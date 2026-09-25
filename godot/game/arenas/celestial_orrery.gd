## celestial_orrery.gd — "Orrery Celeste" rebuilt (2026-09-26) from the owner's cover and
## his four Meshy props (`godot/assets/arenas/orrery/`): the court stands on a brass
## observatory platform floating in space. An indigo deck inlaid with gold orbit rings and
## edged by a star-and-moon railing, brass telescopes and armillary lamps around the court,
## a giant golden orrery turning behind the far end, planets drifting in a violet nebula.
##
## Composition follows the gameplay camera (36 deg down, ~20 m to the sides, ~22 m back):
## deck, rings, lamps, telescopes and the railing's back arc are in its frame, and a ringed
## planet hangs below the platform's edge in its corner; the orrery and the far planets are
## for the lower cameras and menu shots.
## Presentation only: no light nodes, no colliders; props load through the arena kit's
## runtime loader (`ArenaKit._load_scene`), so a missing GLB leaves a gap, never an error.
extends Node3D

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const DIR := "res://assets/arenas/orrery/"

const DECK_RX := 22.0
const DECK_RZ := 27.0
const DECK_TOP := -0.04   # below the court floor (y 0): no z-fighting
const RAIL_W := 4.0       # metres per railing segment
const RAIL_MAX_Z := 15.0  # no railing nearer than this: it would stand in front of the cameras

## Each Meshy prop's own bottom, as a fraction of its scaled size (measured on import).
const BOTTOM := {
	"hero_landmark": 0.46,
	"ornament_accent": 0.5,
	"light_source": 0.5,
	"railing_segment": 0.33,
}

const COLORS := {
	"indigo": Color("1a1646"),
	"gold": Color("d4a64c"),
}

static var _sky_cache: Texture2D = null

var _t := 0.0
var _orrery: Node3D = null
var _planets: Array[Node3D] = []
var _planet_orbit: Array[Vector4] = [] # radius, height, speed, phase


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var o := new()
	o.name = "CelestialOrrery"
	scenery.add_child(o)
	var surround := arena_root.get_node_or_null("Surround") as Node3D
	if surround != null:
		surround.hide() # the platform floats: below it is space, not ground
	o._build_space(arena_root)
	o._build_deck()
	o._build_props()
	o._build_planets()
	o.set_process(true)
	return o


func _process(delta: float) -> void:
	_t += delta
	if _orrery != null:
		_orrery.rotation.y = _t * 0.06
	for i in _planets.size():
		var o := _planet_orbit[i]
		var a := o.w + _t * o.z
		_planets[i].position = Vector3(sin(a) * o.x, o.y, cos(a) * o.x - 20.0)
		_planets[i].rotation.y = _t * 0.2


# ---------------------------------------------------------------------------
# Space: a violet nebula full of stars
# ---------------------------------------------------------------------------

func _build_space(arena_root: Node3D) -> void:
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we != null and we.environment != null:
		var env := we.environment
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = _nebula_panorama()
		sky.sky_material = mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.56, 0.50, 0.86)
		env.ambient_light_energy = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 1.0
		env.fog_enabled = false
	if sun != null:
		# The orrery's golden sun, behind the far end.
		sun.light_color = Color(1.0, 0.86, 0.62)
		sun.light_energy = 1.0
		sun.rotation_degrees = Vector3(-55.0, 10.0, 0.0)
	if fill != null:
		# The nebula's violet.
		fill.light_color = Color(0.62, 0.48, 1.0)
		fill.light_energy = 0.45
		fill.rotation_degrees = Vector3(-20.0, 160.0, 0.0)


static func _nebula_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var w := 1024
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var noise2 := FastNoiseLite.new()
	noise2.seed = 99
	noise2.frequency = 0.011
	noise2.fractal_octaves = 3
	var base := Color("0b0924")
	var violet := Color("7a4fd6")
	var blue := Color("2f5bd6")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for y in h:
		var band := 1.0 - absf(float(y) / float(h) - 0.42) * 2.2 # the nebula hugs the horizon
		for x in w:
			var n := clampf((noise.get_noise_2d(x, y) + 0.1) * 1.4, 0.0, 1.0) * clampf(band, 0.0, 1.0)
			var n2 := clampf(noise2.get_noise_2d(x, y) * 1.6, 0.0, 1.0) * clampf(band, 0.0, 1.0)
			var c := base.lerp(violet, n * 0.75).lerp(blue, n2 * 0.45)
			img.set_pixel(x, y, c)
	for i in 1400:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h - 1)
		var s := rng.randf_range(0.55, 1.0)
		img.set_pixel(x, y, Color(s, s * 0.97, s * 0.9))
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


