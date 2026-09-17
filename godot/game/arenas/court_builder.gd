## court_builder.gd — the shared visual language of every arena: the world
## environment and lights, the court surface with its lines, the net, and the
## glass cage. Plus the small primitive helpers the scenery modules build with.
##
## This is `court.gd::build_world` / `court.gd::build_court` moved into the
## arena library (slice S6), with two changes, both in the glass:
##
##  1. THE REAR WALL NOW READS AS GLASS. It used to be one wide pane at a flat
##     alpha with five posts: in the rendered frame the rear of the court looked
##     like an open dark void, because (a) a single flat-alpha sheet gives the
##     eye no pane edges, and (b) there was nothing behind it to see through it —
##     the ground plane covered the entire band above the far line, so the only
##     thing "behind the glass" was dark ground. It is now six panes with the
##     reference's own divisions (js/render.js:800-813 draws exactly six, with
##     `rgba(29,76,111,0.86)` dividers, a `rgba(225,248,255,0.46)` rail line and
##     a `#244d70` bottom rail), a vertical reflection gradient so the panes catch
##     light, and — in `arena_scenery.gd` — scenery standing behind it to be seen
##     THROUGH it.
##  2. THE PANE ALPHA IS WIRED TO `wallBounce`. The reference's own comment for
##     `locomotive` is "Vetro più vivo" (js/data.js:573); a more reactive glass
##     reads brighter/clearer here. PRESENTATION ONLY: no physics value is read
##     or written, `wallBounce` only ever enters a colour. The slice test asserts
##     the wiring is monotone across the nine arenas.
##
## Everything else — the court bed, the lines, the net lattice and posts, the
## surrounding ground, the camera presets — is byte-for-byte the previous look.
extends RefCounted

const Court := preload("res://game/court.gd")

## `GLASS_H` re-exported for the builder's own use.
const GLASS_H := Court.GLASS_H
## The reference's rear-wall tint, `rgba(184,235,250, ...)` (js/render.js:796) and
## its side-wall tint, `rgba(173,235,255, 0.35)` (js/render.js:787-788).
const REAR_TINT := Color(0.722, 0.922, 0.980)
const SIDE_TINT := Color(0.678, 0.922, 1.000)
const SIDE_ALPHA := 0.34
## The rear pane's alpha at the coldest and hottest glass in the table
## (`wallBounce` 0.83 `forgia` .. 0.95 `tempesta`).
const REAR_ALPHA_MIN := 0.30
const REAR_ALPHA_MAX := 0.46
## The reference's frame colours: dividers `rgba(29,76,111,0.86)`, rail
## `#244d70`, rail highlight `rgba(225,248,255,0.46)`, and the ground rail the
## back wall is drawn on top of.
const FRAME_DIVIDER := Color(0.114, 0.298, 0.435)
const FRAME_RAIL := Color(0.141, 0.302, 0.439)
const FRAME_HILITE := Color(0.882, 0.973, 1.000)
const FRAME_POST := Color(0.75, 0.78, 0.82)
## Six panes, five dividers: the reference's own division of the back wall.
const REAR_PANES := 6


## The rear pane's alpha for an arena's `wallBounce`. Presentation only.
static func rear_alpha(wall_bounce: float) -> float:
	var t := clampf((wall_bounce - 0.83) / (0.95 - 0.83), 0.0, 1.0)
	return lerpf(REAR_ALPHA_MIN, REAR_ALPHA_MAX, t)


static func glass_params(wall_bounce: float) -> Dictionary:
	return {"rear_alpha": rear_alpha(wall_bounce), "side_alpha": SIDE_ALPHA}


# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

## A shaded box, the old `court.gd::box` (kept by name and signature).
static func box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	return Court.box(parent, name, size, pos, color, alpha)


