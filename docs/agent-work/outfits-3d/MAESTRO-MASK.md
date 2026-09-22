# Maestro region mask — notes

Mask for the second athlete, built with the Fiamma pipeline
(`tools/character/build_fiamma_outfit_mask.py`) re-expressed for Maestro's rig:
`tools/character/build_maestro_outfit_mask.py`.

| artifact | path |
| --- | --- |
| tool | `tools/character/build_maestro_outfit_mask.py` |
| mask | `godot/assets/athletes/outfits/maestro/maestro_region_mask.png` (2048², RGBA) |
| preview | `godot/assets/athletes/outfits/maestro/maestro_region_mask_preview.png` |
| report | `docs/agent-work/outfits-3d/evidence/maestro-mask-report.json` |

Commands (both exit 0, `sha256` prefix `dc39e62c92bc5b8e`):

```
/usr/bin/python3 tools/character/build_maestro_outfit_mask.py
/usr/bin/python3 tools/character/build_maestro_outfit_mask.py --check
```

## Bones: what the 24-joint rig actually has

Read from `maestro.glb` `skins[0].joints`, not assumed: **24 joints, bare names — no
`mixamorig:` prefix**. Against the Fiamma map:

- **absent**: `LeftToe_End`, `RightToe_End`. Left out of `bone_region`, never
  substituted; the toes stay covered by `LeftToeBase` / `RightToeBase`.
- **renamed**: Fiamma's ascending `Spine` / `Spine1` / `Spine2` are Maestro's
  `Spine02` / `Spine01` / `Spine` — Maestro numbers its spine chain *downward* from the
  pelvis. All three map to `torso`, so the flip moves no triangle.
- **unchanged**: `Hips`, `LeftUpLeg` / `RightUpLeg`, `LeftFoot` / `RightFoot`,
  `LeftToeBase` / `RightToeBase`, `LeftShoulder` / `RightShoulder`.
- **protected by omission** (12 joints): the head/neck group, arms, hands, shins.

The waist cut stays at world Y `1.0`, not re-tuned: Maestro's `Hips` joint is at
0.9517 against Fiamma's 0.9549 (3.2 mm apart) and the first spine joint at 1.1042
against 1.0755, so the same value lands on the same anatomical landmark.

## Anchors, measured

Measured as the modal colour inside the regions, exactly as for Fiamma
(`s >= 0.25`, `v >= 0.08`, 8/255 quantisation):

| family | hex | hue (mean) | samples | modal hits |
| --- | --- | --- | --- | --- |
| `sky` light blue base | `#68a8c8` | 196.5° | 2563 | 557 |
| `navy` secondary | `#102040` | 217.1° | 54088 | 10335 |

Fiamma's hue windows cannot be reused here: both Maestro families fall inside its
`navy` window (180–265°). The measurement splits them at 205°, which is measured, not
chosen — inside the mask the light family's hue mode is 190–200° at value 0.6–0.8 and
the dark family's is 210–220° at value 0.2–0.4. The light family is real fabric, not a
rim highlight: a 3×3 min-filter keeps 70% of its texels, against 34% of the
0.45 ≤ v < 0.75 mid band (the antialiased seam between the two). The reference
catalogue agrees on two families (`kit #08bfe8`, `secondary #102d68`, `diagonal`).

## Leak investigation (arms 31%, shins 39% — resolved)

The first measurement said ~1/3 of the UV area of the arm and shin triangles fell
inside the mask. Three hypotheses were tested; **it was none of them — the measurement
was wrong**, and the numbers below are why.

1. **Attribution rule (the real cause).** That run counted a triangle as "arm" if *any*
   one of its three vertices was dominated by an arm bone. Those triangles are torso
   and hip triangles with a single sleeve/seam corner, and they belong in the mask.
   Re-measured with `all three vertices` (**strict**) versus `at least two`
   (**majority**), hard mask (≥200), leak of that group's own UV area:

   | group | strict leak | majority leak |
   | --- | --- | --- |
   | Head | 0.0000 | 0.0049 |
   | Hands | 0.0000 | 0.0000 |
   | ForeArm | 0.0000 | 0.0000 |
   | Arm | 0.0002 | 0.1447 |
   | Shin | 0.0001 | 0.1862 |

   Fiamma's own validated mask, same test, strict: Arm 0.0233, Shin 0.0013, Head 0.0032,
   Hands 0.0089. Maestro is at or below the baseline everywhere.

