#!/usr/bin/env node
/**
 * jev_bridge_integration_test.mjs — the seam nothing else covers: the ACTUAL Godot coach
 * client talking to the ACTUAL bridge, with a fake upstream behind it.
 *
 * The unit tests drive each half against its own stub (the client against a Godot stub
 * server, the bridge against a Node fake upstream). This one runs the real pair:
 *
 *   Godot CoachClient (the engine's own HTTPRequest, no test seam)
 *     -> the real createBridge from ./jev_bridge.mjs, on loopback
 *       -> a fake upstream this file starts (and, in one scenario, does not answer at all)
 *
 * Three scenarios, each with its own bridge and upstream:
 *   client  — the upstream answers 503 first and a Choice second: fail -> retry -> advice.
 *   ui      — the whole visible path: the result screen's block asks, gets the advice, and
 *             routes into the real drill screen with the exercise selected.
 *   offline — the upstream is a closed port: the truthful unavailable state, twice.
 *
 * No key is needed and no request leaves this machine. The Godot binary is `$GODOT` or
 * `/Applications/Godot.app/Contents/MacOS/Godot`.
 *
 *   node scripts/coach/jev_bridge_integration_test.mjs
 *
 * Output contract: one `ok <name>` / `FAIL <name>: <detail>` line per check, then
 * `PASS <n>/<n>` or `FAIL <n>/<n>`. Exit 0 only when every check passed.
 */

import { createServer } from "node:http";
import { spawn } from "node:child_process";

import { REPO, createBridge, loadContract, makeUpstreamFetcher } from "./jev_bridge.mjs";

const GODOT = process.env.GODOT || "/Applications/Godot.app/Contents/MacOS/Godot";
const PROBE = "res://tests/coach_integration_probe.gd";
const KEY = "integration-key-2c17-never-logged";
const PROBE_TIMEOUT_MS = 90000;

const checks = [];
const record = (name, ok, detail = "") => {
  checks.push({ name, ok, detail });
  process.stdout.write((ok ? "ok " : "FAIL ") + name + (ok ? "" : ": " + detail) + "\n");
};
const check = (name, condition, detail = "") => record(name, Boolean(condition), detail);
const checkEq = (name, actual, expected) => {
  record(name, actual === expected, "expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
};

const contract = loadContract();

/** The Choice the fake upstream answers with, over exactly the candidates it was offered. */
function choiceFor(offered) {
  const choice = offered.includes("serve_accuracy") ? "serve_accuracy" : offered[0];
  const rest = (1 - 0.8) / Math.max(offered.length - 1, 1);
  const probabilities = {};
  for (const id of offered) probabilities[id] = id === choice ? 0.8 : rest;
  const answers = {};
  answers[contract.question.id] = { type: "choice", choice, confidence: 0.82, probabilities };
  return JSON.stringify({ model: "jev-1.13.0", answers, usage: { input_tokens: 300, output_tokens: 20 } });
}

/** A loopback upstream that records what it was asked. `failFirst` answers 503 once. */
async function startFakeUpstream({ failFirst = false } = {}) {
  const calls = [];
  const server = createServer((req, res) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      const body = Buffer.concat(chunks).toString("utf8");
      calls.push({ url: req.url, headers: req.headers, body });
      if (failFirst && calls.length === 1) {
        res.writeHead(503, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "temporarily unavailable" }));
        return;
      }
      let offered = ["insufficient_data"];
      try {
        const parsed = JSON.parse(body);
        offered = Object.keys(parsed.questions[contract.question.id].criteria);
      } catch {
        offered = ["insufficient_data"];
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(choiceFor(offered));
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return {
    calls,
    url: "http://127.0.0.1:" + server.address().port + "/v1/systemone",
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

/** A loopback address nothing is listening on: bound, read, released. */
async function closedUpstreamUrl() {
  const probe = createServer(() => {});
  await new Promise((resolve) => probe.listen(0, "127.0.0.1", resolve));
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));
  return "http://127.0.0.1:" + port + "/v1/systemone";
}

/**
 * The real bridge: the shipped `createBridge`, the shipped fetcher and validation. Only the
 * endpoint inside the injected contract copy is this test's own — the CLI builds the same
 * fetcher from the contract's pinned https address.
 */
async function startBridge({ upstreamUrl, log = () => {} }) {
  const testContract = {
    ...contract,
    upstream: { ...contract.upstream, endpoint: upstreamUrl, timeoutMs: 2000 },
  };
  const bridge = createBridge({
    contract: testContract,
    fetchUpstream: makeUpstreamFetcher({ contract: testContract, apiKey: KEY, fetchImpl: fetch }),
    log,
    port: 0,
  });
  await new Promise((resolve) => bridge.server.listen(0, "127.0.0.1", resolve));
  return { bridge, port: bridge.server.address().port };
}

/** One Godot probe run, its exit code and its `probe k=v` values. */
function runProbe(port, mode) {
  return new Promise((resolve) => {
    const child = spawn(GODOT, [
      "--headless",
      "--path",
      "godot",
      "--script",
      PROBE,
      "--",
      "--port=" + port,
      "--mode=" + mode,
    ], { cwd: REPO });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      stderr += "\nprobe timed out after " + PROBE_TIMEOUT_MS + "ms";
    }, PROBE_TIMEOUT_MS);
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ code: -1, stdout, stderr: stderr + "\n" + String(error && error.message), values: {} });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      const values = {};
      for (const line of stdout.split("\n")) {
        const match = line.match(/^probe ([a-z_]+)=(.*)$/);
        if (match) values[match[1]] = match[2];
      }
      resolve({ code, stdout, stderr, values });
    });
  });
}

