extends Control
## jukebox_screen.gd — Integrated In-Game Jukebox & Sound Test for Steam Circuit Padel Pro.
##
## Implements the full ScreenShell layout and padel_theme styling, seamlessly matching
## the aesthetic of the other game menus (Help, History, Challenges, Settings).

const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

signal closed

var _manager: Node = null
var _shell: Control = null
var _track_ids: PackedStringArray = []
var _selected_idx: int = 0
var _track_buttons: Array[Button] = []

# Inspector UI references
var _track_list_container: VBoxContainer = null
var _title_label: Label = null
var _scene_label: Label = null
var _category_badge: Label = null
var _status_badge: Label = null
var _bpm_key_label: Label = null
var _style_label: Label = null
var _prompt_text: TextEdit = null
var _copy_btn: Button = null
var _play_btn: Button = null
var _stop_btn: Button = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _volume_slider: HSlider = null
var _now_playing_label: Label = null


func _ready() -> void:
	theme = DefaultTheme
	_track_ids = SoundtrackManager.all_track_ids()
	_manager = SoundtrackManager.new()
	add_child(_manager)
	_build_ui()
	_select_track(0)


func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = 2
	grow_vertical = 2

	# Background dark wash matching game style
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 0.98) # Dark Victorian Navy
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Mount ScreenShell
	_shell = ShellScene.instantiate()
	add_child(_shell)
	_shell.setup("jukebox")
	_shell.set_title_text("JUKEBOX & SOUND TEST")
	_shell.set_subtitle_text("Colonna sonora originale — 47 tracce (Standard, Epiche, Suite Sawano e Dragon Ball GT)")
	_shell.set_back_target("menu")

	var back_btn: Button = _shell.back_control()
	if back_btn != null:
		back_btn.pressed.connect(_on_back_pressed)

	var content: MarginContainer = _shell.content()
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_bottom", 16)

	var split_hbox := HBoxContainer.new()
	split_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 24)
	content.add_child(split_hbox)

	# -------------------------------------------------------------
	# LEFT COLUMN: Track List inside styled CardPanel
	# -------------------------------------------------------------
	var list_card := PanelContainer.new()
	list_card.custom_minimum_size = Vector2(420, 0)
	list_card.size_flags_vertical = SIZE_EXPAND_FILL
	list_card.theme_type_variation = &"CardPanel"
	split_hbox.add_child(list_card)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_card.add_child(list_margin)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_vbox)

	var list_header := Label.new()
	list_header.text = "CATALOGO TRACCE (%d)" % _track_ids.size()
	list_header.theme_type_variation = &"LabelSmall"
	list_header.add_theme_color_override("font_color", Color(0.96, 0.82, 0.44))
	list_vbox.add_child(list_header)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(list_scroll)

	_track_list_container = VBoxContainer.new()
	_track_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_track_list_container.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_track_list_container)

	_populate_track_list()

	# -------------------------------------------------------------
	# RIGHT COLUMN: Inspector Card & Audio Player Controls
	# -------------------------------------------------------------
	var inspector_card := PanelContainer.new()
	inspector_card.size_flags_horizontal = SIZE_EXPAND_FILL
	inspector_card.size_flags_vertical = SIZE_EXPAND_FILL
	inspector_card.theme_type_variation = &"CardPanel"
	split_hbox.add_child(inspector_card)

	var insp_margin := MarginContainer.new()
	insp_margin.add_theme_constant_override("margin_left", 20)
	insp_margin.add_theme_constant_override("margin_top", 16)
	insp_margin.add_theme_constant_override("margin_right", 20)
	insp_margin.add_theme_constant_override("margin_bottom", 16)
	inspector_card.add_child(insp_margin)

	var insp_vbox := VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 10)
	insp_margin.add_child(insp_vbox)

	# Track Title
	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeroTitle"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	insp_vbox.add_child(_title_label)

	# Destination Scene / Arena
	_scene_label = Label.new()
	_scene_label.add_theme_font_size_override("font_size", 14)
	_scene_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	insp_vbox.add_child(_scene_label)

	# Badges Row (Category, Tempo/Key, Audio Status)
	var badges_row := HBoxContainer.new()
	badges_row.add_theme_constant_override("separation", 12)
	insp_vbox.add_child(badges_row)

	_category_badge = Label.new()
	_category_badge.theme_type_variation = &"Badge"
	badges_row.add_child(_category_badge)

	_bpm_key_label = Label.new()
	_bpm_key_label.add_theme_font_size_override("font_size", 13)
	badges_row.add_child(_bpm_key_label)

	_status_badge = Label.new()
	_status_badge.add_theme_font_size_override("font_size", 13)
	badges_row.add_child(_status_badge)

	# Musical style description
	_style_label = Label.new()
	_style_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label.add_theme_font_size_override("font_size", 13)
	_style_label.add_theme_color_override("font_color", Color(0.78, 0.75, 0.72))
	insp_vbox.add_child(_style_label)

	insp_vbox.add_child(HSeparator.new())

	# Prompt Area Header & Copy Button
	var prompt_bar := HBoxContainer.new()
	insp_vbox.add_child(prompt_bar)

	var prompt_title := Label.new()
	prompt_title.text = "PROMPT GENERATIVO PER LYRIA / MUSICFX"
	prompt_title.size_flags_horizontal = SIZE_EXPAND_FILL
	prompt_title.theme_type_variation = &"LabelSmall"
	prompt_title.add_theme_color_override("font_color", Color(0.65, 0.82, 0.95))
	prompt_bar.add_child(prompt_title)

	_copy_btn = Button.new()
	_copy_btn.text = "📋 Copia Prompt"
	_copy_btn.theme_type_variation = &"SegmentedActive"
	_copy_btn.custom_minimum_size = Vector2(130, 30)
	_copy_btn.pressed.connect(_on_copy_prompt_pressed)
	prompt_bar.add_child(_copy_btn)

	_prompt_text = TextEdit.new()
	_prompt_text.editable = false
	_prompt_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_text.custom_minimum_size = Vector2(0, 95)
	_prompt_text.size_flags_vertical = SIZE_EXPAND_FILL
	insp_vbox.add_child(_prompt_text)

	insp_vbox.add_child(HSeparator.new())

	# Now Playing Status Line
	_now_playing_label = Label.new()
	_now_playing_label.text = "In Riproduzione: Nessuna traccia attiva"
	_now_playing_label.add_theme_font_size_override("font_size", 13)
	_now_playing_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	insp_vbox.add_child(_now_playing_label)

	# Audio Controls Toolbar
	var controls_bar := HBoxContainer.new()
	controls_bar.add_theme_constant_override("separation", 10)
	insp_vbox.add_child(controls_bar)

	_prev_btn = Button.new()
	_prev_btn.text = "⏮ Prec."
	_prev_btn.theme_type_variation = &"SegmentedInactive"
	_prev_btn.custom_minimum_size = Vector2(85, 38)
	_prev_btn.pressed.connect(_on_prev_pressed)
	controls_bar.add_child(_prev_btn)

	_play_btn = Button.new()
	_play_btn.text = "▶ Play / Preascolta"
	_play_btn.theme_type_variation = &"HeroButton"
	_play_btn.custom_minimum_size = Vector2(170, 38)
	_play_btn.pressed.connect(_on_play_pressed)
	controls_bar.add_child(_play_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "⏹ Stop"
	_stop_btn.theme_type_variation = &"SegmentedInactive"
	_stop_btn.custom_minimum_size = Vector2(85, 38)
	_stop_btn.pressed.connect(_on_stop_pressed)
	controls_bar.add_child(_stop_btn)

	_next_btn = Button.new()
	_next_btn.text = "Succ. ⏭"
	_next_btn.theme_type_variation = &"SegmentedInactive"
	_next_btn.custom_minimum_size = Vector2(85, 38)
	_next_btn.pressed.connect(_on_next_pressed)
	controls_bar.add_child(_next_btn)

	var vol_label := Label.new()
	vol_label.text = " Vol:"
	vol_label.add_theme_font_size_override("font_size", 12)
	controls_bar.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = -30.0
	_volume_slider.max_value = 6.0
	_volume_slider.value = 0.0
	_volume_slider.custom_minimum_size = Vector2(100, 20)
	_volume_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	controls_bar.add_child(_volume_slider)


func _populate_track_list() -> void:
	_track_buttons.clear()
	var current_cat := ""

	for i in _track_ids.size():
		var tid: String = _track_ids[i]
		var info := SoundtrackManager.track_info(tid)
		var cat: String = String(info.get("category", "Altro"))

		if cat != current_cat:
			current_cat = cat
			var cat_sep := Label.new()
			cat_sep.text = "— %s —" % cat.to_upper()
			cat_sep.theme_type_variation = &"LabelSmall"
			cat_sep.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			_track_list_container.add_child(cat_sep)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.theme_type_variation = &"SegmentedInactive"
		var has_file := SoundtrackManager.has_track(tid)
		var badge := "[✔ AUDIO]" if has_file else "[PROMPT]"
		var title: String = String(info.get("title", tid))
		var idx_str := "%02d" % (i + 1)
		btn.text = " %s. %s %s" % [idx_str, title, badge]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 12)

		var captured_idx := i
		btn.pressed.connect(func(): _select_track(captured_idx))
		_track_list_container.add_child(btn)
		_track_buttons.append(btn)


