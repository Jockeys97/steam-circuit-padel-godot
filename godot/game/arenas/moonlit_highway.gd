## moonlit_highway.gd — "Sopraelevata della Luna" (2026-09-25), the owner's rebuild of the
## `locomotive` arena: a night skyway looping around the court, with traffic, a city
## skyline, a full moon and a starry sky. Inspired by the mood of a moonlit highway race
## track; every piece here is original geometry built in code, plus the owner's own car.
##
## Composition, from the gameplay camera (`Court.CAMERAS.default`: 36 deg down, fov 30):
## the sky is barely in frame, the ground is visible up to ~25 m behind the far glass and
## ~20 m to the sides. So the skyway runs close (deck centre 21 m behind the court centre,
## 17 m to the sides) and low (3.6 m), and the traffic is what the match camera sees; the
## moon and the stars are for the wider and lower cameras.
##
## Presentation only: no collision, no light nodes (emission + the environment's glow),
## and the court's own lighting stays readable (moon key + warm floodlight fill).
extends Node3D

const CAR_SCENE := "res://assets/props/vehicles/rally_car.glb"
const CAR_LENGTH_M := 4.2          # real hatchback length; the GLB is Meshy-normalised
const CAR_GLB_LENGTH := 1.90
const CAR_GLB_MIN_Y := -0.43

## The skyway: a rounded rectangle around the court, deck centre line.
const LOOP_X := 17.0
const LOOP_Z_BACK := -21.0
const LOOP_Z_FRONT := 31.0
const LOOP_CORNER := 6.5
const DECK_Y := 3.6
const DECK_W := 8.4                # four 2.1 m lanes: two each way
const DECK_T := 0.6

const COLORS := {
	"asphalt": Color("1b1f2a"),
	"concrete": Color("3a4153"),
	"rail": Color("8d98ae"),
	"dash": Color("d8dce6"),
	"amber": Color("f2b441"),
	"lamp_post": Color("2b3140"),
	"ground": Color("0d1119"),
	"mountain": Color("0a0e18"),
}

var cars: Array[Node3D] = []
var car_s: Array[float] = []
var car_speed: Array[float] = []
var car_lane: Array[float] = []
var _path: Array[Vector3] = []     # closed polyline, deck centre
var _cum: Array[float] = []        # cumulative length at each point
var _length := 0.0


static func build(scenery: Node3D, arena_root: Node3D) -> Node3D:
	var hw := new()
	hw.name = "MoonlitHighway"
	scenery.add_child(hw)
	hw._build_path()
	hw._build_night(arena_root)
	hw._build_deck()
	hw._build_city()
	hw._build_moon()
	hw._build_traffic()
	return hw


# ---------------------------------------------------------------------------
# The path
# ---------------------------------------------------------------------------

func _build_path() -> void:
	var r := LOOP_CORNER
	var corners := [
		[Vector2(LOOP_X - r, LOOP_Z_BACK + r), -PI * 0.5],   # back-right, arc from -90 to 0
		[Vector2(LOOP_X - r, LOOP_Z_FRONT - r), 0.0],        # front-right, 0 to 90
		[Vector2(-LOOP_X + r, LOOP_Z_FRONT - r), PI * 0.5],  # front-left, 90 to 180
		[Vector2(-LOOP_X + r, LOOP_Z_BACK + r), PI],         # back-left, 180 to 270
	]
	for c in corners:
		var centre: Vector2 = c[0]
		var a0: float = c[1]
		for k in 9:
			var a := a0 + PI * 0.5 * float(k) / 8.0
			_path.append(Vector3(centre.x + cos(a) * r, DECK_Y, centre.y + sin(a) * r))
	_path.append(_path[0])
	_cum = [0.0]
	for i in range(1, _path.size()):
		_cum.append(_cum[i - 1] + _path[i].distance_to(_path[i - 1]))
	_length = _cum[_cum.size() - 1]


## Point and unit tangent at arc length `s` (wraps).
func sample(s: float) -> Array:
	s = fposmod(s, _length)
	var i := _cum.bsearch(s)
	i = clampi(i, 1, _path.size() - 1)
	var a := _path[i - 1]
	var b := _path[i]
	var seg := maxf(0.0001, _cum[i] - _cum[i - 1])
	var t := clampf((s - _cum[i - 1]) / seg, 0.0, 1.0)
	return [a.lerp(b, t), (b - a).normalized()]


# ---------------------------------------------------------------------------
# Night: sky, lights, ground
# ---------------------------------------------------------------------------

static var _sky_cache: Texture2D = null

