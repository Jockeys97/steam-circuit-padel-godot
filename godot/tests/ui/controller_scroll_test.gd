## controller_scroll_test.gd — the right stick scrolls the real UI.
##
##   /opt/homebrew/bin/godot --headless --path godot/ \
##       --script res://tests/ui/controller_scroll_test.gd
##
## WHAT IT PROVES, and against which artefact:
##
##   1. THE HELPER'S OWN CONTRACT, on a fabricated tree: a held stick moves the offset
##      every frame (continuous, never one repeat step), the speed is proportional to
##      the deflection, the deadzone is inert, a released stick stops AND drops its
##      fraction, the offset clamps at both ends, and a sub-pixel frame accumulates
##      instead of vanishing.
##   2. THE HOST'S OWN FRAME, on the real `res://game/Main.tscn` with the real router:
##      the scene's `_process` — the same call the engine makes — moves the mounted
##      screen's own `ScrollContainer`, by exactly the helper's own offset. That last
##      equality is the "no double speed" check: the abstract offset
##      `menu_nav.gd::poll_pad` still accumulates has no consumer that paints, so the
##      helper's write is the only one, and a second application would show up here as
##      a doubled delta.
##   3. THE BOUNDARIES: a hidden surface scrolls nothing, a screen change resets the
##      helper, a controller disconnect resets it, a window focus loss resets it, and
##      the left stick still walks the focus without moving the page.
##   4. THE PLAYER'S OWN SCROLL IS NOT UNDONE: an offset written by anything else (the
##      wheel, a drag, `follow_focus`) is where the stick continues from, never a value
##      the helper snaps back to.
##   5. THE OTHER SCROLLABLE SCREEN: the result screen is not a special case — the
##      help screen's body scrolls by the same route.
##
## HARDWARE. This file makes no claim about a physical pad, in either direction: the
## engine's own `Input.get_connected_joypads()` list is printed for the record and
## physical interaction is untested. The axis is supplied through the helper's
## documented seam, the same shape `PauseOverlay` uses for its injected
## `InputEventJoypadMotion`, and the host's own `_process` is still the code under test
## — the axis is the only thing injected. Two facts that are often confused are kept
## apart in the boundaries section: an ABSENT seat (`set_device(-1)`, nothing to read)
## and a CONNECTED seat reading neutral (a real read that happens to be centred).
##
## ISOLATED SAVE. `Config.save_dir` is redirected before the host boots, so the walk
## never reads or writes the player's own profile.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Config := preload("res://game/match_config.gd")
const ControllerScroll := preload("res://src/ui/focus/controller_scroll.gd")
const HostScene := preload("res://game/Main.tscn")

const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 6
## One frame handed to the host's own `_process`. The engine's own delta in a headless
## run is tiny and varies; a named frame makes the arithmetic below exact.
const STEP := 0.05
## `controller_scroll.gd::SPEED_PX_PER_S` at full deflection: 900 px/s.
const SPEED := 900.0
const EXPECTED_PER_FRAME := SPEED * STEP

var _frame: Control
var _host: Control
## The synthetic axis the helper reads. This is the one injected value; everything else
## is the game's own code.
var _held := 0.0


func _initialize() -> void:
	Config.save_dir = "user://right-stick-scroll-test-%d" % Time.get_ticks_usec()
	var audit := AuditBase.new("controller_scroll")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	await _helper_contract(audit)
	await _nesting_and_modal(audit)
	await _host_wiring(audit)
	await _boundaries(audit)


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


## One frame through the host's own `_process`. Processing is switched off on the host
## when it mounts, so this is exactly one frame and not one plus the engine's.
func _step(delta: float = STEP) -> void:
	_host.call("_process", delta)
	await process_frame


# ---------------------------------------------------------------------------
# 1. The helper's own contract, on a fabricated tree
# ---------------------------------------------------------------------------

