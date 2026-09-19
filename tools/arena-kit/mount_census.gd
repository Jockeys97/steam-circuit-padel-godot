## mount_census.gd — what the arena kit ACTUALLY mounts, measured from the engine.
##
## USAGE (engine discipline: one Godot process at a time — `flock -w 900
## /tmp/padel-godot.lock` around the run and `pgrep -x Godot` checked first):
##
##   $GODOT --headless --path godot/ --script tools/arena-kit/mount_census.gd -- \
##     --mode=both --arena=torii --out=/tmp/mount-census.json
##
##   --mode=before   force the kit's suppression OFF (`ArenaKit.suppress_overrides`,
##                   every slot false) and census that build: the ADDITIVE default
##                   KIT-STANDARD §5 documents, a mounted GLB and the procedural prop
##                   it maps to both standing.
##   --mode=after    census the spec table exactly as it ships.
##   --mode=both     both passes, in that order (default).
##   --arena=a,b     census only these arenas (default: the five world arenas).
##   --out=<path>    also write the machine-readable census as JSON there.
##
## WHAT "DOUBLING" MEANS HERE. A slot's `kinds` are its procedural counterpart. A slot
## DOUBLES when `kinds` is non-empty, a GLB is in place, and the procedural prop still
## builds: the same dressing intent is then in the scene twice. The headline is
## `doubling_slots`; the clutter behind it is `doubling_procedural_meshes`, the number
## of `MeshInstance3D` nodes the doubled slots contribute ON TOP of the mount.
##
## WHERE THE NUMBERS COME FROM (never the spec's declared values):
##   * a mounted instance's box is `ArenaKit.node_bounds(Piece)` — the mesh AABBs through
##     the node chain, the kit's own measurement — re-expressed in the ARENA frame by the
##     `Slot_<slot>` holder's transform, which is what the field law and the frame law are
##     written in. `measured_d` (box depth) is compared with the slot's declared `depth`.
##   * the field law, the glass plane and the court-overlap check are the FROZEN suite's
##     own measurement (`tests/world_arenas_common.gd::field_law_report`), which walks
##     every scenery VERTEX; the per-piece AABB numbers reported here are the tighter,
##     conservative bound and both are printed when they disagree.
##   * the screen check builds a LIVE `Camera3D` with `Court.build_camera("default")` and
##     projects through it (the renderer's own math), so "behind the play area and cannot
##     occlude the court" is a measured claim: every mounted instance projects inside the
##     1280x720 frame and ENTIRELY ABOVE the rear baseline's own screen row.
##
## Exit 0 when every gate passes in the `after` pass, 1 otherwise. A `SCRIPT ERROR` in
## the log is a failure whatever the exit code says.
extends SceneTree

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")
const Court := preload("res://game/court.gd")
const Common := preload("res://tests/world_arenas_common.gd")

## The framing contract's viewport (the same one `world_arenas_frame_test.gd` uses).
const VIEW := Vector2i(1280, 720)
## A mounted piece must measure its spec height within this (the kit test's tolerance).
const HEIGHT_TOL := 0.02
## The camera preset the mounted band is authored for.
const PRESET := "default"
## The court's rear end line: the screen row a mounted instance must stay above.
const REAR_BASELINE_Z := -10.0

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := _arg(args, "--mode=", "both")
	var ids := _ids(args)
	var out := _arg(args, "--out=", "")
	root.size = VIEW
	var viewport := Vector2(root.get_visible_rect().size)
	print("# MOUNT_CENSUS · Godot %s · viewport=%dx%d · preset=%s · mode=%s" % [
		Engine.get_version_info().get("string", "?"), int(viewport.x), int(viewport.y), PRESET, mode])
	print("# depth budget=%.2f m · glass plane=%.2f · field law z=%.1f · authored half x=%.2f" % [
		ArenaKit.DEPTH_BUDGET, ArenaKit.GLASS_PLANE_Z, ArenaKit.FIELD_LAW_Z, ArenaKit.AUTHORED_HALF_X])
	var report := {}
	for id_in in ids:
		var id := String(id_in)
		if not ArenaKit.SPECS.has(id):
			print("FAIL census: '%s' is not a kit arena" % id)
			continue
		var row := {}
		if mode == "before" or mode == "both":
			# Every slot forced OFF: the additive default, whatever the table says.
			ArenaKit.suppress_overrides = _all_off(id)
			row["before"] = _census(id, "before", true)
		if mode == "after" or mode == "both":
			ArenaKit.suppress_overrides = {}
			row["after"] = _census(id, "after", false)
		ArenaKit.suppress_overrides = {}
		report[id] = row
	_print_header()
	for id in report:
		for tag in report[id]:
			_print_arena(id, tag, report[id][tag])
	var gates := _gates(report)
	print("")
	print("# GATES (after pass = the table as it ships)")
	for g in gates["rows"]:
		print(g)
	print("CENSUS_VERDICT %s" % ("PASS" if gates["ok"] else "FAIL"))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f == null:
			print("FAIL census: cannot write %s" % out)
		else:
			f.store_string(JSON.stringify({"godot": Engine.get_version_info().get("string", ""), "report": report, "gates": gates["json"]}, "  "))
			f.close()
			print("# json written to %s" % out)
	quit(0 if gates["ok"] else 1)


