extends SceneTree
## Isolated candidate viewer: never changes the live roster or save data.
var meshes: Array[MeshInstance3D] = []

func _initialize() -> void:
	call_deferred("run")

func collect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		collect(child)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3:
		push_error("Expected absolute model path and output prefix")
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		quit(1)
		return
	var model := document.generate_scene(state)
	root.add_child(model)
	var animation: AnimationPlayer = null
	if args.size() == 3:
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			push_error("Candidate has no animation player")
			quit(1)
			return
		animation = players[0] as AnimationPlayer
		var clips := animation.get_animation_list()
		var sampled := false
		for clip in clips:
			if clip != "RESET":
				animation.play(clip)
				animation.seek(float(args[2]) * animation.get_animation(clip).length, true)
				animation.pause()
				print("CANDIDATE_ANIMATION ", clip, " phase=", args[2])
				sampled = true
				break
		if not sampled:
			quit(1)
			return
	collect(model)
	if meshes.is_empty():
		quit(1)
		return
	var extent := meshes[0].global_transform * meshes[0].get_aabb()
	for mesh in meshes:
		extent = extent.merge(mesh.global_transform * mesh.get_aabb())
	# Skinned exports use centimetre bones under a 0.01 armature. The static
	# mesh AABB alone is not the deformed world-space bound.
	if animation != null:
		var skeletons := model.find_children("*", "Skeleton3D", true, false)
		for skeleton_in in skeletons:
			var skeleton := skeleton_in as Skeleton3D
			skeleton.force_update_all_bone_transforms()
			for bone in skeleton.get_bone_count():
				var point := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
				extent = extent.expand(point)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.09, 0.11)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	light.light_energy = 1.2
	root.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(extent.size.y, extent.size.x) * 1.2
	root.add_child(camera)
	camera.current = true
	DisplayServer.window_set_size(Vector2i(800, 800))
	root.size = Vector2i(800, 800)
	root.content_scale_size = Vector2i(800, 800)
	for side in [1.0, -1.0]:
		camera.position = extent.get_center() + Vector3(0, 0, side * camera.size * 3)
		camera.look_at(extent.get_center())
		await process_frame
		await RenderingServer.frame_post_draw
		var path := args[1] + ("-front.png" if side > 0 else "-back.png")
		if root.get_texture().get_image().save_png(path) != OK:
			quit(1)
			return
		print("CANDIDATE_CAPTURE ", path)
	quit(0)
