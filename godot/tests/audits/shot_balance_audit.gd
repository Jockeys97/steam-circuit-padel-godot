## shot_balance_audit.gd — the port of `scripts/shot-balance-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/shot_balance_audit.gd
##
## (This is the one audit whose reference sample counts — 300 lobs, 4 x 300 first
## replies, 2 x 2500 repertoire draws — need a bound above the 180 s the others
## run in. The counts are the reference's own and are NOT reduced here.)
##
## Same seeds, same sample counts, same dts (`1/240` for the rallies, the
## reference's own `0.001` for the lob flights) and the same three rally paddles as
## `scripts/shot-balance-audit.mjs`.
##
## The promises (`scripts/shot-balance-audit.mjs:102-187`):
##   1. charge increases lob depth (`short > medium > deep` in ball-y, i.e. deeper
##      means nearer the opponent's back glass);
##   2. the Pantera's maximum lob stays risky but usable — error rate inside
##      `(0.2, 0.75)` over 300 seeded lobs;
##   3. a deep lob can reach the glass and the AI can answer after its own glass;
##   4. X2 develops through the glass in the great majority of cases and is strong
##      but defendable (`0 < winners < 120` of 300); the strongest tier reads it
##      more often than the weakest;
##   5. an X3 against the medium AI stays special but not automatic
##      (`120 < winners < 270` of 300);
##   6. the AI repertoire is complete: drive, lob, volley, vibora, smash-x2,
##      smash-x3 and error all occur.
##
## Extra check the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## the lob-depth ordering is asserted from the same charge triple, and the
## repertoire requirement is asserted on the `shotType` enum the port stores, never
## on a rendered label.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")
const Rng := preload("res://src/sim/rng.gd")

const RALLY_DT := 1.0 / 240.0
## The reference's lob-flight dt (`scripts/shot-balance-audit.mjs:94`), kept as is.
const LOB_DT := 0.001
const LOB_FRAMES := 5000
const REPLY_FRAMES := 2600
const PANTERA_SAMPLES := 300
const REPERTOIRE_SAMPLES := 2500
const X2_WINNER_LIMIT := 120
const X3_MEDIUM_LOW := 120
const X3_MEDIUM_HIGH := 270

## `scripts/shot-balance-audit.mjs:165`.
const REPERTOIRE_SEED := 20260811


