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
##   ModesSave.training_key(exercise_id, difficulty, attempts) -> String
##   ModesSave.training_best(store, exercise_id, difficulty, attempts) -> int
##   ModesSave.save_training_score(store, exercise_id, difficulty, attempts, score)
##   ModesSave.training_record_after(store, session, difficulty) -> Dictionary
##       The BOUNDED challenge's own record. The legacy `<exercise id>` key above is the
##       reference's "best score ever" and the old drills ran until the player left, so a
##       bounded 8-attempt score is NOT comparable with it: a fresh install that plays one
##       training run would otherwise look like a record was broken. Bounded scores
##       therefore live under their own stable key — `training_v1:<id>:<difficulty>:
##       <attempts>` — through the same `SaveStore.write_drill_record` door, so the record
##       policy (improvement-only) and the file format are unchanged. The legacy key keeps
##       its own meaning and is never rewritten by this path; the hub shows it, clearly
##       labelled, as the historical best.
##   ModesSave.load_history(store) -> Array
##   ModesSave.record_match(store, entry) -> Dictionary      newest first, cap 20
##   ModesSave.history_entry(...) -> Dictionary              the entry shape
##   ModesSave.tournament_round(store) -> int
##   ModesSave.save_tournament_round(store, round) -> Dictionary
##   ModesSave.save_pref(store, key, value) -> Dictionary
##   ModesSave.award_match_outfits(store, athlete_id, stats, won, ai_skill)
##       evaluates and persists the outfit challenges after any completed match;
##       this is the shared quick/tournament counterpart of the career finish path.
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
const Economy := preload("res://src/economy/economy_service.gd")

## The prefix of a bounded challenge record. Versioned so a future change to what a run
## measures can add `training_v2:` without reinterpreting v1 numbers.
const TRAINING_KEY_PREFIX := "training_v1"

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
	# A read-only access view: the wallet and bought outfits remain together in the
	# economy file. This transient key is never written into the career file.
	var purchased := {}
	for key in Economy.owned_outfit_keys(store):
		purchased[String(key)] = true
	career["outfitsPurchased"] = purchased
	return career


## `saveCareer(career)` (`js/ui.js:48-54`): the whole career object, written to
## the `career` group.
static func save_career(store, career: Dictionary) -> Dictionary:
	var persisted := career.duplicate(true)
	persisted.erase("outfitsPurchased")
	return store.write_group("career", persisted)


## The browser calls `awardOutfitChallenges` before branching by mode
## (`js/main.js:1472`): quick matches and tournament rounds therefore contribute
## to the same outfit progress as career matches.  Career mode keeps the mutation
## inside its larger atomic progression step; the two other match paths use this
## helper so the lazy `outfitsWon` / `athleteWins` fields are persisted identically.
static func award_match_outfits(store, athlete_id: String, stats: Dictionary, won: bool, ai_skill: float) -> Dictionary:
	var career := load_career(store)
	var outfits := CareerProgress.award_outfit_challenges(
		career, athlete_id, stats, won, ai_skill
	)
	var write: Dictionary = {}
	# A win always changes athleteWins, even when it unlocks no outfit yet. A loss
	# only needs a write when a stat-based challenge was completed.
	if won or not outfits.is_empty():
		write = save_career(store, career)
	return {
		"career": career,
		"outfits": outfits,
		"saved": write,
	}


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
# Training: the BOUNDED challenge's own records
# ---------------------------------------------------------------------------

## The stable key a bounded run's record lives under: the exercise, the training difficulty
## it was played at and the number of attempts its run lasts. Two runs are comparable only
## when all three match, which is exactly what the key says.
static func training_key(exercise_id: String, difficulty: String, attempts: int) -> String:
	return "%s:%s:%s:%d" % [TRAINING_KEY_PREFIX, exercise_id, difficulty, int(attempts)]


## The bounded record for one exercise/difficulty/run length, 0 when it was never played.
static func training_best(store, exercise_id: String, difficulty: String, attempts: int) -> int:
	return int(load_drill_records(store).get(training_key(exercise_id, difficulty, attempts), 0))


## Writes one bounded score through the save module's own improvement-only door. Same
## policy, same format, a different key.
static func save_training_score(store, exercise_id: String, difficulty: String, attempts: int, score: int) -> Dictionary:
	var key := training_key(exercise_id, difficulty, attempts)
	var result: Dictionary = store.write_drill_record(key, score)
	var skipped: bool = bool(result.get("skipped", false))
	return {
		"key": key,
		"best": training_best(store, exercise_id, difficulty, attempts),
		"written": bool(result.get("ok", false)) and not skipped,
		"skipped": skipped,
		"result": result,
	}


## The training session's own record step: writes the run's score under the bounded key and
## never touches the legacy one. `session.run_limit` is the run length the score was
## actually produced with, so the key cannot disagree with the drill that produced it.
static func training_record_after(store, session, difficulty: String) -> Dictionary:
	var exercise_id: String = String(session.exercise.get("id", ""))
	var attempts: int = int(session.run_limit)
	return save_training_score(store, exercise_id, difficulty, attempts, int(session.score))


## Every bounded record the save holds, keyed by its full key — the reader an audit uses to
## prove the legacy keys and the bounded ones are separate namespaces.
static func load_training_records(store) -> Dictionary:
	var out: Dictionary = {}
	for key in load_drill_records(store):
		if String(key).begins_with(TRAINING_KEY_PREFIX + ":"):
			out[String(key)] = int((load_drill_records(store) as Dictionary)[key])
	return out


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
