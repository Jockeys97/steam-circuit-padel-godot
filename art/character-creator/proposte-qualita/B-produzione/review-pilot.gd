extends SceneTree
## Isolated review: imports external GLBs without replacing any game asset.
var output: String

func _initialize() -> void:
	output = get_script().resource_path.get_base_dir().path_join("meshy-pilot")
	call_deferred("review")

func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var b: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func review() -> void:
	root.size = Vector2i(1000, 1000)
	for filename in ["body-rigged.glb", "walk.glb", "hair.glb"]:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(output.path_join(filename), state)
		if err != OK:
			printerr("IMPORT FAILED ", filename, " ", err)
			quit(1)
			return
		var world := Node3D.new()
		root.add_child(world)
		var model := doc.generate_scene(state)
		world.add_child(model)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("182438")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.65
		world.add_child(env)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -35, 0)
		light.light_energy = 1.2
		world.add_child(light)
		var box := bounds(model)
		# Meshy skinning applies the rig scale separately from the raw mesh AABB.
		# Review the requested 1.8 m body in world space, not the unskinned AABB.
		if filename != "hair.glb":
			box = AABB(Vector3(-0.55, 0, -0.2), Vector3(1.1, 1.8, 0.4))
		else:
			for mesh in model.find_children("*", "MeshInstance3D", true, false):
				var material := StandardMaterial3D.new()
				material.albedo_color = Color("61452f")
				material.roughness = 0.8
				mesh.material_override = material
		var camera := Camera3D.new()
		camera.fov = 35
		world.add_child(camera)
		camera.position = box.get_center() + Vector3(0, 0, box.size.y * 2.0)
		camera.look_at(box.get_center())
		camera.current = true
		var tris := 0
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				tris += mesh.mesh.surface_get_array_index_len(surface) / 3
		print("REVIEW ", filename, " triangles=", tris, " bounds=", box)
		for skeleton in model.find_children("*", "Skeleton3D", true, false):
			print("BONES ", skeleton.get_bone_count(), " root=", skeleton.get_bone_name(0))
		for player in model.find_children("*", "AnimationPlayer", true, false):
			print("ANIMATIONS ", player.get_animation_list())
			if filename == "walk.glb":
				for clip in player.get_animation_list():
					if clip != "RESET":
						player.play(clip)
						player.seek(0.4, true)
						player.pause()
						break
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(filename.get_basename() + "-review.png"))
		world.queue_free()
		await process_frame
	print("PILOT_REVIEW_COMPLETE")
	quit()
