extends RefCounted
## Egeo only. Real sky and distant geometry, no camera-facing backdrop.
static func build(scenery: Node3D) -> void:
	for child in scenery.get_children():
		if String(child.name).begins_with("Backdrop") or String(child.name).begins_with("Dressing_"):
			(child as Node3D).hide()
	var root := Node3D.new()
	root.name = "EgeoEnvironment"
	scenery.add_child(root)
	var fish := preload("res://game/arenas/egeo_fish.gd").new()
	fish.name = "SeaLife"
	root.add_child(fish)
	var stone := material(Color("d4c6af"))
	var white := material(Color("e8e5dc"))
	var blue := material(Color("23599b"))
	var island := material(Color("547d93"))
	var sea := ShaderMaterial.new()
	sea.shader = preload("res://game/arenas/egeo_water.gdshader")
	box(root,"Sea",Vector3(3000,0.2,3000),Vector3(0,-3.5,0),sea)
	# Finite elevated terrace replaces the endless tiled apron.
	var surround := scenery.get_parent().get_node_or_null("Surround") as MeshInstance3D
	if surround != null: surround.hide()
	box(root,"Terrace",Vector3(36,1.6,34),Vector3(0,-0.87,0),stone)
	for side in [-1,1]:
		box(root,"Parapet",Vector3(0.35,0.6,34),Vector3(side*17.8,0.23,0),white)
	box(root,"RearParapet",Vector3(36,0.6,0.35),Vector3(0,0.23,-16.8),white)
	# Layered low-cost island silhouettes. No lights or collisions.
	for i in 9:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 7+i%4
		mesh.rings = 1
		mesh.top_radius = 0.28
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		var ridge := part(root,"Island",mesh,Vector3(-260+i*65,-1,-210-abs(i-4)*18),island)
		ridge.scale = Vector3(50,8+float(i%3)*6,27)
		ridge.rotation.y = i*0.72
	# Houses step up the caldera behind the court, leaving the playing footprint free.
	for i in 18:
		var row := i/6
		var x := float(i%6)*5.8-14.5+sin(float(i)*2.1)*1.1
		var z := -23.0-float(row)*7.0
		var base := float(row)*1.6-1.2
		var height := 1.7+float(i%5)*0.32
		box(root,"VillagePlinth",Vector3(5.6,3.0+base,6.5),Vector3(x,(base-3.0)*0.5,z),stone)
		box(root,"House",Vector3(3.5,height,3.1),Vector3(x,base+height*0.5,z),white)
		box(root,"Door",Vector3(0.6,1.45,0.06),Vector3(x-0.65,base+0.725,z+1.58),blue)
		box(root,"Window",Vector3(0.65,0.75,0.06),Vector3(x+0.8,base+height*0.65,z+1.58),blue)
		if i%3 == 0:
			var dome := SphereMesh.new()
			dome.radius = 1.45
			dome.height = 2.9
			dome.radial_segments = 16
			dome.rings = 8
			var cap := part(root,"BlueDome",dome,Vector3(x,base+height-0.05,z),blue)
			cap.scale.y = 0.65
		else:
			box(root,"Roof",Vector3(3.7,0.15,3.3),Vector3(x,base+height,z),white)
	# Keep the village silhouette even when the optional community GLB is missing.
	if not _build_community_windmill(root):
		_build_simple_windmill(root, white, stone)

static func _build_community_windmill(root: Node3D) -> bool:
	const WINDMILL_PATH := "res://assets/arenas/egeo/community_windmill.glb"
	if not ResourceLoader.exists(WINDMILL_PATH):
		return false
	var scene := load(WINDMILL_PATH) as PackedScene
	if scene == null:
		return false
	var windmill := scene.instantiate() as Node3D
	if windmill == null:
		return false
	windmill.name = "CommunityWindmill"
	root.add_child(windmill)
	var bounds := AABB()
	var first := true
	for child in windmill.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var local_transform := mesh.transform
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != windmill and ancestor != null:
			local_transform = ancestor.transform * local_transform
			ancestor = ancestor.get_parent() as Node3D
		var local_bounds := local_transform * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	if first or bounds.size.y <= 0.0:
		root.remove_child(windmill)
		windmill.free()
		return false
	var factor := 6.5 / bounds.size.y
	windmill.scale = Vector3.ONE * factor
	windmill.position = Vector3(
		12.0 - (bounds.position.x + bounds.size.x * 0.5) * factor,
		2.25 - bounds.position.y * factor,
		-34.0 - (bounds.position.z + bounds.size.z * 0.5) * factor
	)
	return true

static func _build_simple_windmill(root: Node3D, white: Material, stone: Material) -> void:
	var tower := CylinderMesh.new()
	tower.bottom_radius=1.1
	tower.top_radius=0.75
	tower.height=4.3
	tower.radial_segments=16
	part(root,"Windmill",tower,Vector3(12,4.4,-34),white)
	for angle in [0.0,PI/3.0,PI*2.0/3.0]:
		var beam := BoxMesh.new()
		beam.size=Vector3(0.08,5.6,0.08)
		var sail := part(root,"WindmillSpar",beam,Vector3(12,6.0,-33.1),stone)
		sail.rotation.z=angle

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=0.9
	return mat
static func part(root: Node3D, title: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name=title
	mi.mesh=mesh
	mi.position=pos
	mi.material_override=mat
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
static func box(root: Node3D, title: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size=size
	part(root,title,mesh,pos,mat)
