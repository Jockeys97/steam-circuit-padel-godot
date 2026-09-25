## fantasy_environment.gd — the six pictured arenas rebuilt as real 3D environments.
##
## WHAT THIS REPLACES. The reference paints each arena's far view as one flat canvas
## (`js/render.js`'s backdrop functions) and this port copied that as a camera-sized
## quad: `ArenaScenery`'s `Backdrop` / `BackdropArtwork` / `BackdropVeil` plus one
## `Dressing_*` container per painted prop. From the court that reads as a picture panel
## hung behind the glass, and from the selectable cameras it is a rectangle with visible
## edges. This module hides all of it for the six arenas below and stands a real
## environment in its place:
##
##   cattedrale  brass gothic nave — arcade, buttresses, rose window, organ rank
##   forgia      enclosed foundry hall — furnace mouths, gantries, molten channels
##   tempesta    suspended storm platform — deck, chains, cloud sea, distant lightning
##   abissale    underwater observatory — ribbed frame, ruins, marine depth
##   caldera     platform over volcanic terrain — rock walls, titans, lava, embers
##   orrery      celestial observatory — armillary, ring architecture, starfield
##
## THE ENVELOPE, AND WHY THE COURT STAYS CLEAR. Every camera in `court.gd::CAMERAS`
## looks at the court from +z (z = +5 .. +27.5, one at x = +19), so the envelope is
## argued per direction rather than guessed:
##
##   * The rear hall stands at z <= REAR_Z (-13.5), behind the rear glass at z = -10 and
##     behind the old backdrop's plane (-12). A ray from any camera to any court point
##     ends at z >= -10, so nothing at z < -10 can be between them: the rear structure
##     is background by construction, however tall it is.
##   * Side structures start at |x| = SIDE_X (9.0), outside the cage (|x| = 5.5). The
##     cameras in the axis plane send rays whose |x| never exceeds 5.5 m, so they cannot
##     meet a wing at 9 m; the one off-axis camera (broadcast, x = +19) sends rays that
##     stay at z >= +10, in front of the wings' near end at z = +8, so it cannot either.
##   * Nothing is placed above the playable footprint at any height: vault ribs exist
##     only over the rear hall (z < REAR_Z) and over the wings (|x| > SIDE_X). A
##     top-down camera therefore sees the court unobstructed.
##
## That argument is not asked to be believed: `tests/fantasy_arenas_test.gd` casts the
## live cameras' own rays at a grid of court points and fails if any fantasy mesh bound
## meets one, for all seven presets. The envelope is the design; the test is the proof.
##
## THE ENVIRONMENT AND LIGHTS ARE OURS. `court_builder.gd::build_world` gives every arena
## one flat `BG_COLOR` rig and `ArenaLook.apply` only knows the world five, so the six
## used to keep a single-colour background with no sky, fog or glow. Per the approved
## rebuild they now get their own rig: procedural sky, sky-driven ambient, depth fog in
## the arena's own far colour, glow (lanterns and lava bloom), contact SSAO, AgX
## tonemapping and a key/fill pair chosen for the arena's own light.
## `tests/arena_look_test.gd::_frozen_nine_untouched` keeps pinning the three depot
## arenas exactly; the six redesigned ids are gated by `tests/fantasy_arenas_test.gd`
## (sky set, fog on, court readable, and that suite's section-3 compatibility rules
## still holding for them).
##
## BUDGET. Contract ceiling: 100k extra triangles and 200 extra draw instances per arena,
## measured separately from the existing stands. Repetition goes through
## `fantasy_kit.gd::multi` (one draw per repeated family) and every decorative mesh is
## `cast_shadow = OFF`. The test prints the per-arena numbers; `REPORT.md` records them.
##
## NOTHING PHYSICAL. No collision shapes, no lights beyond the arena's own Sun/Fill
## (whose colour and direction this module tunes), no simulation state, no save data, no
## court geometry. The court, net, cage and stands are the shared build, untouched.
extends RefCounted

