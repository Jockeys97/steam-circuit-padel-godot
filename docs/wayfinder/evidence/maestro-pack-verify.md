# IL MAESTRO asset pack — independent verification report

Verified: 2026-09-16 23:10 CEST, by direct parsing of the shipped bytes. Read-only: nothing in
`/Users/lucafantini/Downloads/maestro-asset-pack-20260916/maestro-asset-pack/` or in the repository
was written; no Godot, no installs, python3 standard library only (struct, json, hashlib, os, math).

Pack under test: `maestro-rigged.glb`, `maestro-idle.glb`, `maestro-walking.glb`,
`maestro-running.glb`, `maestro-texture.png`, `hashes.json`, `RESULT.md`, `RUN-SUMMARY.md`,
`INSERT-NOTES.md`, `01-gen-thumbnail.png`, `02-remesh-thumbnail.png`.
Referenced comparison file: `godot/assets/athletes/volpe-rigged.glb` (repository, read-only).
`01-gen.glb` is listed in `hashes.json` but is not shipped; `INSERT-NOTES.md` states it is
intentionally excluded ("Not included … it stays on the Linux side"). Treated as expected-absent.

## Bottom line

All four GLBs parse as well-formed glTF 2.0 (Khronos glTF Blender I/O v4.0.43). Every hash and
byte count in `hashes.json` for shipped files matches exactly. Every structural claim (triangles,
vertices, joints, material, embedded image, clip names, durations, 72 channels, single-key rigged
clip) verifies. The joint-name identity claim against `volpe-rigged.glb` verifies exactly (same 24
names, same order). Two transform claims do not reproduce from the bytes: the world height
"about 1.59 m" and the stripped-scale "about 158 m" (measured candidates: 1.799999 m kept per
glTF-spec skinning, 180.000 m predicted with the 0.01 removed). The mesh POSITION data is already
metric (Y 0 → 1.799999 m) and the Armature 0.01 scale is exactly compensated by the 24 inverse
bind matrices (net joint-matrix scale 1.000000); see section 6.

Exact contradiction list and claims table below.

## 1. Claims table

