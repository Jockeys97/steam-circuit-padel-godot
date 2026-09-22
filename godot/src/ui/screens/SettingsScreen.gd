## SettingsScreen.gd — `screen-settings`, the reference's own page (`index.html:398-441`).
##
## WHAT THIS SCREEN IS. Three groups, exactly as the markup has them: the language
## segmented control, the accessibility toggles (reduce motion, colour-blind) and the
## audio/controller group (volume, deadzone, vibration). Values come from the save
## contract's own reader — `UiData.settings_snapshot()` — and every change goes back
## through `ModesSave.save_pref()`, the module the rest of the port already reads
## (`Config.control_mode()` reads the same group). No new storage, no second table of
## defaults: the bounds are the reference's own markup attributes
## (`index.html:433`, `:437`) and the labels are message ids.
##
## APPLIED IMMEDIATELY, the reference's own semantics:
##   - the language switches the session locale and re-resolves every string here
##     (`js/main.js:2421`);
##   - reduce motion and colour-blind drive this screen's `AccessibilitySettings`
##     object (`godot/src/accessibility/accessibility_settings.gd`), read through
##     `UiMotionPolicy`, so a UI effect asking the policy follows the toggle at once
##     (`js/ui.js:471-473`);
##   - volume and deadzone are persisted through the same contract; their consumers
##     live outside the UI lane (`js/audio.js` `setVolume`, `js/main.js:2529` for the
##     deadzone) and the hand-back names the port's call sites for the integrator,
##     because the port reads neither pref anywhere yet.
##
## PERSISTENCE IS PER-KEY. `ModesSave.save_pref(store, key, value)` is read-modify-write
## over the `prefs` group, so this screen cannot drop a key another lane wrote
## (`controlMode`, `tournamentRound`, the lineup). The stored keys are the reference's
## camelCase ones (`volume`, `gamepadDeadzone`, `vibration`, `reduceMotion`,
## `colorblind`, `lang`), the same ones `UiData.settings_snapshot()` reads back.
##
## THE ROWS ARE SHARED. `godot/src/ui/components/SettingsRows.gd` builds them, because
## the pause overlay's controller tab (UIR-20) repeats the same two rows in the
## reference and both copies read one state (`js/main.js:2455-2470`).
##
## THE THEME GAP THIS FILE CARRIES. The theme (UIR-02) has the segmented styleboxes and
## the type roles used here, but no variation for the settings group's own title line;
## `_style_group_titles()` composes it from `Palette`, and `godot/src/ui/theme/README.md`
## §7 carries the follow-up. No literal colour, size or sentence lives in this file.
##
## CAPTURE STATES. One: `default`. The reference has no alternate settings page; the
## language flip and the row values are asserted by the audit, not pinned into states.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Schema := preload("res://src/save/save_schema.gd")
const Config := preload("res://game/match_config.gd")
const Rows := preload("res://src/ui/components/SettingsRows.gd")
const Pace := preload("res://src/sim/pace.gd")
const AccessibilitySettings := preload("res://src/accessibility/accessibility_settings.gd")
const UiMotionPolicy := preload("res://src/ui/accessibility/UiMotionPolicy.gd")

const SCREEN_ID := "settings"

## The router's own row for this screen (`ScreenRouter.SCREENS[10]`).
const DECLARED_BACK := "menu"

const CAPTURE_STATES: Array[String] = ["default"]

## `index.html:410-413`: the toggle's two values, in the reference's own order.
const LANGS: Array[String] = ["it", "en"]

## PORT ADDITION: the stored key of the game-pace preset. The ladder, its factors
## and its text are `src/sim/pace.gd`'s; this screen only shows them and writes the
## chosen id through the same save door every other row uses.
const PACE_KEY := "pacePreset"
## The pace group's own title, taken from the pace module rather than from
## `TEXT_SLOTS`: `locale_data.gd` is generated from the frozen `js/i18n.js` and its
## verifier rejects any key the reference does not carry, so a port addition brings
## its own strings.
const PACE_TITLE_KEY := "pacePreset"

