# Evidence — Audio port route

Ticket: [`docs/wayfinder/tickets/audio-port-route.md`](../tickets/audio-port-route.md)
Run date: 2026-09-16. All commands below were executed on this host from the repo root.

## Sources read

| What | Where | Lines |
|---|---|---|
| Synthesis + mixer + generative music | `js/audio.js` | 293 (whole file) |
| Audio call sites (the triggers) | `js/game.js` | 750, 1893, 1898, 2111, 2113, 2115, 2209, 2363, 2382 |
| Rally-intensity drive + start/stop | `js/main.js` | 1158-1159, 1220-1226, 1385, 1553, 1530-1545 |
| Reduced-motion flag | `js/main.js:2214, 2301-2303, 2413`, `js/fx.js:2-10, 26, 63`, `styles.css:2715-2722`, `js/ui.js:283, 435, 471` | — |

`grep -n "reduce\|motion\|Motion" js/audio.js` → **no match**: `js/audio.js` never
consults reduced motion. That is a finding, not an omission in this document.

## Commands run, with exit codes

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `npm run audit` | **0** | 27/27 audit passano |
| 2 | `node tools/audio-audition/verify-stub.mjs` (before fixes) | **1** | 31/54 — harness broken, see below |
| 3 | `node tools/audio-audition/verify-stub.mjs` (after fixes) | **0** | 54/54 — catalogue matches `js/audio.js`, every parameter reaches the API |
| 4 | `python3 tools/audio-audition/verify_browser.py` (script did not exist — written in this task) | **0** | 11/11 renders as expected; 10 WAVs baked. Run twice: exit 0 both times |
| 5 | `python3 docs/wayfinder/validate.py` | **0** | PASS — 0 errors, 0 warnings; ticket headers, links and blocked-by graph all valid |

One transparency note on command 5: that script is the repo's own map validator, and
running it **regenerates `docs/wayfinder/validation.md`**, a generated report. That file
is outside this task's write allowlist; its only change is the row for this ticket
(`audio-port-route.md | resolved | research | AFK | unassigned | none`). No source,
asset or config file was written.

