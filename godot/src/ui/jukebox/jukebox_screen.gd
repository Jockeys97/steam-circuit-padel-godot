extends Control
## jukebox_screen.gd — Integrated In-Game Jukebox & Sound Test for Steam Circuit Padel Pro.
##
## Implements the full ScreenShell layout and padel_theme styling, seamlessly matching
## the aesthetic of the other game menus (Help, History, Challenges, Settings).
##
## THE PLAYER CARD IS THE SCREEN. The right column is no longer an inspector with a
## player bolted underneath it: the record, the title, the category lamp, the real
## transport readout and the transport controls live in one console card, and the
## long catalogue metadata (BPM, key, style, generative prompt) moved into a
## collapsed `_prompt_section`, because a screenful of prompt text is not what the
## reader opens the jukebox for.
##
## THE THEME OWNS THE PALETTE, THIS FILE OWNS THE CARDS. `padel_theme.tres` declares
## no `CardPanel`/`HeroButton` variation (the names this screen used before fall
## straight through to a bare PanelContainer and a bare Button), and the theme file is
## not this screen's to edit — so the two console surfaces are StyleBoxFlats built
## here out of the theme's own navy/cyan palette (`Palette/colors/surface_1`,
## `surface_2`, `cyan`). `_category_badge`, `_status_badge` and every other
## inventory/locale string keep the exact text they carried before.
##
## WHAT "PLAYING" MEANS HERE. The readout is a view of the real stream: elapsed and
## duration come from `SoundtrackManager.playback_position()`/`playback_duration()`,
## never from a timer this screen runs itself, and the progress bar is that fraction.
## There is no seek, no reactive waveform and no animation that runs while audio is
## silent — a stopped or file-less track shows `0:00`, `--:--` and an empty bar.
##
## SELECTION IS NOT PLAYBACK. `_select_track()` is the highlight the list has always
## had; the `▶` marker plus the "In Riproduzione" line name the track actually
## streaming, so the two can differ without either lying.

