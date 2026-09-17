## SettingsRows.gd — the two control rows the settings family shares.
##
## WHY IT EXISTS. `index.html:410-440` writes the same two rows twice in the settings
## screen (`controller-range` for volume and deadzone, `controller-toggle` for reduce
## motion, colour-blind and vibration) and the pause overlay's controller tab repeats
## them in the reference too (`js/main.js:2455-2470` syncs both copies from one state).
## One row per kind, built once here, is what keeps the second consumer (UIR-20) from
## hand-writing a third copy: the row owns the control, the bounds and the reading of
## the raw value, and the caller connects `changed`.
##
## WHAT THE ROW IS. The reference's markup, exactly: a label line (`VOLUME 50%` — the
## value is the same `<b>` the reference updates at `js/main.js:2465`), and the input
## under it. A toggle is the reference's `<label><input type=checkbox>…</label>` — a
## `CheckBox` carries the text, the check state and the focus in one control, which is
## what a Godot form row is.
##
## DEFAULTS ARE NOT HERE. `min`/`max`/`step`/`value` are arguments: the screen reads
## them from the save contract's own defaults (`save_schema.gd::PREFS_DEFAULTS`) and
## hands them over, so this file cannot become a second copy of the settings table.
##
## TEXT IS A MESSAGE ID. Every visible string goes through `UiStrings`, like every
## other UI file (`godot/tests/ui/router_audit.gd` scans this file too: no prose).
##
## LITERALS. None. The percent sign is a constant, and a message id is never a
## sentence.
##
## INNER CLASSES ARE SELF-CONTAINED on purpose: each declares the preloads and
## constants it needs, so nothing here depends on how GDScript resolves an outer
## class's members from inside an inner one.
extends RefCounted

## `controller-settings__title` is 0.72 rem at 0.08 em tracking (`styles.css:2714`).
const TITLE_SIZE := 12
const VALUE_SIZE := 14
## The muted label alpha of `controller-range > span` (`styles.css:2770`).
const LABEL_ALPHA := 0.62
## The percent sign the rows' value line carries (`Math.round(v * 100) + "%"`,
## `js/main.js:2460`). Top-level so the screen reads the same constant the rows do.
const PERCENT_SIGN := "%"


## One `controller-range` row: label, live value, slider. `changed` carries the raw
## value the reference stores (`ui.gamepadDeadzone`, `getVolume()`), never a percent.
class RangeRow extends VBoxContainer:
	signal changed(value: float)

	const UiStrings := preload("res://src/ui/UiStrings.gd")
	const PERCENT_SIGN := "%"

	var slider: HSlider
	var label: Label
	var value_label: Label
	var _as_percent := true

	func setup(label_key: String, min_value: float, max_value: float, step_value: float, start: float, as_percent: bool, label_alpha: float, title_size: int, value_size: int) -> void:
		_as_percent = as_percent
		var head := HBoxContainer.new()
		head.name = "Head"
		add_child(head)
		label = Label.new()
		label.name = "Label"
		label.text = UiStrings.t(label_key)
		label.set_meta("message_id", label_key)
		label.add_theme_font_size_override("font_size", title_size)
		label.modulate.a = label_alpha
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(label)
		value_label = Label.new()
		value_label.name = "Value"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", value_size)
		head.add_child(value_label)
		slider = HSlider.new()
		slider.name = "Slider"
		slider.min_value = min_value
		slider.max_value = max_value
		slider.step = step_value
		slider.custom_minimum_size = Vector2(220.0, 0.0)
		slider.value = clampf(start, min_value, max_value)
		slider.value_changed.connect(_on_slider_changed)
		add_child(slider)
		_refresh()

	func set_value(raw: float) -> void:
		slider.set_value_no_signal(clampf(raw, slider.min_value, slider.max_value))
		_refresh()

	func value() -> float:
		return float(slider.value)

	## `Math.round(v * 100) + "%"` (`js/main.js:2460`, `:2465`).
	func value_text() -> String:
		if not _as_percent:
			return str(int(round(float(slider.value))))
		return str(roundi(float(slider.value) * 100.0)) + PERCENT_SIGN

	func label_key() -> String:
		return String(label.get_meta("message_id", ""))

	func refresh_strings() -> void:
		label.text = UiStrings.t(label_key())

	func _on_slider_changed(raw: float) -> void:
		_refresh()
		changed.emit(raw)

	func _refresh() -> void:
		if value_label != null:
			value_label.text = value_text()


## One `controller-toggle` row: a `CheckBox` carrying the reference's label.
class ToggleRow extends HBoxContainer:
	signal changed(on: bool)

	const UiStrings := preload("res://src/ui/UiStrings.gd")

	var check: CheckBox

	func setup(label_key: String, start: bool, title_size: int) -> void:
		check = CheckBox.new()
		check.name = "Check"
		check.text = UiStrings.t(label_key)
		check.set_meta("message_id", label_key)
		check.set_pressed_no_signal(start)
		check.add_theme_font_size_override("font_size", title_size)
		check.toggled.connect(_on_toggled)
		add_child(check)

	func set_on(on: bool) -> void:
		check.set_pressed_no_signal(on)

	func on() -> bool:
		return bool(check.button_pressed)

	func label_key() -> String:
		return String(check.get_meta("message_id", ""))

	func refresh_strings() -> void:
		check.text = UiStrings.t(label_key())

	func _on_toggled(on: bool) -> void:
		changed.emit(on)


# ---------------------------------------------------------------------------
# The factories a screen calls
# ---------------------------------------------------------------------------

## A percent row for the two reference sliders: `settingsVolume` (0-1, step 0.01,
## `index.html:433`) and `settingsDeadzone` (0.08-0.30, step 0.01, `index.html:437`).
static func make_range(label_key: String, min_value: float, max_value: float, step_value: float, start: float, name_hint: String, as_percent := true) -> RangeRow:
	var row := RangeRow.new()
	row.name = name_hint
	row.setup(label_key, min_value, max_value, step_value, start, as_percent, LABEL_ALPHA, TITLE_SIZE, VALUE_SIZE)
	return row


## A toggle row (`optReduceMotion`, `optColorblind`, `settingsVibration`).
static func make_toggle(label_key: String, start: bool, name_hint: String) -> ToggleRow:
	var row := ToggleRow.new()
	row.name = name_hint
	row.setup(label_key, start, TITLE_SIZE)
	return row


## Re-resolves a row's label through the seam — the language flip path, for a caller
## that holds rows it did not build.
static func refresh_strings(row: Control) -> void:
	if row is RangeRow:
		(row as RangeRow).refresh_strings()
	elif row is ToggleRow:
		(row as ToggleRow).refresh_strings()


## The row kind as a name: `"range"` for the sliders, `"toggle"` for the checkboxes.
## The screen and its audit ask through this door instead of a type check two lanes
## apart.
static func kind_of(row: Control) -> String:
	if row is RangeRow:
		return "range"
	if row is ToggleRow:
		return "toggle"
	return ""


## The focus kind the input model expects for a row's own control
## (`godot/src/input/focus_nav.gd`: a range steps with left/right, a button confirms).
static func focus_kind(row: Control) -> String:
	if row is RangeRow:
		return "range"
	return "button"


## The control a row registers as focusable: the slider or the checkbox, never the row
## container (the model wants the control that owns the value).
static func focus_node(row: Control) -> Control:
	if row is RangeRow:
		return (row as RangeRow).slider
	if row is ToggleRow:
		return (row as ToggleRow).check
	return row
