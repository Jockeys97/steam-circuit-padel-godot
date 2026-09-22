import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { courtStyle, coverLane, safeCoverY } from '../js/court-tactics.js';
const root = fileURLToPath(new URL('../', import.meta.url));
const out = (process.argv[2] || mkdtempSync(join(tmpdir(), 'padel-polish-evidence-'))) + '/';
mkdirSync(out, { recursive: true });
console.log('Evidence:', out);
function run(name, exe, args) {
  const r = spawnSync(exe, args, { cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 50e6 });
  writeFileSync(out + name + '.log', (r.stdout || '') + (r.stderr || ''));
  console.log(name, r.status, (r.stdout || '').trim().split('\n').slice(-1)[0]);
  assert.equal(r.status, 0, name + ': see evidence log');
}
assert.equal(coverLane(481, 650, 100, 860), coverLane(479, 650, 100, 860));
assert.ok(safeCoverY(480, 440, 350, 440, 620, 440, 620) > 440);
assert.ok(courtStyle('fiamma').smash > courtStyle('oracolo').smash);
for (const seed of [12345, 999, 2024]) {
  const args = [`--seed=${seed}`, '--ticks=12000', '--every=1', '--script=frozen', '--athlete=0', '--sets=1'];
  run(`match-js-${seed}`, process.execPath, ['tools/parity-godot/ref-match.mjs', ...args]);
  run(`match-gd-${seed}`, 'godot', ['--headless', '--path', 'godot', '--script', 'res://tests/parity/match_digest_gd.gd', '--', ...args]);
  run(`compare-${seed}`, process.execPath, ['tools/parity-godot/compare-match.mjs', out + `match-js-${seed}.log`, out + `match-gd-${seed}.log`, '--quiet']);
}
for (const test of ['gameplay_polish_test', 'rally_stamina_test', 'fluidity_animation_test', 'audits/controller_tactics_audit', 'audits/ai_attack_audit']) {
  run(test.replaceAll('/', '-'), 'godot', ['--headless', '--path', 'godot', '--script', `res://tests/${test}.gd`]);
}
console.log('GAMEPLAY_POLISH_VERIFIED');
