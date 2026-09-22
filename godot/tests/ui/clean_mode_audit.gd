## clean_mode_audit.gd — the in-match clean-view toggle contract.
##
##   godot --headless --path godot/ --script res://tests/ui/clean_mode_audit.gd
##
## Same machine-readable contract as the other audits: `ok <name>` / `FAIL <name>`
## and one `PASS n/n` line, exit 0 on PASS and 1 on FAIL.
##
## WHAT IT ASSERTS, and the seam each question crosses:
##
##   1. the seams exist and the initial state is a visible HUD
##      (`is_hud_hidden`, `set_hud_hidden`, `toggle_hud_hidden`);
##   2. a pressed LEFT DOUBLE-CLICK toggles hidden and visible, and a single left
##      press does not (the gesture has to be the reference's own double-click). The
##      gesture rides the PRE-GUI path (`_input`), so a HUD control that stops the
##      mouse cannot eat it: the event is pushed through the viewport's own pipeline
##      (and is deliberately NOT answered when delivered to `_unhandled_input`, the
##      post-GUI phase a `MOUSE_FILTER_STOP` control would have cut off);
##   3. the pad's `JOY_BUTTON_START` and `JOY_BUTTON_BACK` each toggle, and — the
##      point of consuming them — neither press pauses: Start is `padel_pause`'s own
##      pad binding, so an unconsumed press would open the pause card instead;
##   4. the layer boundary holds: clean mode hides the shipping HUD, the legacy HUD,
##      the mode strip, the active ring/pin, the drill target and the timing marks,
##      and leaves the pause card, the replay overlay and the touch layer alone;
##   5. the hidden state survives the every-frame rewrite (`_sync_views`), which is
##      why the state is a flag and not a one-shot write;
##   6. a reset (`rematch`) restores the visible UI and clears the flag;
##   7. the keyboard ESC pause flow is untouched, with clean mode on and off;
##   8. the shipping mount never reveals the ported mode strip when clean mode ends,
##      while a legacy run shows its own column and strip and follows the flag.
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://clean-mode-audit`) and removes it
## again. The real `user://save` is never touched.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Config := preload("res://game/match_config.gd")

const MATCH_SCENE := preload("res://game/Match.tscn")
const TEMP_DIR := "user://clean-mode-audit"
const FRAME := Vector2(1280.0, 720.0)
const SETTLE_FRAMES := 3
const TICK := 1.0 / 120.0

var _saved_dir := ""


func _initialize() -> void:
	var audit := AuditBase.new("clean_mode")
	_saved_dir = Config.save_dir
	Config.save_dir = TEMP_DIR
	await _shipping(audit)
	await _legacy(audit)
	await _drill_target(audit)
	Config.save_dir = _saved_dir
	_wipe()
	quit(audit.finish())


# ---------------------------------------------------------------------------
# The shipping match: seams, gestures, layers, refresh, reset, ESC
# ---------------------------------------------------------------------------

