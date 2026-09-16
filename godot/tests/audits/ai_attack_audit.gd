## ai_attack_audit.gd — the port of `scripts/ai-attack-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 600 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/ai_attack_audit.gd
##
## Same seeds (`state.rngState = seme` with `1000 + i * 7919`, `i * 7919 + 7`,
## `i * 7919 + 21`), same 60/240/300 sample counts and the same `1/240` dt as the
## reference. The bench clears `aiServiceReceiverKey` / `serviceReceiverKey` /
## `aiReceiverLocked` — without that the opponents' rackets are parked in
## service-reception position by a branch that runs before the defence logic, and
## the bench measures an AI waiting for a serve instead of one defending.
##
## The promises (`scripts/ai-attack-audit.mjs:76-198`):
##   1. a short lob is replayed almost always (`giocati > 40/60`) and is attacked
##      in the majority of cases (`> 0.6`), with the smash the most common answer
##      (`> 0.4`), reached by stepping forward (`avanzata > 30 px`);
##   2. a deep lob suppresses the attack (`< 0.2`), and the gap between the two is
##      at least 0.4;
##   3. taking the court costs something: the lob risk rises from the baseline
##      (`> 0.4` at the net, `> 0.15` at mid-court, `< 0.25` at the baseline) with
##      no jumps, and the hardest tier lobs more than the easiest;
##   4. the hardest tier moves the opponent: mean landing offset from the centre
##      `> 0.45` of the half-width, fewer than 20% inside the central third, and
##      more than the easiest tier.
##
## Extra checks the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## the attack-rate comparison is reproduced for the two lob depths from the same
## charge triple, and every shot classification is the `shotType` enum the port
## stores, never a rendered label.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

const DT := 1.0 / 240.0
const CAMPAIGN_SAMPLES := 60
const LOB_FRAMES := 2400
const PLAYER_LOB_SAMPLES := 240
const ANGLE_SAMPLES := 300
const ANGLE_FRAMES := 3000
## `scripts/ai-attack-audit.mjs:28`.
const ATTACKING := ["smash-x2", "smash-x3", "vibora", "volley"]
## `scripts/ai-attack-audit.mjs:30` — the lob campaign tier.
const CAMPAIGN_AI := 2


func _initialize() -> void:
	var audit := AuditBase.new("ai_attack")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	# --- the short lob is punished, the deep one is not ---------------------
	var short := campaign(audit, 0.45)
	var deep := campaign(audit, 1.1)
	audit.report("short(lobbed=%d/%d attacks=%d smash=%d forward=%.0f) deep(lobbed=%d/%d attacks=%d)" % [
		short["giocati"], CAMPAIGN_SAMPLES, short["attacchi"], short["smash"], short["avanzata"],
		deep["giocati"], CAMPAIGN_SAMPLES, deep["attacchi"],
	])

	audit.check_gt(short["giocati"], 40, "ai_attack/short_lob_is_replayed")
	audit.check_gt(deep["giocati"], 40, "ai_attack/deep_lob_is_replayed")

	var short_rate := float(short["attacchi"]) / float(short["giocati"])
	var deep_rate := float(deep["attacchi"]) / float(deep["giocati"])
	audit.check_gt(short_rate, 0.6, "ai_attack/short_lob_is_attacked_majority")
	audit.check_gt(
		float(short["smash"]) / float(short["giocati"]), 0.4,
		"ai_attack/smash_is_the_common_answer_to_a_short_lob",
	)
	audit.check_gt(float(short["avanzata"]), 30.0, "ai_attack/ai_steps_forward_to_take_the_lob")
	audit.check_lt(deep_rate, 0.2, "ai_attack/deep_lob_is_not_attacked")
	audit.check_gt(short_rate, deep_rate + 0.4, "ai_attack/short_and_deep_lobs_are_clearly_different")
	audit.report("attackRate(short=%.0f%% deep=%.0f%%)" % [short_rate * 100.0, deep_rate * 100.0])

	# --- taking the court has to cost something -----------------------------
	var court: Dictionary = Frozen.court()
	var net_y := float(court["netY"])
	var hardest: int = Frozen.ai_opponents().size() - 1
	var at_net := lob_rate(hardest, net_y + 70.0)
	var at_mid := lob_rate(hardest, net_y + 150.0)
	var at_back := lob_rate(hardest, float(court["bottom"]) - 60.0)
	audit.report("lobbedAgainst(net=%.0f%% mid=%.0f%% back=%.0f%%)" % [at_net * 100.0, at_mid * 100.0, at_back * 100.0])
	audit.check_gt(at_net, 0.4, "ai_attack/net_position_is_lobbed_often")
	audit.check_gt(at_mid, 0.15, "ai_attack/mid_court_is_still_lobbed")
	audit.check_gt(at_net, at_mid, "ai_attack/lob_risk_falls_from_net_to_mid")
	audit.check_gt(at_mid, at_back, "ai_attack/lob_risk_falls_from_mid_to_back")
	audit.check_lt(at_back, 0.25, "ai_attack/baseline_lob_is_rare")

	var easiest := lob_rate(0, net_y + 70.0)
	audit.check_gt(at_net, easiest + 0.1, "ai_attack/hardest_tier_lobs_more_than_the_easiest")

	# --- and it has to move the opponent ------------------------------------
	var easy_angles := spread_from_centre(easiest)
	var hard_angles := spread_from_centre(hardest)
	audit.report("angles(easy=%.0f%% hard=%.0f%% hardCentral=%.0f%%)" % [
		easy_angles["medio"] * 100.0, hard_angles["medio"] * 100.0, hard_angles["centrale"] * 100.0,
	])
	audit.check_gt(hard_angles["medio"], 0.45, "ai_attack/hardest_tier_moves_the_opponent")
	audit.check_lt(hard_angles["centrale"], 0.2, "ai_attack/hardest_tier_avoids_the_central_third")
	audit.check_gt(
		hard_angles["medio"], easy_angles["medio"] + 0.05,
		"ai_attack/better_tier_angles_more",
	)


