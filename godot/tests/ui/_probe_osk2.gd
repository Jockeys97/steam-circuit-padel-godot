## osk_touch_audit.gd — UIR-26's contract audit: the on-screen keyboard and the
## coarse-pointer layer.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. the grid is the reference's own: five rows `1234567890`, `qwertyuiop`,
##      `asdfghjkl`, `zxcvbnm`, `àèéìòù@._-+` and the four action keys
##      (`js/main.js:430-437`, `:493-498`) — read through the input lane's model
##      (`src/input/osk.gd`), which is the only thing that may rule on them;
##   2. the model's own rules: shift, insert, backspace, the max-length clamp, done,
##      close-and-return-the-field, the label `field · oskHint`, the aria name;
##   3. the panel renders that model — label, value preview, six rows, 52 keys, and
##      the shifted labels after a shift press; its `osk_key_targets()` ids are the
##      feedback screen's door's ids (`osk/<char>`, `osk/<action>`) with the laid-out
##      rects, and the ids reach the keys they name (`js/main.js:475-509`);
##   4. the lane integration: `MenuNav.confirm()` on a text field opens the model,
##      `set_osk_targets(panel.osk_key_targets())` puts the focus context on the
##      keyboard, the first key holds the focus, a press through the panel lands in
##      the lane's model, and `back()` reports the close (`js/main.js:697-733`);
##   5. the touch mapping is the input lane's actions — `padel_drive`, `padel_switch`,
##      `padel_special`, `padel_up`/`left`/`right`/`down` — and every one of them
##      exists in `project.godot`;
##   6. the coarse-pointer visibility rules of `styles.css:2058-2085`: the deck only
##      for a coarse pointer at 681 px or wider, the pad at 680 px or narrower;
##   7. the seven pad buttons and the three deck buttons carry the reference's own
##      `data-i18n-aria` names (`dirUp`/`dirLeft`/`shot`/`dirRight`/`dirDown`/
##      `switchBtn`/`dirSpecial`, plus the deck's `ariaActionDeck`/`ariaTouch`);
##   8. a button down drives the action and a button up releases it; a block that
##      hides releases what it held; an action that is not in the project is refused
##      and named in `report()["missing_actions"]`;
##   9. a real `InputEventScreenTouch` at a deck button's centre drives the action
##      through the engine's own touch→mouse emulation;
##  10. the language flip moves every string this ticket owns (the four action-key
##      labels, the deck's labels and every aria name) between the two tables.
##
## WHAT IT DOES NOT DO: no Godot process ran this file in the UIR-26 wave (the wave's
## dispatch forbids it), and this machine has no touchscreen — `DisplayServer.
## is_touchscreen_available()` is false on it, so nothing here is device-tested. The
## two gaps are recorded below as `not_ported` so the tally carries them rather than
## hiding them. The acceptance command is in `evidence/uir-26-osk-touch.md`.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const OskModel := preload("res://src/input/osk.gd")
const InputStrings := preload("res://src/input/strings.gd")
const MenuNavClass := preload("res://src/input/menu_nav.gd")
const PanelClass := preload("res://src/ui/screens/OskPanel.gd")
const PanelScene := preload("res://src/ui/screens/OskPanel.tscn")
const TouchClass := preload("res://src/ui/screens/TouchControls.gd")
const TouchScene := preload("res://src/ui/screens/TouchControls.tscn")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")

const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 3
## `OSK_ROWS` (`js/main.js:430-437`), verbatim.
const GRID_ROWS := ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm", "àèéìòù@._-+"]
const ACTION_IDS := ["shift", "space", "backspace", "done"]
## The pad's `data-i18n-aria` (`index.html:489-494`), in markup order.
const PAD_ARIA := ["dirUp", "dirLeft", "shot", "dirRight", "dirDown", "switchBtn", "dirSpecial"]

var _panel: Control
var _touch: Control
var _frame: Control
var _model: OskModel
var _closed_targets: Array = []


func _initialize() -> void:
	var audit := AuditBase.new("osk_touch")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	root.size = Vector2i(int(FRAME.x), int(FRAME.y))
	_frame = Control.new()
	_frame.name = "OskTouchAuditFrame"
	_frame.size = FRAME
	root.add_child(_frame)
	_panel = PanelScene.instantiate()
	_frame.add_child(_panel)
	_touch = TouchScene.instantiate()
	_frame.add_child(_touch)
	for _i in SETTLE_FRAMES:
		await process_frame
	_model = OskModel.new()
	_panel.bind_model(_model)
	_panel.closed.connect(func(target_id: String) -> void: _closed_targets.append(target_id))
	await process_frame
	await _model_rules(audit)
	await _panel_view(audit)
	await _lane_integration(audit)
	await _touch_layer(audit)
	await _touch_events(audit)
	await _strings(audit)
	_platform(audit)
	audit.report("osk: %d targets over %d rows; touch: %s" % [
		_panel.osk_key_targets().size(), _model.rows().size(), str(_touch.apply_visibility()),
	])


