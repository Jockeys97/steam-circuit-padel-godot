/**
 * timing-trace.mjs — the JS half of the timing-field parity comparison.
 *
 * WHY THIS FILE EXISTS
 *   The frozen digest (`scripts/parity-digest.mjs`) samples ball, paddles and score.
 *   NONE of the timing fields behind the "PERFETTO" meter are in it: `shotCharge`,
 *   `shotRead.active/eta/perfectWindow/advice/profile/overlap`, the assessment's
 *   `quality`/`grade` and the x3 recoveries are outside the digest shape. So a
 *   green parity digest says nothing about them. This runner prints one `# tm`
 *   line per tick carrying exactly those fields, on the SAME input script as the
 *   Godot half (`godot/tests/timing_feedback_test.gd`), so the two streams can be
 *   compared field by field and tick by tick.
 *
 * INPUT SCRIPT (the same on both engines, a pure function of the simulated state
 * plus the tick — no `tick % 30` serve grid, no wall clock, no randomness):
 *   charging: true                       every tick
 *   hit:      serving and charge >= 0.999, OR `state.shotRead.active`
 *             The first clause strikes the serve at full charge (the trigger of
 *             `tools/sim-port/fault-digest.mjs`); the second swings whenever the
 *             read model says a playable ball is incoming, which is what puts real
 *             contacts, and therefore real `quality`/`grade` values, in the trace.
 *   analogAim: true, aim: a two-level square wave  -> drives `shotAim`, which the
 *             shot-profile branch needs to leave "control"/"attack".
 *   moveX / moveY: the frozen harness's movement pattern
 *             (`scripts/parity-digest.mjs:89-98`), kept so `moveRatio` — an input
 *             of the perfect window — is exercised.
 *
 * WHAT IS COMPARED
 *   `# tm`   one line per tick, the timing fields (text is engine-neutral).
 *   `# con`  the timing constants, read from the engine's own balance table, so a
 *            constant that drifted apart is visible in the same diff.
 *   `# tr` / `# ev` / `# strike` / digest lines: the shapes
 *            `tools/sim-port/trace-compare.py` already reads, so the existing
 *            in-house comparator can also assert that the two streams are the same
 *            run and not merely two runs that agree on the timing fields.
 *
 * Usage:
 *   node tools/sim-port/timing-trace.mjs [--seed=997] [--ticks=2400] [--every=120]
 *                                        [--sets=3] [--athlete=0] [--quiet]
 *   -> stdout, redirected to a file, is the input of
 *      `tools/sim-port/timing-compare.py <js-stream> <gd-stream>`.
 */

import { BALANCE, AI_OPPONENTS, ARENAS, ATHLETES } from "../../js/data.js?v=20260910-sprite-gate-v41";
import { createMatchState, updateMatch } from "../../js/game.js?v=20260910-sprite-gate-v41";
import { t } from "../../js/i18n.js?v=20260910-sprite-gate-v41";
import { createHash } from "node:crypto";

/** `FIXED_STEP = 1 / 120` (`js/main.js:1164`). */
const FIXED_STEP = 1 / 120;
/** `state.shotCharge` is capped at 1 (`js/game.js:2686`). */
const FULL_CHARGE = 0.999;

const DEFAULTS = { seed: 997, ticks: 2400, every: 120, sets: 3, athlete: 0 };

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
  smashUpgrade: false,
};

/** The timing constants both engines' models are built on. */
const TIMING_CONSTANTS = [
  "perfectTimingWindow",
  "goodTimingWindow",
  "timingWindowRunPenalty",
  "timingWindowEnergyPenalty",
  "timingWindowGlassPenalty",
  "timingWindowSplitStepBonus",
  "timingWindowChargePenalty",
  "timingWindowMin",
  "timingWindowMax",
  "timingDecaySpan",
  "qualityTimingWeight",
  "playableHitHeight",
  "ballGravity",
  "smashMinHeight",
  "lateGraceFactor",
  "sprintAccuracyPenalty",
  "splitStepQualityBonus",
  "rallyEnergyFloor",
  "smashX2MinQuality",
  "smashX3MinQuality",
];

