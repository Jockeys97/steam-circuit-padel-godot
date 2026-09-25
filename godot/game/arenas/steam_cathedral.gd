## steam_cathedral.gd — "Cattedrale di Vapore" rebuilt (2026-09-26) from the owner's cover
## and his three Meshy props (`godot/assets/arenas/cattedrale/`): the court stands in the
## nave of a gothic steampunk cathedral. Two rows of brass-capped columns carry the aisles,
## tall lancet windows of amber and violet glass line the walls, iron chandeliers hang over
## the aisles, candelabra stand along the court, and at the far end a cathedral-shaped
## reliquary sits under a rose window between organ pipes venting steam.
##
## Composition follows the gameplay camera (36 deg down, ~20 m to the sides, ~22 m back):
## columns, chandeliers and candelabra are in its frame; the rose window, the reliquary and
## the organ are for the lower cameras and menu shots. The shell (walls and vault) casts no
## shadow, so the sun still lights the court as it did.
## Presentation only: no light nodes, no colliders; props load through the arena kit's
## runtime loader (`ArenaKit._load_scene`), so a missing GLB leaves a gap, never an error.
extends Node3D

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const DIR := "res://assets/arenas/cattedrale/"

const NAVE_X := 15.0     # column rows
const WALL_X := 21.0     # side walls
const BACK_Z := -32.0    # far wall (the rose window)
const FRONT_Z := 34.0    # near wall, behind the gameplay camera
const WALL_H := 26.0
const COLUMN_H := 15.0
const COLUMN_ZS := [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]
const ARCADE_END_Z := 9.0 # the arcade beam and piers stop here (broadcast camera)

const COLORS := {
	"stone": Color("2c2438"),
	"stone_dark": Color("1c1726"),
	"iron": Color("2a2630"),
	"brass": Color("b98a3e"),
}

static var _sky_cache: Texture2D = null


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var c := new()
	c.name = "SteamCathedral"
	scenery.add_child(c)
	c._build_light(arena_root)
	c._build_shell()
	c._build_windows()
	c._build_rose()
	c._build_organ()
	c._build_props()
	c._build_chandeliers()
	return c


# ---------------------------------------------------------------------------
# Light
# ---------------------------------------------------------------------------

func _build_light(arena_root: Node3D) -> void:
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we != null and we.environment != null:
		var env := we.environment
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = _vault_panorama()
		sky.sky_material = mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.50, 0.66)
		env.ambient_light_energy = 0.55
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 1.0
		# Incense haze: warm, thin, enough to set the far end back.
		env.fog_enabled = true
		env.fog_light_color = Color(0.30, 0.22, 0.30)
		env.fog_density = 0.006
		env.fog_sky_affect = 0.3
	if sun != null:
		# Light through the high windows: warm amber.
		sun.light_color = Color(1.0, 0.84, 0.60)
		sun.light_energy = 0.9
		sun.rotation_degrees = Vector3(-62.0, -30.0, 0.0)
	if fill != null:
		# The stained glass's violet bounce.
		fill.light_color = Color(0.66, 0.52, 0.95)
		fill.light_energy = 0.45
		fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)


## Only seen past the vault's edge from the low cameras: a dark violet dusk.
static func _vault_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var img := Image.create(512, 256, false, Image.FORMAT_RGB8)
	var top := Color("0e0916")
	var horizon := Color("2a1a3a")
	for y in 256:
		var t := float(y) / 255.0
		img.fill_rect(Rect2i(0, y, 512, 1), top.lerp(horizon, clampf(t * 1.6, 0.0, 1.0)))
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


# ---------------------------------------------------------------------------
# Walls, aisles and vault
# ---------------------------------------------------------------------------

func _build_shell() -> void:
	var b := {}
	var length := FRONT_Z - BACK_Z
	var mid_z := (FRONT_Z + BACK_Z) * 0.5
	for side in [-1.0, 1.0]:
		# Side wall, with buttress piers between the windows.
		_box(b, "stone", Vector3(1.2, WALL_H, length), Vector3(side * (WALL_X + 0.6), WALL_H * 0.5, mid_z))
		for z in COLUMN_ZS:
			_box(b, "stone_dark", Vector3(1.4, WALL_H, 1.6), Vector3(side * (WALL_X - 0.4), WALL_H * 0.5, z))
		# Aisle arcade over the columns: a stone beam and a brass string course. It stops
		# short of the near end, where the broadcast camera (19, 22, 25) looks across it.
		var beam_len := ARCADE_END_Z - (BACK_Z + 3.0)
		var beam_z := (ARCADE_END_Z + BACK_Z + 3.0) * 0.5
		_box(b, "stone_dark", Vector3(1.6, 2.2, beam_len), Vector3(side * NAVE_X, COLUMN_H + 1.1, beam_z))
		_box(b, "brass", Vector3(1.7, 0.25, beam_len), Vector3(side * NAVE_X, COLUMN_H + 0.1, beam_z))
		# Clerestory: open, only a pier over each column up to the vault, so the aisles and
		# their windows stay visible from the high cameras.
		for z in COLUMN_ZS:
			if float(z) <= ARCADE_END_Z:
				_box(b, "stone", Vector3(1.0, WALL_H - COLUMN_H - 2.2, 1.2), Vector3(side * NAVE_X, COLUMN_H + 2.2 + (WALL_H - COLUMN_H - 2.2) * 0.5, z))
	# Far and near walls.
	_box(b, "stone", Vector3(WALL_X * 2.0 + 2.4, WALL_H, 1.2), Vector3(0, WALL_H * 0.5, BACK_Z - 0.6))
	_box(b, "stone", Vector3(WALL_X * 2.0 + 2.4, WALL_H, 1.2), Vector3(0, WALL_H * 0.5, FRONT_Z + 0.6))
	# Vault ribs across the nave (the vault itself is left open: the camera sits under it).
	for z in COLUMN_ZS:
		for side in [-1.0, 1.0]:
			var rot := Basis(Vector3(0, 0, 1), side * deg_to_rad(28.0))
			_rs_box(b, "stone_dark", rot, Vector3(NAVE_X * 1.15, 0.8, 0.9), Vector3(side * NAVE_X * 0.5, WALL_H + 1.8, z))
	var batches := _flush(b)
	for mmi in batches:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------------
