extends Control
class_name CharacterEditorScreen
## CharacterEditorScreen — create one athlete, see it, keep it or drop it.
##
## ===========================================================================
## HOW IT IS REACHED (and why it is not a router id)
## ===========================================================================
## It is mounted AS AN OVERLAY by `CharactersScreen`, which owns the roster. The
## router's registry is the reference's own thirteen screens and
## `src/input/nav_routes.gd` is generated and byte-verified against that reference, so
## a fourteenth routed id would be a change to the reference's inventory rather than a
## port addition. The overlay keeps Back inside the roster screen: Back and Cancel
## both discard the preview and hand the caller `closed(false)`, Save persists and
## hands it `closed(true)`.
##
## ===========================================================================
## WHAT THE PLAYER DRIVES
## ===========================================================================
## A name and six bounded choices: body, skin, hair variant, hair colour, outfit variant,
## outfit colour. Every row is a focusable pair of step buttons, so the whole screen is
## operable with the pad alone (`ui_left` / `ui_right` on the focused row, `ui_cancel`
## to leave). Typing a name needs the keyboard, so the name row also carries
## suggestions the pad can step through — the pad can always finish the job.
##
## The preview is the real rig: `CustomCharacterRig`, the same athlete the match
## spawns, so what is on screen is what is played. A build that cannot produce the rig
## shows `error` instead of an empty box and keeps the roster usable.

const CustomCharacter := preload("res://src/character/custom_character.gd")
const CustomCharacterStore := preload("res://src/character/custom_character_store.gd")
const CustomCharacterRig := preload("res://src/character/custom_character_rig.gd")
const CustomCharacterPortrait := preload("res://src/character/custom_character_portrait.gd")
## The words are the locale lane's, not this file's: the router's literal scan flags any
## prose literal in `src/ui/**`.
const Text := preload("res://src/locale/custom_character_text.gd")

signal closed(saved: bool)

## The five cosmetic fields, in the order the panel shows them.
const FIELDS := [
	{"field": "body_id", "label_key": "customFieldBody"},
	{"field": "skin_id", "label_key": "customFieldSkin"},
	{"field": "hair_id", "label_key": "customFieldHair"},
	{"field": "hair_color_id", "label_key": "customFieldHairColor"},
	{"field": "outfit_id", "label_key": "customFieldOutfit"},
	{"field": "outfit_color_id", "label_key": "customFieldOutfitColor"},
]

## Names the pad can step through without a keyboard.
const NAME_SUGGESTIONS := [
	"ALBA", "RIVA", "NEO", "VOLA", "TEO", "LUNA", "KAI", "SOLE", "MIRA", "ZEN",
	"ARIA", "BRIO", "DADO", "ELIO", "FOLA", "GIGI",
]

var error: String = ""

var _record: Dictionary = {}
var _saved: Dictionary = {}
var _store: RefCounted = null
var _rig: Node3D = null
var _viewport: SubViewport = null
var _value_labels: Dictionary = {}
var _color_swatches: Dictionary = {}
var _close_up := false
var _preview_bounds := AABB()
var _name_label: Label = null
var _name_edit: LineEdit = null
var _error_label: Label = null


# =========================================================================
# ScreenContract surface (hosted as an overlay, not registered with the router)
# =========================================================================

func screen_id() -> String:
	return "characters"


func back_target() -> String:
	return "characters"


func enter(payload: Dictionary = {}) -> void:
	open_saved(payload.get("store", null))


func exit() -> void:
	pass


# =========================================================================
# Public API
# =========================================================================

## Loads the stored appearance and shows it. Safe to call more than once: the rig is
## rebuilt only when it does not exist yet.
func open_saved(store: RefCounted = null) -> void:
	_store = store if store != null else CustomCharacterStore.new()
	_saved = _store.read()
	_record = _saved.duplicate(true)
	_ensure_rig()
	_apply_preview()
	_refresh_rows()


func store() -> RefCounted:
	return _store


func saved_record() -> Dictionary:
	return _saved.duplicate(true)


func edited_record() -> Dictionary:
	return CustomCharacter.normalize(_record)


func is_dirty() -> bool:
	return edited_record() != _saved


## Steps one field. Wraps, so the pad can cycle without a dead end; refuses an unknown
## field or an empty table rather than silently doing nothing.
func cycle(field: String, direction: int) -> bool:
	var ids := CustomCharacter.option_ids(field)
	if ids.is_empty():
		return false
	var current := String(_record.get(field, CustomCharacter.default_option(field)))
	var index := ids.find(current)
	if index < 0:
		index = 0
	index = posmod(index + direction, ids.size())
	_record[field] = String(ids[index])
	_apply_preview()
	_refresh_rows()
	return true


