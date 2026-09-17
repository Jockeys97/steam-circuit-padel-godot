## world_arenas_frame_test.gd — independent proof: the WHOLE court and the glass
## cage stay inside the frame under the real, unchanged camera presets.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/world_arenas_frame_test.gd
##   ... -- --arenas=torii,medina --presets=default,wide,playable --size=1280x720
##
## WHAT IT GATES per arena and preset (the mission's framing mandate):
##   - every court corner (both baselines' ends) projects INSIDE the frame;
##   - both side walls' extents (foot and top, at both ends) are inside;
##   - the rear rebound glass's extents (foot and top at both sides) are inside;
##   - no required point is behind the camera;
##   - every `Dressing_*` scenery object is fully inside the frame (reported, and
##     gated here too: a half-cropped prop is the exact defect the previous lane's
##     frame showed, and the BRIEF rejects a cropped field of any kind).
## The rear rail's top line and the near wall are reported as INFO margins.
## Finally (round-2 review note) the suite gates the SCENERY BAND's coverage
## through the LIVE camera: the band `ArenaScenery.band()` builds the arenas from
## must still cover the frame's upper rows — measured with engine rays
## (`project_ray_normal`), not the closed form — including the playable preset,
## whose camera `look_at` orientates at about -21.5 deg while the preset table's
## `pitch_deg` says 0.0 (`# BAND_COVER` lines carry the live numbers).
##
## HOW THE NUMBERS ARE MADE: the camera is built by `Court.build_camera()` — the
## same call the match makes — with the preset table untouched; the projection is
## `Camera3D.unproject_position` against a 1280x720 viewport. This is the exact
## math the renderer uses; the RENDERED-frame twin of this suite is
## `world_arenas_capture.gd` (real viewport, PNG + SHA-256).
##
## Exit 0 on PASS, 1 on any FAIL; a `SCRIPT ERROR` anywhere is a failure.
extends SceneTree

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Court := preload("res://game/court.gd")

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
	Common.banner("WORLD_ARENAS_FRAME")
	var ids := Common.target_ids(args)
	var presets := _presets(args)
	var size := _size(args)
	root.size = size
	var viewport := Vector2(root.get_visible_rect().size)
	_c.check_eq("the harness viewport is %dx%d (the framing contract's size)" % [size.x, size.y],
		viewport, Vector2(size))
	print("# targets=%s presets=%s viewport=%s" % [str(ids), str(presets), str(viewport)])

	var gating := Common.required_points()
	var info := Common.info_points()
	var worst_by_preset := {}
	for preset in presets:
		var offenders: Array[String] = []
		var behind_any: Array[String] = []
		var scenery_offenders: Array[String] = []
		var preset_worst := INF
		for id_in in ids:
			var id := String(id_in)
			if not Arena.has(id):
				offenders.append("%s: not in the frozen roster" % id)
				continue
			var holder := Node3D.new()
			root.add_child(holder)
			var cam := Court.build_camera(holder, preset)
			var built := Arena.build_into(holder, id, preset)
			if built == null:
				offenders.append("%s: build returned null" % id)
				root.remove_child(holder)
				holder.free()
				continue
			var results: Array = []
			for point in gating:
				var res := Common.project_point(cam, viewport, point["at"])
				results.append({"name": point["name"], "result": res})
				if not bool(res["inside"]):
					offenders.append("%s/%s %s" % [id, preset, point["name"]])
				if bool(res["behind"]):
					behind_any.append("%s/%s %s" % [id, preset, point["name"]])
				preset_worst = minf(preset_worst, float(res["margin"]))
			Common.frame_line(preset, id, results)
			# INFO: the rail top and the near wall, so nothing is hidden. An INFO
			# point outside the frame is printed, never gated.
			for point in info:
				var res := Common.project_point(cam, viewport, point["at"])
				if not bool(res["inside"]):
					print("INFO preset=%s arena=%s %s outside px=(%.0f,%.0f) margin=%.1f" % [
						preset, id, point["name"], res["px"].x, res["px"].y, res["margin"]])
			# Scenery: every Dressing_* object fully inside the frame.
			for child in Common.dressing_nodes(built):
				var bounds := Common.node_world_aabb(child, built)
				var bad := 0
				for endpoint in 8:
					var res := Common.project_point(cam, viewport, bounds.get_endpoint(endpoint))
					if not bool(res["inside"]):
						bad += 1
				if bad > 0:
					scenery_offenders.append("%s/%s %s: %d of 8 corners outside" % [id, preset, child.name, bad])
			root.remove_child(holder)
			holder.free()
		worst_by_preset[preset] = preset_worst
		_c.check("preset %s: every arena keeps all court corners + side/rear glass extents inside %s" % [preset, str(viewport)],
			offenders.is_empty(), str(offenders))
		_c.check("preset %s: no required point is behind the camera" % preset, behind_any.is_empty(), str(behind_any))
		_c.check("preset %s: every scenery object is fully inside the frame" % preset,
			scenery_offenders.is_empty(), str(scenery_offenders))
		print("FRAME_PRESET preset=%s arenas=%d worst_margin=%.1fpx" % [preset, ids.size(), preset_worst])

	# --- the scenery band's coverage, through the LIVE camera ------------------
	# Round-2 review note, made permanent: `ArenaScenery.band()` derives the band
	# from the preset's `pitch_deg` with a pure-pitch closed form, while
	# `Court.build_camera` orientates the playable camera with `look_at` — the
	# measured live pitch is about -21.5 deg where the table says 0.0. This gates
	# the CLAIM the scenery was built on (the band must cover the frame's upper
	# rows through the engine's own projection, not through the closed form), so
	# the presets or the band moving out from under each other fails loudly here.
	for preset in presets:
		var band_holder := Node3D.new()
		root.add_child(band_holder)
		var band_cam := Court.build_camera(band_holder, preset)
		var band: Dictionary = Arena.band(preset, Common.backdrop_wall_z())
		var live := Common.live_band_requirement(band_cam, viewport, Common.backdrop_wall_z())
		var covered := bool(live["crossed"]) \
			and float(band["top"]) >= float(live["required_top"]) - 0.001 \
			and float(band["half_x"]) >= float(live["required_half_x"]) - 0.001
		_c.check("preset %s: the scenery band covers the frame through the LIVE camera (top %.2f >= required %.2f, half_x %.2f >= required %.2f)" % [
			preset, float(band["top"]), float(live["required_top"]), float(band["half_x"]), float(live["required_half_x"])],
			covered, "band=%s live=%s" % [str(band), str(live)])
		print("BAND_COVER preset=%s live_pitch=%+.2f band_top=%.2f required_top=%.2f band_half_x=%.2f required_half_x=%.2f" % [
			preset, rad_to_deg(band_cam.global_rotation.x), float(band["top"]), float(live["required_top"]),
			float(band["half_x"]), float(live["required_half_x"])])
		root.remove_child(band_holder)
		band_holder.free()

	_c.check("the presets are the game's own, unmodified: %s" % str(Court.CAMERAS.keys()),
		str(Court.CAMERAS.keys()) == str(["default", "wide", "playable"]),
		str(Court.CAMERAS.keys()))
	_c.verdict()
	quit(_c.exit_code())


func _presets(args: PackedStringArray) -> Array:
	var raw := Common.arg(args, "--presets", "")
	if raw == "":
		return ["default", "wide", "playable"]
	var out: Array = []
	for piece in raw.split(",", false):
		var p := piece.strip_edges()
		if p != "":
			out.append(p)
	return out


func _size(args: PackedStringArray) -> Vector2i:
	var raw := Common.arg(args, "--size", "1280x720")
	var parts := raw.split("x", false)
	if parts.size() != 2:
		return Vector2i(1280, 720)
	return Vector2i(int(parts[0]), int(parts[1]))
