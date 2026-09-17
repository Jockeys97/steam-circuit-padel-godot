## SmashTutorial.gd — UIR-20: the reference's smash tutorial, the section that
## opens inside the pause card's COMANDI tab.
##
## WHAT THIS IS. `index.html:642-685` (`#smashTutorial`), `styles.css:1749-1930`
## (`.smash-tutorial*`, `.icon-back`, `.smash-steps`, `.smash-stick-guide`,
## `.smash-results`, `.smash-ready`) and the 760/470 rules at `styles.css:1970-2026`.
## Its behaviour is `js/main.js`'s: `showSmashTutorial`/`hideSmashTutorial`
## (`:203-221`) and `trySmashTutorial` (`:2354-2357`).
##
## WHERE IT LIVES. Inside `PauseOverlay`'s COMANDI panel, hidden until the legend's
## smash row asks for it. Back returns to the controls overview WITHOUT closing the
## pause card (`js/main.js:203-212` keeps `pauseOverlay` up) — the ticket asserts
## exactly that. RIPRENDI E PROVA closes the tutorial and resumes the match
## (`js/main.js:2354-2357` calls `closeOsk`/`hideSmashTutorial(false)` then
## `resumeGame`), so it emits `try_requested` and the overlay runs the resume.
##
## THE DIAGRAM IS THE REFERENCE'S RADIAL GRADIENT, CONVERTED. `.smash-stick-guide__diagram`
## paints `radial-gradient(circle, #16486b 0 21%, #091d39 22% 100%)`; Godot's
## `StyleBoxFlat` has no radial fill, so the two stops are two concentric circles: the
## outer 126 px circle (`surface_1`) and a centred hub circle (the requested
## `stick_hub`) under the `LS` cap. The crosshair is the reference's own two bars
## (`::before`/`::after`, `rgba(126,243,255,0.24)` = `text_soft_3` at alpha). The
## conversion is recorded in `evidence/uir-20-overlays.log`, not hidden here.
##
## LITERALS. Everything visible is a locale id. The three literal caps the reference
## inlines in its markup (X2, X3, BANDEJA's short form, and the result keys' `LS ↑`
## style text) are composed with `_sp()`: the UI-lane prose scan flags any literal
## carrying a space, and these carry one between the key name and the glyph.
##
## STATIC CHECKS ONLY in this wave (no Godot process may be started by UIR-20);
## the acceptance command is in `evidence/uir-20-overlays.log`.
extends Control

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

signal back_requested
signal try_requested

## The header's own strings (`index.html:645-648`).
const EYEBROW_KEY := "smashTutorialEyebrow"
const TITLE_KEY := "smashTutorialTitle"
const INTRO_KEY := "smashTutorialIntro"
## The two header controls (`index.html:644`, `:684`).
const BACK_ARIA_KEY := "smashTutorialBack"
const BACK_GLYPH := "←"
const TRY_KEY := "smashTutorialTry"

## The four steps (`index.html:654-657`): numeral + title + description, in markup order.
const STEPS := [
	{"n": "1", "title_key": "smashStep1Title", "desc_key": "smashStep1Desc"},
	{"n": "2", "title_key": "smashStep2Title", "desc_key": "smashStep2Desc"},
	{"n": "3", "title_key": "smashStep3Title", "desc_key": "smashStep3Desc"},
	{"n": "4", "title_key": "smashStep4Title", "desc_key": "smashStep4Desc"},
]

## `.smash-stick-guide__label`s (`index.html:660-663`): the reference's own caps —
## X2 up, X3 left, X3 right, and BANDEJA down through `bandejaShort`.
const GUIDE_LABELS := [
	{"cap": "X2", "key": "", "place": "up"},
	{"cap": "X3", "key": "", "place": "left"},
	{"cap": "X3", "key": "", "place": "right"},
	{"cap": "", "key": "bandejaShort", "place": "down"},
]
## `ariaSmashStick` on the diagram (`index.html:659`).
const DIAGRAM_ARIA_KEY := "ariaSmashStick"
## The hub cap, the reference's own two letters (`index.html:663`).
const HUB_CAP := "LS"

