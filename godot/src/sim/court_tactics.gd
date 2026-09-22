## Pure tactical preferences. Counterattack extensions are Godot-only. No RNG.
extends RefCounted

## A low contact reached while stretching/running cannot be driven as deep as
## a planted contact. Continuous, bounded choice of trajectory, not an error roll.
static func containment(height: float, lateral_reach: float, moving: float, skill: float) -> float:
	var low := clampf((38.0 - height) / 26.0, 0.0, 1.0)
	var stretch := clampf((lateral_reach - 0.45) / 0.55, 0.0, 1.0)
	var effort := maxf(stretch, clampf(moving, 0.0, 1.0) * 0.75)
	return low * effort * (1.0 - clampf(skill, 0.0, 1.0) * 0.25)

static func style(athlete_id: String) -> Dictionary:
	if athlete_id in ["fiamma", "pantera"]:
		return {"id": "attack", "lob": -0.04, "smash": 0.04, "net_depth": 62.0}
	if athlete_id in ["oracolo", "steamer"]:
		return {"id": "patient", "lob": 0.06, "smash": -0.03, "net_depth": 94.0}
	return {"id": "balanced", "lob": 0.0, "smash": 0.0, "net_depth": 70.0}

static func cover_lane(active_x: float, mate_x: float, left: float, right: float) -> float:
	var width := right - left
	var centre := (left + right) * 0.5
	# No lane flips while the controlled player hovers around the centre line.
	var cover_right := mate_x >= centre
	if active_x < centre - width * 0.08:
		cover_right = true
	elif active_x > centre + width * 0.08:
		cover_right = false
	return left + width * (0.72 if cover_right else 0.28)

static func safe_cover_y(active_x: float, active_y: float, mate_x: float, mate_y: float, target_x: float, target_y: float, bottom: float) -> float:
	# Pass behind, rather than through, a nearby human. No collision/input lock.
	var crossing := (mate_x - active_x) * (target_x - active_x) <= 0.0
	if crossing and absf(mate_y - active_y) < 90.0:
		if active_y + 68.0 > bottom - 42.0:
			return active_y - 68.0
		return maxf(target_y, active_y + 68.0)
	return target_y
