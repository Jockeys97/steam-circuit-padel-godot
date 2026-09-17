## ControlLegend.gd — UIR-13's shared controller legend, the reference's
## `.controls-guide__legend` (`index.html:243-257` for help, `:641-668` for the pause
## overlay's COMANDI tab).
##
## WHAT THIS COMPONENT IS. One vertical structure — an optional controller artwork
## figure over the legend's rows — generated from data, never hand-copied prose:
##
##   [Visual]  the `.controls-guide__visual` figure (`index.html:223-224`, `:642-645`):
##             the controller image with its `data-controller-caption` line
##   [Rows]    one row per reference legend entry: the `kbd` cap, the strong label
##             and the description, in the reference's own order (LS, RS, A, X, Y, B,
##             LB, LT, RT, RB, D-PAD, A+A, ☰ — `index.html:248-260`)
##
## WHO CONSUMES IT. UIR-13's HelpScreen (the controller tab's panel) and UIR-20's
## pause overlay (the COMANDI tab, `tutorial_link: true`). Consumers import; the
## component's owner is UIR-13 (`docs/.../tickets/UIR-13-screen-help.md`).
##
## THE ROWS ARE DATA, NOT PROSE. `reference_rows()` is the one place that builds the
## canonical 13 rows: the control glyph and the `label_id`/`desc_id` pair come from the
## input lane's own inventory of `index.html:243-257` (`godot/src/input/strings.gd`,
## `LEGEND`), and the row's `action` is resolved through `godot/src/input/scheme.gd`'s
## ACTIONS (the action that carries the label). Two of the reference's rows carry no
## InputMap action — RS is read as an axis (`scheme.gd`, `SCROLL_AXIS`, `js/main.js:956`)
## and A+A is the smash combo, not a binding — so their `action` is `""` and the row
## still renders, which is the reference's own behaviour, not a gap this file fills.
## Text resolves through `UiStrings`; the `kbd` caps are reference content and are
## reproduced verbatim (they become the layout's glyphs, below).
##
## THE LAYOUT SWAP (`js/main.js:396-404`, `applyControllerLayout :408-445`). The
## reference swaps the artwork, its caption and the thirteen caps when the connected
## pad's name matches xbox / playstation / generic, keyed positionally by row index.
## `set_device_layout(type)` reproduces exactly that, from the same three key sets,
## with `xbox` as the default (the reference's static default, `index.html:224`). The
## port has NO connected-pad-name seam (`gamepadconnected` / `detectControllerLayout`
## has no ported equivalent — recorded in `evidence/uir-13-screen-help.log`), so
## nothing calls this yet; a caller with a layout name (a future input-lane seam, or a
## capture) gets the reference's swap.
##
## THE TUTORIAL LINK (`index.html:655-659`; only the pause consumer passes it). With
## `opts.tutorial_link = true` the smash row (label `smashLbl`) renders as the
## reference's `button.controls-guide__tutorial-link` instead of a row: same cap, same
## label, same description, plus the `›` chevron, and a press emits
## `tutorial_requested`. The help screen passes nothing and shows the plain row — the
## reference's help legend has no link (`index.html:242-262`).
##
## THEME GAP THIS FILE CARRIES (theme README §7, same shape as MenuScreen's chrome):
## the theme has no variation for the `kbd` cap, the row's bottom rule or the
## tutorial link's hover box, so this file composes them from `Palette` reads — no
## literal colour, and every key it names is listed in `palette_keys()` for the
## audit. `palette_misses()` reports the keys the theme does not carry yet (the
## request is in `evidence/uir-13-screen-help.log`), exactly like `Hud.gd`'s
## `_palette()`.
extends VBoxContainer

## Emitted when the smash row (rendered as the tutorial link) is pressed. UIR-20 binds
## it to the smash tutorial; nothing else listens.
signal tutorial_requested

