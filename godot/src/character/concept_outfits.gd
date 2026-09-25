extends RefCounted
## Godot-only kits. The generated 2D catalogue stays frozen; these rows are
## appended only by playable selectors. Their purchase gate is Godot-only.

const KITS := {
	&"fiamma": {
		&"solar_sprint": {
			"name_key": "outfitSolarSprint",
			"colors": ["#d94e42", "#f2dfbd"],
			"style": 1,
			"panel": "#f2dfbd",
			"piping": "#b77742",
			"targets": {
				"torso_a": "#d94e42", "torso_b": "#f2dfbd",
				"hip_a": "#d94e42", "hip_b": "#f2dfbd",
				"foot_a": "#d94e42", "foot_b": "#f2dfbd",
			},
		},
	},
	&"maestro": {
		&"polar_ace": {
			"name_key": "outfitPolarAce",
			"colors": ["#aebac8", "#20477d"],
			"style": 2,
			"panel": "#20477d",
			"piping": "#b7793f",
			"targets": {
				"torso_a": "#aebac8", "torso_b": "#20477d",
				"hip_a": "#aebac8", "hip_b": "#20477d",
				"foot_a": "#aebac8", "foot_b": "#20477d",
			},
		},
	},
}


static func ids(athlete_id: StringName) -> Array:
	return (KITS.get(athlete_id, {}) as Dictionary).keys()


static func record(athlete_id: StringName, outfit_id: StringName) -> Dictionary:
	return (KITS.get(athlete_id, {}) as Dictionary).get(outfit_id, {})


static func catalogue_record(athlete_id: StringName, outfit_id: StringName) -> Dictionary:
	var kit := record(athlete_id, outfit_id)
	if kit.is_empty():
		return {}
	return {
		"id": String(outfit_id),
		"name_key": kit["name_key"],
		"unlock_key": "%s:%s" % [athlete_id, outfit_id],
		"colors": (kit["colors"] as Array).duplicate(),
		"has_challenge": false,
		"has_sprites": false,
	}


static func menu_rows(athlete_id: String) -> Array:
	var out := []
	for outfit_id in ids(StringName(athlete_id)):
		var kit := record(StringName(athlete_id), outfit_id)
		out.append({
			"id": String(outfit_id),
			"athleteId": athlete_id,
			"nameKey": kit["name_key"],
			"unlockKey": "%s:%s" % [athlete_id, outfit_id],
			"colors": (kit["colors"] as Array).duplicate(),
			"challenge": null,
			"unlock": null,
			"shopOnly": true,
		})
	return out