# ---------------------------------------------------------------------------
# One arena, one pass
# ---------------------------------------------------------------------------

func _census(id: String, tag: String, forced_off: bool) -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var cam_holder := Node3D.new()
	root.add_child(cam_holder)
	var cam := Court.build_camera(cam_holder, PRESET)
	var built := Arena.build_into(holder, id, PRESET)
	var out := {
		"tag": tag,
		"suppress_forced_off": forced_off,
		"suppressed_kinds": ArenaKit.suppressed_kinds(id),
		"dressing": _dressing_count(built),
		"props_authored": _props_authored(id),
		"field_law_production": ArenaScenery.field_law_report(built),
	}
	var strict := Common.field_law_report(built)
	out["strict"] = {
		"closest_z": float(strict["closest_z"]),
		"closest_name": String(strict["closest_name"]),
		"glass_z": float(strict["glass_z"]),
		"glass_panes": int(strict["glass_panes"]),
		"glass_found": bool(strict["glass_found"]),
		"court_overlap": (strict["court_overlap"] as Array).duplicate(),
		"behind_glass": (strict["behind_glass"] as Array).duplicate(),
	}
	var kit := built.get_node_or_null("Scenery/Kit")
	out["kit_present"] = kit != null
	out["kit_slots"] = int(kit.get_meta("slots", 0)) if kit != null else 0
	var x_scale := _x_scale()
	out["x_scale"] = x_scale
	var glass_z := float(strict["glass_z"])
	var slot_rows: Array = []
	var pieces: Array = []
	var doubling_slots := 0
	var doubling_meshes := 0
	var procedural_meshes := 0
	var procedural_containers := 0
	for slot_in in ArenaKit.slots():
		var slot := String(slot_in)
		var entry := ArenaKit.spec(id, slot)
		var kinds: Array = entry.get("kinds", [])
		var containers: Array = []
		var proc_meshes: Array = []
		for container in _dressing_containers(built):
			if kinds.has(String(container.get_meta("kind", ""))):
				containers.append(container)
				proc_meshes.append_array(container.find_children("*", "MeshInstance3D", true, false))
		procedural_containers += containers.size()
		procedural_meshes += proc_meshes.size()
		var slot_node := built.get_node_or_null("Scenery/Kit/Slot_%s" % slot) as Node3D
		var rects: Array = []
		if slot_node != null:
			for child in slot_node.get_children():
				if String(child.name).begins_with("Piece"):
					rects.append(_piece_rect(id, slot, slot_node, child as Node3D, cam, _viewport(), glass_z, x_scale))
		var present := ArenaKit.glb_exists(ArenaKit.slot_path(id, slot))
		var doubles := present and not kinds.is_empty() and proc_meshes.size() > 0 and rects.size() > 0
		if doubles:
			doubling_slots += 1
			doubling_meshes += proc_meshes.size()
		pieces.append_array(rects)
		slot_rows.append({
			"slot": slot,
			"glb_present": present,
			"kinds": kinds.duplicate(),
			"suppress_flag": bool(entry.get("suppress", false)),
			"procedural_containers": containers.size(),
			"procedural_meshes": proc_meshes.size(),
			"mounted_pieces": rects.size(),
			"declared_depth": float(entry.get("depth", 0.0)),
			"target_h": float(entry.get("target_h", 0.0)),
			"doubles": doubles,
		})
	out["slots"] = slot_rows
	out["pieces"] = pieces
	out["procedural_meshes"] = procedural_meshes
	out["procedural_containers"] = procedural_containers
	out["mounted_pieces"] = pieces.size()
	out["doubling_slots"] = doubling_slots
	out["doubling_procedural_meshes"] = doubling_meshes
	out["materials"] = _materials(kit)
	out["gates"] = _arena_gates(out)
	root.remove_child(cam_holder)
	cam_holder.free()
	root.remove_child(holder)
	holder.free()
	return out


