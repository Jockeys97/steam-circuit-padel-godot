#!/usr/bin/env node
/**
 * ref-match.mjs — the JAVASCRIPT REFERENCE half of the cross-engine *match*
 * parity proof (lane crew-parity).
 *
 * It plays a whole match with `js/game.js` (the frozen reference, commit
 * 2979588 — read-only, never modified) from one explicit seed and one scripted
 * per-tick input, and prints the frozen parity-digest stream:
 *
 *   - the 21-field digest line of `scripts/parity-digest.mjs`, rendered through
 *     the SAME formatter the comparator uses (`tools/parity/parity-stream.mjs`,
 *     `valuesFromJsonSample` + `lineFromValues`), so the text is byte-identical
 *     by construction and `tools/parity/parity-compare.mjs` reads it unchanged;
 *   - `# ev …` comment lines (ignored by the comparator) that record the events
 *     the digest line does NOT print: net-cord contact, wall/glass bounce,
 *     wall-event cooldown re-arm, serve strike, double fault, set closure,
 *     match result, and the newest in-game message tick.
 *
 * Why this file exists rather than a call to `scripts/parity-digest.mjs`:
 *   1. three named matches are required — a plain one, one with a DOUBLE FAULT,
 *      one with a WALL/GLASS bounce plus a net-cord contact — and the frozen
 *      harness reaches neither a fault (serve charge caps at 0.3254 against a
 *      measured 0.90 fault threshold) nor any of those events on the digest;
 *   2. the frozen harness runs to the tick budget even after `state.result`,
 *      where the ball free-falls (documented harness artefact); a *match* proof
 *      must stop at the result.
 * The frozen harness itself stays byte-identical (sha256 2b24dd26…fdcd).
 *
 * Usage:
 *   node tools/parity-godot/ref-match.mjs --seed=12345 --ticks=24000 --every=1 \
 *     --script=frozen --athlete=0 --sets=1 --stop-at-result --out=<path>
 *   node tools/parity-godot/ref-match.mjs --probe --script=frozen --ticks=6000 \
 *     --seeds=1,2,3,7,999,2024,12345,999983
 *
 * `--script=`:
 *   frozen       `scriptedInputFor` of `scripts/parity-digest.mjs:89-98`
 *                (charging from tick 60, swing on `tick % 30 === 0`)
 *   full-charge  `tools/sim-port/fault-digest.mjs:118-125`
 *                (charging every tick, swing when `state.serving` and
 *                 `state.shotCharge >= 0.999`) — the scenario that can fault
 *
 * Exit 0 = the run completed and its own integrity checks passed; 1 = it did
 * not. It compares nothing: the comparison is `compare-match.mjs`.
 */

import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

import {
  createMatchState,
  updateMatch,
} from "../../js/game.js?v=20260814-feedback-confirm-v39";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../../js/data.js?v=20260814-feedback-confirm-v39";
import { valuesFromJsonSample, lineFromValues } from "../parity/parity-stream.mjs";

/** `FIXED_STEP = 1 / 120` (`js/main.js:1164`), the step the frozen harness uses. */
const FIXED_STEP = 1 / 120;
const FULL_CHARGE = 0.999;
const SWING_EVERY = 30;
const CHARGE_FROM_TICK = 60;

/** The 22-field empty input of `js/game.js:2712-2735`, verbatim. */
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

const fixed = (value) =>
  Number.isFinite(value) ? value.toFixed(6) : String(value);
const pad6 = (tick) => String(tick).padStart(6, "0");

// ---------------------------------------------------------------------------
// Scripted input — both variants are pure functions of (tick, state entry).
// ---------------------------------------------------------------------------

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

function fullChargeInput(tick, state) {
  return {
    ...EMPTY_INPUT,
    charging: true,
    hit: Boolean(state.serving && state.shotCharge >= FULL_CHARGE),
    moveX: ((Math.floor(tick / 120) % 3) - 1) * 0.5,
    moveY: tick % 240 < 120 ? -1 : 0,
  };
}

const SCRIPTS = {
  frozen: { build: (tick) => frozenInput(tick) },
  "full-charge": {
    build: (tick, state) => fullChargeInput(tick, state),
    chargeAtEntry: true,
  },
};

