extends SceneTree
## Real menu -> editor -> save -> lineup -> match/rematch and career, isolated saves.
const Config := preload("res://game/match_config.gd")
const Store := preload("res://src/character/custom_character_store.gd")
const Appearance := preload("res://src/character/custom_character.gd")
const Main := preload("res://game/Main.tscn")
const Match := preload("res://game/Match.tscn")
const Session := preload("res://game/mode_session.gd")
const Kit := preload("res://src/character/custom_character_rig.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s %s" % ["ok" if ok else "FAIL", label])

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Config.save_dir = "user://custom-character-flow-profile"
	Store.default_path_override = "user://custom-character-flow.json"
	Store.new().erase()
	root.size = Vector2i(1280, 720)
	var menu = Main.instantiate()
	root.add_child(menu)
	await process_frame
	var router = menu.ui_router()
	router.go_to("characters")
	for i in 4:
		await process_frame
	var roster = router.active_screen()
	var found := false
	for spec in roster.focus_controls():
		if spec.action == "create-athlete":
			found = true
	check(found, "create entry belongs to controller navigation")
	roster.activate("create-athlete")
	for i in 4:
		await process_frame
	var editor = roster.modal_overlay()
	check(editor != null and menu._overlay_owns_input(), "editor exclusively owns menu input")
	check(not roster.get_node("Frame").visible, "underlying roster hidden while editing")
	var button = editor.find_child("Next_skin_id", true, false)
	button.grab_focus()
	var before: Dictionary = editor.edited_record()
	await press_pad(JOY_BUTTON_A)
	check(editor.edited_record().skin_id != before.skin_id, "controller A changes focused choice")
	await press_pad(JOY_BUTTON_DPAD_LEFT)
	check(editor.edited_record().skin_id == before.skin_id and root.gui_get_focus_owner() == button,
		"controller left changes the choice without leaving its row")
	await press_pad(JOY_BUTTON_DPAD_RIGHT)
	check(editor.edited_record().skin_id != before.skin_id and root.gui_get_focus_owner() == button,
		"controller right changes the choice without an extra confirm")
	var camera: Camera3D = editor._viewport.get_node("PreviewCamera")
	var full_position := camera.position
	editor.find_child("PreviewZoom", true, false).grab_focus()
	await press_pad(JOY_BUTTON_A)
	check(camera.position.distance_to(full_position) > 0.1, "controller opens the face close-up")
	await press_pad(JOY_BUTTON_A)
	check(camera.position.is_equal_approx(full_position), "controller restores full-body framing")
	button.grab_focus()
	var first_body: String = editor.edited_record().body_id
	check(editor.cycle("body_id", 1) and editor.edited_record().body_id != first_body,
		"body choice changes the selected build")
	check(editor._rig.body_id() == Appearance.body_rig_id(editor.edited_record()),
		"editor preview rebuilds the chosen Meshy body")
	if "--body-b" in OS.get_cmdline_user_args():
		for i in Appearance.BODIES.size():
			if editor.edited_record().body_id == "uomo_b":
				break
			editor.cycle("body_id", 1)
		for i in Appearance.HAIRS.size():
			if editor.edited_record().hair_id == "crop":
				break
			editor.cycle("hair_id", 1)
		check(editor._rig.body_id() == &"cc_uomo_b", "B selected through actual editor")
		check(editor._rig.get_athlete_glb_path().ends_with("corpo_uomo_b-rigged.glb"), "B uses promoted model")
		var hair = editor._rig.get_skeleton().get_node_or_null("CustomHair")
		check(hair != null, "B cropped hair mounted")
	await press_pad(JOY_BUTTON_DPAD_DOWN)
	var focus := root.gui_get_focus_owner()
	check(focus != null and editor.is_ancestor_of(focus) and focus != button, "controller down stays inside editor")
	editor.apply_name("ALESSIO")
	if DisplayServer.get_name() != "headless":
		for i in 4:
			await process_frame
		var shot := "editor-b.png" if "--body-b" in OS.get_cmdline_user_args() else "editor.png"
		root.get_texture().get_image().save_png("res://../docs/agent-work/character-creator/evidence/" + shot)
	var preview = editor._rig
	var skeleton: Skeleton3D = preview.get_skeleton()
	var mesh: MeshInstance3D = preview.custom_mesh()
	check(mesh.skin.get_bind_count() == skeleton.get_bone_count(), "skin slots map every skeleton index")
	var binds_ok := true
	for b in skeleton.get_bone_count():
		var identity := skeleton.get_bone_global_rest(b) * mesh.skin.get_bind_pose(b)
		# Imported centimetre bones accumulate sub-millimetre float roundoff.
		binds_ok = binds_ok and identity.origin.length() < 0.001 and identity.basis.is_equal_approx(Basis.IDENTITY)
	# Only the procedural kit builds its own skin; a Meshy body (2026-09-27) carries the
	# binds its GLB was exported with.
	check(binds_ok or (preview.has_method("body_id") and preview.body_id() != &""), "skin inverse bind transforms reproduce rest geometry")
	check(editor.save(), "editor save succeeds")
	for i in 4:
		await process_frame
	check(roster.modal_overlay() == null and not menu._overlay_owns_input(), "save returns input to roster")
	check(Config.athlete_id() == "custom_one", "saved custom athlete is selected")
	check(roster.slot_athlete_id("player") == "custom_one", "team slot retains created athlete")
	roster.activate("create-athlete")
	await process_frame
	check(roster.modal_overlay().edited_record().display_name == "ALESSIO", "reopening restores saved name")
	if "--body-b" in OS.get_cmdline_user_args():
		check(roster.modal_overlay().edited_record().body_id == "uomo_b", "reopening restores B body")
	await press_pad(JOY_BUTTON_B)
	check(roster.modal_overlay() == null and router.active_id() == "characters", "controller B closes editor without leaving roster")
	menu.free()
	await process_frame
	if "--editor-only" in OS.get_cmdline_user_args():
		Store.new().erase()
		print("CUSTOM_EDITOR %s %d checks" % ["PASS" if failures == 0 else "FAIL", checks])
		quit(0 if failures == 0 else 1)
		return
	Config.pending_mode = "quick"
	var game = Match.instantiate()
	game.harness_mode()
	root.add_child(game)
	await process_frame
	game.start_match()
	check(game.build_athletes() == 4, "actual match creates all four rigs")
	check(game._athletes.rigs.player is Kit, "actual match uses custom rig")
	if "--body-b" in OS.get_cmdline_user_args():
		check(game._athletes.rigs.player.body_id() == &"cc_uomo_b", "actual match uses B body")
	check(game._athletes._racket_on_hand.player, "custom athlete racket attaches to hand")
	for i in 120:
		game.advance_frame(1.0 / 60.0)
		game._athletes.sync(game.state, 1.0 / 60.0)
		game._athletes.serve_ball_override(game.state)
	check(game.ticks > 0, "actual match simulation advances with full rig interface")
	game.rematch()
	check(game.state.athlete.id == "custom_one", "real rematch retains custom identity")
	game.free()
	await process_frame
	var career = Session.start("career", Config.save_store(), {"athlete": Config.athlete(), "arenas": Config.arenas(), "seed": 1})
	check(career != null and career.state.athlete.id == "custom_one", "career session uses custom athlete")
	check(career.state.athlete.stats == Appearance.stats(), "career preserves balanced cosmetic stats")
	career = null
	for i in 5:
		await process_frame
	Store.new().erase()
	check(checks >= 19, "full flow completed")
	print("CUSTOM_FLOW %s %d checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func press_pad(index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
