extends SceneTree

const Config := preload("res://game/match_config.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func run() -> void:
	Config.save_dir = "user://menu-pad-single-dispatch-test"
	print("PHYSICAL_DEVICES ", Input.get_connected_joypads())
	for device in Input.get_connected_joypads():
		print("PHYSICAL_PAD ", device, " ", Input.get_joy_name(device))
	var menu = load("res://game/Main.tscn").instantiate()
	root.add_child(menu)
	for i in 5:
		await process_frame
	if "--physical" in OS.get_cmdline_user_args():
		var last := ""
		for i in 1800:
			var current: String = menu._router.active_id() + " / " + menu._focus.focus_id()
			if current != last:
				print("LIVE ", current)
				last = current
			await create_timer(0.025).timeout
		menu.queue_free()
		await process_frame
		quit()
		return
	menu.set_process(false)
	check(menu._playable, "default playable menu mounted")
	menu._bridge.set_focus("menu/PlayButton")
	var initial: String = menu._focus.focus_id()
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = 0.0
	menu._focus.handle_pad_event(motion, 0)
	motion.axis_value = 1.0
	menu._focus.handle_pad_event(motion, 0)
	motion.axis_value = 0.0
	menu._focus.handle_pad_event(motion, 0)
	menu._bridge.set_focus("menu/PlayButton")
	motion.axis_value = 1.0
	menu._input(motion)
	check(menu._focus.focus_id() != initial, "raw stick event moves the model immediately")
	motion.axis_value = 0.0
	menu._input(motion)
	menu._bridge.set_focus("menu/PlayButton")
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	menu._input(press)
	check(menu._router.active_id() == "modes", "raw A enters modes immediately")
	menu._input(press)
	check(menu._router.active_id() == "modes", "a held A event does not activate twice")
	check(menu._router.active_id() == "modes", "held A does not activate the next screen")
	press.pressed = false
	menu._input(press)
	menu.queue_free()
	await process_frame
	quit(1 if failures else 0)
