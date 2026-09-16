#!/usr/bin/env node
/**
 * compare-match.mjs — the verdict tool of the cross-engine *match* parity proof.
 *
 * It answers two questions about a pair of `ref-match.mjs` / `match_digest_gd.gd`
 * streams and never asserts one from the other:
 *
 *   1. ENGINE PARITY — the frozen gate. It delegates to the established
 *      comparator `tools/parity/parity-compare.mjs` (strict, `--tol=0`, all 21
 *      fields of the frozen digest line, tick by tick) and reports its exit code
 *      and the first-divergence line verbatim. Exit 0/1/2 are propagated.
 *
 *   2. EVENT COVERAGE + EVENT PARITY — this tool's own contribution. The match is
 *      only evidence for the behaviours in its *name* if those behaviours
 *      actually happened, and the digest line does not print the net-cord flag,
 *      the glass marker, the serve strike or the double-fault counter. So the
 *      `# ev` comment families are read back and:
 *        - counted (proving the scenario contained what it claims to contain, and
 *          asserted against `--require=<family[,family]>` when given);
 *        - compared tick by tick and value by value across the two engines for
 *          every family whose text is engine-neutral (net-cord, glass, wall,
 *          strike, double-fault, set-closed, result);
 *        - compared by TICK ONLY for `family=message`, because the reference
 *          stores localized display text in `state.events` while the port stores
 *          message ids (`state.gd:18`) — the same limitation
 *          `tools/sim-port/trace-compare.py:14-17` documents.
 *
 * Usage:
 *   node tools/parity-godot/compare-match.mjs <js-stream> <gd-stream> \
 *     [--require=net-cord,glass,double-fault] [--json=<path>] [--quiet]
 *
 * Exit codes: 0 IDENTICAL, 1 DIVERGED (digest or event), 2 malformed / NOT-DONE,
 * 3 usage/IO. A missing required family is exit 2: the run is not evidence for
 * the scenario it claims to be.
 */

import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { parseStream, summarizeStream } from "../parity/parity-stream.mjs";

const EXIT = { IDENTICAL: 0, DIVERGED: 1, NOT_DONE: 2, USAGE: 3 };
const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");
const PARITY_COMPARE = path.join(REPO, "tools", "parity", "parity-compare.mjs");

/** `# ev tick=NNNNNN family=<name> <detail>` (see ref-match.mjs). */
const EV_LINE = /^# ev tick=(\d{6}) family=([a-z-]+)(?: (.*))?$/;

/** Families whose `detail` text is engine-neutral and therefore comparable. */
const VALUE_FAMILIES = new Set([
  "net-cord",
  "glass",
  "wall",
  "strike",
  "double-fault",
  "set-closed",
  "result",
]);
/** Compared by tick only (localized text on one side, message ids on the other). */
const TICK_ONLY_FAMILIES = new Set(["message"]);
const KNOWN_FAMILIES = new Set([...VALUE_FAMILIES, ...TICK_ONLY_FAMILIES]);

let quiet = false;
const emit = (line) => {
  if (!quiet) console.log(line);
};
const always = (line) => console.log(line);

function usageError(message) {
  console.error(`MATCH-COMPARE USAGE: ${message}`);
  console.error("  node tools/parity-godot/compare-match.mjs <js-stream> <gd-stream> [--require=…] [--json=<path>] [--quiet]");
  process.exit(EXIT.USAGE);
}

function parseArgs(argv) {
  const out = { require: [], json: null, quiet: false, positionals: [] };
  for (const raw of argv) {
    const match = /^--([a-z-]+)(?:=(.*))?$/.exec(raw);
    if (!match) {
      out.positionals.push(raw);
      continue;
    }
    const [, name, value] = match;
    if (name === "require") out.require = String(value ?? "").split(",").filter(Boolean);
    else if (name === "json") out.json = value ?? null;
    else if (name === "quiet") out.quiet = true;
    else usageError(`opzione sconosciuta: --${name}`);
  }
  if (out.positionals.length !== 2) usageError(`servono esattamente due stream, ricevuti ${out.positionals.length}`);
  return out;
}

function read(pathSpec) {
  try {
    return readFileSync(pathSpec, "utf8");
  } catch (error) {
    console.error(`MATCH-COMPARE IO: impossibile leggere "${pathSpec}": ${error.message}`);
    process.exit(EXIT.USAGE);
  }
}