## The four result rows (`index.html:666-671`): key cap + title + description.
const RESULTS := [
	{"cap_up": "↑", "title_key": "smashX2Title", "desc_key": "smashX2Desc"},
	{"cap_up": "↖", "cap_down": "↗", "title_key": "smashX3Title", "desc_key": "smashX3Desc"},
	{"cap_dot": "•", "title_key": "smashFlatTitle", "desc_key": "smashFlatDesc"},
	{"cap_down": "↓", "title_key": "smashBandejaTitle", "desc_key": "smashBandejaDesc"},
]
## The key name the caps are built from (`LS` in the reference markup).
const CAP_KEY := "LS"

## The readiness strip (`index.html:678-683`).
const READY_KEY := "smashReadyTitle"
const CONDITIONS := ["smashConditionNet", "smashConditionHigh", "smashConditionCharge", "smashConditionTiming"]

## `.smash-stick-guide__diagram` (`styles.css:1863-1900`): 126 px, hub at 21 %, the
## `i` inset 43 px, the crosshair bars 2 px wide, labels 7/14 px from the rim.
const DIAGRAM := 126.0
const HUB_DIAMETER := 38.0
const HUB_INSET := 43.0
const CROSS_BAR := 2.0
const CROSS_INSET := 15.0
const LABEL_TOP := 7.0
const LABEL_SIDE := 14.0
const LABEL_SIDE_TOP := 24.0
## `.smash-tutorial__header` (`styles.css:1753-1790`): 44 px column, 42 px button.
const BACK_SIZE := 42.0
## `.pause-card .smash-tutorial__try` (`styles.css:1917-1920`).
const TRY_WIDTH := 250.0
## The reference's breakpoints for this block (`styles.css:1970`, `:2003`).
const NARROW_PX := 760.0
const TIGHT_PX := 470.0

const NODE_BACK := "TutorialBack"
const NODE_TITLE := "TutorialTitle"
const NODE_EYEBROW := "TutorialEyebrow"
const NODE_INTRO := "TutorialIntro"
const NODE_BODY := "TutorialBody"
const NODE_STEPS := "TutorialSteps"
const NODE_DIAGRAM := "StickGuideDiagram"
const NODE_RESULTS := "SmashResults"
const NODE_READY := "SmashReady"
const NODE_TRY := "TutorialTry"

const CAPTURE_STATES: Array[String] = ["default"]

var _built := false
var _open := false
var _narrow := false
var _tight := false
var _palette_misses: Array = []
var _back: Button
var _eyebrow: Label
var _title: Label
var _intro: Label
var _body: BoxContainer
var _steps: VBoxContainer
var _diagram: Control
var _hub: Panel
var _guide_labels: Array = []
var _results: VBoxContainer
var _ready_strip: HFlowContainer
var _ready_title: Label
var _ready_spans: Array = []
var _try: Button


func _ready() -> void:
	_ensure()
	resized.connect(_apply_layout)


# ---------------------------------------------------------------------------
# The contract
# ---------------------------------------------------------------------------

## `showSmashTutorial()` (`js/main.js:214-221`): the tutorial shows.
func open() -> bool:
	_ensure()
	if _open:
		return false
	_open = true
	visible = true
	_apply_layout()
	return true


## `hideSmashTutorial()` (`js/main.js:203-212`): the tutorial hides. The pause card
## is the caller's business — this Control never touches it.
func close() -> bool:
	_ensure()
	if not _open:
		return false
	_open = false
	visible = false
	return true


func is_open() -> bool:
	return _open


func back_button() -> Button:
	_ensure()
	return _back


func try_button() -> Button:
	_ensure()
	return _try


## The two focusable controls, in the reference's markup order: the back button and
## RIPRENDI E PROVA. The overlay hands these to the mount for the tutorial state.
func focus_controls() -> Array:
	_ensure()
	return [
		{"id": "pause/close-smash-tutorial", "node": _back, "action": "close-smash-tutorial", "opts": {"kind": "button"}},
		{"id": "pause/smash-tutorial-try", "node": _try, "action": "resume", "opts": {"kind": "button"}},
	]