const Kit := preload("res://game/arenas/fantasy/fantasy_kit.gd")
const Motion := preload("res://game/arenas/fantasy/fantasy_motion.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Court := preload("res://game/court.gd")

## The six arenas this module owns, in the frozen roster's order.
const IDS := ["cattedrale", "forgia", "tempesta", "abissale", "caldera", "orrery"]
## The five the module must never touch.
const UNTOUCHED := ["officina", "locomotive", "clockwork", "torii", "medina", "carioca", "aurora", "egeo"]

const ROOT_NAME := "FantasyEnvironment"
## The rear hall's plane: behind the rear glass (-10) and behind the old backdrop (-12).
const REAR_Z := -13.5
## The nearest side structure's inner face. The cage ends at 5.5 m, so 9 m clears it.
const SIDE_X := 9.0
## The rear hall's roof line. The measured band tops at z=-12 are 4.80 m (default),
## 11.06 m (wide) and 12.30 m (playable), so 14 m covers every supported view's band.
const HALL_TOP := 14.0
## The rear hall's half width. The measured band half-widths are 20.70 m (default) and
## 36.88 m (wide): 27 m covers the default band outright and leaves the widest view's
## outermost columns against the sky, which is what a real open-roofed hall does.
const HALL_HALF_X := 27.0
## The wings' near end. The one off-axis camera (broadcast, z = +25) sends rays to the
## court that stay at z >= +10, so a wing ending at +8 is never between them.
const WING_Z_NEAR := 8.0
const WING_Z_FAR := -30.0

## THE OCCLUSION CLASSIFICATION, declared here so the lane's test reads the module's own
## vocabulary instead of guessing by name. `tests/fantasy_arenas_test.gd` excludes these
## three families from its camera-to-court ray test and fails if an arena declares none of
## one kind, so nothing can be hidden from the test by renaming it.
##
## SHELLS are enclosing boundaries: the camera stands inside them, so "a ray crosses it" is
## true of every ray and describes no occlusion. Their AABBs would also be wrong in the
## other direction — a sphere's AABB fills its own centre, which is where the court is.
const SHELL_NAMES := ["Dome", "CloudSea", "CloudDeck", "StormWall", "ViewGlass",
	"LavaSea", "StarShell"]
## SCATTER is alpha-blended atmosphere with no opaque surface: clouds, smoke, bubbles,
## motes, dust. Excluded because there is no surface to block a view.
const SCATTER_NAMES := ["Embers", "FlueSmoke", "Incense", "Motes", "Bubbles", "School",
	"Dust", "Lightning", "Jelly"]
## ROTORS are the slow spinning wheels. Their AABB describes the disc, not the rim and
## spokes a ray actually meets; they are bounded instead by section F's speed assertion and
## by being placed at |x| >= 9 or z <= REAR_Z.
const ROTOR_NAMES := ["NaveWheelL", "NaveWheelR", "RoseRotor", "FlywheelL", "FlywheelR",
	"FlywheelFar", "TurbineL", "TurbineR", "AirshipProp", "CalderaGearMain", "CalderaGearL",
	"CalderaGearR", "Armillary", "Carousel", "Jelly"]


static func is_shell(node_name: String) -> bool:
	return _matches(SHELL_NAMES, node_name)


static func is_scatter(node_name: String) -> bool:
	return _matches(SCATTER_NAMES, node_name)


static func is_rotor(node_name: String) -> bool:
	return _matches(ROTOR_NAMES, node_name)


## Prefix match, because Godot appends `@2`-style suffixes only for anonymous nodes: every
## node this module names is named once per arena, and the numbered ones (`Motes`, `School`)
## are matched by prefix so a future `MotesFar` stays in the same class.
static func _matches(list: Array, node_name: String) -> bool:
	for entry in list:
		if node_name.begins_with(String(entry)):
			return true
	return false


static func handles(id: String) -> bool:
	return IDS.has(id)


## True when this arena's rebuild hides the shared 80 m ground plane and stands its own
## deck in the same place — the two arenas that are explicitly platforms over a void.
static func replaces_ground(id: String) -> bool:
	return id in ["tempesta", "caldera"]


## Build the environment for one of the six. Returns null for any other id, so the
## caller may invoke it unconditionally after the shared scenery build.
static func build(arena_root: Node3D, id: String, preset := "default") -> Node3D:
	if not handles(id) or arena_root == null:
		return null
	_hide_legacy(arena_root, id)
	var ctx := _ctx(id)
	var root := Node3D.new()
	root.name = ROOT_NAME
	root.set_meta("arena_id", id)
	root.set_meta("replaces_ground", replaces_ground(id))
	root.set_meta("preset", preset)
	arena_root.add_child(root)
	var motion := Motion.new()
	motion.name = "Motion"
	root.add_child(motion)

	match id:
		"cattedrale": _cattedrale(root, motion, ctx)
		"forgia": _forgia(root, motion, ctx)
		"tempesta": _tempesta(root, motion, ctx)
		"abissale": _abissale(root, motion, ctx)
		"caldera": _caldera(root, motion, ctx)
		"orrery": _orrery(root, motion, ctx)
	_rig_lights(arena_root, id)
	return root


## Hide the legacy painted view for these six: every `Backdrop*` quad and every
## `Dressing_*` container. Hidden rather than removed, because `game_slice_test.gd`
## requires both to still exist for the frozen nine (the same thing `egeo` relies on).
## The two platform arenas stand over a void, so the shared apron plane goes too and
## their own deck takes its place.
static func _hide_legacy(arena_root: Node3D, id: String) -> void:
	var scenery := arena_root.get_node_or_null("Scenery")
	if scenery != null:
		for child in scenery.get_children():
			var nm := String(child.name)
			if nm.begins_with("Backdrop") or nm.begins_with("Dressing_"):
				if child is Node3D:
					(child as Node3D).hide()
	if replaces_ground(id):
		var surround := arena_root.get_node_or_null("Surround") as MeshInstance3D
		if surround != null:
			surround.hide()


## Everything the builders read: this arena's frozen palette (floor/accent/gear) and the
## style table's glow/apron.
static func _ctx(id: String) -> Dictionary:
	var style := ArenaStyle.style(id)
	var row := {}
	for r in Frozen.arenas():
		if String(r.get("id", "")) == id:
			row = r
			break
	return {
		"id": id,
		"floor": Court.palette_color(row, "floor", Color(0.10, 0.22, 0.18)),
		"accent": Court.palette_color(row, "accent", Color(0.0, 0.898, 1.0)),
		"gear": Court.palette_color(row, "gear", Color(0.784, 0.565, 0.0)),
		"glow": Color(String(style.get("glow", "#ffffff"))),
		"apron": Color(String(style.get("apron", "#303030"))),
	}


# ---------------------------------------------------------------------------
# Shared construction recipes
# ---------------------------------------------------------------------------

## The continuous background shell: one low-poly sphere enclosing the arena, unshaded and
## drawn with a world-height gradient. This is what makes the far view continuous in every
## direction rather than ending at a quad's edge, and it costs one draw call.
static func _dome(root: Node3D, stops: Dictionary, radius := 300.0) -> MeshInstance3D:
	return Kit.part(root, "Dome", Kit.sphere_mesh(radius, 24, 12), Vector3.ZERO, Kit.shell(stops))


## The rear hall: a wall across the arena's far end carrying a repeated arcade. The wall
## itself is one box; the arcade is one MultiMesh of piers and one of arch voussoirs, so a
## nine-bay arcade costs two draws instead of thirty-six.
static func _rear_hall(root: Node3D, wall_mat: Material, trim_mat: Material, arc_mat: Material,
		bays := 9, arch_r := 3.6, pier_h := 6.0, wall_z := REAR_Z) -> void:
	Kit.box(root, "HallRear", Vector3(HALL_HALF_X * 2.0, HALL_TOP, 0.8),
		Vector3(0.0, HALL_TOP * 0.5, wall_z), wall_mat)
	Kit.box(root, "HallPlinth", Vector3(HALL_HALF_X * 2.0, 0.7, 1.1),
		Vector3(0.0, 0.35, wall_z + 0.2), trim_mat)
	Kit.box(root, "HallCornice", Vector3(HALL_HALF_X * 2.0, 0.55, 1.2),
		Vector3(0.0, pier_h + arch_r + 0.5, wall_z + 0.25), trim_mat)
	var span := HALL_HALF_X * 2.0 - 4.0
	var pitch := span / float(maxi(bays, 1))
	var pier_x: Array = []
	for i in bays + 1:
		var x := -span * 0.5 + pitch * float(i)
		pier_x.append(Transform3D(Basis.IDENTITY, Vector3(x, pier_h * 0.5, wall_z + 0.9)))
	Kit.multi(root, "HallPiers", Kit.box_mesh(Vector3(0.9, pier_h, 0.9)), trim_mat, pier_x)
	var arch_x: Array = []
	for i in bays:
		var cx := -span * 0.5 + pitch * (float(i) + 0.5)
		arch_x.append_array(Kit.arc_xforms(9, Vector3(cx, pier_h, wall_z + 0.9), arch_r, 180.0,
			wall_z + 0.9, arch_r * 0.38))
	Kit.multi(root, "HallArches", Kit.box_mesh(Vector3(0.5, 0.5, 0.5)), arc_mat, arch_x)


## The two side wings: a balustrade just outside the cage, a colonnade at |x| = SIDE_X and
## a taller wall behind both. Every part is at |x| >= SIDE_X - 0.6, so the envelope holds.
static func _wings(root: Node3D, wall_mat: Material, trim_mat: Material, col_mat: Material,
		col_h := 9.0, cols := 9) -> void:
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		var z_mid := (WING_Z_NEAR + WING_Z_FAR) * 0.5
		var z_len := WING_Z_NEAR - WING_Z_FAR
		Kit.box(root, "Parapet_%s" % tag, Vector3(0.5, 1.1, z_len),
			Vector3(side * (SIDE_X - 0.55), 0.55, z_mid), trim_mat)
		Kit.box(root, "WingWall_%s" % tag, Vector3(1.0, col_h + 2.0, z_len),
			Vector3(side * (SIDE_X + 5.0), (col_h + 2.0) * 0.5, z_mid), wall_mat)
		Kit.multi(root, "WingColumns_%s" % tag, Kit.cyl_mesh(col_h, 0.42, 0.5, 8), col_mat,
			Kit.line_xforms(cols, Vector3(side * SIDE_X, col_h * 0.5, WING_Z_NEAR),
				Vector3(side * SIDE_X, col_h * 0.5, WING_Z_FAR)))


## Vault ribs over the rear hall only (z < REAR_Z): the same recipe as `_rear_hall`'s
## arcade, lifted and repeated down the hall's length. One MultiMesh for the whole vault.
##
## THE RADIUS IS THE WHOLE TRICK, and it is why the first pass rendered five plain columns.
## Only the 70-degree crown of each arc is kept, so with a 20 m radius the visible fragment
## sat ~19 m up and ~12 m out — off the corners of the frame — while the two straight,
## nearly-vertical bottom segments fell exactly where the frame is. The result read as giant
## plain cylinders with the arch clipped out. At a 13 m radius with the arc's centre dropped
## below the deck, the same 70-degree span lands the crown just above the cornice and both
## feet well down the side walls, so the frame sees a connected rib.
static func _vault(root: Node3D, rib_mat: Material, ribs := 6, radius := 13.0) -> void:
	var xforms: Array = []
	for i in ribs:
		var z := REAR_Z - 2.5 - float(i) * 2.6
		# The arc's centre sits 7 m below the hall floor, so the visible crown tops out near
		# the cornice line and the rib's legs reach the plinth instead of vanishing upward.
		xforms.append_array(Kit.arc_xforms(17, Vector3(0.0, -7.0, z), radius, 96.0, z, 1.5))
	Kit.multi(root, "Vault", Kit.box_mesh(Vector3(0.42, 0.42, 1.0)), rib_mat, xforms)


## Ribs in the YZ plane at a given x: a run of arches parallel to the court's long axis.
## This is what gives the observatory and the foundry a vaulted side silhouette without a
## single rib passing over the court.
static func _ribs_yz(root: Node3D, name: String, mat: Material, x: float, z_from: float,
		count: int, radius := 8.0, span := 180.0) -> void:
	var xforms: Array = []
	for i in count:
		var z := z_from - float(i) * 3.2
		xforms.append_array(Kit.arc_xforms_yz(17, Vector3(x, 0.0, z), radius, span, 1.6))
	Kit.multi(root, name, Kit.box_mesh(Vector3(0.45, 0.45, 1.0)), mat, xforms)


## A spinning wheel: rim + hub + spokes under a pivot the motion node turns. Returns the
## pivot so callers can register it; the meshes are children, so one `add_spin` moves all.
static func _wheel(root: Node3D, motion: Node3D, name: String, at: Vector3, radius: float,
		rim_mat: Material, spoke_mat: Material, speed_deg: float, spokes := 8) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name
	pivot.position = at
	root.add_child(pivot)
	var rim := Kit.torus(pivot, "Rim", radius * 0.86, radius, Vector3.ZERO, rim_mat, 20, 8)
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var hub := Kit.cyl(pivot, "Hub", 0.5, radius * 0.16, radius * 0.16, Vector3.ZERO, spoke_mat, 10)
	hub.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	# A spoke is a bar the wheel's own diameter long, placed by `wheel_xforms` so its middle
	# sits at half the radius. The first pass scaled it to 0.94 x radius and placed it at
	# 0.48 x radius, so every spoke tip stopped short of the rim and the wheels read as
	# floating, disconnected geometry — the "cube chunks" the review flagged on cattedrale.
	var spoke_mesh := Kit.box_mesh(Vector3(radius, 0.16, 0.14))
	Kit.multi(pivot, "Spokes", spoke_mesh, spoke_mat, Kit.wheel_xforms(spokes, Vector3.ZERO, radius * 0.5))
	motion.add_spin(pivot, speed_deg, Vector3.BACK)
	return pivot


## The platform deck for the two arenas that stand over a void. Its top sits 3 cm below the
## court bed so the shared court still reads as the court and the deck as the platform it
## is bolted to; it extends well past the cage in both directions.
static func _deck(root: Node3D, deck_mat: Material, trim_mat: Material, hx := 22.0, hz := 24.0) -> void:
	Kit.box(root, "Deck", Vector3(hx * 2.0, 1.0, hz * 2.0), Vector3(0.0, -0.53, 0.0), deck_mat)
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		Kit.box(root, "DeckEdgeX_%s" % tag, Vector3(0.5, 1.35, hz * 2.0),
			Vector3(side * hx, -0.45, 0.0), trim_mat)
		Kit.box(root, "DeckEdgeZ_%s" % tag, Vector3(hx * 2.0, 1.35, 0.5),
			Vector3(0.0, -0.45, side * hz), trim_mat)
	# Under-deck trusses: one MultiMesh crossing each way.
	var cross_x: Array = []
	var cross_z: Array = []
	for i in 7:
		var z := -18.0 + float(i) * 6.0
		cross_x.append(Transform3D(Basis.IDENTITY, Vector3(0.0, -2.4, z)))
	for i in 7:
		var x := -18.0 + float(i) * 6.0
		cross_z.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, -2.4, 0.0)))
	Kit.multi(root, "DeckBeamsX", Kit.box_mesh(Vector3(hx * 1.8, 0.5, 0.5)), trim_mat, cross_x)
	Kit.multi(root, "DeckBeamsZ", Kit.box_mesh(Vector3(hz * 1.7, 0.5, 0.5)), trim_mat, cross_z)


