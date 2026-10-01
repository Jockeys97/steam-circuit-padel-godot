extends SceneTree
const Pilot := preload("res://prototypes/creator_b/pilot_rig.gd")
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("ok " if value else "FAIL ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var rig := Pilot.new()
	world.add_child(rig)
	check(rig.get_load_error() == OK, "pilot builds with game rig")
	var sk := rig.get_skeleton()
	check(sk.get_bone_count() == 24, "native 24-bone skin preserved")
	var hair := sk.get_node_or_null("PilotHair") as BoneAttachment3D
	check(hair != null and hair.bone_name == "Head", "hair attached to Head")
	# BoneAttachment follows the final modified skeleton. The pose cache is restored
	# after modifier processing; compare inside skeleton_updated, not next frame.
	var hair_delta := [INF]
	sk.skeleton_updated.connect(func(): hair_delta[0] = hair.global_position.distance_to(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin))
	var anchor := rig.make_hand_attachment()
	check(anchor != null, "racket hand attachment available")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("182438")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.45
	env.environment.ambient_light_color = Color.WHITE
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	light.light_energy = 0.85
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.2, 4.4)
	camera.fov = 34
	camera.look_at(Vector3(0, 1.05, 0))
	var out := ProjectSettings.globalize_path("res://prototypes/creator_b/out")
	DirAccess.make_dir_recursive_absolute(out)
	for clip in ["idle", "walk", "run", "meshy_drive", "meshy_backhand", "meshy_smash", "meshy_slice", "meshy_forehand_lob", "meshy_lunge_forehand", "meshy_bandeja", "meshy_wall_exit_forehand", "meshy_forehand_volley", "meshy_backhand_volley", "meshy_backhand_lob"]:
		check(rig.play_clip(clip), "play " + clip)
		var animation: Animation = rig._anim.get_animation(clip)
		var valid := true
		for track in animation.get_track_count():
			var raw := String(animation.track_get_path(track))
			if raw.contains(":"):
				valid = valid and sk.find_bone(raw.substr(raw.find(":") + 1)) >= 0
		check(valid, "all tracks resolve " + clip)
		if clip != "idle":
			var moving := false
			for track in animation.get_track_count():
				if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					moving = moving or animation.rotation_track_interpolate(track, animation.length * 0.2).angle_to(animation.rotation_track_interpolate(track, animation.length * 0.6)) > 0.01
			check(moving, "animation actually changes pose " + clip)
		for fraction in [0.0, 0.35, 0.7, 1.0]:
			rig.sample_at(animation.length * fraction)
			sk.force_update_all_bone_transforms()
			var finite := true
			for bone in sk.get_bone_count():
				finite = finite and sk.get_bone_global_pose(bone).is_finite()
			check(finite, "finite pose " + clip + " " + str(fraction))
		rig.sample_at(animation.length * 0.45)
		rig._anim.pause()
		await process_frame
		await process_frame
		check(hair_delta[0] < 0.001, "hair follows final head pose " + clip)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join(clip + ".png"))
	if DisplayServer.get_name() != "headless":
		rig.play_clip("idle")
		rig.sample_at(0)
		rig._anim.pause()
		camera.position = Vector3(0, 1.62, 0.95)
		camera.look_at(Vector3(0, 1.62, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("head-front.png"))
		camera.position = Vector3(0.95, 1.62, 0)
		camera.look_at(Vector3(0, 1.62, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("head-side.png"))
	world.queue_free()
	await process_frame
	print("PILOT ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
