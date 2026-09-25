## mode_training_screen_audit.gd — the PORTED training screen's contract audit.
##
## WHICH SCREEN THIS OWNS. `godot/game/mode_screen.gd` is the page a player reaches with
## `Config.pending_mode == "drill"` (`godot/game/ModeScreen.tscn`). The recreated
## `godot/src/ui/screens/DrillScreen.gd` is a different host of the SAME hub body and has its
## own audit (`tests/ui/screen_drill_audit.gd`); this file owns the ported one.
##
## WHAT IT PROVES, and why each question is asked:
##
##   1. the catalog's EIGHT exercises are all on screen, grouped into the three families the
##      mode module declares, under `DrillText`'s own names — and every name, goal, success
##      rule, scored fact, control and hint resolves in both locales (a raw id on screen is
##      the failure `DrillText.has` exists to catch);
##   2. the cards, the difficulty row, the primary start action and the back control are all
##      reachable through the SAME `MenuFocus` model the menu uses;
##   3. choosing an exercise writes `Config.pending_exercise` by BOTH routes: the mouse (the
##      card's own `pressed`) and the model's keyboard confirm;
##   4. the live `DrillSession` is real: `screen_report()` still answers `drill_phase` and
##      `drill_target` with the session's own values, while the PAGE paints none of the debug
##      text the old screen printed (no repository path, no JSON, no session readout);
##   5. `start` keeps its gate and its seams: `start_mode(true)` reports the drill mode, the
##      chosen exercise and `res://game/Match.tscn`, and touches nothing else;
##   6. the layout fits a 1280x720 frame — and a larger one — with nothing clipped.
##
## Read-only apart from the two seams the screen's own contract owns
## (`Config.pending_mode` / `Config.pending_exercise`) and the locale A/B; it mounts the
## shipped scene in a host frame and never writes a save.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Locale := preload("res://src/locale/locale.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillHub := preload("res://src/modes/drill_hub.gd")
const DrillObjective := preload("res://src/modes/drill_objective.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const ModeSession := preload("res://game/mode_session.gd")
const ModeScene := preload("res://game/ModeScreen.tscn")

const FRAME := Vector2(1280.0, 720.0)
const WIDE_FRAME := Vector2(1600.0, 900.0)
const SETTLE_FRAMES := 3
const SCENE_PATH := "res://game/Match.tscn"

## The keys `screen_report()` promised before this screen was redesigned. The redesign may
## change what the rows SAY, never what the report ANSWERS.
const REPORT_KEYS := ["mode", "screen", "declared_back", "locked", "startable", "rows", "detail",
	"drill_phase", "drill_target", "focus", "saved"]

const SECTIONS := ["catalog", "reachability", "selection", "session", "start", "no_debug_text",
	"reports", "fit_1280x720", "fit_1600x900", "other_locale"]

## The shapes the old screen printed and this one must never show.
const DEBUG_MARKERS := [
	"godot/src", "res://", "drill_phase", "drill_target", "JSON", "{", "}", "[", "]",
	"RECORD SALVATI", "SESSIONE", "ESERCIZI", "ALLENATI", "Torna al menu",
	"Schermata del modo", "bullseye", "target_r", "feed ", "rivals ", "kinds ",
]
const TARGET_FIELD := "(^|[^a-zA-Z])targets\\s*(true|false|\\[|\\{|[0-9])"

var _host: Control
var _screen: Node
var _done_sections: Array = []


func _initialize() -> void:
	var audit := AuditBase.new("mode_training_screen")
	await _run(audit)
	_drop(_screen)
	root.remove_child(_host)
	_host.free()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_host = Control.new()
	_host.name = "TrainingAuditFrame"
	_host.size = FRAME
	root.add_child(_host)

	if Gate.is_demo():
		audit.not_ported("training/the_open_screen_contract",
			"a DEMO build locks the drill (ModeSession.can_start) and shows no rows; run without --demo")
		return

	_screen = _mount()
	await _settle()
	await _catalog(audit)
	await _reachability(audit)
	await _selection(audit)
	await _session(audit)
	await _start(audit)
	await _no_debug_text(audit)
	await _reports(audit)
	await _fit(audit, FRAME, "fit_1280x720")
	await _fit(audit, WIDE_FRAME, "fit_1600x900")
	await _other_locale(audit)
	audit.check_eq(_done_sections, SECTIONS, "training/every_section_ran_to_completion")
	audit.report("mounted res://game/ModeScreen.tscn with Config.pending_mode == drill at %.0fx%.0f" % [
		FRAME.x, FRAME.y])


func _done(section: String) -> void:
	_done_sections.append(section)


# ---------------------------------------------------------------------------
# 1. The eight exercises, in their three families
# ---------------------------------------------------------------------------

func _catalog(audit: AuditBase) -> void:
	var catalogue: Array = Tables.drill_catalog()
	audit.check_eq(catalogue.size(), 8, "training/the_catalogue_carries_eight_exercises")
	audit.check_eq(Tables.drill_exercises().size(), 4,
		"training/the_frozen_reference_still_lists_its_own_four")
	var hub = _screen.get("_hub")
	audit.check_true(hub != null, "training/the_page_mounts_the_shared_hub_view")
	var report: Dictionary = _screen.hub_report()
	var painted: Array = []
	for group in (report.get("groups", []) as Array):
		var entry: Dictionary = group
		audit.check_true(String(entry.get("label", "")) != "",
			"training/the_family_%s_has_a_name_on_the_page" % String(entry.get("id", "")))
		for id in (entry.get("ids", []) as Array):
			var exercise_id := String(id)
			painted.append(exercise_id)
			var card := _card(exercise_id)
			audit.check_true(card != null, "training/%s_card_exists" % exercise_id)
			if card == null:
				continue
			audit.check_eq(card.text, DrillText.exercise_name(exercise_id),
				"training/%s_shows_its_DrillText_name" % exercise_id)
			audit.check_true(card.toggle_mode and card.button_group != null,
				"training/%s_is_a_selection_card" % exercise_id)
			var objective := DrillObjective.for_exercise(exercise_id)
			for suffix in ["goal", "success", "scores", "watch"]:
				for lang in ["it", "en"]:
					audit.check_true(DrillText.has(String(objective["%s_key" % suffix]), String(lang)),
						"training/%s_has_a_%s_in_%s" % [exercise_id, suffix, String(lang)])
			for control in DrillObjective.controls_for(exercise_id):
				for lang in ["it", "en"]:
					audit.check_true(DrillText.has(String((control as Dictionary)["label"]), String(lang)),
						"training/%s_lists_a_control_that_resolves_in_%s" % [exercise_id, String(lang)])
			for lang in ["it", "en"]:
				audit.check_true(DrillText.has("drill_%s_hint" % exercise_id, String(lang)),
					"training/%s_has_a_hint_in_%s" % [exercise_id, String(lang)])
	var sorted_painted := painted.duplicate()
	sorted_painted.sort()
	var sorted_catalog := Array(Tables.drill_catalog_ids())
	sorted_catalog.sort()
	audit.check_eq(sorted_painted, sorted_catalog, "training/the_cards_are_the_catalogue")
	audit.check_eq((report.get("groups", []) as Array).size(), DrillObjective.GROUPS.size(),
		"training/the_cards_are_grouped_into_the_three_families")
	audit.check_true(Tables.drill_catalog_ids().has("return"),
		"training/the_Godot_only_return_exercise_is_offered")
	for challenge in ["glass_recovery", "net_play", "doubles_tactics"]:
		audit.check_true(Tables.drill_catalog_ids().has(challenge), "training/the_%s_challenge_is_offered" % challenge)
	_done("catalog")


# ---------------------------------------------------------------------------
# 2. Reachability through the one navigation model
# ---------------------------------------------------------------------------

func _reachability(audit: AuditBase) -> void:
	var model = _screen.focus_model()
	var focusable: Array = model.focusable_ids()
	var reachable: Array = model.reachable_ids()
	var missing: Array = []
	for exercise_id in Tables.drill_catalog_ids():
		var id := "drill:%s" % exercise_id
		if not (focusable.has(id) and reachable.has(id)):
			missing.append(id)
	audit.check_eq(missing, [], "training/every_exercise_is_focusable_and_reachable")
	audit.check_true(reachable.has("start"), "training/the_start_action_is_reachable")
	audit.check_true(reachable.has("back"), "training/the_back_control_is_reachable")
	audit.check_true(reachable.has("difficulty:legend"), "training/the_difficulty_row_is_reachable")
	var report: Dictionary = _screen.screen_report()
	audit.check_true(String(report["focus"]).begins_with("drill:"),
		"training/the_model_focuses_an_exercise_first")
	_done("reachability")


# ---------------------------------------------------------------------------
# 3. Choosing an exercise, by both routes
# ---------------------------------------------------------------------------

func _selection(audit: AuditBase) -> void:
	var clicked := "rally"
	var click_card := _card(clicked)
	audit.check_true(click_card != null, "training/the_click_target_exists")
	if click_card != null:
		click_card.emit_signal("pressed")
	audit.check_eq(String(Config.pending_exercise), clicked, "training/a_click_writes_pending_exercise")
	audit.check_eq(bool(click_card.button_pressed), true, "training/the_clicked_card_is_the_selection")
	audit.check_eq(String(_screen.get("_selected_exercise")), clicked, "training/and_the_screen_agrees")

	# The navigation route: the model focuses a card, the keyboard confirms it, and the
	# screen's own `_input` dispatches.
	var confirmed := "glass_recovery"
	var model = _screen.focus_model()
	model.menu.nav.set_focus("drill:%s" % confirmed)
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	_screen.call("_input", event)
	audit.check_eq(String(Config.pending_exercise), confirmed, "training/a_model_confirm_writes_pending_exercise")
	audit.check_eq(bool(_card(confirmed).button_pressed), true, "training/the_confirmed_card_is_the_selection")
	audit.check_eq(bool(_card(clicked).button_pressed), false, "training/only_one_card_is_the_selection")

	# The detail panel follows the choice, in the locale's own words, and the hint line too.
	var painted: Dictionary = _screen.hub_report()
	var model_detail: Dictionary = DrillHub.detail(confirmed, Config.save_store(), String(painted["difficulty"]))
	audit.check_eq(String(painted["name"]), String(model_detail["name"]), "training/the_detail_names_the_choice")
	audit.check_true(String(painted["goal"]).contains(String(model_detail["goal"])), "training/the_detail_shows_the_goal")
	audit.check_true(String(painted["success"]).contains(String(model_detail["success"])), "training/the_detail_shows_the_success_rule")
	audit.check_true(String(painted["controls"]).contains("LS"), "training/the_detail_lists_the_controls")
	audit.check_eq(_text_of("DrillHint"), DrillText.t(DrillText.exercise_hint_key(confirmed)), "training/the_hint_is_the_choices_own")
	_done("selection")


# ---------------------------------------------------------------------------
# 4. The real session behind the page
# ---------------------------------------------------------------------------

func _session(audit: AuditBase) -> void:
	var report: Dictionary = _screen.screen_report()
	var session = _screen.session
	audit.check_true(session != null, "training/the_preview_runs_a_real_DrillSession")
	if session == null:
		return
	audit.check_true(String(report["drill_phase"]) != "", "training/the_report_carries_a_phase")
	audit.check_eq(String(report["drill_phase"]), String(session.phase), "training/the_reported_phase_is_the_sessions_own")
	audit.check_true(not (report["drill_target"] as Dictionary).is_empty(), "training/the_report_carries_a_target")
	audit.check_eq(str(report["drill_target"]), str(session.target), "training/the_reported_target_is_the_sessions_own")
	_done("session")


# ---------------------------------------------------------------------------
# 5. start
# ---------------------------------------------------------------------------

func _start(audit: AuditBase) -> void:
	var chosen := String(Config.pending_exercise)
	var round_before: Variant = Config.pending_round
	var difficulty_before := String(Config.pending_drill_difficulty)
	var outcome: Dictionary = _screen.start_mode(true)
	audit.check_eq(ModeSession.can_start("drill"), true, "training/the_gate_grants_the_drill")
	audit.check_eq(String(outcome.get("mode", "")), "drill", "training/start_names_the_drill")
	audit.check_eq(str(outcome.get("started", false)), "true", "training/start_is_granted")
	audit.check_eq(String(outcome.get("exercise", "")), chosen, "training/start_carries_the_chosen_exercise")
	audit.check_eq(String(outcome.get("scene", "")), SCENE_PATH, "training/start_names_the_match_scene")
	audit.check_eq(Config.pending_round, round_before, "training/start_touches_nothing_else")
	# The difficulty the hub row shows is the one the run will play: the choice is transient
	# (`Config.pending_drill_difficulty`), and it never becomes a stored preference.
	audit.check_eq(String(Config.pending_drill_difficulty), difficulty_before, "training/start_does_not_invent_a_difficulty")
	var hub = _screen.get("_hub")
	audit.check_true(DrillHub.difficulties().has(String(hub.difficulty())), "training/the_hub_difficulty_is_one_of_the_four")
	_done("start")


# ---------------------------------------------------------------------------
# 6. No debug text, and the report keeps its shape
# ---------------------------------------------------------------------------

func _no_debug_text(audit: AuditBase) -> void:
	var texts := _visible_texts(_screen)
	var offenders: Array = []
	var target_re := RegEx.new()
	target_re.compile(TARGET_FIELD)
	for line in texts:
		var text := String(line)
		var lower := text.to_lower()
		for marker in DEBUG_MARKERS:
			if lower.contains(String(marker).to_lower()):
				offenders.append("%s <= \"%s\"" % [String(marker), text])
				break
		if target_re.search(lower) != null:
			offenders.append("targets-field <= \"%s\"" % text)
	audit.check_eq(offenders, [], "training/no_developer_text_or_raw_data_is_visible")
	audit.check_gt(texts.size(), 6, "training/the_scan_actually_read_text")
	print("# TRAINING_ON_SCREEN %s" % str(texts))
	_done("no_debug_text")


func _reports(audit: AuditBase) -> void:
	var report: Dictionary = _screen.screen_report()
	var missing: Array = []
	for key in REPORT_KEYS:
		if not report.has(key):
			missing.append(key)
	audit.check_eq(missing, [], "training/screen_report_keeps_every_promised_key")
	audit.check_eq(String(report["screen"]), "screen-modes", "training/the_screen_declares_its_own_id")
	audit.check_eq(String(report["declared_back"]), "to-menu", "training/the_declared_back_is_the_reference_return")
	audit.check_eq(bool(report["locked"]), false, "training/a_full_build_does_not_lock_the_drill")
	var names: Array = []
	for exercise_id in Tables.drill_catalog_ids():
		names.append(DrillText.exercise_name(exercise_id))
	var rows: Array = report["rows"]
	# The rows the page reports are the cards (player-facing names) plus the difficulty row
	# and the one action — data, in the order the page shows them.
	var cards_on_page: Array = []
	for row in rows:
		if names.has(String(row)):
			cards_on_page.append(String(row))
	audit.check_eq(cards_on_page.size(), names.size(), "training/the_reported_rows_carry_every_exercise_name")
	for name in names:
		audit.check_true(cards_on_page.has(String(name)), "training/the_report_lists_%s" % String(name))
	_done("reports")


# ---------------------------------------------------------------------------
# 7. The frame
# ---------------------------------------------------------------------------

func _fit(audit: AuditBase, frame: Vector2, section: String) -> void:
	_host.size = frame
	await _settle()
	var outside: Array = []
	var clipped: Array = []
	for node in _all_nodes(_screen):
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var rect: Rect2 = (node as Control).get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 \
				or rect.end.x > frame.x + 0.5 or rect.end.y > frame.y + 0.5:
			outside.append("%s %s" % [String(node.name), str(rect)])
		if node is Button:
			clipped.append_array(_clip_offenders(node as Button))
	audit.check_eq(outside, [], "training/every_control_is_inside_%.0fx%.0f" % [frame.x, frame.y])
	audit.check_eq(clipped, [], "training/every_button_shows_its_whole_label_at_%.0fx%.0f" % [
		frame.x, frame.y])
	_done(section)


## The engine's own font metrics: a button narrower than its label plus its padding clips.
func _clip_offenders(button: Button) -> Array:
	var text := String(button.text)
	if text == "":
		return []
	var font: Font = button.get_theme_font("font")
	var size: int = button.get_theme_font_size("font_size")
	if font == null:
		return []
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pad := 0.0
	var box := button.get_theme_stylebox("normal")
	if box != null:
		pad = box.content_margin_left + box.content_margin_right
	if button.size.x < width + pad - 0.5:
		return ["\"%s\" needs %.0f+%.0f, has %.0f" % [text, width, pad, button.size.x]]
	return []


# ---------------------------------------------------------------------------
# 8. The other locale
# ---------------------------------------------------------------------------

func _other_locale(audit: AuditBase) -> void:
	var original := Locale.current_lang()
	var other := ""
	for lang in Locale.locales():
		if String(lang) != original:
			other = String(lang)
	audit.check_true(other != "", "training/the_table_has_a_second_locale")
	if other == "":
		return
	var moved := 0
	for exercise_id in Tables.drill_catalog_ids():
		if DrillText.exercise_name(exercise_id, other) != DrillText.exercise_name(exercise_id, original):
			moved += 1
	audit.check_gt(moved, 0, "training/some_exercise_name_differs_between_the_tables")

	Locale.set_lang(other)
	_screen = await _remount()
	var wrong: Array = []
	for exercise_id in Tables.drill_catalog_ids():
		var card := _card(exercise_id)
		var expected := DrillText.exercise_name(exercise_id)
		var got := String(card.text) if card != null else "<missing>"
		if got != expected:
			wrong.append("%s expected <%s> got <%s>" % [exercise_id, expected, got])
	audit.check_eq(wrong, [], "training/a_rebuild_shows_the_other_tables_own_names")
	audit.check_eq(_text_of("DrillHint"),
		DrillText.t(DrillText.exercise_hint_key(String(Config.pending_exercise)), {}, other),
		"training/the_hint_is_the_other_locales_own")

	Locale.set_lang(original)
	_screen = await _remount()
	var restored := _card(String(Tables.drill_catalog_ids()[0]))
	var restored_text := String(restored.text) if restored != null else "<missing>"
	audit.check_eq(restored_text, DrillText.exercise_name(String(Tables.drill_catalog_ids()[0]), original),
		"training/the_original_locale_comes_back")
	_done("other_locale")


# ---------------------------------------------------------------------------
# Plumbing
# ---------------------------------------------------------------------------

func _mount() -> Node:
	Config.pending_mode = "drill"
	var screen: Node = ModeScene.instantiate()
	_host.add_child(screen)
	return screen


func _remount() -> Node:
	_drop(_screen)
	var screen := _mount()
	await _settle()
	return screen


func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await process_frame


func _drop(screen: Node) -> void:
	if screen == null or not is_instance_valid(screen):
		return
	if screen.get_parent() != null:
		screen.get_parent().remove_child(screen)
	screen.free()


## One exercise's card on the shared hub, by the name the view gives it.
func _card(exercise_id: String) -> Button:
	if _screen == null:
		return null
	return _screen.find_child("HubCard_%s" % exercise_id, true, false) as Button


func _text_of(node_name: String) -> String:
	var node := _screen.find_child(node_name, true, false)
	if node is Label:
		return String((node as Label).text)
	if node is Button:
		return String((node as Button).text)
	return "<missing:%s>" % node_name


func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out


func _visible_texts(node: Node) -> Array:
	var out: Array = []
	for child in _all_nodes(node):
		if not (child is Control) or not (child as Control).is_visible_in_tree():
			continue
		if child is Button:
			out.append(String((child as Button).text))
			if String((child as Button).tooltip_text) != "":
				out.append(String((child as Button).tooltip_text))
		elif child is Label:
			out.append(String((child as Label).text))
	return out
