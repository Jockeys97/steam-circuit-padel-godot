# Parity coverage frontier — why faults are unexercised, what the runaway tail is, and the scenario spec that would cover them

- **Date:** 2026-09-16T08:36:30+02:00 (CEST)
- **Repo:** `/root/projects/steam-circuit-padel-pro` @ working tree
- **Mode of this lane:** **read-only analysis.** Godot was **not launched at all** (the single heavy
  engine slot is held by another lane). One `node` process at a time, never two.
- **Authorities read:** `js/game.js` (sha256 `c19277add6a035f7da6c2db4b162b1cd9d58d26e1fa97cd6c81f6f99e69455c9`),
  `js/data.js` (`c63c496cd967663a5ec9f708e77b6f6948e4b523ba5b0e4280a40af642ec6403`),
  `scripts/parity-digest.mjs` (**frozen, unmodified**, `2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd`),
  `js/main.js` (read-only).
- **Prior evidence, not re-derived:** `docs/wayfinder/evidence/parity-coverage.md`
  (`1761c55c0bffb39ee90defb50b9a85f6c632fb00e531f93bb4b09ffbd829e8e6`), 12-scenario matrix, all rows
  `IDENTICAL` after the `godot/src/sim/sim.gd:1114`/`:1011` fix.
- **Machine-readable companion:** `tools/sim-port/out/fault-scenarios.json` (16319 bytes; the
  hash is not quoted here to avoid a self-referential edit — recompute with `sha256sum`).

**Nothing in `js/**`, `scripts/**`, `godot/**`, `docs/mission/**`, `docs/wayfinder/map.md`,
`docs/wayfinder/tickets/**` or any tracked file was modified. No git command that writes was run.
No npm install, no paid spend.**

New files written (both inside the allowlisted tree):
`tools/sim-port/analyze-frontier.py`, `tools/sim-port/frontier-probe.mjs`, plus the two deliverables.

---

## 0. Headline

| question | answer in one line |
|---|---|
| Why has `serveAttempts` never been non-zero? | The frozen input script strikes **every** serve within the first 41 charging frames (charge ≤ **0.3254**), while a serve fault needs charge ≥ **0.90**; the server (`ATHLETES[0]`, control 1.28) also pins the dispersion factor at its floor. The AI's serve charge is fixed at 0.62 and is **structurally incapable** of faulting. |
| What is the "runaway tail"? | It starts on the **exact tick the match-ending point sets `state.result`**. `pointPause` is only armed when `!state.result` (`js/game.js:2108`) and `prepareServe` only runs when `!state.result` (`js/game.js:3006`), so the ball is never reset; `handleGroundBounce` returns **before** the `ball.z` clamp (`js/game.js:2179` vs `:2205`) and scores **one point per tick**, so `ball.z` free-falls (`-0.5·720·dt²` per tick) while `sets` climbs to 0-296. The **real game loop stops at that tick** (`js/main.js:1204`, `js/main.js:1243-1246`) — it is a **harness artefact**, not a reachable game behaviour. |
| Can the frozen harness reach a fault / second serve / game / set? | Fault: **no**. Second serve: **no**. Completed game (`games=0-1`): **yes**, already on disk. Completed set (`sets=0-1`): **yes, but only as the match-ending set**, one sampled tick before the runaway. A 3-line change to a **new** runner (serve at full charge; `setsToWin=3`) reaches fault at **tick 250**, second serve at **253**, and a clean completed set at **~tick 22209** with the match still healthy. |

---

## 1. Empirics: `serveAttempts` is 0 everywhere, including at `every=1`

`tools/sim-port/analyze-frontier.py` (new, read-only) parses every `js-*` / `after-js-*` / `fine-*` /
`before-js-*` digest stream in `tools/sim-port/out/` (31 files) and reports the distinct values of `serveAttempts`:

```
python3 tools/sim-port/analyze-frontier.py            # exit 0, 31 JSON rows
grep -o "serveAttempts=[0-9]*" js-*.txt gd-*.txt after-js-*.txt after-gd-*.txt | sort -u
```