// ---------------------------------------------------------------------------
// RNG accounting — the same reconstruction as `scripts/parity-digest.mjs:137-154`
// (JS keeps no call counter, so the count is replayed from the previous sample).
// ---------------------------------------------------------------------------

function rngAdvance(stateValue) {
  const next = (stateValue + 0x6d2b79f5) | 0;
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
// Sampling — byte-identical shape to `scripts/parity-digest.mjs:166-201`.
// ---------------------------------------------------------------------------

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

/** The digest text, rendered through the comparator's own formatter. */
function digestLine(sample) {
  return lineFromValues(valuesFromJsonSample(sample));
}

// ---------------------------------------------------------------------------
// Event observation over state the digest line does NOT print.
//
// Every observable below exists with the same name and meaning on the port
// (`godot/src/sim/entities.gd` SimBall: netCord, postGlassSide; state.gd:
// wallEventTimer, stats.doubleFaults), so the two engines' event records are
// directly comparable numbers, not localized text.
// ---------------------------------------------------------------------------

function emptyObservations() {
  return { netCord: 0, glass: "null", wallTimer: 0, serveAttempts: 0 };
}

function observe(state) {
  return {
    netCord: Number(state.ball.netCord ?? 0),
    glass: state.ball.postGlassSide == null ? "null" : String(state.ball.postGlassSide),
    wallTimer: Number(state.wallEventTimer ?? 0),
    serveAttempts: Number(state.serveAttempts ?? 0),
  };
}

function eventLines(state, tick, previous, current, extras) {
  const lines = [];
  const b = state.ball;
  // A net contact sets `ball.netCord = 1` (`js/game.js:2388`, `sim.gd:2263`) and
  // it then decays by `dt * 5.5` per tick, so an *upward jump* is the contact.
  if (current.netCord > previous.netCord + 0.5) {
    lines.push(`# ev tick=${pad6(tick)} family=net-cord netCord=${fixed(current.netCord)}`);
  }
  // `postGlassSide` is written on every wall/back-wall bounce that follows a
  // ground bounce (`js/game.js:2358`, `sim.gd:2235`) and cleared by `hitBall`.
  if (current.glass !== previous.glass) {
    lines.push(
      `# ev tick=${pad6(tick)} family=glass glassSide=${current.glass} y=${fixed(b.y)} z=${fixed(b.z)}`,
    );
  }
  // The cooldown is re-armed exactly when a wall event fires (`js/game.js:2365`).
  if (current.wallTimer > previous.wallTimer) {
    lines.push(`# ev tick=${pad6(tick)} family=wall timer=${fixed(current.wallTimer)}`);
  }
  for (const extra of extras) lines.push(extra);
  return lines;
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const out = {
    seed: 12345,
    ticks: 24000,
    every: 1,
    script: "frozen",
    athlete: 0,
    sets: -1,
    stopAtResult: false,
    out: null,
    json: null,
    quiet: false,
    probe: false,
    seeds: null,
  };
  for (const raw of argv) {
    const match = /^--([a-z-]+)(?:=(.*))?$/.exec(raw);
    if (!match) throw new Error(`Argomento non riconosciuto: ${raw}`);
    const [, name, value] = match;
    const int = (min, max) => {
      if (value === undefined || !/^-?\d+$/.test(value)) {
        throw new Error(`--${name} richiede un intero, ricevuto "${value}"`);
      }
      const parsed = Number.parseInt(value, 10);
      if (parsed < min || parsed > max) {
        throw new Error(`--${name} fuori intervallo [${min}, ${max}]: ${parsed}`);
      }
      return parsed;
    };
    if (name === "seed") out.seed = int(0, 0xffffffff);
    else if (name === "ticks") out.ticks = int(1, 1_000_000);
    else if (name === "every") out.every = int(1, 1_000_000);
    else if (name === "athlete") out.athlete = int(0, 64);
    else if (name === "sets") out.sets = int(1, 9);
    else if (name === "script") {
      if (!(value in SCRIPTS)) throw new Error(`--script deve essere frozen|full-charge, ricevuto "${value}"`);
      out.script = value;
    } else if (name === "stop-at-result") out.stopAtResult = true;
    else if (name === "out") out.out = value ?? null;
    else if (name === "json") out.json = value ?? null;
    else if (name === "quiet") out.quiet = true;
    else if (name === "probe") out.probe = true;
    else if (name === "seeds") out.seeds = String(value ?? "").split(",").map((s) => Number.parseInt(s, 10));
    else throw new Error(`Opzione sconosciuta: --${name}`);
  }
  return out;
}

// ---------------------------------------------------------------------------
// The run
// ---------------------------------------------------------------------------

function runMatch({ seed, ticks, every, script, athlete, sets, stopAtResult }) {
  const scriptImpl = SCRIPTS[script];
  const state = createMatchState("quick", ATHLETES[athlete], ARENAS[0], AI_OPPONENTS[1]);
  // Same seed injection as the frozen harness (`scripts/parity-digest.mjs:242`).
  state.rngState = seed;
  state.running = true;
  if (sets > 0) state.setsToWin = sets;

  const lines = [];
  const samples = [];
  const sampledTicks = [];
  const events = [];
  let previousRngState = state.rngState;
  let previousObservations = emptyObservations();
  let resultTick = null;
  let resultWinner = null;
  let lastMessage = "null";
  let brokenRng = [];

  for (let tick = 0; tick <= ticks; tick += 1) {
    const currentObservations = observe(state);
    const extras = [];
    const message = state.events.length ? String(state.events[0]) : "null";
    if (message !== lastMessage) {
      extras.push(`# ev tick=${pad6(tick)} family=message msg="${message}"`);
      lastMessage = message;
    }
    for (const line of eventLines(state, tick, previousObservations, currentObservations, extras)) {
      events.push(line);
      lines.push(line);
    }
    previousObservations = currentObservations;

    if (tick % every === 0) {
      const rngCalls = countRngCalls(previousRngState, state.rngState);
      if (rngCalls < 0) brokenRng.push(tick);
      const sample = sampleState(state, tick, rngCalls);
      samples.push(sample);
      sampledTicks.push(tick);
      lines.push(digestLine(sample));
      previousRngState = state.rngState;
    }

    if (tick === ticks) break;

    const chargeAtEntry = state.shotCharge;
    const servingAtEntry = state.serving;
    const serveAttemptsAtEntry = state.serveAttempts;
    const serveSideAtEntry = state.serveSide;
    const setsBefore = `${state.sets.player}-${state.sets.ai}`;
    const doubleFaultsBefore = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;

    updateMatch(state, FIXED_STEP, scriptImpl.build(tick, state), null);

    // `state.serving` is cleared only by a serve strike.
    if (servingAtEntry && !state.serving) {
      const line = `# ev tick=${pad6(tick)} family=strike serveKind=${
        serveAttemptsAtEntry > 0 ? "second" : "first"
      } charge=${fixed(chargeAtEntry)} serveSide=${serveSideAtEntry}`;
      events.push(line);
      lines.push(line);
    }
    const doubleFaultsAfter = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;
    if (doubleFaultsAfter > doubleFaultsBefore) {
      const line = `# ev tick=${pad6(tick)} family=double-fault server=${serveSideAtEntry} total=${doubleFaultsAfter}`;
      events.push(line);
      lines.push(line);
    }
    const setsAfter = `${state.sets.player}-${state.sets.ai}`;
    if (setsAfter !== setsBefore) {
      const line = `# ev tick=${pad6(tick)} family=set-closed sets=${setsAfter} games=${state.games.player}-${state.games.ai}`;
      events.push(line);
      lines.push(line);
    }
    if (state.result != null && resultTick === null) {
      resultTick = tick + 1;
      resultWinner = String(state.result.winner ?? "?");
      const line = `# ev tick=${pad6(resultTick)} family=result winner=${resultWinner}`;
      events.push(line);
      lines.push(line);
      if (stopAtResult) break;
    }
  }

  return {
    state,
    lines,
    samples,
    sampledTicks,
    events,
    resultTick,
    resultWinner,
    brokenRng,
  };
}

// ---------------------------------------------------------------------------
// Probe mode: count the events the digest cannot show, over several seeds.
// ---------------------------------------------------------------------------

function probe(options) {
  const seeds = options.seeds ?? [options.seed];
  const rows = [];
  for (const seed of seeds) {
    const run = runMatch({
      seed,
      ticks: options.ticks,
      every: options.every,
      script: options.script,
      athlete: options.athlete,
      sets: options.sets,
      stopAtResult: options.stopAtResult,
    });
    const count = (family) => run.events.filter((line) => line.includes(`family=${family} `)).length;
    rows.push({
      seed,
      events: run.events.length,
      netCord: count("net-cord"),
      glass: count("glass"),
      wall: count("wall"),
      strike: count("strike"),
      doubleFault: count("double-fault"),
      setClosed: count("set-closed"),
      resultTick: run.resultTick,
      resultWinner: run.resultWinner,
      samples: run.samples.length,
    });
  }
  console.log(
    `# probe script=${options.script} athlete=${options.athlete} sets=${options.sets} ticks=${options.ticks} every=${options.every} seeds=${seeds.join(",")}`,
  );
  for (const row of rows) {
    console.log(
      `seed=${row.seed} netCord=${row.netCord} glass=${row.glass} wall=${row.wall} strike=${row.strike} ` +
        `doubleFault=${row.doubleFault} setClosed=${row.setClosed} resultTick=${row.resultTick ?? "none"} winner=${row.resultWinner ?? "-"} samples=${row.samples}`,
    );
  }
  return rows;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.probe) {
    probe(options);
    process.exit(0);
  }

  const run = runMatch(options);
  const digestLines = run.lines.filter((line) => line.startsWith("tick="));
  const sha256 = createHash("sha256").update(`${digestLines.join("\n")}\n`).digest("hex");

  if (run.brokenRng.length) {
    throw new Error(
      `rngCalls non ricostruibile ai tick ${run.brokenRng.slice(0, 8).join(",")}: qualcosa scrive rngState fuori da nextRandom`,
    );
  }
  if (run.samples.length === 0) throw new Error("nessun campione prodotto");

  const header = [
    `# ref-match.mjs seed=${options.seed} ticks=${options.ticks} every=${options.every} step=${FIXED_STEP}`,
    `# script=${options.script} athlete=${options.athlete} setsToWin=${options.sets > 0 ? options.sets : "default(1)"} stopAtResult=${options.stopAtResult}`,
    `# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)`,
    `# format=js-side-only no-godot-comparison`,
    `# event-families=net-cord,glass,wall,message,strike,double-fault,set-closed,result (comment lines: ignored by parity-compare.mjs)`,
  ].join("\n");

  const text = `${header}\n${run.lines.join("\n")}\n`;
  const summary =
    `PARITY-DIGEST JS PASS seed=${options.seed} ticks=${options.ticks} ` +
    `sampledTicks=${digestLines.length} every=${options.every} ` +
    `finalRngState=${run.state.rngState} digestSha256=${sha256}`;

  if (!options.quiet) process.stdout.write(`${text}${summary}\n`);
  const target = options.out ?? null;
  if (target) {
    const resolved = path.resolve(process.cwd(), target);
    await mkdir(path.dirname(resolved), { recursive: true });
    await writeFile(resolved, `${text}${summary}\n`, "utf8");
    if (!options.quiet) console.log(`# out=${resolved}`);
  }
  if (options.json) {
    const resolved = path.resolve(process.cwd(), options.json);
    await mkdir(path.dirname(resolved), { recursive: true });
    await writeFile(
      resolved,
      `${JSON.stringify(
        {
          tool: "tools/parity-godot/ref-match.mjs",
          side: "js",
          seed: options.seed,
          ticks: options.ticks,
          every: options.every,
          fixedStep: FIXED_STEP,
          script: options.script,
          athlete: options.athlete,
          setsToWin: options.sets > 0 ? options.sets : 1,
          sampledTicks: run.sampledTicks,
          samples: run.samples,
          digestSha256: sha256,
          digestLineCount: digestLines.length,
          finalRngState: run.state.rngState,
          resultTick: run.resultTick,
          resultWinner: run.resultWinner,
        },
        null,
        2,
      )}\n`,
      "utf8",
    );
    if (!options.quiet) console.log(`# json=${resolved}`);
  }
  if (options.quiet) console.log(summary);
}

main().catch((error) => {
  console.error(`PARITY-DIGEST JS FAIL: ${error?.stack ?? error}`);
  process.exit(1);
});
