## input_map.gd — the 22-field input struct the simulation consumes, filled from
## Godot's InputMap for the keyboard and the gamepad.
##
## Field-for-field the port of `getInput()` / `getInput2()`
## (`js/main.js:1047-1094`, `:1096-1134`), and the one-shot fields follow
## `consumeOneShot()` (`js/main.js:1167-1180`) plus the accumulator loop's comment
## at `js/main.js:1204-1206`: a one-shot is delivered to the FIRST sub-step of a
## rendered frame and cleared before the second.
##
## WHICH STICK AIMS. The left one. While a shot button is held the athlete STOPS
## (`js/main.js:924`, `g.move = { x: 0, y: 0 }`) and the left stick becomes the
## absolute aim through `shotAimAxis` (`js/main.js:301-304`, read at `:920-923`);
## the right stick is only ever the directional switch (`:941-951`). This file used
## to aim with the right stick and to keep the athlete moving through the charge,
## which is a different game to play.
##
## WHICH PAD, AND THE TWO NUMBERINGS. Two facts this file has to carry, because
## both were wrong here once:
##
##   1. **The device is chosen, not assumed.** macOS keeps already-connected
##      controllers in the list, so device 0 is not necessarily the pad in the
##      player's hands (`js/main.js:258-276`, `selectPrimaryGamepad`): the pad a
##      button is pressed on takes over, the current one is kept while a local match
##      is running (co-op/PvP lock the two seats, `:780-783`), and the second player
##      gets the next connected pad (`:784`). `select_device` / `assign_devices` are
##      that policy; `godot/game/match_controller.gd` applies it once per frame.
##   2. **A pad that takes over mid-match does not fire the shot it was holding**
##      (`awaitingGameplayRelease`, `js/main.js:838-843`): until A/B/X/Y/LB/RB are
##      all released, the sample carries movement and the triggers and nothing else.
##
## TWO SAMPLERS. `primary` is the first player's (keyboard plus pad); the second
## player's is pad only — no keyboard and no InputMap action — because that is what
## the reference builds for `input2` (`getInput2()`, `js/main.js:1096-1134`).
##
## Device reading, stated plainly because `Input.is_action_pressed()` cannot say
## which device fired: the digital flags and the keyboard movement come from the
## InputMap actions declared in `godot/project.godot`; the two sticks, the analog
## triggers and every button of the second pad are read per device
## (`Input.get_joy_axis`, `Input.get_joy_button`).
##
## Keyboard bindings are the browser's: WASD/arrows move, space charges and
## releases a drive, meta charges and releases a slice, alt is the special,
## tab/z switch player. The browser wires NO keyboard lob (lob is pad Y only,
## `js/main.js:1079`), so neither does this slice — that is the reference
## behaviour, not a new gap.
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")

## No pad is selected (no controller connected, or none chosen yet).
const NO_DEVICE := -1
## `ui.gamepadDeadzone ?? 0.15` (`js/main.js:830`).
const DEADZONE := 0.15
## An axis this far out counts as "somebody touched this pad" when choosing which
## one to read (`GAMEPAD_ACTIVATION_DEADZONE`, `js/main.js:151`).
const ACTIVATION_DEADZONE := 0.45
## Right-stick flick threshold for the directional switch (`js/main.js:943`).
const SWITCH_FLICK := 0.72
## Where the latch re-arms (`js/main.js:948`, `right.magnitude <= 0.3`). Without it
## a held flick fires on every tick: the reference's `switchStickLatched` is what
## turns a threshold into an edge.
const SWITCH_RELEASE := 0.3
## The exponent the reference curves the stick by (`js/main.js:295`).
const STICK_CURVE := 1.28
## And the one it curves the aim by, sign kept (`shotAimAxis`, `js/main.js:301-304`).
const AIM_CURVE := 0.72
## Pad button 5 (RB) is the technical modifier (`js/main.js:836`).
const PAD_TECHNICAL := JOY_BUTTON_RIGHT_SHOULDER
const PAD_DRIVE := JOY_BUTTON_A
## The buttons whose release hands a newly selected pad over to the game
## (`js/main.js:840`: `!b(0) && !b(1) && !b(2) && !b(3) && !b(4) && !b(5)`).
const POSSESSION_BUTTONS := [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
]
## The second player's one-shots are read straight off the pad: B is the special and
## LB the switch (`js/main.js:954`, `:947`), the D-pad sets the pair's tactic
## (`js/main.js:846-850`).
const PAD_SPECIAL := JOY_BUTTON_B
const PAD_SWITCH := JOY_BUTTON_LEFT_SHOULDER
const PAD_TACTICS := {
	JOY_BUTTON_DPAD_UP: "attack",
	JOY_BUTTON_DPAD_DOWN: "defend",
	JOY_BUTTON_DPAD_LEFT: "staggered",
	JOY_BUTTON_DPAD_RIGHT: "balanced",
}
## The analog triggers (`js/main.js:834-835`: `pad.buttons[6].value` is LT).
const AXIS_SPLIT_STEP := JOY_AXIS_TRIGGER_LEFT
const AXIS_SPRINT := JOY_AXIS_TRIGGER_RIGHT

