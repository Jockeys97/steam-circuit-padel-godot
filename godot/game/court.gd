## court.gd — the shared mapping between the simulation's pixel space and the 3D
## world, plus the camera and athlete-rig builders the quick match reuses.
##
## Nothing here re-implements physics or tuning. It is presentation:
##
##   - the court, net, lines and glass all come from the frozen `COURT` table and
##     from `SERVICE_LINE_OFFSET` (`js/game.js:30`), mapped to a 10 x 20 m court;
##   - the geometry and the camera presets are the ones already rendered by
##     `godot/prototypes/arena_spike/` (see
##     `docs/wayfinder/evidence/character-material-render.md` and the spike's own
##     `arena_*.log` framing reports). They are copied, not reinvented.
##
## SLICE S6 MOVED THE BUILDERS OUT. The court, net and glass cage are now built
## by `game/arenas/court_builder.gd` and the arena's own backdrop and scenery by
## `game/arenas/arena_scenery.gd`, behind the documented API of
## `game/arenas/arena_library.gd` (`ids()`, `info(id)`, `build(id)`). This file
## keeps the scale, the mapping, the material helper, the camera presets, the
## athlete rig and the racket — the parts the match controller and the tests use
## by name — and forwards the two builders so the old call sites keep working.
##
## X maps linearly to 10 m. Depth uses a monotone C1 curve through net,
## service line (6.95 m) and back glass (10 m). The frozen simulation remains
## in pixels; this projection preserves its inside/outside service decisions.
##
## Sim px -> world: X across the court, Y along the court (increasing towards the
## near/player half), Z up. The sim's `court.netY` is world z = 0 and the sim's
## `court.left` is world x = -5 m. Heights retain their original visual scale.
extends RefCounted

const Frozen := preload("res://src/sim/frozen.gd")

## Vertical/legacy effect scale only; ground positions use world_pos().
const PX_TO_M := 0.025
const WIDTH_M := 10.0
const LENGTH_M := 20.0
const SERVICE_M := 6.95
const SERVICE_PX := 126.0
## Cage height. NOT in `COURT` and NOT in `BALANCE`; the spike's flagged default
## (FIP padel is ~3 m) is kept so the two renders stay comparable.
const GLASS_H := 3.0
## The glass panes' alpha floor. The spike used 0.14, which is invisible against
## this dark ground under the default camera, and a single flat-alpha sheet gave
## the eye no pane edges: the enclosure read as three walls with the rear one
## missing. Since slice S6 each wall's alpha is chosen in
## `game/arenas/court_builder.gd` (`glass_params`, wired to the arena's
## `wallBounce`) and never drops below this value; this constant is kept as the
## floor the slice test asserts and as the record of what the old value was.
const GLASS_ALPHA := 0.30
## Ball radius in metres, presentation only (the sim carries `ball.r` in px).
## Larger than a real padel ball so it reads at whole-court framing; same as the
## spike's flagged value.
const BALL_R := 0.10

