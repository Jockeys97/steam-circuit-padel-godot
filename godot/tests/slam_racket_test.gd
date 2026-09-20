extends SceneTree

const Court := preload("res://game/court.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var racket := Court.make_racket_view(holder, "Slam", Color.WHITE)
	var model := racket.get_node("SlamRacket") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	assert(not meshes.is_empty(), "Imported racket must contain geometry")
	var mesh := meshes[0] as MeshInstance3D
	var material := mesh.get_active_material(0) as BaseMaterial3D
	assert(material != null and material.albedo_texture != null, "Keep the supplied texture")
	var grip := model.transform * Vector3(0, -0.70, 0)
	assert(absf(grip.y + 0.2405) < 0.002, "Authored grip aligns with existing wrist offset")
	assert(mesh.mesh.get_surface_count() == 1, "Share the single imported mesh across players")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(900, 900)
		var camera := Camera3D.new()
		holder.add_child(camera)
		camera.position = Vector3(0.1, 0.03, 0.9)
		camera.look_at(Vector3(0, -0.08, 0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 0.65
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.06, 0.08, 0.12)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color.WHITE
		world.environment.ambient_light_energy = 0.8
		holder.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, -25, 0)
		holder.add_child(light)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/padel-slam-racket.png")
	print("SLAM_RACKET_PASS texture, geometry, wrist alignment")
	holder.free()
	quit(0)
