/**
 * probe-drill.mjs — reads the reference drill's OWN measured values for the two
 * audit sections whose expectations are numbers rather than booleans.
 *
 * `scripts/drill-audit.mjs` asserts §7 (a closed attempt carries a diagnosis) and
 * §8 (the squash scale is monotone) but prints neither the diagnoses nor the
 * samples. Without them, "the port reproduces the reference" is a claim about
 * assertions instead of about values. This probe runs the SAME scenarios with the
 * SAME seeds and prints both, so the ported audit's `# report` lines can be
 * compared with the reference's side by side.
 *
 * It patches `Math.random` exactly as the audit does — which is the only reason
 * the reference's drill is reproducible at all (`js/drill.js:155,159,160` draws
 * from the global generator; see `godot/src/modes/drill_seed.gd`).
 *
 * It does not modify `js/**`. It only reads.
 *
 *   node tools/modes-port/probe-drill.mjs
 */

import {
  DRILL_EXERCISES,
  createDrill,
  exerciseById,
  updateDrill,
} from "../../js/drill.js?v=20260814-feedback-v38";
import { ARENAS, ATHLETES, AI_OPPONENTS } from "../../js/data.js?v=20260814-feedback-v38";

const STEP = 1 / 120;

function seededRandom(seed) {
  let value = seed >>> 0;
  return () => {
    value = (value + 0x6D2B79F5) | 0;
    let t = Math.imul(value ^ (value >>> 15), 1 | value);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const INPUT = {
  moveX: 0, moveY: 0, charging: false, hit: false, hold: false, slice: false,
  special: false, switchPlayer: false, switchDirection: null, aim: 0, aimY: 0,
  analogAim: false, teamTactic: null, shotVariant: null,
};
const input = (over = {}) => ({ ...INPUT, ...over });

/** The reference audit's scripted player (`scripts/drill-audit.mjs:110-111`). */
function scriptedStep(drill, over = {}) {
  const palla = drill.state.ball;
  const vicina = Math.abs(palla.y - drill.state.player.y) < 90 && palla.z <= 108;
  updateDrill(drill, STEP, vicina ? input({ hit: true, charging: true, ...over }) : input());
}

// ── §7: the diagnoses, for the same seeds the ported audit uses ──────────────
const diagnosi = {};
for (const esercizio of DRILL_EXERCISES) {
  Math.random = seededRandom(4321);
  const drill = createDrill(esercizio.id, ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  updateDrill(drill, STEP, input({ hit: true }));
  for (let frame = 0; frame < 3600 && drill.phase !== "result"; frame += 1) scriptedStep(drill);
  diagnosi[esercizio.id] = drill.diagnosis;
}

// ── §8: the squash samples, same seeds and same slice rule ──────────────────
const campioni = [];
for (const seed of [3, 9, 15, 21, 27, 33]) {
  Math.random = seededRandom(seed);
  const drill = createDrill("precision", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  updateDrill(drill, STEP, input({ hit: true }));
  for (let frame = 0; frame < 2400 && drill.phase !== "result"; frame += 1) {
    scriptedStep(drill, { slice: seed % 2 === 0 });
  }
  if (drill.impactVz > 0) campioni.push({ vz: drill.impactVz, q: drill.squash });
}

// ── the exercise table and the fallback, for the record ─────────────────────
const fallback = exerciseById("inesistente").id;

console.log(JSON.stringify({
  diagnosi,
  fallback,
  esercizi: DRILL_EXERCISES.map((e) => e.id),
  campioni,
}, null, 2));
