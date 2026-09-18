## screen_arena_audit.gd — UIR-12's contract audit: `screen-arena` in a real router.
##
## WHAT IT PROVES, each check the ticket's own rule:
##
##   1. the router mounts the screen, and the screen names itself and its way back;
##   2. the grid is the catalog the build lists, in the catalog's order, with the
##      renderer's own four sentences per card (`arena_<id>_desc`, `demoOnlyFull`,
##      `lockLabel`, `arenaOtherMatchday` / `arenaOtherRound`) and the badge the fixture
##      state puts on the card it chose (`arenaByCalendar` / `arenaByBracket`);
##   3. the three walls are read, not assumed: the build's (`demoLocked`, live in a demo,
##      pinned in a full build), the career's (`isUnlocked` — the frozen table carries no
##      arena `unlock`, and the audit says so instead of pretending) and the calendar's
##      (every non-fixture card switched off in career/tournament);
##   4. a switched-off card refuses the press, and a locked card refuses through the card
##      itself (the reference's handler is attached and guarded, `js/ui.js:1263-1271`);
##   5. the start path is the frozen contract: `Config.pending_mode` + `Config.arena_index`
##      + the scene today's call sites change to (`game/main_menu.gd:497`, `:502`), read
##      back out of that file in this audit rather than trusted to my own constant;
##   6. the player-mode panel is the quick match's (`js/main.js:1656`), its three options
##      persist through `prefs.playerMode`, its hint is `pmHint` and its active segment
##      follows the selection;
##   7. every bound string is the locale's, in both languages, with the zero-literal rule
##      scanned out of the screen source and the scene;
##   8. the five capture states apply, and each one is the state it names;
##   9. the header chrome is bound, not raw: `TitleLabel` / `SubLabel` / `BackButton`
##      show the locale's words, and the binding survives a grid rebuild (`_clear`
##      resets the list the whole screen shares, so the header is bound after the
##      grid is built — the 2026-09-18 screenshot read the keys themselves);
##  10. the world five are on the screen above the frozen nine: `world_arena_rows_now()`
##      is torii, medina, carioca, aurora, egeo in catalog order, each
##      `WorldArenaCard_<id>` exists, and `WorldGridArea` is a PREVIOUS sibling of
##      `GridArea` — while a demo build draws neither rows nor cards;
##  11. a locked card's wall is `lockLabel`'s own sentence (`js/ui.js:685-702`): the
##      count is interpolated and no card shows the raw "{n} {word}" template;
##  12. `activate_arena(id, apply_scene)` is the press's path: an open card starts the
##      match (quick, without touching the tree), a locked card refuses and moves
##      nothing, and a world card takes the world seat.

extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const ArenaScreenClass := preload("res://src/ui/screens/ArenaScreen.gd")
const ScreenRouter := preload("res://src/ui/ScreenRouter.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const MenuFocus := preload("res://game/menu_focus.gd")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Config := preload("res://game/match_config.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const Frozen := preload("res://src/sim/frozen.gd")

const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
## Lines carrying one of these are developer-facing by construction: `router_audit.gd`
## exempts them in the UI lane, so this audit exempts them the same way instead of
## pretending the lane is wider than it is.
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const MAIN_MENU_PATH := "res://game/main_menu.gd"

var _router: ScreenRouter = null
var _host: Control = null
var _store_dir: String = ""
var _previous_save_dir: String = ""
var _entry_mode: String = ""


func _initialize() -> void:
	var audit := AuditBase.new("UIR-12 ArenaScreen 1:1")
	_previous_save_dir = Config.save_dir
	_store_dir = "user://arena_audit_%d" % Time.get_ticks_usec()
	Config.save_dir = _store_dir
	_entry_mode = String(Config.pending_mode)
	await _run(audit)
	Config.pending_mode = _entry_mode
	_cleanup_store()
	quit(audit.finish())


func _cleanup_store() -> void:
	if _store_dir == "":
		return
	var absolute := ProjectSettings.globalize_path(_store_dir)
	DirAccess.remove_absolute(_store_dir)
	DirAccess.remove_absolute(absolute)
	Config.save_dir = _previous_save_dir


func _run(audit: AuditBase) -> void:
	await _facts(audit)
	await _grid(audit)
	await _locks(audit)
	await _calendar(audit)
	await _bracket(audit)
	await _start(audit)
	await _player_mode(audit)
	await _flip(audit)
	await _literals(audit)
	await _layout(audit)
	await _captures(audit)
	await _header(audit)
	await _world(audit)
	await _unlock_lines(audit)
	await _activation(audit)


# ---------------------------------------------------------------------------
# 1. The mount

func _mount() -> Node:
	if _host != null and _host.is_inside_tree():
		_host.queue_free()
	_host = Control.new()
	_host.name = "AuditHost"
	root.add_child(_host)
	_host.size = FRAME_BIG
	var router := ScreenRouter.new()
	router.name = "AuditRouter"
	for id in ScreenRouter.ids():
		router.register(String(id), PlaceholderScene)
	var arena_scene: PackedScene = load("res://src/ui/screens/ArenaScreen.tscn")
	router.register("arena", arena_scene)
	_host.add_child(router)
	router.size = FRAME_BIG
	_router = router
	router.go_to("arena")
	await process_frame
	await process_frame
	return router.active_screen()


func _screen() -> Node:
	if _router == null:
		return null
	return _router.active_screen()


func _facts(audit: AuditBase) -> void:
	audit.check_eq(ScreenRouter.ids().size(), 13, "arena/the_router_still_carries_thirteen_ids")
	var screen: Node = await _mount()
	audit.check_true(screen != null, "arena/the_screen_mounts")
	audit.check_eq(String(screen.screen_id()), "arena", "arena/the_screen_names_itself")
	audit.check_eq(String(screen.back_target()), "characters", "arena/the_screen_names_its_way_back")
	audit.check_eq(screen.capture_states(), ArenaScreenClass.CAPTURE_STATES, "arena/the_capture_states_are_the_declared_five")
	audit.check_true(screen.find_child("ArenaGrid", true, false) != null, "arena/the_grid_is_in_the_scene")
	audit.check_true(screen.find_child("PlayerModePanel", true, false) != null, "arena/the_player_mode_panel_is_in_the_scene")


# ---------------------------------------------------------------------------
# 2. The catalog

func _grid(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var ids: Array = []
	for arena in Frozen.arenas():
		ids.append(String((arena as Dictionary).get("id", "")))
	audit.check_eq(ids.size(), 9, "arena/the_frozen_catalog_has_nine_arenas")
	var rows: Array = screen.arena_rows_now()
	audit.check_eq(rows.size(), 9, "arena/the_grid_lists_the_whole_catalog")
	var shown: Array = []
	var missing: Array = []
	for row in rows:
		var id := String((row as Dictionary).get("id", ""))
		shown.append(id)
		for prefix in [ArenaScreenClass.CARD_PREFIX, ArenaScreenClass.ART_PREFIX, ArenaScreenClass.NAME_PREFIX,
				ArenaScreenClass.LINE_PREFIX, ArenaScreenClass.BADGE_PREFIX, ArenaScreenClass.LOCK_PREFIX]:
			if screen.find_child(String(prefix) + id, true, false) == null:
				missing.append(String(prefix) + id)
	audit.check_eq(shown, ids, "arena/the_grid_is_the_catalog_in_order")
	audit.check_eq(missing, [], "arena/every_card_carries_its_own_nodes")

	# The names and the descriptions are the catalog's own keys, bound and resolved.
	var first := String(ids[0])
	audit.check_eq(screen.text_shown(ArenaScreenClass.NAME_PREFIX + first), UiStrings.t("arena_%s_name" % first),
		"arena/a_card_is_named_by_its_key")
	# A card the build opens carries the catalog's description; one it withholds carries the
	# sentence that says so (already read in the lock walk). The demo opens nothing but its
	# own one, so the reading follows the walls rather than the catalog's order.
	var open := String(ids[0])
	for row in screen.arena_rows_now():
		if not bool((row as Dictionary).get("locked", false)):
			open = String((row as Dictionary).get("id", ""))
			break
	audit.check_eq(screen.text_shown(ArenaScreenClass.LINE_PREFIX + open), UiStrings.t("arena_%s_desc" % open),
		"arena/an_open_card_carries_its_description")
	var art := screen.find_child(ArenaScreenClass.ART_PREFIX + open + "Texture", true, false) as TextureRect
	audit.check_true(art != null and art.texture != null, "arena/the_card_carries_its_art")

	# The accent and the art come off the frozen table the renderer reads (`arena.palette.accent`).
	var accent := ""
	var image := ""
	for arena in Frozen.arenas():
		if String((arena as Dictionary).get("id", "")) == first:
			var palette: Dictionary = (arena as Dictionary).get("palette", {})
			accent = String(palette.get("accent", ""))
			image = String((arena as Dictionary).get("image", ""))
	audit.check_true(accent != "" and image != "", "arena/the_frozen_table_carries_the_accent_and_the_art")
	audit.report("first arena %s accent %s art %s" % [first, accent, image])


# ---------------------------------------------------------------------------
# 3. The three walls

func _locks(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var withheld := _build_withheld_ids()
	audit.report("build=%s withheld=%d of 9 arenas" % [DemoGate.build(), withheld.size()])
	var live := _expected_locked_ids(false)
	audit.report("live walls: %d of 9 (build=%s, career-walled: %d)" % [live.size(), DemoGate.build(), _expected_locked_ids(false).size()])
	audit.check_eq(_sorted(screen.locked_ids()), live, "arena/the_live_walls_are_the_two_rules_added_up")
	if DemoGate.build() == "demo":
		audit.check_ge(screen.locked_ids().size(), withheld.size(), "arena/a_demo_is_at_least_as_closed_as_its_table")
	else:
		audit.check_true(screen.apply_capture_state("demo-locked"), "arena/the_demo_locked_state_applies")
		var pinned := _expected_locked_ids(true)
		audit.check_eq(_sorted(screen.locked_ids()), pinned, "arena/the_pinned_state_locks_what_the_table_withholds")
		audit.check_ge(pinned.size(), withheld.size(), "arena/the_pinned_wall_covers_the_table")
		var locked_id := String(withheld[0])
		audit.check_eq(screen.arena_card_state(locked_id), "locked", "arena/the_pinned_card_says_it_is_locked")
		audit.check_true(screen.arena_locked_shown(locked_id), "arena/the_pinned_card_shows_the_badge")
		audit.check_eq(screen.text_shown(ArenaScreenClass.LINE_PREFIX + locked_id), UiStrings.t("demoOnlyFull"),
			"arena/a_build_locked_card_says_so_with_the_builds_own_sentence")
		audit.check_eq(screen.select_arena(locked_id), false, "arena/a_build_locked_card_refuses_the_press")
		var card := screen.find_child(ArenaScreenClass.CARD_PREFIX + locked_id, true, false) as Control
		audit.check_true(card != null, "arena/the_locked_card_is_there_to_be_pressed")
		_card_click(card, locked_id)
		audit.check_true(screen.selected_arena_id() != locked_id, "arena/the_locked_card_refuses_through_its_own_card")
		audit.check_true(screen.apply_capture_state("default"), "arena/the_live_state_returns")

	# The career's wall: no arena carries an `unlock` in the frozen table, and the audit
	# says so rather than inventing a lock to prove.
	var with_unlock := 0
	for arena in Frozen.arenas():
		if (arena as Dictionary).get("unlock") is Dictionary:
			with_unlock += 1
	audit.report("arenas carrying an unlock wall in the frozen table: %d" % with_unlock)
	var open_id := ""
	for row in screen.arena_rows_now():
		if not bool((row as Dictionary).get("locked", false)):
			open_id = String((row as Dictionary).get("id", ""))
			break
	audit.check_true(open_id != "", "arena/the_build_exposes_at_least_one_arena_to_read")
	audit.check_eq(screen.arena_card_state(open_id), "selectable", "arena/an_unlocked_arena_is_selectable")


func _card_click(card: Control, arena_id: String) -> void:
	if card == null:
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card.gui_input.emit(click)


# ---------------------------------------------------------------------------
# 4. The calendar's own choice

func _calendar(audit: AuditBase) -> void:
	var store := Config.save_store()
	var career: Dictionary = ModesSave.load_career(store)
	var available := _career_selectable_arenas()
	var fixture: Dictionary = CareerRules.career_fixture(int(career.get("season", 1)), int(career.get("matchIndex", 0)), available)
	var arena: Dictionary = fixture.get("arena", {})
	var expected_id := String(arena.get("id", ""))
	audit.report("career pool: %d arenas, fixture %s" % [available.size(), expected_id])
	audit.check_true(expected_id != "", "arena/the_career_fixture_names_an_arena")

	Config.pending_mode = "career"
	var screen: Node = await _mount()
	audit.check_eq(screen.wording_mode(), "career", "arena/career_speaks_the_calendars_language")
	audit.check_eq(screen.in_program_id(), expected_id, "arena/the_calendar_names_the_arena_in_program")
	audit.check_eq(screen.arena_card_state(expected_id), "in_program", "arena/the_fixture_card_is_in_program")
	audit.check_true(screen.arena_badge_shown(expected_id), "arena/the_fixture_card_carries_its_badge")
	audit.check_eq(screen.text_shown(ArenaScreenClass.BADGE_PREFIX + expected_id), UiStrings.t("arenaByCalendar"),
		"arena/the_badge_says_the_calendar_chose_it")
	# A build that opens one arena only has no switched-off card to read: the report says
	# so instead of the audit inventing one.
	var others: Array = screen.out_of_matchday_ids()
	audit.report("out of the matchday: %d cards (%s)" % [others.size(), JSON.stringify(others)])
	if others.is_empty():
		audit.check_eq(screen.in_program_id(), expected_id, "arena/a_one_arena_build_still_names_the_fixture")
	else:
		audit.check_eq(screen.arena_card_state(String(others[0])), "out_of_matchday",
			"arena/the_other_arenas_are_out_of_the_matchday")
		audit.check_eq(screen.text_shown(ArenaScreenClass.LINE_PREFIX + String(others[0])),
			UiStrings.t("arenaOtherMatchday"), "arena/an_out_of_matchday_card_says_why")
		var other := String(others[0])
		audit.check_eq(screen.select_arena(other), false, "arena/a_switched_off_card_refuses_the_press")
		var other_card := screen.find_child(ArenaScreenClass.CARD_PREFIX + other, true, false) as Control
		_card_click(other_card, other)
		audit.check_eq(screen.selected_arena_id(), "" if screen.selected_arena_id() != expected_id else expected_id,
			"arena/a_switched_off_card_carries_no_handler")
	audit.check_eq(screen.player_mode_visible(), false, "arena/the_player_mode_panel_is_the_quick_matches")
	audit.check_eq(screen.select_arena(expected_id), true, "arena/the_fixture_card_is_selectable")
	audit.check_eq(screen.start_arena_id(), expected_id, "arena/career_starts_on_the_calendars_arena")


func _bracket(audit: AuditBase) -> void:
	var store := Config.save_store()
	var round := ModesSave.tournament_round(store)
	var available := _career_selectable_arenas()
	var fixture: Dictionary = CareerRules.tournament_fixture(round, available)
	var arena: Dictionary = fixture.get("arena", {})
	var expected_id := String(arena.get("id", ""))
	audit.check_true(expected_id != "", "arena/the_bracket_fixture_names_an_arena")

	Config.pending_mode = "tournament"
	var screen: Node = await _mount()
	audit.check_eq(screen.wording_mode(), "tournament", "arena/a_tournament_speaks_the_brackets_language")
	audit.check_eq(screen.in_program_id(), expected_id, "arena/the_bracket_names_the_arena_in_program")
	audit.check_eq(screen.text_shown(ArenaScreenClass.BADGE_PREFIX + expected_id), UiStrings.t("arenaByBracket"),
		"arena/the_badge_says_the_bracket_chose_it")
	var others: Array = screen.out_of_matchday_ids()
	if others.is_empty():
		audit.report("the bracket's arena is the only exposed one in this build: no switched-off card to read")
	else:
		audit.check_eq(screen.text_shown(ArenaScreenClass.LINE_PREFIX + String(others[0])), UiStrings.t("arenaOtherRound"),
			"arena/an_out_of_round_card_says_why")
	audit.check_eq(screen.start_arena_id(), expected_id, "arena/a_tournament_starts_on_the_brackets_arena")
	audit.check_eq(screen.player_mode_visible(), false, "arena/the_panel_is_hidden_in_a_tournament_too")


# ---------------------------------------------------------------------------
# 5. The start path

func _start(audit: AuditBase) -> void:
	Config.pending_mode = "quick"
	ModesSave.save_pref(Config.save_store(), "playerMode", "solo")
	var screen: Node = await _mount()
	var selectable: Array = []
	for row in screen.arena_rows_now():
		if not bool((row as Dictionary).get("locked", false)):
			selectable.append(String((row as Dictionary).get("id", "")))
	audit.check_ge(selectable.size(), 1, "arena/the_build_exposes_at_least_one_arena")
	var chosen := String(selectable[0])
	audit.check_eq(screen.select_arena(chosen), true, "arena/an_exposed_arena_is_selectable")
	audit.check_eq(screen.selected_arena_id(), chosen, "arena/the_press_moves_the_sessions_choice")

	var payload: Dictionary = screen.start_payload()
	audit.report("start payload: %s" % JSON.stringify(payload))
	for key in ["mode", "arena_id", "arena_index", "player_mode", "scene"]:
		audit.check_true(payload.has(key), "arena/the_payload_carries_%s" % key)
	audit.check_eq(String(payload["mode"]), "quick", "arena/a_quick_start_says_quick")
	audit.check_eq(String(payload["scene"]), ArenaScreenClass.MATCH_SCENE, "arena/a_quick_start_changes_to_the_match_scene")
	audit.check_eq(String(payload["arena_id"]), chosen, "arena/a_quick_start_carries_the_chosen_arena")
	audit.check_eq(int(payload["arena_index"]), _index_of(chosen), "arena/the_payload_indexes_the_frozen_catalog")
	audit.check_eq(String(payload["player_mode"]), "solo", "arena/the_payload_carries_the_player_mode")

	# The contract is not this screen's invention: the file that starts matches today
	# changes to these two scenes, read here rather than trusted.
	var source := FileAccess.get_file_as_string(MAIN_MENU_PATH)
	audit.check_true(source != "", "arena/the_existing_call_site_is_readable")
	audit.check_true(source.contains(ArenaScreenClass.MATCH_SCENE), "arena/the_match_scene_is_the_one_already_used")
	audit.check_true(source.contains(ArenaScreenClass.MODE_SCENE), "arena/the_mode_scene_is_the_one_already_used")

	audit.check_eq(screen.start_match(false), true, "arena/the_quick_start_runs_without_touching_the_tree")
	audit.check_eq(Config.arena_index, _index_of(chosen), "arena/the_start_writes_the_session_index")
	audit.check_eq(String(Config.pending_mode), "quick", "arena/the_start_preserves_the_pending_mode")

	# In career the start ignores the choice, like `startMatch` ignores `ui.selectedArena`.
	Config.pending_mode = "career"
	var career_screen: Node = await _mount()
	var fixture: Dictionary = CareerRules.career_fixture(
		int(ModesSave.load_career(Config.save_store()).get("season", 1)),
		int(ModesSave.load_career(Config.save_store()).get("matchIndex", 0)), _career_selectable_arenas())
	var fixture_id := String((fixture.get("arena", {}) as Dictionary).get("id", ""))
	audit.check_eq(career_screen.start_match(false), true, "arena/a_career_start_runs")
	audit.check_eq(Config.arena_index, _index_of(fixture_id), "arena/a_career_start_uses_the_calendars_arena")
	audit.check_eq(String(career_screen.start_payload()["scene"]), ArenaScreenClass.MODE_SCENE,
		"arena/a_career_start_goes_through_the_mode_route")
	Config.pending_mode = _entry_mode


## The reference's `selectableArenas()` (`js/ui.js:490-492`): the build's filter and the
## career's wall, read here through the frozen table and `CareerRules.is_unlocked`.
func _career_selectable_arenas() -> Array:
	var career: Dictionary = ModesSave.load_career(Config.save_store())
	var out: Array = []
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		var id := String(entry.get("id", ""))
		if DemoGate.build() == "demo" and not DemoContent.allowed_arena_ids().has(id):
			continue
		if CareerRules.is_unlocked(entry, career):
			out.append(entry)
	return out


func _index_of(arena_id: String) -> int:
	var index := 0
	for arena in Frozen.arenas():
		if String((arena as Dictionary).get("id", "")) == arena_id:
			return index
		index += 1
	return -1


# ---------------------------------------------------------------------------
# 6. The player-mode panel

func _player_mode(audit: AuditBase) -> void:
	Config.pending_mode = "quick"
	ModesSave.save_pref(Config.save_store(), "playerMode", "solo")
	var screen: Node = await _mount()
	audit.check_eq(screen.player_mode(), "solo", "arena/the_session_defaults_to_one_player")
	audit.check_eq(screen.player_mode_visible(), true, "arena/the_panel_is_the_quick_matches")
	audit.check_eq(screen.hint_key(), "pmHint", "arena/the_hint_is_the_references_own_key")
	audit.check_eq(screen.text_shown("PlayerModeHint"), UiStrings.t("pmHint"), "arena/the_hint_is_the_locales_sentence")
	audit.check_eq(screen.text_shown("PlayerModeLabel"), UiStrings.t("playerMode"), "arena/the_panel_names_itself")
	for key in ["solo", "coop", "pvp"]:
		audit.check_eq(screen.text_shown(ArenaScreenClass.MODE_PREFIX + key), UiStrings.t(String(ArenaScreenClass.MODE_KEYS[key])),
			"arena/the_option_%s_is_the_locales_word" % key)

	var theme: Theme = screen.theme
	var cyan: Color = theme.get_color("cyan", "Palette") if theme != null and theme.has_color("cyan", "Palette") else Color.BLACK
	var solo_button := screen.find_child(ArenaScreenClass.MODE_PREFIX + "solo", true, false) as Button
	var coop_button := screen.find_child(ArenaScreenClass.MODE_PREFIX + "coop", true, false) as Button
	var solo_before := solo_button.get_theme_stylebox("normal")
	audit.check_eq(String(ModesSave.profile(Config.save_store()).get("prefs", {}).get("playerMode", "")), "solo",
		"arena/the_reference_keeps_the_player_mode_in_the_preferences")
	audit.check_eq(screen.select_player_mode("coop"), true, "arena/the_co_op_option_is_selectable")
	audit.check_eq(screen.player_mode(), "coop", "arena/the_choice_moves_the_session")
	audit.check_eq(String(ModesSave.profile(Config.save_store()).get("prefs", {}).get("playerMode", "")), "coop",
		"arena/the_choice_is_persisted_through_the_save")
	audit.check_true(coop_button.get_theme_stylebox("normal") != solo_before, "arena/the_active_segment_is_the_chosen_one")
	var coop_box := coop_button.get_theme_stylebox("normal") as StyleBoxFlat
	audit.check_eq(coop_box.border_color, cyan, "arena/the_active_segment_carries_the_accent_token")
	audit.check_eq(screen.select_player_mode("pvp"), true, "arena/the_local_versus_option_is_selectable")
	audit.check_eq(String(ModesSave.profile(Config.save_store()).get("prefs", {}).get("playerMode", "")), "pvp",
		"arena/the_versus_choice_is_persisted")
	audit.check_eq(screen.select_player_mode("duo"), false, "arena/an_invented_player_mode_is_refused")
	audit.check_eq(screen.player_mode(), "pvp", "arena/a_refused_option_changes_nothing")
	audit.check_eq(screen.select_player_mode("solo"), true, "arena/the_choice_comes_back_to_one_player")


# ---------------------------------------------------------------------------
# 7. The strings

func _flip(audit: AuditBase) -> void:
	Config.pending_mode = "quick"
	var screen: Node = await _mount()
	var language_at_start := Locale.current_lang()
	for lang in Locale.locales():
		Locale.set_lang(String(lang))
		screen.refresh_strings()
		var wrong: Array = []
		var unknown: Array = []
		for binding in screen.text_bindings():
			var entry: Dictionary = binding
			var key := String(entry.get("key", ""))
			if not Locale.is_resolvable(key, String(lang)):
				unknown.append(key)
			var expected := String(entry.get("prefix", "")) + UiStrings.t(key, entry.get("params", {}))
			if String(entry.get("suffix_key", "")) != "":
				expected += String(entry.get("joiner", "")) + UiStrings.t(String(entry["suffix_key"]), entry.get("suffix_params", {}))
			if screen.text_shown(String(entry.get("name", ""))) != expected:
				wrong.append(String(entry.get("name", "")))
		audit.check_eq(unknown, [], "arena/every_bound_key_resolves_%s" % lang)
		audit.check_eq(wrong, [], "arena/every_binding_shows_the_locales_text_%s" % lang)

	Locale.set_lang("it")
	screen.refresh_strings()
	var before := _texts(screen)
	Locale.set_lang("en")
	screen.refresh_strings()
	var after := _texts(screen)
	var moved := 0
	var unmoved: Array = []
	for binding in screen.text_bindings():
		var name := String((binding as Dictionary).get("name", ""))
		if String(before.get(name, "")) != String(after.get(name, "")):
			moved += 1
		elif Locale.t(String((binding as Dictionary).get("key", "")), {}, "it") != Locale.t(String((binding as Dictionary).get("key", "")), {}, "en"):
			unmoved.append(name)
	audit.check_gt(moved, 0, "arena/the_flip_moved_strings")
	audit.check_eq(unmoved, [], "arena/the_flip_moves_every_binding_whose_two_translations_differ")
	audit.report("flip moved %d of %d bindings" % [moved, screen.text_bindings().size()])
	Locale.set_lang(language_at_start)
	screen.refresh_strings()


func _texts(screen: Node) -> Dictionary:
	var out := {}
	for binding in screen.text_bindings():
		var name := String((binding as Dictionary).get("name", ""))
		out[name] = screen.text_shown(name)
	return out


# ---------------------------------------------------------------------------
# 8. The literal scan

func _literals(audit: AuditBase) -> void:
	var source := FileAccess.get_file_as_string("res://src/ui/screens/ArenaScreen.gd")
	audit.check_true(source != "", "arena/the_screen_source_is_readable")
	var probe := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"arenaTitle\")\n## a comment quoting \"prose in a comment\"\n"
	audit.check_eq(_offenders_in_source("res://probe.gd", probe), ["res://probe.gd:2 \"Play now\""],
		"arena/the_scan_catches_prose_and_spares_developers")
	audit.check_eq(_offenders_in_source("res://src/ui/screens/ArenaScreen.gd", source), [],
		"arena/arena_screen_gd_carries_no_prose_literal")
	audit.check_eq(_scene_literals("res://src/ui/screens/ArenaScreen.tscn"), [],
		"arena/arena_screen_tscn_carries_no_literal")


func _offenders_in_source(path: String, source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		var developer := false
		for marker in DEVELOPER_MARKERS:
			if code.contains(String(marker)):
				developer = true
				break
		if developer:
			continue
		for literal in _string_literals(code):
			if String(literal).contains(" "):
				out.append("%s:%d \"%s\"" % [path, index + 1, literal])
	return out


## A scene's `text = "…"` may carry a locale key (the lane's own idiom: the scene names
## the key, the screen resolves it) and nothing else. A literal that is not a key is the
## prose the lane forbids.
func _scene_literals(path: String) -> Array:
	var out: Array = []
	var source := FileAccess.get_file_as_string(path)
	for line in source.split("\n"):
		var text := String(line).strip_edges()
		if not text.begins_with("text = "):
			continue
		var literal := text.trim_prefix("text = ").strip_edges().trim_prefix("\"").trim_suffix("\"")
		if literal != "" and not Locale.is_resolvable(literal, "en"):
			out.append(literal)
	return out


func _string_literals(code: String) -> Array:
	var out: Array = []
	var parts := code.split("\"")
	for index in range(1, parts.size(), 2):
		out.append(parts[index])
	return out


# ---------------------------------------------------------------------------
# 9. Layout and the bridge

func _layout(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var grid := screen.find_child("ArenaGrid", true, false) as GridContainer
	audit.check_true(grid != null, "arena/the_grid_is_a_grid")
	audit.check_eq(grid.columns, ArenaScreenClass.GRID_COLUMNS, "arena/the_grid_is_three_wide_at_1280")
	var first_id := String((screen.arena_rows_now()[0] as Dictionary).get("id", ""))
	var preview := screen.find_child(ArenaScreenClass.ART_PREFIX + first_id, true, false) as Control
	var card := screen.find_child(ArenaScreenClass.CARD_PREFIX + first_id, true, false) as Control
	audit.report("1280x720 card=%s preview=%s grid=%s" % [card.size, preview.size, grid.size])
	audit.check_between(preview.size.x / maxf(preview.size.y, 1.0), 1.6, 1.9, "arena/the_preview_keeps_the_reference_aspect")
	audit.check_le(card.size.x, screen.size.x, "arena/a_card_fits_the_frame")

	screen.size = FRAME_SMALL
	await process_frame
	audit.check_eq(grid.columns, ArenaScreenClass.SMALL_COLUMNS, "arena/the_grid_is_one_wide_at_1024")
	audit.report("1024x600 card=%s preview=%s grid=%s" % [card.size, preview.size, grid.size])
	audit.check_le(card.size.x, screen.size.x, "arena/a_card_still_fits_the_small_frame")

	var bridge := Bridge.new()
	var focus := MenuFocus.new()
	bridge.attach(screen, focus, _router)
	audit.check_gt(bridge.ids().size(), 0, "arena/the_focus_bridge_reads_the_screens_controls")
	audit.check_true(bridge.has("arena/BackButton"), "arena/the_bridge_reaches_the_back_control")
	audit.check_true(bridge.has("arena/" + ArenaScreenClass.CARD_PREFIX + first_id), "arena/the_bridge_reaches_the_cards")
	audit.check_true(bridge.has("arena/" + ArenaScreenClass.MODE_PREFIX + "coop"), "arena/the_bridge_reaches_the_player_modes")
	audit.check_true(bridge.set_focus("arena/BackButton"), "arena/the_back_control_takes_the_focus")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	audit.check_true(bridge.dispatch(event), "arena/the_back_control_can_be_pressed_through_the_bridge")
	await process_frame
	audit.check_eq(String(_router.active_id()), "characters", "arena/the_back_control_lands_on_the_screen_it_names")


# ---------------------------------------------------------------------------
# 10. Capture states

func _captures(audit: AuditBase) -> void:
	Config.pending_mode = "quick"
	ModesSave.save_pref(Config.save_store(), "playerMode", "solo")
	var screen: Node = await _mount()
	for state in ArenaScreenClass.CAPTURE_STATES:
		audit.check_eq(screen.apply_capture_state(String(state)), true, "arena/the_%s_state_applies" % state)
	audit.check_eq(screen.apply_capture_state("invented"), false, "arena/an_undeclared_state_is_refused")
	audit.check_eq(screen.capture_states().size(), 5, "arena/the_five_states_are_the_declared_five")

	audit.check_true(screen.apply_capture_state("career-calendar"), "arena/the_calendar_state_applies_again")
	audit.check_eq(screen.wording_mode(), "career", "arena/the_calendar_state_speaks_the_calendar")
	audit.check_true(screen.in_program_id() != "", "arena/the_calendar_state_names_a_fixture")
	audit.check_eq(screen.player_mode_visible(), false, "arena/the_calendar_state_hides_the_panel")

	audit.check_true(screen.apply_capture_state("tournament-bracket"), "arena/the_bracket_state_applies_again")
	audit.check_eq(screen.wording_mode(), "tournament", "arena/the_bracket_state_speaks_the_bracket")

	audit.check_true(screen.apply_capture_state("demo-locked"), "arena/the_demo_state_applies_again")
	audit.check_eq(_sorted(screen.locked_ids()), _expected_locked_ids(true), "arena/the_demo_state_shows_the_builds_wall")

	audit.check_true(screen.apply_capture_state("player-mode-coop"), "arena/the_co_op_state_applies_again")
	audit.check_eq(screen.player_mode(), "coop", "arena/the_co_op_state_selects_co_op")

	audit.check_true(screen.apply_capture_state("default"), "arena/the_default_state_applies_again")
	audit.check_eq(screen.wording_mode(), "quick", "arena/the_default_state_returns_to_quick")
	audit.check_eq(_sorted(screen.locked_ids()), _expected_locked_ids(false),
		"arena/the_default_state_returns_to_the_live_walls")
	audit.check_eq(screen.player_mode_visible(), true, "arena/the_default_state_shows_the_panel")


## What this build's two walls add up to, re-derived from the frozen table, the demo
## table and `CareerRules.is_unlocked` — never from what the screen just told us.
func _expected_locked_ids(pin_demo: bool) -> Array:
	var career: Dictionary = ModesSave.load_career(Config.save_store())
	var out: Array = []
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		var id := String(entry.get("id", ""))
		var build_locked := false
		if pin_demo or DemoGate.build() == "demo":
			build_locked = not DemoContent.allowed_arena_ids().has(id)
		if build_locked or not CareerRules.is_unlocked(entry, career):
			out.append(id)
	out.sort()
	return out


func _sorted(ids: Array) -> Array:
	var out: Array = ids.duplicate()
	out.sort()
	return out


func _build_withheld_ids() -> Array:
	var out: Array = []
	for arena in Frozen.arenas():
		var id := String((arena as Dictionary).get("id", ""))
		if not DemoContent.allowed_arena_ids().has(id):
			out.append(id)
	return out


# ---------------------------------------------------------------------------
# 9. The header is bound, not raw

func _header(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var title: String = String(screen.text_shown("TitleLabel"))
	var sub: String = String(screen.text_shown("SubLabel"))
	var back: String = String(screen.text_shown("BackButton"))
	audit.report("header: title=%s sub=%s back=%s" % [title, sub, back])
	audit.check_eq(title, UiStrings.t("arenaTitle"), "arena/the_title_is_the_locales_word")
	audit.check_ne(title, "arenaTitle", "arena/the_title_is_not_the_raw_key")
	audit.check_eq(sub, UiStrings.t("arenaSub"), "arena/the_subtitle_is_the_locales_word")
	audit.check_ne(sub, "arenaSub", "arena/the_subtitle_is_not_the_raw_key")
	audit.check_eq(back, UiStrings.t("back"), "arena/the_back_control_is_the_locales_word")
	audit.check_ne(back, "back", "arena/the_back_control_is_not_the_raw_key")

	# `_build_grid` clears the binding list the whole screen shares: a header bound
	# before it would flip back to its key on the next refresh. A capture state is a
	# full rebuild, so it is the honest way to ask.
	audit.check_true(screen.apply_capture_state("career-calendar"), "arena/the_calendar_state_applies_to_a_fresh_header")
	audit.check_eq(screen.text_shown("TitleLabel"), UiStrings.t("arenaTitle"), "arena/the_title_survives_a_grid_rebuild")
	audit.check_true(screen.apply_capture_state("default"), "arena/the_live_state_returns_after_the_header_read")


# ---------------------------------------------------------------------------
# 10. The world five, on screen above the frozen nine

func _world(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var ids: Array = []
	for row in screen.world_arena_rows_now():
		ids.append(String((row as Dictionary).get("id", "")))
	var five := ["torii", "medina", "carioca", "aurora", "egeo"]
	if DemoGate.build() == "demo":
		audit.report("demo build: world rows=%d" % ids.size())
		audit.check_eq(ids, [], "arena/a_demo_offers_no_world_arena")
		audit.check_true(screen.find_child(ArenaScreenClass.WORLD_CARD_PREFIX + "*", true, false) == null,
			"arena/a_demo_builds_no_world_card")
		audit.check_true(screen.find_child(ArenaScreenClass.WORLD_AREA, true, false) == null,
			"arena/a_demo_builds_no_world_area")
		return
	audit.report("world rows: %s" % JSON.stringify(ids))
	audit.check_eq(ids, five, "arena/the_world_five_are_on_screen_in_catalog_order")
	for id in five:
		audit.check_true(screen.find_child(ArenaScreenClass.WORLD_CARD_PREFIX + String(id), true, false) != null,
			"arena/the_world_card_%s_is_on_screen" % id)
	var area := screen.find_child(ArenaScreenClass.WORLD_AREA, true, false)
	var frozen := screen.find_child(ArenaScreenClass.GRID_AREA_NODE, true, false)
	audit.check_true(area != null and frozen != null, "arena/both_grid_blocks_are_in_the_body")
	if area != null and frozen != null:
		audit.report("Body children: WorldGridArea#%d GridArea#%d" % [area.get_index(), frozen.get_index()])
		audit.check_true(area.get_parent() == frozen.get_parent() and area.get_index() < frozen.get_index(),
			"arena/the_world_block_sits_above_the_frozen_block")
		audit.check_true(area.visible, "arena/the_world_block_is_shown")


# ---------------------------------------------------------------------------
# 11. A locked card's wall is lockLabel's sentence

func _unlock_lines(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var read := 0
	for row in screen.arena_rows_now():
		var entry: Dictionary = row
		var id := String(entry.get("id", ""))
		if not bool(entry.get("locked", false)) or bool(entry.get("demo_locked", false)):
			continue
		var unlock := _unlock_of(id)
		if unlock.is_empty():
			continue
		var line: String = String(screen.text_shown(ArenaScreenClass.LINE_PREFIX + id))
		var trophies := int(unlock.get("trophies", 0))
		var count := trophies if trophies > 0 else int(unlock.get("stars", 0))
		audit.report("%s: %s" % [id, line])
		read += 1
		audit.check_true(not line.contains("{"), "arena/the_locked_line_of_%s_shows_no_raw_template" % id)
		audit.check_true(line.contains(str(count)), "arena/the_locked_line_of_%s_shows_its_count" % id)
	if DemoGate.build() == "demo":
		audit.report("a demo words its walls demoOnlyFull: no counted unlock line to read")
	else:
		audit.check_gt(read, 0, "arena/the_build_shows_a_counted_unlock_wall_to_read")


## The frozen table's own unlock wall for an id (`Frozen.arenas()[…].unlock`), read here
## rather than trusted to the screen's copy of it.
func _unlock_of(arena_id: String) -> Dictionary:
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		if String(entry.get("id", "")) == arena_id and entry.get("unlock") is Dictionary:
			return entry["unlock"]
	return {}


# ---------------------------------------------------------------------------
# 12. The press's path: activate_arena

func _activation(audit: AuditBase) -> void:
	Config.pending_mode = "quick"
	ModesSave.save_pref(Config.save_store(), "playerMode", "solo")
	var screen: Node = await _mount()
	var open_ids: Array = []
	var walled: Array = []
	for row in screen.arena_rows_now():
		var entry: Dictionary = row
		var id := String(entry.get("id", ""))
		if bool(entry.get("locked", false)):
			walled.append(id)
		else:
			open_ids.append(id)
	audit.report("open=%s walled=%s" % [JSON.stringify(open_ids), JSON.stringify(walled)])
	audit.check_ge(open_ids.size(), 1, "arena/the_build_exposes_a_card_to_activate")
	audit.check_ge(walled.size(), 1, "arena/the_build_keeps_a_card_to_refuse")

	var chosen := String(open_ids[0])
	audit.check_eq(screen.activate_arena(chosen, false), true, "arena/an_open_card_activates_without_touching_the_tree")
	audit.check_eq(Config.arena_id(), chosen, "arena/the_activation_writes_the_session_arena")
	audit.check_eq(String(Config.pending_mode), "quick", "arena/the_activation_keeps_the_pending_mode_quick")
	audit.check_eq(screen.selected_arena_id(), chosen, "arena/the_activation_moves_the_sessions_choice")
	var card := screen.find_child(ArenaScreenClass.CARD_PREFIX + chosen, true, false) as Control
	audit.check_true(card != null and card.gui_input.get_connections().size() > 0,
		"arena/the_open_card_carries_the_press_handler")

	var refused := String(walled[0])
	var index_before := Config.arena_index
	var world_before := Config.world_arena_id
	var selected_before: String = String(screen.selected_arena_id())
	audit.check_eq(screen.activate_arena(refused, false), false, "arena/a_locked_card_refuses_activation")
	audit.check_eq(Config.arena_index, index_before, "arena/the_refusal_does_not_start_a_match")
	audit.check_eq(Config.world_arena_id, world_before, "arena/the_refusal_does_not_take_a_world_seat")
	audit.check_eq(screen.selected_arena_id(), selected_before, "arena/the_refusal_leaves_the_choice_where_it_was")
	audit.check_eq(screen.activate_arena("invented_arena", false), false, "arena/an_invented_arena_is_refused")

	# The world half (full build): the same call takes the world seat the ported
	# column's world row takes (`Config.set_arena_id`).
	var world_ids: Array = []
	for row in screen.world_arena_rows_now():
		world_ids.append(String((row as Dictionary).get("id", "")))
	if world_ids.is_empty():
		audit.report("demo build: no world card to activate")
		return
	var world_id := String(world_ids[0])
	audit.check_eq(screen.activate_arena(world_id, false), true, "arena/a_world_card_activates_without_touching_the_tree")
	audit.check_eq(Config.world_arena_id, world_id, "arena/the_world_activation_takes_the_world_seat")
	audit.check_eq(Config.arena_id(), world_id, "arena/the_world_activation_names_the_world_arena")
	var world_card := screen.find_child(ArenaScreenClass.WORLD_CARD_PREFIX + world_id, true, false) as Control
	audit.check_true(world_card != null and world_card.gui_input.get_connections().size() > 0,
		"arena/the_world_card_carries_the_press_handler")
