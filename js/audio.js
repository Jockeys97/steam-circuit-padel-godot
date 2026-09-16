const audio = {
  _ctx: null,
  _master: null,
  _muted: false,
  _volume: 0.5,
};

function ctx() {
  if (typeof window === "undefined") return null;
  if (!audio._ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    audio._ctx = new AC();
    audio._master = audio._ctx.createGain();
    audio._master.gain.value = audio._volume;
    audio._master.connect(audio._ctx.destination);
  }
  if (audio._ctx.state === "suspended") audio._ctx.resume();
  return audio._ctx;
}

function tone({ freq = 440, freqEnd = null, type = "sine", dur = 0.12, gain = 0.3, attack = 0.003 } = {}) {
  const c = ctx();
  if (!c || audio._muted) return;
  const osc = c.createOscillator();
  const g = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(Math.max(20, freq), c.currentTime);
  if (freqEnd) osc.frequency.exponentialRampToValueAtTime(Math.max(20, freqEnd), c.currentTime + dur);
  g.gain.setValueAtTime(0.0001, c.currentTime);
  g.gain.exponentialRampToValueAtTime(gain, c.currentTime + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
  osc.connect(g);
  g.connect(audio._master);
  osc.start(c.currentTime);
  osc.stop(c.currentTime + dur + 0.03);
}

function noise({ dur = 0.1, gain = 0.2, filterFreq = 2000 } = {}) {
  const c = ctx();
  if (!c || audio._muted) return;
  const len = Math.max(1, Math.floor(c.sampleRate * dur));
  const buf = c.createBuffer(1, len, c.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = c.createBufferSource();
  src.buffer = buf;
  const filt = c.createBiquadFilter();
  filt.type = "bandpass";
  filt.frequency.value = filterFreq;
  const g = c.createGain();
  g.gain.setValueAtTime(gain, c.currentTime);
  g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + dur);
  src.connect(filt);
  filt.connect(g);
  g.connect(audio._master);
  src.start(c.currentTime);
}

export const sfx = {
  hit() {
    tone({ freq: 230, freqEnd: 92, type: "triangle", dur: 0.09, gain: 0.4 });
    noise({ dur: 0.04, gain: 0.12, filterFreq: 2800 });
  },
  bounce() {
    tone({ freq: 150, freqEnd: 68, type: "sine", dur: 0.1, gain: 0.3 });
  },
  wall() {
    noise({ dur: 0.16, gain: 0.32, filterFreq: 900 });
    tone({ freq: 92, freqEnd: 54, type: "sine", dur: 0.22, gain: 0.4 });
  },
  net() {
    noise({ dur: 0.06, gain: 0.16, filterFreq: 1600 });
    tone({ freq: 310, freqEnd: 170, type: "triangle", dur: 0.06, gain: 0.18 });
  },
  serve() {
    noise({ dur: 0.22, gain: 0.12, filterFreq: 600 });
    tone({ freq: 330, freqEnd: 720, type: "sine", dur: 0.18, gain: 0.12 });
  },
  special() {
    noise({ dur: 0.3, gain: 0.2, filterFreq: 1400 });
    tone({ freq: 1200, freqEnd: 240, type: "sawtooth", dur: 0.3, gain: 0.14 });
    tone({ freq: 210, freqEnd: 90, type: "sine", dur: 0.3, gain: 0.2 });
  },
  point(win) {
    if (win) {
      [523, 659, 784].forEach((f, i) => {
        setTimeout(() => tone({ freq: f, type: "triangle", dur: 0.16, gain: 0.22 }), i * 100);
      });
    } else {
      tone({ freq: 240, freqEnd: 150, type: "triangle", dur: 0.28, gain: 0.2 });
    }
  },
  victoryMatch() {
    [659, 784, 1047, 1319].forEach((f, i) => {
      setTimeout(() => tone({ freq: f, type: "triangle", dur: 0.2, gain: 0.24 }), i * 130);
    });
  },
  defeatMatch() {
    [392, 330, 262, 196].forEach((f, i) => {
      setTimeout(() => tone({ freq: f, type: "triangle", dur: 0.28, gain: 0.2 }), i * 180);
    });
  },
};

function midiToFreq(midi) {
  return 440 * Math.pow(2, (midi - 69) / 12);
}

const PROG = [
  { root: 45, intervals: [0, 3, 7, 12] },
  { root: 41, intervals: [0, 4, 7, 12] },
  { root: 48, intervals: [0, 4, 7, 12] },
  { root: 43, intervals: [0, 4, 7, 12] },
];

export const music = {
  playing: false,
  intensity: 0,
  _timer: null,
  _step: 0,
  _nextTime: 0,
  _gain: null,
  start() {
    if (this.playing) return;
    this.playing = true;
    this._step = 0;
    const c = ctx();
    this._nextTime = (c ? c.currentTime : 0) + 0.08;
    if (!this._timer) this._timer = setInterval(scheduleMusic, 40);
  },
  stop() {
    this.playing = false;
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
  },
  setIntensity(value) {
    this.intensity = Math.min(1, Math.max(0, value));
  },
};

function musicBus() {
  const c = ctx();
  if (!c) return null;
  if (!music._gain) {
    music._gain = c.createGain();
    music._gain.gain.value = 0.55;
    music._gain.connect(audio._master);
  }
  return music._gain;
}

function mTone({ freq, type = "sine", dur = 0.2, gain = 0.1, time, attack = 0.012, filter = null }) {
  const c = ctx();
  if (!c || audio._muted) return;
  const bus = musicBus();
  if (!bus) return;
  const t = time ?? c.currentTime;
  const osc = c.createOscillator();
  const g = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(Math.max(20, freq), t);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(gain, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  let head = osc;
  if (filter) {
    const f = c.createBiquadFilter();
    f.type = "lowpass";
    f.frequency.value = filter;
    osc.connect(f);
    head = f;
  }
  head.connect(g);
  g.connect(bus);
  osc.start(t);
  osc.stop(t + dur + 0.06);
}

function mKick(time) {
  const c = ctx();
  if (!c || audio._muted) return;
  const bus = musicBus();
  if (!bus) return;
  const osc = c.createOscillator();
  const g = c.createGain();
  osc.type = "sine";
  osc.frequency.setValueAtTime(130, time);
  osc.frequency.exponentialRampToValueAtTime(42, time + 0.12);
  g.gain.setValueAtTime(0.2, time);
  g.gain.exponentialRampToValueAtTime(0.0001, time + 0.15);
  osc.connect(g);
  g.connect(bus);
  osc.start(time);
  osc.stop(time + 0.18);
}

function mHat(time, gain) {
  const c = ctx();
  if (!c || audio._muted) return;
  const bus = musicBus();
  if (!bus) return;
  const len = Math.max(1, Math.floor(c.sampleRate * 0.04));
  const buf = c.createBuffer(1, len, c.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i += 1) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = c.createBufferSource();
  src.buffer = buf;
  const f = c.createBiquadFilter();
  f.type = "highpass";
  f.frequency.value = 7000;
  const g = c.createGain();
  g.gain.setValueAtTime(gain, time);
  g.gain.exponentialRampToValueAtTime(0.0001, time + 0.04);
  src.connect(f);
  f.connect(g);
  g.connect(bus);
  src.start(time);
}

function playStep(step, time) {
  const bar = Math.floor(step / 16) % PROG.length;
  const s = step % 16;
  const chord = PROG[bar];
  const inten = music.intensity;

  if (s % 4 === 0) {
    mTone({ freq: midiToFreq(chord.root - 12), type: "triangle", dur: 0.24, gain: 0.15, time, filter: 520 });
  } else if (inten > 0.6 && s % 4 === 2) {
    mTone({ freq: midiToFreq(chord.root - 12), type: "triangle", dur: 0.12, gain: 0.07, time, filter: 520 });
  }

  if (s === 0) {
    chord.intervals.slice(0, 3).forEach((iv) => {
      mTone({ freq: midiToFreq(chord.root + iv), type: "sine", dur: 1.7, gain: 0.032, time, attack: 0.35 });
    });
  }

  if (inten > 0.4) {
    const note = chord.intervals[s % chord.intervals.length];
    const octave = s % 8 < 4 ? 12 : 24;
    mTone({
      freq: midiToFreq(chord.root + note + octave),
      type: "square",
      dur: 0.09,
      gain: 0.028 + inten * 0.03,
      time,
      filter: 2200,
    });
  }

  if (inten > 0.72) {
    if (s % 4 === 0) mKick(time);
    if (s % 2 === 1) mHat(time, 0.02 + (inten - 0.72) * 0.1);
  }
}

function scheduleMusic() {
  const c = ctx();
  if (!c || audio._muted || !music.playing) return;
  if (music._nextTime < c.currentTime - 0.1) music._nextTime = c.currentTime + 0.05;
  const lookahead = 0.15;
  while (music._nextTime < c.currentTime + lookahead) {
    playStep(music._step, music._nextTime);
    const secondsPerBeat = 60 / (96 + music.intensity * 54);
    music._nextTime += secondsPerBeat / 4;
    music._step = (music._step + 1) % 64;
  }
}

export function initAudio() {
  if (typeof window === "undefined") return;
  ctx();
}

export function setMuted(muted) {
  audio._muted = Boolean(muted);
}

export function isMuted() {
  return audio._muted;
}

export function setVolume(volume) {
  audio._volume = Math.min(1, Math.max(0, Number(volume) || 0));
  if (audio._master) audio._master.gain.value = audio._volume;
}

export function getVolume() {
  return audio._volume;
}