/** Ordered `{tick, family, detail}` records, in stream order. */
function eventsOf(text) {
  const events = [];
  const seen = new Map();
  for (const raw of text.replace(/\r\n/g, "\n").split("\n")) {
    const match = EV_LINE.exec(raw.trim());
    if (!match) continue;
    const [, tick, family, detail] = match;
    const index = seen.get(family) ?? 0;
    seen.set(family, index + 1);
    events.push({ tick, family, detail: detail ?? "", ordinal: index });
  }
  return events;
}

function familyCounts(events) {
  const counts = {};
  for (const event of events) counts[event.family] = (counts[event.family] ?? 0) + 1;
  return counts;
}

function describe(event) {
  return `${event.tick} family=${event.family} ${TICK_ONLY_FAMILIES.has(event.family) ? "(tick-only)" : event.detail}`;
}

/**
 * Ordered, element-wise comparison. `message` events contribute their tick only,
 * so a wording difference (by design) is not reported as a divergence while a
 * changed *timing* is.
 */
function compareEvents(jsEvents, gdEvents) {
  const key = (event) =>
    TICK_ONLY_FAMILIES.has(event.family)
      ? `${event.tick}|${event.family}`
      : `${event.tick}|${event.family}|${event.detail}`;
  const jsUnknown = jsEvents.filter((event) => !KNOWN_FAMILIES.has(event.family));
  const gdUnknown = gdEvents.filter((event) => !KNOWN_FAMILIES.has(event.family));
  const length = Math.max(jsEvents.length, gdEvents.length);
  let firstDivergence = null;
  let mismatched = 0;
  for (let i = 0; i < length; i += 1) {
    const a = jsEvents[i] ?? null;
    const b = gdEvents[i] ?? null;
    const equal = a !== null && b !== null && key(a) === key(b);
    if (!equal) {
      mismatched += 1;
      if (!firstDivergence) {
        firstDivergence = {
          index: i,
          tick: a?.tick ?? b?.tick ?? null,
          family: a?.family ?? b?.family ?? null,
          js: a ? describe(a) : "(absent)",
          gd: b ? describe(b) : "(absent)",
        };
      }
    }
  }
  return { length, mismatched, firstDivergence, jsUnknown: jsUnknown.length, gdUnknown: gdUnknown.length };
}

