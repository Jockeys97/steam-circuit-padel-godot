## lineup_audit.gd — the port of `scripts/lineup-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/lineup_audit.gd
##
## Same athletes (picked by the same four `sort` orders), same seeds
## (`state.rngState = seme * 7919`, `424242`), same 240-shot average for the ball
## speed and the same four-shot energy scenario as the reference.
##
## The promises (`scripts/lineup-audit.mjs:22-129`):
##   1. with no choice the partner stays the clone it always was — the behaviour
##      the other audits rest on — while a chosen partner changes width, speed and
##      racket (`conControllo.playerMate.w > conPotenza.playerMate.w`);
##   2. the chosen opponent moves like the chosen athlete, and reach or racket
##      follow the athlete;
##   3. power is measured on the ball, over many seeded shots, with an explicit
##      margin (`> 15%`), because a single shot can be outrun by the error model;
##   4. picking a partner is not a hidden difficulty switch: averaged over every
##      athlete the opponent is worth what it was before (scarto `< 0.5%`), and no
##      `ROSTER_AVERAGE` entry is out of scale (`0.3 .. 3`);
##   5. stamina is a team property: a more resistant partner leaves the team more
##      energy after a fixed number of shots.
##
## Extra check the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## the roster average is read back from `frozen.gd` and asserted against the frozen
## reference values, so the normalisation the lineup ratios divide by cannot drift
## unnoticed.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

const SHOTS := 240
const ENERGY_SHOTS := 4
## `js/data.js` `ROSTER_AVERAGE` at the frozen baseline (commit 2979588).
const REFERENCE_ROSTER_AVERAGE := {
	"speed": 1.0033333333333332, "power": 1.0733333333333335,
	"control": 1.0833333333333333, "reach": 1.0333333333333334,
	"stamina": 1.1066666666666667,
}


func _initialize() -> void:
	var audit := AuditBase.new("lineup")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var athletes: Array = Frozen.athletes()
	var control: Dictionary = _top_by(athletes, "control", true)
	var power: Dictionary = _top_by(athletes, "power", true)
	var fast: Dictionary = _top_by(athletes, "speed", true)
	var slow: Dictionary = _top_by(athletes, "speed", false)

	# --- the partner is no longer a clone -----------------------------------
	var no_choice := match_with({})
	var with_control := match_with({"playerMate": control})
	var with_power := match_with({"playerMate": power})
	audit.check_eq(
		float(no_choice.playerMate.w), float(no_choice.player.w),
		"lineup/empty_lineup_partner_clones_the_player",
	)
	audit.check_true(
		float(with_control.playerMate.w) != float(with_power.playerMate.w),
		"lineup/partner_racket_depends_on_the_chosen_athlete",
	)
	audit.check_gt(
		float(with_control.playerMate.w), float(with_power.playerMate.w),
		"lineup/more_control_is_a_wider_partner_racket",
	)

	var fast_partner := match_with({"playerMate": fast})
	var slow_partner := match_with({"playerMate": slow})
	audit.check_gt(
		float(fast_partner.playerMate.speed), float(slow_partner.playerMate.speed),
		"lineup/partner_speed_comes_from_the_partner",
	)

	# --- the opponents stop being a single look -----------------------------
	var fast_rival := match_with({"opponent": fast})
	var slow_rival := match_with({"opponent": slow})
	audit.check_gt(
		float(fast_rival.opponent.speed), float(slow_rival.opponent.speed),
		"lineup/opponent_moves_like_the_chosen_athlete",
	)
	var power_rival := match_with({"opponent": power})
	var control_rival := match_with({"opponent": control})
	audit.check_true(
		float(power_rival.opponent.reach) != float(control_rival.opponent.reach)
		or float(power_rival.opponent.w) != float(control_rival.opponent.w),
		"lineup/opponent_reach_or_racket_follows_the_athlete",
	)

	# --- power is measured on the ball --------------------------------------
	var power_shot := shot_speed(audit, power)
	var control_shot := shot_speed(audit, control)
	var margin: float = (power_shot - control_shot) / control_shot
	audit.check_gt(margin, 0.15, "lineup/powerful_opponent_hits_perceptibly_harder")

	# --- picking is not a hidden difficulty switch --------------------------
	var reference := match_with({})
	var averages := {"speed": 0.0, "w": 0.0, "reach": 0.0}
	for athlete in athletes:
		var state := match_with({"opponent": athlete})
		averages["speed"] += float(state.opponent.speed) / float(athletes.size())
		averages["w"] += float(state.opponent.w) / float(athletes.size())
		averages["reach"] += float(state.opponent.reach) / float(athletes.size())
	for key in averages:
		var drift: float = absf(float(averages[key]) - float(_opponent_field(reference, key))) / float(_opponent_field(reference, key))
		audit.check_lt(drift, 0.005, "lineup/roster_average_keeps_the_%s_unbiased" % key)

	var roster_average: Dictionary = Frozen.roster_average()
	for key in REFERENCE_ROSTER_AVERAGE:
		audit.check_eq(
			float(roster_average[key]), float(REFERENCE_ROSTER_AVERAGE[key]),
			"lineup/frozen_roster_average_%s_matches_reference" % key,
		)
	for key in roster_average:
		audit.check_between(
			float(roster_average[key]), 0.3, 3.0,
			"lineup/roster_average_%s_is_in_scale" % key,
		)

	# --- stamina is a team property -----------------------------------------
	var resistant: Dictionary = _top_by(athletes, "stamina", true)
	var fragile: Dictionary = _top_by(athletes, "stamina", false)
	var with_resistant := energy_after_rally({"playerMate": resistant})
	var with_fragile := energy_after_rally({"playerMate": fragile})
	audit.check_gt(
		with_resistant, with_fragile,
		"lineup/resistant_partner_leaves_more_team_energy",
	)

	audit.report("racket(control=%.2f power=%.2f) rivalSpeed(fast=%.1f slow=%.1f reference=%.1f) shot(power=%.1f control=%.1f) energy(resistant=%.3f fragile=%.3f)" % [
		with_control.playerMate.w, with_power.playerMate.w,
		fast_rival.opponent.speed, slow_rival.opponent.speed, reference.opponent.speed,
		power_shot, control_shot, with_resistant, with_fragile,
	])
	audit.report("reference racket(controllo=117.33 potenza=111.37) rivalSpeed(veloce=406.5 lento=287.7 riferimento=313.7) shot(potente=428.2 tecnico=335.2) energy(resistente=0.529 fragile=0.440)")


