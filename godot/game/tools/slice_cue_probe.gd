extends SceneTree
## slice_cue_probe.gd — one probe, two questions, both raised by the owner after
## playing the 3D build against the browser reference:
##
##   1. "con X non vedo la palla tagliata" — the physics was there
##      (`sim.gd:1662`, identical to `js/game.js:1671`) but neither of the browser's
##      two cues had been ported. They are now in `match_controller.gd`
##      (`_sync_ball_cues`), and this probe is how you see them without playing.
##   2. "con A la traiettoria mi sembra piu' alta" — measured and true: the port maps
##      height at 0.025 m/px and width at 11.0/800 = 0.01375 m/px, so an arc is drawn
##      1.82x higher relative to the court than the browser draws it. The simulation
##      is not involved (match parity is intact). The lever chosen by the owner is the
##      camera: the match preset looks down at -65.2 deg, and a camera that steep
##      turns "the ball rose" and "the ball went away" into the same screen motion.
##
## It plays a real quick match with the deterministic scripted player, forces every
## shot to be a slice, stops at the first frame where the cut is actually on the ball
## (`backspin > 0.08`, the browser's own threshold) and photographs THAT ONE INSTANT
## from every candidate camera pitch. Same ball, same tick, four cameras: the only
## honest way to compare.
##
## Run: godot/game/tools/slice_cue_run.sh
## Writes out/slice-cue-<pitch>.png and prints one MEASURE line per capture.

const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Court := preload("res://game/court.gd")

const MATCH_SCENE := "res://game/Match.tscn"
const OUT_DIR := "res://game/tools/out"
const DT := 1.0 / 120.0
## Enough ticks to get through the serve and into a rally; the run stops as soon as
## the cut is on the ball, so this is a ceiling and not a duration.
const MAX_TICKS := 4000
## The browser's ring threshold (`js/render.js:1546`): below this there is no cut to
## photograph and waiting for a frame would be photographing nothing.
const CUT_VISIBLE := 0.08
## The cut has to be photographed where all four framings can see it. A ball still
## over the server's baseline leaves the frame as soon as the camera drops, so the
## probe waits for one crossing the net: same cut, visible from every pitch.
const NET_WINDOW_PX := 90.0

## Camera distance from the court centre, kept constant so the four frames differ in
## pitch ONLY: the current preset sits at 15.81 m (pos 0,14.4552,6.4).
const CAM_DISTANCE := 15.81
## 22.5 deg is not a guess: it is the pitch the browser's fake perspective implies.
## Its court quad draws 20 m of depth over 487 px and 11 m of width over ~700 px, so
## the depth axis is foreshortened by (487/20)/(700/11) = 0.383 = sin(pitch)
## (`js/render.js:736-750`). Whatever the 3D build finally uses, this is the framing
## the reference art was composed for.
const PITCHES := [65.2, 45.0, 35.0, 22.5]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Config.pending_mode = "quick"
	Config.pending_round = -1

	var packed: PackedScene = load(MATCH_SCENE)
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame

	var driver = ScriptedPlayer.new()
	var idle: Dictionary = Sim.empty_input()
	var ticks := 0
	var found := false
	while ticks < MAX_TICKS and not found:
		# Four simulation ticks per rendered frame: the tick is a pure function of
		# (dt, input), so this only makes the probe reach a rally sooner. It does not
		# change what the tick computes.
		for _i in 4:
			var input: Dictionary = driver.decide(game.state)
			# The owner's complaint is about X, so every shot this probe plays is one.
			input["slice"] = true
			game.tick_fixed(DT, input, idle)
			ticks += 1
			var ball = game.state.ball
			var near_net: bool = absf(float(ball.y) - float(Frozen.court()["netY"])) < NET_WINDOW_PX
			# Not the serve: the serve is struck deep behind the baseline and leaves the
			# frame as soon as the camera drops. A rally ball crossing the net is the
			# shot the owner is actually looking at when he says he cannot see the cut.
			var in_rally: bool = int(game.state.rallyHits) >= 1
			if float(ball.backspin) > CUT_VISIBLE and float(ball.z) > 20.0 and near_net and in_rally:
				found = true
				break
		await process_frame

	if not found:
		printerr("SLICE_CUE_FAIL: no cut ball within %d ticks" % MAX_TICKS)
		quit(1)
		return

	var ball = game.state.ball
	print("CUT tick=%d rally=%d pos=(%.0f,%.0f) backspin=%.3f spin=%.1f z=%.1f speed=%.1f" % [
		ticks, int(game.state.rallyHits), float(ball.x), float(ball.y),
		float(ball.backspin), float(ball.spin), float(ball.z),
		sqrt(float(ball.vx) * float(ball.vx) + float(ball.vy) * float(ball.vy))])

	var cam: Camera3D = root.get_camera_3d()
	if cam == null:
		printerr("SLICE_CUE_FAIL: no camera")
		quit(1)
		return

	# From here on the simulation is frozen: every frame below is the same instant.
	for pitch in PITCHES:
		var radians: float = deg_to_rad(pitch)
		cam.position = Vector3(0.0, CAM_DISTANCE * sin(radians), CAM_DISTANCE * cos(radians))
		cam.look_at(Vector3.ZERO, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path := "%s/slice-cue-pitch%02d.png" % [OUT_DIR, int(pitch)]
		var err := image.save_png(path)
		var ball_world: Vector3 = Court.world_pos(
			float(ball.x), float(ball.y), float(ball.z))
		var on_screen: Vector2 = cam.unproject_position(ball_world)
		print("MEASURE pitch=%.1f cam=(%.2f,%.2f,%.2f) ball_px=(%.0f,%.0f) err=%d -> %s" % [
			pitch, cam.position.x, cam.position.y, cam.position.z,
			on_screen.x, on_screen.y, err, ProjectSettings.globalize_path(path)])

	print("SLICE_CUE_PASS")
	quit(0)
