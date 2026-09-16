## reachability_audit.gd — the port of `scripts/reachability-audit.mjs`.
##
##   cd /root/projects/steam-circuit-padel-pro && \
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/input/reachability_audit.gd
##
## The reference audit's subject is the defect that makes no noise: a part of the
## game that exists and that nobody can open. Its three rules (`:17`):
##
##   1. every `data-action` in the markup has a handler;
##   2. every handler is reachable, from markup or from code;
##   3. every `<section id="screen-X">` is opened by some `showScreen`.
##
## and its registry cross-check (`:68-97`): the screens in the markup and the keys
## of `js/ui.js`'s `screens` table must be the same set, both ways, because a
## screen missing from the registry turns the page blank without an error.
##
## The port has no markup and no DOM, so the inventory is the one extracted from the
## frozen reference and shipped as data (`godot/src/input/nav_routes.gd`, generated
## by `tools/input-port/nav-routes.mjs --verify`). What is asserted here is the
## reference's own set of rules over that inventory, plus the two halves this slice
## adds: the declared return has to name an action the screen actually carries, and
## the return chain has to terminate at the root when the model walks it.
##
## NOT ported, and why:
##   - `data-action` ↔ `bindNavigation({...})` handler pairing (`:27-48`): the
##     handlers are DOM event bindings; the port's actions are the scheme's
##     (`godot/src/input/scheme.gd`) and the binding half is asserted in
##     `input_coverage_audit.gd`.
##   - the dynamic `data-action` scan over `js/*.js` templates (`:50-64`): there is
##     no template code in the port, and the equivalent (an action that exists and
##     is bound by nobody) is the scheme's reverse check.
##   - the markup-edge reachability is *reported* rather than asserted: a
##     `showScreen("x")` call inside a callback carries no static origin screen, so
##     the graph cannot be closed from the sources alone. The reference's rule 3 —
##     every screen has an opener — is asserted, and the number is printed.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const MenuNav := preload("res://src/input/menu_nav.gd")
const Scheme := preload("res://src/input/scheme.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")

## `scripts/gamepad-nav-audit.mjs:51` and `scripts/reachability-audit.mjs:69`: the
## floor the reference punishes — a two-screen build does not satisfy it.
const SCREEN_FLOOR := 8
## `js/ui.js:444-458`: the thirteen registry keys the markup is cross-checked with.
const REFERENCE_SCREEN_COUNT := 13


