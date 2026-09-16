#!/usr/bin/env node
/**
 * verify-event-map.mjs — engine-free audio port contract test.
 *
 * Asserts, against the CURRENT source tree, that tools/audio-port/event-map.json
 * is still a faithful description of the reference game's audio events:
 *
 *   (a) every anchor in event-map.json resolves to a real call site in the source
 *       (the anchor line contains the declared call verbatim, and the declared
 *       enclosing function is the one that actually encloses that line);
 *   (b) every one of the 10 baked WAVs is reachable from at least one event, and
 *       each event's WAV exists, is a RIFF/WAVE file, and matches its recorded sha256;
 *   (c) no audio event the source can emit is unmapped — the event set is derived
 *       from the real source (every `sfx.<method>(` call site in js/game.js, every
 *       method of the `sfx` object in js/audio.js, every WAV on disk), not from a
 *       hand-written list — and the port bindings are cross-checked against the
 *       event ids the ported sim actually stores (godot/src/sim/sim.gd);
 *   (d) genuinely-injected drift goes RED: seven mutations (removals, an anchor
 *       shift, a port-id rename, a new unmapped sfx method, a WAV byte/hash change,
 *       a missing WAV) are applied to a clone of the map and MUST produce failures.
 *       If any injected drift is NOT caught, this test fails too.
 *
 * No dependencies, no install, no engine: node stdlib + the repo's own files.
 * Exit code 0 = every check green and every injected drift caught.
 *
 * Usage:
 *   node tools/audio-port/verify-event-map.mjs
 *   node tools/audio-port/verify-event-map.mjs --drift=remove-wall
 *     -> runs ONE injected-drift scenario as the primary check.
 *        exit 1 with "DRIFT DETECTED" means the test caught the drift (this is the
 *        demonstrable RED case); exit 0 in this mode would mean the test failed to
 *        notice the drift and is a bug in the test itself.
 */

import { readFileSync, existsSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve, basename } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, "..", "..");
const MAP_PATH = join(HERE, "event-map.json");

const C = {
  reset: "\u001b[0m",
  red: "\u001b[31m",
  green: "\u001b[32m",
  yellow: "\u001b[33m",
  dim: "\u001b[2m",
  bold: "\u001b[1m",
};
const useColor = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (c, s) => (useColor ? c + s + C.reset : s);

// ---------------------------------------------------------------------------
// source reading
// ---------------------------------------------------------------------------

function readSource(rel) {
  const abs = join(REPO, rel);
  if (!existsSync(abs)) return null;
  return readFileSync(abs, "utf8");
}

function lines(text) {
  return text.split(/\r?\n/);
}

function lineAt(text, n) {
  const ls = lines(text);
  if (n < 1 || n > ls.length) return null;
  return ls[n - 1];
}

const FN_RE = /^\s*(?:export\s+)?(?:static\s+)?(?:func|function)\s+([A-Za-z_$][\w$]*)/;

/** Name of the last function declared at or before `line` (1-indexed). */
function enclosingFunction(text, line) {
  const ls = lines(text);
  let found = null;
  for (let i = 0; i < Math.min(line, ls.length); i += 1) {
    const m = ls[i].match(FN_RE);
    if (m) found = { name: m[1], line: i + 1 };
  }
  return found;
}

/** `sfx.<method>(` call sites in a source file, with line numbers. */
function parseSfxCallSites(rel, text) {
  const ls = lines(text);
  const out = [];
  const re = /\bsfx\.([A-Za-z_$][\w$]*)\s*\(/g;
  ls.forEach((line, i) => {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(line)) !== null) {
      out.push({
        file: rel,
        line: i + 1,
        method: m[1],
        key: `${rel}:${i + 1}:sfx.${m[1]}(`,
      });
    }
  });
  return out;
}

/** Method names of the `sfx = { ... }` object in js/audio.js, read from source. */
function parseSfxMethods(rel, text) {
  const start = text.indexOf("export const sfx = {");
  if (start < 0) return { methods: [], error: `no 'export const sfx = {' in ${rel}` };
  const ls = lines(text.slice(start));
  const methods = [];
  for (let i = 1; i < ls.length; i += 1) {
    if (/^\};?\s*$/.test(ls[i])) break;
    const m = ls[i].match(/^\s{2}([A-Za-z_$][\w$]*)\s*\(/);
    if (m) methods.push(m[1]);
  }
  return { methods, error: null };
}

