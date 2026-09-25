## switch_mode_audit.gd — the player-switching system, the two sticks, and which pad
## the game is actually reading.
##
##   $GODOT --headless --path godot/ --script res://tests/input/switch_mode_audit.gd
##   … or through the runner, `res://tests/input/run_all.gd`.
##
## Seven questions, all answerable headless, none of them re-implementing a rule:
##
##   1. **Does a flick fire once?** `InputSource.switch_flick` is the pure form of
##      `pollGamepadGameplay`'s latch (`js/main.js:941-951`): the flick asks for a
##      switch at `SWITCH_FLICK` (0.72), and re-arms only when the stick falls back
##      below `SWITCH_RELEASE` (0.30) — or when a shot button is held, which clears it
##      inside the charge (`js/main.js:925`). Asserted as a sequence, because a latch
##      is a sequence, not a threshold: a threshold alone stays green with the latch
##      gone, which is the defect this file exists to keep out.
##   2. **Which stick does what?** The left one moves AND aims (absolute, curved by
##      `shotAimAxis`, `js/main.js:301-304`, read at `:920-923`); the right one only
##      asks for the directional switch. The stick response is curved by 1.28
##      (`js/main.js:295`) — the port used to be linear.
##   3. **Does the simulation honour the direction it is given?** The alignment gate
##      is driven through the real core (`sim.gd::update_active_player`,
##      `js/game.js:641-667`): a flick towards the partner switches, one away from him
##      does not, and the serve-reception lock refuses both the flick and the button.
##   4. **Does the preference reach the match?** `Config.control_mode()` reads the
##      saved `controlMode` and validates it against the reference's own three values
##      (`js/main.js:2273`); a match created without it keeps the simulation's default,
##      `semi`.
##   5. **Is the pad wired to the button the help label names?** This is the one this
##      audit exists for after 2026-09-16: the browser's Gamepad-API button numbers had
##      been pasted into `godot/project.godot`, where Godot numbers them differently
##      from LB onwards (4=back 5=guide 6=start 7=LS 8=RS 9=LB 10=RB 11-14=dpad). On a
##      real pad LB paused the match, View switched player, RB and Start did nothing,
##      and the D-pad set the wrong tactics. Each action is now checked against the
##      *Godot* constant for the physical button its own label names.
##   6. **Does a pad have to be device 0?** No: the pad somebody touches takes over and
##      the second seat gets the next connected pad (`js/main.js:258-276`, `:784`), and
##      a pad that takes over mid-match does not fire the shot it was holding
##      (`awaitingGameplayRelease`, `js/main.js:838-843`).
##   7. **Can the athlete run while charging?** Yes, and it is a PORT ADDITION: the
##      reference freezes him for as long as a shot button is held (`js/main.js:924`,
##      `g.move = { x: 0, y: 0 }`), which made the pad the only device on which a charge
##      and a run were mutually exclusive. The simulation already prices the charge in
##      (`chargeMovement`, 0.58 solo / 0.32 co-op, `js/game.js:3072` / `:2748`,
##      `sim.gd:2816`), so the sampler's only job is to pass the stick through. The
##      behavioural half is measured through the real core; the sampler half is a source
##      scan, because a headless engine enumerates no pads at all — the pad-driven charge
##      cannot be sampled on a machine without a controller, and a guard that only exists
##      on a desk with a pad attached is not a guard.
##
## What this file cannot assert, stated rather than dropped: with no controller
## attached, every pad read is neutral, so the *feel* of a real pad — and whether the
## pad in the player's hands is picked up by macOS as 0 or 1 — is a play-test. What is
## asserted here is the wiring that was missing or wrong.
##
## On the float note: Godot's `Vector2` is single precision, so a vector built at
## exactly 0.3 or 0.15 is a hair over it. Thresholds are asserted as constants, and
## the sequences use values inside the bands.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const InputSource := preload("res://game/input_map.gd")
const Config := preload("res://game/match_config.gd")
const SaveSchema := preload("res://src/save/save_schema.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## The tick the simulation is driven with, `1/120` (`js/main.js:1164`).
const DT := 1.0 / 120.0
## `[action, the Godot button constant for the physical button its label names, label]`.
const PAD_BINDINGS := [
	["padel_drive", JOY_BUTTON_A, "A"],
	["padel_slice", JOY_BUTTON_X, "X"],
	["padel_lob", JOY_BUTTON_Y, "Y"],
	["padel_special", JOY_BUTTON_B, "B"],
	["padel_switch", JOY_BUTTON_LEFT_SHOULDER, "LB"],
	["padel_technical", JOY_BUTTON_RIGHT_SHOULDER, "RB"],
	["padel_pause", JOY_BUTTON_START, "Start"],
	["padel_tactic_attack", JOY_BUTTON_DPAD_UP, "the D-pad's up"],
	["padel_tactic_defend", JOY_BUTTON_DPAD_DOWN, "the D-pad's down"],
	["padel_tactic_staggered", JOY_BUTTON_DPAD_LEFT, "the D-pad's left"],
	["padel_tactic_balanced", JOY_BUTTON_DPAD_RIGHT, "the D-pad's right"],
]
## The actions that carried the browser's number 4, which in Godot is `back`.
const WAS_ON_BACK := ["padel_switch", "padel_technical", "padel_pause", "padel_tactic_attack"]


func _initialize() -> void:
	var audit := AuditBase.new("switch_mode")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	_flick_latch(audit)
	_sticks(audit)
	_alignment_gate(audit)
	_control_mode(audit)
	_pad_bindings(audit)
	_devices(audit)
	_charge_keeps_the_feet(audit)
	audit.note(
		"the saved mode reaches the match through `game/match_controller.gd::start_match` and `::_adopt_session`, both of which assign `state.controlMode = Config.control_mode()`; the pad policy runs once per frame in `::_refresh_pads` (`js/main.js:780-784`). This audit asserts the values and the validation — the assignments are the lines above them"
	)


## The latch, as a sequence (question 1).
static func _flick_latch(audit: AuditBase) -> void:
	audit.check_eq(InputSource.SWITCH_FLICK, 0.72, "switch/the flick threshold is the reference's 0.72 (`js/main.js:943`)")
	audit.check_eq(InputSource.SWITCH_RELEASE, 0.3, "switch/the latch re-arms at the reference's 0.30 (`js/main.js:948`)")
	audit.check_eq(InputSource.DEADZONE, 0.15, "switch/the stick deadzone is the reference's 0.15 (`js/main.js:830`)")

	var flick := InputSource.switch_flick(Vector2(0.72, 0.0), false, false)
	audit.check_true(flick["direction"] != null, "switch/a flick at the 0.72 threshold asks for a switch")
	audit.check_true(bool(flick["latched"]), "switch/the flick arms the latch")
	var direction: Dictionary = flick["direction"]
	audit.check_true(
		absf(float(direction["x"]) - 0.72) < 0.001 and absf(float(direction["y"])) < 0.001,
		"switch/the flick carries the stick's own direction, not a normalised one",
	)

	for tick in 5:
		var held := InputSource.switch_flick(Vector2(0.9, 0.0), false, true)
		audit.check_true(held["direction"] == null, "switch/a held flick does not fire again (tick %d of 5)" % (tick + 1))
		audit.check_true(bool(held["latched"]), "switch/the latch stays armed while the stick is held (tick %d of 5)" % (tick + 1))

	var mid := InputSource.switch_flick(Vector2(0.5, 0.0), false, true)
	audit.check_true(mid["direction"] == null, "switch/0.5 is under the flick: no fire")
	audit.check_true(bool(mid["latched"]), "switch/0.5 is over the release: the latch stays armed")

	var released := InputSource.switch_flick(Vector2(0.29, 0.0), false, true)
	audit.check_true(not bool(released["latched"]), "switch/a stick back under 0.30 releases the latch")
	audit.check_true(released["direction"] == null, "switch/releasing the stick is not itself a switch")

	var again := InputSource.switch_flick(Vector2(0.8, 0.0), false, bool(released["latched"]))
	audit.check_true(again["direction"] != null, "switch/after the release the next flick fires")

	var charging := InputSource.switch_flick(Vector2(0.95, 0.0), true, true)
	audit.check_true(charging["direction"] == null, "switch/a stick past the flick while a charge is held is not a switch")
	audit.check_true(
		not bool(charging["latched"]),
		"switch/holding a shot button re-arms the latch (`js/main.js:925`)",
	)


## Which stick moves, which aims, and how both are shaped (question 2).
static func _sticks(audit: AuditBase) -> void:
	audit.check_eq(InputSource.STICK_CURVE, 1.28, "sticks/the response is curved by the reference's 1.28 (`js/main.js:295`)")
	audit.check_eq(InputSource.AIM_CURVE, 0.72, "sticks/the aim is curved by the reference's 0.72 (`js/main.js:301`)")

	# `radialStick`: dead inside the deadzone, then rescaled and curved.
	audit.check_eq(InputSource._radial(0.1, 0.0), Vector2.ZERO, "sticks/a stick well inside the deadzone is zero")
	audit.check_eq(InputSource._radial(0.0, 0.0), Vector2.ZERO, "sticks/a centred stick is zero")
	var half: Vector2 = InputSource._radial(0.5, 0.0)
	var linear: float = (0.5 - InputSource.DEADZONE) / (1.0 - InputSource.DEADZONE)
	audit.check_true(absf(half.x - pow(linear, 1.28)) < 0.001, "sticks/half stick is the curved value")
	audit.check_lt(half.x, linear, "sticks/the curve makes the middle of the stick deader than a straight line")
	audit.check_true(absf(InputSource._radial(1.0, 0.0).x - 1.0) < 0.001, "sticks/a stick at full deflection still reaches 1")
	audit.check_gt(InputSource._radial(1.0, 0.0).x, half.x, "sticks/more stick is still more movement")

	# `shotAimAxis`: the sign kept, the magnitude curved.
	audit.check_true(absf(InputSource.shot_aim_axis(0.5) - pow(0.5, 0.72)) < 0.001, "aims/half aim is curved by 0.72")
	audit.check_true(InputSource.shot_aim_axis(-0.5) < 0.0, "aims/the aim keeps its sign")
	audit.check_true(absf(InputSource.shot_aim_axis(-0.5) + pow(0.5, 0.72)) < 0.001, "aims/the sign survives the curve")
	audit.check_true(absf(InputSource.shot_aim_axis(1.0) - 1.0) < 0.001, "aims/full aim stays at 1")
	audit.check_true(InputSource.shot_aim_axis(0.0) == 0.0, "aims/a centred aim is zero")
	audit.check_true(absf(InputSource.shot_aim_axis(4.0) - 1.0) < 0.001, "aims/an out-of-range aim is clamped before the curve")


## The gate the simulation applies to whatever the flick asks for (question 3).
static func _alignment_gate(audit: AuditBase) -> void:
	var state := Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[0], 0, {})
	audit.check_eq(String(state.controlMode), "semi", "switch/a match created without a mode keeps the simulation's default, `semi`")

	var mate = state.paddle("playerMate")
	var active = state.paddle("player")
	var forward: float = 1.0 if float(mate.x) >= float(active.x) else -1.0
	var towards := {"x": forward, "y": 0.0}
	var opposed := {"x": -forward, "y": 0.0}

	var before := String(state.activePlayerKey)
	Sim.update_active_player(state, DT, false, opposed)
	audit.check_eq(String(state.activePlayerKey), before, "switch/a flick away from the partner does not switch (alignment under 0.2, `js/game.js:657`)")

	Sim.update_active_player(state, DT, false, towards)
	audit.check_ne(String(state.activePlayerKey), before, "switch/a flick towards the partner switches to him")
	audit.check_eq(float(state.manualSwitchFlash), 0.55, "switch/the switch flashes for the reference's 0.55 s (`js/game.js:664`)")

	var locked := String(state.activePlayerKey)
	state.serviceReceiverKey = "player"
	Sim.update_active_player(state, DT, false, towards)
	audit.check_eq(String(state.activePlayerKey), locked, "switch/while a service reception is locked a flick switches nobody (`js/game.js:645`)")
	Sim.update_active_player(state, DT, true, null)
	audit.check_eq(String(state.activePlayerKey), locked, "switch/the same lock refuses the button")

	state.serviceReceiverKey = null
	Sim.update_active_player(state, DT, true, null)
	audit.check_ne(String(state.activePlayerKey), locked, "switch/the button switches once the reception lock clears")


