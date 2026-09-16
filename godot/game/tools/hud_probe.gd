## hud_probe.gd — the two layout facts the slice test asserts, printed raw.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://game/tools/hud_probe.gd
##
## Prints:
##   1. every HUD panel's anchors, offsets, minimum size and the rectangle it
##      occupies at 1280x720 and 1152x648 (the safe-area contract);
##   2. the camera's projection matrix and one scenery object's normalized device
##      coordinates (the "is the arena inside the frame" contract) — because a
##      degenerate projection silently reads as "everything is inside 0..0".
## Runs inside a frame, not in `_initialize()`: a node added to the tree before the
## first frame is not inside it yet, so `get_camera_projection()` returns a default
## matrix and every screen-space measurement silently reads zero.
extends SceneTree

const Court := preload("res://game/court.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Hud := preload("res://game/hud.gd")


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_probe()
	return true


var _ran := false


func _run_probe() -> void:
	root.size = Vector2i(1280, 720)
	print("root.size=%s visible=%s" % [str(root.size), str(root.get_visible_rect().size)])

	var holder := Node3D.new()
	root.add_child(holder)
	var cam := Court.build_camera(holder, "default")
	var built := Arena.build_into(holder, "officina", "default")
	var proj := cam.get_camera_projection()
	print("camera in_tree=%s global_origin=%s proj.x=%s proj.w=%s" % [
		str(cam.is_inside_tree()), str(cam.global_position), str(proj.x), str(proj.w)])
	if built != null:
		var scenery := built.get_node_or_null("Scenery")
		print("scenery=%s children=%d" % [str(scenery), scenery.get_child_count() if scenery != null else -1])
		if scenery != null:
			var backdrop := scenery.get_node_or_null("Backdrop")
			print("backdrop is MeshInstance3D=%s" % str(backdrop is MeshInstance3D))
			for child in scenery.get_children():
				var ndc := ndc_bounds(child as Node3D, cam)
				print("  %-28s ndc x %.3f..%.3f y %.3f..%.3f" % [child.name, ndc.position.x, ndc.end.x, ndc.position.y, ndc.end.y])

	var hud := Hud.new()
	hud.name = "Hud"
	root.add_child(hud)
	print("hud panels=%d" % hud.panels().size())
	for frame: Vector2 in [Vector2(1280.0, 720.0), Vector2(1152.0, 648.0)]:
		print("-- frame %.0fx%.0f" % [frame.x, frame.y])
		for panel in hud.panels():
			var p := panel as Control
			var r: Rect2 = Hud.panel_rect(p, frame)
			print("  %-14s anchors (%.1f,%.1f)-(%.1f,%.1f) offsets (%.0f,%.0f)-(%.0f,%.0f) min (%.0f,%.0f) rect %s" % [
				p.name, p.anchor_left, p.anchor_top, p.anchor_right, p.anchor_bottom,
				p.offset_left, p.offset_top, p.offset_right, p.offset_bottom,
				p.get_combined_minimum_size().x, p.get_combined_minimum_size().y, str(r)])
	quit(0)


func ndc_bounds(node: Node3D, cam: Camera3D) -> Rect2:
	var view := cam.global_transform.affine_inverse()
	var proj := cam.get_camera_projection()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		for i in 8:
			var corner := (mi as MeshInstance3D).global_transform * aabb.get_endpoint(i)
			var view_pos := view * corner
			var clip: Vector4 = proj * Vector4(view_pos.x, view_pos.y, view_pos.z, 1.0)
			if is_zero_approx(clip.w) or clip.w < 0.0:
				continue
			var ndc := Vector2(clip.x / clip.w, clip.y / clip.w)
			lo.x = minf(lo.x, ndc.x)
			lo.y = minf(lo.y, ndc.y)
			hi.x = maxf(hi.x, ndc.x)
			hi.y = maxf(hi.y, ndc.y)
	if lo.x == INF:
		return Rect2(0.0, 0.0, 0.0, 0.0)
	return Rect2(lo, hi - lo)