// ---------------------------------------------------------------------------
// 1. client — fail, retry, advice, through the real pair
// ---------------------------------------------------------------------------

const failFirst = await startFakeUpstream({ failFirst: true });
const clientLogs = [];
const clientBridge = await startBridge({ upstreamUrl: failFirst.url, log: (line) => clientLogs.push(line) });
const clientRun = await runProbe(clientBridge.port, "client");
checkEq("client/the_probe_exited_clean", clientRun.code, 0);
checkEq("client/the_first_ask_met_the_failing_upstream", clientRun.values.first, "unavailable");
checkEq("client/the_retry_met_the_answering_upstream", clientRun.values.second, "advice");
checkEq("client/the_advice_links_the_serve_exercise", clientRun.values.drill, "serve");
checkEq("client/the_retry_was_a_second_request", clientRun.values.requests, "2");
checkEq("client/the_upstream_was_called_twice", failFirst.calls.length, 2);
checkEq("client/the_key_rode_in_the_authorization_header", failFirst.calls[0].headers.authorization, "Bearer " + KEY);
const secondBody = JSON.parse(failFirst.calls[1].body);
checkEq("client/the_upstream_was_asked_the_contract_question", Object.keys(secondBody.questions)[0], contract.question.id);
checkEq("client/the_upstream_saw_the_measured_points", secondBody.state.measured.pointsWon.yourSide, 11);
checkEq("client/the_upstream_saw_the_match_wide_note", secondBody.state.matchWide, contract.stats.matchWide);
check("client/no_client_sentence_reached_the_upstream", !failFirst.calls[1].body.includes("coachAdvice"));
check("client/no_log_line_carries_the_key", clientLogs.every((line) => !line.includes(KEY)));
check("client/no_log_line_carries_the_upstream_body", clientLogs.every((line) => !line.includes("serve_accuracy")));
await clientBridge.bridge.close();
await failFirst.close();

// ---------------------------------------------------------------------------
// 2. ui — the visible path, against the real bridge
// ---------------------------------------------------------------------------

const liveUpstream = await startFakeUpstream({});
const uiBridge = await startBridge({ upstreamUrl: liveUpstream.url });
const uiRun = await runProbe(uiBridge.port, "ui");
checkEq("ui/the_probe_exited_clean", uiRun.code, 0);
checkEq("ui/the_block_waits_for_a_press", uiRun.values.before, "idle");
checkEq("ui/the_advice_arrived_through_the_real_bridge", uiRun.values.after, "advice");
check("ui/the_block_names_the_exercise", String(uiRun.values.exercise || "").includes("Serve"));
check("ui/the_block_shows_the_measured_numbers", String(uiRun.values.evidence || "").includes("4 errors"));
checkEq("ui/the_router_opened_the_training_screen", uiRun.values.route, "drill");
checkEq("ui/with_the_exercise_selected", uiRun.values.selected, "serve");
checkEq("ui/the_pending_run_was_left_alone", uiRun.values.pending_mode, "career");
checkEq("ui/the_upstream_was_called_once", liveUpstream.calls.length, 1);
await uiBridge.bridge.close();
await liveUpstream.close();

// ---------------------------------------------------------------------------
// 3. offline — a bridge whose upstream is unreachable
// ---------------------------------------------------------------------------

const offlineBridge = await startBridge({ upstreamUrl: await closedUpstreamUrl() });
const offlineRun = await runProbe(offlineBridge.port, "offline");
checkEq("offline/the_probe_exited_clean", offlineRun.code, 0);
checkEq("offline/the_first_ask_is_unavailable", offlineRun.values.first, "unavailable");
checkEq("offline/the_retry_repeats_the_truth_rather_than_caching_it", offlineRun.values.second, "unavailable");
checkEq("offline/both_asks_really_went_out", offlineRun.values.requests, "2");
checkEq("offline/nothing_is_claimed_about_the_match", offlineRun.values.advice, "");
await offlineBridge.bridge.close();

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

const failures = checks.filter((entry) => !entry.ok);
if (failures.length) {
  process.stdout.write("\nFAIL " + (checks.length - failures.length) + "/" + checks.length + "\n");
  process.exit(1);
}
process.stdout.write("\nPASS " + checks.length + "/" + checks.length + "\n");
process.exit(0);