func _build_night(arena_root: Node3D) -> void:
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we != null and we.environment != null:
		var env := we.environment
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var mat := PanoramaSkyMaterial.new()
		mat.panorama = _night_panorama()
		sky.sky_material = mat
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.26, 0.31, 0.55)
		env.ambient_light_energy = 0.42
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 1.0
		env.fog_enabled = true
		env.fog_light_color = Color(0.10, 0.13, 0.24)
		env.fog_density = 0.004
		env.fog_sky_affect = 0.0
	if sun != null:
		# The moon as the key: cool, from the far-left sky; still enough to read the court.
		sun.light_color = Color(0.78, 0.84, 1.0)
		sun.light_energy = 0.70
		sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	if fill != null:
		# The stadium floodlights: warm, from behind the camera.
		fill.light_color = Color(1.0, 0.86, 0.66)
		fill.light_energy = 0.55
		fill.rotation_degrees = Vector3(-58.0, 170.0, 0.0)


static func _night_panorama() -> Texture2D:
	if _sky_cache != null:
		return _sky_cache
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color("03050f")
	var mid := Color("0c1433")
	var horizon := Color("24305f")
	var below := Color("070a14")
	for y in h:
		var t := float(y) / float(h - 1)
		var c: Color
		if t < 0.40:
			c = top.lerp(mid, t / 0.40)
		elif t < 0.5:
			c = mid.lerp(horizon, (t - 0.40) / 0.10)
		else:
			c = horizon.lerp(below, clampf((t - 0.5) / 0.06, 0.0, 1.0))
		for x in w:
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260925
	for i in 1600:
		var x := rng.randi_range(0, w - 1)
		var y := int(pow(rng.randf(), 1.6) * h * 0.47)
		var b := rng.randf_range(0.35, 1.0)
		var tint := Color(b, b, b * rng.randf_range(0.95, 1.1))
		img.set_pixel(x, y, tint)
		if b > 0.9:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.x < w and p.y >= 0 and p.y < h:
					img.set_pixel(p.x, p.y, tint * 0.5)
	_sky_cache = ImageTexture.create_from_image(img)
	return _sky_cache


# ---------------------------------------------------------------------------
# The skyway
# ---------------------------------------------------------------------------

func _build_deck() -> void:
	var b := {}
	for i in range(1, _path.size()):
		var a := _path[i - 1]
		var c := _path[i]
		var mid := (a + c) * 0.5
		var dir := (c - a)
		var seg := dir.length()
		if seg < 0.01:
			continue
		var yaw := atan2(dir.x, dir.z)
		var basis := Basis(Vector3.UP, yaw)
		var side := basis.x
		# Deck slab and its underside beam, a little longer than the segment to close corners.
		_add(b, "asphalt", Transform3D(_rs(basis, Vector3(DECK_W, DECK_T, seg + 0.35)), mid - Vector3(0, DECK_T * 0.5, 0)))
		_add(b, "concrete", Transform3D(_rs(basis, Vector3(DECK_W + 0.5, 0.35, seg + 0.35)), mid - Vector3(0, DECK_T + 0.18, 0)))
		# Parapets with a metal rail on top.
		for s in [-1.0, 1.0]:
			var edge: Vector3 = mid + side * s * (DECK_W * 0.5 + 0.15)
			_add(b, "concrete", Transform3D(_rs(basis, Vector3(0.3, 0.8, seg + 0.35)), edge + Vector3(0, 0.4, 0)))
			_add(b, "rail", Transform3D(_rs(basis, Vector3(0.12, 0.12, seg + 0.35)), edge + Vector3(0, 0.95, 0)))
		# Lane markings: amber double line in the middle, white dashes between lanes.
		for off in [-0.09, 0.09]:
			_add(b, "amber", Transform3D(_rs(basis, Vector3(0.10, 0.02, seg + 0.3)), mid + side * off + Vector3(0, 0.01, 0)))
		var dashes := int(seg / 4.0)
		for k in dashes:
			var p: Vector3 = a + dir.normalized() * (2.0 + k * 4.0)
			for lane_off in [-DECK_W * 0.25, DECK_W * 0.25]:
				_add(b, "dash", Transform3D(_rs(basis, Vector3(0.12, 0.02, 1.8)), p + side * lane_off + Vector3(0, 0.01, 0)))
	# Pillars and lamp posts along the loop; each lamp throws a warm pool on the deck.
	var pools: Array[Vector3] = []
	var s := 0.0
	var n := 0
	while s < _length:
		var smp := sample(s)
		var p: Vector3 = smp[0]
		var t: Vector3 = smp[1]
		var side := Vector3(t.z, 0, -t.x)
		_add(b, "concrete", Transform3D(Basis().scaled(Vector3(1.3, DECK_Y - DECK_T, 1.3)), Vector3(p.x, (DECK_Y - DECK_T) * 0.5, p.z)))
		var lamp_side := 1.0 if n % 2 == 0 else -1.0
		var post: Vector3 = p + side * lamp_side * (DECK_W * 0.5 + 0.35)
		_add(b, "lamp_post", Transform3D(Basis().scaled(Vector3(0.14, 4.2, 0.14)), post + Vector3(0, 2.1, 0)))
		_add(b, "lamp_post", Transform3D(_rs(Basis(Vector3.UP, atan2(side.x, side.z)), Vector3(0.1, 0.1, 1.4)), post - side * lamp_side * 0.65 + Vector3(0, 4.2, 0)))
		_add(b, "lamp_glow", Transform3D(Basis().scaled(Vector3(0.5, 0.18, 0.5)), post - side * lamp_side * 1.3 + Vector3(0, 4.1, 0)))
		pools.append(Vector3(post.x, DECK_Y + 0.03, post.z) - side * lamp_side * 1.9)
		s += 9.0
		n += 1
	_flush(b)
	_build_light_pools(pools)
	# The ground around the skyway: dark asphalt apron with the city's glow at the edges.
	var ground := MeshInstance3D.new()
	ground.name = "NightGround"
	var pm := PlaneMesh.new()
	pm.size = Vector2(420, 420)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = COLORS["ground"]
	gm.roughness = 0.95
	ground.material_override = gm
	ground.position = Vector3(0, -0.03, 0)
	add_child(ground)


