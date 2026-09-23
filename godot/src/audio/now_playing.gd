extends PanelContainer
## Non-interactive, short-lived track notice. Never participates in menu focus.
var _timer := 0.0
var _title: Label
var _cover: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.12, 0.9)
	style.border_color = Color(0.08, 0.75, 0.83, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_cover = TextureRect.new()
	_cover.custom_minimum_size = Vector2(44, 44)
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_cover)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var caption := Label.new()
	caption.text = "♫  NOW PLAYING · R3 NEXT"
	caption.add_theme_font_size_override("font_size", 10)
	caption.modulate = Color(0.3, 0.85, 0.9)
	words.add_child(caption)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(_title)
	hide()

func show_track(id: String, in_match: bool) -> void:
	var manager = preload("res://src/audio/soundtrack_manager.gd")
	_title.text = "Steam Circuit · Original Match Theme" if id == "classic_match" else String(manager.TRACK_METADATA.get(id, {}).get("title", id))
	tooltip_text = _title.text
	var cover_id := "ost_menu" if id == "classic_match" else id
	_cover.texture = null
	for extension in ["png", "jpg"]:
		var path := "res://assets/images/jukebox_covers/%s.%s" % [cover_id, extension]
		if ResourceLoader.exists(path):
			_cover.texture = load(path)
			break
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null:
				_cover.texture = ImageTexture.create_from_image(img)
				break
	var viewport := get_viewport_rect().size
	size = Vector2(minf(320, viewport.x - 32), 64)
	position = Vector2(viewport.x - size.x - 20 if in_match else 20, viewport.y - size.y - 24)
	_timer = 3.5 if in_match else 5.0
	modulate.a = 0.0
	show()

func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	modulate.a = minf(move_toward(modulate.a, 1.0, delta * 4), maxf(_timer * 2, 0))
	if _timer <= 0:
		hide()
