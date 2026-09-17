extends SceneTree
## port_frame_glue.gd — production frame glue of the ACTUAL Godot A-button path.
##
## Drives the REAL `game/Match.tscn` -> `apply_frame` -> `advance_frame` ->
## `tick_fixed` -> `Sim.update_match` with the REAL `input_map.gd.sample`.
## The only override is the device seam (`_button`/`_axis`/`_key_pressed`), the
## same boundary the pre-existing shot_sequences_test.gd mocks. The latch that
## survives a zero-substep frame (match_controller.gd:965-967) is the production
## behaviour under test; nothing here reimplements it.
##
## Reads the SAME production-rate corpus the JS harness reads, feeds the same
## button/axis timeline, and emits the SAME per-frame JSON schema, so the two
## traces are comparable field-by-field.

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const TICK := 1.0 / 120.0
const SEED := 12345
const CORPUS_PATH := "res://integration/corpus/production_rate.json"

## Browser (standard Gamepad API) button index -> Godot JOY_BUTTON constant.
## Browser: A=0 B=1 X=2 Y=3 LB=4 RB=5 LT/RT=6/7 dpad=12..15.
## Godot:   A=0 B=1 X=2 Y=3 LB=9 RB=10 dpad=11..14. LT/RT are axes, not buttons.
const BTN_MAP := {
	0: JOY_BUTTON_A, 1: JOY_BUTTON_B, 2: JOY_BUTTON_X, 3: JOY_BUTTON_Y,
	4: JOY_BUTTON_LEFT_SHOULDER, 5: JOY_BUTTON_RIGHT_SHOULDER,
	12: JOY_BUTTON_DPAD_UP, 13: JOY_BUTTON_DPAD_DOWN,
	14: JOY_BUTTON_DPAD_LEFT, 15: JOY_BUTTON_DPAD_RIGHT,
}
## Browser axis index -> Godot JOY_AXIS constant (same order: lx ly rx ry LT RT).
const AXIS_MAP := [
	JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y,
	JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT,
]


class Pad:
	extends "res://game/input_map.gd"
	var buttons := {}
	var axes := {}
	var keys := {}
	func _button(button: int) -> bool:
		return bool(buttons.get(button, false))
	func _axis(axis: int) -> float:
		return float(axes.get(axis, 0.0))
	func _key_pressed(_action: String) -> bool:
		return false


var _phase := 0
var _frames_total := 0


func _process(_delta: float) -> bool:
	if _phase == 0:
		_phase = 1
		_run()
	return _phase == 2


func _r6(v) -> Variant:
	if v == null:
		return null
	var t := typeof(v)
	if t == TYPE_BOOL or t == TYPE_STRING:
		return v
	if t == TYPE_FLOAT or t == TYPE_INT:
		return "%.6f" % float(v)
	return v


func _fmt(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = _r6(d[k])
	return out


func _expand(frames: Array) -> Array:
	var out: Array = []
	for f in frames:
		var n := int(f.get("n", 1))
		for _i in n:
			out.append(f)
	return out


func _run() -> void:
	var info: Dictionary = Engine.get_version_info()
	var corpus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CORPUS_PATH))
	var scenarios: Array = corpus["scenarios"]
	print("# port_frame_glue engine=%s physics=%d fixedStep=%.6f seed=%d scenarios=%d" % [
		String(info.get("string", "?")), Engine.physics_ticks_per_second, TICK, SEED, scenarios.size(),
	])
	Config.seed_value = SEED
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var packed: PackedScene = load(MATCH_SCENE)
	var node: Node = packed.instantiate()
	node.harness_mode()
	root.add_child(node)
	await process_frame
	# Escape the serve phase once with the real scripted player (input of
	# production, setup only), so the shot-control path is the one under test.
	var bot := ScriptedPlayer.new()
	var esc := 0
	while bool(node.state.serving) and esc < 1500:
		node.tick_fixed(TICK, bot.decide(node.state), Sim.empty_input())
		esc += 1
	if bool(node.state.serving):
		print("# FATAL serve escape failed after 1500 ticks")
		quit(2)
		return
	for sc in scenarios:
		_run_scenario(node, sc)
	print("# summary scenarios=%d frames=%d exit=0" % [scenarios.size(), _frames_total])
	for child in root.get_children():
		root.remove_child(child)
		child.free()
	_phase = 2
	quit(0)


func _run_scenario(node: Node, sc: Dictionary) -> void:
	var pad := Pad.new(true)
	# Reset the frame-glue accumulator so each scenario is an independent replay,
	# exactly like the JS harness re-seeds `simAccumulator = 0` per scenario.
	node.sim_accumulator = 0.0
	# Reset every queue/shot field so each scenario starts from the same rally
	# baseline (the JS oracle creates a fresh baseState per scenario).
	node.state.shotCharge = 0.0
	node.state.queuedShotVariant = "auto"
	node.state.queuedShotPower = 1.0
	node.state.queuedShotAim = 0.0
	node.state.queuedShotAimY = 0.0
	node.state.smashPrimed = false
	node.state.cutVolleyPrimed = false
	node.state.globoPrimed = false
	node.state.playerSwingBuffer = 0.0
	# Isolate the ball: 125 px from the paddle laterally, high up, stationary.
	node.state.ball.x = node.state.player.x
	node.state.ball.y = node.state.player.y - 125.0
	node.state.ball.z = 160.0
	node.state.ball.vx = 0.0
	node.state.ball.vy = 0.0
	node.state.ball.vz = 0.0
	var frames: Array = _expand(sc["frames"])
	var sid := String(sc["id"])
	for i in frames.size():
		var f: Dictionary = frames[i]
		var delta := float(f.get("delta", TICK))
		var b: Array = f.get("b", [])
		var a: Array = f.get("a", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
		pad.buttons = {}
		for bi in b:
			var key: int = int(BTN_MAP.get(int(bi), -1))
			if key >= 0:
				pad.buttons[key] = true
		pad.axes = {}
		for ai in 6:
			var v := float(a[ai])
			if v != 0.0:
				pad.axes[int(AXIS_MAP[ai])] = v
		var sample: Dictionary = pad.sample(node.state)
		var report: Dictionary = node.apply_frame(sample, delta)
		var s = node.state
		var rec := {
			"scenario": sid,
			"frame": i,
			"delta": _r6(delta),
			"steps": int(report.get("steps", 0)),
			"input": _fmt(sample),
			"sim": _fmt({
				"shotCharge": s.shotCharge,
				"shotIntent": s.shotIntent,
				"queuedShotVariant": s.queuedShotVariant,
				"queuedShotPower": s.queuedShotPower,
				"queuedShotAim": s.queuedShotAim,
				"queuedShotAimY": s.queuedShotAimY,
				"smashPrimed": bool(s.smashPrimed),
				"cutVolleyPrimed": bool(s.cutVolleyPrimed),
				"globoPrimed": bool(s.globoPrimed),
				"playerSwingBuffer": s.playerSwingBuffer,
			}),
		}
		print("# trace " + JSON.stringify(rec))
		_frames_total += 1