## `isSliceAction()`: X is a slice, X+RB is a vibora.
const SLICE_ACTIONS := ["slice", "vibora"]

## The first player's sampler carries the keyboard as well; the second's does not.
var primary: bool = true
## The pad currently read. `NO_DEVICE` until `set_device` is given one.
var device: int = NO_DEVICE
## `gamepad.switchStickLatched` (`js/main.js:943-950`): a flick fires once, and the
## latch re-arms only when the stick comes back below `SWITCH_RELEASE` — or when a
## shot button is held, which clears it inside the charge (`js/main.js:925`).
var _switch_latched := false
## `gamepad.awaitingGameplayRelease` (`js/main.js:284`, read at `:838`).
var _awaiting_release := false
## The aim of the last charging frame, which the release tick hands to the
## simulation (`shotAimQueued`, `js/main.js:933`, read at `:1056`).
var _last_aim := Vector2.ZERO
var _charge_action: Variant = null
var _smash_consumed := false
var _cut_consumed := false
var _globo_consumed := false
var _key_previous := {}

var _prev_pad_drive := false
var _prev_pad_slice := false
var _prev_pad_lob := false
var _prev_pad_prev := {}          # pad button index -> pressed last tick
var _prev_pad_drive_prev := false
var _prev_pad_slice_prev := false


func _init(primary_in: bool = true, device_in: int = NO_DEVICE) -> void:
	primary = primary_in
	device = device_in


## Points this sampler at a pad. A change hands the pad over the way
## `selectGamepad` does (`js/main.js:276-289`): the previous pad's held keys and
## edges are dropped — a stale falling edge would fire a shot nobody pressed — and
## the new pad takes possession until its buttons are released.
func set_device(next: int) -> void:
	if next == device:
		return
	var had_a_pad: bool = device != NO_DEVICE
	device = next
	_prev_pad_drive = false
	_prev_pad_slice = false
	_prev_pad_lob = false
	_prev_pad_drive_prev = false
	_prev_pad_slice_prev = false
	_prev_pad_prev = {}
	_switch_latched = false
	_last_aim = Vector2.ZERO
	_charge_action = null
	_smash_consumed = false
	_cut_consumed = false
	_globo_consumed = false
	# `selectGamepad` arms the hold whenever the pad CHANGES (`js/main.js:276-289`,
	# gated on a match that is running). The FIRST selection of the match is not a
	# change from the player's point of view: in the browser the pad was picked in the
	# menu, long before the match started, so nothing was armed. Arming it here ate the
	# player's first press of every match — on the pad, the serve.
	_awaiting_release = next != NO_DEVICE and had_a_pad


func awaiting_release() -> bool:
	return _awaiting_release


