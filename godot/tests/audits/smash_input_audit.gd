## smash_input_audit.gd — the port of `scripts/smash-input-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/smash_input_audit.gd
##
## Same contact heights, same net-relative positions, same charges, same two-tap
## input dicts and the same `1/60` ticks as the reference.
##
## The promises (`scripts/smash-input-audit.mjs:35-156`):
##   1. a second A on a high ball at the net produces `smash-x2`, a lateral stick
##      produces `smash-x3`;
##   2. a valid but imperfect smash degrades to `smash-flat`, not to `bandeja`;
##   3. a low ball (`BALANCE.smashMinHeight - 8`) and a baseline contact
##      (`COURT.netY + BALANCE.smashNetWindow + 30`) both stay `bandeja`;
##   4. the primed/confirmed two-tap state: the first A release primes the smash,
##      the second tap confirms it (clears `smashPrimed`) and the shot is kept
##      until contact with an incoming ball — `smash-x2`;
##   5. without the second tap the prepared shot degrades to `drive`, it does not
##      vanish, and the striker is still the player;
##   6. the return of serve cannot be a smash: it is a `bandeja`.
##
## Extra checks the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## the primed/confirmed state is read across two separate `updateMatch` ticks
## rather than one call, and every shot type asserted here is the `shotType` enum
## the port stores on the ball, never a rendered label.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

## `scripts/smash-input-audit.mjs:88`, `:90`, `:100` — the two-tap ticks.
const TAP_DT := 1.0 / 60.0
const BUFFER_FRAMES := 40
const MISSED_TAP_FRAMES := 65


func _initialize() -> void:
	var audit := AuditBase.new("smash_input")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var balance: Dictionary = Frozen.balance()
	var court: Dictionary = Frozen.court()
	var net_y := float(court["netY"])

	audit.check_eq(smash(audit, {}), "smash-x2", "smash_input/double_tap_high_ball_is_x2")
	audit.check_eq(smash(audit, {"aim": 0.82}), "smash-x3", "smash_input/lateral_stick_is_x3")
	audit.check_eq(
		smash(audit, {"aim": 0.82, "timingAge": 0.3, "moveRatio": 1.0, "passed": 20.0}),
		"smash-flat", "smash_input/imperfect_smash_degrades_to_flat",
	)
	audit.check_eq(
		smash(audit, {"height": float(balance["smashMinHeight"]) - 8.0}),
		"bandeja", "smash_input/low_ball_stays_bandeja",
	)
	audit.check_eq(
		smash(audit, {"y": net_y + float(balance["smashNetWindow"]) + 30.0}),
		"bandeja", "smash_input/baseline_smash_stays_bandeja",
	)
	audit.check_eq(
		smash(audit, {"rallyHits": 0}),
		"bandeja", "smash_input/return_of_serve_cannot_be_a_smash",
	)

	audit.check_eq(buffered_smash(audit), "smash-x2", "smash_input/buffered_two_tap_keeps_the_smash")

	var missed := missed_double_tap(audit)
	audit.check_eq(String(missed["type"]), "drive", "smash_input/missed_double_tap_degrades_to_drive")
	audit.check_eq(String(missed["hitter"]), "player", "smash_input/missed_double_tap_still_hits")

	audit.report("x2=%s x3=%s imperfect=%s lowBall=%s fromBack=%s buffered=%s missedDoubleTap=%s/%s" % [
		smash(audit, {}),
		smash(audit, {"aim": 0.82}),
		smash(audit, {"aim": 0.82, "timingAge": 0.3, "moveRatio": 1.0, "passed": 20.0}),
		smash(audit, {"height": float(balance["smashMinHeight"]) - 8.0}),
		smash(audit, {"y": net_y + float(balance["smashNetWindow"]) + 30.0}),
		buffered_smash(audit),
		missed["type"], missed["hitter"],
	])


# ---------------------------------------------------------------------------
# `smash` (`scripts/smash-input-audit.mjs:6-33`), verbatim — `rallyHits > 0`
# because the smash is forbidden on the service return and this bench is about
# shots inside a rally.
# ---------------------------------------------------------------------------

