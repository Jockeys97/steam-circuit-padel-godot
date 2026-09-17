/**
 * shot-intent-probe.mjs — one scripted scenario per SHOT INTENT, run against the
 * FROZEN 2D reference (`js/game.js`), printing a machine-checkable trace line per
 * scenario so the Godot port's `res://tests/shot_logic_parity_test.gd` trace can
 * be diffed against it field by field.
 *
 * Ticket: `docs/wayfinder/tickets/shot-logic-parity.md` (slice S14a).
 * Evidence: `docs/wayfinder/evidence/shot-logic-parity.md`.
 *
 * It NEVER modifies `js/**` or the reference tree: it only reads. Every scenario
 * sets `state.rngState = SEED` before the first draw, so both engines consume the
 * same RNG stream and the printed floats are comparable at 6 decimals — the same
 * convention as `tools/parity/**` ("agreement at the digest's printed precision").
 *
 * Usage:
 *   node tools/sim-port/shot-intent-probe.mjs                 # the trace lines
 *   node tools/sim-port/shot-intent-probe.mjs --scan-volley   # find the AI seed that volleys
 *   node tools/sim-port/shot-intent-probe.mjs --scan-smash    # find the x3-downgrade contact
 *
 * The trace line shape (one line per scenario, `# trace ` + JSON, fixed key order):
 *   kind        "shot" (a stroke was struck) | "state" (a rule/state observation)
 *   shotType    the intent the engine produced — `ball.shotType` (`serve` uses the
 *               server's `shotIntent`, which is how the reference represents it)
 *   intentField `paddle.shotIntent`, the HUD-facing intent
 *   dir         sign(ball.vy): -1 toward the AI side, +1 toward the player
 *   spinSign    sign(ball.spin)
 *   x3          shotType == "smash-x3"
 * Numbers are pre-formatted strings (`%.6f`), so the line is byte-comparable
 * against the GDScript side.
 */

import { createMatchState, hitBall, performServe, updateMatch } from "../../js/game.js?v=20260917-shot-parity";
import { AI_OPPONENTS, ARENAS, ATHLETES, BALANCE, COURT } from "../../js/data.js?v=20260917-shot-parity";

const SEED = 12345;
const TAP_DT = 1 / 60;
const TRACE = "# trace ";

// ---------------------------------------------------------------------------
// Trace helpers
// ---------------------------------------------------------------------------

function r6(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === "boolean") return v;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return n.toFixed(6);
}

function sign(v) {
  const n = Number(v);
  if (!Number.isFinite(n) || n === 0) return 0;
  return n > 0 ? 1 : -1;
}

/** A stroke was struck: the outcome is read off the ball and the paddle, never off a label. */
function outcome(state, striker, scenario, path, flags = {}) {
  const ball = state.ball;
  const shotType = String(ball.shotType);
  return {
    scenario,
    kind: "shot",
    path,
    shotType,
    intentField: String(state[striker].shotIntent),
    dir: sign(ball.vy),
    spinSign: sign(ball.spin),
    x3: shotType === "smash-x3",
    vx: r6(ball.vx),
    vy: r6(ball.vy),
    vz: r6(ball.vz),
    spin: r6(ball.spin),
    backspin: r6(ball.backspin),
    topspin: r6(ball.topspin),
    wallKill: r6(ball.wallKill),
    smashTargetSide: ball.smashTargetSide ?? null,
    flags,
  };
}

/** A rule/state observation: the ball fields are not the evidence, `flags` are. */
function observe(state, scenario, path, flags = {}) {
  return {
    scenario,
    kind: "state",
    path,
    shotType: "queued",
    intentField: String(state.player.shotIntent),
    dir: 0,
    spinSign: 0,
    x3: false,
    vx: null,
    vy: null,
    vz: null,
    spin: null,
    backspin: null,
    topspin: null,
    wallKill: null,
    smashTargetSide: null,
    flags,
  };
}

function emit(row) {
  console.log(TRACE + JSON.stringify(row));
}

