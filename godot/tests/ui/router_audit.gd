## router_audit.gd — UIR-03's contract audit over the port's screen router.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/router_audit.gd
##
## Same machine-readable contract as `res://tests/smoke_test.gd` and
## `res://src/audits/audit_base.gd`: `ok <name>` / `FAIL <name>: expected …` / one
## `PASS n/n` line, exit 0 on PASS and 1 on FAIL.
##
## WHAT IT ASSERTS, and where the expectation comes from:
##
##   1. the router's own table holds exactly the thirteen screens — the registry of
##      `js/ui.js:444-458` — and agrees, both ways, with the reference inventory
##      `godot/src/input/nav_routes.gd` (which is generated from `index.html`/`js/ui.js`
##      and byte-verified by `tools/input-port/nav-routes.mjs --verify`). Two copies,
##      cross-checked, is the reference's own arrangement
##      (`scripts/reachability-audit.mjs` compares markup against the registry);
##   2. the declared back edges are the reference's: ten screens declare a return,
##      three (menu, game, result) declare none, and the result carries `to-menu`;
##   3. `go_to` mounts exactly one screen at a time and the outgoing screen leaves the
##      tree before the next enters;
##   4. an unregistered id warns and leaves the player where they are — `showScreen`'s
##      own fix for the blank page (`js/ui.js:595-602`). The warning text is a
##      `WARNING:` line in the acceptance log, which is where it is evidenced; it is not
##      a `SCRIPT ERROR`;
##   5. the shell resolves its text through the locale seam, names its focus controls
##      `<screen_id>/<suffix>` (`<screen_id>/back`), and hides the back control where
##      the reference declares no return;
##   6. no user-facing literal lives in `godot/src/ui/**` outside the whitelist below —
##      and the scan is proved non-vacuous against a synthetic source before it is
##      trusted over the real one.
##
## NOT PORTED here, and why: nothing. This audit is a port-side contract (the web build
## has no router class to compare against); the reference's own navigation behaviour is
## already asserted in `godot/tests/input/reachability_audit.gd`, which this ticket
## requires to stay green and does not duplicate.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Shell := preload("res://src/ui/ScreenShell.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")

## `js/ui.js:444-458`: thirteen keys.
const REFERENCE_SCREEN_COUNT := 13
## The three the reference declares no return from (`nav_routes.gd:82`).
const BACKLESS := ["menu", "game", "result"]
## `godot/game/hud.gd:75`, via the shell's own constant — the frame the port plays at.
const FRAME_SIZE := Vector2(1280.0, 720.0)
## Nodes added to the root during `_initialize` are laid out only after the frame's
## containers have sorted (`godot/tests/game_slice_test.gd:113-117`).
const SETTLE_FRAMES := 3

## A line that builds a message for a developer (a `push_error`, a `push_warning`, an
## `assert`) is not user-facing text. Stated as a rule so it can be argued with.
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]

## Files the literal scan does not read at all, with the reason each one is exempt.
const SCAN_EXEMPTIONS := [
	{
		"path": "res://src/ui/UiStrings.gd",
		"why": "it IS the seam: it owns no table and holds no prose, but its doc comment quotes locale ids (\"does_not_exist_key\") to state the fallback chain",
	},
]

## The literals the scan tolerates, named one by one with their reason. Never a whole
## file: a scan that skips files is a scan nobody can check.
const SCAN_WHITELIST = [
	{
		"path": "res://src/ui/PlaceholderScreen.gd",
		"literal": "not built yet",
		"why": "the ticket's own label for a screen whose ticket has not landed; no locale key answers for it yet and the screen asks the locale seam first (`UiStrings.has`)",
	},
]

## A source the scan must flag, and one it must not: the audit's own proof that it can
## still see prose. The first line is a comment, the second is prose in a label, the
## third is a developer message and the fourth is a locale id.
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"modesTitle\")\n## a comment quoting \"prose in a comment\"\n"


