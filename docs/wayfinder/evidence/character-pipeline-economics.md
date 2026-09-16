# Evidence: character pipeline economics

- Date: 2026-09-16 (measured 2026-09-16T05:51Z)
- Ticket: [`../tickets/character-pipeline-economics.md`](../tickets/character-pipeline-economics.md)
- Method: read-only inspection of artifacts already on disk. No Meshy call, no paid spend, no
  GPU/engine run this tick, no network. `sha256sum`, `stat`, `python3` stdlib (GLB container
  parse, PNG IHDR header parse, regex over `js/data.js`). The 2048x2048 PNGs were **not** decoded
  as pixels here — the diff numbers come from the recorded `diff-report.json`, not from a re-run.
- Host constraint that shaped this tick: 3,910 MB RAM, 0 swap, ~450 MB free; a previous attempt
  at this work was killed by the kernel at ~880 MB RSS. The recolour script was therefore **read
  and not run**, and the one open item needs the engine lane.

## 1. Measured numbers

### 1.1 The trial asset (one athlete's geometry)

Command: `python3 tools/character/glb_tri_count.py meshy/rigged/volpe/{volpe-rigged,volpe-walking,volpe-running}.glb > tools/character/out/tri-count.json`

| File | Bytes | Triangles | Vertices | Primitives | Materials | Images | Joints | Clips (dur) |
|---|---|---|---|---|---|---|---|---|
| `volpe-rigged.glb` | 8,898,424 | 31,325 | 44,829 | 1 | 1 (`Material_1`) | 1 (2048 PNG) | 24 | `Armature\|clip0\|baselayer` 0.300 s |
| `volpe-walking.glb` | 8,911,212 | 31,325 | 44,829 | 1 | 1 (`Material_1`) | 1 (2048 PNG) | 24 | `Armature\|walking_man\|baselayer` 1.067 s |
| `volpe-running.glb` | 8,906,600 | 31,325 | 44,829 | 1 | 1 (`Material_1`) | 1 (2048 PNG) | 24 | `Armature\|running\|baselayer` 0.667 s |
| **Sum across the three GLBs** | 26,716,236 | **93,975** | – | – | – | – | – | – |

- **31,325 triangles per GLB, measured** — matches the ticket's expected trial-asset number and
  `meshy/rigged/RESULT.md`. The three files are the *same* mesh three times: each carries its own
  copy of the mesh, texture and skeleton, so the 93,975 total is 3x redundancy, not 3x geometry.
- `31,325` is the remesh target (30,000) overshooting as triangles; `meshy/README.md` recommends
  decimating to 8–15k for the game. No decimated artifact exists on disk, so **no post-decimation
  triangle count is measured**.
- Material facts, re-measured rather than repeated: 1 material, `baseColorFactor: null`, no
  `COLOR_0` vertex-colour attribute (confirmed: `has_vertex_colors: False` in `tri-count.json`).
  That is what makes the recolour question hard and confirms the ticket's premise.
- `sha256(volpe-rigged.glb) = ab6b3086e6a455d9cdaaf8b198dfb762924b31cd77ee01bd8fe0135e9d687ec5`
  at two paths — `meshy/rigged/volpe/volpe-rigged.glb` and
  `godot/prototypes/arena_spike/assets/volpe-rigged.glb` are byte-identical (same hash, compared
  with `sha256sum`). Note: the copy lives under `godot/prototypes/arena_spike/assets/`, not
  `assets/` at repo root — there is no `assets/volpe-rigged.glb`.

### 1.2 Per-athlete asset cost (bytes on disk)

Command: `stat -c '%y %n'` on the pipeline files, PNG IHDR headers for dimensions, arithmetic in
`python3` (1 MiB = 1,048,576 B).

