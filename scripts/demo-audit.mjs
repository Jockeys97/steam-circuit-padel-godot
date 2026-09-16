import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { ATHLETES, ARENAS, ATHLETE_OUTFITS, BALANCE } from "../js/data.js?v=20260910-sprite-gate-v41";
import { DEMO_CONTENT, demoFilter, demoLocked, IS_DEMO } from "../js/build.js?v=20260910-sprite-gate-v41";

// `demoFilter` guarda IS_DEMO, che fuori dal browser e' false. Qui si verifica
// il contenuto dichiarato, non il rilevamento: quello dipende dal contesto.
const byId = (list, ids) => list.filter((item) => ids.includes(item.id));

const demoAthletes = byId(ATHLETES, DEMO_CONTENT.athletes);
const demoArenas = byId(ARENAS, DEMO_CONTENT.arenas);

assert.equal(demoAthletes.length, DEMO_CONTENT.athletes.length,
  "Ogni atleta dichiarato dalla demo deve esistere davvero");
assert.equal(demoArenas.length, DEMO_CONTENT.arenas.length,
  "Ogni arena dichiarata dalla demo deve esistere davvero");

// Nessun contenuto sbloccabile nella demo: chiederebbe una progressione che la
// demo non ha, quindi resterebbe inaccessibile e sembrerebbe rotto.
for (const item of [...demoAthletes, ...demoArenas]) {
  assert.ok(!item.unlock,
    `La demo non puo' proporre contenuti sbloccabili: ${item.id}`);
}

// I due atleti devono essere agli estremi opposti, altrimenti chi prova la demo
// non capisce che gli atleti giocano davvero diversi.
const [uno, due] = demoAthletes;
const scartoControllo = Math.abs(uno.stats.control - due.stats.control);
const scartoPotenza = Math.abs(uno.stats.power - due.stats.power);
assert.ok(scartoControllo >= 0.25 && scartoPotenza >= 0.25,
  `I due atleti della demo devono essere contrapposti: controllo ${scartoControllo.toFixed(2)}, potenza ${scartoPotenza.toFixed(2)}`);

// La demo taglia la progressione, non il gioco: il repertorio resta intero.
const colpiRichiesti = [
  "smashMinHeight", "smashX2MinQuality", "smashX3MinQuality",
  "cutVolleyMinQuality", "globoMinQuality", "tightAngleReachGain",
  "viboraNetWindow",
];
for (const chiave of colpiRichiesti) {
  assert.ok(BALANCE[chiave] !== undefined,
    `La demo deve mantenere tutti i colpi: manca ${chiave}`);
}

assert.deepEqual(DEMO_CONTENT.modes, ["quick"],
  "La demo espone solo la Partita Rapida: torneo e carriera sono la progressione che si compra");
assert.equal(DEMO_CONTENT.difficulty, "medium",
  "La demo gira sulla difficolta' media: il facile sembra banale, il difficile respinge");

const filtrati = demoFilter(ATHLETES, DEMO_CONTENT.athletes);
assert.ok(filtrati.length === ATHLETES.length || filtrati.length === demoAthletes.length,
  "demoFilter deve lasciare tutto nel gioco completo o solo il consentito nella demo");

// --- si mostra, non si nasconde -------------------------------------------
//
// `demoLocked` e' la controparte di `demoFilter`: dice che un contenuto esiste
// ma la demo non lo concede, cosi' l'interfaccia lo puo' mostrare bloccato.
// Prima atleti e arene fuori demo sparivano, e la demo si contraddiceva: la
// schermata Obiettivi elencava sei atleti e nove arene, la partita ne schierava
// in campo di non selezionabili, e la griglia di scelta ne mostrava due e una.
const fuoriDemo = (item, allowed) => !allowed.includes(item.id);

const atletiEsclusi = ATHLETES.filter((a) => fuoriDemo(a, DEMO_CONTENT.athletes));
const areneEscluse = ARENAS.filter((a) => fuoriDemo(a, DEMO_CONTENT.arenas));

assert.ok(atletiEsclusi.length > 0 && areneEscluse.length > 0,
  "Se la demo contenesse tutto non ci sarebbe niente da vendere");

// `demoLocked` risponde sul contenuto, non sulla build: fuori dalla demo deve
// tacere, altrimenti bloccherebbe il gioco completo.
for (const atleta of atletiEsclusi) {
  assert.equal(demoLocked(atleta, DEMO_CONTENT.athletes), IS_DEMO,
    `demoLocked deve valere solo dentro la demo: ${atleta.id}`);
}
for (const atleta of byId(ATHLETES, DEMO_CONTENT.athletes)) {
  assert.equal(demoLocked(atleta, DEMO_CONTENT.athletes), false,
    `Un atleta della demo non puo' risultare bloccato: ${atleta.id}`);
}

// I completi sono l'unica cosa che la demo lascia conquistare davvero, perche'
// le loro sfide si vincono in partita rapida. E' il suo unico gancio a lungo
// termine: se un giorno le sfide tornassero legate alla progressione, la demo
// resterebbe senza niente da inseguire e questo assert lo direbbe.
assert.equal(DEMO_CONTENT.outfitChallenges, true,
  "La demo deve dichiarare che le sfide dei completi valgono anche qui");