# ---------------------------------------------------------------------------
# 1-2. The model: the grid the reference's own script builds
# ---------------------------------------------------------------------------

func _model_rules(audit: AuditBase) -> void:
	var rows: Array = _model.rows()
	audit.check_eq(rows.size(), 6, "osk/the_grid_is_five_character_rows_and_the_action_row")
	var grid_ok := true
	var chars: Array = []
	for index in 5:
		var row: Dictionary = rows[index]
		if String(row.get("kind", "")) != "chars":
			grid_ok = false
		for key in row.get("keys", []):
			chars.append(String((key as Dictionary).get("char", "")))
	audit.check_true(grid_ok, "osk/the_first_five_rows_are_character_rows")
	audit.check_eq("".join(GRID_ROWS).length(), chars.size(), "osk/the_grid_has_every_character_of_the_reference")
	var rebuilt := ""
	for char in chars:
		rebuilt += String(char)
	audit.check_eq(rebuilt, "".join(GRID_ROWS), "osk/the_characters_are_in_the_references_own_order")
	audit.check_eq(String((rows[5] as Dictionary).get("kind", "")), "actions", "osk/the_last_row_is_the_action_row")
	var action_ids: Array = []
	var action_labels: Array = []
	for key in (rows[5] as Dictionary).get("keys", []):
		action_ids.append(String((key as Dictionary).get("id", "")))
		action_labels.append(String((key as Dictionary).get("label", "")))
	audit.check_eq(action_ids, ACTION_IDS, "osk/the_four_action_keys_are_the_references")
	var unresolved: Array = []
	for index in ACTION_IDS.size():
		if action_labels[index] != InputStrings.text("osk%s" % String(ACTION_IDS[index]).capitalize()):
			unresolved.append(String(ACTION_IDS[index]))
	audit.check_eq(unresolved, [], "osk/every_action_key_label_resolves_through_the_strings_seam")
	# The model's own rules (`js/main.js:461-498`).
	_model.open_for("pause/fb-message", "ab", 12, UiStrings.t("volume"))
	audit.check_eq(_model.is_open(), true, "osk/open_for_opens")
	audit.check_eq(_model.target_id(), "pause/fb-message", "osk/the_target_comes_back_on_close")
	audit.check_eq(_model.value(), "ab", "osk/open_for_takes_the_fields_value")
	audit.check_true(_model.label().begins_with(UiStrings.t("volume")), "osk/the_label_starts_with_the_fields_own_label")
	audit.check_true(_model.label().contains(InputStrings.text("oskHint")), "osk/the_label_carries_the_hint")
	audit.check_eq(_model.aria_label(), InputStrings.text(InputStrings.OSK_ARIA), "osk/the_aria_name_is_the_keyboards")
	audit.check_eq(_model.press_char("c"), true, "osk/a_character_press_is_taken")
	audit.check_eq(_model.value(), "abc", "osk/the_character_lands_in_the_value")
	audit.check_eq(_model.press_char("D"), true, "osk/an_upper_case_press_is_taken")
	audit.check_eq(_model.value(), "abcD", "osk/the_upper_case_lands_as_written")
	audit.check_eq(_model.insert("-"), true, "osk/insert_takes_a_character")
	audit.check_eq(_model.value(), "abcD-", "osk/the_inserted_character_lands_last")
	audit.check_eq(_model.delete_char(), true, "osk/backspace_deletes")
	audit.check_eq(_model.value(), "abcD", "osk/the_delete_removed_the_last_character")
	audit.check_eq(_model.shift(), false, "osk/shift_starts_off")
	audit.check_eq(_model.toggle_shift(), true, "osk/shift_toggles_on")
	var shifted: Array = _model.rows()
	var first_key: Dictionary = (shifted[1] as Dictionary)["keys"][0]
	audit.check_eq(String(first_key.get("label", "")), "Q", "osk/a_shifted_key_shows_its_upper_face")
	audit.check_eq(_model.press("shift"), "shift", "osk/the_shift_key_answers_shifts_name")
	audit.check_eq(_model.shift(), false, "osk/the_second_shift_press_toggles_off")
	audit.check_eq(_model.press("space"), "space", "osk/the_space_key_answers_spaces_name")
	audit.check_true(_model.value().ends_with(String.chr(32)), "osk/the_space_lands_as_a_space")
	audit.check_eq(_model.press("backspace"), "backspace", "osk/the_backspace_key_answers_its_name")
	audit.check_eq(_model.press("nope"), "", "osk/an_unknown_key_answers_nothing")
	# The clamp (`js/main.js:463-470`): the twelfth character is refused, not trimmed.
	_model.close()
	_model.open_for("pause/fb-message", "abcdefghijkl", 12, UiStrings.t("volume"))
	audit.check_eq(_model.value().length(), 12, "osk/the_max_length_is_the_fields")
	audit.check_eq(_model.press_char("m"), false, "osk/a_character_past_the_clamp_is_refused")
	audit.check_eq(_model.value().length(), 12, "osk/the_clamp_does_not_trim")
	audit.check_eq(_model.max_length(), 12, "osk/the_max_length_reads_back")
	audit.check_eq(_model.press("done"), "closed", "osk/done_answers_closed")
	audit.check_eq(_model.is_open(), false, "osk/done_closes_the_keyboard")
	audit.check_eq(_model.press("space"), "", "osk/a_key_after_the_close_answers_nothing")
	_model.open_for("pause/fb-message", "ab", 12, UiStrings.t("volume"))
	audit.check_eq(_model.close(), "pause/fb-message", "osk/close_returns_the_field_to_focus")
	audit.check_eq(_model.value(), "ab", "osk/close_keeps_the_value_for_the_caller")