## `index.html:433`: `min=0 max=1 step=0.01`.
const VOLUME_MIN := 0.0
const VOLUME_MAX := 1.0
const VOLUME_STEP := 0.01
## `index.html:437`: `min=0.08 max=0.30 step=0.01`.
const DEADZONE_MIN := 0.08
const DEADZONE_MAX := 0.30
const DEADZONE_STEP := 0.01

## The group titles: node name -> locale id (`index.html:411`, `:421`, `:428`).
const TEXT_SLOTS := {
	"LanguageTitle": "language",
	"AccessibilityTitle": "accessibility",
	"AudioTitle": "audioSettings",
}

## The row keys, by node name. One place, so the screen, the audit and the rows agree.
const ROW_KEYS := {
	"ReduceMotionRow": "reduceMotion",
	"ColorblindRow": "colorblind",
	"VolumeRow": "volume",
	"DeadzoneRow": "gamepadDeadzone",
	"VibrationRow": "vibration",
}

## `.settings-grid` (`styles.css:2730`) is `auto-fit minmax(240px, 1fr)`: three columns
## at the design frame, one when the frame cannot hold two.
const GRID_MIN_CELL := 240.0
const GRID_COLUMNS := 3
## The screen's own reading column, matching the reference's content width.
const MAX_COLUMN := 980.0

var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted = null
var _built := false
## Re-entrancy guard for the `resized` handler: writing theme-constant overrides from
## inside the layout pass can re-enter synchronously; unguarded it is a stack overflow
## (proven in-engine on DrillScreen, which shares this exact code shape).
var _applying_width := false
var _grid: GridContainer = null
var _rows: Dictionary = {}
var _lang_buttons: Dictionary = {}
var _pace_buttons: Dictionary = {}
var _pace_blurb: Label = null
var _access: AccessibilitySettings = null
var _motion: UiMotionPolicy = null
var _content_root: Control = null


func _ready() -> void:
	_ensure()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


func enter(payload: Dictionary) -> void:
	_ensure()
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", DECLARED_BACK))
	_shell.set_back_target(back_target_id)
	refresh_values()
	refresh_strings()


func exit() -> void:
	pass


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## The reference has no second settings page: only `default` applies, and anything else
## answers false so a harness records "not declared" instead of guessing.
func apply_capture_state(state_id: String) -> bool:
	if state_id != "default":
		return false
	refresh_values()
	refresh_strings()
	return true


# ---------------------------------------------------------------------------
# The save contract
# ---------------------------------------------------------------------------

## The store every read and write goes through: the caller's (an audit's temp
## directory) or the game's own (`match_config.gd::save_store()`).
func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


func set_store(store_in: RefCounted) -> void:
	_store = store_in
	if _built:
		refresh_values()


## What the screen renders: `UiData.settings_snapshot()` — the stored `prefs` group over
## the save schema's defaults, presentation-free.
func snapshot() -> Dictionary:
	return UiData.settings_snapshot(store())


func _persist(key: String, value: Variant) -> Dictionary:
	return ModesSave.save_pref(store(), key, value)


# ---------------------------------------------------------------------------
# The values the screen owns (read-back is the contract; the audit checks both sides)
# ---------------------------------------------------------------------------

func language() -> String:
	var lang := String(snapshot().get("language", Locale.default_lang()))
	return lang if LANGS.has(lang) else Locale.default_lang()


func volume() -> float:
	return float(snapshot().get("volume", Schema.PREFS_DEFAULTS.get("volume", 0.5)))


func volume_text() -> String:
	return str(roundi(volume() * 100.0)) + Rows.PERCENT_SIGN


func deadzone() -> float:
	return float(snapshot().get("deadzone", Schema.PREFS_DEFAULTS.get("gamepadDeadzone", 0.15)))


func deadzone_text() -> String:
	return str(roundi(deadzone() * 100.0)) + Rows.PERCENT_SIGN


