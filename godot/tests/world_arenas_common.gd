## world_arenas_common.gd — the shared contract for the world-arena proof suites.
##
## NEW FILES ONLY. This lane (independent proof engineer) owns
## `godot/tests/world_arenas*`, `tools/world-arenas/**` and
## `docs/mission/world-arenas/proof/**`. It never edits production code, the camera
## presets or the slice suite; it measures them.
##
## WHAT THE MISSION LAW IS (`docs/mission/world-arenas/CHARTER.md`):
##   - five distinct world arenas (torii, medina, carioca, aurora, egeo), each
##     selectable in the game;
##   - scenery stays behind the BACKDROP_Z=-8.0 plane;
##   - the whole court, both baselines, both side walls and the rear rebound glass
##     stay visible under the REAL, UNCHANGED camera presets; no capture may crop the
##     field or hide the glass to pass;
##   - violations are rejected, not hidden in captures.
##
## The camera presets are authority (`game/court.gd` CAMERAS) and are never altered
## by these suites. Every framing number below comes from the engine's own projection
## through a live `Camera3D` built by `Court.build_camera()` — the same call the game
## makes — so this file cannot disagree with the renderer about where a point lands.
##
## Machine-readable contract, same as the slice suite: `ok <name>` / `FAIL <name>:
## expected …, got …` / `PASS n/n` | `FAIL n/n`, exit 0 on PASS, 1 on FAIL.
extends RefCounted

const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const Court := preload("res://game/court.gd")

## The five arenas this mission adds, in the mission's own order (CHARTER.md).
const WORLD_IDS := ["torii", "medina", "carioca", "aurora", "egeo"]
## The field law: scenery stays behind this world-z plane. A scenery vertex with
## z > BACKDROP_Z_LAW is ON THE WRONG SIDE of the law and fails.
const BACKDROP_Z_LAW := -8.0
## The playable footprint, from `court_builder.gd`: the court bed is 10 x 20 m and
## the cages stand on its edges (x = +-5, z = +-10, glass to `Court.GLASS_H`).
const COURT_HALF_W := 5.0
const COURT_HALF_D := 10.0
## The rear glass plane. `court_builder.build_rear_wall` puts the panes at
## z = -court_half_depth - panes' own -0.02 offset; the plane itself is z = -10.0.
## This constant is the design number; the GATE measures the built panes instead
## (`rear_glass_plane` below) and never trusts this value for the verdict.
const REAR_GLASS_Z := -10.0
## The six rear panes' node names (`court_builder.build_rear_wall`).
const REAR_PANE_NAMES := ["GlassFar", "GlassFar2", "GlassFar3", "GlassFar4", "GlassFar5", "GlassFar6"]
## The glass cage's top: `Court.GLASS_H` (3.0 m). The rear wall's rail stands a
## few cm above it; the rail top is reported as an INFO margin, never gated,
## because the mandate names the glass, and the rail is frame dressing.
const GLASS_TOP := Court.GLASS_H
const RAIL_TOP := Court.GLASS_H + 0.05

# ---------------------------------------------------------------------------
# The check harness (same shape as `tests/game_slice_test.gd`)
# ---------------------------------------------------------------------------

var checks: int = 0
var failures: int = 0
var fail_lines: Array[String] = []


func check(name: String, condition: bool, got: Variant = "") -> void:
	checks += 1
	if condition:
		print("ok %s" % name)
		return
	failures += 1
	var line := "FAIL %s: expected true, got %s" % [name, str(got)]
	print(line)
	fail_lines.append(line)


func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(actual)]
	print(line)
	fail_lines.append(line)


func exit_code() -> int:
	return 0 if failures == 0 else 1


func verdict() -> void:
	if failures == 0:
		print("PASS %d/%d" % [checks, checks])
	else:
		print("FAIL %d/%d first=%s" % [checks - failures, checks, fail_lines[0] if not fail_lines.is_empty() else ""])


# ---------------------------------------------------------------------------
# Command line + banners
# ---------------------------------------------------------------------------

