extends Node3D

# character_material — in-engine proof that ONE rigged GLB carries TWO visually
# distinct outfits via the proposed path: override the single baked material's
# albedo_texture per instance.
#
# Method (deliberately narrow, so the render means what the ticket says it means):
#   * the same GLB file res://assets/volpe-rigged.glb is loaded TWICE through
#     GLTFDocument (two independent scene graphs -> identical rest/base pose);
#   * copy A is placed at x = -MODEL_DX, copy B at x = +MODEL_DX, both at y = 0,
#     both rotated the same amount (rotation is NOT mirrored: B is a pure
#     translation of A, which makes the screen-space shift between the two
#     regions a single constant that the measurement script can use);
#   * for every MeshInstance3D surface, the surface material is DUPLICATED and
#     only albedo_texture (and albedo_color -> white) is changed, so no other
#     property of the authored material can explain a difference;
#   * one camera, one light, one background, no shadows (so hiding copy B cannot
#     change copy A's pixels - that makes the measurement's null control exact).
#
# Everything numeric is printed, including the unprojected screen rectangles of
# both models, which the offline measurement script re-derives from the same
# camera. A negative result is reported as a negative result: if the two
# rendered regions come out identical, the script says so.

const GLB_PATH := "res://assets/volpe-rigged.glb"
const TEX_A := "res://assets/outfit-a.png"
const TEX_B := "res://assets/outfit-b.png"

const MODEL_DX := 0.75        # metres each side of the camera axis
const MODEL_YAW := 180.0      # both copies, same value: front of the athlete to camera
const BODY_H := 1.6783        # measured bone extent, arena_spike render log
const CAM_FOV_V := 45.0
const CAM_DIST := 2.60        # half-height 1.077 m, half-width 1.915 m at 16:9
const FRAMES := 12

var _copies: Dictionary = {}          # "a"/"b" -> Node3D root
var _cam: Camera3D

func _log(s: String) -> void:
	print(s)

func _rss_mb() -> float:
	return float(OS.get_static_memory_usage()) / 1048576.0

# --- world ------------------------------------------------------------------

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _build_lights_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.24, 0.28)   # flat mid grey: silhouette + diff readable
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 0.65
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = false        # deliberate: see header
	add_child(sun)

	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(24.0, 24.0)
	floor_mi.mesh = pm
	floor_mi.material_override = _mat(Color(0.30, 0.32, 0.36), 0.9)
	add_child(floor_mi)

func _setup_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "CharacterCam"
	cam.fov = CAM_FOV_V
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(cam)
	var eye := Vector3(0.0, 0.90, CAM_DIST)
	var target := Vector3(0.0, 0.90, 0.0)
	cam.look_at_from_position(eye, target, Vector3.UP)
	cam.current = true
	_cam = cam
	_log("CAM pos=%s target=%s fov_v=%.1f deg keep_aspect=KEEP_HEIGHT" % [eye, target, cam.fov])
	_log("CAM half_height_at_model_plane=%.4f m half_width=%.4f m (16:9)" % [
		CAM_DIST * tan(deg_to_rad(CAM_FOV_V * 0.5)),
		CAM_DIST * tan(deg_to_rad(CAM_FOV_V * 0.5)) * (1280.0 / 720.0)])

# --- texture + model --------------------------------------------------------

func _load_png(path: String, tag: String) -> ImageTexture:
	var t0 := Time.get_ticks_msec()
	if not FileAccess.file_exists(path):
		push_error("CM_FAIL: missing %s" % path)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("CM_FAIL: empty %s" % path)
		return null
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		push_error("CM_FAIL: load_png_from_buffer(%s) = %d" % [path, err])
		return null
	var tex := ImageTexture.create_from_image(img)
	_log("TEX_%s path=%s bytes=%d size=%dx%d format=%d load_ms=%d" % [
		tag, path, bytes.size(), img.get_width(), img.get_height(),
		img.get_format(), Time.get_ticks_msec() - t0])
	return tex

