import assert from "node:assert/strict";

import { createMatchState, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { ATHLETES, ARENAS, AI_OPPONENTS, COURT } from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * Le regole del vetro, quelle vere.
 *
 * Regola 13 del regolamento padel, testuale: si perde il punto
 *
 *   "se rimanda la palla, sia direttamente o colpendo prima le pareti della sua
 *    meta' del campo in modo da colpire, senza farla prima rimbalzare, una
 *    parete del campo avversario"
 *
 * Da cui le due meta' della regola, che vanno lette insieme:
 *
 *   - le PROPRIE pareti si possono colpire. Il colpo resta buono, e la palla
 *     resta in gioco: cosa succede dopo lo decide il gioco, non una sanzione.
 *   - le pareti AVVERSARIE no, se la palla non ha prima rimbalzato a terra nel
 *     campo avversario. Li' il punto e' perso da chi ha tirato.
 *
 * Questo file esiste perche' avevo dedotto la regola sbagliata e stavo per
 * scriverla nel motore: avevo reso fallo il contatto col proprio vetro prima
 * della rete, che il regolamento consente esplicitamente. Il segnale che mi
 * aveva tratto in inganno era che due colpi contro il proprio vetro finivano
 * uno con un punto perso e uno con un punto vinto — ma non erano due casi
 * identici trattati in modo incoerente: erano due traiettorie diverse dopo un
 * rimbalzo legale, ed e' esattamente quello che deve succedere.
 *
 * Nota sul banco di prova: e' facilissimo scrivere una traiettoria che rimbalza
 * a terra prima di arrivare al vetro, e allora si sta misurando la regola del
 * gioco normale credendo di misurare quella del fallo. Ogni scenario verifica
 * quanti rimbalzi c'erano nell'istante del contatto, e fallisce se non ha
 * toccato il vetro nelle condizioni volute.
 */

const VUOTO = {
  moveX: 0, moveY: 0, charging: false, hit: false, slice: false, special: false,
  switchPlayer: false, switchDirection: null, aim: 0, aimY: 0, analogAim: false,
};

/**
 * Manda la palla lungo una traiettoria e registra due cose: com'era messa
 * nell'istante in cui ha toccato il vetro, e se in *quello stesso istante* e'
 * stato assegnato un punto. La seconda e' cio' che distingue una sanzione dal
 * gioco che prosegue.
 */
function scenario(palla, extra = {}) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  state.rngState = 4242;
  Object.assign(state, {
    running: true, serving: false, pointPause: 0, rallyHits: 3,
    aiServiceReceiverKey: null, serviceReceiverKey: null, aiReceiverLocked: false,
    ...extra,
  });
  // Racchette agli angoli opposti: nessuna deve intercettare e falsare il verdetto.
  Object.assign(state.player, { x: 100, y: 550, controlled: true, isPlayer: true, hitCooldown: 0 });
  Object.assign(state.playerMate, { x: 860, y: 550, hitCooldown: 0 });
  Object.assign(state.opponent, { x: 100, y: 70, hitCooldown: 0 });
  Object.assign(state.opponentMate, { x: 860, y: 70, hitCooldown: 0 });
  Object.assign(state.ball, { bounces: { player: 0, ai: 0 }, serveInFlight: false, netFaultOwner: null, ...palla });

  let alVetro = null;
  for (let frame = 0; frame < 1500; frame += 1) {
    state.aiReactionDelay = 99;
    const prima = {
      x: state.ball.x, y: state.ball.y, r: state.ball.r,
      bounces: { ...state.ball.bounces },
      punti: state.stats.pointsWon.player + state.stats.pointsWon.ai,
    };
    updateMatch(state, 1 / 240, VUOTO);
    const puntiOra = state.stats.pointsWon.player + state.stats.pointsWon.ai;
    // Il vetro si attraversa *durante* l'aggiornamento: guardando solo la
    // posizione precedente il fotogramma del contatto sfugge, e quando il
    // contatto e' anche un fallo la partita finisce prima che lo si veda.
    const b = state.ball;
    const tocca = b.x - b.r <= COURT.left + 1 || b.x + b.r >= COURT.right - 1
      || b.y - b.r <= COURT.top + 1 || b.y + b.r >= COURT.bottom - 1;
    if (tocca && !alVetro) {
      alVetro = { lato: prima.y < COURT.netY ? "ai" : "player", rimbalzi: prima.bounces, frame };
    }
    if (puntiOra > 0) {
      return {
        vincitore: state.stats.pointsWon.player ? "player" : "ai",
        alVetro,
        // Quanti fotogrammi fra il vetro e il punto. Inseguire il fotogramma
        // esatto non funziona — la soglia geometrica di una sonda non coincide
        // mai con quella del motore — ma la distanza fra i due dice tutto:
        // vicini significa che il vetro ha chiuso il punto, lontani che il
        // gioco e' proseguito e il punto l'ha deciso altro.
        distanza: alVetro ? frame - alVetro.frame : null,
      };
    }
  }
  return { vincitore: null, alVetro, distanza: null };
}

