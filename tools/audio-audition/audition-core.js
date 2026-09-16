/**
 * audition-core.js — the audio-port catalogue, as data.
 *
 * Single source of truth shared by:
 *   - tools/audio-audition/index.html        (human audition: click a sound, hear it)
 *   - tools/audio-audition/verify-stub.mjs   (Node: stub WebAudio, asserts every
 *                                             parameter actually reaches the API)
 *   - tools/audio-audition/verify_browser.py (Playwright: real Chromium offline
 *                                             render, measures each sound + bakes WAVs.
 *                                             Measures, does not listen — no sound device.)
 *
 * Every row cites the exact js/audio.js lines that synthesise it and the exact
 * js/game.js / js/main.js call site that fires it. `expect` is the machine-
 * checkable form of the `params` prose: if js/audio.js changes and this file does
 * not, verify-stub.mjs fails.
 *
 * The audio module is imported read-only, straight out of the game: js/audio.js
 * is not copied and not modified. Serve the repo root over http and open
 *   http://127.0.0.1:<port>/tools/audio-audition/index.html
 * (font: ../../js/audio.js — a file:// open cannot load ES modules.)
 */

/** WebAudio-side module API of js/audio.js (the game's own module). */
const SFX_MODULE = "js/audio.js";

/** Every one-shot sound: 9 `sfx` methods, 10 distinct sounds (`point` has two). */
export const SFX = [
  {
    id: "hit",
    label: "Paddle hit",
    synth: "js/audio.js:61-64",
    head: "js/audio.js:61 (hit() {)",
    trigger: "js/game.js:1893 — hitBall(), every successful paddle contact (player, mate, opponent, mate)",
    params:
      "tone triangle 230→92 Hz, dur 0.09 s, gain 0.4, attack 0.003 s  ·  " +
      "noise: 0.04 s of decaying white noise through a bandpass at 2800 Hz, gain 0.12",
    suppression: "audio._muted (js/audio.js:24, 41); ctx() is null before the first user gesture",
    play: (api) => api.sfx.hit(),
    expect: {
      tones: [{ type: "triangle", freq: 230, freqEnd: 92, at: 0, dur: 0.09, gain: 0.4 }],
      noise: [{ filterType: "bandpass", filterFreq: 2800, dur: 0.04, gain: 0.12 }],
    },
  },
  {
    id: "bounce",
    label: "Ground bounce",
    synth: "js/audio.js:65-67",
    head: "js/audio.js:65 (bounce() {)",
    trigger: "js/game.js:2209 — handleGroundBounce(), ball lands inside the court",
    params: "tone sine 150→68 Hz, dur 0.1 s, gain 0.3, attack 0.003 s (no noise)",
    suppression: "audio._muted (js/audio.js:24)",
    play: (api) => api.sfx.bounce(),
    expect: {
      tones: [{ type: "sine", freq: 150, freqEnd: 68, at: 0, dur: 0.1, gain: 0.3 }],
      noise: [],
    },
  },
  {
    id: "wall",
    label: "Wall / glass hit",
    synth: "js/audio.js:68-71",
    head: "js/audio.js:68 (wall() {)",
    trigger: "js/game.js:2363 — handleWalls(), ball reaches a side wall or the back glass",
    params:
      "noise 0.16 s through bandpass 900 Hz, gain 0.32  ·  " +
      "tone sine 92→54 Hz, dur 0.22 s, gain 0.4 — the loudest, lowest one-shot in the game",
    suppression: "audio._muted (js/audio.js:24, 41)",
    play: (api) => api.sfx.wall(),
    expect: {
      tones: [{ type: "sine", freq: 92, freqEnd: 54, at: 0, dur: 0.22, gain: 0.4 }],
      noise: [{ filterType: "bandpass", filterFreq: 900, dur: 0.16, gain: 0.32 }],
    },
  },
  {
    id: "net",
    label: "Net contact",
    synth: "js/audio.js:72-75",
    head: "js/audio.js:72 (net() {)",
    trigger:
      "js/game.js:2382 — handleNetCollision(), ball crosses the net plane below BALANCE.netClearance",
    params:
      "noise 0.06 s through bandpass 1600 Hz, gain 0.16  ·  tone triangle 310→170 Hz, dur 0.06 s, gain 0.18",
    suppression: "audio._muted (js/audio.js:24, 41)",
    play: (api) => api.sfx.net(),
    expect: {
      tones: [{ type: "triangle", freq: 310, freqEnd: 170, at: 0, dur: 0.06, gain: 0.18 }],
      noise: [{ filterType: "bandpass", filterFreq: 1600, dur: 0.06, gain: 0.16 }],
    },
  },
  {
    id: "serve",
    label: "Serve",
    synth: "js/audio.js:76-79",
    head: "js/audio.js:76 (serve() {)",
    trigger: "js/game.js:750 — performServe(), racket meets ball on the serve",
    params:
      "noise 0.22 s through bandpass 600 Hz, gain 0.12  ·  " +
      "tone sine 330→720 Hz RISING, dur 0.18 s, gain 0.12 — the only upward-swept tone in the game",
    suppression: "audio._muted (js/audio.js:24, 41)",
    play: (api) => api.sfx.serve(),
    expect: {
      tones: [{ type: "sine", freq: 330, freqEnd: 720, at: 0, dur: 0.18, gain: 0.12 }],
      noise: [{ filterType: "bandpass", filterFreq: 600, dur: 0.22, gain: 0.12 }],
    },
  },
  {
    id: "special",
    label: "Special shot",
    synth: "js/audio.js:80-84",
    head: "js/audio.js:80 (special() {)",
    trigger: "js/game.js:1898 — hitBall() with isSpecial true (energy-bar special fired)",
    params:
      "noise 0.3 s through bandpass 1400 Hz, gain 0.2  ·  " +
      "tone sawtooth 1200→240 Hz, dur 0.3 s, gain 0.14 (harsh sweep)  ·  " +
      "tone sine 210→90 Hz, dur 0.3 s, gain 0.2 (body). Fires on top of the plain hit() at :1893",
    suppression: "audio._muted (js/audio.js:24, 41)",
    play: (api) => api.sfx.special(),
    expect: {
      tones: [
        { type: "sawtooth", freq: 1200, freqEnd: 240, at: 0, dur: 0.3, gain: 0.14 },
        { type: "sine", freq: 210, freqEnd: 90, at: 0, dur: 0.3, gain: 0.2 },
      ],
      noise: [{ filterType: "bandpass", filterFreq: 1400, dur: 0.3, gain: 0.2 }],
    },
  },
  {
    id: "point-win",
    label: "Point won (player)",
    synth: "js/audio.js:86-89",
    head: "js/audio.js:85 (point(win) {)",
    trigger: "js/game.js:2111 — scorePoint() with winner === \"player\" and no match result yet",
    params:
      "ascending major triad: 3 × triangle at 523 / 659 / 784 Hz (C5-E5-G5), dur 0.16 s, gain 0.22, " +
      "scheduled at 0 / 100 / 200 ms with setTimeout (js/audio.js:88)",
    suppression: "audio._muted (js/audio.js:24)",
    play: (api) => api.sfx.point(true),
    expect: {
      tones: [
        { type: "triangle", freq: 523, freqEnd: null, at: 0, dur: 0.16, gain: 0.22 },
        { type: "triangle", freq: 659, freqEnd: null, at: 0.1, dur: 0.16, gain: 0.22 },
        { type: "triangle", freq: 784, freqEnd: null, at: 0.2, dur: 0.16, gain: 0.22 },
      ],
      noise: [],
    },
  },
  {
    id: "point-loss",
    label: "Point lost (AI scores)",
    synth: "js/audio.js:90-92",
    head: "js/audio.js:85 (point(win) {)",
    trigger: "js/game.js:2111 — scorePoint() with winner === \"ai\", no match result",
    params: "single descending triangle 240→150 Hz, dur 0.28 s, gain 0.2 — deliberately the inverse shape of point-win",
    suppression: "audio._muted (js/audio.js:24)",
    play: (api) => api.sfx.point(false),
    expect: {
      tones: [{ type: "triangle", freq: 240, freqEnd: 150, at: 0, dur: 0.28, gain: 0.2 }],
      noise: [],
    },
  },
  {
    id: "victory",
    label: "Match won",
    synth: "js/audio.js:94-98",
    head: "js/audio.js:94 (victoryMatch() {)",
    trigger: "js/game.js:2113 — scorePoint() with state.result and winner === \"player\"; music.stop() at js/main.js:1385",
    params:
      "4 × triangle 659 / 784 / 1047 / 1319 Hz (E5-G5-C6-E6), dur 0.2 s, gain 0.24, staggered 0 / 130 / 260 / 390 ms",
    suppression: "audio._muted (js/audio.js:24)",
    play: (api) => api.sfx.victoryMatch(),
    expect: {
      tones: [
        { type: "triangle", freq: 659, freqEnd: null, at: 0, dur: 0.2, gain: 0.24 },
        { type: "triangle", freq: 784, freqEnd: null, at: 0.13, dur: 0.2, gain: 0.24 },
        { type: "triangle", freq: 1047, freqEnd: null, at: 0.26, dur: 0.2, gain: 0.24 },
        { type: "triangle", freq: 1319, freqEnd: null, at: 0.39, dur: 0.2, gain: 0.24 },
      ],
      noise: [],
    },
  },
  {
    id: "defeat",
    label: "Match lost",
    synth: "js/audio.js:99-103",
    head: "js/audio.js:99 (defeatMatch() {)",
    trigger: "js/game.js:2115 — scorePoint() with state.result and winner === \"ai\"",
    params:
      "4 × triangle 392 / 330 / 262 / 196 Hz (G4-E4-C4-G3), dur 0.28 s, gain 0.2, staggered 0 / 180 / 360 / 540 ms — " +
      "slower and lower than victory on purpose",
    suppression: "audio._muted (js/audio.js:24)",
    play: (api) => api.sfx.defeatMatch(),
    expect: {
      tones: [
        { type: "triangle", freq: 392, freqEnd: null, at: 0, dur: 0.28, gain: 0.2 },
        { type: "triangle", freq: 330, freqEnd: null, at: 0.18, dur: 0.28, gain: 0.2 },
        { type: "triangle", freq: 262, freqEnd: null, at: 0.36, dur: 0.28, gain: 0.2 },
        { type: "triangle", freq: 196, freqEnd: null, at: 0.54, dur: 0.28, gain: 0.2 },
      ],
      noise: [],
    },
  },
];

