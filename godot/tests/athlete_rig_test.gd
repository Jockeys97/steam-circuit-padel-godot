## athlete_rig_test.gd — headless gate for the athlete rig slice.
##
## Contract (same shape as res://tests/smoke_test.gd and res://src/sim/fault_digest_gd.gd):
## every check prints one machine-readable line
##     ok <name>
##     FAIL <name>: expected <x>, got <y>
## and the run ends with exactly one of
##     PASS <n>/<n>
##     FAIL <n>/<n>
## exiting 0 on PASS and 1 on FAIL, so a runner needs no output parser.
##
## It goes red if: the rig scene does not load, the joint count is wrong, no clip
## actually moves the skeleton over time, or an outfit override does not change the
## surface material parameters.
##
## Run (verified invocation, from the repo root):
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 \
##     /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
##     --script res://tests/athlete_rig_test.gd
##   flock ... --script res://tests/athlete_rig_test.gd -- --inject-failure   (proves the red signal)
extends SceneTree

const RigScene := preload("res://src/character/AthleteRig.tscn")

## The 24 joints the three Meshy GLBs ship, measured by
## res://src/character/tools/rig_probe.gd. Order is the GLB's bone order.
const EXPECTED_BONES := [
	"Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
	"Spine02", "Spine01", "Spine",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"neck", "Head", "head_end", "headfront",
]
const EXPECTED_TRIANGLES := 31325

## Below this, a "moving" clip is indistinguishable from a held pose. Bone rotations
## are unit quaternions, so this is in quaternion-component units.
const MOTION_EPSILON := 0.01

var _checks: int = 0
var _failures: int = 0
var _inject_failure: bool = false


func _initialize() -> void:
	_inject_failure = "--inject-failure" in OS.get_cmdline_user_args()

	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)

	_check_load(rig)
	_check_skeleton(rig)
	_check_mesh(rig)
	_check_locomotion(rig)
	_check_stroke(rig)
	_check_outfits(rig)
	_check_facing_and_pose(rig)

	if _inject_failure:
		check_eq(1, 2, "injected failure (deliberate, proves the exit code)")

	rig.queue_free()
	_finish()


# ---------------------------------------------------------------- checks

func _check_load(rig: Node) -> void:
	check_true(rig != null, "rig scene instantiates")
	check_true(rig.has_method("get_load_error"), "rig exposes get_load_error()")
	check_eq(rig.get_load_error(), OK, "rig GLB load error is OK")
	check_true(rig.get_skeleton() != null, "rig exposes a Skeleton3D")


func _check_skeleton(rig: Node) -> void:
	var sk: Skeleton3D = rig.get_skeleton()
	if sk == null:
		check_true(false, "skeleton present (joint checks skipped)")
		return
	check_eq(sk.get_bone_count(), EXPECTED_BONES.size(), "joint count is 24")
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	check_eq(str(names), str(EXPECTED_BONES), "joint names and order match the GLB rig")


func _check_mesh(rig: Node) -> void:
	check_eq(rig.get_triangle_count(), EXPECTED_TRIANGLES, "triangle count is 31325")
	check_eq(rig.get_surface_count(), 1, "mesh has exactly one surface")


func _check_locomotion(rig: Node) -> void:
	var states: Array = rig.get_locomotion_states()
	check_true(&"idle" in states, "locomotion state 'idle' is registered")
	check_true(&"walk" in states, "locomotion state 'walk' is registered")
	check_true(&"run" in states, "locomotion state 'run' is registered")

	# The real gate: a clip that merely LOADS is not proof. Sample every joint's
	# rotation at several times across the clip and require real movement.
	for state in [&"walk", &"run"]:
		var moved: float = _max_joint_motion(rig, state)
		check_true(
			moved > MOTION_EPSILON,
			"clip '%s' moves the skeleton over time (max joint delta %.6f > %.4f)"
				% [state, moved, MOTION_EPSILON]
		)


