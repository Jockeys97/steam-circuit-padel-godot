extends Node

var seen := []

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var frame := Control.new()
	frame.size = Vector2(1280, 720)
	add_child(frame)
	var b := Button.new()
	b.text = "hit"
	b.position = Vector2(30, 30)
	b.size = Vector2(60, 30)
	frame.add_child(b)
	var b2 := Button.new()
	b2.text = "far"
	b2.position = Vector2(900, 600)
	b2.size = Vector2(120, 60)
	frame.add_child(b2)
	await get_tree().process_frame
	await get_tree().process_frame
	print("visible_rect=", get_tree().root.get_visible_rect(), " window size=", get_tree().root.size)
	b.button_down.connect(func() -> void: seen.append("near_down"))
	b2.button_down.connect(func() -> void: seen.append("far_down"))
	for pair in [["mouse near", 40.0, 40.0], ["mouse far", 950.0, 620.0], ["touch far", 950.0, 620.0]]:
		var name := String(pair[0])
		var pos := Vector2(float(pair[1]), float(pair[2]))
		if name.begins_with("touch"):
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.pressed = true
			t.position = pos
			Input.parse_input_event(t)
		else:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = true
			mb.position = pos
			mb.global_position = pos
			Input.parse_input_event(mb)
		for _i in 3:
			await get_tree().process_frame
		print(name, " -> seen=", seen)
	get_tree().quit(0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		seen.append("input_node:%s" % event.get_class())
