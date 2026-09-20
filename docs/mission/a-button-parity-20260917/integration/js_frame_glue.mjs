/**
 * js_frame_glue.mjs — production-frame-glue harness for the A-button differential.
 *
 * Runs the ACTUAL browser input functions extracted verbatim from js/main.js
 * (`radialStick`, `shotAimAxis`, `isSliceAction`, `pollGamepadGameplay`,
 * `getInput`, `getInput2`, `consumeOneShot`) and the ACTUAL `updateMatch` from
 * js/game.js, driven by the ACTUAL gameLoop frame glue (js/main.js:1249-1264):
 *
 *     simAccumulator = min(simAccumulator + dt, FIXED_STEP * MAX_SIM_STEPS);
 *     input = getInput();            // reads AND CLEARS one-shot flags, BEFORE the accumulator
 *     input2 = getInput2();
 *     while (simAccumulator >= FIXED_STEP && steps < MAX_SIM_STEPS) {
 *       updateMatch(state, FIXED_STEP, input, input2);
 *       simAccumulator -= FIXED_STEP; steps += 1;
 *       if (steps === 1) { input = consumeOneShot(input); input2 = consumeOneShot(input2); }
 *     }
 *
 * gamepadLoop (`pollGamepadGameplay`) runs BEFORE gameLoop each frame — the
 * pinned rAF registration order (gamepadLoop at boot js/main.js:2724; gameLoop
 * at match start). FIXED_STEP=1/120, MAX_SIM_STEPS=8 (js/main.js:1217-1218):
 * production rate, NOT the reference corpus' 1/60.
 *
 * Usage: node integration/js_frame_glue.mjs [--corpus=path] [--out=path]
 */

import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import crypto from "node:crypto";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "../../../../");
const MAIN_JS = path.join(ROOT, "js", "main.js");
const GAME_JS = path.join(ROOT, "js", "game.js");
const DATA_JS = path.join(ROOT, "js", "data.js");
const CORPUS = path.join(__dirname, "corpus", "production_rate.json");

function arg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}
const corpusPath = arg("corpus", CORPUS);
const outPath = arg("out", null);

const game = await import(pathToFileURL(GAME_JS).href);
const data = await import(pathToFileURL(DATA_JS).href);
const { createMatchState, updateMatch } = game;
const { ATHLETES, ARENAS, AI_OPPONENTS, COURT } = data;

const mainSource = fs.readFileSync(MAIN_JS, "utf8");
const mainSha = crypto.createHash("sha256").update(mainSource).digest("hex").slice(0, 16);
const gameSha = crypto
  .createHash("sha256").update(fs.readFileSync(GAME_JS, "utf8")).digest("hex").slice(0, 16);

function extract(name) {
  const start = mainSource.indexOf("function " + name + "(");
  if (start < 0) throw new Error("missing reference " + name);
  // Top-level function body ends at the first "}" at column 0.
  const close = mainSource.indexOf("\n}", start);
  if (close < 0) throw new Error("no closing brace for " + name);
  return mainSource.slice(start, close + 2);
}
const INPUT_FUNCS = [
  "radialStick", "shotAimAxis", "isSliceAction",
  "pollGamepadGameplay", "getInput", "getInput2", "consumeOneShot",
].map(extract).join("\n");

const SETUP = `
var ui = { gamepadDeadzone: 0.15 };
var keys = new Set();
var hitQueued=false, sliceQueued=false, shotVariantQueued=null, shotAimQueued=null;
var specialQueued=false, switchQueued=false, switchDirectionQueued=null;
var matchState={humanMode:"solo",smashPrimed:false,cutVolleyPrimed:false,globoPrimed:false};
var gamepad={prevButtons:{},chargeAction:null,move:{x:0,y:0},aim:{x:0,y:0},smashTapConsumed:false,cutVolleyTapConsumed:false,globoTapConsumed:false,smashUpgradeQueued:false,cutVolleyQueued:false,globoQueued:false,tacticQueued:null};
var gamepad2={prevButtons:{},chargeAction:null,move:{x:0,y:0},aim:{x:0,y:0},smashTapConsumed:false,cutVolleyTapConsumed:false,globoTapConsumed:false,hitQueued:false,sliceQueued:false,shotVariantQueued:null,shotAimQueued:null,specialQueued:false,switchQueued:false,switchDirectionQueued:null,smashUpgradeQueued:false,cutVolleyQueued:false,globoQueued:false,tacticQueued:null};
function initAudio(){}
function pulseGamepad(){}
var FIXED_STEP = 1/120;
var MAX_SIM_STEPS = 8;
var simAccumulator = 0;
`;

