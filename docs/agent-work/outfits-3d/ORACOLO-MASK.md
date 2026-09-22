# Oracolo region mask — notes, and the verdict on the tripartition

Fourth athlete through the masked lane. Tool
`tools/character/build_oracolo_outfit_mask.py`, the Oracolo twin of
`build_maestro_outfit_mask.py` and, before it, `build_fiamma_outfit_mask.py`.

Checkout `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, branch
`codex/integrate-arena-11m`. The tree was already dirty with other lanes' work and was not
touched outside this lane's files. No commit, no push, no `.gd` / `.tscn` / `.gdshader`
edited (verified: every modified script in the tree is another lane's and was last written
by another process while this lane ran).

| artifact | path |
| --- | --- |
| tool | `tools/character/build_oracolo_outfit_mask.py` |
| mask | `godot/assets/athletes/outfits/oracolo/oracolo_region_mask.png` (2048², RGBA) |
| preview | `godot/assets/athletes/outfits/oracolo/oracolo_region_mask_preview.png` |
| report | `docs/agent-work/outfits-3d/evidence/oracolo-mask-report.json` |

Commands, both **exit 0**, `sha256` prefix **`35f0456418571d65`**:

```
/usr/bin/python3 tools/character/build_oracolo_outfit_mask.py
/usr/bin/python3 tools/character/build_oracolo_outfit_mask.py --check
```

`/usr/bin/python3` is Python 3.9.6 with Pillow and **no numpy**; the tool is stdlib + PIL
only, like the Maestro one, and runs in ~11 s. Re-running it byte-reproduces the mask
(verified twice). The `.import` sidecars next to the two PNGs are Godot's, written by
another lane's engine run when it noticed the new files.

## Verdict, up front

**The mask is geometrically clean and safe to ship, but the torso/hip/foot tripartition is
NOT a garment partition on this body.** The cut is a horizontal plane through the pelvis
that follows no seam of the outfit, and 61.3% of it passes through recolourable fabric on
both sides. **The atlas has one recolourable family, not two**, and **a value gate cannot
manufacture the second one** — the value histogram is flat where Maestro's had a 5.34×
discontinuity. Details and numbers below; every one of them is in the report.

## 1. Bones: nothing was missing this time

Read from `oracolo.glb` `skins[0].joints`, not assumed: **28 joints, `mixamorig:` prefix**.
Compared by set against `fiamma.glb` and `maestro.glb` with the same code path, Oracolo's
joint set is **identical to Fiamma's** — same 28 names. So the Fiamma bone map applies
verbatim and `bone_diff.absent_from_oracolo` is **empty**: no bone had to be dropped or
renamed, and nothing was invented. `headfront`, `HeadTop_End` and the two
`HandMiddle4` tips are present but own no garment region, exactly as on Fiamma.

Maestro is the rig whose names differ (24 joints, bare, spine numbered downward, no
`Toe_End`). That trap does not fire here; this section is short because the measurement
was short.

## 2. TRIPARTITION: does torso / hip / foot mean anything on this body?

**It holds topologically. It does not hold as a garment partition.** Numbers:

| fact | value |
| --- | --- |
| triangles | torso 5309 · hip 8743 · foot 1369 · protected 16685 (52% of the mesh) |
| straddling triangles (two regions among their vertices) | 56 (0.17%) |
| region bind-Y spans | torso [0.9754, 1.4333] · hip [0.4877, 1.0752] · foot [0.0000, 0.1765] |
| region-boundary edges | **191**, all `torso↔hip`, all inside bind Y **[0.9883, 1.0088]** |
| region adjacency | `protected↔torso` 370 · `hip↔torso` 191 · `foot↔protected` 56 · `hip↔protected` 14 |
| UV islands | 14022; median 1 triangle, mean 2.29, largest 37 |
| islands spanning >1 region | 69 (0.49%), covering 530 triangles (1.65%) |

Two things follow immediately.

**(a) The cut lands on the pelvis, not the waist.** Oracolo's `Hips` joint is at world Y
**0.9916** and the first spine joint at **1.0970**, so the interval is **0.1054 m** and the
unmodified `WAIST_Y = 1.0` sits **8.4 mm above the Hips joint — 8.0% of the
pelvis-to-Spine interval**, against 31.7% on Maestro and 37.4% on Fiamma. The pipeline's
cut was calibrated on two athletes whose pelvis sits at ~0.95; this one's sits 40 mm higher
and the same constant lands somewhere else anatomically. `WAIST_Y` was **not re-tuned** —
the brief forbids it and the report carries the sweep instead.

**(b) The foot region is edge-isolated.** There is **no** `foot↔hip` and no `foot↔torso`
edge anywhere in the mesh: the 1369 foot triangles touch the rest of the mask only through
`foot↔protected` (56 edges), because the boot shaft above them is `LeftLeg`/`RightLeg`,
which is deliberately protected. So the boot's foot is the only region that ends where a
real piece of the outfit ends. `foot` is also the smallest region: 0.0427 of the UV area,
1369 triangles, and it covers the shoe only — not the shin.

### The seam check the interrupted lane had not finished

Four independent tests, all on the 191 boundary edges. A boundary that follows something
real would score high on at least one of them.

| test | measurement | reading |
| --- | --- | --- |
| UV island alignment | 99 of 191 on a UV island border = **0.518**, versus a base rate of **0.627** over all 47 027 shared edges → **likelihood ratio 0.83×** | the boundary is *less* likely than a random edge to sit on an island border |
| texture-edge alignment | 94 of 191 within 3 px of a top-5% gradient texel = **0.492**, versus **0.521** for 20 000 random in-mask texels → **likelihood ratio 0.94×** | it does not sit on any edge of the baked image |
| colour across the boundary | mean max-channel delta **19.2/255** for seam pairs versus **18.9/255** for same-region pairs → **1.02×** | the fabric is the same on both sides |
| what the shader would see | recolourable violet on **both** sides **117** (61.3%), one side **17**, neither **57** | 61.3% of the boundary would show as a hard line if torso and hip got different colours |

**Cut-height sweep** (evidence only — `WAIST_Y` unchanged). "Visible" = recolourable violet
on both sides:

| WAIST_Y | seam edges | visible share |
| --- | --- | --- |
| 0.94 | 342 | 0.892 |
| 0.96 | 297 | 0.852 |
| 0.98 | 252 | 0.845 |
| **1.00** | **191** | **0.613** |
| 1.02 | 167 | 0.383 |
| 1.04 | 102 | 0.353 |
| 1.06 | 70 | 0.500 |
| 1.08 | 83 | 0.398 |
| 1.10 | 27 | 0.296 |
| 1.12 | 27 | 0.333 |

**No height in the pelvis-to-waist range avoids it.** The best available is ~0.30–0.35 at
Y 1.02–1.04 or 1.10, and the reused 1.0 is the second-best of the plausible band. That is
the honest form of the answer: the tripartition is *geometrically* sound and
*garment-wise* arbitrary, and there is no better horizontal cut to be had.

**What the cut actually falls on.** Per-1 cm band of the torso+hip triangles, sampled at
their UV centroids:

| bind Y | triangles | violet share | skin-hued share |
| --- | --- | --- | --- |
| 0.94–0.96 | 339 | 0.957 / 0.893 | 0.006 / 0.028 |
| 0.98–0.99 | 257 | 0.829 | 0.090 |
| 0.99–1.00 | 228 | 0.640 | 0.276 |
| **1.00–1.01** | **333** | **0.435** | **0.511** |
| 1.02–1.03 | 232 | 0.323 | 0.569 |
| 1.04–1.05 | 153 | 0.399 | 0.425 |
| 1.08–1.09 | 67 | 0.567 | 0.239 |
| 1.09–1.10 | 60 | 0.833 | 0.083 |

So the cut falls in a **non-violet band** at 1.00–1.05 (the waist ornament / bare midriff:
modal baked colour `#886848`, tan) between violet above and violet below — which is why the
`neither` count is as high as 57 edges. But 61.3% of the edges are still violet-on-both-
sides, because the transition is gradual over ~5 cm and the seam edges sit at its lower lip.

