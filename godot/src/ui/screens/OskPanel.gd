## OskPanel.gd — UIR-26: the on-screen keyboard's visual grid, over the existing
## `godot/src/input/osk.gd` model. It renders; it never rules.
##
## WHAT THIS IS. `index.html:700-708` (`#osk`, `#oskLabel`, `#oskPreview`,
## `#oskGrid`), the CSS block at `styles.css:3471-3580` and the 560 px rule at
## `:3577-3582`; the behaviour is `js/main.js`'s `buildOsk` (`:475-509`),
## `openOsk` (`:510-531`), `closeOsk` (`:533-542`) and the insert/delete rules
## (`:457-473`) — all of which the port already owns as a MODEL
## (`godot/src/input/osk.gd`, wired into `menu_nav.gd:148-231` and asserted by
## `gamepad_nav_audit.gd`'s `nav/osk_*` checks).
##
## THE ONE PATH. The panel is a view: every press goes through the model
## (`press_char`, `press`, `toggle_shift`), and every visible fact is read back from
## it (`rows()`, `value()`, `label()`, `aria_label()`, `shift()`, `is_open()`).
## The panel never writes a string itself and never keeps a second copy of the text.
##
## THE MOUNT'S RECIPE (names asserted by `osk_touch_audit.gd`):
##
##   panel = OskPanel.tscn instantiate, added over everything (the OSK is z 60)
##   panel.bind_model(menu_nav.osk)                  # the model is the input lane's
##   panel.set_language(...)                         # optional: re-resolve
##
##   when the model opens (the mount's `menu_nav.confirm()` answered
##   {"kind": "osk_open"}):  panel.refresh() ; menu_nav.set_osk_targets(panel.osk_key_targets())
##   on every edit:          panel.refresh() ; the field takes model.value()
##                           (the reference writes straight into the field,
##                           `js/main.js:463-466`; in the port the screen owns the
##                           write, `FeedbackScreen.apply_osk_value`)
##   on {"kind": "osk_close"} (back closed it): panel.refresh()
##   on panel.closed(target): menu_nav.set_osk_targets([]) then focus the field back
##                            (the model's own closeOsk hand-off, `js/main.js:533-542`)
##
## The panel's `osk_key_targets()` uses the same ids the feedback screen already
## offers (`osk/<char>`, `osk/<action>`, `FeedbackScreen.osk_key_targets`), so one
## driver serves both, and it carries live rects because this panel really does lay
## the grid out — the geometric navigation lands on the key the player sees.
##
## THE DECISION THIS TICKET WAITED FOR. The grid was marked a postponed platform
## decision (`osk.gd` header; `docs/wayfinder/tickets/product-scope-and-platforms.md`).
## The KEPT path is built here on the user's explicit direction for this wave; the
## decision's own record stays with its owner (the evidence file quotes the direction
## verbatim and says what is NOT claimed: no device test, no touch hardware).
##
## LITERALS. Every string comes from the model (locale ids). The one glyph the panel
## owns is the reference's empty-preview `…` (`styles.css:3523-3526`, a CSS `content`
## value); it carries no space, so the UI-lane prose scan stays meaningful.
##
## STATIC CHECKS ONLY in this wave; the acceptance command is in
## `evidence/uir-26-osk-touch.md`.
extends Control

const Osk := preload("res://src/input/osk.gd")
const Locale := preload("res://src/locale/locale.gd")
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

## Emitted after an edit that kept the keyboard open (the mount re-reads the value).
signal changed
## Emitted after a `done` press closed the model, with the field to focus back —
## `closeOsk`'s hand-off (`js/main.js:533-542`).
signal closed(target_id: String)

## `.osk__preview:empty::after { content: "…" }` (`styles.css:3523-3526`).
const EMPTY_GLYPH := "…"

