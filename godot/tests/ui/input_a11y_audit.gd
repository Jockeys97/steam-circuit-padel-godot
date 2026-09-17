## input_a11y_audit.gd — UIR-05's audit: the router's screens on the port's input model.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/input_a11y_audit.gd
##
## WHAT IT ASSERTS, and what it deliberately does not
##
##   1. Graph reachability: every one of the router's thirteen screens is reachable from
##      the root by walking the router's *own* table (`Router.back_target_of`). The
##      declared edges are returns, so the walk runs in reverse — from the root, a screen
##      is reachable when its chain of returns leads home. Nothing else is consulted; a
##      screen the walk cannot reach is a discovery failure, not a rendering one.
##   2. Registration: the shell's controls reach `MenuFocus` with the shell's own ids
##      (`<screen_id>/back`), no duplicates, and re-registering an id replaces it.
##   3. Locked controls: registered, reported (`locked_ids()`), never focused (the
##      model's own filter), never activated — including the case the model cannot be
##      asked about directly (a control that takes the focus and is locked afterwards).
##   4. Back: a dispatch on a non-root screen navigates to the shell's declared target,
##      proved through the router's own `screen_changed` signal; on the root it
##      navigates nowhere, which is the reference audit's own rule
##      (`scripts/gamepad-nav-audit.mjs:67-82`).
##   5. Motion policy: `UiMotionPolicy` mirrors `AccessibilitySettings`, and toggling
##      flips every answer it gives.
##   6. The keyboard model: with a pad connected, confirming a text field opens `osk.gd`
##      for that field and back closes it. The field is this audit's own probe, not a
##      real screen's.
##   7. The carried metadata (added 2026-09-17, wave 3): the range keys
##      (`min`/`max`/`step`/`value`) and the OSK keys (`value`/`max_length`/`field_label`)
##      that `focus_nav.gd::_adjust_range` and `menu_nav.gd::confirm()` read but the
##      focus model cannot hold are carried by `UiFocusBridge` from a registration to the
##      live target the input lane consumes — proved by stepping a probe range with both
##      a key and a pad motion, and by opening the OSK on a seeded probe field.
##
## WHAT IT DOES NOT DO: it does not re-assert geometry or key repeat — those are
## `godot/tests/input/**` (4/4, 308 checks) and this audit is not a second suite for
## them. It asserts the *final focused id*, never intermediate steps (the ticket's own
## instruction about engine key-repeat semantics).
##
## Constructed state, labeled: the shell, the router, the four probe controls and the
## probe text field are built by this audit inside a 1280x720 frame and freed at the
## end. No real screen, no `user://` state and no game scene is touched.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MotionPolicy := preload("res://src/ui/accessibility/UiMotionPolicy.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const FocusNav := preload("res://src/input/focus_nav.gd")
const AccessibilitySettings := preload("res://src/accessibility/accessibility_settings.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")

const FRAME_SIZE := Vector2(1280.0, 720.0)
## The two screens no declared edge reaches: they are entered by the match flow —
## starting a match, finishing one — not by a menu action, and they declare no return
## (`game` is the field, `result` the scoreboard; UIR-03's audit pins the three
## backless ids: menu, game, result). Recorded here rather than smoothed over: the
## graph walk proves the other eleven, and this list is the named remainder.
const FLOW_ENTERED := ["game", "result"]
## What the reference has and this port does not, named rather than implied.
const NOT_PORTED := [
	{
		"name": "osk_visual_grid",
		"why": "the keyboard model opens, shifts, types and closes (osk.gd) but nothing draws its rows: the drawn grid is the postponed platform decision (UIR-26), so a pad-only player can open the keyboard and not see it",
	},
	{
		"name": "touch_input",
		"why": "no touch bindings exist in scheme.gd; the reference's touch paths (js/main.js:430-542) have no port side to exercise without a touch device",
	},
	{
		"name": "ime_text_entry",
		"why": "typing goes through the OSK model or the engine's own text controls; composing input for the languages the locale seam carries is not wired into the shell",
	},
	{
		"name": "key_repeat_events",
		"why": "the bridge hands one event to MenuFocus.handle_key; repeat lives in menu_nav.gd's repeat_state for the pad and in the engine for keys, so the audit asserts the final focused id instead of per-step movement",
	},
]


