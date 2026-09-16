## shot_quality_audit.gd — the port of `scripts/shot-quality-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/shot_quality_audit.gd
##
## Same five shots, same charges, same timing ages and the same seed as the
## reference: `shot()` sets `Math.random = seededRandom(42)` before construction,
## which is `state.rngState` at `js/game.js:218`, reproduced exactly by
## `Support.seeded_rng_state(42)` (see that helper's note).
##
## The assertions (`scripts/shot-quality-audit.mjs:54`, `:68-75`):
##   - the timing grades are `perfect` / `early` / `late`;
##   - a perfect timing has strictly better quality than an early one;
##   - the intent mode reads CONTROL at `charge 0.08` and POWER at `0.92`;
##   - the power shot costs more energy and travels faster than the control one.
##
## THE `mode` ASSERTION, AND WHY IT IS NOT A WEAKER ONE. The reference compares a
## LOCALIZED label, because `js/game.js:1070` stores the output of
## `t("shotMode" + Mode)`: "CONTROLLO" and "POTENZA" (`js/i18n.js:173-175`). The
## port stores the message id `shotMode:control` / `shotMode:power`
## (`godot/src/sim/sim.gd` `show_shot_feedback`), which is the same enum value
## before translation. Asserting the id is the same promise minus the translator —
## the ticket forbids comparing localized text (`sim-rules-audits.md` §Failure
## criteria), and the id is what the grade is actually computed from.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

## `scripts/shot-quality-audit.mjs:32` — `Math.random = seededRandom(42)` before
## every `createMatchState`.
const SEED := 42


func _initialize() -> void:
	var audit := AuditBase.new("shot_quality")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var perfect := shot(audit, "perfect", 0.5, 0.0, 0.0, 0.0)
	var early := shot(audit, "early", 0.5, 0.22, 0.0, 0.0)
	var late := shot(audit, "late", 0.5, 0.0, 28.0, 0.0)
	var control := shot(audit, "control", 0.08, 0.0, 0.0, 0.0)
	var power := shot(audit, "power", 0.92, 0.0, 0.0, 0.0)

	audit.check_eq(String(perfect["grade"]), "perfect", "shot_quality/perfect_timing_grades_perfect")
	audit.check_eq(String(early["grade"]), "early", "shot_quality/early_timing_grades_early")
	audit.check_eq(String(late["grade"]), "late", "shot_quality/late_timing_grades_late")
	audit.check_gt(
		float(perfect["quality"]), float(early["quality"]),
		"shot_quality/perfect_timing_has_better_quality",
	)
	audit.check_eq(String(control["mode"]), "shotMode:control", "shot_quality/low_charge_reads_control")
	audit.check_eq(String(power["mode"]), "shotMode:power", "shot_quality/high_charge_reads_power")
	audit.check_lt(
		float(power["energy"]), float(control["energy"]),
		"shot_quality/power_costs_more_energy_than_control",
	)
	audit.check_gt(
		float(power["speed"]), float(control["speed"]),
		"shot_quality/clean_power_travels_faster_than_control",
	)

	# The reference's own JSON report (`scripts/shot-quality-audit.mjs:77-91`),
	# printed here so a band or grade divergence can be read off side by side.
	audit.report("quality(perfect=%.3f early=%.3f late=%.3f) energy(control=%.3f power=%.3f) speed(control=%.1f power=%.1f)" % [
		perfect["quality"], early["quality"], late["quality"],
		control["energy"], power["energy"], control["speed"], power["speed"],
	])
	audit.report("reference quality(perfect=1.000 early=0.642 late=0.779) energy(control=0.943 power=0.860) speed(control=227.1 power=357.4)")


# ---------------------------------------------------------------------------
# `shot()` (`scripts/shot-quality-audit.mjs:31-60`), verbatim — including the
# `assert(hitBall(...))` the reference makes on the return value.
# ---------------------------------------------------------------------------

static func shot(
	audit: AuditBase,
	label: String,
	charge: float,
	timing_age: float,
	passed: float,
	aim: float,
) -> Dictionary:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, Support.seeded_rng_state(SEED))
	state.running = true
	state.serving = false
	state.rallyEnergy = {"player": 1.0, "ai": 1.0}
	state.player.x = 480.0
	state.player.y = 430.0
	state.player.moveRatio = 0.0
	state.player.hitCooldown = 0.0
	state.ball.x = 480.0
	state.ball.y = 430.0 + passed
	state.ball.z = 48.0
	state.ball.vy = 120.0
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null

	var power: float = 0.4 + charge * 0.95
	var landed: bool = Sim.hit_ball(state, state.player, power, false, true, aim, false, "drive", 0.0, timing_age)
	audit.check_true(landed, "shot_quality/%s_contact_registered" % label)

	var feedback: Variant = state.shotFeedback
	if feedback == null:
		audit.check_true(false, "shot_quality/%s_feedback_emitted" % label)
		return {"grade": "", "mode": "", "quality": 0.0, "energy": state.rallyEnergy["player"], "speed": 0.0}
	return {
		"grade": Dictionary(feedback)["grade"],
		"mode": Dictionary(feedback)["mode"],
		"quality": float(Dictionary(feedback)["quality"]),
		"energy": float(state.rallyEnergy["player"]),
		"speed": Support.ball_speed(state),
	}
