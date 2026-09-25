extends Node3D
## THE CROWD: spectators on the stands, who react to the match.
##
## 2026-09-25, owner: the crowd is now the owner's five Meshy fans (`godot/assets/crowd/`,
## ~1,600 triangles each), one MultiMesh per fan type, shirts tinted per spectator and all
## motion in `crowd_fan.gdshader` (bob, lean in long rallies, jump on a point, torso
## turning to the ball) — 60 spectators ~ 97k triangles in five draw calls. The athletes
## are 3D models now, so the flat sprites below read as placeholders beside them. The
## sprite crowd stays as the fallback when a fan GLB is missing (e.g. no LFS checkout).
## The note below is the sprite design's own rationale, kept for that fallback.
##
## WHY SPRITES AND NOT MESHES. The stands alone cost ~20 fps for 919,856 triangles
## across two copies, and the furniture added 1,152,904 more. A crowd of modelled
## people would be the most expensive thing in the scene by an order of magnitude and
## would buy nothing: at ~30 m and ~36 px/m a spectator is roughly 20 px tall, which
## is a sprite's worth of information. Each one here is ONE quad — 2 triangles — with
## `BILLBOARD_ENABLED`, the same construction `match_controller.gd` already uses for
## the timing labels and the pin markers. Sixty spectators cost 120 triangles, which
## is 0.006% of what the stands they sit on already cost.
##
## They also match the players, who are pixel-art sprites in a 3D world. A modelled
## crowd behind sprite athletes would look like the athletes were the placeholder.
##
## HOW THEY REACT. The crowd reads the SAME simulation state the audio does
## (`game/match_audio.gd`), on the same `observe(state, tick)` call, and for the same
## reason: the simulation stores no "the crowd should cheer" flag, so the edge has to
## be derived from the totals the sim does keep. A point landing is
## `stats.pointsWon` rising; a long rally is the rally's own tick count passing a
## threshold. Nothing here is read BACK by the simulation — this module is
## presentation only, and a crowd that could change a rally would be a bug.
##
## The reaction is deliberately cheap: a cheer is an amplitude and a duration applied
## to the bob every spectator already does. No animation frames, no state machine, no
## per-spectator logic — one number on the group, read by every quad's own phase.

const Court := preload("res://game/court.gd")
const Bleachers := preload("res://game/arenas/bleachers.gd")

## Spectators per stand. Two stands, so twice this many quads in the scene. Sixty is
## what fills the 6 m span at this scale without the rows reading as a grid.
static var per_stand := 30
## Rows of seating per stand, back to front.
static var rows := 3
## How tall a spectator stands, in metres. Shorter than a player (1.8 m) because
## they are SEATED — head and shoulders above the bench line.
const HEIGHT_M := 1.15
## Idle bob: metres of vertical travel, and how many bobs per second.
const IDLE_BOB_M := 0.035
const IDLE_BOB_HZ := 0.45
## A cheer multiplies the bob by this and runs for this long.
const CHEER_GAIN := 7.0
const CHEER_SECONDS := 2.2
## A long rally's murmur: smaller than a cheer, and it does not decay — it holds
## while the rally is long.
const MURMUR_GAIN := 2.4
## Rally hits after which the crowd is invested. `state.rallyHits` is the sim's own
## count of shots in the current exchange (`src/sim/sim.gd:346`), reset when a rally
## ends — eight exchanges is a long point at this pace.
const LONG_RALLY_HITS := 8

## The palette a spectator is tinted from. Deliberately NOT the court's blue and not
## the shelters' blue: the stands already read as one blue mass, and a crowd in the
## same hue would disappear into it.
const SHIRT_COLOURS: Array[Color] = [
	Color(0.87, 0.31, 0.27),  # red
	Color(0.95, 0.76, 0.24),  # amber
	Color(0.36, 0.67, 0.42),  # green
	Color(0.85, 0.85, 0.88),  # white
	Color(0.55, 0.36, 0.66),  # violet
	Color(0.92, 0.55, 0.30),  # orange
]

