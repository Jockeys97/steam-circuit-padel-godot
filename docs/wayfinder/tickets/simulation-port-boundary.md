# Simulation port boundary

- Status: resolved
- Type: research
- Mode: AFK
- Owner: crew-charlie
- Blocked by: none

## Question

Classify `js/game.js` (3359 lines), `js/data.js` (936 lines) and `js/drill.js`
(498 lines) into pure simulation logic and browser-coupled code. Name the
GDScript modules the pure part becomes, list every import that has to be
replaced (rendering, audio, DOM, `localStorage`), and pin the determinism
contract so a test can check it rather than a reader trusting it.

The determinism contract has two parts and both must be cited, not assumed:

- **Tick.** The fixed 120 Hz step is **not in `game.js`**. It lives in the frame
  loop: `FIXED_STEP = 1 / 120` at `js/main.js:1164`, consumed by the accumulator
  loop at `js/main.js:1186-1207` (`updateMatch(matchState, FIXED_STEP, ...)`),
  and reused by the drill loop at `js/main.js:2113`. `js/game.js` receives `dt`
  as a parameter and holds no tick constant. The GDScript tick value must cite
  these lines.
- **RNG.** `nextRandom(state)` at `js/game.js:22`; the per-match seed comes from
  `Math.random` once at `js/game.js:218` (`rngState`), and from there the
  simulation advances only through `nextRandom`. Replay identity depends on the
  call order, so the iteration order matters as much as the algorithm.

## Why it matters

This is the seam the whole port runs through. Get it wrong and parity work turns
into a rewrite of the tuning.

## Resolution

Everything below was read out of the repository at HEAD on 2026-09-16. Line
numbers are from that revision; the audit results quoted were produced by running
the audits, not assumed (see "Verification").

### 1. Module inventory

| Module | Lines | Owns | Port class |
|---|---|---|---|
| `js/data.js` | 936 | All tables: court geometry, `BALANCE` (163 keys), athletes, arenas, formats, AI tiers, career/objectives | **Data** — becomes Godot resources + a frozen constants script |
| `js/game.js` | 3359 | The whole match simulation and its state; RNG; scoring; walls; AI | **Simulation** — becomes the GDScript sim core, minus 4 couplings |
| `js/drill.js` | 498 | Drill wrapper over a real match state: exercises, attempt grading, target placement | **Simulation, second consumer** — must move with `game.js` |
| `js/fx.js` | 77 | Particle pool + screen shake; module-global `reducedMotion` | **Presentation**, but currently invoked from inside the sim step |
| `js/audio.js` | 292 | WebAudio synth: `sfx.*`, `music.*`; noise buffers use `Math.random` | **Presentation** — replaced by `AudioStreamPlayer` |
| `js/i18n.js` | 1415 | `it`/`en` dictionaries and `t()` | **Data** — becomes a Godot `Translation` / CSV |
| `js/render.js` | 1751 | Canvas 2D drawing; also exports two pure helpers (`clamp`, `predictLanding`) | **Presentation** — Canvas → 3D nodes; helpers get re-homed |
| `js/ui.js` | 1720 | DOM HUD/screens + all persistence (`localStorage` keys `padel.prefs`, `padel.history`, `padel.drill`, `padel.feedback`, `padel.career` at `js/ui.js:7-11`) | **Presentation + platform** — DOM → Godot UI, storage → `user://` |
| `js/main.js` | 2633 | Frame loop, fixed-step accumulator, input polling, gamepad, menus/OSK, DOM wiring, save cascade | **Platform/timing owner** — the tick lives here, not in the sim |
| `js/build.js` | 75 | Demo/full build detection and `DEMO_CONTENT` filter | **Platform** — becomes export preset + build flag |

### 2. The boundary, module by module

The sim core is **`js/game.js` minus four couplings**, all of which are imports
declared at `js/game.js:1-13`:

| Coupling | Anchor | Replacement |
|---|---|---|
| Audio: `sfx` | import `js/game.js:3`; 9 call sites — `750` (serve), `1893` (hit), `1898` (special), `2111`/`2113`/`2115` (point/victory/defeat), `2209` (bounce), `2363` (wall), `2382` (net) | Return/emit a `SimEvent` enum; a presentation layer plays the sound |
| Particles: `emitBurst`/`emitDust`/`emitSparks`/`emitSteam`/`updateFx`/`resetFx` | import `js/game.js:6-13`; called inside physics from `751`, `1899-1904`, `2210`, `2364`, `2383`; `updateFx` called from the sim step at `2988`; `resetFx` at `323`; `state.fx.shake` written by the sim at `1973` | Move every emission to the `SimEvent` boundary; the GDScript sim step must not allocate particles |
| Motion preference: `isReduceMotion()` | import `js/game.js:10`; **branches inside sim code** at `1058` (`showShotFeedback`) | Presentation-only branch; sim must emit "grade == perfect" and let the view decide |
| Strings: `t()` | import `js/game.js:4`; 187 call sites, e.g. `2110` (`pointMessage`), `2112`, `2209-2212` | Sim stores **message ids**, not text |
| Pure helper: `clamp` | import `js/game.js:2` from `js/render.js:4` — the only sim→render dependency | Re-implement in GDScript; `js/render.js:4` is 3 lines of arithmetic |

Verified absent from `js/game.js` and `js/drill.js`: `document.`, `window.`,
`localStorage`, `performance.now`, `requestAnimationFrame`, `setTimeout`,
`navigator.` — zero occurrences in both files. The simulation is already
headless-importable, which is why `scripts/determinism-audit.mjs:1-6` can import
it in Node.

Per-region mapping inside `js/game.js` (target: one GDScript module per row):

| Region | Lines | Contents | Target |
|---|---|---|---|
| RNG | `22-28` | `nextRandom(state)` | `SimRng.gd` |
| Court/const | `30-33` | `SERVICE_LINE_OFFSET = 126` (duplicated as `SERV_LINE` in `js/render.js:8`) | `Court.gd` const |
| Entity builders | `35-153` | `createPaddle`, `createBall`, `courtSide`, `pointLabel` | `SimTypes.gd` |
| State builder | `184-326` | `createMatchState` — **seeds `rngState` from `Math.random()` at `218`**; `options` reads only `humanMode` and `lineup` (`185-186`), so there is **no seed parameter** | `SimMatch.new(seed: int, ...)` |
| Events/replay | `328-365` | `addEvent`, `resetReplayBuffer`, `captureReplayFrame` | `SimMatch.gd` (replay buffer is deterministic snapshot state) |
| Serve | `367-459`, `669-779` | serve geometry, formations, receiver locking, `prepareServe`, `performServe` | `SimServe.gd` |
| Contact/quality | `479-1060` | `contactWidth`, forecasts, `evaluateShotQuality`, timing windows, energy | `SimShot.gd` |
| AI | `1078-1467`, `2431-2603` | shot choice, error rolls, doubles movement, `moveComputerPaddle` | `SimAi.gd` |
| Hit resolution | `1468-1922` | `hitBall` | `SimShot.gd` |
| Specials | `1923-1991` | `applySpecial`, `trySpecial` | `SimShot.gd` |
| Scoring | `1992-2213` | tennis/games/sets/tie-break, `scorePoint`, serve faults/lets | `SimScore.gd` |
| Bounce/walls/net | `2150-2415` | `handleGroundBounce`, `handleWalls`, `handleNetCollision` | `SimPhysics.gd` |
| Paddle motion | `2416-2542`, `2737-2972` | human + AI movement, tactics, charge/hit queues | `SimMovement.gd` |
| Step | `2712-2734` (`EMPTY_INPUT`), `2973-3359` | `updateMatch` — the single tick entry point | `SimMatch.step(dt, input)` |

`js/drill.js` maps as: exercise table `53-84` → data resource; `createDrill`
`86-148` → `SimDrill.new`; `updateDrill` `326-465` → `SimDrill.step`, which
already delegates all physics to `updateMatch` (`js/drill.js:355`) — so the drill
is not a second engine and must not become one in Godot. Its only sim-owned
nondeterminism is `placeTarget` at `149-162`, which uses **global `Math.random`
at `155`, `159` and `160`** instead of `nextRandom`. That is a defect to fix in
the port (and in the JS engine) before drill parity can be claimed.

`js/render.js` boundary detail: `clamp` (`4-6`) and `predictLanding` (`56-67`)
are pure; everything else in the file takes `ctx`/`canvas`. `predictLanding` is
used only by the renderer (`1577`), never by the sim — landing prediction inside
the sim is `playableEta` (`js/game.js:866`).