func sample(state) -> Dictionary:
	var input := Sim.empty_input()
	var technical := _button(PAD_TECHNICAL)
	var a := _button(PAD_DRIVE)
	var x := _button(JOY_BUTTON_X)
	var y := _button(JOY_BUTTON_Y)
	var left := _radial(_axis(JOY_AXIS_LEFT_X), _axis(JOY_AXIS_LEFT_Y))
	var right := _radial(_axis(JOY_AXIS_RIGHT_X), _axis(JOY_AXIS_RIGHT_Y))
	var move := left
	input["splitStep"] = clampf(_axis(AXIS_SPLIT_STEP), 0.0, 1.0)
	input["sprint"] = clampf(_axis(AXIS_SPRINT), 0.0, 1.0)
	input["technicalModifier"] = technical
	if _awaiting_release:
		input["moveX"] = left.x
		input["moveY"] = left.y
		if not _possession_held():
			_awaiting_release = false
		return input

	# Match pollGamepadGameplay: consume an upgrade tap until that button releases.
	if not a: _smash_consumed = false
	if not x: _cut_consumed = false
	if not y: _globo_consumed = false
	var upgrade_aim := false
	if a and not _prev_pad_drive and _seat_flag(state, "smashPrimed"):
		input["smashUpgrade"] = true
		_smash_consumed = true
		upgrade_aim = true
		move = Vector2.ZERO
	if x and not _prev_pad_slice and _seat_flag(state, "cutVolleyPrimed"):
		input["cutVolley"] = true
		_cut_consumed = true
	if y and not _prev_pad_lob and _seat_flag(state, "globoPrimed"):
		input["globo"] = true
		_globo_consumed = true
	_prev_pad_drive = a
	_prev_pad_slice = x
	_prev_pad_lob = y

	# X > Y > A, and the variant is latched when charging STARTS, including RB.
	var shot: Variant = null
	if x and not _cut_consumed: shot = "vibora" if technical else "slice"
	elif y and not _globo_consumed: shot = "defensive-lob" if technical else "lob"
	elif a and not _smash_consumed: shot = "chiquita" if technical else "drive"
	var released := false
	if shot != null:
		if _charge_action == null: _charge_action = shot
		_last_aim = Vector2(shot_aim_axis(left.x), shot_aim_axis(left.y))
		move = Vector2.ZERO
		_switch_latched = false
	elif _charge_action != null:
		input["hit"] = true
		input["slice"] = SLICE_ACTIONS.has(String(_charge_action))
		input["shotVariant"] = _charge_action
		_charge_action = null
		released = true
	else:
		var flick := switch_flick(right, false, _switch_latched)
		_switch_latched = bool(flick["latched"])
		input["switchDirection"] = flick["direction"]

	if _charge_action != null:
		input["shotVariant"] = _charge_action
		input["slice"] = SLICE_ACTIONS.has(String(_charge_action))
	if upgrade_aim:
		_last_aim = Vector2(shot_aim_axis(left.x), shot_aim_axis(left.y))
	if _charge_action != null or released or upgrade_aim:
		input["aim"] = _last_aim.x
		input["aimY"] = _last_aim.y
		input["analogAim"] = true

	# Keyboard events must not include device-agnostic joypad InputMap events.
	var key_drive := primary and _key_pressed("padel_drive")
	var key_slice := primary and _key_pressed("padel_slice")
	if primary and _key_released("padel_drive", key_drive):
		input["hit"] = true
	if primary and _key_released("padel_slice", key_slice):
		input["hit"] = true
		input["slice"] = true
	input["charging"] = _charge_action != null or key_drive or key_slice
	var keyboard := Vector2.ZERO
	if primary:
		keyboard = Vector2(
			float(_key_pressed("padel_right")) - float(_key_pressed("padel_left")),
			float(_key_pressed("padel_down")) - float(_key_pressed("padel_up")))
	keyboard /= maxf(1.0, keyboard.length())
	input["left"] = keyboard.x < 0.0 if primary else move.x < -0.2
	input["right"] = keyboard.x > 0.0 if primary else move.x > 0.2
	input["up"] = keyboard.y < 0.0 if primary else move.y < -0.2
	input["down"] = keyboard.y > 0.0 if primary else move.y > 0.2
	input["moveX"] = move.x if move.length() > 0.02 else keyboard.x
	input["moveY"] = move.y if move.length() > 0.02 else keyboard.y

	var special := _pad_edge(PAD_SPECIAL)
	var switch_player := _pad_edge(PAD_SWITCH)
	input["special"] = special or (primary and _key_edge("padel_special"))
	input["switchPlayer"] = switch_player or (primary and _key_edge("padel_switch"))
	var tactic_actions := ["padel_tactic_attack", "padel_tactic_defend", "padel_tactic_staggered", "padel_tactic_balanced"]
	var i := 0
	for button in PAD_TACTICS:
		var pressed := _pad_edge(int(button))
		if primary: pressed = _key_edge(tactic_actions[i]) or pressed
		if pressed: input["teamTactic"] = PAD_TACTICS[button]
		i += 1
	return input


