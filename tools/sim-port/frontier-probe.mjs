/**
 * frontier-probe.mjs — NEW, read-only coverage-frontier probe (allowlisted tree).
 *
 * It imports the JS reference (`js/game.js`) exactly the way the frozen harness
 * `scripts/parity-digest.mjs` does, and NEVER modifies it, `js/**` or `scripts/**`.
 * It exists to answer three questions the frozen digest cannot answer on its own:
 *
 *   mode=frozen        replay the frozen harness input script tick-for-tick and report
 *                      (a) the exact tick at which `state.result` first goes non-null,
 *                      (b) the exact tick at which the free-fall "runaway tail" starts,
 *                      (c) every serve's aim depth / charge / fault outcome.
 *   mode=fullcharge    same loop, but the serve is only struck once the charge is full
 *                      (`state.serving && state.shotCharge >= 0.999`). Deterministic:
 *                      the input is a pure function of the simulated state.
 *   mode=serve-sweep   the decisive fault experiment: for charge q in [0..1] and N seeds,
 *                      call the exported `performServe(state, q)` directly and step the
 *                      sim until the first ground bounce, then ask whether that bounce was
 *                      inside the service box. Measures the REAL fault probability, i.e.
 *                      including the `+18 + (1-charge)*18` launch offset (js/game.js:754)
 *                      that makes the ball land later and deeper than the aim point.
 *
 * Usage:
 *   node tools/sim-port/frontier-probe.mjs --mode=frozen --seed=2024 --ticks=28800
 *   node tools/sim-port/frontier-probe.mjs --mode=fullcharge --seed=2024 --ticks=28800 --athlete=1
 *   node tools/sim-port/frontier-probe.mjs --mode=serve-sweep --seeds=200
 */

import { createMatchState, updateMatch, performServe } from "../../js/game.js?v=20260814-feedback-confirm-v39";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../../js/data.js?v=20260814-feedback-confirm-v39";

const FIXED_STEP = 1 / 120;
const SWING_EVERY = 30;

const EMPTY_INPUT = {
  left: false, right: false, up: false, down: false, moveX: 0, moveY: 0,
  charging: false, hit: false, slice: false, shotVariant: null, special: false,
  switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
  splitStep: 0, sprint: 0, technicalModifier: false, teamTactic: null,
  cutVolley: false, globo: false,
};

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

function arg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

