## screen_drill_audit.gd — UIR-18's contract audit: the drill screen in a router.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. the router mounts the screen and the screen declares its own facts;
##   2. the four exercises are the drill table's own (`js/drill.js:53-71` via
##      `ModeTables.drill_exercises()`), in the table's order, labelled with the table's
##      own `drill_<id>_name` ids, and only a known one can be selected;
##   3. the chrome follows the choice exactly as `syncDrillChrome` does
##      (`js/main.js:2146-2185`): the subtitle is the exercise's `desc` id and the
##      instructions line is its `hint` id;
##   4. the four metric boxes are the exercise's own four (`DrillScoring.metrics`), labels
##      included, and the values are the **persisted** record's — proved by writing a
##      record through `ModesSave` and reading the boxes back;
##   5. the difficulty segmented control is independent of the persisted preference:
##      choosing one leaves `aiDifficulty` in the profile untouched, and changing the
##      exercise keeps the difficulty (`js/main.js:2160-2166`);
##   6. the records are re-read when the screen is entered again (the reference re-reads
##      on every render);
##   7. start() writes the pending-mode seam the mount reads and, in a dry run, changes
##      no scene;
##   8. a language flip moves every visible string the two tables differ on;
##   9. zero prose literals in `DrillScreen.gd`, and the screen carries no drill rule of
##      its own — the metric keys come from `DrillScoring`, which the audit names in the
##      source rather than trusting the render;
##  10. the declared capture states walk, and each one is observable.
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://uir18-drill-audit`) and removes it
## again.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/DrillScreen.gd")
const ScreenScene := preload("res://src/ui/screens/DrillScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const Config := preload("res://game/match_config.gd")
const SaveStore := preload("res://src/save/save_store.gd")

const SCREEN_PATH := "res://src/ui/screens/DrillScreen.gd"
const TEMP_DIR := "user://uir18-drill-audit"
const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME := Vector2(1280, 720)
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"drillTitle\")\n## a comment quoting \"prose in a comment\"\n"
const PLACED_RECORD := 7

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("screen_drill")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "ScreenDrillAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _mount(audit)
	await _exercises(audit)
	await _difficulty(audit)
	await _metrics(audit)
	await _records(audit)
	await _start(audit)
	await _strings(audit)
	await _captures(audit)
	_literal_scan(audit)
	audit.report("temp store: %s — the real user:// profile was never written" % TEMP_DIR)


func _screen() -> Node:
	return _router.active_screen()


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "drill/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "drill/all_thirteen_slots_register")
	audit.check_true(_router.register("drill", ScreenScene), "drill/the_scene_registers_under_the_drill_id")
	audit.check_eq(_router.go_to("drill"), true, "drill/go_to_mounts_the_screen")
	audit.check_eq(_router.active_id(), "drill", "drill/the_screen_is_active")
	var screen: Node = _screen()
	audit.check_true(screen is ScreenClass, "drill/the_mounted_scene_carries_DrillScreen_gd")
	audit.check_true(screen.theme != null, "drill/the_scene_mounts_the_theme")
	screen.set_store(_store)
	audit.check_eq(screen.store().dir, TEMP_DIR, "drill/the_audit_store_is_the_temp_one")
	await process_frame
	audit.check_eq(screen.screen_id(), "drill", "drill/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "menu", "drill/the_declared_return_is_the_router_own")
	audit.check_eq(screen.back_target(), Router.back_target_of("drill"), "drill/the_return_is_not_hardcoded")
	audit.check_eq(Array(screen.capture_states()), Array(ScreenClass.CAPTURE_STATES), "drill/the_declared_capture_states_are_the_screen_own")
	audit.check_eq(screen.apply_capture_state("nope"), false, "drill/an_undeclared_capture_state_is_refused")


# ---------------------------------------------------------------------------
# 2. The exercises
# ---------------------------------------------------------------------------

func _exercises(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var table: Array = Tables.drill_exercises()
	audit.check_eq(table.size(), 4, "drill/the_drill_table_lists_four_exercises")
	var shown: Array = []
	for row in table:
		var id := String((row as Dictionary).get("id", ""))
		var button := screen.find_child("Exercise_%s" % id, true, false) as Button
		shown.append(button.text if button != null else "<missing>")
	var expected: Array = []
	for row in table:
		expected.append(UiStrings.t("drill_%s_name" % String((row as Dictionary).get("id", ""))))
	audit.check_eq(shown, expected, "drill/the_four_exercise_buttons_show_the_tables_own_names")
	var order: Array = []
	for row in table:
		order.append(String((row as Dictionary).get("id", "")))
	audit.check_eq(_exercise_ids(screen), order, "drill/the_order_is_the_tables_order")
	audit.check_eq(screen.exercise(), String(order[0]), "drill/the_first_exercise_is_the_default")
	for id in order:
		audit.check_eq(screen.select_exercise(String(id)), true, "drill/%s_can_be_chosen" % id)
		audit.check_eq(screen.exercise(), String(id), "drill/%s_is_the_choice" % id)
		var button := screen.find_child("Exercise_%s" % id, true, false) as Button
		audit.check_eq(button.button_pressed, true, "drill/%s_is_the_pressed_segment" % id)
		audit.check_eq(screen.exercise_desc_key(), "drill_%s_desc" % id, "drill/%s_brings_its_own_subtitle" % id)
		audit.check_eq(screen.exercise_hint_key(), "drill_%s_hint" % id, "drill/%s_brings_its_own_hint" % id)
	audit.check_eq(screen.select_exercise("bogus"), false, "drill/an_unknown_exercise_is_refused")
	screen.select_exercise(String(order[0]))


# ---------------------------------------------------------------------------
# 3. The difficulty control, and what it may not touch
# ---------------------------------------------------------------------------

func _difficulty(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var prefs_before: Dictionary = ModesSave.profile(_store).get("prefs", {}).duplicate(true)
	var difficulty_ids := _difficulty_ids(screen)
	var shown: Array = []
	for id in difficulty_ids:
		var button := screen.find_child("Difficulty_%s" % id, true, false) as Button
		shown.append(button.text if button != null else "<missing>")
	var expected: Array = []
	for id in difficulty_ids:
		expected.append(UiStrings.t("diff%s" % String(id).capitalize()))
	audit.check_eq(shown, expected, "drill/the_difficulty_buttons_name_the_reference_keys")
	audit.check_true(difficulty_ids.has(screen.difficulty()), "drill/the_seed_difficulty_is_one_of_the_four")
	audit.check_eq(screen.select_difficulty("hard"), true, "drill/a_difficulty_can_be_chosen")
	audit.check_eq(screen.difficulty(), "hard", "drill/the_choice_is_the_one_made")
	audit.check_eq(screen.select_difficulty("bogus"), false, "drill/an_unknown_difficulty_is_refused")
	audit.check_eq(screen.difficulty(), "hard", "drill/a_refused_choice_changes_nothing")
	var prefs_after: Dictionary = ModesSave.profile(_store).get("prefs", {})
	audit.check_eq(prefs_after, prefs_before, "drill/choosing_a_drill_difficulty_writes_no_pref")
	var before_exercise: String = screen.exercise()
	screen.select_exercise(String(_exercise_ids(screen)[2]))
	audit.check_eq(screen.difficulty(), "hard", "drill/changing_the_exercise_keeps_the_difficulty")
	screen.select_exercise(before_exercise)
	audit.check_eq(screen.difficulty(), "hard", "drill/the_difficulty_survives_the_round_trip")
	audit.report("difficulty: the drill control is session state — the profile's aiDifficulty is untouched (reference: ui.drillDifficulty ?? ui.aiDifficulty)")


# ---------------------------------------------------------------------------
# 4. The four metric boxes
# ---------------------------------------------------------------------------

func _metrics(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var drill = _session_for(screen.exercise())
	var metrics: Array = DrillScoring.metrics(drill)
	audit.check_eq(screen.metric_rows().size(), 4, "drill/four_metric_boxes")
	var expected: Array = []
	for index in 4:
		var row: Dictionary = metrics[index]
		expected.append({"label": UiStrings.t(String(row["key"])), "value": String(row["value"])})
	audit.check_eq(screen.shown_metric_rows(), expected, "drill/the_boxes_show_the_sessions_own_four")
	audit.check_eq(screen.metric_rows().size(), 4, "drill/the_screens_own_reading_is_four_rows")


## The value in the box whose label is `key`'s own text — the box the reference's
## `syncDrillChrome` writes that metric into, whatever position it holds for this
## exercise (`rally` puts `drillBest` fourth, `js/main.js:2168-2185`).
func _box_value(screen: Node, key: String) -> String:
	var wanted := UiStrings.t(key)
	for row in screen.shown_metric_rows():
		if String((row as Dictionary)["label"]) == wanted:
			return String((row as Dictionary)["value"])
	return "<missing:%s>" % wanted


func _session_for(exercise_id: String) -> Variant:
	return DrillSession.create(exercise_id, Config.athlete(), Config.arena(), Config.tier(), {"seed": 0})


# ---------------------------------------------------------------------------
# 5. The records are the persisted ones, and they are re-read
# ---------------------------------------------------------------------------

func _records(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var exercise: String = screen.exercise()
	for row in Tables.drill_exercises():
		var id := String((row as Dictionary).get("id", ""))
		ModesSave.save_drill_score(_store, id, PLACED_RECORD)
	audit.check_eq(UiData.drill_records(_store).get("count", 0), 4, "drill/four_records_are_on_disk")
	screen.enter({"router_id": "drill", "back_target": "menu"})
	await process_frame
	audit.check_eq(_box_value(screen, "drillBest"), str(PLACED_RECORD), "drill/the_best_box_shows_the_placed_record")
	ModesSave.save_drill_score(_store, exercise, 11)
	screen.enter({"router_id": "drill", "back_target": "menu"})
	await process_frame
	audit.check_eq(_box_value(screen, "drillBest"), "11", "drill/entering_again_re_reads_the_records")


# ---------------------------------------------------------------------------
# 6. start()
# ---------------------------------------------------------------------------

func _start(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var exercise: String = screen.exercise()
	var pending_round_before: Variant = Config.pending_round
	var outcome: Dictionary = screen.start(true)
	audit.check_eq(String(outcome.get("mode", "")), "drill", "drill/start_names_the_drill_mode")
	audit.check_eq(String(outcome.get("exercise", "")), exercise, "drill/start_carries_the_chosen_exercise")
	audit.check_eq(String(outcome.get("scene", "")), ScreenClass.SCENE_PATH, "drill/start_names_the_match_scene")
	audit.check_eq(outcome.get("dry_run", false), true, "drill/the_dry_run_says_so")
	audit.check_eq(Config.pending_mode, "drill", "drill/start_writes_the_pending_mode_seam")
	audit.check_eq(Config.pending_exercise, exercise, "drill/start_writes_the_pending_exercise_seam")
	audit.check_eq(Config.pending_round, pending_round_before, "drill/start_touches_nothing_else")
	audit.report("the mount reads Config.pending_mode == drill and Config.pending_exercise == %s, then loads %s" % [exercise, ScreenClass.SCENE_PATH])


# ---------------------------------------------------------------------------
# 7. Strings
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var language_at_start := Locale.current_lang()
	var unresolved: Array = []
	for key in ["drillTitle", "drillSub", "ariaDrill", "drillExercise", "drillScore", "drillBest",
			"drillHits", "drillStreak", "training", "difficulty"]:
		for lang in Locale.locales():
			if not Locale.is_resolvable(key, String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	for row in Tables.drill_exercises():
		var id := String((row as Dictionary).get("id", ""))
		for suffix in ["name", "desc", "hint"]:
			for lang in Locale.locales():
				if not Locale.is_resolvable("drill_%s_%s" % [id, suffix], String(lang)):
					unresolved.append("drill_%s_%s/%s" % [id, suffix, lang])
	audit.check_eq(unresolved, [], "drill/every_visible_key_resolves_in_both_locales")
	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
	var slots := _slots(screen)
	var before := _visible_texts(screen)
	Locale.set_lang(other)
	screen.refresh_strings()
	await process_frame
	var after := _visible_texts(screen)
	var wrong: Array = []
	var moved := 0
	for slot in slots:
		var expected_text := Locale.resolve(String(slots[slot]), other)
		if String(after[slot]) != expected_text:
			wrong.append("%s expected <%s> got <%s>" % [slot, expected_text, after[slot]])
		if Locale.resolve(String(slots[slot]), language_at_start) != expected_text:
			moved += 1
	audit.check_eq(wrong, [], "drill/the_flip_shows_the_other_tables_own_text")
	audit.check_gt(moved, 0, "drill/the_flip_moved_strings_that_differ")
	audit.report("language flip: %d of %d visible slots differ between tables" % [moved, slots.size()])
	Locale.set_lang(language_at_start)
	screen.refresh_strings()
	await process_frame
	var restored := _visible_texts(screen)
	var still_wrong: Array = []
	for slot in slots:
		if String(restored[slot]) != String(before[slot]):
			still_wrong.append(slot)
	audit.check_eq(still_wrong, [], "drill/the_flip_back_restores_every_slot")


func _slots(screen: Node) -> Dictionary:
	var out := {}
	for id in _exercise_ids(screen):
		out["exercise/%s" % id] = "drill_%s_name" % id
	for id in _difficulty_ids(screen):
		out["difficulty/%s" % id] = "diff%s" % String(id).capitalize()
	out["start"] = "training"
	out["hint"] = screen.exercise_hint_key()
	return out


func _visible_texts(screen: Node) -> Dictionary:
	var out := {}
	for id in _exercise_ids(screen):
		var button := screen.find_child("Exercise_%s" % id, true, false) as Button
		out["exercise/%s" % id] = button.text if button != null else "<missing>"
	for id in _difficulty_ids(screen):
		var button := screen.find_child("Difficulty_%s" % id, true, false) as Button
		out["difficulty/%s" % id] = button.text if button != null else "<missing>"
	out["start"] = _text_of(screen, "StartButton")
	out["hint"] = _text_of(screen, "Hint")
	return out


func _text_of(screen: Node, node_name: String) -> String:
	return _button_or_label(screen.find_child(node_name, true, false))


func _button_or_label(node: Node) -> String:
	if node is Button:
		return (node as Button).text
	if node is Label:
		return (node as Label).text
	return "<missing>"


func _exercise_ids(screen: Node) -> Array:
	var ids: Array = []
	for row in screen.exercise_rows():
		ids.append(String((row as Dictionary).get("id", "")))
	return ids


func _difficulty_ids(screen: Node) -> Array:
	var ids: Array = []
	for row in screen.difficulty_rows():
		ids.append(String((row as Dictionary).get("id", "")))
	return ids


# ---------------------------------------------------------------------------
# 8. Captures and the literal scan
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	for state_id in ScreenClass.CAPTURE_STATES:
		audit.check_eq(screen.apply_capture_state(String(state_id)), true, "drill/capture_state_%s_applies" % state_id)
	for exercise_id in _exercise_ids(screen):
		audit.check_eq(screen.apply_capture_state(String(exercise_id)), true, "drill/the_%s_capture_applies" % exercise_id)
		audit.check_eq(screen.exercise(), String(exercise_id), "drill/the_%s_capture_selects_it" % exercise_id)
	audit.check_eq(screen.apply_capture_state("hard"), true, "drill/the_hard_capture_applies")
	audit.check_eq(screen.difficulty(), "hard", "drill/the_hard_capture_selects_the_difficulty")
	audit.check_eq(screen.apply_capture_state("legend"), true, "drill/the_legend_capture_applies")
	audit.check_eq(screen.difficulty(), "legend", "drill/the_legend_capture_selects_the_difficulty")
	audit.check_eq(screen.apply_capture_state("default"), true, "drill/the_default_capture_applies")


func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "drill/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "drill/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "drill/DrillScreen_gd_carries_no_prose_literal")
	audit.check_true(source.contains("DrillScoring"), "drill/the_metric_labels_come_from_the_scoring_module")
	audit.check_true(not source.contains("Sim."), "drill/the_screen_simulates_nothing")


func _offenders_in_source(path: String, source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		var developer := false
		for marker in DEVELOPER_MARKERS:
			if code.contains(marker):
				developer = true
				break
		if developer:
			continue
		for literal in _literals(code):
			if not String(literal).contains(" "):
				continue
			out.append("%s:%d \"%s\"" % [path, index + 1, literal])
	return out


func _literals(code: String) -> Array:
	var out: Array = []
	var i := 0
	while i < code.length():
		if code[i] == "\"":
			var j := i + 1
			var buffer := ""
			while j < code.length() and code[j] != "\"":
				if code[j] == "\\":
					j += 1
					if j < code.length():
						buffer += code[j]
				else:
					buffer += code[j]
				j += 1
			out.append(buffer)
			i = j + 1
		else:
			i += 1
	return out


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(String(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
