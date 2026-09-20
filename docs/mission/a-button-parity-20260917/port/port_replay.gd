extends SceneTree
## port_replay.gd — isolated replay of the ACTUAL Godot A-button input path.
##
## Two layers, distinguished on purpose (CHARTER evidence contract):
##   Layer A (adapter): the REAL `game/input_map.gd.sample()` on a REAL
##     `Sim.create_match_state` state. The only override is the device seam
##     (`_button`/`_axis`/`_key_pressed`) — the exact boundary the pre-existing
##     `tests/input/shot_sequences_test.gd` and `controller_trace.gd` mock, and
##     the boundary between hardware polling and the input struct. No mapper is
##     restated here.
##   Layer B (full live path): the REAL `game/Match.tscn` -> `apply_frame` ->
##     `advance_frame` -> `tick_fixed` -> `Sim.update_match`. The sampler's real
##     output is fed through the REAL frame-to-fixed-step handoff. This is the
##     same seam `tests/game_slice_test.gd` drives (`apply_frame(sample, delta)`).
##
## Covered: A hold/release (tap), RB+A (chiquita), aim carry-through, primed
## double press (smashUpgrade), and zero/one/multiple fixed ticks.

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MATCH_SCENE := "res://game/Match.tscn"
const TICK := 1.0 / 120.0
const SEED := 20260917
const MAX_SIM_STEPS := 8

## The device seam: `input_map.gd` reads buttons/axes/keys through these three
## methods; this subclass feeds them from plain dictionaries so a timeline can
## be replayed without a physical pad. The `sample()` body above this seam is
## the production one, unmodified.
class Pad:
	extends "res://game/input_map.gd"
	var buttons := {}
	var axes := {}
	var keys := {}
	func _button(button: int) -> bool:
		return bool(buttons.get(button, false))
	func _axis(axis: int) -> float:
		return float(axes.get(axis, 0.0))
	func _key_pressed(_action: String) -> bool:
		return false


var _checks := 0
var _failures := 0
var _phase := 0


func check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("ok ", label)
	else:
		_failures += 1
		print("FAIL ", label)


func _process(_delta: float) -> bool:
	if _phase == 0:
		_phase = 1
		_run()
	return _phase == 2


func _run() -> void:
	var info: Dictionary = Engine.get_version_info()
	print("# PORT_REPLAY engine=%s physics=%d seed=%d" % [
		String(info.get("string", "?")), Engine.physics_ticks_per_second, SEED,
	])
	check(String(info.get("string", "")) == "4.7.2-stable (official)", "engine pinned to 4.7.2 official")
	check(Engine.physics_ticks_per_second == 120, "physics tick is 120 Hz")

	_layer_a_sampler()
	await _layer_b_replay()

	_phase = 2
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
		quit(1)


# ---------------------------------------------------------------------------
# Layer A: the sampler (real input_map.gd.sample, device seam overridden)
# ---------------------------------------------------------------------------

func _layer_a_sampler() -> void:
	print("# --- Layer A: sampler (real input_map.gd.sample) ---")
	var state = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[0], 0, {})

	# A hold -> drive charge, movement stopped, aim carried.
	var pad := Pad.new(true)
	pad.buttons = {JOY_BUTTON_A: true}
	pad.axes = {JOY_AXIS_LEFT_X: 0.7, JOY_AXIS_LEFT_Y: -0.4}
	var held: Dictionary = pad.sample(state)
	print("SAMPLER tap-hold ", JSON.stringify(held))
	check(bool(held["charging"]) and not bool(held["hit"]) and String(held["shotVariant"]) == "drive",
		"A hold charges a drive (not a hit)")
	check(float(held["moveX"]) == 0.0 and float(held["moveY"]) == 0.0, "A hold stops movement")
	check(bool(held["analogAim"]) and absf(float(held["aim"])) > 0.3, "A hold carries the left-stick aim")

	pad.buttons = {}
	pad.axes = {}
	var released: Dictionary = pad.sample(state)
	print("SAMPLER tap-release ", JSON.stringify(released))
	check(bool(released["hit"]) and not bool(released["charging"]) and String(released["shotVariant"]) == "drive",
		"A release fires the drive")
	check(float(released["aim"]) == float(held["aim"]) and bool(released["analogAim"]),
		"release preserves the aim of the charge")
	var again: Dictionary = pad.sample(state)
	check(not bool(again["hit"]), "A release fires only once")

	# RB+A -> chiquita.
	pad = Pad.new(true)
	pad.buttons = {JOY_BUTTON_A: true, JOY_BUTTON_RIGHT_SHOULDER: true}
	var rb_held: Dictionary = pad.sample(state)
	print("SAMPLER rb+a-hold ", JSON.stringify(rb_held))
	check(String(rb_held["shotVariant"]) == "chiquita" and bool(rb_held["charging"]), "RB+A charges a chiquita")
	pad.buttons = {}
	var rb_released: Dictionary = pad.sample(state)
	check(bool(rb_released["hit"]) and String(rb_released["shotVariant"]) == "chiquita", "RB+A release fires a chiquita")

	# X > Y > A priority.
	pad = Pad.new(true)
	pad.buttons = {JOY_BUTTON_A: true, JOY_BUTTON_X: true, JOY_BUTTON_Y: true}
	var prio: Dictionary = pad.sample(state)
	print("SAMPLER priority ", JSON.stringify(prio))
	check(String(prio["shotVariant"]) == "slice", "X has priority over Y and A")

	# Primed double press (sampler): smashPrimed + A -> one-shot smashUpgrade.
	state.smashPrimed = true
	pad = Pad.new(true)
	pad.buttons = {JOY_BUTTON_A: true}
	var up: Dictionary = pad.sample(state)
	print("SAMPLER primed-press ", JSON.stringify(up))
	check(bool(up["smashUpgrade"]) and not bool(up["charging"]), "primed A emits smashUpgrade without charging")
	var up2: Dictionary = pad.sample(state)
	check(not bool(up2["smashUpgrade"]), "held upgrade is not repeated")
	pad.buttons = {}
	var up3: Dictionary = pad.sample(state)
	check(not bool(up3["hit"]), "upgrade release is not another hit")
	state.smashPrimed = false