## Warm pools of lamplight on the asphalt: additive radial discs, no light nodes.
func _build_light_pools(points: Array[Vector3]) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec3 tint = vec3(1.0, 0.72, 0.38);
uniform float strength = 0.55;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float f = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = tint * f * f * strength;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var qm := QuadMesh.new()
	qm.size = Vector2(6.5, 6.5)
	qm.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = points.size()
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), points[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LampPools"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ---------------------------------------------------------------------------
# The city and the mountains
# ---------------------------------------------------------------------------

func _build_city() -> void:
	var shader := preload("res://game/arenas/night_windows.gdshader")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7707
	var mm_boxes: Array[Transform3D] = []
	var seeds: Array[float] = []
	# Rings of towers outside the skyway, denser and taller further out.
	for ring in [[34.0, 52.0, 26], [55.0, 80.0, 30], [85.0, 120.0, 34]]:
		var r0: float = ring[0]
		var r1: float = ring[1]
		for i in int(ring[2]):
			var a := rng.randf_range(-PI, PI)
			var d := rng.randf_range(r0, r1)
			var pos := Vector3(sin(a) * d * 1.25, 0, -cos(a) * d)
			if pos.z > 24.0 and absf(pos.x) < 40.0:
				continue # never between the camera and the court
			var h := rng.randf_range(10.0, 26.0) * (1.0 + (d - 34.0) / 70.0)
			var wx := rng.randf_range(6.0, 12.0)
			var wz := rng.randf_range(6.0, 12.0)
			mm_boxes.append(Transform3D(_rs(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), Vector3(wx, h, wz)), pos + Vector3(0, h * 0.5, 0)))
			seeds.append(rng.randf() * 100.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = mm_boxes.size()
	for i in mm_boxes.size():
		mm.set_instance_transform(i, mm_boxes[i])
		mm.set_instance_custom_data(i, Color(seeds[i], 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Skyline"
	mmi.multimesh = mm
	var sm := ShaderMaterial.new()
	sm.shader = shader
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Far mountains: dark low cones on the horizon.
	var mb := {}
	for i in 14:
		var a := -PI * 0.9 + PI * 1.8 * float(i) / 13.0 + rng.randf_range(-0.08, 0.08)
		var d := rng.randf_range(210.0, 260.0)
		var hgt := rng.randf_range(40.0, 85.0)
		var wid := rng.randf_range(70.0, 120.0)
		_add(mb, "cone_mountain", Transform3D(Basis().scaled(Vector3(wid, hgt, wid * 0.7)), Vector3(sin(a) * d, hgt * 0.5, -cos(a) * d)))
	_flush(mb)


# ---------------------------------------------------------------------------
# The moon
# ---------------------------------------------------------------------------

func _build_moon() -> void:
	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	var sm := SphereMesh.new()
	sm.radius = 16.0
	sm.height = 32.0
	moon.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.97, 0.86)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.96, 0.84)
	m.emission_energy_multiplier = 2.2
	m.disable_fog = true
	moon.material_override = m
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.position = Vector3(-70.0, 70.0, -260.0)
	add_child(moon)
	var halo := MeshInstance3D.new()
	halo.name = "MoonHalo"
	var hm := SphereMesh.new()
	hm.radius = 30.0
	hm.height = 60.0
	halo.mesh = hm
	var h := StandardMaterial3D.new()
	h.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	h.albedo_color = Color(0.75, 0.80, 1.0, 0.10)
	h.disable_fog = true
	halo.material_override = h
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = moon.position
	add_child(halo)


# ---------------------------------------------------------------------------
# The traffic
# ---------------------------------------------------------------------------

const TRAFFIC := [
	# [start fraction of the loop, speed m/s, lane offset (+ outer, clockwise), tint]
	[0.00, 16.0, 3.15, Color(1, 1, 1)],
	[0.18, 14.5, 1.05, Color(1.0, 0.45, 0.35)],
	[0.37, 17.5, 3.15, Color(0.55, 1.0, 0.55)],
	[0.55, 15.0, 1.05, Color(1, 1, 1)],
	[0.73, 16.5, 3.15, Color(1.0, 0.85, 0.35)],
	[0.10, -15.5, -1.05, Color(0.8, 0.5, 1.0)],
	[0.46, -17.0, -3.15, Color(1, 1, 1)],
	[0.80, -14.0, -1.05, Color(0.45, 0.9, 1.0)],
]

func _build_traffic() -> void:
	if not ResourceLoader.exists(CAR_SCENE):
		return
	var packed := load(CAR_SCENE) as PackedScene
	if packed == null:
		return
	var scale_k := CAR_LENGTH_M / CAR_GLB_LENGTH
	for entry in TRAFFIC:
		var holder := Node3D.new()
		holder.name = "Car%d" % cars.size()
		add_child(holder)
		var body := packed.instantiate() as Node3D
		body.scale = Vector3.ONE * scale_k
		body.position = Vector3(0, -CAR_GLB_MIN_Y * scale_k, 0)
		# The GLB's long axis is X; turn it so the car's nose points along the holder's -Z.
		body.rotation_degrees = Vector3(0, -90, 0)
		holder.add_child(body)
		_tint(body, entry[3])
		# Head and tail lights: emissive boxes, no light nodes.
		for s in [-0.55, 0.55]:
			holder.add_child(_light_box(Vector3(s, 0.75, -CAR_LENGTH_M * 0.5 - 0.02), Color(1.0, 0.95, 0.8), 4.0))
			holder.add_child(_light_box(Vector3(s, 0.85, CAR_LENGTH_M * 0.5 + 0.02), Color(1.0, 0.12, 0.1), 3.0))
		cars.append(holder)
		car_s.append(float(entry[0]) * _length)
		car_speed.append(float(entry[1]))
		car_lane.append(float(entry[2]))
	_place_cars(0.0)
	set_process(true)


func _process(delta: float) -> void:
	_place_cars(delta)


func _place_cars(delta: float) -> void:
	for i in cars.size():
		car_s[i] = fposmod(car_s[i] + car_speed[i] * delta, _length)
		var smp := sample(car_s[i])
		var p: Vector3 = smp[0]
		var t: Vector3 = smp[1]
		var side := Vector3(t.z, 0, -t.x)
		var fwd := t if car_speed[i] >= 0.0 else -t
		cars[i].position = p + side * car_lane[i]
		cars[i].basis = Basis.looking_at(fwd, Vector3.UP)


static func _light_box(pos: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.16, 0.05)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _tint(node: Node, tint: Color) -> void:
	if tint == Color(1, 1, 1):
		return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var src := mesh.surface_get_material(si)
			if src is BaseMaterial3D:
				var m := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				m.albedo_color = m.albedo_color * tint
				(mi as MeshInstance3D).set_surface_override_material(si, m)


# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

## Rotate then scale in the piece's OWN axes. `Basis.scaled()` scales along the world axes,
## which laid the back stretch of the skyway along Z, straight through the court's line.
static func _rs(rot: Basis, size: Vector3) -> Basis:
	return rot * Basis.from_scale(size)


# ---------------------------------------------------------------------------
# Batching (helpers)
# ---------------------------------------------------------------------------

func _add(b: Dictionary, key: String, xf: Transform3D) -> void:
	if not b.has(key):
		b[key] = []
	(b[key] as Array).append(xf)


func _flush(b: Dictionary) -> void:
	for key in b:
		var xfs: Array = b[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var color_key: String = key
		if String(key).begins_with("cone_"):
			var cm := CylinderMesh.new()
			cm.top_radius = 0.02
			cm.bottom_radius = 0.5
			cm.height = 1.0
			cm.radial_segments = 7
			mm.mesh = cm
			color_key = String(key).trim_prefix("cone_")
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
		if color_key == "lamp_glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.82, 0.52)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.80, 0.48)
			m.emission_energy_multiplier = 6.0
		elif color_key in ["amber", "dash"]:
			m.albedo_color = COLORS[color_key]
			m.emission_enabled = true
			m.emission = COLORS[color_key]
			m.emission_energy_multiplier = 0.35
		else:
			m.albedo_color = COLORS.get(color_key, Color(0.3, 0.3, 0.3))
			m.roughness = 0.9
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if color_key in ["dash", "amber", "lamp_glow", "mountain"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