func _helper_contract(audit: AuditBase) -> void:
	var tree := _tall_scroll("SyntheticScroll", 2000.0, Vector2(400, 200))
	root.add_child(tree["frame"])
	await _frames(3)
	var container: ScrollContainer = tree["scroll"]
	var helper := ControllerScroll.new()
	helper.set_device(0)
	helper.set_surface(tree["frame"])
	helper.set_axis_source(func() -> float: return _held)
	var max_offset := _max_offset(container)
	audit.check_gt(max_offset, 100.0, "helper/the_fixture_really_overflows")

	# A held stick: every frame moves, and the total is the speed times the time. A
	# one-shot "repeat" would move once and then sit still.
	_held = 1.0
	var moved_frames := 0
	var total := 0.0
	var previous := 0.0
	for _i in 5:
		var report: Dictionary = helper.update(STEP)
		if bool(report["active"]) and float(report["applied"]) > 0.0:
			moved_frames += 1
		total += float(report["applied"])
		previous = float(report["offset"])
	audit.check_eq(moved_frames, 5, "helper/a_held_stick_moves_every_frame")
	audit.check_between(total, EXPECTED_PER_FRAME * 5.0 - 1.0, EXPECTED_PER_FRAME * 5.0 + 1.0,
		"helper/five_frames_move_speed_times_time")
	audit.check_between(previous, 0.0, float(max_offset) + 1.0, "helper/the_offset_stays_inside_the_range")
	audit.check_eq(container.scroll_vertical, int(round(previous)), "helper/the_control_carries_the_helper_offset")

	# Proportional: half deflection is not half the raw axis — it is the axis past the
	# deadzone, rescaled — but it must be strictly slower than full deflection.
	helper.reset()
	_held = 0.6
	var half: Dictionary = helper.update(STEP)
	var half_magnitude := (0.6 - ControllerScroll.DEADZONE) / (1.0 - ControllerScroll.DEADZONE)
	audit.check_between(float(half["applied"]), SPEED * half_magnitude * STEP - 0.5,
		SPEED * half_magnitude * STEP + 0.5, "helper/a_half_stick_is_proportionally_slower")
	audit.check_lt(float(half["applied"]), EXPECTED_PER_FRAME, "helper/and_slower_than_full_deflection")

	# The deadzone is the menu's own: a stick inside it is neutral, and it drops the
	# fraction so a released stick cannot coast.
	helper.reset()
	_held = ControllerScroll.DEADZONE - 0.05
	var dead: Dictionary = helper.update(STEP)
	audit.check_eq(bool(dead["active"]), false, "helper/inside_the_deadzone_nothing_moves")
	audit.check_eq(helper.offset(), 0.0, "helper/and_the_fraction_is_dropped")
	_held = 0.0
	helper.update(STEP)
	audit.check_eq(helper.offset(), 0.0, "helper/a_released_stick_stops_at_once")

	# The limits, both ways.
	helper.reset()
	_held = 1.0
	for _i in 40:
		helper.update(STEP)
	audit.check_eq(container.scroll_vertical, int(round(max_offset)), "helper/held_down_stops_at_the_bottom")
	audit.check_between(helper.offset(), max_offset - 0.5, max_offset + 0.5, "helper/and_the_offset_is_clamped")
	_held = -1.0
	for _i in 40:
		helper.update(STEP)
	audit.check_eq(container.scroll_vertical, 0, "helper/held_up_stops_at_the_top")

	# A frame shorter than a pixel: the fraction has to survive the int write.
	helper.reset()
	_held = 1.0
	var tiny := SPEED * 0.0005
	helper.update(0.0005)
	audit.check_between(helper.offset(), tiny - 0.01, tiny + 0.01, "helper/a_sub_pixel_frame_accumulates")
	audit.check_eq(container.scroll_vertical, 0, "helper/and_writes_no_whole_pixel_yet")
	for _i in 3:
		helper.update(0.0005)
	audit.check_ge(container.scroll_vertical, 1, "helper/and_the_fraction_reaches_a_pixel")

	# Somebody else moved the control: the stick continues from there.
	helper.reset()
	container.scroll_vertical = 40
	_held = 1.0
	var after_manual: Dictionary = helper.update(STEP)
	audit.check_between(float(after_manual["offset"]), 40.0 + EXPECTED_PER_FRAME - 1.0,
		40.0 + EXPECTED_PER_FRAME + 1.0, "helper/a_manual_scroll_is_where_the_stick_continues")

	# `reset()` is the host's stop: forget the container and the fraction.
	helper.reset()
	audit.check_eq(helper.container(), null, "helper/reset_forgets_the_container")
	audit.check_eq(helper.offset(), 0.0, "helper/reset_forgets_the_fraction")
	_held = 0.0
	tree["frame"].queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 2. The host's own frame, on the real scene and the real router
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# 1b. Nested panels and the modal boundary
# ---------------------------------------------------------------------------

