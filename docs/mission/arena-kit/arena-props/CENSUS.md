# CENSUS — arena prop mount, engine-measured, before and after the suppression flip

Engine `/Applications/Godot.app/Contents/MacOS/Godot` (`v4.7.2.stable.official.ed1daf0bf`, project `godot/`).
Tool `tools/arena-kit/mount_census.gd` builds each arena through `ArenaScenery.build()` with the kit on,
then walks the real node tree (`Dressing_*` containers, the `Kit/<Arena>/*` slot holders, every
`MeshInstance3D`) and measures real bounding boxes (`ArenaKit.node_bounds`), the real glass panes, and
the real screen rows from the default camera. Nothing here is asserted from the tables — every number
below is read back off the built scene.

```
run/tmp/arena-kit/bin/flock -w 900 /tmp/padel-godot.lock \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
  --script tools/arena-kit/mount_census.gd -- --mode=both --out=<file.json>
```

`--mode=both` builds every arena twice in one process: **before** = each slot's `suppress` forced off
(the additive kit as it shipped), **after** = the table as it now stands (16 slots suppressed, 34 not).
Nothing else differs between the passes, so every delta below is caused by the suppress flags alone.

## 1. Headline — the doubling

| arena | doubling slots before | after | doubled procedural meshes before | after | mounted pieces before → after |
|---|---|---|---|---|---|
| torii | 4 | 0 | 89 | 0 | 27 → 27 |
| medina | 5 | 0 | 92 | 0 | 31 → 31 |
| carioca | 3 | 0 | 51 | 0 | 30 → 30 |
| aurora | 2 | 0 | 32 | 0 | 28 → 28 |
| egeo | 2 | 0 | 32 | 0 | 29 → 29 |
| **total** | **16** | **0** | **296** | **0** | **145 → 145** |

A *doubling slot* is a slot with a GLB in place whose `kinds` list names procedural containers that the
same `build()` call still constructs. *Doubled meshes* counts the real `MeshInstance3D`s under exactly
those containers. All 145 mounted pieces, their transforms and their counts are identical in both
passes: the flag changes what the procedural pass emits, never the mount.

## 2. Per-slot census — BEFORE the flip (all 50 flags off)

| arena | slot | kinds | procedural containers | procedural meshes | mounted pieces | doubling |
|---|---|---|---|---|---|---|
| torii | hero_landmark | pagoda | 1 | 13 | 1 | **YES** |
| torii | gate_portal | torii | 5 | 30 | 1 | **YES** |
| torii | light_source | lantern | 4 | 16 | 3 | **YES** |
| torii | vegetation_cluster | petal | 5 | 30 | 2 | **YES** |
| torii | ground_dressing | — | 0 | 0 | 2 | — |
| torii | ornament_accent | — | 0 | 0 | 4 | — |
| torii | column_pillar | — | 0 | 0 | 4 | — |
| torii | railing_segment | — | 0 | 0 | 6 | — |
| torii | furniture | — | 0 | 0 | 2 | — |
| torii | signage_banner | — | 0 | 0 | 2 | — |
| medina | hero_landmark | minaret | 1 | 6 | 1 | **YES** |
| medina | gate_portal | arch | 1 | 5 | 1 | **YES** |
| medina | light_source | lantern | 3 | 12 | 4 | **YES** |
| medina | vegetation_cluster | palm | 5 | 45 | 2 | **YES** |
| medina | ground_dressing | — | 0 | 0 | 3 | — |
| medina | ornament_accent | zellige | 1 | 24 | 4 | **YES** |
| medina | column_pillar | — | 0 | 0 | 5 | — |
| medina | railing_segment | — | 0 | 0 | 6 | — |
| medina | furniture | — | 0 | 0 | 3 | — |
| medina | signage_banner | — | 0 | 0 | 2 | — |
| carioca | hero_landmark | peak | 2 | 6 | 1 | **YES** |
| carioca | gate_portal | — | 0 | 0 | 1 | — |
| carioca | light_source | — | 0 | 0 | 3 | — |
| carioca | vegetation_cluster | palm | 4 | 36 | 3 | **YES** |
| carioca | ground_dressing | foam | 3 | 9 | 2 | **YES** |
| carioca | ornament_accent | — | 0 | 0 | 4 | — |
| carioca | column_pillar | — | 0 | 0 | 4 | — |
| carioca | railing_segment | — | 0 | 0 | 6 | — |
| carioca | furniture | — | 0 | 0 | 3 | — |
| carioca | signage_banner | — | 0 | 0 | 3 | — |
| aurora | hero_landmark | snowridge | 1 | 8 | 1 | **YES** |
| aurora | gate_portal | — | 0 | 0 | 1 | — |
| aurora | light_source | — | 0 | 0 | 4 | — |
| aurora | vegetation_cluster | — | 0 | 0 | 2 | — |
| aurora | ground_dressing | basalt | 2 | 24 | 3 | **YES** |
| aurora | ornament_accent | — | 0 | 0 | 4 | — |
| aurora | column_pillar | — | 0 | 0 | 4 | — |
| aurora | railing_segment | — | 0 | 0 | 5 | — |
| aurora | furniture | — | 0 | 0 | 2 | — |
| aurora | signage_banner | — | 0 | 0 | 2 | — |
| egeo | hero_landmark | island | 2 | 18 | 1 | **YES** |
| egeo | gate_portal | — | 0 | 0 | 1 | — |
| egeo | light_source | — | 0 | 0 | 3 | — |
| egeo | vegetation_cluster | bougainvillea | 2 | 14 | 2 | **YES** |
| egeo | ground_dressing | — | 0 | 0 | 2 | — |
| egeo | ornament_accent | — | 0 | 0 | 4 | — |
| egeo | column_pillar | — | 0 | 0 | 5 | — |
| egeo | railing_segment | — | 0 | 0 | 6 | — |
| egeo | furniture | — | 0 | 0 | 3 | — |
| egeo | signage_banner | — | 0 | 0 | 2 | — |

## 3. Per-slot census — AFTER the flip

