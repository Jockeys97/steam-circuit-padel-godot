# Evidence: the athlete rig — locomotion, strokes, outfits, in engine

- Date: 2026-09-16
- Lane: athlete (rig + animation + outfits). Owns `godot/src/character/**`,
  `godot/assets/athletes/**`, `godot/tests/athlete_rig_test.gd`, new files under
  `tools/character/**`, and this file. Nothing else was written.
- Tickets fed: [`../tickets/character-pipeline-economics.md`](../tickets/character-pipeline-economics.md)
  (its named next diagnostic — *one copy at x = 0, one frame per outfit, then raise
  the target-colour delta* — is executed here) and
  [`../tickets/athlete-roster-order.md`](../tickets/athlete-roster-order.md).
- Method: Godot 4.7.2 stable (`ed1daf0bf001b61586d9930840f2f1394092c079`), software
  GL only (Xvfb + Mesa llvmpipe, `--rendering-driver opengl3`). Offline measurement
  with numpy/PIL. **No Meshy call, no paid API, no network, 0 credits, no new 3D
  assets generated.** Every heavy process ran under `flock /tmp/padel-godot.lock`.
- Software GL caveat, stated once and applying to everything below: these renders
  are valid for **correctness**, and carry **no frame-rate claim whatsoever**.

---

## 0. What existed before this slice, and what is new

Before: three Meshy trial GLBs (`meshy/rigged/volpe/`), an offline recolour tool
with one weak outfit pair, and a two-copy prototype render
(`godot/prototypes/character_material/`) that proved the material-override
*mechanism* but produced only a 1.2/255 whole-model colour shift — "a tint, not an
outfit". There was **no rig scene, no animation proof, no stroke, and no test**.

New in this slice:

| Artifact | What it is |
|---|---|
| `godot/src/character/AthleteRig.tscn` + `athlete_rig.gd` | the reusable rig, documented narrow API |
| `godot/src/character/rig_render.gd` + `RigRender.tscn` + `render.sh` | the render evidence producer |
| `godot/src/character/tools/*.gd` | three read-only probes (structure, root motion, extent) |
| `godot/tests/athlete_rig_test.gd` | the headless gate, `PASS 41/41` |
| `tools/character/recolour_outfits_tiled.py` | memory-lean driver for the existing recolour tool |
| `tools/character/out-strong/` | the strong outfit pair the ticket prescribed |
| `godot/assets/athletes/` | in-project copies of the 3 GLBs + 4 outfit atlases |
| `godot/src/character/out/` | 25 rendered PNGs + derived sheets + measurement JSON |

`godot/project.godot` was **not** touched (it belongs to another lane). The render
scene is launched by explicit scene argument instead. Confirmed no collateral damage:
the other lane's harness still reports `PASS 8/8` (section 7).

---

## 1. Rig structure — measured, not assumed

`godot/src/character/tools/rig_probe.gd` loads each GLB through `GLTFDocument` and
dumps the node tree, bone table and animation tracks.

```
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://src/character/tools/rig_probe.gd          # exit 0, "PROBE_DONE"
```

All three GLBs are structurally identical:

| | volpe-rigged | volpe-walking | volpe-running |
|---|---|---|---|
| `append_from_file` err | 0 (158 ms) | 0 (127 ms) | 0 (129 ms) |
| Skeleton3D bones | 24 | 24 | 24 |
| bone names / parents | identical | identical | identical |
| mesh | `char1`, 1 surface, skinned | same | same |
| triangles | 31,325 | 31,325 | 31,325 |
| material | `Material_1` StandardMaterial3D, 1 albedo texture 2048x2048 | same | same |
| clip | `Armature\|clip0\|baselayer` 0.3000 s, 7 tracks, 10 keys | `Armature\|walking_man\|baselayer` 1.0667 s, 27 tracks, 33 keys | `Armature\|running\|baselayer` 0.6667 s, 30 tracks, 21 keys |
| track path shape | `Armature/Skeleton3D:<bone>` | identical | identical |

The 24 joints, in the GLB's own order:
`Hips, LeftUpLeg, LeftLeg, LeftFoot, LeftToeBase, RightUpLeg, RightLeg, RightFoot,
RightToeBase, Spine02, Spine01, Spine, LeftShoulder, LeftArm, LeftForeArm, LeftHand,
RightShoulder, RightArm, RightForeArm, RightHand, neck, Head, head_end, headfront`.

**Consequence, and it is the central structural result of this slice: there is no
retargeting problem.** The walk and run clips address exactly the same bone names
through exactly the same node paths as the base rig, so they are adopted as plain
`Animation` resources into the base rig's `AnimationLibrary` and play directly. The
ticket listed "whether Godot retargets Meshy's 24-joint humanoid onto hand-authored
padel strokes" as open; for these three files the answer is that **no retarget step
is required at all**, because they are one rig exported three times.

Two corrections to prose already on disk, both measured:

- `meshy/rigged/RESULT.md` and the slice brief describe `volpe-rigged.glb` as holding
  "a single-key pose — NOT an idle clip". Measured: the clip is 0.3000 s long with
  **7 tracks of 10 keys each**. It is a short authored motion, not one key. It is
  weak (7 of 24 joints move) but it is not static, and it animates the skeleton
  (section 3).
- The GLB material imports with **`metallic = 1.0, roughness = 1.0`** — the glTF
  defaults for a file that never authored `pbrMetallicRoughness`. This was never
  logged before and it matters a great deal for outfit colour (section 5).

---

## 2. The rig scene and its API

`godot/src/character/AthleteRig.tscn` — a `Node3D` with `athlete_rig.gd`. It loads
the GLBs at **runtime** through `GLTFDocument`, so it needs no `.import` cache and
no `project.godot` entry, and cannot collide with another lane's import database.

The full public contract, copied from the script's header comment (the header is the
contract; an integrator should not have to read the body):

