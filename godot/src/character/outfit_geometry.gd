extends RefCounted
## Cosmetic mesh variants. Athlete identity, progression and simulation stay unchanged.
const VARIANTS := {
	&"fiamma": {&"mythic": {
		"base": "res://assets/athletes/outfits/fiamma/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/fiamma/mythic/walking.glb",
		"motion_id": "fiamma_mythic",
	}},
	&"pantera": {&"mythic": {
		"base": "res://assets/athletes/outfits/pantera/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/pantera/mythic/walking.glb",
		"motion_id": "pantera_mythic",
	}},
	&"steamer": {&"mythic": {
		"base": "res://assets/athletes/outfits/steamer/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/steamer/mythic/walking.glb",
		"motion_id": "steamer_mythic",
	}},
	&"oracolo": {&"mythic": {
		"base": "res://assets/athletes/outfits/oracolo/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/oracolo/mythic/walking.glb",
		"motion_id": "oracolo_mythic",
	}},
	&"colosso": {&"mythic": {
		"base": "res://assets/athletes/outfits/colosso/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/colosso/mythic/walking.glb",
		"motion_id": "colosso_mythic",
	}},
	&"maestro": {&"mythic": {
		"base": "res://assets/athletes/outfits/maestro/mythic/running.glb",
		"walk": "res://assets/athletes/outfits/maestro/mythic/walking.glb",
		"motion_id": "maestro_mythic",
	}},
}

static func variant(athlete: StringName, outfit: StringName) -> Dictionary:
	return VARIANTS.get(athlete, {}).get(outfit, {})
