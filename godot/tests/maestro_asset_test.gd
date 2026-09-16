## maestro_asset_test.gd — focused gate for the IL MAESTRO athlete asset.
##
## Same shape as res://tests/colosso_asset_test.gd: one `ok <name>` / `FAIL <name>`
## line per check, exactly one `PASS n/n` / `FAIL n/n` tally line, exit 0 on PASS
## and 1 on FAIL. It deliberately exercises only the Maestro path — the rigged
## base plus the three companion GLBs (idle / walking / running) adopted through
## COMPANION_CLIPS. The existing rig test keeps covering the Volpe fallback.
##
## Every measured value is printed as a `MEASURED` line so the evidence file can
## quote it. Run from the repo root:
##   GODOT_SILENCE_ROOT_WARNING=1 "$GODOT" --headless --path godot/ \
##     --script res://tests/maestro_asset_test.gd
extends SceneTree

const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

## The 24 joints of the maestro-rigged export, measured in engine (same names and
## order as the Volpe rig the port already ships).
const EXPECTED_BONES := [
	"Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
	"Spine02", "Spine01", "Spine",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"neck", "Head", "head_end", "headfront",
]
const EXPECTED_TRIANGLES := 30980

## Tolerant clip-length windows [nominal, tolerance] in seconds. The pack's nominal
## lengths are idle 4.033 / walking 1.067 / running 0.667; the window is tight
## enough that the 0.30 s bind hold can never pass as an idle.
const CLIP_WINDOWS := {
	&"idle": [4.033, 0.10],
	&"walk": [1.067, 0.05],
	&"run": [0.667, 0.05],
}

## Below this, a played clip is indistinguishable from a held pose (quaternion
## component units), same epsilon the rig test uses.
const MOTION_EPSILON := 0.01

var _checks := 0
var _failures := 0


func _initialize() -> void:
	var rig: Node3D = AthleteSpawn.make(&"maestro", &"base", {
		"name": "MaestroAssetProbe",
		"locomotion": &"idle",
	})
	check_true(rig != null, "Maestro spawns through the normal factory")
	if rig == null:
		_finish()
		return

	var details := AthleteSpawn.describe(rig)
	check_eq(details.get("athlete_asset", &""), &"maestro", "Maestro selects the maestro asset")
	check_eq(details.get("load_error", -1), OK, "Maestro GLB loads")

	var joints := int(details.get("joints", 0))
	print("MEASURED joints=%d" % joints)
	check_true(joints >= 24, "Maestro keeps at least the 24-joint humanoid (%d)" % joints)
	_check_bone_names(rig)

	var triangles := int(details.get("triangles", 0))
	print("MEASURED triangles=%d (pack says %d)" % [triangles, EXPECTED_TRIANGLES])
	check_eq(triangles, EXPECTED_TRIANGLES, "Maestro carries the remeshed 30,980-triangle mesh")
	check_eq(int(details.get("surfaces", 0)), 1, "Maestro mesh has one surface")

	_check_clips(rig)
	# The rest-pose measurements come before any sample_at() call: in a headless
	# tree the skeleton pose is still the GLB rest pose until something samples.
	_check_world_extent(rig)
	_check_material(rig)
	_check_locomotion_plays(rig)
	_check_locomotion_motion(rig)
	_check_strokes(rig)

	rig.free()
	_finish()


func _check_bone_names(rig: Node) -> void:
	var sk: Skeleton3D = rig.get_skeleton()
	if sk == null:
		check_true(false, "skeleton present (bone-name check skipped)")
		return
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	print("MEASURED bone_names=%s" % str(names))
	check_eq(str(names), str(EXPECTED_BONES), "joint names and order match the Meshy humanoid rig")


func _check_clips(rig: Node) -> void:
	var states: Array = rig.get_locomotion_states()
	check_true(&"idle" in states, "Maestro has idle")
	check_true(&"walk" in states, "Maestro has walk")
	check_true(&"run" in states, "Maestro has run")
	for clip in CLIP_WINDOWS:
		var length: float = rig.get_clip_length(clip)
		var nominal: float = CLIP_WINDOWS[clip][0]
		var tolerance: float = CLIP_WINDOWS[clip][1]
		print("MEASURED clip_length %s=%.6f (nominal %.3f)" % [clip, length, nominal])
		check_true(
			absf(length - nominal) <= tolerance,
			"clip '%s' length %.6f is within %.2f s of %.3f s" % [clip, length, tolerance, nominal]
		)


func _check_world_extent(rig: Node) -> void:
	var extent: AABB = rig.get_world_extent()
	print("MEASURED world_extent min=(%.4f, %.4f, %.4f) size=(%.4f, %.4f, %.4f)" % [
		extent.position.x, extent.position.y, extent.position.z,
		extent.size.x, extent.size.y, extent.size.z])
	# 1.45 m is the "tiny scale" failure line; 1.80 m separates a human athlete
	# from the ~158 m figure a dropped Armature scale produces. The engine measures
	# 1.761 m here (head_end to toes on the A-pose bind), so the window is stated
	# as measured, not as the 1.75 m estimate the brief guessed.
	check_true(
		extent.size.y > 1.45 and extent.size.y < 1.80,
		"world height %.4f m is an athlete, not a scaled rig" % extent.size.y
	)
	print("MEASURED feet_min_y=%.4f" % extent.position.y)
	check_true(
		absf(extent.position.y) <= 0.08,
		"feet sit within 0.08 m of the floor (min Y %.4f)" % extent.position.y
	)
	# Facing, measured from the skeleton itself: `headfront` is the forward marker
	# bone the whole humanoid family carries (it is +Z of `Head` on the Volpe rig).
	var head := _bone_world(rig, "Head")
	var headfront := _bone_world(rig, "headfront")
	var toe := _bone_world(rig, "LeftToeBase")
	var foot := _bone_world(rig, "LeftFoot")
	print("MEASURED facing headfront_dz=%.4f toe_dz=%.4f" % [headfront.z - head.z, toe.z - foot.z])
	check_true(
		headfront.z - head.z > 0.02,
		"headfront points +Z, so front is +Z (dz %.4f)" % (headfront.z - head.z)
	)
	check_true(toe.z - foot.z > 0.02, "the toes point +Z as well (dz %.4f)" % (toe.z - foot.z))


