## storm_bastion.gd — "Bastione della Tempesta" rebuilt (2026-09-25) from the owner's cover and
## his three Meshy props (`godot/assets/arenas/tempesta/`): the court on a plank-and-iron
## deck floating in a thunderstorm, a sea of storm clouds below, airships drifting around,
## lightning-rod towers crackling at the corners, ship lanterns on the rail, and distant
## lightning that lights the clouds from inside.
##
## Composition follows the gameplay camera (36 deg down, it sees ~20 m to the sides and
## ~22 m back): the deck edge and the cloud void beyond it, the towers and the near
## airships are in its frame; the far airship and the sky are for the lower cameras.
## Presentation only: no light nodes, no colliders. Props load through the arena kit's
## runtime loader (`ArenaKit._load_scene`); a missing GLB leaves a gap, never an error.
extends Node3D

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const DIR := "res://assets/arenas/tempesta/"

const DECK_X := 15.0
const DECK_BACK := -22.0
const DECK_FRONT := 26.0

const COLORS := {
	"plank_a": Color("4a3526"),
	"plank_b": Color("3b2a1f"),
	"iron": Color("262a33"),
	"brass": Color("9c7c3f"),
	"hull": Color("1c1f27"),
}

var _clouds: ShaderMaterial
var _env: Environment
var _ambient_base := 0.0
var _flash := 0.0
var _next_bolt := 3.0
var _bolt: Node3D
var _crackles: Array[MeshInstance3D] = []
var _ships: Array[Node3D] = []
var _ship_base: Array[Vector3] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()

static var _sky_cache: Texture2D = null


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var s := new()
	s.name = "StormBastion"
	scenery.add_child(s)
	s._rng.seed = 5150
	var surround := arena_root.get_node_or_null("Surround") as Node3D
	if surround != null:
		surround.hide() # the deck floats: below it is the cloud sea, not ground
	s._build_sky(arena_root)
	s._build_clouds()
	s._build_deck()
	s._build_props()
	s._build_bolt()
	s.set_process(true)
	return s


# ---------------------------------------------------------------------------
# Sky and light
# ---------------------------------------------------------------------------

func _build_sky(arena_root: Node3D) -> void:
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we != null and we.environment != null:
		_env = we.environment
		_env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = _storm_panorama()
		sky.sky_material = mat
		_env.sky = sky
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color(0.36, 0.44, 0.66)
		_env.ambient_light_energy = 0.5
		_ambient_base = 0.5
		_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_env.glow_enabled = true
		_env.glow_intensity = 0.9
		_env.glow_bloom = 0.05
		_env.glow_hdr_threshold = 1.0
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.08, 0.11, 0.22)
		_env.fog_density = 0.0035
		_env.fog_sky_affect = 0.0
	if sun != null:
		# Cold storm light from above the far end.
		sun.light_color = Color(0.74, 0.82, 1.0)
		sun.light_energy = 0.85
		sun.rotation_degrees = Vector3(-55.0, 150.0, 0.0)
	if fill != null:
		# Warm lantern-and-floodlight fill from behind the camera.
		fill.light_color = Color(1.0, 0.86, 0.66)
		fill.light_energy = 0.55
		fill.rotation_degrees = Vector3(-50.0, -10.0, 0.0)


static func _storm_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var w := 1024
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color("050912")
	var mid := Color("111c38")
	var horizon := Color("2a3f6e")
	var below := Color("070b16")
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	# Cheap cloud banks: sine-warped value bands, darker lumps over the gradient.
	var ph := []
	for k in 6:
		ph.append(rng.randf_range(0.0, TAU))
	for y in h:
		var t := float(y) / float(h - 1)
		var base: Color
		if t < 0.4:
			base = top.lerp(mid, t / 0.4)
		elif t < 0.5:
			base = mid.lerp(horizon, (t - 0.4) / 0.1)
		else:
			base = horizon.lerp(below, clampf((t - 0.5) / 0.06, 0.0, 1.0))
		for x in w:
			var u := float(x) / float(w) * TAU
			var lump := 0.0
			for k in 3:
				lump += sin(u * (k + 2) + ph[k] + t * (7.0 + k * 3.0) + sin(u * 5.0 + ph[k + 3]) * 0.6)
			lump = clampf(lump / 3.0, -1.0, 1.0)
			var c := base.lerp(Color("1b2a4e"), clampf(lump * 0.5, 0.0, 0.5)) if t < 0.5 else base
			img.set_pixel(x, y, c)
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


