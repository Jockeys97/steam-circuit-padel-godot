extends SceneTree

var _seen := []
var _btn: Button

func _initialize() -> void:
	print("root size start=", root.size)
	root.size = Vector2i(1280, 720)
	print("root size after set=", root.size)
	var frame := Control.new()
	frame.size = Vector2(1280, 720)
	root.add_child(frame)
	_btn = Button.new()
	_btn.text = "hit"
	_btn.position = Vector2(900, 600)
	_btn.size = Vector2(120, 60)
	frame.add_child(_btn)
	for _i in 2:
		await process_frame
	print("root size after frames=", root.size)
	_btn.button_down.connect(func() -> void: _seen.append("down"))
	_btn.pressed.connect(func() -> void: _seen.append("pressed"))
	var centre: Vector2 = _btn.get_global_rect().get_center()
	print("centre=", centre)
	print("emulating=", Input.is_emulating_mouse_from_touch())
	# re-assert the window size BEFORE injecting, the way the fix would
	root.size = Vector2i(1280, 720)
	print("root size re-asserted=", root.size, " visible=", root.get_visible_rect())
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = centre
	Input.parse_input_event(touch)
	for _i in 2:
		await process_frame
	print("seen after touch=", _seen, " hovered=", root.gui_get_hovered_control())
	# now a plain mouse press at the same spot
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = centre
	mb.global_position = centre
	Input.parse_input_event(mb)
	for _i in 2:
		await process_frame
	print("seen after mouse=", _seen, " hovered=", root.gui_get_hovered_control())
	# and a touch inside the window rect
	var t2 := InputEventScreenTouch.new()
	t2.index = 1
	t2.pressed = true
	t2.position = Vector2(30, 30)
	Input.parse_input_event(t2)
	for _i in 2:
		await process_frame
	print("seen after corner touch=", _seen)
	print("root size end=", root.size)
	quit(0)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_seen.append("input:%s:%s" % [event.get_class(), str(event.position if event is InputEventScreenTouch else event.global_position)])
