extends SceneTree
## "Forgia Abyssal" (`game/arenas/abyssal_forge.gd`): presentation only. It must stay out of
## the playing volume, add no light nodes and no colliders, keep the arena's physics, mount
## the owner's three Meshy props, and set its sea-floor sky.
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
	Config.save_dir = "user://forgia-test-%s" % Time.get_ticks_usec()
	var arena = Arena.build("forgia")
	root.add_child(arena)
	var f = arena.get_node_or_null("Scenery/AbyssalForge")
	check(f != null,"forge scene mounted")
	check(f.find_children("*","Light3D",true,false).is_empty(),"no extra light nodes")
	check(f.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
	check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info("forgia").wallBounce)),"physics retained")
	check(f.find_children("Furnace*","",false,false).size() == 3,"three furnaces")
	check(f.find_children("Anvil*","",false,false).size() == 4,"four anvils")
	check(f.find_children("Brazier*","",false,false).size() == 8,"eight braziers")
	check(f.find_children("Magma*","",false,false).size() == 3,"three magma channels")
	var we: WorldEnvironment = arena.get_node("WorldEnvironment")
	check(we.environment.background_mode == Environment.BG_SKY and we.environment.fog_enabled,"sea-floor sky and haze set")
	var inside := 0
	for mi in f.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var box: AABB = mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()
			if box.position.y < 6.0 and box.end.x > -5.5 and box.position.x < 5.5 and box.end.z > -10.5 and box.position.z < 10.5:
				inside += 1
	for n in f.get_children():
		if n is Node3D and not (n is MultiMeshInstance3D) and not (n is CPUParticles3D) and not String(n.name).begins_with("Magma"):
			var p: Vector3 = (n as Node3D).global_position
			if absf(p.x) < 6.0 and absf(p.z) < 11.0: inside += 1
	check(inside == 0,"nothing inside the playing volume (%d)" % inside)
	print("ABYSSAL_FORGE ",checks-failures,"/",checks)
	arena.free()
	quit(1 if failures else 0)
