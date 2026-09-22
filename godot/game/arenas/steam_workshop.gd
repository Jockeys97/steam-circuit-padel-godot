## Officina pilot: cutaway industrial hall, entirely outside the playable cage.
## Batched primitives, no collision, extra lights, shadows or paid/generated assets.
extends RefCounted

static func build(scenery: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "SteamWorkshop"
	scenery.add_child(root)
	var engine := preload("res://game/arenas/workshop_engine.gd").new()
	root.add_child(engine)
	engine.assemble()
	var batches := {}
	var colors := {"brick":Color("342b2b"), "iron":Color("242e38"), "copper":Color("ac6940"), "brass":Color("cf9e58"), "window":Color("efb86a")}
	box(batches,"brick",Vector3(32,5.6,0.4),Vector3(0,2.8,-13.0))
	# Masonry courses and structural pilasters supply readable depth, not a photo.
	for y in range(1,12):
		box(batches,"iron",Vector3(32,0.025,0.045),Vector3(0,y*0.46,-12.76))
	for x in [-14.0,-10.0,-6.0,-2.0,2.0,6.0,10.0,14.0]:
		box(batches,"iron",Vector3(0.32,5.8,0.55),Vector3(x+1.7,2.9,-12.6))
		box(batches,"brass",Vector3(0.55,0.18,0.72),Vector3(x+1.7,0.22,-12.5))
		box(batches,"window",Vector3(2.6,1.4,0.07),Vector3(x,3.05,-12.72))
		add(batches,"cylinder_window",Transform3D(Basis.IDENTITY.scaled(Vector3(1.3,0.07,1.3)).rotated(Vector3.RIGHT,PI/2),Vector3(x,3.75,-12.72)))
		for step in 12:
			var a := (float(step)+0.5)*PI/12.0
			add(batches,"box_iron",Transform3D(Basis.IDENTITY.scaled(Vector3(0.39,0.13,0.15)).rotated(Vector3.BACK,a+PI/2),Vector3(x+cos(a)*1.37,3.75+sin(a)*1.37,-12.58)))
		for y in [0.9,1.8,2.7,3.6,4.5]:
			add(batches,"cylinder_brass",Transform3D(Basis.IDENTITY.scaled(Vector3(0.055,0.06,0.055)).rotated(Vector3.RIGHT,PI/2),Vector3(x+1.7,y,-12.29)))
		for dx in [-1.3,0.0,1.3]:
			box(batches,"iron",Vector3(0.07,2.5,0.12),Vector3(x+dx,3.6,-12.64))
		for y in [2.45,3.6,4.75]:
			box(batches,"iron",Vector3(2.75,0.09,0.12),Vector3(x,y,-12.62))
	box(batches,"iron",Vector3(32,0.30,0.65),Vector3(0,5.25,-12.5))
	box(batches,"iron",Vector3(32,0.20,0.50),Vector3(0,0.65,-12.5))
	# Copper service manifold and two pressure boilers frame the centre window.
	cylinder(batches,"copper",Vector3(0.13,28,0.13),Vector3(0,1.1,-12.25),PI/2)
	for x in [-8.6,8.6]:
		cylinder(batches,"copper",Vector3(0.8,2.8,0.8),Vector3(x,1.5,-11.75))
		add(batches,"sphere_copper",Transform3D(Basis.IDENTITY.scaled(Vector3(0.8,0.28,0.8)),Vector3(x,2.92,-11.75)))
		var valve := Vector3(x+1.1,1.45,-11.6)
		add(batches,"torus_brass",Transform3D(Basis.IDENTITY.scaled(Vector3(0.3,0.3,0.3)).rotated(Vector3.RIGHT,PI/2),valve))
		for spoke in 3:
			add(batches,"box_iron",Transform3D(Basis.IDENTITY.scaled(Vector3(0.5,0.04,0.06)).rotated(Vector3.BACK,float(spoke)*PI/3),valve))
		for y in [0.28,1.0,2.0,2.8]:
			cylinder(batches,"brass",Vector3(0.85,0.12,0.85),Vector3(x,y,-11.75))
		cylinder(batches,"iron",Vector3(0.2,1.6,0.2),Vector3(x,3.45,-11.75))
		box(batches,"iron",Vector3(1.8,0.18,1.65),Vector3(x,0.08,-11.75))
		# Front pressure dial; flat disc oriented toward the court.
		var dial := Transform3D(Basis.IDENTITY.scaled(Vector3(0.28,0.07,0.28)).rotated(Vector3.RIGHT,PI/2),Vector3(x,2.1,-10.91))
		add(batches,"cylinder_brass",dial)
		box(batches,"iron",Vector3(0.035,0.30,0.08),Vector3(x,2.15,-10.83))
		steam(root,Vector3(x,4.25,-11.75))
	# Cutaway perimeter: low side plinths, never a roof over the ball or camera.
	for side in [-1.0,1.0]:
		for z in range(-12,14,2):
			box(batches,"iron",Vector3(6.0,0.012,0.035),Vector3(side*9.0,0.002,z))
		box(batches,"brass",Vector3(0.06,0.012,25),Vector3(side*6.0,0.002,0))
		box(batches,"brick",Vector3(0.4,0.55,25),Vector3(side*12.5,0.26,0))
		for z in [-8.0,-2.0,4.0,10.0]:
			box(batches,"iron",Vector3(0.42,0.95,0.42),Vector3(side*12.5,0.47,z))
			box(batches,"brass",Vector3(0.6,0.12,0.6),Vector3(side*12.5,1.0,z))
	# Each mesh/material family becomes one draw batch instead of one per brick.
	flush_batches(root,batches,colors)
	dress_fabric(scenery)
	return root

static func flush_batches(root: Node3D,batches: Dictionary,colors: Dictionary) -> void:
	for key in batches:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var mesh: PrimitiveMesh
		if String(key).begins_with("box_"):
			mesh = BoxMesh.new()
			mesh.size = Vector3.ONE
		elif String(key).begins_with("sphere_"):
			mesh = SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.0
			mesh.radial_segments = 12
			mesh.rings = 4
		elif String(key).begins_with("torus_"):
			mesh = TorusMesh.new()
			mesh.inner_radius = 0.70
			mesh.outer_radius = 1.0
			mesh.rings = 12
			mesh.ring_segments = 6
		else:
			mesh = CylinderMesh.new()
			mesh.top_radius = 1.0
			mesh.bottom_radius = 1.0
			mesh.height = 1.0
			mesh.radial_segments = 12
		var tint: String = String(key).get_slice("_",1)
		if tint == "window":
			var glow := StandardMaterial3D.new()
			glow.albedo_color = colors[tint]
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material = glow
		else:
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://game/arenas/workshop_surface.gdshader")
			mat.set_shader_parameter("tint",colors[tint])
			mat.set_shader_parameter("masonry",tint == "brick")
			mat.set_shader_parameter("metalness",0.45 if tint in ["copper","brass"] else 0.1)
			mesh.material = mat
		mm.mesh = mesh
		mm.instance_count = batches[key].size()
		for i in mm.instance_count: mm.set_instance_transform(i,batches[key][i])
		var node := MultiMeshInstance3D.new()
		node.name = key
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	# Per-instance overrides only: never recolour the cached GLBs used elsewhere.
static func dress_fabric(scenery: Node3D) -> void:
	for group_name in ["Bleachers","ArenaProps"]:
		var group := scenery.get_node_or_null(group_name)
		if group == null: continue
		for mesh_node in group.find_children("*","MeshInstance3D",true,false):
			var ancestor: Node = mesh_node
			var sponsor := false
			while ancestor != group and ancestor != null:
				sponsor = sponsor or String(ancestor.name).begins_with("Sponsor")
				ancestor = ancestor.get_parent()
			if sponsor: continue
			for surface in mesh_node.mesh.get_surface_count():
				var source = mesh_node.get_active_material(surface)
				if not source is StandardMaterial3D or source.albedo_texture == null: continue
				var fabric := ShaderMaterial.new()
				fabric.shader = preload("res://game/arenas/workshop_fabric.gdshader")
				fabric.set_shader_parameter("albedo_texture",source.albedo_texture)
				fabric.set_shader_parameter("base_color",source.albedo_color)
				mesh_node.set_surface_override_material(surface,fabric)

static func add(batches: Dictionary,key: String,transform: Transform3D):
	if not batches.has(key): batches[key] = []
	batches[key].append(transform)
static func box(batches: Dictionary,color: String,size: Vector3,position: Vector3):
	add(batches,"box_"+color,Transform3D(Basis.IDENTITY.scaled(size),position))
static func cylinder(batches: Dictionary,color: String,size: Vector3,position: Vector3,angle := 0.0):
	add(batches,"cylinder_"+color,Transform3D(Basis.IDENTITY.scaled(size).rotated(Vector3.FORWARD,angle),position))
static func steam(parent: Node3D,position: Vector3):
	var p := CPUParticles3D.new()
	p.name = "SteamVent"
	p.position = position
	p.amount = 6
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0,0.15,0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.5
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.22
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.65,0.7,0.73,0.12)
	sphere.material = mat
	p.mesh = sphere
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