## `.osk` (`styles.css:3471-3485`): inset 0, 24 px padding, the panel at the bottom.
const SCRIM_PADDING := 24.0
## `.osk__panel` (`styles.css:3487-3494`).
const PANEL_WIDTH := 760.0
const PANEL_RADIUS := 16
## `.osk__preview` (`styles.css:3512-3518`): `min-height: 2.6em`.
const PREVIEW_MIN_HEIGHT := 42.0
## `.osk__key` (`styles.css:3540-3549`): 44 px tall, 8 px radius, 0.9rem.
const KEY_HEIGHT := 44.0
const KEY_FONT := 14
## `@media (max-width: 560px) .osk__key` (`styles.css:3577-3582`): 38 px, 0.8rem.
const COMPACT_PX := 560.0
const KEY_HEIGHT_COMPACT := 38.0
const KEY_FONT_COMPACT := 13
## `.osk__row--actions .osk__key` (`styles.css:3560-3564`): 0.72rem.
const ACTION_KEY_FONT := 12
## `.osk__row--actions` (`styles.css:3567-3570`): `1fr 2.4fr 1fr 1fr`.
const ACTION_STRETCH := [1.0, 2.4, 1.0, 1.0]
## `.osk__grid` / `.osk__row` (`styles.css:3528-3538`): 6 px gaps.
const GAP := 6.0
## `.osk__head` (`styles.css:3496-3500`): 6 px gap, 14 px under it.
const HEAD_GAP := 6.0
const HEAD_MARGIN := 14.0

const NODE_SCRIM := "OskScrim"
const NODE_PANEL := "OskPanelBox"
const NODE_LABEL := "OskLabel"
const NODE_PREVIEW := "OskPreview"
const NODE_PREVIEW_TEXT := "OskPreviewText"
const NODE_GRID := "OskGrid"

const CAPTURE_STATES: Array[String] = ["default"]

var _built := false
var _model: Osk = null
var _compact := false
var _palette_misses: Array = []
var _scrim: Panel
var _panel: PanelContainer
var _label: Label
var _preview: Label
var _grid: VBoxContainer
var _keys: Dictionary = {}
var _action_keys: Dictionary = {}
var _char_buttons: Array = []


func _ready() -> void:
	_ensure()
	resized.connect(_apply_layout)


# ---------------------------------------------------------------------------
# The mount's contract
# ---------------------------------------------------------------------------

## The model to render. Required: without it the panel shows nothing and says so in
## `report()` rather than inventing a grid of its own. Binding after the panel is in
## the tree is fine — the grid is rebuilt from the model's own rows.
func bind_model(model: Osk) -> void:
	_model = model
	_ensure()
	_rebuild_grid()
	refresh()


func model() -> Osk:
	return _model


## Read the model back into the view: visibility, label, preview, key labels, the
## shift state. Safe to call before the model exists (it renders hidden).
func refresh() -> void:
	_ensure()
	var open := _model != null and _model.is_open()
	visible = open
	if not open:
		return
	_label.text = _model.label()
	var value := _model.value()
	_preview.text = value if value != "" else EMPTY_GLYPH
	_preview.add_theme_color_override("font_color", _palette("ink") if value != "" else _palette("muted"))
	var rows := _model.rows()
	for row_index in rows.size():
		var row: Dictionary = rows[row_index]
		var keys: Array = row.get("keys", [])
		if String(row.get("kind", "")) == "chars":
			for key_index in keys.size():
				var entry: Dictionary = keys[key_index]
				var button: Button = _chars_row_button(row_index, key_index)
				if button != null:
					button.text = String(entry.get("label", entry.get("char", "")))
		else:
			for entry in keys:
				var button: Button = _action_keys.get(String(entry.get("id", "")), null)
				if button != null:
					button.text = String(entry.get("label", ""))
	_style_shift(_model.shift())
	_set_accessible_name(self, _model.aria_label())


## The panel's own strings are the model's, so a language flip only needs the locale
## set and the view re-read. The *choice* and its persistence are the settings
## screen's (`SettingsScreen.set_language`); this door exists for the harness and for
## the mount that already knows the language changed.
func set_language(lang: String) -> bool:
	if not Locale.has_locale(lang):
		return false
	Locale.set_lang(lang)
	refresh()
	return true


func is_open() -> bool:
	return _model != null and _model.is_open()


## The keyboard's own name for a screen reader (`ariaOsk`), resolved by the model.
func aria_text() -> String:
	return _model.aria_label() if _model != null else ""


func report() -> Dictionary:
	return {
		"model_bound": _model != null,
		"open": is_open(),
		"shift": _model.shift() if _model != null else false,
		"compact": _compact,
		"targets": osk_key_targets().size(),
		"palette_misses": _palette_misses.duplicate(),
	}


func capture_states() -> Array:
	return CAPTURE_STATES.duplicate()


