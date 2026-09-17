## HelpScreen.gd — UIR-13: the reference's `#screen-help` (`index.html:181-273`).
##
## THE REFERENCE SHAPE. A two-column layout (`.help-layout`, `styles.css:2407-2415`):
## the left column is the eight rule cards (`.help-sections`, eight `article.help-card`
## pairs of `h3`/`p`, `index.html:194-221`); the right column (`aside.help-controls`,
## `index.html:222-272`) carries the input tabs — Tastiera (keyboard, active by
## default) and Controller — over their two panels: the keyboard guide
## (`.kbd-guide`, seven rows, `index.html:233-240`) and, on the controller tab, the
## controller artwork plus the thirteen-row legend (`index.html:243-257`), which is
## UIR-13's `ControlLegend` component.
##
## WHAT THIS SCREEN DOES NOT DO. It renders no number, no save and no gate: the page
## is prose and input inventory, and both come from tables that already exist
## (`js/i18n.js` through `UiStrings`, `godot/src/input/scheme.gd` through the legend
## component). It reads nothing from the store.
##
## THE TWO DECISIONS THAT ARE THE REFERENCE'S OWN, RESTATED HERE SO A READER DOES NOT
## HAVE TO TRUST A LAYOUT:
##
##   * the keyboard guide's caps are the reference's markup, cap by cap
##     (`index.html:234-238`: W A S D | Space | ⌘ | A D ← → | Option | Z | Esc). The
##     input lane's own `KEYBOARD_LEGEND` (`godot/src/input/strings.gd`) carries the
##     same seven labels but keeps each row's keys as ONE string ("WASD") because it is
##     the inventory of the pause HUD, not of this markup; this screen renders the caps
##     the reference shows and the audit asserts the two inventories agree on the
##     labels, in order.
##   * the controller tab's legend is `ControlLegend.reference_rows()`, filled with
##     `help-controller-legend`'s own overrides: one column and 48 px rows
##     (`styles.css:2482-2489`).
##
## THE RESPONSIVE RULE (`styles.css:2775-2800`): the two columns collapse to one below
## 860 px; the cards collapse to one column below 560 px. Both are frame-width driven,
## like the media queries they come from.
##
## NODE NAMES the audit and UIR-22's mount address by name are the constants below.
## STATIC CHECKS ONLY in this wave: nothing here has run in an engine (recorded in
## `evidence/uir-13-screen-help.log`).
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const InputStrings := preload("res://src/input/strings.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
## The box that paints and stacks (`PanelContainer` + `VBoxContainer` in one node): the
## reference's help cards are one element each, and `HelpCard0/Title` is read from the card.
const BoxColumn := preload("res://src/ui/components/BoxColumn.gd")
## The scene mounts the theme; this is the fallback for a bare `new()` (Hud.gd's shape).
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")
const LegendScene := preload("res://src/ui/components/ControlLegend.tscn")
const LegendClass := preload("res://src/ui/components/ControlLegend.gd")

const SCREEN_ID := "help"
const TITLE_KEY := "helpTitle"
const SUBTITLE_KEY := "helpIntro"
const ARIA_KEY := "ariaHelp"
const BACK_TARGET_ID := "menu"

## The two views the tabs switch between (`js/main.js:2325-2360`).
const VIEW_KEYBOARD := "keyboard"
const VIEW_CONTROLLER := "controller"

## The eight cards in the reference's order (`index.html:194-221`): title key, body
## key, and whether the reference marks the card `help-card--academy`.
const CARDS: Array = [
	{"title_key": "helpObj", "body_key": "helpObjDesc", "academy": false},
	{"title_key": "helpCharge", "body_key": "helpChargeDesc", "academy": false},
	{"title_key": "helpAcademy", "body_key": "helpAcademyDesc", "academy": true},
	{"title_key": "helpSlice", "body_key": "helpSliceDesc", "academy": false},
	{"title_key": "helpSpecial", "body_key": "helpSpecialDesc", "academy": false},
	{"title_key": "helpSwitch", "body_key": "helpSwitchDesc", "academy": false},
	{"title_key": "helpServe", "body_key": "helpServeDesc", "academy": false},
	{"title_key": "helpScore", "body_key": "helpScoreDesc", "academy": false},
]

## The keyboard guide's rows, cap by cap (`index.html:234-238`), with the label id the
## input lane's `KEYBOARD_LEGEND` carries for the same row. The caps are reference
## content and are reproduced verbatim.
const KEYBOARD_ROWS: Array = [
	{"caps": ["W", "A", "S", "D"], "label_id": "moveNet"},
	{"caps": ["Space"], "label_id": "chargeShot"},
	{"caps": ["⌘"], "label_id": "chargeSlice"},
	{"caps": ["A", "D", "←", "→"], "label_id": "aimWhile"},
	{"caps": ["Option"], "label_id": "specialBtn"},
	{"caps": ["Z"], "label_id": "switchBtn"},
	{"caps": ["Esc"], "label_id": "pauseBtn"},
]

## The two capture states (`UIR-13` DoD): the keyboard tab is the default view.
const CAPTURE_STATE_LIST: Array[String] = ["keyboard-tab", "controller-tab"]

## `styles.css:2775-2800`: 860 px collapses the two columns, 560 px the cards.
const NARROW_LAYOUT_PX := 860.0
const SINGLE_COLUMN_PX := 560.0

## `.help-input-tabs { width: min(360px, 100%) }` (`styles.css:2448-2451`).
const TABS_WIDTH := 360.0

## `.help-card` padding is `16px 18px` (`styles.css:2425-2431`).
const CARD_PAD_X := 18.0
const CARD_PAD_Y := 16.0

const SCROLL_NODE := "HelpScroll"
const BODY_NODE := "HelpBody"
const ROW_NODE := "HelpRow"
const SECTIONS_NODE := "HelpSections"
const CONTROLS_NODE := "HelpControls"
const TABS_NODE := "HelpInputTabs"
const KEYBOARD_TAB_NODE := "HelpKeyboardTab"
const CONTROLLER_TAB_NODE := "HelpControllerTab"
const KEYBOARD_PANEL_NODE := "HelpKeyboardPanel"
const CONTROLLER_PANEL_NODE := "HelpControllerPanel"
const KEYBOARD_GUIDE_NODE := "KbdGuide"

## The router's own facts, kept the way `MenuScreen` keeps them (`enter()` writes
## them from the payload the router hands over).
var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _scroll: ScrollContainer
var _body: VBoxContainer
var _row: HBoxContainer
var _sections: GridContainer
var _controls: VBoxContainer
var _keyboard_tab: Button
var _controller_tab: Button
var _keyboard_panel: PanelContainer
var _controller_panel: VBoxContainer
var _legend: VBoxContainer
var _narrow: bool = false
var _view: String = VIEW_KEYBOARD
var _palette_misses: Array = []


func _ready() -> void:
	_build()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return BACK_TARGET_ID


## The router moved here: the store is not read (the page has no numbers), so `enter`
## only re-runs the two things a router move can have changed — the language, through
## `refresh_strings()`, and the frame, through `_apply_layout()`.
func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", SCREEN_ID))
	back_target_id = String(payload.get("back_target", BACK_TARGET_ID))
	refresh_strings()
	_apply_layout()
	_apply_aria()


func capture_states() -> Array[String]:
	return CAPTURE_STATE_LIST.duplicate()


## `keyboard-tab` / `controller-tab` (`js/main.js:2325-2360`): both switch the panel the
## reference's own tabs switch, and both are applied — a harness can tell either state
## resolved.
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"keyboard-tab":
			return set_input_view(VIEW_KEYBOARD)
		"controller-tab":
			return set_input_view(VIEW_CONTROLLER)
	return false


## `setHelpInput` (`js/main.js:2325-2360`): the tab's panel is shown, the other hidden,
## and the active tab carries the segmented active variation.
func set_input_view(view: String) -> bool:
	if view != VIEW_KEYBOARD and view != VIEW_CONTROLLER:
		return false
	_view = view
	var keyboard_active := view == VIEW_KEYBOARD
	_keyboard_panel.visible = keyboard_active
	_controller_panel.visible = not keyboard_active
	if keyboard_active:
		_keyboard_tab.theme_type_variation = &"SegmentedActive"
		_controller_tab.theme_type_variation = &"SegmentedInactive"
	else:
		_keyboard_tab.theme_type_variation = &"SegmentedInactive"
		_controller_tab.theme_type_variation = &"SegmentedActive"
	_keyboard_tab.set_meta("aria_selected", keyboard_active)
	_controller_tab.set_meta("aria_selected", not keyboard_active)
	return true


func input_view() -> String:
	return _view


## The shell's focusables (back + the two tabs); the screen owns no menu focus of its
## own, which is why this is a pass-through and not a policy.
func focus_controls() -> Array:
	return _shell.focus_controls() if _shell != null else []


## The screen's own title node, through the shell that renders it
## (`ScreenShell.title_control`): the audits read a screen's title under this name.
func title_control() -> Label:
	if _shell == null:
		return null
	return _shell.call("title_control") as Label


func help_shell() -> Control:
	return _shell


func legend() -> VBoxContainer:
	return _legend


func keyboard_tab_button() -> Button:
	return _keyboard_tab


func controller_tab_button() -> Button:
	return _controller_tab


func keyboard_panel() -> PanelContainer:
	return _keyboard_panel


func controller_panel() -> VBoxContainer:
	return _controller_panel


## Every visible string this screen shows, re-resolved: the shell's own title and
## subtitle, the cards, the keyboard rows, the tabs and the legend.
func refresh_strings() -> void:
	if _shell == null:
		return
	_shell.set_title(TITLE_KEY)
	_shell.set_subtitle(SUBTITLE_KEY)
	for index in CARDS.size():
		var card: Dictionary = CARDS[index]
		var title := _sections.get_node_or_null("HelpCard%d/Title" % index) as Label
		var body := _sections.get_node_or_null("HelpCard%d/Body" % index) as Label
		if title != null:
			title.text = UiStrings.t(String(card["title_key"]))
		if body != null:
			body.text = UiStrings.t(String(card["body_key"]))
	var guide := _keyboard_panel.get_node_or_null(KEYBOARD_GUIDE_NODE)
	if guide != null:
		for index in KEYBOARD_ROWS.size():
			var row: Dictionary = KEYBOARD_ROWS[index]
			var text := guide.get_node_or_null("Row%d/Text" % index) as Label
			if text != null:
				text.text = UiStrings.t(String(row["label_id"]))
	_keyboard_tab.text = UiStrings.t("helpKeyboard")
	_controller_tab.text = UiStrings.t("helpGamepad")
	if _legend != null and _legend.has_method("refresh_strings"):
		_legend.call("refresh_strings")
	_apply_aria()


## The section's own aria name (`index.html:181`, `data-i18n-aria="ariaHelp"`) and the
## tab strip's (`ariaInputTabs`). Godot only carries an accessible name where the
## runtime exposes the property; where it does not, this is a no-op and the id stays
## resolvable by the audit.
func aria_name() -> String:
	return UiStrings.t(ARIA_KEY)


func tabs_aria_name() -> String:
	return UiStrings.t("ariaInputTabs")


## Every Palette key this screen can name, for the audit's existence check.
func palette_keys() -> Array:
	return [
		"tab_border", "surface_0", "surface_1", "surface_2", "text_soft_3",
		"help_muted", "line", "state_yellow",
	]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_shell = ShellScene.instantiate()
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(BACK_TARGET_ID)
	add_child(_shell)
	_scroll = ScrollContainer.new()
	_scroll.name = SCROLL_NODE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.content().add_child(_scroll)
	_body = VBoxContainer.new()
	_body.name = BODY_NODE
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 28)
	_scroll.add_child(_body)
	_row = HBoxContainer.new()
	_row.name = ROW_NODE
	_row.add_theme_constant_override("separation", 28)
	_body.add_child(_row)
	# A hidden child is skipped by its container, so below the collapse the empty row keeps
	# the width of the last frame it was shown in. Tracking the body keeps the row's own
	# size at this frame's width, which is what the layout reads ask a screen for.
	_body.resized.connect(_sync_hidden_row)
	_build_sections()
	_build_controls()
	_row.add_child(_sections)
	_row.add_child(_controls)
	resized.connect(_apply_layout)
	refresh_strings()
	_apply_layout()


