extends RefCounted
## custom_body_look.gd — dresses a "Crea atleta" Meshy body (2026-09-27): the recolour
## shader on the body mesh (shirt, shorts, skin) and the chosen hair piece on the head.
##
## The bodies and hair pieces are Meshy models generated from the owner's references in
## neutral colours (art/character-creator/RICHIESTA-2D-CORPI.md). A hair piece is a rigid
## model on a BoneAttachment3D of the head bone, fitted to the head by the head bone's
## own length, so it follows every animation without skinning.

const BODY_SHADER := preload("res://src/character/custom_body_skin.gdshader")
const HAIR_SHADER := preload("res://src/character/custom_hair_tint.gdshader")
const HAIR_DIR := "res://assets/custom_character/"
const HAIR_NODE := "CustomHair"
const HEAD_NODE := "CustomHeadScale"
const HeadScale := preload("res://src/character/custom_head_scale.gd")
## Head scale per body. Body height / head height alone asked for ~3-16%, and the owner's
## eye still read the heads as small: the Meshy heads are narrow and realistic against
## broad shoulders, where the roster's are stylised and wide. Tuned by eye beside Maestro.
const HEAD_SCALES := {
	&"cc_donna_media": 1.12,
	&"cc_donna_atletica": 1.12,
	&"cc_uomo_medio": 1.15,
	&"cc_uomo_robusto": 1.28,
}

## hair id -> [model file, size, down, back], all in head lengths (the Head bone to
## head_end distance, ~0.17 m): the model's size, and where its centre sits below the
## skull top (`head_end`) and behind it. The pieces are upright with their face side on
## +Z, like the head. "buzz" is the bald body itself.
const HAIRS := {
	&"crop": ["capelli_corti.glb", 1.25, 0.38, 0.0],
	&"ponytail": ["capelli_coda.glb", 1.95, 0.85, 0.3],
	&"curly": ["capelli_ricci.glb", 1.5, 0.5, 0.14],
	&"bun": ["capelli_chignon.glb", 1.5, 0.57, 0.15],
}


## Applies colours and hair. `colors` is `CustomCharacter.colors(record)`-shaped:
## skin, hair, outfit, accent. Returns false when the rig has no mesh to dress.
static func apply(rig: Node3D, hair_id: StringName, colors: Dictionary) -> bool:
	var mesh: MeshInstance3D = rig.get_mesh_instance()
	if mesh == null or mesh.mesh == null:
		return false
	var mat := mesh.get_surface_override_material(0) as ShaderMaterial
	if mat == null or mat.shader != BODY_SHADER:
		var base := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		mat = ShaderMaterial.new()
		mat.shader = BODY_SHADER
		if base != null:
			mat.set_shader_parameter("albedo_tex", base.albedo_texture)
		# The shader measures heights in world units from the mesh node's origin (the feet):
		# the Meshy mesh is authored in centimetres under a 0.01 node, so its own AABB is
		# not the body's height; the rig's posed extent is.
		mat.set_shader_parameter("feet_y", 0.0)
		mat.set_shader_parameter("body_height", maxf(rig.get_world_extent().size.y, 1.0))
		mesh.set_surface_override_material(0, mat)
	mat.set_shader_parameter("shirt_color", _rgb(colors.get("outfit", Color.WHITE)))
	mat.set_shader_parameter("shorts_color", _rgb(colors.get("accent", Color.BLACK)))
	mat.set_shader_parameter("skin_color", _rgb(colors.get("skin", Color.WHITE)))
	_apply_head_scale(rig)
	_apply_hair(rig, hair_id, colors.get("hair", Color.BLACK))
	return true


static func _apply_head_scale(rig: Node3D) -> void:
	var skeleton: Skeleton3D = rig.get_skeleton()
	if skeleton == null or skeleton.get_node_or_null(HEAD_NODE) != null:
		return
	var scale := float(HEAD_SCALES.get(StringName(rig._athlete_id), 1.0))
	if is_equal_approx(scale, 1.0):
		return
	var mod := HeadScale.new()
	mod.name = HEAD_NODE
	mod.head_bone = skeleton.find_bone(rig._resolve_bone_name("Head"))
	mod.head_scale = scale
	skeleton.add_child(mod)


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## The mesh's scale up its parent chain (before it is in the tree).
static func _chain_scale(node: Node) -> float:
	var s := 1.0
	var n := node
	while n != null:
		if n is Node3D:
			s *= (n as Node3D).scale.y
		n = n.get_parent()
	return s


static func _apply_hair(rig: Node3D, hair_id: StringName, color: Color) -> void:
	var skeleton: Skeleton3D = rig.get_skeleton()
	if skeleton == null:
		return
	var old := skeleton.get_node_or_null(HAIR_NODE)
	var spec: Array = HAIRS.get(hair_id, [])
	var is_b_crop := StringName(rig._athlete_id) == &"cc_uomo_b" and hair_id == &"crop"
	if is_b_crop:
		# Calibrated against the B head; the source hair has no baked texture.
		spec = ["capelli_b_corti.glb", 1.15 / 1.898894, 0.30, 0.23]
	if old != null and (spec.is_empty() or String(old.get_meta("hair_id", "")) != String(hair_id)):
		skeleton.remove_child(old)
		old.queue_free()
		old = null
	if spec.is_empty():
		return
	if old == null:
		var head := skeleton.find_bone(rig._resolve_bone_name("Head"))
		var head_end := skeleton.find_bone("head_end")
		if head < 0:
			return
		var packed := load(HAIR_DIR + String(spec[0])) as PackedScene
		if packed == null:
			return
		var attach := BoneAttachment3D.new()
		attach.name = HAIR_NODE
		attach.set_meta("hair_id", String(hair_id))
		attach.bone_name = skeleton.get_bone_name(head)
		skeleton.add_child(attach)
		# Placed in the skeleton's rest space (world-aligned), then expressed in the head
		# bone's frame: the head bone leans back ~30 deg, and a hair piece aligned to it
		# covered the eyes and left the nape bare.
		var head_rest := skeleton.get_bone_global_rest(head)
		var top: Vector3 = skeleton.get_bone_global_rest(head_end).origin if head_end >= 0 else head_rest.origin + Vector3.UP * 17.0
		var head_len: float = head_rest.origin.distance_to(top)
		var centre := top + Vector3(0.0, -head_len * float(spec[2]), -head_len * float(spec[3]))
		var hair := packed.instantiate() as Node3D
		hair.name = "Model"
		var local_basis := head_rest.basis.orthonormalized().inverse() * Basis.from_scale(Vector3.ONE * head_len * float(spec[1]))
		if is_b_crop:
			local_basis = head_rest.basis.orthonormalized().inverse() * Basis.from_scale(Vector3(1, 1.1, 1.6) * head_len * float(spec[1]))
		hair.transform = Transform3D(local_basis, head_rest.affine_inverse() * centre)
		attach.add_child(hair)
		old = attach
	var tint := ShaderMaterial.new()
	tint.shader = HAIR_SHADER
	tint.set_shader_parameter("hair_color", _rgb(color))
	for m in old.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_b_crop:
			var solid := StandardMaterial3D.new()
			solid.albedo_color = color
			solid.roughness = 0.8
			mi.material_override = solid
			continue
		var base := mi.mesh.surface_get_material(0) as BaseMaterial3D if mi.mesh != null else null
		if base != null:
			tint.set_shader_parameter("albedo_tex", base.albedo_texture)
		mi.material_override = tint