## The athlete's racket, in metres. The simulation's `paddle.w` / `paddle.h` are
## CONTACT-BOX dimensions, not racket geometry: `basePaddleWidth` is 112 px
## (`src/sim/frozen/data.json:32`) = 2.80 m at this court scale, which is what
## drawing it 1:1 produced on screen — metre-wide bars. A padel racket is 0.26 m
## wide and 0.45 m long (FIP equipment rule: 26 x 45 cm), i.e. about half the
## rendered net height (0.95 m), which is how it is drawn here. The sim's contact
## box is untouched — only its drawing is.
const RACKET_FACE_R := 0.13
const RACKET_FACE_LEN := 1.35
const RACKET_THICK := 0.028
const RACKET_GRIP_W := 0.017
const RACKET_GRIP_L := 0.13
## Which head `make_racket_view` builds. `standard` is the shipped procedural ellipse
## and is also what an empty style means, so every existing caller draws what it drew
## before; `cornetto` is Fornaio's Il Cornetto (`athletes_view.gd::racket_style_for`).
const RACKET_STYLE_STANDARD := &"standard"
const RACKET_STYLE_CORNETTO := &"cornetto"
## Il Cornetto's head, in metres BEFORE the fit to `2 * RACKET_FACE_R` (`_cornetto_fit`).
## The head is a SOLID crescent — a lune, not a ring: the disc of `CORNETTO_OUTER_R` minus
## a "bite" disc whose centre sits `CORNETTO_BITE_D` below the head centre, so the bite
## eats the underside and leaves one arch that tapers to a horn at each end, both horns
## pointing down at the throat — the pose of the intake image
## (`meshy/views/cornetto-front.png`; DNA in `meshy/fornaio-brief.md`). `CORNETTO_TIP_Y`
## is how far below the head centre the two horns meet the outer disc; `CORNETTO_BITE_R`
## is derived from those three (see `cornetto_crescent`), never guessed, so the two
## circles cross exactly at the horns. There is NO hole in the pastry and no string bed:
## the only opening is the concave underside the throat sits in.
## Colours are sampled from that image and kept matte: no chrome, no strings, no holes.
const CORNETTO_OUTER_R := 0.13
const CORNETTO_TIP_Y := 0.078
const CORNETTO_BITE_D := 0.062
## Knots along the crescent's midline. One capsule per gap between knots, so the head is
## a bent, tapering tube — the rolled dough — with `CORNETTO_SEGMENT_GAP` scalloping every
## other segment and a colour band per segment.
const CORNETTO_KNOTS := 15
const CORNETTO_SEGMENTS := CORNETTO_KNOTS - 1
const CORNETTO_SEGMENT_GAP := 0.05
## How much of the lune's local half-thickness the horns keep: below 1 the OUTER edge
## tapers too, so the horns end in points instead of in the legs of an arch.
const CORNETTO_HORN_TAPER := 0.45
const CORNETTO_HORN_MIN_R := 0.004
const CORNETTO_FLAT := 0.72
const CORNETTO_HANDLE_R := 0.021
const CORNETTO_KNOB_R := 0.026
const CORNETTO_KNOB_L := 0.018
const CORNETTO_TWINE_R := 0.0235
const CORNETTO_TWINE_L := 0.014
const CORNETTO_TWINE_PITCH := 0.0445
const CORNETTO_FERRULE_R := 0.0195
const CORNETTO_FERRULE_L := 0.010
const CORNETTO_STEM_L := 0.030
const CORNETTO_ARM_R := 0.011
const CORNETTO_ARM_OVERLAP := 0.012
## Where the hand is, relative to the athlete's feet: height, sideways, towards the
## net. Real proportions for a 1.8 m athlete holding a racket at rest.
const HAND_H := 1.05
const HAND_SIDE := 0.34
const HAND_FWD := 0.34
const HAND_SWING_LIFT := 0.22

## Camera presets, copied verbatim from `godot/prototypes/arena_spike/arena_spike.gd`
## (CAM_DEFAULT / CAM_WIDE / CAM_PLAYABLE). "default" is the solved fit of the web
## build's opening composition and is the provisional match camera; "playable" is
## the behind-the-baseline variant the spike also rendered.
const CAMERAS := {
	"default": {
		"pos": Vector3(0.0, 20.0, 27.5),
		"pitch_deg": -36.0274,
		"fov": 30.0,
		"look_at": Vector3.ZERO,
	},
	"wide": {
		"pos": Vector3(0.0, 22.0, 18.0),
		"pitch_deg": -50.0,
		"fov": 60.000,
		"look_at": Vector3.ZERO,
	},
	"playable": {
		"pos": Vector3(0.0, 8.0, 17.0),
		"pitch_deg": 0.0,
		"fov": 60.000,
		"look_at": Vector3(0.0, 0.900, -1.000),
	},
}

## The athlete GLB this scene falls back to. It MUST be a path the export packs:
## `res://prototypes/*` is in every preset's `exclude_filter`, so the placeholder
## loader this replaced (`res://prototypes/arena_spike/assets/volpe-rigged.glb`)
## silently cost the packaged build its athletes — the export fell back to capsules
## with no error anywhere (`docs/wayfinder/evidence/independent-review.md`, H-3).
## `res://assets/athletes/**` is packed. The primary path is
## `src/character/athlete_rig.gd`'s own `GLB_BASE` through `athlete_spawn.gd`; this
## constant is what `tests/game_slice_test.gd` greps the whole `godot/game/**` tree
## for, so a regression to an excluded tree fails the build instead of shipping.
const GLB_PATH := "res://assets/athletes/volpe-rigged.glb"


static func court() -> Dictionary:
	return Frozen.court()


