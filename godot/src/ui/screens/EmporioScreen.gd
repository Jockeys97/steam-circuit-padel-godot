## EmporioScreen.gd — OST and challenge-outfit storefront.
##
## WHAT IT IS. An overlay screen over the initial menu, built the same way the Jukebox
## is (`main_menu.gd::toggle_jukebox`): the menu mounts it, it sits in `ScreenShell`
## chrome, its Back control and Escape close it, and the menu's right-stick host treats
## it as the modal surface so the right stick scrolls the shelf.
##
## IT OWNS NO RULE. Every number and every decision comes from
## `godot/src/economy/economy_service.gd`: both shelves, prices, ownership, affordability,
## and the purchases. This screen renders answers and
## asks for a purchase; it never decides a price and never writes a save group itself.
##
## CONFIRM BEFORE DEBIT. Pressing a buyable row does not buy it: it opens a confirmation
## panel naming the track and its price, and only `Conferma` calls `purchase()`. Cancel
## and Escape back out with nothing written.
##
## LITERALS. The strings here are Italian/English pairs resolved by `_t()`, the same
## convention the Jukebox screen uses (the reference's locale table is generated and
## carries no shop keys; the OST lane carries its own text, as the Jukebox already does).
extends Control

## Emitted when the player leaves: the Back control, Escape, or `ui_cancel`. The host
## (`main_menu.gd`) frees the overlay.
signal closed
## The host pauses its continuous menu soundtrack only for the duration of a sample.
signal preview_state_changed(active: bool)

const Economy := preload("res://src/economy/economy_service.gd")
const Catalog := preload("res://src/economy/ost_catalog.gd")
const Soundtrack := preload("res://src/audio/soundtrack_manager.gd")
const Mixer := preload("res://src/audio/mixer_contract.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")
const Config := preload("res://game/match_config.gd")
const UiArt := preload("res://src/ui/data/UiArtPaths.gd")
const Locale := preload("res://src/locale/locale.gd")

const SCREEN_ID := "emporio"
const BACK_TARGET := "menu"

## Palette sampled from the theme's own navy/cyan (same source the Jukebox uses).
const NAVY_DEEP := Color(0.02352941, 0.07843137, 0.14901961)
const NAVY_ROW := Color(0.04313725, 0.14117648, 0.26666668)
const CYAN := Color(0.0, 0.89803922, 1.0)
const GOLD := Color(1.0, 0.88, 0.55)
const INK := Color(0.9647059, 0.96862745, 0.98431373)
const MUTED := Color(1.0, 1.0, 1.0, 0.48)
const LINE := Color(1.0, 1.0, 1.0, 0.12)
const COVERS_DIR := "res://assets/images/jukebox_covers/"
const FILTERS := ["all", "standard", "special"]
const PREVIEW_SECONDS := 15.0

var _store: RefCounted = null
var _lang: String = "it"
var _shell: Control = null
var _list_box: GridContainer = null
var _scroll: ScrollContainer = null
var _balance_label: Label = null
var _status_label: Label = null
var _preview_cover: TextureRect = null
var _preview_fallback: Label = null
var _preview_title: Label = null
var _preview_category: Label = null
var _preview_state: Label = null
var _preview_price: Label = null
var _cover_frame: PanelContainer = null
var _info_toggle_btn: Button = null
var _info_panel: PanelContainer = null
var _info_tempo: Label = null
var _info_style: Label = null
var _info_description: Label = null
var _purchase_btn: Button = null
var _listen_btn: Button = null
var _preview_player: AudioStreamPlayer = null
var _preview_timer: Timer = null
var _preview_track_id: String = ""
var _filter_buttons: Dictionary = {}
var _cover_cache: Dictionary = {}
var _selected_id: String = ""
var _active_filter: String = "all"
var _shop_kind: String = "ost"
var _section_buttons: Dictionary = {}
var _ost_filters: HBoxContainer = null
var _shelf_title: Label = null
var _featured_label: Label = null
var _confirm_layer: Control = null
var _confirm_panel: PanelContainer = null
var _confirm_label: Label = null
var _confirm_btn: Button = null
var _cancel_btn: Button = null
var _rows: Array = []
var _row_buttons: Array[Button] = []
var _pending_id: String = ""
var _last_purchase: Dictionary = {}
## Set once the player leaves, so a second cancel/back cannot emit `closed` twice.
var _closing: bool = false


func _ready() -> void:
	theme = DefaultTheme
	# The overlay OWNS input while it is up: `_input` consumes cancel so nothing leaks
	# past the modal, and the host withholds its own focus dispatch (see
	# `main_menu.gd::_overlay_owns_input`). Accept is deliberately NOT consumed here so
	# the GUI still delivers `ui_accept` to the focused row/confirm button.
	set_process_input(true)
	set_process_unhandled_input(true)
	if _store == null:
		_store = Config.save_store()
	Mixer.new().ensure_bus(Mixer.MUSIC_BUS)
	_preview_player = AudioStreamPlayer.new()
	_preview_player.name = "EmporioAudioSample"
	_preview_player.bus = Mixer.MUSIC_BUS
	_preview_player.finished.connect(_stop_preview)
	add_child(_preview_player)
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.timeout.connect(_stop_preview)
	add_child(_preview_timer)
	_lang = _read_lang()
	_build_ui()
	refresh()
	_focus_first_row()


## The store a test hands in (an isolated directory). Never the real profile unless the
## caller leaves it unset, in which case the config's own store is used.
func set_store(store: RefCounted) -> void:
	_store = store
	if _shell != null:
		_lang = _read_lang()
		refresh()


func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


## The rows last rendered, so a test reads the same data the screen shows.
func rows() -> Array:
	return _rows.duplicate(true)


func balance_text() -> String:
	return _balance_label.text if _balance_label != null else ""


func status_text() -> String:
	return _status_label.text if _status_label != null else ""


func confirm_visible() -> bool:
	return _confirm_layer != null and _confirm_layer.visible


func pending_id() -> String:
	return _pending_id


## The last purchase result (`{}` before any), for a test that drove the confirm path.
func last_purchase() -> Dictionary:
	return _last_purchase.duplicate(true)


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = NAVY_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_shell = ShellScene.instantiate()
	add_child(_shell)
	_shell.setup(SCREEN_ID)
	_shell.set_title_text(_t("EMPORIO", "EMPORIUM"))
	_shell.set_subtitle_text(_t(
		"OST e outfit: guadagna Crediti Circuito giocando; alcuni outfit si vincono anche con le sfide",
		"OST and outfits: earn Circuit Credits by playing; some outfits can also be won through challenges"))
	_shell.set_back_target(BACK_TARGET)
	var back_btn: Button = _shell.back_control()
	if back_btn != null:
		back_btn.pressed.connect(_on_back_pressed)

	var content: MarginContainer = _shell.content()
	content.add_theme_constant_override("margin_left", 22)
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_right", 22)
	content.add_theme_constant_override("margin_bottom", 16)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = SIZE_EXPAND_FILL
	column.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	content.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var eyebrow := _label(_t("IL MERCATO DEL CIRCUITO", "THE CIRCUIT MARKET"), 14, CYAN)
	eyebrow.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(eyebrow)
	_balance_label = Label.new()
	_balance_label.add_theme_font_size_override("font_size", 20)
	_balance_label.add_theme_color_override("font_color", GOLD)
	header.add_child(_balance_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var shelf := PanelContainer.new()
	shelf.name = "EmporioShelf"
	shelf.size_flags_horizontal = SIZE_EXPAND_FILL
	shelf.size_flags_stretch_ratio = 1.6
	shelf.add_theme_stylebox_override("panel", _panel_style(NAVY_ROW, Color(CYAN, 0.26), 16, 1))
	body.add_child(shelf)
	var shelf_column := VBoxContainer.new()
	shelf_column.add_theme_constant_override("separation", 10)
	shelf.add_child(shelf_column)
	_shelf_title = _label(_t("COLLEZIONE OST", "OST COLLECTION"), 18, INK)
	shelf_column.add_child(_shelf_title)
	var sections := HBoxContainer.new()
	sections.add_theme_constant_override("separation", 8)
	shelf_column.add_child(sections)
	for kind in ["ost", "outfit"]:
		var section := Button.new()
		section.name = "EmporioSection_%s" % kind
		section.text = _t("OST", "OST") if kind == "ost" else _t("OUTFIT", "OUTFITS")
		section.focus_mode = Control.FOCUS_ALL
		section.size_flags_horizontal = SIZE_EXPAND_FILL
		section.custom_minimum_size.y = 36
		section.theme_type_variation = &"SegmentedActive" if kind == "ost" else &"SegmentedInactive"
		section.pressed.connect(_set_shop_kind.bind(kind))
		sections.add_child(section)
		_section_buttons[kind] = section
	_ost_filters = HBoxContainer.new()
	_ost_filters.add_theme_constant_override("separation", 8)
	shelf_column.add_child(_ost_filters)
	for key in FILTERS:
		var filter_btn := Button.new()
		filter_btn.name = "EmporioFilter_%s" % key
		filter_btn.text = _filter_text(key)
		filter_btn.focus_mode = Control.FOCUS_ALL
		filter_btn.size_flags_horizontal = SIZE_EXPAND_FILL
		filter_btn.custom_minimum_size.y = 38
		filter_btn.pressed.connect(_set_filter.bind(key))
		_ost_filters.add_child(filter_btn)
		_filter_buttons[key] = filter_btn
	_update_filter_style()

	# Keep the host's right-stick scrolling and follow focused cards from the D-pad.
	_scroll = ScrollContainer.new()
	_scroll.name = "EmporioScroll"
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	shelf_column.add_child(_scroll)

	_list_box = GridContainer.new()
	_list_box.columns = 2
	_list_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("h_separation", 9)
	_list_box.add_theme_constant_override("v_separation", 9)
	_scroll.add_child(_list_box)

	var detail := PanelContainer.new()
	detail.name = "EmporioDetail"
	detail.custom_minimum_size.x = 350
	detail.size_flags_horizontal = SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 1.0
	detail.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.12, 0.22), Color(GOLD, 0.40), 16, 1))
	body.add_child(detail)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 9)
	detail.add_child(detail_column)
	var info_header := HBoxContainer.new()
	info_header.add_theme_constant_override("separation", 8)
	detail_column.add_child(info_header)
	_featured_label = _label(_t("IN EVIDENZA  /  OST", "FEATURED  /  OST"), 13, GOLD)
	_featured_label.size_flags_horizontal = SIZE_EXPAND_FILL
	info_header.add_child(_featured_label)
	_info_toggle_btn = Button.new()
	_info_toggle_btn.name = "EmporioInfoButton"
	_info_toggle_btn.focus_mode = Control.FOCUS_ALL
	_info_toggle_btn.theme_type_variation = &"ButtonSecondary"
	_info_toggle_btn.custom_minimum_size = Vector2(92, 32)
	_info_toggle_btn.pressed.connect(_on_info_pressed)
	info_header.add_child(_info_toggle_btn)
	_cover_frame = PanelContainer.new()
	_cover_frame.size_flags_vertical = SIZE_EXPAND_FILL
	_cover_frame.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.06, 0.12), Color(CYAN, 0.26), 10, 1))
	detail_column.add_child(_cover_frame)
	var cover_center := CenterContainer.new()
	_cover_frame.add_child(cover_center)
	_preview_cover = TextureRect.new()
	_preview_cover.name = "EmporioPreviewCover"
	_preview_cover.custom_minimum_size = Vector2(220, 220)
	_preview_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_center.add_child(_preview_cover)
	_preview_fallback = _label("SC / OST", 28, CYAN)
	_preview_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_center.add_child(_preview_fallback)
	_info_panel = PanelContainer.new()
	_info_panel.name = "EmporioTrackInfo"
	_info_panel.visible = false
	_info_panel.size_flags_vertical = SIZE_EXPAND_FILL
	_info_panel.add_theme_stylebox_override("panel", _panel_style(NAVY_DEEP, Color(CYAN, 0.32), 10, 1))
	detail_column.add_child(_info_panel)
	var info_scroll := ScrollContainer.new()
	info_scroll.custom_minimum_size.y = 220
	info_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_panel.add_child(info_scroll)
	var info_content := VBoxContainer.new()
	info_content.size_flags_horizontal = SIZE_EXPAND_FILL
	info_content.add_theme_constant_override("separation", 12)
	info_scroll.add_child(info_content)
	info_content.add_child(_label(_t("DETTAGLI DEL BRANO", "TRACK DETAILS"), 14, CYAN))
	_info_tempo = _label("", 13, INK)
	_info_tempo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_content.add_child(_info_tempo)
	_info_style = _label("", 13, INK)
	_info_style.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_content.add_child(_info_style)
	info_content.add_child(_label(_t("DESCRIZIONE", "DESCRIPTION"), 13, GOLD))
	_info_description = _label("", 13, INK)
	_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_content.add_child(_info_description)
	_update_info_toggle_text()
	_preview_category = _label("", 13, CYAN)
	detail_column.add_child(_preview_category)
	_preview_title = _label("", 24, INK)
	_preview_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(_preview_title)
	_preview_state = _label("", 14, MUTED)
	_preview_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(_preview_state)
	_preview_price = _label("", 22, GOLD)
	detail_column.add_child(_preview_price)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	detail_column.add_child(actions)
	_listen_btn = Button.new()
	_listen_btn.name = "EmporioListenPreview"
	_listen_btn.focus_mode = Control.FOCUS_ALL
	_listen_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_listen_btn.custom_minimum_size.y = 48
	_listen_btn.theme_type_variation = &"ButtonSecondary"
	_listen_btn.tooltip_text = _t("Ascolta al massimo 15 secondi, senza acquistare", "Listen for up to 15 seconds without buying")
	_listen_btn.pressed.connect(_on_preview_pressed)
	actions.add_child(_listen_btn)
	_purchase_btn = Button.new()
	_purchase_btn.name = "EmporioPurchaseButton"
	_purchase_btn.focus_mode = Control.FOCUS_ALL
	_purchase_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	_purchase_btn.custom_minimum_size.y = 48
	_purchase_btn.theme_type_variation = &"ButtonPrimary"
	_purchase_btn.pressed.connect(func(): _on_row_pressed(_selected_id))
	actions.add_child(_purchase_btn)

	_status_label = _label("", 13, MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)
	column.add_child(_label(_t("PAD  ◀ ▶ cambia card   ·   A seleziona   ·   B indietro", "PAD  ◀ ▶ browse   ·   A select   ·   B back"), 12, MUTED))

	_build_confirm_panel()


