## controller_tactics_audit.gd — the port of `scripts/controller-tactics-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/controller_tactics_audit.gd
##
## Same contact positions, same heights, same charges and the same `1/60`
## movement tick as the reference. The simulation is driven directly with a
## per-tick input dictionary, which is the seam this slice stops at: whether a
## real gamepad reaches these fields is the input map's question, owned by the
## quick-match vertical slice, and it is not re-implemented here.
##
## The promises (`scripts/controller-tactics-audit.mjs:35-73`):
##   1. the three technical variants set their `shotType`: `chiquita` at `z 32`
##      with a `0.45` lateral stick, `vibora` at `z 58` with a slice and a `-0.55`
##      stick, `defensive-lob` from deep at `z 34`;
##   2. charge reduces the movement distance versus a normal step, but only by
##      half (`distance < normal` and `> normal * 0.5`);
##   3. the split-step trades speed for stability (`splitStep.distance <
##      normal.distance`);
##   4. RT no longer sprints: it must not change distance or energy at all (exact
##      equality — it is not "close", it is untouched);
##   5. the team tactic reaches the engine and announces itself.
##
## THE `events[0]` ASSERTION. The reference compares the localized line
## "Tattica di coppia: conquista la rete." (`js/i18n.js:98`). The port stores
## message ids in `state.events` (`godot/src/sim/sim.gd` `add_event`), so the
## assertion is made on the id `tactic_attack` — the same value before
## translation, and the only form the ticket allows (`sim-rules-audits.md`
## §Failure criteria: "the audit writes a localized string into compared state").
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

const MOVE_DT := 1.0 / 60.0
## `js/i18n.js:98` `tactic_attack`.
const TACTIC_ATTACK_MESSAGE_ID := "tactic_attack"


func _initialize() -> void:
	var audit := AuditBase.new("controller_tactics")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var court: Dictionary = Frozen.court()
	var net_y := float(court["netY"])

	# --- 1. the three technical variants ------------------------------------
	var chiquita := state_at_contact(32.0, net_y + 120.0)
	audit.check_true(
		Sim.hit_ball(chiquita, chiquita.player, 0.82, false, true, 0.45, false, "chiquita", 0.0),
		"controller_tactics/chiquita_contact_registered",
	)
	audit.check_eq(String(chiquita.ball.shotType), "chiquita", "controller_tactics/chiquita_sets_shot_type")

	var vibora := state_at_contact(58.0, net_y + 120.0)
	audit.check_true(
		Sim.hit_ball(vibora, vibora.player, 1.0, false, true, -0.55, true, "vibora", 0.0),
		"controller_tactics/vibora_contact_registered",
	)
	audit.check_eq(String(vibora.ball.shotType), "vibora", "controller_tactics/vibora_sets_shot_type")

	var defensive_lob := state_at_contact(34.0, net_y + 190.0)
	audit.check_true(
		Sim.hit_ball(defensive_lob, defensive_lob.player, 0.86, false, true, 0.2, false, "defensive-lob", 0.0),
		"controller_tactics/defensive_lob_contact_registered",
	)
	audit.check_eq(
		String(defensive_lob.ball.shotType), "defensive-lob",
		"controller_tactics/defensive_lob_sets_shot_type",
	)

	# --- 2/3/4. movement, split-step, charge and RT -------------------------
	var normal := movement_distance(audit, {})
	var charging := movement_distance(audit, {"charging": true})
	var split_step := movement_distance(audit, {"splitStep": 1.0})
	var sprint := movement_distance(audit, {"sprint": 1.0})

	audit.check_lt(split_step["distance"], normal["distance"], "controller_tactics/split_step_trades_speed_for_stability")
	audit.check_eq(sprint["distance"], normal["distance"], "controller_tactics/rt_does_not_change_distance")
	audit.check_eq(sprint["energy"], normal["energy"], "controller_tactics/rt_does_not_spend_energy")
	audit.check_lt(charging["distance"], normal["distance"], "controller_tactics/charge_slows_the_step")
	audit.check_gt(
		charging["distance"], float(normal["distance"]) * 0.5,
		"controller_tactics/charge_still_allows_adjustment",
	)

	# --- 5. the team tactic --------------------------------------------------
	var tactic: State = movement_distance(audit, {"teamTactic": "attack"})["state"]
	audit.check_eq(String(tactic.playerTeamTactic), "attack", "controller_tactics/team_tactic_reaches_the_state")
	audit.check_gt(tactic.events.size(), 0, "controller_tactics/team_tactic_announces_itself")
	if not tactic.events.is_empty():
		audit.check_eq(
			String(tactic.events[0]), TACTIC_ATTACK_MESSAGE_ID,
			"controller_tactics/team_tactic_event_id",
		)

	audit.report("movement(splitStep=%.2f charging=%.2f normal=%.2f sprint=%.2f) tactic=%s" % [
		split_step["distance"], charging["distance"], normal["distance"], sprint["distance"],
		tactic.playerTeamTactic,
	])


# ---------------------------------------------------------------------------
# `stateAtContact` (`scripts/controller-tactics-audit.mjs:18-33`).
# ---------------------------------------------------------------------------

static func state_at_contact(z: float, y: float) -> State:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	state.running = true
	state.serving = false
	state.player.x = 480.0
	state.player.y = y
	state.player.hitCooldown = 0.0
	state.player.moveRatio = 0.0
	state.ball.x = 480.0
	state.ball.y = y
	state.ball.z = z
	state.ball.vx = 0.0
	state.ball.vy = 120.0
	state.ball.vz = 0.0
	state.ball.bounces = {"player": 0, "ai": 1}
	state.ball.serveInFlight = false
	return state


# ---------------------------------------------------------------------------
# `movementDistance` (`scripts/controller-tactics-audit.mjs:47-54`).
# ---------------------------------------------------------------------------

static func movement_distance(audit: AuditBase, input: Dictionary) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var state := state_at_contact(80.0, float(court["bottom"]) - 70.0)
	state.ball.y = float(court["netY"]) - 130.0
	state.ball.vy = -80.0
	var start: float = state.player.x
	var tick := Support.vuoto()
	tick["moveX"] = 1.0
	tick["moveY"] = 0.0
	for key in input:
		tick[key] = input[key]
	Sim.update_match(state, MOVE_DT, tick)
	return {
		"distance": state.player.x - start,
		"energy": float(state.rallyEnergy["player"]),
		"state": state,
	}
