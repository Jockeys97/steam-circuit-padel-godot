## save_progression_audit.gd — the progression state round-trips through the
## EXISTING save module.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/save_progression_audit.gd
##
## No reference audit covers this: the browser persists through `localStorage`,
## which no headless test can exercise, so the promise "the progression survives a
## session" had no executable form on the reference side. Here it does.
##
## What is asserted, all of it through `godot/src/modes/modes_save.gd` and
## therefore through `SaveStore`:
##
##   - a career round-trips field for field, whole numbers reloading as ints
##     (`save_schema.gd`'s `normalize_numbers`), including `claimedObjectives`
##     (the map that stops a replayed season paying the same stars twice) and the
##     two fields the schema's defaults do not list (`outfitsWon`,
##     `athleteWins` — the finding `modes_save.gd` states);
##   - `is_unlocked` still answers correctly on a RELOADED career, so the persist
##     layer is not just storing bytes;
##   - the drill record writes only on improvement (`js/ui.js:219-230`) and the
##     session's best follows the persisted record (`js/main.js:2122-2124`);
##   - the history is newest-first and capped at 20 (`js/ui.js:1551`);
##   - `tournamentRound` round-trips through `prefs` without clobbering the other
##     preferences.
##
## The store is pointed at `user://modes-port-audit/` so the real profile under
## `user://save/` is never touched; the directory is removed at the end.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Store := preload("res://src/save/save_store.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

const DIR := "user://modes-port-audit"


## The only fields `ModesSave.drill_record_after` reads from a session. The real
## session is covered by `drill_audit.gd`; this audit is about the write path.
class FakeSession:
	var exercise: Dictionary = {}
	var score: int = 0
	var best: int = 0