**Result: `serveAttempts=0` on every line of every file** — 22 JS/Godot streams plus the `every=1`
fine probe (`fine-2024-2285-1-js.txt`, 2286 consecutive ticks). There is no sampling artefact to
hide behind: at `every=1` a 325-tick `serveAttempts=1` window (below) cannot be missed, and nothing
is seen. VERIFIED.

---

## 2. Question 1 — *why* the fault paths are dead, with line anchors

### 2.1 The two fault paths and what they require

A serve can only fail in two places:

| path | code | trigger |
|---|---|---|
| out of the diagonal box | `js/game.js:2161-2165` → `serveFault(state, t("serveOutBox"))` | the **first bounce** fails `validServiceBounce` (`js/game.js:2139-2148`) |
| glass before the bounce | `js/game.js:2221-2225` → `serveFault(state, t("serveWallFault"))` | a wall/back-wall hit while `ball.serveInFlight && !hasBounced` |

`validServiceBounce` requires the first bounce to be **inside the receiver's diagonal half and
between the net and the service line**: the box is `SERVICE_LINE_OFFSET = 126` px deep
(`js/game.js:30-32`, `netY=310`, `SERVICE_TOP=184`, `SERVICE_BOTTOM=436`, court `80..880 × 56..564`,
`js/data.js:1-8`). So a "long fault" needs the first bounce **> 126 px past the net**.

### 2.2 What the serve can possibly aim at

`performServe` (`js/game.js:715-778`) aims at

```
serviceBoxDepth = 126 * (0.24 + 0.52*charge) + (nextRandom - 0.5) * 2 * spread * 1.15      (:734, :732)
spread          = 60 * (0.42 + 0.58*charge^2) * clamp(1.62 - serverControl, 0.3, 1.0) * (2nd ? 0.70 : 1)   (:728-731)
```

The athlete the harness fixes is `ATHLETES[0]` = **maestro, `control: 1.28`** (`js/data.js:341`,
`scripts/parity-digest.mjs:235`), so the control factor is pinned at its **floor 0.34**
(`1.62 − 1.28 = 0.34`). At charge 1.0 that gives `spread = 20.4` px and

```
max aim depth = 126·0.76 + 1.15·20.4 = 95.76 + 23.46 = 119.2 px          (< 126)
```

i.e. **even a perfect full-charge serve aims short of the service line**, and the extra launch term
`+18 + (1−charge)·18` (`js/game.js:754`) buys only a few px of overshoot. The measured numbers
(§2.4) confirm the real threshold.

### 2.3 What the frozen harness actually does at the serve

The frozen script (`scripts/parity-digest.mjs:89-98`) sets `charging: true` from tick 60 and
`hit: tick % 30 === 0`. Tick 60 is both the **first** charging tick and a **hit** tick, and the
strike reads `state.shotCharge` (`js/game.js:2625`) which was zeroed at the previous strike
(`js/game.js:2626`). Charge accrues at `dt / 1.05` per tick (`js/game.js:2686`), so:

| serve | charge at the strike | = charging frames |
|---|---|---|
| tick 60 (first serve) | **0.0079365** | 1 frame |
| later serves | **0.0873** or **0.3254** | 11 or 41 frames |

Measured over **63 player serves** in 4 seeds × 28800 ticks (`--mode=frozen`):
`min 0.0079365`, `max 0.3253968`, values quantised to `k · 1/120/1.05 ∈ {1, 11, 41}`. The 41-frame
ceiling is set by the **point-pause phase** (`pointPause = 1.4 s`, `js/game.js:2109`): the serve can
only be struck on the `tick % 30` grid after the pause, and `shotCharge` is suspended during the
pause (`js/game.js:2999-3009` returns before `updateShotControl`). VERIFIED.

At charge 0.3254 the aim depth is only
`126·0.409 + 1.15·(60·0.4814·0.34) = 51.5 + 11.3 = 62.8 px` — a **58 px margin** inside the
126 px service line. So no RNG draw can fault it.

### 2.4 The decisive experiment: where does a fault actually become possible?

`tools/sim-port/frontier-probe.mjs --mode=serve-sweep` calls the **exported** `performServe(state, q)`
directly and steps the sim to the first ground bounce, for 60 seeds at each charge (this measures the
*real* landing, including the `+18 + (1−charge)·18` launch offset):