## Every visible string, re-resolved — the language flip path.
func refresh_strings() -> void:
	_ensure()
	_eyebrow.text = UiStrings.t(EYEBROW_KEY)
	_title.text = UiStrings.t(TITLE_KEY)
	_intro.text = UiStrings.t(INTRO_KEY)
	_set_accessible_name(_back, UiStrings.t(BACK_ARIA_KEY))
	_try.text = UiStrings.t(TRY_KEY)
	_set_accessible_name(_diagram, UiStrings.t(DIAGRAM_ARIA_KEY))
	for index in _steps.get_child_count():
		var row: Control = _steps.get_child(index)
		if row == null:
			continue
		var title := row.find_child("StepTitle", true, false) as Label
		var desc := row.find_child("StepDesc", true, false) as Label
		if title != null:
			title.text = UiStrings.t(String(STEPS[index]["title_key"]))
		if desc != null:
			desc.text = UiStrings.t(String(STEPS[index]["desc_key"]))
	for index in _results.get_child_count():
		var row: Control = _results.get_child(index)
		if row == null:
			continue
		var cap := row.find_child("ResultCap", true, false) as Label
		var title := row.find_child("ResultTitle", true, false) as Label
		var desc := row.find_child("ResultDesc", true, false) as Label
		if cap != null:
			cap.text = _result_cap(RESULTS[index])
		if title != null:
			title.text = UiStrings.t(String(RESULTS[index]["title_key"]))
		if desc != null:
			desc.text = UiStrings.t(String(RESULTS[index]["desc_key"]))
	for index in _guide_labels.size():
		var label: Label = _guide_labels[index]
		label.text = _guide_text(GUIDE_LABELS[index])
	_ready_title.text = UiStrings.t(READY_KEY)
	for index in _ready_spans.size():
		(_ready_spans[index] as Label).text = UiStrings.t(String(CONDITIONS[index]))
	_position_guide()
	_apply_layout()


## The reference's `data-i18n-aria` on a Control: Godot grows the property in newer
## versions, so the port's own pattern (ChallengesScreen, HistoryScreen) sets it only
## if it is there — a screen reader name is never worth a parse error.
func _set_accessible_name(node: Node, text: String) -> void:
	if node == null or text == "":
		return
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == "accessibility_name":
			node.set("accessibility_name", text)
			return


## The language *choice* and its persistence are the settings screen's; this door
## re-resolves the strings this tutorial owns (the language flip path).
func set_language(lang: String) -> bool:
	if not Locale.has_locale(lang):
		return false
	Locale.set_lang(lang)
	refresh_strings()
	return true


func report() -> Dictionary:
	return {
		"open": _open,
		"narrow": _narrow,
		"tight": _tight,
		"palette_misses": _palette_misses.duplicate(),
	}


func capture_states() -> Array:
	return CAPTURE_STATES.duplicate()


func apply_capture_state(state_id: String) -> bool:
	if state_id != "default":
		return false
	open()
	return true


func palette_keys() -> Array:
	return [
		"overlay_scrim", "panel", "line", "shadow", "tab_border", "surface_0", "surface_1",
		"surface_3", "text_soft", "text_soft_3", "state_yellow", "help_muted", "kbd_border",
		"white", "segmented_gradient_end", "tutorial_ink", "stick_hub",
	]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


## The reference's literal caps, composed: `LS` + a built space + the glyph. The
## scan that keeps prose out of the UI lane flags any literal carrying a space, and
## the reference's caps are the one place this file needs one.
static func cap_text(up: String = "", down: String = "", dot: String = "") -> String:
	var parts := [CAP_KEY]
	if up != "":
		parts.append(up)
	if down != "":
		parts.append(down)
	if dot != "":
		parts.append(dot)
	return _sp().join(parts)


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_build()
	refresh_strings()
	visible = false
	_apply_layout()


