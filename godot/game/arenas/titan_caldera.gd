## titan_caldera.gd — "Caldera del Titano" rebuilt (2026-09-25) from the owner's cover and
## his three Meshy props (`godot/assets/arenas/caldera/`): a lava moat circling the court,
## two kneeling titans flanking the far end, forge chimneys on the rim, lanterns hung from
## iron gallows over the lava, an ember sky and far volcanoes.
##
## Composition follows the gameplay camera (`Court.CAMERAS.default`, 36 deg down): the moat
## (13..19 m to the sides, 19..25 m behind) and the titans (behind the back glass) are what
## the match sees; the volcanoes and sky are for the lower cameras and the menu shots.
## Presentation only: no light nodes, no colliders; the props load at runtime through the
## arena kit's own loader (`ArenaKit._load_scene`), so a missing GLB simply leaves a gap.
extends Node3D

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const DIR := "res://assets/arenas/caldera/"

const INNER_X := 13.0
const OUTER_X := 19.0
const INNER_BACK := -19.0
const OUTER_BACK := -25.0
const INNER_FRONT := 21.0
const OUTER_FRONT := 27.0

const COLORS := {
	"rock": Color("1d1413"),
	"rim": Color("2a1c19"),
	"iron": Color("2b2a2e"),
	"bronze": Color("6d4a2a"),
	"mountain": Color("140c0b"),
}

static var _sky_cache: Texture2D = null


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var c := new()
	c.name = "TitanCaldera"
	scenery.add_child(c)
	c._build_night(arena_root)
	c._build_moat()
	c._build_props()
	c._build_volcanoes()
	c._build_embers()
	return c


# ---------------------------------------------------------------------------
# Sky and light
# ---------------------------------------------------------------------------

func _build_night(arena_root: Node3D) -> void:
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we != null and we.environment != null:
		var env := we.environment
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = _ember_panorama()
		sky.sky_material = mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.46, 0.40, 0.42)
		env.ambient_light_energy = 0.36
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 1.0
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.0
		env.fog_enabled = true
		env.fog_light_color = Color(0.28, 0.08, 0.04)
		env.fog_density = 0.006
		env.fog_sky_affect = 0.0
	if sun != null:
		# The caldera's glow as the key: hot orange, low, from beyond the far end.
		sun.light_color = Color(1.0, 0.58, 0.32)
		sun.light_energy = 0.55
		sun.rotation_degrees = Vector3(-38.0, 160.0, 0.0)
	if fill != null:
		# A cool arena fill from behind the camera keeps the blue court legible.
		fill.light_color = Color(0.70, 0.76, 1.0)
		fill.light_energy = 0.95
		fill.rotation_degrees = Vector3(-60.0, -15.0, 0.0)


static func _ember_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var w := 1024
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color("07030a")
	var mid := Color("2a0908")
	var horizon := Color("8a2410")
	var below := Color("140605")
	for y in h:
		var t := float(y) / float(h - 1)
		var c: Color
		if t < 0.38:
			c = top.lerp(mid, t / 0.38)
		elif t < 0.5:
			c = mid.lerp(horizon, (t - 0.38) / 0.12)
		else:
			c = horizon.lerp(below, clampf((t - 0.5) / 0.05, 0.0, 1.0))
		for x in w:
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 500: # drifting ash and embers
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(int(h * 0.1), int(h * 0.49))
		img.set_pixel(x, y, Color(1.0, rng.randf_range(0.35, 0.7), 0.15) * rng.randf_range(0.4, 1.0))
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


# ---------------------------------------------------------------------------
# The lava moat and its rims
# ---------------------------------------------------------------------------

