## A real-scene controller smoke test: menu -> mode card -> team -> arena ->
## match -> pause -> resume. Unlike the focus-model audits, every confirm is sent
## through the live scene's input handler. No physical gamepad is implied.
extends SceneTree

const Config := preload("res://game/match_config.gd")

var failures := 0
var stage := "boot"
var host: Control
var evidence_dir := ""
var trace: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Config.save_dir = "user://controller-match-journey-%d" % Time.get_ticks_usec()
	evidence_dir = ProjectSettings.globalize_path(Config.save_dir)
	root.size = Vector2i(1280, 720)
	host = load("res://game/Main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	await _frames(6)
	if not _assert_route("menu"):
		await _finish()
		return
	if not await _focus_and_confirm("menu/PlayButton"):
		await _finish()
		return
	if not _assert_route("modes"):
		await _finish()
		return
	stage = "mode card"
	await _pad_down()
	_check(host._focus.focus_id().begins_with("modes/ModeCard_"), "left stick reaches a mode card from Back")
	var quick := "modes/ModeCard_quick"
	_check(host._focus.focusable_ids().has(quick), "quick mode card is in the live pad focus registry")
	if not await _focus_and_confirm(quick):
		await _finish()
		return
	if not _assert_route("characters"):
		await _finish()
		return
	stage = "team confirm"
	if not await _focus_and_confirm("characters/HeadAction"):
		await _finish()
		return
	if not _assert_route("arena"):
		await _finish()
		return
	stage = "arena card"
	await _pad_down()
	_check(host._focus.focus_id().begins_with("arena/ArenaCard_") or host._focus.focus_id().begins_with("arena/WorldArenaCard_"),
		"left stick reaches an arena card from Back")
	var arena_card := _first_offered_arena_card()
	_check(arena_card != "", "an offered arena card is pad-focusable")
	if arena_card == "" or not await _focus_and_confirm(arena_card):
		await _finish()
		return
	await _frames(12)
	stage = "match"
	var match_scene := current_scene
	_check(match_scene != null and match_scene.scene_file_path == "res://game/Match.tscn", "arena confirm launches the real match scene")
	if match_scene == null or match_scene.scene_file_path != "res://game/Match.tscn":
		await _finish()
		return
	_check(match_scene.state != null, "match simulation started")
	stage = "pause"
	_send_pad_button(JOY_BUTTON_START, true)
	await _frames(3)
	_check(match_scene.is_paused(), "controller Start pauses the match")
	_check(match_scene._pause_overlay != null and match_scene._pause_overlay.is_open(), "pause overlay is visible")
	stage = "pause back"
	_send_pad_button(JOY_BUTTON_START, false)
	_send_pad_button(JOY_BUTTON_B, true)
	await _frames(3)
	_check(not match_scene.is_paused(), "controller B returns from pause to the match")
	_send_pad_button(JOY_BUTTON_B, false)
	await _finish()


func _focus_and_confirm(id: String) -> bool:
	stage = id
	await _frames(4)
	var registered: bool = host._focus.focusable_ids().has(id)
	_check(registered, "%s is pad-focusable" % id)
	if not registered:
		return false
	_check(host._focus.reachable_ids().has(id), "%s is reachable by pad directions" % id)
	var focused: bool = host._bridge.set_focus(id)
	host._apply_focus()
	_check(focused and host._focus.focus_id() == id, "%s takes model focus" % id)
	_check(root.gui_get_focus_owner() == host._focus.focus_node(), "%s paints visible focus" % id)
	if not focused:
		return false
	var scene_before: Node = current_scene
	_send_pad_button(JOY_BUTTON_A, true)
	await _frames(3)
	# Arena confirmation replaces and frees the menu host; the release then belongs
	# to the new scene, never to the old node.
	if is_instance_valid(host) and current_scene == scene_before:
		_send_pad_button(JOY_BUTTON_A, false)
	await _frames(4)
	return current_scene != null


func _first_offered_arena_card() -> String:
	var screen: Node = host._router.active_screen()
	for id in host._focus.focusable_ids():
		var key := String(id)
		if not key.begins_with("arena/ArenaCard_") and not key.begins_with("arena/WorldArenaCard_"):
			continue
		var arena_id := key.trim_prefix("arena/ArenaCard_").trim_prefix("arena/WorldArenaCard_")
		if screen.arena_card_state(arena_id) in ["selectable", "in_program"]:
			return key
	return ""


func _assert_route(expected: String) -> bool:
	var ok: bool = is_instance_valid(host) and host._router.active_id() == expected
	_check(ok, "route is %s" % expected)
	if ok:
		trace.append({"stage": stage, "route": expected, "focus": host._focus.focus_id()})
	return ok


func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if ok:
		return
	failures += 1
	_capture_failure(label)


func _capture_failure(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var info := {
		"stage": stage,
		"failure": label,
		"scene": current_scene.scene_file_path if current_scene != null else "",
		"route": host._router.active_id() if is_instance_valid(host) and host._router != null else "",
		"focus": host._focus.focus_id() if is_instance_valid(host) and host._focus != null else "",
		"focusable": host._focus.focusable_ids() if is_instance_valid(host) and host._focus != null else [],
		"trace": trace,
	}
	var path := evidence_dir.path_join("failure-%02d.json" % failures)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
	print("CONTROLLER_JOURNEY_EVIDENCE ", path)
	if DisplayServer.get_name() != "headless":
		var image := root.get_texture().get_image()
		if image != null and not image.is_empty():
			image.save_png(evidence_dir.path_join("failure-%02d.png" % failures))


func _pad_button(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	return event


func _send_pad_button(index: JoyButton, pressed: bool) -> void:
	Input.parse_input_event(_pad_button(index, pressed))
	Input.flush_buffered_events()


func _pad_down() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = 1.0
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await _frames(3)
	motion.axis_value = 0.0
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await _frames(3)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _finish() -> void:
	print("CONTROLLER_MATCH_JOURNEY %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	if current_scene != null:
		current_scene.queue_free()
		await _frames(2)
	quit(0 if failures == 0 else 1)