```
OUTFIT      set_outfit(id) -> bool | get_outfit() | get_outfit_ids()
FACING      set_facing_degrees(yaw) | get_facing_degrees() | face_towards(Vector3)
LOCOMOTION  play_locomotion(&"idle"|&"walk"|&"run") -> bool
            get_locomotion_states() | get_locomotion_state() | set_locomotion_speed_scale(s)
STROKES     play_stroke(&"drive"|&"slice"|&"lob"|&"serve") -> bool
            get_stroke_names() | is_stroking() | signal stroke_finished(stroke)
POSE        get_pose() -> {clip,time,length,locomotion,stroke,outfit,facing_degrees,bones[24]}
            get_skeleton() -> Skeleton3D | get_world_extent() -> AABB
HOOKS       play_clip(name) | sample_at(t) | get_clip_length(name)
            get_load_error() | get_triangle_count() | get_surface_count()
            get_material_state() -> Dictionary | use_glb_pbr(bool)
```

Design points an integrator needs to know:

- **The rig builds on first use, not on the first frame.** `_ready()` is not a
  reliable construction point for every host — a `SceneTree` script that adds the rig
  inside `_initialize()` never sees `_ready()` fire (observed; it is why the first
  test run reported `load_error = 3`). Every public entry point funnels through
  `_ensure_built()`, so the scene is usable the instant it is instantiated, with no
  `await` and no frame loop.
- **`sample_at(t)` applies a pose immediately**, without a running main loop. This is
  what makes both the headless test and the render deterministic.
- **Strokes are one-shot and self-restoring**: `play_stroke()` runs the clip, emits
  `stroke_finished`, and returns to the current locomotion state by itself.

---

## 3. Locomotion proof: the clips really move the skeleton

A clip that loads is not proof. The test plays each clip, calls `sample_at()` at nine
times across its length, and takes the largest per-joint change in bone **pose
rotation** (a quaternion component delta) against t = 0. Threshold 0.01.

| Clip | Source | Max joint rotation delta |
|---|---|---|
| `walk` | `volpe-walking.glb` | **0.432208** |
| `run` | `volpe-running.glb` | **0.614344** |
| `drive` | authored in Godot | **0.478775** |
| `slice` | authored in Godot | **0.386936** |
| `lob` | authored in Godot | **0.549082** |
| `serve` | authored in Godot | **0.513735** |

All two orders of magnitude above the threshold. The same motion is independently
visible in the rendered pixels (section 6.3), so the claim rests on two unrelated
measurements, not one.

### 3.1 Root motion: measured, and it is small

`godot/src/character/tools/root_motion_probe.gd`, Hips bone pose position span over
each clip (bone units are centimetres — the `Armature` node carries a 0.01 scale):

| Clip | Hips position span (x, y, z) |
|---|---|
| `idle` | (0, 0, 0) |
| `walk` | (7.64, 7.49, 4.72) cm |
| `run` | (1.12, 6.67, 6.32) cm |
| authored strokes | (0, 0, 0) — no position track |

So the locomotion clips carry a **bob, not travel**: they do not translate the
athlete across the court, and the match simulation can own world position without
fighting the clip. No root-motion stripping was needed or done.

---

## 4. The padel strokes, authored in Godot

Four strokes are built procedurally at load time in `athlete_rig.gd` (`STROKE_SPECS`
+ `_author_strokes`): **drive** (0.62 s), **slice** (0.54 s), **lob** (0.70 s),
**serve** (0.86 s). Each is an `Animation` of `TYPE_ROTATION_3D` tracks on the GLB's
own bones (`Hips, Spine, RightShoulder, RightArm, RightForeArm, RightHand, LeftArm`),
keyed as `bone_rest_rotation * offset(t)` so that offset = identity is exactly the
rest pose and every stroke starts and ends there. Zero new paid assets, zero credits.

Interpolation is `INTERPOLATION_CUBIC`. Angle magnitudes are <= 72 degrees.

**These poses are functional placeholders, not an art direction.** They were chosen
to be large enough to read on camera and to measure in a test. Final stroke styling
is an owner decision (section 9).

---

## 5. Outfits: the recolour path, and the honest limit

### 5.1 The blocker that had to be solved first, and how

The ticket prescribed `tools/character/outfits-strong.json` as the stronger input.
Running the existing tool on it **failed twice** on this host:

```bash
flock -w 900 /tmp/padel-godot.lock /usr/bin/time -v timeout 600 \
  python3 tools/character/recolour_outfits.py --spec tools/character/outfits-strong.json \
  --out-dir tools/character/out-strong
# attempt 1: exit 1 — ModuleNotFoundError: No module named 'numpy'  (/usr/bin/python3 has no numpy)
# attempt 2 (with /root/scrappy/.venv/bin/python3): exit 137, killed by signal 9
#   Maximum resident set size (kbytes): 765836   against 283 MB available
#   kernel: "Out of memory: Killed process 1112303 (python3) ... anon-rss:764824kB"
```

Two facts worth recording for every later lane: **`/usr/bin/python3` on this host has
no numpy; `/root/scrappy/.venv/bin/python3` is the only interpreter with numpy+PIL.**
And the existing recolour tool needs ~765 MB, which this host frequently does not have.

Rather than wait on another tenant's memory, a **new** file was added (existing files
in `tools/character/` stay byte-identical): `tools/character/recolour_outfits_tiled.py`.
It is a driver, not a fork — it imports every colour operator unchanged from
`recolour_outfits.py`. That is sound because each operator is strictly per-texel
(no convolution, no global normalisation), so evaluating on a horizontal row band is
bit-identical to evaluating on the whole atlas. All difference statistics are
accumulated in streaming form.

**That claim is checked, not asserted.** Re-deriving the *existing* weak pair with the
tiled driver reproduces the original bytes exactly:

```bash
flock -w 900 /tmp/padel-godot.lock /usr/bin/time -v timeout 900 \
  /root/scrappy/.venv/bin/python3 tools/character/recolour_outfits_tiled.py \
  --spec tools/character/outfits.json --out-dir /tmp/tiled-check --band 128 \
  --verify-against tools/character/out            # exit 0
# ok outfit-a: reference 4b7c15d8…0b80 / tiled 4b7c15d8…0b80
# ok outfit-b: reference a7e266e8…0c9b / tiled a7e266e8…0c9b
# VERIFY_PASS 2/2 byte-identical
# Maximum resident set size (kbytes): 150188     (5.1x less than the original)
```

It also reproduces the original's statistics exactly: A−B mean abs 4.873/255,
per-channel [5.616, 2.392, 6.611], changed fraction 0.1460, mean euclidean 9.982,
RMS 20.566 — every figure matching `tools/character/out/diff-report.json`.

### 5.2 The strong pair, generated

```bash
flock -w 900 /tmp/padel-godot.lock /usr/bin/time -v timeout 900 \
  /root/scrappy/.venv/bin/python3 tools/character/recolour_outfits_tiled.py \
  --spec tools/character/outfits-strong.json --out-dir tools/character/out-strong --band 128
# exit 0, wall clock 38.18 s, Maximum resident set size (kbytes): 150604
```

| Statistic (atlas, 2048x2048) | Weak pair (existing) | **Strong pair (new)** | Ratio |
|---|---|---|---|
| A−B mean abs | 4.873/255 | **15.177/255** | 3.11x |
| A−B per channel | 5.616, 2.392, 6.611 | **18.623, 7.140, 19.767** | ~3.1x |
| changed texels (any ch > 2) | 0.1460 | **0.1483** | 1.02x |
| mean euclidean | 9.982 | **28.352** | 2.84x |
| RMS | 20.566 | **44.315** | 2.15x |
| movable fraction (fur guard) | 0.1422 | **0.1422** | unchanged |

The offline prediction in
[`character-recolour-delta-ceiling.md`](character-recolour-delta-ceiling.md) §3.2 was
**15.1938/255**. Measured **15.177/255** — signed residual **−0.0168/255**, i.e. the
prediction was right to 0.11 %. `protect_sat` stayed at 0.22 and the movable fraction
is identical to four decimal places, so the fur guard is untouched and exactly one
variable changed between the two pairs: the target colours.

---

## 6. The ticket's named diagnostic, executed

> *"Render one copy at x = 0 (one frame per outfit, removing the ±0.75 m off-axis
> perspective and view-vector confound), then raise the target-colour delta in the
> recolour input and re-render."*

Both halves ran in **one** Godot process. `godot/src/character/rig_render.gd` places a
single athlete at world origin, camera straight on, and captures one frame per outfit
with the same camera, light, pose (`idle` held at t = 0.15 s), facing and frame count.

### 6.1 The confound is gone, and that is measured, not claimed

| Check | Result |
|---|---|
| `FRAMING_SHIFT_PX` | **dx = 0.0000, dy = 0.0000** (one copy, x = 0) |
| Body-mask pixel count, all 8 outfit frames | **74,001 px, every frame** |
| Body masks bit-identical across all 8 frames | **yes** (`np.array_equal` vs `outfit_base` for each) |
| Body bbox, all 8 frames | **x = 432..846, y = 62..659** (415 x 598 px) |
| Null control: a frame vs itself / vs a re-read | **0.0000** mean abs, max abs 0.0000 |

Because the masks are bit-identical there is no disparity, no resampling floor, no
per-block alignment search and no view-vector difference. A straight per-pixel
comparison is valid. The earlier render could not do this and had to fall back to a
signed difference of means with an admitted ~1/255 inferred confound.

### 6.2 What the two strong outfits actually measure

Statistics over the 74,001-px body mask. Rig default PBR (`metallic = 0`) unless noted.

| Pair | signed ΔRGB (A−B) | mean abs /255 | mean eucl | frac px > 25 eucl |
|---|---|---|---|---|
| **glacier − vermilion** (strong) | −14.8469, +5.6983, +15.1895 | **11.9125** | 22.8394 | 0.1440 |
| **midnight_violet − ember** (weak) | +0.9341, +0.5433, +4.3017 | **2.4262** | 5.6736 | 0.0346 |
| glacier − vermilion at `metallic = 1` | −9.8859, +3.3661, +7.1616 | 6.8051 | 12.9866 | 0.1368 |
| glacier `metallic 0` − glacier `metallic 1` | +4.1264, +9.1113, +20.7158 | 11.3186 | 24.2538 | 0.2346 |

Comparable to the prior evidence's headline statistic (|mean(A) − mean(B)|, which is
what its "1.2/255" is):

| Pair | this render | prior render |
|---|---|---|
| weak pair (midnight_violet vs ember) | **1.9264**/255 | 1.2/255 |
| **strong pair (glacier vs vermilion)** | **11.9115**/255 | did not exist |

The weak pair reproduces the prior result to the right order (the residual is
consistent with the prior render using the GLB's `metallic = 1`, which this run
measures as a −43 % damper; 1.93 x 0.57 = 1.10 against 1.2 — a consistency check, and
an inference, not a measurement). **The strong pair is 6.2x the weak pair and ~10x the
number the ticket called "a tint, not an outfit".**

### 6.3 Where the difference lives — and the dilution that hides it

Per-window signed deltas, windows as fractions of the 598 px body span, same window
definitions as the earlier evidence so the rows are directly comparable:

| Window | glacier − vermilion, signed ΔRGB | mean abs | window coverage |
|---|---|---|---|
| head | −0.80, +0.37, +1.11 | 0.7597 | 0.0425 |
| upper_back | −0.60, +0.29, +10.26 | 3.7146 | 0.0927 |
| mid_torso | −2.43, +1.99, +6.68 | 3.6965 | 0.0619 |
| **waist_hip** | **−57.33, +20.72, +46.03** | **41.3615** | 0.4422 |
| **shorts** | **−30.05, +10.87, +24.27** | **21.7301** | 0.2295 |
| thigh | 0.00, 0.00, +0.01 | 0.0020 | 0.0001 |
| **feet** | **−64.38, +24.54, +55.74** | **48.2227** | 0.5745 |

The ceiling document predicted a garment window of **18–25/255**. Measured shorts
window: **21.73/255** — inside the predicted bracket. It under-predicted the best
windows: waist_hip 41.36 and feet 48.22.

The decisive statistic is coverage-conditional. Splitting the body mask by whether a
pixel changes at all (euclidean > 2):

| Pair | changed px | coverage of body | mean eucl **within** changed px | median | p95 |
|---|---|---|---|---|---|
| **glacier vs vermilion** | 10,917 | 0.1475 | **154.8079** | 169.4137 | 203.7278 |
| midnight_violet vs ember | 10,722 | 0.1449 | 39.1366 | 19.9499 | 131.4253 |
| glacier vs vermilion, `metallic = 1` | 10,574 | 0.1429 | 90.8648 | 99.1312 | 126.5899 |

**Where the outfit paints, the strong pair is 154.8/255 apart — not a tint, a
different colour.** The whole-model mean only looks modest because **85.25 % of the
visible athlete carries no outfit colour at all.** Changed-mask IoU between the strong
and weak pairs is 0.9816: the same texels move in both cases, exactly as the offline
ceiling analysis predicted (coverage is saturated; only the target separation changed).

`derived_glacier_vs_vermilion_amplified.png` shows this directly: the chevron,
wristbands, shorts and shoes light up; the fur, face, arms and legs are pure black.

### 6.4 The fur guard, proven in rendered pixels

The brief flags a known trap: *a recolour with no garment mask tints skin and fur too*.
It does not happen here, and this is now demonstrated in the render rather than only in
the atlas. The `thigh` window — bare fur — reads
**(254.9931, 254.6755, 254.03)** in all five outfits, agreeing to within **0.006/255**,
with a changed-pixel coverage of **0.0001** (1 px of 7,839). The head window moves
0.76/255. The saturation-based mask segments the garment adequately for this model.
**Claim made, and proven.**

### 6.5 Two honest limits of this render

1. **The lighting over-exposes.** At the rig's default `metallic = 0`, **76.40 % of
   body pixels are clipped to pure (255,255,255)** and 86.30 % clip in at least one
   channel. Clipped pixels cannot show a difference, so this render cannot, on its own,
   distinguish "the texture does not paint here" from "the render clips here".
   *It is separable, and it was separated:* the `metallic = 1` frame clips only
   **10.65 %** of body pixels on all channels, and there the changed-pixel coverage is
   still **0.1429** with **IoU 0.956** against the `metallic = 0` changed mask. Coverage
   is therefore genuinely limited by the authored texture, not by the exposure. The
   light rig itself (`light_energy 1.5` + ambient 0.75, inherited from the arena spike)
   should still be re-balanced before any look is judged — listed in section 10.
2. **The single transfer ratio T does not hold.** Using the same statistic throughout:

   | Pair | atlas mean abs | rendered | **T** |
   |---|---|---|---|
   | weak (metallic 0) | 4.873 | 1.9264 | **0.3953** |
   | **strong (metallic 0)** | 15.177 | 11.9115 | **0.7848** |
   | strong (metallic 1) | 15.177 | 6.8045 | **0.4483** |

   The ceiling document assumed a constant **T = 0.2463** and predicted 3.74/255 for
   the strong pair. Measured: **11.91/255 — 3.2x better than predicted.** T is not a
   constant: it is 1.99x larger for the strong pair than the weak one. Two reasons,
   both visible above — the prior T was derived from a render carrying the
   `metallic = 1` damping (−43 %) and the off-axis confound, and a mean-absolute
   statistic does not scale linearly when the weak pair's per-texel changes partly
   cancel in sign (its signed 1.93 against its absolute 2.43) while the strong pair's
   do not (11.9115 signed against 11.9125 absolute). **The prescription over-delivered;
   the pessimistic projection in the ceiling document should not be used for roster
   planning without redoing it against these numbers.**

### 6.6 Verdict on the ticket's one open item

> *"an in-engine render proving two visually distinct outfits from one model via the
> proposed path."*

**Met.** One rigged GLB, one material, one surface, one skeleton, two per-instance
`albedo_texture` surface overrides, one copy at x = 0, one frame per outfit, zero
alignment confound, null controls exactly 0.0000. Glacier renders as azure shorts,
pale-cyan wristbands and blue-and-white shoes; Vermilion as brick-red shorts, gold
wristbands, a gold chevron and red-orange shoes. They are 154.8/255 apart where the
outfit paints and read unambiguously as two different kits at 1280x720.

The honest qualifier, unchanged from the earlier analysis and now quantified: **only
~14.75 % of the visible athlete is recolourable**, so the whole-model mean stays at
11.9/255. Distinctness comes from the garment, and the garment is a chevron, a
waistband, shorts and shoes. Outfits that must differ *more* than this need garment UV
zones, not stronger colours — target separation is already near its practical ceiling
at 154.8/255 within the covered texels.

---

## 7. Headless test

`godot/tests/athlete_rig_test.gd` — `extends SceneTree`, machine-readable `ok` /
`FAIL <name>` lines, one terminal `PASS n/n` or `FAIL n/n`, exit 0/1. Same contract as
`res://tests/smoke_test.gd` and `res://src/sim/fault_digest_gd.gd`.

**The verified invocation, verbatim** (run from the repo root):

