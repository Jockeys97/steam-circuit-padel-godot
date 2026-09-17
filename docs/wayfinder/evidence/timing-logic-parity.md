# Timing logic parity — the numbers behind "PERFETTO"

Ticket: `docs/wayfinder/tickets/timing-logic-parity.md` (slice S14b). Two scripted
scenarios, two engines, compared field by field and tick by tick. The port's timing
model produces the reference's numbers **exactly as the reference prints them** (six
decimals, `toFixed(6)` / `Digest.fixed`): 17 of 17 fields on 3 601 of 3 601 ticks, in
both scenarios, with identical digests and identical timing-stream hashes.

Host: macOS 26.2, engine `/Applications/Godot.app/Contents/MacOS/Godot`
`4.7.2.stable.official.ed1daf0bf` (the run asserts the pin itself via
`res://tests/smoke_test.gd`). Node `v26.8.2`, `python3` 3.9.6.

## 1. Verdict, field by field

`# tm` lines are the new per-tick trace (one line per tick, §2). "agree" is exact
string equality of the printed field, which is the reference's own precision.

| ticket field | trace field | agree / ticks | note |
|---|---|---|---|
| `shotCharge` | `charge` | 3601/3601 (both scenarios) | ramps 0 → 1 at `dt/1.05` |
| `shotRead.active` | `active` | 3601/3601 | 1 on 149 ticks (2024), 376 (seed 7) |
| `shotRead.eta` | `eta` | 3601/3601 | `null` on 3 381 (2024) / 2 829 (seed 7) ticks, finite on the rest |
| `shotRead.perfectWindow` | `perfectWindow` | 3601/3601 | 686 distinct values (2024) / 674 (seed 7), all inside [0.026, 0.07] |
| `shotRead.advice` | `advice` | 3601/3601 | all six ids across the two scenarios |
| `shotRead.profile` | `profile` | 3601/3601 | `control`/`attack`/`risk` |
| `shotRead.overlap` | `overlap` | 3601/3601 | 1 on 71 (2024) / 953 (seed 7) ticks |
| `quality` (assessment) | `fbQuality` | 3601/3601 | set on 752 (2024) / 376 (seed 7) ticks, 8 / 4 distinct values |
| the `x3` flag | `shotType`, `x3ai`, `x3player` | 3601/3601 | `smash-x3` on 867 ticks (2024), `aiX3Recovery > 0` on 372 |

Extras the same lines carry, so the comparison is not narrowed to the ticket's list:
`fbGrade`, `fbProfile`, `fbMode`, `serving`, `queuedCharge`, `queuedPower`.

## 2. The two scripted scenarios

Same input script on both engines, a pure function of `(tick, state)` — no wall
clock, no unseeded randomness:

```
charging: true                            every tick
hit:      (serving and shotCharge >= 0.999)                       -> the serve strike
          OR (shotRead.active and eta < 0.30 | 0.10 on a 480-tick square wave)
analogAim: true, aim = 0.7 | -0.35 on a 900-tick square wave
moveX/moveY: the frozen harness's movement pattern (scripts/parity-digest.mjs:89-98)
setsToWin: 3 (parity-coverage-frontier.md §4.3), athlete 0 ("maestro")
```

| | scenario A | scenario B |
|---|---|---|
| seed / ticks / every | 2024 / 3600 / 120 | 7 / 3600 / 120 |
| why this one | reaches the x3 branch and the late grade | reaches all six advice ids and `overlap` |
| `activeTicks` / `etaFiniteTicks` / `etaMin..etaMax` | 149 / 220 / -0.818479..0.323798 | 376 / 772 / -0.896497..0.544986 |
| `advice` | read:3155, lob:294, smash:150, vibora:2 | read:1953, chiquita:722, smash:478, drive:311, lob:128, vibora:9 |
| `profile` | attack:1932, control:996, risk:673 | attack:2029, control:1029, risk:543 |
| `overlap=1` ticks | 71 | 953 |
| `fbGrade` | none:2849, perfect:658, late:94 | none:3225, late:188, perfect:188 |
| `fbQualityDistinct` | 8 | 4 |
| shot types (non-serve) | smash-x3:867, drive:841, volley:387, smash-x2:373 | lob:1304, drive:872, smash-x2:112, wall-angle:87, volley:46 |
| x3 | `x3SmashTicks=867`, `x3aiTicks=372` | 0 |

