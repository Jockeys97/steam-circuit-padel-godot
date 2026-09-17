## ArenaScreen.gd — `screen-arena` (`index.html:157-178`), the last screen before the field.
##
## WHAT THIS SCREEN IS. The reference's ninth section: the header, the arena grid the
## renderer fills (`renderArenas`, `js/ui.js:1220-1275`), and the player-mode panel
## (`index.html:168-177`). Three states overlap on this grid and each one is the
## reference's own:
##
##   * the build's wall (`demoLocked(arena, DEMO_CONTENT.arenas)`), which is a lock like
##     any other on the card but a different sentence — `demoOnlyFull`;
##   * the career's wall (`isUnlocked(arena, ui.career)`), which in the frozen table no
##     arena carries (none has an `unlock`) and which is still read, not assumed;
##   * the calendar's own choice: in career the arena is the fixture's and the others stay
##     visible but switched off, with the sentence that says why — `arenaOtherMatchday`,
##     or `arenaOtherRound` in a tournament. The fixture card carries the badge that names
##     where the choice came from (`arenaByCalendar` / `arenaByBracket`).
##
## The reference's own comment (`js/ui.js:1227-1230`) gives the reason: the match uses the
## fixture's arena and throws `ui.selectedArena` away, so letting the grid choose was "a
## choice the game discarded". This port keeps that note in behaviour, not in a comment:
## a non-fixture card is disabled in career/tournament exactly as `fuoriGiornata` is.
##
## WHAT IT NEVER DOES. No mode logic, no simulation: the start path is the contract that
## already exists (`game/main_menu.gd:497` quick → `res://game/Match.tscn`, `:502` modes →
## `res://game/ModeScreen.tscn`), reached through `Config.pending_mode` and
## `Config.arena_index` — the seams `game/match_config.gd:22-27` documents.
##
## SPLIT FROM THE SCENES. Like the other screens in this lane: named nodes only, every
## string resolved from `UiStrings`, chrome read off `padel_theme.tres`.

extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Locale := preload("res://src/locale/locale.gd")

const SCREEN_ID := "arena"
const BACK_TARGET_ID := "characters"
## The two scenes `game/main_menu.gd` already changes to, verbatim (`:497`, `:502`).
const MATCH_SCENE := "res://game/Match.tscn"
const MODE_SCENE := "res://game/ModeScreen.tscn"

const GRID_COLUMNS := 3
const SMALL_COLUMNS := 1
const GRID_BREAKPOINT := 1050.0
const PREVIEW_RATIO := 16.0 / 9.0
const PREVIEW_MIN_HEIGHT := 120.0
## `.arena-card__body { padding: 18px }` (`styles.css:323-345`).
const CARD_PADDING := 18.0

const CARD_PREFIX := "ArenaCard_"
const ART_PREFIX := "ArenaArt_"
const NAME_PREFIX := "ArenaName_"
const LINE_PREFIX := "ArenaLine_"
const BADGE_PREFIX := "ArenaBadge_"
const LOCK_PREFIX := "ArenaLock_"
const MODE_PREFIX := "PlayerModeButton_"

const WORDING_QUICK := "quick"
const WORDING_CAREER := "career"
const WORDING_TOURNAMENT := "tournament"
const PLAYER_MODES := ["solo", "coop", "pvp"]
const CAPTURE_STATES := ["default", "career-calendar", "tournament-bracket", "demo-locked", "player-mode-coop"]

const MODE_KEYS := {
	"solo": "pmSolo",
	"coop": "pmCoop",
	"pvp": "pmPvp",
}

var _rows: Array = []
var _wording: String = WORDING_QUICK
var _selected_id: String = ""
var _locked_ids: Array = []
var _out_of_matchday: Array = []
var _in_program: String = ""
var _capture_lock_pin: String = ""
var _capture_entry_mode: String = ""
var _bindings: Array[Dictionary] = []
var _text_nodes: Dictionary = {}
var _focus_specs: Array[Dictionary] = []


func screen_id() -> String:
	return SCREEN_ID


