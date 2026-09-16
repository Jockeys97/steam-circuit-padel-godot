## camera_study.gd — the camera/feel comparison artifact.
##
## WHAT THIS IS. A read-only study scene. It instantiates the REAL quick-match
## controller (`res://game/match_controller.gd`) — the real arena, the real court,
## the real HUD, the real simulation — freezes it on the game's own "rally" frame,
## and then renders ONE labelled frame per camera/HUD option without changing a
## single line of the game. Nothing here is a re-implementation: the first option
## is literally the composition `godot/game/run.sh shots` produces, because it is
## the same code with the same camera preset and the same HUD.
##
## WHAT IT WRITES (only into `res://prototypes/camera_study/out/`):
##   <option>__<W>x<H>.png        the frame as a player would see it (HUD on)
##   <option>__<W>x<H>__mask.png  a flat-colour ID pass of the same frame:
##                                one exact RGB per athlete, one for the ball,
##                                one for the court bed, everything else hidden.
##                                This is what the pixel measurement counts.
##   <option>__<W>x<H>.json       the engine's own numbers for that frame: camera,
##                                HUD panel rectangles, projected athlete/ball/court
##                                points, the simulation tick it was frozen on.
##   index__<W>x<H>.json          all of the above, in one file, plus the run log.
##
## WHY A MASK PASS. "How much of this athlete is hidden behind the HUD" is a pixel
## question, and a beauty frame cannot answer it: the athlete's own texture shares
## colours with the court. The ID pass gives every body an exact, unique RGB, so
## counting is arithmetic rather than judgement. The mask pass hides the glass, so
## a body standing behind a translucent pane counts as visible — stated, not hidden.
##
## HOST RULES. Software GL (Xvfb + Mesa llvmpipe) through `render.sh`, one Godot
## process, always under the shared lock. These frames are correctness/composition
## evidence ONLY. They say nothing whatsoever about frame rate.
##
## NO VERDICT IS MADE HERE. This scene produces the material for the owner's
## decision; it does not take it.
extends Node3D

