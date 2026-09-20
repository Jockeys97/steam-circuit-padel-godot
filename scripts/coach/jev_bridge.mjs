#!/usr/bin/env node
/**
 * jev_bridge.mjs — the coach's local loopback bridge (development integration).
 *
 * WHAT THIS IS. The Godot client never talks to TypeSafe. It posts a bounded, validated
 * body to `http://127.0.0.1:<COACH_PORT>/coach/jev`, and THIS process — which owns
 * `TYPESAFE_API_KEY` in its own environment, and nothing else does — makes the one
 * upstream call the coach is allowed to make:
 *
 *     POST https://api.typesafe.ai/v1/systemone
 *     Authorization: Bearer <TYPESAFE_API_KEY>
 *     { "state": {...measured match...}, "model": "jev-latest",
 *       "questions": { "coach_focus": { type: "choice", instructions, criteria } } }
 *
 * Fixed endpoint, fixed model, fixed question id: `godot/src/coach/coach_contract.json`
 * is read here, so the categories, the counter allowlist and the criteria text have ONE
 * owner and cannot drift between the game and this process. Live contract:
 * https://docs.typesafe.ai/api.md
 *
 * THE BOUNDARY, in the order a request meets it:
 *   - loopback only: the server binds 127.0.0.1 and never another interface;
 *   - POST, this one path, JSON body, under `wire.maxRequestBytes`;
 *   - a browser's own request is refused: any `Origin` or `Sec-Fetch-*` header is 403,
 *     and the `Host` must be loopback on this very port (DNS-rebinding guard);
 *   - no CORS headers are ever sent, so a page cannot read an answer even if a request
 *     left one;
 *   - the body is validated field by field: an unexpected key, a missing counter, a
 *     negative, a fraction, a value over the declared bound or an unknown candidate is a
 *     400 and nothing leaves the machine;
 *   - upstream: no redirects, no automatic retries, one bounded timeout, a bounded
 *     response size, and a 200 whose answer fails its own contract is refused;
 *   - the client gets a bounded status back — never upstream text, never a token.
 *
 * WHAT IT MUST NEVER DO: read the key from anywhere but `process.env`, print it, log a
 * payload or an upstream error body, follow a redirect, retry by itself, or listen on a
 * public interface. This is a development integration, not a deployed service: a public
 * distribution needs an authenticated backend, and this file is explicit about being
 * neither authenticated nor reachable from outside the machine.
 *
 * USAGE
 *   export TYPESAFE_API_KEY="$(cat ~/.hermes/secrets/typesafe.apikey)"
 *   node scripts/coach/jev_bridge.mjs                     # 127.0.0.1:8787
 *   COACH_PORT=9000 node scripts/coach/jev_bridge.mjs
 *
 * TESTS (no key, no paid call, a fake upstream on loopback):
 *   node scripts/coach/jev_bridge_test.mjs
 */

import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

export const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const CONTRACT_REL = path.join("godot", "src", "coach", "coach_contract.json");

/** Bounded, so a local process cannot park a socket on this bridge forever. */
const REQUEST_TIMEOUT_MS = 15000;
const HEADERS_TIMEOUT_MS = 5000;
/** More than one upstream call in flight is already more than one client. */
const MAX_IN_FLIGHT = 2;

const isPlainObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

/** Reads and shape-checks the one contract both sides use. Throws when it is unusable. */
export function loadContract(repo = REPO) {
  const file = path.join(repo, CONTRACT_REL);
  const contract = JSON.parse(readFileSync(file, "utf8"));
  const fail = (why) => { throw new Error(CONTRACT_REL + ": " + why); };
  if (contract?.schema !== "steam-circuit-padel-pro.coach-contract") fail("unexpected schema");
  if (!Number.isInteger(contract?.wire?.version)) fail("wire.version is not an integer");
  if (typeof contract.wire.path !== "string" || !contract.wire.path.startsWith("/")) fail("wire.path is not a path");
  if (typeof contract.wire.maxRequestBytes !== "number") fail("wire.maxRequestBytes is missing");
  if (typeof contract.upstream?.endpoint !== "string" || !contract.upstream.endpoint.startsWith("https://")) fail("upstream.endpoint must be https");
  if (contract.upstream.endpoint !== FIXED_UPSTREAM) fail("upstream.endpoint is not the fixed TypeSafe endpoint");
  if (typeof contract.upstream.model !== "string" || contract.upstream.model === "") fail("upstream.model is missing");
  if (!Number.isInteger(contract.upstream.timeoutMs) || contract.upstream.timeoutMs <= 0) fail("upstream.timeoutMs is not a bounded timeout");
  if (typeof contract.question?.id !== "string" || contract.question.id === "") fail("question.id is missing");
  if (contract.question?.type !== "choice") fail("question.type is not a choice");
  const criteria = contract.question?.criteria;
  if (!isPlainObject(criteria) || Object.keys(criteria).length < 2) fail("question.criteria is not a set of categories");
  if (!Object.prototype.hasOwnProperty.call(criteria, "insufficient_data")) fail("criteria must declare insufficient_data");
  if (!isPlainObject(contract.stats?.groups)) fail("stats.groups is missing");
  if (!Array.isArray(contract.stats?.counters)) fail("stats.counters is missing");
  return contract;
}