// ---------------------------------------------------------------------------
// The benches. Identical on both engines.
// ---------------------------------------------------------------------------

/** One deterministic contact: the ball sits exactly on the paddle (lateral offset 0). */
function bench(opts = {}) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = SEED;
  state.running = true;
  state.serving = false;
  state.rallyHits = opts.rallyHits ?? 2;
  const y = opts.y ?? COURT.netY + 170;
  state.player.x = 480;
  state.player.y = y;
  state.player.hitCooldown = 0;
  state.player.moveRatio = opts.moveRatio ?? 0;
  state.player.splitStep = opts.splitStep ?? 0;
  state.ball.x = 480;
  state.ball.y = y + (opts.passed ?? 0);
  state.ball.z = opts.height ?? 55;
  state.ball.vy = opts.ballVy ?? 120;
  state.ball.serveInFlight = false;
  state.ball.netFaultOwner = null;
  if (opts.incoming) state.ball.shotType = opts.incoming;
  const charge = opts.charge ?? 0.76;
  const power = 0.4 + charge * 0.95;
  const ok = hitBall(
    state, state.player, power, opts.special ?? false, true,
    opts.aim ?? 0, opts.slice ?? false, opts.variant ?? "auto", opts.aimY ?? -1,
    opts.timingAge ?? 0, opts.precision ?? 0,
  );
  return { state, ok };
}

/**
 * A tap bench: the ball is 125 px from the paddle and closing at 260 px/s, so the
 * first two ticks only QUEUE (the geometry of `scripts/smash-input-audit.mjs:53-103`).
 */
function tapBench() {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = SEED;
  state.running = true;
  state.serving = false;
  state.shotCharge = 0.76;
  state.activePlayerKey = "player";
  state.rallyHits = 2;
  state.player.x = 480;
  state.player.y = COURT.netY + 170;
  state.player.hitCooldown = 0;
  state.player.moveRatio = 0;
  state.ball.x = 480;
  state.ball.y = state.player.y - 125;
  state.ball.z = 68;
  state.ball.vx = 0;
  state.ball.vy = 260;
  state.ball.vz = 135;
  state.ball.bounces = { player: 0, ai: 1 };
  state.ball.serveInFlight = false;
  state.ball.netFaultOwner = null;
  return state;
}

function input(overrides = {}) {
  return {
    left: false, right: false, up: false, down: false, moveX: 0, moveY: 0,
    charging: false, hit: false, slice: false, shotVariant: null, special: false,
    switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
    splitStep: 0, sprint: 0, technicalModifier: false, teamTactic: null,
    cutVolley: false, globo: false, smashUpgrade: false,
    ...overrides,
  };
}

/**
 * A tick session over one scenario state: counts the ticks and records the tick at
 * which the queued stroke is struck. `ball.shotType` starts at "serve"
 * (`createBall`, `js/game.js:86`), so the baseline is captured, never assumed — and
 * it is captured BEFORE the first tick, because a tap and the contact can happen in
 * the same tick.
 */
function session(state) {
  return { state, base: String(state.ball.shotType), tick: 0, struck: -1 };
}

function step(s, overrides) {
  updateMatch(s.state, TAP_DT, input(overrides));
  s.tick += 1;
  if (s.struck < 0 && String(s.state.ball.shotType) !== s.base) s.struck = s.tick;
  return s;
}

function idle(s, maxTicks) {
  for (let i = 0; i < maxTicks && s.struck < 0; i += 1) step(s, { moveX: 0, moveY: 0 });
  return s;
}

// ---------------------------------------------------------------------------
// Scenarios — 13 intents, 4 modifiers, the charge/double-tap rules
// ---------------------------------------------------------------------------