const MatchController := preload("res://game/match_controller.gd")
const Court := preload("res://game/court.gd")
const HudScript := preload("res://game/hud.gd")
const Sim := preload("res://src/sim/sim.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

const FIXED_STEP := 1.0 / 120.0
const OUT_DIR := "res://prototypes/camera_study/out"

## Rig height, measured by the athlete lane from the bone extent in the base pose
## (`docs/wayfinder/evidence/athlete-roster-and-spawn.md`). Used only to name the
## "top of the head" point that gets projected; the pixel counts do not use it.
const ATHLETE_H := 1.678

## The keys the match controller uses for its four bodies, near pair first.
const NEAR_KEYS := ["player", "playerMate"]
const FAR_KEYS := ["opponent", "opponentMate"]
const ALL_KEYS := ["player", "playerMate", "opponent", "opponentMate"]

## Exact, unique, unshaded RGB per subject in the ID pass. Primaries and their
## pairwise mixes: the furthest apart 8-bit colours available, so a classifier with
## a generous tolerance can never confuse two subjects.
const MASK_COLORS := {
	"player": Color8(255, 0, 0),
	"playerMate": Color8(0, 255, 0),
	"opponent": Color8(0, 0, 255),
	"opponentMate": Color8(255, 0, 255),
	"ball": Color8(255, 255, 0),
	"court": Color8(0, 255, 255),
}

## The athlete/outfit each body is spawned with when bodies=rig. Fixed so two runs
## are comparable; the reference order of `AthleteSpawn.ids()`.
const RIG_CAST := {
	"player": [&"maestro", &"base"],
	"playerMate": [&"pantera", &"base"],
	"opponent": [&"steamer", &"base"],
	"opponentMate": [&"fiamma", &"base"],
}

## The options. `cam`: which camera. `hud`: which HUD layout. `why`: one line, the
## justification that goes into the evidence file.
const OPTIONS := [
	{
		"id": "current-composition",
		"cam": "game-default",
		"hud": "as-shipped",
		"why": "The composition the game produces today: game/court.gd preset 'default' with the shipping HUD. The baseline everything else is measured against.",
	},
	{
		"id": "raised-backed-off",
		"cam": "dolly-solved",
		"solve": "near-feet",
		"hud": "as-shipped",
		"why": "Same look, same pitch, same FOV: the camera is dollied straight back along its own view axis until the near pair's feet, where they stand on this frozen frame, clear the bottom HUD band. The smallest camera move that fixes today's frame.",
	},
	{
		"id": "slim-bottom-band",
		"cam": "game-default",
		"hud": "slim",
		"why": "Camera untouched; the bottom band is the thing that shrinks. Log panel cut to two smaller lines, feedback panel kept where the reference puts it but reduced to the score word and the energy bar.",
	},
	{
		"id": "raised-and-slim-band",
		"cam": "dolly-solved",
		"solve": "near-baseline",
		"hud": "slim",
		"why": "The slim band plus the camera backed off until the whole NEAR BASELINE clears it - so a player standing anywhere on their own half is readable, not just where they happen to stand on this frame. The strict version, and the one that shows what that strictness costs.",
	},
	{
		"id": "tactical-wide",
		"cam": "preset-wide",
		"hud": "as-shipped",
		"why": "The existing 'wide' preset already in game/court.gd (16.62 m up, -68 deg, 60 deg FOV): a higher tactical view, no new art direction, so the owner can see what more court costs in ball size.",
	},
	{
		"id": "behind-the-baseline",
		"cam": "preset-playable",
		"hud": "as-shipped",
		"why": "The existing 'playable' preset already in game/court.gd (3.2 m up, level, looking at the net): the closest behind-the-server view the port has ever rendered, and the one that reads footwork best.",
	},
]

var _ctrl: Node3D
var _log: Array = []
var _bodies_mode := "game"
var _frozen := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_bodies_mode = _arg(args, "--bodies=", "game")
	_note("STUDY_START bodies=%s driver=%s display=%s" % [
		_bodies_mode, RenderingServer.get_video_adapter_name(), DisplayServer.get_name(),
	])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _run()


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _note(line: String) -> void:
	_log.append(line)
	print(line)


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

func _run() -> void:
	_build_match()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	if _bodies_mode == "rig":
		_swap_in_rigs()
	else:
		var rigs := 0
		for key in ALL_KEYS:
			var root: Node3D = _ctrl._athlete_roots.get(key)
			if root != null and root.has_method("play_locomotion"):
				rigs += 1
		_note("BODIES game rigs=%d/%d source=match_controller.build_athletes()" % [rigs, ALL_KEYS.size()])

	_freeze_on_rally()

	var vp := get_viewport()
	var frame: Vector2 = Vector2(vp.get_visible_rect().size)
	_note("FRAME size=%dx%d" % [int(frame.x), int(frame.y)])

	var saved_hud := _capture_hud_layout()
	var index := {
		"frame": {"w": int(frame.x), "h": int(frame.y)},
		"bodies": _bodies_mode,
		"athlete_source": _athlete_source(),
		"frozen": _frozen,
		"mask_colors": _mask_color_table(),
		"options": [],
	}

	for opt in OPTIONS:
		_restore_hud_layout(saved_hud)
		_apply_hud(String(opt["hud"]))
		var cam_info := _apply_camera(String(opt["cam"]), String(opt.get("solve", "near-feet")))
		_ctrl._sync_views()
		_ctrl._hud.refresh(_ctrl.state, _ctrl.meta)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var tag := "%s__%dx%d" % [String(opt["id"]), int(frame.x), int(frame.y)]
		await _save_frame("%s/%s.png" % [OUT_DIR, tag])
		var geom := _measure_geometry(frame)
		await _render_mask("%s/%s__mask.png" % [OUT_DIR, tag])

		var record := {
			"id": String(opt["id"]),
			"why": String(opt["why"]),
			"cam_mode": String(opt["cam"]),
			"hud_mode": String(opt["hud"]),
			"camera": cam_info,
			"beauty_png": "%s.png" % tag,
			"mask_png": "%s__mask.png" % tag,
			"frame": {"w": int(frame.x), "h": int(frame.y)},
			"hud_panels": _hud_rects(frame),
			"geometry": geom,
		}
		_write_json("%s/%s.json" % [OUT_DIR, tag], record)
		index["options"].append(record)
		_note("OPTION_DONE id=%s cam=%s hud=%s png=%s.png" % [
			String(opt["id"]), String(opt["cam"]), String(opt["hud"]), tag,
		])

	index["log"] = _log
	_write_json("%s/index__%dx%d.json" % [OUT_DIR, int(frame.x), int(frame.y)], index)
	_note("STUDY_PASS options=%d frame=%dx%d bodies=%s mem_mb=%.1f" % [
		OPTIONS.size(), int(frame.x), int(frame.y), _bodies_mode,
		float(OS.get_static_memory_usage()) / 1048576.0,
	])
	get_tree().quit(0)


## The real match scene, built by the real controller. Its engine clock is switched
## off immediately: this study drives the ticks itself so every option renders the
## SAME simulation frame and the only difference between two images is the option.
func _build_match() -> void:
	_ctrl = Node3D.new()
	_ctrl.name = "Match"
	_ctrl.set_script(MatchController)
	add_child(_ctrl)
	_ctrl.engine_driven = false
	_ctrl.set_physics_process(false)
	_ctrl.set_process(false)
	_note("MATCH_BUILT arena=%s cam_preset=%s" % [
		str(_ctrl.meta.get("arena", "?")), str(_ctrl.meta.get("camera", "?")),
	])


## Replaces each body with a rig from the shipping spawn seam
## (`src/character/athlete_spawn.gd`), so the study shows the athletes the port
## actually ships rather than the study's own approximation. The controller's own
## root node — and therefore all of its position/facing logic — is untouched: the
## rig is parented under it and the old body is hidden, not deleted.
##
## If the seam returns null (or the GLBs cannot be held in this host's RAM), the
## controller's own bodies stay on screen and the run records bodies=game.
func _swap_in_rigs() -> void:
	var made := 0
	for key in ALL_KEYS:
		var root: Node3D = _ctrl._athlete_roots[key]
		var cast: Array = RIG_CAST[key]
		var rig := AthleteSpawn.make(cast[0], cast[1], {
			"locomotion": &"idle",
			"name": "Rig_%s" % key,
		})
		if rig == null:
			_note("RIG_FAIL key=%s athlete=%s outfit=%s" % [key, cast[0], cast[1]])
			continue
		for child in root.get_children():
			if child.name != "TintRing":
				child.visible = false
		root.add_child(rig)
		made += 1
	if made == ALL_KEYS.size():
		_note("BODIES rig spawned=%d seam=src/character/athlete_spawn.gd" % made)
	else:
		_bodies_mode = "game" if made == 0 else "mixed"
		_note("BODIES fallback mode=%s spawned=%d/%d" % [_bodies_mode, made, ALL_KEYS.size()])


## Steps the real simulation to the SAME predicate the game's own capture plan uses
## for `rally.png` (`game/match_controller.gd:_capture_plan`): three rally hits and
## the ball below 140 px of height. Same seed, same tier, same scripted player, so
## this is the game's own rally frame, not a pose this study invented.
func _freeze_on_rally() -> void:
	var guard := 0
	while guard < 40000:
		var s = _ctrl.state
		if int(s.rallyHits) >= 3 and float(s.ball.z) < 140.0:
			break
		var input: Dictionary = _ctrl._scripted.decide(s)
		_ctrl.tick_fixed(FIXED_STEP, input, Sim.empty_input())
		guard += 1
	_ctrl._sync_views()
	_ctrl._hud.refresh(_ctrl.state, _ctrl.meta)
	var st = _ctrl.state
	_frozen = {
		"tick": _ctrl.ticks,
		"rally_hits": int(st.rallyHits),
		"ball_px": {"x": float(st.ball.x), "y": float(st.ball.y), "z": float(st.ball.z)},
		"ball_world": _v3(_ctrl._ball_view.position),
		"ball_scale": float(_ctrl._ball_view.scale.x),
		"score": "%s-%s" % [String(st.playerScore), String(st.aiScore)],
		"predicate": "rallyHits>=3 and ball.z<140 (game/match_controller.gd capture plan, rally.png)",
	}
	_note("FROZEN tick=%d rally=%d ball_px=(%.1f,%.1f,%.1f) score=%s" % [
		_ctrl.ticks, int(st.rallyHits), float(st.ball.x), float(st.ball.y), float(st.ball.z),
		String(st.playerScore) + "-" + String(st.aiScore),
	])


# ---------------------------------------------------------------------------
# Cameras
# ---------------------------------------------------------------------------

func _apply_camera(mode: String, solve := "near-feet") -> Dictionary:
	var cam: Camera3D = _ctrl._cam
	var base: Dictionary = Court.CAMERAS["default"]
	var dolly := 0.0
	match mode:
		"game-default":
			cam.fov = float(base["fov"])
			cam.position = base["pos"]
			cam.rotation_degrees = Vector3(float(base["pitch_deg"]), 0.0, 0.0)
		"dolly-solved":
			cam.fov = float(base["fov"])
			cam.rotation_degrees = Vector3(float(base["pitch_deg"]), 0.0, 0.0)
			dolly = _solve_dolly(cam, base, solve)
			var p0: Vector3 = base["pos"]
			cam.position = p0 + _back_dir(float(base["pitch_deg"])) * dolly
		"preset-wide":
			var w: Dictionary = Court.CAMERAS["wide"]
			cam.fov = float(w["fov"])
			cam.position = w["pos"]
			cam.rotation_degrees = Vector3(float(w["pitch_deg"]), 0.0, 0.0)
		"preset-playable":
			var p: Dictionary = Court.CAMERAS["playable"]
			cam.fov = float(p["fov"])
			cam.position = p["pos"]
			cam.look_at(p["look_at"], Vector3.UP)
	return {
		"mode": mode,
		"solve": solve if mode == "dolly-solved" else "",
		"dolly_back_m": dolly,
		"position": _v3(cam.position),
		"rotation_degrees": _v3(cam.rotation_degrees),
		"fov": float(cam.fov),
	}


## Unit vector straight backwards along the view axis of a camera pitched `pitch`
## degrees with no yaw: moving along it changes nothing but distance, which is why
## the "raised/backed-off" option keeps the composition identical.
func _back_dir(pitch_deg: float) -> Vector3:
	var p := deg_to_rad(-pitch_deg)
	return Vector3(0.0, sin(p), cos(p)).normalized()


## How far back the camera has to go for the lowest thing we care about to sit above
## the top of the bottom HUD band, with a 10 px margin. Two criteria:
##
##   "near-feet"     the near pair's feet WHERE THEY STAND on this frozen frame.
##                   The smallest move that fixes this frame; says nothing about
##                   where the players will be on the next one.
##   "near-baseline" the near baseline itself (both near court corners and the
##                   middle of that line). Holds for a player standing anywhere on
##                   their own half, which is the property a shipped camera needs.
##
## Bisection on a monotone quantity (backing straight off along the view axis can
## only move a near object up the frame), 30 iterations. The solved distance is
## written into the JSON, so the number is checkable rather than taste.
func _solve_dolly(cam: Camera3D, base: Dictionary, criterion: String) -> float:
	var frame := Vector2(get_viewport().get_visible_rect().size)
	var band_top := _bottom_band_top(frame)
	var target := band_top - 10.0
	var dir := _back_dir(float(base["pitch_deg"]))
	var origin: Vector3 = base["pos"]
	var saved := cam.position

	var probes: Array = []
	if criterion == "near-baseline":
		var hl := Court.half_len()
		var hd := Court.half_depth()
		probes = [Vector3(-hl, 0.0, hd), Vector3(0.0, 0.0, hd), Vector3(hl, 0.0, hd)]

	var f := func(t: float) -> float:
		cam.position = origin + dir * t
		var worst := -1e9
		if probes.is_empty():
			for key in NEAR_KEYS:
				var root: Node3D = _ctrl._athlete_roots[key]
				worst = maxf(worst, cam.unproject_position(root.global_position).y)
		else:
			for p in probes:
				worst = maxf(worst, cam.unproject_position(p).y)
		return worst

	var lo := 0.0
	var hi := 40.0
	var at_zero: float = f.call(0.0)
	var at_hi: float = f.call(hi)
	var t := hi
	if at_zero <= target:
		t = 0.0
	elif at_hi > target:
		t = hi
	else:
		for _i in 30:
			var mid := (lo + hi) * 0.5
			if f.call(mid) > target:
				lo = mid
			else:
				hi = mid
		t = hi
	cam.position = saved
	_note("SOLVE_DOLLY criterion=%s t=%.4f band_top=%.1f target=%.1f probe_y_at_0=%.1f probe_y_at_t=%.1f" % [
		criterion, t, band_top, target, at_zero, f.call(t),
	])
	cam.position = saved
	return t


## The top edge of the bottom HUD band: the highest top edge among the panels that
## live in the bottom half of the frame. Read off the live HUD, not hard-coded.
func _bottom_band_top(frame: Vector2) -> float:
	var top := frame.y
	for panel in _ctrl._hud.panels():
		var r: Rect2 = HudScript.panel_rect(panel, frame)
		if r.position.y > frame.y * 0.5:
			top = minf(top, r.position.y)
	return top


# ---------------------------------------------------------------------------
# HUD variants
# ---------------------------------------------------------------------------

func _capture_hud_layout() -> Array:
	var saved := []
	var labels := {}
	for panel in _ctrl._hud.panels():
		if panel.name == "LogPanel" or panel.name == "FeedbackPanel":
			for l in panel.find_children("*", "Label", true, false):
				labels[l] = {"size": l.get_theme_font_size("font_size"), "visible": l.visible}
		saved.append({
			"panel": panel,
			"al": panel.anchor_left, "ar": panel.anchor_right,
			"at": panel.anchor_top, "ab": panel.anchor_bottom,
			"ol": panel.offset_left, "orr": panel.offset_right,
			"ot": panel.offset_top, "ob": panel.offset_bottom,
			"visible": panel.visible,
		})
	saved.append({"labels": labels})
	return saved


func _restore_hud_layout(saved: Array) -> void:
	for entry in saved:
		if entry.has("labels"):
			var labels: Dictionary = entry["labels"]
			for l in labels:
				var lab: Label = l
				lab.add_theme_font_size_override("font_size", int(labels[l]["size"]))
				lab.visible = bool(labels[l]["visible"])
			continue
		var panel: Control = entry["panel"]
		panel.anchor_left = entry["al"]
		panel.anchor_right = entry["ar"]
		panel.anchor_top = entry["at"]
		panel.anchor_bottom = entry["ab"]
		panel.offset_left = entry["ol"]
		panel.offset_right = entry["orr"]
		panel.offset_top = entry["ot"]
		panel.offset_bottom = entry["ob"]
		panel.visible = entry["visible"]


## The "slimmer bottom band".
##
## WHAT THE FIRST ATTEMPT TAUGHT (kept in `out/attempt1-reposition/`): a panel's
## rectangle is NOT its offsets. `hud.gd:panel_rect` takes the larger of the offset
## span and the panel's own minimum size, and the feedback panel's minimum size is
## its 40 px score word plus its mode line plus its energy bar. Shrinking the box
## alone bought 22 px of band. Moving the box instead - the feedback panel to the
## bottom-right corner - bought the near player back and buried the near PARTNER,
## who stands on that side: -987 readable pixels on them. Repositioning inside a
## band that tall only moves the collision around.
##
## So this version shrinks the CONTENT, which is what actually sets the height, and
## leaves both panels where the reference build puts them:
##   - log panel: two lines instead of five, at 13 px instead of 17, title 14 px;
##   - feedback panel: the score word at 26 px instead of 40, the mode line
##     ("BILANCIATO") dropped, the energy caption at 14 px. The bar itself is
##     untouched.
## Same panels, same stylebox, same positions, same colours - less text. The mode
## line is real information and dropping it is a trade the owner has to accept or
## reject; it is called out in the evidence rather than hidden.
##
## Everything goes through the HUD's own anchors/offsets/theme overrides and its own
## `apply_safe_area()`. Nothing in `game/hud.gd` is edited.
func _apply_hud(mode: String) -> void:
	if mode != "slim":
		_ctrl._hud.apply_safe_area()
		return
	var hud = _ctrl._hud
	for i in hud._log_lines.size():
		hud._log_lines[i].visible = i < 2
		hud._log_lines[i].add_theme_font_size_override("font_size", 13)
	hud._feedback.add_theme_font_size_override("font_size", 26)
	hud._feedback_mode.visible = false
	hud._energy_label.add_theme_font_size_override("font_size", 14)
	for panel in hud.panels():
		match panel.name:
			"LogPanel":
				for l in panel.find_children("*", "Label", true, false):
					if not (l in hud._log_lines):
						l.add_theme_font_size_override("font_size", 14)
				panel.offset_top = -108.0
				panel.offset_bottom = -12.0
				panel.offset_left = 12.0
				panel.offset_right = 432.0
			"FeedbackPanel":
				panel.offset_top = -108.0
				panel.offset_bottom = -12.0
	hud.apply_safe_area()


func _hud_rects(frame: Vector2) -> Array:
	var out := []
	for panel in _ctrl._hud.panels():
		if not panel.visible:
			continue
		var r: Rect2 = HudScript.panel_rect(panel, frame)
		out.append({
			"name": String(panel.name),
			"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y,
		})
	return out


# ---------------------------------------------------------------------------
# Geometry the engine can state exactly (the pixel pass measures the rest)
# ---------------------------------------------------------------------------

func _measure_geometry(frame: Vector2) -> Dictionary:
	var cam: Camera3D = _ctrl._cam
	var out := {"athletes": {}, "frame": {"w": frame.x, "h": frame.y}}

	for key in ALL_KEYS:
		var root: Node3D = _ctrl._athlete_roots[key]
		var feet: Vector3 = root.global_position
		var head: Vector3 = feet + Vector3(0.0, ATHLETE_H, 0.0)
		out["athletes"][key] = {
			"world": _v3(feet),
			"feet_px": _proj(cam, feet),
			"head_px": _proj(cam, head),
			"near": key in NEAR_KEYS,
		}

	var ball_pos: Vector3 = _ctrl._ball_view.position
	var r: float = Court.BALL_R * float(_ctrl._ball_view.scale.x)
	var right: Vector3 = cam.global_transform.basis.x.normalized()
	var c := _proj(cam, ball_pos)
	var e := _proj(cam, ball_pos + right * r)
	out["ball"] = {
		"world": _v3(ball_pos),
		"radius_m": r,
		"centre_px": c,
		"radius_px": Vector2(float(c["x"]) - float(e["x"]), float(c["y"]) - float(e["y"])).length(),
		"behind_camera": bool(c["behind"]),
	}

	var hl := Court.half_len()
	var hd := Court.half_depth()
	out["court_corners_px"] = {
		"near_left": _proj(cam, Vector3(-hl, 0.0, hd)),
		"near_right": _proj(cam, Vector3(hl, 0.0, hd)),
		"far_left": _proj(cam, Vector3(-hl, 0.0, -hd)),
		"far_right": _proj(cam, Vector3(hl, 0.0, -hd)),
		"net_left": _proj(cam, Vector3(-hl, 0.0, 0.0)),
		"net_right": _proj(cam, Vector3(hl, 0.0, 0.0)),
	}
	out["court_m"] = {"length": Court.court_len(), "depth": Court.court_depth()}

	# The projected court quad is the natural "how much court do I see" measure for a
	# top-down camera, and it is useless for a low one: at the behind-the-baseline
	# preset the near corners project thousands of pixels off-screen, so the quad's
	# AREA ratio reports 1% for a frame that is more than half court. A uniform grid
	# of points ON the court floor does not have that failure mode: it answers "what
	# share of the playing surface can the player see", flat, for every camera.
	var gx := 41
	var gz := 27
	var inside := 0
	var near_half_inside := 0
	var near_half_total := 0
	for ix in gx:
		for iz in gz:
			var x := -hl + 2.0 * hl * float(ix) / float(gx - 1)
			var z := -hd + 2.0 * hd * float(iz) / float(gz - 1)
			var p := Vector3(x, 0.0, z)
			var s := cam.unproject_position(p)
			var vis := (not cam.is_position_behind(p)) and s.x >= 0.0 and s.y >= 0.0 \
				and s.x <= frame.x and s.y <= frame.y
			if vis:
				inside += 1
			if z > 0.0:
				near_half_total += 1
				if vis:
					near_half_inside += 1
	out["court_grid"] = {
		"samples": gx * gz,
		"in_frame": inside,
		"in_frame_pct": 100.0 * float(inside) / float(gx * gz),
		"near_half_samples": near_half_total,
		"near_half_in_frame": near_half_inside,
		"near_half_in_frame_pct": 100.0 * float(near_half_inside) / float(maxi(near_half_total, 1)),
	}
	return out


func _proj(cam: Camera3D, p: Vector3) -> Dictionary:
	var s := cam.unproject_position(p)
	return {"x": s.x, "y": s.y, "behind": cam.is_position_behind(p)}


func _v3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


## What the four bodies on screen actually are, read off the nodes rather than
## assumed: the shipping rig exposes `play_locomotion`, the capsule fallback does not.
func _athlete_source() -> Dictionary:
	var out := {}
	for key in ALL_KEYS:
		var root: Node3D = _ctrl._athlete_roots.get(key)
		out[key] = {
			"node": String(root.name) if root != null else "<missing>",
			"is_rig": root != null and root.has_method("play_locomotion"),
			"class": root.get_class() if root != null else "",
		}
	return out


func _mask_color_table() -> Dictionary:
	var out := {}
	for k in MASK_COLORS:
		var c: Color = MASK_COLORS[k]
		out[k] = [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]
	return out


# ---------------------------------------------------------------------------
# The ID pass
# ---------------------------------------------------------------------------

## Renders the same camera/HUD state as a flat-colour ID image and restores every
## node afterwards. Hidden for the pass: the HUD, the glass cage, the net, the
## scenery, the lines, the rackets, the land ring — everything except the four
## bodies, the ball and the court bed. Unshaded materials plus a bare black
## environment mean each subject lands on its exact RGB, so counting is exact.
func _render_mask(path: String) -> void:
	var vp := get_viewport()
	var saved_msaa := vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED

	var meshes: Array = _ctrl.find_children("*", "MeshInstance3D", true, false)
	var saved_vis := {}
	var saved_mat := {}
	for mi in meshes:
		saved_vis[mi] = mi.visible
		saved_mat[mi] = mi.material_override
		mi.visible = false

	var hud_layer: CanvasLayer = _ctrl.get_node_or_null("HudLayer")
	var saved_hud_vis := true
	if hud_layer != null:
		saved_hud_vis = hud_layer.visible
		hud_layer.visible = false

	var we: WorldEnvironment = _ctrl.find_child("WorldEnvironment", true, false)
	var saved_env: Environment = null
	if we != null:
		saved_env = we.environment
		var flat := Environment.new()
		flat.background_mode = Environment.BG_COLOR
		flat.background_color = Color(0, 0, 0)
		flat.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
		flat.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		we.environment = flat

	var bed: MeshInstance3D = null
	if _ctrl._arena_root != null:
		bed = _ctrl._arena_root.find_child("Court", true, false)
	if bed != null:
		bed.visible = true
		bed.material_override = _flat(MASK_COLORS["court"])

	if _ctrl._ball_view != null:
		_ctrl._ball_view.visible = true
		_ctrl._ball_view.material_override = _flat(MASK_COLORS["ball"])

	for key in ALL_KEYS:
		var root: Node3D = _ctrl._athlete_roots[key]
		# Excluded from the body: the team ring on the floor, and the racket - which
		# since the athletes-view integration is a CHILD of the rig, so a naive walk
		# would count it as body pixels.
		var skip: Array[Node] = []
		var ring: Node = root.get_node_or_null("TintRing")
		if ring != null:
			skip.append(ring)
		var racket = _ctrl._paddle_views.get(key)
		if racket != null and is_instance_valid(racket):
			skip.append(racket)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var excluded := false
			for s_node in skip:
				if mi == s_node or s_node.is_ancestor_of(mi):
					excluded = true
					break
			if excluded:
				continue
			mi.visible = true
			mi.material_override = _flat(MASK_COLORS[key])

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await _save_frame(path)

	for mi in meshes:
		mi.visible = saved_vis[mi]
		mi.material_override = saved_mat[mi]
	if hud_layer != null:
		hud_layer.visible = saved_hud_vis
	if we != null:
		we.environment = saved_env
	vp.msaa_3d = saved_msaa
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = false
	return m


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

func _save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex == null:
		_note("SAVE_FAIL reason=no_texture path=%s" % path)
		return
	var img: Image = tex.get_image()
	if img == null:
		_note("SAVE_FAIL reason=no_image path=%s" % path)
		return
	var err := img.save_png(path)
	_note("SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_note("JSON_FAIL path=%s err=%d" % [path, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	_note("JSON path=%s" % path)
