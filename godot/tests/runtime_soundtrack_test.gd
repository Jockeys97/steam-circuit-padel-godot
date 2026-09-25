extends SceneTree
const Config := preload("res://game/match_config.gd")
const Save := preload("res://src/modes/modes_save.gd")
const Runtime := preload("res://src/audio/runtime_soundtrack.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func frames(count := 8) -> void:
	for i in count:
		await process_frame

func run() -> void:
	Config.save_dir = "user://runtime-ost-%d" % Time.get_ticks_usec()
	Save.save_pref(Config.save_store(), "musicMuted", true)
	var menu = load("res://game/Main.tscn").instantiate()
	root.add_child(menu)
	await frames()
	var ost = menu._runtime_ost
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "menu boot honors the saved music switch")
	Save.save_pref(Config.save_store(), "musicMuted", false)
	ost.refresh()
	var initial_menu_track: String = ost.player.current_track_id()
	check(ost.playlist().has(initial_menu_track) and ost.player.is_playing(), "live menu starts an eligible OST")
	check(not ost.player.active_player().stream.loop, "OST ends naturally for rotation")
	var menu_stream = ost.player.active_player().stream
	menu._router.go_to("characters")
	await frames()
	check(ost.player.current_track_id() == initial_menu_track and ost.player.active_player().stream == menu_stream, "roster preserves menu track without restarting")
	for screen in ["modes", "arena", "characters"]:
		menu._router.go_to(screen)
		await frames()
		check(ost.player.active_player().stream == menu_stream, "%s keeps continuous menu music" % screen)
	var menu_next_key := InputEventKey.new()
	menu_next_key.physical_keycode = KEY_N
	menu_next_key.pressed = true
	menu._input(menu_next_key)
	check(ost._track != initial_menu_track, "N in the menu advances through the R3 playlist")
	var typing := LineEdit.new()
	menu.add_child(typing)
	typing.grab_focus()
	var track_before_typing: String = ost._track
	menu._input(menu_next_key)
	check(ost._track == track_before_typing, "N typed in a text field does not change music")
	typing.queue_free()
	await frames(2)
	menu._router.go_to("settings")
	await frames(2)
	var menu_hold := InputEventJoypadButton.new()
	menu_hold.button_index = JOY_BUTTON_RIGHT_STICK
	menu_hold.pressed = true
	menu._input(menu_hold)
	ost._process(Runtime.R3_HOLD_SECONDS + 0.01)
	check(bool(Config.stored_prefs().get("musicMuted", false)) and not menu._router.active_screen()._rows["MusicEnabledRow"].on(), "long R3 updates the open settings music switch")
	menu_hold.pressed = false
	menu._input(menu_hold)
	menu_hold.pressed = true
	menu._input(menu_hold)
	ost._process(Runtime.R3_HOLD_SECONDS + 0.01)
	check(not bool(Config.stored_prefs().get("musicMuted", true)) and menu._router.active_screen()._rows["MusicEnabledRow"].on(), "second long R3 restores the open settings switch")
	menu_hold.pressed = false
	menu._input(menu_hold)
	menu._router.go_to("characters")
	await frames(2)
	ost._play(initial_menu_track)
	menu.toggle_jukebox()
	await frames()
	check(ost.player.is_paused(), "Jukebox holds menu soundtrack")
	menu.toggle_jukebox()
	await frames()
	check(not ost.player.is_paused() and ost.player.is_playing(), "closing Jukebox resumes soundtrack")
	menu._router.go_to("drill")
	await frames()
	check(ost.player.current_track_id() == initial_menu_track, "training setup keeps menu music")
	ost.player.stop(0.0)
	ost.refresh()
	check(ost.player.current_track_id() != initial_menu_track, "ended menu track advances instead of restarting")
	Save.save_pref(Config.save_store(), "volume", 0.0)
	ost.refresh()
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "saved zero volume silences real mixer")
	Save.save_pref(Config.save_store(), "volume", 0.5)
	ost.refresh()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "volume restoration unmutes mixer")
	Save.save_pref(Config.save_store(), "musicVolume", 0.37)
	Save.save_pref(Config.save_store(), "musicMuted", true)
	ost.refresh()
	var music_bus := AudioServer.get_bus_index("Music")
	check(AudioServer.is_bus_mute(music_bus), "saved music switch mutes menu music")
	Save.save_pref(Config.save_store(), "musicMuted", false)
	ost.refresh()
	check(not AudioServer.is_bus_mute(music_bus) and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.55 * 0.37)), "saved music switch restores the chosen level")
	Save.save_pref(Config.save_store(), "musicMuted", true)
	menu.queue_free()
	await frames(2)
	check(not is_instance_valid(ost), "menu player is freed when leaving menu")
	var career := Save.load_career(Config.save_store())
	career["unlockAll"] = true
	Save.save_career(Config.save_store(), career)
	Config.set_arena_id("officina")
	var game = load("res://game/Match.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.set_physics_process(false)
	ost = game._audio.ost
	check(AudioServer.is_bus_mute(music_bus), "match boot honors the saved music switch")
	Save.save_pref(Config.save_store(), "musicMuted", false)
	ost.refresh()
	check(not AudioServer.is_bus_mute(music_bus), "match music returns at the saved level")
	check(ost != null and ost.player.current_track_id() == "ost_officina", "live match starts arena OST")
	check(game._audio.music == null, "live match creates no procedural music layer")
	check(game._audio.music_summary().get("track") == "ost_officina", "audio diagnostics report live OST")
	var skip := InputEventJoypadButton.new()
	skip.button_index = JOY_BUTTON_RIGHT_STICK
	skip.pressed = true
	game._input(skip)
	check(ost._track == "ost_officina", "R3 waits to distinguish a tap from a hold")
	game._input(skip)
	check(ost._track == "ost_officina", "repeated R3 press does not skip")
	skip.pressed = false
	game._input(skip)
	check(ost._track == "classic_match", "short R3 in actual match input skips to next track")
	ost._play("ost_officina")
	skip.pressed = true
	game._input(skip)
	ost._process(Runtime.R3_HOLD_SECONDS + 0.01)
	check(ost._track == "ost_officina" and bool(Config.stored_prefs().get("musicMuted", false)) and AudioServer.is_bus_mute(music_bus), "long R3 mutes music without skipping")
	check(not game._audio.port.is_muted(), "long R3 leaves match effects enabled")
	game._input(skip)
	ost._process(Runtime.R3_HOLD_SECONDS + 0.01)
	check(bool(Config.stored_prefs().get("musicMuted", false)), "held R3 toggles music only once")
	skip.pressed = false
	game._input(skip)
	check(ost._track == "ost_officina", "releasing a long R3 does not skip")
	skip.pressed = true
	game._input(skip)
	ost._process(Runtime.R3_HOLD_SECONDS + 0.01)
	check(not bool(Config.stored_prefs().get("musicMuted", true)) and not AudioServer.is_bus_mute(music_bus) and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.55 * 0.37)), "second long R3 restores the saved music volume")
	skip.pressed = false
	game._input(skip)
	var next_key := InputEventKey.new()
	next_key.physical_keycode = KEY_N
	next_key.pressed = true
	game._input(next_key)
	check(ost._track == "classic_match", "N in the match advances through the R3 playlist")
	ost._play("ost_officina")
	next_key.echo = true
	game._input(next_key)
	check(ost._track == "ost_officina", "held N does not repeatedly skip")
	ost._play("ost_officina")
	check(ost.toast.visible and ost.toast._cover.texture != null, "track notice has cover")
	if "--capture-audio" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://game/out/now-playing-match.png")
	ost.advance_track()
	check(ost._track == "classic_match" and ost.classic.playing and not ost.player.is_active(), "original theme rotates without OST overlap")
	game._ui_hud._mute_button.pressed.emit()
	check(not ost.classic.is_processing(), "HUD mute also stops classic sequencer")
	game._ui_hud._mute_button.pressed.emit()
	check(ost.classic.is_processing(), "unmute resumes classic sequencer")
	ost._process(121.0)
	check(ost._track != "classic_match" and not ost.classic.playing, "classic segment advances after two minutes")
	game._pause_overlay.set_row_value("NowPlayingRow", 0.0)
	game._pause_overlay.set_tab("controller")
	if "--capture-audio" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		game._pause_overlay.pause()
		game._pause_overlay.set_tab("controller")
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://game/out/now-playing-option.png")
		game._pause_overlay.resume()
	var notice_registered := false
	for entry in game._pause_overlay.focus_controls():
		if entry.node == game._pause_overlay._now_playing_row.check:
			notice_registered = true
	check(notice_registered, "notice option is registered for controller navigation")
	ost.refresh()
	check(not ost.toast.visible and not Config.stored_prefs().get("nowPlaying", true), "pause option persists and hides notices")
	ost.advance_track()
	check(not ost.toast.visible and ost.player.is_active(), "disabled notices do not silence music")
	game._pause_overlay.set_row_value("NowPlayingRow", 1.0)
	ost._play("ost_officina")
	check(ost.toast.visible, "re-enabled notices show on next track")
	game._ui_hud._mute_button.pressed.emit()
	check(ost.player.is_paused() and game._audio.port.is_muted(), "HUD mute button silences OST immediately")
	ost.refresh()
	check(ost.player.is_paused(), "refresh does not undo HUD mute")
	game._ui_hud._mute_button.pressed.emit()
	check(ost.player.is_playing(), "HUD unmute resumes OST")
	game.set_match_paused(true)
	check(ost.player.is_paused(), "pause holds music")
	game._ui_hud._mute_button.pressed.emit()
	game.set_match_paused(false)
	check(ost.player.is_paused(), "resuming match preserves HUD mute")
	game._ui_hud._mute_button.pressed.emit()
	check(ost.player.is_playing() and not ost.player.is_paused(), "resume restarts held music")
	ost.set_arena("locomotive")
	check(ost.player.current_track_id() == "ost_fonderia", "legacy arena alias resolves")
	ost.set_arena("clockwork")
	check(ost.player.current_track_id() == "ost_osservatorio", "second legacy arena alias resolves")
	career["lockAll"] = true
	career["unlockAll"] = false
	Save.save_career(Config.save_store(), career)
	ost.refresh()
	check(ost.player.current_track_id() == "ost_training", "Alelu uses an audible starter fallback")
	game._audio._drive_music({"result": {"winner": "player"}})
	check(ost.player.current_track_id() == "ost_victory", "result event switches to result theme")
	game._audio.reset()
	check(ost.player.current_track_id() == "ost_training", "rematch resets to gated arena music")
	game.queue_free()
	await frames(2)
	check(not is_instance_valid(ost), "match player is freed on exit")
	print("RUNTIME_OST %s %d/%d" % ["PASS" if failures == 0 else "FAIL", checks-failures, checks])
	quit(0 if failures == 0 else 1)
