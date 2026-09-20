import { spawnSync } from 'node:child_process';
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { planAiContact } from '../../../../js/ai-contact.js';
import { COURT, BALANCE } from '../../../../js/data.js';
import assert from 'node:assert/strict';
const root = fileURLToPath(new URL('../../../../', import.meta.url));
const evidence = root + 'docs/agent-work/gameplay-fluidity/evidence/';
mkdirSync(evidence, { recursive: true });
function run(name, exe, args) {
  const r = spawnSync(exe, args, { cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 50e6 });
  writeFileSync(evidence + name + '.log', (r.stdout || '') + (r.stderr || ''));
  console.log(name, 'exit=', r.status, (r.stdout || '').trim().split('\n').slice(-1)[0]);
  assert.equal(r.status, 0, name + ': ' + r.stderr);
  return r.stdout;
}
const p = { x: 480, y: 165, speed: 300, width: 60, depth: 70, skill: 0.6, reaction: 0 };
const b = { x: 480, y: 200, z: 40, vx: 0, vy: -75, vz: -60, spin: 0, backspin: 0, topspin: 0, bounces: 0, serve: false, fault: false, incoming: true };
const cases = [];
function add(name, pp, bb, reason) {
  const expected = planAiContact(pp, bb, COURT, BALANCE);
  if (reason) assert.equal(expected.reason, reason, name);
  cases.push({ name, p: pp, b: bb, expected });
}
add('deep reachable bounce', p, b, 'reachable-bounce');
add('comfortable net volley', { ...p, y: 245 }, { ...b, y: 245 }, 'volley');
add('emergency near glass', p, { ...b, y: 100, vy: -300 }, 'emergency');
add('already bounced', p, { ...b, bounces: 1 }, 'bounced');
add('service', p, { ...b, serve: true }, 'not-playable');
add('outgoing', p, { ...b, incoming: false }, 'not-playable');
add('reaction too late', { ...p, reaction: 0.8 }, b, 'emergency');
add('short descending lob stays attackable', { ...p, y: 230 }, { ...b, y: 250, z: 105, vz: -90 }, 'overhead');
for (const skill of [0.2, 0.6, 1]) for (const y of [120, 180, 250]) for (const z of [10, 40, 90, 140]) for (const vx of [-240, 0, 240]) for (const vz of [-150, 0, 180])
  add(`grid-${cases.length}`, { ...p, y, skill }, { ...b, y, z, vx, vz, backspin: skill });
const fixtures = evidence + 'policy-cases.json';
writeFileSync(fixtures, JSON.stringify(cases));
run('policy-parity', '/opt/homebrew/bin/godot', ['--headless','--path','godot','--script','res://tests/ai_contact_policy_test.gd','--',fixtures]);
for (const seed of [12345, 999, 2024]) {
  const args = [`--seed=${seed}`, '--ticks=12000','--every=1','--script=frozen','--athlete=0','--sets=1'];
  run(`match-js-${seed}`, process.execPath, ['tools/parity-godot/ref-match.mjs', ...args]);
  run(`match-gd-${seed}`, '/opt/homebrew/bin/godot', ['--headless','--path','godot','--script','res://tests/parity/match_digest_gd.gd','--', ...args]);
  run(`match-compare-${seed}`, process.execPath, ['tools/parity-godot/compare-match.mjs',evidence+`match-js-${seed}.log`,evidence+`match-gd-${seed}.log`,'--quiet']);
}
run('census-after', process.execPath, ['docs/agent-work/gameplay-fluidity/tools/ai-contact-census.mjs','--out='+evidence+'census-js-after.jsonl']);
for (const suffix of ['before','after']) {
  const rows=readFileSync(evidence+`census-js-${suffix}.jsonl`,'utf8').trim().split('\n').map(JSON.parse);
  console.log('CENSUS', suffix, rows.reduce((a,r)=>({volley:a.volley+r.aiVolleys,bounced:a.bounced+r.aiBounced,serve:a.serve+r.aiServeReturns}),{volley:0,bounced:0,serve:0}));
}
