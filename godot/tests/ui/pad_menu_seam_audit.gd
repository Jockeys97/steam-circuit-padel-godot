## pad_menu_seam_audit.gd — the pad→menu seam (Lane 1 of `/tmp/padel-menu-nav/nav/REPORT.md`).
##
##   <godot> --headless --path godot/ --script res://tests/ui/pad_menu_seam_audit.gd
##
## What it asserts, defect by defect:
##   D1  the stick has ONE consumer: `MenuFocus.poll_pad()` (the mount's own per-frame call,
##       `game/main_menu.gd::_poll_pad`). A motion EVENT moves nothing and is swallowed, the
##       frame's poll moves once, and the reference's repeat cadence (400/150 ms) follows.
##   D2  the frame goes through the reference's menu deadzone 0.28 (`js/main.js:146`,
##       `gamepadAxis`) BEFORE the direction test, on all three axes.
##   D3  the D-pad reaches the model: Godot's 11..14 become the browser's 12..15.
##   D4  the pad index is resolved from the pads the system enumerates, not hard-coded to 0.
##
## The audit drives the PRODUCTION seam — `MenuFocus.poll_pad(values)` with the frame's pad
## values handed in — so no assertion depends on the pad physically connected to the machine
## running it (the REPORT's own hardware warning), and none is an assertion on a helper the
## production path might not use. The two source-shape checks at the end are the repo's own
## existing style (`scripts/gamepad-nav-audit.mjs` asserts `gamepadAxis` inside
## `pollGamepadMenu`): they only guard against a SECOND reader creeping back in.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")

const MENU_FOCUS_PATH := "res://game/menu_focus.gd"
const BRIDGE_PATH := "res://src/ui/focus/UiFocusBridge.gd"

## The live rectangles the REPORT recorded for the mounted menu (`screen-menu`).
const RECTS := [
	{"id": "menu/PlayButton", "action": "to-modes", "x": 64.0, "y": 480.0, "w": 139.0, "h": 52.0},
	{"id": "menu/DrillButton", "action": "to-drill", "x": 215.0, "y": 480.0, "w": 107.0, "h": 52.0},
	{"id": "menu/HelpButton", "action": "to-help", "x": 334.0, "y": 480.0, "w": 132.0, "h": 52.0},
	{"id": "menu/HistoryButton", "action": "to-history", "x": 478.0, "y": 480.0, "w": 134.0, "h": 52.0},
	{"id": "menu/ChallengesButton", "action": "to-challenges", "x": 64.0, "y": 544.0, "w": 121.0, "h": 41.0},
	{"id": "menu/FeedbackButton", "action": "to-feedback", "x": 197.0, "y": 544.0, "w": 146.0, "h": 41.0},
	{"id": "menu/ProfileButton", "action": "to-profile", "x": 1114.0, "y": 15.0, "w": 37.0, "h": 36.0},
	{"id": "menu/SettingsButton", "action": "to-settings", "x": 1159.0, "y": 15.0, "w": 37.0, "h": 36.0},
	{"id": "menu/LangToggle", "action": "lang", "x": 1204.0, "y": 15.0, "w": 44.0, "h": 36.0},
]

## A full right sweep from the first focus: six steps, then nothing to the right of the last.
## The instants are the reference's own (`pollGamepadMenu`): the first frame moves, then every
## 400 ms at first and every 150 ms after.
const RIGHT_SWEEP := ["menu/DrillButton", "menu/HelpButton", "menu/HistoryButton",
	"menu/ProfileButton", "menu/SettingsButton", "menu/LangToggle"]
const RIGHT_SWEEP_AT := [1000, 1400, 1550, 1700, 1850, 2000]
const FRAME_MS := 50.0
const FRAMES := 60
const T0 := 1000.0

var _shell: Control
var _buttons: Array = []


