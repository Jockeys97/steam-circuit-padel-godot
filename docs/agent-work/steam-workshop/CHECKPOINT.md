# Officina del Vapore — playable pilot

Canonical 11m / codex/integrate-arena-11m. Direct work, preserving concurrent
arena_scenery edits. No Meshy/API calls, commits, 2D or simulation changes.

## Implemented

New steam_workshop.gd builds a cutaway industrial rear wall, amber window panels,
iron framing, copper manifold, two pressure boilers/dials, subtle steam and low
perimeter plinths. No overhead geometry. Existing stands/shelters remain.
Scenery integration is strictly id == officina; other arenas keep their path.
Old Officina props are skipped (including tree GLB loads), old backdrop layers
hidden, exterior ground gets a local dark matte material. No shared-material edits.
Windows are emissive-looking unshaded geometry, not additional dynamic lighting
or a claimed baked-lightmap pipeline. Deliberately stylized pilot, not a finished
photoreal reconstruction of the 2D illustration.

## Verification

steam_workshop_test.gd --capture: exit 0, STEAM_WORKSHOP failures=0 and
WORKSHOP_MATCH failures=0. Actual Match.tscn instantiated with isolated save path,
Officina selected, four athletes visible; no player save changed.
Native captures: default, wide, playable and broadcast. Inspected default,
playable, broadcast and actual match. No new geometry inside court cage; bounded
cutaway heights, no new collisions or lights. Locomotive remains unmodified.
Existing ReplayOverlay anchor warnings remain unrelated.

Cost: 3,792 static triangles in 7 MultiMesh families plus two six-particle vents.
New geometry casts no shadows. This is a structural rendering budget, NOT an FPS
benchmark; existing stands (~920k triangles) and shelters/boards (~1.15m) dominate
the scene and remain a future optimization task. No promise of zero lag.

Existing historical tests expecting frozen scenery counts/visibility for Officina
must account for this intentional replacement; full historical suite not run.
No change to arena physics, selection IDs, camera presets, ball or unlock rules.

Depot and Clockwork Factory are not rebuilt by this pilot.

## Detail pass

Arched amber windows and iron segment frames; riveted columns; rounded boiler
caps and wheel valves. World-space procedural brick/slab joints, surface grain
with distance filtering, metal roughness and subtle painted warm window spill.
Officina-only per-instance canopy shader replaces turquoise with dark canvas;
sponsor boards are excluded, shared source materials never changed. The cheap
canopy shader intentionally does not reproduce imported normal/metallic maps.
No new dynamic lights, shadows, collision, API costs or gameplay changes.

Updated budget: 12,456 static triangles, 10 MultiMesh groups, same 12 steam
particles. Native test and actual match pass, four camera captures generated;
playable and match images inspected. No script/shader errors (existing replay
anchor warnings only). Tests also check no workshop material leaks to Locomotive
and no replacement of sponsor textures. Full-match FPS benchmark not performed.
This is richer stylized art, not photoreal parity with the painted 2D reference.

## Landmark pass

workshop_engine.gd adds central flywheel, opposed piston rods, raised service
platform with supports/stairs/rails, and an Officina del Vapore sign. Wheel turns
at 0.22 rad/s (~29 seconds/revolution); rods travel +/-0.12 m. Pure decorative
_process, no input, physics, audio or simulation calls. Existing vents remain
subtle continuous effects; point-triggered steam was not added in this pass.

Total static geometry now 13,440 triangles: 10 existing MultiMesh families plus
individual engine meshes and one label (not a claim of only 10 draw calls).
Native capture test exit 0; engine bounds and animation-rate checks pass along
with material isolation and actual Match.tscn validation. Match capture inspected;
no script errors, existing ReplayOverlay warnings only. No full FPS benchmark.
No commits, paid APIs or non-Officina arena modifications.
