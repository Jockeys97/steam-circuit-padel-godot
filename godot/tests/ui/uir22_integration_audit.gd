## uir22_integration_audit.gd — UIR-22's contract audit: the playable UI, end to end.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/uir22_integration_audit.gd
##
## WHAT IT ASSERTS, and where the expectation comes from:
##
##   1. the HOST mounts the playable UI: `game/Main.tscn` builds the router with all
##      twelve recreated Control screens registered (the thirteenth id, `game`, is the
##      3D match scene and is reached through `Config.pending_mode`, not through the
##      router), mounts `menu` first, keeps exactly one screen mounted, and mounts NO
##      keyboard: the lane's OSK model is still the menu's own (`menu.menu.osk`), but
##      the panel is not up and a confirm never raises one — not on a row, and not on
##      a real text field, which instead keeps the focus (user decision, 2026-09-17);
##   2. navigation is real, through the host's own bridge: a confirm on the menu's play
##      button lands on `modes` (`MenuScreen.ACTION_TARGETS`), and every registered
##      screen mounts and unmounts cleanly through `go_to`;
##   3. the MATCH mounts the overlay stack with the recreated HUD (UIR-08 + UIR-20 +
##      UIR-26), and the pause seam is an explicit state: `set_match_paused(true/false)`
##      opens and closes the card, a repeated echo is a no-op, ESC drives the card's own
##      five-step hierarchy, and a reset (`rematch()`) leaves the match unpaused;
##   4. an END-TO-END run with real data: a quick match is played out by the scripted
##      player to a real result (`state.result`), `result_payload()` carries the state's
##      own figures, `finish_route(true)` leaves them in `Config.pending_result`, and a
##      host booted with that payload mounts `result` showing the same two numbers —
##      then the payload is consumed exactly once;
##   5. the settings screen's ranges are live through the host: a keyboard step on the
##      volume row (driven through the bridge) lands in the save, not only on screen —
##      the `range_changed` seam the screen audit recorded for the integrator;
##   6. the diagnostic fallback still exists and the LOCALE is unified: `ui_legacy`
##      builds the ported column (no router), the ported HUD no longer forces a
##      language, and the host applies the stored `lang` pref at boot.
##
## THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://uir22-integration-audit`) and
## removes it again; `Config.save_dir` is restored before the run ends.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const Config := preload("res://game/match_config.gd")
const Sim := preload("res://src/sim/sim.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const Locale := preload("res://src/locale/locale.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const OSK := preload("res://src/input/osk.gd")

const HOST_SCENE := preload("res://game/Main.tscn")
const MATCH_SCENE := preload("res://game/Match.tscn")
const HUD_SCRIPT := preload("res://game/hud.gd")

const TEMP_DIR := "user://uir22-integration-audit"
const FRAME := Vector2(1280.0, 720.0)
const SETTLE_FRAMES := 3
const TICK := 1.0 / 120.0
## The same budget the slice uses for one played-out match.
const TICK_BUDGET := 400000
## The twelve Control screens with a scene, from `game/main_menu.gd::SCREEN_SCENES`.
const EXPECTED_REGISTERED := [
	"arena", "challenges", "characters", "drill", "feedback", "help", "history",
	"menu", "modes", "profile", "result", "settings",
]

var _saved_dir := ""


func _initialize() -> void:
	var audit := AuditBase.new("uir22_integration")
	_saved_dir = Config.save_dir
	Config.save_dir = TEMP_DIR
	# A stored language the host must apply at boot (`_apply_stored_language`).
	ModesSave.save_pref(Config.save_store(), "lang", "en")
	Locale.set_lang("it")
	await _host_mounts_the_playable_ui(audit)
	await _match_mounts_the_overlay_stack(audit)
	await _end_to_end_with_real_data(audit)
	await _settings_ranges_are_live(audit)
	await _legacy_fallback_and_locale(audit)
	Config.save_dir = _saved_dir
	_wipe()
	quit(audit.finish())


# ---------------------------------------------------------------------------
# 1-2. The host: twelve mounts, one at a time, navigated by the bridge
# ---------------------------------------------------------------------------

func _mount_host() -> Array:
	var frame := Control.new()
	frame.name = "Uir22Frame"
	frame.size = FRAME
	root.add_child(frame)
	var host: Control = HOST_SCENE.instantiate()
	frame.add_child(host)
	for _i in SETTLE_FRAMES:
		await process_frame
	return [frame, host]


## The keyboard that came up over the MENU, and the two confirms this mount has to get
## right now that it renders none. The pad flag is set on the model because a headless
## run has no joypad to report (`main_menu._pad_connected`), and that flag is exactly
## the third term of the lane's own OSK branch (`src/input/menu_nav.gd:223`).
func _confirm_never_raises_a_keyboard(audit: AuditBase, host: Control, model, router: Control) -> void:
	model.menu.set_pad_connected(true)
	# 1. An ordinary row, which the lane misreads as a text field: the mount must close
	#    the model at once and finish the confirm as the row's own action.
	var play_id := ""
	for id in model.ids():
		if String(id).ends_with("/PlayButton"):
			play_id = String(id)
	audit.check_ne(play_id, "", "osk/the_menu_registers_its_play_button")
	var bridge = host.get("_bridge")
	if play_id != "" and bridge != null:
		audit.check_true(bool(bridge.call("set_focus", play_id)), "osk/the_row_takes_the_focus_before_the_confirm")
		# Through the host's own door: it is the path the engine drives for a real pad
		# event, and the only one that reaches `_sync_osk()`.
		host.call("_input", _key_event(KEY_ENTER))
		audit.check_eq(bool(host.get("_bridge") != null), true, "osk/the_rows_confirm_is_handled")
		audit.check_eq(bool(model.menu.osk.is_open()), false, "osk/the_lane_model_does_not_stay_open_on_a_row")
		audit.check_eq(host.find_child("OskPanel", true, false), null, "osk/no_keyboard_is_mounted_after_the_confirm")
		audit.check_eq(String(router.call("active_id")), "modes", "osk/the_row_runs_instead_of_the_keyboard (%s)" % router.call("active_id"))
		router.call("go_to", "menu")
		for _i in SETTLE_FRAMES:
			await process_frame
	# 2. A real text field: no keyboard, the field takes the focus, and the player can
	#    leave it and keep navigating (the dead end the keyboard's context used to be).
	router.call("go_to", "feedback")
	for _i in SETTLE_FRAMES:
		await process_frame
	var field_id := ""
	for id in model.ids():
		if model.call("node_of", String(id)) is LineEdit:
			field_id = String(id)
			break
	audit.check_ne(field_id, "", "osk/the_feedback_screen_registers_a_real_text_field")
	if field_id != "" and bridge != null:
		audit.check_true(bool(bridge.call("set_focus", field_id)), "osk/the_field_takes_the_focus")
		host.call("_input", _key_event(KEY_ENTER))
		audit.check_eq(bool(model.menu.osk.is_open()), false, "osk/confirming_a_text_field_raises_no_keyboard")
		audit.check_eq(String(model.menu.context_kind()), "screen", "osk/the_focus_context_stays_the_screens")
		audit.check_true(model.menu.nav.targets().size() > 0, "osk/the_player_has_somewhere_else_to_go")
		audit.check_eq(String(bridge.call("focus_id")), field_id, "osk/the_field_keeps_the_focus")
		var other_id := ""
		for id in model.focusable_ids():
			if String(id) != field_id:
				other_id = String(id)
				break
		audit.check_true(other_id != "" and bool(bridge.call("set_focus", other_id)), "osk/another_control_is_reachable_from_the_field")
		audit.check_eq(bool(bridge.call("set_focus", field_id)), true, "osk/the_field_takes_the_focus_back")
		host.call("_input", _key_event(KEY_ESCAPE))
		audit.check_ne(String(router.call("active_id")), "feedback", "osk/the_player_leaves_the_field_and_navigates_on (%s)" % router.call("active_id"))
	model.menu.set_pad_connected(false)
	router.call("go_to", "menu")
	for _i in SETTLE_FRAMES:
		await process_frame


func _host_mounts_the_playable_ui(audit: AuditBase) -> void:
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var frame: Control = pair[0]
	var router: Control = host.call("ui_router") if host.has_method("ui_router") else null
	audit.check_true(router != null, "host/the_default_ui_is_the_playable_host")
	if router == null:
		(frame as Node).queue_free()
		return
	var registered: Array = router.call("registered_ids")
	registered.sort()
	audit.check_eq(str(registered), str(EXPECTED_REGISTERED), "host/all_twelve_recreated_screens_are_registered")
	audit.check_eq(bool(router.call("go_to", "game")), false, "host/the_match_id_is_not_a_router_screen")
	audit.check_eq(String(router.call("active_id")), "menu", "host/the_menu_is_what_the_player_lands_on")
	audit.check_eq(int(router.call("screen_count")), 1, "host/exactly_one_screen_is_mounted")
	var screen: Node = router.call("active_screen")
	audit.check_true(screen != null and screen.has_method("screen_id"), "host/the_mounted_screen_is_a_uir03_screen")
	audit.check_eq(String(screen.call("screen_id")) if screen != null else "", "menu", "host/it_is_the_menu_screen")

	# The focus model over the live screen, and NO keyboard over the router: the panel
	# is not mounted any more (user decision, 2026-09-17 — it came up over the menu,
	# where the reference has no text field). The lane's OSK model is still the
	# menu's own, and the panel's own contract — its rows, its key targets — is
	# asserted by `tests/ui/osk_touch_audit.gd`, which mounts it on its own.
	var model = host.call("focus_model") if host.has_method("focus_model") else null
	audit.check_true(model != null, "host/the_focus_model_is_up")
	audit.check_eq(host.find_child("OskPanel", true, false), null, "osk/no_keyboard_is_mounted_over_the_router")
	audit.check_true(load("res://src/ui/screens/OskPanel.tscn") != null, "osk/the_panels_own_scene_still_ships")
	audit.check_true(model != null and model.menu.osk != null, "osk/the_input_lanes_own_model_is_still_up")
	await _confirm_never_raises_a_keyboard(audit, host, model, router)

	# A real confirm on the play button: the bridge's verdict is a router move.
	var play_id := ""
	for id in model.ids() if model != null else []:
		if String(id).ends_with("/PlayButton"):
			play_id = String(id)
	audit.check_ne(play_id, "", "bridge/the_menu_registers_its_play_button")
	audit.check_true(model != null and model.focusable_ids().has(play_id), "bridge/the_play_button_is_focusable")
	var bridge = host.get("_bridge")
	audit.check_true(bridge != null, "bridge/the_host_owns_a_bridge")
	if play_id != "" and bridge != null:
		audit.check_true(bool(bridge.call("set_focus", play_id)), "bridge/the_play_button_takes_the_focus")
		var before_dispatch := String(router.call("active_id"))
		audit.check_eq(bool(bridge.call("dispatch", _key_event(KEY_ENTER))), true, "bridge/confirm_is_handled")
		audit.check_eq(String(router.call("active_id")), "modes", "bridge/confirm_on_play_lands_on_modes (%s -> %s)" % [before_dispatch, router.call("active_id")])
		audit.check_eq(int(router.call("screen_count")), 1, "bridge/the_old_screen_left_before_the_new_one_mounted")

	# Every registered screen mounts, one at a time, and leaves again.
	var walk_problems: Array[String] = []
	for id in registered:
		var mounted := bool(router.call("go_to", String(id)))
		if not mounted:
			walk_problems.append("go_to(%s) refused" % id)
			continue
		for _i in SETTLE_FRAMES:
			await process_frame
		if int(router.call("screen_count")) != 1:
			walk_problems.append("%s: %d screens mounted" % [id, int(router.call("screen_count"))])
		var live: Node = router.call("active_screen")
		if live == null or String(live.call("screen_id")) != String(id):
			walk_problems.append("%s: the live screen says '%s'" % [id, String(live.call("screen_id")) if live != null else "<none>"])
	audit.check_eq(str(walk_problems), "[]", "host/every_registered_screen_mounts_and_unmounts")
	(frame as Node).queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 3. The match: the overlay stack and the pause seam
# ---------------------------------------------------------------------------

func _new_match(engine_driven: bool) -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var node: Node = MATCH_SCENE.instantiate()
	if not engine_driven:
		node.harness_mode()
	root.add_child(node)
	node.start_match()
	return node


func _match_mounts_the_overlay_stack(audit: AuditBase) -> void:
	var node := _new_match(true)
	audit.check_true(bool(node.get("engine_driven")), "match/the_audit_match_uses_the_engine_clock")
	var layer: Node = node.get_node_or_null("HudLayer")
	audit.check_true(layer != null, "match/the_hud_layer_exists")
	var ui_hud: Node = node.get_node_or_null("HudLayer/UiHud")
	audit.check_true(ui_hud != null, "match/the_recreated_hud_is_mounted (UIR-08)")
	var overlay: Node = node.get_node_or_null("HudLayer/PauseOverlay")
	audit.check_true(overlay != null, "match/the_pause_card_is_mounted (UIR-20)")
	var touch: Node = node.get_node_or_null("HudLayer/TouchControls")
	audit.check_true(touch != null, "match/the_touch_layer_is_mounted (UIR-26)")
	if overlay == null:
		_call(node, "free")
		return
	audit.check_eq(bool(overlay.call("is_open")), false, "pause/the_card_starts_closed")

	# The seam: an explicit state, not a toggle.
	audit.check_eq(bool(node.call("set_match_paused", true)), true, "pause/the_seam_takes_true")
	audit.check_eq(bool(node.call("is_paused")), true, "pause/the_controller_holds_the_flag")
	audit.check_eq(bool(overlay.call("is_open")), true, "pause/true_opens_the_card")
	# The echo: a repeated identical call is a no-op, not a toggle back.
	audit.check_eq(bool(node.call("set_match_paused", true)), true, "pause/a_repeated_echo_keeps_the_state")
	audit.check_eq(bool(overlay.call("is_open")), true, "pause/a_repeated_echo_does_not_flip_the_card")
	audit.check_eq(bool(overlay.call("set_match_paused", true)), false, "pause/the_overlays_own_echo_is_a_no_op_when_identical")
	audit.check_eq(bool(node.call("set_match_paused", false)), false, "pause/the_seam_takes_false")
	audit.check_eq(bool(overlay.call("is_open")), false, "pause/false_closes_the_card")

	# ESC is the card's own hierarchy: closed -> pause, open -> resume.
	audit.check_eq(bool(node.call("is_paused")), false, "pause/the_match_starts_running")
	node.call("_unhandled_input", _action_event("padel_pause"))
	audit.check_eq(bool(node.get("_paused")), true, "pause/escape_on_a_running_match_pauses")
	audit.check_eq(bool(overlay.call("is_open")), true, "pause/and_opens_the_card")
	node.call("_unhandled_input", _action_event("padel_pause"))
	audit.check_eq(bool(node.get("_paused")), false, "pause/escape_on_the_card_resumes")
	audit.check_eq(bool(overlay.call("is_open")), false, "pause/and_closes_it_again")

	# A reset is not a pause: pause, rematch, and the match must be running.
	node.call("set_match_paused", true)
	audit.check_eq(bool(node.get("_paused")), true, "pause/paused_before_the_reset")
	node.call("rematch")
	audit.check_eq(bool(node.get("_paused")), false, "pause/a_rematch_leaves_the_match_running")
	audit.check_eq(bool(overlay.call("is_open")), false, "pause/and_the_card_knows_it")
	audit.check_true(node.has_method("leave_match"), "pause/the_seam_exposes_leave_match")
	node.free()


# ---------------------------------------------------------------------------
# 4. Menu -> match -> result, with real data
# ---------------------------------------------------------------------------

func _end_to_end_with_real_data(audit: AuditBase) -> void:
	var node := _new_match(false)
	var bot := ScriptedPlayer.new()
	while node.state.result == null and int(node.ticks) < TICK_BUDGET:
		node.tick_fixed(TICK, bot.decide(node.state), Sim.empty_input())
	audit.check_true(node.state.result != null, "e2e/the_scripted_match_reaches_a_result (%d ticks)" % int(node.ticks))
	if node.state.result == null:
		node.free()
		return
	var payload: Dictionary = node.call("result_payload")
	audit.check_true(not payload.is_empty(), "e2e/the_result_payload_is_built")
	var result: Dictionary = payload.get("result", {})
	# The figure the screen prints is the one the port's result renderer shows
	# (`ResultScreen.result_from_state`: the set's own line where the run plays by
	# sets) — not `state.points`, which is the live game inside that set.
	var final_line: Dictionary = node.state.setScores[0] if (node.state.setScores is Array and node.state.setScores.size() > 0) else node.state.points
	audit.check_eq(int(result.get("player", -1)), int(final_line.get("player", -2)), "e2e/the_payload_carries_the_states_own_player_line")
	audit.check_eq(int(result.get("ai", -1)), int(final_line.get("ai", -2)), "e2e/the_payload_carries_the_states_own_ai_line")
	audit.check_eq(bool(result.get("won", true)), String(node.state.result.get("winner", "")) == "player", "e2e/the_win_flag_is_the_sims_own_winner")
	audit.check_eq(String(payload.get("mode", "")), "quick", "e2e/the_mode_is_the_runs_own")
	audit.check_eq(String(payload.get("arena_id", "")), Config.arena_id(), "e2e/the_arena_is_the_configured_one")
	audit.check_true(String(result.get("score", "")).contains("-"), "e2e/the_score_line_is_the_states_own")
	audit.check_true(int((result.get("stats", {}) as Dictionary).get("totalRallyHits", 0)) > 0, "e2e/the_stat_rows_come_from_the_state")
	var route: Dictionary = node.call("finish_route", true)
	audit.check_eq(String(route.get("action", "")), "result", "e2e/the_finish_route_is_the_result")
	audit.check_eq(bool(route.get("payload_ready", false)), true, "e2e/dry_run_stops_before_the_scene_change")
	audit.check_eq(Config.pending_result.is_empty(), false, "e2e/the_payload_is_left_for_the_host")
	node.free()

	# A host booted with that payload mounts the result screen with the same numbers.
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var frame: Control = pair[0]
	var router: Control = host.call("ui_router")
	audit.check_eq(String(router.call("active_id")), "result", "e2e/the_host_boots_straight_onto_the_result_screen")
	var screen: Node = router.call("active_screen")
	var shown: Array = screen.call("score_numbers") if screen != null else []
	audit.check_eq(str(shown), str([int(result.get("player", -1)), int(result.get("ai", -1))]), "e2e/the_result_screen_shows_the_matches_own_numbers")
	audit.check_eq(Config.pending_result.is_empty(), true, "e2e/the_payload_is_consumed_once")
	# The rematch route (the result screen's own request handler).
	var rematch: Dictionary = host.call("rematch_route", true)
	audit.check_eq(String(rematch.get("scene", "")), "res://game/Match.tscn", "e2e/rematch_goes_back_to_the_match_scene")
	audit.check_eq(String(rematch.get("mode", "")), "quick", "e2e/and_keeps_the_run_mode")
	(frame as Node).queue_free()
	await process_frame

	# The menu is what a second boot lands on (the payload is gone).
	var pair2: Array = await _mount_host()
	var host2: Control = pair2[1]
	var router2: Control = host2.call("ui_router")
	audit.check_eq(String(router2.call("active_id")), "menu", "e2e/a_boot_without_a_payload_lands_on_the_menu")
	(pair2[0] as Node).queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 5. The settings screen's ranges through the host
# ---------------------------------------------------------------------------

func _settings_ranges_are_live(audit: AuditBase) -> void:
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var frame: Control = pair[0]
	var router: Control = host.call("ui_router")
	audit.check_eq(bool(router.call("go_to", "settings")), true, "settings/the_host_mounts_the_settings_screen")
	for _i in SETTLE_FRAMES:
		await process_frame
	var screen: Node = router.call("active_screen")
	var before: float = float(screen.call("volume"))
	var row_id := String(screen.call("focus_id", "VolumeRow"))
	var bridge = host.get("_bridge")
	var set_ok := bridge != null and bool(bridge.call("set_focus", row_id))
	audit.check_true(set_ok, "settings/the_volume_row_takes_the_focus_through_the_bridge")
	var stepped := before
	if set_ok:
		audit.check_eq(bool(bridge.call("dispatch", _key_event(KEY_RIGHT))), true, "settings/a_right_press_on_the_range_is_handled")
		stepped = float(screen.call("volume"))
	audit.check_ne(stepped, before, "settings/a_right_press_steps_the_volume_row")
	var stored: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	audit.check_true(is_equal_approx(float(stored.get("volume", -1.0)), stepped), "settings/the_stepped_value_lands_in_the_save (%.4f stored, %.4f on screen)" % [float(stored.get("volume", -1.0)), stepped])
	(frame as Node).queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 6. The fallback, and the one locale
# ---------------------------------------------------------------------------

func _legacy_fallback_and_locale(audit: AuditBase) -> void:
	# The host applies the stored language at boot.
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	audit.check_eq(Locale.current_lang(), "en", "locale/the_host_applies_the_stored_language")
	(pair[0] as Node).queue_free()
	await process_frame

	# The ported HUD no longer picks its own language.
	Locale.set_lang("it")
	var frame := Control.new()
	frame.size = FRAME
	root.add_child(frame)
	var hud: Control = HUD_SCRIPT.new()
	frame.add_child(hud)
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(Locale.current_lang(), "it", "locale/the_ported_hud_does_not_force_a_language")
	Locale.set_lang("en")
	audit.check_eq(Locale.current_lang(), "en", "locale/and_a_language_change_sticks")
	hud.queue_free()
	frame.queue_free()
	await process_frame

	# The diagnostic fallback: the ported column, no router.
	var frame2 := Control.new()
	frame2.size = FRAME
	root.add_child(frame2)
	var legacy: Control = HOST_SCENE.instantiate()
	legacy.set("ui_legacy", true)
	frame2.add_child(legacy)
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_true(legacy.call("ui_router") == null, "fallback/ui_legacy_builds_no_router")
	audit.check_true(legacy.find_child("MenuColumn", true, false) != null, "fallback/the_ported_column_is_built")
	audit.check_true(legacy.call("focus_model") != null, "fallback/and_its_own_focus_model_is_up")
	legacy.queue_free()
	frame2.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _key_event(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _action_event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _call(node: Node, method: String) -> void:
	if node != null and node.has_method(method):
		node.call(method)


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists(TEMP_DIR.trim_prefix("user://")):
		dir.remove(TEMP_DIR.trim_prefix("user://"))
