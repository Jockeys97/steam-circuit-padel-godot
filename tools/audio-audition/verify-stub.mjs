#!/usr/bin/env node
/**
 * verify-stub.mjs — executable audit of the audio-port catalogue (Node, no browser).
 *
 * What it proves, in order:
 *   A. The catalogue still matches js/audio.js: every `synth` line range still
 *      contains the numbers the catalogue claims, the trigger line still holds
 *      the cited call, the suppression line still holds the mute guard.
 *   B. Coverage: the catalogue covers exactly the sfx methods js/audio.js exports
 *      and nothing else.
 *   C. Behaviour: with the WebAudio API stubbed, every catalogued sound's
 *      parameters actually reach the API — type / start freq / end freq / start
 *      time / duration / peak gain / noise filter type+frequency, per event.
 *   D. Mixer + mute: master 0.5 default, setVolume reaches the master AudioParam,
 *      setMuted(true) suppresses every event.
 *   E. No file-based audio exists in the game (the catalogue's premise) — no
 *      audio file under assets/, no `new Audio(`, no `<audio>` in js/ or index.html.
 *
 * Run:  node tools/audio-audition/verify-stub.mjs
 * Exit: 0 all checks pass, 1 otherwise. js/audio.js is read-only and unmodified.
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import {
  SFX,
  MUSIC,
  MIXER,
  CATALOGUE,
  bpmForIntensity,
  activeVoices,
  SFX_MODULE,
} from "./audition-core.js";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..");

/* ------------------------------------------------------------------ report */

const results = [];
function check(name, fn) {
  try {
    const detail = fn();
    results.push({ ok: true, name, detail });
    console.log(`  PASS  ${name}${detail ? ` — ${detail}` : ""}`);
  } catch (err) {
    results.push({ ok: false, name, detail: err.message });
    console.log(`  FAIL  ${name} — ${err.message}`);
  }
}
function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}
const r6 = (n) => Math.round(n * 1e6) / 1e6;

/* -------------------------------------------------------------- source read */

const SRC = {};
function lines(rel) {
  if (!SRC[rel]) SRC[rel] = readFileSync(path.join(ROOT, rel), "utf8").split("\n");
  return SRC[rel];
}
function lineAt(rel, n) {
  const ls = lines(rel);
  assert(n >= 1 && n <= ls.length, `${rel}:${n} is outside the file (1..${ls.length})`);
  return ls[n - 1];
}
function range(rel, from, to) {
  const ls = lines(rel);
  assert(to <= ls.length, `${rel}:${from}-${to} runs past the file (${ls.length} lines)`);
  return ls.slice(from - 1, to).join("\n");
}
/** "js/audio.js:61-64" | "js/audio.js:229-233 (mTone, js/audio.js:155-180)" -> refs */
function parseRefs(text) {
  return [...String(text).matchAll(/([\w./-]+\.(?:js|html)):(\d+)(?:-(\d+))?/g)].map((m) => ({
    file: m[1],
    from: Number(m[2]),
    to: m[3] ? Number(m[3]) : Number(m[2]),
    raw: m[0],
  }));
}
/** Every number literal in the catalogue's `expect` for one sound. */
function expectNumbers(entry) {
  const out = new Set();
  const push = (v) => {
    if (typeof v === "number") out.add(String(v));
  };
  for (const t of entry.expect.tones) {
    push(t.freq);
    push(t.freqEnd);
    push(t.dur);
    push(t.gain);
  }
  for (const n of entry.expect.noise) {
    push(n.filterFreq);
    push(n.dur);
    push(n.gain);
  }
  return [...out];
}

/* ------------------------------------------------------- A. anchor integrity */

console.log("\nA. source anchors (audition-core.js -> js/, read-only)");

check("catalogue covers the file it cites", () => {
  const ls = lines(SFX_MODULE);
  // 292 newlines => 293 array slots (last empty). Header says 292 lines.
  const body = ls[ls.length - 1] === "" ? ls.length - 1 : ls.length;
  assert(body >= 292, `${SFX_MODULE} shrank to ${body} lines`);
  return `${SFX_MODULE} = ${body} lines`;
});

