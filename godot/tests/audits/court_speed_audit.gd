## court_speed_audit.gd — the port of `scripts/court-speed-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/court_speed_audit.gd
##
## Same three shots, same charges, same aim values, same seed (`state.rngState =
## 11`), same `1/240` dt and the same 1200-frame budget as the reference: the ball
## speed is the MEAN from the strike to the first bounce, not the launch speed,
## because the ball decelerates and the chaser runs the whole way.
##
## The three promises (`scripts/court-speed-audit.mjs:74-110`):
##   1. a strong shot beats the runner: `drivePieno / mediano >= 1.35`,
##      `smash / mediano >= 1.5`, `smash > drivePieno`;
##   2. no athlete outruns a full drive (`piuVeloce < drivePieno`) and a soft
##      drive stays reachable even by the slowest (`drivePiano < piuLento`);
##   3. the AI speed bracket straddles the athletes': the easiest tier is slower
##      than the slowest athlete, the hardest beats the median one.
##
## Extra check the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## `BALANCE.basePaddleSpeed` and every athlete's `stats.speed` and every AI
## `speed`/`skill` are read back from `frozen.gd` and asserted against the values
## transcribed from the frozen reference (`js/data.js` at commit 2979588). A
## silently re-tuned table fails here, before it can flatter (or spoil) the
## relations below.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

const FRAMES := 1200
const DT := 1.0 / 240.0
## `scripts/court-speed-audit.mjs:39`.
const SEED := 11
## `scripts/court-speed-audit.mjs:59` — the guard against a bench that never flew.
const MIN_FLIGHT_SECONDS := 0.05

## `js/data.js` `BALANCE.basePaddleSpeed` at the frozen baseline (commit 2979588).
const REFERENCE_BASE_PADDLE_SPEED := 317.0
## `js/data.js` `ATHLETES[*].stats.speed`, id -> value, at the frozen baseline.
const REFERENCE_ATHLETE_SPEED := {
	"maestro": 0.96, "pantera": 1.30, "steamer": 0.92,
	"fiamma": 0.96, "oracolo": 0.94, "colosso": 0.94,
}
## `js/data.js` `AI_OPPONENTS[*]`, id -> [speed, skill], at the frozen baseline.
const REFERENCE_AI := {
	"rivale": [310.0, 0.46], "ingegnere": [341.0, 0.60],
	"campione": [377.0, 0.76], "leggenda": [398.0, 0.90],
}


func _initialize() -> void:
	var audit := AuditBase.new("court_speed")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	_frozen_table(audit)

	var drive_full := ball_speed(audit, "drive", 1.35, 0.9, 60.0)
	var smash := ball_speed(audit, "smash", 1.35, 0.8, 70.0)
	var drive_soft := ball_speed(audit, "drive", 0.8, 0.0, 60.0)

	var athletes: Array = Frozen.athletes()
	var balance: Dictionary = Frozen.balance()
	var athlete_speeds: Array = []
	for athlete in athletes:
		athlete_speeds.append(float(balance["basePaddleSpeed"]) * float(athlete["stats"]["speed"]))
	athlete_speeds.sort()
	var fastest: float = athlete_speeds[athlete_speeds.size() - 1]
	var slowest: float = athlete_speeds[0]
	var median: float = athlete_speeds[int(athletes.size() / 2)]

	var ai: Array = Frozen.ai_opponents()
	var easiest: float = ai_speed(ai[0])
	var hardest: float = ai_speed(ai[ai.size() - 1])

	audit.report("ball(driveSoft=%.1f driveFull=%.1f smash=%.1f) athletes(slow=%.1f median=%.1f fast=%.1f) ai(easy=%.1f hard=%.1f)" % [
		drive_soft, drive_full, smash, slowest, median, fastest, easiest, hardest,
	])
	audit.report("ratios(driveFull/median=%.2f smash/median=%.2f)" % [drive_full / median, smash / median])

	# --- 1. a strong shot beats the runner ---------------------------------
	audit.check_ge(drive_full / median, 1.35, "court_speed/full_drive_beats_median_athlete")
	audit.check_ge(smash / median, 1.5, "court_speed/smash_beats_median_athlete")
	audit.check_gt(smash, drive_full, "court_speed/smash_is_the_fastest_shot")

	# --- 2. no athlete outruns a strong shot -------------------------------
	audit.check_lt(fastest, drive_full, "court_speed/no_athlete_outruns_a_full_drive")
	audit.check_lt(drive_soft, slowest, "court_speed/soft_drive_is_reachable")

	# --- 3. the AI bracket straddles the athletes' --------------------------
	audit.check_lt(easiest, slowest, "court_speed/easiest_ai_slower_than_slowest_athlete")
	audit.check_gt(hardest, median, "court_speed/hardest_ai_beats_median_athlete")


