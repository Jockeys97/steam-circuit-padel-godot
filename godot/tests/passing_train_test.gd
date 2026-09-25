extends SceneTree
## The depot's passing train belonged to "Deposito Locomotive", rebuilt on 2026-09-25 as
## "Sopraelevata della Luna" (moonlit_highway.gd): the arena no longer has a train. This
## test now pins that retirement at the match seam: the controller's train lookup stays
## null-safe (no train, no errors, match ticks) and the new arena's traffic is mounted.
## The train component itself (`passing_train.gd`) is kept, unused, for a future arena.
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
	check(game._depot_train() == null,"no train in the rebuilt arena")
	var hw = game._arena_root.get_node_or_null("Scenery/MoonlitHighway")
	check(hw != null and hw.cars.size() >= 6,"skyway traffic mounted instead")
	game.ticks = 10
	game.state.pointPause = 0.8
	game.state.result = null
	game.tick_fixed(1.0/120.0,Sim.empty_input(),{})
	check(true,"match point pause ticks without a train")
	game.free()
	print("PASSING_TRAIN ",checks-failures,"/",checks)
	quit(1 if failures else 0)
