#!/usr/bin/env node
/**
 * seed-vectors.mjs — the JavaScript side of the seed vectors
 * `godot/tests/audits/run_all.gd` asserts against.
 *
 * The reference audits install their own generator with
 * `Math.random = seededRandom(seed)` (`scripts/shot-quality-audit.mjs:18-29`), and
 * `js/game.js:218` then builds `rngState` from the first draw:
 *
 *     rngState: (Math.random() * 0xffffffff) | 0
 *
 * `godot/src/audits/audit_support.gd` reproduces that arithmetic in integers. This
 * script prints the JavaScript result for the seeds the ported audits use, so the
 * reproduction can be checked against V8 rather than against itself.
 *
 *   node tools/audit-port/seed-vectors.mjs
 */
function seededRandom(seed) {
  let value = seed >>> 0;
  return () => {
    value = (value + 0x6D2B79F5) | 0;
    let t = Math.imul(value ^ (value >>> 15), 1 | value);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const seeds = [42, 1, 11, 20260811, 7919, 4242];
const out = {};
for (const seed of seeds) {
  const draw = seededRandom(seed);
  out[seed] = (draw() * 0xffffffff) | 0;
}
// `Math.random = () => 0.5` (scripts/shot-balance-audit.mjs:90).
out["half"] = (0.5 * 0xffffffff) | 0;
console.log(JSON.stringify(out, null, 2));