## Corner lanterns: emissive posts and caps at |x| = 11, outside the cage. Emissive paint
## rather than a real light, which is what keeps the arena's light count at Sun + Fill.
static func _lanterns(root: Node3D, post_mat: Material, glass_mat: Material, x := 11.0, z := 12.0, h := 2.6) -> void:
	var posts: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			posts.append(Transform3D(Basis.IDENTITY, Vector3(sx * x, h * 0.5, sz * z)))
	Kit.multi(root, "LanternPosts", Kit.cyl_mesh(h, 0.16, 0.2, 8), post_mat, posts)
	var glass: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			glass.append(Transform3D(Basis.IDENTITY, Vector3(sx * x, h + 0.25, sz * z)))
	Kit.multi(root, "LanternGlass", Kit.box_mesh(Vector3(0.42, 0.62, 0.42)), glass_mat, glass)


# ---------------------------------------------------------------------------
# cattedrale — brass gothic nave
# ---------------------------------------------------------------------------

static func _cattedrale(root: Node3D, motion: Node3D, ctx: Dictionary) -> void:
	var stone := Kit.standard(Color("241a33"), 0.92)
	var stone_dark := Kit.standard(Color("171027"), 0.95)
	var brass := Kit.standard(Color("b4883c"), 0.34, 0.55)
	var brass_lit := Kit.standard(Color("d9b25e"), 0.28, 0.6, Color("d9b25e"), 0.28)
	var violet := Kit.unshaded(Color("c98bff"), 0.7)
	var window_mat := Kit.unshaded(Color("7d5cff"), 0.55)
	_dome(root, {"bottom": Color("100a1c"), "mid": Color("2c1c48"), "top": Color("0a0616"),
		"mid_point": 0.42, "y_min": -6.0, "y_max": 70.0, "haze": Color("4b3a6b"), "haze_amount": 0.25})
	_rear_hall(root, stone, brass, brass_lit, 9, 3.6, 6.6)
	# Nine tall lancet windows, one per bay, plus their pointed heads: two MultiMeshes.
	var span := HALL_HALF_X * 2.0 - 4.0
	var pitch := span / 9.0
	var panes: Array = []
	var heads: Array = []
	for i in 9:
		var cx := -span * 0.5 + pitch * (float(i) + 0.5)
		panes.append(Transform3D(Basis.IDENTITY, Vector3(cx, 10.4, REAR_Z + 0.92)))
		heads.append(Transform3D(Basis(Vector3.BACK, deg_to_rad(45.0)), Vector3(cx - 0.75, 13.0, REAR_Z + 0.92)))
		heads.append(Transform3D(Basis(Vector3.BACK, deg_to_rad(-45.0)), Vector3(cx + 0.75, 13.0, REAR_Z + 0.92)))
	Kit.multi(root, "Lancets", Kit.box_mesh(Vector3(1.5, 6.6, 0.16)), window_mat, panes)
	Kit.multi(root, "LancetHeads", Kit.box_mesh(Vector3(1.1, 0.28, 0.16)), window_mat, heads)
	# The rose window: rim, twelve spokes, and an unshaded violet heart.
	var rose := Vector3(0.0, 11.2, REAR_Z + 1.0)
	var rim := Kit.torus(root, "RoseRim", 2.5, 3.1, rose, brass_lit, 24, 8)
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	Kit.multi(root, "RoseSpokes", Kit.box_mesh(Vector3(5.0, 0.16, 0.16)), brass,
		Kit.wheel_xforms(12, rose, 1.25))
	var heart := Kit.cyl(root, "RoseHeart", 0.22, 2.45, 2.45, rose + Vector3(0.0, 0.0, -0.05), violet, 24)
	heart.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	# The organ rank: two banks of pipes either side of the rose, one MultiMesh, heights
	# carried by per-instance scale.
	var pipes: Array = []
	for bank in [-1.0, 1.0]:
		for i in 11:
			var x: float = bank * (7.4 + float(i) * 1.45)
			var h: float = 3.2 + sin(float(i) * 0.7) * 1.1 + (0.6 if i % 3 == 0 else 0.0)
			pipes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)),
				Vector3(x, 9.0 + h * 0.5 - 1.6, REAR_Z + 1.3)))
	Kit.multi(root, "OrganPipes", Kit.cyl_mesh(1.0, 0.26, 0.3, 8), brass, pipes)
	# Buttresses leaning on the front of the wall, one MultiMesh per side.
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		var xs: Array = []
		for i in 6:
			var x: float = side * (10.0 + float(i) * 3.2)
			xs.append(Transform3D(Basis(Vector3.BACK, deg_to_rad(side * 12.0)), Vector3(x, 3.4, REAR_Z + 1.6)))
		Kit.multi(root, "Buttress_%s" % tag, Kit.box_mesh(Vector3(1.1, 7.0, 1.6)), stone_dark, xs)
	_wings(root, stone_dark, brass, brass_lit, 10.5, 9)
	_vault(root, brass, 7, 21.0)
	# Drifting incense smoke in the nave, behind the rear glass: the arena's own slow
	# vertical motion, and the reason this arena is not only wheels.
	var smoke: Array = []
	for i in 22:
		smoke.append(Transform3D(Basis.IDENTITY, Vector3(-22.0 + float(i % 11) * 4.4, 0.6, REAR_Z - 2.0 - float(i % 4) * 2.0)))
	var smoke_node := Kit.multi(root, "Incense", Kit.box_mesh(Vector3(0.5, 0.5, 0.5)), violet, smoke)
	motion.add_drift(smoke_node, 0.5, 0.4, 13.0, 10.0, 10.0)
	# Slow mechanical movement: the two nave wheels and the rose rotor, all under 3 deg/s.
	_wheel(root, motion, "NaveWheelL", Vector3(-17.0, 11.0, REAR_Z + 0.6), 2.4, brass, brass_lit, 1.6, 10)
	_wheel(root, motion, "NaveWheelR", Vector3(17.0, 11.0, REAR_Z + 0.6), 2.4, brass, brass_lit, -1.6, 10)
	var rotor := Node3D.new()
	rotor.name = "RoseRotor"
	rotor.position = rose + Vector3(0.0, 0.0, 0.22)
	root.add_child(rotor)
	Kit.multi(rotor, "RoseRotorSpokes", Kit.box_mesh(Vector3(4.6, 0.1, 0.1)), brass_lit,
		Kit.wheel_xforms(8, Vector3.ZERO, 1.2))
	motion.add_spin(rotor, 1.2, Vector3.BACK)