/** The one endpoint this bridge may ever call. The contract names it; this pins it. */
export const FIXED_UPSTREAM = "https://api.typesafe.ai/v1/systemone";

// ---------------------------------------------------------------------------
// The wire: what the game is allowed to send
// ---------------------------------------------------------------------------

/** The three fields the wire carries, and nothing else. */
export function validateWire(raw, contract) {
  if (!isPlainObject(raw)) return { ok: false, problems: ["body is not a JSON object"] };
  const problems = [];
  const declared = new Set(["version", "stats", "candidates"]);
  for (const key of Object.keys(raw)) {
    if (!declared.has(key)) problems.push("unexpected field '" + key + "'");
  }
  if (raw.version !== contract.wire.version) problems.push("wire version");
  problems.push(...validateStats(raw.stats, contract));
  problems.push(...validateCandidates(raw.candidates, contract));
  if (problems.length) return { ok: false, problems };
  return { ok: true, problems, stats: raw.stats, candidates: raw.candidates.slice() };
}

/** Every declared counter, present, whole, non-negative and inside the declared bound. */
export function validateStats(stats, contract) {
  if (!isPlainObject(stats)) return ["stats is not an object"];
  const problems = [];
  const max = contract.stats.maxValue;
  const groups = contract.stats.groups;
  const counters = contract.stats.counters;
  const expected = new Set([...Object.keys(groups), ...counters]);
  for (const key of Object.keys(stats)) {
    if (!expected.has(key)) problems.push("unexpected counter '" + key + "'");
  }
  const bounded = (value, where) => {
    if (!Number.isInteger(value)) return problems.push(where + " is not a whole number");
    if (value < 0) return problems.push(where + " is negative");
    if (value > max) return problems.push(where + " is over " + max);
    return undefined;
  };
  for (const [group, sides] of Object.entries(groups)) {
    const value = stats[group];
    if (!isPlainObject(value)) { problems.push(group + " is not an object"); continue; }
    for (const side of Object.keys(value)) {
      if (!sides.includes(side)) problems.push("unexpected counter '" + group + "." + side + "'");
    }
    for (const side of sides) {
      if (!Object.prototype.hasOwnProperty.call(value, side)) { problems.push(group + "." + side + " is missing"); continue; }
      bounded(value[side], group + "." + side);
    }
  }
  for (const name of counters) {
    if (!Object.prototype.hasOwnProperty.call(stats, name)) { problems.push(name + " is missing"); continue; }
    bounded(stats[name], name);
  }
  return problems;
}

/** A real Choice: known categories, no repeats, and never only the no-answer option. */
export function validateCandidates(candidates, contract) {
  const known = new Set(Object.keys(contract.question.criteria));
  if (!Array.isArray(candidates)) return ["candidates is not an array"];
  const problems = [];
  if (candidates.length > known.size) problems.push("more candidates than declared categories");
  const seen = new Set();
  for (const id of candidates) {
    if (typeof id !== "string" || !known.has(id)) problems.push("an unknown candidate was offered");
    else if (seen.has(id)) problems.push("a candidate was offered twice");
    else seen.add(id);
  }
  if (!candidates.includes("insufficient_data")) problems.push("insufficient_data is not offered");
  if (!candidates.some((id) => id !== "insufficient_data")) problems.push("no drillable candidate is offered");
  return problems;
}

// ---------------------------------------------------------------------------
// The upstream request, built from the contract only
// ---------------------------------------------------------------------------

