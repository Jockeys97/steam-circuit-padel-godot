extends RefCounted
## Static peripheral landscape: no gameplay nodes, animation, lights or shadows.
const Shapes = preload("res://game/arenas/egeo_environment.gd")

static func build(scenery: Node3D, id: String) -> void:
	var root := Node3D.new()
	root.name = "OutdoorLandscape"
	scenery.add_child(root)
	var colors: Dictionary = {
		"torii": [Color("344c49"), Color("687386"), Color("414c68")],
		"medina": [Color("b58c63"), Color("bb9b85"), Color("987969")],
		"carioca": [Color("c9bd91"), Color("739eae"), Color("426f71")],
		"aurora": [Color("273941"), Color("52697b"), Color("354657")],
	}
	var palette: Array = colors[id]
	Shapes.box(root, "LandscapeGround", Vector3(2400, 0.3, 2400),
		Vector3(0, -0.65, 0), Shapes.material(palette[0]))
	# Two staggered rings have real parallax from every camera, not a flat backdrop.
	for layer in 2:
		var rock := Shapes.material(palette[layer + 1])
		for i in 14:
			var angle := TAU * (float(i) + 0.37 * layer) / 14.0
			var distance := 230.0 + layer * 180.0
			var height := 9.0 + float((i * 7 + layer * 3) % 11) * 1.1
			if id == "medina": height *= 0.35
			var mesh := ridge_mesh(65.0 + layer * 30.0, height, i + layer * 17)
			var ridge := Shapes.part(root, "DistantRidge", mesh,
				Vector3(cos(angle) * distance, -3.0, sin(angle) * distance), rock)
			ridge.scale.z = 0.7
			ridge.rotation.y = angle
	if id in ["torii", "medina", "aurora"]:
		_build_distant_landmark(root, id)
	if id == "carioca":
		_build_sugarloaf(root)
		var water := ShaderMaterial.new()
		water.shader = preload("res://game/arenas/egeo_water.gdshader")
		water.set_shader_parameter("coast_extent", Vector2(40.0, 38.0))
		Shapes.box(root, "CoastalWater", Vector3(2400, 0.1, 2400), Vector3(0, -0.4, 0), water)
		Shapes.box(root, "BeachShelf", Vector3(80, 0.6, 76), Vector3(0, -0.35, 0), Shapes.material(palette[0]))
		var crabs := preload("res://game/arenas/carioca_crabs.gd").new()
		crabs.name = "BeachCrabs"
		root.add_child(crabs)
	elif id == "medina":
		var plaster := Shapes.material(Color("b78562"))
		var trim := Shapes.material(Color("d6ac7f"))
		var recess := Shapes.material(Color("493c36"))
		for i in 16:
			var x := float(i % 8) * 9.0 - 31.5
			var z := -35.0 - float(i / 8) * 14.0
			var h := 3.0 + float(i % 4) * 1.1
			Shapes.box(root, "MedinaHouse", Vector3(7,h,7), Vector3(x,h/2.0-0.5,z), plaster)
			Shapes.box(root, "RoofCornice", Vector3(7.3,0.25,7.3), Vector3(x,h-0.4,z), trim)
			Shapes.box(root, "DoorRecess", Vector3(1.1,1.9,0.08), Vector3(x,0.45,z+3.54), recess)
			for side in [-1.0, 1.0]:
				Shapes.box(root, "WindowRecess", Vector3(0.7,0.9,0.08), Vector3(x+side*2.0,h*0.6,z+3.54), recess)
	elif id == "torii":
		var wood := Shapes.material(Color("403735"))
		var leaves := Shapes.material(Color("486256"))
		for i in 24:
			var angle := TAU * float(i) / 24.0
			var radius := 64.0 + float(i % 5) * 3.7
			var pos := Vector3(cos(angle)*radius,-0.5,sin(angle)*radius)
			Shapes.box(root,"ForestTrunk",Vector3(0.4,5,0.4),pos+Vector3(0,2,0),wood)
			var crown := SphereMesh.new()
			crown.radius = 2.6
			crown.height = 5.2
			crown.radial_segments = 10
			crown.rings = 5
			var canopy := Shapes.part(root,"ForestCanopy",crown,pos+Vector3(0,4,0),leaves)
			canopy.scale = Vector3(1.5, 0.65 + float(i % 3) * 0.1, 1.2)
		var stone := Shapes.material(Color("69706b"))
		var lantern := Shapes.material(Color("e8b876"))
		for side in [-1.0, 1.0]:
			for i in 5:
				var pos := Vector3(side * 24.0, 0.0, -18.0 - i * 6.0)
				Shapes.box(root, "LanternPedestal", Vector3(0.5,1.2,0.5), pos+Vector3(0,0.3,0), stone)
				Shapes.box(root, "LanternWindow", Vector3(0.65,0.55,0.65), pos+Vector3(0,1.1,0), lantern)
				Shapes.box(root, "LanternCap", Vector3(1.0,0.16,1.0), pos+Vector3(0,1.45,0), stone)
	elif id == "aurora":
		var basalt := Shapes.material(Color("344650"))
		var snow := Shapes.material(Color("a4b7bf"))
		# Broken basalt clusters, outside the stands; no animated particles or lights.
		for side in [-1.0, 1.0]:
			for i in 12:
				var h: float = 1.2 + 2.4 * absf(sin(i * 1.71))
				var pos := Vector3(side * (27.0 + 2.5 * sin(i)), h * 0.5 - 0.5, -22.0 - i * 2.3)
				var pillar := CylinderMesh.new()
				pillar.radial_segments = 6
				pillar.rings = 1
				pillar.top_radius = 1.0
				pillar.bottom_radius = 1.1
				pillar.height = h
				Shapes.part(root,"BasaltCluster",pillar,pos,basalt)
				if i % 3 == 0:
					var cap := CylinderMesh.new()
					cap.radial_segments = 6
					cap.rings = 1
					cap.top_radius = 0.9
					cap.bottom_radius = 1.0
					cap.height = 0.14
					Shapes.part(root,"SnowCap",cap,pos+Vector3(0,h*0.5,0),snow)