## The preference, and the validation around it (question 4).
static func _control_mode(audit: AuditBase) -> void:
	var previous: String = Config.save_dir
	Config.save_dir = "user://switch-mode-audit"
	var store = Config.save_store()

	var prefs: Dictionary = SaveSchema.PREFS_DEFAULTS.duplicate(true)
	prefs["controlMode"] = "manual"
	store.write_group("prefs", prefs)
	audit.check_eq(Config.control_mode(), "manual", "switch/the saved `manual` reaches the match (`js/main.js:1184`)")
	prefs["controlMode"] = "assisted"
	store.write_group("prefs", prefs)
	audit.check_eq(Config.control_mode(), "assisted", "switch/the saved `assisted` reaches the match")
	prefs["controlMode"] = "nonsense"
	store.write_group("prefs", prefs)
	audit.check_eq(Config.control_mode(), "semi", "switch/an unknown mode falls back to `semi` (`js/main.js:2273`)")

	var bare: Dictionary = SaveSchema.PREFS_DEFAULTS.duplicate(true)
	bare.erase("controlMode")
	store.write_group("prefs", bare)
	audit.check_eq(Config.control_mode(), "semi", "switch/an absent mode falls back to `semi`")

	Config.save_dir = previous


## Every action against the physical button its own help label names (question 5).
static func _pad_bindings(audit: AuditBase) -> void:
	for row in PAD_BINDINGS:
		var action: String = row[0]
		var wanted: int = row[1]
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == wanted:
				found = true
				break
		audit.check_true(found, "pad/%s is bound to %s (Godot's %d, not the browser's number)" % [action, row[2], wanted])

	# LT and RT are analog triggers, so their actions carry an axis
	# (`js/main.js:834-835`: `pad.buttons[6].value` and `[7].value`).
	for row in [["padel_split_step", JOY_AXIS_TRIGGER_LEFT, "LT"], ["padel_sprint", JOY_AXIS_TRIGGER_RIGHT, "RT"]]:
		var action: String = row[0]
		var axis: int = row[1]
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == axis:
				found = true
				break
		audit.check_true(found, "pad/%s carries %s as an analog axis (Godot's %d)" % [action, row[2], axis])

	# The defect this replaces, asserted as absent: none of these actions is on
	# Godot's `back` button, which is where the browser's LB number landed.
	for action in WAS_ON_BACK:
		var offenders: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK:
				offenders.append(action)
		audit.check_eq(offenders, [], "pad/%s is not on Godot's `back` button (the browser's LB number)" % action)