| Item | Bytes | MiB | Source |
|---|---|---|---|
| Rigged GLB (mesh + skin + texture embedded) | 8,898,424 | 8.49 | `volpe-rigged.glb` |
| + walking GLB | 8,911,212 | 8.50 | `volpe-walking.glb` |
| + running GLB | 8,906,600 | 8.49 | `volpe-running.glb` |
| **One athlete, full locomotion set** | **26,716,236** | **25.48** | measured |
| Base colour texture extracted | 6,352,874 | 6.06 | `volpe-texture.png`, 2048x2048, 8-bit RGB (`6cd22f86…`) |
| Authorable outfit texture | 5,586,280 / 5,661,745 | 5.33 / 5.40 | `outfit-a.png` / `outfit-b.png`, 2048x2048 8-bit RGB, PNG IHDR |
| Mean outfit texture | 5,624,012.5 | 5.36 | mean of the two |

Projected roster totals (**projection = measured per-unit size × verified count**, not a
measurement of assets that exist):

| Projection | Bytes | MiB |
|---|---|---|
| 6 athletes x 3 GLBs | 160,297,416 | 152.87 |
| 20 unlockable outfit textures at the measured mean | 112,480,250 | 107.27 |
| 26 textures (6 base at source size + 20 unlockable) | 146,224,325 | 139.45 |
| **6 athletes, full locomotion GLBs + 20 unlockable textures** | **272,777,666** | **260.14** |
| Cheaper variant: 1 rigged GLB/athlete + 20 outfit textures (no per-clip GLB duplication) | 165,870,794 | 158.19 |

The cheaper variant assumes clip-only GLBs (mesh stripped), which **does not exist on disk** —
Meshy emitted three self-contained files. Stripping is a Godot import/export task, unmeasured.

### 1.3 Textures

| Artifact | Dimensions | Mode | Bytes | sha256 |
|---|---|---|---|---|
| `meshy/rigged/volpe/volpe-texture.png` | 2048x2048 | 8-bit RGB | 6,352,874 | `6cd22f86…aaf0b38` |
| `tools/character/out/outfit-a.png` | 2048x2048 | 8-bit RGB | 5,586,280 | `4b7c15d842f245d4…` |
| `tools/character/out/outfit-b.png` | 2048x2048 | 8-bit RGB | 5,661,745 | `a7e266e8160a9d5d…` |
| `tools/character/out/mask-chromatic.png` | 2048x2048 | 8-bit greyscale | 225,726 | – |

Dimensions/mode read from PNG IHDR headers (first 33 bytes), not by decoding.

### 1.4 Credits and wall clock already spent (measured, Meshy lane)

| Step | Endpoint | Task id | Credits | API-side duration |
|---|---|---|---|---|
| Image to 3D (4 views) | `POST /openapi/v1/multi-image-to-3d` | `01a0a77f-097d-7091-80b0-e904b7d93ecb` | 30 | 628.1 s |
| Remesh to 30k | `POST /openapi/v1/remesh` | `01a0a78d-cf8e-763e-9bc0-4d1513e0d0b5` | 5 | 201.3 s |
| Rigging, height 1.8 m | `POST /openapi/v1/rigging` | `01a0a794-ddfc-7644-b183-c919f5c3ee92` | 5 | 44.2 s |
| **Per athlete** | | | **40** | **873.6 s ≈ 14.6 min of API time** |

- API duration computed from `started_at`/`finished_at` in `gen_final.json`, `remesh_final.json`,
  `rig_final.json` (epoch ms). Credits from `consumed_credits` in those files; `RESULT.md` records
  the account balance dropping 3,060 → 3,020, which corroborates the 40.
- Wall clock for the run: first artifact `gen_create.json` mtime 01:55:23 → `volpe-rigged.glb`
  mtime 02:20:14 = **24 min 51 s** (`stat -c '%y %n'`). That window has no operator-idle evidence
  either way; treat 24:51 as the observed end-to-end of the successful trial, not as a schedule.
  It also **excludes** the earlier aborted rigging attempt (`height_meters` 1.1) noted in
  `RESULT.md`, so the true first-time cost is higher by an unmeasured amount.
