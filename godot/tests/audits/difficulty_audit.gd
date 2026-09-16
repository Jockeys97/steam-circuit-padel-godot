## difficulty_audit.gd — the port of `scripts/difficulty-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/difficulty_audit.gd
##
## (The reference's own sample budget — 240 seeds x 4 tiers x (two smashes + one
## serve return) plus 1000 AI-error draws per tier — needs a bound above the 180 s
## the small audits run in. The sample counts are the reference's and are NOT
## reduced here.)
##
## Same seeds (`seededRandom(seed + aiIndex * 1000)`, `+ aiIndex * 2000`,
## `+ aiIndex * 3000`, `seededRandom(seed + aiIndex * 10000)`), same 240/1000
## counts and the same `1/240` dt as `scripts/difficulty-audit.mjs`.
##
## The promises (`scripts/difficulty-audit.mjs:134-181`):
##   1. against the hardest tier an X3 closes at most a third of the points
##      (`x3PlayerWinnerRate <= 0.35`) — mastering the strongest shot must not be
##      enough to beat the top difficulty;
##   2. the spread between the first and the last step is at least 0.45;
##   3. skill, effective speed, reaction time, aim error, long-rally error and the
##      X2/X3 defence all move monotonically as the tiers rise;
##   4. every tier returns at least 90% of valid serves.
##
## Extra check the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## the four tiers and the `reactionSkill` override are read from `frozen.gd`, and
## `reactionSkill` is asserted at 0.78 for the Leggenda — the value
## `js/data.js:678-684` pins on purpose (above it the AI intercepts the smash
## before the glass and cancels the x2).
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

const DT := 1.0 / 240.0
const REPLY_FRAMES := 2600
const SAMPLES := 240
const ERROR_SAMPLES := 1000
const X3_HARD_LIMIT := 0.35
const X3_SPREAD_MIN := 0.45
const SERVE_RETURN_MIN := 0.9
const X2_SATURATION := 0.05
## `js/data.js:678-684` — the Leggenda's pinned reaction skill.
const LEGGENDA_REACTION_SKILL := 0.78