static func center_x() -> float:
	var c := court()
	return (float(c["left"]) + float(c["right"])) / 2.0


static func net_y() -> float:
	return float(court()["netY"])


static func court_len() -> float:
	return WIDTH_M


static func court_depth() -> float:
	return LENGTH_M


static func half_len() -> float:
	return court_len() / 2.0


static func half_depth() -> float:
	return court_depth() / 2.0


static func net_h() -> float:
	return float(court()["netHeight"]) * PX_TO_M


## The simulation's service boundary is projected to 6.95 m from the net.
static func service_z() -> float:
	return SERVICE_M


## Smooth monotone presentation mapping: net, service boundary and back glass
## remain aligned with the unchanged 2D simulation. No velocity discontinuity
## at the service line; this is an arcade projection, not new physical metres.
static func depth_m(px_y: float) -> float:
	var signed_distance := px_y - net_y()
	var distance := absf(signed_distance)
	var c := court()
	var end_px := float(c["bottom"]) - net_y() if signed_distance >= 0 else net_y() - float(c["top"])
	var inner_slope := SERVICE_M / SERVICE_PX
	var outer_slope := (LENGTH_M * 0.5 - SERVICE_M) / (end_px - SERVICE_PX)
	var join_slope := 2.0 * inner_slope * outer_slope / (inner_slope + outer_slope)
	var metres: float
	if distance > end_px:
		metres = LENGTH_M * 0.5 + (distance - end_px) * outer_slope
	elif distance <= SERVICE_PX:
		metres = _hermite(distance / SERVICE_PX, 0.0, SERVICE_M, inner_slope * SERVICE_PX, join_slope * SERVICE_PX)
	else:
		var span := end_px - SERVICE_PX
		metres = _hermite((distance - SERVICE_PX) / span, SERVICE_M, LENGTH_M * 0.5, join_slope * span, outer_slope * span)
	return signf(signed_distance) * metres


static func _hermite(t: float, a: float, b: float, ma: float, mb: float) -> float:
	return (2*t*t*t - 3*t*t + 1)*a + (t*t*t - 2*t*t + t)*ma + (-2*t*t*t + 3*t*t)*b + (t*t*t - t*t)*mb


## Sim (x, y, z) in px -> world position in metres.
static func world_pos(px_x: float, px_y: float, px_z: float) -> Vector3:
	var c := court()
	return Vector3((px_x - center_x()) * WIDTH_M / (float(c["right"]) - float(c["left"])), px_z * PX_TO_M, depth_m(px_y))


## Sim (x, y) on the floor, at a given height in px.
static func world_floor(px_x: float, px_y: float, px_z: float = 0.0) -> Vector3:
	return world_pos(px_x, px_y, px_z)


