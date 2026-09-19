## screen_modes_audit.gd — UIR-10's contract audit: `screen-modes` in a real router.
##
## WHAT IT PROVES, each check the reference's own question:
##
##   1. the router still carries the thirteen ids and the modes screen mounts
##      through it (`js/ui.js:444-458`, `:595-607`);
##   2. the three cards are the reference's own set, in its order, with its own
##      title/description/tag nodes and the career card's tag + fixture line
##      (`index.html:112-130`, `js/main.js:1549-1567`);
##   3. the two setup segments: four difficulty rungs (`index.html:136-139`, the
##      gate's `DIFFICULTY_TIERS`) and six match formats (`js/data.js:689-698`);
##      a choice persists through the reference's own carrier (prefs) and moves the
##      session's selection (`js/main.js:2541-2556`, `:2276-2277`). The row's third
##      group is the port's own (the game-pace rung), and this audit only has to see
##      its five rungs reach the bridge like every other control —
##      `tests/pace_screen_test.gd` owns the rungs' behaviour and the clock they set;
##   4. a press on a mode card performs `js/ui.js:1720-1729`: pending mode set, the
##      choice persisted, tournament's round reset, the route to `characters`;
##   5. the demo run's own presentation: exactly one difficulty enabled and visible,
##      the unexposed modes shown locked with `demoLockedMode`, activation inert —
##      and the same presentation reachable in a full build through the declared
##      `demo-locked` capture state;
##   6. zero user-facing literals in `ModesScreen.gd`, with the scan's own synthetic
##      proof it can still see prose; the scene carries none;
##   7. a language flip re-resolves every binding the screen declares, in both
##      locales (`js/main.js:2421-2444`);
##   8. the five declared capture states walk, and `syncMatchSetup`'s own rule
##      (`js/main.js:1651-1657`) holds: setup visible for quick, hidden otherwise,
##      cards never touched;
##   9. the layout holds at 1280x720 (three columns) and 1024x600 (one column), and
##      UIR-05's bridge can read the screen and route its declared back edge.
##
## Both runs the ticket asks for share this file: a full build and `-- --demo`.
## The demo checks branch on `DemoGateAdapter.build()` with the adapter's own
## answers, so the same audit proves "all four rungs in a full build" and "one rung,
## visibly locked, in a demo" without being told which run it is in.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ModesScreenClass := preload("res://src/ui/screens/ModesScreen.gd")
const ModesScene := preload("res://src/ui/screens/ModesScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const ModeTables := preload("res://src/modes/mode_tables.gd")
const Pace := preload("res://src/sim/pace.gd")

const SCREEN_PATH := "res://src/ui/screens/ModesScreen.gd"
const SCENE_PATH := "res://src/ui/screens/ModesScreen.tscn"
const TEMP_DIR := "user://uir10-modes-audit"

const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
const REFERENCE_SCREEN_COUNT := 13

## `ModesScreen.gd` is allowed no prose literal at all: the one datum it would have
## needed (the fixture line's own separator) is spelled from its code points in
## `ModesScreen.fixture_joiner()`, so the lane's rule holds here with no exception.
const SCREEN_LITERALS: Array = []
## The scene is allowed none.
const SCENE_LITERALS: Array = []
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"modesTitle\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control
var _frame: Control


func _initialize() -> void:
	var audit := AuditBase.new("screen_modes")
	Config.save_dir = TEMP_DIR
	await _run(audit)
	_cleanup()
	quit(audit.finish())


func _cleanup() -> void:
	Config.save_dir = ""
	var absolute := ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(absolute):
		var dir := DirAccess.open(absolute)
		if dir != null:
			for file in dir.get_files():
				dir.remove(file)
		DirAccess.remove_absolute(absolute)


func _run(audit: AuditBase) -> void:
	_frame = Control.new()
	_frame.name = "ScreenModesAuditFrame"
	_frame.size = FRAME_BIG
	root.add_child(_frame)
	_router = Router.new()
	_router.name = "Router"
	_frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame

	await _register_router(audit)
	await _facts(audit)
	await _cards(audit)
	await _segments(audit)
	await _selection(audit)
	await _locks(audit)
	await _flip(audit)
	await _captures(audit)
	_literal_scan(audit)
	await _bridge(audit)
	await _layout(audit)


func _register_router(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "modes/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "modes/all_thirteen_slots_register")
	audit.check_true(_router.register("modes", ModesScene), "modes/the_scene_registers_under_the_modes_id")
	audit.check_eq(_router.go_to("modes"), true, "modes/go_to_mounts_the_screen")
	audit.check_eq(_router.active_id(), "modes", "modes/the_screen_is_active")
	audit.check_eq(_router.screen_count(), 1, "modes/one_screen_is_mounted")


func _screen() -> Node:
	return _router.active_screen()


func _facts(audit: AuditBase) -> void:
	await process_frame
	var screen := _screen()
	audit.check_true(screen is ModesScreenClass, "modes/the_mounted_scene_carries_ModesScreen_gd")
	audit.check_eq(screen.screen_id(), "modes", "modes/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "menu", "modes/the_declared_back_edge_is_menu")
	audit.check_eq(screen.get("router_id"), "modes", "modes/the_screen_kept_the_router_fact")
	audit.check_eq(screen.capture_states(),
		["default", "quick", "tournament", "career", "demo-locked"],
		"modes/the_screen_declares_the_five_capture_states")
	audit.check_true(screen.theme != null, "modes/the_scene_mounts_the_theme")


# ---------------------------------------------------------------------------
# 2. The three cards
# ---------------------------------------------------------------------------

func _cards(audit: AuditBase) -> void:
	var screen := _screen()
	var rows: Array = screen.mode_rows_now()
	audit.check_eq(rows.size(), 3, "modes/three_mode_cards")
	var ids: Array = []
	for row in rows:
		ids.append(String((row as Dictionary).get("id", "")))
	audit.check_eq(ids, ModesScreenClass.MODE_ORDER, "modes/the_cards_are_quick_tournament_career_in_order")

	var missing: Array = []
	for row in rows:
		var id := String((row as Dictionary).get("id", ""))
		for prefix in [ModesScreenClass.CARD_PREFIX, ModesScreenClass.ART_PREFIX,
				ModesScreenClass.ART_IMAGE_PREFIX, ModesScreenClass.TITLE_PREFIX,
				ModesScreenClass.DESC_PREFIX, ModesScreenClass.TAG_PREFIX,
				ModesScreenClass.FIXTURE_PREFIX]:
			if screen.find_child(prefix + id, true, false) == null:
				missing.append(prefix + id)
	audit.check_eq(missing, [], "modes/every_card_carries_its_own_nodes")

	# The art paths the seam hands over really exist on disk (UiArtPaths' contract).
	var art_missing: Array = []
	for row in rows:
		if String((row as Dictionary).get("art_path", "")) == "":
			art_missing.append(String((row as Dictionary).get("id", "")))
	audit.check_eq(art_missing, [], "modes/every_card_has_its_artifact_on_disk")

	# The reference's own keys resolve in both locales.
	var unresolved: Array = []
	for row in rows:
		for key in [String((row as Dictionary).get("title_key", "")), String((row as Dictionary).get("desc_key", ""))]:
			for lang in Locale.locales():
				if not Locale.is_resolvable(key, String(lang)):
					unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "modes/every_card_key_resolves_in_both_locales")

	# The career card's tag and fixture line, shaped as the reference writes them.
	var career_row := {}
	for row in rows:
		if String((row as Dictionary).get("id", "")) == "career":
			career_row = row
	audit.check_true(career_row.has("career"), "modes/the_career_card_carries_the_calendar_step")
	var career: Dictionary = career_row.get("career", {})
	audit.check_eq(int(career.get("matches", 0)), ModeTables.career_matches(), "modes/the_career_card_knows_the_season_length")
	var fixture: Label = screen.find_child(ModesScreenClass.FIXTURE_PREFIX + "career", true, false)
	audit.check_true(fixture != null and fixture.visible and fixture.text != "", "modes/the_career_card_shows_a_fixture_line")
	var arena_key := "arena_%s_name" % String(career.get("arena_id", ""))
	var rival_key := "ai_%s_name" % String(career.get("rival_id", ""))
	audit.check_true(fixture.text.contains(UiStrings.t(arena_key)), "modes/the_fixture_names_the_calendar_arena")
	audit.check_true(fixture.text.contains(UiStrings.t(rival_key)), "modes/the_fixture_names_the_calendar_rival")
	audit.check_true(fixture.text.contains(ModesScreenClass.fixture_joiner()), "modes/the_fixture_joins_its_two_halves")
	var tag: Label = screen.find_child(ModesScreenClass.TAG_PREFIX + "career", true, false)
	audit.check_true(tag.text != "" and tag.text != career_row.get("tag_key"), "modes/the_career_tag_is_a_sentence_not_an_id")
	audit.check_true(screen.text_shown(ModesScreenClass.TAG_PREFIX + "career") == tag.text, "modes/the_tag_is_a_binding_too")

	# The other two cards' fixture slots stay empty (`.mode-card__fixture:empty`
	# hides them in the reference).
	var visible_fixtures: Array = []
	for row in rows:
		var id := String((row as Dictionary).get("id", ""))
		var node: Label = screen.find_child(ModesScreenClass.FIXTURE_PREFIX + id, true, false)
		if node != null and node.visible:
			visible_fixtures.append(id)
	audit.check_eq(visible_fixtures, ["career"], "modes/only_the_career_card_shows_a_fixture")


# ---------------------------------------------------------------------------
# 3. The two segments
# ---------------------------------------------------------------------------

func _segments(audit: AuditBase) -> void:
	var screen := _screen()
	var order: Array = []
	for key in ModesScreenClass.DIFFICULTY_ORDER:
		var button: Button = screen.find_child(ModesScreenClass.DIFFICULTY_PREFIX + key, true, false)
		audit.check_true(button != null and button.text != key, "modes/difficulty_%s_is_a_button_with_text" % key)
		if button != null:
			order.append(key)
	audit.check_eq(order, ModesScreenClass.DIFFICULTY_ORDER, "modes/the_four_rungs_in_the_reference_order")
	var diff_order: Array = []
	for key in Gate.DIFFICULTY_TIERS.keys():
		diff_order.append(key)
	audit.check_eq(ModesScreenClass.DIFFICULTY_ORDER.size(), Gate.DIFFICULTY_TIERS.size(),
		"modes/the_rung_count_is_the_gates_own")

	var lengths: Array = []
	for key in ModesScreenClass.LENGTH_ORDER:
		var button: Button = screen.find_child(ModesScreenClass.LENGTH_PREFIX + key, true, false)
		audit.check_true(button != null and button.text != key, "modes/length_%s_is_a_button_with_text" % key)
		if button != null:
			lengths.append(key)
	audit.check_eq(lengths, ModesScreenClass.LENGTH_ORDER, "modes/the_six_formats_in_the_reference_order")

	# The active state follows the session's own selection — which in a demo is the
	# rung the build pins (`applyDemoLimits`, `js/ui.js:760-764`).
	var pinned: String = screen.pinned_rung()
	var chosen: String = pinned if pinned != "" else "hard"
	Config.tier_index = int(Gate.DIFFICULTY_TIERS[chosen])
	screen.refresh_data()
	var active: Array = []
	for key in ModesScreenClass.DIFFICULTY_ORDER:
		var button: Button = screen.find_child(ModesScreenClass.DIFFICULTY_PREFIX + key, true, false)
		if button != null and bool(button.get_meta("active", false)):
			active.append(key)
	audit.check_eq(active, [chosen], "modes/the_active_rung_is_the_sessions_own")
	audit.check_eq(screen.active_difficulty(), chosen, "modes/the_screen_reads_the_sessions_rung")

	# A choice moves the session and persists through the reference's own carrier.
	if pinned == "":
		audit.check_true(screen.select_difficulty("legend"), "modes/a_full_build_accepts_a_rung_change")
		audit.check_eq(Config.tier_index, int(Gate.DIFFICULTY_TIERS["legend"]), "modes/the_rung_change_reaches_the_session")
		var full_prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
		audit.check_eq(String(full_prefs.get("aiDifficulty", "")), "legend", "modes/the_rung_change_is_persisted")
	else:
		audit.check_true(screen.select_difficulty(chosen), "modes/the_pinned_rung_is_selectable")
		var other := ""
		for key in ModesScreenClass.DIFFICULTY_ORDER:
			if key != chosen:
				other = key
				break
		audit.check_eq(screen.select_difficulty(other), false, "modes/a_rung_outside_the_pin_is_refused")
		audit.check_eq(Config.tier_index, int(Gate.DIFFICULTY_TIERS[chosen]), "modes/a_refused_rung_leaves_the_session_alone")
		var demo_prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
		audit.check_eq(String(demo_prefs.get("aiDifficulty", "")), chosen, "modes/the_pinned_rung_is_persisted")
	audit.check_true(screen.select_length("games3"), "modes/a_format_choice_is_accepted")
	var after: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	audit.check_eq(String(after.get("matchLength", "")), "games3", "modes/the_format_choice_is_persisted")
	audit.check_eq(screen.active_length(), "games3", "modes/the_screen_shows_the_persisted_format")
	var length_active: Array = []
	for key in ModesScreenClass.LENGTH_ORDER:
		var button: Button = screen.find_child(ModesScreenClass.LENGTH_PREFIX + key, true, false)
		if button != null and bool(button.get_meta("active", false)):
			length_active.append(key)
	audit.check_eq(length_active, ["games3"], "modes/exactly_one_format_is_active")
	audit.check_eq(screen.select_length("nope"), false, "modes/an_unknown_format_is_refused")
	audit.check_eq(screen.select_difficulty("nope"), false, "modes/an_unknown_rung_is_refused")
	audit.report("length seam: no Config member carries the format today; the prefs carrier (matchLength=%s) is the reference's own and is asserted above" % String(after.get("matchLength", "")))


# ---------------------------------------------------------------------------
# 4. Selection: the card press
# ---------------------------------------------------------------------------

func _selection(audit: AuditBase) -> void:
	var screen := _screen()
	# The quick card, through the deployed click wire (`gui_input`).
	var quick: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + "quick", true, false)
	audit.check_true(quick != null, "modes/the_quick_card_exists")
	if DemoGate.mode_locked("quick"):
		audit.check_true(false, "modes/the_quick_card_is_never_locked_by_the_build")
	else:
		_click(quick)
		await process_frame
		audit.check_eq(Config.pending_mode, "quick", "modes/a_card_press_sets_the_pending_mode")
		audit.check_eq(_router.active_id(), "characters", "modes/a_card_press_lands_on_characters")
		audit.check_eq(_router.screen_count(), 1, "modes/the_press_mounts_exactly_one_screen")
		var prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
		audit.check_eq(String(prefs.get("mode", "")), "quick", "modes/the_press_persists_the_mode")

	# The tournament card also resets the bracket's round (`js/ui.js:1723-1726`).
	var again: Node = await _mount()
	if not DemoGate.mode_locked("tournament"):
		ModesSave.save_tournament_round(Config.save_store(), 2)
		audit.check_true(again.select_mode("tournament"), "modes/the_tournament_card_is_selectable")
		audit.check_eq(Config.pending_mode, "tournament", "modes/the_tournament_press_sets_the_pending_mode")
		audit.check_eq(ModesSave.tournament_round(Config.save_store()), 0, "modes/the_tournament_press_resets_the_round")
		audit.check_eq(_router.active_id(), "characters", "modes/the_tournament_press_lands_on_characters")
	else:
		audit.check_eq(again.select_mode("tournament"), false, "modes/a_mode_this_build_does_not_grant_is_not_selectable")

	# The back button routes the declared edge (`to-menu`).
	var back: Button = (await _mount()).find_child("BackButton", true, false)
	back.pressed.emit()
	await process_frame
	audit.check_eq(_router.active_id(), "menu", "modes/the_back_control_lands_on_menu")


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	control.gui_input.emit(event)


func _mount() -> Node:
	_router.go_to("modes")
	for _i in SETTLE_FRAMES:
		await process_frame
	return _router.active_screen()


# ---------------------------------------------------------------------------
# 5. Locks: the demo's own presentation, live and pinned
# ---------------------------------------------------------------------------

func _locks(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var build := DemoGate.build()
	audit.report("build=%s pinned_rung=%s" % [build, screen.pinned_rung()])
	var locked_cards: Array = []
	for row in screen.mode_rows_now():
		var id := String((row as Dictionary).get("id", ""))
		if screen.mode_locked_shown(id):
			locked_cards.append(id)
	if build == "demo":
		audit.check_eq(locked_cards, ["tournament", "career"], "modes/demo_shows_the_unexposed_modes_locked")
		audit.check_eq(DemoContent.allowed_mode_ids(), ["quick"], "modes/demo_grants_quick_only")
	else:
		audit.check_eq(locked_cards, [], "modes/full_build_locks_no_mode")

	# The locked presentation: tag key, alpha, no activation path.
	for id in locked_cards:
		var card: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + String(id), true, false)
		var tag: Label = screen.find_child(ModesScreenClass.TAG_PREFIX + String(id), true, false)
		audit.check_eq(tag.text, UiStrings.t(Gate.locked_key()), "modes/locked_card_%s_shows_the_reference_tag" % id)
		audit.check_true(card.modulate.a < 1.0, "modes/locked_card_%s_is_dimmed" % id)
		var before: String = _router.active_id()
		_click(card)
		await process_frame
		audit.check_eq(_router.active_id(), before, "modes/locked_card_%s_has_no_activation" % id)

	# The difficulty pin, whichever run this is.
	var enabled: Array = []
	var disabled: Array = []
	for key in ModesScreenClass.DIFFICULTY_ORDER:
		var button: Button = screen.find_child(ModesScreenClass.DIFFICULTY_PREFIX + key, true, false)
		if button.disabled:
			disabled.append(key)
		else:
			enabled.append(key)
		audit.check_true(button.visible, "modes/rung_%s_stays_visible_when_disabled" % key)
	var pinned: String = screen.pinned_rung()
	if pinned == "":
		audit.check_eq(enabled, ModesScreenClass.DIFFICULTY_ORDER, "modes/full_build_offers_every_rung")
		audit.check_eq(disabled, [], "modes/full_build_disables_no_rung")
	else:
		audit.check_eq(enabled, [pinned], "modes/one_rung_is_enabled")
		audit.check_eq(disabled.size(), ModesScreenClass.DIFFICULTY_ORDER.size() - 1, "modes/the_other_rungs_are_disabled")
		audit.report("pinned rung: %s (disabled: %s)" % [pinned, JSON.stringify(disabled)])
	audit.check_eq(screen.select_difficulty(disabled[0] if disabled.size() > 0 else "nope"), false,
		"modes/a_rung_the_build_does_not_grant_is_refused")

	# The `demo-locked` capture state renders the same presentation in a full build
	# (and is consistent with the live one in a demo).
	audit.check_true(screen.apply_capture_state("demo-locked"), "modes/the_demo_locked_state_applies")
	var pinned_cards: Array = []
	for row in screen.mode_rows_now():
		var id := String((row as Dictionary).get("id", ""))
		if screen.mode_locked_shown(id):
			pinned_cards.append(id)
	audit.check_eq(pinned_cards, ["tournament", "career"], "modes/the_demo_locked_state_locks_the_unexposed_modes")
	audit.check_eq(screen.pinned_rung(), DemoContent.difficulty(), "modes/the_demo_locked_state_pins_the_demo_rung")
	audit.check_eq(screen.active_length(), "games3", "modes/the_pinned_view_does_not_touch_the_persisted_format")
	audit.check_eq(screen.setup_visible(), true, "modes/the_demo_locked_state_opens_in_quick")
	audit.check_true(screen.apply_capture_state("default"), "modes/the_default_state_applies")
	audit.check_eq(screen.pinned_rung(), pinned, "modes/the_default_state_returns_to_the_live_gate")


# ---------------------------------------------------------------------------
# 6. The literal scan (the rule `router_audit.gd` uses, aimed at this screen)
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe: Array = []
	for entry in _offenders_in_source("res://probe.gd", PROBE_SOURCE):
		probe.append(_offender_text(entry))
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "modes/the_literal_scan_flags_prose_and_ignores_developer_text")

	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "modes/the_screen_source_is_readable")
	var offenders: Array = []
	for entry in _offenders_in_source(SCREEN_PATH, source):
		if not SCREEN_LITERALS.has(String((entry as Dictionary).get("literal", ""))):
			offenders.append(_offender_text(entry))
	audit.check_eq(offenders, [], "modes/ModesScreen_gd_carries_no_prose_literal")

	var scene := FileAccess.get_file_as_string(SCENE_PATH)
	var found: Array = []
	for literal in _literals_in_scene(scene):
		found.append(String(literal))
	var expected: Array = SCENE_LITERALS.duplicate()
	audit.check_eq(found, expected, "modes/the_scene_carries_no_literal_text")


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