## One image-derived architectural/geological anchor per arena, behind the playable
## enclosure. No collision, dynamic shadow or per-frame script work is added.
static func _build_distant_landmark(root: Node3D, id: String) -> void:
	var scene := load("res://assets/arenas/%s/distant_landmark.glb" % id) as PackedScene
	if scene == null:
		return
	var landmark := scene.instantiate() as Node3D
	landmark.name = "DistantLandmark"
	root.add_child(landmark)
	var bounds := AABB()
	var first := true
	for child in landmark.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var transform := mesh.transform
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != landmark and ancestor != null:
			transform = ancestor.transform * transform
			ancestor = ancestor.get_parent() as Node3D
		var local := transform * mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if first or bounds.size.y <= 0.0:
		landmark.queue_free()
		return
	var heights := {"torii": 15.0, "medina": 15.0, "aurora": 15.0}
	var centers := {
		"torii": Vector2(-8.0, -41.0),
		"medina": Vector2(3.0, -36.0),
		"aurora": Vector2(-10.0, -42.0),
	}
	var factor: float = heights[id] / bounds.size.y
	landmark.scale = Vector3.ONE * factor
	var center: Vector2 = centers[id]
	landmark.position = Vector3(center.x - (bounds.position.x + bounds.size.x * 0.5) * factor,
		-0.5 - bounds.position.y * factor,
		center.y - (bounds.position.z + bounds.size.z * 0.5) * factor)


## Irregular connected hill surface, deterministic and independent of simulation RNG.
## Rounded shoulders replace the repeated straight-sided cones of the first pass.
static func _build_sugarloaf(root: Node3D) -> void:
	var scene := load("res://assets/arenas/carioca/sugarloaf.glb") as PackedScene
	if scene == null:
		return
	var mountain := scene.instantiate() as Node3D
	mountain.name = "SugarloafLandmark"
	root.add_child(mountain)
	var bounds := AABB()
	var first := true
	for child in mountain.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var transform := mesh.transform
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != mountain and ancestor != null:
			transform = ancestor.transform * transform
			ancestor = ancestor.get_parent() as Node3D
		var local := transform * mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if first or bounds.size.y <= 0.0:
		mountain.queue_free()
		return
	var factor := 36.0 / bounds.size.y
	mountain.scale = Vector3.ONE * factor
	# Offset landmark leaves the centre sightline and the whole playable footprint clear.
	mountain.position = Vector3(-62.0, -0.5 - bounds.position.y * factor, -145.0)


static func ridge_mesh(radius: float, height: float, seed: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for level in range(6):
		var ring := PackedVector3Array()
		var t := float(level) / 5.0
		for i in range(25):
			var angle := TAU * float(i % 24) / 24.0
			var uneven := 1.0 + 0.16 * sin(angle * 3.0 + seed) + 0.09 * cos(angle * 5.0 - seed)
			var r := radius * (1.0 - t) * uneven
			var y := height * sin(t * PI * 0.5) * (0.85 + 0.15 * sin(angle * 2.0 + seed) * (1.0 - t))
			ring.append(Vector3(cos(angle) * r + t * radius * 0.13, y, sin(angle) * r))
		rings.append(ring)
	for level in range(5):
		for i in range(24):
			for vertex in [rings[level][i], rings[level + 1][i], rings[level][i + 1],
				rings[level][i + 1], rings[level + 1][i], rings[level + 1][i + 1]]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