/**
 * The generative music. Not triggered by a game event: it is a 40 ms scheduler
 * (js/audio.js:130) that looks 150 ms ahead (js/audio.js:264-265) and emits one
 * 16-step bar of a 4-chord loop, forever, while a match is running.
 */
export const MUSIC = {
  start: "js/main.js:1158-1159 — startMatch(): setIntensity(0.12) then start()",
  stop: "js/main.js:1385 (endMatch) and js/main.js:1553 (quitMatch); NOT stopped by pauseGame() (js/main.js:1530) — the music keeps playing under the pause overlay",
  scheduler: "setInterval(scheduleMusic, 40) at js/audio.js:130; lookahead 0.15 s at js/audio.js:264-265; step modulo 64 at js/audio.js:269",
  harmony: "PROG at js/audio.js:110-115 — Am (root 45, [0,3,7,12]), Fmaj7 (41, [0,4,7,12]), C (48, [0,4,7,12]), G (43, [0,4,7,12]); 4 bars × 16 steps = the 64-step loop",
  timetable: "js/audio.js:267 — secondsPerBeat = 60 / (96 + intensity * 54), i.e. 96 BPM at intensity 0 rising to 150 BPM at intensity 1; step = secondsPerBeat / 4 (16th notes)",
  intensity: "js/main.js:1226, once per rendered frame — min(1, 0.12 + min(1, rallyHits/12) * 0.55 + stakes), stakes = min(0.35, (sets.player+sets.ai)*0.15 + (games.player+games.ai)*0.02) (js/main.js:1220-1225)",
  buses: "music bus gain 0.55 (js/audio.js:149) into the master gain 0.5 (js/audio.js:4-5, 15)",
  mute: "scheduleMusic returns early while muted (js/audio.js:262) and the step clock is re-anchored on unmute (js/audio.js:263), so unmuting resumes mid-pattern instead of dumping the missed steps",
  reducedMotion: "not consulted anywhere in js/audio.js — reduced motion only cuts particles and shake (js/fx.js:5, 26, 63)",
  gates: { arp: 0.4, bassOffbeat: 0.6, drums: 0.72 },
  voices: [
    {
      id: "music-bass",
      label: "Bass",
      synth: "js/audio.js:229-233 (mTone, js/audio.js:155-180)",
      gate: "every step where step % 4 === 0, plus step % 4 === 2 when intensity > 0.6",
      params: "triangle at midiToFreq(root − 12) (Am45 → 110 Hz region), lowpass 520 Hz, dur 0.24 s, gain 0.15; the off-beat echo is dur 0.12 s, gain 0.07",
      intensityEffect: "gains a syncopated off-beat octave pulse above 0.6",
    },
    {
      id: "music-pad",
      label: "Pad chord",
      synth: "js/audio.js:235-239",
      gate: "step === 0 of every bar (once per bar, 1.7 s release)",
      params: "3 × sine on chord.intervals.slice(0,3), dur 1.7 s, gain 0.032, attack 0.35 s, no filter — the wash under everything",
      intensityEffect: "none: the pad is constant, and it is what makes an empty rally still sound like music",
    },
    {
      id: "music-arp",
      label: "Arpeggio",
      synth: "js/audio.js:241-252",
      gate: "intensity > 0.4 — every step, no exceptions",
      params: "square wave at midiToFreq(root + intervals[s % 3] + octave), octave = 12 for steps 0-3 and 8-11, else 24; lowpass 2200 Hz, dur 0.09 s, gain 0.028 + intensity * 0.03",
      intensityEffect: "the on/off switch at 0.4 is the loudest structural change in the whole score; above it, gain grows with intensity",
    },
    {
      id: "music-kick",
      label: "Kick",
      synth: "js/audio.js:182-198 (mKick), gated at js/audio.js:254-255",
      gate: "intensity > 0.72 and step % 4 === 0",
      params: "sine 130→42 Hz over 0.12 s, gain 0.2 from a hard setValueAtTime (no attack ramp), stop at +0.18 s",
      intensityEffect: "appears only at high tension (long rally or a match deep into sets)",
    },
    {
      id: "music-hat",
      label: "Hi-hat",
      synth: "js/audio.js:200-221 (mHat), gated at js/audio.js:256",
      gate: "intensity > 0.72 and step % 2 === 1 (off-beat)",
      params: "0.04 s noise burst through a highpass at 7000 Hz, gain 0.02 + (intensity − 0.72) * 0.1",
      intensityEffect: "same gate as the kick; its gain keeps rising with intensity above 0.72",
    },
  ],
};