## An unshaded mesh: it renders as the colour it is given, which is what scenery
## against a dark sky needs (the same decision `glass_wall` already records).
static func unshaded(parent: Node3D, name: String, mesh: Mesh, pos: Vector3, color: Color, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	parent.add_child(mi)
	return mi


static func box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


static func cyl_mesh(radius: float, height: float, sides := 12) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	return cm


static func cone_mesh(radius: float, height: float, sides := 10) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	return cm


static func ball_mesh(radius: float, segments := 12) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = segments / 2
	return sm


static func ring_mesh(inner: float, outer: float, segments := 20) -> TorusMesh:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = segments
	tm.ring_segments = 8
	return tm


static func quad_mesh(w: float, h: float) -> QuadMesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	return qm


## A vertical gradient texture (top -> bottom) from hex stops, for a painted
## backdrop or a pane's reflected light. No asset file is read: the reference's
## own `addColorStop` values are turned into a Godot `Gradient`.
static func gradient_texture(stops: Array, height_px := 256) -> GradientTexture2D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop in stops:
		offsets.append(float(stop[0]))
		var value: Variant = stop[1]
		colors.append(value if typeof(value) == TYPE_COLOR else Color(String(value)))
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 8
	tex.height = height_px
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


## An unshaded quad carrying a texture (the arena backdrop).
static func textured_quad(parent: Node3D, name: String, size: Vector2, pos: Vector3, texture: Texture2D, tint := Color(1, 1, 1, 1)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = quad_mesh(size.x, size.y)
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = texture
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if tint.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# The world
# ---------------------------------------------------------------------------

## Environment + lights: the arena-spike numbers, with the arena's own palette
## colouring the ground.
static func build_world(parent: Node3D, arena: Dictionary) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.10, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.46, 0.55)
	env.ambient_light_energy = 0.75
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-62.0, -38.0, 0.0)
	sun.shadow_enabled = true
	parent.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-28.0, 148.0, 0.0)
	fill.shadow_enabled = false
	parent.add_child(fill)


# ---------------------------------------------------------------------------
# The court
# ---------------------------------------------------------------------------

## Court, lines, net and glass cage. Geometry from `COURT` +
## `SERVICE_LINE_OFFSET`, exactly as `godot/prototypes/arena_spike/` built it.
static func build_court(parent: Node3D, arena: Dictionary, wall_bounce := 0.89) -> void:
	var floor_color := Court.palette_color(arena, "floor", Color(0.10, 0.22, 0.18))
	var accent := Court.palette_color(arena, "accent", Color(0.0, 0.898, 1.0))
	var gear := Court.palette_color(arena, "gear", Color(0.784, 0.565, 0.0))

	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Surround"
	var pm := PlaneMesh.new()
	pm.size = Vector2(80.0, 80.0)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0.0, -0.02, 0.0)
	floor_mi.material_override = Court.material(floor_color.darkened(0.35))
	parent.add_child(floor_mi)

	var bed := MeshInstance3D.new()
	bed.name = "Court"
	var bed_mesh := PlaneMesh.new()
	bed_mesh.size = Vector2(Court.court_len(), Court.court_depth())
	bed.mesh = bed_mesh
	bed.material_override = Court.material(Color(0.16, 0.30, 0.58))
	parent.add_child(bed)

	var lw := 0.05
	var hl := Court.half_len()
	var hd := Court.half_depth()
	var line_col := Color(0.95, 0.96, 0.98)
	box(parent, "LineFar", Vector3(Court.court_len(), 0.012, lw), Vector3(0.0, 0.006, -hd), line_col)
	box(parent, "LineNear", Vector3(Court.court_len(), 0.012, lw), Vector3(0.0, 0.006, hd), line_col)
	box(parent, "LineLeft", Vector3(lw, 0.012, Court.court_depth()), Vector3(-hl, 0.006, 0.0), line_col)
	box(parent, "LineRight", Vector3(lw, 0.012, Court.court_depth()), Vector3(hl, 0.006, 0.0), line_col)
	box(parent, "CenterLine", Vector3(lw, 0.012, 2.0 * (Court.service_z() + 0.2)), Vector3(0.0, 0.006, 0.0), line_col)
	box(parent, "ServiceFar", Vector3(Court.court_len(), 0.012, lw), Vector3(0.0, 0.006, -Court.service_z()), line_col)
	box(parent, "ServiceNear", Vector3(Court.court_len(), 0.012, lw), Vector3(0.0, 0.006, Court.service_z()), line_col)

	# Net: `COURT.netHeight` (38 px -> 0.950 m) centred on `COURT.netY` (z = 0),
	# drawn as a mesh between two padded posts (js/render.js:864-866).
	var net_root := Node3D.new()
	net_root.name = "Net"
	parent.add_child(net_root)
	var net_top := Court.net_h()
	var wire := 0.014
	var strand := Color(0.17, 0.20, 0.26)
	var columns := 49
	var rows := 9
	for i in columns + 1:
		var wire_x := -hl + (Court.court_len() / float(columns)) * float(i)
		box(net_root, "NetWire", Vector3(wire, net_top, wire), Vector3(wire_x, net_top * 0.5, 0.0), strand)
	for r in rows:
		var wire_y := net_top * (float(r + 1) / float(rows + 1))
		box(net_root, "NetCord", Vector3(Court.court_len(), wire, wire), Vector3(0.0, wire_y, 0.0), strand)
	box(net_root, "NetTape", Vector3(Court.court_len(), 0.07, 0.05), Vector3(0.0, net_top - 0.035, 0.0), line_col)
	box(parent, "NetPostL", Vector3(0.10, net_top + 0.05, 0.10), Vector3(-hl, (net_top + 0.05) * 0.5, 0.0), FRAME_POST)
	box(parent, "NetPostR", Vector3(0.10, net_top + 0.05, 0.10), Vector3(hl, (net_top + 0.05) * 0.5, 0.0), FRAME_POST)

	build_glass_cage(parent, Court.palette_color(arena, "accent", Color(0.0, 0.898, 1.0)), wall_bounce)

	# The two accent posts outside the cage: the reference's own "accent" use of
	# the palette (`js/render.js:1613`). They stand well outside the frame's
	# side wedges (the scenery band is `arena_scenery.gd`'s business).
	box(parent, "AccentPostL", Vector3(0.18, 3.4, 0.18), Vector3(-hl - 2.0, 1.7, 3.4), accent.darkened(0.2))
	box(parent, "AccentPostR", Vector3(0.18, 3.4, 0.18), Vector3(hl + 2.0, 1.7, 3.4), accent.darkened(0.2))
	var gear_ring := MeshInstance3D.new()
	gear_ring.name = "GearRing"
	gear_ring.mesh = ring_mesh(1.5, 1.7)
	# Moved from the left edge of the frame, where half of it was cut off by the
	# screen border (see the evidence file): the two rings now hang in the
	# scenery band behind the rear glass, one per side, inside the frame.
	gear_ring.position = Vector3(-4.6, 1.35, -hd - 1.45)
	gear_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	gear_ring.material_override = Court.material(gear)
	parent.add_child(gear_ring)