function scriptedInputFor(tick, state) {
  const read = state.shotRead ?? {};
  const eta = read.eta;
  // Two swing bands, alternating on a 480-tick square wave: the near band swings
  // when the read model is already `active` (a clean contact), the early band
  // swings while the ball is still closing, so the queued shot ages before the
  // ball arrives and the assessment has to grade it. Ages, and therefore grades,
  // are a property of the contact, not of this script.
  const earlyBand = tick % 480 < 240;
  const swing =
    read.active &&
    (earlyBand ? eta !== null && eta < 0.30 : eta !== null && eta < 0.10);
  return {
    ...EMPTY_INPUT,
    charging: true,
    hit: Boolean((state.serving && (state.shotCharge ?? 0) >= FULL_CHARGE) || swing),
    analogAim: true,
    aim: tick % 900 < 450 ? 0.7 : -0.35,
    aimY: 0,
    moveX: ((Math.floor(tick / 120) % 3) - 1) * 0.5,
    moveY: tick % 240 < 120 ? -1 : 0,
  };
}

// ---------------------------------------------------------------------------
// Argument parsing — same shape as the frozen harness's.
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const out = { ...DEFAULTS, quiet: false };
  for (const raw of argv) {
    const match = /^--([a-z-]+)(?:=(.*))?$/.exec(raw);
    if (!match) throw new Error(`Argomento non riconosciuto: ${raw}`);
    const [, name, value] = match;
    if (name === "seed") out.seed = readInt(name, value, 0, 0xffffffff);
    else if (name === "ticks") out.ticks = readInt(name, value, 1, 1_000_000);
    else if (name === "every") out.every = readInt(name, value, 1, 1_000_000);
    else if (name === "sets") out.sets = readInt(name, value, 1, 5);
    else if (name === "athlete") out.athlete = readInt(name, value, 0, 64);
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
// RNG accounting and formatting — copied from the frozen harness
// (`scripts/parity-digest.mjs:137-229`).
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

const fixed = (value) => (Number.isFinite(value) ? value.toFixed(6) : String(value));
const point = (p) => `(${fixed(p.x)},${fixed(p.y)})`;
const vector = (v) => `(${fixed(v.x)},${fixed(v.y)},${fixed(v.z)})`;
const tick6 = (tick) => String(tick).padStart(6, "0");

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
    `tick=${tick6(sample.tick)}`,
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

/** The discrete transition trace — same keys and spelling as the port's. */
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
    return [`# tr tick=${tick6(tick)} ${TRACE_KEYS.map((key) => `${key}=${current[key]}`).join(" ")}`];
  }
  const moved = TRACE_KEYS.filter((key) => String(previous[key]) !== String(current[key]));
  if (moved.length === 0) return [];
  return [`# tr tick=${tick6(tick)} ${moved.map((key) => `${key}=${current[key]}`).join(" ")}`];
}

// ---------------------------------------------------------------------------
// The timing fields — the point of this runner.
// ---------------------------------------------------------------------------

/**
 * `state.shotFeedback.mode` holds localized text on this side (`t("shotModeBalanced")`,
 * `t("smashMissedHint")`) and an id on the port's side, so the JS half maps it back
 * through the same table the reference wrote it with: the value that is compared is
 * the mode the simulation chose, not the sentence the HUD prints.
 */
const MODE_IDS = ["shotModeControl", "shotModeBalanced", "shotModePower", "smashMissedHint", "smashMissedContact"];
const MODE_LABELS = new Map();
for (const id of MODE_IDS) {
  const label = t(id);
  if (!MODE_LABELS.has(label)) MODE_LABELS.set(label, id);
}

function modeIdOf(mode) {
  if (mode === undefined || mode === null) return "none";
  return MODE_LABELS.get(mode) ?? `unmapped:${mode}`;
}

