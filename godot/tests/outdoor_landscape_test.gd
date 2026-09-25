extends SceneTree
const Landscape = preload("res://game/arenas/outdoor_landscape.gd")

func _initialize() -> void:
	var count := 0
	for id in ["torii", "medina", "carioca", "aurora"]:
		var scenery := Node3D.new()
		Landscape.build(scenery, id)
		var landscape := scenery.get_node("OutdoorLandscape")
		assert(landscape.get_child_count() < 180)
		if id == "aurora":
			var plateau := landscape.get_node("AuroraPlateau") as MeshInstance3D
			assert(plateau.position.y + (plateau.mesh as BoxMesh).size.y * 0.5 < -0.02)
			assert((plateau.material_override as StandardMaterial3D).albedo_texture != null)
			assert(landscape.find_children("AuroraSideSnow*", "MeshInstance3D", false, false).size() == 8)
			assert(landscape.find_children("AuroraRearSnow*", "MeshInstance3D", false, false).size() == 3)
			assert(landscape.find_children("AuroraOutcrop*", "MeshInstance3D", false, false).size() == 4)
			assert(landscape.find_children("AuroraMidRidge*", "MeshInstance3D", false, false).size() == 7)
			assert(landscape.find_children("AuroraWalkDeck_*", "MeshInstance3D", false, false).size() == 2)
			assert(landscape.find_children("AuroraWalkMarker_*", "MeshInstance3D", false, false).size() == 8)
			assert(landscape.find_children("AuroraBoulder_*", "MeshInstance3D", false, false).size() == 6)
			assert(landscape.find_children("AuroraBoulderSnow_*", "MeshInstance3D", false, false).size() == 3)
			assert(landscape.find_children("AuroraThermalRim_*", "MeshInstance3D", false, false).size() == 2)
			assert(landscape.find_children("AuroraThermalWater_*", "MeshInstance3D", false, false).size() == 2)
			assert(landscape.find_children("AuroraSteam_*", "MeshInstance3D", false, false).size() == 4)
			for prop in landscape.find_children("AuroraWalkDeck_*", "MeshInstance3D", false, false) \
				+ landscape.find_children("AuroraBoulder_*", "MeshInstance3D", false, false) \
				+ landscape.find_children("AuroraThermalRim_*", "MeshInstance3D", false, false):
				assert(absf(prop.position.x) >= 10.0)
			for puff in landscape.find_children("AuroraSteam_*", "MeshInstance3D", false, false):
				assert(puff.material_override is ShaderMaterial)
		else:
			assert(landscape.get_node_or_null("AuroraPlateau") == null)
			assert(landscape.get_node_or_null("AuroraWalkRear") == null)
		var landmarks := 0
		var palms := 0
		var community_props := 0
		var expected_prop: String = {
			"torii": "CommunitySakura",
			"medina": "CommunityLantern",
			"carioca": "CommunityCafeSet",
		}.get(id, "")
		for child in landscape.get_children():
			if child.name == "BeachCrabs":
				assert(id == "carioca")
				continue
			if child.name == "SugarloafLandmark":
				assert(id == "carioca")
				assert(child.position.z < -100.0)
				assert(child.find_children("*", "MeshInstance3D", true, false).size() > 0)
				continue
			if String(child.name).begins_with("CommunityPalm_"):
				assert(id == "carioca")
				assert(child.position.x >= 12.5 and child.position.z < -12.5)
				var palm_meshes := child.find_children("*", "MeshInstance3D", true, false)
				assert(palm_meshes.size() > 0)
				for mesh in palm_meshes:
					assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				palms += 1
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
			if String(child.name).begins_with("Community"):
				assert(String(child.name) == expected_prop)
				assert(absf(child.position.x) > 10.0 and child.position.z < -5.0)
				assert(child.get_script() == null)
				var prop_meshes := child.find_children("*", "MeshInstance3D", true, false)
				assert(prop_meshes.size() > 0)
				for mesh in prop_meshes:
					assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				community_props += 1
				continue
			assert(child is MeshInstance3D)
			assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			var vertices: AABB = child.get_aabb()
			assert(vertices.size.is_finite())
			assert(vertices.size.length() > 0.0)
			count += 1
		assert(landmarks == (0 if id == "carioca" else 1))
		assert(palms == (1 if id == "carioca" else 0))
		assert(community_props == (0 if id == "aurora" else 1))
		scenery.free()
	var first := Landscape.ridge_mesh(65.0, 15.0, 2).surface_get_arrays(0)
	var second := Landscape.ridge_mesh(65.0, 15.0, 2).surface_get_arrays(0)
	assert(first[Mesh.ARRAY_VERTEX] == second[Mesh.ARRAY_VERTEX])
	print("PASS outdoor landscape: ", count, " meshes checked, deterministic ridges, no added shadows")
	quit()
