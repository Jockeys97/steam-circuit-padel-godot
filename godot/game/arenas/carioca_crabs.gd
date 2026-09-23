extends Node3D
## Pooled decorative wildlife, independent of simulation RNG and collisions.
const Shapes = preload("res://game/arenas/egeo_environment.gd")
const PERIOD := 26.0
const SAND_Y := -0.015
var elapsed := 0.0
var crabs: Array[Node3D] = []
var legs: Array = []
var homes: Array[Vector3] = []

func _ready() -> void:
	var shell := Shapes.material(Color("bd593c"))
	var dark := Shapes.material(Color("38221a"))
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.23
	body_mesh.height = 0.46
	body_mesh.radial_segments = 10
	body_mesh.rings = 5
	var limb_mesh := BoxMesh.new()
	limb_mesh.size = Vector3(0.28, 0.045, 0.045)
	for i in 4:
		var crab := Node3D.new()
		crab.name = "Crab%d" % i
		add_child(crab)
		crabs.append(crab)
		homes.append(Vector3(-14.0 if i % 2 == 0 else 14.0, SAND_Y, -1.0 if i < 2 else -5.0))
		crab.position = homes[i]
		crab.scale = Vector3.ONE * 1.35
		var body := Shapes.part(crab, "Shell", body_mesh, Vector3(0,0.14,0), shell)
		body.scale = Vector3(1.3,0.5,1.0)
		var moving: Array[MeshInstance3D] = []
		for side in [-1.0, 1.0]:
			for k in 4:
				var leg := Shapes.part(crab, "Leg", limb_mesh, Vector3(side*0.32,0.07,-0.16+k*0.105),shell)
				leg.rotation.y = side * (float(k)-1.5) * 0.35
				moving.append(leg)
			var claw := Shapes.part(crab,"Claw",body_mesh,Vector3(side*0.3,0.17,-0.34),shell)
			claw.scale = Vector3(0.48,0.35,0.65)
			var eye := Shapes.part(crab,"Eye",body_mesh,Vector3(side*0.10,0.28,-0.17),dark)
			eye.scale = Vector3.ONE * 0.13
		legs.append(moving)
	step(0.0)

func _process(delta: float) -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("is_paused") and ancestor.call("is_paused"):
			return
		ancestor = ancestor.get_parent()
	step(delta)

func step(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	for i in crabs.size():
		var t := fposmod(elapsed + i * 6.1, PERIOD)
		var crab := crabs[i]
		crab.visible = t < 12.0
		if not crab.visible:
			continue
		var walk := clampf((t - 1.5) / 9.0, 0.0, 1.0)
		var emerge := smoothstep(0.0, 1.5, t) * (1.0 - smoothstep(10.5, 12.0, t))
		crab.position = homes[i] + Vector3(signf(homes[i].x) * 1.5 * walk, -0.55 * (1.0-emerge), 0)
		for k in legs[i].size():
			var leg: MeshInstance3D = legs[i][k]
			leg.rotation.z = sin(t * 16.0 + k * PI) * 0.3 if t > 1.5 and t < 10.5 else 0.0
