## uir_route_audit.gd — the finalize wave's route driver: the playable path, in one run.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/uir_route_audit.gd
##
## WHAT IT DRIVES, in the order the owner named it for the play-test:
##
##   menu -> modes -> characters -> arena -> drill -> match -> pause -> result ->
##   rematch -> settings
##
##   1. the host (`game/Main.tscn`) mounts the menu; a REAL confirm on the menu's own
##      PlayButton goes through the host's bridge and lands on `modes` (not a mocked
##      call: the bridge dispatches an InputEventKey into the input lane's model);
##   2. `characters`, `arena`, `drill` and `settings` are each mounted by the router and
##      the screen that answers is the screen the route asked for, one at a time;
##   3. the DRILL: the screen's own gate (`ModeSession.can_start`) grants it in this
##      build, its start writes the two pending fields, and a `Match.tscn` booted on
##      those fields adopts a real drill session (`session.mode == "drill"`);
##   4. the MATCH: ESC through `_unhandled_input` pauses (card open, one flag), ESC
##      again resumes; a scripted quick match plays out to `state.result`;
##   5. the RESULT: `finish_route(true)` leaves the live payload in
##      `Config.pending_result`, a host booted on it mounts `result` with the same two
##      numbers, `rematch_route(true)` points back at `Match.tscn` with the same mode,
##      and the payload is consumed exactly once;
##   6. SETTINGS: a real right-press on the volume row moves the slider, the save and
##      the AUDIO MODULE's own master gain (review F6: the value is applied, not only
##      stored);
##   7. HUMAN MODES (review F1): a stored `playerMode` of `coop`/`pvp` reaches
##      `create_match_state` on a quick match (`state.humanMode`, `state.coop`,
##      `state.pvp`), and a non-quick mode stays `solo`.
##
## WRITES: only `user://uir-route-audit`, removed again; `Config.save_dir` restored.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Locale := preload("res://src/locale/locale.gd")
const Sim := preload("res://src/sim/sim.gd")

const HOST_SCENE := preload("res://game/Main.tscn")
const MATCH_SCENE := preload("res://game/Match.tscn")

const TEMP_DIR := "user://uir-route-audit"
const FRAME := Vector2(1280.0, 720.0)
const SETTLE_FRAMES := 3
const TICK := 1.0 / 120.0
const TICK_BUDGET := 400000

var _saved_dir := ""


func _initialize() -> void:
	var audit := AuditBase.new("uir_route")
	_saved_dir = Config.save_dir
	Config.save_dir = TEMP_DIR
	ModesSave.save_pref(Config.save_store(), "lang", "en")
	Locale.set_lang("it")
	await _route_to_the_drill(audit)
	await _drill_boots_a_real_session(audit)
	await _match_pause_and_result(audit)
	await _settings_apply_what_they_store(audit)
	await _human_modes_reach_the_state(audit)
	# Everything this driver mounted is gone before the tree quits: the harness nodes
	# are detached rather than left for the exit sweep, so the run's only output is
	# the tally (and the audit does not report leaked instances at exit).
	for child in root.get_children():
		child.free()
	await process_frame
	Config.save_dir = _saved_dir
	_wipe()
	quit(audit.finish())


# ---------------------------------------------------------------------------
# 1-3. menu -> modes -> characters -> arena -> drill
# ---------------------------------------------------------------------------

func _mount_host() -> Array:
	var frame := Control.new()
	frame.name = "RouteFrame"
	frame.size = FRAME
	root.add_child(frame)
	var host: Control = HOST_SCENE.instantiate()
	frame.add_child(host)
	for _i in SETTLE_FRAMES:
		await process_frame
	return [frame, host]


