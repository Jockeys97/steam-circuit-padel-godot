## fantasy_kit.gd — the shared toolbox the six fantasy environments are built with.
##
## WHY A KIT RATHER THAN FREEHAND CODE PER ARENA. Six substantial environments built
## from primitives only stay inside the contract's budget (<= 100k extra triangles and
## <= 200 extra draw instances per arena, measured separately from the existing stands)
## if they share three disciplines, and this file is where those live:
##
##   1. SHARED MATERIALS. One `StandardMaterial3D` per colour per arena, referenced by
##      every mesh that uses it. Godot still issues one draw per mesh instance, but the
##      material state changes and the shader compile count stay flat.
##   2. MULTIMESH FOR REPETITION. A colonnade of forty ribs, a field of ninety rocks or
##      a carousel of rivets is ONE draw call through `multi()` instead of forty. Every
##      repeated element in `fantasy_environment.gd` goes through it; the per-arena
##      draw count is what makes the difference between ~15 and ~200.
##   3. SHADOW OFF ON DECORATION. `cast_shadow = OFF` on every decorative mesh, the same
##      setting `egeo_environment.gd` and `community_props.gd` already use: the arena's
##      shadows stay the shared court's two-directional-light budget, and adding a hall
##      never adds a shadow-casting volume.
##
## `budget()` is the measurement the lane's own test asserts against, and it reports the
## two numbers the contract names: triangles (index count / 3, or vertices / 3 when the
## mesh is unindexed) and draw instances (mesh instances + one per MultiMesh surface).
##
## EVERYTHING HERE IS PRESENTATION. No collision shapes, no lights, no animation state:
## motion lives in `fantasy_motion.gd`, which only rotates pivots it is handed.
extends RefCounted