## The contract's own name for the declared back edge (`ScreenContract.back_target`).
func back_target() -> String:
	return BACK_TARGET_ID


func capture_states() -> Array:
	return CAPTURE_STATES.duplicate()


# ---------------------------------------------------------------------------
# Lifecycle


func _ready() -> void:
	_style_chrome()
	_apply_layout()
	_apply_accessibility()
	resized.connect(_apply_layout)
	var grid := _control("ArenaGrid")
	if grid != null:
		grid.resized.connect(_update_preview_heights)
	_wire()
	refresh_data()


func enter(payload: Dictionary = {}) -> void:
	if payload.has("entry_mode"):
		_capture_entry_mode = String(payload["entry_mode"])
	if _capture_entry_mode == "":
		_capture_entry_mode = String(Config.pending_mode)
	refresh_data()


func exit() -> void:
	pass


func _wire() -> void:
	var back := _control("BackButton") as Button
	if back != null:
		back.pressed.connect(_on_back)
	(back as Button).focus_mode = Control.FOCUS_ALL
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key) as Button
		if button != null:
			button.pressed.connect(select_player_mode.bind(key))
			button.focus_mode = Control.FOCUS_ALL


func _on_back() -> void:
	route_to(BACK_TARGET_ID)


## The router moves. It is the first node above this screen that owns `go_to`
## (`ScreenRouter` mounts screens under its host); a press with no router above is
## reported, not swallowed.
func route_to(screen_id: String) -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to(screen_id))
		node = node.get_parent()
	push_warning("ArenaScreen: no router above this screen; '%s' went nowhere" % screen_id)
	return false


# ---------------------------------------------------------------------------
# Data


## The nine rows of `renderArenas` (`js/ui.js:1240-1268`), the build's answer included.
func refresh_data() -> void:
	_wording = _wording_now()
	_rows = _rows_now()
	_locked_ids = []
	for row in _rows:
		if bool((row as Dictionary).get("locked", false)):
			_locked_ids.append(String((row as Dictionary).get("id", "")))
	_in_program = _fixture_arena_id()
	# The calendar's own choice cannot be a locked card: `selectableArenas()` excludes
	# them before the fixture is drawn (`js/ui.js:490-503`).
	if _in_program != "" and _locked_ids.has(_in_program):
		_in_program = ""
	_out_of_matchday = []
	if _in_program != "":
		for row in _rows:
			var id := String((row as Dictionary).get("id", ""))
			if id != _in_program and not _locked_ids.has(id):
				_out_of_matchday.append(id)
	if _selected_id == "" or _row_of(_selected_id).is_empty() or arena_card_state(_selected_id) == "locked":
		_selected_id = _first_selectable_id()
	_build_grid()
	_build_player_mode()
	_apply_layout()
	refresh_strings()


func _wording_now() -> String:
	var mode := String(Config.pending_mode)
	if mode == WORDING_CAREER or mode == WORDING_TOURNAMENT:
		return mode
	return WORDING_QUICK


## `selectableArenas()` (`js/ui.js:490-492`): the build's filter *and* the career's wall —
## `demoFilter(ARENAS, DEMO_CONTENT.arenas).filter((a) => isUnlocked(a, ui.career))`. The
## fixture must come from this pool, or the calendar would name an arena the career has
## not opened: `Config.selectable_arenas()` alone is only the build's half
## (`match_config.gd:64-66`).
func _career_selectable_arenas() -> Array:
	var out: Array = []
	for row in _rows:
		var entry: Dictionary = row
		if bool(entry.get("locked", false)) or _locked_ids.has(String(entry.get("id", ""))):
			continue
		for arena in Frozen.arenas():
			if String((arena as Dictionary).get("id", "")) == String(entry.get("id", "")):
				out.append(arena)
				break
	return out


