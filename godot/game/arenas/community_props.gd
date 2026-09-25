extends RefCounted
## Downloaded Meshy Community scenery. Keep these outside the playable court and
## instantiate only the asset needed by the selected arena.

static func build(root: Node3D, arena_id: String) -> void:
	var scene_path := ""
	var prop_name := ""
	var target_height := 0.0
	var center := Vector2.ZERO
	match arena_id:
		"torii":
			scene_path = "res://assets/arenas/torii/community_sakura.glb"
			prop_name = "CommunitySakura"
			target_height = 2.8
			center = Vector2(13.2, -15.0)
		"medina":
			scene_path = "res://assets/arenas/medina/community_lantern.glb"
			prop_name = "CommunityLantern"
			target_height = 3.2
			center = Vector2(-13.2, -7.0)
		"carioca":
			scene_path = "res://assets/arenas/carioca/community_cafe_set.glb"
			prop_name = "CommunityCafeSet"
			target_height = 1.7
			center = Vector2(15.2, -13.0)
		_:
			return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return
	var prop := scene.instantiate() as Node3D
	if prop == null:
		return
	prop.name = prop_name
	root.add_child(prop)
	var bounds := AABB()
	var first := true
	for child in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var transform := mesh.transform
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != prop and ancestor != null:
			transform = ancestor.transform * transform
			ancestor = ancestor.get_parent() as Node3D
		var local := transform * mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if first or bounds.size.y <= 0.0:
		root.remove_child(prop)
		prop.free()
		return
	var factor := target_height / bounds.size.y
	prop.scale = Vector3.ONE * factor
	prop.position = Vector3(center.x - (bounds.position.x + bounds.size.x * 0.5) * factor,
		-0.5 - bounds.position.y * factor,
		center.y - (bounds.position.z + bounds.size.z * 0.5) * factor)
