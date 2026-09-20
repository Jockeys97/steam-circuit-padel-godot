# Fiamma: Circuit, Legend, Signature

Implemented locally on `codex/integrate-arena-11m`, baseline HEAD `331c3dc`.
Completed directly by Astra after the user stopped the Flash delegation. No paid
API calls, commits or pushes. Other dirty gameplay/UI changes were preserved.

## Result

The existing wardrobe IDs now select a dedicated masked Fiamma material. Circuit
uses blue/cyan, Legend charcoal/ivory/gold, Signature petrol/lime. The original GLB,
skeleton, animation tracks, gameplay and unlock data are unchanged. The shader
retains the original normal and roughness maps and the rig's existing nonmetallic
presentation defaults. Base reinstalls the original material object. A rig owns
one reusable variant material; the immutable mask is shared. Unsupported Mythic
returns to the baked look rather than leaving the last supported skin visible.
Dedicated athletes without a profile retain their original appearance.

This is a **palette/material adaptation**, not a faithful recreation of every
illustrated seam or flame graphic. The 2D previews and sprite colours guide the
result; the existing baked garment geometry/pattern remains. Wristbands stay in
their original lime colour as protected accessories. Original baked texture and
mesh facets remain visible in close-ups. Mythic and other athletes are out of scope.

## Corrections to the partial delivery

- Capture hid all other rigs before each render (previously four coincident meshes),
  fixed the square framebuffer, paused clips and sampled normalized clip phases.
- Fixed mask UV orientation in the rasterizer and separated abdomen from skirt
  using bind-space height; made region tie-breaking deterministic.
- Fixed Compatibility renderer colour-space handling and removed a value cutoff
  that prevented bright lime fabric from being recoloured.
- Preserved normal/roughness maps, cached materials, exact base restoration, and
  safe fallback for the known but unauthored Mythic ID.

## Evidence and validation

Godot command prefix: `/Applications/Godot.app/Contents/MacOS/Godot --path godot`.
Headless tests add `--headless --script`; visual captures use `--script` without
headless. All commands run from the canonical repository root.

| Command / script | Result |
| --- | --- |
| `res://tests/outfit_fiamma_profile_test.gd` | 108 checks, 0 failures: instance isolation, repeated switching, exact base restoration, maps, fallback, 26 entries |
| `res://tests/meshy_strokes_test.gd -- --athlete=fiamma` | 611/611 |
| `res://tests/racket_hand_follow_test.gd` | 30 poses, 0 failures |
| `res://tests/modes/outfit_challenges_audit.gd` | 89/89 |
| `res://tests/ui/screen_characters_audit.gd` | 165/165 |
| `/usr/bin/python3 tools/character/validate_standard.py` | 43/43; 6 existing registry/budget warnings |
| `/usr/bin/python3 tools/character/build_fiamma_outfit_mask.py --check` | reproducible, SHA prefix `f176618b03f92216` |
| `res://tests/outfit_fiamma_capture.gd -- --size=640` | 64 captures: four states, four poses, front/back, two scales; plus labelled comparison |
| `res://tests/outfit_fiamma_match_capture.gd` | real Match scene, four rigs, two independent Fiamma outfits; staged visual fixture, not a full gameplay trial |
| `git diff --check` | passes |

`athlete_roster_test.gd` is **not passing**: it assumes 24 joints, exactly three
locomotion clips/four strokes and the legacy shader fields on dedicated models.
Those expectations conflict with the existing 28-joint Fiamma and expanded
animation set. Its reported 56/60 also includes a script error reading a missing
legacy field, so it must not be treated as a successful gate. It was left unchanged.
ReplayOverlay emits existing anchor warnings during the match capture.

Rendered colour check across eight full-body base views (four poses × two sides):
142,707 skin-coloured samples per variant, selected by base HSV hue 9–37.8 degrees,
saturation > .3 and value > .3. Maximum-channel absolute RGB difference: mean
0.942/255 Circuit, 0.941 Legend, 0.942 Signature; p95 5/255, max 28/255 for all.
This is a skin-colour heuristic including antialiased edges, not a semantic proof
for every eye/hair texel. Visual inspection shows no broad skin recolouring.

## Assets and viewing

- Runtime mask: `godot/assets/athletes/outfits/fiamma/fiamma_region_mask.png`, about
  1.0 MiB, 2048² RGBA; mask plus original model textures, no duplicate GLB.
- Diagnostic preview: approximately 5.5 MiB, not loaded by gameplay.
- One surface per rig; one cached ShaderMaterial per dressed Fiamma, plus its
  original StandardMaterial3D for Base.
- `evidence/renders/fiamma-lineup.png`: labelled four-state comparison.
- `evidence/fiamma-match.png`: two different variants in the real match scene.
- `evidence/renders/`: close/full-body front/back idle/run/backhand/smash captures.

Use the existing Fiamma wardrobe and equip an unlocked Circuit, Legend or Signature
outfit. Existing challenge requirements remain in force. Visual approval and a
user playtest remain separate from these technical checks.