func _load_model(tag: String, x: float) -> Node3D:
	var t0 := Time.get_ticks_msec()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(GLB_PATH, st)
	_log("GLB_%s_APPEND err=%d path=%s" % [tag, err, GLB_PATH])
	if err != OK:
		push_error("CM_FAIL: append_from_file %d" % err)
		return null
	var scene: Node = doc.generate_scene(st)
	if scene == null:
		push_error("CM_FAIL: generate_scene null (%s)" % tag)
		return null
	_log("GLB_%s_LOADED in %d ms rss=%.1f MB" % [tag, Time.get_ticks_msec() - t0, _rss_mb()])

	var root := Node3D.new()
	root.name = "Athlete_%s" % tag.to_upper()
	root.add_child(scene)
	root.position = Vector3(x, 0.0, 0.0)
	root.rotation_degrees = Vector3(0.0, MODEL_YAW, 0.0)
	add_child(root)

	# Base pose. The rig has one key at t=0.30 s with duration 0.0: hold it, so
	# both copies stand in exactly the same pose with no animation running.
	for p in scene.find_children("*", "AnimationPlayer", true, false):
		var ap := p as AnimationPlayer
		var names := ap.get_animation_list()
		_log("ANIM_%s list=%s" % [tag, names])
		if names.size() > 0:
			var a: Animation = ap.get_animation(names[0])
			ap.play(names[0])
			if a.length > 0.0:
				ap.seek(a.length, true)
			ap.pause()
			_log("ANIM_%s held '%s' at t=%.3f length=%.3f tracks=%d" % [
				tag, names[0], a.length, a.length, a.get_track_count()])
	return root

func _describe_and_override(root: Node3D, tag: String, tex: ImageTexture) -> int:
	# Inspect what the GLB actually authored, then override ONLY albedo_texture.
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	_log("MESH_%s mesh_instances=%d" % [tag, meshes.size()])
	var surfaces := 0
	for mi in meshes:
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var n_surf := m.get_surface_count()
		var n_tris := m.get_faces().size() / 3
		var n_verts := 0
		if n_surf > 0:
			n_verts = m.surface_get_array_len(0)
		_log("MESH_%s '%s' surfaces=%d faces=%d verts_surface0=%d" % [
			tag, (mi as MeshInstance3D).name, n_surf, n_tris, n_verts])
		for s in n_surf:
			var src: Material = m.surface_get_material(s)
			var cls := "null" if src == null else src.get_class()
			var shader_mode := -1
			var had_tex := false
			var src_col := Color(0, 0, 0, 0)
			if src is BaseMaterial3D:
				var bm := src as BaseMaterial3D
				shader_mode = bm.shading_mode
				had_tex = bm.albedo_texture != null
				src_col = bm.albedo_color
				if bm.albedo_texture != null:
					_log("MAT_%s surface=%d ORIG albedo_texture=%dx%d" % [
						tag, s, bm.albedo_texture.get_width(), bm.albedo_texture.get_height()])
			_log("MAT_%s surface=%d class=%s shading_mode=%d has_albedo_texture=%s albedo_color=%s" % [
				tag, s, cls, shader_mode, had_tex, src_col])

			var out: StandardMaterial3D
			if src is StandardMaterial3D:
				out = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				out = StandardMaterial3D.new()
			out.albedo_texture = tex
			out.albedo_color = Color(1, 1, 1, 1)
			out.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			(mi as MeshInstance3D).set_surface_override_material(s, out)
			surfaces += 1
			_log("MAT_%s surface=%d OVERRIDE class=StandardMaterial3D albedo_texture=%dx%d albedo_color=white shading_mode=%d" % [
				tag, s, tex.get_width(), tex.get_height(), out.shading_mode])
	return surfaces

# --- framing report ---------------------------------------------------------