Those counters are printed by both engines (`# cov` lines) and compared textually, so
two streams that agreed on every field but exercised different branches cannot pass.

## 3. Commands (exact)

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
ROOT=/Users/alessiofantini/Documents/steam-circuit-padel-godot
cd "$ROOT"

# A. the reference engine's timing stream (reads this repo's js/, byte-identical to
#    the read-only reference: shasum -a 256 js/game.js  ->  22b8a4f4154d8ed2b35d107cd94b41e114a53b6fbe3da07c156103e989040fe7,
#    same hash as /Users/alessiofantini/Documents/Padel/js/game.js)
node tools/sim-port/timing-trace.mjs --seed=2024 --ticks=3600 --every=120 > tools/sim-port/out/timing/js-2024.txt
node tools/sim-port/timing-trace.mjs --seed=7    --ticks=3600 --every=120 > tools/sim-port/out/timing/js-7.txt

# B. the port's timing stream + the in-process gate
$GODOT --headless --path godot/ --script res://tests/timing_feedback_test.gd -- \
  --seed=2024 --ticks=3600 --every=120 --trace=tools/sim-port/out/timing/gd-2024.txt \
  > tools/sim-port/out/timing/gd-2024.log 2>tools/sim-port/out/timing/gd-2024.err
$GODOT --headless --path godot/ --script res://tests/timing_feedback_test.gd -- \
  --seed=7 --ticks=3600 --every=120 --trace=tools/sim-port/out/timing/gd-7.txt \
  > tools/sim-port/out/timing/gd-7.log 2>tools/sim-port/out/timing/gd-7.err

# C. the new comparator, and the in-house one on the same pair
python3 tools/sim-port/timing-compare.py tools/sim-port/out/timing/js-2024.txt tools/sim-port/out/timing/gd-2024.txt
python3 tools/sim-port/timing-compare.py tools/sim-port/out/timing/js-7.txt    tools/sim-port/out/timing/gd-7.txt
python3 tools/sim-port/trace-compare.py  tools/sim-port/out/timing/js-2024.txt tools/sim-port/out/timing/gd-2024.txt
python3 tools/sim-port/trace-compare.py  tools/sim-port/out/timing/js-7.txt    tools/sim-port/out/timing/gd-7.txt

