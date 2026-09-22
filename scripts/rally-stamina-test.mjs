import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import { fatigue, staminaSpeed, assessmentEnergy, executionEnergy, shotCost, effortEnergy } from '../js/rally-stamina.js';
import { createMatchState, updateMatch } from '../js/game.js';
import { ATHLETES, ARENAS, AI_OPPONENTS } from '../js/data.js';

const cases = [];
for (const energy of [0.15, 0.3, 0.59, 0.6, 0.8, 1]) {
  assert.ok(staminaSpeed(energy) >= 0.75 && staminaSpeed(energy) <= 1);
  if (energy >= 0.7) assert.equal(fatigue(energy), 0);
  for (const dt of [1/30, 1/60, 1/120]) for (const movement of [0, 0.5, 1])
    for (const sprint of [0, 1]) for (const stamina of [0.7, 1, 1.38]) {
      const next = effortEnergy(energy, dt, movement, sprint, stamina);
      assert.ok(next >= 0.15 && next <= 1);
      cases.push({ energy, dt, movement, sprint, stamina, next, speed: staminaSpeed(energy), assessment: assessmentEnergy(energy), execution: executionEnergy(energy, 0.8, movement, 0.7, sprint, true) });
    }
}
assert.ok(shotCost('smash-flat') > shotCost('bandeja'));
assert.ok(shotCost('bandeja') > shotCost('safe-drive'));
assert.ok(shotCost('vibora') > shotCost('slice', true));
assert.equal(shotCost('smash-x3', false, 'power'), 0.125);
assert.equal(executionEnergy(0.15, 0, 0, 1, 0, false), 1);
assert.ok(executionEnergy(0.15, 1, 1, 0.6, 0, true) < 0.2);
assert.ok(staminaSpeed(0.4) < 0.86);
const input = { left:false, right:false, up:false, down:false, moveX:0, moveY:0,
  charging:false, hit:false, slice:false, shotVariant:null, special:false, switchPlayer:false,
  switchDirection:null, aim:0, aimY:0, analogAim:false, splitStep:0, sprint:0,
  technicalModifier:false, teamTactic:null, cutVolley:false, globo:false };
const matches=[];
for (const seed of [12345, 999, 2024]) {
  const state=createMatchState('quick',ATHLETES[0],ARENAS[0],AI_OPPONENTS[1],0,{seed});
  state.running = true;
  state.rngState = seed | 0;
  const min={player:1,playerMate:1,opponent:1,opponentMate:1};
  for(let tick=0;tick<12000;tick++) {
    const controls={...input,charging:tick>=60,hit:tick>=60&&tick%30===0};
    updateMatch(state,1/120,controls);
    for(const key of Object.keys(min)){
      assert.ok(Number.isFinite(state[key].staminaEnergy));
      assert.ok(state[key].staminaEnergy>=0.15&&state[key].staminaEnergy<=1);
      min[key]=Math.min(min[key],state[key].staminaEnergy);
    }
  }
  assert.ok(state.stats.rallyCount > 0, 'simulation must actually play points');
  assert.ok(Object.values(min).some(e => e < 0.99), 'simulation must expend energy');
  matches.push({seed,min,points:state.stats.pointsWon,errors:state.stats.errors,
    longestRally:state.stats.longestRally,rallies:state.stats.rallyCount,totalHits:state.stats.totalRallyHits});
}
if(process.argv[2])writeFileSync(process.argv[2],JSON.stringify(cases));
console.log(JSON.stringify({fixtureCount:cases.length,matches},null,2));
console.log('STAMINA_JS_PASS');
