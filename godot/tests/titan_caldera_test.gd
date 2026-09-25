extends SceneTree
## "Caldera del Titano" (`game/arenas/titan_caldera.gd`): presentation only. It must stay out
## of the playing volume, add no light nodes and no colliders, keep the arena's physics, mount
## the owner's three Meshy props, and set its ember sky.
const Arena = preload("res://game/arenas/arena_library.gd")
const Config = preload("res://game/match_config.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _initialize(): call_deferred("run")
func run():
	if DisplayServer.get_name() == "headless":
		printerr("Native renderer required: the headless server keeps no MultiMesh transforms")
		quit(1)
		return
	Config.save_dir = "user://caldera-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("caldera")
	root.add_child(arena)
	var c = arena.get_node_or_null("Scenery/TitanCaldera")
	check(c != null,"caldera scene mounted")
	check(c.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(c.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("caldera").wallBounce)),"physics retained")
	check(c.get_node_or_null("Titan") != null and c.get_node_or_null("Titan2") != null or c.find_children("Titan*","",false,false).size() == 2,"two titans")
	check(c.find_children("Chimney*","",false,false).size() == 8,"eight chimneys")
	check(c.find_children("Lantern*","",false,false).size() == 8,"eight lanterns")
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY,"ember sky set")
	var inside := 0
	for mi in c.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5 and box.size.x < 100.0:
				inside += 1
	for n in c.get_children():
		if n is Node3D and (String(n.name).begins_with("Titan") or String(n.name).begins_with("Chimney") or String(n.name).begins_with("Lantern")):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x) < 10.0 and absf(p.z) < 13.0: inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	print("TITAN_CALDERA ",checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
