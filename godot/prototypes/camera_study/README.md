# camera_study — the artifact the camera/feel decision is taken ON, not BY

This folder renders one labelled frame per camera/HUD option, from the real game,
and measures the differences in pixels. **It takes no decision.** The camera and the
feel of this port are an open owner gate (`docs/wayfinder/tickets/camera-and-feel-spike.md`);
what is missing is not an opinion, it is something cheap to look at and cheap to
reverse. That is this.

## How to reproduce

```bash
# one resolution per engine process, both under the shared lock
./godot/prototypes/camera_study/render.sh 1280x720 rig
./godot/prototypes/camera_study/render.sh 1152x648 rig
# offline; no engine
python3 godot/prototypes/camera_study/measure.py 1280x720
python3 godot/prototypes/camera_study/measure.py 1152x648
```

`render.sh` is the only thing that starts an engine, and it always does so as
`flock -w 900 /tmp/padel-godot.lock timeout 900 … xvfb-run … --rendering-driver opengl3`.
Software GL (Mesa llvmpipe). **These frames are composition evidence only — nothing
here is a frame-rate measurement, and none of it can become one on this host.**

## What it does

`camera_study.gd` instantiates the real `res://game/match_controller.gd` — the real
arena, court, glass, net, HUD, simulation and scripted player — turns its engine
clock off, and steps it to the game's own `rally.png` predicate
(`rallyHits >= 3 and ball.z < 140`, `match_controller.gd:_capture_plan`). Every
option then renders that **same frozen tick**, so the only difference between two
images is the option. The first option is the shipping camera and the shipping HUD,
untouched: it is the game's composition, produced by the game's code, not an
approximation of it.

Bodies come from the shipping spawn seam `res://src/character/athlete_spawn.gd`
(`bodies=rig`, four rigs, idle). The controller's own positioning is untouched — the
rig is parented under the controller's athlete root and the plain GLB body is hidden.

Two images per option:

| file | what it is |
|---|---|
| `<option>__<W>x<H>.png` | the frame as a player would see it, HUD on |
| `<option>__<W>x<H>__mask.png` | ID pass: one exact unshaded RGB per athlete/ball/court bed, everything else hidden. This is what gets counted. |
| `<option>__<W>x<H>.json` | the engine's own numbers: camera, HUD panel rects, projected feet/head/ball/court points, the frozen tick |

`measure.py` runs no engine. It counts the ID pass, intersects those pixels with the
HUD rectangles the engine reported for that exact frame, and writes
`measure__<W>x<H>.{json,md}`, both contact sheets and `inventory.md`.

## Honest limits of the measurement

- The mask pass **hides the glass cage**, so a body standing behind a translucent
  pane counts as fully visible. In the beauty frame it is dimmed. Glass readability
  is not measured here.
- HUD rectangles are used as plain rectangles; the panels' 8 px rounded corners are
  ignored, which slightly over-states how much a panel hides.
- `court quad in frame %` is meaningless for a low camera (the near corners project
  thousands of pixels off-screen). `court surface in frame %` — a 41×27 grid of
  points on the floor — is the one to read across all options. Both are printed.
- One frozen tick. Where the players stand is where the sim put them at tick 420 of
  seed 20260916, tier 3. The `near-baseline` solve exists precisely because a
  conclusion drawn from one tick's player positions would not survive the next tick.

## `out/attempt1-reposition/`

The first slim-band attempt, kept deliberately. It shrank the panel boxes and moved
the feedback panel to the bottom-right corner; that bought the near player back and
buried the near partner instead (−987 readable px on them), because a panel's
rectangle is the larger of its offsets and its content's minimum size. Recorded so
the second version's reasoning is checkable.