func _initialize() -> void:
	var audit := AuditBase.new("pad_menu_seam")
	await process_frame          # the root window is not in the tree at `_initialize()` yet
	_build()
	_deadzone(audit)
	_one_consumer(audit)
	_dpad(audit)
	_pad_index(audit)
	_range_from_the_stick(audit)
	_reader_count(audit)
	audit.report("seam: the stick's only consumer is poll_pad(), the frame is built by pad_frame()")
	quit(audit.finish())


func _build() -> void:
	_shell = Control.new()
	_shell.name = "SeamShell"
	_shell.size = Vector2(1280.0, 720.0)
	root.add_child(_shell)
	for row in RECTS:
		var button := Button.new()
		button.text = String(row["id"])
		_shell.add_child(button)
		button.position = Vector2(float(row["x"]), float(row["y"]))
		button.set_size(Vector2(float(row["w"]), float(row["h"])))
		_buttons.append(button)


func _model() -> RefCounted:
	var focus: RefCounted = MenuFocus.new()
	for i in RECTS.size():
		focus.add(String(RECTS[i]["id"]), _buttons[i], String(RECTS[i]["action"]))
	focus.refresh()
	return focus


## One frame through the production seam. Returns the model's own result dictionary.
func _frame(focus: RefCounted, values: Dictionary, now_ms: float) -> Dictionary:
	var frame: Dictionary = values.duplicate()
	frame["now_ms"] = now_ms
	return focus.poll_pad(frame)


## The focus changes a held frame produces, as `["<ms>-><id>"]`, plus the raw instants.
func _drive(focus: RefCounted, values: Dictionary, ticks: int) -> Array:
	var moves: Array = []
	var seen: String = focus.focus_id()
	for i in ticks:
		var now := T0 + float(i) * FRAME_MS
		_frame(focus, values, now)
		if focus.focus_id() != seen:
			moves.append({"ms": int(now), "id": focus.focus_id()})
			seen = focus.focus_id()
	return moves


func _ids(moves: Array) -> Array:
	var out: Array = []
	for move in moves:
		out.append(String((move as Dictionary)["id"]))
	return out


func _instants(moves: Array) -> Array:
	var out: Array = []
	for move in moves:
		out.append(int((move as Dictionary)["ms"]))
	return out


# ---------------------------------------------------------------------------
# D2 — the menu deadzone, on the production path
# ---------------------------------------------------------------------------

func _deadzone(audit: AuditBase) -> void:
	# A stick under 0.28 is neutral: the reference's `gamepadAxis` zeroes it before the
	# direction test, so it moves nothing however long it is held.
	for under in [0.20, 0.27, 0.279]:
		var focus := _model()
		var moves := _drive(focus, {"lx": float(under)}, FRAMES)
		audit.check_eq(moves.size(), 0, "seam/a_stick_at_%.3f_is_neutral" % float(under))
	audit.check_eq(_drive(_model(), {"ly": -0.27}, FRAMES).size(), 0, "seam/a_stick_at_-0.27_up_is_neutral")
	var right := _model()
	audit.check_eq(_drive(right, {"ry": 0.27}, FRAMES).size(), 0, "seam/the_right_stick_at_0.27_does_not_scroll")
	audit.check_eq(right.menu.nav.page_scroll(), 0.0, "seam/the_right_stick_under_the_deadzone_scrolls_nothing")

	# At the threshold and above it, the reference's own behaviour, to the millisecond.
	var focus := _model()
	var sweep := _drive(focus, {"lx": 0.90}, FRAMES)
	audit.check_eq(_ids(sweep), RIGHT_SWEEP, "seam/a_full_right_sweep_visits_the_reference_sequence")
	audit.check_eq(_instants(sweep), RIGHT_SWEEP_AT, "seam/the_sweep_moves_at_the_reference_instants")
	audit.check_eq(sweep.size(), 6, "seam/a_full_right_sweep_moves_six_times")
	var at_threshold := _model()
	audit.check_eq(_drive(at_threshold, {"lx": 0.28}, FRAMES).size(), 6, "seam/a_stick_exactly_at_the_threshold_moves")
	audit.check_eq(MenuFocus.menu_deadzone(0.279), 0.0, "seam/the_deadzone_helper_zeroes_0.279")
	audit.check_eq(MenuFocus.menu_deadzone(0.28), 0.28, "seam/the_deadzone_helper_keeps_the_threshold")
	# No drift: a sub-threshold stick never adds a step to a real sweep.
	var drift := _model()
	_drive(drift, {"lx": 0.90}, 23)                       # 1000..2100: the sweep, then the right edge
	var held: String = drift.focus_id()
	_drive(drift, {"lx": -0.22}, 12)                      # the release, with a worn stick's drift
	audit.check_eq(drift.focus_id(), held, "seam/a_released_stick_never_walks_the_focus_back")