```bash
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/athlete_rig_test.gd
# exit 0 — "PASS 41/41"
```

The failure signal is proven, not assumed:

```bash
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/athlete_rig_test.gd -- --inject-failure
# exit 1 — "FAIL 41/42"
```

It goes red on every condition the slice was asked to gate: the rig failing to load
(`get_load_error() != OK`), a wrong joint count or joint name list, any clip that does
not move the skeleton over time, and an outfit override that does not change the
material parameters. TDD order was followed: the test was written first and run red
(`exit 1`, `Preload file "res://src/character/AthleteRig.tscn" does not exist`) before
`athlete_rig.gd` existed.

**No collateral damage.** The other lane's harness still passes with the rig, the GLBs
and the outfit atlases added to the project:

```bash
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
# exit 0 — "PASS 8/8"
```

---

## 8. Render commands, with exit codes

```bash
# attempt 1 (rejected — see below):
flock -w 900 /tmp/padel-godot.lock /usr/bin/time -v ./godot/src/character/render.sh 1280x720
#   exit 0, "RIG_RENDER_PASS", 25 PNGs, 7.47 s, max RSS 375,320 kB
#   REJECTED: framing bug (below). 2 of 25 frames came out blank.

# attempt 2 (the render this evidence is built on):
flock -w 900 /tmp/padel-godot.lock /usr/bin/time -v ./godot/src/character/render.sh 1280x720
#   exit 0, "RIG_RENDER_PASS", 25 PNGs, 13.36 s, max RSS 284,904 kB
#   "EXTENT world pos=(-0.522217, 0.044973, -0.277535) size=(1.041607, 1.678306, 0.266738)"
#   "CAM pos=(0.0, 0.884126, 2.968332) fov=40.000 FRAMING_SHIFT_PX dx=0.0000 dy=0.0000"
```

Attempts used: **2 of 2.** What failed in attempt 1 is worth recording because it is a
trap for any lane that frames a camera on this model:

**`MeshInstance3D.get_aabb()` is wrong for this skinned mesh.** The mesh vertices are
already in metres (mesh-space AABB 1.276 x 1.800 x 0.541 m), while the bone hierarchy
is in centimetres under an `Armature` node scaled 0.01. Multiplying the mesh AABB by
the mesh's *global* transform therefore double-counts that 0.01 and reports the athlete
as **0.018 m tall**. The camera was placed 0.371 m from a full-size figure; the result
was a giant close-up, and two frames in which a skinned pose pushed geometry outside the
cached AABB and the whole instance was frustum-culled to an empty frame.

Both are fixed and both fixes are in the shipped rig: `AthleteRig.get_world_extent()`
derives the extent from bone poses (giving the true **1.041 x 1.678 x 0.267 m**), and
`extra_cull_margin = 4.0` makes captures unconditional. A third defect found the same
way — the capture returning the *previous* state — is fixed by two `process_frame`
awaits before the grab.

**The athlete is correctly scaled at ~1.68 m tall.** No scale correction is needed by
the match-scene lane.

---

## 9. File inventory

### 9.1 Code, test and tooling

| Path | Bytes | sha256 |
|---|---|---|
| `godot/src/character/athlete_rig.gd` | 23533 | `2eec2060969de6b23a6c7a06370aab2be4f21a956079227a36ddea5b946f2c66` |
| `godot/src/character/AthleteRig.tscn` | 200 | `030ac8bea808cdb9a81bf43b821f764f32cbf5412b4f703315d9d7d03187f959` |
| `godot/src/character/rig_render.gd` | 8643 | `1390400044163768ebbf7bdd6e87db3f2bdae4a98d81feb045e66dc26a061c9d` |
| `godot/src/character/RigRender.tscn` | 196 | `10288d7010066550e37d111c570e7446e1f5d0c28c9c80e0730544ddc896503e` |
| `godot/src/character/render.sh` | 1401 | `306dbd28660dcdfd67be9d89c04c9248b2488fe70eca2b51587df41ffe4ed003` |
| `godot/src/character/measure_outfit_pixels.py` | 11240 | `5cce58c0c78b60392c5d211a608f326030b8a290a462d6e7852b4d3e5cbd974a` |
| `godot/src/character/measure_coverage.py` | 3004 | `e9aad47f3987f76011cce3566c38f06cba284a6a53b41c3bffa8bdaaa0c46d3e` |
| `godot/src/character/tools/rig_probe.gd` | 3353 | `0afa6b6021546a15937dad060f7f71a8aa0a29e6472d43763bd4f97b6de59b5f` |
| `godot/src/character/tools/root_motion_probe.gd` | 1530 | `f61fef903d69be6ee100f1050c2cc086c6db91849faf4d8273685128a7e5ecaf` |
| `godot/src/character/tools/extent_probe.gd` | 2064 | `29be6e000c3484e95860a57c31d3bf442eff030f1091d0faf4cfee76640c7502` |
| `godot/tests/athlete_rig_test.gd` | 7879 | `f64cc76ed713c32b0d9f5c308e65664840cc06e43926f0a6c583b2b94473558f` |
| `tools/character/recolour_outfits_tiled.py` | 9781 | `43d586f776ddb60a2ed27099dcc6a83dbaf22c4b35140c89efca6f5fe6ba7953` |

### 9.2 Generated outfit atlases (new, `tools/character/out-strong/`)

| Path | Bytes | sha256 |
|---|---|---|
| `tools/character/out-strong/outfit-a.png` | 5578975 | `80992abd7ff0150397f1228de1ccd5b9d3daf530fc4e75e3c7604a7698a0da43` |
| `tools/character/out-strong/outfit-b.png` | 5584870 | `b8e6ca4fb0d6d1ceed5c33423caca0d90ba1ab9f9bffeb4217e8ac48bfd957e9` |
| `tools/character/out-strong/mask-chromatic.png` | 225726 | `9fd54c05c45b450c9357d3872a9a3dd7cc3ccb2149fbd065898f27f377584d3b` |
| `tools/character/out-strong/diff-report.json` | 2210 | `e73a6e6f5409b9a8f173abb2da78d71afb757bf969bd58700e07191dfb2658a8` |
| `tools/character/out-strong/PROVENANCE.md` | 3328 | `39330c09ee2f5ca7540cebab54d8ae1d7dd599743e2220012e84a8af5ad39a9c` |

