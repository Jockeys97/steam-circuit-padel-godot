extends SceneTree
## arena_cost_probe.gd — which part of an arena costs the frame (2026-10-01). Boots
## the match in one arena, then hides one group of the arena at a time (each child of
## the arena root and of its Scenery) and measures the drawn primitives, draw calls
## and the mean frame time, with a baseline window right before every group so the
## machine's own drift lands on both sides.
##
##   godot --path godot --script res://game/tools/arena_cost_probe.gd -- --arena=torii --camera=default

const Sim := preload("res://src/sim/sim.gd")
const WINDOW_S := 1.2

var _ctl: Node = null
var _frame := 0
var _arena := "torii"
var _camera := "default"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			_arena = a.substr("--arena=".length())
		elif a.begins_with("--camera="):
			_camera = a.substr("--camera=".length())
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


func _window() -> Array:
	for i in 8:
		await process_frame
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var n := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(WINDOW_S * 1000000.0):
		await process_frame
		n += 1
	return [prims, draws, float(Time.get_ticks_usec() - start) / 1000.0 / maxf(1.0, float(n))]


func _run() -> void:
	var Config = load("res://game/match_config.gd")
	var own_camera := String(Config.stored_prefs().get("cameraPreset", "default"))
	_ctl.engine_driven = false
	for i in 420:
		_ctl.tick_fixed(_ctl.FIXED_STEP, _ctl._scripted.decide(_ctl.state), Sim.empty_input())
	_ctl._sync_views()
	_ctl.set_camera_preset(_camera)
	for i in 90:
		await process_frame
	var arena: Node = _ctl._arena_root
	var groups: Array = []
	for c in arena.get_children():
		if c is Node3D and c.name != "Scenery":
			groups.append(c)
	var scenery := arena.get_node_or_null("Scenery")
	if scenery != null:
		for c in scenery.get_children():
			if c is Node3D:
				groups.append(c)
	var rows := []
	for g in groups:
		if not (g as Node3D).visible:
			continue
		var base: Array = await _window()
		(g as Node3D).visible = false
		var off: Array = await _window()
		(g as Node3D).visible = true
		rows.append([str(arena.get_path_to(g)), base[0] - off[0], base[1] - off[1], base[2] - off[2], base[2]])
		print("ARENA_COST arena=%s camera=%s group=%s primitives=%d draws=%d ms_saved=%.2f (base %.2f)" % [
			_arena, _camera, str(arena.get_path_to(g)), base[0] - off[0], base[1] - off[1], base[2] - off[2], base[2]])
	# The environment's effects, one at a time (glow, SSAO, fog, shadows).
	var env: Environment = _ctl._cam.get_world_3d().environment if _ctl._cam.get_world_3d() != null else null
	if env == null:
		for n in root.find_children("*", "WorldEnvironment", true, false):
			env = (n as WorldEnvironment).environment
	if env != null:
		for prop in ["glow_enabled", "ssao_enabled", "fog_enabled", "volumetric_fog_enabled"]:
			if not bool(env.get(prop)):
				continue
			var base: Array = await _window()
			env.set(prop, false)
			var off: Array = await _window()
			env.set(prop, true)
			print("ARENA_COST arena=%s camera=%s effect=%s draws=%d ms_saved=%.2f (base %.2f)" % [_arena, _camera, prop, base[1] - off[1], base[2] - off[2], base[2]])
	var lights := root.find_children("*", "DirectionalLight3D", true, false)
	for l in lights:
		if not (l as Light3D).shadow_enabled:
			continue
		var base: Array = await _window()
		(l as Light3D).shadow_enabled = false
		var off: Array = await _window()
		(l as Light3D).shadow_enabled = true
		print("ARENA_COST arena=%s camera=%s effect=shadow:%s draws=%d primitives=%d ms_saved=%.2f (base %.2f)" % [_arena, _camera, l.name, base[1] - off[1], base[0] - off[0], base[2] - off[2], base[2]])
	_ctl.set_camera_preset(own_camera)
	quit(0)
