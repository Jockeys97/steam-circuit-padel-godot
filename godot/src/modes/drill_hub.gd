## drill_hub.gd — the training hub's model: the eight exercises, grouped, with the goal,
## the success rule, the controls and the record a page shows beside them.
##
## WHY IT EXISTS. Two screens present the training hub — the recreated
## `godot/src/ui/screens/DrillScreen.gd` (the default `--ui=new` route) and the ported
## `godot/game/mode_screen.gd` (the `--ui=legacy` route and the mode harness). Both must
## name the exercises, group them and describe them IDENTICALLY, and neither may invent a
## fact: this module is the single join of the two runtime tables
## (`mode_tables.drill_catalog()` + `drill_objective.gd`) with the locale layer, so a card
## says what the drill actually grades.
##
## WHAT IT IS NOT. It runs nothing and scores nothing: the session, the scoring module and
## the engine own every number. `detail()` reads the persisted best through `ModesSave`
## (write-only-on-improvement, unchanged) and everything else from the tables.
##
## IT ADDS NO STRINGS. Names and prose resolve through `drill_text.gd`, which asks the
## reference's generated table first and this build's `drill_strings.json` for the ids the
## reference does not own — in the current locale, with the port's own fallback chain.
extends RefCounted

const Tables := preload("res://src/modes/mode_tables.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const DrillObjective := preload("res://src/modes/drill_objective.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Locale := preload("res://src/locale/locale.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")

## The reference's own drill difficulties, in its own order (`index.html:381-385`). The
## rows are the same four words the quick-match tiers use, which is what makes them the
## honest choice for a training AI profile.
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard", "legend"]
const DIFFICULTY_LABEL_KEYS := {
	"easy": "diffEasy",
	"medium": "diffMedium",
	"hard": "diffHard",
	"legend": "diffLegend",
}
## The difficulty a run starts on when nothing chose one.
const DEFAULT_DIFFICULTY := "easy"


## The exercise's card: what a screen draws in the grid, and nothing else. The prose is
## resolved in the locale asked for (default: the current one).
static func card(exercise_id: String, lang: String = "") -> Dictionary:
	var row: Dictionary = Tables.drill_exercise(exercise_id)
	var id := String(row.get("id", ""))
	var objective := DrillObjective.for_exercise(id)
	return {
		"id": id,
		"group": String(objective.get("group", "")),
		"name": DrillText.exercise_name(id, lang),
		"goal": DrillText.t(String(objective.get("goal_key", "")), {}, lang),
		"watch": DrillText.t(String(objective.get("watch_key", "")), {}, lang),
		"attempts": DrillObjective.attempts_for(id),
	}


## The whole catalog as cards, in the catalog's own order (the frozen four, then this
## build's four).
static func cards(lang: String = "") -> Array:
	var out: Array = []
	for row in Tables.drill_catalog():
		out.append(card(String((row as Dictionary).get("id", "")), lang))
	return out


## The catalog grouped into the three families the page shows, in `GROUPS` order. Card
## order inside a family is the catalog's own order, so a family never re-shuffles itself
## between two mounts.
static func groups(lang: String = "") -> Array:
	var out: Array = []
	for group in DrillObjective.GROUPS:
		var members: Array = []
		for entry in cards(lang):
			if String((entry as Dictionary).get("group", "")) == String(group):
				members.append(entry)
		out.append({
			"id": String(group),
			"label_key": String(DrillObjective.GROUP_LABEL_KEYS.get(String(group), "")),
			"label": DrillText.t(String(DrillObjective.GROUP_LABEL_KEYS.get(String(group), "")), {}, lang),
			"cards": members,
		})
	return out


## Everything the detail panel shows for one exercise: the name, the goal, the measurable
## success rule, what is scored, the controls, the records, the run length and the hint line.
##
## TWO RECORDS, ON PURPOSE. `best` is the BOUNDED challenge's record for the run the player
## is about to play — `training_v1:<id>:<difficulty>:<attempts>`, the only number comparable
## with the score this run will produce. `historical_best` is the legacy `<id>` record: the
## old drills ran until the player left (`js/drill.js`), so that number measures a different
## thing and the page shows it as historical rather than as this challenge's best.
static func detail(exercise_id: String, store = null, difficulty: String = "", lang: String = "") -> Dictionary:
	var id := String(Tables.drill_exercise(exercise_id).get("id", ""))
	var objective := DrillObjective.for_exercise(id)
	var records: Dictionary = ModesSave.load_drill_records(store) if store != null else {}
	var attempts := DrillObjective.attempts_for(id)
	var level := seed_difficulty(difficulty)
	var controls: Array = []
	for control in DrillObjective.controls_for(id):
		var row: Dictionary = control
		var label_id := String(row.get("label", ""))
		controls.append({
			"key": String(row.get("key", "")),
			"label_id": label_id,
			"text": "%s · %s" % [String(row.get("key", "")), DrillText.t(label_id, {}, lang)],
		})
	return {
		"id": id,
		"group": String(objective.get("group", "")),
		"name": DrillText.exercise_name(id, lang),
		"desc": DrillText.t(DrillText.exercise_desc_key(id), {}, lang),
		"hint": DrillText.t(DrillText.exercise_hint_key(id), {}, lang),
		"goal": DrillText.t(String(objective.get("goal_key", "")), {}, lang),
		"success": DrillText.t(String(objective.get("success_key", "")), {}, lang),
		"scores": DrillText.t(String(objective.get("scores_key", "")), {}, lang),
		"watch": DrillText.t(String(objective.get("watch_key", "")), {}, lang),
		"controls": controls,
		"best": ModesSave.training_best(store, id, level, attempts) if store != null else 0,
		"historical_best": int(records.get(id, 0)),
		"training_key": ModesSave.training_key(id, level, attempts),
		"difficulty": level,
		"attempts": attempts,
	}


## The exercise ids the hub offers, in catalog order.
static func exercise_ids() -> Array[String]:
	return Tables.drill_catalog_ids()


static func first_id() -> String:
	var ids := exercise_ids()
	return ids[0] if not ids.is_empty() else ""


## True when the catalog carries the id — the question both screens ask before accepting a
## choice from the mouse or the pad.
static func has(exercise_id: String) -> bool:
	return exercise_ids().has(exercise_id)


## The training difficulties, validated against the reference's own four.
static func difficulties() -> Array[String]:
	return DIFFICULTIES.duplicate()


## The difficulty the run starts on, seeded from the STORED `aiDifficulty` when it is one
## of the four (`js/main.js:2162`, read-only) and otherwise the first.
static func seed_difficulty(stored: String) -> String:
	return stored if DIFFICULTIES.has(stored) else DEFAULT_DIFFICULTY


static func difficulty_label(difficulty: String, lang: String = "") -> String:
	return DrillText.t(String(DIFFICULTY_LABEL_KEYS.get(difficulty, "")), {}, lang)


## The AI profile a training run at this difficulty plays against. The reference's drill
## difficulty carries the same four words as the quick-match tiers, and
## `CareerRules.ai_for_match` is the module that owns that mapping — so this asks it rather
## than keeping a second copy of the table. Nothing here writes a preference.
static func ai_profile(difficulty: String) -> Dictionary:
	var wanted := seed_difficulty(difficulty)
	return CareerRules.ai_for_match("quick", 0, wanted)


## The screen each route hands the match when the player leaves a run: the training hub
## they came from. The recreated route lives under the router (`Main.tscn` owns it), the
## ported one is its own scene.
const RETURN_SCENE_ROUTED := "res://game/Main.tscn"
const RETURN_SCENE_PORTED := "res://game/ModeScreen.tscn"
