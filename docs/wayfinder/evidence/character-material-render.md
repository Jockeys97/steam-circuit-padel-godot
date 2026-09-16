# Evidence: one rigged GLB, two outfits, in engine (Godot render)

- Date: 2026-09-16 (rendered 2026-09-16T06:34Z, measured 2026-09-16T06:41Z)
- Ticket: [`../tickets/character-pipeline-economics.md`](../tickets/character-pipeline-economics.md)
- Artifact: `godot/prototypes/character_material/` (new project)
- Method: one real Godot 4.7.2 headless render (Xvfb + Mesa llvmpipe software GL,
  `opengl3`), then offline pixel measurement with `python3` + numpy/PIL. No Meshy call,
  no paid API, no image generation, no network. The recolour tool
  (`tools/character/recolour_outfits.py`) was **not** run — `outfit-a.png` /
  `outfit-b.png` are used exactly as they already exist on disk, byte-identical to
  `tools/character/out/` (sha256 checked, section 1.3).
- Host constraint that shaped this tick: 3,910 MB RAM, 0 swap, 716 MB available at
  run time, single heavy-process slot. Peak RSS of the render was 380,828 kB (372 MiB,
  measured by `/usr/bin/time -v`). The 2,000-line recolour pass was deliberately not
  re-run.

## 1. What was built and what it proves

### 1.1 The scene

