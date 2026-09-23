extends SceneTree
## Close-up A/B of the "folded in half" bug, per athlete: the SAME locomotion
## frame with the SAME wind-up, left = the old layer (absolute stroke rotations
## slerped over the locomotion pose), right = the current layer (bounded deltas
## composed on top). Also prints the rendered torso pitch of each.
##
##   $GODOT --rendering-driver opengl3 --resolution 1400x760 --path godot/ \
##     --script res://game/tools/fold_frames.gd -- --out=<dir> [--clip=shuffle_left] [--t=0.09]
const Spawn = preload("res://src/character/athlete_spawn.gd")


## The layer as it was before the fix: absolute target, slerped from the
## current pose. Rebuilt here only to render the "before" side.
class LegacyLayer extends SkeletonModifier3D:
	var pose := {}
	var weight := 0.0
	func _process_modification_with_delta(_d: float) -> void:
		var sk := get_skeleton()
		for b in pose:
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(pose[b], weight).normalized())


func _initialize() -> void:
	call_deferred("run")


func _pitch(rig, at: Dictionary) -> float:
	var t: Vector3 = (at["Head"] as Node3D).global_position - (at["Hips"] as Node3D).global_position
	return rad_to_deg(t.normalized().angle_to(rig.global_transform.basis.y.normalized()))


func _attach(rig) -> Dictionary:
	var out := {}
	for n in ["Hips", "Head"]:
		var a := BoneAttachment3D.new()
		a.bone_name = rig._resolve_bone_name(n)
		rig.get_skeleton().add_child(a)
		out[n] = a
	return out


func _label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(l)


func run() -> void:
	var out := "/tmp/fold-frames"
	var clip := &"shuffle_left"
	var t := 0.09
	var stroke := &"meshy_backhand"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--clip="): clip = StringName(a.substr(7))
		elif a.begins_with("--t="): t = float(a.substr(4))
		elif a.begins_with("--stroke="): stroke = StringName(a.substr(9))
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1400, 760)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1d2230")
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(2.2, 1.1, 2.6)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	for id in Spawn.ids():
		var old = Spawn.make(id, &"base")
		var new = Spawn.make(id, &"base")
		if old == null or new == null:
			continue
		root.add_child(old)
		root.add_child(new)
		old.position = Vector3(-0.7, 0, 0)
		new.position = Vector3(0.7, 0, 0)
		old.rotation_degrees.y = 60
		new.rotation_degrees.y = 60
		var ao := _attach(old)
		var an := _attach(new)
		await process_frame
		# Old side: the current layer off, the legacy one on with the absolute
		# targets the old code stored (clip frame-0 rotation * the bounded delta).
		new.set_anticipation(stroke, 1.0, 0.34)
		var deltas: Dictionary = new._pose_layer.prep_pose
		var anim: Animation = new._anim.get_animation(stroke)
		var sk: Skeleton3D = old.get_skeleton()
		var legacy := LegacyLayer.new()
		for b in deltas:
			var tr := anim.find_track(NodePath("%s:%s" % [old._track_prefix, sk.get_bone_name(b)]), Animation.TYPE_ROTATION_3D)
			var neutral: Quaternion = anim.rotation_track_interpolate(tr, 0.0) if tr >= 0 else Quaternion.IDENTITY
			legacy.pose[b] = (neutral * deltas[b]).normalized()
		legacy.weight = float(new.get_anticipation()["weight"])
		sk.add_child(legacy)
		old.set_anticipation(&"", 0.0)
		for r in [old, new]:
			r._anim.play(clip)
			r._anim.seek(t, true, true)
			r._anim.pause()
		for i in 4:
			await process_frame
		var p_old := _pitch(old, ao)
		var p_new := _pitch(new, an)
		_label("prima: busto %.0f°" % p_old, Vector3(-0.7, 2.05, 0))
		_label("adesso: busto %.0f°" % p_new, Vector3(0.7, 2.05, 0))
		for i in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/fold-%s-%s.png" % [out, String(id), String(clip)]
		root.get_texture().get_image().save_png(path)
		print("FOLD_AB %-9s clip=%s t=%.2f stroke=%s weight=%.2f  old_pitch=%.1f new_pitch=%.1f  %s" % [
			String(id), String(clip), t, String(stroke), legacy.weight, p_old, p_new, path])
		for n in root.get_children():
			if n is Label3D:
				n.free()
		old.free()
		new.free()
	print("FOLD_AB_DONE")
	quit(0)
