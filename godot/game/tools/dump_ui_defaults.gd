extends SceneTree
## Dumps `ui_accept` and `ui_cancel` as SUPERSETS of the engine's own defaults:
## same events the engine ships, plus the pad button the engine's default set is
## missing. Godot 4.7's defaults give the D-pad and the left stick to
## ui_up/down/left/right but give ui_accept and ui_cancel NO joypad event, so a
## pad-only player could move the menu focus and then had no button to press.
## Nothing is removed: the keycode events below are the engine's own, taken with
## `var_to_str` on the events `InputMap.action_get_events()` returns.

func _initialize() -> void:
	for action in ["ui_accept", "ui_cancel"]:
		print("__BEGIN__%s" % action)
		var parts: Array = []
		for e in InputMap.action_get_events(action):
			parts.append(var_to_str(e))
		if action == "ui_accept":
			var a := InputEventJoypadButton.new()
			a.button_index = JOY_BUTTON_A
			parts.append(var_to_str(a))
			var start := InputEventJoypadButton.new()
			start.button_index = JOY_BUTTON_START
			parts.append(var_to_str(start))
		else:
			var b := InputEventJoypadButton.new()
			b.button_index = JOY_BUTTON_B
			parts.append(var_to_str(b))
		print("%s={\n\"deadzone\": 0.5,\n\"events\": [%s]\n}" % [action, ", ".join(parts)])
		print("__END__%s" % action)
	quit(0)
