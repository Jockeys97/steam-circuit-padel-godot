## bleachers_probe.gd — one throwaway probe for the tribunes' cost: boot the match
## scene windowed, drive the simulation to a chosen tick with the capture's own
## scripted player, write ONE frame, then read the engine's own frame time for a
## few hundred frames.
##
##   $GODOT --rendering-driver opengl3 --resolution 1280x720 --path godot/ \
##     --script res://game/tools/bleachers_probe.gd -- \
##     --bleachers=1 --ticks=420 --shot=res://game/out/bleachers-probe.png --frames=600
##
## `--bleachers=0` sets `bleachers.gd::enabled = false` BEFORE the match scene is
## instantiated, so the A/B is the same probe, the same seed, the same tick and the
## same camera — with and without the stands, and nothing else.
##
## TWO MEASUREMENT MODES, and the difference matters on this Mac (another engine
## window is open here, so a run-to-run comparison swings by 2-5x):
##
##  1. separate runs (`--interleave=0`): the whole run has the stands or does not.
##     Comparable only between runs taken back to back on a quiet machine.
##  2. INTERLEAVED (default): ONE scene, one engine session; the stands' group is
##     switched `visible` off and on between windows of `--window=N` frames and the
##     arms alternate ABAB, so any contention hits both arms equally. The arm
##     medians and their difference are the robust numbers.
##
## It is deleted before the lane returns: it is an instrument, not a fixture.
extends SceneTree

const Bleachers := preload("res://game/arenas/bleachers.gd")
const Sim := preload("res://src/sim/sim.gd")

var _use_bleachers := true
var _ticks := 420
var _shot := ""
var _frames := 600
var _warmup := 120
var _vsync := false
var _label := "probe"
var _interleave := 8
var _window := 200
var _seconds := 2.0

var _ctl: Node = null
var _frame := 0
var _measuring := false
var _samples := PackedFloat32Array()
var _wall := PackedFloat32Array()
var _warm := PackedFloat32Array()
var _last_usec := 0
var _shot_done := false
## Interleaved arms: [wall deltas, engine times] per arm, plus the window list.
var _arm_wall := [[], []]
var _arm_engine := [[], []]
var _window_log := []
var _windows_left := 0
var _window_i := 0
var _in_window := 0
var _group: Node3D = null
## Per-arm throughput: frames delivered and microseconds spent, over windows of a
## FIXED wall-clock length. The frame-to-frame interval is capped by the present
## path on this Mac (~6.9 ms) and so are the percentiles: the throughput is what
## separates two arms that both sit on the cap.
var _arm_frames := [0, 0]
var _arm_usec := [0, 0]
var _window_frames := 0
var _window_usec := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bleachers="):
			_use_bleachers = a.substr("--bleachers=".length()) != "0"
		elif a.begins_with("--ticks="):
			_ticks = int(a.substr("--ticks=".length()))
		elif a.begins_with("--shot="):
			_shot = a.substr("--shot=".length())
		elif a.begins_with("--frames="):
			_frames = int(a.substr("--frames=".length()))
		elif a.begins_with("--warmup="):
			_warmup = int(a.substr("--warmup=".length()))
		elif a.begins_with("--vsync="):
			_vsync = a.substr("--vsync=".length()) != "0"
		elif a.begins_with("--label="):
			_label = a.substr("--label=".length())
		elif a.begins_with("--copies="):
			Bleachers.copies_per_side = int(a.substr("--copies=".length()))
		elif a.begins_with("--scale="):
			Bleachers.scale = float(a.substr("--scale=".length()))
		elif a.begins_with("--shadow="):
			Bleachers.cast_shadow = a.substr("--shadow=".length()) != "0"
		elif a.begins_with("--material="):
			Bleachers.material_mode = a.substr("--material=".length())
		elif a.begins_with("--interleave="):
			_interleave = int(a.substr("--interleave=".length()))
		elif a.begins_with("--sides="):
			Bleachers.sides = int(a.substr("--sides=".length()))
		elif a.begins_with("--window="):
			_window = int(a.substr("--window=".length()))
		elif a.begins_with("--seconds="):
			_seconds = float(a.substr("--seconds=".length()))
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _vsync else DisplayServer.VSYNC_DISABLED)
	Bleachers.enabled = _use_bleachers
	print("PROBE_START label=%s bleachers=%s ticks=%d frames=%d warmup=%d vsync=%s viewport=%s" % [
		_label, str(_use_bleachers), _ticks, _frames, _warmup, str(_vsync), str(root.size)])
	var packed: PackedScene = load("res://game/Match.tscn")
	_ctl = packed.instantiate()
	root.add_child(_ctl)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 3:
		_boot()
		return false
	if _measuring:
		var engine_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		var now := Time.get_ticks_usec()
		var wall_ms := 0.0
		if _last_usec > 0:
			wall_ms = float(now - _last_usec) / 1000.0
		var arm := _window_i % 2
		if _last_usec > 0:
			_arm_wall[arm].append(wall_ms)
			_arm_engine[arm].append(engine_ms)
			_arm_frames[arm] += 1
			_arm_usec[arm] += now - _last_usec
			_window_frames += 1
			_window_usec += now - _last_usec
		_last_usec = now
		if _interleave <= 0:
			_samples.append(engine_ms)
			_wall.append(wall_ms)
		_in_window += 1
		var due := _in_window >= _window if _seconds <= 0.0 else _window_usec >= int(_seconds * 1000000.0)
		if due and _in_window > 1:
			_window_log.append("window%d=%s frames=%d seconds=%.3f fps=%.1f wall_p50=%.3f" % [
				_window_i, "ON" if arm == 0 else "off", _window_frames,
				float(_window_usec) / 1000000.0,
				float(_window_frames) / maxf(0.001, float(_window_usec) / 1000000.0),
				_median(_arm_wall[arm])])
			_in_window = 0
			_window_frames = 0
			_window_usec = 0
			_window_i += 1
			_windows_left -= 1
			if _windows_left <= 0:
				_report()
				quit(0)
				return true
			if _group != null:
				_group.visible = (_window_i % 2) == 0
	return false