func _initialize() -> void:
	var audit := AuditBase.new("shot_balance")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var short_lob: Variant = lob_landing(audit, 0.4, 0.0)
	var medium_lob: Variant = lob_landing(audit, 0.8, 0.0)
	var deep_lob: Variant = lob_landing(audit, 1.1, -1.0)

	audit.check_true(
		short_lob != null and medium_lob != null and deep_lob != null,
		"shot_balance/controlled_lobs_bounce_in_court",
	)
	if short_lob != null and medium_lob != null and deep_lob != null:
		audit.check_gt(short_lob, medium_lob, "shot_balance/charge_increases_lob_depth_short_over_medium")
		audit.check_gt(medium_lob, deep_lob, "shot_balance/charge_increases_lob_depth_medium_over_deep")
		audit.report("lobDepths(short=%.3f medium=%.3f deep=%.3f)" % [short_lob, medium_lob, deep_lob])

	# --- 2. the Pantera's maximum lob stays risky but usable -----------------
	var pantera_errors := 0
	for seed in range(1, PANTERA_SAMPLES + 1):
		var state: State = rally_state(Frozen.athletes()[1], Frozen.ai_opponents()[1])
		Support.inject_seed(state, Support.seeded_rng_state(seed))
		Sim.hit_ball(state, state.player, 1.35, false, true, 0.0, false, "lob", -1.0)
		for frame in range(0, LOB_FRAMES):
			Sim.update_match(state, LOB_DT, Support.vuoto())
			state.aiReactionDelay = 99.0
			if int(state.ball.bounces["ai"]) != 0 or int(state.stats["pointsWon"]["ai"]) != 0:
				break
		if int(state.stats["pointsWon"]["ai"]) != 0:
			pantera_errors += 1
	var pantera_rate := float(pantera_errors) / float(PANTERA_SAMPLES)
	audit.check_between(pantera_rate, 0.2, 0.75, "shot_balance/pantera_max_lob_error_rate_in_band")
	audit.report("panteraLobErrorRate=%.3f (%d/%d)" % [pantera_rate, pantera_errors, PANTERA_SAMPLES])

	# --- 3. a deep lob reaches the glass and the AI answers after it ---------
	var glass_state: State = rally_state(Frozen.athletes()[0], Frozen.ai_opponents()[1])
	Support.inject_seed(glass_state, Support.HALF_RNG_STATE)
	glass_state.opponent.x = 480.0
	glass_state.opponent.y = 135.0
	Sim.hit_ball(glass_state, glass_state.player, 1.35, false, true, 0.0, false, "lob", 0.0)
	var glass_reached := false
	for frame in range(0, LOB_FRAMES):
		if glass_state.rallyHits >= 5:
			break
		Sim.update_match(glass_state, LOB_DT, Support.vuoto())
		if not glass_reached and str(glass_state.ball.postGlassSide) == "ai":
			glass_reached = true
		if not glass_reached:
			glass_state.aiReactionDelay = 99.0
	audit.check_true(glass_reached, "shot_balance/deep_lob_reaches_the_glass")
	audit.check_ge(glass_state.rallyHits, 5, "shot_balance/ai_answers_after_its_own_glass")

	# --- 4. the X2 through the glass, per difficulty tier -------------------
	var interceptions: Array = []
	for ai_index in range(0, Frozen.ai_opponents().size()):
		var through_glass := 0
		var winners := 0
		for seed in range(1, PANTERA_SAMPLES + 1):
			var reply := first_reply(audit, "smash", ai_index, 0.0, -1.0, seed + ai_index * 1000)
			if int(reply["maxSmashStage"]) >= 2:
				through_glass += 1
			if bool(reply["winner"]):
				winners += 1
		interceptions.append(1.0 - float(through_glass) / float(PANTERA_SAMPLES))
		audit.check_gt(
			float(through_glass) / float(PANTERA_SAMPLES), 0.7,
			"shot_balance/ai%d_x2_develops_through_the_glass" % ai_index,
		)
		audit.check_true(
			winners > 0 and winners < X2_WINNER_LIMIT,
			"shot_balance/ai%d_x2_strong_but_defendable" % ai_index,
		)
		audit.report("ai%d x2ThroughGlass=%d x2Winners=%d interception=%.3f" % [
			ai_index, through_glass, winners, interceptions[ai_index],
		])
	audit.check_gt(
		float(interceptions[interceptions.size() - 1]), float(interceptions[0]) + 0.05,
		"shot_balance/hardest_tier_reads_the_smash_more_often",
	)

	# --- 5. the X3 against the medium AI ------------------------------------
	var medium_x3_winners := 0
	for seed in range(1, PANTERA_SAMPLES + 1):
		if bool(first_reply(audit, "smash", 1, 0.8, -1.0, seed)["winner"]):
			medium_x3_winners += 1
	audit.check_between(
		float(medium_x3_winners), float(X3_MEDIUM_LOW), float(X3_MEDIUM_HIGH),
		"shot_balance/medium_x3_special_but_not_automatic",
	)
	audit.report("mediumX3WinnerRate=%.3f (%d/%d)" % [
		float(medium_x3_winners) / float(PANTERA_SAMPLES), medium_x3_winners, PANTERA_SAMPLES,
	])

	# --- 6. the AI repertoire is complete -----------------------------------
	var repertoire := repertoire_shots(audit)
	var missing: Array = []
	for required in ["drive", "lob", "volley", "vibora", "smash-x2", "smash-x3", "error"]:
		if not repertoire.has(required):
			missing.append(required)
		audit.check_true(repertoire.has(required), "shot_balance/ai_repertoire_has_%s" % required)
	audit.report("aiRepertoire=%s" % [JSON.stringify(_sorted(repertoire))])
	if not missing.is_empty():
		audit.note("repertoire mancante: %s" % ", ".join(missing))


# ---------------------------------------------------------------------------
# `createRallyState` (`scripts/shot-balance-audit.mjs:33-67`).
# ---------------------------------------------------------------------------