func _check_material(rig: Node) -> void:
	var state: Dictionary = rig.get_material_state()
	print("MEASURED material_state=%s" % JSON.stringify(state))
	check_true(state.get("override_present", false), "Maestro outfit goes through a surface override")
	check_eq(state.get("emission", null), false, "emission is off on the override")
	check_true(absf(float(state.get("metallic", -1.0))) < 0.001, "metallic is 0")
	var roughness := float(state.get("roughness", -1.0))
	check_true(absf(roughness - 0.85) <= 0.02, "roughness is about 0.85 (%.4f)" % roughness)
	check_true(
		String(state.get("albedo_texture_size", "none")) == "2048x2048",
		"the base colour texture is kept (%s)" % state.get("albedo_texture_size", "none")
	)


func _check_locomotion_plays(rig: Node) -> void:
	check_true(rig.play_locomotion(&"walk"), "Maestro walk clip plays")
	check_true(rig.play_locomotion(&"run"), "Maestro run clip plays")
	check_true(rig.play_locomotion(&"idle"), "Maestro idle clip plays")


func _check_locomotion_motion(rig: Node) -> void:
	# The real gate: a registered clip is not proof. Sample two instants of the
	# walk clip and require the bone poses to actually differ (via get_pose()).
	check_true(rig.play_locomotion(&"walk"), "Maestro walk clip replays for the motion check")
	rig.sample_at(0.05)
	var first: Array = _pose_snapshot(rig)
	rig.sample_at(0.55)
	var second: Array = _pose_snapshot(rig)
	var delta: Dictionary = _pose_delta(first, second)
	print("MEASURED walk_motion changed_bones=%d max_angle_deg=%.4f" % [
		int(delta["changed"]), float(delta["max_angle"])])
	check_true(int(delta["changed"]) >= 1, "the walk clip moves the skeleton (bones changed %d)" % int(delta["changed"]))
	check_true(float(delta["max_angle"]) > 0.01, "the walk movement is measurable (max angle %.4f deg)" % float(delta["max_angle"]))


func _check_strokes(rig: Node) -> void:
	var strokes: Array = rig.get_stroke_names()
	print("MEASURED strokes=%s" % str(strokes))
	for stroke in [&"drive", &"slice", &"lob", &"serve"]:
		check_true(stroke in strokes, "padel stroke '%s' is authored" % stroke)
	check_true(rig.play_stroke(&"drive"), "play_stroke('drive') succeeds")
	rig.sample_at(0.0)
	var first: Array = _pose_snapshot(rig)
	rig.sample_at(0.31)
	var second: Array = _pose_snapshot(rig)
	var delta: Dictionary = _pose_delta(first, second)
	print("MEASURED stroke_motion changed_bones=%d max_angle_deg=%.4f" % [
		int(delta["changed"]), float(delta["max_angle"])])
	check_true(int(delta["changed"]) >= 1, "the drive stroke moves the skeleton (bones changed %d)" % int(delta["changed"]))


# ---------------------------------------------------------------- helpers

func _bone_world(rig: Node, bone_name: String) -> Vector3:
	var sk: Skeleton3D = rig.get_skeleton()
	if sk == null:
		return Vector3.ZERO
	var idx := sk.find_bone(bone_name)
	if idx < 0:
		return Vector3.ZERO
	# Same chain rule as AthleteRig.get_world_extent(): bone poses are in the
	# skeleton's centimetre space, the Armature node above it carries the 0.01.
	var chain := Transform3D.IDENTITY
	var n: Node = sk
	while n != null and n != rig:
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	return chain * sk.get_bone_global_pose(idx).origin


func _pose_snapshot(rig: Node) -> Array:
	var out := []
	for bone in (rig.get_pose()["bones"] as Array):
		out.append({"rotation": bone["rotation"], "position": bone["position"]})
	return out


func _pose_delta(a: Array, b: Array) -> Dictionary:
	var changed := 0
	var max_angle := 0.0
	for i in range(mini(a.size(), b.size())):
		var qa: Quaternion = a[i]["rotation"]
		var qb: Quaternion = b[i]["rotation"]
		var angle := rad_to_deg(qa.angle_to(qb))
		var shift := ((a[i]["position"] as Vector3) - (b[i]["position"] as Vector3)).length()
		if angle > 0.0 or shift > 0.0:
			changed += 1
		max_angle = maxf(max_angle, angle)
	return {"changed": changed, "max_angle": max_angle}


func check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		printerr("FAIL %s: expected %s, got %s" % [name, str(expected), str(got)])


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