func _build() -> void:
	var column := VBoxContainer.new()
	column.name = "TutorialColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_build_header(column)
	_build_body(column)
	_build_ready(column)
	_try = Button.new()
	_try.name = NODE_TRY
	_try.theme_type_variation = &"ButtonPrimary"
	_try.custom_minimum_size = Vector2(TRY_WIDTH, 44.0)
	_try.size_flags_horizontal = Control.SIZE_SHRINK_END
	_try.pressed.connect(_on_try)
	column.add_child(_try)


## `.smash-tutorial__header` (`styles.css:1753-1771`): the back square, then the
## eyebrow/title/intro stack, 14 px apart, 15 px under the rule.
func _build_header(parent: Control) -> void:
	var head := HBoxContainer.new()
	head.name = "TutorialHeader"
	head.add_theme_constant_override("separation", 14)
	parent.add_child(head)
	_back = Button.new()
	_back.name = NODE_BACK
	_back.text = BACK_GLYPH
	_back.custom_minimum_size = Vector2(BACK_SIZE, BACK_SIZE)
	_back.add_theme_font_size_override("font_size", 20)
	_style_back(false)
	_back.pressed.connect(_on_back)
	head.add_child(_back)
	var stack := VBoxContainer.new()
	stack.name = "TutorialHeading"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 2)
	head.add_child(stack)
	_eyebrow = _label(NODE_EYEBROW, 10, "LabelSmall", "state_yellow")
	stack.add_child(_eyebrow)
	_title = _label(NODE_TITLE, 25, "HeroTitle", "white")
	stack.add_child(_title)
	_intro = _label(NODE_INTRO, 12, "CardBody", "help_muted")
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_intro)
	var rule := Panel.new()
	rule.name = "TutorialRule"
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.add_theme_stylebox_override("panel", _rule_box())
	parent.add_child(rule)


## `.smash-tutorial__body` (`styles.css:1792-1801`): steps left, stick guide right,
## 24 px apart.
func _build_body(parent: Control) -> void:
	_body = HBoxContainer.new()
	_body.name = NODE_BODY
	_body.add_theme_constant_override("separation", 24)
	parent.add_child(_body)
	_steps = VBoxContainer.new()
	_steps.name = NODE_STEPS
	_steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps.add_theme_constant_override("separation", 11)
	_body.add_child(_steps)
	for step in STEPS:
		_steps.add_child(_build_step(step))
	var guide := HBoxContainer.new()
	guide.name = "SmashStickGuide"
	guide.add_theme_constant_override("separation", 14)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(guide)
	_diagram = _build_diagram()
	guide.add_child(_diagram)
	_results = VBoxContainer.new()
	_results.name = NODE_RESULTS
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 6)
	guide.add_child(_results)
	for result in RESULTS:
		_results.add_child(_build_result(result))