| arena | slot | suppress | kinds | procedural containers | proc. meshes | mounted pieces | doubling |
|---|---|---|---|---|---|---|---|
| torii | hero_landmark | **ON** | pagoda | 1 | 0 | 1 | — |
| torii | gate_portal | **ON** | torii | 5 | 0 | 1 | — |
| torii | light_source | **ON** | lantern | 4 | 0 | 3 | — |
| torii | vegetation_cluster | **ON** | petal | 5 | 0 | 2 | — |
| torii | ground_dressing | off | — | 0 | 0 | 2 | — |
| torii | ornament_accent | off | — | 0 | 0 | 4 | — |
| torii | column_pillar | off | — | 0 | 0 | 4 | — |
| torii | railing_segment | off | — | 0 | 0 | 6 | — |
| torii | furniture | off | — | 0 | 0 | 2 | — |
| torii | signage_banner | off | — | 0 | 0 | 2 | — |
| medina | hero_landmark | **ON** | minaret | 1 | 0 | 1 | — |
| medina | gate_portal | **ON** | arch | 1 | 0 | 1 | — |
| medina | light_source | **ON** | lantern | 3 | 0 | 4 | — |
| medina | vegetation_cluster | **ON** | palm | 5 | 0 | 2 | — |
| medina | ground_dressing | off | — | 0 | 0 | 3 | — |
| medina | ornament_accent | **ON** | zellige | 1 | 0 | 4 | — |
| medina | column_pillar | off | — | 0 | 0 | 5 | — |
| medina | railing_segment | off | — | 0 | 0 | 6 | — |
| medina | furniture | off | — | 0 | 0 | 3 | — |
| medina | signage_banner | off | — | 0 | 0 | 2 | — |
| carioca | hero_landmark | **ON** | peak | 2 | 0 | 1 | — |
| carioca | gate_portal | off | — | 0 | 0 | 1 | — |
| carioca | light_source | off | — | 0 | 0 | 3 | — |
| carioca | vegetation_cluster | **ON** | palm | 4 | 0 | 3 | — |
| carioca | ground_dressing | **ON** | foam | 3 | 0 | 2 | — |
| carioca | ornament_accent | off | — | 0 | 0 | 4 | — |
| carioca | column_pillar | off | — | 0 | 0 | 4 | — |
| carioca | railing_segment | off | — | 0 | 0 | 6 | — |
| carioca | furniture | off | — | 0 | 0 | 3 | — |
| carioca | signage_banner | off | — | 0 | 0 | 3 | — |
| aurora | hero_landmark | **ON** | snowridge | 1 | 0 | 1 | — |
| aurora | gate_portal | off | — | 0 | 0 | 1 | — |
| aurora | light_source | off | — | 0 | 0 | 4 | — |
| aurora | vegetation_cluster | off | — | 0 | 0 | 2 | — |
| aurora | ground_dressing | **ON** | basalt | 2 | 0 | 3 | — |
| aurora | ornament_accent | off | — | 0 | 0 | 4 | — |
| aurora | column_pillar | off | — | 0 | 0 | 4 | — |
| aurora | railing_segment | off | — | 0 | 0 | 5 | — |
| aurora | furniture | off | — | 0 | 0 | 2 | — |
| aurora | signage_banner | off | — | 0 | 0 | 2 | — |
| egeo | hero_landmark | **ON** | island | 2 | 0 | 1 | — |
| egeo | gate_portal | off | — | 0 | 0 | 1 | — |
| egeo | light_source | off | — | 0 | 0 | 3 | — |
| egeo | vegetation_cluster | **ON** | bougainvillea | 2 | 0 | 2 | — |
| egeo | ground_dressing | off | — | 0 | 0 | 2 | — |
| egeo | ornament_accent | off | — | 0 | 0 | 4 | — |
| egeo | column_pillar | off | — | 0 | 0 | 5 | — |
| egeo | railing_segment | off | — | 0 | 0 | 6 | — |
| egeo | furniture | off | — | 0 | 0 | 3 | — |
| egeo | signage_banner | off | — | 0 | 0 | 2 | — |

Every suppressed slot keeps its `Dressing_*` container and every unsuppressed kind keeps its meshes;
`dressing` container counts are identical before and after in all five arenas:

| arena | authored props | dressing containers before | after |
|---|---|---|---|
| torii | 16 | 16 | 16 |
| medina | 13 | 13 | 13 |
| carioca | 14 | 14 | 14 |
| aurora | 13 | 13 | 13 |
| egeo | 7 | 7 | 7 |
## 4. Mounted instances — every piece, measured (after)

145 mounted pieces. `depth` = measured z extent vs the 3.26 m budget; `law` = front z ≤ −8.0;
`glass` = front z ≤ the measured glass plane (−10.02 m here); `frame` = authored-space x inside
±14.35 m (authored metres = built metres ÷ x_scale); `scr` = the box inside the 1280×720 frame and
above the rear baseline's own screen row.

### torii — x_scale 1.3437, glass plane measured at -10.02 m

| slot / piece | measured h | w | d | declared d | depth | front z | law | glass | frame | scr | authored x |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hero_landmark/Piece | 4.00 | 1.52 | 1.56 | 2.20 | ✓ | -10.52 | ✓ | ✓ | ✓ | ✓ | -3.77..-2.63 |
| gate_portal/Piece | 2.60 | 2.77 | 0.50 | 0.90 | ✓ | -10.85 | ✓ | ✓ | ✓ | ✓ | +2.97..+5.03 |
| light_source/Piece_1 | 1.15 | 0.58 | 0.58 | 0.50 | ✓ | -10.76 | ✓ | ✓ | ✓ | ✓ | -10.11..-9.68 |
| light_source/Piece_2 | 1.15 | 0.58 | 0.58 | 0.50 | ✓ | -10.76 | ✓ | ✓ | ✓ | ✓ | -8.61..-8.18 |
| light_source/Piece_3 | 1.15 | 0.58 | 0.58 | 0.50 | ✓ | -10.76 | ✓ | ✓ | ✓ | ✓ | -7.11..-6.68 |
| vegetation_cluster/Piece_1 | 2.60 | 2.70 | 1.30 | 1.40 | ✓ | -10.80 | ✓ | ✓ | ✓ | ✓ | -12.10..-10.10 |
| vegetation_cluster/Piece_2 | 2.60 | 2.70 | 1.30 | 1.40 | ✓ | -10.80 | ✓ | ✓ | ✓ | ✓ | -10.30..-8.30 |
| ground_dressing/Piece_1 | 0.55 | 1.35 | 1.25 | 0.70 | ✓ | -10.12 | ✓ | ✓ | ✓ | ✓ | +5.00..+6.00 |
| ground_dressing/Piece_2 | 0.55 | 1.35 | 1.25 | 0.70 | ✓ | -10.12 | ✓ | ✓ | ✓ | ✓ | +7.20..+8.20 |
| ornament_accent/Piece_1 | 0.90 | 0.76 | 0.73 | 0.25 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -0.83..-0.27 |
| ornament_accent/Piece_2 | 0.90 | 0.76 | 0.73 | 0.25 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | +0.07..+0.63 |
| ornament_accent/Piece_3 | 0.90 | 0.76 | 0.73 | 0.25 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | +0.97..+1.53 |
| ornament_accent/Piece_4 | 0.90 | 0.76 | 0.73 | 0.25 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | +1.87..+2.43 |
| column_pillar/Piece_1 | 2.60 | 0.56 | 0.42 | 0.50 | ✓ | -10.74 | ✓ | ✓ | ✓ | ✓ | +8.19..+8.61 |
| column_pillar/Piece_2 | 2.60 | 0.56 | 0.42 | 0.50 | ✓ | -10.74 | ✓ | ✓ | ✓ | ✓ | +8.99..+9.41 |
| column_pillar/Piece_3 | 2.60 | 0.56 | 0.42 | 0.50 | ✓ | -10.74 | ✓ | ✓ | ✓ | ✓ | +9.79..+10.21 |
| column_pillar/Piece_4 | 2.60 | 0.56 | 0.42 | 0.50 | ✓ | -10.74 | ✓ | ✓ | ✓ | ✓ | +10.59..+11.01 |
| railing_segment/Piece_1 | 1.05 | 1.62 | 0.26 | 0.30 | ✓ | -10.57 | ✓ | ✓ | ✓ | ✓ | -9.55..-8.35 |
| railing_segment/Piece_2 | 1.05 | 1.62 | 0.26 | 0.30 | ✓ | -10.57 | ✓ | ✓ | ✓ | ✓ | -8.45..-7.25 |
| railing_segment/Piece_3 | 1.05 | 1.62 | 0.26 | 0.30 | ✓ | -10.57 | ✓ | ✓ | ✓ | ✓ | -7.35..-6.15 |
| railing_segment/Piece_4 | 1.05 | 1.62 | 0.26 | 0.30 | ✓ | -10.57 | ✓ | ✓ | ✓ | ✓ | -6.25..-5.05 |
| railing_segment/Piece_5 | 1.05 | 1.62 | 0.26 | 0.30 | ✓ | -10.57 | ✓ | ✓ | ✓ | ✓ | -5.15..-3.95 |
| railing_segment/Piece_6 | 1.05 | 1.62 | 0.26 | 0.30 | ✓ | -10.57 | ✓ | ✓ | ✓ | ✓ | -4.05..-2.85 |
| furniture/Piece_1 | 0.95 | 3.02 | 0.89 | 0.80 | ✓ | -10.36 | ✓ | ✓ | ✓ | ✓ | +0.68..+2.92 |
| furniture/Piece_2 | 0.95 | 3.02 | 0.89 | 0.80 | ✓ | -10.36 | ✓ | ✓ | ✓ | ✓ | +2.28..+4.52 |
| signage_banner/Piece_1 | 1.40 | 0.86 | 0.36 | 0.12 | ✓ | -10.74 | ✓ | ✓ | ✓ | ✓ | -2.32..-1.68 |
| signage_banner/Piece_2 | 1.40 | 0.86 | 0.36 | 0.12 | ✓ | -10.74 | ✓ | ✓ | ✓ | ✓ | -1.12..-0.48 |