| charge | serves | faults | fault rate | max valid landing depth |
|---:|---:|---:|---:|---:|
| 0.00 … 0.85 | 60 each | **0** | 0.000 | 118.62 (at 0.85) |
| 0.90 | 60 | 6 | 0.100 | 119.26 |
| 0.95 | 60 | 8 | 0.133 | 119.99 |
| 1.00 | 60 | 14 | **0.233** | 120.04 |

**The fault threshold is charge ≈ 0.90 — 2.8× the maximum the frozen harness can produce.**

### 2.5 The AI serve cannot fault at all (structural)

`performServe(state)` for the AI uses the default `charge = 0.62` (`js/game.js:719`), so
`spread ≤ 60·(0.42 + 0.58·0.62²)·1.0 = 38.6` and

```
max aim depth = 126·(0.24 + 0.52·0.62) + 1.15·38.6 = 70.86 + 44.36 = 115.2 px    (< 126)
```

regardless of the AI's skill (the `clamp(..., 0.3, 1.0)` factor tops out at 1.0). Consistent with
**0 faults in 103 observed AI serves** (55 frozen-script + 48 full-charge; the deepest AI serve
observed aimed 98.95 px past the net, under the 115.2 px worst-case bound). VERIFIED (arithmetic + observation). Consequence: *all*
faults and second serves must come from the **player's** serve, at high charge.

### 2.6 Answer to question 1

It is **both**, with the harness configuration binding:

1. **Frozen-harness configuration (binding).** The serve trigger is on the `tick % 30` grid while
   charging starts at tick 60, so the charge at the strike is a function of the pause phase and tops
   out at **0.3254** — a factor 2.8 below the 0.90 threshold. This is a property of
   `scripts/parity-digest.mjs:87-98` + `js/game.js:2625-2626`, **not** of the match state or of the
   Godot port.
2. **Reference-loop design (contributing).** Spread is quadratic in charge while the box is a fixed
   126 px deep, and the harness's athlete has `control = 1.28`, which pins the dispersion factor at
   its 0.34 floor. So even at full charge the first serve aims ~7 px short of the line and only a
   ~23 % tail of the depth distribution faults.

Both statements are about the **scenario configuration**, not about a defect: the reference can
fault (measured, §3.3), the harness just never asks it to.

> **Risk this exposes for the parity claim.** `js/game.js:727` (`const secondServe = state.serveAttempts > 0`)
> and the whole `state.serveAttempts` branch — including `js/game.js:2120-2130` — are **unexercised on
> both engines**. The parity matrix's 12 IDENTICAL scenarios therefore prove *nothing* about this
> branch, and the one real port bug found so far (`sim.gd:1114`, a mistranslated *nullish-coalescing
> fallback*) lived in exactly this kind of guard expression. That is the coverage frontier, stated
> plainly.

---

## 3. Question 2 — the "runaway tail": what it is, where it starts, whether it is real

### 3.1 Where it starts, per seed already on disk

`analyze-frontier.py` over the existing streams (first sampled tick with `ball.z < -1000`), plus the
exact onset from the tick-by-tick probe:

| seed / config | first sampled `ball.z < -1000` | last healthy sample | exact `state.result` tick (probe) | first `ball.z < -1` | `ball.z` at end |
|---|---:|---|---:|---:|---:|
| 12345 / 28800 / 60 | tick 23220 | 22860 | **22209** | 22210 | −838 448 (stream) |
| 2024 / 28800 / 120 | tick 21960 | 21720 (pts 0-3, games 0-5) | **21720** | 21720 | −1 268 097 |
| 999 / 28800 / 120 | tick 24960 | 24720 (pts 1-3, games 0-5) | **24768** | 24768 | −415 324 |
| 999983 / 28800 / 60 | tick 18420 | 18180 (pts 0-3, games 0-5) | **18204** | 18206 | −2 812 962 |

(Seeds 7 and 999983/4320 and every 1440/4320-tick scenario never leave the healthy regime; the long
runs that do are exactly the four above.)

**It coincides with the point that finishes the match** — and with nothing else. Before it, the long
runs sit **stuck at `games=0-5`** for thousands of ticks (seed 12345: 0-5 at tick 15240 → result at
22209, i.e. ~58 s of match time to play one game); the `sets` counter first moves on the **same
sample interval** as the runaway (`sets: 0-0 → 0-1` at tick 22260 for seed 12345, and at
22260/21840/24840/18240 for the other three).