# ---------------------------------------------------------------------------
# forgia — enclosed foundry hall
# ---------------------------------------------------------------------------

static func _forgia(root: Node3D, motion: Node3D, ctx: Dictionary) -> void:
	var brick := Kit.standard(Color("3a2530"), 0.95)
	var steel := Kit.standard(Color("2b2325"), 0.75, 0.35)
	var iron := Kit.standard(Color("191517"), 0.9, 0.2)
	var gold := Kit.standard(Color("ffd54a"), 0.4, 0.5, Color("ffd54a"), 0.22)
	var molten := Kit.unshaded(Color("ff7138"), 1.5)
	var molten_hot := Kit.unshaded(Color("ffd089"), 1.4)
	_dome(root, {"bottom": Color("170e13"), "mid": Color("3a2029"), "top": Color("0d0810"),
		"mid_point": 0.44, "y_min": -8.0, "y_max": 70.0, "haze": Color("6b3a2a"), "haze_amount": 0.3})
	_rear_hall(root, brick, steel, steel, 5, 5.6, 5.2)
	# Three furnace mouths: a dark arch, a glowing throat, and a flue above each.
	for i in 3:
		var cx := -30.0 + float(i) * 30.0
		var mouth := Kit.torus(root, "FurnaceRim_%d" % i, 3.0, 4.4, Vector3(cx, 5.6, REAR_Z + 1.1), iron, 18, 7)
		mouth.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		Kit.cyl(root, "FurnaceThroat_%d" % i, 0.5, 3.1, 3.1, Vector3(cx, 5.6, REAR_Z + 1.25), molten, 18).rotation_degrees = Vector3(90.0, 0.0, 0.0)
		Kit.cyl(root, "Flue_%d" % i, 7.0, 1.6, 1.9, Vector3(cx, 12.6, REAR_Z + 2.2), steel, 10)
		Kit.box(root, "FlueCap_%d" % i, Vector3(3.6, 0.4, 3.6), Vector3(cx, 16.2, REAR_Z + 2.2), iron)
		Kit.box(root, "FlueMouth_%d" % i, Vector3(1.6, 0.5, 1.6), Vector3(cx, 16.5, REAR_Z + 2.2), molten_hot)
	# Molten channels: two long floor runs outside the cage plus cross-run under the hall.
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		Kit.box(root, "Channel_%s" % tag, Vector3(1.5, 0.14, 30.0),
			Vector3(side * 7.6, 0.05, -2.0), molten)
		Kit.box(root, "ChannelBank_%s" % tag, Vector3(2.1, 0.3, 30.0),
			Vector3(side * 7.6, -0.1, -2.0), iron)
	# Both runs sit behind the rear glass plane. A pool 5 m deep on centre reached z = -9.7,
	# in front of the glass, and did stand between the courtside camera and the rear
	# baseline — the envelope rule in this file's header, and exactly what the lane's
	# occlusion test caught before these two numbers moved.
	Kit.box(root, "CrossChannel", Vector3(30.0, 0.14, 1.6), Vector3(0.0, 0.05, -11.6), molten)
	Kit.box(root, "LadlePool", Vector3(18.0, 0.16, 3.0), Vector3(0.0, 0.06, -12.8), molten_hot)
	# Overhead gantries, behind the rear glass only: three spans with hoist blocks.
	var girders: Array = []
	var hoists: Array = []
	for i in 3:
		var z := -15.5 - float(i) * 4.0
		girders.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 10.2 + float(i) * 0.5, z)))
		hoists.append(Transform3D(Basis.IDENTITY, Vector3(-8.0 + float(i) * 8.0, 8.6 + float(i) * 0.5, z)))
	Kit.multi(root, "Girders", Kit.box_mesh(Vector3(34.0, 0.8, 0.9)), iron, girders)
	Kit.multi(root, "Hoists", Kit.box_mesh(Vector3(1.6, 1.6, 1.6)), steel, hoists)
	# Machinery: flywheel banks, piston towers, riveted tanks, chimneys.
	_wheel(root, motion, "FlywheelL", Vector3(-15.0, 3.6, -14.5), 3.0, steel, gold, 5.0, 12)
	_wheel(root, motion, "FlywheelR", Vector3(15.0, 3.6, -14.5), 3.0, steel, gold, -5.0, 12)
	_wheel(root, motion, "FlywheelFar", Vector3(0.0, 4.4, -20.0), 4.2, iron, gold, 3.5, 14)
	var towers: Array = []
	for sx in [-1.0, 1.0]:
		for i in 3:
			towers.append(Transform3D(Basis.IDENTITY, Vector3(sx * (10.5 + float(i) * 3.0), 3.0, -18.0 - float(i) * 2.5)))
	Kit.multi(root, "PistonTowers", Kit.cyl_mesh(6.0, 0.7, 0.9, 8), steel, towers)
	var tanks: Array = []
	for i in 5:
		tanks.append(Transform3D(Basis.IDENTITY, Vector3(12.5 + float(i) * 3.2, 2.6, 2.0)))
	Kit.multi(root, "Tanks", Kit.cyl_mesh(5.2, 1.5, 1.5, 10), iron, tanks)
	var chimneys: Array = []
	for i in 4:
		chimneys.append(Transform3D(Basis.IDENTITY, Vector3(-26.0 + float(i) * 17.0, 11.0, -26.0)))
	Kit.multi(root, "Chimneys", Kit.cyl_mesh(20.0, 1.5, 2.2, 10), brick, chimneys)
	_wings(root, brick, steel, iron, 9.5, 9)
	# Embers rising from the channels: one MultiMesh, drifting outside the cage only.
	var embers: Array = []
	for i in 26:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (7.4 + float(i % 3) * 0.5)
		var z := -13.0 + float(i % 13) * 1.7
		embers.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.6, z)))
	var node := Kit.multi(root, "Embers", Kit.box_mesh(Vector3(0.09, 0.09, 0.09)), molten_hot, embers)
	motion.add_drift(node, 1.1, 0.4, 9.0, 8.0, 20.0)
	# Flue smoke over the furnace hall, one MultiMesh, drifting inside the hall's volume.
	var smoke: Array = []
	for i in 20:
		smoke.append(Transform3D(Basis.IDENTITY, Vector3(-26.0 + float(i % 10) * 5.8, 15.5, REAR_Z - 6.0 - float(i % 4) * 2.4)))
	var smoke_node := Kit.multi(root, "FlueSmoke", Kit.box_mesh(Vector3(2.2, 2.2, 2.2)), steel, smoke)
	motion.add_drift(smoke_node, 0.7, 14.0, 26.0, 10.0, 8.0)


# ---------------------------------------------------------------------------
# tempesta — suspended platform over a storm
# ---------------------------------------------------------------------------