func _build_clouds() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1100, 1100)
	sea.mesh = pm
	_clouds = ShaderMaterial.new()
	_clouds.shader = preload("res://game/arenas/storm_clouds.gdshader")
	sea.material_override = _clouds
	sea.position = Vector3(0, -24.0, 0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)


# ---------------------------------------------------------------------------
# The deck
# ---------------------------------------------------------------------------

func _build_deck() -> void:
	var b := {}
	# Planks along the court's length, two alternating tones, over an iron frame.
	var n := int(DECK_X * 2.0 / 0.9)
	for i in n:
		var x := -DECK_X + 0.45 + float(i) * 0.9
		# Top at -4 cm: level with the court floor the two z-fought and the planks painted
		# over the court in the match camera's frame.
		_box(b, "plank_a" if i % 2 == 0 else "plank_b", Vector3(0.86, 0.3, DECK_FRONT - DECK_BACK), Vector3(x, -0.19, (DECK_FRONT + DECK_BACK) * 0.5))
	_box(b, "hull", Vector3(DECK_X * 2.0 + 1.0, 2.6, DECK_FRONT - DECK_BACK + 1.0), Vector3(0, -1.6, (DECK_FRONT + DECK_BACK) * 0.5))
	# Iron rim and a keel-like underside that tapers into the void.
	for side in [-1.0, 1.0]:
		_box(b, "iron", Vector3(0.5, 0.5, DECK_FRONT - DECK_BACK + 1.0), Vector3(side * (DECK_X + 0.25), 0.1, (DECK_FRONT + DECK_BACK) * 0.5))
	_box(b, "iron", Vector3(DECK_X * 2.0 + 1.0, 0.5, 0.5), Vector3(0, 0.1, DECK_BACK - 0.25))
	_box(b, "hull", Vector3(DECK_X * 1.2, 5.0, (DECK_FRONT - DECK_BACK) * 0.7), Vector3(0, -5.0, (DECK_FRONT + DECK_BACK) * 0.5))
	# Rail: iron posts with a brass top rail along the sides and the back.
	var posts: Array[Vector3] = []
	var z := DECK_BACK
	while z <= DECK_FRONT:
		for side in [-1.0, 1.0]:
			posts.append(Vector3(side * (DECK_X + 0.25), 0, z))
		z += 3.0
	var x := -DECK_X
	while x <= DECK_X:
		posts.append(Vector3(x, 0, DECK_BACK - 0.25))
		x += 3.0
	for p in posts:
		_box(b, "iron", Vector3(0.16, 1.1, 0.16), p + Vector3(0, 0.55, 0))
	for side in [-1.0, 1.0]:
		_box(b, "brass", Vector3(0.1, 0.1, DECK_FRONT - DECK_BACK), Vector3(side * (DECK_X + 0.25), 1.1, (DECK_FRONT + DECK_BACK) * 0.5))
	_box(b, "brass", Vector3(DECK_X * 2.0, 0.1, 0.1), Vector3(0, 1.1, DECK_BACK - 0.25))
	_flush(b)


# ---------------------------------------------------------------------------
# The owner's Meshy props
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var ship := ArenaKit._load_scene(DIR + "hero_landmark.glb")
	var tower := ArenaKit._load_scene(DIR + "column_pillar.glb")
	var lantern := ArenaKit._load_scene(DIR + "light_source.glb")
	if tower != null:
		var k := 0
		for p in [Vector3(-DECK_X + 1.2, 0, DECK_BACK + 1.2), Vector3(DECK_X - 1.2, 0, DECK_BACK + 1.2), Vector3(-DECK_X + 1.2, 0, 4.0), Vector3(DECK_X - 1.2, 0, 4.0)]:
			var h := 9.0
			_place(tower, "Tower%d" % k, p, h, 45.0 * k)
			# The sphere on top crackles: an emissive blue orb whose energy flickers.
			var orb := _orb(p + Vector3(0, h * 0.94, 0), 0.45)
			_crackles.append(orb)
			k += 1
	if lantern != null:
		var k := 0
		for side in [-1.0, 1.0]:
			for zz in [-15.0, -6.0, 3.0, 12.0]:
				var p := Vector3(side * (DECK_X - 0.8), 0, zz)
				_place(lantern, "Lantern%d" % k, p, 1.6, 0.0)
				_glow(p + Vector3(0, 0.95, 0), 0.22, Color(1.0, 0.72, 0.35), 5.0)
				k += 1
	if ship != null:
		# Two close ships drifting beside the deck (in the match camera's corners), one far
		# behind for the lower views. Meshy delivers it 1 long, 0.68 tall, centred.
		var spots := [[Vector3(-21.0, 6.0, -15.0), 16.0, 80.0], [Vector3(22.0, 9.0, -4.0), 14.0, -100.0], [Vector3(10.0, 20.0, -70.0), 30.0, 160.0]]
		var k := 0
		for s in spots:
			var node := ship.duplicate() as Node3D
			node.name = "Airship%d" % k
			node.scale = Vector3.ONE * float(s[1])
			node.rotation_degrees = Vector3(0, float(s[2]), 0)
			node.position = s[0]
			add_child(node)
			_ships.append(node)
			_ship_base.append(s[0])
			k += 1