### medina — x_scale 1.3437, glass plane measured at -10.02 m

| slot / piece | measured h | w | d | declared d | depth | front z | law | glass | frame | scr | authored x |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hero_landmark/Piece | 3.90 | 0.73 | 0.72 | 2.00 | ✓ | -10.99 | ✓ | ✓ | ✓ | ✓ | -4.47..-3.93 |
| gate_portal/Piece | 2.80 | 2.37 | 0.68 | 1.00 | ✓ | -10.81 | ✓ | ✓ | ✓ | ✓ | +2.72..+4.49 |
| light_source/Piece_1 | 1.30 | 0.44 | 0.38 | 0.45 | ✓ | -10.81 | ✓ | ✓ | ✓ | ✓ | -10.07..-9.73 |
| light_source/Piece_2 | 1.30 | 0.44 | 0.38 | 0.45 | ✓ | -10.81 | ✓ | ✓ | ✓ | ✓ | -8.67..-8.33 |
| light_source/Piece_3 | 1.30 | 0.44 | 0.38 | 0.45 | ✓ | -10.81 | ✓ | ✓ | ✓ | ✓ | -7.27..-6.93 |
| light_source/Piece_4 | 1.30 | 0.44 | 0.38 | 0.45 | ✓ | -10.81 | ✓ | ✓ | ✓ | ✓ | -5.87..-5.53 |
| vegetation_cluster/Piece_1 | 2.70 | 2.13 | 1.10 | 1.50 | ✓ | -10.95 | ✓ | ✓ | ✓ | ✓ | -12.39..-10.80 |
| vegetation_cluster/Piece_2 | 2.70 | 2.13 | 1.10 | 1.50 | ✓ | -10.95 | ✓ | ✓ | ✓ | ✓ | -10.39..-8.80 |
| ground_dressing/Piece_1 | 0.60 | 0.70 | 0.75 | 0.80 | ✓ | -10.32 | ✓ | ✓ | ✓ | ✓ | +3.54..+4.06 |
| ground_dressing/Piece_2 | 0.60 | 0.70 | 0.75 | 0.80 | ✓ | -10.32 | ✓ | ✓ | ✓ | ✓ | +5.54..+6.06 |
| ground_dressing/Piece_3 | 0.60 | 0.70 | 0.75 | 0.80 | ✓ | -10.32 | ✓ | ✓ | ✓ | ✓ | +7.54..+8.06 |
| ornament_accent/Piece_1 | 1.00 | 2.43 | 2.43 | 0.22 | ✓ | -9.63 | ✓ | **✗** | ✓ | **✗** | -2.01..-0.19 |
| ornament_accent/Piece_2 | 1.00 | 2.43 | 2.43 | 0.22 | ✓ | -9.63 | ✓ | **✗** | ✓ | **✗** | -1.01..+0.81 |
| ornament_accent/Piece_3 | 1.00 | 2.43 | 2.43 | 0.22 | ✓ | -9.63 | ✓ | **✗** | ✓ | **✗** | -0.01..+1.81 |
| ornament_accent/Piece_4 | 1.00 | 2.43 | 2.43 | 0.22 | ✓ | -9.63 | ✓ | **✗** | ✓ | **✗** | +0.99..+2.81 |
| column_pillar/Piece_1 | 2.70 | 0.83 | 0.41 | 0.55 | ✓ | -10.69 | ✓ | ✓ | ✓ | ✓ | +6.79..+7.41 |
| column_pillar/Piece_2 | 2.70 | 0.83 | 0.41 | 0.55 | ✓ | -10.69 | ✓ | ✓ | ✓ | ✓ | +7.64..+8.26 |
| column_pillar/Piece_3 | 2.70 | 0.83 | 0.41 | 0.55 | ✓ | -10.69 | ✓ | ✓ | ✓ | ✓ | +8.49..+9.11 |
| column_pillar/Piece_4 | 2.70 | 0.83 | 0.41 | 0.55 | ✓ | -10.69 | ✓ | ✓ | ✓ | ✓ | +9.34..+9.96 |
| column_pillar/Piece_5 | 2.70 | 0.83 | 0.41 | 0.55 | ✓ | -10.69 | ✓ | ✓ | ✓ | ✓ | +10.19..+10.81 |
| railing_segment/Piece_1 | 1.15 | 1.70 | 0.23 | 0.30 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -9.11..-7.84 |
| railing_segment/Piece_2 | 1.15 | 1.70 | 0.23 | 0.30 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -7.96..-6.69 |
| railing_segment/Piece_3 | 1.15 | 1.70 | 0.23 | 0.30 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -6.81..-5.54 |
| railing_segment/Piece_4 | 1.15 | 1.70 | 0.23 | 0.30 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -5.66..-4.39 |
| railing_segment/Piece_5 | 1.15 | 1.70 | 0.23 | 0.30 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -4.51..-3.24 |
| railing_segment/Piece_6 | 1.15 | 1.70 | 0.23 | 0.30 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -3.36..-2.09 |
| furniture/Piece_1 | 0.95 | 1.42 | 1.42 | 0.85 | ✓ | -10.04 | ✓ | ✓ | ✓ | ✓ | +0.37..+1.43 |
| furniture/Piece_2 | 0.95 | 1.42 | 1.42 | 0.85 | ✓ | -10.04 | ✓ | ✓ | ✓ | ✓ | +1.67..+2.73 |
| furniture/Piece_3 | 0.95 | 1.42 | 1.42 | 0.85 | ✓ | -10.04 | ✓ | ✓ | ✓ | ✓ | +2.97..+4.03 |
| signage_banner/Piece_1 | 1.30 | 2.28 | 1.23 | 0.12 | ✓ | -10.27 | ✓ | ✓ | ✓ | ✓ | -3.00..-1.30 |
| signage_banner/Piece_2 | 1.30 | 2.28 | 1.23 | 0.12 | ✓ | -10.27 | ✓ | ✓ | ✓ | ✓ | -1.90..-0.20 |

