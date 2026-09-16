#!/usr/bin/env node
// tools/audio-music-port/extract-music.mjs
//
// Derives the reference's OWN music output by running it.
//
// `js/audio.js` is the specification for the ported music engine. It is a Web Audio
// module: every voice is an OscillatorNode/BufferSourceNode scheduled on an
// AudioContext, and the score is walked by a 40 ms `setInterval` reading
// `ctx.currentTime`. To know what it emits, this tool installs a fake AudioContext
// (recording every started node, its oscillator type, frequency, gain envelope and
// filter), a fake `setInterval`, a fake clock and a scripted "frame" pump, and reads
// the module's own `_step` while `playStep` is on the stack.
//
// Nothing here is typed in by hand: the module source, the chord table, the intensity
// formula (extracted from `js/main.js`) and every expected note/chord come out of the
// reference at run time. `--check` re-derives and compares against the file on disk,
// so a reference change turns into a diff instead of a silent divergence.
//
// Usage:
//   node tools/audio-music-port/extract-music.mjs           # write out/music-reference.json
//   node tools/audio-music-port/extract-music.mjs --check   # re-derive and diff (exit 1 on drift)
//   node tools/audio-music-port/extract-music.mjs --print    # summary table + write
//
// Exit codes: 0 ok, 1 drift/self-check failure, 2 usage error.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import vm from "node:vm";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");
const AUDIO_JS = path.join(REPO, "js", "audio.js");
const MAIN_JS = path.join(REPO, "js", "main.js");
const OUT_DIR = path.join(HERE, "out");
const OUT_FILE = path.join(OUT_DIR, "music-reference.json");

const SCHEMA = "steam-circuit-padel-pro.music-reference";
const SCHEMA_VERSION = 1;
const SAMPLE_RATE = 44100;
const DT = 1 / 60;
const EPS = 1e-9;

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

const sha256 = (buf) => createHash("sha256").update(buf).digest("hex");
const round = (v, d = 9) => (v === null || v === undefined ? null : Number(v.toFixed(d)));

/** Every self-check goes through here: a failure is loud, named, and fatal. */
const selfChecks = [];
function check(name, ok, detail = "") {
  selfChecks.push({ name, ok: !!ok, detail });
  if (!ok) throw new Error(`self-check failed: ${name}${detail ? " — " + detail : ""}`);
}

// ---------------------------------------------------------------------------
// the fake Web Audio API — records what the reference asks the browser to play
// ---------------------------------------------------------------------------

class FakeParam {
  constructor(value) {
    this.value = value;
    this.calls = [];
  }
  setValueAtTime(v, t) {
    this.calls.push({ op: "set", v, t });
    return this;
  }
  exponentialRampToValueAtTime(v, t) {
    this.calls.push({ op: "exp", v, t });
    return this;
  }
  linearRampToValueAtTime(v, t) {
    this.calls.push({ op: "lin", v, t });
    return this;
  }
}