func _initialize() -> void:
	var audit := AuditBase.new("difficulty")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var profiles: Array = Frozen.ai_opponents()
	_frozen_tiers(audit, profiles)

	var report: Array = []
	for ai_index in range(0, profiles.size()):
		var profile: Dictionary = profiles[ai_index]
		var x2_winners := 0
		var x3_winners := 0
		var serves_returned := 0
		for seed in range(1, SAMPLES + 1):
			if bool(player_smash(ai_index, 0.0, seed + ai_index * 1000)["winner"]):
				x2_winners += 1
			if bool(player_smash(ai_index, 0.8, seed + ai_index * 2000)["winner"]):
				x3_winners += 1
			if serve_returned(ai_index, 0.82, seed + ai_index * 3000):
				serves_returned += 1
		var reaction_skill: float = float(profile["skill"])
		if profile.has("reactionSkill") and profile["reactionSkill"] != null:
			reaction_skill = float(profile["reactionSkill"])
		report.append({
			"id": String(profile["id"]),
			"skill": float(profile["skill"]),
			"effectiveSpeed": _round_to(ai_speed(profile), 1),
			"baseReactionMs": Sim.js_round((0.28 - reaction_skill * 0.25) * 1000.0),
			"aimErrorPx": _round_to((1.0 - float(profile["skill"])) * 44.0, 1),
			"longRallyErrorRate": _round_to(ai_error_rate(ai_index), 3),
			"serveReturnRate": _round_to(float(serves_returned) / float(SAMPLES), 3),
			"x2PlayerWinnerRate": _round_to(float(x2_winners) / float(SAMPLES), 3),
			"x3PlayerWinnerRate": _round_to(float(x3_winners) / float(SAMPLES), 3),
		})
		audit.report("tier %s skill=%.2f speed=%.1f reactionMs=%d aimErr=%.1f rallyErr=%.3f serveReturn=%.3f x2Win=%.3f x3Win=%.3f" % [
			report[report.size() - 1]["id"], report[report.size() - 1]["skill"],
			report[report.size() - 1]["effectiveSpeed"], int(report[report.size() - 1]["baseReactionMs"]),
			report[report.size() - 1]["aimErrorPx"], report[report.size() - 1]["longRallyErrorRate"],
			report[report.size() - 1]["serveReturnRate"], report[report.size() - 1]["x2PlayerWinnerRate"],
			report[report.size() - 1]["x3PlayerWinnerRate"],
		])

	# --- the two constraints the audit exists for ---------------------------
	var easiest: Dictionary = report[0]
	var hardest: Dictionary = report[report.size() - 1]
	var spread: float = float(easiest["x3PlayerWinnerRate"]) - float(hardest["x3PlayerWinnerRate"])
	audit.check_le(float(hardest["x3PlayerWinnerRate"]), X3_HARD_LIMIT, "difficulty/hardest_tier_caps_the_x3_winner_rate")
	audit.check_ge(spread, X3_SPREAD_MIN, "difficulty/x3_spread_between_first_and_last_tier")

	# --- monotonicity per adjacent pair -------------------------------------
	for index in range(1, report.size()):
		var easier: Dictionary = report[index - 1]
		var harder: Dictionary = report[index]
		audit.check_gt(float(harder["skill"]), float(easier["skill"]), "difficulty/%s_skill_rises" % harder["id"])
		audit.check_gt(
			float(harder["effectiveSpeed"]), float(easier["effectiveSpeed"]),
			"difficulty/%s_effective_speed_rises" % harder["id"],
		)
		audit.check_le(
			float(harder["baseReactionMs"]), float(easier["baseReactionMs"]),
			"difficulty/%s_reaction_time_does_not_worsen" % harder["id"],
		)
		audit.check_lt(
			float(harder["aimErrorPx"]), float(easier["aimErrorPx"]),
			"difficulty/%s_aim_error_falls" % harder["id"],
		)
		audit.check_lt(
			float(harder["longRallyErrorRate"]), float(easier["longRallyErrorRate"]),
			"difficulty/%s_long_rally_errors_fall" % harder["id"],
		)
		# Below 5% the X2 defence is saturated and the metric is sampling noise
		# (300 draws, +/- 1.4 points): there, not getting worse is the assertion.
		var saturated: bool = (
			float(harder["x2PlayerWinnerRate"]) < X2_SATURATION
			and float(easier["x2PlayerWinnerRate"]) < X2_SATURATION
		)
		audit.check_true(
			saturated or float(harder["x2PlayerWinnerRate"]) <= float(easier["x2PlayerWinnerRate"]),
			"difficulty/%s_x2_defence_improves" % harder["id"],
		)
		# The X3 decides the points, so here "does not get worse" is not enough.
		audit.check_le(
			float(harder["x3PlayerWinnerRate"]), float(easier["x3PlayerWinnerRate"]),
			"difficulty/%s_x3_defence_does_not_worsen" % harder["id"],
		)

	for entry in report:
		audit.check_ge(float(entry["serveReturnRate"]), SERVE_RETURN_MIN, "difficulty/%s_returns_valid_serves" % entry["id"])


# ---------------------------------------------------------------------------
# `createRallyState` (`scripts/difficulty-audit.mjs:33-67`) — the same rally bench
# the shot-balance audit builds (identical paddles, ball and cleared serve keys).
# ---------------------------------------------------------------------------

static func rally_state(ai_index: int) -> State:
	var state: State = Support.rally_state(Frozen.athletes()[0], Frozen.ai_opponents()[ai_index])
	state.player.x = 480.0
	state.player.y = 395.0
	state.player.controlled = true
	state.player.isPlayer = true
	state.player.hitCooldown = 0.0
	state.playerMate.x = 700.0
	state.playerMate.y = 405.0
	state.playerMate.hitCooldown = 0.0
	state.opponent.x = 330.0
	state.opponent.y = 145.0
	state.opponent.hitCooldown = 0.0
	state.opponentMate.x = 650.0
	state.opponentMate.y = 210.0
	state.opponentMate.hitCooldown = 0.0
	state.ball.x = 480.0
	state.ball.y = 375.0
	state.ball.z = 70.0
	state.ball.vx = 0.0
	state.ball.vy = 100.0
	state.ball.vz = 0.0
	state.ball.bounces = {"player": 0, "ai": 0}
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null
	state.ball.crossedNet = true
	return state


