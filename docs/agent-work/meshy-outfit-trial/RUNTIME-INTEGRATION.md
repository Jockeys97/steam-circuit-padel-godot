# Maestro Mythic in-game — 2026-09-22

Implemented directly following explicit user authorization, without Flash or any
new Meshy calls. This supersedes the pilot report's 'not enabled in matches'.
Canonical checkout/branch verified. Existing concurrent changes and staged files
preserved; this task did not stage, commit, push or alter real player saves.

## Runtime

- `outfit_geometry.gd` owns the cosmetic variant mapping, retaining `maestro`
  identity and `maestro:mythic` progression. Other outfits retain the old model.
- Spawn selects geometry before construction. New 24-joint rig uses its own
  walking/running clips and a planted, breathing idle. Shoulder and hand rotations
  participate in idle relaxation, fixing the initial open-arm silhouette.
- Five distinct motion resources baked onto the actual Mythic skeleton for drive,
  smash, bandeja, backhand and slice. All 24 target joints mapped. No extra paid
  motion generation. Simulation timing and character statistics unchanged.
- OutfitCatalogue recognizes the geometry variant and skips the old UV mask.
  Switching geometry on a live rig is explicitly rejected: a new match constructs
  the correct skeleton and hand attachment, rather than invalidating live nodes.
- Wardrobe availability and saved selection now reach the actual Match rig.
  Existing challenge requirements apply; no automatic unlock was granted.

## Evidence

- `meshy_strokes_test.gd -- --athlete=maestro --outfit=mythic`: five dispatches,
  contact timing, finite rotations, stationary stroke translations, upright body,
  smash hand above head, recovery, fallback, and relaxed idle arm checks.
- Same stroke test for base Maestro: 531/531.
- `racket_hand_follow_test.gd`: 35 poses across base roster plus Mythic; zero
  failures. Grip distance and world scale checked, not just attachment parent.
- `outfit_wardrobe_match_test.gd -- --capture`: 45 assertions; isolated save,
  unlock gating, four real Match rigs, old variants preserved, unsafe live switch
  rejected, and actual arena capture.
- `tests/ui/screen_characters_audit.gd`: 190/190.
- 12 front/back renders of base/Mythic idle, run and smash, plus comparison in
  `runtime/`. Contact pose sheet in
  `../meshy-roster-retarget/maestro-mythic-poses.png`.
- Syntax/diff checks clean. Visual review performed in Godot, not only API preview.

## Limits

Variant remains an explicitly documented in-trial asset: legacy 24-joint skeleton,
20,543 triangles (543 over the standard ceiling), no cloth simulation. Pose review
does not guarantee absence of coat clipping in every blend. The base asset standard
and gameplay budget have not been globally relaxed. Future optimization is separate
from this functional outfit integration.