## The two questions a nested tree asks, and the one a modal asks:
##
##   - a card that scrolls on its own owns the stick, not the body around it;
##   - a card that scrolls but has nothing to scroll gives the stick back to the body
##     around it (the "nearest must overflow, else the next one out" rule);
##   - a modal that is up owns the stick even when the FOCUS still names a control of
##     the screen underneath it — the background must not scroll.
##
## The last one is built with two separate trees on purpose: the focus is a real
## control of a real background surface, and the surface the helper is given is the
## modal. That is exactly the jukebox-over-the-result-screen shape.
func _nesting_and_modal(audit: AuditBase) -> void:
	var outer := _tall_scroll("OuterScroll", 2000.0, Vector2(400, 200))
	var nested := _nested_scroll(outer["body"], "NestedScroll", 800.0, 150.0)
	var deep_button := Button.new()
	deep_button.name = "DeepButton"
	nested["body"].add_child(deep_button)
	var shallow_button := Button.new()
	shallow_button.name = "ShallowButton"
	outer["body"].add_child(shallow_button)
	root.add_child(outer["frame"])
	await _frames(3)

	var helper := ControllerScroll.new()
	helper.set_device(0)
	helper.set_surface(outer["frame"])
	helper.set_axis_source(func() -> float: return 1.0)
	audit.check_gt(_max_offset(outer["scroll"]), 50.0, "nesting/the_outer_body_overflows")
	audit.check_gt(_max_offset(nested["scroll"]), 50.0, "nesting/the_nested_card_overflows")

	# A focus inside the nested card: the card owns the stick.
	helper.set_focus_source(func() -> Control: return deep_button)
	var nested_report: Dictionary = helper.update(STEP)
	audit.check_eq(nested_report["container"], nested["scroll"], "nesting/the_nested_card_owns_the_stick")

	# The same card with nothing to scroll: the body around it takes over.
	nested["body"].custom_minimum_size = Vector2(0.0, 60.0)
	await _frames(3)
	helper.reset()
	helper.set_focus_source(func() -> Control: return deep_button)
	var outer_report: Dictionary = helper.update(STEP)
	audit.check_eq(outer_report["container"], outer["scroll"],
		"nesting/a_card_with_nothing_to_scroll_gives_the_stick_back")

	# A modal owns the stick while the focus still names a control of the screen under
	# it. Two separate trees: the background really overflows, and it must not move.
	var background := _tall_scroll("BackgroundScroll", 2000.0, Vector2(400, 200))
	var background_button := Button.new()
	background_button.name = "BackgroundButton"
	background["body"].add_child(background_button)
	root.add_child(background["frame"])
	var modal := _tall_scroll("ModalScroll", 1200.0, Vector2(400, 200))
	root.add_child(modal["frame"])
	await _frames(3)
	helper.reset()
	helper.set_surface(modal["frame"])
	helper.set_focus_source(func() -> Control: return background_button)
	var modal_report: Dictionary = helper.update(STEP)
	audit.check_eq(modal_report["container"], modal["scroll"],
		"modal/the_modal_owns_the_stick_not_the_focus_owners_screen")
	audit.check_eq(background["scroll"].scroll_vertical, 0, "modal/the_background_did_not_scroll")

	# A modal with no scrollable content at all: the stick is inert, and the background
	# is still untouched — the fallback never leaves the surface.
	var bare := Control.new()
	bare.name = "BareModal"
	bare.size = Vector2(400, 200)
	root.add_child(bare)
	await _frames(3)
	helper.reset()
	helper.set_surface(bare)
	helper.set_focus_source(func() -> Control: return background_button)
	var bare_report: Dictionary = helper.update(STEP)
	audit.check_eq(bool(bare_report["active"]), false, "modal/a_modal_with_nothing_to_scroll_is_inert")
	audit.check_eq(background["scroll"].scroll_vertical, 0,
		"modal/and_the_background_still_did_not_scroll")

	outer["frame"].queue_free()
	background["frame"].queue_free()
	modal["frame"].queue_free()
	bare.queue_free()
	await process_frame

