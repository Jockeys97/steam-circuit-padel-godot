/**
 * parity-digest.mjs — the JavaScript side of the future cross-engine parity
 * comparison.
 *
 * It drives the REAL web simulation (`js/game.js`) with an explicit integer seed
 * and a fixed, scripted per-tick input sequence, and prints one deterministic
 * digest line per sampled tick. The same shape (tick, rngState, rngCalls, ball
 * position and velocity, the four paddles, the score fields) is what a Godot
 * harness must print for the comparison to be possible; see
 * `docs/wayfinder/tickets/simulation-port-boundary.md` §6.
 *
 * This file produces ONLY the JavaScript side. It compares nothing.
 *
 * Usage:
 *   node scripts/parity-digest.mjs [--seed=12345] [--ticks=1440] [--every=60]
 *                                  [--json=<path>] [--quiet]
 *
 * Deliberately NOT named `*-audit.mjs`: `scripts/run-audits.mjs` runs every
 * `*-audit.mjs` and this tool is a digest emitter, not a pass/fail suite.
 */

import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  createMatchState,
  updateMatch,
} from "./js/game.js?v=20260814-feedback-confirm-v39";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "./js/data.js?v=20260814-feedback-confirm-v39";

// ---------------------------------------------------------------------------
// Contract constants. Cited, not invented:
//   FIXED_STEP     -> js/main.js:1164  (`FIXED_STEP = 1 / 120`)
//   MAX_SIM_STEPS  -> js/main.js:1165
// The digest below advances ONE fixed step per tick, which is the shape §6 of
// simulation-port-boundary.md prescribes for the cross-engine comparison
// (per-tick input, not per-frame sampling).
// ---------------------------------------------------------------------------
const FIXED_STEP = 1 / 120;

const DEFAULTS = {
  seed: 12345,
  ticks: 1440,
  every: 60,
};

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

/**
 * The scripted input sequence: a pure function of the tick index, so it is
 * reproducible by construction and easy to port to GDScript. There is no
 * randomness and no wall clock in it.
 *
 *   - from tick 60 the player holds the charge (a rally shot needs charge);
 *   - a swing is requested every 30 ticks (tick % 30 === 0), which is the
 *     explicit "hit at a named tick" the harness needs;
 *   - moveX and moveY drive the paddle through a fixed pattern so the paddles
 *     and the ball actually move and points actually get played;
 *   - the serve is triggered the way the real loop triggers it: `input.hit`
 *     while `state.serving` is true runs `performServe` (js/game.js:2625).
 */
const SWING_EVERY = 30;

function scriptedInputFor(tick) {
  if (tick < 60) return EMPTY_INPUT;
  return {
    ...EMPTY_INPUT,
    charging: true,
    hit: tick % SWING_EVERY === 0,
    moveX: ((Math.floor(tick / 120) % 3) - 1) * 0.5,
    moveY: tick % 240 < 120 ? -1 : 0,
  };
}

// ---------------------------------------------------------------------------
// Argument parsing. Fail loudly: a silently mis-parsed seed would produce a
// digest that looks fine and compares against the wrong run.
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const out = { ...DEFAULTS, json: null, quiet: false };
  for (const raw of argv) {
    const match = /^--([a-z-]+)(?:=(.*))?$/.exec(raw);
    if (!match) throw new Error(`Argomento non riconosciuto: ${raw}`);
    const [, name, value] = match;
    if (name === "seed") out.seed = readInt(name, value, 0, 0xffffffff);
    else if (name === "ticks") out.ticks = readInt(name, value, 1, 1_000_000);
    else if (name === "every") out.every = readInt(name, value, 1, 1_000_000);
    else if (name === "json") out.json = value ?? null;
    else if (name === "quiet") out.quiet = true;
    else throw new Error(`Opzione sconosciuta: --${name}`);
  }
  return out;
}

function readInt(name, value, min, max) {
  if (value === undefined) throw new Error(`--${name} richiede un valore: --${name}=<intero>`);
  if (!/^-?\d+$/.test(value)) throw new Error(`--${name} deve essere un intero, ricevuto "${value}"`);
  const parsed = Number.parseInt(value, 10);
  if (parsed < min || parsed > max) {
    throw new Error(`--${name} fuori intervallo [${min}, ${max}]: ${parsed}`);
  }
  return parsed;
}

