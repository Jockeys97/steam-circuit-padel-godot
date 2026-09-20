extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var rig = load("res://src/character/athlete_spawn.gd").make(&"fiamma", &"base")
	root.add_child(rig)
	var skeleton: Skeleton3D = rig._skeleton
	var idle: Animation = rig._anim.get_animation(&"idle")
	check(idle.length >= 3.0 and idle.loop_mode == Animation.LOOP_LINEAR, "Idle is a breathing loop")
	rig.play_clip(&"idle")
	rig.sample_at(0.45)
	var expected: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		expected.append(skeleton.get_bone_pose(i))
	for side in ["Left", "Right"]:
		var hand := skeleton.find_bone(rig._resolve_bone_name(side + "Hand"))
		var arm := skeleton.find_bone(rig._resolve_bone_name(side + "Arm"))
		check(skeleton.get_bone_global_pose(hand).origin.y < skeleton.get_bone_global_pose(arm).origin.y - 0.2,
			side + " hand rests below shoulder")
	var spine := skeleton.find_bone(rig._resolve_bone_name("Spine"))
	rig.sample_at(0.0)
	var start := skeleton.get_bone_pose_rotation(spine)
	rig.sample_at(0.8)
	check(start.angle_to(skeleton.get_bone_pose_rotation(spine)) > 0.005, "Spine breathes")
	for clip in [&"walk", &"run", &"drive", &"slice", &"lob", &"serve"]:
		check(rig.play_clip(clip), "Clip available: " + String(clip))
		rig.sample_at(0.2)
		rig.play_clip(&"idle")
		rig.sample_at(0.45)
		for i in skeleton.get_bone_count():
			check(skeleton.get_bone_pose(i).is_equal_approx(expected[i]),
				String(clip) + " resets bone " + skeleton.get_bone_name(i))
	rig.free()
	print("FIAMMA_IDLE_PASS" if failures == 0 else "FIAMMA_IDLE_FAIL " + str(failures))
	quit(0 if failures == 0 else 1)
