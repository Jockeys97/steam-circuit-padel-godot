extends SceneTree
const View = preload("res://game/athletes_view.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://game/Match.tscn").instantiate()
	game.engine_driven = false
	root.add_child(game)
	await process_frame
	# Staged visual fixture: the real Match scene and its normal view sync,
	# with two Fiamma rigs wearing independent outfits. No saved settings touched.
	game._athletes.free()
	var view := View.new()
	game.add_child(view)
	game._athletes = view
	var lineup: Dictionary = game._lineup.duplicate(true)
	lineup.player = {"id": "fiamma"}
	lineup.playerMate = {"id": "fiamma"}
	var count := view.spawn(lineup, {"player": &"circuit", "playerMate": &"legend"}, {})
	assert(count == 4)
	for role in View.ROLES:
		game._athlete_roots[role] = view.rigs[role]
		game._paddle_views[role] = view.rackets[role]
	game._sync_views()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../docs/agent-work/outfits-3d/evidence/fiamma-match.png")
	var result := root.get_texture().get_image().save_png(path)
	assert(result == OK)
	assert(view.rigs.player.get_catalogue_surface() != view.rigs.playerMate.get_catalogue_surface())
	print("OUTFIT_FIAMMA_MATCH_PASS rigs=4 independent_outfits=2")
	game.free()
	quit()
