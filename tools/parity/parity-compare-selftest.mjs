#!/usr/bin/env node
/**
 * parity-compare-selftest.mjs — proves the comparator catches injected
 * differences, on real JavaScript digest data plus synthetic injected streams.
 *
 * What it does NOT do: it never edits `scripts/parity-digest.mjs`, never touches
 * `js/**`, never writes under `godot/**`, and never claims a GDScript comparison
 * happened. The "right" side of every case here is a synthetic stream built by
 * mutating the real JS digest, standing in for the GDScript producer until one
 * exists.
 *
 * Every case runs the delivered CLI (`tools/parity/parity-compare.mjs`) as a
 * child process and asserts exit code + reported RESULT + reported first
 * divergence (tick and field). Fixture files are written to
 * tools/parity/fixtures/ so each case can be re-run by hand.
 *
 * Usage: node tools/parity/parity-compare-selftest.mjs [--keep-fixtures]
 */

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { parseDigestText, digestSha256OfLines, lineFromValues } from "./parity-stream.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..");
// PARITY_COMPARE_BIN lets this suite be pointed at a deliberately weakened copy
// of the comparator (mutation testing): the suite proving itself capable of
// going red is what makes its green runs mean anything.
const COMPARE = process.env.PARITY_COMPARE_BIN ?? path.join(HERE, "parity-compare.mjs");
const HARNESS = path.join(ROOT, "scripts", "parity-digest.mjs");
const FROZEN_JSON = path.join(ROOT, "tools", "parity", "parity-digest-seed12345.json");
const FIXTURES = path.join(HERE, "fixtures");

const FROZEN_JSON_SHA256 = "1032fb20df663a8e0db44ad85d15bcd00a840a1a80b9611cba06c368bb70f0dc";
const FROZEN_JSON_DIGEST = "a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd";
const HARNESS_SHA256 = "2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd";

const fileSha256 = (buffer) => createHash("sha256").update(buffer).digest("hex");

// ---------------------------------------------------------------------------
// Harness + fixture plumbing
// ---------------------------------------------------------------------------

function runHarness() {
  const result = spawnSync(
    process.execPath,
    [HARNESS, "--seed=12345", "--ticks=1440", "--every=60"],
    { cwd: ROOT, encoding: "utf8" },
  );
  if (result.status !== 0) {
    throw new Error(`il producer JS e' fallito (exit ${result.status}): ${result.stderr}`);
  }
  return result.stdout;
}

function runCompare(leftPath, rightPath, extraArgs = []) {
  const result = spawnSync(
    process.execPath,
    [COMPARE, leftPath, rightPath, ...extraArgs],
    { cwd: ROOT, encoding: "utf8" },
  );
  const stdout = result.stdout ?? "";
  const resultMatch = /RESULT=([A-Z-]+)/.exec(stdout);
  const firstMatch = /firstTick=(\S+) field=(\S+)/.exec(stdout);
  const cascadeMatch = /CASCADE divergentTicksAfter=(\d+) of (\d+)/.exec(stdout);
  return {
    status: result.status,
    stdout,
    stderr: result.stderr ?? "",
    result: resultMatch ? resultMatch[1] : null,
    firstTick: firstMatch && firstMatch[1] !== "-" ? firstMatch[1] : null,
    firstField: firstMatch && firstMatch[2] !== "-" ? firstMatch[2] : null,
    cascade: cascadeMatch ? { divergent: Number(cascadeMatch[1]), of: Number(cascadeMatch[2]) } : null,
  };
}

/** Rebuild a digest text stream from mutated values, refreshing the digest sha. */
function renderStream({ headerLine1, headerLine3, samples, side = "SYNTH", summary = true }) {
  const digestLines = samples.map((sample) => lineFromValues(sample.values));
  const sha256 = digestSha256OfLines(digestLines);
  const ticks = digestLines.length ? samples[samples.length - 1].values.tick : "000000";
  const lines = [
    headerLine1,
    "# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)",
    headerLine3,
    ...digestLines,
  ];
  if (summary) {
    lines.push(
      `PARITY-DIGEST ${side} PASS seed=12345 ticks=1440 sampledTicks=${digestLines.length} every=60 ` +
        `finalRngState=${samples.length ? samples[samples.length - 1].values.rngState : "0"} digestSha256=${sha256}`,
    );
  }
  return `${lines.join("\n")}\n`;
}

