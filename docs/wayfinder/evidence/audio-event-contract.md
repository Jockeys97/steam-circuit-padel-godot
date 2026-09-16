# Evidence — Audio event contract (engine-free)

Ticket: the contract half of [`docs/wayfinder/tickets/audio-port-route.md`](../tickets/audio-port-route.md)
(audio is one of the four couplings named in
[`simulation-port-boundary.md`](../tickets/simulation-port-boundary.md) §2).
Run date: 2026-09-16, repo `steam-circuit-padel-pro` at git HEAD `2979588`.
All commands below were executed on this host from the repo root; the outputs are
verbatim.

Deliverables:

| File | sha256 | bytes | lines |
|---|---|---|---|
| `tools/audio-port/event-map.json` | `a17ccf9de251619dd2575d9bfe6fb0924695cf19b9a0520d837e892d2c2cd286` | 18555 | 427 |
| `tools/audio-port/verify-event-map.mjs` | `7266d2de08815a0d7f0c87201ad6947befeaad10f74153c0c76c46fc44dc7e35` | 24527 | 606 |
| `docs/wayfinder/evidence/audio-event-contract.md` | this file | — | — |

Nothing in `js/**`, `godot/**`, `scripts/**`, `tools/audio-audition/**` or any other
tracked file was read only, never written. `godot/**`, `tools/**` and `docs/**` are
untracked at HEAD (`git status --porcelain` shows `?? docs/`, `?? godot/`, `?? tools/`),
so no tracked file was touched here either.

## What this contract is, and what it is not

It is **data plus a source-asserting test**: one entry per audio event the reference
game can emit, each bound to (i) the exact `sfx` call site that triggers it, (ii) one of
the 10 baked WAVs, and (iii) the ported sim's counterpart function and the message ids
it actually stores. It is not a Godot module and it plays nothing — see "Honest gaps".

The event set is **derived from source**, not hand-written, by the test:

- every `sfx.<method>(` call site in `js/game.js` (9 of them),
- every method of the `sfx` object in `js/audio.js` (9 of them),
- every `.wav` on disk under `tools/audio-audition/baked/` (10 of them),
- every `eventIdAnchors` binding re-read out of `godot/src/sim/sim.gd`.

An event is a *sound a player can hear*, not a source line: `sfx.point(win)` at
`js/game.js:2111` is one call site that emits two different sounds, so it is two events
(`point-win`, `point-loss`) sharing one anchor. 9 call sites + 1 branch split = 10 events
= 10 WAVs.

## The mapping (10 events, 10 WAVs)

`fn` is the function the test asserts encloses the cited line.

| # | event | sound / WAV | reference anchor (`file:line`) | triggering `fn` (js) | port anchor (`godot/src/sim/sim.gd`) | port fn | port message ids it stores |
|---|---|---|---|---|---|---|---|
| 1 | serve | `serve.wav` `1e584b02…d2dd` | `js/game.js:750` | `performServe` | `sim.gd:689` | `perform_serve` | *(none — see note 1)* |
| 2 | hit | `hit.wav` `3045ce71…c0ee` | `js/game.js:1893` | `hitBall` | `sim.gd:1527` | `hit_ball` | *(none — see note 2)* |
| 3 | special | `special.wav` `0b6771cf…cc53` | `js/game.js:1898` | `hitBall` (`isSpecial` branch) | `sim.gd:1783` → `apply_special` `1874` | `hit_ball` / `apply_special` | `evPrecision` `1884`, `evLightningDash` `1889`, `evSteamSmash` `1897`, `evSteamShield` `1902`, `evPerfectVision` `1909`, `evSteamHammer` `1915` |
| 4 | point-win | `point-win.wav` `92a0faf0…ba8e` | `js/game.js:2111` | `scorePoint` (`win === true`) | `sim.gd:1990` | `score_point` | `pointYou` `2026` |
| 5 | point-loss | `point-loss.wav` `c0fe349e…467b` | `js/game.js:2111` | `scorePoint` (`win === false`) | `sim.gd:1990` | `score_point` | `pointOpp` `2026` |
| 6 | victory | `victory.wav` `6131d7db…ace2` | `js/game.js:2113` | `scorePoint` (result, player) | `sim.gd:1990` | `score_point` | `setToYou` `1947` (`finish_set`) |
| 7 | defeat | `defeat.wav` `6ee4fad1…f15b` | `js/game.js:2115` | `scorePoint` (result, ai) | `sim.gd:1990` | `score_point` | `setToCircuit` `1947` (`finish_set`) |
| 8 | bounce | `bounce.wav` `b09f28b4…91a6` | `js/game.js:2209` | `handleGroundBounce` | `sim.gd:2071` | `handle_ground_bounce` | `evServeValid` `2091`, `evSmashValid` `2115` |
| 9 | wall | `wall.wav` `bfe0ff28…8706` | `js/game.js:2363` | `handleWalls` | `sim.gd:2140` | `handle_walls` | `evWallValid` `2242` |
| 10 | net | `net.wav` `3ba22290…ab02` | `js/game.js:2382` | `handleNetCollision` | `sim.gd:2247` | `handle_net_collision` | `evTape` `2273`, `evNetRebound` `2284` |