# Stained glass
# ---------------------------------------------------------------------------

func _build_windows() -> void:
	var amber := _glass(Color(0.95, 0.62, 0.20), 1.7)
	var violet := _glass(Color(0.55, 0.30, 0.90), 1.9)
	var k := 0
	for side in [-1.0, 1.0]:
		for i in COLUMN_ZS.size() - 1:
			var z := (float(COLUMN_ZS[i]) + float(COLUMN_ZS[i + 1])) * 0.5
			for pane in 2:
				var mi := MeshInstance3D.new()
				mi.name = "Lancet%d" % k
				var qm := QuadMesh.new()
				qm.size = Vector2(1.6, 9.0)
				mi.mesh = qm
				mi.material_override = amber if (i + pane) % 2 == 0 else violet
				mi.rotation_degrees = Vector3(0, -side * 90.0, 0)
				mi.position = Vector3(side * (WALL_X - 0.05), 12.0, z + (pane - 0.5) * 2.4)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
				k += 1


func _glass(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## The rose window on the far wall: an amber disc, a violet ring, brass tracery spokes.
func _build_rose() -> void:
	var centre := Vector3(0, 17.0, BACK_Z + 0.05)
	var disc := _disc(6.5, _glass(Color(0.55, 0.30, 0.90), 1.8))
	disc.name = "RoseWindow"
	disc.position = centre
	add_child(disc)
	var core := _disc(4.2, _glass(Color(0.98, 0.66, 0.24), 2.0))
	core.position = centre + Vector3(0, 0, 0.04)
	add_child(core)
	var b := {}
	for i in 12:
		var a := TAU * float(i) / 12.0
		var rot := Basis(Vector3(0, 0, 1), a)
		_rs_box(b, "brass", rot, Vector3(0.28, 6.5, 0.2), centre + Vector3(cos(a + PI * 0.5), sin(a + PI * 0.5), 0) * 3.25 + Vector3(0, 0, 0.1))
	for r in [2.0, 4.2, 6.5]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.18
		tm.outer_radius = r + 0.18
		tm.rings = 32
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = _solid(COLORS["brass"], 0.6)
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = centre + Vector3(0, 0, 0.12)
		add_child(ring)
	_flush(b)


func _disc(radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.05
	cm.radial_segments = 32
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------------------
# Organ pipes venting steam
# ---------------------------------------------------------------------------

func _build_organ() -> void:
	var brass := _solid(COLORS["brass"], 0.7)
	var steam := _steam_mesh()
	var k := 0
	for side in [-1.0, 1.0]:
		for i in 9:
			var h := 7.0 + 5.0 * sin(float(i) / 8.0 * PI)
			var x: float = side * (9.0 + float(i) * 0.9)
			var pipe := MeshInstance3D.new()
			pipe.name = "OrganPipe%d" % k
			var cm := CylinderMesh.new()
			cm.top_radius = 0.34
			cm.bottom_radius = 0.34
			cm.height = h
			cm.radial_segments = 10
			pipe.mesh = cm
			pipe.material_override = brass
			pipe.position = Vector3(x, 1.5 + h * 0.5, BACK_Z + 1.6)
			add_child(pipe)
			if i % 3 == 1:
				var p := CPUParticles3D.new()
				p.name = "Steam"
				# Soft round puffs: many, small at the mouth, swelling and fading as they rise,
				# drifting a little sideways; each one turns slowly so no two read alike.
				p.amount = 48
				p.lifetime = 4.5
				p.preprocess = 4.5
				p.direction = Vector3.UP
				p.spread = 16.0
				p.gravity = Vector3(0.15, 0.25, 0)
				p.initial_velocity_min = 0.7
				p.initial_velocity_max = 1.1
				p.damping_min = 0.1
				p.damping_max = 0.2
				p.angle_min = 0.0
				p.angle_max = 360.0
				p.angular_velocity_min = -12.0
				p.angular_velocity_max = 12.0
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
				p.emission_sphere_radius = 0.2
				p.scale_amount_min = 0.8
				p.scale_amount_max = 1.3
				p.scale_amount_curve = _steam_growth()
				p.color_ramp = _steam_fade()
				p.mesh = steam
				p.position = pipe.position + Vector3(0, h * 0.5 + 0.2, 0)
				add_child(p)
			k += 1
	var b := {}
	_box(b, "iron", Vector3(WALL_X * 2.0, 1.5, 3.0), Vector3(0, 0.75, BACK_Z + 1.6))
	_flush(b)


func _steam_mesh() -> Mesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(1.5, 1.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true # the fade ramp drives the alpha
	m.albedo_texture = _puff_texture()
	m.albedo_color = Color(0.94, 0.90, 0.98, 1.0)
	m.disable_receive_shadows = true
	qm.material = m
	return qm


## A round, soft-edged puff: a radial gradient, opaque-ish at the centre, gone at the rim.
func _puff_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.75))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.45, Color(1, 1, 1, 0.35))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Small at the pipe mouth, three times as wide at the top.
func _steam_growth() -> Curve:
	var c := Curve.new()
	c.max_value = 3.0
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(0.4, 1.6))
	c.add_point(Vector2(1.0, 3.0))
	return c


