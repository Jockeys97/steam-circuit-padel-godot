# Drill as a 3D session (slice S8)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Quick-match vertical slice in 3D](quick-match-slice.md) technically: the drill is a wrapper over the same match engine and cannot land before the engine is playable in 3D. Acceptance is additionally blocked by [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md) (open, HITL, owner Luca) only insofar as it decides the input surface the drill is played on; a drill session that runs the four existing exercises is not otherwise a scope question. The drill's own determinism defect is a finding to record, not a gate to wait on.

This ticket implements row S8 of `docs/implementation/PLAN.md` ("Drill as a 3D session"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S9 through S13.

## Objective

Bring the training mode into the port as a real 3D session that runs on the same simulation the match runs on. The web build's drill is a wrapper, not a second engine — `js/drill.js` imports `createMatchState`, `hitBall`, `prepareServe` and `updateMatch` and delegates every physical step to the match engine at `js/drill.js:361`, and the drill audit exists precisely to keep it that way, asserting both that the file imports the engine and that it contains no self-integrated ball physics. The Godot drill is built to the same rule: a `DrillSession` that owns exercises, rounds, attempts and targets, and delegates every step to `godot/src/sim/sim.gd`. Any second physics path is the failure this slice is defined against.

The drill also carries a defect that must be stated rather than inherited silently: target placement uses global `Math.random` at `js/drill.js:155`, `:159` and `:160` instead of the seeded generator. In the web build that makes drill runs unreproducible; in the port, an unseeded target cannot be reproduced either, and it cannot be made byte-comparable with the JavaScript side without editing `js/`, which this mission forbids. This slice fixes the port's own placement to use the injected seed, records the JavaScript defect as a finding with its anchors, and states plainly that drill digests are therefore not cross-engine comparable until the reference is fixed by someone allowed to fix it.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/drill.js:1-2` | The import block: `BALANCE, COURT, AI_OPPONENTS` from `data.js`, and `createMatchState, hitBall, prepareServe, updateMatch` from `game.js`. The engine dependency the drill audit guards |
| `js/drill.js:361` | `updateMatch(state, dt, input);` — the single line where a drill step becomes an engine step. The port's `DrillSession.step` calls the GDScript equivalent and nothing else |
| `js/drill.js:53-71` | `DRILL_EXERCISES`, the four exercises: `precision` (flat feed, targets, kinds `["short", "deep"]`), `smash` (lob feed, rivals, no targets), `rally` (flat feed, rivals, no targets), `serve` (serve feed, rivals, no targets) |
| `js/drill.js:73` | `exerciseById(id)` — the lookup, with a fallback to the first exercise |
| `js/drill.js:78` | `placeTeams(state)` — the starting positions (player at the back, the pair at the net). Deterministic and part of the scenario |
| `js/drill.js:86` | `createDrill(exerciseId, athlete, arena, aiProfile = AI_OPPONENTS[1], lineup = {})` — the drill state is a match state plus a drill wrapper |
| `js/drill.js:149-162` | `placeTarget(drill)` — the target ring, placed with **global `Math.random` at `:155`, `:159` and `:160`**. The determinism defect |
| `js/drill.js:234` | `resetDrill(drill)` — round reset, including the match state's own reset call |
| `js/drill.js:326` | `updateDrill(drill, dt, input)` — the drill step entry point; phases `ready`, `live`, `result` |
| `js/drill.js:466` | `drillScoreLine(drill)` — the summary line the result screen shows |
| `js/drill.js:475` | `drillMetrics(drill)` — the metrics behind the record |
| `js/main.js:2105-2121` | The drill loop: same `FIXED_STEP` and `MAX_SIM_STEPS`, `updateDrill` called at `:2115`, and the accumulator at `:2111` **without** the clamp the match loop has at `js/main.js:1196`. Two timing owners that already differ; the port reproduces both faithfully and does not unify them in this slice |
| `js/main.js:1639` | `getAiForMatch("quick", 0, ui.drillDifficulty ?? ui.aiDifficulty)` — the drill's AI profile comes from the same resolver the match uses |
| `js/ui.js:206-226` | `loadDrillRecords`, `drillRecord`, `saveDrillRecord` — best-score persistence under the `padel.drill` key, saved only on improvement. The storage seam belongs to [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md) |
| `index.html:362` | `screen-drill`, the DOM screen the 3D session replaces |
| `scripts/drill-audit.mjs:52-60` | The two claims that define the drill: the file must import the engine (`/from "\.\/game\.js\?v=/`), and it must not contain any of `ballGravity * dt`, `GRAVITY * dt`, `vz -=`, `b.z +=` — a self-integrated ball flight is a failure |
| `scripts/drill-audit.mjs:69-75` | The drill state is asserted to be a real match state: the athlete carries its stats, the arena carries its `wallBounce`, the mode declares itself, and `pointsToWin > 1000` so a single point cannot end the session |
| `scripts/drill-audit.mjs:86-100` | The four exercises each start a round on the first input, prepare a serve where the feed is `serve`, and place an active target where the exercise has targets |
| `scripts/drill-audit.mjs:114-115` | Every exercise closes at least one attempt within 20 seconds of simulation, and the attempt counter advances |
| `GAMEPLAY_RULES.md:39-43` | Rally energy, resets per point — the drill's own scoring leans on this |
| `GAMEPLAY_RULES.md:142-150` | The feedback contract the drill screen must also honour (grade, intent, energy bar) |
| `godot/src/sim/sim.gd` | The engine the drill delegates to: `create_match_state`, `update_match`, `hit_ball`, `prepare_serve` |
| `godot/src/sim/frozen.gd` | `court()`, `balance()`, `athletes()`, `arenas()`, `ai_opponents()` |

The seams this slice sits next to, each with one owner: the screen router and the shared theme belong to [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md), which owns the placeholder shell this slice's screen replaces and the only code that switches screens; persistence belongs to [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md); strings belong to `godot/src/locale/**`; input belongs to [Quick-match vertical slice in 3D](quick-match-slice.md). This slice registers its screen by data, never by editing the router.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/drill/DrillSession.gd` — the wrapper: exercises, rounds, attempts, phases (`ready`, `live`, `result`), grade life, and `step(dt, input)` which calls `sim.gd` and nothing else
- `godot/src/drill/DrillExercises.gd` — the four exercises, generated from `js/drill.js:53-71` rather than re-typed
- `godot/src/drill/DrillTarget.gd` and `DrillTarget.tscn` — the target ring, its kind (`short`, `deep`), its radius and its active state
- `godot/src/drill/DrillScoring.gd` — the attempt grading and the score line, ported from `drillScoreLine` / `drillMetrics`
- `godot/src/drill/DrillSeed.gd` — the seeded replacement for the unseeded placement, drawing from the same injected generator the match uses, with the JavaScript defect and its anchors recorded in the file header
- `godot/src/ui/screens/DrillScreen.gd` and `DrillScreen.tscn` — the session screen, replacing the placeholder shell the HUD slice installs. It registers itself with the router by data, and the router file is not edited
- `godot/tests/drill_audit.gd` and `godot/tests/drill_audit.tscn` — the ported drill audit, same promises as `scripts/drill-audit.mjs`
- `godot/tests/drill_determinism_audit.gd` and `.tscn` — the port's own addition: two runs, one seed, identical target positions and attempt outcomes. It exists because the JavaScript side cannot make that claim
- `godot/tests/capture_drill.gd` — the capture harness
- `godot/shots/drill-precision.png`, `godot/shots/drill-smash.png`, `godot/shots/drill-serve.png` and an append to `godot/shots/README.md`
- `docs/implementation/evidence/s8-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file, **including `js/drill.js`** — the unseeded placement is recorded as a finding, not fixed here), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md); the drill consumes it), `godot/src/ui/ScreenRouter.gd`, `godot/src/ui/theme/`, `godot/src/ui/UiStrings.gd` (owned by [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md)), the save interface files (owned by [Saves, Steam achievements and Steam Cloud](saves-steam-cloud.md)), `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/input/**`, and `godot/prototypes/`.

## Inputs and outputs

Inputs:

- The simulation core through its published entry points: `create_match_state("drill", athlete, arena, ai_profile)`, `update_match(state, dt, input)`, `prepare_serve(state)`, `hit_ball(...)`.
- The four exercises and their feeds, read from the generated exercise table.
- The seed, injected explicitly, for the port's own target placement.
- The per-tick input, the same 22-field dictionary the match uses, sampled once per rendered frame with the one-shot rule applied to the first sub-step only.
- The tick, `1.0 / 120.0`, handed to the drill the same way `js/main.js:2115` hands it to `updateDrill`, and the drill's accumulator reproduced **without** the match loop's clamp, matching `js/main.js:2111`.

Outputs:

- A runnable drill session in 3D: four exercises selectable, each starting a round, each placing its targets, each grading attempts and ending rounds, and none of it stepping physics outside the engine.
- Targets placed from the injected seed, with the placement function deterministic and reproducible across runs of the same seed.
- A score line and a record per exercise, written through the save seam rather than into a storage API directly.
- Rendered captures of three of the four exercises.
- The ported drill audit plus a determinism audit the JavaScript side cannot run, with the JavaScript defect recorded and anchored.

Explicitly not output: new exercises, new target behaviours, a second physics path, any change to `js/drill.js`, any claim of cross-engine drill parity, and any claim about frame rate.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/drill-audit.mjs` — the primary gate, ported promise for promise: the drill imports the engine and contains no self-integrated ball physics (`:52-60`); the drill state is a real match state with the athlete's stats, the arena's `wallBounce`, a declared mode and a `pointsToWin` above 1000 (`:69-75`); all four exercises start a round on the first input and place their targets where the exercise has them (`:86-100`); each exercise closes at least one attempt within 20 simulated seconds and the counter advances (`:114-115`).
- `scripts/determinism-audit.mjs` — the seeded-generator rule the drill currently breaks. The port's equivalent is `drill_determinism_audit.gd`, which asserts two runs of the same seed produce identical target positions and identical attempt outcomes. That audit is the port holding a higher standard than the reference, and it is stated as such.
- `scripts/assets-audit.mjs` — the Godot equivalent is load-time resolution of the drill screen's resources.
- `scripts/reachability-audit.mjs` — the drill screen must be reachable from the menu; the check itself is `godot/tests/reachability_audit.gd`, owned by [In-match HUD and main menu in Godot Control nodes](hud-and-menu.md), which this slice registers with rather than edits.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` — the replacement stays the headless load with zero script errors.

Godot-side equivalents:

- `godot/tests/drill_audit.gd` — prints one `ok`/`FAIL` line per promise above and `PASS n/n`. Its no-second-engine check is structural as well as behavioural: the audit reads the drill source and fails if a ball-integration expression appears in it, the way the JavaScript audit reads its own source.
- `godot/tests/drill_determinism_audit.gd` — two seeded runs, identical targets and outcomes.
- `godot/tests/capture_drill.gd` — three captures under one camera preset.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. `timeout` is the CI bound, not `--quit-after`.

The drill audit and the determinism audit:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in drill_audit drill_determinism_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s8-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s8-${a//_/-}.log; \
done
```

Reproducibility by hand: the same seed twice, diffed:

```sh
cd /root/projects/steam-circuit-padel-pro && for run in 1 2; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/drill_determinism_audit.tscn -- --seed=4242 --exercise=precision \
    >> docs/implementation/evidence/s8-drill-seed-4242.log 2>&1; echo "run${run} exit=$?"; \
done; awk '/target-grid/{print}' docs/implementation/evidence/s8-drill-seed-4242.log | sort | uniq -c
```

Captures under software GL — `--headless` installs the dummy driver and the frame is blank, so this route is `xvfb-run` plus an explicit rendering driver:

```sh
cd /root/projects/steam-circuit-padel-pro && for ex in precision smash serve; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/capture_drill.tscn -- --exercise=${ex} --preset=playable \
    >> docs/implementation/evidence/s8-capture.log 2>&1 || echo "CAPTURE FAILED: ${ex}"; \
done; echo done
```

The defect this slice records rather than fixes, printed for the evidence file:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  grep -n 'Math.random' js/drill.js && \
  grep -c 'nextRandom(' js/drill.js; echo "nextRandom count above must be 0"
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && node scripts/drill-audit.mjs; echo "drill exit=$?"
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s8-web-baseline.log 2>&1; echo "exit=$?"
```

## Expected evidence

- `docs/implementation/evidence/s8-drill-audit.log` — the ported drill audit, exit code and `PASS n/n`, with every promise named.
- `docs/implementation/evidence/s8-drill-determinism-audit.log` — the two-seed run, with identical target positions reported as identical.
- `docs/implementation/evidence/s8-drill-seed-4242.log` — the manual two-run reproducibility check, with the `uniq -c` counts showing each target line appearing exactly twice.
- `docs/implementation/evidence/s8-capture.log` — the three capture runs, their exit codes, the exercise, the seed and the rendering driver.
- `godot/shots/drill-precision.png`, `godot/shots/drill-smash.png`, `godot/shots/drill-serve.png` — 1280x720, one camera preset.
- `godot/shots/README.md` — appended: preset, scale, software-GL caveat.
- `docs/implementation/evidence/s8-drill-notes.md` — the exercise table as ported, the phase machine, the accumulator rule the port reproduced (unclamped, unlike the match loop, with both anchors cited), the seeded placement that replaces the unseeded one, the JavaScript defect finding with its three anchors and the explicit statement that cross-engine drill digests are not comparable until the reference is fixed by someone allowed to edit `js/`, and the list of what the drill does not do (no new exercises, no second engine, no record migration).
- `docs/implementation/evidence/s8-web-baseline.log` — the untouched web suite, `27/27 audit passano`, exit 0.

What does not count as proof: a drill screenshot without its log; a determinism claim without two runs of the same seed shown side by side; an attempt count reported without the exercise that produced it; and any claim of parity with the JavaScript drill, which the defect makes impossible today.

## Failure and recovery criteria

Red means any of these:

- Either audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- The drill integrates any part of the ball's flight itself, or contains a physics expression of the kind `scripts/drill-audit.mjs:56-60` forbids. A second engine path is the failure this whole slice exists to prevent.
- A round or attempt changes the frozen values: `COURT`, `BALANCE`, `AI_OPPONENTS`, an athlete's `stats`, or an arena's `wallBounce`.
- The drill's `pointsToWin` lets a single point end the session.
- The port silently inherits the unseeded target placement, or silently normalizes the drill accumulator to the match loop's clamp instead of reproducing both faithfully.
- The slice edits `js/drill.js`, or claims cross-engine drill parity.
- A capture run exits non-zero or writes a blank frame because it went through the dummy driver.
- A file outside the allowlist changes, or `js/` or `scripts/` changes at all.
- A frame-rate claim appears in the evidence.

What stops the slice: a red audit after the retry rule below; the drill state not being constructible on the current simulation core, in which case the blocker is recorded against [Sim core parity](sim-core-parity.md) rather than worked around with a local state; or the product-scope decision the input surface depends on not landing, which blocks play but not the headless session.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm `DrillSession.step` calls the engine and does not hold a copy of it; confirm the drill's athlete and arena come from the frozen data and not from a literal; confirm the target placement draws from the injected generator and not from the engine's own randomness; confirm the capture run passed `--rendering-driver opengl3` under `xvfb-run`; confirm the 20-second attempt window is measured in simulated seconds and not wall-clock seconds.

## Human gates that block this slice (open, owner Luca)

- **Product scope and platforms** — the input surface the drill is played on, and whether touch and the on-screen keyboard are kept, postponed or dropped. This slice runs the drill from the same input the match uses and names the question; it does not decide.
- **Court aspect** — the drill's court and target geometry follow the same undecided px-to-metre scale as the match. The slice states the scale it used and does not resolve the conflict.