Full sha256 values live in `event-map.json` (`events[].wav.sha256`); the test verifies
each one byte-for-byte. Column 7 is the *set of port message ids the port can store at
that trigger*, re-read from source — not an invented enum.

Notes on the port bindings, stated plainly because they are the weakest part of the table:

1. **serve** — `perform_serve` (`sim.gd:689`) stores no message id when the serve is
   struck. The nearest port event is `evServeValid` (`sim.gd:2091`), which fires on the
   first *valid bounce*, one step later. Recorded as an empty list rather than a guess.
2. **hit** — the port's `hit_ball` stores trajectory/quality ids (`evChiquita`,
   `evGlobo`, `evSlice`, …, `sim.gd:1527-1870`) but nothing at the raw contact point,
   because the JS contact point stores nothing either (`sfx.hit()` sits between
   `ball.hitFlash = 1` and the `isSpecial` branch). Empty list.
3. **special** — six ids because the port's `apply_special` dispatches on athlete id
   exactly as `js/game.js:1923-1977` does; all six lines were re-read and confirmed.
4. **victory / defeat** — the port's `score_point` dropped the JS `else if (winner ===
   "player")` branch along with the `sfx` calls, so no id is stored there. The nearest
   stored ids are `setToYou` / `setToCircuit` in `finish_set` (`sim.gd:1947`); the
   authoritative port signal for a finished match is `state.result`.
5. **wall** — the only 1:1 audio counterpart in the whole port: the JS stores
   `addEvent(t("evWallValid"))` at `js/game.js:2365` immediately after `sfx.wall()`, and
   the port stores `evWallValid` at `sim.gd:2242` behind the same `wallEventTimer`
   cooldown.

## Mixer / mute / volume semantics — data, not invention

Everything the reference actually defines, with its anchor. `defined: false` and
`unknowns` are recorded as data in `event-map.json` (`mixer`), because a port that
invents a number here is re-designing, not porting.

| Semantics | Value | Anchor |
|---|---|---|
| master gain default | `0.5` | `js/audio.js:5`, applied `:15` |
| master gain setter | `setVolume`, clamped `Math.min(1, Math.max(0, …))` | `js/audio.js:286-289` |
| master gain range (UI) | `min 0 max 1 step 0.01 value 0.5` | `index.html:426`, `index.html:603` |
| music bus gain | `0.55` (music only — no WAV in this contract routes through it) | `js/audio.js:149` |
| mute | global boolean, default `false`; every synth entry returns early | `js/audio.js:4`, gates `:24, :41, :157, :184, :202, :262`, setter `:278-280` |
| per-sound mute | **does not exist** in the reference | `js/audio.js` — one global flag only |
| persistence | `prefs.volume`, `prefs.muted` | read `js/main.js:2213`, `:2199`; written `js/main.js:2426`, `:2193` |
| reduced motion | **does not affect audio** — `js/audio.js` contains no `reduce`/`motion` | evidence `audio-port-route.md`, §"reduced-motion branch" |
| ducking / compressor / limiter / fade | **defined: false** — overlap is pure additive summation | `js/audio.js` — no such node anywhere |
| panning / 3D attenuation | **defined: false** — no `StereoPannerNode`, no distance model | `js/audio.js` |
| per-event runtime volume | **does not exist**: each baked WAV already contains its synth gain (e.g. `hit` tone gain `0.4` at `js/audio.js:62`) | per-event synth params, `js/audio.js:61-103` |

Unknowns recorded verbatim in the map: no target loudness or headroom number exists
anywhere in the reference; no defined priority when two events sum; no distance model.

## Commands run, with exit codes

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `node tools/audio-port/verify-event-map.mjs` | **0** | 8/8 green checks pass; all 7 injected-drift cases caught |
| 2 | `node tools/audio-port/verify-event-map.mjs --drift=remove-event` | **1** | RED by design — 3 failures raised by the injected removal |
| 3 | `node tools/audio-port/verify-event-map.mjs --map=/tmp/event-map-redA.json` (wall event deleted on disk) | **1** | RED — 3 failures, `RESULT: FAIL` |
| 4 | `node tools/audio-port/verify-event-map.mjs --map=/tmp/event-map-redB.json` (serve anchor shifted 750→751) | **1** | RED — 3 failures |
| 5 | `node tools/audio-port/verify-event-map.mjs --map=/tmp/event-map-redC.json` (port id `evWallValid`→`evWallDead`) | **1** | RED — 1 failure |

`--map=<path>` exists so a drift case can be injected into a **real file on disk** without
writing to `tools/audio-port/event-map.json`. The RED copies were written to `/tmp`, the
repo's map was never mutated. `node v22.22.1`, no dependency added, no `npm install`.

### 1 — the green run (verbatim, exit 0)

```
$ node tools/audio-port/verify-event-map.mjs
event-map contract test  /root/projects/steam-circuit-padel-pro/tools/audio-port/event-map.json
  repo: /root/projects/steam-circuit-padel-pro

  [PASS] map: structure  10 events, 10 declared sounds
  [PASS] anchors: reference call sites resolve  10/10 anchors verbatim + enclosing function matches
  [PASS] events: call-site coverage (js/game.js)  9 source call sites == 9 mapped call sites
  [PASS] events: sfx method coverage (js/audio.js)  9 declared methods == 9 mapped methods
  [PASS] sounds: baked WAV coverage + integrity  10/10 wavs reached, 10/10 sha256 confirmed, 10 on disk
  [PASS] port: function + event-id bindings resolve  10/10 port functions + 15 port event-id anchors checked in godot/src/sim/sim.gd
  [PASS] port: engine-free premise holds  sim.gd calls no sfx and still declares the stripped coupling
  [PASS] sounds: declared ids exist on disk  10 declared ids