static func material(color: Color, rough := 0.85, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# `alpha` is applied to the albedo, not just switched on. It used to only set the
	# transparency MODE and leave the colour opaque — so every "glass" pane was a
	# solid slab: the rear wall was there all along, drawn as an opaque lit surface
	# that read as a dark band. Found by sampling the rendered frame, not by reading
	# the code (`docs/wayfinder/evidence/quick-match-playable.md`).
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = material(color, 0.8, alpha)
	parent.add_child(mi)
	return mi


static func palette_color(arena: Dictionary, key: String, fallback: Color) -> Color:
	var palette: Dictionary = arena.get("palette", {})
	if not palette.has(key):
		return fallback
	return Color(String(palette[key]))


# ---------------------------------------------------------------------------
# Forwarders to the arena library (slice S6)
# ---------------------------------------------------------------------------

## Environment and lights for an arena. Built by `game/arenas/court_builder.gd`;
## loaded at call time rather than preloaded because the arena library preloads
## this file, and a static preload here would be a cycle.
static func build_world(parent: Node3D, arena: Dictionary) -> void:
	var builder = load("res://game/arenas/court_builder.gd")
	builder.build_world(parent, arena)


## Court, lines, net and glass cage for an arena. The arena's `wallBounce` is
## passed through: it decides the rear glass's alpha (`arena_library.gd`).
static func build_court(parent: Node3D, arena: Dictionary) -> void:
	var builder = load("res://game/arenas/court_builder.gd")
	builder.build_court(parent, arena, float(arena.get("wallBounce", 0.89)))


static func build_camera(parent: Node3D, preset: String) -> Camera3D:
	var cfg: Dictionary = CAMERAS.get(preset, CAMERAS["default"])
	var cam := Camera3D.new()
	cam.name = "MatchCam"
	cam.fov = float(cfg["fov"])
	parent.add_child(cam)
	cam.position = cfg["pos"]
	if preset == "playable":
		cam.look_at(cfg["look_at"], Vector3.UP)
	else:
		cam.rotation_degrees = Vector3(float(cfg["pitch_deg"]), 0.0, 0.0)
	cam.current = true
	return cam


## One GLB load; every athlete is a `duplicate()` of that scene graph, so the
## 31,325-triangle mesh and the 2048x2048 atlas are shared and four athletes do
## not cost four loads. Returns an empty Array if the GLB cannot be read.
static func load_athlete_scene() -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(GLB_PATH, st)
	if err != OK:
		push_error("court.gd: GLB append failed err=%d path=%s" % [err, GLB_PATH])
		return null
	var scene: Node = doc.generate_scene(st)
	if scene == null:
		push_error("court.gd: GLB generate_scene returned null")
		return null
	return scene


## A body for one athlete: the shared rig, holding its base pose, with a coloured
## ring on the floor so the four athletes are told apart (the GLB has one baked
## texture; see `docs/wayfinder/evidence/character-material-render.md`).
static func make_athlete(parent: Node3D, base_scene: Node, name: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var body: Node = base_scene.duplicate() if base_scene != null else null
	if body != null:
		root.add_child(body)
		for p in body.find_children("*", "AnimationPlayer", true, false):
			var ap := p as AnimationPlayer
			var names := ap.get_animation_list()
			if names.size() > 0:
				ap.play(names[0])
				var a: Animation = ap.get_animation(names[0])
				if a.length > 0.0:
					ap.seek(a.length, true)
				ap.pause()
	else:
		# Fallback body so the scene still loads if the GLB is unreadable.
		var capsule := MeshInstance3D.new()
		capsule.name = "FallbackBody"
		var cm := CapsuleMesh.new()
		cm.radius = 0.32
		cm.height = 1.8
		capsule.mesh = cm
		capsule.position = Vector3(0.0, 0.9, 0.0)
		capsule.material_override = material(tint)
		root.add_child(capsule)

	var ring := MeshInstance3D.new()
	ring.name = "TintRing"
	var rm := TorusMesh.new()
	rm.inner_radius = 0.34
	rm.outer_radius = 0.46
	ring.mesh = rm
	ring.position = Vector3(0.0, 0.03, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var mat := material(tint)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	root.add_child(ring)

	parent.add_child(root)
	return root


## The racket the athlete swings: one local frame, two heads.
##
## `standard` — and an empty `style`, so every pre-existing caller is untouched — is the
## shipped procedural ellipse: a 0.26 x 0.35 m face (a cylinder scaled along its own long
## axis, which is how the reference draws it too — an ellipse, `js/render.js:1346`) with a
## 0.13 m grip below it, in the athlete's tint. `cornetto` is Fornaio's Il Cornetto: a
## croissant where the face would be, a beech throat and a rolling-pin handle below it
## (`_build_cornetto_head`, `_build_cornetto_grip`).
##
## Both are VISUAL ONLY. The sim's `paddle.w` / `paddle.h` are contact-box dimensions and
## are NOT used as millimetres here; see the constants. Both roots are the same frame —
## the root is the head centre, the grip hangs below it — so
## `athletes_view.gd::RACKET_HAND_LOCAL` / `RACKET_HAND_ROTATION` still put the hand in
## the middle of either grip and no caller changes. Root's local frame: +X across the
## court, +Y up, +Z towards the net.
static func make_racket_view(parent: Node3D, name: String, tint: Color,
		style: StringName = &"") -> Node3D:
	var root := Node3D.new()
	root.name = name
	if style == RACKET_STYLE_CORNETTO:
		_build_cornetto_head(root)
		_build_cornetto_grip(root)
	else:
		_build_ellipse_racket(root, tint)
	parent.add_child(root)
	return root


## The shipped head: the tinted ellipse. Split out of `make_racket_view` when the
## cornetto style landed; the geometry, the materials and the node names are unchanged.
static func _build_ellipse_racket(root: Node3D, tint: Color) -> void:
	var face := MeshInstance3D.new()
	face.name = "Face"
	var cm := CylinderMesh.new()
	cm.top_radius = RACKET_FACE_R
	cm.bottom_radius = RACKET_FACE_R
	cm.height = RACKET_THICK
	cm.radial_segments = 20
	face.mesh = cm
	# The disc faces the net: the cylinder's own axis is +Y, so lay it down on Z.
	face.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	face.scale = Vector3(1.0, RACKET_FACE_LEN, 1.0)
	face.material_override = material(tint, 0.45)
	root.add_child(face)
	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	var gm := CylinderMesh.new()
	gm.top_radius = RACKET_GRIP_W
	gm.bottom_radius = RACKET_GRIP_W
	gm.height = RACKET_GRIP_L
	gm.radial_segments = 10
	grip.mesh = gm
	grip.position = Vector3(0.0, -(RACKET_FACE_R * RACKET_FACE_LEN + RACKET_GRIP_L * 0.5), 0.0)
	grip.material_override = material(tint.darkened(0.45), 0.6)
	root.add_child(grip)


## Il Cornetto's head: one large croissant arching over the throat, both horns pointing
## down — the pose and the palette of the intake image (`meshy/views/cornetto-front.png`;
## DNA in `meshy/fornaio-brief.md`). The pastry is the capsule chain `cornetto_segments()`:
## one bent segment per length of the crescent's midline, fattest over the top of the arch
## and tapering to a point at each horn, every other segment a little thinner so the crust
## reads as rolled dough, and each segment in its own crust tone. It is SOLID pastry — no
## strings, no perforations, no string bed — and its only opening is the concave underside
## the wooden throat sits in.
##
## VISUAL STAND-IN. The real Il Cornetto is the Meshy prop the brief describes; when that
## GLB lands it mounts at the same anchor (`AthletesView.RACKET_HAND_LOCAL`) and this
## head retires. Until then the match shows this, which is honest about being procedural.
static func _build_cornetto_head(root: Node3D) -> void:
	var crust := [Color("8c5316"), Color("a86a20"), Color("d0923b"), Color("e0a94f")]
	var fitted := _cornetto_fit()
	var scale: float = fitted["scale"]
	var centre_y: float = fitted["centre_y"]
	var head := Node3D.new()
	head.name = "CroissantHead"
	root.add_child(head)
	var segments := cornetto_segments()
	for i in segments.size():
		var segment: Dictionary = segments[i]
		var from: Vector2 = segment["from"]
		var to: Vector2 = segment["to"]
		var baked := _add_racket_capsule(head, "CroissantSegment_%02d" % i,
			Vector2(from.x * scale, from.y * scale + centre_y),
			Vector2(to.x * scale, to.y * scale + centre_y),
			float(segment["r"]) * scale, crust[i % crust.size()], 0.9)
		# Squashed across the net axis: a croissant is a fat roll, not a tube.
		baked.scale = Vector3(1.0, 1.0, CORNETTO_FLAT)


## Il Cornetto's lower half: a beech Y-throat cradling the two horns, a small matte brass
## ferrule, a turned rolling-pin handle wrapped in cream bakery twine. The grip band is
## the shipped one — `CORNETTO_HANDLE_L` is `RACKET_GRIP_L`, centred on the same y as the
## ellipse grip — so the hand attach lands on the handle exactly as it lands on the
## shipped grip, and the handle is what the hand closes on (never the pastry).
static func _build_cornetto_grip(root: Node3D) -> void:
	var beech := Color("c8a678")
	var brass := Color("b08a3e")
	var twine := Color("e8dfd1")
	var grip_y := -(RACKET_FACE_R * RACKET_FACE_LEN + RACKET_GRIP_L * 0.5)
	var grip_top := grip_y + RACKET_GRIP_L * 0.5
	var handle := Node3D.new()
	handle.name = "Handle"
	root.add_child(handle)
	_add_racket_cylinder(handle, "RollingPin", Vector3(0.0, grip_y, 0.0), RACKET_GRIP_L,
		CORNETTO_HANDLE_R, beech)
	for end in [grip_top, grip_y - RACKET_GRIP_L * 0.5]:
		_add_racket_cylinder(handle, "RollingPinKnob", Vector3(0.0, end, 0.0), CORNETTO_KNOB_L,
			CORNETTO_KNOB_R, beech.darkened(0.08))
	for i in 3:
		var y: float = grip_y + (float(i) - 1.0) * CORNETTO_TWINE_PITCH
		_add_racket_cylinder(handle, "TwineBand_%d" % i, Vector3(0.0, y, 0.0), CORNETTO_TWINE_L,
			CORNETTO_TWINE_R, twine)
	var throat := Node3D.new()
	throat.name = "Throat"
	root.add_child(throat)
	var ferrule_y := grip_top + CORNETTO_FERRULE_L * 0.5 + 0.002
	_add_racket_cylinder(throat, "Ferrule", Vector3(0.0, ferrule_y, 0.0), CORNETTO_FERRULE_L,
		CORNETTO_FERRULE_R, brass, 0.55)
	var stem_y := grip_top + CORNETTO_FERRULE_L + CORNETTO_STEM_L * 0.5
	_add_racket_cylinder(throat, "ThroatStem", Vector3(0.0, stem_y, 0.0), CORNETTO_STEM_L,
		0.019, beech)
	var fitted := _cornetto_fit()
	var scale: float = fitted["scale"]
	var centre_y: float = fitted["centre_y"]
	var knots := cornetto_knots()
	var horns := [knots[0], knots[knots.size() - 1]]
	for i in horns.size():
		var horn_knot: Dictionary = horns[i]
		var at: Vector2 = horn_knot["pos"]
		var horn := Vector2(at.x * scale, at.y * scale + centre_y)
		var from := Vector2(0.0, stem_y + CORNETTO_STEM_L * 0.5)
		var tip := horn + (horn - from).normalized() * CORNETTO_ARM_OVERLAP
		_add_racket_strut(throat, "ThroatArm_%d" % i, from, tip, CORNETTO_ARM_R, beech)


## One bevelled cylinder in a racket's own frame: `at` is the centre of the cylinder,
## whose axis runs along +Y.
static func _add_racket_cylinder(parent: Node3D, name: String, at: Vector3, height: float,
		radius: float, color: Color, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.position = at
	mi.material_override = material(color, rough)
	parent.add_child(mi)
	return mi


## One cylinder between two points of the racket's own XY plane, pointing at the second.
## The cylinder's own axis is +Y: a rotation of theta about Z sends it to
## `(-sin theta, cos theta)`, so theta is `atan2(-dx, dy)`.
static func _add_racket_strut(parent: Node3D, name: String, from: Vector2, to: Vector2,
		radius: float, color: Color) -> MeshInstance3D:
	var span := to - from
	var middle := Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, 0.0)
	var mi := _add_racket_cylinder(parent, name, middle, span.length(), radius, color)
	mi.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(atan2(-span.x, span.y)))
	return mi


## One capsule (a cylinder with round ends) between two points of the racket's own XY
## plane, oriented like `_add_racket_strut`. `CapsuleMesh.height` is the FULL height
## including both hemispheres, so the chord plus `2 * radius` puts the cylinder section
## exactly on the two points and lets the caps overshoot each joint by one radius — which
## is what makes the croissant's segments blend into one bent tube instead of reading as
## beads on a wire (measured: a bare chord pinches the tube at every knot, 0.25 m wide
## instead of 0.26 m).
static func _add_racket_capsule(parent: Node3D, name: String, from: Vector2, to: Vector2,
		radius: float, color: Color, rough := 0.9) -> MeshInstance3D:
	var span := to - from
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = span.length() + radius * 2.0
	cm.radial_segments = 14
	cm.rings = 4
	mi.mesh = cm
	mi.position = Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, 0.0)
	mi.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(atan2(-span.x, span.y)))
	mi.material_override = material(color, rough)
	parent.add_child(mi)
	return mi


