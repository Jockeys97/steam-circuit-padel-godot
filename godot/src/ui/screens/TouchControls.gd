## TouchControls.gd — UIR-26: the coarse-pointer layer, the action deck and the
## seven-button touch pad.
##
## WHAT THIS IS. `index.html:482-495` (`.action-deck`, `.touch-controls`),
## `styles.css:807-844` (the deck), `:1081-1099` (the pad) and the three media
## rules at `:2058-2085` — `pointer: fine` hides the deck, `pointer: coarse` with a
## 681 px frame shows it, and a 680 px frame shows the pad instead.
##
## THE ONE PATH. Touch press/release injects the SAME input actions the keyboard and
## the pad use (`padel_drive` for the shot, `padel_switch`, `padel_special`,
## `padel_up/down/left/right`), through `Input.action_press`/`Input.action_release`:
## the reference's own `data-dir` contract, mapped once, here, and recorded. No
## `InputEventScreenTouch` is synthesised and no second mapping table exists — the
## ticket asks for one path and this is it (the other route, a screen-touch event
## re-parsed into actions, is the one the port already has in `input_map.gd` for a
## real touchscreen; injecting the action is the path that cannot drift from it).
##
## WHAT THE SAMPLER SEES, SAID PLAINLY. `input_map.gd`'s keyboard sampler reads
## physical key state (`_key_pressed`) and its pad sampler reads real joypad axes and
## buttons, so an injected ACTION reaches the sim only where the sim already reads
## actions. The mapping table here is the contract the engine owner has to accept;
## it is recorded as a seam request in `evidence/uir-26-osk-touch.md`, not smuggled
## into a lane this ticket does not own.
##
## VISIBILITY. Godot has no `(pointer: coarse)` media query: `set_coarse_pointer()`
## is the mount's answer (`DisplayServer.is_touchscreen_available()` is the default),
## and `set_frame_width()` — or the control's own `size.x` — drives the 680 px rule.
## A desktop machine with a mouse is the `pointer: fine` branch, and the deck is
## hidden there, exactly as `styles.css:2058-2062` says.
##
## LITERALS. The glyphs are the reference's own markup characters (▲ ◀ ▶ ▼ ⇄ ✦ ◒ and
## the `HIT` cap); the labels are locale ids (`shot`/`switch`/`special`). A glyph is
## not prose and carries no space, so the UI-lane scan stays meaningful.
##
## STATIC CHECKS ONLY in this wave; the acceptance command is in
## `evidence/uir-26-osk-touch.md`.
extends Control

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

signal action_pressed(action: String)
signal action_released(action: String)

## `.action-deck` (`index.html:483-486`), in markup order: `data-dir`, the action it
## stands for, the glyph and the label id. `hit` is the shot button, so it stands on
## the drive action (`input_map.gd`'s `PAD_DRIVE := JOY_BUTTON_A`).
const DECK := [
	{"dir": "hit", "action": "padel_drive", "glyph": "◒", "label_id": "shot", "aria": "shot"},
	{"dir": "switch", "action": "padel_switch", "glyph": "⇄", "label_id": "switch", "aria": "switchBtn"},
	{"dir": "special", "action": "padel_special", "glyph": "✦", "label_id": "special", "aria": "specialBtn"},
]
## `.touch-controls` (`index.html:488-494`), in markup order. The pad's own aria ids
## differ from the deck's on two buttons (`shot`, `switchBtn`, `dirSpecial`).
const PAD := [
	{"dir": "up", "action": "padel_up", "glyph": "▲", "aria": "dirUp"},
	{"dir": "left", "action": "padel_left", "glyph": "◀", "aria": "dirLeft"},
	{"dir": "hit", "action": "padel_drive", "glyph": "HIT", "aria": "shot"},
	{"dir": "right", "action": "padel_right", "glyph": "▶", "aria": "dirRight"},
	{"dir": "down", "action": "padel_down", "glyph": "▼", "aria": "dirDown"},
	{"dir": "switch", "action": "padel_switch", "glyph": "⇄", "aria": "switchBtn"},
	{"dir": "special", "action": "padel_special", "glyph": "⚡", "aria": "dirSpecial"},
]