**UV budget, worth knowing before reading the coverage number.** Total UV area is 0.4136 of
the unit square = 1 734 897 atlas pixels; a triangle owns a **median of 18.9 px** (p10 3.7,
p90 116.2). The recolour therefore works at roughly 4×4 px per triangle, which is why the
mask is rasterised at 2048 with a 1.2 px soften — and it is a limit of the asset, not of
this pipeline.

## 3. FAMILIES: there is one recolourable family, not two

Anchors measured inside the regions only, modal colour at 8/255 quantisation, same gates as
Fiamma and Maestro (`s ≥ 0.25`, `v ≥ 0.08`):

| family | hex | mean hue | samples | modal hits | components | ≥64 px | largest |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `violet` | `#301850` | 264.5° | 38 253 | 2 854 | 2 342 | **1 177** | **12 064 px** |
| `magenta` | `#302028` | 325.7° | 1 416 | 51 | 922 | 54 | 240 px |

The violet band is a real painted family: 819 263 of the 1 161 080 masked texels (70.6%),
in 1177 components of 64 px or more with a largest of 12 064 px. The 300–360° band is
**antialiasing**, not a second family: 55 527 texels (4.8%) spread over 922 sampled
components, a modal colour that holds only 51 of its 1416 samples, and a largest component
of 240 px. It is the ramp the atlas interpolates between violet fabric and skin.

