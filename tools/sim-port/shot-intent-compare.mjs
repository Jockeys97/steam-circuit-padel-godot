/**
 * shot-intent-compare.mjs — the verdict for the shot-intent parity trace.
 *
 * Two streams of `# trace <json>` lines (the reference's, from
 * `tools/sim-port/shot-intent-probe.mjs`, and the port's, from
 * `godot/tests/shot_logic_parity_test.gd`) are compared scenario by scenario and
 * field by field, in the order the rows were printed.
 *
 * It compares the PARSED json, not the raw text, so a difference in key order or
 * in JSON escaping is not a difference — and it names the first differing field
 * per scenario instead of dumping two walls of text.
 *
 * Floats were already formatted to 6 decimals by BOTH sides (`%.6f`), so the
 * comparison is exact at the reference's printed precision — the same rule as
 * `tools/parity/**` (`--tol=0`). No tolerance is applied anywhere.
 *
 * Exit codes: 0 IDENTICAL, 1 DIVERGED, 2 NOT-COMPARABLE (a scenario present on
 * one side only, a missing row, a malformed line), 3 usage/IO.
 *
 * Usage:
 *   node tools/sim-port/shot-intent-compare.mjs \
 *     --js=tools/sim-port/out/shot-intent-js.txt \
 *     --gd=tools/sim-port/out/shot-intent-gd.txt
 */

import { readFileSync } from "node:fs";

function arg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const jsPath = arg("js", "tools/sim-port/out/shot-intent-js.txt");
const gdPath = arg("gd", "tools/sim-port/out/shot-intent-gd.txt");

const TRACE = "# trace ";

/**
 * The differences that are REPRESENTATION, not behaviour, each one named with the
 * values it is expected to produce. They are printed as `# known-difference` lines
 * and counted separately — a run whose only differences are these is IDENTICAL.
 * Hiding them in a tolerance would be the thing this list exists to avoid.
 *
 *   wallKill — `createBall` (`js/game.js:74-107`) has no `wallKill` key (it is first
 *   written in `hitBall`, `js/game.js:1506`), so the reference's trace prints null;
 *   `godot/src/sim/entities.gd` declares it `0.0`. Both engines only ever assign it
 *   or compare it numerically, and the value is 0 on both sides after any hit.
 */
const KNOWN_REPRESENTATION_DIFFERENCES = {
  "intent/serve|wallKill": { js: null, gd: "0.000000" },
  "intent/serve/slice|wallKill": { js: null, gd: "0.000000" },
};

function knownDifference(name, field, jsValue, gdValue) {
  const declared = KNOWN_REPRESENTATION_DIFFERENCES[`${name}|${field}`];
  if (!declared) return false;
  if (declared.js !== jsValue || declared.gd !== gdValue) return false;
  console.log(`# known-difference ${name} ${field}: js=${JSON.stringify(jsValue)} gd=${JSON.stringify(gdValue)} (representation, declared in the test and in the evidence)`);
  return true;
}

function readTraces(path) {
  const text = readFileSync(path, "utf8");
  const rows = [];
  const bad = [];
  for (const line of text.split("\n")) {
    if (!line.startsWith(TRACE)) continue;
    try {
      rows.push(JSON.parse(line.slice(TRACE.length)));
    } catch (err) {
      bad.push(line.slice(0, 120));
    }
  }
  return { rows, bad };
}

const js = readTraces(jsPath);
const gd = readTraces(gdPath);

if (js.bad.length || gd.bad.length) {
  console.log(`NOT-COMPARABLE malformed trace line(s): js=${js.bad.length} gd=${gd.bad.length}`);
  for (const line of [...js.bad, ...gd.bad]) console.log(`  ${line}`);
  process.exit(2);
}

const byName = (rows) => new Map(rows.map((r) => [r.scenario, r]));
const jsByName = byName(js.rows);
const gdByName = byName(gd.rows);

const onlyJs = [...jsByName.keys()].filter((k) => !gdByName.has(k));
const onlyGd = [...gdByName.keys()].filter((k) => !jsByName.has(k));
if (onlyJs.length || onlyGd.length) {
  console.log(`NOT-COMPARABLE scenario sets differ: only-js=[${onlyJs}] only-gd=[${onlyGd}]`);
  process.exit(2);
}

let diverged = 0;
let compared = 0;
for (const [name, jsRow] of jsByName) {
  const gdRow = gdByName.get(name);
  const fields = new Set([...Object.keys(jsRow), ...Object.keys(gdRow)]);
  for (const field of fields) {
    compared += 1;
    if (field === "flags") {
      const want = jsRow.flags ?? {};
      const got = gdRow.flags ?? {};
      const keys = new Set([...Object.keys(want), ...Object.keys(got)]);
      for (const key of keys) {
        compared += 1;
        if (want[key] !== got[key] && !knownDifference(name, `flags.${key}`, want[key], got[key])) {
          diverged += 1;
          console.log(`DIVERGED ${name} flags.${key}: js=${JSON.stringify(want[key])} gd=${JSON.stringify(got[key])}`);
        }
      }
      continue;
    }
    if (jsRow[field] !== gdRow[field] && !knownDifference(name, field, jsRow[field], gdRow[field])) {
      diverged += 1;
      console.log(`DIVERGED ${name} ${field}: js=${JSON.stringify(jsRow[field])} gd=${JSON.stringify(gdRow[field])}`);
    }
  }
}

console.log(`# scenarios js=${js.rows.length} gd=${gd.rows.length} fields_compared=${compared}`);
if (diverged === 0) {
  console.log(`IDENTICAL ${js.rows.length}/${js.rows.length} scenarios, ${compared} field comparisons, tol=0`);
  process.exit(0);
}
console.log(`DIVERGED ${diverged} field comparison(s)`);
process.exit(1);