func _select_track(idx: int) -> void:
	if idx < 0 or idx >= _track_ids.size():
		return
	_selected_idx = idx

	for i in _track_buttons.size():
		_track_buttons[i].theme_type_variation = &"SegmentedActive" if (i == idx) else &"SegmentedInactive"

	var tid: String = _track_ids[idx]
	var info := SoundtrackManager.track_info(tid)
	var has_file := SoundtrackManager.has_track(tid)

	var cat_str: String = String(info.get("category", "General"))
	_category_badge.text = "[ %s ]" % cat_str.to_upper()
	if cat_str.begins_with("Sawano"):
		_category_badge.add_theme_color_override("font_color", Color(1.0, 0.28, 0.35))
	elif cat_str.begins_with("Dragon Ball"):
		_category_badge.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1)) # Iconic Dragon Ball Orange
	elif cat_str.begins_with("Epico"):
		_category_badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	else:
		_category_badge.add_theme_color_override("font_color", Color(0.3, 0.8, 0.95))
	_bpm_key_label.text = "Tempo: %d BPM  |  Chiave: %s" % [int(info.get("bpm", 120)), String(info.get("key", "D minor"))]

	if has_file:
		_status_badge.text = "✔ Audio: File presente su disco"
		_status_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		_status_badge.text = "⏳ Audio: In attesa di generazione Lyria"
		_status_badge.add_theme_color_override("font_color", Color(0.95, 0.72, 0.32))

	_style_label.text = "Stile & Strumentazione: %s" % String(info.get("style", ""))
	_prompt_text.text = String(info.get("prompt", ""))


