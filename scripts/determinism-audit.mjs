import assert from "node:assert/strict";

import { createMatchState, prepareServe, performServe, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../js/data.js?v=20260910-sprite-gate-v41";

// Deve rispecchiare il ciclo di gioco in main.js.
const FIXED_STEP = 1 / 120;
const MAX_SIM_STEPS = 8;

const EMPTY_INPUT = {
  left: false, right: false, up: false, down: false,
  moveX: 0, moveY: 0, charging: false, hit: false, slice: false,
  shotVariant: null, special: false, switchPlayer: false, switchDirection: null,
  aim: 0, aimY: 0, analogAim: false, splitStep: 0, sprint: 0,
  technicalModifier: false, teamTactic: null, cutVolley: false,
};

/**
 * Gioca lo stesso punto con un seme dato, simulando il ciclo a passo fisso a un
 * frame rate qualsiasi. Il risultato non deve dipendere dal frame rate.
 */
function playPoint(fps, seed, seconds = 3) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = seed;
  state.running = true;
  prepareServe(state);
  state.serving = false;
  performServe(state, 0.6, false);

  let accumulator = 0;
  const frame = 1 / fps;
  for (let f = 0; f < Math.round(fps * seconds); f += 1) {
    accumulator = Math.min(accumulator + frame, FIXED_STEP * MAX_SIM_STEPS);
    let steps = 0;
    while (accumulator >= FIXED_STEP && steps < MAX_SIM_STEPS) {
      updateMatch(state, FIXED_STEP, EMPTY_INPUT, null);
      accumulator -= FIXED_STEP;
      steps += 1;
    }
  }
  return {
    ball: { x: state.ball.x, y: state.ball.y, z: state.ball.z },
    rallyHits: state.rallyHits,
    points: `${state.stats.pointsWon.player}-${state.stats.pointsWon.ai}`,
    rngState: state.rngState,
  };
}

const RATES = [30, 60, 90, 120, 144];
const reference = playPoint(60, 12345);

for (const fps of RATES) {
  assert.deepEqual(
    playPoint(fps, 12345),
    reference,
    `La simulazione deve essere identica a ${fps} fps: la fisica non puo' dipendere dal frame rate`,
  );
}

// Stesso seme, stessa partita: e' il prerequisito di replay e rollback netcode.
assert.deepEqual(
  playPoint(60, 999),
  playPoint(60, 999),
  "Lo stesso seme deve produrre esattamente la stessa partita",
);

// Il seme deve contare davvero, altrimenti ogni partita sarebbe uguale.
assert.notDeepEqual(
  playPoint(60, 111),
  playPoint(60, 222),
  "Semi diversi devono produrre partite diverse",
);

// Nessuna chiamata a Math.random deve restare nella simulazione: basterebbe una
// sola per far divergere due macchine che eseguono gli stessi input.
const source = await import("node:fs/promises")
  .then((fs) => fs.readFile(new URL("../js/game.js", import.meta.url), "utf8"));
// L'unica chiamata ammessa e' quella che semina `rngState` alla creazione della
// partita: da li' in poi la simulazione deve avanzare solo con nextRandom().
const stray = source.split("\n")
  .map((line, index) => ({ line, index: index + 1 }))
  .filter(({ line }) => line.includes("Math.random()") && !line.includes("rngState"));
assert.equal(
  stray.length,
  0,
  `game.js non deve usare Math.random() nella simulazione: ${stray.map((s) => s.index).join(", ")}`,
);

console.log(JSON.stringify({
  frameRates: RATES,
  identicalAcrossRates: true,
  reproducible: true,
  seedSensitive: true,
  strayMathRandom: stray.length,
}, null, 2));