## One mounted instance, measured. `box` is `ArenaKit.node_bounds(piece)` — the piece's
## own transform applied, i.e. in the `Slot_<slot>` holder's frame — so the arena frame is
## the holder's own anchor plus that box.
func _piece_rect(id: String, slot: String, holder: Node3D, piece: Node3D, cam: Camera3D,
		view: Vector2, glass_z: float, x_scale: float) -> Dictionary:
	var box := ArenaKit.node_bounds(piece)
	var arena_box := AABB(box.position + holder.position, box.size)
	var entry := ArenaKit.spec(id, slot)
	var repeat := String(piece.name)
	var inside := true
	var behind := false
	var worst_margin := INF
	var lowest_row := -INF
	var top_row := INF
	for i in 8:
		var corner: Vector3 = arena_box.get_endpoint(i)
		if cam.is_position_behind(corner):
			behind = true
			continue
		var px: Vector2 = cam.unproject_position(corner)
		worst_margin = minf(worst_margin, minf(minf(px.x, px.y), minf(view.x - px.x, view.y - px.y)))
		lowest_row = maxf(lowest_row, px.y)
		top_row = minf(top_row, px.y)
	if worst_margin < 0.0:
		inside = false
	# The rear baseline's own screen row at this instance's x: a mounted instance that
	# stays above it cannot occlude the court from this camera.
	var baseline_px: Vector2 = cam.unproject_position(Vector3(arena_box.position.x + arena_box.size.x * 0.5, 0.0, REAR_BASELINE_Z))
	var front_z := float(arena_box.position.z + arena_box.size.z)
	# The FRAME LAW is an authored-space law (`AUTHORED_HALF_X` bounds the style tables the
	# default preset's top row spans), while a built arena multiplies authored x by the
	# preset's own `x_scale` (1.3437 at "default" here). So the gate reads the extents in
	# authored metres, and the as-built extents are reported beside them.
	var auth_min := float(arena_box.position.x) / x_scale
	var auth_max := float(arena_box.position.x + arena_box.size.x) / x_scale
	return {
		"slot": slot,
		"piece": repeat,
		"measured_h": float(arena_box.size.y),
		"measured_w": float(arena_box.size.x),
		"measured_d": float(arena_box.size.z),
		"target_h": float(entry.get("target_h", 0.0)),
		"declared_depth": float(entry.get("depth", 0.0)),
		"x_min": float(arena_box.position.x),
		"x_max": float(arena_box.position.x + arena_box.size.x),
		"x_authored_min": auth_min,
		"x_authored_max": auth_max,
		"bottom_y": float(arena_box.position.y),
		"top_y": float(arena_box.position.y + arena_box.size.y),
		"back_z": float(arena_box.position.z),
		"front_z": front_z,
		"depth_ok": float(arena_box.size.z) <= ArenaKit.DEPTH_BUDGET,
		"field_law_ok": front_z <= ArenaKit.FIELD_LAW_Z,
		"glass_ok": front_z <= glass_z + 0.0001,
		"frame_ok": absf(auth_min) <= ArenaKit.AUTHORED_HALF_X + 0.0001 \
			and absf(auth_max) <= ArenaKit.AUTHORED_HALF_X + 0.0001,
		"height_ok": absf(float(arena_box.size.y) - float(entry.get("target_h", 0.0))) <= HEIGHT_TOL,
		"bottom_origin_ok": absf(float(arena_box.position.y)) <= 0.001,
		"screen_inside": inside and not behind,
		"screen_behind_camera": behind,
		"screen_worst_margin_px": worst_margin,
		"screen_lowest_row": lowest_row,
		"screen_baseline_row": baseline_px.y,
		"screen_above_baseline": lowest_row <= baseline_px.y + 0.5,
	}


# ---------------------------------------------------------------------------
# Per-arena gates
# ---------------------------------------------------------------------------