static func _tempesta(root: Node3D, motion: Node3D, ctx: Dictionary) -> void:
	var deck := Kit.standard(Color("2c2a2b"), 0.7, 0.35)
	var steel := Kit.standard(Color("3a3a3d"), 0.6, 0.45)
	var gold := Kit.standard(Color("d89a32"), 0.35, 0.6, Color("d89a32"), 0.2)
	var lamp := Kit.unshaded(Color("ffdca8"), 1.3)
	var hull := Kit.standard(Color("6b4a22"), 0.6, 0.4)
	var brass := Kit.standard(Color("b47b35"), 0.4, 0.5)
	_dome(root, {"bottom": Color("0a1a2e"), "mid": Color("1d4a70"), "top": Color("050c1a"),
		"mid_point": 0.5, "y_min": -60.0, "y_max": 90.0, "haze": Color("3d6a90"), "haze_amount": 0.35})
	# The platform, its edges, trusses and the chains that hold it.
	_deck(root, deck, gold, 22.0, 24.0)
	var chains: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for i in 3:
				chains.append(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(sx * -6.0)),
					Vector3(sx * (15.0 + float(i) * 2.5), -3.0 - float(i) * 2.0, sz * (16.0 + float(i) * 2.0))))
	Kit.multi(root, "HangChains", Kit.cyl_mesh(12.0, 0.14, 0.14, 6), steel, chains)
	_lanterns(root, steel, lamp, 11.5, 13.0, 2.7)
	# Turbine pylons on the platform's corners, outside the cage.
	var pylons: Array = []
	var turbine: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pylons.append(Transform3D(Basis.IDENTITY, Vector3(sx * 15.5, 3.0, sz * 16.0)))
			turbine.append(Transform3D(Basis(Vector3.BACK, deg_to_rad(90.0)), Vector3(sx * 15.5, 6.4, sz * 16.0)))
	Kit.multi(root, "Pylons", Kit.cyl_mesh(6.0, 0.5, 0.7, 8), steel, pylons)
	Kit.multi(root, "TurbineRims", Kit.torus_mesh(1.7, 2.3, 16, 7), brass, turbine)
	_wheel(root, motion, "TurbineL", Vector3(-15.5, 6.4, -16.0), 1.7, brass, gold, 6.0, 6)
	_wheel(root, motion, "TurbineR", Vector3(15.5, 6.4, 16.0), 1.7, brass, gold, -6.0, 6)
	# Airships holding station off the platform, with their own slow propellers.
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var at := Vector3(sx * 27.0, 15.0, -52.0 - float(i) * 12.0)
		var body := Kit.sphere(root, "AirshipHull_%d" % i, 5.2, at, hull, 14, 8)
		body.scale = Vector3(1.0, 0.62, 2.1)
		Kit.box(root, "AirshipGondola_%d" % i, Vector3(3.4, 1.6, 5.6), at + Vector3(0.0, -3.6, 0.0), brass)
		Kit.box(root, "AirshipFin_%d" % i, Vector3(0.3, 4.2, 2.4), at + Vector3(0.0, 1.6, -9.6), brass)
		_wheel(root, motion, "AirshipProp_%d" % i, at + Vector3(0.0, -3.6, 3.4), 1.2, brass, gold, 7.0, 4)
	# The cloud sea below and the storm wall behind: drift-shaded, capped pulse.
	Kit.part(root, "CloudSea", Kit.plane_mesh(Vector2(420.0, 420.0), 1), Vector3(0.0, -26.0, 0.0),
		Kit.drift(Color("16283f"), Color("5f86ad"), {"scale": 0.02, "speed": 0.012,
			"pulse_speed": 0.08, "pulse_amount": 0.12, "alpha": 1.0})).rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	Kit.part(root, "CloudDeck", Kit.plane_mesh(Vector2(460.0, 460.0), 1), Vector3(0.0, -46.0, 0.0),
		Kit.drift(Color("0d1a2c"), Color("2f5170"), {"scale": 0.016, "speed": 0.008,
			"pulse_speed": 0.05, "pulse_amount": 0.1, "alpha": 1.0})).rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	Kit.part(root, "StormWall", Kit.plane_mesh(Vector2(520.0, 200.0), 1), Vector3(0.0, 52.0, -150.0),
		Kit.drift(Color("0b1526"), Color("46688f"), {"scale": 0.013, "speed": 0.006,
			"pulse_speed": 0.06, "pulse_amount": 0.14, "alpha": 1.0, "edge_fade": 0.6}))
	# Distant lightning: thin emissive bolts on the storm wall, pulsing at ~0.07 rad/s with a
	# 25% amplitude ceiling, so they breathe instead of strobing.
	var bolts: Array = []
	for i in 5:
		var x := -70.0 + float(i) * 34.0
		var h := 34.0 + float(i % 3) * 18.0
		bolts.append(Transform3D(Basis(Vector3.BACK, deg_to_rad(6.0 * float(i % 2 * 2 - 1))),
			Vector3(x, 44.0 + h * 0.5, -142.0)))
	Kit.multi(root, "Lightning", Kit.box_mesh(Vector3(0.5, 1.0, 0.5)),
		Kit.drift(Color("3d7fd6"), Color("dff0ff"), {"scale": 0.9, "speed": 0.0,
			"pulse_speed": 0.07, "pulse_amount": 0.25, "alpha": 1.0}), bolts)
	for sx in [-1.0, 1.0]:
		Kit.multi(root, "TurbineBank_%s" % ("L" if sx < 0.0 else "R"),
			Kit.torus_mesh(3.4, 4.4, 18, 7), brass,
			Kit.line_xforms(3, Vector3(sx * 19.0, 9.0, -22.0), Vector3(sx * 19.0, 9.0, -34.0)))
	_wings(root, Kit.standard(Color("241f22"), 0.8, 0.3), gold, brass, 6.0, 7)
	# Storm motes: one MultiMesh drifting outside the cage, never over the court.
	var motes: Array = []
	for i in 24:
		var sx := -1.0 if i % 2 == 0 else 1.0
		motes.append(Transform3D(Basis.IDENTITY, Vector3(sx * (10.0 + float(i % 4) * 1.6), 1.5, -14.0 + float(i % 12) * 2.4)))
	var mote_node := Kit.multi(root, "Motes", Kit.box_mesh(Vector3(0.06, 0.06, 0.06)), lamp, motes)
	motion.add_drift(mote_node, 0.8, 0.5, 14.0, 12.0, 18.0)


# ---------------------------------------------------------------------------
# abissale — underwater observatory
# ---------------------------------------------------------------------------

static func _abissale(root: Node3D, motion: Node3D, ctx: Dictionary) -> void:
	var brass := Kit.standard(Color("c7843f"), 0.4, 0.5)
	var brass_dark := Kit.standard(Color("7a5228"), 0.55, 0.4)
	var iron := Kit.standard(Color("22343b"), 0.8, 0.25)
	var stone := Kit.standard(Color("1d3b42"), 0.95)
	var lamp := Kit.unshaded(Color("ffd9a0"), 1.2)
	var teal := Kit.unshaded(Color("2bd8d0"), 0.7)
	_dome(root, {"bottom": Color("02090f"), "mid": Color("073b46"), "top": Color("01060c"),
		"mid_point": 0.45, "y_min": -30.0, "y_max": 90.0, "haze": Color("0d5f6b"), "haze_amount": 0.4})
	# The observatory's ribbed frame: arches standing parallel to the court at |x| >= 9.5,
	# so the vault reads from every grazing camera and never crosses the court.
	for sx in [-1.0, 1.0]:
		var tag := "L" if sx < 0.0 else "R"
		_ribs_yz(root, "Frame_%s" % tag, brass_dark, sx * 9.6, 8.0, 7, 8.4, 180.0)
		_ribs_yz(root, "FrameOuter_%s" % tag, brass, sx * 13.4, 6.0, 6, 10.4, 180.0)
	# The great rear arch that frames the view, plus the glazed wall below it.
	var arch := Vector3(0.0, 0.0, -14.6)
	Kit.multi(root, "GrandArch", Kit.box_mesh(Vector3(0.5, 0.5, 1.4)),
		brass, Kit.arc_xforms(23, arch, 15.4, 180.0, arch.z, 1.1))
	_ribs_yz(root, "RearRibsL", brass_dark, -9.6, -18.0, 1, 8.4, 180.0)
	_ribs_yz(root, "RearRibsR", brass_dark, 9.6, -18.0, 1, 8.4, 180.0)
	Kit.part(root, "ViewGlass", Kit.plane_mesh(Vector2(64.0, 34.0), 1), Vector3(0.0, 15.0, -15.2),
		Kit.drift(Color("06323c"), Color("1a8f96"), {"scale": 0.016, "speed": 0.008,
			"pulse_speed": 0.06, "pulse_amount": 0.1}))
	# Layered ruins behind the glass, at three depths, plus the drowned tower on axis.
	for layer in 3:
		var z := -34.0 - float(layer) * 16.0
		var shade := Kit.standard(Color("1d3b42").darkened(float(layer) * 0.2), 0.95)
		Kit.multi(root, "RuinColumns_%d" % layer, Kit.cyl_mesh(9.0 + float(layer) * 3.0, 1.3, 1.6, 8),
			shade, Kit.line_xforms(6, Vector3(-40.0, 0.0, z), Vector3(40.0, 0.0, z), 0.0,
				Vector3(1.0, 1.0, 1.0)))
		Kit.multi(root, "RuinLintels_%d" % layer, Kit.box_mesh(Vector3(12.0, 1.0, 2.0)),
			shade, Kit.line_xforms(5, Vector3(-30.0, 8.0, z - 2.0), Vector3(30.0, 8.0, z - 2.0)))
	Kit.cyl(root, "DrownedTower", 26.0, 3.4, 4.2, Vector3(0.0, 13.0, -58.0), stone, 10)
	Kit.cyl(root, "TowerCrown", 2.0, 5.2, 4.4, Vector3(0.0, 26.0, -58.0), brass_dark, 10)
	# Heavy service pipes and gauges along both walkways (outside the cage).
	for sx in [-1.0, 1.0]:
		var tag := "L" if sx < 0.0 else "R"
		Kit.cyl(root, "Manifold_%s" % tag, 22.0, 0.7, 0.7, Vector3(sx * 11.2, 0.7, -4.0), brass, 8).rotation_degrees = Vector3(90.0, 0.0, 0.0)
		Kit.cyl(root, "Riser_%s" % tag, 4.0, 0.4, 0.4, Vector3(sx * 11.2, 2.4, 5.0), brass_dark, 8)
		for i in 3:
			var g := Kit.torus(root, "Gauge_%s_%d" % [tag, i], 0.5, 0.66,
				Vector3(sx * 11.9, 1.6, -10.0 + float(i) * 5.0), iron, 12, 6)
			g.rotation_degrees = Vector3(90.0, 90.0, 0.0)
	_lanterns(root, brass_dark, lamp, 10.4, 12.0, 2.5)
	_wings(root, Kit.standard(Color("152e34"), 0.9), brass_dark, brass, 8.5, 8)
	# Marine life: bubbles rising beside the cage, a slow school off-axis, and jellyfish.
	var bubbles: Array = []
	for i in 28:
		var sx := -1.0 if i % 2 == 0 else 1.0
		bubbles.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.5 + float(i % 4) * 0.28)),
			Vector3(sx * (10.0 + float(i % 5) * 1.4), 1.0 + float(i % 7), -12.0 + float(i % 10) * 2.2)))
	var bub := Kit.multi(root, "Bubbles", Kit.sphere_mesh(0.16, 8, 5), teal, bubbles)
	motion.add_drift(bub, 0.55, 0.3, 12.0, 10.0, 4.0)
	var school: Array = []
	for i in 18:
		school.append(Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)),
			Vector3(-26.0 + float(i % 9) * 6.4, 3.0 + float(i % 4) * 2.2, -26.0 - float(i / 9) * 6.0)))
	var fish := Kit.multi(root, "School", Kit.prism_mesh(Vector3(0.5, 0.28, 1.3)), teal, school)
	motion.add_drift(fish, 0.18, 1.5, 11.0, 9.0, 0.0)
	# Jellyfish ride the same gentle rise, so the observatory is not the only thing moving
	# and the marine life is not frozen in place.
	for i in 4:
		motion.add_spin(root.get_node("Jelly_%d" % i) as Node3D, 1.2 * (1.0 if i % 2 == 0 else -1.0), Vector3.UP)
	for i in 4:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var jet := Vector3(sx * (16.0 + float(i % 2) * 6.0), 10.0 + float(i) * 2.4, -30.0 - float(i) * 5.0)
		var bell := Kit.sphere(root, "Jelly_%d" % i, 1.5, jet, teal, 10, 6)
		bell.scale = Vector3(1.0, 0.7, 1.0)
		Kit.multi(root, "JellyTentacles_%d" % i, Kit.cyl_mesh(5.0, 0.05, 0.09, 5), teal,
			Kit.line_xforms(3, jet + Vector3(-0.6, -2.6, 0.0), jet + Vector3(0.6, -2.6, 0.4)))


