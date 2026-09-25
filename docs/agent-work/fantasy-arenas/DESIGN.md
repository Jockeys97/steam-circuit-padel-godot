# Six fantasy arenas: full 3D environments

User approval: rebuild the six pictured arenas with Astra Flash. Canonical checkout: steam-circuit-padel-11m, codex/integrate-arena-11m, initial HEAD 1160b184125a97dbcec5c3faf10b12c64f994ddb. The workspace contains unrelated concurrent work; preserve it.

## Contract

Build immersive, recognizable environments for cattedrale, forgia, tempesta, abissale, caldera, orrery. Existing art in game/arenas/art is the visual reference. Replace visible painting panels with real surrounding geometry and continuous environment backgrounds. Architecture must read from default, courtside and other supported cameras while keeping the court, ball and players clear.

- Cathedral: brass gothic nave, repeated tall arches and buttresses, luminous rose window, organ pipes, slow mechanical movement.
- Forge: industrial foundry hall, furnace mouths, overhead gantries outside camera sightlines, molten channels and machinery. Distinct from the open volcanic Caldera.
- Storm: substantial suspended platform, peripheral chains and turbine/airship silhouettes, cloud depth and restrained distant lightning, no rapid strobe.
- Sanctuary: underwater observatory framing, layered ruins/rocks, submarine color depth and distant marine movement/bubbles; transparent effects kept sparse.
- Caldera: visibly supported platform over volcanic terrain, rock walls, monumental industrial/titan silhouettes, lava flows and occasional embers.
- Orrery: celestial observatory, brass armillary landmark, orbiting planets, ring architecture and continuous starfield.

Scope is presentation only. Do not alter simulation, physics, court dimensions, save data, unlocks, selection IDs, music, or cameras. Reuse local assets and procedural geometry; no paid Meshy calls or downloads. Keep all large decoration outside the playable footprint; prevent front/roof geometry obscuring gameplay from any camera. Shared materials/meshes, bounded animation, no collisions or extra shadow-casting point lights. Prefer a small number of meshes/MultiMeshes; initial ceiling 100k extra triangles and 200 extra draw instances per arena, measured separately from existing stands. Explain any evidence-driven budget revision before acceptance.

Integration: a new dedicated fantasy_environment.gd builder with build(arena_root, id), invoked once after ArenaScenery.build in the currently clean arena_library.gd. It affects only the six IDs, hides legacy Backdrop*/Dressing_* for those IDs, and adjusts the arena-local Environment/lights. Do not modify concurrently dirty arena_scenery.gd, outdoor_landscape.gd, egeo_environment.gd. Preserve existing other arenas and shared court. New shader/helpers may live under game/arenas/fantasy/. No auto-commit/push.

## Phase and acceptance

One end-to-end Flash bundle owns discovery within scope, all six environment implementations, bounded animations and focused verification. Capture baseline copies before changing existing files. Capture all six arenas from default and courtside, plus representative real Match.tscn routes, using rendering-enabled Godot. Headless rendering cannot save screenshots. Supply image paths, geometry/node counts and test outcomes. Run a focused new scene contract/geometry/isolation test, existing arena_catalog_test.gd and targeted field-law/selection checks only where affected. Do not rewrite golden simulation baselines. Record unrelated pre-existing failures.

Astra reviews code and visual evidence once, with one consolidated correction request if required. Worker checkpoints every 5 minutes and after baseline, first usable arena, all six and validation; 35-minute soft handoff target. Stop with evidence if native routing fails; no alternate provider or CLI.

Astra also owns the independently scoped missing Cathedral/Forge menu previews: UiArtPaths.gd, the existing art-convention assertion in tests/ui/data_audit.gd, and two WebP captures under assets/ui/arenas/. Flash supplies clean scene captures; Astra connects them after visual acceptance. These files were clean at assignment.

Resolved during baseline: arena_look_test.gd::_frozen_nine_untouched pins the six arenas' old lighting. The visual rebuild deliberately supersedes those presentation pins. Flash may narrow that exact legacy test to the three unaffected IDs and cover the six new environments with meaningful rendering/compatibility invariants in its focused test. Frozen simulation values remain unchanged. Fourteen unrelated pre-existing world-arena look failures and one locomotive floor assertion were reported at baseline; do not fix those here.