func _host_wiring(audit: AuditBase) -> void:
	_frame = Control.new()
	_frame.name = "ControllerScrollFrame"
	_frame.size = FRAME
	root.add_child(_frame)
	_host = HostScene.instantiate()
	_host.set("ui_prototype", true)
	_frame.add_child(_host)
	await _frames(SETTLE_FRAMES)
	# One clock, and it is this file's: every frame below is one explicit call.
	_host.set_process(false)
	# For the record, and NOT a hardware claim: the engine's own list is what it is, and
	# physical interaction is untested either way (see the file header).
	audit.report("engine joypad list: %s (physical interaction untested)" % [Input.get_connected_joypads()])

	var helper: RefCounted = _host.call("controller_scroll")
	audit.check_ne(helper, null, "host/the_scene_owns_a_scroll_helper")
	helper.call("set_axis_source", func() -> float: return _held)
	var router: Control = _host.call("ui_router")
	audit.check_eq(String(router.call("active_id")), "menu", "host/the_real_router_mounted_the_menu")

	# The result screen, with a full payload, on the real host.
	router.call("go_to", "result", _payload())
	await _settle(router)
	var screen: Node = router.call("active_screen")
	audit.check_eq(String(router.call("active_id")), "result", "host/the_result_screen_is_up")
	var container := await _overflowing_body(screen)
	audit.check_ne(container, null, "host/the_result_screen_has_a_scrolling_body")
	if container == null:
		return
	audit.check_gt(_max_offset(container), 50.0, "host/and_it_really_overflows")

	# One held stick, five frames, through the host's own `_process`.
	var before := container.scroll_vertical
	var room := _max_offset(container)
	audit.report("result overflow room: %.0f px" % room)
	_held = 1.0
	# Focus reveal may already have scrolled the screen on entry. Clamp the
	# expected travel to the remaining room, not the total content height.
	for _i in 3:
		await _step()
	var after := container.scroll_vertical
	audit.check_gt(after, before, "host/held_down_moves_the_real_screen")
	var expected := minf(EXPECTED_PER_FRAME * 3.0, room - before)
	audit.check_between(float(after - before), expected - 2.0,
		expected + 2.0, "host/and_by_speed_times_time_once")
	audit.check_eq(after, int(round(float(helper.call("offset")))),
		"host/the_control_carries_the_helpers_own_offset")
	var report: Dictionary = helper.call("last_report")
	audit.check_eq(report["container"], container, "host/the_report_names_the_container_it_drove")

	# Held past the end: the real screen clamps at its own last offset and stops there.
	for _i in 20:
		await _step()
	audit.check_between(container.scroll_vertical, int(room) - 1, int(room) + 1,
		"host/held_down_clamps_at_the_real_screens_end")

	# Up again, from where it stopped.
	var top := container.scroll_vertical
	_held = -1.0
	for _i in 2:
		await _step()
	audit.check_lt(container.scroll_vertical, top, "host/held_up_moves_back")

	# The player's own scroll is not undone: the wheel (or `follow_focus`) writes the
	# control between two frames, and the stick continues from there.
	_held = 0.0
	await _step()
	container.scroll_vertical = 30
	_held = 1.0
	await _step()
	audit.check_ge(container.scroll_vertical, 30 + int(EXPECTED_PER_FRAME) - 2,
		"host/a_manual_scroll_is_not_snapped_back")

	# The other scrollable screen: the help body, by the same route.
	_held = 0.0
	router.call("go_to", "help")
	await _settle(router)
	audit.check_eq(String(router.call("active_id")), "help", "host/the_help_screen_is_up")
	var help_screen: Node = router.call("active_screen")
	var help_container := await _overflowing_body(help_screen)
	audit.check_ne(help_container, null, "host/the_help_screen_has_a_scrolling_body")
	if help_container != null:
		audit.check_gt(_max_offset(help_container), 50.0, "host/and_it_really_overflows")
		var help_before := help_container.scroll_vertical
		var help_room := _max_offset(help_container)
		_held = 1.0
		for _i in 5:
			await _step()
		var help_expected := minf(EXPECTED_PER_FRAME * 5.0, help_room)
		audit.check_between(float(help_container.scroll_vertical - help_before),
			help_expected - 2.0, help_expected + 2.0,
			"host/the_help_body_moves_by_the_same_rule")
		_held = 0.0
		await _step()

	# The abstract model still accumulates its own offset, and it writes NO node: the
	# two cannot double up, because only the helper touches `scroll_vertical`.
	var settled := help_container.scroll_vertical
	_host.call("focus_model").call("step_pad", {
		"stick_x": 0.0, "stick_y": 0.0, "right_stick_y": 1.0,
		"buttons": {}, "now_ms": 1000.0,
	})
	audit.check_eq(help_container.scroll_vertical, settled,
		"host/the_abstract_model_scroll_paints_nothing")

	# The left stick still walks the focus, and it does not move the page.
	_held = 0.0
	await _step()
	# Return the controls below the header to view before moving down from Back.
	help_container.scroll_vertical = 0
	await _frames(2)
	var before_left := help_container.scroll_vertical
	var focus: RefCounted = _host.call("focus_model")
	var focus_before := String(focus.call("focus_id"))
	var verdict: Dictionary = focus.call("step_pad", {
		"stick_x": 0.0, "stick_y": 1.0, "right_stick_y": 0.0,
		"buttons": {}, "now_ms": 2000.0,
	})
	audit.check_true(bool(verdict.get("focus_moved", false)), "host/the_left_stick_still_moves_the_focus")
	audit.check_ne(String(focus.call("focus_id")), focus_before, "host/and_the_focus_really_moved")
	audit.check_eq(help_container.scroll_vertical, before_left, "host/the_left_stick_scrolls_nothing")


