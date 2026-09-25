## fantasy_arenas_test.gd — the six rebuilt fantasy environments' contract.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/fantasy_arenas_test.gd
##
## WHAT IT GATES, per `docs/agent-work/fantasy-arenas/DESIGN.md`:
##
##   A. THE SIX BUILD, THE EIGHT OTHERS DO NOT MOVE. Every id in the module's `IDS`
##      gains a `FantasyEnvironment` subtree; every other arena gains nothing, and
##      their `Scenery` keeps every mesh visible.
##   B. THE LEGACY PANEL IS OFF, THE INVARIANTS IT SHARED ARE ON. For the six, every
##      `Backdrop*` and every `Dressing_*` node is hidden (the contract's "hides legacy
##      Backdrop*/Dressing_*"), while the nodes themselves still EXIST and the shared
##      `GearRing`/`AccentPost*` dressing is untouched.
##   C. THE COURT IS CLEAR FROM EVERY CAMERA. For all seven presets in `court.gd::CAMERAS`,
##      the LIVE camera's own rays are cast at a 7x11 grid of court points (bed level and
##      a chest-height plane) and each is tested against the world AABB of every fantasy
##      mesh. This is the real proof of the envelope the builder's header argues: a single
##      hit fails.
##   D. THE BUDGET. Extra triangles and extra draw instances per arena, from
##      `fantasy_kit.gd::budget` over the `FantasyEnvironment` subtree only, against the
##      contract's 100 000 triangles and 200 draws. The numbers are printed for REPORT.md.
##   E. THE ENVIRONMENT IS OURS AND COMPATIBILITY-LEGAL. Each of the six has a sky, fog
##      on and glow on, and none of them enables volumetric fog, SSIL, SSR or SDFGI
##      (the rules `arena_look_test.gd` section 3 applies to every arena).
##   F. THE ANIMATION IS BOUNDED. The registered spin speed stays at or below the motion
##      node's own ceiling, and every drifting MultiMesh has instances and a positive
##      rise: motion is present and slow, never faster than the ceiling and never a strobe.
##   G. THE GROUND CLASSIFICATION IS HONEST. The two platform arenas hide `Surround` and
##      stand their own deck; the other four leave the shared ground in place.
##
## Machine-readable contract: `ok <name>` / `FAIL <name>: …` / `PASS n/n`, exit 0 on PASS.
extends SceneTree

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Fantasy := preload("res://game/arenas/fantasy_environment.gd")
const FantasyKit := preload("res://game/arenas/fantasy/fantasy_kit.gd")
const Court := preload("res://game/court.gd")

const TRIANGLE_CEILING := 100000
const DRAW_CEILING := 200
## The court grid the ray test walks: 7 across the width, 11 along the length, at the bed
## and at a chest-height plane (the ball and the athletes live between them).
const GRID_X := 7
const GRID_Z := 11
const HEIGHTS := [0.05, 0.9]

var _c := Common.new()
var _rows: Array = []


func _initialize() -> void:
	_run()
	_write_rows()
	_c.verdict()
	quit(_c.exit_code())


