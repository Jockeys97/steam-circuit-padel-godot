## cornetto_racket_test.gd — Il Cornetto (Fornaio's croissant racket) against the
## shipped ellipse, built from the same call.
##
## What this gate is for: `Court.make_racket_view` grew a `style` argument, and the one
## thing that must not move is the default. So this test builds a plain racket, an
## explicit-`standard` racket and a `cornetto` racket from the same function, measures
## all three off their own meshes, and asserts that:
##
##   1. the default and explicit `standard` are still exactly the old head — a `Face`
##      plus a `Grip`, no croissant anywhere;
##   2. `cornetto` is not an empty root — a `CroissantHead`, a `Throat` and a `Handle`
##      with real meshes, all matte, none of them strings or a perforated face;
##   3. the two heads sit in one size band: every racket is 0.26 m wide and 36-52 cm
##      tall in its own frame, and the cornetto is within 5 cm of the ellipse's height,
##      which is the "still reads as a padel racket in hand" claim, measured not guessed;
##   4. the hand attach still lands on the grip: the cornetto's rolling-pin band covers
##      the same y (root 0 -> grip centre 0.2405 m below) the ellipse grip covers;
##   5. the binding is real: athlete id `fornaio` maps to `cornetto`, a frozen athlete
##      does not, and the explicit per-role style override reaches a spawned rig.
##
## It does NOT assert the sim. `paddle.w` / `paddle.h` are the contact box and no part of
## this test reads them, on purpose: the croissant is a drawing of the racket, not a
## change to the game.
extends SceneTree

const AthletesView := preload("res://game/athletes_view.gd")
const Court := preload("res://game/court.gd")

## The band every racket must fit in, in metres of its own frame: the shipped racket
## measures about 43.5 cm from face top to grip bottom, and a padel racket is 45 cm.
const BAND_MIN := 0.36
const BAND_MAX := 0.52
## How far the cornetto's height may drift from the ellipse's.
const BAND_DRIFT := 0.05

var _checks := 0
var _failures := 0


