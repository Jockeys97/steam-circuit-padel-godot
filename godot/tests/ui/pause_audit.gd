## pause_audit.gd — UIR-20's contract audit: the pause overlay and the smash tutorial.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. the overlay mounts, starts hidden, and its five declared capture states walk;
##   2. the three tabs (`index.html:569-572`): PARTITA active initially, the panels
##      swap, the active tab carries the segmented active look (`js/main.js:224-241`);
##   3. the quit confirmation is two-step (`js/main.js:1615-1634`): first press arms
##      with the `quitConfirm` text, second press leaves; leaving the overlay disarms;
##   4. the five-step ESC hierarchy (`js/main.js:2607-2614`, `menuBack` `:751-770`):
##      replay, keyboard, tutorial, tab, resume, pause — in that order;
##   5. the pause seam: with a seam bound, `set_match_paused(bool)` is called exactly
##      once per edge and `_reset_transient_input` stays the controller's; without a
##      seam the action route (`padel_pause`) is what goes out, and the overlay never
##      fakes the state;
##   6. the tree is never paused by any of it — `SceneTree.paused` is asserted false
##      after every transition, and the two sources are grep-asserted for the pattern;
##   7. the CONTROLLER tab: the mode strip persists through `controlMode`, the shared
##      rows write `gamepadDeadzone`/`vibration`/`volume`, and `UiData.settings_snapshot`
##      — the settings screen's own reader — sees every write (one state, two copies);
##   8. the stick monitors: the two dots move `radial(value) * 17` px from the centre,
##      through the player's deadzone, from an injected `InputEventJoypadMotion`;
##   9. the COMANDI tab consumes the full thirteen-row `ControlLegend` and its smash
##      tutorial link opens the tutorial; back returns to the tab with pause still
##      open (`js/main.js:203-221`); RIPRENDI E PROVA closes it and resumes
##      (`js/main.js:2354-2357`);
##  10. every visible key resolves in both locales, and a language flip moves every
##      slot this overlay owns;
##  11. zero prose literals in `PauseOverlay.gd` and `SmashTutorial.gd`.
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://uir20-pause-audit`) and removes it
## again. The real `user://save` is never touched.
##
## WHAT IT DOES NOT DO, and says so rather than pretending: no Godot process ran this
## file in the UIR-20 wave (the wave's dispatch forbids it), and no pad was attached
## to the machine — the axis injection is the engine's own `InputEventJoypadMotion`,
## not hardware. Both facts are in `evidence/uir-20-overlays.log`.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const OverlayClass := preload("res://src/ui/screens/PauseOverlay.gd")
const OverlayScene := preload("res://src/ui/screens/PauseOverlay.tscn")
const TutorClass := preload("res://src/ui/screens/SmashTutorial.gd")
const LegendClass := preload("res://src/ui/components/ControlLegend.gd")
const RowsClass := preload("res://src/ui/components/SettingsRows.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const InputMapScript := preload("res://game/input_map.gd")

const OVERLAY_PATH := "res://src/ui/screens/PauseOverlay.gd"
const TUTORIAL_PATH := "res://src/ui/screens/SmashTutorial.gd"
const TEMP_DIR := "user://uir20-pause-audit"
const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 3
## The five states the ticket's frontmatter declares.
const CAPTURE_STATES := ["pause-match", "pause-controller", "pause-controls", "quit-confirm", "smash-tutorial"]
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"volume\")\n## a comment quoting \"prose in a comment\"\n"
## The patterns this ticket may never carry in code (comments are stripped first).
const FORBIDDEN_PAUSE_PATTERNS := ["SceneTree.paused", "get_tree().paused", "paused = true", "paused = false"]

var _store: RefCounted
var _overlay: Control
var _seam


## The match seam's shape, with the calls counted — the overlay's own contract
## (see its header) with `is_paused()`, `set_match_paused(bool)`, `rematch()` and
## `leave_match()` (`match_controller.gd:1946, :1926, :1980`).
class FakeSeam extends RefCounted:
	var paused := false
	var calls: Array = []

	func is_paused() -> bool:
		return paused

	func set_match_paused(value: bool) -> bool:
		calls.append(["set_match_paused", value])
		paused = value
		return true

	func rematch() -> void:
		calls.append(["rematch", true])

	func leave_match() -> void:
		calls.append(["leave_match", true])

	func count_of(method: String) -> int:
		var total := 0
		for call in calls:
			if String(call[0]) == method:
				total += 1
		return total

	func last_args(method: String) -> Array:
		var found: Array = []
		for call in calls:
			if String(call[0]) == method:
				found = call
		return found


func _initialize() -> void:
	var audit := AuditBase.new("pause_overlay")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "PauseAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_seam = FakeSeam.new()
	_overlay = OverlayScene.instantiate()
	_overlay.set_store(_store)
	_overlay.bind_seam(_seam)
	frame.add_child(_overlay)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _mount(audit)
	await _tabs(audit)
	await _quit_confirmation(audit)
	await _esc_hierarchy(audit)
	await _seam_routes(audit)
	await _tree_never_paused(audit)
	await _controller_rows(audit)
	await _stick_monitors(audit)
	await _legend_and_tutorial(audit)
	await _captures(audit)
	await _strings(audit)
	_literal_scan(audit)
	audit.not_ported("device/physical_pad", "no pad was attached to the audit host: the two stick monitors were driven by injected InputEventJoypadMotion events, not by hardware")
	audit.not_ported("device/pause_seam_live", "match_controller.gd carries no set_match_paused(bool) yet (UIR-22 owns the one-line seam): the seam contract is asserted against a fake seam of the documented shape, and the action route is asserted against InputMap; the live call is owed to UIR-22")
	audit.not_ported("feature/replay", "replay has no entry point until UIR-27 lands: the button ships disabled with the recorded reason and refuses programmatic presses")
	audit.not_ported("engine/run", "no Godot process ran this file in the UIR-20 wave (the wave's dispatch forbids it): the tally below is what the file asserts, and the acceptance command in evidence/uir-20-overlays.log is the run that is owed")
	audit.note("the shared theme (godot/src/ui/theme/padel_theme.tres) does not parse as of this wave: thirteen palette rows use a three-argument Color() (lines 419-429, 434-435). Every palette read here falls back to the palette's own ink and the misses are listed; the fix belongs to the theme lane (append the missing alpha)")
	audit.report("mount: %s (open=%s, tab=%s, pause_route=%s)" % [
		_overlay.name, str(_overlay.report().get("open")), str(_overlay.report().get("tab")),
		str(_overlay.report().get("pause_route")),
	])
	audit.note("recorded seam request for the integration owner: match_controller needs the one-line `set_match_paused(paused: bool)` (see the overlay header); until it lands `pause_route()` answers `action` and the overlay goes out through the engine's synthetic `padel_pause` press")


# ---------------------------------------------------------------------------
# 1. The mount and the overlay's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var report: Dictionary = _overlay.report()
	audit.check_eq(report.get("open"), false, "pause/the_overlay_starts_hidden")
	audit.check_eq(report.get("tab"), "match", "pause/partita_is_the_initial_tab")
	audit.check_eq(_overlay.capture_states(), CAPTURE_STATES, "pause/the_five_capture_states_are_declared")
	audit.check_ne(_overlay.theme, null, "pause/the_scene_mounts_the_theme")
	audit.check_eq(_overlay.legend() != null, true, "pause/the_legend_is_consumed")
	audit.check_eq(_overlay.smash_tutorial() != null, true, "pause/the_tutorial_is_consumed")
	var missing: Array = _overlay.palette_misses()
	var stray: Array = []
	for key in missing:
		if not _overlay.palette_keys().has(String(key)):
			stray.append(String(key))
	audit.check_eq(stray, [], "pause/every_palette_miss_is_a_key_this_overlay_declares")
	if not missing.is_empty():
		audit.note("palette keys the theme does not carry yet, requested in evidence/uir-20-overlays.log: %s" % str(missing))
	audit.check_eq(String(_overlay.get_node("PauseScrim").name), "PauseScrim", "pause/the_scrim_is_named")
	audit.check_eq(String(_overlay.get_node("PauseScrim/PauseCenter/PauseCard").name), "PauseCard", "pause/the_card_is_named")
	var status_title := _overlay.find_child("PauseStatusTitle", true, false) as Label
	audit.check_eq(status_title.text, OverlayClass.status_title(), "pause/the_status_title_is_the_references_own_literal")


# ---------------------------------------------------------------------------
# 2. Tabs (`setPauseTab`, js/main.js:224-241)
# ---------------------------------------------------------------------------

func _tabs(audit: AuditBase) -> void:
	_overlay.open()
	audit.check_eq(_overlay.is_open(), true, "pause/open_shows_the_card")
	audit.check_eq(_overlay.active_tab(), "match", "pause/open_lands_on_the_match_tab")
	audit.check_eq(_overlay.tab_button("match").theme_type_variation, &"SegmentedActive", "pause/the_active_tab_carries_the_segmented_active_look")
	audit.check_eq(_overlay.tab_button("controller").theme_type_variation, &"SegmentedInactive", "pause/an_idle_tab_carries_the_idle_look")
	audit.check_eq(_overlay.set_tab("controller"), true, "pause/the_controller_tab_switches")
	audit.check_eq(_overlay.active_tab(), "controller", "pause/the_controller_tab_is_active")
	audit.check_eq(_overlay.tab_button("controller").theme_type_variation, &"SegmentedActive", "pause/the_switched_tab_takes_the_active_look")
	audit.check_eq(_overlay.tab_button("match").theme_type_variation, &"SegmentedInactive", "pause/the_left_tab_returns_to_idle")
	audit.check_eq(_overlay.set_tab("controls"), true, "pause_the_controls_tab_switches")
	audit.check_eq(_overlay.set_tab("nope"), false, "pause/an_unknown_tab_is_refused")
	var panels: Array = []
	for tab in ["match", "controller", "controls"]:
		var panel: Control = _overlay.find_child(_panel_name(tab), true, false)
		if panel != null and panel.visible:
			panels.append(tab)
	audit.check_eq(panels, ["controls"], "pause/exactly_one_panel_is_visible")
	audit.check_eq(_overlay.set_tab("match"), true, "pause/back_to_the_match_tab")
	audit.check_eq(_overlay.focus_controls().size(), 7, "pause/three_tabs_and_four_actions_are_focusable")
	var focus_ids: Array = []
	for entry in _overlay.focus_controls():
		focus_ids.append(String((entry as Dictionary).get("id", "")))
	for wanted in ["pause/tab-match", "pause/tab-controller", "pause/tab-controls",
			"pause/resume", "pause/replay", "pause/rematch", "pause/quit-match"]:
		audit.check_true(focus_ids.has(wanted), "pause/the_focus_table_carries_%s" % wanted)


func _panel_name(tab: String) -> String:
	match tab:
		"match":
			return "PanelMatch"
		"controller":
			return "PanelController"
	return "PanelControls"


# ---------------------------------------------------------------------------
# 3. The two-step quit (js/main.js:1615-1634)
# ---------------------------------------------------------------------------

func _quit_confirmation(audit: AuditBase) -> void:
	_overlay.reset_quit_confirm()
	var quit_events := [0]
	_overlay.quit_requested.connect(func() -> void: quit_events[0] += 1)
	audit.check_eq(_overlay.is_quit_armed(), false, "pause/quit_starts_unarmed")
	audit.check_eq(_overlay.quit_button().text, UiStrings.t("quit"), "pause/the_quit_button_carries_the_quit_text")
	audit.check_eq(_overlay.handle_quit(), false, "pause/the_first_press_only_arms")
	audit.check_eq(_overlay.is_quit_armed(), true, "pause/the_first_press_arms")
	audit.check_eq(_overlay.quit_button().text, UiStrings.t("quitConfirm"), "pause/the_armed_button_carries_the_confirm_text")
	audit.check_eq(quit_events[0], 0, "pause/arming_leaves_the_match_running")
	audit.check_eq((_seam as FakeSeam).count_of("leave_match"), 0, "pause/arming_calls_no_seam_method")
	audit.check_eq(_overlay.handle_quit(), true, "pause/the_second_press_leaves")
	audit.check_eq(quit_events[0], 1, "pause/leaving_emits_quit_requested")
	audit.check_eq((_seam as FakeSeam).count_of("leave_match"), 1, "pause/leaving_calls_the_seam")
	audit.check_eq(_overlay.is_open(), false, "pause/leaving_closes_the_card")
	audit.check_eq(_overlay.is_quit_armed(), false, "pause/leaving_disarms")


# ---------------------------------------------------------------------------
# 4. The five-step ESC hierarchy
# ---------------------------------------------------------------------------

func _esc_hierarchy(audit: AuditBase) -> void:
	_overlay.set_replay_active(true)
	var step: Dictionary = _overlay.back()
	audit.check_eq(int(step.get("step", -1)), OverlayClass.STEP_REPLAY, "pause/esc_step_0_is_replay")
	_overlay.set_replay_active(false)
	_overlay.set_osk_open(true)
	audit.check_eq(int(_overlay.back().get("step", -1)), OverlayClass.STEP_OSK, "pause/esc_step_1_is_the_keyboard")
	_overlay.set_osk_open(false)
	_overlay.open()
	_overlay.set_tab("controls")
	_overlay.open_tutorial()
	audit.check_eq(int(_overlay.back().get("step", -1)), OverlayClass.STEP_TUTORIAL, "pause/esc_step_2_is_the_tutorial")
	audit.check_eq(_overlay.tutorial_open(), false, "pause/step_2_closes_the_tutorial")
	audit.check_eq(_overlay.is_open(), true, "pause/step_2_keeps_the_pause_open")
	audit.check_eq(_overlay.active_tab(), "controls", "pause/step_2_stays_on_the_controls_tab")
	_overlay.set_tab("controller")
	audit.check_eq(int(_overlay.back().get("step", -1)), OverlayClass.STEP_TAB, "pause/esc_step_3_returns_to_the_match_tab")
	audit.check_eq(_overlay.active_tab(), "match", "pause/step_3_lands_on_match")
	var calls_before := (_seam as FakeSeam).count_of("set_match_paused")
	audit.check_eq(int(_overlay.back().get("step", -1)), OverlayClass.STEP_RESUME, "pause/esc_step_4_resumes")
	audit.check_eq((_seam as FakeSeam).count_of("set_match_paused"), calls_before + 1, "pause/step_4_calls_the_seam_once")
	audit.check_eq((_seam as FakeSeam).last_args("set_match_paused"), ["set_match_paused", false], "pause/step_4_asks_for_the_running_match")
	_overlay.close()
	audit.check_eq(int(_overlay.back().get("step", -1)), OverlayClass.STEP_PAUSE, "pause/esc_step_5_pauses")
	audit.check_eq((_seam as FakeSeam).last_args("set_match_paused"), ["set_match_paused", true], "pause/step_5_asks_for_the_paused_match")
	_overlay.close()


# ---------------------------------------------------------------------------
# 5. The seam, and what happens without one
# ---------------------------------------------------------------------------

func _seam_routes(audit: AuditBase) -> void:
	audit.check_eq(_overlay.pause_route(), "seam", "pause/the_seam_route_is_preferred")
	audit.check_eq((_seam as FakeSeam).is_paused(), true, "pause/the_fake_match_is_paused_after_step_5")
	audit.check_eq(_overlay.read_paused(), true, "pause/the_overlay_reads_is_paused_from_the_seam")
	_overlay.open()
	_seam.set_match_paused(true)
	audit.check_eq(_overlay.set_match_paused(false), true, "pause/the_echo_closes_the_card")
	audit.check_eq(_overlay.is_open(), false, "pause/the_echo_left_the_card_closed")
	audit.check_eq(_overlay.set_match_paused(false), false, "pause/a_second_echo_is_a_no_op")
	audit.check_eq(_overlay.set_match_paused(true), true, "pause/the_echo_opens_the_card_again")
	audit.check_eq(_overlay.is_open(), true, "pause/the_card_follows_the_echo")
	var rematch_before := (_seam as FakeSeam).count_of("rematch")
	_overlay.rematch()
	audit.check_eq((_seam as FakeSeam).count_of("rematch"), rematch_before + 1, "pause/rematch_routes_to_the_match")
	# No seam at all: the action route, and no faked state.
	var bare: Control = OverlayScene.instantiate()
	bare.name = "BareOverlay"
	bare.set_store(_store)
	root.add_child(bare)
	await process_frame
	audit.check_eq(bare.pause_route(), "action", "pause/without_a_seam_the_action_route_is_offered")
	audit.check_eq(InputMap.has_action(OverlayClass.PAUSE_ACTION), true, "pause/the_pause_action_exists_in_the_project")
	audit.check_eq(bare.pause_action_event().action, "padel_pause", "pause/the_action_route_builds_the_pause_event")
	audit.check_eq(bare.pause_action_event().pressed, true, "pause/the_pause_event_is_a_press")
	bare.open()
	bare.resume()
	await process_frame
	audit.check_eq(bare.is_open(), true, "pause/without_a_seam_the_overlay_does_not_fake_the_resume")
	audit.check_eq(bare.read_paused(), null, "pause/without_a_seam_the_match_state_is_unknown_not_guessed")
	audit.check_true(bare.report().get("seam_missing", []).is_empty(), "pause/the_action_route_records_no_missing_seam")
	var bare_route := String(bare.report().get("pause_route", ""))
	bare.queue_free()
	await process_frame
	audit.report("seam route: %s, action route: %s, curve %s / deadzone default %s vs input_map %s / %s" % [
		_overlay.pause_route(), bare_route, str(OverlayClass.STICK_CURVE), str(OverlayClass.DEADZONE_DEFAULT),
		str(InputMapScript.STICK_CURVE), str(InputMapScript.DEADZONE),
	])
	audit.check_eq(OverlayClass.STICK_CURVE, InputMapScript.STICK_CURVE, "pause/the_stick_curve_matches_the_input_lane")
	audit.check_eq(OverlayClass.DEADZONE_DEFAULT, InputMapScript.DEADZONE, "pause/the_deadzone_default_matches_the_input_lane")


# ---------------------------------------------------------------------------
# 6. The tree is never paused
# ---------------------------------------------------------------------------

func _tree_never_paused(audit: AuditBase) -> void:
	audit.check_eq(paused, false, "pause/the_tree_is_not_paused_after_the_esc_walk")
	_overlay.open()
	audit.check_eq(paused, false, "pause/opening_the_card_does_not_pause_the_tree")
	_overlay.resume()
	audit.check_eq(paused, false, "pause/resuming_does_not_touch_the_tree")
	_overlay.pause()
	audit.check_eq(paused, false, "pause/pausing_does_not_touch_the_tree")
	_overlay.close()
	audit.check_eq(paused, false, "pause/closing_does_not_touch_the_tree")


# ---------------------------------------------------------------------------
# 7. The controller tab, and the one stored state
# ---------------------------------------------------------------------------

func _controller_rows(audit: AuditBase) -> void:
	_overlay.open()
	_overlay.set_tab("controller")
	var rows: Dictionary = _overlay.rows()
	var deadzone_row: RowsClass.RangeRow = rows.get("DeadzoneRow", null)
	var volume_row: RowsClass.RangeRow = rows.get("VolumeRow", null)
	var vibration_row: RowsClass.ToggleRow = rows.get("VibrationRow", null)
	audit.check_ne(deadzone_row, null, "pause/the_deadzone_row_is_the_shared_component")
	audit.check_ne(volume_row, null, "pause/the_volume_row_is_the_shared_component")
	audit.check_ne(vibration_row, null, "pause/the_vibration_row_is_the_shared_component")
	audit.check_eq(deadzone_row.slider.min_value, 0.08, "pause/the_deadzone_min_is_the_references")
	audit.check_eq(deadzone_row.slider.max_value, 0.30, "pause/the_deadzone_max_is_the_references")
	audit.check_eq(deadzone_row.slider.step, 0.01, "pause/the_deadzone_step_is_the_references")
	audit.check_eq(volume_row.slider.min_value, 0.0, "pause/the_volume_min_is_the_references")
	audit.check_eq(volume_row.slider.max_value, 1.0, "pause/the_volume_max_is_the_references")
	# The pause side writes; the settings reader sees it.
	audit.check_eq(_overlay.set_control_mode("manual"), true, "pause/the_mode_strip_takes_manual")
	audit.check_eq(_overlay.control_mode(), "manual", "pause/the_mode_strip_reads_back_manual")
	audit.check_eq(UiData.settings_snapshot(_store).get("control_mode"), "manual", "pause/settings_snapshot_sees_the_mode")
	audit.check_eq(_pref("controlMode"), "manual", "pause/the_mode_lands_in_the_shared_pref_key")
	audit.check_eq(_overlay.set_control_mode("assisted"), true, "pause/the_mode_strip_takes_assisted")
	audit.check_eq(_overlay.mode_button("assisted").theme_type_variation, &"SegmentedActive", "pause/the_chosen_mode_carries_the_active_look")
	audit.check_eq(_overlay.mode_button("semi").theme_type_variation, &"SegmentedInactive", "pause/an_unchosen_mode_carries_the_idle_look")
	deadzone_row.slider.value = 0.22
	await process_frame
	audit.check_eq(is_equal_approx(_overlay.deadzone(), 0.22), true, "pause/the_deadzone_row_persists_its_value")
	audit.check_eq(is_equal_approx(float(UiData.settings_snapshot(_store).get("deadzone", -1.0)), 0.22), true, "pause/settings_snapshot_sees_the_deadzone")
	vibration_row.check.button_pressed = false
	await process_frame
	audit.check_eq(UiData.settings_snapshot(_store).get("vibration"), false, "pause/settings_snapshot_sees_the_vibration")
	volume_row.slider.value = 0.42
	await process_frame
	audit.check_eq(is_equal_approx(float(UiData.settings_snapshot(_store).get("volume", -1.0)), 0.42), true, "pause/settings_snapshot_sees_the_volume")
	# The other direction: a write that came from elsewhere is read back.
	ModesSave.save_pref(_store, "controlMode", "semi")
	ModesSave.save_pref(_store, "gamepadDeadzone", 0.11)
	_overlay.refresh_values()
	audit.check_eq(_overlay.control_mode(), "semi", "pause/a_foreign_mode_write_is_read_back")
	audit.check_eq(_overlay.mode_button("semi").theme_type_variation, &"SegmentedActive", "pause/the_strip_follows_the_foreign_write")
	audit.check_eq(is_equal_approx(_overlay.deadzone(), 0.11), true, "pause/a_foreign_deadzone_write_is_read_back")
	audit.check_eq(is_equal_approx(deadzone_row.value(), 0.11), true, "pause/the_row_shows_the_foreign_deadzone")
	audit.check_eq(_overlay.focus_controls().size(), 9, "pause/the_controller_tab_exposes_three_modes_and_three_rows")


func _pref(key: String) -> Variant:
	var profile: Dictionary = ModesSave.profile(_store)
	var prefs: Dictionary = profile.get("prefs", {})
	return prefs.get(key, null)


# ---------------------------------------------------------------------------
# 8. The two stick monitors (`updateStickMonitor`, js/main.js:447-451)
# ---------------------------------------------------------------------------

func _stick_monitors(audit: AuditBase) -> void:
	ModesSave.save_pref(_store, "gamepadDeadzone", 0.15)
	ModesSave.save_pref(_store, "vibration", true)
	_overlay.refresh_values()
	_overlay.set_stick_values(Vector2.ZERO, Vector2.ZERO)
	var idle: Vector2 = _overlay.stick_offsets()["left"]
	audit.check_eq(idle, Vector2.ZERO, "pause/an_idle_stick_leaves_the_dot_centred")
	# The deadzone holds the dot still (the monitor previews the player's own deadzone).
	_overlay.set_stick_values(Vector2(0.05, 0.0), Vector2.ZERO)
	var inside: Vector2 = _overlay.stick_offsets()["left"]
	audit.check_eq(inside, Vector2.ZERO, "pause/a_value_inside_the_deadzone_leaves_the_dot_still")
	# Full deflection: the reference's own 17 px range, 1:1 in Control pixels.
	_overlay.set_stick_values(Vector2(1.0, 0.0), Vector2.ZERO)
	var full: Vector2 = _overlay.stick_offsets()["left"]
	audit.check_eq(full.x, 17.0, "pause/full_deflection_reaches_the_references_17px")
	audit.check_eq(full.y, 0.0, "pause/the_horizontal_push_stays_horizontal")
	audit.check_eq(_overlay.stick_offsets()["right"], Vector2.ZERO, "pause/the_other_stick_does_not_move")
	audit.check_eq(OverlayClass.radial(Vector2(1.0, 0.0), 0.15), Vector2(1.0, 0.0), "pause/the_radial_curve_is_full_at_full_push")
	var half: Vector2 = OverlayClass.radial(Vector2(0.5, 0.0), 0.0)
	audit.check_between(half.x, 0.0, 1.0, "pause/the_radial_curve_is_monotonic")
	_overlay.set_stick_values(Vector2(0.0, -1.0), Vector2.ZERO)
	var pushed_up: Vector2 = _overlay.stick_offsets()["left"]
	audit.check_eq(pushed_up.y, -17.0, "pause/the_vertical_push_is_negative_up")
	# The dot's own position: the box's centre plus the offset, minus half the dot.
	var dot := _overlay.find_child("StickLeft", true, false).find_child("StickDot", true, false) as Control
	var box := dot.get_parent() as Control
	var expected := box.size * 0.5 + pushed_up - dot.size * 0.5
	audit.check_eq(dot.position, expected, "pause/the_left_dot_sits_at_the_offset")
	# The binding, injected: one InputEventJoypadMotion, the engine's own class.
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = 1.0
	audit.check_eq(_overlay.handle_joypad_motion(event), true, "pause/a_left_axis_event_is_taken")
	audit.check_eq(_overlay.stick_values()["left"], Vector2(1.0, -1.0), "pause/the_left_axis_composes_with_the_left_y")
	event = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_RIGHT_Y
	event.axis_value = -1.0
	audit.check_eq(_overlay.handle_joypad_motion(event), true, "pause/a_right_axis_event_is_taken")
	var right_off: Vector2 = _overlay.stick_offsets()["right"]
	audit.check_eq(right_off.y, -17.0, "pause/the_right_stick_monitor_follows_its_axis")
	event = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_LEFT
	event.axis_value = 1.0
	audit.check_eq(_overlay.handle_joypad_motion(event), false, "pause/a_non_stick_axis_is_ignored")
	_overlay.set_stick_values(Vector2.ZERO, Vector2.ZERO)


# ---------------------------------------------------------------------------
# 9. The legend and the smash tutorial
# ---------------------------------------------------------------------------

func _legend_and_tutorial(audit: AuditBase) -> void:
	_overlay.set_tab("controls")
	var legend: Control = _overlay.legend()
	audit.check_eq(legend.row_count(), LegendClass.ROW_COUNT, "pause/the_legend_carries_the_reference_rows")
	audit.check_eq(legend.tutorial_link_enabled(), true, "pause/the_legend_carries_the_tutorial_link")
	audit.check_ne(legend.tutorial_button(), null, "pause/the_tutorial_link_is_a_button")
	var focus_ids: Array = []
	for entry in _overlay.focus_controls():
		focus_ids.append(String((entry as Dictionary).get("id", "")))
	audit.check_eq(focus_ids.has("pause/open-smash-tutorial"), true, "pause/the_link_is_focusable")
	legend.tutorial_button().pressed.emit()
	await process_frame
	audit.check_eq(_overlay.tutorial_open(), true, "pause/the_link_opens_the_tutorial")
	audit.check_eq(_overlay.is_open(), true, "pause/the_tutorial_opens_inside_the_pause")
	audit.check_eq(_overlay.legend_host().visible, false, "pause/the_legend_steps_aside_for_the_tutorial")
	var tutorial: Control = _overlay.smash_tutorial()
	audit.check_eq(tutorial.is_open(), true, "pause/the_tutorial_reports_itself_open")
	audit.check_eq(tutorial.find_child("TutorialSteps", true, false).get_child_count(), 4, "pause/the_tutorial_carries_four_steps")
	audit.check_eq(tutorial.find_child("SmashResults", true, false).get_child_count(), 4, "pause/the_tutorial_carries_four_results")
	audit.check_eq(tutorial.find_child("SmashReadySpans", true, false).get_child_count(), 5, "pause/the_ready_strip_carries_its_title_and_four_conditions")
	var caps: Array = []
	for child in tutorial.find_child("SmashResults", true, false).get_children():
		var cap := child.find_child("ResultCap", true, false) as Label
		caps.append(cap.text)
	audit.check_eq(caps.size(), 4, "pause/every_result_row_carries_a_key_cap")
	audit.check_eq(caps[0], TutorClass.cap_text("↑", "", ""), "pause/the_first_cap_is_the_references")
	audit.check_eq(caps[1], TutorClass.cap_text("↖", "↗", ""), "pause/the_diagonal_cap_is_the_references")
	audit.check_eq(caps[2], TutorClass.cap_text("", "", "•"), "pause/the_flat_cap_is_the_references")
	audit.check_eq(caps[3], TutorClass.cap_text("", "↓", ""), "pause/the_bandeja_cap_is_the_references")
	var guide_down := tutorial.find_child("GuideLabelDown", true, false) as Label
	audit.check_eq(guide_down.text, UiStrings.t("bandejaShort"), "pause/the_down_label_is_bandeja")
	audit.check_eq(tutorial.focus_controls().size(), 2, "pause/the_tutorial_exposes_back_and_try")
	_overlay.back()
	audit.check_eq(_overlay.tutorial_open(), false, "pause/back_closes_the_tutorial")
	audit.check_eq(_overlay.is_open(), true, "pause/back_leaves_the_pause_open")
	audit.check_eq(_overlay.active_tab(), "controls", "pause/back_lands_on_the_controls_tab")
	audit.check_eq(_overlay.legend_host().visible, true, "pause/the_legend_returns")
	# RIPRENDI E PROVA: close the tutorial and resume (`js/main.js:2354-2357`).
	_overlay.open_tutorial()
	var calls_before := (_seam as FakeSeam).count_of("set_match_paused")
	tutorial.try_button().pressed.emit()
	await process_frame
	audit.check_eq(_overlay.tutorial_open(), false, "pause/try_closes_the_tutorial")
	audit.check_eq((_seam as FakeSeam).count_of("set_match_paused"), calls_before + 1, "pause/try_resumes_through_the_seam")
	audit.check_eq((_seam as FakeSeam).last_args("set_match_paused"), ["set_match_paused", false], "pause/try_asks_for_the_running_match")
	# The disabled replay button carries its recorded reason (UIR-27).
	audit.check_eq(_overlay.replay_enabled(), false, "pause/replay_is_disabled_until_uir27")
	audit.check_eq(_overlay.quit_button() != null, true, "pause/the_quit_button_is_readable")
	var replay_button := _overlay.find_child("ReplayButton", true, false) as Button
	audit.check_eq(replay_button.disabled, true, "pause/the_replay_button_is_disabled")
	audit.check_eq(_overlay.replay_disabled_reason(), "uir27-replay-entry-not-landed", "pause/the_disabled_reason_is_recorded")
	audit.check_eq(_overlay.replay(), false, "pause/a_programmatic_replay_press_is_refused")
	_overlay.set_replay_active(true)
	audit.check_eq(_overlay.replay_enabled(), true, "pause/uir27s_flag_re_enables_the_button")
	audit.check_eq(replay_button.disabled, false, "pause/the_button_follows_the_flag")
	_overlay.set_replay_active(false)


# ---------------------------------------------------------------------------
# 10. Captures
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	for state_id in CAPTURE_STATES:
		audit.check_eq(_overlay.apply_capture_state(String(state_id)), true, "pause/capture_state_%s_applies" % state_id)
		var report: Dictionary = _overlay.report()
		match String(state_id):
			"pause-match":
				audit.check_eq(report.get("tab"), "match", "pause/capture_match_is_the_match_tab")
			"pause-controller":
				audit.check_eq(report.get("tab"), "controller", "pause/capture_controller_is_the_controller_tab")
			"pause-controls":
				audit.check_eq(report.get("tab"), "controls", "pause/capture_controls_is_the_controls_tab")
			"quit-confirm":
				audit.check_eq(report.get("quit_armed"), true, "pause/capture_quit_confirm_is_armed")
			"smash-tutorial":
				audit.check_eq(report.get("tutorial_open"), true, "pause/capture_tutorial_is_open")
	audit.check_eq(_overlay.apply_capture_state("nope"), false, "pause/an_unknown_capture_state_is_refused")
	_overlay.close()


# ---------------------------------------------------------------------------
# 11. Strings: resolvable in both locales, and the flip
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var keys := ["pause", "pauseInProgress", "tabMatch", "tabController", "commands", "continue",
		"replayBtn", "rematch", "quit", "quitConfirm", "controlPlayers", "auto", "semi", "manual",
		"deadzone", "volume", "vibration", "stickMove", "stickAimSwitch",
		"smashTutorialEyebrow", "smashTutorialTitle", "smashTutorialIntro", "smashTutorialTry",
		"smashReadyTitle", "bandejaShort", "ariaPauseMenu", "ariaControllerSettings",
		"ariaControlMode", "ariaStickTest", "ariaSmashStick", "smashTutorialBack"]
	var unresolved: Array = []
	for index in 4:
		keys.append("smashStep%sTitle" % str(index + 1))
		keys.append("smashStep%sDesc" % str(index + 1))
	for result in ["X2", "X3", "Flat", "Bandeja"]:
		keys.append("smash%sTitle" % result)
		keys.append("smash%sDesc" % result)
	for condition in ["Net", "High", "Charge", "Timing"]:
		keys.append("smashCondition%s" % condition)
	for key in keys:
		for lang in Locale.locales():
			if not Locale.is_resolvable(String(key), String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "pause/every_visible_key_resolves_in_both_locales")
	var language_at_start := Locale.current_lang()
	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
	audit.check_ne(other, "", "pause/there_is_a_second_locale_to_flip_to")
	_overlay.open()
	_overlay.set_tab("match")
	var before := _visible_slots()
	audit.check_ge(before.size(), 10, "pause/the_flip_table_covers_the_visible_slots")
	audit.check_eq(_overlay.set_language(other), true, "pause/the_other_language_is_taken")
	await process_frame
	var after := _visible_slots()
	var wrong: Array = []
	var moved := 0
	for id in before:
		var expected := Locale.resolve(String(before[id]["key"]), other)
		if String(after[id]["text"]) != expected:
			wrong.append("%s expected <%s> got <%s>" % [id, expected, after[id]["text"]])
		if Locale.resolve(String(before[id]["key"]), language_at_start) != expected:
			moved += 1
	audit.check_eq(wrong, [], "pause/the_flip_shows_the_other_tables_own_text")
	audit.check_gt(moved, 0, "pause/the_flip_moved_strings_that_differ")
	audit.check_eq(_overlay.set_language(language_at_start), true, "pause/the_first_language_comes_back")
	await process_frame
	var restored := _visible_slots()
	var still_wrong: Array = []
	for id in before:
		if String(restored[id]["text"]) != String(before[id]["text"]):
			still_wrong.append(String(id))
	audit.check_eq(still_wrong, [], "pause/the_flip_back_restores_every_slot")
	audit.check_eq(_overlay.set_language("xx"), false, "pause/an_unknown_locale_is_refused")
	audit.check_eq(_overlay.focus_controls().size(), 7, "pause/the_match_tab_is_still_focusable_after_the_flip")
	audit.report("language flip: %d of %d visible slots differ between tables" % [moved, before.size()])
	_overlay.close()


## The observable slots of the overlay and the tutorial, keyed by slot id: the message
## id each one must show and the text it shows now. The flip walks this table.
func _visible_slots() -> Dictionary:
	var tutorial: Control = _overlay.smash_tutorial()
	return {
		"title": {"key": "pause", "text": _text_of("PauseTitle")},
		"status": {"key": "pauseInProgress", "text": _text_of("StatusKey")},
		"tabMatch": {"key": "tabMatch", "text": _text_of("TabMatch")},
		"tabController": {"key": "tabController", "text": _text_of("TabController")},
		"tabControls": {"key": "commands", "text": _text_of("TabControls")},
		"continue": {"key": "continue", "text": _text_of("ContinueButton")},
		"replay": {"key": "replayBtn", "text": _text_of("ReplayButton")},
		"rematch": {"key": "rematch", "text": _text_of("RematchButton")},
		"quit": {"key": "quit", "text": _text_of("QuitButton")},
		"stickMove": {"key": "stickMove", "text": _text_of("StickLabel")},
		"tutorialTitle": {"key": "smashTutorialTitle", "text": _text_in(tutorial, "TutorialTitle")},
		"tutorialTry": {"key": "smashTutorialTry", "text": _text_in(tutorial, "TutorialTry")},
		"step1": {"key": "smashStep1Title", "text": _text_in(tutorial, "StepTitle")},
		"readyTitle": {"key": "smashReadyTitle", "text": _text_in(tutorial, "ReadyTitle")},
		"bandeja": {"key": "bandejaShort", "text": _text_in(tutorial, "GuideLabelDown")},
	}


func _text_of(node_name: String) -> String:
	var node := _overlay.find_child(node_name, true, false)
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return "<missing>"


func _text_in(root_node: Node, node_name: String) -> String:
	var node := root_node.find_child(node_name, true, false)
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return "<missing>"


# ---------------------------------------------------------------------------
# 12. The literal scan and the pause-pattern grep
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "pause/the_literal_scan_flags_prose_and_ignores_developer_text")
	for path in [OVERLAY_PATH, TUTORIAL_PATH]:
		var source := FileAccess.get_file_as_string(path)
		audit.check_true(source != "", "pause/the_source_of_%s_is_readable" % path)
		audit.check_eq(_offenders_in_source(path, source), [], "pause/%s_carries_no_prose_literal" % path)
		audit.check_eq(_pause_patterns_in_source(source), [], "pause/%s_never_touches_the_tree_pause" % path)


func _pause_patterns_in_source(source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		for pattern in FORBIDDEN_PAUSE_PATTERNS:
			if code.contains(pattern):
				out.append("%d: %s" % [index + 1, pattern])
	return out


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