# ---------------------------------------------------------------------------
# The glass cage
# ---------------------------------------------------------------------------

static func build_glass_cage(parent: Node3D, tint: Color, wall_bounce: float) -> void:
	var hl := Court.half_len()
	var hd := Court.half_depth()
	var params := glass_params(wall_bounce)
	var rear := REAR_TINT.lerp(tint.lightened(0.6), 0.25)
	var side := SIDE_TINT.lerp(tint.lightened(0.5), 0.25)

	build_rear_wall(parent, rear, float(params["rear_alpha"]), hl, hd)
	glass_wall(parent, "GlassLeft", Vector3(0.04, GLASS_H, Court.court_depth()), Vector3(-hl, GLASS_H * 0.5, 0.0), side, float(params["side_alpha"]), false)
	glass_wall(parent, "GlassRight", Vector3(0.04, GLASS_H, Court.court_depth()), Vector3(hl, GLASS_H * 0.5, 0.0), side, float(params["side_alpha"]), false)
	glass_wall(parent, "GlassNear", Vector3(Court.court_len(), GLASS_H, 0.04), Vector3(0.0, GLASS_H * 0.5, hd), side, 0.055, true)
	# The cage's four corner posts, so the enclosure closes.
	var corner := FRAME_POST.darkened(0.25)
	box(parent, "GlassPostFL", Vector3(0.07, GLASS_H, 0.07), Vector3(-hl, GLASS_H * 0.5, -hd), corner)
	box(parent, "GlassPostFR", Vector3(0.07, GLASS_H, 0.07), Vector3(hl, GLASS_H * 0.5, -hd), corner)
	var near_left := box(parent, "GlassPostNL", Vector3(0.07, GLASS_H, 0.07), Vector3(-hl, GLASS_H * 0.5, hd), corner, 0.18)
	var near_right := box(parent, "GlassPostNR", Vector3(0.07, GLASS_H, 0.07), Vector3(hl, GLASS_H * 0.5, hd), corner, 0.18)
	near_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	near_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The rear wall: six glass panes with the reference's frame between them, a