## `const dettata = ui.selectedMode === "career" ? currentFixture().arena : …`
## (`js/ui.js:1231-1235`), read through the port's own rules.
func _fixture_arena_id() -> String:
	var available: Array = _career_selectable_arenas()
	if _wording == WORDING_CAREER:
		var career: Dictionary = ModesSave.load_career(Config.save_store())
		var fixture: Dictionary = CareerRules.career_fixture(
			int(career.get("season", 1)), int(career.get("matchIndex", 0)), available)
		var arena: Dictionary = fixture.get("arena", {}) if fixture.get("arena") is Dictionary else {}
		return String(arena.get("id", ""))
	if _wording == WORDING_TOURNAMENT:
		var round := ModesSave.tournament_round(Config.save_store())
		var fixture: Dictionary = CareerRules.tournament_fixture(round, available)
		var arena: Dictionary = fixture.get("arena", {}) if fixture.get("arena") is Dictionary else {}
		return String(arena.get("id", ""))
	return ""


## `renderArenas`'s three booleans per card (`js/ui.js:1238-1241`), with the build's wall
## the only thing a capture state may pin.
func _rows_now() -> Array:
	var out: Array = []
	for row in UiData.arena_rows(Config.save_store()):
		var entry: Dictionary = (row as Dictionary).duplicate(true)
		var id := String(entry.get("id", ""))
		var demo_locked := bool(entry.get("demo_locked", false))
		entry["demo_locked"] = demo_locked
		if _capture_lock_pin == "demo":
			demo_locked = not DemoContent.allowed_arena_ids().has(id)
			entry["demo_locked"] = demo_locked
		entry["locked"] = demo_locked or bool(entry.get("locked", false))
		entry["accent"] = _accent_of(id)
		out.append(entry)
	return out


## The arena a press would start on when the player has not chosen: the first one the
## build exposes (`Config.selectable_arenas()` order, `match_config.gd:64-66`).
func _first_selectable_id() -> String:
	for row in _rows:
		var entry: Dictionary = row
		if not bool(entry.get("locked", false)) and not _out_of_matchday.has(String(entry.get("id", ""))):
			return String(entry.get("id", ""))
	return ""


func arena_rows_now() -> Array:
	return _rows.duplicate(true)


func wording_mode() -> String:
	return _wording


func fixture_arena_id() -> String:
	return _in_program


func in_program_id() -> String:
	return _in_program


func out_of_matchday_ids() -> Array:
	return _out_of_matchday.duplicate()


func locked_ids() -> Array:
	return _locked_ids.duplicate()


func selected_arena_id() -> String:
	return _selected_id


## Which of `renderArenas`'s four sentences the card's body carries.
func arena_card_state(arena_id: String) -> String:
	if _locked_ids.has(arena_id):
		return "locked"
	if _out_of_matchday.has(arena_id):
		return "out_of_matchday"
	if arena_id == _in_program:
		return "in_program"
	return "selectable"


func arena_locked_shown(arena_id: String) -> bool:
	var lock := _control(LOCK_PREFIX + arena_id) as Control
	return lock != null and lock.visible


func arena_badge_shown(arena_id: String) -> bool:
	var badge := _control(BADGE_PREFIX + arena_id) as Control
	return badge != null and badge.visible


func arena_line_key(arena_id: String) -> String:
	var row := _row_of(arena_id)
	var demo_locked := bool(row.get("demo_locked", false))
	var unlock: Dictionary = _arena_unlock_of(arena_id)
	if demo_locked:
		return "demoOnlyFull"
	if _locked_ids.has(arena_id):
		if int(unlock.get("trophies", 0)) > 0:
			return "unlockTrophies"
		if int(unlock.get("stars", 0)) > 0:
			return "unlockStars"
		return Gate.locked_key()
	if _out_of_matchday.has(arena_id):
		return "arenaOtherRound" if _wording == WORDING_TOURNAMENT else "arenaOtherMatchday"
	return String(row.get("desc_key", ""))


# ---------------------------------------------------------------------------
# Selection and the preserved start contract


## `ui.selectedArena = arena; onSelect?.(arena)` (`js/ui.js:1264-1265`) — the choice is the
## session's, and the port's seat for it is `Config.arena_index` (`match_config.gd:22-27`).
func select_arena(arena_id: String) -> bool:
	if _row_of(arena_id).is_empty():
		return false
	var state := arena_card_state(arena_id)
	if state == "locked" or state == "out_of_matchday":
		return false
	var index := _arena_index_of(arena_id)
	if index < 0:
		return false
	_selected_id = arena_id
	return true


