# Court width — the render, widened by candidates (lane `crew-courtwidth`)

**Status: DELIVERED and RATIFIED — three candidates rendered and measured, one
frame each. The owner picked 11.0 m ("prova 11", confirmed to this session on
2026-09-17), so `game/court.gd` and `EXPECTED_WIDTH_M` both rest on 11.0 m. The
code was already there; the status line and §9 still named 10.5 m and are
corrected here.**

The owner's verdict this answers (2026-09-17): *"allarghiamo leggermente le misure
dell'arena orizzontalmente. Di poco proprio visto che quelle attuali sono
realistiche per un campo da padel ma non mi piace la resa grafica"*. The
measurement is accepted; the **render** is what he is judging.

This is a **projection** change. The simulation is frozen in pixels (`js/game.js`
semantics) and `court.gd::world_pos` maps those pixels to metres by dividing by
`COURT`'s pixel span — never by `WIDTH_M`. Moving `WIDTH_M` therefore changes the
metres-per-pixel of x and nothing else. The proof is the parity digest below,
which did not move.

## 1. The candidates and their frames

One frame per candidate, all four rendered from the **same simulation instant**
(`ticks=420 rallyHits=3 ball=(798.0,203.8,54.5)`, seed `20260916`, tier `leggenda`,
arena `officina`, camera `default`, models on), so the only difference between two
frames is the width. `width-10.0.png` is the "before" baseline, rendered by the
same probe for a like-for-like comparison.

| width | % of 10 m | frame | sha256 (first 16) | frame size |
|---|---|---|---|---|
| 10.0 m (before) | 100 % | `godot/game/out/width-10.0.png` | `5fc2717fc512431b…` | 1280x720 |
| **10.5 m** | **105 %** | `godot/game/out/width-10.5.png` | `d1827ce1746bbb0f…` | 1280x720 |
| **11.0 m** | **110 %** | `godot/game/out/width-11.0.png` | `147283208e608296…` | 1280x720 |
| **12.0 m** | **120 %** | `godot/game/out/width-12.0.png` | `bcae35afdc3d9505…` | 1280x720 |

Full hashes:

```
5fc2717fc512431b7a7aab05ae7a2556f9bf33e903af466d77008c5fddfdea85  width-10.0.png
d1827ce1746bbb0f1bd95cdcd7f4a53e8a3595adfdc073fbd1dcdee3eadbeda0  width-10.5.png
147283208e60829626254475d4483564162b7b3bbd8ab2878085d7c0a31d2ce3  width-11.0.png
bcae35afdc3d9505ece9bf321af241edd71387f60d2ce0b9f023def696917cee  width-12.0.png
```

## 2. The court's measured width in the frame

Two independent readings, and they agree to 0.4 %:

- **projected** — `Camera3D.unproject_position()` on the court's own corners, from
  the live camera of the run;
- **measured in the PNG** — the longest run of near-white pixels per screen row
  (the court lines and the net tape are albedo `0.95,0.96,0.98`, the brightest
  things on the bed). The near line is the widest visible row of the court.

| width | metres per sim px on x | near line (z=+10 m) proj / measured | net tape (z=0, 0.915 m) proj / measured | far line (z=-10 m) proj | frame margin per side at the near line |
|---|---|---|---|---|---|
| 10.0 m | 0.012500 | 518.4 / **516** px | 401.5 / 404 px | 319.2 px | 382 px |
| 10.5 m | 0.013125 | 544.3 / **542** px | 421.5 / 424 px | 335.2 px | 369 px |
| 11.0 m | 0.013750 | 570.3 / **568** px | 441.6 / 444 px | 351.1 px | 356 px |
| 12.0 m | 0.015000 | 622.1 / **620** px | 481.8 / 484 px | 383.0 px | 330 px |

The measured rows, verbatim from the run:

```
== godot/game/out/width-10.0.png  1280x720
  row  663 run= 516  x= 382.. 897  centre=639.5      <- near line
  row  329 run= 404  x= 438.. 841  centre=639.5      <- net tape
== godot/game/out/width-10.5.png  1280x720
  row  664 run= 542  x= 369.. 910  centre=639.5
  row  329 run= 424  x= 428.. 851  centre=639.5
== godot/game/out/width-11.0.png  1280x720
  row  664 run= 568  x= 356.. 923  centre=639.5
  row  329 run= 444  x= 418.. 861  centre=639.5
== godot/game/out/width-12.0.png  1280x720
  row  664 run= 620  x= 330.. 949  centre=639.5
  row  329 run= 484  x= 398.. 881  centre=639.5
```

(The 1–3 px difference between the projection and the pixel reading is the drawn
line's own 0.05 m thickness plus the frame's filter — the projection is the exact
number, the pixel run is what a reader can find in the PNG.)

The court grows on screen **exactly** in proportion to `WIDTH_M`: +5.0 %, +10.0 %,
+20.0 % at the same three depths. Nothing else in the frame moved.