## `.action-deck` (`styles.css:807-814`): 16 px from the right, 18 from the bottom.
const DECK_MARGIN_X := 16.0
const DECK_MARGIN_Y := 18.0
## `.action-deck button` (`styles.css:816-830`): 70 px square, 3 px border, 8 px radius.
const DECK_SIZE := 70.0
const DECK_GAP := 8.0
## `.action-deck b` / `.action-deck span` (`styles.css:839-848`).
const DECK_GLYPH_SIZE := 23
const DECK_LABEL_SIZE := 9
## `.touch-controls` (`styles.css:1081-1099`): 12 px from the right and the bottom,
## 52x44 minimum buttons.
const PAD_MARGIN := 12.0
const PAD_GAP := 8.0
const PAD_MIN := Vector2(52.0, 44.0)
const PAD_FONT_SIZE := 14

## `@media (max-width: 680px)` (`styles.css:2070-2078`): the frame that shows the pad.
const PAD_MAX_WIDTH := 680.0
## `@media (pointer: coarse) and (min-width: 681px)` (`styles.css:2064-2068`).
const DECK_MIN_WIDTH := 681.0

const NODE_DECK := "ActionDeck"
const NODE_PAD := "TouchPad"

var _built := false
var _coarse := false
var _frame_width := 0.0
var _palette_misses: Array = []
var _missing_actions: Array = []
var _deck: HBoxContainer
var _pad: HBoxContainer
var _deck_buttons: Dictionary = {}
var _pad_buttons: Dictionary = {}
var _held: Array = []


func _ready() -> void:
	_coarse = DisplayServer.is_touchscreen_available()
	_ensure()
	resized.connect(_apply_layout)


# ---------------------------------------------------------------------------
# The mount's contract
# ---------------------------------------------------------------------------

## The mount's answer to `(pointer: coarse)`. The default is the engine's own answer
## for the machine it runs on; a mount that knows better (a Deck in desktop mode, a
## laptop without touch) says so.
func set_coarse_pointer(coarse: bool) -> void:
	_coarse = coarse
	_ensure()
	_apply_layout()


func coarse_pointer() -> bool:
	return _coarse


## The frame the media rules measure. The control's own width is the default, so a
## mount that lets it fill the viewport has nothing to call.
func set_frame_width(width: float) -> void:
	_frame_width = width
	_ensure()
	_apply_layout()


func frame_width() -> float:
	return _frame_width if _frame_width > 0.0 else size.x


## `styles.css:2058-2085`: the deck only for a coarse pointer on a 681 px-or-wider
## frame, the pad on a 680 px-or-narrower one. Returns both verdicts so the audit and
## the log can read them without asking the tree.
func apply_visibility() -> Dictionary:
	_ensure()
	_apply_layout()
	return {
		"deck": _deck.visible if _deck != null else false,
		"pad": _pad.visible if _pad != null else false,
		"coarse": _coarse,
		"width": frame_width(),
	}


func deck() -> HBoxContainer:
	_ensure()
	return _deck


func pad() -> HBoxContainer:
	_ensure()
	return _pad


## Every button of both blocks, by `data-dir`, for the audit and the mount.
func deck_buttons() -> Dictionary:
	_ensure()
	return _deck_buttons


func pad_buttons() -> Dictionary:
	_ensure()
	return _pad_buttons


## The action a `data-dir` stands for, from the tables above.
static func action_for_dir(dir: String) -> String:
	for entry in DECK:
		if String(entry["dir"]) == dir:
			return String(entry["action"])
	for entry in PAD:
		if String(entry["dir"]) == dir:
			return String(entry["action"])
	return ""


## Every string this layer owns, re-resolved: the deck's three labels and the ten
## screen-reader names. The touch buttons' own text is the reference's glyphs, not
## locale text.
func refresh_strings() -> void:
	_ensure()
	for entry in DECK:
		var button: Button = _deck_buttons.get(String(entry["dir"]), null)
		if button == null:
			continue
		var label := button.get_node_or_null("DeckStack/DeckLabel") as Label
		if label != null:
			label.text = UiStrings.t(String(entry["label_id"]))
		_set_accessible_name(button, UiStrings.t(String(entry["aria"])))
	for entry in PAD:
		var button: Button = _pad_buttons.get(String(entry["dir"]), null)
		if button == null:
			continue
		_set_accessible_name(button, UiStrings.t(String(entry["aria"])))
	_set_accessible_name(_deck, UiStrings.t("ariaActionDeck"))
	_set_accessible_name(_pad, UiStrings.t("ariaTouch"))


## The language *choice* and its persistence are the settings screen's (`Locale` is
## the shared seam); this door re-resolves what this layer owns.
func set_language(lang: String) -> bool:
	if not Locale.has_locale(lang):
		return false
	Locale.set_lang(lang)
	refresh_strings()
	return true


