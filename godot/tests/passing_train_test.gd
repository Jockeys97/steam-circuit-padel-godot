extends SceneTree
const Config = preload("res://game/match_config.gd")
const Sim = preload("res://src/sim/sim.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _initialize(): call_deferred("run")
func run():
	Config.save_dir = "user://train-test-%s" % Time.get_ticks_usec()
	Config.arena_index = Config.arena_index_of("locomotive")
	Config.world_arena_id = ""
	var game = load("res://game/Match.tscn").instantiate()
	game.harness_mode()
	root.add_child(game)
	await process_frame
	var train = game._depot_train()
	check(train != null,"train in selected match")
	check(train.wait_seconds >= 60 and train.wait_seconds <= 90,"initial 60-90 second wait")
	check(not train.visible and not train.travelling,"outside frame while waiting")
	train.step(100.0,false,false)
	check(not train.travelling and train.wait_seconds == 0.0,"expired timer waits for point break")
	train.step(0.01,true,false)
	check(train.travelling and train.passes == 1,"one pass begins at break")
	var x: float = train.position.x
	train.step(1.0,false,false)
	check(is_equal_approx(train.position.x-x,2.8),"constant travel speed even after new rally")
	game._audio.port.set_muted(false)
	train.sync_audio(false,false)
	check(train.sound.bus == "SFX" and train.sound.playing,"train uses effects bus")
	game.set_match_paused(true)
	game._sync_views()
	check(train.sound.stream_paused,"pause silences ongoing loop")
	x = train.position.x
	game.apply_frame(Sim.empty_input(),0.5)
	check(train.position.x == x,"pause freezes translation")
	game.set_match_paused(false)
	game._audio.port.set_muted(true)
	game._sync_views()
	check(not train.sound.playing,"mute stops train sound")
	game._audio.port.set_master_gain(0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"zero volume uses existing mixer mute")
	train.step(25.0,false,false)
	check(not train.visible and not train.travelling and not train.sound.playing,"exit cleans up pass")
	check(train.wait_seconds >= 60 and train.wait_seconds <= 90,"repeat wait remains bounded")
	# Exercise the actual match tick seam, not only the decorative controller.
	game.ticks = 10
	train.wait_seconds = 0.0
	game.state.pointPause = 0.8
	game.state.result = null
	game.tick_fixed(1.0/120.0,Sim.empty_input(),{})
	check(train.travelling,"match point pause starts pass")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		for seconds in [6.0,3.0,3.0]:
			train.step(seconds,false,false)
			game._sync_views()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/train-pass-%d.png" % int(train.position.x)) == OK,"pass frame saved")
	train.step(0.1,true,true)
	check(not train.visible and not train.sound.playing,"match end removes pass")
	train.reset_schedule()
	check(train.passes == 0 and not train.travelling,"restart resets controller")
	game.free()
	print("PASSING_TRAIN ",checks-failures,"/",checks)
	quit(1 if failures else 0)
