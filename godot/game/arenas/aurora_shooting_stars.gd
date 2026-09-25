extends Node3D
## Banco Aurora's shooting stars: one pooled star crossing the night sky on its
## own schedule. Presentation only — no gameplay effect, no collision, no
## `Light3D`, no particles, no shadow casting, and no simulation randomness: the
## schedule runs on this node's own seeded RNG, and `step()` is the whole tick,
## so an ancestor that owns pause stops it exactly like `egeo_fish.gd`'s fish.
##
## WHERE THE SKY ACTUALLY IS. Measured, not assumed (`tests/aurora_shooting_stars_test.gd`
## re-measures it every run): the arena's sky is a `BG_SKY` equirect panorama on
## the `WorldEnvironment` (`arena_look.gd`), and it is in frame only for the
## presets whose camera still points near the horizon:
##
##   playable   frame top ~8.5 deg above the horizon, distant ridges at ~2.1 deg
##   courtside  frame top ~14  deg, ridges at ~2.9 deg
##   immersive  frame top ~1.8 deg (a sliver)
##   default / wide / tactical / broadcast: frame top is 20-21 deg BELOW the
##              horizon, i.e. no sky at all is visible
##
## A star "in the sky" therefore has to sit above the arena's own silhouette and
## below the top of the playable frame: this node flies it on a 900 m arc at
## y = 80..118 m, comfortably over the ridge tops (17 m at 230 m) and under the
## frame's top edge. It needs no special case for the other views: at 900 m and
## that height it is simply outside the frame when the camera looks down, which
## is why a star is never painted over the court or the athletes.
##
## THE LANE. Aurora also has a distant landmark (`outdoor_landscape.gd`'s
## `DistantLandmark`, a 15 m massif centred at x = -10, z = -42). From the
## playable camera it reaches ~7.1 deg above the horizon — nearly the whole
## height of that view's ~8.5 deg of sky — so the open lane is beside it, on the
## +x side: the star's whole crossing runs at azimuth +12..+40 deg (measured from
## -Z, the horizon-facing cameras' own forward; the frame is ~+-45.7 deg wide at
## 16:9). Nothing in this module moves the lane if the landmark moves, and the
## test measures the line of sight to every mesh in the built arena, so a
## landmark that grows into the lane fails the suite instead of being hidden.
##
## 900 m is inside `Camera3D`'s default far plane (4000 m, untouched by
## `Court.build_camera`) and outside the arena's 210 m terrain plateau, the
## 230/410 m ridge rings and the fog volume.
##
## FOG IS OFF ON PURPOSE. `arena_look.gd`'s aurora recipe ends depth fog at 170 m
## (`fog_depth` 14..170), so a 900 m object would be fogged to the fog colour and
## vanish. A celestial streak is above the ground haze; the material says so.

const CourtBuilder := preload("res://game/arenas/court_builder.gd")

## The local, deterministic stream. Never the simulation's RNG and never
## wall-clock: two runs of the same arena see the same star schedule.
const RNG_SEED := 20260925
## How long the star waits before its first pass, then between passes: first
## sighting 10-20 s in, then one every 20-40 s.
const FIRST_WAIT := Vector2(10.0, 20.0)
const GAP_WAIT := Vector2(20.0, 40.0)
## On screen for about a second — a meteor's streak, not a drifting prop.
const FLIGHT := 1.0
## The arc: horizontal radius, and the height band it crosses at. See the header
## for why these numbers are where the sky is.
const SKY_RADIUS := 900.0
const HEIGHT_MIN := 80.0
const HEIGHT_MAX := 118.0
## How much altitude the star loses along one pass, and the lane it crosses (see
## THE LANE in the header).
const DROP_MIN := 6.0
const DROP_MAX := 22.0
const AZ_MIN := 12.0
const AZ_MAX := 40.0
const AZ_SWEEP_MIN := 14.0
## The streak's own size at 900 m: a small luminous head and a tapered trail,
## both widened by the arena's own glow pass.
const HEAD_RADIUS := 4.5
const TRAIL_LENGTH := 150.0
const TRAIL_WIDTH := 5.5
## Both above 1.0 on purpose: albedo over the arena's glow threshold is the bloom.
const HEAD_TINT := Color(1.85, 1.95, 2.15)
const TRAIL_TINT := Color(1.70, 1.80, 1.95)

## Seconds until the next pass; a negative `elapsed` means "counting down".
var wait_seconds := 0.0
var elapsed := -1.0
var rng := RandomNumberGenerator.new()
## The pooled pair, built once in `_ready()` and reused by every pass.
var star: Node3D
var head: MeshInstance3D
var trail: MeshInstance3D
## Each star owns its own two materials, so the fade is a plain alpha change on
## them. `GeometryInstance3D.transparency` is deliberately NOT used: on an opaque
## material it is an ordered-dither approximation, and a dithered streak is not a
## soft one.
var head_material: StandardMaterial3D
var trail_material: StandardMaterial3D
var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _direction := Vector3.FORWARD


func _ready() -> void:
	if star != null:
		return
	star = Node3D.new()
	star.name = "Star"
	add_child(star)

	head = MeshInstance3D.new()
	head.name = "Head"
	head.mesh = CourtBuilder.ball_mesh(HEAD_RADIUS, 12)
	head_material = _head_material()
	head.material_override = head_material
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	star.add_child(head)

	trail = MeshInstance3D.new()
	trail.name = "Trail"
	trail.mesh = CourtBuilder.quad_mesh(TRAIL_LENGTH, TRAIL_WIDTH)
	# The quad runs from -X (tail) to +X (head); the head sits at the origin.
	trail.position = Vector3(-TRAIL_LENGTH * 0.5, 0.0, 0.0)
	trail_material = _trail_material()
	trail.material_override = trail_material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	star.add_child(trail)

	reset()