/** Every catalogued sound, one row each: 10 one-shots + 5 music voices = 15. */
export const CATALOGUE = [
  ...SFX.map((entry) => ({ ...entry, group: "sfx" })),
  ...MUSIC.voices.map((voice) => ({ ...voice, group: "music" })),
];

/** Mixer, not sound: the two gain stages every sound passes through. */
export const MIXER = [
  { id: "master", value: 0.5, anchor: "js/audio.js:4-5 (_volume 0.5), :15 (gain), :286-288 (setVolume)", db: 20 * Math.log10(0.5) },
  { id: "music-bus", value: 0.55, anchor: "js/audio.js:149", db: 20 * Math.log10(0.55) },
];

export const PERSISTENCE = {
  mute: "prefs.muted restored at js/main.js:2199, saved via collectPrefs (js/ui.js:428), toggled by #muteBtn (js/main.js:2191-2196)",
  volume: "prefs.volume restored at js/main.js:2213, sliders at js/main.js:2369-2372 and 2426, saved via collectPrefs (js/ui.js:434)",
  unlock: "initAudio() on the first pointerdown/keydown/gamepad press: js/main.js:2484, 2506, 875, 916, 984, 2192",
};

/** BPM that js/audio.js:267 produces for an intensity in [0,1]. */
export function bpmForIntensity(intensity) {
  const i = Math.min(1, Math.max(0, intensity));
  return 96 + i * 54;
}

/** Layer activity implied by MUSIC.gates — the same numbers the source gates on. */
export function activeVoices(intensity) {
  const i = Math.min(1, Math.max(0, intensity));
  const { gates } = MUSIC;
  return {
    "music-bass": "on (with an extra off-beat pulse above " + gates.bassOffbeat + ")",
    "music-pad": "on",
    "music-arp": i > gates.arp ? "on" : "off",
    "music-kick": i > gates.drums ? "on" : "off",
    "music-hat": i > gates.drums ? "on" : "off",
    "music-bass-offbeat": i > gates.bassOffbeat ? "on" : "off",
  };
}

export { SFX_MODULE };