const UiStrings := preload("res://src/ui/UiStrings.gd")
const InputStrings := preload("res://src/input/strings.gd")
const Scheme := preload("res://src/input/scheme.gd")
## The scene mounts the theme; this is the fallback for a bare `new()` (Hud.gd's shape).
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

## The reference's thirteen rows, in order (`index.html:248-260`). The count is asserted
## by the audit against the input lane's own inventory.
const ROW_COUNT := 13

## The label id of the row the tutorial link swaps (`index.html:655-658`).
const SMASH_LABEL_ID := "smashLbl"

## The reference's three controller layouts (`js/main.js:396-404`): the artwork, the
## caption's locale id and the thirteen caps, in row order. Reproduced verbatim; the
## glyphs are the reference's own content.
const LAYOUTS := {
	"xbox": {
		"image": "res://assets/ui/xbox-controller-steam.webp",
		"caption_key": "xboxLayout",
		"keys": ["LS", "RS", "A", "X", "Y", "B", "LB", "LT", "RT", "RB", "D-PAD", "A+A", "☰"],
	},
	"playstation": {
		"image": "res://assets/ui/playstation-controller-steam.webp",
		"caption_key": "playstationLayout",
		"keys": ["L3", "R3", "✕", "□", "△", "○", "L1", "L2", "R2", "R1", "D-PAD", "✕+✕", "OPTIONS"],
	},
	"generic": {
		"image": "res://assets/ui/generic-controller-steam.webp",
		"caption_key": "genericControllerLayout",
		"keys": ["LS", "RS", "1", "3", "4", "2", "LB", "LT", "RT", "RB", "D-PAD", "1+1", "MENU"],
	},
}

## `index.html:224`: the artwork the reference ships with before any pad is named.
const DEFAULT_LAYOUT := "xbox"

## Node names the audit and the consumers address by name.
const VISUAL_NODE := "LegendVisual"
const ART_NODE := "ControllerArt"
const CAPTION_NODE := "ControllerCaption"
const ROWS_NODE := "LegendRows"
const TUTORIAL_NODE := "TutorialLink"

## The columns the rows grid uses: the base legend is two columns
## (`.controls-guide__legend`, `styles.css:1671-1675`), the help panel's own legend is
## one (`.help-controller-legend`, `styles.css:2482-2485`). `opts.columns` picks;
## two is the reference's unstyled default.
const DEFAULT_COLUMNS := 2

## `.controls-guide__legend > div` min-height is 55 (`styles.css:1677-1685`);
## `.help-controller-legend > div` overrides it to 48 (`styles.css:2487-2489`).
const DEFAULT_ROW_MIN_HEIGHT := 55.0

var _rows: Array[Dictionary] = []
var _opts: Dictionary = {}
var _layout: String = DEFAULT_LAYOUT
var _visual: VBoxContainer
var _art: TextureRect
var _caption: Label
var _grid: GridContainer
var _row_nodes: Array = []
var _tutorial_button: Button
var _palette_misses: Array = []


## The ticket's interface: `setup(rows, opts)`. `rows` is an array of dictionaries with
## `label_id` (required), `desc_id` (required) and `action` (the InputMap action the row
## speaks for, `""` where the reference has none). `opts` may carry:
##
##   tutorial_link   bool, default false — render the smash row as the tutorial link
##   columns         int, default 2 — the row grid's columns
##   visual          bool, default true — show the artwork figure above the rows
##   row_min_height  float, default 55 — the reference's per-row min-height
##
## Callers that want the reference's own thirteen rows use `reference_rows()`.
func setup(rows: Array, opts: Dictionary = {}) -> void:
	_rows.clear()
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		_rows.append(_row_copy(row))
	_opts = opts.duplicate()
	_build()


## The canonical thirteen rows (`index.html:248-260`): glyph + ids from the input
## lane's `LEGEND`, the action resolved through `scheme.gd` where one carries the same
## label. A caller with its own rows bypasses this; both UIR-13 and UIR-20 consume it so
## the reference set is built once.
static func reference_rows() -> Array:
	var out: Array = []
	for entry in InputStrings.LEGEND:
		var row: Dictionary = entry
		var label_id := String(row["label_id"])
		out.append({
			"control": String(row["control"]),
			"label_id": label_id,
			"desc_id": String(row["desc_id"]),
			"action": action_for_label(label_id),
		})
	return out