static func smash(audit: AuditBase, options: Dictionary) -> String:
	var court: Dictionary = Frozen.court()
	var height: float = float(options.get("height", 55.0))
	var y: float = float(options.get("y", float(court["netY"]) + 170.0))
	var aim: float = float(options.get("aim", 0.0))
	var aim_y: float = float(options.get("aimY", -1.0))
	var charge: float = float(options.get("charge", 0.76))
	var timing_age: float = float(options.get("timingAge", 0.0))
	var move_ratio: float = float(options.get("moveRatio", 0.0))
	var passed: float = float(options.get("passed", 0.0))
	var rally_hits: int = int(options.get("rallyHits", 2))

	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	state.running = true
	state.serving = false
	state.rallyHits = rally_hits
	state.player.x = 480.0
	state.player.y = y
	state.player.hitCooldown = 0.0
	state.player.moveRatio = move_ratio
	state.ball.x = 480.0
	state.ball.y = y + passed
	state.ball.z = height
	state.ball.vy = 120.0
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null

	var power: float = 0.4 + charge * 0.95
	var landed: bool = Sim.hit_ball(state, state.player, power, false, true, aim, false, "smash", aim_y, timing_age)
	audit.check_true(landed, "smash_input/contact_registered_h%.0f_y%.0f_aim%.2f" % [height, y, aim])
	return String(state.ball.shotType)


# ---------------------------------------------------------------------------
# `bufferedSmash` (`scripts/smash-input-audit.mjs:53-103`).
# ---------------------------------------------------------------------------

static func buffered_smash(audit: AuditBase) -> String:
	var court: Dictionary = Frozen.court()
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	state.running = true
	state.serving = false
	state.shotCharge = 0.76
	state.activePlayerKey = "player"
	state.rallyHits = 2
	state.player.x = 480.0
	state.player.y = float(court["netY"]) + 170.0
	state.player.hitCooldown = 0.0
	state.player.moveRatio = 0.0
	state.ball.x = 480.0
	state.ball.y = state.player.y - 125.0
	state.ball.z = 68.0
	state.ball.vx = 0.0
	state.ball.vy = 260.0
	state.ball.vz = 135.0
	state.ball.bounces = {"player": 0, "ai": 1}
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null

	var release := Support.vuoto()
	release["hit"] = true
	release["shotVariant"] = "drive"
	release["aim"] = 0.0
	release["aimY"] = -1.0
	release["analogAim"] = true
	release["moveX"] = 0.0
	release["moveY"] = 0.0
	Sim.update_match(state, TAP_DT, release)
	audit.check_eq(state.smashPrimed, true, "smash_input/first_a_release_primes_the_smash")

	var confirm := Support.vuoto()
	confirm["smashUpgrade"] = true
	confirm["aim"] = 0.0
	confirm["aimY"] = -1.0
	confirm["analogAim"] = true
	confirm["moveX"] = 0.0
	confirm["moveY"] = 0.0
	Sim.update_match(state, TAP_DT, confirm)
	audit.check_eq(state.smashPrimed, false, "smash_input/second_a_tap_confirms_the_smash")

	var idle := Support.vuoto()
	idle["moveX"] = 0.0
	idle["moveY"] = 0.0
	for frame in range(0, BUFFER_FRAMES):
		if String(state.ball.shotType) == "smash-x2":
			break
		Sim.update_match(state, TAP_DT, idle)
	return String(state.ball.shotType)


# ---------------------------------------------------------------------------
# `missedDoubleTap` (`scripts/smash-input-audit.mjs:105-138`).
# ---------------------------------------------------------------------------

static func missed_double_tap(audit: AuditBase) -> Dictionary:
	var court: Dictionary = Frozen.court()
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	state.running = true
	state.serving = false
	state.shotCharge = 0.76
	state.rallyHits = 2
	state.player.x = 480.0
	state.player.y = float(court["netY"]) + 170.0
	state.player.hitCooldown = 0.0
	state.player.moveRatio = 0.0
	state.ball.x = 480.0
	state.ball.y = state.player.y - 125.0
	state.ball.z = 68.0
	state.ball.vx = 0.0
	state.ball.vy = 260.0
	state.ball.vz = 135.0
	state.ball.bounces = {"player": 0, "ai": 1}
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null

	var release := Support.vuoto()
	release["hit"] = true
	release["shotVariant"] = "drive"
	release["aim"] = 0.0
	release["aimY"] = -1.0
	release["analogAim"] = true
	release["moveX"] = 0.0
	release["moveY"] = 0.0
	Sim.update_match(state, TAP_DT, release)

	var idle := Support.vuoto()
	idle["moveX"] = 0.0
	idle["moveY"] = 0.0
	for frame in range(0, MISSED_TAP_FRAMES):
		if str(state.lastHitterSide) == "player":
			break
		Sim.update_match(state, TAP_DT, idle)
	return {"type": String(state.ball.shotType), "hitter": str(state.lastHitterSide)}
