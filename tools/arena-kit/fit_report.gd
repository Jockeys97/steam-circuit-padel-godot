## fit_report.gd — the FIT pass's own re-measure: after the anchors moved, does every
## mounted piece really sit behind the rear glass and clear the court, and does every
## slot's declared depth really equal the mesh the engine mounts?
##
## USAGE (engine discipline: one Godot process at a time — `pgrep -x Godot` first and
## `flock -w 900 /tmp/padel-godot.lock` around the run; macOS has no util-linux flock, use
## `run/tmp/arena-kit/bin/flock`):
##
##   $GODOT --headless --path godot/ --script <repo>/tools/arena-kit/fit_report.gd -- \
##     --out=/tmp/fit-after.json
##
## WHY IT EXISTS. `mount_census.gd` counts what mounts; this measures the ONE property the
## fit pass changed: the front/back faces of every mounted piece in the arena frame, at the
## anchors now in the table, next to the MEASURED glass plane and the backdrop wall. Every
## number is read back off a real build (`Arena.build_into`, the production path) — the
## arithmetic in the table is never trusted.
##
## THE THREE GATES (exit 0 only when all three pass; everything else is reported, not gated):
##   * GLASS  — every mounted piece's front face is at least `GLASS_MARGIN` behind the
##              measured glass plane, and the frozen suite's own per-mesh measurement
##              (`Common.field_law_report`) lists nothing in front of it either;
##   * COURT  — no mounted piece overlaps the playable footprint, by both measurements;
##   * HONEST — every slot's declared `depth` equals its measured mesh depth (2 dp).
##
## REPORTED, NOT GATED (the brief's fail-honest list): pieces whose measured depth exceeds
## `ArenaKit.DEPTH_BUDGET` (the 3.26 m constant derived for the DEFAULT prop z), and pieces
## whose back face sits behind the backdrop wall at z = -12.0. The band between the glass
## (-10.02) and the wall (-12.0) is under two metres, so a piece deeper than that cannot
## both clear the glass and stay in front of the wall: the owner's scale call, named here.
extends SceneTree

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Common := preload("res://tests/world_arenas_common.gd")

