## arena_kit_test.gd — the arena-kit intake suite (KIT-STANDARD gate G3).
##
##   flock -w 900 /tmp/padel-godot.lock /Applications/Godot.app/Contents/MacOS/Godot \
##     --headless --path godot/ --script res://tests/arena_kit_test.gd
##
## WHAT IT PROVES, in five parts. The suite reads the DISK STATE first (empty kit vs
## kitted) and then makes the same claims in both, because the kit's contract has to
## hold in both: an empty `godot/assets/arenas/` costs nothing, and a full drop folder
## mounts without doubling the dressing.
##
##   1. THE SPEC TABLE IS VALID AND FROZEN-SHAPED. `arena_kit.gd::SPECS` covers the five
##      world arenas x the ten frozen slots exactly (no missing slot, no extra one, the
##      standard's order); every anchor is a ground contact; every target height is
##      metres and inside the built band; every footprint note is there AND its declared
##      depth fits the two planes a built arena is gated on — the charter's field-law
##      plane (z = -8.0) and the MEASURED rear glass plane (z = -10.02, what
##      `world_arenas_field_law_test.gd:194-209` fails on). The declared `depth` is the
##      ENGINE-MEASURED mesh depth (fit pass, `FIT-RESULT.md`), so four slots measure
##      deeper than the 3.26 m constant derived for the default prop z; that budget
##      check stays RED and names them rather than being redefined away. Every repeat
##      run stays inside the authored half-span; every
##      `kinds` entry is a real prop kind of that arena; and `suppress` is ON exactly
##      where a slot HAS a procedural counterpart to stand over (`kinds` non-empty) and
##      OFF everywhere else — no blanket flip (the mission's rule: a slot with
##      `kinds: []` has nothing to double and is left alone).
##
##   2. THE MOUNT IS ADDITIVE, BYTE FOR BYTE, IN BOTH STATES. `run/tmp/arena-kit/
##      baseline.json` is the digest recorded by `run/tmp/arena-kit/baseline_probe.gd`
##      BEFORE the seam existed (same digest function, copied here verbatim, plus one
##      optional `skip` argument that defaults to "skip nothing": the walk with no skip
##      is the recorded one). With suppression forced OFF (`ArenaKit.suppress_overrides`,
##      the module's own test seam) and the `Kit` subtree skipped, every arena's digest
##      must equal the recorded baseline — including the line count — and its mesh and
##      `Dressing_*` counts must equal the recorded ones once the kit's own meshes are
##      subtracted. That is the same statement the empty-kit regression made, made
##      against the kit that is actually on disk: with `Kit` removed, the procedural tree
##      is the pre-kit tree, so the seam adds a subtree and touches nothing else. With no
##      GLB anywhere the skipped subtree does not exist and the check is the original one
##      verbatim. A missing baseline file is a FAILURE, never a silent pass.
##
##   3. EVERY SLOT WITH A FILE MOUNTS AT ITS SPEC TRANSFORM AND SIZE. For every (arena,
##      slot) that has a GLB: `Scenery/Kit/Slot_<slot>` exists (including under a
##      different camera preset, where x follows the preset's own `x_scale` like a
##      `Dressing_*` container), holds exactly the declared repeat count at the declared
##      spreads, measures its `target_h` within 2 cm, is bottom-origin on the anchor,
##      stays behind the MEASURED glass plane and inside the authored half-span, is not
##      half-cropped by the default camera, carries the shared kit material policy with
##      one material per (file, surface) shared across the repeats, and carries no
##      collider, light, camera or unmeasurable asset class. The fixture drops
##      (`tools/arena-kit/fixtures/tiny_prop.glb`, `res://assets/athletes/volpe-rigged.glb`)
##      run only when their slot is FREE — they are exercised in the empty state and
##      skipped, loudly, when a real asset holds the slot (the seam caches loaded scenes
##      per path, so dropping a fixture over a real slot would measure the cached original
##      anyway).
##
##   4. SUPPRESSION COVERS EXACTLY THE SLOTS THAT DOUBLE, AND NOTHING ELSE. The suppressed
##      set is derived from the table and the disk — kinds non-empty AND a GLB in place —
##      and `suppressed_kinds()` must equal it, kind for kind. Two builds are compared:
##      the table as it ships, and the same table forced OFF. Every suppressed kind loses
##      its procedural meshes in the first and keeps them in the second; every other kind
##      is untouched in both; and `Dressing_*` count == authored prop count in both, so
##      the "one container per authored prop" invariant the frozen suites pin does not
##      move. A slot with `kinds: []` never suppresses anything, even forced on.
##
##   5. NOTHING IS LEFT BEHIND. The suite fingerprints every `.glb` under
##      `godot/assets/arenas/` (path + size) before it starts and requires the same set
##      at the end, removes only what it staged itself, clears `suppress_overrides`, and
##      re-asserts the disk state it found.
##
## Machine-readable contract, same as the other suites: `ok <name>` / `FAIL <name>:
## expected …, got …` / `PASS n/n` | `FAIL n/n`, exit 0 on PASS, 1 on FAIL. A `SCRIPT
## ERROR` anywhere in the log is a failure even next to a green tally.
extends SceneTree

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const Common := preload("res://tests/world_arenas_common.gd")
const Court := preload("res://game/court.gd")

const ARENAS := ["torii", "medina", "carioca", "aurora", "egeo"]
const KITS_DIR := "res://assets/arenas/"
## The recorded pre-change baseline and the fixture the puller also verifies against.
const BASELINE_PATH := "run/tmp/arena-kit/baseline.json"
const TINY_FIXTURE := "tools/arena-kit/fixtures/tiny_prop.glb"
## The real repo GLB used as the second fixture (the smallest athlete export).
const REPO_GLB := "res://assets/athletes/volpe-rigged.glb"
const REPO_GLB_BYTES := 8898424
## Where the two fixtures are dropped, and what each one proves.
const TINY_SLOT := "light_source"
const REPO_SLOT := "hero_landmark"
const FIXTURE_ARENA := "torii"
const HEIGHT_TOLERANCE := 0.02
## The framing contract's viewport and the preset the mounted band is authored for.
const VIEW := Vector2i(1280, 720)
const PRESET := "default"

var checks := 0
var failures := 0
var notes := 0
var fail_lines: Array[String] = []
var staged: Array[String] = []
var fingerprint_before := {}
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

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


## A check that does not apply in this disk state. Counted and printed, never silent.
func note(what: String) -> void:
	notes += 1
	print("NOTE %s" % what)


func verdict() -> void:
	if failures == 0:
		print("PASS %d/%d" % [checks, checks])
	else:
		print("FAIL %d/%d first=%s" % [checks - failures, checks,
			fail_lines[0] if not fail_lines.is_empty() else ""])
	if notes > 0:
		print("# %d note(s) this run" % notes)


# ---------------------------------------------------------------------------
# Paths (repo layout: <repo>/godot is the project, <repo>/run/tmp holds the evidence)
# ---------------------------------------------------------------------------

func _project_dir() -> String:
	return ProjectSettings.globalize_path("res://").rstrip("/")


func _repo_dir() -> String:
	return _project_dir().get_base_dir()


func _abs(path: String) -> String:
	return "%s/%s" % [_repo_dir(), path]


func _slot_res_path(arena_id: String, slot: String) -> String:
	return "%s%s/%s.glb" % [KITS_DIR, arena_id, slot]


