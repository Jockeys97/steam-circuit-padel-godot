## Two cutaway halls. Decorative only: no sim, collision or dynamic lighting.
extends Node3D
const Kit = preload("res://game/arenas/steam_workshop.gd")
const Pieces = preload("res://game/arenas/workshop_engine.gd")
var clock_hands: Array[Node3D] = []
var gears: Array[Node3D] = []
var phase := 0.0

func assemble(id: String,scenery: Node3D) -> void:
	name = "LocomotiveDepot" if id == "locomotive" else "ClockworkFactory"
	var b := {}
	var depot := id == "locomotive"
	var colors := {"brick":Color("26343c") if depot else Color("302638"),"iron":Color("202d32"),"copper":Color("27604b") if depot else Color("94633e"),"brass":Color("b29455"),"window":Color("76999d") if depot else Color("8e648d")}
	Kit.box(b,"brick",Vector3(32,5.8,0.4),Vector3(0,2.9,-13.4))
	for x in [-14.0,-10.0,-6.0,6.0,10.0,14.0]:
		Kit.box(b,"window",Vector3(2.5,2.6,0.06),Vector3(x,3.5,-13.16))
		for dx in [-1.25,0.0,1.25]: Kit.box(b,"iron",Vector3(0.09,2.8,0.12),Vector3(x+dx,3.5,-13.08))
		for y in [2.2,3.5,4.8]: Kit.box(b,"iron",Vector3(2.7,0.10,0.12),Vector3(x,y,-13.08))
		Kit.box(b,"iron",Vector3(0.35,5.8,0.65),Vector3(x+1.65,2.9,-13.0))
		Kit.box(b,"brass",Vector3(0.60,0.18,0.80),Vector3(x+1.65,0.16,-13.0))
	# Trusses only over the rear service band: never above the playing volume.
	Kit.box(b,"iron",Vector3(32,0.20,0.45),Vector3(0,5.50,-12.85))
	for x in range(-14,15,2):
		Kit.add(b,"box_iron",Transform3D(Basis.IDENTITY.scaled(Vector3(2.1,0.09,0.15)).rotated(Vector3.BACK,0.32 if x%4 == 0 else -0.32),Vector3(x,5.13,-12.83)))
	for side in [-1.0,1.0]:
		Kit.box(b,"brick",Vector3(0.35,0.45,25),Vector3(side*12.5,0.22,0))
		Kit.box(b,"brass",Vector3(0.05,0.02,25),Vector3(side*6.0,0.01,0))
	if depot: build_train(b)
	else: build_clock(b)
	Kit.flush_batches(self,b,colors)
	Kit.dress_fabric(scenery)
	set_process(not depot)

func build_train(b: Dictionary) -> void:
	for z in [-11.15,-12.70]: Kit.box(b,"iron",Vector3(24,0.10,0.09),Vector3(0,0.11,z))
	for x in range(-12,13): Kit.box(b,"copper",Vector3(0.18,0.08,2.0),Vector3(x,0.03,-11.92))
	var fixed_batches := b
	b = {}
	var train := preload("res://game/arenas/passing_train.gd").new()
	train.name = "PassingTrain"
	add_child(train)
	Kit.box(b,"iron",Vector3(9.1,0.28,1.30),Vector3(-0.7,0.75,-11.95))
	Kit.cylinder(b,"copper",Vector3(0.78,6.0,0.78),Vector3(0.0,1.75,-11.95),PI/2)
	for x in [-2.7,-1.4,0.0,1.4,2.7]:
		Kit.cylinder(b,"brass",Vector3(0.81,0.12,0.81),Vector3(x,1.75,-11.95),PI/2)
	Kit.box(b,"copper",Vector3(2.0,2.20,1.65),Vector3(-4.0,1.85,-12.05))
	Kit.box(b,"iron",Vector3(2.35,0.20,1.90),Vector3(-4.0,3.04,-12.05))
	Kit.box(b,"window",Vector3(1.3,0.90,0.06),Vector3(-4.0,2.25,-11.19))
	Kit.box(b,"brass",Vector3(0.07,1.0,0.08),Vector3(-4.0,2.25,-11.13))
	for x in [-4.65,-3.35]:
		for y in [1.1,1.4,1.7]:
			Kit.add(b,"cylinder_brass",Transform3D(Basis.IDENTITY.scaled(Vector3(0.045,0.04,0.045)).rotated(Vector3.RIGHT,PI/2),Vector3(x,y,-11.19)))
	Kit.cylinder(b,"brass",Vector3(0.22,0.5,0.22),Vector3(-0.7,2.68,-11.95))
	Kit.cylinder(b,"iron",Vector3(0.23,1.1,0.23),Vector3(2.2,2.93,-11.95))
	Kit.cylinder(b,"brass",Vector3(0.34,0.13,0.34),Vector3(2.2,3.50,-11.95))
	Kit.steam(train,Vector3(2.2,3.57,-11.95))
	for x in [-3.9,-2.2,-0.5,1.2,2.9]:
		var t := Transform3D(Basis.IDENTITY.scaled(Vector3(0.57,0.16,0.57)).rotated(Vector3.RIGHT,PI/2),Vector3(x,0.62,-11.18))
		Kit.add(b,"cylinder_iron",t)
		Kit.add(b,"torus_brass",Transform3D(Basis.IDENTITY.scaled(Vector3(0.54,0.54,0.54)).rotated(Vector3.RIGHT,PI/2),Vector3(x,0.62,-11.06)))
		for i in 3:
			var spoke := Transform3D(Basis.IDENTITY.scaled(Vector3(0.92,0.05,0.06)).rotated(Vector3.BACK,i*PI/3.0),Vector3(x,0.62,-11.02))
			train.wheel_spokes.append({"index":b["box_brass"].size(),"transform":spoke})
			Kit.add(b,"box_brass",spoke)
	Kit.box(b,"brass",Vector3(6.9,0.07,0.08),Vector3(-0.5,0.60,-10.96))
	Kit.flush_batches(train,b,{"iron":Color("202d32"),"copper":Color("27604b"),"brass":Color("b29455"),"window":Color("76999d")})
	b = fixed_batches
	for side in [-1.0,1.0]:
		for i in 2:
			var at := Vector3(side*(9.0+i*1.1),0.5,-10.25)
			Kit.box(b,"copper",Vector3(0.95,0.95,0.9),at)
			for offset in [-0.3,0.3]: Kit.box(b,"iron",Vector3(0.07,0.98,0.94),at+Vector3(offset,0,0))
		Kit.box(b,"iron",Vector3(0.15,2.6,0.15),Vector3(side*7.0,1.3,-10.35))
		Kit.box(b,"brass",Vector3(0.50,0.75,0.25),Vector3(side*7.0,2.4,-10.35))
		Kit.box(b,"window",Vector3(0.24,0.24,0.04),Vector3(side*7.0,2.55,-10.19))
	add_sign("DEPOSITO LOCOMOTIVE  •  BINARIO 07",Vector3(0,4.4,-12.9),0.0045)