func vibration() -> bool:
	return bool(snapshot().get("vibration", true))


func reduce_motion() -> bool:
	return bool(snapshot().get("reduce_motion", false))


func colorblind() -> bool:
	return bool(snapshot().get("colorblind", false))


## The stored game-pace preset, validated against the ladder. Same shape as
## `language()` above: an unknown id reads back as the module's own default.
func pace() -> String:
	var id := String(snapshot().get("pace_preset", Pace.default_id()))
	return id if Pace.has(id) else Pace.default_id()


## The accessibility object this screen owns, fed from the stored prefs and read by
## `motion_policy()`. A UI effect that asks the policy sees a toggle immediately.
func accessibility() -> AccessibilitySettings:
	_ensure()
	return _access


func motion_policy() -> UiMotionPolicy:
	_ensure()
	return _motion


## Whether the colour-blind treatment is on, as the effects layer reads it
## (`accessibility_settings.gd::is_colorblind`). The full FX treatment is that module's;
## this screen persists and reflects the flag.
func colorblind_applied() -> bool:
	return motion_policy().colorblind()


# ---------------------------------------------------------------------------
# The changes
# ---------------------------------------------------------------------------

func set_language(lang: String) -> bool:
	if not LANGS.has(lang):
		return false
	_persist("lang", lang)
	Locale.set_lang(lang)
	refresh_strings()
	return true


## Picks a pace preset. Refused for an id outside the ladder, exactly as
## `set_language` refuses a locale the port does not carry.
func set_pace(id: String) -> bool:
	if not Pace.has(id):
		return false
	_persist(PACE_KEY, id)
	_refresh_pace()
	return true


func set_volume(raw: float) -> Dictionary:
	var value := clampf(raw, VOLUME_MIN, VOLUME_MAX)
	_rows_set("VolumeRow", value)
	return _persist("volume", value)


func set_deadzone(raw: float) -> Dictionary:
	var value := clampf(raw, DEADZONE_MIN, DEADZONE_MAX)
	_rows_set("DeadzoneRow", value)
	return _persist("gamepadDeadzone", value)


func set_vibration(on: bool) -> Dictionary:
	_rows_set("VibrationRow", on)
	return _persist("vibration", on)


func set_reduce_motion(on: bool) -> Dictionary:
	_rows_set("ReduceMotionRow", on)
	_access.set_enabled(AccessibilitySettings.REDUCE_MOTION, on)
	return _persist("reduceMotion", on)


func set_colorblind(on: bool) -> Dictionary:
	_rows_set("ColorblindRow", on)
	_access.set_enabled(AccessibilitySettings.COLORBLIND, on)
	return _persist("colorblind", on)


## Pushes one stored value onto its row. The rows' own signals are what a player's
## press emits; these are reads, so nothing re-persists what was just read.
func _rows_set(row_name: String, value: Variant) -> void:
	var row: Control = _rows.get(row_name, null)
	if row == null:
		return
	if row is Rows.RangeRow:
		(row as Rows.RangeRow).set_value(float(value))
	elif row is Rows.ToggleRow:
		(row as Rows.ToggleRow).set_on(bool(value))


func _store_row(row_name: String, control: Control) -> void:
	_rows[row_name] = control


## The rows, by node name — UIR-20 (the pause overlay's controller tab) reads the same
## contract from the reference, and the audit checks the signals through this door.
func rows() -> Dictionary:
	return _rows


func set_row_value(row_name: String, value: Variant) -> bool:
	if not _rows.has(row_name):
		return false
	_rows_set(row_name, value)
	return true


# ---------------------------------------------------------------------------
# Strings and values
# ---------------------------------------------------------------------------