injected-drift self-check (each case must go RED)
  [CAUGHT] remove-event      3 failure(s)  delete the 'wall' event (an unmapped sfx.wall() call site + an unreachable wall.wav)
  [CAUGHT] shift-anchor      3 failure(s)  move the 'serve' anchor from js/game.js:750 to :751
  [CAUGHT] sound-swap        2 failure(s)  point the 'net' event at hit.wav instead of net.wav
  [CAUGHT] port-id-rename    1 failure(s)  rename the port event id anchor 'evWallValid' to 'evWallDead'
  [CAUGHT] new-sfx-method    1 failure(s)  add a new method to the sfx object in js/audio.js (source drift) with no map entry
  [CAUGHT] wav-hash-drift    1 failure(s)  expect a different sha256 for the 'hit' WAV (asset changed under the contract)
  [CAUGHT] wav-missing       1 failure(s)  point the 'bounce' event at a WAV that does not exist

numbers
  sfx call sites in js/game.js        : 9
  sfx methods in js/audio.js          : 9
  audio events in the map             : 10
  events with a resolving anchor      : 10
  baked WAVs reached / on disk        : 10 / 10
  distinct port event ids bound       : 15
  green-check failures                : 0
  injected drift: 7/7 applicable cases caught, 12 failure(s) raised in total

