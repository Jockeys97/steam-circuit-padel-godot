extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
const View = preload("res://game/athletes_view.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
func _initialize(): call_deferred("run")
func run():
	check(View.low_contact_amount("drive", 8) == 1.0, "low ball")
	check(View.low_contact_amount("slice", 45) == 0.0, "high ball")
	for intent in ["smash", "smash-flat", "bandeja", "serve", "vibora"]:
		check(View.low_contact_amount(intent, 5) == 0.0, "overhead/serve excluded")
	var view := View.new()
	root.add_child(view)
	view.spawn({"player":{"id":"fiamma"}, "opponent":{"id":"maestro"}}, {}, {})
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.serving = false
	view.sync(state, 1.0/60.0)
	for role in ["player", "opponent"]:
		var paddle = state.paddle(role)
		var rig = view.rigs[role]
		state.ball.z = 8.0
		paddle.swing = 1.0
		paddle.actionIntent = "drive"
		view.sync(state, 1.0/60.0)
		var chosen: String = rig._anim.current_animation
		check(chosen.begins_with("low_contact_"), role+" low shot wired")
		state.ball.z = 90.0
		view.sync(state, 1.0/60.0)
		check(rig._anim.current_animation == chosen, "height latched until next shot")
		paddle.swing = 0.0
		view.sync(state, 1.0/60.0)
		paddle.swing = 1.0
		view.sync(state, 1.0/60.0)
		check(not String(rig._anim.current_animation).begins_with("low_contact_"), "high shot clears old crouch")
		paddle.swing = 0.0
		view.sync(state, 1.0/60.0)
		state.ball.z = 8.0
		paddle.swing = 1.0
		view.sync(state, 1.0/60.0)
		state.serving = true
		view.sync(state, 1.0/60.0)
		check(not String(rig._anim.current_animation).begins_with("low_contact_"), "point reset clears crouch")
		state.serving = false
	view.free()
	for id in [&"maestro", &"fiamma", &"pantera", &"steamer", &"oracolo", &"colosso"]:
		for outfit in [&"base", &"mythic"]:
			var model = Spawn.make(id, outfit)
			root.add_child(model)
			var sk: Skeleton3D = model.get_skeleton()
			for clip in [&"meshy_drive", &"meshy_backhand", &"meshy_slice", &"lob", &"volley"]:
				var length: float = model.get_clip_length(clip)
				check(model.play_stroke_at(clip, 0.34, 1.0), "normal plays")
				model.sample_at(length * 0.5)
				sk.force_update_all_bone_transforms()
				var left := sk.find_bone(model._resolve_bone_name("LeftFoot"))
				var right := sk.find_bone(model._resolve_bone_name("RightFoot"))
				var hips := sk.find_bone(model._resolve_bone_name("Hips"))
				var before := (sk.get_bone_global_pose(left).origin + sk.get_bone_global_pose(right).origin) * 0.5
				var pelvis := sk.get_bone_global_pose(hips).origin
				check(model.play_stroke_at(clip, 0.34, 1.0, 1.0), "low plays")
				check(String(model._anim.current_animation).begins_with("low_contact_"), "adapted selected")
				model.sample_at(length * 0.5)
				sk.force_update_all_bone_transforms()
				var after := (sk.get_bone_global_pose(left).origin + sk.get_bone_global_pose(right).origin) * 0.5
				check(before.distance_to(after) < 0.002, str(id)+" foot anchor")
				check(sk.get_bone_global_pose(hips).origin.is_finite() and model.position == Vector3.ZERO, "finite in place")
				check(sk.get_bone_global_pose(hips).origin.distance_to(pelvis) > 0.001, "pelvis responds")
				model.clear_low_contact()
				check(model._anim.current_animation == clip, "reset clears adaptation")
				model.play_stroke_at(clip, 0.34, 1.0, 1.0)
				model._anim.advance(length + 0.1)
				check(not model.is_stroking(), "low clip completes")
			model.free()
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1400, 800)
		for i in 4:
			var model = Spawn.make(&"fiamma" if i < 2 else &"colosso", &"base")
			root.add_child(model)
			model.position.x = (float(i) - 1.5) * 1.5
			model.play_stroke_at(&"meshy_drive", 0.34, 1.0, float(i % 2))
			model.sample_at(model.get_clip_length(&"meshy_drive") * 0.34)
			model._anim.pause()
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 7.0
		camera.position = Vector3(3, 3, 9)
		camera.look_at(Vector3(0, 0.9, 0))
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.10, 0.13, 0.18)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.8
		root.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, -25, 0)
		root.add_child(sun)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/padel-low-contact.png")
	print("LOW_CONTACT ", checks-failures, "/", checks)
	quit(1 if failures else 0)
