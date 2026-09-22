# Wardrobe to match — 2026-09-21

The live match now passes saved career data to Lineup.outfits. All four roles use
equippedOutfits keyed by athlete ID and the same CareerRules unlock check used by
CharactersScreen. Legacy diagnostic callers without career data keep their explicit
player outfit argument. Tests use an isolated save directory.

Oracolo's actual 2D catalogue has base, signature and mythic only. Signature now uses
the existing UV mask and violet anchor #301850 for both shader families, with the
same #38216f target across all regions. This avoids both the waist seam and the
skin-matching magenta anchor. Cyan accents have no separate surface on this model.
Front/back renders are under evidence/oracolo-live. The difference from base is
subtle; this is a recolour, not the mythic costume.

Unavailable non-base 3D outfits remain visible with an explicit localized notice
and retain their challenge description, but cannot be equipped from the wardrobe.
Their unlock progress is not removed.

Colosso remains unsupported: its existing mask covers bare deltoids and thigh.
A manually authored garment exclusion mask is the selected next mechanism, but
has NOT been authored or enabled by this change. The measured overlap means that
adding a shader channel alone cannot supply the missing garment labels. Pantera
and Steamer still need usable rig assets; mythic costumes need new geometry.

Validation: outfit_wardrobe_match_test exercises the six Fiamma/Maestro selections,
save reload, Oracolo Signature, blocked mythic selection, challenge enforcement,
and the real match's build_athletes path plus the material read-back for three roles.
Oracolo base/signature were also rendered front and back with the Godot renderer.