### 3.2 The mechanism, tick by tick (VERIFIED)

`--mode=tail-dump --seed=12345` prints the first post-result ticks:

```
tick  22209  z=-0.065  y=437.00  bounces=2/0  pause=0.0000  pts=0-0  games=0-0  sets=0-1 *
tick  22210  z=-2.617  y=435.58  bounces=3/0  pause=0.0000  pts=0-1  games=0-0  sets=0-1
tick  22211  z=-5.219  y=434.16  bounces=4/0  pause=0.0000  pts=0-2  games=0-0  sets=0-1
...
tick  22213  z=-10.573 y=431.31  bounces=6/0  pause=0.0000  pts=0-0  games=0-1  sets=0-1
```

Three code facts produce it, all in `js/game.js`:

1. **`js/game.js:2108-2109`** — `scorePoint` arms `state.pointPause = 1.4` only `if (!state.result)`.
   On the match-winning point the pause is **not** armed.
2. **`js/game.js:2999-3008`** — the pause branch is the **only** place that calls `prepareServe`
   after a point, and it does so only `if (state.pointPause === 0 && !state.result)`. So after the
   match ends, **the ball is never reset** and `state.serving` never returns.
3. **`js/game.js:2173-2183` vs `:2205`** — `handleGroundBounce`'s second-bounce branch calls
   `scorePoint(...)` and `return true` **before** the `ball.z = Math.max(0, ...)` clamp. Because
   `bounces[side]` is never reset (that happens in `prepareServe`, `js/game.js:762`), *every*
   subsequent tick re-enters the branch with `bounces > 1`, scores a point, and returns — leaving
   `ball.z` to integrate unchanged: `z_n ≈ -0.5 · 720 · (n/120)²`.

The measured consequence matches that closed form exactly: seed 999 ends at `ball.z ≈ −4.15e5`,
i.e. `0.025·n²` with `n ≈ 4075` post-result ticks, and the counts run at **one point per tick**
(4 points/game, 6 games/set ⇒ **24 ticks per set**): `sets = 0-296` for seed 12345, `0-442` for
999983, `0-169` for 999. Any `sets`/`games` magnitude in the tail is meaningless.

### 3.3 Is it a harness artefact or real behaviour?

**Harness artefact, precisely:** it is the deterministic simulation of a game state the real game
never simulates. The real loop stops the moment a point returns a result:

- `js/main.js:1204` — `if (result) break;` (inner fixed-step loop);
- `js/main.js:1243-1246` — `if (result) { endMatch(result.winner); return; }` (frame loop ends, no
  further `updateMatch`).

The frozen harness has no such guard (`scripts/parity-digest.mjs:252-264` loops `ticks` times
regardless), and this is documented in its own header as a deliberate per-tick harness contract.

It is **not** an artefact of illegal parameters: `FIXED_STEP = 1/120` and `MAX_SIM_STEPS = 8`
(`js/main.js:1164-1165`) are the real game's, one `updateMatch` per fixed step is what
`js/main.js:1197-1209` does, and `createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1])`
is a legal quick match. The one configuration the harness does not use is the one the game uses to
*end* the match: `state.result`.

So the honest statement is: **the tail is unreachable in the shipped game (the loop cannot get
there), and any digest line after the result tick is not comparable as gameplay.** The prior
evidence document's sentence — "That is a property of the frozen JS harness, not of the port" — is
confirmed, and can now be stated mechanistically rather than by observation.

**Corollary that matters for the parity work:** the tail is *identical in kind* on both engines
because both are stepping the same broken-out-of-band state; matching there proves nothing about
serve/point/game logic. The 12-scenario matrix's useful window is exactly the pre-result window.

---

## 4. Question 3 — the scenario spec that would reach a fault, a second serve, a game and a set

Full machine-readable spec: **`tools/sim-port/out/fault-scenarios.json`**. Summary:

| id | target | frozen harness? | recipe | observable in the digest line | budget |
|---|---|---|---|---|---|
| **A1** | first serve fault | **NO** — charge cap 0.3254 vs threshold 0.90 | new runner: `charging:true`, `hit:(state.serving && state.shotCharge>=0.999)`, seed 999, every 60 | `serveAttempts=1` at tick **250** (window 250–575) | 600 ticks |
| **A2** | second serve | **NO** (needs A1) | same run, no extra code | `serveAttempts=1` persists; second serve struck at **253**, lands in the box at **377**, point lost at 576 | 600 ticks (shared) |
| **A3** | double fault | **NO** (needs A1/A2) | A1 run extended + print `state.stats.doubleFaults` (`js/game.js:308`) | `serveAttempts 1→0` + `points` to the receiver, `bounces=0/0` at the reset tick | 4000 ticks (INFERRED) |
| **C** | completed game | **YES** | frozen as-is: `--seed=12345 --ticks=4320 --every=60` | `games=0-1` (first sampled 4140; cheaper: seed 2024 @2520, seed 7 @2880, seed 999983 @3180) | 4320 ticks |
| **D1** | completed set | **YES, but degenerate** | frozen as-is: `--seed=12345 --ticks=22260 --every=60` | `sets=0-1` on the sample at tick 22260 — one sample before the runaway begins | 22260 ticks |
| **D2** | completed set, match stays healthy | **NO** — needs `setsToWin>1` | new runner: `state.setsToWin = 3` after `createMatchState` | `sets=0-1` at ~22260 **and** the run continues sanely (games reset, `ball.z=8.71` at 28800, no runaway) | 28800 ticks |

VERIFIED for A1/A2 (probe run, fixed): seed 999 **and** seed 12345 both fault at **tick 250**, the
fault event recorded is `"Serve out of the diagonal box. Second serve."` (`serveOutBox`,
`js/game.js:2163`; **not** the glass path), `serveAttempts` goes 0→1 at 250 and back to 0 at 576/575
after the second serve's point.

### What a **new** file under `tools/sim-port/**` must do (do not touch the frozen harness)

1. **One new runner** (e.g. `tools/sim-port/fault-digest.mjs`). `scripts/parity-digest.mjs` stays
   frozen and byte-identical.
2. **Serve trigger:** `charging: true` every tick; `hit: (state.serving && state.shotCharge >= 0.999)`.
   Deterministic (a pure function of the simulated state), and it is the *only* change needed to
   reach a first-serve fault and a second serve. **Do not** key the strike off `tick % N`: that is
   what puts the charge at the mercy of the pause phase.
3. **Format:** set `state.setsToWin = 3` right after `createMatchState`, so a completed set does not
   end the match and the run stays in the healthy regime (VERIFIED: no result, no runaway, 28 800
   ticks, 41 serves, set 1 closed 0-6 at ~22209, match continues).
4. **Stop at the result** (or cap the budget before the result tick). Otherwise the digest tail is
   free-fall noise (`ball.z → −1e6`, one point per tick) that must never be compared across engines
   as if it were gameplay.
5. **Optional:** add `state.stats.doubleFaults` to the digest line — `serveAttempts` alone cannot
   distinguish a double fault from an ordinary lost point.
6. Reuse the existing comparator (`tools/parity/parity-compare.mjs`) unchanged; the digest line shape
   is the same, so a fault scenario compares exactly like the 12 existing ones.

---

## 5. Commands run (exact, with exit codes)

```bash
cd /root/projects/steam-circuit-padel-pro

# stream parsing over the 31 existing JS/Godot digest streams (read-only artefact analysis)
python3 tools/sim-port/analyze-frontier.py                                   # exit 0, 31 rows
grep -o "serveAttempts=[0-9]*" js-*.txt gd-*.txt after-js-*.txt after-gd-*.txt | sort -u   # exit 0

# fault-threshold sweep: 21 charges x 60 seeds, direct performServe + first bounce
timeout 180 node tools/sim-port/frontier-probe.mjs --mode=serve-sweep --seeds=60 --athlete=0   # exit 0

# frozen-script replay, 4 seeds x 28800 ticks: serve charge, aim depth, faults, result tick
for s in 2024 999 999983 12345; do
  timeout 200 node tools/sim-port/frontier-probe.mjs --mode=frozen --seed=$s --ticks=28800 | ... ; done   # exit 0

# tick-by-tick tail trace (24 ticks after state.result)
timeout 200 node tools/sim-port/frontier-probe.mjs --mode=tail-dump --seed=12345 --ticks=22240   # exit 0

# full-charge serve recipe: first fault + second serve
timeout 200 node tools/sim-port/frontier-probe.mjs --mode=fullcharge --seed=999   --ticks=700     # exit 0
timeout 200 node tools/sim-port/frontier-probe.mjs --mode=fullcharge --seed=12345 --ticks=700     # exit 0
# (the 28800-tick full-charge runs for seeds 2024 and 7 reported 0 faults in 13 player serves each)

# clean completed set: frozen script + setsToWin override
timeout 200 node tools/sim-port/frontier-probe.mjs --mode=frozen --seed=12345 --ticks=28800 --sets=3   # exit 0
```