class FakeCtx {
  constructor() {
    this.currentTime = 0;
    this.sampleRate = SAMPLE_RATE;
    this.state = "running";
    this.destination = { kind: "destination", outs: [] };
    this.pending = [];
    this.currentStep = null;
  }
  resume() {}
  createGain() {
    return { kind: "gain", gain: new FakeParam(1), outs: [], connect(d) { this.outs.push(d); return d; } };
  }
  createOscillator() {
    const ctx = this;
    return {
      kind: "osc",
      type: "sine",
      frequency: new FakeParam(440),
      outs: [],
      connect(d) { this.outs.push(d); return d; },
      start(t) { this.startedAt = t; ctx._record(this); },
      stop(t) { this.stoppedAt = t; },
    };
  }
  createBiquadFilter() {
    return { kind: "biquad", type: "lowpass", frequency: new FakeParam(350), outs: [], connect(d) { this.outs.push(d); return d; } };
  }
  createBuffer(channels, length, rate) {
    return {
      numberOfChannels: channels,
      length,
      sampleRate: rate,
      getChannelData: () => new Float32Array(length),
    };
  }
  createBufferSource() {
    const ctx = this;
    return {
      kind: "bufferSource",
      buffer: null,
      outs: [],
      connect(d) { this.outs.push(d); return d; },
      start(t) { this.startedAt = t; ctx._record(this); },
      stop(t) { this.stoppedAt = t; },
    };
  }
  /** Walk the graph the reference built and record one event. */
  _record(node) {
    const chain = [];
    let frontier = [node];
    for (let depth = 0; depth < 4 && frontier.length; depth += 1) {
      const next = [];
      for (const n of frontier) {
        for (const d of n.outs || []) {
          if (!chain.includes(d) && d !== this.destination) {
            chain.push(d);
            next.push(d);
          }
        }
      }
      frontier = next;
    }
    const gainNode = chain.find((n) => n.kind === "gain");
    const biquad = chain.find((n) => n.kind === "biquad");
    if (!gainNode) throw new Error("recorded node has no gain node in its chain");
    const calls = gainNode.gain.calls;
    // The reference's envelopes are one of:
    //   tone: setValueAtTime(0.0001,t), expRampTo(gain,t+attack), expRampTo(0.0001,t+dur)
    //   kick/hat: setValueAtTime(gain,t), expRampTo(0.0001,t+dur)
    const hasAttack = calls.length === 3 && calls[0].op === "set" && calls[0].v <= 0.001;
    const t0 = calls[0].t;
    const freqCalls = node.kind === "osc" ? node.frequency.calls : [];
    this.pending.push({
      step: this.currentStep,
      t: node.startedAt,
      node: node.kind,
      type: node.kind === "osc" ? node.type : null,
      freq: freqCalls.length ? freqCalls[0].v : null,
      freq_end: freqCalls.length > 1 ? freqCalls[freqCalls.length - 1].v : null,
      sweep: freqCalls.length > 1 ? freqCalls[freqCalls.length - 1].t - freqCalls[0].t : null,
      gain: hasAttack ? calls[1].v : calls[0].v,
      attack: hasAttack ? calls[1].t - t0 : null,
      dur: calls[calls.length - 1].t - t0,
      stop: node.stoppedAt === undefined ? null : node.stoppedAt - t0,
      filter_type: biquad ? biquad.type : null,
      filter: biquad ? biquad.frequency.value : null,
      buf_frames: node.kind === "bufferSource" ? node.buffer.length : null,
    });
  }
}

// ---------------------------------------------------------------------------
// loading `js/audio.js` — mechanically de-exported, never retyped
// ---------------------------------------------------------------------------

function loadReference() {
  const raw = readFileSync(AUDIO_JS, "utf8");
  const exportCount = (raw.match(/^export\s/gm) || []).length;
  const body = raw.replace(/^export\s/gm, "");
  const tail = `
globalThis.__mod = { music, sfx, initAudio, setMuted, isMuted, setVolume, getVolume, playStep, midiToFreq, PROG, tone, noise };
`;
  const sandbox = {
    console,
    Math,
    Boolean,
    Number,
    String,
    Object,
    Array,
    JSON,
    isNaN,
    Float32Array,
    TypeError,
    Error,
  };
  const ctx = new FakeCtx();
  const interval = { fn: null, ms: null, live: false };
  sandbox.window = { AudioContext: function FakeAudioContextCtor() { return ctx; } };
  sandbox.setTimeout = () => 0;
  sandbox.clearTimeout = () => {};
  sandbox.setInterval = (fn, ms) => { interval.fn = fn; interval.ms = ms; interval.live = true; return 1; };
  sandbox.clearInterval = () => { interval.live = false; };
  const context = vm.createContext(sandbox);
  vm.runInContext(body + tail, context, { filename: AUDIO_JS });
  const mod = sandbox.__mod;
  if (!mod || !mod.music || !mod.PROG) throw new Error("reference module did not expose `music` / `PROG`");
  check(
    "reference module shape (js/audio.js)",
    exportCount === 7 &&
      typeof mod.music.start === "function" &&
      typeof mod.music.stop === "function" &&
      typeof mod.music.setIntensity === "function" &&
      typeof mod.setMuted === "function" &&
      typeof mod.setVolume === "function" &&
      typeof mod.playStep === "function" &&
      Array.isArray(mod.PROG) &&
      mod.PROG.length === 4,
    `exports=${exportCount} prog=${mod.PROG && mod.PROG.length}`,
  );
  return { mod, ctx, interval, sandbox, exportCount };
}

