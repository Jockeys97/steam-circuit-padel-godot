# Sim core parity (slice S1)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: none technically. Acceptance is blocked by [Parity gate definition](../../wayfinder/tickets/parity-gate-definition.md) (open, owner Luca). The build may start and the digest harness may be written now; the slice may not be called done until the gate definition lands.

This ticket implements row S1 of `docs/implementation/PLAN.md` ("Deterministic simulation parity core"). It does not change that plan, its slice numbering or its open-decision table.

## Objective

Port the pure simulation inside `js/game.js` (the module minus its four couplings) plus the `clamp` helper it imports, into headless GDScript under `godot/src/sim/`, driven by an explicitly injected integer seed and a fixed `1/120` s tick, and prove with a cross-engine digest that both engines produce the same `rngState`, `rngCalls`, counters, score fields and ordered point outcomes for the same seed and the same per-tick input script. Parity is measured against the web build frozen at git commit `2979588`. Nothing is rendered, no scene is entered and no audio is played by this slice; it is the seam every later slice runs through, so it is built first and gated on the discrete state rather than on floating point positions.

## Existing source anchors

Every anchor below is a real file and line in this repository. The ones marked `verified` were re-read while writing this ticket; the ones marked `from the boundary ticket` are the anchors resolved in `docs/wayfinder/tickets/simulation-port-boundary.md` and were not re-read line by line here.

Simulation module and its four couplings:

| Anchor | What it is | Status |
|---|---|---|
| `js/game.js:1-13` | The import block. `BALANCE, COURT, EVENT_LINES, ROSTER_AVERAGE` from `data.js`, `clamp` from `render.js:2`, `sfx` from `audio.js:3`, `t` from `i18n.js:4`, and `fx.js` names at `6-13` | verified |
| `js/game.js:2` | `import { clamp } from "./render.js..."`, the only sim to render dependency; the helper is `js/render.js:4-6`, three lines of arithmetic | verified |
| `js/game.js:3` | `import { sfx }`, audio coupling. 9 call sites: `750, 1893, 1898, 2111, 2113, 2115, 2209, 2363, 2382` | import verified, call sites from the boundary ticket |
| `js/game.js:4` | `import { t }`, string coupling, 187 call sites. Sim must store message ids, not text | import verified, count from the boundary ticket |
| `js/game.js:6-13` | `emitBurst, emitDust, emitSparks, emitSteam, isReduceMotion, resetFx, updateFx`, the fx coupling | verified |
| `js/game.js:1058` | `if (assessment.grade === "perfect" && !isReduceMotion())`, the reduced-motion branch inside sim code | verified |
| `js/game.js:2988` | `updateFx(state, dt)`, fx advanced from inside the step | verified |
| `js/game.js:1973` | `state.fx.shake = Math.max(state.fx.shake ?? 0, 1.1)`, sim writing a view field on a special | verified |
| `js/game.js:750-751` | `sfx.serve(); emitSteam(state, ball.x, ball.y, ball.z);`, both couplings firing on the serve | verified |
| `js/game.js:1893, 1898` | `sfx.hit();` and `sfx.special();`, the hit and special sounds | verified |

RNG contract:

| Anchor | What it is | Status |
|---|---|---|
| `js/game.js:22-28` | `nextRandom(state)`, mulberry32-style 32-bit generator, the exact algorithm to reproduce including the `i32` masks | verified |
| `js/game.js:218` | `rngState: (Math.random() * 0xffffffff) \| 0`, the single seed line. The only `Math.random` the port replaces | verified |
| `js/game.js:184-186` | `createMatchState(mode, athlete, arena, aiProfile, tournamentRound = 0, options = {})`, where `options` reads only `humanMode` and `lineup`, so there is no seed parameter today | verified |
| `js/game.js:30-33` | `SERVICE_LINE_OFFSET = 126`, `SERVICE_TOP`, `SERVICE_BOTTOM`, `POINTS = ["0","15","30","40"]` | verified |
| `js/game.js:2231-2233` | The wall-handling defender choice, the one place the JS engine sorts instead of comparing in insertion order. V8 sort is stable, `sort_custom` is not | anchor verified, semantics from the boundary ticket |
| `js/game.js:2272, 2284` | `ball.vx *= -state.arena.wallBounce * 0.72;` and `ball.vx *= -state.arena.wallBounce;`, where arena `wallBounce` enters the sim | verified |
| 32 `nextRandom` call sites in `js/game.js` | `602, 633, 732, 733, 1188, 1206, 1214, 1220, 1242, 1275, 1294, 1300, 1303, 1362, 1390, 1398, 1404, 1409, 1414, 1441, 1442, 1599, 1603, 1640, 1698, 1700, 1859, 1919, 2265, 2302, 2344, 2441`. Order is a literal in-line sequence and is part of the contract | from the boundary ticket |

Tick contract:

| Anchor | What it is | Status |
|---|---|---|
| `js/main.js:1164` | `const FIXED_STEP = 1 / 120;`. The tick lives in the frame loop, not in `game.js` | verified |
| `js/main.js:1165` | `const MAX_SIM_STEPS = 8;` | verified |
| `js/main.js:1196` | `min(acc + dt, FIXED_STEP * MAX_SIM_STEPS)`, the match accumulator clamp | from the boundary ticket |
| `js/main.js:1200-1202` | `while (acc >= FIXED_STEP && steps < MAX_SIM_STEPS)` calling `updateMatch(state, FIXED_STEP, ...)` | from the boundary ticket |
| `js/main.js:2105-2120` | The drill loop, same two constants, no accumulator clamp | from the boundary ticket |
| `js/game.js:3012-3015` | `if (state.hitStop > 0) { ... dt *= BALANCE.hitStopTimeScale; }`, so the step's effective `dt` is state dependent | verified |
| `js/game.js:2973` | `export function updateMatch(state, dt, input, input2 = null)`, the single tick entry point | verified |
| `js/game.js:2712-2734` | `EMPTY_INPUT`, the 22-field input struct the per-tick script must match | verified |
| `js/game.js:866` | `function playableEta(state, paddle)`, in-sim landing prediction, distinct from the renderer's `predictLanding` | verified |

Region map inside `js/game.js` (from the boundary ticket section 2; the pre-fix block is the pure sim, and `js/game.js` is 3359 lines, verified):

| Region | Lines | Target module |
|---|---|---|
| RNG | `22-28` | `SimRng.gd` |
| Court constants | `30-33` | `SimCourt.gd` |
| Entity builders | `35-153` | `SimTypes.gd` |
| State builder | `184-326` | `SimMatch.gd` |
| Events and replay | `328-365` | `SimMatch.gd` |
| Serve | `367-459`, `669-779` | `SimServe.gd` |
| Contact and quality | `479-1060` | `SimShot.gd` |
| AI | `1078-1467`, `2431-2603` | `SimAi.gd` |
| Hit resolution | `1468-1922` | `SimShot.gd` |
| Specials | `1923-1991` | `SimShot.gd` |
| Scoring | `1992-2213` | `SimScore.gd` |
| Bounce, walls, net | `2150-2415` | `SimPhysics.gd` |
| Paddle motion | `2416-2542`, `2737-2972` | `SimMovement.gd` |
| Step | `2973-3359` | `SimMatch.step(dt, input, input2)` |

Data anchors (all verified present at the cited line):

| Anchor | What it is |
|---|---|
| `js/data.js:1-8` | `COURT` = `{ left 80, right 880, top 56, bottom 564, netY 310, netHeight 38 }` |
| `js/data.js:10` | `export const WIN_SCORE = 11;` |
| `js/data.js:20` | `export const VERSION = { build: "alpha-0.2", balance: "b7" };` |
| `js/data.js:81-323` | `BALANCE`, 163 keys |
| `js/data.js:324` | `export const ATHLETES = [` |
| `js/data.js:484` | `export const ROSTER_AVERAGE = (() => {` |
| `js/data.js:560` | `export const ARENAS = [` |
| `js/data.js:662` | `export const MATCH_FORMATS = {` |
| `js/data.js:673` | `export const AI_OPPONENTS = [` |
| `js/data.js:686` | `export const EVENT_LINES = [` |
| `js/render.js:4-6` | `clamp(value, min, max)` |
| `js/fx.js:29-41` | Particle emission on global `Math.random`, a stream separate from `state.rngState` |

Frozen input for this slice, from `docs/wayfinder/tickets/simulation-port-boundary.md` and `PLAN.md`: `COURT`, the 163 `BALANCE` values, `SERVICE_LINE_OFFSET = 126`, `WIN_SCORE`, `MATCH_FORMATS`, the `stats` block of every athlete, `AI_OPPONENTS` `skill`/`speed`/`power`, and every arena's `wallBounce`. Changing any of them is re-tuning, needs Luca's approval and a `VERSION.balance` bump (`js/data.js:20`). The port carries them verbatim, including the nine `BALANCE` keys that nothing reads today (`gravity`, `serviceBounceTime`, `baseHitLift`, `baseHitAngle`, `spinInfluence`, `serveVy`, `serveVx`, `outMargin`, `sprintSpeedBonus`), because dropping them loses numbers a future formula reads and inventing behaviour for them adds untested behaviour.

Court aspect is an open human question and is NOT resolved here: `COURT` is 800 x 508 px, an aspect of 1.575, while `GAMEPLAY_RULES.md:11` says 20 x 10 metri. The two disagree. Do not pick a scale in this slice; determinism is scale independent.

## File ownership / allowlist

New files this ticket creates (one writer at a time, one file at a time):

- `godot/src/sim/SimRng.gd` - the seeded 32-bit generator and the `i32` helpers
- `godot/src/sim/SimCourt.gd` - `COURT`, `SERVICE_LINE_OFFSET`, `WIN_SCORE`, `MATCH_FORMATS` as frozen constants
- `godot/src/sim/SimBalance.gd` - the 163 `BALANCE` values, generated from `js/data.js`, verbatim and unsorted
- `godot/src/sim/SimTypes.gd` - `createPaddle`, `createBall`, `courtSide`, `pointLabel` equivalents, and the `SimEvent` enum
- `godot/src/sim/SimMatch.gd` - `createMatchState` equivalent, event and replay buffer, `step(dt, input, input2)`
- `godot/src/sim/SimServe.gd`, `godot/src/sim/SimShot.gd`, `godot/src/sim/SimAi.gd`, `godot/src/sim/SimScore.gd`, `godot/src/sim/SimPhysics.gd`, `godot/src/sim/SimMovement.gd`
- `godot/src/data/athletes.gd`, `godot/src/data/arenas.gd`, `godot/src/data/ai_opponents.gd`, `godot/src/data/event_lines.gd`
- `godot/tests/determinism_audit.gd` and `godot/tests/determinism_audit.tscn` - the ported determinism audit, same promise, same name stem
- `godot/src/inputs/scripted_input.gd` - the Godot mirror of the scripted per-tick input sequence
- `godot/tests/parity_digest.gd` - the Godot side of the cross-engine digest
- `godot/tests/SimCoreTest.tscn` - the runner scene for the ported audits this slice covers
- `docs/implementation/evidence/s1-*` - the evidence files listed below

`godot/src/sim/` module granularity is a proposal from the boundary ticket section 2, not a parity requirement; splitting or merging those files does not change the contract, but the mapping from `js/game.js` regions to files must stay written down in `godot/src/sim/README.md`.

The Node side of the comparison already exists: `scripts/parity-digest.mjs` (12528 bytes, untracked, written by another lane on 2026-09-16). It drives `js/game.js` with an explicit integer seed and a fixed scripted per-tick input sequence, and its real flags are `--seed`, `--ticks`, `--every`, `--json`, `--quiet`. It deliberately does not end in `-audit.mjs` so `run-audits.mjs` does not pick it up, and it compares nothing. It is read-only from here: do not modify it, and do not add a `scripts/fixtures/` directory for it, because its input sequence is a pure function of the tick index inside the script, not a fixture file. The Godot side must mirror that function rather than invent a second input format. The boundary ticket proposed a `--input=scripts/fixtures/input-quick.json` fixture; the shipped script does not use one, and the shipped script is authoritative.

Must not be touched by this slice: `js/` (any file, including `game.js`, `data.js`, `main.js`), `scripts/` (any file, including the 27 audits and `run-audits.mjs`), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/project.godot` beyond adding the new test scenes to nothing, `godot/prototypes/`, and any `godot/src/sim/` file while another writer holds it. The web build at `2979588` is the reference and stays exactly as it is.

## Inputs and outputs

Match construction. The JS engine has no seed parameter, tests inject one by assignment after construction (`scripts/determinism-audit.mjs:24`, confirmed: `createMatchState("quick", ATHLETES[0], ARENAS[0], AI_OPPONENTS[1])` then `state.rngState = seed`). The GDScript constructor takes the seed explicitly:

```
SimMatch.new(seed: int, mode: String, athlete: Dictionary, arena: Dictionary, ai_profile: Dictionary, lineup = null) -> SimMatch
```

Inputs:

- `seed`, a 32-bit integer. The JS reference injects it at the same point in the lifecycle: after `createMatchState` returns, before `prepareServe` is called.
- `mode`, `"quick"` for this slice.
- `athlete`, `arena`, `ai_profile`, taken from the ported data scripts. `AI_OPPONENTS[1]` is the tier the determinism audit uses.
- `lineup`, null for solo. `options.humanMode` defaults to `"solo"`, matching `js/game.js:185`.

Tick:

- `TICK = 1.0 / 120.0`, a constant in `SimCourt.gd` or `SimMatch.gd`, cited to `js/main.js:1164`. The sim is handed this constant, never Godot's `delta`, so the accumulator model stays available for the drill.
- `step(dt: float, input: Dictionary, input2 = null) -> Array[SimEvent]`. `dt` is the tick constant except when `hitStop > 0`, in which case it is `hitStopTimeScale`-scaled exactly as at `js/game.js:3012-3015`.
- The input dictionary has the same 22 fields as `js/game.js:2712-2734`: `left, right, up, down, moveX, moveY, charging, hit, slice, shotVariant, special, switchPlayer, switchDirection, aim, aimY, analogAim, splitStep, sprint, technicalModifier, teamTactic, cutVolley`. One input object per tick, not per frame.
- One-shot fields (`hit`, `special`, `switchPlayer`, `switchDirection`, `smashUpgrade`, `cutVolley`, `teamTactic`) are cleared after the first sub-step of a frame, per `js/main.js:1169-1181, 1207-1209`. The sim core exposes `consumeOneShot()`, the caller decides when to call it.

- The input script: the same scripted per-tick input sequence the JS digest uses, mirrored in `godot/src/inputs/scripted_input.gd` as a pure function of the tick index. Neither side takes a fixture file or an `--input` flag. If the two scripts disagree on one tick field, the digests diverge and the gate catches it, which is the point.

State the digest reads, all of them deterministic functions of state:

- `rngState: int` (int32, signed), `rngCalls: int` (a test-only counter incremented inside `nextRandom`, mirrored in both engines)
- `ball: { x, y, z, vx, vy, vz, spin, shotType, smashStage }`
- `bounces`, `points`, `games`, `sets`, `playerScore`, `aiScore`, `serveAttempts`, `rallyHits`
- the four paddles' `{ x, y }`
- `shotType` and `smashStage` enums, and the ordered list of point outcomes

Outputs:

- `step()` returns an `Array[SimEvent]`. The event enum carries the presentation facts the sim currently emits inline: serve (`js/game.js:750`), steam burst (`751`), hit (`1893`), special (`1898`), point, victory, defeat (`2111`, `2113`, `2115`), bounce (`2209`), wall (`2363`), net (`2382`), the reduced-motion perfect grade (`1058`, emitted as a grade, the view decides) and the shake request (`1973`). The sim never allocates particles and never calls an audio API.
- Text is stored as message ids, never as localized strings. `state.events` and `pointMessage` stay out of every digest.
- `state.fx` is not advanced by the step. Particle streams use global `Math.random` in JS (`js/fx.js:29-41`) and stay separate from `state.rngState`; if particles ever consume the sim RNG, every digest moves.
- `SimMatch.snapshot() -> Dictionary` returns the digest fields above, ready to serialize. `SimMatch.digest_line() -> String` returns one stable line for log comparison.

Port rules that are not optional:

- Int32 wraparound: `i32(x) = ((x & 0xFFFFFFFF) ^ 0x80000000) - 0x80000000`, applied after every `+` that can leave the 32-bit range and after every multiply, because GDScript integers are 64 bit and there is no `Math.imul`.
- JS `>>` maps to GDScript `>>` on the sign-extended int; JS `>>>` maps to `(x & 0xFFFFFFFF) >> n`.
- The returned float is `uint32 / 2**32`, exactly representable in float64, so the RNG stream is bit comparable across engines and is the strongest parity signal available.
- No engine RNG inside the sim. `Math.random` becomes the injected seed, nothing else.
- Wall handling compares the two defenders explicitly and never sorts a two-element tie (`js/game.js:2231-2233`).

## Tests

The web audits that prove this slice, by real file name under `scripts/`:

- `scripts/determinism-audit.mjs` - the primary gate. It asserts frame-rate independence at 30/60/90/120/144 fps, seed reproducibility and seed sensitivity, and it reads the sim source to assert zero stray `Math.random` in `game.js`. The Godot equivalent must assert the same three properties.
- `scripts/court-speed-audit.mjs` - ball speed against chaser speed, a read of `BALANCE` and `COURT`. It proves the ported `BALANCE` and `COURT` values are live, not decorative.
- `scripts/wall-rules-audit.mjs` - the glass rules and the double bounce, the rules most at risk from a rewrite of bounce and wall handling.
- `scripts/match-format-audit.mjs` - scoring to advantage, `MATCH_FORMATS`, the outcome every other audit reads.
- `scripts/shot-quality-audit.mjs` - timing windows and the quality labels, the sim-side half of what a human calls feel.
- `scripts/shot-balance-audit.mjs` and `scripts/smash-input-audit.mjs` - the shot mix and the smash x2 / x3 conditions.
- `scripts/difficulty-audit.mjs`, `scripts/ai-attack-audit.mjs`, `scripts/lineup-audit.mjs`, `scripts/controller-tactics-audit.mjs` - the AI tiers and the lineup, which read `AI_OPPONENTS` and `ROSTER_AVERAGE`.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` - these two do not port literally. The replacement is that the Godot project loads headless with zero script errors and every scene and script in `godot/src/sim/` instantiates.

Godot-side equivalents, one per name, keeping the original file name stem so a red test points at the same promise (`docs/wayfinder/parity-harness.md`):

- `godot/tests/determinism_audit.gd` - ports `determinism-audit.mjs` first, per the harness ticket finding that a fixed-step port that drifts is not a port.
- `godot/tests/parity_digest.gd` - the Godot side of the cross-engine digest, sample grid ticks `0, 60, 120, ..., 1440` plus one sample at each point end, same digest fields, same scripted input sequence, same seed and same `--every` value as the JS run.
- Later slices own the remaining ported audits. This slice owns `determinism_audit` and the digest.

The cross-engine gate, stated honestly:

- The gate is the discrete state: identical `rngState`, identical `rngCalls`, identical counters, score fields and `shotType` sequence at every sampled tick, and identical point outcomes.
- The position tolerance of absolute `1e-3` court units (px) on positions and px/s on velocities, applied to the first divergence only, with any first-divergence mismatch a hard failure regardless of magnitude, is a PROPOSAL from `docs/wayfinder/tickets/simulation-port-boundary.md` section 6. It is not measured, it is not confirmed, and the parity gate definition is an open question for the human owner Luca. Do not present the tolerance as approved and do not close the slice on it. The digest harness reports both the discrete verdict and the first divergence, and the discrete verdict is what this ticket can call a result.
- Positions are float64 in JS but flow through float32 in Godot nodes, and `cos`, `sin`, `pow`, `hypot` and `atan2` are not the same functions (`js/game.js:459-478, 1093-1130, 2441`). One position difference can flip a probability gate (`nextRandom(state) < chance` at `602, 633, 1275, 1294, 1300, 1303, 2265, 2302, 2344, 2441`) and the engines then diverge for good. That is why the gate is the discrete state and the positions are a smoke check.

## Execution commands

The pinned binary is `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, build `ed1daf0bf`). `--headless` alone is enough; `xvfb-run` is not needed for a headless run. `timeout` is part of the contract, not decoration, because a runtime error that aborts `_ready()` hangs the main loop instead of going red. `--quit-after` must not be used as the CI bound because it exits 0 on an aborted run.

Godot smoke, the harness itself:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/; \
  echo "exit=$?"
```

Ported determinism audit:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/determinism_audit.tscn > docs/implementation/evidence/s1-determinism-godot.log 2>&1; \
  echo "exit=$?"; grep -E '^(PASS|FAIL)' docs/implementation/evidence/s1-determinism-godot.log
```

Godot parity digest. The flags mirror `scripts/parity-digest.mjs`; there is no fixture file to pass:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://tests/parity_digest.gd -- \
    --seed 12345 --ticks 1440 --every 60 --json docs/implementation/evidence/s1-parity-godot.json \
    > docs/implementation/evidence/s1-parity-godot.log 2>&1; \
  echo "exit=$?"
```

JS side of the same comparison, and the web baseline the port does not touch:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  node scripts/parity-digest.mjs --seed=12345 --ticks=1440 --every=60 \
    --json=docs/implementation/evidence/s1-parity-js.json \
    > docs/implementation/evidence/s1-parity-js.log 2>&1; echo "exit=$?"

cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s1-web-baseline.log 2>&1; echo "exit=$?"
```

Compare step, once both digest logs exist: a Node harness asserts the discrete matches and reports the first position divergence with its tick number. That harness belongs to the parity gate definition ticket and to the headless harness ticket, not to this one.

## Expected evidence

Artifacts on disk, each with an exit code:

- `docs/implementation/evidence/s1-parity-godot.log` - the Godot digest, one line per sampled tick, and a final `PASS n/n` or `FAIL n/n` line with a non-zero exit on failure.
- `docs/implementation/evidence/s1-parity-js.log` and `s1-parity-js.json` - the JS digest for the same seed, tick count and sample interval. The JSON is the machine-readable half.
- `docs/implementation/evidence/s1-parity-godot.json` - the Godot digest in the same shape, so the comparison reads two files rather than two log formats.
- `docs/implementation/evidence/s1-parity-compare.log` - the comparison result: discrete verdict per sampled tick, and the first position divergence with its tick number and magnitude, or the statement that none occurred before the first branch mismatch.
- `docs/implementation/evidence/s1-determinism-godot.log` - the ported determinism audit, printing the same three properties the JS audit prints: identical across frame rates, reproducible, seed sensitive.
- `docs/implementation/evidence/s1-web-baseline.log` - `npm run audit` on the frozen web build, for comparison. The harness ticket recorded 27/27 on 2026-09-16 and noted that `evidence/baseline-audit.log` records a stale 25/27. Neither number is repaired by this slice.
- `godot/src/sim/README.md` - the region-to-module map, so a reader can trace any GDScript function back to the `js/game.js` line it came from.

What counts as proof: the Godot run's exit code plus its `PASS`/`FAIL` line for the determinism audit, and the comparison log's discrete verdict. A digest that happens to match without a recorded exit code and a named seed does not count.

## Failure and recovery criteria

Red means any of these:

- The Godot determinism audit fails, or the harness hangs and `timeout` kills it (exit 124). A hang is a red, not a slow green.
- `rngState` differs at any sampled tick, or `rngCalls` differs by any amount, or any counter, score field or point outcome differs.
- The first position divergence occurs at a tick where the discrete state still agrees, with magnitude above the proposed `1e-3` bound. Record it as a divergence finding for the parity gate definition; do not silently relax the bound, because the bound is not this slice's to change.
- The engines agree only after a `BALANCE`, `COURT`, `SERVICE_LINE_OFFSET`, `WIN_SCORE`, `MATCH_FORMATS`, athlete stat or `wallBounce` change. That is re-tuning, not porting: stop, revert the number, and raise it for Luca with the `VERSION.balance` consequence stated.
- The port writes text into sim state, or lets the step allocate particles or play audio. That breaks the boundary and every later digest.
- Any write lands outside the allowlist, or `scripts/` or `js/` changes at all.

What stops the slice: a failed determinism audit after the retry rule below; a first divergence at tick 0, which means the seed injection point or the `i32` masking is wrong rather than the physics; or the JS digest script `scripts/parity-digest.mjs` being unreadable or its recorded flags changed by another writer, in which case the comparison has no reference side and the blocker is escalated instead of invented.

Retry rule: two attempts per gate, then record a blocker with the failing gate, the log line and the two attempts. No endless identical retries, per `docs/mission/CHARTER.md`. Continue any unrelated unblocked work instead of retrying a third time.

Recovery paths worth trying before declaring a blocker: assert the first eight `nextRandom` outputs against the JS values in isolation, before involving any physics; confirm the seed is injected after construction and before `prepareServe`, matching `scripts/determinism-audit.mjs:24`; confirm the one-shot consumption rule is applied to the first sub-step only; confirm the wall defender choice compares instead of sorting.

The slice may be called done only when the parity gate definition lands and Luca's verdict on it is recorded. Until then the correct status is built and pending gate, and no later slice may be declared complete on this slice's discrete result alone.
