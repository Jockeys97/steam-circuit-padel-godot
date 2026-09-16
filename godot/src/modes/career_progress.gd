## career_progress.gd — the career PROGRESSION: the season total, the objective
## evaluation, the star arithmetic and the four season outcomes. Ported from
## `js/ui.js:91-192` (progress and awards), `js/ui.js:625-648` (outfit
## challenges) and `js/main.js:1421-1477` (the season outcome machine).
##
## Every function is PURE over a career dictionary: `career` is passed in and
## mutated in place, exactly as the reference mutates its `ui.career`. There is
## no storage call anywhere in this file — persistence goes through
## `godot/src/modes/modes_save.gd`, which hands the payload to the existing save
## module. That split is the reference's own: `js/ui.js` has the rules,
## `saveCareer` is the boundary.
##
## API (a UI lane consumes this without reading its internals):
##
##   CareerProgress.EMPTY_CAREER -> Dictionary
##       The 17-field starting career, `js/ui.js:12-36` (`DEFAULT_CAREER`). The
##       save module's `SaveSchema.CAREER_DEFAULTS` carries the same object;
##       this one is the modes lane's copy so the rules are usable with no save
##       directory present.
##   CareerProgress.match_progress(stats) -> Dictionary      `js/ui.js:91-100`
##   CareerProgress.accumulate(career, stats) -> Dictionary  `js/ui.js:106-117`
##   CareerProgress.season_progress(career) -> Dictionary    `js/ui.js:120-122`
##   CareerProgress.objective_met(def_id, target, progress) -> bool  `js/ui.js:124-128`
##   CareerProgress.objective_status(objective, progress) -> Dictionary  `js/ui.js:131-138`
##   CareerProgress.objectives_signature(objectives) -> String  `js/ui.js:58-60`
##   CareerProgress.ensure_season_objectives(career) -> Array  `js/ui.js:62-83`
##   CareerProgress.award_objectives(career, stats) -> Dictionary  `js/ui.js:144-179`
##       `{seasonDone: [id...], matchDone: bool, stars: int}` and the star total
##       already added to `career.stars` / `career.seasonStars`.
##   CareerProgress.reset_season_objectives(career) -> void   `js/ui.js:186-192`
##   CareerProgress.award_outfit_challenges(career, athlete_id, stats, won, ai_skill) -> Array
##       `js/ui.js:625-648`; returns the outfits won by THIS match.
##   CareerProgress.pre_match_trophy(career, mode, won, round) -> bool
##       The history entry's `trophy` flag, computed BEFORE the season advances
##       (`js/main.js:1395-1398`): a season won, or the tournament final won.
##   CareerProgress.apply_career_match(career, won) -> Dictionary
##       `js/main.js:1427-1471`: `career.wins/losses`, `seasonWins`,
##       `rivalStreak`, `matchIndex`, then — on the third match — the season
##       outcome. Returns `{outcome, seasonWon, trophiesGained, seasonStarted,
##       seasonEnded}` where `outcome` is one of `finale`, `trophy`, `promoted`,
##       `repeat` (`js/main.js:1454-1464`) or `""` while the season is still
##       running.
##
## The star rule this file must keep, verbatim from `js/ui.js:157-164`: a season
## objective pays one star, ONCE per season. `career.claimedObjectives` is
## remembered across a season replay, so losing on purpose cannot farm the same
## three stars again — `scripts/career-audit.mjs:195-199` is the assertion that
## holds this.
extends RefCounted

const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

## `DEFAULT_CAREER` (`js/ui.js:12-36`), field for field.
const EMPTY_CAREER: Dictionary = {
	"season": 1,
	"matchIndex": 0,
	"wins": 0,
	"losses": 0,
	"trophies": 0,
	"stars": 0,
	"seasonObjectives": [],
	"seasonStars": 0,
	"rivalStreak": 0,
	"seasonWins": 0,
	"seasonProgress": {
		"pointsWon": 0,
		"winners": 0,
		"smashWinners": 0,
		"errors": 0,
		"doubleFaults": 0,
		"longestRally": 0,
	},
	"claimedObjectives": {},
	"bestSeason": 1,
	"finaleSeen": false,
	"unlockAll": false,
	"equippedOutfits": {},
}