# D. the negative controls
python3 tools/sim-port/out/timing/sensitivity.py
$GODOT --headless --path godot/ --script res://tests/timing_feedback_test.gd -- --ticks=200 --inject-failure
```

Delivered for this ticket (all new, nothing tracked was edited):

| file | what it is |
|---|---|
| `tools/sim-port/timing-trace.mjs` | the reference engine's per-tick timing stream |
| `tools/sim-port/timing-compare.py` | the field-by-field comparator (imports `trace-compare.py`'s loader for the digest half) |
| `godot/tests/timing_feedback_test.gd` | the in-process gate **and** the port's per-tick stream (`--trace=<path>`) |
| `tools/sim-port/out/timing/*` | the two streams, the comparator transcripts, `sensitivity.py` and its mutants |
| this document | |

Stream sizes: `js-2024.txt` and `gd-2024.txt` 3 760 lines each, `js-7.txt` and
`gd-7.txt` 3 749 lines each; 3 601 `# tm` lines in every one of them.

## 4. The comparator's verdict (real output, transcripts in `out/timing/`)

```
TIMING-COMPARE js=.../js-2024.txt gd=.../gd-2024.txt
# tm lines: js=3601 gd=3601
# con lines: js=20 gd=20
# cov lines: js=11 gd=11
-- constants (20 compared) --        constants identical: 20/20
-- fields over 3601 shared ticks --
  ok  charge: agree=3601 differ=0     ok  eta: agree=3601 differ=0
  ok  active: agree=3601 differ=0     ok  perfectWindow: agree=3601 differ=0
  ok  advice: agree=3601 differ=0     ok  profile: agree=3601 differ=0
  ok  overlap: agree=3601 differ=0    ok  serving: agree=3601 differ=0
  ok  fbGrade: agree=3601 differ=0    ok  fbQuality: agree=3601 differ=0
  ok  fbProfile: agree=3601 differ=0  ok  fbMode: agree=3601 differ=0
  ok  shotType: agree=3601 differ=0   ok  queuedCharge: agree=3601 differ=0
  ok  queuedPower: agree=3601 differ=0  ok  x3ai: agree=3601 differ=0
  ok  x3player: agree=3601 differ=0
all 17 fields identical on all 3601 ticks
-- digests (via tools/sim-port/trace-compare.py's loader) --
  digest body sha256: js=560b2acf12106bc795ff7c934afadafabb823dc734f24272d342c4d51f26e3be gd=560b2acf... same=True
  declared digest sha256: js=560b2acf... gd=560b2acf...
  # tr identical on all 45 transition ticks
-- declared timing hashes --
  js: declared=401009a7cc07a7d6b207184aebd190a1b1c3d9b89e291099c99321a64e50ecda recomputed=401009a7... match=True
  gd: declared=401009a7... recomputed=401009a7... match=True
TIMING-COMPARE RESULT=IDENTICAL
```

Seed 7, same tool: `all 17 fields identical on all 3601 ticks`,
digest `6677be4e91fe1269b7e6ab09f6a51495018a02d6c1051464c103141be1e5b286` on both
sides, timing hash `9a05308f39c5f371e4b4f9d2584b66a6146e6d060a96d7e44a91d29d1e33acbf`,
40/40 `# tr` ticks identical, constants 20/20, coverage 11/11 —
`TIMING-COMPARE RESULT=IDENTICAL`.

Engine summaries, printed by both halves and equal field for field:

```
TIMING-TRACE JS PASS seed=2024 ticks=3600 tracedTicks=3601 every=120 finalRngState=1944297631 digestSha256=560b2acf... timingSha256=401009a7...
TIMING-TRACE GD PASS seed=2024 ticks=3600 tracedTicks=3601 every=120 finalRngState=1944297631 digestSha256=560b2acf... timingSha256=401009a7...
TIMING-TRACE JS PASS seed=7 ticks=3600 tracedTicks=3601 every=120 finalRngState=-1463071224 digestSha256=6677be4e... timingSha256=9a05308f...
TIMING-TRACE GD PASS seed=7 ticks=3600 tracedTicks=3601 every=120 finalRngState=-1463071224 digestSha256=6677be4e... timingSha256=9a05308f...
```

The in-house comparator on the same pair — the check that the two streams are the
same run and not merely two runs that agree on the timing fields:

```
TRACE-COMPARE ... 2024: # tr lines js=45 gd=45 | # ev lines js=37 gd=37 | digest lines js=31 gd=31
  digest sha256 same=True | TR identical on all 45 transition ticks
  EV tick numbers identical: [0, 127, 251, 325, ... 3529]
  serveAttempts transitions [js] == [gd] == [(840, 0, 1), (1200, 1, 0)]
  STRIKE identical (7 lines): 126 first charge=1.000000 | 626 first 0.999206 | 753 second | 1309 first | 2275 first 0.999206 | 2941 first | 3528 first serveSide=ai
  DOUBLE-FAULT identical (0)   SET-CLOSED identical (0)
TRACE-COMPARE RESULT=IDENTICAL
```

Seed 7: `# tr` 40/40, `# ev` 31/31, 7 strikes, `TRACE-COMPARE RESULT=IDENTICAL`.

The three x3 events of scenario A land in the compared stream (`js`/`gd` tick numbers
identical): `evSmashX3Downgrade` at tick 961, `evSmashX3` at 1974, `msgSmashX3Wall` at
445 / 2104 / 3269 — i.e. the x3 decision at `js/game.js:1213` /
`godot/src/sim/sim.gd:1330` is exercised, not just present.

## 5. The constants, from each engine's own balance table

Both halves print the 20 timing constants read from their **own** table
(`BALANCE` in `js/data.js:108-345`, `Frozen.balance()` in the port) and the comparator
diffs them: `constants identical: 20/20` in both scenarios.

```
perfectTimingWindow 0.055000   goodTimingWindow 0.130000    timingWindowRunPenalty 0.018000
timingWindowEnergyPenalty 0.018000  timingWindowGlassPenalty 0.009000  timingWindowSplitStepBonus 0.012000
timingWindowChargePenalty 0.018000  timingWindowMin 0.026000  timingWindowMax 0.070000
timingDecaySpan 0.900000       qualityTimingWeight 0.440000  playableHitHeight 108.000000
ballGravity 720.000000         smashMinHeight 46.000000      lateGraceFactor 0.300000
sprintAccuracyPenalty 0.120000 splitStepQualityBonus 0.075000  rallyEnergyFloor 0.160000
smashX2MinQuality 0.780000     smashX3MinQuality 0.900000
```

## 6. The in-process gate: `godot/tests/timing_feedback_test.gd`

```sh
$GODOT --headless --path godot/ --script res://tests/timing_feedback_test.gd -- \
  --seed=2024 --ticks=3600 --every=120 --trace=...
# -> 100 ok lines, PASS 100/100 (100 checks)
$GODOT ... -- --seed=7 --ticks=3600 --every=120 --trace=...
# -> 92 ok lines, PASS 92/92 (the 8 documented-scenario guards are skipped on a probe run, printed as a note)
```

What it asserts, in its own words (see the log for all of them):

- `shotRead`'s default literal is the reference's six keys with the reference's six
  values (`js/game.js:220`: `active false`, `eta null`, `perfectWindow 0.055`,
  `advice "read"`, `profile "control"`, `overlap false`), and
  `balance.perfectTimingWindow` is `0.055`;
- **no field is missing**: after one `update_shot_read` the dictionary carries the
  eight keys the reference's `js/game.js:916-925` writes, `precision` and `tight`
  included;
- the window's boundaries as constants: `timingWindowMin 0.026`,
  `timingWindowMax 0.07`, `timingWindowChargePenalty 0.018`; the computed window at
  charge 0 / 0.5 / 1.0 = `0.055` / `0.0505` / `0.037`; the charge term is quadratic
  (half the charge costs a quarter of the penalty); running costs
  `timingWindowRunPenalty`, the split-step pays `timingWindowSplitStepBonus`, my own
  glass costs `timingWindowGlassPenalty` and the opponent's glass costs nothing; the
  four penalties together land at `0.014680`, below `timingWindowMin`, and the clamp
  is what binds; `base + splitStepBonus = 0.067 < 0.07`, so the upper clamp is inert;
- `eta` is `null` while the ball is not arriving (`vy 20`, `vy 0`, and exactly at the
  strict `vy > 28` guard) and finite when it is — including the "too high" case,
  where it waits for the descent under `playableHitHeight` (`0.341565 s` against
  `0.050000 s` to the paddle line) — a case that never happens in either scenario;
- the grade vocabulary is the reference's four ids; the sweep over the swing age
  produces exactly `perfect`, `good`, `early`; half a window early is still perfect
  and half a window beyond it is not; a contact with the ball behind the paddle is
  `late`;
- every grade's derived HUD key resolves: `Locale.is_resolvable("shot" +
  Capitalize(grade))` for all four, `shot:<grade>` derives exactly `shotPerfect` /
  `shotGood` / `shotEarly` / `shotLate`, and `shotAdvice_<id>` resolves for all six
  advice ids;
- `quality` is the weighted sum of the parts the call returns — with the weights it
  reads from the balance table, including `qualityTimingWeight 0.44`,
  `goodTimingWindow 0.13`, `timingDecaySpan 0.9` — and the residual (the `control`
  term, which the reference's own return literal does not expose) is constant across
  calls and inside its clamp band;
- over the 3 601 traced ticks: no tick has `active` without an `eta`, every active
  tick's `eta` is inside `(-0.16, 1.15)`, every non-null `eta` is finite, every
  `perfectWindow` stays inside the band, every advice / profile / grade id is in the
  reference's vocabulary;
- the release rules (`js/game.js:2624-2627` for the serve, `:2694-2707`
  `queueChargedShot` for a rally hit), detected from the trace itself: 15 resets in
  scenario A (9 rally, 6 serve) and each one restarts the charge from zero; every
  rally release carries its charge into `queuedShotCharge` and never more than the
  charge held at the release; every release widens the perfect window; on 9 of the
  15 resets an incoming ball is still readable, so the release does not blank the
  `eta`;
- coverage guards, so the gate cannot pass on an uninteresting run: `active` on >100
  ticks, finite `eta` on >50 ticks, `smash-x3` and `x3ai > 0` in the documented
  scenario.

**The gate can go red** (negative control, `--inject-failure` shifts the expected
perfect window by 1 ms):

```
$GODOT --headless --path godot/ --script res://tests/timing_feedback_test.gd -- --ticks=200 --inject-failure
FAIL shotRead.perfectWindow default is 0.055: expected 0.056, got 0.055
FAIL balance.perfectTimingWindow is 0.055: expected 0.056, got 0.055
FAIL window at charge 0 is 0.055: expected 0.056000000000, got 0.055000000000
FAIL the opponent's glass is not my penalty: expected 0.056000000000, got 0.055000000000
FAIL 88/92          exit=1
```

## 7. The comparator can fail (`out/timing/sensitivity.py`)

```
ok control: the same stream twice: exit=0 (expected 0)
ok control: js vs gd: exit=0 (expected 0)
ok mutant: perfectWindow +0.000001 on one tick: exit=1 (expected 1)
ok mutant: eta null -> 0.000000 on one tick: exit=1 (expected 1)
ok mutant: the wrong scenario (js-2024 vs gd-7): exit=1 (expected 1)
SENSITIVITY PASS
```

The one-millionth mutant is reported as
`tick=000880 perfectWindow: js=0.037000 gd=0.037001` — the smallest difference the
reference's own printed precision can express. Nothing here widens a tolerance: the
comparison is per-field string equality.

## 8. Non-regression, and what the port did not have touched

| suite | command | result |
|---|---|---|
| harness | `$GODOT --headless --path godot/` | `PASS 8/8` (before and after this work) |
| slice | `$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd` | `FAIL 324/325` — 1 red, not mine: the `padel.pck` clone artefact (`godot/build/` is gitignored). An intermediate run in this same window read `FAIL 287/289` with a second red, `godot/game/out/timing_probe.gd` (another lane's probe left in an exporter-excluded tree); that file is gone and the red with it — neither run's reds are mine |
| audits | `$GODOT --headless --path godot/ --script res://tests/audits/run_all.gd` | `PASS 10/10`, 241 `ok` lines |
| input | `$GODOT --headless --path godot/ --script res://tests/input/run_all.gd` | `PASS 5/5`, 398 `ok` lines |
| the port's simulation | `git status --short godot/src/sim/` | empty — no file in `godot/src/sim/**` was edited, so **no digest moved**: the parity trio is exactly the one already recorded |

No proven divergence was found, so the ticket's "sim.gd only with a proven divergence"
clause was not used: the port's `sim.gd` is byte-identical to what it was.

## 9. Where a field is missing, and the hand-off to the timing-hud lane

**Nothing is missing in the simulation.** All eight `shotRead` keys, the `quality` /
`grade` / `profile` / `mode` of the shot feedback and both x3 recovery flags exist in
the port and carry the reference's numbers. What the presentation lane has to know:

1. **The sim stores ids, not sentences.** `shotFeedback.text` is `"shot:<grade>"` and
   `.mode` is `"shotMode:<mode>"` or `"smashMissedHint"` (`sim.gd:1244-1249`,
   `:2590-2598`, `:2927-2935`), against the reference's already-localized strings
   (`js/game.js:1067`, `:2900`, `:3188`). This is deliberate (state.gd header) and the
   HUD already derives the keys (`hud.gd`: `GRADE_COLORS` 549, `grade_of` 560,
   `mode_of` 565, `feedback_label` 576 — line numbers as of this run, the file is
   being edited by the timing-hud lane). This document adds the
   missing half of that claim: **every key those ids derive to resolves in `Locale`**,
   for all four grades and all six advice ids (asserted, §6).
2. **`shotFeedback.profile` does not exist at the smash-missed site** — neither in the
   port (`sim.gd:2590-2597`) nor in the reference (`js/game.js:2900-2906`). A HUD that
   reads `profile` unconditionally errors on exactly that feedback.
3. **The advice chip's amber state is unreachable.** The reference colours the word by
   `state.shotRead.profile === "aggressive"` (`js/render.js:1745`), but `shotProfile`
   only ever returns `control`, `attack` or `risk` (`js/game.js:826-832`; measured over
   both scenarios: attack/control/risk only, no fourth value). `hud.gd:612-624`
   mirrors the rule verbatim and its comment already notes the two-value shape; the
   lane should decide whether `risk` maps to amber (a deliberate deviation, so the
   player sees the state the model actually has) or whether the faithful dead branch
   stays. Not a port diverge — the reference never lights it either.
4. **The advice word is a read-model field, not a serving one.** The reference draws
   it only when `!state.serving && !(state.pointPause > 0)` (`js/render.js:1729`), but
   the sim keeps emitting `advice` while serving (measured: `advice=read` on 3 155 of
   3 601 ticks in scenario A includes the service phase). The gate is the HUD's.
5. `shotRead.precision` and `.tight` (the tight-angle meter, `js/render.js:1690-1724`)
   are written by the port with the reference's inputs; their values were asserted
   *present* but are **not** in the compared stream (§10).

## 10. What this does NOT prove

- **Two scenarios, one input family.** Both are `quick` matches, athlete 0, one human
  player, `solo`; the same seed family (the RNG stream is the reference's own). A
  divergence that needs coop, PvP, a different athlete or a different tier is not
  excluded by this comparison — though nothing on the timing path branches on those.
- **Two of the four grades are exercised in the streams.** `perfect` and `late` appear
  in the compared ticks; `good` and `early` are pinned only by the in-process sweeps
  (§6), not by a tick-by-tick cross-engine sample.
- **`x3player` never fires** in either scenario (0 ticks): the player side never hits a
  `smash-x3` because the input script never double-taps into a smash. The AI side does
  (867 `smash-x3` ticks, 372 ticks with `x3ai > 0`), and the *decision* is exercised
  (`evSmashX3`, `evSmashX3Downgrade`, `msgSmashX3Wall` all in the compared ticks).
- **`shotRead.precision` / `.tight` values are not compared** tick by tick; only their
  presence and the reference's inputs are asserted.
- **The human path is scripted, not played.** The input driver is a pure function of
  the state; a real controller (analog triggers, buffered swings, double taps) can
  reach state combinations this script never produces.
- **The comparison is on the port's side of the seam only.** What the HUD finally
  draws was not looked at (it is the presentation lane's ticket); this document proves
  the numbers it would draw from.

## 11. Where the ticket is wrong or imprecise

1. `js/game.js:900` / `:902` and `sim.gd:1053` / `:1071` are the **call sites** inside
   `updateShotRead` / `update_shot_read`, not the definitions (definitions:
   `js/game.js:841` `contextualPerfectWindow`, `:826` `shotProfile`, `:866`
   `playableEta`, `:883` `updateShotRead`; port `sim.gd:1007`, `:111`, `:1028`,
   `:1048`, and `:1330` for the x3 decision — that one is right). The table reads as
   if they were the definitions; every anchor does resolve to a real line.
2. The command block says `node tools/sim-port/<comparator>.mjs <js-trace> <gd-trace>`.
   The in-house stream comparator of this repo is Python
   (`tools/sim-port/trace-compare.py`), so this ticket's comparator is
   `tools/sim-port/timing-compare.py` — a `.mjs` would have been the odd one out.
   Both run on the same pair and are reported above.
3. "Float traps: Godot's `Vector2`/`float` are single precision" does not hold for this
   port's timing path: GDScript `float` is 64-bit and the path touches neither a
   `Vector2` nor a `PackedFloat32Array` (`state.gd`, `entities.gd` are plain
   `RefCounted` classes with `float` members), which is why 17 fields × 3 601 ticks ×
   2 scenarios printed identical at six decimals, with no near-edge case anywhere.
   The advice to avoid edge assertions was followed for a different reason: an
   edge-valued assertion fails on an off-by-one-tick reading, not on rounding.
4. The tests section asks for "a released charge carries the last charging `eta`".
   Read as written, the model does not do that and should not: `eta` is a property of
   the incoming ball (`js/game.js:866-881`) and a release never touches it, while what
   a release *does* carry is the **charge**, into `queuedShotCharge`
   (`js/game.js:2694-2707`), and the serve release carries it nowhere
   (`js/game.js:2624-2627`). Both readings are covered: the charge carry as a
   tick-by-tick compared field plus the release rules (§6), and "the release does not
   blank the `eta`" as a counted invariant (9 resets with a readable incoming ball in
   scenario A).
