## gamepad_nav_audit.gd — the port of `scripts/gamepad-nav-audit.mjs`.
##
##   cd /root/projects/steam-circuit-padel-pro && \
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/input/gamepad_nav_audit.gd
##
## The reference audits a game that is sold on Steam and played with a pad, and it
## reads the *sources* — `index.html`, `js/main.js`, `js/i18n.js` — to prove the
## contract between the markup and the navigation. The port has no markup, so the
## same contract is asserted against the model the UI lane calls
## (`godot/src/input/**`): the focus filter, the geometry that picks the next
## target, the declared return, the confirm and back edges, the on-screen keyboard
## and the help strings that promise them.
##
## Reference assertions carried over, one for one:
##   §1 every kind of interactive element is focusable        → `nav/*_is_skipped` + `nav/kinds_*`
##   §2 every screen declares its return                      → reachability_audit.gd
##   §3 the root declares no return, back is the *declared* one → `nav/declared_return_wins_*`, `nav/root_back_*`
##   §4 B/Circle goes back and A/Cross confirms, and the help
##      strings promise exactly that                           → `nav/pad_*`, `nav/help_*`
##   §5 a text field is filled with the pad (the OSK opens on
##      confirm, the keyboard takes the focus, back closes it) → `nav/osk_*`, `osk/*`
##   §6 the key labels exist in both languages                 → `nav/labels_*`
##   §7 the focus skips what is hidden, disabled or not drawn   → `nav/*_is_skipped`
##   §8 a wide target is not skipped (transverse overlap beats
##      centre distance)                                       → `nav/wide_target_*`
##   §9 read-only screens scroll, and the movement reports
##      whether it moved                                        → `nav/scroll_*`, `nav/move_reports_*`
##   §10 a read-only screen can be read with the pad only        → `nav/read_only_*`
##
## NOT ported, with the reason on the record: the markup itself (there is no DOM
## in the port: the reference's `<section>` inventory, its `data-action` attributes
## and its `[hidden]`/`disabled`/`offsetParent` selectors are the *inputs* here,
## expressed as target descriptors and asserted as rules), the eight-screen floor
## of `:51` (recorded, not asserted — see the report line), and every assertion
## that reads a DOM property rather than a decision (`offsetParent !== null`,
## `getComputedStyle`, `scrollIntoView`).
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const FocusNav := preload("res://src/input/focus_nav.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const Osk := preload("res://src/input/osk.gd")
const Scheme := preload("res://src/input/scheme.gd")
const InputStrings := preload("res://src/input/strings.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")

## `js/main.js:646-649`: `dx < -8` / `dx > 8` — the reference's direction threshold.
const THRESHOLD := FocusNav.DIRECTION_THRESHOLD

## The reference's two locales (`js/i18n.js`), the ones the audit's `n === 2` check
## counts. A hint that exists in one language only is the failure it punishes.
const LOCALES := ["it", "en"]


func _initialize() -> void:
	var audit := AuditBase.new("gamepad_nav")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	# Reference assertions with no headless form. Named, so a dropped check can
	# never hide behind a green summary (`AuditBase.not_ported`).
	audit.not_ported(
		"nav/focus_selector_is_read_from_the_sources",
		"scripts/gamepad-nav-audit.mjs:24-30 reads `root.querySelectorAll(\"button, input, textarea, select, summary, .mode-card, …\")` out of js/main.js; the port has no selector — the same inventory is the descriptor kinds focus_nav.gd accepts, asserted as nav/every_interactive_kind_is_focusable",
	)
	audit.not_ported(
		"nav/focus_skips_what_is_not_drawn_offsetParent",
		"js/main.js:578 uses `el.offsetParent !== null`, a DOM layout fact with no headless equivalent; the model takes the caller's `drawn` flag, and nav/not_drawn_is_skipped asserts the filter, not a browser layout engine",
	)
	audit.not_ported(
		"nav/scroll_positions_come_from_getComputedStyle",
		"js/main.js:605-613 resolves the scrolling ancestor from `getComputedStyle(el).overflowY` and `scrollHeight/clientHeight`; the model takes registered containers with content_height/view_height and asserts the same comparison in nav/a_container_that_does_not_overflow_is_not_the_scroller",
	)
	audit.not_ported(
		"nav/scrollIntoView_on_focus_move",
		"js/main.js:588 calls `el.scrollIntoView({block: 'nearest'})` when the focus moves; a DOM scroll-into-view has no headless equivalent and belongs to the UI lane",
	)
	audit.note("the eight-screen floor of scripts/gamepad-nav-audit.mjs:51 is measured in reachability_audit.gd against the reference's 13-screen inventory")
	_focus_filter(audit)
	_movement_geometry(audit)
	_scrolling(audit)
	_context_and_activation(audit)
	_back(audit)
	_pad_edges(audit)
	_on_screen_keyboard(audit)
	_help_strings(audit)


# ---------------------------------------------------------------------------
# §1/§7 — what can take the focus (collectMenuTargets, js/main.js:559-580)
# ---------------------------------------------------------------------------

static func _focus_filter(audit: AuditBase) -> void:
	var nav := FocusNav.new()
	for target in filter_fixture():
		nav.add_target(target)

	var ids: Array = nav.targets().map(func(t: Dictionary) -> String: return String(t["id"]))
	audit.check_eq(ids, ["play", "mode-card", "server"], "nav/collect_keeps_only_what_the_focus_may_land_on")
	audit.check_eq(
		nav.targets().size(), filter_fixture().size() - 5,
		"nav/filter_drops_exactly_the_five_unfocusable_kinds",
	)
	audit.check_true(nav.has_target("play"), "nav/button_is_focusable")
	audit.check_true(nav.has_target("server"), "nav/text_field_is_focusable")
	audit.check_true(nav.has_target("mode-card"), "nav/card_that_is_its_own_button_is_focusable")
	audit.check_true(not nav.has_target("locked-card"), "nav/locked_card_is_skipped")
	audit.check_true(not nav.has_target("disabled-btn"), "nav/disabled_is_skipped")
	audit.check_true(not nav.has_target("hidden-btn"), "nav/hidden_is_skipped")
	audit.check_true(not nav.has_target("undrawn-btn"), "nav/not_drawn_is_skipped")
	audit.check_true(
		not nav.has_target("lineup-cell"),
		"nav/container_card_with_its_own_button_is_skipped",
	)

	# §1: the reference's selector is `button, input, textarea, select, summary,
	# .mode-card, .athlete-card, .arena-card` (`js/main.js:565-567`) — every kind
	# that markup can carry must have a descriptor kind that is focusable.
	var kinds: Array = ["button", "text_field", "range", "card"]
	var focusable: Array = []
	for kind in kinds:
		var probe := FocusNav.new()
		probe.add_target({"id": "x", "rect": Rect2(0, 0, 10, 10), "kind": kind, "drawn": true})
		if probe.targets().size() == 1:
			focusable.append(kind)
	audit.check_eq(focusable, kinds, "nav/every_interactive_kind_is_focusable")

	# Insertion order is the markup order: the first target is the first one added.
	var ordered := FocusNav.new()
	for target in filter_fixture():
		ordered.add_target(target)
	audit.check_eq(ordered.ensure_focus(), "play", "nav/first_target_is_the_first_inserted")


# ---------------------------------------------------------------------------
# §8 — the geometry (findMenuTarget, js/main.js:630-673)
# ---------------------------------------------------------------------------

static func _movement_geometry(audit: AuditBase) -> void:
	# A target 5 px to the right is not "to the right" (the threshold is 8).
	var narrow := FocusNav.new()
	narrow.add_target(_target("here", 100, 100, 40, 20))
	narrow.add_target(_target("barely-right", 105, 100, 40, 20))
	narrow.set_focus("here")
	audit.check_true(not narrow.move_focus("right"), "nav/direction_threshold_is_eight_pixels")
	audit.check_eq(narrow.focus_id(), "here", "nav/a_candidate_under_the_threshold_does_not_take_the_focus")

	# §8: the wide element. From a left column, a wide target *below* overlaps the
	# column on the x axis and must win against a nearer target that is aligned in
	# its own column but does not overlap — the defect the reference fixed, where
	# the wide textarea stayed in the list and was unreachable.
	var wide := FocusNav.new()
	wide.add_target(_target("column", 20, 100, 60, 30))
	wide.add_target(_target("aligned-near", 200, 130, 40, 20))
	wide.add_target(_target("wide-row", 20, 300, 600, 40))
	wide.set_focus("column")
	var chosen := wide.find_target("down")
	audit.check_eq(String(chosen.get("id", "")), "wide-row", "nav/wide_target_wins_over_a_closer_aligned_one")
	audit.check_true(wide.move_focus("down"), "nav/wide_target_can_be_reached")
	audit.check_eq(wide.focus_id(), "wide-row", "nav/wide_target_takes_the_focus")

	# The overlap is read from the two rectangles' edges
	# (`Math.min(curRect.right, r.right)`, `js/main.js:662-663`): a candidate whose
	# edge only touches pays the no-overlap penalty, so a farther *overlapping*
	# target still wins.
	var touching := FocusNav.new()
	touching.add_target(_target("column-b", 20, 100, 60, 30))
	touching.add_target(_target("touching", 80, 140, 40, 20))
	touching.add_target(_target("overlapping-far", 40, 500, 100, 30))
	touching.set_focus("column-b")
	audit.check_eq(
		String(touching.find_target("down").get("id", "")), "overlapping-far",
		"nav/overlap_is_computed_from_the_rect_edges",
	)

	# §9: the movement must say whether it moved, or the caller cannot know when to
	# scroll (`js/main.js:692-694`).
	var edge := FocusNav.new()
	edge.add_target(_target("only", 100, 100, 40, 20))
	edge.set_focus("only")
	audit.check_true(edge.move_focus("down") == false, "nav/move_reports_that_it_did_not_move")
	audit.check_true(edge.move_focus("right") == false, "nav/move_reports_no_move_on_every_axis")
	edge.add_target(_target("under", 100, 200, 40, 20))
	audit.check_true(edge.move_focus("down") == true, "nav/move_reports_that_it_moved")

	# No wrapping: at the edge the focus stays put, which is what makes the caller
	# scroll instead (`js/main.js:646-649,965-969`).
	edge.set_focus("under")
	audit.check_true(not edge.move_focus("down"), "nav/no_wrapping_at_the_bottom_edge")
	audit.check_eq(edge.focus_id(), "under", "nav/the_focus_stays_at_the_edge")

	# A range steps its own value on left/right (`js/main.js:683-689`).
	var slider := FocusNav.new()
	slider.add_target(_target("deadzone", 100, 100, 200, 20, {
		"kind": "range", "min": 0.08, "max": 0.30, "step": 0.01, "value": 0.15,
	}))
	slider.add_target(_target("below", 100, 200, 40, 20))
	slider.set_focus("deadzone")
	audit.check_true(slider.move_focus("right"), "nav/range_keeps_the_focus_on_left_right")
	audit.check_eq(slider.focus().get("value"), 0.16, "nav/range_steps_its_value_up")
	slider.move_focus("left")
	slider.move_focus("left")
	audit.check_true(
		absf(float(slider.focus()["value"]) - 0.14) < 1e-9,
		"nav/range_steps_its_value_down",
	)
	for i in 40:
		slider.move_focus("left")
	audit.check_eq(slider.focus().get("value"), 0.08, "nav/range_clamps_at_its_minimum")
	slider.set_focus("deadzone")
	audit.check_true(slider.move_focus("down"), "nav/range_gives_its_focus_up_on_up_down")
	audit.check_eq(slider.focus_id(), "below", "nav/range_moves_off_on_the_other_axis")


# ---------------------------------------------------------------------------
# §9/§10 — scrolling (scrollContainer / scrollMenu, js/main.js:605-627)
# ---------------------------------------------------------------------------

static func _scrolling(audit: AuditBase) -> void:
	var nav := FocusNav.new()
	nav.register_container({"id": "screen-challenges", "parent": "", "scrolls": true, "content_height": 1800.0, "view_height": 700.0})
	nav.add_target(_target("back", 20, 20, 120, 40, {"container": "screen-challenges"}))
	audit.check_eq(nav.ensure_focus(), "back", "nav/read_only_screen_has_a_target")
	audit.check_eq(nav.scroll_container_id(), "screen-challenges", "nav/scroll_finds_the_container")
	audit.check_eq(nav.scroll(90.0)["offset"], 90.0, "nav/scroll_applies_to_the_container")

	# A container that does not actually overflow is not the scroll owner
	# (`el.scrollHeight > el.clientHeight + 2`, `js/main.js:609`): the page takes it.
	var short_container := FocusNav.new()
	short_container.register_container({"id": "panel", "parent": "", "scrolls": true, "content_height": 100.0, "view_height": 99.0})
	short_container.add_target(_target("row", 20, 20, 120, 40, {"container": "panel"}))
	short_container.ensure_focus()
	audit.check_eq(short_container.scroll_container_id(), "", "nav/a_container_that_does_not_overflow_is_not_the_scroller")
	short_container.scroll(90.0)
	audit.check_eq(short_container.page_scroll(), 90.0, "nav/the_page_scrolls_instead")

	# The inner panel wins over the page when it does overflow: some panels scroll
	# on their own (`js/main.js:601-604`).
	var nested := FocusNav.new()
	nested.register_container({"id": "page", "parent": "", "scrolls": true, "content_height": 2000.0, "view_height": 700.0})
	nested.register_container({"id": "panel", "parent": "page", "scrolls": true, "content_height": 600.0, "view_height": 200.0})
	nested.add_target(_target("attached", 20, 20, 120, 40, {"container": "panel"}))
	nested.ensure_focus()
	audit.check_eq(nested.scroll_container_id(), "panel", "nav/an_inner_panel_wins_over_the_page")

	# §10: a read-only screen — challenges, history, profile — scrolls with the pad
	# and with the arrows, because the focus cannot move anywhere.
	var menu := MenuNav.new()
	menu.set_pad_connected(true)
	menu.register_scroll_container({"id": "screen-history", "parent": "", "scrolls": true, "content_height": 2400.0, "view_height": 700.0})
	menu.set_screen_targets([_target("to-menu", 20, 20, 120, 40, {"container": "screen-history"})])
	menu.open_screen("screen-history")
	var keyboard := menu.keyboard_direction("down")
	audit.check_true(not keyboard["moved"], "nav/read_only_screen_has_nothing_below_to_focus")
	audit.check_eq(keyboard["scrolled"], MenuNav.KEY_SCROLL_STEP, "nav/arrows_scroll_when_the_focus_cannot_move")
	audit.check_eq(menu.nav.scroll_offset("screen-history"), MenuNav.KEY_SCROLL_STEP, "nav/the_arrow_scroll_lands_on_the_container")

	var pad := menu.poll_pad({"stick_y": 1.0, "buttons": {}, "now_ms": 0.0})
	audit.check_true(not pad["focus_moved"], "nav/the_pad_finds_no_target_below")
	audit.check_eq(pad["scrolled"], MenuNav.FOCUS_SCROLL_SPEED, "nav/the_stick_scrolls_15_per_frame_when_there_is_no_target")

	# The right stick scrolls whatever the focus can do (`js/main.js:954-957`).
	var right_stick := menu.poll_pad({"right_stick_y": 1.0, "buttons": {}, "now_ms": 0.0})
	audit.check_eq(right_stick["scrolled"], MenuNav.STICK_SCROLL_SPEED, "nav/the_right_stick_scrolls_24_per_unit")
	var half := menu.poll_pad({"right_stick_y": -0.5, "buttons": {}, "now_ms": 0.0})
	audit.check_eq(half["scrolled"], -MenuNav.STICK_SCROLL_SPEED / 2.0, "nav/the_right_stick_scrolls_proportionally")


# ---------------------------------------------------------------------------
# §5 — the context, confirm and the on-screen keyboard hand-off
# ---------------------------------------------------------------------------

static func _context_and_activation(audit: AuditBase) -> void:
	var menu := MenuNav.new()
	menu.set_screen_targets(menu_fixture())
	menu.open_screen(NavRoutes.ROOT_SCREEN)
	audit.check_eq(menu.context_kind(), MenuNav.CONTEXT_SCREEN, "nav/the_source_screen_owns_the_focus")
	audit.check_eq(menu.ensure_focus(), "to-profile", "nav/the_first_target_of_the_screen_takes_the_focus")

	# In a running match the menu does not have the focus at all
	# (`js/main.js:555`: `matchState.running && !paused` returns null).
	menu.set_in_match(true, false)
	audit.check_eq(menu.context_kind(), MenuNav.CONTEXT_NONE, "nav/a_running_match_has_no_menu_focus")
	audit.check_eq(menu.nav.targets().size(), 0, "nav/no_target_is_offered_during_play")
	var polled := menu.poll_pad({"stick_y": 1.0, "buttons": {"0": true}, "now_ms": 0.0})
	audit.check_true(not polled["focus_moved"], "nav/the_pad_moves_nothing_during_play")
	audit.check_true(not polled["confirm"], "nav/confirm_does_nothing_during_play")

	menu.set_in_match(true, true)
	audit.check_eq(menu.context_kind(), MenuNav.CONTEXT_SCREEN, "nav/a_paused_match_gives_the_focus_back")

	# The overlay takes precedence over the screen (`js/main.js:556`).
	menu.push_overlay("pause")
	menu.set_overlay_targets([_target("resume", 480, 300, 200, 60, {"action": "resume"})])
	audit.check_eq(menu.context_kind(), MenuNav.CONTEXT_OVERLAY, "nav/the_overlay_owns_the_focus_while_it_is_up")
	audit.check_eq(menu.focus_id(), "resume", "nav/the_overlay_targets_replace_the_screens")
	menu.pop_overlay()
	audit.check_eq(menu.focus_id(), "to-profile", "nav/closing_the_overlay_gives_the_screen_back")

	# Confirm activates the focused target and names its action.
	menu.set_screen_targets([_target("start", 480, 300, 200, 60, {"action": "to-modes"})])
	audit.check_eq(menu.focus_id(), "start", "nav/the_new_screens_first_target_takes_the_focus")
	var activated := menu.confirm()
	audit.check_eq(activated["kind"], "activate", "nav/confirm_activates_the_focused_target")
	audit.check_eq(activated["action"], "to-modes", "nav/confirm_reports_the_targets_action")
	audit.check_eq(activated["target"], "start", "nav/confirm_reports_the_target")

	# §5: confirming on a text field opens the keyboard — but only for a pad
	# (`js/main.js:701`: `ui.lastGamepadId`), because with a keyboard the player
	# types into the field directly.
	menu.set_screen_targets([_target("fbMessage", 200, 400, 600, 120, {"kind": "text_field", "value": "ciao", "max_length": 40, "field_label": "Messaggio"})])
	menu.set_pad_connected(false)
	audit.check_eq(menu.confirm()["kind"], "activate", "nav/a_text_field_activates_normally_without_a_pad")
	menu.set_pad_connected(true)
	var opened := menu.confirm()
	audit.check_eq(opened["kind"], "osk_open", "nav/confirm_on_a_text_field_opens_the_keyboard_with_a_pad")
	audit.check_eq(opened["target"], "fbMessage", "nav/the_keyboard_opens_for_the_focused_field")
	audit.check_true(menu.osk.is_open(), "nav/the_keyboard_is_open")
	audit.check_eq(menu.context_kind(), MenuNav.CONTEXT_OSK, "nav/the_open_keyboard_becomes_the_focus_context")
	audit.check_eq(menu.osk.value(), "ciao", "nav/the_keyboard_starts_from_the_fields_value")
	audit.check_eq(menu.osk.label(), InputStrings.osk_label("Messaggio"), "nav/the_keyboard_label_names_the_field")

	# While the keyboard is open the pad moves among its keys, not the screen
	# behind it: the context's targets are the keyboard's (`js/main.js:551-557`).
	menu.set_osk_targets([
		_target("osk-key-w", 100, 400, 40, 40),
		_target("osk-key-e", 150, 400, 40, 40),
		_target("osk-done", 600, 500, 100, 40, {"action": "done"}),
	])
	audit.check_eq(menu.focus_id(), "osk-key-w", "nav/the_keyboards_first_key_takes_the_focus")
	audit.check_true(menu.keyboard_direction("right")["moved"], "nav/the_focus_moves_among_the_keys")
	audit.check_eq(menu.focus_id(), "osk-key-e", "nav/the_second_key_has_the_focus")


# ---------------------------------------------------------------------------
# §3 — back: declared, not positional
# ---------------------------------------------------------------------------

static func _back(audit: AuditBase) -> void:
	# §5: back closes the keyboard and gives the field back, or the player is stuck
	# in it (`js/main.js:709-712,533-542`).
	var menu := MenuNav.new()
	menu.set_pad_connected(true)
	menu.set_screen_targets([_target("fbMessage", 200, 400, 600, 120, {"kind": "text_field", "value": "", "max_length": 40, "field_label": "Messaggio"})])
	menu.open_screen("screen-feedback")
	menu.confirm()
	var closed := menu.back()
	audit.check_eq(closed["kind"], "osk_close", "nav/back_closes_the_keyboard")
	audit.check_eq(closed["target"], "fbMessage", "nav/back_says_which_field_to_refocus")
	audit.check_eq(menu.focus_id(), "fbMessage", "nav/the_field_takes_the_focus_back")

	# The declared return wins over the positional fallback (§3, the defect the
	# reference audit describes: back used to open the first `to-*` action).
	audit.check_eq(NavRoutes.back_action("screen-characters"), "to-modes", "nav/the_return_is_declared_data")
	var walk := MenuNav.new()
	walk.set_screen_targets([_target("to-modes", 20, 20, 120, 40, {"action": "to-modes"}), _target("Completo", 300, 400, 200, 60)])
	walk.open_screen("screen-characters")
	var back := walk.back()
	audit.check_eq(back["kind"], "back", "nav/back_fires_the_declared_return")
	audit.check_eq(back["action"], "to-modes", "nav/the_declared_return_is_the_one_used")
	audit.check_eq(back["target"], "screen-modes", "nav/back_lands_on_the_declared_screen")
	audit.check_eq(walk.screen_id(), "screen-modes", "nav/the_screen_changed")
	audit.check_true(
		back["action"] != walk.legacy_back_action() or NavRoutes.row("screen-characters")["to"].size() == 1,
		"nav/the_declared_return_is_not_taken_from_the_positional_criterion",
	)

	# The menu is the root: it declares no return, and back from it leads nowhere
	# (`scripts/gamepad-nav-audit.mjs:67-82`).
	var root := MenuNav.new()
	root.set_screen_targets(menu_fixture())
	root.open_screen(NavRoutes.ROOT_SCREEN)
	var root_back := root.back()
	audit.check_eq(root_back["kind"], "none", "nav/root_back_leads_nowhere")
	audit.check_eq(root.screen_id(), NavRoutes.ROOT_SCREEN, "nav/root_back_stays_on_the_root")
	audit.check_true(root.legacy_back_action() != "", "nav/the_positional_criterion_still_exists_as_data")

	# …and it is unreachable from every shipped screen that declares a return.
	var unprotected: Array = []
	for screen_id in NavRoutes.ids():
		if NavRoutes.BACKLESS_SCREENS.has(screen_id):
			continue
		if NavRoutes.back_action(screen_id) == "":
			unprotected.append(screen_id)
	audit.check_eq(unprotected, [], "nav/no_shipped_screen_falls_back_to_the_positional_criterion")

	# The overlay owns back while it is up (`js/main.js:713-724`).
	var overlay := MenuNav.new()
	overlay.set_screen_targets(menu_fixture())
	overlay.open_screen(NavRoutes.ROOT_SCREEN)
	overlay.push_overlay("pause")
	audit.check_eq(overlay.back()["kind"], "overlay", "nav/the_overlay_owns_back_while_it_is_up")

	# During play there is nothing to go back to in the menu.
	var playing := MenuNav.new()
	playing.set_in_match(true, false)
	audit.check_eq(playing.back()["kind"], "none", "nav/back_does_nothing_during_play")


# ---------------------------------------------------------------------------
# §4 — the pad's edges and the repeat
# ---------------------------------------------------------------------------

static func _pad_edges(audit: AuditBase) -> void:
	# The direction chain, in the reference's order (`js/main.js:940-952`).
	audit.check_eq(MenuNav.direction({"buttons": {"12": true}}), "up", "nav/dpad_up_is_up")
	audit.check_eq(MenuNav.direction({"buttons": {"13": true}}), "down", "nav/dpad_down_is_down")
	audit.check_eq(MenuNav.direction({"buttons": {"14": true}}), "left", "nav/dpad_left_is_left")
	audit.check_eq(MenuNav.direction({"buttons": {"15": true}}), "right", "nav/dpad_right_is_right")
	audit.check_eq(MenuNav.direction({"stick_y": -0.8}), "up", "nav/stick_up_is_up")
	audit.check_eq(MenuNav.direction({"stick_x": 0.8}), "right", "nav/stick_right_is_right")
	audit.check_eq(MenuNav.direction({"stick_x": 0.4, "stick_y": 0.4}), "down", "nav/vertical_is_checked_before_horizontal")
	audit.check_eq(MenuNav.direction({"stick_x": 0.4, "stick_y": -0.4}), "up", "nav/vertical_up_wins_over_horizontal")
	audit.check_eq(MenuNav.direction({}), "", "nav/a_neutral_stick_is_no_direction")
	audit.check_eq(
		MenuNav.direction({"stick_y": 0.9, "buttons": {"12": true}}), "up",
		"nav/the_dpad_wins_over_an_opposite_stick",
	)

	var menu := MenuNav.new()
	menu.set_screen_targets([
		_target("top", 480, 100, 200, 60),
		_target("bottom", 480, 500, 200, 60),
	])
	menu.open_screen(NavRoutes.ROOT_SCREEN)
	audit.check_eq(menu.focus_id(), "top", "nav/the_pad_starts_on_the_first_target")
	var first := menu.poll_pad({"stick_y": 1.0, "buttons": {}, "now_ms": 1000.0})
	audit.check_true(first["focus_moved"], "nav/the_first_push_moves_the_focus")
	audit.check_eq(menu.focus_id(), "bottom", "nav/the_first_push_changes_the_target")

	# Held down: nothing until 400 ms, then every 150 ms (`js/main.js:970-978`).
	var held_nav := MenuNav.new()
	held_nav.set_screen_targets([
		_target("top", 480, 100, 200, 60),
		_target("middle", 480, 300, 200, 60),
		_target("bottom", 480, 500, 200, 60),
	])
	held_nav.open_screen(NavRoutes.ROOT_SCREEN)
	audit.check_eq(held_nav.focus_id(), "top", "nav/the_held_run_starts_on_the_first_target")
	var pushed := held_nav.poll_pad({"stick_y": 1.0, "buttons": {}, "now_ms": 0.0})
	audit.check_true(pushed["focus_moved"], "nav/the_push_moves_once")
	audit.check_eq(held_nav.focus_id(), "middle", "nav/the_push_moved_one_target")
	audit.check_eq(held_nav.repeat_state()["repeat_at"], MenuNav.REPEAT_FIRST_MS, "nav/the_first_repeat_is_scheduled_at_400ms")
	var holding := held_nav.poll_pad({"stick_y": 1.0, "buttons": {}, "now_ms": 200.0})
	audit.check_true(not holding["focus_moved"], "nav/holding_does_not_repeat_before_400ms")
	audit.check_eq(held_nav.focus_id(), "middle", "nav/the_hold_has_not_moved_the_focus")
	var repeated := held_nav.poll_pad({"stick_y": 1.0, "buttons": {}, "now_ms": 400.0})
	audit.check_true(repeated["focus_moved"], "nav/the_repeat_fires_at_400ms")
	audit.check_eq(held_nav.focus_id(), "bottom", "nav/the_repeat_moved_one_target")
	audit.check_eq(
		held_nav.repeat_state()["repeat_at"], 400.0 + MenuNav.REPEAT_MS,
		"nav/the_next_repeat_is_150ms_later",
	)
	audit.check_true(
		not held_nav.poll_pad({"stick_y": 1.0, "buttons": {}, "now_ms": 500.0})["focus_moved"],
		"nav/the_repeat_is_not_faster_than_150ms",
	)
	var released := held_nav.poll_pad({"stick_y": 0.0, "buttons": {}, "now_ms": 560.0})
	audit.check_eq(held_nav.repeat_state()["dir"], "", "nav/releasing_the_stick_clears_the_direction")
	audit.check_true(not released["focus_moved"], "nav/a_released_stick_moves_nothing")

	# Confirm is the A/Cross edge (button 0) and back is B/Circle or X/Square,
	# both edge-triggered (`js/main.js:983-996`).
	var edges := MenuNav.new()
	edges.set_screen_targets(menu_fixture())
	edges.open_screen(NavRoutes.ROOT_SCREEN)
	audit.check_true(edges.poll_pad({"buttons": {"0": true}, "now_ms": 0.0})["confirm"], "nav/button_0_confirms")
	audit.check_true(not edges.poll_pad({"buttons": {"0": true}, "now_ms": 16.0})["confirm"], "nav/a_held_button_0_does_not_confirm_again")
	edges.poll_pad({"buttons": {}, "now_ms": 32.0})
	audit.check_true(edges.poll_pad({"buttons": {"0": true}, "now_ms": 48.0})["confirm"], "nav/button_0_confirms_again_after_release")
	audit.check_true(edges.poll_pad({"buttons": {"1": true}, "now_ms": 64.0})["back"], "nav/button_1_goes_back")
	edges.poll_pad({"buttons": {}, "now_ms": 80.0})
	audit.check_true(edges.poll_pad({"buttons": {"2": true}, "now_ms": 96.0})["back"], "nav/button_2_goes_back_too")
	audit.check_eq(Scheme.CONFIRM_PAD_BUTTONS, [0], "nav/the_confirm_button_is_a_cross")
	audit.check_eq(Scheme.BACK_PAD_BUTTONS, [1, 2], "nav/back_is_mapped_on_both_b_and_x")


# ---------------------------------------------------------------------------
# §5/§6 — the on-screen keyboard model
# ---------------------------------------------------------------------------

static func _on_screen_keyboard(audit: AuditBase) -> void:
	# The grid is the reference's, verbatim (`js/main.js:430-437`).
	audit.check_eq(Osk.ROWS, [
		"1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm", "àèéìòù@._-+",
	], "osk/the_grid_is_the_references")
	audit.check_eq(Osk.ROWS.size(), 5, "osk/the_grid_has_five_rows")
	var osk := Osk.new()
	audit.check_eq(osk.chars().size(), 47, "osk/the_grid_lists_every_key")
	audit.check_true(osk.chars().has("à") and osk.chars().has("@") and osk.chars().has("."), "osk/the_accented_and_address_keys_are_there")

	audit.check_true(not osk.is_open(), "osk/starts_closed")
	audit.check_eq(osk.press_char("q"), false, "osk/typing_while_closed_does_nothing")
	osk.open_for("fbMessage", "", 10, "Messaggio")
	audit.check_true(osk.is_open(), "osk/opens_for_a_field")
	audit.check_eq(osk.target_id(), "fbMessage", "osk/remembers_the_field")

	audit.check_true(osk.press_char("q"), "osk/a_character_is_typed")
	audit.check_eq(osk.value(), "q", "osk/the_value_grew")
	osk.toggle_shift()
	audit.check_true(osk.press_char("w"), "osk/a_shifted_character_is_typed")
	audit.check_eq(osk.value(), "qW", "osk/shift_uppercases")
	audit.check_true(osk.shift(), "osk/shift_stays_on_until_it_is_toggled_back")
	osk.toggle_shift()
	audit.check_eq(osk.press("space"), "space", "osk/space_is_an_action_key")
	audit.check_eq(osk.value(), "qW ", "osk/space_inserts_a_space")

	# `oskInsert` refuses the whole insertion when it would not fit
	# (`js/main.js:459-466`) — it does not truncate. The value is "qW " here.
	audit.check_true(not osk.insert("01234567"), "osk/an_insertion_past_the_limit_is_refused")
	audit.check_eq(osk.value().length(), 3, "osk/a_refused_insertion_changes_nothing")
	audit.check_true(osk.insert("0123456"), "osk/an_insertion_that_fits_is_accepted")
	audit.check_eq(osk.value().length(), 10, "osk/the_max_length_is_honoured")
	audit.check_true(not osk.insert("x"), "osk/an_insertion_past_exactly_the_limit_is_refused")
	audit.check_eq(osk.press("backspace"), "backspace", "osk/backspace_is_an_action_key")
	audit.check_eq(osk.value().length(), 9, "osk/backspace_removes_one_character")

	var empty := Osk.new()
	empty.open_for("field", "", 0, "")
	audit.check_true(not empty.delete_char(), "osk/backspace_on_an_empty_field_is_a_no_op")
	audit.check_eq(empty.value(), "", "osk/an_empty_field_stays_empty")
	audit.check_true(empty.insert("senza_limite"), "osk/a_zero_max_length_means_unbounded")

	audit.check_eq(osk.press("done"), "closed", "osk/done_closes_the_keyboard")
	audit.check_true(not osk.is_open(), "osk/the_keyboard_is_closed")

	# §6: the action keys are labelled in both languages, through the locale seam.
	for locale in LOCALES:
		var labels: Array = []
		var missing: Array = []
		for key in InputStrings.osk_labels(locale):
			labels.append(String(key["text"]))
			if String(key["text"]) == String(key["label_id"]) or String(key["text"]).strip_edges() == "":
				missing.append(String(key["label_id"]))
		audit.check_eq(missing, [], "osk/action_keys_are_labelled_%s" % locale)
		audit.check_eq(labels.size(), 4, "osk/four_action_keys_%s" % locale)
	var reopened := Osk.new()
	reopened.open_for("f", "", 0, "")
	audit.check_true(reopened.toggle_shift() == true, "osk/shift_can_be_toggled")
	audit.check_eq(String(reopened.close()), "f", "osk/closing_reports_the_field")
	audit.check_true(not reopened.shift(), "osk/closing_clears_shift")
	audit.check_eq(reopened.close(), "", "osk/closing_twice_reports_nothing")

	var labelled := Osk.new()
	labelled.open_for("f", "", 0, "")
	labelled.toggle_shift()
	var rows: Array = labelled.rows("it")
	audit.check_eq(String(rows[1]["keys"][0]["label"]), "Q", "osk/the_grid_shows_the_shifted_character")
	audit.check_eq(String(rows[5]["kind"]), "actions", "osk/the_action_row_is_last")
	audit.check_eq(String(rows[5]["keys"][0]["label"]), InputStrings.text("oskShift", "it"), "osk/the_action_row_is_resolved_through_the_locale")
	audit.check_true(labelled.aria_label("it") != "ariaOsk", "osk/the_keyboard_announces_itself")


# ---------------------------------------------------------------------------
# §4/§6 — the help strings
# ---------------------------------------------------------------------------

static func _help_strings(audit: AuditBase) -> void:
	# §4: "L'aiuto non deve promettere un comando che non esiste" — the help strings
	# must promise the mapping that exists: A/Cross confirms, B/Circle goes back.
	# The reference's own filter is `pad(?:Hints3|MenuHint)`
	# (`scripts/gamepad-nav-audit.mjs:94`): the *menu* help lines are the ones that
	# promise back, and `padHints1/2` describe the in-match pad where B is the
	# special — asserting the back promise on those would be wrong.
	audit.check_eq(InputStrings.pad_hints().size(), 3, "nav/three_pad_help_lines")
	audit.check_true(InputStrings.menu_hint() != InputStrings.MENU_HINT, "nav/the_menu_help_line_resolves")
	var promises := {
		"it": {"back": "B/Cerchio", "confirm": "A conferma"},
		"en": {"back": "B/Circle", "confirm": "A confirm"},
	}
	for locale in LOCALES:
		var texts: Array = [InputStrings.pad_hints(locale)[2], InputStrings.menu_hint(locale)]
		audit.check_eq(texts.size(), 2, "nav/the_menu_help_lines_are_two_%s" % locale)
		var wrong: Array = []
		for text in texts:
			# The reference's own regex (`scripts/gamepad-nav-audit.mjs:98`):
			# `/B\/(Cerchio|Circle)/` on every menu help line.
			if not String(text).contains(promises[locale]["back"]):
				wrong.append(text)
		audit.check_eq(wrong, [], "nav/pad_help_promises_b_circle_for_back_%s" % locale)
		audit.check_true(
			String(InputStrings.pad_hints(locale)[2]).contains(promises[locale]["confirm"]),
			"nav/pad_help_promises_a_confirm_%s" % locale,
		)

	# §6: every id this module resolves must resolve in both languages — a hint
	# that exists in one language only is the failure that check punishes.
	for locale in LOCALES:
		audit.check_eq(InputStrings.unresolvable(locale), [], "nav/every_input_string_resolves_%s" % locale)
	audit.check_gt(InputStrings.owned_ids().size(), 30, "nav/the_input_string_inventory_is_enumerable")

	# The pad-only actions are the reference's, and are named rather than glossed.
	var pad_only: Array = []
	for action in Scheme.ids():
		if Scheme.devices(action) == ["pad"]:
			pad_only.append(action)
	audit.check_eq(pad_only.size(), 8, "nav/eight_actions_are_pad_only_in_the_reference")

	# The reference's own disagreement about RT, recorded where it is visible: the
	# legend calls it "Angolo"/"Angle" while GAMEPLAY_RULES.md calls it the analog
	# sprint. Reported, not resolved.
	audit.note("RT: legend label `sprintLbl` = \"%s\" (index.html:252, GAMEPLAY_RULES.md:169-171 calls it the analog sprint); the port binds padel_sprint to it and does not rename the string" % InputStrings.text("sprintLbl", "it"))
	audit.note("the reference's pad help strings are declared in both locales and resolved through godot/src/locale/** — no private string table in godot/src/input/**")
	audit.report("focus targets=%d hints=%d pad-only=%d" % [filter_fixture().size(), InputStrings.owned_ids().size(), pad_only.size()])


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

static func _target(id: String, x: float, y: float, w: float, h: float, extra: Dictionary = {}) -> Dictionary:
	var target := {"id": id, "rect": Rect2(x, y, w, h), "kind": "button", "drawn": true}
	for key in extra:
		target[key] = extra[key]
	return target


## The menu as the reference's markup builds it (`index.html:31-85`): the top bar
## first, then the hero. The order matters — it is what the positional fallback
## would have used.
static func menu_fixture() -> Array:
	return [
		_target("to-profile", 1200, 20, 48, 48, {"action": "to-profile"}),
		_target("to-settings", 1256, 20, 48, 48, {"action": "to-settings"}),
		_target("start", 480, 300, 220, 64, {"action": "to-modes"}),
	]


## Every kind the reference's selector can return, plus the five it must drop.
static func filter_fixture() -> Array:
	return [
		_target("play", 480, 300, 220, 64),
		_target("disabled-btn", 480, 400, 220, 64, {"disabled": true}),
		_target("hidden-btn", 480, 500, 220, 64, {"hidden": true}),
		_target("locked-card", 100, 300, 160, 200, {"kind": "card", "locked": true}),
		_target("lineup-cell", 300, 300, 160, 200, {"kind": "card", "contains_buttons": true}),
		_target("mode-card", 100, 100, 160, 200, {"kind": "card"}),
		_target("undrawn-btn", 700, 300, 120, 40, {"drawn": false}),
		_target("server", 480, 600, 300, 40, {"kind": "text_field"}),
	]
