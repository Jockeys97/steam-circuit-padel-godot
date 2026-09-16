/**
 * double-fault-probe.mjs — NEW, read-only recon probe (allowlisted tree, `tools/sim-port/**`).
 *
 * WHY THIS FILE EXISTS
 *   A3 in `docs/wayfinder/evidence/parity-coverage-frontier.md` §4 asks for a DOUBLE
 *   FAULT: the second serve must ALSO be struck at full charge, and the second serve
 *   must itself fail. The frontier document calls the double-fault rate INFERRED and
 *   never measures it. Before spending an engine slot on a 4 000-tick two-engine run,
 *   this probe answers the cheaper question: *is a full-charge second-serve fault
 *   reachable at all, and at what rate?*
 *
 * METHOD
 *   Mirror of `frontier-probe.mjs --mode=serve-sweep`, with ONE difference: the match
 *   state is put into the reserve-serve condition (`state.serveAttempts = 1`) BEFORE
 *   the exported `performServe(state, charge)` is called, so the internal
 *   `const secondServe = state.serveAttempts > 0` branch (`js/game.js:727`) and the
 *   `serveSecondSafety = 0.70` spread factor are the ones under test. The sim is then
 *   stepped with empty input until the first bounce (or until `stats.doubleFaults`
 *   moves, i.e. `serveFault` took its `serveAttempts === 1` branch, `js/game.js:2126`).
 *
 *   Nothing is modified: `js/**`, `scripts/**` and the frozen harness are read-only.
 *
 * Usage:
 *   node tools/sim-port/double-fault-probe.mjs [--seeds=200] [--athlete=0] [--q=1.0]
 */

import { createMatchState, updateMatch, performServe } from "../../js/game.js?v=20260814-feedback-confirm-v39";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../../js/data.js?v=20260814-feedback-confirm-v39";

const FIXED_STEP = 1 / 120;

const EMPTY_INPUT = {
  left: false, right: false, up: false, down: false, moveX: 0, moveY: 0,
  charging: false, hit: false, slice: false, shotVariant: null, special: false,
  switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
  splitStep: 0, sprint: 0, technicalModifier: false, teamTactic: null,
  cutVolley: false, globo: false,
};

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

/** One serve, at a fixed charge, in the FIRST-serve or SECOND-serve condition. */
function serveOnce(seed, charge, athleteIndex, secondServe) {
  const state = makeState(seed, athleteIndex);
  if (secondServe) state.serveAttempts = 1;
  performServe(state, charge, false);
  const receiver = state.serveSide === "player" ? "ai" : "player";
  const inDepth = () => (receiver === "ai"
    ? state.ball.y >= 184 && state.ball.y < 310
    : state.ball.y > 310 && state.ball.y <= 436);
  const isLeft = () => state.ball.x < 480;
  const lateralOk = () => (state.ball.serveTargetSide === "left" ? isLeft() : !isLeft());

  for (let i = 0; i < 400; i += 1) {
    updateMatch(state, FIXED_STEP, EMPTY_INPUT, null);
    const doubleFaults = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;
    if (doubleFaults > 0) {
      // `serveFault`'s serveAttempts === 1 branch: the SECOND serve failed too.
      return { kind: "double-fault", tick: i, y: state.ball.y, x: state.ball.x, spread: null };
    }
    if (!secondServe && state.serveAttempts === 1) {
      return { kind: "first-serve-fault", tick: i, y: state.ball.y, x: state.ball.x };
    }
    if (state.ball.bounces.ai || state.ball.bounces.player) {
      const depth = receiver === "ai" ? 310 - state.ball.y : state.ball.y - 310;
      return {
        kind: "bounce", tick: i, y: state.ball.y, x: state.ball.x, depth,
        valid: inDepth() && lateralOk(),
        serveInFlight: Boolean(state.ball.serveInFlight),
        serveTouchedNet: Boolean(state.ball.serveTouchedNet),
        events0: state.events[0] ?? null,
      };
    }
  }
  return { kind: "none" };
}