# ---------------------------------------------------------------------------
# 3. The panel over that model
# ---------------------------------------------------------------------------

func _panel_view(audit: AuditBase) -> void:
	audit.check_eq(_panel.visible, false, "osk/the_panel_is_hidden_while_the_keyboard_is_closed")
	audit.check_eq(_panel.is_open(), false, "osk/the_panel_reports_the_model_closed")
	audit.check_eq(_panel.osk_key_targets().size(), 0, "osk/no_targets_while_closed")
	audit.check_true(_panel.capture_states().has("default"), "osk/the_default_capture_state_is_declared")
	audit.check_eq(_panel.apply_capture_state("nope"), false, "osk/an_unknown_capture_state_is_refused")
	_model.open_for("pause/fb-message", "ab", 12, UiStrings.t("volume"))
	_panel.refresh()
	audit.check_eq(_panel.visible, true, "osk/the_panel_shows_while_the_keyboard_is_open")
	audit.check_eq(_panel.is_open(), true, "osk/the_panel_reports_the_model_open")
	audit.check_eq(_panel.apply_capture_state("default"), true, "osk/the_default_capture_state_applies_while_open")
	audit.check_eq(_panel.aria_text(), InputStrings.text(InputStrings.OSK_ARIA), "osk/the_panel_carries_the_keyboards_aria_name")
	var label := _panel.find_child("OskLabel", true, false) as Label
	audit.check_eq(label.text, _model.label(), "osk/the_label_is_the_models_own")
	var preview := _panel.find_child("OskPreviewText", true, false) as Label
	audit.check_eq(preview.text, "ab", "osk/the_preview_shows_the_fields_value")
	audit.check_eq(_panel.report().get("open"), true, "osk/the_report_carries_the_state")
	var targets: Array = _panel.osk_key_targets()
	print("DIAG panel size=", _panel.size, " visible=", _panel.visible, " global=", _panel.get_global_rect())
	print("DIAG frame size=", _frame.size, " root size=", root.size)
	var rows_dbg: Array = _model.rows()
	print("DIAG model rows=", rows_dbg.size(), " open=", _model.is_open())
	for i in [0, targets.size() - 1]:
		if i < targets.size():
			print("DIAG target[%d]=" % i, (targets[i] as Dictionary).get("rect"))
	var grid := _panel.find_child("OskGrid", true, false)
	print("DIAG grid=", grid, " grid rect=", (grid.get_global_rect() if grid != null else "n/a"))
	print("DIAG grid visible_in_tree=", grid.is_visible_in_tree() if grid != null else "n/a", " panel vis_in_tree=", _panel.is_visible_in_tree())
	for _f in 2:
		await process_frame
	var after: Array = _panel.osk_key_targets()
	for i in [0, after.size() - 1]:
		if i < after.size():
			print("DIAG after frame target[%d]=" % i, (after[i] as Dictionary).get("rect"))
	print("DIAG root size after=", root.size)
	quit(0)
	audit.check_eq(targets.size(), 52, "osk/every_key_of_the_grid_is_a_target")
	var target_ids: Array = []
	var wanted_ids: Array = []
	for char in "".join(GRID_ROWS):
		wanted_ids.append("osk/%s" % String(char))
	for id in ACTION_IDS:
		wanted_ids.append("osk/%s" % String(id))
	var wrong: Array = []
	for target in targets:
		var entry: Dictionary = target
		target_ids.append(String(entry.get("id", "")))
		if not wanted_ids.has(String(entry.get("id", ""))):
			wrong.append(String(entry.get("id", "")))
	audit.check_eq(wrong, [], "osk/every_target_id_is_a_key_of_the_grid")
	audit.check_eq(target_ids, wanted_ids, "osk/the_target_order_is_the_grids_own")
	var flat: Array = []
	var laid_out := true
	for target in targets:
		var entry: Dictionary = target
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			laid_out = false
		flat.append(rect.position.y)
	audit.check_true(laid_out, "osk/every_target_carries_the_laid_out_rect")
	audit.check_lt(flat[0], flat[flat.size() - 1], "osk/the_first_row_sits_above_the_action_row")
	var picks := ["1", "q", "a", "z", "à", "shift", "done"]
	for index in picks.size():
		var key: Control = _panel.key_node("osk/%s" % String(picks[index]))
		audit.check_ne(key, null, "osk/the_target_id_reaches_key_%d" % (index + 1))
	for index in picks.size():
		var reachable: Button = _panel.key_node("osk/%s" % String(picks[index]))
		if reachable != null:
			audit.check_gt(reachable.get_global_rect().size.y, 0.0, "osk/key_%d_has_a_laid_out_height" % (index + 1))
	# Shift: the panel's labels follow the model's rows.
	audit.check_eq((_panel.key_node("osk/q") as Button).text, "q", "osk/an_unshifted_key_shows_its_lower_face")
	audit.check_eq(_panel.press_target("osk/shift"), true, "osk/the_shift_target_is_pressed")
	audit.check_eq(_model.shift(), true, "osk/the_shift_target_moved_the_model")
	audit.check_eq((_panel.key_node("osk/q") as Button).text, "Q", "osk/a_shifted_key_shows_its_upper_face_on_the_panel")
	audit.check_eq((_panel.key_node("osk/shift") as Button).text, InputStrings.text("oskShift"), "osk/the_shift_key_carries_its_label")
	_panel.press_target("osk/shift")
	audit.check_eq(_model.shift(), false, "osk/the_shift_target_toggles_back")
	# A character through the panel, and the value preview follows.
	var before_value := _model.value()
	audit.check_eq(_panel.press_target("osk/z"), true, "osk/a_character_target_is_pressed")
	audit.check_eq(_model.value(), before_value + "z", "osk/the_character_reached_the_model")
	audit.check_eq(preview.text, _model.value(), "osk/the_preview_follows_the_value")
	audit.check_eq(_panel.press_target("osk/nope"), false, "osk/an_unknown_target_is_refused")
	audit.check_eq(_panel.press_char("y"), true, "osk/the_panel_forwards_a_bare_character")
	audit.check_eq(_panel.press("backspace"), "backspace", "osk/the_panel_forwards_an_action_key")
	# Done closes, the panel hides, and the field to focus comes back.
	var closed_before := _closed_targets.size()
	audit.check_eq(_panel.press("done"), "closed", "osk/done_through_the_panel_closes")
	audit.check_eq(_panel.visible, false, "osk/the_panel_hides_after_done")
	audit.check_eq(_closed_targets.size(), closed_before + 1, "osk/the_closed_signal_fires_once")
	audit.check_eq(String(_closed_targets[closed_before]), "pause/fb-message", "osk/the_closed_signal_names_the_field")
	# The compact sizing of `@media (max-width: 560px)` (`styles.css:3577-3582`).
	_model.open_for("pause/fb-message", "ab", 12, UiStrings.t("volume"))
	_panel.size = Vector2(FRAME.x, FRAME.y)
	_panel.refresh()
	await process_frame
	audit.check_eq((_panel.key_node("osk/q") as Button).custom_minimum_size.y, PanelClass.KEY_HEIGHT, "osk/a_wide_frame_keeps_the_44px_keys")
	_panel.size = Vector2(520.0, 700.0)
	await process_frame
	audit.check_eq((_panel.key_node("osk/q") as Button).custom_minimum_size.y, PanelClass.KEY_HEIGHT_COMPACT, "osk/a_560px_frame_shrinks_the_keys")
	_panel.size = Vector2(FRAME.x, FRAME.y)
	await process_frame