/**
 * The one request shape this bridge may make. `state.measured` renames the wire's own
 * `player`/`ai` to `yourSide`/`opponent` (the criteria are written in those words), adds
 * the two derived readings the question may use — points played, and the average hits
 * per rally, computed with the result screen's own formula (`js/ui.js:1394-1396`) — and
 * copies the criteria of the offered candidates in the contract's own order. No free
 * text from the client reaches this object: it is assembled from the contract and from
 * validated integers.
 */
export function buildUpstreamRequest(wire, contract) {
  const measured = {};
  for (const [group, sides] of Object.entries(contract.stats.groups)) {
    measured[group] = {};
    for (const side of sides) {
      measured[group][side === "player" ? "yourSide" : "opponent"] = wire.stats[group][side];
    }
  }
  for (const name of contract.stats.counters) measured[name] = wire.stats[name];
  const rallies = wire.stats.rallyCount;
  measured.pointsPlayed = wire.stats.pointsWon.player + wire.stats.pointsWon.ai;
  measured.averageHitsPerRally = rallies === 0 ? 0 : Number((wire.stats.totalRallyHits / rallies).toFixed(1));
  const criteria = {};
  for (const [id, rubric] of Object.entries(contract.question.criteria)) {
    if (wire.candidates.includes(id)) criteria[id] = rubric;
  }
  const question = {};
  question[contract.question.id] = {
    type: contract.question.type,
    instructions: contract.question.instructions,
    criteria,
  };
  return {
    // Both notes travel with the state: the grouped counters are one side's aggregate, and
    // the rally counters are the whole match's. The criteria are written in those words, so
    // the model is told which is which instead of inferring it.
    state: { measured, aggregation: contract.stats.aggregation, matchWide: contract.stats.matchWide },
    model: contract.upstream.model,
    questions: question,
  };
}

// ---------------------------------------------------------------------------
// The upstream answer's own contract
// ---------------------------------------------------------------------------

/** Refuses anything that is not a Choice over exactly the offered categories. */
export function validateUpstreamAnswer(parsed, contract, offered) {
  if (!isPlainObject(parsed)) return { ok: false, detail: "upstream body is not an object" };
  if (typeof parsed.model !== "string" || parsed.model === "") return { ok: false, detail: "upstream body carries no model" };
  if (!isPlainObject(parsed.answers)) return { ok: false, detail: "upstream body carries no answers" };
  const answer = parsed.answers[contract.question.id];
  if (!isPlainObject(answer)) return { ok: false, detail: "no answer for the coach question" };
  if (answer.type !== "choice") return { ok: false, detail: "the answer is not a choice" };
  if (typeof answer.choice !== "string" || !offered.includes(answer.choice)) return { ok: false, detail: "the choice was not offered" };
  const confidence = answer.confidence;
  if (typeof confidence !== "number" || !Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    return { ok: false, detail: "confidence is not a probability" };
  }
  const probabilities = answer.probabilities;
  if (!isPlainObject(probabilities)) return { ok: false, detail: "no distribution" };
  const keys = Object.keys(probabilities);
  if (keys.length !== offered.length) return { ok: false, detail: "the distribution does not cover the offered categories" };
  let total = 0;
  let peak = 0;
  for (const key of keys) {
    if (!offered.includes(key)) return { ok: false, detail: "the distribution carries a category that was not offered" };
    const value = probabilities[key];
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
      return { ok: false, detail: "a distribution entry is not a probability" };
    }
    total += value;
    peak = Math.max(peak, value);
  }
  if (Math.abs(total - 1) > 0.02) return { ok: false, detail: "the distribution does not sum to 1" };
  // A Choice's `choice` is its highest-probability option (https://docs.typesafe.ai/api.md):
  // a body whose chosen option is not the peak, beyond a tie's floating-point noise, is
  // internally inconsistent and is refused rather than forwarded.
  if (probabilities[answer.choice] < peak - 0.000001) {
    return { ok: false, detail: "the chosen category is not the most probable one" };
  }
  const bounded = {};
  for (const key of offered) bounded[key] = probabilities[key];
  return { ok: true, detail: "", model: parsed.model, choice: answer.choice, confidence, probabilities: bounded };
}

// ---------------------------------------------------------------------------
// The upstream call
// ---------------------------------------------------------------------------

/** Reads at most `limit` bytes; `null` means the answer was over the declared bound. */
async function readBounded(response, limit) {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const chunks = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      try { await reader.cancel(); } catch { /* the answer is already refused */ }
      return null;
    }
    chunks.push(Buffer.from(value));
  }
  return Buffer.concat(chunks).toString("utf8");
}