# ---------------------------------------------------------------------------
# `pallonetto` (`scripts/ai-attack-audit.mjs:30-58`).
# ---------------------------------------------------------------------------

static func lob_rule(audit: AuditBase, charge: float, seed: int, ai_index: int) -> Dictionary:
	var state: State = rally_state(ai_index)
	Support.inject_seed(state, seed)
	state.player.x = 480.0
	state.player.y = 500.0
	state.player.controlled = true
	state.player.isPlayer = true
	state.player.hitCooldown = 0.0
	state.playerMate.x = 700.0
	state.playerMate.y = 480.0
	state.playerMate.hitCooldown = 0.0
	var court: Dictionary = Frozen.court()
	state.opponent.x = 480.0
	state.opponent.y = float(court["top"]) + 76.0
	state.opponent.hitCooldown = 0.0
	state.opponentMate.x = 650.0
	state.opponentMate.y = float(court["netY"]) - 84.0
	state.opponentMate.hitCooldown = 0.0
	state.ball.x = 480.0
	state.ball.y = 480.0
	state.ball.z = 70.0
	state.ball.vx = 0.0
	state.ball.vy = -100.0
	state.ball.vz = 0.0
	state.ball.bounces = {"player": 0, "ai": 0}
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null
	state.ball.crossedNet = true

	Sim.hit_ball(state, state.player, charge, false, true, 0.0, false, "lob", 0.0)

	var start := state.opponent.y
	var max_forward := 0.0
	var hits_before := state.rallyHits
	for frame in range(0, LOB_FRAMES):
		Sim.update_match(state, DT, Support.vuoto())
		max_forward = maxf(max_forward, state.opponent.y - start)
		if state.rallyHits > hits_before:
			return {"colpo": String(state.ball.shotType), "avanzata": max_forward}
		if int(state.stats["pointsWon"]["player"]) != 0 or int(state.stats["pointsWon"]["ai"]) != 0:
			break
	return {"colpo": "", "avanzata": max_forward}


# ---------------------------------------------------------------------------
# `campagna` (`scripts/ai-attack-audit.mjs:60-71`).
# ---------------------------------------------------------------------------

static func campaign(audit: AuditBase, charge: float) -> Dictionary:
	var played := 0
	var attacks := 0
	var smashes := 0
	var forward_total := 0.0
	var counts: Dictionary = {}
	for index in range(0, CAMPAIGN_SAMPLES):
		var outcome := lob_rule(audit, charge, 1000 + index * 7919, CAMPAIGN_AI)
		var shot: String = String(outcome["colpo"])
		forward_total += float(outcome["avanzata"])
		if shot != "":
			played += 1
			if ATTACKING.has(shot):
				attacks += 1
			if shot.begins_with("smash"):
				smashes += 1
			counts[shot] = int(counts.get(shot, 0)) + 1
	return {
		"giocati": played,
		"attacchi": attacks,
		"smash": smashes,
		"avanzata": forward_total / float(CAMPAIGN_SAMPLES),
		"colpi": counts,
	}