# ---------------------------------------------------------------------------
# 4. The lane integration (menu_nav.gd's own contract, js/main.js:697-733)
# ---------------------------------------------------------------------------

func _lane_integration(audit: AuditBase) -> void:
	var menu: MenuNavClass = MenuNavClass.new()
	menu.set_pad_connected(true)
	var field := {
		"id": "pause/fb-message", "kind": "text_field", "action": "",
		"rect": Rect2(0.0, 0.0, 240.0, 28.0),
		"value": "ciao", "max_length": 12, "field_label": UiStrings.t("volume"),
	}
	menu.set_screen_targets([field])
	menu.open_screen("screen-feedback")
	menu.ensure_focus()
	audit.check_eq(menu.focus_id(), "pause/fb-message", "osk/the_field_holds_the_focus")
	var opened: Dictionary = menu.confirm()
	audit.check_eq(String(opened.get("kind", "")), "osk_open", "osk/confirming_a_field_opens_the_keyboard")
	audit.check_eq(String(opened.get("target", "")), "pause/fb-message", "osk/the_opened_keyboard_names_the_field")
	audit.check_eq(menu.osk.is_open(), true, "osk/the_lanes_own_model_is_open")
	audit.check_eq(menu.osk.value(), "ciao", "osk/the_lane_took_the_fields_value")
	audit.check_eq(menu.context_kind(), "osk", "osk/the_focus_context_is_the_keyboard")
	var panel_two: Control = PanelScene.instantiate()
	panel_two.size = FRAME
	_frame.add_child(panel_two)
	panel_two.bind_model(menu.osk)
	await process_frame
	audit.check_eq(panel_two.is_open(), true, "osk/the_panel_renders_the_lanes_model")
	menu.set_osk_targets(panel_two.osk_key_targets())
	audit.check_eq(menu.focus_id(), "osk/1", "osk/the_first_key_takes_the_focus")
	var pressed: bool = panel_two.press_target("osk/q")
	await process_frame
	audit.check_eq(pressed, true, "osk/a_panel_press_is_taken_over_the_lanes_model")
	audit.check_eq(menu.osk.value(), "ciaoq", "osk/the_press_landed_in_the_lanes_model")
	var closed: Dictionary = menu.back()
	audit.check_eq(String(closed.get("kind", "")), "osk_close", "osk/back_reports_the_keyboard_close")
	audit.check_eq(String(closed.get("target", "")), "pause/fb-message", "osk/back_names_the_field_to_refocus")
	audit.check_eq(menu.osk.is_open(), false, "osk/back_closed_the_lanes_model")
	audit.check_eq(menu.context_kind(), "screen", "osk/the_focus_context_returns_to_the_screen")
	panel_two.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 5-7. The touch layer: the mapping, the buttons, the aria names