2. **Bone map dragging limbs in.** Not the cause. `LeftLeg`/`RightLeg` are *not* in
   `bone_region`, and the strict shin leak is 0.0001 — `UpLeg` does not drag the shin
   into the mask. Where the majority triangles sit in bind space (arm meanY 1.17–1.48,
   shin 0.11–0.54) is the shoulder seam and the shorts hem, i.e. geometry that must be
   in the mask.

3. **Skin-coloured texels inside the mask.** Present and expected — 60271 texels
   (4.0% of the mask) read as skin, almost all in the `hip` region (bare thigh under
   the shorts, 51759) — but **none of them can be recoloured**: the shader's family
   test is applied on top of the mask, and skin sits at hue ≈ 20° against anchors at
   200° and 220°. Full-resolution simulation with the effective `MASK_DEFAULTS`
   windows (`hue_tol_deg 45.0`, `sat_min 0.18`): `skin_hued_family_hits = 0`.

## Cross-check against the parallel sprite lane

`docs/agent-work/outfits-3d/evidence/maestro-palette/` (a different lane, not this one)
measures the same athlete off the in-field 2D sprites. Its `base` outfit `hip` family
`a` mode is `#0d2359` at hue 222.4°, and `foot` `a` is `#082658` at hue 217.5° — the
same family as the `navy` anchor measured here at hue 217.1°, from two independent
assets. Its family `b` is the **white** accent (`#fbf9f8`), which is a third colour,
not one of the two chromatic families this mask profiles: white is achromatic
(saturation 0.01, below the effective `sat_min` 0.18) and the shader's family test
rejects it in any case. In the baked atlas that white is 29% of the masked texels
(`neutral`, 43% inside the shoes).

## Limits, honest

- **`navy` is the mass and `sky` the band.** Inside the mask, 961 770 texels (63%) are
  the navy family and 48 803 (3%) the light-blue one — the diagonal is a band on a navy
  field, not the other way round. Both are real measured families; the wording of the
  brief reads the other way round.
- **The two families are not separable by the current shader's hue test.** The measured
  anchor hues are 20° apart while `hue_tol_deg` is 45°, so both anchors fire on the same
  texels (1 114 473 of the 1 518 775 masked texels match *both*): the sky anchor matches
  1 114 593 and the navy anchor 1 127 490. The mask is unaffected, but driving `target_*_a` and
  `target_*_b` to different colours through `family_weight` alone will bleed: a future
  recolour slice needs a value-aware or narrower family gate, or a third mask channel.
  The report carries this as `family_test.hue_test_separates_the_two_families = false`.
- **Coverage is 0.362 against Fiamma's 0.2148** and that is a rig-density difference,
  not a fatter garment: Maestro has 12253 triangles against Fiamma's 24920, and
  Fiamma's head alone owns 75% of her vertices against Maestro's 38%. Garment area as
  a share of *used* atlas area is 63.3% for Maestro against 40.2% for Fiamma (used
  atlas: 0.5720 and 0.5349 of the 2048² respectively).
- **176 straddling triangles** (1.4% of the mesh) touch two regions; each is assigned
  to its majority region, the same rule and the same order of magnitude as Fiamma's 126.
- **The `foot` region is 62% of the mask area** (859794 hard texels): both shoes and
  both bare feet share large islands. Correct for the pipeline, worth knowing before
  reading the coverage number as "how much clothing is recoloured".
- Not run here: any in-engine render or GDScript test. `godot/src/**` and
  `godot/tests/**` are other lanes' files; this slice is the mask, the tool and the
  report only.
