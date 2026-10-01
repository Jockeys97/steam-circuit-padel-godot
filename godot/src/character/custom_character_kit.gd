extends RefCounted
class_name CustomCharacterKit
## CustomCharacterKit — the custom athlete's body, generated in code.
##
## ===========================================================================
## WHY GENERATED GEOMETRY AND NOT A TINT OF AN EXISTING ATHLETE
## ===========================================================================
## `docs/art/character-standard.md` freezes each roster GLB as one mesh, one skin,
## one primitive and one baked material. There is no hair region, no skin region and
## no garment region in that atlas, so "recolouring" a roster athlete is a tint of
## the whole body — the thing the design forbids. This kit instead builds its own
## modular mesh: a tapered segment per bone with a sphere at every joint, grouped
## into MATERIAL REGIONS (skin, hair, outfit, accent, shoe). Each region is its own
## surface with its own material, so skin, hair and garment colours move
## independently by construction, and a hair or outfit variant is a different set of
## segments — a different shape, not a different colour of the same shape.
##
## ===========================================================================
## HOW IT BINDS TO THE EXISTING RIG (animation compatibility)
## ===========================================================================
## The kit does not carry its own skeleton and does not import anything. It is handed
## the Skeleton3D an existing `AthleteRig` already built — volpe's 24-joint
## `mixamorig:`-style rig or a Meshy 28-joint one — and every vertex it emits is
## weighted to those bones by name. The skin's bind poses are the skeleton's own rest
## transforms, so at rest the mesh sits exactly where the segments were generated and
## every clip the rig already authors (idle, walk, run, the four padel strokes)
## drives it with no retargeting and no second rig. Bone names are resolved through a
## candidate list per role, so the same kit works on both naming conventions.
##
## ===========================================================================
## WHAT A CALLER DOES
## ===========================================================================
##     var kit := CustomCharacterKit.new()
##     var mesh_instance := kit.build(skeleton, record)   # null on failure
##     ...           # add mesh_instance under the skeleton's parent, set skeleton path
##     kit.apply(new_record)                             # recolour / re-shape in place
##     kit.describe()                                    # evidence: regions, triangles, mode
##
## `build()` never throws and never half-builds: it returns null and leaves
## `error` set, so a caller can show the editor's error line and keep the six
## canonical athletes playable.

const CustomCharacter := preload("res://src/character/custom_character.gd")

const SIDES := 12

## Role -> bone names to try, in order. Covers the Meshy 28-joint `mixamorig:` export
## and volpe's 24-joint fallback spelling.
const BONE_NAMES := {
	"hips": ["mixamorig:Hips", "Hips"],
	"spine": ["mixamorig:Spine", "Spine"],
	"spine_mid": ["mixamorig:Spine1", "mixamorig:Spine01", "Spine1", "Spine01"],
	"spine_top": ["mixamorig:Spine2", "mixamorig:Spine02", "Spine2", "Spine02"],
	"neck": ["mixamorig:Neck", "neck", "Neck"],
	"head": ["mixamorig:Head", "Head"],
	"head_top": ["mixamorig:HeadTop_End", "headfront", "head_end"],
	"l_shoulder": ["mixamorig:LeftShoulder", "LeftShoulder"],
	"l_arm": ["mixamorig:LeftArm", "LeftArm"],
	"l_forearm": ["mixamorig:LeftForeArm", "LeftForeArm"],
	"l_hand": ["mixamorig:LeftHand", "LeftHand"],
	"l_hand_end": ["mixamorig:LeftHandMiddle4", "LeftHandEnd"],
	"r_shoulder": ["mixamorig:RightShoulder", "RightShoulder"],
	"r_arm": ["mixamorig:RightArm", "RightArm"],
	"r_forearm": ["mixamorig:RightForeArm", "RightForeArm"],
	"r_hand": ["mixamorig:RightHand", "RightHand"],
	"r_hand_end": ["mixamorig:RightHandMiddle4", "RightHandEnd"],
	"l_upleg": ["mixamorig:LeftUpLeg", "LeftUpLeg"],
	"l_leg": ["mixamorig:LeftLeg", "LeftLeg"],
	"l_foot": ["mixamorig:LeftFoot", "LeftFoot"],
	"l_toe": ["mixamorig:LeftToeBase", "LeftToeBase"],
	"r_upleg": ["mixamorig:RightUpLeg", "RightUpLeg"],
	"r_leg": ["mixamorig:RightLeg", "RightLeg"],
	"r_foot": ["mixamorig:RightFoot", "RightFoot"],
	"r_toe": ["mixamorig:RightToeBase", "RightToeBase"],
}