func _slot_abs_path(arena_id: String, slot: String) -> String:
	return "%s/assets/arenas/%s/%s.glb" % [_project_dir(), arena_id, slot]


func _x_scale(preset: String) -> float:
	var extent := ArenaScenery.band(preset, ArenaScenery.BACKDROP_Z)
	return float(extent["prop_half_x"]) / ArenaKit.AUTHORED_HALF_X


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

func _run() -> void:
	print("# arena-kit intake suite — godot %s, repo %s" % [Engine.get_version_info()["string"], _repo_dir()])
	root.size = VIEW
	fingerprint_before = _glb_fingerprint()
	_spec_table()
	_disk_state()
	_regression()
	_mount_contract()
	_fixtures()
	_suppression()
	_cleanup()
	verdict()
	quit(0 if failures == 0 else 1)


# --- 1. the spec table -----------------------------------------------------

func _spec_table() -> void:
	var arenas := ArenaKit.arenas()
	var arenas_ok := arenas.size() == ARENAS.size()
	for a in ARENAS:
		if not arenas.has(a):
			arenas_ok = false
	check("spec/the_spec_table_covers_the_five_world_arenas", arenas_ok, str(arenas))
	var slots := ArenaKit.slots()
	var unique := {}
	for s in slots:
		unique[s] = true
	check("spec/the_slot_set_is_the_frozen_ten_in_order",
		slots == ["hero_landmark", "gate_portal", "light_source", "vegetation_cluster",
			"ground_dressing", "ornament_accent", "column_pillar", "railing_segment",
			"furniture", "signage_banner"], str(slots))
	check("spec/every_slot_name_is_unique", unique.size() == slots.size(), str(unique.keys()))

	# One pass over the 5 x 10 table, collecting violations per property: 50 named checks
	# would bury the failures, a violation list per property names each offender.
	var missing: Array[String] = []
	var ground: Array[String] = []
	var heights: Array[String] = []
	var repeats_bad: Array[String] = []
	var run_wide: Array[String] = []
	var notes_bad: Array[String] = []
	var law: Array[String] = []
	var glass: Array[String] = []
	var budget: Array[String] = []
	var suppress_wrong: Array[String] = []
	var suppress_expected: Array[String] = []
	var kinds_bad: Array[String] = []
	var band_top := float(ArenaScenery.band("default", ArenaScenery.BACKDROP_Z)["top"])
	for arena_id in ARENAS:
		var table: Dictionary = ArenaKit.SPECS.get(arena_id, {})
		var have: Array = table.keys()
		for s in slots:
			if not have.has(s):
				missing.append("%s/%s" % [arena_id, s])
		for key in have:
			if not slots.has(String(key)):
				missing.append("%s/%s (not a frozen slot)" % [arena_id, key])
		var prop_kinds: Array = []
		for prop in (ArenaStyle.style(arena_id).get("props", []) as Array):
			prop_kinds.append(String((prop as Dictionary).get("kind", "")))
		for s in slots:
			var entry := ArenaKit.spec(String(arena_id), String(s))
			if entry.is_empty():
				continue
			var where := "%s/%s" % [arena_id, s]
			var anchor: Vector3 = entry["anchor"]
			var target_h := float(entry["target_h"])
			var repeats := int(entry["repeats"])
			var spread := float(entry["spread"])
			var depth := float(entry["depth"])
			var kinds: Array = entry.get("kinds", [])
			if not is_equal_approx(anchor.y, 0.0):
				ground.append("%s y=%.3f" % [where, anchor.y])
			if target_h <= 0.0 or anchor.y + target_h > band_top + 0.0001:
				heights.append("%s h=%.2f (band top %.2f)" % [where, target_h, band_top])
			if repeats < 1 or (repeats == 1 and not is_zero_approx(spread)) or (repeats > 1 and spread <= 0.0):
				repeats_bad.append("%s repeats=%d spread=%.2f" % [where, repeats, spread])
			if absf(anchor.x) + float(repeats - 1) * 0.5 * spread > ArenaKit.AUTHORED_HALF_X:
				run_wide.append("%s x=%.2f run=%.2f" % [where, anchor.x, float(repeats - 1) * spread])
			if String(entry.get("footprint", "")).length() < 24:
				notes_bad.append("%s note=%s" % [where, String(entry.get("footprint", ""))])
			if anchor.z + depth * 0.5 > ArenaScenery.FIELD_LAW_Z:
				law.append("%s front=%.2f" % [where, anchor.z + depth * 0.5])
			if anchor.z + depth * 0.5 > ArenaKit.GLASS_PLANE_Z:
				glass.append("%s front=%.2f (glass %.2f)" % [where, anchor.z + depth * 0.5, ArenaKit.GLASS_PLANE_Z])
			if depth <= 0.0 or depth > ArenaKit.DEPTH_BUDGET:
				budget.append("%s depth=%.2f (budget %.2f)" % [where, depth, ArenaKit.DEPTH_BUDGET])
			# The flag stands where the slot HAS a procedural counterpart, and only there:
			# suppressing a slot with no `kinds` would suppress nothing and hide a mistake.
			var want_suppress := not kinds.is_empty()
			if want_suppress:
				suppress_expected.append(where)
			if bool(entry.get("suppress", false)) != want_suppress:
				suppress_wrong.append("%s suppress=%s kinds=%s" % [where, str(entry.get("suppress", false)), str(kinds)])
			for kind in kinds:
				if not prop_kinds.has(String(kind)):
					kinds_bad.append("%s kind=%s" % [where, kind])
	check("spec/every_arena_carries_exactly_the_ten_frozen_slots", missing.is_empty(), str(missing))
	check("spec/every_anchor_is_a_ground_contact", ground.is_empty(), str(ground))
	check("spec/every_target_height_is_metres_inside_the_built_band", heights.is_empty(), str(heights))
	check("spec/repeat_count_and_spread_agree", repeats_bad.is_empty(), str(repeats_bad))
	check("spec/every_repeat_run_stays_inside_the_authored_half_span", run_wide.is_empty(), str(run_wide))
	check("spec/every_slot_carries_a_footprint_note", notes_bad.is_empty(), str(notes_bad))
	check("spec/every_footprint_clears_the_field_law_plane_z_minus_8", law.is_empty(), str(law))
	check("spec/every_footprint_clears_the_measured_glass_plane", glass.is_empty(), str(glass))
	check("spec/every_footprint_fits_the_depth_budget", budget.is_empty(), str(budget))
	check("spec/suppress_is_on_exactly_where_a_slot_has_a_procedural_counterpart (%d slots)" % suppress_expected.size(),
		suppress_wrong.is_empty(), str(suppress_wrong))
	check("spec/every_suppress_target_is_a_real_prop_kind", kinds_bad.is_empty(), str(kinds_bad))


# --- 2. the disk state, and what it changes about the rest of the run ------

