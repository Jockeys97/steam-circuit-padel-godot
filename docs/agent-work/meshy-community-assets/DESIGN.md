# Meshy community scenery integration

## Objective

Use the five user-supplied public Meshy GLBs as optional scenery in their matching
3D arenas (Medina fountain, Egeo windmill, Aurora geyser, Locomotive Depot train,
Torii stone lantern), without changing court geometry, physics, camera, or input.

## Asset gate

The supplied Egeo windmill is 145.2 MiB / 3,612,179 triangles, Medina fountain
63.8 MiB / 1,824,527 triangles, Aurora geyser 25.4 MiB / 585,754 triangles,
train 19.1 MiB / 29,999 triangles, and lantern 2.0 MiB / 26,380 triangles.
Do not place the raw windmill, fountain, or geyser in a live match. Reduce them
locally, preserving silhouette and textures at their intended camera distance;
record source and output sizes, triangle counts, image sizes, and visual checks.
No Meshy API calls or credits. Do not modify or delete the Downloads originals.

## Placement and compatibility

Keep assets outside the playable court and disable collision/dynamic shadows.
Instantiate only for the selected arena. Preserve existing procedural dressing
and other contributors' current work. Integration may proceed only when the
actively edited arena scripts have a stable baseline; an additive dedicated
helper is preferred over broad rewrites.

## Acceptance

- Each selected GLB has a verifiable source/license note and Git LFS matching.
- Heavy models are substantially smaller and visibly adequate for their role.
- Scene import and focused arena tests pass; no missing resources or new Godot
  parse errors. Report pre-existing test failures separately.
- Capture at least one in-game view for each new landmark before claiming that
  placement or visual quality is verified.