## bottom band, a top rail and a highlight line on that rail. `name` "GlassFar"
## is pane 1 so the existing contract (`GlassFar` + `GlassFarRail`) still holds.
##
## A pane is UNSHADED with a vertical RGB gradient in its albedo — brighter at the
## top (the sky it reflects), lifting again at the foot (the ground it reflects).
## That gradient is what makes a flat sheet read as glass: a lit, low-alpha pane
## picks up almost none of this scene's light and lands within a couple of RGB
## steps of the dark ground behind it, which is why the rear wall was reported
## missing in the first place.
static func build_rear_wall(parent: Node3D, tint: Color, alpha: float, hl: float, hd: float) -> void:
	var z := -hd
	var total := Court.court_len()
	var divider := 0.06
	var pane_w := (total - divider * float(REAR_PANES - 1)) / float(REAR_PANES)
	var grad_stops := [
		[0.00, "#eaf7ff"],
		[0.30, "#b7dcee"],
		[0.72, "#8fb9d0"],
		[1.00, "#cfe6f2"],
	]
	var tex := gradient_texture(grad_stops, 128)
	for i in REAR_PANES:
		var pane_name := "GlassFar" if i == 0 else "GlassFar%d" % (i + 1)
		var pane_x := -hl + pane_w * 0.5 + float(i) * (pane_w + divider)
		var pane := textured_quad(parent, pane_name, Vector2(pane_w, GLASS_H), Vector3(pane_x, GLASS_H * 0.5, z - 0.02), tex, Color(tint.r, tint.g, tint.b, alpha))
		var mat := pane.material_override as StandardMaterial3D
		if mat != null:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in REAR_PANES - 1:
		var post_x := -hl + pane_w + divider * 0.5 + float(i) * (pane_w + divider)
		box(parent, "GlassFarDivider%d" % (i + 1), Vector3(divider, GLASS_H, 0.07), Vector3(post_x, GLASS_H * 0.5, z), FRAME_DIVIDER)
	# The foot of the wall: the reference draws a heavier `#244d70` rail over the
	# bottom of the panes (js/render.js:812-813).
	box(parent, "GlassFarBottom", Vector3(total, 0.16, 0.08), Vector3(0.0, 0.08, z + 0.01), FRAME_RAIL)
	# The top rail and the light line along it.
	box(parent, "GlassFarRail", Vector3(total + 0.1, 0.09, 0.09), Vector3(0.0, GLASS_H, z), FRAME_RAIL)
	box(parent, "GlassFarRailHilite", Vector3(total + 0.1, 0.025, 0.10), Vector3(0.0, GLASS_H + 0.02, z), FRAME_HILITE)


## One side wall: the pane, a top rail and vertical posts. `along_x` says whether
## the wall runs across the court (the near wall) or along it (the two sides).
static func glass_wall(parent: Node3D, name: String, size: Vector3, pos: Vector3, tint: Color, alpha: float, along_x: bool) -> void:
	var pane := box(parent, name, size, pos, tint, alpha)
	var near_camera := name == "GlassNear"
	if near_camera:
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := pane.material_override as StandardMaterial3D
	if mat != null:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var span := size.x if along_x else size.z
	var rail_size := Vector3(span, 0.06, 0.06) if along_x else Vector3(0.06, 0.06, span)
	var rail := box(parent, name + "Rail", rail_size, Vector3(pos.x, GLASS_H, pos.z), FRAME_RAIL, 0.12 if near_camera else 1.0)
	if near_camera:
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var posts := 5
	for i in posts:
		var t := -0.5 + (float(i) / float(posts - 1))
		var post_pos := Vector3(pos.x + span * t, GLASS_H * 0.5, pos.z) if along_x \
			else Vector3(pos.x, GLASS_H * 0.5, pos.z + span * t)
		var post := box(parent, name + "Post", Vector3(0.06, GLASS_H, 0.06), post_pos, FRAME_DIVIDER, 0.12 if near_camera else 1.0)
		if near_camera:
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