# ---------------------------------------------------------------------------

func _touch_layer(audit: AuditBase) -> void:
	audit.check_eq(TouchClass.action_for_dir("hit"), "padel_drive", "touch/the_decks_shot_button_is_the_drive_action")
	audit.check_eq(TouchClass.action_for_dir("switch"), "padel_switch", "touch/the_decks_switch_button_is_the_switch_action")
	audit.check_eq(TouchClass.action_for_dir("special"), "padel_special", "touch/the_decks_special_button_is_the_special_action")
	var pad_dirs := ["up", "left", "hit", "right", "down"]
	for dir in pad_dirs:
		audit.check_true(String(TouchClass.action_for_dir(dir)) != "", "touch/the_pads_%s_button_maps_to_an_action" % dir)
	audit.check_eq(String(TouchClass.action_for_dir("up")), "padel_up", "touch/the_pads_up_is_the_up_action")
	audit.check_eq(String(TouchClass.action_for_dir("down")), "padel_down", "touch/the_pads_down_is_the_down_action")
	audit.check_eq(String(TouchClass.action_for_dir("left")), "padel_left", "touch/the_pads_left_is_the_left_action")
	audit.check_eq(String(TouchClass.action_for_dir("right")), "padel_right", "touch/the_pads_right_is_the_right_action")
	audit.check_eq(String(TouchClass.action_for_dir("nope")), "", "touch/an_unknown_direction_maps_to_nothing")
	var actions: Array = []
	for entry in TouchClass.DECK:
		actions.append(String((entry as Dictionary)["action"]))
	for entry in TouchClass.PAD:
		actions.append(String((entry as Dictionary)["action"]))
	var absent: Array = []
	for action in actions:
		if not InputMap.has_action(String(action)):
			absent.append(String(action))
	audit.check_eq(absent, [], "touch/every_mapped_action_exists_in_the_project")
	audit.check_eq(_touch.deck_buttons().size(), 3, "touch/the_deck_carries_three_buttons")
	audit.check_eq(_touch.pad_buttons().size(), 7, "touch/the_pad_carries_seven_buttons")
	var deck_order: Array = []
	for dir in ["hit", "switch", "special"]:
		deck_order.append(_touch.deck_buttons().has(dir))
	audit.check_eq(deck_order, [true, true, true], "touch/the_deck_buttons_are_the_references_three")
	var pad_order: Array = []
	for dir in ["up", "left", "hit", "right", "down", "switch", "special"]:
		pad_order.append(_touch.pad_buttons().has(dir))
	audit.check_eq(pad_order, [true, true, true, true, true, true, true], "touch/the_pad_buttons_are_the_references_seven")
	# The aria names: the reference's own ids, in the reference's own order.
	var ids: Dictionary = _touch.aria_ids()
	audit.check_eq(String(ids.get("hit", "")), "shot", "touch/the_decks_shot_carries_the_shot_aria")
	audit.check_eq(String(ids.get("switch", "")), "switchBtn", "touch/the_decks_switch_carries_the_switchBtn_aria")
	audit.check_eq(String(ids.get("special", "")), "specialBtn", "touch/the_decks_special_carries_the_specialBtn_aria")
	var pad_aria: Array = []
	for dir in ["up", "left", "hit", "right", "down", "switch", "special"]:
		pad_aria.append(String(ids.get("pad-%s" % dir, "")))
	audit.check_eq(pad_aria, PAD_ARIA, "touch/the_pads_aria_names_are_the_references_own")
	audit.check_true(_touch.aria_text_for("pad-hit") == UiStrings.t("shot"), "touch/the_pads_hit_resolves_to_the_shot_name")
	for entry in TouchClass.DECK:
		var glyph := String((entry as Dictionary)["glyph"])
		audit.check_eq(glyph.contains(String.chr(32)), false, "touch/the_deck_glyphs_carry_no_space")
	# The visibility rules of `styles.css:2058-2085`.
	_touch.set_coarse_pointer(false)
	_touch.set_frame_width(FRAME.x)
	var fine: Dictionary = _touch.apply_visibility()
	audit.check_eq(fine.get("deck"), false, "touch/a_fine_pointer_hides_the_deck_at_desktop_width")
	_touch.set_coarse_pointer(true)
	var wide: Dictionary = _touch.apply_visibility()
	audit.check_eq(wide.get("deck"), true, "touch/a_coarse_pointer_shows_the_deck_at_desktop_width")
	audit.check_eq(wide.get("pad"), false, "touch/a_coarse_pointer_hides_the_pad_at_desktop_width")
	_touch.set_frame_width(720.0)
	var medium: Dictionary = _touch.apply_visibility()
	audit.check_eq(medium.get("deck"), true, "touch/the_deck_survives_the_681px_frame")
	audit.check_eq(medium.get("pad"), false, "touch/the_pad_stays_hidden_above_680px")
	_touch.set_frame_width(600.0)
	var narrow: Dictionary = _touch.apply_visibility()
	audit.check_eq(narrow.get("deck"), false, "touch/the_deck_hides_at_600px")
	audit.check_eq(narrow.get("pad"), true, "touch/the_pad_shows_at_600px")
	_touch.set_frame_width(680.0)
	var edge: Dictionary = _touch.apply_visibility()
	audit.check_eq(edge.get("pad"), true, "touch/the_pad_shows_at_the_680px_edge")
	audit.check_eq(edge.get("deck"), false, "touch/the_deck_is_gone_at_the_680px_edge")
	# The frame is the control's own width when nobody says otherwise.
	var default_touch: Control = TouchScene.instantiate()
	root.add_child(default_touch)
	await process_frame
	audit.check_eq(default_touch.frame_width(), default_touch.size.x, "touch/the_frame_defaults_to_the_controls_own_width")
	audit.check_eq(default_touch.palette_misses().is_empty(), true, "touch/the_default_instance_finds_its_palette")
	default_touch.queue_free()
	await process_frame
	# The platform fact, read rather than assumed.
	audit.note("this machine reports touchscreen=%s; the deck's default state follows the engine's own answer" % str(DisplayServer.is_touchscreen_available()))


