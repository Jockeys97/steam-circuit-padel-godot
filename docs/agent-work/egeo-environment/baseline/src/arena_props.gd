extends RefCounted
## THE ARENA'S FURNITURE: the players' sideline shelters and the sponsor boards.
##
## The stands (`game/arenas/bleachers.gd`) answered "what does the owner see beyond
## the side glass". These two answer the rest of the same question, and they are one
## module rather than two because they are the same job twice: read a Meshy unit,
## size it from the COURT rather than from the file, and lay N copies along a line
## outside the cage. Two props sharing a placement rule is a real seam; one would
## have been a guess.
##
## WHERE EACH ONE GOES, AND WHY THERE
##
## The shelters stand on the SAME side corridor as the stands, flanking them. The
## stands cover 6 m centred on the net, so the strip between their ends and the
## court's corners is the empty floor a real club fills with the players' benches —
## and it is inside the frame at the default camera, which is what makes it worth
## drawing at all.
##
## The boards stand behind the REAR glass, between the cage and the backdrop wall
## (`arena_scenery.gd::BACKDROP_Z`). That band is the one the camera looks straight
## into down the length of the court: perimeter signage anywhere else on this
## framing is either behind the viewer or edge-on and unreadable.
##
## EVERY SIZE IS DERIVED, NONE IS TYPED TWICE. The court's own `half_len()`,
## `half_depth()` and `Bleachers.CORRIDOR_M` place both families, so a change to the
## court's width moves the furniture with it — the 10 m to 11 m change is exactly
## the kind of edit that would otherwise leave a prop floating inside the glass.
##
## COST. Both units are read once and duplicated per copy (one GLB read, N draws).
## Shadows are off here and on for the stands, and the split is measured, not
## assumed: see the note on `cast_shadow` below.

const Court := preload("res://game/court.gd")
const Bleachers := preload("res://game/arenas/bleachers.gd")

## The owner's models, copied into the tracked runtime tree.
const SHELTER_GLB := "res://assets/arena/sideline-shelter.glb"
const BOARD_GLB := "res://assets/arena/sponsor-board.glb"

## Uniform scale of one shelter. The unit is 1.90 m wide as authored; 2.4 makes it
## 4.6 m wide and 2.3 m tall — a bench shelter that stands UNDER the 3 m side glass
## rather than over it, which is what keeps the cage reading as the tallest thing on
## the side line.
static var shelter_scale := 2.4
## Shelters per side, laid along the side line beyond the stands' own span.
static var shelters_per_side := 2
## Uniform scale of one board. 2.0 makes the 1.90 m unit 3.8 m wide and 0.82 m tall,
## so three of them span 11.4 m against the court's 11.0 m — the run reads as
## continuous signage without a gap at the corners.
static var board_scale := 2.0
## Boards along the rear line.
static var board_count := 3
## Clear floor between the rear glass and the boards' front face. Half the side
## corridor: nobody walks behind the rear glass, and the backdrop wall is 2 m past
## it, so the band is narrow on purpose.
const REAR_CLEARANCE_M := 0.6

## A/B switch for the cost measurement, exactly as the stands have one. The game
## never writes it.
static var enabled := true
## Shadows: OFF, and so are the stands' — see the measurement in `bleachers.gd`.
## The stands' shadow pass alone costs about 20% of the frame rate on this hardware;
## seven more copies in it would cost more and ground less, since a shelter tucked
## against the stands already falls inside their shadow.
static var cast_shadow := false
## What the last `build()` loaded and placed, for the boot log and the evidence.
## Plain values only — a Resource or a Node in a `static var` would outlive the
## scene tree and be reported as leaked at exit.
static var report: Dictionary = {}