/**
 * The fixed upstream call. No redirects (`redirect: "manual"`, and a 3xx is a refusal),
 * no retry, one bounded timeout, one bounded response size, and never the key in an
 * error. Only a 200 whose JSON passes `validateUpstreamAnswer` counts as an answer; the
 * reason strings here are ours, never upstream text.
 */
export function makeUpstreamFetcher({ contract, apiKey, fetchImpl = fetch }) {
  return async function fetchUpstream(payload) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), contract.upstream.timeoutMs);
    try {
      const response = await fetchImpl(contract.upstream.endpoint, {
        method: "POST",
        headers: {
          Authorization: "Bearer " + apiKey,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
        redirect: "manual",
        signal: controller.signal,
      });
      if (response.status >= 300 && response.status < 400) return { status: "unavailable", reason: "redirect" };
      if (response.status !== 200) return { status: "unavailable", reason: "status " + response.status };
      const text = await readBounded(response, contract.upstream.maxResponseBytes);
      if (text === null) return { status: "unavailable", reason: "oversize" };
      let parsed;
      try {
        parsed = JSON.parse(text);
      } catch {
        return { status: "invalid", reason: "not json" };
      }
      return { status: "ok", parsed };
    } catch (error) {
      const name = error && typeof error === "object" ? error.name : "";
      return { status: "unavailable", reason: name === "AbortError" ? "timeout" : "network" };
    } finally {
      clearTimeout(timer);
    }
  };
}

const isJsonContentType = (value) => typeof value === "string" && /^application\/json\b/i.test(value.trim());

/** The browser's own markers: an Origin, or the Fetch metadata headers only a page sets. */
export function hasBrowserOrigin(headers) {
  return Boolean(headers.origin || headers["sec-fetch-mode"] || headers["sec-fetch-site"] || headers["sec-fetch-dest"]);
}

/** Loopback on this exact port, or nothing: the DNS-rebinding guard. */
export function hostAllowed(hostHeader, port) {
  if (typeof hostHeader !== "string" || hostHeader === "") return false;
  const value = hostHeader.trim().toLowerCase();
  return ["127.0.0.1:" + port, "localhost:" + port, "[::1]:" + port].includes(value);
}

function readBody(req, limit) {
  return new Promise((resolve) => {
    const chunks = [];
    let size = 0;
    let tooLarge = false;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > limit) { tooLarge = true; return; }
      chunks.push(chunk);
    });
    req.on("end", () => resolve({ tooLarge, text: tooLarge ? "" : Buffer.concat(chunks).toString("utf8") }));
    req.on("error", () => resolve({ tooLarge, text: "" }));
  });
}

// ---------------------------------------------------------------------------
// The server
// ---------------------------------------------------------------------------

/** One line per request, on stderr: a code and a duration, never a payload or a secret. */
export function defaultLog(line) {
  process.stderr.write("[jev-bridge] " + line + "\n");
}

/**
 * What a log line may say about a request: the canonical route, or a marker when the
 * request did not name it; `POST`, or a marker when it was some other verb. Both fields are
 * attacker-chosen text in a hostile request, and neither the query string nor the raw path
 * or verb is ever written.
 */
export function safeRouteLabel(route, contract) {
  // The query string is stripped here as well as at the call site: a log line may name the
  // canonical route, and nothing else about the request.
  const canonical = String(route || "").split("?")[0];
  return canonical === contract.wire.path ? contract.wire.path : "(other-route)";
}

export function safeMethodLabel(method) {
  return method === "POST" ? "POST" : "(other-method)";
}

/**
 * The bridge as a factory: the CLI passes the fixed upstream, and the tests inject a fake
 * one (a loopback server of their own) plus a silent log. Nothing here reads the
 * environment — the caller decides, which is what keeps the shipped path unconfigurable.
 */