# ---------------------------------------------------------------------------
# Presses — one path: the action
# ---------------------------------------------------------------------------

## A press on a button: `Input.action_press` on the mapped action. Already-held
## actions are not re-pressed (`opposite dir` buttons can be held together, the
## reference's own behaviour: `button_down` fires per button).
func press_action(action: String) -> bool:
	if not InputMap.has_action(action):
		if not _missing_actions.has(action):
			_missing_actions.append(action)
		return false
	if _held.has(action):
		return false
	_held.append(action)
	Input.action_press(action)
	action_pressed.emit(action)
	return true


func release_action(action: String) -> bool:
	if not _held.has(action):
		return false
	_held.erase(action)
	if InputMap.has_action(action):
		Input.action_release(action)
	action_released.emit(action)
	return true


## Everything this control is holding, released — the mount calls it when the layer
## is hidden or the match pauses, so a finger that lifted over a hidden button cannot
## leave an action stuck down.
func release_all() -> Array:
	var released := _held.duplicate()
	for action in released:
		release_action(String(action))
	return released


func held_actions() -> Array:
	return _held.duplicate()


func report() -> Dictionary:
	return {
		"coarse": _coarse,
		"frame_width": frame_width(),
		"deck_visible": _deck.visible if _deck != null else false,
		"pad_visible": _pad.visible if _pad != null else false,
		"held": _held.duplicate(),
		"missing_actions": _missing_actions.duplicate(),
		"palette_misses": _palette_misses.duplicate(),
	}


func palette_keys() -> Array:
	return ["deck_hit_border", "deck_hit_fill", "deck_hit_shadow", "deck_switch_fill",
		"deck_special_fill", "deck_special_border", "deck_special_shadow",
		"touch_button_bg", "line", "ink", "white"]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


## The name this layer hands the platform's screen reader per button — the resolved
## `data-i18n-aria` of the reference's markup (`index.html:483-494`).
func aria_ids() -> Dictionary:
	var out := {}
	for entry in DECK:
		out[String(entry["dir"])] = String(entry["aria"])
	for entry in PAD:
		out["pad-%s" % String(entry["dir"])] = String(entry["aria"])
	return out


func aria_text_for(dir: String) -> String:
	var aria := String(aria_ids().get(dir, ""))
	return UiStrings.t(aria) if aria != "" else ""


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_build()
	_apply_layout()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck = HBoxContainer.new()
	_deck.name = NODE_DECK
	_deck.add_theme_constant_override("separation", int(DECK_GAP))
	_deck.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(DECK_MARGIN_X))
	_deck.offset_bottom -= DECK_MARGIN_Y - DECK_MARGIN_X
	_deck.offset_top -= DECK_MARGIN_Y - DECK_MARGIN_X
	_deck.set_meta("aria_key", "ariaActionDeck")
	add_child(_deck)
	for index in DECK.size():
		var entry: Dictionary = DECK[index]
		var button := _deck_button(entry, index)
		_deck.add_child(button)
		_deck_buttons[String(entry["dir"])] = button
	_set_accessible_name(_deck, UiStrings.t("ariaActionDeck"))
	_pad = HBoxContainer.new()
	_pad.name = NODE_PAD
	_pad.add_theme_constant_override("separation", int(PAD_GAP))
	_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(PAD_MARGIN))
	_pad.set_meta("aria_key", "ariaTouch")
	add_child(_pad)
	for index in PAD.size():
		var entry: Dictionary = PAD[index]
		var button := _pad_button(entry, index)
		_pad.add_child(button)
		_pad_buttons[String(entry["dir"])] = button
	_set_accessible_name(_pad, UiStrings.t("ariaTouch"))


