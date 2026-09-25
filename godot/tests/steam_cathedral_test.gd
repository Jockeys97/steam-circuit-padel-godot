extends SceneTree
## "Cattedrale di Vapore" (`game/arenas/steam_cathedral.gd`): presentation only. It must stay out of
## the playing volume, add no light nodes and no colliders, keep the arena's physics, mount
## the owner's three Meshy props, and set its own sky.
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
	Config.save_dir = "user://cattedrale-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("cattedrale")
	root.add_child(arena)
	var f = arena.get_node_or_null("Scenery/SteamCathedral")
	check(f != null,"cathedral scene mounted")
	check(f.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(f.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("cattedrale").wallBounce)),"physics retained")
	check(f.get_node_or_null("Reliquary") != null,"the reliquary under the rose window")
	check(f.find_children("Column*","",false,false).size() == 10,"ten nave columns")
	check(f.find_children("Candelabrum*","",false,false).size() == 8,"eight candelabra")
	check(f.find_children("Chandelier*","",false,false).size() == 6,"six chandeliers")
	check(f.get_node_or_null("RoseWindow") != null,"rose window")
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY,"own sky set")
	# The broadcast camera sits in the aisle at (19, 22, 25): nothing may stand between it
	# and the court's centre.
	var from := Vector3(19, 22, 25)
	var blocked := 0
	for n in f.get_children():
		if n is Node3D and String(n.name).begins_with("Column"):
			var p: Vector3 = (n as Node3D).global_position
			var t := clampf((p - from).dot(-from) / from.length_squared(), 0.0, 1.0)
			var q := from.lerp(Vector3.ZERO, t)
			if Vector2(q.x - p.x, q.z - p.z).length() < 2.0 and q.y < 15.5: blocked += 1
	check(blocked == 0,"the broadcast camera sees the court (%d)" % blocked)
	var inside := 0
	for mi in f.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5:
				inside += 1
	for n in f.get_children():
		if n is Node3D and not (n is MultiMeshInstance3D) and not (n is CPUParticles3D) and not String(n.name).begins_with("RoseWindow"):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x) < 6.0 and absf(p.z) < 11.0: inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	print("STEAM_CATHEDRAL ",checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