let sfideDemo = 0;
for (const id of DEMO_CONTENT.athletes) {
  sfideDemo += (ATHLETE_OUTFITS[id] ?? []).filter((o) => o.challenge).length;
}
assert.ok(sfideDemo >= 6,
  `Gli atleti della demo devono avere completi da vincere: ${sfideDemo}`);

console.log(JSON.stringify({
  athletes: demoAthletes.map((a) => a.id),
  arenas: demoArenas.map((a) => a.id),
  modes: DEMO_CONTENT.modes,
  difficulty: DEMO_CONTENT.difficulty,
  shotsKept: colpiRichiesti.length,
  fullGameAthletes: ATHLETES.length,
  fullGameArenas: ARENAS.length,
  mostratiBloccati: atletiEsclusi.length + areneEscluse.length,
  sfideCompletiInDemo: sfideDemo,
}, null, 2));

// ── Il richiamo a seguire il gioco non deve dipendere dal tipo di build ────
// Stava dentro `if (IS_DEMO)`: la demo lo mostrava, la versione completa no.
// Pubblicando la completa come beta — che e' cio' che serve per avere feedback su
// Carriera, Torneo e sulle difficolta' alte, che la demo blocca — il funnel verso
// Steam non esisteva. Ora lo accende l'esistenza di una destinazione.
{
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const main = readFileSync(new URL("../js/main.js", import.meta.url), "utf8");
  const { STORE } = await import("../js/data.js?v=20260910-sprite-gate-v41");

  assert("url" in STORE, "STORE deve dichiarare la destinazione del richiamo");
  const blocco = main.match(/function applyStoreCta[\s\S]*?\n}/)?.[0];
  assert(blocco, "applyStoreCta non trovata");
  assert(
    /if \(!STORE\.url\)/.test(blocco),
    "Senza destinazione il richiamo deve restare nascosto: un pulsante verso la "
    + "homepage di Steam sembra rotto e chi lo preme non torna",
  );
  assert(
    !/if \(IS_DEMO\) \{\s*const cta/.test(main),
    "Il richiamo non deve piu' essere acceso dal tipo di build",
  );
  // Due paragrafi con la propria chiave: "questa e' una demo" in una beta sarebbe
  // falso, e riscrivere un solo testo a mano ricreerebbe il conflitto con
  // `applyLanguage` su chi possiede la stringa.
  assert(/id="ctaBodyDemo"/.test(html) && /id="ctaBodyBeta"/.test(html),
    "Servono i due testi, uno per la demo e uno per la beta");
  // E il campo duplicato non deve tornare.
  const build = readFileSync(new URL("../js/build.js", import.meta.url), "utf8");
  assert(
    !/wishlistUrl/.test(build),
    "La destinazione vive solo in STORE: due campi per la stessa cosa finiscono in disaccordo",
  );
}

// ── La beta esiste per raccogliere cio' che la demo non puo' dire ──────────
// La demo blocca la difficolta' su Medio e concede una sola arena: pubblicandola
// non arriverebbe una parola su Difficile e Leggenda, ne' sulla difesa dello smash
// al variare del vetro — cioe' esattamente il lavoro su cui serve feedback.
{
  const modulo = readFileSync(new URL("../js/build.js", import.meta.url), "utf8");
  assert(/beta:\s*{/.test(modulo), "Manca il tipo di build `beta`");

  // Si forza la build come fa il pacchetto caricato su itch.
  globalThis.__PADEL_BUILD = "beta";
  const beta = await import("../js/build.js?v=sonda-beta");
  assert.equal(beta.BUILD, "beta", "La build forzata deve risultare `beta`");
  assert(beta.IS_DEMO, "La beta e' una build limitata: filtri e blocchi devono valere");

  assert.equal(
    beta.DEMO_CONTENT.difficulty,
    null,
    "La beta deve lasciare tutte le difficolta': e' la ragione per cui esiste",
  );

  const vetri = beta.DEMO_CONTENT.arenas
    .map((id) => ARENAS.find((a) => a.id === id)?.wallBounce)
    .filter((x) => typeof x === "number");
  assert.equal(vetri.length, beta.DEMO_CONTENT.arenas.length, "Un'arena della beta non esiste in ARENAS");
  assert(vetri.length >= 2, `La beta ha ${vetri.length} arena/e: servono almeno due vetri diversi`);
  assert(
    Math.max(...vetri) - Math.min(...vetri) >= 0.04,
    `Vetri troppo simili (${vetri.join(", ")}): il feedback sullo x3 non distinguerebbe niente`,
  );
  beta.DEMO_CONTENT.arenas.forEach((id) => {
    assert(!ARENAS.find((a) => a.id === id)?.unlock, `L'arena ${id} e' bloccata: non si potrebbe giocare`);
  });

  // Carriera e Torneo restano fuori: sono cio' che vale la versione completa.
  assert.deepEqual(beta.DEMO_CONTENT.modes, ["quick"], "La beta non deve concedere Carriera e Torneo");

  delete globalThis.__PADEL_BUILD;
  console.log(JSON.stringify({
    beta: { arene: beta.DEMO_CONTENT.arenas, vetri, difficolta: "tutte", modalita: beta.DEMO_CONTENT.modes },
  }, null, 2));
}