### 9.3 In-project assets (`godot/assets/athletes/`) — all byte-identical copies

| Path | Bytes | sha256 | Copy of |
|---|---|---|---|
| `godot/assets/athletes/volpe-rigged.glb` | 8898424 | `ab6b3086e6a455d9cdaaf8b198dfb762924b31cd77ee01bd8fe0135e9d687ec5` | `meshy/rigged/volpe/volpe-rigged.glb` |
| `godot/assets/athletes/volpe-walking.glb` | 8911212 | `8ee2447b6fa6d7f7c71ad781aefecbda914a6d4a6497b53f6d7e7cffb4f3e8f1` | `meshy/rigged/volpe/volpe-walking.glb` |
| `godot/assets/athletes/volpe-running.glb` | 8906600 | `47192d80c8bfb860c2da77c9ca9431ed753da50942fcc61e79887cd6cecc9e11` | `meshy/rigged/volpe/volpe-running.glb` |
| `godot/assets/athletes/outfits/strong-outfit-a.png` | 5578975 | `80992abd7ff0150397f1228de1ccd5b9d3daf530fc4e75e3c7604a7698a0da43` | `tools/character/out-strong/outfit-a.png` |
| `godot/assets/athletes/outfits/strong-outfit-b.png` | 5584870 | `b8e6ca4fb0d6d1ceed5c33423caca0d90ba1ab9f9bffeb4217e8ac48bfd957e9` | `tools/character/out-strong/outfit-b.png` |
| `godot/assets/athletes/outfits/weak-outfit-a.png` | 5586280 | `4b7c15d842f245d419ecf9a5ccd151c293b770bb7509d1308527df46a0430b80` | `tools/character/out/outfit-a.png` |
| `godot/assets/athletes/outfits/weak-outfit-b.png` | 5661745 | `a7e266e8160a9d5d2b8b113d788c54e87f1f2ad34128dedb18bd1251f0359c9b` | `tools/character/out/outfit-b.png` |

### 9.4 Render evidence (`godot/src/character/out/`)

All PNGs are 1280x720 RGBA unless the dimensions column says otherwise, all from ONE Godot process. "Body px" is the count of pixels differing from `background_only` by > 2 in any channel — the not-blank proof.

| File | Bytes | sha256 | Dimensions | Body px | Distinct RGB |
|---|---|---|---|---|---|
| `outfit_base_x0_1280x720.png` | 57484 | `3dc2370650061de0d4fe9972adabed4199e4081285227561b5108138400e5c3d` | 1280x720 | 74001 | 5032 |
| `outfit_ember_x0_1280x720.png` | 56684 | `3ef9e3d503cb591a2e53a1e81eade76c5dfd5d95648798e9a67df60e2d98eeca` | 1280x720 | 74001 | 4614 |
| `outfit_glacier_x0_1280x720.png` | 57243 | `46019f850f1cff3cbcde96fa445cd4390c1767ab50ce4551743cc7b6aea3473a` | 1280x720 | 74001 | 4932 |
| `outfit_midnight_violet_x0_1280x720.png` | 56546 | `64778c33dede525eee85d6c8c23bbe28ff49c146f2150ff44354d3361ab28632` | 1280x720 | 74001 | 4521 |
| `outfit_vermilion_x0_1280x720.png` | 57872 | `b4caa21846b27520bc6cbe42c621ba894f01c8ba2bb173a70fd4ceb04a62a163` | 1280x720 | 74001 | 5370 |
| `pbrglb_outfit_base_x0_1280x720.png` | 116687 | `9db67b5c79354c862637e04abbb8c14388708c7255c522300996ca7e457c8500` | 1280x720 | 74001 | 6265 |
| `pbrglb_outfit_glacier_x0_1280x720.png` | 116452 | `840488aab0e14a67aeb7a8f25cb841919087d9720fc84de379d5cfc8f5e53c3f` | 1280x720 | 74001 | 6518 |
| `pbrglb_outfit_vermilion_x0_1280x720.png` | 116153 | `5b002c0f37c434abd1eff0964c18cc2811298a9de1155fa93a772a22abbedbf5` | 1280x720 | 74001 | 6463 |
| `background_only_1280x720.png` | 5325 | `6237f791f001afdcfa25f43f16925a811bf8b0a3e14393c711d67592c337dfb6` | 1280x720 | 0 | 1 |
| `anim_run_f0_1280x720.png` | 57002 | `975efb013c8d62c788dce46c39f1616e2b10ea95dbe66d79313d75ef8bcd8d69` | 1280x720 | 60413 | 4925 |
| `anim_run_f1_1280x720.png` | 53335 | `673d7274c45adfa52c6b7bbbbd647c77fe638a15d0b959f77444568ae64402e7` | 1280x720 | 58803 | 4861 |
| `anim_run_f2_1280x720.png` | 58137 | `14b39baa947d69c08b560bb17179e5a7eb5cf1442ff7278251fa8ec41924e874` | 1280x720 | 64304 | 5313 |
| `anim_run_f3_1280x720.png` | 63494 | `21168c165270c7e724bcb77287824ebbb798447e30fd56ada206f649c1667328` | 1280x720 | 64089 | 5697 |
| `anim_run_f4_1280x720.png` | 55526 | `0fe7bd5e77d375623b864bc7c8bf1926c47081497a37cee5b0ae4d39c7d29ad3` | 1280x720 | 57664 | 4792 |
| `anim_run_f5_1280x720.png` | 53785 | `e0bd507fe1c864b7e09c9e610457d51bbbfde086ad3715398cef18d1c13d05d7` | 1280x720 | 58882 | 5160 |
| `anim_run_f6_1280x720.png` | 58138 | `91ec8c6c547557a488cf0a8b124fb22210cee3e70f418127df0239f1e62d50ef` | 1280x720 | 62327 | 5309 |
| `anim_run_f7_1280x720.png` | 59918 | `a88b7a7e2d07a027494275bb4ca239d21f9336da93bfbf3b171ef3142119dc01` | 1280x720 | 63018 | 5528 |
| `anim_drive_f0_1280x720.png` | 61451 | `281099558c1133a4a3870a479df79a5d2764f73799d73078e88be26282e8b5cc` | 1280x720 | 50043 | 5788 |
| `anim_drive_f1_1280x720.png` | 62153 | `95ba5df3229029b3ffdfd807cb2bb374c624763dc6feb4ecff55ffe34a26e0ce` | 1280x720 | 51238 | 5772 |
| `anim_drive_f2_1280x720.png` | 64489 | `761c42778e897bc481d5668ed13459807b3c2755937d13138f2b8ec697847288` | 1280x720 | 70346 | 5766 |
| `anim_drive_f3_1280x720.png` | 61719 | `93f389e3cac41e218ba08fcc400df988559e8348c557f0fa3cc30e5466d0e3b9` | 1280x720 | 72428 | 6044 |
| `anim_drive_f4_1280x720.png` | 61581 | `5e0dc9e9c2d4da621443d8ffc3ec5d8be37fed2fdb729a862d10e902ecca4b98` | 1280x720 | 72414 | 6075 |
| `anim_drive_f5_1280x720.png` | 63826 | `2a8d6c338a59e5712ca5cdc721b3da857fed006ca79d3483cc8915fa4a5b0879` | 1280x720 | 73036 | 5999 |
| `anim_drive_f6_1280x720.png` | 63459 | `9ecdd39096c5d3f1131b127dda9dc6fc15bff480c709c2c3206a28057dc4d457` | 1280x720 | 68732 | 5790 |
| `anim_drive_f7_1280x720.png` | 63277 | `b227d0276a56d90bb678f062a9912ddeed9d251a9ced3783346dda423a7c570a` | 1280x720 | 68322 | 5750 |
| `arena_composition_1280x720.png` | 34088 | `8fabb99a44eb6d5c4d2ab574a0cba23921cb0d8d47f0622f6b4711480875c27b` | 1280x720 | 539562 | 1053 |
| `derived_anim_drive_strip.png` | 387873 | `d9264c58998fe0b729337883c131460e2bbbcb73d2b3d2ba6d8e67924f55ed70` | 3696x629 | n/a (derived) | 25838 |
| `derived_anim_run_strip.png` | 345714 | `c8cc56fdff5c243566f228f15b9ad3a39d7cee597fd236f5e9d8a2af14d1f82e` | 2208x623 | n/a (derived) | 23761 |
| `derived_glacier_vs_vermilion_amplified.png` | 11048 | `7c220156c30a2ca4e655175053a55c774061d94a1cb786cb29019f37fc5990ed` | 415x598 | n/a (derived) | 767 |
| `derived_outfit_grid.png` | 144126 | `8813f187fb11499564ee46d332ebbf9660cf9ef953c95f58293cd428fd786eac` | 2075x598 | n/a (derived) | 19525 |
| `render_1280x720.log` | 7482 | `293f48b535ae222144a0a2eead41e14fd3bae41af1d40973679e1529bdb79547` | - | - | - |
| `render_shell_1280x720.log` | 8897 | `c35c21fad991b1497381e6a02c586bddbba57ee13d4cad6de42b0a5e59286d21` | - | - | - |
| `measure-outfit-pixels.json` | 23064 | `7f5661ec4e6f88d9986ff3aa7cc481d22772cf842fe219761a0e2112a287e889` | - | - | - |
| `measure-coverage.json` | 3006 | `933a00f26a8181899f55c05783ec1be51a10f64eba4d01eb0608dc414f25fcd5` | - | - | - |
| `derived_outfit_grid.json` | 370 | `e2165a90558de968893a87d4e6f149aa83e1a49dac059ccc57a1f0a7dab7b2aa` | - | - | - |

Every render frame is non-blank: `background_only` holds exactly 1 distinct colour
(56, 61, 71) and every other frame holds 993–6,518 distinct RGB values with a
non-empty body mask. The `anim_*` frames each have a different silhouette (section
6.3 / 10), which is the point of them.

---

## 10. Motion across frames, in pixels

Independent of the joint-transform proof in section 3: mean absolute difference of each
strip frame against frame 0, over the union body mask, plus the silhouette bbox.

| Frame | run: mean abs vs f0 | run: silhouette px | drive: mean abs vs f0 | drive: silhouette px |
|---|---|---|---|---|
| f0 | 0.0000 | 60,413 | 0.0000 | 50,043 |
| f1 | 38.6882 | 58,803 | 6.2072 | 51,238 |
| f2 | 61.6509 | 64,304 | 66.6551 | 70,346 |
| f3 | 50.8698 | 64,089 | 77.0026 | 72,428 |
| f4 | 47.6243 | 57,664 | 77.0942 | 72,414 |
| f5 | 47.6396 | 58,882 | 74.8609 | 73,036 |
| f6 | 49.4800 | 62,327 | 63.5918 | 68,732 |
| f7 | 37.9998 | 63,018 | 62.5378 | 68,322 |

The drive bbox widens from 245 px to 429 px as the arm extends, and the run silhouette
translates and changes area every frame. Contact sheets:
`derived_anim_run_strip.png` (2208x623) and `derived_anim_drive_strip.png` (3696x629).