const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")
## Emporio OST: the ownership gate. A track the profile does not own (and the LUCALE
## override does not unlock) is listed honestly as locked and is not playable here.
const Economy := preload("res://src/economy/economy_service.gd")
const Config := preload("res://game/match_config.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
const RecordMotif := preload("res://src/ui/jukebox/jukebox_record.gd")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

## Palette sampled from `padel_theme.tres` (`Palette/colors/*`) rather than re-invented.
const NAVY_DEEP := Color(0.02352941, 0.07843137, 0.14901961)
const NAVY_CARD := Color(0.03529412, 0.11372549, 0.22352941)
const NAVY_CONSOLE := Color(0.04313725, 0.14117648, 0.26666668)
const CYAN := Color(0.0, 0.89803922, 1.0)
const INK := Color(0.9647059, 0.96862745, 0.98431373)
const MUTED := Color(1.0, 1.0, 1.0, 0.48)
const LINE := Color(1.0, 1.0, 1.0, 0.12)
const STATUS_IDLE := Color(0.6447059, 0.7098039, 0.78431374)

## How often the transport readout is re-read from the manager. Ten polls a second
## keeps the clock legible without touching text layout every frame.
const READOUT_INTERVAL := 0.1

signal closed
const MusicPreferences := preload("res://src/audio/music_preferences.gd")
var _favorite_buttons: Dictionary = {}
var _only_buttons: Dictionary = {}
var _playlist_scope: OptionButton
var _r3_order: OptionButton
var _playlist_hint: Label
var _playlist_preview := false
var _classic_favorite: CheckButton
## Emitted when the player tries to play a LOCKED track: the host routes this to the
## Emporio shop. The screen itself never opens another screen.
signal shop_requested(track_id: String)

var _manager: Node = null
## The store the ownership gate reads. Unset means the config's own store; a test hands
## in an isolated directory so a real profile is never read.
var _economy_store: RefCounted = null
var _shell: Control = null
var _track_ids: PackedStringArray = []
var _selected_idx: int = 0
var _track_buttons: Array[Button] = []
## Each button's own text without the `▶` playback marker, so marking/unmarking the
## playing track never re-derives the label (and never drifts from the list build).
var _track_base_texts: PackedStringArray = []
const COVERS_DIR := "res://assets/images/jukebox_covers/"

var _cover_cache: Dictionary = {}
var _readout_accum: float = 0.0

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
var _pause_btn: Button = null
var _stop_btn: Button = null
var _prev_btn: Button = null
var _next_btn: Button = null
var _volume_slider: HSlider = null
var _now_playing_label: Label = null

# Player card (the dominant surface)
var _list_card: PanelContainer = null
var _player_card: PanelContainer = null
var _insp_scroll: ScrollContainer = null
var _hero_eyebrow: Label = null
var _record: Control = null
var _progress_bar: ProgressBar = null
var _elapsed_label: Label = null
var _duration_label: Label = null
var _prompt_section: VBoxContainer = null
var _prompt_toggle_btn: Button = null
## True while the reader is dragging the progress handle: the pointer owns the bar for
## that moment, so the 10 Hz readout must not pull it back under the cursor.
var _dragging: bool = false
var _progress_hover: bool = false
## What the last progress style was built for, so the readout poll does not rebuild
## three StyleBoxes ten times a second for no visual change.
var _progress_style_key: String = ""


func _ready() -> void:
	theme = DefaultTheme
	_track_ids = SoundtrackManager.all_track_ids()
	_manager = SoundtrackManager.new()
	add_child(_manager)
	_build_ui()
	_select_track(0)
	# The readout follows the stream, so it is polled rather than evented — the
	# manager owns no per-frame signal and this screen will not invent one.
	set_process(true)


## The store the ownership gate reads. A test hands in an isolated directory (call this
## BEFORE the node enters the tree, or the list is rebuilt here). Never writes.
func set_store(store: RefCounted) -> void:
	_economy_store = store
	if _track_list_container != null:
		for child in _track_list_container.get_children():
			child.queue_free()
		_populate_track_list()
		_refresh_readout()
		_sync_favorites()
		for scope in _only_buttons:
			_only_buttons[scope].set_pressed_no_signal(MusicPreferences.only(_economy(), scope))
		_classic_favorite.set_pressed_no_signal(MusicPreferences.favorites(_economy(), "match").has("classic_match"))
		_r3_order.select(1 if MusicPreferences.random_skip(_economy()) else 0)
		_filter_playlist()


func _economy() -> RefCounted:
	return _economy_store if _economy_store != null else Config.save_store()


## True when the profile may NOT play the track: not owned and not unlocked by LUCALE.
func is_locked(track_id: String) -> bool:
	return not Economy.has_access(_economy(), track_id)


## The locked track ids, in catalogue order — the list a test asserts against.
func locked_ids() -> Array:
	var out: Array = []
	for id in _track_ids:
		if is_locked(String(id)):
			out.append(String(id))
	return out


func _process(delta: float) -> void:
	_readout_accum += delta
	if _readout_accum < READOUT_INTERVAL:
		return
	_readout_accum = 0.0
	if _playlist_preview and not _manager.is_active():
		_play_playlist(1)
	_refresh_readout()


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
	split_hbox.add_theme_constant_override("separation", 20)
	content.add_child(split_hbox)

	_build_list_column(split_hbox)
	_build_player_column(split_hbox)


## LEFT COLUMN: the catalogue. Unchanged in behaviour (same order, same sections, same
## selection semantics); narrower than before so the player card can dominate, with
## ellipsis on the buttons so a long title trims instead of forcing the row wider.
func _build_list_column(split_hbox: HBoxContainer) -> void:
	var list_card := PanelContainer.new()
	list_card.custom_minimum_size = Vector2(300, 0)
	list_card.size_flags_vertical = SIZE_EXPAND_FILL
	list_card.size_flags_stretch_ratio = 0.62
	list_card.add_theme_stylebox_override("panel", _panel_style(NAVY_DEEP, LINE, 12, 1))
	split_hbox.add_child(list_card)
	_list_card = list_card

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
	_build_favorites(list_vbox)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(list_scroll)

	_track_list_container = VBoxContainer.new()
	_track_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_track_list_container.add_theme_constant_override("separation", 6)
	list_scroll.follow_focus = true
	list_scroll.add_child(_track_list_container)

	_populate_track_list()

func _build_favorites(parent: VBoxContainer) -> void:
	_r3_order = OptionButton.new()
	_r3_order.add_item("R3: ordine fisso")
	_r3_order.add_item("R3: ordine casuale")
	_r3_order.select(1 if MusicPreferences.random_skip(_economy()) else 0)
	_r3_order.tooltip_text = "Vale per R3 nei menu e in partita. Rispetta i preferiti e le tracce sbloccate; non cambia l'avanzamento automatico."
	_r3_order.item_selected.connect(func(index: int): MusicPreferences.set_random_skip(_economy(), index == 1))
	parent.add_child(_r3_order)
	var caption := Label.new()
	caption.text = "PREFERITI DEL BRANO SELEZIONATO"
	caption.add_theme_font_size_override("font_size", 11)
	parent.add_child(caption)
	var favorites := HBoxContainer.new()
	parent.add_child(favorites)
	var filters := HBoxContainer.new()
	parent.add_child(filters)
	for scope in ["menu", "match"]:
		var label_text := "Menu" if scope == "menu" else "Partita"
		var favorite := Button.new()
		favorite.toggle_mode = true
		favorite.size_flags_horizontal = SIZE_EXPAND_FILL
		favorite.custom_minimum_size.y = 34
		favorite.text = "+ " + label_text
		favorite.pressed.connect(_toggle_favorite.bind(scope))
		favorites.add_child(favorite)
		_favorite_buttons[scope] = favorite
		var only := CheckButton.new()
		only.text = "Solo pref. " + label_text
		only.add_theme_font_size_override("font_size", 11)
		only.tooltip_text = "Riproduci solo i preferiti in questo contesto. Senza preferiti disponibili, la musica resta silenziosa."
		only.set_pressed_no_signal(MusicPreferences.only(_economy(), scope))
		only.toggled.connect(_set_only_favorites.bind(scope))
		filters.add_child(only)
		_only_buttons[scope] = only
	_classic_favorite = CheckButton.new()
	_classic_favorite.text = "Tema originale: preferito partita"
	_classic_favorite.add_theme_font_size_override("font_size", 11)
	_classic_favorite.tooltip_text = "Il tema generato dal gioco viene riprodotto in partita, non nell'anteprima dei file OST."
	_classic_favorite.set_pressed_no_signal(MusicPreferences.favorites(_economy(), "match").has("classic_match"))
	_classic_favorite.toggled.connect(func(_on: bool):
		MusicPreferences.toggle(_economy(), "match", "classic_match")
		_filter_playlist()
	)
	parent.add_child(_classic_favorite)
	_playlist_scope = OptionButton.new()
	for text in ["Catalogo completo", "Playlist menu", "Playlist partita"]:
		_playlist_scope.add_item(text)
	_playlist_scope.item_selected.connect(func(_index): _filter_playlist())
	parent.add_child(_playlist_scope)
	var listen := Button.new()
	listen.text = "Ascolta playlist"
	listen.pressed.connect(func(): _play_playlist(0))
	parent.add_child(listen)
	_playlist_hint = Label.new()
	_playlist_hint.text = "R3: prossimo brano nei menu e in partita"
	_playlist_hint.add_theme_font_size_override("font_size", 11)
	_playlist_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_playlist_hint)

