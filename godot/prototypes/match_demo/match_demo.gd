## match_demo.gd — the 30-second scripted-match capture probe (throwaway lane).
##
## WHAT IT IS. A `SceneTree` main loop that mounts the REAL match scene
## (`res://game/Match.tscn`, the shipping `match_controller.gd` with its shipping
## HUD) and drives it from the repo's own deterministic stand-in for a human
## (`res://game/scripted_player.gd`), against the simulation's own AI
## (`res://src/sim/sim.gd`) — the pairing the repo's audits use.
##
## BOOT ORDER, copied from `res://_probe_replay_card.gd` (the proven seam): the
## node is instantiated and added AFTER the tree is already iterating, so `_ready`
## runs on `add_child` and its UI mount block fires; `harness_mode()` is called
## AFTER `add_child`; the harness then owns the clock (`tick_fixed`) and the engine
## never runs its own frame loop on the match.
##
## FRAMES. `--probe=frames` advances `--ticks-per-frame` simulation ticks (120 Hz)
## per SAVED frame and writes one PNG per saved frame from the LIVE viewport
## (`root.get_texture().get_image()`), after `await RenderingServer.frame_post_draw`
## — the idiom of `res://tests/ui/capture_ui.gd` and
## `res://prototypes/camera_study/camera_study.gd`. A real window context is
## required: `--headless` installs the dummy driver and every frame is blank.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-driver opengl3 \
##     --path godot/ --resolution 1280x720 \
##     --script res://prototypes/match_demo/match_demo.gd \
##     -- --probe=frames --frames=900 --ticks-per-frame=4 --seed=20260916 \
##        --tier=3 --arena=torii --out=/tmp/padel-demo/frames
##
## `--probe=stats` is the cheap counter pass: no rendering, no PNGs, N seeds in one
## process, `--ticks` ticks each (headless-safe).
##
##   ... --script res://prototypes/match_demo/match_demo.gd -- \
##     --probe=stats --seeds=20260916,20260917,20260918 --ticks=3600 --tier=3
##
## WRITES ONLY: `--out=<abs dir>` and a temp save dir under `user://`
## (`user://match-demo-tmp`); the real `user://save` is never touched.
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const TICK := 1.0 / 120.0
const TEMP_SAVE := "user://match-demo-tmp"

