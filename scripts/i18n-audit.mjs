import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";

import { ATHLETES, ARENAS, AI_OPPONENTS, ATHLETE_OUTFITS, OBJECTIVE_DEFS } from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * Le due lingue devono dire le stesse cose.
 *
 * `t()` ricade sull'italiano quando una chiave manca nella lingua attiva, il che
 * e' la scelta giusta — meglio una frase nella lingua sbagliata che il nome
 * grezzo di una chiave — ma rende il buco invisibile: niente errore, niente
 * console, solo un giocatore inglese che trova due frasi in italiano. E'
 * successo con `helpIntro` e `historySub`, rimaste solo in italiano per tutto lo
 * sviluppo.
 *
 * Verifica anche il verso opposto: una chiave usata e mai definita esce a video
 * come chiave, e una definita e mai usata e' peso morto da tradurre due volte.
 */

const root = new URL("../", import.meta.url);
const i18n = await readFile(new URL("js/i18n.js", root), "utf8");

const chiavi = {};
for (const lingua of ["it", "en"]) {
  const blocco = i18n.match(new RegExp(`\\n {2}${lingua}: \\{(.*?)\\n {2}\\},?\\n`, "s"));
  assert.ok(blocco, `Blocco della lingua ${lingua} non trovato`);
  chiavi[lingua] = new Set([...blocco[1].matchAll(/\n {4}([A-Za-z_][A-Za-z0-9_]*):/g)].map((m) => m[1]));
}
assert.ok(chiavi.it.size > 200, `Attese piu' di 200 chiavi, trovate ${chiavi.it.size}`);

const soloIt = [...chiavi.it].filter((k) => !chiavi.en.has(k));
const soloEn = [...chiavi.en].filter((k) => !chiavi.it.has(k));
assert.deepEqual(soloIt, [], `Chiavi presenti solo in italiano: ${soloIt.join(", ")}`);
assert.deepEqual(soloEn, [], `Chiavi presenti solo in inglese: ${soloEn.join(", ")}`);

// I segnaposto devono coincidere: una traduzione che perde `{n}` stampa una
// frase monca, una che ne inventa uno lascia le graffe a video.
for (const chiave of chiavi.it) {
  const prendi = (lingua) => {
    const blocco = i18n.match(new RegExp(`\\n {2}${lingua}: \\{(.*?)\\n {2}\\},?\\n`, "s"))[1];
    const riga = blocco.match(new RegExp(`\\n {4}${chiave}: "([^"]*)"`));
    return riga ? new Set([...riga[1].matchAll(/\{(\w+)\}/g)].map((m) => m[1])) : null;
  };
  const a = prendi("it");
  const b = prendi("en");
  if (!a || !b) continue;
  assert.deepEqual([...a].sort(), [...b].sort(),
    `${chiave}: le due lingue usano segnaposto diversi`);
}

// Chiavi citate dal codice o dal markup ma mai definite: escono a video cosi'
// come sono. Quelle composte a runtime (`athlete_${id}_name`) restano fuori.
const sorgenti = [
  "index.html",
  ...(await readdir(new URL("js/", root))).filter((f) => f.endsWith(".js")).map((f) => `js/${f}`),
];
let testo = "";
for (const file of sorgenti) testo += await readFile(new URL(file, root), "utf8");

const PREFISSI_DINAMICI = ["athlete_", "arena_", "ai_", "outfit", "objective", "metric_", "obj"];
const usate = new Set([
  ...[...testo.matchAll(/\bt\("([A-Za-z_][A-Za-z0-9_]*)"/g)].map((m) => m[1]),
  ...[...testo.matchAll(/data-i18n(?:-aria)?="([A-Za-z_][A-Za-z0-9_]*)"/g)].map((m) => m[1]),
]);
const mancanti = [...usate].filter((k) => !chiavi.it.has(k) && !PREFISSI_DINAMICI.some((p) => k.startsWith(p)));
assert.deepEqual(mancanti, [], `Chiavi usate ma mai definite: ${mancanti.join(", ")}`);

// Le chiavi composte a runtime — `ai_${id}_name`, `athlete_${id}_desc` — erano
// escluse dal controllo qui sopra, perche' cercarle nel testo non ha senso: nel
// codice non compaiono mai per intero. Ma sono proprio quelle che nessuno
// controlla a occhio, e infatti `ai_leggenda_name` e' mancata per giorni: la
// Leggenda si presentava a schermo come "AI_LEGGENDA_NAME" durante la partita.
//
// La soluzione non e' escluderle, e' generarle: gli identificativi stanno nei
// dati, quindi le chiavi attese si costruiscono e si verificano tutte.
const attese = [];
for (const atleta of ATHLETES) {
  for (const suffisso of ["name", "role", "desc", "special"]) attese.push(`athlete_${atleta.id}_${suffisso}`);
}
for (const arena of ARENAS) {
  for (const suffisso of ["name", "desc"]) attese.push(`arena_${arena.id}_${suffisso}`);
}
for (const avversario of AI_OPPONENTS) attese.push(`ai_${avversario.id}_name`);
for (const lista of Object.values(ATHLETE_OUTFITS)) {
  for (const completo of lista) if (completo.nameKey) attese.push(completo.nameKey);
}
for (const id of Object.keys(OBJECTIVE_DEFS)) attese.push(`obj_${id}`);

const composteMancanti = attese.filter((k) => !chiavi.it.has(k));
assert.deepEqual(composteMancanti, [],
  `Chiavi composte a runtime e mai definite — escono a schermo cosi' come sono: ${composteMancanti.join(", ")}`);

console.log(JSON.stringify({
  chiavi: chiavi.it.size,
  usateEsplicitamente: usate.size,
  composteVerificate: attese.length,
  lingue: 2,
}, null, 2));