## `.help-sections` + `article.help-card` (`styles.css:2417-2445`).
func _build_sections() -> void:
	_sections = GridContainer.new()
	_sections.name = SECTIONS_NODE
	_sections.columns = 2
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.size_flags_stretch_ratio = 1.1
	_sections.add_theme_constant_override("h_separation", 14)
	_sections.add_theme_constant_override("v_separation", 14)
	for index in CARDS.size():
		var card: Dictionary = CARDS[index]
		# `article.help-card` (`styles.css:2425-2436`) is one element that paints the card
		# and stacks its title over its body. `BoxColumn` is both jobs in one node, so
		# `HelpCard%d/Title` and `HelpCard%d/Body` are the card's own direct children —
		# the path this screen reads (`_card_text`) and the audit walks.
		var panel := BoxColumn.new()
		panel.name = "HelpCard%d" % index
		panel.separation = 8
		panel.add_theme_stylebox_override("panel", _card_box())
		var title := Label.new()
		title.name = "Title"
		title.add_theme_font_override("font", _font("CardTitle"))
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", _palette("text_soft_3"))
		panel.add_child(title)
		var body := Label.new()
		body.name = "Body"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.theme_type_variation = &"CardBody"
		body.add_theme_color_override("font_color", _palette("help_muted"))
		panel.add_child(body)
		if bool(card["academy"]):
			panel.set_meta("academy", true)
		_sections.add_child(panel)


