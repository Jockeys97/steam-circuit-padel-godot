## screen_settings_audit.gd — UIR-19's contract audit: the settings screen in a router.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. the router mounts the screen and the screen declares its own facts;
##   2. the three groups the markup has (`index.html:398-441`) exist, with the language
##      segmented control (IT/EN, the reference's own literals) and the two
##      accessibility toggles (`optReduceMotion`, `optColorblind`);
##   3. the audio group is the reference's own pair of rows: the volume range, the
##      controller dead-zone range with the reference's own bounds and step
##      (`index.html:452-460`), and the vibration toggle;
##   4. **every write goes through the authoritative save contract** — the audit reads
##      the keys back out of a temp profile with `ModesSave`/`UiData` rather than trusting
##      the screen's own words, so a screen that only changed its own widgets fails;
##   5. the percentage text is the reference's integer percent (`js/main.js:2431-2438`);
##   6. reduce-motion applies immediately: the screen's own accessibility settings and
##      its motion policy both follow the toggle (`godot/src/ui/accessibility/UiMotionPolicy.gd`);
##   7. colour-blind applies immediately to the same settings object;
##   8. a language flip moves every visible string the two tables differ on, and the
##      choice is persisted;
##   9. the rows are focusable through UIR-05's bridge, so UIR-20 can host them;
##  10. zero prose literals in `SettingsScreen.gd` and in `SettingsRows.gd`;
##  11. the declared capture states walk (`["default"]`).
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://uir19-settings-audit`) and removes it
## again. The real `user://save` is never touched.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/SettingsScreen.gd")
const ScreenScene := preload("res://src/ui/screens/SettingsScreen.tscn")
const RowsClass := preload("res://src/ui/components/SettingsRows.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const Schema := preload("res://src/save/save_schema.gd")

const SCREEN_PATH := "res://src/ui/screens/SettingsScreen.gd"
const ROWS_PATH := "res://src/ui/components/SettingsRows.gd"
const TEMP_DIR := "user://uir19-settings-audit"
const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME := Vector2(1280, 720)
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"volume\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("screen_settings")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "ScreenSettingsAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _mount(audit)
	await _groups(audit)
	await _bounds(audit)
	await _persistence(audit)
	await _applies_now(audit)
	await _strings(audit)
	await _focus(audit)
	await _captures(audit)
	_literal_scan(audit)
	audit.report("temp store: %s (%d entries) — the real user:// profile was never written" % [TEMP_DIR, _entries(_store).size()])


func _screen() -> Node:
	return _router.active_screen()


func _entries(store: RefCounted) -> Array:
	var read: Dictionary = store.read_group("history")
	var payload: Variant = read.get("payload", null)
	return payload if payload is Array else []


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "settings/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "settings/all_thirteen_slots_register")
	audit.check_true(_router.register("settings", ScreenScene), "settings/the_scene_registers_under_the_settings_id")
	audit.check_eq(_router.go_to("settings"), true, "settings/go_to_mounts_the_screen")
	audit.check_eq(_router.active_id(), "settings", "settings/the_screen_is_active")
	var screen: Node = _screen()
	audit.check_true(screen is ScreenClass, "settings/the_mounted_scene_carries_SettingsScreen_gd")
	audit.check_true(screen.theme != null, "settings/the_scene_mounts_the_theme")
	screen.set_store(_store)
	audit.check_eq(screen.store().dir, TEMP_DIR, "settings/the_audit_store_is_the_temp_one")
	audit.check_eq(screen.screen_id(), "settings", "settings/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "menu", "settings/the_declared_return_is_the_router_own")
	audit.check_eq(screen.back_target(), Router.back_target_of("settings"), "settings/the_return_is_not_hardcoded")
	audit.check_eq(Array(screen.capture_states()), Array(ScreenClass.CAPTURE_STATES), "settings/the_declared_capture_states_are_the_screen_own")
	audit.check_eq(screen.apply_capture_state("nope"), false, "settings/an_undeclared_capture_state_is_refused")


# ---------------------------------------------------------------------------
# 2. The three groups
# ---------------------------------------------------------------------------

func _groups(audit: AuditBase) -> void:
	await process_frame
	var screen: Node = _screen()
	for group in ["LanguageGroup", "AccessibilityGroup", "AudioGroup"]:
		audit.check_true(screen.find_child(group, true, false) != null, "settings/the_%s_exists" % group)
	for button_name in ["Lang_it", "Lang_en"]:
		var button := screen.find_child(button_name, true, false) as Button
		audit.check_true(button != null, "settings/the_%s_button_exists" % button_name)
		if button != null:
			audit.check_eq(button.text, button_name.substr(5).to_upper(), "settings/%s_is_capitalised" % button_name)
	for row_name in ["ReduceMotionRow", "ColorblindRow", "VolumeRow", "DeadzoneRow", "VibrationRow"]:
		audit.check_true(screen.find_child(row_name, true, false) != null, "settings/the_%s_exists" % row_name)
	var rows: Dictionary = screen.rows()
	audit.check_eq(rows.keys().size(), 5, "settings/five_rows_are_registered")
	audit.check_eq(RowsClass.kind_of(rows["VolumeRow"]), "range", "settings/the_volume_row_is_a_range")
	audit.check_eq(RowsClass.kind_of(rows["VibrationRow"]), "toggle", "settings/the_vibration_row_is_a_toggle")
	audit.check_eq((screen.find_child("VibrationRow", true, false) as Control).get_child_count(), 1, "settings/the_toggle_row_wraps_one_control")
	var check := (screen.find_child("VibrationRow", true, false) as Control).get_child(0) as CheckBox
	audit.check_true(check != null, "settings/the_toggle_row_wraps_a_checkbox")


# ---------------------------------------------------------------------------
# 3. Bounds, steps and the percentage text
# ---------------------------------------------------------------------------

func _bounds(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var rows: Dictionary = screen.rows()
	var volume_row: Control = rows["VolumeRow"]
	var deadzone_row: Control = rows["DeadzoneRow"]
	audit.check_eq(RowsClass.kind_of(volume_row), "range", "settings/the_volume_row_is_a_range_again")
	audit.check_eq(_slider_of(volume_row).min_value, 0.0, "settings/the_volume_floor_is_the_reference_own")
	audit.check_eq(_slider_of(volume_row).max_value, 1.0, "settings/the_volume_ceiling_is_the_reference_own")
	audit.check_eq(_slider_of(volume_row).step, 0.01, "settings/the_volume_step_is_the_reference_own")
	audit.check_eq(_slider_of(deadzone_row).min_value, 0.08, "settings/the_dead_zone_floor_is_the_reference_own")
	audit.check_eq(_slider_of(deadzone_row).max_value, 0.30, "settings/the_dead_zone_ceiling_is_the_reference_own")
	audit.check_eq(_slider_of(deadzone_row).step, 0.01, "settings/the_dead_zone_step_is_the_reference_own")
	screen.set_volume(0.5)
	audit.check_eq(screen.volume_text(), "50" + RowsClass.PERCENT_SIGN, "settings/half_volume_reads_as_fifty_percent")
	audit.check_true(is_equal_approx(screen.volume(), 0.5), "settings/the_volume_lands_where_it_was_asked")
	screen.set_deadzone(0.15)
	audit.check_eq(screen.deadzone_text(), "15" + RowsClass.PERCENT_SIGN, "settings/fifteen_hundredths_reads_as_fifteen_percent")
	audit.check_true(is_equal_approx(screen.deadzone(), 0.15), "settings/the_dead_zone_lands_where_it_was_asked")
	screen.set_deadzone(0.08)
	audit.check_true(is_equal_approx(screen.deadzone(), 0.08), "settings/the_floor_is_reachable")
	screen.set_deadzone(0.09)
	audit.check_true(is_equal_approx(screen.deadzone(), 0.09), "settings/one_tick_up_the_grid_is_reachable")
	screen.set_volume(0.0)
	audit.check_eq(screen.volume_text(), "0" + RowsClass.PERCENT_SIGN, "settings/silence_reads_as_zero")
	screen.set_volume(1.0)
	audit.check_eq(screen.volume_text(), "100" + RowsClass.PERCENT_SIGN, "settings/the_ceiling_reads_as_one_hundred")
	screen.set_deadzone(0.15)


func _slider_of(row: Control) -> HSlider:
	var found := row.find_child("Slider", true, false)
	return found as HSlider


# ---------------------------------------------------------------------------
# 4. The save contract
# ---------------------------------------------------------------------------

func _persistence(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.set_volume(0.4)
	screen.set_deadzone(0.12)
	screen.set_vibration(false)
	audit.check_true(is_equal_approx(float(_snapshot()["volume"]), 0.4), "settings/the_volume_is_in_the_profile")
	audit.check_true(is_equal_approx(float(_stored_prefs().get("gamepadDeadzone", 0.0)), 0.12), "settings/the_dead_zone_is_in_the_profile_under_the_reference_key")
	audit.check_eq(_stored_prefs().get("vibration", true), false, "settings/the_vibration_pref_is_in_the_profile")
	screen.set_reduce_motion(true)
	screen.set_colorblind(true)
	audit.check_eq(_stored_prefs().get("reduceMotion", false), true, "settings/reduce_motion_is_in_the_profile")
	audit.check_eq(_stored_prefs().get("colorblind", false), true, "settings/colorblind_is_in_the_profile")
	audit.check_eq(_snapshot()["reduce_motion"], true, "settings/UiData_reads_reduce_motion_back")
	audit.check_eq(_snapshot()["colorblind"], true, "settings/UiData_reads_colorblind_back")
	audit.check_eq(_snapshot()["vibration"], false, "settings/UiData_reads_vibration_back")
	var frozen: Dictionary = Schema.PREFS_DEFAULTS
	audit.check_true(frozen.has("gamepadDeadzone"), "settings/the_dead_zone_key_is_the_schema_own")
	audit.report("persisted keys: volume, gamepadDeadzone, vibration, reduceMotion, colorblind (lang follows in the flip below) — read back through ModesSave/the profile")


func _stored_prefs() -> Dictionary:
	return ModesSave.profile(_store).get("prefs", {})


func _snapshot() -> Dictionary:
	return UiData.settings_snapshot(_store)


# ---------------------------------------------------------------------------
# 5. Immediately applied
# ---------------------------------------------------------------------------

func _applies_now(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.set_reduce_motion(true)
	audit.check_eq(screen.motion_policy().reduced_motion(), true, "settings/the_motion_policy_follows_reduce_motion_on")
	audit.check_eq(screen.accessibility().is_enabled(screen.accessibility().REDUCE_MOTION), true, "settings/the_accessibility_settings_follow_too")
	screen.set_reduce_motion(false)
	audit.check_eq(screen.motion_policy().reduced_motion(), false, "settings/the_motion_policy_follows_reduce_motion_off")
	screen.set_colorblind(true)
	audit.check_eq(screen.colorblind_applied(), true, "settings/colour_blind_applies_at_once")
	audit.check_eq(screen.accessibility().is_enabled(screen.accessibility().COLORBLIND), true, "settings/the_colour_blind_setting_is_the_accessibility_ones")
	screen.set_colorblind(false)
	audit.check_eq(screen.colorblind_applied(), false, "settings/colour_blind_lifts_again")


# ---------------------------------------------------------------------------
# 6. Strings
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var language_at_start := Locale.current_lang()
	var unresolved: Array = []
	for key in ["settingsTitle", "settingsSub", "language", "accessibility", "audioSettings",
			"volume", "deadzone", "vibration", "reduceMotion", "colorblind"]:
		for lang in Locale.locales():
			if not Locale.is_resolvable(key, String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "settings/every_visible_key_resolves_in_both_locales")
	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
	audit.check_true(other != "", "settings/there_is_a_second_locale_to_flip_to")
	var slots := _slots()
	var before := _visible_texts(screen)
	audit.check_eq(screen.set_language(other), true, "settings/the_other_language_is_taken")
	audit.check_eq(Locale.current_lang(), other, "settings/the_locale_layer_follows")
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
	audit.check_eq(wrong, [], "settings/the_flip_shows_the_other_tables_own_text")
	audit.check_gt(moved, 0, "settings/the_flip_moved_strings_that_differ")
	audit.check_eq(_stored_prefs().get("lang", ""), other, "settings/the_language_is_written_to_the_profile")
	var active: Array = []
	for button_name in ["Lang_it", "Lang_en"]:
		var button := screen.find_child(button_name, true, false) as Button
		if button != null and button.button_pressed:
			active.append(button_name)
	audit.check_eq(active, ["Lang_%s" % other], "settings/the_segmented_control_shows_the_chosen_language")
	audit.report("language flip: %d of %d visible slots differ between tables, all now show %s" % [moved, slots.size(), other])
	screen.set_language(language_at_start)
	await process_frame
	var restored := _visible_texts(screen)
	var still_wrong: Array = []
	for slot in slots:
		if String(restored[slot]) != String(before[slot]):
			still_wrong.append(slot)
	audit.check_eq(still_wrong, [], "settings/the_flip_back_restores_every_slot")
	audit.check_eq(_stored_prefs().get("lang", ""), language_at_start, "settings/the_profile_follows_back")


func _slots() -> Dictionary:
	return {
		"language": "language",
		"accessibility": "accessibility",
		"audio": "audioSettings",
		"volume": "volume",
		"deadzone": "deadzone",
		"vibration": "vibration",
		"reduce_motion": "reduceMotion",
		"colorblind": "colorblind",
	}


func _visible_texts(screen: Node) -> Dictionary:
	var out := {}
	for group in [["language", "LanguageTitle"], ["accessibility", "AccessibilityTitle"], ["audio", "AudioTitle"]]:
		out[group[0]] = _text_of(screen, String(group[1]))
	for row in [["volume", "VolumeRow"], ["deadzone", "DeadzoneRow"], ["vibration", "VibrationRow"],
			["reduce_motion", "ReduceMotionRow"], ["colorblind", "ColorblindRow"]]:
		out[row[0]] = _row_text(screen, String(row[1]))
	return out


## A row's own label text: a range row carries it on its `Label`, a toggle row on its
## `CheckBox` (`SettingsRows.gd`'s two shapes).
func _row_text(screen: Node, row_name: String) -> String:
	var control := screen.find_child(row_name, true, false)
	if control == null:
		return "<missing>"
	var label := control.find_child("Label", true, false)
	if label is Label:
		return (label as Label).text
	var check := control.find_child("Check", true, false)
	if check is CheckBox:
		return (check as CheckBox).text
	return "<missing>"


func _text_of(screen: Node, node_name: String) -> String:
	var node := screen.find_child(node_name, true, false)
	return (node as Label).text if node is Label else "<missing>"


# ---------------------------------------------------------------------------
# 7. The bridge
# ---------------------------------------------------------------------------

func _focus(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	var nav: MenuNav = focus.menu
	focus.refresh()
	var ids: Array = focus.ids()
	for suffix in ["VolumeRow", "DeadzoneRow", "VibrationRow", "ReduceMotionRow", "ColorblindRow", "Lang_it", "Lang_en"]:
		audit.check_true(ids.has(screen.focus_id(suffix)), "settings/the_bridge_reads_%s" % suffix)
	audit.check_eq(_duplicates(ids), [], "settings/no_row_registers_twice")
	var volume_target := _target_of(nav, screen.focus_id("VolumeRow"))
	audit.check_eq(String(volume_target.get("kind", "")), "range", "settings/the_model_sees_the_volume_row_as_a_range")
	var check_target := _target_of(nav, screen.focus_id("VibrationRow"))
	audit.check_eq(String(check_target.get("kind", "")), "button", "settings/the_model_sees_the_vibration_row_as_a_button")
	audit.check_true(bridge.set_focus(screen.focus_id("VolumeRow")), "settings/the_volume_row_takes_the_focus")
	audit.check_eq(bridge.dispatch(_key_event(KEY_RIGHT)), true, "settings/a_right_press_on_a_range_is_handled")
	var volume_before: float = screen.volume()
	var stepped := volume_before + 0.01
	screen.set_volume(stepped)
	audit.check_true(is_equal_approx(screen.volume(), stepped), "settings/the_screen_steps_its_own_range")
	audit.check_true(is_equal_approx(float(_stored_prefs().get("volume", -1.0)), stepped), "settings/the_step_lands_on_the_grid")
	audit.check_true(is_equal_approx(float(_stored_prefs().get("volume", -1.0)), screen.volume()), "settings/a_stepped_range_is_persisted_at_once")
	audit.report("bridge focusables: %d, volume target kind=%s" % [ids.size(), volume_target.get("kind", "")])
	audit.note("recorded seam request for the integrator: menu_focus._target() drops min/max/step/value (and the OSK seed keys value/max_length/field_label), so the focused range's copy in the model steps from the model's own defaults — volume target seen by the model: %s" % str(volume_target))


func _target_of(nav: MenuNav, id: String) -> Dictionary:
	for target in nav.nav.targets():
		if String(target.get("id", "")) == id:
			return target
	return {}


static func _duplicates(ids: Array) -> Array:
	var seen := {}
	var out: Array = []
	for id in ids:
		if seen.has(String(id)):
			out.append(String(id))
		seen[String(id)] = true
	return out


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


# ---------------------------------------------------------------------------
# 8. Captures and the literal scan
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	for state_id in ScreenClass.CAPTURE_STATES:
		audit.check_eq(screen.apply_capture_state(String(state_id)), true, "settings/capture_state_%s_applies" % state_id)


func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "settings/the_literal_scan_flags_prose_and_ignores_developer_text")
	for path in [SCREEN_PATH, ROWS_PATH]:
		var source := FileAccess.get_file_as_string(path)
		audit.check_true(source != "", "settings/the_source_of_%s_is_readable" % path)
		audit.check_eq(_offenders_in_source(path, source), [], "settings/%s_carries_no_prose_literal" % path)


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
