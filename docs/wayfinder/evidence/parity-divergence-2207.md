# Parity divergence at tick 2207 — root cause, fix, verification

**Date:** 2026-09-16 (CEST) · **Host:** Linux, Godot `4.7.2.stable.official.ed1daf0bf`
**Slice:** S1 — deterministic simulation parity (`js/game.js` → `godot/src/sim/sim.gd`)
**Status:** **ROOT-CAUSED AND FIXED.** 8 of 12 matrix scenarios went DIVERGED → IDENTICAL;
the 4 previously-IDENTICAL scenarios produced **byte-identical digest hashes** (not just
"still identical").

---

## 1. Reproduction and the true first divergence

```sh
cd /root/projects/steam-circuit-padel-pro
node scripts/parity-digest.mjs --seed=2024 --ticks=2215 --every=1 > /tmp/js2024.txt
tools/sim-port/parity-digest-gd.sh --seed=2024 --ticks=2215 --every=1 > /tmp/gd2024.txt
tools/sim-port/compare-digests.py /tmp/js2024.txt /tmp/gd2024.txt
```

Before the fix:

```
DIVERGED firstTick=002207 fields=spin,v
  JS 002207 rngState=-1903081286 rngCalls=7 ball=(501.579959,223.000000,74.000000) v=(-164.480614,467.924202,122.068019) spin=-6.579225 …
  GD 002207 rngState=-1903081286 rngCalls=7 ball=(501.579959,223.000000,74.000000) v=(-165.878629,467.924202,122.068019) spin=-6.635145 …
```

Confirmed against the brief: at the first differing tick the two engines agree on
`rngState`, `rngCalls`, `ball`, `v.y`, `v.z`, `bounces`, `shotType` (`smash-x2`),
`smashStage` and all four paddles; only `v.x` differs (JS − GD = `1.398015`), and
`spin` is `clamp(v.x * 0.04, -24, 24)`, i.e. a consequence, not a second cause.

| seed | ticks | every | first differing tick | fields |
|---|---|---|---|---|
| 2024 | 2215 | 1 | **2207** | `v.x`, `spin` |
| 7 | 4500 | 1 | not probed at `--every=1` before the fix (its finest before-run was `--every=60`, first differing sample 4200); verified identical *after* the fix — §4(a) | — |

(`--every=60` hides this: the first *sampled* difference for seed 2024 is 2280.)

Raw streams (byte sizes):

| file | bytes |
|---|---|
| `/tmp/js2024.txt` → `tools/sim-port/out/before-js-2024-2215-1.txt` | 934 431 |
| `/tmp/gd2024.txt` → `tools/sim-port/out/before-gd-2024-2215-1.txt` | 1 045 309 |

## 2. Localising: the ball's `v.x` is set from a single target

At tick 2207 the shot is `smash-x2`, executed by the AI's `opponentMate` paddle
(contact at `ball = (501.57996, 223.0, 74.0)`). Tracing `js/game.js:1445` and
`godot/src/sim/sim.gd:1495` (the ported counterparts) shows both call the *same*
trajectory helper on the *same* target:

`js/game.js:1338-1347`
```js
function setComputerTrajectory(ball, targetX, targetY, flightTime) {
  const dragRate = -60 * Math.log(BALANCE.airDrag);
  const dragDistanceFactor = dragRate > 0.0001
    ? (1 - Math.exp(-dragRate * flightTime)) / (dragRate * flightTime) : 1;
  const dragCompensation = 1 / dragDistanceFactor;
  ball.vx = ((targetX - ball.x) / flightTime) * dragCompensation;
```
`godot/src/sim/sim.gd:1416-1421` is line-for-line equivalent. Since `v.y` and `v.z`
match exactly, `flightTime`, `dragCompensation` and `targetY` are identical — so the
*only* free variable is `target.x`. Inverting the digest: `targetY = COURT.bottom - 44 =
520`, `flightTime = 0.62744`, giving `comp/t = 1.575502` and `Δtarget.x = -0.887346`
(GD − JS). The entire divergence lives in `target.x`, computed ~250 lines earlier.

## 3. The named root cause

Instrumenting `chooseComputerShot`, `applyComputerShot` and `evaluateShotQuality`
(a `globalThis`-gated copy of `js/game.js` for the reference side, a
`SCP_SIM_DBG`-gated `print` on the Godot side — see `tools/sim-port/probe/README.md`)
pins it to the contact assessment:

| field at the tick-2207 contact | JS | Godot |
|---|---|---|
| `kind` | `smash-x2` | `smash-x2` |
| `baseX` | 400.115325319469 | 400.115325319469 |
| `sideBias` / `ampiezza` / `accuracyError` / `skill` | −1 / 1.64 / 17.6 / 0.6 | −1 / 1.64 / 17.6 / 0.6 |
| `timing` / `position` / `height` / `energy` / `control` | 0.9428340920973892 / 0.8245853686822328 / 0.9142857142857143 / 0.9656106000000056 / 0.9239999999999999 | identical |
| **`balance`** | **1** | **0.80566666666667** |
| `quality` | 0.922887347374692 | 0.89956734737469 |
| `risk` | 0.08721618841654968 | 0.11359164619981 |
| `executionSpread` = `risk·(1−skill·0.45)` | 0.06366781754408127 | 0.08292190172586131 |
| `moveRatio` / `motion` (the paddle, both engines) | 0 / 0.8833333333333333 | 0 / 0.8833333333333333 |

Every component of `quality` matches except `balance`, and every input to `balance`
matches except the one term below.

**The defect is a mistranslated nullish-coalescing operator.**

`js/game.js:942` (and the identical `js/game.js:844`):
```js
const movementPenalty = clamp(paddle.moveRatio ?? paddle.motion ?? 0, 0, 1) * 0.22 + sprintPenalty;
```
`godot/src/sim/sim.gd:1114` **before the fix** (and the identical line 1011):
```gdscript
var movement_penalty: float = clampf(paddle.moveRatio if paddle.moveRatio != 0.0 else paddle.motion, 0.0, 1.0) * 0.22 + sprint_penalty
```

`??` falls back only on `null`/`undefined`; `if x != 0.0 else y` falls back on **zero**.
In the JavaScript reference `moveRatio` is *never* null — it is initialised to a number
at `js/game.js:54` (`moveRatio: 0,`) and reset to a number at `js/game.js:400`
(`paddle.moveRatio = 0;`) — so the `??` chain is dead code there and the reference always
uses `paddle.moveRatio`. `motion` is a *separate, decaying animation echo*
(`js/game.js:2445-2447`: `paddle.motion = … ? 1 : Math.max(0, paddle.motion - dt * 7)`),
which lags behind `moveRatio` for several frames after a paddle stops. So whenever a
paddle is at a standstill (`moveRatio == 0`) while `motion` is still non-zero, the port
injected a phantom movement penalty — here `0.8833333 × 0.22 = 0.1943333` — into
`balance_`.

Consequence chain, arithmetically closed end to end:

```
balance_  1.0      (JS)   vs  0.8056667     (GD)
quality   +0.12·Δbalance = 0.922887347374692 vs 0.89956734737469   (Δ = 0.02332) ✓
risk      (1−quality)·(0.48+aggression·0.82); the multiplier is identical
          (r_js/(1−q_js) = r_gd/(1−q_gd) = 1.13102306) so Δrisk = 0.026375 ✓
spread    risk·0.73 → Δspread = 0.01925408
target.x  += (rng − 0.5)·spread·150   →  Δtarget.x = −0.8873459
v.x       = (target.x − ball.x)·comp/t  →  Δv.x = −1.3980156  (predicted)
                                            1.398015           (measured) ✓
spin      clamp(v.x·0.04) — consequence only
```

`motion` is deliberately *not* in the digest, which is why the two engines' printed
fields agreed on this tick while the hidden operand did not.

### Fix (one attempt, `godot/src/sim/**` only)

```
--- a/godot/src/sim/sim.gd
+++ b/godot/src/sim/sim.gd
@@ -1008,7 +1008,7 @@
-	var moving := clampf(paddle.moveRatio if paddle.moveRatio != 0.0 else paddle.motion, 0.0, 1.0)
+	var moving := clampf(paddle.moveRatio, 0.0, 1.0)
@@ -1111,7 +1111,7 @@
-	var movement_penalty: float = clampf(paddle.moveRatio if paddle.moveRatio != 0.0 else paddle.motion, 0.0, 1.0) * 0.22 + sprint_penalty
+	var movement_penalty: float = clampf(paddle.moveRatio, 0.0, 1.0) * 0.22 + sprint_penalty
```

Both lines are the *same* defect translated twice (`js/game.js:844` → `sim.gd:1011`,
`js/game.js:942` → `sim.gd:1114`); both were fixed because dropping the `??` fallback is
provably behaviour-preserving on the reference (where `moveRatio` is always a number)
and leaving one in place would have left the same latent divergence in
`contextualPerfectWindow`, i.e. in the timing window of *every* shot.