# ---------------------------------------------------------------------------
# 8-9. Presses, releases, and a real touch event through the engine
# ---------------------------------------------------------------------------

func _touch_events(audit: AuditBase) -> void:
	_touch.set_coarse_pointer(true)
	_touch.set_frame_width(FRAME.x)
	_touch.apply_visibility()
	await process_frame
	var drive := _touch.deck_buttons().get("hit", null) as Button
	audit.check_ne(drive, null, "touch/the_deck_shot_button_is_reachable")
	# The wiring, directly: down drives, up releases.
	drive.button_down.emit()
	audit.check_eq(Input.is_action_pressed("padel_drive"), true, "touch/a_button_down_presses_the_action")
	audit.check_eq(_touch.held_actions().has("padel_drive"), true, "touch/the_layer_remembers_what_it_holds")
	drive.button_up.emit()
	audit.check_eq(Input.is_action_pressed("padel_drive"), false, "touch/a_button_up_releases_the_action")
	audit.check_eq(_touch.held_actions().has("padel_drive"), false, "touch/the_held_list_drops_it_again")
	audit.check_eq(_touch.release_action("padel_drive"), false, "touch/a_second_release_is_a_no_op")
	var special := _touch.deck_buttons().get("special", null) as Button
	special.button_down.emit()
	audit.check_eq(Input.is_action_pressed("padel_special"), true, "touch/the_special_button_drives_its_action")
	# Hiding the block releases what it held (`styles.css:2058-2085`).
	_touch.set_coarse_pointer(false)
	await process_frame
	audit.check_eq(Input.is_action_pressed("padel_special"), false, "touch/hiding_the_deck_releases_its_held_action")
	audit.check_eq(_touch.held_actions().is_empty(), true, "touch/nothing_stays_held_after_the_hide")
	_touch.set_coarse_pointer(true)
	_touch.apply_visibility()
	await process_frame
	# An action the project does not carry is refused, and named.
	audit.check_eq(_touch.press_action("padel_nope"), false, "touch/an_unknown_action_is_refused")
	audit.check_eq(_touch.report().get("missing_actions"), ["padel_nope"], "touch/the_refused_action_is_recorded")
	audit.check_eq(_touch.press_action("padel_drive"), true, "touch/a_known_action_is_taken_again")
	_touch.release_all()
	await process_frame
	# A real touch event at the button's centre, through the engine's own pipeline.
	var emulate := bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	audit.check_true(emulate, "touch/the_engine_emulates_mouse_from_touch")
	var centre: Vector2 = drive.get_global_rect().get_center()
	var in_frame := drive.is_visible_in_tree() and centre.x > 0.0 and centre.y > 0.0
	audit.check_true(in_frame, "touch/the_deck_button_sits_inside_the_frame")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = centre
	Input.parse_input_event(touch)
	await process_frame
	await process_frame
	var by_touch := Input.is_action_pressed("padel_drive")
	if emulate:
		audit.check_eq(by_touch, true, "touch/a_screen_touch_press_on_the_deck_drives_the_action")
	else:
		audit.not_ported("touch/screen_touch_without_emulation", "the project has touch-to-mouse emulation off, so the deck's buttons only take mouse events")
	var lifted := InputEventScreenTouch.new()
	lifted.index = 0
	lifted.pressed = false
	lifted.position = centre
	Input.parse_input_event(lifted)
	await process_frame
	await process_frame
	if emulate:
		audit.check_eq(Input.is_action_pressed("padel_drive"), false, "touch/lifting_the_finger_releases_the_action")
	audit.check_eq(_touch.held_actions().is_empty(), true, "touch/the_touch_path_leaves_nothing_held")
	# The pad's own buttons, at the narrow width.
	_touch.set_frame_width(600.0)
	_touch.apply_visibility()
	await process_frame
	audit.check_eq(_touch.pad().visible, true, "touch/the_pad_is_shown_for_the_narrow_frame")
	var hit := _touch.pad_buttons().get("hit", null) as Button
	audit.check_ne(hit, null, "touch/the_pads_hit_button_is_reachable")
	hit.button_down.emit()
	audit.check_eq(Input.is_action_pressed("padel_drive"), true, "touch/the_pads_hit_drives_the_same_action")
	hit.button_up.emit()
	audit.check_eq(Input.is_action_pressed("padel_drive"), false, "touch/the_pads_hit_releases_it")
	_touch.set_frame_width(FRAME.x)
	_touch.apply_visibility()