# ---------------------------------------------------------------------------
# Layer B: the full live path (Match.tscn -> apply_frame -> tick_fixed)
# ---------------------------------------------------------------------------

func _layer_b_replay() -> void:
	print("# --- Layer B: full live-path replay (real Match.tscn -> apply_frame) ---")
	Config.seed_value = SEED
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = 0
	var packed: PackedScene = load(MATCH_SCENE)
	check(packed != null, "Match.tscn loads")
	if packed == null:
		return
	var node: Node = packed.instantiate()
	node.harness_mode()
	root.add_child(node)
	await process_frame
	check(node.state != null and node.state.ball != null and node.state.player != null,
		"match owns a real sim state")
	check(int(node.state.rng_state) == SEED, "seed pinned before the first tick")

	# Escape the serve phase with the real scripted player, so the shot-control
	# path (not the serve path) is the one under test.
	var bot := ScriptedPlayer.new()
	var escape := 0
	while bool(node.state.serving) and escape < 1500:
		node.tick_fixed(TICK, bot.decide(node.state), Sim.empty_input())
		escape += 1
	check(not bool(node.state.serving), "match leaves the serve phase")

	await _timeline_tap(node)
	await _timeline_rb_a(node)
	await _timeline_aim(node)
	await _timeline_primed(node)
	await _timeline_ticks(node)

	for child in root.get_children():
		root.remove_child(child)
		child.free()


func _record(node: Node, timeline: String, idx: int, sample: Dictionary, report: Dictionary) -> void:
	var s = node.state
	var rec := {
		"intent": sample,
		"steps": int(report.get("steps", -1)),
		"accumulator": snappedf(float(report.get("accumulator", -1.0)), 0.000001),
		"ticks": int(node.ticks),
		"shotCharge": snappedf(float(s.shotCharge), 0.0001),
		"shotAim": snappedf(float(s.shotAim), 0.0001),
		"shotIntent": String(s.shotIntent),
		"queuedShotVariant": String(s.queuedShotVariant),
		"queuedShotCharge": snappedf(float(s.queuedShotCharge), 0.0001),
		"queuedShotPower": snappedf(float(s.queuedShotPower), 0.0001),
		"queuedShotAim": snappedf(float(s.queuedShotAim), 0.0001),
		"smashPrimed": bool(s.smashPrimed),
		"cutVolleyPrimed": bool(s.cutVolleyPrimed),
		"globoPrimed": bool(s.globoPrimed),
		"rallyHits": int(s.rallyHits),
		"events_total": int(s.events.size()),
		"events_tail": Array(s.events.slice(maxi(0, s.events.size() - 4))),
	}
	print("REPLAY %s %d %s" % [timeline, idx, JSON.stringify(rec)])


