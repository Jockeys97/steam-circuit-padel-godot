## abyssal_forge.gd — "Forgia Abyssal" rebuilt (2026-09-25) from the owner's cover and his
## three Meshy props (`godot/assets/arenas/forgia/`): a forge on the sea floor. Dark teal
## water and dense sea haze, bubbles rising, magma channels flanking the court, furnaces
## and steam-hammer anvils beside it, braziers along the edge, and a riveted iron wall of
## magma portholes around the far end.
##
## Composition follows the gameplay camera (36 deg down, ~20 m to the sides, ~22 m back):
## the channels, the furnaces and anvils on the sides and the braziers are in its frame;
## the porthole wall and the big rear furnace are for the lower cameras and menu shots.
## Presentation only: no light nodes, no colliders; props load through the arena kit's
## runtime loader (`ArenaKit._load_scene`), so a missing GLB leaves a gap, never an error.
extends Node3D

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const DIR := "res://assets/arenas/forgia/"

const CH_IN := 12.0      # magma channels: from 12 m ...
const CH_OUT := 15.5     # ... to 15.5 m out on each side
const BACK_IN := -19.0
const BACK_OUT := -23.5

const COLORS := {
	"basalt": Color("15161b"),
	"iron": Color("20262b"),
	"brass": Color("8c6a3a"),
	"teal_iron": Color("173a40"),
}

static var _sky_cache: Texture2D = null


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var f := new()
	f.name = "AbyssalForge"
	scenery.add_child(f)
	f._build_water(arena_root)
	f._build_channels()
	f._build_wall()
	f._build_props()
	f._build_bubbles()
	return f


# ---------------------------------------------------------------------------
# Water and light
# ---------------------------------------------------------------------------

func _build_water(arena_root: Node3D) -> void:
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we != null and we.environment != null:
		var env := we.environment
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = _abyss_panorama()
		sky.sky_material = mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.30, 0.52, 0.56)
		env.ambient_light_energy = 0.5
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.95
		env.glow_bloom = 0.06
		env.glow_hdr_threshold = 1.0
		# Water: a dense teal haze that swallows the far forge.
		env.fog_enabled = true
		env.fog_light_color = Color(0.04, 0.16, 0.19)
		env.fog_density = 0.012
		env.fog_sky_affect = 0.4
	if sun != null:
		# Cold light filtering down from the surface far above.
		sun.light_color = Color(0.62, 0.88, 0.92)
		sun.light_energy = 0.75
		sun.rotation_degrees = Vector3(-70.0, 20.0, 0.0)
	if fill != null:
		# The magma's warm up-light from the channels and furnaces.
		fill.light_color = Color(1.0, 0.62, 0.36)
		fill.light_energy = 0.45
		fill.rotation_degrees = Vector3(-25.0, 170.0, 0.0)


static func _abyss_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var w := 1024
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color("0f3a44")   # the surface glow, far above
	var mid := Color("062129")
	var horizon := Color("041419")
	for y in h:
		var t := float(y) / float(h - 1)
		var c := top.lerp(mid, clampf(t / 0.35, 0.0, 1.0)) if t < 0.35 else mid.lerp(horizon, clampf((t - 0.35) / 0.2, 0.0, 1.0))
		for x in w:
			# Faint shafts of surface light.
			var shaft := maxf(0.0, sin(float(x) * 0.043 + sin(float(x) * 0.011) * 3.0)) * maxf(0.0, 0.45 - t) * 0.12
			img.set_pixel(x, y, c + Color(shaft * 0.6, shaft, shaft))
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


# ---------------------------------------------------------------------------
# Magma channels
# ---------------------------------------------------------------------------