## The two samplers and the pad policy (question 6).
static func _devices(audit: AuditBase) -> void:
	var first := InputSource.new()
	var second := InputSource.new(false)
	audit.check_true(first.primary, "pads/the first sampler carries the keyboard")
	audit.check_true(not second.primary, "pads/the second sampler is pad only (`getInput2()`, `js/main.js:1096`)")
	audit.check_eq(int(first.device), InputSource.NO_DEVICE, "pads/no pad is selected before a frame asks for one")

	var state := Sim.create_match_state("quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[0], 0, {})
	var empty: Dictionary = Sim.empty_input()

	first.set_device(0)
	audit.check_eq(int(first.device), 0, "pads/set_device points the sampler at a pad")
	audit.check_true(
		not first.awaiting_release(),
		"pads/the first pad of the match does not swallow the first press (the browser picks its pad in the menu, `js/main.js:284`)",
	)

	# A pad that takes over DURING a match does hold its first press.
	first.set_device(1)
	audit.check_true(first.awaiting_release(), "pads/a pad that takes over mid-match holds its first press (`js/main.js:284`)")
	first.set_device(0)
	audit.check_true(first.awaiting_release(), "pads/and it holds it again when it takes over back")

	var during: Dictionary = first.sample(state)
	audit.check_true(not bool(during["hit"]), "pads/while the pad takes possession no hit is queued")
	audit.check_true(not bool(during["charging"]), "pads/while the pad takes possession no charge starts")
	audit.check_true(during["switchDirection"] == null, "pads/while the pad takes possession the stick switches nothing")
	audit.check_true(not first.awaiting_release(), "pads/with nothing held the possession ends on the next sample")

	# The at-rest equality is only meaningful while nothing is being held: with a hand
	# on the stick the sampler is reading real input, which is the point of it.
	if InputSource.device_has_activity(0):
		audit.note("pad 0 is being touched right now, so the at-rest equality check was skipped")
	else:
		audit.check_eq(first.sample(state), empty, "pads/a connected pad at rest samples as the empty input")
	audit.check_eq(
		InputSource.new().sample(state), empty,
		"pads/a sampler pointed at no device produces the empty input, field for field",
	)
	audit.check_eq(second.sample(state), empty, "pads/the second sampler fills the same %d fields with no pad" % empty.keys().size())

	# The policy must not invent a device. These checks are about the CODE, not about
	# what is plugged into this machine: an earlier version asserted "no controller
	# connected" and went red the moment the owner attached one, which is a false red
	# for a property of the desk rather than of the port.
	var connected := Input.get_connected_joypads()
	var chosen := InputSource.select_device(InputSource.NO_DEVICE)
	audit.check_true(
		chosen == InputSource.NO_DEVICE or connected.has(chosen),
		"pads/the chosen device is one the OS reports (connected=%s, chosen=%d)" % [str(connected), chosen],
	)
	var seats: Array = InputSource.assign_devices(false, InputSource.NO_DEVICE, InputSource.NO_DEVICE)
	audit.check_eq(seats.size(), 2, "pads/the policy answers for both seats")
	audit.check_true(
		int(seats[1]) == InputSource.NO_DEVICE or int(seats[1]) != int(seats[0]),
		"pads/the two seats never share one pad",
	)
	audit.check_true(
		InputSource.select_device(chosen, true) == chosen,
		"pads/keep_current keeps the pad it was given (`js/main.js:783`)",
	)
	audit.check_eq(InputSource.device_has_activity(InputSource.NO_DEVICE), false, "pads/no device never counts as activity")
	if connected.is_empty():
		audit.check_eq(chosen, InputSource.NO_DEVICE, "pads/with no controller connected no pad is selected")
	else:
		audit.note("a controller is connected on this machine (%s), so the no-pad fallback was not exercised: with no pads the policy answers %d" % [str(connected), InputSource.select_device(InputSource.NO_DEVICE)])

	audit.report("flick=%s release=%s deadzone=%s curves=%s/%s fields=%d devices=%d,%d" % [
		InputSource.SWITCH_FLICK, InputSource.SWITCH_RELEASE, InputSource.DEADZONE,
		InputSource.STICK_CURVE, InputSource.AIM_CURVE, empty.keys().size(),
		first.device, second.device,
	])


## The owner's request, kept (question 7). Two halves, because neither one alone would
## catch the failure: the SIMULATION has to keep moving a charging athlete (behaviour,
## through the real core), and the SAMPLER has to stop swallowing the stick's movement
## (source, because a headless engine enumerates no pads at all — the pad-driven charge
## cannot be sampled on this machine, and this repo has already measured what a
## "connected controller" check does on a desk that has one: `_devices` above refuses to
## assert anything about the desk for exactly that reason).
static func _charge_keeps_the_feet(audit: AuditBase) -> void:
	var free_state: Variant = _rally_state()
	var charge_state: Variant = _rally_state()
	var free_start: float = free_state.player.x
	var charge_start: float = charge_state.player.x
	for _i in 60:
		var free_tick: Dictionary = Sim.empty_input()
		free_tick["moveX"] = 1.0
		Sim.update_match(free_state, DT, free_tick)
		var charged_tick: Dictionary = Sim.empty_input()
		charged_tick["moveX"] = 1.0
		charged_tick["charging"] = true
		Sim.update_match(charge_state, DT, charged_tick)
	var free_travel: float = free_state.player.x - free_start
	var charged_travel: float = charge_state.player.x - charge_start
	audit.check_gt(
		charged_travel, 0.0,
		"charge/a charging tick still moves the athlete (the owner's request, a PORT ADDITION)",
	)
	audit.check_lt(
		charged_travel, free_travel,
		"charge/the charge still costs speed (`chargeMovement`, `js/game.js:3072`)",
	)
	audit.check_between(
		charged_travel / maxf(0.001, free_travel), 0.5, 0.62,
		"charge/and it costs the reference's own share, solo (0.58) — not co-op's 0.32",
	)
	audit.check_gt(
		float(charge_state.player.motion), 0.55,
		"charge/the run clip stays selected while charging (`athletes_view.gd` RUN_MOTION)",
	)

	# A line scan, not a substring one: the file's own comment on that line names the
	# assignment to explain its absence, so the test is the executable form alone —
	# a stripped line that IS the assignment.
	var text := FileAccess.get_file_as_string("res://game/input_map.gd")
	var freeze_lines := 0
	for line in text.split("\n"):
		if String(line).strip_edges() == "move = Vector2.ZERO":
			freeze_lines += 1
	audit.check_eq(
		freeze_lines, 0,
		"charge/the sampler does not freeze the athlete (`js/main.js:924` is deliberately not ported)",
	)
	audit.check_true(
		text.contains("PORT ADDITION"),
		"charge/and the deviation from the reference is written down where the next reader looks",
	)
	audit.report("travel charging=%.2fpx free=%.2fpx ratio=%.3f motion=%.2f" % [
		charged_travel, free_travel, charged_travel / maxf(0.001, free_travel),
		float(charge_state.player.motion),
	])


## A rally tick, not a serve: nothing human moves during a serve, so a probe that never
## serves measures the serve positioner instead (the recipe is
## `tests/audits/controller_tactics_audit.gd::state_at_contact`, `:114-132`).
static func _rally_state() -> Variant:
	var court: Dictionary = Frozen.court()
	var state: Variant = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1])
	state.running = true
	state.serving = false
	state.player.x = 480.0
	state.player.y = float(court["bottom"]) - 70.0
	state.player.hitCooldown = 0.0
	state.player.moveRatio = 0.0
	state.ball.x = 480.0
	state.ball.y = float(court["netY"]) - 130.0
	state.ball.z = 80.0
	state.ball.vx = 0.0
	state.ball.vy = -80.0
	state.ball.vz = 0.0
	state.ball.bounces = {"player": 0, "ai": 1}
	state.ball.serveInFlight = false
	return state
