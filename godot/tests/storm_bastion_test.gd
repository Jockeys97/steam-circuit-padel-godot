extends SceneTree
## "Bastione della Tempesta" (`game/arenas/storm_bastion.gd`): presentation only. It must stay out
## of the playing volume, add no light nodes and no colliders, keep the arena's physics, mount
## (the deck itself lies under the court floor, so only pieces above the floor count) the owner's three Meshy props, and set its storm sky.
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
	Config.save_dir = "user://tempesta-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("tempesta")
	root.add_child(arena)
	var c = arena.get_node_or_null("Scenery/StormBastion")
	check(c != null,"storm deck mounted")
	check(c.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(c.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("tempesta").wallBounce)),"physics retained")
	check(c.find_children("Airship*","",false,false).size() == 3,"three airships")
	check(c.find_children("Tower*","",false,false).size() == 4,"four lightning towers")
	check(c.find_children("Lantern*","",false,false).size() == 8,"eight lanterns")
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY,"storm sky set")
	var inside := 0
	for mi in c.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.y > 0.02 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5 and box.size.x < 100.0:
				inside += 1
	for n in c.get_children():
		if n is Node3D and (String(n.name).begins_with("Airship") or String(n.name).begins_with("Tower") or String(n.name).begins_with("Lantern")):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x) < 10.0 and absf(p.z) < 13.0: inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	print("STORM_BASTION ",checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