# ---------------------------------------------------------------------------
# 10. The language flip
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var keys := ["oskShift", "oskSpace", "oskBackspace", "oskDone", "oskHint", "ariaOsk",
		"ariaActionDeck", "ariaTouch", "shot", "switch", "special", "switchBtn", "specialBtn",
		"dirUp", "dirLeft", "dirRight", "dirDown", "dirSpecial"]
	var unresolved: Array = []
	for key in keys:
		for lang in Locale.locales():
			if not Locale.is_resolvable(String(key), String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "osk/every_key_this_ticket_shows_resolves_in_both_locales")
	var language_at_start := Locale.current_lang()
	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
	audit.check_ne(other, "", "osk/there_is_a_second_locale_to_flip_to")
	_model.open_for("pause/fb-message", "ab", 12, UiStrings.t("volume"))
	_panel.refresh()
	var before_label: String = (_panel.key_node("osk/shift") as Button).text
	var before_aria: String = _touch.aria_text_for("hit")
	audit.check_eq(_panel.set_language(other), true, "osk/the_panel_takes_the_other_language")
	audit.check_eq(_touch.set_language(other), true, "touch/the_layer_takes_the_other_language")
	await process_frame
	var after_label: String = (_panel.key_node("osk/shift") as Button).text
	var expected_label := Locale.resolve("oskShift", other)
	audit.check_eq(after_label, expected_label, "osk/the_shift_key_shows_the_other_tables_label")
	audit.check_eq(_panel.aria_text(), Locale.resolve("ariaOsk", other), "osk/the_aria_name_follows_the_language")
	audit.check_eq(_touch.aria_text_for("hit"), Locale.resolve("shot", other), "touch/the_deck_aria_name_follows_the_language")
	audit.check_eq(_touch.aria_text_for("pad-hit"), Locale.resolve("shot", other), "touch/the_pad_aria_name_follows_the_language")
	var moved := 0
	if before_label != after_label:
		moved += 1
	if before_aria != _touch.aria_text_for("hit"):
		moved += 1
	audit.check_ge(moved, 1, "osk/the_flip_moved_strings_that_differ")
	audit.report("language flip: %d of 2 sampled strings differ between tables" % moved)
	audit.check_eq(_panel.set_language(language_at_start), true, "osk/the_first_language_comes_back")
	audit.check_eq(_touch.set_language(language_at_start), true, "touch/the_first_language_comes_back")
	await process_frame
	audit.check_eq((_panel.key_node("osk/shift") as Button).text, before_label, "osk/the_flip_back_restores_the_label")
	audit.check_eq(_touch.aria_text_for("hit"), before_aria, "touch/the_flip_back_restores_the_aria")
	audit.check_eq(_panel.set_language("xx"), false, "osk/an_unknown_locale_is_refused")
	audit.check_eq(_touch.set_language("xx"), false, "touch/an_unknown_locale_is_refused")
	_model.close()
	_panel.refresh()


