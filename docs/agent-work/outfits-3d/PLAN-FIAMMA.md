# Fiamma 3D outfit trial — executable brief

Status: first three Fiamma material variants implemented and tested directly by
Astra following the user's request to stop delegation. See REPORT.md for evidence
and visual limits; illustration-exact artwork is not claimed.
Canonical checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`,
branch `codex/integrate-arena-11m`.

## Outcome

Implement the existing `circuit`, `legend` and `signature` outfit IDs on the
current `fiamma.glb`. Preserve Fiamma's mesh, skeleton, animations, dimensions,
collision, racket attachment, gameplay stats and unlock contracts. Selecting an
outfit must visibly change the 3D athlete in menus and in a match.

The target is the in-field 2D sprite language, using each preview as styling
reference. Do not claim pixel-perfect fidelity to the illustrated cards. Mythic,
new garment geometry and other athletes are explicitly out of scope.

## Existing contracts

- Catalogue owner: `godot/src/character/outfit_catalogue.gd` and
  `godot/assets/athletes/reference_catalogue.json`.
- Runtime owner: `godot/src/character/athlete_rig.gd`.
- Source model: `godot/assets/athletes/fiamma.glb`; one mesh/material, Mixamo-28.
- References: `assets/outfits/fiamma/{circuit,legend,signature}-preview.webp` and
  six sprite sheets per outfit.
- Today `uses_catalogue_recolour()` refuses all dedicated Meshy athletes and
  `apply()` records the outfit without changing appearance. Replace that silent
  no-op for Fiamma only; leave other athletes safe until they have their masks.

## Implementation bundle

1. Inspect the embedded Fiamma base-colour texture and UV layout. Produce an
   explicit, reproducible garment mask that separates at least fabric, trim and
   protected skin/hair/eyes. Masks and derived textures live under
   `godot/assets/athletes/outfits/fiamma/`; source tooling lives under
   `tools/character/`. Do not paint skin through broad colour selection.
2. Create dedicated textures/material parameters for:
   - Circuit: blue/cyan athletic kit;
   - Legend: charcoal/black, ivory and gold trim;
   - Signature: petrol/teal with lime flame accents.
   Preserve normal and metallic/roughness maps unless a measured reason requires
   a derived map. Keep files LFS-compatible and avoid duplicate embedded GLBs.
3. Add an athlete-specific material profile or lookup. `OutfitCatalogue.apply`
   must remain backward compatible: Volpe keeps its existing shader; Fiamma uses
   the new profile; dedicated athletes without a profile remain visually unchanged
   and explicitly report unsupported rather than corrupting their materials.
4. Keep each rig instance's material unique. Two simultaneous Fiamma instances
   wearing different outfits must not overwrite one another. Switching to `base`
   restores the exact original texture/material behavior.
5. Preserve catalogue IDs, challenge/unlock data, save values, menu selection,
   skeleton tracks, animations, racket attachment and gameplay behavior.

## Allowed scope

`godot/src/character/outfit_catalogue.gd`, narrowly necessary methods in
`godot/src/character/athlete_rig.gd`, new Fiamma outfit assets, focused tools and
tests, and `docs/agent-work/outfits-3d/` reports/evidence. Touch UI only if a
verified bug prevents the existing wardrobe choice from reaching the rig.

Do not edit Meshy credentials, call paid APIs, regenerate the athlete, alter the
GLB skeleton, modify unlock requirements, change other character appearances,
commit, push or discard concurrent changes. Preserve all dirty files unrelated
to this bundle.

## Acceptance

1. Catalogue still exposes 26 entries and the same Fiamma IDs/unlocks.
2. Circuit, Legend and Signature produce visibly distinct, reference-aligned
   outfits; base round-trips byte/parameter-equivalent to the original material.
3. Skin, hair, eyes, racket and protected accessories stay within a measured
   colour-difference tolerance from base; no alpha holes or emissive accidents.
4. Two Fiamma rigs can show different outfits simultaneously with independent
   materials; every outfit survives repeated switching without accumulating nodes
   or material instances.
5. At minimum render front/back views for idle, run, backhand and smash for all
   four states (base plus three variants), and one real match frame with two
   different outfits. Inspect at native match camera scale and menu close-up.
6. Existing character-standard, outfit catalogue, Fiamma animation, stroke bridge,
   racket-follow and relevant screen audits pass. Add focused tests for profile
   selection, base restoration, instance isolation and unsupported-athlete safety.
7. Report generated file sizes, material count, render evidence, exact commands,
   limitations and whether the result matches sprites or cards. No claim of final
   visual approval without the user's playtest.

## Routing gate

The user confirmed selection of Astra in the app. The doctor reports the native
Flash role/catalog as static-ready; its global configuration alias does not
resolve the app's model override. Proceed through the native astra_flash_builder
role. Provider runtime routing remains unverified unless host metadata confirms it.