## The crescent's two circles, derived from the three consts and NOT guessed: the bite's
## radius follows from requiring its circle to cross the outer one exactly at the horns,
## `(tip_x, -CORNETTO_TIP_Y)`, and `horn_deg` is where those crossings sit.
static func cornetto_crescent() -> Dictionary:
	var outer := CORNETTO_OUTER_R
	var tip := CORNETTO_TIP_Y
	var tip_x := sqrt(maxf(outer * outer - tip * tip, 0.0))
	var bite := sqrt(maxf(CORNETTO_BITE_D * CORNETTO_BITE_D + outer * outer
		- 2.0 * CORNETTO_BITE_D * tip, 0.0))
	return {
		"outer_r": outer,
		"bite_r": bite,
		"tip_x": tip_x,
		"horn_deg": rad_to_deg(atan2(tip_x, -tip)),
	}


## The crescent's midline, in metres before the fit: `CORNETTO_KNOTS` points swept from
## one horn through the top of the arch to the other, each with the local half-thickness
## of the lune. The bite circle is centred `CORNETTO_BITE_D` BELOW the head centre, so the
## ray at angle phi meets it at `t(phi)` and the pastry is the ring's worth of material
## between `t` and the outer radius: fat over the top, tapering to the horns. `horn_deg`
## where `t` reaches the outer radius IS the horn. Pure maths, so the head can be fitted
## and measured without a scene.
static func cornetto_knots() -> Array:
	var crescent := cornetto_crescent()
	var outer: float = crescent["outer_r"]
	var bite: float = crescent["bite_r"]
	var horn_deg: float = crescent["horn_deg"]
	var knots := []
	for i in CORNETTO_KNOTS:
		var t := float(i) / float(CORNETTO_KNOTS - 1)
		var phi := deg_to_rad(horn_deg * (2.0 * t - 1.0))
		var cos_phi := cos(phi)
		var reach := -CORNETTO_BITE_D * cos_phi + sqrt(maxf(
			CORNETTO_BITE_D * CORNETTO_BITE_D * cos_phi * cos_phi + bite * bite
			- CORNETTO_BITE_D * CORNETTO_BITE_D, 0.0))
		reach = minf(reach, outer)
		var middle := (outer + reach) * 0.5
		var half := (outer - reach) * 0.5
		# The horns keep only part of their thickness, so the OUTER edge tapers as well.
		var taper := 1.0 - CORNETTO_HORN_TAPER * pow(absf(2.0 * t - 1.0), 1.5)
		knots.append({
			"pos": Vector2(sin(phi) * middle, cos(phi) * middle),
			"r": maxf(half * taper, CORNETTO_HORN_MIN_R),
		})
	return knots


