## aurora_shooting_stars_test.gd — the focused suite for Banco Aurora's shooting
## stars (`game/arenas/aurora_shooting_stars.gd`, mounted only by
## `arena_scenery.gd`'s Aurora branch).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##     --script res://tests/aurora_shooting_stars_test.gd
##
## WHAT IS GATED
##   1. PRESENCE AND NEGATIVES. One `AuroraShootingStars` node under Aurora's
##      `Scenery`, and NONE in the other four world arenas nor in a frozen one.
##   2. BUDGET. Two `MeshInstance3D` (a luminous head and one tapered trail quad),
##      no `Light3D`, no particles, no shadow casting, unshaded, fog off, and a
##      node count that never grows as passes come and go (the pool is reused).
##   3. LOCAL RNG. Two instances of the module produce the identical schedule —
##      same waits, same positions, same pass count — because the stream is seeded
##      from a constant and never from the simulation's RNG.
##   4. SCHEDULE. The first delay is 10-20 s, every later gap 20-40 s, and each
##      pass is on screen for about a second (`FLIGHT`).
##   5. PAUSE. An ancestor exposing `is_paused()` freezes the schedule (the
##      `egeo_fish.gd` seam), and it resumes when the ancestor is not paused.
##   6. THE SKY, MEASURED. In the viewports that can see sky at all, the star's
##      head AND the far end of its trail must have a CLEAR LINE OF SIGHT: the
##      segment from the camera to each of them may not cross any visible mesh of
##      the built arena (`AABB.intersects_segment` against every mesh's own world
##      bounds). Nothing is asserted against a hand-written row, and the mesh that
##      blocks the view is named when one does.
##   7. NO COURT CONTACT. In every preset (playable, courtside, immersive,
##      default, wide) the star must stay ABOVE the highest court corner's row, so
##      it can never be drawn over the court or the athletes. In the presets whose
##      frame contains no sky the star is simply outside the frame, and the suite
##      says so rather than forcing it in.
##   8. NO STALE STAR. `reset()` (the build/stop path) clears the streak, and a
##      finished pass leaves nothing visible.
##   9. REACH. 900 m is inside the live camera's far plane and in front of it, so
##      the star is not clipped away.
##
## Exit 0 on PASS, 1 on any FAIL. `# SKY_REPORT` lines carry the measured numbers.
extends SceneTree