## A fresh career. A deep copy every time: the reference returns
## `{ ...DEFAULT_CAREER }` and the caller mutates it.
static func empty_career() -> Dictionary:
	return EMPTY_CAREER.duplicate(true)


# ---------------------------------------------------------------------------
# The season total (`js/ui.js:91-122`)
# ---------------------------------------------------------------------------

## `matchProgress(stats)` (`js/ui.js:91-100`): the match's stats reduced to the
## flat `metric -> value` map the objectives are measured on.
static func match_progress(stats: Dictionary) -> Dictionary:
	return {
		"pointsWon": _side(stats, "pointsWon"),
		"winners": _side(stats, "winners"),
		"smashWinners": _side(stats, "smashWinners"),
		"errors": _side(stats, "errors"),
		"doubleFaults": _side(stats, "doubleFaults"),
		"longestRally": int(stats.get("longestRally", 0)),
	}


## `accumulateSeasonProgress(stats)` (`js/ui.js:106-117`): sums or keeps the
## worst case per `SEASON_METRIC_AGG`, writes it back on the career, returns it.
static func accumulate(career: Dictionary, stats: Dictionary) -> Dictionary:
	var totals: Dictionary = CareerRules.empty_season_progress()
	var stored: Variant = career.get("seasonProgress", null)
	if stored is Dictionary:
		for key in stored:
			totals[key] = stored[key]
	var match := match_progress(stats)
	for metric in CareerRules.season_metric_agg():
		var value: int = int(match.get(metric, 0))
		if String(CareerRules.season_metric_agg()[metric]) == "max":
			totals[metric] = maxi(int(totals.get(metric, 0)), value)
		else:
			totals[metric] = int(totals.get(metric, 0)) + value
	career["seasonProgress"] = totals
	return totals


## `seasonProgress()` (`js/ui.js:120-122`): the total even before a match.
static func season_progress(career: Dictionary) -> Dictionary:
	var totals: Dictionary = CareerRules.empty_season_progress()
	var stored: Variant = career.get("seasonProgress", null)
	if stored is Dictionary:
		for key in stored:
			totals[key] = stored[key]
	return totals


# ---------------------------------------------------------------------------
# Objectives (`js/ui.js:58-192`)
# ---------------------------------------------------------------------------

## `objectivesSignature(objectives)` (`js/ui.js:58-60`): `id:target` joined.
static func objectives_signature(objectives: Array) -> String:
	var parts: Array = []
	for objective in objectives:
		if objective is Dictionary:
			# `str()`, not `String()`: the target is an int and Godot 4 has no
			# `String` constructor for one (`String(4)` is a runtime error).
			parts.append("%s:%s" % [String(objective.get("id", "")), str(objective.get("target", ""))])
	return "|".join(parts)


## `objectiveMet(defId, target, progress)` (`js/ui.js:124-128`). `unit === "max"`
## objectives are satisfied by staying at or below the target, the others by
## reaching it.
static func objective_met(def_id: String, target: int, progress: Dictionary) -> bool:
	var defs: Dictionary = CareerRules.objective_defs()
	if not defs.has(def_id):
		return false
	var definition: Dictionary = defs[def_id]
	var metric: String = String(definition.get("metric", ""))
	var value: int = int(progress.get(metric, 0))
	if String(definition.get("unit", "")) == "max":
		return value <= target
	return value >= target


## `objectiveStatus(objective, progress)` (`js/ui.js:131-138`).
static func objective_status(objective: Dictionary, progress: Dictionary) -> Dictionary:
	var defs: Dictionary = CareerRules.objective_defs()
	var def_id: String = String(objective.get("id", ""))
	var metric: String = String((defs.get(def_id, {}) as Dictionary).get("metric", ""))
	return {
		"done": objective_met(def_id, int(objective.get("target", 0)), progress),
		"progress": int(progress.get(metric, 0)),
		"target": int(objective.get("target", 0)),
	}


