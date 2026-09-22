# Colosso region mask — notes

Mask for the gladiator, built with the Fiamma pipeline re-expressed for Colosso's rig:
`tools/character/build_colosso_outfit_mask.py`. This file is the Colosso twin of
`MAESTRO-MASK.md`, and it carries the answer to the question this athlete forces: **his
leather and his skin are the same colour, so the shader's family test cannot tell them
apart, and the mask therefore cannot be a two-family recolour map.**

| artifact | path |
| --- | --- |
| tool | `tools/character/build_colosso_outfit_mask.py` |
| mask | `godot/assets/athletes/outfits/colosso/colosso_region_mask.png` (2048², RGBA) |
| preview | `godot/assets/athletes/outfits/colosso/colosso_region_mask_preview.png` |
| report | `docs/agent-work/outfits-3d/evidence/colosso-mask-report.json` |

Commands, both exit 0, mask `sha256` prefix `5182250b9aee31ea` (unchanged from the
previous run of this tool: the fixes below touch the report, not the mask):

```
/usr/bin/python3 tools/character/build_colosso_outfit_mask.py          # exit 0
/usr/bin/python3 tools/character/build_colosso_outfit_mask.py --check  # exit 0
```

The report is deterministic too: two consecutive runs both give
`sha256 1c4e5a92cf1e2eaa` (full `1c4e5a92cf1e2eaa149151b9d2ade51aa1e12ad0b1b3b50611702a409c5374cc`).
The run prints ten `COLOSSO_MASK_*` lines; the report carries 28 top-level keys,
including the four Maestro's report has (`bone_diff`, `protected_leak`, `texel_classes`,
`family_test` — the last inside `texel_classes`).

## 1. Two numbers this lane had to fix, and one that was stale

### 1.1 Per-bone attribution did not add up

The report's `inmask_skin_tone_by_garment_bone` was built by incrementing a counter for
**every** bone layer that covered a texel, and those layers come from
`rasterise_bone_layers`, which draws a triangle only when *all three* of its vertices are
dominated by the same bone. A texel on a mixed-dominance triangle therefore belongs to no
bone at all and disappeared silently: the rows summed to **24 490** of the **45 059** texels
they claimed to explain. The left/right thigh pair read 334 / 13 799, which looks like a
measurement of one leg rather than of two.

Fixed: attribution is now a **partition** — one owner per triangle, the `bone_region` bone
dominating most of that triangle's three vertices, ties broken by bone name — and both
leftovers are counted instead of dropped. `inmask_skin_tone_attribution` says so in the
report:

| | texels |
| --- | --- |
| attributed to a bone | 44 971 |
| no garment-bone triangle owns the texel | 51 |
| two owner polygons cover it (shared edges) | 37 |
| **total (= `inmask_texels_carrying_skin_tone`)** | **45 059** |

The old strict-rule rows are kept next to it as
`inmask_skin_tone_attribution.strict_all_three_vertices_secondary` (24 490 texels covered)
with a note saying they are not a partition. Per region the same treatment:
torso 25 228 + hip 19 753 + foot 56 + 22 in no region = 45 059.

The resulting per-bone table, as a partition:

| bone | sampled skin-toned in-mask texels | masked triangles it owns |
| --- | --- | --- |
| `mixamorig:RightUpLeg` | 19 189 | 778 |
| `mixamorig:LeftShoulder` | 12 983 | 573 |
| `mixamorig:RightShoulder` | 11 544 | 514 |
| `mixamorig:Spine` | 632 | 953 |
| `mixamorig:LeftUpLeg` | 555 | 854 |
| feet + toes (`Left/RightFoot`, `Left/RightToe*`) | 55 | 947 |
| `mixamorig:Hips` | 11 | 561 |
| `mixamorig:Spine1` | 2 | 116 |

**The left/right asymmetry is real, and §4 explains it.**

### 1.2 The value-bin arithmetic

The report's `value_gate.note` (and the tool's own docstring) said the split at 0.48 *"is
the midpoint of the largest step of the 0.05-binned histogram (0.45-0.50 -> 0.50-0.55,
x1.59)"*. Measured against the histogram the tool itself produces, none of that holds:

