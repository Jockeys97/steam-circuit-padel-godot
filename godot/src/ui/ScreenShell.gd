## ScreenShell.gd — the chrome every router screen sits in: a title row with the
## declared back control, a subtitle line, and the content region the screen fills.
##
## WHY A SHELL AND NOT THIRTEEN HEADERS. The reference writes each screen's header
## markup by hand (`index.html:104-110` for modes, and the same shape ten more
## times: `<button class="btn btn--ghost" data-action="to-…" data-back
## data-i18n="back">`, an `<h2 data-i18n="…Title">`, a `<p data-i18n="…Sub">`). The
## port cannot: one writer per file means thirteen screen tickets that would each
## hand-write the same header. So the header is built once here and a screen ticket
## fills the content region instead.
##
## THE BACK CONTROL IS THE REFERENCE'S OWN. Its label is the locale id `back`
## (`index.html:105`), its action is the declared return, and it is shown only where
## the reference shows one: the ten screens that carry `data-back`. The menu, the
## field and the result declare none (`godot/src/input/nav_routes.gd:82`) and the
## control is hidden there.
##
## FOCUS. The shell does not own focus policy — that is `godot/src/input/**`'s, and
## UIR-05's bridge is the adapter. The shell only NAMES its controls, and it owns
## that naming: every focusable control registers as `<screen_id>/<suffix>`, the back
## control as `<screen_id>/back`. `focus_controls()` is what the bridge reads.
##
## The safe-area margin is `godot/game/hud.gd:75`'s own number, kept as a constant
## and applied to the layout here. Header type roles (back / title / subtitle) are
## the theme's own variations, applied once here so every router screen matches the
## reference chrome (`.btn--ghost`, `.screen-header h2`, `.screen-header p`).
##
## NODES ARE RESOLVED LAZILY (`_ensure_nodes`), not with `@onready`: a screen enters
## the router's host before the host is necessarily inside a tree — that is exactly
## what the router audit does — and an `@onready` reference would still be null there.
## Every public method resolves first, so the shell behaves the same in a live frame
## and in a headless contract test.
extends Control

const UiStrings := preload("res://src/ui/UiStrings.gd")

## A click on the shell's visible Back control. The router owns the actual transition.
signal back_requested(target_id: String)

## `godot/game/hud.gd:75`. Applied to the shell's outer margins in `_apply_safe_area`.
const SAFE_MARGIN := 8.0

## The suffix the back control registers under (`"<screen_id>/back"`).
const BACK_SUFFIX := "back"

## The back control's label, as the reference writes it in its own markup
## (`index.html:312`: `data-i18n="back"` → IT `← Indietro`, EN `← Back`). The docstring
## above has always named this id; nothing assigned it, so every screen mounted in this
## shell showed a styled but wordless back button.
const BACK_LABEL := "back"

## The router id this shell belongs to (`""` until `setup()`).
var screen_id: String = ""

## The declared back target as a router id (`""` where the reference declares none).
var back_target_id: String = ""

var _margin: MarginContainer
var _title_row: HBoxContainer
var _back: Button
var _title: Label
var _subtitle: Label
var _content: MarginContainer

## suffix -> `{id, node, action, opts}`; keyed so a repeated registration of the
## same control replaces its entry instead of stacking a second one.
var _focus_specs: Dictionary = {}


func _ready() -> void:
	_ensure_nodes()
	set_back_target(back_target_id)


## One call per screen: the id. `setup()` deliberately takes no title string — a
## title is a message id, resolved through `UiStrings` by `set_title()`.
func setup(screen_id_in: String) -> void:
	_ensure_nodes()
	screen_id = screen_id_in
	_focus_specs.clear()
	set_back_target("")


func set_title(message_id: String) -> void:
	_ensure_nodes()
	_title.text = UiStrings.t(message_id)


func set_subtitle(message_id: String) -> void:
	_ensure_nodes()
	var present := message_id != ""
	_subtitle.text = UiStrings.t(message_id) if present else ""
	_subtitle.visible = present


## A title the screen already holds as text — the visible-fallback case, where an id
## resolves to itself. Kept apart from `set_title()` so the resolver route stays the
## default one a reader meets first.
func set_title_text(text: String) -> void:
	_ensure_nodes()
	_title.text = text


