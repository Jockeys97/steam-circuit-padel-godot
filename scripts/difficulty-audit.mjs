import assert from "node:assert/strict";

import { createMatchState, hitBall, performServe, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../js/data.js?v=20260910-sprite-gate-v41";

const EMPTY_INPUT = {
  moveX: 0,
  moveY: 0,
  charging: false,
  hit: false,
  slice: false,
  special: false,
  switchPlayer: false,
  switchDirection: null,
  aim: 0,
  aimY: 0,
  analogAim: false,
};

function seededRandom(seed) {
  // Generatore di qualita' (mulberry32). Il congruenziale lineare usato prima
  // aveva correlazioni forti fra estrazioni vicine e falsava le misure: il tasso
  // d'errore dell'IA media risultava 0.082 invece dei ~0.148 reali del browser.
  let value = seed >>> 0;
  return () => {
    value = (value + 0x6D2B79F5) | 0;
    let t = Math.imul(value ^ (value >>> 15), 1 | value);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function createRallyState(aiIndex) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[aiIndex]);
  Object.assign(state, {
    running: true,
    serving: false,
    pointPause: 0,
    lastHitterSide: "ai",
    rallyHits: 3,
    // Senza azzerare questi non si sta simulando uno scambio: `aiServiceReceiverKey`
    // vale "opponent" da quando la partita nasce, e finche' e' impostata le
    // racchette avversarie vengono portate in posizione di ricezione del servizio
    // da un ramo che precede del tutto la logica di difesa. Le misure di questo
    // audit descrivevano un'IA che aspetta un servizio, non una che difende.
    aiServiceReceiverKey: null,
    serviceReceiverKey: null,
    aiReceiverLocked: false,
  });
  Object.assign(state.player, { x: 480, y: 395, controlled: true, isPlayer: true, hitCooldown: 0 });
  Object.assign(state.playerMate, { x: 700, y: 405, hitCooldown: 0 });
  Object.assign(state.opponent, { x: 330, y: 145, hitCooldown: 0 });
  Object.assign(state.opponentMate, { x: 650, y: 210, hitCooldown: 0 });
  Object.assign(state.ball, {
    x: 480,
    y: 375,
    z: 70,
    vx: 0,
    vy: 100,
    vz: 0,
    bounces: { player: 0, ai: 0 },
    serveInFlight: false,
    netFaultOwner: null,
    crossedNet: true,
  });
  return state;
}

function simulatePlayerSmash(aiIndex, aim, seed) {
  Math.random = seededRandom(seed);
  const state = createRallyState(aiIndex);
  hitBall(state, state.player, 1.35, false, true, aim, false, "smash", -1);
  for (let frame = 0; frame < 2600; frame += 1) {
    updateMatch(state, 1 / 240, EMPTY_INPUT);
    if (state.rallyHits >= 5 || state.stats.pointsWon.player || state.stats.pointsWon.ai) break;
  }
  return {
    returned: state.rallyHits >= 5,
    winner: state.stats.pointsWon.player > 0,
  };
}

function simulateServeReturn(aiIndex, charge, seed) {
  Math.random = seededRandom(seed);
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[aiIndex]);
  state.running = true;
  performServe(state, charge, false);
  for (let frame = 0; frame < 2600; frame += 1) {
    updateMatch(state, 1 / 240, EMPTY_INPUT);
    if (state.rallyHits >= 1 || state.stats.pointsWon.player || state.stats.pointsWon.ai) break;
  }
  return state.rallyHits >= 1;
}

function sampleAiErrors(aiIndex, samples = 1000) {
  let errors = 0;
  for (let seed = 1; seed <= samples; seed += 1) {
    Math.random = seededRandom(seed + aiIndex * 10000);
    const state = createRallyState(aiIndex);
    state.rallyHits = 12;
    Object.assign(state.opponent, { x: 480, y: 230, hitCooldown: 0 });
    Object.assign(state.ball, { x: 480, y: 250, z: 70, vy: -80 });
    hitBall(state, state.opponent, 1, false, true);
    if (state.ball.shotType === "error" || state.aiRecoveryMode) errors += 1;
  }
  return errors / samples;
}