## `--flag=value`, or `fallback` when absent. Same convention as the game's own
## arg parsing (`match_controller.gd::_arg`).
## `--flag=value` and `--flagvalue` both work: the `=` is a separator, not part of
## the value. (Kept because the failed capture run read `--out=<abs path>` as
## `=<abs path>`: `substr(prefix.length())` keeps the `=`, the path then resolves
## nowhere and every PNG write fails with err=7.)
static func arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			var rest := a.substr(prefix.length())
			if rest.begins_with("="):
				rest = rest.substr(1)
			return rest
	return fallback


## The arena ids this run targets: `--arenas=a,b,c` if given, the five world
## arenas otherwise (the mission's subject), `--all` for the whole frozen roster.
static func target_ids(args: PackedStringArray) -> Array:
	var all := arg(args, "--all", "")
	if all != "":
		var out_all: Array = []
		for id in Arena.ids():
			out_all.append(String(id))
		return out_all
	var raw := arg(args, "--arenas", "")
	if raw == "":
		return WORLD_IDS.duplicate()
	var out: Array = []
	for piece in raw.split(",", false):
		var id := piece.strip_edges()
		if id != "":
			out.append(id)
	return out


static func banner(kind: String) -> void:
	print("# %s · Godot %s · field-law z=%.1f · presets=%s" % [
		kind, Engine.get_version_info().get("string", "?"), BACKDROP_Z_LAW,
		str(Court.CAMERAS.keys()),
	])


# ---------------------------------------------------------------------------
# The framing contract: the required points
# ---------------------------------------------------------------------------

## The GATING framing set, one entry per named world point: `court_corner_*` (the
## four court-bed corners, both baselines' ends), `side_glass_*` (both side walls'
## extents: foot and top at both ends of the 20 m wall) and `rear_glass_*` (the
## rear rebound glass's extents). Names carry the side so a failure says which
## part of the frame broke.
static func required_points() -> Array:
	var points: Array = []
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			points.append({
				"name": "court_corner_%s_%s" % [side_name_x(side_x), side_name_z(side_z)],
				"at": Vector3(side_x * COURT_HALF_W, 0.0, side_z * COURT_HALF_D),
			})
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			for y in [0.0, GLASS_TOP]:
				points.append({
					"name": "side_glass_%s_%s_%s" % [side_name_x(side_x), "foot" if y == 0.0 else "top", side_name_z(side_z)],
					"at": Vector3(side_x * COURT_HALF_W, y, side_z * COURT_HALF_D),
				})
	for side_x in [-1.0, 1.0]:
		for y in [0.0, GLASS_TOP]:
			points.append({
				"name": "rear_glass_%s_%s" % [side_name_x(side_x), "foot" if y == 0.0 else "top"],
				"at": Vector3(side_x * COURT_HALF_W, y, REAR_GLASS_Z),
			})
	return points


## NON-GATING extras, reported so nothing is hidden: the rear rail's top line and
## the near wall's extents (the wall behind the player, which the mandate does not
## name; the near BASELINE is gating through the court corners above).
static func info_points() -> Array:
	var points: Array = []
	for side_x in [-1.0, 1.0]:
		points.append({
			"name": "rear_rail_top_%s" % side_name_x(side_x),
			"at": Vector3(side_x * COURT_HALF_W, RAIL_TOP, REAR_GLASS_Z),
		})
		for y in [0.0, GLASS_TOP]:
			points.append({
				"name": "near_glass_%s_%s" % [side_name_x(side_x), "foot" if y == 0.0 else "top"],
				"at": Vector3(side_x * COURT_HALF_W, y, -REAR_GLASS_Z),
			})
	return points


static func side_name_x(side_x: float) -> String:
	return "left" if side_x < 0.0 else "right"


static func side_name_z(side_z: float) -> String:
	return "far" if side_z < 0.0 else "near"


# ---------------------------------------------------------------------------
# Projection through a LIVE camera
# ---------------------------------------------------------------------------

## Where a world point lands through a live camera at a viewport size, in pixels:
##   behind — the point is behind the camera's near plane: it cannot be visible,
##            and `unproject_position` would return a meaningless mirror point.
##            NEVER silently skipped: a required point that is behind is a FAIL.
##   px     — pixel coordinates, (0,0) top-left, when not behind.
##   margin — pixels from the point to the nearest frame edge; negative means
##            outside the frame (cropped). 0 means exactly on the edge.
##   inside — not behind and margin >= 0.
static func project_point(cam: Camera3D, viewport: Vector2, at: Vector3) -> Dictionary:
	var behind := cam.is_position_behind(at)
	if behind:
		return {"behind": true, "px": Vector2(-1.0, -1.0), "margin": -INF, "inside": false}
	var px: Vector2 = cam.unproject_position(at)
	var margin := minf(minf(px.x, px.y), minf(viewport.x - px.x, viewport.y - px.y))
	return {"behind": false, "px": px, "margin": margin, "inside": margin >= 0.0}


