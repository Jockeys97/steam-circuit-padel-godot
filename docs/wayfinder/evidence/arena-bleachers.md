# The stands: the owner's bleachers model, measured at the shipped configuration

Lane `crew-bleachers`. The owner's Meshy model is placed along the **two side lines**
of the court, outside the side glass, seats facing the court, and this file records
what it costs: the asset's own numbers as Godot loads them, the placement in metres,
the on-screen size of one unit, and the frame time with and without the stands.

**The ticket stays open.** Two things are still owed and are recorded here, not
filled in: the owner's look verdict (the placement and the size are his call), and
the asset's provenance file `godot/assets/bleachers/bleachers.meshy-task.json` —
its `taskId` / `consumedCredits` are not known, so it is deliberately **not**
created. Nothing in this file substitutes a guess for either.

## 1. The asset's own numbers, as Godot loads them

The probe reads the GLB the way the game does — `GLTFDocument` + `GLTFState` at
runtime (`bleachers.gd::_load_scene`, the same path as
`court.gd::load_athlete_scene`) — so the numbers below are the engine's report of
the loaded scene, not a parse of the file's own tables.

`PROBE_BLEACHERS`, verbatim from the interleaved shipped run (journal Step 1):

```
PROBE_BLEACHERS instances=2 tris=919856 report={"box":"[P: (-0.951825, -0.486788, -0.483349), S: (1.902859, 0.956917, 0.960511)]","error":"","front_x":6.7,"glb_loads":1,"height_m":3.01428869962692,"instances":2,"load_ms":358,"side_x":8.21280477643013,"span_z":5.99400576353073,"triangles":919856}
```

- **Triangles / vertices per copy: 459,928 / 271,287** — one mesh, one node, no
  skins, no animations (`bleachers.gd:44-45`, measured off the loaded mesh in
  `bleachers.gd::triangle_count`). The shipped config is **2 copies** (`sides 2`,
  `copies_per_side 1`) = **919,856 triangles**.
- **Textures**: 3 JPEG textures — `_0.jpg` 9,791,152 bytes (4096² base colour),
  `_1.jpg` 2,064,390 bytes (2048² metallic-roughness), `_2.jpg` 6,500,611 bytes
  (4096² normal). The GLB itself is **32,558,780 bytes (~31.1 MiB)**, glTF 2.0.
- The scene total, from `PROBE_SCENE` on the same run: **1,068,055 triangles**
  (182 meshes). The stands are **86.1 % of the scene's triangles** — and with the
  stands off the whole scene is 148,199 triangles (`PROBE_SCENE` of the baseline
  run), so the stands are 919,856 / 924,606 = **99.5 % of the arena subtree**.
  For scale: one rigged athlete is 31,325 triangles, so **one copy is ≈15× an
  athlete's triangle budget**.

## 2. The placement in metres, and the anchors it derives from

Every number below is derived, not hand-copied. The court's own measures are
`court.gd`: `WIDTH_M := 11.0` (`court.gd:44`), `court_len()` → `WIDTH_M`
(`court.gd:133-134`), `half_len()` → `court_len()/2` = 5.5 m (`court.gd:141-142`),
and the side glass is `GLASS_H := 3.0` (`court.gd:50`). The stands' knobs live in
`bleachers.gd`.

| quantity | value | anchor |
|---|---|---|
| corridor (clear floor beside the glass) | **1.2 m** | `bleachers.gd:70` `CORRIDOR_M` |
| front face x | **6.70 m** | `bleachers.gd:124` `front_x = Court.half_len() + CORRIDOR_M` = 5.5 + 1.2 |
| copy depth (z) | **3.026 m** | `box.size.z * scale` = 0.9605 × 3.15 |
| stand centre x (`side_x`) | **8.2128 m** | `bleachers.gd:125` `centre_x = front_x + depth * 0.5` |
| height | **3.0143 m** | `box.size.y * scale` = 0.9569 × 3.15 (`report["height_m"]`) |
| span along the line (`span_z`) | **5.994 m** | `copies_per_side * box.size.x * scale` = 1 × 1.9029 × 3.15 (`bleachers.gd:150`) |
| min-y lift | **+0.4868 m** | `bleachers.gd:140` `body.position = (0, -box.position.y, 0)`; the unit's own `min_y` is −0.4868 (its box reports `position.y = -0.486788`), so it is lifted by its measured box, never by a hand-copied offset |
| yaw per side | **right −90°, left +90°** | `bleachers.gd:134` `rotation_degrees = (0, -90 * side, 0)`; the unit faces **+Z** as authored (`bleachers.gd:23-26`), so local +Z → world −X on the right, +X on the left — seats facing the court |