const cloneSamples = (samples) => samples.map((s) => ({ tick: s.tick, values: { ...s.values } }));

function findSampleIndex(samples, tick) {
  const index = samples.findIndex((sample) => sample.values.tick === tick);
  if (index === -1) throw new Error(`tick ${tick} non trovato nella base`);
  return index;
}

function setField(samples, tick, field, value) {
  const copy = cloneSamples(samples);
  copy[findSampleIndex(copy, tick)].values[field] = value;
  return copy;
}

/** Perturb a scalar field by `delta`, keeping the fixed(6) rendering. */
function bumpScalar(samples, tick, field, delta) {
  const copy = cloneSamples(samples);
  const sample = copy[findSampleIndex(copy, tick)];
  const original = Number(sample.values[field]);
  if (!Number.isFinite(original)) throw new Error(`campo ${field} non numerico: ${sample.values[field]}`);
  sample.values[field] = (original + delta).toFixed(6);
  return copy;
}

/** Perturb an integer field by `delta`, relative to whatever the base holds. */
function bumpInt(samples, tick, field, delta) {
  const copy = cloneSamples(samples);
  const sample = copy[findSampleIndex(copy, tick)];
  const original = Number.parseInt(sample.values[field], 10);
  if (!Number.isFinite(original)) throw new Error(`campo ${field} non intero: ${sample.values[field]}`);
  sample.values[field] = String(original + delta);
  return copy;
}

/** Perturb one component of a vector/point field by `delta`, keeping fixed(6). */
function perturbComponent(samples, tick, field, component, delta) {
  const copy = cloneSamples(samples);
  const sample = copy[findSampleIndex(copy, tick)];
  const match = /^\(([^)]*)\)$/.exec(sample.values[field]);
  if (!match) throw new Error(`campo ${field} non e' un vettore: ${sample.values[field]}`);
  const parts = match[1].split(",");
  const order = field === "ball" || field === "v" ? ["x", "y", "z"] : ["x", "y"];
  const index = order.indexOf(component);
  parts[index] = (Number(parts[index]) + delta).toFixed(6);
  sample.values[field] = `(${parts.join(",")})`;
  return copy;
}

// ---------------------------------------------------------------------------
// Case runner
// ---------------------------------------------------------------------------

const cases = [];
let failures = 0;

function check(name, condition, detail) {
  if (condition) return true;
  failures += 1;
  console.log(`    ASSERT-FAIL ${name}: ${detail}`);
  return false;
}

function runCase(spec) {
  const leftText = spec.left();
  const rightText = spec.right();
  const leftPath = path.join(FIXTURES, `${spec.name}.left.txt`);
  const rightPath = path.join(FIXTURES, `${spec.name}.right.txt`);
  writeFileSync(leftPath, leftText, "utf8");
  writeFileSync(rightPath, rightText, "utf8");
  writeFileSync(path.join(FIXTURES, `${spec.name}.cmd.sh`), spec.manualCmd ?? "", "utf8");

  const observed = runCompare(leftPath, rightPath, spec.args ?? []);
  const want = spec.expect;
  const ok = [
    check(`${spec.name} exit`, observed.status === want.exit, `atteso exit ${want.exit}, ottenuto ${observed.status}`),
    check(
      `${spec.name} result`,
      observed.result === want.result,
      `atteso RESULT=${want.result}, ottenuto ${observed.result}`,
    ),
    want.firstTick === undefined ||
      check(
        `${spec.name} firstTick`,
        observed.firstTick === want.firstTick,
        `atteso firstTick=${want.firstTick}, ottenuto ${observed.firstTick}`,
      ),
    want.field === undefined ||
      check(`${spec.name} field`, observed.firstField === want.field, `atteso field=${want.field}, ottenuto ${observed.firstField}`),
    want.cascadePositive === undefined ||
      check(
        `${spec.name} cascade`,
        Boolean(observed.cascade && observed.cascade.divergent > 0),
        `atteso un conteggio di coda > 0, ottenuto ${JSON.stringify(observed.cascade)}`,
      ),
    ...(spec.extraChecks ?? []).map((extra) => extra(observed)),
  ].every(Boolean);

  cases.push({ name: spec.name, ok, result: observed.result, firstTick: observed.firstTick, firstField: observed.firstField });
  console.log(
    `${ok ? "  ok  " : " FAIL "} ${spec.name.padEnd(38)} exit=${observed.status} RESULT=${observed.result} ` +
      `first=${observed.firstTick ?? "-"}/${observed.firstField ?? "-"}` +
      (ok ? "" : `  <<< expected exit=${want.exit} RESULT=${want.result} first=${want.firstTick ?? "-"}/${want.field ?? "-"}`),
  );
  if (!ok) {
    console.log(observed.stdout.split("\n").slice(0, 12).map((l) => `        | ${l}`).join("\n"));
  }
  return observed;
}