## One line per arena+preset with the aggregate framing numbers, plus one line per
## failing point. `worst` is the smallest margin among the gating points.
static func frame_line(preset: String, id: String, results: Array) -> void:
	var inside := 0
	var behind := 0
	var worst := INF
	var worst_name := ""
	var fails: Array[String] = []
	for r in results:
		var res: Dictionary = r["result"]
		if bool(res["behind"]):
			behind += 1
			fails.append("%s:BEHIND" % r["name"])
			continue
		if bool(res["inside"]):
			inside += 1
		else:
			fails.append("%s:px=(%.0f,%.0f):margin=%.1f" % [r["name"], res["px"].x, res["px"].y, res["margin"]])
		if float(res["margin"]) < worst:
			worst = float(res["margin"])
			worst_name = String(r["name"])
	print("FRAME preset=%s arena=%s points=%d inside=%d behind=%d worst=%.1fpx(%s) failures=%s" % [
		preset, id, results.size(), inside, behind, worst, worst_name,
		"none" if fails.is_empty() else ",".join(fails),
	])


# ---------------------------------------------------------------------------
# Geometry: world AABBs and the scenery walk
# ---------------------------------------------------------------------------

## A node's transform in the frame of `ancestor`, walked up the parent chain. The
## same walk the production module's own `ArenaScenery._xform_to` does, and for
## the same reason: the arenas the proof builds are DETACHED subtrees (nothing
## adds an `Arena.build()` result to the scene tree), and `Node3D.global_transform`
## on a node outside the tree is identity — with one engine error per call, 399
## of them in the first field-law run (`Condition "!is_inside_tree()" is true.
## Returning: Transform3D()`). Walking the chain measures the arena's own frame
## whatever the node is attached to, which is also the frame the field law is
## written in.
static func arena_xform_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf


## The arena-frame AABB of one mesh instance: EVERY VERTEX of EVERY SURFACE
## through `arena_xform_to(mi, arena_root)`, min/max — not the mesh AABB's 8
## corners, and never `global_transform`. Vertices, because the field law is
## about the closest POINT (`closest_z`) and a corner of an inflated box is not
## a point the geometry has; the walk, because the tree is detached. Falls back
## to the mesh AABB corners (still walked) when a surface cannot be read.
## Returns an empty AABB for a mesh-less instance.
static func world_aabb(mi: MeshInstance3D, arena_root: Node3D) -> AABB:
	if mi.mesh == null:
		return AABB()
	var xf := arena_xform_to(mi, arena_root)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var any := false
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var p: Vector3 = xf * v
			lo = lo.min(p)
			hi = hi.max(p)
			any = true
	if not any:
		var aabb: AABB = mi.mesh.get_aabb()
		for i in 8:
			var corner: Vector3 = xf * aabb.get_endpoint(i)
			lo = lo.min(corner)
			hi = hi.max(corner)
	return AABB(lo, hi - lo)


## Every MeshInstance3D under a built arena's `Scenery/` subtree, plus the
## `Scenery` root's own name for reporting. The backdrop wall, artwork, veil,
## apron and every prop part are all in here: the walk is what the field law is
## measured against — node names play no part, so scenery cannot dodge the check
## by being renamed.
static func scenery_meshes(built: Node3D) -> Array:
	var out: Array = []
	var scenery: Node = built.get_node_or_null("Scenery")
	if scenery == null:
		return out
	for mi in scenery.find_children("*", "MeshInstance3D", true, false):
		out.append(mi)
	if scenery is MeshInstance3D:
		out.append(scenery)
	return out