## Back to "no star, first delay pending". Called on build and on stop, so a
## rebuilt arena or a finished match never inherits a stale streak.
func reset() -> void:
	rng.seed = RNG_SEED
	elapsed = -1.0
	wait_seconds = rng.randf_range(FIRST_WAIT.x, FIRST_WAIT.y)
	_start = Vector3.ZERO
	_end = Vector3.ZERO
	_direction = Vector3.FORWARD
	if star != null:
		star.hide()


func _process(delta: float) -> void:
	# The match owns pause without pausing the SceneTree: the same ancestor seam
	# `egeo_fish.gd` and `carioca_crabs.gd` read.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("is_paused") and ancestor.call("is_paused"):
			return
		ancestor = ancestor.get_parent()
	step(delta)


func step(delta: float) -> void:
	if elapsed < 0.0:
		wait_seconds -= delta
		if wait_seconds > 0.0:
			return
		_launch()
		elapsed = 0.0
	elapsed += delta
	if elapsed < FLIGHT:
		var t := elapsed / FLIGHT
		var pos := _start.lerp(_end, t)
		star.position = pos
		_face_viewer(pos)
		var alpha := _opacity(t)
		head_material.albedo_color = Color(HEAD_TINT.r, HEAD_TINT.g, HEAD_TINT.b, alpha)
		trail_material.albedo_color = Color(TRAIL_TINT.r, TRAIL_TINT.g, TRAIL_TINT.b, alpha)
		star.show()
	else:
		star.hide()
		elapsed = -1.0
		wait_seconds = rng.randf_range(GAP_WAIT.x, GAP_WAIT.y)


## Where the streak is right now (`Vector3.ZERO` while it waits). Test-facing.
func position_now() -> Vector3:
	return star.position if star != null and star.visible else Vector3.ZERO


## Which way the current pass is travelling (unit). Test-facing.
func direction_now() -> Vector3:
	return _direction


## One pass across the sky: a sweep of the open lane, and a height band inside the
## sky the measurements above describe.
func _launch() -> void:
	var start_az := rng.randf_range(AZ_MIN, AZ_MAX - AZ_SWEEP_MIN)
	var end_az := start_az + rng.randf_range(AZ_SWEEP_MIN, AZ_MAX - start_az)
	if rng.randf() < 0.5:
		var swap := start_az
		start_az = end_az
		end_az = swap
	var end_y := rng.randf_range(HEIGHT_MIN, HEIGHT_MAX - DROP_MAX)
	var start_y := minf(end_y + rng.randf_range(DROP_MIN, DROP_MAX), HEIGHT_MAX)
	_start = sky_point(start_az, start_y)
	_end = sky_point(end_az, end_y)
	_direction = (_end - _start).normalized()


## A point on the sky arc: `azimuth_deg` is measured from -Z (the horizon-facing
## cameras' own forward), `height` is world y.
static func sky_point(azimuth_deg: float, height: float) -> Vector3:
	var a := deg_to_rad(azimuth_deg)
	return Vector3(SKY_RADIUS * sin(a), height, -SKY_RADIUS * cos(a))


## Turn the star so the trail quad FACES the arena (where every camera stands) with
## its long axis along the travel direction as seen from there: the quad's +Z looks
## back at the viewer and its +X is the travel direction projected into that plane.
## A quad whose plane contained the view ray instead would be edge-on and invisible
## — the first capture of this module showed exactly that. One basis assignment,
## no allocation.
func _face_viewer(pos: Vector3) -> void:
	var to_viewer := -pos.normalized()
	var along := _direction - to_viewer * _direction.dot(to_viewer)
	if along.length_squared() < 0.000001:
		return
	along = along.normalized()
	star.basis = Basis(along, to_viewer.cross(along), to_viewer)


## Fade in and out so the star never pops on or off: opaque through the middle of
## the pass, transparent at both ends.
static func _opacity(t: float) -> float:
	return smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.70, 1.0, t))


func _head_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(HEAD_TINT.r, HEAD_TINT.g, HEAD_TINT.b, 1.0)
	m.disable_fog = true
	return m


func _trail_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.albedo_texture = _trail_texture()
	m.albedo_color = Color(TRAIL_TINT.r, TRAIL_TINT.g, TRAIL_TINT.b, 1.0)
	m.disable_fog = true
	return m


## Head-bright, tail-transparent, along the quad's own U axis (local +X, the
## direction of travel), AND feathered across its width. A one-dimensional gradient
## on a thin quad renders as a hard-edged rectangle that breaks into separated dots
## along its length at capture size; the cross-section falloff here is what makes it
## read as light. Built once, from code, with no asset file.
static func _trail_texture() -> ImageTexture:
	var w := 96
	var h := 16
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var head := Color(1.0, 1.0, 1.0)
	var tail := Color(0.40, 0.54, 0.78)
	for y in h:
		var v := (float(y) + 0.5) / float(h)
		# 0 at both long edges, 1 on the centre line, with a broad soft shoulder.
		var feather := pow(sin(v * PI), 0.55)
		for x in w:
			var u := (float(x) + 0.5) / float(w)
			var along := pow(u, 1.7)
			var c := tail.lerp(head, along)
			image.set_pixel(x, y, Color(c.r, c.g, c.b, along * feather * 0.95))
	return ImageTexture.create_from_image(image)