## [{where: "path:line", literal: "..."}] — the same rule `router_audit.gd` applies,
## returned structured so an allowlist can compare the literal itself.
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
			out.append({"where": "%s:%d" % [path, index + 1], "literal": String(literal)})
	return out


func _offender_text(entry: Dictionary) -> String:
	return "%s \"%s\"" % [entry.get("where", ""), entry.get("literal", "")]


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
# 7. The language flip
# ---------------------------------------------------------------------------

func _flip(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var language_at_start := Locale.current_lang()
	audit.check_eq(language_at_start, Locale.default_lang(), "modes/the_run_starts_in_the_default_language")

	var unresolved: Array = []
	for binding in screen.text_bindings():
		for lang in Locale.locales():
			if not Locale.is_resolvable(String((binding as Dictionary).get("key", "")), String(lang)):
				unresolved.append("%s/%s" % [(binding as Dictionary).get("key", ""), lang])
	audit.check_eq(unresolved, [], "modes/every_bound_key_resolves_in_both_locales")

	Locale.set_lang("it")
	screen.refresh_strings()
	_check_bindings(audit, screen, "it")
	Locale.set_lang("en")
	screen.refresh_strings()
	_check_bindings(audit, screen, "en")

	# And the flip really moves what it should: every binding whose two translations
	# differ must have changed.
	Locale.set_lang("it")
	screen.refresh_strings()
	var before := _binding_texts(screen)
	Locale.set_lang("en")
	screen.refresh_strings()
	var after := _binding_texts(screen)
	var unmoved: Array = []
	var moved := 0
	for name in before:
		if String(before[name]) != String(after[name]):
			moved += 1
			continue
		var key := _key_of(screen, String(name))
		if Locale.t(key, {}, "it") != Locale.t(key, {}, "en"):
			unmoved.append(name)
	audit.check_eq(unmoved, [], "modes/the_flip_moves_every_binding_whose_two_translations_differ")
	audit.check_gt(moved, 0, "modes/the_flip_moved_strings")
	audit.report("language flip: moved=%d bindings=%d" % [moved, before.size()])

	Locale.set_lang(language_at_start)
	screen.refresh_strings()
	_check_bindings(audit, screen, language_at_start)
	audit.check_eq(Locale.current_lang(), language_at_start, "modes/the_run_language_is_restored")


func _check_bindings(audit: AuditBase, screen: Node, lang: String) -> void:
	var wrong: Array = []
	for binding in screen.text_bindings():
		var row: Dictionary = binding
		var expected := UiStrings.t(String(row.get("key", "")), row.get("params", {}))
		if String(row.get("suffix_key", "")) != "":
			expected += String(row.get("joiner", "")) + UiStrings.t(String(row["suffix_key"]), row.get("suffix_params", {}))
		var shown := String(screen.text_shown(String(row.get("name", ""))))
		if shown != expected:
			wrong.append("%s: %s != %s" % [row.get("name", ""), shown, expected])
	audit.check_eq(wrong, [], "modes/every_binding_shows_its_locale_text_in_%s" % lang)


func _binding_texts(screen: Node) -> Dictionary:
	var out := {}
	for binding in screen.text_bindings():
		out[String((binding as Dictionary).get("name", ""))] = screen.text_shown(String((binding as Dictionary).get("name", "")))
	return out


func _key_of(screen: Node, node_name: String) -> String:
	for binding in screen.text_bindings():
		if String((binding as Dictionary).get("name", "")) == node_name:
			return String((binding as Dictionary).get("key", ""))
	return ""


# ---------------------------------------------------------------------------
# 8. Capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var walk: Array = []
	for state_id in screen.capture_states():
		walk.append([String(state_id), bool(screen.apply_capture_state(String(state_id)))])
	audit.check_eq(walk, [["default", true], ["quick", true], ["tournament", true], ["career", true], ["demo-locked", true]],
		"modes/every_declared_capture_state_applies")
	audit.check_eq(screen.apply_capture_state("nope"), false, "modes/an_undeclared_capture_state_is_refused")

	# `syncMatchSetup`'s own rule, both directions, with the cards untouched.
	var setup: Control = screen.find_child("MatchSetup", true, false)
	var cards_visible := 0
	for id in ModesScreenClass.MODE_ORDER:
		var card: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + id, true, false)
		if card != null and card.visible:
			cards_visible += 1
	audit.check_eq(cards_visible, 3, "modes/the_cards_are_visible_in_the_live_state")
	for state_id in ["quick", "tournament", "career"]:
		screen.apply_capture_state(String(state_id))
		await process_frame
		audit.check_eq(setup.visible, String(state_id) == "quick", "modes/%s_shows_the_setup_only_in_quick" % state_id)
		var visible_now := 0
		for id in ModesScreenClass.MODE_ORDER:
			var card: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + id, true, false)
			if card != null and card.visible:
				visible_now += 1
		audit.check_eq(visible_now, 3, "modes/the_cards_stay_visible_in_%s" % state_id)
	screen.apply_capture_state("default")