# ---------------------------------------------------------------------------
# caldera — platform over volcanic terrain
# ---------------------------------------------------------------------------

static func _caldera(root: Node3D, motion: Node3D, ctx: Dictionary) -> void:
	var rock := Kit.standard(Color("2a1d1c"), 0.96)
	var rock_dark := Kit.standard(Color("161011"), 0.98)
	var iron := Kit.standard(Color("241a19"), 0.7, 0.4)
	var titan_mat := Kit.standard(Color("3b2a26"), 0.8, 0.3)
	var gold := Kit.standard(Color("f4af46"), 0.35, 0.6, Color("f4af46"), 0.24)
	var lava := Kit.unshaded(Color("ff5a1e"), 1.5)
	var lava_hot := Kit.unshaded(Color("ffb057"), 1.5)
	_dome(root, {"bottom": Color("1a0b0a"), "mid": Color("63200f"), "top": Color("120607"),
		"mid_point": 0.46, "y_min": -30.0, "y_max": 90.0, "haze": Color("8a3a1c"), "haze_amount": 0.4})
	_deck(root, rock, iron, 23.0, 25.0)
	# The lava sea far below and the falls pouring off the rear cliffs.
	Kit.part(root, "LavaSea", Kit.plane_mesh(Vector2(340.0, 340.0), 1), Vector3(0.0, -17.0, -10.0),
		Kit.drift(Color("c0330a"), Color("ffab4a"), {"scale": 0.018, "speed": 0.01,
			"pulse_speed": 0.1, "pulse_amount": 0.16})).rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	for i in 3:
		var x := -24.0 + float(i) * 24.0
		Kit.box(root, "LavaFall_%d" % i, Vector3(2.4, 18.0, 0.4), Vector3(x, 9.0, -20.2), lava)
		Kit.box(root, "LavaFallGlow_%d" % i, Vector3(5.0, 4.0, 0.3), Vector3(x, 1.4, -19.8), lava_hot)
	# The rear rock wall and the cliffs beyond the platform: one MultiMesh of prisms each.
	var wall: Array = []
	for i in 11:
		wall.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(i) * 33.0)),
			Vector3(-30.0 + float(i) * 6.0, 12.0 + float(i % 3) * 4.0, -25.0 - float(i % 4) * 4.0)))
	Kit.multi(root, "RearCliff", Kit.prism_mesh(Vector3(8.0, 28.0, 7.0)), rock, wall)
	var sides: Array = []
	for sx in [-1.0, 1.0]:
		for i in 5:
			sides.append(Transform3D(Basis(Vector3.UP, deg_to_rad(float(i) * 47.0)),
				Vector3(sx * (26.0 + float(i) * 5.0), 10.0 + float(i % 2) * 7.0, 12.0 - float(i) * 11.0)))
	Kit.multi(root, "SideCliffs", Kit.prism_mesh(Vector3(11.0, 34.0, 10.0)), rock_dark, sides)
	# The titans: two monumental machine silhouettes on the cliff line, with lit visors.
	# They stand at |x| = 23 with 11 m torsos, so the courtside camera (which sees |x| <= 9
	# at the court and ~23 m at the far cliff) catches them whole rather than clipping them;
	# the default camera's 20.7 m half-band cuts their outer shoulders by design, which is
	# what makes them read as monumental rather than as furniture.
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var x := sx * 21.0
		Kit.box(root, "TitanTorso_%d" % i, Vector3(10.0, 11.0, 7.0), Vector3(x, 9.4, -29.0), titan_mat)
		Kit.box(root, "TitanHead_%d" % i, Vector3(4.4, 4.4, 4.4), Vector3(x, 17.1, -29.0), titan_mat)
		Kit.box(root, "TitanBrow_%d" % i, Vector3(4.0, 0.6, 0.4), Vector3(x, 17.5, -26.7), lava_hot)
		Kit.box(root, "TitanVisor_%d" % i, Vector3(3.0, 0.8, 0.3), Vector3(x, 16.6, -26.8), lava_hot)
		for arm in [-1.0, 1.0]:
			Kit.box(root, "TitanArm_%d_%s" % [i, "L" if arm < 0.0 else "R"],
				Vector3(2.8, 12.0, 3.2), Vector3(x + arm * 6.6, 7.4, -29.0), titan_mat)
			Kit.box(root, "TitanShoulder_%d_%s" % [i, "L" if arm < 0.0 else "R"],
				Vector3(4.4, 3.6, 5.4), Vector3(x + arm * 5.8, 14.0, -29.0), titan_mat)
	# Machinery on the platform: three great gears on the rear axis, chain runs, lanterns.
	_wheel(root, motion, "CalderaGearMain", Vector3(0.0, 11.0, -18.4), 6.4, iron, gold, 2.2, 16)
	_wheel(root, motion, "CalderaGearL", Vector3(-11.5, 8.0, -18.4), 3.6, iron, gold, 3.4, 10)
	_wheel(root, motion, "CalderaGearR", Vector3(11.5, 8.0, -18.4), 3.6, iron, gold, -3.4, 10)
	_lanterns(root, iron, Kit.unshaded(Color("ffcf7a"), 1.25), 11.0, 13.0, 2.6)
	var chains: Array = []
	for sx in [-1.0, 1.0]:
		for i in 4:
			chains.append(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(sx * -5.0)),
				Vector3(sx * (14.0 + float(i) * 3.0), -3.0 - float(i), 14.0 - float(i) * 9.0)))
	Kit.multi(root, "DeckChains", Kit.cyl_mesh(10.0, 0.13, 0.13, 6), iron, chains)
	_wings(root, rock_dark, iron, titan_mat, 8.0, 7)
	# Embers off the lava: one MultiMesh, drifting behind the platform only.
	var embers: Array = []
	for i in 30:
		embers.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.6 + float(i % 3) * 0.4)),
			Vector3(-28.0 + float(i % 10) * 6.2, 0.5, -16.0 - float(i % 6) * 3.0)))
	var node := Kit.multi(root, "Embers", Kit.box_mesh(Vector3(0.1, 0.1, 0.1)), lava_hot, embers)
	motion.add_drift(node, 1.4, 0.4, 16.0, 12.0, 15.0)