| # | Claim | Expected | Measured | Verdict |
|---|---|---|---|---|
| 1 | `hashes.json`: "every file it lists exists on disk and matches its recorded sha256 AND byte size" | 8/8 entries match | 7 entries on disk; 6 shipped files match bytes+sha256 exactly (full values in section 2). `01-gen.glb` (80,674,496 B) is listed and absent — expected-absent per INSERT-NOTES. 4 pack files are not listed at all: RESULT.md, RUN-SUMMARY.md, INSERT-NOTES.md, hashes.json itself | MATCH (for all shipped files); 1 expected absence |
| 2 | GLB structure: single mesh/skin/material/image; clips per file | — | All four: 1 mesh, 1 primitive, 1 material, 1 skin, 1 image (image/png, no URI, embedded via bufferView 6), 2 texture objects, 1 animation, 26 nodes, 1 scene; 12-byte header glTF v2, declared length == file length, JSON+BIN chunks only, 0 trailing bytes; no `uri` keys anywhere (fully embedded) | MATCH |
| 3 | Each file has "30,980 triangles" | 30,980 | indices accessor count 92,940, mode TRIANGLES (4); 92,940/3 = 30,980 exactly (all four files) | MATCH |
| 4 | Each file has "45,218 vertices" | 45,218 | POSITION accessor count 45,218 (VEC3 float), all four files | MATCH |
| 5 | Each file has "24 skin joints" | 24 | `skin.joints` length 24; inverseBindMatrices accessor count 24 (all four) | MATCH |
| 6 | Each file has "exactly 1 embedded image, 1 material" | 1 / 1 | images = 1 (mimeType image/png, uri absent, bufferView 6, 7,411,125 B); materials = 1 ("Material_1"); all four files | MATCH |
| 7 | rigged = single clip, "0.30 s single-key bind hold" | 1 clip, 1 key, 0.30 s | `Armature|clip0|baselayer`, 72 channels, every sampler 1 key at t = 0.300000; duration = max(input) = 0.300000. Note: the single key sits at t = 0.300 (not t = 0); the pose is constant so it is a hold either way | MATCH |
| 8 | idle = Idle, about 4.033 s | 4.033 s | `Armature|Idle|baselayer`, 72 channels, duration 4.033333 → 4.033 s; sampler key counts {2, 121} (first key t = 0.033333) | MATCH |
| 9 | walking = walking_man, about 1.067 s | 1.067 s | `Armature|walking_man|baselayer`, 72 channels, duration 1.066667 → 1.067 s; key counts {2, 32} | MATCH |
| 10 | running = running, about 0.667 s | 0.667 s | `Armature|running|baselayer`, 72 channels, duration 0.666667 → 0.667 s; key counts {2, 20} | MATCH |
| 11 | Material: "emissiveFactor is 1,1,1" | [1,1,1] | [1,1,1] in all four files | MATCH |
| 12 | Material: "the base colour texture doubles as the emissive map" | same image | baseColorTexture → texture[1] → image 0; emissiveTexture → texture[0] → image 0. Two texture objects, identical source image (the 7,411,125 B PNG). Same image in all four files | MATCH |
| 13 | Material: "metallicFactor unset (glTF default 1)" | absent | `metallicFactor` key absent in all four (glTF default 1) | MATCH |
| 14 | Material: roughnessFactor unset | absent | Absent in rigged, walking, running; PRESENT in idle = 0.4100847542285919. (INSERT-NOTES does not state a roughness expectation; reported as measured.) | MATCH (with deviation noted) |
| 15 | Material: baseColorTexture present; alphaMode; doubleSided | — | baseColorTexture {"index":1} present ×4; alphaMode key absent ×4 (glTF default OPAQUE); doubleSided true ×4 | MATCH |
| 16 | "identical 24 joint names to volpe-rigged.glb, Hips through headfront" | identical | Both files: 24 joints; sets identical, ordered lists identical, symmetric difference empty (section 5). All four pack files share the same set and order | MATCH |
| 17 | "the Armature root carries scale 0.01" | 0.01 | Scene root node "Armature" local scale = (0.009999999776482582, ×3) = float32 0.01; the only node in the file whose scale differs from 1 (all others within 2.4e-7); cumulative scale 0.01 to the mesh node and to all 24 joints | MATCH |
| 18 | "world height about 1.59 m at the 1.8 m source" | ~1.59 m | "1.8 m source" confirmed: mesh POSITION Y extent = 1.799999 m. World-height candidates: literal formula (extent × cumulative scale) = 0.018000 m; glTF-spec skinning at the file's default pose = 1.799999 m; top skeleton node (head_end) = 1.800208 m. No parse-side computation produces 1.59 m | MISMATCH (not reproduced) |
| 19 | "stripping that scale makes the model about 158 m tall" | ~158 m | With the Armature 0.01 set to 1 (all else identical), the spec-skinning prediction is 100 × raw = 180.000 m; the literal formula gives 1.8 m. Neither is 158 m | MISMATCH (not reproduced) |
| 20 | "feet at Y 0" | 0 | Skinned min Y = 0.000000 m; mesh POSITION declared min Y = 3.179196994551603e-08 m (float noise ≈ 0). All four files | MATCH |
| 21 | "Walking and running carry the same mesh" / idle "same mesh and 24-joint skeleton as the rigged file" | same mesh | Mesh buffer bytes sha256 identical across all four files (90814a66…, section 4); nodes/skins/meshes/images JSON-equal across all four; materials equal except idle's roughnessFactor | MATCH |
| 22 | "One material, one embedded base colour texture (7.4 MB PNG, extracted as maestro-texture.png)" | byte-identical extraction | Image byteLength 7,411,125 B (= 7.4 MB decimal); sha256 7a88e6f43acccf97…; byte-identical (same sha256) to the shipped `maestro-texture.png`. Same PNG in all four GLBs | MATCH |
| 23 | 01-gen.glb: "80,674,496 B; 1,659,582 tris; 1,778,564 verts; joints=0; skins=0; images=1; sha fd8452c8…" | — | File intentionally not shipped (INSERT-NOTES); hash and counts cannot be computed | NOT-PARSED (expected-absent) |
| 24 | "Front is +Z" (extra check, not in the required list) | +Z | Foot→toe horizontal direction is +Z on both feet: Left (0.0253, −0.0855, +0.1172) m, Right (−0.0270, −0.0871, +0.1172) m (toe forward of ankle). Consistent at parse level; visual/engine confirmation still per INSERT-NOTES | MATCH (extra) |

## 2. hashes.json verification (bytes + sha256 recomputed)