func _arena_gates(cen: Dictionary) -> Dictionary:
	var g := {}
	var pieces: Array = cen["pieces"]
	g["doubling_zero"] = int(cen["doubling_slots"]) == 0
	g["field_law_production_empty"] = (cen["field_law_production"] as Array).is_empty()
	var strict: Dictionary = cen["strict"]
	var glass_z := float(strict["glass_z"])
	g["field_law_closest_z"] = float(strict["closest_z"]) <= ArenaKit.FIELD_LAW_Z
	g["no_scenery_over_the_court"] = (strict["court_overlap"] as Array).is_empty()
	g["behind_measured_glass"] = bool(strict["glass_found"]) and (strict["behind_glass"] as Array).is_empty()
	var depth_bad: Array = []
	var frame_bad: Array = []
	var height_bad: Array = []
	var origin_bad: Array = []
	var screen_bad: Array = []
	var screen_row_bad: Array = []
	var strict_bad: Array = []
	var over_court: Array = []
	for p in pieces:
		var where := "%s/%s" % [p["slot"], p["piece"]]
		if not bool(p["depth_ok"]):
			depth_bad.append("%s %.2f m" % [where, p["measured_d"]])
		if not bool(p["frame_ok"]):
			frame_bad.append("%s authored x=%.2f..%.2f (as built %.2f..%.2f)" % [where,
				p["x_authored_min"], p["x_authored_max"], p["x_min"], p["x_max"]])
		if not bool(p["height_ok"]):
			height_bad.append("%s h=%.3f want %.2f" % [where, p["measured_h"], p["target_h"]])
		if not bool(p["bottom_origin_ok"]):
			origin_bad.append("%s bottom=%.3f" % [where, p["bottom_y"]])
		if not bool(p["screen_inside"]):
			screen_bad.append("%s margin=%.1fpx behind=%s" % [where, p["screen_worst_margin_px"], str(p["screen_behind_camera"])])
		if not bool(p["screen_above_baseline"]):
			screen_row_bad.append("%s row=%.1f baseline=%.1f" % [where, p["screen_lowest_row"], p["screen_baseline_row"]])
		if not bool(p["glass_ok"]):
			strict_bad.append("%s front z=%+.2f (measured glass %+.2f)" % [where, p["front_z"], glass_z])
		# The playable footprint: the court bed's x/z rectangle at any height — a mounted
		# AABB intersecting it stands over playable ground (the frozen suite's own check).
		if float(p["front_z"]) > -10.0 and float(p["x_min"]) < 5.0 and float(p["x_max"]) > -5.0:
			over_court.append("%s z=%+.2f..%+.2f x=%+.2f..%+.2f" % [where, p["back_z"], p["front_z"], p["x_min"], p["x_max"]])
	g["depth_budget"] = depth_bad.is_empty()
	g["frame_law"] = frame_bad.is_empty()
	g["target_height"] = height_bad.is_empty()
	g["bottom_origin"] = origin_bad.is_empty()
	g["culling_inside_frame"] = screen_bad.is_empty()
	g["culling_above_baseline"] = screen_row_bad.is_empty()
	var mats: Dictionary = cen["materials"]
	g["material_policy"] = int(mats["policy_violations"]) == 0 and int(mats["unique_materials"]) <= int(mats["files_present"]) * 3 \
		and int(mats["shared_across_repeats_violations"]) == 0
	g["detail"] = {
		"doubling_zero": [],
		"no_scenery_over_the_court": over_court,
		"behind_measured_glass": strict_bad,
		"depth_budget": depth_bad,
		"frame_law": frame_bad,
		"target_height": height_bad,
		"bottom_origin": origin_bad,
		"culling_inside_frame": screen_bad,
		"culling_above_baseline": screen_row_bad,
		"material_policy": (mats["notes"] as Array).duplicate(),
	}
	return g


func _materials(kit: Node3D) -> Dictionary:
	var out := {"surfaces": 0, "unique_materials": 0, "files_present": 0, "policy_violations": 0,
		"shared_across_repeats_violations": 0, "notes": []}
	if kit == null:
		return out
	var instances := {}
	var per_slot_surface := {}
	var violations: Array = []
	var shared_bad: Array = []
	for mi_in in kit.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_in as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var holder := mi.get_parent()
		while holder != null and not String(holder.name).begins_with("Slot_"):
			holder = holder.get_parent()
		var slot := String(holder.name) if holder != null else "?"
		for s in mesh.get_surface_count():
			out["surfaces"] = int(out["surfaces"]) + 1
			var mat := mi.get_surface_override_material(s) as StandardMaterial3D
			if mat == null:
				violations.append("%s/%s surface %d has no override material" % [slot, mi.name, s])
				continue
			instances[mat.get_instance_id()] = true
			var key := "%s#%d" % [slot, s]
			if per_slot_surface.has(key) and int(per_slot_surface[key]) != mat.get_instance_id():
				shared_bad.append("%s is not one shared material across the repeats" % key)
			per_slot_surface[key] = mat.get_instance_id()
			if not is_zero_approx(mat.metallic) or not is_equal_approx(mat.roughness, 0.85) \
					or mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				violations.append("%s/%s surface %d metallic=%.2f roughness=%.2f emission=%s transparency=%d" % [
					slot, mi.name, s, mat.metallic, mat.roughness, str(mat.emission_enabled), mat.transparency])
	out["unique_materials"] = instances.size()
	out["policy_violations"] = violations.size()
	out["shared_across_repeats_violations"] = shared_bad.size()
	out["notes"] = violations + shared_bad
	out["files_present"] = _files_present(kit)
	return out