## Presentation only, and switchable for the cost measurement exactly as the stands
## and the furniture are. The game never writes it.
static var enabled := true
## What the last `build()` placed, for the boot log and the evidence.
static var report: Dictionary = {}

var _quads: Array[Sprite3D] = []
## The 3D crowd: one MultiMeshInstance3D per fan type, sharing the uniforms below.
var _fans: Array[MultiMeshInstance3D] = []
var _fan_count := 0
var _ball_z := 0.0
const FAN_DIR := "res://assets/crowd/"
const FAN_TYPES := 5
## Each spectator's own phase, so the rows do not bob in lockstep.
var _phases: PackedFloat32Array = PackedFloat32Array()
var _time := 0.0
## Seconds left of the current cheer, and whether the rally is currently long.
var _cheer_left := 0.0
var _murmuring := false
## Previous-tick values, the same edge detection `match_audio.gd` does.
var _prev_points_total := -1
var _prev_rally_hits := 0


## Adds a crowd to an arena root. Returns the group node (always non-null: a crowd
## that cannot be built leaves the arena exactly as it was, the stands' contract).
static func build(parent: Node3D) -> Node3D:
	var crowd: Node3D = (load("res://game/arenas/crowd.gd") as GDScript).new()
	crowd.name = "Crowd"
	parent.add_child(crowd)
	report = {"spectators": 0, "triangles": 0, "error": ""}
	if not enabled:
		report["error"] = "disabled"
		return crowd
	if not crowd._populate_3d():
		crowd._populate()
	report["spectators"] = crowd._quads.size() + crowd._fan_count
	report["triangles"] = crowd._quads.size() * 2 + int(report.get("fan_triangles", 0))
	print("CROWD spectators=%d triangles=%d rows=%d per_stand=%d height_m=%.2f error=%s" % [
		int(report["spectators"]), int(report["triangles"]), rows, per_stand, HEIGHT_M,
		str(report["error"]),
	])
	return crowd


## One quad per spectator, laid over the two stands' own footprint.
func _populate() -> void:
	var texture := _spectator_texture()
	# The stands stand at ±side_x, span `span_z()` along the side line, and are
	# `height_m` tall — all three read from the stands themselves so a change to
	# their scale or count carries the crowd with it.
	var span: float = Bleachers.span_z()
	var side_x: float = Court.half_len() + Bleachers.CORRIDOR_M
	var stand_h: float = Bleachers.UNIT_HEIGHT_M * Bleachers.scale
	var stand_d: float = Bleachers.UNIT_DEPTH_M * Bleachers.scale

	var rng := RandomNumberGenerator.new()
	# Fixed seed: the same crowd every run, so a screenshot is comparable with the
	# last one and a regression in placement is visible rather than noise.
	rng.seed = 20260917

	for side in [1.0, -1.0]:
		for i in per_stand:
			var row := i % rows
			var seat := float(i / rows)
			var seats_per_row := ceilf(float(per_stand) / float(rows))
			# Along the stand, centred on the net, with a little jitter so the rows
			# are not a grid.
			var z := ((seat + 0.5) / seats_per_row - 0.5) * span
			z += rng.randf_range(-0.12, 0.12)
			# Back rows sit higher and further from the court, on the raked seating.
			var t := float(row) / float(maxf(1.0, float(rows - 1)))
			var y := stand_h * (0.42 + 0.38 * t)
			var x := side_x + stand_d * (0.28 + 0.42 * t)

			var quad := Sprite3D.new()
			quad.name = "Fan%s%02d" % ["R" if side > 0.0 else "L", i + 1]
			quad.texture = texture
			quad.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# `billboard_keep_scale` is what lets the quad be sized by its node's
			# scale rather than having billboarding throw the scale away — the same
			# note `match_controller.gd` makes about its own bars.
			quad.set("billboard_keep_scale", true)
			quad.shaded = false
			quad.double_sided = true
			# A transparent billboarded quad casting a shadow would cast the quad,
			# not the silhouette: off, as every other billboard here is.
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			quad.pixel_size = HEIGHT_M / float(texture.get_height())
			quad.modulate = SHIRT_COLOURS[rng.randi() % SHIRT_COLOURS.size()]
			quad.position = Vector3(x * side, y, z)
			add_child(quad)
			_quads.append(quad)
			_phases.append(rng.randf() * TAU)


