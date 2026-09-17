# UIR-09 — prototype mount: evidence (real checkout)

Ticket: `docs/implementation/ui-recreation/tickets/UIR-09-prototype-mount.md`
Repo: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (the real
target checkout — not the isolated copy the earlier waves used).
Date (UTC): 2026-09-16/17 · `git rev-parse HEAD` `252ff6074039372ebbf8ec682f9adda0e9c80d03`
(no commit was made; every file below is a working-tree change).
Engine: `/Applications/Godot.app/Contents/MacOS/Godot` → `4.7.2.stable.official.ed1daf0bf`
(the pinned version), `--rendering-driver opengl3` on Metal (`OpenGL API 4.1 Metal - 91.7 -
Compatibility - Using Device: Apple - Apple M4` — real GPU frames, not the dummy driver).

## What the mount is

`--ui=new` is an additive switch: it mounts the recreated UI *beside* the ported one,
which is still built and refreshed until UIR-22 owns its removal.

| Seam | File | What `--ui=new` does |
|---|---|---|
| menu | `godot/game/main_menu.gd` | builds UIR-03's `ScreenRouter` with the recreated `menu` screen (`res://src/ui/screens/MenuScreen.tscn`) and registers the still-ported `modes` scene beside it; both are `load()`ed at the moment the switch is read, so a legacy run (and the slice gate) pulls nothing of the prototype into the engine's object count |
| HUD | `godot/game/match_controller.gd` | mounts `res://src/ui/Hud.tscn` in the same HUD layer, binds the same names (`bind_names`) and feeds it the same `state`+`meta` through `_refresh_ui()` at MODE_START / MODE_FINISH / every tick / result / pause — the ported `_hud`/`_mode_hud` pair stays built underneath |

Report line when the prototype is on screen: `UI_PROTOTYPE_ON_SCREEN {"screen":"menu","router":"menu"}`
(or `MODE_SCREEN_ON_SCREEN` for the ported modes scene, which is its own lane).

## Commands and results (serial, one engine process at a time)

```
$GODOT --headless --path godot/ --import                      # exit 0, fonts' .import sidecars created
$GODOT --headless --path godot/ --script res://tests/ui/hud_audit.gd
    -> exit 0, PASS 151/151, SCRIPT ERROR 0           (was: script + font load failures, exit 0 with 3 SCRIPT ERRORs)
$GODOT --headless --path godot/ --script res://tests/ui/ui_legibility_audit.gd
    -> exit 1, FAIL 73/76, SCRIPT ERROR 0             (3 failures = one finding, below)
```

