#!/usr/bin/env node
// tools/audio-music-port/sync-godot-music.mjs
//
// Vendors the generated reference dump into the engine tree, byte-identical, the way
// `tools/audio-port/sync-godot-audio.mjs` vendors the event contract:
//
//   tools/audio-music-port/out/music-reference.json  ->  godot/src/audio/music_reference.json
//
// The Godot test (`godot/tests/music_port_test.gd`) reads the vendored copy and asserts
// it is byte-identical to the authoritative generated file, so a stale copy is a test
// failure rather than a quietly different expectation.
//
// Usage:
//   node tools/audio-music-port/sync-godot-music.mjs           # write the vendored copy
//   node tools/audio-music-port/sync-godot-music.mjs --check    # verify byte-identity (exit 1 on drift)
//
// Exit codes: 0 ok, 1 drift/missing, 2 usage error.

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");
const SRC = path.join(HERE, "out", "music-reference.json");
const DST = path.join(REPO, "godot", "src", "audio", "music_reference.json");
const SIDECAR = path.join(HERE, "out", "music-reference.sha256");

const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");

function main() {
  const argv = process.argv.slice(2);
  const unknown = argv.filter((a) => a !== "--check");
  if (unknown.length) {
    console.error(`unknown argument(s): ${unknown.join(" ")}`);
    process.exit(2);
  }
  if (!existsSync(SRC)) {
    console.error(`FAIL — ${path.relative(REPO, SRC)} is missing; run \`node tools/audio-music-port/extract-music.mjs\` first`);
    process.exit(1);
  }
  const srcBytes = readFileSync(SRC);
  const srcHash = sha256(srcBytes);
  if (existsSync(SIDECAR)) {
    const recorded = readFileSync(SIDECAR, "utf8").trim();
    if (recorded !== srcHash) {
      console.error(`FAIL — ${path.relative(REPO, SRC)} does not match the sha256 recorded by the extractor`);
      console.error(`  recorded ${recorded}`);
      console.error(`  actual   ${srcHash}`);
      process.exit(1);
    }
  } else {
    console.error(`FAIL — ${path.relative(REPO, SIDECAR)} is missing; re-run the extractor`);
    process.exit(1);
  }

  if (argv.includes("--check")) {
    if (!existsSync(DST)) {
      console.error(`FAIL — ${path.relative(REPO, DST)} is missing`);
      process.exit(1);
    }
    const dstBytes = readFileSync(DST);
    if (Buffer.compare(srcBytes, dstBytes) !== 0) {
      console.error(`FAIL — the vendored engine copy is not byte-identical to the generated reference dump`);
      console.error(`  ${path.relative(REPO, SRC)} sha256 ${srcHash} (${srcBytes.length} bytes)`);
      console.error(`  ${path.relative(REPO, DST)} sha256 ${sha256(dstBytes)} (${dstBytes.length} bytes)`);
      process.exit(1);
    }
    console.log(`ok — ${path.relative(REPO, DST)} is byte-identical to ${path.relative(REPO, SRC)}`);
    console.log(`  sha256 ${srcHash}  ${srcBytes.length} bytes`);
    process.exit(0);
  }

  mkdirSync(path.dirname(DST), { recursive: true });
  writeFileSync(DST, srcBytes);
  const dstBytes = readFileSync(DST);
  if (Buffer.compare(srcBytes, dstBytes) !== 0) {
    console.error(`FAIL — the write did not land byte-identical`);
    process.exit(1);
  }
  console.log(`wrote ${path.relative(REPO, DST)} — ${dstBytes.length} bytes, sha256 ${srcHash}`);
  process.exit(0);
}

main();
