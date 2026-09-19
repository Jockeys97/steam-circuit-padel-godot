# PROPS-RESULT — fifty props mounted, the doubling proved, the doubling fixed

Captain C (integrator), wave two. Workdir `steam-circuit-padel-godot` (main tree), engine
`/Applications/Godot.app/Contents/MacOS/Godot` v4.7.2. Every number here is measured in the engine, one
process at a time under `flock -w 900 /tmp/padel-godot.lock`; the full tables are in `CENSUS.md` beside
this file, and the machine-readable census JSON is written by the tool to the path passed as `--out=`.

## 1. What changed

| file | change |
|---|---|
| `godot/game/arenas/arena_kit.gd` | `suppress` flipped to `true` on exactly the 16 slots that stand over a procedural counterpart; 34 slots untouched. No anchor, `target_h`, `repeats`, `spread` or `depth` value was touched — the diff is 16 lines, all of them suppress flags. Stale header/doc comments updated to match. |
| `tools/arena-kit/mount_census.gd` | new — the engine-measured census tool (`--mode=both` runs each arena with the flags forced off and again as they stand). |
| `godot/tests/arena_kit_test.gd` | rewritten as the KIT-STANDARD gate G3 intake suite: real mount, real node tree, real bounding boxes, real glass panes; no longer deletes GLBs (it fingerprints them instead). |
| `docs/mission/arena-kit/arena-props/CENSUS.md` | new — the full before/after tables. |
| this file | the narrative, gates, tallies and decisions. |

Not touched: any GLB, `art/arena-kits/**`, `arena_scenery.gd`, `arena_look.gd`, the
`feat-native-world-arenas` worktree, the SPECS numbers. No commits, no pushes.

Verified after the work: all 50 GLBs still sha256-match the fingerprint taken before any run
(`/tmp/kit-glb-prev/glb-sha256-pre.txt`, 00:59); `git diff` on `arena_kit.gd` contains **0** changed
lines touching `"anchor"`, `"target_h"`, `"repeats"`, `"spread"` or `"depth"`; no Godot process is left
running. The headless import pass the brief requires wrote the engine's own `.import` sidecars under
`godot/assets/arenas/**` (205 files, engine metadata, not authored content) — no GLB or texture was
touched by it.

## 2. The doubling, proved and fixed

**Measured**, not asserted: `mount_census.gd` builds each arena through the production path
(`ArenaScenery.build()`), then walks the built tree — the `Dressing_*` containers, the
`Kit/<Arena>/<slot>` holders and every `MeshInstance3D` under them — and counts what is actually
there, plus real bounding boxes (`ArenaKit.node_bounds`), the real glass panes and real screen rows.

| | before (flags off) | after (flags on) |
|---|---|---|
| slots whose GLB stands over live procedural containers | 16 of 50 | **0 of 50** |
| procedural `MeshInstance3D`s built under those containers | 296 | **0** |
| `Dressing_*` containers (frozen invariant) | 145 | 145 (unchanged) |
| mounted pieces | 145 | 145 (unchanged) |

Per arena, before → after: doubling slots `torii` 4→0, `medina` 5→0, `carioca` 3→0, `aurora` 2→0,
`egeo` 2→0; live procedural meshes `torii` 89→0, `medina` 92→0, `carioca` 51→0, `aurora` 32→0,
`egeo` 32→0. The two passes differ only in the flags, so this delta is the fix.

## 3. The suppress decision, slot by slot

Rule applied: `suppress = true` **iff** the slot's `kinds` list names a procedural prop that
`arena_scenery.gd` still builds for that arena (i.e. the slot stands over a counterpart). Slots with
`kinds: []` have no procedural counterpart and stay additive — suppressing them would delete a prop
the arena is authored to have.

