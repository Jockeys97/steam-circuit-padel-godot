/**
 * extract-constants.mjs — dump the FROZEN simulation tables out of `js/data.js`
 * into a JSON file the GDScript sim core loads at runtime.
 *
 * Why a generator and not a hand-typed GDScript constant block: the boundary
 * ticket (`docs/wayfinder/tickets/simulation-port-boundary.md` §5) says the
 * tables are authoritative in `js/data.js` and must NOT be retuned or invented
 * during the port. Copying 163 BALANCE keys by hand is exactly how a port
 * silently re-tunes the game. This script reads the real module and serialises
 * it, so the numbers are the numbers, byte for byte.
 *
 * It does not modify `js/**`. It only reads.
 *
 * Usage:
 *   node tools/sim-port/extract-constants.mjs
 */

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  AI_OPPONENTS,
  ARENAS,
  ATHLETES,
  BALANCE,
  COURT,
  EVENT_LINES,
  MATCH_FORMATS,
  ROSTER_AVERAGE,
  VERSION,
  WIN_SCORE,
} from "../../js/data.js?v=20260814-feedback-confirm-v39";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");
const dataSource = path.join(repoRoot, "js", "data.js");
const target = path.join(repoRoot, "godot", "src", "sim", "frozen", "data.json");

// FUNCTIONS in the tables are dropped by JSON.stringify. Dropping one silently
// would be a hole in the port, so refuse instead.
function assertPlain(value, trail) {
  if (typeof value === "function") throw new Error(`funzione non serializzabile in ${trail}`);
  if (value === undefined) throw new Error(`undefined in ${trail}`);
  if (Array.isArray(value)) value.forEach((item, i) => assertPlain(item, `${trail}[${i}]`));
  else if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value)) assertPlain(v, `${trail}.${k}`);
  }
}

const payload = {
  generatedBy: "tools/sim-port/extract-constants.mjs",
  source: "js/data.js",
  court: COURT,
  winScore: WIN_SCORE,
  version: VERSION,
  balance: BALANCE,
  athletes: ATHLETES,
  rosterAverage: ROSTER_AVERAGE,
  arenas: ARENAS,
  matchFormats: MATCH_FORMATS,
  aiOpponents: AI_OPPONENTS,
  eventLines: EVENT_LINES,
};

assertPlain(payload, "data");

const serialized = `${JSON.stringify(payload, null, 2)}\n`;
await mkdir(path.dirname(target), { recursive: true });
await writeFile(target, serialized, "utf8");

const sourceText = await readFile(dataSource, "utf8");
console.log(`# source js/data.js sha256=${createHash("sha256").update(sourceText).digest("hex")}`);
console.log(`# wrote ${path.relative(repoRoot, target)} sha256=${createHash("sha256").update(serialized).digest("hex")}`);
console.log(`# balance keys=${Object.keys(BALANCE).length} athletes=${ATHLETES.length} arenas=${ARENAS.length} aiTiers=${AI_OPPONENTS.length} eventLines=${EVENT_LINES.length}`);