# ---------------------------------------------------------------------------
# D1 — one consumer for the stick
# ---------------------------------------------------------------------------

func _one_consumer(audit: AuditBase) -> void:
	var focus := _model()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(null, focus)
	var start: String = focus.focus_id()
	var swallowed := true
	for value in [0.18, 0.36, 0.54, 0.72, 0.90]:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_X
		event.axis_value = float(value)
		if not bridge.dispatch(event):
			swallowed = false
	audit.check_true(swallowed, "seam/a_motion_event_is_handled_and_swallowed")
	audit.check_eq(focus.focus_id(), start, "seam/five_axis_events_move_the_focus_not_once")

	# The same push through the frame that owns it: one move, then the reference's silence.
	var polled := _frame(focus, {"lx": 0.90}, T0)
	audit.check_true(bool(polled.get("focus_moved", false)), "seam/the_frames_poll_moves_the_focus")
	audit.check_eq(focus.focus_id(), "menu/DrillButton", "seam/the_frames_poll_moves_one_step")
	var quiet := 0
	for i in 7:                                            # 1050..1350: inside the 400 ms
		var before: String = focus.focus_id()
		_frame(focus, {"lx": 0.90}, 1050.0 + float(i) * FRAME_MS)
		if focus.focus_id() != before:
			quiet += 1
	audit.check_eq(quiet, 0, "seam/a_held_stick_is_silent_until_the_first_repeat")
	var repeated := 0
	for i in 20:                                           # 1400..: the 150 ms cadence
		var before: String = focus.focus_id()
		_frame(focus, {"lx": 0.90}, 1400.0 + float(i) * FRAME_MS)
		if focus.focus_id() != before:
			repeated += 1
	audit.check_eq(repeated, 5, "seam/the_repeat_cadence_still_walks_the_row")

	# The keyboard branch is NOT the stick's: it must stay as it was.
	var keys := _model()
	var key_bridge: RefCounted = Bridge.new()
	key_bridge.attach(null, keys)
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	audit.check_true(key_bridge.dispatch(down), "seam/an_arrow_key_is_still_handled")
	audit.check_eq(keys.focus_id(), "menu/ChallengesButton", "seam/an_arrow_key_still_moves_one_step")
	keys.menu.nav.set_focus("menu/ChallengesButton")
	var edge_start: float = keys.menu.nav.page_scroll()
	var second := InputEventKey.new()
	second.keycode = KEY_DOWN
	second.pressed = true
	key_bridge.dispatch(second)
	audit.check_eq(keys.menu.nav.page_scroll() - edge_start, 90.0, "seam/an_arrow_key_at_the_edge_still_scrolls_90")

	# The same edge with the stick: the five events must not scroll, the frame's poll scrolls once.
	var edge := _model()
	edge.menu.nav.set_focus("menu/ChallengesButton")
	var stick_bridge: RefCounted = Bridge.new()
	stick_bridge.attach(null, edge)
	var stick_start: float = edge.menu.nav.page_scroll()
	for value in [0.55, 0.62, 0.70, 0.80, 0.90]:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_Y
		event.axis_value = float(value)
		stick_bridge.dispatch(event)
	audit.check_eq(edge.menu.nav.page_scroll() - stick_start, 0.0, "seam/five_stick_events_scroll_nothing")
	_frame(edge, {"ly": 0.90}, T0)
	audit.check_eq(edge.menu.nav.page_scroll() - stick_start, 15.0, "seam/the_frames_poll_scrolls_the_reference_fifteen")
	var polled_real := _model()
	polled_real.menu.nav.set_focus("menu/ChallengesButton")
	var real_start: float = polled_real.menu.nav.page_scroll()
	_frame(polled_real, {"ly": 0.90}, T0)
	audit.check_eq(edge.menu.nav.page_scroll() - stick_start, polled_real.menu.nav.page_scroll() - real_start,
		"seam/the_polled_scroll_is_the_same_with_or_without_the_events")