# ---------------------------------------------------------------------------
# `quantoPallonetta` (`scripts/ai-attack-audit.mjs:109-127`).
# ---------------------------------------------------------------------------

static func lob_rate(ai_index: int, player_y: float) -> float:
	var lobs := 0
	for index in range(0, PLAYER_LOB_SAMPLES):
		var state: State = rally_state(ai_index)
		Support.inject_seed(state, index * 7919 + 7)
		state.player.x = 430.0
		state.player.y = player_y
		state.player.controlled = true
		state.player.isPlayer = true
		state.player.hitCooldown = 0.0
		state.playerMate.x = 620.0
		state.playerMate.y = player_y + 10.0
		state.playerMate.hitCooldown = 0.0
		state.opponent.x = 480.0
		state.opponent.y = 150.0
		state.opponent.hitCooldown = 0.0
		state.opponentMate.x = 600.0
		state.opponentMate.y = 220.0
		state.opponentMate.hitCooldown = 0.0
		state.ball.x = 480.0
		state.ball.y = 170.0
		state.ball.z = 60.0
		state.ball.vx = 0.0
		state.ball.vy = -80.0
		state.ball.vz = 0.0
		state.ball.bounces = {"player": 0, "ai": 0}
		state.ball.crossedNet = true
		Sim.hit_ball(state, state.opponent, 1.0, false, true)
		if String(state.ball.shotType) == "lob":
			lobs += 1
	return float(lobs) / float(PLAYER_LOB_SAMPLES)


# ---------------------------------------------------------------------------
# `scartoDalCentro` (`scripts/ai-attack-audit.mjs:160-186`).
# ---------------------------------------------------------------------------

static func spread_from_centre(ai_index: int) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var centre: float = (float(court["left"]) + float(court["right"])) / 2.0
	var half: float = (float(court["right"]) - float(court["left"])) / 2.0
	var offsets: Array = []
	for index in range(0, ANGLE_SAMPLES):
		var state: State = rally_state(ai_index)
		Support.inject_seed(state, index * 7919 + 21)
		state.player.x = 480.0
		state.player.y = 430.0
		state.player.controlled = true
		state.player.isPlayer = true
		state.player.hitCooldown = 0.0
		state.playerMate.x = 670.0
		state.playerMate.y = 440.0
		state.playerMate.hitCooldown = 0.0
		state.opponent.x = 480.0
		state.opponent.y = 150.0
		state.opponent.hitCooldown = 0.0
		state.opponentMate.x = 600.0
		state.opponentMate.y = 220.0
		state.opponentMate.hitCooldown = 0.0
		state.ball.x = 480.0
		state.ball.y = 170.0
		state.ball.z = 60.0
		state.ball.vx = 0.0
		state.ball.vy = -80.0
		state.ball.vz = 0.0
		state.ball.bounces = {"player": 0, "ai": 0}
		state.ball.crossedNet = true
		Sim.hit_ball(state, state.opponent, 1.0, false, true)
		for frame in range(0, ANGLE_FRAMES):
			state.aiReactionDelay = 99.0
			Sim.update_match(state, DT, Support.vuoto())
			if int(state.ball.bounces["player"]) != 0:
				offsets.append(absf(state.ball.x - centre) / half)
				break
			if int(state.stats["pointsWon"]["player"]) != 0 or int(state.stats["pointsWon"]["ai"]) != 0:
				break
	if offsets.is_empty():
		return {"medio": 0.0, "centrale": 0.0}
	var total := 0.0
	var central := 0
	for value in offsets:
		total += float(value)
		if float(value) < 0.33:
			central += 1
	return {
		"medio": total / float(offsets.size()),
		"centrale": float(central) / float(offsets.size()),
	}


## `createRallyState` (`scripts/ai-attack-audit.mjs:30-58` shares the bench with
## `difficulty-audit.mjs:33-67`): the live-rally shape with the serve keys cleared.
static func rally_state(ai_index: int) -> State:
	var state: State = Support.rally_state(Frozen.athletes()[0], Frozen.ai_opponents()[ai_index])
	state.lastHitterSide = "ai"
	state.rallyHits = 3
	return state
