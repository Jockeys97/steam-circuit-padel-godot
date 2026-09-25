extends SceneTree
## "Orrery Celeste" (`game/arenas/celestial_orrery.gd`): presentation only. It must stay out of
## the playing volume, add no light nodes and no colliders, keep the arena's physics, mount
## the owner's three Meshy props, and set its nebula sky.
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
	Config.save_dir = "user://orrery-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("orrery")
	root.add_child(arena)
	var f = arena.get_node_or_null("Scenery/CelestialOrrery")
	check(f != null,"orrery scene mounted")
	check(f.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(f.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("orrery").wallBounce)),"physics retained")
	check(f.get_node_or_null("Orrery") != null,"the giant orrery")
	check(f.find_children("Telescope*","",false,false).size() == 4,"four telescopes")
	check(f.find_children("Armillary*","",false,false).size() == 8,"eight armillary lamps")
	check(f.find_children("Planet*","",false,false).size() == 5,"five planets")
	var rails := f.find_children("Rail*","",false,false)
	check(rails.size() >= 20,"railing along the deck edge (%d)" % rails.size())
	var near := 0
	for r in rails:
		if (r as Node3D).position.z > 15.0: near += 1
	check(near == 0,"no railing in front of the cameras (%d)" % near)
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY,"nebula sky set")
	var surround := arena.get_node_or_null("Surround") as Node3D
	check(surround == null or not surround.visible,"the platform floats: no ground plane")
	var deck := f.get_node_or_null("Deck") as MeshInstance3D
	check(deck != null and deck.position.y + deck.scale.y * 0.5 < 0.0,"deck top below the court floor")
	var tris := 0
	for mi in f.find_children("*","MeshInstance3D",true,false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m is ArrayMesh:
			for si in m.get_surface_count():
				tris += (m as ArrayMesh).surface_get_array_index_len(si) / 3
	check(tris < 400000,"triangle budget (%d)" % tris)
	var inside := 0
	for mi in f.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5:
				inside += 1
	for n in f.get_children():
		if n is Node3D and not (n is MultiMeshInstance3D) and not (n is CPUParticles3D) and not String(n.name).begins_with("Deck") and not String(n.name).begins_with("OrbitRing"):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x) < 6.0 and absf(p.z) < 11.0: inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	print("CELESTIAL_ORRERY triangles=%d " % tris,checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
