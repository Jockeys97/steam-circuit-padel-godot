extends SceneTree
## bleacher_lod_measure.gd — the match as it is imported, per camera: primitives drawn,
## mean frame time and one screenshot (2026-10-01). Run before and after an import
## change (the bleachers' `generate_lods`) and compare the two runs.
##
##   godot --path godot --script res://game/tools/bleacher_lod_measure.gd -- --arena=officina --label=before

const Sim := preload("res://src/sim/sim.gd")
const DIR := "user://bleacher_lod/"
const CAMERAS := ["default", "courtside", "immersive", "broadcast", "tactical"]

var _ctl: Node = null
var _frame := 0
var _arena := "officina"
var _label := "run"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			_arena = a.substr("--arena=".length())
		elif a.begins_with("--light="):
			load("res://game/arenas/bleachers.gd").light = a.substr("--light=".length()) != "0"
		elif a.begins_with("--light-props="):
			load("res://game/arenas/arena_props.gd").light_shelters = a.substr(14) != "0"
		elif a.begins_with("--label="):
			_label = a.substr("--label=".length())
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


func _run() -> void:
	var Config = load("res://game/match_config.gd")
	var own_camera := String(Config.stored_prefs().get("cameraPreset", "default"))
	_ctl.engine_driven = false
	for i in 420:
		_ctl.tick_fixed(_ctl.FIXED_STEP, _ctl._scripted.decide(_ctl.state), Sim.empty_input())
	_ctl._sync_views()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	for i in 60:
		await process_frame
	for cam in CAMERAS:
		_ctl.set_camera_preset(cam)
		for i in 20:
			await process_frame
		var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var n := 0
		var start := Time.get_ticks_usec()
		while Time.get_ticks_usec() - start < 1500000:
			await process_frame
			n += 1
		var ms := float(Time.get_ticks_usec() - start) / 1000.0 / maxf(1.0, float(n))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "%s-%s-%s.png" % [_label, _arena, cam])
		print("LOD_MEASURE label=%s arena=%s camera=%s primitives=%d mean_ms=%.2f" % [_label, _arena, cam, int(prims), ms])
	_ctl.set_camera_preset(own_camera)
	quit(0)