func _check_stroke(rig: Node) -> void:
	var strokes: Array = rig.get_stroke_names()
	check_true(&"drive" in strokes, "padel stroke 'drive' is registered")
	check_true(strokes.size() >= 3, "at least three padel strokes are authored")
	for stroke in strokes:
		var moved: float = _max_joint_motion(rig, stroke)
		check_true(
			moved > MOTION_EPSILON,
			"stroke '%s' moves the skeleton over time (max joint delta %.6f > %.4f)"
				% [stroke, moved, MOTION_EPSILON]
		)


func _check_outfits(rig: Node) -> void:
	var outfits: Array = rig.get_outfit_ids()
	check_true(outfits.size() >= 3, "at least three outfits are registered (base + 2)")
	check_true(&"base" in outfits, "outfit 'base' is registered")

	check_true(rig.set_outfit(&"base"), "set_outfit('base') succeeds")
	var base_state: Dictionary = rig.get_material_state()
	check_true(
		base_state.get("override_present", false),
		"base outfit goes through a surface override (not the shared GLB material)"
	)

	# The override must actually change the material parameters, not just be applied.
	var seen := {}
	var changed := 0
	for id in outfits:
		check_true(rig.set_outfit(id), "set_outfit('%s') succeeds" % id)
		var st: Dictionary = rig.get_material_state()
		check_eq(st.get("outfit", &""), id, "get_material_state() reports outfit '%s'" % id)
		var key := "%s|%s|%s" % [
			st.get("albedo_texture_digest", ""),
			st.get("albedo_color", ""),
			st.get("metallic", ""),
		]
		if not seen.has(key):
			changed += 1
		seen[key] = id
	check_true(
		changed >= 3,
		"each outfit yields distinct material parameters (%d distinct of %d outfits)"
			% [changed, outfits.size()]
	)
	check_true(not rig.set_outfit(&"no-such-outfit"), "an unknown outfit id is rejected")


func _check_facing_and_pose(rig: Node) -> void:
	rig.set_facing_degrees(90.0)
	check_true(is_equal_approx(rig.get_facing_degrees(), 90.0), "set_facing_degrees(90) reads back 90")
	rig.set_facing_degrees(180.0)
	check_true(is_equal_approx(rig.get_facing_degrees(), 180.0), "set_facing_degrees(180) reads back 180")

	var pose: Dictionary = rig.get_pose()
	check_true(pose.has("bones"), "get_pose() returns a 'bones' entry")
	check_eq((pose.get("bones", []) as Array).size(), EXPECTED_BONES.size(), "get_pose() reports 24 joints")
	check_true(pose.has("clip"), "get_pose() reports the current clip")
	check_true(pose.has("time"), "get_pose() reports the current clip time")


# ---------------------------------------------------------------- helpers

## Plays `clip` on the rig and returns the largest per-joint rotation change seen
## between any sampled time and t=0. This is the "it actually animates" measurement.
func _max_joint_motion(rig: Node, clip: StringName) -> float:
	if not rig.play_clip(clip):
		return -1.0
	var sk: Skeleton3D = rig.get_skeleton()
	if sk == null:
		return -1.0
	var length: float = rig.get_clip_length(clip)
	if length <= 0.0:
		return -1.0

	rig.sample_at(0.0)
	var base := []
	for i in sk.get_bone_count():
		base.append(sk.get_bone_pose_rotation(i))

	var worst := 0.0
	for step in range(1, 9):
		rig.sample_at(length * float(step) / 8.0)
		for i in sk.get_bone_count():
			var q: Quaternion = sk.get_bone_pose_rotation(i)
			var b: Quaternion = base[i]
			var d := maxf(
				maxf(absf(q.x - b.x), absf(q.y - b.y)),
				maxf(absf(q.z - b.z), absf(q.w - b.w))
			)
			worst = maxf(worst, d)
	return worst


func check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(got)]
		print(line)
		printerr(line)


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		var line := "FAIL %d/%d" % [_checks - _failures, _checks]
		print(line)
		printerr(line)
		quit(1)