| claim | measured |
| --- | --- |
| largest 0.05-bin step is 0.45-0.50 → 0.50-0.55 at **x1.59** | it is at **x1.635** (13 466 → 22 014 texels) |
| … so the split is **0.48** | the boundary of that step is **0.50**, and 0.48 is not the midpoint of any step |
| where does **x1.59** come from | the **next** step, 0.50-0.55 → 0.55-0.60 at **x1.588** — the note paired the ratio with the wrong bin pair |

Fixed by making the arithmetic computed rather than asserted:

- `VALUE_SPLIT = 0.50`, i.e. the boundary of the largest 0.05-bin step, which is what the
  constant's own comment always claimed it was.
- `FAMILY_WINDOWS` is now derived from `VALUE_SPLIT`, so the split statistic and the two
  value windows cannot drift apart again.
- the report carries `value_histogram_0.05` (the whole binned histogram, floor 366 =
  `max(200, 0.002·total)`), `largest_step_0.05_bins`, `second_largest_step_0.05_bins` and
  `step_0.05_bins_at_the_chosen_split`; the note is built from those values.

The 1 %-bin numbers are kept, and are the reason a 0.05-bin figure was needed at all: at
0.01 resolution the step **at** the split is x1.101, one bin to the left x1.599 and one bin
to the right x0.746 — noise, not structure — while the largest 1 %-bin step in the
transition is x1.850 at 0.55→0.56, *inside* the light family's own peak, not between the
families. Against Maestro's measured x5.34 discontinuity, Colosso's x1.635 is a ramp: ratio
0.31.

### 1.3 One field the previous report could not reproduce

`skin_population_texels_below_the_split` on disk read **95 650**, which the tool does not
produce. Re-running the pre-fix tool reproduces every other field of the on-disk report
exactly and gives **25 996** for that one — because 95 650 is the count of *every* on-skin
texel below the split, while the field's sibling
(`skin_toned_texels_in_the_light_side`) counts on-skin texels with `s ≥ sat_min`. Two
different populations, one sentence. The field is now gated like its sibling, the
denominator is reported (`skin_population_texels_with_the_sat_gate`: 131 256), and the
report says which population it means. At the corrected 0.50 split it reads 28 698.

### 1.4 What moved in the report, and what did not

Changed by the 0.48 → 0.50 window shift: `value_split`, `family_windows`, `texels_below`
(101 162 → 106 762), `texels_above` (81 839 → 76 239), `step_ratio_vs_maestro_5.34`
(0.35 → 0.31), `skin_toned_texels_in_the_light_side` (44 746 → 44 077),
`value_test_separates_the_two_families` (false → true, see §5), the `classes` split
(leather 362 105 → 382 067, light 146 787 → 126 825 — 19 962 full-resolution texels moved
from the light window to the dark one) and the anchor sample counts.

**Unchanged**, because the mask and the anchors' modal colours are: the mask `sha256`, the
coverage (1 421 477 texels, 0.3389), the triangle counts (2766 / 1583 / 947), the whole
`protected_leak` block, `bone_diff`, the skin anchor `#906040` at hue 24.0°,
`skin_hued_family_hits` 200 158, the hue separation 6.0°, the in-mask skin-toned count
45 059 (12.67 %) and the skin match fractions 0.6447 / 0.6448. The anchors the shader and
any profile quote are still `#282018` (modal hue 30.0°) and `#906040` (modal hue 24.0°).

## 2. Bones: what the 28-joint rig actually has

Read from `colosso.glb` `skins[0].joints`, not assumed: **28 joints with the
`mixamorig:` prefix** — the Fiamma rig shape, not Maestro's bare names. All 14 names in
`bone_region` were found (`missing_from_rig=[]`); nothing is substituted and nothing is
invented. The spine chain ascends (`Spine` → `Spine1` → `Spine2`), and both `Toe_End`
joints exist, unlike Maestro's 24-joint rig. Protected by omission (14 joints):
`Neck`, `Head`, `HeadTop_End`, `headfront`, both `Arm`, `ForeArm`, `Hand`,
`HandMiddle4` and both `Leg` (shins). The shins stay out exactly as in Fiamma and Maestro:
a sock is found by the family test inside the foot region, and the shin's bare skin would
only add false positives.

