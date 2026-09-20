extends SceneTree
## Exercises the actual sampler with held/released controls, not binding metadata.
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
class Pad:
	extends "res://game/input_map.gd"
	var buttons := {}
	var axes := {}
	var keys := {}
	func _button(button: int) -> bool:
		return bool(buttons.get(button, false))
	func _axis(axis: int) -> float:
		return float(axes.get(axis, 0.0))
	func _key_pressed(action: String) -> bool:
		return bool(keys.get(action, false))

var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[0], 0, {})
	for primary in [true, false]:
		for row in [[JOY_BUTTON_A, "drive", "chiquita"], [JOY_BUTTON_X, "slice", "vibora"], [JOY_BUTTON_Y, "lob", "defensive-lob"]]:
			for technical in [false, true]:
				var pad := Pad.new(primary)
				var variant: String = row[2] if technical else row[1]
				pad.buttons = {row[0]: true, JOY_BUTTON_RIGHT_SHOULDER: technical}
				pad.axes = {JOY_AXIS_LEFT_X: 0.7, JOY_AXIS_LEFT_Y: -0.4}
				var held := pad.sample(state)
				check(held.charging and not held.hit and held.shotVariant == variant, variant + " charges")
				check(held.moveX == 0 and held.moveY == 0, variant + " stops movement")
				pad.buttons[JOY_BUTTON_RIGHT_SHOULDER] = not technical
				check(pad.sample(state).shotVariant == variant, variant + " stays latched when RB changes")
				pad.buttons = {}
				pad.axes = {}
				var released := pad.sample(state)
				check(released.hit and not released.charging and released.shotVariant == variant, variant + " releases")
				check(released.aim == held.aim and released.aimY == held.aimY and released.analogAim, variant + " preserves aim")
				check(released.slice == (row[0] == JOY_BUTTON_X), variant + " slice flag")
				check(not pad.sample(state).hit, variant + " fires only once")
	# The second press upgrades the primed shot; it must not become another shot.
	for mode in ["solo", "coop", "pvp"]:
		state.humanMode = mode
		for primary in [true, false]:
			if mode == "solo" and not primary: continue
			for row in [[JOY_BUTTON_A, "smashPrimed", "smashUpgrade"], [JOY_BUTTON_X, "cutVolleyPrimed", "cutVolley"], [JOY_BUTTON_Y, "globoPrimed", "globo"]]:
				var target = state if primary else state.playerMate if mode == "coop" else state.get(state.pvpActiveKey)
				if primary and mode == "coop" and row[1] == "smashPrimed": target = state.player
				# Secondary paddles, as in the 2D core, only expose smashPrimed.
				if target.get(row[1]) == null:
					var unprimed := Pad.new(primary)
					unprimed.buttons = {row[0]: true}
					var normal := unprimed.sample(state)
					check(normal.charging and not normal[row[2]], "unprimed secondary shot remains normal")
					continue
				target.set(row[1], true)
				var pad := Pad.new(primary)
				pad.buttons = {row[0]: true}
				var tap := pad.sample(state)
				check(tap[row[2]] and not tap.charging, mode + " upgrade without charge")
				check(not pad.sample(state)[row[2]], mode + " held upgrade is not repeated")
				pad.buttons = {}
				check(not pad.sample(state).hit, mode + " upgrade release is not another hit")
				target.set(row[1], false)
	state.humanMode = "solo"
	var pad := Pad.new()
	pad.buttons = {JOY_BUTTON_A: true, JOY_BUTTON_X: true, JOY_BUTTON_Y: true}
	check(pad.sample(state).shotVariant == "slice", "X has priority over Y and A")
	pad.buttons = {JOY_BUTTON_Y: true}
	check(not pad.sample(state).hit, "changing held button does not fire early")
	pad.buttons = {}
	check(pad.sample(state).shotVariant == "slice", "initial variant survives overlap")
	for action in ["padel_drive", "padel_slice"]:
		pad = Pad.new()
		pad.keys[action] = true
		check(pad.sample(state).charging, action + " keyboard charges")
		pad.keys = {}
		check(pad.sample(state).hit, action + " keyboard releases")
		check(not pad.sample(state).hit, action + " keyboard fires once")
	# Real device-agnostic InputMap events must never leak into another sampler.
	var native = load("res://game/input_map.gd").new(true)
	Input.action_press("padel_drive")
	Input.action_press("padel_special")
	check(not native.sample(state).charging, "unselected controller cannot charge player one")
	check(not native.sample(state).special, "unselected controller cannot fire player one special")
	Input.action_release("padel_drive")
	Input.action_release("padel_special")
	check(not native.sample(state).hit, "unselected controller cannot release player one shot")
	print("%s shot sequences: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