`paddle.moveRatio` is a plain `float = 0.0` in the port too (`godot/src/sim/entities.gd:26`,
reset at `:118`), so `clampf(paddle.moveRatio, 0.0, 1.0)` is the exact port of the
reference expression. **No other change was made.** The temporary `print` hooks were
removed (`grep -c DBG godot/src/sim/sim.gd` → `0`); the pre-fix file is
`/tmp/sim.gd.bak` (md5 `d1365b33b9675796f7263955cedb88bd`), the fixed file md5
`b0779b6e1b981124bb7dcdef92fa40e4`, 141 741 bytes.

A sweep for the same mistake found one remaining `x if x != 0.0 else y`
(`sim.gd:2215`, `ball.vx if ball.vx != 0.0 else ball.spin`). That one is **correct**: it
ports `Math.sign(ball.vx || ball.spin)` (`||`, not `??`), and for a numeric `vx`
`x || y` and `x != 0 else y` agree. Left untouched.

## 4. Verification

### (a) Fine probe — seed 2024, `--every=1`

```sh
node scripts/parity-digest.mjs --seed=2024 --ticks=2215 --every=1 > /tmp/js2024_fix.txt
tools/sim-port/parity-digest-gd.sh --seed=2024 --ticks=2215 --every=1 > /tmp/gd2024_fix.txt
tools/sim-port/compare-digests.py /tmp/js2024_fix.txt /tmp/gd2024_fix.txt
→ IDENTICAL common_ticks=2216 js_ticks=2216 gd_ticks=2216
```
(934 431 / 1 045 309 bytes; archived as `tools/sim-port/out/after-{js,gd}-2024-2215-1-fixed.txt`.)

Second, independent fine probe on the *other* seed family, well past its own sampled
divergence point (4200):

```sh
node scripts/parity-digest.mjs --seed=7 --ticks=4500 --every=1 > /tmp/js7_fine.txt
tools/sim-port/parity-digest-gd.sh --seed=7 --ticks=4500 --every=1 > /tmp/gd7_fine.txt
tools/sim-port/compare-digests.py /tmp/js7_fine.txt /tmp/gd7_fine.txt
→ IDENTICAL common_ticks=4501
```

### (b) The 12-scenario matrix

Re-run with `tools/sim-port/run-parity-matrix.sh` — the scenario list is read from the
"before" file `tools/sim-port/out/coverage-matrix.jsonl`, and each scenario is run the
way the before-run was run (`--json=` for the JS side, `--js=` for the Godot side, so
`parity_digest_gd.gd`'s own comparator runs *as well as* `compare-digests.py`: two
independent comparators).

```sh
bash tools/sim-port/run-parity-matrix.sh tools/sim-port/out/coverage-matrix-after.jsonl
```