---

## 11. Owner decisions deliberately left open

Visual direction is the owner's. Each item below was resolved to the **technically
reversible** default and is flagged rather than self-certified.

1. **PBR: `metallic = 0.0, roughness = 0.85` (rig default) vs `metallic = 1.0,
   roughness = 1.0` (the GLB's own values).** The GLB's values are the glTF defaults for
   an unauthored `pbrMetallicRoughness`, and metallic = 1 is not a correct description
   of cloth and fur — but it is not obviously worse to look at, and it renders with more
   visible form. Measured cost of choosing it: **−42.9 %** of the strong pair's
   whole-body outfit contrast (11.9125 → 6.8051) and −41.3 % within the covered texels
   (154.81 → 90.86). Fully reversible at runtime: `rig.use_glb_pbr(true)`. Both are
   rendered side by side in `godot/src/character/out/`. **Owner picks.**
2. **Outfit colours.** `glacier` / `vermilion` are the ticket's diagnostic targets,
   chosen to make the recolour measurable. They are **not** a proposed palette, and
   they are not tied to any of the 26 `ATHLETE_OUTFITS` entries in `js/data.js`.
3. **Padel stroke poses.** Four functional placeholder strokes, keyed to be readable and
   measurable. Timing, weight and follow-through are art direction; the data lives in
   one dictionary (`STROKE_SPECS`) and is trivially replaceable.
4. **Facing convention.** `set_facing_degrees(180)` shows the athlete's **back** to the
   camera; 0 shows the front. All frames in this evidence are at 180 (matching the
   arena spike's assumption), so they show the athlete from behind. Which way an athlete
   faces on each side of the net is the match-scene lane's call.
5. **Light rig.** `light_energy 1.5` + ambient 0.75, inherited from the arena spike, and
   it over-exposes this ivory model (76.40 % of body pixels clip to pure white at
   metallic = 0). Fine for the colour diagnostic, wrong for judging a look.

---

## 12. NOT DONE — explicit

- **The roster is one model.** Six athletes and four AI opponents are *not* built. This
  slice proves one rigged model can be recoloured and animated; it does not produce ten
  characters. The `volpe` trial rig is a pipeline test, not a roster athlete.
- **26 outfits are not authored.** Two strong + two weak recolours exist. The roster
  needs 26 (`ATHLETE_OUTFITS`, 6 base + 20 unlockable). The ceiling analysis estimates
  8–12 *visually distinct* recolours per baked texture; this render neither confirms
  nor refutes that estimate, which rests on a distinctness threshold no human has tested.
- **No blend between clips.** `play_locomotion()` hard-switches. There is no
  `AnimationTree`, no idle↔walk↔run blend space, no stroke upper-body mask. A stroke
  overrides the whole body for its duration.
- **No frame-rate or performance claim.** Software llvmpipe only. 31,325 triangles per
  athlete x 4 on court is unmeasured on real hardware. No decimated/LOD asset exists.
- **The mesh defects recorded in `meshy/rigged/RESULT.md` were not re-checked** in
  engine (fused fingers/toes, tail/shorts seam, leg texture smearing). The renders here
  are consistent with fused digits but I did not measure it.
- **`get_world_extent()` returns the REST extent under a headless tree**, because the
  skeleton's global-pose cache is not refreshed without frames. Correct for camera
  framing; it is *not* a per-frame silhouette bound.
- **The weak pair was not rendered at `metallic = 1`,** so the comparison against the
  prior render's 1.2/255 crosses one uncontrolled variable and is reported as a
  consistency check, not a reproduction.
- **Garment UV zones were not built.** The ceiling analysis names them as the one
  authoring investment that changes the roster economics (mask 0.1425 → ~0.40 would
  roughly triple distinct-outfit capacity). Out of scope here; still the highest-value
  next step for outfits.
- **No integration with the match scene.** The rig is callable and documented but no
  other lane consumes it yet.
- **Nothing was committed.** No commit, no push, no deploy, no publish.

---

## 13. Reproduce, in order

```bash
cd /root/projects/steam-circuit-padel-pro
G=/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64
PY=/root/scrappy/.venv/bin/python3     # the ONLY interpreter here with numpy+PIL

# 1. structure probes (read-only)
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $G --headless --path godot/ --script res://src/character/tools/rig_probe.gd
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $G --headless --path godot/ --script res://src/character/tools/root_motion_probe.gd
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $G --headless --path godot/ --script res://src/character/tools/extent_probe.gd

# 2. the outfit atlases (byte-identity gate first, then the strong pair)
flock -w 900 /tmp/padel-godot.lock timeout 900 $PY tools/character/recolour_outfits_tiled.py \
  --spec tools/character/outfits.json --out-dir /tmp/tiled-check --band 128 \
  --verify-against tools/character/out                      # exit 0, VERIFY_PASS 2/2
flock -w 900 /tmp/padel-godot.lock timeout 900 $PY tools/character/recolour_outfits_tiled.py \
  --spec tools/character/outfits-strong.json --out-dir tools/character/out-strong --band 128

# 3. the gate
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  $G --headless --path godot/ --script res://tests/athlete_rig_test.gd    # exit 0, PASS 41/41

# 4. the render (Xvfb + opengl3, NOT --headless)
flock -w 900 /tmp/padel-godot.lock ./godot/src/character/render.sh 1280x720  # RIG_RENDER_PASS

# 5. the measurement
flock -w 900 /tmp/padel-godot.lock timeout 600 $PY godot/src/character/measure_outfit_pixels.py
flock -w 900 /tmp/padel-godot.lock timeout 600 $PY godot/src/character/measure_coverage.py
```

Peak RSS, measured: recolour 150,604 kB; render 284,904 kB; measurement 175,916 kB.
All well inside the single heavy-process slot this host allows.