// ---------------------------------------------------------------------------
// RNG accounting. `js/game.js` keeps only `state.rngState`; it does not count
// calls, so the count is reconstructed exactly by replaying the generator from
// the previous sample's state until it reaches the next one. Any mismatch means
// something else wrote `rngState`, which is a real finding, not a rounding
// problem.
// ---------------------------------------------------------------------------
function rngAdvance(stateValue) {
  const next = (stateValue + 0x6D2B79F5) | 0;
  let t = Math.imul(next ^ (next >>> 15), 1 | next);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return next;
}

const RNG_CALL_CAP = 1_000_000;

function countRngCalls(from, to) {
  if (from === to) return 0;
  let cursor = from;
  for (let calls = 1; calls <= RNG_CALL_CAP; calls += 1) {
    cursor = rngAdvance(cursor);
    if (cursor === to) return calls;
  }
  return -1;
}

// ---------------------------------------------------------------------------
// Formatting. Every float goes through fixed(6) so the text is byte-stable, and
// ints are printed as ints. `rngState` is int32 and is bit-comparable across
// engines; positions are float64 here and will NOT be bit-comparable against
// Godot (see the boundary ticket's §6 and its 1e-3 px proposal).
// ---------------------------------------------------------------------------
const fixed = (value) => (Number.isFinite(value) ? value.toFixed(6) : String(value));
const point = (p) => `(${fixed(p.x)},${fixed(p.y)})`;
const vector = (v) => `(${fixed(v.x)},${fixed(v.y)},${fixed(v.z)})`;

function sampleState(state, tick, rngCalls) {
  return {
    tick,
    rngState: state.rngState,
    rngCalls,
    ball: {
      x: state.ball.x,
      y: state.ball.y,
      z: state.ball.z,
      vx: state.ball.vx,
      vy: state.ball.vy,
      vz: state.ball.vz,
      spin: state.ball.spin,
      shotType: state.ball.shotType,
      smashStage: state.ball.smashStage,
      bounces: { player: state.ball.bounces.player, ai: state.ball.bounces.ai },
    },
    paddles: {
      player: { x: state.player.x, y: state.player.y },
      playerMate: { x: state.playerMate.x, y: state.playerMate.y },
      opponent: { x: state.opponent.x, y: state.opponent.y },
      opponentMate: { x: state.opponentMate.x, y: state.opponentMate.y },
    },
    score: {
      points: `${state.points.player}-${state.points.ai}`,
      games: `${state.games.player}-${state.games.ai}`,
      sets: `${state.sets.player}-${state.sets.ai}`,
      playerScore: state.playerScore,
      aiScore: state.aiScore,
      pointsWon: `${state.stats.pointsWon.player}-${state.stats.pointsWon.ai}`,
      rallyHits: state.rallyHits,
      serveAttempts: state.serveAttempts,
      longestRally: state.stats.longestRally,
    },
  };
}

function digestLine(sample) {
  const { ball, paddles, score } = sample;
  return [
    `tick=${String(sample.tick).padStart(6, "0")}`,
    `rngState=${sample.rngState}`,
    `rngCalls=${sample.rngCalls}`,
    `ball=${vector(ball)}`,
    `v=${vector({ x: ball.vx, y: ball.vy, z: ball.vz })}`,
    `spin=${fixed(ball.spin)}`,
    `bounces=${ball.bounces.player}/${ball.bounces.ai}`,
    `shotType=${ball.shotType}`,
    `smashStage=${ball.smashStage}`,
    `player=${point(paddles.player)}`,
    `playerMate=${point(paddles.playerMate)}`,
    `opponent=${point(paddles.opponent)}`,
    `opponentMate=${point(paddles.opponentMate)}`,
    `points=${score.points}`,
    `games=${score.games}`,
    `sets=${score.sets}`,
    `playerScore=${score.playerScore}`,
    `aiScore=${score.aiScore}`,
    `pointsWon=${score.pointsWon}`,
    `rallyHits=${score.rallyHits}`,
    `serveAttempts=${score.serveAttempts}`,
    `longestRally=${score.longestRally}`,
  ].join(" ");
}

