# Runtime integration — five Mythics

User requested activation after generation. Godot-only, canonical 11m branch.
No API calls, commits, pushes, real-save edits or artificial unlocks.

Reuse Maestro's pre-build geometry variant mapping and existing rotation-only
stroke baker. Own only the five new Mythic asset directories, 25 new stroke clips,
outfit_geometry.gd mappings and focused regression tests/documentation.
Preserve all base meshes/skins and existing geometry/material logic. No hot
geometry switch on a live rig; new matches construct the saved outfit correctly.

Acceptance: all five unlocked wardrobe choices persist, reach actual Match rigs,
retain athlete identity/locked fallback, dispatch five imported strokes with
valid contact/recovery, stay attached to the racket, and preserve base variants.
Use isolated test profiles, native rendered match/pose evidence and existing
wardrobe/challenge regression suites. No claiming static load is match proof.

## Completed validation

- Actual wardrobe -> isolated saved profile -> five native Match instances:
  `MYTHIC_BATCH_INTEGRATION 236/236`. All four roles carry saved Mythic geometry.
- Five stroke suites: `533/533` each; 25 locally retargeted clips, no API spend.
- Racket regression: 90 poses, zero failures, including all six Mythics.
- Wardrobe regression PASS; challenge audit PASS 89/89. No unlock rules changed.
- Inspected all five native stroke grids and Fiamma/Oracolo match captures.
  Models animate and rackets follow hands. Long garments on Fiamma/Oracolo still
  show deformation/clipping in some bent poses; this is not cloth simulation.
- Existing Colosso texture-material initialization emitted missing-meta errors;
  guarded the optional lookup without changing material behavior.
- Existing ReplayOverlay anchor warnings remain outside this change.

Runtime assets are ten walk/run GLBs plus 25 baked stroke resources. Bases and
Maestro Mythic remain intact. Equip an unlocked Mythic and start a new match;
an already running match is not hot-swapped. No user save changes or commit.