func _report_framing() -> void:
	var vp := get_viewport().get_visible_rect().size
	for tag in _copies:
		var root: Node3D = _copies[tag]
		var foot: Vector3 = root.global_position
		var head: Vector3 = foot + Vector3(0.0, BODY_H, 0.0)
		var lft: Vector3 = foot + Vector3(-0.45, 0.0, 0.0)
		var rgt: Vector3 = foot + Vector3(0.45, 0.0, 0.0)
		var pf := _cam.unproject_position(foot)
		var ph := _cam.unproject_position(head)
		var pl := _cam.unproject_position(lft)
		var pr := _cam.unproject_position(rgt)
		_log("FRAMING_%s foot_px=(%.2f,%.2f) head_px=(%.2f,%.2f) x_span_px=%.2f..%.2f viewport=%.0fx%.0f" % [
			tag, pf.x, pf.y, ph.x, ph.y, pl.x, pr.x, vp.x, vp.y])
	var pa: Vector2 = _cam.unproject_position((_copies["a"] as Node3D).global_position)
	var pb: Vector2 = _cam.unproject_position((_copies["b"] as Node3D).global_position)
	_log("FRAMING_SHIFT_PX dx=%.4f dy=%.4f (B minus A; whole metres of the same model)" % [
		pb.x - pa.x, pb.y - pa.y])

# --- capture ----------------------------------------------------------------

func _capture(path: String) -> bool:
	if path.is_empty():
		_log("CAPTURE skipped (empty path)")
		return false
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("CM_FAIL: viewport texture null for %s" % path)
		return false
	var img: Image = tex.get_image()
	if img == null:
		push_error("CM_FAIL: viewport image null for %s" % path)
		return false
	var err := img.save_png(path)
	_log("SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])
	return err == OK

func _env(name: String) -> String:
	return OS.get_environment(name)

func _ready() -> void:
	_log("CHARACTER_MATERIAL_START")
	_log("RENDERER=%s ADAPTER=%s API=%s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version()])
	_log("HOST rss_at_start=%.1f MB" % _rss_mb())

	_build_lights_world()

	var tex_a := _load_png(TEX_A, "A")
	var tex_b := _load_png(TEX_B, "B")
	if tex_a == null or tex_b == null:
		push_error("CM_FAIL: outfit texture load failed")
		get_tree().quit(3)
		return

	var ra := _load_model("a", -MODEL_DX)
	var rb := _load_model("b", MODEL_DX)
	if ra == null or rb == null:
		push_error("CM_FAIL: model load failed")
		get_tree().quit(4)
		return
	_copies["a"] = ra
	_copies["b"] = rb

	var sa := _describe_and_override(ra, "a", tex_a)
	var sb := _describe_and_override(rb, "b", tex_b)
	_log("OVERRIDE_SUMMARY surfaces_a=%d surfaces_b=%d" % [sa, sb])

	_setup_camera()

	for _i in FRAMES:
		await get_tree().process_frame
	_report_framing()
	_log("RSS_before_capture=%.1f MB" % _rss_mb())

	var p_ab := _env("CM_PNG_AB")
	var p_a := _env("CM_PNG_A")
	var p_b := _env("CM_PNG_B")

	var ok := true

	var rab := await _capture(p_ab)
	ok = rab and ok
	_log("FRAME_AB both_visible=1 rss=%.1f MB" % _rss_mb())

	if not p_a.is_empty():
		(_copies["b"] as Node3D).visible = false
		for _i in 4:
			await get_tree().process_frame
		var r1 := await _capture(p_a)
		ok = r1 and ok
		_log("FRAME_A b_hidden=1 rss=%.1f MB" % _rss_mb())

	if not p_b.is_empty():
		(_copies["b"] as Node3D).visible = true
		(_copies["a"] as Node3D).visible = false
		for _i in 4:
			await get_tree().process_frame
		var r2 := await _capture(p_b)
		ok = r2 and ok
		_log("FRAME_B a_hidden=1 rss=%.1f MB" % _rss_mb())

	if not ok:
		push_error("CM_FAIL: one or more captures failed")
		get_tree().quit(5)
		return
	_log("CM_PASS rss_final=%.1f MB" % _rss_mb())
	get_tree().quit(0)