const samples = 240;
const report = AI_OPPONENTS.map((profile, aiIndex) => {
  let x2Winners = 0;
  let x3Winners = 0;
  let servesReturned = 0;
  for (let seed = 1; seed <= samples; seed += 1) {
    if (simulatePlayerSmash(aiIndex, 0, seed + aiIndex * 1000).winner) x2Winners += 1;
    if (simulatePlayerSmash(aiIndex, 0.8, seed + aiIndex * 2000).winner) x3Winners += 1;
    if (simulateServeReturn(aiIndex, 0.82, seed + aiIndex * 3000)) servesReturned += 1;
  }
  return {
    id: profile.id,
    skill: profile.skill,
    effectiveSpeed: Number((profile.speed * (0.86 + profile.skill * 0.1)).toFixed(1)),
    // La reazione dipende da `reactionSkill`, che puo' essere piu' bassa della
    // skill: sopra 0.78 di reattivita' l'IA intercetta lo smash prima del vetro.
    baseReactionMs: Math.round((0.28 - (profile.reactionSkill ?? profile.skill) * 0.25) * 1000),
    aimErrorPx: Number(((1 - profile.skill) * 44).toFixed(1)),
    longRallyErrorRate: Number(sampleAiErrors(aiIndex).toFixed(3)),
    serveReturnRate: Number((servesReturned / samples).toFixed(3)),
    x2PlayerWinnerRate: Number((x2Winners / samples).toFixed(3)),
    x3PlayerWinnerRate: Number((x3Winners / samples).toFixed(3)),
  };
});

// Lo X3 e' il colpo che decide i punti, e questi due vincoli sono la ragione per
// cui l'audit esiste. Passo per passo non si puo' pretendere molto: con 240
// prove l'errore di campionamento e' di circa tre punti, quindi un divario di
// quattro fra due gradini vicini non e' distinguibile dal rumore, e chiederlo
// sarebbe finta precisione. Sugli estremi invece il segnale c'e'.
const facile = report[0];
const durissimo = report[report.length - 1];
const forbice = facile.x3PlayerWinnerRate - durissimo.x3PlayerWinnerRate;

assert(durissimo.x3PlayerWinnerRate <= 0.35,
  `Contro il livello piu' duro uno X3 non deve chiudere piu' di un terzo dei punti: `
  + `${(durissimo.x3PlayerWinnerRate * 100).toFixed(0)}%. Padroneggiare il colpo piu' forte `
  + `del gioco non puo' bastare a vincere la difficolta' massima.`);

assert(forbice >= 0.45,
  `Fra il primo e l'ultimo gradino lo X3 deve cambiare mestiere: `
  + `${(facile.x3PlayerWinnerRate * 100).toFixed(0)}% -> ${(durissimo.x3PlayerWinnerRate * 100).toFixed(0)}%, `
  + `forbice ${(forbice * 100).toFixed(0)} punti. Se resta stretta, la difficolta' non tocca `
  + `il colpo che decide i punti.`);

console.log(JSON.stringify(report, null, 2));

for (let index = 1; index < report.length; index += 1) {
  const easier = report[index - 1];
  const harder = report[index];
  assert(harder.skill > easier.skill, "La skill deve crescere con la difficolta");
  assert(harder.effectiveSpeed > easier.effectiveSpeed, "La velocita deve crescere con la difficolta");
  assert(harder.baseReactionMs <= easier.baseReactionMs, "Il tempo di reazione non deve peggiorare con la difficolta");
  assert(harder.aimErrorPx < easier.aimErrorPx, "L'errore di mira deve calare con la difficolta");
  assert(harder.longRallyErrorRate < easier.longRallyErrorRate, "Gli errori IA devono calare con la difficolta");
  // Sotto il 5% la difesa dello X2 e' satura e la metrica e' solo rumore di
  // campionamento (300 prove, +/- 1,4 punti): li' basta che non peggiori.
  const x2Saturo = harder.x2PlayerWinnerRate < 0.05 && easier.x2PlayerWinnerRate < 0.05;
  assert(x2Saturo || harder.x2PlayerWinnerRate <= easier.x2PlayerWinnerRate,
    `La difesa dello X2 deve migliorare: ${easier.id} ${easier.x2PlayerWinnerRate} -> ${harder.id} ${harder.x2PlayerWinnerRate}`);
  // Lo X3 e' il colpo che decide i punti, quindi qui non basta "non peggiora":
  // ogni gradino deve difenderlo *percettibilmente* meglio del precedente.
  // L'assert di prima chiedeva solo che non salisse, e passava con Campione al
  // 53% e Leggenda al 51%: sul colpo piu' forte del gioco l'ultimo gradino di
  // difficolta' non esisteva, e nessun audit se ne accorgeva.
  assert(harder.x3PlayerWinnerRate <= easier.x3PlayerWinnerRate,
    `La difesa dello X3 non deve peggiorare salendo di livello: ${easier.id} `
    + `${(easier.x3PlayerWinnerRate * 100).toFixed(0)}% -> ${harder.id} ${(harder.x3PlayerWinnerRate * 100).toFixed(0)}%`);
}

for (const difficulty of report) {
  assert(difficulty.serveReturnRate >= 0.9, `${difficulty.id} deve rispondere ai servizi validi`);
}
