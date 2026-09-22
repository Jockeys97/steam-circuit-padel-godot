extends SceneTree
## The low-contact adaptation's own cost, in knee flexion:
##   knee = angle(thigh, shin)  (0 = straight leg)
## For each stroke, the same clip played normally and as `low_contact_*` (the
## variant the view selects for a ball below 38 px), sampled at the contact
## frame. Read-only.
##
##   $GODOT --headless --path godot/ --script res://game/tools/low_contact_probe.gd
const Spawn = preload("res://src/character/athlete_spawn.gd")


func _initialize() -> void:
	call_deferred("run")


func knee(rig: Node3D) -> float:
	var sk: Skeleton3D = rig.get_skeleton()
	var out := 0.0
	for side in ["Left", "Right"]:
		var u: int = sk.find_bone(rig._resolve_bone_name(side + "UpLeg"))
		var l: int = sk.find_bone(rig._resolve_bone_name(side + "Leg"))
		var f: int = sk.find_bone(rig._resolve_bone_name(side + "Foot"))
		if u < 0 or l < 0 or f < 0:
			continue
		var thigh: Vector3 = sk.get_bone_global_pose(l).origin - sk.get_bone_global_pose(u).origin
		var shin: Vector3 = sk.get_bone_global_pose(f).origin - sk.get_bone_global_pose(l).origin
		out = maxf(out, rad_to_deg(thigh.angle_to(shin)))
	return out


func hand_height(rig: Node3D) -> float:
	var sk: Skeleton3D = rig.get_skeleton()
	var i: int = sk.find_bone(rig._resolve_bone_name("RightHand"))
	return (sk.global_transform * sk.get_bone_global_pose(i).origin).y


func run() -> void:
	for id in [&"fiamma", &"maestro", &"oracolo", &"colosso"]:
		var rig = Spawn.make(id, &"base")
		if rig == null:
			continue
		root.add_child(rig)
		rig.play_locomotion(&"ready")
		rig._anim.pause()
		for i in 3:
			await process_frame
		var names: Array = rig.get_stroke_names()
		for stroke in [&"meshy_drive", &"meshy_backhand", &"meshy_slice", &"drive"]:
			if not stroke in names:
				continue
			var row := []
			for level in [0.0, 1.0]:
				rig.play_stroke_at(stroke, 0.34, 1.0, level)
				await process_frame
				row.append("low=%.0f knee=%.0f hand_y=%.2f clip=%s" % [level, knee(rig), hand_height(rig), String(rig._anim.current_animation)])
				rig._anim.advance(3.0)
			print("LOWCONTACT %-9s %-15s %s" % [String(id), String(stroke), "   ".join(row)])
		rig.free()
	print("LOWCONTACT_DONE")
	quit(0)
