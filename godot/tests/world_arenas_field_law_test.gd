## world_arenas_field_law_test.gd — independent proof: the five world arenas exist,
## are selectable, and their scenery obeys the field law.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/world_arenas_field_law_test.gd
##   ... -- --arenas=torii,medina        (subset; default is the five world ids)
##   ... -- --all                        (the whole frozen roster)
##
## HEADLESS IS CORRECT HERE: every number in this suite is a world-space or data
## fact (roster membership, style tables, built geometry, the selectable path). The
## RENDERED-frame proof is `world_arenas_capture.gd`, which needs a real viewport
## (`--rendering-driver opengl3`) and is run by `tools/world-arenas/run_proof.sh`.
## Nothing in this file renders, toggles a mesh's visibility, or edits anything.
##
## WHAT IT GATES (all against `docs/mission/world-arenas/CHARTER.md`):
##   1. every target arena id is a real arena of the arena library (the frozen
##      nine plus the world five), the frozen roster is still exactly nine with
##      no world id inside it, and every target is offered as a choice by the
##      build that is running (the frozen list plus the world seam — a demo
##      offers none of the world set);
##   2. `family` is "world" and the style's signature is distinct per arena
##      (five different environments, not five copies);
##   3. every target builds a complete environment (court, net, cage, scenery) with
##      one `Dressing_*` object per authored prop — under all three real presets;
##   4. FIELD LAW: every scenery vertex stays behind the BACKDROP_Z=-8.0 plane, and
##      no scenery AABB intersects the playable footprint (never inside the cage);
##   4b. FIELD LAW, independent second plane (round-2 review): the nearest point of
##      every scenery mesh also stays behind the ACTUAL rear glass, measured from
##      the six `GlassFar*` panes' own geometry (`Common.rear_glass_plane`) — this
##      does not replace the mandated plane, it adds the stricter one — plus a RED
##      CONTROL that places scenery at z=-9 and proves the glass safety rejects it
##      while the mandated -8 plane does not (the two checks are independent);
##   4c. shared structural dressing (`GearRing`, `AccentPostL/R`, built into every
##      arena by `court_builder.gd`) is explicitly classified as shared structural
##      court dressing and COVERED by measurement: GearRing behind the measured
##      glass, the accent posts outside the cage laterally;
##   5. the glass cage is intact: six rear panes, the rear wall's frame parts, the
##      side walls, and the rear panes' alpha equals `Arena.rear_alpha(id)` — this
##      suite never hides or zeroes glass to pass;
##   6. the game's selection path takes each id: `Config.set_arena_id` and the CLI
##      route (`apply_cli_selection`) land on the arena that was asked for.
##
## Exit 0 on PASS (all gates), 1 on any FAIL. `PASS n/n` is the tally; a
## `SCRIPT ERROR` anywhere in the log is a failure even next to a green tally.
extends SceneTree

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ArenaStyle := preload("res://game/arenas/arena_style.gd")
const Court := preload("res://game/court.gd")
const CourtBuilder := preload("res://game/arenas/court_builder.gd")
const Config := preload("res://game/match_config.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Gate := preload("res://game/content_gate.gd")

const PRESETS := ["default", "wide", "playable"]

var _c := Common.new()
var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Common.banner("WORLD_ARENAS_FIELD_LAW")
	var ids := Common.target_ids(args)
	print("# targets=%s build=%s" % [str(ids), Gate.label()])

	# --- 1. roster presence -------------------------------------------------
	# MECHANICS FIX (integrator, recorded in `integrator.md` §9.4): this section
	# used to ask `Arena.ids()` alone, which the slice pins to the FROZEN nine
	# (`game_slice_test.gd:1833`) and which by design can never hold a world id —
	# the check could not pass for the very arenas this mission adds. The question
	# the gate needs is "is this a real arena of this library, and does the build
	# offer it?", asked below of `Arena.all_ids()` (frozen ∪ world) with the
	# frozen roster's own preservation asserted right after it. No bound is
	# loosened: the frozen-roster check is still an exact order equality.
	var library: Array = []
	for id in Arena.all_ids():
		library.append(String(id))
	var missing: Array[String] = []
	var duplicates: Array[String] = []
	for id in ids:
		if not library.has(String(id)):
			missing.append(String(id))
		if ids.count(id) > 1 and not duplicates.has(String(id)):
			duplicates.append(String(id))
	_c.check("every target arena id is known to the arena library (frozen nine + world five)", missing.is_empty(), "missing=%s library=%s" % [str(missing), str(library)])
	_c.check("the target ids are distinct", duplicates.is_empty(), str(duplicates))

	# The frozen roster must survive the extension untouched: still exactly the
	# frozen table's ids, in order, with none of the world five inside it.
	var frozen_ids: Array = []
	for row in Frozen.arenas():
		frozen_ids.append(String(row["id"]))
	var leaked: Array[String] = []
	for id in Arena.world_ids():
		if frozen_ids.has(String(id)):
			leaked.append(String(id))
	var roster := PackedStringArray()
	for id in Arena.ids():
		roster.append(String(id))
	_c.check("the frozen roster is still exactly the frozen table's nine, in order, with no world id inside it",
		roster == PackedStringArray(frozen_ids) and leaked.is_empty(),
		"roster=%s frozen=%s leaked=%s" % [str(roster), str(frozen_ids), str(leaked)])

	# "Offered as a choice" is asked of the build's OWN choice seams: the frozen
	# list (`Config.selectable_arenas()`, pinned by the slice at the frozen nine)
	# plus the world seam (`Config.selectable_world_arenas()`, empty in a demo).
	var offered: Array = []
	for row in Config.selectable_arenas():
		offered.append(String((row as Dictionary)["id"]))
	var world_offered: Array = []
	for row in Config.selectable_world_arenas():
		world_offered.append(String((row as Dictionary)["id"]))
	offered.append_array(world_offered)
	var not_offered: Array[String] = []
	for id in ids:
		if not offered.has(String(id)):
			not_offered.append(String(id))
	_c.check("every target arena is offered as a choice by this build (%s)" % Gate.label(), not_offered.is_empty(),
		"not offered=%s offered=%s" % [str(not_offered), str(offered)])
	if Gate.is_demo():
		_c.check("a DEMO build offers none of the world five (its content rule is the reference's own table)",
			world_offered.is_empty(), str(world_offered))
	else:
		_c.check("a FULL build offers the five world arenas as choices",
			world_offered.size() == Arena.world_ids().size() and world_offered.size() == 5,
			"%d offered: %s" % [world_offered.size(), str(world_offered)])

	# --- 2..5. per-arena data, build, field law, glass -----------------------
	var signatures := {}
	var reported: Array = []
	var present: Array = []
	for id_in in ids:
		var id := String(id_in)
		if not Arena.has(id):
			continue
		present.append(id)
		var info: Dictionary = Arena.info(id)
		var built := Arena.build(id, "default")
		if built == null:
			_c.check("arena '%s' builds an environment" % id, false, "Arena.build returned null")
			continue
		var report := Common.arena_report(id, built)
		reported.append(report)
		print(Common.report_line(report))

		var family := String(report["family"])
		_c.check("arena '%s' declares family \"world\"" % id, family == "world", family)
		_c.check("arena '%s' carries a name and a description" % id,
			String(info.get("name", "")) != "" and String(info.get("desc", "")) != "",
			"%s / %s" % [info.get("name", ""), info.get("desc", "")])
		var bounce := float(report["wallBounce"])
		_c.check("arena '%s' carries a usable wallBounce (%.2f -> rear alpha %.3f)" % [id, bounce, float(report["rear_alpha"])],
			bounce > 0.0 and float(report["rear_alpha"]) >= CourtBuilder.REAR_ALPHA_MIN - 0.0001
			and float(report["rear_alpha"]) <= CourtBuilder.REAR_ALPHA_MAX + 0.0001,
			"wallBounce=%.3f rear_alpha=%.3f" % [bounce, float(report["rear_alpha"])])
		_c.check("arena '%s' has a distinct style signature" % id,
			not signatures.has(String(report["signature"])), str(signatures.get(String(report["signature"]), "")))
		signatures[String(report["signature"])] = id

		# Build health: the cage and the scenery are really there.
		var has_court: bool = built.get_node_or_null("Court") != null
		var has_net: bool = built.get_node_or_null("Net") != null
		var scenery: Node = built.get_node_or_null("Scenery")
		var dressing := int(report["dressing"])
		_c.check("arena '%s' builds the court, the net and a populated Scenery" % id,
			has_court and has_net and scenery != null and dressing > 0 and int(report["props"]) == dressing,
			"court=%s net=%s scenery=%s dressing=%d props=%d" % [str(has_court), str(has_net), str(scenery != null), dressing, int(report["props"])])
		_c.check("arena '%s' carries its own scenery vocabulary" % id,
			(report["kinds"] as Array).size() > 0, str(report["kinds"]))

		# Field law, measured on the built tree (not read from the table).
		var field: Dictionary = report["field"]
		_c.check("arena '%s' scenery stays behind BACKDROP_Z=%.1f (closest vertex z=%+.2f at '%s')" % [
			id, Common.BACKDROP_Z_LAW, float(field["closest_z"]), String(field["closest_name"])],
			float(field["closest_z"]) <= Common.BACKDROP_Z_LAW,
			"closest z=%+.3f" % float(field["closest_z"]))
		_c.check("arena '%s' backdrop wall stands behind BACKDROP_Z=%.1f (z=%+.2f, module constant %+.2f)" % [
			id, Common.BACKDROP_Z_LAW, float(field["wall_z"]), float(field["module_z"])],
			bool(field["wall_found"]) and float(field["wall_z"]) <= Common.BACKDROP_Z_LAW,
			"wall_found=%s wall_z=%+.3f module_z=%+.3f" % [str(field["wall_found"]), float(field["wall_z"]), float(field["module_z"])])
		_c.check("arena '%s' has no scenery over the playable footprint (never inside the cage)" % id,
			(field["court_overlap"] as Array).is_empty(), str(field["court_overlap"]))

		# --- FIELD LAW, second INDEPENDENT plane: the ACTUAL rear glass.
		# The review asked for a dressing-behind-the-actual-rear-glass check that
		# does NOT replace the mandated z<=-8 plane. This measures the six
		# `GlassFar*` panes' own geometry (`Common.rear_glass_plane`) and requires
		# the nearest point of EVERY scenery mesh — backdrop, apron, dressing — to
		# stay behind that measured plane. It is STRICTER than the mandate's
		# plane: the red control below puts scenery at z=-9, which passes -8 and
		# fails here.
		_c.check("arena '%s' six rear panes give a real glass plane (measured glass z=%+.2f at %s)" % [
			id, float(field["glass_z"]), String(field["glass_name"])],
			bool(field["glass_found"]) and int(field["glass_panes"]) == int(field["glass_expected_panes"]),
			"glass_found=%s panes=%d/%d name=%s" % [str(field["glass_found"]), int(field["glass_panes"]), int(field["glass_expected_panes"]), String(field["glass_name"])])
		_c.check("arena '%s' every scenery mesh stays behind the MEASURED rear glass (closest z=%+.2f at '%s' vs glass z=%+.2f)" % [
			id, float(field["closest_z"]), String(field["closest_name"]), float(field["glass_z"])],
			(field["behind_glass"] as Array).is_empty(),
			"violations=%s" % str(field["behind_glass"]))

		# --- shared structural dressing: GearRing / AccentPostL/R. Classified AND
		# covered (they are built by `court_builder.gd` for every arena, the frozen
		# nine included, and are not `Scenery/` children — see `structural_report`).
		var structural: Dictionary = Common.structural_report(built, float(field["glass_z"]))
		_c.check("arena '%s' shared structural dressing classified + covered (GearRing z=%+.2f behind glass, AccentPostL/R outside the cage)" % [
			id, float((structural["gear"] as Dictionary).get("z", 0.0))],
			(structural["problems"] as Array).is_empty(), str(structural["problems"]))
		print("STRUCTURAL arena=%s gear=%s posts=%s classified=%s" % [
			id, str(structural["gear"]), str(structural["posts"]), String(structural["classified"])])

		# --- RED CONTROL: scenery at z=-9, i.e. still behind the mandated PLANE
		# (-9 <= -8) but IN FRONT of the real glass (-9 > the measured -10.02).
		# The glass check must reject it and the -8 plane must not: that is the
		# property that makes the two checks independent, and it fails loudly if
		# either half stops discriminating.
		var scenery_root: Node = built.get_node_or_null("Scenery")
		var red := MeshInstance3D.new()
		red.name = "Dressing_RedControl"
		var red_box := BoxMesh.new()
		red_box.size = Vector3(0.4, 0.4, 0.4)
		red.mesh = red_box
		red.position = Vector3(0.0, 0.2, -9.2)
		scenery_root.add_child(red)
		var red_report := Common.field_law_report(built)
		var red_listed := false
		for hit in red_report["behind_glass"]:
			if String(hit).begins_with("Dressing_RedControl"):
				red_listed = true
		_c.check("RED CONTROL arena '%s': scenery at z=-9 is REJECTED by the glass safety (closest vertex z=%+.2f > measured glass z=%+.2f)" % [
			id, float(red_report["closest_z"]), float(red_report["glass_z"])],
			absf(float(red_report["closest_z"]) + 9.0) < 0.001 and float(red_report["closest_z"]) > float(red_report["glass_z"]) and red_listed,
			"closest=%+.3f glass=%+.3f violations=%s" % [float(red_report["closest_z"]), float(red_report["glass_z"]), str(red_report["behind_glass"])])
		_c.check("RED CONTROL arena '%s': the SAME z=-9 dressing is NOT a violation of the mandated -8 plane (the checks are independent)" % id,
			float(red_report["closest_z"]) <= Common.BACKDROP_Z_LAW,
			"closest=%+.3f law=%+.1f" % [float(red_report["closest_z"]), Common.BACKDROP_Z_LAW])
		scenery_root.remove_child(red)
		red.free()

		# Glass honesty: the cage is intact and nothing is hidden.
		var glass_problems: Array[String] = []
		for pane_name in ["GlassFar", "GlassFar2", "GlassFar3", "GlassFar4", "GlassFar5", "GlassFar6"]:
			var pane := _find(built, pane_name) as MeshInstance3D
			if pane == null or not pane.visible:
				glass_problems.append("%s missing/hidden" % pane_name)
				continue
			var mat := pane.material_override as StandardMaterial3D
			if mat == null or absf(mat.albedo_color.a - float(report["rear_alpha"])) > 0.0001:
				glass_problems.append("%s alpha=%s expected %.3f" % [pane_name, str(mat.albedo_color.a if mat != null else -1.0), float(report["rear_alpha"])])
		for pane_name in ["GlassFarRail", "GlassFarRailHilite", "GlassFarBottom", "GlassLeft", "GlassRight", "GlassNear"]:
			var pane := _find(built, pane_name) as MeshInstance3D
			if pane == null or not pane.visible:
				glass_problems.append("%s missing/hidden" % pane_name)
		var side := _find(built, "GlassLeft") as MeshInstance3D
		if side != null:
			var side_mat := side.material_override as StandardMaterial3D
			if side_mat == null or absf(side_mat.albedo_color.a - CourtBuilder.SIDE_ALPHA) > 0.0001:
				glass_problems.append("side alpha=%s expected %.3f" % [str(side_mat.albedo_color.a if side_mat != null else -1.0), CourtBuilder.SIDE_ALPHA])
		_c.check("arena '%s' glass cage intact: six rear panes + frame + side walls, all visible, alphas as built" % id,
			glass_problems.is_empty(), str(glass_problems))

		# Buildability under all three real presets (the framing authority).
		var preset_problems: Array[String] = []
		for preset in PRESETS:
			var holder := Node3D.new()
			root.add_child(holder)
			Court.build_camera(holder, preset)
			var built_preset := Arena.build_into(holder, id, preset)
			if built_preset == null:
				preset_problems.append("%s: no build" % preset)
			elif built_preset.find_children("*", "MeshInstance3D", true, false).size() < 60:
				preset_problems.append("%s: thin build" % preset)
			root.remove_child(holder)
			holder.free()
		_c.check("arena '%s' builds under every real preset %s" % [id, str(PRESETS)], preset_problems.is_empty(), str(preset_problems))
		built.free()

	# --- distinctness across the five ----------------------------------------
	if present.size() == Common.WORLD_IDS.size():
		_c.check("the five world arenas are five distinct environments (signature digests)",
			signatures.size() == Common.WORLD_IDS.size(), "%d signatures: %s" % [signatures.size(), str(signatures.values())])
	else:
		_c.check("all five world arenas are present to compare", false,
			"only %d of %d built: %s" % [present.size(), Common.WORLD_IDS.size(), str(present)])

	# --- 6. the game's selection path ----------------------------------------
	var original := Config.arena_id()
	var refused: Array[String] = []
	var misrouted: Array[String] = []
	for id in present:
		if not Config.set_arena_id(String(id)):
			refused.append("%s: set_arena_id false" % id)
			continue
		if Config.arena_id() != String(id):
			misrouted.append("%s: set landed on %s" % [id, Config.arena_id()])
		var cli: Dictionary = Config.apply_cli_selection("", String(id), "")
		var effective: String = String((cli["effective"] as Dictionary)["arena"])
		if effective != String(id):
			misrouted.append("%s: CLI route landed on %s (%s)" % [id, effective, str(cli)])
	Config.set_arena_id(original)
	_c.check("every present target arena is selectable through Config.set_arena_id", refused.is_empty(), str(refused))
	_c.check("every present target arena reaches the selection the match would start with", misrouted.is_empty(), str(misrouted))

	# --- verdict --------------------------------------------------------------
	_c.verdict()
	quit(_c.exit_code())


func _find(from: Node, node_name: String) -> Node:
	for node in from.find_children("*", "", true, false):
		if String(node.name) == node_name:
			return node
	return null
