# Luca arena integration

Source: f732998, canonical checkout steam-circuit-padel-11m, branch
codex/integrate-arena-11m. User approved integrating the arena assets under LFS.
Existing dirty pace/progression/character changes are unrelated and preserved.
Arena loader and arena_kit_test currently match source parent; no dirty arena paths.

One vertical implementation bundle, one Flash writer. Capture exact affected
baseline first. Import 50 GLB + 150 JPG runtime assets and required import sidecars
from source, selectively port arena_kit.gd and intake tests. Port required tooling
only; do not copy mission dumps or generator scripts without runtime/test need.
Preserve actual GLB data (never replace models with LFS pointer text on disk).
Existing .gitattributes covers GLB/JPG. Root will register new binary assets in
the index with LFS after review; worker does not stage, commit, merge, or push.

Fix source's three known intake failures, preserving spatial constraints:
3.26 m depth budget, no decor crossing rear glass or disappearing behind backdrop,
repeat offsets centered for asymmetric meshes. Normalize/fit geometry consistently
and update spec to measured results; do not weaken tests, expand budgets or remove
models to pass. Preserve recognizable models, no collision or gameplay changes.
Keep procedural suppression for slots with actual loaded replacements; graceful
fallback for missing/unloadable assets. No new Meshy calls or costs.

Owned files: godot/assets/arenas, godot/game/arenas/arena_kit.gd and directly
necessary arena loader integration files, godot/tests/arena_kit*.gd + sidecars,
focused new arena integration/performance probe, necessary tools/arena-kit
inspection utilities; task evidence/REPORT.md here. Do not edit unrelated game,
character, save or UI code. Do not change .gitattributes or Git configuration.

Required checks only: arena_kit_test, world_arenas_field_law_test,
world_arenas_selection_test, and a visual/load smoke test across five arenas.
Capture representative rendered views. Compare same-arena rendered frame timing
with/without kit (warm-up then measured sample, same size/render settings), plus
load time/draw/geometry figures if available. Headless timing is NOT GPU/FPS proof.
If a serious slowdown appears, investigate only the new kit path; report tradeoffs
before broad quality reductions. Tests use isolated config, not live user saves.
Root checks LFS objects/index pointers and actual patch. No repository-wide suites.

Milestones via native message: baseline captured; usable implementation; checks
complete. Checkpoint interval 5 minutes; soft handoff 20 minutes for binary intake
and render measurement. At deadline return current evidence and specific remaining
acceptance, not more unrelated testing. Keep report short and logs local. Do not
wait for a perfect report before handing off. Stop and preserve partial work for
concurrent edits, missing dependencies, or repeated failure with no useful progress.