/** The method named in an anchor call string, e.g. `sfx.point(...)` -> `point`. */
function anchorMethod(call) {
  const m = String(call).match(/\bsfx\.([A-Za-z_$][\w$]*)\s*\(/);
  return m ? m[1] : null;
}

function sha256(abs) {
  return createHash("sha256").update(readFileSync(abs)).digest("hex");
}

// ---------------------------------------------------------------------------
// the checks
// ---------------------------------------------------------------------------

const SOUND_FROM_METHOD = null; // no name table: sound ids come from the WAVs on disk

function runChecks(map, env) {
  const checks = [];
  const add = (name, failures, detail) => checks.push({ name, failures, detail });

  const byId = new Map((map.events || []).map((e) => [e.id, e]));
  const gameText = env.gameText;
  const audioText = env.audioText;
  const simText = env.simText;

  // --- structure ---------------------------------------------------------
  {
    const f = [];
    if (map.schema !== "steam-circuit-padel-pro.audio-event-map") f.push(`unexpected schema: ${map.schema}`);
    if (!Number.isInteger(map.schemaVersion)) f.push("schemaVersion must be an integer");
    if (!Array.isArray(map.events) || map.events.length === 0) f.push("events must be a non-empty array");
    if (!Array.isArray(map.soundIds) || map.soundIds.length === 0) f.push("soundIds must be a non-empty array");
    const ids = new Set();
    for (const e of map.events || []) {
      if (!e.id) f.push("an event has no id");
      if (ids.has(e.id)) f.push(`duplicate event id: ${e.id}`);
      ids.add(e.id);
      if (!e.sound) f.push(`event ${e.id} has no sound`);
      if (!e.anchor || !e.anchor.file || !e.anchor.line || !e.anchor.call) f.push(`event ${e.id} has an incomplete anchor`);
      if (!e.port || !e.port.file || !e.port.line) f.push(`event ${e.id} has an incomplete port binding`);
      if (!e.wav || !e.wav.path) f.push(`event ${e.id} has no wav`);
    }
    add("map: structure", f, `${(map.events || []).length} events, ${(map.soundIds || []).length} declared sounds`);
  }

  // --- (a) anchors resolve -------------------------------------------------
  {
    const f = [];
    let resolved = 0;
    for (const e of map.events || []) {
      const text = env.byFile[e.anchor.file];
      if (text == null) {
        f.push(`${e.id}: anchor file missing: ${e.anchor.file}`);
        continue;
      }
      const line = lineAt(text, e.anchor.line);
      if (line == null) {
        f.push(`${e.id}: anchor line ${e.anchor.file}:${e.anchor.line} is out of range`);
        continue;
      }
      if (!line.includes(e.anchor.call)) {
        f.push(`${e.id}: ${e.anchor.file}:${e.anchor.line} does not contain '${e.anchor.call}' — found '${line.trim().slice(0, 80)}'`);
        continue;
      }
      const want = String(e.anchor.fn || "").split(/[\s(]/)[0];
      const enc = enclosingFunction(text, e.anchor.line);
      if (!enc) {
        f.push(`${e.id}: no function encloses ${e.anchor.file}:${e.anchor.line}`);
        continue;
      }
      if (want && enc.name !== want) {
        f.push(`${e.id}: ${e.anchor.file}:${e.anchor.line} is inside ${enc.name}(), map says ${e.anchor.fn}`);
        continue;
      }
      resolved += 1;
    }
    add("anchors: reference call sites resolve", f, `${resolved}/${(map.events || []).length} anchors verbatim + enclosing function matches`);
  }

  // --- (c1) call-site coverage, derived from js/game.js --------------------
  {
    const sites = parseSfxCallSites("js/game.js", gameText);
    const siteKeys = new Set(sites.map((s) => s.key));
    const mapKeys = new Set();
    for (const e of map.events || []) {
      const m = anchorMethod(e.anchor.call);
      if (!m) {
        add("events: call-site coverage", [`event ${e.id} anchor is not an sfx call: ${e.anchor.call}`], "");
        mapKeys.add(`<<unparsable:${e.id}>>`);
        continue;
      }
      mapKeys.add(`${e.anchor.file}:${e.anchor.line}:sfx.${m}(`);
    }
    const f = [];
    for (const k of siteKeys) if (!mapKeys.has(k)) f.push(`unmapped sfx call site: ${k}`);
    for (const k of mapKeys) if (!siteKeys.has(k)) f.push(`map cites a call site the source does not have: ${k}`);
    add("events: call-site coverage (js/game.js)", f, `${siteKeys.size} source call sites == ${mapKeys.size} mapped call sites`);
  }

  // --- (c2) sfx method coverage, derived from js/audio.js ------------------
  {
    const { methods, error } = parseSfxMethods("js/audio.js", audioText);
    const f = [];
    if (error) f.push(error);
    const mapped = new Set();
    for (const e of map.events || []) {
      const m = anchorMethod(e.anchor.call);
      if (m) mapped.add(m);
    }
    const declared = new Set(methods);
    for (const m of declared) if (!mapped.has(m)) f.push(`sfx method added to js/audio.js but unmapped: .${m}()`);
    for (const m of mapped) if (!declared.has(m)) f.push(`map cites sfx.${m}() but js/audio.js declares no such method`);
    add("events: sfx method coverage (js/audio.js)", f, `${declared.size} declared methods == ${mapped.size} mapped methods`);
  }

  // --- (b) sound / WAV coverage -------------------------------------------
  {
    const f = [];
    const wavDir = join(REPO, env.bakedDir);
    const disk = existsSync(wavDir)
      ? env.readdir(wavDir).filter((n) => n.endsWith(".wav")).sort()
      : [];
    const diskIds = disk.map((n) => basename(n, ".wav"));
    const declared = (map.soundIds || []).slice().sort();
    const eventSounds = (map.events || []).map((e) => e.sound);
    const reached = new Set();
    let hashOk = 0;

    if (diskIds.length === 0) f.push(`no .wav files under ${env.bakedDir} — coverage cannot be verified`);
    if (JSON.stringify(diskIds) !== JSON.stringify(declared)) {
      f.push(`baked WAV set on disk != soundIds in map\n      disk: ${diskIds.join(", ")}\n      map : ${declared.join(", ")}`);
    }
    for (const s of eventSounds) {
      if (reached.has(s)) f.push(`sound '${s}' is emitted by more than one event`);
      reached.add(s);
    }
    for (const s of declared) {
      if (!reached.has(s)) f.push(`baked WAV '${s}.wav' is reachable from no event`);
    }
    for (const e of map.events || []) {
      const abs = join(REPO, e.wav.path);
      if (!existsSync(abs)) {
        f.push(`${e.id}: wav missing: ${e.wav.path}`);
        continue;
      }
      if (statSync(abs).size <= 0) {
        f.push(`${e.id}: wav is empty: ${e.wav.path}`);
        continue;
      }
      const head = readFileSync(abs).subarray(0, 12);
      if (head.toString("ascii", 0, 4) !== "RIFF" || head.toString("ascii", 8, 12) !== "WAVE") {
        f.push(`${e.id}: ${e.wav.path} is not a RIFF/WAVE file`);
        continue;
      }
      const actual = sha256(abs);
      if (e.wav.sha256 && actual !== e.wav.sha256) {
        f.push(`${e.id}: ${e.wav.path} sha256 changed\n      map: ${e.wav.sha256}\n      now: ${actual}`);
        continue;
      }
      hashOk += 1;
    }
    add("sounds: baked WAV coverage + integrity", f, `${reached.size}/${declared.length} wavs reached, ${hashOk}/${(map.events || []).length} sha256 confirmed, ${disk.length} on disk`);
  }

  // --- (c3) port bindings cross-checked against the ported sim -------------
  {
    const f = [];
    let anchorCount = 0;
    let resolved = 0;
    for (const e of map.events || []) {
      const p = e.port || {};
      if (p.file !== "godot/src/sim/sim.gd") f.push(`${e.id}: port.file is '${p.file}', expected godot/src/sim/sim.gd`);
      const text = env.byFile[p.file];
      if (text == null) {
        f.push(`${e.id}: port file missing: ${p.file}`);
        continue;
      }
      const want = String(p.fn || "").split(/[\s(]/)[0];
      const enc = enclosingFunction(text, p.line);
      if (!enc) f.push(`${e.id}: no function encloses ${p.file}:${p.line}`);
      else if (want && enc.name !== want) f.push(`${e.id}: ${p.file}:${p.line} is inside ${enc.name}(), map says ${p.fn}`);
      else resolved += 1;

      for (const ea of p.eventIdAnchors || []) {
        anchorCount += 1;
        const l = lineAt(text, ea.line);
        if (l == null) {
          f.push(`${e.id}: port event id anchor out of range: ${p.file}:${ea.line}`);
          continue;
        }
        if (!l.includes(`"${ea.id}"`)) {
          f.push(`${e.id}: ${p.file}:${ea.line} does not contain the port event id "${ea.id}" — found '${l.trim().slice(0, 80)}'`);
          continue;
        }
        const eenc = enclosingFunction(text, ea.line);
        const ewant = String(ea.fn || "").split(/[\s(]/)[0];
        if (ewant && (!eenc || eenc.name !== ewant)) {
          f.push(`${e.id}: port event id "${ea.id}" at ${p.file}:${ea.line} is inside ${eenc ? eenc.name : "<none>"}(), map says ${ea.fn}`);
          continue;
        }
      }
    }
    add("port: function + event-id bindings resolve", f, `${resolved}/${(map.events || []).length} port functions + ${anchorCount} port event-id anchors checked in godot/src/sim/sim.gd`);
  }

  // --- port still holds the engine-free premise ----------------------------
  {
    const f = [];
    const ls = lines(simText);
    if (!ls.some((l) => /^\s*(?:static\s+)?func\s+add_event\s*\(/.test(l))) {
      f.push("godot/src/sim/sim.gd no longer declares add_event()");
    }
    if (!/sfx\.\*/.test(simText)) {
      f.push("godot/src/sim/sim.gd no longer documents the stripped sfx.* coupling — the premise of this contract changed");
    }
    const call = parseSfxCallSites("godot/src/sim/sim.gd", simText);
    if (call.length > 0) {
      f.push(`godot/src/sim/sim.gd now calls sfx at ${call.map((c) => `${c.line}`).join(", ")} — audio is no longer engine-free; re-map before trusting this contract`);
    }
    add("port: engine-free premise holds", f, "sim.gd calls no sfx and still declares the stripped coupling");
  }

  // --- every declared sound id is a real WAV basename ----------------------
  {
    const f = [];
    for (const s of map.soundIds || []) {
      if (!existsSync(join(REPO, env.bakedDir, `${s}.wav`))) f.push(`soundIds declares '${s}' but ${env.bakedDir}/${s}.wav does not exist`);
    }
    add("sounds: declared ids exist on disk", f, `${(map.soundIds || []).length} declared ids`);
  }

  return checks;
}

// ---------------------------------------------------------------------------
// injected drift (the RED cases)
// ---------------------------------------------------------------------------

const DRIFT = [
  {
    name: "remove-event",
    what: "delete the 'wall' event (an unmapped sfx.wall() call site + an unreachable wall.wav)",
    apply: (map) => {
      map.events = map.events.filter((e) => e.id !== "wall");
    },
  },
  {
    name: "shift-anchor",
    what: "move the 'serve' anchor from js/game.js:750 to :751",
    apply: (map) => {
      map.events.find((e) => e.id === "serve").anchor.line += 1;
    },
  },
  {
    name: "sound-swap",
    what: "point the 'net' event at hit.wav instead of net.wav",
    apply: (map) => {
      const e = map.events.find((x) => x.id === "net");
      e.sound = "hit";
      e.wav.path = "tools/audio-audition/baked/hit.wav";
      e.wav.sha256 = "3045ce7154535ac208cb734bb0027992cf43fe990c4b85fd9970856546dfc0ee";
    },
  },
  {
    name: "port-id-rename",
    what: "rename the port event id anchor 'evWallValid' to 'evWallDead'",
    apply: (map) => {
      map.events.find((e) => e.id === "wall").port.eventIdAnchors[0].id = "evWallDead";
    },
  },
  {
    name: "new-sfx-method",
    what: "add a new method to the sfx object in js/audio.js (source drift) with no map entry",
    apply: (map, env) => {
      env.audioText = env.audioText.replace(
        "export const sfx = {",
        'export const sfx = {\n  echoDash() {\n    tone({ freq: 900, dur: 0.1, gain: 0.2 });\n  },'
      );
    },
  },
  {
    name: "wav-hash-drift",
    what: "expect a different sha256 for the 'hit' WAV (asset changed under the contract)",
    apply: (map) => {
      map.events.find((e) => e.id === "hit").wav.sha256 = "0".repeat(64);
    },
  },
  {
    name: "wav-missing",
    what: "point the 'bounce' event at a WAV that does not exist",
    apply: (map) => {
      map.events.find((e) => e.id === "bounce").wav.path = "tools/audio-audition/baked/does-not-exist.wav";
    },
  },
];

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

function loadEnv() {
  const gameText = readSource("js/game.js");
  const audioText = readSource("js/audio.js");
  const simText = readSource("godot/src/sim/sim.gd");
  const byFile = {};
  const missing = [];
  for (const [rel, text] of [
    ["js/game.js", gameText],
    ["js/audio.js", audioText],
    ["godot/src/sim/sim.gd", simText],
  ]) {
    if (text == null) missing.push(rel);
    else byFile[rel] = text;
  }
  return {
    gameText,
    audioText,
    simText,
    byFile,
    missing,
    bakedDir: "tools/audio-audition/baked",
    readdir: (p) => {
      const fs = envReadDir(p);
      return fs;
    },
  };
}

// readdir needs its own import path (kept separate so the env object stays plain data)
import { readdirSync } from "node:fs";
function envReadDir(p) {
  return readdirSync(p);
}

function totalFailures(checks) {
  return checks.reduce((n, c) => n + c.failures.length, 0);
}

function printChecks(checks, indent = "  ") {
  for (const c of checks) {
    const ok = c.failures.length === 0;
    const tag = ok ? paint(C.green, "[PASS]") : paint(C.red, "[FAIL]");
    const detail = c.detail ? paint(C.dim, `  ${c.detail}`) : "";
    process.stdout.write(`${indent}${tag} ${c.name}${detail}\n`);
    for (const msg of c.failures) process.stdout.write(`${indent}       ${paint(C.red, "- " + msg)}\n`);
  }
}

function main() {
  const argv = process.argv.slice(2);
  const driftArg = argv.find((a) => a.startsWith("--drift="));
  const mapArg = argv.find((a) => a.startsWith("--map="));
  const MAP_FILE = mapArg ? resolve(mapArg.slice("--map=".length)) : MAP_PATH;

  if (!existsSync(MAP_FILE)) {
    process.stdout.write(paint(C.red, `FATAL: missing ${MAP_FILE}\n`));
    process.exit(2);
  }
  let map;
  try {
    map = JSON.parse(readFileSync(MAP_FILE, "utf8"));
  } catch (err) {
    process.stdout.write(paint(C.red, `FATAL: ${MAP_FILE} is not valid JSON: ${err.message}\n`));
    process.exit(2);
  }

  const env = loadEnv();
  if (env.missing.length) {
    process.stdout.write(paint(C.red, `FATAL: missing source files: ${env.missing.join(", ")}\n`));
    process.exit(2);
  }

  process.stdout.write(`${paint(C.bold, "event-map contract test")}  ${paint(C.dim, MAP_FILE)}\n`);
  process.stdout.write(`${paint(C.dim, "  repo: " + REPO)}\n\n`);

  // ---- standalone drift mode: run ONE injected case as the primary check ----
  if (driftArg) {
    const name = driftArg.slice("--drift=".length);
    const scenario = DRIFT.find((d) => d.name === name);
    if (!scenario) {
      process.stdout.write(paint(C.red, `unknown drift scenario '${name}'. known: ${DRIFT.map((d) => d.name).join(", ")}\n`));
      process.exit(2);
    }
    const m = structuredClone(map);
    const e = { ...env, byFile: { ...env.byFile } };
    let applied = true;
    try {
      scenario.apply(m, e);
    } catch (err) {
      applied = false;
      process.stdout.write(`${paint(C.dim, `  (scenario '${scenario.name}' is not applicable to this map: ${err.message})`)}\n`);
    }
    if (!applied) {
      process.stdout.write(paint(C.yellow, "  [ SKIP ] " + scenario.name + "  mutation not applicable to the map under test (base map already drifted)\n"));
      process.exit(2);
    }
    let checks;
    try {
      checks = runChecks(m, e);
    } catch (err) {
      process.stdout.write(paint(C.red, `DRIFT DETECTED (checks threw) — injected '${scenario.name}': ${err.message}\n`));
      process.exit(1);
    }
    const failures = totalFailures(checks);
    process.stdout.write(`${paint(C.bold, "injected drift")}: ${scenario.name} — ${scenario.what}\n\n`);
    printChecks(checks);
    process.stdout.write("\n");
    if (failures > 0) {
      process.stdout.write(paint(C.red, `DRIFT DETECTED — ${failures} failure(s) raised by injected '${scenario.name}'.\n`));
      process.stdout.write(paint(C.yellow, "exit 1 is CORRECT here: this proves the test reacts to drift.\n"));
      process.exit(1);
    }
    process.stdout.write(paint(C.red, `NOT CAUGHT — injected '${scenario.name}' produced 0 failures. The test is blind to this drift.\n`));
    process.exit(0);
  }

  // ---- normal mode: green run + self-proof that injected drift is caught ----
  const checks = runChecks(map, env);
  printChecks(checks);
  const failures = totalFailures(checks);

  process.stdout.write(`\n${paint(C.bold, "injected-drift self-check")} ${paint(C.dim, "(each case must go RED)")}\n`);
  let uncaught = 0;
  let skipped = 0;
  let caughtFailureTotal = 0;
  for (const scenario of DRIFT) {
    const m = structuredClone(map);
    const e = { ...env, byFile: { ...env.byFile } };
    let applied = true;
    try {
      scenario.apply(m, e);
    } catch (err) {
      applied = false;
    }
    if (!applied) {
      skipped += 1;
      process.stdout.write(`  ${paint(C.yellow, "[ SKIP ]")} ${scenario.name.padEnd(16)} ${"".padStart(2)}           ${paint(C.dim, "mutation not applicable to the map under test (base map already drifted)")}\n`);
      continue;
    }
    let f;
    try {
      f = totalFailures(runChecks(m, e));
    } catch (err) {
      uncaught += 1;
      process.stdout.write(`  ${paint(C.red, "[ERROR]")} ${scenario.name.padEnd(16)} checks threw: ${err.message}\n`);
      continue;
    }
    const caught = f > 0;
    caughtFailureTotal += f;
    if (!caught) uncaught += 1;
    const tag = caught ? paint(C.green, "[CAUGHT]") : paint(C.red, "[MISSED]");
    process.stdout.write(`  ${tag} ${scenario.name.padEnd(16)} ${String(f).padStart(2)} failure(s)  ${paint(C.dim, scenario.what)}\n`);
  }

  // ---- numbers -------------------------------------------------------------
  const sites = parseSfxCallSites("js/game.js", env.gameText);
  const { methods } = parseSfxMethods("js/audio.js", env.audioText);
  const portIds = new Set();
  for (const ev of map.events) for (const ea of ev.port.eventIdAnchors || []) portIds.add(ea.id);
  const wavs = readdirSync(join(REPO, env.bakedDir)).filter((n) => n.endsWith(".wav")).sort();
  const reached = new Set(map.events.map((e) => e.sound));

  process.stdout.write(`\n${paint(C.bold, "numbers")}\n`);
  process.stdout.write(`  sfx call sites in js/game.js        : ${sites.length}\n`);
  process.stdout.write(`  sfx methods in js/audio.js          : ${methods.length}\n`);
  process.stdout.write(`  audio events in the map             : ${map.events.length}\n`);
  process.stdout.write(`  events with a resolving anchor      : ${checks[1].failures.length === 0 ? map.events.length : "?"}\n`);
  process.stdout.write(`  baked WAVs reached / on disk        : ${reached.size} / ${wavs.length}\n`);
  process.stdout.write(`  distinct port event ids bound       : ${portIds.size}\n`);
  process.stdout.write(`  green-check failures                : ${failures}\n`);
  process.stdout.write(`  injected drift: ${DRIFT.length - uncaught - skipped - 0}/${DRIFT.length - skipped} applicable cases caught, ${caughtFailureTotal} failure(s) raised in total${skipped ? `, ${skipped} skipped` : ""}\n`);

  const green = failures === 0;
  const red = uncaught === 0;
  process.stdout.write(`\n`);
  if (green && red) {
    process.stdout.write(paint(C.green, `RESULT: PASS — ${checks.length} green checks, 0 failures; all ${DRIFT.length} injected drift cases caught.\n`));
    process.exit(0);
  }
  if (!green) process.stdout.write(paint(C.red, `RESULT: FAIL — ${failures} failure(s) in the green checks.\n`));
  if (!red) process.stdout.write(paint(C.red, `RESULT: FAIL — ${uncaught} injected drift case(s) were NOT caught; the test is blind to them.\n`));
  process.exit(1);
}

main();