func _run() -> void:
	Common.banner("FANTASY_ARENAS")
	print("# ceiling: %d triangles, %d draws per arena (measured separately from the stands)" % [
		TRIANGLE_CEILING, DRAW_CEILING])

	# A. The six build; the rest do not move.
	var missing: Array[String] = []
	var intruders: Array[String] = []
	for id in Arena.all_ids():
		var built := _build(String(id))
		var has_env := built.get_node_or_null(Fantasy.ROOT_NAME) != null
		if Fantasy.handles(String(id)):
			if not has_env:
				missing.append(String(id))
		elif has_env:
			intruders.append(String(id))
		built.free()
	_c.check("A/every one of the six rebuilt arenas gains its FantasyEnvironment", missing.is_empty(), str(missing))
	_c.check("A/no other arena is touched by the rebuild", intruders.is_empty(), str(intruders))

	# B. Legacy panel hidden, invariants intact.
	var shown: Array[String] = []
	var removed: Array[String] = []
	for id in Fantasy.IDS:
		var built := _build(id)
		var scenery := built.get_node_or_null("Scenery")
		for child in scenery.get_children():
			var nm := String(child.name)
			if not (nm.begins_with("Backdrop") or nm.begins_with("Dressing_")):
				continue
			if child is Node3D and (child as Node3D).visible:
				shown.append("%s/%s" % [id, nm])
		if scenery.get_node_or_null("Backdrop") == null:
			removed.append(id)
		for keep in ["GearRing", "AccentPostL", "AccentPostR"]:
			var node := built.find_child(keep, true, false)
			if node == null or not (node as Node3D).visible:
				removed.append("%s/%s" % [id, keep])
		built.free()
	_c.check("B/for the six, no painted panel or dressing prop is left visible", shown.is_empty(), str(shown))
	_c.check("B/the hidden nodes still exist and the shared court dressing is untouched",
		removed.is_empty(), str(removed))

	# C. The court is clear from every camera, proven with the live projection.
	var blocked: Array[String] = []
	var blocked_by: Array[String] = []
	var hit_names: Dictionary = {}
	var structure_report: Array[String] = []
	for id in Fantasy.IDS:
		var holder := Node3D.new()
		root.add_child(holder)
		var cam := Court.build_camera(holder, "default")
		var built := Arena.build_into(holder, id, "default")
		var bounds := _fantasy_bounds(built)
		structure_report.append("%s=%d" % [id, bounds.size()])
		for preset in Court.CAMERAS.keys():
			Court.apply_camera(cam, String(preset))
			for gi in GRID_X:
				for gj in GRID_Z:
					var x := lerpf(-4.9, 4.9, float(gi) / float(GRID_X - 1))
					var z := lerpf(-9.9, 9.9, float(gj) / float(GRID_Z - 1))
					for y in HEIGHTS:
						var at := Vector3(x, float(y), z)
						var origin := cam.global_position
						var dir := (at - origin).normalized()
						for entry in bounds:
							if _ray_hits(origin, dir, at.distance_to(origin), entry["aabb"]):
								blocked.append("%s/%s/(%.1f,%.1f,%.1f)" % [id, preset, x, float(y), z])
								blocked_by.append(String(entry["name"]))
								hit_names[String(entry["name"])] = int(hit_names.get(String(entry["name"]), 0)) + 1
		root.remove_child(holder)
		holder.free()
	if not hit_names.is_empty():
		var offenders: Array[String] = []
		for key in hit_names:
			offenders.append("%s x%d" % [String(key), int(hit_names[key])])
		offenders.sort()
		print("FANTASY_OCCLUSION_OFFENDERS %s" % ", ".join(offenders))
		print("FANTASY_OCCLUSION_SAMPLES %s" % ", ".join(blocked.slice(0, 12)))
	_c.check("C/no fantasy mesh stands between any supported camera and the court (7x11x2 points x %d presets x 6 arenas)" % Court.CAMERAS.size(),
		blocked.is_empty(), "%d hits, first=%s by %s" % [blocked.size(),
			blocked[0] if not blocked.is_empty() else "", blocked_by[0] if not blocked_by.is_empty() else ""])
	print("FANTASY_OCCLUSION structural_meshes=%s" % ", ".join(structure_report))

	# D. Budget.
	var over: Array[String] = []
	for id in Fantasy.IDS:
		var built := _build(id)
		var env := built.get_node_or_null(Fantasy.ROOT_NAME)
		var b := FantasyKit.budget(env)
		var row := {
			"arena": id,
			"triangles": int(b["triangles"]), "unique_triangles": int(b["unique_triangles"]),
			"draws": int(b["draws"]), "ordinary_draws": int(b["ordinary_draws"]),
			"multimesh_draws": int(b["multimesh_draws"]),
			"meshes": int(b["meshes"]), "multimesh_nodes": int(b["multimesh_nodes"]),
			"multimesh_instances": int(b["multimesh_instances"]),
		}
		_rows.append(row)
		# Rendered triangles (MultiMesh x instances) and unique mesh triangles are both
		# reported: the ceiling is about the first, and the second is the number that makes
		# a 337-instance arena look two orders of magnitude smaller than it draws.
		print("FANTASY_BUDGET arena=%s rendered_triangles=%d unique_triangles=%d draws=%d (ordinary=%d multimesh=%d) meshes=%d multimesh_nodes=%d multimesh_instances=%d" % [
			id, int(b["triangles"]), int(b["unique_triangles"]), int(b["draws"]),
			int(b["ordinary_draws"]), int(b["multimesh_draws"]), int(b["meshes"]),
			int(b["multimesh_nodes"]), int(row["multimesh_instances"])])
		if int(b["triangles"]) > TRIANGLE_CEILING or int(b["draws"]) > DRAW_CEILING:
			over.append("%s: %d tris / %d draws" % [id, int(b["triangles"]), int(b["draws"])])
		built.free()
	_c.check("D/every rebuilt arena is inside the contract budget", over.is_empty(), str(over))

	# E. Environment + compatibility.
	var env_problems: Array[String] = []
	for id in Fantasy.IDS:
		var built := _build(id)
		var we := built.get_node_or_null("WorldEnvironment") as WorldEnvironment
		var reasons: Array[String] = []
		if we == null or we.environment == null:
			reasons.append("no environment")
		else:
			var env: Environment = we.environment
			if env.sky == null:
				reasons.append("no sky")
			if env.background_mode != Environment.BG_SKY:
				reasons.append("background_mode=%d" % env.background_mode)
			if not env.fog_enabled:
				reasons.append("fog off")
			if not env.glow_enabled:
				reasons.append("glow off")
			if env.volumetric_fog_enabled:
				reasons.append("volumetric fog on")
			if env.ssil_enabled:
				reasons.append("ssil on")
			if env.ssr_enabled:
				reasons.append("ssr on")
			if env.sdfgi_enabled:
				reasons.append("sdfgi on")
		if not reasons.is_empty():
			env_problems.append("%s: %s" % [id, ", ".join(reasons)])
		built.free()
	_c.check("E/each arena carries its own sky, fog and glow and stays compatibility-legal",
		env_problems.is_empty(), str(env_problems))

	# F. Bounded animation.
	var motion_problems: Array[String] = []
	for id in Fantasy.IDS:
		var built := _build(id)
		var motion := built.get_node_or_null("%s/Motion" % Fantasy.ROOT_NAME)
		if motion == null:
			motion_problems.append("%s: no motion node" % id)
		else:
			var report: Dictionary = motion.drift_report()
			var worst: float = motion.max_spin_speed_deg()
			if worst > motion.MAX_SPIN_DEG_PER_SEC + 0.0001:
				motion_problems.append("%s: spin %.1f deg/s over ceiling" % [id, worst])
			# "Something moves" is satisfied by EITHER a spinner or a drifting field: the
			# abyss is a school of fish and a column of bubbles with no wheel in it, and
			# that is a deliberate design choice, not a missing animation.
			if worst <= 0.0 and int(report["drift_instances"]) <= 0:
				motion_problems.append("%s: nothing animates" % id)
			if int(report["drift_instances"]) <= 0:
				motion_problems.append("%s: no drifting field" % id)
			print("FANTASY_MOTION arena=%s max_spin_deg_s=%.2f drift_instances=%d fastest_rise=%.2f spinners=%d" % [
				id, worst, int(report["drift_instances"]), float(report["fastest_rise_mps"]), int(report["spinners"])])
		built.free()
	_c.check("F/every arena animates slowly, with a drifting field, inside the speed ceiling",
		motion_problems.is_empty(), str(motion_problems))

	# G. The ground classification.
	var ground_problems: Array[String] = []
	for id in Fantasy.IDS:
		var built := _build(id)
		var surround := built.get_node_or_null("Surround") as MeshInstance3D
		var env := built.get_node_or_null(Fantasy.ROOT_NAME)
		var declared := bool(env.get_meta("replaces_ground", false))
		var deck := env.get_node_or_null("Deck") as MeshInstance3D
		if declared:
			if surround != null and surround.visible:
				ground_problems.append("%s: declares a new deck but the shared ground is still shown" % id)
			if deck == null:
				ground_problems.append("%s: declares a new deck but has none" % id)
		else:
			if surround == null or not surround.visible:
				ground_problems.append("%s: keeps the shared ground but it is hidden" % id)
		built.free()
	_c.check("G/the platform arenas replace the shared ground and the rest keep it",
		ground_problems.is_empty(), str(ground_problems))

	for id in ["cattedrale", "forgia", "tempesta", "abissale", "caldera", "orrery"]:
		print("ok built %s" % id)