for (const entry of SFX) {
  check(`anchors: ${entry.id} (${entry.synth})`, () => {
    const refs = parseRefs(entry.synth);
    assert(refs.length === 1, `expected 1 synth anchor, got ${refs.length}`);
    const { file, from, to } = refs[0];
    const text = range(file, from, to);
    // The method head is a separate anchor: `point` synthesises two catalogue
    // rows from one 7-line method, so a row's own range need not hold the head.
    const headRefs = parseRefs(entry.head);
    assert(headRefs.length === 1, `expected 1 head anchor for ${entry.id}, got ${headRefs.length}`);
    const method = entry.id.startsWith("point")
      ? "point"
      : entry.id.startsWith("victory")
        ? "victoryMatch"
        : entry.id.startsWith("defeat")
          ? "defeatMatch"
          : entry.id;
    const headLine = lineAt(headRefs[0].file, headRefs[0].from);
    assert(
      headLine.includes(`${method}(`),
      `${entry.head} = ${headLine.trim()} — does not contain the method head ${method}(`,
    );
    const nums = expectNumbers(entry);
    const missing = nums.filter((n) => !text.includes(n));
    assert(missing.length === 0, `catalogue numbers not found in ${entry.synth}: ${missing.join(", ")}`);
    for (const t of entry.expect.tones) {
      assert(text.includes(`"${t.type}"`), `oscillator type "${t.type}" not in ${entry.synth}`);
    }
    // noise() declares the filter type once for every noise-based sound
    // (js/audio.js:48-50); each caller only passes the frequency.
    const noiseHelper = range(file, 48, 50);
    for (const n of entry.expect.noise) {
      assert(
        text.includes(`"${n.filterType}"`) || noiseHelper.includes(`"${n.filterType}"`),
        `filter type "${n.filterType}" in neither ${entry.synth} nor the noise() helper (js/audio.js:48-50)`,
      );
    }
    return `${nums.length} numbers + ${entry.expect.tones.length} tone / ${entry.expect.noise.length} noise verified in ${entry.synth}, head at ${entry.head}`;
  });

  check(`trigger: ${entry.id} (${entry.trigger.split(" — ")[0]})`, () => {
    const refs = parseRefs(entry.trigger);
    assert(refs.length >= 1, "no trigger anchor");
    const first = refs[0];
    const text = lineAt(first.file, first.from);
    const call = entry.id.startsWith("point")
      ? "sfx.point("
      : entry.id.startsWith("victory")
        ? "sfx.victoryMatch("
        : entry.id.startsWith("defeat")
          ? "sfx.defeatMatch("
          : `sfx.${entry.id}(`;
    assert(text.includes(call), `${first.raw} = ${text.trim()} — expected ${call}`);
    return `${first.raw} calls ${call}`;
  });

  check(`suppression: ${entry.id} (${entry.suppression.match(/js\/audio\.js:\d+/)?.[0] ?? "?"})`, () => {
    const refs = parseRefs(entry.suppression);
    assert(refs.length >= 1, "no suppression anchor");
    for (const ref of refs) {
      const text = lineAt(ref.file, ref.from);
      assert(text.includes("_muted"), `${ref.raw} = ${text.trim()} — expected the _muted guard`);
    }
    return refs.map((r) => r.raw).join(", ") + " hold the _muted guard";
  });
}

check("music: start/stop anchors", () => {
  const text = range("js/main.js", 1158, 1159);
  assert(text.includes("music.setIntensity(0.12)") && text.includes("music.start()"), "startMatch anchors moved");
  assert(lineAt("js/main.js", 1385).includes("music.stop()"), "js/main.js:1385 is not music.stop()");
  assert(lineAt("js/main.js", 1553).includes("music.stop()"), "js/main.js:1553 is not music.stop()");
  const paused = range("js/main.js", 1530, 1545);
  assert(!paused.includes("music.stop()"), "pauseGame now stops the music — catalogue says it does not");
  return "startMatch starts it, endMatch/quitMatch stop it, pauseGame does not";
});

check("music: intensity driver", () => {
  const text = range("js/main.js", 1220, 1226);
  assert(text.includes("rallyTension") && text.includes("0.12 + rallyTension * 0.55"), "intensity formula moved");
  assert(text.includes("sets.player + matchState.sets.ai"), "stakes formula moved");
  return "js/main.js:1220-1226 still min(1, 0.12 + rallyHits/12 * 0.55 + stakes)";
});

