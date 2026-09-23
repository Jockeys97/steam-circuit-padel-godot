extends SceneTree
const Landscape = preload("res://game/arenas/outdoor_landscape.gd")

func _initialize() -> void:
	var count := 0
	for id in ["torii", "medina", "carioca", "aurora"]:
		var scenery := Node3D.new()
		Landscape.build(scenery, id)
		var landscape := scenery.get_node("OutdoorLandscape")
		assert(landscape.get_child_count() < 180)
		var landmarks := 0
		for child in landscape.get_children():
			if child.name == "BeachCrabs":
				assert(id == "carioca")
				continue
			if child.name == "SugarloafLandmark":
				assert(id == "carioca")
				assert(child.position.z < -100.0)
				assert(child.find_children("*", "MeshInstance3D", true, false).size() > 0)
				continue
			if child.name == "DistantLandmark":
				landmarks += 1
				assert(id in ["torii", "medina", "aurora"])
				assert(child.position.z < -25.0)
				var meshes := child.find_children("*", "MeshInstance3D", true, false)
				assert(meshes.size() > 0)
				for mesh in meshes:
					assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				continue
			assert(child is MeshInstance3D)
			assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			var vertices: AABB = child.get_aabb()
			assert(vertices.size.is_finite())
			assert(vertices.size.length() > 0.0)
			count += 1
		assert(landmarks == (0 if id == "carioca" else 1))
		scenery.free()
	var first := Landscape.ridge_mesh(65.0, 15.0, 2).surface_get_arrays(0)
	var second := Landscape.ridge_mesh(65.0, 15.0, 2).surface_get_arrays(0)
	assert(first[Mesh.ARRAY_VERTEX] == second[Mesh.ARRAY_VERTEX])
	print("PASS outdoor landscape: ", count, " meshes checked, deterministic ridges, no added shadows")
	quit()
