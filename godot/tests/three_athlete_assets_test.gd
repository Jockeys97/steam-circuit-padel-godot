extends SceneTree
## Real factory/animation/hand integration, with optional visual evidence.
const Spawn := preload("res://src/character/athlete_spawn.gd")
const View := preload("res://game/athletes_view.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var view := View.new()
	root.add_child(view)
	var ids := ["maestro", "fiamma", "oracolo"]
	var roles := ["player", "playerMate", "opponent"]
	var lineup := {}
	for i in ids.size():
		lineup[roles[i]] = {"id": ids[i]}
	check(view.spawn(lineup, {}, {}) == 3, "All three spawn in the match view")
	for i in ids.size():
		var rig: Node3D = view.rigs[roles[i]]
		check(rig.get_load_error() == OK, ids[i] + " loads")
		check(String(rig._glb_base_path).contains(ids[i]), ids[i] + " does not use Volpe fallback")
		check(not rig.uses_catalogue_recolour(), ids[i] + " preserves its own atlas")
		for clip in [&"idle", &"walk", &"run"]:
			check(rig.play_locomotion(clip), ids[i] + " plays " + String(clip))
			# Standard Meshy idle is a restpose hold, not a breathing cycle.
			var minimum := 0.0 if clip == &"idle" and ids[i] != "maestro" else 0.3
			check(rig.get_clip_length(clip) > minimum, ids[i] + " has " + String(clip))
			rig.sample_at(0.2)
		for stroke in [&"drive", &"slice", &"lob", &"serve"]:
			check(rig.play_stroke_at(stroke, 0.5, 1.0), ids[i] + " plays " + String(stroke))
			rig.sample_at(0.2)
		if ids[i] != "maestro":
			check(view.rackets[roles[i]].get_parent() is BoneAttachment3D, ids[i] + " racket follows wrist")
		rig._stroke = &""
		rig.play_clip(&"idle" if "--idle" in OS.get_cmdline_user_args() else &"walk")
		rig.sample_at(0.45)
		rig._anim.pause()
		rig.position = Vector3((i - 1) * 1.8, 0, 0)
		rig.set_facing_degrees(0)
		print("ASSET ", ids[i], " triangles=", rig.get_triangle_count(), " clips=", rig.get_locomotion_states())
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1200, 800)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0, 1.4, 4.0)
		camera.look_at(Vector3(0, 0.9, 0))
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.12, 0.15, 0.2)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.7
		root.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, -25, 0)
		root.add_child(sun)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/padel-three-athletes.png")
	print("THREE_ASSETS_PASS" if failures == 0 else "THREE_ASSETS_FAIL " + str(failures))
	view.free()
	quit(0 if failures == 0 else 1)
