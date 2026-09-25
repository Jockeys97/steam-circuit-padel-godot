extends SceneTree
## "Santuario Abissale" (`game/arenas/abyssal_sanctuary.gd`): presentation only. It must stay out of
## the playing volume, add no light nodes and no colliders, keep the arena's physics, mount
## the owner's three Meshy props, and set its ocean sky.
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
	Config.save_dir = "user://abissale-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("abissale")
	root.add_child(arena)
	var f = arena.get_node_or_null("Scenery/AbyssalSanctuary")
	check(f != null,"sanctuary scene mounted")
	check(f.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(f.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("abissale").wallBounce)),"physics retained")
	check(f.find_children("Temple*","",false,false).size() == 3,"three temple towers")
	check(f.find_children("Whale*","",false,false).size() == 2,"two whale monuments")
	check(f.find_children("JellyLamp*","",false,false).size() == 8,"eight jellyfish lamps")
	check(f.find_children("Kelp*","",false,false).size() >= 8,"kelp around the dome")
	check(f.find_children("Jellyfish*","",false,false).size() == 14,"fourteen drifting jellyfish")
	# Nothing stands over the court: the gameplay camera looks straight down on it.
	var over := 0
	for mi in f.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.end.x > -5.0 and box.position.x < 5.0 and box.end.z > -10.0 and box.position.z < 10.0:
				over += 1
	check(over == 0,"no rib or ring over the court (%d)" % over)
	# The jellyfish drift on the far side, never in front of the high cameras.
	var near := 0
	for j in f.find_children("Jellyfish*","",false,false):
		if (j as Node3D).position.z > 2.0: near += 1
	check(near == 0,"jellyfish stay on the far side (%d)" % near)
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY and we.environment.fog_enabled,"ocean sky and haze set")
	var inside := 0
	for mi in f.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5:
				inside += 1
	for n in f.get_children():
		if n is Node3D and not (n is MultiMeshInstance3D) and not (n is CPUParticles3D) and not String(n.name).begins_with("Ray"):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x) < 6.0 and absf(p.z) < 11.0: inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	print("ABYSSAL_SANCTUARY ",checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