| # | scenario (seed/ticks/every) | verdict before | verdict after | `gd_exit` before → after | digest_js == digest_gd |
|---|---|---|---|---|---|
| 1 | 12345/1440/60 | IDENTICAL | IDENTICAL | 0 → 0 | yes |
| 2 | 12345/1440/120 | IDENTICAL | IDENTICAL | 0 → 0 | yes |
| 3 | 999/1440/60 | IDENTICAL | IDENTICAL | 0 → 0 | yes |
| 4 | 999/28800/120 | **DIVERGED** (t=3000 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 5 | 7/4320/60 | **DIVERGED** (t=4200 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 6 | 7/14400/60 | **DIVERGED** (t=4200 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 7 | 2024/14400/120 | **DIVERGED** (t=2280 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 8 | 2024/720/7 | IDENTICAL | IDENTICAL | 0 → 0 | yes |
| 9 | 999983/28800/60 | **DIVERGED** (t=3780 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 10 | 2024/28800/120 | **DIVERGED** (t=2280 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 11 | 999983/4320/60 | **DIVERGED** (t=3780 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |
| 12 | 12345/28800/60 | **DIVERGED** (t=3900 `ball.x`) | **IDENTICAL** | 1 → 0 | yes |

* 8 DIVERGED → IDENTICAL. 4 IDENTICAL → IDENTICAL. **0 remaining divergences.**
* Acceptance criterion ("every DIVERGED scenario becomes IDENTICAL, the 4 previously
  IDENTICAL stay IDENTICAL") is met, including the two 28 800-tick scenarios (4 minutes
  of match time each) and the 14 400-tick scenarios.
* The 4 previously-IDENTICAL scenarios are unchanged *bit for bit*, not merely still
  passing: their `sha256` over the tick body is identical to the before-run
  (`12345/1440/60` = `a7136682…`, `12345/1440/120` = `775ced90…`, `999/1440/60` =
  `3ee635b3…`, `2024/720/7` = `4d588245…`, matching the `digest_js` values recorded in
  `coverage-matrix.jsonl`). That is the check that the fix is additive, not a
  re-tune.

Evidence files:

| path | bytes |
|---|---|
| `docs/wayfinder/evidence/parity-divergence-2207.md` | this file |
| `tools/sim-port/compare-digests.py` (new) | 2 321 |
| `tools/sim-port/run-parity-matrix.sh` (new) | 3 686 |
| `tools/sim-port/out/coverage-matrix.jsonl` (before, untouched) | 7 009 |
| `tools/sim-port/out/coverage-matrix-after.jsonl` (after) | 6 613 |
| `tools/sim-port/out/probe-logs/` — 4 raw instrumentation captures | 16 675 |
| `tools/sim-port/probe/` — instrumented JS copy + README (diagnostic only) | — |
| `godot/src/sim/sim.gd` (fixed) | 141 741 |

## 5. What this does not prove

* **Only the quickly-reachable parts of the match are exercised.** `serveAttempts` is `0`
  in every scenario (`js/game.js:2121-2122` only ever sets it to 1 on the second serve),
  so no fault, no second serve and no double fault was traversed; the score sits at
  `0-3 / 40` at the first divergence in every scenario, so games, set points and
  tie-breaks are **unexercised**. The probe covers one long opening rally, not a match.
* **No physics/collision invariance is established.** A single scalar (`movementPenalty`)
  was wrong in one branch. That the remaining 28 800-tick streams now agree bit-for-bit is
  strong evidence but not a proof: a divergence whose first symptom falls outside the
  digit resolution of the digest, or in a field the digest does not print (`motion`,
  `runPhase`, `charge`, `swing`, event lines, RNG-free branches reached only in games /
  tie-breaks), would be invisible here.
* **The fix is a semantic-equivalence argument, not a reading of the reference at
  runtime.** It relies on `moveRatio` always being a number in `js/game.js` (checked at
  the declaration `js/game.js:54`, the reset `js/game.js:400`, and all 8 sites that
  assign `paddle.moveRatio = …`). If a paddle object could ever be constructed without
  `moveRatio`, `js/game.js` would fall back to `motion` and the port would now not — but
  no such construction exists in the current reference.
* **Sample grids can still hide divergence.** Scenarios 4-12 are sampled every 60 or 120
  ticks. Only seeds 2024 (`every=1`, 2215 ticks) and 7 (`every=1`, 4500 ticks) were
  verified at the fine grid; the other 10 were not. A divergence that appears and is
  *reabsorbed* between two samples would not be caught.
* **The earliest divergence across all seeds at `--every=1` was not established.** Only
  seed 2024 (2207) and seed 7 were pinned at the fine grid; 2207 is the earliest *probed*,
  not proven to be the earliest. It is however a single shared root cause, so the anchor
  is not per-seed.
* **A note on `gd_exit`.** The first re-run of the matrix produced
  `/tmp/matrix.log` with all 12 rows `MALFORMED: one of the streams has no tick lines`:
  that run passed `--quiet` to `scripts/parity-digest.mjs`, which suppresses the digest
  lines on stdout (the flag only writes the JSON). It was discarded and the matrix re-run
  without `--quiet`; the discarded log is quoted here so the failed attempt is on the
  record rather than silently dropped. Separately, the Godot harness's own comparator
  reads the default stored reference `tools/parity/parity-digest-seed12345.json` when
  `--js=` is not supplied, which is why `gd_exit` is 1 even for IDENTICAL rows in such
  runs; all verdicts in the table above come from `compare-digests.py` (stream vs stream)
  and were corroborated by `parity_digest_gd.gd`'s own comparator once the matching
  `--js=` reference was supplied.
* **Untracked side effects of other workstreams.** `docs/mission/STATE.md`,
  `docs/mission/LOG.md` and `tools/character/out/tri-count.json` were also modified on
  disk during this window by other sessions; this task did not write to them. Nothing
  under `js/**` or `scripts/**` was modified (verified by mtime).
