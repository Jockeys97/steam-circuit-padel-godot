# Meshy trial: one rigged character from the Volpe views

Date: 2026-09-16. Purpose: prove the character lane end to end before the Godot port depends on it. This was a
test, not production: one character, one remesh, one rig.

## Outcome

Three GLB files, verified by parsing them, not by trusting the API response.

| File | Bytes | Triangles | Joints | Clips | sha256 |
|---|---|---|---|---|---|
| `volpe-rigged.glb` | 8,898,424 | 31,325 | 24 | 1 (base pose, 0.30s) | `ab6b3086e6a455d9...` |
| `volpe-walking.glb` | 8,911,212 | 31,325 | 24 | walking, 1.07s | `8ee2447b6fa6d7f7...` |
| `volpe-running.glb` | 8,906,600 | 31,325 | 24 | running, 0.67s | `47192d80c8bfb860...` |

Full hashes in `hashes.json`. The skeleton is the standard humanoid set: Hips, Left and Right UpLeg, Leg, Foot,
ToeBase, Spine, Spine01, Spine02, Shoulder, Arm, ForeArm, Hand, neck, Head, head_end, headfront. One material,
one embedded base colour texture (6.3 MB PNG, extracted as `volpe-texture.png`). The walking and running files
carry the same mesh plus their clip, so a Godot import can take the rigged base and add locomotion clips.

## What ran

| Step | Endpoint | Task id | Credits |
|---|---|---|---|
| Image to 3D, four views, base64 data URIs | `POST /openapi/v1/multi-image-to-3d` | `01a0a77f-097d-7091-80b0-e904b7d93ecb` | 30 |
| Remesh to 30,000 triangles | `POST /openapi/v1/remesh` | `01a0a78d-cf8e-763e-9bc0-4d1513e0d0b5` | 5 |
| Rigging, height 1.8 m | `POST /openapi/v1/rigging` | `01a0a794-ddfc-7644-b183-c919f5c3ee92` | 5 |

Total 40 credits. Account balance went from 3,060 to 3,020, which confirms the charges.

## What the docs got wrong, and what bit us

- `remesh` exists only under `/openapi/v1`. Posting to `/openapi/v2/remesh` returns 404.
- The image to 3D output arrived at 1,597,868 faces and rigging refuses anything above 320,000, so the remesh
  step is mandatory, not optional. Rigging before remeshing fails with a 400 that names the limit.
- `height_meters` defaults to 1.7 and matters for scale. A first attempt passed 1.1, wrong for a humanoid
  athlete; the successful run used 1.8.
- Rigging already returns walking and running clips in its result, under `basic_animations`. There is no need
  to call the animations endpoint for locomotion, which is what the animation decision in the map assumes.

## Honest limits

The model is recognisably Volpe: white spitz head with upright ears, goggles pushed up on the forehead, ivory
tee with gold trim, navy shorts, tail, wristbands. The render also shows defects typical of this pipeline at low
polycount: fingers and toes partly fused, the tail meeting the shorts unnaturally, and some texture smearing on
the legs. Good enough to build against and to judge scale, rig and pipeline; not good enough to ship without a
pass over the hands, the feet and the tail. Nobody has checked the mesh in a 3D editor or in engine, because
Godot is not installed on this host yet.

## Recipe for the next character

1. Views already prepared: `meshy/volpe-views/`, and for the other athletes `meshy/views/`.
2. `POST /openapi/v1/multi-image-to-3d` with the four views as base64 data URIs, front first.
3. `POST /openapi/v1/remesh` with `target_polycount` 30000, `topology` triangle, formats `["glb"]`.
4. `POST /openapi/v1/rigging` with the remesh task id and `height_meters` 1.8.
5. Parse the GLB before believing the task succeeded. The scripts that did this are in this folder:
   `run_gen.py`, `run_remesh.py`, `run_rig2.py`.

The API key lives outside the repository, at `/root/.config/meshy/api_key`.
