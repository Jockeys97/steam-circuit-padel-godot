## ai_contact_decision_test.gd — gameplay fluidity, the AI's contact CHOICE.
##
## The port half of the pair. The JavaScript twin is
## `docs/agent-work/gameplay-fluidity/tools/ai-contact-census.mjs`, which runs the
## same five seeds with the same scripted input and prints the same `CENSUS`
## fields, so the two engines can be compared line for line.
##
## It goes red if: the AI volleys a ball no defender is set up for, never lets a
## reachable ball bounce, returns a serve it never let land, loses a point to a
## second bounce while holding a deferral, or abandons a deferral it made.
##
## Run (verified invocation):
##   /opt/homebrew/bin/godot --headless --path godot/ \
##     --script res://tests/fluidity/ai_contact_decision_test.gd
extends SceneTree

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

## `FIXED_STEP = 1 / 120` (`js/main.js:1164`), the step the frozen harness uses.
const FIXED_STEP := 1.0 / 120.0
const SWING_EVERY := 30
const CHARGE_FROM_TICK := 60
const CENSUS_SEEDS := [12345, 999, 2024, 424242, 7]
const CENSUS_TICKS := 12000

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_unit_cases()
	_scenarios()
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(1)


func check(condition: bool, name: String) -> void:
	_checks += 1
	if condition:
		print("ok %s" % name)
	else:
		_failures += 1
		printerr("FAIL %s" % name)


func check_eq(actual: Variant, expected: Variant, name: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [name, str(expected), str(actual)])


func check_close(actual: float, expected: float, tolerance: float, name: String) -> void:
	check(absf(actual - expected) <= tolerance,
		"%s (expected %.4f +- %.4f, got %.4f)" % [name, expected, tolerance, actual])


# ---------------------------------------------------------------------------
# Unit cases: the plan on a hand-built state, so the choice is inspected directly
# instead of through whatever a rally happens to do.
# ---------------------------------------------------------------------------

