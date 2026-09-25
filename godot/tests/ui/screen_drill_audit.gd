## screen_drill_audit.gd — UIR-18's contract audit for `screen-drill`, now the TRAINING HUB.
##
## WHAT THIS PROVES, and the reference each question comes from:
##
##   1. THE ROUTE: the router mounts the screen and the screen declares its own facts
##      (`screen_id`, `back_target`, the capture states it accepts).
##   2. THE HUB: the body is the shared `godot/src/ui/training/DrillHubView.gd`, and it shows
##      EVERY exercise the catalog carries — the reference's four (`js/drill.js:53-71`), the
##      Jev `return` and the training overhaul's three challenges — under `DrillText`'s own
##      names, grouped into the three families the mode module declares.
##   3. THE DETAIL PANEL: the goal, the measurable success rule, what is scored, the controls,
##      BOTH records and the run's length are the ones `drill_hub.gd` answers for the
##      selection, painted (read back from the labels), not retyped here.
##   4. THE RECORDS ARE THE BOUNDED ONES: the challenge best is read from the run's own key
##      (`training_v1:<id>:<difficulty>:<attempts>`) and the legacy `<id>` record is shown
##      separately as historical, so two numbers measured differently are never compared.
##   5. THE DIFFICULTY IS REAL AND TRANSIENT: choosing one changes the payload `start()` hands
##      the flow and writes NO preference (`aiDifficulty` is left exactly as it was).
##   6. START: `start(true)` writes the pending-mode seams (exercise + difficulty + return
##      route) and changes no scene.
##   7. THE WORDS: a language flip moves every name the two tables differ on.
##   8. THE FRAME: at 1280x720 nothing leaves the frame and no button clips its own label.
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://uir18-drill-audit`) and removes it again.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenScene := preload("res://src/ui/screens/DrillScreen.tscn")
const Locale := preload("res://src/locale/locale.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const DrillHub := preload("res://src/modes/drill_hub.gd")
const DrillObjective := preload("res://src/modes/drill_objective.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Config := preload("res://game/match_config.gd")
const SaveStore := preload("res://src/save/save_store.gd")

const TEMP_DIR := "user://uir18-drill-audit"
const SETTLE_FRAMES := 3
const FRAME := Vector2(1280, 720)
const PLACED_BOUNDED := 23
const PLACED_LEGACY := 7

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	_wipe()
	var audit := AuditBase.new("screen_drill")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	_router = Control.new()
	_router.name = "AuditRouter"
	_router.size = FRAME
	root.add_child(_router)
	var router := Router.new()
	router.name = "UiRouter"
	_router.add_child(router)
	audit.check_true(router.register("drill", ScreenScene), "screen/the_router_registers_the_drill_screen")
	audit.check_true(router.go_to("drill", {"back_target": "menu"}), "screen/the_router_mounts_it")
	await _settle()
	var screen = router.active_screen()
	audit.check_true(screen != null, "screen/the_screen_is_active")
	if screen == null:
		return
	screen.set_store(_store)
	await _settle()

	audit.check_eq(String(screen.screen_id()), "drill", "screen/the_screen_declares_its_own_id")
	audit.check_eq(String(screen.back_target()), "menu", "screen/the_declared_back_is_the_reference_return")

	await _hub(audit, screen)
	await _detail(audit, screen)
	await _records(audit, screen)
	await _difficulty(audit, screen)
	await _start(audit, screen)
	await _locale(audit, screen)
	await _fit(audit, screen)


## 2. The hub: every catalog exercise, under its own name, in its own family.
func _hub(audit: AuditBase, screen) -> void:
	var ids: Array = []
	for id in screen.exercise_ids():
		ids.append(String(id))
	audit.check_eq(ids.size(), 8, "screen/the_hub_offers_the_whole_catalog")
	audit.check_eq(ids, Array(Tables.drill_catalog_ids()), "screen/in_the_catalog_order")
	var report: Dictionary = screen.hub_report()
	var painted: Array = []
	for group in (report.get("groups", []) as Array):
		var entry: Dictionary = group
		audit.check_true(String(entry.get("label", "")) != "", "screen/the_family_%s_is_named" % String(entry.get("id", "")))
		for id in (entry.get("ids", []) as Array):
			painted.append(String(id))
			var card = screen.find_child("HubCard_%s" % String(id), true, false)
			audit.check_true(card is Button, "screen/%s_has_a_card" % String(id))
			if card is Button:
				audit.check_eq(String((card as Button).text), DrillText.exercise_name(String(id)), "screen/%s_shows_its_DrillText_name" % String(id))
	painted.sort()
	var expected: Array = ids.duplicate()
	expected.sort()
	audit.check_eq(painted, expected, "screen/every_catalog_exercise_has_exactly_one_card")
	audit.check_eq((report.get("groups", []) as Array).size(), 3, "screen/the_cards_are_grouped_into_three_families")


## 3. The detail panel: the model's own words, painted.
func _detail(audit: AuditBase, screen) -> void:
	audit.check_true(screen.select_exercise("glass_recovery"), "screen/a_challenge_can_be_selected")
	await _settle()
	var painted: Dictionary = screen.hub_report()
	var model: Dictionary = DrillHub.detail("glass_recovery", _store, String(painted["difficulty"]))
	audit.check_eq(String(painted["name"]), String(model["name"]), "screen/the_panel_names_the_selection")
	for field in ["goal", "success", "scores"]:
		audit.check_true(String(painted[field]).contains(String(model[field])), "screen/the_panel_shows_the_%s" % field)
	audit.check_true(String(painted["controls"]).contains("LS"), "screen/the_panel_lists_the_controls")
	audit.check_true(String(painted["run"]).contains("8"), "screen/the_panel_shows_the_run_length")
	var detail: Dictionary = painted["detail"]
	audit.check_eq(int(detail["attempts"]), DrillObjective.attempts_for("glass_recovery"), "screen/the_run_length_is_the_objective's")
	audit.check_true((detail["controls"] as Array).size() > 0, "screen/the_controls_are_the_model's_rows")


## 4. The records: the bounded one is the challenge's, the legacy one is historical.
func _records(audit: AuditBase, screen) -> void:
	var id := "glass_recovery"
	var attempts := DrillObjective.attempts_for(id)
	ModesSave.save_training_score(_store, id, "easy", attempts, PLACED_BOUNDED)
	ModesSave.save_drill_score(_store, id, PLACED_LEGACY)
	screen.select_difficulty("easy")
	await _settle()
	var rows: Dictionary = screen.shown_record_rows()
	audit.check_eq(int(rows["challenge"]), PLACED_BOUNDED, "screen/the_challenge_record_is_the_bounded_one")
	audit.check_eq(int(rows["historical"]), PLACED_LEGACY, "screen/the_legacy_record_is_shown_separately")
	audit.check_eq(String(rows["key"]), "training_v1:%s:easy:%d" % [id, attempts], "screen/and_keyed_by_difficulty_and_run_length")
	audit.check_true(String(rows["text"]).contains(str(PLACED_BOUNDED)) and String(rows["text"]).contains(str(PLACED_LEGACY)), "screen/both_numbers_are_painted")
	# A record written for ANOTHER difficulty is not this challenge's best.
	screen.select_difficulty("hard")
	await _settle()
	audit.check_eq(int(screen.shown_record_rows()["challenge"]), 0, "screen/another_difficulty_is_another_record")
	screen.select_difficulty("easy")
	await _settle()


## 5. The difficulty row: real, transient, and carried into the start payload.
func _difficulty(audit: AuditBase, screen) -> void:
	var before := UiData.settings_snapshot(_store)
	audit.check_true(screen.select_difficulty("legend"), "screen/the_difficulty_row_moves")
	await _settle()
	audit.check_eq(String(screen.difficulty()), "legend", "screen/the_choice_is_the_screen's")
	audit.check_eq(String(screen.start_payload()["difficulty"]), "legend", "screen/the_choice_reaches_the_payload")
	var after := UiData.settings_snapshot(_store)
	audit.check_eq(String(after.get("ai_difficulty", "")), String(before.get("ai_difficulty", "")), "screen/and_writes_no_preference")
	var seeded: String = String(screen.seed_difficulty())
	audit.check_true(DrillHub.difficulties().has(seeded), "screen/the_seed_is_one_of_the_references_four")


## 6. Start: the seams, and no scene change for a dry run.
func _start(audit: AuditBase, screen) -> void:
	screen.select_exercise("doubles_tactics")
	screen.select_difficulty("hard")
	await _settle()
	var payload: Dictionary = screen.start(true)
	audit.check_eq(String(payload["mode"]), "drill", "screen/start_names_the_drill")
	audit.check_eq(String(payload["exercise"]), "doubles_tactics", "screen/start_carries_the_exercise")
	audit.check_eq(String(payload["difficulty"]), "hard", "screen/start_carries_the_difficulty")
	audit.check_eq(str(payload["started"]), "true", "screen/start_is_granted_in_a_full_build")
	audit.check_eq(String(Config.pending_exercise), "doubles_tactics", "screen/start_writes_the_pending_exercise")
	audit.check_eq(String(Config.pending_drill_difficulty), "hard", "screen/start_writes_the_transient_difficulty")
	audit.check_eq(String(Config.pending_training_return), DrillHub.RETURN_SCENE_ROUTED, "screen/start_writes_the_route_back_to_this_hub")
	var focus: Array = screen.focus_controls()
	var actions: Array = []
	for row in focus:
		actions.append(String((row as Dictionary).get("action", "")))
	for id in Tables.drill_catalog_ids():
		audit.check_true(actions.has("exercise:%s" % String(id)), "screen/%s_is_focusable" % String(id))
	audit.check_true(actions.has("start"), "screen/the_start_action_is_focusable")


## 7. The words move with the language.
func _locale(audit: AuditBase, screen) -> void:
	var original := Locale.current_lang()
	var other := ""
	for lang in Locale.locales():
		if String(lang) != original:
			other = String(lang)
	audit.check_true(other != "", "screen/the_table_has_a_second_locale")
	if other == "":
		return
	Locale.set_lang(other)
	screen.refresh_strings()
	await _settle()
	var wrong: Array = []
	for id in Tables.drill_catalog_ids():
		var card = screen.find_child("HubCard_%s" % String(id), true, false)
		var expected := DrillText.exercise_name(String(id))
		var got := String((card as Button).text) if card is Button else "<missing>"
		if got != expected:
			wrong.append("%s expected <%s> got <%s>" % [String(id), expected, got])
	audit.check_eq(wrong, [], "screen/a_language_flip_moves_every_card")
	var detail: Dictionary = screen.hub_report()["detail"]
	audit.check_true(String(screen.hub_report()["goal"]).contains(String(detail["goal"])), "screen/and_the_detail_panel")
	Locale.set_lang(original)
	screen.refresh_strings()
	await _settle()


## 8. Nothing leaves the frame and no button clips its label.
func _fit(audit: AuditBase, screen) -> void:
	var outside: Array = []
	var clipped: Array = []
	for node in _all_nodes(screen):
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var rect: Rect2 = (node as Control).get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > FRAME.x + 0.5 or rect.end.y > FRAME.y + 0.5:
			outside.append("%s %s" % [String((node as Control).name), str(rect)])
		if node is Button:
			clipped.append_array(_clip_offenders(node as Button))
	audit.check_eq(outside, [], "screen/every_control_is_inside_1280x720")
	audit.check_eq(clipped, [], "screen/every_button_shows_its_whole_label_at_1280x720")


func _clip_offenders(button: Button) -> Array:
	var text := String(button.text)
	if text == "":
		return []
	var font: Font = button.get_theme_font("font")
	if font == null:
		return []
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	var pad := 0.0
	var box := button.get_theme_stylebox("normal")
	if box != null:
		pad = box.content_margin_left + box.content_margin_right
	if button.size.x < width + pad - 0.5:
		return ["\"%s\" needs %.0f+%.0f, has %.0f" % [text, width, pad, button.size.x]]
	return []


func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await process_frame


func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir():
				dir.remove(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