# ---------------------------------------------------------------------------
# 3. The boundaries
# ---------------------------------------------------------------------------

func _boundaries(audit: AuditBase) -> void:
	var helper: RefCounted = _host.call("controller_scroll")
	var router: Control = _host.call("ui_router")
	var container := await _overflowing_body(router.call("active_screen"))
	if container == null:
		audit.check_true(false, "boundaries/a_scrolling_body_is_up")
		return

	# A hidden surface: the screen is still mounted and the helper is still wired, and
	# nothing moves. This is the modal rule stated as a test — the screen behind an
	# overlay is inert without a second flag.
	var screen: Control = router.call("active_screen")
	var offset_before := container.scroll_vertical
	_held = 1.0
	await _step()
	audit.check_gt(container.scroll_vertical, offset_before, "boundaries/a_visible_surface_scrolls")
	screen.visible = false
	var hidden_before := container.scroll_vertical
	for _i in 3:
		await _step()
	audit.check_eq(container.scroll_vertical, hidden_before, "boundaries/a_hidden_surface_scrolls_nothing")
	audit.check_eq(bool((helper.call("last_report") as Dictionary)["active"]), false,
		"boundaries/and_the_helper_reports_itself_inert")
	screen.visible = true
	await _step()
	audit.check_gt(container.scroll_vertical, hidden_before, "boundaries/and_it_resumes_when_shown")

	# A screen change: the fraction belongs to the screen that left.
	router.call("go_to", "menu")
	await _settle(router)
	audit.check_eq(helper.call("container"), null, "boundaries/a_screen_change_resets_the_helper")
	audit.check_eq(helper.call("offset"), 0.0, "boundaries/and_drops_the_fraction")

	# A controller that goes away.
	router.call("go_to", "help")
	await _settle(router)
	var help_container := await _overflowing_body(router.call("active_screen"))
	if help_container != null:
		_held = 1.0
		await _step()
		audit.check_ne(helper.call("container"), null, "boundaries/the_stick_is_driving_a_container")
		_host.call("_on_joy_connection_changed", 0, false)
		audit.check_eq(helper.call("container"), null, "boundaries/a_disconnected_pad_stops_at_once")
		# The LATER frames, with the stick still held: a disconnect is not a pause the
		# next poll undoes.
		var disconnected_at := help_container.scroll_vertical
		for _i in 3:
			await _step()
		audit.check_eq(help_container.scroll_vertical, disconnected_at,
			"boundaries/a_held_stick_does_not_resume_after_a_disconnect")
		_held = 0.0
		await _step()
		audit.check_eq(bool(helper.call("is_suspended")), false,
			"boundaries/neutral_rearms_after_a_disconnect")

	# Losing the window: a stick left deflected while the window is in the background
	# must not resume the moment it comes back, and `reset()` alone would not stop it —
	# the very next frame reads the same deflected axis. So the frames AFTER the event
	# are the assertion.
	_held = 1.0
	await _step()
	audit.check_ne(helper.call("container"), null, "boundaries/the_stick_is_driving_again")
	_host.call("_on_window_focus_lost")
	audit.check_eq(helper.call("container"), null, "boundaries/losing_the_window_stops_at_once")
	audit.check_eq(bool(helper.call("is_suspended")), true, "boundaries/and_the_helper_is_suspended")
	var suspended_at := help_container.scroll_vertical
	_held = 0.0
	await _step()
	_held = 1.0
	await _step()
	audit.check_eq(help_container.scroll_vertical, suspended_at,
		"boundaries/neutral_then_push_in_background_stays_inert")
	_host.call("_on_scroll_window_focus_returned")
	for _i in 3:
		await _step()
	audit.check_eq(help_container.scroll_vertical, suspended_at,
		"boundaries/a_held_stick_does_not_resume_when_the_window_returns")
	audit.check_eq(helper.call("container"), null, "boundaries/and_no_container_is_taken")
	# Neutral rearms it, and the next push scrolls again.
	_held = 0.0
	await _step()
	audit.check_eq(bool(helper.call("is_suspended")), false, "boundaries/neutral_rearms_the_helper")
	_held = 1.0
	var rearmed_from := help_container.scroll_vertical
	await _step()
	audit.check_gt(help_container.scroll_vertical, rearmed_from,
		"boundaries/and_the_next_push_scrolls_again")

	# ABSENT SEAT vs NEUTRAL SEAT, stated as two different facts and asked of the helper
	# directly, because the host overwrites the seat from the engine's own list every
	# frame. The first is "there is nobody to read"; the second is "somebody is there and
	# the stick is centred". Only the first is what an unplugged pad means.
	_held = 0.0
	helper.call("set_axis_source", Callable())
	helper.call("set_focus_source", Callable())
	helper.call("set_surface", router.call("active_screen"))
	helper.call("set_device", -1)
	var absent_report: Dictionary = helper.call("update", STEP)
	audit.check_eq(bool(absent_report["active"]), false, "boundaries/an_absent_seat_is_inert")
	audit.check_eq(absent_report["axis"], 0.0, "boundaries/and_reads_as_centred")
	var neutral_before := help_container.scroll_vertical
	helper.call("set_device", 0)
	var neutral_report: Dictionary = helper.call("update", STEP)
	audit.check_eq(bool(neutral_report["active"]), false, "boundaries/a_connected_neutral_seat_is_inert")
	audit.check_eq(help_container.scroll_vertical, neutral_before,
		"boundaries/and_a_neutral_seat_scrolls_nothing")
	_frame.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# Fixtures and small helpers
# ---------------------------------------------------------------------------

## A Control frame holding one `ScrollContainer` whose body is `height` tall.
func _tall_scroll(node_name: String, height: float, size: Vector2) -> Dictionary:
	var frame := Control.new()
	frame.name = "SyntheticFrame"
	frame.size = size
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.custom_minimum_size = Vector2(0.0, height)
	scroll.add_child(body)
	var filler := Label.new()
	filler.text = "tall"
	body.add_child(filler)
	return {"frame": frame, "scroll": scroll, "body": body}


## A `ScrollContainer` nested inside another one's body, so a focus can sit in a card
## that scrolls on its own while the body around it scrolls too.
func _nested_scroll(parent: Control, node_name: String, body_height: float, view_height: float) -> Dictionary:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, view_height)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = node_name + "Body"
	body.custom_minimum_size = Vector2(0.0, body_height)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	return {"frame": parent, "scroll": scroll, "body": body}


## A constructed result, the shape the result screen's own `render()` reads. It is a
## fixture and is labelled as one: this file is about the scroll, not about a match.
func _payload() -> Dictionary:
	return {
		"result": {
			"score": "11-7",
			"won": true,
			"pointsToWin": 11,
			"player": 11,
			"ai": 7,
			"stats": {
				"pointsWon": {"player": 11, "ai": 7},
				"aces": {"player": 2, "ai": 1},
				"winners": {"player": 5, "ai": 3},
				"errors": {"player": 4, "ai": 6},
				"doubleFaults": {"player": 3, "ai": 1},
				"smashWinners": {"player": 1, "ai": 0},
				"rallyCount": 9,
				"totalRallyHits": 32,
				"longestRally": 7,
			},
		},
		"mode": "quick",
		"arena_id": String((Config.arena() as Dictionary).get("id", "")),
		"season": 1,
		"match": 1,
		"outcome": "",
		"tournament": {},
		"continue_pending": false,
	}


