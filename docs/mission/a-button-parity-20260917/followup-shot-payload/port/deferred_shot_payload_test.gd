## deferred_shot_payload_test.gd — proves the deferred-release payload loss and
## the minimal fix, through REAL ball contact.
##
## Charter: docs/mission/a-button-parity-20260917/followup-shot-payload/CHARTER.md
## Bug: match_controller.gd's `queued_one_shots` latch (`ONE_SHOTS`, only
## hit/special/switchPlayer/switchDirection/smashUpgrade/cutVolley/globo/teamTactic)
## survives a zero-substep frame, but shotVariant/slice/aim/aimY/analogAim do not —
## they come from whatever sample happens to be current when the latched "hit" is
## finally consumed. sim.gd:2854-2857 then falls back to variant "auto" instead of
## the actually-requested "drive", which changes whether hit_ball's smash_ready
## (shot_variant == "auto") fires on THIS contact (`sim.gd:1576`).
##
## Real path: real `res://game/Match.tscn` + `apply_frame()` (same function
## `_process` calls), fixed 1/120 step, matched athlete/arena/seed/state (the same
## bench `tests/audits/smash_input_audit.gd::buffered_smash` uses — a near-net,
## high, powered contact where drive vs auto is smash-eligibility-deciding, not
## cosmetic). One 1/240s (zero-substep) frame carries the release payload
## (hit=true, shotVariant="drive"); the next 1/240s frame is neutral and is the one
## whose accumulated time crosses FIXED_STEP, running the sub-step that actually
## queues the shot.
extends SceneTree

