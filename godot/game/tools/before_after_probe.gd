extends SceneTree
## before_after_probe.gd — this morning's render setup against today's, alternated in
## ONE session so the machine's drift lands on both (2026-10-01).
##
##   "before": full bleachers (459,928 tris) and shelters (259,882), no MSAA, world-arena
##             sun at 2 splits over 80 m.
##   "after":  light bleachers (28,744) and shelters (32,484), MSAA 2x, 2 splits over 50 m.
##
##   godot --path godot --script res://game/tools/before_after_probe.gd -- --arena=torii --camera=courtside

const Sim := preload("res://src/sim/sim.gd")
const BLEACHER_GLB := "res://assets/bleachers/Meshy_AI_Blue_Canopy_Bleachers_0917000231_texture.glb"
const SHELTER_GLB := "res://assets/arena/sideline-shelter.glb"
const WINDOW_S := 2.0
const ROUNDS := 6

var _ctl: Node = null
var _frame := 0
var _arena := "torii"
var _camera := "courtside"
## --only=meshes|msaa|shadows switches just that part (the rest stays as today).
var _only := ""
## --msaa=2 tries 2x as the "after" level; --after-splits=2 tries 2 splits over 50 m.
var _msaa_after := Viewport.MSAA_2X
var _after_splits := 2
var _swaps := []          # [MeshInstance3D, light mesh, full mesh]
var _sun: DirectionalLight3D = null
var _sun_after := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			_arena = a.substr(8)
		elif a.begins_with("--camera="):
			_camera = a.substr(9)
		elif a.begins_with("--only="):
			_only = a.substr(7)
		elif a.begins_with("--msaa="):
			_msaa_after = Viewport.MSAA_2X if a.substr(7) == "2" else Viewport.MSAA_4X
		elif a.begins_with("--after-splits="):
			_after_splits = int(a.substr(15))
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


static func _first_mesh(path: String) -> Mesh:
	var scene := (load(path) as PackedScene).instantiate()
	var m: Mesh = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	scene.free()
	return m


func _use(after_in: bool) -> void:
	var after := after_in
	for s in _swaps:
		(s[0] as MeshInstance3D).mesh = s[1] if (after or (_only != "" and _only != "meshes")) else s[2]
	root.msaa_3d = _msaa_after if (after or (_only != "" and _only != "msaa")) else Viewport.MSAA_DISABLED
	if _only != "" and _only != "shadows":
		after = true
	if _sun != null and not _sun_after.is_empty() and is_equal_approx(float(_sun_after["dist"]), 50.0):
		_sun.directional_shadow_max_distance = 50.0 if after else 80.0
		_sun.directional_shadow_mode = (DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if _after_splits == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS) if after else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func _window() -> Array:
	for i in 10:
		await process_frame
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var n := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(WINDOW_S * 1000000.0):
		await process_frame
		n += 1
	return [prims, float(Time.get_ticks_usec() - start) / 1000.0 / maxf(1.0, float(n)), n]


func _run() -> void:
	var Config = load("res://game/match_config.gd")
	var own_camera := String(Config.stored_prefs().get("cameraPreset", "default"))
	_ctl.engine_driven = false
	for i in 420:
		_ctl.tick_fixed(_ctl.FIXED_STEP, _ctl._scripted.decide(_ctl.state), Sim.empty_input())
	_ctl._sync_views()
	_ctl.set_camera_preset(_camera)
	var full_bleacher := _first_mesh(BLEACHER_GLB)
	var full_shelter := _first_mesh(SHELTER_GLB)
	for path in ["Scenery/Bleachers", "Scenery/ArenaProps"]:
		var g: Node = _ctl._arena_root.get_node_or_null(path)
		if g == null:
			continue
		for mi in g.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			if m == null:
				continue
			var tris := m.get_faces().size() / 3
			if tris == 28744:
				_swaps.append([mi, m, full_bleacher])
			elif tris == 32484:
				_swaps.append([mi, m, full_shelter])
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		if (n as DirectionalLight3D).shadow_enabled:
			_sun = n
			_sun_after = {"dist": _sun.directional_shadow_max_distance, "mode": _sun.directional_shadow_mode}
			break
	print("BEFORE_AFTER arena=%s camera=%s swaps=%d sun=%s" % [_arena, _camera, _swaps.size(), str(_sun_after)])
	for after in [false, true]:
		_use(after)
		for i in 40:
			await process_frame
	var ms := {false: [], true: []}
	var prims := {false: 0, true: 0}
	for r in ROUNDS:
		for after in ([false, true] if r % 2 == 0 else [true, false]):
			_use(after)
			var w: Array = await _window()
			prims[after] = w[0]
			(ms[after] as Array).append(w[1])
	for after in [false, true]:
		var a: Array = (ms[after] as Array).duplicate()
		a.sort()
		var mean := 0.0
		for v in a:
			mean += float(v)
		mean /= float(a.size())
		print("BEFORE_AFTER arena=%s camera=%s %s primitives=%d median_ms=%.2f mean_ms=%.2f fps=%.0f windows=%s" % [
			_arena, _camera, "ADESSO   " if after else "STAMATTINA", int(prims[after]), float(a[a.size() / 2]), mean,
			1000.0 / maxf(0.01, float(a[a.size() / 2])), str(a)])
	_use(true)
	_ctl.set_camera_preset(own_camera)
	quit(0)
