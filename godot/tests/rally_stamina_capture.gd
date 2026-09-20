extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame
	# Deliberately staged UI fixture, not a balance/playtest measurement.
	game.state.player.staminaEnergy = 1.0
	game.state.playerMate.staminaEnergy = 0.6
	game.state.opponent.staminaEnergy = 0.3
	game.state.opponentMate.staminaEnergy = 0.15
	game._sync_views()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/padel-stamina-levels.png")
	print("STAMINA_CAPTURE_PASS")
	game.free()
	quit()