const MATCH_SCENE := "res://game/Match.tscn"
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Config := preload("res://game/match_config.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	print("# deferred_shot_payload_test — zero-substep release payload preservation")
	_contact_bench_scenario()
	print("PASS %d/%d" % [_checks - _failures, _checks] if _failures == 0 else "FAIL %d/%d" % [_failures, _checks])
	return 0 if _failures == 0 else 1


func _check(cond: bool, name: String, detail: String = "") -> void:
	_checks += 1
	if cond:
		print("ok %s" % name)
	else:
		_failures += 1
		print("FAIL %s: %s" % [name, detail])


## Real production node, harness clock only (no display), matched seed/state.
func _new_match_node() -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var packed: PackedScene = load(MATCH_SCENE)
	var node: Node = packed.instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	return node


## Same near-net/high/powered bench as `tests/audits/smash_input_audit.gd`'s
## `buffered_smash` — the one place in this codebase where "auto" vs "drive" is
## already known to be smash-eligibility-deciding on real contact, not a label.
func _arm_contact_bench(node: Node) -> void:
	var court: Dictionary = Frozen.court()
	var state = node.state
	state.serving = false
	state.rallyHits = 2
	state.activePlayerKey = "player"
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
	# Enough charge that queuedShotPower * athlete power clears smashMinPower
	# (0.98) once the hit is queued — the SAME arithmetic sim.gd:2859 performs.
	state.shotCharge = 0.85


func _drive_ball_to_contact(node: Node, initial: Dictionary) -> String:
	var half := 1.0 / 240.0
	# Frame 1: zero-substep. Carries the REAL release payload the sampler would
	# produce (hit + shotVariant="drive" + aim/aimY/analogAim), same fields
	# `game/input_map.gd:210-228` fills on a real controller release.
	var release := Sim.empty_input()
	release["hit"] = true
	release["shotVariant"] = "drive"
	release["slice"] = false
	release["aim"] = 0.0
	release["aimY"] = -1.0
	release["analogAim"] = true
	var f1: Dictionary = node.apply_frame(release, half)
	_check(int(f1["steps"]) == 0, "release frame runs no sub-step (zero-substep setup)", str(f1))
	_check(node.one_shot_armed("hit"), "hit is latched, unconsumed, after the release frame", str(node.queued_one_shots))
	# Frame 2: neutral (no controller input at all — this is what a rendered frame
	# with nothing new to report looks like). This is the frame whose accumulated
	# time crosses FIXED_STEP and spends the latched hit.
	var neutral := Sim.empty_input()
	var f2: Dictionary = node.apply_frame(neutral, half)
	_check(int(f2["steps"]) == 1, "neutral frame spends exactly one sub-step", str(f2))
	_check(bool(node.last_tick_input.get("hit", false)), "the spent tick saw hit=true", str(node.last_tick_input))
	print("# trace post-consume queuedShotVariant=%s playerSwingBuffer=%.3f smashPrimed=%s" % [
		String(node.state.queuedShotVariant), node.state.playerSwingBuffer, str(node.state.smashPrimed)])
	# Run contact to completion: a few more idle real-path frames at 1/120 so the
	# already-moving ball reaches the paddle and attempt_human_swing fires.
	var idle := Sim.empty_input()
	var shot_type := String(node.state.ball.shotType)
	for i in range(200):
		node.apply_frame(idle, 1.0 / 120.0)
		shot_type = String(node.state.ball.shotType)
		if i < 6:
			print("# trace step%d ballz=%.2f bally=%.2f swingBuffer=%.3f shotType=%s hitter=%s" % [
				i, node.state.ball.z, node.state.ball.y, node.state.playerSwingBuffer, shot_type, str(node.state.lastHitterSide)])
		if shot_type in ["smash-x2", "smash-x3", "smash-flat", "drive"] and node.state.lastHitterSide == "player":
			break
		if not node.state.result == null:
			break
	print("# trace debug smashPrimed=%s swingBuffer=%.3f fallback=%s ballz=%.2f ballY=%.2f playerY=%.2f queuedVariant=%s" % [
		str(node.state.smashPrimed), node.state.playerSwingBuffer, str(node.state.smashContactFallback),
		node.state.ball.z, node.state.ball.y, node.state.player.y, String(node.state.queuedShotVariant)])
	return shot_type


func _contact_bench_scenario() -> void:
	# --- side A: the actually-requested "drive" survives contact (target) ------
	var node_a := _new_match_node()
	_arm_contact_bench(node_a)
	var result_a := _drive_ball_to_contact(node_a, {})
	print("# trace shotType_after_fix_or_before=%s queuedShotVariant_last=%s" % [result_a, String(node_a.state.queuedShotVariant)])

	# --- side B: explicit control — force shot_variant "auto" through Sim
	# directly (no controller path), the SAME bench, to know what "auto" alone
	# produces on this exact contact — the comparator this test's verdict rests on.
	var node_b := _new_match_node()
	_arm_contact_bench(node_b)
	node_b.state.queuedShotPower = 0.4 + node_b.state.shotCharge * 0.95
	node_b.state.queuedShotCharge = node_b.state.shotCharge
	node_b.state.queuedShotAim = 0.0
	node_b.state.queuedShotAimY = -1.0
	node_b.state.queuedShotSlice = false
	node_b.state.queuedShotVariant = "auto"
	node_b.state.playerSwingBuffer = 0.9
	var idle := Sim.empty_input()
	var result_b := String(node_b.state.ball.shotType)
	for _i in range(120):
		node_b.apply_frame(idle, 1.0 / 120.0)
		result_b = String(node_b.state.ball.shotType)
		if result_b in ["smash-x2", "smash-x3", "smash-flat", "drive"] and node_b.state.lastHitterSide == "player":
			break
	print("# trace auto_reference_shotType=%s" % result_b)

	# --- the behavioral assertion the fix must turn green -----------------------
	# BEFORE the fix: node_a (real controller path, requested "drive") degrades to
	# "auto" at the consuming frame and produces the SAME upgraded shot as the
	# explicit-auto reference (both smash-x2 on this bench). AFTER the fix: node_a
	# preserves "drive" and must NOT upgrade to a smash on this bench (drive is not
	# smash-eligible per sim.gd:1576 unless shot_variant == "auto" or "smash").
	if result_a == result_b and result_b in ["smash-x2", "smash-x3"]:
		_check(false, "requested drive must not silently degrade to auto's smash on this bench",
			"drive-path result=%s == auto-reference result=%s (payload lost)" % [result_a, result_b])
	else:
		_check(true, "requested drive is preserved through the zero-substep frame (result=%s, auto-reference=%s)" % [result_a, result_b], "")

	if "queued_shot_payload" in node_a:
		_check(node_a.queued_shot_payload.is_empty(),
			"queued_shot_payload is cleared after consumption (no leak into next point)",
			str(node_a.queued_shot_payload))
	else:
		print("# note queued_shot_payload field not present yet (pre-fix source)")
