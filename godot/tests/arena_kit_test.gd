## arena_kit_test.gd — the arena-kit intake suite (KIT-STANDARD gate G3).
##
##   flock -w 900 /tmp/padel-godot.lock /Applications/Godot.app/Contents/MacOS/Godot \
##     --headless --path godot/ --script res://tests/arena_kit_test.gd
##
## WHAT IT PROVES, in four parts:
##
##   1. THE SPEC TABLE IS VALID AND FROZEN-SHAPED. `arena_kit.gd::SPECS` covers the five
##      world arenas x the ten frozen slots exactly (no missing slot, no extra one, the
##      standard's order); every slot names a unique slot id; every anchor is a ground
##      contact; every target height is metres and inside the built band; every footprint
##      note is there AND its declared depth fits the two planes a built arena is gated
##      on — the charter's field-law plane (z = -8.0) and the MEASURED rear glass plane
##      (z = -10.02, what `world_arenas_field_law_test.gd:194-209` fails on) — inside the
##      depth budget at the default prop z; every repeat run stays inside the authored
##      half-span; every `suppress` flag is OFF; every `kinds` entry is a real prop kind
##      of that arena.
##
##   2. THE EMPTY KIT IS THE PRE-KIT BUILD, BYTE FOR BYTE. `run/tmp/arena-kit/baseline.json`
##      is the digest recorded by `run/tmp/arena-kit/baseline_probe.gd` BEFORE the seam
##      existed (same digest function, copied here verbatim): per arena the SHA-256 of the
##      whole built tree — node names, classes, transforms, mesh classes/surface/face and
##      vertex counts, override material values — plus the mesh / `Dressing_*` / props
##      counts. This suite rebuilds the five arenas with no GLB anywhere and requires the
##      digests to be equal, and requires no `Kit` node to exist. A baseline file that is
##      missing is a FAILURE, never a silent pass: the gate is against a recorded number.
##
##   3. A GLB IN A SLOT MOUNTS AT ITS SPEC TRANSFORM AND SIZE. Two fixtures are dropped
##      one at a time and removed again:
##        * `tools/arena-kit/fixtures/tiny_prop.glb` — a hand-built STATIC 0.50 m box with
##          a deliberately wrong material (metallic 0.9 / roughness 0.2 / emission 1,1,1,
##          i.e. the Meshy defaults), so the scaling is exactly checkable (scale =
##          target_h / 0.50) and the shared material policy has something real to correct;
##        * `res://assets/athletes/volpe-rigged.glb` — a REAL repo GLB (the athlete
##          precedent), which is also the skinned case `athlete_rig.gd:790-797` warns
##          about: it must still mount, sized in metres, not 100x off.
##      Both are asserted present as `Scenery/Kit/Slot_<slot>` at the spec anchor
##      (including under a different camera preset, where x follows the preset's own
##      `x_scale` like a `Dressing_*` container), with the mounted geometry sized to
##      `target_h`, bottom-origin on the anchor, behind the measured glass plane, holding
##      its declared repeat count, with no collider and no light, and with the override
##      material shared between repeats.
##
##   4. THE FALLBACK COMES BACK, AND NOTHING IS LEFT BEHIND. Both fixtures are removed,
##      `godot/assets/arenas/` is required to hold no `.glb` again, the digest of all five
##      arenas must match the recorded baseline AGAIN, `has_kit()` must be false and every
##      slot report must say "procedural" — i.e. the empty path is not a one-way door.
##
## Suppression (default OFF, asserted above) is exercised here too, with the frozen table
## untouched: `ArenaKit.suppress_overrides` forces one slot on, and the build must then
## skip exactly that slot's procedural kind while still building the `Dressing_*`
## container, so the "one container per authored prop" invariant does not move.
##
## Machine-readable contract, same as the other suites: `ok <name>` / `FAIL <name>:
## expected …, got …` / `PASS n/n` | `FAIL n/n`, exit 0 on PASS, 1 on FAIL. A `SCRIPT
## ERROR` anywhere in the log is a failure even next to a green tally.
extends SceneTree