The build entry point is `arena_scenery.gd:137` `Bleachers.build(root)`, called last
in `arena_scenery.gd::build` so the stands are the arena's own geometry placed from
the court's width, not a scenery prop (`arena_scenery.gd:134-137`). The measured
world positions, from `PROBE_UNIT`:

```
PROBE_UNIT name=BleacherR1 world_pos=(8.212805, 0.0, 0.0) ...
PROBE_UNIT name=BleacherL1 world_pos=(-8.212805, 0.0, 0.0) ...
```

One copy per side, so `z = 0` (the copy sits centred on the net line, per
`bleachers.gd:129`), and the two stands sit at world x = ±8.2128 m.

## 3. The on-screen size of one unit

`PROBE_UNIT`, verbatim from the interleaved shipped run (the run that wrote
`godot/game/out/bleachers-ship.png`):

```
PROBE_UNIT name=BleacherR1 world_pos=(8.212805, 0.0, 0.0) px_box=(887,197)-(1079,435) px_w=191 px_h=238 px_height=102
PROBE_UNIT name=BleacherL1 world_pos=(-8.212805, 0.0, 0.0) px_box=(201,197)-(393,435) px_w=191 px_h=238 px_height=102
```

The frame is **1280×720**, and these are the engine's own projection —
`Camera3D.unproject_position` over the copy's measured box (`bleachers_probe.gd::_scene_report`),
not a pixel count read off a screenshot. `px_w` is the projected box width (191 px),
`px_h` the projected bounding box height (238 px, the box's z-depth opens it up
under a 36° downward camera), and `px_height` is the projected vertical span of the
unit from its floor line to the top of the box (102 px). The two sides are mirror
symmetric (same `px_w`/`px_h`/`px_height`), as expected at z = 0.

## 4. The cost: frame time with and without the stands

**Method.** The engine's own `Performance.TIME_PROCESS` per frame and the wall-clock
frame interval, measured by the probe over **8 alternating wall-clock windows of
~2 s inside ONE session** (stands visible on/off ABAB, so any contention hits both
arms equally), `vsync` disabled, the same seed / tick / camera
(`--seed=20260916`, tick 420, camera `default`). `--warmup=150` frames are excluded
and reported separately (the first-frame hitch — shader compile + texture upload —
not steady state). The arm medians and their difference are the robust numbers.

**The primary (interleaved) arms**, verbatim:

```
PROBE_ARM arm=ON name=stands n=793 fps=99.0 wall_p50_ms=9.517 wall_mean_ms=10.102 wall_p95_ms=16.120 wall_worst_ms=24.419 engine_p50_ms=17.011 engine_mean_ms=17.351
PROBE_ARM arm=off name=no stands n=1260 fps=157.2 wall_p50_ms=6.704 wall_mean_ms=6.362 wall_p95_ms=8.099 wall_worst_ms=11.669 engine_p50_ms=11.145 engine_mean_ms=11.175
```

Marginal cost of the stands (2 copies, 919,856 triangles), derived from those two
arms:

| metric | no stands | stands | Δ | Δ % |
|---|---|---|---|---|
| engine mean (ms) | 11.175 | 17.351 | **+6.176** | +55.3 % |
| engine p50 (ms) | 11.145 | 17.011 | **+5.866** | +52.6 % |
| wall mean (ms) | 6.362 | 10.102 | **+3.740** | +58.8 % |
| wall p50 (ms) | 6.704 | 9.517 | **+2.813** | +42.0 % |
| fps | 157.2 | 99.0 | **−58.2** | −37.0 % |

**The separate-run pair — a caveated cross-check only.** Re-run after the probe's
`PROBE_FRAME` label fix, `--interleave=0` measures **one ~2-second window** per run
(the probe reports when its single window closes), so each number is a single sample
taken on a machine with another engine window open, and they swing run to run. They
are quoted here as a cross-check, not as equals to the interleaved arms:

```
PROBE_ARM arm=ON name=stands n=154 fps=76.8 wall_p50_ms=11.788 wall_mean_ms=13.028 wall_p95_ms=18.254 wall_worst_ms=22.304 engine_p50_ms=18.766 engine_mean_ms=16.969
PROBE_ARM arm=off name=no stands n=284 fps=141.6 wall_p50_ms=6.937 wall_mean_ms=7.060 wall_p95_ms=7.924 wall_worst_ms=13.061 engine_p50_ms=13.000 engine_mean_ms=16.470
```

That pair implies +5.766 ms engine p50 (+44 %), +4.851 ms wall p50 (+70 %), −64.8
fps (−46 %), but the baseline's `engine_mean` carries a 163 ms boot outlier in a
single window, which is exactly why the interleaved arms are the primary evidence
and these two are not presented as equals.