- Roster projection: 6 athletes x 40 = **240 credits**, i.e. balance 3,060 → 2,820, at *today's*
  prices. **Not measured:** any future price change, any re-run cost from a failed generation, the
  cost of a second attempt after a rejected mesh, and the cost of Meshy's anima/UV-unwrap features
  (never called). No credits or minutes are invented for those.
- **20 unlockable outfit textures consumed 0 credits and 0 API calls** — authored offline from the
  texture Meshy already produced (`tools/character/out/PROVENANCE.md`).

## 2. The recolour route: real status

**Proven offline, for two textures from one rig. Not proven in engine.**

| Measurement | `outfit-a` | `outfit-b` | a vs b |
|---|---|---|---|
| mean abs diff (0–255) vs source | 4.002 | 2.193 | **4.873** |
| mean euclidean (0–255) | 7.909 | 4.591 | 9.982 |
| RMS (0–255) | 17.113 | 8.026 | 20.566 |
| changed texels, any channel > 2 | 0.1441 | 0.1448 | 0.1460 |
| changed texels, euclidean > 10 | 0.1311 | 0.1355 | 0.1352 |
| mask movable fraction | – | – | 0.142226 |

Source: `tools/character/out/diff-report.json` and `PROVENANCE.md` (generated 2026-09-16T04:35:21Z
by `tools/character/recolour_outfits.py` v1.0.1, source texture sha256 `6cd22f86…`). Outputs are
the same 2048x2048 RGB layout as the source, so a swap needs no UV change and no re-import pass.

What that does and does not establish:

- **Does:** the single baked `baseColorTexture` is a sufficient source to author two measurably
  different outfit textures, offline and deterministically, at zero credit cost, with a real
  separation between the two outfits (4.873 mean abs diff) larger than either one's distance from
  the source.
- **Mask limits (measured caveat, `PROVENANCE.md` "Region-mask caveat"):** the rig has **no garment
  zones** — no UV regions, no separate materials, no vertex colours. The mask is therefore inferred
  from *colour* (`mask-chromatic.png`, movable fraction 0.1422 of texels) and, by construction, it
  **cannot separate an ivory tee from ivory fur** — both are the same colour class in the atlas.
  A shipping pipeline wants a real unwrap (Meshy UV Unwrap or manual polygon selection) before the
  first outfit is authored. Nobody has done that step.
- **Missing:** no in-engine evidence. The recolour's own provenance references renders at
  `godot/prototypes/character_material/` — **that directory does not exist on disk** (`ls` fails).
  The only existing Godot character artifacts are `godot/prototypes/arena_spike/` (the same GLB
  appended into an arena scene, screenshots `arena_*.png`) and `godot/prototypes/render_probe/`
  (`probe_vk.png`, a Vulkan probe). Neither renders two outfits from one model, and neither was
  produced by the recolour path.

## 3. Retarget and polycount budget — what the evidence supports

Supported by disk evidence:

- The skeleton is a standard 24-joint humanoid (Hips, Left/Right UpLeg, Leg, Foot, ToeBase, Spine,
  Spine01, Spine02, Shoulder, Arm, ForeArm, Hand, neck, Head, head_end, headfront — `RESULT.md`;
  joint count 24 re-measured in `tri-count.json`). That naming is the same family Godot's
  `SkeletonProfileHumanoid` expects, which is why `godot/prototypes/arena_spike/` can append the GLB
  at all.
- **Rigging already returns locomotion**: `basic_animations` in the rig result carries walking
  (1.067 s) and running (0.667 s) — re-measured clip names and durations above. So the plan does
  not need the animations endpoint for locomotion.
- **Polycount:** 31,325 triangles per GLB, one primitive, one material — well inside a modern
  character budget on its own, but it is 2–4x the 8–15k `meshy/README.md` recommends after
  retopology, and no decimated build exists to measure.

**Open, unsupported this tick (asserted by nobody):**