func _initialize() -> void:
	var audit := AuditBase.new("input_a11y")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_graph(audit)
	_motion(audit)
	await _frame(audit)
	for item in NOT_PORTED:
		audit.not_ported(String(item["name"]), String(item["why"]))
	audit.note("constructed state: the router, the shell, the four probe controls and the probe text field below are built by this audit in a 1280x720 frame and freed at the end; no real screen and no user:// state is touched")
	audit.note("the bridge does not re-state focus or lock rules: `focus_nav.gd::_selectable` owns them (`godot/tests/input/**` asserts the model), so a locked control is asserted here as *registered, reported, unfocusable, inert*, which is what a screen can act on")
	audit.report("not-ported=%d" % NOT_PORTED.size())
	print("# totals checks=%d failures=%d not-ported=%d" % [audit.checks, audit.failures, audit.not_ported_count])


# ---------------------------------------------------------------------------
# 1. The router's own table is a reachable graph
# ---------------------------------------------------------------------------

func _graph(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), 13, "a11y/the_router_inventory_is_the_thirteen_screens")
	audit.check_true(ids.has(Router.ROOT_ID), "a11y/the_root_is_one_of_them")

	# Two edge kinds, both read from the router's own table: the forward actions a screen
	# declares (`Router.to_actions_of` -> the reference's `data-action` table) and the
	# declared returns (`Router.back_target_of`), which point home and are therefore
	# walked in reverse. Nothing else is consulted, and the walk is breadth-first.
	var forward := {}
	var forward_edges := 0
	var bad_edges: Array = []
	for id in ids:
		var outs: Array = []
		for action in Router.to_actions_of(String(id)):
			var target := Router.id_of_dom(NavRoutes.screen_of_action(String(action)))
			if target == "" or not ids.has(target):
				bad_edges.append("%s -%s-> %s" % [id, String(action), target])
				continue
			forward_edges += 1
			outs.append(target)
		forward[String(id)] = outs
	audit.check_eq(bad_edges, [], "a11y/every_declared_forward_action_names_a_registered_screen")

	var inbound := {}
	var return_edges := 0
	for id in ids:
		var target := Router.back_target_of(String(id))
		if target == "":
			continue
		return_edges += 1
		if not inbound.has(target):
			inbound[target] = []
		inbound[target].append(String(id))
	var bad_returns: Array = []
	for id in ids:
		var back := Router.back_target_of(String(id))
		if back != "" and not ids.has(back):
			bad_returns.append("%s->%s" % [id, back])
	audit.check_eq(bad_returns, [], "a11y/every_declared_return_names_a_registered_screen")
	audit.check_eq(return_edges, 10, "a11y/ten_screens_declare_a_return")

	var seen := {Router.ROOT_ID: true}
	var queue: Array = [Router.ROOT_ID]
	while queue.size() > 0:
		var current: String = queue.pop_front()
		var next_out: Array = forward.get(current, [])
		var next_in: Array = inbound.get(current, [])
		for target in next_out + next_in:
			if not seen.has(String(target)):
				seen[String(target)] = true
				queue.append(String(target))
	var unreachable: Array = []
	for id in ids:
		if not seen.has(String(id)):
			unreachable.append(String(id))
	audit.check_eq(unreachable, FLOW_ENTERED, "a11y/the_only_screens_no_declared_edge_reaches_are_the_two_the_match_flow_enters")
	audit.check_eq(seen.size(), ids.size() - FLOW_ENTERED.size(), "a11y/eleven_screens_are_reachable_by_declared_edges")
	for id in FLOW_ENTERED:
		audit.check_eq(Router.back_target_of(String(id)), "", "a11y/the_%s_screen_declares_no_return" % id)
		audit.check_eq(_sources_of(forward, inbound, String(id)), [], "a11y/no_declared_edge_enters_%s" % id)
	audit.report("graph: %d screens, %d reachable by declared edges, %d forward edges, %d returns, flow-entered=%s" % [
		ids.size(), seen.size(), forward_edges, return_edges, str(FLOW_ENTERED)])


# ---------------------------------------------------------------------------
# 2. The motion policy mirrors the accessibility settings
# ---------------------------------------------------------------------------

