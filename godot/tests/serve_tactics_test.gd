extends SceneTree
## Focused serve contract: pad aim, a forgiving bounce-timing bonus, second-serve
## safety, and the existing slice's different rebound. No visual driver needed.

const Sim = preload("res://src/sim/sim.gd")
const Frozen = preload("res://src/sim/frozen.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func fresh(court_side: String = "right"):
	var state = Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[0])
	state.serveCourt = court_side
	Sim.prepare_serve(state)
	state.running = true
	state.rng_state = 1234567
	return state


func run() -> void:
	var right = fresh()
	var centre: float = Sim.serve_target_x(right)
	var glass: float = Sim.serve_aim_x(right, -1.0)
	var tee: float = Sim.serve_aim_x(right, 1.0)
	check(glass < centre and centre < tee and tee < 480.0, "right box: glass, body, T")
	check(Sim.serve_aim_x(right, 1.0, true) < tee, "second serve pulls T aim inward")
	check(Sim.serve_aim_x(right, -1.0, true) > glass, "second serve pulls glass aim inward")
	var left = fresh("left")
	check(480.0 < Sim.serve_aim_x(left, -1.0) and Sim.serve_aim_x(left, -1.0) < Sim.serve_target_x(left), "left box aims toward T")
	check(Sim.serve_aim_x(left, 1.0) > Sim.serve_target_x(left), "left box aims toward glass")

	var neutral = fresh()
	var aimed = fresh()
	Sim.perform_serve(neutral, 0.65)
	Sim.perform_serve(aimed, 0.65, false, 1.0, -1.0)
	check(aimed.ball.serveTargetX > neutral.ball.serveTargetX + 80.0, "right aim changes actual landing X")
	check(aimed.ball.serveTargetY < neutral.ball.serveTargetY - 20.0, "up aim makes the serve deeper")
	aimed.ball.x = aimed.ball.serveTargetX
	aimed.ball.y = aimed.ball.serveTargetY
	check(Sim.valid_service_bounce(aimed, "ai"), "aimed serve still targets diagonal box")

	var ideal_clock: float = Sim.SERVE_BOUNCE_PERIOD * Sim.SERVE_TIMING_PEAK
	check(Sim.serve_bounce_quality(ideal_clock) > 0.99, "rising bounce has ideal timing")
	check(Sim.serve_bounce_quality(0.0) == 0.0, "off-beat timing has no bonus, not a fault")
	var untimed = fresh()
	var timed = fresh()
	Sim.perform_serve(untimed, 0.8)
	Sim.perform_serve(timed, 0.8, false, 0.0, 0.0, 1.0)
	check(absf(timed.ball.serveTargetX - Sim.serve_target_x(timed)) < absf(untimed.ball.serveTargetX - Sim.serve_target_x(untimed)), "clean timing reduces dispersion")

	var live = fresh()
	live.serveBounceTime = ideal_clock
	var input: Dictionary = Sim.empty_input()
	input["charging"] = true
	input["analogAim"] = true
	input["aim"] = 1.0
	input["aimY"] = -1.0
	Sim.update_match(live, 1.0 / 120.0, input)
	check(live.serveTimingBonus > 0.99, "charge start captures displayed bounce phase")
	input["charging"] = false
	input["hit"] = true
	Sim.update_match(live, 1.0 / 120.0, input)
	check(not live.serving and live.ball.serveInFlight, "release fires the serve")
	check(live.ball.serveTargetX > Sim.serve_target_x(live) + 80.0, "real input path uses stick aim")
	Sim.prepare_serve(live)
	check(live.serveBounceTime == 0.0 and live.serveTimingBonus == 0.0, "next serve resets timing")

	var flat = fresh()
	var sliced = fresh()
	Sim.perform_serve(flat, 0.6)
	Sim.perform_serve(sliced, 0.6, true)
	for state in [flat, sliced]:
		state.ball.x = state.ball.serveTargetX
		state.ball.y = state.ball.serveTargetY
		state.ball.z = 0.0
		Sim.handle_ground_bounce(state, -300.0, 0.0)
	check(sliced.ball.backspin > flat.ball.backspin, "slice has backspin")
	check(absf(sliced.ball.vy) < absf(flat.ball.vy), "slice slows after the first bounce")

	var faults = fresh()
	Sim.serve_fault(faults, "serveOutBox")
	check(faults.serveAttempts == 1 and faults.serving, "first fault keeps the second serve")
	Sim.serve_fault(faults, "serveOutBox")
	check(int(faults.stats["doubleFaults"]["player"]) == 1, "second fault still awards the double fault")

	var pvp = fresh()
	pvp.humanMode = "pvp"
	pvp.pvp = true
	pvp.serveSide = "ai"
	Sim.prepare_serve(pvp)
	var second: Dictionary = Sim.empty_input()
	second["charging"] = true
	second["analogAim"] = true
	second["aim"] = -1.0
	Sim.update_serving(pvp, 1.0 / 120.0, Sim.empty_input(), second)
	second["charging"] = false
	second["hit"] = true
	Sim.update_serving(pvp, 1.0 / 120.0, Sim.empty_input(), second)
	check(pvp.ball.serveTargetX < Sim.serve_target_x(pvp) - 60.0, "PVP second player aim reaches the serve")

	print("%s serve tactics: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
