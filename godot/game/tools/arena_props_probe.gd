extends SceneTree
## Measures where the arena's furniture actually ENDS UP, in world metres, and says
## plainly whether any of it intersects the glass cage, the stands, or another copy.
##
## WHY THIS EXISTS. A screenshot can only suggest that a canopy crosses a glass
## panel; the eye cannot tell a 5 cm overlap from a 5 cm gap at 30 m, and a review
## that guesses sends the placement round the loop twice. This prints the AABBs and
## the clearances, so "it clips" becomes a signed number.
##
##   godot --headless --path godot/ --script res://game/tools/arena_props_probe.gd

const Court := preload("res://game/court.gd")
const Bleachers := preload("res://game/arenas/bleachers.gd")
const ArenaProps := preload("res://game/arenas/arena_props.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)

	Bleachers.build(root)
	ArenaProps.build(root)

	# Transforms propagate on the frame AFTER the nodes enter the tree: measuring
	# straight after `build()` reads every global_transform as identity and reports
	# nine boxes stacked on the origin. Wait one frame, then measure.
	await process_frame
	await process_frame

	var glass_x: float = Court.half_len()
	var glass_z: float = Court.half_depth()
	var glass_h: float = Court.GLASS_H
	print("CAGE glass_x=%.3f glass_z=%.3f glass_h=%.3f court_w=%.2f" % [
		glass_x, glass_z, glass_h, Court.WIDTH_M])

	# Every placed unit, as a world-space box.
	var units: Array = []
	for group_name in ["Bleachers", "ArenaProps"]:
		var group: Node = root.get_node_or_null(group_name)
		if group == null:
			continue
		for child in group.get_children():
			var stack := child as Node3D
			if stack == null:
				continue
			var box := _world_box(stack)
			units.append({"name": stack.name, "box": box})
			print("UNIT %-16s x=[%7.3f,%7.3f] y=[%6.3f,%6.3f] z=[%7.3f,%7.3f] w=%.2f d=%.2f h=%.2f" % [
				stack.name, box.position.x, box.end.x, box.position.y, box.end.y,
				box.position.z, box.end.z, box.size.x, box.size.z, box.size.y])

	# 1. Does anything cross the cage? The cage is the box the glass encloses; a prop
	#    outside it must keep its whole footprint outside, on the axis it stands on.
	var worst := 1e9
	var offender := ""
	for u in units:
		var box: AABB = u["box"]
		var clear_x: float = 0.0
		if box.position.x > 0.0:
			clear_x = box.position.x - glass_x      # right side: nearest face to the cage
		elif box.end.x < 0.0:
			clear_x = -glass_x - box.end.x          # left side
		else:
			clear_x = -1.0                          # straddles the court's centre line
		var clear_z: float = 0.0
		if box.end.z < 0.0:
			clear_z = -glass_z - box.end.z
		elif box.position.z > 0.0:
			clear_z = box.position.z - glass_z
		else:
			clear_z = -1.0
		# A unit clears the cage if it is clear on EITHER axis (side props clear in x,
		# rear props clear in z).
		var clear: float = maxf(clear_x, clear_z)
		print("CAGE_CLEARANCE %-16s clear_x=%7.3f clear_z=%7.3f -> %7.3f %s" % [
			u["name"], clear_x, clear_z, clear, "OK" if clear >= 0.0 else "INTERSECTS"])
		if clear < worst:
			worst = clear
			offender = u["name"]
	print("CAGE_WORST unit=%s clearance=%.3f %s" % [
		offender, worst, "OK" if worst >= 0.0 else "FAIL"])

	# 2. Do any two units interpenetrate? Touching is fine, overlapping is not.
	var overlaps := 0
	for i in range(units.size()):
		for j in range(i + 1, units.size()):
			var a: AABB = units[i]["box"]
			var b: AABB = units[j]["box"]
			var dx: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
			var dy: float = minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
			var dz: float = minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
			if dx > 0.001 and dy > 0.001 and dz > 0.001:
				overlaps += 1
				print("OVERLAP %s <-> %s by (%.3f, %.3f, %.3f) m" % [
					units[i]["name"], units[j]["name"], dx, dy, dz])
	print("OVERLAPS count=%d %s" % [overlaps, "OK" if overlaps == 0 else "FAIL"])

	# 3. Is everything standing ON the floor? A unit whose min y is far off zero is
	#    either floating or sunk.
	var worst_y := 0.0
	var y_offender := ""
	for u in units:
		var box: AABB = u["box"]
		if absf(box.position.y) > absf(worst_y):
			worst_y = box.position.y
			y_offender = u["name"]
	print("GROUND worst unit=%s min_y=%.4f %s" % [
		y_offender, worst_y, "OK" if absf(worst_y) <= 0.05 else "FAIL"])

	# 4. Do the side props stay under the glass? Taller than the cage and they stop
	#    reading as furniture behind it.
	var tallest := 0.0
	var tall_name := ""
	for u in units:
		if String(u["name"]).begins_with("Shelter"):
			var h: float = (u["box"] as AABB).end.y
			if h > tallest:
				tallest = h
				tall_name = u["name"]
	print("SHELTER_HEIGHT tallest=%s h=%.3f glass_h=%.3f %s" % [
		tall_name, tallest, glass_h, "OK" if tallest <= glass_h else "OVER_GLASS"])

	quit(0)


## A node's world-space box, merged over every mesh under it.
func _world_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mi as MeshInstance3D
		if instance.mesh == null:
			continue
		var b: AABB = instance.global_transform * instance.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