# ---------------------------------------------------------------------------
# `velocitaPalla` (`scripts/court-speed-audit.mjs:37-61`), verbatim: mean ball
# speed from the strike to the first bounce in the opponent court, the 1200-frame
# budget and the `tempo > 0.05` bench guard included.
# ---------------------------------------------------------------------------

static func ball_speed(audit: AuditBase, variant: String, charge: float, aim: float, height: float) -> float:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, SEED)
	state.running = true
	state.serving = false
	state.pointPause = 0.0
	state.lastHitterSide = "ai"
	state.rallyHits = 3
	Support.clear_service_reception(state)
	state.player.x = 480.0
	state.player.y = 395.0
	state.player.controlled = true
	state.player.isPlayer = true
	state.player.hitCooldown = 0.0
	state.ball.x = 480.0
	state.ball.y = 375.0
	state.ball.z = height
	state.ball.vx = 0.0
	state.ball.vy = 100.0
	state.ball.vz = 0.0
	state.ball.crossedNet = true

	Sim.hit_ball(state, state.player, charge, false, true, aim, false, variant, -1.0 if variant == "smash" else 0.0)

	var distance := 0.0
	var elapsed := 0.0
	for frame in range(0, FRAMES):
		var previous_x: float = state.ball.x
		var previous_y: float = state.ball.y
		state.aiReactionDelay = 99.0
		Sim.update_match(state, DT, Support.vuoto())
		distance += Sim.hypot2(state.ball.x - previous_x, state.ball.y - previous_y)
		elapsed += DT
		if int(state.ball.bounces["ai"]) != 0:
			break
	audit.check_gt(elapsed, MIN_FLIGHT_SECONDS, "court_speed/bench_%s_charge%.2f_ball_flew" % [variant, charge])
	if elapsed <= 0.0:
		return 0.0
	return distance / elapsed


## `velocitaIa` (`scripts/court-speed-audit.mjs:64`).
static func ai_speed(profile: Dictionary) -> float:
	return float(profile["speed"]) * (0.86 + float(profile["skill"]) * 0.1)


# ---------------------------------------------------------------------------
# Extra check: the frozen tables, read back through `frozen.gd`.
# ---------------------------------------------------------------------------

static func _frozen_table(audit: AuditBase) -> void:
	var balance: Dictionary = Frozen.balance()
	audit.check_eq(
		float(balance["basePaddleSpeed"]), REFERENCE_BASE_PADDLE_SPEED,
		"court_speed/frozen_base_paddle_speed_matches_reference",
	)
	for athlete in Frozen.athletes():
		var id := String(athlete["id"])
		audit.check_eq(
			float(athlete["stats"]["speed"]), REFERENCE_ATHLETE_SPEED[id],
			"court_speed/frozen_athlete_%s_speed_matches_reference" % id,
		)
	for profile in Frozen.ai_opponents():
		var id := String(profile["id"])
		audit.check_eq(
			float(profile["speed"]), float(REFERENCE_AI[id][0]),
			"court_speed/frozen_ai_%s_speed_matches_reference" % id,
		)
		audit.check_eq(
			float(profile["skill"]), float(REFERENCE_AI[id][1]),
			"court_speed/frozen_ai_%s_skill_matches_reference" % id,
		)