# ---------------------------------------------------------------------------
# The platform
# ---------------------------------------------------------------------------

func _build_deck() -> void:
	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 0.82
	cm.height = 1.0
	cm.radial_segments = 64
	deck.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = COLORS["indigo"]
	dm.roughness = 0.6
	dm.metallic = 0.2
	deck.material_override = dm
	deck.scale = Vector3(DECK_RX, 1.2, DECK_RZ)
	deck.position = Vector3(0, DECK_TOP - 0.6, 0)
	add_child(deck)
	# Gold orbit rings inlaid in the deck, and a heavy rim at its edge.
	var gold := StandardMaterial3D.new()
	gold.albedo_color = COLORS["gold"]
	gold.metallic = 0.5
	gold.roughness = 0.45
	gold.emission_enabled = true
	gold.emission = COLORS["gold"]
	gold.emission_energy_multiplier = 0.25
	var k := 0
	for r in [[9.0, 13.0, 0.035], [15.5, 19.5, 0.04], [DECK_RX - 0.4, DECK_RZ - 0.4, 0.07]]:
		var ring := MeshInstance3D.new()
		ring.name = "OrbitRing%d" % k
		var tm := TorusMesh.new()
		tm.inner_radius = 1.0 - float(r[2])
		tm.outer_radius = 1.0
		tm.rings = 64
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = gold
		ring.scale = Vector3(float(r[0]), 0.4 if k == 2 else 0.05, float(r[1]))
		ring.position = Vector3(0, DECK_TOP + (0.12 if k == 2 else 0.005), 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		k += 1
	# A few glowing star studs on the inner ring.
	for i in 12:
		var a := TAU * float(i) / 12.0
		_glow(Vector3(sin(a) * 15.5, DECK_TOP + 0.05, cos(a) * 19.5), 0.16, Color(1.0, 0.92, 0.7), 3.0)


# ---------------------------------------------------------------------------
# The owner's Meshy props
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var orrery := ArenaKit._load_scene(DIR + "hero_landmark.glb")
	var telescope := ArenaKit._load_scene(DIR + "ornament_accent.glb")
	var lamp := ArenaKit._load_scene(DIR + "light_source.glb")
	var rail := ArenaKit._load_scene(DIR + "railing_segment.glb")
	if orrery != null:
		# The giant orrery floats beyond the far end, turning slowly, its sun glowing.
		# Far and low enough that the courtside camera frames all of it, arms and planets.
		var size := 34.0
		var at := Vector3(0, -8.0, -62.0)
		_orrery = _place(orrery, "Orrery", "hero_landmark", at, size, 0.0)
		# Its sun, lit: a glowing sphere just larger than the model's own (~0.25 of its width).
		_glow(at + Vector3(0, size * (0.46 + 0.07), 0), size * 0.135, Color(1.0, 0.78, 0.35), 2.0)
	if telescope != null:
		var k := 0
		for spot in [Vector3(-17.5, 0, -9.0), Vector3(17.5, 0, -9.0), Vector3(-17.5, 0, 7.0), Vector3(17.5, 0, 7.0)]:
			# Each points out into space, away from the court.
			_place(telescope, "Telescope%d" % k, "ornament_accent", spot + Vector3(0, DECK_TOP, 0), 4.6, 180.0 if spot.x < 0.0 else 0.0)
			k += 1
	if lamp != null:
		var k := 0
		for side in [-1.0, 1.0]:
			for z in [-14.0, -4.5, 4.5, 14.0]:
				var p := Vector3(float(side) * 11.4, DECK_TOP, float(z))
				_place(lamp, "Armillary%d" % k, "light_source", p, 2.6, float(k) * 45.0)
				_glow(p + Vector3(0, 2.6 * 0.55, 0), 0.22, Color(1.0, 0.95, 0.78), 4.0)
				k += 1
	if rail != null:
		_build_railing(rail)


## Railing segments along the deck's edge, tangent to it, the far arc and the sides only.
func _build_railing(rail: Node3D) -> void:
	var k := 0
	var a := -PI
	var edge := 0.94
	while a < PI:
		var p := Vector3(sin(a) * DECK_RX * edge, 0, cos(a) * DECK_RZ * edge)
		var tangent := Vector3(cos(a) * DECK_RX, 0, -sin(a) * DECK_RZ)
		var step := RAIL_W / tangent.length()
		var mid_a := a + step * 0.5
		var mid := Vector3(sin(mid_a) * DECK_RX * edge, DECK_TOP, cos(mid_a) * DECK_RZ * edge)
		var t := Vector3(cos(mid_a) * DECK_RX, 0, -sin(mid_a) * DECK_RZ).normalized()
		if mid.z < RAIL_MAX_Z:
			_place(rail, "Rail%d" % k, "railing_segment", mid, RAIL_W, rad_to_deg(atan2(-t.z, t.x)))
			k += 1
		a += step


## Meshy delivers each prop 1 m on its largest side, centred: scale to `size`, lift by the
## model's own bottom (`BOTTOM`).
func _place(source: Node3D, node_name: String, slot: String, pos: Vector3, size: float, yaw_deg: float) -> Node3D:
	var piece := source.duplicate() as Node3D
	piece.name = node_name
	piece.scale = Vector3.ONE * size
	piece.rotation_degrees = Vector3(0, yaw_deg, 0)
	piece.position = pos + Vector3(0, size * float(BOTTOM.get(slot, 0.5)), 0)
	add_child(piece)
	return piece


# ---------------------------------------------------------------------------
# Planets drifting in space
# ---------------------------------------------------------------------------

func _build_planets() -> void:
	# [radius, colour, ring?, orbit radius, height, speed, phase]
	var defs := [
		[9.0, Color("8f6cff"), true, 58.0, -16.0, 0.010, -2.2],   # below the left edge, in the gameplay frame
		[5.0, Color("e0885a"), false, 62.0, 18.0, 0.014, 0.4],
		[7.0, Color("4f8fe0"), true, 70.0, 26.0, 0.008, 2.6],
		[3.5, Color("e6d4a0"), false, 50.0, 12.0, 0.020, -0.9],
		[6.0, Color("c25fa0"), false, 66.0, -20.0, 0.012, 1.9],   # below the right edge
	]
	var k := 0
	for d in defs:
		var root := Node3D.new()
		root.name = "Planet%d" % k
		add_child(root)
		var sphere := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = float(d[0])
		sm.height = float(d[0]) * 2.0
		sm.radial_segments = 32
		sm.rings = 16
		sphere.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = d[1]
		m.roughness = 0.8
		m.emission_enabled = true
		m.emission = (d[1] as Color) * 0.35
		sphere.material_override = m
		sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sphere)
		if bool(d[2]):
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = float(d[0]) * 1.35
			tm.outer_radius = float(d[0]) * 1.9
			tm.rings = 48
			tm.ring_segments = 4
			ring.mesh = tm
			var rm := StandardMaterial3D.new()
			rm.albedo_color = COLORS["gold"]
			rm.emission_enabled = true
			rm.emission = COLORS["gold"]
			rm.emission_energy_multiplier = 0.4
			ring.material_override = rm
			ring.scale = Vector3(1.0, 0.05, 1.0)
			ring.rotation_degrees = Vector3(18.0, 0, 12.0)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ring)
		_planets.append(root)
		_planet_orbit.append(Vector4(float(d[3]), float(d[4]), float(d[5]), float(d[6])))
		root.position = Vector3(sin(float(d[6])) * float(d[3]), float(d[4]), cos(float(d[6])) * float(d[3]) - 20.0)
		k += 1


func _glow(pos: Vector3, radius: float, color: Color, energy: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
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