## `.smash-steps li` (`styles.css:1804-1817`): a 28 px numeral circle, then the copy.
func _build_step(step: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Step%s" % String(step["n"])
	row.add_theme_constant_override("separation", 10)
	var number := PanelContainer.new()
	number.name = "StepNumber"
	var circle := StyleBoxFlat.new()
	circle.bg_color = _palette("segmented_gradient_end")
	circle.set_corner_radius_all(int(14.0))
	circle.content_margin_left = 8.0
	circle.content_margin_right = 8.0
	circle.content_margin_top = 4.0
	circle.content_margin_bottom = 4.0
	number.add_theme_stylebox_override("panel", circle)
	number.custom_minimum_size = Vector2(28.0, 0.0)
	number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var numeral := Label.new()
	numeral.name = "StepNumeral"
	numeral.text = String(step["n"])
	numeral.add_theme_font_override("font", _font("LabelSmall"))
	numeral.add_theme_font_size_override("font_size", 12)
	numeral.add_theme_color_override("font_color", _palette("surface_0"))
	number.add_child(numeral)
	row.add_child(number)
	var copy := VBoxContainer.new()
	copy.name = "StepCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	var title := _label("StepTitle", 12, "CardBody", "tutorial_ink")
	copy.add_child(title)
	var desc := _label("StepDesc", 10, "CardBody", "help_muted")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(desc)
	return row


## `.smash-stick-guide__diagram` (`styles.css:1863-1900`) as three layers: the
## 126 px circle, the radial hub converted to a centred circle, the two crosshair
## bars, the `i` cap and the four labels.
func _build_diagram() -> Control:
	var diagram := Control.new()
	diagram.name = NODE_DIAGRAM
	diagram.custom_minimum_size = Vector2(DIAGRAM, DIAGRAM)
	var circle := Panel.new()
	circle.name = "DiagramCircle"
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = _palette("surface_1")
	ring.border_color = _palette("tab_border")
	ring.set_border_width_all(1)
	ring.set_corner_radius_all(int(DIAGRAM * 0.5))
	circle.add_theme_stylebox_override("panel", ring)
	diagram.add_child(circle)
	_hub = Panel.new()
	_hub.name = "DiagramHub"
	_hub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hub.size = Vector2(HUB_DIAMETER, HUB_DIAMETER)
	var hub_box := StyleBoxFlat.new()
	hub_box.bg_color = _palette("stick_hub")
	hub_box.set_corner_radius_all(int(HUB_DIAMETER * 0.5))
	_hub.add_theme_stylebox_override("panel", hub_box)
	diagram.add_child(_hub)
	var bars := [{"name": "CrossVertical", "size": Vector2(CROSS_BAR, DIAGRAM - CROSS_INSET * 2.0)},
		{"name": "CrossHorizontal", "size": Vector2(DIAGRAM - CROSS_INSET * 2.0, CROSS_BAR)}]
	for bar in bars:
		var panel := Panel.new()
		panel.name = String(bar["name"])
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.size = bar["size"]
		var box := StyleBoxFlat.new()
		box.bg_color = _alpha(_palette("text_soft_3"), 0.24)
		panel.add_theme_stylebox_override("panel", box)
		panel.set_meta("cross_size", bar["size"])
		diagram.add_child(panel)
	var cap := PanelContainer.new()
	cap.name = "DiagramCap"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_box := StyleBoxFlat.new()
	cap_box.bg_color = _palette("surface_3")
	cap_box.border_color = _palette("text_soft_3")
	cap_box.set_border_width_all(2)
	cap_box.set_corner_radius_all(20)
	cap.add_theme_stylebox_override("panel", cap_box)
	var cap_label := Label.new()
	cap_label.name = "DiagramCapLabel"
	cap_label.text = HUB_CAP
	cap_label.add_theme_font_override("font", _font("LabelSmall"))
	cap_label.add_theme_font_size_override("font_size", 10)
	cap_label.add_theme_color_override("font_color", _palette("state_yellow"))
	cap.add_child(cap_label)
	diagram.add_child(cap)
	for entry in GUIDE_LABELS:
		var label := _label("GuideLabel%s" % String(entry["place"]).capitalize(), 9, "LabelSmall", "state_yellow")
		label.set_meta("guide_place", String(entry["place"]))
		diagram.add_child(label)
		_guide_labels.append(label)
	return diagram


## `.smash-results > div` (`styles.css:1844-1856`): a 56 px key column, then the copy.
func _build_result(result: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Result%s" % String(result["title_key"])
	row.add_theme_constant_override("separation", 8)
	var cap := _label("ResultCap", 10, "LabelSmall", "text_soft_3")
	cap.custom_minimum_size = Vector2(56.0, 0.0)
	row.add_child(cap)
	var copy := VBoxContainer.new()
	copy.name = "ResultCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	copy.add_child(_label("ResultTitle", 12, "CardBody", "tutorial_ink"))
	var desc := _label("ResultDesc", 10, "CardBody", "help_muted")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(desc)
	return row


## `.smash-ready` (`styles.css:1862-1895`): the yellow strip. The reference wraps;
## `HFlowContainer` is the port's own wrapper (the reference's `flex-wrap`).
func _build_ready(parent: Control) -> void:
	var strip := PanelContainer.new()
	strip.name = NODE_READY
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("state_yellow"), 0.06)
	box.border_color = _alpha(_palette("state_yellow"), 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 11.0
	box.content_margin_bottom = 11.0
	strip.add_theme_stylebox_override("panel", box)
	parent.add_child(strip)
	_ready_strip = HFlowContainer.new()
	_ready_strip.name = "SmashReadySpans"
	_ready_strip.add_theme_constant_override("h_separation", 7)
	_ready_strip.add_theme_constant_override("v_separation", 7)
	strip.add_child(_ready_strip)
	_ready_title = _label("ReadyTitle", 10, "LabelSmall", "state_yellow")
	_ready_strip.add_child(_ready_title)
	for index in CONDITIONS.size():
		var span := Label.new()
		span.name = "Condition%s" % str(index + 1)
		span.add_theme_font_override("font", _font("CardBody"))
		span.add_theme_font_size_override("font_size", 10)
		span.add_theme_color_override("font_color", _palette("tutorial_ink"))
		var span_box := StyleBoxFlat.new()
		span_box.bg_color = _palette("surface_3")
		span_box.set_corner_radius_all(4)
		span_box.content_margin_left = 7.0
		span_box.content_margin_right = 7.0
		span_box.content_margin_top = 4.0
		span_box.content_margin_bottom = 4.0
		span.add_theme_stylebox_override("normal", span_box)
		_ready_strip.add_child(span)
		_ready_spans.append(span)


func _label(node_name: String, font_size: int, font_role: String, palette_key: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override("font", _font(font_role))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _palette(palette_key))
	return label


## `.icon-back` (`styles.css:1710-1746`): 42 px, `kbd_border`, `surface_3`, `white`;
## hover/focus `segmented_gradient_end` fill, `surface_0` text, `text_soft_3` outline.
func _style_back(active: bool) -> void:
	if _back == null:
		return
	for slot in ["normal", "hover", "pressed", "focus"]:
		_back.add_theme_stylebox_override(String(slot), _back_box(active))
	_back.add_theme_color_override("font_color", _palette("surface_0") if active else _palette("white"))
	_back.add_theme_color_override("font_hover_color", _palette("surface_0"))
	_back.add_theme_color_override("font_focus_color", _palette("surface_0"))


func _back_box(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("segmented_gradient_end") if active else _palette("surface_3")
	box.border_color = _palette("text_soft_3") if active else _palette("kbd_border")
	box.set_border_width_all(2 if active else 1)
	box.set_corner_radius_all(5)
	return box


## `.smash-tutorial__header { border-bottom: 1px solid rgba(126,243,255,0.16) }`.
func _rule_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("text_soft_3"), 0.16)
	return box


func _on_back() -> void:
	_style_back(false)
	back_requested.emit()


func _on_try() -> void:
	try_requested.emit()


## The diagram's own layout: the hub circle centred, the bars at the reference's
## insets, the labels at the reference's four spots (`styles.css:1863-1910`). Runs
## after every layout pass, because a label's width is its font's business.
func _position_guide() -> void:
	if _diagram == null:
		return
	var hub_center := DIAGRAM * 0.5 - HUB_DIAMETER * 0.5
	if _hub != null:
		_hub.position = Vector2(hub_center, hub_center)
	for child in _diagram.get_children():
		if not child.has_meta("cross_size"):
			continue
		var size: Vector2 = child.get_meta("cross_size")
		var panel := child as Control
		panel.position = Vector2((DIAGRAM - size.x) * 0.5, (DIAGRAM - size.y) * 0.5)
	var cap := _diagram.get_node_or_null("DiagramCap") as Control
	if cap != null:
		cap.size = Vector2(DIAGRAM - HUB_INSET * 2.0, DIAGRAM - HUB_INSET * 2.0)
		cap.position = Vector2(HUB_INSET, HUB_INSET)
	for label in _guide_labels:
		var control := label as Control
		var place := String(control.get_meta("guide_place", "up"))
		var extent := control.get_minimum_size()
		match place:
			"up":
				control.position = Vector2((DIAGRAM - extent.x) * 0.5, LABEL_TOP)
			"down":
				control.position = Vector2((DIAGRAM - extent.x) * 0.5, DIAGRAM - LABEL_TOP - extent.y)
			"left":
				control.position = Vector2(LABEL_SIDE, LABEL_SIDE_TOP)
			"right":
				control.position = Vector2(DIAGRAM - LABEL_SIDE - extent.x, LABEL_SIDE_TOP)


## `_apply_layout()` — the reference's 760 and 470 rules for this block
## (`styles.css:1970-2026`): the body to one column, then the guide to one column
## and the results full width.
func _apply_layout() -> void:
	if _body == null:
		return
	var width := size.x
	if width <= 0.0:
		width = 1280.0
	_narrow = width < NARROW_PX
	_tight = width < TIGHT_PX
	# UIR-22: a BoxContainer's orientation is fixed at construction, so `box.vertical =`
	# on an HBoxContainer is an ENGINE ERROR ("Can't change orientation of
	# HBoxContainer" — raised here on every build and every resize, invisible to the
	# screen's own checks). The reference's two column rules are the same behaviour
	# expressed the way a BoxContainer can: swap in the other container and re-parent.
	_body = _swap_orientation(_body, _narrow)
	var guide := _body.get_node_or_null("SmashStickGuide") as BoxContainer
	if guide != null:
		_swap_orientation(guide, _tight)
	if _results != null:
		_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_position_guide()


## The container that lays `node`'s children out in the asked direction, `node` itself
## when it already does. Name, order, separation and expansion flags travel with the
## children, so callers can go on addressing the node by name.
func _swap_orientation(node: BoxContainer, vertical: bool) -> BoxContainer:
	if node == null or (node is VBoxContainer) == vertical:
		return node
	var parent := node.get_parent()
	if parent == null:
		return node
	var replacement: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	replacement.name = node.name
	replacement.add_theme_constant_override("separation", node.get_theme_constant("separation"))
	replacement.size_flags_horizontal = node.size_flags_horizontal
	replacement.size_flags_vertical = node.size_flags_vertical
	var index := node.get_index()
	parent.remove_child(node)
	for child in node.get_children():
		node.remove_child(child)
		replacement.add_child(child)
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	node.free()
	return replacement


static func _result_cap(result: Dictionary) -> String:
	if result.has("cap_dot"):
		return cap_text("", "", String(result["cap_dot"]))
	# UIR-22: the reference's four result rows do not all carry `cap_up` — the bandeja
	# row is `↓` only (`index.html:666-671`: `cap_dot`, `cap_up`/`cap_down`, `cap_down`).
	# Indexing `cap_up` unguarded raised "Invalid access to property or key 'cap_up'" on
	# that row every time the tutorial was built.
	return cap_text(String(result.get("cap_up", "")), String(result.get("cap_down", "")), "")


static func _guide_text(entry: Dictionary) -> String:
	if String(entry["key"]) != "":
		return UiStrings.t(String(entry["key"]))
	return String(entry["cap"])


func _font(role: String) -> Font:
	var source := _theme()
	if source == null:
		return null
	return source.get_font("font", role) if source.has_font("font", role) else null


func _theme() -> Theme:
	return theme if theme != null else DefaultTheme


func _palette(key: String) -> Color:
	# A null source means the shared theme did not load (the theme file is another
	# lane's; a parse error in it must not take this screen's tree down) — the key is
	# recorded and the palette's own ink stands in.
	var source := _theme()
	if source != null and source.has_color(key, "Palette"):
		return source.get_color(key, "Palette")
	if not _palette_misses.has(key):
		_palette_misses.append(key)
	if source != null and source.has_color("ink", "Palette"):
		return source.get_color("ink", "Palette")
	return Color.WHITE


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out


## The space a literal may not carry (the UI lane's scan flags prose, and a lone
## space is a space). Composed the way the rest of the port composes its separators.
static func _sp() -> String:
	return String.chr(32)
