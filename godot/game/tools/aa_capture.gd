extends SceneTree
## aa_capture.gd — the match with no anti-aliasing, MSAA 2x, MSAA 4x and FXAA, side by
## side from a camera, plus the mean frame time of each, interleaved in one session
## (2026-10-01). The match runs with none of them today.
##
##   godot --path godot --script res://game/tools/aa_capture.gd -- --arena=officina --camera=courtside
##
## Output in user://aa/: <arena>-<camera>.png (2x2: off | MSAA 2x / MSAA 4x | FXAA) and
## <arena>-<camera>-zoom.png (the same four, a crop around the net, 3x).

const Sim := preload("res://src/sim/sim.gd")
const DIR := "user://aa/"
const VARIANTS := ["off", "msaa2", "msaa4", "fxaa"]
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


func _use(v: String) -> void:
	root.msaa_3d = Viewport.MSAA_2X if v == "msaa2" else (Viewport.MSAA_4X if v == "msaa4" else Viewport.MSAA_DISABLED)
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if v == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED


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
	# The net and the far glass: thin lines, the worst case for aliasing.
	var crop := Rect2i(360, 220, 560, 200)
	var zoom := Image.create(crop.size.x * 3 * 2, crop.size.y * 3 * 2, false, Image.FORMAT_RGBA8)
	for k in shots.size():
		var c: Image = (shots[k] as Image).get_region(crop)
		c.resize(crop.size.x * 3, crop.size.y * 3, Image.INTERPOLATE_NEAREST)
		zoom.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i((k % 2) * crop.size.x * 3, (k / 2) * crop.size.y * 3))
	zoom.save_png(DIR + "%s-%s-zoom.png" % [_arena, _camera])
	print("AA_SHOT %s" % ProjectSettings.globalize_path(DIR + "%s-%s.png" % [_arena, _camera]))
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
		print("AA_TIME arena=%s camera=%s variant=%s mean_ms=%.2f" % [_arena, _camera, v, float(usec[v]) / 1000.0 / maxf(1.0, float(frames[v]))])
	_use("off")
	_ctl.set_camera_preset(own_camera)
	quit(0)
