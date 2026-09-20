extends SceneTree
const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")
const Stamina = preload("res://src/sim/rally_stamina.gd")
var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", label)

func fresh(mode: String = "solo"):
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1], 0, {"humanMode": mode, "seed": 12345})
	state.running = true
	state.rng_state = 12345
	return state

func scenario(seconds: int, hz: int, kind: String, movement: float, sprint: float) -> float:
	var energy := 1.0
	for i in seconds * hz:
		energy = Stamina.effort_energy(energy, 1.0 / hz, movement, sprint)
		if (i + 1) % (3 * hz) == 0:
			energy = maxf(Stamina.FLOOR, energy - Stamina.shot_cost(kind, false, "control"))
	return energy

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		var cases = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
		for row in cases:
			check(absf(Stamina.effort_energy(row.energy, row.dt, row.movement, row.sprint, row.stamina) - row.next) < 0.00000001, "JS effort parity")
			check(absf(Stamina.speed_factor(row.energy) - row.speed) < 0.00000001, "JS speed parity")
			check(absf(Stamina.assessment_energy(row.energy) - row.assessment) < 0.00000001, "JS quality parity")
	for hz in [30, 60, 120]:
		var short := scenario(10, hz, "safe-drive", 0.5, 0.0)
		var long_control := scenario(30, hz, "safe-drive", 0.5, 0.0)
		var long_smash := scenario(30, hz, "smash", 0.5, 0.0)
		check(short >= 0.75 and Stamina.speed_factor(short) == 1.0, "short rally stays fresh")
		check(long_control >= 0.5 and long_smash < long_control, "controlled long rally")
		check(absf(long_control - scenario(30, 120, "safe-drive", 0.5, 0.0)) < 0.00001, "frame independent")
		print("SCENARIO ", hz, " ", short, " ", long_control, " ", long_smash)
	for i in 101:
		var e := float(i) / 100.0
		check(Stamina.speed_factor(e) >= 0.88 and Stamina.speed_factor(e) <= 1.0, "bounded speed")
		check(is_finite(Stamina.assessment_energy(e)), "finite assessment")
	check(Stamina.effort_energy(0.5, 1, 0, 0) > 0.5, "idle recovery")
	check(Stamina.effort_energy(0.5, 1, 1, 1) < Stamina.effort_energy(0.5, 1, 1, 0), "sprint costs more")
	check(Stamina.effort_energy(0.5, 1, 1, 1, 1.4) > Stamina.effort_energy(0.5, 1, 1, 1, 0.7), "resistance matters")
	var fresh_state = fresh()
	var tired_state = fresh()
	fresh_state.serving = false
	tired_state.serving = false
	tired_state.player.staminaEnergy = 0.15
	var move := Sim.empty_input()
	move.moveX = 1.0
	var initial_x: float = fresh_state.player.x
	Sim.move_human_paddle(fresh_state, fresh_state.player, move, 1.0 / 60)
	Sim.move_human_paddle(tired_state, tired_state.player, move, 1.0 / 60)
	check(absf((tired_state.player.x - initial_x) / (fresh_state.player.x - initial_x) - 0.88) < 0.00001, "actual human speed floor")
	fresh_state.ball.x = fresh_state.player.x
	fresh_state.ball.y = fresh_state.player.y
	fresh_state.ball.z = 50.0
	var high = Sim.evaluate_shot_quality(fresh_state, fresh_state.player, {"aiTiming": 0.8})
	fresh_state.player.staminaEnergy = 0.6
	var threshold = Sim.evaluate_shot_quality(fresh_state, fresh_state.player, {"aiTiming": 0.8})
	check(high.quality == threshold.quality, "no precision loss above threshold")
	fresh_state.player.staminaEnergy = 0.15
	var low = Sim.evaluate_shot_quality(fresh_state, fresh_state.player, {"aiTiming": 0.8})
	check(low.quality < high.quality and high.quality - low.quality <= 0.05, "bounded existing precision penalty")
	fresh_state.ball.x = -9999
	check(not Sim.hit_ball(fresh_state, fresh_state.player), "miss does not contact")
	check(fresh_state.player.staminaEnergy == 0.15, "miss does not consume contact energy")
	var fair = fresh()
	fair.lineup = fair.lineup.duplicate(true)
	for key in ["player", "playerMate", "opponent", "opponentMate"]:
		fair.lineup[key] = Frozen.athletes()[0].duplicate(true)
		fair.lineup[key]["stats"]["stamina"] = 1.0
		var p = fair.paddle(key)
		Sim.consume_rally_energy(fair, p, {"mode": "power"}, "smash-flat", false)
		check(absf(p.staminaEnergy - 0.875) < 0.000001, "identical human and AI contact costs")
	for mode in ["solo", "coop", "pvp"]:
		var state = fresh(mode)
		var pads = [state.player, state.playerMate, state.opponent, state.opponentMate]
		for p in pads:
			Sim.consume_rally_energy(state, p, {"mode": "power"}, "smash", false)
			check(p.staminaEnergy < 1.0, "contact charges actual hitter")
		check(state.player.staminaEnergy > 0.8, "no shared team drain")
		var e: float = state.player.staminaEnergy
		state.paused = true
		Sim.update_match(state, 1.0 / 60, Sim.empty_input())
		check(state.player.staminaEnergy == e, "pause no drain")
		state.paused = false
		Sim.update_match(state, 1.0 / 60, Sim.empty_input())
		check(state.player.staminaEnergy == e, "serve setup no drain")
		state.serving = false
		state.hitStop = 1.0
		Sim.update_match(state, 1.0 / 60, Sim.empty_input())
		check(state.player.staminaEnergy == e, "hitstop no continuous drain")
		state.player.staminaEnergy = 0.15
		state.playerMate.staminaEnergy = 0.9
		state.activePlayerKey = "playerMate"
		Sim.sync_rally_energy(state)
		check(state.player.staminaEnergy == 0.15 and state.rallyEnergy.player == 0.9, "switch preserves both energies")
		Sim.score_point(state, "player", "")
		for p in pads:
			check(p.staminaEnergy == 1.0, "point reset")
	print("PASS %d/%d" % [checks, checks] if failures == 0 else "FAIL %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)
