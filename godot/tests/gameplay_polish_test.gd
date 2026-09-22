extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
const Tactics = preload("res://src/sim/court_tactics.gd")
const Spawn = preload("res://src/character/athlete_spawn.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ", label)
func fresh():
	var s = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1], 0, {"seed":12345})
	s.serving = false
	s.running = true
	s.serviceReceiverKey = null
	s.aiServiceReceiverKey = null
	return s
func _initialize():
	call_deferred("run")
func run():
	var court = Frozen.court()
	var centre: float = (court.left + court.right) * 0.5
	var width: float = court.right - court.left
	for side in [-1.0, 1.0]:
		var lane = Tactics.cover_lane(centre, centre + side * width * 0.22, court.left, court.right)
		for offset in [-10.0, -1.0, 0.0, 1.0, 10.0]:
			check(Tactics.cover_lane(centre + offset, lane, court.left, court.right) == lane, "centre does not flip coverage")
	check(Tactics.safe_cover_y(480, 440, 350, 440, 620, 440, court.bottom) > 440, "crossing yields behind player")
	check(Tactics.safe_cover_y(480, 440, 620, 440, 620, 440, court.bottom) == 440, "no unnecessary detour")
	var crossing_game = fresh()
	crossing_game.player.x = centre - width * 0.15
	crossing_game.player.y = court.netY + 120
	crossing_game.playerMate.x = crossing_game.player.x - 50
	crossing_game.playerMate.y = crossing_game.player.y
	var min_distance := 1000.0
	for i in 240:
		Sim.move_tactical_mate(crossing_game, crossing_game.playerMate, 1.0/120)
		min_distance = minf(min_distance, Vector2(crossing_game.player.x-crossing_game.playerMate.x,crossing_game.player.y-crossing_game.playerMate.y).length())
	check(min_distance >= 49.9, "moving teammate creates space before crossing")
	check(crossing_game.playerMate.x > crossing_game.player.x, "detour completes without freezing teammate")
	for mode in ["manual", "semi", "auto"]:
		for key in ["player", "playerMate"]:
			var s = fresh()
			s.controlMode = mode
			s.activePlayerKey = key
			var mate = s.playerMate if key == "player" else s.player
			s.ball.x = mate.x
			s.ball.y = mate.y
			s.ball.z = 40
			s.ball.vy = 50
			s.ball.bounces.player = 1
			s.lastHitterSide = "ai"
			var before: int = s.rallyHits
			for i in 120:
				Sim.update_doubles_ai(s, 1.0 / 120)
			check(s.rallyHits == before and mate.swing == 0, "no autonomous human-team contact " + mode + key)
	for human_mode in ["coop", "pvp"]:
		var game = fresh()
		game.coop = human_mode == "coop"
		game.pvp = human_mode == "pvp"
		game.ball.x = game.playerMate.x
		game.ball.y = game.playerMate.y
		game.ball.z = 40
		game.ball.vy = 50
		game.ball.bounces.player = 1
		game.lastHitterSide = "ai"
		var before: int = game.rallyHits
		Sim.update_doubles_ai(game, 1.0/60)
		check(game.rallyHits == before, "no automatic teammate contact " + human_mode)
	var s = fresh()
	s.aiReceiverLocked = true
	s.aiPrimaryKey = "opponent"
	s.aiReactionDelay = 0.25
	s.ball.x = centre + 180
	s.ball.y = court.netY - 50
	s.ball.z = 40
	s.ball.vy = -180
	var positions = [Vector2(s.opponent.x,s.opponent.y), Vector2(s.opponentMate.x,s.opponentMate.y)]
	Sim.move_opponent_team(s, 1.0/60)
	check(positions[0] == Vector2(s.opponent.x,s.opponent.y), "primary respects reaction")
	check(absf(s.opponentMate.x-positions[1].x) <= s.opponentMate.speed/60 + 0.001, "support recovery stays physically bounded")
	var support_before_x: float = s.opponentMate.x
	s.aiReactionDelay = 0
	Sim.move_opponent_team(s, 1.0/60)
	check(positions[1] != Vector2(s.opponentMate.x,s.opponentMate.y), "support resumes after reaction")
	check(absf(s.opponentMate.x-support_before_x) <= s.opponentMate.speed/60 + 0.001, "no speed buff")
	s.ball.x = s.opponent.x + 200
	s.ball.y = s.opponent.y + 20
	s.ball.vy = -120
	var fresh_score: float = Sim.ai_responder_forecast(s.opponent,s.ball).score
	s.opponent.staminaEnergy = 0.15
	check(Sim.ai_responder_forecast(s.opponent,s.ball).score > fresh_score, "forecast accounts for fatigue")
	# Same skill/physics, different shot selection preferences across roster styles.
	var counts := {}
	for id in ["fiamma", "maestro", "oracolo"]:
		counts[id] = 0
		s.lineup = s.lineup.duplicate(true)
		s.lineup.opponent = Frozen.athletes()[0].duplicate(true)
		s.lineup.opponent.id = id
		s.opponent.y = court.netY - 60
		s.ball.y = s.opponent.y
		s.ball.z = 85
		s.ball.vy = -100
		s.rallyHits = 3
		for seed in 500:
			s.rng_state = 1000 + seed * 7919
			var choice = Sim.choose_computer_shot(s,s.opponent,s.ai,85,1.0)
			if choice.kind.begins_with("smash"):
				counts[id] += 1
	check(counts.fiamma > counts.maestro and counts.maestro > counts.oracolo, "roster styles change decisions at same difficulty")
	print("STYLE_SMASH_COUNTS ", counts)
	for id in [&"maestro", &"fiamma", &"colosso"]:
		var rig = Spawn.make(id, &"base")
		root.add_child(rig)
		rig.play_stroke_at(&"drive",0.34,1.0)
		rig.play_locomotion(&"run")
		check(not rig.recover_to_movement() and rig.is_stroking(), "preserve actual contact")
		var length: float = rig.clip_length(&"drive") if rig.has_method("clip_length") else rig._anim.get_animation(&"drive").length
		rig.sample_at(maxf(length*0.80,length*0.34+0.13))
		check(rig.recover_to_movement(), "moving recovery does not wait for entire tail")
		check(not rig.is_stroking() and rig._anim.current_animation == "run", "resume pending run")
		check(rig.position == Vector3.ZERO, "no root motion")
		rig.free()
	print("GAMEPLAY_POLISH %d/%d" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