RESULT: PASS — 8 green checks, 0 failures; all 7 injected drift cases caught.
```

### 2 — the demonstrable RED (verbatim, exit 1)

```
$ node tools/audio-port/verify-event-map.mjs --drift=remove-event
injected drift: remove-event — delete the 'wall' event (an unmapped sfx.wall() call site + an unreachable wall.wav)

  [FAIL] events: call-site coverage (js/game.js)  9 source call sites == 8 mapped call sites
         - unmapped sfx call site: js/game.js:2363:sfx.wall(
  [FAIL] events: sfx method coverage (js/audio.js)  9 declared methods == 8 mapped methods
         - sfx method added to js/audio.js but unmapped: .wall()
  [FAIL] sounds: baked WAV coverage + integrity  9/10 wavs reached, 9/9 sha256 confirmed, 10 on disk
         - baked WAV 'wall.wav' is reachable from no event

DRIFT DETECTED — 3 failure(s) raised by injected 'remove-event'.
exit 1 is CORRECT here: this proves the test reacts to drift.
```

Exit code **1** with `DRIFT DETECTED`. In this mode exit 1 means *the test caught the
drift*; exit 0 would mean the test was blind to it and would be printed as
`NOT CAUGHT … The test is blind to this drift.`

### 3 — the same removal on a real file, not just in memory

```
$ python3 -c "<load event-map.json, drop the 'wall' event, write /tmp/event-map-redA.json>"
$ node tools/audio-port/verify-event-map.mjs --map=/tmp/event-map-redA.json
  [FAIL] events: call-site coverage (js/game.js)  9 source call sites == 8 mapped call sites
         - unmapped sfx call site: js/game.js:2363:sfx.wall(
  [FAIL] events: sfx method coverage (js/audio.js)  9 declared methods == 8 mapped methods
         - sfx method added to js/audio.js but unmapped: .wall()
  [FAIL] sounds: baked WAV coverage + integrity  9/10 wavs reached, 9/9 sha256 confirmed, 10 on disk
         - baked WAV 'wall.wav' is reachable from no event
...
RESULT: FAIL — 3 failure(s) in the green checks.
$ echo $?
1
```

```
$ node tools/audio-port/verify-event-map.mjs --map=/tmp/event-map-redB.json   # serve anchor 750 -> 751
  [FAIL] anchors: reference call sites resolve  9/10 anchors verbatim + enclosing function matches
         - serve: js/game.js:751 does not contain 'sfx.serve()' — found 'emitSteam(state, ball.x, ball.y, ball.z);'
  [FAIL] events: call-site coverage (js/game.js)  9 source call sites == 9 mapped call sites
         - unmapped sfx call site: js/game.js:750:sfx.serve(
         - map cites a call site the source does not have: js/game.js:751:sfx.serve(
RESULT: FAIL — 3 failure(s) in the green checks.        $ echo $?  ->  1
```

```
$ node tools/audio-port/verify-event-map.mjs --map=/tmp/event-map-redC.json   # evWallValid -> evWallDead
  [FAIL] port: function + event-id bindings resolve  10/10 port functions + 15 port event-id anchors checked in godot/src/sim/sim.gd
         - wall: godot/src/sim/sim.gd:2242 does not contain the port event id "evWallDead" — found 'add_event(state, "evWallValid")'
RESULT: FAIL — 1 failure(s) in the green checks.        $ echo $?  ->  1
```

### The 7 injected-drift scenarios (the (d) requirement)

Each is applied to a clone of the map and **must** raise ≥1 failure; a scenario that
does not is reported `[MISSED]` and the whole test exits non-zero.

| Scenario | Injection | Failures raised |
|---|---|---|
| `remove-event` | delete the `wall` event | 3 |
| `shift-anchor` | serve anchor `750` → `751` | 3 |
| `sound-swap` | `net` bound to `hit.wav` | 2 |
| `port-id-rename` | `evWallValid` → `evWallDead` | 1 |
| `new-sfx-method` | add `echoDash()` to the `sfx` object in `js/audio.js` (source drift) | 1 |
| `wav-hash-drift` | expect a wrong sha256 for `hit.wav` | 1 |
| `wav-missing` | `bounce` pointed at a non-existent WAV | 1 |

## The numbers

| Metric | Value |
|---|---|
| audio events found (derived from source) | **10** |
| events mapped to a sound + WAV + anchor | **10 / 10** |
| distinct `sfx` call sites in `js/game.js` | **9** (all mapped; one splits into two events) |
| distinct `sfx` methods in `js/audio.js` | **9** (all mapped) |
| baked WAVs reached by ≥1 event | **10 / 10** |
| baked WAVs sha256-verified | **10 / 10** |
| port event ids bound and re-resolved in `sim.gd` | **15** (distinct ids: 9) |
| port functions cross-checked | **10 / 10** |
| green checks / failures | 8 / 0 |
| injected drift cases caught | 7 / 7 |

## Honest gaps — what is NOT proven

1. **No Godot audio module exists, and none was built.** `godot/src/sim/sim.gd:17` states
   the four couplings are stripped, and the test asserts that line still exists *and*
   that `sim.gd` calls no `sfx`. There is no `AudioStreamPlayer`, no
   `AudioStreamRandomizer`, no autoload, no bus layout anywhere in `godot/`.
2. **Nothing has ever been played by the engine.** No playback, no mixing, no volume
   applied in Godot. This contract is data + source assertions; it is not an engine test
   and does not claim parity of *sound*.
3. **No listening test, and none claimed.** Consistent with
   [`audio-port-route.md`](../tickets/audio-port-route.md) §"Still open": the host has no
   sound device. The baked WAVs plus the audition page remain the ear artefacts.
4. **Volume/feel numbers are the reference's, not tuned.** Master `0.5` and music bus
   `0.55` are the only two gain numbers the reference defines; there is no target
   loudness, no headroom, no ducking, no panning and no per-event runtime volume. Any
   Godot mixer value beyond these is a new decision, not a port.
5. **The port's event ids are strings, not numbers.** `state.gd:18-20` says `events` and
   `pointMessage` hold message ids; `add_event` (`sim.gd:241`) takes a `String`. There is
   no numeric event-id space in the port today, so this contract binds to the string ids
   that exist. The task brief called them "numeric event IDs" — that description does not
   match the port at HEAD `2979588`; recorded here as a correction rather than a silent
   assumption. If a numeric enum is introduced later, `eventIdAnchors` is the single place
   to re-point and the test will fail until it is re-pointed.
6. **Which port id should *carry* each sound is undecided.** For `serve` and `hit` the
   port stores no id at the trigger, so the map records an empty list. Deciding that (say)
   a new `evServeStruck` id should exist is a presentation-layer/port-ticket decision this
   contract deliberately does not take.
7. **Variant counts are out of contract.** How many randomised variants a Godot player
   holds for `hit`/`wall`/`net`/`serve`/`special` (the route proposes 4-6) is a realisation
   choice; the reference has no variant concept — the variation lives inside the noise
   buffer drawn per play at `js/audio.js:45`.
8. **Music is out of contract.** The 5 generative voices are not event-triggered and have
   no baked WAV, so they cannot appear in a WAV-coverage check. They stay owned by
   `audio-port-route.md`.
9. **Overlap is asserted from source only.** `hit` + `special` are played together
   (`js/game.js:1893` then `:1898`); the map records the overlap, but no engine test proves
   simultaneous playback.
10. **`--map` RED cases were run against `/tmp` copies.** The repo's `event-map.json` was
    never mutated, so the RED evidence proves the *checks* react to drift; it does not
    prove the on-disk asset would be edited by the harness (it deliberately is not).

## Re-run everything

```bash
cd /root/projects/steam-circuit-padel-pro \
 && node tools/audio-port/verify-event-map.mjs \
 && node tools/audio-port/verify-event-map.mjs --drift=remove-event; echo "drift exit=$? (1 == drift caught, by design)"
```

Expected: the first command exits 0 with `RESULT: PASS — 8 green checks, 0 failures; all 7
injected drift cases caught.`; the second exits 1 with `DRIFT DETECTED — 3 failure(s)`.

**Remaining budget: credits/spend used = 0.** No paid API call was made (no `web_search`,
no image generation, no LLM call, no installation). One `node` process and short `python3`
one-liners on `/tmp` only; Godot was never launched — no engine, no rendering, no xvfb.
