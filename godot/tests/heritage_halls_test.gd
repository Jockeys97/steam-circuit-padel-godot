extends SceneTree
const Arena = preload("res://game/arenas/arena_library.gd")
const Court = preload("res://game/court.gd")
const Config = preload("res://game/match_config.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _initialize(): call_deferred("run")
func bounds_ok(bounds: AABB) -> bool:
	return bounds.end.y < 6.0 and bounds.position.y >= -0.1 and (bounds.end.z < -10.0 or bounds.position.x > 5.5 or bounds.end.x < -5.5)
func run():
	if DisplayServer.get_name() == "headless":
		printerr("Native renderer required for MultiMesh transform and image evidence")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	Config.save_dir = "user://heritage-test-%s" % Time.get_ticks_usec()
	for id in ["locomotive","clockwork"]:
		var arena = Arena.build(id)
		root.add_child(arena)
		var name := "LocomotiveDepot" if id == "locomotive" else "ClockworkFactory"
		var hall = arena.get_node("Scenery/"+name)
		check(hall != null,"correct hall")
		var triangles := 0
		var batches := 0
		for mi in hall.find_children("*","MultiMeshInstance3D",true,false):
			var mm: MultiMesh = mi.multimesh
			batches += 1
			triangles += mm.mesh.get_faces().size()/3*mm.instance_count
			for i in mm.instance_count:
				check(bounds_ok(mi.global_transform*mm.get_instance_transform(i)*mm.mesh.get_aabb()),id+" batched prop outside field")
		for mi in hall.find_children("*","MeshInstance3D",true,false):
			triangles += mi.mesh.get_faces().size()/3
			check(bounds_ok(mi.global_transform*mi.mesh.get_aabb()),id+" animated prop outside field")
		check(hall.find_children("*","Light3D",true,false).is_empty(),"no extra lights")
		check(hall.find_children("*","CollisionObject3D",true,false).is_empty(),"no gameplay colliders")
		check(triangles < 22000 and batches <= 24,"bounded scenery cost")
		check(is_equal_approx(float(arena.get_meta("wallBounce")),float(Arena.info(id).wallBounce)),"physics retained")
		if id == "clockwork":
			hall._process(1.0)
			check(hall.gears[0].rotation.z > 0 and hall.gears[1].rotation.z < 0,"opposed mechanical rotation")
			check(absf(hall.clock_hands[0].rotation.z+0.6) > absf(hall.clock_hands[1].rotation.z-1.2),"hour hand slower")
		print("HERITAGE ",id," triangles=",triangles," batches=",batches)
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.current = true
		for preset in ["default","wide","playable","broadcast"]:
			var c: Dictionary = Court.CAMERAS[preset]
			camera.position = c.pos
			camera.fov = c.fov
			camera.look_at(c.look_at)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/"+id+"-"+preset+".png") == OK,"capture saved")
		camera.free()
		arena.free()
		Config.world_arena_id = ""
		Config.arena_index = Config.arena_index_of(id)
		var game = load("res://game/Match.tscn").instantiate()
		game.harness_mode()
		root.add_child(game)
		await process_frame
		check(game.find_child(name,true,false) != null,"selected hall reaches actual match")
		game._sync_views()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/"+id+"-match.png") == OK,"actual match capture")
		game.free()
	print("HERITAGE_HALLS ",checks-failures,"/",checks)
	quit(1 if failures else 0)