function runParityCompare(jsPath, gdPath, jsonPath) {
  // The full human report is captured (no --quiet) so the first divergence is
  // quoted verbatim in this tool's output; only its summary lines are re-emitted.
  const args = [PARITY_COMPARE, jsPath, gdPath];
  if (jsonPath) args.push(`--json=${jsonPath}`);
  const result = spawnSync(process.execPath, args, { cwd: REPO, encoding: "utf8" });
  if (result.error) {
    return { status: EXIT.USAGE, stdout: "", stderr: `spawn fallito: ${result.error.message}` };
  }
  return { status: result.status, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  quiet = options.quiet;
  const [jsPath, gdPath] = options.positionals;

  const jsText = read(jsPath);
  const gdText = read(gdPath);
  const jsStream = parseStream(jsText, { label: "js", sourcePath: path.resolve(jsPath) });
  const gdStream = parseStream(gdText, { label: "gd", sourcePath: path.resolve(gdPath) });

  const jsEvents = eventsOf(jsText);
  const gdEvents = eventsOf(gdText);
  const jsCounts = familyCounts(jsEvents);
  const gdCounts = familyCounts(gdEvents);

  emit(`# compare-match.mjs js=${jsPath} gd=${gdPath}`);
  emit(`# js  ${summarizeStream(jsStream, "js")}`);
  emit(`# gd  ${summarizeStream(gdStream, "gd")}`);

  // (1) The frozen gate, delegated to the established comparator.
  const pcJson = options.json ? `${options.json.replace(/\.json$/, "")}-parity-compare.json` : null;
  const parity = runParityCompare(jsPath, gdPath, pcJson);
  emit(`# engine-parity: tools/parity/parity-compare.mjs --tol=0 exit=${parity.status}`);
  for (const line of parity.stdout.split("\n")) {
    if (
      /PARITY-COMPARE (RESULT=|IDENTICAL|DIVERGED|NOT-COMPARABLE)|FIRST-DIVERGENCE|CASCADE|MALFORMED|PROBLEM|BRANCH-MISMATCH|FLOAT-DRIFT|GRID-MISMATCH|^  (left|right|delta|note|detail)/.test(
        line,
      )
    ) {
      emit(`#   ${line.trim()}`);
    }
  }
  if (parity.stderr.trim()) emit(`#   stderr: ${parity.stderr.trim()}`);

  // (2) Coverage of the behaviours the scenario claims.
  emit(
    `# event-counts js: ${Object.entries(jsCounts).sort().map(([k, v]) => `${k}=${v}`).join(" ") || "(none)"}`,
  );
  emit(
    `# event-counts gd: ${Object.entries(gdCounts).sort().map(([k, v]) => `${k}=${v}`).join(" ") || "(none)"}`,
  );
  const missing = [];
  for (const family of options.require) {
    if (!(jsCounts[family] > 0)) missing.push(`js:${family}`);
    if (!(gdCounts[family] > 0)) missing.push(`gd:${family}`);
  }
  if (options.require.length) {
    emit(
      `# required-families ${options.require.join(",")} -> ${missing.length ? `MISSING ${missing.join(" ")}` : "present on both engines"}`,
    );
  }

  // (3) Event parity.
  const events = compareEvents(jsEvents, gdEvents);
  emit(
    `# event-parity: js=${jsEvents.length} gd=${gdEvents.length} records, ` +
      `mismatched=${events.mismatched} (message family compared by tick only)`,
  );
  if (events.jsUnknown || events.gdUnknown) {
    emit(`# event-parity: unknown families js=${events.jsUnknown} gd=${events.gdUnknown}`);
  }
  if (events.firstDivergence) {
    emit(`# first-event-divergence index=${events.firstDivergence.index} tick=${events.firstDivergence.tick} family=${events.firstDivergence.family}`);
    emit(`#   js: ${events.firstDivergence.js}`);
    emit(`#   gd: ${events.firstDivergence.gd}`);
  }

  const digestVerdict =
    parity.status === 0 ? "IDENTICAL" : parity.status === 1 ? "DIVERGED" : "NOT-COMPARABLE";
  const eventVerdict = events.mismatched === 0 && !events.jsUnknown && !events.gdUnknown ? "IDENTICAL" : "DIVERGED";
  const coverageVerdict = missing.length === 0 ? "OK" : "MISSING";

  let verdict;
  let code;
  if (missing.length) {
    verdict = "NOT-DONE";
    code = EXIT.NOT_DONE;
  } else if (digestVerdict === "IDENTICAL" && eventVerdict === "IDENTICAL") {
    verdict = "IDENTICAL";
    code = EXIT.IDENTICAL;
  } else if (digestVerdict === "NOT-COMPARABLE") {
    verdict = "NOT-COMPARABLE";
    code = EXIT.NOT_DONE;
  } else {
    verdict = "DIVERGED";
    code = EXIT.DIVERGED;
  }

  const payload = {
    tool: "tools/parity-godot/compare-match.mjs",
    js: { path: jsPath, sampledTicks: jsStream.samples.length, digestSha256: jsStream.meta.digestSha256 },
    gd: { path: gdPath, sampledTicks: gdStream.samples.length, digestSha256: gdStream.meta.digestSha256 },
    digestVerdict,
    parityCompareExit: parity.status,
    eventVerdict,
    coverageVerdict,
    requiredFamilies: options.require,
    missingFamilies: missing,
    eventCounts: { js: jsCounts, gd: gdCounts },
    eventRecords: { js: jsEvents.length, gd: gdEvents.length, mismatched: events.mismatched },
    firstEventDivergence: events.firstDivergence,
    verdict,
  };
  if (options.json) {
    const target = path.resolve(process.cwd(), options.json);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    emit(`# json=${target}`);
  }

  always(
    `MATCH-COMPARE RESULT=${verdict} digest=${digestVerdict} events=${eventVerdict} coverage=${coverageVerdict} ` +
      `sampledTicks=${jsStream.samples.length}/${gdStream.samples.length} ` +
      `digestSha256=${jsStream.meta.digestSha256 ?? "-"}${jsStream.meta.digestSha256 === gdStream.meta.digestSha256 ? " (identical)" : " (DIFFERENT)"}`,
  );
  process.exit(code);
}

try {
  main();
} catch (error) {
  console.error(`MATCH-COMPARE ERROR: ${error?.stack ?? error}`);
  process.exit(EXIT.USAGE);
}
