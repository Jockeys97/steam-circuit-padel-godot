## screen_help_audit.gd — UIR-13's contract audit: the help screen in a real router.
##
## WHAT IT PROVES, and why each check is the reference's own question:
##
##   1. the router still carries the thirteen ids and the help screen mounts through it
##      (`js/ui.js:444-458`, `:595-607`);
##   2. the reference's own content inventory: eight cards in order (`index.html:194-221`),
##      the seven keyboard rows' caps and labels (`index.html:234-238`), and the
##      thirteen-row legend (`index.html:248-260`) — each cross-checked against the input
##      lane's own inventory (`godot/src/input/strings.gd`), so the screen and the pause
##      HUD cannot drift apart;
##   3. every string the screen shows resolves through the locale tables, and a language
##      flip re-resolves the ones the two tables differ on (`js/main.js:2325-2360` +
##      `js/i18n.js`);
##   4. the tabs switch (keyboard active by default, exactly the reference's own
##      `is-active`/`hidden` pair, `js/main.js:2338-2352`) and both capture states walk;
##   5. zero user-facing literals in `HelpScreen.gd` and in the two scenes this ticket
##      adds, scanned with the same rule `router_audit.gd` applies to the UI lane;
##   6. the layout holds at 1280x720 and 1024x600 (no horizontal overflow, the two
##      columns and the scroll region are both inside the frame) and the two breakpoints
##      behave (`styles.css:2775-2800`);
##   7. the legend's device-layout swap works (`js/main.js:408-445`) and the smash row is
##      a plain row here (the help legend has no tutorial link, `index.html:242-262`);
##   8. UIR-05's bridge can read the screen: the back control plus the two tabs.
##
## The theme gap this ticket carries (the `kbd` cap and the six muted inks the four
## UIR-13..16 screens share) is checked the way `hud_audit.gd` checks its own: every key
## the screen names must exist, and the screen's own miss list must be empty.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/HelpScreen.gd")
const ScreenScene := preload("res://src/ui/screens/HelpScreen.tscn")
const LegendClass := preload("res://src/ui/components/ControlLegend.gd")
const LegendScene := preload("res://src/ui/components/ControlLegend.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const InputStrings := preload("res://src/input/strings.gd")
const Scheme := preload("res://src/input/scheme.gd")

const SCREEN_PATH := "res://src/ui/screens/HelpScreen.gd"
const SCENE_PATH := "res://src/ui/screens/HelpScreen.tscn"
const LEGEND_PATH := "res://src/ui/components/ControlLegend.gd"
const LEGEND_SCENE_PATH := "res://src/ui/components/ControlLegend.tscn"

const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
const FRAME_NARROW := Vector2(820, 600)
const FRAME_TINY := Vector2(540, 600)

## The keyboard guide's caps, cap by cap (`index.html:234-238`), as the audit's own
## copy: the screen's rows must match this and the label ids must match the input
## lane's `KEYBOARD_LEGEND` in order.
const KEYBOARD_CAPS: Array = [
	["W", "A", "S", "D"], ["Space"], ["⌘"], ["A", "D", "←", "→"], ["Option"], ["Z"], ["Esc"],
]

## Same rule and same probe as `router_audit.gd`/`screen_menu_audit.gd`.
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"helpTitle\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control


func _initialize() -> void:
	var audit := AuditBase.new("screen_help")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	var frame := Control.new()
	frame.name = "ScreenHelpAuditFrame"
	frame.size = FRAME_BIG
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame

	await _mount(audit)
	await _content(audit)
	await _keyboard(audit)
	await _tabs(audit)
	await _legend(audit)
	await _strings(audit)
	await _captures(audit)
	await _layout(audit)
	_literal_scan(audit)
	await _bridge(audit)


func _screen() -> Node:
	return _router.active_screen()


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "help/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "help/all_thirteen_slots_register")
	audit.check_true(_router.register("help", ScreenScene), "help/the_scene_registers_under_the_help_id")
	audit.check_eq(_router.go_to("help"), true, "help/go_to_mounts_the_screen")
	audit.check_eq(_router.active_id(), "help", "help/the_screen_is_active")
	await process_frame
	var screen: Node = _screen()
	audit.check_true(screen != null and screen is ScreenClass, "help/the_mounted_scene_carries_HelpScreen_gd")
	audit.check_true(screen.theme != null, "help/the_scene_mounts_the_theme")
	audit.check_eq(screen.screen_id(), "help", "help/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "menu", "help/the_declared_return_is_a_router_id")
	audit.check_eq(screen.back_target(), Router.back_target_of("help"), "help/the_return_matches_the_router_table")
	audit.check_eq(String(screen.get("router_id")), "help", "help/the_screen_kept_the_router_fact")
	audit.check_eq(Array(screen.capture_states()), Array(ScreenClass.CAPTURE_STATE_LIST), "help/the_declared_capture_states_are_the_screen_own")
	audit.check_eq(screen.apply_capture_state("nope"), false, "help/an_undeclared_capture_state_is_refused")


# ---------------------------------------------------------------------------
# 2. The reference's own content inventory
# ---------------------------------------------------------------------------

func _content(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var sections: Node = screen.find_child(ScreenClass.SECTIONS_NODE, true, false)
	audit.check_true(sections != null, "help/the_cards_block_exists")
	var cards: Array = []
	for index in ScreenClass.CARDS.size():
		var card: Dictionary = ScreenClass.CARDS[index]
		var node: Node = sections.get_node_or_null("HelpCard%d" % index)
		if node == null:
			continue
		cards.append({
			"title": String((node.get_node("Title") as Label).text),
			"body": String((node.get_node("Body") as Label).text),
			"academy": node.has_meta("academy"),
		})
	audit.check_eq(cards.size(), 8, "help/the_reference_has_eight_cards")
	audit.check_eq(Array(ScreenClass.CARDS).size(), 8, "help/the_card_table_is_eight_rows")
	var titles_match := true
	var bodies_resolve := true
	var academy_flags := 0
	for index in cards.size():
		var card: Dictionary = cards[index]
		var spec: Dictionary = ScreenClass.CARDS[index]
		if String(card["title"]) != UiStrings.t(String(spec["title_key"])):
			titles_match = false
		if String(card["body"]) != UiStrings.t(String(spec["body_key"])):
			bodies_resolve = false
		if bool(card["academy"]):
			academy_flags += 1
	audit.check_true(titles_match, "help/every_card_title_is_its_locale_text")
	audit.check_true(bodies_resolve, "help/every_card_body_is_its_locale_text")
	audit.check_eq(academy_flags, 1, "help/one_card_carries_the_academy_mark")
	audit.check_eq(String((ScreenClass.CARDS[2] as Dictionary)["title_key"]), "helpAcademy", "help/the_academy_card_is_the_reference_third")
	# The keys must resolve in the locale tables, not fall back to themselves.
	var unresolved: Array = []
	for spec_in in ScreenClass.CARDS:
		var spec: Dictionary = spec_in
		for key in [String(spec["title_key"]), String(spec["body_key"])]:
			if not UiStrings.has(key):
				unresolved.append(key)
	audit.check_eq(unresolved, [], "help/every_card_string_resolves_in_the_locale_tables")


func _keyboard(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var guide: Node = screen.find_child(ScreenClass.KEYBOARD_GUIDE_NODE, true, false)
	audit.check_true(guide != null, "help/the_keyboard_guide_exists")
	var rows: Array = []
	for index in ScreenClass.KEYBOARD_ROWS.size():
		var row: Dictionary = ScreenClass.KEYBOARD_ROWS[index]
		var line: Node = guide.get_node_or_null("Row%d" % index)
		if line == null:
			continue
		var caps: Array = []
		var text := ""
		for child in line.get_children():
			if child is Label and String((child as Label).name).begins_with("Text"):
				text = String((child as Label).text)
			elif child is Label:
				caps.append(String((child as Label).text))
		rows.append({"caps": caps, "label": text, "label_id": String(row["label_id"])})
	audit.check_eq(rows.size(), 7, "help/the_keyboard_guide_has_the_reference_s_seven_rows")
	audit.check_eq(Array(ScreenClass.KEYBOARD_ROWS).size(), KEYBOARD_CAPS.size(), "help/the_screen_declares_seven_rows")
	var caps_match := true
	var labels_resolve := true
	for index in rows.size():
		var row: Dictionary = rows[index]
		if row["caps"] != KEYBOARD_CAPS[index]:
			caps_match = false
		if String(row["label"]) != UiStrings.t(String(row["label_id"])):
			labels_resolve = false
	audit.check_true(caps_match, "help/every_row_carries_the_reference_s_caps")
	audit.check_true(labels_resolve, "help/every_row_label_is_its_locale_text")
	# The input lane's own inventory must agree on the seven labels, in order.
	var lane_ids: Array = []
	for entry in InputStrings.KEYBOARD_LEGEND:
		lane_ids.append(String((entry as Dictionary)["label_id"]))
	var screen_ids: Array = []
	for row_in in ScreenClass.KEYBOARD_ROWS:
		screen_ids.append(String((row_in as Dictionary)["label_id"]))
	audit.check_eq(screen_ids, lane_ids, "help/the_seven_labels_agree_with_the_input_lane")
	var lane_unresolved: Array = []
	for id in lane_ids:
		if not UiStrings.has(String(id)):
			lane_unresolved.append(String(id))
	audit.check_eq(lane_unresolved, [], "help/every_label_resolves_in_both_locale_tables")


# ---------------------------------------------------------------------------
# 3. The tabs and the panel swap
# ---------------------------------------------------------------------------

func _tabs(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var keyboard_panel: Node = screen.find_child(ScreenClass.KEYBOARD_PANEL_NODE, true, false)
	var controller_panel: Node = screen.find_child(ScreenClass.CONTROLLER_PANEL_NODE, true, false)
	audit.check_true(keyboard_panel != null and controller_panel != null, "help/both_input_panels_exist")
	audit.check_eq(screen.input_view(), "keyboard", "help/the_keyboard_tab_is_the_default_view")
	audit.check_true(keyboard_panel.visible, "help/the_keyboard_panel_starts_visible")
	audit.check_true(not controller_panel.visible, "help/and_the_controller_panel_starts_hidden")
	audit.check_eq(String(screen.keyboard_tab_button().theme_type_variation), "SegmentedActive",
		"help/the_active_tab_carries_the_segmented_active_variation")
	audit.check_eq(String(screen.controller_tab_button().theme_type_variation), "SegmentedInactive",
		"help/the_idle_tab_carries_the_idle_variation")
	audit.check_eq(screen.set_input_view("controller"), true, "help/switching_to_the_controller_view_lands")
	audit.check_true(controller_panel.visible and not keyboard_panel.visible, "help/the_panels_swap")
	audit.check_eq(String(screen.keyboard_tab_button().theme_type_variation), "SegmentedInactive",
		"help/the_keyboard_tab_goes_idle")
	audit.check_eq(screen.set_input_view("nope"), false, "help/an_unknown_view_is_refused")
	audit.check_eq(screen.input_view(), "controller", "help/the_refused_switch_left_the_view_alone")
	screen.set_input_view("keyboard")


# ---------------------------------------------------------------------------
# 4. The legend (UIR-13's shared component, consumed by UIR-20 later)
# ---------------------------------------------------------------------------

func _legend(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var legend: Node = screen.find_child("HelpControllerLegend", true, false)
	audit.check_true(legend != null and legend is LegendClass, "help/the_controller_panel_carries_the_legend_component")
	var rows := LegendClass.reference_rows()
	audit.check_eq(rows.size(), 13, "help/the_legend_declares_the_reference_s_thirteen_rows")
	audit.check_eq(legend.row_count(), 13, "help/the_mounted_legend_shows_thirteen_rows")
	var lane_controls: Array = []
	var lane_labels: Array = []
	var lane_descs: Array = []
	for entry in InputStrings.LEGEND:
		lane_controls.append(String((entry as Dictionary)["control"]))
		lane_labels.append(String((entry as Dictionary)["label_id"]))
		lane_descs.append(String((entry as Dictionary)["desc_id"]))
	audit.check_eq(legend.row_label_keys(), lane_labels, "help/the_legend_labels_are_the_input_lane_s_own")
	audit.check_eq(legend.row_desc_keys(), lane_descs, "help/the_legend_descriptions_are_the_input_lane_s_own")
	audit.check_eq(legend.row_controls(), lane_controls, "help/the_legend_caps_are_the_input_lane_s_own")
	# The two actionless rows, and every action that does exist.
	var missing_actions: Array = []
	var actionless: Array = []
	for index in legend.row_count():
		var action := String(legend.row_action(index))
		if action == "":
			actionless.append(String(lane_labels[index]))
			continue
		var found := false
		for entry in Scheme.ACTIONS:
			if String((entry as Dictionary)["id"]) == action:
				found = true
				break
		if not found:
			missing_actions.append(action)
	audit.check_eq(actionless, ["aimLbl", "smashLbl"],
		"help/the_two_rows_with_no_inputmap_action_are_the_reference_s_own")
	audit.check_eq(missing_actions, [], "help/every_other_row_s_action_exists_in_the_scheme")
	# The device-layout swap (`js/main.js:396-404`).
	audit.check_eq(legend.device_layout(), "xbox", "help/the_default_layout_is_xbox")
	audit.check_true(legend.set_device_layout("playstation"), "help/the_playstation_layout_applies")
	var playstation: Array = []
	for entry in LegendClass.LAYOUTS["playstation"]["keys"]:
		playstation.append(String(entry))
	audit.check_eq(legend.row_controls(), playstation, "help/and_swaps_every_cap")
	audit.check_true(legend.caption_text() != "", "help/and_keeps_a_caption")
	audit.check_eq(legend.set_device_layout("dreamcast"), false, "help/an_unknown_layout_is_refused")
	audit.check_eq(legend.device_layout(), "playstation", "help/the_refused_layout_left_the_swap_alone")
	legend.set_device_layout("xbox")
	# The help legend shows no tutorial link (`index.html:242-262`); the component's
	# optional row is UIR-20's and is asserted through a standalone instance here.
	audit.check_eq(legend.tutorial_button(), null, "help/the_help_legend_shows_no_tutorial_link")
	var standalone: Node = LegendScene.instantiate()
	root.add_child(standalone)
	standalone.setup(LegendClass.reference_rows(), {"tutorial_link": true, "visual": false})
	audit.check_true(standalone.tutorial_button() != null, "help/the_component_renders_the_tutorial_row_when_asked")
	audit.check_eq(standalone.tutorial_row_index(), 11, "help/the_tutorial_row_is_the_smash_row")
	var fired: Array = []
	standalone.tutorial_requested.connect(func() -> void: fired.append(true))
	standalone.tutorial_button().pressed.emit()
	audit.check_eq(fired.size(), 1, "help/pressing_the_tutorial_row_emits_the_signal")
	standalone.queue_free()


# ---------------------------------------------------------------------------
# 5. Strings and the language flip
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var original := Locale.current_lang()
	var title_before := String(screen.title_control().text)
	var tab_before := String(screen.keyboard_tab_button().text)
	audit.check_true(title_before != "", "help/the_title_has_text")
	audit.check_eq(title_before, UiStrings.t("helpTitle"), "help/the_title_is_its_locale_text")
	# The runtime's default locale is `en` (`locale_rules.json` `defaultLocale`), so a
	# hard-coded "en" flip is a no-op here and proves nothing. Flip to the other table
	# of the pair, whatever the run started in (the osk audit's own pattern).
	var other := ""
	for lang in Locale.locales():
		if String(lang) != original:
			other = String(lang)
	audit.check_ne(other, "", "help/there_is_a_second_locale_to_flip_to")
	Locale.set_lang(other)
	screen.refresh_strings()
	var title_other := String(screen.title_control().text)
	var tab_other := String(screen.keyboard_tab_button().text)
	audit.check_true(title_other != title_before, "help/the_english_title_differs_from_the_italian_one")
	audit.check_true(tab_other != tab_before, "help/the_tab_labels_follow_the_language")
	var card_moved := String((screen.find_child(ScreenClass.SECTIONS_NODE, true, false).get_node("HelpCard0/Title") as Label).text)
	audit.check_eq(card_moved, UiStrings.t("helpObj"), "help/the_cards_follow_the_language")
	Locale.set_lang(original)
	screen.refresh_strings()
	audit.check_eq(String(screen.title_control().text), title_before, "help/and_the_flip_back_restores_the_first_text")
	audit.check_true(UiStrings.t("ariaHelp") != "", "help/the_aria_name_resolves")
	audit.check_eq(screen.aria_name(), UiStrings.t("ariaHelp"), "help/the_screen_reports_its_aria_name")


# ---------------------------------------------------------------------------
# 6. Capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var applied: Array = []
	for state in ScreenClass.CAPTURE_STATE_LIST:
		applied.append(screen.apply_capture_state(String(state)))
	audit.check_eq(applied, [true, true], "help/both_declared_capture_states_apply")
	audit.check_eq(screen.input_view(), "controller", "help/the_last_state_left_the_controller_tab_up")
	screen.apply_capture_state("keyboard-tab")
	audit.check_eq(screen.input_view(), "keyboard", "help/the_first_state_puts_the_keyboard_back")


# ---------------------------------------------------------------------------
# 7. Layout at both declared sizes, and the two breakpoints
# ---------------------------------------------------------------------------

func _layout(audit: AuditBase) -> void:
	var frame: Control = _router.get_parent()
	var screen: Node = _screen()
	var big := _measure(screen)
	audit.report("1280x720: widest=%.1f body=%.1f scroll=%.1f columns=%d" % [big["widest"], big["body_width"], big["viewport"], big["columns"]])
	audit.check_true(big["widest"] <= FRAME_BIG.x, "help/nothing_is_wider_than_the_frame")
	audit.check_eq(int(big["columns"]), 2, "help/the_cards_are_two_columns_at_1280")
	audit.check_true(big["row_visible"], "help/the_two_columns_sit_side_by_side_at_1280")
	frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	var small := _measure(screen)
	audit.report("1024x600: widest=%.1f body=%.1f scroll=%.1f columns=%d" % [small["widest"], small["body_width"], small["viewport"], small["columns"]])
	audit.check_true(small["widest"] <= FRAME_SMALL.x, "help/nothing_is_wider_than_the_small_frame")
	audit.check_eq(int(small["columns"]), 2, "help/the_cards_are_still_two_columns_at_1024")
	frame.size = FRAME_NARROW
	for _i in SETTLE_FRAMES:
		await process_frame
	var narrow := _measure(screen)
	audit.report("820x600: widest=%.1f columns=%d stacked=%s" % [narrow["widest"], narrow["columns"], str(not narrow["row_visible"])])
	audit.check_true(narrow["widest"] <= FRAME_NARROW.x, "help/nothing_is_wider_than_the_narrow_frame")
	audit.check_true(not narrow["row_visible"], "help/the_two_columns_collapse_below_860px")
	frame.size = FRAME_TINY
	for _i in SETTLE_FRAMES:
		await process_frame
	var tiny := _measure(screen)
	audit.report("540x600: columns=%d" % tiny["columns"])
	audit.check_eq(int(tiny["columns"]), 1, "help/the_cards_collapse_to_one_column_below_560px")
	frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame


func _measure(screen: Node) -> Dictionary:
	var scroll: ScrollContainer = screen.find_child(ScreenClass.SCROLL_NODE, true, false)
	var body: Control = screen.find_child(ScreenClass.BODY_NODE, true, false)
	var row: Control = screen.find_child(ScreenClass.ROW_NODE, true, false)
	var sections: GridContainer = screen.find_child(ScreenClass.SECTIONS_NODE, true, false)
	var controls: Control = screen.find_child(ScreenClass.CONTROLS_NODE, true, false)
	var widest := 0.0
	for control in [body, row, sections, controls, screen.find_child(ScreenClass.TABS_NODE, true, false)]:
		if control is Control:
			widest = maxf(widest, (control as Control).size.x)
	return {
		"widest": widest,
		"body_width": body.size.x,
		"viewport": scroll.size.y,
		"columns": sections.columns,
		"row_visible": row.visible,
	}


# ---------------------------------------------------------------------------
# 8. The literal scan, and the theme tokens this screen names
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "help/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "help/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "help/HelpScreen_gd_carries_no_prose_literal")
	var legend_source := FileAccess.get_file_as_string(LEGEND_PATH)
	audit.check_eq(_offenders_in_source(LEGEND_PATH, legend_source), [], "help/ControlLegend_gd_carries_no_prose_literal")
	var scene_literals: Array = []
	for path in [SCENE_PATH, LEGEND_SCENE_PATH]:
		for literal in _literals_in_scene(FileAccess.get_file_as_string(path)):
			scene_literals.append("%s: %s" % [path, literal])
	audit.check_eq(scene_literals, [], "help/the_two_scenes_carry_no_literals")

	var screen: Node = _screen()
	var theme: Theme = screen.theme
	var missing: Array = []
	for key in screen.palette_keys():
		if not theme.has_color(String(key), "Palette"):
			missing.append(String(key))
	audit.check_eq(missing, [], "help/the_theme_carries_every_palette_key_the_screen_names")
	audit.check_eq(screen.palette_misses(), [], "help/the_screen_recorded_no_missing_palette_key")
	var legend: Node = screen.find_child("HelpControllerLegend", true, false)
	audit.check_eq(legend.palette_misses(), [], "help/the_legend_recorded_no_missing_palette_key")



func _literals_in_scene(scene: String) -> Array:
	var out: Array = []
	for line in scene.split("\n"):
		var code := String(line).strip_edges()
		if not code.begins_with("text = "):
			continue
		for literal in _literals(code):
			if String(literal) != "":
				out.append(String(literal))
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
			if not String(literal).contains(" "):
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


# ---------------------------------------------------------------------------
# 9. UIR-05's bridge over this screen
# ---------------------------------------------------------------------------

func _bridge(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var specs: Array = screen.focus_controls()
	var ids: Array = []
	var actions: Array = []
	for spec in specs:
		ids.append(String((spec as Dictionary).get("id", "")))
		actions.append(String((spec as Dictionary).get("action", "")))
	audit.check_eq(specs.size(), 3, "help/the_screen_registers_three_focusables")
	audit.check_true(ids.has("help/back"), "help/the_back_control_is_registered")
	audit.check_true(ids.has("help/input-keyboard") and ids.has("help/input-controller"), "help/both_tabs_are_registered")
	audit.check_eq(actions.count("back"), 1, "help/one_focusable_speaks_for_the_declared_return")
	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	audit.check_eq(bridge.ids().size(), 3, "help/the_bridge_reads_the_three_controls")
	audit.check_true(bridge.set_focus("help/input-controller"), "help/the_bridge_can_focus_the_controller_tab")