## The 3D crowd over the same seat layout as `_populate()`. False (and nothing added)
## when any fan GLB is missing, so the sprite crowd takes over.
func _populate_3d() -> bool:
	const ArenaKit := preload("res://game/arenas/arena_kit.gd")
	var meshes: Array[Mesh] = []
	var textures: Array[Texture2D] = []
	for k in FAN_TYPES:
		var scene := ArenaKit._load_scene(FAN_DIR + "fan_%d.glb" % (k + 1))
		if scene == null:
			return false
		var mis: Array = scene.find_children("*", "MeshInstance3D", true, false)
		if mis.is_empty():
			return false
		var mesh: Mesh = (mis[0] as MeshInstance3D).mesh
		var mat := mesh.surface_get_material(0) as BaseMaterial3D
		if mat == null or mat.albedo_texture == null:
			return false
		meshes.append(mesh)
		textures.append(mat.albedo_texture)
	var span: float = Bleachers.span_z()
	var side_x: float = Court.half_len() + Bleachers.CORRIDOR_M
	var stand_h: float = Bleachers.UNIT_HEIGHT_M * Bleachers.scale
	var stand_d: float = Bleachers.UNIT_DEPTH_M * Bleachers.scale
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917
	var per_type: Array = []
	for k in FAN_TYPES:
		per_type.append([])
	for side in [1.0, -1.0]:
		for i in per_stand:
			var row := i % rows
			var seat := float(i / rows)
			var seats_per_row := ceilf(float(per_stand) / float(rows))
			var z := ((seat + 0.5) / seats_per_row - 0.5) * span + rng.randf_range(-0.12, 0.12)
			var t := float(row) / float(maxf(1.0, float(rows - 1)))
			# The seat surface of this row; the fan's pivot is its middle, so lift by half.
			var y := stand_h * (0.30 + 0.38 * t) + HEIGHT_M * 0.5
			var x := side_x + stand_d * (0.28 + 0.42 * t)
			var yaw := -PI * 0.5 if side > 0.0 else PI * 0.5 # the model's front (+Z) to the court
			yaw += rng.randf_range(-0.18, 0.18)
			var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * HEIGHT_M), Vector3(x * side, y, z))
			var shirt: Color = SHIRT_COLOURS[rng.randi() % SHIRT_COLOURS.size()]
			(per_type[rng.randi() % FAN_TYPES] as Array).append([xf, Color(rng.randf(), shirt.r, shirt.g, shirt.b)])
	var tris := 0
	for k in FAN_TYPES:
		var list: Array = per_type[k]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[k]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_custom_data(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Fans%d" % (k + 1)
		mmi.multimesh = mm
		var sm := ShaderMaterial.new()
		sm.shader = preload("res://game/arenas/crowd_fan.gdshader")
		sm.set_shader_parameter("albedo_tex", textures[k])
		sm.set_shader_parameter("model_h", HEIGHT_M)
		mmi.material_override = sm
		# Seated people under a stand roof: their own shadow buys nothing at this size.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_fans.append(mmi)
		_fan_count += list.size()
		tris += meshes[k].get_faces().size() / 3 * list.size()
	report["fan_triangles"] = tris
	return true


func _process(delta: float) -> void:
	if not _fans.is_empty():
		_process_3d(delta)
		return
	if _quads.is_empty():
		return
	_time += delta
	if _cheer_left > 0.0:
		_cheer_left = maxf(0.0, _cheer_left - delta)

	# One amplitude for the whole crowd, one phase per spectator. The cheer decays
	# over its own window so the crowd settles rather than stopping dead.
	var gain := 1.0
	if _cheer_left > 0.0:
		gain = 1.0 + (CHEER_GAIN - 1.0) * (_cheer_left / CHEER_SECONDS)
	elif _murmuring:
		gain = MURMUR_GAIN
	var amplitude := IDLE_BOB_M * gain
	var rate := TAU * IDLE_BOB_HZ * (1.0 + 0.8 * (gain - 1.0) / CHEER_GAIN)

	for i in _quads.size():
		var quad := _quads[i]
		var phase: float = _phases[i]
		var bob := sin(_time * rate + phase) * amplitude
		quad.position.y = quad.position.y - quad.get_meta("bob", 0.0) + bob
		quad.set_meta("bob", bob)


func _process_3d(delta: float) -> void:
	_time += delta
	if _cheer_left > 0.0:
		_cheer_left = maxf(0.0, _cheer_left - delta)
	var gain := 1.0
	if _cheer_left > 0.0:
		gain = 1.0 + (CHEER_GAIN - 1.0) * (_cheer_left / CHEER_SECONDS)
	elif _murmuring:
		gain = MURMUR_GAIN
	var jump := (_cheer_left / CHEER_SECONDS) if _cheer_left > 0.0 else 0.0
	for mmi in _fans:
		var sm := mmi.material_override as ShaderMaterial
		sm.set_shader_parameter("t", _time)
		sm.set_shader_parameter("bob", IDLE_BOB_M * minf(gain, 2.5))
		sm.set_shader_parameter("rate", TAU * IDLE_BOB_HZ * (1.0 + 0.8 * (gain - 1.0) / CHEER_GAIN))
		sm.set_shader_parameter("lean", 1.0 if _murmuring else 0.0)
		sm.set_shader_parameter("jump", jump)
		sm.set_shader_parameter("ball_z", _ball_z)


## Reads the match the way `game/match_audio.gd` reads it: the same state, the same
## tick, the same edge-from-totals derivation, because the simulation stores no
## "cheer now" flag. Presentation only — nothing here is read back by the sim.
func observe(state, _tick: int) -> void:
	if _quads.is_empty() and _fans.is_empty():
		return
	if "ball" in state and state.ball != null:
		_ball_z = Court.world_pos(float(state.ball.x), float(state.ball.y), 0.0).z

	# A point landed: totals rose. The very first observation only primes the
	# baseline, or the crowd would cheer the score it walked in on.
	var total := int(state.stats["pointsWon"]["player"]) + int(state.stats["pointsWon"]["ai"])
	if _prev_points_total < 0:
		_prev_points_total = total
	elif total > _prev_points_total:
		_prev_points_total = total
		_cheer_left = CHEER_SECONDS

	# A long rally: the crowd leans in while it lasts and settles when it ends.
	var hits := int(state.rallyHits)
	_murmuring = hits >= LONG_RALLY_HITS
	_prev_rally_hits = hits


## The spectator's silhouette: a seated head-and-shoulders, drawn once and shared by
## every quad. Generated rather than authored so the crowd needs no new art file —
## at ~20 px on screen the silhouette is all that survives anyway.
func _spectator_texture() -> ImageTexture:
	var w := 12
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Head.
	for y in range(1, 6):
		for x in range(4, 8):
			if (x == 4 or x == 7) and (y == 1 or y == 5):
				continue  # round the corners
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	# Shoulders and torso, widening downward.
	for y in range(6, h):
		var spread: int = 2 + int((y - 6) / 3)
		for x in range(6 - spread, 6 + spread):
			if x >= 0 and x < w:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	return tex
