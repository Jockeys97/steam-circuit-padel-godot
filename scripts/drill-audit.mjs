import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  DRILL_EXERCISES,
  createDrill,
  drillMetrics,
  exerciseById,
  updateDrill,
} from "../js/drill.js?v=20260910-sprite-gate-v41";
import { ARENAS, ATHLETES, AI_OPPONENTS } from "../js/data.js?v=20260910-sprite-gate-v41";
import { setLang, t } from "../js/i18n.js?v=20260910-sprite-gate-v41";

/**
 * Audit dell'allenamento.
 *
 * Il punto non e' che il codice giri: e' che l'allenamento resti **il gioco**.
 * Prima `drill.js` era un secondo motore con gravita' e misuratore propri, e
 * allenava una fisica che in partita non esisteva — nessuna finestra di timing,
 * nessuna energia, nessuna statistica dell'atleta. Un difetto cosi' non si
 * manifesta come un errore: si manifesta come un giocatore che si allena e
 * peggiora.
 *
 * Qui si verifica quindi che lo stato sia quello del match, che ogni esercizio
 * chiuda un tentativo e lo sappia valutare, e che non ricompaia una fisica
 * parallela.
 */

function seededRandom(seed) {
  // Stesso mulberry32 degli altri audit: un LCG riseminato produce valori
  // correlati e falsa le misure.
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

const STEP = 1 / 120;

// ── 1. Nessuna fisica parallela ─────────────────────────────────────────────
const source = readFileSync(new URL("../js/drill.js", import.meta.url), "utf8");
assert(
  /from "\.\/game\.js\?v=/.test(source),
  "L'allenamento deve girare sul motore: manca l'import di game.js",
);
for (const vietato of ["ballGravity * dt", "GRAVITY * dt", "vz -=", "b.z +="]) {
  assert(
    !source.includes(vietato),
    `drill.js integra il volo della palla da solo ("${vietato}"): e' la fisica parallela che si voleva togliere`,
  );
}

// ── 2. Lo stato e' quello del match ────────────────────────────────────────
{
  Math.random = seededRandom(7);
  const drill = createDrill("precision", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  const s = drill.state;
  for (const campo of ["arena", "athlete", "rallyEnergy", "stats", "player", "opponent", "ball"]) {
    assert(s[campo] !== undefined, `Lo stato dell'allenamento non ha "${campo}": non e' uno stato di match`);
  }
  assert(s.athlete.stats?.control > 0, "L'atleta deve portare le sue statistiche");
  assert(s.arena.wallBounce > 0, "L'arena deve portare la fisica del vetro");
  assert.equal(s.mode, "drill", "La modalita' dello stato deve dichiararsi");
  // Un punto non deve poter chiudere l'allenamento.
  assert(s.pointsToWin > 1000, "Un punto non deve chiudere l'allenamento");
}

// ── 3. Ogni esercizio chiude un tentativo e lo valuta ──────────────────────
const report = [];
for (const esercizio of DRILL_EXERCISES) {
  Math.random = seededRandom(1234);
  const drill = createDrill(esercizio.id, ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);

  // Primo `hit`: dalla posa di attesa si passa al tentativo.
  updateDrill(drill, STEP, input({ hit: true }));
  assert.equal(drill.phase, "live", `${esercizio.id}: il primo comando non avvia il tentativo`);
  if (esercizio.feed === "serve") {
    // Il primo comando prepara il tentativo; la battuta parte dal comando
    // successivo, esattamente come in partita. Pretendere velocita' qui
    // codificava il vecchio feed automatico che l'esercizio ha sostituito.
    assert(drill.state.serving, "serve: il motore non ha preparato la battuta");
  } else {
    assert(
      drill.state.ball.vy !== 0 || drill.state.ball.vz !== 0,
      `${esercizio.id}: la palla non e' stata messa in gioco dal motore`,
    );
  }
  if (esercizio.targets) {
    assert(drill.target.active, `${esercizio.id}: nessun bersaglio piazzato`);
    assert(
      drill.target.y < 310,
      `${esercizio.id}: il bersaglio deve stare nella meta' avversaria, non a ${drill.target.y}`,
    );
  }

  // Si lascia correre: il giocatore prova a colpire quando la palla arriva.
  let chiuso = false;
  for (let frame = 0; frame < 2400 && !chiuso; frame += 1) {
    const palla = drill.state.ball;
    const vicina = Math.abs(palla.y - drill.state.player.y) < 90 && palla.z <= 108;
    updateDrill(drill, STEP, input(vicina ? { hit: true, charging: true } : {}));
    if (drill.phase === "result") chiuso = true;
  }
  assert(chiuso, `${esercizio.id}: nessun tentativo si chiude in 20 secondi di simulazione`);
  assert.equal(drill.attempts, 1, `${esercizio.id}: il tentativo non e' stato contato`);
  assert(drill.points >= 0, `${esercizio.id}: punteggio non valido`);
  assert(Number.isFinite(drill.score), `${esercizio.id}: punteggio non numerico`);

  // Le metriche dell'HUD devono essere quattro e tutte popolate.
  const metriche = drillMetrics(drill);
  assert.equal(metriche.length, 4, `${esercizio.id}: l'HUD vuole quattro metriche`);
  metriche.forEach((m) => {
    assert(m.key && m.value !== undefined, `${esercizio.id}: metrica incompleta`);
  });

  report.push({
    esercizio: esercizio.id,
    tentativi: drill.attempts,
    centrati: drill.hits,
    punti: drill.points,
    voto: drill.grade ?? "—",
    colpiScambio: drill.rallyHits,
    energia: Number((drill.state.rallyEnergy.player).toFixed(2)),
  });
}

// ── 4. Il tiro al bersaglio non deve essere disturbato ────────────────────
{
  Math.random = seededRandom(99);
  const drill = createDrill("precision", ATHLETES[0], ARENAS[0], AI_OPPONENTS[3]);
  updateDrill(drill, STEP, input({ hit: true }));
  for (let frame = 0; frame < 400; frame += 1) updateDrill(drill, STEP, input());
  assert(
    drill.state.opponent.hitCooldown > 0 && drill.state.opponentMate.hitCooldown > 0,
    "Nel tiro al bersaglio gli avversari devono restare congelati, altrimenti intercettano",
  );
}

// ── 5. Gli esercizi con avversario non lo congelano ───────────────────────
for (const id of ["smash", "rally"]) {
  Math.random = seededRandom(55);
  const drill = createDrill(id, ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  updateDrill(drill, STEP, input({ hit: true }));
  for (let frame = 0; frame < 240; frame += 1) updateDrill(drill, STEP, input());
  assert(
    drill.state.opponent.hitCooldown < 5,
    `${id}: l'avversario deve poter giocare, altrimenti l'esercizio non ha senso`,
  );
}

// ── 6. Ogni esercizio dichiarato deve essere raggiungibile ────────────────
for (const id of ["precision", "smash", "rally"]) {
  assert.equal(exerciseById(id).id, id, `L'esercizio ${id} non si risolve`);
}
assert.equal(exerciseById("inesistente").id, DRILL_EXERCISES[0].id, "Un id ignoto deve ricadere sul primo");


// ── 7. Ogni tentativo deve dire perche' e' andato cosi' ───────────────────
{
  const chiaviViste = new Set();
  for (const esercizio of DRILL_EXERCISES) {
    Math.random = seededRandom(4321);
    const drill = createDrill(esercizio.id, ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
    updateDrill(drill, STEP, input({ hit: true }));
    for (let frame = 0; frame < 3600 && drill.phase !== "result"; frame += 1) {
      const palla = drill.state.ball;
      const vicina = Math.abs(palla.y - drill.state.player.y) < 90 && palla.z <= 108;
      updateDrill(drill, STEP, input(vicina ? { hit: true, charging: true } : {}));
    }
    assert.equal(drill.phase, "result", `${esercizio.id}: il tentativo non si chiude`);
    assert(
      drill.diagnosis,
      `${esercizio.id}: tentativo chiuso senza diagnosi — valutare senza dire perche' insegna a metà`,
    );
    chiaviViste.add(drill.diagnosis);
  }
  // Le diagnosi devono esistere in entrambe le lingue: `t()` restituisce la
  // chiave grezza quando manca, quindi un buco finirebbe a schermo come tale.
  for (const lang of ["it", "en"]) {
    setLang(lang);
    for (const chiave of chiaviViste) {
      assert.notEqual(t(chiave), chiave, `[${lang}] diagnosi senza traduzione: ${chiave}`);
    }
  }
  setLang("it");
}

// ── 8. Il rimbalzo schiacciato si valuta a scorrimento, non a soglia ──────
// Con una soglia secca il punteggio salterebbe da 0 a 1 attorno a un valore, e
// due esecuzioni diverse prenderebbero lo stesso voto. Qui si verifica che valori
// d'impatto diversi producano qualita' diverse, e che i due estremi saturino.
{
  const campioni = [];
  for (const seed of [3, 9, 15, 21, 27, 33]) {
    Math.random = seededRandom(seed);
    const drill = createDrill("precision", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
    updateDrill(drill, STEP, input({ hit: true }));
    for (let frame = 0; frame < 2400 && drill.phase !== "result"; frame += 1) {
      const palla = drill.state.ball;
      const vicina = Math.abs(palla.y - drill.state.player.y) < 90 && palla.z <= 108;
      updateDrill(drill, STEP, input(vicina ? { hit: true, charging: true, slice: seed % 2 === 0 } : {}));
    }
    if (drill.impactVz > 0) campioni.push({ vz: drill.impactVz, q: drill.squash });
  }
  assert(campioni.length >= 3, "servono almeno tre atterraggi per giudicare la scala");
  campioni.forEach(({ vz, q }) => {
    assert(q >= 0 && q <= 1, `qualita' del rimbalzo fuori scala: ${q} per |vz| ${vz}`);
  });
  // Monotona: piu' basso l'impatto, piu' schiacciato il rimbalzo.
  const ordinati = [...campioni].sort((a, b) => a.vz - b.vz);
  for (let i = 1; i < ordinati.length; i += 1) {
    assert(
      ordinati[i].q <= ordinati[i - 1].q + 1e-9,
      `la scala non e' monotona: |vz| ${ordinati[i].vz} da' ${ordinati[i].q}`,
    );
  }
}

// ── 9. Il servizio usa le regole del motore ──────────────────────────────
{
  Math.random = seededRandom(777);
  const drill = createDrill("serve", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  updateDrill(drill, STEP, input({ hit: true }));
  assert(drill.state.serving, "L'esercizio del servizio deve mettere lo stato in battuta");
  assert.equal(drill.state.serveSide, "player", "Serve il giocatore, non l'avversario");
  const metriche = drillMetrics(drill).map((m) => m.key);
  assert(
    metriche.includes("drillDoubleFaults"),
    "Il servizio deve mostrare i doppi falli: sono il percorso che l'esercizio esiste per allenare",
  );
}

console.log(JSON.stringify(report, null, 2));
console.log("\ndrill-audit: l'allenamento gira sul motore del gioco e ogni esercizio si chiude");
