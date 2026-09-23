## mode_tables.gd — the FROZEN game-modes tables, generated from `js/**`.
##
## API (a UI lane consumes this without reading the rest of the directory):
##
##   ModeTables.data() -> Dictionary          the whole generated document
##   ModeTables.career() -> Dictionary        the career block
##   ModeTables.career_matches() -> int       CAREER_MATCHES, `js/data.js:765`
##   ModeTables.career_points_to_win() -> int CAREER_POINTS_TO_WIN, `js/data.js:766`
##   ModeTables.career_promotion_wins() -> int CAREER_PROMOTION_WINS, `js/data.js:767`
##   ModeTables.career_final_season() -> int  CAREER_FINAL_SEASON, `js/data.js:853`
##   ModeTables.career_ramp() -> Dictionary   CAREER_RAMP, `js/data.js:872-883`
##   ModeTables.season_metric_agg() -> Dictionary   SEASON_METRIC_AGG, `js/data.js:775-782`
##   ModeTables.objective_defs() -> Dictionary      OBJECTIVE_DEFS, `js/data.js:806-813`
##   ModeTables.unlock_code() -> String       UNLOCK_CODE, `js/data.js:700`
##   ModeTables.outfits() -> Dictionary       ATHLETE_OUTFITS, `js/data.js:515-554`
##   ModeTables.outfits_for_athlete(id) -> Array    `outfitsForAthlete`, `js/data.js:556-558`
##   ModeTables.outfit_by_unlock_key(key) -> Dictionary or {}  (`js/data.js:799-804`)
##   ModeTables.drill_exercises() -> Array    DRILL_EXERCISES, `js/drill.js:53-71`
##   ModeTables.drill_exercise(id) -> Dictionary    `exerciseById`, `js/drill.js:73-75`
##   ModeTables.drill_catalog() -> Array      the frozen rows plus the Godot-only ones
##                                            (`drill_extras.gd`), for the drill screen
##   ModeTables.drill_catalog_ids() -> Array[String]
##   ModeTables.drill_target_r() -> float     TARGET_R, `js/drill.js:20`
##   ModeTables.drill_bullseye() -> float     BULLSEYE, `js/drill.js:21`
##   ModeTables.drill_squash_flat() -> float  SQUASH_FLAT, `js/drill.js:38`
##   ModeTables.drill_squash_low() -> float   SQUASH_LOW, `js/drill.js:39`
##   ModeTables.drill_freeze() -> float       FREEZE, `js/drill.js:47`
##
## `res://src/modes/data/modes.json` is a mechanical serialisation produced by
## `tools/modes-port/extract-modes.mjs` from `js/data.js` and `js/drill.js` — the
## frozen reference (commit 2979588). Nothing here is typed by hand: the numeric
## constants come from the source text of `js/drill.js`, the tables from the
## imports, and the document records the sha256 of both source files.
##
## A missing key is loud (`_require`) rather than a silent default, because a
## silently-defaulted season count or target radius is a re-tuned game.
##
## Godot's JSON parser returns every number as a float; the ints this module
## returns are converted at the boundary so callers compare ints with ints.
extends RefCounted

const DATA_PATH := "res://src/modes/data/modes.json"
const GENERATOR := "tools/modes-port/extract-modes.mjs"
const DrillExtras := preload("res://src/modes/drill_extras.gd")

static var _data: Dictionary = {}


## The whole generated document. Loaded once; the file is small (tables only).
static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(DATA_PATH)
		if text.is_empty():
			push_error("mode_tables.gd: cannot read %s — run `node %s`" % [DATA_PATH, GENERATOR])
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("mode_tables.gd: %s is not a JSON object" % DATA_PATH)
			return {}
		_data = parsed
	return _data


## sha256 of the two reference files the document was generated from.
static func source_sha256() -> Dictionary:
	return data().get("sourceSha256", {})


## The career block: matches, pointsToWin, promotionWins, finalSeason, ramp,
## seasonMetricAgg, objectiveDefs, unlockCode.
static func career() -> Dictionary:
	return _require("career")


