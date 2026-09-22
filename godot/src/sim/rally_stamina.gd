## Mirror of js/rally-stamina.js. No RNG: reuse existing shot assessment.
extends RefCounted

const FLOOR := 0.15
const THRESHOLD := 0.70
const MAX_SLOW := 0.25

static func fatigue(energy: float = 1.0) -> float:
	var t := clampf((THRESHOLD - energy) / (THRESHOLD - FLOOR), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func speed_factor(energy: float = 1.0) -> float:
	return 1.0 - MAX_SLOW * fatigue(energy)

static func assessment_energy(energy: float = 1.0) -> float:
	return 1.0 - 0.60 * fatigue(energy)

## Preserve well-timed, planted control shots; fatigue magnifies execution demands.
static func execution_energy(energy: float, charge: float, moving: float, timing: float, split: float, overhead: bool) -> float:
	var demand := clampf(charge * charge * 0.40 + moving * (1.0 - split) * 0.30 + (1.0 - timing) * 0.80 + (0.15 if overhead else 0.0), 0.0, 1.0)
	return 1.0 - 0.85 * fatigue(energy) * demand

static func shot_cost(variant: String = "", slice: bool = false, mode: String = "control") -> float:
	var cost := 0.04
	if variant.begins_with("smash"):
		cost = 0.10
	elif variant.contains("bandeja"):
		cost = 0.055
	elif variant.contains("vibora"):
		cost = 0.065
	elif slice or variant.contains("slice") or variant == "cut-volley":
		cost = 0.035
	elif variant in ["safe-drive", "chiquita", "lob", "defensive-lob", "globo"]:
		cost = 0.025
	return cost + (0.025 if mode == "power" else (0.01 if mode == "balanced" else 0.0))

static func effort_energy(energy: float, dt: float, movement: float, sprint: float, stamina: float = 1.0) -> float:
	var m := clampf(movement, 0.0, 1.0)
	var s := clampf(sprint, 0.0, 1.0)
	var resistance := clampf(stamina, 0.7, 1.5)
	var recovery := 0.004 * (1.0 - m) * resistance
	var drain := (0.002 + 0.008 * m + 0.016 * m * s) / resistance
	return clampf(energy + dt * (recovery - drain), FLOOR, 1.0)
