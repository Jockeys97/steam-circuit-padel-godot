import assert from "node:assert/strict";

import { createMatchState, hitBall } from "../js/game.js?v=20260910-sprite-gate-v41";
import { AI_OPPONENTS, ARENAS, ATHLETES } from "../js/data.js?v=20260910-sprite-gate-v41";
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

function shot({ charge, timingAge = 0, passed = 0, aim = 0 }) {
  Math.random = seededRandom(42);
  const state = createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1]);
  Object.assign(state, {
    running: true,
    serving: false,
    rallyEnergy: { player: 1, ai: 1 },
  });
  Object.assign(state.player, {
    x: 480,
    y: 430,
    moveRatio: 0,
    hitCooldown: 0,
  });
  Object.assign(state.ball, {
    x: 480,
    y: 430 + passed,
    z: 48,
    vy: 120,
    serveInFlight: false,
    netFaultOwner: null,
  });
  const power = 0.4 + charge * 0.95;
  assert(hitBall(state, state.player, power, false, true, aim, false, "drive", 0, timingAge));
  return {
    feedback: state.shotFeedback,
    energy: state.rallyEnergy.player,
    speed: Math.hypot(state.ball.vx, state.ball.vy),
  };
}

const perfect = shot({ charge: 0.5 });
const early = shot({ charge: 0.5, timingAge: 0.22 });
const late = shot({ charge: 0.5, passed: 28 });
const control = shot({ charge: 0.08 });
const power = shot({ charge: 0.92 });

assert.equal(perfect.feedback.grade, "perfect");
assert.equal(early.feedback.grade, "early");
assert.equal(late.feedback.grade, "late");
assert(perfect.feedback.quality > early.feedback.quality, "Il timing perfetto deve migliorare la qualita'");
assert.equal(control.feedback.mode, "CONTROLLO");
assert.equal(power.feedback.mode, "POTENZA");
assert(power.energy < control.energy, "Il power shot deve consumare piu' energia del controllo");
assert(power.speed > control.speed, "Il power shot pulito deve viaggiare piu' veloce");

console.log(JSON.stringify({
  quality: {
    perfect: Number(perfect.feedback.quality.toFixed(3)),
    early: Number(early.feedback.quality.toFixed(3)),
    late: Number(late.feedback.quality.toFixed(3)),
  },
  energyAfterShot: {
    control: Number(control.energy.toFixed(3)),
    power: Number(power.energy.toFixed(3)),
  },
  speed: {
    control: Number(control.speed.toFixed(1)),
    power: Number(power.speed.toFixed(1)),
  },
}, null, 2));