## What is on disk right now: the empty-kit state (the pre-kit build, unchanged) or the
## kitted state (real GLBs mounted, suppression live). Both are legitimate; the suite
## says which one it is measuring and then holds the kit to the same claims.
func _disk_state() -> void:
	var on_disk := _glb_files_under_kits()
	print("# disk state: %d GLB file(s) under godot/assets/arenas/ -> %s" % [
		on_disk.size(), "EMPTY KIT" if on_disk.is_empty() else "KITTED"])
	var problems: Array[String] = []
	for arena_id in ARENAS:
		var report := ArenaKit.slot_report(arena_id)
		if report.size() != ArenaKit.slots().size():
			problems.append("%s: %d rows" % [arena_id, report.size()])
			continue
		for i in report.size():
			var row: Dictionary = report[i]
			var slot := String(row["slot"])
			if slot != String(ArenaKit.slots()[i]):
				problems.append("%s: row %d is %s" % [arena_id, i, slot])
			if String(row["path"]) != _slot_res_path(arena_id, slot):
				problems.append("%s/%s path=%s" % [arena_id, slot, row["path"]])
			if Vector3(row["anchor"]) != ArenaKit.anchor_at(arena_id, slot):
				problems.append("%s/%s anchor=%s" % [arena_id, slot, str(row["anchor"])])
			var want := "loaded" if bool(row["present"]) else "procedural"
			if String(row["status"]) != want:
				problems.append("%s/%s status=%s present=%s" % [arena_id, slot, row["status"], row["present"]])
	check("state/slot_report_lists_all_ten_slots_in_order_with_their_path_and_status", problems.is_empty(), str(problems))
	var inconsistent: Array[String] = []
	for arena_id in ARENAS:
		var any_present := false
		for slot in ArenaKit.slots():
			if ArenaKit.glb_exists(ArenaKit.slot_path(arena_id, String(slot))):
				any_present = true
		if ArenaKit.has_kit(arena_id) != any_present:
			inconsistent.append("%s has_kit=%s any_file=%s" % [arena_id, str(ArenaKit.has_kit(arena_id)), str(any_present)])
	check("state/has_kit_agrees_with_the_files_on_disk", inconsistent.is_empty(), str(inconsistent))


# --- 3. the additive proof, against the recorded baseline ------------------

func _regression() -> void:
	var baseline := _read_baseline()
	check("regression/the_recorded_baseline_is_readable (%s)" % BASELINE_PATH, not baseline.is_empty(),
		"missing or unparsable — record it with run/tmp/arena-kit/baseline_probe.gd")
	if baseline.is_empty():
		return
	var arenas: Dictionary = baseline.get("arenas", {})
	var mismatch: Array[String] = []
	var lines_bad: Array[String] = []
	var counts: Array[String] = []
	var nondeterministic: Array[String] = []
	var field_law: Array[String] = []
	var kit_state: Array[String] = []
	var empty_disk := _glb_files_under_kits().is_empty()
	# Suppression OFF: the additive default, which is the state the baseline was recorded
	# in. The kit is then purely additive by construction, so the tree with `Kit` skipped
	# must be the recorded tree, byte for byte.
	ArenaKit.suppress_overrides = _all_suppress(false)
	for arena_id in ARENAS:
		var built := Arena.build(arena_id, "default")
		var digest := _digest_arena_excluding_kit(built)
		var want: Dictionary = arenas.get(arena_id, {})
		var kit := _kit_node(built)
		var kit_meshes := 0 if kit == null else kit.find_children("*", "MeshInstance3D", true, false).size()
		if digest["sha256"] != String(want.get("sha256", "")):
			mismatch.append("%s %s != %s" % [arena_id, String(digest["sha256"]).substr(0, 12),
				String(want.get("sha256", "")).substr(0, 12)])
		if int(digest["lines"]) != int(want.get("lines", -1)):
			lines_bad.append("%s lines=%d/%d" % [arena_id, int(digest["lines"]), int(want.get("lines", -1))])
		if int(digest["meshes"]) != int(want.get("meshes", -1)) \
				or int(digest["dressing"]) != int(want.get("dressing", -1)) \
				or int(digest["scenery_meshes"]) != int(want.get("scenery_meshes", -1)):
			counts.append("%s meshes=%d/%d scenery=%d/%d dressing=%d/%d" % [arena_id, int(digest["meshes"]),
				int(want.get("meshes", -1)), int(digest["scenery_meshes"]), int(want.get("scenery_meshes", -1)),
				int(digest["dressing"]), int(want.get("dressing", -1))])
		# The kit is the ONLY thing the tree gained: its own meshes are the whole difference.
		var grown := built.find_children("*", "MeshInstance3D", true, false).size() - int(want.get("meshes", -1))
		if grown != kit_meshes:
			kit_state.append("%s grew %d mesh(es) but the Kit subtree holds %d" % [arena_id, grown, kit_meshes])
		# With no GLB anywhere the Kit node must not exist at all (the empty-kit path).
		if empty_disk and kit != null:
			kit_state.append("%s grew a Kit node with no GLB" % arena_id)
		var law := ArenaScenery.field_law_report(built)
		if not law.is_empty():
			field_law.append("%s: %s" % [arena_id, str(law)])
		# The digest must also be stable within the run (a second build, same answer):
		# otherwise the baseline comparison itself would be measuring noise.
		var rebuilt := Arena.build(arena_id, "default")
		if _digest_arena(rebuilt)["sha256"] != _digest_arena(built)["sha256"]:
			nondeterministic.append(arena_id)
		built.free()
		rebuilt.free()
	ArenaKit.suppress_overrides = {}
	check("regression/with_suppression_off_every_arena_digest_equals_the_recorded_baseline",
		mismatch.is_empty(), str(mismatch))
	check("regression/the_digest_walk_records_the_recorded_line_count", lines_bad.is_empty(), str(lines_bad))
	check("regression/mesh_scenery_and_dressing_counts_are_unchanged_once_the_kit_is_subtracted",
		counts.is_empty(), str(counts))
	check("regression/the_digest_is_deterministic_inside_the_run", nondeterministic.is_empty(), str(nondeterministic))
	check("regression/new_geometry_in_the_tree_is_exactly_the_kit_subtree", kit_state.is_empty(), str(kit_state))
	check("regression/the_field_law_still_holds", field_law.is_empty(), str(field_law))


# --- 4. the mount contract on whatever is on disk --------------------------