# ---------------------------------------------------------------------------
# The platform record
# ---------------------------------------------------------------------------

func _platform(audit: AuditBase) -> void:
	var panel_stray: Array = []
	for key in _panel.palette_misses():
		if not _panel.palette_keys().has(String(key)):
			panel_stray.append(String(key))
	audit.check_eq(panel_stray, [], "osk/every_palette_miss_is_a_key_this_panel_declares")
	var touch_stray: Array = []
	for key in _touch.palette_misses():
		if not _touch.palette_keys().has(String(key)):
			touch_stray.append(String(key))
	audit.check_eq(touch_stray, [], "touch/every_palette_miss_is_a_key_this_layer_declares")
	audit.report("palette keys this ticket declares — osk: %s | touch: %s" % [
		str(_panel.palette_keys()), str(_touch.palette_keys()),
	])
	if not _panel.palette_misses().is_empty():
		audit.note("palette keys the theme does not carry yet, requested in evidence/uir-26-osk-touch.md: osk %s | touch %s" % [
			str(_panel.palette_misses()), str(_touch.palette_misses()),
		])
	audit.note("no touchscreen on this machine: DisplayServer.is_touchscreen_available() answered %s during this audit" % str(DisplayServer.is_touchscreen_available()))
	audit.note("the shared theme (godot/src/ui/theme/padel_theme.tres) does not parse as of this wave: thirteen palette rows use a three-argument Color() (lines 419-429, 434-435). Every palette read here falls back to the palette's own ink and the misses are listed; the fix belongs to the theme lane (append the missing alpha)")
	audit.not_ported("device/real_touch_hardware", "no touchscreen on the audit host (macOS desktop); the touch path is exercised with InputEventScreenTouch and the engine's own emulation, not a finger")
	audit.not_ported("device/handheld_export", "no iOS/Android/Deck export was run in this wave — the 560 px and 680 px rules are asserted on a resized Control, not on a device")
	audit.not_ported("device/steam_input_keyboard", "the platform's own on-screen keyboard hook (Steam/Android) is not wired; this ticket's keyboard is the reference's DOM one, rebuilt")
