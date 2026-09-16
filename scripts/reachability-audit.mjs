import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";

/**
 * Ogni schermata deve avere una porta, e ogni porta deve portare da qualche parte.
 *
 * E' il difetto che non fa rumore: nessun errore, nessun test rosso, solo una
 * parte del gioco che esiste e che nessuno puo' aprire. La modalita' Allenamento
 * e' stata cosi' per tutto lo sviluppo — schermata completa, HUD con punti,
 * record, precisione e streak, un modulo `drill.js` di 159 righe e le sue
 * traduzioni — e l'unico modo per accorgersene era contare a mano i
 * `data-action` del markup.
 *
 * Tre controlli:
 *   1. ogni `data-action` nel markup ha un gestore;
 *   2. ogni gestore e' raggiungibile, dal markup o da codice;
 *   3. ogni `<section id="screen-X">` viene aperta da almeno un `showScreen`.
 */

const root = new URL("../", import.meta.url);
const html = await readFile(new URL("index.html", root), "utf8");
const main = await readFile(new URL("js/main.js", root), "utf8");
const ui = await readFile(new URL("js/ui.js", root), "utf8");

// --- 1 e 2: azioni e gestori ------------------------------------------------

const azioni = new Set([...html.matchAll(/data-action="([A-Za-z-]+)"/g)].map((m) => m[1]));
assert.ok(azioni.size > 5, `Attese piu' azioni nel markup, trovate ${azioni.size}`);

const blocco = main.match(/bindNavigation\(\{(.*?)\n\}\);/s);
assert.ok(blocco, "bindNavigation non trovato in main.js");
// Le chiavi possono essere `nome:`, `"con-trattino":` oppure la forma breve
// `nome,` — quest'ultima e' quella che un'analisi ingenua si perde.
const gestori = new Set([
  ...[...blocco[1].matchAll(/\n {2}"?([A-Za-z][A-Za-z0-9-]*)"?\s*:/g)].map((m) => m[1]),
  ...[...blocco[1].matchAll(/\n {2}([A-Za-z][A-Za-z0-9]*),/g)].map((m) => m[1]),
]);

const senzaGestore = [...azioni].filter((a) => !gestori.has(a));
assert.deepEqual(senzaGestore, [],
  `Pulsanti nel markup che non fanno niente: ${senzaGestore.join(", ")}`);

// Un gestore puo' essere invocato da codice invece che da un pulsante — e' il
// caso di `selectMode`, che parte dal clic su una card di modalita'.
const daCodice = new Set([...`${ui}${main}`.matchAll(/handlers\.([A-Za-z][A-Za-z0-9]*)\??\.?\(/g)].map((m) => m[1]));
const irraggiungibili = [...gestori].filter((g) => !azioni.has(g) && !daCodice.has(g));
assert.deepEqual(irraggiungibili, [],
  `Gestori che nessuno puo' invocare: ${irraggiungibili.join(", ")}`);

// I `data-action` non stanno solo in index.html: alcuni pulsanti nascono da
// template dentro il codice — il riepilogo del Profilo, la barra del feedback.
// Da quando la navigazione usa la delega quelli funzionano senza registrazione,
// ma un nome sbagliato resta muto esattamente come prima. Qui si pretende che
// ogni azione citata da un template corrisponda a un gestore.
const sorgentiJs = (await readdir(new URL("js/", root)))
  .filter((f) => f.endsWith(".js"));
const azioniDinamiche = new Set();
for (const file of sorgentiJs) {
  const testo = await readFile(new URL(`js/${file}`, root), "utf8");
  for (const m of testo.matchAll(/data-action="([A-Za-z-]+)"/g)) azioniDinamiche.add(m[1]);
}
const dinamicheOrfane = [...azioniDinamiche].filter((a) => !gestori.has(a));
assert.deepEqual(dinamicheOrfane, [],
  `Pulsanti generati dal codice che non fanno niente: ${dinamicheOrfane.join(", ")}`);

// --- 3: schermate senza porta ----------------------------------------------

const schermate = [...html.matchAll(/id="screen-([a-z-]+)"/g)].map((m) => m[1]);
assert.ok(schermate.length >= 8, `Attese almeno otto schermate, trovate ${schermate.length}`);

const aperte = new Set([...`${main}${ui}`.matchAll(/showScreen\("([a-z-]+)"\)/g)].map((m) => m[1]));
const orfane = schermate.filter((s) => !aperte.has(s));
assert.deepEqual(orfane, [],
  `Schermate che il gioco non apre mai: ${orfane.join(", ")}`);

// E il contrario: aprire una schermata che non esiste lascia il giocatore su
// una pagina vuota, perche' `showScreen` non protesta se l'id non c'e'.
const inesistenti = [...aperte].filter((a) => !schermate.includes(a));
assert.deepEqual(inesistenti, [],
  `Il codice apre schermate che non esistono nel markup: ${inesistenti.join(", ")}`);

// Il registro `screens` e' l'anello fra i due: `showScreen` spegne tutte le
// schermate che conosce e accende quella richiesta, quindi una chiave mancante
// non da' errore — lascia semplicemente la pagina vuota. E' successo con la
// schermata Obiettivi: markup a posto, gestore a posto, `showScreen("challenges")`
// chiamato, e cliccando non appariva niente. I due controlli qui sopra non lo
// vedevano, perche' guardavano gli estremi e non l'anello in mezzo.
const registro = ui.match(/const screens = \{(.*?)\n\};/s);
assert.ok(registro, "Registro `screens` non trovato in ui.js");
const registrate = new Set([...registro[1].matchAll(/\n {2}([A-Za-z][A-Za-z0-9]*):/g)].map((m) => m[1]));

const nonRegistrate = schermate.filter((s) => !registrate.has(s));
assert.deepEqual(nonRegistrate, [],
  `Schermate nel markup ma assenti dal registro: cliccarle lascia la pagina vuota (${nonRegistrate.join(", ")})`);

const registrateInutili = [...registrate].filter((r) => !schermate.includes(r));
assert.deepEqual(registrateInutili, [],
  `Il registro elenca schermate che non esistono: ${registrateInutili.join(", ")}`);

console.log(JSON.stringify({
  azioni: azioni.size,
  gestori: gestori.size,
  schermate: schermate.length,
}, null, 2));