func _toggle_favorite(scope: String) -> void:
	MusicPreferences.toggle(_economy(), scope, String(_track_ids[_selected_idx]))
	_sync_favorites()
	_filter_playlist()

func _set_only_favorites(enabled: bool, scope: String) -> void:
	MusicPreferences.set_only(_economy(), scope, enabled)
	_filter_playlist()

func _sync_favorites() -> void:
	for scope in _favorite_buttons:
		var on := MusicPreferences.favorites(_economy(), scope).has(String(_track_ids[_selected_idx]))
		_favorite_buttons[scope].set_pressed_no_signal(on)
		_favorite_buttons[scope].text = ("✓ " if on else "+ ") + ("Menu" if scope == "menu" else "Partita")

func _playlist_ids() -> Array[String]:
	var result: Array[String] = []
	var scope := "menu" if _playlist_scope.selected == 1 else "match"
	var favorites := MusicPreferences.favorites(_economy(), scope)
	var only := MusicPreferences.only(_economy(), scope)
	for id in _track_ids:
		var belongs := (id in ["ost_menu", "ost_roster", "ost_career"]) if scope == "menu" else (not id in ["ost_menu", "ost_roster", "ost_career", "ost_victory"])
		if _playlist_scope.selected == 0 or ((belongs or favorites.has(id)) and (not only or favorites.has(id))):
			result.append(id)
	return result

func _filter_playlist() -> void:
	var ids := _playlist_ids()
	for child in _track_list_container.get_children():
		if child is Label:
			child.visible = _playlist_scope.selected == 0
	for index in _track_buttons.size():
		_track_buttons[index].visible = ids.has(_track_ids[index])
	_playlist_hint.text = "Nessuna OST nella lista. Aggiungila dal catalogo; il tema originale si ascolta in partita." if ids.is_empty() else "R3: prossimo brano nei menu e in partita"
	if not ids.is_empty() and not ids.has(_track_ids[_selected_idx]):
		_select_track(_track_ids.find(ids[0]))
	if _playlist_preview and not ids.has(_manager.current_track_id()):
		_manager.stop(0.0)

func _play_playlist(direction: int) -> void:
	var ids := _playlist_ids().filter(func(id): return not is_locked(id) and SoundtrackManager.has_track(id))
	if ids.is_empty():
		_on_stop_pressed()
		_playlist_hint.text = "Nessuna traccia sbloccata disponibile in questa playlist."
		return
	var current := ids.find(_manager.current_track_id())
	var next := posmod(current + direction, ids.size()) if current >= 0 else 0
	_select_track(_track_ids.find(ids[next]))
	_on_play_pressed()
	var stream: AudioStream = _manager.active_player().stream.duplicate()
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	_manager.active_player().stream = stream
	_manager.active_player().play()
	_playlist_preview = true


