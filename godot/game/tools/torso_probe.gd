extends SceneTree
## What the anticipation layer does to the TORSO, per athlete and stroke:
##   torso pitch = angle(Hips->Neck, world up)   (0 = upright)
## and the racket hand's travel. Measured on the RENDERED pose (post-modifier)
## through bone attachments; the baseline is the same rig at weight 0.
##
##   $GODOT --headless --path godot/ --script res://game/tools/torso_probe.gd
const Spawn = preload("res://src/character/athlete_spawn.gd")


func _initialize() -> void:
	call_deferred("run")


func pitch(rig: Node3D) -> float:
	var sk: Skeleton3D = rig.get_skeleton()
	var h: int = sk.find_bone(rig._resolve_bone_name("Hips"))
	var n: int = sk.find_bone(rig._resolve_bone_name("Neck"))
	if h < 0 or n < 0:
		return 0.0
	var up := sk.global_transform.basis.y.normalized()
	var torso: Vector3 = sk.global_transform.basis * (sk.get_bone_global_pose(n).origin - sk.get_bone_global_pose(h).origin)
	return rad_to_deg(torso.normalized().angle_to(up))


func run() -> void:
	for id in [&"fiamma", &"maestro", &"oracolo", &"colosso"]:
		var rig = Spawn.make(id, &"base")
		if rig == null:
			continue
		root.add_child(rig)
		var att := BoneAttachment3D.new()
		att.bone_name = rig._resolve_bone_name("RightHand")
		rig.get_skeleton().add_child(att)
		rig.play_locomotion(&"ready")
		rig._anim.pause()
		for i in 3:
			await process_frame
		var names: Array = rig.get_stroke_names()
		for stroke in [&"meshy_drive", &"meshy_backhand", &"meshy_smash", &"meshy_slice", &"drive", &"serve"]:
			if not stroke in names:
				continue
			rig.set_anticipation(stroke, 0.0)
			await process_frame
			var p0 := pitch(rig)
			var h0: Vector3 = att.global_position
			rig.set_anticipation(stroke, 0.85, 0.34)
			await process_frame
			var p1 := pitch(rig)
			var h1: Vector3 = att.global_position
			var lay = rig._pose_layer
			var worst := 0.0
			var worst_bone := ""
			var sk: Skeleton3D = rig.get_skeleton()
			for bone in lay.prep_pose:
				var a := rad_to_deg(Quaternion.IDENTITY.angle_to(lay.prep_pose[bone]))   # prep_pose holds deltas
				if a > worst:
					worst = a
					worst_bone = sk.get_bone_name(bone)
			print("TORSO %-9s %-15s pitch %.1f -> %.1f deg (%+.1f)  hand %+.3fm  bones=%d  worst_joint=%s %.1f deg" % [
				String(id), String(stroke), p0, p1, p1 - p0, h1.distance_to(h0), lay.prep_pose.size(), worst_bone, worst])
		rig.free()
	print("TORSO_DONE")
	quit(0)