| File | Recorded bytes | Measured bytes | sha256 equal | sha256 (recomputed) |
|---|---|---|---|---|
| maestro-rigged.glb | 9,974,896 | 9,974,896 | yes | f314518555bde367bd8971bb1933d5c1a0ae01e50ab4a9c61f52676402b6496e |
| maestro-walking.glb | 9,987,672 | 9,987,672 | yes | d742f4597d6dada3bc4493735a162c816e7f42c988dfcdfe13f353ab0503dba8 |
| maestro-running.glb | 9,983,076 | 9,983,076 | yes | f7f98512d5474a2c0d5e294355f22340444faec7b20a49060eeb97737a63a79b |
| maestro-idle.glb | 10,023,848 | 10,023,848 | yes | 48430822f3621baf54ec5e780f390dbef46772903e771c5b05a3d6c2af9872b8 |
| 01-gen.glb | 80,674,496 | file absent | n/a | recorded fd8452c83d570b317d31787f808a7cb6f2e3f256f452132263f93110f75036d0 — not verifiable |
| maestro-texture.png | 7,411,125 | 7,411,125 | yes | 7a88e6f43acccf973f3e1f6e8ad10e30c1a0f1a1a2a642e1c208e30dd6c65d66 |
| 01-gen-thumbnail.png | 72,847 | 72,847 | yes | 933d9913ee065faeaf9888484c415d91e9d6728d6353381d4217e5e900c26862 |
| 02-remesh-thumbnail.png | 72,479 | 72,479 | yes | 2343cba93846dbb9a802f5a940b5cb52f30c1a7ef041923c7ce969594201b77f |

Missing (listed, not on disk): `01-gen.glb` — expected-absent per INSERT-NOTES.
Unlisted (on disk, no hash recorded): `RESULT.md` (5,670 B), `RUN-SUMMARY.md` (1,113 B),
`INSERT-NOTES.md` (3,112 B), `hashes.json` itself (1,025 B).

## 3. Raw numbers per GLB

GLB container facts: magic `glTF`, version 2, declared length == file size, exactly two chunks
(JSON then BIN), trailing bytes 0. Chunk lengths (JSON / BIN): rigged 24,024 / 9,950,844; idle
24,404 / 9,999,416; walking 24,308 / 9,963,336; running 24,320 / 9,958,728. Buffer count 1 per
file, no `uri` anywhere; generator `Khronos glTF Blender I/O v4.0.43`; asset version 2.0.

| | rigged | idle | walking | running |
|---|---|---|---|---|
| bytes | 9,974,896 | 10,023,848 | 9,987,672 | 9,983,076 |
| triangles (indices/3) | 30,980 (92,940/3) | 30,980 | 30,980 | 30,980 |
| vertices (POSITION count) | 45,218 | 45,218 | 45,218 | 45,218 |
| meshes / primitives | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| skin joints / IBM count | 24 / 24 | 24 / 24 | 24 / 24 | 24 / 24 |
| materials | 1 | 1 | 1 | 1 |
| textures / images | 2 / 1 | 2 / 1 | 2 / 1 | 2 / 1 |
| image size / mime | 7,411,125 B / image/png | same | same | same |
| animations | 1 | 1 | 1 | 1 |
| clip name | Armature\|clip0\|baselayer | Armature\|Idle\|baselayer | Armature\|walking_man\|baselayer | Armature\|running\|baselayer |
| duration (s, max of sampler input) | 0.300 (→ 0.300) | 4.033333 (→ 4.033) | 1.066667 (→ 1.067) | 0.666667 (→ 0.667) |
| first key time (s) | 0.300 | 0.033333 | 0.033333 | 0.033333 |
| channels / samplers | 72 / 72 | 72 / 72 | 72 / 72 | 72 / 72 |
| unique sampler key counts | {1} | {2, 121} | {2, 32} | {2, 20} |
| sampler interpolation | LINEAR | LINEAR + STEP | LINEAR + STEP | LINEAR + STEP |
| mesh attribute bytes sha256 | 90814a662675aff2282e1437fc1fefd4a4f3fc80193e2bfdd2833a404401dacf (identical in all four) | | | |

Attribute accessors (identical in all four): POSITION VEC3 float32 count 45,218 (bufferView 0);
NORMAL VEC3 float32; TEXCOORD_0 VEC2 float32; JOINTS_0 VEC4 unsigned byte count 45,218 (bufferView 3);
WEIGHTS_0 VEC4 float32 (bufferView 4), weight sums = 1 within 1.26e-7. Indices UNSIGNED_SHORT (5123).
All bufferViews tightly packed (no byteStride).

Animation channels are 24 joints × {translation, rotation, scale} = 72 channels per file.
Motion samplers are LINEAR (idle/walking/running mix in STEP samplers for constant channels).