## RIGHT COLUMN: the player console. This is the screen's dominant surface — the
## record and title read first, the transport second, the catalogue metadata last.
func _build_player_column(split_hbox: HBoxContainer) -> void:
	var inspector_card := PanelContainer.new()
	inspector_card.size_flags_horizontal = SIZE_EXPAND_FILL
	inspector_card.size_flags_vertical = SIZE_EXPAND_FILL
	inspector_card.size_flags_stretch_ratio = 1.0
	inspector_card.add_theme_stylebox_override("panel", _panel_style(NAVY_CARD, Color(CYAN, 0.18), 12, 1))
	split_hbox.add_child(inspector_card)

	var insp_margin := MarginContainer.new()
	insp_margin.add_theme_constant_override("margin_left", 18)
	insp_margin.add_theme_constant_override("margin_top", 14)
	insp_margin.add_theme_constant_override("margin_right", 18)
	insp_margin.add_theme_constant_override("margin_bottom", 14)
	inspector_card.add_child(insp_margin)

	# The column scrolls rather than overflowing: collapsed it fits every shipped
	# resolution, and expanded at 720p the prompt is reached by scrolling this column
	# instead of drawing outside the card or squeezing the player out of the screen.
	_insp_scroll = ScrollContainer.new()
	_insp_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_insp_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_insp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	insp_margin.add_child(_insp_scroll)

	var insp_vbox := VBoxContainer.new()
	insp_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	insp_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	insp_vbox.add_theme_constant_override("separation", 12)
	_insp_scroll.add_child(insp_vbox)

	# Console header: what this card is, and the honest audio-file lamp.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	insp_vbox.add_child(header_row)

	var eyebrow := Label.new()
	eyebrow.text = "CONSOLE TRACCIA"
	eyebrow.theme_type_variation = &"LabelSmall"
	eyebrow.size_flags_vertical = SIZE_SHRINK_CENTER
	header_row.add_child(eyebrow)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)

	_status_badge = Label.new()
	_status_badge.add_theme_font_size_override("font_size", 12)
	_status_badge.size_flags_vertical = SIZE_SHRINK_CENTER
	header_row.add_child(_status_badge)

	# The dominant card: record + title face to face, then the transport.
	_player_card = PanelContainer.new()
	_player_card.size_flags_horizontal = SIZE_EXPAND_FILL
	_player_card.size_flags_vertical = SIZE_EXPAND_FILL
	_player_card.add_theme_stylebox_override(
		"panel", _panel_style(NAVY_CONSOLE, Color(CYAN, 0.35), 12, 1, Color(CYAN, 0.14), 14)
	)
	insp_vbox.add_child(_player_card)

	var player_margin := MarginContainer.new()
	player_margin.add_theme_constant_override("margin_left", 18)
	player_margin.add_theme_constant_override("margin_top", 16)
	player_margin.add_theme_constant_override("margin_right", 18)
	player_margin.add_theme_constant_override("margin_bottom", 16)
	_player_card.add_child(player_margin)

	var player_vbox := VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 14)
	# The console card is deliberately taller than its content on a 1080p screen;
	# centring the stack keeps that extra room reading as console margin instead of as
	# an accidental gap under the transport.
	player_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	player_margin.add_child(player_vbox)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 18)
	player_vbox.add_child(hero_row)

	# The record keeps a square footprint at any card size, so it can never stretch
	# into a shape the motif was not drawn for.
	var record_box := AspectRatioContainer.new()
	record_box.ratio = 1.0
	record_box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	record_box.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	record_box.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	record_box.custom_minimum_size = Vector2(168, 168)
	record_box.size_flags_vertical = SIZE_SHRINK_CENTER
	hero_row.add_child(record_box)

	_record = RecordMotif.new()
	_record.size_flags_horizontal = SIZE_EXPAND_FILL
	_record.size_flags_vertical = SIZE_EXPAND_FILL
	record_box.add_child(_record)

	var hero_info := VBoxContainer.new()
	hero_info.size_flags_horizontal = SIZE_EXPAND_FILL
	hero_info.size_flags_vertical = SIZE_SHRINK_CENTER
	hero_info.add_theme_constant_override("separation", 6)
	hero_row.add_child(hero_info)

	# The hero's title/scene/badge describe the SELECTED track, so this eyebrow must say
	# so — "IN RIPRODUZIONE" here would be a lie whenever the selection is not the track
	# actually streaming. `_refresh_readout()` flips it only when the two coincide.
	_hero_eyebrow = Label.new()
	_hero_eyebrow.text = "TRACCIA SELEZIONATA"
	_hero_eyebrow.theme_type_variation = &"LabelSmall"
	hero_info.add_child(_hero_eyebrow)

	# Track Title — the largest type in the card, trimmed at two lines rather than
	# growing the card (the longest catalogue title is 46 characters).
	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeroTitle"
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.max_lines_visible = 2
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_info.add_child(_title_label)

	# Destination Scene / Arena — one line, trimmed, never widening the column.
	_scene_label = Label.new()
	_scene_label.add_theme_font_size_override("font_size", 13)
	_scene_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	_scene_label.clip_text = true
	_scene_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_info.add_child(_scene_label)

	# Category lamp. Text contract is unchanged: "[ <CATEGORY> ]" in upper case.
	var badges_row := HBoxContainer.new()
	badges_row.add_theme_constant_override("separation", 10)
	hero_info.add_child(badges_row)

	_category_badge = Label.new()
	_category_badge.theme_type_variation = &"Badge"
	_category_badge.size_flags_vertical = SIZE_SHRINK_CENTER
	badges_row.add_child(_category_badge)

	var badge_spacer := Control.new()
	badge_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	badges_row.add_child(badge_spacer)

	# Honest state line: idle, playing, or "waiting for its file".
	_now_playing_label = Label.new()
	_now_playing_label.text = "In Riproduzione: Nessuna traccia attiva"
	_now_playing_label.add_theme_font_size_override("font_size", 13)
	_now_playing_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_now_playing_label.clip_text = true
	_now_playing_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_info.add_child(_now_playing_label)

	# Real transport readout: elapsed / duration around a bar driven by the stream.
	var times_row := HBoxContainer.new()
	player_vbox.add_child(times_row)

	_elapsed_label = Label.new()
	_elapsed_label.theme_type_variation = &"Mono"
	_elapsed_label.text = "0:00"
	times_row.add_child(_elapsed_label)

	var times_spacer := Control.new()
	times_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	times_row.add_child(times_spacer)

	_duration_label = Label.new()
	_duration_label.theme_type_variation = &"Mono"
	_duration_label.text = "--:--"
	_duration_label.add_theme_color_override("font_color", MUTED)
	times_row.add_child(_duration_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	# 14 px rather than 10: the bar is now a click target, and a target the reader can
	# actually hit is worth four pixels. The look is unchanged (same cyan fill, same
	# track, same rounding).
	_progress_bar.custom_minimum_size = Vector2(0, 14)
	# A ProgressBar takes no input by default, so the click/drag handling below is only
	# reachable because this is set.
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_progress_bar.focus_mode = Control.FOCUS_ALL
	_progress_bar.gui_input.connect(_on_progress_gui_input)
	_progress_bar.mouse_entered.connect(_on_progress_hover.bind(true))
	_progress_bar.mouse_exited.connect(_on_progress_hover.bind(false))
	_apply_progress_style()
	player_vbox.add_child(_progress_bar)

	# Transport controls. Prev/Next select only (never autoplay, as before); Play is
	# disabled for a track with no file on disk, Stop only while something is playing.
	var controls_bar := HBoxContainer.new()
	# 12 rather than 16: the extra Pausa control has to fit the same 1280x720 band
	# without moving anything else about the row's shape.
	controls_bar.add_theme_constant_override("separation", 12)
	player_vbox.add_child(controls_bar)

	_prev_btn = Button.new()
	_prev_btn.text = "⏮ Prec."
	_prev_btn.theme_type_variation = &"SegmentedInactive"
	_prev_btn.custom_minimum_size = Vector2(88, 40)
	_prev_btn.tooltip_text = "Traccia precedente"
	_prev_btn.pressed.connect(_on_prev_pressed)
	controls_bar.add_child(_prev_btn)

	_play_btn = Button.new()
	_play_btn.text = "▶ Play"
	_play_btn.theme_type_variation = &"ButtonPrimary"
	_play_btn.custom_minimum_size = Vector2(132, 40)
	_play_btn.tooltip_text = "Riproduci la traccia selezionata"
	_play_btn.pressed.connect(_on_play_pressed)
	controls_bar.add_child(_play_btn)

	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Pausa"
	_pause_btn.theme_type_variation = &"ButtonSecondary"
	_pause_btn.custom_minimum_size = Vector2(104, 40)
	_pause_btn.tooltip_text = "Metti in pausa la traccia in riproduzione"
	_pause_btn.pressed.connect(_on_pause_pressed)
	controls_bar.add_child(_pause_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "⏹ Stop"
	_stop_btn.theme_type_variation = &"ButtonSecondary"
	_stop_btn.custom_minimum_size = Vector2(96, 40)
	_stop_btn.tooltip_text = "Interrompi la riproduzione"
	_stop_btn.pressed.connect(_on_stop_pressed)
	controls_bar.add_child(_stop_btn)

	_next_btn = Button.new()
	_next_btn.text = "Succ. ⏭"
	_next_btn.theme_type_variation = &"SegmentedInactive"
	_next_btn.custom_minimum_size = Vector2(88, 40)
	_next_btn.tooltip_text = "Traccia successiva"
	_next_btn.pressed.connect(_on_next_pressed)
	controls_bar.add_child(_next_btn)

	var controls_spacer := Control.new()
	controls_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	controls_bar.add_child(controls_spacer)

	var vol_label := Label.new()
	vol_label.text = "Vol"
	vol_label.add_theme_font_size_override("font_size", 12)
	vol_label.size_flags_vertical = SIZE_SHRINK_CENTER
	controls_bar.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = -30.0
	_volume_slider.max_value = 6.0
	# Start where the Music bus actually is: opening the jukebox must not rewrite the
	# user's stored mix, and the first `value_changed` (after the connect below) is
	# what puts the slider and the bus in step.
	_volume_slider.value = _bus_volume_db()
	_volume_slider.custom_minimum_size = Vector2(96, 20)
	_volume_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	_volume_slider.tooltip_text = "Volume musica"
	_volume_slider.value_changed.connect(_on_volume_changed)
	controls_bar.add_child(_volume_slider)

	# Collapsed secondary section: BPM/key, style and the generative prompt.
	_prompt_toggle_btn = Button.new()
	_prompt_toggle_btn.theme_type_variation = &"SegmentedInactive"
	_prompt_toggle_btn.custom_minimum_size = Vector2(0, 32)
	_prompt_toggle_btn.pressed.connect(_on_prompt_toggle_pressed)
	insp_vbox.add_child(_prompt_toggle_btn)

	_prompt_section = VBoxContainer.new()
	_prompt_section.visible = false
	_prompt_section.size_flags_vertical = SIZE_EXPAND_FILL
	_prompt_section.add_theme_constant_override("separation", 8)
	insp_vbox.add_child(_prompt_section)

	_bpm_key_label = Label.new()
	_bpm_key_label.add_theme_font_size_override("font_size", 12)
	_bpm_key_label.add_theme_color_override("font_color", Color(0.74, 0.93, 1.0))
	_prompt_section.add_child(_bpm_key_label)

	_style_label = Label.new()
	_style_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label.add_theme_font_size_override("font_size", 12)
	_style_label.add_theme_color_override("font_color", Color(0.78, 0.75, 0.72))
	_prompt_section.add_child(_style_label)

	var prompt_bar := HBoxContainer.new()
	prompt_bar.add_theme_constant_override("separation", 10)
	_prompt_section.add_child(prompt_bar)

	var prompt_title := Label.new()
	prompt_title.text = "PROMPT GENERATIVO PER LYRIA / MUSICFX"
	prompt_title.size_flags_horizontal = SIZE_EXPAND_FILL
	prompt_title.size_flags_vertical = SIZE_SHRINK_CENTER
	prompt_title.theme_type_variation = &"LabelSmall"
	prompt_title.add_theme_color_override("font_color", Color(0.65, 0.82, 0.95))
	prompt_bar.add_child(prompt_title)

	_copy_btn = Button.new()
	_copy_btn.text = "📋 Copia Prompt"
	_copy_btn.theme_type_variation = &"SegmentedInactive"
	_copy_btn.custom_minimum_size = Vector2(130, 30)
	_copy_btn.pressed.connect(_on_copy_prompt_pressed)
	prompt_bar.add_child(_copy_btn)

	_prompt_text = TextEdit.new()
	_prompt_text.editable = false
	_prompt_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_text.custom_minimum_size = Vector2(0, 110)
	_prompt_text.size_flags_vertical = SIZE_EXPAND_FILL
	_prompt_section.add_child(_prompt_text)

	_apply_prompt_toggle_text()


func _populate_track_list() -> void:
	_track_buttons.clear()
	_track_base_texts = PackedStringArray()
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
		# Emporio OST: a track the profile does not own is marked here, honestly, and the
		# marker lives in the base text so the ▶ playback marker cannot erase it.
		var lock := " 🔒" if is_locked(tid) else ""
		var base_text := " %s. %s %s%s" % [idx_str, title, badge, lock]
		btn.text = base_text
		# A long title trims inside the column instead of forcing the row wider.
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 12)

		var captured_idx := i
		btn.pressed.connect(func(): _select_track(captured_idx))
		_track_list_container.add_child(btn)
		_track_buttons.append(btn)
		_track_base_texts.append(base_text)


func _select_track(idx: int) -> void:
	if idx < 0 or idx >= _track_ids.size():
		return
	_selected_idx = idx
	_sync_favorites()

	for i in _track_buttons.size():
		_track_buttons[i].theme_type_variation = &"SegmentedActive" if (i == idx) else &"SegmentedInactive"

	var tid: String = _track_ids[idx]
	var info := SoundtrackManager.track_info(tid)
	var has_file := SoundtrackManager.has_track(tid)

	# Title/arena: the pair this screen always intended to show but never assigned.
	_title_label.text = String(info.get("title", tid))
	_scene_label.text = "Scena: %s" % String(info.get("scene", "—"))

	var cat_str: String = String(info.get("category", "General"))
	_category_badge.text = "[ %s ]" % cat_str.to_upper()
	_category_badge.add_theme_color_override("font_color", _category_color(cat_str))
	_bpm_key_label.text = "Tempo: %d BPM  |  Chiave: %s" % [int(info.get("bpm", 120)), String(info.get("key", "D minor"))]

	if has_file:
		_status_badge.text = "✔ Audio: File presente su disco"
		_status_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		_status_badge.text = "⏳ Audio: In attesa di generazione Lyria"
		_status_badge.add_theme_color_override("font_color", Color(0.95, 0.72, 0.32))

	_style_label.text = "Stile & Strumentazione: %s" % String(info.get("style", ""))
	_prompt_text.text = String(info.get("prompt", ""))

	if _record != null:
		_record.set_accent(_category_color(cat_str))
		_record.set_cover_texture(_load_cover_for_track(tid))

	# A selection with no file on disk cannot be played — the button says so instead
	# of accepting a press that would only ever fail in the manager.
	_play_btn.disabled = not has_file
	_refresh_readout()


## Loads the picture disc cover art with reliable disk-loader and cache
func _load_cover_for_track(tid: String) -> Texture2D:
	if _cover_cache.has(tid):
		return _cover_cache[tid]
	var tex: Texture2D = null
	var candidate_paths := [
		COVERS_DIR + tid + ".png",
		COVERS_DIR + tid + ".jpg"
	]
	for p in candidate_paths:
		var global_p := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(global_p):
			var img := Image.load_from_file(global_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				break
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is Texture2D:
				tex = res
				break

	_cover_cache[tid] = tex
	return tex


## The category lamp colour, shared by the badge and the record label so the two
## never disagree about which suite the track belongs to.
func _category_color(cat_str: String) -> Color:
	if cat_str.begins_with("Sawano"):
		return Color(1.0, 0.28, 0.35)
	elif cat_str.begins_with("Dragon Ball"):
		return Color(1.0, 0.55, 0.1) # Iconic Dragon Ball Orange
	elif cat_str.begins_with("Epico"):
		return Color(1.0, 0.82, 0.2)
	return Color(0.3, 0.8, 0.95)


## Re-reads the live stream and repaints the transport. Everything here is a fact
## about the manager's own players: elapsed, duration and fraction are the stream's,
## and the disc only spins while audio is really playing.
func _refresh_readout() -> void:
	if _manager == null:
		return
	var now_id := String(_manager.current_track_id())
	var active: bool = now_id != "" and bool(_manager.is_active())
	var held: bool = active and bool(_manager.is_paused())
	var playing: bool = active and bool(_manager.is_playing())

	if active:
		# Playing and held both report the stream: a held track keeps its own frozen
		# position, so the readout never snaps to zero just because the audio is held.
		_elapsed_label.text = _fmt_time(float(_manager.playback_position()))
		var duration: float = _manager.playback_duration()
		_duration_label.text = _fmt_time(duration) if duration > 0.0 else "--:--"
		# The pointer owns the bar mid-drag; the readout takes it back on release.
		if not _dragging:
			_progress_bar.value = float(_manager.playback_progress()) * 100.0
	else:
		_elapsed_label.text = _fmt_time(0.0)
		_duration_label.text = "--:--"
		if not _dragging:
			_progress_bar.value = 0.0
		# A drag that outlives the stream it was dragging must not hold the bar hostage.
		_dragging = false

	_record.set_spinning(playing)
	# Both transport controls key off "a track is loaded", not off "audio is moving", so
	# a held track can still be released and stopped.
	_pause_btn.disabled = not active
	_pause_btn.text = "▶ Riprendi" if held else "⏸ Pausa"
	_pause_btn.tooltip_text = (
		"Riprendi la traccia dal punto in cui era" if held else "Metti in pausa la traccia in riproduzione"
	)
	_stop_btn.disabled = not active
	# The hero shows the SELECTED track; only when that selection is the one actually
	# streaming does the eyebrow claim playback. The "In Riproduzione" line below it
	# always names the real audio, so the two never contradict each other.
	var selected_is_playing: bool = playing and _track_ids[_selected_idx] == now_id
	_hero_eyebrow.text = "IN RIPRODUZIONE" if selected_is_playing else "TRACCIA SELEZIONATA"
	var seekable := _seekable()
	_progress_bar.mouse_default_cursor_shape = CURSOR_POINTING_HAND if seekable else CURSOR_ARROW
	_progress_bar.tooltip_text = "Clic o trascina per saltare nella traccia" if seekable else "Nessuna traccia in riproduzione"
	_apply_progress_style()
	_refresh_track_markers(now_id)


## Marks the ONE playing row (and only that row) with `▶`, leaving the selected row's
## own highlight untouched so selection and playback stay separately readable.
func _refresh_track_markers(now_id: String) -> void:
	if _track_base_texts.size() != _track_buttons.size():
		return
	for i in _track_buttons.size():
		var btn: Button = _track_buttons[i]
		var is_now := now_id != "" and _track_ids[i] == now_id
		var wanted := ("▶" + _track_base_texts[i]) if is_now else _track_base_texts[i]
		if btn.text != wanted:
			btn.text = wanted
		# The selected row keeps the active variation's own contrast; only an
		# unselected playing row needs the cyan tint to stand out.
		if is_now and i != _selected_idx:
			btn.add_theme_color_override("font_color", Color(0.49411765, 0.95294118, 1.0))
		else:
			btn.remove_theme_color_override("font_color")


func _fmt_time(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	return "%d:%02d" % [int(total / 60.0), total % 60]


## A click (or a drag) on the bar moves the ACTIVE stream — the one the readout is
## showing — never the row the catalogue happens to have selected.
func _on_progress_gui_input(event: InputEvent) -> void:
	if not _seekable():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_dragging = button.pressed
		_seek_to_fraction(_fraction_at(button.position.x))
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_seek_to_fraction(_fraction_at(motion.position.x))
	elif event is InputEventKey and event.pressed and not event.echo:
		# The bar takes keyboard focus, so it owes the keyboard the same action: five
		# seconds at a time, plus the two ends.
		var key := event as InputEventKey
		var here := float(_manager.playback_position())
		match key.keycode:
			KEY_LEFT:
				_seek_to_seconds(here - 5.0)
			KEY_RIGHT:
				_seek_to_seconds(here + 5.0)
			KEY_HOME:
				_seek_to_seconds(0.0)
			KEY_END:
				_seek_to_seconds(float(_manager.playback_duration()) - 1.0)
			_:
				return
		get_viewport().set_input_as_handled()


## Horizontal position inside the bar -> [0, 1]. Local coordinates, so the same mapping
## serves a click and a drag, and any position outside the bar lands on an end.
func _fraction_at(x: float) -> float:
	return clampf(x / maxf(_progress_bar.size.x, 1.0), 0.0, 1.0)


func _seek_to_fraction(frac: float) -> void:
	var duration := float(_manager.playback_duration())
	if duration <= 0.0:
		return
	var clamped := clampf(frac, 0.0, 1.0)
	if not bool(_manager.seek(clamped * duration)):
		return
	# The pointer's own fraction is the honest bar value for this interaction (the manager
	# clamps through the engine), and the readout takes the bar back on release.
	_progress_bar.value = clamped * 100.0
	_sync_seek_feedback()


func _seek_to_seconds(seconds: float) -> void:
	if not bool(_manager.seek(seconds)):
		return
	_sync_seek_feedback()


## Report the requested position at once: while held, the engine seek is deferred to
## release, so the readout would otherwise lag the interaction by a whole hold.
func _sync_seek_feedback() -> void:
	var duration := float(_manager.playback_duration())
	if duration <= 0.0:
		return
	_progress_bar.value = float(_manager.playback_progress()) * 100.0
	_elapsed_label.text = _fmt_time(float(_manager.playback_position()))
	_duration_label.text = _fmt_time(duration)


func _on_progress_hover(over: bool) -> void:
	_progress_hover = over
	_apply_progress_style()


## True only when a seek would really move something: an active stream of known length.
## Idle and unknown-duration both answer false, so the bar never offers an action it
## cannot perform, and the cursor stays an arrow there.
func _seekable() -> bool:
	if _manager == null or not bool(_manager.is_active()):
		return false
	return float(_manager.playback_duration()) > 0.0


## The cyan bar plus the cues that say it is interactive: a brighter fill under the
## pointer and a themed focus ring. StyleBoxes are shared state, so this rebuilds them
## only when the state actually changes rather than on every readout poll.
func _apply_progress_style() -> void:
	var seekable := _seekable()
	var key := "%s-%s" % [str(seekable), str(_progress_hover and seekable)]
	if key == _progress_style_key:
		return
	_progress_style_key = key
	var strong := seekable and _progress_hover
	var fill := Color(CYAN, 0.85) if strong else (CYAN if seekable else Color(CYAN, 0.35))
	_progress_bar.add_theme_stylebox_override("background", _panel_style(Color(1, 1, 1, 0.07), LINE, 7, 1))
	_progress_bar.add_theme_stylebox_override("fill", _panel_style(fill, fill, 7, 0))
	_progress_bar.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), CYAN, 8, 2))


## The dedicated transport control. Both directions act on the stream that is really
## loaded, whatever the catalogue has selected.
func _on_pause_pressed() -> void:
	if _manager == null:
		return
	# The label and the line change only on a real transition: a refused hold or release
	# must leave the transport saying exactly what it is still doing.
	if bool(_manager.is_paused()):
		if not bool(_manager.resume()):
			return
		_now_playing_label.text = "In Riproduzione: %s" % _active_track_title()
		_now_playing_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		if not bool(_manager.pause()):
			return
		_now_playing_label.text = "In pausa: %s" % _active_track_title()
		_now_playing_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_refresh_readout()


## The title of the track actually loaded in the manager, not of the selected row.
func _active_track_title() -> String:
	var now_id := String(_manager.current_track_id())
	return String(SoundtrackManager.track_info(now_id).get("title", now_id))


func _on_play_pressed() -> void:
	_playlist_preview = false
	var tid: String = _track_ids[_selected_idx]
	var info := SoundtrackManager.track_info(tid)
	var title: String = String(info.get("title", tid))

	# Emporio OST: only owned content plays from here. A locked track is not played and
	# not silently allowed — the screen says so and asks the host to open the shop.
	if is_locked(tid):
		if Economy.relock_all(_economy()):
			_now_playing_label.text = "Blocco Alelu attivo: usa Lucale per sbloccare."
			return
		_now_playing_label.text = "Traccia bloccata: acquistabile nell'Emporio"
		_now_playing_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25))
		shop_requested.emit(tid)
		_refresh_readout()
		return

	if SoundtrackManager.has_track(tid):
		_manager.play_track(tid, 0.3)
		_now_playing_label.text = "In Riproduzione: %s" % title
		_now_playing_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		_now_playing_label.text = "Traccia '%s' in attesa: inserisci il file .ogg in res://assets/audio/music/" % title
		_now_playing_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25))
	_refresh_readout()


func _on_stop_pressed() -> void:
	_playlist_preview = false
	_dragging = false
	if _manager != null:
		_manager.stop(0.2)
	_now_playing_label.text = "Riproduzione interrotta"
	_now_playing_label.add_theme_color_override("font_color", STATUS_IDLE)
	_refresh_readout()


func _on_prev_pressed() -> void:
	if _playlist_scope.selected != 0:
		_play_playlist(-1)
		return
	var new_idx := (_selected_idx - 1 + _track_ids.size()) % _track_ids.size()
	_select_track(new_idx)


func _on_next_pressed() -> void:
	if _playlist_scope.selected != 0:
		_play_playlist(1)
		return
	var new_idx := (_selected_idx + 1) % _track_ids.size()
	_select_track(new_idx)


func _on_volume_changed(val: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, val)


## The Music bus volume the slider should open at, in the slider's own dB band.
## A missing bus reads as 0.0 dB — the same value the bus defaults to — and an
## out-of-band or muted bus is clamped so the handle is always somewhere reachable.
func _bus_volume_db() -> float:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		return 0.0
	return clampf(AudioServer.get_bus_volume_db(bus_idx), -30.0, 6.0)


func _on_prompt_toggle_pressed() -> void:
	_prompt_section.visible = not _prompt_section.visible
	_apply_prompt_toggle_text()


func _apply_prompt_toggle_text() -> void:
	var open := _prompt_section.visible
	_prompt_toggle_btn.text = "▾ Metadati & Prompt (BPM, chiave, prompt)" if open else "▸ Metadati & Prompt (BPM, chiave, prompt)"
	_prompt_toggle_btn.tooltip_text = "Nascondi metadati e prompt" if open else "Mostra metadati e prompt"


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


## The two console surfaces. `padel_theme.tres` has no card variation this screen may
## use (`CardPanel` is not a theme item, and `PanelCardSelected` is declared for
## `Panel`, not `PanelContainer`), and the theme file is not this ticket's to edit.
func _panel_style(
	bg: Color, border: Color, radius: int, border_width: int,
	shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	if shadow_size > 0:
		box.shadow_color = shadow
		box.shadow_size = shadow_size
	return box
