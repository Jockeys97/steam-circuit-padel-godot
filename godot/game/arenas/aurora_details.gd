extends RefCounted
## Low-cost, Aurora-only environmental props. All meshes stay outside the cage;
## only the steam material moves, on the GPU, without a per-frame script.
const Shapes = preload("res://game/arenas/egeo_environment.gd")
const STEAM = preload("res://game/arenas/aurora_steam.gdshader")

static func build(root: Node3D) -> void:
	var basalt := Shapes.material(Color("3a5360"))
	var pale_basalt := Shapes.material(Color("506b77"))
	var snow := Shapes.material(Color("a2bbc3"))
	var deck := Shapes.material(Color("304654"))
	var deck_edge := Shapes.material(Color("7896a1"))
	var marker := Shapes.material(Color("8bdacc"))
	marker.emission_enabled = true
	marker.emission = Color("72d9c9")
	marker.emission_energy_multiplier = 1.25
	var water := Shapes.material(Color("3f9c9d"))
	water.emission_enabled = true
	water.emission = Color("2a8c89")
	water.emission_energy_multiplier = 0.65
	var steam := ShaderMaterial.new()
	steam.shader = STEAM

	# The boardwalk sits between the spectator banks and the outer rock field.
	# A short rear connector makes it read as one place, not two floating strips.
	Shapes.box(root, "AuroraWalkRear", Vector3(27.0, 0.1, 1.2),
		Vector3(0, 0.0, -20.0), deck)
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		var x: float = side * 13.5
		Shapes.box(root, "AuroraWalkDeck_%s" % tag, Vector3(2.2, 0.12, 40.0),
			Vector3(x, 0.0, 0), deck)
		Shapes.box(root, "AuroraWalkEdge_%s" % tag, Vector3(0.12, 0.16, 40.0),
			Vector3(side * 14.65, 0.04, 0), deck_edge)
		for i in 6:
			var z := -15.0 + float(i) * 6.0
			Shapes.box(root, "AuroraWalkJoint_%s_%d" % [tag, i],
				Vector3(2.2, 0.025, 0.12), Vector3(x, 0.075, z), deck_edge)
		# Waist-high rail and sparse lit posts: emissive paint, not real lights.
		Shapes.box(root, "AuroraWalkRail_%s" % tag, Vector3(0.1, 0.1, 36.0),
			Vector3(side * 14.7, 0.82, 0), pale_basalt)
		for i in 4:
			var z := -16.0 + float(i) * 10.7
			Shapes.box(root, "AuroraWalkPost_%s_%d" % [tag, i],
				Vector3(0.14, 0.9, 0.14), Vector3(side * 14.7, 0.39, z), pale_basalt)
			Shapes.box(root, "AuroraWalkMarker_%s_%d" % [tag, i],
				Vector3(0.22, 0.2, 0.22), Vector3(side * 14.7, 0.95, z), marker)

	# Small uneven boulders frame the path; none enters x = +/-10 m.
	var boulder_positions := [
		Vector3(-19.0, 0, -9.0), Vector3(-17.5, 0, 8.0),
		Vector3(-20.0, 0, 24.0), Vector3(19.5, 0, -17.0),
		Vector3(18.0, 0, 3.0), Vector3(20.5, 0, 27.0),
	]
	for i in boulder_positions.size():
		var pos: Vector3 = boulder_positions[i]
		var body := SphereMesh.new()
		body.radius = 1.0
		body.height = 2.0
		body.radial_segments = 8
		body.rings = 4
		var rock := Shapes.part(root, "AuroraBoulder_%d" % i, body,
			Vector3(pos.x, 0.38, pos.z), basalt if i % 2 == 0 else pale_basalt)
		rock.scale = Vector3(1.5 + float(i % 3) * 0.25, 0.65, 1.2 + float(i % 2) * 0.2)
		if i % 2 == 0:
			var cap := SphereMesh.new()
			cap.radius = 1.0
			cap.height = 2.0
			cap.radial_segments = 8
			cap.rings = 4
			var frost := Shapes.part(root, "AuroraBoulderSnow_%d" % i, cap,
				Vector3(pos.x, 0.89, pos.z), snow)
			frost.scale = Vector3(0.82, 0.2, 0.69)

	# Exactly two shallow hot pools beyond the outside edge of the walkways.
	_build_pool(root, "L", Vector3(-21.0, 0, -24.0), basalt, water, steam)
	_build_pool(root, "R", Vector3(21.0, 0, 15.0), basalt, water, steam)


static func _build_pool(root: Node3D, tag: String, pos: Vector3,
		basalt: Material, water: Material, steam: Material) -> void:
	var rim := CylinderMesh.new()
	rim.top_radius = 2.8
	rim.bottom_radius = 3.15
	rim.height = 0.25
	rim.radial_segments = 12
	Shapes.part(root, "AuroraThermalRim_%s" % tag, rim,
		Vector3(pos.x, -0.06, pos.z), basalt)
	var basin := CylinderMesh.new()
	basin.top_radius = 2.45
	basin.bottom_radius = 2.45
	basin.height = 0.035
	basin.radial_segments = 16
	Shapes.part(root, "AuroraThermalWater_%s" % tag, basin,
		Vector3(pos.x, 0.075, pos.z), water)
	for i in 2:
		var veil := QuadMesh.new()
		veil.size = Vector2(1.8, 2.4)
		var puff := Shapes.part(root, "AuroraSteam_%s_%d" % [tag, i], veil,
			Vector3(pos.x, 1.22, pos.z), steam)
		puff.rotation.y = float(i) * PI * 0.5