The waist cut stays at world Y `1.0`, not re-tuned: Colosso's `Hips` joint is at 0.9896
and the first spine joint at 1.1142, so the cut sits 0.0838 of the way from the pelvis to
the first spine — the same anatomical landmark as Fiamma and Maestro.

## 3. Anchors, measured inside the regions

| family | hex | mean hue | samples | modal hits |
| --- | --- | --- | --- | --- |
| `leather` (dark) | `#282018` | 33.3° | 17 234 | 793 |
| `light` | `#906040` | 28.2° | 17 146 | 3 588 |

**The `light` anchor is the character's own skin colour.** That is not a coincidence of
this measurement: the skin anchor measured independently on the protected bones (face,
arms, forearms, hands, shins) is also `#906040`, at hue 24.0°, saturation 0.556, value
0.565 (85 454 samples, 20 866 modal hits). The two modal anchor hues are **6.0° apart
under a 45° tolerance**.

## 4. The question: can the shader tell this gladiator's leather from his skin?

**No, not by hue, and not by value either.**

### 4.1 Hue: every skin-toned texel inside the mask matches both anchors

Measured on all 1 421 791 masked texels with the effective `MASK_DEFAULTS` windows
(`hue_tol_deg 45.0`, `sat_min 0.18`, `val_min 0.02`, `val_max 0.98`):

- the `leather` anchor matches 1 054 269 masked texels, the `light` anchor 1 050 394, and
  **1 048 218 (73.7 %) match both at once**;
- `family_test.skin_hued_family_hits` = **200 158** — every masked texel classed as skin is
  claimed by the family test;
- inside the mask, **45 059 sampled texels (12.67 % of it) carry the measured skin tone**
  (`#906040` ± 6° hue, ± 0.10 saturation and value) — 180 250 at full resolution, 12.68 %
  of the mask, an independent full-resolution pass agreeing with the tool's step-2 sample.

Mirroring the shader's own `family_weight()` (`outfit_region_recolour.gdshader`, graded
ramps, value gate off) makes it sharper than a window test: the weight on the skin anchor
colour is **1.0 for both anchors**, and **all 45 059** in-mask skin-toned texels sit at
weight ≥ 0.99 for both (minimum 1.0). The skin is not near the edge of the tolerance — it
is at the centre of both ramps, and the shader would repaint it at full strength with
either family's target colour.

The same mirror on the whole measured skin population outside the mask (200 924 texels on
the protected bones) puts **122 584 at full weight for the `leather` anchor and 122 538 for
the `light` one (61.0 %)**. There the mask is what protects the skin. Inside the mask
nothing does.

### 4.2 Where that skin is, and why one thigh only

The mask is a **bone-region** map, so the bare surface of a bone that owns a region comes
with it: the thigh bones map to `hip`, and the bare thigh of this model is inside the mask
by construction — the same thing Maestro's mask does with the bare thigh under the shorts
(51 759 texels there, harmless because the family test rejected them). Here it is not
harmless. Per bone: `RightUpLeg` 19 189, `LeftShoulder` 12 983, `RightShoulder` 11 544,
`Spine` 632, `LeftUpLeg` 555.

The 35× left/right difference is real, and it is the outfit, not a rig defect. The two
thigh bones own almost the same number of masked triangles (854 and 778), but their masked
areas are painted differently:

| bone | masked chromatic texels | value p25/p50 | modal colour |
| --- | --- | --- | --- |
| `LeftUpLeg` | 17 759 | 0.161 / 0.325 | `#101010` (833), then `#302820`, `#282018` — near-black leather |
| `RightUpLeg` | 33 250 | 0.396 / 0.549 | `#906040` (8 566), then `#885838` — the skin tone |
| `LeftShoulder` | 28 812 | 0.329 / 0.518 | `#906040` (2 682) |
| `RightShoulder` | 21 547 | 0.388 / 0.557 | `#906040` (3 726) |

