## fit_report.gd — the arena-kit FIT pass, re-measured inside the engine.
##
## USAGE (engine discipline: one Godot process at a time):
##
##   $GODOT --headless --path godot/ --script <repo>/tools/arena-kit/fit_report.gd -- --emit
##   $GODOT --headless --path godot/ --script <repo>/tools/arena-kit/fit_report.gd
##
## TWO MODES
##
##   --emit     Measures every GLB on disk (raw mesh bounds, no spec involved) and prints
##              the row the fit produces for it: the fitted `target_h`, the fitted
##              `depth` and the anchor z that keeps the piece inside the band. This is
##              the source of the numbers in `arena_kit.gd::SPECS` — read, never guessed.
##   (default)  Builds all five arenas through the production path (`Arena.build_into`)
##              and GATES the six laws the fit exists to hold:
##
##                GLASS    every mounted front face behind the measured glass plane;
##                WALL     every mounted back face in front of the backdrop wall (-12.0);
##                BUDGET   every mounted depth <= `ArenaKit.DEPTH_BUDGET`;
##                HONEST   every slot's declared depth == its measured mesh depth;
##                HEIGHT   every piece measures its slot's declared `target_h`;
##                CENTRE   every piece's x centre within 0.10 m of its repeat offset.
##
## WHY IT EXISTS. The source table declared each mesh's own measured depth and pushed the
## anchor back until the glass was clear, which leaves the back of the deep pieces behind
## the backdrop wall — and leaves the depth budget red. This pass holds the band instead:
## the band between the glass margin and the wall is `FIT_DEPTH` metres, so a piece is
## scaled UNIFORMLY (height and depth together) until it either fits the band or reaches
## its authored height, whichever comes first. Nothing is squashed, no model is dropped,
## and the table records the measured result. Exit is 0 only when all six laws hold.
extends SceneTree

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")

## The camera preset the band is authored for (`x_scale` 1.34375).
const PRESET := "default"
## Every front face clears the measured glass plane by at least this much.
const GLASS_MARGIN := 0.05
## The backdrop wall (`arena_scenery.gd::BACKDROP_Z`) — behind it, a piece is not drawn.
const BACKDROP_Z := -12.0
## Every back face stays at least this far in front of the wall (the glass margin's twin:
## without it a piece clamped onto the wall sits exactly ON the plane, which float error
## then reads as a hair behind it).
const WALL_MARGIN := 0.01
## The deepest a piece may measure: front on the glass margin, back on the wall margin.
const FIT_DEPTH := -10.07 - (BACKDROP_Z + WALL_MARGIN)
## The front plane a fitted piece's face may reach.
const GLASS_FRONT_Z := -10.07
## The suite's own tolerances, so this report measures what the gate measures.
const SPEC_TOL := 0.005
const HEIGHT_TOL := 0.02
const CENTRE_TOL := 0.10

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	print("# FIT_REPORT · Godot %s · preset=%s · band=%.2f m (glass %.2f - margin %.2f -> wall %.2f)" % [
		Engine.get_version_info().get("string", "?"), PRESET, FIT_DEPTH,
		ArenaKit.GLASS_PLANE_Z, GLASS_MARGIN, BACKDROP_Z])
	root.size = Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("--emit"):
		_emit()
		quit(0)
		return
	quit(0 if _gate() else 1)


## Measures every GLB on disk and prints the row the fit produces for its slot. The
## authored height comes from the table in force; everything else is read off the file.
func _emit() -> void:
	var rows := 0
	var resized := 0
	for arena_id in ArenaKit.arenas():
		var arena := String(arena_id)
		for slot_in in ArenaKit.slots():
			var slot := String(slot_in)
			var path := ArenaKit.slot_path(arena, slot)
			if not ArenaKit.glb_exists(path):
				continue
			var raw := _raw_box(path)
			if raw.size.y <= 0.0001 or raw.size.z <= 0.0001:
				print("FIT_ROW %s/%s UNMEASURABLE %s" % [arena, slot, str(raw)])
				continue
			var entry := ArenaKit.spec(arena, slot)
			var ideal := float(entry.get("target_h", 0.0))
			var ratio := raw.size.z / raw.size.y
			var fitted_h := minf(ideal, FIT_DEPTH / ratio)
			# The declared height is TRUNCATED (never rounded up) so the depth the loader
			# derives from it can never overshoot the band it was fitted into.
			var declared_h := floorf(fitted_h * 100.0 + 0.000001) / 100.0
			var scale := declared_h / raw.size.y
			var measured_d := raw.size.z * scale
			var declared_d := roundf(measured_d * 100.0) / 100.0
			var anchor_z := clampf(float((entry["anchor"] as Vector3).z),
				BACKDROP_Z + WALL_MARGIN + measured_d * 0.5, GLASS_FRONT_Z - measured_d * 0.5)
			var banded := declared_h < ideal - 0.005
			# The footprint note keeps the source's own description and carries the fitted
			# measured box, so the note, the plan and the mount describe one object.
			var tail := String(entry.get("footprint", "")).get_slice(" - ", 1)
			rows += 1
			if banded:
				resized += 1
			print("FIT_ROW %s/%s raw_h=%.3f raw_d=%.3f raw_cx=%+.3f ideal_h=%.2f was_d=%.2f -> target_h=%.2f depth=%.2f scale=%.4f anchor_z=%.4f was_z=%.3f%s" % [
				arena, slot, raw.size.y, raw.size.z, raw.position.x + raw.size.x * 0.5,
				ideal, float(entry.get("depth", 0.0)), declared_h, declared_d, scale,
				anchor_z, float((entry["anchor"] as Vector3).z), " BANDED" if banded else ""])
			print("SPEC_ROW %s/%s anchor %s target_h %.2f depth %.2f footprint \"%.2f x %.2f x %.2f m - %s\"" % [
				arena, slot, _vec(Vector3(float((entry["anchor"] as Vector3).x), 0.0, anchor_z)),
				declared_h, declared_d, raw.size.x * scale, raw.size.y * scale, raw.size.z * scale, tail])
	print("# emit: %d slot(s), %d fitted to the band" % [rows, resized])


