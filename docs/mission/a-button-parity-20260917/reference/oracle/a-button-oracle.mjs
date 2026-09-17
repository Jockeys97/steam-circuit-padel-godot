/**
 * a-button-oracle.mjs — executable oracle of the ACTUAL browser A-button input path.
 *
 * It runs the real production input functions extracted from js/main.js
 * (`radialStick`, `shotAimAxis`, `isSliceAction`, `pollGamepadGameplay`, `getInput`)
 * inside a Node VM — no reimplementation of browser semantics — and, for each
 * frame, feeds the translated `getInput()` result straight into the real
 * `updateMatch` from js/game.js to observe queued-shot / primed / contact state.
 *
 * Stage 1 (input path): raw pad -> pollGamepadGameplay -> getInput -> translated input.
 * Stage 2 (sim):       translated input -> updateMatch -> queued/shot outcomes.
 *
 * Both stages execute the actual production functions; nothing is rewritten.
 *
 * Output (stdout), one line per frame:
 *   # trace {"scenario":..,"frame":..,"input":{..},"sim":{..}}
 * Plus a header line with source hashes and a summary line. Numbers are
 * pre-formatted to 6 decimals so the stream is byte-comparable (tol=0) against
 * the Godot port's replay of the same corpus.
 *
 * Usage:
 *   node reference/oracle/a-button-oracle.mjs [--corpus=path] [--out=path]
 */

import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import crypto from "node:crypto";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "../../../../../");
const MAIN_JS = path.join(ROOT, "js", "main.js");
const GAME_JS = path.join(ROOT, "js", "game.js");
const DATA_JS = path.join(ROOT, "js", "data.js");
const CORPUS = path.join(__dirname, "../corpus/scenarios.json");

function arg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const corpusPath = arg("corpus", CORPUS);
const outPath = arg("out", null);

// --- real production modules -------------------------------------------------
const game = await import(pathToFileURL(GAME_JS).href);
const data = await import(pathToFileURL(DATA_JS).href);
const { createMatchState, updateMatch } = game;
const { ATHLETES, ARENAS, AI_OPPONENTS, COURT } = data;

const mainSource = fs.readFileSync(MAIN_JS, "utf8");
const mainSha = crypto.createHash("sha256").update(mainSource).digest("hex");
const gameSha = crypto
  .createHash("sha256")
  .update(fs.readFileSync(GAME_JS, "utf8"))
  .digest("hex");

// --- extract the real input functions (verbatim) -----------------------------
function extract(name) {
  const start = mainSource.indexOf("function " + name + "(");
  const end = mainSource.indexOf("\nfunction ", start + 1);
  if (start < 0 || end < 0) throw new Error("missing reference " + name);
  return mainSource.slice(start, end);
}
const INPUT_FUNCS = ["radialStick", "shotAimAxis", "isSliceAction", "pollGamepadGameplay", "getInput"]
  .map(extract)
  .join("\n");

const SETUP = `
var ui = { gamepadDeadzone: 0.15 };
var keys = new Set();
var hitQueued=false, sliceQueued=false, shotVariantQueued=null, shotAimQueued=null;
var specialQueued=false, switchQueued=false, switchDirectionQueued=null;
var matchState={humanMode:"solo",smashPrimed:false,cutVolleyPrimed:false,globoPrimed:false};
var gamepad={prevButtons:{},chargeAction:null,move:{x:0,y:0},aim:{x:0,y:0},smashTapConsumed:false,cutVolleyTapConsumed:false,globoTapConsumed:false};
function initAudio(){}
function pulseGamepad(){}
`;

// --- formatting (byte-comparable, tol=0) -------------------------------------
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

// --- benches -----------------------------------------------------------------
function baseState(bench) {
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
  if (bench === "contact") {
    // Close approaching ball so the queued drive strikes within the swing buffer.
    state.player.x = 480;
    state.player.y = COURT.netY + 220; // behind the smash net window: plain drive
    state.ball.x = 480;
    state.ball.y = state.player.y - 30;
    state.ball.z = 55;
    state.ball.vx = 0;
    state.ball.vy = 260;
    state.ball.vz = 100;
  } else {
    // Floating ball placed high: stays above the court for the whole charge
    // window (~85 ticks under arcade gravity) so it never bounces/ends the point
    // during a full-charge + double-tap timeline. It is far enough from the
    // paddle laterally that no contact occurs: this isolates the input->queued seam.
    state.player.x = 480;
    state.player.y = COURT.netY + 170; // within smashNetWindow (190): priming observable
    state.ball.x = 480;
    state.ball.y = state.player.y - 125;
    state.ball.z = 160;
    state.ball.vx = 0;
    state.ball.vy = 0;
    state.ball.vz = 0;
  }
  return state;
}

// --- run one scenario --------------------------------------------------------
function runScenario(sc) {
  const ctx = vm.createContext({});
  vm.runInContext(SETUP + INPUT_FUNCS, ctx);
  const sim = baseState(sc.bench ?? "stationary");

  const base = String(sim.ball.shotType);
  const frames = [];
  for (const f of sc.frames) {
    const n = f.n ?? 1;
    for (let k = 0; k < n; k++) frames.push(f);
  }

  const lines = [];
  for (let i = 0; i < frames.length; i++) {
    const f = frames[i];
    const buttons = f.b ?? [];
    const axes = f.a ?? [0, 0, 0, 0, 0, 0];
    // Sync the real primed flags into the VM matchState so the double-tap edge
    // sees what the sim actually computed last tick.
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
    const translated = vm.runInContext(
      "pollGamepadGameplay(gamepad, pad, i => buttons.includes(i)); getInput();",
      ctx,
    );
    updateMatch(sim, corpus.dt, translated);
    const shotType = String(sim.ball.shotType);
    lines.push({
      scenario: sc.id,
      frame: i,
      input: fmt(translated),
      sim: fmt({
        shotCharge: sim.shotCharge,
        shotIntent: sim.shotIntent,
        queuedShotVariant: sim.queuedShotVariant,
        queuedShotPower: sim.queuedShotPower,
        queuedShotSlice: sim.queuedShotSlice === true,
        queuedShotAim: sim.queuedShotAim,
        queuedShotAimY: sim.queuedShotAimY,
        smashPrimed: sim.smashPrimed === true,
        cutVolleyPrimed: sim.cutVolleyPrimed === true,
        globoPrimed: sim.globoPrimed === true,
        playerSwingBuffer: sim.playerSwingBuffer,
        shotType,
      }),
    });
  }
  return { sc, base, lines };
}

// --- main --------------------------------------------------------------------
const corpus = JSON.parse(fs.readFileSync(corpusPath, "utf8"));

const header =
  `# oracle main_js=${mainSha.slice(0, 16)} game_js=${gameSha.slice(0, 16)} ` +
  `seed=${corpus.seed} dt=${corpus.dt} scenarios=${corpus.scenarios.length}`;
const out = [];
out.push(header);

let totalFrames = 0;
for (const sc of corpus.scenarios) {
  out.push(`# scenario ${sc.id} bench=${sc.bench ?? "stationary"} frames=${sc.frames.reduce((s, f) => s + (f.n ?? 1), 0)}`);
  const { lines } = runScenario(sc);
  totalFrames += lines.length;
  for (const l of lines) out.push("# trace " + JSON.stringify(l));
}

out.push(`# summary scenarios=${corpus.scenarios.length} frames=${totalFrames} exit=0`);
const text = out.join("\n") + "\n";
if (outPath) fs.writeFileSync(outPath, text);
process.stdout.write(text);