- Whether Godot's retarget actually maps Meshy's humanoid onto hand-authored padel strokes; no
  stroke animation and no Godot `AnimationTree`/import-retarget artifact exists on disk.
- Whether the mesh survives a Godot import clean — `RESULT.md` records known defects (fused
  fingers/toes, tail meeting the shorts, texture smearing on the legs) and explicitly says nobody
  has checked the mesh in a 3D editor or in engine.
- A shipping polycount number (post-decimation, with LODs) — not measurable from what exists.

## 4. Runtime cost of one recolour pass

**Not measured this tick.** The command that produces it, and why it was not run:

```bash
cd /root/projects/steam-circuit-padel-pro
/usr/bin/time -v python3 tools/character/recolour_outfits.py \
    --spec tools/character/outfits.json --out-dir tools/character/out
```

- It needs numpy + Pillow to hold the 2048x2048 source and working float buffers; the script was
  read, not executed, because this host has ~450 MB free of 3,910 MB with 0 swap and a previous
  attempt at exactly this work was OOM-killed at ~880 MB RSS. Run it when the machine is idle and
  no other heavy lane holds the slot (`/usr/bin/time -v` prints `Maximum resident set size` and
  `Elapsed (wall clock)`).
- Baseline for scale, **measured**: one 2048x2048 RGB image is 12 MiB as 8-bit bytes, 48 MiB as
  float32 x 3 channels, 96 MiB as float64 (`python3` arithmetic). Those are buffer sizes, not
  process RSS — do not present them as the runtime cost.
- Do not confuse this with the offline authoring cost already established: zero credits, zero API
  calls.

## 5. The one remaining gate item

**An in-engine Godot render showing two distinct outfits from the one model, driven by the
`albedo_texture` swap of `outfit-a.png` and `outfit-b.png` on `volpe-rigged.glb`.**

- It does not exist: `godot/prototypes/character_material/` is absent; no PNG on disk is a
  two-outfit render.
- It is queued for the next tick because it needs the engine (and the single heavy process slot is
  held by another lane this tick), and because the recolour script must stay unrun here under the
  memory rule.
- Command that will produce it (same shape as the working arena spike, `godot/prototypes/arena_spike/render.sh`):

```bash
cd /root/projects/steam-circuit-padel-pro
# scene: append meshy/rigged/volpe/volpe-rigged.glb, duplicate the MeshInstance3D,
# set StandardMaterial3D.albedo_texture = res://tools/character/out/outfit-a.png on copy A
# and outfit-b.png on copy B, camera on both, then:
godot --headless --path godot/prototypes/character_material --quit-after 120 2>&1 | tee godot/prototypes/character_material/render.log
```

Evidence to capture: the PNG render plus a log line naming both texture paths and the material
each was applied to, stored under `godot/prototypes/character_material/`.

## 6. Reproduction commands (all read-only or already-recorded)

```bash
cd /root/projects/steam-circuit-padel-pro
python3 tools/character/glb_tri_count.py meshy/rigged/volpe/volpe-{rigged,walking,running}.glb
sha256sum meshy/rigged/volpe/volpe-rigged.glb godot/prototypes/arena_spike/assets/volpe-rigged.glb
stat -c '%y %n' meshy/rigged/volpe/{gen_create,gen_final,remesh_final,rig_final}.json meshy/rigged/volpe/volpe-rigged.glb
python3 -c "import json;print(json.load(open('tools/character/out/diff-report.json')))"
python3 - <<'PY'   # PNG dimension/mode from IHDR, no full decode
import struct
for p in ['tools/character/out/outfit-a.png','tools/character/out/outfit-b.png',
          'tools/character/out/mask-chromatic.png','meshy/rigged/volpe/volpe-texture.png']:
    h=open(p,'rb').read(33); print(p, struct.unpack('>II',h[16:24]), 'bitdepth',h[24],'colour',h[25])
PY
```

The recolour run itself is deliberately **not** reproduced here (see section 4).
