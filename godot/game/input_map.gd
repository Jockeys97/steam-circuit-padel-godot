## input_map.gd — the 22-field input struct the simulation consumes, filled from
## Godot's InputMap for the keyboard and the gamepad.
##
## Field-for-field the port of `getInput()` / `getInput2()`
## (`js/main.js:1006-1092`), and the one-shot fields follow `consumeOneShot()`
## (`js/main.js:1167-1180`) plus the accumulator loop's comment at
## `js/main.js:1204-1206`: a one-shot is delivered to the FIRST sub-step of a
## rendered frame and cleared before the second.
##
## Device reading, stated plainly because `Input.is_action_pressed()` cannot say
## which device fired: the digital flags and the keyboard movement come from the
## InputMap actions declared in `godot/project.godot`; the two sticks and the
## analog triggers are read per device (`Input.get_joy_axis`, `Input.get_joy_button`).
## When a stick is engaged the browser ignores the keyboard for movement
## (`js/main.js:1012`) and this file does the same.
##
## Keyboard bindings are the browser's: WASD/arrows move, space charges and
## releases a drive, meta charges and releases a slice, alt is the special,
## tab/z switch player. The browser wires NO keyboard lob (lob is pad Y only,
## `js/main.js:1079`), so neither does this slice — that is the reference
## behaviour, not a new gap.
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")

const DEVICE := 0
## `ui.gamepadDeadzone ?? 0.15` (`js/main.js:789`).
const DEADZONE := 0.15
## Right-stick flick threshold for the directional switch (`js/main.js:801`).
const SWITCH_FLICK := 0.72
## Pad button 5 (RB) is the technical modifier (`js/main.js:794`).
const PAD_TECHNICAL := JOY_BUTTON_RIGHT_SHOULDER
const PAD_DRIVE := JOY_BUTTON_A

## `isSliceAction()`: X is a slice, X+RB is a vibora.
const SLICE_ACTIONS := ["slice", "vibora"]

var _prev_pad_drive := false
var _prev_pad_slice := false
var _prev_pad_lob := false