## A subtitle a screen resolves itself, for a message a table the shell does not read
## owns — `screen-drill`'s per-exercise line, where the reference's own generated table and
## this build's extension table share one resolver (`drill_text.gd`). The visible-fallback
## rule is the same one `set_subtitle()` keeps: an empty string hides the line.
func set_subtitle_text(text: String) -> void:
	_ensure_nodes()
	_subtitle.text = text
	_subtitle.visible = text != ""


## Shows the back control for a target and registers it under the shell's own naming
## (`<screen_id>/back`), or hides it and drops the registration for `""` — the
## reference's rule for the root, the field and the result.
func set_back_target(target_id: String) -> void:
	_ensure_nodes()
	back_target_id = target_id
	_back.visible = target_id != ""
	_back.disabled = target_id == ""
	_apply_back_label()
	if target_id == "":
		_focus_specs.erase(BACK_SUFFIX)
		return
	add_focus(BACK_SUFFIX, _back, "back", {"kind": "button"})


## The declared return's id, or `""` where the reference declares none — what UIR-05's
## focus bridge routes a back dispatch to (`go_to(back_target())`), and the same answer
## `set_back_target("")` used to hide the control.
func back_target() -> String:
	return back_target_id


## The region a screen's own controls go into.
func content() -> MarginContainer:
	_ensure_nodes()
	return _content


func back_control() -> Button:
	_ensure_nodes()
	return _back


func title_control() -> Label:
	_ensure_nodes()
	return _title


func subtitle_control() -> Label:
	_ensure_nodes()
	return _subtitle


## `<screen_id>/<suffix>` — the id naming this shell owns (UIR-05's bridge consumes
## it; nothing else re-derives it).
func focus_id(suffix: String) -> String:
	return "%s/%s" % [screen_id, suffix]


func back_control_id() -> String:
	return focus_id(BACK_SUFFIX)


## Registers a focusable control the screen added to the content region.
func add_focus(suffix: String, node: Control, action: String, opts: Dictionary = {}) -> void:
	if node == null:
		return
	_focus_specs[suffix] = {
		"id": focus_id(suffix),
		"node": node,
		"action": action,
		"opts": opts.duplicate(),
	}


func drop_focus(suffix: String) -> void:
	_focus_specs.erase(suffix)


## The shell's focusables, as `{id, node, action, opts}`. UIR-05's bridge feeds these
## to `godot/game/menu_focus.gd::add()`; the shell does not call the model itself.
func focus_controls() -> Array:
	return _focus_specs.values()


func _ensure_nodes() -> void:
	if _back != null:
		return
	_margin = $Margin
	_title_row = $Margin/Rows/TitleRow
	_back = $Margin/Rows/TitleRow/BackButton
	_title = $Margin/Rows/TitleRow/TitleBlock/Title
	_subtitle = $Margin/Rows/TitleRow/TitleBlock/Subtitle
	_content = $Margin/Rows/Content
	_back.pressed.connect(_on_back_pressed)
	_apply_safe_area()
	_style_chrome()
	_apply_back_label()


func _on_back_pressed() -> void:
	if back_target_id != "":
		back_requested.emit(back_target_id)


## Re-reads the label the reference's own markup carries (`index.html:312`). A door a
## screen calls from its own `refresh_strings()` so a language flip reaches the header:
## the reference rewrites every `data-i18n` node on `applyLanguage` (`js/ui.js:1667-1673`),
## header included, while a label written once would keep the language it was built in.
func refresh_strings() -> void:
	_ensure_nodes()
	_apply_back_label()


func _apply_back_label() -> void:
	if _back != null:
		_back.text = UiStrings.t(BACK_LABEL)


## `.screen-header` (`styles.css:280-296`): ghost back, Lilita title, muted subtitle,
## 24 px gap. Applied here so a screen that never writes `_style_chrome()` still
## matches the reference instead of falling through to the unstyled Button/Label.
func _style_chrome() -> void:
	_title_row.add_theme_constant_override("separation", 24)
	_back.theme_type_variation = &"ButtonGhost"
	_title.theme_type_variation = &"ScreenTitle"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.theme_type_variation = &"ScreenSubtitle"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _apply_safe_area() -> void:
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(String(side), int(SAFE_MARGIN))
