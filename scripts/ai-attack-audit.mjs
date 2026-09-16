import assert from "node:assert/strict";

import { createMatchState, updateMatch, hitBall } from "../js/game.js?v=20260910-sprite-gate-v41";
import { ATHLETES, ARENAS, AI_OPPONENTS, COURT } from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * L'IA deve punire un pallonetto mal riuscito, e lasciar stare quello buono.
 *
 * E' la promessa che regge il pallonetto come colpo: se un lob corto non viene
 * castigato, alzare la palla diventa gratis e il repertorio si riduce a uno.
 * Nessun audit la sorvegliava, e non e' una proprieta' che si nota rompendola —
 * si nota mesi dopo, quando il gioco e' diventato piatto senza sapere quando.
 *
 * ATTENZIONE AL BANCO DI PROVA. `aiServiceReceiverKey` vale "opponent" da quando
 * la partita nasce, e finche' e' impostata le racchette avversarie vengono
 * portate in posizione di ricezione del servizio — `COURT.top + 74`, cioe'
 * y=130 — da un ramo che precede del tutto la logica di difesa. Uno scambio
 * simulato senza azzerarla non misura l'IA che difende: misura l'IA che aspetta
 * un servizio. Su quell'errore ho concluso che l'IA arretrava sempre e non
 * attaccava mai, che e' esattamente il contrario di quello che fa.
 */

const VUOTO = {
  moveX: 0, moveY: 0, charging: false, hit: false, slice: false, special: false,
  switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
};

const ATTACCANTI = new Set(["smash-x2", "smash-x3", "vibora", "volley"]);

function pallonetto(carica, seme, aiIndex = 2) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[aiIndex]);
  state.rngState = seme;
  Object.assign(state, {
    running: true, serving: false, pointPause: 0, lastHitterSide: "ai", rallyHits: 3,
    aiServiceReceiverKey: null, serviceReceiverKey: null, aiReceiverLocked: false,
  });
  Object.assign(state.player, { x: 480, y: 500, controlled: true, isPlayer: true, hitCooldown: 0 });
  Object.assign(state.playerMate, { x: 700, y: 480, hitCooldown: 0 });
  Object.assign(state.opponent, { x: 480, y: COURT.top + 76, hitCooldown: 0 });
  Object.assign(state.opponentMate, { x: 650, y: COURT.netY - 84, hitCooldown: 0 });
  Object.assign(state.ball, {
    x: 480, y: 480, z: 70, vx: 0, vy: -100, vz: 0,
    bounces: { player: 0, ai: 0 }, serveInFlight: false, netFaultOwner: null, crossedNet: true,
  });

  hitBall(state, state.player, carica, false, true, 0, false, "lob", 0);

  const partenza = state.opponent.y;
  let avanzataMax = 0;
  const colpiPrima = state.rallyHits;
  for (let frame = 0; frame < 2400; frame += 1) {
    updateMatch(state, 1 / 240, VUOTO);
    avanzataMax = Math.max(avanzataMax, state.opponent.y - partenza);
    if (state.rallyHits > colpiPrima) return { colpo: state.ball.shotType, avanzata: avanzataMax };
    if (state.stats.pointsWon.player || state.stats.pointsWon.ai) break;
  }
  return { colpo: null, avanzata: avanzataMax };
}

function campagna(carica, quanti = 60) {
  const esiti = [];
  for (let i = 0; i < quanti; i += 1) esiti.push(pallonetto(carica, 1000 + i * 7919));
  const giocati = esiti.filter((e) => e.colpo);
  return {
    giocati: giocati.length,
    attacchi: giocati.filter((e) => ATTACCANTI.has(e.colpo)).length,
    smash: giocati.filter((e) => e.colpo.startsWith("smash")).length,
    avanzata: esiti.reduce((somma, e) => somma + e.avanzata, 0) / esiti.length,
    colpi: giocati.reduce((conta, e) => ({ ...conta, [e.colpo]: (conta[e.colpo] ?? 0) + 1 }), {}),
  };
}

const corto = campagna(0.45);
const profondo = campagna(1.1);

assert.ok(corto.giocati > 40, `Il pallonetto corto deve essere rigiocato quasi sempre: ${corto.giocati}/60`);
assert.ok(profondo.giocati > 40, `Il pallonetto profondo deve essere rigiocato quasi sempre: ${profondo.giocati}/60`);