`godot/prototypes/character_material/character_material.gd` loads
`res://assets/volpe-rigged.glb` **twice** through `GLTFDocument` and places the two
independent scene graphs at world x = −0.75 and x = +0.75 m, both y = 0, both yaw 180°,
both holding the same pose (`Armature|clip0|baselayer` seeked to t = 0.300 s and paused,
the rig's only key). For each copy, every `MeshInstance3D` surface material is duplicated
and only `albedo_texture` is replaced:

```gdscript
out = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
out.albedo_texture = tex          # outfit-a.png for the left copy, outfit-b.png for the right
out.albedo_color = Color(1,1,1,1)
(mi as MeshInstance3D).set_surface_override_material(s, out)
```

One camera, one directional light, one flat background, one floor plane, **shadows
disabled on purpose** so that hiding one copy cannot change the other copy's pixels. Xvfb
+ llvmpipe, `--rendering-driver opengl3`, viewport 1280x720.

### 1.2 Engine facts printed by the render (verbatim from `render_1280x720.log`)

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf
Globals  RENDERER=gl_compatibility  ADAPTER=llvmpipe (LLVM 21.1.8, 256 bits)
         API=4.5 (Core Profile) Mesa 26.0.8-1ubuntu0.3
GLB_a_APPEND err=0        GLB_a_LOADED in 237 ms
GLB_b_APPEND err=0        GLB_b_LOADED in 192 ms
MESH_a 'char1' surfaces=1 faces=31325 verts_surface0=44829
MESH_b 'char1' surfaces=1 faces=31325 verts_surface0=44829
MAT_a surface=0 class=StandardMaterial3D shading_mode=1 has_albedo_texture=true albedo_color=(1,1,1,1)
MAT_a surface=0 ORIG albedo_texture=2048x2048
MAT_a surface=0 OVERRIDE class=StandardMaterial3D albedo_texture=2048x2048 albedo_color=white
ANIM_a/b held 'Armature|clip0|baselayer' at t=0.300 length=0.300 tracks=7
FRAMING_SHIFT_PX dx=501.4136 dy=0.0000
```

- The GLB's single material is a **lit** `StandardMaterial3D`
  (`shading_mode=1` = `SHADING_MODE_PER_PIXEL`, *not* unshaded), so a texture swap is
  expected to show under lighting — it is not the "unshaded material eats the override"
  failure mode. One surface, one material, exactly as the ticket records.
- **31,325 triangles / 44,829 vertices re-measured in engine**, an independent
  confirmation of the ticket's `glb_tri_count.py` number, from a different code path.

### 1.3 Inputs, hashes

| Input | Bytes | sha256 |
|---|---|---|
| `assets/volpe-rigged.glb` | 8,898,424 | `ab6b3086e6a455d9cdaaf8b198dfb762924b31cd77ee01bd8fe0135e9d687ec5` |
| `assets/outfit-a.png` (Midnight Violet) | 5,586,280 | `4b7c15d842f245d419ecf9a5ccd151c293b770bb7509d1308527df46a0430b80` |
| `assets/outfit-b.png` (Ember) | 5,661,745 | `a7e266e8160a9d5d2b8b113d788c54e87f1f2ad34128dedb18bd1251f0359c9b` |

Both PNG hashes equal the `outfit-a` / `outfit-b` hashes in
`tools/character/out/PROVENANCE.md` — the copies are byte-identical, no re-run.

## 2. Renders on disk

Three PNGs, one render process, same camera / light / pose / frame count for all three.

| File | Bytes | sha256 | Dimensions | Distinct RGB colours (whole frame) |
|---|---|---|---|---|
| `outfit_ab_side_by_side_1280x720.png` | 277,445 | `a5797073fd13412b9d4344fd8e47a67d7d25c5b36b3eea018441dc005bd37764` | 1280x720 RGBA | 13,587 |
| `outfit_a_only_1280x720.png` | 157,470 | `47d9586f3a6aa40d2f46189df59664e6e99195446bd8659c669ed7620f7d2e82` | 1280x720 RGBA | 7,858 |
| `outfit_b_only_1280x720.png` | 152,433 | `aca8dcddff3210a4a6e07128bb855797bd3cd7afc46273363730eb45456ba2d1` | 1280x720 RGBA | 7,744 |

Not blank: the side-by-side frame has 13,587 distinct RGB values, channel range 0–255,
std 61.29, and 495,519 px (53.8 %) differ from the background colour `(56,61,71)`. The
body region of each copy (297x557 px) holds 6,322 / 6,185 distinct RGB values. Three
derived analysis images were also written (they are **derived**, not renders):
`derived_diff_amplified_6x_ab_regions.png` (177,199 B,
`4b7b24cea5678ac7f545689be864d1ad5d645e7d669347bbaa621bf5162eee4f`),
`derived_side_by_side_A_left_B_right_2x.png` (270,260 B),
`derived_torso_band_A_left_B_right_3x.png` (163,521 B).

## 3. Measured difference between the two rendered outfits

### 3.1 Measurement controls (both passed exactly)

The two single-outfit frames are captured with the *other* copy hidden. Comparing the
left copy's pixels in the side-by-side frame with the same pixels in the A-only frame:

| Control | Pixels | mean abs diff |
|---|---|---|
| copy A region: side-by-side frame vs A-only frame | 165,429 | **0.0000** |
| copy B region: side-by-side frame vs B-only frame | 165,429 | **0.0000** |

Exactly zero, max euclidean 0.0, zero pixels above any threshold. The renderer is
deterministic and **the two copies cannot affect each other**, so any difference between
the two regions is attributable to the texture (or to camera geometry — see 3.2).

### 3.2 A fixed-shift region comparison is invalid here, and had to be replaced

Copy B is a pure world translation of copy A, but under perspective a world translation
is **not** a screen translation. With f = 869.0 px (640 px half-width at the 1.9146 m
half-width plane, 2.60 m away) the disparity of the 1.5 m offset is 1.5·f/d, which
depends on the surface's camera depth d:

| surface depth d | predicted screen shift |
|---|---|
| 2.3 m (0.3 m nearer camera than the model origin) | 566.7 px |
| 2.6 m (the model origin plane — the value the engine printed) | 501.4 px |
| 2.9 m (0.3 m behind) | 449.5 px |

A body with ~0.6 m of depth therefore has a **117 px spread of local disparity** across
its surface. Measured evidence that this is real, not theoretical: a per-48 px-block
search over shifts found best local shifts scattered from −80 px to +62 px on the torso
and shorts (7 of 53 blocks hit the ±80 px search bound).

Numbers, reported with that caveat attached:

| Statistic | Value |
|---|---|
| Fixed-shift region diff, dx = 501.4 px (best-effort single shift) | mean abs **21.12**/255, mean euclidean 37.68, 25.1 % of px > 10 |
| Same, rounded to 501 px (integer) | mean abs 21.36/255 (this is the number a naive comparison reports) |
| Sub-pixel resampled floor: copy A resampled by the same 0.4136 px fraction vs itself | mean abs 1.93/255 (body px) |
| Per-block local best shift (48 px blocks, 53 blocks, shift search ±80 px) | residual mean **9.84**/255, median **5.43**, min 0.16, max 40.80 |

### 3.3 The alignment-free measurement (the number that survives all of the above)

Spatial misalignment is zero-mean, so a *signed* difference of region means is immune to
it. Over **all rendered body pixels** of each copy (identical masks):

| | A (Midnight Violet) | B (Ember) | A − B |
|---|---|---|---|
| mean rendered RGB | (138.00, 139.13, 141.58) | (138.49, 140.31, 142.76) | **(−0.49, −1.18, −1.18)** |

Per body window (fractions of the measured 561 px body span, same signed statistic):

| Window | A mean RGB | B mean RGB | A − B (signed) |
|---|---|---|---|
| head (0.02–0.10) | (175.48, 173.75, 167.50) | (175.69, 174.79, 169.02) | (−0.21, −1.05, −1.53) |
| upper_back (0.20–0.32) | (228.92, 219.96, 203.20) | (229.52, 220.03, 201.39) | (−0.60, −0.07, +1.81) |
| mid_torso (0.32–0.45) | (196.21, 194.45, 190.32) | (197.43, 197.20, 194.19) | (−1.22, −2.75, −3.86) |
| waist_hip (0.45–0.56) | (111.96, 114.44, 126.39) | (107.12, 113.64, 126.98) | (+4.84, +0.80, −0.59) |
| shorts (0.56–0.68) | (186.79, 184.06, 180.48) | (190.67, 190.38, 186.03) | (−3.88, −6.32, −5.55) |
| thigh (0.70–0.82) | (211.92, 209.38, 199.98) | (212.33, 211.17, 201.84) | (−0.41, −1.80, −1.86) |
| feet (0.94–0.99) | (103.41, 107.82, 121.56) | (101.62, 107.53, 123.49) | (+1.79, +0.29, −1.93) |

Largest garment-region shift: ~6/255 in the shorts. Whole-model shift: ~1.2/255.

### 3.4 What the two textures carry (measured this tick, offline)

| | mean RGB | 
|---|---|
| source `volpe-texture.png` | (215.722, 202.313, 179.701) |
| `outfit-a.png` | (213.846, 203.036, 184.266) |
| `outfit-b.png` | (215.394, 201.310, 178.205) |

- mean abs A−B over the whole 2048x2048 atlas: **4.874**/255 (agrees with 4.873 in
  `diff-report.json`); texels changed (any channel > 2): **14.5 %**.
- Over those changed texels only: signed A−B = (−12.76, +8.13, **+44.86**), mean abs
  **33.60**/255. So where the recolour acts, it acts strongly and in the right direction
  (A cooler / more blue, B warmer / less blue).

The render cannot show more than the texture carries, and the texture carries a
mean-colour change of ≤ 6.5/255 per channel.

## 4. Plain verdict

**The proposed path works. The two outfits are not visually distinct.**

- *Works:* one rigged GLB, one material, one surface, one skeleton per copy; two
  per-instance `albedo_texture` overrides; both copies render in one frame; the override
  is applied to a lit `StandardMaterial3D` and was logged; the two rendered bodies are
  demonstrably not the same render (null controls exactly 0, cross-copy signed shifts of
  1–6/255, alignment-free). Nothing here depends on sprite paths or on the PNG diff tool.
- *Not distinct:* the strongest statistic that survives the geometry problem — the mean
  colour of the rendered model — moves by 1.2/255 (0.5 %) between the two outfits, with
  garment windows up to 6/255 (2.4 %). At 1280x720 in this lighting a look at
  `outfit_ab_side_by_side_1280x720.png` does not read as two different kits. This is
  what the texture carries (section 3.4): a 4.874/255 mean change over 14.5 % of the
  atlas, concentrated in near-neutral garment texels, is a tint, not an outfit.
- *Honest hole in the measurement:* the two copies stand off-axis at ±0.75 m, so their
  view vectors differ by ±16°. Any view-dependent shading term (specular is not zero at
  the GLB's roughness) is therefore mixed into every cross-copy number. The fur/head
  window shows a signed shift of the same order as the whole-body shift
  ((−0.21, −1.05, −1.53)/255), which is consistent with either "the recolour also tints
  fur" or "a ~1/255 view-dependent floor". The `|diff|` statistics cannot separate the
  two: per-block residuals do not localise to garments (head blocks mean 8.00, legs
  11.98, torso 10.16). The 1/255 view-term is an inference, not a measurement.

Consequences for the ticket: the render proves the **mechanism**, not the **outcome**
("one rigged model into satisfying outfits"). The item stays open.

## 5. Commands, with exit codes

```bash
# attempt 1 (failed, no PNGs): the first script version used Vector3 for a Vector2
#   return value; Godot reported two parse errors and never started the render,
#   so the 300 s wrapper in render.sh expired.
cd godot/prototypes/character_material && ./render.sh 1280x720     # exit 124 (timeout wrapper)

# syntax gate before the second (and last) render attempt:
GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --check-only --script res://character_material.gd                # exit 0, no output

# attempt 2 (the render this evidence is built on):
cd godot/prototypes/character_material && /usr/bin/time -v ./render.sh 1280x720
#   exit 0, "RESULT: CM_PASS", 3 PNGs written, wall clock 4.74 s,
#   Maximum resident set size 380,828 kB

# measurement (all offline, no engine, all exit 0):
python3 measure.py                 # exit 0 -> measure-report.json       (integer-shift + null controls)
python3 measure_aligned.py         # exit 0 -> measure-aligned.json      (sub-pixel resample + floor)
python3 measure_local_shift.py     # exit 0 -> measure-local-shift.json  (per-window signed shifts)
python3 measure_regions.py         # exit 0 -> measure-regions.json      (per-window means)
python3 measure_blocks.py          # exit 0 -> measure-blocks.json       (48 px tiled local alignment)
```

`render.sh` uses `xvfb-run` + `--rendering-driver opengl3`, **not** `--headless`: with
`--headless` Godot installs the dummy rendering driver and the viewport capture would be
blank. That is the same proven recipe as
`godot/prototypes/render_probe/render.sh` and `godot/prototypes/arena_spike/render.sh`.
Attempts used: **2 of 2** (one failed on a script parse error, one succeeded).

## 6. Next diagnostic (if the ticket item is to be closed)

1. **Remove the geometry asymmetry, then re-measure.** Render one copy at x = 0 (centred,
   camera straight on) twice in separate frames, one per outfit — the render log's
   `FRAMING_SHIFT_PX` becomes 0 and the two frames are pixel-comparable with no
   disparity and no view-vector difference. That turns the 1/255 inference in section 4
   into a measurement. Straightforward: set `MODEL_DX = 0.0`, capture A, swap the
   texture, capture B.
2. **Separate "weak recolour" from "weak render".** Raise the target-colour delta in
   `tools/character/outfits.json` (0 credits, 0 API calls) and re-render. If the visible
   difference scales with the atlas delta, the limit is authoring strength; if it does
   not, the limit is the render/override path and question (i) is answered the other way.
3. Log `StandardMaterial3D.roughness` / `metallic` of the GLB's material next run — it
   bounds the specular asymmetry that step 1 removes.
