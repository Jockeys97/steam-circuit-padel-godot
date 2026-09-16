import assert from "node:assert/strict";

import { createMatchState, hitBall, updateMatch } from "../js/game.js?v=20260910-sprite-gate-v41";
import { AI_OPPONENTS, ARENAS, ATHLETES, COURT } from "../js/data.js?v=20260910-sprite-gate-v41";
import { readFile } from "node:fs/promises";

// Le asserzioni confrontano etichette tradotte, quindi la lingua va fissata qui
// invece di ereditare il default dell'interfaccia. L'import deve usare la STESSA
// specifica di game.js: i moduli sono importati con una query di cache busting e
// `i18n.js` e `i18n.js?v=20260910-sprite-gate-v41` sono due istanze distinte, quindi setLang su una
// non ha effetto sull'altra. La specifica viene letta dal sorgente, cosi' non
// va aggiornata a ogni bump di versione.
const gameSource = await readFile(new URL("../js/game.js", import.meta.url), "utf8");
const i18nSpec = gameSource.match(/from "\.\/i18n\.js([^"]*)"/)?.[1] ?? "";
const { setLang } = await import(`../js/i18n.js${i18nSpec}`);
setLang("it");

function stateAtContact({ y = COURT.netY + 120, z = 52 } = {}) {
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  Object.assign(state, { running: true, serving: false });
  Object.assign(state.player, { x: 480, y, hitCooldown: 0, moveRatio: 0 });
  Object.assign(state.ball, {
    x: 480,
    y,
    z,
    vx: 0,
    vy: 120,
    vz: 0,
    bounces: { player: 0, ai: 1 },
    serveInFlight: false,
  });
  return state;
}

const chiquita = stateAtContact({ z: 32 });
assert(hitBall(chiquita, chiquita.player, 0.82, false, true, 0.45, false, "chiquita", 0));
assert.equal(chiquita.ball.shotType, "chiquita");

const vibora = stateAtContact({ z: 58 });
assert(hitBall(vibora, vibora.player, 1, false, true, -0.55, true, "vibora", 0));
assert.equal(vibora.ball.shotType, "vibora");

const defensiveLob = stateAtContact({ y: COURT.netY + 190, z: 34 });
assert(hitBall(defensiveLob, defensiveLob.player, 0.86, false, true, 0.2, false, "defensive-lob", 0));
assert.equal(defensiveLob.ball.shotType, "defensive-lob");

function movementDistance(input) {
  const state = stateAtContact({ y: COURT.bottom - 70, z: 80 });
  state.ball.y = COURT.netY - 130;
  state.ball.vy = -80;
  const start = state.player.x;
  updateMatch(state, 1 / 60, { moveX: 1, moveY: 0, ...input });
  return { distance: state.player.x - start, energy: state.rallyEnergy.player, state };
}

const normal = movementDistance({});
const charging = movementDistance({ charging: true });
const splitStep = movementDistance({ splitStep: 1 });
const sprint = movementDistance({ sprint: 1 });
assert(splitStep.distance < normal.distance, "Lo split-step deve privilegiare stabilita rispetto alla velocita");
// RT non muove piu': governa solo l'angolo del colpo. Prima faceva entrambe le
// cose, e nessuna delle due si poteva dosare senza subire l'altra.
assert.equal(sprint.distance, normal.distance,
  `RT non deve toccare la velocita': ${sprint.distance} contro ${normal.distance}`);
assert.equal(sprint.energy, normal.energy,
  "RT non deve consumare energia: non e' piu' una corsa");
assert(charging.distance < normal.distance && charging.distance > normal.distance * 0.5,
  "Durante la carica il giocatore deve potersi aggiustare, ma piu lentamente");

const tactic = movementDistance({ teamTactic: "attack" }).state;
assert.equal(tactic.playerTeamTactic, "attack");
assert.equal(tactic.events[0], "Tattica di coppia: conquista la rete.");

console.log(JSON.stringify({
  shots: [chiquita.ball.shotType, vibora.ball.shotType, defensiveLob.ball.shotType],
  movement: {
    splitStep: Number(splitStep.distance.toFixed(2)),
    charging: Number(charging.distance.toFixed(2)),
    normal: Number(normal.distance.toFixed(2)),
    sprint: Number(sprint.distance.toFixed(2)),
  },
  tactic: tactic.playerTeamTactic,
}, null, 2));