## Which arena the start will use: the chosen one, or — in career and tournament — the
## calendar's, because `startMatch` uses the fixture and discards the choice
## (`js/ui.js:1227-1230`, `js/main.js`'s guards around `:1545-1583`).
func start_arena_id() -> String:
	if _wording == WORDING_CAREER or _wording == WORDING_TOURNAMENT:
		return _in_program
	return _selected_id


func can_start() -> bool:
	var id := start_arena_id()
	return id != "" and _arena_index_of(id) >= 0


## The payload the router (UIR-22) reads. Keys named and returned, never written into a
## mode rule: `mode` is `Config.pending_mode`'s own value, `arena_index` is
## `Config.arena_index`'s own seat, `scene` is the scene today's call sites change to.
func start_payload() -> Dictionary:
	var id := start_arena_id()
	var mode := _wording
	return {
		"mode": mode,
		"arena_id": id,
		"arena_index": _arena_index_of(id),
		"player_mode": player_mode(),
		"scene": MODE_SCENE if mode != WORDING_QUICK else MATCH_SCENE,
	}


func start_match(apply_scene: bool = true) -> bool:
	if not can_start():
		return false
	var payload := start_payload()
	var index := int(payload["arena_index"])
	if index < 0:
		return false
	Config.arena_index = index
	Config.pending_mode = String(payload["mode"])
	# The reference's own rule (`js/main.js:1156`): the human mode rides only on a
	# quick match; tournament, career and drill are forced back to `"solo"`.
	Config.pending_player_mode = String(payload["player_mode"]) if String(payload["mode"]) == WORDING_QUICK else "solo"
	if apply_scene:
		get_tree().change_scene_to_file(String(payload["scene"]))
	return true


func player_mode() -> String:
	var prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	var mode := String(prefs.get("playerMode", PLAYER_MODES[0]))
	if not PLAYER_MODES.has(mode):
		return PLAYER_MODES[0]
	return mode


func player_mode_visible() -> bool:
	var panel := _control("PlayerModePanel") as Control
	return panel != null and panel.visible


func hint_key() -> String:
	return "pmHint"


func select_player_mode(mode: String) -> bool:
	if not PLAYER_MODES.has(mode):
		return false
	ModesSave.save_pref(Config.save_store(), "playerMode", mode)
	refresh_strings()
	refresh_selection()
	return true


func refresh_selection() -> void:
	var current := player_mode()
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key) as Button
		if button == null:
			continue
		if key == current:
			button.add_theme_stylebox_override("normal", _active_segment_box())
			button.add_theme_stylebox_override("hover", _active_segment_box())
			button.add_theme_stylebox_override("pressed", _active_segment_box())
		else:
			button.add_theme_stylebox_override("normal", _inactive_segment_box())
			button.add_theme_stylebox_override("hover", _inactive_segment_box())
			button.add_theme_stylebox_override("pressed", _inactive_segment_box())


func player_mode_shown(mode: String) -> String:
	return UiStrings.t(MODE_KEYS.get(mode, ""))


# ---------------------------------------------------------------------------
# Capture states


func apply_capture_state(state: String) -> bool:
	if not CAPTURE_STATES.has(state):
		return false
	match state:
		"default":
			_capture_lock_pin = ""
			Config.pending_mode = _capture_entry_mode if _capture_entry_mode != "" else WORDING_QUICK
		"career-calendar":
			_capture_lock_pin = ""
			Config.pending_mode = WORDING_CAREER
		"tournament-bracket":
			_capture_lock_pin = ""
			Config.pending_mode = WORDING_TOURNAMENT
		"demo-locked":
			_capture_lock_pin = "demo"
		"player-mode-coop":
			_capture_lock_pin = ""
			Config.pending_mode = _capture_entry_mode if _capture_entry_mode != "" else WORDING_QUICK
	refresh_data()
	if state == "player-mode-coop":
		select_player_mode("coop")
	return true


# ---------------------------------------------------------------------------
# The grid


