#!/usr/bin/env node
/**
 * ai-contact-census.mjs — counts what the opponent AI actually plays on the
 * JavaScript side, on the same seeded scenarios the Godot twin uses.
 *
 * It is deliberately read-only about the game: it imports `createMatchState` and
 * `updateMatch` from `js/game.js`, drives them with the frozen parity input
 * recipe (`tools/parity-godot/ref-match.mjs:89-98`), and reports one JSON line
 * per seed:
 *
 *   aiContacts      contacts the AI made inside a rally (`rallyHits` grew while
 *                   `lastHitterSide === "ai"`)
 *   aiVolleys       those contacts with no bounce on the AI's own side yet —
 *                   struck on the fly
 *   aiBounced       those contacts with at least one bounce on the AI's own side
 *                   first — a bounce recovery, or a serve the receiver let land
 *
 * THE COUNT IS NOT READ AFTER THE HIT. `hitBall` resets `ball.bounces` on every
 * contact (`js/game.js:1885`), so a post-tick read always says "0 bounces" and
 * every AI contact looks like a volley. The count below is therefore taken
 * *before* `updateMatch` and corrected for the one thing that can happen earlier
 * in the same tick: `handleGroundBounce` runs before the AI's contact
 * (`js/game.js` step order), and it leaves `ball.bouncePulse = 1`
 * (`js/game.js:2207`). So a same-tick bounce is visible as `bouncePulse === 1`,
 * and — because the AI can only strike a ball on its own side — a bounce in the
 * same tick as an AI contact is a bounce on the AI's side.
 *   aiServeReturns  the subset that came off a serve (the ball had bounced once
 *                   on the AI side, so it overlaps `aiBounced` by design)
 *
 * Usage:
 *   node docs/agent-work/gameplay-fluidity/tools/ai-contact-census.mjs \
 *     [--seeds=12345,999,2024,424242,7] [--ticks=12000] [--out=<path>]
 *
 * Exit 0 when every scenario ran; 1 otherwise.
 */

import { writeFileSync } from "node:fs";

import { createMatchState, updateMatch } from "../../../../js/game.js";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../../../../js/data.js";

const FIXED_STEP = 1 / 120;
const SWING_EVERY = 30;
const CHARGE_FROM_TICK = 60;

const EMPTY_INPUT = {
  left: false,
  right: false,
  up: false,
  down: false,
  moveX: 0,
  moveY: 0,
  charging: false,
  hit: false,
  slice: false,
  shotVariant: null,
  special: false,
  switchPlayer: false,
  switchDirection: null,
  aim: 0,
  aimY: 0,
  analogAim: false,
  splitStep: 0,
  sprint: 0,
  technicalModifier: false,
  teamTactic: null,
  cutVolley: false,
  globo: false,
};

/** The frozen parity recipe (`tools/parity-godot/ref-match.mjs:89-98`). */
function frozenInput(tick) {
  if (tick < CHARGE_FROM_TICK) return { ...EMPTY_INPUT };
  return {
    ...EMPTY_INPUT,
    charging: true,
    hit: tick % SWING_EVERY === 0,
    moveX: ((Math.floor(tick / 120) % 3) - 1) * 0.5,
    moveY: tick % 240 < 120 ? -1 : 0,
  };
}

function arg(name, fallback) {
  const hit = process.argv.find((value) => value.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

function census(seed, ticks) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = seed;
  state.running = true;

  const out = {
    seed,
    ticks: 0,
    resultTick: null,
    aiContacts: 0,
    aiVolleys: 0,
    aiBounced: 0,
    aiServeReturns: 0,
    aiMaxContactZ: 0,
    longestRally: 0,
    points: "0-0",
    contacts: [],
  };

  for (let tick = 0; tick <= ticks; tick += 1) {
    out.ticks = tick;
    if (tick === ticks || state.result) {
      if (state.result) out.resultTick = tick;
      break;
    }
    const servingAtEntry = state.serving;
    const hitsAtEntry = state.rallyHits;
    const bouncesAtEntry = state.ball.bounces.ai;
    updateMatch(state, FIXED_STEP, frozenInput(tick), null);
    const gained = state.rallyHits - hitsAtEntry;
    const aiHit = gained > 0 && state.lastHitterSide === "ai";
    if (aiHit) {
      const bouncedSameTick = state.ball.bouncePulse >= 0.999 ? 1 : 0;
      const bounced = bouncesAtEntry + bouncedSameTick;
      out.aiContacts += gained;
      if (bounced > 0) out.aiBounced += gained;
      else out.aiVolleys += gained;
      // The serve's return is the first rally contact: `rallyHits` is 0 until it.
      if (hitsAtEntry === 0) out.aiServeReturns += gained;
      out.contacts.push({
        tick,
        bounced,
        z: Number(state.ball.z.toFixed(2)),
        y: Number(state.ball.y.toFixed(1)),
        shot: state.ball.shotType,
        glass: state.ball.postGlassSide,
      });
      out.aiMaxContactZ = Math.max(out.aiMaxContactZ, state.ball.z);
    }
  }
  out.longestRally = state.stats.longestRally;
  out.points = `${state.points.player}-${state.points.ai}`;
  return out;
}

const seeds = String(arg("seeds", "12345,999,2024,424242,7"))
  .split(",")
  .map((value) => Number(value.trim()))
  .filter((value) => Number.isFinite(value));
const ticks = Number(arg("ticks", "12000"));

const detailed = process.argv.includes("--detail");
const rows = seeds.map((seed) => census(seed, ticks));
for (const row of rows) {
  const summary = { ...row, aiMaxContactZ: Number(row.aiMaxContactZ.toFixed(2)) };
  if (!detailed) delete summary.contacts;
  console.log(JSON.stringify(summary));
}

const totals = rows.reduce(
  (acc, row) => ({
    aiContacts: acc.aiContacts + row.aiContacts,
    aiVolleys: acc.aiVolleys + row.aiVolleys,
    aiBounced: acc.aiBounced + row.aiBounced,
    aiServeReturns: acc.aiServeReturns + row.aiServeReturns,
  }),
  { aiContacts: 0, aiVolleys: 0, aiBounced: 0, aiServeReturns: 0 },
);
console.log(JSON.stringify({ totals }));

const outPath = arg("out", "");
if (outPath) {
  writeFileSync(outPath, `${rows.map((row) => JSON.stringify(row)).join("\n")}\n`);
}

process.exit(0);