## How many DISTINCT slot files the arena's kit actually mounted (the material policy is
## "bounded per file, not per model").
func _files_present(kit: Node3D) -> int:
	var files := {}
	for slot_in in ArenaKit.slots():
		var slot := String(slot_in)
		var holder := kit.get_node_or_null("Slot_%s" % slot)
		if holder != null and holder.get_child_count() > 0:
			files[String(holder.get_meta("asset", slot))] = true
	return files.size()


# ---------------------------------------------------------------------------
# Printing
# ---------------------------------------------------------------------------

func _print_header() -> void:
	print("")
	print("ARENA/SLOT CENSUS — proc = the procedural counterpart (containers/meshes), mounted = pieces in Scenery/Kit/Slot_<slot>")


func _print_arena(id: String, tag: String, cen: Dictionary) -> void:
	print("")
	print("== %s [%s] suppressed_kinds=%s dressing=%d/%d kit_slots=%d proc_meshes=%d mounted_pieces=%d doubling_slots=%d" % [
		id, tag, str(cen["suppressed_kinds"]), int(cen["dressing"]), int(cen["props_authored"]),
		int(cen["kit_slots"]), int(cen["procedural_meshes"]), int(cen["mounted_pieces"]), int(cen["doubling_slots"])])
	print("   %-18s %-14s %-10s %-9s %-6s %s" % ["slot", "kinds", "proc c/m", "mounted", "suppr", "doubles"])
	for row in cen["slots"]:
		print("   %-18s %-14s %-10s %-9d %-6s %s" % [
			String(row["slot"]), ",".join(row["kinds"]) if not (row["kinds"] as Array).is_empty() else "-",
			"%d/%d" % [int(row["procedural_containers"]), int(row["procedural_meshes"])],
			int(row["mounted_pieces"]), "on" if bool(row["suppress_flag"]) else "off",
			"DOUBLE" if bool(row["doubles"]) else "-"])
	print("   %-18s %-14s %-10s %-9s %-6s" % ["slot", "measured h/w/d", "front_z", "declared d", "gates"])
	for p in cen["pieces"]:
		print("   %-18s %5.2f/%5.2f/%5.2f @z%+7.2f decl %4.2f  depth=%s glass=%s law=%s frame=%s h=%s screen=%s (authored x %+.2f..%+.2f)" % [
			"%s/%s" % [p["slot"], p["piece"]], float(p["measured_h"]), float(p["measured_w"]), float(p["measured_d"]),
			float(p["front_z"]), float(p["declared_depth"]),
			_ok(p["depth_ok"]), _ok(p["glass_ok"]), _ok(p["field_law_ok"]), _ok(p["frame_ok"]), _ok(p["height_ok"]),
			_ok(p["screen_inside"] and p["screen_above_baseline"]),
			float(p["x_authored_min"]), float(p["x_authored_max"])])
	var mats: Dictionary = cen["materials"]
	print("   materials: surfaces=%d unique=%d files=%d policy_violations=%d shared_across_repeats_violations=%d" % [
		int(mats["surfaces"]), int(mats["unique_materials"]), int(mats["files_present"]),
		int(mats["policy_violations"]), int(mats["shared_across_repeats_violations"])])
	var strict: Dictionary = cen["strict"]
	print("   strict field law: closest_z=%+.2f at '%s' · glass_z=%+.2f (%d panes) · court_overlap=%d · behind_glass=%d" % [
		float(strict["closest_z"]), String(strict["closest_name"]), float(strict["glass_z"]),
		int(strict["glass_panes"]), (strict["court_overlap"] as Array).size(), (strict["behind_glass"] as Array).size()])