## The material regions, in surface order. A region is one surface with one material.
const REGIONS := ["skin", "hair", "outfit", "accent", "shoe", "eyes"]

var error: String = ""
var mode: String = "none"
var triangles: int = 0
var bones_bound: int = 0

var _skeleton: Skeleton3D = null
var _mesh: MeshInstance3D = null
var _record: Dictionary = {}
var _bones: Dictionary = {}
var _surfaces: Dictionary = {}
var _materials: Dictionary = {}
var _vertex_counts: Dictionary = {}
## Metres per skeleton unit, measured off the rig itself: the roster ships both metre and
## centimetre skeletons, so radii and offsets are scaled rather than assumed.
var _unit: float = 1.0
## The athlete's height in skeleton units, for whoever has to frame a camera.
var body_height: float = 0.0
var body_center: Vector3 = Vector3.ZERO


# =========================================================================
# Public API
# =========================================================================

## Builds the athlete's mesh for `record` on `skeleton`. Returns the MeshInstance3D
## (already configured with skin + skeleton path) or null, with `error` set.
func build(skeleton: Skeleton3D, record: Dictionary) -> MeshInstance3D:
	error = ""
	_skeleton = skeleton
	_record = CustomCharacter.normalize(record)
	if _skeleton == null:
		error = "no skeleton"
		return null
	_bones = _resolve_bones()
	if _bones.size() < 10:
		error = "skeleton did not resolve the expected humanoid bones (%d found)" % _bones.size()
		return null
	_measure_units()
	_mesh = MeshInstance3D.new()
	_mesh.name = "CustomKitMesh"
	# Face/edge tolerance: a skinned pose can push geometry outside the cached AABB.
	_mesh.extra_cull_margin = 4.0
	_apply_geometry()
	return _mesh


## Changes appearance on an already-built kit. Rebuilds the mesh (a variant swaps
## geometry) and re-colours the materials. No skeleton, no node, no skin change.
func apply(record: Dictionary) -> bool:
	if _mesh == null:
		error = "apply() before build()"
		return false
	_record = CustomCharacter.normalize(record)
	_apply_geometry()
	return error == ""


func mesh_instance() -> MeshInstance3D:
	return _mesh


func set_visible(value: bool) -> void:
	if _mesh != null:
		_mesh.visible = value


## The evidence shape: what was built, on which bones, in which colours.
func describe() -> Dictionary:
	var colors := CustomCharacter.colors(_record)
	var out := {
		"mode": mode,
		"error": error,
		"triangles": triangles,
		"bones_bound": bones_bound,
		"regions": REGIONS.duplicate(),
		"surfaces": _surfaces.size(),
		"appearance": _record.duplicate(true),
		"signature": CustomCharacter.signature(_record),
		"colors": {},
	}
	for region in colors:
		out["colors"][region] = (colors[region] as Color).to_html(false)
	return out


## Per-surface material colour of what is actually on the GPU, read back off the
## mesh rather than from the record: the test that proves the preview really changed.
func surface_colors() -> Dictionary:
	var out := {}
	if _mesh == null or _mesh.mesh == null:
		return out
	var mesh := _mesh.mesh
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if mat is StandardMaterial3D:
			out[mesh.surface_get_name(i)] = (mat as StandardMaterial3D).albedo_color.to_html(false)
	return out


# =========================================================================
# Geometry
# =========================================================================

func _resolve_bones() -> Dictionary:
	var out := {}
	for role in BONE_NAMES:
		for candidate in BONE_NAMES[role]:
			var index := _skeleton.find_bone(String(candidate))
			if index >= 0:
				out[role] = index
				break
	return out


func _rest_origin(role: String) -> Vector3:
	if not _bones.has(role):
		return Vector3.ZERO
	return _skeleton.get_bone_global_rest(int(_bones[role])).origin


func _has(role: String) -> bool:
	return _bones.has(role)


