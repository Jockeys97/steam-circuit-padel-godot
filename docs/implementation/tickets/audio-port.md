# Audio port (slice S10)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Quick-match vertical slice in 3D](quick-match-slice.md) technically: the events this slice turns into sound are the ones the simulation already emits and the view already routes. Acceptance is **not** blocked by a human decision — the audio route is resolved — but the route's own open item is carried: the reference defines no loudness or ducking targets, and no listening test has been made on this host. The module may be built now; "it sounds right" is Luca's ear call and stays open.

This ticket implements row S10 of `docs/implementation/PLAN.md` ("Audio port"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S11 through S13.

## Objective

Implement the Godot audio module against the contract that already exists, so that the port makes the same fifteen sounds the reference makes, from the same triggers, with the same generative music behaviour, and with no live synthesis. The route is resolved and written down: ten one-shot sounds are baked WAVs, five music voices are baked per-voice samples played by a ported step sequencer, and the rally-intensity formula that drives the sequencer is ported rather than approximated. The reference defines no loudness or ducking targets, so the port defines none and records the gap instead of guessing.

The event contract is already verified and is the input to this slice: ten events map to the ten baked WAVs, every anchor resolves to a real call site in the reference, and a test fails on drift. What does not exist yet is the Godot module — no audio module, no bus, no playback — which is precisely this slice. The module has **one owner**: `godot/src/audio/**` is the audio lane's directory, this ticket is its implementation plan, and no second writer may create a parallel module or duplicate a bus.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/audio.js:8` | `ctx()`, the lazily created WebAudio context — the object the port replaces with an `AudioServer` bus layout |
| `js/audio.js:22` | `tone({ freq, freqEnd, type, dur, gain, attack })` — the tonal primitive, with a 3 ms attack (`attack: 0.003`) |
| `js/audio.js:39` | `noise({ dur, gain, filterFreq })` — the filtered-noise primitive |
| `js/audio.js:45` | The noise buffer filled with **global `Math.random`** per play. This is why five sounds bake as randomised variants instead of one frozen file |
| `js/audio.js:60-104` | `sfx`, the nine methods that make ten sounds: `hit` (`:61`), `bounce` (`:65`), `wall` (`:68`), `net` (`:72`), `serve` (`:76`), `special` (`:80`), `point(win)` (`:85`, splitting into point-win and point-loss), `victoryMatch` (`:94`), `defeatMatch` (`:99`) |
| `js/audio.js:88, 96, 101` | The `setTimeout` note chains inside `point`, `victoryMatch` and `defeatMatch` — four chances to drift, which is why each bakes as a single sequence file |
| `js/audio.js:106` | `midiToFreq(midi)` — the note helper the sequencer uses |
| `js/audio.js:117` | `music`, the sequencer surface (`start`, `stop`, `setIntensity`, gain per voice) |
| `js/audio.js:144` | `musicBus()` — the music gain node |
| `js/audio.js:155, 182, 200` | `mTone`, `mKick`, `mHat` — the five voices' primitives |
| `js/audio.js:223` | `playStep(step, time)` — the step scheduler: chord table, gates and per-voice parameters |
| `js/audio.js:260` | `scheduleMusic()` — the 40 ms tick with a 150 ms lookahead |
| `js/audio.js:273, 278, 286` | `initAudio()`, `setMuted(muted)`, `setVolume(volume)` — the three controls the port must expose with the same semantics |
| `js/main.js:1158-1159` | `music.setIntensity(0.12); music.start();` at match start — the initial intensity, not zero |
| `js/main.js:1220-1226` | The rally-intensity formula, recomputed per frame: `rallyTension = min(1, rallyHits / 12)`, `stakes = min(0.35, sets*0.15 + games*0.02)`, `setIntensity(min(1, 0.12 + rallyTension * 0.55 + stakes))` |
| `js/main.js:1385` | `music.stop()` on the path the port must mirror |
| `js/main.js:1530-1545` | `pauseGame()` and its music behaviour — including the quirk the route evidence records: pause does **not** stop the music |
| `js/game.js:750, 1893, 1898, 2111, 2113, 2115, 2209, 2363, 2382` | The nine `sfx` call sites in the simulation, which the port replaces with event ids and the view resolves to sounds |
| `js/fx.js:2-10` | The reduced-motion flag lives here, and `js/audio.js` consults it **nowhere**. The port must preserve that: motion reduction stays in the effects layer and never in audio |
| `tools/audio-port/event-map.json` | The verified event contract: ten sound ids, each anchor's line and call text, the port's message-id anchors, and the sha256 of each baked WAV |
| `tools/audio-port/verify-event-map.mjs` | The drift test over that contract |
| `tools/audio-audition/baked/*.wav` | The ten baked files: `hit`, `bounce`, `wall`, `net`, `serve`, `special`, `point-win`, `point-loss`, `victory`, `defeat` |
| `tools/audio-audition/audition-core.js`, `index.html`, `verify-stub.mjs`, `verify_browser.py` | The audition harness: 54 stub checks and 11 real-browser renders, with `tools/audio-audition/baked/` as its output. The two verifiers' counts are the evidence bar this slice inherits |
| `docs/wayfinder/evidence/audio-event-contract.md` | The contract's evidence, including the seven injected drift cases it catches |
| `docs/wayfinder/evidence/audio-port-route.md` | The route: per-sound decisions, the tempo formula `60 / (96 + intensity * 54)`, the gates at 0.4 (arp), 0.6 (off-beat bass) and 0.72 (kick and hat), the 40 ms tick with 150 ms lookahead, and the explicit note that no listening test has been made |
| `godot/src/sim/sim.gd` | The port's event emission: `add_event(state, message_id)` with ids, never sounds |
| `godot/src/view/SimEventRouter.gd` | The single module that reads the event list and touches the view, owned by [Quick-match vertical slice in 3D](quick-match-slice.md). Audio hooks land here as one consumer, not as calls scattered through the view |

The seams this slice sits next to, each with one owner: `godot/src/sim/**` emits event ids and never plays sound; `godot/src/view/SimEventRouter.gd` is the single routing point; `godot/src/locale/**` owns strings; `godot/src/ui/**` owns the settings screen that will one day expose mute and volume, and this slice exposes the API for it rather than building the screen.

## File ownership / allowlist

New files this ticket creates, all inside the one module directory:

- `godot/src/audio/audio_bus_layout.tres` — the bus layout: a master and a music bus, with the mute and volume semantics of `js/audio.js:278` and `:286`
- `godot/src/audio/AudioEvents.gd` — the ten sound ids and their event mapping, generated from `tools/audio-port/event-map.json`, with the file-bound sha256 values carried
- `godot/src/audio/SfxPlayer.gd` — the one-shot player: preloaded streams, per-sound variant sets for the five sounds whose grain is a fresh noise buffer, no dynamic synthesis
- `godot/src/audio/MusicSequencer.gd` — the ported sequencer: chord table, gates, per-voice gains, tempo `60 / (96 + intensity * 54)`, a 40 ms tick with 150 ms lookahead, `start`, `stop`, `set_intensity`
- `godot/src/audio/RallyIntensity.gd` — the port of `js/main.js:1220-1226`, fed by the same three simulation values and recomputed per frame
- `godot/src/audio/AudioApi.gd` — the module's only public surface: `init()`, `set_muted(bool)`, `set_volume(float)`, `play(event_id)`, `music_start()`, `music_stop()`, `set_intensity(float)`. Nothing outside the module imports any other file in it
- `godot/tests/audio_event_audit.gd` and `.tscn` — the ported drift test: every `AudioEvents` id has a baked file, every file's hash matches the contract, and every id is emitted by at least one place in the simulation's event vocabulary
- `godot/tests/audio_sequence_audit.gd` and `.tscn` — the sequencer's pure half: tempo, gates and voice parameters at stated intensities, and the start/stop and pause quirk
- `godot/tests/audio_intensity_audit.gd` and `.tscn` — the ported intensity formula against its three inputs, including the boundaries
- `godot/src/audio/README.md` — the module's map and its one-owner statement
- `docs/implementation/evidence/s10-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `tools/audio-audition/` and `tools/audio-port/` (read-only: the WAVs and the contract are the ground truth and are not regenerated), `assets/` (read-only), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md)), `godot/src/view/SimEventRouter.gd` beyond the single audio-hook registration agreed with its owner, `godot/src/locale/**`, `godot/src/ui/**`, and `godot/prototypes/`.

There is exactly one audio module. A second directory, a second bus layout, or a `SfxPlayer` copy under another lane's path is a red, not a merge conflict.

## Inputs and outputs

Inputs:

- The verified event contract: ten sound ids, their baked files and the WAV hashes from `tools/audio-port/event-map.json`.
- The ten baked WAVs as the audio ground truth. No synthesis is authored in the module; the only place a parameter can be expressed is `pitch_scale` on a played stream.
- The simulation's event ids and the three intensity inputs (rally hits, sets, games) through the view seam.
- The mute and volume settings, from the interface the settings screen will later call.

Outputs:

- One audio module with a single public surface, no scattered calls, and no sound ever triggered from inside the simulation.
- Ten sounds playable by id, five of them with randomised variants, and the five music voices driven by a ported sequencer whose tempo and gates respond to intensity exactly as the formula says.
- Mute suppressing every one-shot and the music, and volume applied on the bus rather than per-stream.
- A headless drift audit, a headless sequencer audit and a headless intensity audit, each with an exit code.
- The honest statement of what is not proven: no listening test, no loudness or ducking targets (the reference defines none), and the music asserted against source rather than rendered end to end, because the reference sequencer is driven by a timer an offline render does not advance.

Explicitly not output: live synthesis, a new sound, a re-bake of the WAVs, loudness or ducking targets, motion-linked audio cues (the reference has no such branch), a settings screen, and any claim that the port sounds right.

## Tests

The web audits and verifiers that bear on this slice, by real file name under `scripts/` and `tools/`:

- `tools/audio-port/verify-event-map.mjs` — the drift test over the contract. The Godot equivalent is `audio_event_audit.gd`, which re-reads the same contract and the same hashes so the two sides cannot drift apart.
- `tools/audio-audition/verify-stub.mjs` — 54 checks, including that every parameter reaches the stubbed API, that mute suppresses all ten one-shots, and that the music tempo, gates and intensity anchors hold. The port's equivalents are the sequencer and intensity audits.
- `tools/audio-audition/verify_browser.py` — 11 real headless-Chromium renders, 10/10 sounds audible, the muted path silent and the mixer ratio exactly 0.5000. **This one does not port**: there is no browser in the port, and the host has no sound device. Its replacement is weaker and is stated as such — the WAVs' hashes are asserted and the play calls are asserted to reach the bus, but audibility is not re-proven in Godot.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` — the replacement stays the headless load with zero script errors, plus the module-boundary rule that nothing outside the module imports past `AudioApi.gd`.
- `scripts/feedback-audit.mjs` and `scripts/api-feedback-audit.mjs` — not this slice's; named only because they are the other two audits that touch non-game subsystems and neither port literally.

Godot-side equivalents:

- `godot/tests/audio_event_audit.gd` — every id in `AudioEvents.gd` has a baked file whose sha256 matches the contract; every id is reachable from a simulation event id; an unknown id is a failure, not a silent no-op.
- `godot/tests/audio_sequence_audit.gd` — at stated intensities, the sequencer's tempo equals `60 / (96 + intensity * 54)` and each gate crosses where the route evidence says; `start`/`stop` behave as the reference; pause does not stop the music.
- `godot/tests/audio_intensity_audit.gd` — the intensity formula against its inputs and its two clamps, including `stakes` saturating at 0.35 and the total at 1.0.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. These audits are headless and need no sound device, which is what makes them the right evidence on this host.

The three headless audits:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in audio_event_audit audio_sequence_audit audio_intensity_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s10-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s10-${a//_/-}.log; \
done
```

The contract and the WAV hashes this slice is bound to, re-checked rather than assumed:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  node tools/audio-port/verify-event-map.mjs; echo "contract exit=$?"; \
  node tools/audio-audition/verify-stub.mjs; echo "stub exit=$?"; \
  sha256sum tools/audio-audition/baked/*.wav
```

The module-boundary rule, checked mechanically:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  grep -rn 'res://src/audio/' godot/ --include=*.gd | grep -v '^godot/src/audio/' | \
  grep -v 'AudioApi.gd'; echo "the line above must be empty (only AudioApi.gd is imported from outside)"
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s10-web-baseline.log 2>&1; echo "exit=$?"
```

What cannot be run here, stated rather than faked: a listening test. The host has no sound device, and the reference's loudness and ducking targets do not exist to compare against.

## Expected evidence

- `docs/implementation/evidence/s10-audio-event-audit.log`, `s10-audio-sequence-audit.log`, `s10-audio-intensity-audit.log` — each with an exit code and a `PASS n/n` line.
- `docs/implementation/evidence/s10-contract-recheck.log` — `verify-event-map.mjs` and `verify-stub.mjs` re-run, with the ten WAV sha256 values, so the module is provably bound to the verified set and not to files it generated itself.
- `docs/implementation/evidence/s10-boundary-check.log` — the module-import check, showing only `AudioApi.gd` crossing the boundary.
- `docs/implementation/evidence/s10-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.
- `docs/implementation/evidence/s10-audio-notes.md` — the module map, the id-to-file table, the five variant sets and why they exist, the sequencer parameters with their anchors, the pause quirk reproduced deliberately, the explicit statement that motion reduction never touches audio (`js/fx.js:2-10`, `js/audio.js` has no match), and the three things not proven: no listening test, no loudness or ducking targets because the reference defines none, and the music asserted against source rather than rendered end to end.

What does not count as proof: a screenshot of a bus layout; a claim that a sound is right without a listening test — which nobody on this host can make; a ported parameter table with no audit behind it; and any claim of parity for loudness, since there is nothing to be at parity with.

## Failure and recovery criteria

Red means any of these:

- Any audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- A sound is synthesised live, or a WAV is regenerated or re-baked instead of read from `tools/audio-audition/baked/`.
- The audio module reads the reduced-motion flag, or any other setting that the reference's audio layer does not read.
- A sound is played from inside `godot/src/sim/**`. The simulation emits ids; the router plays.
- A second audio module, a second bus layout or a duplicated player appears outside `godot/src/audio/**`.
- An id in the contract has no file, or a file's hash differs from the contract.
- Loudness, ducking or a listening verdict is claimed.
- The four `setTimeout` chains of the reference are ported as timer chains instead of as single sequence bakes — which is the drift risk the route explicitly rejected.
- A file outside the allowlist changes, or `js/`, `scripts/`, `tools/` or `assets/` changes at all.

What stops the slice: a red audit after the retry rule below; or the audio lane and this ticket conflicting over the module directory, which is resolved by the one-owner rule — this ticket's file list is the module, and a conflicting writer stops rather than merges.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the sequencer's tick and lookahead are the route's values and not engine defaults; confirm the intensity formula's two clamps are both present, since a missing `stakes` clamp changes every long match; confirm the pause path reproduces the reference's quirk deliberately rather than by accident; confirm the variant sets are preloaded and not generated at play time.

## Human gates that block this slice (open, owner Luca)

- **The listening verdict** — the audio route is resolved, but no listening test exists and this host has no sound device. Whether the port sounds right is an ear call, and the artifacts for it are the ten baked WAVs plus the audition page's click-to-play cards, unchanged. This slice does not claim it.
- **The audition harness's wiring** — `verify_browser.py` needs a browser and is deliberately not part of the audit suite; whether it is wired in is a separate decision nobody has taken, and this slice does not take it.
- **Product scope and platforms** — the settings surface where mute and volume are exposed. This slice publishes the API and builds no screen.