# ---------------------------------------------------------------------------
# orrery — celestial observatory
# ---------------------------------------------------------------------------

static func _orrery(root: Node3D, motion: Node3D, ctx: Dictionary) -> void:
	var brass := Kit.standard(Color("c9a04a"), 0.3, 0.6)
	var brass_dark := Kit.standard(Color("7d6029"), 0.45, 0.5)
	var steel := Kit.standard(Color("2b3350"), 0.6, 0.35)
	var stone := Kit.standard(Color("1b2450"), 0.9)
	var lamp := Kit.unshaded(Color("ffe6b0"), 1.25)
	var glass := Kit.unshaded(Color("a98cff"), 0.6)
	# The starfield shell IS the background here: one draw call, no texture, bounded twinkle.
	Kit.part(root, "StarShell", Kit.sphere_mesh(280.0, 32, 16), Vector3.ZERO,
		Kit.stars({"sky_low": Color("03030f"), "sky_high": Color("0a0a2c"),
			"nebula_color": Color("5a3aa8"), "nebula_amount": 0.5, "density": 260.0,
			"twinkle": 0.16, "energy": 1.05}))
	_rear_hall(root, stone, brass_dark, brass, 7, 4.2, 7.4)
	# Ring architecture: vertical brass rings on the axis, sized so the ring band sits
	# outside the court's width and behind the rear glass.
	for i in 3:
		# These are the observatory's RING ARCHITECTURE: 21-25 m across, standing well
		# behind the rear glass at |z| >= 28. The first pass reused a smaller local `radius`
		# and produced a 9.4 m ring whose band crossed the frame's centre — the giant brass
		# column the review caught on this arena.
		var ring_r := 10.5 + float(i) * 1.0
		var ring := Kit.torus(root, "Ring_%d" % i, ring_r - 0.5, ring_r + 0.2,
			Vector3(0.0, 13.0 + float(i) * 1.2, -28.0 - float(i) * 6.0), brass, 40, 8)
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	# The rotunda of columns behind the rear glass, one MultiMesh.
	Kit.multi(root, "Rotunda", Kit.cyl_mesh(12.0, 0.7, 0.9, 10), brass_dark,
		Kit.ring_xforms(16, Vector3(0.0, 6.0, -26.0), 22.0))
	# The armillary landmark on the rear axis: three tilted rings and an orbiting carousel.
	# It stands at |z| = 24, beyond the ring architecture and behind the rear glass, so the
	# courtside camera sees it whole through the gap the hall frame leaves open.
	var at := Vector3(0.0, 10.4, -24.0)
	Kit.sphere(root, "ArmillaryCore", 2.6, at, glass, 14, 8)
	var pivot := Node3D.new()
	pivot.name = "Armillary"
	pivot.position = at
	root.add_child(pivot)
	for i in 3:
		var r := Kit.torus(pivot, "ArmRing_%d" % i, 5.6 + float(i) * 1.7, 5.9 + float(i) * 1.7,
			Vector3.ZERO, brass, 32, 8)
		r.rotation_degrees = Vector3(90.0, float(i) * 30.0, float(i) * 22.0)
	motion.add_spin(pivot, 2.0, Vector3.UP)
	# The orbiting planets: one arm MultiMesh and one planet MultiMesh under a second pivot.
	var carousel := Node3D.new()
	carousel.name = "Carousel"
	carousel.position = at
	root.add_child(carousel)
	var arms: Array = []
	var planets: Array = []
	var colours := ["#50d8ff", "#d17cff", "#e2b653", "#6e8dff", "#ff8fa6"]
	var radii := [10.0, 13.5, 17.0, 20.5, 24.0]
	for i in 5:
		var a := TAU * float(i) / 5.0
		var offset := Vector3(cos(a), 0.0, sin(a))
		# An arm is a unit box along local X, so it is scaled by its own radius and turned
		# so its X axis points outward along `offset` (rotation about +Y by -a).
		arms.append(Transform3D(Basis(Vector3.UP, -a).scaled(Vector3(radii[i], 1.0, 1.0)),
			offset * (radii[i] * 0.5)))
		planets.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.7 + float(i % 3) * 0.35)),
			offset * radii[i]))
	Kit.multi(carousel, "Arms", Kit.box_mesh(Vector3(1.0, 0.16, 0.16)), brass, arms)
	var tints: Array = []
	for c in colours:
		tints.append(Color(String(c)))
	Kit.multi_tinted(carousel, "Planets", Kit.sphere_mesh(0.85, 10, 6), brass, planets, tints)
	motion.add_spin(carousel, 2.6, Vector3.UP)
	# Telescopes on the two walkways, outside the cage.
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		Kit.cyl(root, "TelescopeBase_%d" % i, 1.4, 1.6, 2.0, Vector3(sx * 12.5, 0.7, -4.0), steel, 10)
		var tube := Kit.cyl(root, "TelescopeTube_%d" % i, 9.0, 0.9, 1.1, Vector3(sx * 12.5, 4.2, -4.0), brass, 12)
		tube.rotation_degrees = Vector3(-58.0, sx * 18.0, 0.0)
		Kit.torus(root, "TelescopeRing_%d" % i, 1.0, 1.35, Vector3(sx * 12.5, 6.4, -5.4), brass, 16, 6).rotation_degrees = Vector3(-58.0, 0.0, 0.0)
	_lanterns(root, brass_dark, lamp, 10.6, 12.0, 2.7)
	_wings(root, steel, brass_dark, brass, 10.0, 9)
	_ribs_yz(root, "OrreryRibsL", brass_dark, -9.8, 4.0, 3, 9.0, 150.0)
	_ribs_yz(root, "OrreryRibsR", brass_dark, 9.8, 4.0, 3, 9.0, 150.0)
	# Slow dust: one MultiMesh drifting in the ring light, behind the rear glass.
	var dust: Array = []
	for i in 26:
		dust.append(Transform3D(Basis.IDENTITY, Vector3(-24.0 + float(i % 13) * 4.0, 2.0, -13.0 - float(i % 5) * 3.0)))
	var node := Kit.multi(root, "Dust", Kit.box_mesh(Vector3(0.07, 0.07, 0.07)), lamp, dust)
	motion.add_drift(node, 0.35, 0.5, 14.0, 10.0, 12.0)


# ---------------------------------------------------------------------------
# The environment and light rig
# ---------------------------------------------------------------------------

## One rig per arena: sky, ambient, fog, glow, SSAO, tonemap, grade and the key/fill pair.
## Values are chosen for the arena's own art direction (the reference stills), and the
## compatibility rules `arena_look_test.gd` section 3 enforces still hold: volumetric fog,
## SSIL, SSR and SDFGI stay off, because the game ships on the compatibility renderer.
static func _rig_lights(arena_root: Node3D, id: String) -> void:
	var rig := _rig(id)
	var we := arena_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena_root.get_node_or_null("Sun") as DirectionalLight3D
	var fill := arena_root.get_node_or_null("Fill") as DirectionalLight3D
	if we == null or sun == null or fill == null:
		return
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = rig["sky_top"]
	sky_mat.sky_horizon_color = rig["sky_horizon"]
	sky_mat.ground_horizon_color = rig["ground_horizon"]
	sky_mat.ground_bottom_color = rig["ground_bottom"]
	sky_mat.sky_curve = float(rig["sky_curve"])
	sky_mat.sun_angle_max = 6.0
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = float(rig["ambient_sky"])
	env.ambient_light_color = rig["ambient"]
	env.ambient_light_energy = float(rig["ambient_energy"])
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = rig["fog"]
	env.fog_light_energy = float(rig["fog_energy"])
	var fd: Vector3 = rig["fog_depth"]
	env.fog_depth_begin = fd.x
	env.fog_depth_end = fd.y
	env.fog_depth_curve = fd.z
	env.fog_sun_scatter = float(rig["fog_scatter"])
	env.fog_aerial_perspective = float(rig["fog_aerial"])
	env.fog_sky_affect = float(rig["fog_sky"])
	env.ssao_enabled = true
	env.ssao_radius = float(rig["ssao_radius"])
	env.ssao_intensity = float(rig["ssao_intensity"])
	env.glow_enabled = true
	env.glow_hdr_threshold = float(rig["glow_threshold"])
	env.glow_bloom = float(rig["glow_bloom"])
	env.glow_intensity = float(rig["glow_intensity"])
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(rig["exposure"])
	env.adjustment_enabled = true
	env.adjustment_contrast = float(rig["contrast"])
	env.adjustment_saturation = float(rig["saturation"])
	env.adjustment_brightness = float(rig["brightness"])
	we.environment = env

	sun.rotation_degrees = rig["sun_rotation"]
	sun.light_color = rig["sun_color"]
	sun.light_energy = float(rig["sun_energy"])
	sun.shadow_enabled = true
	sun.shadow_opacity = float(rig["shadow_opacity"])
	sun.directional_shadow_max_distance = float(rig["shadow_distance"])
	fill.rotation_degrees = rig["fill_rotation"]
	fill.light_color = rig["fill_color"]
	fill.light_energy = float(rig["fill_energy"])
	fill.shadow_enabled = false