func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "RacketHolder"
	root.add_child(holder)

	# 1. The default: no style argument at all, which is every pre-existing call site.
	var plain: Node3D = Court.make_racket_view(holder, "RacketPlain", Color.GOLD)
	check_true(plain.get_node_or_null("SlamRacket") != null, "default build uses the textured Slam racket")
	check_true(plain.get_node_or_null("Grip") == null, "no procedural grip overlaps the imported grip")
	check_true(plain.get_node_or_null("CroissantHead") == null, "default build has no croissant")
	check_eq(_meshes(plain).size(), 1, "default build has the authored mesh")

	# 2. An explicit `standard` is the same head as the default.
	var standard: Node3D = Court.make_racket_view(holder, "RacketStandard", Color.GOLD,
		Court.RACKET_STYLE_STANDARD)
	check_true(standard.get_node_or_null("SlamRacket") != null, "style standard uses Slam")
	check_true(standard.get_node_or_null("Grip") == null, "standard has no duplicate grip")
	check_true(standard.get_node_or_null("CroissantHead") == null, "style `standard` has no croissant")

	# 3. Il Cornetto.
	var cornetto: Node3D = Court.make_racket_view(holder, "RacketCornetto", Color.GOLD,
		Court.RACKET_STYLE_CORNETTO)
	var head: Node = cornetto.get_node_or_null("CroissantHead")
	var throat: Node = cornetto.get_node_or_null("Throat")
	var handle: Node = cornetto.get_node_or_null("Handle")
	check_true(head != null, "cornetto has a CroissantHead node")
	check_true(throat != null, "cornetto has a Throat node")
	check_true(handle != null, "cornetto has a Handle node")
	check_true(cornetto.get_node_or_null("Face") == null, "cornetto draws no ellipse face")
	if head != null:
		check_eq(_meshes(head).size(), Court.CORNETTO_SEGMENTS,
			"the croissant head is one mesh per dough segment")
	if handle != null:
		check_true(_meshes(handle).size() >= 5, "the handle carries a shaft, knobs and twine")
		check_true(handle.get_node_or_null("RollingPin") != null, "the handle is a rolling pin")
	check_true(_meshes(cornetto).size() >= 14, "the cornetto root is not an empty root")
	check_true(_unanchored(cornetto) == 0, "every cornetto mesh has a mesh and a material")

	# 4. Matte, and no strings: the croissant is a solid pastry head.
	check_eq(_metallic(cornetto), 0, "every cornetto part is matte (no chrome, no metal)")

	# 5. One size band: measure both heads off their own meshes, in the racket's frame.
	var plain_span := _span(plain)
	var cornetto_span := _span(cornetto)
	print("CORNETTO_SPANS plain=%s standard=%s cornetto=%s" % [
		str(plain_span), str(_span(standard)), str(cornetto_span)])
	check_true(plain_span.y > BAND_MIN and plain_span.y < BAND_MAX,
		"the shipped racket stays in the 36-52 cm band (%.3f m)" % plain_span.y)
	check_true(cornetto_span.y > BAND_MIN and cornetto_span.y < BAND_MAX,
		"the cornetto is in the same band (%.3f m)" % cornetto_span.y)
	check_true(absf(cornetto_span.y - plain_span.y) <= BAND_DRIFT,
		"the cornetto's height is within %.2f m of the ellipse's" % BAND_DRIFT)
	check_true(absf(cornetto_span.x - 2.0 * Court.RACKET_FACE_R) <= 0.02,
		"the croissant head is the ellipse face's width (%.3f m)" % cornetto_span.x)

	# 6. The hand attach: the grip band is the same, so RACKET_HAND_LOCAL is still right.
	var grip_centre := -(Court.RACKET_FACE_R * Court.RACKET_FACE_LEN + Court.RACKET_GRIP_L * 0.5)
	check_true(_covers_y(cornetto, grip_centre), "the cornetto's handle covers the hand attach y")
	check_true(_covers_y(plain, grip_centre), "the shipped grip covers the hand attach y")
	check_true(_covers_y(cornetto, grip_centre + Court.RACKET_GRIP_L * 0.5 - 0.002),
		"the cornetto's handle reaches the top of the shipped grip band")

	# 7. The binding, both ways.
	check_eq(AthletesView.racket_style_for(&"fornaio"), Court.RACKET_STYLE_CORNETTO,
		"athlete id fornaio swings Il Cornetto")
	check_eq(AthletesView.racket_style_for(&"colosso"), Court.RACKET_STYLE_STANDARD,
		"a frozen athlete keeps the shipped ellipse")
	check_eq(AthletesView.racket_style_for(&""), Court.RACKET_STYLE_STANDARD,
		"an unknown athlete id keeps the shipped ellipse")
	_check_spawned_special()
	_check_spawned_override()

	_finish()


## The live path: the special athlete, spawned through the same call the match makes, with
## NO style override — the croissant has to come from the athlete id alone.
func _check_spawned_special() -> void:
	var view := AthletesView.new()
	root.add_child(view)
	var spawned: int = view.spawn({"player": {"id": "fornaio"}}, {"player": &"base"},
		{"player": Color("d98e2b")})
	var style: String = view.racket_styles.get("player", "?")
	print("CORNETTO_SPECIAL rigs=%d style=%s" % [spawned, style])
	if spawned == 1:
		check_eq(style, "cornetto", "the fornaio rig swings Il Cornetto with no override at all")
		check_true(view.rackets["player"].get_node_or_null("CroissantHead") != null,
			"and the croissant is on the rig's hand bone")
	view.free()