func apply_capture_state(state_id: String) -> bool:
	if state_id != "default":
		return false
	refresh()
	return is_open()


func palette_keys() -> Array:
	return ["osk_scrim", "cyan", "surface_0", "surface_1", "surface_2", "tab_border",
		"text_soft_2", "segmented_gradient_start", "ink", "muted"]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# Presses — the model's own vocabulary
# ---------------------------------------------------------------------------

## A character key: `oskInsert(oskShift ? ch.toUpperCase() : ch)` (`js/main.js:486`).
func press_char(char: String) -> bool:
	_ensure()
	if _model == null:
		return false
	var field := _model.target_id()
	var accepted := _model.press_char(char)
	_after_press(accepted, field)
	return accepted


## An action key: `shift` / `space` / `backspace` / `done` (`js/main.js:493-498`).
## The model answers what happened; a `done` that closed the keyboard emits `closed`
## with the field to focus back.
func press(key_id: String) -> String:
	_ensure()
	if _model == null:
		return ""
	var field := _model.target_id()
	var result := _model.press(key_id)
	_after_press(result != "", field)
	return result


## The id a driver sees in `osk_key_targets()`, pressed. `osk/q`, `osk/à`… and
## `osk/shift`, `osk/done`. Returns whether the id named a key of this panel.
func press_target(target_id: String) -> bool:
	_ensure()
	if not _keys.has(target_id):
		return false
	var char := target_id.substr(target_id.rfind("/") + 1)
	if _action_keys.has(char):
		press(char)
		return true
	press_char(char)
	return true


## The nav-shaped targets `MenuNav.set_osk_targets()` wants, in the reference's own
## key order (five character rows, then the action row). The ids match the feedback
## screen's door (`osk/<char>`, `osk/<action>`); the rects are the laid-out buttons'
## own, so the geometric navigation moves across the grid the player sees.
##
## Empty while the keyboard is closed: the grid is not navigable then, and the mount
## registers targets only on open (`main_menu._sync_osk` sets `[]` back on close).
func osk_key_targets() -> Array:
	_ensure()
	if not is_open():
		return []
	var out: Array = []
	var rows := _model.rows() if _model != null else []
	for row in rows:
		var entry: Dictionary = row
		for key in entry.get("keys", []):
			var key_entry: Dictionary = key
			var name := String(key_entry.get("char", key_entry.get("id", "")))
			var button: Button = _keys.get(_target_id(name), null)
			out.append(_osk_target(_target_id(name), button))
	return out


## The Control behind a target id, for the mount's focus painter.
func key_node(target_id: String) -> Control:
	_ensure()
	return _keys.get(target_id, null)


## The first key of the grid takes the focus, as `ensureMenuFocus()` does after
## `openOsk` (`js/main.js:529-531`). Returns the node that took it, or null.
func focus_first_key() -> Control:
	_ensure()
	var rows := _model.rows() if _model != null else []
	for row in rows:
		var entry: Dictionary = row
		for key in entry.get("keys", []):
			var key_entry: Dictionary = key
			var name := String(key_entry.get("char", key_entry.get("id", "")))
			var button: Button = _keys.get(_target_id(name), null)
			if button != null:
				button.grab_focus()
				return button
	return null


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_build()
	_rebuild_grid()
	refresh()
	_apply_layout()


func _build() -> void:
	_scrim = Panel.new()
	_scrim.name = NODE_SCRIM
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.add_theme_stylebox_override("panel", _scrim_box())
	add_child(_scrim)
	var margin := MarginContainer.new()
	margin.name = "OskMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, int(SCRIM_PADDING))
	_scrim.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "OskColumn"
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var row := HBoxContainer.new()
	row.name = "OskCenter"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	_panel = PanelContainer.new()
	_panel.name = NODE_PANEL
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.add_theme_stylebox_override("panel", _panel_box())
	row.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.name = "OskStack"
	stack.add_theme_constant_override("separation", HEAD_MARGIN)
	_panel.add_child(stack)
	_build_head(stack)
	_build_grid(stack)