func _build_confirm_panel() -> void:
	_confirm_layer = ColorRect.new()
	_confirm_layer.name = "EmporioConfirmLayer"
	_confirm_layer.color = Color(0.0, 0.0, 0.0, 0.7)
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.visible = false
	add_child(_confirm_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	_confirm_panel = PanelContainer.new()
	_confirm_panel.name = "EmporioConfirm"
	_confirm_panel.custom_minimum_size = Vector2(420, 0)
	_confirm_panel.add_theme_stylebox_override("panel", _panel_style(NAVY_ROW, CYAN, 12, 2))
	center.add_child(_confirm_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_confirm_panel.add_child(box)

	_confirm_label = Label.new()
	_confirm_label.add_theme_font_size_override("font_size", 15)
	_confirm_label.add_theme_color_override("font_color", INK)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	_confirm_btn = Button.new()
	_confirm_btn.name = "EmporioConfirmBuy"
	_confirm_btn.text = _t("Conferma", "Confirm")
	_confirm_btn.focus_mode = Control.FOCUS_ALL
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_btn)

	_cancel_btn = Button.new()
	_cancel_btn.name = "EmporioConfirmCancel"
	_cancel_btn.text = _t("Annulla", "Cancel")
	_cancel_btn.focus_mode = Control.FOCUS_ALL
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	buttons.add_child(_cancel_btn)


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func refresh() -> void:
	_rows = []
	var source: Array = Economy.outfit_shop_rows(store()) if _shop_kind == "outfit" else Economy.shop_rows(store())
	for entry in source:
		var row: Dictionary = (entry as Dictionary).duplicate(true)
		row["kind"] = _shop_kind
		if _shop_kind == "outfit":
			row["title"] = Locale.t(String(row["name_key"]), {}, _lang)
			row["category"] = Locale.t("athlete_%s_name" % String(row["athlete_id"]), {}, _lang)
		_rows.append(row)
	var previous := _selected_id
	for child in _list_box.get_children():
		child.queue_free()
	_row_buttons.clear()
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if _matches_filter(row):
			var card := _make_card(row, i)
			_list_box.add_child(card)
			_row_buttons.append(card)
	_link_focus()
	_balance_label.text = _t("Crediti Circuito: %d", "Circuit Credits: %d") % Economy.balance(store())
	_selected_id = previous if _find_row(previous).size() > 0 and _matches_filter(_find_row(previous)) else ""
	if _selected_id == "" and not _row_buttons.is_empty():
		_selected_id = String(_row_buttons[0].get_meta("track_id"))
	if _preview_track_id != "" and _preview_track_id != _selected_id:
		_stop_preview()
	_sync_preview()
	if _status_label.text == "":
		_status_label.text = _t(
			"Esplora le OST. I brani acquistati sono disponibili nel Jukebox.",
			"Explore the OSTs. Purchased tracks are available in the Jukebox.")


func selected_id() -> String:
	return _selected_id


func shop_kind() -> String:
	return _shop_kind


func _set_shop_kind(kind: String) -> void:
	if (kind != "ost" and kind != "outfit") or confirm_visible():
		return
	_stop_preview()
	_shop_kind = kind
	_selected_id = ""
	_ost_filters.visible = kind == "ost"
	_listen_btn.visible = kind == "ost"
	_info_panel.visible = false
	_cover_frame.visible = true
	_shelf_title.text = _t("COLLEZIONE OST", "OST COLLECTION") if kind == "ost" else _t("OUTFIT SBLOCCABILI", "UNLOCKABLE OUTFITS")
	_featured_label.text = _t("IN EVIDENZA  /  OST", "FEATURED  /  OST") if kind == "ost" else _t("IN EVIDENZA  /  OUTFIT", "FEATURED  /  OUTFIT")
	for section_kind in _section_buttons:
		(_section_buttons[section_kind] as Button).theme_type_variation = &"SegmentedActive" if section_kind == kind else &"SegmentedInactive"
	_update_info_toggle_text()
	refresh()
	_focus_first_row()


func _filter_text(key: String) -> String:
	match key:
		"standard": return _t("Circuito", "Circuit")
		"special": return _t("Speciali", "Special")
		_: return _t("Tutte", "All")


func _set_filter(key: String) -> void:
	if not FILTERS.has(key) or confirm_visible():
		return
	_active_filter = key
	_update_filter_style()
	refresh()
	_focus_first_row()


func _update_filter_style() -> void:
	for key in _filter_buttons:
		var btn: Button = _filter_buttons[key]
		btn.theme_type_variation = &"SegmentedActive" if key == _active_filter else &"SegmentedInactive"


func _matches_filter(row: Dictionary) -> bool:
	if _shop_kind == "outfit":
		return true
	if _active_filter == "all":
		return true
	var special := Catalog.SPECIAL_CATEGORIES.has(String(row.get("category", "")))
	return special if _active_filter == "special" else not special


func _make_card(row: Dictionary, index: int) -> Button:
	var track_id := String(row["id"])
	var card := Button.new()
	card.name = "EmporioRow%d" % index
	card.set_meta("track_id", track_id)
	card.focus_mode = Control.FOCUS_ALL
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 112)
	card.add_theme_stylebox_override("normal", _panel_style(Color(0.055, 0.13, 0.24), LINE, 10, 1))
	card.add_theme_stylebox_override("hover", _panel_style(Color(0.08, 0.20, 0.33), Color(CYAN, 0.55), 10, 1))
	card.add_theme_stylebox_override("focus", _panel_style(Color(0.06, 0.14, 0.24, 0.0), CYAN, 10, 2))
	# Hover and controller focus are navigation only. Click / pad confirm selects the
	# card; purchase remains an explicit action in the detail pane.
	card.pressed.connect(_select_track.bind(track_id))
	var inset := MarginContainer.new()
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset.add_theme_constant_override("margin_left", 8)
	inset.add_theme_constant_override("margin_top", 8)
	inset.add_theme_constant_override("margin_right", 8)
	inset.add_theme_constant_override("margin_bottom", 8)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inset)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 9)
	inset.add_child(line)
	var cover := TextureRect.new()
	cover.custom_minimum_size = Vector2(80, 80)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture = _load_cover_for_outfit(row) if _shop_kind == "outfit" else _load_cover_for_track(track_id)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(cover)
	if cover.texture == null:
		cover.visible = false
		var fallback := _label("♪", 35, CYAN)
		fallback.custom_minimum_size = Vector2(80, 80)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(fallback)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(copy)
	var title := _label(String(row["title"]), 14, INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_vertical = SIZE_EXPAND_FILL
	copy.add_child(title)
	copy.add_child(_label(_short_state(row), 12, GOLD if bool(row.get("affordable", false)) else MUTED))
	return card


func _link_focus() -> void:
	var back_btn: Button = _shell.back_control()
	for kind in _section_buttons:
		var section: Button = _section_buttons[kind]
		section.focus_neighbor_top = section.get_path_to(back_btn)
		if not _row_buttons.is_empty():
			var below: Control = _filter_buttons[_active_filter] if _shop_kind == "ost" else _row_buttons[0]
			section.focus_neighbor_bottom = section.get_path_to(below)
	for key in FILTERS:
		var filter_btn: Button = _filter_buttons[key]
		filter_btn.focus_neighbor_top = filter_btn.get_path_to(_section_buttons["ost"])
		if not _row_buttons.is_empty():
			filter_btn.focus_neighbor_bottom = filter_btn.get_path_to(_row_buttons[0])
	for i in _row_buttons.size():
		var card := _row_buttons[i]
		var action: Control = _purchase_btn if _shop_kind == "outfit" else _listen_btn
		var top: Control = _row_buttons[i - 2] if i >= 2 else (_section_buttons["outfit"] if _shop_kind == "outfit" else _filter_buttons[_active_filter])
		var bottom: Control = _row_buttons[i + 2] if i + 2 < _row_buttons.size() else action
		var left: Control = _row_buttons[i - 1] if i % 2 == 1 else card
		var right: Control = _row_buttons[i + 1] if i % 2 == 0 and i + 1 < _row_buttons.size() else action
		card.focus_neighbor_top = card.get_path_to(top)
		card.focus_neighbor_bottom = card.get_path_to(bottom)
		card.focus_neighbor_left = card.get_path_to(left)
		card.focus_neighbor_right = card.get_path_to(right)
	if not _row_buttons.is_empty():
		_purchase_btn.focus_neighbor_left = _purchase_btn.get_path_to(_row_buttons[0])
		_purchase_btn.focus_neighbor_top = _purchase_btn.get_path_to(_row_buttons[0])
		_listen_btn.focus_neighbor_left = _listen_btn.get_path_to(_row_buttons[0])
		_listen_btn.focus_neighbor_top = _listen_btn.get_path_to(_info_toggle_btn)
		_listen_btn.focus_neighbor_right = _listen_btn.get_path_to(_purchase_btn)
		_purchase_btn.focus_neighbor_left = _purchase_btn.get_path_to(_row_buttons[0] if _shop_kind == "outfit" else _listen_btn)
		_info_toggle_btn.focus_neighbor_left = _info_toggle_btn.get_path_to(_row_buttons[0])
		_info_toggle_btn.focus_neighbor_bottom = _info_toggle_btn.get_path_to(_purchase_btn if _shop_kind == "outfit" else _listen_btn)


func _select_track(track_id: String) -> void:
	if confirm_visible() or _find_row(track_id).is_empty():
		return
	if _preview_track_id != "" and _preview_track_id != track_id:
		_stop_preview()
	_selected_id = track_id
	_sync_preview()


func _on_info_pressed() -> void:
	if confirm_visible():
		return
	_info_panel.visible = not _info_panel.visible
	_cover_frame.visible = not _info_panel.visible
	_update_info_toggle_text()


func _update_info_toggle_text() -> void:
	if _shop_kind == "outfit":
		var shop_only := bool(_find_row(_selected_id).get("shop_only", false))
		_info_toggle_btn.text = _t("ⓘ CHIUDI", "ⓘ CLOSE") if _info_panel.visible else (_t("ⓘ INFO", "ⓘ INFO") if shop_only else _t("ⓘ SFIDA", "ⓘ CHALLENGE"))
		_info_toggle_btn.tooltip_text = _t("Mostra/nascondi i dettagli", "Show/hide details") if shop_only else _t("Mostra/nascondi la sfida gratuita", "Show/hide the free challenge")
		return
	_info_toggle_btn.text = _t("ⓘ CHIUDI", "ⓘ CLOSE") if _info_panel.visible else _t("ⓘ INFO", "ⓘ INFO")
	_info_toggle_btn.tooltip_text = _t("Nascondi dettagli del brano", "Hide track details") if _info_panel.visible else _t("Mostra dettagli del brano", "Show track details")


func _sync_preview() -> void:
	var row := _find_row(_selected_id)
	if row.is_empty():
		_preview_title.text = _t("Nessuna traccia", "No track")
		_listen_btn.disabled = true
		_purchase_btn.disabled = true
		return
	if _shop_kind == "outfit":
		_sync_outfit_preview(row)
		return
	_preview_cover.texture = _load_cover_for_track(_selected_id)
	_preview_cover.visible = _preview_cover.texture != null
	_preview_fallback.visible = not _preview_cover.visible
	_preview_fallback.text = "SC / OST"
	_preview_title.text = String(row["title"])
	_preview_category.text = String(row["category"]).to_upper()
	_preview_state.text = _short_state(row).to_upper()
	_preview_price.text = "%d CC" % int(row["price"])
	var info: Dictionary = Soundtrack.track_info(_selected_id)
	_info_tempo.text = _t("Tempo: %s BPM  |  Tonalità: %s", "Tempo: %s BPM  |  Key: %s") % [str(info.get("bpm", "—")), String(info.get("key", "—"))]
	_info_style.text = _t("Stile e strumentazione: %s", "Style and instrumentation: %s") % String(info.get("style", "—"))
	_info_description.text = String(info.get("prompt", "—"))
	_listen_btn.disabled = not Soundtrack.has_track(_selected_id)
	_listen_btn.text = _t("■ FERMA", "■ STOP") if _preview_track_id == _selected_id else _t("▶ ASCOLTA 15s", "▶ LISTEN 15s")
	_purchase_btn.disabled = not bool(row.get("affordable", false)) or bool(row.get("owned", false)) or bool(row.get("accessible", false)) or bool(row.get("relocked", false))
	_purchase_btn.text = _t("ACQUISTA  ›", "BUY  ›") if not _purchase_btn.disabled else _short_state(row).to_upper()


func _sync_outfit_preview(row: Dictionary) -> void:
	_preview_cover.texture = _load_cover_for_outfit(row)
	_preview_cover.visible = _preview_cover.texture != null
	_preview_fallback.visible = not _preview_cover.visible
	_preview_fallback.text = "SC / OUTFIT"
	_preview_title.text = String(row["title"])
	_preview_category.text = String(row["category"]).to_upper()
	if bool(row.get("shop_only", false)):
		_preview_state.text = _short_state(row).to_upper()
		_preview_price.text = "%d CC" % int(row["price"])
		_info_tempo.text = _t("ESCLUSIVO EMPORIO", "EMPORIO EXCLUSIVE")
		_info_style.text = _t("Completo cosmetico 3D", "3D cosmetic outfit")
		_info_description.text = _t("Sbloccalo con i Crediti Circuito, poi equipaggialo nel guardaroba. Il codice Lucale lo rende disponibile senza acquisto.", "Unlock it with Circuit Credits, then equip it in the wardrobe. The Lucale code grants access without a purchase.")
	else:
		_preview_state.text = _t("Sfida: ", "Challenge: ") + _challenge_text(row["challenge"])
		_preview_price.text = _t("Alternativa: %d CC", "Alternative: %d CC") % int(row["price"])
		_info_tempo.text = _t("VIA PRINCIPALE: SFIDA", "MAIN ROUTE: CHALLENGE")
		_info_style.text = _challenge_text(row["challenge"])
		_info_description.text = _t("Completa la sfida gratuitamente, oppure acquista l'outfit con Crediti Circuito.", "Complete the challenge for free, or buy the outfit with Circuit Credits.")
	_update_info_toggle_text()
	_listen_btn.disabled = true
	_purchase_btn.disabled = bool(row.get("unavailable", false)) or not bool(row.get("supported", false)) or not bool(row.get("affordable", false)) or bool(row.get("owned", false)) or bool(row.get("accessible", false)) or bool(row.get("relocked", false))
	_purchase_btn.text = _t("ACQUISTA OUTFIT  ›", "BUY OUTFIT  ›") if not _purchase_btn.disabled else _short_state(row).to_upper()


func _challenge_text(challenge: Dictionary) -> String:
	var parts: Array[String] = []
	if bool(challenge.get("win", false)):
		parts.append(_t("Vinci", "Win"))
	if challenge.has("minSkill"):
		parts.append(_t("IA almeno %.2f", "AI at least %.2f") % float(challenge["minSkill"]))
	parts.append(_challenge_metric(challenge))
	if challenge.get("also") is Dictionary:
		parts.append(_challenge_metric(challenge["also"]))
	return " · ".join(parts)


func _challenge_metric(challenge: Dictionary) -> String:
	var metric := String(challenge.get("metric", ""))
	var label := metric
	match metric:
		"winners": label = _t("vincenti", "winners")
		"errors": label = _t("errori", "errors")
		"doubleFaults": label = _t("doppi falli", "double faults")
		"wins": label = _t("vittorie", "wins")
		"smashWinners": label = _t("smash vincenti", "smash winners")
		"longestRally": label = _t("scambi consecutivi", "rally length")
	var comparator := "≤" if bool(challenge.get("atMost", false)) else "≥"
	return "%s %s %d" % [label, comparator, int(challenge.get("target", 0))]


## The sample never changes ownership or the runtime playlist. Its own non-looping
## player stops at 15 seconds even when the source stream is much longer.
func preview_playing() -> bool:
	return _preview_track_id != ""


func _on_preview_pressed() -> void:
	if confirm_visible() or _selected_id == "":
		return
	if _preview_track_id == _selected_id:
		_stop_preview()
		return
	_stop_preview()
	var stream: AudioStream = Soundtrack.load_stream(_selected_id)
	if stream == null:
		_status_label.text = _t("Anteprima non disponibile per questa OST.", "Preview unavailable for this OST.")
		_sync_preview()
		return
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_preview_track_id = _selected_id
	preview_state_changed.emit(true)
	_preview_player.stream = stream
	_preview_player.play()
	if not _preview_player.playing:
		_stop_preview()
		_status_label.text = _t("Impossibile avviare l'anteprima.", "Could not start preview.")
		return
	_preview_timer.start(PREVIEW_SECONDS)
	_sync_preview()


func _stop_preview() -> void:
	if _preview_timer != null:
		_preview_timer.stop()
	if _preview_player != null:
		_preview_player.stop()
		_preview_player.stream = null
	if _preview_track_id == "":
		return
	_preview_track_id = ""
	preview_state_changed.emit(false)
	if _preview_title != null:
		_sync_preview()


func _find_row(track_id: String) -> Dictionary:
	for row in _rows:
		if String(row["id"]) == track_id:
			return row
	return {}


func _short_state(row: Dictionary) -> String:
	if String(row.get("kind", "")) == "outfit":
		if bool(row.get("unavailable", false)):
			return _t("Profilo non disponibile", "Profile unavailable")
		if not bool(row.get("supported", false)):
			return _t("Non disponibile in 3D", "Not available in 3D")
		if bool(row.get("relocked", false)):
			return _t("Bloccato", "Locked")
		if bool(row.get("won", false)):
			return _t("Vinto con sfida", "Won through challenge")
		if bool(row.get("owned", false)):
			return _t("Acquistato", "Purchased")
		if bool(row.get("accessible", false)):
			return _t("Sbloccato", "Unlocked")
		if bool(row.get("affordable", false)):
			if bool(row.get("shop_only", false)):
				return "%d CC" % int(row["price"])
			return _t("Sfida o %d CC", "Challenge or %d CC") % int(row["price"])
		if bool(row.get("shop_only", false)):
			return _t("Crediti insufficienti", "Not enough credits")
		return _t("Sfida · crediti insufficienti", "Challenge · not enough credits")
	if bool(row.get("relocked", false)):
		return _t("Bloccata", "Locked")
	if bool(row.get("owned", false)):
		return _t("Acquistata", "Owned")
	if bool(row.get("accessible", false)):
		return _t("Sbloccata", "Unlocked")
	if bool(row.get("affordable", false)):
		return "%d CC" % int(row["price"])
	return _t("Crediti insufficienti", "Not enough credits")


func _load_cover_for_track(track_id: String) -> Texture2D:
	if _cover_cache.has(track_id):
		return _cover_cache[track_id]
	var texture: Texture2D = null
	for extension in ["png", "jpg"]:
		var path := "%s%s.%s" % [COVERS_DIR, track_id, extension]
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource is Texture2D:
				texture = resource
				break
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			var img := Image.load_from_file(absolute)
			if img != null and not img.is_empty():
				texture = ImageTexture.create_from_image(img)
				break
	_cover_cache[track_id] = texture
	return texture


func _load_cover_for_outfit(row: Dictionary) -> Texture2D:
	var key := "outfit:" + String(row["id"])
	if _cover_cache.has(key):
		return _cover_cache[key]
	var path := UiArt.outfit_path_for(String(row["athlete_id"]), String(row["outfit_id"]))
	var texture: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	_cover_cache[key] = texture
	return texture


func _label(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

## The explicit purchase button for the selected row. Card activation only selects;
## this action opens confirmation and never debits on its own.
func _on_row_pressed(track_id: String) -> void:
	_select_track(track_id)
	for row in _rows:
		if String(row["id"]) != track_id:
			continue
		if _shop_kind == "outfit" and bool(row.get("unavailable", false)):
			_status_label.text = _t("Profilo non disponibile: nessun addebito.", "Profile unavailable: nothing debited.")
			return
		if _shop_kind == "outfit" and not bool(row.get("supported", false)):
			_status_label.text = _t("Questo outfit non ha ancora una variante 3D utilizzabile.", "This outfit has no usable 3D variant yet.")
			return
		if bool(row.get("relocked", false)):
			_status_label.text = _t("Blocco Alelu attivo: usa Lucale per sbloccare.", "Alelu lock active: use Lucale to unlock.")
			return
		if bool(row.get("owned", false)):
			_status_label.text = _t("Già acquistato.", "Already owned.") if _shop_kind == "outfit" else _t("Già acquistata.", "Already owned.")
			return
		if bool(row.get("accessible", false)):
			_status_label.text = _t("Già sbloccato tramite sfida o codice.", "Already unlocked by challenge or code.") if _shop_kind == "outfit" else _t("Sbloccata: disponibile nel Jukebox.", "Unlocked: available in the Jukebox.")
			return
		if not bool(row.get("affordable", false)):
			_status_label.text = _t("Crediti insufficienti.", "Not enough credits.")
			return
		_open_confirm(row)
		return


func _open_confirm(row: Dictionary) -> void:
	_stop_preview()
	_pending_id = String(row["id"])
	if _shop_kind == "outfit":
		if bool(row.get("shop_only", false)):
			_confirm_label.text = _t(
				"Sbloccare l'outfit «%s» per %d crediti? Saldo: %d.",
				"Unlock the outfit \"%s\" for %d credits? Balance: %d."
			) % [String(row["title"]), int(row["price"]), Economy.balance(store())]
		else:
			_confirm_label.text = _t(
				"Acquistare l'outfit «%s» per %d crediti? La sfida resta disponibile. Saldo: %d.",
				"Buy the outfit \"%s\" for %d credits? The challenge remains available. Balance: %d."
			) % [String(row["title"]), int(row["price"]), Economy.balance(store())]
	else:
		_confirm_label.text = _t(
			"Acquistare «%s» per %d crediti? Saldo attuale: %d.",
			"Buy \"%s\" for %d credits? Current balance: %d."
		) % [String(row["title"]), int(row["price"]), Economy.balance(store())]
	_confirm_layer.visible = true
	_set_background_focus(false)
	_confirm_btn.grab_focus()


func _on_confirm_pressed() -> void:
	if _pending_id == "":
		return
	var result: Dictionary = Economy.purchase_outfit(store(), _pending_id) if _shop_kind == "outfit" else Economy.purchase(store(), _pending_id)
	_last_purchase = result
	_confirm_layer.visible = false
	_set_background_focus(true)
	_pending_id = ""
	_status_label.text = _purchase_status(result)
	refresh()
	_focus_first_row()


func _on_cancel_pressed() -> void:
	_confirm_layer.visible = false
	_set_background_focus(true)
	_pending_id = ""
	_status_label.text = _t("Acquisto annullato.", "Purchase cancelled.")
	_focus_first_row()


func _purchase_status(result: Dictionary) -> String:
	match String(result.get("reason", "")):
		"purchased":
			if _shop_kind == "outfit":
				return _t("Outfit sbloccato! Equipaggialo nel guardaroba. Saldo: %d.", "Outfit unlocked! Equip it in the wardrobe. Balance: %d.") % int(result.get("balance", 0))
			return _t("Acquisto completato. Saldo: %d.", "Purchase complete. Balance: %d.") % int(result.get("balance", 0))
		"insufficient":
			return _t("Crediti insufficienti.", "Not enough credits.")
		"owned":
			if _shop_kind == "outfit":
				return _t("Outfit già acquistato.", "Outfit already purchased.")
			return _t("Già acquistata.", "Already owned.")
		"unlocked":
			if _shop_kind == "outfit":
				return _t("Outfit già sbloccato: nessun addebito.", "Outfit already unlocked: nothing debited.")
			return _t("Già sbloccata: nessun addebito.", "Already unlocked: nothing debited.")
		"write_failed":
			return _t("Acquisto non salvato: nessun addebito.", "Purchase not saved: nothing debited.")
		"refused":
			return _t("Profilo rifiutato: nessun addebito.", "Profile refused: nothing debited.")
		_:
			return _t("Acquisto non disponibile.", "Purchase unavailable.")


func _focus_first_row() -> void:
	for b in _row_buttons:
		if is_instance_valid(b) and String(b.get_meta("track_id")) == _selected_id:
			b.grab_focus()
			return
	for b in _row_buttons:
		if is_instance_valid(b):
			b.grab_focus()
			return
	var back_btn: Button = _shell.back_control()
	if back_btn != null:
		back_btn.grab_focus()


func _set_background_focus(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for b in _row_buttons:
		if is_instance_valid(b):
			b.focus_mode = mode
	for key in _filter_buttons:
		(_filter_buttons[key] as Button).focus_mode = mode
	for key in _section_buttons:
		(_section_buttons[key] as Button).focus_mode = mode
	_purchase_btn.focus_mode = mode
	_listen_btn.focus_mode = mode
	_info_toggle_btn.focus_mode = mode
	var back_btn: Button = _shell.back_control()
	if back_btn != null:
		back_btn.focus_mode = mode


func _on_back_pressed() -> void:
	if _closing:
		return
	_closing = true
	_stop_preview()
	closed.emit()


func _exit_tree() -> void:
	_stop_preview()


## The overlay's own input owner. Cancel/Escape closes the confirmation if one is open
## and the screen otherwise, and the event is marked handled so it cannot also reach the
## menu behind the modal. `ui_accept` and pad navigation are left alone on purpose: the
## GUI delivers them to the focused control, which is how a pad buys a track.
func _input(event: InputEvent) -> void:
	if _closing:
		return
	var cancel := event.is_action_pressed("ui_cancel") \
		or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE)
	if not cancel:
		return
	if confirm_visible():
		_on_cancel_pressed()
	else:
		_on_back_pressed()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# The same rule as `_input`, kept as the fallback path when something earlier in the
	# GUI chain consumed `ui_cancel` without acting on it.
	_input(event)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _read_lang() -> String:
	var read: Dictionary = store().read_group("prefs")
	var payload: Variant = read.get("payload", null)
	if payload is Dictionary:
		var lang := String((payload as Dictionary).get("lang", ""))
		if lang == "en" or lang == "it":
			return lang
	return "it"


func _t(it: String, en: String) -> String:
	return it if _lang == "it" else en


func _panel_style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