func _initialize() -> void:
	var audit := AuditBase.new("save_progression")
	run(audit)
	_cleanup()
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	_cleanup()
	var store := Store.new(DIR)

	# --- the career, field for field ------------------------------------------
	var career := CareerProgress.empty_career()
	career["season"] = 4
	career["matchIndex"] = 2
	career["stars"] = 17
	career["trophies"] = 3
	career["wins"] = 9
	career["losses"] = 3
	career["seasonWins"] = 2
	career["bestSeason"] = 4
	career["finaleSeen"] = true
	career["seasonProgress"] = {"pointsWon": 27, "winners": 12, "smashWinners": 4, "errors": 3, "doubleFaults": 1, "longestRally": 14}
	career["claimedObjectives"] = {"1": ["winners", "winRally", "fewErrors"], "3": ["smashWins"]}
	career["outfitsWon"] = {"maestro:circuit": true, "pantera:legend": true}
	career["athleteWins"] = {"maestro": 4, "pantera": 2}
	career["equippedOutfits"] = {"maestro": "circuit"}

	var written := ModesSave.save_career(store, career)
	audit.check_true(bool(written["ok"]), "save_progression/career_write_succeeds")

	var loaded := ModesSave.load_career(store)
	var same := true
	for field in ModesSave.CAREER_FIELDS:
		same = same and loaded.has(field)
	audit.check_true(same, "save_progression/every_career_field_reloads")
	audit.check_eq(JSON.stringify(loaded), JSON.stringify(career), "save_progression/career_round_trips_byte_for_byte")
	audit.check_eq(typeof(loaded["season"]), TYPE_INT, "save_progression/season_reloads_as_an_int")

	# The two fields the schema's defaults do not list must still survive.
	audit.check_true(loaded.has("outfitsWon"), "save_progression/outfits_won_survives_the_round_trip")
	audit.check_true(loaded.has("athleteWins"), "save_progression/athlete_wins_survives_the_round_trip")

	# The rules must read the RELOADED career correctly.
	var outfit := Tables.outfit_by_unlock_key("maestro:circuit")
	audit.check_true(not outfit.is_empty(), "save_progression/outfit_found_for_the_unlock_check")
	audit.check_true(CareerRules.is_unlocked(outfit, loaded), "save_progression/unlocked_outfit_still_unlocked_after_reload")
	audit.check_eq(
		String(CareerRules.career_rival(int(loaded["season"]))["id"]),
		String(CareerRules.career_rival(4)["id"]),
		"save_progression/rival_resolves_from_the_reloaded_season",
	)

	# An older save without the two lazy fields loads, and the rules do not crash.
	var older := {"season": 2, "stars": 4}
	ModesSave.save_career(store, older)
	var reloaded_older := ModesSave.load_career(store)
	audit.check_eq(int(reloaded_older["season"]), 2, "save_progression/partial_save_keeps_its_values")
	audit.check_eq(int(reloaded_older["stars"]), 4, "save_progression/partial_save_keeps_its_stars")
	audit.check_true(reloaded_older.has("matchIndex"), "save_progression/partial_save_gains_defaults")

	# --- the drill record, improvement only -----------------------------------
	audit.check_eq(ModesSave.drill_best(store, "precision"), 0, "save_progression/no_drill_record_yet")
	var first := ModesSave.save_drill_score(store, "precision", 10)
	audit.check_true(bool(first["written"]), "save_progression/first_drill_score_is_written")
	audit.check_eq(int(first["best"]), 10, "save_progression/first_drill_best_is_10")
	var worse := ModesSave.save_drill_score(store, "precision", 5)
	audit.check_true(bool(worse["skipped"]), "save_progression/lower_score_is_skipped")
	audit.check_eq(ModesSave.drill_best(store, "precision"), 10, "save_progression/lower_score_keeps_the_record")
	var equal := ModesSave.save_drill_score(store, "precision", 10)
	audit.check_true(bool(equal["skipped"]), "save_progression/equal_score_is_skipped")
	var better := ModesSave.save_drill_score(store, "precision", 12)
	audit.check_true(bool(better["written"]), "save_progression/higher_score_is_written")
	audit.check_eq(ModesSave.drill_best(store, "precision"), 12, "save_progression/best_follows_the_improvement")
	audit.check_eq(ModesSave.drill_best(store, "rally"), 0, "save_progression/records_are_per_exercise")

	# `js/main.js:2122-2124`: the session's best follows the persisted record.
	var drill := _fake_session("precision", 15)
	ModesSave.drill_record_after(store, drill)
	audit.check_eq(int(drill.best), 15, "save_progression/session_best_updates_on_improvement")
	audit.check_eq(ModesSave.drill_best(store, "precision"), 15, "save_progression/record_follows_the_session")
	var losing := _fake_session("precision", 3)
	ModesSave.drill_record_after(store, losing)
	# Faithful to `js/main.js:2122-2124`: the branch is entered because the run
	# beat the SESSION's best, and the assignment takes what `saveDrillRecord`
	# returns — which, when the score did not beat the RECORD, is the record
	# itself. So the session's best becomes 15, not 3.
	audit.check_eq(int(losing.best), 15, "save_progression/session_best_takes_the_persisted_record")
	audit.check_eq(ModesSave.drill_best(store, "precision"), 15, "save_progression/record_untouched_on_a_worse_run")

	# --- the history: newest first, capped at 20 ------------------------------
	var first_entry := ModesSave.history_entry("career", "maestro", "officina", "ingegnere", "solo", "player", "11-4", 11, true, 1, 1700000000)
	var write := ModesSave.record_match(store, first_entry)
	audit.check_true(bool(write["ok"]), "save_progression/history_write_succeeds")
	audit.check_eq(ModesSave.load_history(store).size(), 1, "save_progression/history_has_one_entry")
	for i in range(1, 25):
		ModesSave.record_match(store, ModesSave.history_entry("quick", "pantera", "clockwork", "rivale", "solo", "ai", "3-11", 11, false, 0, 1700000000 + i))
	var history := ModesSave.load_history(store)
	audit.check_eq(history.size(), 20, "save_progression/history_is_capped_at_20")
	audit.check_eq(int(Dictionary(history[0])["ts"]), 1700000024, "save_progression/history_is_newest_first")
	audit.check_eq(int(Dictionary(history[19])["ts"]), 1700000005, "save_progression/history_keeps_the_newest_twenty")
	var kept_oldest := true
	for entry in history:
		kept_oldest = kept_oldest and int(Dictionary(entry)["ts"]) != 1700000000
	audit.check_true(kept_oldest, "save_progression/oldest_entry_was_dropped")

	# --- the tournament round, through prefs ----------------------------------
	audit.check_eq(ModesSave.tournament_round(store), 0, "save_progression/tournament_round_starts_at_zero")
	var round_write := ModesSave.save_tournament_round(store, 2)
	audit.check_true(bool(round_write["ok"]), "save_progression/tournament_round_write_succeeds")
	audit.check_eq(ModesSave.tournament_round(store), 2, "save_progression/tournament_round_round_trips")
	var profile := ModesSave.profile(store)
	audit.check_eq(String(Dictionary(profile["prefs"])["aiDifficulty"]), "easy", "save_progression/other_prefs_survive")

	audit.report("career_fields=%d" % ModesSave.CAREER_FIELDS.size())
	audit.report("store_dir=%s" % store.dir)


## A drill session stand-in carrying only what `drill_record_after` reads: the
## exercise and the run's score/best. The real session is covered by
## `drill_audit.gd`; this audit is about the write path.
static func _fake_session(exercise_id: String, score: int) -> FakeSession:
	var session := FakeSession.new()
	session.exercise = {"id": exercise_id}
	session.score = score
	session.best = 0
	return session


static func _cleanup() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(DIR)
