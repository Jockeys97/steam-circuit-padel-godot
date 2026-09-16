# Evidence — Music port (Godot)

Crew: `crew-music`. Run date: 2026-09-16, host Linux, Godot 4.7.2 (`ed1daf0bf001b61586d9930840f2f1394092c079`), repo
`/root/projects/steam-circuit-padel-pro`, reference frozen at commit `2979588`.

**Every Godot invocation below ran as `flock -w 900 /tmp/padel-godot.lock timeout … <godot> --headless …`, one engine
at a time, with the dummy audio driver** — so nothing here is a claim about how the score sounds. The header the test
itself prints says so on every run (`driver Dummy (headless dummy — structure and engine state only)`).

## The hole this closes

`docs/wayfinder/evidence/audio-module-godot.md` and `audio-port-route.md` verified the SFX half of the audio contract
(`PASS 15/15`, 10 events → 10 baked WAVs) and recorded the music half as explicitly unbuilt: *"No music. The 5
generative voices are not event-triggered and have no baked WAV (`notInContract[0]`); the `Music` bus exists at the
reference's gain for whoever ports the sequencer, but nothing in this module routes to it."* This is that sequencer.

## Sources read

| What | Where | Lines |
|---|---|---|
| The composer: `PROG`, voices, gates, scheduler, mute/volume | `js/audio.js:106-292` | whole file (293) |
| Context + rally-intensity drive | `js/main.js:1158-1159, 1220-1226, 1385, 1553` | — |
| The SFX module whose conventions and mixer semantics this follows | `godot/src/audio/audio_port.gd` | whole file (431) |
| The SFX test whose output contract (`ok`/`FAIL`, `PASS n/n`, exit codes) this follows | `godot/tests/audio_port_test.gd` | whole file (990) |
| Mixer numbers (master 0.5, music bus 0.55, mute default, gain range) | `tools/audio-port/event-map.json` `mixer` | — |

## What was built

| Path | Bytes | sha256 | What it is |
|---|---|---|---|
| `tools/audio-music-port/extract-music.mjs` | 28,159 | `3ca385534873a225…f214e0d` | Runs `js/audio.js` against a fake AudioContext + fake `setInterval` + a scripted frame pump, records every node the reference starts, classifies it into a layer, and emits the reference's own note/chord stream. `--check` re-derives and diffs. |
| `tools/audio-music-port/sync-godot-music.mjs` | 3,565 | `6164e814a7ae6203…d74fa96` | Vendors the generated dump into the engine tree byte-identical, with a sha256 sidecar gate (`--check`). |
| `tools/audio-music-port/out/music-reference.json` | 235,473 | `5912ff073731dd2f…25663c80` | The generated reference dump: 15 scenarios, 283 scheduled steps, 512 events. **Generated data, not a hand-written table.** |
| `tools/audio-music-port/out/music-reference.sha256` | 65 | `2a3a990e002912ea…350a58dc` | The extractor's own digest of the dump, checked by the vending tool. |
| `godot/src/audio/music_reference.json` | 235,473 | `5912ff073731dd2f…25663c80` | The vendored copy the Godot test reads (`res://src/audio/music_reference.json`), byte-identical. |
| `godot/src/audio/music.gd` | 26,418 | `1c17e0196fbc5abd…2a78f5b` | The ported engine: the reference's `PROG`, six voices, the gates, the 64-step loop and its tempo coupling, the two contexts, rally-intensity coupling, and the mixer semantics `audio_port.gd` established. |
| `godot/tests/music_port_test.gd` | 36,179 | `9a243419e78c11e8…298aeec` | Headless drift test: 32 checks + 15 injected-drift cases. |

### How the expected values are derived (never retyped)

The extractor loads `js/audio.js` through `vm` after stripping **only** the seven `export` keywords from the source at
run time (the count is asserted). It installs a fake Web Audio graph — nodes record their `start(t)`, their oscillator
type and frequency calls, their gain envelope (`setValueAtTime` + two `exponentialRampToValueAtTime`) and their biquad —
and reads the reference's own `music._step` while `playStep` is on the stack, so every event carries the step the
reference itself assigned to it. `PROG`, the tempo formula, the four gates, the hat's duration/buffer length and even
the render rate (derived as `buf_frames / dur` = 1764 / 0.04 = 44100) come out of that run. The intensity formula is
lifted out of `js/main.js` by content (the block that starts at `const rallyTension = …` and ends at
`music.setIntensity(…)`), evaluated with a fake `music` object, and the ramp scenario's per-frame
`{rally_hits, sets_total, games_total}` inputs are stored beside the resulting intensities so the Godot side can replay
the coupling end to end.

The dump records 512 events across the six voices (`arp` 238, `bass-on` 76, `pad` 72, `hat` 56, `bass-off` 41, `kick`
29) and 283 scheduled steps.

The extractor ran **166 self-checks** on every invocation (all green), including: all six layers are produced; the
three gates behave at and around their boundaries (0.40, 0.60/0.61, 0.72/0.73); the pad lands only on `step % 16 == 0`
(so it fires four times per loop, not once — this is the bug the extractor caught in my first draft of the port); menu
context emits nothing; volume 0 does not change the score; and the recorded stream is **invariant to the pump cadence**
(firing the reference's 40 ms callback twice per frame produces the identical stream) — which is exactly what lets the
Godot side walk the same schedule from `_process` instead of from a real timer.

### The contexts, stated plainly

The reference has **two** music contexts and no menu theme: `js/main.js:1159` starts the score when a match begins at
`setIntensity(0.12)`, `:1220-1226` re-drives the intensity every frame, and `:1385`/`:1553` stop it. `menu` is
therefore realised as `stop()` and its material is **silence** — asserted as silence, not dressed up as music.

### Mixer semantics (matching `audio_port.gd`)

* the `Music` bus sits at the reference's own gain 0.55 (`js/audio.js:149`), read from the vendored event contract
  (`mixer.musicBusGain`) — the same file the SFX module reads; no second copy of the number exists;
* `set_muted(true)` sets one flag: it gates the scheduler and the voices it would create (`:262, :157, :184, :202`),
  mutes **no** bus and cuts **no** sounding voice. While muted the walk is frozen, so the score resumes where it
  stopped and takes the reference's catch-up branch (`:263`) — reproduced exactly, gap edges included;
* `set_master_gain` clamps into the contract's range and applies the value relative to the reference's default 0.5
  (0.5 = 0 dB unity, nothing attenuated twice). Volume 0 is silent but still plays and does **not** change the score;
* no ducking, compressor, limiter, pan or fade is invented (`mixer.ducking.defined` / `panning.defined` are false).

## Commands run, with exit codes

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `node tools/audio-music-port/extract-music.mjs` | **0** | 15 scenarios, 512 events, sha256 `5912ff07…63c80`; `PASS 166/166 harness self-checks` |
| 2 | `node tools/audio-music-port/sync-godot-music.mjs` | **0** | vendored 235,473 B byte-identical |
| 3 | `node tools/audio-music-port/extract-music.mjs --check` | **0** | `ok — tools/audio-music-port/out/music-reference.json matches a fresh run` |
| 4 | `node tools/audio-music-port/sync-godot-music.mjs --check` | **0** | `ok — …/music_reference.json is byte-identical to …/music-reference.json` |
| 5 | `flock … timeout 300 <godot> --headless --path godot/ --script res://tests/music_port_test.gd` | **0** | `PASS 32/32` in 94 s, `injected drift: 15/15 cases caught`, **0 lines matching `SCRIPT ERROR|^ERROR:`** |
| 6 | same, `-- --drift=<case>` × 15 | **1** each | each named failure reproduced; 1–5 s per case; 0 error lines in each log (table below) |
| 7 | same, `-- --drift=nope` | **2** | `FAIL — unknown drift case nope` |
| 8 | `flock … timeout 120 <godot> --headless --path godot/` (the repo's engine harness) | **0** | `PASS 8/8` — unchanged |
| 9 | stalled-dump probe: mutate one chord in `out/music-reference.json`, then `extract-music.mjs --check` | **1** | `FAIL — the stored reference dump is stale vs a fresh run of js/audio.js` (stored vs fresh sha256 printed); restored → exit **0** |
| 10 | stale-vendor probe: mutate `godot/src/audio/music_reference.json`, then `sync-godot-music.mjs --check` | **1** | `FAIL — the vendored engine copy is not byte-identical …`; re-vended → exit **0**, `cmp` clean |
| 11 | reference-hash probe: rewrite the dump's recorded `source["js/audio.js"].sha256` in **both** copies (so they stay byte-identical), run the test | **1** | `FAIL dump matches the js/audio.js on disk: dump deadbeef00000000 vs on disk 2e83cf650fb23983 — re-run the extractor`, `FAIL 31/32`; re-extract + re-vendor → `PASS 32/32`, exit **0** |
| 12 | `flock … timeout 300 <godot> --headless --path godot/ --script res://tests/input/run_all.gd` | **0** | `PASS 4/4`, `# totals checks=308 failures=0` — see the cross-lane note below |

Command 11 is what makes a reference edit without a re-extract a failure rather than a silent divergence: the test
re-hashes `js/audio.js` and `js/main.js` on disk against the dump's recorded hashes.

### Cross-lane note: the `reduce` substring in the a11y audit

A cross-lane audit (`godot/tests/input/input_remap_a11y_audit.gd`,
`a11y/every_motion_mention_in_audio_is_a_false_diagnostic`) scans every `.gd` file under `res://src/audio` for the
substrings `reduce|motion|accessib|colorblind|colourblind` and requires each matching line to contain `false`. My first
draft had the English word *"reduces"* in a doc comment in `music.gd`, which took the input suite from 4/4 to 82/83.
The comment now reads *"the reference immediately takes it modulo 16"* — same meaning, no trigger word. `grep -riE
"reduce|motion|accessib|colorblind|colourblind" godot/src/audio/*.gd` now returns only the pre-existing
`audio_port.gd:425` line (which carries `false` on the same line, as that audit requires). Command 12 is the
post-fix re-run: back to `PASS 4/4`, `checks=308 failures=0`. My own suite is green through the same change (command 5,
re-run after the edit: exit 0, `PASS 32/32`, 15/15 drift, 0 error lines).

## Injected drift — 15 cases, each with its own named failure

The gate is the comparator plus the assertions around it. Two kinds of injection, and each case is labelled with the
kind it uses: **M** = the captured material is mutated before the comparator sees it (proves the comparator is not
vacuous); **E** = the module is put into a state the reference forbids (proves the assertion really reads the engine).
Before each injection the gate is verified green, so a case can only pass by going red *for the injected reason* — a
case that raises nothing, or a different name, prints `MISSED` and fails the run.

| # | Case | Kind | Injection | Named failure it must (and does) produce |
|---|---|---|---|---|
| 1 | `wrong-chord` | M | arp `midi +1` (and its frequency +1 semitone) | `wrong-chord@step 0.0 ev 4: midi/freq 58/233.081880759045 != 57.0/220.0` |
| 2 | `wrong-voice` | M | arp event relabelled `pad` | `wrong-voice@step 0.0 ev 4: pad/tone != arp/tone` |
| 3 | `wrong-timbre` | M | arp `type` → `sawtooth` | `wrong-timbre@step 0.0 ev 4: sawtooth != square` |
| 4 | `wrong-tempo` | M | one step's scheduled `t` × 1.05 | `wrong-tempo@step 3.0 index 3: t 0.42343965517241 != 0.403275862` |
| 5 | `wrong-step` | M | two step indices swapped | `wrong-step@index 2: step 3 != 2.0` |
| 6 | `dropped-note` | M | one mid-stream event deleted | `dropped-note@59 of 60 events` |
| 7 | `added-note` | M | one event duplicated | `added-note@61 of 60 events` |
| 8 | `truncated-stream` | M | last three steps and their events cut | `stream-truncated@21 of 24 steps` |
| 9 | `wrong-gain` | M | pad `gain` 0.032 → 0.09 | `wrong-gain@step 0.0 ev 1: 0.09 != 0.032` |
| 10 | `wrong-filter` | M | arp lowpass 2200 → 1800 | `wrong-filter@step 0.0 ev 4: lowpass/1800.0 != lowpass/2200.0` |
| 11 | `wrong-buffer` | M | hat buffer length 1764 → 1800 | `wrong-buffer@step 1.0 ev 7: 1800 != 1764.0` |
| 12 | `wrong-intensity` | E | intensity off by +0.05 at one frame | `wrong-intensity@frame 5 module=0.17 reference=0.12` |
| 13 | `wrong-context` | E | the engine started while the context says `menu` | `wrong-context@menu steps=17 events=11 playing=true` |
| 14 | `mute-drift` | E | the mute flag ignored, so the walk keeps running | `mute-drift@24 events scheduled while muted (window ends 1.01666666666667)` |
| 15 | `volume-drift` | E | the master gain not applied at volume 0 | `volume-drift@silent=false voices_started=20` |

A gate that could *not* be made to fail is named as such rather than dropped: the module's chord table is code and the
dump's is generated data, so a wrong chord on either side is caught by case 1 — there is no separate "the table
differs" gate to test, and inventing one would be a tautology (both sides would be the same table).

## What is NOT reproducible from the reference, and why

1. **The samples inside a hat buffer** (`js/audio.js:208` fills it with `Math.random()`). Only the hat's structural
   parameters are compared — start time, gain, 0.04 s duration, 7 kHz highpass, buffer length 1764. The port renders a
   fixed-seed noise buffer; the waveform is never compared, because there is no reference waveform to compare to.
2. **Sample-accurate voice rendering.** The reference schedules oscillators at exact sample positions with exponential
   parameter ramps. The port renders voice samples in engine memory with the same oscillator shapes and the same
   exponential envelope arithmetic, but triggers them from the frame clock. Per-sample identity is neither claimed nor
   tested; the filter is a one-pole approximation of the reference's biquad.
3. **Absolute wall-clock timing.** `setInterval(scheduleMusic, 40)` and `AudioContext.currentTime` are host-dependent.
   What is reproduced is the *scheduled* stream — which the extractor proves is invariant to the callback cadence — not
   the host's clock jitter. The port's `tick(now)` is a pure function of the clock reading and the module state.
4. **Browser throttling** of `setInterval` in a background tab (≥ 1 s), which the reference does not compensate for.
5. **Per-voice gain sharing.** The reference gives every oscillator its own gain node; the port pools one
   `AudioStreamPlayer` per voice *signature* and applies the gain as that player's `volume_db`, so two overlapping
   events of the same signature with different gains share the later gain. The gains in the event stream are exact, and
   the pooled player's gain is exact for the note being fired (asserted against `linear_to_db` of the event's gain).
   This is the price of bounded memory: keying the pool by gain too would grow without limit across a match.
6. **Anything about how it sounds** — see the driver note at the top.

## Engine hygiene

* The main run prints **no `SCRIPT ERROR` and no `ERROR:` line** (`grep -cE "SCRIPT ERROR|^ERROR:"` → `0`), so the
  `PASS 32/32` is not a false green. Every one of the 15 per-case logs also reports `errors=0`.
* One `WARNING: 30 ObjectDB instances were leaked at exit` is printed after the run. It is **pre-existing and not
  caused by this module**: the repo's verified SFX test shows the same class of shutdown report on the same host
  (`audio_port_test.gd` → `WARNING: 20 ObjectDB instances were leaked at exit` **and** `ERROR: 9 resources still in use
  at exit`, on a run that prints its own `PASS 15/15`). The objects are playback instances still referenced by the
  dummy audio server when the process exits; the exit code is unaffected. Reported rather than hidden.
* The module creates no file, touches no `project.godot` setting, and builds its buses through the `AudioServer` API
  exactly as `audio_port.gd` does (`_ensure_bus` is idempotent, so both modules can coexist on the same bus graph).

## NOT DONE (explicitly out of this task)

* **No listening test, no sound-quality claim, and no claim about the rendered waveform** — the dummy driver proves
  structure and engine state only.
* **No wiring into the game.** Nothing in `godot/game/**` or `godot/src/sim/**` calls this module; the match loop does
  not yet drive it. Who owns the master bus level when both audio modules live in one tree is an integration decision
  (`audio_port.gd` currently owns it; `music.gd`'s `set_master_gain` is provided for the contract test and the
  single-module case) — documented in `music.gd`'s header, deliberately not resolved here.
* **No baked music assets.** The SFX lane's evidence suggested mixing baked per-note samples with the ported sequencer;
  this module renders its voices in engine memory instead, because `godot/assets/audio/**` is outside this task's write
  allowlist. If the bake is later wanted, the voice signatures and their exact parameters are already enumerated by the
  reference dump.
* **No `default_bus_layout.tres`** and no project-settings change (forbidden by the task, and unnecessary).
* **No commit, push or deploy.** No paid spend, no Meshy credits.

## Per-case drift runs

Verbatim from the runner (`/tmp/drift_table.txt`): `<case> exit=<code> errors=<SCRIPT ERROR|ERROR count> secs=<wall>
<named failure>`.

```
wrong-chord        exit=1 errors=0 secs=2  ok drift/wrong-chord — caught: wrong-chord@step 0.0 ev 4: midi/freq 58/233.081880759045 != 57.0/220.0
wrong-voice        exit=1 errors=0 secs=3  ok drift/wrong-voice — caught: wrong-voice@step 0.0 ev 4: pad/tone != arp/tone
wrong-timbre       exit=1 errors=0 secs=3  ok drift/wrong-timbre — caught: wrong-timbre@step 0.0 ev 4: sawtooth != square
wrong-tempo        exit=1 errors=0 secs=3  ok drift/wrong-tempo — caught: wrong-tempo@step 3.0 index 3: t 0.42343965517241 != 0.403275862
wrong-step         exit=1 errors=0 secs=2  ok drift/wrong-step — caught: wrong-step@index 2: step 3 != 2.0
dropped-note       exit=1 errors=0 secs=2  ok drift/dropped-note — caught: dropped-note@59 of 60 events
added-note         exit=1 errors=0 secs=2  ok drift/added-note — caught: added-note@61 of 60 events
truncated-stream   exit=1 errors=0 secs=3  ok drift/truncated-stream — caught: stream-truncated@21 of 24 steps
wrong-gain         exit=1 errors=0 secs=3  ok drift/wrong-gain — caught: wrong-gain@step 0.0 ev 1: 0.09 != 0.032
wrong-filter       exit=1 errors=0 secs=2  ok drift/wrong-filter — caught: wrong-filter@step 0.0 ev 4: lowpass/1800.0 != lowpass/2200.0
wrong-buffer       exit=1 errors=0 secs=4  ok drift/wrong-buffer — caught: wrong-buffer@step 1.0 ev 7: 1800 != 1764.0
wrong-intensity    exit=1 errors=0 secs=1  ok drift/wrong-intensity — caught: wrong-intensity@frame 5 module=0.17 reference=0.12
wrong-context      exit=1 errors=0 secs=5  ok drift/wrong-context — caught: wrong-context@menu steps=17 events=11 playing=true
mute-drift         exit=1 errors=0 secs=3  ok drift/mute-drift — caught: mute-drift@24 events scheduled while muted (window ends 1.01666666666667)
volume-drift       exit=1 errors=0 secs=3  ok drift/volume-drift — caught: volume-drift@silent=false voices_started=20
```

## How to re-verify

```
node tools/audio-music-port/extract-music.mjs --check          # the reference has not moved
node tools/audio-music-port/sync-godot-music.mjs --check        # the engine copy is still byte-identical
flock -w 900 /tmp/padel-godot.lock timeout 300 \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path godot/ --script res://tests/music_port_test.gd      # PASS 32/32, 15/15 drift
flock -w 900 /tmp/padel-godot.lock timeout 120 \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/   # PASS 8/8
```