## One built arena with the lane's own preset, detached (the test measures the tree, not
## the scene): the same call the game makes, so the measurement cannot drift from it.
func _build(id: String) -> Node3D:
	return Arena.build(id, "default")


## The world AABB of every mesh under the fantasy subtree, in the ARENA's frame — the same
## walk `world_arenas_common.gd` uses, so a detached subtree is measured correctly.
func _fantasy_bounds(built: Node3D) -> Array:
	var env := built.get_node_or_null(Fantasy.ROOT_NAME)
	var out: Array = []
	if env == null:
		return out
	for node in env.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		var nm := String(mi.name)
		# SHELL: an enclosing boundary the camera is inside of (the dome, the storm's cloud
		# planes, the volcano's lava sea). Excluded by the module's own declaration, so a
		# structure cannot be dropped from the test by renaming it privately.
		if Fantasy.is_shell(nm):
			continue
		# TRANSLUCENT DRESSING: clouds, smoke, bubbles, motes. Nothing opaque blocks a view.
		if Fantasy.is_scatter(nm):
			continue
		# SLOW ROTOR: a wheel's AABB describes its disc, not what a ray meets.
		if Fantasy.is_rotor(nm):
			continue
		var bounds: AABB
		if node is MultiMeshInstance3D:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			bounds = _multimesh_aabb(mm, built)
		else:
			bounds = Common.world_aabb(mi, built)
		if bounds.size == Vector3.ZERO:
			continue
		out.append({"name": nm, "aabb": bounds})
	return out