## A Vector3 as the table writes it.
func _vec(v: Vector3) -> String:
	return "Vector3(%.4f, %.1f, %.4f)" % [v.x, v.y, v.z]


## The six laws, measured off a real build. Returns true when all of them hold.
func _gate() -> bool:
	var glass_bad: Array[String] = []
	var wall_bad: Array[String] = []
	var budget_bad: Array[String] = []
	var honest_bad: Array[String] = []
	var height_bad: Array[String] = []
	var centre_bad: Array[String] = []
	var x_scale := _x_scale(PRESET)
	var pieces := 0
	for arena_id in ArenaKit.arenas():
		var arena := String(arena_id)
		var holder := Node3D.new()
		root.add_child(holder)
		var built := Arena.build_into(holder, arena, PRESET)
		for slot_in in ArenaKit.slots():
			var slot := String(slot_in)
			var slot_node := built.get_node_or_null("Scenery/Kit/Slot_%s" % slot) as Node3D
			if slot_node == null:
				continue
			var entry := ArenaKit.spec(arena, slot)
			var want_anchor := ArenaKit.anchor_at(arena, slot, x_scale)
			var repeats := int(entry["repeats"])
			var spread := float(entry["spread"]) * x_scale
			var i := 0
			for child in slot_node.get_children():
				if not String(child.name).begins_with("Piece"):
					continue
				var box := ArenaKit.node_bounds(child as Node3D)
				var ab := AABB(box.position + slot_node.position, box.size)
				var front := float(ab.position.z + ab.size.z)
				var back := float(ab.position.z)
				var depth := float(ab.size.z)
				var where := "%s/%s/%s" % [arena, slot, String(child.name)]
				var want_x := (float(i) - float(repeats - 1) * 0.5) * spread
				pieces += 1
				if front > ArenaKit.GLASS_PLANE_Z:
					glass_bad.append("%s front z=%.3f" % [where, front])
				if back < BACKDROP_Z:
					wall_bad.append("%s back z=%.3f (%.2f m past the wall)" % [where, back, BACKDROP_Z - back])
				if depth > ArenaKit.DEPTH_BUDGET:
					budget_bad.append("%s depth=%.3f" % [where, depth])
				if absf(depth - float(entry.get("depth", 0.0))) > SPEC_TOL:
					honest_bad.append("%s measured d=%.4f declared %.2f" % [where, depth, float(entry.get("depth", 0.0))])
				if absf(float(ab.size.y) - float(entry["target_h"])) > HEIGHT_TOL:
					height_bad.append("%s h=%.4f want %.2f" % [where, ab.size.y, float(entry["target_h"])])
				var drift := float(ab.position.x + ab.size.x * 0.5) - (want_anchor.x + want_x)
				if absf(drift) > CENTRE_TOL:
					centre_bad.append("%s centre x drift %+.3f m" % [where, drift])
				i += 1
		holder.free()
	print("# gate: %d piece(s) measured across the five arenas" % pieces)
	print("# GLASS: %s" % ("none" if glass_bad.is_empty() else str(glass_bad)))
	print("# WALL: %s" % ("none" if wall_bad.is_empty() else str(wall_bad)))
	print("# BUDGET: %s" % ("none" if budget_bad.is_empty() else str(budget_bad)))
	print("# HONEST: %s" % ("none" if honest_bad.is_empty() else str(honest_bad)))
	print("# HEIGHT: %s" % ("none" if height_bad.is_empty() else str(height_bad)))
	print("# CENTRE: %s" % ("none" if centre_bad.is_empty() else str(centre_bad)))
	var ok := glass_bad.is_empty() and wall_bad.is_empty() and budget_bad.is_empty() \
		and honest_bad.is_empty() and centre_bad.is_empty() and height_bad.is_empty()
	print("FIT_VERDICT %s" % ("PASS" if ok else "FAIL"))
	return ok


## A GLB's own bounds, before any spec: loaded with the same `GLTFDocument` path the kit
## mounts with, measured with the kit's own `node_bounds()` walk.
func _raw_box(res_path: String) -> AABB:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(res_path, state) != OK:
		return AABB()
	var scene := doc.generate_scene(state) as Node3D
	if scene == null:
		return AABB()
	var wrap := Node3D.new()
	wrap.add_child(scene)
	var box := ArenaKit.node_bounds(wrap)
	wrap.free()
	return box


func _x_scale(preset: String) -> float:
	var extent := ArenaScenery.band(preset, ArenaScenery.BACKDROP_Z)
	return float(extent["prop_half_x"]) / ArenaKit.AUTHORED_HALF_X