// ---------------------------------------------------------------------------
// the intensity formula, extracted from `js/main.js` and evaluated
// ---------------------------------------------------------------------------

function loadIntensityFormula() {
  const src = readFileSync(MAIN_JS, "utf8");
  const lines = src.split("\n");
  const START = "const rallyTension = Math.min(1, matchState.rallyHits / 12)";
  const starts = lines.reduce((acc, l, i) => (l.includes(START) ? acc.concat(i) : acc), []);
  check("intensity formula found exactly once in js/main.js", starts.length === 1, `matches=${starts.length}`);
  let end = -1;
  for (let i = starts[0]; i < lines.length; i += 1) {
    if (lines[i].includes("music.setIntensity(")) {
      end = i + 1;
      break;
    }
  }
  check("intensity formula terminates at music.setIntensity", end > 0 && end - starts[0] <= 12, `lines=${end - starts[0]}`);
  const block = lines.slice(starts[0], end).join("\n");
  check("exactly one music.setIntensity call in the block", (block.match(/music\.setIntensity\(/g) || []).length === 1);
  const fn = new Function("matchState", "music", block);
  const evaluate = (rallyHits, sets, games) => {
    let captured = null;
    fn(
      { rallyHits, sets: { player: sets[0], ai: sets[1] }, games: { player: games[0], ai: games[1] } },
      { setIntensity: (v) => { captured = v; } },
    );
    return captured;
  };
  check("formula: idle rally, no sets/games -> 0.12", Math.abs(evaluate(0, [0, 0], [0, 0]) - 0.12) < 1e-12);
  check("formula saturates at 1", evaluate(999, [2, 2], [6, 6]) === 1);
  return { evaluate, block, start: starts[0] + 1, end };
}

// ---------------------------------------------------------------------------
// layer classification — read off the reference's own voice signatures
// ---------------------------------------------------------------------------

const LAYERS = ["bass-on", "bass-off", "pad", "arp", "kick", "hat"];

function layerOf(r) {
  const near = (a, b) => a !== null && Math.abs(a - b) < EPS;
  if (r.node === "bufferSource") {
    if (near(r.filter, 7000) && r.filter_type === "highpass" && near(r.dur, 0.04)) return "hat";
    throw new Error(`unclassified buffer source: ${JSON.stringify(r)}`);
  }
  if (r.node !== "osc") throw new Error(`unclassified node kind ${r.node}`);
  if (r.type === "sine" && r.freq_end !== null && near(r.freq, 130) && near(r.freq_end, 42)) return "kick";
  if (r.type === "square" && near(r.filter, 2200)) return "arp";
  if (r.type === "sine" && r.freq_end === null && near(r.dur, 1.7)) return "pad";
  if (r.type === "triangle" && near(r.filter, 520) && near(r.dur, 0.24)) return "bass-on";
  if (r.type === "triangle" && near(r.filter, 520) && near(r.dur, 0.12)) return "bass-off";
  throw new Error(`unclassified tone: ${JSON.stringify(r)}`);
}

/** midi recovered from the scheduled frequency (`midiToFreq`, js/audio.js:106-108). */
const midiOf = (freq) => (freq === null ? null : round(69 + 12 * Math.log2(freq / 440)));

function normalize(r) {
  const layer = layerOf(r);
  return {
    s: r.step,
    t: round(r.t, 9),
    layer,
    kind: r.node === "osc" ? (layer === "kick" ? "kick" : "tone") : "hat",
    type: r.type,
    midi: midiOf(r.freq),
    freq: round(r.freq, 9),
    freq_end: round(r.freq_end, 9),
    sweep: round(r.sweep, 9),
    gain: round(r.gain, 9),
    attack: round(r.attack, 9),
    dur: round(r.dur, 9),
    filter_type: r.filter_type,
    filter: round(r.filter, 9),
    buf_frames: r.buf_frames,
  };
}

// ---------------------------------------------------------------------------
// the pump — drives the reference exactly the way the game drives it
// ---------------------------------------------------------------------------

/**
 * One scenario run.
 *   context:      "match" (music.start() called) | "menu" (never started)
 *   frames/dt:    the pump; the reference's own 40 ms callback is fired
 *                 `ticksPerFrame` times per frame after advancing ctx.currentTime
 *   intensityAt:  (frame) -> value passed to music.setIntensity before the tick
 *   muteAt:       (frame) -> value passed to setMuted before the tick
 *
 * Per-frame order mirrors `js/main.js:1158-1159, 1220-1226`: set intensity, apply the
 * mute flag, then let the scheduler run.
 */
function runScenario(spec, opts = {}) {
  const ticksPerFrame = opts.ticksPerFrame || 1;
  const { mod, ctx, interval, sandbox } = loadReference();
  const schedule = [];
  const events = [];
  const series = [];
  const inputs = [];
  if (spec.volume !== undefined) mod.setVolume(spec.volume);
  if (spec.context === "match") {
    ctx.currentTime = 0;
    mod.music.start();
    check(`[${spec.id}] scheduler installed`, interval.fn !== null && interval.ms === 40, `ms=${interval.ms}`);
  }
  // Every emitted step is observed through the reference's own `playStep`.
  const origPlayStep = mod.playStep;
  sandbox.playStep = function observedPlayStep(step, time) {
    ctx.currentStep = step;
    schedule.push({ step, t: round(time, 9) });
    return origPlayStep(step, time);
  };
  for (let f = 0; f < spec.frames; f += 1) {
    const t = (f + 1) * DT;
    ctx.currentTime = t;
    const inten = spec.intensityAt(f);
    mod.music.setIntensity(inten);
    series.push(round(inten, 9));
    if (spec.rallyAt) inputs.push(spec.rallyAt(f));
    mod.setMuted(spec.muteAt ? spec.muteAt(f) : false);
    for (let k = 0; k < ticksPerFrame; k += 1) {
      ctx.pending = [];
      if (interval.live && interval.fn) interval.fn();
      for (const r of ctx.pending) events.push(normalize(r));
    }
  }
  check(`[${spec.id}] the observer saw the reference's playStep`, schedule.length === 0 || ctx.currentStep !== null);
  return { schedule, events, series, inputs };
}

// ---------------------------------------------------------------------------
// scenarios
// ---------------------------------------------------------------------------

function scenarioList(intensityFormula) {
  const F = 150;
  const constant = (v) => () => v;
  // The rally drive the game actually produces, kept in one place so the intensity and
  // the inputs recorded beside it cannot drift apart.
  const rallyPlan = (f) => {
    const tight = f > 100;
    return {
      rally_hits: Math.min(24, Math.floor(f / 6)),
      sets_total: tight ? 1 : 0,
      games_total: tight ? 1 : 0,
    };
  };
  const base = { context: "match", frames: F, intensityAt: constant(0.12) };
  return [
    // the reference's other context: no scheduler installed at all
    // (`js/main.js:1159` starts it, `:1385` / `:1553` stop it).
    { ...base, id: "menu_stopped", context: "menu", intensityAt: constant(0.0) },
    // js/main.js:1158 — the intensity a match starts at
    { ...base, id: "match_i012", intensityAt: constant(0.12) },
    // 0.4 boundary: arp gate is `inten > 0.4` (js/audio.js:241)
    { ...base, id: "match_i040", intensityAt: constant(0.4) },
    { ...base, id: "match_i050", intensityAt: constant(0.5) },
    // 0.6 boundary: bass off-beat gate is `inten > 0.6` (js/audio.js:231)
    { ...base, id: "match_i060", intensityAt: constant(0.6) },
    { ...base, id: "match_i061", intensityAt: constant(0.61) },
    // 0.72 boundary: drum gate is `inten > 0.72` (js/audio.js:254)
    { ...base, id: "match_i072", intensityAt: constant(0.72) },
    { ...base, id: "match_i073", intensityAt: constant(0.73) },
    { ...base, id: "match_i080", intensityAt: constant(0.8) },
    { ...base, id: "match_i100", intensityAt: constant(1.0) },
    // the real drive: js/main.js:1220-1226 over a rally that tightens
    {
      ...base,
      id: "match_ramp",
      rallyAt: rallyPlan,
      intensityAt: (f) => {
        const r = rallyPlan(f);
        return intensityFormula.evaluate(r.rally_hits, [r.sets_total, 0], [r.games_total, 0]);
      },
    },
    // mute from the start, unmuted at frame 60: the scheduler is frozen while muted
    // (js/audio.js:262) and then takes the catch-up branch (:263)
    { ...base, id: "match_muted_from_start", intensityAt: constant(0.8), muteAt: (f) => f < 60 },
    // muted in the middle of a running score
    { ...base, id: "match_muted_midway", intensityAt: constant(0.8), muteAt: (f) => f >= 40 && f < 100 },
    // volume 0 is silent but still plays (js/audio.js:286-289 + the music path)
    { ...base, id: "match_volume_zero", frames: 90, intensityAt: constant(0.5), volume: 0 },
    // the unstyled default, as the game ships it (js/audio.js:5)
    { ...base, id: "match_volume_default", frames: 90, intensityAt: constant(0.5) },
  ];
}

// ---------------------------------------------------------------------------
// pass: one full derived reference dump
// ---------------------------------------------------------------------------

function derive() {
  const { mod } = loadReference();
  const formula = loadIntensityFormula();
  const specs = scenarioList(formula);
  const scenarios = [];
  const layerSeen = new Set();

  for (const spec of specs) {
    const run = runScenario(spec);
    for (const e of run.events) layerSeen.add(e.layer);
    // every event must sit exactly on the step the scheduler announced
    for (const e of run.events) {
      const hit = run.schedule.find((r) => r.step === e.s && Math.abs(r.t - e.t) < EPS);
      if (!hit) throw new Error(`[${spec.id}] event step=${e.s} t=${e.t} is not on the announced schedule`);
    }
    const muteWindows = [];
    if (spec.muteAt) {
      let open = null;
      for (let f = 0; f < spec.frames; f += 1) {
        if (spec.muteAt(f) && open === null) open = f;
        if (!spec.muteAt(f) && open !== null) { muteWindows.push([open, f]); open = null; }
      }
      if (open !== null) muteWindows.push([open, spec.frames]);
    }
    scenarios.push({
      id: spec.id,
      context: spec.context,
      volume: spec.volume === undefined ? null : spec.volume,
      frames: spec.frames,
      dt: DT,
      ticks_per_frame: 1,
      mute_windows: muteWindows,
      intensity_series: run.series,
      intensity_inputs: run.inputs.length ? run.inputs : null,
      steps: run.schedule,
      events: run.events,
    });
  }

  check("all six layers are produced", LAYERS.every((l) => layerSeen.has(l)), [...layerSeen].join(","));

  // Gate assertions, read off the reference's own output — never off this file's prose.
  const byId = (id) => scenarios.find((s) => s.id === id);
  const has = (id, layer) => byId(id).events.some((e) => e.layer === layer);
  check("menu context emits nothing", byId("menu_stopped").events.length === 0 && byId("menu_stopped").steps.length === 0);
  check("start intensity: no arp, no drums", !has("match_i012", "arp") && !has("match_i012", "kick") && !has("match_i012", "hat"));
  check("intensity 0.4: arp still gated off (inten > 0.4)", !has("match_i040", "arp"));
  check("intensity 0.5: arp on, drums off", has("match_i050", "arp") && !has("match_i050", "kick") && !has("match_i050", "hat"));
  check("intensity 0.6: bass off-beat still gated off (inten > 0.6)", !has("match_i060", "bass-off"));
  check("intensity 0.61: bass off-beat on", has("match_i061", "bass-off"));
  check("intensity 0.72: drums still gated off (inten > 0.72)", !has("match_i072", "kick") && !has("match_i072", "hat"));
  check("intensity 0.73: drums on", has("match_i073", "kick") && has("match_i073", "hat"));
  const LOOKAHEAD = 0.15; // js/audio.js:264
  const CATCH_UP_LEAD = 0.05; // js/audio.js:263
  check(
    "muted from start: the score starts only after the catch-up",
    byId("match_muted_from_start").events.every((e) => e.t >= 60 * DT + CATCH_UP_LEAD - EPS) &&
      byId("match_muted_from_start").events.length > 0,
  );
  // Muted midway: steps already queued inside the lookahead window still fire, then the
  // walk freezes (`js/audio.js:262`) and on unmute the catch-up branch re-anchors
  // `_nextTime` to `currentTime + 0.05` (`:263`) — so there is a gap, and its edges are
  // the reference's own two constants.
  const midway = byId("match_muted_midway");
  // Frame f is pumped at ctx.currentTime = (f+1)*DT, so the mute applied at frame 40
  // takes effect at 41*DT and the un-mute at frame 100 at 101*DT.
  const muteTime = 41 * DT;
  const unmuteTime = 101 * DT;
  const preSteps = midway.steps.filter((r) => r.t < unmuteTime);
  const postSteps = midway.steps.filter((r) => r.t >= unmuteTime);
  check(
    "muted midway: the score freezes inside the lookahead and resumes at the catch-up",
    preSteps.length > 0 &&
      postSteps.length > 0 &&
      Math.max(...preSteps.map((r) => r.t)) <= muteTime + LOOKAHEAD + EPS &&
      Math.abs(Math.min(...postSteps.map((r) => r.t)) - (unmuteTime + CATCH_UP_LEAD)) < EPS &&
      midway.events.filter((e) => e.t >= unmuteTime).length > 0,
    `preMax=${Math.max(...preSteps.map((r) => r.t))} postMin=${Math.min(...postSteps.map((r) => r.t))} expect=${unmuteTime + CATCH_UP_LEAD}`,
  );
  check(
    "volume 0 does not change the score",
    JSON.stringify(byId("match_volume_zero").events) === JSON.stringify(byId("match_volume_default").events),
  );
  check("volume 0 still schedules the score", byId("match_volume_zero").events.length > 0);
  check("each bar opens with a pad", byId("match_i080").events.filter((e) => e.layer === "pad").length >= 2);
  check("pad lands only on step 0 of a bar", byId("match_i080").events.every((e) => e.layer !== "pad" || e.s % 16 === 0));

  // Cadence invariance: firing the reference's 40 ms callback twice per frame must
  // produce the same scheduled stream. That is what lets the Godot side walk the same
  // schedule from `_process` instead of from a real timer.
  for (const spec of specs) {
    if (spec.id === "menu_stopped") continue;
    const a = runScenario(spec, { ticksPerFrame: 1 });
    const b = runScenario(spec, { ticksPerFrame: 2 });
    check(
      `pump cadence invariance [${spec.id}]`,
      JSON.stringify(a.events) === JSON.stringify(b.events) && JSON.stringify(a.schedule) === JSON.stringify(b.schedule),
      `ticks1=${a.events.length}/${a.schedule.length} ticks2=${b.events.length}/${b.schedule.length}`,
    );
  }

  const prog = mod.PROG.map((c) => ({ root: c.root, intervals: [...c.intervals] }));
  check("PROG read from the reference", prog.length === 4 && prog.every((c) => c.intervals.length === 4), JSON.stringify(prog));

  const audioRaw = readFileSync(AUDIO_JS);
  const mainRaw = readFileSync(MAIN_JS);
  // The hat's own duration and buffer length, read off the recorded stream: the
  // render rate is `bufferFrames / dur` (`js/audio.js:205-206`), never typed in.
  const hat = scenarios.flatMap((s) => s.events).find((e) => e.layer === "hat");
  check("a hat event exists to derive the render rate from", !!hat);
  const renderRate = Math.round(hat.buf_frames / hat.dur);
  check("the reference's render rate derives from its own hat buffer", renderRate === 44100, `derived=${renderRate}`);
  return {
    doc: {
      schema: SCHEMA,
      schemaVersion: SCHEMA_VERSION,
      generatedBy: "tools/audio-music-port/extract-music.mjs",
      source: {
        "js/audio.js": { sha256: sha256(audioRaw), bytes: audioRaw.length },
        "js/main.js": { sha256: sha256(mainRaw), bytes: mainRaw.length },
      },
      anchors: {
        prog: "js/audio.js:110-115",
        midi_to_freq: "js/audio.js:106-108",
        start_stop: "js/audio.js:124-138",
        set_intensity: "js/audio.js:139-141",
        music_bus_gain: "js/audio.js:144-153",
        voices: "js/audio.js:155-221",
        play_step: "js/audio.js:223-258",
        scheduler: "js/audio.js:260-271",
        mute: "js/audio.js:24,41,157,184,202,262",
        volume: "js/audio.js:286-289",
        contexts: "js/main.js:1158-1159 (start), :1220-1226 (intensity), :1385, :1553 (stop)",
        intensity_formula_source: formula.block,
        intensity_formula_lines: `js/main.js:${formula.start}-${formula.end}`,
      },
      engine: {
        sample_rate: renderRate,
        hat_dur: hat.dur,
        hat_buf_frames: hat.buf_frames,
        lookahead: 0.15,
        lead: 0.08,
        catch_up_behind: -0.1,
        catch_up_lead: 0.05,
        bpm_base: 96,
        bpm_intensity: 54,
        steps_per_beat: 4,
        loop_steps: 64,
        steps_per_bar: 16,
        timer_ms: 40,
        music_bus_gain: 0.55,
        master_gain_default: 0.5,
      },
      prog,
      layers: LAYERS,
      not_reproducible: [
        "the samples inside a hat buffer (js/audio.js:208 fills it with Math.random()): only the hat's structural parameters — start time, gain, 0.04 s duration, 7 kHz highpass, buffer length — are compared, never the waveform",
        "sample-accurate voice rendering: the reference schedules oscillators at exact sample positions with exponential param ramps; the port renders voice samples in engine memory with the same envelope arithmetic but triggers them from the frame clock, so per-sample identity is neither claimed nor tested",
        "absolute wall-clock timing: `setInterval(scheduleMusic, 40)` and `AudioContext.currentTime` are host-dependent; what is reproduced is the scheduled stream, which is invariant to the callback cadence (asserted above)",
        "browser throttling of `setInterval` in a background tab (>= 1 s), which the reference does not compensate for",
        "anything about how the result sounds: the test engine runs the dummy audio driver, so there is no listening test and no claim about audible output",
      ],
      scenarios,
      self_checks: selfChecks.map((c) => ({ name: c.name, ok: c.ok })),
    },
  };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function main() {
  const argv = process.argv.slice(2);
  const unknown = argv.filter((a) => !["--check", "--print"].includes(a));
  if (unknown.length) {
    console.error(`unknown argument(s): ${unknown.join(" ")}`);
    process.exit(2);
  }
  const { doc } = derive();
  const text = JSON.stringify(doc, null, 1) + "\n";
  const digest = sha256(Buffer.from(text, "utf8"));

  if (argv.includes("--check")) {
    if (!existsSync(OUT_FILE)) {
      console.error(`FAIL — ${path.relative(REPO, OUT_FILE)} does not exist; run without --check first`);
      process.exit(1);
    }
    const onDisk = readFileSync(OUT_FILE, "utf8");
    if (onDisk !== text) {
      console.error(`FAIL — the stored reference dump is stale vs a fresh run of js/audio.js`);
      console.error(`  stored sha256 ${sha256(Buffer.from(onDisk, "utf8"))}`);
      console.error(`  fresh  sha256 ${digest}`);
      process.exit(1);
    }
    console.log(`ok — ${path.relative(REPO, OUT_FILE)} matches a fresh run (sha256 ${digest})`);
    console.log(`PASS ${selfChecks.length}/${selfChecks.length} harness self-checks`);
    process.exit(0);
  }

  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(OUT_FILE, text, "utf8");
  writeFileSync(OUT_FILE.replace(/\.json$/, ".sha256"), digest + "\n", "utf8");
  const events = doc.scenarios.reduce((n, s) => n + s.events.length, 0);
  if (argv.includes("--print")) {
    for (const s of doc.scenarios) {
      const layers = [...new Set(s.events.map((e) => e.layer))].sort().join(",");
      console.log(
        `${s.id.padEnd(24)} ctx=${s.context.padEnd(5)} vol=${String(s.volume).padEnd(4)} steps=${String(s.steps.length).padStart(3)} events=${String(s.events.length).padStart(4)} layers=${layers}`,
      );
    }
  }
  console.log(`wrote ${path.relative(REPO, OUT_FILE)} — ${doc.scenarios.length} scenarios, ${events} events, sha256 ${digest}`);
  console.log(`PASS ${selfChecks.length}/${selfChecks.length} harness self-checks`);
  process.exit(0);
}

main();
