# The stands: put the owner's bleachers model in the arena

- Status: open
- Type: prototype
- Mode: HITL
- Owner: crew-bleachers
- Blocked by: none

The owner: *"ok, aggiungi gli spalti, ho il modello 3d"* — with
`~/Downloads/Meshy_AI_Blue_Canopy_Bleachers_0917000231_texture.glb`. The model is
his; **where and how big** it reads is his verdict, so deliver frames, not a decision.

Progress 2026-09-17: the evidence file `docs/wayfinder/evidence/arena-bleachers.md`
now exists (shipped-config cost measured); the owner's look verdict and the missing
`bleachers.meshy-task.json` remain outstanding, so this ticket stays open.

## Objective

Place the bleachers in the arena scene so they read as real tribunes around a padel
court, and **measure what they cost**: triangles in the scene, frame time before and
after, and the on-screen size of one unit. Deliver frames from the default camera. The
placement (side lines, behind the back wall, both) is a proposal to be overruled.

## Existing source anchors

Measured off the GLB itself, in this session, not assumed:

| fact | value |
|---|---|
| triangles / vertices | **459,928** / 271,287 (one mesh, one node, no skins, no animations) |
| file size | 31.1 MB, 3 JPEG textures, glTF 2.0 |
| bounding box (mesh-local) | x 1.903 m × y 0.957 m × z 0.961 m |
| `min_y` | **−0.4868** — the unit sits half a metre below its own origin |

For scale: the rigged athletes are 15–30 k triangles by the studio's own BRIEF, and the
tracked athlete GLBs in this repo are 8–23 MB each (`godot/assets/athletes/*.glb`).
So one copy of this model is **≈15× the triangle budget of an athlete**.

| where it goes | file:line | note |
|---|---|---|
| the scenery root, backdrop at z = −12 | `godot/game/arenas/arena_scenery.gd:49` (`BACKDROP_Z`), `:78` (root), `:80` (`band()`) | the props container is built below `:100`; read the file before choosing the anchor point |
| the world/hall builder | `godot/game/arenas/court_builder.gd:187` (`build_world`), `:68` (`box`), `:228` (the 80 × 80 m bed) | room exists: the floor is 80 m square |
| the court's own measures | `godot/game/court.gd` — `WIDTH_M = 11.0`, `court_len()`, `court_depth()` | today's width is 11 m, the owner's pick from this session |
| where runtime assets live, and what is tracked | `godot/assets/**` — **tracked** (50 files, 111 MB today) | the game loads `res://assets/…`; the athlete rigs load over 12 `glb_loads` at match start |

`art/generated/**` is the *generation* workspace and is **not tracked**; this model is a
runtime asset, so it belongs under `godot/assets/` or Luca's checkout will not have it.

## File ownership / allowlist

- `godot/assets/bleachers/**` (new): the `.glb`, its `.import`, a `bleachers.meshy-task.json`
  recording `{name, taskId, status, consumedCredits, source}` per the repo's asset
  convention, and the untouched original left where it is — **copy, never move or delete**
  `/Users/alessiofantini/Downloads/Meshy_AI_Blue_Canopy_Bleachers_0917000231_texture.glb`.
- `godot/game/arenas/arena_scenery.gd` and/or a new `godot/game/arenas/bleachers.gd` —
  whichever keeps the scenery file readable; say which you chose and why.
- `docs/wayfinder/evidence/arena-bleachers.md` (new, yours).
- `godot/game/out/bleachers-*.png` — your frames.
- Not yours: `godot/game/match_controller.gd`, `hud.gd`, `godot/tests/game_slice_test.gd`,
  `godot/src/sim/**`, `docs/mission/**`, `docs/wayfinder/map.md`, `godot/game/court.gd`.

## Inputs and outputs

In: the GLB above; the arena presets (`arena_style.gd`); the default camera.
Out: a placed, scaled, lit bleachers group in the scene; a frame that shows it; the cost
table. The unit is **1.9 m long as authored**, so make the scaling decision explicit:
one unit scaled to tribune size (fewer triangles, stretched texels) versus several
unscaled units along a side (truer texels, triangles × copies). Measure both if you can
afford one extra run, and say which you would ship.

## Tests

- `godot/tests/game_slice_test.gd`: 325/326 with `padel.pck` the only red — the count must
  not change, and **no probe may be left in an exporter-excluded tree** (a `.gd` under
  `game/out/` turns that suite red; probes belong in `godot/game/tools/`).
- Import: the GLB's `.import` must be generated (the editor is open on this Mac and will
  do it; headless runs can use `--headless --import`), and a match launched with
  `models=true` must show the added `glb_loads` count and **zero `SCRIPT ERROR`**.

## Execution commands

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path godot/ --import
$GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd
```

Iterate with a throwaway single-frame probe in `godot/game/tools/` (~10 s per frame) and
delete it before returning. `flock`/`timeout` do not exist on macOS. A second lane may be
capturing into `godot/game/out/` — copy your frames to their `bleachers-*.png` names the
moment they render.

## Expected evidence

`arena-bleachers.md`: the asset's own numbers (triangles, size, textures) **as loaded by
Godot**, not as parsed from the file; the placement in metres with the anchors it derives
from; the on-screen height of one unit in the frame (measured with
`python3 godot/game/tools/inspect_png.py`); the **frame time before and after** with the
same seed and camera (state the method: engine-reported frame time, several hundred
ticks, mean and worst); the slice's before/after counts; `glb_loads` and the boot log
lines; and a "what this does NOT prove" section.

## Failure and recovery criteria

Two attempts, then a blocker with the frame. **If the triangle count or the frame time
makes the scene worse to play** — a stutter the owner would feel — say so with the
numbers and propose the alternatives instead of shipping it: a Meshy remesh from the same
task (it spends the account's credits, so it is the owner's call, and the completed task
id can be carried forward as `input_task_id`), fewer instances, or a simpler stand built
from boxes in the arena's own style. A dropped frame rate is a finding, not a failure to
hide; the look is his, the cost has to be disclosed.