const SCENARIOS = {
  // --- the 13 intents ------------------------------------------------------
  "intent/drive": () => {
    const { state } = bench({ variant: "auto", height: 55, y: COURT.netY + 220, aim: 0 });
    return outcome(state, "player", "intent/drive",
      "hitBall: no branch taken (baseline contact, |aimedOffset| < 0.72)");
  },
  "intent/slice": () => {
    const { state } = bench({ variant: "auto", slice: true, height: 50, y: COURT.netY + 220 });
    return outcome(state, "player", "intent/slice",
      "hitBall: `else if (slice)` and NOT viboraRange (outside viboraNetWindow)");
  },
  "intent/vibora": () => {
    const { state } = bench({ variant: "vibora", slice: true, height: 55, y: COURT.netY + 170 });
    return outcome(state, "player", "intent/vibora",
      "hitBall: `slice` + viboraRange + contactHeight >= 42 (vibora asks smashNetWindow)");
  },
  "intent/bandeja": () => {
    const { state } = bench({ variant: "smash", height: BALANCE.smashMinHeight - 8, y: COURT.netY + 170, aim: 0 });
    return outcome(state, "player", "intent/bandeja",
      "hitBall: explicitSmash with smashReady false -> smashType bandeja");
  },
  "intent/chiquita": () => {
    const { state } = bench({ variant: "chiquita", height: 55, y: COURT.netY + 170, aim: 0 });
    return outcome(state, "player", "intent/chiquita",
      "hitBall: `shotVariant === \"chiquita\"`");
  },
  "intent/volley": () => {
    // The one intent only the AI produces (`chooseComputerShot`: atNet && ball.z > 42
    // && the kind roll misses the vibora band). Reached through the exported
    // `hitBall` on the opponent paddle, which is exactly what `updateDoublesAI` calls.
    const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
    state.rngState = 1;
    state.running = true;
    state.serving = false;
    state.rallyHits = 2;
    state.opponent.x = 480;
    state.opponent.y = COURT.netY - 100;
    state.opponent.hitCooldown = 0;
    state.ball.x = 480;
    state.ball.y = state.opponent.y + 40;
    state.ball.z = 50;
    state.ball.vy = -120;
    state.ball.serveInFlight = false;
    state.ball.netFaultOwner = null;
    hitBall(state, state.opponent, 0.88 + 0.6 * 0.12, false, true);
    return outcome(state, "opponent", "intent/volley",
      "applyComputerShot -> chooseComputerShot: kind = volley (seed 1)");
  },
  "intent/cut-volley": () => {
    const { state } = bench({ variant: "cut-volley", height: 55, y: COURT.netY + 170, aim: 0.3 });
    return outcome(state, "player", "intent/cut-volley",
      "hitBall: variant cut-volley + quality >= cutVolleyMinQuality");
  },
  "intent/lob": () => {
    const { state } = bench({ variant: "lob", height: 55, y: COURT.netY + 170, aim: 0 });
    return outcome(state, "player", "intent/lob", "hitBall: variant lob");
  },
  "intent/defensive-lob": () => {
    const { state } = bench({ variant: "defensive-lob", height: 55, y: COURT.netY + 170, aim: 0 });
    return outcome(state, "player", "intent/defensive-lob",
      "hitBall: variant defensive-lob (pad Y + RB)");
  },
  "intent/globo": () => {
    const { state } = bench({ variant: "globo", height: 55, y: COURT.netY + 170, aim: 0 });
    return outcome(state, "player", "intent/globo",
      "hitBall: variant globo + quality >= globoMinQuality");
  },
  "intent/smash/x2": () => {
    const { state } = bench({ variant: "smash", height: 55, y: COURT.netY + 170, aim: 0, aimY: -1 });
    return outcome(state, "player", "intent/smash/x2",
      "hitBall: smashReady + explicitSmash + aimedDepth -1 -> x2 (|aimedOffset| < 0.42)");
  },
  "intent/smash/x3": () => {
    const { state } = bench({ variant: "smash", height: 55, y: COURT.netY + 170, aim: 0.82, aimY: -1 });
    return outcome(state, "player", "intent/smash/x3",
      "hitBall: smashReady + explicitSmash + aimedDepth <= -0.28 + |aimedOffset| >= 0.42");
  },
  "intent/smash/flat": () => {
    const { state } = bench({ variant: "smash", height: 55, y: COURT.netY + 170, aim: 0.82, aimY: -1, timingAge: 0.3, moveRatio: 1, passed: 20 });
    return outcome(state, "player", "intent/smash/flat",
      "hitBall: smash-flat branch (quality < smashX3MinQuality, >= smashFlatMinQuality)");
  },
  "intent/wall-angle": () => {
    const { state } = bench({ variant: "auto", height: 55, y: COURT.netY + 220, aim: 1, aimY: -1 });
    return outcome(state, "player", "intent/wall-angle",
      "hitBall: seeksSideGlass (|aimedOffset| >= 0.72, no smashType, not slice, not lob)");
  },
  "intent/serve": () => {
    const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
    state.rngState = SEED;
    state.running = true;
    state.serveSide = "player";
    state.serveCourt = "right";
    state.serveAttempts = 0;
    state.serving = true;
    performServe(state, 0.62, false);
    const row = outcome(state, "player", "intent/serve",
      "performServe: server.shotIntent = serve (the reference's own representation)");
    row.shotType = String(state.player.shotIntent);
    row.flags = {
      serveTargetX: r6(state.ball.serveTargetX),
      serveTargetY: r6(state.ball.serveTargetY),
      served: state.ball.served === true,
      serveInFlight: state.ball.serveInFlight === true,
    };
    return row;
  },
  "intent/serve/slice": () => {
    const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
    state.rngState = SEED;
    state.running = true;
    state.serveSide = "player";
    state.serveCourt = "right";
    state.serveAttempts = 0;
    state.serving = true;
    performServe(state, 0.62, true);
    const row = outcome(state, "player", "intent/serve/slice",
      "performServe: slice=true -> backspin 0.75 and spin x1.8");
    row.shotType = String(state.player.shotIntent);
    row.flags = {
      backspinIsSlice: state.ball.backspin === 0.75,
      serveTargetX: r6(state.ball.serveTargetX),
      serveTargetY: r6(state.ball.serveTargetY),
    };
    return row;
  },

  // --- the 4 modifiers -----------------------------------------------------
  "modifier/special": () => {
    // The input path, not a direct call: `input.special` -> `trySpecial` ->
    // `hitBall(.., isSpecial=true)` -> `applySpecial` (maestro: vy/vz override +
    // specialReadPenalty). The ball must be inside `canHit` for this to land.
    const state = tapBench();
    state.player.y = COURT.netY + 170;
    state.ball.y = state.player.y - 20;
    state.ball.z = 55;
    state.ball.vy = 120;
    state.ball.vz = 0;
    state.specialReady = 1;
    state.specialCooldown = 0;
    updateMatch(state, TAP_DT, input({ special: true }));
    return outcome(state, "player", "modifier/special",
      "updateMatch: input.special -> trySpecial -> hitBall(isSpecial) -> applySpecial(maestro)", {
        aiReactionDelay: r6(state.aiReactionDelay),
        specialCooldown: r6(state.specialCooldown),
        specialReady: r6(state.specialReady),
        swingBuffer: r6(state.playerSwingBuffer),
        hitCooldown: r6(state.player.hitCooldown),
      });
  },
  "modifier/smashUpgrade": () => {
    // The double tap end to end: the first release of A primes, the second tap
    // confirms the upgrade to `smash`, and the prepared stroke keeps until contact.
    const s = session(tapBench());
    step(s, { hit: true, shotVariant: "drive", aim: 0, aimY: -1, analogAim: true });
    const primed = s.state.smashPrimed === true;
    const tapWindow = s.state.smashTapWindow;
    const buffer = s.state.playerSwingBuffer;
    const variantAfterFirst = String(s.state.queuedShotVariant);
    step(s, { smashUpgrade: true, aim: 0, aimY: -1, analogAim: true });
    const primedAfterTap = s.state.smashPrimed === true;
    const intentAfterTap = String(s.state.shotIntent);
    const variantAfterTap = String(s.state.queuedShotVariant);
    idle(s, 40);
    const row = outcome(s.state, "player", "modifier/smashUpgrade",
      "updateMatch: A release primes -> second tap confirms -> queuedShotVariant smash -> struck on contact");
    row.flags = {
      primedAfterFirstRelease: primed,
      tapWindowAfterPrime: r6(tapWindow),
      swingBufferAfterPrime: r6(buffer),
      variantAfterFirstRelease: variantAfterFirst,
      primedAfterSecondTap: primedAfterTap,
      intentAfterTap,
      queuedVariantAfterTap: variantAfterTap,
      contactTick: s.struck,
    };
    return row;
  },
  "modifier/cutVolley": () => {
    // The same grammar on X: the first release is a slice, the second tap upgrades
    // it to a cut volley while the priming window is open, and the queued variant
    // survives to the contact. The player stands inside `viboraNetWindow` (96) and
    // the ball starts outside `canHit` (the audit geometry: 75 px away).
    const s = session(tapBench());
    s.state.player.y = COURT.netY + 95;
    s.state.ball.y = COURT.netY + 20;
    s.state.ball.z = 68;
    s.state.ball.vy = 260;
    step(s, { hit: true, slice: true, aim: 0, aimY: -1, analogAim: true });
    const primed = s.state.cutVolleyPrimed === true;
    const tapWindow = s.state.cutVolleyTapWindow;
    const buffer = s.state.playerSwingBuffer;
    const sliceAfterFirst = s.state.queuedShotSlice === true;
    step(s, { cutVolley: true, aim: 0, aimY: -1, analogAim: true });
    const primedAfterTap = s.state.cutVolleyPrimed === true;
    const intentAfterTap = String(s.state.shotIntent);
    idle(s, 40);
    const row = outcome(s.state, "player", "modifier/cutVolley",
      "updateMatch: X release primes the cut volley -> second tap confirms -> struck on contact");
    row.flags = {
      primedAfterFirstRelease: primed,
      tapWindowAfterPrime: r6(tapWindow),
      swingBufferAfterPrime: r6(buffer),
      sliceAfterFirstRelease: sliceAfterFirst,
      primedAfterSecondTap: primedAfterTap,
      intentAfterTap,
      contactTick: s.struck,
    };
    return row;
  },
  "modifier/globo": () => {
    // The third tap grammar: a lob off a real charge on a ball that is not too high
    // primes the globo; the tap promotes the queued variant to `globo`.
    const s = session(tapBench());
    s.state.ball.y = s.state.player.y - 60;
    step(s, { hit: true, shotVariant: "lob", aim: 0, aimY: -1, analogAim: true });
    const primed = s.state.globoPrimed === true;
    const tapWindow = s.state.globoTapWindow;
    step(s, { globo: true, aim: 0, aimY: -1, analogAim: true });
    const intentAfterTap = String(s.state.shotIntent);
    idle(s, 40);
    const row = outcome(s.state, "player", "modifier/globo",
      "updateMatch: lob release primes the globo -> globo tap confirms -> struck on contact");
    row.flags = {
      primedAfterFirstRelease: primed,
      tapWindowAfterPrime: r6(tapWindow),
      intentAfterTap,
      contactTick: s.struck,
    };
    return row;
  },
  "modifier/teamTactic": () => {
    // The D-pad tactic. It does NOT upgrade a shot intent (it steers the pair), so
    // the row records the tactic state the input sets, not a stroke.
    const state = tapBench();
    const before = String(state.playerTeamTactic);
    updateMatch(state, TAP_DT, input({ teamTactic: "attack" }));
    const after = String(state.playerTeamTactic);
    const flash = state.tacticFlash;
    updateMatch(state, TAP_DT, input({ teamTactic: "attack" }));
    const row = observe(state, "modifier/teamTactic",
      "updateMatch: setPlayerTeamTactic(input.teamTactic) — steers the pair, does not change the shot intent", {
        before,
        after,
        tacticFlashAfterSet: r6(flash),
        reSetIsNoOp: String(state.playerTeamTactic) === after,
      });
    return row;
  },

  // --- the charge / double-tap rules that select them ----------------------
  "rule/charge-accrual": () => {
    // `updateShotControl`: charge += dt/1.05 per tick, capped at 1; the release
    // freezes `queuedShotPower = 0.4 + charge * 0.95` and the variant.
    const state = tapBench();
    state.shotCharge = 0;
    const charging = input({ charging: true, moveX: 0, moveY: 0 });
    const ticks = 30;
    for (let i = 0; i < ticks; i += 1) updateMatch(state, TAP_DT, charging);
    const chargeAfter = state.shotCharge;
    const intentWhileCharging = String(state.shotIntent);
    updateMatch(state, TAP_DT, input({ hit: true, moveX: 0, moveY: 0 }));
    return observe(state, "rule/charge-accrual",
      "updateShotControl: shotCharge += dt/1.05, queuedShotPower = 0.4 + charge*0.95", {
        ticks,
        chargeAfterTicks: r6(chargeAfter),
        intentWhileCharging,
        queuedShotPower: r6(state.queuedShotPower),
        queuedShotCharge: r6(state.queuedShotCharge),
        queuedShotVariant: String(state.queuedShotVariant),
        queuedShotSlice: state.queuedShotSlice === true,
      });
  },
  "rule/charge-variant-slice": () => {
    const state = tapBench();
    state.shotCharge = 0.3;
    updateMatch(state, TAP_DT, input({ hit: true, slice: true, moveX: 0, moveY: 0 }));
    return observe(state, "rule/charge-variant-slice",
      "queueChargedShot(slice=true, variant = input.slice ? \"slice\" : \"auto\")", {
        queuedShotVariant: String(state.queuedShotVariant),
        queuedShotSlice: state.queuedShotSlice === true,
        queuedShotPower: r6(state.queuedShotPower),
      });
  },
  "rule/smash-prime-accepted": () => {
    const state = tapBench();
    updateMatch(state, TAP_DT, input({ hit: true, shotVariant: "drive", moveX: 0, moveY: 0 }));
    return observe(state, "rule/smash-prime-accepted",
      "updateMatch: canPrimeSmash = drive && !slice && rallyHits>0 && withinNetRange(smashNetWindow) && z >= smashMinHeight-8 && power >= smashMinPower", {
        smashPrimed: state.smashPrimed === true,
        smashTapWindow: r6(state.smashTapWindow),
        swingBuffer: r6(state.playerSwingBuffer),
        smashContactFallback: state.smashContactFallback === true,
      });
  },
  "rule/smash-prime-slice-refused": () => {
    const state = tapBench();
    updateMatch(state, TAP_DT, input({ hit: true, slice: true, moveX: 0, moveY: 0 }));
    return observe(state, "rule/smash-prime-slice-refused",
      "canPrimeSmash: queuedShotVariant != drive (a slice is queued) -> refused", {
        smashPrimed: state.smashPrimed === true,
        cutVolleyPrimed: state.cutVolleyPrimed === true,
      });
  },
  "rule/smash-prime-service-return-refused": () => {
    const state = tapBench();
    state.rallyHits = 0;
    updateMatch(state, TAP_DT, input({ hit: true, shotVariant: "drive", moveX: 0, moveY: 0 }));
    return observe(state, "rule/smash-prime-service-return-refused",
      "canPrimeSmash: state.rallyHits > 0 -> refused on the service return", {
        smashPrimed: state.smashPrimed === true,
      });
  },
  "rule/smash-prime-baseline-refused": () => {
    const state = tapBench();
    state.player.y = COURT.netY + BALANCE.smashNetWindow + 30;
    updateMatch(state, TAP_DT, input({ hit: true, shotVariant: "drive", moveX: 0, moveY: 0 }));
    return observe(state, "rule/smash-prime-baseline-refused",
      "canPrimeSmash: withinNetRange(paddle, smashNetWindow) -> refused from the baseline", {
        smashPrimed: state.smashPrimed === true,
      });
  },
  "rule/smash-prime-low-ball-refused": () => {
    const state = tapBench();
    state.ball.z = BALANCE.smashMinHeight - 9;
    updateMatch(state, TAP_DT, input({ hit: true, shotVariant: "drive", moveX: 0, moveY: 0 }));
    return observe(state, "rule/smash-prime-low-ball-refused",
      "canPrimeSmash: ball.z >= smashMinHeight - 8 -> refused on a low ball", {
        smashPrimed: state.smashPrimed === true,
      });
  },
  "rule/smash-prime-low-power-refused": () => {
    const state = tapBench();
    state.shotCharge = 0.1;
    updateMatch(state, TAP_DT, input({ hit: true, shotVariant: "drive", moveX: 0, moveY: 0 }));
    return observe(state, "rule/smash-prime-low-power-refused",
      "canPrimeSmash: queuedShotPower * athlete.power >= smashMinPower -> refused on a soft contact", {
        smashPrimed: state.smashPrimed === true,
        queuedShotPower: r6(state.queuedShotPower),
      });
  },
  "rule/smash-tap-window-expiry": () => {
    // No contact is possible (the ball sits above `playableHitHeight` and never
    // comes down), so the priming window is left to run out: the tap dies after
    // `BALANCE.smashDoubleTapWindow` seconds and the prepared shot degrades.
    const state = tapBench();
    state.ball.z = BALANCE.playableHitHeight + 22;
    state.ball.vy = 0;
    state.ball.vz = 250;
    updateMatch(state, TAP_DT, input({ hit: true, shotVariant: "drive", moveX: 0, moveY: 0 }));
    const primedFirst = state.smashPrimed === true;
    let expiredAt = -1;
    for (let frame = 0; frame < 90; frame += 1) {
      updateMatch(state, TAP_DT, input({ moveX: 0, moveY: 0 }));
      if (state.smashPrimed !== true) { expiredAt = frame + 1; break; }
    }
    return observe(state, "rule/smash-tap-window-expiry",
      "decayHumanSwing/updateMatch: smashTapWindow <= 0 -> smashPrimed = false (contact impossible: ball above playableHitHeight)", {
        primedAfterFirstRelease: primedFirst,
        expiredAfterTicks: expiredAt,
        queuedShotVariant: String(state.queuedShotVariant),
        swingBuffer: r6(state.playerSwingBuffer),
      });
  },
  "rule/no-double-tap-degrades": () => {
    // Without the second tap the prepared shot degrades to the plain drive: it does
    // not vanish and the striker is still the player.
    const s = session(tapBench());
    step(s, { hit: true, shotVariant: "drive", moveX: 0, moveY: 0 });
    idle(s, 70);
    const row = outcome(s.state, "player", "rule/no-double-tap-degrades",
      "updateMatch: no second tap -> queuedShotVariant stays drive -> drive struck after the tap window expires");
    row.flags = { contactTick: s.struck, lastHitterSide: String(s.state.lastHitterSide) };
    return row;
  },
  "rule/x3-vs-x2-auto": () => {
    // The same `smashReady` contact with the auto variant: the x3 flag is the
    // `|aimedOffset| >= 0.52` rule, not a player choice.
    const { state } = bench({ variant: "auto", height: 55, y: COURT.netY + 170, aim: 0.82, aimY: -1 });
    return outcome(state, "player", "rule/x3-vs-x2-auto",
      "hitBall: smashReady + auto -> smash-x3 when |aimedOffset| >= 0.52");
  },
  "rule/x3-downgrade": () => {
    // x3 asked (aimedDepth <= -0.28, |aimedOffset| >= 0.42) but the contact is below
    // `smashX3MinQuality`: the stroke becomes an x2 and the x3 flag is false.
    const { state } = bench({ variant: "smash", height: 55, y: COURT.netY + 170, aim: 0.82, aimY: -1, timingAge: 0.06 });
    return outcome(state, "player", "rule/x3-downgrade",
      "hitBall: the smash-x3 branch requires quality >= smashX3MinQuality, else the x3 is downgraded to x2");
  },
  "rule/service-return-no-smash": () => {
    const { state } = bench({ variant: "smash", height: 55, y: COURT.netY + 170, aim: 0, aimY: -1, rallyHits: 0 });
    return outcome(state, "player", "rule/service-return-no-smash",
      "hitBall: serviceReturn (rallyHits == 0) forbids smashReady -> the explicit smash becomes a bandeja");
  },
  "rule/smash-defence-vs-incoming": () => {
    // Responding to a smash with a contact that is neither perfect nor good: the
    // base trajectory is raised and shortened (`smashReturnScrambleArc/Depth`) while
    // the intent stays the base one. Baseline contact so no smashType masks it.
    const { state } = bench({ variant: "auto", height: 55, y: COURT.netY + 220, aim: 0, aimY: -1, incoming: "smash-x2", timingAge: 0.3, moveRatio: 1, passed: 20 });
    return outcome(state, "player", "rule/smash-defence-vs-incoming",
      "hitBall: returningSmash && grade != perfect/good -> smashed/scrambled defence arc and depth");
  },
};

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