## How many metres one skeleton unit is. The frozen roster carries both a metre rig and
## centimetre legacy exports, and the kit has to be the same athlete on either.
func _measure_units() -> void:
	var head := _rest_origin("head")
	var foot := _rest_origin("r_foot")
	if absf(foot.y) < 0.0001:
		foot = _rest_origin("l_foot")
	var span := absf(head.y - foot.y)
	# Skeleton units PER METRE: the roster ships 1.75 m rigs in both metres and
	# centimetres, so a metre radius has to be multiplied by this and never divided by
	# it — the inverted factor is what made the first build a set of hairlines.
	_unit = (span / 1.75) if span > 0.05 else 1.0
	body_height = 1.75
	body_center = Vector3(
		(head.x + foot.x) * 0.5, (head.y + foot.y) * 0.5, 0.0) / maxf(_unit, 0.0001)


func _apply_geometry() -> void:
	_surfaces = {}
	_vertex_counts = {}
	triangles = 0
	for region in REGIONS:
		_surfaces[region] = SurfaceTool.new()
		(_surfaces[region] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
		_vertex_counts[region] = 0
	_compose(_record)
	mode = "skinned"
	var mesh := _commit()
	if mesh == null:
		error = "commit failed"
		return
	_mesh.mesh = mesh
	_mesh.skin = _make_skin()
	if _mesh.skin == null:
		mode = "rest_static"
		error = "skin could not be created; mesh shows only the rest pose"
	bones_bound = _bones.size()


## One surface per region, each with its own material, assembled into one ArrayMesh.
func _commit() -> ArrayMesh:
	var out := ArrayMesh.new()
	var any := false
	for region in REGIONS:
		var st: SurfaceTool = _surfaces[region]
		if int(_vertex_counts.get(region, 0)) == 0:
			continue
		var part := st.commit()
		if part == null:
			continue
		var arrays := part.surface_get_arrays(0)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0:
			triangles += int((indices as PackedInt32Array).size() / 3)
		else:
			triangles += int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
		var index := out.get_surface_count()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_name(index, region)
		out.surface_set_material(index, _material_for(region))
		any = true
	return out if any else null


func _make_skin() -> Skin:
	var skin := Skin.new()
	# Vertex bone indices address skin bind slots, not the role dictionary. Keep
	# one slot per skeleton bone, including bones unused by the generated mesh.
	for index in _skeleton.get_bone_count():
		skin.add_bind(index, _skeleton.get_bone_global_rest(index).affine_inverse())
	return skin


func _material_for(region: String) -> StandardMaterial3D:
	var colors := CustomCharacter.colors(_record)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Custom_%s" % region
	mat.albedo_color = colors.get(region, Color.WHITE)
	mat.metallic = 0.0
	mat.roughness = 0.8
	mat.emission_enabled = false
	# Both windings render: the kit is built procedurally and a mirrored winding on
	# some ring would otherwise punch a hole in the silhouette mid-animation.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# =========================================================================
# The kit itself: which segments exist, and for which variant
# =========================================================================

func _compose(record: Dictionary) -> bool:
	var hair := StringName(record["hair_id"])
	var outfit := StringName(record["outfit_id"])

	# --- torso: one block per spine bone, so it bends with the spine ---------
	_segment("hips", "spine", 0.15, 0.155, "outfit")
	_segment("spine", "spine_mid", 0.155, 0.165, "outfit")
	_segment("spine_mid", "spine_top", 0.165, 0.17, "outfit")
	_sphere("hips", Vector3.ZERO, 0.17, "outfit", Vector3(1.0, 0.7, 0.75))
	_sphere("spine_top", Vector3.ZERO, 0.17, "outfit", Vector3(1.1, 0.75, 0.8))
	# Belt: the accent band that makes the two-tone kit read as designed.
	_segment_at("spine", "spine_mid", 0.14, 0.11, "accent", 0.98)

	# --- head and neck ------------------------------------------------------
	_segment("neck", "head", 0.055, 0.065, "skin")
	_sphere("head", Vector3(0, 0.055, 0.0), 0.105, "skin", Vector3(1.0, 1.12, 1.05))
	for x in [-0.039, 0.039]:
		_sphere("head", Vector3(x, 0.075, 0.094), 0.019, "eyes", Vector3(1.0, 0.7, 0.5))
		_sphere("head", Vector3(x, 0.075, 0.103), 0.009, "shoe", Vector3(1, 1, 0.5))
	# A small face plate, so the head has a front in the preview.
	_sphere("head", Vector3(0, 0.045, 0.085), 0.045, "skin", Vector3(1.1, 1.0, 0.6))

	# --- arms: sleeve coverage depends on the outfit variant ----------------
	var sleeved := outfit == &"circuit" or outfit == &"varsity"
	var upper_region := "outfit" if sleeved else "skin"
	for side in ["l", "r"]:
		_sphere("%s_arm" % side, Vector3.ZERO, 0.066, upper_region, Vector3.ONE)
		_sphere("%s_forearm" % side, Vector3.ZERO, 0.051, "skin", Vector3.ONE)
		_segment("%s_shoulder" % side, "%s_arm" % side, 0.06, 0.062, upper_region)
		_segment("%s_arm" % side, "%s_forearm" % side, 0.062, 0.05, upper_region)
		_segment("%s_forearm" % side, "%s_hand" % side, 0.05, 0.04, "skin")
		_sphere("%s_hand" % side, Vector3.ZERO, 0.052, "skin", Vector3(1.0, 0.8, 1.3))

	# --- legs: garment coverage depends on the outfit variant ---------------
	var thigh_region := "outfit"
	var shin_region := "outfit" if outfit == &"training" or outfit == &"varsity" else "skin"
	for side in ["l", "r"]:
		_sphere("%s_upleg" % side, Vector3.ZERO, 0.106, thigh_region, Vector3.ONE)
		_sphere("%s_leg" % side, Vector3.ZERO, 0.087, shin_region, Vector3.ONE)
		_segment("%s_upleg" % side, "%s_leg" % side, 0.105, 0.085, thigh_region)
		_segment("%s_leg" % side, "%s_foot" % side, 0.085, 0.06, shin_region)
		_segment("%s_foot" % side, "%s_toe" % side, 0.062, 0.05, "shoe")
		_sphere("%s_foot" % side, Vector3(0, -0.02, 0), 0.062, "shoe", Vector3(1.0, 0.7, 1.0))

	# --- variant 3: a one-piece carried by the shoulders --------------------
	if outfit == &"varsity":
		_segment_at("spine", "spine_top", 0.10, 0.10, "accent", 1.02)

	# --- hair variants: different shapes, not a recolour --------------------
	match hair:
		&"buzz":
			_sphere("head", Vector3(0, 0.12, -0.015), 0.107, "hair", Vector3(1.02, 0.52, 1.02))
		&"crop":
			_sphere("head", Vector3(0, 0.135, -0.015), 0.108, "hair", Vector3(1.03, 0.65, 1.03))
			_sphere("head", Vector3(0, 0.13, 0.062), 0.05, "hair", Vector3(1.5, 0.6, 0.7))
		_:
			# ponytail: cap plus a strand gathered behind the head
			_sphere("head", Vector3(0, 0.12, -0.035), 0.108, "hair", Vector3(1.03, 0.65, 1.03))
			_sphere("head", Vector3(0, 0.04, -0.12), 0.055, "hair", Vector3(0.8, 1.0, 1.9))
			_sphere("head", Vector3(0, -0.12, -0.13), 0.04, "hair", Vector3(0.8, 1.5, 0.8))
	return true


# =========================================================================
# Primitives
# =========================================================================

## A tapered tube from the rest origin of `a` to the rest origin of `b`. The start
## ring is fully weighted to `a`; the end ring is split with `b`, so the joint bends
## smoothly instead of tearing.
func _segment(a: String, b: String, r0: float, r1: float, region: String) -> void:
	_segment_at(a, b, r0, r1, region, 0.0)


func _segment_at(a: String, b: String, r0: float, r1: float, region: String, start_offset: float) -> void:
	if not (_has(a) and _has(b)):
		return
	var pa := _rest_origin(a)
	var pb := _rest_origin(b)
	var axis := pb - pa
	if axis.length() < 0.0001:
		return
	axis = axis.normalized()
	r0 *= _unit
	r1 *= _unit
	if start_offset != 0.0:
		pa += axis * (start_offset * axis.length())
	# The reference vector must not be parallel to the bone: a spine or a shin is almost
	# exactly UP, and `axis.cross(UP)` is then a zero vector whose normalisation is
	# garbage — every ring collapsed onto the bone and the athlete rendered as slivers.
	var reference := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var side := axis.cross(reference).normalized()
	var up := side.cross(axis).normalized()
	var st: SurfaceTool = _surfaces[region]
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for i in SIDES:
		var angle := TAU * float(i) / float(SIDES)
		var radial := side * cos(angle) + up * sin(angle)
		ring_a.append(pa + radial * r0)
		ring_b.append(pb + radial * r1)
	for i in SIDES:
		var j := (i + 1) % SIDES
		# side quad, start ring weighted to `a`, end ring split with `b`
		_add_vertex(st, ring_a[i], side * cos(TAU * float(i) / SIDES) + up * sin(TAU * float(i) / SIDES), a, b, 1.0)
		_add_vertex(st, ring_b[i], side * cos(TAU * float(i) / SIDES) + up * sin(TAU * float(i) / SIDES), a, b, 0.0)
		_add_vertex(st, ring_b[j], side * cos(TAU * float(j) / SIDES) + up * sin(TAU * float(j) / SIDES), a, b, 0.0)
		_add_vertex(st, ring_a[i], side * cos(TAU * float(i) / SIDES) + up * sin(TAU * float(i) / SIDES), a, b, 1.0)
		_add_vertex(st, ring_b[j], side * cos(TAU * float(j) / SIDES) + up * sin(TAU * float(j) / SIDES), a, b, 0.0)
		_add_vertex(st, ring_a[j], side * cos(TAU * float(j) / SIDES) + up * sin(TAU * float(j) / SIDES), a, b, 1.0)
	# end caps, so the silhouette is closed
	var center_a := pa
	var center_b := pb
	for i in SIDES:
		var j := (i + 1) % SIDES
		_add_vertex(st, center_a, -axis, a, b, 1.0)
		_add_vertex(st, ring_a[j], -axis, a, b, 1.0)
		_add_vertex(st, ring_a[i], -axis, a, b, 1.0)
		_add_vertex(st, center_b, axis, a, b, 0.0)
		_add_vertex(st, ring_b[i], axis, a, b, 0.0)
		_add_vertex(st, ring_b[j], axis, a, b, 0.0)


## A sphere at a bone's rest origin, offset in that bone's own space, all vertices
## weighted to the bone.
func _sphere(role: String, offset: Vector3, radius: float, region: String, scale: Vector3) -> void:
	if not _has(role):
		return
	var bone := int(_bones[role])
	var bind := _skeleton.get_bone_global_rest(bone)
	var scaled_radius := radius * _unit
	var center := bind.origin + offset * _unit
	var st: SurfaceTool = _surfaces[region]
	var rings := 5
	var segments := SIDES
	var points: Array[Array] = []
	for r in rings + 1:
		var phi := PI * float(r) / float(rings)
		var row: Array[Vector3] = []
		for s in segments:
			var theta := TAU * float(s) / float(segments)
			var unit := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			row.append(center + Vector3(unit.x * scale.x, unit.y * scale.y, unit.z * scale.z) * scaled_radius)
		points.append(row)
	for r in rings:
		for s in segments:
			var s2 := (s + 1) % segments
			var quad := [points[r][s], points[r + 1][s], points[r + 1][s2], points[r][s2]]
			for order in [0, 1, 2, 0, 2, 3]:
				var vertex: Vector3 = quad[order]
				_add_vertex(st, vertex, (vertex - center).normalized(), role, "", 1.0)


func _add_vertex(st: SurfaceTool, position: Vector3, normal: Vector3,
		bone_a: String, bone_b: String, weight_a: float) -> void:
	var region := _region_of(st)
	_vertex_counts[region] = int(_vertex_counts.get(region, 0)) + 1
	var ia := int(_bones[bone_a])
	var ib := int(_bones[bone_b]) if bone_b != "" and _bones.has(bone_b) else ia
	var wa := clampf(weight_a, 0.0, 1.0)
	var wb := 1.0 - wa if ib != ia else 0.0
	var wa_final := wa if ib != ia else 1.0
	st.set_bones(PackedInt32Array([ia, ib, 0, 0]))
	st.set_weights(PackedFloat32Array([wa_final, wb, 0.0, 0.0]))
	st.set_normal(normal.normalized())
	st.add_vertex(position)


## Which region a SurfaceTool belongs to. `_add_vertex` is the only place that needs
## it, because SurfaceTool has no vertex-count query of its own.
func _region_of(st: SurfaceTool) -> String:
	for region in _surfaces:
		if _surfaces[region] == st:
			return String(region)
	return ""
