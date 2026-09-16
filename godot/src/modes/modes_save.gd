## modes_save.gd — where the modes' progression meets the SAVE MODULE.
##
## This file owns no file format. Every read and write goes through
## `godot/src/save/save_store.gd` (the port's offline save, described in
## `godot/src/save/README.md`), so the career payload, the drill records, the
## history and the tournament round land in exactly the five groups the browser
## reference persisted in `localStorage`:
##
##   | modes data                | group      | reference key      |
##   |---------------------------|------------|--------------------|
##   | career (season, stars...) | `career`   | `padel.career`     |
##   | drill records per exercise| `drill`    | `padel.drill`      |
##   | history entries           | `history`  | `padel.history`    |
##   | `tournamentRound`         | `prefs`    | `padel.prefs`      |
##
## Nothing here forks a format, and `godot/src/save/**` is not edited.
##
## API (a UI lane consumes this without reading its internals):
##
##   ModesSave.load_career(store) -> Dictionary
##   ModesSave.save_career(store, career) -> Dictionary      (write result)
##   ModesSave.load_drill_records(store) -> Dictionary       exercise id -> best
##   ModesSave.drill_best(store, exercise_id) -> int
##   ModesSave.save_drill_score(store, exercise_id, score) -> Dictionary
##       `{best, written, skipped}` — improvement-only, `js/ui.js:219-230`;
##       delegating to `SaveStore.write_drill_record`, which owns that policy.
##   ModesSave.drill_record_after(store, session) -> Dictionary
##       The drill loop's own rule (`js/main.js:2122-2124`): when the run beat the
##       SESSION's best, the session's best takes what `saveDrillRecord` returns —
##       and that is the persisted record, which may be higher than the run's own
##       score when the run did not beat the record. Reproduced as written, not
##       "normalised" into something tidier.
##   ModesSave.load_history(store) -> Array
##   ModesSave.record_match(store, entry) -> Dictionary      newest first, cap 20
##   ModesSave.history_entry(...) -> Dictionary              the entry shape
##   ModesSave.tournament_round(store) -> int
##   ModesSave.save_tournament_round(store, round) -> Dictionary
##   ModesSave.save_pref(store, key, value) -> Dictionary
##   ModesSave.profile(store) -> Dictionary                  all five groups
##   ModesSave.CAREER_FIELDS -> Array
##       The career payload's field list (`js/ui.js:12-36` plus the two the
##       reference creates lazily in `awardOutfitChallenges`, `js/ui.js:629-630`:
##       `outfitsWon` and `athleteWins`). The save module's
##       `SaveSchema.CAREER_DEFAULTS` carries the sixteen of `DEFAULT_CAREER`;
##       the two lazy ones survive a round trip because the store's merge only
##       supplies missing keys and never drops stored ones.
##
## A FINDING this file states rather than fixes: `SaveSchema.CAREER_DEFAULTS`
## (`godot/src/save/save_schema.gd:83-107`) does NOT list `outfitsWon` or
## `athleteWins`, because the reference's `DEFAULT_CAREER` does not either — they
## are created on first award (`js/ui.js:629-630`). A save written before any
## challenge was won therefore has no such keys, and `is_unlocked` reads them
## through `career.get("outfitsWon", {})`. Round-tripping is unaffected (verified
## in `godot/tests/modes/career_audit.gd`), so this lane does not ask for a
## schema change; the exact field list is reported instead.
extends RefCounted

const Store := preload("res://src/save/save_store.gd")
const Schema := preload("res://src/save/save_schema.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")

## `js/ui.js:12-36` field by field, plus `outfitsWon` / `athleteWins`
## (`js/ui.js:629-630`).
const CAREER_FIELDS: Array = [
	"season", "matchIndex", "wins", "losses", "trophies", "stars",
	"seasonObjectives", "seasonStars", "rivalStreak", "seasonWins",
	"seasonProgress", "claimedObjectives", "bestSeason", "finaleSeen",
	"unlockAll", "equippedOutfits", "outfitsWon", "athleteWins",
]


# ---------------------------------------------------------------------------
# Career
# ---------------------------------------------------------------------------

## The career as the rules layer wants it: the stored payload merged over the
## modes lane's own defaults, so a partial or older save never yields a career
## missing a field the rules read.
static func load_career(store) -> Dictionary:
	var raw: Variant = profile(store).get("career", null)
	var career: Dictionary = CareerProgress.EMPTY_CAREER.duplicate(true)
	if raw is Dictionary:
		for key in (raw as Dictionary):
			career[key] = (raw as Dictionary)[key]
	return career


