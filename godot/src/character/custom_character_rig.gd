extends "res://src/character/athlete_rig.gd"
## No `class_name` (2026-09-27): the project reaches scripts through `preload` consts
## (`godot/src/save/README.md`), and a global class name here collided with the
## `const CustomCharacterRig := preload(...)` its callers declare - headless runs
## failed with "Identifier not found: CustomCharacterRig" and took match_config down.
## Inherit the full playable API: racket, anticipation, strokes and foot planting.
## Only the visible body is replaced with the independently coloured kit.
const Kit := preload("res://src/character/custom_character_kit.gd")
const Appearance := preload("res://src/character/custom_character.gd")
const Look := preload("res://src/character/custom_body_look.gd")
const Self := preload("res://src/character/custom_character_rig.gd")
const SOURCE_ATHLETE := &"maestro"

var error: String = ""
var _kit: RefCounted
var _record: Dictionary = {}
## The Meshy body this rig was built on (`cc_<body>`), or &"" for the procedural kit.
var _body: StringName = &""

static func make(record: Dictionary, opts: Dictionary = {}) -> Node3D:
	var node = Self.new()
	node.name = String(opts.get("name", "CustomAthlete"))
	if not node._build_custom(record, bool(opts.get("kit", false))):
		node.free()
		return null
	node.position = opts.get("position", Vector3.ZERO)
	node.set_facing_degrees(float(opts.get("facing_degrees", 0.0)))
	return node

func _build_custom(record: Dictionary, force_kit: bool = false) -> bool:
	_record = Appearance.normalize(record)
	# The Meshy body (2026-09-27) when its model is present; the procedural kit below is
	# the fallback (and what `opts.kit` asks for, e.g. the kit's own tests).
	var body := Appearance.body_rig_id(_record)
	if not force_kit and ResourceLoader.exists(String(ATHLETE_GLB.get(body, ""))):
		if set_athlete_asset(body) and get_load_error() == OK and get_skeleton() != null:
			_body = body
			Look.apply(self, StringName(_record["hair_id"]), Appearance.colors(_record))
			play_locomotion(&"idle")
			return true
		error = "body rig unavailable"
		return false
	if not set_athlete_asset(SOURCE_ATHLETE) or get_load_error() != OK:
		error = "base rig unavailable"
		return false
	var skeleton := get_skeleton()
	if skeleton == null:
		return false
	get_mesh_instance().hide()
	_kit = Kit.new()
	var mesh: MeshInstance3D = _kit.build(skeleton, _record)
	if mesh == null:
		error = _kit.error
		return false
	skeleton.get_parent().add_child(mesh)
	mesh.skeleton = mesh.get_path_to(skeleton)
	play_locomotion(&"idle")
	return true

func apply_appearance(record: Dictionary) -> bool:
	var next := Appearance.normalize(record)
	if _body != &"":
		# A different body is a different model: the caller rebuilds the rig.
		if Appearance.body_rig_id(next) != _body:
			return false
		_record = next
		return Look.apply(self, StringName(_record["hair_id"]), Appearance.colors(_record))
	_record = next
	return _kit != null and _kit.apply(_record)


## The Meshy body id this rig wears (`cc_<body>`), or &"" on the procedural kit.
func body_id() -> StringName:
	return _body

func appearance() -> Dictionary:
	return _record.duplicate(true)

func kit() -> RefCounted:
	return _kit

func custom_mesh() -> MeshInstance3D:
	if _body != &"":
		return get_mesh_instance()
	return _kit.mesh_instance() if _kit != null else null

func base_rig() -> Node3D:
	return self

func get_athlete_asset() -> StringName:
	return Appearance.ID

func world_bounds() -> AABB:
	if _body != &"":
		return get_world_extent()
	var mesh := custom_mesh()
	if mesh == null:
		return AABB()
	var xform := Transform3D.IDENTITY
	var node: Node = get_skeleton()
	while node != null and node != self:
		if node is Node3D:
			xform = node.transform * xform
		node = node.get_parent()
	return xform * mesh.mesh.get_aabb()

func describe() -> Dictionary:
	return {"athlete_id": String(Appearance.ID), "source_athlete": String(SOURCE_ATHLETE),
		"error": error, "bones": get_skeleton().get_bone_count(),
		"kit": _kit.describe() if _kit != null else {"appearance": _record.duplicate(true), "body": String(_body)}, "body": String(_body), "mesh_visible": custom_mesh().visible,
		"baked_mesh_visible": get_mesh_instance().visible,
		"locomotion": String(get_locomotion_state()), "strokes": get_stroke_names().size()}