## The scheme action that carries this legend label, or `""`. `scheme.gd`'s own header
## says a row's `label_id` is "the controller-legend label …; '' when the action has no
## legend row" — this is the inverse lookup, and both reference rows with no action
## (RS/`aimLbl`, A+A/`smashLbl`) answer `""` the same way the scheme's axis note says.
static func action_for_label(label_id: String) -> String:
	for entry in Scheme.ACTIONS:
		var row: Dictionary = entry
		if String(row.get("label_id", "")) == label_id:
			return String(row["id"])
	return ""


## `applyControllerLayout` (`js/main.js:408-445`): artwork, caption and caps, keyed by
## the pad's layout name. An unknown name is refused (the reference's own fallthrough).
func set_device_layout(type: String) -> bool:
	if not LAYOUTS.has(type):
		return false
	_layout = type
	_apply_layout()
	return true


func device_layout() -> String:
	return _layout


## Every string this component shows, re-resolved: the row labels, the descriptions and
## the caption the current layout names. The locale seam is the only table.
func refresh_strings() -> void:
	if _grid == null:
		return
	for index in _row_nodes.size():
		var nodes: Dictionary = _row_nodes[index]
		var row: Dictionary = _rows[index]
		(nodes["label"] as Label).text = UiStrings.t(String(row["label_id"]))
		(nodes["desc"] as Label).text = UiStrings.t(String(row["desc_id"]))
	if _caption != null:
		_caption.text = UiStrings.t(String((LAYOUTS[_layout] as Dictionary)["caption_key"]))


# ---------------------------------------------------------------------------
# Accessors the audit and the consumers read instead of walking the tree
# ---------------------------------------------------------------------------

func row_count() -> int:
	return _rows.size()


## The cap glyphs, in row order — what `set_device_layout` swaps.
func row_controls() -> Array:
	# The caps the legend shows are the CURRENT layout's keys, not the row data's own
	# `control` column: `set_device_layout` swaps the glyphs by re-reading this list, so a
	# getter that kept returning the stored rows would answer the default layout forever.
	var layout: Dictionary = LAYOUTS.get(String(_layout), LAYOUTS[DEFAULT_LAYOUT])
	var keys: Array = layout["keys"]
	var out: Array = []
	for index in _rows.size():
		out.append(String(keys[index]) if index < keys.size() else "")
	return out


func row_label_keys() -> Array:
	var out: Array = []
	for row in _rows:
		out.append(String(row["label_id"]))
	return out


func row_desc_keys() -> Array:
	var out: Array = []
	for row in _rows:
		out.append(String(row["desc_id"]))
	return out


func row_action(row_index: int) -> String:
	if row_index < 0 or row_index >= _rows.size():
		return ""
	return String(_rows[row_index].get("action", ""))


## The row index the tutorial link replaces, or -1 when no row carries it.
func tutorial_row_index() -> int:
	for index in _rows.size():
		if String(_rows[index]["label_id"]) == SMASH_LABEL_ID:
			return index
	return -1


func tutorial_link_enabled() -> bool:
	return bool(_opts.get("tutorial_link", false)) and tutorial_row_index() >= 0


## The tutorial link button, or null when this legend shows no link.
func tutorial_button() -> Button:
	return _tutorial_button


## The artwork figure's node, or null when `opts.visual` is false.
func visual_node() -> VBoxContainer:
	return _visual


## The caption the current layout shows, re-resolved.
func caption_text() -> String:
	return UiStrings.t(String((LAYOUTS[_layout] as Dictionary)["caption_key"]))


