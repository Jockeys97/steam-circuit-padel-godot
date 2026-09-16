## arena_probe.gd — build all nine arenas headless and print what each one
## produced, including whether every scenery object lands inside the frame.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://game/tools/arena_probe.gd
##
## It is the fast feedback loop for the arena library (slice S6): the slice test
## asserts the same numbers, this prints them so a wrong prop position is a number
## to read rather than a picture to squint at. The frame check uses the engine's
## own projection (`Camera3D.get_camera_projection()`), the same call the slice test
## makes, so the two cannot disagree.
##
## Exit code 0 when all nine build and every scenery object is fully inside or
## fully outside the frame; 1 otherwise.
extends SceneTree

const Arena := preload("res://game/arenas/arena_library.gd")
const Court := preload("res://game/court.gd")

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_probe()
	return true


func _probe() -> void:
	var failures := 0
	var ids := Arena.ids()
	# The headless window starts at 64x64, which would make every frame check wrong
	# (the projection's aspect comes from the viewport). The renders this slice
	# produces are 1280x720, so the probe checks at that size.
	root.size = Vector2i(1280, 720)
	print("# arena probe · Godot %s · camera default · viewport %s" % [
		Engine.get_version_info().get("string", "?"), str(root.get_visible_rect().size),
	])
	for id in ids:
		var arena := Arena.info(String(id))
		var holder := Node3D.new()
		root.add_child(holder)
		var cam := Court.build_camera(holder, "default")
		var built := Arena.build_into(holder, String(id), "default")
		if built == null:
			print("FAIL %s: build() returned null" % id)
			failures += 1
			root.remove_child(holder)
			holder.free()
			continue
		var meshes := built.find_children("*", "MeshInstance3D", true, false).size()
		var scenery: Node = built.get_node_or_null("Scenery")
		var dressing: Array = []
		var worst := 0.0
		var worst_name := ""
		if scenery != null:
			for child in scenery.get_children():
				if not String(child.name).begins_with("Dressing_"):
					continue
				var bounds := _ndc_bounds(child as Node3D, cam)
				var outside := maxf(maxf(absf(bounds.position.x), absf(bounds.position.y)),
					maxf(absf(bounds.end.x), absf(bounds.end.y)))
				dressing.append("%s[%.2f..%.2f]" % [child.name, bounds.position.x, bounds.end.x])
				if outside > worst:
					worst = outside
					worst_name = String(child.name)
		var backdrop := 0.0
		if scenery != null and scenery.get_node_or_null("Backdrop") != null:
			var b := _ndc_bounds(scenery.get_node("Backdrop") as Node3D, cam)
			backdrop = maxf(absf(b.position.x), absf(b.end.x))
		var band := Arena.band("default", float(arena["backdrop_z"]))
		print("ARENA %-11s family=%-10s wb=%.2f rear_alpha=%.3f meshes=%3d scenery=%2d props=%2d artwork=%-26s band(top=%.2f half_x=%.2f) dressing_worst=%.3f (%s) backdrop_x=%.2f" % [
			String(id), String(arena["family"]), float(arena["wallBounce"]), float(arena["rear_alpha"]),
			meshes, scenery.get_child_count() if scenery != null else -1, Arena.prop_kinds(String(id)).size(),
			"artwork" if scenery != null and bool(scenery.get_meta("artwork")) else "gradient-only",
			float(band["top"]), float(band["half_x"]), worst, worst_name, backdrop,
		])
		if meshes < 60:
			print("FAIL %s: only %d meshes" % [id, meshes])
			failures += 1
		if worst > 1.0:
			print("FAIL %s: %s leaves the frame (ndc %.3f)" % [id, worst_name, worst])
			failures += 1
		if scenery == null or scenery.get_child_count() < 2:
			print("FAIL %s: no scenery" % id)
			failures += 1
		root.remove_child(holder)
		holder.free()
	print("PROBE %s built=%d failed=%d" % ["OK" if failures == 0 else "FAIL", ids.size(), failures])
	quit(0 if failures == 0 else 1)


## The screen-space bounds (NDC, -1..1 = the frame) of every mesh under `node`,
## using the engine's own view-projection matrix.
func _ndc_bounds(node: Node3D, cam: Camera3D) -> Rect2:
	var view := cam.global_transform.affine_inverse()
	var proj := cam.get_camera_projection()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var meshes: Array = [node]
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		if mi is not MeshInstance3D:
			continue
		var aabb: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		var xform: Transform3D = (mi as MeshInstance3D).global_transform
		for i in 8:
			var corner: Vector3 = xform * aabb.get_endpoint(i)
			var view_pos := view * corner
			var clip: Vector4 = proj * Vector4(view_pos.x, view_pos.y, view_pos.z, 1.0)
			if absf(clip.w) < 0.000001:
				continue
			var ndc := Vector2(clip.x / clip.w, clip.y / clip.w)
			lo.x = minf(lo.x, ndc.x)
			lo.y = minf(lo.y, ndc.y)
			hi.x = maxf(hi.x, ndc.x)
			hi.y = maxf(hi.y, ndc.y)
	if lo.x == INF:
		return Rect2(0, 0, 0, 0)
	return Rect2(lo, hi - lo)
