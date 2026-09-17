# Court width: the owner wants it slightly wider

- Status: resolved
- Type: prototype
- Mode: HITL
- Owner: crew-courtwidth
- Blocked by: none

The owner's verdict, 2026-09-17, after the real 10 × 20 m court landed:
*"allarghiamo leggermente le misure dell'arena orizzontalmente. Di poco proprio visto
che quelle attuali sono realistiche per un campo da padel ma non mi piace la resa
grafica"*. The realism is accepted as correct; the **render** is what he is rejecting.

## Objective

Widen the court's horizontal measure by a small amount and show him the candidates, so
the amount is his decision and not the lane's. Deliver **three captured frames at three
candidate widths**, each labelled with its value, plus the measurement table, and keep
the choice open until he picks one.

This is a **projection** change, not a simulation change: the frozen simulation works in
pixels (`js/game.js` semantics), and `court.gd` maps those pixels to metres. Widening
changes the metres-per-pixel on x only. The parity digests must not move — that is the
proof this is presentation.

## Existing source anchors

| what | where | note |
|---|---|---|
| the horizontal measure | `godot/game/court.gd`: `WIDTH_M := 10.0`, `world_pos`, `court_len()` | the single parameter to move; `court_depth()`/`LENGTH_M := 20.0` stay |
| the depth curve | same file: the monotone C1 curve through net / service line 6.95 m / back glass | must survive untouched in form: continuity, service boundary at exactly 6.95 m, monotone over 1,100 samples |
| the walls and lines | `godot/game/arenas/court_builder.gd` | they derive from the court helpers; if any hard-codes 10 m, name it |
| the venue and the backdrop | `godot/game/arenas/arena_scenery.gd` (`BACKDROP_Z`) | a wider court may need the hall to follow, by a reported amount |
| the camera presets | `godot/game/court.gd` | chosen for the 10 m court; a minimal, **reported** adjustment is allowed to keep the court framed |
| the dimensions test | `godot/tests/court_dimensions_test.gd` (written by another session) | its expectations move with the chosen width **in the same change**; the C1, service-line and monotonicity checks stay exactly as they are |

## File ownership / allowlist

- `godot/game/court.gd`, `godot/game/arenas/court_builder.gd`, `godot/game/arenas/arena_scenery.gd` (yours)
- `godot/tests/court_dimensions_test.gd` (yours, for the expected width only)
- `docs/wayfinder/evidence/court-width-render.md` (new, yours)
- `godot/game/out/width-<value>.png` — your candidate frames, named by their width
- **Not yours right now**: `godot/game/match_controller.gd`, `godot/game/hud.gd`,
  `godot/tests/game_slice_test.gd`, `godot/src/sim/**`, `docs/mission/**`,
  `docs/wayfinder/map.md`. Another lane is editing the first three this minute.

## Inputs and outputs

In: the pixel court geometry (unchanged), the camera presets, the current captures as
the "before".
Out: three candidate widths implemented one at a time, one frame each, a measurement
table, and a recommended default for the owner to accept or overrule.

## Tests

- `godot/tests/court_dimensions_test.gd`: PASS, with the expected width parameterised to
  the candidate under test; every other check unchanged.
- `godot/tests/game_slice_test.gd`: the count must **not** change (no new checks); the
  only red stays `padel.pck`.
- The parity digest: one scenario re-run, digest unchanged (the simulation is not
  touched).

## Execution commands

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916
$GODOT --headless --path godot/ --script res://tests/court_dimensions_test.gd
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd
python3 godot/game/tools/inspect_png.py godot/game/out/width-11.0.png --region=court@x,y,w,h
```

One whole-match capture takes ~3 minutes; for a candidate sweep write a throwaway
`SceneTree` probe that renders one frame (~10 s) and delete it after. **Copy every
candidate frame to its own name the moment it is rendered**: another lane is capturing
into the same `godot/game/out/` directory right now and will overwrite `rally.png`.
`flock`/`timeout` do not exist on macOS; `pgrep -f Godot` before starting a heavy run.

## Expected evidence

`court-width-render.md`: the three candidates in metres and as a percentage of 10 m, one
frame each with the court's measured width in pixels in the frame, the camera
adjustment if any (with numbers), the **ball's and the athletes' apparent size relative
to the court** before/after (`Court.BALL_R = 0.10 m` is a fixed world size, so widening
makes the ball look smaller relative to the court — measure it and report it; do **not**
silently rescale the ball), the test counts, and the parity digest.

## Failure and recovery criteria

Two attempts, then a blocker with the frame. If a candidate pushes the court out of the
default framing, say so and show it rather than quietly widening the field of view — the
framing is part of what the owner is judging.