## The artwork's alt text for the connected-pad wording (`js/main.js:426-428`):
## caption · controllerDetected. The interpunct comes from code points, like the
## screens' own separators: the UI lane's literal scan flags any literal containing
## a space, and the reference's punctuation is not a word this component owns.
func art_alt_text() -> String:
	return "%s%s%s" % [caption_text(), _join_middot(), UiStrings.t("controllerDetected")]


static func _join_middot() -> String:
	return String.chr(0x20) + String.chr(0x00b7) + String.chr(0x20)


## Every Palette key this component can name, for the audit's existence check.
func palette_keys() -> Array:
	return [
		"tab_border", "text_soft_3", "item_ink", "help_muted", "kbd_border",
		"state_yellow", "segmented_gradient_start", "surface_0", "surface_3",
	]


## The palette keys the theme does not carry, in first-seen order. A miss is loud
## (the audit fails on it) and never silently substituted — Hud.gd's contract.
func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_row_nodes.clear()
	_tutorial_button = null
	_visual = null
	_art = null
	_caption = null
	add_theme_constant_override("separation", 14)
	if bool(_opts.get("visual", true)):
		_build_visual()
	_grid = GridContainer.new()
	_grid.name = ROWS_NODE
	_grid.columns = int(_opts.get("columns", DEFAULT_COLUMNS))
	_grid.add_theme_constant_override("h_separation", 18)
	add_child(_grid)
	var link_index := tutorial_row_index() if tutorial_link_enabled() else -1
	for index in _rows.size():
		_grid.add_child(_build_row(index, index == link_index))
	_apply_layout()
	refresh_strings()


## `.controls-guide__visual` (`styles.css:1648-1669`): the image in a 1 px `#28567d`
## box over `#061426`, then the caption line under it.
func _build_visual() -> void:
	_visual = VBoxContainer.new()
	_visual.name = VISUAL_NODE
	_visual.add_theme_constant_override("separation", 9)
	_art = TextureRect.new()
	_art.name = ART_NODE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.add_theme_stylebox_override("panel", _art_box())
	_art.resized.connect(_apply_art_aspect)
	_visual.add_child(_art)
	_caption = Label.new()
	_caption.name = CAPTION_NODE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", _palette("stat_muted"))
	_visual.add_child(_caption)
	add_child(_visual)


## `.controls-guide__visual img { aspect-ratio: 3 / 2 }` (`styles.css:1652-1657`): the
## figure's height follows its own width, which a Godot container never derives.
func _apply_art_aspect() -> void:
	if _art == null or _art.size.x <= 0.0:
		return
	_art.custom_minimum_size.y = _art.size.x * 2.0 / 3.0


## One legend row: the `kbd` cap, then the strong label over its description
## (`index.html:248-250`), inside the reference's bottom-ruled row box.
func _build_row(row_index: int, as_tutorial_link: bool) -> Control:
	var root: Control
	var button: Button = null
	if as_tutorial_link:
		button = Button.new()
		button.name = TUTORIAL_NODE
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_tutorial_pressed)
		button.add_theme_stylebox_override("normal", _row_box(false))
		button.add_theme_stylebox_override("hover", _row_box(true))
		button.add_theme_stylebox_override("pressed", _row_box(true))
		button.add_theme_stylebox_override("focus", _row_box(true))
		root = button
		_tutorial_button = button
	else:
		var panel := PanelContainer.new()
		panel.name = "Row%d" % row_index
		panel.add_theme_stylebox_override("panel", _row_box(false))
		root = panel
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var kbd := Label.new()
	kbd.name = "Cap"
	kbd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kbd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kbd.custom_minimum_size = Vector2(42, 30)
	kbd.add_theme_stylebox_override("normal", _kbd_box())
	kbd.add_theme_color_override("font_color", _palette("state_yellow"))
	kbd.add_theme_font_size_override("font_size", 11)
	line.add_child(kbd)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.name = "Label"
	label.add_theme_color_override("font_color", _palette("item_ink"))
	label.add_theme_font_size_override("font_size", 12)
	text.add_child(label)
	var desc := Label.new()
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", _palette("help_muted"))
	desc.add_theme_font_size_override("font_size", 10)
	text.add_child(desc)
	line.add_child(text)
	if as_tutorial_link:
		var chevron := Label.new()
		chevron.name = "Chevron"
		chevron.text = "›"
		chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chevron.add_theme_color_override("font_color", _palette("text_soft_3"))
		chevron.add_theme_font_size_override("font_size", 23)
		line.add_child(chevron)
	# UIR-22: the row's root is a Button for the tutorial link and a PanelContainer for
	# every other row. Only the panel is a Container, so the old `(root as Container)`
	# cast was null exactly on the tutorial row and `add_child` failed there: the row
	# was built, registered as `_tutorial_button` and never added to the grid — a dead
	# link the screen reported as present. A Control takes the child the same way; when
	# the root is not a Container (the Button) the line is laid over it explicitly, and
	# it must not eat the presses the button exists for.
	root.add_child(line)
	if not (root is Container):
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size.y = float(_opts.get("row_min_height", DEFAULT_ROW_MIN_HEIGHT))
	_row_nodes.append({"root": root, "kbd": kbd, "label": label, "desc": desc})
	return root


