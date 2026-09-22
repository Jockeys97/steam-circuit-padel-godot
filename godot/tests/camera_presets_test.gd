extends SceneTree

const Config = preload("res://game/match_config.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", description)

func run() -> void:
	Config.save_dir = "user://camera-audit-%s" % Time.get_ticks_usec()
	root.size = Vector2i(1280, 720)
	var game = load("res://game/Match.tscn").instantiate()
	game.harness_mode()
	root.add_child(game)
	await process_frame
	game.set_match_paused(true)
	var overlay = game._pause_overlay
	check(overlay.TABS[1].id == "camera", "camera tab immediately follows match")
	check(overlay.set_tab("camera"), "camera panel opens")
	check(overlay.focus_controls().size() == 11, "five tabs, five cameras and resume navigable")
	var before_preview = game._cam.transform
	var before_pref = Config.stored_prefs().get("cameraPreset")
	overlay._camera_buttons["courtside"].grab_focus()
	check(overlay._preview_id == "courtside", "keyboard/controller focus previews camera")
	check(game._cam.transform == before_preview and Config.stored_prefs().get("cameraPreset") == before_pref, "preview leaves live camera and saved preference unchanged")
	var original_state = game.state
	var poses: Array = []
	for id in ["default", "immersive", "courtside", "tactical", "broadcast"]:
		overlay._camera_buttons[id].pressed.emit()
		check(Config.camera_preset == id, "button selects " + id)
		check(Config.stored_prefs().get("cameraPreset") == id, "selection saved " + id)
		check(game.is_paused() and game.state == original_state, "selection preserves paused match " + id)
		check(not poses.has(game._cam.transform), "distinct view " + id)
		poses.append(game._cam.transform)
		if "--camera-capture" in OS.get_cmdline_user_args():
			overlay.hide()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/padel-camera-" + id + ".png")
			overlay.show()
		for corner in [Vector3(-5, 0, -10), Vector3(5, 0, -10), Vector3(-5, 0, 10), Vector3(5, 0, 10)]:
			var pixel = game._cam.unproject_position(corner)
			check(not game._cam.is_position_behind(corner) and Rect2(Vector2.ZERO, Vector2(root.size)).has_point(pixel), "court corner visible " + id + str(corner))
	check(not game.set_camera_preset("invalid"), "invalid preset rejected")
	if "--camera-capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/padel-camera-pause.png")
		root.size = Vector2i(1024, 600)
		overlay.set_language("it")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/padel-camera-pause-it.png")
		check(root.get_visible_rect().encloses(overlay._resume_footer.get_global_rect()), "Italian resume fits stretched small viewport")
	for tab in ["camera", "controller", "controls", "ui"]:
		overlay.set_tab(tab)
		check(overlay._resume_footer.is_visible_in_tree(), "resume visible on " + tab)
		check(overlay.focus_controls().back().node == overlay._resume_footer, "resume navigable on " + tab)
	overlay._resume_footer.pressed.emit()
	check(not game.is_paused(), "footer resumes actual match")
	check(overlay._camera_preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "preview rendering stops outside camera tab")
	game.queue_free()
	await process_frame
	var reloaded = load("res://game/Match.tscn").instantiate()
	reloaded.harness_mode()
	root.add_child(reloaded)
	await process_frame
	check(Config.camera_preset == "broadcast" and reloaded._cam.transform == poses.back(), "new match restores saved camera")
	reloaded.queue_free()
	await process_frame
	print("CAMERA_PRESETS failures=", failures)
	quit(0 if failures == 0 else 1)