func _key_pressed(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if event.physical_keycode != 0 and Input.is_physical_key_pressed(event.physical_keycode):
				return true
			if event.keycode != 0 and Input.is_key_pressed(event.keycode):
				return true
	return false


func _key_edge(action: String) -> bool:
	var now := _key_pressed(action)
	var before := bool(_key_previous.get(action, false))
	_key_previous[action] = now
	return now and not before


func _key_released(action: String, now: bool) -> bool:
	var before := bool(_key_previous.get(action, false))
	_key_previous[action] = now
	return before and not now


func _seat_flag(state, key: String) -> bool:
	if state == null: return false
	if not primary:
		var paddle = state.playerMate if state.humanMode == "coop" else state.get(state.pvpActiveKey) if state.humanMode == "pvp" else null
		return paddle != null and paddle.get(key) != null and bool(paddle.get(key))
	if key == "smashPrimed" and state.humanMode == "coop":
		return bool(state.player.get(key))
	return bool(state.get(key))


# ---------------------------------------------------------------------------
# Which pad to read (`selectPrimaryGamepad`, `js/main.js:258-276`)
# ---------------------------------------------------------------------------

## `gamepadHasActivity` (`js/main.js:243-257`): any button pressed, or any axis
## pushed past `GAMEPAD_ACTIVATION_DEADZONE`.
static func device_has_activity(id: int) -> bool:
	if id < 0:
		return false
	for button in 16:
		if Input.is_joy_button_pressed(id, button):
			return true
	for axis in 6:
		if absf(Input.get_joy_axis(id, axis)) >= ACTIVATION_DEADZONE:
			return true
	return false


## The pad the first player should be reading.
##
## `keep_current` is the reference's own parameter for a local co-op/PvP match: the
## two seats are assigned when the match starts and must not be swapped because the
## other pad moved a stick (`js/main.js:780-783`). Everywhere else the pad somebody
## touches takes over; with nobody touching anything the current pad is kept, and a
## fresh list falls back to its first entry.
static func select_device(current: int, keep_current: bool = false) -> int:
	var connected := Input.get_connected_joypads()
	if connected.is_empty():
		return NO_DEVICE
	if keep_current and connected.has(current):
		return current
	for id in connected:
		if id != current and device_has_activity(id):
			return id
	if connected.has(current):
		return current
	return int(connected[0])


## `[primary, second]`: the policy above, then "the next connected pad that is not
## the first one's" (`js/main.js:784`).
static func assign_devices(keep_current: bool, current_primary: int, current_second: int) -> Array:
	var first := select_device(current_primary, keep_current)
	var second := NO_DEVICE
	for id in Input.get_connected_joypads():
		if id != first:
			second = id
			break
	return [first, second]


## The flick's edge and its latch, as a pure function of the stick, the charge state
## and the previous latch — so the audit can assert the sequence without a pad
## (`js/main.js:941-951`).
##
## `{"direction": {"x": .., "y": ..} | null, "latched": bool}`. A direction is
## returned only on the tick the flick arms. Holding a shot button RE-ARMS the latch
## rather than leaving it alone (`js/main.js:925`, inside the charge branch), so
## releasing a charge does not immediately spend the switch.
static func switch_flick(right: Vector2, charging: bool, latched: bool) -> Dictionary:
	if charging:
		return {"direction": null, "latched": false}
	if right.length() >= SWITCH_FLICK and not latched:
		return {"direction": {"x": right.x, "y": right.y}, "latched": true}
	if right.length() <= SWITCH_RELEASE:
		return {"direction": null, "latched": false}
	return {"direction": null, "latched": latched}


## `shotAimAxis` (`js/main.js:301-304`): the sign kept, the magnitude curved.
static func shot_aim_axis(value: float) -> float:
	var clamped := clampf(value, -1.0, 1.0)
	return signf(clamped) * pow(absf(clamped), AIM_CURVE)


## A pad button's falling edge, from the previous sample's own state.
static func released_edge(now: bool, before: bool) -> bool:
	return before and not now


## A button's own rising edge, tracked per sampler.
func _pad_edge(button: int) -> bool:
	var now := _button(button)
	var was := bool(_prev_pad_prev.get(button, false))
	_prev_pad_prev[button] = now
	return now and not was


## `!b(0) && !b(1) && !b(2) && !b(3) && !b(4) && !b(5)` (`js/main.js:840`), in the
## physical buttons the two numberings agree on plus the two shoulders.
func _possession_held() -> bool:
	for button in POSSESSION_BUTTONS:
		if _button(button):
			return true
	return false


func _button(button: int) -> bool:
	return device != NO_DEVICE and Input.is_joy_button_pressed(device, button)


func _axis(axis: int) -> float:
	return Input.get_joy_axis(device, axis) if device != NO_DEVICE else 0.0


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


## Radial deadzone, as `radialStick` does (`js/main.js:291-299`): the deadzone is
## applied to the magnitude, the remaining range is rescaled and the result is
## curved by 1.28 — the reference's own shaping, which this file had flattened into
## a straight line.
static func _radial(x: float, y: float) -> Vector2:
	var v := Vector2(x, y)
	var magnitude := minf(1.0, v.length())
	if magnitude <= DEADZONE:
		return Vector2.ZERO
	var normalized := (magnitude - DEADZONE) / (1.0 - DEADZONE)
	var curved := pow(normalized, STICK_CURVE)
	return Vector2((x / magnitude) * curved, (y / magnitude) * curved)


## A scripted sample for the headless slice run and the capture harness: the same
## 22 fields, filled from a plain dictionary of overrides.
static func scripted(overrides: Dictionary = {}) -> Dictionary:
	var input := Sim.empty_input()
	for key in overrides:
		input[key] = overrides[key]
	return input