## `.action-deck button` (`styles.css:816-837`): the glyph above the label, the three
## fills, the hard `0 5px 0` step shadow. The reference's inset highlight
## (`inset 0 4px 0 rgba(255,255,255,0.28)`) has no `StyleBoxFlat` equivalent that can
## sit under the text on all four sides — recorded as a gap in the evidence log.
func _deck_button(entry: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Deck%s" % String(entry["dir"]).capitalize()
	button.text = ""
	button.custom_minimum_size = Vector2(DECK_SIZE, DECK_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	for slot in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(String(slot), _deck_box(index))
	var stack := VBoxContainer.new()
	stack.name = "DeckStack"
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	button.add_child(stack)
	var glyph := Label.new()
	glyph.name = "DeckGlyph"
	glyph.text = String(entry["glyph"])
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_override("font", _font("HeroTitle"))
	glyph.add_theme_font_size_override("font_size", DECK_GLYPH_SIZE)
	glyph.add_theme_color_override("font_color", _palette("white"))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(glyph)
	var label := Label.new()
	label.name = "DeckLabel"
	label.text = UiStrings.t(String(entry["label_id"]))
	label.set_meta("message_id", String(entry["label_id"]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font("HeroTitle"))
	label.add_theme_font_size_override("font_size", DECK_LABEL_SIZE)
	label.add_theme_color_override("font_color", _palette("white"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label)
	_wire(button, String(entry["action"]))
	_set_accessible_name(button, UiStrings.t(String(entry["aria"])))
	return button


## `.touch-controls button` (`styles.css:1089-1098`): 52x44, `--line`, the 0.88 dark
## fill, `--ink`.
func _pad_button(entry: Dictionary, index: int) -> Button:
	var button := Button.new()
	button.name = "Pad%s" % String(entry["dir"]).capitalize()
	button.text = String(entry["glyph"])
	button.custom_minimum_size = PAD_MIN
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font("LabelSmall"))
	button.add_theme_font_size_override("font_size", PAD_FONT_SIZE)
	button.add_theme_color_override("font_color", _palette("ink"))
	button.add_theme_color_override("font_hover_color", _palette("ink"))
	button.add_theme_color_override("font_pressed_color", _palette("ink"))
	for slot in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(String(slot), _pad_box(slot))
	_wire(button, String(entry["action"]))
	_set_accessible_name(button, UiStrings.t(String(entry["aria"])))
	return button


## `button_down`/`button_up` are the port's press and release: the reference's
## buttons take a pointer down and a pointer up, and a drag off the button cancels —
## Godot's own `BaseButton` semantics, so the two agree without a rule of our own.
func _wire(button: Button, action: String) -> void:
	button.button_down.connect(press_action.bind(action))
	button.button_up.connect(release_action.bind(action))


## The deck's three fills (`styles.css:816-837`): the shot teal, the switch blue, the
## special orange, each with its own border and step shadow. The reference defines no
## hover or active rule for these buttons, so neither does this file.
func _deck_box(index: int) -> StyleBoxFlat:
	var fills := ["deck_hit_fill", "deck_switch_fill", "deck_special_fill"]
	var borders := ["deck_hit_border", "deck_hit_border", "deck_special_border"]
	var shadows := ["deck_hit_shadow", "deck_hit_shadow", "deck_special_shadow"]
	var box := StyleBoxFlat.new()
	box.bg_color = _palette(String(fills[index]))
	box.border_color = _palette(String(borders[index]))
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	box.shadow_color = _palette(String(shadows[index]))
	box.shadow_offset = Vector2(0.0, 5.0)
	box.shadow_size = 0
	return box


## `.touch-controls button` (`styles.css:1089-1098`): the same fill for every state —
## the reference defines no hover rule here either.
func _pad_box(_slot: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("touch_button_bg")
	box.border_color = _palette("line")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	return box


## `styles.css:2058-2085`, applied. The frame the rules measure is the mount's
## (`set_frame_width`) or this control's own width.
func _apply_layout() -> void:
	if _deck == null or _pad == null:
		return
	var width := frame_width()
	if width <= 0.0:
		width = 1280.0
	var was_deck := _deck.visible
	var was_pad := _pad.visible
	_deck.visible = _coarse and width >= DECK_MIN_WIDTH
	_pad.visible = width <= PAD_MAX_WIDTH
	if (was_deck and not _deck.visible) or (was_pad and not _pad.visible):
		release_all()
	if not _deck.visible:
		_deck.hide()
	if not _pad.visible:
		_pad.hide()
	if not _deck.visible and not _pad.visible:
		return
	# Anchored blocks keep their corner; the preset already pinned them.
	_deck.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(DECK_MARGIN_X))
	_deck.offset_bottom -= DECK_MARGIN_Y - DECK_MARGIN_X
	_deck.offset_top -= DECK_MARGIN_Y - DECK_MARGIN_X
	_pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(PAD_MARGIN))


func _set_accessible_name(node: Node, text: String) -> void:
	if node == null or text == "":
		return
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == "accessibility_name":
			node.set("accessibility_name", text)
			return


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