func apply_name(text: String) -> void:
	_record["display_name"] = CustomCharacter.sanitize_name(text)
	_apply_preview()
	_refresh_rows()


## Steps the name through the suggestion list — the pad's way to name an athlete.
func cycle_name(direction: int) -> void:
	var index := NAME_SUGGESTIONS.find(String(_record.get("display_name", "")))
	if index < 0:
		index = 0
	index = posmod(index + direction, NAME_SUGGESTIONS.size())
	apply_name(NAME_SUGGESTIONS[index])


## Persists the preview. False (with `error`) when the write failed; the previous
## saved record is left untouched in that case.
func save() -> bool:
	var written: Dictionary = _store.write(edited_record())
	if not bool(written.get("ok", false)):
		error = String(written.get("message", Text.t("customErrorSave")))
		_show_error()
		return false
	_saved = edited_record()
	_capture_portrait()
	error = ""
	_show_error()
	closed.emit(true)
	return true


## Discards the preview and closes. The saved record is not touched.
func cancel() -> void:
	_record = _saved.duplicate(true)
	_apply_preview()
	_refresh_rows()
	closed.emit(false)


# =========================================================================
# Construction
# =========================================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if get_child_count() == 0:
		_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b1028")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var root_box := MarginContainer.new()
	root_box.name = "EditorRoot"
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		root_box.add_theme_constant_override(side, 28)
	add_child(root_box)

	var column := VBoxContainer.new()
	column.name = "EditorColumn"
	column.add_theme_constant_override("separation", 16)
	root_box.add_child(column)

	var title := Label.new()
	title.name = "EditorTitle"
	title.text = Text.t("customEditorTitle")
	title.theme_type_variation = &"ScreenTitle"
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)
	var hint := Label.new()
	hint.text = Text.t("customChoiceHint")
	hint.tooltip_text = Text.t("customHint")
	hint.add_theme_color_override("font_color", Color("99b9ce"))
	column.add_child(hint)

	var body := HBoxContainer.new()
	body.name = "EditorBody"
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	_build_preview(body)
	_build_panel(body)


func _build_preview(host: Control) -> void:
	var preview_column := VBoxContainer.new()
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(preview_column)
	var container := SubViewportContainer.new()
	container.name = "PreviewContainer"
	container.stretch = true
	container.custom_minimum_size = Vector2(300, 360)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(420, 520)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("12161f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5dbe8")
	environment.ambient_light_energy = 0.65
	env.environment = environment
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 32, 0)
	sun.light_energy = 1.15
	_viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 42.0
	camera.current = true
	camera.position = Vector3(0.3, 1.2, 2.6)
	_viewport.add_child(camera)
	# A turntable pivot, so a viewer can spin the athlete without touching the rig.
	var pivot := Node3D.new()
	pivot.name = "PreviewPivot"
	_viewport.add_child(pivot)
	pivot.rotate_y(deg_to_rad(20.0))
	var turn := HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_column.add_child(turn)
	turn.add_child(_text_button("RotateLeft", Text.t("customRotateLeft"), func() -> void: pivot.rotate_y(PI / 8.0)))
	turn.add_child(_text_button("RotateRight", Text.t("customRotateRight"), func() -> void: pivot.rotate_y(-PI / 8.0)))
	turn.add_child(_text_button("PreviewZoom", Text.t("customCloseUp"), _toggle_preview_zoom))
	preview_column.move_child(turn, 0)
	_ensure_rig()


func _ensure_rig() -> void:
	if _rig != null or _viewport == null:
		return
	var record := _record if not _record.is_empty() else CustomCharacter.defaults()
	var pivot := _viewport.get_node_or_null("PreviewPivot")
	if pivot == null:
		return
	_rig = CustomCharacterRig.make(record, {"name": "PreviewAthlete"})
	if _rig == null:
		error = Text.t("customErrorRig")
		_show_error()
		return
	pivot.add_child(_rig)
	_rig.play_locomotion(&"idle")
	_preview_bounds = _rig.world_bounds()
	_frame_camera_on_athlete()
	_schedule_portrait()