const ArenaKit := preload("res://game/arenas/arena_kit.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaScenery := preload("res://game/arenas/arena_scenery.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")

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

var checks := 0
var failures := 0
var fail_lines: Array[String] = []
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


func verdict() -> void:
	if failures == 0:
		print("PASS %d/%d" % [checks, checks])
	else:
		print("FAIL %d/%d first=%s" % [checks - failures, checks,
			fail_lines[0] if not fail_lines.is_empty() else ""])


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
	_spec_table()
	_precheck()
	_empty_kit_regression()
	_fixture_tiny()
	_fixture_repo_glb()
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
	var notes: Array[String] = []
	var law: Array[String] = []
	var glass: Array[String] = []
	var budget: Array[String] = []
	var suppress_on: Array[String] = []
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
			if not is_equal_approx(anchor.y, 0.0):
				ground.append("%s y=%.3f" % [where, anchor.y])
			if target_h <= 0.0 or anchor.y + target_h > band_top + 0.0001:
				heights.append("%s h=%.2f (band top %.2f)" % [where, target_h, band_top])
			if repeats < 1 or (repeats == 1 and not is_zero_approx(spread)) or (repeats > 1 and spread <= 0.0):
				repeats_bad.append("%s repeats=%d spread=%.2f" % [where, repeats, spread])
			if absf(anchor.x) + float(repeats - 1) * 0.5 * spread > ArenaKit.AUTHORED_HALF_X:
				run_wide.append("%s x=%.2f run=%.2f" % [where, anchor.x, float(repeats - 1) * spread])
			if String(entry.get("footprint", "")).length() < 24:
				notes.append("%s note=%s" % [where, String(entry.get("footprint", ""))])
			if anchor.z + depth * 0.5 > ArenaScenery.FIELD_LAW_Z:
				law.append("%s front=%.2f" % [where, anchor.z + depth * 0.5])
			if anchor.z + depth * 0.5 > ArenaKit.GLASS_PLANE_Z:
				glass.append("%s front=%.2f (glass %.2f)" % [where, anchor.z + depth * 0.5, ArenaKit.GLASS_PLANE_Z])
			if depth <= 0.0 or depth > ArenaKit.DEPTH_BUDGET:
				budget.append("%s depth=%.2f (budget %.2f)" % [where, depth, ArenaKit.DEPTH_BUDGET])
			if bool(entry.get("suppress", false)):
				suppress_on.append(where)
			for kind in (entry.get("kinds", []) as Array):
				if not prop_kinds.has(String(kind)):
					kinds_bad.append("%s kind=%s" % [where, kind])
	check("spec/every_arena_carries_exactly_the_ten_frozen_slots", missing.is_empty(), str(missing))
	check("spec/every_anchor_is_a_ground_contact", ground.is_empty(), str(ground))
	check("spec/every_target_height_is_metres_inside_the_built_band", heights.is_empty(), str(heights))
	check("spec/repeat_count_and_spread_agree", repeats_bad.is_empty(), str(repeats_bad))
	check("spec/every_repeat_run_stays_inside_the_authored_half_span", run_wide.is_empty(), str(run_wide))
	check("spec/every_slot_carries_a_footprint_note", notes.is_empty(), str(notes))
	check("spec/every_footprint_clears_the_field_law_plane_z_minus_8", law.is_empty(), str(law))
	check("spec/every_footprint_clears_the_measured_glass_plane", glass.is_empty(), str(glass))
	check("spec/every_footprint_fits_the_depth_budget", budget.is_empty(), str(budget))
	check("spec/suppress_defaults_off_in_every_slot", suppress_on.is_empty(), str(suppress_on))
	check("spec/every_suppress_target_is_a_real_prop_kind", kinds_bad.is_empty(), str(kinds_bad))
	check("spec/no_slot_is_suppressed_without_a_glb_in_place", ArenaKit.suppressed_kinds("torii").is_empty(),
		str(ArenaKit.suppressed_kinds("torii")))


# --- 2. nothing on disk, and the empty build -------------------------------

func _precheck() -> void:
	var on_disk := _glb_files_under_kits()
	check("pre/godot_assets_arenas_holds_no_glb_yet (the empty-kit state)", on_disk.is_empty(), str(on_disk))
	for arena_id in ARENAS:
		check("pre/has_kit_is_false_for_%s" % arena_id, not ArenaKit.has_kit(arena_id),
			str(ArenaKit.has_kit(arena_id)))
	_assert_slot_report_is_procedural("pre")


func _assert_slot_report_is_procedural(prefix: String) -> void:
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
			if String(row["status"]) != "procedural" or bool(row["present"]):
				problems.append("%s/%s status=%s present=%s" % [arena_id, slot, row["status"], row["present"]])
			if String(row["path"]) != _slot_res_path(arena_id, slot):
				problems.append("%s/%s path=%s" % [arena_id, slot, row["path"]])
			if Vector3(row["anchor"]) != ArenaKit.anchor_at(arena_id, slot):
				problems.append("%s/%s anchor=%s" % [arena_id, slot, str(row["anchor"])])
	check("%s/slot_report_lists_all_ten_slots_as_procedural_with_their_path" % prefix,
		problems.is_empty(), str(problems))


func _empty_kit_regression() -> void:
	var baseline := _read_baseline()
	check("regression/the_recorded_baseline_is_readable (%s)" % BASELINE_PATH, not baseline.is_empty(),
		"missing or unparsable — record it with run/tmp/arena-kit/baseline_probe.gd")
	if baseline.is_empty():
		return
	var arenas: Dictionary = baseline.get("arenas", {})
	var mismatch: Array[String] = []
	var counts: Array[String] = []
	var nondeterministic: Array[String] = []
	var grew_kit: Array[String] = []
	var field_law: Array[String] = []
	for arena_id in ARENAS:
		var built := Arena.build(arena_id, "default")
		var digest := _digest_arena(built)
		var want: Dictionary = arenas.get(arena_id, {})
		if digest["sha256"] != String(want.get("sha256", "")):
			mismatch.append("%s %s != %s" % [arena_id, String(digest["sha256"]).substr(0, 12),
				String(want.get("sha256", "")).substr(0, 12)])
		var dressing := _dressing_count(built)
		var meshes := built.find_children("*", "MeshInstance3D", true, false).size()
		if meshes != int(want.get("meshes", -1)) or dressing != int(want.get("dressing", -1)):
			counts.append("%s meshes=%d/%d dressing=%d/%d" % [arena_id, meshes, int(want.get("meshes", -1)),
				dressing, int(want.get("dressing", -1))])
		if built.find_child("Kit", true, false) != null:
			grew_kit.append("%s grew a Kit node with no GLB" % arena_id)
		var law := ArenaScenery.field_law_report(built)
		if not law.is_empty():
			field_law.append("%s: %s" % [arena_id, str(law)])
		# The digest must also be stable within the run (a second build, same answer):
		# otherwise the baseline comparison itself would be measuring noise.
		var rebuilt := Arena.build(arena_id, "default")
		if _digest_arena(rebuilt)["sha256"] != digest["sha256"]:
			nondeterministic.append(arena_id)
		built.free()
		rebuilt.free()
	check("regression/every_arena_digest_equals_the_recorded_baseline", mismatch.is_empty(), str(mismatch))
	check("regression/mesh_and_dressing_counts_are_unchanged", counts.is_empty(), str(counts))
	check("regression/the_digest_is_deterministic_inside_the_run", nondeterministic.is_empty(), str(nondeterministic))
	check("regression/no_kit_node_is_built_without_a_glb", grew_kit.is_empty(), str(grew_kit))
	check("regression/the_field_law_still_holds", field_law.is_empty(), str(field_law))


# --- 3a. the tiny static fixture -------------------------------------------

func _fixture_tiny() -> void:
	var src := _abs(TINY_FIXTURE)
	check("fixture/tiny_prop_fixture_exists (%s)" % TINY_FIXTURE, FileAccess.file_exists(src), src)
	if not FileAccess.file_exists(src):
		return
	var dst := _slot_abs_path(FIXTURE_ARENA, TINY_SLOT)
	_make_dir(dst.get_base_dir())
	check_eq("fixture/copy_the_tiny_glb_into_the_slot_path", DirAccess.copy_absolute(src, dst), OK)
	check("fixture/the_kit_sees_the_drop (has_kit)",
		ArenaKit.has_kit(FIXTURE_ARENA) and ArenaKit.has_kit(FIXTURE_ARENA, TINY_SLOT), "has_kit false")
	var res_path := _slot_res_path(FIXTURE_ARENA, TINY_SLOT)
	print("INFO resource_loader_exists(%s)=%s file_exists=%s" % [res_path,
		str(ResourceLoader.exists(res_path)), str(FileAccess.file_exists(res_path))])
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
	var preset := "default"
	var slot_node := ArenaKit.mount_slot(holder, FIXTURE_ARENA, TINY_SLOT, {"x_scale": _x_scale(preset)})
	check("fixture/mount_slot_returns_the_slot_node", slot_node != null, "null")
	if slot_node != null:
		var want_anchor := ArenaKit.anchor_at(FIXTURE_ARENA, TINY_SLOT, _x_scale(preset))
		check_eq("fixture/the_slot_node_is_named_Slot_<slot>", String(slot_node.name), "Slot_%s" % TINY_SLOT)
		check("fixture/the_slot_node_sits_at_the_spec_anchor",
			slot_node.position.distance_to(want_anchor) < 0.0001,
			"%s want %s" % [str(slot_node.position), str(want_anchor)])
		check_eq("fixture/the_slot_node_records_its_asset_path", String(slot_node.get_meta("asset")), res_path)
		var spec := ArenaKit.spec(FIXTURE_ARENA, TINY_SLOT)
		var repeats := int(spec["repeats"])
		var spread := float(spec["spread"]) * _x_scale(preset)
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
		# The strictest arena rule, applied to the mounted geometry: its front face stays
		# behind the MEASURED rear glass plane (what the world-arena suite fails on). The
		# box is already expressed in the slot's frame, so the arena-frame front is the
		# slot's anchor z plus the box's own far edge.
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
	var built := Arena.build(FIXTURE_ARENA, preset)
	var kit := built.get_node_or_null("Scenery/Kit")
	check("fixture/a_built_arena_carries_Scenery/Kit", kit != null, "no Kit node")
	check("fixture/the_built_arena_has_Kit/Slot_%s" % TINY_SLOT,
		built.get_node_or_null("Scenery/Kit/Slot_%s" % TINY_SLOT) != null, "missing")
	var law := ArenaScenery.field_law_report(built)
	check("fixture/the_field_law_still_holds_with_a_glb_mounted", law.is_empty(), str(law))
	built.free()
	var wide := Arena.build(FIXTURE_ARENA, "wide")
	var wide_slot := wide.get_node_or_null("Scenery/Kit/Slot_%s" % TINY_SLOT) as Node3D
	var want_wide := ArenaKit.anchor_at(FIXTURE_ARENA, TINY_SLOT, _x_scale("wide"))
	check("fixture/under_another_camera_preset_the_anchor_follows_the_presets_x_scale",
		wide_slot != null and wide_slot.position.distance_to(want_wide) < 0.0001,
		"%s want %s" % [str(wide_slot.position) if wide_slot != null else "missing", str(want_wide)])
	wide.free()


# --- 3b. the real repo GLB (the athlete precedent) --------------------------

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
	var built := Arena.build(FIXTURE_ARENA, "default")
	var slot_node := built.get_node_or_null("Scenery/Kit/Slot_%s" % REPO_SLOT) as Node3D
	check("repo_glb/a_real_repo_glb_mounts_as_Kit/Slot_%s" % REPO_SLOT, slot_node != null, "missing")
	if slot_node != null:
		var spec := ArenaKit.spec(FIXTURE_ARENA, REPO_SLOT)
		var want := ArenaKit.anchor_at(FIXTURE_ARENA, REPO_SLOT, _x_scale("default"))
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


# --- 4. suppression (default off, proven with the test seam) ---------------

func _suppression() -> void:
	var entry := ArenaKit.spec(FIXTURE_ARENA, REPO_SLOT)
	var kinds := entry.get("kinds", []) as Array
	check("suppress/the_slot_names_a_procedural_kind_to_stand_over (%s)" % str(kinds), not kinds.is_empty(), "empty")
	if kinds.is_empty():
		return
	var kind := String(kinds[0])
	var built := Arena.build(FIXTURE_ARENA, "default")
	check("suppress/with_the_flag_off_the_procedural_prop_is_still_built",
		_meshes_of_kind(built, kind).size() > 0, "no meshes for kind %s" % kind)
	built.free()

	ArenaKit.suppress_overrides = {FIXTURE_ARENA: {REPO_SLOT: true}}
	check_eq("suppress/forcing_the_flag_lists_the_kind", ArenaKit.suppressed_kinds(FIXTURE_ARENA), [kind])
	var forced := Arena.build(FIXTURE_ARENA, "default")
	var containers := _containers_of_kind(forced, kind)
	check("suppress/the_container_is_still_built (one Dressing_ per authored prop)",
		containers.size() > 0 and int(_dressing_count(forced)) == (ArenaStyle.style(FIXTURE_ARENA).get("props", []) as Array).size(),
		"%d containers, dressing=%d" % [containers.size(), _dressing_count(forced)])
	check("suppress/the_matching_procedural_prop_is_skipped", _meshes_of_kind(forced, kind).is_empty(),
		"%d meshes left" % _meshes_of_kind(forced, kind).size())
	check("suppress/the_kit_slot_itself_is_still_mounted",
		forced.get_node_or_null("Scenery/Kit/Slot_%s" % REPO_SLOT) != null, "slot missing")
	check("suppress/other_kinds_are_untouched",
		_dressing_count(forced) - containers.size() > 0
		and _meshes_of_kind(forced, "lantern").size() > 0, "another kind lost its geometry")
	forced.free()
	ArenaKit.suppress_overrides = {}
	check("suppress/the_override_clears_back_to_the_frozen_table",
		ArenaKit.suppressed_kinds(FIXTURE_ARENA).is_empty(), str(ArenaKit.suppressed_kinds(FIXTURE_ARENA)))


# --- 5. cleanup: the fallback comes back, nothing is left behind -----------

func _cleanup() -> void:
	var removed: Array[String] = []
	for pair in [[FIXTURE_ARENA, TINY_SLOT], [FIXTURE_ARENA, REPO_SLOT]]:
		var path := _slot_abs_path(String(pair[0]), String(pair[1]))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
			removed.append(path)
	var left := _glb_files_under_kits()
	check("clean/both_fixtures_are_gone_and_no_glb_is_staged (%d removed)" % removed.size(),
		removed.size() == 2 and left.is_empty(), "removed=%s left=%s" % [str(removed), str(left)])
	for arena_id in ARENAS:
		check("clean/has_kit_is_false_again_for_%s" % arena_id, not ArenaKit.has_kit(arena_id),
			str(ArenaKit.has_kit(arena_id)))
	_assert_slot_report_is_procedural("clean")
	var baseline := _read_baseline()
	var arenas: Dictionary = baseline.get("arenas", {})
	var mismatch: Array[String] = []
	for arena_id in ARENAS:
		var built := Arena.build(arena_id, "default")
		var digest := _digest_arena(built)
		if digest["sha256"] != String((arenas.get(arena_id, {}) as Dictionary).get("sha256", "")):
			mismatch.append(arena_id)
		built.free()
	check("clean/after_removal_every_arena_digest_matches_the_baseline_again", mismatch.is_empty(), str(mismatch))
	var contracts: Array[String] = []
	for arena_id in ARENAS:
		var readme := "%s/assets/arenas/%s/README.md" % [_project_dir(), arena_id]
		if not FileAccess.file_exists(readme):
			contracts.append(readme)
	check("clean/the_per_arena_drop_folders_and_their_readmes_survive", contracts.is_empty(), str(contracts))


# --- checks shared by the fixture sections ---------------------------------

func _check_material_policy(slot_node: Node3D, prefix: String) -> void:
	var wrong: Array[String] = []
	var instances := {}
	var source_surfaces := 0
	var kept_colours := 0
	for mi in slot_node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := (mi as MeshInstance3D).get_surface_override_material(s) as StandardMaterial3D
			var where := "%s/%d" % [String((mi as MeshInstance3D).name), s]
			if mat == null:
				wrong.append("%s has no override material" % where)
				continue
			instances[mat.get_instance_id()] = true
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
	check("%s/one_material_instance_is_shared_across_the_repeats (%d)" % [prefix, instances.size()],
		instances.size() == 1, "%d distinct materials" % instances.size())


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

## The GLB files under `godot/assets/arenas/` (recursive) — the drop-in state.
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
## must move together (the probe's header says the same).
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


func _digest(node: Node, out: PackedStringArray, depth := 0) -> void:
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
		_digest(child, out, depth + 1)


func _v(v: Vector3) -> String:
	return "(%.4f,%.4f,%.4f)" % [v.x, v.y, v.z]


## A node's recorded name, with Godot's process-local auto names masked (`@MeshInstance3D@2`):
## the counter depends on how many nodes the process created before, so recording it would
## make the digest a function of the process instead of the build. `baseline_probe.gd`
## masks it the same way — the two digests must stay identical.
func _node_name(node: Node) -> String:
	var name := String(node.name)
	return "<auto>" if name.begins_with("@") else name
