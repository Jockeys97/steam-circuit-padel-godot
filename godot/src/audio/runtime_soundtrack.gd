extends Node
## Scene-owned OST playback. Owners free it on exit; preview/pause hold its position.
const Manager := preload("res://src/audio/soundtrack_manager.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const Config := preload("res://game/match_config.gd")
const Mixer := preload("res://src/audio/mixer_contract.gd")
const MusicSettings := preload("res://src/audio/music_settings.gd")
const Legacy := preload("res://src/audio/music.gd")
const CLASSIC := "classic_match"
const CLASSIC_SECONDS := 120.0
const R3_HOLD_SECONDS := 0.8
const Preferences := preload("res://src/audio/music_preferences.gd")
signal track_changed(id: String)
signal music_enabled_changed(enabled: bool)

var player: Node
var requested := ""
var fallback := "ost_menu"
var _held := false
var _muted := false
var _elapsed := 0.0
var _gain := -1.0
var _music_gain := -1.0
var classic: Node
var toast: Control
var _track := ""
var _match := false
var _classic_elapsed := 0.0
var _playlist_key := ""
var _playlist_cache: Array[String] = []
var _skip_down := false
var _skip_hold_seconds := 0.0
var _skip_long_fired := false

func _ready() -> void:
	player = Manager.new()
	add_child(player)
	classic = Legacy.new()
	add_child(classic)
	classic.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	toast = preload("res://src/audio/now_playing.gd").new()
	layer.add_child(toast)
	_music_gain = MusicSettings.effective_volume(Config.stored_prefs())
	Mixer.new().apply_music_volume(_music_gain)

func set_screen(id: String) -> void:
	_match = false
	var context := "menu"
	# Navigation is one continuous musical context, not a track per setup screen.
	if id == "result":
		context = "victory"
	request(Manager.track_id_for_context(context), "ost_menu")

func set_arena(id: String) -> void:
	_match = true
	# Runtime arena names differ from the original OST catalogue in these two seats.
	var aliases := {"locomotive": "fonderia", "clockwork": "osservatorio"}
	request(Manager.track_id_for_arena(String(aliases.get(id, id))), "ost_training")

func request(track: String, free_track: String) -> void:
	if requested == track and fallback == free_track:
		return
	requested = track
	fallback = free_track
	_track = ""
	refresh()

func playlist() -> Array[String]:
	var items: Array[String] = []
	var store := Config.save_store()
	var scope := "match" if _match else "menu"
	var favorite_ids := Preferences.favorites(store, scope)
	var only_favorites := Preferences.only(store, scope)
	# Rebuild only when context or ownership changes, not 47 disk lookups per tick.
	var key := str([requested, fallback, _match, Economy.unlock_all(store), Economy.relock_all(store), Economy.owned_ids(store), favorite_ids, only_favorites, Preferences.read(store).get("musicContexts", {})])
	if key == _playlist_key:
		return _playlist_cache
	_playlist_key = key
	var first := requested if Economy.has_access(store, requested) and Manager.has_track(requested) else fallback
	if Preferences.belongs(store, first, scope):
		items.append(first)
	if Preferences.belongs(store, CLASSIC, scope):
		items.append(CLASSIC)
	var candidates: Array = Array(Manager.all_track_ids())
	if requested == "ost_victory" and not only_favorites:
		items = [first]
		_playlist_cache = items
		return items
	for id in candidates:
		if not Preferences.belongs(store, id, scope):
			continue
		if not items.has(id) and Manager.has_track(id) and Economy.has_access(store, id):
			items.append(id)
	# A favourite can be assigned to either context, irrespective of its original tag.
	for id in favorite_ids:
		if Preferences.belongs(store, id, scope) and not items.has(id) and (id == CLASSIC or (Manager.has_track(id) and Economy.has_access(store, id))):
			items.append(id)
	if only_favorites:
		items.assign(items.filter(func(id): return favorite_ids.has(id)))
	_playlist_cache = items
	return items

func advance_track(random_order := false) -> void:
	var items := playlist()
	if items.is_empty():
		_silence()
		return
	if random_order and items.size() > 1:
		var alternatives := items.filter(func(id): return id != _track)
		_play(alternatives[randi_range(0, alternatives.size() - 1)])
	else:
		_play(items[(items.find(_track) + 1) % items.size()])

func handle_skip(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode != KEY_N or key.ctrl_pressed or key.meta_pressed or key.alt_pressed:
			return false
		if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit:
			return false
		if key.pressed and not key.echo:
			advance_track(Preferences.random_skip(Config.save_store()))
		return true
	if not event is InputEventJoypadButton or event.button_index != JOY_BUTTON_RIGHT_STICK:
		return false
	if event.pressed:
		if not _skip_down:
			_skip_down = true
			_skip_hold_seconds = 0.0
			_skip_long_fired = false
	else:
		if _skip_down and not _skip_long_fired:
			advance_track(Preferences.random_skip(Config.save_store()))
		_skip_down = false
		_skip_hold_seconds = 0.0
		_skip_long_fired = false
	return true

func _silence() -> void:
	classic.stop()
	classic.stop_all()
	classic.set_process(false)
	player.stop(0.0)
	_track = ""
	toast.hide()

func _play(id: String) -> void:
	# Stop both engines before switching: the original sequencer is a playlist entry.
	classic.stop()
	classic.stop_all()
	classic.set_process(false)
	player.stop(0.0)
	_track = id
	if not _match and requested != "ost_victory":
		Preferences.Save.save_pref(Config.save_store(), "musicLastMenu", id)
	_classic_elapsed = 0.0
	if id == CLASSIC:
		classic.start()
	else:
		if not player.play_track(id, 0.6):
			return
		var stream: AudioStream = player.active_player().stream.duplicate()
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = false
		player.active_player().stream = stream
		player.active_player().play()
	_sync_hold()
	if bool(Config.stored_prefs().get("nowPlaying", true)) and not _held and not _muted:
		toast.show_track(id, _match)
	track_changed.emit(id)

func refresh() -> void:
	if player == null or requested == "":
		return
	var items := playlist()
	if items.is_empty():
		_silence()
	elif not items.has(_track):
		var index := 0
		if not _match and requested != "ost_victory":
			var last := String(Preferences.read(Config.save_store()).get("musicLastMenu", ""))
			index = (items.find(last) + 1) % items.size() if items.has(last) else randi_range(0, items.size() - 1)
		_play(items[index])
	elif _track != CLASSIC and not player.is_active() and not _held and not _muted:
		advance_track()
	if not bool(Config.stored_prefs().get("nowPlaying", true)):
		toast.hide()
	var gain := float(Config.stored_prefs().get("volume", 0.5))
	if not is_equal_approx(gain, _gain):
		_gain = gain
		Mixer.new().apply_master_gain(gain)
	var music_gain := MusicSettings.effective_volume(Config.stored_prefs())
	if not is_equal_approx(music_gain, _music_gain):
		_music_gain = music_gain
		Mixer.new().apply_music_volume(music_gain)
	_sync_hold()

func set_held(held: bool) -> void:
	_held = held
	if held:
		_skip_down = false
		_skip_hold_seconds = 0.0
		_skip_long_fired = false
	_sync_hold()

func set_muted(muted: bool) -> void:
	_muted = muted
	_sync_hold()

func _sync_hold() -> void:
	if player == null:
		return
	if _held or _muted:
		toast.hide()
	if _track == CLASSIC:
		classic.set_process(not (_held or _muted))
		if _held or _muted:
			classic.stop_all()
		return
	if _held or _muted:
		if not player.is_paused():
			player.pause()
	elif player.is_paused():
		player.resume()

func _process(delta: float) -> void:
	if _skip_down and not _skip_long_fired:
		_skip_hold_seconds += delta
		if _skip_hold_seconds >= R3_HOLD_SECONDS:
			_skip_long_fired = true
			var enabled := bool(Config.stored_prefs().get("musicMuted", false))
			Preferences.Save.save_pref(Config.save_store(), "musicMuted", not enabled)
			refresh()
			music_enabled_changed.emit(enabled)
	if _track == CLASSIC and not _held and not _muted:
		_classic_elapsed += delta
		if _classic_elapsed >= CLASSIC_SECONDS:
			advance_track()
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		refresh()