func _initialize() -> void:
	var audit := AuditBase.new("reachability")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	audit.not_ported(
		"reach/markup_actions_have_handlers",
		"scripts/reachability-audit.mjs:27-48 pairs the markup's `data-action` strings with the keys of `bindNavigation({...})` in js/main.js; the port has neither markup nor event bindings — the same question is asserted in input_coverage_audit.gd over godot/src/input/scheme.gd and the live InputMap",
	)
	audit.not_ported(
		"reach/actions_generated_by_templates",
		"scripts/reachability-audit.mjs:50-64 scans js/*.js for `data-action=\"…\"` written in template strings, because the reference's buttons are built in code; the port has no template code, and the equivalent reverse check (an action nobody declares) is coverage/project_declared_actions_match_the_scheme",
	)

	# --- rule 3: every screen has a door -----------------------------------
	var screens := NavRoutes.ids()
	audit.check_eq(screens.size(), REFERENCE_SCREEN_COUNT, "reach/the_reference_inventory_is_thirteen_screens")
	audit.check_ge(screens.size(), SCREEN_FLOOR, "reach/the_eight_screen_floor_is_met")
	audit.check_eq(screens.size(), NavRoutes.ROUTE_SCREENS.size(), "reach/every_screen_has_a_row")

	var opened := NavRoutes.opened_screens()
	var orphans: Array = []
	for screen_id in screens:
		if not opened.has(screen_id):
			orphans.append(screen_id)
	audit.check_eq(orphans, [], "reach/every_screen_is_opened_by_some_showScreen")
	audit.check_eq(opened.size(), REFERENCE_SCREEN_COUNT, "reach/every_screen_has_at_least_one_opener")

	# …and the reverse: opening a screen that does not exist leaves the player on a
	# blank page, because `showScreen` does not complain about an unknown id
	# (`js/ui.js:595-602`).
	var phantom: Array = []
	for screen_id in opened:
		if not screens.has(screen_id):
			phantom.append(screen_id)
	audit.check_eq(phantom, [], "reach/no_opener_names_a_screen_that_does_not_exist")

	# --- the registry cross-check (js/ui.js:444-458) ------------------------
	var registry: Array = NavRoutes.ROUTE_REGISTRY.duplicate()
	registry.sort()
	var markup_keys: Array = screens.map(func(s: String) -> String: return s.trim_prefix("screen-"))
	markup_keys.sort()
	audit.check_eq(registry, markup_keys, "reach/the_registry_and_the_markup_list_the_same_screens")
	var unregistered: Array = []
	for key in markup_keys:
		if not registry.has(key):
			unregistered.append(key)
	audit.check_eq(unregistered, [], "reach/no_markup_screen_is_missing_from_the_registry")
	var useless: Array = []
	for key in registry:
		if not markup_keys.has(key):
			useless.append(key)
	audit.check_eq(useless, [], "reach/the_registry_lists_no_screen_that_does_not_exist")

	# --- rule: every screen declares its return, and only the root does not --
	var declared: Array = []
	var backless: Array = []
	for screen_id in screens:
		if NavRoutes.back_action(screen_id) == "":
			backless.append(screen_id)
		else:
			declared.append(screen_id)
	audit.check_eq(declared.size(), 10, "reach/ten_screens_declare_their_return")
	audit.check_eq(
		backless, NavRoutes.BACKLESS_SCREENS,
		"reach/only_the_root_the_field_and_the_result_declare_no_return",
	)
	audit.check_eq(NavRoutes.back_action(NavRoutes.ROOT_SCREEN), "", "reach/the_root_declares_no_return")

	# The declared return must be an action the screen itself carries, and it must
	# lead to a screen that exists — the difference between "declared data" and an
	# inferred position (`scripts/gamepad-nav-audit.mjs:73-80`).
	var not_on_the_screen: Array = []
	var dangling: Array = []
	var self_loops: Array = []
	for screen_id in declared:
		var row: Dictionary = NavRoutes.row(screen_id)
		var action := NavRoutes.back_action(screen_id)
		if not (row["to"] as Array).has(action):
			not_on_the_screen.append("%s=%s" % [screen_id, action])
		var target := NavRoutes.screen_of_action(action)
		if target == "" or not screens.has(target):
			dangling.append("%s=%s" % [screen_id, action])
		elif target == screen_id:
			self_loops.append(screen_id)
	audit.check_eq(not_on_the_screen, [], "reach/every_return_is_an_action_the_screen_carries")
	audit.check_eq(dangling, [], "reach/every_return_leads_to_a_screen_that_exists")
	audit.check_eq(self_loops, [], "reach/no_screen_returns_to_itself")

	# --- the model walks the declared chain ---------------------------------
	# Back from every screen must terminate at the root, or cancel would loop. The
	# game screen is the field: its back is the pause overlay's, which the model
	# reports as its own case (`nav/the_overlay_owns_back_while_it_is_up`).
	var menu := MenuNav.new()
	var walk_failures: Array = []
	for screen_id in declared:
		menu.set_screen_targets([{"id": "back", "rect": Rect2(20, 20, 120, 40), "kind": "button", "drawn": true, "action": NavRoutes.back_action(screen_id)}])
		menu.open_screen(screen_id)
		var steps := 0
		var at: String = String(screen_id)
		while at != NavRoutes.ROOT_SCREEN and steps < 10:
			var result := menu.back()
			if String(result["kind"]) != "back":
				break
			at = menu.screen_id()
			steps += 1
		if at != NavRoutes.ROOT_SCREEN:
			walk_failures.append("%s→%s after %d" % [screen_id, at, steps])
	audit.check_eq(walk_failures, [], "reach/back_walks_every_screen_to_the_root")
	audit.check_eq(menu.screen_id(), NavRoutes.ROOT_SCREEN, "reach/the_walk_ends_on_the_root")

	# The game screen's back belongs to the overlay, not to a screen edge.
	menu.set_screen_targets([])
	menu.open_screen("screen-game")
	menu.set_in_match(true, true)
	menu.push_overlay("pause")
	audit.check_eq(menu.back()["kind"], "overlay", "reach/the_field_returns_to_its_overlay")

	# --- provenance ---------------------------------------------------------
	var pinned := 0
	for source in NavRoutes.ROUTE_PROVENANCE:
		var entry: Dictionary = NavRoutes.ROUTE_PROVENANCE[source]
		if String(entry.get("sha256", "")).length() == 64 and int(entry.get("bytes", 0)) > 0:
			pinned += 1
	audit.check_eq(pinned, 3, "reach/the_route_table_is_pinned_to_three_source_hashes")
	audit.check_eq(
		NavRoutes.ROUTE_OPENERS.size(), 17,
		"reach/seventeen_showscreen_call_sites_are_recorded",
	)

	var reachable := NavRoutes.markup_reachable_from_root()
	audit.check_ge(reachable.size(), 9, "reach/the_markup_edges_reach_at_least_the_nine_screens_they_can")
	audit.report("screens=%d declared_returns=%d openers=%d markup_reachable=%d/%d" % [
		screens.size(), declared.size(), NavRoutes.ROUTE_OPENERS.size(), reachable.size(), screens.size(),
	])
	audit.note("markup-edge reachability is a lower bound, not an assertion: a `showScreen(\"x\")` inside a callback carries no static origin screen, so arena, characters, game and result are opened from code only (js/main.js:2346, 2480, 1156; js/ui.js:1526)")
	audit.note("the scheme declares %d actions; the binding half of the reference's action/handler pairing is asserted in input_coverage_audit.gd" % Scheme.ids().size())