func _shipping(audit: AuditBase) -> void:
	var node := await _new_match(false, false)
	var ui_hud: Node = node.get_node_or_null("HudLayer/UiHud")
	var mode_hud: Node = node.get_node_or_null("HudLayer/ModeHud")
	if ui_hud == null or mode_hud == null:
		audit.check_true(false, "shipping/the_recreated_hud_and_mode_strip_are_mounted")
		node.free()
		return

	# 1. The seams and the initial state.
	audit.check_true(node.has_method("set_hud_hidden")
		and node.has_method("toggle_hud_hidden") and node.has_method("is_hud_hidden"),
		"seam/the_controller_exposes_the_three_seams")
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "initial/is_hud_hidden_is_false")
	# The shipping HUD is component-aware now (`docs/agent-work/
	# ui-visibility-settings/PLAN.md`): the ROOT stays mounted (the restore hint is
	# its independent sibling), and the profile hides the named panels inside it. A
	# fresh match is the full view.
	audit.check_eq(bool(ui_hud.visible), true, "initial/the_hud_root_is_mounted")
	audit.check_eq(_components(ui_hud), _all_on(), "initial/every_component_starts_visible")

	# 2. The double-click. The gesture is delivered to `_input` on purpose: that is the
	# pre-GUI global path, and a double-click over a `MOUSE_FILTER_STOP` HUD control is
	# consumed by that control before `_unhandled_input` runs (the check below).
	node.call("_input", _double_click())
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "double_click/a_left_double_click_hides")
	audit.check_eq(_components(ui_hud), _all_off(), "double_click/every_component_is_hidden")
	audit.check_eq(_nodes_hidden(ui_hud), true, "double_click/no_component_panel_is_left_showing")
	audit.check_eq(bool(ui_hud.visible), true, "double_click/the_hud_root_stays_mounted_for_the_hint")
	node.call("_input", _double_click())
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "double_click/the_second_double_click_shows")
	audit.check_eq(_components(ui_hud), _all_on(), "double_click/every_component_is_shown_again")
	node.call("_input", _single_click())
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "double_click/a_single_left_press_does_not_toggle")

	# The pre-GUI claim. `_input` is the viewport's first, pre-GUI phase; a HUD control
	# with `MOUSE_FILTER_STOP` consumes a press before the later `_unhandled_input`
	# phase, so a rung there is dead over any HUD button. Delivered through the
	# viewport's own pipeline, the gesture toggles; delivered to `_unhandled_input`
	# directly, it does not — which is exactly the ordering this correction put in
	# place. (The engine dispatches no GUI phase in this headless harness, so the
	# button-eats-the-click scenario itself is pinned by this pair, not reproduced.)
	var center := Vector2(FRAME.x * 0.5, FRAME.y * 0.5)
	var hidden_before := bool(node.call("is_hud_hidden"))
	root.push_input(_double_click_at(center))
	audit.check_eq(bool(node.call("is_hud_hidden")), not hidden_before,
		"double_click/the_gesture_is_answered_by_the_viewports_pre_gui_input")
	node.call("set_hud_hidden", false)
	node.call("_unhandled_input", _double_click())
	audit.check_eq(bool(node.call("is_hud_hidden")), false,
		"double_click/the_gesture_is_not_answered_post_gui_in_unhandled_input")

	# 3. The pad's two buttons, and the consumption that keeps Start from pausing.
	node.call("_input", _pad_button(JOY_BUTTON_START))
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "pad/start_hides_the_hud")
	audit.check_eq(bool(node.call("is_paused")), false, "pad/start_does_not_pause")
	audit.check_eq(bool(node.get_node("HudLayer/PauseOverlay").call("is_open")), false,
		"pad/start_does_not_open_the_card")
	node.call("_input", _pad_button(JOY_BUTTON_START))
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "pad/a_second_start_shows_the_hud")
	node.call("_input", _pad_button(JOY_BUTTON_BACK))
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "pad/back_hides_the_hud")
	audit.check_eq(bool(node.call("is_paused")), false, "pad/back_does_not_pause")
	node.call("_input", _pad_button(JOY_BUTTON_BACK))
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "pad/a_second_back_shows_the_hud")

	# A press while the card is open belongs to the card, not to clean mode.
	node.call("set_match_paused", true)
	node.call("_input", _pad_button(JOY_BUTTON_START))
	audit.check_eq(bool(node.call("is_hud_hidden")), false,
		"pad/a_press_while_the_card_is_open_is_left_to_the_card")
	node.call("set_match_paused", false)

	# 4. The world-space marks and the timing presentation follow the flag, and the
	# other layers are not touched.
	var ring: Node = node.get_node_or_null("ActiveRing")
	var pin: Node = node.get_node_or_null("ActivePin")
	var energy: Node = node.get_node_or_null("TimingEnergyBar")
	var touch: Node = node.get_node_or_null("HudLayer/TouchControls")
	var replay: Node = node.get_node_or_null("HudLayer/ReplayOverlay")
	audit.check_true(ring != null and pin != null and energy != null,
		"marks/the_world_and_timing_marks_are_mounted")
	audit.check_eq(bool(ring.visible), true, "marks/the_active_ring_starts_visible")
	audit.check_eq(bool(pin.visible), true, "marks/the_active_pin_starts_visible")
	audit.check_eq(bool(energy.visible), true, "marks/the_energy_bar_starts_visible")
	var touch_before := bool(touch.visible) if touch != null else false
	var replay_before := bool(replay.visible) if replay != null else false
	node.call("set_hud_hidden", true)
	audit.check_eq(bool(ring.visible), false, "marks/the_active_ring_follows_clean_mode")
	audit.check_eq(bool(pin.visible), false, "marks/the_active_pin_follows_clean_mode")
	audit.check_eq(bool(energy.visible), false, "marks/the_timing_marks_follow_clean_mode")
	audit.check_eq(bool(mode_hud.visible), false, "shipping/the_port_strip_stays_hidden_in_clean_mode")
	audit.check_eq(bool(touch.visible) if touch != null else false, touch_before,
		"layers/clean_mode_leaves_the_touch_layer_alone")
	audit.check_eq(bool(replay.visible) if replay != null else false, replay_before,
		"layers/clean_mode_leaves_the_replay_overlay_alone")
	node.call("set_match_paused", true)
	audit.check_eq(bool(node.get_node("HudLayer/PauseOverlay").call("is_open")), true,
		"layers/clean_mode_keeps_the_pause_card_available")
	audit.check_eq(_components(ui_hud), _all_off(), "layers/the_hud_stays_hidden_under_the_card")
	node.call("set_match_paused", false)

	# 5. The flag survives the every-frame rewrite: `_sync_views` re-runs the rings,
	# the pin and the timing marks, and a one-shot write would be undone by it.
	for _i in SETTLE_FRAMES:
		node.call("apply_frame", {}, TICK)
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "refresh/the_flag_survives_a_frame")
	audit.check_eq(_components(ui_hud), _all_off(), "refresh/the_hud_stays_hidden_after_refresh")
	audit.check_eq(_nodes_hidden(ui_hud), true, "refresh/no_component_panel_is_re_shown_by_the_rewrite")
	audit.check_eq(bool(ring.visible), false, "refresh/the_ring_stays_hidden_after_refresh")
	audit.check_eq(bool(energy.visible), false, "refresh/the_marks_stay_hidden_after_refresh")

	# 7. ESC is untouched, with clean mode on.
	node.call("_unhandled_input", _action_event("padel_pause"))
	audit.check_eq(bool(node.call("is_paused")), true, "escape/escape_still_pauses_while_clean")
	node.call("_unhandled_input", _action_event("padel_pause"))
	audit.check_eq(bool(node.call("is_paused")), false, "escape/escape_still_resumes_while_clean")
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "escape/escape_leaves_clean_mode_alone")

	# 6. A reset is a reset: the rematch shows the informational UI again.
	node.call("rematch")
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "reset/a_rematch_clears_the_flag")
	audit.check_eq(bool(ui_hud.visible), true, "reset/a_rematch_keeps_the_hud_root_mounted")
	audit.check_eq(_components(ui_hud), _all_on(), "reset/a_rematch_shows_every_component_again")
	audit.check_eq(bool(node.get_node("ActiveRing").visible), true, "reset/a_rematch_shows_the_ring_again")
	audit.check_eq(bool(node.get_node("TimingEnergyBar").visible), true, "reset/a_rematch_shows_the_marks_again")

	# 8. Shipping: the ported strip must not come back with the visible HUD.
	audit.check_eq(bool(mode_hud.visible), false, "shipping/the_port_strip_is_not_revealed_by_clean_mode")

	# 9. EXACT RESTORE. Clean mode remembers the profile it left, so the gesture
	# returns the player's own custom view rather than forcing `all` back. The
	# custom profile here is "every component but the map", chosen through the same
	# seam the UI tab writes.
	node.call("set_ui_component", "map", false)
	var custom: Dictionary = node.call("ui_visibility_snapshot")
	audit.check_eq(bool(custom.get("map", true)), false, "restore/the_custom_profile_is_in_force")
	audit.check_eq(String(node.call("ui_preset_id")), "", "restore/a_custom_profile_matches_no_preset")
	node.call("_input", _double_click())
	audit.check_eq(bool(node.call("is_hud_hidden")), true, "restore/the_gesture_enters_clean")
	node.call("_input", _double_click())
	audit.check_eq(bool(node.call("is_hud_hidden")), false, "restore/the_gesture_leaves_clean")
	audit.check_eq(node.call("ui_visibility_snapshot"), custom,
		"restore/the_gesture_returns_the_exact_custom_profile")
	audit.check_eq(_components(ui_hud), custom, "restore/the_hud_follows_the_restored_profile")
	# And a preset is remembered as itself, not flattened to `all`.
	node.call("set_ui_preset", "score_only")
	node.call("_input", _double_click())
	node.call("_input", _double_click())
	audit.check_eq(String(node.call("ui_preset_id")), "score_only",
		"restore/a_preset_comes_back_as_that_preset")
	node.free()