// ---------------------------------------------------------------------------
// Base material: the REAL JavaScript digest
// ---------------------------------------------------------------------------

console.log("# parity-compare self-test: comparator vs real JS digest + injected streams");
console.log(`# node ${process.version}  cwd ${ROOT}`);

const harnessSha = fileSha256(readFileSync(HARNESS));
const frozenJsonSha = fileSha256(readFileSync(FROZEN_JSON));
check("frozen harness untouched", harnessSha === HARNESS_SHA256, `sha256 ${harnessSha} != ${HARNESS_SHA256}`);
check("frozen json untouched", frozenJsonSha === FROZEN_JSON_SHA256, `sha256 ${frozenJsonSha} != ${FROZEN_JSON_SHA256}`);
console.log(`# frozen seam: scripts/parity-digest.mjs sha256=${harnessSha}`);
console.log(`# frozen input: tools/parity/parity-digest-seed12345.json sha256=${frozenJsonSha}`);

const runA = runHarness();
const runB = runHarness();
check("harness rerun is byte-stable", runA === runB, "due esecuzioni del producer JS differiscono");
const parsed = parseDigestText(runA, { label: "js-live", sourcePath: "scripts/parity-digest.mjs" });
check("live stream parses conformant", parsed.problems.length === 0, JSON.stringify(parsed.problems));
check("live stream integrity", parsed.integrity.ok === true, `integrity=${parsed.integrity.ok}`);
check(
  "live digest == frozen artifact digest",
  parsed.meta.digestSha256 === FROZEN_JSON_DIGEST,
  `live=${parsed.meta.digestSha256} frozen=${FROZEN_JSON_DIGEST}`,
);
console.log(
  `# live JS digest: samples=${parsed.samples.length} digestSha256=${parsed.meta.digestSha256} ` +
    `finalRngState=${parsed.meta.finalRngState} integrity=${parsed.integrity.ok ? "OK" : "MISMATCH"}`,
);

mkdirSync(FIXTURES, { recursive: true });
const BASE_LINES = runA.split("\n");
const HEADER1 = BASE_LINES[0];
const HEADER3_GD = "# format=synthetic-godot-side stand-in-until-parity-digest-gd-exists (parity-compare selftest)";
const baseSamples = parsed.samples.map((sample) => ({ tick: sample.tick, values: { ...sample.values } }));
const liveStreamText = runA;
const jsPath = path.join(FIXTURES, "js-seed12345-live.txt");
writeFileSync(jsPath, liveStreamText, "utf8");

const renderGd = (samples, opts = {}) =>
  renderStream({ headerLine1: HEADER1.replace("parity-digest.mjs", "parity-digest.gd"), headerLine3: HEADER3_GD, samples, ...opts });
const renderSelf = (samples, opts = {}) =>
  renderStream({ headerLine1: HEADER1, headerLine3: BASE_LINES[2], samples, ...opts });