func _route_to_the_drill(audit: AuditBase) -> void:
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var router: Control = host.call("ui_router")
	audit.check_eq(String(router.call("active_id")), "menu", "route/the_route_starts_on_the_menu")

	# The real confirm: the bridge dispatches a key event into the lane's own model.
	var model = host.call("focus_model")
	var bridge = host.get("_bridge")
	var play_id := ""
	for id in model.ids():
		if String(id).ends_with("/PlayButton"):
			play_id = String(id)
	audit.check_true(play_id != "", "route/the_menu_registers_its_play_button")
	audit.check_true(bridge != null, "route/the_host_owns_the_bridge")
	if play_id != "" and bridge != null:
		audit.check_true(bool(bridge.call("set_focus", play_id)), "route/the_play_button_takes_the_focus")
		audit.check_eq(bool(bridge.call("dispatch", _key_event(KEY_ENTER))), true, "route/the_confirm_is_handled")
	audit.check_eq(String(router.call("active_id")), "modes", "route/a_real_confirm_on_play_lands_on_modes")

	# The named screens, each mounted by the router, one at a time.
	var problems: Array[String] = []
	for id in ["characters", "arena", "drill"]:
		if not bool(router.call("go_to", String(id))):
			problems.append("go_to(%s) refused" % id)
			continue
		for _i in SETTLE_FRAMES:
			await process_frame
		if int(router.call("screen_count")) != 1:
			problems.append("%s: %d screens mounted" % [id, int(router.call("screen_count"))])
		var live: Node = router.call("active_screen")
		if live == null or String(live.call("screen_id")) != String(id):
			problems.append("%s: the live screen says '%s'" % [id, String(live.call("screen_id")) if live != null else "<none>"])
	audit.check_eq(str(problems), "[]", "route/characters_arena_and_drill_mount_one_at_a_time")

	# The drill screen's own gate and payload (a full build grants the drill).
	var drill: Node = router.call("active_screen")
	audit.check_true(drill != null and drill.has_method("granted"), "route/the_drill_screen_is_what_mounted")
	if drill != null and drill.has_method("granted"):
		audit.check_eq(bool(drill.call("granted")), true, "route/this_build_grants_the_drill")
		var payload: Dictionary = drill.call("start", true)
		audit.check_eq(String(payload.get("mode", "")), "drill", "route/the_drill_start_names_the_mode")
		audit.check_eq(String(payload.get("scene", "")), "res://game/Match.tscn", "route/the_drill_start_points_at_the_match_scene")
		audit.check_eq(Config.pending_mode, "drill", "route/and_writes_the_pending_mode")
		audit.check_eq(Config.pending_exercise, String(drill.call("exercise")), "route/and_the_chosen_exercise")
	(pair[0] as Node).queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 4. the drill's press boots a real drill session
# ---------------------------------------------------------------------------

func _drill_boots_a_real_session(audit: AuditBase) -> void:
	Config.pending_mode = "drill"
	var node: Node = MATCH_SCENE.instantiate()
	root.add_child(node)
	node.harness_mode()
	for _i in SETTLE_FRAMES:
		await process_frame
	var session = node.get("session")
	audit.check_true(session != null, "drill/the_match_adopts_a_session")
	if session != null:
		audit.check_eq(String(session.get("mode") if session.get("mode") != null else ""), "drill", "drill/and_it_is_the_drill_the_screen_asked_for")
	audit.check_eq(String(node.state.mode), "drill", "drill/the_state_runs_the_drill_mode")
	# It ticks: one fixed step with the empty input must advance the clock.
	var before := int(node.ticks)
	node.call("tick_fixed", TICK, Sim.empty_input(), Sim.empty_input())
	audit.check_eq(int(node.ticks), before + 1, "drill/and_it_ticks (the drill's own step)")
	node.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 5. the match: pause, result, rematch
# ---------------------------------------------------------------------------

func _quick_match() -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	var node: Node = MATCH_SCENE.instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	return node