func _mount_contract() -> void:
	var present_slots := 0
	var absent_slots := 0
	var missing_node: Array[String] = []
	var anchor_bad: Array[String] = []
	var name_bad: Array[String] = []
	var asset_bad: Array[String] = []
	var count_bad: Array[String] = []
	var placement_bad: Array[String] = []
	var size_bad: Array[String] = []
	var origin_bad: Array[String] = []
	var centre_bad: Array[String] = []
	var spec_depth_bad: Array[String] = []
	var glass_bad: Array[String] = []
	var frame_bad: Array[String] = []
	var screen_bad: Array[String] = []
	var screen_row_bad: Array[String] = []
	var preset_bad: Array[String] = []
	var hover_bad: Array[String] = []
	var material_bad: Array[String] = []
	var asset_class_bad: Array[String] = []
	var law_bad: Array[String] = []
	for arena_id in ARENAS:
		var holder := Node3D.new()
		root.add_child(holder)
		var cam := Court.build_camera(holder, PRESET)
		var built := Arena.build_into(holder, arena_id, PRESET)
		var viewport := Vector2(root.get_visible_rect().size)
		var law := ArenaScenery.field_law_report(built)
		if not law.is_empty():
			law_bad.append("%s: %s" % [arena_id, str(law)])
		for slot_in in ArenaKit.slots():
			var slot := String(slot_in)
			var entry := ArenaKit.spec(arena_id, slot)
			var res_path := _slot_res_path(arena_id, slot)
			var has_file := ArenaKit.glb_exists(res_path)
			var slot_node := built.get_node_or_null("Scenery/Kit/Slot_%s" % slot) as Node3D
			if not has_file:
				absent_slots += 1
				if slot_node != null:
					missing_node.append("%s/%s mounted with no file" % [arena_id, slot])
				continue
			present_slots += 1
			if slot_node == null:
				missing_node.append("%s/%s not mounted" % [arena_id, slot])
				continue
			if String(slot_node.name) != "Slot_%s" % slot:
				name_bad.append("%s/%s named %s" % [arena_id, slot, String(slot_node.name)])
			if String(slot_node.get_meta("asset", "")) != res_path:
				asset_bad.append("%s/%s asset=%s" % [arena_id, slot, String(slot_node.get_meta("asset", ""))])
			var want_anchor := ArenaKit.anchor_at(arena_id, slot, _x_scale(PRESET))
			if slot_node.position.distance_to(want_anchor) > 0.0001:
				anchor_bad.append("%s/%s %s want %s" % [arena_id, slot, str(slot_node.position), str(want_anchor)])
			var repeats := int(entry["repeats"])
			var spread := float(entry["spread"]) * _x_scale(PRESET)
			var pieces := _piece_nodes(slot_node)
			if pieces.size() != repeats:
				count_bad.append("%s/%s %d pieces want %d" % [arena_id, slot, pieces.size(), repeats])
			for i in pieces.size():
				var piece: Node3D = pieces[i]
				var where := "%s/%s/%s" % [arena_id, slot, String(piece.name)]
				var want_x := (float(i) - float(repeats - 1) * 0.5) * spread
				if absf(piece.position.x - want_x) > 0.0001:
					placement_bad.append("%s x=%.3f want %.3f" % [where, piece.position.x, want_x])
				# The measured box of what is actually mounted, in the SLOT's own frame
				# (the kit's `node_bounds()` applies the node's own transform), moved into
				# the arena frame by the slot's anchor — the frame every law is written in.
				var box := ArenaKit.node_bounds(piece)
				var arena_box := AABB(box.position + slot_node.position, box.size)
				if absf(float(arena_box.size.y) - float(entry["target_h"])) > HEIGHT_TOLERANCE:
					size_bad.append("%s h=%.4f want %.2f" % [where, arena_box.size.y, float(entry["target_h"])])
				# SPEC HONEST (fit pass): the declared depth IS the measured mesh depth, so
				# the spec table, the 2D plan and the art describe one object. 2 dp.
				if absf(float(arena_box.size.z) - float(entry["depth"])) > 0.005:
					spec_depth_bad.append("%s measured d=%.4f declared %.2f" % [where, arena_box.size.z, float(entry["depth"])])
				# Bottom origin and z-centring are exact by construction: `_place_piece()`
				# puts the measured box's bottom on the wrapper's origin and the box's z
				# centre there too, and `mount_slot()` puts the wrapper on the declared
				# repeat offset. The box's X centre carries the SOURCE MODEL's own x
				# asymmetry on top of that offset — measured here, never assumed away.
				if absf(float(arena_box.position.y)) > 0.001 \
						or absf(float(arena_box.position.z + arena_box.size.z * 0.5) - want_anchor.z) > 0.001:
					origin_bad.append("%s box=%s anchor z=%.3f" % [where, str(arena_box), want_anchor.z])
				var want_centre_x := want_anchor.x + want_x
				var x_drift := float(arena_box.position.x + arena_box.size.x * 0.5) - want_centre_x
				if absf(x_drift) > 0.10:
					centre_bad.append("%s centre x=%.3f want %.3f (drift %+.3f m, the model's own x asymmetry)" % [
						where, arena_box.position.x + arena_box.size.x * 0.5, want_centre_x, x_drift])
				var front := float(arena_box.position.z + arena_box.size.z)
				if front > ArenaKit.GLASS_PLANE_Z:
					glass_bad.append("%s front z=%.3f" % [where, front])
				if float(arena_box.size.z) > ArenaKit.DEPTH_BUDGET:
					hover_bad.append("%s depth=%.3f (budget %.2f)" % [where, arena_box.size.z, ArenaKit.DEPTH_BUDGET])
				# The frame law is an AUTHORED-space law: a built arena multiplies authored x
				# by the running preset's own `x_scale` (1.3437 at "default"), so the gate
				# reads the extents back in authored metres and reports both.
				var auth_min := float(arena_box.position.x) / _x_scale(PRESET)
				var auth_max := float(arena_box.position.x + arena_box.size.x) / _x_scale(PRESET)
				if absf(auth_min) > ArenaKit.AUTHORED_HALF_X or absf(auth_max) > ArenaKit.AUTHORED_HALF_X:
					frame_bad.append("%s authored x=%.2f..%.2f (as built %.2f..%.2f)" % [
						where, auth_min, auth_max, arena_box.position.x, arena_box.position.x + arena_box.size.x])
				var crop := _screen_report(cam, viewport, arena_box)
				if not bool(crop["inside"]):
					screen_bad.append("%s margin=%.1fpx behind=%s" % [where, crop["margin"], str(crop["behind"])])
				if not bool(crop["above_baseline"]):
					screen_row_bad.append("%s row=%.1f baseline=%.1f" % [where, crop["lowest_row"], crop["baseline_row"]])
			_check_material_policy(slot_node, "%s/%s" % [arena_id, slot])
			_check_no_physics_or_light(slot_node, "%s/%s" % [arena_id, slot])
		root.remove_child(holder)
		holder.free()
		# The anchor follows the camera preset's own x_scale, like a Dressing_* container.
		var wide_holder := Node3D.new()
		root.add_child(wide_holder)
		var wide := Arena.build_into(wide_holder, arena_id, "wide")
		for slot_in in ArenaKit.slots():
			var slot := String(slot_in)
			if not ArenaKit.glb_exists(_slot_res_path(arena_id, slot)):
				continue
			var wide_slot := wide.get_node_or_null("Scenery/Kit/Slot_%s" % slot) as Node3D
			var want_wide := ArenaKit.anchor_at(arena_id, slot, _x_scale("wide"))
			if wide_slot == null or wide_slot.position.distance_to(want_wide) > 0.0001:
				preset_bad.append("%s/%s %s want %s" % [arena_id, slot,
					str(wide_slot.position) if wide_slot != null else "missing", str(want_wide)])
		root.remove_child(wide_holder)
		wide_holder.free()
	print("# mount contract: %d slot(s) with a file, %d without" % [present_slots, absent_slots])
	check("mount/slot_report_marks_the_same_slots_loaded_as_have_a_file",
		_loaded_slots_match_disk(), "see the per-slot status lines in the state section")
	check("mount/every_slot_with_a_file_is_mounted_and_none_without_one", missing_node.is_empty(), str(missing_node))
	check("mount/every_mounted_slot_is_named_Slot_<slot>", name_bad.is_empty(), str(name_bad))
	check("mount/every_mounted_slot_records_its_asset_path", asset_bad.is_empty(), str(asset_bad))
	check("mount/every_mounted_slot_stands_at_its_spec_anchor", anchor_bad.is_empty(), str(anchor_bad))
	check("mount/the_declared_repeat_count_is_mounted", count_bad.is_empty(), str(count_bad))
	check("mount/every_repeat_is_placed_on_the_declared_spread", placement_bad.is_empty(), str(placement_bad))
	check("mount/every_piece_measures_the_spec_target_height", size_bad.is_empty(), str(size_bad))
	check("mount/every_piece_is_bottom_origin_and_z_centred_on_its_slot_anchor", origin_bad.is_empty(), str(origin_bad))
	check("mount/every_declared_depth_is_the_measured_mesh_depth (spec honest, 2 dp)",
		spec_depth_bad.is_empty(), str(spec_depth_bad))
	check("mount/every_mounted_box_sits_on_its_repeat_offset (x centre within 0.10 m of the plan)",
		centre_bad.is_empty(), str(centre_bad))
	check("mount/every_piece_fits_the_depth_budget", hover_bad.is_empty(), str(hover_bad))
	check("mount/every_piece_stays_behind_the_measured_glass_plane", glass_bad.is_empty(), str(glass_bad))
	check("mount/every_piece_stays_inside_the_authored_half_span", frame_bad.is_empty(), str(frame_bad))
	check("mount/no_mounted_piece_is_half_cropped_by_the_default_camera", screen_bad.is_empty(), str(screen_bad))
	check("mount/no_mounted_piece_covers_the_court (all above the rear baseline's own screen row)",
		screen_row_bad.is_empty(), str(screen_row_bad))
	check("mount/a_built_arena_keeps_the_field_law_with_the_kit_mounted", law_bad.is_empty(), str(law_bad))
	check("mount/under_another_camera_preset_the_anchor_follows_the_presets_x_scale",
		preset_bad.is_empty(), str(preset_bad))
	if present_slots == 0:
		note("no GLB on disk: the mount contract above is vacuous this run (empty-kit state)")


func _loaded_slots_match_disk() -> bool:
	var bad: Array[String] = []
	for arena_id in ARENAS:
		for row in ArenaKit.slot_report(arena_id):
			var present := bool(row["present"])
			if bool(row["present"]) != ArenaKit.glb_exists(String(row["path"])):
				bad.append("%s/%s" % [arena_id, row["slot"]])
	return bad.is_empty()


# --- 4b. the fixture drops (only into a FREE slot) -------------------------

func _fixtures() -> void:
	var tiny_free := not FileAccess.file_exists(_slot_abs_path(FIXTURE_ARENA, TINY_SLOT))
	var repo_free := not FileAccess.file_exists(_slot_abs_path(FIXTURE_ARENA, REPO_SLOT))
	if not tiny_free:
		note("fixture/ the tiny-prop drop is skipped: %s/%s holds a real asset" % [FIXTURE_ARENA, TINY_SLOT])
	if not repo_free:
		note("fixture/ the repo-GLB drop is skipped: %s/%s holds a real asset" % [FIXTURE_ARENA, REPO_SLOT])
	if tiny_free:
		_fixture_tiny()
	if repo_free:
		_fixture_repo_glb()


func _fixture_tiny() -> void:
	var src := _abs(TINY_FIXTURE)
	check("fixture/tiny_prop_fixture_exists (%s)" % TINY_FIXTURE, FileAccess.file_exists(src), src)
	if not FileAccess.file_exists(src):
		return
	var dst := _slot_abs_path(FIXTURE_ARENA, TINY_SLOT)
	_make_dir(dst.get_base_dir())
	check_eq("fixture/copy_the_tiny_glb_into_the_slot_path", DirAccess.copy_absolute(src, dst), OK)
	staged.append(dst)
	check("fixture/the_kit_sees_the_drop (has_kit)",
		ArenaKit.has_kit(FIXTURE_ARENA) and ArenaKit.has_kit(FIXTURE_ARENA, TINY_SLOT), "has_kit false")
	var report := ArenaKit.slot_report(FIXTURE_ARENA)
	var loaded: Array[String] = []
	for row in report:
		if String(row["status"]) == "loaded":
			loaded.append(String(row["slot"]))
	check_eq("fixture/only_the_slot_with_the_file_reports_loaded", loaded, [TINY_SLOT])

	# Focused mount first (a throwaway holder), so the placement numbers are read without
	# the court around them.
	var holder := Node3D.new()
	root.add_child(holder)
	var slot_node := ArenaKit.mount_slot(holder, FIXTURE_ARENA, TINY_SLOT, {"x_scale": _x_scale(PRESET)})
	check("fixture/mount_slot_returns_the_slot_node", slot_node != null, "null")
	if slot_node != null:
		var want_anchor := ArenaKit.anchor_at(FIXTURE_ARENA, TINY_SLOT, _x_scale(PRESET))
		check_eq("fixture/the_slot_node_is_named_Slot_<slot>", String(slot_node.name), "Slot_%s" % TINY_SLOT)
		check("fixture/the_slot_node_sits_at_the_spec_anchor",
			slot_node.position.distance_to(want_anchor) < 0.0001,
			"%s want %s" % [str(slot_node.position), str(want_anchor)])
		check_eq("fixture/the_slot_node_records_its_asset_path", String(slot_node.get_meta("asset")),
			_slot_res_path(FIXTURE_ARENA, TINY_SLOT))
		var spec := ArenaKit.spec(FIXTURE_ARENA, TINY_SLOT)
		var repeats := int(spec["repeats"])
		var spread := float(spec["spread"]) * _x_scale(PRESET)
		var pieces := _piece_nodes(slot_node)
		check_eq("fixture/the_declared_repeat_count_is_mounted", pieces.size(), repeats)
		var placement_bad: Array[String] = []
		var size_bad: Array[String] = []
		var origin_bad: Array[String] = []
		for i in pieces.size():
			var piece: Node3D = pieces[i]
			var want_x := (float(i) - float(repeats - 1) * 0.5) * spread
			if absf(piece.position.x - want_x) > 0.0001:
				placement_bad.append("piece %d x=%.3f want %.3f" % [i + 1, piece.position.x, want_x])
			# The measured box of what is actually mounted, in the SLOT's own frame (the
			# kit's `node_bounds()` applies the node's own transform): the tiny box is
			# 0.50 m tall, so the scale must be target_h / 0.50 and the bottom must sit on
			# the anchor (bottom origin).
			var box := ArenaKit.node_bounds(piece)
			if absf(float(box.size.y) - float(spec["target_h"])) > HEIGHT_TOLERANCE:
				size_bad.append("piece %d h=%.4f want %.2f" % [i + 1, box.size.y, float(spec["target_h"])])
			if absf(float(box.position.y)) > 0.001 or absf(float(box.position.x + box.size.x * 0.5) - want_x) > 0.001:
				origin_bad.append("piece %d box=%s want x=%.3f" % [i + 1, str(box), want_x])
		check("fixture/every_repeat_is_placed_on_the_declared_spread", placement_bad.is_empty(), str(placement_bad))
		check("fixture/every_piece_measures_the_spec_target_height", size_bad.is_empty(), str(size_bad))
		check("fixture/every_piece_is_bottom_origin_and_x_centred_on_its_anchor", origin_bad.is_empty(), str(origin_bad))
		check("fixture/the_scale_is_exactly_target_height_over_the_source_box (0.50 m fixture)",
			pieces.size() > 0 and is_equal_approx((pieces[0] as Node3D).scale.x, float(spec["target_h"]) / 0.5),
			str((pieces[0] as Node3D).scale if pieces.size() > 0 else "no piece"))
		_check_material_policy(slot_node, "fixture")
		_check_no_physics_or_light(slot_node, "fixture")
		var glass_bad: Array[String] = []
		for piece in pieces:
			var box: AABB = ArenaKit.node_bounds(piece)
			var front := slot_node.position.z + box.position.z + box.size.z
			if front > ArenaKit.GLASS_PLANE_Z:
				glass_bad.append("%s front z=%.3f" % [String((piece as Node3D).name), front])
		check("fixture/the_mounted_geometry_stays_behind_the_measured_glass_plane", glass_bad.is_empty(), str(glass_bad))
	root.remove_child(holder)
	holder.free()

	# Then the real path: the arena build itself carries the slot, and the preset scaling
	# follows the camera like the props do.
	var built := Arena.build(FIXTURE_ARENA, PRESET)
	var kit := built.get_node_or_null("Scenery/Kit")
	check("fixture/a_built_arena_carries_Scenery/Kit", kit != null, "no Kit node")
	check("fixture/the_built_arena_has_Kit/Slot_%s" % TINY_SLOT,
		built.get_node_or_null("Scenery/Kit/Slot_%s" % TINY_SLOT) != null, "missing")
	var law := ArenaScenery.field_law_report(built)
	check("fixture/the_field_law_still_holds_with_a_glb_mounted", law.is_empty(), str(law))
	built.free()