const Stars := preload("res://game/arenas/aurora_shooting_stars.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Court := preload("res://game/court.gd")
const Common := preload("res://tests/world_arenas_common.gd")

## The renderer's own viewport for the projection checks, and the tick the suite
## drives `step()` with (the fixed step the sim uses is close enough that a pass
## is 20 samples).
const VIEWPORT := Vector2(1280.0, 720.0)
const DT := 0.05
## The presets whose frame contains sky at all, and the ones whose frame does not.
## Both groups are sampled: the first must show the star with a clear line of
## sight, the second must not show it at all (so it is never forced over a view
## that has no sky). `immersive` sits in the second group on measurement: its
## frame top is 1.8 deg above the horizon while the arena's own ridges stand
## higher than that, so that view has no sky to put a star in.
const SKY_PRESETS := ["playable", "courtside"]
const NO_SKY_PRESETS := ["default", "wide", "tactical", "broadcast", "immersive"]

var checks := 0
var failures := 0


## A pause owner for the `is_paused()` seam. Nothing else about it matters.
class Pauser:
	extends Node3D
	var paused := false

	func is_paused() -> bool:
		return paused


func check(name: String, condition: bool, got: Variant = "") -> void:
	checks += 1
	if condition:
		print("ok %s" % name)
		return
	failures += 1
	print("FAIL %s: expected true, got %s" % [name, str(got)])


func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	failures += 1
	print("FAIL %s: expected %s, got %s" % [name, str(expected), str(actual)])


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var capture_dir := ""
	for arg in args:
		if String(arg).begins_with("--capture="):
			capture_dir = String(arg).trim_prefix("--capture=")
	if capture_dir != "":
		await _capture(capture_dir)
		return
	root.size = Vector2i(VIEWPORT)
	print("# AURORA_SHOOTING_STARS · Godot %s" % Engine.get_version_info().get("string", "?"))
	_test_budget()
	_test_determinism()
	_test_schedule()
	_test_stale()
	await _test_pause()
	_test_presence()
	_test_sky()
	print("# AURORA_SHOOTING_STARS result=%d/%d" % [checks - failures, checks])
	print("AURORA_SHOOTING_STARS %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)


func _fresh() -> Node3D:
	var stars := Stars.new()
	stars.name = "AuroraShootingStars"
	root.add_child(stars)
	return stars


# ---------------------------------------------------------------------------
# 2. The budget: what the module is allowed to put in the tree
# ---------------------------------------------------------------------------

func _test_budget() -> void:
	var stars := _fresh()
	var meshes: Array = stars.find_children("*", "MeshInstance3D", true, false)
	var before := stars.get_child_count()
	check_eq("budget/one head plus one trail quad", meshes.size(), 2)
	check("budget/no Light3D anywhere", stars.find_children("*", "Light3D", true, false).is_empty(), "found a light")
	check("budget/no particles", stars.find_children("*", "GPUParticles3D", true, false).is_empty()
		and stars.find_children("*", "CPUParticles3D", true, false).is_empty(), "found particles")
	var shadows_off := true
	var unshaded := true
	var fog_off := true
	for node in meshes:
		var mi := node as MeshInstance3D
		shadows_off = shadows_off and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			unshaded = false
			continue
		unshaded = unshaded and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		fog_off = fog_off and m.disable_fog
	check("budget/nothing casts a shadow", shadows_off, str(meshes.size()))
	check("budget/every material is unshaded", unshaded, "a lit star would be invisible at night")
	check("budget/fog off (aurora's fog ends at 170 m, the star lives at 900 m)", fog_off, "fog on")

	# The pool is reused: 400 s of passes must not add a single node.
	var were := stars.get_child_count()
	for i in 8000:
		stars.step(DT)
	check_eq("budget/the pool does not grow over 400 s of passes",
		[stars.get_child_count(), stars.find_children("*", "MeshInstance3D", true, false).size()],
		[were, 2])
	check("budget/the star is inside the camera's own reach (900 m << far plane of 4000 m)",
		Stars.SKY_RADIUS < 1000.0, Stars.SKY_RADIUS)
	check("budget/started with the star hidden", not stars.star.visible, "visible before any pass")
	root.remove_child(stars)
	stars.free()


# ---------------------------------------------------------------------------
# 3. The local, deterministic stream
# ---------------------------------------------------------------------------

func _test_determinism() -> void:
	var a := _fresh()
	var b := _fresh()
	var mismatches := 0
	var passes := 0
	var was_visible := false
	for i in 6000:
		a.step(DT)
		b.step(DT)
		if a.star.visible != b.star.visible:
			mismatches += 1
		if a.star.visible and not was_visible:
			passes += 1
		was_visible = a.star.visible
		if a.star.visible and a.star.position.distance_to(b.star.position) > 0.0001:
			mismatches += 1
		if not is_equal_approx(a.wait_seconds, b.wait_seconds):
			mismatches += 1
	check_eq("rng/two instances agree on every step of 300 s", mismatches, 0)
	check("rng/the seeded stream really does produce passes to compare", passes >= 6, "%d passes" % passes)
	root.remove_child(a)
	root.remove_child(b)
	a.free()
	b.free()


# ---------------------------------------------------------------------------
# 4. The schedule: the first delay, the gaps, and the flight time
# ---------------------------------------------------------------------------

func _test_schedule() -> void:
	var stars := _fresh()
	check("schedule/first delay is 10-20 s",
		stars.wait_seconds >= Stars.FIRST_WAIT.x and stars.wait_seconds <= Stars.FIRST_WAIT.y,
		stars.wait_seconds)
	var runs: Array[float] = []
	var gaps: Array[float] = []
	var first_at := -1.0
	var clock := 0.0
	var run := 0.0
	var gap := 0.0
	var was_visible := false
	for i in 8000:
		stars.step(DT)
		clock += DT
		var visible: bool = stars.star.visible
		if visible and not was_visible:
			if first_at < 0.0:
				first_at = clock
			elif runs.size() > 0:
				gaps.append(gap)
			run = 0.0
			gap = 0.0
		if visible:
			run += DT
		else:
			gap += DT
		if was_visible and not visible:
			runs.append(run)
		was_visible = visible
	check("schedule/the first pass starts inside the 10-20 s window",
		first_at >= Stars.FIRST_WAIT.x and first_at <= Stars.FIRST_WAIT.y + DT, first_at)
	check("schedule/produced several passes to measure", runs.size() >= 6, "%d runs" % runs.size())
	var flight_bad := 0
	for duration in runs:
		# FLIGHT is reached by whole DT ticks, so one tick is the tolerance.
		if absf(duration - Stars.FLIGHT) > DT + 0.0001:
			flight_bad += 1
	check_eq("schedule/every pass is on screen for about a second", flight_bad, 0)
	var gap_bad := 0
	for g in gaps:
		if g < Stars.GAP_WAIT.x - DT or g > Stars.GAP_WAIT.y + DT:
			gap_bad += 1
	check_eq("schedule/every gap between passes is 20-40 s", gap_bad, 0)
	print("# SKY_REPORT passes=%d flights=%s gaps=%s" % [
		runs.size(), str(runs.slice(0, 3)), str(gaps.slice(0, 3))])
	root.remove_child(stars)
	stars.free()


# ---------------------------------------------------------------------------
# 8. No stale star
# ---------------------------------------------------------------------------

func _test_stale() -> void:
	var stars := _fresh()
	# Force a pass and let it finish.
	stars.wait_seconds = 0.0
	stars.step(DT)
	check("stale/a pass is in flight when the wait expires", stars.star.visible, "hidden")
	for i in 40:
		stars.step(DT)
	check("stale/a finished pass leaves nothing on screen", not stars.star.visible, "still visible")
	check("stale/a finished pass schedules the next gap in 20-40 s",
		stars.wait_seconds >= Stars.GAP_WAIT.x and stars.wait_seconds <= Stars.GAP_WAIT.y, stars.wait_seconds)
	# Mid-flight stop (the arena is rebuilt / the match ends) must clear it.
	stars.wait_seconds = 0.0
	stars.step(DT)
	stars.reset()
	check("stale/reset() clears a streak that is mid-flight",
		not stars.star.visible and stars.elapsed < 0.0, "stale star left behind")
	check("stale/reset() re-arms the first delay", stars.wait_seconds >= Stars.FIRST_WAIT.x
		and stars.wait_seconds <= Stars.FIRST_WAIT.y, stars.wait_seconds)
	root.remove_child(stars)
	stars.free()


# ---------------------------------------------------------------------------
# 5. The pause seam
# ---------------------------------------------------------------------------

func _test_pause() -> void:
	var pauser := Pauser.new()
	root.add_child(pauser)
	var stars := Stars.new()
	stars.name = "AuroraShootingStars"
	pauser.add_child(stars)
	pauser.paused = true
	var held := stars.wait_seconds
	await process_frame
	await process_frame
	check("pause/a paused match freezes the schedule",
		is_equal_approx(stars.wait_seconds, held), "%s vs %s" % [stars.wait_seconds, held])
	pauser.paused = false
	await process_frame
	await process_frame
	check("pause/an unpaused match runs the schedule again",
		stars.wait_seconds < held, "%s vs %s" % [stars.wait_seconds, held])
	root.remove_child(pauser)
	pauser.free()


# ---------------------------------------------------------------------------
# 1. Presence, and the negative in the other arenas
# ---------------------------------------------------------------------------

func _test_presence() -> void:
	var ids := ["aurora", "torii", "medina", "carioca", "egeo", "cattedrale"]
	for id in ids:
		var arena := Arena.build(id)
		root.add_child(arena)
		var scenery := arena.get_node_or_null("Scenery")
		var found := scenery.get_node_or_null("AuroraShootingStars") if scenery != null else null
		if id == "aurora":
			check("presence/aurora has exactly one shooting-star node", found != null, "missing")
			if found != null:
				check("presence/and it is the module, not a look-alike",
					found.get_script() == Stars, str(found.get_script()))
		else:
			check("presence/%s has no shooting stars" % id, found == null, "found one")
		root.remove_child(arena)
		arena.free()


# ---------------------------------------------------------------------------
# 6 and 7. The measured skyline, and no contact with the court
# ---------------------------------------------------------------------------

func _test_sky() -> void:
	var arena := Arena.build("aurora")
	root.add_child(arena)
	var scenery := arena.get_node("Scenery")
	var stars := scenery.get_node("AuroraShootingStars")
	stars.set_process(false)

	var holder := Node3D.new()
	root.add_child(holder)
	for preset in SKY_PRESETS + NO_SKY_PRESETS:
		var cam := Court.build_camera(holder, preset)
		_probe_preset(preset, cam, arena, stars)
		holder.remove_child(cam)
		cam.free()
	root.remove_child(holder)
	holder.free()
	root.remove_child(arena)
	arena.free()


func _probe_preset(preset: String, cam: Camera3D, arena: Node3D, stars: Node3D) -> void:
	var far_ok := cam.far > Stars.SKY_RADIUS * 1.5
	check("reach/%s far plane (%.0f) covers the star's %.0f m" % [preset, cam.far, Stars.SKY_RADIUS],
		far_ok, cam.far)
	var sky := _skyline(cam, arena)
	var skyline: float = sky["row"]
	var court_top := _court_top_row(cam)
	var into_arena := arena.global_transform.affine_inverse()
	var in_frame := 0
	var samples := 0
	var blocked := 0
	var blocker := "<none>"
	var over_court := 0
	var behind := 0
	var row_min := INF
	var row_max := -INF
	var alt_min := INF
	var alt_max := -INF
	# One full pass, sampled the way the game ticks it.
	stars.reset()
	stars.wait_seconds = 0.0
	var direction := Vector3.ZERO
	for i in 40:
		stars.step(DT)
		if not stars.star.visible:
			continue
		var pos: Vector3 = stars.star.position
		direction = stars.direction_now()
		var tail := pos - direction * Stars.TRAIL_LENGTH
		for point in [pos, tail]:
			samples += 1
			alt_min = minf(alt_min, _elevation_deg(cam, point))
			alt_max = maxf(alt_max, _elevation_deg(cam, point))
			if cam.is_position_behind(point):
				behind += 1
				continue
			var row: float = cam.unproject_position(point).y
			row_min = minf(row_min, row)
			row_max = maxf(row_max, row)
			if row >= 0.0 and row <= VIEWPORT.y:
				in_frame += 1
			var hit := _line_of_sight_blocker(cam, into_arena, arena, point)
			if hit != "":
				blocked += 1
				blocker = hit
			if row >= court_top:
				over_court += 1
	print("# SKY_REPORT preset=%-9s samples=%d in_frame=%d blocked=%d over_court=%d behind=%d star_rows=[%.1f,%.1f] star_alt_deg=[%.2f,%.2f] court_top_row=%.1f frame_top_alt_deg=%.2f" % [
		preset, samples, in_frame, blocked, over_court, behind, row_min, row_max, alt_min, alt_max,
		court_top, _frame_top_altitude(cam)])
	print("# SKY_REPORT preset=%-9s highest_silhouette=%s at %.2f deg (reported, not gated)" % [
		preset, sky["owner"], sky["alt_deg"]])
	if blocked > 0:
		print("# SKY_REPORT preset=%-9s blocked_by=%s" % [preset, blocker])
	check("sky/%s the star is never behind a camera" % preset, behind == 0, "%d behind" % behind)
	check("sky/%s the star never reaches the court's own row" % preset, over_court == 0,
		"%d of %d samples at or below row %.1f" % [over_court, samples, court_top])
	if preset in SKY_PRESETS:
		check("sky/%s the star's line of sight is clear of every arena mesh" % preset, blocked == 0,
			"%d of %d samples blocked by %s" % [blocked, samples, blocker])
		check("sky/%s the star really is inside the frame there" % preset, in_frame > 0,
			"%d of %d samples in frame" % [in_frame, samples])
	else:
		check("sky/%s has no sky, so the star is not drawn there at all" % preset, in_frame == 0,
			"%d of %d samples in frame" % [in_frame, samples])


## The first visible mesh whose own world bounds the camera-to-`point` segment
## crosses, or "" when the view is clear. Bounds are conservative (a mesh is
## tested through its own vertex bounds), so a pass cannot be bought by hiding a
## real occluder. The star's own geometry is the subject, not scenery, and is
## skipped: the segment ends on the head itself, whose trail is at that very spot.
func _line_of_sight_blocker(cam: Camera3D, into_arena: Transform3D, arena: Node3D, point: Vector3) -> String:
	var scenery := arena.get_node_or_null("Scenery")
	if scenery == null:
		return ""
	var subject := scenery.get_node_or_null("AuroraShootingStars")
	var from := into_arena * cam.global_position
	var to := into_arena * point
	for node in scenery.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		if subject != null and subject.is_ancestor_of(mi):
			continue
		if Common.world_aabb(mi, arena).intersects_segment(from, to):
			return String(arena.get_path_to(mi))
	return ""


## The highest row (smallest screen y) of anything the arena actually draws in this
## camera, sampled from every visible mesh's own vertex bounds, WITH the mesh that
## owns it and its elevation from the camera — so a failure names the silhouette
## rather than only a row. `row` is `INF` when nothing is in front of this camera.
func _skyline(cam: Camera3D, arena: Node3D) -> Dictionary:
	var best := INF
	var owner := "<none>"
	var owner_point := Vector3.ZERO
	var scenery := arena.get_node_or_null("Scenery")
	if scenery == null:
		return {"row": best, "owner": owner, "point": owner_point, "alt_deg": 0.0}
	for node in scenery.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var bounds := Common.world_aabb(mi, arena)
		for corner in 8:
			var point := bounds.get_endpoint(corner)
			if cam.is_position_behind(point):
				continue
			var px: Vector2 = cam.unproject_position(point)
			if px.x < 0.0 or px.x > VIEWPORT.x:
				continue
			if px.y < best:
				best = px.y
				owner = String(arena.get_path_to(mi))
				owner_point = point
	return {
		"row": best,
		"owner": owner,
		"point": owner_point,
		"alt_deg": _elevation_deg(cam, owner_point) if best < INF else 0.0,
	}


## The elevation above the horizon of a world point seen from the camera, in
## degrees. Reported, never asserted on: the gates use the renderer's own rows.
func _elevation_deg(cam: Camera3D, at: Vector3) -> float:
	var d := at - cam.global_position
	var flat := sqrt(d.x * d.x + d.z * d.z)
	return rad_to_deg(atan2(d.y, maxf(flat, 0.0001)))


## The elevation of the frame's own top row, so the report says how much sky a
## preset has at all.
func _frame_top_altitude(cam: Camera3D) -> float:
	return _elevation_deg(cam, cam.global_position + cam.project_ray_normal(Vector2(VIEWPORT.x * 0.5, 0.0)) * 100.0)


## The highest row of the court bed's own four corners — the lowest row the star
## may reach without ever being drawn over the playable area.
func _court_top_row(cam: Camera3D) -> float:
	var top := -INF
	for point in Common.required_points():
		if not String(point["name"]).begins_with("court_corner_"):
			continue
		var at: Vector3 = point["at"]
		if cam.is_position_behind(at):
			return -INF
		top = maxf(top, cam.unproject_position(at).y)
	return top


# ---------------------------------------------------------------------------
# The rendered half: an ACTIVE star, captured and checked in the same run
# ---------------------------------------------------------------------------

##   /Applications/Godot.app/Contents/MacOS/Godot --path godot \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     --script res://tests/aurora_shooting_stars_test.gd -- --capture=/abs/dir
##
## TWO frames of the same playable view: one with the star mid-flight (t = 0.5 of
## its pass, fully opaque) and one control frame with the same arena, camera and
## tick count but no star. The suite then samples the star's own projected pixel
## neighbourhood in BOTH images and requires the star frame to be brighter there —
## so the artifact proves an active star landed on the sky, not that a frame was
## written. Plain `--headless` installs the dummy renderer and every frame comes
## back blank; this refuses to certify itself in that state.
func _capture(dir: String) -> void:
	root.size = Vector2i(VIEWPORT)
	if DisplayServer.get_name() == "headless":
		print("CAPTURE_SKIP headless: the dummy renderer writes blank frames")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var arena := Arena.build("aurora")
	root.add_child(arena)
	var holder := Node3D.new()
	root.add_child(holder)
	var cam := Court.build_camera(holder, "playable")
	cam.current = true
	var stars := arena.get_node("Scenery/AuroraShootingStars")
	stars.set_process(false)
	stars.reset()
	await _settle()
	var control := await _shoot(dir.path_join("aurora-playable-nostar.png"))
	# Mid-flight: half of the second-long pass, so the streak is fully opaque.
	stars.wait_seconds = 0.0
	for i in 10:
		stars.step(DT)
	var at: Vector3 = stars.star.position
	var px: Vector2 = cam.unproject_position(at)
	var active := await _shoot(dir.path_join("aurora-playable-star.png"))
	var quiet := _brightest(control, px, 24)
	var lit := _brightest(active, px, 24)
	var found := _brightest_pixel(active, control)
	print("# CAPTURE_DIAG viewport=%s image=%s predicted_px=%s brightest=%s" % [
		str(root.get_visible_rect().size), str(active.get_size()), str(px.round()), str(found)])
	print("# CAPTURE_DIAG star_visible=%s head_vis=%s trail_vis=%s override_matches=%s head_albedo=%s trail_albedo=%s t=%.2f" % [
		stars.star.visible, stars.head.is_visible_in_tree(), stars.trail.is_visible_in_tree(),
		stars.head.material_override == stars.head_material,
		str(stars.head_material.albedo_color), str(stars.trail_material.albedo_color), stars.elapsed / Stars.FLIGHT])
	print("# CAPTURE star_visible=%s world=%s px=%s frame=%s" % [
		stars.star.visible, str(at), str(px.round()), str(VIEWPORT)])
	print("# CAPTURE luminance_at_star active=%.3f control=%.3f" % [lit, quiet])
	check("capture/the star is mid-flight when the frame is taken", stars.star.visible, "hidden")
	check("capture/the star's own pixel is brighter than the same pixel without it",
		lit > quiet + 0.05, "%.3f vs %.3f" % [lit, quiet])
	check("capture/the star is inside the frame it was captured in",
		px.x > 0.0 and px.x < VIEWPORT.x and px.y > 0.0 and px.y < VIEWPORT.y, str(px))
	print("AURORA_SHOOTING_STARS_CAPTURE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)


func _settle() -> void:
	for i in 4:
		await process_frame


## Draw and save one frame from the real viewport, returning the image.
func _shoot(path: String) -> Image:
	# Two full draws: a change made since the previous frame (the star's own
	# material alpha, for instance) can otherwise be read back one frame late, and
	# the capture would then certify the frame BEFORE the star became visible.
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("# CAPTURE wrote %s size=%s err=%d" % [path, str(image.get_size()), err])
	check("capture/%s written at the full capture size" % path.get_file(),
		err == OK and image.get_size() == Vector2i(VIEWPORT), "%s err=%d" % [str(image.get_size()), err])
	return image


## The brightest pixel in a square neighbourhood, as a 0-1 luminance.
func _brightest(image: Image, at: Vector2, radius: int) -> float:
	var best := 0.0
	for y in range(maxi(0, int(at.y) - radius), mini(image.get_height(), int(at.y) + radius)):
		for x in range(maxi(0, int(at.x) - radius), mini(image.get_width(), int(at.x) + radius)):
			var c := image.get_pixel(x, y)
			best = maxf(best, maxf(c.r, maxf(c.g, c.b)))
	return best


## The brightest pixel of the whole star frame that is NOT also bright in the
## control frame — i.e. where the star actually landed on screen. Diagnostics for
## the capture only; the gate is the neighbourhood check above.
func _brightest_pixel(active: Image, control: Image) -> Dictionary:
	var best := 0.0
	var at := Vector2i.ZERO
	for y in active.get_height():
		for x in active.get_width():
			var a := active.get_pixel(x, y)
			var b := control.get_pixel(x, y)
			var gain := maxf(a.r, maxf(a.g, a.b)) - maxf(b.r, maxf(b.g, b.b))
			if gain > best:
				best = gain
				at = Vector2i(x, y)
	return {"at": at, "gain": best}
