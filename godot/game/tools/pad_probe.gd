## pad_probe.gd — what macOS hands Godot, and what this build does with it.
##
##   $GODOT --path godot/ --script res://game/tools/pad_probe.gd
##   … add `--headless` to run it without opening a window.
##
## It prints, once: every connected pad with its device id and its OS name, and which
## device `InputSource.select_device()` would read — the answer to "is my controller
## device 0 or 1 on this machine?", which is what a fixed `DEVICE := 0` got wrong.
##
## Then, live for `SECONDS`: every button press and every axis push it sees, each
## line naming (a) Godot's own name for that button index and (b) the `padel_*`
## action it fires, read from the LIVE InputMap. The action list is what the game
## itself dispatches on, so pressing LB and reading `padel_switch` is the same
## binding the match uses — not a copy of it that could disagree.
##
## Quit with Escape or Ctrl-C; it stops by itself after `SECONDS`. Exit code 0.
##
## The two numberings, for reading the output: this engine's `JoyButton` is
## 0=A 1=B 2=X 3=Y 4=back 5=guide 6=start 7=LS 8=RS 9=LB 10=RB 11-14=D-pad, with
## LT/RT as AXES 4 and 5. The browser's Gamepad API numbers 4=LB 5=RB 6=LT 7=RT
## 8=back 9=start 10=LS 11=RS 12-15=D-pad — face buttons agree, everything past Y
## does not. A pad_probe line saying `9 (LEFT_SHOULDER/LB) -> padel_switch` is the
## corrected binding; `4 (BACK) -> padel_switch` was the defect.
extends SceneTree

const InputSource := preload("res://game/input_map.gd")

## How long to watch, in seconds. `PAD_PROBE_SECONDS=60` overrides it.
const SECONDS := 20.0
## An axis has to move this far to be reported, so a resting stick stays quiet.
const AXIS_REPORT := 0.15

## Godot's `JoyButton` names, so the output never has to be decoded by hand.
const BUTTON_NAMES := {
	0: "A", 1: "B", 2: "X", 3: "Y",
	4: "BACK/View", 5: "GUIDE", 6: "START", 7: "LEFT_STICK", 8: "RIGHT_STICK",
	9: "LEFT_SHOULDER/LB", 10: "RIGHT_SHOULDER/RB",
	11: "DPAD_UP", 12: "DPAD_DOWN", 13: "DPAD_LEFT", 14: "DPAD_RIGHT",
	15: "MISC1", 16: "PADDLE1", 17: "PADDLE2",
}
const AXIS_NAMES := {
	0: "LEFT_X", 1: "LEFT_Y", 2: "RIGHT_X", 3: "RIGHT_Y",
	4: "TRIGGER_LEFT/LT", 5: "TRIGGER_RIGHT/RT",
}

var _left := SECONDS
var _buttons := {}          # "device:button" -> pressed last frame
var _axes := {}             # "device:axis" -> last reported value


func _initialize() -> void:
	var override := OS.get_environment("PAD_PROBE_SECONDS")
	if override != "":
		_left = float(override)
	var pads := Input.get_connected_joypads()
	print("# pads connected: %d" % pads.size())
	if pads.is_empty():
		print("#   none — attach the controller and run this again (macOS adds it live)")
	for id in pads:
		print("#   device %d: %s" % [id, Input.get_joy_name(id)])
	print("# `selectPrimaryGamepad` would read device %d here (`js/main.js:258-276`)" % InputSource.select_device(InputSource.NO_DEVICE))
	print("# press something: each line names the button and the action this build fires")
	print("# watching for %.0f s — Escape to stop" % _left)


func _process(delta: float) -> bool:
	_left -= delta
	if _left <= 0.0 or Input.is_key_pressed(KEY_ESCAPE):
		print("# done (%d pads still connected)" % Input.get_connected_joypads().size())
		quit(0)
		return true
	for id in Input.get_connected_joypads():
		for button in BUTTON_NAMES.size():
			var key := "%d:%d" % [id, button]
			var now := Input.is_joy_button_pressed(id, button)
			if now != bool(_buttons.get(key, false)):
				_buttons[key] = now
				if now:
					print("device %d · button %d (%s) %s" % [
						id, button, BUTTON_NAMES[button], _actions_for_button(button),
					])
		for axis in AXIS_NAMES.size():
			var key := "%d:%d" % [id, axis]
			var value := Input.get_joy_axis(id, axis)
			var reported := float(_axes.get(key, 0.0))
			if absf(value - reported) >= AXIS_REPORT:
				_axes[key] = value
				print("device %d · axis %d (%s) = %.2f %s" % [
					id, axis, AXIS_NAMES[axis], value, _actions_for_axis(axis),
				])
	return false


## The `padel_*` / `ui_*` actions this button index fires in THIS build, read from
## the live InputMap.
static func _actions_for_button(button: int) -> String:
	var out: Array = []
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
				out.append(String(action))
				break
	return "-> %s" % ", ".join(PackedStringArray(out)) if not out.is_empty() else "-> no action"


static func _actions_for_axis(axis: int) -> String:
	var out: Array = []
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == axis:
				out.append(String(action))
				break
	return "-> %s" % ", ".join(PackedStringArray(out)) if not out.is_empty() else "-> no action"