export function createBridge({ contract, fetchUpstream, log = defaultLog, port = 0 }) {
  let inFlight = 0;
  const server = createServer((req, res) => {
    const started = Date.now();
    const send = (code, body, after = null) => {
      const text = JSON.stringify(body);
      res.writeHead(code, {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(text),
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
        Connection: "close",
      });
      // The response is flushed before anything closes the socket: a client that was
      // refused still reads the status that refused it.
      res.end(text, after === null ? undefined : after);
      // The CANONICAL route label and a known verb only, never `req.url` or a raw method: a
      // request can carry a query string, a path traversal attempt or any other
      // attacker-chosen text, and a log line is not a place for it. Code, duration and the
      // bridge's own status complete the line.
      const routeLabel = safeRouteLabel(req.url, contract);
      log(code + " " + safeMethodLabel(req.method) + " " + routeLabel + " " + (Date.now() - started) + "ms " + body.status);
    };
    if (req.method !== "POST") return send(405, { status: "method_not_allowed" });
    const route = (req.url || "").split("?")[0];
    if (route !== contract.wire.path) return send(404, { status: "not_found" });
    if (hasBrowserOrigin(req.headers)) return send(403, { status: "forbidden" });
    // The port the socket is actually on: the caller may have asked for 0 (a test), and
    // the Host header must name this very port in either case.
    const bound = server.address();
    const boundPort = bound && typeof bound === "object" ? bound.port : port;
    if (!hostAllowed(req.headers.host, boundPort)) return send(403, { status: "forbidden" });
    if (!isJsonContentType(req.headers["content-type"])) return send(415, { status: "bad_request" });
    const declared = Number(req.headers["content-length"] || 0);
    if (declared > contract.wire.maxRequestBytes) {
      // An announced body this bridge will not read: answer, then drop the socket.
      return send(413, { status: "too_large" }, () => req.destroy());
    }
    return readBody(req, contract.wire.maxRequestBytes).then(async (body) => {
      if (body.tooLarge) return send(413, { status: "too_large" });
      let parsed;
      try {
        parsed = JSON.parse(body.text);
      } catch {
        return send(400, { status: "bad_request" });
      }
      const wire = validateWire(parsed, contract);
      if (!wire.ok) return send(400, { status: "bad_request" });
      if (inFlight >= MAX_IN_FLIGHT) return send(503, { status: "busy" });
      inFlight += 1;
      let upstream;
      try {
        upstream = await fetchUpstream(buildUpstreamRequest(wire, contract));
      } catch {
        upstream = { status: "unavailable", reason: "threw" };
      } finally {
        inFlight -= 1;
      }
      if (upstream.status === "unavailable") return send(503, { status: "upstream_unavailable" });
      if (upstream.status !== "ok") return send(502, { status: "upstream_invalid" });
      const answer = validateUpstreamAnswer(upstream.parsed, contract, wire.candidates);
      if (!answer.ok) return send(502, { status: "upstream_invalid" });
      return send(200, {
        status: "ok",
        type: "choice",
        choice: answer.choice,
        confidence: answer.confidence,
        probabilities: answer.probabilities,
      });
    });
  });
  server.requestTimeout = REQUEST_TIMEOUT_MS;
  server.headersTimeout = HEADERS_TIMEOUT_MS;
  // The game's own client is the only caller this bridge expects.
  server.maxConnections = 8;
  return {
    server,
    contract,
    listen({ host = "127.0.0.1", bindPort = port }, onReady) {
      server.listen(bindPort, host, onReady);
      return server.address();
    },
    close() {
      return new Promise((resolve) => server.close(resolve));
    },
    inFlight: () => inFlight,
  };
}

/** The port from the declared environment variable, or the contract's own default. */
export function resolvePort(contract, raw) {
  const declared = Number(contract.wire.defaultPort);
  if (typeof raw !== "string" || raw.trim() === "") return declared;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1024 || value > 65535) return declared;
  return value;
}

export function isMain(metaUrl = import.meta.url) {
  return process.argv[1] ? path.resolve(process.argv[1]) === fileURLToPath(metaUrl) : false;
}

function main() {
  const contract = loadContract();
  const keyEnv = contract.upstream.keyEnv;
  const key = process.env[keyEnv] ?? "";
  if (key.trim() === "") {
    process.stderr.write("jev_bridge: " + keyEnv + " is not set. Export it in this shell before starting the bridge; this process never prints, logs or writes the value.\n");
    process.exit(2);
  }
  const port = resolvePort(contract, process.env[contract.wire.portEnv]);
  const bridge = createBridge({ contract, fetchUpstream: makeUpstreamFetcher({ contract, apiKey: key }) });
  bridge.listen({ host: "127.0.0.1", bindPort: port }, () => {
    process.stderr.write("jev_bridge: listening on http://127.0.0.1:" + port + contract.wire.path + " (" + keyEnv + " set; model " + contract.upstream.model + ")\n");
  });
  const stop = () => {
    bridge.close().then(() => process.exit(0));
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
}

if (isMain()) main();