| arena | slot | told to stand over | doubles before | suppress | why |
|---|---|---|---|---|---|
| torii | hero_landmark | pagoda | yes | **ON** | replaces the procedural pagoda |
| torii | gate_portal | torii | yes | **ON** | replaces the procedural torii |
| torii | light_source | lantern | yes | **ON** | replaces the procedural lantern |
| torii | vegetation_cluster | petal | yes | **ON** | replaces the procedural petal |
| torii | ground_dressing | — | no | off | no procedural counterpart — additive by design |
| torii | ornament_accent | — | no | off | no procedural counterpart — additive by design |
| torii | column_pillar | — | no | off | no procedural counterpart — additive by design |
| torii | railing_segment | — | no | off | no procedural counterpart — additive by design |
| torii | furniture | — | no | off | no procedural counterpart — additive by design |
| torii | signage_banner | — | no | off | no procedural counterpart — additive by design |
| medina | hero_landmark | minaret | yes | **ON** | replaces the procedural minaret |
| medina | gate_portal | arch | yes | **ON** | replaces the procedural arch |
| medina | light_source | lantern | yes | **ON** | replaces the procedural lantern |
| medina | vegetation_cluster | palm | yes | **ON** | replaces the procedural palm |
| medina | ground_dressing | — | no | off | no procedural counterpart — additive by design |
| medina | ornament_accent | zellige | yes | **ON** | replaces the procedural zellige |
| medina | column_pillar | — | no | off | no procedural counterpart — additive by design |
| medina | railing_segment | — | no | off | no procedural counterpart — additive by design |
| medina | furniture | — | no | off | no procedural counterpart — additive by design |
| medina | signage_banner | — | no | off | no procedural counterpart — additive by design |
| carioca | hero_landmark | peak | yes | **ON** | replaces the procedural peak |
| carioca | gate_portal | — | no | off | no procedural counterpart — additive by design |
| carioca | light_source | — | no | off | no procedural counterpart — additive by design |
| carioca | vegetation_cluster | palm | yes | **ON** | replaces the procedural palm |
| carioca | ground_dressing | foam | yes | **ON** | replaces the procedural foam |
| carioca | ornament_accent | — | no | off | no procedural counterpart — additive by design |
| carioca | column_pillar | — | no | off | no procedural counterpart — additive by design |
| carioca | railing_segment | — | no | off | no procedural counterpart — additive by design |
| carioca | furniture | — | no | off | no procedural counterpart — additive by design |
| carioca | signage_banner | — | no | off | no procedural counterpart — additive by design |
| aurora | hero_landmark | snowridge | yes | **ON** | replaces the procedural snowridge |
| aurora | gate_portal | — | no | off | no procedural counterpart — additive by design |
| aurora | light_source | — | no | off | no procedural counterpart — additive by design |
| aurora | vegetation_cluster | — | no | off | no procedural counterpart — additive by design |
| aurora | ground_dressing | basalt | yes | **ON** | replaces the procedural basalt |
| aurora | ornament_accent | — | no | off | no procedural counterpart — additive by design |
| aurora | column_pillar | — | no | off | no procedural counterpart — additive by design |
| aurora | railing_segment | — | no | off | no procedural counterpart — additive by design |
| aurora | furniture | — | no | off | no procedural counterpart — additive by design |
| aurora | signage_banner | — | no | off | no procedural counterpart — additive by design |
| egeo | hero_landmark | island | yes | **ON** | replaces the procedural island |
| egeo | gate_portal | — | no | off | no procedural counterpart — additive by design |
| egeo | light_source | — | no | off | no procedural counterpart — additive by design |
| egeo | vegetation_cluster | bougainvillea | yes | **ON** | replaces the procedural bougainvillea |
| egeo | ground_dressing | — | no | off | no procedural counterpart — additive by design |
| egeo | ornament_accent | — | no | off | no procedural counterpart — additive by design |
| egeo | column_pillar | — | no | off | no procedural counterpart — additive by design |
| egeo | railing_segment | — | no | off | no procedural counterpart — additive by design |
| egeo | furniture | — | no | off | no procedural counterpart — additive by design |
| egeo | signage_banner | — | no | off | no procedural counterpart — additive by design |

16 slots ON, 34 slots OFF. The suite asserts the rule holds both ways (ON ⇔ non-empty
`kinds` with a GLB in place), so a future table edit cannot silently unsuppress a doubled slot.

## 4. Gates — measured

