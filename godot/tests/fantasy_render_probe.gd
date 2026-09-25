## fantasy_render_probe.gd — temporary feasibility probe for the fantasy-arena lane.
##
## NOT a proof suite. It answers exactly one question before the lane spends time on
## a capture harness: can a rendering-enabled Godot on this host turn the render
## viewport into PNG bytes? `--headless` installs the dummy driver and every frame
## comes back blank, so the probe runs windowed and refuses to certify itself in
## headless state. It reports the adapter, the frame's colour count and the byte
## count it wrote; nothing here is evidence about an arena.
extends Node3D

var _done := false


func _ready() -> void:
	if _done:
		return
	_done = true
	_run()


func _run() -> void:
	var out := "user://fantasy-probe.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	print("# display=%s adapter=%s api=%s size=%s out=%s" % [
		DisplayServer.get_name(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(), str(get_viewport().get_visible_rect().size), out])
	if DisplayServer.get_name() == "headless":
		print("PROBE_FAIL headless display server cannot render")
		get_tree().quit(1)
		return

	# A camera looking at three flat quads of different colours: enough that a real
	# frame is multi-coloured and a dummy frame is not.
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 6.0)
	cam.current = true
	add_child(cam)
	var colours := [Color(0.9, 0.2, 0.2), Color(0.2, 0.8, 0.3), Color(0.2, 0.3, 0.95)]
	for i in 3:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 4.0)
		mi.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colours[i]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.position = Vector3(-2.2 + float(i) * 2.2, 0.0, 0.0)
		add_child(mi)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	we.environment = env
	add_child(we)

	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex != null else null
	if img == null:
		print("PROBE_FAIL no image from the render viewport")
		get_tree().quit(1)
		return
	var distinct := {}
	for gy in 24:
		for gx in 32:
			distinct[img.get_pixel(gx * img.get_width() / 32, gy * img.get_height() / 24).to_rgba32()] = true
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err := img.save_png(out)
	var size := 0
	if err == OK and FileAccess.file_exists(out):
		size = FileAccess.get_file_as_bytes(out).size()
	print("PROBE_OK px=%dx%d distinct_colours=%d png_bytes=%d err=%d" % [
		img.get_width(), img.get_height(), distinct.size(), size, err])
	print("PROBE_SAVED %s" % ProjectSettings.globalize_path(out))
	get_tree().quit(0 if distinct.size() >= 3 and size > 0 else 1)