function timingLine(state, tick) {
  const read = state.shotRead ?? {};
  const ball = state.ball;
  const feedback = state.shotFeedback ?? null;
  return (
    `# tm tick=${tick6(tick)}` +
    ` charge=${fixed(state.shotCharge ?? 0)}` +
    ` active=${read.active ? 1 : 0}` +
    ` eta=${read.eta === null || read.eta === undefined ? "null" : fixed(read.eta)}` +
    ` perfectWindow=${fixed(read.perfectWindow ?? 0)}` +
    ` advice=${read.advice ?? "?"}` +
    ` profile=${read.profile ?? "?"}` +
    ` overlap=${read.overlap ? 1 : 0}` +
    ` serving=${state.serving ? 1 : 0}` +
    ` fbGrade=${feedback?.grade ?? "none"}` +
    ` fbQuality=${feedback && feedback.quality !== undefined ? fixed(feedback.quality) : "none"}` +
    ` fbProfile=${feedback?.profile ?? "none"}` +
    ` fbMode=${feedback ? modeIdOf(feedback.mode) : "none"}` +
    ` shotType=${ball.shotType}` +
    ` queuedCharge=${fixed(state.queuedShotCharge ?? 0)}` +
    ` queuedPower=${fixed(state.queuedShotPower ?? 0)}` +
    ` x3ai=${fixed(state.aiX3Recovery ?? 0)}` +
    ` x3player=${fixed(state.playerX3Recovery ?? 0)}`
  );
}

function constantsLines() {
  const lines = [];
  for (const name of TIMING_CONSTANTS) {
    const value = BALANCE[name];
    if (value === undefined) {
      lines.push(`# con name=${name} value=missing`);
      continue;
    }
    lines.push(`# con name=${name} value=${fixed(value)}`);
  }
  return lines;
}

// ---------------------------------------------------------------------------
// The run.
// ---------------------------------------------------------------------------
function runSimulation({ seed, ticks, every, sets, athlete }) {
  const state = createMatchState("quick", ATHLETES[athlete], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = seed;
  state.running = true;
  // Keep the match alive after the first completed set (`parity-coverage-frontier.md` §4.3).
  state.setsToWin = sets;

  const samples = [];
  const trace = [];
  const timing = [];
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

    timing.push(timingLine(state, tick));

    const head = state.events[0] ?? null;
    if (events.length === 0 || events[events.length - 1].message !== head) {
      events.push({ tick, message: head });
    }

    if (tick === ticks) break;

    const chargeAtEntry = state.shotCharge ?? 0;
    const servingAtEntry = Boolean(state.serving);
    const serveAttemptsAtEntry = state.serveAttempts;
    const serveSideAtEntry = state.serveSide;
    const setsBefore = `${state.sets.player}-${state.sets.ai}`;
    const doubleFaultsBefore = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;

    updateMatch(state, FIXED_STEP, scriptedInputFor(tick, state), null);

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
      doubleFaults.push({ tick, server: serveSideAtEntry, total: doubleFaultsAfter });
    }
    const setsAfter = `${state.sets.player}-${state.sets.ai}`;
    if (setsAfter !== setsBefore) {
      setClosures.push({ tick, sets: setsAfter, games: `${state.games.player}-${state.games.ai}` });
    }

    if (state.result) {
      resultTick = tick + 1;
      break;
    }
  }

  return { state, samples, trace, timing, events, strikes, doubleFaults, setClosures, resultTick };
}