// ---------------------------------------------------------------------------
// GREEN cases
// ---------------------------------------------------------------------------

console.log("\n# GREEN: streams that must compare IDENTICAL");

runCase({
  name: "G1-live-js-vs-live-js",
  left: () => liveStreamText,
  right: () => runHarness(),
  expect: { exit: 0, result: "IDENTICAL", firstTick: null, field: null },
  manualCmd: "node tools/parity/parity-compare.mjs tools/parity/fixtures/G1-live-js-vs-live-js.left.txt tools/parity/fixtures/G1-live-js-vs-live-js.right.txt\n",
});

runCase({
  name: "G2-live-js-vs-frozen-json",
  left: () => liveStreamText,
  right: () => readFileSync(FROZEN_JSON, "utf8"),
  expect: { exit: 0, result: "IDENTICAL", firstTick: null, field: null },
  manualCmd: "node tools/parity/parity-compare.mjs tools/parity/fixtures/js-seed12345-live.txt tools/parity/parity-digest-seed12345.json\n",
});

runCase({
  name: "G3-rendered-vs-live",
  left: () => liveStreamText,
  right: () => renderSelf(baseSamples),
  expect: { exit: 0, result: "IDENTICAL", firstTick: null, field: null },
});

runCase({
  name: "G4-no-summary-line",
  left: () => liveStreamText,
  right: () => renderGd(baseSamples, { summary: false }),
  expect: { exit: 0, result: "IDENTICAL", firstTick: null, field: null },
});

runCase({
  name: "G5-crlf-and-blank-lines",
  left: () => liveStreamText.replace(/\n/g, "\r\n") + "\n\n",
  right: () => renderGd(baseSamples),
  expect: { exit: 0, result: "IDENTICAL", firstTick: null, field: null },
});

// Float noise inside the §6 proposal: strict must still catch it, --tol=1e-3
// must accept it. This is the case that documents the unvalidated tolerance.
const withinTolSamples = perturbComponent(
  perturbComponent(bumpScalar(baseSamples, "000240", "spin", 0.0005), "000240", "ball", "x", 0.0005),
  "000300",
  "player",
  "y",
  0.0009,
);
runCase({
  name: "G6-noise-in-tol-strict",
  left: () => liveStreamText,
  right: () => renderGd(withinTolSamples),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000240", field: "ball.x" },
  manualCmd:
    "node tools/parity/parity-compare.mjs tools/parity/fixtures/js-seed12345-live.txt tools/parity/fixtures/G6-noise-in-tol-strict.right.txt\n",
});
runCase({
  name: "G7-noise-in-tol-with-tol",
  left: () => liveStreamText,
  right: () => renderGd(withinTolSamples),
  args: ["--tol=0.001"],
  expect: { exit: 0, result: "IDENTICAL", firstTick: null, field: null },
  manualCmd:
    "node tools/parity/parity-compare.mjs tools/parity/fixtures/js-seed12345-live.txt tools/parity/fixtures/G7-noise-in-tol-with-tol.right.txt --tol=0.001\n",
});

// ---------------------------------------------------------------------------
// RED cases: injected differences the comparator must locate exactly
// ---------------------------------------------------------------------------

console.log("\n# RED: injected differences and the first divergence each must yield");

runCase({
  name: "R1-rngState-drift",
  left: () => liveStreamText,
  right: () => renderGd(bumpInt(baseSamples, "000120", "rngState", 1)),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000120", field: "rngState" },
  manualCmd:
    "node tools/parity/parity-compare.mjs tools/parity/fixtures/js-seed12345-live.txt tools/parity/fixtures/R1-rngState-drift.right.txt\n",
});

runCase({
  name: "R2-rngCalls-off-by-one",
  left: () => liveStreamText,
  right: () => renderGd(bumpInt(baseSamples, "000120", "rngCalls", 1)),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000120", field: "rngCalls" },
});

runCase({
  name: "R3-ball-x-beyond-tol",
  left: () => liveStreamText,
  right: () => renderGd(perturbComponent(baseSamples, "000240", "ball", "x", 0.01)),
  args: ["--tol=0.001"],
  expect: { exit: 1, result: "DIVERGED", firstTick: "000240", field: "ball.x" },
});