func _build_grid() -> void:
	var grid := _control("ArenaGrid") as GridContainer
	if grid == null:
		return
	_clear(grid)
	for row in _rows:
		var entry: Dictionary = row
		var id := String(entry.get("id", ""))
		var state := arena_card_state(id)
		var card := PanelContainer.new()
		card.name = CARD_PREFIX + id
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.theme_type_variation = &""
		# The reference paints exactly three card states — locked, out of the matchday, in
		# program (`js/ui.js:1238-1243`) — and no "chosen" one: the choice is the session's,
		# not the card's.
		card.add_theme_stylebox_override("panel", _card_box())
		if state == "in_program":
			card.add_theme_stylebox_override("panel", _selected_box())
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.name = card.name + "Column"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		card.add_child(column)

		# `.arena-card__preview` (`styles.css:508-522`): the art with the accent it carries.
		var preview := PanelContainer.new()
		preview.name = ART_PREFIX + id
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_theme_stylebox_override("panel", _preview_box(String(entry.get("accent", ""))))
		column.add_child(preview)
		var art := TextureRect.new()
		art.name = preview.name + "Texture"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art_path := String(entry.get("art_path", ""))
		var texture: Texture2D = load(art_path) if art_path != "" else null
		if texture != null:
			art.texture = texture
		preview.add_child(art)
		_place_overlay(art, LOCK_PREFIX + id, LockBadge.new(), state == "locked")
		var badge := Label.new()
		_place_overlay(art, BADGE_PREFIX + id, badge, state == "in_program")
		_bind(badge, "arenaByBracket" if _wording == WORDING_TOURNAMENT else "arenaByCalendar")

		var body := MarginContainer.new()
		body.name = card.name + "Body"
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := int(CARD_PADDING)
		body.add_theme_constant_override("margin_left", pad)
		body.add_theme_constant_override("margin_right", pad)
		body.add_theme_constant_override("margin_top", pad)
		body.add_theme_constant_override("margin_bottom", pad)
		column.add_child(body)
		var stack := VBoxContainer.new()
		stack.name = card.name + "Stack"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 4)
		body.add_child(stack)

		var name_label := Label.new()
		name_label.name = NAME_PREFIX + id
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.theme_type_variation = &"CardTitle"
		stack.add_child(name_label)
		_bind(name_label, String(entry.get("name_key", "")))

		var line := Label.new()
		line.name = LINE_PREFIX + id
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.theme_type_variation = &"CardBody"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(line)
		_bind(line, arena_line_key(id))

		# A switched-off card is a card the reference hands to `card.disabled`
		# (`js/ui.js:1263-1271`), never a card that quietly does nothing.
		card.modulate = Color(1, 1, 1, 0.55) if state == "out_of_matchday" else Color(1, 1, 1, 1)
		if state != "out_of_matchday":
			card.gui_input.connect(_on_card_input.bind(id))


func _on_card_input(event: InputEvent, arena_id: String) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		select_arena(arena_id)


func _place_overlay(host: Control, overlay_name: String, overlay: Control, visible_now: bool) -> void:
	overlay.name = overlay_name
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = visible_now
	if overlay is Label:
		(overlay as Label).theme_type_variation = &"Tag"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)


## `.arena-card__preview`'s height: the art keeps its own ratio, floored so a narrow
## column cannot collapse it.
func _update_preview_heights() -> void:
	var grid := _control("ArenaGrid") as GridContainer
	if grid == null:
		return
	var columns := _column_count()
	var width := grid.size.x
	if width <= 0.0:
		return
	# The column the viewport rules give this card, floored so a narrow column cannot
	# collapse the preview.
	var column_width := (width - float(columns - 1) * float(_grid_separation())) / float(columns)
	for row in _rows:
		var id := String((row as Dictionary).get("id", ""))
		var preview := _control(ART_PREFIX + id) as Control
		if preview == null:
			continue
		var card := _control(CARD_PREFIX + id) as Control
		var basis := card.size.x if card != null and card.size.x > 1.0 else column_width
		preview.custom_minimum_size.y = maxf(PREVIEW_MIN_HEIGHT, basis / PREVIEW_RATIO)


