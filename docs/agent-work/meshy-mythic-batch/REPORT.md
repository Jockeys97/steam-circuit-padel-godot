# Five Mythic outfits generated and rigged — 2026-09-22

Update: runtime integration completed after this generation report. See
INTEGRATION.md for wardrobe/match, strokes and racket validation plus limitations.
The generation-only scope described below is historical.

Canonical 11m, branch codex/integrate-arena-11m. Direct work, no Flash delegation.
No runtime edits, save/unlock changes, commits or pushes.

## Actual spend

Starting API balance 615; final balance 440. Ten successful tasks, **175 credits**:
five textured image-to-3D jobs at 30, five auto-rig jobs at 5. No paid retries or
extra animation purchases. Walking/running came with the rigging results.
Per-task JSON records contain IDs, settings, billed credits, hashes and paths.
No credentials, signed URLs or base64 payloads are stored in records.

Current docs used: https://docs.meshy.ai/en/api/pricing,
https://docs.meshy.ai/en/api/image-to-3d, https://docs.meshy.ai/en/api/rigging.
Meshy-7.1 standard geometry, 2K textures, PBR, A-pose, target 20k triangles.
Original 2D references converted to PNG without appearance editing.

## Deliverables

| Mythic | Generated triangles | Rigged triangles | Skeleton | Companion clips |
| --- | ---: | ---: | ---: | --- |
| Fiamma | 20,387 | 20,387 | 24 joints | walk/run |
| Pantera | 20,726 | 20,720 | 24 joints | walk/run |
| Steamer | 20,749 | 20,749 | 24 joints | walk/run |
| Oracolo | 20,505 | 20,505 | 24 joints | walk/run |
| Colosso | 20,728 | 20,728 | 24 joints | walk/run |

Each `<athlete>-model/model.glb` retains the generated source. Each
`<athlete>-rig/` contains `model.glb`, `running.glb` and `walking.glb`.
GLBs are covered by the repository's existing Git LFS attributes but have NOT
been committed/pushed. Maestro Mythic and Colosso Signature were not regenerated.

## Verified

- All ten tasks succeeded; hashes of all 25 returned artifacts verified.
- GLB headers/lengths parse; all 15 rigged exports contain skin joint/weight
  attributes and 24-joint skins. Walk/run contain animation channels.
- Original and rigged triangle counts measured with existing glb_tri_count.py;
  rigging changed Pantera by six triangles, so topology identity is NOT assumed.
- 30 native Godot captures: five static front/back pairs plus two running phases
  front/back for each athlete. No script errors in capture logs; all processes
  finished. Visual review of source previews, static backs, all running fronts
  and clothing-sensitive running backs shows recognizable outfits, complete
  bodies and no fused rackets in the inspected views.
- Reusable paid runner has fixed athlete/stage allowlists, exclusive pre-POST
  reservation, no retry of uncertain submissions and a maximum ten paid slots.
- Node syntax and git diff whitespace checks pass.

## Limits and next work

These are candidate 3D assets, **not yet selectable playable Mythics**. Do not
replace existing bases, particularly Pantera/Steamer's legacy fallback bodies.
Map the outfit IDs explicitly, retarget five padel strokes, align racket grip,
test switching and performance, and inspect shoulder/cloth deformation before
promotion. Close-up running poses show coarse shoulder/elbow deformations and
possible cloth/body overlap; two sampled phases do not certify an entire cycle
or a smash. Faces and backs are generated interpretations, not exact replicas.

The rigging output contains only one embedded image (albedo), unlike the original
PBR source. Preserve the source GLBs for material recovery; do not claim the rig
retained all PBR maps. No additional budget remains for generation retries.
