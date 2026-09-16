extends Node3D

# Builds a tiny but unambiguous scene (coloured box + plane + sphere, lit, seen
# from a Camera3D), renders N real frames, captures the viewport as an Image and
# writes a PNG. Any failure is reported loudly with a non-zero exit code.

const OUT_ENV := "PROBE_PNG"
const FRAMES := 8

func _make_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func _build() -> Camera3D:
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(3.2, 2.6, 4.4), Vector3(0.0, 0.6, 0.0))
	cam.fov = 60.0
	cam.current = true

	var light := DirectionalLight3D.new()
	light.light_energy = 1.6
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	add_child(light)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.14, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.6
	we.environment = env
	add_child(we)

	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 1.4, 1.4)
	box.mesh = bm
	box.position = Vector3(-0.9, 0.7, 0.0)
	box.material_override = _make_mat(Color(0.95, 0.12, 0.10)) # red
	add_child(box)

	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sphere.mesh = sm
	sphere.position = Vector3(1.1, 0.7, 0.0)
	sphere.material_override = _make_mat(Color(0.10, 0.35, 0.95)) # blue
	add_child(sphere)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.0, 12.0)
	floor_mi.mesh = pm
	floor_mi.material_override = _make_mat(Color(0.20, 0.80, 0.28)) # green
	add_child(floor_mi)

	return cam

func _ready() -> void:
	var cam := _build()
	print("PROBE_SCENE_OK camera=", cam != null)
	print("PROBE_RENDERER=", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("PROBE_ADAPTER=", RenderingServer.get_video_adapter_name())
	print("PROBE_API=", RenderingServer.get_video_adapter_api_version())

	# Let the renderer actually draw before touching the viewport texture.
	for _i in FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("PROBE_FAIL: viewport texture is null")
		get_tree().quit(3)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("PROBE_FAIL: viewport image is null")
		get_tree().quit(4)
		return

	var path := OS.get_environment(OUT_ENV)
	if path.is_empty():
		path = "user://probe.png"
	var err := img.save_png(path)
	print("PROBE_SAVE err=", err, " path=", path)
	print("PROBE_IMAGE size=", img.get_width(), "x", img.get_height(),
		" format=", img.get_format())
	if err != OK:
		push_error("PROBE_FAIL: save_png returned %d" % err)
		get_tree().quit(5)
		return
	print("PROBE_PASS")
	get_tree().quit(0)
