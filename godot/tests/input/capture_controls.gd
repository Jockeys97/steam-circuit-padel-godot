extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var match_node = load("res://game/Match.tscn").instantiate()
	root.add_child(match_node)
	match_node.engine_driven = false
	for i in 12:
		await process_frame
	match_node._sync_views()
	match_node._hud.refresh(match_node.state, {})
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("/tmp/padel-controls-fixed.png")
	print("CAPTURE ", error)
	match_node.queue_free()
	await process_frame
	quit(error)