Material block per file — name `Material_1` everywhere:
- `emissiveFactor`: [1, 1, 1] (all four)
- `emissiveTexture`: {"index": 0} → image 0 (all four)
- `pbrMetallicRoughness.baseColorTexture`: {"index": 1} → image 0 (all four) — same source image as the emissive map
- `pbrMetallicRoughness.metallicFactor`: absent (all four) → glTF default 1
- `pbrMetallicRoughness.roughnessFactor`: absent in rigged/walking/running; 0.4100847542285919 in idle
- `pbrMetallicRoughness.baseColorFactor`: absent (all four) → default [1,1,1,1]
- `alphaMode`: absent (all four) → default OPAQUE; `doubleSided`: true (all four)

## 4. Cross-file identity

- Mesh buffer bytes (bufferViews 0–5, concatenated): sha256 identical across all four files
  (90814a662675aff2282e1437fc1fefd4a4f3fc80193e2bfdd2833a404401dacf). The four GLBs differ only
  in the animation data (and idle's roughnessFactor).
- Embedded image bytes: sha256 7a88e6f43acccf973f3e1f6e8ad10e30c1a0f1a1a2a642e1c208e30dd6c65d66 in
  all four files, byte-identical to the shipped `maestro-texture.png`.
- `nodes`, `skins`, `meshes`, `images` arrays are JSON-equal across all four files; `materials`
  equal except the idle roughnessFactor difference.

## 5. Joint-name comparison (maestro-rigged.glb vs volpe-rigged.glb)

maestro-rigged.glb joints (24), in skin order:
`Hips, LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase, RightUpLeg, RightLeg, RightFoot, RightToeBase,
Spine02, Spine01, Spine, LeftShoulder, LeftArm, LeftForeArm, LeftHand, RightShoulder, RightArm,
RightForeArm, RightHand, neck, Head, head_end, headfront`

volpe-rigged.glb joints (24), in skin order: identical list, element for element.

- sets identical: True; ordered lists identical: True; in maestro not in volpe: none;
  in volpe not in maestro: none; first position-wise difference: none.
- maestro-idle / walking / running: joint sets and order equal to maestro-rigged (True/True each).
- Both skins have no `skeleton` property set (skin.skeleton absent in both files); joints are the
  24 nodes under the "Armature" node in both files.

## 6. Transform and height analysis (maestro-rigged.glb; identical in the other three)

Node chain, scene root to mesh/skeleton (scene has a single root; every scale below is the node's
local scale):

```
node[25] "Armature"      local scale (0.009999999776482582, 0.009999999776482582, 0.009999999776482582)   <- carries the 0.01
  node[24] "char1"       local scale (1, 1, 1)          mesh=0, skin=0        cum_scale 0.01
  node[23] "Hips"        local scale ~(1, 1.0000002, 0.99999994)             cum_scale 0.01   (skeleton root)
    ... 22 further joint nodes, each local scale within 2.4e-7 of 1.0        cum_scale 0.01
```

- The `0.01` is carried by exactly one node: `Armature` (the scene root), all three axes
  (float32 0.00999999977648). No other node scales away from 1.0 by more than 2.4e-7.
- Cumulative scale from scene root to the mesh node `char1` = (0.01, 0.01, 0.01); same to every
  one of the 24 joints.
- Mesh POSITION bounds (computed from the BIN chunk; declared accessor min/max match):
  min (−0.4631872, 3.179196994551603e-08, −0.1805340), max (0.4631872, 1.7999994755, 0.1805340).
  Y extent = 1.799999 m — the mesh data itself is metric and 1.8 m tall ("the 1.8 m source").

World height, three computed candidates:
1. Literal formula from the request (POSITION Y extent × cumulative scale): 1.799999 × 0.01 =
   0.018000 m.
2. glTF-spec skinning at the file's default pose (world vertex = Σ w_q · W(joint_q) · IBM_q · v,
   computed over all 45,218 vertices with the file's own JOINTS_0/WEIGHTS_0/IBM data):
   y_extent = 1.799999 m, min_y = 0.000000 m. Cause, measured: the 24 products
   W(joint) × IBM equal the identity (per-axis scale mean 0.99999988 / 0.99999989 / 0.99999998,
   max axis deviation 3.3e-7, max translation 4.7e-7 m) — the Armature 0.01 scale is exactly
   compensated by the inverse bind matrices at the spec level, so the at-rest rendered size
   equals the raw mesh size: 1.80 m.
3. Highest skeleton node: world Y of `head_end` = 1.800208 m.

Consequences for the claims:
- "world height about 1.59 m": not produced by any of the three computations (0.018 / 1.799999 /
  1.800208 m). MISMATCH / not reproduced. For reference, the repo's `volpe-rigged.glb` parsed
  with the same code shows the same construction (Armature 0.01, raw Y extent 1.800000 m, net
  joint scale 1.000000, head_end 1.723279 m), so the 1.59 m figure does not reproduce from the
  volpe bytes either.
- "stripping that scale makes the model about 158 m tall": with the Armature node's scale set
  to 1 the joint matrix product becomes 100 × identity, giving a predicted 180.000 m; the literal
  formula gives 1.8 m. 158 m is not reproduced by either. MISMATCH / not reproduced.

These two numbers are recorded in INSERT-NOTES.md as engine-side observations ("measured on the
Volpe rig"); byte-level parsing cannot re-run an engine. They are reported as not reproduced, and
the strongest signals in the bytes (mesh metric data at 1.8 m, net joint-matrix scale exactly
1.000000, top bone at 1.800208 m) all indicate a 1.80 m at-rest model.

Feet on floor: minimum vertex Y after skinning = 0.000000 m (declared accessor min Y
3.179196994551603e-08 m, i.e. within float epsilon of 0). MATCH for "feet at Y 0".

Facing (extra check): foot → toe-base world vectors point +Z on both feet (Left
(0.0253, −0.0855, +0.1172) m, Right (−0.0270, −0.0871, +0.1172) m), consistent with "Front is +Z"
at parse level. Ankle world Y ≈ 0.125 m, toe-base world Y ≈ 0.039 m, Hips world Y = 0.948774 m,
Head world Y = 1.605038 m.

## 7. Not parsed / not verifiable

- `01-gen.glb` (80,674,496 B, "1,659,582 tris, 1,778,564 verts, joints=0, skins=0, images=1",
  sha fd8452c8…) — the file is intentionally not shipped; its recorded numbers are NOT-PARSED.
  Its absence is consistent with INSERT-NOTES.md ("Not included").
- Engine-side behavior (Godot import specifics: the 1.59 m / 158 m notes) — cannot be reproduced
  by byte-level parsing; see section 6.
- Thumbnail PNG contents — only hash-verified (no visual inspection was performed; not required).
- Visual defect claims (fingers, smudge, stripe edges) — not parseable; out of scope here.

## 8. Method

Two throwaway scripts, both stdlib-only, run with the system python3; both open files read-only
(`open(path, "rb")`) and write nothing to the pack or the repository:

- `/tmp/maestro_parse.py` — sections 1–9: inventory, hashes.json re-hash, per-GLB structural
  parse, materials, skins, animations, node tree, skinning math, cross-file comparison, volpe
  comparison. Full stdout saved at `/tmp/maestro_parse_out.txt`.
- `/tmp/maestro_supp.py` — joint world positions and facing direction.

Approach:
- sha256: `hashlib.sha256` over the full file in 1 MiB chunks; compared to `hashes.json` values
  (read with json).
- GLB: header unpacked with `struct.unpack_from("<4sII")`; chunk loop reading `(length, type)`
  pairs (JSON 0x4E4F534A, BIN 0x004E4942); JSON chunk `json.loads`; accessors read from the BIN
  chunk via bufferView byteOffset + accessor byteOffset with byteStride fallback (all views here
  are tightly packed, stride unset).
- Counts: triangles = indices accessor count // 3 (checked mode == 4 TRIANGLES); vertices =
  POSITION accessor count; joints = len(skin.joints) and IBM accessor count; images/materials/
  animations/textures read from the JSON directly.
- Durations: max over each animation sampler's input accessor declared max; cross-checked against
  binary key counts (e.g. idle's 121-key samplers at 0.033333 s spacing end at 4.033333).
- Transforms: local matrices from TRS (quaternion → rotation matrix) or the `matrix` form; world
  matrices as chain products from scene roots; "scale" extracted as column norms; cumulative
  scale as a per-axis product along the chain.
- Skinning: joint matrices N = world(joint) × IBM (IBM read from the accessor as 24 MAT4 floats);
  skinned world vertex = Σ w_q · N · v over the file's own JOINTS_0/WEIGHTS_0, positions, and IBM
  data; weight/index dequantization applied only if `normalized` (here both are non-normalized;
  weights float32 summing to 1 within 1.26e-7).
- volpe-rigged.glb read with the same code, read-only, for the joint-name and transform reference.
- No estimates or "likely" values anywhere in this report; every number above was printed by the
  scripts. No external URIs exist in the files (all buffers and images embedded; `uri` key count = 0).