func _place(source: Node3D, node_name: String, pos: Vector3, height: float, yaw_deg: float) -> void:
	var piece := source.duplicate() as Node3D
	piece.name = node_name
	piece.scale = Vector3.ONE * height
	piece.rotation_degrees = Vector3(0, yaw_deg, 0)
	piece.position = pos + Vector3(0, height * 0.5, 0)
	add_child(piece)


func _orb(pos: Vector3, radius: float) -> MeshInstance3D:
	return _glow(pos, radius, Color(0.45, 0.78, 1.0), 6.0)


func _glow(pos: Vector3, radius: float, color: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Lightning
# ---------------------------------------------------------------------------

func _build_bolt() -> void:
	_bolt = Node3D.new()
	_bolt.name = "Lightning"
	_bolt.visible = false
	add_child(_bolt)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.9, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.7, 0.85, 1.0)
	m.emission_energy_multiplier = 8.0
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 1, 1.2)
	var p := Vector3(0, 110, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 14:
		var q := p + Vector3(rng.randf_range(-9, 9), -9.5, rng.randf_range(-4, 4))
		var seg := MeshInstance3D.new()
		seg.mesh = bm
		seg.material_override = m
		var d := q - p
		seg.basis = Basis.looking_at(d.normalized(), Vector3.FORWARD if absf(d.normalized().y) > 0.99 else Vector3.UP) * Basis.from_scale(Vector3(1, 1, d.length()))
		seg.position = (p + q) * 0.5
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bolt.add_child(seg)
		p = q


func _process(delta: float) -> void:
	_t += delta
	# Airships bob and sway gently.
	for i in _ships.size():
		var base := _ship_base[i]
		_ships[i].position = base + Vector3(sin(_t * 0.23 + i) * 1.2, sin(_t * 0.6 + i * 1.7) * 0.6, 0)
		_ships[i].rotation_degrees.z = sin(_t * 0.5 + i) * 2.5
	# The rod spheres crackle.
	for i in _crackles.size():
		var m := _crackles[i].material_override as StandardMaterial3D
		m.emission_energy_multiplier = 4.0 + 4.0 * absf(sin(_t * 23.0 + i * 5.1)) * _rng.randf()
	# Lightning: a far bolt every few seconds, flashing the cloud sea for ~0.25 s.
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = _rng.randf_range(5.0, 11.0)
		_flash = 1.0
		var a := _rng.randf_range(-PI * 0.7, PI * 0.7)
		var d := _rng.randf_range(160.0, 260.0)
		_bolt.position = Vector3(sin(a) * d, -40.0, -cos(a) * d)
		_bolt.rotation_degrees = Vector3(0, _rng.randf_range(0, 360), 0)
		_bolt.visible = true
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		if _flash < 0.35:
			_bolt.visible = false
	if _clouds != null:
		_clouds.set_shader_parameter("flash", _flash)
	if _env != null:
		# A soft flicker only: the court must stay readable through the storm.
		_env.ambient_light_energy = _ambient_base + _flash * 0.25


# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

func _box(b: Dictionary, color: String, size: Vector3, pos: Vector3) -> void:
	b.get_or_add(color, []).append(Transform3D(Basis.from_scale(size), pos))


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
		m.roughness = 0.85
		mmi.material_override = m
		add_child(mmi)