func _build_channels() -> void:
	var lava := ShaderMaterial.new()
	lava.shader = preload("res://game/arenas/lava_flow.gdshader")
	lava.set_shader_parameter("energy", 1.3)
	var strips := [
		Rect2(-CH_OUT, BACK_OUT, CH_OUT * 2.0, BACK_IN - BACK_OUT),     # behind the court
		Rect2(-CH_OUT, BACK_IN, CH_OUT - CH_IN, 44.0),                  # left
		Rect2(CH_IN, BACK_IN, CH_OUT - CH_IN, 44.0),                    # right
	]
	var i := 0
	for r in strips:
		var mi := MeshInstance3D.new()
		mi.name = "Magma%d" % i
		var pm := PlaneMesh.new()
		pm.size = r.size
		mi.mesh = pm
		mi.material_override = lava
		mi.position = Vector3(r.position.x + r.size.x * 0.5, 0.03, r.position.y + r.size.y * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		i += 1
	var b := {}
	for side in [-1.0, 1.0]:
		_box(b, "teal_iron", Vector3(0.5, 0.4, 44.0), Vector3(side * (CH_IN - 0.25), 0.2, BACK_IN + 22.0))
		_box(b, "basalt", Vector3(3.0, 1.3, 50.0), Vector3(side * (CH_OUT + 1.5), 0.65, BACK_IN + 20.0))
	_box(b, "teal_iron", Vector3(CH_IN * 2.0, 0.4, 0.5), Vector3(0, 0.2, BACK_IN + 0.25))
	_box(b, "basalt", Vector3(CH_OUT * 2.0 + 6.0, 1.3, 3.0), Vector3(0, 0.65, BACK_OUT - 1.5))
	# Basalt shelves beyond the channels, where the forge machinery stands.
	_box(b, "basalt", Vector3(120.0, 1.2, 60.0), Vector3(0, 0.6, BACK_OUT - 3.0 - 30.0))
	for side in [-1.0, 1.0]:
		_box(b, "basalt", Vector3(60.0, 1.2, 110.0), Vector3(side * (CH_OUT + 3.0 + 30.0), 0.6, 5.0))
	_flush(b)


# ---------------------------------------------------------------------------
# The riveted porthole wall (lower cameras)
# ---------------------------------------------------------------------------

func _build_wall() -> void:
	var b := {}
	var r := 40.0
	for k in 17:
		var a := -PI * 0.5 + PI * float(k) / 16.0 - PI * 0.5
		var p := Vector3(cos(a) * r, 0, sin(a) * r * 0.85 - 6.0)
		var yaw := atan2(-p.x, -p.z)
		var basis := Basis(Vector3.UP, yaw)
		_rs_box(b, "iron", basis, Vector3(9.0, 16.0, 1.2), p + Vector3(0, 8.0, 0))
		_rs_box(b, "brass", basis, Vector3(9.2, 0.5, 1.4), p + Vector3(0, 15.8, 0))
		_rs_box(b, "brass", basis, Vector3(0.5, 16.0, 1.4), p + basis.x * 4.5 + Vector3(0, 8.0, 0))
		# A glowing magma porthole in each panel.
		var glow := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.5
		cm.bottom_radius = 1.5
		cm.height = 0.3
		cm.radial_segments = 16
		glow.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 0.3, 0.08)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.38, 0.08)
		m.emission_energy_multiplier = 1.6
		glow.material_override = m
		# Riveted brass rim around the porthole.
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.5
		tm.outer_radius = 1.95
		tm.rings = 20
		tm.ring_segments = 8
		rim.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = COLORS["brass"]
		rm.metallic = 0.6
		rm.roughness = 0.5
		rim.material_override = rm
		rim.basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
		rim.position = p + Vector3(0, 8.5, 0) + basis.z * 0.7
		add_child(rim)
		glow.basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
		glow.position = p + Vector3(0, 8.5, 0) + basis.z * 0.65
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
	_flush(b)


