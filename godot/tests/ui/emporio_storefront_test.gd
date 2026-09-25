extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Store := preload("res://src/save/save_store.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const Config := preload("res://game/match_config.gd")
const Soundtrack := preload("res://src/audio/soundtrack_manager.gd")
const Catalog := preload("res://src/economy/ost_catalog.gd")
const Shop := preload("res://src/ui/screens/EmporioScreen.tscn")

var audit: AuditBase


func _initialize() -> void:
	audit = AuditBase.new("emporio_storefront")
	call_deferred("_run")


func _run() -> void:
	var store: RefCounted = Store.new("user://emporio-storefront-test")
	store.write_group("economy", {
		"credits": 1000,
		"owned": [],
		"migrationVersion": Economy.MIGRATION_VERSION,
		"receipts": {},
	})
	var screen: Control = Shop.instantiate()
	screen.call("set_store", store)
	root.add_child(screen)
	await process_frame
	await process_frame
	var rows: Array = screen.call("rows")
	audit.check_true(rows.size() > 20, "shop/catalog_visible")
	audit.check_true(screen.call("_load_cover_for_track", "ost_officina") is Texture2D, "shop/reuses_jukebox_cover")
	var covers_found := 0
	for row in rows:
		if screen.call("_load_cover_for_track", String(row["id"])) is Texture2D:
			covers_found += 1
	audit.check_eq(covers_found, rows.size(), "shop/every_sold_ost_has_cover")
	audit.check_true(screen.call("_load_cover_for_track", "ost_nonexistent") == null, "shop/missing_cover_fallback")
	var all_cards: Array = screen.get("_row_buttons")
	var all_count := all_cards.size()
	audit.check_eq(all_cards.size(), rows.size(), "shop/all_cards_reachable")
	var preview: TextureRect = screen.get("_preview_cover")
	audit.check_true(preview.texture != null, "shop/first_preview_has_cover")
	var first: Button = all_cards[0]
	var initial_id := String(screen.call("selected_id"))
	first.grab_focus()
	await process_frame
	audit.check_eq(String(screen.call("selected_id")), initial_id, "shop/focus_does_not_select")
	var reached := {first: true}
	var pending: Array = [first]
	while not pending.is_empty():
		var card: Button = pending.pop_front()
		for path in [card.focus_neighbor_left, card.focus_neighbor_right, card.focus_neighbor_top, card.focus_neighbor_bottom]:
			var next: Node = card.get_node_or_null(path)
			if next is Button and all_cards.has(next) and not reached.has(next):
				reached[next] = true
				pending.append(next)
	audit.check_eq(reached.size(), all_count, "shop/all_cards_connected_by_dpad")
	if all_cards.size() > 1:
		var right: Button = first.get_node_or_null(first.focus_neighbor_right)
		audit.check_true(right == all_cards[1], "shop/first_card_right_neighbor")
		var press := InputEventAction.new()
		press.action = "ui_right"
		press.pressed = true
		root.push_input(press)
		await process_frame
		audit.check_true(root.gui_get_focus_owner() == all_cards[1], "shop/dpad_right_moves_to_next_card")
		audit.check_eq(String(screen.call("selected_id")), initial_id, "shop/dpad_focus_does_not_change_preview")
		all_cards[1].mouse_entered.emit()
		audit.check_eq(String(screen.call("selected_id")), initial_id, "shop/mouse_hover_does_not_change_preview")
		var accept := InputEventAction.new()
		accept.action = "ui_accept"
		accept.pressed = true
		root.push_input(accept)
		accept.pressed = false
		root.push_input(accept)
		await process_frame
		audit.check_eq(String(screen.call("selected_id")), String(all_cards[1].get_meta("track_id")), "shop/controller_accept_selects_preview")
		audit.check_true(not bool(screen.call("confirm_visible")), "shop/card_activation_does_not_open_purchase")
		var click_pos := first.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = click_pos
		motion.global_position = click_pos
		root.push_input(motion, true)
		await process_frame
		audit.check_eq(String(screen.call("selected_id")), String(all_cards[1].get_meta("track_id")), "shop/real_mouse_hover_still_does_not_select")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = click_pos
		click.global_position = click_pos
		click.pressed = true
		root.push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click, true)
		await process_frame
		audit.check_eq(String(screen.call("selected_id")), initial_id, "shop/mouse_click_selects_preview")
		all_cards[1].pressed.emit()
		all_cards[1].grab_focus()
		press.pressed = false
		root.push_input(press)
		press.pressed = true
		root.push_input(press)
		await process_frame
		audit.check_true(root.gui_get_focus_owner() == screen.get("_listen_btn"), "sample/dpad_reaches_listen_button")
		press.pressed = false
		root.push_input(press)
		audit.check_eq(String(screen.call("selected_id")), String(all_cards[1].get_meta("track_id")), "shop/selection_changes_track")
	var info_button: Button = screen.get("_info_toggle_btn")
	audit.check_true(not screen.get("_info_panel").visible, "info/starts_collapsed")
	audit.check_true(screen.get("_listen_btn").get_node_or_null(screen.get("_listen_btn").focus_neighbor_top) == info_button, "info/reachable_from_listen_with_dpad")
	info_button.grab_focus()
	await process_frame
	audit.check_true(root.gui_get_focus_owner() == info_button, "info/controller_focusable")
	info_button.pressed.emit()
	audit.check_true(screen.get("_info_panel").visible and not screen.get("_cover_frame").visible, "info/expands_instead_of_cover")
	screen.call("_select_track", "ost_officina")
	var metadata: Dictionary = Soundtrack.track_info("ost_officina")
	audit.check_true(screen.get("_info_tempo").text.contains(str(metadata["bpm"])) and screen.get("_info_tempo").text.contains(String(metadata["key"])), "info/tempo_and_key_from_catalog")
	audit.check_true(screen.get("_info_style").text.contains(String(metadata["style"])), "info/style_from_catalog")
	audit.check_eq(screen.get("_info_description").text, String(metadata["prompt"]), "info/description_from_catalog")
	info_button.pressed.emit()
	audit.check_true(not screen.get("_info_panel").visible and screen.get("_cover_frame").visible, "info/collapses_back_to_cover")
	screen.call("_set_filter", "special")
	var special_cards: Array = screen.get("_row_buttons")
	audit.check_true(special_cards.size() > 0 and special_cards.size() < all_count, "shop/special_filter")
	screen.call("_set_filter", "vocal")
	var vocal_cards: Array = screen.get("_row_buttons")
	audit.check_true(vocal_cards.size() == 5, "shop/vocal_filter_five_cards")
	screen.call("_select_track", "ost_vocal_overdrive_line")
	audit.check_eq(Catalog.price_of("ost_vocal_overdrive_line"), 400, "shop/vocal_price_400")
	audit.check_eq(Catalog.price_of("ost_vocal_break_point_riot"), 400, "shop/vocal_break_point_price_400")
	audit.check_eq(Catalog.price_of("ost_vocal_reach_for_the_sun"), 400, "shop/vocal_reach_sun_price_400")
	audit.check_eq(Catalog.price_of("ost_vocal_neon_velocity"), 400, "shop/vocal_neon_velocity_price_400")
	audit.check_eq(Catalog.price_of("ost_vocal_girei"), 400, "shop/vocal_girei_price_400")
	screen.call("_set_filter", "all")
	screen.call("_select_track", "ost_officina")
	(screen.get("_purchase_btn") as Button).pressed.emit()
	audit.check_true(bool(screen.call("confirm_visible")), "shop/purchase_requires_confirm")
	audit.check_eq(String(screen.call("selected_id")), "ost_officina", "shop/confirm_keeps_selection")
	screen.call("_on_cancel_pressed")
	audit.check_true(not bool(screen.call("confirm_visible")), "shop/cancel_closes_confirm")
	audit.check_eq(Economy.balance(store), 1000, "shop/cancel_no_debit")
	var preview_states: Array[bool] = []
	screen.preview_state_changed.connect(func(active: bool): preview_states.append(active))
	screen.call("_select_track", "ost_officina")
	screen.call("_on_preview_pressed")
	audit.check_true(bool(screen.call("preview_playing")), "sample/plays_locked_track_without_purchase")
	audit.check_eq(screen.get("_preview_player").bus, &"Music", "sample/uses_music_bus")
	audit.check_eq(screen.get("_preview_timer").wait_time, 15.0, "sample/limited_to_15_seconds")
	audit.check_eq(Economy.balance(store), 1000, "sample/no_credits_spent")
	audit.check_true(not Economy.is_owned(store, "ost_officina"), "sample/no_unlock")
	screen.get("_preview_timer").start(0.02)
	await create_timer(0.08).timeout
	audit.check_true(not bool(screen.call("preview_playing")), "sample/stops_at_timeout")
	screen.call("_on_preview_pressed")
	var next_card: Button = null
	for card in screen.get("_row_buttons"):
		if String(card.get_meta("track_id")) == "ost_fonderia":
			next_card = card
			break
	audit.check_true(next_card != null, "sample/second_card_exists")
	if next_card != null:
		next_card.mouse_entered.emit()
		next_card.grab_focus()
		await process_frame
		audit.check_eq(String(screen.call("selected_id")), "ost_officina", "sample/hover_and_focus_keep_playing_track_selected")
		audit.check_true(bool(screen.call("preview_playing")), "sample/hover_and_focus_do_not_stop_audio")
		next_card.pressed.emit()
	audit.check_true(not bool(screen.call("preview_playing")), "sample/stops_on_selection_change")
	audit.check_eq(preview_states, [true, false, true, false], "sample/host_pause_resume_signals")

	# Vocal track preview offset check
	screen.call("_select_track", "ost_vocal_overdrive_line")
	audit.check_eq(Soundtrack.preview_offset("ost_vocal_overdrive_line"), 26.0, "sample/vocal_overdrive_offset_26")
	audit.check_eq(Soundtrack.preview_offset("ost_vocal_neon_velocity"), 60.0, "sample/vocal_neon_offset_60")
	audit.check_eq(Soundtrack.preview_offset("ost_vocal_break_point_riot"), 40.0, "sample/vocal_break_point_offset_40")
	audit.check_eq(Soundtrack.preview_offset("ost_vocal_reach_for_the_sun"), 40.0, "sample/vocal_reach_sun_offset_40")
	audit.check_eq(Soundtrack.preview_offset("ost_vocal_girei"), 115.5, "sample/vocal_girei_offset_115_5")
	audit.check_eq(Soundtrack.preview_offset("ost_hyori_ittai_vocal"), 18.7, "sample/vocal_hyori_ittai_offset_18_7")
	screen.call("_on_preview_pressed")
	audit.check_true(bool(screen.call("preview_playing")), "sample/vocal_preview_plays")
	var vocal_player: AudioStreamPlayer = screen.get("_preview_player")
	audit.check_true(vocal_player.playing, "sample/vocal_player_active")
	screen.call("_stop_preview")
	audit.check_true(not bool(screen.call("preview_playing")), "sample/vocal_preview_stops")

	screen.queue_free()
	await process_frame
	Config.save_dir = "user://emporio-sample-host-test"
	var menu: Node = load("res://game/Main.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	menu.call("toggle_emporio")
	await process_frame
	var hosted_shop: Control = menu.call("emporio_overlay")
	var runtime: Node = menu.get("_runtime_ost")
	audit.check_true(hosted_shop != null and runtime != null, "sample/host_mounts_shop_and_music")
	if hosted_shop != null and runtime != null:
		audit.check_true(bool(runtime.get("_held")), "sample/host_mutes_menu_on_shop_open")
		hosted_shop.call("_select_track", "ost_officina")
		hosted_shop.call("_on_preview_pressed")
		audit.check_true(bool(runtime.get("_held")), "sample/host_pauses_menu_music_immediately")
		await process_frame
		audit.check_true(bool(runtime.get("_held")), "sample/host_keeps_music_paused")
		hosted_shop.call("_stop_preview")
		await process_frame
		audit.check_true(bool(runtime.get("_held")), "sample/menu_stays_muted_after_sample_stops")
		hosted_shop.call("_on_preview_pressed")
		menu.call("toggle_emporio")
		await process_frame
		audit.check_true(not bool(runtime.get("_held")), "sample/closing_shop_resumes_menu_music")
		menu.call("toggle_emporio")
		await process_frame
		audit.check_true(bool(runtime.get("_held")), "sample/reopened_shop_mutes_menu")
		var reopened: Control = menu.call("emporio_overlay")
		reopened.call("_on_back_pressed")
		await process_frame
		audit.check_true(not bool(runtime.get("_held")), "sample/back_resumes_menu_music")
		menu.call("toggle_jukebox")
		await process_frame
		menu.call("_on_jukebox_shop_requested", "ost_officina")
		await process_frame
		audit.check_true(menu.call("emporio_overlay") != null and bool(runtime.get("_held")), "sample/jukebox_to_shop_stays_muted")
		menu.call("toggle_emporio")
		await process_frame
		audit.check_true(not bool(runtime.get("_held")), "sample/jukebox_shop_exit_resumes_menu")
	menu.queue_free()
	await process_frame
	quit(audit.finish())
