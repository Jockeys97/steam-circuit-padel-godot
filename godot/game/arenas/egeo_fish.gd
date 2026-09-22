extends Node3D
## One pooled fish and splash, local RNG; never touches simulation randomness.
var rng := RandomNumberGenerator.new()
var wait_seconds := 14.0
var elapsed := -1.0
var start := Vector3.ZERO
var direction := 1.0
var fish: Node3D
var splash: MeshInstance3D
const WATER_Y := -3.39
const FLIGHT := 1.2

func _ready() -> void:
	rng.seed = 923117
	fish = Node3D.new()
	add_child(fish)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color("77b4bc")
	silver.roughness = 0.5
	var body := SphereMesh.new()
	body.radial_segments = 10
	body.rings = 5
	body.radius = 0.12
	body.height = 0.24
	var mi := MeshInstance3D.new()
	mi.mesh = body
	mi.scale = Vector3(2.6,0.8,0.8)
	mi.material_override = silver
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fish.add_child(mi)
	var tail := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.15
	cone.height = 0.22
	cone.radial_segments = 3
	tail.mesh = cone
	tail.position.x = -0.32
	tail.rotation.z = -PI/2.0
	tail.material_override = silver
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fish.add_child(tail)
	splash = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.23
	ring.rings = 16
	ring.ring_segments = 4
	splash.mesh = ring
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color("b6d8de")
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splash.material_override = foam
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splash)
	fish.hide()
	splash.hide()

func _process(delta: float) -> void:
	# The match owns pause without pausing SceneTree.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("is_paused") and ancestor.call("is_paused"):
			return
		ancestor = ancestor.get_parent()
	step(delta)

func step(delta: float) -> void:
	if elapsed < 0.0:
		wait_seconds -= delta
		if wait_seconds > 0.0: return
		direction = -1.0 if rng.randf() < 0.5 else 1.0
		start = Vector3(direction * rng.randf_range(21.0,25.0), WATER_Y, rng.randf_range(-8.0,8.0))
		elapsed = 0.0
		fish.show()
	elapsed += delta
	if elapsed < FLIGHT:
		var t := elapsed / FLIGHT
		fish.position = start + Vector3(direction * 2.0 * t, sin(t * PI) * 1.05, 0)
		fish.rotation = Vector3(0,0,atan2(1.05 * PI * cos(t * PI),2.0))
		if direction < 0: fish.rotation.y = PI
	else:
		fish.hide()
		var t := (elapsed-FLIGHT)/0.7
		splash.visible = t < 1.0
		splash.position = start + Vector3(direction*2.0,0.025,0)
		splash.scale = Vector3.ONE * (0.5+t*2.0)
		if t >= 1.0:
			elapsed = -1.0
			wait_seconds = rng.randf_range(18.0,35.0)