## 5. The boot log

The stands group loads **once per boot**: `glb_loads=1` on every run, with the
loaded scene duplicated per copy (the copies share one mesh and its textures, so the
cost is draw calls, not memory — `bleachers.gd:31-32,108-109,136-137`). Load times
measured: **358 ms** (interleaved shipped run), 324 ms and 330 ms on the two
separate shipped runs. **Zero `SCRIPT ERROR`** on every run — the interleaved run
reports `SCRIPT ERROR count: 0`, and the two post-fix re-runs carry no SCRIPT ERROR
lines (count 0). The `report` dict is plain values only, so the stands leave nothing
leaked at exit (`bleachers.gd:87-94`).

## 6. The slice counts and the parity digest

All three re-run from the journal, exit codes included:

```
PASS court dimensions: 1111 checks, 0 failures            (exit 0)
FAIL 325/326                                              (exit 1)
FAIL the shipping pack exists (export it before running this test): expected true, got res://build/linux-x86_64/padel.pck
```

- `court_dimensions_test.gd` — **1111 checks, 0 failures, exit 0**.
- `game_slice_test.gd` — **325/326, exit 1**, with `res://build/linux-x86_64/padel.pck`
  the **only** red (the gitignored, not-exported clone artifact — by design; the
  count did not change).
- Parity digest — **exit 0**:

```
PARITY-DIGEST GD PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
```

## 7. The frames — a blank-frame guard, not a geometry measurement

`inspect_png.py` over the four rendered frames (journal Step 4), verbatim:

```
godot/game/out/bleachers-ship.png bytes=275685 sha256=bdcbf445d7f5f03f4e854d1e39ced151a29f98871b64b2adf16fb026b837c8f3 size=1280x720 channels=4 distinct_rgb=18046 std=66.27 pixels_different_from_modal=0.9583 blank=no
godot/game/out/bleachers-2side.png bytes=353781 sha256=17b745016345f60a804ba73f920c67e5c90b8a439f889bae29f64c8a795ed98a size=1280x720 channels=4 distinct_rgb=21417 std=69.21 pixels_different_from_modal=0.9583 blank=no
godot/game/out/bleachers-off.png bytes=192019 sha256=1a147a73ff6a3f8d6d5e6cd24f057331d199789b6ed20c60cc51d1ccd9303ac7 size=1280x720 channels=4 distinct_rgb=10417 std=62.96 pixels_different_from_modal=0.9572 blank=no
godot/game/out/bleachers-1side.png bytes=275636 sha256=2a27ed4a0a60d76dd06090041342f361b316c9f50b30e8321d216111a176fc71 size=1280x720 channels=4 distinct_rgb=18015 std=66.27 pixels_different_from_modal=0.9583 blank=no
```

This proves the captures are **not blank** (all `blank=no`, tens of thousands of
distinct colours). It does **not** measure geometry — the on-screen size above is
the projection, and the look itself is the owner's to judge, not this detector's.

## 8. What this does NOT prove

- **Nothing about feel, and nothing about the look being right.** The owner's
  aesthetic verdict is still open; these frames are material for it, not the verdict.
- **Nothing about the cost on a quiet machine.** Another engine window was open
  throughout, so the absolute numbers are pessimistic. The two interleaved arms are
  comparable **to each other** because they alternate inside one session; a single
  absolute fps figure is not a claim about a clean run.
- **It does not measure a 4th copy, another side count, another scale, or the
  shadows-on configuration.** Only `copies_per_side=1`, `sides=2`, `scale=3.15`,
  `cast_shadow=false`, `material=imported` was measured for the shipped number
  (the separate-run A/B also fixed exactly this config).
- **It does not prove the GLB is production-ready.** One mesh of 459,928 triangles
  per copy is ~15× an athlete; that is the disclosed cost, not a statement that the
  model is the right asset for a tribune.
- **The separate-run cross-check is two ~2-second samples**, each a single window on
  a busy machine — it swings run to run and is not the primary evidence.

## 9. Corrections made during this session

- The probe's `PROBE_FRAME` line had two labels assigned to the wrong arguments; it
  was fixed in the tree during this session (label `engine_fps` → `wall_fps`, and
  the engine trimmed mean now lands in `engine_trim80_ms`). **Labels only — no value
  changed.** The two `--interleave=0` commands were re-run after the fix and appended
  to the journal (Step 2c); the pre-fix `PROBE_FRAME` lines in the journal are
  correctly numbered but mislabelled, so they are not quoted in this file.
- The probe's `--frames` argument is accepted but **unused**: the measured region is
  driven by the `--interleave` windows and `--seconds`, not by `--frames`.
