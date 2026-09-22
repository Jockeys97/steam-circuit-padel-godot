extends SceneTree

const Arena = preload("res://game/arenas/arena_library.gd")
const Court = preload("res://game/court.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for id in ["torii", "medina", "carioca", "aurora"]:
		var arena = Arena.build(id)
		root.add_child(arena)
		var env: Environment = arena.find_child("WorldEnvironment", true, false).environment
		check(env.background_mode == Environment.BG_SKY and env.sky != null, id + " continuous sky")
		var panels := 0
		for node in arena.get_node("Scenery").get_children():
			if String(node.name).begins_with("Backdrop"):
				panels += 1
				check(not node.visible, id + " panel hidden: " + String(node.name))
		check(panels >= 2, id + " checked legacy panels")
		for preset in Court.CAMERAS:
			var cfg: Dictionary = Court.CAMERAS[preset]
			camera.position = cfg.pos
			camera.fov = cfg.fov
			camera.look_at(cfg.look_at)
			await process_frame
			await process_frame
			if DisplayServer.get_name() != "headless":
				RenderingServer.force_draw(false)
				check(root.get_texture().get_image().save_png("/tmp/sky-%s-%s.png" % [id, preset]) == OK, id + " capture " + preset)
		arena.free()
	camera.free()
	print("WORLD_SKY_PANEL failures=", failures)
	quit(1 if failures else 0)