**The declared pair is not separable by hue, and the two declarations disagree.** This is
the one athlete where the catalogue's `visual` block and the outfit's own `colors` do not
match (`outfit_catalogue.gd` documents the outfit winning):

| declaration | colours | hues | hue gap | value gap |
| --- | --- | --- | --- | --- |
| outfit `base` | `#6d42b8` / `#a96cff` | 261.9° / 264.9° | **3.0°** | 0.278 |
| catalogue `visual` | `#6b3df0` / `#e3c6ff` | 255.4° / 270.5° | **15.1°** | 0.059 |

Under `hue_tol_deg 45.0`, two anchors need to be **more than 90° apart** for the shader to
tell them apart. Measured on the atlas, the two available anchors are **64.2°** apart
(violet 265.7°, magenta 330.0°) — and `hue_test_separates_the_two_families = false`, with
**41 333 masked texels (3.56%) answering to both anchors**.

**And the magenta anchor repaints skin.** Its 45° window is **[285°, 15°]**, which wraps
past 360 onto the low hues, and there the atlas has skin: the family test would recolour
**24 182 skin-hued masked texels**, every one of them through the magenta anchor. The
**violet anchor alone recolours 0** skin-hued texels. So the safe configuration is a single
anchor; a profile that points `*_b` at a second violet will not separate anything and one
that uses the magenta anchor will tint skin.

## 4. VALUE SPLIT: not possible here — the histogram is flat

The interrupted lane reported a flat value histogram between 0.7 and 1.0 and suspected there
was no clean threshold like Maestro's 0.76. **Confirmed, and it is stronger than that.**

Population = everything the shader could recolour: masked texels (`alpha ≥ 128`) with
`hue 240–360°`, `sat ≥ 0.18`, `0.02 ≤ v ≤ 0.98` → **874 790 texels**.

| fact | Oracolo | Maestro |
| --- | --- | --- |
| density discontinuity to cut on | **none** | value 0.76, a **5.34×** jump |
| flat band 0.55–0.98 | **48–485 texels per 0.01 bin, median 162** | — |
| largest upward jump above v = 0.30 | **1.95× at v = 0.84** | 5.34× at 0.76 |
| biggest ratio anywhere | 11.84× at v = 0.04 — that is the `val_min` gate, not the atlas | — |
| bright population `v ≥ 0.76` | **2 919 texels = 0.33%** of the population, 81 components, median **4 px** | 24 067 texels, 23 components ≥ 64 px |

There is no threshold to cut on: above v = 0.55 the histogram is a flat tail with no step,
the only large ratio in it is the gate's own edge, and the bright texels are speckle rather
than painted panels. `value_split.possible = false`, and the second declared family cannot
be reached by value either. A gate at Maestro's 0.76 would move 0.33% of the recolourable
texels — it cannot carry a family.

*(Cross-check, same atlas, different method: the parallel palette lane's
`atlas_inventory.two_largest_saturated_families` finds `#341c54` violet at 80.2% and
`#9c745c` skin at 19.8%, 116.8° apart. Its second family is **skin**, which the mask must
not repaint — which is exactly what the violet anchor guarantees.)*

## 5. Leak and safety

`protected_leak`, strict rule (all three vertices in the group) and majority (at least two),
hard mask (≥200) and visible mask (≥128):

| group | strict ≥200 | strict ≥128 | majority ≥200 | majority ≥128 |
| --- | --- | --- | --- | --- |
| Head | 0.0039 | 0.0067 | 0.0194 | 0.0301 |
| Hands | 0.0000 | 0.0008 | 0.0000 | 0.0008 |
| ForeArm | 0.0054 | 0.0080 | 0.0042 | 0.0062 |
| Arm | 0.0053 | 0.0153 | 0.1988 | 0.2418 |
| Shin | 0.0106 | 0.0154 | 0.0805 | 0.0922 |