// --- il lob corto si paga -------------------------------------------------

const tassoAttacco = corto.attacchi / corto.giocati;
assert.ok(tassoAttacco > 0.6,
  `Un pallonetto corto deve essere aggredito nella maggioranza dei casi: ${(tassoAttacco * 100).toFixed(0)}% (${JSON.stringify(corto.colpi)})`);
assert.ok(corto.smash / corto.giocati > 0.4,
  `E lo smash deve essere la risposta piu' comune, non un caso raro: ${corto.smash}/${corto.giocati}`);

// L'IA ci arriva avanzando: se restasse ferma la palla le scenderebbe sotto e
// nessuna taratura di `attackRead` potrebbe salvarla.
assert.ok(corto.avanzata > 30,
  `Per prendere il pallonetto in aria l'IA deve farsi avanti: avanza ${corto.avanzata.toFixed(0)} px`);

// --- il lob profondo no ---------------------------------------------------

const tassoProfondo = profondo.attacchi / profondo.giocati;
assert.ok(tassoProfondo < 0.2,
  `Un pallonetto profondo non si attacca da fondo campo: ${(tassoProfondo * 100).toFixed(0)}% (${JSON.stringify(profondo.colpi)})`);
assert.ok(tassoAttacco > tassoProfondo + 0.4,
  `La differenza fra corto e profondo deve essere netta: ${(tassoAttacco * 100).toFixed(0)}% contro ${(tassoProfondo * 100).toFixed(0)}%`);

// --- prendere il campo deve costare ---------------------------------------
//
// L'altra meta' della stessa promessa. Se avanzare non viene pallonettato,
// esiste una strategia che vince sempre: smash, prendi la rete, ripeti. Era
// cosi': contro un giocatore incollato alla rete la Leggenda alzava la palla nel
// 45% dei casi, contro uno a meta' campo nello 0%, perche' il test sulla
// posizione era una soglia secca. Bastava staccarsi di venti pixel per non
// essere piu' pallonettati, e il centro del campo era terra libera.

function quantoPallonetta(aiIndex, yGiocatore, quanti = 240) {
  let lob = 0;
  for (let i = 0; i < quanti; i += 1) {
    const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[aiIndex]);
    state.rngState = i * 7919 + 7;
    Object.assign(state, {
      running: true, serving: false, pointPause: 0, lastHitterSide: "player", rallyHits: 4,
      aiServiceReceiverKey: null, serviceReceiverKey: null, aiReceiverLocked: false,
    });
    Object.assign(state.player, { x: 430, y: yGiocatore, controlled: true, isPlayer: true, hitCooldown: 0 });
    Object.assign(state.playerMate, { x: 620, y: yGiocatore + 10, hitCooldown: 0 });
    Object.assign(state.opponent, { x: 480, y: 150, hitCooldown: 0 });
    Object.assign(state.opponentMate, { x: 600, y: 220, hitCooldown: 0 });
    Object.assign(state.ball, { x: 480, y: 170, z: 60, vx: 0, vy: -80, vz: 0, bounces: { player: 0, ai: 0 }, crossedNet: true });
    hitBall(state, state.opponent, 1, false, true);
    if (state.ball.shotType === "lob") lob += 1;
  }
  return lob / quanti;
}

const DURISSIMO = AI_OPPONENTS.length - 1;
const aRete = quantoPallonetta(DURISSIMO, COURT.netY + 70);
const aMeta = quantoPallonetta(DURISSIMO, COURT.netY + 150);
const alFondo = quantoPallonetta(DURISSIMO, COURT.bottom - 60);

assert.ok(aRete > 0.4,
  `Chi sta a rete deve essere pallonettato spesso: ${(aRete * 100).toFixed(0)}%`);
// E' il numero che rompe la strategia dominante: senza questo, guadagnare il
// centro del campo non costa niente.
assert.ok(aMeta > 0.15,
  `Anche a meta' campo si deve rischiare il pallonetto: ${(aMeta * 100).toFixed(0)}%`);
assert.ok(aRete > aMeta && aMeta > alFondo,
  `Il rischio deve crescere avanzando, senza salti: rete ${(aRete * 100).toFixed(0)}%, `
  + `meta' ${(aMeta * 100).toFixed(0)}%, fondo ${(alFondo * 100).toFixed(0)}%`);
