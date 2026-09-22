extends RefCounted
## Cosmetic mesh variants. Athlete identity, progression and simulation stay unchanged.
const VARIANTS := {
	&"maestro": {&"mythic": {
		"base": "res://assets/athletes/outfits/maestro/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/maestro/mythic/walking.glb",
		"motion_id": "maestro_mythic",
	}},
}

static func variant(athlete: StringName, outfit: StringName) -> Dictionary:
	return VARIANTS.get(athlete, {}).get(outfit, {})