# ---------------------------------------------------------------------------
# `partita` (`scripts/lineup-audit.mjs:18-20`).
# ---------------------------------------------------------------------------

static func match_with(lineup: Dictionary) -> State:
	var by_id := {}
	for athlete in Frozen.athletes():
		by_id[String(athlete["id"])] = athlete
	var options: Dictionary = {"lineup": lineup} if not lineup.is_empty() else {}
	return Sim.create_match_state(
		"quick", by_id["maestro"], Frozen.arenas()[0], Frozen.ai_opponents()[1], 0, options,
	)


static func _opponent_field(state: State, key: String) -> float:
	match key:
		"speed":
			return float(state.opponent.speed)
		"w":
			return float(state.opponent.w)
		"reach":
			return float(state.opponent.reach)
	return 0.0


## `velocitaColpo` (`scripts/lineup-audit.mjs:57-69`).
static func shot_speed(audit: AuditBase, athlete: Dictionary) -> float:
	var total := 0.0
	for seed in range(1, SHOTS + 1):
		var state := match_with({"opponent": athlete})
		Support.inject_seed(state, seed * 7919)
		state.running = true
		state.serving = false
		state.pointPause = 0.0
		state.lastHitterSide = "player"
		state.rallyHits = 3
		state.opponent.x = 480.0
		state.opponent.y = 145.0
		state.opponent.hitCooldown = 0.0
		state.ball.x = 480.0
		state.ball.y = 165.0
		state.ball.z = 60.0
		state.ball.vx = 0.0
		state.ball.vy = -100.0
		state.ball.vz = 0.0
		state.ball.crossedNet = true
		Sim.hit_ball(state, state.opponent, 1.0, false, true, 0.0, false, "drive", 0.0)
		total += Support.ball_speed(state)
	audit.check_gt(total, 0.0, "lineup/opponent_drive_produced_a_speed")
	return total / float(SHOTS)


## `energiaDopoScambio` (`scripts/lineup-audit.mjs:110-123`).
static func energy_after_rally(lineup: Dictionary) -> float:
	var state := match_with(lineup)
	Support.inject_seed(state, 424242)
	state.running = true
	state.serving = false
	state.pointPause = 0.0
	state.lastHitterSide = "ai"
	state.rallyHits = 3
	for shot in range(0, ENERGY_SHOTS):
		state.player.x = 480.0
		state.player.y = 395.0
		state.player.hitCooldown = 0.0
		state.ball.x = 480.0
		state.ball.y = 375.0
		state.ball.z = 60.0
		state.ball.vx = 0.0
		state.ball.vy = 100.0
		state.ball.vz = 0.0
		state.ball.crossedNet = true
		Sim.hit_ball(state, state.player, 1.3, false, true, 0.0, false, "drive", 0.0)
	return float(state.rallyEnergy["player"])


## `[...ATHLETES].sort((a, b) => b.stats[key] - a.stats[key])[0]` and its inverse.
static func _top_by(athletes: Array, key: String, highest: bool) -> Dictionary:
	var best: Dictionary = athletes[0]
	for athlete in athletes:
		var value := float(athlete["stats"][key])
		var best_value := float(best["stats"][key])
		if (highest and value > best_value) or (not highest and value < best_value):
			best = athlete
	return best
