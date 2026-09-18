# Arena kit — image batch INDEX (for Luca)

Batch: **5 arenas × 11 images = 55 files**, all under `art/arena-kits/<arena>/<slot>.png`.
Producer: `tools/arena-kit/gen_assets.py` (resumable; Hermes image tool, provider
`openai` / `gpt-image-2.5-flare`, `aspect_ratio: square` → exactly 1024×1024).
Prompts: `tools/arena-kit/prompts/<arena>.json` (one fully written prompt per slot,
shared style block byte-identical across the whole pack — Meshy: wording drift *is*
style drift). Per-arena slot tables: `art/arena-kits/<arena>/MANIFEST.md`.
Spend ledger: `art/arena-kits/image-spend.json` — **cap 66, used 57, left 9, 0 failed calls**
(55 unique slot images; 2 slots regenerated once each, previous attempts kept under
`<arena>/_rejected/`). `torii/hero_landmark.png` is the parent probe, reused as-is
(sha256 unchanged: `b4b95d8b…4fa07b`).

## 1. Checklist status (KIT-STANDARD §4, 6 gating items)

Every one of the 55 images was verified **programmatically** (square 1024×1024, PNG,
file size sane, outer 6 px ring 100 % white, subject bbox measured with a clean margin
on all four sides) and **visually** (per-arena contact sheets + individual zooms):
single subject · white background · no text/watermark · uncropped · matte · ≥1024².
Measured subject fill runs 78–95 % of the frame with **min margin ≥ 2.15 % (22 px)** on
every image — nothing touches or crosses an edge. `ground_texture` is a full-bleed
tiling swatch (checklist items “white background” / “single subject” are N/A by design):
**never upload it to Meshy** — it is the material swatch for the apron.

## 2. Uploading to Meshy (image-to-3D), per image

1. Meshy → **3D Model → Image to 3D**; drag `art/arena-kits/<arena>/<slot>.png`.
2. Settings (KIT-STANDARD §3 / `scan/meshy-props.md` §7a): **Model Type = Smart
   Topology** (`meshy-t2`); **Poly Count ≈ 1,000–3,000** for small props, up to
   ~4,000 for large set pieces (hero_landmark, gate_portal); **Pose = Default** (never
   A/T-pose — objects only); **Image Enhancement = On**; **Auto Split = Off**
   (printing-only); Texture **2K, PBR on, Remove Lighting ON**; export **GLB**
   (embedded textures); origin bottom.
3. One image = one model. If a polycount overshoots, run **Remesh before texturing**
   (free in GUI; remesh after texturing breaks UVs).
4. Budget: **10 models per map** — build T1 first (`hero_landmark`, `gate_portal`,
   `light_source`, `vegetation_cluster`, `ground_dressing`, `ornament_accent`), then
   the four T2 slots when the budget allows.
5. Fallback if a model comes back distorted: fix the INPUT first — the documented
   order is re-prompt the image → try Multi-view → Remesh. Regenerate a slot image
   with `python3 tools/arena-kit/gen_assets.py --regen --arena X --slot Y`.

## 3. How the finished GLBs come back to us

- Save each Meshy download as `meshy/inbox/<arena>/<slot>.glb` (manual drop inbox,
  KIT-STANDARD §2); the engine-side path is `godot/assets/arenas/<arena>/<slot>.glb`.
- Download **immediately**: Meshy keeps assets 3 days, signed URLs expire sooner, and
  GUI-generated models are **not enumerable by the API** (`scan/meshy-props.md` G1) —
  the GUI download (or the Meshy-for-Blender bridge, Pro+) is the path back. If we
  ever want an automated pull, re-issue the same slot images through
  `POST /openapi/v1/image-to-3d` with the settings in `meshy-props.md` §7b (re-pays
  credits; task ids — not signed URLs — go in any log).
- Engine intake (mount/scale/suppress rules) lives in `godot/game/arenas/arena_kit.gd`;
  procedural geometry stays as fallback until a slot GLB exists.

## 4. Probes run during this batch (answers, n=1 each)

- **Reference image from the concept still — torii.** `torii/gate_portal` was generated
  with `art/concepts/world-arenas-r1/01-torii.png` passed as a style reference.
  Result: **palette carried cleanly** (vermilion/coral + indigo + lantern gold) and
  **no scene content dragged into the prop frame** (no court, glass, net, sky, horizon);
  it passed all 6 gating items first try and is the delivered image. Caveat: verified on
  one slot only; the other 53 images are text-only prompts and the per-arena palette
  tokens keep them coherent.
- **White-on-white — egeo.** `egeo/hero_landmark` (whitewashed cubes) was generated with
  the documented §1c fix built in: a pale grey-stone base course and cobalt dome/doors
  carry the silhouette. Result: **survives — no transparent-background fallback needed.**
  Silhouette legibility graded *acceptable* (shading + cobalt + stone edges read; not a
  bold outline). The same fix is in every egeo white prop and all passed. If a future
  egeo prop ever disappears into the white, add a stronger non-white base/trim before
  spending a transparent-background pass.

## 5. Files

| arena | images (11) | fill range | notes |
|---|---|---|---|
| torii | `hero_landmark` (parent probe) + 10 | 83–95 % | `ground_dressing` regenerated once (tight margin) |
| medina | 11 | 80–95 % | all first-pass |
| carioca | 11 | 84–95 % | all first-pass |
| aurora | 11 | 78–94 % | all first-pass |
| egeo | 11 | 82–93 % | `ground_dressing` regenerated once (subject mismatch) |

Contact sheets used for the visual review: `run/tmp/arena-kit/sheet-<arena>.png`.
Progress journal: `run/tmp/arena-kit/image-batch-journal.txt`.
