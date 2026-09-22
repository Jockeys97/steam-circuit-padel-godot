extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check_pose(rig, context: String) -> void:
	var sk: Skeleton3D = rig.get_skeleton()
	sk.force_update_all_bone_transforms()
	for side in ["Left", "Right"]:
		var hand := sk.find_bone(rig._resolve_bone_name(side+"Hand"))
		var arm := sk.find_bone(rig._resolve_bone_name(side+"Arm"))
		var drop := sk.to_global(sk.get_bone_global_pose(arm).origin).y - sk.to_global(sk.get_bone_global_pose(hand).origin).y
		checks += 1
		if drop < 0.30:
			failures += 1
			push_error(context+" "+side+" open arm: "+str(drop))
func run() -> void:
	for id in [&"pantera", &"steamer", &"colosso", &"oracolo"]:
		var rig = Spawn.make(id, &"base")
		root.add_child(rig)
		for name in [&"idle", &"ready", &"prepare", &"brake", &"shuffle_left", &"shuffle_right", &"backpedal"]:
			rig.play_locomotion(&"run")
			rig._anim.advance(0.3)
			rig.play_locomotion(name)
			# Advance frame-sized steps so the 0.10s animation blend completes.
			for step in 15: rig._anim.advance(0.02)
			check_pose(rig, str(id)+" run->"+str(name))
		for shot in [&"meshy_drive", &"meshy_smash", &"meshy_bandeja", &"meshy_backhand", &"meshy_slice"]:
			rig.play_locomotion(&"ready")
			rig.play_stroke_at(shot, 0.34)
			# Inspect the baked recovery BEFORE the completion callback too.
			rig.sample_at(rig.get_clip_length(shot)-0.001)
			check_pose(rig,str(id)+" baked recovery "+str(shot))
			for step in 20: rig._anim.advance(0.02)
			checks += 1
			if rig.is_stroking() or rig._anim.current_animation != "ready":
				failures += 1
			check_pose(rig,str(id)+" finished "+str(shot))
		rig.free()
	print("ROSTER_READY_POSE ",checks-failures,"/",checks)
	quit(1 if failures else 0)
