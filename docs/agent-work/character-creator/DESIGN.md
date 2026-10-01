# Character creator — first playable slice

Status: design ready; implementation not started. Canonical checkout: `steam-circuit-padel-11m`, branch `codex/integrate-arena-11m`. Baseline observed at `98356c2` on 2026-09-27. Preserve the many pre-existing uncommitted edits, especially `godot/src/character/athlete_rig.gd`, `godot/src/save/save_schema.gd`, and game flow files.

## Objective

Let a player create one persistent, visually distinct athlete, preview it in 3D, and select it for a match and career without changing the existing six athletes, their unlocks, or match statistics. The editor must work with mouse, keyboard, and controller and have a clear Back/Cancel route.

## Non-goals for the first release

- Free-form face sculpting, text-to-3D generation, or paid Meshy calls.
- New gameplay attributes, balance changes, or modifying existing athlete/outfit progression.
- Rebuilding existing GLBs or changing the frozen six-athlete asset standard.

## Repository constraints and design

- `docs/art/character-standard.md` freezes a single baked material/mesh for canonical roster GLBs. Its UV layout cannot currently recolor hair, skin, and clothes independently. Therefore a true editor must use a **separate custom-avatar asset pipeline** with modular meshes or material regions, not recolor an existing athlete's one baked texture and call that a creator.
- Reuse the existing `mixamorig:` rig contract and retargeted locomotion/strokes. Parts share a skeleton and do not introduce another animated rig per attachment. Avoid changing the six frozen athlete IDs or inserting an unregistered GLB in `godot/assets/athletes/`.
- Store appearance as a small, versioned data record (e.g. `schema_version`, display name, body/head/hair/outfit preset IDs, bounded color IDs), not a generated GLB or raw arbitrary paths. Validate IDs on read; unknown/old values fall back to safe defaults. Save separately from career/economy so existing profile migration and unlocks remain intact.
- Give the custom athlete a stable synthetic ID at the UI/match boundary, with stats sourced from a documented existing balanced preset. Customization is cosmetic only. Preserve the selected athlete through match, result, rematch, and career reload.
- Generate or render its roster thumbnail from the saved appearance; static six-athlete portraits remain untouched. Show a preview even before save, and restore the last saved appearance after restart.
- No asset download or generation is authorized by this design alone. First create/approve a minimal compatible modular body/head/hair/outfit kit and verify geometry, skinning, texture budget, and animation poses in Godot.

## Failure behavior

Missing/corrupt appearance save or unavailable art must not break the menu or match. Fall back to the documented default custom preset, and if its rig cannot load, leave the six canonical athletes playable and show a visible editor error. Cancel discards unsaved changes; Save validates then persists atomically through the existing save conventions.

## Acceptance

1. A new `Create athlete` entry opens an editor and Back returns to its caller.
2. Changing each visible option changes the 3D preview; controller focus and confirmation are usable.
3. Save/restart/reopen restores the name and appearance; Cancel does not alter the saved record.
4. The custom athlete appears in selection and can complete a match/career fixture with the same stats regardless of cosmetic choices.
5. Existing roster/outfit unlocks and saves behave as before. No paid generation, auto-commit, or modification of unrelated work.