### carioca — x_scale 1.3437, glass plane measured at -10.02 m

| slot / piece | measured h | w | d | declared d | depth | front z | law | glass | frame | scr | authored x |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hero_landmark/Piece | 3.60 | 3.71 | 3.71 | 2.20 | **✗** | -9.55 | ✓ | **✗** | ✓ | **✗** | +3.22..+5.98 |
| gate_portal/Piece | 2.40 | 2.57 | 0.60 | 0.90 | ✓ | -10.80 | ✓ | ✓ | ✓ | ✓ | -4.95..-3.05 |
| light_source/Piece_1 | 1.50 | 2.77 | 0.38 | 0.50 | ✓ | -10.76 | ✓ | ✓ | ✓ | ✓ | +4.87..+6.93 |
| light_source/Piece_2 | 1.50 | 2.77 | 0.38 | 0.50 | ✓ | -10.76 | ✓ | ✓ | ✓ | ✓ | +6.57..+8.63 |
| light_source/Piece_3 | 1.50 | 2.77 | 0.38 | 0.50 | ✓ | -10.76 | ✓ | ✓ | ✓ | ✓ | +8.27..+10.33 |
| vegetation_cluster/Piece_1 | 2.50 | 2.40 | 1.58 | 1.80 | ✓ | -10.61 | ✓ | ✓ | ✓ | ✓ | -12.39..-10.61 |
| vegetation_cluster/Piece_2 | 2.50 | 2.40 | 1.58 | 1.80 | ✓ | -10.61 | ✓ | ✓ | ✓ | ✓ | -10.69..-8.91 |
| vegetation_cluster/Piece_3 | 2.50 | 2.40 | 1.58 | 1.80 | ✓ | -10.61 | ✓ | ✓ | ✓ | ✓ | -8.99..-7.21 |
| ground_dressing/Piece_1 | 0.50 | 0.88 | 0.84 | 1.00 | ✓ | -10.28 | ✓ | ✓ | ✓ | ✓ | +2.57..+3.23 |
| ground_dressing/Piece_2 | 0.50 | 0.88 | 0.84 | 1.00 | ✓ | -10.28 | ✓ | ✓ | ✓ | ✓ | +5.17..+5.83 |
| ornament_accent/Piece_1 | 0.85 | 3.62 | 3.62 | 0.25 | **✗** | -8.99 | ✓ | **✗** | ✓ | **✗** | -4.00..-1.30 |
| ornament_accent/Piece_2 | 0.85 | 3.62 | 3.62 | 0.25 | **✗** | -8.99 | ✓ | **✗** | ✓ | **✗** | -2.90..-0.20 |
| ornament_accent/Piece_3 | 0.85 | 3.62 | 3.62 | 0.25 | **✗** | -8.99 | ✓ | **✗** | ✓ | **✗** | -1.80..+0.90 |
| ornament_accent/Piece_4 | 0.85 | 3.62 | 3.62 | 0.25 | **✗** | -8.99 | ✓ | **✗** | ✓ | **✗** | -0.70..+2.00 |
| column_pillar/Piece_1 | 2.60 | 0.49 | 0.44 | 0.55 | ✓ | -10.63 | ✓ | ✓ | ✓ | ✓ | -8.73..-8.37 |
| column_pillar/Piece_2 | 2.60 | 0.49 | 0.44 | 0.55 | ✓ | -10.63 | ✓ | ✓ | ✓ | ✓ | -7.83..-7.47 |
| column_pillar/Piece_3 | 2.60 | 0.49 | 0.44 | 0.55 | ✓ | -10.63 | ✓ | ✓ | ✓ | ✓ | -6.93..-6.57 |
| column_pillar/Piece_4 | 2.60 | 0.49 | 0.44 | 0.55 | ✓ | -10.63 | ✓ | ✓ | ✓ | ✓ | -6.03..-5.67 |
| railing_segment/Piece_1 | 1.00 | 1.51 | 0.29 | 0.30 | ✓ | -10.41 | ✓ | ✓ | ✓ | ✓ | -2.16..-1.04 |
| railing_segment/Piece_2 | 1.00 | 1.51 | 0.29 | 0.30 | ✓ | -10.41 | ✓ | ✓ | ✓ | ✓ | -0.96..+0.16 |
| railing_segment/Piece_3 | 1.00 | 1.51 | 0.29 | 0.30 | ✓ | -10.41 | ✓ | ✓ | ✓ | ✓ | +0.24..+1.36 |
| railing_segment/Piece_4 | 1.00 | 1.51 | 0.29 | 0.30 | ✓ | -10.41 | ✓ | ✓ | ✓ | ✓ | +1.44..+2.56 |
| railing_segment/Piece_5 | 1.00 | 1.51 | 0.29 | 0.30 | ✓ | -10.41 | ✓ | ✓ | ✓ | ✓ | +2.64..+3.76 |
| railing_segment/Piece_6 | 1.00 | 1.51 | 0.29 | 0.30 | ✓ | -10.41 | ✓ | ✓ | ✓ | ✓ | +3.84..+4.96 |
| furniture/Piece_1 | 0.90 | 0.80 | 1.05 | 0.90 | ✓ | -10.33 | ✓ | ✓ | ✓ | ✓ | +7.70..+8.30 |
| furniture/Piece_2 | 0.90 | 0.80 | 1.05 | 0.90 | ✓ | -10.33 | ✓ | ✓ | ✓ | ✓ | +9.10..+9.70 |
| furniture/Piece_3 | 0.90 | 0.80 | 1.05 | 0.90 | ✓ | -10.33 | ✓ | ✓ | ✓ | ✓ | +10.50..+11.10 |
| signage_banner/Piece_1 | 1.20 | 0.78 | 0.09 | 0.12 | ✓ | -10.75 | ✓ | ✓ | ✓ | ✓ | -3.99..-3.41 |
| signage_banner/Piece_2 | 1.20 | 0.78 | 0.09 | 0.12 | ✓ | -10.75 | ✓ | ✓ | ✓ | ✓ | -2.69..-2.11 |
| signage_banner/Piece_3 | 1.20 | 0.78 | 0.09 | 0.12 | ✓ | -10.75 | ✓ | ✓ | ✓ | ✓ | -1.39..-0.81 |

