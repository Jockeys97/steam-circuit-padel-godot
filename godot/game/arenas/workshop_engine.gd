## Slow decorative machinery. No physics, lights, audio or simulation dependency.
extends Node3D
var phase := 0.0
var wheel: Node3D
var rods: Array[Node3D] = []

func assemble() -> void:
	name = "WorkshopEngine"
	position.z = -11.95
	var iron := material(Color("26323a"),0.35)
	var copper := material(Color("9b623d"),0.5)
	var brass := material(Color("b69156"),0.45)
	# Raised service platform and rails remain behind the far glass.
	box(self,Vector3(15,0.18,0.7),Vector3(0,0.8,-0.3),iron)
	for x in [-7.0,-5.0,-3.0,3.0,5.0,7.0]:
		box(self,Vector3(0.07,0.65,0.07),Vector3(x,1.18,-0.55),brass)
		box(self,Vector3(0.15,0.8,0.4),Vector3(x,0.4,-0.3),iron)
	for side in [-1.0,1.0]:
		box(self,Vector3(4.3,0.06,0.06),Vector3(side*5,1.5,-0.55),brass)
		for step in 4:
			box(self,Vector3(0.8,0.15,0.22),Vector3(side*(7.8+step*0.23),0.7-step*0.17,-0.3),iron)
		box(self,Vector3(0.48,2.6,0.55),Vector3(side*2,1.8,0),copper)
		var rod := box(self,Vector3(0.12,1.0,0.14),Vector3(side*2,3.15,0),brass)
		rods.append(rod)
		box(self,Vector3(2.0,0.2,0.4),Vector3(side*1.0,0.98,0),iron)
	# The flywheel faces the camera and turns around its axle, not around the hall.
	wheel = Node3D.new()
	wheel.name = "Flywheel"
	wheel.position = Vector3(0,2.6,0.20)
	add_child(wheel)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.27
	ring.outer_radius = 1.47
	ring.rings = 32
	ring.ring_segments = 6
	var rim := piece(wheel,ring,Vector3.ZERO,copper)
	rim.rotation.x = PI/2
	for i in 4:
		var spoke := box(wheel,Vector3(2.7,0.13,0.13),Vector3.ZERO,iron)
		spoke.rotation.z = float(i)*PI/4
	var hub := CylinderMesh.new()
	hub.top_radius = 0.26
	hub.bottom_radius = 0.26
	hub.height = 0.3
	hub.radial_segments = 16
	var axle := piece(wheel,hub,Vector3(0,0,0.08),brass)
	axle.rotation.x = PI/2
	box(self,Vector3(6.8,0.60,0.12),Vector3(0,4.48,-0.12),iron)
	var sign := Label3D.new()
	sign.name = "WorkshopSign"
	sign.text = "OFFICINA DEL VAPORE"
	sign.font_size = 64
	sign.pixel_size = 0.005
	sign.modulate = Color("d9b982")
	sign.outline_size = 3
	sign.position = Vector3(0,4.48,-0.03)
	add_child(sign)

func _process(delta: float) -> void:
	if wheel == null: return
	phase = fposmod(phase+maxf(delta,0.0)*0.22,TAU)
	wheel.rotation.z = phase
	for i in rods.size():
		rods[i].position.y = 3.15 + sin(phase+(PI if i == 1 else 0.0))*0.12

static func material(color: Color,metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.8
	return mat
static func piece(parent: Node3D,mesh: Mesh,at: Vector3,mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
static func box(parent: Node3D,size: Vector3,at: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return piece(parent,mesh,at,mat)