## The scenery's field-law numbers for one built arena (all in the ARENA's frame,
## see `arena_xform_to`):
##   closest_z     — the largest arena-frame z of any scenery vertex (the closest
##                   point to the camera; the law wants this <= BACKDROP_Z_LAW);
##   closest_name  — the mesh carrying that point;
##   wall_z        — the `Backdrop` wall's own z;
##   module_z      — `ArenaScenery.BACKDROP_Z`, the module constant, for the record;
##   meshes        — how many scenery meshes were walked;
##   court_overlap — scenery meshes whose AABB intersects the playable footprint
##                   (the court's x/z footprint, at any height): must be empty;
##   glass_z       — the MEASURED rear glass plane (see `rear_glass_plane`): the
##                   arena-frame z of the pane face nearest the camera;
##   glass_name    — the pane carrying that face; glass_panes — how many of the
##                   six panes were found; glass_found — whether the plane could
##                   be measured at all (a missing pane is a violation elsewhere);
##   behind_glass  — one line per scenery mesh whose nearest point is IN FRONT of
##                   the measured glass (z > glass_z): the independent
##                   dressing-behind-the-actual-rear-glass check. Empty on a pass.
static func field_law_report(built: Node3D) -> Dictionary:
	var glass := rear_glass_plane(built)
	var closest := {"z": -INF, "name": ""}
	var wall_z := 0.0
	var wall_found := false
	var overlaps: Array[String] = []
	var behind_glass: Array[String] = []
	var meshes := 0
	for node in scenery_meshes(built):
		var mi := node as MeshInstance3D
		var bounds := world_aabb(mi, built)
		meshes += 1
		if bounds.size == Vector3.ZERO and bounds.position == Vector3.ZERO:
			continue
		if bounds.end.z > float(closest["z"]):
			closest = {"z": bounds.end.z, "name": String(mi.name)}
		if String(mi.name) == "Backdrop":
			wall_z = bounds.position.z
			wall_found = true
		# The independent glass check: the nearest point of every scenery mesh
		# must stay behind the MEASURED rear glass plane. `-9` passes the -8 law
		# above but fails HERE; both planes are reported, neither replaces the other.
		if bool(glass["found"]) and bounds.end.z > float(glass["z"]) + 0.0001:
			behind_glass.append("%s nearest z=%+.2f > glass z=%+.2f" % [mi.name, bounds.end.z, float(glass["z"])])
		# The playable footprint: the court bed's x/z rectangle at any height.
		# A scenery AABB intersecting it stands over playable ground.
		if bounds.position.z < COURT_HALF_D and bounds.end.z > -COURT_HALF_D \
				and bounds.position.x < COURT_HALF_W and bounds.end.x > -COURT_HALF_W:
			overlaps.append("%s z=%.2f..%.2f x=%.2f..%.2f" % [
				mi.name, bounds.position.z, bounds.end.z, bounds.position.x, bounds.end.x])
	return {
		"closest_z": float(closest["z"]) if closest["z"] > -INF else INF,
		"closest_name": String(closest["name"]),
		"wall_z": wall_z,
		"wall_found": wall_found,
		"module_z": ArenaScenery.BACKDROP_Z,
		"meshes": meshes,
		"court_overlap": overlaps,
		"glass_z": float(glass["z"]),
		"glass_name": String(glass["name"]),
		"glass_panes": int(glass["panes"]),
		"glass_expected_panes": int(glass["expected_panes"]),
		"glass_found": bool(glass["found"]),
		"behind_glass": behind_glass,
	}


## The rear glass's REAL plane, measured from the built geometry — never the
## `REAR_GLASS_Z` constant. Takes the six `GlassFar*` panes' arena-frame vertex
## AABBs and reports the pane FACE NEAREST the camera (their max z; the panes are
## flat in z, so this is the glass surface itself, at the built -10.02). The
## scenery-behind-glass check reads this, so it cannot drift from the glass that
## is actually on screen. `found` is false when no pane could be measured: the
## callers fail on that rather than treat "no glass" as "no violation".
static func rear_glass_plane(built: Node3D) -> Dictionary:
	var panes := 0
	var front := -INF
	var front_name := ""
	for nm in REAR_PANE_NAMES:
		var pane := built.find_child(nm, true, false) as MeshInstance3D
		if pane == null:
			continue
		panes += 1
		var bounds := world_aabb(pane, built)
		if bounds.end.z > front:
			front = bounds.end.z
			front_name = String(pane.name)
	return {
		"z": front if front > -INF else INF,
		"name": front_name,
		"panes": panes,
		"expected_panes": REAR_PANE_NAMES.size(),
		"found": front > -INF,
	}


## GearRing / AccentPostL/R are the court's own SHARED dressing: `court_builder.gd`
## builds the same three objects into every arena, the frozen nine included
## (`arena_library.gd` lists them under "the cage's outside dressing"), so they
## are NOT arena scenery and the `Scenery/` walk cannot see them. The review asked
## for coverage OR an explicit classification; this does BOTH — classifies them as
## shared structural dressing and COVERS them by measurement:
##   GearRing      — hangs in the scenery band behind the rear glass; its nearest
##                   arena-frame vertex must stay behind the MEASURED glass plane;
##   AccentPostL/R — stand at z = +3.4, x = ±7: outside the cage laterally
##                   (|x| > COURT_HALF_W), i.e. never over the playable footprint.
## Returns the classification string, the measured facts and one line per problem.
static func structural_report(built: Node3D, glass_z: float) -> Dictionary:
	var problems: Array[String] = []
	var gear := {"found": false, "z": 0.0, "behind_glass": false}
	var gear_node := built.find_child("GearRing", true, false) as MeshInstance3D
	if gear_node == null:
		problems.append("GearRing missing (shared court dressing should exist in every arena)")
	else:
		var gb := world_aabb(gear_node, built)
		gear = {"found": true, "z": gb.end.z, "behind_glass": gb.end.z <= glass_z + 0.0001}
		if not bool(gear["behind_glass"]):
			problems.append("GearRing nearest z=%+.2f is NOT behind the measured glass z=%+.2f" % [gb.end.z, glass_z])
	var posts: Array = []
	for nm in ["AccentPostL", "AccentPostR"]:
		var post := built.find_child(nm, true, false) as MeshInstance3D
		if post == null:
			problems.append("%s missing (shared court dressing should exist in every arena)" % nm)
			continue
		var pb := world_aabb(post, built)
		var outside := pb.end.x <= -COURT_HALF_W or pb.position.x >= COURT_HALF_W
		posts.append({"name": nm, "z": (pb.position.z + pb.end.z) * 0.5, "x": (pb.position.x + pb.end.x) * 0.5, "outside_cage": outside})
		if not outside:
			problems.append("%s is not outside the cage laterally (x=%.2f..%.2f)" % [nm, pb.position.x, pb.end.x])
	return {
		"classified": "shared structural court dressing (court_builder.gd), identical in every arena including the frozen nine; not arena scenery",
		"gear": gear,
		"posts": posts,
		"problems": problems,
	}


## The LIVE camera's own requirement for the scenery band at plane `z`, measured
## through the engine's projection (`Camera3D.project_ray_normal`) — not through
## `ArenaScenery.band()`'s closed form. `viewport` is the render size the frame is
## measured at. The band's job is to cover the frame's upper rows with the backdrop
## wall at `z`, so this returns the minimum the wall must satisfy:
##   required_top    — world y where the frame's top-centre ray crosses plane z;
##   required_half_x — the widest |x| of any left/right edge-ray crossing of plane
##                     z that lands at or above the ground (hit.y >= 0): the wall
##                     must be at least this wide;
##   crossed         — whether the top-centre ray crossed plane z in front of the
##                     camera at all (false = the frame does not reach the wall);
##   samples         — edge samples taken.
## This is the independent twin of `band()`: it exists because the playable
## preset's camera is oriented by `look_at` while `band()` reads `pitch_deg`
## (recorded mismatch — see `docs/mission/world-arenas/refinement.md`).
static func live_band_requirement(cam: Camera3D, viewport: Vector2, z: float, samples := 61) -> Dictionary:
	var size := viewport
	var required_top := -INF
	var required_half := 0.0
	var crossed := false
	# The frame's top-centre ray.
	var top_hit: Variant = _ray_plane_hit(cam, Vector2(size.x * 0.5, 0.5), z)
	if top_hit != null:
		crossed = true
		required_top = maxf(required_top, (top_hit as Vector3).y)
	# Both side edges, all rows.
	for i in samples:
		var t := float(i) / float(maxi(samples - 1, 1))
		var y := 0.5 + t * (size.y - 1.0)
		for x in [0.5, size.x - 0.5]:
			var hit: Variant = _ray_plane_hit(cam, Vector2(x, y), z)
			if hit == null:
				continue
			var h: Vector3 = hit
			if h.y >= 0.0:
				required_half = maxf(required_half, absf(h.x))
	return {
		"required_top": required_top,
		"required_half_x": required_half,
		"crossed": crossed,
		"samples": samples,
	}