func _motion(audit: AuditBase) -> void:
	var settings := AccessibilitySettings.new()
	var policy := MotionPolicy.new(settings)
	audit.check_eq(policy.reduced_motion(), false, "a11y/the_default_policy_allows_motion")
	audit.check_eq(policy.motion_allowed(), true, "a11y/the_default_policy_says_yes")
	audit.check_eq(policy.duration(0.4), 0.4, "a11y/a_duration_passes_through_untouched")
	audit.check_eq(policy.shake(1.0), 1.0, "a11y/an_uncapped_shake_passes_through")
	audit.check_eq(policy.particle_count(40), 40, "a11y/a_particle_count_passes_through")
	audit.check_eq(policy.settings() == settings, true, "a11y/the_policy_reads_the_object_it_was_given")

	audit.check_eq(settings.set_enabled(AccessibilitySettings.REDUCE_MOTION, true), true, "a11y/the_reduce_motion_setting_exists")
	audit.check_eq(policy.reduced_motion(), true, "a11y/the_policy_mirrors_reduce_motion")
	audit.check_eq(policy.motion_allowed(), false, "a11y/reduced_motion_says_no_to_motion")
	audit.check_eq(policy.duration(0.4), 0.0, "a11y/reduced_motion_removes_a_ui_animation")
	audit.check_eq(policy.shake(1.0), AccessibilitySettings.SHAKE_CAP, "a11y/reduced_motion_caps_the_shake_the_reference_caps")
	audit.check_eq(policy.particle_count(40), 14, "a11y/reduced_motion_scales_particles_by_the_reference_figure")
	audit.check_eq(policy.particle_count(2), AccessibilitySettings.PARTICLE_FLOOR, "a11y/the_particle_floor_holds")

	audit.check_eq(settings.set_enabled(AccessibilitySettings.REDUCE_MOTION, false), true, "a11y/the_setting_toggles_back")
	audit.check_eq(policy.reduced_motion(), false, "a11y/toggling_flips_the_policy")
	audit.check_eq(policy.duration(0.4), 0.4, "a11y/motion_returns_when_the_setting_does")

	audit.check_eq(settings.set_enabled(AccessibilitySettings.COLORBLIND, true), true, "a11y/the_colorblind_setting_exists")
	audit.check_eq(policy.colorblind(), true, "a11y/the_policy_mirrors_colorblind")

	policy.apply_prefs({"reduceMotion": true})
	audit.check_eq(policy.reduced_motion(), true, "a11y/prefs_applied_through_the_policy_reach_the_same_settings")
	audit.check_eq(settings.is_reduced_motion(), true, "a11y/the_settings_object_shows_the_same_value")
	audit.check_eq(policy.colorblind(), true, "a11y/applying_prefs_does_not_disturb_another_setting")
	policy.apply_prefs({"reduceMotion": false, "colorblind": false})
	audit.check_eq(policy.reduced_motion(), false, "a11y/prefs_can_turn_the_setting_off_again")


# ---------------------------------------------------------------------------
# 3. The live frame: registration, lock, back, the keyboard
# ---------------------------------------------------------------------------

func _frame(audit: AuditBase) -> void:
	var frame := Control.new()
	frame.name = "InputA11yFrame"
	frame.size = FRAME_SIZE
	root.add_child(frame)
	var router: Control = Router.new()
	router.name = "Router"
	frame.add_child(router)
	for id in Router.ids():
		router.register(String(id), PlaceholderScene)
	var transitions: Array = []
	# The counter rides in a one-element array because a lambda captures its locals by
	# value: `observed[0]` is the total over the whole run, while `transitions` is the
	# per-step window each section clears.
	var observed := [0]
	router.screen_changed.connect(func(from_id: String, to_id: String) -> void:
		transitions.append([from_id, to_id])
		observed[0] = int(observed[0]) + 1)
	router.go_to("modes")
	await process_frame
	await process_frame

	var screen: Node = router.active_screen()
	var shell: Control = screen.get("shell")
	audit.check_true(shell != null, "a11y/the_active_screen_exposes_its_shell")
	audit.check_eq(String(shell.get("screen_id")), "modes", "a11y/the_shell_knows_the_screen_it_is")

	var focus: MenuFocus = MenuFocus.new(Router.dom_id_of("modes"))
	var bridge := Bridge.new()
	bridge.attach(shell, focus, router)
	await process_frame

	_registration(audit, bridge, focus, shell)
	_probes(audit, bridge, focus, shell)
	await process_frame
	_discoverability(audit, bridge, focus)
	_direction(audit, bridge, focus)
	await _activation(audit, bridge, focus, router, transitions)
	await _forward(audit, bridge, focus, router, transitions)
	await _back(audit, bridge, focus, router, transitions)
	await _root(audit, bridge, focus, router, transitions)
	await _keyboard(audit, bridge, focus, router)
	await _metadata(audit, bridge, focus, router)
	root.remove_child(frame)
	frame.free()
	audit.report("transitions observed by the routers own signal: %d" % int(observed[0]))