func build_clock(b: Dictionary) -> void:
	var face := CylinderMesh.new()
	face.top_radius = 1.80
	face.bottom_radius = 1.80
	face.height = 0.10
	face.radial_segments = 64
	var face_mat := Pieces.material(Color("cbbd90"),0.15)
	var disc := Pieces.piece(self,face,Vector3(0,2.5,-12.40),face_mat)
	disc.rotation.x = PI/2
	var rim := TorusMesh.new()
	rim.inner_radius = 1.75
	rim.outer_radius = 1.90
	rim.rings = 48
	rim.ring_segments = 6
	var rim_node := Pieces.piece(self,rim,Vector3(0,2.5,-12.36),Pieces.material(Color("b29455"),0.5))
	rim_node.rotation.x = PI/2
	for i in 12:
		var a := float(i)*TAU/12
		Kit.add(b,"box_iron",Transform3D(Basis.IDENTITY.scaled(Vector3(0.06,0.22,0.08)).rotated(Vector3.BACK,-a),Vector3(sin(a)*1.56,2.5+cos(a)*1.56,-12.27)))
		if i%3 == 0:
			var number := Label3D.new()
			number.text = str(12 if i == 0 else i)
			number.font_size = 64
			number.pixel_size = 0.004
			number.modulate = Color("302b39")
			number.outline_size = 0
			number.position = Vector3(sin(a)*1.25,2.5+cos(a)*1.25,-12.25)
			add_child(number)
	for i in 2:
		var pivot := Node3D.new()
		pivot.name = "MinuteHand" if i == 0 else "HourHand"
		pivot.position = Vector3(0,2.5,-12.15-i*0.04)
		add_child(pivot)
		var length := 1.25 if i == 0 else 0.85
		Pieces.box(pivot,Vector3(0.065 if i == 0 else 0.11,length,0.07),Vector3(0,length*0.45,0),Pieces.material(Color("252335"),0.2))
		clock_hands.append(pivot)
	for side in [-1.0,1.0]:
		make_gear(Vector3(side*3.4,2.3,-12.0),1.4)
		make_gear(Vector3(side*5.6,1.7,-12.0),0.85)
		Kit.cylinder(b,"copper",Vector3(0.34,3.5,0.34),Vector3(side*8.0,1.8,-12.15))
		for y in [0.3,1.2,2.3,3.4]: Kit.cylinder(b,"brass",Vector3(0.38,0.12,0.38),Vector3(side*8.0,y,-12.15))
	add_sign("FABBRICA DEGLI OROLOGI",Vector3(0,5.15,-12.80),0.004)
	_process(0.0)

func make_gear(at: Vector3,radius: float) -> void:
	var gear := Node3D.new()
	gear.position = at
	add_child(gear)
	var teeth := {}
	for i in 16:
		var a := float(i)*TAU/16
		Kit.add(teeth,"box_brass",Transform3D(Basis.IDENTITY.scaled(Vector3(radius*0.23,radius*0.23,0.16)).rotated(Vector3.BACK,a),Vector3(cos(a)*radius,sin(a)*radius,0)))
	Kit.add(teeth,"torus_brass",Transform3D(Basis.IDENTITY.scaled(Vector3(radius*0.9,radius*0.9,radius*0.9)).rotated(Vector3.RIGHT,PI/2),Vector3.ZERO))
	for i in 3:
		Kit.add(teeth,"box_iron",Transform3D(Basis.IDENTITY.scaled(Vector3(radius*1.7,0.12,0.12)).rotated(Vector3.BACK,i*PI/3.0),Vector3.ZERO))
	Kit.flush_batches(gear,teeth,{"brass":Color("a9894d"),"iron":Color("36313c")})
	gears.append(gear)

func _process(delta: float) -> void:
	# Keep a continuous shared phase: wrapping it would snap unequal gear ratios.
	phase += maxf(delta,0.0)*0.035
	for i in clock_hands.size(): clock_hands[i].rotation.z = -phase/(1.0 if i == 0 else 12.0)+(-0.6 if i == 0 else 1.2)
	for i in gears.size():
		# Adjacent wheels have opposite rotation, inversely proportional to radius.
		gears[i].rotation.z = phase*(1.0 if i%2 == 0 else -1.4/0.85)

func add_sign(text: String,at: Vector3,pixel: float):
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 64
	label.pixel_size = pixel
	label.modulate = Color("d2b775")
	label.outline_size = 6
	add_child(label)
