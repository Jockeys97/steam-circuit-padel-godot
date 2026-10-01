# Character creator — implementation plan

Status: planned, not implemented. Use the existing checkout and branch stated in `DESIGN.md`; do not commit, push, or overwrite concurrent edits.

## Phase 1 — compatible art and data contract

Create a minimal modular, skinned kit (body/head, two hair variants, two outfits, bounded palette) on the existing `mixamorig:` skeleton. Validate import and animation poses. Add a versioned appearance record with strict preset IDs, defaults, atomic persistence, and focused save/migration tests. Do not modify the frozen roster assets. If art cannot be produced at acceptable quality from existing/local sources, stop and report the concrete missing asset rather than substituting a flat tint of the baked character.

## Phase 2 — editor and preview

Add a `Create athlete` entry, 3D preview, appearance/name controls, Save/Cancel/Back, and a visible error state. Support mouse, keyboard, and controller focus. Verify that all choices affect the preview, Cancel discards edits, and re-entry/restart restores saved data.

## Phase 3 — selection and gameplay integration

Expose one stable custom-athlete ID in selection and roster thumbnails, map its gameplay stats to the documented balanced preset, and carry its appearance through match, rematch, results, and career. Keep the existing six athletes, outfits, and unlock rules untouched. Run focused selection/save/controller tests and a real Godot match smoke check; record unrelated suite failures separately.

## Ownership and handoff

One approved Flash implementation worker owns discovery, implementation, tests, debugging, and routine visual QA for the full slice. The Astra root reviews specification compliance and quality/security in one batch. The worker should give a concrete checkpoint about every five minutes and aim to hand off within fifteen minutes; no auto-commit. Before dispatch, verify Astra root/Flash routing and coordinate overlapping dirty files (`athlete_rig.gd`, `save_schema.gd`, game flow) so concurrent work is preserved.