The 2D reference art agrees: Colosso's kit is asymmetric — one leg bare, the other in black
padded leather, with asymmetric bracers. So the mask covers bare skin on one thigh and on
both deltoids, and the atlas's own baked colours there are the skin tone.

Note the atlas layout: it is not one big garment island but **many small scattered islands**
(checked visually, `colosso_owner_montage.png` in the scratch dir). "RightUpLeg owns these
texels" therefore means *the geometry there is the thigh*, spread over many small islands,
not that one contiguous island is skin.

### 4.3 Value: a real ramp, but the light side is the skin

The value test does split the dark mass from the light one — at 0.50, x1.635, as computed
in §1.2 — and that is why the report now says
`value_test_separates_the_two_families: true`. **It does not make the mask usable**, because
what it puts on the light side is the character:

- **44 077 of the 45 059** in-mask skin-toned sampled texels (**97.8 %**) are above the split;
- pushed as far as it goes, the best single value cut for skin-vs-garment *inside the mask*
  is **0.54**, and it still leaves **21 860 chromatic garment texels on the skin's side**
  against 5 909 skin-toned texels on the garment's side — balanced accuracy **0.8483**,
  under the 0.95 a separation would need. (Full-resolution cross-check of the same
  comparison: 87 476 and 23 634, accuracy 0.8482.)
- the same scan against the whole measured skin population outside the mask: threshold 0.52,
  accuracy 0.7781, 27 087 garment texels on the skin's side.

The report carries both scans (`best_value_cut_for_skin_vs_garment_inside_the_mask`,
`..._measured_skin`) and the verdict as
`value_gate.value_test_separates_skin_from_garment: false`.

## 5. How much of the mask can be recoloured at all

`sat_min 0.18` rejects the achromatics and the value window rejects the extremes. On all
1 421 791 masked texels:

| class | texels | share |
| --- | --- | --- |
| achromatic (`s < 0.18`) | 688 606 | 48.43 % |
| too dark (`v < 0.02`) | 195 | 0.01 % |
| too bright (`v > 0.98`) | 1 110 | 0.08 % |
| **chromatic, inside the value window** | **731 880** | **51.48 %** |

So just over half the mask is a candidate for any recolour; the other 48.5 % is grey and
near-black leather, gold trim and shadow that no anchor can reach. The breakdown is
computed in the report (`texel_classes.neutral_breakdown`) and was cross-checked
independently at full resolution: 688 606 / 195 / 1 110 / 731 880, identical.

## 6. Leak: strict rule, as Maestro taught

A triangle counts as leak only when **all three** vertices are dominated by the protected
group. The loose "at least one vertex" rule inflated the first Maestro measurement from
0.02 % to 31-39 %; it is reported as the secondary `majority` row only. Leak as a share of
each group's own UV area:

| group | strict ≥200 | strict ≥128 | majority ≥200 | majority ≥128 |
| --- | --- | --- | --- | --- |
| Head | 0.0000 | 0.0008 | 0.0402 | 0.0458 |
| Hands | 0.0000 | 0.0000 | 0.0000 | 0.0000 |
| ForeArm | 0.0000 | 0.0000 | 0.0000 | 0.0000 |
| Arm | 0.0001 | 0.0037 | 0.1087 | 0.1210 |
| Shin | 0.0000 | 0.0032 | 0.1273 | 0.1436 |

The hard threshold is ≥200 (geometry, no Gaussian bleed) and ≥128 is what the shader's
linear filtering can see. Strict leak is at or below 0.0001 on the hard mask for every
group — the mask itself is sound; the majority rows are the shoulder seam and the shorts
hem, i.e. geometry that belongs in the mask.

## 7. Cross-checks, and where they disagree with nothing

- The docstring's hue×value table was re-derived at step 4 and matches: 45 723 recolourable
  in-mask texels, hue 21-27 (skin, modal `#906040`) 82 % at value 0.50-0.70, hue 33-39
  (modal `#786038`) spread over 0.15-0.70, hue 27-33 (modal `#302820`) massed at 0.15-0.35.