`js/main.js` boundary detail: pure timing, no game rules. `drawScene` (`1780`),
`drawDrill` (`1728`), `drawMiniMap` (`1344`), `drawReplayOverlay` (`1309`) and
`updateHud` (`1218`) are the presentation half of the loop.

### 3. Timing contract

| Fact | Anchor | Value |
|---|---|---|
| Fixed step | `js/main.js:1164` | `1 / 120` s |
| Max sub-steps per frame | `js/main.js:1165` | `8` |
| Accumulator clamp | `js/main.js:1196` | `min(acc + dt, FIXED_STEP * MAX_SIM_STEPS)` |
| Frame `dt` | `js/main.js:1186` | `min((now - lastTime)/1000, 0.25)` |
| Sub-step loop | `js/main.js:1200-1202` | `while (acc >= FIXED_STEP && steps < MAX_SIM_STEPS)` → `updateMatch(state, FIXED_STEP, ...)` |
| Drill loop | `js/main.js:2105-2120` | same two constants, `updateDrill(drillState, FIXED_STEP, input)` at `2115` |
| Drill accumulator clamp | `js/main.js:2111` | **absent** — the drill adds the raw frame, unlike the match loop |
| Hit-stop time scale | `js/game.js:3012-3015` | when `state.hitStop > 0`, `dt *= BALANCE.hitStopTimeScale` (0.15) — the sim step's *effective* dt is state-dependent |
| Wall-clock fields | `js/main.js:1155` | `matchState.lastTime = performance.now()` — presentation only, must not enter the sim |

Input is sampled **once per rendered frame**, not per tick: `getInput()` /
`getInput2()` at `js/main.js:1197-1198`, before the sub-step loop. One-shot
fields (`hit`, `special`, `switchPlayer`, `switchDirection`, `smashUpgrade`,
`cutVolley`, `teamTactic` — cleared by `consumeOneShot`, `js/main.js:1169-1181`)
are zeroed after the **first** sub-step (`1207-1209`). This is deliberate: see
the comment at `1204-1206`. Consequences for the port:

1. The tick constant is `1/120`; the accumulator is a *presentation-side*
   decoupling device. In Godot the equivalent is
   `Engine.physics_ticks_per_second = 120` plus an explicit
   `for i in sub_steps: sim.step(TICK, input)`; the sim must be handed the
   constant `TICK`, never Godot's `delta`, so the accumulator model stays
   available for the drill.
2. The one-shot consumption rule must be reproduced exactly, or a held trigger
   queues the same shot twice in one frame (the bug the comment records).
3. Dropped frames change how many sub-steps run, never the step size. Frame-rate
   independence is a *verified property*, not a claim:
   `scripts/determinism-audit.mjs:49-56` asserts identical state at 30/60/90/120/144 fps.

### 4. RNG contract

Algorithm (`js/game.js:22-28`), a mulberry32-style 32-bit generator whose state
lives in `state.rngState`:

```
a = (state.rngState + 0x6D2B79F5) | 0     state.rngState = a
t = Math.imul(a ^ (a >>> 15), 1 | a)
t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
return ((t ^ (t >>> 14)) >>> 0) / 4294967296
```

The GDScript port must emulate **Int32 wraparound**, because GDScript integers
are 64-bit and Godot has no `Math.imul`:

- `i32(x) = ((x & 0xFFFFFFFF) ^ 0x80000000) - 0x80000000` — apply after **every**
  `+` that can leave the 32-bit range (`state.rngState + 0x6D2B79F5`, and the
  `(t + Math.imul(...))` sum) and after every multiply (that is what `Math.imul`
  does: 32-bit signed multiply).
  `grep -c 'nextRandom(' js/game.js` returns **34**, not 32: the definition line
  (`22`) and the comment at `217` contain the token too.
- JS `>>` is an arithmetic shift on the int32 value — GDScript `>>` on a
  sign-extended negative int matches it.
- JS `>>>` is a **logical** shift of the uint32 view: use
  `(x & 0xFFFFFFFF) >> n` (non-negative, so GDScript `>>` is logical there).
- The returned value is an exact `uint32 / 2**32`, i.e. exactly representable in
  float64 — so **the RNG stream is bit-comparable across engines**, unlike
  trigonometry-heavy physics. That makes it the strongest available parity
  signal.

Seeding and reproducibility:

| Fact | Anchor |
|---|---|
| Seed is `(Math.random() * 0xffffffff) \| 0`, one per match | `js/game.js:218` (comment `216-217`) |
| `createMatchState` has **no seed parameter** — `options` reads only `humanMode` and `lineup` | `js/game.js:185-186` |
| Tests inject the seed by assignment after construction | `scripts/determinism-audit.mjs:24`; also `scripts/court-speed-audit.mjs:39`, `wall-rules-audit.mjs:50`, `lineup-audit.mjs:61,112`, `ai-attack-audit.mjs:32,113,166` |
| The engine must not use `Math.random` anywhere else in the sim; the audit enforces it by reading the source | `scripts/determinism-audit.mjs:76-89` |

The port must therefore take an explicit `seed: int` on the match constructor
and never seed from the engine RNG inside the sim. Call ordering: **32** call
sites of `nextRandom` in `js/game.js` (`602, 633, 732, 733, 1188, 1206, 1214, 1220,
1242, 1275, 1294, 1300, 1303, 1362, 1390, 1398, 1404, 1409, 1414, 1441, 1442,
1599, 1603, 1640, 1698, 1700, 1859, 1919, 2265, 2302, 2344, 2441`). Order is a
literal in-line sequence — no sorting or map iteration of unordered collections
— with **one exception**: `handleWalls` sorts the two defenders by distance and
takes element 0 (`js/game.js:2231-2233`). V8's `Array.prototype.sort` is
stable, Godot's `sort_custom` is not; with tied distances the two engines can
select different defenders and consume RNG on a different branch. Preserve
insertion order in the port (compare explicitly instead of sorting).

`state.fx` particles draw from **global** `Math.random` (`js/fx.js:29-41`), a
separate stream from `state.rngState`. That is why the particle emitter can sit
inside the sim step without breaking reproducibility. The port must keep the two
streams separate: if particles ever consume the sim RNG, every digest moves.

`state` also carries presentation-shaped fields advanced inside the step:
`runPhase`, `actionPose`, `motion`, `moveRatio` (`js/game.js:2989-2998`),
`ball.trail`/`trailTime`/`bouncePulse`/`landRing`/`hitFlash` (`91-105`, decayed
at `3247-3248`), `state.events` (`328-333`) and `pointMessage` (`2110`). They are
deterministic functions of state, so they may stay in the sim state, but the last
two are **localized strings** and must not enter a parity digest.

### 5. Data contract

| Table | Anchor | Becomes | Notes |
|---|---|---|---|
| `COURT` | `js/data.js:1-8` | **Frozen constant** | `left 80, right 880, top 56, bottom 564, netY 310, netHeight 38`. The px↔metre scale is still an open decision (see Unknowns) |
| `WIN_SCORE` | `js/data.js:10` | Frozen constant | `11` |
| `VERSION` | `js/data.js:20` | Resource metadata | `balance: "b7"` is the tuning tag; **any** `BALANCE` edit must bump it (rationale `12-19`) |
| `BALANCE` | `js/data.js:81-323` | **Frozen constant** | **163 keys.** Includes `gravity 38`, `ballGravity 720`, `groundRestitution 0.56`, `airDrag 0.9985`, `basePaddleSpeed 317`, `basePaddleWidth 112`, `playerContactReach 0.66`, `aiDepthReach 1.3`, `serveSpread 60`, `perfectTimingWindow 0.055`, `goodTimingWindow 0.13`, `hitStopTimeScale 0.15`, `shotErrorThreshold 0.8`, `shotErrorSpan 0.32`, `smashX2MinQuality 0.78`, `smashX3MinQuality 0.9`, `smashFlatMinQuality 0.48`, `x3RecoveryReach 5.5`, `rallyEnergyFloor 0.16`, `wallTangentialDamping 0.975`, `netClearance 42` |
| `ATHLETES` | `js/data.js:324-483` | **Resource** (6 entries) | Sim-relevant part is `stats { speed, power, control, reach, stamina }` and `special.cooldown` (`346-349`). All five stats are read: `stamina` at `js/game.js:1025-1026, 1033, 3338`; the rest via `statRatio`/`paddleRatio` (`js/game.js:173-183`). Sprite/visual fields are presentation |
| `ROSTER_AVERAGE` | `js/data.js:484-497` | **Computed at load** | Derived from `ATHLETES`; do not hardcode |
| `ARENAS` | `js/data.js:560-661` | **Resource** (9 entries) | `wallBounce` **is simulation** — `js/game.js:2272, 2284`. `floorGrip` (`566, 575, 584, 593, 603, 613, 624, 633, 643`) is **read by nothing in `js/`**: port it as data, do not invent behaviour for it |
| `MATCH_FORMATS` | `js/data.js:662-670` | **Frozen constant** | `points11`, `points21`, `games3`, `games5`, `set`, `match2` |
| `AI_OPPONENTS` | `js/data.js:673-685` | **Resource** (4 tiers) | `skill`, `speed`, `power`, `reactionSkill`. Tuned deliberately — see the comment at `678-684` on why `reactionSkill` stays at 0.78 |
| `EVENT_LINES` | `js/data.js:686-699` | Presentation data | Selected by `nextRandom` at `js/game.js:1919`, so its **length and order are sim-visible** even though the text is not |
| Career/objectives/unlock/outfits | `js/data.js:700-936` | Meta-progression | Out of scope for quick-match parity |
| `i18n` dictionary | `js/i18n.js:1-1415` | Godot translation resources | Sim keeps message ids (`js/game.js:187` call sites) |
| `DEMO_CONTENT` | `js/build.js:45-60` | Export-preset config | |

Nine `BALANCE` keys are declared and never read anywhere in `js/`:
`gravity`, `serviceBounceTime`, `baseHitLift`, `baseHitAngle`, `spinInfluence`,
`serveVy`, `serveVx`, `outMargin`, `sprintSpeedBonus` (anchor: `js/data.js:82,
94, 125, 126, 127, 131, 132, 142, 208`). `data.js:203-207` says so explicitly for
the sprint trio. Carry them verbatim as constants — a port that "cleans them up"
silently creates untested behaviour; a port that drops them loses the numbers the
day a formula reads them again.

**Not to be retuned during the port.** Any change to: `COURT`; the 163 `BALANCE`
values; `SERVICE_LINE_OFFSET = 126` (`js/game.js:30`); `WIN_SCORE`;
`MATCH_FORMATS`; the `stats` block of any athlete; `AI_OPPONENTS` `skill`/`speed`/
`power`; any arena's `wallBounce` — requires Luca's explicit approval and a
`VERSION.balance` bump (`js/data.js:20`). The designs these numbers implement are
written in `GAMEPLAY_RULES.md:133-140` (speed, AI speed ceiling, lateral
deviation, max response height, post-bounce deceleration) — a port that needs to
change one of these numbers is not porting, it is re-tuning, and it must say so.

### 6. Cross-engine parity test

**Shape.** Same seed + same input script, both engines, identical tick counts,
compare a state digest. The JS reference already exists in prototype form:
`scripts/determinism-audit.mjs:19-47` plays a point with an injected seed and a
fixed accumulator, and its digest is `{ball x/y/z, rallyHits, points, rngState}`
(`41-45`). Extend that shape rather than inventing a new one.

- **Input script**: one input object per **tick**, not per frame — the 22-field
  struct at `js/game.js:2712-2734`. Per-frame scripts would drag the
  frame-sampling asymmetry of `js/main.js:1197-1209` into the comparison.
- **Sample grid**: ticks `0, 60, 120, …, 1440` (every 0.5 s for 12 s), plus one
  sample at each point end.
- **Digest** per sample: `rngState`; `ball {x,y,z,vx,vy,vz,spin,shotType,
  smashStage}`; `bounces`; the four paddles' `{x, y}`; `points`, `games`, `sets`,
  `playerScore`, `aiScore`, `serveAttempts`, `rallyHits`; and a **`rngCalls`
  counter** (a test-only counter incremented inside `nextRandom`, mirrored in
  GDScript).
- **Comparable bit-for-bit**: `rngState` (int32), `rngCalls`, all counters and
  score fields, `shotType`/`smashStage` enums, `serveAttempts`, and the ordered
  list of point outcomes — exactly what the current audit asserts for
  reproducibility (`57-61`) and seed sensitivity (`64-70`).
- **Not bit-comparable**: `x/y/z/vx/vy/vz`. Positions are float64 in JS but flow
  through float32 in Godot nodes, and `cos/sin/pow/hypot` are not the same
  functions (`js/game.js:459-478, 1093-1130, 2441` use `Math.hypot`, `Math.cos`,
  `Math.sin`, `Math.atan2`). Tolerance: **absolute `1e-3` on court units (px) and
  on px/s**, per sampled tick, applied to the *first divergence only* — after the
  break, positions are compared loosely, because a 1e-3 position drift can flip a
  probability gate (`nextRandom(state) < chance` at `602, 633, 1275, 1294, 1300,
  1303, 2265, 2302, 2344, 2441`) and then the two engines legitimately diverge
  for good.
- **Therefore the gate is the discrete state, not the floats**: require identical
  `rngState` and `rngCalls` at every sampled tick, identical point outcomes and
  identical `shotType` sequence, and treat positions as a smoke check that must
  stay within `1e-3` until the first branch mismatch, which is a hard failure
  regardless of magnitude. This mirrors what `js/render.js:56` `predictLanding`
  already does visually.
- **Explicitly outside the comparison**: `Math.random` outside the seeded path —
  particles (`js/fx.js:29-41`), audio noise buffers (`js/audio.js:45, 208`),
  drill target placement (`js/drill.js:155-160`), the match seed line
  (`js/game.js:218`); frame-time behaviour — the accumulator clamp
  (`js/main.js:1196`), the unclamped drill accumulator (`2111`), HUD/fx timers;
  wall clock (`js/main.js:1155`, `matchState.lastTime`); and localized strings in
  state (`js/game.js:328-333`, `2110`).
- **Commands** (to be implemented under `scripts/` and `godot/tests/`; nothing is
  built here):
  - JS: `node scripts/parity-digest.mjs --seed=12345 --ticks=1440 --input=scripts/fixtures/input-quick.json`
  - Godot: `godot --headless --path godot --script res://tests/parity_digest.gd -- --seed 12345 --ticks 1440 --input res://tests/fixtures/input-quick.json`
  - Compare: a Node harness that asserts the discrete matches and the `1e-3`
    float tolerance. The harness belongs to
    [Godot headless harness](godot-headless-harness.md) and
    [Parity gate definition](parity-gate-definition.md).

Current baseline, run on this host (`node v22.22.1`):

```
$ node scripts/run-audits.mjs        # suites that matter here
determinism PASS  court-speed PASS  shot-balance PASS
wall-rules PASS   shot-quality PASS
```

So determinism is a **stated, currently-passing property of the engine**, not an
aspiration: frame-rate independence, seed reproducibility and seed sensitivity
are asserted at `scripts/determinism-audit.mjs:49-70`, and the absence of stray
`Math.random` in the sim is asserted by reading the source at `76-89`.

### 7. Port risks, ranked

| # | Risk | Evidence | Mitigation |
|---|---|---|---|
| 1 | **RNG word semantics.** GDScript has no `Math.imul` and 64-bit ints; a naive transcription of `js/game.js:22-28` diverges silently from the first call | 32 call sites; the algorithm mixes `\|0`, `Math.imul`, `>>`, `>>>` | Implement `i32()` masking exactly as in §4 and assert the first 8 outputs against the JS values in the parity harness |
| 2 | **Divergence amplification through probability gates.** One float difference flips a `nextRandom(state) < chance` branch and the engines diverge permanently; the JS audit only proves self-consistency within one engine | `602, 633, 1275, 1294, 1300, 1303, 2265, 2302, 2344, 2441` | Gate on `rngState` + `rngCalls` per tick, not on positions; keep transcendentials out of the *decision* path where possible |
| 3 | **Presentation coupling inside the sim step.** Particles, sfx and a motion preference are invoked from inside physics | `751, 1899-1904, 2210, 2364, 2383` (fx), `750, 1893, 1898, 2111-2115, 2209, 2363, 2382` (sfx), `2988` (updateFx), `1973` (shake), `1058` (isReduceMotion) | Extract a `SimEvent` list from the step; the GDScript step emits, never renders. Dropping the emission entirely breaks the "keep every feature" promise for shot feedback |
| 4 | **Unstable sort in wall handling.** JS sort is stable, Godot's `sort_custom` is not | `js/game.js:2231-2233` | Compare the two defenders explicitly; never sort a 2-element tie |
| 5 | **Drill nondeterminism.** Drill targets are placed with global `Math.random` | `js/drill.js:155, 159, 160`; no `nextRandom` in the file (`js/drill.js` count: 0) | Switch to `nextRandom` in both engines; verify with a seeded drill test |
| 6 | **Localized text stored in sim state.** `addEvent` stores what the player reads | `js/game.js:328-333`, `2110`; 187 `t()` call sites in `game.js` | Move text to message ids; exclude `events`/`pointMessage` from digests |
| 7 | **Two timing owners drift apart.** The match accumulator clamps, the drill accumulator does not | `js/main.js:1196` vs `2111` | Port both faithfully first, then decide whether to unify — as a deliberate change with its own ticket |

