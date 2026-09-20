extends SceneTree
## scratch: before/after on focused contact scenarios (baseline sim vs new sim).
const New := preload("res://src/sim/sim.gd")
const Old := preload("res://tests/fluidity/_baseline_sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

const DT := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("run")


func _base(ai_x: float, ai_y: float) -> State:
	var athletes: Array = Frozen.athletes()
	var state: State = New.create_match_state(
		"quick", athletes[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.rng_state = 20260920
	state.running = true
	state.serving = false
	state.ball.served = true
	state.ball.serveInFlight = false
	state.ball.shotType = "drive"
	state.ball.crossedNet = true
	state.rallyHits = 2
	state.lastHitterSide = "player"
	state.opponent.x = ai_x
	state.opponent.y = ai_y
	state.opponentMate.x = ai_x + 120.0
	state.opponentMate.y = ai_y - 10.0
	state.player.x = 480.0
	state.player.y = 500.0
	state.playerMate.x = 300.0
	state.playerMate.y = 400.0
	return state


func _ball(state: State, x: float, y: float, z: float, vx: float, vy: float, vz: float) -> void:
	state.ball.x = x
	state.ball.y = y
	state.ball.z = z
	state.ball.vx = vx
	state.ball.vy = vy
	state.ball.vz = vz
	state.ball.bounces = {"player": 0, "ai": 0}


func _run(sim, state: State, ticks: int) -> Dictionary:
	var contacts := 0
	var volleys := 0
	var bounced := 0
	var contact_tick := -1
	var contact_z := 0.0
	var contact_y := 0.0
	var defer_ticks := 0
	sim.lock_ai_receiver_for_incoming_shot(state)
	for tick in range(0, ticks):
		var hits_at_entry: int = state.rallyHits
		var bounces_at_entry: int = int(state.ball.bounces["ai"])
		var z_at_entry: float = state.ball.z
		var y_at_entry: float = state.ball.y
		sim.update_match(state, DT, sim.empty_input(), null)
		if float(state.aiDeferTimer) > 0.0:
			defer_ticks += 1
		if state.rallyHits > hits_at_entry and str(state.lastHitterSide) == "ai":
			contacts += 1
			var landed: int = bounces_at_entry + (1 if state.ball.bouncePulse >= 0.999 else 0)
			if landed > 0:
				bounced += 1
			else:
				volleys += 1
			if contact_tick < 0:
				contact_tick = tick
				contact_z = z_at_entry
				contact_y = y_at_entry
		if state.result != null:
			break
	return {
		"contacts": contacts, "volleys": volleys, "bounced": bounced,
		"tick": contact_tick, "z": contact_z, "y": contact_y, "defer": defer_ticks,
		"points": "%d-%d" % [int(state.points["player"]), int(state.points["ai"])],
		"result": "-" if state.result == null else str(state.result),
	}


func _case(entry: Array) -> State:
	var state := _base(float(entry[1]), float(entry[2]))
	_ball(state, float(entry[3]), float(entry[4]), float(entry[5]),
		float(entry[6]), float(entry[7]), float(entry[8]))
	return state


func run() -> void:
	var cases := [
		["net-volley", 480.0, 240.0, 480.0, 330.0, 80.0, 0.0, -150.0, -20.0],
		["deep-stretch-a", 480.0, 206.0, 480.0, 300.0, 120.0, 0.0, -260.0, 60.0],
		["deep-stretch-b", 480.0, 190.0, 430.0, 330.0, 150.0, 40.0, -210.0, -40.0],
		["deep-stretch-c", 480.0, 240.0, 480.0, 340.0, 140.0, 0.0, -200.0, 20.0],
		["deep-stretch-d", 480.0, 230.0, 520.0, 350.0, 170.0, -60.0, -230.0, -60.0],
		["deep-lob-e", 480.0, 220.0, 400.0, 330.0, 200.0, 80.0, -180.0, -30.0],
		["high-arrival-f", 480.0, 240.0, 480.0, 340.0, 120.0, 0.0, -200.0, 130.0],
		["high-arrival-g", 480.0, 230.0, 480.0, 350.0, 140.0, 0.0, -220.0, 150.0],
		["high-arrival-h", 480.0, 240.0, 520.0, 330.0, 100.0, -40.0, -180.0, 110.0],
		["deep-late-i", 480.0, 250.0, 480.0, 360.0, 160.0, 0.0, -240.0, 40.0],
		["fast-stretch-j", 480.0, 250.0, 480.0, 360.0, 110.0, 0.0, -420.0, 36.0],
		["fast-stretch-k", 480.0, 250.0, 480.0, 380.0, 130.0, 0.0, -460.0, 60.0],
		["fast-control-l", 480.0, 250.0, 480.0, 360.0, 90.0, 0.0, -420.0, -40.0],
		["fast-stretch-m", 560.0, 250.0, 620.0, 380.0, 120.0, -60.0, -400.0, 40.0],
	]
	var trace := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--trace="):
			trace = String(arg).substr(8)
	for entry in cases:
		var name := String(entry[0])
		var out_old := _run(Old, _case(entry), 600)
		var out_new := _run(New, _case(entry), 600)
		if trace == name:
			_trace(New, _case(entry), 220)
		print("%-14s OLD c=%d v=%d b=%d tick=%d z=%6.1f y=%6.1f pts=%s | NEW c=%d v=%d b=%d tick=%d z=%6.1f y=%6.1f defer=%d pts=%s" % [
			name, out_old["contacts"], out_old["volleys"], out_old["bounced"], out_old["tick"],
			out_old["z"], out_old["y"], out_old["points"],
			out_new["contacts"], out_new["volleys"], out_new["bounced"], out_new["tick"],
			out_new["z"], out_new["y"], out_new["defer"], out_new["points"]])
	quit(0)


func _trace(sim, state: State, ticks: int) -> void:
	sim.lock_ai_receiver_for_incoming_shot(state)
	var last_action := ""
	for tick in range(0, ticks):
		var paddle = state.paddle(state.aiPrimaryKey)
		var plan: Dictionary = sim.ai_contact_plan(state, paddle, state.ball)
		var action := String(plan["action"])
		if action != last_action or tick % 20 == 0:
			print("   TRACE %4d %-9s %-14s ballY=%6.1f z=%6.1f vy=%7.1f vz=%7.1f pY=%6.1f pX=%6.1f timer=%.2f bAI=%d msg=%s" % [
				tick, action, String(plan["reason"]), state.ball.y, state.ball.z, state.ball.vy, state.ball.vz,
				paddle.y, paddle.x, state.aiDeferTimer, int(state.ball.bounces["ai"]), str(state.pointMessage)])
			last_action = action
		sim.update_match(state, DT, sim.empty_input(), null)
		if state.result != null:
			print("   TRACE result at %d: %s" % [tick, str(state.result)])
			break
