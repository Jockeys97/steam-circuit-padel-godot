extends SceneTree
## scratch diagnostic: prints the AI contact plan per action change for one seeded
## scenario. Not part of the deliverable; deleted before handoff.
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var athletes: Array = Frozen.athletes()
	var state: State = Sim.create_match_state(
		"quick", athletes[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.rng_state = 12345
	state.running = true
	var last := ""
	var hist := {}
	var inbound := {}
	var inbound_log := 0
	for tick in range(0, 4000):
		var paddle = state.paddle(state.aiPrimaryKey)
		var plan: Dictionary = Sim.ai_contact_plan(state, paddle, state.ball)
		var action := String(plan["action"])
		hist[action] = int(hist.get(action, 0)) + 1
		if int(state.ball.bounces["ai"]) == 0 \
				and Sim.ball_playable_direction("ai", state.ball) \
				and not state.ball.serveInFlight \
				and tick >= 370 and tick <= 500:
			var fc: Dictionary = Sim.ai_volley_contact(state, paddle, state.ball)
			var pz: Dictionary = plan
			if inbound_log < 60:
				inbound_log += 1
				print("IN %5d %-9s %-14s comfort=%.3f live=%.3f ready=%s now=%s defer=%s fcastReach=%s fcastZ=%6.1f late=%.3f ballY=%7.1f z=%6.1f vz=%7.1f vy=%7.1f pY=%6.1f pX=%6.1f bX=%6.1f bAI=%d" % [
					tick, String(pz["action"]), String(pz["reason"]), float(pz["comfort"]),
					Sim.ai_live_comfort(paddle, state.ball),
					str(state.aiReactionDelay <= 0.0), str(Sim.can_hit(paddle, state.ball)),
					str(Sim.ai_deferred_contact(state, paddle, state.ball)["valid"]),
					str(fc["valid"]), float(fc["contactZ"]), float(fc["lateBy"]),
					state.ball.y, state.ball.z, state.ball.vz, state.ball.vy, paddle.y, paddle.x,
					state.ball.x, int(state.ball.bounces["ai"])])
		if action != last and state.ball.y < float(Frozen.court()["netY"]):
			print("tick %5d %-9s %-14s comfort=%.2f live=%.2f deferValid=%s now=%s ballY=%7.1f z=%6.1f pY=%6.1f pX=%6.1f ballX=%6.1f bAI=%d" % [
				tick, action, String(plan["reason"]), float(plan["comfort"]),
				Sim.ai_live_comfort(paddle, state.ball),
				str(Sim.ai_deferred_contact(state, paddle, state.ball)["valid"]),
				str(Sim.can_hit(paddle, state.ball)), state.ball.y, state.ball.z,
				paddle.y, paddle.x, state.ball.x, int(state.ball.bounces["ai"])])
			last = action
		Sim.update_match(state, 1.0 / 120.0, _input(tick), null)
		if state.result != null:
			break
	print("HIST ", hist)
	quit(0)


func _input(tick: int) -> Dictionary:
	var input: Dictionary = Sim.empty_input()
	if tick < 60:
		return input
	input["charging"] = true
	input["hit"] = tick % 30 == 0
	input["moveX"] = float(((int(floor(tick / 120.0)) % 3) - 1)) * 0.5
	input["moveY"] = -1.0 if tick % 240 < 120 else 0.0
	return input
