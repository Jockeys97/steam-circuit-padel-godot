extends SceneTree
## jukebox_player_test.gd — probe stage (temporary).

const SoundtrackManager := preload("res://src/audio/soundtrack_manager.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	print("PROBE driver=", AudioServer.get_driver_name(), " mix_rate=", AudioServer.get_mix_rate())
	print("A start")
	await create_timer(0.3).timeout
	print("A done")
	var sm := SoundtrackManager.new()
	root.add_child(sm)
	await process_frame
	var ok := sm.play_track("ost_sawano_titan_breach", 0.01)
	print("PROBE play=", ok)
	await create_timer(0.5).timeout
	print("PROBE playing=", sm.is_playing() if sm.has_method("is_playing") else "n/a")
	if sm.active_player() != null:
		var p: AudioStreamPlayer = sm.active_player()
		print("PROBE pos=", p.get_playback_position(), " len=", (p.stream.get_length() if p.stream != null else -1.0), " playing=", p.playing)
	quit(0)
