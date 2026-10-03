extends SceneTree
## shadow_capture.gd — the sun's shadow settings side by side from a camera, plus the mean
## frame time of each, interleaved in one session (2026-10-01). Today the world arenas cast
## over 80 m with two splits: the shadow map is spread over four court lengths.
##
##   godot --path godot --script res://game/tools/shadow_capture.gd -- --arena=officina --camera=courtside
##
## Output in user://shadows/: <arena>-<camera>.png (2x2: today | 40 m / 40 m + 4 splits |
## 40 m + 8192 atlas) and <arena>-<camera>-zoom.png (a crop around the near athletes, 3x).

const Sim := preload("res://src/sim/sim.gd")
const DIR := "user://shadows/"
const VARIANTS := ["today", "d40", "d40_4split", "d40_8k"]
const TIME_SECONDS := 2.0
const TIME_ROUNDS := 4

var _ctl: Node = null
var _frame := 0
var _arena := "officina"
var _camera := "courtside"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			_arena = a.substr(8)
		elif a.begins_with("--camera="):
			_camera = a.substr(9)
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_ctl = (load("res://game/Match.tscn") as PackedScene).instantiate()
	root.add_child(_ctl)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_run()
	return false


var _sun: DirectionalLight3D = null
var _today := {}


func _use(v: String) -> void:
	if _sun == null:
		for n in root.find_children("*", "DirectionalLight3D", true, false):
			if (n as DirectionalLight3D).shadow_enabled:
				_sun = n
				break
		if _sun == null:
			return
		_today = {"dist": _sun.directional_shadow_max_distance, "mode": _sun.directional_shadow_mode}
		print("SHADOW_TODAY sun=%s dist=%.1f mode=%d" % [_sun.name, float(_today["dist"]), int(_today["mode"])])
	_sun.directional_shadow_max_distance = float(_today["dist"]) if v == "today" else (80.0 if v == "d40_8k" else 40.0)
	_sun.directional_shadow_mode = int(_today["mode"]) if v in ["today", "d40", "d40_8k"] else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(8192 if v == "d40_8k" else 4096, true)


func _run() -> void:
	var Config = load("res://game/match_config.gd")
	var own_camera := String(Config.stored_prefs().get("cameraPreset", "default"))
	_ctl.engine_driven = false
	for i in 420:
		_ctl.tick_fixed(_ctl.FIXED_STEP, _ctl._scripted.decide(_ctl.state), Sim.empty_input())
	_ctl._sync_views()
	_ctl.set_camera_preset(_camera)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for v in VARIANTS:
		_use(v)
		for i in 30:
			await process_frame
	var grid := Image.create(2560, 1440, false, Image.FORMAT_RGBA8)
	var shots := []
	for k in VARIANTS.size():
		_use(VARIANTS[k])
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		shots.append(img)
		grid.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((k % 2) * 1280, (k / 2) * 720))
	grid.save_png(DIR + "%s-%s.png" % [_arena, _camera])
	# The near athletes and their shadows on the court.
	var crop := Rect2i(380, 360, 520, 240)
	var zoom := Image.create(crop.size.x * 3 * 2, crop.size.y * 3 * 2, false, Image.FORMAT_RGBA8)
	for k in shots.size():
		var c: Image = (shots[k] as Image).get_region(crop)
		c.resize(crop.size.x * 3, crop.size.y * 3, Image.INTERPOLATE_NEAREST)
		zoom.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i((k % 2) * crop.size.x * 3, (k / 2) * crop.size.y * 3))
	zoom.save_png(DIR + "%s-%s-zoom.png" % [_arena, _camera])
	print("SHADOW_SHOT %s" % ProjectSettings.globalize_path(DIR + "%s-%s.png" % [_arena, _camera]))
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
		print("SHADOW_TIME arena=%s camera=%s variant=%s mean_ms=%.2f" % [_arena, _camera, v, float(usec[v]) / 1000.0 / maxf(1.0, float(frames[v]))])
	_use("today")
	_ctl.set_camera_preset(own_camera)
	quit(0)
