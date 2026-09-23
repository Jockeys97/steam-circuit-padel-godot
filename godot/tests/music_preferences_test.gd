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
	juke._select_track(juke._track_ids.find("ost_roster"))
	juke._favorite_buttons.menu.pressed.emit()
	check(Prefs.favorites(store, "menu") == ["ost_roster"], "Jukebox button saves menu favourite")
	check(Prefs.favorites(store, "match").is_empty(), "menu favourite does not affect match")
	juke._only_buttons.menu.button_pressed = true
	music.refresh()
	check(music.playlist() == ["ost_roster"] and music._track == "ost_roster", "runtime menu uses only its favourites")
	music.advance_track()
	check(music._track == "ost_roster", "single favourite remains sole playable song")
	juke._select_track(juke._track_ids.find("ost_training"))
	juke._favorite_buttons.match.pressed.emit()
	juke._only_buttons.match.button_pressed = true
	music.set_arena("officina")
	check(music.playlist() == ["ost_training"], "match favourites independently filter rotation")
	juke._playlist_scope.select(2)
	juke._filter_playlist()
	check(juke._playlist_ids() == ["ost_training"], "Jukebox match playlist filters to favourites")
	juke._play_playlist(0)
	check(juke._manager.current_track_id() == "ost_training", "listen playlist starts favourite")
	juke._manager.stop(0.0)
	juke._process(0.2)
	check(juke._manager.current_track_id() == "ost_training", "preview advances only within favourite playlist")
	juke._favorite_buttons.match.pressed.emit()
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
	check(juke._only_buttons.menu.button_pressed and juke._only_buttons.match.button_pressed, "both filters restored when Jukebox reopens")
	juke._classic_favorite.button_pressed = true
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
	check(music._track == "classic_match", "random R3 safely handles single favourite")
	skip.pressed = false
	music.handle_skip(skip)
	Prefs.toggle(store, "match", "ost_training")
	Prefs.toggle(store, "match", "ost_roster")
	var valid_random := true
	for i in 12:
		var previous := music._track
		skip.pressed = true
		music.handle_skip(skip)
		valid_random = valid_random and music._track != previous and music.playlist().has(music._track) and music._track != "ost_officina"
		skip.pressed = false
		music.handle_skip(skip)
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
	check(music._track == expected and not Prefs.random_skip(store), "switching back restores fixed R3 sequence")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		music.set_held(true)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://game/out/jukebox-favorites.png")
	juke.free()
	music.free()
	print("MUSIC_PREFERENCES %d/%d" % [checks-failures, checks])
	quit(0 if failures == 0 else 1)
