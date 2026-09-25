extends SceneTree
## AD-HOC repair probe (2026-09-20, project root, outside the sweep's hashed trees).
##
## Question: while a shot is charging, does the athlete still move — on the keyboard,
## and on a pad?
##
##   $GODOT --headless --path godot/ --script res://_probe_charge_move.gd
##
## Method: inject real input events through `Input.parse_input_event`, READ THEM BACK
## (an injection that did not register cannot be reported as a result), then drive the
## SHIPPING sampler (`game/input_map.gd`), the SHIPPING simulation and the SHIPPING
## athlete view with what they return — the gait word below is the live rig's own clip
## state, not this file's guess.
##
## Two measured traps, both hit before this file was right:
##   * `Input.get_connected_joypads()` is EMPTY in `_initialize` and fills in a few
##     frames later — reading it on the first call says "no controller" on a desk that
##     has one;
##   * a state left in `serving` moves nobody: the serve positioner moves the server,
##     which reads as "the athlete moved" whatever the input says. The rally state
##     below is `tests/audits/controller_tactics_audit.gd`'s own recipe.
##
## Baseline for the same probe: `git show HEAD:godot/game/input_map.gd > godot/game/input_map.gd`
## and re-run.

const InputSource := preload("res://game/input_map.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const AthletesView := preload("res://game/athletes_view.gd")

const DT := 1.0 / 120.0
const TICKS := 60

var _state


func _initialize() -> void:
	for _i in 4:
		await process_frame
	_state = _fresh()
	print("# connected_pads=%s names=%s" % [
		str(Input.get_connected_joypads()),
		str([Input.get_joy_name(0), Input.get_joy_name(1)])])
	_pad_section(Input.get_connected_joypads())
	_keyboard_section()
	quit(0)


func _pad_section(pads: Array) -> void:
	if pads.is_empty():
		print("# PAD: the engine reports no connected joypad, so no stick can be read here.")
		return
	var device: int = int(pads[0])
	Input.parse_input_event(_axis_event(device, JOY_AXIS_LEFT_X, 0.9))
	Input.parse_input_event(_button_event(device, JOY_BUTTON_A, true))
	Input.flush_buffered_events()
	var axis_read: float = Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var button_read: bool = Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	print("# PAD: device=%d injected axis=0.900 button=pressed -> readback axis=%.3f button=%s" % [
		device, axis_read, str(button_read)])
	if absf(axis_read) < 0.5 or not button_read:
		print("# PAD: INJECTION_FAILED - the engine ignored the synthetic pad event.")
		return
	var sampler := InputSource.new()
	sampler.set_device(device)
	var sampled: Dictionary = sampler.sample(_state)
	print("# PAD: FIRST sample moveX=%.3f charging=%s (aim=%.3f analogAim=%s)" % [
		float(sampled.get("moveX", 0.0)), str(sampled.get("charging", false)),
		float(sampled.get("aim", 0.0)), str(sampled.get("analogAim", false))])
	_run("PAD-CHARGING", sampler)


func _keyboard_section() -> void:
	Input.parse_input_event(_key_event(KEY_D, true))
	Input.parse_input_event(_key_event(KEY_SPACE, true))
	Input.flush_buffered_events()
	var d_read: bool = Input.is_physical_key_pressed(KEY_D)
	var space_read: bool = Input.is_physical_key_pressed(KEY_SPACE)
	print("# KEY: injected d+space -> readback d=%s space=%s" % [str(d_read), str(space_read)])
	if not d_read or not space_read:
		print("# KEY: INJECTION_FAILED - the engine ignored the synthetic key events.")
		return
	var sampler := InputSource.new()
	var sampled: Dictionary = sampler.sample(_state)
	print("# KEY: sample moveX=%.3f right=%s charging=%s" % [
		float(sampled.get("moveX", 0.0)), str(sampled.get("right", false)),
		str(sampled.get("charging", false))])
	_run("KEY-CHARGING", sampler)
	Input.parse_input_event(_key_event(KEY_SPACE, false))
	Input.flush_buffered_events()
	_run("KEY-FREE", sampler)


## Drives the sim through the sampler for `TICKS` ticks; reports the ground the athlete
## covered and the live rig's own gait word under the same state.
func _run(label: String, sampler) -> void:
	var state: Variant = _fresh()
	var start_x: float = state.player.x
	var charging_ticks := 0
	for _i in TICKS:
		var input: Dictionary = sampler.sample(state)
		if bool(input.get("charging", false)):
			charging_ticks += 1
		Sim.update_match(state, DT, input)
	var travel: float = state.player.x - start_x
	print("# %s: ticks=%d charging_ticks=%d travel=%.2fpx (%.1f px/s) shotCharge=%.3f speed=%.1f paw=%s" % [
		label, TICKS, charging_ticks, travel, travel / (TICKS * DT),
		float(state.shotCharge), float(state.player.speed), String(state.activePlayerKey)])
	print("# %s: rig_gait=%s" % [label, _rig_gait(state)])


## The shipping view's own answer: `athletes_view._sync_gait` drives the rig, and the rig
## reports the clip it is running (`athlete_rig.get_pose()["locomotion"]`).
func _rig_gait(state) -> String:
	var view: Variant = AthletesView.new()
	root.add_child(view)
	var spawned: int = view.spawn(
		{"player": {"id": String(Frozen.athletes()[0]["id"])}},
		{"player": &"base"},
		{"player": Color.RED})
	if spawned != 1:
		view.free()
		return "no-rig"
	view.sync(state)
	var rig: Node3D = view.rig("player")
	var gait := "?"
	if rig != null and rig.has_method("get_pose"):
		var pose: Dictionary = rig.get_pose()
		gait = String(pose.get("locomotion", "?"))
	view.free()
	return gait


## A rally tick, not a serve: `tests/audits/controller_tactics_audit.gd`'s own movement
## recipe (`state_at_contact`, `:114-132`).
func _fresh() -> Variant:
	var court: Dictionary = Frozen.court()
	var state = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.running = true
	state.serving = false
	state.player.x = 480.0
	state.player.y = float(court["bottom"]) - 70.0
	state.player.hitCooldown = 0.0
	state.player.moveRatio = 0.0
	state.ball.x = 480.0
	state.ball.y = float(court["netY"]) - 130.0
	state.ball.z = 80.0
	state.ball.vx = 0.0
	state.ball.vy = -80.0
	state.ball.vz = 0.0
	state.ball.bounces = {"player": 0, "ai": 1}
	state.ball.serveInFlight = false
	return state


func _axis_event(device: int, axis: int, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	return ev


func _button_event(device: int, button: int, pressed: bool) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	ev.pressure = 1.0 if pressed else 0.0
	return ev


func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	return ev