## The explicit style name has to reach a real rig, not just the factory: this spawns the
## one athlete whose GLB is on this checkout and asks for the croissant by name, then
## reads the racket back off the node it created.
func _check_spawned_override() -> void:
	var view := AthletesView.new()
	root.add_child(view)
	var lineup := {"player": {"id": "colosso"}}
	var spawned: int = view.spawn(lineup, {"player": &"base"}, {"player": Color.GOLD},
		{"player": Court.RACKET_STYLE_CORNETTO})
	if spawned != 1:
		check_true(false, "a rig spawned so the style override could be exercised (got %d)" % spawned)
		view.free()
		return
	var racket: Node3D = view.rackets["player"]
	check_eq(racket.get_node_or_null("CroissantHead") != null, true,
		"the cornetto style reached the spawned racket on the hand bone")
	check_eq(view.racket_styles.get("player", "?"), "cornetto",
		"the view reports the style it built")
	check_eq(view.describe_all()["player"]["racket_style"], "cornetto",
		"the athlete report carries the style per role")
	check_eq(view.rackets["player"].position, AthletesView.RACKET_HAND_LOCAL,
		"the cornetto rides the same grip-centre offset as the shipped racket")
	view.free()


# ---------------------------------------------------------------------------
# Measurement — read off the meshes, not off what the builder remembers
# ---------------------------------------------------------------------------

## Every MeshInstance3D under a root.
func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


## How many meshes are missing a mesh resource or a material (a silently broken build).
func _unanchored(node: Node) -> int:
	var bad := 0
	for child in _meshes(node):
		var mi := child as MeshInstance3D
		if mi.mesh == null or mi.material_override == null:
			bad += 1
	return bad


## How many meshes are metallic: Il Cornetto is matte only, and `Court.material()` never
## sets metalness, so a non-zero here would be somebody else's override leaking in.
func _metallic(node: Node) -> int:
	var metal := 0
	for child in _meshes(node):
		var mi := child as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null or m.metallic > 0.0:
			metal += 1
	return metal


## Every mesh under a root, each with its transform taken from its parents' LOCAL
## transforms up to that root. Deliberately not `global_transform`: a `SceneTree` script's
## `_initialize()` runs before the scene is inside the tree, and a global read there returns
## the identity and prints `!is_inside_tree()` (measured: 630 of them on the first run of
## this test). The racket's own frame is also exactly what the two styles must be compared
## in, so this is the honest measurement and not a workaround.
func _in_frame(root: Node3D) -> Array:
	var found := []
	_collect(root, Transform3D.IDENTITY, found)
	return found


func _collect(node: Node, xform: Transform3D, found: Array) -> void:
	if node is MeshInstance3D:
		found.append({"mesh": node, "xform": xform})
	for child in node.get_children():
		if child is Node3D:
			_collect(child, xform * (child as Node3D).transform, found)


## The eight corners of a mesh's local AABB, in the mesh's own local space.
func _corners(mi: MeshInstance3D) -> Array:
	var box := mi.mesh.get_aabb()
	var corners := []
	for corner in 8:
		corners.append(box.position + Vector3(
			box.size.x * float(corner & 1),
			box.size.y * float((corner >> 1) & 1),
			box.size.z * float((corner >> 2) & 1)))
	return corners


## The racket's own-frame size: the union of every mesh's local AABB, expressed in the
## racket root's frame. Independent of where the racket hangs, so the two styles are
## compared like for like.
func _span(racket: Node3D) -> Vector2:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for entry in _in_frame(racket):
		var mi: MeshInstance3D = entry["mesh"]
		var xform: Transform3D = entry["xform"]
		for corner in _corners(mi):
			var at: Vector3 = xform * corner
			lo = lo.min(at)
			hi = hi.max(at)
	return Vector2(hi.x - lo.x, hi.y - lo.y)


## Whether any mesh of the racket spans a given height in the racket's own frame — the
## test's way of asking "is there something to hold on to at the hand attach y".
func _covers_y(racket: Node3D, y: float) -> bool:
	for entry in _in_frame(racket):
		var mi: MeshInstance3D = entry["mesh"]
		var xform: Transform3D = entry["xform"]
		var lo := INF
		var hi := -INF
		for corner in _corners(mi):
			var at: Vector3 = xform * corner
			lo = minf(lo, at.y)
			hi = maxf(hi, at.y)
		if y >= lo and y <= hi:
			return true
	return false


func check_eq(got, expected, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
	else:
		_failures += 1
		printerr("FAIL %s: expected %s, got %s" % [name, str(expected), str(got)])


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