# ---------------------------------------------------------------------------
# A legacy run: its own column follows the same seam
# ---------------------------------------------------------------------------

func _legacy(audit: AuditBase) -> void:
	var node := await _new_match(false, true)
	var legacy_hud: Node = node.get_node_or_null("HudLayer/Hud")
	var mode_hud: Node = node.get_node_or_null("HudLayer/ModeHud")
	audit.check_true(legacy_hud != null, "legacy/the_legacy_column_is_built")
	audit.check_true(node.get_node_or_null("HudLayer/UiHud") == null,
		"legacy/the_recreated_hud_is_not_built")
	if legacy_hud == null or mode_hud == null:
		node.free()
		return
	audit.check_eq(bool(mode_hud.visible), true, "legacy/the_port_strip_is_visible_when_clean_is_off")
	node.call("set_hud_hidden", true)
	audit.check_eq(bool(legacy_hud.visible), false, "legacy/clean_mode_hides_the_legacy_hud")
	audit.check_eq(bool(mode_hud.visible), false, "legacy/clean_mode_hides_the_port_strip")
	node.call("set_hud_hidden", false)
	audit.check_eq(bool(legacy_hud.visible), true, "legacy/clean_mode_off_shows_the_legacy_hud")
	audit.check_eq(bool(mode_hud.visible), true, "legacy/clean_mode_off_shows_the_port_strip")
	node.free()


# ---------------------------------------------------------------------------
# The drill target: a world-space informational mark of the mode's own session
# ---------------------------------------------------------------------------

func _drill_target(audit: AuditBase) -> void:
	Config.pending_mode = "drill"
	Config.pending_round = -1
	Config.pending_exercise = "precision"
	var node: Node = MATCH_SCENE.instantiate()
	node.harness_mode()
	root.add_child(node)
	for _i in SETTLE_FRAMES:
		await process_frame
	# The press that leaves `ready` places the drill's target (`game_slice_test.gd`
	# drives the same step through the same `apply_frame` path).
	node.call("apply_frame", {"hit": true}, TICK)
	var session = node.get("session")
	var active: bool = session != null and bool(session.drill.target.get("active", false))
	if not active:
		audit.not_ported("drill/the_drill_target_is_placed",
			"the precision drill placed no target on the first tick in this run; the target's own placement is covered by tests/game_slice_test.gd")
		node.free()
		Config.pending_mode = "quick"
		return
	audit.check_eq(bool(node.get_node("TargetRing").visible), true, "drill/the_drill_target_starts_visible")
	node.call("set_hud_hidden", true)
	audit.check_eq(bool(node.get_node("TargetRing").visible), false, "drill/clean_mode_hides_the_drill_target")
	node.call("set_hud_hidden", false)
	audit.check_eq(bool(node.get_node("TargetRing").visible), true, "drill/clean_mode_off_shows_the_drill_target")
	node.free()
	Config.pending_mode = "quick"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## The shipping HUD's applied component profile, as data (`Hud.gd`'s own report of
## what it was told to show). The root is never hidden, so this is what "the HUD is
## hidden" means for an implementation that keeps the hint independent.
func _components(hud: Node) -> Dictionary:
	var profile: Variant = hud.call("component_visibility")
	return profile if profile is Dictionary else {}


## Every node the six components own is hidden. `indicators` owns none in the HUD
## (the controller carries those marks), so an empty node list is not a failure.
func _nodes_hidden(hud: Node) -> bool:
	for id in _components(hud).keys():
		var nodes: Variant = hud.call("component_nodes", String(id))
		for node in (nodes if nodes is Array else []):
			if node != null and bool((node as Control).visible):
				return false
	return true


func _all_on() -> Dictionary:
	return {"score": true, "time": true, "map": true, "guidance": true, "indicators": true, "events": true}


func _all_off() -> Dictionary:
	return {"score": false, "time": false, "map": false, "guidance": false, "indicators": false, "events": false}


func _new_match(harness: bool, legacy: bool) -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var node: Node = MATCH_SCENE.instantiate()
	if legacy:
		node.set("ui_legacy", true)
	if harness:
		node.harness_mode()
	root.add_child(node)
	# A `--script` SceneTree's root is not ready until the first frame: the scene's
	# own `_ready` (which builds the HUD layer) runs on that first `process_frame`.
	for _i in SETTLE_FRAMES:
		await process_frame
	node.start_match()
	return node


func _double_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = true
	return event


func _single_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = false
	return event


func _double_click_at(at: Vector2) -> InputEventMouseButton:
	var event := _double_click()
	event.position = at
	event.global_position = at
	return event


func _pad_button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists(TEMP_DIR.trim_prefix("user://")):
		dir.remove(TEMP_DIR.trim_prefix("user://"))