static func rally_state(athlete: Dictionary, ai_profile: Dictionary) -> State:
	var state: State = Support.rally_state(athlete, ai_profile)
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
# `simulateFirstReply` (`scripts/shot-balance-audit.mjs:69-87`).
# ---------------------------------------------------------------------------

static func first_reply(
	audit: AuditBase,
	kind: String,
	ai_index: int,
	aim: float,
	aim_y: float,
	seed: int,
) -> Dictionary:
	var ai: Array = Frozen.ai_opponents()
	var state: State = rally_state(Frozen.athletes()[0], ai[ai_index])
	Support.inject_seed(state, Support.seeded_rng_state(seed))
	Sim.hit_ball(state, state.player, 1.35, false, true, aim, false, kind, aim_y)
	var max_smash_stage := 0
	var used_glass := false
	for frame in range(0, REPLY_FRAMES):
		Sim.update_match(state, RALLY_DT, Support.vuoto())
		max_smash_stage = maxi(max_smash_stage, state.ball.smashStage)
		if not used_glass and str(state.ball.postGlassSide) == "ai":
			used_glass = true
		if (
			state.rallyHits >= 5
			or int(state.stats["pointsWon"]["player"]) != 0
			or int(state.stats["pointsWon"]["ai"]) != 0
		):
			break
	return {
		"returned": state.rallyHits >= 5,
		"winner": int(state.stats["pointsWon"]["player"]) > 0,
		"maxSmashStage": max_smash_stage,
		"usedGlass": used_glass,
	}


# ---------------------------------------------------------------------------
# `lobLanding` (`scripts/shot-balance-audit.mjs:89-100`).
# ---------------------------------------------------------------------------

static func lob_landing(audit: AuditBase, power: float, aim_y: float) -> Variant:
	var state: State = rally_state(Frozen.athletes()[0], Frozen.ai_opponents()[1])
	Support.inject_seed(state, Support.HALF_RNG_STATE)
	Sim.hit_ball(state, state.player, power, false, true, 0.0, false, "lob", aim_y)
	for frame in range(0, LOB_FRAMES):
		Sim.update_match(state, LOB_DT, Support.vuoto())
		state.aiReactionDelay = 99.0
		if int(state.ball.bounces["ai"]) != 0:
			return state.ball.y
		if int(state.stats["pointsWon"]["ai"]) != 0:
			return null
	return null


# ---------------------------------------------------------------------------
# The repertoire sampling (`scripts/shot-balance-audit.mjs:165-187`), including
# the ONE generator installed before the loop: state `i` starts from draw `i`.
# ---------------------------------------------------------------------------

static func repertoire_shots(audit: AuditBase) -> Array:
	var scenarios := [
		{"opponentY": 230.0, "ballY": 250.0, "ballZ": 70.0, "ballVy": -80.0},
		{"opponentY": 110.0, "ballY": 130.0, "ballZ": 34.0, "ballVy": -80.0},
	]
	var repertoire: Array = []
	# One generator (`Math.random = seededRandom(20260811)`) consumed once per
	# construction: state `i` uses draw `i`. Stepped incrementally — the draws are
	# sequential, so replaying from the seed for every state would be O(n^2).
	var generator := Rng.i32(REPERTOIRE_SEED)
	for scenario in scenarios:
		for sample in range(0, REPERTOIRE_SAMPLES):
			var draw := Support.mulberry32_step(generator)
			generator = int(draw["value"])
			var state: State = rally_state(Frozen.athletes()[0], Frozen.ai_opponents()[2])
			Support.inject_seed(state, Support.state_from_draw(int(draw["draw"])))
			state.opponent.x = 480.0
			state.opponent.y = float(scenario["opponentY"])
			state.opponent.hitCooldown = 0.0
			state.player.x = 330.0
			state.player.y = 390.0
			state.playerMate.x = 650.0
			state.playerMate.y = 400.0
			state.ball.x = 480.0
			state.ball.y = float(scenario["ballY"])
			state.ball.z = float(scenario["ballZ"])
			state.ball.vy = float(scenario["ballVy"])
			Sim.hit_ball(state, state.opponent, 1.0, false, true)
			var shot: String = String(state.ball.shotType)
			if not repertoire.has(shot):
				repertoire.append(shot)
	return repertoire


static func _sorted(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy
