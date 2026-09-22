extends SceneTree
const Arena = preload("res://game/arenas/arena_library.gd")
const Court = preload("res://game/court.gd")
var failures := 0
func check(ok: bool,label: String):
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1280,720)
	var arena = Arena.build("officina")
	root.add_child(arena)
	var workshop = arena.get_node("Scenery/SteamWorkshop")
	var batches := 0
	var triangles := 0
	for child in workshop.get_children():
		check(not child is Light3D and not child is CollisionObject3D,"no gameplay physics or extra lights")
		if child is MultiMeshInstance3D:
			batches += 1
			var mm: MultiMesh = child.multimesh
			triangles += mm.mesh.get_faces().size()/3*mm.instance_count
			for i in mm.instance_count:
				var aabb: AABB = mm.get_instance_transform(i)*mm.mesh.get_aabb()
				check(aabb.end.z < -10.0 or aabb.position.x > 5.5 or aabb.end.x < -5.5,"geometry outside playable cage")
				check(aabb.end.y <= 6.0 and aabb.position.y >= -0.1,"bounded cutaway height")
	var engine = workshop.get_node("WorkshopEngine")
	for mi in engine.find_children("*","MeshInstance3D",true,false):
		triangles += mi.mesh.get_faces().size()/3
		var bounds: AABB = mi.global_transform*mi.mesh.get_aabb()
		check(bounds.end.z < -10.0 and bounds.end.y < 6.0,"engine stays behind far glass")
	var before: float = engine.wheel.rotation.z
	engine._process(1.0)
	check(engine.wheel.rotation.z > before and engine.wheel.rotation.z-before < 0.25,"slow decorative wheel")
	check(absf(engine.rods[0].position.y-3.15) <= 0.12,"bounded piston travel")
	check(batches <= 10 and triangles < 16000,"bounded detailed decoration cost")
	check(arena.get_node("GlassNear").visible and arena.get_node("LineFar").visible,"court retained")
	var other = Arena.build("cattedrale")
	check(other.get_node_or_null("Scenery/SteamWorkshop") == null,"other arenas untouched")
	for mi in other.find_children("*","MeshInstance3D",true,false):
		for surface in mi.mesh.get_surface_count():
			var mat = mi.get_active_material(surface)
			check(not mat is ShaderMaterial or not "workshop" in mat.shader.resource_path,"no material leak to untouched cattedrale")
	for board in arena.get_node("Scenery/ArenaProps").get_children():
		if not String(board.name).begins_with("Sponsor"): continue
		for mi in board.find_children("*","MeshInstance3D",true,false):
			for surface in mi.mesh.get_surface_count():
				check(not mi.get_active_material(surface) is ShaderMaterial,"sponsor texture unchanged")
	other.free()
	print("WORKSHOP batches=",batches," triangles=",triangles)
	if "--capture" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.current = true
		for preset in ["default","wide","playable","broadcast"]:
			var config: Dictionary = Court.CAMERAS[preset]
			camera.position = config.pos
			camera.fov = config.fov
			camera.look_at(config.look_at)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/workshop-"+preset+".png") == OK,"capture saved")
	print("STEAM_WORKSHOP failures=",failures)
	arena.free()
	if "--capture" in OS.get_cmdline_user_args():
		var config = load("res://game/match_config.gd")
		config.save_dir = "user://workshop-test-%s" % Time.get_ticks_usec()
		config.arena_index = 0
		config.world_arena_id = ""
		var game = load("res://game/Match.tscn").instantiate()
		game.harness_mode()
		root.add_child(game)
		await process_frame
		check(game.find_child("SteamWorkshop",true,false) != null,"real match uses workshop")
		game._sync_views()
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/workshop-match.png") == OK,"actual match capture")
		game.free()
	print("WORKSHOP_MATCH failures=",failures)
	quit(1 if failures else 0)
