import assert from "node:assert/strict";

import { createMatchState, updateMatch, hitBall } from "../js/game.js?v=20260910-sprite-gate-v41";
import { ATHLETES, ARENAS, AI_OPPONENTS, BALANCE, COURT } from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * Quanto e' veloce la palla rispetto a chi la rincorre.
 *
 * E' il rapporto che decide se uno sport si sente come uno sport. Nessun audit
 * lo guardava, e infatti era finito alla pari: un drive a piena carica viaggiava
 * a 520 px/s di media contro i 478 del giocatore — il 9% — e uno smash a 580, il
 * 21%. Un drive piano andava a 212 e un pallonetto a 155, cioe' a un terzo della
 * velocita' di chi doveva rincorrerli. La Pantera, a 647 px/s, era piu' veloce
 * di un drive tirato: si arrivava ovunque, e nessuna finestra di contatto per
 * quanto stretta poteva rimediare, perche' la finestra si sposta col giocatore.
 *
 * Tre proprieta', in ordine di importanza:
 *
 *   1. un colpo forte deve poter battere chi corre;
 *   2. nessun atleta puo' essere piu' veloce di un colpo forte;
 *   3. la forbice di velocita' dell'IA deve stare a cavallo di quella degli
 *      atleti — il livello piu' facile sotto il piu' lento, il piu' duro sopra
 *      la maggioranza — altrimenti "difficile" non e' una difficolta', e'
 *      soltanto un avversario che non ti sta dietro.
 */

const VUOTO = {
  moveX: 0, moveY: 0, charging: false, hit: false, slice: false, special: false,
  switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
};

/**
 * Velocita' media della palla dal colpo al primo rimbalzo. La media, non quella
 * iniziale: la palla rallenta per attrito, e chi la insegue corre per tutto il
 * tragitto, non solo nel primo fotogramma.
 */
function velocitaPalla(variante, carica, aim, altezza = 60) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = 11;
  Object.assign(state, {
    running: true, serving: false, pointPause: 0, lastHitterSide: "ai", rallyHits: 3,
    aiServiceReceiverKey: null, serviceReceiverKey: null, aiReceiverLocked: false,
  });
  Object.assign(state.player, { x: 480, y: 395, controlled: true, isPlayer: true, hitCooldown: 0 });
  Object.assign(state.ball, { x: 480, y: 375, z: altezza, vx: 0, vy: 100, vz: 0, crossedNet: true });
  hitBall(state, state.player, carica, false, true, aim, false, variante, variante === "smash" ? -1 : 0);

  let distanza = 0;
  let tempo = 0;
  for (let frame = 0; frame < 1200; frame += 1) {
    const px = state.ball.x;
    const py = state.ball.y;
    state.aiReactionDelay = 99;
    updateMatch(state, 1 / 240, VUOTO);
    distanza += Math.hypot(state.ball.x - px, state.ball.y - py);
    tempo += 1 / 240;
    if (state.ball.bounces.ai) break;
  }
  assert.ok(tempo > 0.05, `Scenario mal costruito: la palla non ha volato (${variante})`);
  return distanza / tempo;
}

const velocitaAtleta = (a) => BALANCE.basePaddleSpeed * a.stats.speed;
const velocitaIa = (p) => p.speed * (0.86 + p.skill * 0.1);

const drivePieno = velocitaPalla("drive", 1.35, 0.9);
const smash = velocitaPalla("smash", 1.35, 0.8, 70);
const drivePiano = velocitaPalla("drive", 0.8, 0);

const piuVeloce = Math.max(...ATHLETES.map(velocitaAtleta));
const piuLento = Math.min(...ATHLETES.map(velocitaAtleta));
const mediano = [...ATHLETES.map(velocitaAtleta)].sort((a, b) => a - b)[Math.floor(ATHLETES.length / 2)];

// --- 1. un colpo forte batte chi corre --------------------------------------

assert.ok(drivePieno / mediano >= 1.35,
  `Un drive a piena carica deve staccare nettamente chi corre: ${Math.round(drivePieno)} px/s `
  + `contro ${Math.round(mediano)} dell'atleta mediano, cioe' ${(drivePieno / mediano).toFixed(2)}x`);
assert.ok(smash / mediano >= 1.5,
  `Uno smash deve staccare piu' del drive: ${(smash / mediano).toFixed(2)}x`);
assert.ok(smash > drivePieno,
  `Lo smash deve essere il colpo piu' veloce: ${Math.round(smash)} contro ${Math.round(drivePieno)}`);

// --- 2. nessun atleta corre piu' di un colpo forte --------------------------
//
// E' la proprieta' che era saltata. Con l'atleta piu' veloce sopra il drive
// pieno non esiste colpo che possa batterlo, e il gioco diventa una rincorsa
// sempre vinta.

assert.ok(piuVeloce < drivePieno,
  `Nessun atleta puo' essere piu' veloce di un drive tirato: il piu' rapido va a `
  + `${Math.round(piuVeloce)} px/s contro i ${Math.round(drivePieno)} della palla`);

// Un colpo piano invece si raggiunge: e' quello che rende una scelta il tirare
// forte, e che tiene in vita gli scambi.
assert.ok(drivePiano < piuLento,
  `Un drive piano deve restare raggiungibile anche dall'atleta piu' lento: `
  + `${Math.round(drivePiano)} px/s contro ${Math.round(piuLento)}`);

// --- 3. la forbice dell'IA sta a cavallo di quella degli atleti -------------

const iaLenta = velocitaIa(AI_OPPONENTS[0]);
const iaDura = velocitaIa(AI_OPPONENTS[AI_OPPONENTS.length - 1]);

assert.ok(iaLenta < piuLento,
  `Il livello piu' facile deve essere piu' lento dell'atleta piu' lento: `
  + `${Math.round(iaLenta)} contro ${Math.round(piuLento)}`);
assert.ok(iaDura > mediano,
  `Il livello piu' duro deve superare l'atleta mediano, altrimenti non e' una `
  + `difficolta': ${Math.round(iaDura)} contro ${Math.round(mediano)}`);

console.log(JSON.stringify({
  palla: { drivePiano: Math.round(drivePiano), drivePieno: Math.round(drivePieno), smash: Math.round(smash) },
  atleti: { piuLento: Math.round(piuLento), mediano: Math.round(mediano), piuVeloce: Math.round(piuVeloce) },
  ia: { piuFacile: Math.round(iaLenta), piuDura: Math.round(iaDura) },
  rapporti: {
    drivePienoSuAtleta: Number((drivePieno / mediano).toFixed(2)),
    smashSuAtleta: Number((smash / mediano).toFixed(2)),
  },
}, null, 2));
