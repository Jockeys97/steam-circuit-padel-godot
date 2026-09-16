import assert from "node:assert/strict";

import { createMatchState, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { ATHLETES, ARENAS, AI_OPPONENTS, COURT, MATCH_FORMATS } from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * I formati di partita, giocati davvero.
 *
 * Non verifica la tabella: verifica il motore. Un formato si specifica con tre
 * numeri — game per set, margine, set da vincere — e sbagliarne uno non da'
 * nessun errore, produce una partita che finisce quando non dovrebbe o che non
 * finisce affatto. Un "al meglio di 3 game" con margine due, per esempio, non si
 * potrebbe vincere 2-1, cioe' nel modo piu' probabile.
 *
 * Qui i punti vengono assegnati facendo uscire la palla dal fondo di una delle
 * due meta': e' come finisce un punto vero, quindi passa da `scorePoint`,
 * `finishGame` e `finishSet` come in partita.
 */

const VUOTO = {
  moveX: 0, moveY: 0, charging: false, hit: false, slice: false, special: false,
  switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
};

function nuovaPartita(formato) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  Object.assign(state, formato, { running: true });
  return state;
}

/** Assegna un punto al lato indicato mandando fuori la palla dell'altro. */
function assegnaPunto(state, aChi) {
  const perdente = aChi === "player" ? "ai" : "player";
  Object.assign(state, { serving: false, pointPause: 0 });
  Object.assign(state.ball, {
    x: 480,
    y: perdente === "player" ? COURT.top - 80 : COURT.bottom + 80,
    z: 2, vx: 0, vy: perdente === "player" ? -300 : 300, vz: -50,
    crossedNet: true, serveInFlight: false,
  });
  state.lastHitterSide = perdente;
  const prima = state.points.player + state.points.ai
    + state.games.player + state.games.ai + state.sets.player + state.sets.ai
    + state.tieBreakPoints.player + state.tieBreakPoints.ai;
  for (let frame = 0; frame < 4000; frame += 1) {
    const esito = updateMatch(state, 1 / 240, VUOTO);
    if (esito) return esito;
    const ora = state.points.player + state.points.ai
      + state.games.player + state.games.ai + state.sets.player + state.sets.ai
      + state.tieBreakPoints.player + state.tieBreakPoints.ai;
    if (ora !== prima) return null;
  }
  throw new Error("Il punto non è mai stato assegnato");
}

/** Il giocatore vince ogni punto: conta quanti gliene servono per chiudere. */
function partitaADominio(formato) {
  const state = nuovaPartita(formato);
  let punti = 0;
  for (; punti < 400; punti += 1) {
    const esito = assegnaPunto(state, "player");
    if (esito) {
      return { punti: punti + 1, vincitore: esito.winner, games: state.games, sets: state.sets };
    }
  }
  throw new Error("La partita non finisce nemmeno vincendo 400 punti di fila");
}

const report = {};

for (const [id, formato] of Object.entries(MATCH_FORMATS)) {
  const esito = partitaADominio(formato);
  assert.equal(esito.vincitore, "player", `${id}: vincendo ogni punto deve vincere il giocatore`);

  if (formato.scoring === "points") {
    assert.equal(esito.punti, formato.pointsToWin,
      `${id}: attesi ${formato.pointsToWin} punti, servono ${esito.punti}`);
  } else {
    // Un game si vince a quattro punti; vincendoli tutti non c'e' vantaggio.
    const attesi = 4 * formato.gamesToWin * formato.setsToWin;
    assert.equal(esito.punti, attesi,
      `${id}: attesi ${attesi} punti (${formato.gamesToWin} game × ${formato.setsToWin} set), servono ${esito.punti}`);
    assert.equal(esito.sets.player, formato.setsToWin,
      `${id}: la partita deve chiudersi a ${formato.setsToWin} set`);
  }
  report[id] = { puntiPerVincere: esito.punti };
}

// Il caso che il margine governa: nei formati brevi si deve poter vincere di uno.
for (const id of ["games3", "games5"]) {
  const formato = MATCH_FORMATS[id];
  const state = nuovaPartita(formato);
  // L'avversario prende tutti i game meno uno, poi il giocatore li vince tutti.
  for (let game = 0; game < formato.gamesToWin - 1; game += 1) {
    for (let punto = 0; punto < 4; punto += 1) assegnaPunto(state, "ai");
  }
  let esito = null;
  for (let punto = 0; punto < 4 * formato.gamesToWin && !esito; punto += 1) {
    esito = assegnaPunto(state, "player");
  }
  assert.ok(esito, `${id}: un set vinto ${formato.gamesToWin}-${formato.gamesToWin - 1} deve chiudere la partita`);
  assert.equal(esito.winner, "player", `${id}: deve vincere chi ha preso l'ultimo game`);
  report[id].vinceDiUno = true;
}

// Il set pieno deve invece pretendere i due game di scarto, e arrivare al
// tie-break sul 6-6: e' la regola vera, e senza margine sparirebbe.
{
  const state = nuovaPartita(MATCH_FORMATS.set);
  for (let game = 0; game < 5; game += 1) {
    for (let punto = 0; punto < 4; punto += 1) assegnaPunto(state, "ai");
  }
  for (let punto = 0; punto < 20; punto += 1) assegnaPunto(state, "player");
  assert.deepEqual({ p: state.games.player, a: state.games.ai }, { p: 5, a: 5 },
    `Set pieno: atteso 5-5, trovato ${state.games.player}-${state.games.ai}`);
  for (let punto = 0; punto < 4; punto += 1) assegnaPunto(state, "player");
  assert.equal(state.sets.player, 0,
    "Set pieno: 6-5 non deve chiudere il set, servono due game di scarto");
  for (let punto = 0; punto < 4; punto += 1) assegnaPunto(state, "ai");
  assert.equal(state.tieBreak, true, "Set pieno: sul 6-6 deve partire il tie-break");
  report.set.tieBreak = true;
}

console.log(JSON.stringify({ formati: Object.keys(MATCH_FORMATS).length, ...report }, null, 2));
