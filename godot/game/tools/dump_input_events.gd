extends SceneTree
## Dumps the exact `project.godot` serialisation of the InputEvent objects the
## slice needs, so `godot/project.godot` is edited with strings the engine wrote
## rather than strings typed by hand.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 60 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://game/tools/dump_input_events.gd
##
## Output is copy-pasted into the `[input]` section. Nothing here runs at game
## time.

func _initialize() -> void:
	var specs: Array = [
		["padel_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(0, -1.0)]],
		["padel_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(0, 1.0)]],
		["padel_up", [_key(KEY_W), _key(KEY_UP), _joy_axis(1, -1.0)]],
		["padel_down", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(1, 1.0)]],
		# js/main.js:1079 charges on space; js/main.js:1076 queues the hit on the
		# space keyUP. ProjectSettings cannot express "on release", so the slice
		# reads release separately (see input_map.gd) and this action is the
		# held state.
		["padel_drive", [_key(KEY_SPACE), _joy_button(0)]],
		# js/main.js:1086: meta is the slice charge, and its keyup queues a slice
		# hit. Same "release read separately" note.
		["padel_slice", [_key(KEY_META), _joy_button(2)]],
		# js/main.js:1079: the browser wires no keyboard lob. Pad Y keeps the
		# browser's own button (pollGamepadGameplay, button 3).
		["padel_lob", [_joy_button(3)]],
		# js/main.js:2571: Alt queues the special; js/main.js buttons[1] is B.
		["padel_special", [_key(KEY_ALT), _joy_button(1)]],
		# js/main.js:2572: Tab and Z queue a player switch; buttons[4] is LB.
		["padel_switch", [_key(KEY_TAB), _key(KEY_Z), _joy_button(4)]],
		# js/main.js:792: buttons[6] (LT) is the analog split step.
		["padel_split_step", [_joy_button(6)]],
		# js/main.js:793: buttons[7] (RT) is the analog sprint; axis 5 mirrors it.
		["padel_sprint", [_joy_button(7), _joy_axis(5, 1.0)]],
		# js/main.js:794: buttons[5] (RB) is the technical modifier.
		["padel_technical", [_joy_button(5)]],
		# js/main.js:803: D-pad 12/13/14/15 = attack / defend / staggered / balanced.
		["padel_tactic_attack", [_joy_button(12)]],
		["padel_tactic_defend", [_joy_button(13)]],
		["padel_tactic_staggered", [_joy_button(14)]],
		["padel_tactic_balanced", [_joy_button(15)]],
		# In-match keys the browser owns (js/main.js:2519 escape pauses,
		# js/main.js:2532 r replays). No replay in this slice, so only pause/back.
		["padel_pause", [_key(KEY_ESCAPE), _joy_button(9)]],
		# Menu navigation is Godot's own: ui_up / ui_down / ui_left / ui_right /
		# ui_accept / ui_cancel already carry the arrow keys, WASD is not part of
		# them, and they already carry the D-pad, the left stick and pad A/B, so
		# the menu needs no second navigation scheme that could fight them.
		["menu_quit", [_key(KEY_Q)]],
	]
	for spec in specs:
		var action: String = spec[0]
		var parts: Array = []
		for event in spec[1]:
			parts.append(var_to_str(event))
		print("__BEGIN__%s" % action)
		print("%s={\n\"deadzone\": 0.5,\n\"events\": [%s]\n}" % [action, ", ".join(parts)])
		print("__END__%s" % action)
	print("__INPUT_DUMP_DONE__")
	quit(0)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _joy_button(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
