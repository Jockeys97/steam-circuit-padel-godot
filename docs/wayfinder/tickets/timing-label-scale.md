# Timing labels are too big — match the reference's proportion

- Status: resolved
- Type: task
- Mode: AFK
- Owner: crew-labelscale
- Blocked by: none

The owner's verdict on the first delivered sizes, with a screenshot in hand:
*"le scritte qui sono troppo grandi"*. This ticket is the sizing half of
`timing-presentation-3d.md`; the elements themselves are delivered and measured.

## Objective

Bring the on-field timing texts back to the reference's own proportion, and make their
**screen** size independent of the window — the reference draws fixed pixels on a fixed
canvas, while a world-anchored `Label3D` grows with the window, which is why the same
constant looks bigger on the owner's machine than in a 1280×720 capture.

## Existing source anchors

| element | reference | the port today |
|---|---|---|
| advice word | `js/render.js:1730-1750`: `800 ${11 * scale}px`, upper-case, in a `measureText + 22` by **20 px** rounded box (radius 6, fill `rgba(4,14,32,0.82)`, stroke `rgba(126,243,255,0.5)`) at `p.y - 132*scale` | `TIMING_ADVICE_PX = 15`, `TIMING_ADVICE_BOX_LINES = 20/11`, `TIMING_ADVICE_PAD_LINES = 22/11` (`match_controller.gd:168-185`) |
| verdict | `js/render.js:1059-1068`: `700 14px` — **fixed, not scaled** — with a 5 px dark stroke, rising by `(0.78 - life) * 18`, and the mode line at `600 9px`, 15 px below | `TIMING_VERDICT_PX = 19`, `TIMING_VERDICT_MODE_PX = 12`, outline 7 |
| the conversion the port already uses | the ring sits at `p.y - 96*scale` (`js/render.js:1657`) and the port maps that to `TIMING_RING_HEIGHT = 1.60 m` ⇒ the reference reads **60 px/m** | the port's own frame measured **36 px/m** at 1280×720 (`TIMING_PX_PER_M = 36`) |

Consequence, in metres of world height (what a `Label3D` actually needs, because
`font_size * pixel_size` is a world size):

- advice `11/60 = 0.183 m` → **≈6.6 px** at 1280×720;
- verdict `14/60 = 0.233 m` → ≈8.4 px; mode `9/60 = 0.150 m`;
- box `20/60 = 0.333 m` tall, padding `22/60 m` wide.

The delivered values are roughly **twice** those proportions. The lane's own first pass
was the faithful one (~7 px) and was enlarged because it looked illegible in a
1280×720 capture — recorded, not blamed: the enlargement is the thing the owner has
now rejected.

## File ownership / allowlist

- `godot/game/match_controller.gd` (yours)
- `docs/wayfinder/evidence/timing-presentation-3d.md` — **update** it: keep the existing
  measurement table, add a before/after section with the new numbers; do not delete the
  old ones.
- `godot/game/out/{timing,timing-off,hud,hud-off,probe-*}.png` (regenerate)
- The existing slice section `_timing_presentation` only — do not add a section.
- Nothing else. `godot/src/sim/**` untouched.

## Inputs and outputs

In: `state.shotRead`, `state.shotFeedback`, the live window size, the camera.
Out: labels whose on-screen height holds the reference's proportion (advice ≈ `11/96`
of the athlete's on-screen height) at **any** window size, plus fresh frames and their
measurements.

## Tests

`_timing_presentation` keeps passing and gains **one** check: at a stated window size the
advice's measured on-screen height is within a stated tolerance of the reference's
proportion. One check, not a new section — the count must move by exactly one.

## Execution commands

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916      # ~3 min, five shots
$GODOT --rendering-driver opengl3 --resolution 1568x881 --path godot/ res://game/Match.tscn \
  -- --capture=match --camera=default --tier=3 --seed=20260916      # the owner's window
python3 godot/game/tools/inspect_png.py godot/game/out/timing.png --region=advice@x,y,w,h
python3 godot/game/tools/yellow_map.py godot/game/out/timing.png yellow "x,y,w,h" 4
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd
```

A whole-match capture takes ~3 minutes; for iteration write a throwaway `SceneTree`
probe that renders one frame (~10 s) and delete it afterwards. `flock`/`timeout` do not
exist on macOS.

## Expected evidence

In `timing-presentation-3d.md`: the old sizes and the new ones as **both** world metres
and measured screen pixels, at 1280×720 **and** at 1568×881 (the owner's window), with
the A/B pixel counts and the slice's before/after count. A claim of "smaller now" with
no height measurement is not evidence.

## Failure and recovery criteria

Two attempts, then a blocker naming the frame and the measurement. If the reference's
proportion turns out to be unreadable at 1568×881, say so with both measurements and
present the two candidate sizes — do **not** pick one silently: legibility against a
screenshot is the owner's call, and this ticket exists because that call was already
made once without him.