# ---------------------------------------------------------------------------
# D3 — the D-pad
# ---------------------------------------------------------------------------

func _dpad(audit: AuditBase) -> void:
	audit.check_eq(MenuFocus.dpad_order(), [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT],
		"seam/the_dpad_order_is_godots_own")
	audit.check_eq(MenuFocus.dpad_order(), [11, 12, 13, 14], "seam/godots_dpad_numbers_are_11_to_14")
	audit.check_eq(MenuFocus.letter_order(), [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X], "seam/the_letters_are_a_b_x")
	var frame: Dictionary = MenuFocus.pad_frame({"dpad": [false, true, false, false]})
	audit.check_eq(String(MenuNav.direction(frame)), "down", "seam/a_godot_dpad_down_reads_as_the_models_down")
	var left: Dictionary = MenuFocus.pad_frame({"dpad": [false, false, true, false]})
	audit.check_eq(String(MenuNav.direction(left)), "left", "seam/a_godot_dpad_left_reads_as_the_models_left")
	var letters: Dictionary = MenuFocus.pad_frame({"letters": [true, false, false]})
	audit.check_true(bool((letters["buttons"] as Dictionary).get("0", false)), "seam/the_a_button_is_the_models_zero")

	# Through the production frame: a D-pad down moves, with no stick at all.
	var dpmap := _model()
	var moves := _drive(dpmap, {"dpad": [false, true, false, false]}, 12)
	audit.check_eq(_ids(moves), ["menu/ChallengesButton"], "seam/a_dpad_down_moves_the_focus")
	audit.check_eq(_instants(moves), [1000], "seam/a_held_dpad_moves_once_then_repeats")
	# A held D-pad walks once and then, with nowhere below, scrolls on every frame — the
	# reference's own continuous edge scroll (`js/main.js:966-969`), not a repeat step.
	var hold := _model()
	audit.check_eq(_ids(_drive(hold, {"dpad": [false, true, false, false]}, FRAMES)), ["menu/ChallengesButton"],
		"seam/a_held_dpad_walks_once")
	audit.check_eq(hold.menu.nav.page_scroll(), 15.0 * float(FRAMES - 1),
		"seam/a_held_dpad_scrolls_the_edge_every_frame")
	# A D-pad event is not a direction source of its own: the frame's poll owns it, so the
	# event must not move the focus twice.
	var event_model := _model()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(null, event_model)
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_DPAD_DOWN
	event.pressed = true
	bridge.dispatch(event)
	audit.check_eq(event_model.focus_id(), "menu/PlayButton", "seam/a_dpad_event_does_not_move_the_focus_by_itself")
	# Confirm and cancel still arrive, and their edges still latch.
	var edges := _model()
	audit.check_true(bool(_frame(edges, {"letters": [true, false, false]}, 1000.0).get("confirm", false)),
		"seam/the_confirm_edge_fires_once")
	audit.check_true(not bool(_frame(edges, {"letters": [true, false, false]}, 1050.0).get("confirm", false)),
		"seam/the_confirm_edge_does_not_repeat_while_held")
	audit.check_true(bool(_frame(edges, {"letters": [false, true, false]}, 1100.0).get("back", false)),
		"seam/the_b_button_still_means_back")


# ---------------------------------------------------------------------------
# D4 — the pad's index
# ---------------------------------------------------------------------------

