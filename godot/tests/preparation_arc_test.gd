extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func _initialize():
	call_deferred("run")
func run():
	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame
	var s = game.state
	s.running = true
	s.serving = false
	s.pointPause = 0.0
	s.shotCharge = 0.2
	s.shotRead.active = true
	s.ball.x = s.active_player().x
	s.ball.y = s.active_player().y
	s.ball.z = 50.0
	var rng = s.rng_state
	game._sync_views()
	var marks = game.court_timing_marks()
	check(marks.preparation_report.visible, "charging arc visible")
	check(marks.preparation_report.band == 0, "prepared shot compact")
	var expected = Sim.evaluate_shot_quality(s, s.active_player(), {"charge":s.shotCharge,"aim":s.shotAim,"variant":s.shotIntent})
	check(marks.preparation_report.risk == expected.risk, "same real assessment")
	check(s.rng_state == rng, "presentation does not consume RNG")
	game.set_ui_component("preparation", false)
	check(not game.get_node("ShotPreparationArc").visible, "toggle immediately hides")
	game.set_ui_component("preparation", true)
	s.shotCharge = 1.0
	s.shotAim = 1.0
	s.active_player().moveRatio = 1.0
	s.active_player().staminaEnergy = 0.15
	s.ball.y += 30.0
	game._sync_views()
	check(marks.preparation_report.band == 2, "forced shot wide amber")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/padel-preparation-arc.png")
	s.shotCharge = 0.0
	s.shotFeedback = {"paddleKey":s.active_player().key,"grade":"perfect","life":0.78,"quality":1.0,"mode":"shotMode:control","profile":"control"}
	game._sync_views()
	check(marks.preparation_report.flash, "confirmed perfect flashes")
	s.shotFeedback.life = 0.5
	game._sync_views()
	check(not marks.preparation_report.visible, "flash expires")
	s.shotCharge = 0.2
	s.paused = true
	game._sync_views()
	check(not marks.preparation_report.visible, "paused hidden")
	s.paused = false
	game.set_hud_hidden(true)
	game._sync_views()
	check(not marks.preparation_report.visible, "clean view hidden")
	print("PREPARATION %d/%d" % [checks-failures,checks])
	game.free()
	quit(0 if failures == 0 else 1)