const GRADIENT_SHADER := preload("res://game/arenas/fantasy/fantasy_gradient.gdshader")
const DRIFT_SHADER := preload("res://game/arenas/fantasy/fantasy_drift.gdshader")
const STARS_SHADER := preload("res://game/arenas/fantasy/fantasy_stars.gdshader")


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## A lit surface material. `emission` > 0 adds emissive paint: the established local
## idiom for glow without a real light (`aurora_details.gd`), which matters because the
## contract forbids extra shadow-casting point lights and the arenas' environment glow
## is pinned off by `arena_look_test.gd` for these six ids.
static func standard(color: Color, roughness := 0.85, metallic := 0.0,
		emission := Color(0, 0, 0), emission_energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


## An unshaded material. Used for anything that has to read as its own colour whatever
## the key/fill rig does — window glass, lava surfaces, painted signal faces.
static func unshaded(color: Color, emission_energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	return mat


## The continuous background shell: a world-height gradient on a dome or wall.
static func shell(stops: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GRADIENT_SHADER
	_shader_set(mat, "bottom_color", stops.get("bottom", Color(0.05, 0.06, 0.10)))
	_shader_set(mat, "mid_color", stops.get("mid", Color(0.16, 0.20, 0.30)))
	_shader_set(mat, "top_color", stops.get("top", Color(0.05, 0.08, 0.16)))
	mat.set_shader_parameter("mid_point", float(stops.get("mid_point", 0.5)))
	mat.set_shader_parameter("y_min", float(stops.get("y_min", -20.0)))
	mat.set_shader_parameter("y_max", float(stops.get("y_max", 60.0)))
	_shader_set(mat, "haze_color", stops.get("haze", Color(0.5, 0.5, 0.6)))
	mat.set_shader_parameter("haze_begin", float(stops.get("haze_begin", 40.0)))
	mat.set_shader_parameter("haze_end", float(stops.get("haze_end", 260.0)))
	mat.set_shader_parameter("haze_amount", float(stops.get("haze_amount", 0.0)))
	mat.set_shader_parameter("energy", float(stops.get("energy", 1.0)))
	return mat


## A slow drifting layer. `pulse_speed` and `pulse_amount` are the anti-strobe budget:
## every arena keeps the product well under one visible cycle per second.
static func drift(a: Color, b: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DRIFT_SHADER
	_shader_set(mat, "color_a", a)
	_shader_set(mat, "color_b", b)
	mat.set_shader_parameter("scale", float(opts.get("scale", 0.05)))
	mat.set_shader_parameter("speed", float(opts.get("speed", 0.02)))
	mat.set_shader_parameter("band_strength", float(opts.get("band_strength", 1.0)))
	mat.set_shader_parameter("pulse_speed", float(opts.get("pulse_speed", 0.15)))
	mat.set_shader_parameter("pulse_amount", float(opts.get("pulse_amount", 0.10)))
	mat.set_shader_parameter("alpha", float(opts.get("alpha", 1.0)))
	mat.set_shader_parameter("energy", float(opts.get("energy", 1.0)))
	mat.set_shader_parameter("edge_fade", float(opts.get("edge_fade", 0.0)))
	# Translucent layers draw after the opaque hall so a cloud bank never pokes through
	# a wall it should be behind.
	if float(opts.get("alpha", 1.0)) < 1.0:
		mat.render_priority = 1
	return mat


## The star/nebula shell.
static func stars(opts: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STARS_SHADER
	_shader_set(mat, "sky_low", opts.get("sky_low", Color(0.02, 0.02, 0.08)))
	_shader_set(mat, "sky_high", opts.get("sky_high", Color(0.06, 0.05, 0.20)))
	_shader_set(mat, "star_color", opts.get("star_color", Color(0.92, 0.95, 1.0)))
	_shader_set(mat, "warm_star_color", opts.get("warm_star_color", Color(1.0, 0.86, 0.62)))
	_shader_set(mat, "nebula_color", opts.get("nebula_color", Color(0.42, 0.24, 0.72)))
	mat.set_shader_parameter("density", float(opts.get("density", 220.0)))
	mat.set_shader_parameter("star_size", float(opts.get("star_size", 0.004)))
	mat.set_shader_parameter("twinkle", float(opts.get("twinkle", 0.18)))
	mat.set_shader_parameter("nebula_amount", float(opts.get("nebula_amount", 0.45)))
	mat.set_shader_parameter("energy", float(opts.get("energy", 1.0)))
	return mat


static func _shader_set(mat: ShaderMaterial, name: String, value: Variant) -> void:
	# `source_color` vec3 uniforms take a Color: Godot converts it on the way in, and
	# passing the Color keeps the shader's own hint the single source of truth.
	mat.set_shader_parameter(name, value)


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------

static func box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cyl_mesh(height: float, top_r: float, bottom_r: float, segments := 10) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func torus_mesh(inner: float, outer: float, ring_segments := 12, rings := 6) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.ring_segments = ring_segments
	mesh.rings = rings
	return mesh


static func sphere_mesh(radius: float, radial := 10, ring := 6) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = ring
	return mesh


static func prism_mesh(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh


static func plane_mesh(size: Vector2, subdiv := 1) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = subdiv
	mesh.subdivide_depth = subdiv
	return mesh


# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------

## One decorative mesh instance. Shadows are always off (see the file header), so no
## caller has to remember the arena's shadow budget.
static func part(root: Node3D, title: String, mesh: Mesh, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = title
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func box(root: Node3D, title: String, size: Vector3, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	return part(root, title, box_mesh(size), pos, mat)


static func cyl(root: Node3D, title: String, height: float, top_r: float, bottom_r: float,
		pos: Vector3, mat: Material, segments := 10) -> MeshInstance3D:
	return part(root, title, cyl_mesh(height, top_r, bottom_r, segments), pos, mat)


static func sphere(root: Node3D, title: String, radius: float, pos: Vector3,
		mat: Material, radial := 10, ring := 6) -> MeshInstance3D:
	return part(root, title, sphere_mesh(radius, radial, ring), pos, mat)


static func torus(root: Node3D, title: String, inner: float, outer: float, pos: Vector3,
		mat: Material, ring_segments := 12, rings := 6) -> MeshInstance3D:
	return part(root, title, torus_mesh(inner, outer, ring_segments, rings), pos, mat)


## `count` copies of one mesh in ONE draw call. This is the workhorse for ribs, rocks,
## rivets, lanterns, pipes and stars-of-the-hall: see the file header.
static func multi(root: Node3D, title: String, mesh: Mesh, mat: Material,
		xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	return _multi_node(root, title, mm, mat)


## The same, with a per-instance colour: the orrery's five planets are one MultiMesh whose
## instances differ only in tint. `use_colors` has to be set BEFORE `instance_count`, which
## is why this is a separate entry point rather than a flag on `multi` — Godot refuses the
## toggle once instances exist, and setting an instance colour on a colourless MultiMesh is
## silently dropped.
static func multi_tinted(root: Node3D, title: String, mesh: Mesh, mat: Material,
		xforms: Array, colours: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	# `use_colors` may only be toggled while the MultiMesh has no instances, and an
	# instance colour written to a colourless MultiMesh is silently dropped — so the flag
	# is set first, the instances are created, and only then are the tints written.
	mm.use_colors = true
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	for i in mini(colours.size(), xforms.size()):
		mm.set_instance_color(i, colours[i])
	return _multi_node(root, title, mm, mat)


static func _multi_node(root: Node3D, title: String, mm: MultiMesh,
		mat: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	return node


# ---------------------------------------------------------------------------
# Instance-transform recipes
# ---------------------------------------------------------------------------

## `count` transforms evenly spaced around a circle, each facing the centre. Used for
## rotundas, ring walls, colonnades that wrap a hall and planet carousels.
static func ring_xforms(count: int, center: Vector3, radius: float, extra_yaw := 0.0,
		scale := Vector3.ONE) -> Array:
	var out: Array = []
	for i in count:
		var a := TAU * float(i) / float(maxi(count, 1))
		var basis := Basis(Vector3.UP, a + extra_yaw).scaled(scale)
		out.append(Transform3D(basis, center + Vector3(sin(a) * radius, 0.0, -cos(a) * radius)))
	return out


## `count` transforms along a straight line from `from` to `to`, `yaw` facing +z.
static func line_xforms(count: int, from: Vector3, to: Vector3, yaw := 0.0,
		scale := Vector3.ONE) -> Array:
	var out: Array = []
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(scale), from.lerp(to, t)))
	return out


## `count` transforms along a vertical arc of `radius`, spanning `span_deg`, with the arc
## centred on `center` in the XY plane and extruded at `z`. This is how the ribbed vaults
## and the under-deck trusses are made without a bespoke mesh: each rib is one segment of
## a MultiMesh, so a whole vault costs one draw call.
static func arc_xforms(count: int, center: Vector3, radius: float, span_deg: float,
		z: float, segment_length: float, yaw := 0.0) -> Array:
	var out: Array = []
	var span := deg_to_rad(span_deg)
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		var a := -span * 0.5 + span * t
		var pos := Vector3(center.x + sin(a) * radius, center.y + cos(a) * radius, z)
		# The segment's LONG axis (local +Z) has to lie along the arc's tangent and its
		# local +Y along the radius, or a "rib" renders as a radial stub instead of a
		# piece of vault. Columns: X = -Z world, Y = radial, Z = tangent.
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3(0.0, 0.0, -1.0),
			Vector3(sin(a), cos(a), 0.0), Vector3(cos(a), -sin(a), 0.0))
		out.append(Transform3D(basis.scaled(Vector3(1.0, 1.0, segment_length)), pos))
	return out


## The same recipe in the YZ plane: an arch standing parallel to the court's long axis,
## at a fixed x. This is the observatory rib (`abissale`) and the foundry gantry rib,
## and it is the reason those arenas can have a vaulted silhouette at |x| >= SIDE_X
## without any rib passing over the playable footprint.
static func arc_xforms_yz(count: int, center: Vector3, radius: float, span_deg: float,
		segment_length: float) -> Array:
	var out: Array = []
	var span := deg_to_rad(span_deg)
	for i in count:
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		var a := -span * 0.5 + span * t
		var pos := Vector3(center.x, center.y + cos(a) * radius, center.z + sin(a) * radius)
		# Same convention in the YZ plane: X = extrusion (+X world), Y = radial,
		# Z = tangent, so the segment follows the arch instead of pointing across it.
		var basis := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, cos(a), sin(a)),
			Vector3(0.0, -sin(a), cos(a))).scaled(Vector3(1.0, 1.0, segment_length))
		out.append(Transform3D(basis, pos))
	return out


## `count` transforms evenly spaced on a circle in the XY plane, each rotated to point
## radially outwards: gear teeth, rose-window spokes, armillary arms.
static func wheel_xforms(count: int, center: Vector3, radius: float) -> Array:
	var out: Array = []
	for i in count:
		var a := TAU * float(i) / float(maxi(count, 1))
		out.append(Transform3D(Basis(Vector3.BACK, a), center + Vector3(cos(a), sin(a), 0.0) * radius))
	return out


# ---------------------------------------------------------------------------
# The budget measurement the lane's own test asserts against
# ---------------------------------------------------------------------------

## RENDERED triangles and draw instances under `root`, which is what the contract bounds
## (<= 100k extra triangles, <= 200 extra draw instances per arena).
##
## THE TWO NUMBERS THAT ARE EASY TO CONFUSE, and why this returns both:
##
##   `triangles`  RENDERED total — a MultiMesh instance's mesh triangles MULTIPLIED by its
##                instance count. This is what the GPU actually draws, and it is the number
##                the contract's ceiling is about.
##   `unique_triangles`
##                the underlying mesh geometry once, as authored, with each MultiMesh
##                counted a single time. This is the cheap-to-read number and it is roughly
##                two orders of magnitude smaller, so reporting only this one would make a
##                337-instance arena look like a 2k-triangle arena.
##   `draws`      draw instances. Ordinary meshes: one per mesh SURFACE. A MultiMesh: one
##                per surface for the whole instance set (that is the entire point of using
##                it), NOT one per instance.
##   `ordinary_draws` / `multimesh_draws`
##                the same total split by kind, so the report shows where the draws went.
##
## HOW THE TREE IS WALKED. `MultiMeshInstance3D` and `MeshInstance3D` are SIBLINGS under
## `GeometryInstance3D` in Godot 4, not a parent/child pair: a `find_children("*",
## "MeshInstance3D")` pass matches only the latter, so a MultiMesh-heavy arena reports zero
## repeated geometry and a suspiciously small draw count. The walk below therefore queries
## `GeometryInstance3D` once and classifies each node explicitly, and it counts BOTH classes
## independently so neither can be missed.
static func budget(root: Node) -> Dictionary:
	var triangles := 0
	var unique_triangles := 0
	var draws := 0
	var ordinary_draws := 0
	var multimesh_draws := 0
	var meshes := 0
	var multimesh_nodes := 0
	var instances := 0
	for node in _geometry_nodes(root):
		if node is MultiMeshInstance3D:
			var mmi := node as MultiMeshInstance3D
			if not mmi.visible:
				continue
			var mm: MultiMesh = mmi.multimesh
			if mm == null or mm.mesh == null:
				continue
			meshes += 1
			multimesh_nodes += 1
			var n := maxi(mm.instance_count, 1)
			instances += n
			var per := _triangles(mm.mesh)
			unique_triangles += per
			triangles += per * n
			var surfaces := maxi(mm.mesh.get_surface_count(), 1)
			multimesh_draws += surfaces
			draws += surfaces
			continue
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if not mi.visible or mi.mesh == null:
				continue
			meshes += 1
			var surfaces := maxi(mi.mesh.get_surface_count(), 1)
			var tris := _triangles(mi.mesh)
			unique_triangles += tris
			triangles += tris
			ordinary_draws += surfaces
			draws += surfaces
	return {
		"triangles": triangles, "unique_triangles": unique_triangles,
		"draws": draws, "ordinary_draws": ordinary_draws, "multimesh_draws": multimesh_draws,
		"meshes": meshes, "multimesh_nodes": multimesh_nodes, "multimesh_instances": instances,
	}


## Every drawable under `root`, MultiMeshes included: `GeometryInstance3D` is the class both
## `MeshInstance3D` and `MultiMeshInstance3D` share, so one query cannot miss either. The
## returned array is typed as `GeometryInstance3D` and the caller narrows it.
static func _geometry_nodes(root: Node) -> Array:
	var out: Array = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		out.append(node)
	if root is GeometryInstance3D:
		out.append(root)
	return out


## How many MultiMesh nodes, instances and drawn triangles a subtree actually has, counted
## through the full `GeometryInstance3D` walk. Exposed so a caller (the lane's test, or a
## report generator) never has to re-derive the sibling-class subtlety above.
static func multimesh_report(root: Node) -> Dictionary:
	var nodes := 0
	var instances := 0
	var families: Array[String] = []
	for node in _geometry_nodes(root):
		if not (node is MultiMeshInstance3D):
			continue
		var mmi := node as MultiMeshInstance3D
		var mm: MultiMesh = mmi.multimesh
		if mm == null:
			continue
		nodes += 1
		instances += mm.instance_count
		families.append("%s x%d" % [String(mmi.name), mm.instance_count])
	families.sort()
	return {"nodes": nodes, "instances": instances, "families": families}


## Triangles in one mesh: index count / 3 when indexed, vertex count / 3 otherwise.
static func _triangles(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total += idx.size() / 3
		elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += verts.size() / 3
	return total