func _registration(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, shell: Control) -> void:
	audit.check_eq(bridge.ids(), [shell.back_control_id()], "a11y/attaching_registers_the_shells_back_control")
	audit.check_eq(focus.ids(), bridge.ids(), "a11y/the_model_holds_exactly_the_registered_ids")
	audit.check_eq(focus.action_of(shell.back_control_id()), "back", "a11y/the_back_control_carries_the_shells_own_action")
	audit.check_true(bridge.has("modes/back"), "a11y/the_registered_id_is_the_shells_naming")
	bridge.register("modes/back", shell.back_control(), "back")
	audit.check_eq(_duplicates(bridge.ids()), [], "a11y/re_registering_an_id_does_not_duplicate_it_in_the_bridge")
	audit.check_eq(_duplicates(focus.ids()), [], "a11y/re_registering_an_id_does_not_duplicate_it_in_the_model")
	audit.check_eq(focus.ids().size(), bridge.ids().size(), "a11y/every_registered_control_reaches_the_model_once")


func _probes(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, shell: Control) -> void:
	var column := VBoxContainer.new()
	column.name = "ProbeColumn"
	column.custom_minimum_size = Vector2(320.0, 260.0)
	shell.content().add_child(column)
	var first := _probe_button(column, "ProbeFirst", "1")
	var second := _probe_button(column, "ProbeSecond", "2")
	var locked := _probe_button(column, "ProbeLocked", "3")
	bridge.register("modes/first", first, _declared_action("modes"), {})
	bridge.register("modes/second", second, "to-settings", {})
	bridge.register("modes/locked", locked, "to-career", {"locked": true})
	audit.check_eq(bridge.ids().size(), 4, "a11y/four_controls_are_registered")
	audit.check_eq(focus.ids().size(), 4, "a11y/four_targets_are_in_the_model")
	audit.check_eq(bridge.locked_ids(), ["modes/locked"], "a11y/the_locked_control_is_reported_locked")
	audit.check_true(focus.ids().has("modes/locked"), "a11y/a_locked_control_stays_registered_and_visible")


func _discoverability(audit: AuditBase, bridge: RefCounted, focus: MenuFocus) -> void:
	audit.check_eq(focus.focusable_ids().has("modes/locked"), false, "a11y/the_models_own_filter_refuses_a_locked_target")
	audit.check_eq(bridge.set_focus("modes/locked"), false, "a11y/the_bridge_will_not_focus_a_locked_control")
	audit.check_eq(bridge.set_focus("modes/first"), true, "a11y/a_normal_control_takes_the_focus")
	audit.check_eq(bridge.focus_id(), "modes/first", "a11y/the_focus_lands_where_it_was_asked")
	audit.check_eq(bridge.set_focus("modes/nope"), false, "a11y/an_unregistered_id_cannot_take_the_focus")
	var reachable: Array = focus.reachable_ids()
	audit.check_eq(reachable.has("modes/locked"), false, "a11y/the_models_walk_cannot_reach_a_locked_control")
	audit.check_ge(reachable.size(), 3, "a11y/the_models_walk_reaches_the_controls_it_should")


func _direction(audit: AuditBase, bridge: RefCounted, focus: MenuFocus) -> void:
	audit.check_eq(bridge.set_focus("modes/first"), true, "a11y/the_first_control_takes_the_focus_before_a_move")
	var down := _key_event(KEY_DOWN)
	audit.check_eq(bridge.dispatch(down), true, "a11y/a_direction_is_handled_by_the_bridge")
	audit.check_eq(bridge.focus_id(), "modes/second", "a11y/a_down_press_lands_on_the_control_below")


func _activation(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, router: Control, transitions: Array) -> void:
	var action := _declared_action("modes")
	var expected := Router.id_of_dom(NavRoutes.screen_of_action(action))
	audit.check_true(expected != "" and Router.ids().has(expected), "a11y/the_screens_forward_action_names_a_registered_screen")
	audit.check_eq(Router.to_actions_of("modes").size(), 1, "a11y/the_modes_row_declares_exactly_one_action")
	audit.check_eq(action, NavRoutes.back_action(Router.dom_id_of("modes")), "a11y/the_modes_rows_only_action_is_its_own_return")
	audit.check_eq(expected, Router.ROOT_ID, "a11y/that_return_points_at_the_root")
	audit.check_eq(bridge.set_focus("modes/first"), true, "a11y/the_acting_control_has_the_focus")
	transitions.clear()
	var enter := _key_event(KEY_ENTER)
	audit.check_eq(bridge.dispatch(enter), true, "a11y/confirm_on_a_control_is_handled")
	audit.check_eq(bool(bridge.last_dispatch().get("activated", false)), true, "a11y/the_control_activated")
	audit.check_eq(String(bridge.last_dispatch().get("screen", "")), expected, "a11y/the_activation_names_the_screen_the_action_points_at")
	audit.check_eq(transitions.size(), 1, "a11y/the_activation_navigated_once")
	audit.check_eq(router.active_id(), expected, "a11y/the_router_is_on_the_screen_the_action_named")
	await process_frame


