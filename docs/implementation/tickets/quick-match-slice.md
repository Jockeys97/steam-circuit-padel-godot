# Quick-match vertical slice in 3D (slice S2)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Sim core parity](sim-core-parity.md) technically. The done verdict is blocked by [Camera and feel spike](../../wayfinder/tickets/camera-and-feel-spike.md) and [UI port approach](../../wayfinder/tickets/ui-port-approach.md), both open and owned by Luca. The slice can be built now; it cannot be called complete.

This ticket implements row S2 of `docs/implementation/PLAN.md` ("Quick-match vertical slice in 3D"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S3 through S13.

## Objective

Take the headless sim core delivered by S1 and put a real 3D quick match around it: a menu, a diagonal serve, a rally with drive, slice, lob, volee and the special, points, tennis scoring, the four AI tiers reachable, and the shot feedback visible in PERFETTO / BUONO / IN ANTICIPO / IN RITARDO with CONTROLLO / BILANCIATO / POTENZA. The match physics stays exactly the S1 sim, stepped on the fixed `1/120` s tick with input sampled per rendered frame; this slice adds camera, court mesh, ball and paddle visuals, input mapping and the two screens, and consumes the sim's event list for sound hooks, particles, feedback text and camera shake. It is a vertical slice, not a finished game: it proves the sim drives real 3D and that a human can play it, and it stops short of the remaining arenas, athletes, audios, saves and Steam work.

## Existing source anchors

Browser-side anchors are real files and lines in this repository at the frozen commit `2979588`. Gameplay intent is `GAMEPLAY_RULES.md`.

| Anchor | What it is | Status |
|---|---|---|
| `GAMEPLAY_RULES.md:17-25` | Serve rules: server stays behind the service line and in its own box, serve is from below, must cross the net and land only in the diagonally opposite box, the return cannot be a volley before the bounce, one fault gives a second serve, two consecutive faults are a double fault | verified |
| `GAMEPLAY_RULES.md:39-43` | Shot quality: low quality produces a short or central ball first, net and out become likely only when timing, position, extreme aim, low energy or excess power stack up; energy is rally-local and resets each point | verified |
| `GAMEPLAY_RULES.md:47-65` | Ball and shot behaviour: readable parabola, volley faster but weaker than a clean smash, lob depth tied to charge, smash window and bandeja fallback, technical smash x2 and x3, extreme aim seeking the side glass | verified |
| `GAMEPLAY_RULES.md:69-100` | AI decision priority, target zones, controlled error, one counter-attack per trajectory at most, difficulty changing timing and tactical precision but never granting impossible contacts | verified |
| `GAMEPLAY_RULES.md:102-111` | Glass and point assignment: direct wall hit without a bounce gives the point to the side owning that wall, second bounce closes the point | verified |
| `GAMEPLAY_RULES.md:113-131` | Doubles: pair defends from the back and attacks at the net in two lanes with a stagger, designated receiver intercepts, partner covers, automatic switch evaluated at the opponent's shot, fixed diagonals on serve return, both receivers behind the service line until the return | verified |
| `GAMEPLAY_RULES.md:142-150` | Player feedback: the log explains valid serve, valid glass, second bounce, double fault and defensive shot; score stays tennis; the ball animation must make height and bounce point obvious; after contact a short PERFETTO / BUONO / IN ANTICIPO / IN RITARDO label appears with CONTROLLO / BILANCIATO / POTENZA; a thin bar under the active player shows remaining rally energy | verified |
| `GAMEPLAY_RULES.md:152-180` | Controller map: full analog left stick with radial deadzone and progressive curve, A charges drive, X charges slice or vibora, Y charges lob, B is the special, LB switches player fast, stick aims absolutely during charge, timing meter, execution profiles, smash needs a second A at impact with stick direction selecting x2 / x3 / flat / bandeja, LT split-step, RT analog sprint, RB technical modifier, D-pad team tactics, right-stick flick for the directional switch, three player-switch modes | verified |
| `GAMEPLAY_RULES.md:182-188` | Acceptance criteria: the AI completes multi-hit rallies without hitting walls directly or going out in most exchanges, its shots stay inside the court margins except deliberate risk, every AI point lost corresponds to a visible rule, the player can predict where the ball will arrive and has time to move | verified |
| `GAMEPLAY_RULES.md:11` | "20 x 10 metri". This conflicts with `COURT` (800 x 508 px, aspect 1.575). Open human question, not resolved here | verified |
| `js/game.js:2973` | `updateMatch(state, dt, input, input2 = null)`, the single tick entry point this slice drives | verified |
| `js/game.js:2712-2734` | `EMPTY_INPUT`, the 22-field input struct the controller mapping must fill | verified |
| `js/game.js:3012-3015` | `hitStop` scaling `dt` by `BALANCE.hitStopTimeScale`, the one state-dependent step size | verified |
| `js/game.js:750-751` | Serve sound and steam emission, the shape of the event this slice must consume for feedback | verified |
| `js/game.js:1973` | `state.fx.shake` written by the sim on a special shot. Whether that is a sim event or a view concern is open, and the camera ticket owns the answer | verified |
| `js/game.js:2209-2212` | Bounce sound and point message, the feedback the HUD must reproduce | from the boundary ticket |
| `js/main.js:1164-1165` | `FIXED_STEP = 1 / 120`, `MAX_SIM_STEPS = 8` | verified |
| `js/main.js:1196-1209` | Accumulator clamp, sub-step loop, input sampled once per rendered frame, one-shot fields cleared after the first sub-step | from the boundary ticket |
| `js/data.js:673-685` | `AI_OPPONENTS`, the four tiers with `skill`, `speed`, `power`, `reactionSkill` | verified line, contents from the boundary ticket |
| `js/data.js:324` | `ATHLETES`, the six entries. `maestro` and `pantera` are the first two built, by the roster-order default | verified line, roster order from `PLAN.md` |
| `js/data.js:560` | `ARENAS`, nine entries. Quick match uses the first arena for the slice | verified line |
| `js/data.js:662-670` | `MATCH_FORMATS`. Scoring comes from the sim, not from this slice | verified |
| `godot/project.godot` | Physics tick already 120 Hz, `gl_compatibility` renderer, current main scene `res://tests/SmokeTest.tscn` | verified |
| `godot/tests/SmokeTest.tscn`, `godot/tests/smoke_test.gd` | The headless harness and its machine-readable contract: `ok <name>`, `FAIL <name>: expected <x>, got <y>`, `PASS <n>/<n>`, exit 0 or 1 | verified |
| `godot/prototypes/arena_spike/` | The playable preset framing that `PLAN.md` keeps as the provisional composition until Luca's verdict. Exists with `arena_spike.gd`, `Main.tscn`, `render.sh`, `assets/volpe-rigged.glb` and three 1280x720 captures | verified |
| `godot/prototypes/render_probe/` | Software GL render probe, proof that a rendered capture is possible on this host | verified |

Frozen constants, from `docs/wayfinder/tickets/simulation-port-boundary.md` and restated in `PLAN.md`: `COURT`, the 163 `BALANCE` values, `SERVICE_LINE_OFFSET`, `WIN_SCORE`, `MATCH_FORMATS`, every athlete's `stats`, `AI_OPPONENTS` `skill` / `speed` / `power`, and every arena's `wallBounce`. This slice changes none of them. If a 3D rendering choice seems to require a different number, the choice is wrong, not the number.

Court aspect is open and stays open: `COURT` is 800 x 508 px, aspect 1.575, while `GAMEPLAY_RULES.md:11` says 20 x 10 metri. Build the court mesh from `COURT` under one uniform root scale and record the scale you used in the slice notes. Do not resolve the conflict, and do not derive metres from `GAMEPLAY_RULES.md`.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/view/CourtMesh.gd`, `godot/src/view/CourtMesh.tscn` - court, net, glass and lines, built from the ported `COURT`
- `godot/src/view/BallView.gd`, `godot/src/view/PaddleView.gd`, `godot/src/view/PlayerRig.gd` - the ball with a visible bounce pulse, four paddles, one rigged body reused four times
- `godot/src/view/CameraRig.gd` - the match camera, starting from the `arena_spike` playable preset composition
- `godot/src/view/SimEventRouter.gd` - the only module that reads `Array[SimEvent]` and touches the view, the sound hooks, the shake and the feedback labels
- `godot/src/view/DebugHud.gd` - the shot-feedback label, the energy bar and the point log, minimum viable for this slice
- `godot/src/input/InputMap.gd` - the 22-field input struct filled from the gamepad and the keyboard, per `GAMEPLAY_RULES.md:152-180`
- `godot/src/input/frame_loop.gd` - input sampled once per rendered frame, one-shots cleared after the first sub-step, `MAX_SIM_STEPS` clamp, per `js/main.js:1196-1209`
- `godot/src/ui/MainMenu.gd` and `godot/src/ui/MainMenu.tscn` - entry, quick match, four AI tiers, exit
- `godot/scenes/QuickMatch.tscn` - the slice scene, one quick match, arena 0, athlete 0, one chosen AI tier
- `godot/shots/README.md` and the captures listed below
- `godot/tests/quick_match_slice.gd` and `godot/tests/quick_match_slice.tscn` - the headless slice run and the ported audits this slice covers
- `godot/tests/capture_slice.gd` - the capture harness that renders and writes the PNGs
- `docs/implementation/evidence/s2-*` - the evidence files listed below

Must not be touched by this slice: `js/` (any file), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by S1, this slice only calls it), `godot/prototypes/` (read only, the framing reference), and any file another writer holds. `godot/project.godot` is edited only to add the new scenes and the input map, and the 120 Hz physics tick and the `gl_compatibility` renderer stay as the harness ticket left them.

One writer per file at a time, per `PLAN.md`.

## Inputs and outputs

Inputs:

- The S1 sim core: `SimMatch.new(seed, "quick", athlete, arena, ai_profile)`, `SimMatch.step(TICK, input, input2)`, `SimMatch.snapshot()`, and the `SimEvent` list. This slice does not re-implement any rule.
- The tick: `TICK = 1.0 / 120.0`, cited to `js/main.js:1164`. The scene runs an accumulator with `MAX_SIM_STEPS = 8` and the clamp from `js/main.js:1196`, so a dropped frame changes how many sub-steps run and never the step size.
- The seed: an explicit integer chosen at match start and shown in the debug HUD. Two runs with the same seed and the same input script must produce the same point outcomes, and the HUD makes that checkable by hand.
- Input, sampled once per rendered frame: the 22 fields of `js/game.js:2712-2734`, filled from the pad and the keyboard. One-shot fields are cleared after the first sub-step of the frame. The keyboard is the fallback path and both must reach the same fields.
- Framing: the `godot/prototypes/arena_spike/` playable preset is the provisional composition. Changing it needs Luca, and the slice records which preset it used.
- Court scale: one uniform root scale applied to `COURT`, recorded in the slice notes, with the aspect question left open.

Outputs:

- A runnable scene `res://scenes/QuickMatch.tscn`, startable from `godot/scenes` or from a main menu, that plays one quick match to a decided result.
- `SimEvent` consumption in `SimEventRouter.gd`: serve, hit, special, point, victory, defeat, bounce, wall, net, the perfect grade and the shake request. Sound hooks are stubbed in this slice, because the audio route is S10 and is a separate ticket. Nothing in this slice plays a real sample and nothing claims audio parity.
- Shot feedback on screen: the grade and the intent label, with the CONTROLLO / BILANCIATO / POTENZA intent, matching `GAMEPLAY_RULES.md:148-149`. Text comes from message ids through the translation layer, never as a hardcoded string in a view script.
- A remaining-energy bar under the active player, per `GAMEPLAY_RULES.md:150`.
- A point log that names valid serve, valid glass, second bounce, double fault and defensive shot, per `GAMEPLAY_RULES.md:144-145`.
- Rendered captures, 1280x720, written under `godot/shots/`.
- A headless slice run that drives a full scripted point sequence through the sim with the view attached and exits 0 or 1 on the machine-readable contract.

Explicitly not output by this slice: nine arenas, more than one playable athlete, real audio, saves, Steam interfaces, tournament, drill, career, touch input, localized UI beyond the two feedback languages already in the data. Those belong to S3 through S13 and each needs its own ticket.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/drill-audit.mjs` is the precedent for how the slice run should be shaped: one engine, one real match state, no second physics path. The slice's headless run follows that shape.
- `scripts/reachability-audit.mjs` - every screen has a door and every door leads somewhere. The Godot equivalent is that the main menu reaches the quick match and the quick match can be exited back to the menu, asserted in a headless run rather than by reading files.
- `scripts/gamepad-nav-audit.mjs` - controller navigation. This slice's input map is where the port starts to satisfy it; the audit reads repository files and does not port literally, so the replacement is a headless assertion that every menu action is reachable from a named input action.
- `scripts/assets-audit.mjs` - every image named in code exists and no active asset is orphaned. The Godot equivalent is that every resource path referenced by the new scenes resolves at load, which the headless run proves by failing to load otherwise.
- `scripts/demo-audit.mjs` - the demo content rule. Not this slice's gate, named because the export preset will reuse it in S12.
- `scripts/court-speed-audit.mjs`, `scripts/wall-rules-audit.mjs`, `scripts/shot-quality-audit.mjs` - already gated by S1 through the shared sim. This slice adds no physics and must not make them fail. Run the full web suite after the slice to confirm the web build is untouched.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` do not port. The replacement is a headless run that loads the project, instantiates every new scene and script, and reports zero script errors.

Godot-side equivalents, keeping the original file name stem:

- `godot/tests/quick_match_slice.gd` - plays a scripted quick match headless with the view attached, asserts the match reaches a decided result, asserts the four AI tiers are selectable, asserts the event list contains a serve, a bounce and a point, and prints one `ok`/`FAIL` line per check ending in `PASS n/n`.
- `godot/tests/reachability_audit.gd` - the ported reachability check, added when this slice introduces the second screen.
- `godot/tests/capture_slice.gd` - renders the slice and writes the captures. Runs under software GL (`llvmpipe`, no GPU on this host). The captures are valid for correctness, invalid for any frame-rate or target-hardware claim.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). `--headless` alone is enough. `timeout` is the bound, not `--quit-after`, because a runtime error that aborts `_ready()` hangs the loop instead of going red, and `--quit-after` exits 0 on an aborted run.

