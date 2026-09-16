#!/usr/bin/env node
/**
 * sync-godot-audio.mjs — vendor the verified audio contract into the Godot project.
 *
 * This is the ONLY writer of the two engine-side copies of the contract:
 *
 *   tools/audio-port/event-map.json   ->  godot/src/audio/event_map.json   (byte-identical)
 *   tools/audio-audition/baked/*.wav  ->  godot/assets/audio/<sound>.wav   (byte-identical)
 *
 * It reads the authoritative map, re-verifies every WAV sha256 the map records,
 * copies the bytes, re-verifies the copies, and prints one row per file plus both
 * map hashes. `tools/audio-port/event-map.json` and
 * `tools/audio-port/verify-event-map.mjs` are read-only here — this tool never
 * touches them (the contract is the source of truth, not a consumer of the port).
 *
 * The engine-side copies are byte-identical on purpose: "drift" is then a
 * sha256 comparison, not a field-by-field diff, and the headless test in
 * godot/tests/audio_port_test.gd can prove the chain
 *
 *   authoritative map == vendored map == what the module ships and plays
 *
 * with hashes only.
 *
 * Usage:
 *   node tools/audio-port/sync-godot-audio.mjs           # write the engine copies
 *   node tools/audio-port/sync-godot-audio.mjs --check   # write nothing, fail on drift
 *
 * Exit 0 = engine copies match the contract. Exit 1 = drift (or a missing/edited
 * WAV); exit 2 = the contract itself is unusable.
 */

import { readFileSync, writeFileSync, existsSync, statSync, copyFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, "..", "..");
const MAP = join(HERE, "event-map.json");
const VENDOR_MAP = join(REPO, "godot", "src", "audio", "event_map.json");
const ASSET_DIR = join(REPO, "godot", "assets", "audio");

const CHECK_ONLY = process.argv.slice(2).includes("--check");

const sha256 = (abs) => createHash("sha256").update(readFileSync(abs)).digest("hex");

function fail(msg) {
  process.stdout.write(`FAIL ${msg}\n`);
  process.exit(1);
}

function main() {
  if (!existsSync(MAP)) {
    process.stdout.write(`FATAL: missing ${MAP}\n`);
    process.exit(2);
  }
  let map;
  try {
    map = JSON.parse(readFileSync(MAP, "utf8"));
  } catch (err) {
    process.stdout.write(`FATAL: ${MAP} is not valid JSON: ${err.message}\n`);
    process.exit(2);
  }
  const events = map.events || [];
  if (events.length === 0) {
    process.stdout.write("FATAL: the contract declares no events\n");
    process.exit(2);
  }

  const problems = [];
  const rows = [];

  // ---- 1. WAVs: verify the baked source, copy, verify the copy ---------------
  const copied = [];
  for (const e of events) {
    const srcAbs = join(REPO, e.wav.path);
    const dstAbs = join(ASSET_DIR, `${e.sound}.wav`);
    if (!existsSync(srcAbs)) {
      problems.push(`${e.id}: baked WAV missing: ${e.wav.path}`);
      continue;
    }
    const srcHash = sha256(srcAbs);
    const srcBytes = statSync(srcAbs).size;
    if (e.wav.sha256 && srcHash !== e.wav.sha256) {
      problems.push(`${e.id}: ${e.wav.path} sha256 drifted\n      map: ${e.wav.sha256}\n      now: ${srcHash}`);
      continue;
    }
    if (e.wav.bytes && srcBytes !== e.wav.bytes) {
      problems.push(`${e.id}: ${e.wav.path} byte count drifted: map ${e.wav.bytes}, now ${srcBytes}`);
      continue;
    }
    let dstHash = null;
    if (CHECK_ONLY) {
      if (!existsSync(dstAbs)) {
        problems.push(`${e.id}: engine copy missing: godot/assets/audio/${e.sound}.wav (run without --check)`);
        continue;
      }
      dstHash = sha256(dstAbs);
    } else {
      mkdirSync(ASSET_DIR, { recursive: true });
      copyFileSync(srcAbs, dstAbs);
      dstHash = sha256(dstAbs);
    }
    if (dstHash !== srcHash) {
      problems.push(`${e.id}: engine copy godot/assets/audio/${e.sound}.wav != ${e.wav.path}\n      src: ${srcHash}\n      dst: ${dstHash}`);
      continue;
    }
    copied.push({ id: e.id, sound: e.sound, dstAbs, hash: dstHash, bytes: srcBytes, src: e.wav.path });
  }

  // ---- 2. the map itself, byte-identical ------------------------------------
  const mapHash = sha256(MAP);
  let vendorHash = null;
  if (CHECK_ONLY) {
    if (!existsSync(VENDOR_MAP)) {
      problems.push("engine contract copy missing: godot/src/audio/event_map.json (run without --check)");
    } else {
      vendorHash = sha256(VENDOR_MAP);
    }
  } else {
    mkdirSync(dirname(VENDOR_MAP), { recursive: true });
    writeFileSync(VENDOR_MAP, readFileSync(MAP));
    vendorHash = sha256(VENDOR_MAP);
  }
  if (vendorHash !== null && vendorHash !== mapHash) {
    problems.push(
      `engine contract copy godot/src/audio/event_map.json != tools/audio-port/event-map.json\n      contract: ${mapHash}\n      vendored: ${vendorHash}`
    );
  }

  // ---- report ---------------------------------------------------------------
  process.stdout.write(`audio contract -> Godot sync  ${CHECK_ONLY ? "(check only, nothing written)" : "(writing engine copies)"}\n`);
  process.stdout.write(`  repo: ${REPO}\n\n`);
  process.stdout.write(`  contract map   tools/audio-port/event-map.json\n      sha256 ${mapHash}\n`);
  if (vendorHash !== null) {
    process.stdout.write(`  engine map     godot/src/audio/event_map.json\n      sha256 ${vendorHash}${vendorHash === mapHash ? "  (identical)" : "  (DRIFTED)"}\n`);
  }
  process.stdout.write(`\n  ${"event".padEnd(12)} ${"wav".padEnd(10)} ${"bytes".padStart(7)}  sha256\n`);
  for (const r of copied) {
    process.stdout.write(`  ${r.id.padEnd(12)} ${(r.sound + ".wav").padEnd(10)} ${String(r.bytes).padStart(7)}  ${r.hash.slice(0, 16)}…\n`);
  }
  process.stdout.write(`\n  events in contract : ${events.length}\n`);
  process.stdout.write(`  WAVs verified      : ${copied.length}/${events.length}\n`);
  process.stdout.write(`  sounds declared    : ${(map.soundIds || []).length}\n`);

  if (problems.length) {
    process.stdout.write(`\n${problems.length} problem(s):\n`);
    for (const p of problems) process.stdout.write(`  - ${p}\n`);
    fail(`RESULT: FAIL — ${problems.length} problem(s) between the contract and the Godot engine copies.`);
  }
  process.stdout.write(`\nRESULT: PASS — contract and engine copies agree (${copied.length}/${events.length} WAVs, map sha256 ${mapHash.slice(0, 16)}…).\n`);
  process.exit(0);
}

main();
