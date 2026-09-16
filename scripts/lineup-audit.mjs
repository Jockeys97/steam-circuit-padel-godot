import assert from "node:assert/strict";

import { createMatchState, hitBall, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { ATHLETES, AI_OPPONENTS, ARENAS, ROSTER_AVERAGE } from "../js/data.js?v=20260910-sprite-gate-v41";

// Prima di questa funzione il compagno riceveva le statistiche del giocatore —
// era un clone con un'altra faccia — e i due avversari non avevano statistiche
// affatto. Qui si verifica che la scelta arrivi davvero al motore e, soprattutto,
// che farla contare non trasformi la formazione in un secondo selettore di
// difficolta' nascosto dentro quello vero.

const byId = (id) => ATHLETES.find((a) => a.id === id);
const controllo = [...ATHLETES].sort((a, b) => b.stats.control - a.stats.control)[0];
const potenza = [...ATHLETES].sort((a, b) => b.stats.power - a.stats.power)[0];
const veloce = [...ATHLETES].sort((a, b) => b.stats.speed - a.stats.speed)[0];
const lento = [...ATHLETES].sort((a, b) => a.stats.speed - b.stats.speed)[0];

const partita = (lineup) => createMatchState(
  "quick", byId("maestro"), ARENAS[0], AI_OPPONENTS[1], 0, lineup ? { lineup } : {},
);

// --- il compagno non e' piu' un clone ---------------------------------------

const senzaScelta = partita(null);
const conControllo = partita({ playerMate: controllo });
const conPotenza = partita({ playerMate: potenza });

assert.equal(senzaScelta.playerMate.w, senzaScelta.player.w,
  "Senza scelta il compagno resta il clone di prima: e' il comportamento su cui poggiano gli altri audit");
assert.notEqual(conControllo.playerMate.w, conPotenza.playerMate.w,
  "La racchetta del compagno deve dipendere dall'atleta scelto, non da quello del giocatore");
assert.ok(conControllo.playerMate.w > conPotenza.playerMate.w,
  `Piu' controllo deve valere piu' racchetta: ${conControllo.playerMate.w} vs ${conPotenza.playerMate.w}`);

const veloceInCoppia = partita({ playerMate: veloce });
const lentoInCoppia = partita({ playerMate: lento });
assert.ok(veloceInCoppia.playerMate.speed > lentoInCoppia.playerMate.speed,
  "La velocita' del compagno deve venire dal compagno");

// --- gli avversari smettono di essere solo un aspetto ------------------------

const rivaleVeloce = partita({ opponent: veloce });
const rivaleLento = partita({ opponent: lento });
assert.ok(rivaleVeloce.opponent.speed > rivaleLento.opponent.speed,
  `L'avversario scelto deve muoversi come l'atleta scelto: ${rivaleVeloce.opponent.speed} vs ${rivaleLento.opponent.speed}`);

const rivalePotente = partita({ opponent: potenza });
const rivaleTecnico = partita({ opponent: controllo });
assert.ok(rivalePotente.opponent.reach !== rivaleTecnico.opponent.reach
  || rivalePotente.opponent.w !== rivaleTecnico.opponent.w,
  "Allungo e racchetta dell'avversario devono dipendere dall'atleta");

// La potenza si misura sulla palla, non sui campi della racchetta. Il colpo
// passa pero' dal modello d'errore, che e' casuale: su un singolo tiro
// l'atleta potente puo' benissimo risultare il piu' lento. Si fissa quindi il
// seme e si media su molti tiri, altrimenti questo audit misura il rumore.
function velocitaColpo(atleta, tiri = 240) {
  let somma = 0;
  for (let seme = 1; seme <= tiri; seme += 1) {
    const state = partita({ opponent: atleta });
    state.rngState = seme * 7919;
    Object.assign(state, { running: true, serving: false, pointPause: 0, lastHitterSide: "player", rallyHits: 3 });
    Object.assign(state.opponent, { x: 480, y: 145, hitCooldown: 0 });
    Object.assign(state.ball, { x: 480, y: 165, z: 60, vx: 0, vy: -100, vz: 0, crossedNet: true });
    hitBall(state, state.opponent, 1, false, true, 0, false, "drive", 0);
    somma += Math.hypot(state.ball.vx, state.ball.vy);
  }
  return somma / tiri;
}
const colpoPotente = velocitaColpo(potenza);
const colpoTecnico = velocitaColpo(controllo);
// Lo scarto va preteso esplicito. Alla prima stesura questo confronto passava
// con 333,4 contro 333,4: la potenza dell'IA non e' un moltiplicatore sulla
// palla ma il tempo di volo, e senza toccarlo l'avversario scelto cambiava
// racchetta senza cambiare il peso dei colpi. Un `>` da solo non lo vedeva.
const scartoColpo = (colpoPotente - colpoTecnico) / colpoTecnico;
assert.ok(scartoColpo > 0.15,
  `L'avversario potente deve tirare percettibilmente piu' forte: ${colpoPotente.toFixed(1)} vs ${colpoTecnico.toFixed(1)} (${(scartoColpo * 100).toFixed(1)}%)`);

// --- la promessa: scegliere non e' cambiare difficolta' ----------------------

// Le statistiche entrano come rapporto sulla media del roster, quindi la media
// delle formazioni possibili deve ricadere esattamente sul comportamento di
// prima. Se un giorno il roster cresce sbilanciato, e' questo assert a cadere.
const riferimento = partita(null);
const medie = { speed: 0, w: 0, reach: 0 };
for (const atleta of ATHLETES) {
  const state = partita({ opponent: atleta });
  medie.speed += state.opponent.speed / ATHLETES.length;
  medie.w += state.opponent.w / ATHLETES.length;
  medie.reach += state.opponent.reach / ATHLETES.length;
}
for (const [chiave, valore] of Object.entries(medie)) {
  const scarto = Math.abs(valore - riferimento.opponent[chiave]) / riferimento.opponent[chiave];
  assert.ok(scarto < 0.005,
    `Sulla media del roster l'avversario deve valere quanto prima (${chiave}): scarto ${(scarto * 100).toFixed(2)}%`);
}

// Nessuna statistica media deve essere zero o assurda: la normalizzazione ci
// divide, e un roster con una media nulla darebbe moltiplicatori infiniti.
for (const [chiave, valore] of Object.entries(ROSTER_AVERAGE)) {
  assert.ok(valore > 0.3 && valore < 3, `Media del roster fuori scala su ${chiave}: ${valore}`);
}

// --- la resistenza e' di squadra --------------------------------------------

// `rallyEnergy` si consuma per meta' campo, quindi la resistenza che conta e' la
// media dei due, non quella di chi tira. Si misura sull'energia residua dopo un
// numero fisso di colpi.
function energiaDopoScambio(lineup) {
  const state = partita(lineup);
  state.rngState = 424242;
  Object.assign(state, { running: true, serving: false, pointPause: 0, lastHitterSide: "ai", rallyHits: 3 });
  // Quattro colpi: oltre i sei l'energia tocca `rallyEnergyFloor` e le due
  // formazioni finiscono sullo stesso valore, che farebbe passare l'audit per
  // saturazione invece che per merito.
  for (let colpo = 0; colpo < 4; colpo += 1) {
    Object.assign(state.player, { x: 480, y: 395, hitCooldown: 0 });
    Object.assign(state.ball, { x: 480, y: 375, z: 60, vx: 0, vy: 100, vz: 0, crossedNet: true });
    hitBall(state, state.player, 1.3, false, true, 0, false, "drive", 0);
  }
  return state.rallyEnergy.player;
}
const resistente = [...ATHLETES].sort((a, b) => b.stats.stamina - a.stats.stamina)[0];
const fragile = [...ATHLETES].sort((a, b) => a.stats.stamina - b.stats.stamina)[0];
const conResistente = energiaDopoScambio({ playerMate: resistente });
const conFragile = energiaDopoScambio({ playerMate: fragile });
assert.ok(conResistente > conFragile,
  `Un compagno piu' resistente deve lasciare piu' energia alla squadra: ${conResistente.toFixed(3)} vs ${conFragile.toFixed(3)}`);

console.log(JSON.stringify({
  rosterAverage: Object.fromEntries(Object.entries(ROSTER_AVERAGE).map(([k, v]) => [k, Number(v.toFixed(3))])),
  compagnoRacchetta: { controllo: Number(conControllo.playerMate.w.toFixed(2)), potenza: Number(conPotenza.playerMate.w.toFixed(2)) },
  avversarioVelocita: { veloce: Number(rivaleVeloce.opponent.speed.toFixed(1)), lento: Number(rivaleLento.opponent.speed.toFixed(1)), riferimento: Number(riferimento.opponent.speed.toFixed(1)) },
  avversarioColpo: { potente: Number(colpoPotente.toFixed(1)), tecnico: Number(colpoTecnico.toFixed(1)) },
  energiaSquadra: { resistente: Number(conResistente.toFixed(3)), fragile: Number(conFragile.toFixed(3)) },
}, null, 2));