# ---------------------------------------------------------------------------
# The owner's Meshy props
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var furnace := ArenaKit._load_scene(DIR + "hero_landmark.glb")
	var anvil := ArenaKit._load_scene(DIR + "ornament_accent.glb")
	var brazier := ArenaKit._load_scene(DIR + "light_source.glb")
	var shelf_y := 1.2
	if furnace != null:
		var k := 0
		for spot in [[Vector3(-19.5, shelf_y, -13.0), 9.0, 90.0], [Vector3(19.5, shelf_y, -13.0), 9.0, -90.0], [Vector3(0.0, shelf_y, -30.0), 16.0, 0.0]]:
			_place(furnace, "Furnace%d" % k, spot[0], float(spot[1]), float(spot[2]))
			k += 1
	if anvil != null:
		var k := 0
		# Behind the back glass corners: the only spot beyond the stands the gameplay camera
		# keeps in frame; the other pair stands on the side shelves for the lower cameras.
		for spot in [[Vector3(-7.8, 0.0, -15.2), 3.4, 20.0], [Vector3(7.8, 0.0, -15.2), 3.4, 160.0],
				[Vector3(-18.3, shelf_y, 4.0), 5.0, 90.0], [Vector3(18.3, shelf_y, 4.0), 5.0, -90.0]]:
			_place(anvil, "Anvil%d" % k, spot[0], float(spot[1]), float(spot[2]))
			k += 1
	if brazier != null:
		var k := 0
		for side in [-1.0, 1.0]:
			for z in [-14.0, -4.0, 6.0, 16.0]:
				var p := Vector3(side * (CH_IN - 1.4), 0.0, z)
				_place(brazier, "Brazier%d" % k, p, 1.4, float(k) * 40.0)
				_glow(p + Vector3(0, 1.25, 0), 0.35)
				k += 1


## Meshy delivers each prop 1 m on its largest side, centred: scale to `height`, lift by
## the model's own half height (its `min_y`, measured on import, is ~ -0.5 * height).
func _place(source: Node3D, node_name: String, pos: Vector3, height: float, yaw_deg: float) -> void:
	var piece := source.duplicate() as Node3D
	piece.name = node_name
	piece.scale = Vector3.ONE * height
	piece.rotation_degrees = Vector3(0, yaw_deg, 0)
	piece.position = pos + Vector3(0, height * 0.5, 0)
	add_child(piece)


func _glow(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.5, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.12)
	m.emission_energy_multiplier = 4.5
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------------------
# Bubbles
# ---------------------------------------------------------------------------

func _build_bubbles() -> void:
	var qm := SphereMesh.new()
	qm.radius = 0.06
	qm.height = 0.12
	qm.radial_segments = 6
	qm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.95, 1.0, 0.55)
	qm.material = m
	for spot in [Vector3(-15.2, 0.1, 0), Vector3(15.2, 0.1, 0), Vector3(0, 0.1, -21.2)]:
		var p := CPUParticles3D.new()
		p.name = "Bubbles"
		p.amount = 60
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(2.0, 0.1, 20.0) if absf(spot.x) > 1.0 else Vector3(16.0, 0.1, 2.0)
		p.direction = Vector3.UP
		p.spread = 8.0
		p.gravity = Vector3(0, 1.2, 0)
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		p.mesh = qm
		p.position = spot
		add_child(p)


# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

func _box(b: Dictionary, color: String, size: Vector3, pos: Vector3) -> void:
	b.get_or_add(color, []).append(Transform3D(Basis.from_scale(size), pos))


func _rs_box(b: Dictionary, color: String, rot: Basis, size: Vector3, pos: Vector3) -> void:
	b.get_or_add(color, []).append(Transform3D(rot * Basis.from_scale(size), pos))


func _flush(b: Dictionary) -> void:
	for key in b:
		var xfs: Array = b[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mm.mesh = bm
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch_" + String(key)
		mmi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS.get(key, Color(0.2, 0.2, 0.2))
		m.roughness = 0.9
		mmi.material_override = m
		add_child(mmi)
