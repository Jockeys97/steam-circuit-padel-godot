# Meshy outfit pilot — 2026-09-21

Canonical checkout: steam-circuit-padel-11m, codex/integrate-arena-11m.
Bounded user-authorized trial, performed directly without Flash. No commit/push.

## Actual API spend

Starting API balance 660; final balance 615. Three successful tasks, 45 credits:

- Colosso Signature retexture: 10, `01a0c4f4-0e89-7286-bd1d-11012f1567a0`.
- Maestro Mythic image-to-3D: 30, `01a0c4f4-3256-75cf-9ef1-3b0955a832f3`.
- Maestro Mythic auto-rigging: 5, `01a0c4f9-4e14-730d-9d1f-f48a212a293c`.

Task records contain request settings, source hashes, status and billed credits.
No keys, request image payloads, authentication headers or signed URLs are stored.
Runner reserves the task record before POST: uncertain submissions must be
reconciled, never blindly retried. `status` resumes downloads without more generation.

Pricing reference: https://docs.meshy.ai/en/api/pricing

## Colosso Signature — integrated

Used actual `assets/outfits/colosso/signature-preview.webp`, converted losslessly
to PNG for API format compatibility. Retexture keeps original UVs, 2K albedo.

Returned GLB is NOT a replacement for runtime: Meshy removed skin and animations
and deduplicated two vertices. All 8,928 UV triangles match the original model
after order-independent comparison at 1e-5 precision (audit JSONL).
Only the albedo is promoted to
`godot/assets/athletes/outfits/colosso/signature_albedo.png`.
The existing GLB, 28-joint skeleton, skin weights, normals and animation set stay
unchanged. Original PBR maps remain in use. The new texture distinguishes bare
skin from dark armour, but is a generated approximation: skin shading and fine
details are not pixel-identical to base or the 2D artwork.

OutfitCatalogue now supports a dedicated texture lane alongside masked recolours.
Each rig owns a reusable material; base restores the original, other rigs remain
independent. CharactersScreen uses a shared availability predicate. Challenge
requirements are unchanged; no real save or unlock was modified.

Verification:
- `outfit_wardrobe_match_test.gd`: PASS, 36 assertions. Isolated test profile;
  real wardrobe handler, disk reload, all four real Match rigs, Colosso base
  restoration/material reuse/instance isolation/run clip.
- `tests/ui/screen_characters_audit.gd`: PASS 190/190.
- Actual Godot captures: base/signature, idle/run, front/back: 8 renders plus
  comparison under `colosso-live/`. No capture failures.
- JavaScript syntax checks and `git diff --check` pass.
- Wardrobe test reports six ObjectDB instances leaked at process exit; this
  does not invalidate the assertions but is not a clean leak audit.

## Maestro Mythic — generated and rigged, NOT enabled in matches

Source `assets/outfits/maestro/mythic-preview.webp`. New coat, shoulder plate and
boots; no fused racket visible in front/back review. Result has 20,543 triangles
(target 20,000), 2K textures. Auto-rig produced a 24-joint skeleton and walking /
running companions. Static front/back captures and two running phases are saved
under `maestro-mythic/` and `maestro-mythic-rig/`.

This is a successful art/rig feasibility trial, not a completed runtime outfit.
Before promotion: outfit-specific mesh selection without replacing base Maestro,
adapt existing padel stroke clips and racket attachment, check coat deformation
during smash/bandeja/backhand/slice, and verify runtime performance and switching.
Do not unlock or advertise this Mythic as wearable yet. No mass generation of the
remaining wardrobe was started.

The capture harness frames skinned exports from bone bounds as well as mesh AABB;
the raw Meshy armature has centimetre bones with a 0.01 scale, so static bounds
alone incorrectly frame an empty image.