## The declared `to-*` table's genuine forward navigation, taken from the root because
## the screen the audit starts on declares none of its own: `screen-modes`'s only action
## is its return (`nav_routes.gd`, and `_activation` asserts exactly that). The action is
## read from the table and skipped while it points back at this screen's own return, so
## nothing here can drift from the route data.
func _forward(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, router: Control, transitions: Array) -> void:
	var shell: Control = router.active_screen().get("shell")
	bridge.attach(shell, focus, router)
	await process_frame
	var action := _forward_action(router.active_id())
	audit.check_true(action != "", "a11y/the_root_declares_a_forward_action_the_audit_can_take")
	var expected := Router.id_of_dom(NavRoutes.screen_of_action(action))
	audit.check_true(expected != "" and Router.ids().has(expected), "a11y/the_forward_action_names_a_registered_screen")
	audit.check_ne(expected, Router.ROOT_ID, "a11y/the_forward_action_reaches_a_screen_that_is_not_the_root")
	var button := _probe_button(shell.content(), "ForwardProbe", "F")
	bridge.register("menu/forward", button, action, {})
	audit.check_eq(bridge.set_focus("menu/forward"), true, "a11y/the_forward_control_takes_the_focus")
	transitions.clear()
	audit.check_eq(bridge.dispatch(_key_event(KEY_ENTER)), true, "a11y/confirm_on_the_forward_control_is_handled")
	audit.check_eq(transitions.size(), 1, "a11y/the_forward_action_navigated_once")
	audit.check_eq(router.active_id(), expected, "a11y/the_router_is_on_the_screen_the_forward_action_named")
	await process_frame


func _back(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, router: Control, transitions: Array) -> void:
	var shell: Control = router.active_screen().get("shell")
	audit.check_true(shell.back_target() != "", "a11y/a_non_root_screen_declares_its_return")
	bridge.attach(shell, focus, router)
	await process_frame
	audit.check_eq(bridge.ids(), [shell.back_control_id()], "a11y/re_attaching_registers_the_new_shell")
	transitions.clear()
	var escape_key := _key_event(KEY_ESCAPE)
	audit.check_eq(bridge.dispatch(escape_key), true, "a11y/back_is_handled")
	audit.check_eq(bool(bridge.last_dispatch().get("activated", false)), true, "a11y/back_navigated")
	audit.check_eq(transitions.size(), 1, "a11y/back_navigated_once")
	audit.check_eq(String(shell.back_target()), String(router.active_id()), "a11y/back_landed_on_the_shells_declared_target")
	await process_frame


func _root(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, router: Control, transitions: Array) -> void:
	var shell: Control = router.active_screen().get("shell")
	audit.check_eq(router.active_id(), Router.ROOT_ID, "a11y/the_walk_back_reached_the_root")
	audit.check_eq(shell.back_target(), "", "a11y/the_root_declares_no_return")
	bridge.attach(shell, focus, router)
	await process_frame
	transitions.clear()
	var escape_key := _key_event(KEY_ESCAPE)
	audit.check_eq(bridge.dispatch(escape_key), true, "a11y/back_on_the_root_is_still_handled")
	audit.check_eq(transitions.size(), 0, "a11y/back_on_the_root_navigates_nowhere")
	audit.check_eq(router.active_id(), Router.ROOT_ID, "a11y/the_root_stays_the_root")

	# The handled contract: true exactly for the events the model owns, so the caller can
	# stop Godot's built-in ui_* navigation from moving the same focus again.
	audit.check_eq(bridge.dispatch(_key_event(KEY_ENTER)), true, "a11y/confirm_is_the_models_to_handle")
	audit.check_eq(bridge.dispatch(_key_event(KEY_ESCAPE)), true, "a11y/back_is_the_models_to_handle")
	audit.check_eq(bridge.dispatch(_key_event(KEY_RIGHT)), true, "a11y/a_direction_is_the_models_to_handle")
	audit.check_eq(bridge.dispatch(_key_event(KEY_F5)), false, "a11y/a_key_the_model_does_not_own_is_left_to_the_game")
	audit.check_eq(bridge.dispatch(InputEventMouseMotion.new()), false, "a11y/a_pointer_event_is_not_the_bridges")

	# The case the model cannot be asked about directly: a control takes the focus and is
	# locked afterwards. It stays inert, and nothing navigates.
	var locked_button := _probe_button(shell.content(), "LateLock", "4")
	bridge.register("menu/late", locked_button, "to-career", {})
	audit.check_eq(bridge.set_focus("menu/late"), true, "a11y/a_control_to_be_locked_later_takes_the_focus")
	bridge.register("menu/late", locked_button, "to-career", {"locked": true})
	audit.check_eq(focus.focusable_ids().has("menu/late"), false, "a11y/a_control_that_became_locked_leaves_the_focusable_set")
	transitions.clear()
	audit.check_eq(bridge.dispatch(_key_event(KEY_ENTER)), true, "a11y/confirm_on_a_control_that_became_locked_is_handled")
	audit.check_eq(bool(bridge.last_dispatch().get("activated", false)), false, "a11y/a_locked_control_does_not_activate")
	audit.check_eq(transitions.size(), 0, "a11y/no_navigation_happened_for_the_locked_control")
	audit.check_eq(router.active_id(), Router.ROOT_ID, "a11y/the_router_did_not_move_for_a_locked_control")
	audit.check_eq(bridge.locked_ids(), ["menu/late"], "a11y/the_late_lock_is_reported_upward")