## `.osk__head` (`styles.css:3496-3522`): the label above, the preview under it.
func _build_head(parent: Control) -> void:
	var head := VBoxContainer.new()
	head.name = "OskHead"
	head.add_theme_constant_override("separation", int(HEAD_GAP))
	parent.add_child(head)
	_label = Label.new()
	_label.name = NODE_LABEL
	_label.add_theme_font_override("font", _font("LabelSmall"))
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", _palette("text_soft_2"))
	head.add_child(_label)
	var preview := PanelContainer.new()
	preview.name = NODE_PREVIEW
	preview.custom_minimum_size = Vector2(0.0, PREVIEW_MIN_HEIGHT)
	preview.add_theme_stylebox_override("panel", _preview_box())
	head.add_child(preview)
	_preview = Label.new()
	_preview.name = NODE_PREVIEW_TEXT
	_preview.add_theme_font_override("font", _font("CardBody"))
	_preview.add_theme_font_size_override("font_size", 14)
	_preview.add_theme_color_override("font_color", _palette("ink"))
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(_preview)


## `.osk__grid` (`styles.css:3528-3538`): five equal-column rows and the action row.
func _build_grid(parent: Control) -> void:
	_grid = VBoxContainer.new()
	_grid.name = NODE_GRID
	_grid.add_theme_constant_override("separation", int(GAP))
	parent.add_child(_grid)


## The grid, built from the model's own rows (`buildOsk`, `js/main.js:475-509`).
## A rebuild replaces every button, so the key map and the targets follow the model
## the panel is actually bound to.
func _rebuild_grid() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_keys.clear()
	_action_keys.clear()
	_char_buttons.clear()
	if _model == null:
		return
	var rows := _model.rows()
	for row_index in rows.size():
		var entry: Dictionary = rows[row_index]
		var keys: Array = entry.get("keys", [])
		if String(entry.get("kind", "")) == "chars":
			var line := HBoxContainer.new()
			line.name = "OskRow%s" % str(row_index + 1)
			line.add_theme_constant_override("separation", int(GAP))
			_grid.add_child(line)
			for key in keys:
				var key_entry: Dictionary = key
				var button := _key_button(String(key_entry.get("char", "")))
				button.pressed.connect(_on_char_pressed.bind(String(key_entry.get("char", ""))))
				line.add_child(button)
				_char_buttons.append(button)
		else:
			var actions := HBoxContainer.new()
			actions.name = "OskRowActions"
			actions.add_theme_constant_override("separation", int(GAP))
			_grid.add_child(actions)
			for index in keys.size():
				var key_entry: Dictionary = keys[index]
				var id := String(key_entry.get("id", ""))
				var button := _key_button(id)
				button.add_theme_font_size_override("font_size", ACTION_KEY_FONT)
				if index < ACTION_STRETCH.size():
					button.size_flags_stretch_ratio = ACTION_STRETCH[index]
				button.pressed.connect(_on_action_pressed.bind(id))
				actions.add_child(button)
				_action_keys[id] = button
	_style_shift(_model.shift())