func _pad_index(audit: AuditBase) -> void:
	audit.check_eq(MenuFocus.resolve_pad_index([]), -1, "seam/no_pad_resolves_to_minus_one")
	audit.check_eq(MenuFocus.resolve_pad_index([2]), 2, "seam/a_pad_the_system_numbers_two_is_used")
	audit.check_eq(MenuFocus.resolve_pad_index([3, 5]), 3, "seam/the_first_enumerated_pad_is_used")
	var live: Dictionary = _model().read_pad_values()
	audit.check_true(live.has("pad") and live.has("dpad") and live.has("letters"),
		"seam/the_live_reader_answers_the_frames_shape")
	audit.note("D4: the index is proven as a rule; a second physical pad is not available on this host, so no two-pad run is claimed")


# ---------------------------------------------------------------------------
# The stick on a range row (found while rewriting `input_a11y_audit`'s motion block)
# ---------------------------------------------------------------------------

## A stick step happens INSIDE the model (`focus_nav.gd::_adjust_range`), before the bridge
## sees the verdict, so `act()` must read the step before it carries the registry's value back
## over the live target — otherwise the stick moves a slider that the screen never hears about.
func _range_from_the_stick(audit: AuditBase) -> void:
	var slider := VSlider.new()
	slider.name = "SeamRange"
	_shell.add_child(slider)
	slider.position = Vector2(20.0, 20.0)
	slider.set_size(Vector2(48.0, 160.0))
	var focus := _model()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(null, focus)
	bridge.register("seam/Range", slider, "", {"kind": "range", "min": 0.0, "max": 1.0, "step": 0.25, "value": 0.5})
	var reported: Array = []
	bridge.connect("range_changed", func(id: String, value: float) -> void:
		reported.append(value))
	audit.check_true(bridge.set_focus("seam/Range"), "seam/the_range_takes_the_focus")
	var verdict: Dictionary = _frame(focus, {"lx": 0.90}, T0)
	audit.check_true(bool(verdict.get("focus_moved", false)), "seam/the_stick_steps_the_range_it_is_focused_on")
	audit.check_eq(bridge.act(verdict), true, "seam/the_polled_verdict_is_acted_on")
	audit.check_eq(reported, [0.75], "seam/the_stick_step_reaches_the_screen")
	audit.check_eq(float(bridge.last_range().get("value", 0.0)), 0.75, "seam/the_stick_step_is_the_reported_one")


# ---------------------------------------------------------------------------
# The two source-shape checks (the repo's own existing style)
# ---------------------------------------------------------------------------

func _reader_count(audit: AuditBase) -> void:
	var menu := _read(MENU_FOCUS_PATH)
	audit.check_eq(menu.count("Input.get_joy_axis("), 3, "seam/the_pad_is_read_for_three_axes_in_one_place")
	audit.check_eq(menu.count("Input.is_joy_button_pressed("), 2, "seam/the_pad_buttons_are_read_in_one_place")
	audit.check_true(_body(menu, "func poll_pad").find("pad_frame(") != -1, "seam/the_poll_builds_its_frame_with_pad_frame")
	audit.check_true(_body(menu, "func poll_pad").find("Input.get_joy_axis") == -1, "seam/the_poll_reads_no_axis_itself")
	var bridge := _read(BRIDGE_PATH)
	audit.check_true(bridge.find("STICK_THRESHOLD") == -1, "seam/the_bridge_carries_no_stick_threshold")
	audit.check_true(bridge.find("_stick_direction") == -1, "seam/the_bridge_carries_no_stick_consumer")
	audit.check_true(bridge.find("keyboard_direction") == -1, "seam/the_bridge_never_moves_the_focus_from_a_stick_value")


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## One function's own text, from its `func` line to the next one.
func _body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start == -1:
		return ""
	var rest := source.substr(start + signature.length())
	var end := rest.find("\nfunc ")
	return rest if end == -1 else rest.substr(0, end)