static func career_matches() -> int:
	return int(career()["matches"])


static func career_points_to_win() -> int:
	return int(career()["pointsToWin"])


static func career_promotion_wins() -> int:
	return int(career()["promotionWins"])


static func career_final_season() -> int:
	return int(career()["finalSeason"])


static func career_ramp() -> Dictionary:
	return career()["ramp"]


static func season_metric_agg() -> Dictionary:
	return career()["seasonMetricAgg"]


static func objective_defs() -> Dictionary:
	return career()["objectiveDefs"]


static func unlock_code() -> String:
	return String(career()["unlockCode"])


static func relock_code() -> String:
	return "ALELU"


## `ATHLETE_OUTFITS` (`js/data.js:515-554`), keyed by athlete id. Every entry
## carries the `unlockKey` / `athleteId` pair `js/data.js:799-804` adds, plus its
## `challenge` (or `null`) and its `unlock` (the pre-outfit wall, kept because
## `is_unlocked` still reads it for non-outfit items).
static func outfits() -> Dictionary:
	return _require("outfits")


## `outfitsForAthlete(athleteId)` (`js/data.js:556-558`): the list, `[]` for an
## unknown athlete.
static func outfits_for_athlete(athlete_id: String) -> Array:
	return outfits().get(athlete_id, [])


## The outfit with this `unlockKey`, or `{}`. `js/data.js:799-804`.
static func outfit_by_unlock_key(key: String) -> Dictionary:
	for athlete_id in outfits():
		for outfit in outfits()[athlete_id]:
			if String(outfit.get("unlockKey", "")) == key:
				return outfit
	return {}


## `DRILL_EXERCISES` (`js/drill.js:53-71`): id, feed (`flat` / `lob` / `serve`),
## `rivals`, `targets`, `kinds`. The FROZEN reference's own four rows, and nothing else:
## this is what the reference has, and what the generated document's drift check covers.
static func drill_exercises() -> Array:
	return _require("drill")["exercises"]


## Every exercise this build can offer: the frozen table's own rows, then the Godot-only
## ones (`drill_extras.gd` explains why they are not in the generated document). The
## frozen list is never edited here and its drift check still has one answer; this is the
## single place the two are joined, so a caller that lists exercises for a PLAYER asks
## this one, and a caller that audits the REFERENCE asks `drill_exercises()`.
static func drill_catalog() -> Array:
	var out: Array = []
	for row in drill_exercises():
		out.append(row)
	for row in DrillExtras.exercises():
		out.append(row)
	return out


## The catalog's own ids, in catalog order.
static func drill_catalog_ids() -> Array[String]:
	var out: Array[String] = []
	for row in drill_catalog():
		out.append(String((row as Dictionary).get("id", "")))
	return out


## `exerciseById(id)` (`js/drill.js:73-75`): the exercise, falling back to the
## first one for an unknown id, exactly as the reference does. The search covers the
## Godot-only rows too, so `return` resolves while an unknown id still falls back to the
## reference's own first exercise.
static func drill_exercise(exercise_id: String) -> Dictionary:
	var exercises: Array = drill_catalog()
	for exercise in exercises:
		if String(exercise.get("id", "")) == exercise_id:
			return exercise
	return exercises[0] if exercises.size() > 0 else {}


static func drill_target_r() -> float:
	return float(_require("drill")["targetR"])


static func drill_bullseye() -> float:
	return float(_require("drill")["bullseye"])


static func drill_squash_flat() -> float:
	return float(_require("drill")["squashFlat"])


static func drill_squash_low() -> float:
	return float(_require("drill")["squashLow"])


static func drill_freeze() -> float:
	return float(_require("drill")["freeze"])


## Loud access: a key the generator did not write is a port bug, never a default.
static func _require(key: String) -> Dictionary:
	var doc := data()
	if not doc.has(key):
		push_error("mode_tables.gd: %s has no '%s' block — regenerate with `node %s`" % [DATA_PATH, key, GENERATOR])
		return {}
	var value: Variant = doc[key]
	return value if value is Dictionary else {}