## The scene is up after a couple of frames (the match's `_ready` builds the arena,
## the athletes and the HUD). Ticks the simulation to the requested instant with the
## capture's own scripted player, writes the frame, and reads the scene's own cost.
func _boot() -> void:
	_ctl.engine_driven = false
	for i in _ticks:
		var input: Dictionary = _ctl._scripted.decide(_ctl.state)
		_ctl.tick_fixed(_ctl.FIXED_STEP, input, Sim.empty_input())
	_ctl._hud.refresh(_ctl.state, _ctl.meta)
	_ctl._sync_views()
	var cam: Camera3D = _ctl._cam
	print("PROBE_TICK ticks=%d rallyHits=%d ball=(%s) serving=%s" % [
		_ctl.ticks, int(_ctl.state.rallyHits), str(_ctl.state.ball.y), str(_ctl.state.serving)])
	print("PROBE_CAMERA preset=%s pos=%s rot_deg=%s fov=%.3f frame=%s" % [
		"default", str(cam.position), str(cam.rotation_degrees), cam.fov, str(root.size)])
	_scene_report(cam)
	# The frame has to be DRAWN before it can be read: the view was just re-synced,
	# so wait for the next drawn frame (the capture's `_save_frame` does the same).
	await RenderingServer.frame_post_draw
	if _shot != "":
		_save_shot(_shot)
	# Warm-up OUTSIDE the sample: the first frames after the boot pay for shader
	# compilation and the texture upload (measured: one frame of ~800 ms). They are
	# counted and reported on their own, never inside the mean.
	for i in _warmup:
		await process_frame
		_warm.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
	# Interleaved arms: window 0 has the stands ON, window 1 off, and so on, so the
	# machine's own noise lands on both arms. Separate-runs mode keeps one arm only.
	_group = _ctl._arena_root.get_node_or_null("Scenery/Bleachers") if _ctl._arena_root != null else null
	_window_i = 0 if _use_bleachers else 1
	_in_window = 0
	_window_frames = 0
	_window_usec = 0
	_windows_left = _interleave
	if _group != null:
		_group.visible = _use_bleachers
	_measuring = true
	_last_usec = Time.get_ticks_usec()