No Godot invocation of any kind. `free -m` was checked before and after; available memory moved
between 850 MB and 605 MB (host: 3910 MB, 0 swap) — every run was sequential and bounded, no OOM.

---

## 6. VERIFIED vs INFERRED

**VERIFIED (ran it or read it in the code)**

- `serveAttempts=0` on every line of all 31 existing streams, including the 2286-tick `every=1` probe.
- Fault threshold ≈ charge 0.90 (0/60 at ≤0.85; 10 % at 0.90; 13.3 % at 0.95; 23.3 % at 1.00).
- Frozen harness's player serve charge ∈ {0.00794, 0.0873, 0.3254}, max 0.3254, over 63 serves.
- Full-charge serve script (new) ⇒ first-serve fault at **tick 250** for seeds 999 and 12345,
  reason `serveOutBox`; second serve at 253; second serve lands in the box at 377.
- Runaway onset == `state.result` tick (21720 / 24768 / 18204 / 22209), within 0–2 ticks;
  mechanism: `js/game.js:2108`, `:3005-3007`, `:2179-2181` vs `:2205`; rate 24 ticks/set,
  `ball.z ≈ -0.5·720·(n/120)²`.
- Real game never steps past the result: `js/main.js:1204`, `js/main.js:1243-1246`.
- `setsToWin=3` override ⇒ clean completed set with the match still healthy at 28800 ticks.
- Completed game (`games=0-1`) reachable at 2520–4140 ticks in four existing scenarios.

**INFERRED (not measured here)**

- Double-fault rate (A3): the second serve lands only 6–8 px inside the 184 service line with a
  ±16.5 px depth error (`serveSecondSafety 0.70`), so a second-serve fault is the same order as the
  first-serve rate. Not measured.
- That the 41-frame charge ceiling (0.3254) holds for every seed. Structurally it is the `tick % 30`
  grid against the 1.4 s pause; only 4 seeds × 28800 ticks were measured.
- Any statement about the Godot port's behaviour on these scenarios: **none was run.**

**Still unknown**

- Whether the port reproduces a fault, a second serve, a completed game/set — i.e. the whole
  `serveAttempts` branch is unverified on both engines (see the risk note in §2.6).
- The true double-fault probability and the cheapest seed for it.
- Whether other athletes/seeds push the charge above 41 frames in the frozen harness.
- Whether the Godot port has an equivalent `state.result` guard: whether its harness also steps past
  the result, and whether its post-result state matches the JS tail, is untested (godot/** was not
  read or executed in this lane).

---

## 7. What this proves / does not prove

**Proves**

- The absence of faults in the parity matrix is fully explained by the **serve-charge configuration**
  of the frozen script (cap 0.3254) against a **measured** fault threshold of charge 0.90 — not by
  chance, sampling, or the port.
- The runaway tail begins exactly at the match-ending point, its mechanism is pinned to three
  `js/game.js` lines, and the shipped game loop cannot reach it (`js/main.js:1204`, `:1243-1246`).
- A fault, a second serve and a clean completed set are all reachable **deterministically** with one
  new file and no change to the frozen harness.

**Does not prove**

- Anything about the port (§6). No Godot process was started; the engine slot belongs to another lane.
- That a fault scenario *passes* parity — only that it is constructible and what it must print.
- Any `sets`/`games` magnitude observed after the result tick; those numbers are free-fall artefacts.