## `saveCareer(career)` (`js/ui.js:48-54`): the whole career object, written to
## the `career` group.
static func save_career(store, career: Dictionary) -> Dictionary:
	return store.write_group("career", career)


# ---------------------------------------------------------------------------
# Drill records
# ---------------------------------------------------------------------------

## `loadDrillRecords()` (`js/ui.js:206-213`): exercise id -> best score.
static func load_drill_records(store) -> Dictionary:
	var raw: Variant = profile(store).get("drill", null)
	return raw if raw is Dictionary else {}


## `drillRecord(exerciseId)` (`js/ui.js:215-217`).
static func drill_best(store, exercise_id: String) -> int:
	return int(load_drill_records(store).get(exercise_id, 0))


## `saveDrillRecord(exerciseId, score)` (`js/ui.js:219-230`), policy included: a
## lower or equal score is not written.
static func save_drill_score(store, exercise_id: String, score: int) -> Dictionary:
	var result: Dictionary = store.write_drill_record(exercise_id, score)
	var skipped: bool = bool(result.get("skipped", false))
	return {
		"best": drill_best(store, exercise_id),
		"written": bool(result.get("ok", false)) and not skipped,
		"skipped": skipped,
		"result": result,
	}


## `js/main.js:2122-2124`:
##
##   if (drillState.score > drillState.best) {
##     drillState.best = saveDrillRecord(drillState.exercise.id, drillState.score);
##   }
##
## The session's own best is only touched when the run beat the persisted record.
static func drill_record_after(store, session) -> Dictionary:
	var exercise_id: String = String(session.exercise.get("id", ""))
	var stored := save_drill_score(store, exercise_id, int(session.score))
	if int(session.score) > int(session.best):
		session.best = maxi(int(session.best), int(stored["best"]))
	return stored


# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------

## `loadHistory()` (`js/ui.js:1540-1547`).
static func load_history(store) -> Array:
	var raw: Variant = profile(store).get("history", null)
	return raw if raw is Array else []


## `recordMatch(entry)` (`js/ui.js:1557-1561`): newest first, capped at 20 by
## `SaveStore.write_history` (`js/ui.js:1551`).
static func record_match(store, entry: Dictionary) -> Dictionary:
	var list := load_history(store)
	list.insert(0, entry)
	return store.write_history(list)


## The history entry's shape (`js/main.js:1399-1414`). Names are IDS, not display
## text: the reference resolves them with `t()` at record time, the port stores
## the ids the locale lane resolves at render time — the same convention
## `godot/src/sim/state.gd` uses for its events (`docs/.../simulation-port-
## boundary.md` §2, "localized text is not stored").
static func history_entry(
	mode: String,
	athlete_id: String,
	arena_id: String,
	opponent_id: String,
	human_mode: String,
	winner: String,
	score: String,
	points_to_win: int,
	trophy: bool,
	campaign_season: int,
	ts: int
) -> Dictionary:
	return {
		"ts": ts,
		"mode": mode,
		"humanMode": human_mode,
		"winner": winner,
		"score": score,
		"opponent": opponent_id,
		"athlete": athlete_id,
		"arena": arena_id,
		"pointsToWin": points_to_win,
		"trophy": trophy,
		"season": campaign_season,
	}


# ---------------------------------------------------------------------------
# Tournaments: the round lives in `prefs` (`js/main.js:1482` -> `savePrefs`)
# ---------------------------------------------------------------------------

static func tournament_round(store) -> int:
	var prefs: Variant = profile(store).get("prefs", null)
	if prefs is Dictionary:
		return int((prefs as Dictionary).get("tournamentRound", 0))
	return int(Schema.PREFS_DEFAULTS.get("tournamentRound", 0))


static func save_tournament_round(store, round: int) -> Dictionary:
	return save_pref(store, "tournamentRound", round)


## One preference, read-modify-write, through the save module.
static func save_pref(store, key: String, value: Variant) -> Dictionary:
	var raw: Variant = profile(store).get("prefs", null)
	var prefs: Dictionary = {}
	if raw is Dictionary:
		prefs = (raw as Dictionary).duplicate(true)
	else:
		prefs = (Schema.PREFS_DEFAULTS as Dictionary).duplicate(true)
	prefs[key] = value
	return store.write_group("prefs", prefs)


## Every group, with the save module's defaults applied (`SaveStore.read_all`).
static func profile(store) -> Dictionary:
	var read: Dictionary = store.read_all()
	var result: Variant = read.get("profile", null)
	return result if result is Dictionary else {}
