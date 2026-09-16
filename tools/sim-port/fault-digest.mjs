/**
 * fault-digest.mjs — the full-charge serve runner (JS side).
 *
 * WHY THIS FILE EXISTS
 *   The frozen harness (`scripts/parity-digest.mjs`, sha256 2b24dd26..., READ-ONLY,
 *   never edited) strikes the serve on the `tick % 30` grid, so the charge at the
 *   strike is a function of the point-pause phase and tops out at 0.3254 — while a
 *   serve fault needs charge >= 0.90 (measured: docs/wayfinder/evidence/
 *   parity-coverage-frontier.md §2.4). Consequence: the whole `serveAttempts`
 *   branch (`js/game.js:2120-2130`, `:727`) is unexercised in all 12 parity
 *   scenarios. This runner changes ONLY the input driver so that branch is reached:
 *
 *     charging: true every tick
 *     hit:      (state.serving && state.shotCharge >= 0.999)
 *
 *   That trigger is a pure function of the simulated state — no `tick % N`, no
 *   randomness, no wall clock — so it is reproducible by construction on both
 *   engines.
 *
 * DELIBERATE DIFFERENCES FROM THE FROZEN HARNESS (input driver + stop condition only)
 *   1. the serve trigger above, instead of `hit: tick % 30 === 0` from tick 60;
 *   2. `state.setsToWin = 3` right after `createMatchState`, so a completed set does
 *      not set `state.result` and the run stays in the healthy regime
 *      (`parity-coverage-frontier.md` §4 item 3);
 *   3. the loop STOPS at `state.result`, so nothing after the match-ending point is
 *      ever emitted as if it were gameplay (the post-result tail is a free-fall
 *      artefact — §3 of the same document);
 *   4. `--athlete=<index>` (default 0 = `ATHLETES[0]` "maestro", the frozen harness's
 *      athlete). It exists because A3 (double fault) is a property of the server's
 *      `control` stat: `spread` carries `clamp(1.62 - control, 0.3, 1.0)` and the
 *      reserve serve carries the `serveSecondSafety = 0.70` factor, so with maestro
 *      (control 1.28 -> factor 0.34) a full-charge SECOND serve aims 122.3 px deep at
 *      worst against a 126 px service line and can never fault (measured: 0 double
 *      faults in 300 isolated second serves, and in 4 000-tick live runs on five
 *      seeds). With `--athlete=1` ("pantera", control 0.96 -> factor 0.66) the reserve
 *      serve's spread is 27.7 px instead of 14.3 px and the double-fault branch is
 *      reached. The default is 0, so every pre-existing scenario is byte-identical.
 *
 * DIAGNOSTIC COMMENT LINES (ignored by both comparators, identical text on both
 * engines so `tools/sim-port/trace-compare.py` can diff them directly):
 *   `# strike tick=T kind=first|second charge=X serveSide=<player|ai>`
 *       the serve was struck during tick T, with the charge the runner's own trigger
 *       predicate observed at that tick's entry (>= FULL_CHARGE by construction);
 *   `# double-fault tick=T server=<player|ai> total=N`  (A3)
 *   `# set-closed tick=T sets=p-a games=p-a`            (D2)
 *
 * EVERYTHING ELSE IS COPIED VERBATIM from `scripts/parity-digest.mjs`: the sample
 * shape, the float formatting, the field order, the RNG-call reconstruction, the
 * `# ` headers and the `PARITY-DIGEST JS ... digestSha256=...` summary line, so
 * `tools/parity/parity-compare.mjs` and `tools/sim-port/compare-digests.py` work on
 * this stream unchanged.
 *
 * Usage:
 *   node tools/sim-port/fault-digest.mjs [--seed=999] [--ticks=600] [--every=60]
 *                                        [--sets=3] [--json=<path>] [--quiet]
 */

import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

import {
  createMatchState,
  updateMatch,
} from "../../js/game.js?v=20260814-feedback-confirm-v39";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../../js/data.js?v=20260814-feedback-confirm-v39";

// `FIXED_STEP = 1 / 120` (`js/main.js:1164`), the step the frozen harness advances
// per tick (`scripts/parity-digest.mjs:41`).
const FIXED_STEP = 1 / 120;

/** The strike threshold. `state.shotCharge` is capped at 1 (`js/game.js:2686`). */
const FULL_CHARGE = 0.999;