| gate | verdict | measured value |
|---|---|---|
| doubling gone | **PASS** | 16 slots / 296 meshes → 0 / 0 |
| field-law plane z = −8.0 (no instance crosses) | **PASS** | closest vertices: torii −10.12, medina −9.63, carioca −8.99, aurora −9.53, egeo −9.38 |
| mount height = spec `target_h` | **PASS** | 145/145 exact |
| bottom origin / repeat offsets / counts | **PASS** | 145/145 exact |
| frame law, authored ±14.35 m | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| material policy (opaque, metallic 0, rough .85) | **PASS** | 145 surfaces, 0 violations |
| culling: box inside the 1280×720 frame | **PASS** | 145/145, worst margin 8.8 px |
| depth budget ≤ 3.26 m | **FAIL** | torii=PASS medina=PASS carioca=FAIL aurora=FAIL egeo=FAIL |
| behind the measured glass plane (−10.02 m) | **FAIL** | torii=PASS medina=FAIL carioca=FAIL aurora=FAIL egeo=FAIL |
| no mesh over the court footprint | **FAIL** | torii=PASS medina=FAIL carioca=FAIL aurora=FAIL egeo=FAIL |
| culling: box above the rear baseline row | **FAIL** | torii=PASS medina=FAIL carioca=FAIL aurora=FAIL egeo=FAIL |

The four red gates are one defect measured four ways and they are **inherited from the art, not from
the suppress flip**: the before and after passes name the same offenders. Seven slots across four
arenas carry meshes far deeper than the table declares; `torii` passes everything.

## 5. Suite tallies (commands and exit codes)

All runs: one Godot process at a time under
`run/tmp/arena-kit/bin/flock -w 900 /tmp/padel-godot.lock` (this host has no system `flock`; the
vendored one in `run/tmp/arena-kit/bin/` is used), `pgrep -x Godot` checked before each run, never
`pkill`. `--` separates Godot args from script args.

### Before the flip (baseline, `/tmp/kit-suites-before`)

| suite | command | exit | tally |
|---|---|---|---|
| field_law | `Godot --headless --path godot/ --script res://tests/world_arenas_field_law_test.gd` | 1 | FAIL 79/88 |
| frame | `Godot --headless --path godot/ --script res://tests/world_arenas_frame_test.gd` | 0 | PASS 14/14 |
| selection | `Godot --headless --path godot/ --script res://tests/world_arenas_selection_test.gd` | 0 | PASS 18/18 |
| selection_demo | `Godot --headless --path godot/ --script res://tests/world_arenas_selection_test.gd -- --demo` | 0 | PASS 8/8 |
| game_slice | `Godot --headless --path godot/ --script res://tests/game_slice_test.gd` | 1 | FAIL 344/345 |
| game_slice_demo | `Godot --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo` | 1 | FAIL 295/296 |
| arena_selector | `Godot --headless --path godot/ --script res://tests/ui/arena_selector_contract_test.gd` | 0 | PASS 30/30 |
| screen_audit | `Godot --headless --path godot/ --script res://tests/ui/screen_arena_audit.gd` | 0 | PASS 180/180 |

### After the flip and the rewrite (`/tmp/kit-suites-after`, `/tmp/kit-suites-final`)

| suite | exit | before | after |
|---|---|---|---|
| field_law | 1 | FAIL 79/88 | FAIL 79/88 (identical first failure: `medina` mounted mesh z=−12.07..−9.63 over the court) |
| frame | 0 | PASS 14/14 | PASS 14/14 |
| selection | 0 | PASS 18/18 | PASS 18/18 |
| selection_demo | 0 | PASS 8/8 | PASS 8/8 |
| game_slice | 1 | FAIL 344/345 | FAIL 344/345 (`locale table sizes match the reference (688 keys each)`, got it=689 en=689 — not an arena/kit check) |
| game_slice_demo | 1 | FAIL 295/296 | FAIL 295/296 (same locale check) |
| arena_selector | 0 | PASS 30/30 | PASS 30/30 |
| screen_audit | 0 | PASS 180/180 | PASS 180/180 |
| arena_kit (intake, rewritten) | 1 | FAIL 62/83 (old suite, sandbox: it deleted GLBs) | FAIL 247/251 (4 real gate failures, 0 script errors) |
| mount_census (new tool) | 1 | — | CENSUS_VERDICT FAIL (the four red gates above) |

The suppress flip changed **no** frozen suite: identical tallies and identical first failures before
and after. Two reds are not mine to fix and both predate this wave:

- `field_law` 79/88 — the mounted meshes of `medina`/`carioca`/`aurora`/`egeo` crossing the glass plane
  and the court footprint (verified green at 88/88 in the last pre-kit proof runs:
  `tools/world-arenas/out/{merge-01,refinement-01,ceo-final-01}/results.tsv`).