## Re-resolves every string: the three group titles, the two language buttons, the rows
## and the shell's own header.
func refresh_strings() -> void:
	_ensure()
	_shell.set_title("settingsTitle")
	_shell.set_subtitle("settingsSub")
	for node_name in TEXT_SLOTS:
		var label := _control(String(node_name)) as Label
		if label != null:
			label.text = UiStrings.t(String(TEXT_SLOTS[node_name]))
	for row_name in _rows:
		Rows.refresh_strings(_rows[row_name])
	_refresh_language_buttons()
	_refresh_pace()


## Every stored value onto its row. Called on `enter()` — the reference syncs the whole
## page on `to-settings` (`js/main.js:2227-2230`) — and by the capture path.
func refresh_values() -> void:
	_ensure()
	var snap := snapshot()
	_rows_set("ReduceMotionRow", snap.get("reduce_motion", false))
	_rows_set("ColorblindRow", snap.get("colorblind", false))
	_rows_set("VolumeRow", snap.get("volume", 0.5))
	_rows_set("DeadzoneRow", snap.get("deadzone", 0.15))
	_rows_set("VibrationRow", snap.get("vibration", true))
	_access.apply_prefs(_stored_prefs())
	_refresh_language_buttons()
	_refresh_pace()
	_apply_grid_columns()


func _stored_prefs() -> Dictionary:
	var profile := ModesSave.profile(store())
	var prefs: Variant = profile.get("prefs", null)
	return prefs if prefs is Dictionary else {}


func _refresh_language_buttons() -> void:
	var current := language()
	for lang in _lang_buttons:
		var button := _lang_buttons[lang] as Button
		var active: bool = String(lang) == current
		_style_segment(button, active)


## The pace group's three moving parts: the selected rung, every button's label and
## the blurb under them. All three follow the locale, so this runs on a flip too.
func _refresh_pace() -> void:
	var lang := Locale.current_lang()
	var current := pace()
	for id in _pace_buttons:
		var button := _pace_buttons[id] as Button
		var preset: Dictionary = Pace.preset(String(id))
		button.text = Pace.text(String(preset["label_key"]), lang)
		_style_segment(button, String(id) == current)
	var title := _control("PaceTitle") as Label
	if title != null:
		title.text = Pace.text(PACE_TITLE_KEY, lang)
	if _pace_blurb != null:
		_pace_blurb.text = Pace.text(String(Pace.preset(current)["blurb_key"]), lang)


# ---------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_shell = $Shell
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(DECLARED_BACK)
	_access = AccessibilitySettings.new()
	_motion = UiMotionPolicy.new(_access)
	_build()


func _build() -> void:
	_content_root = _centered_column(MAX_COLUMN)
	_grid = GridContainer.new()
	_grid.name = "SettingsGrid"
	_grid.columns = GRID_COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_child(_grid)
	_grid.add_child(_group("LanguageGroup", "LanguageTitle", _language_body()))
	_grid.add_child(_group("AccessibilityGroup", "AccessibilityTitle", _accessibility_body()))
	_grid.add_child(_group("AudioGroup", "AudioTitle", _audio_body()))
	_grid.add_child(_group("PaceGroup", "PaceTitle", _pace_body()))
	_register_focus()
	resized.connect(_apply_grid_columns)
	refresh_values()
	refresh_strings()


## The shell's content region, wrapped in a `MarginContainer` whose side margins centre
## a `MAX_COLUMN`-wide reading column: the reference's `max-width` on a page that must
## also survive a 1024-wide frame (the margins go to zero before anything overflows).
func _centered_column(max_width: float) -> VBoxContainer:
	var content: MarginContainer = _shell.content()
	var centering := MarginContainer.new()
	centering.name = "Centering"
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centering.set_meta("max_width", max_width)
	content.add_child(centering)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 22)
	centering.add_child(column)
	centering.resized.connect(_apply_column_width.bind(centering, column))
	_apply_column_width(centering, column)
	return column