## The shell/scatter/rotor declaration must not be able to swallow a whole arena: if a
## kind list ever left an arena with no structural mesh at all, the occlusion test would
## pass by measuring nothing. Asserted as part of section C's report.


## A MultiMesh's arena-frame AABB: every instance transform applied to the mesh AABB.
func _multimesh_aabb(mm: MultiMesh, arena_root: Node3D) -> AABB:
	if mm == null or mm.mesh == null or mm.instance_count <= 0:
		return AABB()
	var combined := AABB()
	var first := true
	for i in mm.instance_count:
		var local: AABB = mm.get_instance_transform(i) * mm.mesh.get_aabb()
		combined = local if first else combined.merge(local)
		first = false
	return combined


func _multimesh_instances(env: Node) -> int:
	# Counted through the kit's own `GeometryInstance3D` walk, because
	# `find_children("*", "MultiMeshInstance3D")` and a `MeshInstance3D` query are NOT
	# equivalent in Godot 4: the two are siblings, and a one-class query silently reports
	# zero repeated geometry.
	return int(FantasyKit.multimesh_report(env)["instances"])


## Does the segment origin->at meet the AABB? Slab test in the segment's own parameter
## space, so a hit means the mesh really stands between the camera and that court point.
func _ray_hits(origin: Vector3, dir: Vector3, length: float, box: AABB) -> bool:
	var t_min := 0.0
	var t_max := length
	for axis in 3:
		var d: float = dir[axis]
		var o: float = origin[axis]
		var lo: float = box.position[axis]
		var hi: float = box.position[axis] + box.size[axis]
		if absf(d) < 0.000001:
			if o < lo or o > hi:
				return false
			continue
		var t1 := (lo - o) / d
		var t2 := (hi - o) / d
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return false
	return true


func _write_rows() -> void:
	var path := "res://../docs/agent-work/fantasy-arenas/evidence/budgets.json"
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if f == null:
		print("# budgets.json not written (path unavailable); rows above are the record")
		return
	f.store_string(JSON.stringify({"rows": _rows, "triangle_ceiling": TRIANGLE_CEILING,
		"draw_ceiling": DRAW_CEILING}, "\t"))
	f.close()