func _keyboard(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, router: Control) -> void:
	# The shell the router has mounted *now*: the earlier shells were freed as the audit
	# walked the graph, and a freed node is not a place to add a probe field.
	var shell: Control = router.active_screen().get("shell")
	var nav: MenuNav = focus.menu
	nav.set_pad_connected(true)
	audit.check_eq(nav.pad_connected(), true, "a11y/the_probe_runs_with_a_pad_connected")
	nav.set_osk_targets([{
		"id": "osk/probe_key",
		"kind": "button",
		"action": "",
		"rect": Rect2(0.0, 0.0, 44.0, 44.0),
		"drawn": true,
	}])
	var field := LineEdit.new()
	field.name = "ProbeField"
	field.text = ""
	field.custom_minimum_size = Vector2(220.0, 32.0)
	shell.content().add_child(field)
	bridge.register("menu/probe_field", field, "", {"kind": "text_field"})
	await process_frame
	audit.check_true(FocusNav.is_text_field(_target_of(nav, "menu/probe_field")), "a11y/the_probe_field_is_seen_as_a_text_field")
	audit.check_eq(bridge.set_focus("menu/probe_field"), true, "a11y/the_probe_field_takes_the_focus")
	audit.check_eq(nav.osk.is_open(), false, "a11y/the_keyboard_starts_closed")

	var enter := _key_event(KEY_ENTER)
	audit.check_eq(bridge.dispatch(enter), true, "a11y/confirm_on_a_text_field_is_handled")
	audit.check_eq(nav.osk.is_open(), true, "a11y/with_a_pad_connected_confirm_opens_the_keyboard_model")
	audit.check_eq(String(bridge.last_dispatch().get("kind", "")), "osk_open", "a11y/the_verdict_names_the_keyboard")
	audit.check_eq(nav.osk.target_id(), "menu/probe_field", "a11y/the_keyboard_opened_for_the_focused_field")
	audit.check_eq(nav.context_kind(), MenuNav.CONTEXT_OSK, "a11y/the_model_is_in_the_keyboard_context")
	audit.check_eq(nav.osk.press_char("p"), true, "a11y/the_keyboard_model_takes_a_character")
	audit.check_eq(nav.osk.value(), "p", "a11y/the_character_lands_in_the_open_field")

	audit.check_eq(bridge.dispatch(_key_event(KEY_ESCAPE)), true, "a11y/back_with_the_keyboard_open_is_handled")
	audit.check_eq(nav.osk.is_open(), false, "a11y/back_closes_the_keyboard_model")
	audit.check_eq(String(bridge.last_dispatch().get("kind", "")), "osk_close", "a11y/the_verdict_names_the_close")
	audit.check_eq(bridge.focus_id(), "menu/probe_field", "a11y/closing_the_keyboard_gives_the_field_back")
	audit.check_eq(nav.context_kind(), MenuNav.CONTEXT_SCREEN, "a11y/the_model_is_back_in_the_screen_context")

	var pad_confirm := InputEventJoypadButton.new()
	pad_confirm.button_index = JOY_BUTTON_A
	pad_confirm.pressed = true
	audit.check_eq(bridge.dispatch(pad_confirm), true, "a11y/a_pad_confirm_is_handled")
	audit.check_eq(nav.osk.is_open(), true, "a11y/a_pad_confirm_opens_the_keyboard_again")
	var pad_cancel := InputEventJoypadButton.new()
	pad_cancel.button_index = JOY_BUTTON_B
	pad_cancel.pressed = true
	audit.check_eq(bridge.dispatch(pad_cancel), true, "a11y/a_pad_cancel_is_handled")
	audit.check_eq(nav.osk.is_open(), false, "a11y/a_pad_cancel_closes_the_keyboard")
	var released := InputEventJoypadButton.new()
	released.button_index = JOY_BUTTON_A
	released.pressed = false
	audit.check_eq(bridge.dispatch(released), false, "a11y/a_button_release_is_not_a_confirm")