func _apply_column_width(centering: MarginContainer, column: VBoxContainer) -> void:
	if _applying_width:
		return
	_applying_width = true
	var max_width := float(centering.get_meta("max_width", 0.0))
	# The column centres itself (`SIZE_SHRINK_CENTER`) instead of the centering carrying
	# side margins: margins are part of a container's own minimum size, so a width the
	# screen once had could never be given back and the shell stayed wider than its frame.
	var available := centering.get_parent_area_size().x
	var want_min := minf(max_width, available)
	if not is_equal_approx(column.custom_minimum_size.x, want_min):
		column.custom_minimum_size.x = want_min
	_applying_width = false


func _group(node_name: String, title_node: String, body: Control) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = node_name
	group.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.name = title_node
	title.theme_type_variation = &"LabelSmall"
	group.add_child(title)
	group.add_child(body)
	return group


func _language_body() -> Control:
	var box := PanelContainer.new()
	box.name = "LanguageBox"
	box.theme_type_variation = &"SegmentedContainer"
	var seg := HBoxContainer.new()
	seg.name = "LanguageSeg"
	seg.add_theme_constant_override("separation", 0)
	box.add_child(seg)
	for lang in LANGS:
		var button := Button.new()
		button.name = "Lang_%s" % lang
		button.text = lang.to_upper()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 36.0)
		button.pressed.connect(set_language.bind(lang))
		seg.add_child(button)
		_lang_buttons[lang] = button
	return box


## The game-pace group: one segmented rung per preset plus the blurb of the chosen
## one. Built here, the way the difficulty rungs are built in `ModesScreen`, rather
## than through `SettingsRows`: that component's two kinds are the reference's range
## and toggle, and a rung group is neither.
func _pace_body() -> Control:
	var column := VBoxContainer.new()
	column.name = "PaceRows"
	column.add_theme_constant_override("separation", 8)
	var seg := VBoxContainer.new()
	seg.name = "PaceSeg"
	seg.add_theme_constant_override("separation", 0)
	for id in Pace.ids():
		var button := Button.new()
		button.name = "Pace_%s" % id
		button.toggle_mode = true
		button.pressed.connect(set_pace.bind(String(id)))
		seg.add_child(button)
		_pace_buttons[String(id)] = button
	column.add_child(seg)
	_pace_blurb = Label.new()
	_pace_blurb.name = "PaceBlurb"
	_pace_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pace_blurb.add_theme_font_size_override("font_size", Rows.TITLE_SIZE)
	_pace_blurb.modulate.a = Rows.LABEL_ALPHA
	column.add_child(_pace_blurb)
	return column


func _accessibility_body() -> Control:
	var column := VBoxContainer.new()
	column.name = "AccessibilityRows"
	column.add_theme_constant_override("separation", 8)
	var snap := snapshot()
	_add_row(column, Rows.make_toggle("reduceMotion", bool(snap.get("reduce_motion", false)), "ReduceMotionRow"))
	_add_row(column, Rows.make_toggle("colorblind", bool(snap.get("colorblind", false)), "ColorblindRow"))
	(_rows["ReduceMotionRow"] as Rows.ToggleRow).changed.connect(_on_reduce_motion)
	(_rows["ColorblindRow"] as Rows.ToggleRow).changed.connect(_on_colorblind)
	return column


func _audio_body() -> Control:
	var column := VBoxContainer.new()
	column.name = "AudioRows"
	column.add_theme_constant_override("separation", 12)
	var snap := snapshot()
	_add_row(column, Rows.make_range("volume", VOLUME_MIN, VOLUME_MAX, VOLUME_STEP, float(snap.get("volume", 0.5)), "VolumeRow"))
	_add_row(column, Rows.make_range("deadzone", DEADZONE_MIN, DEADZONE_MAX, DEADZONE_STEP, float(snap.get("deadzone", 0.15)), "DeadzoneRow"))
	_add_row(column, Rows.make_toggle("vibration", bool(snap.get("vibration", true)), "VibrationRow"))
	(_rows["VolumeRow"] as Rows.RangeRow).changed.connect(_on_volume)
	(_rows["DeadzoneRow"] as Rows.RangeRow).changed.connect(_on_deadzone)
	(_rows["VibrationRow"] as Rows.ToggleRow).changed.connect(_on_vibration)
	return column