## Let a freshly mounted screen lay out: the containers sort at the end of the frame
## that built them, and the host re-measures two frames later.
func _settle(router: Control) -> void:
	await _frames(4)
	_host.call("_process", 0.0)
	await process_frame
	_host.call("_process", 0.0)
	await _frames(2)
	# The router's own answer, so a caller cannot settle a screen that is not up.
	if router.call("active_screen") == null:
		await _frames(2)


## The surface's primary body scroll, with the frame shrunk if the shipped 1280x720
## happens not to overflow for that screen. The shrink is reported by the caller's own
## `and_it_really_overflows` check, so a screen that never overflows cannot pass.
func _overflowing_body(surface: Node) -> ScrollContainer:
	for _attempt in 6:
		var found := _primary_scroll(surface)
		if found != null and _max_offset(found) > 50.0:
			return found
		_frame.size.y = maxf(320.0, _frame.size.y - 80.0)
		await _frames(3)
	return _primary_scroll(surface)


## The first visible, vertically-scrolling `ScrollContainer` under the surface, in tree
## order — the same rule the helper's own primary fallback uses.
func _primary_scroll(node: Node) -> ScrollContainer:
	for child in node.get_children():
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is ScrollContainer:
			var scroll := control as ScrollContainer
			if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				return scroll
		var found := _primary_scroll(child)
		if found != null:
			return found
	return null


static func _max_offset(container: ScrollContainer) -> float:
	var bar := container.get_v_scroll_bar()
	if bar == null:
		return 0.0
	return maxf(0.0, bar.max_value - bar.page)