# ---------------------------------------------------------------------------
# 7. The carried metadata: the range keys and the OSK keys the model cannot hold
# ---------------------------------------------------------------------------

## The seam the settings screen's range rows and the feedback screen's text fields need.
## `game/menu_focus.gd::_target()` projects a fixed key set, so the keys the input lane
## itself reads never reach the model: `focus_nav.gd::_adjust_range` (:239-246) steps a
## range from `step`/`value`/`min`/`max`, and `menu_nav.gd::confirm()` (:223-229) opens
## the OSK from `value`/`max_length`/`field_label`. The bridge carries them from the
## registration to the live target the input lane consumes. Both probes below are this
## audit's own constructed state, labeled as such like the section above. The shell is the
## one the router has mounted *now*, read the same way `_keyboard` reads it.
func _metadata(audit: AuditBase, bridge: RefCounted, focus: MenuFocus, router: Control) -> void:
	var shell: Control = router.active_screen().get("shell")
	var nav: MenuNav = focus.menu
	# The settings screen's shape: a range row registered with the range keys.
	var range := VSlider.new()
	range.name = "ProbeRange"
	range.custom_minimum_size = Vector2(48.0, 160.0)
	shell.content().add_child(range)
	var range_keys := {"min": 0.0, "max": 1.0, "step": 0.25, "value": 0.5}
	bridge.register("settings/probe_range", range, "", {
		"kind": "range", "min": 0.0, "max": 1.0, "step": 0.25, "value": 0.5,
	})
	await process_frame
	audit.check_eq(bridge.metadata_of("settings/probe_range"), range_keys, "a11y/the_registered_range_keys_are_reported_back")
	audit.check_eq(bridge.metadata_of("modes/first"), {}, "a11y/a_plain_control_carries_no_metadata")
	audit.check_eq(bridge.last_range(), {}, "a11y/no_range_step_is_reported_before_one_happens")
	audit.check_true(bridge.set_focus("settings/probe_range"), "a11y/the_range_takes_the_focus")
	audit.check_eq(bridge.focused_metadata(), range_keys, "a11y/the_carried_keys_reach_the_live_target_the_input_lane_reads")
	var steps: Array = []
	bridge.connect("range_changed", func(id: String, value: float) -> void:
		steps.append([id, value]))
	audit.check_eq(bridge.dispatch(_key_event(KEY_RIGHT)), true, "a11y/a_direction_on_the_range_is_handled")
	audit.check_eq(bridge.last_range(), {"id": "settings/probe_range", "value": 0.75}, "a11y/right_steps_the_range_from_the_registered_value")
	audit.check_eq(float(_target_of(nav, "settings/probe_range")["value"]), 0.75, "a11y/the_stepped_value_is_the_live_targets_own")
	audit.check_eq(float(bridge.metadata_of("settings/probe_range")["value"]), 0.75, "a11y/the_step_is_mirrored_into_the_registration")
	audit.check_eq(bridge.dispatch(_key_event(KEY_RIGHT)), true, "a11y/the_range_steps_again")
	audit.check_eq(float(bridge.last_range()["value"]), 1.0, "a11y/the_second_step_reaches_the_maximum")
	audit.check_eq(bridge.dispatch(_key_event(KEY_RIGHT)), true, "a11y/a_direction_at_the_maximum_is_still_handled")
	audit.check_eq(float(bridge.last_range()["value"]), 1.0, "a11y/the_maximum_clamps_the_value")
	audit.check_eq(steps.size(), 2, "a11y/the_clamped_step_reported_no_change")
	audit.check_eq(bridge.dispatch(_key_event(KEY_LEFT)), true, "a11y/the_range_steps_back")
	audit.check_eq(float(bridge.last_range()["value"]), 0.75, "a11y/the_mirrored_value_is_where_the_next_step_starts")
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.9
	audit.check_eq(bridge.dispatch(motion), true, "a11y/a_pad_motion_on_the_range_is_handled")
	audit.check_eq(float(bridge.last_range()["value"]), 1.0, "a11y/the_pad_motion_steps_the_same_range")
	audit.check_eq(steps.size(), 4, "a11y/every_step_reported_once")

	# The feedback screen's shape: a text field registered with the OSK keys.
	var message := LineEdit.new()
	message.name = "ProbeMessage"
	message.custom_minimum_size = Vector2(320.0, 32.0)
	shell.content().add_child(message)
	var osk_keys := {"value": "seed", "max_length": 12, "field_label": "Messaggio"}
	bridge.register("feedback/probe_message", message, "", {
		"kind": "text_field", "value": "seed", "max_length": 12, "field_label": "Messaggio",
	})
	await process_frame
	audit.check_eq(bridge.metadata_of("feedback/probe_message"), osk_keys, "a11y/the_registered_osk_keys_are_reported_back")
	audit.check_true(bridge.set_focus("feedback/probe_message"), "a11y/the_message_field_takes_the_focus")
	audit.check_eq(bridge.focused_metadata(), osk_keys, "a11y/the_osk_keys_reach_the_live_target_too")
	audit.check_eq(nav.osk.is_open(), false, "a11y/the_keyboard_is_closed_before_the_field_is_confirmed")
	audit.check_eq(bridge.dispatch(_key_event(KEY_ENTER)), true, "a11y/confirm_on_the_seeded_field_is_handled")
	audit.check_eq(nav.osk.is_open(), true, "a11y/the_seeded_field_opens_the_keyboard")
	audit.check_eq(nav.osk.value(), "seed", "a11y/the_keyboard_opens_with_the_registered_seed")
	audit.check_eq(nav.osk.max_length(), 12, "a11y/the_keyboard_opens_with_the_registered_length_cap")
	audit.check_true(nav.osk.label().contains("Messaggio"), "a11y/the_keyboard_labels_the_field_the_screen_named")
	audit.check_eq(String(bridge.last_osk().get("id", "")), "feedback/probe_message", "a11y/the_bridge_reports_the_field_the_keyboard_opened_for")
	audit.check_eq(bool(bridge.last_osk().get("open", false)), true, "a11y/the_report_says_the_keyboard_is_open")
	audit.check_eq(nav.osk.press_char("x"), true, "a11y/a_key_press_lands_while_the_keyboard_is_open")
	audit.check_eq(bridge.dispatch(_key_event(KEY_ESCAPE)), true, "a11y/back_with_the_seeded_keyboard_open_is_handled")
	audit.check_eq(nav.osk.is_open(), false, "a11y/the_seeded_keyboard_closes")
	audit.check_eq(String(bridge.last_osk().get("value", "")), "seedx", "a11y/the_screen_can_read_back_what_was_typed")
	audit.check_eq(bridge.focus_id(), "feedback/probe_message", "a11y/the_field_gets_the_focus_back")
	audit.check_eq(bridge.focused_metadata(), osk_keys, "a11y/the_carried_keys_survive_the_context_change_the_keyboard_made")


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## The first action a screen's row declares, whatever direction it points in — read from
## the router's table rather than hardcoded, so this audit cannot drift from it.
func _declared_action(screen_id: String) -> String:
	var actions: Array = Router.to_actions_of(screen_id)
	return "" if actions.is_empty() else String(actions[0])