func _add_row(parent: Control, row: Control) -> void:
	parent.add_child(row)
	_store_row(row.name, row)


## A player's own change: the row already moved itself, so only the store is written.
func _on_volume(raw: float) -> void:
	_persist("volume", clampf(raw, VOLUME_MIN, VOLUME_MAX))


func _on_deadzone(raw: float) -> void:
	_persist("gamepadDeadzone", clampf(raw, DEADZONE_MIN, DEADZONE_MAX))


func _on_vibration(on: bool) -> void:
	_persist("vibration", on)


func _on_reduce_motion(on: bool) -> void:
	_access.set_enabled(AccessibilitySettings.REDUCE_MOTION, on)
	_persist("reduceMotion", on)


func _on_colorblind(on: bool) -> void:
	_access.set_enabled(AccessibilitySettings.COLORBLIND, on)
	_persist("colorblind", on)


## `.settings-grid`'s `auto-fit`: as many 240 px cells as the frame holds, up to three.
func _apply_grid_columns() -> void:
	if _grid == null:
		return
	var width := size.x
	if width <= 0.0:
		width = 1280.0
	_grid.columns = maxi(1, mini(GRID_COLUMNS, int(width / GRID_MIN_CELL)))


## The segmented look: the theme's own two styleboxes, swapped on the active one
## (`styles.css` `.segmented button` / `.is-active`, already in the theme as
## `SegmentedInactive`/`SegmentedActive`).
func _style_segment(button: Button, active: bool) -> void:
	if button == null:
		return
	button.set_pressed_no_signal(active)
	var variation := "SegmentedActive" if active else "SegmentedInactive"
	var theme: Theme = self.theme
	if theme == null:
		return
	button.add_theme_stylebox_override("normal", theme.get_stylebox("normal", variation))
	button.add_theme_stylebox_override("hover", theme.get_stylebox("hover", variation))
	button.add_theme_stylebox_override("pressed", theme.get_stylebox("pressed", variation))
	button.add_theme_stylebox_override("focus", theme.get_stylebox("normal", variation))
	button.add_theme_font_override("font", theme.get_font("font", variation))
	button.add_theme_font_size_override("font_size", theme.get_font_size("font_size", variation))
	for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(String(slot), theme.get_color(String(slot), variation))


# ---------------------------------------------------------------------------
# Focus (UIR-05's bridge consumes these; the screen only names its controls)
# ---------------------------------------------------------------------------

func _register_focus() -> void:
	for lang in _lang_buttons:
		_shell.add_focus("Lang_%s" % lang, _lang_buttons[lang], "lang:%s" % lang, {"kind": "button"})
	for id in _pace_buttons:
		_shell.add_focus("Pace_%s" % id, _pace_buttons[id], "pace:%s" % id, {"kind": "button"})
	for row_name in _rows:
		var row: Control = _rows[row_name]
		var opts := {"kind": Rows.focus_kind(row)}
		# UIR-22: the range rows carry their own numbers (`UiFocusBridge.CARRIED_KEYS`).
		# The focus model's projection drops min/max/step/value (`menu_focus._target`),
		# so without these the a keyboard/pad step would move a copy built from the
		# model's defaults instead of the row the player is looking at.
		if Rows.focus_kind(row) == "range":
			var slider := Rows.focus_node(row) as Range
			opts["min"] = slider.min_value
			opts["max"] = slider.max_value
			opts["step"] = slider.step
			opts["value"] = slider.value
		_shell.add_focus(row_name, Rows.focus_node(row), row_name, opts)


## The shell's own controls plus this screen's, in one list — what the bridge reads.
func focus_controls() -> Array:
	_ensure()
	return _shell.focus_controls()


func focus_id(suffix: String) -> String:
	_ensure()
	return _shell.focus_id(suffix)


func _control(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control
