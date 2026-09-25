extends SceneTree
const Config := preload("res://game/match_config.gd")
const Prefs := preload("res://src/audio/music_preferences.gd")
const Runtime := preload("res://src/audio/runtime_soundtrack.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
func run() -> void:
	Config.save_dir = "user://music-preferences-%d" % Time.get_ticks_usec()
	var store := Config.save_store()
	var music := Runtime.new()
	root.add_child(music)
	music.set_screen("menu")
	var first := music._track
	music.free()
	music = Runtime.new()
	root.add_child(music)
	music.set_screen("menu")
	check(first != music._track, "fresh menu instance does not repeat first song")
	check(Prefs.read(store).get("musicLastMenu") == music._track, "last menu song persisted")
	var juke = load("res://src/ui/jukebox/JukeboxScreen.tscn").instantiate()
	juke.set_store(store)
	root.add_child(juke)
	juke._set_scope("menu")
	for frame in 3:
		await process_frame
	juke._select_track(juke._track_ids.find("ost_menu"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = juke._star_buttons.ost_roster.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	check(Prefs.favorites(store, "menu") == ["ost_roster"], "Jukebox button saves menu favourite")
	check(juke._selected_idx == juke._track_ids.find("ost_menu"), "star click targets its own song without prior selection")
	juke._track_buttons[juke._track_ids.find("ost_roster")].grab_focus()
	var favorite_event := InputEventJoypadButton.new()
	favorite_event.button_index = JOY_BUTTON_Y
	favorite_event.pressed = true
	root.push_input(favorite_event, true)
	check(Prefs.favorites(store, "menu").is_empty(), "controller Y removes highlighted song favourite")
	favorite_event = favorite_event.duplicate()
	favorite_event.pressed = false
	root.push_input(favorite_event, true)
	favorite_event = favorite_event.duplicate()
	favorite_event.pressed = true
	root.push_input(favorite_event, true)
	check(Prefs.favorites(store, "menu") == ["ost_roster"], "controller Y adds highlighted song favourite")
	check(Prefs.favorites(store, "match").is_empty(), "menu favourite does not affect match")
	juke._only_favorites.button_pressed = true
	check(juke._track_rows[juke._track_ids.find("ost_menu")].visible, "only favourites playback leaves other songs available for starring")
	music.refresh()
	check(music.playlist() == ["ost_roster"] and music._track == "ost_roster", "runtime menu uses only its favourites")
	music.advance_track()
	check(music._track == "ost_roster", "single favourite remains sole playable song")
	juke._scope_buttons.match.pressed.emit()
	juke._select_track(juke._track_ids.find("ost_training"))
	juke._star_buttons.ost_training.pressed.emit()
	juke._only_favorites.button_pressed = true
	music.set_arena("officina")
	check(music.playlist() == ["ost_training"], "match favourites independently filter rotation")
	juke._filter_playlist()
	check(juke._playlist_ids() == ["ost_training"], "Jukebox match playlist filters to favourites")
	juke._play_playlist(0)
	check(juke._manager.current_track_id() == "ost_training", "listen playlist starts favourite")
	juke._manager.stop(0.0)
	juke._process(0.2)
	check(juke._manager.current_track_id() == "ost_training", "preview advances only within favourite playlist")
	juke._star_buttons.ost_training.pressed.emit()
	music.refresh()
	check(music.playlist().is_empty() and not music.player.is_active() and not music.classic.playing, "empty favourites is silent, no unwanted fallback")
	Prefs.toggle(store, "match", "ost_officina")
	music.refresh()
	check(music.playlist().is_empty(), "locked favourites cannot bypass ownership")
	var career := Prefs.Save.load_career(store)
	career.unlockAll = true
	Prefs.Save.save_career(store, career)
	music.refresh()
	check(music._track == "ost_officina", "unlocked favourite starts immediately")
	career.lockAll = true
	Prefs.Save.save_career(store, career)
	music.refresh()
	check(music.playlist().is_empty() and not music.player.is_active(), "Alelu silences locked favourite without deleting it")
	check(Prefs.favorites(store, "match").has("ost_officina"), "favourites survive relocking")
	juke.free()
	juke = load("res://src/ui/jukebox/JukeboxScreen.tscn").instantiate()
	juke.set_store(store)
	root.add_child(juke)
	juke._set_scope("menu")
	var menu_only: bool = juke._only_favorites.button_pressed
	juke._scope_buttons.match.pressed.emit()
	check(menu_only and juke._only_favorites.button_pressed, "both filters restored when switching tabs")
	juke._star_buttons.classic_match.pressed.emit()
	music.refresh()
	check(music._track == "classic_match" and music.playlist() == ["classic_match"], "classic favourite works even with locked OSTs")
	check(juke._r3_order.selected == 0, "R3 defaults to fixed order")
	juke._r3_order.select(1)
	juke._r3_order.item_selected.emit(1)
	check(Prefs.random_skip(store), "Jukebox saves random R3 setting")
	var skip := InputEventJoypadButton.new()
	skip.button_index = JOY_BUTTON_RIGHT_STICK
	skip.pressed = true
	music.handle_skip(skip)
	skip.pressed = false
	music.handle_skip(skip)
	check(music._track == "classic_match", "random R3 safely handles single favourite")
	Prefs.toggle(store, "match", "ost_training")
	Prefs.toggle(store, "match", "ost_roster")
	var valid_random := true
	for i in 12:
		var previous := music._track
		skip.pressed = true
		music.handle_skip(skip)
		skip.pressed = false
		music.handle_skip(skip)
		valid_random = valid_random and music._track != previous and music.playlist().has(music._track) and music._track != "ost_officina"
	check(valid_random, "random R3 avoids immediate repeat and respects favourite ownership")
	juke.free()
	juke = load("res://src/ui/jukebox/JukeboxScreen.tscn").instantiate()
	juke.set_store(store)
	root.add_child(juke)
	check(juke._r3_order.selected == 1, "random preference restored on reopen")
	juke._r3_order.select(0)
	juke._r3_order.item_selected.emit(0)
	var items := music.playlist()
	var expected := items[(items.find(music._track) + 1) % items.size()]
	skip.pressed = true
	music.handle_skip(skip)
	skip.pressed = false
	music.handle_skip(skip)
	check(music._track == expected and not Prefs.random_skip(store), "switching back restores fixed R3 sequence")
	Prefs.set_only(store, "menu", false)
	Prefs.set_only(store, "match", false)
	juke._set_scope("menu")
	juke._select_track(juke._track_ids.find("ost_menu"))
	juke._copy_context.pressed.emit()
	check(Prefs.belongs(store, "ost_menu", "menu") and Prefs.belongs(store, "ost_menu", "match"), "copy adds menu song to both contexts")
	music.set_arena("officina")
	music.refresh()
	check(music.playlist().has("ost_menu"), "copied song participates in actual match rotation")
	juke._move_context.pressed.emit()
	check(not juke._visible_ids().has("ost_menu") and Prefs.belongs(store, "ost_menu", "match"), "move removes song from source playlist")
	music.set_screen("menu")
	check(not music.playlist().has("ost_menu"), "runtime does not reinsert moved theme as fallback")
	juke._set_scope("match")
	juke._select_track(juke._track_ids.find("ost_menu"))
	juke._move_context.pressed.emit()
	check(Prefs.belongs(store, "ost_menu", "menu") and not Prefs.belongs(store, "ost_menu", "match"), "reverse move restores menu-only membership")
	Prefs.transfer(store, "ost_roster", "menu", true)
	check(not Prefs.favorites(store, "menu").has("ost_roster") and Prefs.favorites(store, "match").has("ost_roster"), "moving a favourite carries its star to destination")
	var sawano := ""
	for category in juke._genre_values:
		if category.to_lower().contains("sawano"):
			sawano = category
	check(sawano != "", "genre dropdown derives Sawano label from catalogue")
	juke._set_genre(sawano)
	var filtered: Array = juke._visible_ids()
	check(not filtered.is_empty() and filtered.all(func(id): return juke.SoundtrackManager.track_info(id).get("category") == sawano), "genre filter shows only matching tracks")
	var song: String = filtered[0]
	juke._select_track(juke._track_ids.find(song))
	juke._copy_context.pressed.emit()
	juke._set_scope("menu")
	check(juke._visible_ids().has(song), "copied match song appears under same genre in menu tab")
	juke._set_genre("")
	check(juke._visible_ids().has("ost_menu"), "clearing genre restores unrelated menu songs")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		music.set_held(true)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://game/out/jukebox-favorites.png")
	juke.free()
	music.free()
	print("MUSIC_PREFERENCES %d/%d" % [checks-failures, checks])
	quit(0 if failures == 0 else 1)