## 3. The ball and the athletes — how their apparent size changes

`Court.BALL_R = 0.10 m` and the athlete rig are **fixed world sizes**, and the
camera is unchanged, so their own pixel size is *identical in all four frames*:

```
PROBE_BALL sim_px=(798.0,203.8,54.5) world=(3.974815, 1.361513, -6.16478) center_px=(779.8,193.7) diameter_px=6.222 r_m=0.100   (10.0 m)
PROBE_BALL sim_px=(798.0,203.8,54.5) world=(4.173555, 1.361513, -6.16478) center_px=(786.8,193.7) diameter_px=6.222 r_m=0.100   (10.5 m)
PROBE_BALL sim_px=(798.0,203.8,54.5) world=(4.372296, 1.361513, -6.16478) center_px=(793.8,193.7) diameter_px=6.222 r_m=0.100   (11.0 m)
PROBE_BALL sim_px=(798.0,203.8,54.5) world=(4.769778, 1.361513, -6.16478) center_px=(807.8,193.7) diameter_px=6.222 r_m=0.100   (12.0 m)
```

That print is also the cleanest statement of what this change *is*: **the same sim
pixel (798.0) lands at a different metre** (3.97 m → 4.77 m) because the world got
wider under a frozen pixel simulation. The ball's 6.222 px diameter does not move.

Confirmed in the PNG itself (the ball is the only yellow disc in the frame):

```
$ python3 godot/game/tools/yellow_map.py godot/game/out/width-11.0.png yellow 780,180,32,32 1
# godot/game/out/width-11.0.png window=780,180,32,32 cell=1 mode=yellow pixels=33
 190 ............###.................
 191 ...........######...............
 193 ..........#######...............
 195 ...........#####................
```

— a blob ~6 px across at (790,190), against the projected 6.222 px.

Apparent size **relative to the court**, before and after (a metre ratio is
depth-free; the on-screen ratios are quoted at the same depth for both sides):

| ratio | 10.0 m | 10.5 m | 11.0 m | 12.0 m |
|---|---|---|---|---|
| ball Ø 0.20 m / court width | 2.000 % | 1.905 % | 1.818 % | 1.667 % |
| athlete 1.678 m / court width | 16.78 % | 15.98 % | 15.25 % | 13.98 % |
| ball Ø px / net tape px (same depth) | 1.550 % | 1.476 % | 1.409 % | 1.291 % |
| athlete px / near line px | 11.66 % | 11.10 % | 10.59 % | 9.70 % |
| relative to the 10 m court | 1.0000 | 0.9524 | 0.9091 | 0.8333 |