## `ensureSeasonObjectives()` (`js/ui.js:62-83`). Regenerates when the stored
## triple is empty OR no longer matches the signature the current season
## produces (a retuned target must not survive in a save), and preserves the
## `claimed` flags so a regeneration cannot hand out stars twice.
static func ensure_season_objectives(career: Dictionary) -> Array:
	var expected: Array = CareerRules.season_objectives(int(career.get("season", 1)))
	var stored: Variant = career.get("seasonObjectives", null)
	var stored_list: Array = stored if stored is Array else []
	var must_regenerate: bool = stored_list.is_empty() \
		or objectives_signature(stored_list) != objectives_signature(expected)
	if must_regenerate:
		var claimed := _claimed_for(career, int(career.get("season", 1)))
		var rebuilt: Array = []
		for objective in expected:
			var entry: Dictionary = objective.duplicate()
			entry["done"] = false
			entry["claimed"] = claimed.has(String(objective.get("id", "")))
			rebuilt.append(entry)
		career["seasonObjectives"] = rebuilt
		career["seasonStars"] = 0
		return rebuilt
	return stored_list


## `awardObjectives(state)` (`js/ui.js:144-179`). Called once at the end of a
## career match; `stats` is `state.stats`.
static func award_objectives(career: Dictionary, stats: Dictionary) -> Dictionary:
	var result := {"seasonDone": [], "matchDone": false, "stars": 0}
	if stats.is_empty():
		return result
	var season: int = int(career.get("season", 1))
	var match_index: int = int(career.get("matchIndex", 0))

	# L'obiettivo bonus vive dentro il singolo match: si valuta su quello.
	var bonus: Dictionary = CareerRules.match_objective(season, match_index)
	if objective_met(String(bonus["id"]), int(bonus["target"]), match_progress(stats)):
		result["matchDone"] = true
		result["stars"] = int(result["stars"]) + 1

	# Gli obiettivi di stagione si valutano sul totale accumulato, e una stella
	# per obiettivo si prende una volta per stagione.
	var totals := accumulate(career, stats)
	var claimed := _claimed_for(career, season)
	for objective in ensure_season_objectives(career):
		if not objective_met(String(objective["id"]), int(objective["target"]), totals):
			continue
		objective["done"] = true
		var id := String(objective["id"])
		if claimed.has(id):
			continue
		claimed[id] = true
		result["seasonDone"].append(id)
		result["stars"] = int(result["stars"]) + 1
	_store_claimed(career, season, claimed)

	career["stars"] = int(career.get("stars", 0)) + int(result["stars"])
	career["seasonStars"] = int(career.get("seasonStars", 0)) + int(result["stars"])
	return result


## `resetSeasonObjectives()` (`js/ui.js:186-192`): the season restarts, the stars
## already taken do not (`claimedObjectives` survives).
static func reset_season_objectives(career: Dictionary) -> void:
	career["seasonObjectives"] = []
	career["seasonStars"] = 0
	career["seasonProgress"] = CareerRules.empty_season_progress()
	ensure_season_objectives(career)


## `awardOutfitChallenges(state, won)` (`js/ui.js:625-648`). `ai_skill` is
## `state.ai.skill`; `athlete_id` is `state.athlete.id`. Returns the outfits won
## by this match, in table order.
static func award_outfit_challenges(career: Dictionary, athlete_id: String, stats: Dictionary, won: bool, ai_skill: float) -> Array:
	if athlete_id == "":
		return []
	if not (career.get("outfitsWon") is Dictionary):
		career["outfitsWon"] = {}
	if not (career.get("athleteWins") is Dictionary):
		career["athleteWins"] = {}
	var won_map: Dictionary = career["outfitsWon"]
	var wins_map: Dictionary = career["athleteWins"]
	if won:
		wins_map[athlete_id] = int(wins_map.get(athlete_id, 0)) + 1

	var contesto := {
		"stats": stats,
		"won": won,
		"skill": ai_skill,
		"athleteWins": int(wins_map.get(athlete_id, 0)),
	}
	var vinti: Array = []
	for outfit in Tables.outfits_for_athlete(athlete_id):
		if outfit.get("challenge") == null:
			continue
		var key := String(outfit.get("unlockKey", ""))
		if bool(won_map.get(key, false)):
			continue
		if not CareerRules.outfit_challenge_met(outfit["challenge"], contesto):
			continue
		won_map[key] = true
		vinti.append(outfit)
	return vinti