func _initialize() -> void:
	var audit := AuditBase.new("router")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_table(audit)
	_mount_on_a_bare_router(audit)
	await _shell_and_frame(audit)
	_strings(audit)
	_source_rules(audit)
	_literal_scan(audit)


# ---------------------------------------------------------------------------
# 1-2. The table, cross-checked against the reference inventory
# ---------------------------------------------------------------------------

func _table(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "router/the_router_knows_exactly_thirteen_screens")

	var route_ids: Array = NavRoutes.ids()
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	# The two spellings of the same thirteen: the router speaks the registry's keys
	# (`menu`), the reference inventory speaks the markup's anchors (`screen-menu`).
	var route_keys: Array = route_ids.map(func(dom: String) -> String: return String(dom).trim_prefix("screen-"))
	var sorted_route: Array = route_keys.duplicate()
	sorted_route.sort()
	audit.check_eq(sorted_ids, sorted_route, "router/the_ids_are_nav_routes_screen_ids_without_the_dom_prefix")

	var registry: Array = NavRoutes.ROUTE_REGISTRY.duplicate()
	registry.sort()
	audit.check_eq(sorted_ids, registry, "router/the_ids_are_the_registry_keys_of_js_ui_js_444")

	var missing_here: Array = []
	var missing_there: Array = []
	for key in route_keys:
		if not ids.has(String(key)):
			missing_here.append(String(key))
	for id in ids:
		if not route_keys.has(id):
			missing_there.append(String(id))
	audit.check_eq(missing_here, [], "router/every_reference_screen_exists_in_the_router")
	audit.check_eq(missing_there, [], "router/the_router_invents_no_screen")

	var doms: Array = []
	for id in ids:
		doms.append(Router.dom_id_of(id))
	audit.check_eq(doms, route_ids, "router/the_dom_anchors_are_the_reference_ids_in_document_order")

	var round_trip: Array = []
	for dom in doms:
		round_trip.append(Router.id_of_dom(dom))
	audit.check_eq(round_trip, ids, "router/every_dom_anchor_maps_back_to_its_own_id")
	audit.check_eq(Router.id_of_dom("screen-nope"), "", "router/an_unknown_dom_anchor_resolves_to_nothing")
	audit.check_eq(Router.dom_id_of("nope"), "", "router/an_unknown_id_has_no_dom_anchor")

	# The back edges, screen by screen, against the reference's own `data-back`.
	var mismatches: Array = []
	var declared: Array = []
	var backless: Array = []
	for id in ids:
		var here := Router.back_target_of(id)
		var action := NavRoutes.back_action(Router.dom_id_of(id))
		var there := "" if action == "" else String(action).trim_prefix("to-")
		if here != there:
			mismatches.append("%s: router=%s reference=%s" % [id, here, there])
		elif here == "":
			backless.append(id)
		elif not Router.has_id(here):
			mismatches.append("%s: back target %s is not a registered screen" % [id, here])
		else:
			declared.append(id)
	audit.check_eq(mismatches, [], "router/every_back_target_matches_the_reference")
	audit.check_eq(backless, BACKLESS, "router/only_the_root_the_field_and_the_result_declare_no_return")
	audit.check_eq(declared.size(), 10, "router/ten_screens_declare_a_return")
	audit.check_eq(Router.back_target_of(Router.ROOT_ID), "", "router/the_root_declares_no_return")

	# The `to-*` actions the screen's own markup carries, both ways.
	var to_mismatches: Array = []
	for id in ids:
		var row: Dictionary = NavRoutes.row(Router.dom_id_of(id))
		var expected: Array = row.get("to", [])
		var got: Array = Router.to_actions_of(id)
		if got != expected:
			to_mismatches.append("%s: router=%s reference=%s" % [id, str(got), str(expected)])
	audit.check_eq(to_mismatches, [], "router/every_to_action_matches_the_reference")
	audit.check_true(Router.to_actions_of("result").has("to-menu"), "router/the_result_carries_the_to_menu_action")
	audit.check_eq(Router.to_actions_of("game"), [], "router/the_field_carries_no_to_action")
	audit.check_eq(Router.to_actions_of("nope"), [], "router/an_unknown_id_carries_no_action")