## Fades in over the first moment, thins out by the end of its life.
func _steam_fade() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.12, Color(1, 1, 1, 0.55))
	g.add_point(0.55, Color(1, 1, 1, 0.30))
	return g


# ---------------------------------------------------------------------------
# The owner's Meshy props
# ---------------------------------------------------------------------------

func _build_props() -> void:
	var reliquary := ArenaKit._load_scene(DIR + "hero_landmark.glb")
	var column := ArenaKit._load_scene(DIR + "column_pillar.glb")
	var lamp := ArenaKit._load_scene(DIR + "light_source.glb")
	if reliquary != null:
		# The facade faces the nave, under the rose window, between the organ pipes.
		_place(reliquary, "Reliquary", Vector3(0, 0, BACK_Z + 6.0), 13.0, 0.0)
	if column != null:
		var k := 0
		for side in [-1.0, 1.0]:
			for z in COLUMN_ZS:
				# The arcade ends where the broadcast camera looks down across the aisle.
				if float(z) > ARCADE_END_Z:
					continue
				_place(column, "Column%d" % k, Vector3(side * NAVE_X, 0, z), COLUMN_H, 0.0)
				k += 1
	if lamp != null:
		var k := 0
		for side in [-1.0, 1.0]:
			for z in [-14.0, -4.5, 4.5, 14.0]:
				var p := Vector3(float(side) * 11.4, 0, float(z))
				_place(lamp, "Candelabrum%d" % k, p, 3.2, 0.0)
				_glow(p + Vector3(0, 2.75, 0), 0.24, Color(1.0, 0.72, 0.32), 3.2)
				k += 1


## Meshy delivers each prop 1 m tall, centred: scale to `height`, lift by half of it.
func _place(source: Node3D, node_name: String, pos: Vector3, height: float, yaw_deg: float) -> void:
	var piece := source.duplicate() as Node3D
	piece.name = node_name
	piece.scale = Vector3.ONE * height
	piece.rotation_degrees = Vector3(0, yaw_deg, 0)
	piece.position = pos + Vector3(0, height * 0.5, 0)
	add_child(piece)


# ---------------------------------------------------------------------------
# Chandeliers over the aisles
# ---------------------------------------------------------------------------

func _build_chandeliers() -> void:
	var iron := _solid(COLORS["iron"], 0.3)
	var k := 0
	for side in [-1.0, 1.0]:
		for z in [-20.0, -4.0, 12.0]:
			var centre := Vector3(float(side) * 18.0, 11.0, float(z))
			var root := Node3D.new()
			root.name = "Chandelier%d" % k
			root.position = centre
			add_child(root)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 1.25
			tm.outer_radius = 1.45
			tm.rings = 24
			tm.ring_segments = 6
			ring.mesh = tm
			ring.material_override = iron
			root.add_child(ring)
			var chain := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.08, WALL_H - 11.0, 0.08)
			chain.mesh = bm
			chain.material_override = iron
			chain.position = Vector3(0, (WALL_H - 11.0) * 0.5, 0)
			root.add_child(chain)
			for i in 8:
				var a := TAU * float(i) / 8.0
				_glow(centre + Vector3(cos(a) * 1.35, 0.3, sin(a) * 1.35), 0.13, Color(1.0, 0.78, 0.4), 4.0)
			k += 1


func _glow(pos: Vector3, radius: float, color: Color, energy: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var m := _glass(color, energy)
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _solid(color: Color, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.55
	return m


# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

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
		if key == "brass":
			m.metallic = 0.6
			m.roughness = 0.5
		mmi.material_override = m
		add_child(mmi)
		out.append(mmi)
	return out