check("music: tempo table", () => {
  const text = lineAt(SFX_MODULE, 267);
  assert(text.includes("60 / (96 + music.intensity * 54)"), `js/audio.js:267 = ${text.trim()}`);
  const got = [0, 0.5, 1].map((i) => bpmForIntensity(i));
  assert(got[0] === 96 && got[2] === 150, `bpmForIntensity gives ${got.join(", ")}`);
  return "js/audio.js:267 == bpmForIntensity() -> " + got.join(" / ") + " BPM at intensity 0 / 0.5 / 1";
});

check("music: gates", () => {
  // Line numbers point at the gate itself, not at the voice it wraps.
  const gates = { bassOffbeat: 229, bass: 231, arp: 241, drums: 254, hat: 256 };
  const expect = {
    bassOffbeat: "s % 4 === 0",
    bass: "inten > 0.6",
    arp: "inten > 0.4",
    drums: "inten > 0.72",
    hat: "mHat(time, 0.02 + (inten - 0.72) * 0.1)",
  };
  for (const [k, ln] of Object.entries(gates)) {
    const text = lineAt(SFX_MODULE, ln);
    assert(text.includes(expect[k]), `js/audio.js:${ln} = ${text.trim()} — expected "${expect[k]}"`);
  }
  assert(MUSIC.gates.arp === 0.4 && MUSIC.gates.bassOffbeat === 0.6 && MUSIC.gates.drums === 0.72, "MUSIC.gates drifted");
  const on = activeVoices(0.9);
  assert(on["music-kick"] === "on" && on["music-arp"] === "on", "activeVoices(0.9) wrong");
  assert(activeVoices(0.2)["music-kick"] === "off", "activeVoices(0.2) wrong");
  const off = Object.entries(activeVoices(0.2)).filter(([, v]) => v === "off").map(([k]) => k);
  return `4 gates hold; intensity 0.2 leaves ${off.join(", ")} off`;
});

check("music: buses + persistence anchors", () => {
  assert(lineAt(SFX_MODULE, 149).includes("music._gain.gain.value = 0.55"), "music bus gain moved");
  assert(lineAt(SFX_MODULE, 5).includes("_volume: 0.5"), "master default volume moved");
  assert(lineAt(SFX_MODULE, 15).includes("audio._master.gain.value = audio._volume"), "master gain write moved");
  assert(lineAt("js/main.js", 2199).includes("prefs.muted"), "mute restore anchor moved");
  assert(lineAt("js/main.js", 2213).includes("prefs.volume"), "volume restore anchor moved");
  assert(lineAt("js/main.js", 2484).includes("pointerdown"), "first-gesture unlock anchor moved");
  const busses = MIXER.map((m) => `${m.id}=${m.value} (${m.db.toFixed(2)} dB)`);
  return busses.join(", ");
});

/* ---------------------------------------------------------- B. coverage */

console.log("\nB. coverage");

