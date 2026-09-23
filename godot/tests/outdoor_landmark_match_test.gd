extends SceneTree

const Config = preload("res://game/match_config.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for id in ["torii", "medina", "aurora"]:
		Config.world_arena_id = id
		Config.arena_index = 0
		var match_scene = load("res://game/Match.tscn").instantiate()
		match_scene.engine_driven = false
		root.add_child(match_scene)
		await process_frame
		assert(match_scene.state != null, "%s simulation state did not initialize" % id)
		var landmark: Node3D = match_scene._arena_root.find_child("DistantLandmark", true, false) as Node3D
		assert(landmark != null, "%s landmark missing from real match" % id)
		assert(landmark.position.z < -25.0)
		assert(landmark.find_children("*", "MeshInstance3D", true, false).size() > 0)
		match_scene.free()
	print("PASS outdoor landmarks mounted in real matches: torii, medina, aurora")
	quit()