/** Coverage counters: what the scripted scenario actually exercised. */
function coverage(timing) {
  const count = (prefix) => {
    const map = new Map();
    for (const line of timing) {
      const field = line.split(" ").find((part) => part.startsWith(prefix));
      if (!field) continue;
      const value = field.slice(prefix.length);
      map.set(value, (map.get(value) ?? 0) + 1);
    }
    return [...map.entries()].sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).map(([value, n]) => `${value}:${n}`).join(",");
  };
  const activeTicks = timing.filter((line) => line.includes(" active=1")).length;
  const etaValues = timing
    .map((line) => line.split(" ").find((part) => part.startsWith("eta="))?.slice(4))
    .filter((value) => value !== undefined && value !== "null");
  const shotTypes = new Map();
  for (const line of timing) {
    const value = line.split(" ").find((part) => part.startsWith("shotType="))?.slice(9);
    if (value !== undefined && value !== "serve") shotTypes.set(value, (shotTypes.get(value) ?? 0) + 1);
  }
  return [
    `# cov ticks=${timing.length} activeTicks=${activeTicks} etaNullTicks=${timing.length - etaValues.length} etaFiniteTicks=${etaValues.length}`,
    `# cov etaMin=${etaValues.length ? fixed(Math.min(...etaValues.map(Number))) : "none"} etaMax=${
      etaValues.length ? fixed(Math.max(...etaValues.map(Number))) : "none"
    }`,
    `# cov advice=${count("advice=")}`,
    `# cov profile=${count("profile=")}`,
    `# cov overlapTicks=${timing.filter((line) => line.includes(" overlap=1")).length}`,
    `# cov fbGrade=${count("fbGrade=")}`,
    `# cov fbQualityDistinct=${new Set(
      timing
        .map((line) => line.split(" ").find((part) => part.startsWith("fbQuality="))?.slice(10))
        .filter((value) => value !== undefined && value !== "none"),
    ).size}`,
    `# cov shotTypes=${[...shotTypes.entries()].sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1)).map(([value, n]) => `${value}:${n}`).join(",") || "none"}`,
    `# cov x3SmashTicks=${timing.filter((line) => line.includes("shotType=smash-x3")).length}`,
    `# cov x3aiTicks=${timing.filter((line) => !line.includes(" x3ai=0.000000")).length}`,
    `# cov x3playerTicks=${timing.filter((line) => !line.includes(" x3player=0.000000")).length}`,
  ];
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const run = runSimulation(options);

  const lines = run.samples.map(digestLine);
  if (lines.length === 0) throw new Error("Nessun campione prodotto: --every piu' grande di --ticks");
  const broken = run.samples.filter((sample) => sample.rngCalls < 0);
  if (broken.length) {
    throw new Error(
      `rngCalls non ricostruibile ai tick ${broken.map((s) => s.tick).join(", ")}: ` +
        "qualcosa scrive state.rngState fuori da nextRandom",
    );
  }
  const digestSha = createHash("sha256").update(`${lines.join("\n")}\n`).digest("hex");
  const timingSha = createHash("sha256").update(`${run.timing.join("\n")}\n`).digest("hex");
  const coverageLines = coverage(run.timing);

  if (!options.quiet) {
    console.log(
      `# timing-trace.mjs seed=${options.seed} ticks=${options.ticks} every=${options.every} ` +
        `step=${FIXED_STEP} setsToWin=${options.sets} athlete=${options.athlete}`,
    );
    console.log(`# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)`);
    console.log(
      `# input-script=charging:true every tick; hit=(state.serving && shotCharge>=${FULL_CHARGE}) || (shotRead.active && eta < 0.30|0.10 on a 480-tick square wave); ` +
        `analogAim:true aim=0.7|-0.35 on a 900-tick square wave; moveX/moveY = the frozen harness pattern`,
    );
    console.log(`# format=js-side compare-godot-timing-stream`);
    for (const line of constantsLines()) console.log(line);
    for (const line of lines) console.log(line);
    for (const line of run.trace) console.log(line);
    for (const strike of run.strikes) {
      console.log(
        `# strike tick=${tick6(strike.tick)} kind=${strike.kind} charge=${fixed(strike.charge)} serveSide=${strike.serveSide}`,
      );
    }
    for (const fault of run.doubleFaults) {
      console.log(`# double-fault tick=${tick6(fault.tick)} server=${fault.server} total=${fault.total}`);
    }
    for (const closure of run.setClosures) {
      console.log(`# set-closed tick=${tick6(closure.tick)} sets=${closure.sets} games=${closure.games}`);
    }
    for (const event of run.events) {
      console.log(`# ev tick=${tick6(event.tick)} events0="${event.message}"`);
    }
    console.log(`# resultTick=${run.resultTick === null ? "none" : run.resultTick}`);
    for (const line of run.timing) console.log(line);
    for (const line of coverageLines) console.log(line);
    console.log(`# timingFields=17 charge,active,eta,perfectWindow,advice,profile,overlap,serving,fbGrade,fbQuality,fbProfile,fbMode +shotType,queuedCharge,queuedPower,x3ai,x3player`);
    console.log(`# timingSha256=${timingSha}`);
  }

  console.log(
    `TIMING-TRACE JS PASS seed=${options.seed} ticks=${options.ticks} tracedTicks=${run.timing.length} ` +
      `every=${options.every} finalRngState=${run.state.rngState} digestSha256=${digestSha} timingSha256=${timingSha}`,
  );
}

try {
  main();
  process.exit(0);
} catch (error) {
  console.error(`TIMING-TRACE JS FAIL: ${error?.message ?? error}`);
  process.exit(1);
}