function makeState(seed, athleteIndex) {
  const state = createMatchState("quick", ATHLETES[athleteIndex], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = seed;
  state.running = true;
  return state;
}

/** Charge the serve branch would use, reconstructed from the value at tick entry. */
function chargeUsed(chargeAtEntry, charging) {
  return Math.min(1, chargeAtEntry + (charging ? FIXED_STEP / 1.05 : 0));
}

function replayFrozen({ seed, ticks, athleteIndex, fullCharge, setsToWin, tailDump }) {
  const state = makeState(seed, athleteIndex);
  if (setsToWin) state.setsToWin = setsToWin;
  const serves = [];
  let resultTick = null;
  let firstFallingTick = null;
  let firstNonZeroServeAttemptTick = null;
  let secondServeTick = null;
  const maxChargeSeen = { value: 0, tick: 0 };
  let inFlightBefore = false;
  let attemptBefore = 0;
  const tail = [];
  let lastResult = null;
  let lastSets = "0-0";
  const serveEnds = [];
  const faultEvents = [];
  let inFlightBeforeWasTrue = false;
  let faultCount = 0;

  for (let tick = 0; tick <= ticks; tick += 1) {
    const chargeAtEntry = state.shotCharge ?? 0;
    // Frozen harness script = pure function of the tick (scripts/parity-digest.mjs:89-98).
    // fullCharge = the candidate script for a NEW runner: hold the button from tick 0 and
    // strike only when the charge is full. Still a pure function of the simulated state.
    const charging = fullCharge ? true : tick >= 60;
    const input = fullCharge
      ? {
          ...EMPTY_INPUT,
          charging: true,
          hit: state.serving && (state.shotCharge ?? 0) >= 0.999,
          moveX: ((Math.floor(tick / 120) % 3) - 1) * 0.5,
          moveY: tick % 240 < 120 ? -1 : 0,
        }
      : scriptedInputFor(tick);

    updateMatch(state, FIXED_STEP, input, null);

    if (state.result && resultTick === null) resultTick = tick;
    if (resultTick !== null && firstFallingTick === null && state.ball.z < -1) firstFallingTick = tick;
    if (tailDump && resultTick !== null && tail.length < tailDump) {
      const setsNow = `${state.sets.player}-${state.sets.ai}`;
      lastResult = state.result;
      tail.push({
        tick,
        z: Number(state.ball.z.toFixed(3)),
        y: Number(state.ball.y.toFixed(3)),
        x: Number(state.ball.x.toFixed(3)),
        vx: Number(state.ball.vx.toFixed(3)),
        vy: Number(state.ball.vy.toFixed(3)),
        bounces: `${state.ball.bounces.player}/${state.ball.bounces.ai}`,
        serveInFlight: Boolean(state.ball.serveInFlight),
        pointPause: Number((state.pointPause ?? 0).toFixed(4)),
        points: `${state.points.player}-${state.points.ai}`,
        games: `${state.games.player}-${state.games.ai}`,
        sets: setsNow,
        setsDelta: setsNow !== lastSets,
      });
      lastSets = setsNow;
    }

    const chargeNow = state.shotCharge ?? 0;
    if (chargeNow > maxChargeSeen.value) { maxChargeSeen.value = chargeNow; maxChargeSeen.tick = tick; }

    const inFlightNow = Boolean(state.ball.serveInFlight);
    if (inFlightNow && !inFlightBefore) {
      serves.push({
        tick,
        server: state.serveSide,
        charge: state.serveSide === "player" ? chargeUsed(chargeAtEntry, charging) : 0.62,
        aimDepth: state.ball.serveTargetY - 310,
        targetX: state.ball.serveTargetX,
        serveAttemptsAtStrike: attemptBefore,
      });
    }
    inFlightBefore = inFlightNow;
    if (!inFlightNow && inFlightBeforeWasTrue) {
      serveEnds.push({
        tick,
        y: Number(state.ball.y.toFixed(3)),
        x: Number(state.ball.x.toFixed(3)),
        z: Number(state.ball.z.toFixed(3)),
        bounces: `${state.ball.bounces.player}/${state.ball.bounces.ai}`,
        serveAttempts: state.serveAttempts ?? 0,
        netFaultOwner: state.ball.netFaultOwner ?? null,
      });
    }
    inFlightBeforeWasTrue = inFlightNow;
    const attemptsNow = state.serveAttempts ?? 0;
    if (attemptsNow !== attemptBefore) {
      faultEvents.push({
        tick,
        from: attemptBefore,
        to: attemptsNow,
        ballY: Number(state.ball.y.toFixed(3)),
        ballX: Number(state.ball.x.toFixed(3)),
        ballZ: Number(state.ball.z.toFixed(3)),
        bounces: `${state.ball.bounces.player}/${state.ball.bounces.ai}`,
        serveStillInFlight: Boolean(state.ball.serveInFlight),
        events: (state.events ?? []).slice(0, 2),
      });
    }
    if (attemptsNow === 1 && attemptBefore === 0 && firstNonZeroServeAttemptTick === null) firstNonZeroServeAttemptTick = tick;
    if (attemptsNow === 1 && attemptBefore === 0) faultCount += 1;
    if (attemptsNow > 0 && secondServeTick === null && firstNonZeroServeAttemptTick !== null && tick > firstNonZeroServeAttemptTick) secondServeTick = tick;
    attemptBefore = attemptsNow;
  }

  const depths = serves.map((s) => s.aimDepth);
  const playerServes = serves.filter((s) => s.server === "player");
  return {
    mode: fullCharge ? "fullcharge" : "frozen",
    seed, ticks, athlete: ATHLETES[athleteIndex].id, athleteControl: ATHLETES[athleteIndex].stats.control,
    serves: serves.length,
    playerServes: playerServes.length,
    aiServes: serves.length - playerServes.length,
    aimDepthMin: depths.length ? Math.min(...depths) : null,
    aimDepthMax: depths.length ? Math.max(...depths) : null,
    playerChargeMin: playerServes.length ? Math.min(...playerServes.map((s) => s.charge)) : null,
    playerChargeMax: playerServes.length ? Math.max(...playerServes.map((s) => s.charge)) : null,
    maxShotChargeSeen: maxChargeSeen,
    faults: faultCount,
    firstFaultTick: firstNonZeroServeAttemptTick,
    secondServeSeen: secondServeTick !== null,
    secondServeTick,
    serveEnds,
    faultEvents,
    resultTick,
    firstFallingTick,
    setsAtEnd: `${state.sets.player}-${state.sets.ai}`,
    gamesAtEnd: `${state.games.player}-${state.games.ai}`,
    pointsAtEnd: `${state.points.player}-${state.points.ai}`,
    setScores: state.setScores,
    ballZAtEnd: state.ball.z,
    ballYAtEnd: state.ball.y,
    ballXAtEnd: state.ball.x,
    firstServeDetail: serves.slice(0, 4),
    lastServeDetail: serves.slice(-3),
    tail,
  };
}

/** Steer a single serve at a fixed charge and report where the first bounce lands. */
function serveOnce(seed, charge, athleteIndex) {
  const state = makeState(seed, athleteIndex);
  performServe(state, charge, false);
  const receiver = state.serveSide === "player" ? "ai" : "player";
  const inDepth = () => (receiver === "ai"
    ? state.ball.y >= 184 && state.ball.y < 310
    : state.ball.y > 310 && state.ball.y <= 436);
  const isLeft = () => state.ball.x < 480;
  const lateralOk = () => (state.ball.serveTargetSide === "left" ? isLeft() : !isLeft());
  let bounce = null;
  for (let i = 0; i < 400; i += 1) {
    updateMatch(state, FIXED_STEP, EMPTY_INPUT, null);
    if (state.serveAttempts === 1) { bounce = { kind: "fault-long-or-wall", y: state.ball.y, z: state.ball.z, tick: i }; break; }
    if (state.ball.bounces.ai || state.ball.bounces.player) {
      bounce = { kind: "bounce", y: state.ball.y, x: state.ball.x, depth: receiver === "ai" ? 310 - state.ball.y : state.ball.y - 310, tick: i,
        valid: inDepth() && lateralOk() };
      break;
    }
  }
  return bounce ?? { kind: "none", y: state.ball.y, z: state.ball.z };
}

function serveSweep({ seeds, athleteIndex }) {
  const rows = [];
  for (let q = 0; q <= 1.0001; q += 0.05) {
    const charge = Math.round(q * 100) / 100;
    let faults = 0, valid = 0, other = 0, minDepth = Infinity, maxDepth = -Infinity, minY = Infinity, maxY = -Infinity;
    for (let s = 0; s < seeds; s += 1) {
      const res = serveOnce(1000 + s * 7919, charge, athleteIndex);
      if (res.kind === "bounce" && res.valid) { valid += 1; minDepth = Math.min(minDepth, res.depth); maxDepth = Math.max(maxDepth, res.depth); minY = Math.min(minY, res.y); maxY = Math.max(maxY, res.y); }
      else if (res.kind === "bounce" || res.kind === "fault-long-or-wall") { faults += 1; minY = Math.min(minY, res.y); maxY = Math.max(maxY, res.y); }
      else other += 1;
    }
    rows.push({ charge, seeds, valid, faults, other, faultRate: (faults / seeds), landingYMin: minY, landingYMax: maxY,
      bounceDepthMin: Number.isFinite(minDepth) ? minDepth : null, bounceDepthMax: Number.isFinite(maxDepth) ? maxDepth : null });
  }
  return { mode: "serve-sweep", athlete: ATHLETES[athleteIndex].id, athleteControl: ATHLETES[athleteIndex].stats.control, seeds, rows };
}

const mode = arg("mode", "frozen");
const seed = Number(arg("seed", "2024"));
const ticks = Number(arg("ticks", "28800"));
const athlete = Number(arg("athlete", "0"));
const seeds = Number(arg("seeds", "200"));
const setsToWin = arg("sets", null) ? Number(arg("sets", "0")) : 0;
const tailDump = Number(arg("tail", "0"));

let out;
if (mode === "frozen" || mode === "tail-dump") {
  out = replayFrozen({ seed, ticks, athleteIndex: athlete, fullCharge: false, setsToWin, tailDump: tailDump || (mode === "tail-dump" ? 24 : 0) });
}
else if (mode === "fullcharge") out = replayFrozen({ seed, ticks, athleteIndex: athlete, fullCharge: true, setsToWin });
else if (mode === "serve-sweep") out = serveSweep({ seeds, athleteIndex: athlete });
else throw new Error(`mode sconosciuta: ${mode}`);

console.log(JSON.stringify(out, null, 1));