## One 22-field sample. `state` is the live `SimState`; only the smash / cut-volley
## / globo priming flags are read from it, exactly like `pollGamepadGameplay`.
func sample(state) -> Dictionary:
	var input := Sim.empty_input()

	# --- left stick / keyboard movement ------------------------------------
	var stick := _radial(Input.get_joy_axis(DEVICE, JOY_AXIS_LEFT_X), Input.get_joy_axis(DEVICE, JOY_AXIS_LEFT_Y))
	var using_pad_move: bool = stick.length() > 0.02
	var keyboard_x: float = (-1.0 if Input.is_action_pressed("padel_left") else 0.0) + (1.0 if Input.is_action_pressed("padel_right") else 0.0)
	var keyboard_y: float = (-1.0 if Input.is_action_pressed("padel_up") else 0.0) + (1.0 if Input.is_action_pressed("padel_down") else 0.0)
	var keyboard_length: float = maxf(1.0, sqrt(keyboard_x * keyboard_x + keyboard_y * keyboard_y))

	input["left"] = keyboard_x < 0.0
	input["right"] = keyboard_x > 0.0
	input["up"] = keyboard_y < 0.0
	input["down"] = keyboard_y > 0.0
	input["moveX"] = stick.x if using_pad_move else keyboard_x / keyboard_length
	input["moveY"] = stick.y if using_pad_move else keyboard_y / keyboard_length

	# --- charge action ------------------------------------------------------
	var technical: bool = Input.is_joy_button_pressed(DEVICE, PAD_TECHNICAL)
	var pad_drive: bool = Input.is_joy_button_pressed(DEVICE, PAD_DRIVE)
	var pad_slice: bool = Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_X)
	var pad_lob: bool = Input.is_joy_button_pressed(DEVICE, JOY_BUTTON_Y)
	var key_drive: bool = Input.is_action_pressed("padel_drive")
	var key_slice: bool = Input.is_action_pressed("padel_slice")

	var charge_action: Variant = null
	if pad_drive:
		charge_action = "chiquita" if technical else "drive"
	elif pad_slice:
		charge_action = "vibora" if technical else "slice"
	elif pad_lob:
		charge_action = "defensive-lob" if technical else "lob"
	elif key_drive:
		charge_action = "drive"
	elif key_slice:
		charge_action = "slice"

	input["charging"] = charge_action != null
	input["shotVariant"] = charge_action
	input["slice"] = charge_action != null and SLICE_ACTIONS.has(String(charge_action))

	# --- right stick: analog aim, or the directional switch -----------------
	var right := _radial(Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_X), Input.get_joy_axis(DEVICE, JOY_AXIS_RIGHT_Y))
	if charge_action != null:
		if right.length() > 0.02:
			input["aim"] = right.x
			input["aimY"] = right.y
			input["analogAim"] = true
	elif right.length() >= SWITCH_FLICK:
		input["switchDirection"] = {"x": right.x, "y": right.y}

	# --- one-shots: the hit is queued on RELEASE ----------------------------
	# `js/main.js:2573-2580` queues the hit on keyup, so a tap is a short-charge
	# shot and holding builds power. The pad reads the same way: chargeAction is
	# a held state and its falling edge queues the hit (`js/main.js:884-899`).
	if Input.is_action_just_released("padel_drive") or (_prev_pad_drive and not pad_drive):
		input["hit"] = true
		input["slice"] = false
	if Input.is_action_just_released("padel_slice") or (_prev_pad_slice and not pad_slice):
		input["hit"] = true
		input["slice"] = true
	_prev_pad_drive = pad_drive
	_prev_pad_slice = pad_slice

	# --- one-shots: the second tap upgrades a primed shot -------------------
	# `js/main.js:824-846`: a fresh A press while the smash is primed, a fresh X
	# while a cut volley is primed, a fresh Y while a globo is primed.
	var a_fresh: bool = pad_drive and not _prev_pad_drive_prev
	var x_fresh: bool = pad_slice and not _prev_pad_slice_prev
	var y_fresh: bool = pad_lob and not _prev_pad_lob
	if a_fresh and _smash_primed(state):
		input["smashUpgrade"] = true
	if x_fresh and _flag(state, "cutVolleyPrimed"):
		input["cutVolley"] = true
	if y_fresh and _flag(state, "globoPrimed"):
		input["globo"] = true
	_prev_pad_drive_prev = pad_drive
	_prev_pad_slice_prev = pad_slice
	_prev_pad_lob = pad_lob

	input["special"] = Input.is_action_just_pressed("padel_special")
	input["switchPlayer"] = Input.is_action_just_pressed("padel_switch")

	if Input.is_action_just_pressed("padel_tactic_attack"):
		input["teamTactic"] = "attack"
	elif Input.is_action_just_pressed("padel_tactic_defend"):
		input["teamTactic"] = "defend"
	elif Input.is_action_just_pressed("padel_tactic_staggered"):
		input["teamTactic"] = "staggered"
	elif Input.is_action_just_pressed("padel_tactic_balanced"):
		input["teamTactic"] = "balanced"

	# LT / RT are analog (`js/main.js:792-793`).
	input["splitStep"] = clampf(Input.get_joy_axis(DEVICE, JOY_AXIS_TRIGGER_LEFT), 0.0, 1.0)
	input["sprint"] = clampf(Input.get_joy_axis(DEVICE, JOY_AXIS_TRIGGER_RIGHT), 0.0, 1.0)
	input["technicalModifier"] = technical

	return input


var _prev_pad_drive_prev := false
var _prev_pad_slice_prev := false


func _flag(state, key: String) -> bool:
	return state != null and bool(state.get(key))


func _smash_primed(state) -> bool:
	if state == null:
		return false
	if bool(state.get("smashPrimed")):
		return true
	var paddle = state.active_player()
	return paddle != null and bool(paddle.smashPrimed)


## `consumeOneShot` (`js/main.js:1167-1180`): the same dict with every one-shot
## field cleared, for the second and later sub-steps of a rendered frame.
static func consume_one_shots(input: Dictionary) -> Dictionary:
	var out := input.duplicate()
	out["hit"] = false
	out["special"] = false
	out["switchPlayer"] = false
	out["switchDirection"] = null
	out["smashUpgrade"] = false
	out["cutVolley"] = false
	out["globo"] = false
	out["teamTactic"] = null
	return out


## Radial deadzone, as `radialStick` does (`js/main.js:789-800`): the deadzone is
## applied to the magnitude and the remaining range is rescaled.
static func _radial(x: float, y: float) -> Vector2:
	var v := Vector2(x, y)
	var magnitude := v.length()
	if magnitude <= DEADZONE:
		return Vector2.ZERO
	var scaled := (magnitude - DEADZONE) / (1.0 - DEADZONE)
	return v.normalized() * minf(1.0, scaled)


## A scripted sample for the headless slice run and the capture harness: the same
## 22 fields, filled from a plain dictionary of overrides.
static func scripted(overrides: Dictionary = {}) -> Dictionary:
	var input := Sim.empty_input()
	for key in overrides:
		input[key] = overrides[key]
	return input
