## render_probe.gd — what the arena kit COSTS on screen, measured in the same run.
##
##   $GODOT --path godot/ --rendering-driver opengl3 --resolution 1280x720 \
##     --script "$PWD/tools/arena-kit/render_probe.gd" -- --frames=90 --warmup=30
##
## WHY AN A/B INSIDE ONE BUILD. The honest question is not "is the kitted arena fast"
## (there is no engine-side way to un-load the fifty files without touching the assets),
## it is "what does the kit's own geometry add to the same arena, same camera, same
## frames". So each arena is built ONCE with the kit mounted and then timed twice — with
## the `Kit` node visible and with it hidden — so the procedural scenery, the backdrop,
## the glass, the tribunes and the camera are identical in both passes and only the kit's
## draws differ. Hide, never free: no rebuild between the two passes, no asset touched.
##
## HONEST LIMITS, printed with the numbers: this is a macOS desktop GL run, not a
## target-hardware or GPU-frame-time measurement; vsync is disabled for the run, frames
## are wall-clock on the main thread, and the per-arena kit geometry is reported next to
## the timing so the number can be read against what it bought (mesh and triangle counts).
extends SceneTree

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")
const Court := preload("res://game/court.gd")

const PRESET := "default"

var _started := false
var _frames := 90
var _warmup := 30


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	# NOT true: in a `SceneTree` script, returning true from `_process()` asks the main loop
	# to quit, which would end the run before the first awaited frame. `_run()` calls
	# `quit()` itself when the measurements are done.
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_frames = _argi(args, "--frames=", _frames)
	_warmup = _argi(args, "--warmup=", _warmup)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	print("# RENDER_PROBE · Godot %s · driver=%s · %dx%d · warmup=%d frames=%d · vsync off" % [
		Engine.get_version_info().get("string", "?"),
		RenderingServer.get_video_adapter_name(), 1280, 720, _warmup, _frames])
	print("# these are main-thread wall-clock frame times on this desktop GL run, not GPU")
	print("# frame times on target hardware; read them next to the kit geometry below.")
	print("PROBE_COLUMNS arena kit_meshes kit_tris visible_ms hidden_ms delta_ms visible_fps hidden_fps")
	for arena_id in ArenaKit.arenas():
		await _measure(String(arena_id))
	print("# PROBE_DONE")
	quit(0)


func _measure(arena_id: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	Court.build_camera(holder, PRESET)
	var built := Arena.build_into(holder, arena_id, PRESET)
	var kit := built.get_node_or_null("Scenery/Kit") as Node3D
	var kit_meshes := 0
	var kit_tris := 0
	if kit != null:
		for mi in kit.find_children("*", "MeshInstance3D", true, false):
			kit_meshes += 1
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if mesh != null and mesh is ArrayMesh:
				for s in mesh.get_surface_count():
					var arrays: Array = (mesh as ArrayMesh).surface_get_arrays(s)
					if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
						kit_tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if kit != null:
		kit.visible = true
	var visible_ms := await _sample()
	if kit != null:
		kit.visible = false
	var hidden_ms := await _sample()
	if kit != null:
		kit.visible = true
	print("PROBE_ROW %s %d %d %.3f %.3f %+.3f %.1f %.1f" % [arena_id, kit_meshes, kit_tris,
		visible_ms, hidden_ms, visible_ms - hidden_ms,
		1000.0 / maxf(visible_ms, 0.0001), 1000.0 / maxf(hidden_ms, 0.0001)])
	holder.free()


## Warm-up frames first (shader compile, first-draw upload), then a timed run of
## `_frames` frames; the number is the mean frame time in milliseconds.
func _sample() -> float:
	for i in _warmup:
		await process_frame
	var t0 := Time.get_ticks_usec()
	for i in _frames:
		await process_frame
	return float(Time.get_ticks_usec() - t0) / float(_frames) / 1000.0


func _argi(args: PackedStringArray, prefix: String, fallback: int) -> int:
	for a in args:
		if a.begins_with(prefix):
			return int(a.substr(prefix.length()))
	return fallback