func _save_shot(path: String) -> void:
	var tex := root.get_texture()
	if tex == null:
		push_error("probe: viewport texture null")
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("probe: viewport image null")
		return
	var err := img.save_png(path)
	print("PROBE_SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])
	_shot_done = true


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	return float(values[int(values.size() * 0.5)])


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / float(values.size())


## [triangles, meshes] under a node.
func _count(from: Node) -> Array:
	if from == null:
		return [0, 0]
	var tris := 0
	var meshes := 0
	for mi in from.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		meshes += 1
		tris += mesh.get_faces().size() / 3
	return [tris, meshes]


## Everything the scene currently draws: the whole match tree, the arena subtree
## (the stands are inside it) and the stands on their own — plus the stands' own box
## in the frame, the on-screen size of one unit, from the engine's projection.
func _scene_report(cam: Camera3D) -> void:
	print("PROBE_SCENE tris_total=%d meshes_total=%d tris_arena=%d tris_athletes=%d" % [
		_count(_ctl)[0], _count(_ctl)[1],
		_count(_ctl._arena_root)[0], _count(_ctl.get_node_or_null("Athletes"))[0],
	])
	var group: Node = _ctl._arena_root.get_node_or_null("Scenery/Bleachers") if _ctl._arena_root != null else null
	if group == null or group.get_child_count() == 0:
		print("PROBE_BLEACHERS instances=0 report=%s" % JSON.stringify(Bleachers.report))
		return
	print("PROBE_BLEACHERS instances=%d tris=%d report=%s" % [group.get_child_count(), Bleachers.triangle_count(group), JSON.stringify(Bleachers.report)])
	var body_box: AABB = Bleachers.unit_box(group.get_child(0).get_child(0))
	# the copy was lifted inside its stack (the unit's own min_y is negative): the
	# same lift puts the projected box where the stand actually stands.
	body_box.position.y = 0.0
	for i in group.get_child_count():
		var stack: Node3D = group.get_child(i)
		var xform := stack.global_transform
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for c in 8:
			var px: Vector2 = cam.unproject_position(xform * body_box.get_endpoint(c))
			lo.x = minf(lo.x, px.x)
			lo.y = minf(lo.y, px.y)
			hi.x = maxf(hi.x, px.x)
			hi.y = maxf(hi.y, px.y)
		var base: Vector2 = cam.unproject_position(xform * Vector3(0.0, body_box.position.y, 0.0))
		var top: Vector2 = cam.unproject_position(xform * Vector3(0.0, body_box.end.y, 0.0))
		print("PROBE_UNIT name=%s world_pos=%s px_box=(%.0f,%.0f)-(%.0f,%.0f) px_w=%.0f px_h=%.0f px_height=%.0f" % [
			String(stack.name), str(stack.global_position), lo.x, lo.y, hi.x, hi.y,
			hi.x - lo.x, hi.y - lo.y, absf(base.y - top.y)])


func _report() -> void:
	var sorted := Array(_samples)
	sorted.sort()
	var wall_sorted := Array(_wall)
	wall_sorted.sort()
	var sum := 0.0
	for s in _samples:
		sum += s
	var wsum := 0.0
	for w in _wall:
		wsum += w
	var warm_worst := 0.0
	var warm_sum := 0.0
	for w in _warm:
		warm_worst = maxf(warm_worst, w)
		warm_sum += w
	var mean := sum / maxf(1.0, float(_samples.size()))
	var wmean := wsum / maxf(1.0, float(_wall.size()))
	# Trimmed means: the sample keeps the environment's own hitches (another engine
	# window on this Mac), so the middle 80% is the regime and the tail is reported.
	var trim := maxi(1, int(sorted.size() * 0.1))
	var tsum := 0.0
	for i in range(trim, sorted.size() - trim):
		tsum += float(sorted[i])
	var engine_trim := tsum / maxf(1.0, float(sorted.size() - trim * 2))
	var wtrim := maxi(1, int(wall_sorted.size() * 0.1))
	var wtsum := 0.0
	for i in range(wtrim, wall_sorted.size() - wtrim):
		wtsum += float(wall_sorted[i])
	var wall_trim := wtsum / maxf(1.0, float(wall_sorted.size() - wtrim * 2))
	for arm in [0, 1]:
		if (_arm_wall[arm] as Array).is_empty():
			continue
		var w: Array = (_arm_wall[arm] as Array).duplicate()
		var e: Array = (_arm_engine[arm] as Array).duplicate()
		w.sort()
		e.sort()
		var usec := int(_arm_usec[arm])
		print("PROBE_ARM arm=%s name=%s n=%d fps=%.1f wall_p50_ms=%.3f wall_mean_ms=%.3f wall_p95_ms=%.3f wall_worst_ms=%.3f engine_p50_ms=%.3f engine_mean_ms=%.3f" % [
			"ON" if arm == 0 else "off", "stands" if arm == 0 else "no stands", w.size(),
			float(_arm_frames[arm]) / maxf(0.001, float(usec) / 1000000.0),
			_median(w), _mean(w), float(w[int(w.size() * 0.95)]), float(w[w.size() - 1]),
			_median(e), _mean(e)])
	for line in _window_log:
		print("PROBE_WINDOW " + String(line))
	if _samples.is_empty():
		print("PROBE_WARMUP label=%s warmup=%d warmup_worst_ms=%.1f warmup_mean_ms=%.1f" % [
			_label, _warm.size(), warm_worst, warm_sum / maxf(1.0, float(_warm.size()))])
		return
	print("PROBE_FRAME label=%s bleachers=%s frames=%d engine_mean_ms=%.3f engine_p50_ms=%.3f engine_p95_ms=%.3f engine_worst_ms=%.3f wall_mean_ms=%.3f wall_p50_ms=%.3f wall_p95_ms=%.3f wall_worst_ms=%.3f engine_trim80_ms=%.3f wall_fps=%.1f wall_trim80_ms=%.3f warmup=%d warmup_worst_ms=%.1f warmup_mean_ms=%.1f" % [
		_label, str(_use_bleachers), _samples.size(), mean,
		_median(sorted), float(sorted[int(sorted.size() * 0.95)]), float(sorted[sorted.size() - 1]),
		wmean, _median(wall_sorted), float(wall_sorted[int(wall_sorted.size() * 0.95)]),
		float(wall_sorted[wall_sorted.size() - 1]), engine_trim,
		1000.0 / maxf(0.001, wmean), wall_trim, _warm.size(), warm_worst, warm_sum / maxf(1.0, float(_warm.size()))])