The athlete's figure is the rig's own `athlete_rig.gd::get_world_extent()` —
`MeshInstance3D.get_aabb()` is explicitly wrong here (it double-counts the
`Armature`'s 0.01 scale; that file records the wasted render). Measured at the
rally tick: 1.678 m for the two near athletes, 1.516–1.587 m for the two far ones
(the rest extent varies slightly per rig), and 60.148 px on screen for the near
pair in **every** frame.

**Neither the ball nor the athletes were rescaled — and they must not be.** The
exact effect of every candidate is a −4.8 % / −9.1 % / −16.7 % drop in the size of
everything else relative to the court.

## 4. The camera: no adjustment was made, and here is the proof it was not needed

Measured identically in all four runs:

```
PROBE_CAMERA preset=default pos=(0.0, 20.0, 27.5) rot_deg=(-36.0274, 0.0, 0.0) pitch_deg=-36.0274 fov=30.000 keep_aspect=1 frame=(1280.0, 720.0)
```

`CAMERAS.default` is byte-identical to what the 10 m court was solved for: no fov
change, no dolly, no pitch change, no `keep_aspect` change. **A minimal, reported
adjustment was allowed and was measured to be unnecessary**: the widest visible
row of the court keeps a healthy margin to the frame edge in every candidate
(382 → 369 → 356 → 330 px per side at 1280 px), so the wider court stays framed
and nothing is cut off. At the largest candidate the near corner still sits 25.8 %
of the frame half-width inside the border. This also means the "keep the court
framed" allowance in the ticket is unused, not silently spent.

## 5. What else in the scene follows, and what does not

- **Follows automatically** (all derived from `Court.court_len()` / `half_len()`):
  the court bed, all seven lines, the net lattice/tape/posts (49 columns and 9 rows
  of wire are re-spaced from the width), the six rear glass panes and their
  dividers, the side and near glass, the four cage posts, the two accent posts
  (placed at `±(hl + 2.0)`), the land ring and the athletes' positions.
  `court_builder.gd` holds **no** hard-coded 10 m; the only bare `5.0` in
  `arena_scenery.gd` (line 292) is a prop's own hull length, not the court.
- **Does not follow, and does not need to**: the hall. `arena_scenery.gd::band()`
  derives the backdrop's half-width and the props' `x_scale` from the camera
  preset and the frame, not from the court, so the backdrop still covers the
  frame's widest row at every candidate. Reported here because the ticket asked
  for the amount: **0 m of hall movement required, 0 m made.**
- The owner's "resa" is what changes: the court fills 5/10/20 % more of the frame
  width, the sidelines' screen slope steepens, and every ball and body in it
  reads correspondingly smaller (§3).

## 6. Tests and the parity digest (real output)

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
GODOT_BIN=$GODOT tools/sim-port/parity-digest-gd.sh --seed=12345 --ticks=1440 --every=60
$GODOT --headless --path godot/ --script res://tests/court_dimensions_test.gd
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd
```

```
PARITY-DIGEST GD PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
PASS court dimensions: 1111 checks, 0 failures
FAIL 325/326
FAIL the shipping pack exists (export it before running this test): expected true, got res://build/linux-x86_64/padel.pck
```

- **The parity digest is unchanged** — same `finalRngState`, same
  `digestSha256=a7136682…c27dd` as the digest recorded for the frozen
  simulation, and the script's own comparison against the JavaScript reference
  exits 0. This is the proof that this is presentation: the simulation was not
  touched.
- `court_dimensions_test.gd`: **1111 checks, 0 failures**, with the expected width
  now the ratified value (`EXPECTED_WIDTH_M := 11.0`) and the two mapping
  checks written in terms of it. The C1-continuity, 6.95 m service-line and
  1100-sample monotonicity checks are byte-for-byte what they were.
- `game_slice_test.gd`: **325/326, the only red `padel.pck`** (the gitignored
  clone artifact, by design). The count did not change.

## 7. What this does NOT prove

- **Nothing about the owner's judgement.** Whether the wider render is the one he
  wants is his call; these frames are the material for it, not a verdict.
- **Nothing about the game's behaviour.** The digest proves the headless
  simulation core is unchanged; it says nothing about physics *as rendered*
  (contact, reach, bounce are the same pixel code, and the athletes' bodies are
  the same metre sizes — that is an argument, not a measurement).
- **Nothing about motion.** These are single static frames at one instant. No
  animation, temporal stability, shadow-accurate or frame-rate claim is made.
- **Nothing about the other camera presets.** Only `default` was measured;
  `wide` and `playable` were not rendered at any candidate.
- **Nothing about the nine arenas.** Only the default arena `officina` was
  rendered (the scenery is frame-derived, which is why it should not matter, but
  it was not measured).
- The athlete's apparent size uses the rig's **rest extent** (1.678 m), not a
  per-frame skinned silhouette; a swing pose can differ by a few centimetres.
- The pixel measurements are one detector (near-white runs, one cell per pixel);
  the ±1–3 px agreement with the projection is the cross-check, not a
  second independent instrument.
- The frames are 1280x720 here, while the recorded quick-match captures on this
  host are 1568x882 (the display scale factor). The aspect is identical (16:9), so
  the geometry and every ratio above are unaffected — but a 1:1 pixel comparison
  against `rally.png` is not available.

## 8. What the lane found wrong in the ticket, and how it was closed

1. **`godot/tests/game_slice_test.gd:226` fixed the width at `10.0` as a literal.**
   Any width change — this ticket's whole subject — turned that check red in a
   file the ticket had assigned to another lane. The owner corrected the
   allowlist and it now compares against `Court.WIDTH_M`, so his next pick cannot
   break the slice. Without that correction this lane could not have delivered a
   widened court with a green suite.
2. **A throwaway probe left in `godot/game/out/` is a red in the slice test.**
   The export/content check scans that directory, so the ticket's own advice
   ("write a throwaway probe … and delete it after") is load-bearing: the probe
   was removed before the suite was run (verified: no `*.gd` left in `out/`).
3. **`Match.tscn`'s `_ready()` is deferred.** A `SceneTree` probe must await two
   frames after `add_child()` before touching `state`; touching it earlier gave a
   half-built scene, `state == null` and a `_sync_views()` error on a null
   `_ball_view`. Not a defect in the game — a trap for the next probe.
4. **The "before" is not pixel-comparable.** The ticket calls the current captures
   the before; on this host they are 1568x882 against a 1280x720 capture command.
   The baseline was re-rendered at 1280x720 with the same probe for a like-for-like
   comparison.

## 9. The ratified value, and the surface it moves

The owner picked **11.0 m** (2026-09-17), so `game/court.gd` carries
`const WIDTH_M := 11.0` and `court_dimensions_test.gd` carries the matching
`EXPECTED_WIDTH_M := 11.0`. This section named 10.5 m as the resting value while
the code had already moved to 11.0 — that contradiction was found on 2026-09-17
during the map reconciliation and is closed here. The change surface is:

- `godot/game/court.gd` → `WIDTH_M` (one line).
- `godot/tests/court_dimensions_test.gd` → `EXPECTED_WIDTH_M` (one line, the only
  place the number is repeated in that file).
- `godot/tests/game_slice_test.gd` and every other call site need **no** change:
  they read the constant.
