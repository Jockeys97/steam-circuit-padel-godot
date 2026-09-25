## abyssal_sanctuary.gd — "Santuario Abissale" rebuilt (2026-09-26) from the owner's cover
## and his four Meshy props (`godot/assets/arenas/abissale/`): the court stands under a
## brass-ribbed dome on the ocean floor. Around it, beyond the ribs: sunken temple towers,
## two brass whale monuments, kelp and coral swaying, glowing jellyfish drifting in the
## water, shafts of teal light from the surface and bubbles rising.
##
## Composition follows the gameplay camera (36 deg down, ~20 m to the sides, ~22 m back):
## the jellyfish lamps, the dome's ribs, the whales and the kelp are in its frame; the
## temples and most of the drifting jellyfish are for the lower cameras and menu shots.
## The dome is ribs only, never a roof over the court, so nothing crosses the play view.
## Presentation only: no light nodes, no colliders; props load through the arena kit's
## runtime loader (`ArenaKit._load_scene`), so a missing GLB leaves a gap, never an error.
extends Node3D

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const DIR := "res://assets/arenas/abissale/"

const DOME_RX := 14.0    # rib ring, half-width across the court
const DOME_RZ := 17.5    # rib ring, half-length along it
const RIB_H := 12.0
const RIBS := 22
const RIB_SEGMENTS := 5
const RIB_CURVE := 0.85  # how much of a quarter circle each rib bends through
const RIB_REACH := 3.2   # how far inwards the rib's top leans
const DOME_OPEN_Z := 2.0 # ribs only on the far side of this

const COLORS := {
	"brass": Color("c89a4a"),
	"brass_dark": Color("5e4a26"),
	"rock": Color("12303a"),
	"stone": Color("2a4a52"),
}

static var _sky_cache: Texture2D = null

var _t := 0.0
var _jellies: Array[Node3D] = []
var _jelly_base: Array[Vector3] = []
var _kelp: Array[Node3D] = []


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var s := new()
	s.name = "AbyssalSanctuary"
	scenery.add_child(s)
	s._build_water(arena_root)
	s._build_seabed()
	s._build_dome()
	s._build_rays()
	s._build_props()
	s._build_jellyfish()
	s._build_bubbles()
	s.set_process(true)
	return s


func _process(delta: float) -> void:
	_t += delta
	for i in _jellies.size():
		var j := _jellies[i]
		var b := _jelly_base[i]
		var ph := float(i) * 1.7
		j.position = b + Vector3(sin(_t * 0.21 + ph) * 1.2, sin(_t * 0.9 + ph) * 0.6, cos(_t * 0.17 + ph) * 1.2)
		var pulse := 1.0 + 0.08 * sin(_t * 2.2 + ph)
		j.scale = Vector3(pulse, 2.0 - pulse, pulse)
	for i in _kelp.size():
		var k := _kelp[i]
		k.rotation.z = sin(_t * 0.8 + float(i) * 0.9) * 0.05
		k.rotation.x = cos(_t * 0.6 + float(i) * 1.3) * 0.04


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
		mat.panorama = _ocean_panorama()
		sky.sky_material = mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.36, 0.64, 0.70)
		env.ambient_light_energy = 0.6
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.06
		env.glow_hdr_threshold = 1.0
		env.fog_enabled = true
		env.fog_light_color = Color(0.03, 0.20, 0.26)
		env.fog_density = 0.010
		env.fog_sky_affect = 0.35
	if sun != null:
		# Surface light, filtered teal.
		sun.light_color = Color(0.66, 0.92, 0.95)
		sun.light_energy = 0.85
		sun.rotation_degrees = Vector3(-68.0, -15.0, 0.0)
	if fill != null:
		# The brass's warm bounce and the lamps.
		fill.light_color = Color(1.0, 0.78, 0.50)
		fill.light_energy = 0.30
		fill.rotation_degrees = Vector3(-22.0, 160.0, 0.0)