// --- 1. il vetro avversario al volo e' fallo di chi tira --------------------

for (const [nome, palla] of [
  ["laterale", { x: 760, y: 190, z: 74, vx: 900, vy: -30, vz: 260, crossedNet: true }],
  ["di fondo", { x: 480, y: 180, z: 74, vx: 0, vy: -760, vz: 260, crossedNet: true }],
]) {
  const esito = scenario(palla, { lastHitterSide: "player" });
  assert.ok(esito.alVetro, `Scenario mal costruito: la palla non arriva al vetro ${nome} avversario`);
  assert.equal(esito.alVetro.lato, "ai", `Il contatto deve avvenire nel campo avversario (${nome})`);
  assert.equal(esito.alVetro.rimbalzi.ai, 0,
    `Scenario mal costruito: la palla ha gia' rimbalzato prima del vetro ${nome}, quindi il colpo e' legale`);
  assert.equal(esito.vincitore, "ai",
    `Vetro avversario ${nome} colpito senza rimbalzo: il punto lo perde chi ha tirato`);
  assert.ok(esito.distanza !== null && esito.distanza <= 3,
    `Il fallo va sanzionato al contatto col vetro ${nome}: fra vetro e punto sono passati ${esito.distanza} fotogrammi`);
}

// --- 2. le proprie pareti sono consentite -----------------------------------
//
// Il cuore della regola 13, ed e' quello che avevo sbagliato. Non si pretende
// chi vince il punto: si pretende che al contatto col proprio vetro NON venga
// assegnato niente, perche' la palla e' ancora in gioco.

for (const [nome, palla] of [
  ["laterale", { x: 760, y: 470, z: 74, vx: 900, vy: -30, vz: 260, crossedNet: false }],
  ["di fondo", { x: 480, y: 470, z: 74, vx: 0, vy: 760, vz: 260, crossedNet: false }],
]) {
  const esito = scenario(palla, { lastHitterSide: "player" });
  assert.ok(esito.alVetro, `Scenario mal costruito: la palla non arriva al proprio vetro ${nome}`);
  assert.equal(esito.alVetro.lato, "player", `Il contatto deve avvenire nel proprio campo (${nome})`);
  assert.equal(esito.alVetro.rimbalzi.player, 0,
    `Scenario mal costruito: la palla ha gia' rimbalzato prima del proprio vetro ${nome}`);
  assert.ok(esito.distanza === null || esito.distanza > 30,
    `Colpire il proprio vetro ${nome} prima della rete e' consentito dalla regola 13: `
    + `la palla deve restare in gioco, invece il punto arriva dopo ${esito.distanza} fotogrammi`);
}

// --- 3. dopo il rimbalzo il vetro e' gioco normale --------------------------

const legale = scenario(
  { x: 480, y: 150, z: 26, vx: 0, vy: -260, vz: -30, crossedNet: true, bounces: { player: 0, ai: 1 } },
  { lastHitterSide: "player" },
);
assert.equal(legale.vincitore, "player",
  "Palla rimbalzata nel campo avversario e poi finita sul vetro: e' gioco normale");

// --- 4. il servizio sul vetro e' fallo di battuta ---------------------------
//
// Sul servizio la regola e' piu' stretta: la palla non puo' toccare una parete
// avversaria prima del secondo rimbalzo, ed e' sempre fallo di battuta — mai un
// punto per chi serve.

const servizio = scenario(
  { x: 760, y: 190, z: 74, vx: 900, vy: -30, vz: 260, crossedNet: true, serveInFlight: true },
  { lastHitterSide: "player", serveSide: "player", serveAttempts: 0 },
);
assert.notEqual(servizio.vincitore, "player",
  "Un servizio finito sul vetro avversario non puo' fare punto a chi serve");

console.log(JSON.stringify({
  regola: "13",
  vetroAvversarioSenzaRimbalzo: "punto perso da chi tira",
  proprioVetroPrimaDellaRete: "consentito, palla in gioco",
  vetroDopoIlRimbalzo: "gioco normale",
  servizioSulVetro: "fallo di battuta",
}, null, 2));