static func _rig(id: String) -> Dictionary:
	match id:
		"cattedrale":
			return {
				"sky_top": Color("080618"), "sky_horizon": Color("3d2a63"),
				"ground_horizon": Color("342a4a"), "ground_bottom": Color("150f24"), "sky_curve": 0.24,
				"ambient": Color(0.30, 0.26, 0.46), "ambient_sky": 0.68, "ambient_energy": 0.85,
				"fog": Color(0.36, 0.28, 0.56), "fog_energy": 0.62, "fog_depth": Vector3(26.0, 320.0, 0.72),
				"fog_scatter": 0.35, "fog_aerial": 0.45, "fog_sky": 0.75,
				"ssao_radius": 2.0, "ssao_intensity": 1.15,
				"glow_threshold": 0.72, "glow_bloom": 0.14, "glow_intensity": 1.35,
				"exposure": 1.02, "contrast": 1.06, "saturation": 1.16, "brightness": 1.0,
				"sun_rotation": Vector3(-46.0, -34.0, 0.0), "sun_color": Color(1.0, 0.84, 0.62),
				"sun_energy": 1.15, "shadow_opacity": 0.7, "shadow_distance": 120.0,
				"fill_rotation": Vector3(-22.0, 146.0, 0.0), "fill_color": Color(0.46, 0.38, 0.86),
				"fill_energy": 0.55,
			}
		"forgia":
			return {
				"sky_top": Color("0d0710"), "sky_horizon": Color("5a2a22"),
				"ground_horizon": Color("3c1d18"), "ground_bottom": Color("120a0c"), "sky_curve": 0.3,
				"ambient": Color(0.36, 0.24, 0.22), "ambient_sky": 0.6, "ambient_energy": 0.8,
				"fog": Color(0.44, 0.24, 0.18), "fog_energy": 0.7, "fog_depth": Vector3(22.0, 280.0, 0.7),
				"fog_scatter": 0.55, "fog_aerial": 0.5, "fog_sky": 0.7,
				"ssao_radius": 2.2, "ssao_intensity": 1.25,
				"glow_threshold": 0.62, "glow_bloom": 0.2, "glow_intensity": 1.6,
				"exposure": 1.0, "contrast": 1.08, "saturation": 1.14, "brightness": 1.0,
				"sun_rotation": Vector3(-54.0, -28.0, 0.0), "sun_color": Color(1.0, 0.72, 0.46),
				"sun_energy": 1.05, "shadow_opacity": 0.68, "shadow_distance": 130.0,
				"fill_rotation": Vector3(-18.0, 158.0, 0.0), "fill_color": Color(0.52, 0.34, 0.30),
				"fill_energy": 0.6,
			}
		"tempesta":
			return {
				"sky_top": Color("050b1c"), "sky_horizon": Color("2f6d9c"),
				"ground_horizon": Color("2a5578"), "ground_bottom": Color("081222"), "sky_curve": 0.26,
				"ambient": Color(0.30, 0.42, 0.62), "ambient_sky": 0.75, "ambient_energy": 0.95,
				"fog": Color(0.34, 0.52, 0.72), "fog_energy": 0.7, "fog_depth": Vector3(30.0, 360.0, 0.7),
				"fog_scatter": 0.3, "fog_aerial": 0.5, "fog_sky": 0.85,
				"ssao_radius": 1.8, "ssao_intensity": 1.05,
				"glow_threshold": 0.75, "glow_bloom": 0.16, "glow_intensity": 1.45,
				"exposure": 1.05, "contrast": 1.07, "saturation": 1.18, "brightness": 1.0,
				"sun_rotation": Vector3(-50.0, -20.0, 0.0), "sun_color": Color(0.78, 0.88, 1.0),
				"sun_energy": 1.2, "shadow_opacity": 0.62, "shadow_distance": 140.0,
				"fill_rotation": Vector3(-26.0, 132.0, 0.0), "fill_color": Color(0.36, 0.58, 0.9),
				"fill_energy": 0.55,
			}
		"abissale":
			return {
				"sky_top": Color("01060e"), "sky_horizon": Color("075f6b"),
				"ground_horizon": Color("06414c"), "ground_bottom": Color("01070c"), "sky_curve": 0.28,
				"ambient": Color(0.16, 0.42, 0.46), "ambient_sky": 0.7, "ambient_energy": 0.9,
				"fog": Color(0.10, 0.42, 0.48), "fog_energy": 0.8, "fog_depth": Vector3(24.0, 300.0, 0.72),
				"fog_scatter": 0.22, "fog_aerial": 0.55, "fog_sky": 0.9,
				"ssao_radius": 2.0, "ssao_intensity": 1.1,
				"glow_threshold": 0.66, "glow_bloom": 0.18, "glow_intensity": 1.5,
				"exposure": 1.0, "contrast": 1.05, "saturation": 1.2, "brightness": 1.0,
				"sun_rotation": Vector3(-62.0, -12.0, 0.0), "sun_color": Color(0.62, 0.92, 0.9),
				"sun_energy": 1.05, "shadow_opacity": 0.6, "shadow_distance": 130.0,
				"fill_rotation": Vector3(-20.0, 168.0, 0.0), "fill_color": Color(0.16, 0.5, 0.62),
				"fill_energy": 0.62,
			}
		"caldera":
			return {
				"sky_top": Color("100607"), "sky_horizon": Color("7a2a12"),
				"ground_horizon": Color("4a1c0e"), "ground_bottom": Color("140708"), "sky_curve": 0.3,
				"ambient": Color(0.42, 0.22, 0.16), "ambient_sky": 0.6, "ambient_energy": 0.85,
				"fog": Color(0.52, 0.22, 0.12), "fog_energy": 0.75, "fog_depth": Vector3(24.0, 300.0, 0.7),
				"fog_scatter": 0.6, "fog_aerial": 0.5, "fog_sky": 0.72,
				"ssao_radius": 2.2, "ssao_intensity": 1.2,
				"glow_threshold": 0.58, "glow_bloom": 0.22, "glow_intensity": 1.7,
				"exposure": 1.0, "contrast": 1.09, "saturation": 1.15, "brightness": 1.0,
				"sun_rotation": Vector3(-40.0, -62.0, 0.0), "sun_color": Color(1.0, 0.62, 0.36),
				"sun_energy": 1.1, "shadow_opacity": 0.66, "shadow_distance": 140.0,
				"fill_rotation": Vector3(-16.0, 118.0, 0.0), "fill_color": Color(0.7, 0.3, 0.18),
				"fill_energy": 0.62,
			}
		_:
			return {
				"sky_top": Color("04041a"), "sky_horizon": Color("2c2464"),
				"ground_horizon": Color("201a4c"), "ground_bottom": Color("06061a"), "sky_curve": 0.24,
				"ambient": Color(0.26, 0.24, 0.5), "ambient_sky": 0.7, "ambient_energy": 0.9,
				"fog": Color(0.3, 0.26, 0.62), "fog_energy": 0.6, "fog_depth": Vector3(28.0, 340.0, 0.72),
				"fog_scatter": 0.3, "fog_aerial": 0.45, "fog_sky": 0.8,
				"ssao_radius": 1.9, "ssao_intensity": 1.05,
				"glow_threshold": 0.68, "glow_bloom": 0.16, "glow_intensity": 1.45,
				"exposure": 1.02, "contrast": 1.06, "saturation": 1.18, "brightness": 1.0,
				"sun_rotation": Vector3(-48.0, -40.0, 0.0), "sun_color": Color(1.0, 0.9, 0.7),
				"sun_energy": 1.1, "shadow_opacity": 0.66, "shadow_distance": 130.0,
				"fill_rotation": Vector3(-24.0, 150.0, 0.0), "fill_color": Color(0.42, 0.42, 0.9),
				"fill_energy": 0.55,
			}
