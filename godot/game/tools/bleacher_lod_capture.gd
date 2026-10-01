extends SceneTree
## bleacher_lod_capture.gd — the bleachers at full detail and at three lighter LOD
## levels (from `bleacher_lod_probe.gd`), side by side from every match camera, plus
## the frame time of each, interleaved in one session (2026-10-01).
##
##   godot --path godot --script res://game/tools/bleacher_lod_capture.gd -- --arena=officina
##
## Output in user://bleacher_lod/: <arena>-<camera>.png, a 2x2 grid per camera:
## top-left original (459,928 triangles), top-right 114,982, bottom-left 57,490,
## bottom-right 14,370. Then one BLEACHER_TIME line per variant.

const Sim := preload("res://src/sim/sim.gd")
const DIR := "user://bleacher_lod/"
var VARIANTS := ["original", "bleacher_120k.res", "bleacher_50k.res", "bleacher_20k.res"]
## `--group=Scenery/ArenaProps --tris=259882 --variants=shelter_65k.res,...` swaps the
## meshes of another group instead, only those with that triangle count.
var GROUP := "Scenery/Bleachers"
var MATCH_TRIS := 0
var TAG := "bleacher"
const CAMERAS := ["default", "courtside", "immersive", "broadcast", "tactical"]
const TICKS := 420
const TIME_SECONDS := 2.0
const TIME_ROUNDS := 4

var _ctl: Node = null
var _frame := 0
var _arena := "officina"
var _meshes: Array = []        # [MeshInstance3D]
var _original: Array = []      # their meshes as loaded
var _lods := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			_arena = a.substr("--arena=".length())
		elif a.begins_with("--group="):
			GROUP = a.substr(8)
		elif a.begins_with("--tris="):
			MATCH_TRIS = int(a.substr(7))
		elif a.begins_with("--tag="):
			TAG = a.substr(6)
		elif a.begins_with("--variants="):
			VARIANTS = ["original"]
			for v in a.substr(11).split(","):
				VARIANTS.append(v)
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var packed: PackedScene = load("res://game/Match.tscn")
	_ctl = packed.instantiate()
	root.add_child(_ctl)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run()
	return false


func _use(variant: String) -> void:
	for i in _meshes.size():
		(_meshes[i] as MeshInstance3D).mesh = _original[i] if variant == "original" else _lods[variant]


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	var Config = load("res://game/match_config.gd")
	var own_camera := String(Config.stored_prefs().get("cameraPreset", "default"))
	_ctl.engine_driven = false
	for i in TICKS:
		_ctl.tick_fixed(_ctl.FIXED_STEP, _ctl._scripted.decide(_ctl.state), Sim.empty_input())
	_ctl._sync_views()
	var group: Node = _ctl._arena_root.get_node_or_null(GROUP) if _ctl._arena_root != null else null
	if group == null:
		print("BLEACHER_ERROR no Scenery/Bleachers in arena %s" % _arena)
		quit(1)
		return
	for m in group.find_children("*", "MeshInstance3D", true, false):
		if MATCH_TRIS > 0 and (m as MeshInstance3D).mesh.get_faces().size() / 3 != MATCH_TRIS:
			continue
		_meshes.append(m)
		_original.append((m as MeshInstance3D).mesh)
	for v in VARIANTS:
		if v != "original":
			_lods[v] = load(DIR + v)
	print("BLEACHER_SCENE arena=%s copies=%d" % [_arena, _meshes.size()])
	# Warm every variant once (shader compile, upload) before any picture or timing.
	for v in VARIANTS:
		_use(v)
		for i in 20:
			await process_frame
	for cam in CAMERAS:
		_ctl.set_camera_preset(cam)
		var grid := Image.create(2560, 1440, false, Image.FORMAT_RGBA8)
		for k in VARIANTS.size():
			_use(VARIANTS[k])
			var img: Image = await _shot()
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != Vector2i(1280, 720):
				img.resize(1280, 720)
			grid.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((k % 2) * 1280, (k / 2) * 720))
		var path := DIR + "%s-%s-%s.png" % [TAG, _arena, cam]
		grid.save_png(path)
		print("BLEACHER_SHOT %s" % ProjectSettings.globalize_path(path))
	# Frame time, interleaved: each round visits every variant for TIME_SECONDS.
	_ctl.set_camera_preset("default")
	var frames := {}
	var usec := {}
	for v in VARIANTS:
		frames[v] = 0
		usec[v] = 0
	for r in TIME_ROUNDS:
		for v in VARIANTS:
			_use(v)
			for i in 10:
				await process_frame
			var start := Time.get_ticks_usec()
			var last := start
			while Time.get_ticks_usec() - start < int(TIME_SECONDS * 1000000.0):
				await process_frame
				var now := Time.get_ticks_usec()
				frames[v] += 1
				usec[v] += now - last
				last = now
	for v in VARIANTS:
		var prims := 0
		print("BLEACHER_TIME arena=%s variant=%s frames=%d mean_ms=%.2f fps=%.1f" % [
			_arena, v, frames[v], float(usec[v]) / 1000.0 / maxf(1.0, float(frames[v])),
			float(frames[v]) * 1000000.0 / maxf(1.0, float(usec[v]))])
	_use("original")
	_ctl.set_camera_preset(own_camera)   # the owner's own choice, saved back
	quit(0)