var _bot: RefCounted
var _node: Node
var _frames_dir := ""
var _size := Vector2i(0, 0)
var _written: int = 0
var _blank: int = 0
var _points_at := []
var _points_seen: int = 0
var _ms_total: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var probe := _arg(args, "--probe=", "frames")
	await _run(args, probe)
	quit(0)


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _run(args: PackedStringArray, probe: String) -> void:
	Config.save_dir = TEMP_SAVE
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.camera_preset = _arg(args, "--camera=", "default")
	Config.tier_index = int(_arg(args, "--tier=", "3"))
	var arena := _arg(args, "--arena=", "")
	Config.seed_value = int(_arg(args, "--seed=", "20260916"))

	print("DEMO_BOOT engine=%s display=%s adapter=%s api=%s build=%s demo=%s camera=%s tier=%d save=%s" % [
		Engine.get_version_info().get("string", "?"), DisplayServer.get_name(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(),
		Gate.label(), str(Gate.is_demo()), Config.camera_preset, Config.tier_index, TEMP_SAVE,
	])
	print("DEMO_GATE world_offered=%s frozen_offered=%s modes=%s" % [
		JSON.stringify(Config.selectable_world_arenas().map(func(r): return String(r["id"]))),
		JSON.stringify(Config.selectable_arenas().map(func(r): return String(r["id"]))),
		JSON.stringify(Gate.modes()),
	])
	if arena != "":
		var granted: bool = Config.set_arena_id(arena)
		print("DEMO_ARENA requested=%s granted=%s effective=%s world_seat=%s family=%s" % [
			arena, str(granted), Config.arena_id(), Config.world_arena_id,
			String(Config.arena().get("family", "?")),
		])
	else:
		print("DEMO_ARENA requested=<none> effective=%s" % Config.arena_id())

	# The tree must be iterating before the node is created: a node added from
	# `_initialize()` (before the first iteration) gets its `_ready` deferred to
	# the first frame, which would run AFTER `harness_mode()` and skip the mount.
	for _i in 3:
		await process_frame

	_node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(_node)
	_node.harness_mode()
	_node.start_match()
	for _i in 3:
		await process_frame
	print("DEMO_MOUNT viewport=%s rigs=%d arena_meshes=%d ui_hud=%s windowed=%s" % [
		str(Vector2i(root.get_visible_rect().size)), _node.athletes_report().size(),
		_node.arena_mesh_count(), str(_node._ui_hud != null),
		str(DisplayServer.window_get_size()),
	])

	if probe == "stats":
		await _stats(args)
	else:
		await _frames(args)
	_node.free()
	await process_frame


## The counter pass: N seeds, `--ticks` ticks each, nothing rendered. The counters
## are the simulation's own (`state.stats`), the same ones `_observe` reads.
func _stats(args: PackedStringArray) -> void:
	var ticks := int(_arg(args, "--ticks=", "3600"))
	var seeds := _arg(args, "--seeds=", str(Config.seed_value)).split(",", false)
	for s in seeds:
		var seed_value := int(String(s).strip_edges())
		Config.seed_value = seed_value
		_bot = ScriptedPlayer.new()
		_node.start_match()
		for i in ticks:
			_node.tick_fixed(TICK, _bot.decide(_node.state), Sim.empty_input())
		print("PROBE_STATS %s" % JSON.stringify(_counters(seed_value, ticks * TICK)))


## The rendered pass: `--frames` saved frames, `--ticks-per-frame` ticks each.
func _frames(args: PackedStringArray) -> void:
	var frames := int(_arg(args, "--frames=", "900"))
	var per := int(_arg(args, "--ticks-per-frame=", "4"))
	_frames_dir = _arg(args, "--out=", "/tmp/padel-demo/frames")
	var mk := DirAccess.make_dir_recursive_absolute(_frames_dir)
	if mk != OK and not DirAccess.dir_exists_absolute(_frames_dir):
		print("DEMO_FATAL out=%s make_dir err=%d" % [_frames_dir, mk])
		return
	_bot = ScriptedPlayer.new()
	_points_seen = _points()

	var started := Time.get_ticks_msec()
	for f in frames:
		var t0 := Time.get_ticks_msec()
		for _t in per:
			_node.tick_fixed(TICK, _bot.decide(_node.state), Sim.empty_input())
		# The views and the HUD are synced by `_process` in an engine-driven match;
		# a harness that owns the clock syncs them itself (camera_study.gd does the
		# same, and `_observe` only refreshes the HUD 4 times a second).
		_node._sync_views()
		if _node._ui_hud != null:
			_node._ui_hud.refresh(_node.state, _node.meta)
		# The frame that gets saved is the frame that was just drawn.
		await RenderingServer.frame_post_draw
		var tex: ViewportTexture = root.get_texture()
		var img: Image = tex.get_image() if tex != null else null
		if img == null:
			print("DEMO_FATAL frame=%d reason=no_image" % f)
			return
		_size = Vector2i(img.get_width(), img.get_height())
		var path := "%s/frame_%05d.png" % [_frames_dir, f]
		var err := img.save_png(path)
		if err != OK:
			print("DEMO_FATAL frame=%d path=%s save_png err=%d" % [f, path, err])
			return
		_written += 1
		_ms_total += Time.get_ticks_msec() - t0
		var total := _points()
		if total > _points_seen:
			_points_seen = total
			_points_at.append({"frame": f, "tick": _node.ticks, "t": float(f) / 30.0,
				"playerScore": String(_node.state.playerScore), "aiScore": String(_node.state.aiScore),
				"who": String(_node.state.pointMessage)})
		if f % 60 == 0:
			var colours := _colours(img)
			if colours <= 1:
				_blank += 1
			print("DEMO_FRAME f=%d t=%.2fs ticks=%d points=%d rallyHits=%d longest=%d hits=%d colours=%d ms=%d" % [
				f, float(f) / 30.0, _node.ticks, total, int(_node.state.rallyHits),
				int(_node.state.stats["longestRally"]), int(_node.state.stats["totalRallyHits"]),
				colours, Time.get_ticks_msec() - t0,
			])
	print("DEMO_SUMMARY %s" % JSON.stringify(_counters(Config.seed_value, float(frames) / 30.0, frames, Time.get_ticks_msec() - started)))


func _counters(seed_value: int, seconds: float, frames: int = 0, elapsed_ms: int = 0) -> Dictionary:
	var stats: Dictionary = _node.state.stats
	var player_points: int = int(stats["pointsWon"]["player"])
	var ai_points: int = int(stats["pointsWon"]["ai"])
	return {
		"seed": seed_value,
		"tier_index": Config.tier_index,
		"tier": String(Config.tier()["id"]),
		"athlete": String(Config.athlete()["id"]),
		"arena": Config.arena_id(),
		"camera": Config.camera_preset,
		"mode": Config.pending_mode,
		"seconds": seconds,
		"ticks": _node.ticks,
		"points_played": player_points + ai_points,
		"points_player": player_points,
		"points_ai": ai_points,
		"points_events": _points_at,
		"score": "%s-%s" % [String(_node.state.playerScore), String(_node.state.aiScore)],
		"games": "%d-%d" % [int(_node.state.games["player"]), int(_node.state.games["ai"])],
		"total_paddle_hits": int(stats["totalRallyHits"]),
		"longest_rally": int(stats["longestRally"]),
		"rally_hits_now": int(_node.state.rallyHits),
		"crossings": _node.crossings,
		"frames": frames,
		"frames_written": _written,
		"blank_frames": _blank,
		"resolution": [ _size.x, _size.y ],
		"frames_dir": _frames_dir,
		"ms_total": elapsed_ms,
		"engine": Engine.get_version_info().get("string", "?"),
		"display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
	}


## The points the match has completed so far (`_points_total`, the same sum the
## controller's own `points_scored` uses).
func _points() -> int:
	if _node.state == null:
		return 0
	return int(_node.state.stats["pointsWon"]["player"]) + int(_node.state.stats["pointsWon"]["ai"])


## A 16x16 grid sample: one colour is the blank frame's signature (capture_ui.gd).
func _colours(img: Image) -> int:
	var seen := {}
	var step_x := maxi(img.get_width() / 16, 1)
	var step_y := maxi(img.get_height() / 16, 1)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			seen[img.get_pixel(x, y).to_rgba32()] = true
			y += step_y
		x += step_x
	return seen.size()

