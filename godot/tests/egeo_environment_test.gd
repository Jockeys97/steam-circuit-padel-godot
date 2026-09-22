extends SceneTree
const Arena = preload("res://game/arenas/arena_library.gd")
const Court = preload("res://game/court.gd")
const Config = preload("res://game/match_config.gd")
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures+=1
		printerr("FAIL ",label)
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1280,720)
	var arena = Arena.build("egeo")
	root.add_child(arena)
	var scenery = arena.get_node("Scenery")
	check(scenery.has_node("EgeoEnvironment"),"pilot mounted")
	for node in scenery.get_children():
		if String(node.name).begins_with("Backdrop"): check(not node.visible,"no visible panel")
	var environment: Environment = arena.find_child("WorldEnvironment",true,false).environment
	check(environment.background_mode==Environment.BG_SKY and environment.sky.sky_material is ProceduralSkyMaterial,"real sky")
	var triangles := 0
	for mi in scenery.get_node("EgeoEnvironment").find_children("*","MeshInstance3D",true,false):
		triangles += mi.mesh.get_faces().size()/3
	check(triangles<15000,"geometry budget")
	print("EGEO_TRIANGLES ",triangles)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current=true
	for preset in Court.CAMERAS:
		var cfg: Dictionary = Court.CAMERAS[preset]
		camera.position=cfg.pos
		camera.fov=cfg.fov
		camera.look_at(cfg.look_at)
		for i in 4: await process_frame
		RenderingServer.force_draw(false)
		check(root.get_texture().get_image().save_png("/tmp/egeo-"+preset+".png")==OK,"capture "+preset)
	camera.free()
	arena.free()
	for id in ["medina","officina"]:
		var other = Arena.build(id)
		root.add_child(other)
		check(other.find_child("EgeoEnvironment",true,false)==null,"isolation "+id)
		other.free()
	Config.save_dir="user://egeo-environment-test-%d" % Time.get_ticks_usec()
	Config.world_arena_id="egeo"
	var game = load("res://game/Match.tscn").instantiate()
	root.add_child(game)
	game.engine_driven=false
	check(game.find_child("EgeoEnvironment",true,false)!=null,"actual match route")
	var cfg: Dictionary = Court.CAMERAS.courtside
	game._cam.position=cfg.pos
	game._cam.fov=cfg.fov
	game._cam.look_at(cfg.look_at)
	game._sync_views()
	for i in 4: await process_frame
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png("/tmp/egeo-match.png")==OK,"actual match capture")
	game.free()
	print("EGEO_ENV failures=",failures)
	quit(1 if failures else 0)