func _match_pause_and_result(audit: AuditBase) -> void:
	var node := _quick_match()
	audit.check_eq(bool(node.call("is_paused")), false, "match/the_match_starts_running")
	node.call("_unhandled_input", _action_event("padel_pause"))
	audit.check_eq(bool(node.call("is_paused")), true, "pause/escape_on_a_running_match_pauses")
	var overlay: Node = node.get_node_or_null("HudLayer/PauseOverlay")
	audit.check_true(overlay != null and bool(overlay.call("is_open")), "pause/and_the_card_is_open")
	node.call("_unhandled_input", _action_event("padel_pause"))
	audit.check_eq(bool(node.call("is_paused")), false, "pause/a_second_escape_resumes")
	audit.check_true(overlay != null and not bool(overlay.call("is_open")), "pause/and_closes_the_card")

	var bot := ScriptedPlayer.new()
	while node.state.result == null and int(node.ticks) < TICK_BUDGET:
		node.call("tick_fixed", TICK, bot.decide(node.state), Sim.empty_input())
	audit.check_true(node.state.result != null, "result/the_scripted_match_reaches_a_result")
	var payload: Dictionary = node.call("result_payload")
	var result: Dictionary = payload.get("result", {})
	var route: Dictionary = node.call("finish_route", true)
	audit.check_eq(String(route.get("action", "")), "result", "result/the_finish_route_is_the_result")
	audit.check_eq(Config.pending_result.is_empty(), false, "result/the_payload_waits_for_the_host")
	node.queue_free()
	await process_frame

	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var router: Control = host.call("ui_router")
	audit.check_eq(String(router.call("active_id")), "result", "result/the_host_boots_straight_onto_the_result")
	var screen: Node = router.call("active_screen")
	var shown: Array = screen.call("score_numbers") if screen != null else []
	audit.check_eq(str(shown), str([int(result.get("player", -1)), int(result.get("ai", -2))]), "result/and_shows_the_matches_own_numbers")
	audit.check_eq(Config.pending_result.is_empty(), true, "result/the_payload_is_consumed_once")
	# The rematch: the result screen's own request, handled by the host.
	if screen != null and screen.has_signal("rematch_requested"):
		screen.emit_signal("rematch_requested")
	var rematch: Dictionary = host.call("rematch_route", true)
	audit.check_eq(String(rematch.get("scene", "")), "res://game/Match.tscn", "rematch/rematch_goes_back_to_the_match_scene")
	audit.check_eq(String(rematch.get("mode", "")), "quick", "rematch/and_keeps_the_run_mode")
	(pair[0] as Node).queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 6. settings: stored AND applied
# ---------------------------------------------------------------------------

func _settings_apply_what_they_store(audit: AuditBase) -> void:
	var pair: Array = await _mount_host()
	var host: Control = pair[1]
	var router: Control = host.call("ui_router")
	audit.check_eq(bool(router.call("go_to", "settings")), true, "settings/the_router_mounts_the_settings_screen")
	for _i in SETTLE_FRAMES:
		await process_frame
	var screen: Node = router.call("active_screen")
	var before := float(screen.call("volume"))
	var row_id := String(screen.call("focus_id", "VolumeRow"))
	var bridge = host.get("_bridge")
	var set_ok := bridge != null and bool(bridge.call("set_focus", row_id))
	audit.check_true(set_ok, "settings/the_volume_row_takes_the_focus")
	var stepped := before
	if set_ok:
		audit.check_eq(bool(bridge.call("dispatch", _key_event(KEY_RIGHT))), true, "settings/the_right_press_is_handled")
		stepped = float(screen.call("volume"))
	audit.check_ne(stepped, before, "settings/the_press_steps_the_row")
	var stored: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	audit.check_true(is_equal_approx(float(stored.get("volume", -1.0)), stepped), "settings/the_step_lands_in_the_save")
	# F6: the same value reaches the audio module the host applies it through.
	var port = host.get("_audio_port")
	audit.check_true(port != null, "settings/the_host_owns_the_audio_application")
	if port != null and port.has_method("master_gain"):
		audit.check_true(is_equal_approx(float(port.master_gain()), stepped), "settings/the_stepped_value_is_APPLIED_to_the_mixer (F6)")
	(pair[0] as Node).queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 7. F1: the stored human mode reaches the state
# ---------------------------------------------------------------------------

func _human_modes_reach_the_state(audit: AuditBase) -> void:
	for mode in ["coop", "pvp"]:
		ModesSave.save_pref(Config.save_store(), "playerMode", mode)
		Config.pending_player_mode = mode
		var node := _quick_match()
		audit.check_eq(String(node.state.humanMode), mode, "human/%s_reaches_the_state" % mode)
		audit.check_eq(bool(node.state.coop), mode == "coop", "human/%s_sets_the_coop_flag" % mode)
		audit.check_eq(bool(node.state.pvp), mode == "pvp", "human/%s_sets_the_pvp_flag" % mode)
		node.queue_free()
		await process_frame
	# The reference forces solo everywhere else (`js/main.js:1156`).
	ModesSave.save_pref(Config.save_store(), "playerMode", "coop")
	Config.pending_player_mode = "coop"
	Config.pending_mode = "drill"
	var node: Node = MATCH_SCENE.instantiate()
	root.add_child(node)
	node.harness_mode()
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(String(node.state.humanMode), "solo", "human/a_non_quick_mode_stays_solo")
	node.queue_free()
	await process_frame


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


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("uir-route-audit"):
		for f in dir.get_files_at("user://uir-route-audit"):
			DirAccess.remove_absolute("user://uir-route-audit/%s" % f)
		DirAccess.remove_absolute("user://uir-route-audit")