func _fixture_repo_glb() -> void:
	var src := ProjectSettings.globalize_path(REPO_GLB)
	check("repo_glb/the_repo_fixture_exists (%s)" % REPO_GLB, FileAccess.file_exists(src), src)
	if not FileAccess.file_exists(src):
		return
	check_eq("repo_glb/the_fixture_is_the_size_the_repo_states (%d bytes)" % REPO_GLB_BYTES,
		int(FileAccess.get_file_as_bytes(src).size()), REPO_GLB_BYTES)
	var dst := _slot_abs_path(FIXTURE_ARENA, REPO_SLOT)
	_make_dir(dst.get_base_dir())
	check_eq("repo_glb/copy_the_volpe_glb_into_the_slot_path", DirAccess.copy_absolute(src, dst), OK)
	staged.append(dst)
	var built := Arena.build(FIXTURE_ARENA, PRESET)
	var slot_node := built.get_node_or_null("Scenery/Kit/Slot_%s" % REPO_SLOT) as Node3D
	check("repo_glb/a_real_repo_glb_mounts_as_Kit/Slot_%s" % REPO_SLOT, slot_node != null, "missing")
	if slot_node != null:
		var spec := ArenaKit.spec(FIXTURE_ARENA, REPO_SLOT)
		var want := ArenaKit.anchor_at(FIXTURE_ARENA, REPO_SLOT, _x_scale(PRESET))
		check("repo_glb/it_stands_at_the_spec_anchor",
			slot_node.position.distance_to(want) < 0.0001,
			"%s want %s" % [str(slot_node.position), str(want)])
		var pieces := _piece_nodes(slot_node)
		check_eq("repo_glb/one_piece_for_a_single_instance_slot", pieces.size(), 1)
		if not pieces.is_empty():
			var piece: Node3D = pieces[0]
			var box := ArenaKit.node_bounds(piece)
			var source_h := box.size.y / maxf(piece.scale.y, 0.0001)
			print("INFO repo_glb measured box=%s scale=%.4f source_h=%.4f m" % [str(box.size), piece.scale.y, source_h])
			# The athlete trap (`athlete_rig.gd:790-797`): measuring this GLB through its
			# own node chain reports ~0.018 m. The kit must read it in metres.
			check("repo_glb/the_skinned_source_is_measured_in_metres_not_centimetres",
				source_h > 0.5 and source_h < 3.0, "source height %.4f m" % source_h)
			check("repo_glb/the_scale_is_target_height_over_the_measured_source",
				is_equal_approx(piece.scale.y, float(spec["target_h"]) / source_h),
				"scale %.4f want %.4f" % [piece.scale.y, float(spec["target_h"]) / source_h])
			check("repo_glb/the_mounted_box_measures_the_spec_target_height (%.2f m)" % float(spec["target_h"]),
				absf(float(box.size.y) - float(spec["target_h"])) / float(spec["target_h"]) < HEIGHT_TOLERANCE,
				"h=%.4f" % box.size.y)
			check("repo_glb/it_is_bottom_origin_on_the_anchor",
				absf(float(box.position.y)) < float(spec["target_h"]) * HEIGHT_TOLERANCE,
				"box min y=%.4f" % box.position.y)
			var front := slot_node.position.z + box.position.z + box.size.z
			check("repo_glb/the_mounted_geometry_stays_behind_the_measured_glass_plane",
				front <= ArenaKit.GLASS_PLANE_Z, "front z=%.3f" % front)
		_check_material_policy(slot_node, "repo_glb")
		_check_no_physics_or_light(slot_node, "repo_glb")
	var law := ArenaScenery.field_law_report(built)
	check("repo_glb/the_field_law_still_holds", law.is_empty(), str(law))
	built.free()


# --- 5. suppression: exactly the slots that double, and nothing else -------

func _suppression() -> void:
	# The doubling set, derived from the table AND the disk: a slot with a procedural
	# counterpart (`kinds` non-empty) and a GLB standing in it.
	var expect := {}
	var expect_by_arena := {}
	var no_counterpart: Array[String] = []
	for arena_id in ARENAS:
		var kinds_sum: Array = []
		for slot_in in ArenaKit.slots():
			var slot := String(slot_in)
			var entry := ArenaKit.spec(arena_id, slot)
			var kinds: Array = entry.get("kinds", [])
			if not ArenaKit.glb_exists(_slot_res_path(arena_id, slot)):
				continue
			if kinds.is_empty():
				no_counterpart.append("%s/%s" % [arena_id, slot])
				continue
			expect["%s/%s" % [arena_id, slot]] = true
			for kind in kinds:
				if not kinds_sum.has(String(kind)):
					kinds_sum.append(String(kind))
		expect_by_arena[arena_id] = kinds_sum
	print("# suppression: %d slot(s) stand over a procedural counterpart, %d slot(s) have none (kinds [])" % [
		expect.size(), no_counterpart.size()])
	if expect.is_empty():
		note("no GLB on disk: nothing can double, so the suppression contract is measured in its empty form only")
	var wrong: Array[String] = []
	var kinds_wrong: Array[String] = []
	var overrides_wrong: Array[String] = []
	for arena_id in ARENAS:
		var got := ArenaKit.suppressed_kinds(arena_id)
		var want: Array = expect_by_arena[arena_id]
		# A slot with `kinds: []` must never suppress anything, even forced on.
		var forced_on := _all_suppress(true)
		ArenaKit.suppress_overrides = forced_on
		var forced := ArenaKit.suppressed_kinds(arena_id)
		ArenaKit.suppress_overrides = {}
		for kind in forced:
			if not want.has(kind):
				overrides_wrong.append("%s forced-on suppressed '%s' with no counterpart" % [arena_id, kind])
		for kind in want:
			if not got.has(kind):
				wrong.append("%s is missing kind '%s'" % [arena_id, kind])
		for kind in got:
			if not want.has(kind):
				wrong.append("%s suppresses '%s' without a slot standing over it" % [arena_id, kind])
		if got.size() != want.size():
			kinds_wrong.append("%s %s want %s" % [arena_id, str(got), str(want)])
	check("suppress/every_slot_that_doubles_is_covered (kind for kind, per arena)", wrong.is_empty(), str(wrong))
	check("suppress/the_suppressed_kind_lists_are_exactly_the_expected_ones", kinds_wrong.is_empty(), str(kinds_wrong))
	check("suppress/a_slot_with_no_procedural_counterpart_never_suppresses (kinds [])",
		overrides_wrong.is_empty(), str(overrides_wrong))

	# Two builds per arena: the table as it ships, and the same table forced OFF. Measured
	# per kind, so "the procedural prop is gone and nothing else moved" is a number.
	var off_problems: Array[String] = []
	var on_problems: Array[String] = []
	var container_problems: Array[String] = []
	for arena_id in ARENAS:
		var authored := (ArenaStyle.style(arena_id).get("props", []) as Array).size()
		ArenaKit.suppress_overrides = {}
		var with_table := Arena.build(arena_id, PRESET)
		ArenaKit.suppress_overrides = _all_suppress(false)
		var forced_off := Arena.build(arena_id, PRESET)
		ArenaKit.suppress_overrides = {}
		var kinds_all: Array = []
		for prop in (ArenaStyle.style(arena_id).get("props", []) as Array):
			var kind := String((prop as Dictionary).get("kind", ""))
			if not kinds_all.has(kind):
				kinds_all.append(kind)
		var suppressed: Array = expect_by_arena[arena_id]
		for kind in kinds_all:
			var on_meshes := _meshes_of_kind(with_table, String(kind)).size()
			var off_meshes := _meshes_of_kind(forced_off, String(kind)).size()
			if suppressed.has(String(kind)):
				if off_meshes == 0:
					off_problems.append("%s/%s has no procedural geometry to suppress" % [arena_id, kind])
				if on_meshes != 0:
					on_problems.append("%s/%s still holds %d procedural mesh(es)" % [arena_id, kind, on_meshes])
			elif on_meshes != off_meshes:
				on_problems.append("%s/%s moved without being suppressed (%d vs %d)" % [arena_id, kind, on_meshes, off_meshes])
		# The container invariant the frozen suites pin, in both states.
		var dressing_on := _dressing_count(with_table)
		var dressing_off := _dressing_count(forced_off)
		if dressing_on != authored or dressing_off != authored:
			container_problems.append("%s dressing=%d/%d authored=%d" % [arena_id, dressing_on, dressing_off, authored])
		# The kit itself is mounted in both builds: suppression never unmounts a slot.
		var kit_slots := _kit_node(with_table)
		if expect.size() > 0 and kit_slots == null:
			container_problems.append("%s lost its Kit node under suppression" % arena_id)
		with_table.free()
		forced_off.free()
	check("suppress/the_procedural_prop_is_still_built_when_the_flag_is_off", off_problems.is_empty(), str(off_problems))
	check("suppress/with_the_table_in_force_only_the_suppressed_kinds_lose_their_geometry",
		on_problems.is_empty(), str(on_problems))
	check("suppress/one_Dressing_container_per_authored_prop_in_both_states",
		container_problems.is_empty(), str(container_problems))
	check("suppress/the_override_clears_back_to_the_frozen_table",
		ArenaKit.suppress_overrides.is_empty(), str(ArenaKit.suppress_overrides))