runCase({
  name: "R4-ball-z-mid-stream",
  left: () => liveStreamText,
  right: () => renderGd(perturbComponent(baseSamples, "000900", "ball", "z", 2.5)),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000900", field: "ball.z" },
});

runCase({
  name: "R5-velocity-component",
  left: () => liveStreamText,
  right: () => renderGd(perturbComponent(baseSamples, "001320", "v", "y", 1)),
  expect: { exit: 1, result: "DIVERGED", firstTick: "001320", field: "v.y" },
});

runCase({
  name: "R6-pointsWon-score-field",
  left: () => liveStreamText,
  right: () => renderGd(setField(baseSamples, "001320", "pointsWon", "2-0")),
  expect: { exit: 1, result: "DIVERGED", firstTick: "001320", field: "pointsWon" },
});

runCase({
  name: "R7-shotType-sequence",
  left: () => liveStreamText,
  right: () => renderGd(setField(baseSamples, "001380", "shotType", "smash")),
  expect: { exit: 1, result: "DIVERGED", firstTick: "001380", field: "shotType" },
});

runCase({
  name: "R8-smashStage-enum",
  left: () => liveStreamText,
  right: () => renderGd(setField(baseSamples, "000060", "smashStage", "1")),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000060", field: "smashStage" },
});

runCase({
  name: "R9-bounces-counter",
  left: () => liveStreamText,
  right: () => renderGd(setField(baseSamples, "001380", "bounces", "2/0")),
  expect: { exit: 1, result: "DIVERGED", firstTick: "001380", field: "bounces" },
});

runCase({
  name: "R10-paddle-position",
  left: () => liveStreamText,
  right: () => renderGd(perturbComponent(baseSamples, "000060", "opponentMate", "x", -12.25)),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000060", field: "opponentMate.x" },
});

runCase({
  name: "R11-missing-sample-tick",
  left: () => liveStreamText,
  right: () => renderGd(cloneSamples(baseSamples).filter((sample) => sample.values.tick !== "000600")),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000600", field: "samples" },
  manualCmd:
    "node tools/parity/parity-compare.mjs tools/parity/fixtures/js-seed12345-live.txt tools/parity/fixtures/R11-missing-sample-tick.right.txt\n",
});

runCase({
  name: "R12-extra-sample-tick",
  left: () => liveStreamText,
  right: () => renderGd([baseSamples[0], { ...baseSamples[0], tick: "000030", values: { ...baseSamples[0].values, tick: "000030" } }, ...baseSamples.slice(1)]),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000030", field: "samples" },
});

// A late discrete break with an earlier float drift: the FIRST divergence must
// be the earlier one (ordering is by tick, then by the frozen field order).
runCase({
  name: "R13-earliest-wins",
  left: () => liveStreamText,
  right: () =>
    renderGd(
      setField(perturbComponent(baseSamples, "000480", "ball", "y", 0.25), "000900", "rngState", "77"),
    ),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000480", field: "ball.y" },
});

// A break that propagates: every sampled tick from an injected tick onward
// differs, so the cascade counter must report the tail as dependent, not as
// separate findings.
runCase({
  name: "R21-cascade-counted-not-listed",
  left: () => liveStreamText,
  right: () => {
    const copy = cloneSamples(baseSamples);
    for (const sample of copy) {
      if (sample.values.tick >= "000120") {
        sample.values.rngState = String(Number.parseInt(sample.values.rngState, 10) + 1);
      }
    }
    return renderGd(copy);
  },
  expect: { exit: 1, result: "DIVERGED", firstTick: "000120", field: "rngState", cascadePositive: true },
  extraChecks: [
    (observed) =>
      check(
        "R21 reports exactly one first divergence",
        (observed.stdout.match(/^FIRST-DIVERGENCE /gm) ?? []).length === 1,
        "il report elenca piu' di una prima divergenza",
      ),
  ],
});

