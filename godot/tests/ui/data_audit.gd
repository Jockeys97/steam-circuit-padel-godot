## data_audit.gd — UIR-04's contract audit over the UI data adapters.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/data_audit.gd
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/data_audit.gd -- --demo
##
## Same machine-readable contract as `res://tests/smoke_test.gd`:
## `ok <name>` / `FAIL <name>: expected …` / one `PASS n/n`, exit 0 on PASS.
##
## WHAT IT ASSERTS
##
##   1. a career, a history, a drill record and prefs written through the real public
##      seams (`ModesSave.save_career`, `record_match`, `save_drill_score`, `save_pref`)
##      into a TEMP store read back through the adapters, field by field — including the
##      reference's own aggregates (win rate `js/ui.js:1613`, trophies
##      `js/ui.js:1580`, the unlock count `js/ui.js:1653-1668`);
##   2. every locale key the adapters hand a screen resolves through the seam, and every
##      non-empty art path points at a file that exists;
##   3. the build answers are the gate's answers — and in the `--demo` run they are the
##      pinned ones (`js/build.js:36-52`: roster maestro+steamer, one arena, one mode,
##      difficulty medium);
##   4. no adapter calls the locale seam and none writes through the save contract
##      (source scan over `godot/src/ui/data/**`).
##
## CONSTRUCTED STATE, labeled: the profile this audit reads is written into a temp
## `SaveStore` under `user://uir04-data-audit*`; the real `user://save` profile is never
## opened for write, and the temp directories are removed at the end of the run. The
## `-- --demo` run is a real build-flag run (`godot/tests/build/BuildFlag.gd`), not a
## simulation of one.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const GateAdapter := preload("res://src/ui/data/DemoGateAdapter.gd")
const Art := preload("res://src/ui/data/UiArtPaths.gd")
const Store := preload("res://src/save/save_store.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Gate := preload("res://game/content_gate.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")

## The constructed profile's root (temp, removed at the end).
const TEMP_DIR := "user://uir04-data-audit"
const TEMP_DIR_EMPTY := "user://uir04-data-audit-empty"
## The two artefacts this audit reads a path convention for.
const ART_KINDS := ["athletes", "arenas", "modes"]
## Calls a read-only adapter must never make: the locale seam and every write of the
## save contract. A hit here is the finding; the audit prints file and line.
const LOCALE_MARKERS := ["Locale.t(", "UiStrings.t(", "preload(\"res://src/locale"]
const WRITE_MARKERS := [
	"save_career(", "save_pref(", "save_drill_score(", "save_tournament_round(",
	"record_match(", "write_group(", "write_history(", "write_drill_record(",
	"write_all(", "write_feedback(",
]

var _url_locale: Array = []
var _offenders_locale: Array = []
var _offenders_writes: Array = []
var _adapter_files: int = 0


func _initialize() -> void:
	var audit := AuditBase.new("data")
	_run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	var store := Store.new(TEMP_DIR)
	_clean(TEMP_DIR)
	_clean(TEMP_DIR_EMPTY)

	_round_trip(audit, store)
	_history(audit, store)
	_objectives(audit, store)
	_unlocks(audit, store)
	_drill(audit, store)
	_rows(audit, store)
	_lineup(audit, store)
	_settings(audit, store)
	_result_view(audit, store)
	_feedback(audit)
	_gate(audit)
	_source_rules(audit)
	_clean(TEMP_DIR)
	_clean(TEMP_DIR_EMPTY)
	audit.note("constructed state: the career, history, drill records and prefs above were written through the public seams into %s and removed at the end; the real user:// profile was never written" % TEMP_DIR)
	audit.note("the reference's third build label (`js/build.js` BUILD === beta, `js/ui.js:745`) has no port equivalent — `godot/tests/build/BuildFlag.gd` is one boolean, so `build()` answers demo|full and `betaBadge` is unreachable here: a finding for UIR-23, not a defect to fix in this ticket")
	audit.note("art paths are UIR-01's namespace (`godot/assets/ui/**`); this audit asserts that a non-empty path exists and never that an asset which has not landed is there, so a missing asset reads as an empty path")


# ---------------------------------------------------------------------------
# 1. The temp store, through the real seams
# ---------------------------------------------------------------------------

func _round_trip(audit: AuditBase, store: RefCounted) -> void:
	var career: Dictionary = CareerProgress.EMPTY_CAREER.duplicate(true)
	career["wins"] = 7
	career["losses"] = 3
	career["stars"] = 12
	career["trophies"] = 2
	career["season"] = 2
	career["matchIndex"] = 4
	var written: Dictionary = ModesSave.save_career(store, career)
	audit.check_true(bool(written["ok"]), "data/the_constructed_career_writes_through_the_public_seam")

	var stored: Dictionary = ModesSave.load_career(store)
	audit.check_eq(int(stored["wins"]), 7, "data/the_seam_reads_the_career_it_wrote")

	var summary: Dictionary = UiData.profile_summary(store)
	audit.check_eq(int(summary["wins"]), 7, "data/profile_summary_wins_is_the_saved_value")
	audit.check_eq(int(summary["losses"]), 3, "data/profile_summary_losses_is_the_saved_value")
	audit.check_eq(int(summary["seasons"]), 2, "data/profile_summary_carries_the_trophy_count_the_reference_labels_seasons")
	audit.check_eq(int(summary["stars"]), 12, "data/profile_summary_stars_is_the_saved_value")
	audit.check_eq(int(summary["total"]), 10, "data/profile_summary_total_is_wins_plus_losses")
	audit.check_eq(int(summary["win_rate"]), 70, "data/the_win_rate_is_the_reference_formula_round_wins_over_total")
	audit.check_eq(int(summary["season"]), 2, "data/profile_summary_carries_the_calendar_season")
	audit.check_eq(int(summary["match_index"]), 4, "data/profile_summary_carries_the_calendar_match_index")

	var other := Store.new(TEMP_DIR_EMPTY)
	audit.check_eq(int(UiData.profile_summary(other)["wins"]), 0, "data/a_different_store_is_read_afresh")
	audit.check_eq(int(UiData.profile_summary(store)["wins"]), 7, "data/the_first_store_still_reads_its_own_values")


func _history(audit: AuditBase, store: RefCounted) -> void:
	ModesSave.record_match(store, ModesSave.history_entry("career", "maestro", "officina", "rivale", "coop", "player", "6-4", 11, true, 2, 1700000000))
	ModesSave.record_match(store, ModesSave.history_entry("quick", "steamer", "clockwork", "ingegnere", "solo", "ai", "4-6", 11, false, 0, 1700000100))
	ModesSave.record_match(store, ModesSave.history_entry("tournament", "maestro", "orrery", "campione", "pvp", "player", "7-5", 11, false, 0, 1700000200))

	var rows: Array = UiData.history_entries(store)
	audit.check_eq(rows.size(), 3, "data/three_recorded_matches_read_back_three_rows")
	audit.check_eq(String(rows[0]["mode"]), "tournament", "data/history_is_newest_first")
	audit.check_eq(String(rows[0]["result"]), "win", "data/a_won_match_reads_as_a_win")
	audit.check_eq(String(rows[1]["result"]), "loss", "data/a_lost_match_reads_as_a_loss")
	audit.check_eq(String(rows[0]["score"]), "7-5", "data/the_score_line_is_carried")
	audit.check_eq(int(rows[0]["points_to_win"]), 11, "data/the_points_to_win_figure_is_carried")
	audit.check_true(bool(rows[0]["counts_as_trophy"]), "data/a_won_tournament_match_counts_as_a_trophy")
	audit.check_true(bool(rows[2]["counts_as_trophy"]), "data/the_stored_trophy_flag_is_carried")
	audit.check_eq(bool(rows[1]["counts_as_trophy"]), false, "data/a_lost_match_is_not_a_trophy")
	audit.check_eq(String(rows[2]["human_mode"]), "coop", "data/the_human_mode_id_is_carried")
	audit.check_eq(String(rows[2]["opponent"]), "rivale", "data/the_opponent_id_is_carried")
	audit.check_eq(String(rows[2]["athlete"]), "maestro", "data/the_athlete_id_is_carried")

	var history: Dictionary = UiData.history_summary(store)
	audit.check_eq(int(history["wins"]), 2, "data/history_summary_counts_the_two_wins")
	audit.check_eq(int(history["losses"]), 1, "data/history_summary_counts_the_one_loss")
	audit.check_eq(int(history["trophies"]), 2, "data/trophies_count_the_flag_and_the_won_tournament")
	audit.check_eq(int(history["entries"]), 3, "data/history_summary_counts_the_rows")
	audit.check_true(UiStrings.has("histWins"), "data/the_history_labels_the_screen_uses_resolve")


func _objectives(audit: AuditBase, store: RefCounted) -> void:
	var rows: Array = UiData.season_objectives(store)
	audit.check_ge(rows.size(), 1, "data/the_season_offers_at_least_one_objective")
	var seam: Array = CareerProgress.ensure_season_objectives(ModesSave.load_career(store))
	audit.check_eq(rows.size(), seam.size(), "data/the_objective_rows_are_the_seam_rows")

	var bad_keys: Array = []
	var bad_types: Array = []
	for row in rows:
		if not UiStrings.has(String(row["label_key"])):
			bad_keys.append(String(row["label_key"]))
		if typeof(row["progress"]) != TYPE_INT or typeof(row["target"]) != TYPE_INT or typeof(row["done"]) != TYPE_BOOL:
			bad_types.append(String(row["id"]))
	audit.check_eq(bad_keys, [], "data/every_objective_label_key_resolves")
	audit.check_eq(bad_types, [], "data/every_objective_row_carries_an_int_progress_target_and_a_bool_done")


func _unlocks(audit: AuditBase, store: RefCounted) -> void:
	var summary: Dictionary = UiData.unlock_summary(store)
	var athletes_with_unlock := _count_with_unlock(Frozen.athletes())
	var arenas_with_unlock := _count_with_unlock(Frozen.arenas())
	var outfits_with_challenge := 0
	for athlete in Frozen.athletes():
		for outfit in Tables.outfits_for_athlete(String((athlete as Dictionary).get("id", ""))):
			if (outfit as Dictionary).get("challenge", null) != null:
				outfits_with_challenge += 1

	audit.check_eq(int(summary["characters"]["total"]), athletes_with_unlock, "data/the_character_bucket_is_the_frozen_unlockable_count")
	audit.check_eq(int(summary["arenas"]["total"]), arenas_with_unlock, "data/the_arena_bucket_is_the_frozen_unlockable_count")
	audit.check_eq(int(summary["outfits"]["total"]), outfits_with_challenge, "data/the_outfit_bucket_is_the_challenge_gated_count")
	audit.check_eq(
		int(summary["total"]),
		athletes_with_unlock + arenas_with_unlock + outfits_with_challenge,
		"data/the_summary_total_is_the_three_buckets")
	var career: Dictionary = ModesSave.load_career(store)
	audit.check_eq(int(summary["done"]), _seam_unlocked_count(career), "data/the_done_count_is_the_seams_own_answer")
	audit.check_true(int(summary["done"]) <= int(summary["total"]), "data/the_done_count_cannot_exceed_the_total")
	audit.check_eq(String(summary["label_key"]), "profileUnlocksCount", "data/the_summary_key_is_the_reference_key")
	audit.check_true(UiStrings.has(String(summary["label_key"])), "data/the_summary_key_resolves")
	audit.report("unlocks done=%d/%d (characters %d, arenas %d, outfits %d)" % [
		int(summary["done"]), int(summary["total"]),
		athletes_with_unlock, arenas_with_unlock, outfits_with_challenge])

	# A career with nothing behind it unlocks strictly less, and the rows a screen reads
	# follow it: adapter behaviour, not a count that happens to agree.
	var bare := Store.new(TEMP_DIR_EMPTY)
	_clean(TEMP_DIR_EMPTY)
	ModesSave.save_career(bare, CareerProgress.EMPTY_CAREER.duplicate(true))
	var bare_summary: Dictionary = UiData.unlock_summary(bare)
	audit.check_eq(int(bare_summary["done"]), 0, "data/a_career_with_nothing_behind_it_unlocks_nothing")
	audit.check_true(int(bare_summary["done"]) < int(summary["done"]), "data/two_trophies_and_twelve_stars_unlock_more_than_nothing")
	audit.check_eq(int(bare_summary["total"]), int(summary["total"]), "data/the_total_does_not_move_with_the_career")

	var bare_unlocked: Array = []
	for row in UiData.athlete_rows(bare):
		if not bool(row["locked"]):
			bare_unlocked.append(String(row["id"]))
	var rich_unlocked: Array = []
	for row in UiData.athlete_rows(store):
		if not bool(row["locked"]):
			rich_unlocked.append(String(row["id"]))
	if BuildFlag.is_demo():
		audit.check_eq(bare_unlocked, ["maestro", "steamer"], "data/a_demo_fields_only_what_it_exposes_even_with_nothing_won")
		audit.check_eq(rich_unlocked, ["maestro", "steamer"], "data/a_demo_hides_the_athletes_the_career_unlocked")
	else:
		audit.check_eq(bare_unlocked, ["maestro", "pantera", "steamer", "fiamma"], "data/a_career_with_nothing_behind_it_fields_the_four_unconditioned_athletes")
		audit.check_eq(rich_unlocked.size(), 6, "data/two_trophies_and_twelve_stars_unlock_both_gated_athletes")
		audit.check_eq(rich_unlocked.size() - bare_unlocked.size(), 2, "data/the_career_unlocks_exactly_the_two_gated_athletes")


func _drill(audit: AuditBase, store: RefCounted) -> void:
	var exercise_id := String((Tables.drill_exercises()[0] as Dictionary).get("id", ""))
	ModesSave.save_drill_score(store, exercise_id, 9)
	var records: Dictionary = UiData.drill_records(store)
	var rows: Array = records["rows"]
	# The records screen lists what the PLAYER can play: the frozen rows plus the Godot-only
	# extras (`Tables.drill_catalog()`), in that order, so the frozen ones come first.
	audit.check_eq(rows.size(), Tables.drill_catalog().size(), "data/one_drill_row_per_catalog_exercise")
	audit.check_eq(String((rows[0] as Dictionary)["id"]), exercise_id, "data/the_frozen_exercises_lead_the_records")
	var first := {}
	for row in rows:
		if String(row["id"]) == exercise_id:
			first = row
	audit.check_eq(int(first.get("best", 0)), 9, "data/the_saved_drill_best_is_read_back")
	audit.check_eq(bool(first.get("played", false)), true, "data/a_played_exercise_reports_as_played")
	audit.check_eq(int(records["best_total"]), 9, "data/the_best_total_sums_the_records")
	var unplayed: Array = []
	for row in rows:
		if String(row["id"]) != exercise_id and (int(row["best"]) != 0 or bool(row["played"])):
			unplayed.append(String(row["id"]))
	audit.check_eq(unplayed, [], "data/an_exercise_never_played_reads_zero_and_unplayed")


# ---------------------------------------------------------------------------
# 2. The rows a screen renders
# ---------------------------------------------------------------------------

func _rows(audit: AuditBase, store: RefCounted) -> void:
	var career: Dictionary = ModesSave.load_career(store)
	_athlete_rows(audit, store, career)
	_arena_rows(audit, store, career)
	_mode_rows(audit, store)
	_art_convention(audit)


func _athlete_rows(audit: AuditBase, store: RefCounted, career: Dictionary) -> void:
	var rows: Array = UiData.athlete_rows(store)
	audit.check_eq(rows.size(), Frozen.athletes().size(), "data/one_athlete_row_per_frozen_athlete")

	var bad_keys: Array = []
	var bad_art: Array = []
	var bad_locks: Array = []
	var art_present := 0
	for row in rows:
		var id := String(row["id"])
		for field in ["name_key", "desc_key"]:
			if not UiStrings.has(String(row[field])):
				bad_keys.append("%s/%s" % [id, field])
		var path := String(row["art_path"])
		if path != "":
			art_present += 1
			if not FileAccess.file_exists(path):
				bad_art.append(path)
		var item: Dictionary = _athlete_of(id)
		var expected := GateAdapter.locked(id, "athlete") or not CareerRules.is_unlocked(item, career)
		if bool(row["locked"]) != expected:
			bad_locks.append(id)
		if bool(row["demo_locked"]) != GateAdapter.locked(id, "athlete"):
			bad_locks.append("%s/demo" % id)
	audit.check_eq(bad_keys, [], "data/every_athlete_locale_key_resolves")
	audit.check_eq(bad_art, [], "data/every_athlete_art_path_points_at_a_file_that_exists")
	audit.check_eq(bad_locks, [], "data/every_athlete_locked_flag_is_the_build_and_career_rule")
	audit.report("athlete art present %d/%d" % [art_present, rows.size()])


func _arena_rows(audit: AuditBase, store: RefCounted, career: Dictionary) -> void:
	var rows: Array = UiData.arena_rows(store)
	audit.check_eq(rows.size(), Frozen.arenas().size(), "data/one_arena_row_per_frozen_arena")
	var bad_keys: Array = []
	var bad_art: Array = []
	var bad_locks: Array = []
	var art_present := 0
	for row in rows:
		var id := String(row["id"])
		for field in ["name_key", "desc_key"]:
			if not UiStrings.has(String(row[field])):
				bad_keys.append("%s/%s" % [id, field])
		var path := String(row["art_path"])
		if path != "":
			art_present += 1
			if not FileAccess.file_exists(path):
				bad_art.append(path)
		var item: Dictionary = _arena_of(id)
		var expected := GateAdapter.locked(id, "arena") or not CareerRules.is_unlocked(item, career)
		if bool(row["locked"]) != expected:
			bad_locks.append(id)
	audit.check_eq(bad_keys, [], "data/every_arena_locale_key_resolves")
	audit.check_eq(bad_art, [], "data/every_arena_art_path_points_at_a_file_that_exists")
	audit.check_eq(bad_locks, [], "data/every_arena_locked_flag_is_the_build_and_career_rule")
	audit.report("arena art present %d/%d" % [art_present, rows.size()])


func _mode_rows(audit: AuditBase, store: RefCounted) -> void:
	var rows: Array = UiData.mode_rows(store)
	audit.check_eq(rows.size(), 3, "data/the_reference_has_three_mode_cards")
	var ids: Array = []
	var bad_keys: Array = []
	for row in rows:
		ids.append(String(row["id"]))
		for field in ["title_key", "desc_key", "tag_key", "locked_key"]:
			if not UiStrings.has(String(row[field])):
				bad_keys.append("%s/%s" % [String(row["id"]), field])
	audit.check_eq(ids, ["quick", "tournament", "career"], "data/the_mode_rows_are_in_the_reference_order")
	audit.check_eq(bad_keys, [], "data/every_mode_locale_key_resolves")
	audit.check_eq(bool(rows[0]["locked"]), not Gate.modes().has("quick"), "data/the_quick_card_locked_flag_is_the_build_answer")
	audit.check_eq(bool(rows[2]["locked"]), not Gate.modes().has("career"), "data/the_career_card_locked_flag_is_the_build_answer")
	var career_row: Dictionary = rows[2].get("career", {})
	audit.check_ge(int(career_row.get("matches", 0)), 1, "data/the_career_card_carries_the_calendar_length")
	audit.check_true(String(career_row.get("arena_id", "")) != "", "data/the_career_card_carries_the_calendar_arena")
	audit.check_true(String(career_row.get("rival_id", "")) != "", "data/the_career_card_carries_the_calendar_rival")
	audit.check_eq(int(career_row.get("season", 0)), 2, "data/the_career_card_carries_the_calendar_season")
	audit.check_eq(int(career_row.get("match_index", -1)), 4, "data/the_career_card_carries_the_calendar_match_index")


func _art_convention(audit: AuditBase) -> void:
	var bad: Array = []
	for id in _ids_of(Frozen.athletes()):
		if Art.candidate_for("athletes", id) != "res://assets/ui/athletes/%s.webp" % id:
			bad.append("athletes/%s" % id)
	for id in _ids_of(Frozen.arenas()):
		var candidate := Art.candidate_for("arenas", id)
		if candidate != "" and not candidate.begins_with("res://assets/ui/arenas/"):
			bad.append("arenas/%s" % id)
	audit.check_eq(bad, [], "data/the_art_convention_is_the_declared_namespace")
	audit.check_eq(Art.candidate_for("modes", "quick"), "res://assets/ui/modes/quick-match.webp", "data/the_quick_mode_art_stem_is_quick_match")
	audit.check_eq(Art.path_for("arenas", "nope"), "", "data/an_arena_with_no_art_name_answers_empty")
	audit.check_eq(Art.path_for("modes", "nope"), "", "data/an_unknown_mode_answers_empty")
	# 2026-09-25: Cathedral (and Forge) got their own cover; every frozen arena now has art.
	audit.check_eq(Art.candidate_for("arenas", "cattedrale"), "res://assets/ui/arenas/cattedrale-vapore.webp", "data/the_cathedral_has_its_own_cover")
	audit.report("art names known: arenas=%d/9 modes=3" % Art.named_ids("arenas").size())


# ---------------------------------------------------------------------------
# 3. Lineup, settings, result, feedback
# ---------------------------------------------------------------------------

func _lineup(audit: AuditBase, store: RefCounted) -> void:
	var lineup: Dictionary = UiData.lineup_defaults(store)
	var ids: Array = [String(lineup["playerMate"]), String(lineup["opponent"]), String(lineup["opponentMate"])]
	audit.check_true(String(lineup["playerMate"]) != "", "data/the_lineup_fills_the_team_mate_slot")
	audit.check_true(String(lineup["opponent"]) != "", "data/the_lineup_fills_the_opponent_slot")
	audit.check_true(String(lineup["opponentMate"]) != "", "data/the_lineup_fills_the_second_opponent_slot")
	audit.check_eq(_duplicates(ids), [], "data/the_three_slots_name_three_different_athletes")
	audit.check_eq(ids.has(String(lineup["player"])), false, "data/the_player_is_not_also_on_court_twice")
	audit.check_true(_ids_of(Frozen.athletes()).has(String(lineup["playerMate"])), "data/the_team_mate_is_a_frozen_athlete")

	ModesSave.save_pref(store, "lineup", {"playerMate": "steamer", "opponent": "pantera", "opponentMate": "colosso"})
	var again: Dictionary = UiData.lineup_defaults(store)
	audit.check_eq(String(again["playerMate"]), "steamer", "data/a_saved_lineup_slot_is_honoured")
	audit.check_eq(String(again["opponent"]), "pantera", "data/a_saved_opponent_slot_is_honoured")
	ModesSave.save_pref(store, "lineup", {"playerMate": "nope", "opponent": "", "opponentMate": ""})
	var patched: Dictionary = UiData.lineup_defaults(store)
	audit.check_ne(String(patched["playerMate"]), "nope", "data/an_unknown_saved_id_is_not_fielded")
	audit.check_true(_ids_of(Frozen.athletes()).has(String(patched["playerMate"])), "data/an_unknown_saved_id_falls_back_to_a_real_athlete")


func _settings(audit: AuditBase, store: RefCounted) -> void:
	ModesSave.save_pref(store, "lang", "it")
	ModesSave.save_pref(store, "reduceMotion", true)
	ModesSave.save_pref(store, "volume", 0.25)
	var snapshot: Dictionary = UiData.settings_snapshot(store)
	audit.check_eq(String(snapshot["language"]), "it", "data/the_saved_language_is_read")
	audit.check_eq(bool(snapshot["reduce_motion"]), true, "data/the_saved_reduce_motion_flag_is_read")
	audit.check_eq(float(snapshot["volume"]), 0.25, "data/the_saved_volume_is_read")
	audit.check_eq(bool(snapshot["colorblind"]), false, "data/an_untouched_pref_reads_the_schema_default")
	audit.check_eq(bool(snapshot["vibration"]), true, "data/the_vibration_default_survives")
	audit.check_eq(String(snapshot["control_mode"]), "semi", "data/the_control_mode_default_survives")
	audit.check_eq(int(snapshot["tournament_round"]), 0, "data/the_tournament_round_default_survives")


func _result_view(audit: AuditBase, store: RefCounted) -> void:
	var result := {
		"score": "6-4",
		"won": true,
		"pointsToWin": 11,
		"stats": {
			"pointsWon": {"player": 6, "ai": 4},
			"aces": {"player": 3, "ai": 3},
			"winners": {"player": 10, "ai": 7},
			"errors": {"player": 9, "ai": 5},
			"longestRally": 12,
			"rallyCount": 10,
			"totalRallyHits": 43,
		},
	}
	var view: Dictionary = UiData.result_view(result, store)
	audit.check_eq(String(view["score"]), "6-4", "data/the_score_line_reaches_the_view")
	audit.check_eq(bool(view["won"]), true, "data/the_win_flag_reaches_the_view")
	var rows: Array = view["stats_rows"]
	audit.check_eq(rows.size(), 4, "data/the_view_carries_the_four_compared_rows")
	var by_key := {}
	var bad_labels: Array = []
	for row in rows:
		by_key[String(row["key"])] = row
		if not UiStrings.has(String(row["label_key"])):
			bad_labels.append(String(row["label_key"]))
	audit.check_eq(bad_labels, [], "data/every_result_stat_label_key_resolves")
	audit.check_eq(String(by_key["pointsWon"]["better"]), "player", "data/more_points_reads_as_better_for_the_player")
	audit.check_eq(String(by_key["winners"]["better"]), "player", "data/more_winners_reads_as_better_for_the_player")
	audit.check_eq(String(by_key["errors"]["better"]), "opponent", "data/fewer_errors_reads_as_better_for_the_player")
	audit.check_eq(String(by_key["aces"]["better"]), "tie", "data/equal_figures_read_as_a_tie")
	audit.check_eq(int(view["longest_rally"]), 12, "data/the_longest_rally_figure_reaches_the_view")
	audit.check_eq(float(view["average_rally"]), 43.0 / 10.0, "data/the_average_rally_is_hits_over_rallies")
	audit.check_ge((view["objectives"] as Array).size(), 1, "data/the_view_carries_the_season_objectives")
	audit.check_eq((view["outfit_rows"] as Array).size(), 0, "data/a_career_that_won_no_outfit_carries_no_outfit_row")

	var career: Dictionary = ModesSave.load_career(store)
	var outfit_key := ""
	for athlete_id in Tables.outfits():
		for outfit in Tables.outfits()[athlete_id]:
			if (outfit as Dictionary).get("challenge", null) != null:
				outfit_key = String((outfit as Dictionary).get("unlockKey", ""))
				break
		if outfit_key != "":
			break
	audit.check_true(outfit_key != "", "data/the_frozen_outfit_table_offers_a_challenge_outfit")
	career["outfitsWon"] = {outfit_key: true}
	ModesSave.save_career(store, career)
	var won_rows: Array = UiData.outfit_unlock_rows(store)
	audit.check_eq(won_rows.size(), 1, "data/a_won_outfit_reads_back_as_one_row")
	audit.check_eq(String(won_rows[0]["unlock_key"]), outfit_key, "data/the_won_outfit_keeps_its_unlock_key")
	audit.check_true(String(won_rows[0]["athlete_id"]) != "", "data/the_won_outfit_names_its_athlete")
	audit.check_true(UiStrings.has(String(won_rows[0]["name_key"])), "data/the_won_outfit_name_key_resolves")


func _feedback(audit: AuditBase) -> void:
	var topics: Array = UiData.feedback_topics()
	audit.check_eq(topics.size(), 6, "data/the_reference_has_six_feedback_topics")
	var ids: Array = []
	var bad_keys: Array = []
	for topic in topics:
		ids.append(String(topic["id"]))
		if not UiStrings.has(String(topic["label_key"])):
			bad_keys.append(String(topic["label_key"]))
	audit.check_eq(ids, ["bug", "balance", "controls", "performance", "idea", "other"], "data/the_topic_ids_are_the_reference_data_values")
	audit.check_eq(bad_keys, [], "data/every_feedback_topic_label_resolves")


# ---------------------------------------------------------------------------
# 4. The build gate
# ---------------------------------------------------------------------------

func _gate(audit: AuditBase) -> void:
	var demo := BuildFlag.is_demo()
	audit.check_eq(GateAdapter.build(), "demo" if demo else "full", "data/the_adapter_reports_the_build_the_flag_reports")
	audit.check_eq(GateAdapter.build(), BuildFlag.label(), "data/the_build_label_is_the_ported_flag_label")
	audit.check_eq(GateAdapter.badge_visible(), demo, "data/the_badge_visibility_follows_the_demo_flag")

	var athletes: Array = GateAdapter.exposed_ids("athlete")
	var arenas: Array = GateAdapter.exposed_ids("arena")
	var modes: Array = GateAdapter.exposed_ids("mode")
	audit.check_eq(athletes, _ids_of(Gate.roster()), "data/the_adapter_exposes_what_the_gate_exposes")
	audit.check_eq(arenas, _ids_of(Gate.arenas()), "data/the_adapter_exposes_the_arenas_the_gate_exposes")
	audit.check_eq(modes, Gate.modes(), "data/the_adapter_exposes_the_modes_the_gate_exposes")
	audit.check_eq(GateAdapter.all_ids("athlete").size(), Frozen.athletes().size(), "data/the_full_athlete_list_is_the_frozen_table")
	audit.check_eq(GateAdapter.all_ids("arena").size(), Frozen.arenas().size(), "data/the_full_arena_list_is_the_frozen_table")

	if demo:
		audit.check_eq(athletes, ["maestro", "steamer"], "data/demo_exposes_maestro_and_steamer")
		audit.check_eq(arenas, ["clockwork"], "data/demo_exposes_one_arena")
		audit.check_eq(modes, ["quick"], "data/demo_exposes_one_mode")
		audit.check_eq(GateAdapter.difficulty_allowed("medium"), true, "data/demo_pins_medium")
		audit.check_eq(GateAdapter.difficulty_allowed("legend"), false, "data/demo_locks_the_other_tiers")
		audit.check_eq(GateAdapter.locked("colosso", "athlete"), true, "data/an_athlete_outside_the_demo_roster_is_locked")
		audit.check_eq(GateAdapter.locked("maestro", "athlete"), false, "data/an_athlete_inside_the_demo_roster_is_not_locked")
		audit.check_eq(GateAdapter.mode_locked("career"), true, "data/a_mode_outside_the_demo_grant_is_locked")
		audit.check_eq(GateAdapter.mode_locked("quick"), false, "data/the_demo_mode_is_not_locked")
		audit.check_eq(UiData.athlete_rows().size(), Frozen.athletes().size(), "data/the_demo_rows_list_the_whole_roster_and_lock_what_it_withholds")
	else:
		audit.check_eq(athletes.size(), 6, "data/a_full_build_exposes_the_whole_roster")
		audit.check_eq(arenas.size(), 9, "data/a_full_build_exposes_every_arena")
		audit.check_eq(modes.size(), 3, "data/a_full_build_exposes_every_mode")
		audit.check_eq(GateAdapter.difficulty_allowed("legend"), true, "data/a_full_build_allows_every_tier")
		audit.check_eq(GateAdapter.locked("colosso", "athlete"), false, "data/a_full_build_locks_no_athlete")
		audit.check_eq(GateAdapter.mode_locked("career"), false, "data/a_full_build_locks_no_mode")

	# The reference's own reading of an id the frozen tables do not hold
	# (`demoLocked`, `js/build.js:73-75`) — a demo locks it, a full build does not.
	audit.check_eq(GateAdapter.locked("nope", "athlete"), demo, "data/an_unknown_id_is_locked_only_in_a_demo")
	audit.check_eq(GateAdapter.locked("nope", "nonsense"), false, "data/an_unknown_kind_locks_nothing")
	audit.report("build=%s athletes=%d arenas=%d modes=%d difficulty_allowed=medium:%s legend:%s" % [
		GateAdapter.build(), athletes.size(), arenas.size(), modes.size(),
		str(GateAdapter.difficulty_allowed("medium")), str(GateAdapter.difficulty_allowed("legend"))])


# ---------------------------------------------------------------------------
# 5. Source rules the adapters keep
# ---------------------------------------------------------------------------

func _source_rules(audit: AuditBase) -> void:
	var scripts := _adapter_scripts()
	_adapter_files = scripts.size()
	audit.check_ge(scripts.size(), 3, "data/the_source_scan_finds_the_adapter_files")
	for path in scripts:
		var source := FileAccess.get_file_as_string(String(path))
		var lines := source.split("\n")
		for index in lines.size():
			var code := String(lines[index]).split("#")[0]
			for marker in LOCALE_MARKERS:
				if code.contains(marker):
					_offenders_locale.append("%s:%d %s" % [path, index + 1, marker])
			for marker in WRITE_MARKERS:
				if code.contains(marker):
					_offenders_writes.append("%s:%d %s" % [path, index + 1, marker])
	audit.check_eq(_offenders_locale, [], "data/no_adapter_calls_the_locale_seam")
	audit.check_eq(_offenders_writes, [], "data/no_adapter_writes_through_the_save_contract")
	audit.report("adapter source scan files=%d locale_hits=0 write_hits=0 markers=%d" % [
		_adapter_files, LOCALE_MARKERS.size() + WRITE_MARKERS.size()])


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _adapter_scripts() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://src/ui/data")
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".gd"):
			out.append("res://src/ui/data/".path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _clean(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)


func _athlete_of(id: String) -> Dictionary:
	for athlete in Frozen.athletes():
		if String((athlete as Dictionary).get("id", "")) == id:
			return athlete
	return {}


func _arena_of(id: String) -> Dictionary:
	for arena in Frozen.arenas():
		if String((arena as Dictionary).get("id", "")) == id:
			return arena
	return {}


static func _ids_of(items: Array) -> Array:
	var out: Array = []
	for item in items:
		out.append(String((item as Dictionary).get("id", "")))
	return out


static func _count_with_unlock(items: Array) -> int:
	var count := 0
	for item in items:
		if (item as Dictionary).get("unlock", null) != null:
			count += 1
	return count


## The audit's own reading of the three unlock economies, written out again here so the
## adapter is compared against the seams rather than against its own code path.
static func _seam_unlocked_count(career: Dictionary) -> int:
	var count := 0
	for athlete in Frozen.athletes():
		if (athlete as Dictionary).get("unlock", null) != null and CareerRules.is_unlocked(athlete, career):
			count += 1
	for arena in Frozen.arenas():
		if (arena as Dictionary).get("unlock", null) != null and CareerRules.is_unlocked(arena, career):
			count += 1
	for athlete in Frozen.athletes():
		for outfit in Tables.outfits_for_athlete(String((athlete as Dictionary).get("id", ""))):
			if (outfit as Dictionary).get("challenge", null) != null and CareerRules.is_unlocked(outfit, career):
				count += 1
	return count


static func _duplicates(ids: Array) -> Array:
	var seen := {}
	var out: Array = []
	for id in ids:
		if seen.has(id):
			out.append(String(id))
		seen[id] = true
	return out