static func _ocean_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var w := 1024
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color("1a7f8c")   # the surface, far above
	var mid := Color("0a4152")
	var horizon := Color("052334")
	for y in h:
		var t := float(y) / float(h - 1)
		var c := top.lerp(mid, clampf(t / 0.3, 0.0, 1.0)) if t < 0.3 else mid.lerp(horizon, clampf((t - 0.3) / 0.25, 0.0, 1.0))
		for x in w:
			var shaft := maxf(0.0, sin(float(x) * 0.05 + sin(float(x) * 0.013) * 3.0)) * maxf(0.0, 0.5 - t) * 0.16
			img.set_pixel(x, y, c + Color(shaft * 0.5, shaft, shaft * 0.9))
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


# ---------------------------------------------------------------------------
# Seabed: rock shelves and the scattered ruins
# ---------------------------------------------------------------------------

func _build_seabed() -> void:
	var b := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	# Low rock ledges beyond the dome ring.
	for i in 26:
		var a := TAU * float(i) / 26.0
		var r := 1.0 + rng.randf_range(0.25, 0.55)
		var p := Vector3(sin(a) * DOME_RX * r, 0, cos(a) * DOME_RZ * r)
		var s := Vector3(rng.randf_range(3.0, 6.0), rng.randf_range(0.6, 1.8), rng.randf_range(3.0, 6.0))
		_rs_box(b, "rock", Basis(Vector3.UP, rng.randf() * TAU), s, p + Vector3(0, s.y * 0.35, 0))
	# Broken temple columns, some standing, some fallen.
	for i in 14:
		var a := TAU * (float(i) + 0.5) / 14.0
		var r := 1.0 + rng.randf_range(0.6, 1.2)
		var p := Vector3(sin(a) * DOME_RX * r, 0, cos(a) * DOME_RZ * r)
		if p.z > 20.0:
			continue # behind the gameplay camera: never seen
		var h := rng.randf_range(3.0, 8.0)
		if i % 3 == 0:
			var rot := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(0, 0, 1), PI * 0.5)
			_rs_box(b, "stone", rot, Vector3(1.2, h, 1.2), p + Vector3(0, 0.6, 0))
		else:
			_box(b, "stone", Vector3(1.2, h, 1.2), p + Vector3(0, h * 0.5, 0))
			_box(b, "stone", Vector3(1.7, 0.4, 1.7), p + Vector3(0, 0.2, 0))
			_box(b, "stone", Vector3(1.6, 0.35, 1.6), p + Vector3(0, h + 0.17, 0))
	_flush(b)


# ---------------------------------------------------------------------------
# The dome: brass ribs around the court, a ring on top of them, glowing rivets
# ---------------------------------------------------------------------------

func _build_dome() -> void:
	var b := {}
	var tops: Array[Vector3] = []
	for i in RIBS:
		var a := TAU * float(i) / float(RIBS)
		var base := Vector3(sin(a) * DOME_RX, 0, cos(a) * DOME_RZ)
		if base.z > DOME_OPEN_Z:
			continue # the near half stays open: the high cameras look in from that side
		var inward := -Vector3(base.x, 0, base.z).normalized()
		# An arched rib: straight up, then curving inwards, the start of the dome's vault.
		var pts: Array[Vector3] = []
		for k in RIB_SEGMENTS + 1:
			var t := float(k) / float(RIB_SEGMENTS)
			var ang := t * PI * 0.5 * RIB_CURVE
			pts.append(base + Vector3(0, sin(ang) * RIB_H / sin(PI * 0.5 * RIB_CURVE), 0) + inward * (1.0 - cos(ang)) * RIB_REACH)
		for k in RIB_SEGMENTS:
			_segment(b, "brass", pts[k], pts[k + 1], 0.42)
		_box(b, "brass_dark", Vector3(1.0, 0.6, 1.0), base + Vector3(0, 0.3, 0))
		tops.append(pts[RIB_SEGMENTS])
		# Glowing rivets up the rib.
		_glow(pts[1], 0.16, Color(1.0, 0.78, 0.45), 3.0)
		_glow(pts[RIB_SEGMENTS], 0.24, Color(1.0, 0.78, 0.45), 3.0)
	# The crown ring joins the rib tops, far half only.
	tops.sort_custom(func(p: Vector3, q: Vector3) -> bool: return atan2(p.x, -p.z) < atan2(q.x, -q.z))
	for k in tops.size() - 1:
		_segment(b, "brass", tops[k], tops[k + 1], 0.36)
	for mmi in _flush(b):
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A box from `a` to `b`, `thick` metres square.
func _segment(b: Dictionary, color: String, from: Vector3, to: Vector3, thick: float) -> void:
	var d := to - from
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var basis := Basis(x * thick, y * d.length(), z * thick)
	b.get_or_add(color, []).append(Transform3D(basis, (from + to) * 0.5))