// ---------------------------------------------------------------------------
// RED cases: producer contract violations (not comparable, reported as such)
// ---------------------------------------------------------------------------

runCase({
  name: "R14-field-order-swapped",
  left: () => liveStreamText,
  right: () => {
    const copy = cloneSamples(baseSamples);
    const values = copy[findSampleIndex(copy, "000120")].values;
    const line = lineFromValues(values).replace(/rngState=(\S+) rngCalls=(\S+)/, "rngCalls=$2 rngState=$1");
    // rebuild the stream text with one line replaced verbatim
    const text = renderGd(copy);
    return text.replace(lineFromValues(values), line);
  },
  expect: { exit: 2, result: "NOT-COMPARABLE" },
  extraChecks: [
    (observed) =>
      check(
        "R14 names the offending position",
        /ordine dei campi non conforme in posizione 1/.test(observed.stdout),
        "il report non indica la posizione dell'ordine errato",
      ),
  ],
});

runCase({
  name: "R15-missing-field",
  left: () => liveStreamText,
  right: () => {
    const copy = cloneSamples(baseSamples);
    const values = copy[findSampleIndex(copy, "000240")].values;
    const line = lineFromValues(values).replace(/ serveAttempts=\S+/, "");
    const text = renderGd(copy);
    return text.replace(lineFromValues(values), line);
  },
  expect: { exit: 2, result: "NOT-COMPARABLE" },
});

runCase({
  name: "R16-seed-mismatch",
  left: () => liveStreamText,
  right: () => renderGd(baseSamples).replace(/seed=12345/g, "seed=999"),
  expect: { exit: 2, result: "NOT-COMPARABLE" },
  extraChecks: [
    (observed) =>
      check("R16 explains the parameter clash", /seed: left=12345 right=999/.test(observed.stdout), "manca il dettaglio del seed"),
  ],
});

runCase({
  name: "R17-tampered-line-intact-summary",
  left: () => liveStreamText,
  right: () => {
    const text = renderGd(baseSamples);
    // tamper a value WITHOUT refreshing the summary digest: integrity must fire
    const target = lineFromValues(baseSamples[findSampleIndex(baseSamples, "000060")].values);
    return text.replace(target, target.replace("player=(568.000000,486.000000)", "player=(568.000000,486.000001)"));
  },
  expect: { exit: 2, result: "NOT-COMPARABLE" },
  extraChecks: [
    (observed) =>
      check(
        "R17 reports the integrity break",
        /integrita'/.test(observed.stdout),
        "il report non menziona l'integrita' del digest",
      ),
  ],
});

runCase({
  name: "R18-duplicate-tick",
  left: () => liveStreamText,
  right: () => {
    const copy = cloneSamples(baseSamples);
    const duplicate = { tick: copy[2].tick, values: { ...copy[2].values } };
    copy.splice(3, 0, duplicate);
    return renderGd(copy, { summary: false });
  },
  expect: { exit: 2, result: "NOT-COMPARABLE" },
});

runCase({
  name: "R19-truncated-stale-summary",
  left: () => liveStreamText,
  right: () => {
    // Remove the tail digest lines but KEEP the original summary line: the
    // declared sampledTicks/digestSha256 no longer describe the stream.
    const text = renderGd(baseSamples);
    const lines = text.split("\n");
    const digestIndexes = lines
      .map((line, index) => (line.startsWith("tick=") ? index : -1))
      .filter((index) => index !== -1);
    for (const index of digestIndexes.slice(-5)) lines[index] = "__REMOVED__";
    return lines.filter((line) => line !== "__REMOVED__").join("\n");
  },
  expect: { exit: 2, result: "NOT-COMPARABLE" },
  extraChecks: [
    (observed) =>
      check(
        "R19 reports the integrity break",
        /integrita'/.test(observed.stdout),
        "il report non menziona l'integrita' del digest",
      ),
  ],
});

runCase({
  name: "R19b-shorter-consistent-grid",
  left: () => liveStreamText,
  right: () => renderGd(cloneSamples(baseSamples).slice(0, 20)),
  expect: { exit: 1, result: "DIVERGED", firstTick: "001200", field: "samples" },
});

