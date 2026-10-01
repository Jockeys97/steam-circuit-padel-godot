extends SceneTree

const StateScript := preload("res://src/sim/state.gd")
const MatchAudioScript := preload("res://game/match_audio.gd")
const LocaleScript := preload("res://src/locale/locale.gd")

var _failed := 0


func _initialize() -> void:
	await _run()
	quit(1 if _failed > 0 else 0)


func _check(label: String, good: bool) -> void:
	print("%s %s" % ["ok" if good else "FAIL", label])
	if not good:
		_failed += 1


func _run() -> void:
	var state = StateScript.new()
	state.stats = {"pointsWon": {"player": 0, "ai": 0}, "aces": {"player": 0, "ai": 0}}
	_check("no announcement at opening score", MatchAudioScript.match_point_side(state) == "")
	state.games = {"player": 2, "ai": 2}
	state.points = {"player": 3, "ai": 2}
	_check("ordinary game point has its own cue", MatchAudioScript.score_cue(state).get("kind") == "game-point")
	state.serveSide = "ai"
	_check("receiver game point is break point", MatchAudioScript.score_cue(state).get("kind") == "break-point")
	state.serveSide = "player"

	state.games["player"] = 5
	state.games["ai"] = 3
	state.points["player"] = 3
	state.points["ai"] = 2
	_check("last game and set point is match point", MatchAudioScript.match_point_side(state) == "player")
	state.setsToWin = 2
	_check("first-set point is not match point", MatchAudioScript.match_point_side(state) == "")
	_check("first-set point has set cue", MatchAudioScript.score_cue(state).get("kind") == "set-point")
	state.sets["player"] = 1
	_check("final-set point is match point", MatchAudioScript.match_point_side(state) == "player")
	state.points["ai"] = 3
	_check("deuce is not match point", MatchAudioScript.match_point_side(state) == "")
	state.points["player"] = 4
	_check("advantage on final game is match point", MatchAudioScript.match_point_side(state) == "player")

	state.tieBreak = true
	state.tieBreakPoints = {"player": 6, "ai": 5}
	_check("final-set tiebreak point is match point", MatchAudioScript.match_point_side(state) == "player")
	state.sets["player"] = 0
	_check("first-set tiebreak point has set cue", MatchAudioScript.score_cue(state).get("kind") == "set-point")
	state.sets["player"] = 1
	state.tieBreakPoints["ai"] = 6
	_check("tiebreak 6-6 is not match point", MatchAudioScript.match_point_side(state) == "")
	state.tieBreak = false
	state.pointsToWin = 3
	state.points = {"player": 0, "ai": 2}
	_check("short-match threshold covers opponent", MatchAudioScript.match_point_side(state) == "ai")
	state.result = {"winner": "ai"}
	_check("finished match has no match point", MatchAudioScript.match_point_side(state) == "")

	state.result = null
	state.pointsToWin = 3
	state.points = {"player": 2, "ai": 0}
	state.stats["pointsWon"] = {"player": 2, "ai": 0}
	var audio: Node = MatchAudioScript.new()
	root.add_child(audio)
	await process_frame
	_check("announcer uses SFX bus", audio.announcer.bus == "SFX")
	audio.announcer_enabled = false
	audio._observe_announcer(state)
	_check("disabled Bruno stays silent on match point", not audio.announcer.is_playing())
	audio.announcer_enabled = true
	LocaleScript.set_lang("en")
	state.pointPause = 1.4
	audio._observe_announcer(state)
	_check("voice waits for point pause", not audio.announcer.is_playing())
	state.pointPause = 0.0
	audio._observe_announcer(state)
	_check("English match point starts Bruno", audio.announcer.is_playing())
	audio.announcer.stop()
	audio._observe_announcer(state)
	_check("same point is not re-announced", not audio.announcer.is_playing())
	audio.reset()
	LocaleScript.set_lang("it")
	audio._observe_announcer(state)
	_check("Italian UI still plays the English voice", audio.announcer.is_playing() and audio.announcer.stream == MatchAudioScript.MATCH_POINT_VOICE)
	LocaleScript.set_lang("en")
	audio.port.set_muted(true)
	audio._observe_announcer(state)
	_check("mute prevents spoken cue", not audio.announcer.is_playing())
	audio.port.set_muted(false)
	audio.reset()
	LocaleScript.set_lang("en")
	audio._observe_announcer(state)
	_check("reset permits a rematch cue", audio.announcer.is_playing())
	audio.reset()
	state.pointsToWin = 0
	state.setsToWin = 1
	state.sets = {"player": 0, "ai": 0}
	state.games = {"player": 2, "ai": 2}
	state.points = {"player": 3, "ai": 2}
	audio._observe_announcer(state)
	_check("game point plays its short cue", audio.announcer.stream == MatchAudioScript.GAME_POINT_VOICE)
	audio.reset()
	state.serveSide = "ai"
	audio._observe_announcer(state)
	_check("break point replaces game point on return", audio.announcer.stream == MatchAudioScript.BREAK_POINT_VOICE)
	audio.announcer.stop()
	audio._observe_announcer(state)
	_check("break point is not repeated in the same game", not audio.announcer.is_playing())
	state.serveSide = "player"
	audio.reset()
	audio._observe_announcer(state)
	_check("new match restores ordinary game point", audio.announcer.stream == MatchAudioScript.GAME_POINT_VOICE)
	audio.announcer.stop()
	state.stats["pointsWon"]["player"] = 3
	audio._observe_announcer(state)
	_check("game point stays quiet in the same game", not audio.announcer.is_playing())
	state.games["player"] = 5
	state.games["ai"] = 3
	audio._observe_announcer(state)
	_check("match point supersedes game cue", audio.announcer.stream == MatchAudioScript.MATCH_POINT_VOICE)
	audio.reset()
	state.setsToWin = 2
	state.sets["player"] = 0
	audio._observe_announcer(state)
	_check("set point plays its short cue", audio.announcer.stream == MatchAudioScript.SET_POINT_VOICE)
	audio.reset()
	state.points = {"player": 0, "ai": 0}
	state.tieBreak = true
	state.tieBreakPoints = {"player": 0, "ai": 0}
	audio._observe_announcer(state)
	_check("tie-break plays its short intro", audio.announcer.stream == MatchAudioScript.TIE_BREAK_VOICE)
	audio.announcer.stop()
	state.stats["pointsWon"]["player"] = 4
	audio._observe_announcer(state)
	_check("tie-break intro is not repeated", not audio.announcer.is_playing())
	audio.reset()
	state.tieBreak = false
	state.points = {"player": 0, "ai": 0}
	state.games = {"player": 0, "ai": 0}
	state.pointPause = 1.4
	audio._observe_announcer(state)
	state.stats["aces"]["player"] = 1
	audio._observe_announcer(state)
	_check("recorded ace plays Bruno during point pause", audio.announcer.stream == MatchAudioScript.ACE_VOICE and audio.announcer.is_playing())
	audio.announcer.stop()
	audio._observe_announcer(state)
	_check("same ace is not repeated", not audio.announcer.is_playing())
	LocaleScript.set_lang("it")
	state.result = {"winner": "player"}
	state.stats["aces"]["player"] = 2
	audio._observe_announcer(state)
	_check("Italian UI announces match end over final ace", audio.announcer.stream == MatchAudioScript.MATCH_OVER_VOICE)
	audio.free()
	var runtime := root.get_node_or_null("BackgroundMusic")
	_check("persistent soundtrack is available for the result route", runtime != null)
	if runtime != null:
		runtime.play_match_end_announcement(MatchAudioScript.MATCH_OVER_VOICE, false)
		await create_timer(0.45).timeout
		_check("result sting is not covered by the voice", not runtime.announcer_player.is_playing())
		await create_timer(1.20).timeout
		_check("match-end voice survives the match node", runtime.announcer_player.is_playing())
		runtime.stop_match_end_announcement()
		runtime.play_match_end_announcement(MatchAudioScript.MATCH_OVER_VOICE, false)
		runtime.stop_match_end_announcement()
		await create_timer(1.65).timeout
		_check("a rematch cancels a queued result cue", not runtime.announcer_player.is_playing())
		runtime.play_match_end_announcement(MatchAudioScript.MATCH_OVER_VOICE, true)
		_check("muted result remains silent", not runtime.announcer_player.is_playing())
	print("%s announcer match point" % ["PASS" if _failed == 0 else "FAIL"])