## `aside.help-controls` (`index.html:222-272`): the tab strip, then the two panels.
func _build_controls() -> void:
	_controls = VBoxContainer.new()
	_controls.name = CONTROLS_NODE
	_controls.add_theme_constant_override("separation", 14)
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.size_flags_stretch_ratio = 0.9
	var tabs := PanelContainer.new()
	tabs.name = TABS_NODE
	tabs.theme_type_variation = &"SegmentedContainer"
	tabs.custom_minimum_size.x = TABS_WIDTH
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var strip := HBoxContainer.new()
	tabs.add_child(strip)
	_keyboard_tab = Button.new()
	_keyboard_tab.name = KEYBOARD_TAB_NODE
	_keyboard_tab.theme_type_variation = &"SegmentedActive"
	_keyboard_tab.custom_minimum_size.y = 42
	_keyboard_tab.pressed.connect(func() -> void: set_input_view(VIEW_KEYBOARD))
	strip.add_child(_keyboard_tab)
	_controller_tab = Button.new()
	_controller_tab.name = CONTROLLER_TAB_NODE
	_controller_tab.theme_type_variation = &"SegmentedInactive"
	_controller_tab.custom_minimum_size.y = 42
	_controller_tab.pressed.connect(func() -> void: set_input_view(VIEW_CONTROLLER))
	strip.add_child(_controller_tab)
	_controls.add_child(tabs)
	_build_keyboard_panel()
	_build_controller_panel()
	_shell.add_focus("input-keyboard", _keyboard_tab, "help-tab-keyboard", {"kind": "button"})
	_shell.add_focus("input-controller", _controller_tab, "help-tab-controller", {"kind": "button"})