check("catalogue == the methods js/audio.js exports", () => {
  const body = range(SFX_MODULE, 60, 104);
  const methods = [...body.matchAll(/^ {2}([a-zA-Z]\w*)\(/gm)].map((m) => m[1]);
  const expected = ["hit", "bounce", "wall", "net", "serve", "special", "point", "victoryMatch", "defeatMatch"];
  assert(
    JSON.stringify(methods) === JSON.stringify(expected),
    `js/audio.js sfx methods are [${methods.join(", ")}], catalogue expects [${expected.join(", ")}]`,
  );
  assert(SFX.length === 10, `catalogue has ${SFX.length} one-shots, expected 10 (point splits in two)`);
  assert(MUSIC.voices.length === 5, `catalogue has ${MUSIC.voices.length} music voices, expected 5`);
  assert(CATALOGUE.length === 15, `catalogue has ${CATALOGUE.length} rows, expected 15`);
  const ids = new Set(CATALOGUE.map((r) => r.id));
  assert(ids.size === CATALOGUE.length, "duplicate catalogue ids");
  return "9 exported sfx methods -> 10 one-shots + 5 music voices = 15 rows";
});

/* -------------------------------------------------- C/D. stubbed behaviour */

const clock = { now: 0 };
const LIVE = { oscs: [], gains: [], filters: [], sources: [] };
/** The master gain of the single lazily-built context; survives reset(). */
let FIRST_GAIN = null;

class FakeParam {
  constructor(v) {
    this.value = v;
    this._ev = [];
  }
  setValueAtTime(v, t) {
    this._ev.push(["set", v, t]);
    return this;
  }
  exponentialRampToValueAtTime(v, t) {
    this._ev.push(["exp", v, t]);
    return this;
  }
  linearRampToValueAtTime(v, t) {
    this._ev.push(["lin", v, t]);
    return this;
  }
  setTargetAtTime() {
    return this;
  }
}
class FakeGain {
  constructor() {
    this.gain = new FakeParam(1);
    this._target = null;
  }
  connect(d) {
    this._target = d;
    return d;
  }
  disconnect() {}
}
class FakeOsc {
  constructor() {
    this.type = "sine";
    this.frequency = new FakeParam(0);
    this._start = null;
    this._stop = null;
    this._target = null;
  }
  connect(d) {
    this._target = d;
    return d;
  }
  start(t) {
    this._start = t;
  }
  stop(t) {
    this._stop = t;
  }
}
class FakeFilter {
  constructor() {
    this.type = "lowpass";
    this.frequency = new FakeParam(350);
    this._target = null;
  }
  connect(d) {
    this._target = d;
    return d;
  }
}
class FakeBuffer {
  constructor(ch, len, sr) {
    this.length = len;
    this.sampleRate = sr;
    this._d = new Float32Array(len);
  }
  getChannelData() {
    return this._d;
  }
}
class FakeBufferSource {
  constructor() {
    this.buffer = null;
    this._start = null;
    this._target = null;
  }
  connect(d) {
    this._target = d;
    return d;
  }
  start(t) {
    this._start = t;
  }
}
class FakeAudioContext {
  constructor() {
    this.sampleRate = 44100;
    this.state = "running";
    this.destination = { __destination: true };
  }
  get currentTime() {
    return clock.now;
  }
  resume() {
    this.state = "running";
    return Promise.resolve();
  }
  createGain() {
    const g = new FakeGain();
    // js/audio.js:14 creates the master gain first, when the context is built;
    // the music bus (js/audio.js:148) comes later. Keep it across reset().
    if (!FIRST_GAIN) FIRST_GAIN = g;
    LIVE.gains.push(g);
    return g;
  }
  createOscillator() {
    const o = new FakeOsc();
    LIVE.oscs.push(o);
    return o;
  }
  createBiquadFilter() {
    const f = new FakeFilter();
    LIVE.filters.push(f);
    return f;
  }
  createBuffer(ch, len, sr) {
    return new FakeBuffer(ch, len, sr);
  }
  createBufferSource() {
    const s = new FakeBufferSource();
    LIVE.sources.push(s);
    return s;
  }
}

globalThis.window = { AudioContext: FakeAudioContext };
// js/audio.js staggers point/victory/defeat notes with setTimeout. The real API
// schedules each timer against the *registration* moment, so a 3-note arpeggio
// registered in one synchronous burst fires at 0 / 0.1 / 0.2 s — not at a
// cumulative 0 / 0.1 / 0.3. Model that with a time-ordered queue and flush it
// after a sound is played, so `at` is measured, not assumed.
const timers = [];
globalThis.setTimeout = (fn, ms = 0) => {
  timers.push({ at: clock.now + ms / 1000, fn });
  return timers.length;
};
function flushTimers() {
  while (timers.length) {
    timers.sort((a, b) => a.at - b.at);
    const next = timers.shift();
    clock.now = next.at;
    next.fn();
  }
}
globalThis.setInterval = () => 1;
globalThis.clearInterval = () => {};

function reset() {
  clock.now = 0;
  timers.length = 0;
  for (const k of Object.keys(LIVE)) LIVE[k].length = 0;
}

/** Read the live events back out of the stubbed API into catalogue shape. */
function readEvents() {
  const tones = LIVE.oscs
    .filter((o) => o._start !== null)
    .map((o) => {
      const g = o._target;
      const ev = g && g.gain ? g.gain._ev : [];
      const freqSet = o.frequency._ev.find((e) => e[0] === "set");
      const freqRamp = o.frequency._ev.find((e) => e[0] === "exp");
      const peak = ev[1] && ev[1][0] === "exp" ? ev[1][1] : ev[0] ? ev[0][1] : null;
      const t0 = ev[0] ? ev[0][2] : o._start;
      const tEnd = ev.length ? ev[ev.length - 1][2] : o._start;
      return {
        type: o.type,
        freq: freqSet ? r6(freqSet[1]) : null,
        freqEnd: freqRamp ? r6(freqRamp[1]) : null,
        at: r6(o._start),
        dur: r6(tEnd - t0),
        gain: peak === null ? null : r6(peak),
      };
    });
  const noise = LIVE.sources
    .filter((s) => s._start !== null && s.buffer)
    .map((s) => {
      const filt = s._target;
      const g = filt ? filt._target : null;
      const ev = g && g.gain ? g.gain._ev : [];
      const t0 = ev[0] ? ev[0][2] : s._start;
      const tEnd = ev.length ? ev[ev.length - 1][2] : s._start;
      return {
        filterType: filt ? filt.type : null,
        filterFreq: filt ? r6(filt.frequency.value) : null,
        dur: r6(tEnd - t0),
        gain: ev[0] ? r6(ev[0][1]) : null,
        bufDur: r6(s.buffer.length / s.buffer.sampleRate),
      };
    });
  return { tones, noise };
}

function diff(exp, got, label) {
  const errs = [];
  if (exp.length !== got.length) errs.push(`${label}: expected ${exp.length} event(s), the API received ${got.length}`);
  exp.forEach((e, i) => {
    const g = got[i];
    if (!g) return;
    for (const k of Object.keys(e)) {
      if (g[k] !== e[k]) errs.push(`${label}[${i}].${k}: catalogue ${JSON.stringify(e[k])} vs API ${JSON.stringify(g[k])}`);
    }
  });
  return errs;
}

const audioModule = await import(
  new URL(`../../${SFX_MODULE}`, import.meta.url).href
);

console.log("\nC. parameters reach the WebAudio API (stubbed)");

for (const entry of SFX) {
  check(`API events: ${entry.id}`, () => {
    reset();
    audioModule.setMuted(false);
    entry.play(audioModule);
    flushTimers();
    const { tones, noise } = readEvents();
    const errs = [...diff(entry.expect.tones, tones, "tones"), ...diff(entry.expect.noise, noise, "noise")];
    assert(errs.length === 0, errs.join(" | "));
    const detail = [
      ...tones.map((t) => `${t.type} ${t.freq}${t.freqEnd ? "→" + t.freqEnd : ""}Hz @${t.at}s ${t.dur}s g${t.gain}`),
      ...noise.map((n) => `${n.filterType} ${n.filterFreq}Hz ${n.dur}s g${n.gain}`),
    ];
    return detail.join(" + ");
  });
}

check("noise buffers are as long as their dur", () => {
  reset();
  audioModule.sfx.wall();
  const { noise } = readEvents();
  assert(noise.length === 1, `expected 1 noise event, got ${noise.length}`);
  assert(Math.abs(noise[0].bufDur - 0.16) < 1e-6, `buffer is ${noise[0].bufDur}s, expected 0.16s`);
  return `0.16 s == ${noise[0].bufDur} s buffer @ 44100 Hz (${Math.round(0.16 * 44100)} samples)`;
});

check("special() is additive over hit(), not a replacement", () => {
  reset();
  audioModule.sfx.special();
  flushTimers();
  const special = readEvents();
  reset();
  audioModule.sfx.hit();
  flushTimers();
  const hit = readEvents();
  assert(hit.tones.length === 1 && hit.noise.length === 1, "hit() shape changed");
  assert(special.tones.length === 2 && special.noise.length === 1, "special() shape changed");
  return `special = ${special.tones.length} tones + ${special.noise.length} noise, hit = ${hit.tones.length} + ${hit.noise.length}; game.js:1893 and :1898 both fire on a special`;
});

console.log("\nD. mixer, mute, volume");

check("master default 0.5, setVolume reaches the AudioParam", () => {
  reset();
  const mod = audioModule;
  mod.initAudio();
  assert(mod.getVolume() === 0.5, `getVolume() = ${mod.getVolume()}, expected 0.5`);
  const master = FIRST_GAIN;
  assert(master, "no gain was ever created — the context was never built");
  assert(master.gain.value === 0.5, `master gain = ${master.gain.value}, expected 0.5`);
  mod.setVolume(0.73);
  assert(master.gain.value === 0.73, `master gain = ${master.gain.value} after setVolume(0.73)`);
  mod.setVolume(2); // clamped
  assert(master.gain.value === 1, `setVolume(2) gave ${master.gain.value}, expected clamp to 1`);
  mod.setVolume(0.5);
  return "0.5 default, 0.73 applied, >1 clamped to 1 (js/audio.js:286-289)";
});

check("setMuted(true) suppresses every catalogued sound", () => {
  audioModule.setMuted(true);
  const silent = [];
  for (const entry of SFX) {
    reset();
    entry.play(audioModule);
    flushTimers();
    const { tones, noise } = readEvents();
    if (tones.length || noise.length) silent.push(entry.id);
  }
  assert(audioModule.isMuted() === true, "isMuted() is false while muted");
  assert(silent.length === 0, `still audible while muted: ${silent.join(", ")}`);
  audioModule.setMuted(false);
  reset();
  audioModule.sfx.hit();
  assert(readEvents().tones.length === 1, "unmute did not restore audio");
  return `${SFX.length}/${SFX.length} one-shots emit zero API events while muted, and resume after unmute`;
});

check("first-gesture gate: no AudioContext before initAudio()", () => {
  // js/audio.js builds its context lazily; a fresh module instance has _ctx null.
  assert(typeof audioModule.initAudio === "function", "initAudio is not exported");
  // 2484 is addEventListener's *reference* to initAudio (no parens), the other
  // five are direct calls on the first gamepad/pointer/key gesture.
  const calls = [2506, 875, 916, 984, 2192].map((n) => lineAt("js/main.js", n));
  const refs = lineAt("js/main.js", 2484);
  assert(refs.includes("initAudio"), `js/main.js:2484 no longer references initAudio`);
  const hits = calls.join("\n").match(/initAudio\(\)/g) || [];
  assert(hits.length === 5, `expected 5 initAudio() call sites, found ${hits.length}`);
  return `5 initAudio() calls + 1 pointerdown reference (js/main.js:875, 916, 984, 2192, 2506, 2484) — the browser holds the context suspended until the first gesture`;
});

/* ------------------------------------------------- E. no file-based audio */

console.log("\nE. no file-based audio in the game");

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === ".git") continue;
    const p = path.join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

