## court.gd — the shared mapping between the simulation's pixel space and the 3D
## world, plus the camera and athlete-rig builders the quick match reuses.
##
## Nothing here re-implements physics or tuning. It is presentation:
##
##   - the court, net, lines and glass all come from the frozen `COURT` table and
##     from `SERVICE_LINE_OFFSET` (`js/game.js:30`), under ONE uniform scale;
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
## Scale (recorded, not resolved): `PX_TO_M = 0.025` m/px is the value that turns
## `COURT`'s 800 px span into the FIP 20.00 m length, and therefore its 508 px
## depth into 12.70 m. `COURT`'s aspect (1.575) is not 20:10 and stays an open
## question owned by Luca; this file only records the single scale it used.
##
## Sim px -> world: X across the court, Y along the court (increasing towards the
## near/player half), Z up. The sim's `court.netY` is world z = 0 and the sim's
## `court.left` is world x = -HALF_LEN, so the mapping is one translation plus
## the single scale.
extends RefCounted

const Frozen := preload("res://src/sim/frozen.gd")

## One uniform scale for both court axes. `PLAN.md` "Court aspect" row.
const PX_TO_M := 0.025
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
		"pos": Vector3(0.0, 14.4552, 6.4000),
		"pitch_deg": -65.2000,
		"fov": 50.866,
		"look_at": Vector3.ZERO,
	},
	"wide": {
		"pos": Vector3(0.0, 16.6235, 7.4000),
		"pitch_deg": -68.0000,
		"fov": 60.000,
		"look_at": Vector3.ZERO,
	},
	"playable": {
		"pos": Vector3(0.0, 3.2000, 5.8000),
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
	var c := court()
	return (float(c["right"]) - float(c["left"])) * PX_TO_M


static func court_depth() -> float:
	var c := court()
	return (float(c["bottom"]) - float(c["top"])) * PX_TO_M


static func half_len() -> float:
	return court_len() / 2.0


static func half_depth() -> float:
	return court_depth() / 2.0


static func net_h() -> float:
	return float(court()["netHeight"]) * PX_TO_M


## `SERVICE_LINE_OFFSET` is 126 px in the sim (`js/game.js:30`) = 3.150 m here.
static func service_z() -> float:
	return 126.0 * PX_TO_M


## Sim (x, y, z) in px -> world position in metres.
static func world_pos(px_x: float, px_y: float, px_z: float) -> Vector3:
	return Vector3((px_x - center_x()) * PX_TO_M, px_z * PX_TO_M, (px_y - net_y()) * PX_TO_M)


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


## The racket the athlete swings.
##
## Geometry: a 0.26 x 0.35 m face (a cylinder scaled along its own long axis, which
## is how the reference draws it too — an ellipse, `js/render.js:1346`) with a 0.13 m
## grip below it, in the athlete's tint. The sim's `paddle.w` / `paddle.h` are
## contact-box dimensions and are NOT used as millimetres here; see the constants.
## The root's local frame is the hand: +X across the court, +Y up, +Z towards the net.
static func make_racket_view(parent: Node3D, name: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = name
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
	parent.add_child(root)
	return root
