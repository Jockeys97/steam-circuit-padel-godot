import assert from "node:assert/strict";

import { createMatchState, hitBall, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { AI_OPPONENTS, ARENAS, ATHLETES, BALANCE, COURT } from "../js/data.js?v=20260910-sprite-gate-v41";

function smash({
  height = 55,
  y = COURT.netY + 170,
  aim = 0,
  aimY = -1,
  charge = 0.76,
  timingAge = 0,
  moveRatio = 0,
  passed = 0,
  rallyHits = 2,
} = {}) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  // rallyHits > 0: lo smash e' vietato sulla risposta al servizio, e qui si
  // stanno verificando i colpi durante lo scambio.
  Object.assign(state, { running: true, serving: false, rallyHits });
  Object.assign(state.player, { x: 480, y, hitCooldown: 0, moveRatio });
  Object.assign(state.ball, {
    x: 480,
    y: y + passed,
    z: height,
    vy: 120,
    serveInFlight: false,
    netFaultOwner: null,
  });
  const power = 0.4 + charge * 0.95;
  assert(hitBall(state, state.player, power, false, true, aim, false, "smash", aimY, timingAge));
  return state.ball.shotType;
}

assert.equal(smash(), "smash-x2", "Il doppio tap su palla alta a rete deve produrre uno smash X2");
assert.equal(smash({ aim: 0.82 }), "smash-x3", "La diagonale della levetta deve produrre uno smash X3");
assert.equal(
  smash({ aim: 0.82, timingAge: 0.3, moveRatio: 1, passed: 20 }),
  "smash-flat",
  "Uno smash valido ma imperfetto deve degradare a piatto, non a bandeja",
);
assert.equal(
  smash({ height: BALANCE.smashMinHeight - 8 }),
  "bandeja",
  "Una palla bassa deve restare una bandeja",
);
assert.equal(
  smash({ y: COURT.netY + BALANCE.smashNetWindow + 30 }),
  "bandeja",
  "Uno smash da fondo deve restare una bandeja",
);

function bufferedSmash() {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  Object.assign(state, {
    running: true,
    serving: false,
    shotCharge: 0.76,
    activePlayerKey: "player",
    rallyHits: 2,
  });
  Object.assign(state.player, {
    x: 480,
    y: COURT.netY + 170,
    hitCooldown: 0,
    moveRatio: 0,
  });
  Object.assign(state.ball, {
    x: 480,
    y: state.player.y - 125,
    z: 68,
    vx: 0,
    vy: 260,
    vz: 135,
    bounces: { player: 0, ai: 1 },
    serveInFlight: false,
    netFaultOwner: null,
  });
  const release = {
    hit: true,
    shotVariant: "drive",
    aim: 0,
    aimY: -1,
    analogAim: true,
    moveX: 0,
    moveY: 0,
  };
  updateMatch(state, 1 / 60, release);
  assert.equal(state.smashPrimed, true, "Il primo rilascio di A deve preparare lo smash");
  updateMatch(state, 1 / 60, {
    smashUpgrade: true,
    aim: 0,
    aimY: -1,
    analogAim: true,
    moveX: 0,
    moveY: 0,
  });
  assert.equal(state.smashPrimed, false, "Il secondo tap di A deve confermare lo smash");
  for (let frame = 0; frame < 40 && state.ball.shotType !== "smash-x2"; frame += 1) {
    updateMatch(state, 1 / 60, { moveX: 0, moveY: 0 });
  }
  return state.ball.shotType;
}

function missedDoubleTap() {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  Object.assign(state, { running: true, serving: false, shotCharge: 0.76, rallyHits: 2 });
  Object.assign(state.player, {
    x: 480,
    y: COURT.netY + 170,
    hitCooldown: 0,
    moveRatio: 0,
  });
  Object.assign(state.ball, {
    x: 480,
    y: state.player.y - 125,
    z: 68,
    vx: 0,
    vy: 260,
    vz: 135,
    bounces: { player: 0, ai: 1 },
    serveInFlight: false,
    netFaultOwner: null,
  });
  updateMatch(state, 1 / 60, {
    hit: true,
    shotVariant: "drive",
    aim: 0,
    aimY: -1,
    analogAim: true,
    moveX: 0,
    moveY: 0,
  });
  for (let frame = 0; frame < 65 && state.lastHitterSide !== "player"; frame += 1) {
    updateMatch(state, 1 / 60, { moveX: 0, moveY: 0 });
  }
  return { type: state.ball.shotType, hitter: state.lastHitterSide };
}

assert.equal(
  bufferedSmash(),
  "smash-x2",
  "Il doppio tap di A deve conservare lo smash fino al contatto con una palla in arrivo",
);
assert.deepEqual(
  missedDoubleTap(),
  { type: "drive", hitter: "player" },
  "Senza secondo tap il colpo preparato deve degradare a drive, non sparire",
);

const rispostaAlServizio = smash({ rallyHits: 0 });
assert.equal(
  rispostaAlServizio,
  "bandeja",
  `La risposta al servizio non puo' essere uno smash: ${rispostaAlServizio}`,
);

console.log(JSON.stringify({
  x2: smash(),
  x3: smash({ aim: 0.82 }),
  imperfect: smash({ aim: 0.82, timingAge: 0.3, moveRatio: 1, passed: 20 }),
  lowBall: smash({ height: BALANCE.smashMinHeight - 8 }),
  fromBack: smash({ y: COURT.netY + BALANCE.smashNetWindow + 30 }),
  buffered: bufferedSmash(),
  missedDoubleTap: missedDoubleTap(),
}, null, 2));
