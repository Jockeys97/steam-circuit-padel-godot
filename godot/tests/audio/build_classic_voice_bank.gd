extends SceneTree
## Developer-only bake: run with Godot --headless --path godot --script
## res://tests/audio/build_classic_voice_bank.gd. Regenerate after changing the
## original theme's oscillator, envelope, filter, or progression.

const Music := preload("res://src/audio/music.gd")
const VoiceBank := preload("res://src/audio/classic_voice_bank.gd")
const OUTPUT := "res://src/audio/classic_voice_bank.res"


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var music := Music.new()
	root.add_child(music)
	music.set_process(false)
	var bank := VoiceBank.new()
	# At intensity 1 every conditional layer is present. Gains do not belong to
	# the sample key, so this covers all lower intensities as well.
	for step in Music.LOOP_STEPS:
		for event in music.step_events(step, 1.0):
			var key: String = music._voice_key(event)
			if not bank.voices.has(key):
				bank.voices[key] = music._render(event)
	var error := ResourceSaver.save(bank, OUTPUT)
	if error != OK:
		push_error("Classic voice bake failed: %s" % error)
		quit(1)
		return
	var read: Resource = ResourceLoader.load(OUTPUT, "", ResourceLoader.CACHE_MODE_IGNORE)
	if read == null or not read is VoiceBank or read.voices.size() != bank.voices.size():
		push_error("Classic voice bake did not round-trip")
		quit(1)
		return
	for key in bank.voices:
		var stream: AudioStreamWAV = read.voices.get(key)
		if stream == null or stream.data != (bank.voices[key] as AudioStreamWAV).data:
			push_error("Classic voice bake differs at %s" % key)
			quit(1)
			return
	print("CLASSIC VOICE BANK: %d samples, %d bytes" % [read.voices.size(), FileAccess.get_file_as_bytes(OUTPUT).size()])
	music.queue_free()
	quit(0)