## `.kbd-guide` (`styles.css:2614-2630`): a bordered box of seven rows.
func _build_keyboard_panel() -> void:
	_keyboard_panel = PanelContainer.new()
	_keyboard_panel.name = KEYBOARD_PANEL_NODE
	_keyboard_panel.add_theme_stylebox_override("panel", _guide_box())
	var guide := VBoxContainer.new()
	guide.name = KEYBOARD_GUIDE_NODE
	guide.add_theme_constant_override("separation", 8)
	for index in KEYBOARD_ROWS.size():
		var row: Dictionary = KEYBOARD_ROWS[index]
		var line := HBoxContainer.new()
		line.name = "Row%d" % index
		line.add_theme_constant_override("separation", 8)
		for cap in (row["caps"] as Array):
			line.add_child(_cap(String(cap)))
		var text := Label.new()
		text.name = "Text"
		text.add_theme_color_override("font_color", _palette("help_muted"))
		text.add_theme_font_size_override("font_size", 12)
		line.add_child(text)
		guide.add_child(line)
	_keyboard_panel.add_child(guide)
	_controls.add_child(_keyboard_panel)


## `#help-controller-panel` (`index.html:242-258`): UIR-13's legend, one column and
## 48 px rows (`.help-controller-legend`, `styles.css:2482-2489`).
func _build_controller_panel() -> void:
	_controller_panel = VBoxContainer.new()
	_controller_panel.name = CONTROLLER_PANEL_NODE
	_controller_panel.add_theme_constant_override("separation", 14)
	_legend = LegendScene.instantiate()
	_legend.name = "HelpControllerLegend"
	_controller_panel.add_child(_legend)
	if _legend.has_method("setup"):
		_legend.call("setup", LegendClass.reference_rows(), {"columns": 1, "row_min_height": 48.0})
	_controller_panel.visible = false
	_controls.add_child(_controller_panel)