### aurora — x_scale 1.3437, glass plane measured at -10.02 m

| slot / piece | measured h | w | d | declared d | depth | front z | law | glass | frame | scr | authored x |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hero_landmark/Piece | 4.00 | 4.00 | 3.84 | 2.00 | **✗** | -9.53 | ✓ | **✗** | ✓ | **✗** | -6.49..-3.51 |
| gate_portal/Piece | 2.20 | 1.70 | 1.72 | 0.80 | ✓ | -10.19 | ✓ | ✓ | ✓ | ✓ | +2.57..+3.83 |
| light_source/Piece_1 | 1.60 | 1.90 | 1.90 | 0.55 | ✓ | -9.95 | ✓ | **✗** | ✓ | **✗** | -11.76..-10.34 |
| light_source/Piece_2 | 1.60 | 1.90 | 1.90 | 0.55 | ✓ | -9.95 | ✓ | **✗** | ✓ | **✗** | -10.26..-8.84 |
| light_source/Piece_3 | 1.60 | 1.90 | 1.90 | 0.55 | ✓ | -9.95 | ✓ | **✗** | ✓ | **✗** | -8.76..-7.34 |
| light_source/Piece_4 | 1.60 | 1.90 | 1.90 | 0.55 | ✓ | -9.95 | ✓ | **✗** | ✓ | **✗** | -7.26..-5.84 |
| vegetation_cluster/Piece_1 | 1.90 | 2.36 | 2.36 | 1.60 | ✓ | -10.17 | ✓ | ✓ | ✓ | ✓ | +6.62..+8.38 |
| vegetation_cluster/Piece_2 | 1.90 | 2.36 | 2.36 | 1.60 | ✓ | -10.17 | ✓ | ✓ | ✓ | ✓ | +8.82..+10.58 |
| ground_dressing/Piece_1 | 0.70 | 0.66 | 0.59 | 0.90 | ✓ | -10.35 | ✓ | ✓ | ✓ | ✓ | -5.45..-4.95 |
| ground_dressing/Piece_2 | 0.70 | 0.66 | 0.59 | 0.90 | ✓ | -10.35 | ✓ | ✓ | ✓ | ✓ | -3.05..-2.55 |
| ground_dressing/Piece_3 | 0.70 | 0.66 | 0.59 | 0.90 | ✓ | -10.35 | ✓ | ✓ | ✓ | ✓ | -0.65..-0.15 |
| ornament_accent/Piece_1 | 1.10 | 0.44 | 0.14 | 0.30 | ✓ | -10.71 | ✓ | ✓ | ✓ | ✓ | -1.06..-0.74 |
| ornament_accent/Piece_2 | 1.10 | 0.44 | 0.14 | 0.30 | ✓ | -10.71 | ✓ | ✓ | ✓ | ✓ | -0.06..+0.26 |
| ornament_accent/Piece_3 | 1.10 | 0.44 | 0.14 | 0.30 | ✓ | -10.71 | ✓ | ✓ | ✓ | ✓ | +0.94..+1.26 |
| ornament_accent/Piece_4 | 1.10 | 0.44 | 0.14 | 0.30 | ✓ | -10.71 | ✓ | ✓ | ✓ | ✓ | +1.94..+2.26 |
| column_pillar/Piece_1 | 2.80 | 1.25 | 1.18 | 0.60 | ✓ | -10.29 | ✓ | ✓ | ✓ | ✓ | +3.43..+4.37 |
| column_pillar/Piece_2 | 2.80 | 1.25 | 1.18 | 0.60 | ✓ | -10.29 | ✓ | ✓ | ✓ | ✓ | +4.43..+5.37 |
| column_pillar/Piece_3 | 2.80 | 1.25 | 1.18 | 0.60 | ✓ | -10.29 | ✓ | ✓ | ✓ | ✓ | +5.43..+6.37 |
| column_pillar/Piece_4 | 2.80 | 1.25 | 1.18 | 0.60 | ✓ | -10.29 | ✓ | ✓ | ✓ | ✓ | +6.43..+7.37 |
| railing_segment/Piece_1 | 0.95 | 1.18 | 0.23 | 0.35 | ✓ | -10.39 | ✓ | ✓ | ✓ | ✓ | -6.64..-5.76 |
| railing_segment/Piece_2 | 0.95 | 1.18 | 0.23 | 0.35 | ✓ | -10.39 | ✓ | ✓ | ✓ | ✓ | -5.34..-4.46 |
| railing_segment/Piece_3 | 0.95 | 1.18 | 0.23 | 0.35 | ✓ | -10.39 | ✓ | ✓ | ✓ | ✓ | -4.04..-3.16 |
| railing_segment/Piece_4 | 0.95 | 1.18 | 0.23 | 0.35 | ✓ | -10.39 | ✓ | ✓ | ✓ | ✓ | -2.74..-1.86 |
| railing_segment/Piece_5 | 0.95 | 1.18 | 0.23 | 0.35 | ✓ | -10.39 | ✓ | ✓ | ✓ | ✓ | -1.44..-0.56 |
| furniture/Piece_1 | 0.90 | 1.60 | 2.57 | 0.95 | ✓ | -9.62 | ✓ | **✗** | ✓ | **✗** | +8.46..+9.65 |
| furniture/Piece_2 | 0.90 | 1.60 | 2.57 | 0.95 | ✓ | -9.62 | ✓ | **✗** | ✓ | **✗** | +10.06..+11.25 |
| signage_banner/Piece_1 | 1.50 | 0.93 | 0.11 | 0.12 | ✓ | -10.67 | ✓ | ✓ | ✓ | ✓ | +0.76..+1.45 |
| signage_banner/Piece_2 | 1.50 | 0.93 | 0.11 | 0.12 | ✓ | -10.67 | ✓ | ✓ | ✓ | ✓ | +2.16..+2.85 |

### egeo — x_scale 1.3437, glass plane measured at -10.02 m