func _on_play_pressed() -> void:
	var tid: String = _track_ids[_selected_idx]
	var info := SoundtrackManager.track_info(tid)
	var title: String = String(info.get("title", tid))

	if SoundtrackManager.has_track(tid):
		_manager.play_track(tid, 0.3)
		_now_playing_label.text = "In Riproduzione: %s" % title
		_now_playing_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		_now_playing_label.text = "Traccia '%s' in attesa: inserisci il file .ogg in res://assets/audio/music/" % title
		_now_playing_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25))


func _on_stop_pressed() -> void:
	if _manager != null:
		_manager.stop(0.2)
	_now_playing_label.text = "Riproduzione interrotta"
	_now_playing_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _on_prev_pressed() -> void:
	var new_idx := (_selected_idx - 1 + _track_ids.size()) % _track_ids.size()
	_select_track(new_idx)


func _on_next_pressed() -> void:
	var new_idx := (_selected_idx + 1) % _track_ids.size()
	_select_track(new_idx)


func _on_volume_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, val)


func _on_copy_prompt_pressed() -> void:
	var prompt := _prompt_text.text
	DisplayServer.clipboard_set(prompt)
	_copy_btn.text = "✔ Copiato!"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(_copy_btn):
			_copy_btn.text = "📋 Copia Prompt"
	)


func _on_back_pressed() -> void:
	_on_stop_pressed()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
