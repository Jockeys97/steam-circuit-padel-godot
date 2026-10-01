extends SceneTree
## return_winner_probe.gd — how often a hard, angled return of serve is a clean winner
## (2026-09-30, owner: "rimangono ancora molti punti diretti in risposta alla battuta").
##
## The AI serves; when the serve has bounced and reaches the human receiver, the
## human returns it with a forced, fully charged drive or slice aimed at a corner.
## Then nobody on the human side touches anything: the probe counts how often the
## AI never gets its racket on the return (a direct winner) and how often it does.
##
## Run: godot --headless --path godot/ --script res://game/tools/return_winner_probe.gd
## Environment: SEEDS=60, LEVELS=0,3

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const DT := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 60
	var levels := (OS.get_environment("LEVELS") if OS.get_environment("LEVELS") != "" else "0,3").split(",")
	for level in levels:
		for slice in [false, true]:
			var m := {"returns": 0, "winners": 0, "ai_touched": 0, "wrong_footed": 0, "delay_sum": 0.0}
			for seed in range(1, seeds + 1):
				_one(int(level), seed, slice, m)
			var name := String(Frozen.ai_opponents()[int(level)].get("id", level))
			print("== %-9s %-5s risposte %d  punti diretti %.0f%%  l'IA la tocca %.0f%%  presa in contropiede %.0f%%  ritardo medio %.2f s" % [
				name, "slice" if slice else "drive", m.returns, 100.0 * m.winners / maxf(1, m.returns),
				100.0 * m.ai_touched / maxf(1, m.returns), 100.0 * m.wrong_footed / maxf(1, m.returns), m.delay_sum / maxf(1, m.returns)])
	quit(0)


func _one(level: int, seed: int, slice: bool, m: Dictionary) -> void:
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[level])
	state.rng_state = seed * 104729
	state.running = true
	state.serveSide = "ai"
	Sim.prepare_serve(state)
	var idle: Dictionary = Sim.empty_input()
	var returned := false
	for _t in 3000:
		if not returned:
			var p = state.active_player()
			var ball = state.ball
			if not bool(state.serving) and int(ball.bounces["player"]) >= 1 and ball.vy > 0.0 \
					and absf(ball.y - p.y) < 30.0 and ball.z < 90.0:
				p.x = ball.x
				var aim := 0.95 if ball.x < 480.0 else -0.95   # cross-court, to the far corner
				if Sim.hit_ball(state, p, 1.35, false, true, aim, slice, "slice" if slice else "drive"):
					returned = true
					m.returns += 1
					m.delay_sum += float(state.aiReactionDelay)
					if bool(state.aiWrongFooted):
						m.wrong_footed += 1
					continue
			# Follow the serve so the contact happens.
			var input: Dictionary = Sim.empty_input()
			if not bool(state.serving):
				input["moveX"] = clampf((ball.x - p.x) / 55.0, -1.0, 1.0)
			Sim.update_match(state, DT, input, idle)
			if int(state.stats["pointsWon"]["player"]) + int(state.stats["pointsWon"]["ai"]) > 0:
				return
			continue
		var hits_before := int(state.rallyHits)
		var won_before := int(state.stats["pointsWon"]["player"])
		Sim.update_match(state, DT, idle, idle)
		if int(state.rallyHits) > hits_before:
			m.ai_touched += 1
			return
		if int(state.stats["pointsWon"]["player"]) > won_before:
			m.winners += 1
			return
		if int(state.stats["pointsWon"]["ai"]) > 0:
			return