func _key_button(text: String) -> Button:
	var button := Button.new()
	button.name = "Key%s" % text
	button.text = text
	button.custom_minimum_size = Vector2(0.0, KEY_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", _font("LabelSmall"))
	button.add_theme_font_size_override("font_size", KEY_FONT)
	for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(String(slot), _key_box(slot))
	button.add_theme_color_override("font_color", _palette("ink"))
	button.add_theme_color_override("font_hover_color", _palette("ink"))
	button.add_theme_color_override("font_pressed_color", _palette("ink"))
	_keys[_target_id(text)] = button
	return button


## A character row's button by position — `refresh()` walks the model's rows and this
## is the same order, because the buttons were built from it.
func _chars_row_button(row_index: int, key_index: int) -> Button:
	var line := _grid.get_node_or_null("OskRow%s" % str(row_index + 1))
	if line == null:
		return null
	var child := line.get_child(key_index)
	return child as Button


## `.osk__key--shift.is-active` / `.osk__key--done` (`styles.css:3555-3567`): the
## segmented gradient's first stop with `surface_0` text — the theme's own documented
## collapse of `linear-gradient(180deg,#22d5ee,#16bed7)` to its first stop (`theme README §6.1`).
func _style_shift(active: bool) -> void:
	var shift: Button = _action_keys.get("shift", null)
	if shift != null:
		for slot in ["normal", "hover", "pressed", "focus"]:
			shift.add_theme_stylebox_override(String(slot), _active_key_box() if active else _key_box(slot))
		var color := _palette("surface_0") if active else _palette("ink")
		for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
			shift.add_theme_color_override(String(slot), color)
	var done: Button = _action_keys.get("done", null)
	if done != null:
		for slot in ["normal", "hover", "pressed", "focus"]:
			done.add_theme_stylebox_override(String(slot), _active_key_box())
		for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
			done.add_theme_color_override(String(slot), _palette("surface_0"))


func _on_char_pressed(char: String) -> void:
	press_char(char)


func _on_action_pressed(key_id: String) -> void:
	press(key_id)


## `field` is the target id captured BEFORE the press: `done` closes the model and
## `close()` clears `target_id()` (`osk.gd:85-94`), so reading it after the press
## would lose the field the keyboard was opened for.
func _after_press(accepted: bool, field: String) -> void:
	refresh()
	if not is_open():
		closed.emit(field)
		return
	if accepted:
		changed.emit()


## `@media (max-width: 560px)` (`styles.css:3577-3582`): the keys shrink to 38 px and
## 0.8rem; the panel is `min(760px, 100%)` of the scrim's padded box at every width
## (`styles.css:3487-3494`).
func _apply_layout() -> void:
	if _panel == null:
		return
	var width := size.x
	if width <= 0.0:
		width = 1280.0
	_compact = width <= COMPACT_PX
	_panel.custom_minimum_size.x = minf(PANEL_WIDTH, maxf(0.0, width - SCRIM_PADDING * 2.0))
	for button in _char_buttons:
		var control := button as Button
		control.custom_minimum_size.y = KEY_HEIGHT_COMPACT if _compact else KEY_HEIGHT
		control.add_theme_font_size_override("font_size", KEY_FONT_COMPACT if _compact else KEY_FONT)
	for id in _action_keys:
		(_action_keys[id] as Button).custom_minimum_size.y = KEY_HEIGHT_COMPACT if _compact else KEY_HEIGHT


## `.osk` (`styles.css:3471-3481`): `rgba(4,8,24,0.72)`. The `backdrop-filter: blur(6px)`
## is a browser compositing effect with no Godot equivalent on a Control — recorded as
## a gap in the evidence log, not faked with a second overlay.
func _scrim_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("osk_scrim")
	return box


## `.osk__panel` (`styles.css:3487-3494`): `surface_2` at 0.97 (the gradient's first
## stop, the theme's documented collapse), the cyan border at 0.32, the 16 px radius
## and the `0 26px 60px rgba(0,0,0,0.5)` shadow.
func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("surface_2"), 0.97)
	box.border_color = _alpha(_palette("cyan"), 0.32)
	box.set_border_width_all(1)
	box.set_corner_radius_all(PANEL_RADIUS)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 18.0
	box.shadow_color = _palette("shadow")
	box.shadow_offset = Vector2(0.0, 26.0)
	box.shadow_size = 60
	return box


## `.osk__preview` (`styles.css:3512-3518`).
func _preview_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("surface_1")
	box.border_color = _palette("tab_border")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


## `.osk__key` (`styles.css:3540-3558`): `tab_border`, radius 8, `surface_2` for the
## reference's `#0d2646` (a 2/255-per-channel near-match, recorded), the cyan hover.
func _key_box(slot: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if slot == "hover" or slot == "focus":
		box.bg_color = _alpha(_palette("cyan"), 0.16)
	else:
		box.bg_color = _palette("surface_2")
	box.border_color = _palette("tab_border")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 2.0
	box.content_margin_right = 2.0
	return box


## The shift/done active look: the segmented gradient's first stop, `surface_0` text.
func _active_key_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("segmented_gradient_start")
	box.set_corner_radius_all(8)
	box.content_margin_left = 2.0
	box.content_margin_right = 2.0
	return box


func _target_id(name: String) -> String:
	return "osk/%s" % name


## The nav-shaped target, the same fields the feedback screen's door builds
## (`FeedbackScreen._osk_target`) with the live rect this panel can afford.
func _osk_target(target_id: String, button: Button) -> Dictionary:
	var rect := Rect2(Vector2.ZERO, Vector2(44.0, 44.0))
	var drawn := false
	if button != null:
		rect = button.get_global_rect()
		drawn = button.is_visible_in_tree()
	return {"id": target_id, "kind": "button", "action": "", "rect": rect, "drawn": drawn}


## `data-i18n-aria` on the container (`index.html:700`), set only when the engine has
## the property (the port's own pattern in ChallengesScreen/HistoryScreen).
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