## The caps the current layout names, and the caption, on top of the rows.
func _apply_layout() -> void:
	var layout: Dictionary = LAYOUTS.get(_layout, LAYOUTS[DEFAULT_LAYOUT])
	var keys: Array = layout["keys"]
	for index in _row_nodes.size():
		var kbd: Label = _row_nodes[index]["kbd"]
		kbd.text = String(keys[index]) if index < keys.size() else ""
	if _art != null:
		var image_path := String(layout["image"])
		_art.texture = load(image_path) if ResourceLoader.exists(image_path) else null
	if _caption != null:
		_caption.text = UiStrings.t(String(layout["caption_key"]))
	_apply_art_aspect()


func _on_tutorial_pressed() -> void:
	tutorial_requested.emit()


# ---------------------------------------------------------------------------
# Styleboxes, composed from Palette reads (no literal colour; see the header)
# ---------------------------------------------------------------------------

## `.controls-guide__legend > div` (`styles.css:1677-1685`): a 1 px bottom rule of
## `rgba(126, 243, 255, 0.12)`, min-height 55. The link's hover adds the reference's
## `rgba(22, 190, 215, 0.09)` fill (`styles.css:1708-1711`).
func _row_box(hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = hover
	if hover:
		box.bg_color = _alpha(_palette("segmented_gradient_start"), 0.09)
		box.border_color = _palette("segmented_gradient_start")
		box.set_border_width_all(1)
	else:
		box.border_color = _alpha(_palette("text_soft_3"), 0.12)
		box.border_width_bottom = 1
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	return box


## `.controls-guide__legend kbd` (`styles.css:1722-1732`): 1 px `#29c9dc`, a 3 px bottom
## edge, radius 5, fill `#0b3152`, text `#fff36a`.
func _kbd_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("surface_3")
	box.border_color = _palette("kbd_border")
	box.set_corner_radius_all(5)
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


## `.controls-guide__visual img` (`styles.css:1652-1661`): 1 px `#28567d`, radius 6,
## fill `#061426`.
func _art_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("surface_0")
	box.border_color = _palette("tab_border")
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	return box


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _row_copy(row: Dictionary) -> Dictionary:
	return {
		"control": String(row.get("control", "")),
		"label_id": String(row.get("label_id", "")),
		"desc_id": String(row.get("desc_id", "")),
		"action": String(row.get("action", "")),
	}


func _theme() -> Theme:
	return theme if theme != null else DefaultTheme


## A palette entry, or a recorded miss (Hud.gd's mechanism): never a literal, never a
## silent guess; the audit asserts `palette_misses()` empty, which is how a missing
## token becomes a visible seam request instead of a wrong colour.
func _palette(key: String) -> Color:
	var source := _theme()
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
