extends SceneTree
## Static census of how far each clip folds the athlete, for EVERY athlete and
## EVERY clip the rig carries (strokes, locomotion, baked low-contact variants):
##   pitch = angle(Hips->Head, up), 0 = upright; knee = worst leg flexion;
##   head_h = head height / ready head height (1.0 = standing tall).
## Played on the real AnimationPlayer (then read post-pose), 25 samples/clip.
##
##   $GODOT --headless --path godot/ --script res://game/tools/fold_census.gd
const Spawn = preload("res://src/character/athlete_spawn.gd")


func _initialize() -> void:
	call_deferred("run")


func _w(sk: Skeleton3D, rig, n: String) -> Vector3:
	var i: int = sk.find_bone(rig._resolve_bone_name(n))
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO


func _sample(rig, sk: Skeleton3D) -> Dictionary:
	var torso := _w(sk, rig, "Head") - _w(sk, rig, "Hips")
	var knee := 0.0
	for side in ["Left", "Right"]:
		var a := (_w(sk, rig, side + "UpLeg") - _w(sk, rig, side + "Leg")).normalized()
		var b := (_w(sk, rig, side + "Foot") - _w(sk, rig, side + "Leg")).normalized()
		knee = maxf(knee, 180.0 - rad_to_deg(a.angle_to(b)))
	return {"pitch": rad_to_deg(torso.normalized().angle_to(Vector3.UP)), "knee": knee, "head": _w(sk, rig, "Head").y}


func run() -> void:
	var ids: Array = [&"fiamma", &"maestro", &"oracolo", &"colosso"]
	for id in ids:
		var rig = Spawn.make(StringName(id), &"base")
		if rig == null:
			continue
		root.add_child(rig)
		await process_frame
		var sk: Skeleton3D = rig.get_skeleton()
		var anim: AnimationPlayer = rig._anim
		anim.play(&"ready")
		anim.seek(0.5, true, true)
		sk.force_update_all_bone_transforms()
		var ready_head: float = maxf(0.01, _sample(rig, sk)["head"])
		var rows: Array = []
		for clip in anim.get_animation_list():
			var a: Animation = anim.get_animation(clip)
			var worst := {"pitch": -1.0}
			for step in 25:
				var t := a.length * float(step) / 24.0
				anim.play(clip)
				anim.seek(t, true, true)
				sk.force_update_all_bone_transforms()
				var s := _sample(rig, sk)
				if float(s["pitch"]) > float(worst["pitch"]):
					worst = s
					worst["t"] = t
					worst["len"] = a.length
			rows.append([String(clip), worst])
		rows.sort_custom(func(x, y): return float(x[1]["pitch"]) > float(y[1]["pitch"]))
		for r in rows:
			var w: Dictionary = r[1]
			print("CENSUS %-9s %-34s pitch=%5.1f knee=%5.1f head_h=%.2f t=%.2f/%.2f" % [
				String(id), r[0], w["pitch"], w["knee"], float(w["head"]) / ready_head, w["t"], w["len"]])
		rig.free()
	print("CENSUS_DONE")
	quit(0)