## Adds the shelters and the boards to an arena root. Returns the group node (always
## non-null: an unreadable GLB leaves the arena exactly as it was and is reported,
## not raised — the stands' own contract).
static func build(parent: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = "ArenaProps"
	parent.add_child(group)
	report = {"shelters": 0, "boards": 0, "glb_loads": 0, "load_ms": 0,
		"triangles": 0, "error": ""}
	if not enabled:
		report["error"] = "disabled"
		return group

	var started := Time.get_ticks_msec()
	var shelters := _place_shelters(group)
	var boards := _place_boards(group)
	report["load_ms"] = Time.get_ticks_msec() - started
	report["shelters"] = shelters
	report["boards"] = boards

	print("ARENA_PROPS shelters=%d boards=%d glb_loads=%d load_ms=%d triangles=%d shelter_x=%.2f shelter_z=%s board_z=%.2f board_span=%.2f error=%s" % [
		shelters, boards, int(report["glb_loads"]), int(report["load_ms"]),
		int(report["triangles"]), float(report.get("shelter_x", 0.0)),
		str(report.get("shelter_z", [])), float(report.get("board_z", 0.0)),
		float(report.get("board_span", 0.0)), str(report["error"]),
	])
	return group


## The shelters, on the side corridor, flanking the stands' span. Returns how many
## were placed.
static func _place_shelters(group: Node3D) -> int:
	if shelters_per_side <= 0:
		return 0
	var base := _load(SHELTER_GLB)
	if base == null:
		report["error"] = "shelter load failed"
		return 0
	report["glb_loads"] = int(report["glb_loads"]) + 1

	var box := Bleachers.unit_box(base)
	var width := box.size.x * shelter_scale
	var depth := box.size.z * shelter_scale
	# The shelter's front face stands on the same line as the stands' front face, so
	# the two read as one row of furniture rather than two depths of clutter.
	var front_x: float = Court.half_len() + Bleachers.CORRIDOR_M
	var centre_x := front_x + depth * 0.5
	# Beyond the stands' own span, with half a shelter of air between them.
	var stands_half: float = Bleachers.span_z() * 0.5
	var first_z := stands_half + width * 0.5 + width * 0.1

	var placed := 0
	var zs: Array[float] = []
	for side in [1.0, -1.0]:
		for i in shelters_per_side:
			# Alternate up and down the line: 0 -> +z, 1 -> -z, 2 -> further +z.
			var step := float(i / 2) * width * 1.1
			var sign_z := 1.0 if i % 2 == 0 else -1.0
			var z := (first_z + step) * sign_z
			var stack := Node3D.new()
			stack.name = "Shelter%s%d" % ["R" if side > 0.0 else "L", i + 1]
			stack.position = Vector3(centre_x * side, 0.0, z)
			# local +Z (the open face) looks at the court on both sides.
			stack.rotation_degrees = Vector3(0.0, -90.0 * side, 0.0)
			stack.scale = Vector3(shelter_scale, shelter_scale, shelter_scale)
			var body: Node = base.duplicate()
			# the unit's own min_y is negative: lift it onto the floor it stands on.
			body.position = Vector3(0.0, -box.position.y, 0.0)
			_prepare(body)
			stack.add_child(body)
			group.add_child(stack)
			placed += 1
			if side > 0.0:
				zs.append(z)
	report["triangles"] = int(report["triangles"]) + placed * Bleachers.triangle_count(base)
	report["shelter_x"] = centre_x
	report["shelter_z"] = zs
	report["shelter_height_m"] = box.size.y * shelter_scale
	base.free()
	return placed


## The boards, in the band between the rear glass and the backdrop, facing the
## camera. Returns how many were placed.
static func _place_boards(group: Node3D) -> int:
	if board_count <= 0:
		return 0
	var base := _load(BOARD_GLB)
	if base == null:
		report["error"] = ("%s; board load failed" % report["error"]) if report["error"] != "" else "board load failed"
		return 0
	report["glb_loads"] = int(report["glb_loads"]) + 1

	var box := Bleachers.unit_box(base)
	var width := box.size.x * board_scale
	var depth := box.size.z * board_scale
	var z := -(Court.half_depth() + REAR_CLEARANCE_M + depth * 0.5)

	var placed := 0
	for i in board_count:
		var x := (float(i) - float(board_count - 1) * 0.5) * width
		var stack := Node3D.new()
		stack.name = "SponsorBoard%d" % (i + 1)
		stack.position = Vector3(x, 0.0, z)
		# local +Z is the printed face; the camera looks down -Z, so no rotation.
		stack.scale = Vector3(board_scale, board_scale, board_scale)
		var body: Node = base.duplicate()
		body.position = Vector3(0.0, -box.position.y, 0.0)
		_prepare(body)
		stack.add_child(body)
		group.add_child(stack)
		placed += 1
	report["triangles"] = int(report["triangles"]) + placed * Bleachers.triangle_count(base)
	report["board_z"] = z
	report["board_span"] = float(board_count) * width
	report["board_height_m"] = box.size.y * board_scale
	base.free()
	return placed


## Shadow casting, per copy. The stands' `_prepare` also carries the measurement's
## plain-material path; these two have no such knob, so this is the whole of it.
static func _prepare(node: Node) -> void:
	if cast_shadow:
		return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Reads a GLB the way the stands and the athlete rigs are read: `GLTFDocument` +
## `GLTFState` at runtime, which is what makes the load show up in `glb_loads`.
static func _load(path: String) -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK:
		push_error("arena_props.gd: GLB append failed err=%d path=%s" % [err, path])
		return null
	var scene: Node = doc.generate_scene(st)
	if scene == null:
		push_error("arena_props.gd: GLB generate_scene returned null path=%s" % path)
		return null
	return scene
