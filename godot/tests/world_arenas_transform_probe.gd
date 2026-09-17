## world_arenas_transform_probe.gd — the integrator's diagnostic for the
## field-law RED (not a gate, not a bound). One question, answered with evidence:
##
##   The field-law suite measures `Common.world_aabb()`, which reads
##   `MeshInstance3D.global_transform`. The arenas it measures come from
##   `Arena.build()`, which returns a DETACHED subtree — nothing adds it to the
##   scene tree — and in this build `global_transform` outside the tree is
##   identity, with an engine error per call (399 of them in the failed run:
##   `Condition "!is_inside_tree()" is true. Returning: Transform3D()`). So the
##   suite measured every mesh's RAW LOCAL AABB: the backdrop at its own quad
##   origin (z 0.00), a prop's roof at its own mesh extent (+0.82).
##
## This probe measures the same trees the way the production module's own
## `ArenaScenery.field_law_report()` does — transform walked up the parent chain
## to the arena root — and independently again over TRANSFORMED VERTICES (not
## AABB corners), in the arena's frame. It runs one world arena and one frozen
## arena on purpose: if the arena-frame numbers for the frozen nine are also
## far from the raw-local numbers, the metric was wrong for every arena, and
## the field law itself was never in question.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##     --script res://tests/world_arenas_transform_probe.gd
##
## Output: `# PROBE ...` lines only. Read-only: builds arenas, writes nothing.
extends SceneTree

const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")
const Frozen := preload("res://src/sim/frozen.gd")


func _initialize() -> void:
	var probe_ids: Array = ["torii", String(Frozen.arenas()[0]["id"])]
	for raw_id in probe_ids:
		_probe(String(raw_id))
	quit(0)


func _probe(id: String) -> void:
	print("\n# PROBE === arena '%s' ===" % id)
	var built := Arena.build(id, "default")
	if built == null:
		print("# PROBE arena '%s': build returned null" % id)
		return
	print("# PROBE root=%s family=%s" % [built.name, str(Arena.info(id).get("family", "?"))])

	# 1. What the production module's own field law says (arena frame).
	var law: Array = ArenaScenery.field_law_report(built)
	print("# PROBE module_field_law violations=%d%s" % [
		law.size(), "" if law.is_empty() else " first=%s" % String(law[0])])

	# 2. The scenery walk, per holder: the chain-walked z (arena frame) next to
	#    what a raw `global_transform` would give for the same node (identity).
	var scenery := built.get_node_or_null("Scenery")
	if scenery == null:
		print("# PROBE arena '%s': no Scenery" % id)
		return
	var closest_z := -INF
	var closest_at := ""
	var raw_closest_z := -INF
	var raw_closest_at := ""
	var meshes_walked := 0
	for holder_node in scenery.get_children():
		var holder := holder_node as Node3D
		if holder == null:
			continue
		var holder_z := (_xform_to(holder, built) * Vector3.ZERO).z
		print("# PROBE holder %-18s chain_z=%+8.2f raw_global_z=%+8.2f" % [
			holder.name, holder_z, holder.global_transform.origin.z])
		var walk: Array = [holder]
		walk.append_array(holder.find_children("*", "MeshInstance3D", true, false))
		for node in walk:
			var mi := node as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			meshes_walked += 1
			var xf := _xform_to(mi, built)
			var zr := _vertex_z_range(mi, xf)
			if zr["max"] > closest_z:
				closest_z = float(zr["max"])
				closest_at = "%s/%s" % [holder.name, mi.name]
			# The same mesh through raw `global_transform` (what the failing
			# suite measured) — kept side by side as the evidence pair.
			var aabb: AABB = mi.mesh.get_aabb()
			var raw_end := raw_global_aabb_end(mi, aabb)
			if raw_end > raw_closest_z:
				raw_closest_z = raw_end
				raw_closest_at = "%s/%s" % [holder.name, mi.name]
	print("# PROBE meshes_walked=%d" % meshes_walked)
	print("# PROBE arena '%s' closest transformed VERTEX z=%+.3f at '%s' (law %.1f -> %s)" % [
		id, closest_z, closest_at, -8.0, "PASS" if closest_z <= -8.0 else "FAIL"])
	print("# PROBE arena '%s' closest raw-global AABB z=%+.3f at '%s' (what the failed suite read)" % [
		id, raw_closest_z, raw_closest_at])


## A node's transform in the frame of `ancestor`, walked up the parent chain —
## the same walk the production module's `ArenaScenery._xform_to` does, and for
## the same reason: a detached arena carries its own frame with it.
func _xform_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf


## The arena-frame z range of one mesh, over every vertex of every surface
## (transformed), falling back to the transformed AABB when a surface cannot be
## read. Vertices, not corners: the law wants the closest POINT.
func _vertex_z_range(mi: MeshInstance3D, xf: Transform3D) -> Dictionary:
	var lo := INF
	var hi := -INF
	var any := false
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var z := (xf * v).z
			lo = minf(lo, z)
			hi = maxf(hi, z)
			any = true
	if not any:
		var aabb: AABB = mi.mesh.get_aabb()
		for i in 8:
			var z := (xf * aabb.get_endpoint(i)).z
			lo = minf(lo, z)
			hi = maxf(hi, z)
	return {"min": lo, "max": hi}


## The raw (unwalked) `global_transform` AABB end z — what the failing suite
## computed. Kept here to print the evidence pair, never used as a bound.
func raw_global_aabb_end(mi: MeshInstance3D, aabb: AABB) -> float:
	var xf: Transform3D = mi.global_transform
	var hi := -INF
	for i in 8:
		var z := (xf * aabb.get_endpoint(i)).z
		hi = maxf(hi, z)
	return hi