// The ACTUAL production frame glue (js/main.js:1249-1264), verbatim.
const GLUE = `
simAccumulator = Math.min(simAccumulator + dt, FIXED_STEP * MAX_SIM_STEPS);
var input = getInput();
var input2 = getInput2();
var recInput = input;
var recInput2 = input2;
var steps = 0;
while (simAccumulator >= FIXED_STEP && steps < MAX_SIM_STEPS) {
  var result = updateMatch(sim, FIXED_STEP, input, input2);
  simAccumulator -= FIXED_STEP;
  steps += 1;
  if (result) break;
  if (steps === 1) { input = consumeOneShot(input); input2 = consumeOneShot(input2); }
}
`;

const FIXED_STEP = 1 / 120;

function r6(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return v;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return n.toFixed(6);
}
function fmt(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) out[k] = r6(v);
  return out;
}

function baseState() {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = corpus.seed;
  state.running = true;
  state.serving = false;
  state.rallyHits = 2;
  state.player.hitCooldown = 0;
  state.player.moveRatio = 0;
  state.player.splitStep = 0;
  state.ball.bounces = { player: 0, ai: 1 };
  state.ball.serveInFlight = false;
  state.ball.netFaultOwner = null;
  state.player.x = 480;
  state.player.y = COURT.netY + 170;
  state.ball.x = 480;
  state.ball.y = state.player.y - 125;
  state.ball.z = 160;
  state.ball.vx = 0; state.ball.vy = 0; state.ball.vz = 0;
  return state;
}

function expand(frames) {
  const out = [];
  for (const f of frames) {
    const n = f.n ?? 1;
    for (let k = 0; k < n; k++) out.push(f);
  }
  return out;
}

const corpus = JSON.parse(fs.readFileSync(corpusPath, "utf8"));

function runScenario(sc) {
  const ctx = vm.createContext({});
  vm.runInContext(SETUP + INPUT_FUNCS, ctx);
  ctx.updateMatch = updateMatch;
  const sim = baseState();
  const frames = expand(sc.frames);
  const lines = [];
  for (let i = 0; i < frames.length; i++) {
    const f = frames[i];
    const dt = f.delta;
    const buttons = f.b ?? [];
    const axes = f.a ?? [0, 0, 0, 0, 0, 0];
    ctx.matchState.smashPrimed = sim.smashPrimed === true;
    ctx.matchState.cutVolleyPrimed = sim.cutVolleyPrimed === true;
    ctx.matchState.globoPrimed = sim.globoPrimed === true;
    ctx.pad = {
      axes: axes.slice(0, 4),
      buttons: Array.from({ length: 16 }, (_, bi) => ({
        value: bi === 6 ? axes[4] : bi === 7 ? axes[5] : Number(buttons.includes(bi)),
      })),
    };
    ctx.buttons = buttons;
    ctx.sim = sim;
    ctx.dt = dt;
    vm.runInContext("pollGamepadGameplay(gamepad, pad, i => buttons.includes(i));", ctx);
    vm.runInContext(GLUE, ctx);
    lines.push({
      scenario: sc.id,
      frame: i,
      delta: r6(dt),
      steps: ctx.steps,
      input: fmt(ctx.recInput),
      sim: fmt({
        shotCharge: sim.shotCharge,
        shotIntent: sim.shotIntent,
        queuedShotVariant: sim.queuedShotVariant,
        queuedShotPower: sim.queuedShotPower,
        queuedShotAim: sim.queuedShotAim,
        queuedShotAimY: sim.queuedShotAimY,
        smashPrimed: sim.smashPrimed === true,
        cutVolleyPrimed: sim.cutVolleyPrimed === true,
        globoPrimed: sim.globoPrimed === true,
        playerSwingBuffer: sim.playerSwingBuffer,
      }),
    });
  }
  return lines;
}

const out = [];
out.push(`# js_frame_glue main_js=${mainSha} game_js=${gameSha} seed=${corpus.seed} fixedStep=${FIXED_STEP} scenarios=${corpus.scenarios.length}`);
let total = 0;
for (const sc of corpus.scenarios) {
  const lines = runScenario(sc);
  total += lines.length;
  for (const l of lines) out.push("# trace " + JSON.stringify(l));
}
out.push(`# summary scenarios=${corpus.scenarios.length} frames=${total} exit=0`);
const text = out.join("\n") + "\n";
if (outPath) fs.writeFileSync(outPath, text);
process.stdout.write(text);