function aiVolleyState(seed) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = seed;
  state.running = true;
  state.serving = false;
  state.rallyHits = 2;
  state.opponent.x = 480;
  state.opponent.y = COURT.netY - 100;
  state.opponent.hitCooldown = 0;
  state.ball.x = 480;
  state.ball.y = state.opponent.y + 40;
  state.ball.z = 50;
  state.ball.vy = -120;
  state.ball.serveInFlight = false;
  state.ball.netFaultOwner = null;
  return state;
}

function scanVolley() {
  for (let seed = 1; seed <= 24; seed += 1) {
    const state = aiVolleyState(seed);
    hitBall(state, state.opponent, 0.952, false, true);
    console.log(`seed=${seed} shotType=${state.ball.shotType} vx=${state.ball.vx.toFixed(3)} vy=${state.ball.vy.toFixed(3)}`);
  }
}

function scanSmash() {
  const grid = [
    { timingAge: 0.1, moveRatio: 1, passed: 30, charge: 0.76 },
    { timingAge: 0.15, moveRatio: 0.6, passed: 20, charge: 0.76 },
    { timingAge: 0.2, moveRatio: 0.8, passed: 20, charge: 0.76 },
    { timingAge: 0.25, moveRatio: 0.6, passed: 12, charge: 0.76 },
    { timingAge: 0.12, moveRatio: 0.5, passed: 10, charge: 0.76 },
    { timingAge: 0.2, moveRatio: 1, passed: 0, charge: 0.76 },
    { timingAge: 0.2, moveRatio: 0, passed: 40, charge: 0.76 },
    { timingAge: 0.18, moveRatio: 0.4, passed: 25, charge: 0.76 },
  ];
  for (const g of grid) {
    const { state } = bench({ variant: "smash", height: 55, y: COURT.netY + 170, aim: 0.82, aimY: -1, ...g });
    console.log(`${JSON.stringify(g)} -> ${state.ball.shotType} topspin=${state.ball.topspin.toFixed(3)}`);
  }
}

if (process.argv.includes("--scan-volley")) {
  scanVolley();
} else if (process.argv.includes("--scan-smash")) {
  scanSmash();
} else {
  console.log(`# shot-intent-probe seed=${SEED} athlete=${ATHLETES[0].id} opponent=${AI_OPPONENTS[1].id} dt=${TAP_DT}`);
  for (const [name, run] of Object.entries(SCENARIOS)) {
    const row = run();
    if (!row) { console.error(`scenario ${name} produced no row`); continue; }
    emit(row);
  }
}
