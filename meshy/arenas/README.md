# meshy/arenas — the arena kit upload batch

One image per asset, ready to run through **Meshy → Image to 3D**, one at a time.

- `meshy/arenas/<arena>/` — the 10 Meshy props for that map (`hero_landmark`, `gate_portal`,
  `light_source`, `vegetation_cluster`, `ground_dressing`, `ornament_accent`, `column_pillar`,
  `railing_segment`, `furniture`, `signage_banner`). `MANIFEST.md` says what each one is.
- `meshy/arenas/_ground-textures/` — the 5 ground textures. **Do not upload these to Meshy**;
  they are material swatches that go straight into Godot's apron material.
- `meshy/arenas/UPLOAD-LIST.md` — the numbered, tick-off list (50 models + 5 textures).

## Recipe per image

Image to 3D → Smart Topology → ~4k faces → 2K texture → bottom origin. Model name =
`<arena>__<slot>`, e.g. `torii__hero_landmark`.

Meshy keeps assets for 3 days and Workspace models are not enumerable through the API —
download each GLB as you go.

## How the models come back

Either drop each GLB at `meshy/inbox/<arena>/<slot>.glb` and it gets pulled into
`godot/assets/arenas/<arena>/<slot>.glb`, or hand over the Meshy task ids and the API pull
does it (`tools/arena-kit/pull_meshy.py`). Once a GLB is in place, the arena mounts it
automatically on the next build — no code change.

## Keeping this folder in step

`art/arena-kits/` is the canonical batch (ledger, prompts, manifests, scripts all point
there). After any regeneration, refresh this folder with:

    bash tools/arena-kit/sync-meshy-folder.sh

Files are hard-linked, so the copy costs no extra disk.