# --- 6. cleanup: nothing staged is left, and nothing else was touched ------

func _cleanup() -> void:
	var removed: Array[String] = []
	for path in staged:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
			removed.append(path)
	check("clean/every_staged_fixture_is_removed (%d)" % staged.size(), removed.size() == staged.size(),
		"staged=%s removed=%s" % [str(staged), str(removed)])
	var after := _glb_fingerprint()
	var changed: Array[String] = []
	for path in fingerprint_before:
		if not after.has(path) or after[path] != fingerprint_before[path]:
			changed.append("%s (%s -> %s)" % [path, str(fingerprint_before[path]), str(after.get(path, "gone"))])
	for path in after:
		if not fingerprint_before.has(path):
			changed.append("%s (new, %s bytes)" % [path, str(after[path])])
	check("clean/the_on_disk_glb_set_is_exactly_what_the_run_found (%d files)" % fingerprint_before.size(),
		changed.is_empty(), str(changed))
	var recheck: Array[String] = []
	for arena_id in ARENAS:
		for row in ArenaKit.slot_report(arena_id):
			var want := "loaded" if bool(row["present"]) else "procedural"
			if String(row["status"]) != want:
				recheck.append("%s/%s status=%s" % [arena_id, row["slot"], row["status"]])
	check("clean/every_slot_report_is_back_to_the_state_the_run_found", recheck.is_empty(), str(recheck))
	var contracts: Array[String] = []
	for arena_id in ARENAS:
		var readme := "%s/assets/arenas/%s/README.md" % [_project_dir(), arena_id]
		if not FileAccess.file_exists(readme):
			contracts.append(readme)
	check("clean/the_per_arena_drop_folders_and_their_readmes_survive", contracts.is_empty(), str(contracts))


# --- checks shared by the fixture and mount sections -----------------------

func _check_material_policy(slot_node: Node3D, prefix: String) -> void:
	var wrong: Array[String] = []
	var instances := {}
	var per_surface := {}
	var source_surfaces := 0
	var kept_colours := 0
	var shared_bad: Array[String] = []
	for mi in slot_node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := (mi as MeshInstance3D).get_surface_override_material(s) as StandardMaterial3D
			var where := "%s/%d" % [String((mi as MeshInstance3D).name), s]
			if mat == null:
				wrong.append("%s has no override material" % where)
				continue
			instances[mat.get_instance_id()] = true
			# One material per (file, surface), shared by the repeats: the same surface
			# index must never carry two different materials inside one slot.
			if per_surface.has(s) and int(per_surface[s]) != mat.get_instance_id():
				shared_bad.append("surface %d is not one shared material across the repeats" % s)
			per_surface[s] = mat.get_instance_id()
			if not is_zero_approx(mat.metallic) or not is_equal_approx(mat.roughness, 0.85) or mat.emission_enabled:
				wrong.append("%s metallic=%.2f roughness=%.2f emission=%s" % [
					where, mat.metallic, mat.roughness, str(mat.emission_enabled)])
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				wrong.append("%s is not opaque (transparency=%d)" % [where, mat.transparency])
			var src := mesh.surface_get_material(s) as StandardMaterial3D
			if src != null:
				source_surfaces += 1
				if mat.albedo_texture == src.albedo_texture and mat.albedo_color.is_equal_approx(src.albedo_color):
					kept_colours += 1
	check("%s/the_shared_material_policy_corrects_the_meshy_defaults" % prefix, wrong.is_empty(), str(wrong))
	check("%s/the_policy_keeps_each_models_own_colour (%d/%d surfaces)" % [prefix, kept_colours, source_surfaces],
		kept_colours == source_surfaces, "%d of %d kept" % [kept_colours, source_surfaces])
	check("%s/one_material_instance_per_surface_is_shared_across_the_repeats (%d materials well shared)"
		% [prefix, instances.size()], shared_bad.is_empty(), str(shared_bad))


func _check_no_physics_or_light(slot_node: Node3D, prefix: String) -> void:
	var offenders: Array[String] = []
	for node in [slot_node] + slot_node.find_children("*", "", true, false):
		for cls in ["CollisionObject3D", "CollisionShape3D", "Light3D", "Camera3D",
				"MultiMeshInstance3D", "CSGShape3D", "StaticBody3D", "RigidBody3D", "Area3D"]:
			if (node as Node).is_class(cls):
				offenders.append("%s:%s" % [String((node as Node).name), cls])
				break
	check("%s/no_collision_no_light_no_unmeasurable_asset_class_on_the_slot" % prefix,
		offenders.is_empty(), str(offenders))


# --- small helpers ---------------------------------------------------------

