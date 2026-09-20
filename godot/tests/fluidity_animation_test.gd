extends SceneTree
const Spawn = preload("res://src/character/athlete_spawn.gd")
const View = preload("res://game/athletes_view.gd")
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
var failures := 0
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for id in [&"maestro", &"fiamma", &"oracolo", &"colosso", &"fornaio", &"steamer"]:
		var rig = Spawn.make(id, &"base")
		if rig == null:
			check(false, "Missing rig " + String(id))
			continue
		root.add_child(rig)
		for clip in [&"shuffle_left", &"shuffle_right", &"backpedal", &"prepare", &"volley", &"ready", &"brake"]:
			check(rig.play_clip(clip), String(id) + " has " + String(clip))
			rig.sample_at(0.08)
			var first := []
			for i in rig._skeleton.get_bone_count(): first.append(rig._skeleton.get_bone_pose_rotation(i))
			rig.sample_at(0.40)
			var changed := false
			for i in first.size():
				if first[i].angle_to(rig._skeleton.get_bone_pose_rotation(i)) > 0.001: changed = true
			check(changed, String(id) + " animated " + String(clip))
			check(rig.position == Vector3.ZERO, "No simulation root motion")
		check(rig.play_stroke_at(&"volley", 0.5, 1.0), "Contact begins immediately")
		check(absf(float(rig.get_pose().time) - 0.18) < 0.001, "Volley contact at authored frame")
		rig.play_locomotion(&"backpedal")
		check(rig.is_stroking(), "Gait does not interrupt stroke")
		rig._anim.advance(0.20)
		check(not rig.is_stroking(), "Volley finishes without stuck stroke")
		check(rig._anim.current_animation == "backpedal", "Recovery resumes pending gait")
		rig.free()
	var view := View.new()
	root.add_child(view)
	view.spawn({"player": {"id": "fiamma"}}, {}, {})
	var s = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	s.serving = false
	s.lastHitterSide = "ai"
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player._model_root.position.y > 0.0, "Receiver split-step visible")
	s.player.motion = 1.0
	s.player.x += 2.0
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player.get_locomotion_state() == &"shuffle_left", "Lateral movement selects shuffle")
	s.player.y += 2.0
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player.get_locomotion_state() == &"backpedal", "Retreat selects backpedal")
	var before := Vector2(s.player.x, s.player.y)
	view.sync(s, 1.0 / 60.0)
	check(before == Vector2(s.player.x, s.player.y), "Presentation never moves simulated player")
	s.lastHitterSide = "player"
	s.player.motion = 0.1
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player.get_locomotion_state() == &"brake", "Stopped movement selects settling clip")
	s.player.motion = 0.0
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player.get_locomotion_state() == &"ready", "Settled player returns to breathing ready stance")
	s.serving = true
	view.sync(s, 1.0 / 60.0)
	check(view.rigs.player._model_root.position.y == 0.0, "No split-step in service")
	view.free()
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1400, 700)
		var clips := [&"ready", &"shuffle_left", &"brake", &"backpedal", &"prepare", &"volley"]
		for i in clips.size():
			var rig = Spawn.make(&"fiamma", &"base")
			root.add_child(rig)
			rig.position.x = (i - 2.5) * 1.5
			rig.play_clip(clips[i])
			rig.sample_at(0.18)
			rig._anim.pause()
			var label := Label3D.new()
			label.text = String(clips[i])
			label.font_size = 32
			label.pixel_size = 0.006
			label.position = Vector3(rig.position.x, 2.1, 0)
			root.add_child(label)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 5.0
		camera.position = Vector3(0, 2.2, 8.0)
		camera.look_at(Vector3(0, 1, 0))
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
		root.get_texture().get_image().save_png("/tmp/padel-fluidity.png")
	print("FLUIDITY_ANIMATION ", checks - failures, "/", checks)
	quit(0 if failures == 0 else 1)
