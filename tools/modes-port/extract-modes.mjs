/**
 * extract-modes.mjs — dump the FROZEN game-modes tables out of `js/data.js` and
 * `js/drill.js` into the JSON the GDScript modes layer loads.
 *
 * Why a generator and not hand-typed GDScript constants: `docs/wayfinder/
 * tickets/simulation-port-boundary.md` §5 makes `js/**` authoritative and forbids
 * retyping the tables during the port. The career season shape, the metric
 * aggregation, the objective pool, the ramp and its caps, the unlock rules, the
 * 26 outfits and the four drill exercises are the rules the three reference
 * audits assert; typing them by hand is exactly how a port silently re-tunes the
 * game. This script reads the real modules and serialises them.
 *
 * It writes two files:
 *
 *   godot/src/modes/data/modes.json          the runtime tables
 *   godot/tests/modes/data/reference-grid.json  the reference FUNCTIONS evaluated
 *                                            over a grid, so the ported GDScript
 *                                            formulas are checked against the
 *                                            reference's own output instead of
 *                                            against a second reading of them
 *
 * It does not modify `js/**`. It only reads.
 *
 *   node tools/modes-port/extract-modes.mjs
 */

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  ARENAS,
  ATHLETE_OUTFITS,
  CAREER_FINAL_SEASON,
  CAREER_MATCHES,
  CAREER_POINTS_TO_WIN,
  CAREER_PROMOTION_WINS,
  CAREER_RAMP,
  OBJECTIVE_DEFS,
  SEASON_METRIC_AGG,
  UNLOCK_CODE,
  careerAiProfile,
  careerFixture,
  careerRival,
  emptySeasonProgress,
  matchObjective,
  seasonObjectives,
  tournamentFixture,
} from "../../js/data.js?v=20260814-feedback-v38";
import { DRILL_EXERCISES, exerciseById } from "../../js/drill.js?v=20260814-feedback-v38";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");
const runtimeTarget = path.join(repoRoot, "godot", "src", "modes", "data", "modes.json");
const gridTarget = path.join(repoRoot, "godot", "tests", "modes", "data", "reference-grid.json");

/** The drill's own numeric constants, read out of the source that declares them.
 *
 *  They are module-level `const`s in `js/drill.js` and not exported, so they are
 *  read from the file text with a single narrow pattern rather than re-typed.
 *  A missing constant is a hard failure: a silently defaulted target radius or
 *  squash reference would be a re-tuned drill. */
function drillConstants(source, names) {
  const out = {};
  for (const name of names) {
    const match = source.match(new RegExp(`^const ${name} = ([-0-9.eE]+);`, "m"));
    if (!match) throw new Error(`js/drill.js: costante '${name}' non trovata`);
    out[name] = Number(match[1]);
  }
  return out;
}

function assertPlain(value, trail) {
  if (typeof value === "function") throw new Error(`funzione non serializzabile in ${trail}`);
  if (value === undefined) throw new Error(`undefined in ${trail}`);
  if (Array.isArray(value)) value.forEach((item, i) => assertPlain(item, `${trail}[${i}]`));
  else if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value)) assertPlain(v, `${trail}.${k}`);
  }
}

const dataSource = await readFile(path.join(repoRoot, "js", "data.js"), "utf8");
const drillSource = await readFile(path.join(repoRoot, "js", "drill.js"), "utf8");

const constants = drillConstants(drillSource, ["TARGET_R", "BULLSEYE", "SQUASH_FLAT", "SQUASH_LOW", "FREEZE"]);

// The outfits carry `unlockKey` and `athleteId`, added by `js/data.js:799-804`.
// The same two fields are asserted by `scripts/outfit-challenges-audit.mjs:45-46`
// (unique keys) and by `isUnlocked` (`js/data.js:702-710`), so they travel.
const outfits = Object.fromEntries(
  Object.entries(ATHLETE_OUTFITS).map(([athleteId, list]) => [
    athleteId,
    list.map((outfit) => ({
      id: outfit.id,
      nameKey: outfit.nameKey,
      unlockKey: outfit.unlockKey,
      athleteId: outfit.athleteId,
      colors: outfit.colors,
      challenge: outfit.challenge ?? null,
      unlock: outfit.unlock ?? null,
    })),
  ]),
);

const runtime = {
  generatedBy: "tools/modes-port/extract-modes.mjs",
  source: ["js/data.js", "js/drill.js"],
  sourceSha256: {
    "js/data.js": createHash("sha256").update(dataSource).digest("hex"),
    "js/drill.js": createHash("sha256").update(drillSource).digest("hex"),
  },
  career: {
    matches: CAREER_MATCHES,
    pointsToWin: CAREER_POINTS_TO_WIN,
    promotionWins: CAREER_PROMOTION_WINS,
    finalSeason: CAREER_FINAL_SEASON,
    ramp: CAREER_RAMP,
    seasonMetricAgg: SEASON_METRIC_AGG,
    objectiveDefs: OBJECTIVE_DEFS,
    unlockCode: UNLOCK_CODE,
  },
  outfits,
  drill: {
    exercises: DRILL_EXERCISES,
    targetR: constants.TARGET_R,
    bullseye: constants.BULLSEYE,
    squashFlat: constants.SQUASH_FLAT,
    squashLow: constants.SQUASH_LOW,
    freeze: constants.FREEZE,
  },
};

assertPlain(runtime, "modes");

// ---------------------------------------------------------------------------
// The grid: the reference FUNCTIONS evaluated, so the ported formulas are
// checked against the reference's own output rather than against a second
// hand-transcription of them. Domains are wider than any audit's own sweep so a
// transcription that is only right on the audited points still fails.
// ---------------------------------------------------------------------------

const SEASONS = 40;
const PROFILE_SEASONS = 121; // covers `career-audit.mjs:207`'s season 120
const MATCHES = CAREER_MATCHES;
const ARENA_COUNTS = [0, 1, 2, 3, 4, 9];
const ROUNDS = [0, 1, 2, 3, 4];

const grid = {
  generatedBy: "tools/modes-port/extract-modes.mjs",
  source: ["js/data.js"],
  sourceSha256: runtime.sourceSha256,
  seasonObjectives: [],
  matchObjective: [],
  careerRival: [],
  careerAiProfile: [],
  careerFixture: [],
  tournamentFixture: [],
  emptySeasonProgress: emptySeasonProgress(),
  objectiveIdsInSeasons: [],
};

for (let season = 1; season <= SEASONS; season += 1) {
  grid.seasonObjectives.push({ season, objectives: seasonObjectives(season) });
  grid.careerRival.push({ season, rival: careerRival(season).id });
  for (let m = 0; m < MATCHES; m += 1) {
    grid.matchObjective.push({ season, matchIndex: m, objective: matchObjective(season, m) });
  }
}

// `careerFixture`'s arena pool is the third argument, so the grid dumps explicit
// pools: `0` is the empty list (the reference falls back to all `ARENAS`) and
// `n` is `ARENAS.slice(0, n)`, the same sweep `scripts/tournament-audit.mjs:41-51`
// performs.
for (let season = 1; season <= SEASONS; season += 1) {
  for (let m = 0; m < MATCHES; m += 1) {
    for (const count of ARENA_COUNTS) {
      const pool = count === 0 ? [] : ARENAS.slice(0, count);
      const fx = careerFixture(season, m, pool);
      grid.careerFixture.push({ season, matchIndex: m, arenaCount: count, arena: fx.arena.id, rival: fx.rival.id });
    }
  }
}
for (const round of ROUNDS) {
  for (const count of ARENA_COUNTS) {
    const pool = count === 0 ? [] : ARENAS.slice(0, count);
    grid.tournamentFixture.push({ round, arenaCount: count, arena: tournamentFixture(round, pool).arena.id });
  }
}
for (let season = 1; season <= PROFILE_SEASONS; season += 1) {
  for (let m = 0; m < MATCHES; m += 1) {
    const profile = careerAiProfile(season, m);
    grid.careerAiProfile.push({
      season,
      matchIndex: m,
      id: profile.id,
      skill: profile.skill,
      speed: profile.speed,
      power: profile.power,
    });
  }
}
{
  const seen = new Set();
  for (let season = 1; season <= SEASONS; season += 1) seasonObjectives(season).forEach((o) => seen.add(o.id));
  grid.objectiveIdsInSeasons = [...seen].sort();
}

assertPlain(grid, "grid");

const runtimeText = `${JSON.stringify(runtime, null, 2)}\n`;
const gridText = `${JSON.stringify(grid, null, 2)}\n`;
await mkdir(path.dirname(runtimeTarget), { recursive: true });
await mkdir(path.dirname(gridTarget), { recursive: true });
await writeFile(runtimeTarget, runtimeText, "utf8");
await writeFile(gridTarget, gridText, "utf8");

console.log(`# js/data.js sha256=${runtime.sourceSha256["js/data.js"]}`);
console.log(`# js/drill.js sha256=${runtime.sourceSha256["js/drill.js"]}`);
console.log(`# wrote ${path.relative(repoRoot, runtimeTarget)} sha256=${createHash("sha256").update(runtimeText).digest("hex")}`);
console.log(`# wrote ${path.relative(repoRoot, gridTarget)} sha256=${createHash("sha256").update(gridText).digest("hex")}`);
console.log(`# seasons=${CAREER_MATCHES} objectives=${Object.keys(OBJECTIVE_DEFS).length} outfits=${Object.values(outfits).flat().length} exercises=${DRILL_EXERCISES.length} exercisesById=${DRILL_EXERCISES.map((e) => exerciseById(e.id).id).join(",")}`);
console.log(`# grid seasonObjectives=${grid.seasonObjectives.length} matchObjective=${grid.matchObjective.length} careerAiProfile=${grid.careerAiProfile.length} careerFixture=${grid.careerFixture.length} tournamentFixture=${grid.tournamentFixture.length}`);
