extends Button
## Drawn star: independent of the glyphs present in the UI font.
func _ready() -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(38, 36)
	theme_type_variation = &"SegmentedInactive"
	toggled.connect(func(_on): queue_redraw())

func _draw() -> void:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI / 2 + index * PI / 5
		var radius := 11.0 if index % 2 == 0 else 5.0
		points.append(size / 2 + Vector2(cos(angle), sin(angle)) * radius)
	if button_pressed:
		draw_colored_polygon(points, Color("ffda6e"))
	points.append(points[0])
	draw_polyline(points, Color("ffda6e") if button_pressed else Color("9db4cb"), 1.7, true)
