## drill_objective.gd — what each drill ASKS the player to do, and how the run is bounded.
##
## WHY THIS IS NOT THE EXERCISE TABLE. `drill_extras.gd` (and the frozen `modes.json`)
## declare what the ENGINE needs to run an exercise: feed, rivals, targets, kinds,
## formation. This file declares what the PLAYER needs to read: which family the exercise
## belongs to, the one-sentence goal, the measurable success rule, what is scored, which
## controls matter, and how many attempts one run lasts. `drill_hub.gd` joins the two.
##
## ONE OWNER PER FACT. A screen retypes none of it: the hub model is the only place the
## two tables meet, and `drill_session.gd` asks THIS file for the run length so the hub's
## "8 attempts" and the session's own bound cannot disagree.
##
## THE FROZEN TABLE IS NOT TOUCHED. The reference's four rows get their objective metadata
## here, next to the Godot-only ones, so the generated document keeps its four rows and
## its drift check keeps meaning exactly what it says.
##
## EVERY FIELD IS AN ID OR A NUMBER. No prose lives here: the strings are resolved by the
## locale layer for the reference's own exercises and by `drill_strings.json` +
## `drill_text.gd` for the ones this build adds, in Italian and English.
extends RefCounted

const Tables := preload("res://src/modes/mode_tables.gd")
const DrillExtras := preload("res://src/modes/drill_extras.gd")

## The three families the hub groups the catalog into, in the order the page shows them.
const GROUPS: Array[String] = ["technique", "defence", "match_play"]
const GROUP_LABEL_KEYS := {
	"technique": "drillGroupTechnique",
	"defence": "drillGroupDefence",
	"match_play": "drillGroupMatchPlay",
}

## The run length of one training run when the exercise does not say otherwise.
const DEFAULT_ATTEMPTS := 8
## The hard ceiling the session accepts from this table: a row that asked for a longer run
## would be a re-tuned session, not an exercise.
const MAX_ATTEMPTS := 24

## The controls, as the reference's OWN legend triples (`godot/src/input/strings.gd:LEGEND`,
## `index.html:243-257`): a KEY and the label id that belongs to that same row, never a key
## borrowed from another one. The hub renders `"<key> · <label>"`.
##
## THE PORT'S REAL MAPPING WINS OVER THE LEGEND'S WORDING where the two disagree, because a
## hint that names the wrong key is worse than no hint (`godot/game/input_map.gd:10-16`):
##
##   - the LEFT stick moves AND aims: while a shot button is held the athlete stops and the
##     left stick becomes the absolute aim (`input_map.gd:245` sets `analogAim` from it);
##   - the RIGHT stick is only ever the directional switch (`input_map.gd:235`), never the aim;
##   - the right trigger feeds `input["sprint"]`, which the simulation reads as the shot's
##     PRECISION (`sim.gd:2930`, `:3022`) and which zeroes `paddle.sprinting` (`:3055`) — so
##     training does NOT label RT "sprint", and does not advertise RT at all: none of the eight
##     exercises asks for it.
##
## A control an exercise does not need is simply absent. What remains is verified by the key
## and the simulation: A drives, X slices, Y lobs, B is the special, LB switches, LT is the
## split step, RB is the technical modifier (`input_map.gd:187`), D-PAD calls the pair tactic,
## A+A smashes.
const CONTROL_KEYS := {
	"move": {"key": "LS", "label": "moveLbl"},
	## The reference's own `aimLbl` row belongs to the RIGHT stick, whose label reads
	## "Directional switch" — pairing that text with LS would name the wrong control. The left
	## stick's aim gets this build's own string instead (`drill_strings.json`), so the row says
	## what the key does.
	"aim": {"key": "LS", "label": "drillControlAim"},
	"drive": {"key": "A", "label": "driveLbl"},
	"slice": {"key": "X", "label": "sliceLbl"},
	"lob": {"key": "Y", "label": "lobLbl"},
	"special": {"key": "B", "label": "specialLbl"},
	"switch": {"key": "LB", "label": "switchLbl"},
	"splitStep": {"key": "LT", "label": "splitStepLbl"},
	"technical": {"key": "RB", "label": "technicalLbl"},
	"tactics": {"key": "D-PAD", "label": "tacticsLbl"},
	"smash": {"key": "A+A", "label": "smashLbl"},
}

