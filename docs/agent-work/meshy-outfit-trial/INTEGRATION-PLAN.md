# Maestro Mythic runtime integration

User approved promotion on 2026-09-22. Canonical branch verified:
`codex/integrate-arena-11m`. Preserve all existing staged, dirty and untracked work.

## Scope and contracts

- Use downloaded `maestro-mythic-rig` GLBs; no new Meshy calls or credits.
- Preserve athlete identity `maestro`, unlock key `maestro:mythic`, statistics,
  base model and all existing colour outfits. Variant selection is presentation only.
- Add pre-build outfit geometry selection in AthleteRig/AthleteSpawn; never swap
  skeleton under an existing racket anchor or animation library. Reject unsafe
  live switches or rebuild explicitly at the owning view boundary.
- Adopt compatible locomotion and bake five padel strokes for the actual new
  24-joint skeleton, using existing retarget tooling. Do not blindly reuse
  Maestro's animation resources just because the bone count matches.
- Route OutfitCatalogue availability/application/readback through the geometry
  variant, avoiding the base Maestro recolour mask on the new atlas.
- Preserve challenge gating and real save data. No automatic unlock.

## Acceptance

1. Isolated wardrobe selection persists and real Match spawns the Mythic mesh.
2. Base/circuit/legend/signature remain on the original Maestro model.
3. Run, idle, drive, smash, bandeja, backhand and slice have valid tracks,
   stable scale and no gameplay root motion; racket follows the hand.
4. Render front/back and stroke contact poses to check coat/shoulder deformation.
5. Wardrobe match, screen characters, racket and relevant stroke regressions pass.
6. No commit, push, paid calls or changes to player progression.

## Preflight blocker

No implementation edits made for this request. Astra–Flash skill static doctor
reported static-ready but runtime_verified=false and a non-Astra root route.
Optional local router catalogue GET failed with HTTPError. No inference request
or child launched; no private URL or credentials recorded. Resolve routing or
obtain an explicit direct/no-delegation instruction before implementation under
the repository orchestration policy.