- The full-resolution independent pass reproduces the tool's step-2 numbers within
  sampling: skin-toned in-mask 180 250 vs 4 × 45 059, neutral breakdown identical, best
  value cut 0.54 / 0.8482 vs 0.54 / 0.8483.
- The attribution partition reconciles with the strict layers: 51 texels with no owner plus
  37 on shared edges = the 88 texels the strict rule cannot place.
- The shader-weight mirror in the report was reconciled per texel against an independent
  copy of the formula: 0 differences over the 200 924-texel skin population. (An earlier
  scratch probe over-counted by 2 740 texels by feeding 0-255 values to `colorsys`; the
  report's numbers are the reconciled ones.)
- Audit probes used by this lane, in
  `/Users/alessiofantini/.hermes/profiles/dev-work/cache/scratch/`:
  `colosso_probe7_audit_sa2.py` (attribution), `colosso_probe8_audit_sa2.py` (per-bone
  partition, value separation), `colosso_probe9_audit_sa2.py` (full-resolution neutral
  breakdown and separation), `colosso_probe10_huevalue_sa2.py` (docstring table),
  `colosso_probe13_lr_sa2.py` (left/right thigh colours),
  `colosso_probe14_shader_weight_sa2.py` and `colosso_probe15_reconcile_sa2.py`
  (shader `family_weight`), `colosso_probe11_owners_sa2.py` + `colosso_probe12_zoom_sa2.py`
  (the visual checks). Each ran with `/usr/bin/python3`, exit 0.

## 8. Limits, honest

- **No engine run and no render from this lane.** A headless Godot has no framebuffer, and
  `godot/src/**`, `godot/tests/**` are other lanes' files — not touched here. What is
  proven is the mask, the measurement and the report; the on-screen check would be
  `godot/tests/outfit_maestro_capture.gd`-style work in another lane. The family test is
  mirrored in Python, exactly as the brief specifies, and the mirror was reconciled against
  a second implementation.
- **Which constants.** The report runs the family test on `MASK_DEFAULTS`
  (45.0 / 0.18 / 0.02 / 0.98) as instructed, and they were not re-tuned. The shader's own
  declared literals are `hue_tol_deg 42.0`, `sat_min 0.25`, `val_min 0.06`, `val_max 0.99`,
  and the Maestro lane found that a *profile* material runs on those literals rather than on
  `MASK_DEFAULTS`. The verdict does not depend on which set is used: the skin sits at hue
  distance 0° and 6° from the two anchors, while the hue ramp only starts to fall at
  0.55 × tolerance (23.1° at 42, 24.75° at 45), and its saturation and value sit far above
  both `sat_min` values — so the skin scores 1.0 on both families either way.
- **The value split is descriptive.** 0.50 is not pushed to the shader and no Colosso
  profile or value gate was added; that would be a `.gd`/`.gdshader` edit and is out of this
  lane's perimeter.
- **The attribution is per triangle owner.** With a scattered atlas, "RightUpLeg owns these
  texels" locates the geometry, not a contiguous island. 51 + 37 = 88 of the 45 059 texels
  (0.20 %) cannot be placed by the strict rule at all and are reported as such.
- **The consequence for the outfit plan.** `INVENTARIO.md` (20 Sept) lists Colosso
  Signature as *"cuoio scuro, metallo e dettagli arancio/emissivi; geometria già vicina"* —
  i.e. a recolour job. This lane's numbers add the caveat: a two-family recolour of this
  atlas repaints the character's own skin (45 059 masked texels at full family weight), so
  Signature is **not** realisable with the mask plus the current family test. It needs a
  mechanism that can reject skin inside the mask — a third mask channel, a hand-authored
  garment mask that excludes the bare thigh and the deltoids, or a per-texel skin classifier
  — and that is a design decision for the lane that owns the shader, not this one.
- `ok: false` in the report is the honest value: the mask is a usable **permission map**,
  it is not a usable **two-family recolour map**, and no number in the report claims
  otherwise.