HUD capture, 1280x720 (before-file names are the capture plan's own):

```
$GODOT --rendering-driver opengl3 --path godot --resolution 1280x720 res://game/Match.tscn -- \
    --ui=new --capture=match --tier=3 --seed=20260916
    -> exit 0, CAPTURE_DONE shots=4 ticks=25962 result={"winner":"ai"} score=0-0 points=24, SCRIPT ERROR 0
       CAPTURE_SHOT quickmatch-serve.png/-rally.png/hud.png/result.png
```

Same plan at the ticket's secondary viewport:

```
... --resolution 1152x648 ... -> exit 0, CAPTURE_DONE shots=4, SCRIPT ERROR 0
```

Menu capture + UIR-24 harness (see `uir-24-capture.log`):

```
$GODOT --rendering-driver opengl3 --path godot --resolution 1280x720 res://game/Main.tscn -- \
    --ui=new --capture=menu --out=ui-prototype-menu
    -> exit 0
$GODOT --rendering-driver opengl3 --path godot --resolution 1280x720 res://tests/ui/capture_ui.tscn -- \
    --capture=all --seed=20260916 --tier=3
    -> exit 0 (log attached)
```

## The capture pairs (real frames, registered)

After-frames, `godot/game/out/` (all `PNG image data, 1280 x 720 / 1152 x 648,
8-bit/color RGBA, non-interlaced`, md5):

| File | Viewport | Command | md5 |
|---|---|---|---|
| `ui-prototype-menu.png` | 1280x720 | `--ui=new --capture=menu` | `1f0e32d3df5d26bbdf12fccb6a3f6407` |
| `ui-menu.png` / `ui-menu-demo.png` / `ui-menu-beta.png` | 1280x720 | harness `--capture=all` | `1f0e32d3…` / `e37d4fc2…` / `6692fcdd…` |
| `ui-prototype-hud-serve.png` | 1280x720 | `--ui=new --capture=match` | `40bbb74a54e1e15cad391fd3e32ba73e` |
| `ui-prototype-hud-rally.png` | 1280x720 | same run | `b014551dda1caa62bbe6a3c3aa6c8a26` |
| `ui-hud-feedback.png` (plan's `hud.png`) | 1280x720 | same run | `cd3f654da3d0869124ddec2c6bda0e99` |
| `ui-hud-result.png` (plan's `result.png`) | 1280x720 | same run | `8131c7e9185bd87470a71a00e8e719b1` |
| `ui-hud-serve-1152x648.png` | 1152x648 | secondary run | `28d8c244280eb555302d105704742876` |
| `ui-hud-rally-1152x648.png` | 1152x648 | secondary run | `9b74255e7f1ca10c84beca88151a7f1a` |

The four plan outputs were copied to their `ui-*` names and the plan's own files were
then restored byte-identical from `/tmp/uir-wave3-out-before/` (which was taken from the
registered before-set): `quickmatch-serve.png md5 619a421737c04bc47232cd1a15de8884`,
`rally.png`, `hud.png`, `result.png` — the before-set's own sha256 register is in
`uir-00-before-set.md` and is unchanged by this wave (re-checked below).

Before-halves (both are recorded, neither was re-taken):
- the recorded web references — `evidence/reference-captures/menu.png`,
  `…/game.png` (the platform being recreated, screenshots of the reference build);
- the ported-UI frames — `godot/game/out/menu.png`, `hud.png`, `quickmatch-serve.png`,
  `rally.png`, `result.png` (registered at the anchor commit, untouched).

So the menu pair is `reference-captures/menu.png` ↔ `ui-prototype-menu.png` +
`ui-menu{,-demo,-beta}.png`, and the HUD pair is `reference-captures/game.png` ↔
`ui-prototype-hud-serve.png` / `ui-prototype-hud-rally.png` (+ the 1152x648 pair).

## Honest read of the frames (a description, **not** an approval)

Both halves were read with a vision pass on the real files; this lists what the frames
show and where they diverge. Nothing here closes GATE-A's look/feel verdict.

Matches: dark page background, top bar with brand mark + the three round buttons, the
poster card, hero block with the two-line title (white + cyan line), the tag row
(`PC Browser`, `Arcade`, `Alpha 0.2`), the pad-note pill, the six-button column, and the
six-card modes screen; in-match — scoreboard top-left with the `SCORE` header, the two
competitors and the meta sub-grid, the control row top-right, the minimap card under it,
the centred serve/pause banner band, and the bottom feed.

Discrepancies recorded (open):
1. **Frame pairing.** The plan's `quickmatch-serve` shot fires just *after* the serve
   (tick 143, ball in flight, `GAME TIME 00:01`), while the recorded web frame shows the
   pre-serve prompt; the closer pair is `ui-prototype-hud-rally.png` ↔ `game.png`. A
   pre-serve frame would need a new shot in the capture plan.
2. **Competitor label.** The port's scoreboard reads its AI name from the tier
   (`CIRCUITO` at `--tier=3`); the recorded web frame shows the shorter `RIVAL`. The
   reference capture's tier is not recorded in its own provenance, so this is flagged,
   not resolved.
3. **Density in the scoreboard card.** In the port's frame the meta chips (`COPPIA`,
   `Combo`) sit close to the card's bottom edge; the legibility audit measures
   containment (clean), not breathing room.
4. **Minimap header.** The frame shows `MAPPA` tight against the card's top edge — a
   watch item for GATE-A; containment passes.
5. **Scene content.** The arena/players behind the HUD differ from the recorded web
   frame (arena art is another lane's); the comparison is the overlay, not the scene.

## Findings this wave fixed (with the audit that caught them)

- `Hud.gd`: the training/tournament strip no longer collides with the scoreboard — its
  top is the card's *real* bottom via `_score_panel.resized` → `_stack_mode_strip()`
  (the measured 95 px constant was a floor, not the rendered height).
- `ViewState.gd` (`drill` capture state): the serve banner is off — a drill serves
  nothing, and the banner was standing inside the strip's band at 1152x648.
- `UiStrings.gd`: numeric locale params are stringified before `Locale.t` (GDScript has
  no `String(int)`; the frozen locale module fails on a non-String `{n}`).
- The ported `Modes` screen keeps its own capture lane: the UIR-24 harness reports it
  pending instead of probing its hooks (an earlier harness build called them and the
  run's own scene went out from under it).

## Still open, not ours to close

- `MenuScreen` caption overhang at 1024x600 (`Caption` 378x92 at (552,307) leaving
  `PosterFrame` (561,197,391,220) by 9 px) — UIR-07's file; recorded by the legibility
  audit, unchanged here.
- `slice-demo` object-count ceiling: `game_slice_test.gd`'s `objects_delta <= 450`
  (measured baseline 395) — before this wave's lazy loads it measured 459 (resources,
  not nodes: `nodes=1 orphans=0`); fixed by loading the prototype scenes only under
  `--ui=new` (re-run below).

## Running the prototype (the launch command)

```
/Applications/Godot.app/Contents/MacOS/Godot --rendering-driver opengl3 --path godot \
  --resolution 1280x720 res://game/Main.tscn -- --ui=new
```

The recreated menu answers; `Play now` routes through the router to the ported `modes`
screen (its recreation is a later ticket); starting a match mounts the recreated HUD in
`Match.tscn` under the same `--ui=new` switch.