| slot / piece | measured h | w | d | declared d | depth | front z | law | glass | frame | scr | authored x |
|---|---|---|---|---|---|---|---|---|---|---|---|
| hero_landmark/Piece | 3.70 | 3.96 | 3.93 | 2.30 | **✗** | -9.38 | ✓ | **✗** | ✓ | **✗** | +2.33..+5.27 |
| gate_portal/Piece | 2.50 | 1.62 | 1.70 | 0.90 | ✓ | -10.15 | ✓ | ✓ | ✓ | ✓ | -4.00..-2.80 |
| light_source/Piece_1 | 1.70 | 0.40 | 0.41 | 0.50 | ✓ | -10.70 | ✓ | ✓ | ✓ | ✓ | +5.25..+5.55 |
| light_source/Piece_2 | 1.70 | 0.40 | 0.41 | 0.50 | ✓ | -10.70 | ✓ | ✓ | ✓ | ✓ | +7.05..+7.35 |
| light_source/Piece_3 | 1.70 | 0.40 | 0.41 | 0.50 | ✓ | -10.70 | ✓ | ✓ | ✓ | ✓ | +8.85..+9.15 |
| vegetation_cluster/Piece_1 | 2.20 | 2.13 | 1.24 | 1.70 | ✓ | -10.68 | ✓ | ✓ | ✓ | ✓ | -11.19..-9.60 |
| vegetation_cluster/Piece_2 | 2.20 | 2.13 | 1.24 | 1.70 | ✓ | -10.68 | ✓ | ✓ | ✓ | ✓ | -9.19..-7.60 |
| ground_dressing/Piece_1 | 0.55 | 0.89 | 0.83 | 0.95 | ✓ | -10.27 | ✓ | ✓ | ✓ | ✓ | +4.07..+4.73 |
| ground_dressing/Piece_2 | 0.55 | 0.89 | 0.83 | 0.95 | ✓ | -10.27 | ✓ | ✓ | ✓ | ✓ | +6.47..+7.13 |
| ornament_accent/Piece_1 | 0.95 | 1.89 | 1.29 | 0.30 | ✓ | -10.12 | ✓ | ✓ | ✓ | ✓ | -3.00..-1.60 |
| ornament_accent/Piece_2 | 0.95 | 1.89 | 1.29 | 0.30 | ✓ | -10.12 | ✓ | ✓ | ✓ | ✓ | -2.00..-0.60 |
| ornament_accent/Piece_3 | 0.95 | 1.89 | 1.29 | 0.30 | ✓ | -10.12 | ✓ | ✓ | ✓ | ✓ | -1.00..+0.40 |
| ornament_accent/Piece_4 | 0.95 | 1.89 | 1.29 | 0.30 | ✓ | -10.12 | ✓ | ✓ | ✓ | ✓ | -0.00..+1.40 |
| column_pillar/Piece_1 | 2.50 | 1.13 | 0.56 | 0.50 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -8.72..-7.88 |
| column_pillar/Piece_2 | 2.50 | 1.13 | 0.56 | 0.50 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -7.87..-7.03 |
| column_pillar/Piece_3 | 2.50 | 1.13 | 0.56 | 0.50 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -7.02..-6.18 |
| column_pillar/Piece_4 | 2.50 | 1.13 | 0.56 | 0.50 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -6.17..-5.33 |
| column_pillar/Piece_5 | 2.50 | 1.13 | 0.56 | 0.50 | ✓ | -10.54 | ✓ | ✓ | ✓ | ✓ | -5.32..-4.48 |
| railing_segment/Piece_1 | 1.00 | 1.32 | 0.25 | 0.30 | ✓ | -10.40 | ✓ | ✓ | ✓ | ✓ | -2.42..-1.43 |
| railing_segment/Piece_2 | 1.00 | 1.32 | 0.25 | 0.30 | ✓ | -10.40 | ✓ | ✓ | ✓ | ✓ | -1.17..-0.18 |
| railing_segment/Piece_3 | 1.00 | 1.32 | 0.25 | 0.30 | ✓ | -10.40 | ✓ | ✓ | ✓ | ✓ | +0.08..+1.07 |
| railing_segment/Piece_4 | 1.00 | 1.32 | 0.25 | 0.30 | ✓ | -10.40 | ✓ | ✓ | ✓ | ✓ | +1.33..+2.32 |
| railing_segment/Piece_5 | 1.00 | 1.32 | 0.25 | 0.30 | ✓ | -10.40 | ✓ | ✓ | ✓ | ✓ | +2.58..+3.57 |
| railing_segment/Piece_6 | 1.00 | 1.32 | 0.25 | 0.30 | ✓ | -10.40 | ✓ | ✓ | ✓ | ✓ | +3.83..+4.82 |
| furniture/Piece_1 | 1.00 | 0.52 | 0.55 | 0.85 | ✓ | -10.58 | ✓ | ✓ | ✓ | ✓ | +8.11..+8.50 |
| furniture/Piece_2 | 1.00 | 0.52 | 0.55 | 0.85 | ✓ | -10.58 | ✓ | ✓ | ✓ | ✓ | +9.61..+10.00 |
| furniture/Piece_3 | 1.00 | 0.52 | 0.55 | 0.85 | ✓ | -10.58 | ✓ | ✓ | ✓ | ✓ | +11.11..+11.50 |
| signage_banner/Piece_1 | 1.30 | 1.16 | 0.21 | 0.12 | ✓ | -10.60 | ✓ | ✓ | ✓ | ✓ | -2.98..-2.12 |
| signage_banner/Piece_2 | 1.30 | 1.16 | 0.21 | 0.12 | ✓ | -10.60 | ✓ | ✓ | ✓ | ✓ | -1.68..-0.82 |
## 5. Gates — measured verdicts

| gate | verdict | measured value |
|---|---|---|
| doubling | **PASS** | 16 doubling slots / 296 procedural meshes → **0 / 0** |
| field-law plane, production build | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| field-law plane, closest vertex ≤ −8.0 | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| target height = spec `target_h` | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| bottom origin (box bottom on y=0) | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| frame law, authored ±14.35 m | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| material policy | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| culling: whole box inside the 1280×720 frame | **PASS** | torii=PASS medina=PASS carioca=PASS aurora=PASS egeo=PASS |
| **depth budget ≤ 3.26 m** | **FAIL** | torii=PASS medina=PASS carioca=FAIL aurora=FAIL egeo=FAIL |
| **no mesh in front of the measured glass plane** | **FAIL** | torii=PASS medina=FAIL carioca=FAIL aurora=FAIL egeo=FAIL |
| **no mesh over the court footprint** | **FAIL** | torii=PASS medina=FAIL carioca=FAIL aurora=FAIL egeo=FAIL |
| **culling: box above the rear baseline's screen row** | **FAIL** | torii=PASS medina=FAIL carioca=FAIL aurora=FAIL egeo=FAIL |

Measured glass plane this build: −10.02 m in all five arenas (6 panes each). The four failing
gates are one inherited defect measured four ways — identical offenders in the before pass — and the
offenders sit behind their anchors as placed: it is the *mesh* that is deeper than declared.