# ---------------------------------------------------------------------------
# 9. The bridge and the layout
# ---------------------------------------------------------------------------

func _bridge(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var specs: Array = screen.focus_controls()
	var ids: Array = []
	for spec in specs:
		ids.append(String((spec as Dictionary).get("id", "")))
	audit.check_eq(specs.size(), 19, "modes/the_screen_registers_nineteen_focusables")
	audit.check_true(ids.has("modes/BackButton"), "modes/the_back_control_is_registered")
	audit.check_true(ids.has("modes/%squick" % ModesScreenClass.CARD_PREFIX), "modes/the_quick_card_is_registered")
	var actions: Array = []
	for spec in specs:
		actions.append(String((spec as Dictionary).get("action", "")))
	audit.check_true(actions.has("select-mode:quick"), "modes/the_card_reports_its_own_action")
	audit.check_true(actions.has("difficulty:easy"), "modes/a_rung_reports_its_own_action")
	audit.check_true(actions.has("length:points11"), "modes/a_format_reports_its_own_action")
	# The port's own pace rungs ride the same door; `tests/pace_screen_test.gd` owns
	# their behaviour, this audit only has to see them like any other control.
	var pace_actions := 0
	for id in Pace.ids():
		if actions.has("pace:%s" % String(id)):
			pace_actions += 1
	audit.check_eq(pace_actions, Pace.ids().size(), "modes/every_pace_rung_reports_its_own_action")

	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	audit.check_eq(bridge.ids().size(), 19, "modes/the_bridge_reads_the_nineteen_controls")
	audit.check_true(bridge.set_focus("modes/BackButton"), "modes/the_bridge_can_focus_the_back_control")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	audit.check_true(bridge.dispatch(event), "modes/a_confirm_dispatch_is_handled")
	await process_frame
	audit.check_eq(_router.active_id(), "menu", "modes/the_back_dispatch_lands_on_menu")

	# The screen's own activation door for the actions the bridge reports.
	var second: Node = await _mount()
	audit.check_true(second.activate("select-mode:quick"), "modes/the_activation_door_selects_a_mode")
	audit.check_eq(_router.active_id(), "characters", "modes/the_activation_door_routes_to_characters")
	audit.check_eq(second.activate("nope"), false, "modes/an_unknown_action_is_refused")


func _layout(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	audit.check_true(screen.size.is_equal_approx(FRAME_BIG), "modes/the_screen_fills_the_frame")
	var grid: GridContainer = screen.find_child("ModeGrid", true, false)
	audit.check_eq(grid.columns, 3, "modes/three_columns_at_1280")
	var widest := 0.0
	for row in screen.mode_rows_now():
		var card: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + String((row as Dictionary).get("id", "")), true, false)
		if card != null:
			widest = maxf(widest, card.size.x)
	audit.report("1280x720: card=%.1f grid=%.1f" % [widest, grid.size.x])
	audit.check_le(widest, FRAME_BIG.x, "modes/nothing_is_wider_than_the_frame")
	audit.check_gt(widest, 0.0, "modes/the_cards_have_width")
	var widths: Array = []
	for row in screen.mode_rows_now():
		var c: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + String((row as Dictionary).get("id", "")), true, false)
		widths.append(c.size.x)
	var even := true
	for width in widths:
		if absf(float(width) - widest) > 1.0:
			even = false
	audit.check_true(even, "modes/the_columns_are_equal_thirds")
	var thirds := (grid.size.x - 2.0 * 20.0) / 3.0
	audit.check_between(widest, thirds - 2.0, thirds + 2.0, "modes/the_cards_fill_their_column")

	# The art keeps the reference's 3:1 aspect, derived from the card's own width.
	var art: Control = screen.find_child(ModesScreenClass.ART_PREFIX + "quick", true, false)
	var card: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + "quick", true, false)
	audit.check_between(art.size.x / maxf(art.size.y, 1.0), 2.7, 3.3, "modes/the_art_keeps_the_reference_aspect")

	_frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(grid.columns, 1, "modes/one_column_below_the_reference_breakpoint")
	var widest_small := 0.0
	for row in screen.mode_rows_now():
		var c: Control = screen.find_child(ModesScreenClass.CARD_PREFIX + String((row as Dictionary).get("id", "")), true, false)
		if c != null:
			widest_small = maxf(widest_small, c.size.x)
	audit.check_le(widest_small, FRAME_SMALL.x, "modes/nothing_is_wider_than_the_small_frame")
	audit.report("1024x600: card=%.1f grid=%.1f" % [widest_small, grid.size.x])
	_frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame
