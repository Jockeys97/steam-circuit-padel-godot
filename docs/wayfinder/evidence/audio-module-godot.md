# Evidence — Godot audio module: the event→sound contract, implemented and drift-tested

Ticket: the *engine* half of [`docs/wayfinder/tickets/audio-port-route.md`](../tickets/audio-port-route.md),
consuming the verified, engine-free contract
[`docs/wayfinder/evidence/audio-event-contract.md`](./audio-event-contract.md)
(`tools/audio-port/event-map.json`).
Run date: 2026-09-16. Repo `steam-circuit-padel-pro`, Godot `4.7.2.stable.official.ed1daf0bf`
at `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`.
Host: 3.9 GB RAM, 0 swap, other agents in the same repo — **every** Godot invocation below ran
inside `flock -w 900 /tmp/padel-godot.lock` with an inner `timeout`, one engine process at a time.
Spend: **0** (no paid API, no install, no network call).

## What was built

The first **real** Godot-side audio: a bus graph, ten players, the mixer semantics, and a
headless test that fails if any of it drifts from the contract.

```
tools/audio-port/event-map.json          (authoritative, verified — READ ONLY here)
        │  node tools/audio-port/sync-godot-audio.mjs        (the only writer of the two copies)
        ├─► godot/src/audio/event_map.json                byte-identical copy of the contract
        └─► godot/assets/audio/<sound>.wav  (× 10)        byte-identical copies of the baked WAVs
                    │
                    │  godot/src/audio/audio_port.gd       consumes the copy at _ready()
                    ▼
        buses Master / SFX / Music  +  10 × AudioStreamPlayer
                    ▲
                    │  godot/tests/audio_port_test.gd      compares engine ↔ contract, 15 checks
                    └  + 15 injected-drift cases that MUST go red
```

Drift anywhere in that chain — the contract, the engine copy, a WAV, a mixer number, the bus
graph, the players — is a red test, not a quietly different-sounding game.

### Deliverables (path, bytes, sha256)

| File | Bytes | sha256 |
|---|---|---|
| `godot/src/audio/audio_port.gd` | 16711 | `39de40cb7c63f3c473701a09b39b927dfd3f6a1c32daaa487e1292967a6d89c4` |
| `godot/src/audio/audio_port.gd.uid` | 20 | `9fab6689412cfc7aa6c3e7206b767b507aecf0bdda991b7bd64fdb85c0f2fe69` |
| `godot/src/audio/event_map.json` (engine copy) | 18555 | `a17ccf9de251619dd2575d9bfe6fb0924695cf19b9a0520d837e892d2c2cd286` |
| `godot/tests/audio_port_test.gd` | 44409 | `f8f6fbb04c31daa8b9d64f0ebbaa3c5e8151a369310bbdf2fb222fd2cd81cbb1` |
| `godot/tests/audio_port_test.gd.uid` | 20 | `1ef4bba527f41c93f140e1ea7a4488e28582e46a60f96af853deec8f572648a5` |
| `tools/audio-port/sync-godot-audio.mjs` | 6436 | `a2022435a0c8ff1f15edebbf1c988bec0f6df17555b2496d2b5c6932d29148d8` |
| `godot/assets/audio/padel_audio_bus.tres` | 1888 | `6246964833fab216f98146720349af8a7454b9817d141e1b389cefad5f2fde08` |
| `godot/assets/audio/{bounce,defeat,hit,net,point-loss,point-win,serve,special,victory,wall}.wav` | 132344 each | `b09f28b4…91a6`, `6ee4fad1…f15b`, `3045ce71…c0ee`, `3ba22290…ab02`, `c0fe349e…467b`, `92a0faf0…ba8e`, `1e584b02…d2dd`, `0b6771cf…cc53`, `6131d7db…ace2`, `bfe0ff28…8706` |
| `godot/assets/audio/<sound>.wav.import` (× 10, Godot's import config) | 480–501 each | — |
| `docs/wayfinder/evidence/audio-module-godot.md` | this file | — |

All ten engine WAV sha256 values are **identical strings** to `events[].wav.sha256` in the
contract — the engine plays the exact bytes the verified bake produced.

`godot/src/audio/_probe.gd` (a temporary API probe used to establish the engine facts below)
was deleted; it is not part of the port. `.godot/` import caches are regenerated, git-ignored,
and not deliverables.

**One side effect outside this lane, reported rather than glossed:** running
`godot --headless --import` (needed to turn the WAVs into loadable `AudioStreamWAV` resources)
made the engine write Godot's own script-id files (`<script>.gd.uid`, one line each) next to
scripts owned by other lanes — `godot/src/sim/*.gd.uid` appeared at 11:48, and any other lane's
editor run creates the same files. No `.gd` source outside this lane was modified (checked by
mtime: `sim.gd` 07:59, `fault_digest_gd.gd` 09:47, i.e. untouched); `godot/project.godot` changed
at 11:55, **after** this lane's last engine run at 11:54, by the lane that owns it.

**Untouched, as required:** `tools/audio-port/event-map.json` (`a17ccf9d…2286`) and
`tools/audio-port/verify-event-map.mjs` (`7266d2de…7e35`) are byte-identical to the hashes
recorded in `audio-event-contract.md`; `godot/project.godot`, `godot/src/sim/**`,
`godot/game/**`, `js/**`, `scripts/**`, `docs/wayfinder/map.md` were not modified
(`git status --porcelain js/` → empty). Nothing was committed, pushed or deployed.

## What the module is

`godot/src/audio/audio_port.gd` (extends `Node`) reads `res://src/audio/event_map.json` at
`_ready()` and builds itself from it. **No contract number is re-typed as a constant**: the
sound set, the event ids, `mixer.masterGainDefault.value`, `mixer.masterGainRange.{min,max,step}`,
`mixer.mute.default` and `mixer.musicBusGain.value` all come out of the JSON.

| Interface | Behaviour |
|---|---|
| `play_event(event_id) -> bool` | starts the event's one-shot; `false` + `last_play_error` for a non-contract id, while muted, if the contract did not load, or outside a running tree |
| `is_playing(id)`, `stop_all()` | voice state |
| `sound_for_event(id)`, `event_ids()`, `player_for(id)` | the mapping, as data |
| `set_master_gain(v) -> float`, `master_gain()` | the 0..1 reference slider, clamped, applied relative to the baked 0.5 |
| `set_muted(b)`, `is_muted()` | one global flag (`js/audio.js:278-280`) |
| `reset()` | stop, rebuild buses and players from the contract |
| `describe()` | the engine's own view of itself (per-event stream/bus/hash/format facts, bus graph, mixer state) — what the test diffs against the contract |
| `port_bindings()` | **always `{}`** (see "not invented") |

Buses are built at runtime through the `AudioServer` API (`add_bus` / `set_bus_name` /
`set_bus_volume_db` / `set_bus_send`), idempotently — **no `project.godot` edit and no
`default_bus_layout.tres` dependency**. `godot/assets/audio/padel_audio_bus.tres` ships the same
three buses as an `AudioBusLayout` and the test asserts the resource and the runtime layout agree
bus-for-bus, so it can be adopted as the editor default later (request in §"Not done").

### Semantics, with their anchors

| Behaviour | Implemented as | Anchor |
|---|---|---|
| 10 events → 10 baked one-shots | one `AudioStreamPlayer` per event, `bus = "SFX"` | `event-map.json events[]` |
| master gain 0.5 default | `Master` bus at **0 dB** at the default, `bus_db = linear_to_db(value / 0.5)` | `js/audio.js:4-5`, applied `:15`; setter `:286-289` |
| clamp, no quantisation | `clampf(v, min, max)`; the 0.01 step stays a UI property | `js/audio.js:286-289`, `index.html:426` |
| volume 0 | `-80 dB` + master bus mute — silent, playback still runs | `js/audio.js:286-289` (gain 0 keeps voices running) |
| mute | refuses to **start** new voices; mutes **no** bus, cuts no sounding voice | `js/audio.js:278-280`, early returns at `:24,41,157,184,202,262` |
| music bus 0.55 | `Music` bus at `linear_to_db(0.55)` = **-5.1927 dB**; nothing routes to it | `js/audio.js:149` |
| no ducking / limiter / compressor / fade | **0** bus effects anywhere; overlap is additive summation | `mixer.ducking.defined == false` |
| no panning / 3D | plain `AudioStreamPlayer`, `volume_db = 0.0`, one shared bus | `mixer.panning.defined == false` |
| no per-event volume | every player at 0 dB; the WAV already carries its synth gain | `mixer.unknowns[1]` |
| same sound may overlap itself | `max_polyphony = 16` (the reference builds fresh oscillators per call) | `js/audio.js:30-46`; variants are `notInContract[1]` |
| reduced motion | audio never reads it | `mixer.reducedMotion.affectsAudio == false` |

### The master-gain derivation (measured, not tuned)

The bake already contains the reference's master gain, so re-applying 0.5 in Godot would
attenuate twice. Measured on the shipped artefacts:

```
$ python3 - <<'PY'   # peak of each baked WAV, 16-bit mono
import wave, struct, os
for n in sorted(os.listdir("tools/audio-audition/baked")):
    w = wave.open(os.path.join("tools/audio-audition/baked", n)); raw = w.readframes(w.getnframes())
    print(n, max(abs(x) for x in struct.unpack("<%dh" % (len(raw)//2), raw)) / 32768)
PY
bounce.wav 0.1266   hit.wav 0.1969   wall.wav 0.2140   serve.wav 0.0615   net.wav 0.0796
victory.wav 0.3291  defeat.wav 0.2334  point-win.wav 0.2270  point-loss.wav 0.0990  special.wav 0.1767
```

`bounce` is the clean case: synth sine gain **0.3** (`js/audio.js:65-67`) → ceiling 0.15 with the
reference master gain 0.5, versus **0.1266** measured (attack ramp + 150→68 Hz sweep explain the
rest). `hit`: gain 0.4 → 0.2 ceiling, **0.1969** measured. Both confirm the bake includes the
`0.5`. Hence: at the reference default the Godot master bus is **unity (0 dB)** and reproduces
the baked level; the 0..1 slider scales relative to it. No target-loudness or headroom number is
invented — the contract records none (`mixer.unknowns[0]`).

### Import decision: lossless PCM, not the default codec

Godot's WAV importer defaults to `compress/mode=2` (QOA, lossy): the first import produced
`format=3` and a 26784-byte payload for a 264600-byte source. The route chose *baked audio* for
bit-faithfulness, so all ten `.wav.import` files are set to `compress/mode=0` and re-imported —
the engine then decodes `format=1` (FORMAT_16_BITS) with a 132300-byte payload that is
**byte-for-byte equal** to the file's payload (verified in-engine, 0 differing bytes, `_chk_payload`).
Re-running `--import` afterwards preserves the setting and the test stays green.

## The test

`godot/tests/audio_port_test.gd` — extends `SceneTree`, so it needs no `.tscn` (the harness
skeleton's scene file is another lane's) and runs headless as a script:

```bash
flock -w 900 /tmp/padel-godot.lock timeout -k 30 480 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot \
  --script res://tests/audio_port_test.gd
```

Output contract (CI-parsable, same shape as `godot/tests/smoke_test.gd`): one `ok <name>` /
`FAIL <name>` line per check, the failing detail also on stderr, then `PASS n/n` or `FAIL n/n`,
and a `RESULT`-free drift section above it. Exit 0 = green **and** every injected drift caught.

### The 15 checks (verbatim, green run)

```
ok contract copy: the engine copy is byte-identical to the authoritative contract  sha256 a17ccf9de251619d…
ok contract: 10 unique events == 10 declared sounds == 10 engine players  10 events, 10 players
ok engine: event -> sound resolution matches the contract (incl. the point win/loss split)  10 events resolved
ok engine: players are mono, un-panned, un-levelled and share one SFX bus  bus 'SFX', 10 players
ok assets: every engine WAV is byte-identical to the baked source the contract points at  10 events
ok assets: the contract's recorded sha256/bytes match the files the engine loaded  10 events
ok assets: engine format equals the baked file's own header (44.1 kHz mono 16-bit, exact payload size)  checked against each WAV header
ok assets: the engine's decoded PCM equals the baked WAV payload byte-for-byte  10 streams, 132300 bytes each
ok mixer: only the reference's numbers (master default, mute default, music bus gain)  master 0.500, music 0.550, muted default false
ok mixer: master gain clamps to the contract's range and scales relative to the baked 0.5  range [0.0, 1.0], unity at 0.5
ok mixer: mute is one global flag that gates new voices and mutes no bus  10 events refused while muted
ok engine: no ducking, compression, limiter, panning or per-event volume was invented  3 buses, 0 live effects
ok engine: port message ids are not bound to sounds (the contract leaves that open)  16 port ids rejected, 10 event ids accepted
ok bus layout: the shipped AudioBusLayout resource matches the buses the module builds  3 buses
ok engine: playback starts and advances under the headless driver  0.189 s after 20 frames
```

Notes on the non-obvious ones:

- The WAV format check derives its expectations from **each baked file's own 44-byte RIFF
  header** (rate, channels, bit depth, payload size) — no typed-in constant. That is what makes
  a re-encode (e.g. a fresh import with the default codec) go red.
- The mute check asserts the two halves separately: a voice started *before* mute keeps playing
  and all ten events are refused *after* it, and the master bus is not muted.
- The port-id check replays 15 message ids the contract binds to port functions plus one
  fabricated id (`evNotAContractEvent`); all 16 must be refused while all 10 contract event ids
  are accepted. That is the executable form of "the sim-message-id → sound binding is undecided".
- "no invention" is a **tripwire on the contract too**: if `mixer.ducking.defined` or
  `mixer.panning.defined` ever becomes `true`, the check fails, because the module implements
  neither. Same for an emptied `mixer.unknowns`.
- Playback advance is a real measurement under the headless dummy driver
  (`AudioServer.get_driver_name() == "Dummy"`), not a flag read.

### The 15 injected-drift cases (each must go RED)

Applied to a deep copy of the contract and/or a copy of the engine view, then the whole check
set is re-run; a case raising 0 failures is printed `[MISSED]` and fails the run.

```
injected-drift self-check (each case must go RED)
  [CAUGHT] remove-event               4 failure(s)  delete the 'wall' event from the contract
  [CAUGHT] add-event                  8 failure(s)  append a fabricated 11th event with no WAV
  [CAUGHT] sound-swap                 4 failure(s)  point 'net' at hit.wav
  [CAUGHT] soundids-drift             1 failure(s)  declare an 11th sound id no event uses
  [CAUGHT] wav-hash-drift             1 failure(s)  expect a different sha256 for 'hit'
  [CAUGHT] mixer-gain                 4 failure(s)  master default 0.5 -> 0.6
  [CAUGHT] mute-default               5 failure(s)  mute default false -> true
  [CAUGHT] music-bus-gain             3 failure(s)  music bus gain 0.55 -> 0.7
  [CAUGHT] ducking-invented           1 failure(s)  mark ducking as defined in the contract
  [CAUGHT] schema-drift               1 failure(s)  bump schemaVersion to 2
  [CAUGHT] engine-sound-repoint       4 failure(s)  repoint the engine's 'net' player at hit.wav (engine view)
  [CAUGHT] engine-gain-drift          1 failure(s)  engine view reports master gain 0.6
  [CAUGHT] engine-effect-injected     2 failure(s)  put a hard limiter on the SFX bus (live engine)
  [CAUGHT] engine-stream-emptied      4 failure(s)  clear the 'hit' player's stream (live engine)
  [CAUGHT] engine-player-detached    12 failure(s)  pull the 'hit' player out of the tree (live engine)
```

Ten cases are contract-side, three are engine-view-side and two mutate the **live** engine (an
audio effect on the bus, a player with no stream / out of the tree), so the "not blind" proof
covers both directions of the drift axis — a check that only ever compared two copies of the same
JSON would not.

**One drift case was tried and dropped, on the record:** `stream_paused = true` before playback
did **not** go red — Godot rebuilds the playback on `play()`, so a pre-set pause does not survive
the call the check exercises. It was replaced by the two live cases above rather than left in the
table as a case that passes for the wrong reason.

A single case can be run on its own, as its own red control:

```
$ … --script res://tests/audio_port_test.gd -- --drift=remove-event
[FAIL] contract: 10 unique events == 10 declared sounds == 10 engine players  9 events, 10 players
       - 9 events != 10 declared sounds
       - engine builds 10 players, contract declares 9 events
       - engine has a player for 'wall', which no contract event declares
[FAIL] engine: players are mono, un-panned, un-levelled and share one SFX bus  bus 'SFX', 10 players
       - contract declares 9 events, engine describes 10
DRIFT DETECTED — 4 failure(s) raised by injected 'remove-event'.
exit 1 is CORRECT here: this proves the test reacts to drift.
```

## Commands run, with exit codes

| # | Command (Godot calls wrapped in `flock -w 900 /tmp/padel-godot.lock` + `timeout`) | Exit | Key output line |
|---|---|---|---|
| 1 | `node tools/audio-port/sync-godot-audio.mjs` | **0** | `RESULT: PASS — contract and engine copies agree (10/10 WAVs, map sha256 a17ccf9de251619d…).` |
| 2 | `node tools/audio-port/sync-godot-audio.mjs --check` | **0** | same, writing nothing |
| 3 | `godot --headless --path godot --import` | **0** | `[ DONE ] reimport` (10 WAVs) |
| 4 | `godot --headless --path godot --script res://tests/audio_port_test.gd` | **0** | `PASS 15/15`, `drift cases caught / missed : 15 / 0` |
| 5 | … same + `-- --drift=remove-event` | **1** | `DRIFT DETECTED — 4 failure(s) raised by injected 'remove-event'.` |
| 6 | … same + `-- --drift=engine-stream-emptied` | **1** | `DRIFT DETECTED — 4 failure(s) raised by injected 'engine-stream-emptied'.` |
| 7 | `node tools/audio-port/verify-event-map.mjs` | **0** | `RESULT: PASS — 8 green checks, 0 failures; all 7 injected drift cases caught.` |
| 8 | `node tools/audio-port/verify-event-map.mjs --drift=remove-event` | **1** | `DRIFT DETECTED — 3 failure(s)` (red by design) |
| 9 | `node tools/audio-audition/verify-stub.mjs` | **0** | `54/54 checks passed — catalogue matches js/audio.js and every sound reaches the API` |
| 10 | `sha256sum tools/audio-port/event-map.json tools/audio-port/verify-event-map.mjs` | **0** | `a17ccf9d…2286` / `7266d2de…7e35` — unchanged |
| 11 | `godot --headless --path godot --import` (re-run) then command 4 again | **0** | `PASS 15/15` — import is idempotent, lossless import setting survives |

Commands 7 and 9 are not this lane's deliverables; they were re-run to show the contract and the
audition tooling were left intact. `verify_browser.py` (11/11 offline Chromium render) was **not**
re-run by this lane — it needs a full Playwright Chromium under the same one-heavy-process limit;
the route's own evidence already records it, and nothing in this lane touched `tools/audio-audition/**`.

### Re-run everything

```bash
cd /root/projects/steam-circuit-padel-pro
node tools/audio-port/sync-godot-audio.mjs --check
node tools/audio-port/verify-event-map.mjs
flock -w 900 /tmp/padel-godot.lock timeout -k 60 600 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot --import
flock -w 900 /tmp/padel-godot.lock timeout -k 30 480 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot \
  --script res://tests/audio_port_test.gd            # expect exit 0 and PASS 15/15
flock -w 900 /tmp/padel-godot.lock timeout -k 30 480 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot \
  --script res://tests/audio_port_test.gd -- --drift=remove-event   # expect exit 1 (drift caught)
```

From a clean checkout: run `node tools/audio-port/sync-godot-audio.mjs` (not `--check`) first —
it writes the engine copies of the contract and the WAVs — then `--import`, then the test.

## Against the route's acceptance bar

`audio-port-route.md` asks for the audition bar (54/54 stub checks, 11/11 browser renders) to be
reproduced on the Godot side. Mapped honestly, per assertion:

| Audition assertion | Godot-side equivalent here | Strength |
|---|---|---|
| 10/10 sounds audible | 10 WAVs byte-identical to the bake + decoded PCM byte-identical + playback starts and advances | **stronger numerically**, but no listening |
| muted path silent | all 10 events refused while muted; no voice started | **weaker**: asserts no voice starts, it does not measure a silent output buffer |
| mixer ratio exactly 0.5000 | bus dB at 1.0 / 0.5 / 0.25 relative to the baked default, and the 0..1 clamp | equal in kind (numeric), measured in dB |
| catalogue matches `js/audio.js` | that is the Node contract test's job (8/8 green, untouched); the module consumes its output | unchanged, delegated |
| music tempo/gates/intensity | **not covered** — music is out of contract | gap, see below |

## Not done — stated plainly

1. **No listening test, and none claimed.** The host has no sound device;
   `AudioServer.get_driver_name()` returns `"Dummy"`. Everything above is numeric and API-level.
   The baked WAVs and the audition page remain the ear artefacts, and whether the port *feels*
   right is Luca's call.
2. **No measurement of the mixed output.** Nothing captures the master bus to prove the engine's
   summed output equals the reference's mix. `AudioEffectCapture` on the Master bus is the obvious
   route; whether the dummy driver runs the effect chain at all is unverified, so it was not
   claimed. Follow-up if a real driver ever runs in CI.
3. **The sim-message-id → sound binding is deliberately absent.** `port_bindings()` returns `{}`
   and the test asserts that. Nothing in `godot/src/sim/**` plays a sound yet: the module's API
   takes *contract* event ids, and which port message id (`evWallValid`, `pointYou`, `evTape`, …)
   should carry which sound is a decision the contract leaves open (`honestUnknowns[4]`).
   **This is the remaining integration step and it needs a decision, not a guess.**
4. **Music (5 generative voices) is not ported.** Out of contract (`notInContract[0]`); the
   `Music` bus exists at the reference's 0.55 gain, but nothing routes to it. The sequencer stays
   owned by the route ticket.
5. **Randomised variants are not implemented.** The route proposes 4-6 variants via
   `AudioStreamRandomizer` for `hit`/`wall`/`net`/`serve`/`special`; the contract records variant
   counts as out of scope (`notInContract[1]`). One player per sound, `max_polyphony = 16`.
6. **No `project.godot` change** (another lane owns it). The module needs none — buses are built
   at runtime. Two *optional* one-line settings for whoever owns that file:
   - `audio/buses/default_bus_layout = "res://assets/audio/padel_audio_bus.tres"` (so the editor's
     default layout matches; the module does not depend on it), and
   - an autoload of `res://src/audio/audio_port.gd` (e.g. named `Audio`) so `godot/game/**` can
     call `Audio.play_event("<event id>")` without threading a reference through the scenes.
7. **Not wired into CI.** `scripts/**` is outside this lane's boundary, so nothing runs the
   Godot test automatically. Request: a CI entry with the flocked command from §"Re-run
   everything", asserting exit 0 for the green run and exit 1 for `--drift=remove-event`.
8. **Exit-time leak warning, observed nondeterministically.** Some runs end with
   `WARNING: N ObjectDB instances were leaked at exit` / `ERROR: M resources still in use at exit`
   (observed 3/1 in one green run and 20-24 objects / 9-10 streams in others, including single-case
   runs; the final green run is clean). Exit codes, check results and the drift verdict are
   unaffected. Cause not established — the engine's dummy audio driver holding playback/stream
   references at shutdown is the likely source, **not verified**. Recorded rather than hidden.
9. **Overlap priority and ducking remain undefined** by design (`mixer.ducking.defined == false`);
   the test asserts the module adds none rather than inventing a rule.
10. **`eventIdAnchors` weak spots are inherited, not fixed.** `serve` and `hit` still store no
    port id at their trigger, and `victory`/`defeat` bind to `setToYou`/`setToCircuit` in
    `finish_set` rather than to `score_point`. That is the contract's honest position; this lane
    did not soften it.