Headless slice run:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/quick_match_slice.tscn > docs/implementation/evidence/s2-slice-headless.log 2>&1; \
  echo "exit=$?"; grep -E '^(PASS|FAIL)' docs/implementation/evidence/s2-slice-headless.log
```

Rendered capture under software GL:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ \
    res://tests/capture_slice.tscn -- --shot=menu,quickmatch-serve,rally,point \
    > docs/implementation/evidence/s2-capture.log 2>&1; \
  echo "exit=$?"
```

Harness smoke, to prove the project still loads clean:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/; \
  echo "exit=$?"
```

Web baseline, unchanged and re-run only to prove nothing under `js/` or `scripts/` was touched:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s2-web-baseline.log 2>&1; echo "exit=$?"
```

Manual play, for the human verdict:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ \
    res://scenes/QuickMatch.tscn
```

## Expected evidence

- `docs/implementation/evidence/s2-slice-headless.log` - the headless slice run, exit code plus the `PASS`/`FAIL` summary line.
- `docs/implementation/evidence/s2-capture.log` - the capture run, exit code, and the list of PNG paths written.
- `godot/shots/menu.png`, `godot/shots/quickmatch-serve.png`, `godot/shots/rally.png`, `godot/shots/point.png` - 1280x720 captures of the two screens and two match moments.
- `godot/shots/README.md` - which preset and which uniform court scale each capture used, and the note that the captures come from software GL.
- `docs/implementation/evidence/s2-web-baseline.log` - the web suite, to show the web build at `2979588` is untouched.
- `docs/implementation/evidence/s2-slice-notes.md` - the court scale used, the seed used, the AI tier used, the framing preset used, the list of `SimEvent` types consumed, and the list of what is stubbed (sound, particles beyond the ball pulse, full HUD).

What does not count as proof: a screenshot alone without its capture log and exit code, a headless run with no seed recorded, a claim of parity for audio or the HUD when both are stubbed, and any frame-rate claim, because this host has no GPU.

## Failure and recovery criteria

Red means any of these:

- The headless slice run fails, or hangs and `timeout` kills it (exit 124). A hang is a red.
- The project loads with a script error, or a new scene or script fails to instantiate.
- The slice re-implements a physics or scoring rule instead of calling the S1 sim. Any second physics path is a red, by the same argument `drill-audit.mjs` makes for the web build.
- Input is sampled per physics tick instead of once per rendered frame, or a one-shot field survives into a second sub-step. That reproduces the double-shot bug the comment at `js/main.js:1204-1206` records.
- The slice changes any frozen constant, including `COURT`, `BALANCE`, `SERVICE_LINE_OFFSET`, `WIN_SCORE`, `MATCH_FORMATS`, athlete stats, AI `skill` / `speed` / `power` or arena `wallBounce`. Re-tune and revert before anything else.
- A file outside the allowlist changes, or `js/` or `scripts/` changes at all.
- The court mesh resolves the aspect question instead of recording the scale it used.

What stops the slice: a red headless run after the retry rule below, or a framing or UI verdict from Luca that rejects the provisional composition, in which case the slice is re-scoped rather than patched around. It also stops if S1 has not landed its sim core, because there is nothing to drive.

Retry rule: two attempts per gate, then record a blocker with the failing gate, the log line and the two attempts, per `docs/mission/CHARTER.md`. No identical third retry. Continue unrelated unblocked work.

Recovery paths worth trying before declaring a blocker: confirm the scene instantiates the sim core rather than copying it; confirm the accumulator clamp and `MAX_SIM_STEPS` match `js/main.js:1196-1205`; confirm the ball position is read from `snapshot()` and not cached across a tick; confirm the capture run uses `xvfb-run` because the working example under `godot/prototypes/` needs a rendering context.

Done verdict, stated plainly. This slice can be built, run and evidenced now. It cannot be called complete. The `done` verdict on S2 depends on two human verdicts that remain open, both owned by Luca: the framing and feel verdict from `camera-and-feel-spike` and the UI approach verdict from `ui-port-approach`. Until both land, and until the parity gate definition behind S1 lands, the correct status for this slice is built, evidenced, pending human verdicts. No agent may record it as complete, and `PLAN.md` itself says the same.
