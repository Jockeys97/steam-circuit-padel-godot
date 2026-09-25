extends SceneTree
## "Sopraelevata della Luna" (`game/arenas/moonlit_highway.gd`): the rebuilt `locomotive`
## arena. Presentation only: it must stay out of the playing volume, add no light nodes and
## no colliders, keep its cost bounded, keep the arena's physics, set a night sky, and move
## its traffic along the skyway.
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
	Config.save_dir = "user://moonlit-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("locomotive")
	root.add_child(arena)
	var hw = arena.get_node_or_null("Scenery/MoonlitHighway")
	check(hw != null,"skyway mounted in the locomotive arena")
	check(arena.get_node_or_null("Scenery/LocomotiveDepot") == null,"old depot hall gone")
	check(hw.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(hw.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("locomotive").wallBounce)),"physics retained")
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY and we.environment.sky != null,"night sky set")
	# Nothing of the skyway inside the court volume (|x| < 5.5 and |z| < 10.5, below 6 m).
	var inside := 0
	var triangles := 0
	for mi in hw.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		triangles += mm.mesh.get_faces().size()/3*mm.instance_count
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5 and box.size.x < 300.0:
				inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	check(triangles < 60000,"bounded static cost (%d triangles)" % triangles)
	check(hw.cars.size() == 8,"eight cars on the skyway")
	var before: Vector3 = hw.cars[0].position
	hw._process(0.5)
	check(before.distance_to(hw.cars[0].position) > 5.0,"traffic moves")
	var off := 0
	for car in hw.cars:
		if absf(car.position.y - 3.6) > 0.2: off += 1
	check(off == 0,"cars ride on the deck")
	print("MOONLIT_HIGHWAY triangles=",triangles," ",checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
