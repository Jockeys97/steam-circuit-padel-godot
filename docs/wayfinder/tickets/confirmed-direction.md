# Confirmed direction (2026-09-16)

- Status: resolved
- Type: task
- Mode: HITL
- Owner: Luca
- Blocked by: none

## Question

What did Luca actually confirm on 2026-09-16, so the rest of the map references
one place instead of repeating it?

## Resolution

Five decisions were confirmed by Luca in the 2026-09-16 clarify answers. They are
settled; the open tickets build on them and must not re-open them.

1. **Animation split.** Meshy rig plus Meshy locomotion clips for the athlete
   body; padel strokes (serve, forehand, backhand, volley, smash, lob) are
   authored in Godot. Locomotion comes from the Meshy rigging step, not a
   separate animation call.
2. **Camera start.** The first 3D build reproduces the current web build's
   composition on first load. Luca judges framing and feel after seeing it, and
   nothing is locked before that verdict.
3. **Delivery order.** Quick match reaches parity first. All other content
   (tournament, career presentation, drill-as-3D, challenges) comes after.
4. **Outfit route.** Outfits recolour the same rigged athlete model, not
   per-outfit models. The exact recolour path is still open and unproven; it is
   not decided that recolouring is easy.
5. **Steam in v1.** Desktop release first, with Steam achievements and Steam
   Cloud saves shipping in the first release.

## What these decisions do NOT settle

- They do not prove the recolour path. The Volpe rig has a single baked texture
  with no garment zones; whether it can be segmented for per-outfit tints is
  unproven and belongs to
  [Character pipeline economics](character-pipeline-economics.md).
- They do not fix the camera; they fix only that the first build matches the
  current framing.
- They do not pick an OS set or an input/save scope; see
  [Product scope and platforms](product-scope-and-platforms.md).
- They do not approve any spend, any asset generation beyond the one generated
  Volpe trial, or any implementation. This map is charted; these five are the
  only confirmations and nothing else is approved.

## Volpe trial provenance and limits

The Volpe asset under `meshy/rigged/volpe/` is a **newly generated** trial,
produced by the Meshy lane on 2026-09-16 from turnaround views. It is **not** a
retrieval of Luca's latest existing asset and **not** a shipped roster athlete.
Facts later tickets depend on:

- `volpe-rigged.glb` is a base pose only: one clip, one key at t=0.30 s,
  duration 0.0. **There is no idle clip anywhere.**
- Walking (32 keys) and running (20 keys) live only in the companion files
  `volpe-walking.glb` and `volpe-running.glb`.
- 24 joints, ~31,325 triangles per file, one embedded baked base-colour texture
  (`Material_1`). No outfit zones, no vertex colours, no separate garment
  materials — **tint zones are unproven**.
- Sizes and sha256 are in `meshy/rigged/volpe/hashes.json`. The rigging response
  (`rig_final.json`) contains signed expiring download URLs; never quote them.