## Where an arena-frame box lands through the live camera: is it inside the frame, is any
## corner behind the camera, and does it stay above the rear baseline's own screen row
## (i.e. can it not cover the court from this camera)?
func _screen_report(cam: Camera3D, viewport: Vector2, arena_box: AABB) -> Dictionary:
	var inside := true
	var behind := false
	var margin := INF
	var lowest := -INF
	for i in 8:
		var corner: Vector3 = arena_box.get_endpoint(i)
		if cam.is_position_behind(corner):
			behind = true
			continue
		var px: Vector2 = cam.unproject_position(corner)
		margin = minf(margin, minf(minf(px.x, px.y), minf(viewport.x - px.x, viewport.y - px.y)))
		lowest = maxf(lowest, px.y)
	if margin < 0.0:
		inside = false
	var baseline: Vector2 = cam.unproject_position(
		Vector3(arena_box.position.x + arena_box.size.x * 0.5, 0.0, -10.0))
	return {"inside": inside and not behind, "behind": behind, "margin": margin,
		"lowest_row": lowest, "baseline_row": baseline.y, "above_baseline": lowest <= baseline.y + 0.5}


## The GLB files under `godot/assets/arenas/` (recursive) with their sizes — the drop-in
## state, fingerprinted so the suite can prove it left the assets exactly as it found them.
func _glb_fingerprint() -> Dictionary:
	var out := {}
	for path in _glb_files_under_kits():
		out[path] = FileAccess.get_file_as_bytes(path).size()
	return out


func _glb_files_under_kits() -> Array[String]:
	var out: Array[String] = []
	_walk_glbs("%s/assets/arenas" % _project_dir(), out)
	return out


func _walk_glbs(dir: String, out: Array[String]) -> void:
	var handle := DirAccess.open(dir)
	if handle == null:
		return
	for name in handle.get_files():
		if String(name).ends_with(".glb"):
			out.append("%s/%s" % [dir, name])
	for sub in handle.get_directories():
		_walk_glbs("%s/%s" % [dir, sub], out)


func _make_dir(abs_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)


func _read_baseline() -> Dictionary:
	var path := _abs(BASELINE_PATH)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## `{arena: {slot: flag}}` for every slot of every arena — the test seam, used here to
## measure the table against the additive default it replaced.
func _all_suppress(flag: bool) -> Dictionary:
	var out := {}
	for arena_id in ARENAS:
		var per_slot := {}
		for slot in ArenaKit.slots():
			per_slot[String(slot)] = flag
		out[arena_id] = per_slot
	return out


func _kit_node(built: Node3D) -> Node3D:
	return built.get_node_or_null("Scenery/Kit") as Node3D


func _piece_nodes(slot_node: Node3D) -> Array:
	var out: Array = []
	for child in slot_node.get_children():
		if String(child.name).begins_with("Piece"):
			out.append(child)
	return out


func _dressing_count(built: Node3D) -> int:
	var scenery := built.get_node_or_null("Scenery")
	if scenery == null:
		return -1
	var count := 0
	for child in scenery.get_children():
		if String(child.name).begins_with("Dressing_"):
			count += 1
	return count


func _containers_of_kind(built: Node3D, kind: String) -> Array:
	var out: Array = []
	for node in built.find_children("Dressing_*", "Node3D", true, false):
		if String(node.get_meta("kind", "")) == kind:
			out.append(node)
	return out


func _meshes_of_kind(built: Node3D, kind: String) -> Array:
	var out: Array = []
	for container in _containers_of_kind(built, kind):
		out.append_array((container as Node).find_children("*", "MeshInstance3D", true, false))
	return out


## The structural digest — COPIED VERBATIM from `run/tmp/arena-kit/baseline_probe.gd`,
## which recorded the baseline. Any change here invalidates the comparison, so the two
## must move together (the probe's header says the same). The one addition since the
## baseline was recorded is `_digest`'s optional `skip` argument, which defaults to
## skipping nothing: a walk with no skip is the recorded walk, to the line.
func _digest_arena(built: Node3D) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	_digest(built, lines)
	var scenery := built.get_node_or_null("Scenery")
	return {
		"sha256": "\n".join(lines).sha256_text(),
		"lines": lines.size(),
		"meshes": built.find_children("*", "MeshInstance3D", true, false).size(),
		"scenery_meshes": scenery.find_children("*", "MeshInstance3D", true, false).size() if scenery != null else 0,
		"dressing": _dressing_count(built),
	}


## The same digest with the `Kit` subtree walked OUT of it, and the counts corrected for
## the meshes that subtree holds. With suppression off the mounted kit is the only thing
## the tree gained, so this must equal the recorded baseline exactly — the empty-kit
## regression, restated for a drop folder that is full.
func _digest_arena_excluding_kit(built: Node3D) -> Dictionary:
	var kit := _kit_node(built)
	var lines: PackedStringArray = PackedStringArray()
	_digest(built, lines, 0, kit)
	var scenery := built.get_node_or_null("Scenery")
	var kit_meshes := 0 if kit == null else kit.find_children("*", "MeshInstance3D", true, false).size()
	return {
		"sha256": "\n".join(lines).sha256_text(),
		"lines": lines.size(),
		"meshes": built.find_children("*", "MeshInstance3D", true, false).size() - kit_meshes,
		"scenery_meshes": (scenery.find_children("*", "MeshInstance3D", true, false).size() if scenery != null else 0) - kit_meshes,
		"dressing": _dressing_count(built),
	}


func _digest(node: Node, out: PackedStringArray, depth := 0, skip: Node = null) -> void:
	if skip != null and node == skip:
		return
	out.append("%s%s|%s" % ["  ".repeat(depth), _node_name(node), node.get_class()])
	if node is Node3D:
		var n3 := node as Node3D
		out.append("%s xf %s %s %s" % [_v(n3.position), _v(n3.rotation_degrees), _v(n3.scale), _v(n3.transform.basis.get_scale())])
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			out.append("  mesh=null")
		else:
			var faces := mesh.get_faces().size()
			out.append("  mesh %s surfaces=%d face_verts=%d aabb=%s" % [
				mesh.get_class(), mesh.get_surface_count(), faces, str(mesh.get_aabb()),
			])
			for s in mesh.get_surface_count():
				out.append("    surface%d material=%s" % [
					s, String((mesh.surface_get_material(s) as Resource).resource_path) if mesh.surface_get_material(s) != null else "none",
				])
			if mesh is ArrayMesh:
				for s in mesh.get_surface_count():
					var len_s: int = mesh.surface_get_array_len(s)
					var verts: int = 0
					var arrays: Array = mesh.surface_get_arrays(s)
					if arrays.size() > Mesh.ARRAY_VERTEX:
						verts = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
					out.append("    arraymesh surface%d array_len=%d verts=%d" % [s, len_s, verts])
		var mo := mi.material_override as StandardMaterial3D
		if mo == null:
			out.append("  override=none")
		else:
			out.append("  override albedo=%s metallic=%.3f roughness=%.3f transparency=%d shading=%d visible=%s" % [
				str(mo.albedo_color), mo.metallic, mo.roughness, mo.transparency, mo.shading_mode, str(mi.visible),
			])
	for child in node.get_children():
		_digest(child, out, depth + 1, skip)


func _v(v: Vector3) -> String:
	return "(%.4f,%.4f,%.4f)" % [v.x, v.y, v.z]


## A node's recorded name, with Godot's process-local auto names masked (`@MeshInstance3D@2`):
## the counter depends on how many nodes the process created before, so recording it would
## make the digest a function of the process instead of the build. `baseline_probe.gd`
## masks it the same way — the two digests must stay identical.
func _node_name(node: Node) -> String:
	var name := String(node.name)
	return "<auto>" if name.begins_with("@") else name