## The camera preset the band is authored for (x_scale 1.34375).
const PRESET := "default"
## The fit margin: every front face at least this far behind the measured glass plane.
const GLASS_MARGIN := 0.05
## The backdrop wall plane (`arena_scenery.gd::BACKDROP_Z`) and the court bed's rear line.
const BACKDROP_Z := -12.0
const COURT_REAR_Z := -10.0
const COURT_HALF_X := 5.0
## Declared-vs-measured honesty tolerance: the table carries 2 dp.
const SPEC_TOL := 0.005

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := _arg(args, "--out=", "")
	print("# FIT_REPORT · Godot %s · preset=%s · margin=%.2f m" % [
		Engine.get_version_info().get("string", "?"), PRESET, GLASS_MARGIN])
	root.size = Vector2i(1280, 720)
	var report := {}
	var all_ok := true
	for id_in in ArenaKit.arenas():
		var id := String(id_in)
		var holder := Node3D.new()
		root.add_child(holder)
		var built := Arena.build_into(holder, id, PRESET)
		var strict := Common.field_law_report(built)
		var glass_z := float(strict["glass_z"])
		var rows: Array = []
		var glass_bad: Array[String] = []
		var court_bad: Array[String] = []
		var honest_bad: Array[String] = []
		var over_budget: Array[String] = []
		var behind_wall: Array[String] = []
		var worst_margin := INF
		var pieces := 0
		for slot_in in ArenaKit.slots():
			var slot := String(slot_in)
			var entry := ArenaKit.spec(id, slot)
			var slot_node := built.get_node_or_null("Scenery/Kit/Slot_%s" % slot) as Node3D
			if slot_node == null:
				continue
			for child in slot_node.get_children():
				if not String(child.name).begins_with("Piece"):
					continue
				var piece := child as Node3D
				var box := ArenaKit.node_bounds(piece)
				var ab := AABB(box.position + slot_node.position, box.size)
				var front := float(ab.position.z + ab.size.z)
				var back := float(ab.position.z)
				var depth := float(ab.size.z)
				var declared := float(entry.get("depth", 0.0))
				var x_min := float(ab.position.x)
				var x_max := float(ab.position.x + ab.size.x)
				var margin := glass_z - front
				worst_margin = minf(worst_margin, margin)
				pieces += 1
				var where := "%s/%s" % [slot, String(piece.name)]
				if margin < GLASS_MARGIN - 0.0001:
					glass_bad.append("%s front z=%+.3f margin=%.3f (< %.2f)" % [where, front, margin, GLASS_MARGIN])
				if front > COURT_REAR_Z and x_min < COURT_HALF_X and x_max > -COURT_HALF_X:
					court_bad.append("%s front z=%+.3f x=%+.2f..%+.2f" % [where, front, x_min, x_max])
				if absf(declared - depth) > SPEC_TOL:
					honest_bad.append("%s measured d=%.4f declared %.2f" % [where, depth, declared])
				if depth > ArenaKit.DEPTH_BUDGET + 0.0001:
					over_budget.append("%s d=%.2f m" % [where, depth])
				if back < BACKDROP_Z:
					behind_wall.append("%s back z=%+.2f (%.2f m past the wall)" % [where, back, BACKDROP_Z - back])
				rows.append({
					"slot": slot, "piece": String(piece.name),
					"measured_w": float(ab.size.x), "measured_h": float(ab.size.y), "measured_d": depth,
					"declared_depth": declared,
					"back_z": back, "front_z": front, "glass_margin": margin,
					"x_min": x_min, "x_max": x_max,
					"glass_ok": margin >= GLASS_MARGIN - 0.0001,
					"court_ok": not (front > COURT_REAR_Z and x_min < COURT_HALF_X and x_max > -COURT_HALF_X),
					"honest_ok": absf(declared - depth) <= SPEC_TOL,
					"depth_budget_ok": depth <= ArenaKit.DEPTH_BUDGET + 0.0001,
					"wall_ok": back >= BACKDROP_Z,
				})
		var strict_glass: Array = strict["behind_glass"]
		var strict_court: Array = strict["court_overlap"]
		var glass_ok := glass_bad.is_empty() and strict_glass.is_empty() and bool(strict["glass_found"])
		var court_ok := court_bad.is_empty() and strict_court.is_empty()
		var honest_ok := honest_bad.is_empty()
		all_ok = all_ok and glass_ok and court_ok and honest_ok
		print("== %s  glass_z=%+.2f (%d panes)  pieces=%d  worst front margin=%+.3f m" % [
			id, glass_z, int(strict["glass_panes"]), pieces, worst_margin if pieces > 0 else NAN])
		print("   GLASS %s (aabb offenders=%d, strict suite offenders=%d) · COURT %s (aabb=%d, strict=%d) · HONEST %s (%d mismatches)" % [
			_pass(glass_ok), glass_bad.size(), strict_glass.size(),
			_pass(court_ok), court_bad.size(), strict_court.size(), _pass(honest_ok), honest_bad.size()])
		print("   reporting: over the 3.26 m default-z budget=%d · behind the backdrop wall=%d" % [
			over_budget.size(), behind_wall.size()])
		for line in glass_bad:
			print("   GLASS-BAD   %s" % line)
		for line in court_bad:
			print("   COURT-BAD   %s" % line)
		for line in honest_bad:
			print("   HONEST-BAD  %s" % line)
		for line in over_budget:
			print("   OVER-BUDGET %s" % line)
		for line in behind_wall:
			print("   BEHIND-WALL %s" % line)
		report[id] = {
			"glass_z": glass_z, "pieces": pieces, "worst_front_margin": worst_margin,
			"glass_ok": glass_ok, "court_ok": court_ok, "honest_ok": honest_ok,
			"glass_bad": glass_bad, "court_bad": court_bad, "honest_bad": honest_bad,
			"over_depth_budget": over_budget, "behind_backdrop_wall": behind_wall,
			"strict_closest_z": float(strict["closest_z"]),
			"rows": rows,
		}
		root.remove_child(holder)
		holder.free()
	print("")
	print("FIT_VERDICT %s" % ("PASS" if all_ok else "FAIL"))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			print("FAIL fit_report: cannot write %s" % out)
		else:
			f.store_string(JSON.stringify({
				"godot": Engine.get_version_info().get("string", ""),
				"preset": PRESET, "glass_margin": GLASS_MARGIN, "backdrop_z": BACKDROP_Z,
				"report": report,
			}, "  "))
			f.close()
			print("# json written to %s" % out)
	quit(0 if all_ok else 1)


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			var rest := a.substr(prefix.length())
			if rest.begins_with("="):
				rest = rest.substr(1)
			return rest
	return fallback


func _pass(v: bool) -> String:
	return "PASS" if v else "FAIL"