## Where the ray through a viewport position crosses the plane z = `z`, or null
## when it never does in front of the camera.
static func _ray_plane_hit(cam: Camera3D, at: Vector2, z: float) -> Variant:
	var dir := cam.project_ray_normal(at)
	if absf(dir.z) < 0.000001:
		return null
	var origin: Vector3 = cam.global_position
	var t := (z - origin.z) / dir.z
	if t <= 0.0:
		return null
	return origin + dir * t


## The world-space AABB of every `Dressing_*` object under `Scenery/` (one per
## authored prop), so the capture run can prove each prop is inside the frame.
static func dressing_nodes(built: Node3D) -> Array:
	var out: Array = []
	var scenery: Node = built.get_node_or_null("Scenery")
	if scenery == null:
		return out
	for child in scenery.get_children():
		if String(child.name).begins_with("Dressing_") and child is Node3D:
			out.append(child)
	return out


static func node_world_aabb(node: Node, arena_root: Node3D) -> AABB:
	if node is MeshInstance3D:
		return world_aabb(node as MeshInstance3D, arena_root)
	var combined := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b := world_aabb(mi as MeshInstance3D, arena_root)
		if first:
			combined = b
			first = false
		else:
			combined = combined.merge(b)
	return combined


# ---------------------------------------------------------------------------
# The five arenas, one line each, for the record
# ---------------------------------------------------------------------------

## Everything the proof needs to say about one arena, without judging it:
## roster facts, style family, the scenery vocabulary, the field-law numbers and
## the glass the arena will be captured with.
static func arena_report(id: String, built: Node3D) -> Dictionary:
	var info: Dictionary = Arena.info(id)
	var kinds: Array = []
	for kind in Arena.prop_kinds(id):
		kinds.append(String(kind))
	var field := field_law_report(built)
	var scenery: Node = built.get_node_or_null("Scenery")
	var dressing := 0
	if scenery != null:
		for child in scenery.get_children():
			if String(child.name).begins_with("Dressing_"):
				dressing += 1
	return {
		"id": id,
		"family": String(info.get("family", "")),
		"wallBounce": float(info.get("wallBounce", -1.0)),
		"rear_alpha": float(info.get("rear_alpha", -1.0)),
		"signature": Arena.signature(id),
		"props": (info.get("props", []) as Array).size(),
		"dressing": dressing,
		"kinds": kinds,
		"field": field,
		"meshes": built.find_children("*", "MeshInstance3D", true, false).size() + (1 if built is MeshInstance3D else 0),
	}


static func report_line(r: Dictionary) -> String:
	var field: Dictionary = r["field"]
	return (("ARENA id=%-8s family=%-6s wallBounce=%.2f rear_alpha=%.3f meshes=%3d props=%2d dressing=%2d "
		+ "closest_scenery_z=%+.2f(%s) wall_z=%+.2f module_z=%+.2f overlaps=%d "
		+ "glass_z=%+.2f(%s %d/%d) behind_glass=%d kinds=%s") % [
		String(r["id"]), String(r["family"]), float(r["wallBounce"]), float(r["rear_alpha"]),
		int(r["meshes"]), int(r["props"]), int(r["dressing"]),
		float(field["closest_z"]), String(field["closest_name"]), float(field["wall_z"]),
		float(field["module_z"]), (field["court_overlap"] as Array).size(),
		float(field["glass_z"]), String(field["glass_name"]), int(field["glass_panes"]), int(field["glass_expected_panes"]),
		(field["behind_glass"] as Array).size(),
		",".join(PackedStringArray(r["kinds"])),
	])


## `ArenaScenery.BACKDROP_Z` — the scenery band's own plane, re-exported so the
## suites do not have to preload the production module just for one constant.
static func backdrop_wall_z() -> float:
	return ArenaScenery.BACKDROP_Z