## `styles.css:2775-2800` as one frame-width rule.
func _apply_layout() -> void:
	if _body == null:
		return
	var width := size.x
	var narrow := width < NARROW_LAYOUT_PX
	_sections.columns = 1 if width < SINGLE_COLUMN_PX else 2
	if narrow == _narrow and _sections.get_parent() != null:
		_row.visible = not narrow
		_sync_hidden_row()
		return
	_narrow = narrow
	_row.visible = not narrow
	if narrow:
		_sections.reparent(_body, false)
		_controls.reparent(_body, false)
		_sync_hidden_row()
	else:
		_sections.reparent(_row, false)
		_controls.reparent(_row, false)


## The collapsed row is hidden and empty: give it this frame's width so a screen that is
## asked for its parts reports the frame it is in, not the frame it was last shown in.
func _sync_hidden_row() -> void:
	if _narrow and _row != null and _body != null:
		_row.size = Vector2(_body.size.x, _row.size.y)


# ---------------------------------------------------------------------------
# Pieces and inks
# ---------------------------------------------------------------------------

## `.help-card` (`styles.css:2425-2436`): 1 px `#28567d`, radius 10, the two-stop
## gradient's first stop at 0.85 (a `StyleBoxFlat` cannot carry a gradient — recorded
## in the evidence log) and the card's own `0 18px 40px rgba(0,0,0,0.25)` shadow.
func _card_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("surface_2"), 0.85)
	box.border_color = _palette("tab_border")
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = CARD_PAD_X
	box.content_margin_right = CARD_PAD_X
	box.content_margin_top = CARD_PAD_Y
	box.content_margin_bottom = CARD_PAD_Y
	box.shadow_color = _alpha(_palette("shadow"), 0.25)
	box.shadow_size = 40
	box.shadow_offset = Vector2(0, 18)
	return box


## `.kbd-guide` (`styles.css:2614-2621`): 1 px `#28567d`, radius 10, `#091d39` at 0.6.
func _guide_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("surface_1"), 0.6)
	box.border_color = _palette("tab_border")
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box


## One keyboard cap: the reference's own `kbd` (`styles.css:894-904`) — 1 px
## `rgba(255,255,255,0.12)`, a 3 px bottom, radius 6, `#19212d` fill.
func _cap(text: String) -> Label:
	var cap := Label.new()
	cap.text = text
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.custom_minimum_size = Vector2(32, 0)
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_stylebox_override("normal", _cap_box())
	cap.add_theme_color_override("font_color", _palette("ink"))
	return cap


func _cap_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("surface_2")
	box.border_color = _palette("line")
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 5.0
	return box


func _font(role: String) -> Font:
	var source := theme if theme != null else DefaultTheme
	return source.get_font("font", role) if source.has_font("font", role) else null


func _apply_aria() -> void:
	var tab_strip := _controls.get_node_or_null(TABS_NODE) if _controls != null else null
	if tab_strip != null:
		_set_accessible_name(tab_strip, tabs_aria_name())
	_set_accessible_name(self, aria_name())


func _set_accessible_name(node: Node, text: String) -> void:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == "accessibility_name":
			node.set("accessibility_name", text)
			return


func _palette(key: String) -> Color:
	var source := theme if theme != null else DefaultTheme
	if source.has_color(key, "Palette"):
		return source.get_color(key, "Palette")
	if not _palette_misses.has(key):
		_palette_misses.append(key)
	if source.has_color("ink", "Palette"):
		return source.get_color("ink", "Palette")
	return Color.WHITE


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out