# ---------------------------------------------------------------------------
# Light shafts from the surface
# ---------------------------------------------------------------------------

func _build_rays() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.95, 1.0, 0.0))
	g.set_color(1, Color(0.5, 0.95, 1.0, 0.0))
	g.add_point(0.5, Color(0.5, 0.95, 1.0, 0.22))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64
	tex.height = 8
	m.albedo_texture = tex
	var spots := [Vector3(-24, 0, -30), Vector3(-6, 0, -38), Vector3(14, 0, -34), Vector3(28, 0, -18), Vector3(-30, 0, -8)]
	var k := 0
	for p in spots:
		var mi := MeshInstance3D.new()
		mi.name = "Ray%d" % k
		var qm := QuadMesh.new()
		qm.size = Vector2(5.0, 60.0)
		mi.mesh = qm
		mi.material_override = m
		mi.position = p + Vector3(0, 26, 0)
		mi.rotation_degrees = Vector3(0, float(k) * 37.0, 14.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		k += 1


# ---------------------------------------------------------------------------
# The owner's Meshy props
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var temple := ArenaKit._load_scene(DIR + "hero_landmark.glb")
	var whale := ArenaKit._load_scene(DIR + "ornament_accent.glb")
	var lamp := ArenaKit._load_scene(DIR + "light_source.glb")
	var kelp := ArenaKit._load_scene(DIR + "vegetation_cluster.glb")
	if temple != null:
		var k := 0
		for spot in [[Vector3(0, 0, -34), 18.0, 0.0], [Vector3(-24, 0, -20), 12.0, 40.0], [Vector3(24, 0, -20), 12.0, -40.0]]:
			_place(temple, "Temple%d" % k, spot[0], float(spot[1]), float(spot[2]))
			k += 1
	if whale != null:
		# Brass whale monuments at the far corners, the one spot beyond the stands the
		# gameplay camera keeps in frame; each swims towards the court's centre line.
		_place(whale, "Whale0", Vector3(-12.5, 0, -19.5), 6.5, 30.0)
		_place(whale, "Whale1", Vector3(12.5, 0, -19.5), 6.5, 150.0)
	if lamp != null:
		var k := 0
		for side in [-1.0, 1.0]:
			for z in [-14.0, -4.5, 4.5, 14.0]:
				var p := Vector3(float(side) * 11.4, 0, float(z))
				_place(lamp, "JellyLamp%d" % k, p, 3.0, 90.0 * float(side))
				_glow(p + Vector3(0, 2.2, 0), 0.32, Color(0.35, 1.0, 0.92), 2.2)
				k += 1
	if kelp != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 707
		var k := 0
		for i in 22:
			var a := TAU * (float(i) + rng.randf()) / 22.0
			var r := 1.0 + rng.randf_range(0.12, 0.5)
			var p := Vector3(sin(a) * DOME_RX * r, 0, cos(a) * DOME_RZ * r)
			if p.z > 8.0:
				continue # near the high cameras kelp would stand in front of the court
			var piece := _place(kelp, "Kelp%d" % k, p, rng.randf_range(3.0, 6.0), rng.randf() * 360.0)
			_kelp.append(piece)
			k += 1


## Meshy delivers each prop 1 m tall, centred: scale to `height`, lift by half of it.
func _place(source: Node3D, node_name: String, pos: Vector3, height: float, yaw_deg: float) -> Node3D:
	var piece := source.duplicate() as Node3D
	piece.name = node_name
	piece.scale = Vector3.ONE * height
	piece.rotation_degrees = Vector3(0, yaw_deg, 0)
	piece.position = pos + Vector3(0, height * 0.5, 0)
	add_child(piece)
	return piece


# ---------------------------------------------------------------------------
# Drifting jellyfish
# ---------------------------------------------------------------------------

func _build_jellyfish() -> void:
	var bell := SphereMesh.new()
	bell.radius = 0.9
	bell.height = 0.9
	bell.is_hemisphere = true
	bell.radial_segments = 16
	bell.rings = 6
	var bell_mat := StandardMaterial3D.new()
	bell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bell_mat.albedo_color = Color(0.45, 1.0, 0.92, 0.55)
	bell_mat.emission_enabled = true
	bell_mat.emission = Color(0.3, 1.0, 0.9)
	bell_mat.emission_energy_multiplier = 1.6
	var tendril := BoxMesh.new()
	tendril.size = Vector3(0.05, 1.6, 0.05)
	var tendril_mat := bell_mat.duplicate() as StandardMaterial3D
	tendril_mat.albedo_color = Color(1.0, 0.55, 0.6, 0.5)
	tendril_mat.emission = Color(1.0, 0.45, 0.5)
	tendril_mat.emission_energy_multiplier = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	for i in 14:
		var a := TAU * float(i) / 14.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(1.35, 2.2)
		var base := Vector3(sin(a) * DOME_RX * r, rng.randf_range(5.0, 15.0), cos(a) * DOME_RZ * r)
		if base.z > 0.0:
			base.z = -base.z # all on the far side: near ones would drift in front of the cameras
		var j := Node3D.new()
		j.name = "Jellyfish%d" % i
		j.position = base
		add_child(j)
		var bm := MeshInstance3D.new()
		bm.mesh = bell
		bm.material_override = bell_mat
		bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		j.add_child(bm)
		for t in 5:
			var ta := TAU * float(t) / 5.0
			var tm := MeshInstance3D.new()
			tm.mesh = tendril
			tm.material_override = tendril_mat
			tm.position = Vector3(cos(ta) * 0.45, -0.8, sin(ta) * 0.45)
			tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			j.add_child(tm)
		_jellies.append(j)
		_jelly_base.append(base)


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
	for spot in [Vector3(-17, 0.1, -6), Vector3(17, 0.1, -6), Vector3(0, 0.1, -24)]:
		var p := CPUParticles3D.new()
		p.name = "Bubbles"
		p.amount = 50
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(3.0, 0.1, 14.0) if absf(spot.x) > 1.0 else Vector3(14.0, 0.1, 3.0)
		p.direction = Vector3.UP
		p.spread = 8.0
		p.gravity = Vector3(0, 1.0, 0)
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
		p.mesh = qm
		p.position = spot
		add_child(p)


# ---------------------------------------------------------------------------
# Helpers and batching
# ---------------------------------------------------------------------------

func _glow(pos: Vector3, radius: float, color: Color, energy: float) -> void:
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


func _solid(color: Color, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.5
	return m


func _box(b: Dictionary, color: String, size: Vector3, pos: Vector3) -> void:
	b.get_or_add(color, []).append(Transform3D(Basis.from_scale(size), pos))


func _rs_box(b: Dictionary, color: String, rot: Basis, size: Vector3, pos: Vector3) -> void:
	b.get_or_add(color, []).append(Transform3D(rot * Basis.from_scale(size), pos))


func _flush(b: Dictionary) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
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
		if String(key).begins_with("brass"):
			m.metallic = 0.4
			m.roughness = 0.5
			# A little warm self-light: under the teal water plain brass reads olive green.
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 0.35
		mmi.material_override = m
		add_child(mmi)
		out.append(mmi)
	return out