## Frames the preview camera on the athlete that was actually built: the roster ships
## both metre and centimetre rigs, so a fixed camera position is right for one of them
## and puts the other out of shot.
func _frame_camera_on_athlete() -> void:
	if _rig == null or _viewport == null:
		return
	var camera := _viewport.get_node_or_null("PreviewCamera") as Camera3D
	if camera == null:
		return
	var pivot := _viewport.get_node_or_null("PreviewPivot")
	var bounds: AABB = _preview_bounds
	if pivot != null:
		bounds = pivot.get_global_transform() * bounds
	var centre: Vector3 = bounds.get_center()
	var height := maxf(bounds.size.y, 0.5)
	if _close_up:
		centre.y = bounds.position.y + height * 0.79
	camera.look_at_from_position(
		centre + Vector3(height * 0.14, height * 0.05, height * (0.72 if _close_up else 1.55)), centre, Vector3.UP)


func _toggle_preview_zoom() -> void:
	_close_up = not _close_up
	_frame_camera_on_athlete()
	var button := find_child("PreviewZoom", true, false) as Button
	if button != null:
		button.text = Text.t("customFullBody" if _close_up else "customCloseUp")


func _build_panel(host: Control) -> void:
	var shell := PanelContainer.new()
	shell.name = "EditorPanelShell"
	shell.custom_minimum_size = Vector2(530, 0)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color("111c38")
	shell_style.border_color = Color("1a7694")
	shell_style.set_border_width_all(1)
	shell_style.set_corner_radius_all(18)
	shell_style.content_margin_left = 20
	shell_style.content_margin_right = 20
	shell_style.content_margin_top = 20
	shell_style.content_margin_bottom = 20
	shell.add_theme_stylebox_override("panel", shell_style)
	host.add_child(shell)
	var panel := VBoxContainer.new()
	panel.name = "EditorPanel"
	panel.add_theme_constant_override("separation", 16)
	shell.add_child(panel)

	# --- name ---------------------------------------------------------------
	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("separation", 8)
	panel.add_child(name_row)
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.text = Text.t("customFieldName")
	_name_label.custom_minimum_size = Vector2(165, 0)
	_name_label.add_theme_font_size_override("font_size", 16)
	name_row.add_child(_name_label)
	var name_back := _step_button("NamePrev", "<", func() -> void: cycle_name(-1))
	name_row.add_child(name_back)
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.max_length = CustomCharacter.NAME_MAX_LENGTH
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(text: String) -> void: _record["display_name"] = text)
	name_row.add_child(_name_edit)
	name_row.add_child(_step_button("NameNext", ">", func() -> void: cycle_name(1)))

	# --- the five bounded fields -------------------------------------------
	for spec in FIELDS:
		var field := String(spec["field"])
		var row := HBoxContainer.new()
		row.name = "Row_%s" % field
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var label := Label.new()
		label.name = "Label_%s" % field
		label.text = Text.t(String(spec["label_key"]))
		label.custom_minimum_size = Vector2(165, 0)
		label.add_theme_font_size_override("font_size", 16)
		row.add_child(label)
		var back := _step_button("Prev_%s" % field, "<", func() -> void: cycle(field, -1))
		row.add_child(back)
		var value := Label.new()
		value.name = "Value_%s" % field
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.custom_minimum_size.x = 125
		value.add_theme_font_size_override("font_size", 18)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		_value_labels[field] = value
		if field in ["skin_id", "hair_color_id", "outfit_color_id"]:
			var swatch := ColorRect.new()
			swatch.name = "Swatch_%s" % field
			swatch.custom_minimum_size = Vector2(24, 24)
			swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(swatch)
			_color_swatches[field] = swatch
		var forward := _step_button("Next_%s" % field, ">", func() -> void: cycle(field, 1))
		row.add_child(forward)
		# The pad moves along a row: left/right between the two step buttons, and the
		# row above/below stays available to the default neighbour search.
		back.focus_neighbor_right = back.get_path_to(forward)
		forward.focus_neighbor_left = forward.get_path_to(back)
		for step in [back, forward]:
			step.gui_input.connect(_on_choice_input.bind(field))
			step.tooltip_text = Text.t("customChoiceHint")

	# --- commands -----------------------------------------------------------
	var commands := HBoxContainer.new()
	commands.name = "EditorCommands"
	commands.add_theme_constant_override("separation", 10)
	panel.add_child(commands)
	var save_button := _text_button("SaveButton", Text.t("customActionSave"), func() -> void: save())
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = Color("13c6dd")
	save_style.set_corner_radius_all(10)
	save_style.content_margin_top = 10
	save_style.content_margin_bottom = 10
	save_button.add_theme_stylebox_override("normal", save_style)
	save_button.add_theme_color_override("font_color", Color("061426"))
	commands.add_child(save_button)
	commands.add_child(_text_button("CancelButton", Text.t("customActionCancel"), func() -> void: cancel()))

	_error_label = Label.new()
	_error_label.name = "EditorError"
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.modulate = Color("ff9d9d")
	panel.add_child(_error_label)
	_show_error()
	_refresh_rows()
	_wire_choice_focus()