## The head as the capsules `_build_cornetto_head` draws: one per gap between knots, its
## radius the mean of the two knots', every other one thinned by `CORNETTO_SEGMENT_GAP`.
static func cornetto_segments() -> Array:
	var knots := cornetto_knots()
	var segments := []
	for i in CORNETTO_KNOTS - 1:
		var a: Dictionary = knots[i]
		var b: Dictionary = knots[i + 1]
		var r := 0.5 * (float(a["r"]) + float(b["r"]))
		if i % 2 == 1:
			r *= 1.0 - CORNETTO_SEGMENT_GAP
		segments.append({"from": a["pos"], "to": b["pos"], "r": r})
	return segments


## The design-space bounds of `cornetto_segments()`: half the head's width, its top and
## its bottom. A capsule is the segment's own box grown by its radius on every side, so
## this is the exact box of what is drawn — the fit is built on it, and it is where the
## "same size band as the ellipse" claim comes from rather than from a guess.
static func cornetto_bounds() -> Dictionary:
	var half_width := 0.0
	var top := -INF
	var bottom := INF
	for segment in cornetto_segments():
		var a: Vector2 = segment["from"]
		var b: Vector2 = segment["to"]
		var r: float = segment["r"]
		half_width = maxf(half_width, maxf(absf(a.x), absf(b.x)) + r)
		top = maxf(top, maxf(a.y, b.y) + r)
		bottom = minf(bottom, minf(a.y, b.y) - r)
	return {"half_width": half_width, "top": top, "bottom": bottom}


## The single fit that keeps the cornetto in the shipped racket's size band: the scale
## that puts the croissant's widest segment exactly on the ellipse face's width
## (`2 * RACKET_FACE_R` = 0.26 m), and the y that centres the head's bounding box on the
## root — the root the hand attach is calibrated against. The grip is NOT scaled: it is
## the shipped grip band, so the two styles swing from the same frame.
static func _cornetto_fit() -> Dictionary:
	var bounds := cornetto_bounds()
	var scale := RACKET_FACE_R / maxf(float(bounds["half_width"]), 0.0001)
	return {
		"scale": scale,
		"centre_y": -0.5 * (float(bounds["top"]) + float(bounds["bottom"])) * scale,
	}