# ---------------------------------------------------------------------------
# 3-4. Registration and mounting
# ---------------------------------------------------------------------------

func _mount_on_a_bare_router(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	var router: Control = Router.new()
	audit.check_eq(router.screen_count(), 0, "router/a_fresh_router_mounts_nothing")
	audit.check_eq(router.active_id(), "", "router/a_fresh_router_has_no_active_id")
	audit.check_eq(router.registered_ids(), [], "router/nothing_is_registered_before_a_screen_registers_itself")
	audit.check_eq(router.go_to("menu"), false, "router/go_to_refuses_before_any_screen_is_registered")

	var registered_all := true
	for id in ids:
		if not router.register(id, PlaceholderScene):
			registered_all = false
	audit.check_true(registered_all, "router/all_thirteen_screens_register_their_scene")
	audit.check_eq(router.registered_ids(), ids, "router/registered_ids_lists_the_thirteen_in_document_order")
	audit.check_eq(router.register("nope", PlaceholderScene), false, "router/register_refuses_an_id_outside_the_table")
	audit.check_eq(router.register("menu", null), false, "router/register_refuses_a_null_scene")

	var transitions: Array = []
	router.screen_changed.connect(func(from_id: String, to_id: String) -> void:
		transitions.append([from_id, to_id]))

	var mount_failures: Array = []
	var stragglers: Array = []
	for id in ids:
		var previous: Node = router.active_screen()
		var went: bool = router.go_to(id)
		var screen: Node = router.active_screen()
		if not went:
			mount_failures.append("%s: go_to refused" % id)
			continue
		if router.active_id() != id:
			mount_failures.append("%s: active_id=%s" % [id, router.active_id()])
		if screen == null:
			mount_failures.append("%s: no active screen" % id)
		elif screen.has_method("screen_id") and String(screen.screen_id()) != id:
			mount_failures.append("%s: the screen reports %s" % [id, screen.screen_id()])
		if router.screen_count() != 1:
			mount_failures.append("%s: %d screens mounted" % [id, router.screen_count()])
		if previous != null:
			if previous.is_inside_tree():
				stragglers.append("%s: the previous screen is still in the tree" % id)
			elif not previous.is_queued_for_deletion():
				stragglers.append("%s: the previous screen was not freed" % id)
	audit.check_eq(mount_failures, [], "router/go_to_mounts_the_screen_it_names_and_only_that_one")
	audit.check_eq(stragglers, [], "router/the_outgoing_screen_leaves_the_tree_before_the_next_enters")
	audit.check_eq(router.screen_count(), 1, "router/exactly_one_screen_is_mounted_after_thirteen_transitions")
	audit.check_eq(router.active_id(), String(ids[ids.size() - 1]), "router/the_last_transition_stands")
	audit.check_eq(transitions.size(), REFERENCE_SCREEN_COUNT, "router/every_transition_emits_screen_changed_once")
	audit.check_eq(transitions[0], ["", "menu"], "router/the_first_transition_reports_an_empty_from_id")
	audit.check_eq(transitions[1], ["menu", "characters"], "router/the_second_reports_the_screen_it_left")

	# The payload the router hands over: its own facts, and a caller's keys kept.
	var live_screen: Node = router.active_screen()
	audit.check_eq(String(live_screen.get("router_id")), "result", "router/the_screen_is_told_the_id_it_was_mounted_under")
	audit.check_eq(String(live_screen.get("back_target_id")), "", "router/the_result_is_told_it_has_no_back_target")
	router.go_to("modes", {"caller_fact": "kept"})
	audit.check_eq(String(router.active_screen().get("router_id")), "modes", "router/a_screen_mounted_by_id_is_told_its_own_id")
	audit.check_eq(String(router.active_screen().get("back_target_id")), "menu", "router/a_screen_is_told_its_declared_back_target")

	# An unknown id: warn, and stay put (`js/ui.js:595-602`).
	var kept_id: String = router.active_id()
	var kept_screen: Node = router.active_screen()
	audit.check_eq(router.go_to("nope"), false, "router/go_to_an_unregistered_id_refuses")
	audit.check_eq(router.go_to("screen-menu"), false, "router/go_to_refuses_a_dom_id_instead_of_a_router_id")
	audit.check_eq(router.active_id(), kept_id, "router/an_unknown_id_leaves_the_active_id_alone")
	audit.check_true(router.active_screen() == kept_screen, "router/an_unknown_id_does_not_remount_the_screen")
	audit.check_eq(transitions.size(), REFERENCE_SCREEN_COUNT + 1, "router/a_refused_transition_emits_nothing")
	audit.note("expected engine lines in this audit's log, all deliberate: four `WARNING: ScreenRouter.go_to: screen \"…\" is not registered` refusals and two `ERROR: ScreenRouter.register: …` refusals; the engine's own error/script-error count for this run must still read zero real faults")

	var bare_parent: Node = router.get_parent()
	if bare_parent != null:
		bare_parent.remove_child(router)
	router.free()


# ---------------------------------------------------------------------------
# 5. The shell, in a real frame
# ---------------------------------------------------------------------------

func _shell_and_frame(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	var frame := Control.new()
	frame.name = "RouterAuditFrame"
	frame.size = FRAME_SIZE
	root.add_child(frame)

	for _i in SETTLE_FRAMES:
		await process_frame

	var shell: Control = ShellScene.instantiate()
	audit.check_true(shell != null, "router/the_screen_shell_scene_loads")
	frame.add_child(shell)
	await process_frame
	shell.setup("modes")
	shell.set_title("modesTitle")
	shell.set_subtitle("modesSub")
	shell.set_back_target("menu")
	audit.check_eq(shell.screen_id, "modes", "router/the_shell_reports_the_id_it_was_set_up_with")
	audit.check_eq(shell.title_control().text, UiStrings.t("modesTitle"), "router/the_title_resolves_through_the_locale_seam")
	audit.check_true(shell.title_control().text != "modesTitle", "router/the_modes_title_is_a_sentence_and_not_an_id")
	audit.check_eq(shell.subtitle_control().text, UiStrings.t("modesSub"), "router/the_subtitle_resolves_through_the_locale_seam")
	audit.check_true(shell.subtitle_control().visible, "router/a_declared_subtitle_is_shown")
	audit.check_true(shell.back_control().visible, "router/the_back_control_shows_where_a_return_is_declared")
	audit.check_eq(shell.focus_controls().size(), 1, "router/the_shell_registers_its_back_control")
	audit.check_eq(String(shell.focus_controls()[0]["id"]), "modes/back", "router/the_back_control_is_named_screen_id_slash_back")
	audit.check_eq(shell.back_control_id(), "modes/back", "router/the_shell_owns_the_back_control_id")
	audit.check_eq(String(shell.focus_controls()[0]["action"]), "back", "router/the_back_control_carries_the_back_action")
	var margin_container: MarginContainer = shell.get_node("Margin")
	audit.check_eq(margin_container.get_theme_constant("margin_left"), int(Shell.SAFE_MARGIN),
		"router/the_shell_applies_the_safe_area_margin_from_its_own_constant")

	var probe := Button.new()
	probe.name = "Probe"
	shell.content().add_child(probe)
	shell.add_focus("probe", probe, "to-modes", {"kind": "button"})
	audit.check_eq(shell.focus_controls().size(), 2, "router/a_screen_control_adds_one_registration")
	audit.check_eq(String(shell.focus_controls()[1]["id"]), "modes/probe", "router/a_content_control_registers_under_the_shell_naming")
	shell.add_focus("probe", probe, "to-modes")
	audit.check_eq(shell.focus_controls().size(), 2, "router/registering_the_same_suffix_twice_replaces_it")

	shell.set_back_target("")
	audit.check_true(not shell.back_control().visible, "router/the_back_control_hides_where_the_reference_declares_no_return")
	audit.check_eq(shell.focus_controls().size(), 1, "router/hiding_the_back_control_drops_its_registration")
	shell.set_back_target("menu")
	audit.check_eq(shell.focus_controls().size(), 2, "router/re_declaring_the_back_target_registers_it_again")

	# The router mounted inside the same frame: every screen lays out, one at a time.
	var router: Control = Router.new()
	router.name = "Router"
	frame.add_child(router)
	for id in ids:
		router.register(id, PlaceholderScene)
	for _i in SETTLE_FRAMES:
		await process_frame
	var rect_failures: Array = []
	var id_failures: Array = []
	for id in ids:
		router.go_to(id)
		await process_frame
		var screen: Control = router.active_screen()
		var rect: Rect2 = screen.get_global_rect()
		if rect.size.x < FRAME_SIZE.x - 1.0 or rect.size.y < FRAME_SIZE.y - 1.0:
			rect_failures.append("%s=%s" % [id, str(rect)])
		if router.screen_count() != 1:
			id_failures.append("%s=%d" % [id, router.screen_count()])
	audit.check_eq(rect_failures, [], "router/every_screen_lays_out_inside_the_frame_it_is_mounted_in")
	audit.check_eq(id_failures, [], "router/one_screen_is_mounted_at_a_time_in_a_live_frame")

	# The placeholder's own report: the id, the label, the state list.
	var placeholder: Control = router.active_screen()
	audit.check_eq(String(placeholder.get("router_id")), "result", "router/the_placeholder_reports_the_id_it_was_handed")
	audit.check_eq(placeholder.label_text(), "not built yet", "router/the_placeholder_says_what_it_is")
	var states: Array = placeholder.capture_states()
	audit.check_eq(states.size(), 1, "router/a_screen_declares_one_capture_state_by_default")
	audit.check_eq(String(states[0]), "default", "router/the_default_capture_state_is_named_default")
	audit.check_eq(placeholder.apply_capture_state("default"), false, "router/the_default_capture_state_is_not_applied_by_the_base_class")
	audit.check_eq(placeholder.apply_capture_state("nope"), false, "router/an_unknown_capture_state_is_refused")
	audit.check_true(placeholder.get_node_or_null("ScreenShell") != null, "router/the_placeholder_builds_its_shell")

	frame.remove_child(router)
	router.free()
	frame.free()


# ---------------------------------------------------------------------------
# 6. UiStrings
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	audit.check_eq(UiStrings.t("does_not_exist_key"), "does_not_exist_key", "router/ui_strings_falls_back_to_the_id_itself")
	audit.check_eq(UiStrings.has("does_not_exist_key"), false, "router/ui_strings_reports_an_unresolvable_id")
	audit.check_eq(UiStrings.has("back"), true, "router/the_back_label_id_resolves")
	audit.check_eq(UiStrings.has("modesTitle"), true, "router/the_modes_title_id_resolves")
	audit.check_ne(UiStrings.t("back"), "back", "router/the_back_label_is_a_sentence_and_not_an_id")


# ---------------------------------------------------------------------------
# 7. Source rules
# ---------------------------------------------------------------------------

func _source_rules(audit: AuditBase) -> void:
	var path := "res://src/ui/ScreenRouter.gd"
	var source := FileAccess.get_file_as_string(path)
	audit.check_ne(source, "", "router/the_router_source_can_be_read")
	audit.check_eq(source.contains("preload(\"res://src/input/nav_routes.gd\")"), false,
		"router/the_router_does_not_load_the_reference_inventory")
	audit.check_eq(source.contains("nav_routes.gd"), true,
		"router/the_router_names_the_reference_inventory_it_is_compared_against")
	audit.check_eq(source.contains("FREEZE NOTE"), true, "router/the_freeze_note_is_in_the_header")

	var strings_source := FileAccess.get_file_as_string("res://src/ui/UiStrings.gd")
	# The rule is "this file owns no table", so scan for a *top-level* declaration.
	# A function-local `:= {}` is a temporary, not a table: `UiStrings.t` normalizes
	# params into one (`:36`, added with the params support the screens use), and the
	# older flat substring match flagged it (`FAIL 85/86`, wave-3 file at 01:03).
	var owns_table := false
	for line in strings_source.split("\n"):
		if not line.begins_with("	") and line.contains(":= {"):
			owns_table = true
			break
	audit.check_eq(owns_table, false, "router/ui_strings_owns_no_table")
	audit.check_eq(strings_source.contains("Locales"), false, "router/ui_strings_does_not_re_declare_the_locale_list")
	audit.check_eq(strings_source.contains("preload(\"res://src/locale/locale.gd\")"), true,
		"router/ui_strings_delegates_to_the_locale_seam")

	var contract := FileAccess.get_file_as_string("res://src/ui/screens/ScreenContract.gd")
	audit.check_eq(contract.contains("js/ui.js:595-607"), true, "router/the_contract_cites_the_show_screen_body")
	audit.check_eq(contract.contains("js/ui.js:596-598"), true, "router/the_contract_cites_the_blank_page_fix")


# ---------------------------------------------------------------------------
# 8. The literal scan
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	# The scan proves itself first: a synthetic source with one prose literal, one
	# developer message, one locale id and one comment.
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "router/the_literal_scan_flags_prose_and_ignores_developer_text")

	var scripts := _ui_scripts()
	audit.check_ge(scripts.size(), 5, "router/the_scan_finds_the_ui_lane_scripts")

	var offenders: Array = []
	var scanned: Array = []
	for path in scripts:
		if _exemption_why(String(path)) != "":
			continue
		scanned.append(String(path))
		offenders.append_array(_offenders_in_source(String(path), FileAccess.get_file_as_string(String(path))))
	audit.check_eq(offenders, [], "router/no_user_facing_literal_lives_in_godot_src_ui")
	audit.check_eq(scanned.size(), scripts.size() - SCAN_EXEMPTIONS.size(),
		"router/the_scan_read_every_ui_script_except_the_exemptions")
	audit.report("literal scan scanned=%d files offenders=%d exemptions=%d whitelist=%d" % [
		scanned.size(), offenders.size(), SCAN_EXEMPTIONS.size(), SCAN_WHITELIST.size(),
	])
	audit.note("the scan's rule: a string literal containing a space, outside a comment and not on a push_error/push_warning/printerr/assert line, is prose; the whitelist above is the only exception")


func _ui_scripts() -> Array:
	var out: Array = []
	var pending: Array = ["res://src/ui"]
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			var path := dir_path.path_join(entry)
			if dir.current_is_dir():
				if entry != "." and entry != "..":
					pending.append(path)
			elif entry.ends_with(".gd"):
				out.append(path)
			entry = dir.get_next()
		dir.list_dir_end()
	out.sort()
	return out


func _offenders_in_source(path: String, source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		var developer := false
		for marker in DEVELOPER_MARKERS:
			if code.contains(marker):
				developer = true
				break
		if developer:
			continue
		for literal in _literals(code):
			if not literal.contains(" "):
				continue
			if _whitelisted(path, literal):
				continue
			out.append("%s:%d \"%s\"" % [path, index + 1, literal])
	return out


func _literals(code: String) -> Array:
	var out: Array = []
	var i := 0
	while i < code.length():
		if code[i] == "\"":
			var j := i + 1
			var buffer := ""
			while j < code.length() and code[j] != "\"":
				if code[j] == "\\":
					j += 1
					if j < code.length():
						buffer += code[j]
				else:
					buffer += code[j]
				j += 1
			out.append(buffer)
			i = j + 1
		else:
			i += 1
	return out


func _exemption_why(path: String) -> String:
	for entry in SCAN_EXEMPTIONS:
		if String(entry["path"]) == path:
			return String(entry["why"])
	return ""


func _whitelisted(path: String, literal: String) -> bool:
	for entry in SCAN_WHITELIST:
		if String(entry["path"]) == path and String(entry["literal"]) == literal:
			return true
	return false