// ---------------------------------------------------------------------------
// The run.
// ---------------------------------------------------------------------------
function runSimulation({ seed, ticks, every }) {
  globalThis.__SCP_DBG = true;
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);

  // (a) Explicit seed, assigned after construction because createMatchState has
  // no seed parameter (js/game.js:185-186) and seeds from Math.random at
  // js/game.js:218. This is the same injection the existing audits use
  // (scripts/determinism-audit.mjs:24). Nothing after this line reads
  // Math.random on the simulation path.
  state.rngState = seed;
  state.running = true;

  // createMatchState already ran prepareServe (js/game.js:324), so the match
  // starts in the serving state and the scripted `hit` input performs the
  // serve through the real loop. The harness does not call performServe itself,
  // so the serve path under test is the one the game uses.
  const samples = [];
  let previousRngState = state.rngState;

  for (let tick = 0; tick <= ticks; tick += 1) {
    // Sampled before the step, so tick 0 is the state the match begins from.
    if (tick % every === 0) {
      const rngCalls = countRngCalls(previousRngState, state.rngState);
      samples.push(sampleState(state, tick, rngCalls));
      previousRngState = state.rngState;
    }
    if (tick === ticks) break;
    globalThis.__SCP_TICK = tick;
    // One input object per TICK, not per frame, which is what §6 of
    // simulation-port-boundary.md prescribes: per-frame sampling would drag
    // js/main.js:1197-1209's asymmetry into the comparison.
    updateMatch(state, FIXED_STEP, scriptedInputFor(tick), null);
  }

  return { state, samples };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const { state, samples } = runSimulation(options);

  const lines = samples.map(digestLine);
  const body = lines.join("\n");
  const sha256 = createHash("sha256").update(`${body}\n`).digest("hex");

  // Checks BEFORE anything is printed, so a failing run never prints the PASS
  // summary first.
  if (lines.length === 0) throw new Error("Nessun campione prodotto: --every piu' grande di --ticks");
  const broken = samples.filter((sample) => sample.rngCalls < 0);
  if (broken.length) {
    throw new Error(
      `rngCalls non ricostruibile ai tick ${broken.map((s) => s.tick).join(", ")}: ` +
        "qualcosa scrive state.rngState fuori da nextRandom",
    );
  }

  if (!options.quiet) {
    console.log(`# parity-digest.mjs seed=${options.seed} ticks=${options.ticks} every=${options.every} step=${FIXED_STEP}`);
    console.log(`# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)`);
    console.log(`# format=js-side-only no-godot-comparison`);
    for (const line of lines) console.log(line);
  }

  if (options.json) {
    const target = path.resolve(process.cwd(), options.json);
    await mkdir(path.dirname(target), { recursive: true });
    const payload = {
      tool: "scripts/parity-digest.mjs",
      side: "js",
      seed: options.seed,
      ticks: options.ticks,
      every: options.every,
      fixedStep: FIXED_STEP,
      inputScript: {
        kind: "pure-function-of-tick",
        swingEvery: SWING_EVERY,
        chargeFromTick: 60,
        moveX: "((floor(tick/120) % 3) - 1) * 0.5",
        moveY: "tick % 240 < 120 ? -1 : 0",
      },
      sampledTicks: samples.map((sample) => sample.tick),
      samples,
      digestSha256: sha256,
      digestLineCount: lines.length,
      finalRngState: state.rngState,
    };
    await writeFile(target, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    if (!options.quiet) console.log(`# json=${target}`);
  }

  const summary =
    `PARITY-DIGEST JS PASS seed=${options.seed} ticks=${options.ticks} ` +
    `sampledTicks=${lines.length} every=${options.every} ` +
    `finalRngState=${state.rngState} digestSha256=${sha256}`;
  console.log(summary);
}

try {
  await main();
  process.exit(0);
} catch (error) {
  console.error(`PARITY-DIGEST JS FAIL: ${error?.message ?? error}`);
  process.exit(1);
}