runCase({
  name: "R20-producer-self-reported-fail",
  left: () => liveStreamText,
  right: () => renderGd(baseSamples).replace("PARITY-DIGEST SYNTH PASS", "PARITY-DIGEST GD FAIL"),
  expect: { exit: 0, result: "IDENTICAL" },
  extraChecks: [
    (observed) =>
      check(
        "R20 surfaces the producer verdict as a warning",
        /WARNING \[right\]/.test(observed.stdout) && /PRODUCER-SELF-CHECK/.test(observed.stdout),
        "il verdetto FAIL del producer non e' stato riportato come warning",
      ),
  ],
});

// ...and the same FAIL verdict must NOT mask a real field divergence.
runCase({
  name: "R20b-fail-verdict-does-not-mask-drift",
  left: () => liveStreamText,
  right: () =>
    renderGd(bumpInt(baseSamples, "000060", "rngCalls", 1)).replace("PARITY-DIGEST SYNTH PASS", "PARITY-DIGEST GD FAIL"),
  expect: { exit: 1, result: "DIVERGED", firstTick: "000060", field: "rngCalls" },
});

// ---------------------------------------------------------------------------
// Usage / IO errors
// ---------------------------------------------------------------------------

console.log("\n# USAGE: misuse must fail loudly, never silently compare");

const usageCases = [
  { name: "U1-one-argument", args: [jsPath], exit: 3 },
  { name: "U2-bad-tol", args: [jsPath, jsPath, "--tol=-1"], exit: 3 },
  { name: "U3-missing-file", args: [jsPath, path.join(FIXTURES, "does-not-exist.txt")], exit: 3 },
  { name: "U4-unknown-flag", args: [jsPath, jsPath, "--nope"], exit: 3 },
];
for (const spec of usageCases) {
  const observed = spawnSync(process.execPath, [COMPARE, ...spec.args], { cwd: ROOT, encoding: "utf8" });
  const ok = check(`${spec.name} exit`, observed.status === spec.exit, `atteso exit ${spec.exit}, ottenuto ${observed.status}`);
  cases.push({ name: spec.name, ok, result: "USAGE", firstTick: null, firstField: null });
  console.log(`${ok ? "  ok  " : " FAIL "} ${spec.name.padEnd(38)} exit=${observed.status}`);
}

// ---------------------------------------------------------------------------

const green = cases.filter((entry) => /^G/.test(entry.name));
const red = cases.filter((entry) => /^R/.test(entry.name));
const usage = cases.filter((entry) => /^U/.test(entry.name));
const failed = cases.filter((entry) => !entry.ok);

console.log("\n# fixtures written for manual re-runs:");
writeFileSync(
  path.join(FIXTURES, "README.md"),
  [
    "# parity-compare fixtures",
    "",
    "Synthetic streams generated by `tools/parity/parity-compare-selftest.mjs`.",
    "`js-seed12345-live.txt` is the REAL stdout of `scripts/parity-digest.mjs` captured live.",
    "Everything else is that stream plus ONE injected difference (the GDScript side does not exist yet).",
    "",
    "Re-run any single pair with:",
    "",
    "```",
    "node tools/parity/parity-compare.mjs <left.txt> <right.txt> [--tol=0.001]",
    "```",
    "",
    "Exit codes: 0 IDENTICAL, 1 DIVERGED, 2 NOT-COMPARABLE, 3 usage/IO.",
    "",
  ].join("\n"),
  "utf8",
);
for (const entry of cases) console.log(`  tools/parity/fixtures/${entry.name}.*.txt`);

console.log(
  `\nSELFTEST ${failed.length === 0 ? "PASS" : "FAIL"} cases=${cases.length} ` +
    `green=${green.length} red=${red.length} usage=${usage.length} failed=${failed.length}`,
);
if (failed.length) {
  console.log(`FAILED: ${failed.map((entry) => entry.name).join(", ")}`);
  process.exit(1);
}
process.exit(0);
