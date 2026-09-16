import assert from "node:assert/strict";

import { ARENAS, AI_OPPONENTS, tournamentFixture } from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * Il tabellone del torneo.
 *
 * Prima il torneo giocava tutti e tre i turni nella stessa arena: si sceglieva
 * una volta e `rematch` ripartiva senza ripassare dalla selezione. Le arene che
 * costano trofei e stelle non comparivano mai in torneo, e i tre turni erano
 * indistinguibili — lo stesso difetto che il calendario di carriera aveva gia'
 * risolto per conto suo.
 *
 * Qui si verifica che il tabellone viaggi, che salga, e soprattutto che regga
 * quando le arene disponibili sono poche: e' all'inizio della partita che il
 * giocatore ne ha una o due, ed e' li' che una divisione per zero o un indice
 * fuori scala manderebbe tutto a schermo nero.
 */

const TURNI = 3;
const prestigio = (arena) => (arena.unlock?.trophies ?? 0) * 10 + (arena.unlock?.stars ?? 0);

// --- il tabellone viaggia e sale ------------------------------------------

const percorso = [...Array(TURNI).keys()].map((round) => tournamentFixture(round, ARENAS).arena);
assert.equal(new Set(percorso.map((a) => a.id)).size, TURNI,
  `Con ${ARENAS.length} arene i tre turni devono giocarsi in campi diversi: ${percorso.map((a) => a.id).join(", ")}`);

for (let turno = 1; turno < TURNI; turno += 1) {
  assert.ok(prestigio(percorso[turno]) >= prestigio(percorso[turno - 1]),
    `Il turno ${turno + 1} deve giocarsi in un campo almeno prestigioso quanto il precedente`);
}

const finale = percorso[TURNI - 1];
const massimo = Math.max(...ARENAS.map(prestigio));
assert.equal(prestigio(finale), massimo,
  `La finale deve giocarsi nel campo piu' prestigioso disponibile, non in ${finale.id}`);

// --- i casi limite: poche arene, o una sola -------------------------------

for (const quante of [1, 2, 3]) {
  const pool = ARENAS.slice(0, quante);
  const arene = [...Array(TURNI).keys()].map((round) => tournamentFixture(round, pool).arena);
  for (const arena of arene) {
    assert.ok(arena, `Con ${quante} arene disponibili un turno resta senza campo`);
    assert.ok(pool.includes(arena),
      `Con ${quante} arene disponibili il tabellone ne sceglie una non disponibile: ${arena.id}`);
  }
  assert.equal(new Set(arene.map((a) => a.id)).size, Math.min(quante, TURNI),
    `Con ${quante} arene disponibili i turni devono usarne ${Math.min(quante, TURNI)} di distinte`);
}

// Elenco vuoto: non deve rompersi, deve ricadere sul roster completo. E'
// il caso della demo, dove `selectableArenas` puo' filtrare via tutto.
const conVuoto = tournamentFixture(0, []).arena;
assert.ok(conVuoto && ARENAS.includes(conVuoto),
  "Senza arene disponibili il tabellone deve ricadere sull'elenco completo");

// Un turno oltre la finale non deve uscire dall'elenco: `tournamentRound` viene
// incrementato prima di mostrare il risultato, e sull'ultima vittoria arriva a 3.
for (const round of [3, 4, 10]) {
  const arena = tournamentFixture(round, ARENAS).arena;
  assert.ok(arena && ARENAS.includes(arena), `Turno ${round} fuori scala: ${arena?.id}`);
}

// --- l'avversario cresce col turno ----------------------------------------

// Il tabellone detta anche la difficolta': e' `AI_OPPONENTS[round]`, e deve
// esistere un gradino per ciascuno dei tre turni.
assert.ok(AI_OPPONENTS.length >= TURNI,
  `Servono almeno ${TURNI} avversari per i turni del torneo, ce ne sono ${AI_OPPONENTS.length}`);
for (let turno = 1; turno < TURNI; turno += 1) {
  assert.ok(AI_OPPONENTS[turno].skill > AI_OPPONENTS[turno - 1].skill,
    `Il turno ${turno + 1} deve essere piu' duro del precedente`);
}

console.log(JSON.stringify({
  turni: TURNI,
  percorso: percorso.map((a) => a.id),
  finale: finale.id,
  areneTotali: ARENAS.length,
}, null, 2));
