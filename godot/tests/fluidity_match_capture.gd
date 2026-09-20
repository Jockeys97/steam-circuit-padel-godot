extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame
	for tick in 960:
		var input := Sim.empty_input()
		if tick >= 60:
			input.charging = true
			input.hit = tick % 30 == 0
			input.moveX = (int(tick / 120) % 3 - 1) * 0.5
			input.moveY = -1 if tick % 240 < 120 else 0
		game.tick_fixed(1.0 / 120.0, input, {})
		if tick % 2 == 0:
			game._sync_views()
			await process_frame
		if tick in [360, 720, 959]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/padel-fluidity-match-%d.png" % tick)
	print("FLUIDITY_MATCH_CAPTURE_PASS ticks=960")
	game.free()
	quit()