// Chi resta sul fondo non va pallonettato di continuo: li' e' un colpo di
// varieta', non una risposta.
assert.ok(alFondo < 0.25,
  `Sul fondo il pallonetto deve restare raro: ${(alFondo * 100).toFixed(0)}%`);

const piuFacile = quantoPallonetta(0, COURT.netY + 70);
assert.ok(aRete > piuFacile + 0.1,
  `Il livello piu' duro deve pallonettare piu' del piu' facile: ${(aRete * 100).toFixed(0)}% contro ${(piuFacile * 100).toFixed(0)}%`);

// --- e deve muovere l'avversario ------------------------------------------
//
// Il bersaglio laterale era a distanza fissa dal centro e l'unica cosa che
// cambiava con la bravura era la dispersione, che cala. Ne seguiva l'assurdo:
// la Leggenda era piu' centrale dell'Ingegnere — 100% dei rimbalzi nel terzo
// centrale contro l'83% — perche' colpiva con piu' precisione un bersaglio che
// stava in mezzo. Un avversario che non ti sposta non e' un avversario difficile.

function scartoDalCentro(aiIndex, quanti = 300) {
  const centro = (COURT.left + COURT.right) / 2;
  const semi = (COURT.right - COURT.left) / 2;
  const scarti = [];
  for (let i = 0; i < quanti; i += 1) {
    const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[aiIndex]);
    state.rngState = i * 7919 + 21;
    Object.assign(state, {
      running: true, serving: false, pointPause: 0, lastHitterSide: "player", rallyHits: 4,
      aiServiceReceiverKey: null, serviceReceiverKey: null, aiReceiverLocked: false,
    });
    Object.assign(state.player, { x: 480, y: 430, controlled: true, isPlayer: true, hitCooldown: 0 });
    Object.assign(state.playerMate, { x: 670, y: 440, hitCooldown: 0 });
    Object.assign(state.opponent, { x: 480, y: 150, hitCooldown: 0 });
    Object.assign(state.opponentMate, { x: 600, y: 220, hitCooldown: 0 });
    Object.assign(state.ball, { x: 480, y: 170, z: 60, vx: 0, vy: -80, vz: 0, bounces: { player: 0, ai: 0 }, crossedNet: true });
    hitBall(state, state.opponent, 1, false, true);
    for (let frame = 0; frame < 3000; frame += 1) {
      state.aiReactionDelay = 99;
      updateMatch(state, 1 / 240, VUOTO);
      if (state.ball.bounces.player) { scarti.push(Math.abs(state.ball.x - centro) / semi); break; }
      if (state.stats.pointsWon.player || state.stats.pointsWon.ai) break;
    }
  }
  const medio = scarti.reduce((a, b) => a + b, 0) / scarti.length;
  return { medio, centrale: scarti.filter((v) => v < 0.33).length / scarti.length };
}

const angoliFacile = scartoDalCentro(0);
const angoliDuro = scartoDalCentro(AI_OPPONENTS.length - 1);

assert.ok(angoliDuro.medio > 0.45,
  `Il livello piu' duro deve spostare l'avversario: rimbalzi in media al `
  + `${(angoliDuro.medio * 100).toFixed(0)}% della semi-larghezza dal centro`);
assert.ok(angoliDuro.centrale < 0.2,
  `Non puo' finire tutto nel terzo centrale: ${(angoliDuro.centrale * 100).toFixed(0)}%`);
assert.ok(angoliDuro.medio > angoliFacile.medio + 0.05,
  `Chi e' piu' bravo deve angolare di piu', non di meno: facile `
  + `${(angoliFacile.medio * 100).toFixed(0)}%, duro ${(angoliDuro.medio * 100).toFixed(0)}%`);

console.log(JSON.stringify({
  corto: { attacchiPercento: Math.round(tassoAttacco * 100), avanzataPx: Math.round(corto.avanzata), colpi: corto.colpi },
  profondo: { attacchiPercento: Math.round(tassoProfondo * 100), colpi: profondo.colpi },
  pallonettaContro: { rete: Math.round(aRete * 100), meta: Math.round(aMeta * 100), fondo: Math.round(alFondo * 100) },
  angoli: { facile: Math.round(angoliFacile.medio * 100), duro: Math.round(angoliDuro.medio * 100) },
}, null, 2));