func _timeline_tap(node: Node) -> void:
	var pad := Pad.new(true)
	for i in 6:
		pad.buttons = {JOY_BUTTON_A: true}
		pad.axes = {JOY_AXIS_LEFT_X: 0.6, JOY_AXIS_LEFT_Y: -0.3}
		var s: Dictionary = pad.sample(node.state)
		var r: Dictionary = node.apply_frame(s, TICK)
		_record(node, "tap", i, s, r)
	pad.buttons = {}
	pad.axes = {}
	var srel: Dictionary = pad.sample(node.state)
	var rrel: Dictionary = node.apply_frame(srel, TICK)
	_record(node, "tap", 6, srel, rrel)
	check(String(node.state.queuedShotVariant) == "drive", "tap release queues a drive")
	check(float(node.state.queuedShotCharge) > 0.0, "tap release carries the accumulated charge")
	var sidle: Dictionary = pad.sample(node.state)
	var ridle: Dictionary = node.apply_frame(sidle, TICK)
	_record(node, "tap", 7, sidle, ridle)
	check(String(node.state.queuedShotVariant) == "drive", "drive queue persists (no double fire)")


func _timeline_rb_a(node: Node) -> void:
	var pad := Pad.new(true)
	for i in 4:
		pad.buttons = {JOY_BUTTON_A: true, JOY_BUTTON_RIGHT_SHOULDER: true}
		var s: Dictionary = pad.sample(node.state)
		var r: Dictionary = node.apply_frame(s, TICK)
		_record(node, "rb_a", i, s, r)
	pad.buttons = {}
	var s: Dictionary = pad.sample(node.state)
	var r: Dictionary = node.apply_frame(s, TICK)
	_record(node, "rb_a", 4, s, r)
	check(String(node.state.queuedShotVariant) == "chiquita", "RB+A release queues a chiquita")


func _timeline_aim(node: Node) -> void:
	var pad := Pad.new(true)
	var last_aim := 0.0
	for i in 5:
		pad.buttons = {JOY_BUTTON_A: true}
		pad.axes = {JOY_AXIS_LEFT_X: -0.9, JOY_AXIS_LEFT_Y: 0.1}
		var s: Dictionary = pad.sample(node.state)
		last_aim = float(s["aim"])
		var r: Dictionary = node.apply_frame(s, TICK)
		_record(node, "aim", i, s, r)
	check(not is_zero_approx(float(node.state.shotAim)), "charge carries the aim into the sim state")
	pad.buttons = {}
	pad.axes = {}
	var s: Dictionary = pad.sample(node.state)
	var r: Dictionary = node.apply_frame(s, TICK)
	_record(node, "aim", 5, s, r)
	check(absf(float(node.state.queuedShotAim) - last_aim) < 0.0001,
		"release hands the aim to the queued shot")


func _timeline_primed(node: Node) -> void:
	# Seed the precondition (a primed smash with an armed swing buffer AND a live
	# double-tap window) so the REAL handoff's smashUpgrade branch is reachable
	# without an organic rally. The window and buffer are the reference's own
	# balance values (frozen/data.json): smashDoubleTapWindow=0.7, smashBufferWindow=0.9.
	node.state.smashPrimed = true
	node.state.smashTapWindow = 0.7
	node.state.playerSwingBuffer = 0.9
	node.state.queuedShotVariant = "drive"
	var pad := Pad.new(true)
	pad.buttons = {JOY_BUTTON_A: true}
	var s: Dictionary = pad.sample(node.state)
	check(bool(s["smashUpgrade"]), "primed A sample emits smashUpgrade")
	var r: Dictionary = node.apply_frame(s, TICK)
	_record(node, "primed", 0, s, r)
	check(String(node.state.queuedShotVariant) == "smash", "smashUpgrade flips the queued shot to smash")
	check(not bool(node.state.smashPrimed), "smashPrimed is consumed by the upgrade")
	var tail: Array = node.state.events.slice(maxi(0, node.state.events.size() - 4))
	check(tail.has("evSmashTapConfirmed"), "evSmashTapConfirmed emitted")


func _timeline_ticks(node: Node) -> void:
	var pad := Pad.new(true)
	var s0: Dictionary = pad.sample(node.state)
	var r0: Dictionary = node.apply_frame(s0, 0.0001)
	check(int(r0["steps"]) == 0, "a sub-step frame runs zero fixed ticks")
	_record(node, "ticks", 0, s0, r0)
	var s1: Dictionary = pad.sample(node.state)
	var r1: Dictionary = node.apply_frame(s1, TICK)
	check(int(r1["steps"]) == 1, "a full-step frame runs exactly one fixed tick")
	_record(node, "ticks", 1, s1, r1)
	var s2: Dictionary = pad.sample(node.state)
	var r2: Dictionary = node.apply_frame(s2, 2.0 * TICK)
	check(int(r2["steps"]) == 2, "a double-step frame runs two fixed ticks")
	_record(node, "ticks", 2, s2, r2)
	var s3: Dictionary = pad.sample(node.state)
	var r3: Dictionary = node.apply_frame(s3, 0.25)
	check(int(r3["steps"]) == MAX_SIM_STEPS, "a stalled frame clamps at MAX_SIM_STEPS (8) ticks")
	_record(node, "ticks", 3, s3, r3)
