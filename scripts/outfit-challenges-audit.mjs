import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

import {
  ATHLETE_OUTFITS,
  ATHLETES,
  CAREER_POINTS_TO_WIN,
  isUnlocked,
  outfitChallengeMet,
} from "../js/data.js?v=20260910-sprite-gate-v41";

/**
 * Le sfide dei completi. Non verifica che il codice giri: verifica che le sfide
 * si possano *superare*, e che superarle voglia dire qualcosa.
 *
 * I tetti non sono stime. Ogni punto assegnato passa da `scorePoint`: un punto
 * vinto con un colpo vincente accredita `winners` a chi vince, uno smash x2/x3
 * accredita anche `smashWinners`, un errore accredita `errors` a chi perde. Ne
 * segue che in una partita da N punti
 *
 *     winners[p] <= pointsWon[p] <= N     e     errors[p] <= pointsWon[avversario] <= N
 *
 * quindi una sfida che chiede piu' di N di una metrica derivata dai punti non si
 * puo' vincere. E' successo: "12 vincenti" con la carriera che gioca partite da
 * 11 punti era un completo che nessuno avrebbe mai potuto indossare.
 */

const CAP = CAREER_POINTS_TO_WIN;
const DERIVATE_DAI_PUNTI = new Set(["winners", "smashWinners", "errors", "doubleFaults"]);
const completi = Object.entries(ATHLETE_OUTFITS)
  .flatMap(([athleteId, lista]) => lista.map((o) => ({ ...o, athleteId })));
const conSfida = completi.filter((o) => o.challenge);

assert.ok(conSfida.length >= 20, `Attesi almeno venti completi con sfida, trovati ${conSfida.length}`);

// Nessun completo deve restare dietro al vecchio muro di stelle e trofei: quello
// era il sistema che si voleva sostituire, e mescolare i due sarebbe peggio di
// entrambi — il giocatore non saprebbe piu' cosa gli serve.
const aCurrency = completi.filter((o) => o.unlock && o.id !== "base");
assert.deepEqual(aCurrency.map((o) => o.unlockKey), [],
  `Completi ancora dietro a stelle o trofei: ${aCurrency.map((o) => o.unlockKey).join(", ")}`);

// La chiave deve essere unica: "circuit" esiste per ogni atleta, e senza prefisso
// vincere il completo di uno li sbloccherebbe a tutti.
const chiavi = conSfida.map((o) => o.unlockKey);
assert.equal(new Set(chiavi).size, chiavi.length, "Chiavi di sblocco duplicate");

const prove = (challenge) => [challenge, challenge.also].filter(Boolean);

for (const completo of conSfida) {
  for (const prova of prove(completo.challenge)) {
    if (!DERIVATE_DAI_PUNTI.has(prova.metric)) continue;
    if (prova.atMost) {
      // Un tetto pari o superiore al massimo ottenibile non si puo' fallire:
      // e' un completo regalato travestito da sfida.
      assert.ok(prova.target < CAP,
        `${completo.unlockKey}: "al massimo ${prova.target} ${prova.metric}" non si puo' fallire in una partita da ${CAP} punti`);
    } else {
      assert.ok(prova.target <= CAP,
        `${completo.unlockKey}: chiede ${prova.target} ${prova.metric} ma una partita da ${CAP} punti ne concede al massimo ${CAP}`);
    }
  }
}

// Ogni sfida deve essere distinta: due completi con la stessa prova si
// sbloccherebbero insieme, e uno dei due non avrebbe mai avuto una sua sfida.
const firme = conSfida.map((o) => JSON.stringify(o.challenge));
assert.equal(new Set(firme).size, firme.length,
  "Due completi condividono la stessa identica sfida");

// Ogni atleta con quattro completi deve chiedere almeno due cose diverse: quattro
// varianti dello stesso numero sono una barra di progresso, non quattro sfide.
for (const [athleteId, lista] of Object.entries(ATHLETE_OUTFITS)) {
  const sfide = lista.filter((o) => o.challenge);
  if (sfide.length < 3) continue;
  const metriche = new Set(sfide.flatMap((o) => prove(o.challenge).map((p) => p.metric)));
  assert.ok(metriche.size >= 2,
    `${athleteId}: tutte le sfide misurano ${[...metriche][0]}, non c'e' varieta'`);
}

