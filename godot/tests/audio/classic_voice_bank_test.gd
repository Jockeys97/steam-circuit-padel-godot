extends SceneTree
## The original theme has every possible sample ready before its first match tick.
## Also detects a stale bake if the synthesis recipe changes.

const Music := preload("res://src/audio/music.gd")
const Bank := preload("res://src/audio/classic_voice_bank.res")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("ok %s" % label)
	else:
		_failures += 1
		push_error("FAIL %s" % label)


func _run() -> void:
	var music := Music.new()
	# Keep this focused audit out of the tree: it tests sample lookup and the
	# scheduler, while music_port_test covers actual audio playback and buses.
	music._hat_rng.seed = 1
	music._load_contract()
	var signatures: Dictionary = {}
	for step in Music.LOOP_STEPS:
		for event in music.step_events(step, 1.0):
			var key: String = music._voice_key(event)
			if not signatures.has(key):
				signatures[key] = event
	_check(signatures.size() == Bank.voices.size(), "bank covers the full-intensity 64-step loop")
	_check(music.bank_size() == signatures.size(), "runtime sees the baked bank")
	var all_gates_covered := true
	for intensity in [0.0, 0.12, 0.4, 0.41, 0.6, 0.61, 0.72, 0.73, 1.0]:
		for step in Music.LOOP_STEPS:
			for event in music.step_events(step, intensity):
				if not Bank.voices.has(music._voice_key(event)):
					all_gates_covered = false
	_check(all_gates_covered, "every intensity gate uses a baked signature")
	var identical := true
	for key in signatures:
		var baked: AudioStreamWAV = Bank.voices.get(key)
		if baked == null:
			identical = false
			continue
		var fresh: AudioStreamWAV = music._render(signatures[key])
		if baked.data != fresh.data or baked.mix_rate != fresh.mix_rate or baked.format != fresh.format:
			identical = false
	_check(identical, "every baked PCM sample matches the current synth recipe")
	var start_us := Time.get_ticks_usec()
	music.start(0.0)
	var first: Array = music.tick(0.0)
	var first_us := Time.get_ticks_usec() - start_us
	_check(first.size() == 1 and music.voices_started == 4, "first tick starts the original four voices")
	var streams_baked := true
	for key in signatures:
		var p: AudioStreamPlayer = music._voice_for(signatures[key])
		if p == null or p.stream != Bank.voices.get(key):
			streams_baked = false
	_check(streams_baked and music.pool_size() == signatures.size(), "all runtime players use bank streams, with no synthesis")
	_check(music.last_error == "", "no voice signature is missing")
	print("CLASSIC FIRST TICK: %.3f ms (diagnostic, not a hardware-dependent pass gate)" % (float(first_us) / 1000.0))
	music.reset()
	music.free()
	_finish.call_deferred()


func _finish() -> void:
	print("CLASSIC VOICE BANK %s %d/%d" % ["PASS" if _failures == 0 else "FAIL", _checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