/** Full per-tick detail for one seed: used to explain what a "bounce" outcome really was. */
function debugSeed({ seed, athleteIndex, charge, secondServe }) {
  const state = makeState(seed, athleteIndex);
  if (secondServe) state.serveAttempts = 1;
  const serveSide = state.serveSide;
  performServe(state, charge, false);
  const receiver = serveSide === "player" ? "ai" : "player";
  const rows = [];
  for (let i = 0; i < 400; i += 1) {
    updateMatch(state, FIXED_STEP, EMPTY_INPUT, null);
    rows.push({
      tick: i,
      y: Number(state.ball.y.toFixed(3)),
      x: Number(state.ball.x.toFixed(3)),
      z: Number(state.ball.z.toFixed(3)),
      serveInFlight: Boolean(state.ball.serveInFlight),
      serveTouchedNet: Boolean(state.ball.serveTouchedNet),
      bounces: `${state.ball.bounces.player}/${state.ball.bounces.ai}`,
      serveAttempts: state.serveAttempts,
      doubleFaults: state.stats.doubleFaults.player + state.stats.doubleFaults.ai,
      serving: Boolean(state.serving),
      events0: state.events[0] ?? null,
    });
    const df = state.stats.doubleFaults.player + state.stats.doubleFaults.ai;
    if (df > 0 || state.ball.bounces.player || state.ball.bounces.ai) break;
  }
  return { seed, serveSide, receiver, secondServe, rows: rows.slice(-14) };
}

function sweep({ seeds, athleteIndex, charge }) {
  const rows = [];
  for (const secondServe of [false, true]) {
    let faults = 0, valid = 0, shallow = 0, lateral = 0, other = 0;
    let faultDepthMin = Infinity, faultDepthMax = -Infinity;
    const faultTicks = [];
    const shallowSeeds = [];
    for (let s = 0; s < seeds; s += 1) {
      const seed = 1000 + s * 7919;
      const res = serveOnce(seed, charge, athleteIndex, secondServe);
      if (res.kind === "double-fault" || res.kind === "first-serve-fault") {
        faults += 1;
        faultTicks.push({ seed, tick: res.tick });
      } else if (res.kind === "bounce") {
        if (res.valid) valid += 1;
        else if (res.depth >= 126) { faults += 1; faultDepthMin = Math.min(faultDepthMin, res.depth); faultDepthMax = Math.max(faultDepthMax, res.depth); faultTicks.push({ seed, tick: res.tick }); }
        else { shallow += 1; if (shallowSeeds.length < 8) shallowSeeds.push({ seed, tick: res.tick, depth: res.depth, y: res.y, x: res.x, inFlight: res.serveInFlight, net: res.serveTouchedNet, events0: res.events0 }); }
      } else other += 1;
    }
    rows.push({
      secondServe, charge, seeds, valid, faults, shallowOutOfBox: shallow, lateralOutOfBox: lateral, other,
      faultRate: faults / seeds, faultTickMin: faultTicks.length ? Math.min(...faultTicks.map((f) => f.tick)) : null,
      faultTickMax: faultTicks.length ? Math.max(...faultTicks.map((f) => f.tick)) : null,
      firstFaultSeeds: faultTicks.slice(0, 8),
      shallowSeeds,
    });
  }
  return {
    mode: "second-serve-sweep",
    athlete: ATHLETES[athleteIndex].id,
    athleteControl: ATHLETES[athleteIndex].stats.control,
    rows,
  };
}

const seeds = Number(arg("seeds", "200"));
const athlete = Number(arg("athlete", "0"));
const q = Number(arg("q", "1.0"));
const debugSeedArg = arg("debug", null);

if (debugSeedArg !== null) {
  console.log(JSON.stringify(debugSeed({
    seed: Number(debugSeedArg), athleteIndex: athlete, charge: q,
    secondServe: arg("second", "1") === "1",
  }), null, 1));
} else {
  console.log(JSON.stringify(sweep({ seeds, athleteIndex: athlete, charge: q }), null, 1));
}