func _gates(report: Dictionary) -> Dictionary:
	var rows: Array = []
	var json := {}
	var all_ok := true
	var gate_names := ["doubling_zero", "field_law_production_empty", "field_law_closest_z", "no_scenery_over_the_court",
		"behind_measured_glass", "depth_budget", "frame_law", "target_height", "bottom_origin",
		"culling_inside_frame", "culling_above_baseline", "material_policy"]
	for name in gate_names:
		var cells: Array = []
		var ok := true
		var detail := {}
		for id in report:
			var cen: Dictionary = report[id].get("after", {})
			if cen.is_empty():
				continue
			var gt: Dictionary = cen["gates"]
			var v := bool(gt.get(name, false))
			ok = ok and v
			cells.append("%s=%s" % [id, "PASS" if v else "FAIL"])
			if not v:
				var d: Dictionary = gt.get("detail", {})
				var lines: Array = d.get(name, [])
				detail[id] = lines if not lines.is_empty() else "see the census lines above"
		json[name] = {"ok": ok, "detail": detail}
		all_ok = all_ok and ok
		rows.append("GATE %-28s %-6s %s" % [name, "PASS" if ok else "FAIL", "  ".join(cells) \
			+ ("" if detail.is_empty() else "  detail=%s" % str(detail))])
	# The headline: doubling before vs after, summed over the arenas.
	var before_slots := 0
	var after_slots := 0
	var before_meshes := 0
	var after_meshes := 0
	var before_pieces := 0
	var after_pieces := 0
	var before_proc := 0
	var after_proc := 0
	for id in report:
		if report[id].has("before"):
			before_slots += int(report[id]["before"]["doubling_slots"])
			before_meshes += int(report[id]["before"]["doubling_procedural_meshes"])
			before_pieces += int(report[id]["before"]["mounted_pieces"])
			before_proc += int(report[id]["before"]["procedural_meshes"])
		if report[id].has("after"):
			after_slots += int(report[id]["after"]["doubling_slots"])
			after_meshes += int(report[id]["after"]["doubling_procedural_meshes"])
			after_pieces += int(report[id]["after"]["mounted_pieces"])
			after_proc += int(report[id]["after"]["procedural_meshes"])
	rows.append("GATE %-28s %-6s doubling_slots before=%d after=%d · doubling_procedural_meshes before=%d after=%d" % [
		"doubling_headline", "PASS" if after_slots == 0 else "FAIL", before_slots, after_slots, before_meshes, after_meshes])
	rows.append("INFO %-28s %-6s mounted_pieces before=%d after=%d · procedural_meshes before=%d after=%d" % [
		"totals", "-", before_pieces, after_pieces, before_proc, after_proc])
	json["doubling_headline"] = {"before_slots": before_slots, "after_slots": after_slots,
		"before_procedural_meshes": before_meshes, "after_procedural_meshes": after_meshes,
		"before_mounted_pieces": before_pieces, "after_mounted_pieces": after_pieces}
	return {"ok": all_ok and after_slots == 0, "rows": rows, "json": json}


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

func _viewport() -> Vector2:
	return Vector2(root.get_visible_rect().size)


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			var rest := a.substr(prefix.length())
			if rest.begins_with("="):
				rest = rest.substr(1)
			return rest
	return fallback


func _ids(args: PackedStringArray) -> Array:
	var raw := _arg(args, "--arena=", "")
	if raw == "":
		return ArenaKit.arenas()
	return Array(raw.split(",", false))


## Every slot of one arena forced OFF, the `before` pass (the test seam: production code
## never sets `suppress_overrides`).
func _all_off(id: String) -> Dictionary:
	var per_slot := {}
	for slot in ArenaKit.slots():
		per_slot[String(slot)] = false
	return {id: per_slot}


func _x_scale() -> float:
	return float(ArenaScenery.band(PRESET, ArenaScenery.BACKDROP_Z)["prop_half_x"]) / ArenaKit.AUTHORED_HALF_X


func _dressing_count(built: Node3D) -> int:
	var scenery := built.get_node_or_null("Scenery")
	if scenery == null:
		return -1
	var count := 0
	for child in scenery.get_children():
		if String(child.name).begins_with("Dressing_"):
			count += 1
	return count


func _dressing_containers(built: Node3D) -> Array:
	var out: Array = []
	var scenery := built.get_node_or_null("Scenery")
	if scenery == null:
		return out
	for child in scenery.get_children():
		if String(child.name).begins_with("Dressing_"):
			out.append(child)
	return out


func _props_authored(id: String) -> int:
	var style := load("res://game/arenas/arena_style.gd")
	return (style.style(id).get("props", []) as Array).size()


func _ok(v: Variant) -> String:
	return "ok" if bool(v) else "BAD"