func _build_moat() -> void:
	var lava := ShaderMaterial.new()
	lava.shader = preload("res://game/arenas/lava_flow.gdshader")
	# Four flat strips forming a ring around the court island.
	var strips := [
		Rect2(-OUTER_X, OUTER_BACK, OUTER_X * 2.0, INNER_BACK - OUTER_BACK),        # back
		Rect2(-OUTER_X, INNER_FRONT, OUTER_X * 2.0, OUTER_FRONT - INNER_FRONT),     # front
		Rect2(-OUTER_X, INNER_BACK, OUTER_X - INNER_X, INNER_FRONT - INNER_BACK),   # left
		Rect2(INNER_X, INNER_BACK, OUTER_X - INNER_X, INNER_FRONT - INNER_BACK),    # right
	]
	var i := 0
	for r in strips:
		var mi := MeshInstance3D.new()
		mi.name = "Lava%d" % i
		var pm := PlaneMesh.new()
		pm.size = r.size
		pm.subdivide_width = 0
		mi.mesh = pm
		mi.material_override = lava
		mi.position = Vector3(r.position.x + r.size.x * 0.5, 0.03, r.position.y + r.size.y * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		i += 1
	var b := {}
	# Iron curb along the island's edge, rock cliffs along the outer edge.
	for side in [-1.0, 1.0]:
		_box(b, "iron", Vector3(0.5, 0.45, INNER_FRONT - INNER_BACK), Vector3(side * (INNER_X - 0.25), 0.22, (INNER_FRONT + INNER_BACK) * 0.5))
		_box(b, "rim", Vector3(2.2, 1.6, OUTER_FRONT - OUTER_BACK + 2.2), Vector3(side * (OUTER_X + 1.1), 0.8, (OUTER_FRONT + OUTER_BACK) * 0.5))
	for z in [INNER_BACK + 0.25, INNER_FRONT - 0.25]:
		_box(b, "iron", Vector3(INNER_X * 2.0, 0.45, 0.5), Vector3(0, 0.22, z))
	_box(b, "rim", Vector3(OUTER_X * 2.0 + 4.4, 1.6, 2.2), Vector3(0, 0.8, OUTER_BACK - 1.1))
	_box(b, "rim", Vector3(OUTER_X * 2.0 + 4.4, 1.6, 2.2), Vector3(0, 0.8, OUTER_FRONT + 1.1))
	# The rock shelf beyond the rim, where the titans and chimneys stand.
	_box(b, "rock", Vector3(140.0, 1.2, 60.0), Vector3(0, 0.6, OUTER_BACK - 2.2 - 30.0))
	for side in [-1.0, 1.0]:
		_box(b, "rock", Vector3(60.0, 1.2, 120.0), Vector3(side * (OUTER_X + 2.2 + 30.0), 0.6, 0))
	_flush(b)


# ---------------------------------------------------------------------------
# The owner's Meshy props
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var titan := ArenaKit._load_scene(DIR + "hero_landmark.glb")
	var chimney := ArenaKit._load_scene(DIR + "column_pillar.glb")
	var lantern := ArenaKit._load_scene(DIR + "light_source.glb")
	var shelf_y := 1.2
	if titan != null:
		var t := 0
		for side in [-1.0, 1.0]:
			# Knee-deep in the side moat (13..19 m out), turned in towards the court. Behind
			# the far glass they fell outside the match camera's frame (36 deg down, it sees
			# the ground to ~22 m back), and x = 23.5 on the shelf was still out of its width
			# at that depth, measured in the frame.
			_place(titan, "Titan%d" % t, Vector3(side * 16.3, -0.8, -10.0), 8.0, side * -90.0)
			t += 1
	if chimney != null:
		var spots := [Vector3(-26, 0, -33), Vector3(-4.5, 0, -36), Vector3(4.5, 0, -36), Vector3(26, 0, -33),
			Vector3(-25, 0, -10), Vector3(25, 0, -10), Vector3(-25, 0, 10), Vector3(25, 0, 10)]
		var k := 0
		for p in spots:
			_place(chimney, "Chimney%d" % k, p + Vector3(0, shelf_y, 0), 9.0 + float(k % 3) * 2.0, float(k) * 37.0)
			k += 1
	if lantern != null:
		var b := {}
		var k := 0
		for side in [-1.0, 1.0]:
			for z in [-15.0, -5.0, 5.0, 15.0]:
				var post := Vector3(side * (INNER_X - 0.6), 0.0, z)
				_box(b, "iron", Vector3(0.28, 5.2, 0.28), post + Vector3(0, 2.6, 0))
				_box(b, "iron", Vector3(2.6, 0.22, 0.22), post + Vector3(side * 1.2, 5.1, 0))
				_box(b, "bronze", Vector3(0.36, 0.36, 0.36), post + Vector3(0, 5.25, 0))
				var hang := post + Vector3(side * 2.3, 3.2, 0)
				_place(lantern, "Lantern%d" % k, hang, 1.9, 0.0)
				_glow(hang + Vector3(0, 0.05, 0), 0.32)
				k += 1
		_flush(b)


## One instance of a kit scene: Meshy delivers every prop 1 m tall and centred, so scale it
## to `height` and lift it by half so its base sits at `pos`.
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
	m.albedo_color = Color(1.0, 0.55, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.18)
	m.emission_energy_multiplier = 5.0
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------------------
# Far volcanoes and embers
# ---------------------------------------------------------------------------

func _build_volcanoes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# The owner's Meshy volcano (2026-09-25), one model reused with its own size and turn;
	# Meshy delivers it 1 wide, 0.34 tall, centred (min_y -0.17). The procedural cones stay
	# only as the fallback when the GLB is missing.
	var volcano := ArenaKit._load_scene(DIR + "volcano.glb")
	var b := {}
	for i in 9:
		var a := -PI * 0.75 + PI * 1.5 * float(i) / 8.0 + rng.randf_range(-0.06, 0.06)
		var d := rng.randf_range(170.0, 230.0)
		var wid := rng.randf_range(110.0, 170.0)
		var base := Vector3(sin(a) * d, 0, -cos(a) * d)
		if volcano != null:
			var v := volcano.duplicate() as Node3D
			v.name = "Volcano%d" % i
			v.scale = Vector3.ONE * wid
			v.rotation_degrees = Vector3(0, rng.randf_range(0.0, 360.0), 0)
			v.position = base + Vector3(0, 0.17 * wid, 0)
			add_child(v)
			_lava_glows(v)
			_glow(base + Vector3(0, 0.30 * wid, 0), wid * 0.04)
		else:
			var hgt := wid * 0.5
			b.get_or_add("cone_mountain", []).append(Transform3D(Basis.from_scale(Vector3(wid, hgt, wid * 0.8)), base + Vector3(0, hgt * 0.5, 0)))
			_glow(base + Vector3(0, hgt * 0.97, 0), wid * 0.05)
	_flush(b)


## The GLB's base colour carries the lava: `lava_mask.gdshader` emits only its warm bright
## texels, so the molten channels glow in the dark and the rock stays dark. No light nodes.
static func _lava_glows(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			if src is StandardMaterial3D and (src as StandardMaterial3D).albedo_texture != null:
				var m := ShaderMaterial.new()
				m.shader = preload("res://game/arenas/lava_mask.gdshader")
				m.set_shader_parameter("albedo_tex", (src as StandardMaterial3D).albedo_texture)
				(mi as MeshInstance3D).set_surface_override_material(si, m)


func _build_embers() -> void:
	for x in [-16.0, 16.0]:
		var p := CPUParticles3D.new()
		p.name = "Embers"
		p.amount = 40
		p.lifetime = 4.0
		p.preprocess = 4.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(2.5, 0.1, 22.0)
		p.direction = Vector3.UP
		p.spread = 15.0
		p.gravity = Vector3(0, 0.6, 0)
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.6
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		var qm := QuadMesh.new()
		qm.size = Vector2(0.12, 0.12)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_color = Color(1.0, 0.55, 0.15)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.5, 0.12)
		m.emission_energy_multiplier = 4.0
		qm.material = m
		p.mesh = qm
		p.position = Vector3(x, 0.2, 0)
		add_child(p)


# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

func _box(b: Dictionary, color: String, size: Vector3, pos: Vector3) -> void:
	b.get_or_add("box_" + color, []).append(Transform3D(Basis.from_scale(size), pos))


func _flush(b: Dictionary) -> void:
	for key in b:
		var xfs: Array = b[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var color_key := String(key).get_slice("_", 1)
		if String(key).begins_with("cone_"):
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04
			cm.bottom_radius = 0.5
			cm.height = 1.0
			cm.radial_segments = 8
			mm.mesh = cm
		else:
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
		m.albedo_color = COLORS.get(color_key, Color(0.2, 0.2, 0.2))
		m.roughness = 0.95
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if color_key == "mountain" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