func _wire_choice_focus() -> void:
	# Stable columns: up/down reaches the next setting even with differently sized labels.
	for prefix in ["Prev_", "Next_"]:
		for i in FIELDS.size():
			var button := find_child(prefix + String(FIELDS[i].field), true, false) as Control
			var above := find_child(prefix + String(FIELDS[i - 1].field), true, false) as Control if i > 0 else _name_edit
			var below := find_child(prefix + String(FIELDS[i + 1].field), true, false) as Control if i + 1 < FIELDS.size() else find_child("SaveButton", true, false) as Control
			button.focus_neighbor_top = button.get_path_to(above)
			button.focus_neighbor_bottom = button.get_path_to(below)


func _on_choice_input(event: InputEvent, field: String) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		cycle(field, -1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()


func _step_button(node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(48, 44)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	return button


func _text_button(node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(100, 50)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	return button


# =========================================================================
# Presentation
# =========================================================================

func _refresh_rows() -> void:
	var colors := CustomCharacter.colors(_record)
	for spec in FIELDS:
		var field := String(spec["field"])
		var label: Label = _value_labels.get(field, null)
		if label == null:
			continue
		label.text = Text.option(String(_record.get(field, CustomCharacter.default_option(field))))
		var swatch: ColorRect = _color_swatches.get(field, null)
		if swatch != null:
			var color_key := "skin" if field == "skin_id" else ("hair" if field == "hair_color_id" else "outfit")
			swatch.color = colors[color_key]
	if _name_edit != null and _name_edit.text != String(_record.get("display_name", "")):
		_name_edit.text = String(_record.get("display_name", ""))


## The card portrait is taken from this live preview (2026-09-27): a few frames after
## the athlete last changed, the upper body is cut out of the real 3D frame and cached
## for this exact appearance (`CustomCharacterPortrait.store_preview`).
const PORTRAIT_SETTLE_FRAMES := 6
var _portrait_wait: int = -1


func _schedule_portrait() -> void:
	_portrait_wait = PORTRAIT_SETTLE_FRAMES


func _process(_delta: float) -> void:
	if _portrait_wait < 0:
		return
	_portrait_wait -= 1
	if _portrait_wait > 0:
		return
	_portrait_wait = -1
	_capture_portrait()


func _capture_portrait() -> void:
	if _rig == null or _viewport == null or DisplayServer.get_name() == "headless":
		return
	var camera := _viewport.get_node_or_null("PreviewCamera") as Camera3D
	var skeleton: Skeleton3D = _rig.get_skeleton()
	if camera == null or skeleton == null:
		return
	var top_bone := skeleton.find_bone("head_end")
	var hip_bone := skeleton.find_bone(_rig._resolve_bone_name("Hips"))
	if top_bone < 0 or hip_bone < 0:
		return
	var top: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(top_bone).origin
	var hips: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hip_bone).origin
	var span := top.y - hips.y
	var a := camera.unproject_position(top + Vector3.UP * span * 0.25)
	var b := camera.unproject_position(hips - Vector3.UP * span * 0.15)
	var height := absf(b.y - a.y)
	var focus := Rect2(Vector2(a.x - height * 0.4, minf(a.y, b.y)), Vector2(height * 0.8, height))
	CustomCharacterPortrait.store_preview(edited_record(), _viewport.get_texture().get_image(), focus)


func _apply_preview() -> void:
	if _rig == null:
		_ensure_rig()
		return
	_schedule_portrait()
	if not _rig.apply_appearance(edited_record()):
		# A new body is a new model: rebuild the preview instead of reporting an error.
		if _rig.has_method("body_id") and _rig.body_id() != &"":
			_rig.get_parent().remove_child(_rig)
			_rig.queue_free()
			_rig = null
			_ensure_rig()
			return
		error = Text.t("customErrorPreview")
		_show_error()


func _show_error() -> void:
	if _error_label != null:
		_error_label.text = error


# =========================================================================
# Input
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