const DEFAULTS = {
  seed: 999,
  ticks: 600,
  every: 60,
  sets: 3,
  athlete: 0,
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
 * The input script: `charging` held every tick, the strike requested only once the
 * charge is full AND the match is in the serving state. `moveX`/`moveY` are the
 * frozen harness's pattern (`scripts/parity-digest.mjs:89-98`), kept so the two
 * runners differ in the serve trigger and nothing else.
 *
 * `chargeAtEntry` is passed in so the caller can record *which* charge the trigger
 * predicate observed on the tick it fired — that is the evidence that the second
 * serve of a double-fault sequence was struck at full charge too.
 */
function scriptedInputFor(tick, state, chargeAtEntry) {
  return {
    ...EMPTY_INPUT,
    charging: true,
    hit: Boolean(state.serving && chargeAtEntry >= FULL_CHARGE),
    moveX: ((Math.floor(tick / 120) % 3) - 1) * 0.5,
    moveY: tick % 240 < 120 ? -1 : 0,
  };
}

// ---------------------------------------------------------------------------
// Argument parsing (same shape as the frozen harness's).
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
    else if (name === "sets") out.sets = readInt(name, value, 1, 5);
    else if (name === "athlete") out.athlete = readInt(name, value, 0, 64);
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
// RNG accounting — copied from the frozen harness (`scripts/parity-digest.mjs:137-154`).
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
// Formatting — copied from the frozen harness (`scripts/parity-digest.mjs:162-229`).
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
// The transition trace. One `# tr` comment line per tick where a discrete field of
// the simulated state moved. It is a pure function of the state (no wall clock),
// so the two engines' traces are directly comparable — and it is what makes the
// fault tick and the second-serve tick visible at tick resolution instead of only
// on the `--every` grid. Comment lines are ignored by both comparators.
// ---------------------------------------------------------------------------
function traceOf(state) {
  return {
    serving: state.serving ? 1 : 0,
    serveAttempts: state.serveAttempts,
    bounces: `${state.ball.bounces.player}/${state.ball.bounces.ai}`,
    points: `${state.points.player}-${state.points.ai}`,
    games: `${state.games.player}-${state.games.ai}`,
    sets: `${state.sets.player}-${state.sets.ai}`,
    rallyHits: state.rallyHits,
    lastHitterSide: state.lastHitterSide,
  };
}

const TRACE_KEYS = ["serving", "serveAttempts", "bounces", "points", "games", "sets", "rallyHits", "lastHitterSide"];

function traceLines(previous, current, tick) {
  if (!previous) {
    return [`# tr tick=${String(tick).padStart(6, "0")} ${TRACE_KEYS.map((key) => `${key}=${current[key]}`).join(" ")}`];
  }
  const moved = TRACE_KEYS.filter((key) => String(previous[key]) !== String(current[key]));
  if (moved.length === 0) return [];
  return [
    `# tr tick=${String(tick).padStart(6, "0")} ` +
      moved
        .map((key) => `${key}=${current[key]}`)
        .join(" "),
  ];
}

// ---------------------------------------------------------------------------
// The run.
// ---------------------------------------------------------------------------
function runSimulation({ seed, ticks, every, sets, athlete }) {
  const state = createMatchState("quick", ATHLETES[athlete], ARENAS[0], AI_OPPONENTS[1]);

  // Same seed injection as the frozen harness (`scripts/parity-digest.mjs:242-243`).
  state.rngState = seed;
  state.running = true;
  // §4 item 3: keep the match alive after the first completed set.
  state.setsToWin = sets;

  const samples = [];
  const trace = [];
  const events = [];
  const strikes = [];
  const doubleFaults = [];
  const setClosures = [];
  let previousRngState = state.rngState;
  let previousTrace = null;
  let resultTick = null;

  for (let tick = 0; tick <= ticks; tick += 1) {
    if (tick % every === 0) {
      const rngCalls = countRngCalls(previousRngState, state.rngState);
      samples.push(sampleState(state, tick, rngCalls));
      previousRngState = state.rngState;
    }
    const current = traceOf(state);
    for (const line of traceLines(previousTrace, current, tick)) trace.push(line);
    previousTrace = current;

    const head = state.events[0] ?? null;
    if (events.length === 0 || events[events.length - 1].message !== head) {
      events.push({ tick, message: head });
    }

    if (tick === ticks) break;

    // Entry snapshot: the values the input script and the strike detector both read,
    // before `updateMatch` can move them.
    const chargeAtEntry = state.shotCharge ?? 0;
    const servingAtEntry = Boolean(state.serving);
    const serveAttemptsAtEntry = state.serveAttempts;
    const serveSideAtEntry = state.serveSide;
    const setsBefore = `${state.sets.player}-${state.sets.ai}`;
    const doubleFaultsBefore = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;

    updateMatch(state, FIXED_STEP, scriptedInputFor(tick, state, chargeAtEntry), null);

    // A serve strike is the only transition that clears `state.serving`
    // (`js/game.js:2618` performServe -> `state.serving = false`).
    if (servingAtEntry && !state.serving) {
      strikes.push({
        tick,
        kind: serveAttemptsAtEntry > 0 ? "second" : "first",
        charge: chargeAtEntry,
        serveSide: serveSideAtEntry,
      });
    }
    const doubleFaultsAfter = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;
    if (doubleFaultsAfter > doubleFaultsBefore) {
      // `serveFault`'s `serveAttempts === 1` branch (`js/game.js:2126-2131`).
      doubleFaults.push({ tick, server: serveSideAtEntry, total: doubleFaultsAfter });
    }
    const setsAfter = `${state.sets.player}-${state.sets.ai}`;
    if (setsAfter !== setsBefore) {
      setClosures.push({ tick, sets: setsAfter, games: `${state.games.player}-${state.games.ai}` });
    }

    if (state.result) {
      // Stop AT the match-ending point: everything the frozen harness would print
      // after it is free-fall noise, not gameplay (parity-coverage-frontier.md §3).
      resultTick = tick + 1;
      break;
    }
  }

  return { state, samples, trace, events, strikes, doubleFaults, setClosures, resultTick };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const { state, samples, trace, events, strikes, doubleFaults, setClosures, resultTick } =
    runSimulation(options);

  const lines = samples.map(digestLine);
  const body = lines.join("\n");
  const sha256 = createHash("sha256").update(`${body}\n`).digest("hex");

  if (lines.length === 0) throw new Error("Nessun campione prodotto: --every piu' grande di --ticks");
  const broken = samples.filter((sample) => sample.rngCalls < 0);
  if (broken.length) {
    throw new Error(
      `rngCalls non ricostruibile ai tick ${broken.map((s) => s.tick).join(", ")}: ` +
        "qualcosa scrive state.rngState fuori da nextRandom",
    );
  }

  if (!options.quiet) {
    console.log(
      `# fault-digest.mjs seed=${options.seed} ticks=${options.ticks} every=${options.every} ` +
        `step=${FIXED_STEP} setsToWin=${options.sets} athlete=${options.athlete}`,
    );
    console.log(`# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)`);
    console.log(`# serve-trigger=charging:true every tick, hit=(state.serving && state.shotCharge>=${FULL_CHARGE})`);
    console.log(`# format=js-side compare-godot-fault-stream`);
    for (const line of lines) console.log(line);
    for (const line of trace) console.log(line);
    for (const strike of strikes) {
      console.log(
        `# strike tick=${String(strike.tick).padStart(6, "0")} kind=${strike.kind} ` +
          `charge=${fixed(strike.charge)} serveSide=${strike.serveSide}`,
      );
    }
    for (const fault of doubleFaults) {
      console.log(
        `# double-fault tick=${String(fault.tick).padStart(6, "0")} server=${fault.server} total=${fault.total}`,
      );
    }
    for (const closure of setClosures) {
      console.log(
        `# set-closed tick=${String(closure.tick).padStart(6, "0")} sets=${closure.sets} games=${closure.games}`,
      );
    }
    for (const event of events) {
      console.log(`# ev tick=${String(event.tick).padStart(6, "0")} events0="${event.message}"`);
    }
    console.log(`# serves=${strikes.length} firstServes=${strikes.filter((s) => s.kind === "first").length} secondServes=${strikes.filter((s) => s.kind === "second").length}`);
    console.log(`# second-serve-charges=${[...new Set(strikes.filter((s) => s.kind === "second").map((s) => fixed(s.charge)))].join(",") || "none"}`);
    console.log(`# first-serve-faults=${events.filter((e) => /second serve|secondServe/i.test(String(e.message))).length}`);
    console.log(`# doubleFaults=${state.stats.doubleFaults.player}/${state.stats.doubleFaults.ai}`);
    console.log(`# doubleFaultTicks=${doubleFaults.map((f) => `${f.tick}:${f.server}`).join(",") || "none"}`);
    console.log(`# setClosures=${setClosures.map((c) => `${c.tick}:${c.sets}`).join(",") || "none"}`);
    console.log(`# resultTick=${resultTick === null ? "none" : resultTick}`);
  }

  if (options.json) {
    const target = path.resolve(process.cwd(), options.json);
    await mkdir(path.dirname(target), { recursive: true });
    const payload = {
      tool: "tools/sim-port/fault-digest.mjs",
      side: "js",
      seed: options.seed,
      ticks: options.ticks,
      every: options.every,
      fixedStep: FIXED_STEP,
      setsToWin: options.sets,
      athleteIndex: options.athlete,
      inputScript: {
        kind: "full-charge, pure function of the simulated state",
        charging: true,
        hit: `state.serving && state.shotCharge >= ${FULL_CHARGE}`,
        moveX: "((floor(tick/120) % 3) - 1) * 0.5",
        moveY: "tick % 240 < 120 ? -1 : 0",
      },
      sampledTicks: samples.map((sample) => sample.tick),
      samples,
      strikes,
      doubleFaults,
      setClosures,
      digestSha256: sha256,
      digestLineCount: lines.length,
      finalRngState: state.rngState,
      resultTick,
    };
    await writeFile(target, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
    if (!options.quiet) console.log(`# json=${target}`);
  }

  console.log(
    `PARITY-DIGEST JS PASS seed=${options.seed} ticks=${options.ticks} ` +
      `sampledTicks=${lines.length} every=${options.every} ` +
      `finalRngState=${state.rngState} digestSha256=${sha256}`,
  );
}

try {
  await main();
  process.exit(0);
} catch (error) {
  console.error(`PARITY-DIGEST JS FAIL: ${error?.message ?? error}`);
  process.exit(1);
}