// Dentro un atleta la difficolta' deve crescere. Il peso e' grezzo di proposito:
// serve a intercettare un'inversione, non a misurare il divertimento.
const peso = (challenge) => prove(challenge).reduce((somma, p) => {
  const scala = p.metric === "totalRallyHits" ? 0.1 : p.metric === "longestRally" ? 0.5 : 1;
  return somma + (p.atMost ? (CAP - p.target) * scala : p.target * scala);
}, 0) + (challenge.win ? 3 : 0) + (challenge.minSkill ? challenge.minSkill * 12 : 0);

const ORDINE = ["circuit", "legend", "signature", "mythic"];
for (const [athleteId, lista] of Object.entries(ATHLETE_OUTFITS)) {
  const scala = ORDINE
    .map((id) => lista.find((o) => o.id === id && o.challenge))
    .filter(Boolean);
  for (let i = 1; i < scala.length; i += 1) {
    assert.ok(peso(scala[i].challenge) > peso(scala[i - 1].challenge),
      `${athleteId}: ${scala[i].id} non e' piu' difficile di ${scala[i - 1].id} (${peso(scala[i].challenge).toFixed(1)} vs ${peso(scala[i - 1].challenge).toFixed(1)})`);
  }
}

// Il primo gradino deve essere alla portata di chi apre il gioco: senza vittoria
// richiesta e senza soglia di difficolta', altrimenti non e' un primo gradino.
for (const [athleteId, lista] of Object.entries(ATHLETE_OUTFITS)) {
  const primo = lista.find((o) => o.id === "circuit" && o.challenge);
  if (!primo) continue;
  assert.ok(!primo.challenge.win && !primo.challenge.minSkill,
    `${athleteId}: il primo completo chiede gia' una vittoria o una difficolta' minima`);
}

// --- la macchina che valuta ------------------------------------------------

const statsPiene = {
  pointsWon: { player: 11, ai: 2 }, winners: { player: 10, ai: 0 },
  errors: { player: 0, ai: 0 }, smashWinners: { player: 10, ai: 0 },
  doubleFaults: { player: 0, ai: 0 }, longestRally: 40, totalRallyHits: 300,
};
const statsVuote = {
  pointsWon: { player: 0, ai: 11 }, winners: { player: 0, ai: 0 },
  errors: { player: 11, ai: 0 }, smashWinners: { player: 0, ai: 0 },
  doubleFaults: { player: 6, ai: 0 }, longestRally: 1, totalRallyHits: 12,
};

for (const completo of conSfida) {
  assert.ok(
    outfitChallengeMet(completo.challenge, { stats: statsPiene, won: true, skill: 0.95, athleteWins: 99 }),
    `${completo.unlockKey}: nemmeno una partita perfetta contro la Leggenda la supera`,
  );
  assert.ok(
    !outfitChallengeMet(completo.challenge, { stats: statsVuote, won: false, skill: 0.46, athleteWins: 0 }),
    `${completo.unlockKey}: la supera anche una partita persa senza fare niente`,
  );
}

// `isUnlocked` deve guardare la sfida vinta, non piu' il portafoglio.
const esempio = conSfida[0];
assert.ok(!isUnlocked(esempio, { trophies: 99, stars: 99 }),
  "Stelle e trofei non devono piu' sbloccare un completo");
assert.ok(isUnlocked(esempio, { outfitsWon: { [esempio.unlockKey]: true } }),
  "La sfida vinta deve sbloccare il completo");
assert.ok(isUnlocked(esempio, { unlockAll: true }),
  "Il codice di sblocco deve continuare a valere");

// Nessun filtro puo' piu' cercare i completi per `unlock`: quel campo non esiste
// da quando si vincono con una sfida, quindi un `.filter(o => o.unlock)` non
// sbaglia — restituisce zero, in silenzio. E' successo nel Profilo Carriera, che
// per questo elencava 8 contenuti mentre gli Obiettivi ne elencavano 28.
const sorgentiUi = await readFile(new URL("../js/ui.js", import.meta.url), "utf8");
const filtriMorti = [...sorgentiUi.matchAll(/outfitsForAthlete\([^)]*\)\s*\n?\s*\.filter\(\(?(\w+)\)?\s*=>\s*\1\.unlock\b/g)];
assert.equal(filtriMorti.length, 0,
  "In ui.js c'e' un filtro sui completi per `unlock`: quel campo non esiste piu' e il filtro restituisce sempre zero");

console.log(JSON.stringify({
  completiConSfida: conSfida.length,
  atleti: ATHLETES.length,
  tettoPunti: CAP,
  metriche: [...new Set(conSfida.flatMap((o) => prove(o.challenge).map((p) => p.metric)))],
}, null, 2));
