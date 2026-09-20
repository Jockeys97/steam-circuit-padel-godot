extends SceneTree
class Pad:
	extends "res://game/input_map.gd"
	var buttons := {}
	var axes := {}
	func _button(button: int) -> bool:
		return buttons.has(str(button))
	func _axis(axis: int) -> float:
		return float(axes.get(str(axis), 0.0))
	func _key_pressed(_action: String) -> bool:
		return false

func _initialize() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var pad := Pad.new()
	for frame in data:
		if frame.get("reset", false): pad = Pad.new()
		pad.buttons = frame.buttons
		pad.axes = frame.axes
		var state: Dictionary = frame.state
		print("INPUT_JSON ", JSON.stringify(pad.sample(state)))
	quit()