### 8. Genuinely unknown

- **The px↔metre scale.** The court is "20 x 10 metri" (`GAMEPLAY_RULES.md:11`)
  but every simulation constant is in px (`COURT` spans 800 x 508 px,
  `js/data.js:1-8`; `basePaddleSpeed 317` px/s). Whether the 3D build keeps the
  px-authored numbers on a scaled root transform, or re-derives metres, changes
  nothing about determinism but everything about how §5's frozen numbers read.
  Needs [Camera and feel spike](camera-and-feel-spike.md) and Luca.
- **Per-frame vs per-tick input in Godot.** `js/main.js:1197-1209` samples input
  once per rendered frame and consumes one-shots on the first sub-step. Godot's
  `_input`/`_physics_process` would naturally sample per tick. Both are
  reachable; only play says which feels right. Not decidable from source.
- **Whether `state.fx.shake` (`js/game.js:1973`) is a sim event or a view
  concern.** It is currently written by the sim on a special shot; the camera
  ticket owns the answer.
- **Godot float/physics exactness.** Whether `1e-3` in §6 is comfortably inside
  or outside reality depends on Godot's math functions, and cannot be measured
  without the harness. The $1e-3$ figure is a proposal, not a measurement.
- **GDScript module granularity.** The mapping table in §2 is one proposal; the
  number of files does not affect parity and is [Godot headless harness](godot-headless-harness.md)'s
  call.
- **Whether the drill keeps its own loop** (`js/main.js:2105-2131`) or becomes a
  match variant in Godot. Functionally equivalent today; a product decision.

## Verification

One command re-checks every load-bearing anchor in this ticket:

```bash
cd /root/projects/steam-circuit-padel-pro \
 && sed -n '1164,1166p;1186p;1196,1211p' js/main.js \
 && sed -n '2105,2121p' js/main.js \
 && sed -n '22,28p;184,186p;218p' js/game.js \
 && echo "nextRandom call sites: $(grep -c 'nextRandom(' js/game.js)" \
 && echo "game.js browser APIs: $(grep -c 'document\.\|localStorage\|performance\.now\|requestAnimationFrame' js/game.js)" \
 && echo "drill Math.random lines: $(grep -n 'Math.random' js/drill.js | tr '\n' ' ')" \
 && node scripts/determinism-audit.mjs
```

Expected: `FIXED_STEP = 1 / 120` on a line of `1164`, the two sub-step loops
matching, `184-186` showing `createMatchState` reading only `humanMode`/`lineup`,
`218` seeding from `Math.random`, `nextRandom` **34** raw grep hits (32 real call
sites plus the definition at `22` and the comment at `217`), browser APIs in
`game.js` **0**, `Math.random` in `drill.js` on lines `155`, `159`, `160`, and the
determinism audit printing
`identicalAcrossRates: true, reproducible: true, seedSensitive: true,
strayMathRandom: 0`.

## Resolved when — check

- [x] Per-region JavaScript → GDScript mapping — §1, §2
- [x] Replaced imports named — §2 (table of four couplings + the import anchors)
- [x] Tick cited to `js/main.js` lines — §3 (`1164`, `1165`, `1196`, `1200-1202`,
      `2113-2116`)
- [x] RNG pinned to an algorithm a test can replay — §4
- [x] Iteration order stated — §4 (34 call sites, fixed-array iteration,
      the one sort)
- [x] Document under `docs/wayfinder/` — this file