## The first action of `screen_id` whose target is a registered screen other than this
## screen's own return — a genuine step forward, not a step home.
func _forward_action(screen_id: String) -> String:
	var home := Router.back_target_of(screen_id)
	for entry in Router.to_actions_of(screen_id):
		var action := String(entry)
		var target := Router.id_of_dom(NavRoutes.screen_of_action(action))
		if target == "" or not Router.ids().has(target):
			continue
		if target == home:
			continue
		return action
	return ""


func _probe_button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(120.0, 36.0)
	parent.add_child(button)
	return button


func _key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _target_of(nav: MenuNav, id: String) -> Dictionary:
	for target in nav.nav.targets():
		if String(target["id"]) == id:
			return target
	return {}


static func _duplicates(ids: Array) -> Array:
	var seen := {}
	var out: Array = []
	for id in ids:
		if seen.has(id):
			out.append(String(id))
		seen[id] = true
	return out


## Every screen whose declared table has an edge into `id`: the forward actions that name
## it, plus the returns that point at it. Empty means nothing in the table leads there.
static func _sources_of(forward: Dictionary, inbound: Dictionary, id: String) -> Array:
	var out: Array = []
	for source in forward.keys():
		if (forward[source] as Array).has(id) and not out.has(String(source)):
			out.append(String(source))
	for source in inbound.get(id, []):
		if not out.has(String(source)):
			out.append(String(source))
	out.sort()
	return out