**depth over the 3.26 m budget**

- carioca: hero_landmark/Piece 3.71 m; ornament_accent/Piece_1 3.62 m; ornament_accent/Piece_2 3.62 m; ornament_accent/Piece_3 3.62 m; ornament_accent/Piece_4 3.62 m
- aurora: hero_landmark/Piece 3.84 m
- egeo: hero_landmark/Piece 3.93 m

**in front of the measured glass plane**

- medina: ornament_accent/Piece_1 front z=-9.63 (measured glass -10.02); ornament_accent/Piece_2 front z=-9.63 (measured glass -10.02); ornament_accent/Piece_3 front z=-9.63 (measured glass -10.02); ornament_accent/Piece_4 front z=-9.63 (measured glass -10.02)
- carioca: hero_landmark/Piece front z=-9.55 (measured glass -10.02); ornament_accent/Piece_1 front z=-8.99 (measured glass -10.02); ornament_accent/Piece_2 front z=-8.99 (measured glass -10.02); ornament_accent/Piece_3 front z=-8.99 (measured glass -10.02); ornament_accent/Piece_4 front z=-8.99 (measured glass -10.02)
- aurora: hero_landmark/Piece front z=-9.53 (measured glass -10.02); light_source/Piece_1 front z=-9.95 (measured glass -10.02); light_source/Piece_2 front z=-9.95 (measured glass -10.02); light_source/Piece_3 front z=-9.95 (measured glass -10.02); light_source/Piece_4 front z=-9.95 (measured glass -10.02); furniture/Piece_1 front z=-9.62 (measured glass -10.02); furniture/Piece_2 front z=-9.62 (measured glass -10.02)
- egeo: hero_landmark/Piece front z=-9.38 (measured glass -10.02)

**over the court footprint**

- medina: ornament_accent/Piece_1 z=-12.07..-9.63 x=-2.69..-0.26; ornament_accent/Piece_2 z=-12.07..-9.63 x=-1.35..+1.08; ornament_accent/Piece_3 z=-12.07..-9.63 x=-0.01..+2.43; ornament_accent/Piece_4 z=-12.07..-9.63 x=+1.34..+3.77
- carioca: hero_landmark/Piece z=-13.25..-9.55 x=+4.33..+8.04; ornament_accent/Piece_1 z=-12.61..-8.99 x=-5.37..-1.75; ornament_accent/Piece_2 z=-12.61..-8.99 x=-3.89..-0.27; ornament_accent/Piece_3 z=-12.61..-8.99 x=-2.41..+1.20; ornament_accent/Piece_4 z=-12.61..-8.99 x=-0.94..+2.68
- aurora: hero_landmark/Piece z=-13.37..-9.53 x=-8.72..-4.72
- egeo: hero_landmark/Piece z=-13.32..-9.38 x=+3.12..+7.09

**lowest screen row below the rear baseline row**

- medina: ornament_accent/Piece_1 row=177.8 baseline=172.3; ornament_accent/Piece_2 row=177.8 baseline=172.3; ornament_accent/Piece_3 row=177.8 baseline=172.3; ornament_accent/Piece_4 row=177.8 baseline=172.3
- carioca: hero_landmark/Piece row=179.2 baseline=172.3; ornament_accent/Piece_1 row=187.9 baseline=172.3; ornament_accent/Piece_2 row=187.9 baseline=172.3; ornament_accent/Piece_3 row=187.9 baseline=172.3; ornament_accent/Piece_4 row=187.9 baseline=172.3
- aurora: hero_landmark/Piece row=179.5 baseline=172.3; light_source/Piece_1 row=173.0 baseline=172.3; light_source/Piece_2 row=173.0 baseline=172.3; light_source/Piece_3 row=173.0 baseline=172.3; light_source/Piece_4 row=173.0 baseline=172.3; furniture/Piece_1 row=178.1 baseline=172.3; furniture/Piece_2 row=178.1 baseline=172.3
- egeo: hero_landmark/Piece row=181.7 baseline=172.3

## 6. GLB mesh vs declared footprint

Every mounted mesh is scaled uniformly to its slot's `target_h` (KIT-STANDARD §5), so heights match
the spec by construction. The x and z proportions are whatever the GLB carries. Slots whose measured
box differs from the table's declared footprint by more than 0.25 m on any axis:

| arena | slot | declared w×h×d | measured w×h×d | Δw | Δd | breaks a gate? |
|---|---|---|---|---|---|---|
| torii | hero_landmark | 5.2×4.0×2.2 | 1.52×4.00×1.56 | -3.68 | -0.64 | — |
| carioca | ornament_accent | 0.7×0.8×0.2 | 3.62×0.85×3.62 | +2.92 | +3.37 | depth budget, glass plane |
| carioca | light_source | 0.5×1.5×0.5 | 2.77×1.50×0.38 | +2.27 | -0.12 | — |
| medina | hero_landmark | 3.0×3.9×2.0 | 0.73×3.90×0.72 | -2.27 | -1.28 | — |
| medina | ornament_accent | 0.8×1.0×0.2 | 2.43×1.00×2.43 | +1.63 | +2.21 | glass plane |
| carioca | ground_dressing | 3.0×0.5×1.0 | 0.88×0.50×0.84 | -2.12 | -0.16 | — |
| aurora | hero_landmark | 3.6×4.0×2.0 | 4.00×4.00×3.84 | +0.40 | +1.84 | depth budget, glass plane |
| torii | furniture | 1.2×0.9×0.8 | 3.02×0.95×0.89 | +1.82 | +0.09 | — |
| egeo | hero_landmark | 4.2×3.7×2.3 | 3.96×3.70×3.93 | -0.24 | +1.63 | depth budget, glass plane |
| aurora | furniture | 1.4×0.9×0.9 | 1.60×0.90×2.57 | +0.20 | +1.62 | glass plane |
| carioca | hero_landmark | 4.0×3.6×2.2 | 3.71×3.60×3.71 | -0.29 | +1.51 | depth budget, glass plane |
| aurora | light_source | 0.5×1.6×0.6 | 1.90×1.60×1.90 | +1.40 | +1.35 | glass plane |
| medina | signage_banner | 1.4×1.3×0.1 | 2.28×1.30×1.23 | +0.88 | +1.11 | — |
| torii | vegetation_cluster | 1.6×2.6×1.4 | 2.70×2.60×1.30 | +1.10 | -0.10 | — |
| aurora | railing_segment | 2.2×0.9×0.3 | 1.18×0.95×0.23 | -1.02 | -0.12 | — |
| egeo | ornament_accent | 0.9×0.9×0.3 | 1.89×0.95×1.29 | +0.99 | +0.99 | — |
| aurora | gate_portal | 2.2×2.2×0.8 | 1.70×2.20×1.72 | -0.50 | +0.92 | — |
| egeo | railing_segment | 2.2×1.0×0.3 | 1.32×1.00×0.25 | -0.88 | -0.05 | — |
| aurora | ground_dressing | 1.5×0.7×0.9 | 0.66×0.70×0.59 | -0.84 | -0.31 | — |
| medina | gate_portal | 3.2×2.8×1.0 | 2.37×2.80×0.68 | -0.83 | -0.32 | — |
| egeo | gate_portal | 2.4×2.5×0.9 | 1.62×2.50×1.70 | -0.78 | +0.80 | — |
| egeo | furniture | 1.3×1.0×0.8 | 0.52×1.00×0.55 | -0.78 | -0.30 | — |
| aurora | vegetation_cluster | 1.8×1.9×1.6 | 2.36×1.90×2.36 | +0.56 | +0.76 | — |
| egeo | ground_dressing | 1.6×0.6×0.9 | 0.89×0.55×0.83 | -0.71 | -0.12 | — |
| medina | ground_dressing | 1.4×0.6×0.8 | 0.70×0.60×0.75 | -0.70 | -0.05 | — |
| carioca | railing_segment | 2.2×1.0×0.3 | 1.51×1.00×0.29 | -0.69 | -0.01 | — |
| torii | signage_banner | 1.5×1.4×0.1 | 0.86×1.40×0.36 | -0.64 | +0.24 | — |
| torii | gate_portal | 3.4×2.6×0.9 | 2.77×2.60×0.50 | -0.63 | -0.40 | — |
| aurora | column_pillar | 0.7×2.8×0.6 | 1.25×2.80×1.18 | +0.55 | +0.58 | — |
| medina | furniture | 1.3×0.9×0.8 | 1.42×0.95×1.42 | +0.12 | +0.57 | — |
| torii | ground_dressing | 1.2×0.6×0.7 | 1.35×0.55×1.25 | +0.15 | +0.55 | — |
| egeo | column_pillar | 0.6×2.5×0.5 | 1.13×2.50×0.56 | +0.53 | +0.06 | — |
| carioca | signage_banner | 1.3×1.2×0.1 | 0.78×1.20×0.09 | -0.52 | -0.03 | — |
| carioca | furniture | 1.3×0.9×0.9 | 0.80×0.90×1.05 | -0.50 | +0.15 | — |
| torii | ornament_accent | 0.8×0.9×0.2 | 0.76×0.90×0.73 | -0.04 | +0.48 | — |
| egeo | vegetation_cluster | 1.8×2.2×1.7 | 2.13×2.20×1.24 | +0.33 | -0.46 | — |
| medina | vegetation_cluster | 1.8×2.7×1.5 | 2.13×2.70×1.10 | +0.33 | -0.40 | — |
| carioca | vegetation_cluster | 2.0×2.5×1.8 | 2.40×2.50×1.58 | +0.40 | -0.22 | — |
| torii | railing_segment | 2.0×1.1×0.3 | 1.62×1.05×0.26 | -0.38 | -0.04 | — |
| aurora | ornament_accent | 0.8×1.1×0.3 | 0.44×1.10×0.14 | -0.36 | -0.16 | — |
| medina | railing_segment | 2.0×1.1×0.3 | 1.70×1.15×0.23 | -0.30 | -0.07 | — |
| carioca | gate_portal | 2.6×2.4×0.9 | 2.57×2.40×0.60 | -0.03 | -0.30 | — |
| aurora | signage_banner | 1.2×1.5×0.1 | 0.93×1.50×0.11 | -0.27 | -0.01 | — |

43 of 50 slots carry a mesh whose proportions differ from the declared footprint by more than
0.25 m on some axis; in 7 of them the difference is large enough to put real mesh in front of the measured
glass plane or over the depth budget. Counting distinct models:

| model (slot name) | arenas that mount it | declared d | measured d |
|---|---|---|---|
| `ornament_accent` | carioca, medina | 0.25 | 3.62 |
| `hero_landmark` | aurora, egeo, carioca | 2.00 | 3.93 |
| `furniture` | aurora | 0.95 | 2.57 |
| `light_source` | aurora | 0.55 | 1.90 |

## 7. Materials and screen placement (after)

| arena | GLB files | surfaces | unique materials | policy violations | pieces fully inside frame | worst margin (px) | below baseline row |
|---|---|---|---|---|---|---|---|
| torii | 10 | 27 | 10 | 0 | 27/27 | 24.6 | 0 |
| medina | 10 | 31 | 10 | 0 | 31/31 | 32.4 | 4 |
| carioca | 10 | 30 | 10 | 0 | 30/30 | 22.4 | 5 |
| aurora | 10 | 28 | 10 | 0 | 28/28 | 8.8 | 7 |
| egeo | 10 | 29 | 10 | 0 | 29/29 | 18.6 | 1 |

Nothing is cropped by the frame and nothing lands behind the camera in any arena. The material policy
holds on all 145 mounted surfaces (27/31/30/28/29 per arena — one surface per piece): opaque, metallic 0,
roughness 0.85, no emission, and no material shared across a repeat run.

## 8. What the numbers say

1. **The doubling is real and it is gone.** Before the flip, 16 slots stood over 296 live procedural
   meshes (`torii` 89, `medina` 92, `carioca` 51, `aurora` 32, `egeo` 32) beside the same 145 mounted
   pieces. After, those containers build 0 meshes while the containers themselves and all 145 mounted
   pieces are untouched — so the frozen "one `Dressing_*` per authored prop" invariant still holds and
   the 3D band now carries each prop exactly once.
2. **The mount itself is clean.** Height, bottom origin, repeat offsets, the −8.0 m field-law plane,
   the authored ±14.35 m frame and the material policy all pass for all 145 pieces in all five arenas.
3. **The art disagrees with the declared footprints.** Four models are far deeper than their slots
   declare, in 7 of the 50 slots (`hero_landmark` in `aurora` 3.84 m, `carioca` 3.71 m, `egeo` 3.93 m;
   `ornament_accent` in `carioca` 3.62 m, `medina` 2.43 m; `furniture` 2.57 m and `light_source` 1.90 m
   in `aurora` — declared depths run 0.22–2.30 m against the 3.26 m budget), which is what puts mesh in
   front of the measured −10.02 m glass plane and over the court footprint in `medina`, `carioca`,
   `aurora`, `egeo` — the four
   gates that stay red. `torii` passes every gate.

## 9. What this census does not measure

- Rendered frames. This is a headless geometry census: no pixels. The rendered look (band, glare,
  balance) is judged by the capture passes, not here.
- Frames after the two towers / stands / crowd are added: the screen rows are measured on the arena
  build alone.
- Anything behind the backdrop plane, where no camera looks.
- The other presets: every number here is the `default` preset (x_scale 1.3437).

Reproduce: see the command at the top; the same run wrote the machine-readable copy to the path
passed as `--out=`. `PROPS-RESULT.md` in this directory carries the narrative, the gate table and the
per-slot suppress decision.