`verify_browser.py` did not exist before this task, so the promise in
`audition-core.js:8-9` (and the ticket's "verified by playing the catalogue against
the running web build") was unbacked. It exists now and runs green.

### Fixes made to the harness (all inside `tools/audio-audition/`)

The harness was broken, not merely stale. Four real bugs, each verified by the exit
code above:

1. `entry.play(audioModule.sfx)` — every catalogue row's `play` is `(api) => api.sfx.x()`,
   so passing `audioModule.sfx` made `api.sfx` undefined. All 10 "API events" checks
   died with `Cannot read properties of undefined (reading 'hit')`. → pass `audioModule`.
2. Master-gain capture used `LIVE.gains[0]` after `reset()` had emptied the array, so
   the mixer check read `undefined.gain`. → the first gain ever created is now kept
   across `reset()` (`js/audio.js:14` creates the master first, the music bus at `:148`).
3. Anchor scheme assumed each row's `synth` range contains the method head. `point(win)`
   at `js/audio.js:85` produces two catalogue rows (`:86-89`, `:90-92`), so both failed.
   → each row now carries an explicit `head` anchor (added to `audition-core.js`), and
   the `bandpass` filter type is checked against the `noise()` helper (`js/audio.js:48-50`)
   where it is declared once, instead of inside every caller's range.
4. The fake `setTimeout` advanced the clock cumulatively, double-counting the note
   stagger (`point-win` note 3 measured at 0.3 s instead of 0.2 s). → replaced with a
   time-ordered timer queue flushed after each play.
5. `initAudio()` site count: `js/main.js:2484` is `addEventListener("pointerdown", initAudio, …)`,
   a *reference* with no parens, so the "6 call sites" expectation could never hold.
   → 5 direct calls + 1 reference, both asserted.
6. The page's own bake (`index.html`, `window.__auditionBake`) rendered the wrong
   context for sounds that stagger with `setTimeout` (`point-win`, `victory`): those
   touch the AudioContext only when the timer fires, so the bake rendered the previous,
   already-rendered context and threw `InvalidStateError: … in a stopped state`.
   → the bake now waits `settleMs` (900 ms) for the timers before taking the context,
   and fails loudly if no context was created.
7. The mixer probe first used `hit()` and came out at ratio 0.512 / 0.529 — flaky,
   because `hit()`'s peak includes a fresh random noise burst per render. It now
   measures `bounce()` (one sine sweep, no noise) and reads exactly `0.5000` on two
   consecutive runs; the tolerance was tightened from ±0.02 to ±0.005 to match.

## Catalogue — every sound the game makes (15 rows)

One-shots are `js/audio.js` `sfx` methods; music voices are the sequencer's layers.
All synthesis goes through `tone()` (`js/audio.js:22-37`), `noise()` (`:39-58`) and
`mTone()`/`mKick()`/`mHat()` (`:155-221`); master gain 0.5 (`:4-5, 15`), music bus
0.55 (`:149`). "Verified" = the row appears in the 54/54 stub run **and** rendered
audible in the Chromium run.

### One-shots

| # | Sound | Trigger (source anchor) | Synthesis parameters (`js/audio.js`) | Measured peak / RMS (Chromium) | Godot realisation | Reason |
|---|---|---|---|---|---|---|
| 1 | `hit` — paddle hit | `js/game.js:1893` `hitBall()`, every successful contact | `triangle 230→92 Hz, dur 0.09 s, gain 0.4` (`:62`) + `noise 0.04 s bandpass 2800 Hz, gain 0.12` (`:63`) | 0.2095 / 0.00723 | **Baked, 6 randomized variants, `AudioStreamRandomizer`** | The noise term is `Math.random()` per play (`:45`), so a single bake would freeze the grain. 6 variants + ±3 % pitch restore the stochastic texture; the tonal sweep is deterministic and bakes exactly. |
| 2 | `bounce` — ground bounce | `js/game.js:2209` `handleGroundBounce()` | `sine 150→68 Hz, dur 0.1 s, gain 0.3`, no noise (`:66`) | 0.1266 / 0.00658 | **Baked, single file** | Fully deterministic, no noise term: one WAV is bit-faithful and there is nothing a live synth adds. |
| 3 | `wall` — wall / glass | `js/game.js:2363` `handleWalls()` | `noise 0.16 s bandpass 900 Hz, gain 0.32` (`:69`) + `sine 92→54 Hz, dur 0.22 s, gain 0.4` (`:70`) | 0.2297 / 0.01338 | **Baked, 6 randomized variants** | Same randomness reason as `hit`; also the loudest, lowest one-shot (gain 0.4), so its level must not drift — variant selection with a fixed gain keeps it peak-matched. |
| 4 | `net` — net contact | `js/game.js:2382` `handleNetCollision()` | `noise 0.06 s bandpass 1600 Hz, gain 0.16` + `triangle 310→170 Hz, dur 0.06 s, gain 0.18` | 0.0887 / 0.002711 | **Baked, 6 randomized variants** | Shortest noise burst in the game (0.06 s) — the grain is most audible here; variants matter more than for any other sound. |
| 5 | `serve` — serve contact | `js/game.js:750` `performServe()` | `noise 0.22 s bandpass 600 Hz, gain 0.12` + `sine 330→720 Hz RISING, dur 0.18 s, gain 0.12` | 0.0650 / 0.003969 | **Baked, 6 randomized variants** | Only upward-swept tone in the game; the rising sweep is what makes a serve recognisable, so it must bake exactly (exponential ramp reproduced at bake time, not approximated). |
| 6 | `special` — energy-bar shot | `js/game.js:1898` `hitBall()` with `isSpecial` (fires *on top of* the `hit` at `:1893`) | `noise 0.3 s bandpass 1400 Hz, gain 0.2` + `sawtooth 1200→240 Hz, dur 0.3 s, gain 0.14` + `sine 210→90 Hz, dur 0.3 s, gain 0.2` | 0.1827 / 0.009293 | **Baked, 4 variants × 2 layers if layering is kept** | Three simultaneous voices and the game deliberately plays `hit` + `special` together; keeping them as two baked players preserves the additive mix the stub verifies, and lets the special be attenuated if Godot ducking differs. |
| 7 | `point-win` | `js/game.js:2111` `scorePoint()`, winner player, no result yet | `triangle 523 / 659 / 784 Hz`, `dur 0.16 s, gain 0.22`, staggered 0/100/200 ms by `setTimeout` (`:86-89`) | 0.2270 / 0.008738 | **Baked as ONE sequence file** | The stagger uses wall-clock `setTimeout`; in Godot a single 0.36 s WAV is frame-independent and identical. Scheduling three one-shots from a timer would re-introduce a timing bug for no gain. |
| 8 | `point-loss` | `js/game.js:2111`, winner AI, no result yet | `triangle 240→150 Hz, dur 0.28 s, gain 0.2` (`:91`) | 0.0991 / 0.006455 | **Baked, single file** | One descending tone, deterministic — deliberately the inverse shape of `point-win`; that contrast is the feature and a single bake preserves it. |
| 9 | `victory` — match won | `js/game.js:2113` `scorePoint()` with `state.result`, player | `triangle 659 / 784 / 1047 / 1319 Hz`, `dur 0.2 s, gain 0.24`, staggered 0/130/260/390 ms (`:94-98`); music already stopped by `js/main.js:1385` | 0.3291 / 0.01282 | **Baked as ONE sequence file** | Same reason as row 7. Also the loudest measured render, and it plays after the music bus is torn down, so it needs no mixing with the score. |
| 10 | `defeat` — match lost | `js/game.js:2115`, `state.result`, winner AI | `triangle 392 / 330 / 262 / 196 Hz`, `dur 0.28 s, gain 0.2`, staggered 0/180/360/540 ms (`:99-103`) | 0.2334 / 0.011356 | **Baked as ONE sequence file** | 540 ms of stagger and a 0.28 s tail: as a bake it is one asset; as a timer chain it is four chances to drift. |

### Music voices (generative, not event-triggered)

The score is a 40 ms scheduler (`js/audio.js:130`) with a 150 ms lookahead
(`:264-265`), 16 steps per bar, 64-step loop (`:269`), over `PROG` (`:110-115`):
Am `[0,3,7,12]` → Fmaj7 → C → G, `[0,4,7,12]` each.

| # | Voice | Gate (`js/audio.js`) | Synthesis parameters | Godot realisation | Reason |
|---|---|---|---|---|---|
| 11 | `music-bass` | every step where `s % 4 === 0` (`:229`), plus `s % 4 === 2` when `inten > 0.6` (`:231`) | `triangle midiToFreq(root-12)`, lowpass 520 Hz, `dur 0.24 s, gain 0.15`; off-beat echo `dur 0.12 s, gain 0.07` | **Mix: baked one-shot + ported sequencer** | The bass note changes with the chord and its gate changes with intensity, so it cannot be a static loop. Baked per-note samples (Am/F/C/G × 2 rates) triggered by the ported step clock keep the exact 4-chord vocabulary. |
| 12 | `music-pad` | `s === 0` of every bar (`:235-239`) | 3 × `sine` on `intervals.slice(0,3)`, `dur 1.7 s, gain 0.032, attack 0.35 s`, no filter | **Mix: baked 1.7 s pad per chord + ported sequencer** | 4 chords → 4 baked samples; a 1.7 s exponential release does not survive a naive live-synth port, and this is the wash that makes an empty rally still sound like music. |
| 13 | `music-arp` | `inten > 0.4`, every step (`:241-252`) | `square midiToFreq(root + intervals[s % 3] + octave)` — octave 12 for `s % 8 < 4`, else 24; lowpass 2200 Hz, `dur 0.09 s`, `gain 0.028 + inten*0.03` | **Mix: baked arp samples + ported sequencer** | Gain tracks intensity continuously, so it must be a per-note player with a runtime volume, not a crossfaded loop. |
| 14 | `music-kick` | `inten > 0.72` and `s % 4 === 0` (`:254-255`) | `sine 130→42 Hz over 0.12 s, gain 0.2` hard-set, stop at +0.18 s (`:182-198`) | **Mix: one baked kick sample + ported sequencer** | 0.18 s, one timbre, gated on/off: a single baked sample is exact and the gate is the only variable. |
| 15 | `music-hat` | `inten > 0.72` and `s % 2 === 1` (`:256`) | `0.04 s noise highpass 7000 Hz`, `gain 0.02 + (inten-0.72)*0.1` (`:200-221`) | **Mix: 3 baked hat variants + ported sequencer** | 0.04 s bursts of white noise: 3 variants avoid the machine-gun effect of one repeated sample, and the runtime gain keeps the intensity ramp. |

### Why no row keeps live synthesis

Godot 4.7 has no WebAudio-style node graph: the procedural option is
`AudioStreamGenerator` + `AudioStreamGeneratorPlayback`, which requires pushing buffers
per frame from `_process` and cannot schedule a 40 ms event with a 3 ms attack and an
exponential release at the exact sample the way `setValueAtTime` /
`exponentialRampToValueAtTime` do (`js/audio.js:30-32`). Every one of the 15 rows is
either fully deterministic (bake it) or stochastic only in its noise grain (bake
variants). So the port keeps **synthesis-free audio** and ports only the *scheduling
logic*. Live synthesis would come back if a future sound needs a parameter that
`pitch_scale` cannot express — a continuous pitch glide tied to ball speed, say — and
then only for that sound.

## How rally intensity still drives the music in the Godot realisation

Web build, verified by the stub (`music: intensity driver`, `music: tempo table`,
`music: gates` checks all PASS):

- `js/main.js:1220-1226`, once per rendered frame:
  `rallyTension = min(1, rallyHits / 12)`; `stakes = min(0.35, (sets.player+sets.ai)*0.15 + (games.player+games.ai)*0.02)`;
  `music.setIntensity(min(1, 0.12 + rallyTension*0.55 + stakes))`.
- `js/audio.js:140` clamps to `[0,1]`; `:267` turns it into tempo:
  `secondsPerBeat = 60 / (96 + intensity * 54)` → 96 BPM at 0, 123 at 0.5, 150 at 1
  (`bpmForIntensity()` reproduces this exactly in the passing check).
- `playStep()` (`:223-258`) turns it into arrangement: arp on above 0.4, off-beat bass
  above 0.6, kick+hat above 0.72. Intensity is read at *schedule* time, so a rally
  change lands within the 150 ms lookahead.
- Start/stop parity: `music.setIntensity(0.12); music.start()` at match start
  (`js/main.js:1158-1159`), `music.stop()` on match end (`:1385`) and quit (`:1553`),
  and `pauseGame()` deliberately does **not** stop it (`:1530-1545`, asserted).

Godot realisation: an autoload `Music` node holding the ported sequencer. It is fed the
same three simulation inputs (`rallyHits`, sets, games) from the ported `MatchState`
(cf. [Simulation port boundary](../tickets/simulation-port-boundary.md) — audio calls are
one of the four named couplings), recomputes intensity in `_process` with the identical
formula and clamps, and applies, at each scheduled step:

1. tempo from the same `60 / (96 + intensity*54)` — an accelerating 16th-note clock, not
   a BPM-synced loop;
2. the same three gates (0.4 / 0.6 / 0.72) deciding which baked voice samples are fired;
3. the same continuous gains (`0.028 + intensity*0.03` on the arp,
   `0.02 + (intensity-0.72)*0.1` on the hat) applied as per-voice `volume_db`;
4. the same 40 ms scheduler tick with a 150 ms lookahead, so the ramp feels identical
   instead of stepping once per frame.

Rejected alternative: bake three intensity "stems" and crossfade. It is cheaper but it
loses the tempo ramp (the most felt part of a long rally) and quantises the layer
entries, so it is recorded here as the fallback, not the choice.

## How the reduced-motion branch is honoured

Fact, verified by `grep -n "reduce\|motion\|Motion" js/audio.js` → **no match**: the
audio module has no reduced-motion branch. Reduced motion only

- scales particle counts in `js/fx.js:26` (`if (reducedMotion) count = max(2, round(count*0.35))`),
- caps screen shake in `js/fx.js:63` (`if (reducedMotion) fx.shake = min(fx.shake, 0.5)`),
- toggles the `body.reduce-motion` CSS class (`js/main.js:2301`, styles at `styles.css:2715-2722`),
- is persisted as `prefs.reduceMotion` (`js/ui.js:283, 435`; restored `js/main.js:2214`; toggled `:2413`).

So there is nothing in audio to honour, and the Godot port must preserve that: **the
reduce-motion setting must not change a single audio event.** In the port, motion
reduction stays in the effects layer (`fx.js` → Godot particles/shake), and the audio
autoload does not read the setting. That parity is now testable in the web build by
toggling the option and re-running `verify_browser.py`: the renders must be identical
apart from the random noise grain. If a later session wants motion-linked audio cues
(quieter impacts under reduced motion, say), that is a new decision for Luca — it must
not be smuggled in as a "port" of a branch that does not exist.

## Chromium render (real browser, numeric — not a listening test)

`python3 tools/audio-audition/verify_browser.py`, exit 0. Offline render of the game's
real `js/audio.js` inside headless Chromium, 1.5 s @ 44.1 kHz, `settleMs` 900:

```
sound              peak        rms  audible s  verdict
hit            0.201092   0.007223     0.0818  audible
bounce         0.126635    0.00658     0.0915  audible
wall           0.217372   0.013364     0.1959  audible
net            0.089714   0.002673     0.0532  audible
serve          0.064617   0.003944     0.1669  audible
special        0.157946   0.009228     0.2861  audible
point-win      0.227046   0.008738     0.1848  audible
point-loss     0.099057   0.006455     0.2517  audible
victory        0.329079    0.01282     0.2248  audible
defeat         0.233375   0.011356     0.3084  audible
muted-special          0          0          0  silent as designed
mixer: bounce() peak 0.12663531303405762 @ volume 0.5 vs 0.06331765651702881 @ volume 0.25 -> ratio 0.5000
11/11 renders as expected
```

Run twice back to back, exit 0 both times; the mixer ratio was `0.5000` in both.
Peaks for the noise-bearing sounds (`hit`, `wall`, `net`, `serve`, `special`) move a
few percent between runs because their noise burst is a fresh `Math.random()` draw
(`js/audio.js:45`) — the tone-only rows (`bounce`, `point-loss`) are identical run to run.

Cross-check against the source numbers: `hit` 0.2011 ≈ tone gain 0.4 × master 0.5 = 0.2;
`victory` 0.3291 ≈ 0.24 × 0.5 = 0.12 plus four overlapping notes. 10 WAVs are written to
`tools/audio-audition/baked/` for a human ear check.

## Honest limits

1. **No listening test, and none claimed.** This host has no sound device; headless
   Chromium was launched with `--mute-audio`. The checks above are numeric measurements
   of a real render plus API-level assertions. Whether the port *feels* right is Luca's
   call, and the ticket says feel is signed off by a human, not by tests.
2. **Music is not rendered end-to-end.** `verify-stub.mjs` proves the sequencer's
   tempo formula, gates, voice parameters and start/stop anchors from source; nothing
   here renders the 64-step loop through Chromium, because the scheduler is driven by
   `setInterval` and an `OfflineAudioContext` does not advance it. The music realisation
   decision above is therefore source-verified, not render-verified.
3. **Stagger timing inside the browser bake collapses.** In an offline render
   `ctx.currentTime` stays 0 until `startRendering()`, so `point-win` / `victory` /
   `defeat` notes land at t=0 rather than at 0.1/0.2 s. Their *offsets* are proven by
   the stub check instead (measured `at` values), and their audibility by the browser.
4. `verify_browser.py` is a new script written in this task; it needs
   `python3` + Playwright Chromium, which this host has. It is not wired into
   `npm run audit` (that suite drives the game's `scripts/` verifiers and is green at
   27/27, exit 0) — wiring it in is a separate, unclaimed decision.
5. The mixer ratio came out 0.512 rather than exactly 0.500 because each render draws
   fresh `Math.random()` noise; the tolerance is ±0.02 and the script records the value
   rather than rounding it away.
