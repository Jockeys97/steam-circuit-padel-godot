extends SceneTree
## smash_defence_probe.gd — how many AI smashes the human side saves, by where the
## defender stands when the smash is struck (2026-09-29).
##
## The owner: "la difesa dalle schiacciate deve essere tosta no?". Tough is fine,
## unfair is not: this measures whether standing back and playing off the back glass
## saves smashes, or whether nothing does. The scripted human plays short, uncharged
## lobs so the AI smashes; at the smash contact both human-side athletes are moved to
## the chosen depth (x kept) and the scripted player defends from there.
##
## Run (from the repo root):
##   godot --headless --path godot/ --script res://game/tools/smash_defence_probe.gd
## Environment: SEEDS=12, LEVELS=0,3

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const DT := 1.0 / 120.0
const MAX_TICKS := 60000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seeds := int(OS.get_environment("SEEDS")) if OS.get_environment("SEEDS") != "" else 12
	var levels := (OS.get_environment("LEVELS") if OS.get_environment("LEVELS") != "" else "0,3").split(",")
	var court: Dictionary = Frozen.court()
	var net_y := float(court["netY"])
	var bottom := float(court["bottom"])
	print("SMASH_DEFENCE net_y=%.0f bottom=%.0f seeds=%d" % [net_y, bottom, seeds])
	var spots := {"rete": net_y + 90.0, "meta": net_y + 200.0, "fondo": bottom - 45.0}
	for level in levels:
		for spot in spots:
			for hold in [false, true]:
				_report(int(level), spot, hold, _measure(int(level), float(spots[spot]), hold, seeds))
	quit(0)


func _measure(level: int, depth: float, hold: bool, seeds: int) -> Dictionary:
	var m := {"smashes": 0, "returned": 0, "after_glass": 0, "returned_in": 0, "point_won": 0, "by_mate": 0, "lost_by": {}}
	var profile: Dictionary = Frozen.ai_opponents()[level]
	for seed in range(1, seeds + 1):
		var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], profile)
		state.rng_state = seed * 7919
		state.running = true
		state.setsToWin = 1
		var bot = ScriptedPlayer.new()
		var idle: Dictionary = Sim.empty_input()
		var prev_hits := 0
		var watching := false       # an AI smash is in the air
		var returned := false
		var glass := false
		var human_hits_after := 0
		var counted_in := false
		for _t in MAX_TICKS:
			if state.result != null:
				break
			var input: Dictionary = bot.decide(state)
			if not bool(state.serving) and not watching:
				input["shotVariant"] = "lob"
				input["charging"] = false
			if watching and hold:
				input["moveY"] = 0.0
				input["up"] = false
				input["down"] = false
			var won_before: Dictionary = state.stats["pointsWon"].duplicate()
			Sim.update_match(state, DT, input, idle)
			var ball = state.ball
			if watching and ball.postGlassSide != null and String(ball.postGlassSide) == "player" and not returned:
				glass = true
			var hits := int(state.rallyHits)
			if hits > prev_hits:
				var side := String(state.lastHitterSide)
				if side == "ai" and Sim.is_smash_shot(ball.shotType) and not watching:
					watching = true
					returned = false
					glass = false
					human_hits_after = 0
					counted_in = false
					m.smashes += 1
					for p in [state.player, state.playerMate]:
						p.y = depth
				elif side == "player" and watching and not returned:
					returned = true
					m.returned += 1
					if glass:
						m.after_glass += 1
					if state.activePlayerKey != "player":
						m.by_mate += 1
				elif side == "ai" and watching and returned and not counted_in:
					counted_in = true
					m.returned_in += 1
			prev_hits = hits
			if int(state.stats["pointsWon"]["player"]) != int(won_before["player"]) or int(state.stats["pointsWon"]["ai"]) != int(won_before["ai"]):
				if watching:
					if int(state.stats["pointsWon"]["player"]) > int(won_before["player"]):
						m.point_won += 1
					elif not returned:
						var reason := String(state.pointMessage)
						m.lost_by[reason] = int(m.lost_by.get(reason, 0)) + 1
				watching = false
				prev_hits = 0
	return m


func _pct(a: int, b: int) -> float:
	return 100.0 * float(a) / maxf(1.0, float(b))


func _report(level: int, spot: String, hold: bool, m: Dictionary) -> void:
	var name := String(Frozen.ai_opponents()[level].get("id", str(level)))
	print("== %-10s da %-5s %-8s smash %3d  risposte %3.0f%% (dopo il vetro %3.0f%% di queste)  rimandate e rigiocate %3.0f%%  punto vinto %3.0f%%  perse per: %s" % [
		name, spot, "fermo" if hold else "insegue", m.smashes, _pct(m.returned, m.smashes),
		_pct(m.after_glass, m.returned), _pct(m.returned_in, m.smashes), _pct(m.point_won, m.smashes), str(m.lost_by)])
	print("METRICS " + JSON.stringify({"level": level, "spot": spot, "hold": hold, "m": m}))