# ---------------------------------------------------------------------------
# The player-mode panel


func _build_player_mode() -> void:
	var panel := _control("PlayerModePanel") as Control
	if panel == null:
		return
	# `js/main.js:1656`: `playerModeSetup.hidden = ui.selectedMode !== "quick"` — the panel
	# is the quick match's, and it is the same rule the modes screen's setup obeys.
	panel.visible = _wording == WORDING_QUICK
	var label := _control("PlayerModeLabel") as Label
	if label != null:
		_bind(label, "playerMode")
	var hint := _control("PlayerModeHint") as Label
	if hint != null:
		_bind(hint, hint_key())
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key) as Button
		if button != null:
			_bind(button, String(MODE_KEYS[key]))
	refresh_selection()


# ---------------------------------------------------------------------------
# Chrome (theme tokens only)


func _style_chrome() -> void:
	var panel := _control("PlayerModePanel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", _setup_box())


func _theme_box(variation: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	if theme == null:
		return StyleBoxFlat.new()
	var box: StyleBox = theme.get_stylebox("panel", variation)
	if box == null:
		push_error("ArenaScreen: the theme has no '%s' box" % variation)
		return StyleBoxFlat.new()
	var out := (box as StyleBoxFlat).duplicate()
	# The preview bleeds to the card's edges (`styles.css:508-522`): the frame gives up
	# its padding and the body below carries it.
	out.content_margin_left = 0.0
	out.content_margin_top = 0.0
	out.content_margin_right = 0.0
	out.content_margin_bottom = 0.0
	return out


func _card_box() -> StyleBoxFlat:
	return _theme_box("PanelDark")


func _selected_box() -> StyleBoxFlat:
	return _theme_box("PanelCardSelected")


func _setup_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	if theme == null:
		return StyleBoxFlat.new()
	var box := _theme_box("PanelDark")
	if theme.has_color("line", "Palette"):
		box.border_color = theme.get_color("line", "Palette")
	return box


func _preview_box(accent_hex: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	if theme != null and theme.has_color("panel", "Palette"):
		box.bg_color = theme.get_color("panel", "Palette")
	box.set_corner_radius_all(12)
	if accent_hex != "":
		var accent := Color.from_string(accent_hex, Color.WHITE)
		box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
		box.border_width_bottom = 2
	return box


func _active_segment_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	# A `StyleBoxFlat` starts at `bg_color = Color(0.6, 0.6, 0.6)` with `draw_center` on,
	# so a segment that only wants a bottom border must clear the fill or it paints an
	# opaque grey slab (`styles.css` .segmented button: background none).
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	if theme != null and theme.has_color("cyan", "Palette"):
		box.border_color = theme.get_color("cyan", "Palette")
	box.set_corner_radius_all(8)
	box.border_width_bottom = 2
	return box


func _inactive_segment_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	if theme != null and theme.has_color("line", "Palette"):
		box.border_color = theme.get_color("line", "Palette")
	box.set_corner_radius_all(8)
	box.border_width_bottom = 1
	return box


## `lockLabel(arena.unlock)`'s own field (`js/ui.js:414-417`): the frozen table carries no
## `unlock` on any arena today, so this reads it rather than assuming its absence.
func _arena_unlock_of(arena_id: String) -> Dictionary:
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		if String(entry.get("id", "")) == arena_id and entry.get("unlock") is Dictionary:
			return entry["unlock"]
	return {}


func _accent_of(arena_id: String) -> String:
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		if String(entry.get("id", "")) == arena_id:
			var palette: Dictionary = entry.get("palette", {}) if entry.get("palette") is Dictionary else {}
			return String(palette.get("accent", ""))
	return ""


# ---------------------------------------------------------------------------
# Layout


func _column_count() -> int:
	return GRID_COLUMNS if size.x >= GRID_BREAKPOINT else SMALL_COLUMNS


func _grid_separation() -> int:
	var grid := _control("ArenaGrid") as GridContainer
	return grid.get_theme_constant("h_separation") if grid != null else 20


func _apply_layout() -> void:
	var grid := _control("ArenaGrid") as GridContainer
	if grid != null:
		grid.columns = _column_count()
	_update_preview_heights()


# ---------------------------------------------------------------------------
# Strings


func refresh_strings() -> void:
	for row in _bindings:
		var entry: Dictionary = row
		var node: Control = _text_nodes.get(String(entry.get("name", "")), null)
		if node == null:
			continue
		_set_node_text(node, _resolve_entry(entry))
	_apply_accessibility()


func _resolve_entry(entry: Dictionary) -> String:
	var text := String(entry.get("prefix", "")) + UiStrings.t(String(entry.get("key", "")), entry.get("params", {}))
	if String(entry.get("suffix_key", "")) != "":
		text += String(entry.get("joiner", "")) + UiStrings.t(String(entry["suffix_key"]), entry.get("suffix_params", {}))
	return text


func _set_node_text(node: Control, text: String) -> void:
	if node is Label:
		(node as Label).text = text
	elif node is Button:
		(node as Button).text = text


func _bind(control: Control, key: String, params: Dictionary = {}, joiner: String = "",
		suffix_key: String = "", suffix_params: Dictionary = {}, prefix: String = "") -> void:
	_register_text_node(control)
	_bindings.append({
		"name": control.name,
		"key": key,
		"params": params,
		"prefix": prefix,
		"joiner": joiner,
		"suffix_key": suffix_key,
		"suffix_params": suffix_params,
	})
	_set_node_text(control, _resolve_entry(_bindings[_bindings.size() - 1]))


func _register_text_node(control: Control) -> void:
	_text_nodes[control.name] = control


func text_bindings() -> Array:
	return _bindings.duplicate(true)


func text_shown(node_name: String) -> String:
	var node: Control = _text_nodes.get(node_name, null)
	if node == null:
		return ""
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return ""


# ---------------------------------------------------------------------------
# Focus and accessibility


func focus_controls() -> Array:
	return _focus_specs.duplicate(true)


func _apply_accessibility() -> void:
	_focus_specs = []
	var back := _control("BackButton")
	if back != null:
		_focus_specs.append(_focus_spec("BackButton", back, "back"))
	for row in _rows:
		var card := _control(CARD_PREFIX + String((row as Dictionary).get("id", "")))
		if card != null:
			_focus_specs.append(_focus_spec(CARD_PREFIX + String((row as Dictionary).get("id", "")), card,
				"activate:" + CARD_PREFIX + String((row as Dictionary).get("id", ""))))
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key)
		if button != null:
			_focus_specs.append(_focus_spec(MODE_PREFIX + key, button, "player-mode:" + key))


## UIR-05's bridge reads these shapes: the id it can focus, the node it moves the focus to,
## the reference's own action name, and the model's options (`game/menu_focus.gd:60-77`).
func _focus_spec(node_name: String, control: Control, action: String) -> Dictionary:
	return {
		"id": "%s/%s" % [SCREEN_ID, node_name],
		"node": control,
		"action": action,
		"opts": {"kind": "card" if control is PanelContainer else "button"},
	}


func aria_names() -> Dictionary:
	var out := {}
	var back := _control("BackButton") as Button
	if back != null:
		out["BackButton"] = back.text
	return out


# ---------------------------------------------------------------------------
# Small helpers


func _control(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control


func _row_of(arena_id: String) -> Dictionary:
	for row in _rows:
		if String((row as Dictionary).get("id", "")) == arena_id:
			return row
	return {}


func _arena_index_of(arena_id: String) -> int:
	var index := 0
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		if String(entry.get("id", "")) == arena_id:
			return index
		index += 1
	return -1


func _clear(container: Node) -> void:
	_bindings.clear()
	_text_nodes.clear()
	_focus_specs.clear()
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## The lock badge is the reference's own `🔒` (`js/ui.js:1249`), from its code point.
class LockBadge:
	extends Label

	func _init() -> void:
		text = String.chr(0x1f512)
		horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vertical_alignment = VERTICAL_ALIGNMENT_TOP