# ---------------------------------------------------------------------------
# `simulatePlayerSmash` (`scripts/difficulty-audit.mjs:69-81`).
# ---------------------------------------------------------------------------

static func player_smash(ai_index: int, aim: float, seed: int) -> Dictionary:
	var state: State = rally_state(ai_index)
	Support.inject_seed(state, Support.seeded_rng_state(seed))
	Sim.hit_ball(state, state.player, 1.35, false, true, aim, false, "smash", -1.0)
	for frame in range(0, REPLY_FRAMES):
		Sim.update_match(state, DT, Support.vuoto())
		if (
			state.rallyHits >= 5
			or int(state.stats["pointsWon"]["player"]) != 0
			or int(state.stats["pointsWon"]["ai"]) != 0
		):
			break
	return {
		"returned": state.rallyHits >= 5,
		"winner": int(state.stats["pointsWon"]["player"]) > 0,
	}


# ---------------------------------------------------------------------------
# `simulateServeReturn` (`scripts/difficulty-audit.mjs:83-93`).
# ---------------------------------------------------------------------------

static func serve_returned(ai_index: int, charge: float, seed: int) -> bool:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[ai_index],
	)
	Support.inject_seed(state, Support.seeded_rng_state(seed))
	state.running = true
	Sim.perform_serve(state, charge, false)
	for frame in range(0, REPLY_FRAMES):
		Sim.update_match(state, DT, Support.vuoto())
		if (
			state.rallyHits >= 1
			or int(state.stats["pointsWon"]["player"]) != 0
			or int(state.stats["pointsWon"]["ai"]) != 0
		):
			break
	return state.rallyHits >= 1


# ---------------------------------------------------------------------------
# `sampleAiErrors` (`scripts/difficulty-audit.mjs:95-107`).
# ---------------------------------------------------------------------------

static func ai_error_rate(ai_index: int) -> float:
	var errors := 0
	for seed in range(1, ERROR_SAMPLES + 1):
		var state: State = rally_state(ai_index)
		Support.inject_seed(state, Support.seeded_rng_state(seed + ai_index * 10000))
		state.rallyHits = 12
		state.opponent.x = 480.0
		state.opponent.y = 230.0
		state.opponent.hitCooldown = 0.0
		state.ball.x = 480.0
		state.ball.y = 250.0
		state.ball.z = 70.0
		state.ball.vy = -80.0
		Sim.hit_ball(state, state.opponent, 1.0, false, true)
		if String(state.ball.shotType) == "error" or state.aiRecoveryMode:
			errors += 1
	return float(errors) / float(ERROR_SAMPLES)


static func ai_speed(profile: Dictionary) -> float:
	return float(profile["speed"]) * (0.86 + float(profile["skill"]) * 0.1)


## `Number(x.toFixed(digits))` on the non-negative values this audit reports.
static func _round_to(value: float, digits: int) -> float:
	var factor: float = pow(10.0, float(digits))
	return Sim.js_round(value * factor) / factor


# ---------------------------------------------------------------------------
# Extra check: the tiers and the reaction skill come from `frozen.gd`.
# ---------------------------------------------------------------------------

static func _frozen_tiers(audit: AuditBase, profiles: Array) -> void:
	audit.check_eq(profiles.size(), 4, "difficulty/frozen_has_four_tiers")
	audit.check_eq(String(profiles[0]["id"]), "rivale", "difficulty/first_tier_is_rivale")
	audit.check_eq(String(profiles[profiles.size() - 1]["id"]), "leggenda", "difficulty/last_tier_is_leggenda")
	var leggenda: Dictionary = profiles[profiles.size() - 1]
	audit.check_true(leggenda.has("reactionSkill"), "difficulty/leggenda_has_a_reaction_skill_override")
	if leggenda.has("reactionSkill"):
		audit.check_eq(
			float(leggenda["reactionSkill"]), LEGGENDA_REACTION_SKILL,
			"difficulty/leggenda_reaction_skill_is_pinned_at_0.78",
		)
	for index in range(0, profiles.size() - 1):
		audit.check_true(
			not profiles[index].has("reactionSkill") or profiles[index]["reactionSkill"] == null,
			"difficulty/%s_has_no_reaction_skill_override" % String(profiles[index]["id"]),
		)