func _state() -> State:
	var athletes: Array = Frozen.athletes()
	var state: State = Sim.create_match_state(
		"quick", athletes[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.running = true
	state.serving = false
	state.ball.served = true
	state.ball.serveInFlight = false
	state.ball.shotType = "drive"
	state.ball.crossedNet = true
	state.rallyHits = 2
	state.lastHitterSide = "player"
	state.aiReceiverLocked = true
	state.aiPrimaryKey = "opponent"
	state.aiReactionDelay = 0.0
	state.aiDeferTimer = 0.0
	state.opponent.x = 480.0
	state.opponent.y = 190.0
	state.opponentMate.x = 480.0
	state.opponentMate.y = 260.0
	return state


func _put_ball(state: State, x: float, y: float, z: float, vx: float, vy: float, vz: float,
		bounces_ai: int = 0) -> void:
	var ball = state.ball
	ball.x = x
	ball.y = y
	ball.z = z
	ball.vx = vx
	ball.vy = vy
	ball.vz = vz
	ball.bounces = {"player": 1, "ai": bounces_ai}
	ball.postGlassSide = null
	ball.netFaultOwner = null
	ball.serveInFlight = false


func _unit_cases() -> void:
	# A ball that is not coming at the AI at all is not a decision.
	var away := _state()
	_put_ball(away, 480.0, 420.0, 40.0, 0.0, 90.0, -20.0)
	check_eq(String(Sim.ai_contact_plan(away, away.opponent, away.ball)["action"]), "none",
		"a ball travelling away is not playable")

	# A serve in flight is no-contact by rule: the receiver may not volley it.
	var serve := _state()
	_put_ball(serve, 480.0, 240.0, 60.0, 0.0, -120.0, 10.0)
	serve.ball.serveInFlight = true
	check_eq(String(Sim.ai_contact_plan(serve, serve.opponent, serve.ball)["action"]), "none",
		"a serve in flight is not a volley the AI may take")

	# A set-up ball at the paddle's own centre is a volley.
	var set_up := _state()
	_put_ball(set_up, 480.0, 230.0, 55.0, 0.0, -100.0, -20.0)
	var set_up_plan: Dictionary = Sim.ai_contact_plan(set_up, set_up.opponent, set_up.ball)
	check_eq(String(set_up_plan["action"]), "volley", "a set-up ball is volleyed")
	check_close(Sim.ai_contact_comfort(set_up.opponent, set_up.ball), 1.0, 0.001,
		"a set-up ball is fully comfortable")

	# A ball at the edge of the racket is not: no defender volleys that and calls
	# it a plan. It still has to bounce somewhere the AI can play it.
	var stretched := _state()
	_put_ball(stretched, 560.0, 200.0, 120.0, 0.0, -120.0, -60.0)
	var stretched_plan: Dictionary = Sim.ai_contact_plan(stretched, stretched.opponent, stretched.ball)
	check(Sim.ai_contact_comfort(stretched.opponent, stretched.ball) < 0.4,
		"a ball at the fingertips is not a comfortable contact")
	check_eq(String(stretched_plan["action"]), "defer", "a stretched ball is left to bounce")
	check(bool(stretched_plan["afterBounce"]), "the deferred contact comes after a bounce")
	check(float(stretched_plan["time"]) > 0.2, "the deferred contact is in the future")
	check_close(float(stretched_plan["contactX"]), 560.0, 1.0,
		"the deferred contact keeps the ball's line")
	var deferred: Dictionary = Sim.ai_deferred_contact(stretched, stretched.opponent, stretched.ball)
	check(bool(deferred["valid"]), "the deferred prediction is valid")
	check(float(deferred["contactZ"]) <= 74.0 and float(deferred["contactZ"]) >= 34.0,
		"the deferred contact sits inside the strike window (got %.2f)" % float(deferred["contactZ"]))

	# A reachable ball with nothing to wait for is the emergency strike, not a pass.
	var emergency := _state()
	_put_ball(emergency, 540.0, 200.0, 40.0, 40.0, -40.0, -220.0, 1)
	emergency.ball.postGlassSide = "ai"
	var emergency_plan: Dictionary = Sim.ai_contact_plan(emergency, emergency.opponent, emergency.ball)
	check_eq(String(emergency_plan["action"]), "emergency",
		"a reachable ball with no bounce to wait for is an emergency strike")

	# A ball that has already bounced and is coming back off the glass is a
	# recovery, and the prediction has to say so.
	var glass := _state()
	glassy(glass)
	var glass_plan: Dictionary = Sim.ai_contact_plan(glass, glass.opponent, glass.ball)
	check(String(glass_plan["action"]) in ["volley", "defer", "emergency"],
		"a ball back off the glass is playable (got %s)" % String(glass_plan["action"]))
	check(Sim.can_hit(glass.opponent, glass.ball), "the glass recovery is inside the racket reach")

	# The commitment: once the AI has declined the volley it holds the decision,
	# and it releases it the moment the ball has bounced.
	var committed := _state()
	_put_ball(committed, 480.0, 230.0, 55.0, 0.0, -100.0, -20.0)
	committed.aiDeferTimer = 0.5
	check_eq(String(Sim.ai_contact_plan(committed, committed.opponent, committed.ball)["action"]), "defer",
		"a committed deferral is held through a volleyable moment")
	committed.ball.bounces = {"player": 1, "ai": 1}
	check_eq(String(Sim.ai_contact_plan(committed, committed.opponent, committed.ball)["action"]), "volley",
		"the commitment releases once the ball has bounced")


## Deep ball coming back off the AI's own glass: bounced once, on the AI's side,
## travelling back towards the net.
func glassy(state: State) -> void:
	_put_ball(state, 470.0, 70.0, 45.0, 20.0, 210.0, 10.0, 1)
	state.ball.postGlassSide = "ai"
	state.ball.shotType = "x3-recovered"


# ---------------------------------------------------------------------------
# Scenarios: the same five seeds and the same scripted input as the JavaScript
# census, so the two engines can be compared line for line.
# ---------------------------------------------------------------------------

func _scenarios() -> void:
	var contacts := 0
	var volleys := 0
	var bounced := 0
	var serve_returns := 0
	var serve_returns_before_bounce := 0
	var defer_ticks := 0
	var deferral_failures := 0
	var unresolved_deferrals := 0
	var double_bounce_losses := 0
	for seed in CENSUS_SEEDS:
		var athletes: Array = Frozen.athletes()
		var state: State = Sim.create_match_state(
			"quick", athletes[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
		state.rng_state = int(seed)
		state.rng_calls = 0
		state.running = true
		var seed_contacts := 0
		var seed_volleys := 0
		var seed_bounced := 0
		var seed_serve_returns := 0
		var episode := false
		var episode_contact := false
		var episode_bounce := false
		var episode_scored := false
		for tick in range(0, CENSUS_TICKS):
			var hits_at_entry: int = state.rallyHits
			var bounces_at_entry: int = int(state.ball.bounces["ai"])
			var events_before: int = state.events.size()
			var timer_before: float = state.aiDeferTimer
			Sim.update_match(state, FIXED_STEP, _script_input(tick), null)
			var events_after: int = state.events.size()
			var scored := false
			for index in range(events_before, events_after):
				if String(state.events[index]) == "msgDoubleBounce":
					double_bounce_losses += 1
					if timer_before > 0.0:
						deferral_failures += 1
			if state.events.size() < events_before:
				scored = true
			else:
				scored = state.pointMessage != ""
			var landed_this_tick: int = 1 if int(state.ball.bounces["ai"]) > bounces_at_entry else 0
			var gained: int = state.rallyHits - hits_at_entry
			var ai_hit: bool = gained > 0 and String(state.lastHitterSide) == "ai"
			if ai_hit:
				var landed: int = bounces_at_entry \
					+ (1 if state.ball.bouncePulse >= 0.999 and landed_this_tick == 0 else 0)
				seed_contacts += gained
				if landed > 0:
					seed_bounced += gained
				else:
					seed_volleys += gained
				if hits_at_entry == 0:
					seed_serve_returns += gained
					if landed == 0:
						serve_returns_before_bounce += gained
				if episode:
					episode_contact = true
			if episode and landed_this_tick > 0:
				episode_bounce = true
			if episode and scored:
				episode_scored = true
			if state.aiDeferTimer > 0.0:
				if not episode:
					episode = true
					episode_contact = false
					episode_bounce = false
					episode_scored = false
				defer_ticks += 1
			elif episode:
				episode = false
				if not episode_contact and not episode_bounce and not episode_scored:
					unresolved_deferrals += 1
			if state.result != null:
				break
		contacts += seed_contacts
		volleys += seed_volleys
		bounced += seed_bounced
		serve_returns += seed_serve_returns
		print("CENSUS {\"seed\":%d,\"aiContacts\":%d,\"aiVolleys\":%d,\"aiBounced\":%d,\"aiServeReturns\":%d}" % [
			int(seed), seed_contacts, seed_volleys, seed_bounced, seed_serve_returns])
	print("CENSUS-TOTALS aiContacts=%d aiVolleys=%d aiBounced=%d aiServeReturns=%d deferTicks=%d doubleBounceAgainstAi=%d deferralDoubleBounce=%d unresolved=%d" % [
		contacts, volleys, bounced, serve_returns, defer_ticks, double_bounce_losses,
		deferral_failures, unresolved_deferrals])
	check(contacts > 0, "the AI plays the ball in the seeded scenarios")
	check(bounced > 0, "the AI lets a reachable ball bounce at least once")
	check(serve_returns > 0, "the AI returns serves it let land")
	check_eq(serve_returns_before_bounce, 0, "no serve is returned before it bounces")
	check_eq(deferral_failures, 0,
		"no point is lost to a second bounce while the AI is holding a deferral")
	check_eq(unresolved_deferrals, 0, "no deferral is abandoned after it was made")


func _script_input(tick: int) -> Dictionary:
	var input: Dictionary = Sim.empty_input()
	if tick < CHARGE_FROM_TICK:
		return input
	input["charging"] = true
	input["hit"] = tick % SWING_EVERY == 0
	input["moveX"] = float(((int(floor(tick / 120.0)) % 3) - 1)) * 0.5
	input["moveY"] = -1.0 if tick % 240 < 120 else 0.0
	return input