- `game_slice`/`game_slice_demo` — one locale-table check (689 vs 688 keys), a different lane, red with
  and without the kit.

### The rewritten intake suite (`res://tests/arena_kit_test.gd`, exit 1, FAIL 247/251)

| failing check | measured |
|---|---|
| `mount/every_mounted_box_sits_on_its_repeat_offset` | `aurora/furniture` pieces centre x=12.165/14.315 where the plan says 12.631/14.781 — drift −0.466 m, the model's own x asymmetry |
| `mount/every_piece_fits_the_depth_budget` | the 7 slots in §6 |
| `mount/every_piece_stays_behind_the_measured_glass_plane` | medina 4, carioca 5, aurora 7, egeo 1 pieces |
| `mount/no_mounted_piece_covers_the_court` | the same pieces, measured in screen rows |

Green in that suite: mount contract (anchor/size/count/repeat offsets), the −8.0 m field-law plane,
the authored frame, material policy, the empty-kit path, the suppressing ⇔ `kinds` rule, determinism,
and the two invariant audits it re-runs headlessly. The suite fingerprints the GLBs before and after
its own run, so a destructive edit fails the suite instead of passing it.

## 6. GLB mesh vs declared footprint

Uniform scaling to `target_h` makes the height match by construction; the x/z proportions are what the
GLB carries. 43 of 50 slots differ from the declared footprint by more than 0.25 m on some axis; in 7
of them the difference is big enough to break a gate:

| arena | slot | declared w×h×d | measured w×h×d | Δd | breaks |
|---|---|---|---|---|---|
| aurora | furniture | 1.4×0.9×0.95 | 1.60×0.90×2.57 | +1.62 | glass plane |
| aurora | hero_landmark | 3.6×4.0×2.0 | 4.00×4.00×3.84 | +1.84 | depth budget, glass plane |
| aurora | light_source | 0.5×1.6×0.55 | 1.90×1.60×1.90 | +1.35 | glass plane |
| carioca | hero_landmark | 4.0×3.6×2.2 | 3.71×3.60×3.71 | +1.51 | depth budget, glass plane |
| carioca | ornament_accent | 0.7×0.8×0.25 | 3.62×0.85×3.62 | +3.37 | depth budget, glass plane |
| egeo | hero_landmark | 4.2×3.7×2.3 | 3.96×3.70×3.93 | +1.63 | depth budget, glass plane |
| medina | ornament_accent | 0.8×1.0×0.22 | 2.43×1.00×2.43 | +2.21 | glass plane |

(`medina hero_landmark` is also worth naming: declared 3.0×3.9×2.0 but measured 0.73×3.90×0.72 — a slim
minaret shaft where the table assumes a 3 m mass. It breaks no gate, but the plan and the mesh do not
describe the same object.)

## 7. What I could not verify

- **No rendered frames.** Everything above is headless geometry. Whether the band now *looks* clean at
  1280×720 is a capture/judgement matter — the pass to run is
  `Godot --path godot --rendering-driver opengl3 --resolution 1280x720 res://tests/world_arenas_capture.tscn -- --out=<dir>`
  (windowed, so it needs the machine free; not run here).
- **The other presets.** All numbers are the `default` preset (x_scale 1.3437).
- **Whether the 2D plan's rectangles are meant to match the meshes.** The plan is built from these same
  declared numbers, so the 43 disagreements above are plan-vs-mesh gaps that a second captain's plan
  inherits; deciding who yields (art or spec) is not mine.
- **Anything behind the backdrop or outside the camera.** No pixels, no occlusion testing.

## 8. Decisions this needs

The doubling is fixed and the mount is clean; the four red gates are the art disagreeing with the
declared footprints of 7 slots. Only the owner can pick:

1. **Re-generate those 7 models** to the declared footprints (art lane), or
2. **Re-anchor/re-depth those 7 slots** in the SPECS table (then the 2D plan built from those numbers
   must be rebuilt — forbidden for this task, and it is exactly why the flags, not the numbers, were
   changed today), or
3. **Accept the intruding meshes** and amend the gate (the field law the mission set is z ≤ −8.0 and
   every mounted instance passes it; the stricter −10.02 glass plane is the one that fails).

