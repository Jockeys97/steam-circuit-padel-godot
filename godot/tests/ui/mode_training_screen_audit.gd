## mode_training_screen_audit.gd — the LEGACY training screen's contract audit.
##
## WHICH SCREEN THIS OWNS. `godot/game/mode_screen.gd` is the page a player reaches
## with `Config.pending_mode == "drill"` (`godot/game/ModeScreen.tscn`). The recreated
## `godot/src/ui/screens/DrillScreen.gd` is a different screen with its own audit
## (`tests/ui/screen_drill_audit.gd`); this file owns the legacy one the owner's
## screenshot came from.
##
## WHAT IT PROVES, and why each question is asked:
##
##   1. the five exercises `Tables.drill_catalog()` carries are all on screen, in the
##      catalogue's own order, under `DrillText`'s own names — and every name,
##      description and hint RESOLVES in both locales (a raw id on screen is the
##      failure `DrillText.has` exists to catch);
##   2. the five rows, the primary start action and the back control are all reachable
##      through the SAME `MenuFocus` model the menu uses, and the model focuses an
##      exercise first;
##   3. choosing an exercise writes `Config.pending_exercise` by BOTH routes: the
##      mouse (the Button's own `pressed`) and the model's keyboard confirm — the path
##      that used to leave the seam untouched;
##   4. the live `DrillSession` is real: `screen_report()` still answers `drill_phase`
##      and `drill_target` with the session's own values, while the PAGE paints none of
##      the debug text the old screen printed (no repository path, no JSON, no
##      `feed`/`rivals`/`targets`/`kinds` field, no session readout);
##   5. `start` keeps its gate and its seams: `start_mode(true)` reports the drill mode,
##      the chosen exercise and `res://game/Match.tscn`, and touches nothing else;
##   6. the layout fits a 1280x720 frame — and a larger one — with nothing clipped:
##      every control's rect is inside the frame and every button is wider than its own
##      label.
##
## Read-only apart from the two seams the screen's own contract owns
## (`Config.pending_mode` / `Config.pending_exercise`) and the locale A/B; it mounts the
## shipped scene in a host frame and never writes a save.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Locale := preload("res://src/locale/locale.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const ModeSession := preload("res://game/mode_session.gd")
const ModeScene := preload("res://game/ModeScreen.tscn")

const FRAME := Vector2(1280.0, 720.0)
const WIDE_FRAME := Vector2(1600.0, 900.0)
const SETTLE_FRAMES := 3
const ROW_PREFIX := "Row_"
const SCENE_PATH := "res://game/Match.tscn"

## The keys `screen_report()` promised before this screen was redesigned. The redesign
## may change what the rows SAY, never what the report ANSWERS.
const REPORT_KEYS := ["mode", "screen", "declared_back", "locked", "startable", "rows", "detail",
	"drill_phase", "drill_target", "focus", "saved"]

## Every step `_run` performs. A GDScript runtime error aborts only the function it
## happens in and the engine keeps going (the same silent-abort class
## `game_slice_test.gd` names in M-1), so each step reports itself at its end and the
## run asserts the list is complete — a step that threw is a FAILED check, not a
## smaller green count.
const SECTIONS := ["exercises", "reachability", "selection", "session", "start", "no_debug_text",
	"reports", "fit_1280x720", "fit_1600x900", "other_locale"]

## The shapes the old screen printed and this one must never show. `feed`/`rivals`/
## `kinds` are matched as themselves — no exercise prose uses them — while `targets` is
## matched only as a printed field, because the reference's own English description
## legitimately reads "Targets in the opponent half".
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
		# `DEMO_CONTENT.modes` grants quick match only, so every mode screen — training
		# included — renders the locked line instead of its rows (`ModeScreen.is_locked`).
		# The open-screen contract needs a full build.
		audit.not_ported("training/the_open_screen_contract",
			"a DEMO build locks the drill (ModeSession.can_start) and shows no rows; run without --demo")
		return

	_screen = _mount()
	await _settle()
	await _exercises(audit)
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
# 1. The five exercises
# ---------------------------------------------------------------------------

func _exercises(audit: AuditBase) -> void:
	var catalogue: Array = Tables.drill_catalog()
	audit.check_eq(catalogue.size(), 5, "training/the_catalogue_carries_five_exercises")
	audit.check_eq(Tables.drill_exercises().size(), 4,
		"training/the_frozen_reference_still_lists_its_own_four")
	var seen: Array = []
	for exercise_id in Tables.drill_catalog_ids():
		var button := _row(exercise_id)
		audit.check_true(button != null, "training/%s_row_exists" % exercise_id)
		if button == null:
			continue
		seen.append(exercise_id)
		audit.check_eq(button.text, DrillText.exercise_name(exercise_id),
			"training/%s_shows_its_DrillText_name" % exercise_id)
		audit.check_true(button.toggle_mode and button.button_group != null,
			"training/%s_is_a_selection_row" % exercise_id)
		for suffix in ["name", "desc", "hint"]:
			for lang in ["it", "en"]:
				audit.check_true(DrillText.has("drill_%s_%s" % [exercise_id, suffix], String(lang)),
					"training/%s_has_a_%s_in_%s" % [exercise_id, suffix, String(lang)])
	audit.check_eq(seen, Array(Tables.drill_catalog_ids()), "training/the_rows_are_the_catalogue_order")
	audit.check_true(Tables.drill_catalog_ids().has("return"),
		"training/the_Godot_only_return_exercise_is_offered")
	_done("exercises")


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
	var report: Dictionary = _screen.screen_report()
	audit.check_true(String(report["focus"]).begins_with("drill:"),
		"training/the_model_focuses_an_exercise_first")
	_done("reachability")


# ---------------------------------------------------------------------------
# 3. Choosing an exercise, by both routes
# ---------------------------------------------------------------------------

func _selection(audit: AuditBase) -> void:
	var clicked := "rally"
	var click_row := _row(clicked)
	audit.check_true(click_row != null, "training/the_click_target_exists")
	if click_row != null:
		# The mouse route: the Button's own `pressed`, exactly what a click emits.
		click_row.emit_signal("pressed")
	audit.check_eq(String(Config.pending_exercise), clicked,
		"training/a_click_writes_pending_exercise")
	audit.check_eq(bool(click_row.button_pressed), true, "training/the_clicked_row_is_the_selection")

	# The navigation route: the model focuses a row, the keyboard confirms it, and the
	# screen's own `_input` dispatches — the path that used to leave the seam untouched.
	var confirmed := "return"
	var model = _screen.focus_model()
	model.menu.nav.set_focus("drill:%s" % confirmed)
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	_screen.call("_input", event)
	audit.check_eq(String(Config.pending_exercise), confirmed,
		"training/a_model_confirm_writes_pending_exercise")
	audit.check_eq(bool(_row(confirmed).button_pressed), true,
		"training/the_confirmed_row_is_the_selection")
	audit.check_eq(bool(_row(clicked).button_pressed), false,
		"training/only_one_row_is_the_selection")

	# The detail panel and the hint line follow the choice, in the locale's own words.
	audit.check_eq(_text_of("DrillName"), DrillText.exercise_name(confirmed),
		"training/the_detail_names_the_choice")
	audit.check_eq(_text_of("DrillDesc"), DrillText.t(DrillText.exercise_desc_key(confirmed)),
		"training/the_detail_describes_the_choice")
	audit.check_eq(_text_of("DrillHint"), DrillText.t(DrillText.exercise_hint_key(confirmed)),
		"training/the_hint_is_the_choices_own")
	audit.check_true(_text_of("DrillBest").contains(DrillText.exercise_name(confirmed)) or
		_text_of("DrillBest").contains(Locale.t("drillBest")),
		"training/the_record_line_uses_the_reference_best_label")
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
	audit.check_eq(String(report["drill_phase"]), String(session.phase),
		"training/the_reported_phase_is_the_sessions_own")
	audit.check_true(not (report["drill_target"] as Dictionary).is_empty(),
		"training/the_report_carries_a_target")
	audit.check_eq(str(report["drill_target"]), str(session.target),
		"training/the_reported_target_is_the_sessions_own")
	_done("session")


# ---------------------------------------------------------------------------
# 5. start
# ---------------------------------------------------------------------------

func _start(audit: AuditBase) -> void:
	var chosen := String(Config.pending_exercise)
	var round_before: Variant = Config.pending_round
	var outcome: Dictionary = _screen.start_mode(true)
	audit.check_eq(ModeSession.can_start("drill"), true, "training/the_gate_grants_the_drill")
	audit.check_eq(String(outcome.get("mode", "")), "drill", "training/start_names_the_drill")
	# `str()` and not `String()`: GDScript has no `String(bool)` constructor.
	audit.check_eq(str(outcome.get("started", false)), "true", "training/start_is_granted")
	audit.check_eq(String(outcome.get("exercise", "")), chosen,
		"training/start_carries_the_chosen_exercise")
	audit.check_eq(String(outcome.get("scene", "")), SCENE_PATH,
		"training/start_names_the_match_scene")
	audit.check_eq(Config.pending_round, round_before, "training/start_touches_nothing_else")
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
	audit.check_eq(String(report["declared_back"]), "to-menu",
		"training/the_declared_back_is_the_reference_return")
	audit.check_eq(bool(report["locked"]), false, "training/a_full_build_does_not_lock_the_drill")
	var names: Array = []
	for exercise_id in Tables.drill_catalog_ids():
		names.append(DrillText.exercise_name(exercise_id))
	audit.check_eq(Array(report["rows"]), names, "training/the_reported_rows_are_player_facing_names")
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


## The engine's own font metrics, the same rule `game_slice_test.gd::_ui_text()` applies
## to the menu's rows: a button narrower than its label plus its padding clips.
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
		var button := _row(exercise_id)
		var expected := DrillText.exercise_name(exercise_id)
		var got := String(button.text) if button != null else "<missing>"
		if got != expected:
			wrong.append("%s expected <%s> got <%s>" % [exercise_id, expected, got])
	audit.check_eq(wrong, [], "training/a_rebuild_shows_the_other_tables_own_names")
	audit.check_eq(_text_of("DrillHint"),
		DrillText.t(DrillText.exercise_hint_key(String(Config.pending_exercise)), {}, other),
		"training/the_hint_is_the_other_locales_own")
	audit.check_eq(_text_of("DrillDesc"),
		DrillText.t(DrillText.exercise_desc_key(String(Config.pending_exercise)), {}, other),
		"training/the_description_is_the_other_locales_own")

	Locale.set_lang(original)
	_screen = await _remount()
	var restored := _row(String(Tables.drill_catalog_ids()[0]))
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


func _row(exercise_id: String) -> Button:
	if _screen == null:
		return null
	return _screen.find_child(ROW_PREFIX + exercise_id, true, false) as Button


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