check("zero audio files under assets/", () => {
  const files = walk(path.join(ROOT, "assets"));
  const audio = files.filter((f) => /\.(mp3|ogg|wav|m4a|flac|aac|opus|webm)$/i.test(f));
  assert(audio.length === 0, `found audio files: ${audio.join(", ")}`);
  return `${files.length} files under assets/, 0 with an audio extension`;
});

check("no <audio>/new Audio() in the shipped sources", () => {
  const suspects = [];
  for (const f of walk(path.join(ROOT, "js"))) {
    const t = readFileSync(f, "utf8");
    if (/\bnew Audio\s*\(|<audio[\s>]/i.test(t)) suspects.push(path.relative(ROOT, f));
  }
  const html = readFileSync(path.join(ROOT, "index.html"), "utf8");
  const htmlAudio = /<audio[\s>]|\.mp3|\.ogg|\.wav|\.m4a/i.test(html) ? ["index.html"] : [];
  const all = [...suspects, ...htmlAudio];
  assert(all.length === 0, `file-based audio referenced in: ${all.join(", ")}`);
  return "every sample in the game is generated by js/audio.js at play time";
});

/* ------------------------------------------------------------------- verdict */

const failed = results.filter((r) => !r.ok);
console.log(
  `\n${results.length - failed.length}/${results.length} checks passed` +
    (failed.length ? ` — FAILED: ${failed.map((f) => f.name).join(", ")}` : " — catalogue matches js/audio.js and every sound reaches the API"),
);
process.exit(failed.length ? 1 : 0);