## One entry per exercise the build offers — the frozen four and the four Godot-only ones.
## `group` is one of `GROUPS`; the three `*_key` ids are resolved through the locale layer
## or this build's own drill strings; `controls` are `CONTROL_KEYS` names.
const OBJECTIVES := {
	"precision": {
		"group": "technique",
		"goal_key": "drill_precision_goal",
		"success_key": "drill_precision_success",
		"scores_key": "drill_precision_scores",
		"watch_key": "drill_precision_watch",
		"controls": ["drive", "aim"],
		"attempts": 8,
	},
	"smash": {
		"group": "technique",
		"goal_key": "drill_smash_goal",
		"success_key": "drill_smash_success",
		"scores_key": "drill_smash_scores",
		"watch_key": "drill_smash_watch",
		"controls": ["smash", "lob"],
		"attempts": 8,
	},
	"serve": {
		"group": "technique",
		"goal_key": "drill_serve_goal",
		"success_key": "drill_serve_success",
		"scores_key": "drill_serve_scores",
		"watch_key": "drill_serve_watch",
		"controls": ["drive", "aim"],
		"attempts": 8,
	},
	"return": {
		"group": "defence",
		"goal_key": "drill_return_goal",
		"success_key": "drill_return_success",
		"scores_key": "drill_return_scores",
		"watch_key": "drill_return_watch",
		"controls": ["splitStep", "drive"],
		"attempts": 8,
	},
	"rally": {
		"group": "defence",
		"goal_key": "drill_rally_goal",
		"success_key": "drill_rally_success",
		"scores_key": "drill_rally_scores",
		"watch_key": "drill_rally_watch",
		"controls": ["drive", "move", "aim"],
		"attempts": 8,
	},
	"glass_recovery": {
		"group": "defence",
		"goal_key": "drill_glass_recovery_goal",
		"success_key": "drill_glass_recovery_success",
		"scores_key": "drill_glass_recovery_scores",
		"watch_key": "drill_glass_recovery_watch",
		"controls": ["move", "lob", "drive"],
		"attempts": 8,
	},
	"net_play": {
		"group": "match_play",
		"goal_key": "drill_net_play_goal",
		"success_key": "drill_net_play_success",
		"scores_key": "drill_net_play_scores",
		"watch_key": "drill_net_play_watch",
		"controls": ["smash", "technical", "move"],
		"attempts": 8,
	},
	"doubles_tactics": {
		"group": "match_play",
		"goal_key": "drill_doubles_tactics_goal",
		"success_key": "drill_doubles_tactics_success",
		"scores_key": "drill_doubles_tactics_scores",
		"watch_key": "drill_doubles_tactics_watch",
		"controls": ["tactics", "switch", "drive"],
		"attempts": 8,
	},
}


## The objective metadata of one exercise, or `{}` for an id no row declares — a loud
## empty answer rather than a default the caller could score against.
static func for_exercise(exercise_id: String) -> Dictionary:
	var raw: Variant = OBJECTIVES.get(exercise_id, null)
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


## The family an exercise belongs to, `""` when nothing declares it.
static func group_of(exercise_id: String) -> String:
	return String(for_exercise(exercise_id).get("group", ""))


## The run length of one exercise, clamped to `MAX_ATTEMPTS`. A missing row answers the
## default so an exercise added with a row and no objective still terminates.
static func attempts_for(exercise_id: String) -> int:
	var declared := int(for_exercise(exercise_id).get("attempts", DEFAULT_ATTEMPTS))
	if declared <= 0:
		return DEFAULT_ATTEMPTS
	return mini(declared, MAX_ATTEMPTS)


## Every control the exercise asks the player to use, as `{key, label}` rows. An unknown
## control name is skipped rather than printed: the audit fails on that instead.
static func controls_for(exercise_id: String) -> Array:
	var out: Array = []
	for name in for_exercise(exercise_id).get("controls", []):
		var row: Variant = CONTROL_KEYS.get(String(name), null)
		if row is Dictionary:
			out.append((row as Dictionary).duplicate(true))
	return out


## The exercises the catalog offers that have NO objective row, and the ids this table
## declares that the catalog does not offer. Both are port defects, and an audit asks.
static func mismatches() -> Dictionary:
	var catalog := Tables.drill_catalog_ids()
	var missing: Array = []
	var extra: Array = []
	for id in catalog:
		if not OBJECTIVES.has(String(id)):
			missing.append(String(id))
	for id in OBJECTIVES.keys():
		if not catalog.has(String(id)):
			extra.append(String(id))
	return {"missing": missing, "extra": extra}


## True when the objective's own fields are the shape the hub and the audit expect: a
## declared group, three resolvable-sounding ids and a usable run length. Ids are checked
## for shape, not for resolution — resolution is the locale layer's question and the hub
## audit asks it there.
static func well_formed(exercise_id: String) -> bool:
	var row := for_exercise(exercise_id)
	if row.is_empty():
		return false
	if not GROUPS.has(String(row.get("group", ""))):
		return false
	for field in ["goal_key", "success_key", "scores_key", "watch_key"]:
		var value := String(row.get(field, ""))
		if value == "" or not value.begins_with("drill_"):
			return false
	if (row.get("controls", []) as Array).is_empty():
		return false
	return attempts_for(exercise_id) > 0