# ---------------------------------------------------------------------------
# The season outcome machine (`js/main.js:1395-1477`)
# ---------------------------------------------------------------------------

## The history entry's `trophy` flag (`js/main.js:1395-1398`), computed on the
## state BEFORE the season advances: the third career win of a season, or the
## tournament final won.
static func pre_match_trophy(career: Dictionary, mode: String, won: bool, round: int = 0) -> bool:
	if not won:
		return false
	if mode == "career":
		return int(career.get("seasonWins", 0)) + 1 >= CareerRules.career_matches() \
			and int(career.get("matchIndex", 0)) + 1 >= CareerRules.career_matches()
	if mode == "tournament":
		return round == 2
	return false


## `js/main.js:1427-1471`. Mutates the career; the season advances even when the
## match is lost (`matchIndex` grows either way — losing used to cost nothing).
static func apply_career_match(career: Dictionary, won: bool) -> Dictionary:
	var outcome := {
		"outcome": "",
		"seasonWon": false,
		"trophiesGained": 0,
		"seasonStarted": int(career.get("season", 1)),
		"seasonEnded": false,
	}
	if won:
		career["wins"] = int(career.get("wins", 0)) + 1
		career["seasonWins"] = int(career.get("seasonWins", 0)) + 1
		career["rivalStreak"] = maxi(0, int(career.get("rivalStreak", 0))) + 1
	else:
		career["losses"] = int(career.get("losses", 0)) + 1
		career["rivalStreak"] = mini(0, int(career.get("rivalStreak", 0))) - 1
	career["matchIndex"] = int(career.get("matchIndex", 0)) + 1

	if int(career["matchIndex"]) < CareerRules.career_matches():
		return outcome

	outcome["seasonEnded"] = true
	var vinte: int = int(career.get("seasonWins", 0))
	# Il trofeo dell'ultima stagione chiude il circuito: e' il finale, e si vede
	# una volta sola.
	var finale: bool = vinte >= CareerRules.career_matches() \
		and int(career.get("season", 1)) >= CareerRules.career_final_season()
	if vinte >= CareerRules.career_matches():
		career["trophies"] = int(career.get("trophies", 0)) + 1
		career["season"] = int(career.get("season", 1)) + 1
		outcome["seasonWon"] = true
		outcome["trophiesGained"] = 1
		outcome["outcome"] = "finale" if finale and not bool(career.get("finaleSeen", false)) else "trophy"
		if finale:
			career["finaleSeen"] = true
	elif vinte >= CareerRules.career_promotion_wins():
		career["season"] = int(career.get("season", 1)) + 1
		outcome["outcome"] = "promoted"
	else:
		outcome["outcome"] = "repeat"
	career["bestSeason"] = maxi(int(career.get("bestSeason", 1)), int(career.get("season", 1)))
	career["matchIndex"] = 0
	career["seasonWins"] = 0
	reset_season_objectives(career)
	return outcome


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## The player's side of a stats entry (`js/game.js` stats are `{player, ai}`).
static func _side(stats: Dictionary, key: String) -> int:
	var entry: Variant = stats.get(key, null)
	if entry is Dictionary:
		return int((entry as Dictionary).get("player", 0))
	return int(entry) if entry != null else 0


## `career.claimedObjectives[season]` as a set keyed by objective id. The
## reference keys the map by the season number; JSON gives back string keys, so
## both spellings are read.
static func _claimed_for(career: Dictionary, season: int) -> Dictionary:
	var out: Dictionary = {}
	var claimed: Variant = career.get("claimedObjectives", null)
	if not (claimed is Dictionary):
		return out
	var table: Dictionary = claimed
	for key in [str(season), season]:
		if table.has(key) and table[key] is Array:
			for id in table[key]:
				out[String(id)] = true
	return out


static func _store_claimed(career: Dictionary, season: int, claimed: Dictionary) -> void:
	var table: Variant = career.get("claimedObjectives", null)
	var out: Dictionary = table if table is Dictionary else {}
	# The reference writes the JS numeric key, which JSON serialises as a string.
	out[str(season)] = claimed.keys()
	career["claimedObjectives"] = out