Strict is the number that means anything (the Maestro lane proved the loose rule produced a
false 31–39% that was really 0.02%); majority is carried as the secondary datum. Against
Fiamma's own validated mask, same test, strict: Arm 0.0233, Shin 0.0013, Head 0.0032, Hands
0.0089. Oracolo is **below Fiamma on Arm** (0.0053 vs 0.0233) and above on Shin (0.0106 vs
0.0013); both are fractions of a percent of that group's own UV area, i.e. seam and hem
corners, not misplaced limbs.

Masked texel classes: violet 819 263 · skin 169 302 · neutral 110 987 · magenta 55 527 ·
other 6 001. The 169 302 skin texels inside the mask are bare midriff, thigh and face-adjacent
area that the regions legitimately cover; **none of them can be recoloured by the violet
anchor**, which is the measurement in §3.

Coverage **0.2765** (1 159 771 texels at `alpha > 128`; 1 161 080 at `>= 128`, which is what
the family test counts). For scale: Fiamma 0.2148, Maestro 0.362. Oracolo's 32 106 triangles
against Maestro's 12 253 explain most of the difference.

## 6. Visual evidence, and where it disagrees with the measurement

`mask_render_front.png` / `mask_render_side.png` / `mask_render_contact.png` in the probe
directory `/Users/alessiofantini/.hermes/profiles/dev-work/cache/scratch/oracolo/` — rendered
from the **shipped mask PNG**, not recomputed, tinted on the baked texture (red torso, green
hip, blue foot).

An auxiliary vision read of those renders says the red/green boundary "sits on a clear,
distinct garment edge between two separate costume pieces" and that no bare skin is tinted.
A second vision read of a zoom with the boundary drawn as lines says the lines "cross
unbroken fabric". **The vision reads are not the measurement and the measurement wins**: the
boundary is 0.94× as likely as a random texel to sit on a texture edge and 1.02× the
same-region colour baseline, i.e. it follows nothing. What the renders do confirm, and the
numbers agree with, is that the tint is coherent (not speckle), that the blue region is
confined to the boots' foot portion, and that **no bare skin is recolourable** — that last
one because the violet anchor's hue window does not reach skin, measured as 0 skin-hued
hits, not asserted.

## 7. Limits, honest

- **The tripartition does not hold as a garment partition.** This is a `no` with numbers, and
  it is the main finding. The mask is still usable — it is geometrically clean, it does not
  recolour skin, and its leak is at or below the validated Fiamma baseline — but a profile
  that gives `torso_*` and `hip_*` different colours will draw a horizontal line across the
  outfit for 61.3% of its length. The only way to avoid that on this body is to give both
  regions the same colour, or to accept the line.
- **One recolourable family.** The second family the sprite lane sees (`#a96cff` /
  `#e3c6ff`, a lighter violet) is 3.0°–15.1° from the first in hue; it is not separable by
  hue, not separable by value, and in the atlas it exists only as a 0.33% bright speckle.
  The `b` slots have almost nothing to land on.
- **The magenta anchor must not be used.** It repaints 24 182 skin-hued texels via the
  360° wrap. Reported, not fixed here: the anchor choice belongs to the profile lane.
- **No in-engine render or GDScript test was run by this lane.** `godot/src/**` and
  `godot/tests/**` belong to other lanes and were not touched. The evidence here is the
  mask, the report and the offline render; the shader-side check is another lane's.
- **No Oracolo profile exists yet** (`godot/assets/athletes/outfits/oracolo/` was empty
  before this lane; `outfit_catalogue.gd` has no `&"oracolo"`). The profile's mask path,
  anchors (`#301850` only) and `mask_sha256_prefix 35f0456418571d65` are what this lane
  hands over. If the mask is regenerated the prefix changes.
- **The asset's UV resolution is coarse**: a median of 18.9 atlas pixels per triangle over
  14 022 islands. The recolour cannot be sharper than that, whatever the mask says.
- `protected_leak` majority numbers on Arm (0.199) and Shin (0.081) are high *by
  construction* — those triangles are torso/hip triangles with one sleeve or hem corner and
  belong in the mask. Do not quote them as a defect.
