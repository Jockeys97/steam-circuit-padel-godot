extends SceneTree
## Verifies that compact Jukebox controls leave room for the OST list at 1280x720.

const JukeboxScene := preload("res://src/ui/jukebox/JukeboxScreen.tscn")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	preload("res://game/match_config.gd").save_dir = "user://jukebox-layout-%d" % Time.get_ticks_usec()
	root.size = Vector2i(1280, 720)
	var juke: Control = JukeboxScene.instantiate()
	root.add_child(juke)
	await _settle()
	_check(juke._scope == "all", "catalogo unificato predefinito all'apertura")
	_check(juke._visible_ids().has("ost_menu") and juke._visible_ids().has("ost_training"), "menu e partita nello stesso elenco")
	var closed_rows := _fully_visible_rows(juke)
	_check(not juke._options_body.visible, "Opzioni inizialmente chiuse")
	_check(closed_rows >= 7, "almeno 7 brani completi a 1280x720 (%d)" % closed_rows)
	_check(not juke._scope_buttons["menu"].is_visible_in_tree(), "vecchie schede nascoste nella modalità unificata")
	_check(juke._catalog_filter_buttons[false].is_visible_in_tree(), "filtro elenco visibile")
	var keep_rect: Rect2 = juke._continue_outside.get_global_rect()
	var player_rect: Rect2 = juke._insp_scroll.get_global_rect()
	_check(juke._continue_outside.is_visible_in_tree() and keep_rect.end.y <= player_rect.end.y + 1.0, "opzione continua fuori visibile senza scorrere il lettore")
	juke._continue_outside.grab_focus()
	_check(juke._continue_outside.has_focus(), "opzione continua fuori raggiungibile col controller")
	_check(juke._genre.is_visible_in_tree(), "filtro genere visibile")
	juke._genre.pressed.emit()
	await _settle()
	_check(juke._genre_popup.visible, "menu generi personalizzato apribile")
	_check(juke._genre_buttons.size() == juke._genre_values.size(), "ogni genere ha un'opzione navigabile")
	_check(juke._genre_buttons[0].has_focus(), "opzione corrente riceve il focus controller")
	_check(juke._genre_popup.get_global_rect().end.y <= root.size.y + 1.0, "menu generi dentro lo schermo")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var genre_capture := ProjectSettings.globalize_path("res://../docs/agent-work/jukebox-list-space/genre-popup-1280x720.png")
		_check(root.get_texture().get_image().save_png(genre_capture) == OK, "cattura filtro generi salvata")
		print("capture: ", genre_capture)
	juke._genre_buttons[1].pressed.emit()
	await _settle()
	_check(not juke._genre_popup.visible and juke._selected_genre == juke._genre_values[1], "scelta del genere applicata e pannello chiuso")
	juke._genre.pressed.emit()
	await _settle()
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	await _settle()
	_check(not juke._genre_popup.visible and juke.is_inside_tree(), "B chiude solo il filtro, non il Jukebox")
	cancel.pressed = false
	root.push_input(cancel)
	juke._set_genre("")

	juke._options_button.button_pressed = true
	await _settle()
	var open_rows := _fully_visible_rows(juke)
	_check(juke._options_body.visible, "Opzioni apribili")
	_check(juke._r3_order.is_visible_in_tree() and juke._only_favorites.is_visible_in_tree(), "ordinamento e soli preferiti accessibili")
	juke._separate_contexts.button_pressed = true
	_check(juke._scope == "match" and juke._scope_tabs.visible, "opzione ripristina la vecchia suddivisione")
	juke._separate_contexts.button_pressed = false
	_check(juke._scope == "all" and not juke._copy_context.get_parent().visible, "disattivando la suddivisione torna la libreria unificata")
	_check(closed_rows >= open_rows + 2, "chiudere Opzioni restituisce almeno 2 righe (%d -> %d)" % [open_rows, closed_rows])

	juke._r3_order.grab_focus()
	await _settle()
	_check(juke._r3_order.has_focus(), "ordinamento raggiungibile con focus")
	juke._options_button.button_pressed = false
	await _settle()
	_check(juke._options_button.has_focus(), "chiusura Opzioni riporta il focus sul toggle")
	_check(not juke._r3_order.is_visible_in_tree(), "controlli avanzati nascosti dopo la chiusura")

	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := ProjectSettings.globalize_path("res://../docs/agent-work/jukebox-list-space/after-1280x720.png")
		_check(root.get_texture().get_image().save_png(capture) == OK, "cattura 1280x720 salvata")
		print("capture: ", capture)

	juke.free()
	await _settle()
	print("[jukebox_catalog_layout_test] Results: %d checks, %d failures; rows closed=%d open=%d" % [_checks, _failures, closed_rows, open_rows])
	quit(1 if _failures > 0 else 0)


func _fully_visible_rows(juke: Control) -> int:
	var scroll: ScrollContainer = juke._track_list_container.get_parent()
	var bounds := scroll.get_global_rect()
	var count := 0
	for row in juke._track_rows:
		if not row.is_visible_in_tree():
			continue
		var rect: Rect2 = row.get_global_rect()
		if rect.position.y >= bounds.position.y - 1.0 and rect.end.y <= bounds.end.y + 1.0:
			count += 1
	return count


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: ", label)
	else:
		print("ok: ", label)


func _settle() -> void:
	for _i in 4:
		await process_frame
