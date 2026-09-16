# 3D camera and feel integration into the slice (slice S5)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Quick-match vertical slice in 3D](quick-match-slice.md) technically. The done verdict is blocked by [Camera and feel spike](../../wayfinder/tickets/camera-and-feel-spike.md) (open, HITL, owner Luca) — the spike's verdict on framing and feel is the acceptance for this slice, and no camera or art direction is locked before it. The build may start now; the slice may not be called complete.

This ticket implements row S5 of `docs/implementation/PLAN.md` ("3D camera and feel integration into the slice"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S6 through S13.

## Objective

Replace the provisional composition the quick-match slice stands on with a tuned, integrated 3D camera that a human can play behind, and prove the tuning is real by rendered captures and a headless camera contract — not by adjectives. Two things are being integrated, and the ticket keeps them apart:

1. **The camera**, as a node rig with named, inspectable parameters (height, pitch, distance, follow mode, shake response), started from the `arena_spike` playable preset that `PLAN.md` holds as the provisional composition, and tunable without recompiling anything.
2. **The feel contract around it** — what the camera does at a serve, during a rally, at a bounce, on a special, and on a point — expressed as camera behaviour driven by the simulation's event ids, so a human verdict can be attached to specific frames rather than to "the whole thing".

The spike's own finding is the reason both matter: the web build's default match camera is a fabricated trapezoid (`js/render.js:740-745`), and a pinhole camera at 16:9 cannot reproduce it exactly — `sin(pitch)` would have to exceed 1. The best fit that pins the player's baseline sits about 14.46 m up at about 65.2 degrees of pitch. Framing parity with today's build and a playable 3D camera are therefore **different compositions**, and Luca's verdict is taken on both. This slice builds both presets, makes switching between them a parameter, and stops for the verdict.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/render.js:740-745` | The web projection: `point(x, y)` builds the pseudo-3D trapezoid, with `depth = v <= 0.5 ? v * 0.88 : 0.44 + (v - 0.5) * 1.12` along the near/far baselines. This is the composition the first 3D build must reproduce, and it is the proof that the web view is not a pinhole camera |
| `js/render.js:738-739` | `bottomLeft = { x: 48, y: canvas.height - 13 }` and `bottomRight = { x: 912, y: canvas.height - 13 }` — the near-baseline extents the trapezoid uses |
| `js/render.js:910` | `ctx.__padelProject = point` — the projection is stored and reused for everything drawn after the court, so every sprite in the web build is projected through the same warped map |
| `js/render.js:1139` | The paddle is drawn through `ctx.__padelProject`, with a `scale` factor. A 3D camera that keeps depth cueing but drops the `scale` warp changes how readable near/far is, and the verdict must see that |
| `js/render.js:1361-1370` | The ball is drawn through the same projection, with `airborneY = projected.y - (ball.z ?? 0) * projected.scale` — the web build makes height legible by displacing screen-y by z times the local scale |
| `js/render.js:4-6` | `clamp(value, min, max)`, the only pure helper the simulation borrows from the renderer |
| `js/render.js:56-67` | `predictLanding(ball)`, the renderer's landing prediction, separate from the simulation's `playableEta` |
| `GAMEPLAY_RULES.md:47-65` | Ball and shot readability in design prose: a standard shot uses a moderate horizontal speed and a readable parabola; height buys margin and time, not free power; the lob's depth is real; the smash has a precise window. This is the contract the camera has to make visible |
| `GAMEPLAY_RULES.md:142-150` | "L'animazione della palla deve rendere evidente altezza e punto di rimbalzo" — the ball animation must make height and bounce point obvious, which in the web build is the z-times-scale displacement above |
| `GAMEPLAY_RULES.md:182-188` | Acceptance criteria: the player can predict where the ball will arrive and has time to move. That is the human check this slice is judged on |
| `js/game.js:1973` | `state.fx.shake = Math.max(state.fx.shake ?? 0, 1.1)` — the simulation writes a camera-shake field on a special. Whether this is a simulation event or a view concern is explicitly open in the boundary work; this slice must not silently pick a side, and it records which side it took while the question stays open |
| `js/fx.js:60-63` | `updateFx(state, dt)` and the reduced-motion shake cap `Math.min(fx.shake ?? 0, 0.5)`. The reduced-motion rule is presentation-side and the camera rig is where it lands |
| `godot/prototypes/arena_spike/arena_spike.gd`, `Main.tscn`, `project.godot`, `render.sh` | The playable preset framing this slice starts from, and the working capture route |
| `godot/prototypes/arena_spike/arena_playable_1280x720.png`, `arena_default_1280x720.png`, `arena_wide_1280x720.png` and their `.log` files | The three real 1280x720 renders, with `ARENA_PASS` in each log — the pair the verdict should be taken on is `default` versus `playable` |
| `godot/prototypes/arena_spike/assets/volpe-rigged.glb` | The one rigged body available, a static base pose. No idle clip exists anywhere, and this slice must not claim one |
| `godot/prototypes/render_probe/` | The software GL render probe, proof that a capture is possible on this host without a GPU |
| `docs/wayfinder/evidence/camera-spike-render.md` | The spike's measured numbers: the best-fit pitch, the 14.46 m height, the 65.2 degree pitch, the measured 1.678 m athlete height, the fact that no idle clip is claimed, and the list of what the spike does not contain |
| `godot/src/view/CameraRig.gd` | Built by [Quick-match vertical slice in 3D](quick-match-slice.md), started from the `arena_spike` playable preset. This ticket takes ownership at handoff and is afterwards its only writer |
| `godot/src/view/SimEventRouter.gd` | The single module that reads the simulation's event list and touches the view; camera response is one of its consumers. Owned by the quick-match slice; this ticket reads the event ids it publishes |

The seam this slice sits next to: `godot/src/locale/**` owns every string, `godot/src/audio/**` owns every sound, and `godot/src/input/**` owns the framed input. This ticket touches none of them; camera tuning is exposed as parameters, not as UI strings.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/view/camera/CameraPresets.gd` — the named presets as data: at minimum `framing_parity` (the best-fit pinhole approximation of the web trapezoid) and `playable` (the `arena_spike` playable composition), each a plain dictionary of height, pitch, distance, fov, target offset and follow mode, so a preset is a number change and not a code change
- `godot/src/view/camera/CameraFeel.gd` — the behaviour layer: serve framing, rally follow, bounce emphasis, special shake, point framing, and the reduced-motion cap. It reads simulation event ids and never simulates
- `godot/src/view/camera/CameraShake.gd` — the shake application and its reduced-motion limit, ported from the `js/fx.js:60-63` behaviour
- `godot/src/view/camera/ball_readability.gd` — the depth-cue helper that makes height and bounce point legible in 3D, replacing the web build's `z * projected.scale` displacement (`js/render.js:1361-1370`)
- `godot/scenes/CameraTune.tscn` and `godot/scenes/CameraTune.gd` — a tuning scene: the match with the camera parameters exposed as sliders, so a human tune session produces a named preset rather than an edit
- `godot/tests/camera_feel_audit.gd` and `godot/tests/camera_feel_audit.tscn` — the camera contract, headless
- `godot/tests/capture_camera.gd` — the capture harness for the preset comparison
- `godot/shots/camera-framing-parity.png`, `godot/shots/camera-playable.png`, `godot/shots/camera-serve.png`, `godot/shots/camera-bounce.png` and an append to `godot/shots/README.md`
- `docs/implementation/evidence/s5-*` — the evidence files listed below

Files taken over at handoff from [Quick-match vertical slice in 3D](quick-match-slice.md): `godot/src/view/CameraRig.gd` and the camera node inside `godot/scenes/QuickMatch.tscn`. The handoff is explicit; after it, this ticket is the only writer of the camera files.

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md)), `godot/src/ui/` (owned by [Hud and menu in Godot Control nodes](hud-and-menu.md)), `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/input/`, `godot/prototypes/` (read-only: the `arena_spike` preset is a reference, and the prototype project is not this slice's to edit), and `godot/src/view/CourtMesh.gd` — a camera change that needs a different court mesh is an arena question, not a camera one.

## Inputs and outputs

Inputs:

- The match state and its event ids, through the view seam the quick-match slice publishes. The camera never reads simulation internals and never steps the simulation.
- The current preset, named, from `CameraPresets.gd`. Default is a verdict-free choice made explicit in `s5-camera-notes.md`: `playable` for gameplay, `framing_parity` for the comparison captures.
- The reduced-motion setting, read at the effects layer. The simulation's reduced-motion behaviour is already stripped (the port takes the "no reduced motion" side in `godot/src/sim/sim.gd`), so the camera is the only consumer.
- The `arena_spike` playable preset numbers, read from that prototype's scene and script, carried over verbatim as the starting preset.

Outputs:

- A camera that, at any time, reports which preset it is in and what its five parameters are — printed, not implied, so a capture is attributable to a preset.
- Two preset captures of the same frozen match moment, so a human compares framing parity against playable on identical frames.
- Behaviour frames: the serve, a bounce, and a point, each captured.
- A headless camera contract that asserts the camera node exists, a preset applies, the parameters are the preset's numbers, shake decays to zero, reduced motion caps shake, and the camera never leaves the court's vertical envelope.
- A tuning scene, so a verdict becomes a preset rather than a conversation.

Explicitly not output: nine arenas (that is [Nine arenas in 3D](nine-arenas.md)), athlete models beyond the one existing rig, any idle clip — none exists, per the confirmed direction — and any frame-rate claim. The host renders through software GL with no GPU, which makes every capture valid for correctness and invalid for performance.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/court-speed-audit.mjs` — the readable-window promise the camera must make visible. This slice does not re-run it as a gate, but a camera that makes the ball unreadable at a speed the audit calls readable is a contradiction and is recorded as a framing finding.
- `scripts/arena-scenery-audit.mjs` — the web build's screen-space scenery clip (`:9-21`). That audit is screen-space and does not port to 3D; its replacement is the arena slice's, and this slice names the seam rather than claiming it.
- There is no web audit for camera or feel. The human verdict is the acceptance, and the tests below are the machine half that keeps the verdict about feel instead of about bugs.

Godot-side equivalents:

- `godot/tests/camera_feel_audit.gd` — asserts, headless: the rig loads with a named preset; each preset's applied parameters equal its declared numbers; the camera stays above the court plane and inside a stated vertical envelope across a scripted match; shake rises on the special event id and decays to exactly zero; the reduced-motion setting caps shake to the declared limit; and the ball's on-screen y displacement grows monotonically with `ball.z` — the ported form of the web build's `airborneY` behaviour. Prints `ok`/`FAIL` per check and `PASS n/n`.
- `godot/tests/capture_camera.gd` — freezes the same match moment for both presets and writes the captures, so the comparison is like-for-like.

The contract the captures carry: each capture's log records the preset name, the five parameter values, the tick number of the frozen moment, the seed and the software-GL note. A capture without those is a picture, not evidence.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). A capture needs a real rendering context: `--headless` installs the dummy driver and the viewport capture is blank, so the render route is `xvfb-run` plus an explicit rendering driver — exactly what the prototype render scripts proved. Godot is the heavy process on this host: every invocation is wrapped in the shared lock.

Headless camera contract:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/camera_feel_audit.tscn > docs/implementation/evidence/s5-camera-feel.log 2>&1; \
  echo "exit=$?"; grep -E '^(ok |FAIL|PASS)' docs/implementation/evidence/s5-camera-feel.log
```

Preset comparison captures, both presets on the same frozen moment:

```sh
cd /root/projects/steam-circuit-padel-pro && for p in framing_parity playable; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/capture_camera.tscn -- --preset=${p} --tick=600 --seed=12345 \
    >> docs/implementation/evidence/s5-capture.log 2>&1; \
  echo "$p exit=$?"; \
done
```

Behaviour frames:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/capture_camera.tscn -- --shot=serve,bounce,point \
    >> docs/implementation/evidence/s5-capture.log 2>&1; echo "exit=$?"
```

The prototype route this slice reuses, run once as the provenance check that the route still works:

```sh
cd /root/projects/steam-circuit-padel-pro/godot/prototypes/arena_spike && \
  flock -w 900 /tmp/padel-godot.lock ./render.sh 1280x720 2>&1 | tail -5
```

Manual tuning and the human verdict, with a real window:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ \
    res://scenes/CameraTune.tscn
```

## Expected evidence

- `docs/implementation/evidence/s5-camera-feel.log` — the headless camera contract, exit code and `PASS n/n`, with every check named.
- `docs/implementation/evidence/s5-capture.log` — the capture runs, exit codes, and for every capture the preset name, the five parameter values, the frozen tick, the seed and the rendering driver.
- `godot/shots/camera-framing-parity.png` and `godot/shots/camera-playable.png` — the same moment through the two presets, 1280x720, the pair the verdict is taken on.
- `godot/shots/camera-serve.png`, `godot/shots/camera-bounce.png`, `godot/shots/camera-point.png` — the behaviour frames.
- `godot/shots/README.md` — appended: which preset each camera capture used, the parameter values, and the software-GL caveat.
- `docs/implementation/evidence/s5-camera-notes.md` — the parameter table per preset, the measured best-fit numbers carried from the spike evidence and how far the `framing_parity` preset lands from the web trapezoid, the reduced-motion limit, the decision taken about `state.fx.shake` (`js/game.js:1973`) with the open question marked open, and the explicit statement that no frame-rate claim is made on this host.
- `docs/implementation/evidence/s5-verdict-request.md` — the one-page request for Luca: the two captures, the tuning scene command, and the specific questions (does the framing hold; is the ball readable; does the follow feel right), so the verdict closes [Camera and feel spike](../../wayfinder/tickets/camera-and-feel-spike.md) explicitly.

What does not count as proof: a capture without its preset and parameter log; a camera claim supported only by a screenshot at one resolution; any statement about feel, framing approval or frame rate, all three of which are Luca's or the hardware's and not this host's.

## Failure and recovery criteria

Red means any of these:

- The headless camera audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- A capture run exits non-zero, or writes a blank frame because the run went through the dummy driver instead of `xvfb-run` with a rendering driver.
- A preset's applied parameters differ from its declared numbers, or the camera silently changes composition between two runs of the same preset and the same seed.
- The camera rig re-implements a simulation rule, reads simulation internals directly, or steps the simulation.
- The slice claims an idle clip or any animation the rig does not have. The rig is a single base pose and the confirmed direction says locomotion clips are Meshy's and padel strokes are authored in Godot; neither is this slice's to invent.
- The slice locks a framing verdict, or presents the provisional preset as approved.
- A file outside the allowlist changes, or `js/` or `scripts/` changes at all.
- A frame-rate or target-hardware claim appears anywhere in the evidence.

What stops the slice: a red audit after the retry rule below; or a verdict from Luca that rejects both compositions, in which case the slice is re-scoped around the verdict rather than patched toward a third unrequested preset.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the capture run passed `--rendering-driver opengl3` under `xvfb-run` rather than `--headless`; confirm the frozen tick is the same for both presets so the comparison is like-for-like; confirm the audit's vertical envelope is measured in the court's own units and not in metres, since the court scale is still an open question; confirm shake decay is asserted to zero and not to a small epsilon chosen after the fact.

## Human gates that block this slice (open, owner Luca)

- **Camera and feel** — the acceptance itself. This slice produces the two compositions, the behaviour frames and the tuning scene; Luca plays them and says whether the framing and the feel hold in 3D. Until that verdict lands, no camera or art direction is locked and no completion is claimed. The recommended default in `PLAN.md` — keep the `arena_spike` playable preset as the provisional composition — is provisional only.
- **Court aspect** — the court is 800 x 508 px = 1.575, not 20:10, and the px-to-metre scale is undecided. Camera distance and height read differently under a different scale, so this slice states the scale it tuned under and does not resolve the conflict. Determinism is unaffected either way, which keeps the camera work independent of the parity gate.
