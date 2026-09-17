## screen_history_audit.gd — UIR-14's contract audit: the history screen against a
## constructed profile in a temp store.
##
## WHAT IT PROVES, and why each check is the reference's own question:
##
##   1. the router still carries the thirteen ids and the screen mounts through it;
##   2. an EMPTY profile renders the reference's own empty state
##      (`js/ui.js:1585-1588`: three zeroed boxes and one `histEmpty` line);
##   3. a POPULATED profile renders one row per entry, with the reference's own lines
##      (`js/ui.js:1596-1604`) — mode + `histVs` + the opponent's resolved name, the
##      `athlete · arena` line, the score and a `dd/mm` date;
##   4. the cap is the save lane's own (`Schema.HISTORY_CAP`, `js/ui.js:1551`): 25
##      recorded matches leave 20 and the screen shows 20;
##   5. the screen is READ-ONLY: the store's files are byte-identical before and after a
##      refresh, and the screen's source carries no writer's name;
##   6. a language flip re-renders (the labels and the composed lines);
##   7. zero user-facing literals in the screen and its scene;
##   8. the layout holds at 1280x720 and 1024x600 and the two blocks stay inside the
##      reference's own `min(720px, 100%)` (`styles.css:2632-2640`);
##   9. both declared capture states walk.
##
## CONSTRUCTED STATE, labeled: every entry this audit reads was written by
## `ModesSave.record_match` into `user://uir14-history-audit`, and the directory is
## removed at the end. The real `user://save` profile is never opened for write.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/HistoryScreen.gd")
const ScreenScene := preload("res://src/ui/screens/HistoryScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const Schema := preload("res://src/save/save_schema.gd")

const SCREEN_PATH := "res://src/ui/screens/HistoryScreen.gd"
const SCENE_PATH := "res://src/ui/screens/HistoryScreen.tscn"
const TEMP_DIR := "user://uir14-history-audit"

const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)

## The reference's own cap (`js/ui.js:1551`, `save_store.gd:128-129`).
const CAP := 20
const OVERFILL := 25

## The three writers a screen could reach for, named so the read-only check fails on a
## screen that grows one.
const WRITE_MARKERS := ["write_group(", "write_history(", "save_career", "record_match(", "save_pref(", "write_drill_record(", "write_all("]

## `1700000000` is 2023-11-14 in UTC; the screen's date is `dd/mm` from the entry's own
## `ts` (the reference's intl form has no ported equivalent — recorded in the log).
const FIXED_TS := 1700000000
const FIXED_DATE := "14/11"

const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"historyTitle\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("screen_history")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	# The harness never applies the stored language pref (`js/main.js:2292-2294` does it at
	# boot) and the engine's own default is `DEFAULT_LANG = "en"`, so the run pins the
	# reference's fallback table first: the flip below then really moves the screen's own
	# strings between the two tables, and the flip back really restores them.
	Locale.set_lang("it")
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "ScreenHistoryAuditFrame"
	frame.size = FRAME_BIG
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame

	await _mount(audit)
	await _empty(audit)
	await _populated(audit)
	await _cap(audit)
	await _read_only(audit)
	await _strings(audit)
	await _captures(audit)
	await _layout(audit)
	_literal_scan(audit)
	audit.report("temp store: %s (%d entries) — the real user:// profile was never written" % [TEMP_DIR, ModesSave.load_history(_store).size()])


func _screen() -> Node:
	return _router.active_screen()


func _entry(index: int, winner: String = "player", mode: String = "quick") -> Dictionary:
	return ModesSave.history_entry(
		mode, "maestro", "officina", "rivale", "coop", winner,
		"6-4", 6, false, 1, FIXED_TS + index
	)


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "history/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "history/all_thirteen_slots_register")
	audit.check_true(_router.register("history", ScreenScene), "history/the_scene_registers_under_the_history_id")
	audit.check_eq(_router.go_to("history", {"store": _store}), true, "history/go_to_mounts_the_screen")
	await process_frame
	var screen: Node = _screen()
	audit.check_true(screen is ScreenClass, "history/the_mounted_scene_carries_HistoryScreen_gd")
	audit.check_true(screen.theme != null, "history/the_scene_mounts_the_theme")
	audit.check_eq(screen.store().dir, TEMP_DIR, "history/the_screen_reads_the_temp_store")
	audit.check_eq(screen.screen_id(), "history", "history/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), Router.back_target_of("history"), "history/the_declared_return_is_the_router_table_s")
	audit.check_eq(String(screen.get("router_id")), "history", "history/the_screen_kept_the_router_fact")
	audit.check_eq(Array(screen.capture_states()), ["empty", "populated"], "history/the_two_declared_capture_states")
	audit.check_eq(screen.apply_capture_state("nope"), false, "history/an_undeclared_capture_state_is_refused")


# ---------------------------------------------------------------------------
# 2. The empty page (`js/ui.js:1582-1588`)
# ---------------------------------------------------------------------------

func _empty(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.refresh()
	audit.check_eq(screen.row_count(), 0, "history/an_empty_store_shows_no_rows")
	audit.check_eq(screen.stat_values(), ["0", "0", "0"], "history/the_three_boxes_read_zero")
	audit.check_eq(screen.stat_labels(), [UiStrings.t("histWins"), UiStrings.t("histLosses"), UiStrings.t("histTrophies")],
		"history/the_boxes_carry_the_reference_s_own_labels")
	var empty: Label = screen.find_child(ScreenClass.EMPTY_NODE, true, false)
	audit.check_true(empty != null, "history/the_empty_state_is_a_row_of_its_own")
	audit.check_eq(String(empty.text), UiStrings.t("histEmpty"), "history/and_it_is_the_reference_s_own_line")


# ---------------------------------------------------------------------------
# 3. The populated page (`js/ui.js:1590-1604`)
# ---------------------------------------------------------------------------

func _populated(audit: AuditBase) -> void:
	var screen: Node = _screen()
	ModesSave.record_match(_store, _entry(0, "player", "quick"))
	ModesSave.record_match(_store, _entry(1, "opponent", "tournament"))
	ModesSave.record_match(_store, _entry(2, "player", "career"))
	screen.refresh()
	audit.check_eq(screen.row_count(), 3, "history/three_recorded_matches_are_three_rows")
	var entries: Array = screen.entries()
	audit.check_eq(String(entries[0].get("mode", "")), "career", "history/the_newest_entry_is_the_first_row")
	var summary: Dictionary = UiData.history_summary(_store)
	audit.check_eq(screen.stat_values(), [str(summary["wins"]), str(summary["losses"]), str(summary["trophies"])],
		"history/the_boxes_are_the_adapter_s_own_counts")
	# Row 0: the newest is the career win. Its lines, composed the way the screen
	# composes them (the separator comes from the locale lane's declared rules).
	# `_entry` records every row with `human_mode = "coop"`, so the reference's own
	# `${modeBase} · ${hm}` segment is part of the line (`js/ui.js:1594-1596`).
	var row0: Node = screen.find_child("HistoryList", true, false).get_node_or_null("Row0")
	audit.check_true(row0 != null, "history/the_first_row_exists")
	var sep := String(screen.composed_separator())
	audit.check_true(sep != "", "history/the_composed_separator_is_the_locale_lane_s_own")
	var mode_line := String((row0.get_node("Main/Mode") as Label).text)
	var mode_base := UiStrings.t("careerMatch") + sep + UiStrings.t("hmCoop")
	var expected_mode := "%s %s %s" % [
		mode_base, UiStrings.t("histVs"), screen.opponent_name("rivale"),
	]
	audit.check_eq(mode_line, expected_mode, "history/the_mode_line_is_mode_plus_vs_plus_the_resolved_opponent")
	audit.check_true(mode_line.contains(UiStrings.t("histVs")), "history/and_it_carries_the_reference_s_vs_word")
	var who_line := String((row0.get_node("Main/Who") as Label).text)
	audit.check_eq(who_line, "%s%s%s" % [UiStrings.t("athlete_maestro_name"), sep, UiStrings.t("arena_officina_name")],
		"history/the_second_line_is_the_athlete_and_the_arena")
	audit.check_eq(String((row0.get_node("Meta/Score") as Label).text), "6-4", "history/the_score_is_the_entry_s_own")
	audit.check_eq(String((row0.get_node("Meta/Date") as Label).text), FIXED_DATE, "history/the_date_is_dd_slash_mm_in_utc")
	var badge := String((row0.get_node("Badge") as Label).text)
	audit.check_eq(badge, UiStrings.t("histWin"), "history/a_player_win_carries_the_win_badge")
	# The human-mode suffix (`js/ui.js:1594`).
	var coop := ModesSave.history_entry("quick", "maestro", "officina", "maestro", "pvp", "player", "6-0", 6, false, 1, FIXED_TS + 9)
	ModesSave.record_match(_store, coop)
	screen.refresh()
	var newest: Node = screen.find_child("HistoryList", true, false).get_node_or_null("Row0")
	var coop_line := String((newest.get_node("Main/Mode") as Label).text)
	audit.check_true(coop_line.contains(UiStrings.t("hmPvp")), "history/a_pvp_entry_carries_its_human_mode_suffix")
	audit.check_true(coop_line.contains(UiStrings.t("quickMatch")), "history/and_its_own_mode_word")
	audit.check_true(screen.opponent_name("maestro") != "", "history/an_athlete_opponent_resolves_through_the_athlete_family")


# ---------------------------------------------------------------------------
# 4. The cap is the save lane's own (`js/ui.js:1551`)
# ---------------------------------------------------------------------------

func _cap(audit: AuditBase) -> void:
	var screen: Node = _screen()
	for index in OVERFILL:
		ModesSave.record_match(_store, _entry(index + 10, "player", "quick"))
	audit.check_eq(ModesSave.load_history(_store).size(), CAP, "history/the_store_keeps_the_reference_s_twenty")
	audit.check_eq(int(Schema.HISTORY_CAP), CAP, "history/the_cap_is_the_schema_s_own_constant")
	screen.refresh()
	audit.check_eq(screen.row_count(), CAP, "history/and_the_screen_renders_every_entry_it_is_given")
	audit.report("cap: recorded %d, stored %d, rendered %d" % [OVERFILL + 4, ModesSave.load_history(_store).size(), screen.row_count()])


# ---------------------------------------------------------------------------
# 5. Read-only, proven two ways
# ---------------------------------------------------------------------------

func _read_only(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var before := _fingerprint()
	screen.refresh()
	screen.apply_capture_state("empty")
	screen.apply_capture_state("populated")
	var after := _fingerprint()
	audit.check_eq(after, before, "history/refreshing_and_walking_the_states_rewrote_nothing")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	var offenders: Array = []
	for marker in WRITE_MARKERS:
		if source.contains(marker):
			offenders.append(marker)
	audit.check_eq(offenders, [], "history/the_screen_source_names_no_writer")


## Every file in the temp store, path -> sha256, as one sorted list.
func _fingerprint() -> Array:
	var out: Array = []
	var absolute := ProjectSettings.globalize_path(TEMP_DIR)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return out
	for file in dir.get_files():
		var path := "%s/%s" % [absolute, file]
		out.append("%s %s" % [file, FileAccess.get_sha256(path)])
	out.sort()
	return out


# ---------------------------------------------------------------------------
# 6. Strings and the language flip
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var original := Locale.current_lang()
	var label_before := String(screen.stat_labels()[0])
	var row_before := String((screen.find_child("HistoryList", true, false).get_node("Row0/Main/Mode") as Label).text)
	audit.check_eq(label_before, UiStrings.t("histWins"), "history/the_first_box_label_is_the_locale_text")
	Locale.set_lang("en")
	screen.refresh()
	audit.check_true(String(screen.stat_labels()[0]) != label_before, "history/the_english_box_label_differs")
	var row_en := String((screen.find_child("HistoryList", true, false).get_node("Row0/Main/Mode") as Label).text)
	audit.check_true(row_en != row_before, "history/and_the_mode_line_is_re_rendered")
	audit.check_eq(String(screen.title_control().text), UiStrings.t("historyTitle"), "history/the_title_follows_the_language")
	Locale.set_lang(original)
	screen.refresh()
	audit.check_eq(String(screen.stat_labels()[0]), label_before, "history/the_flip_back_restores_the_first_text")


# ---------------------------------------------------------------------------
# 7. Capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	audit.check_eq(screen.apply_capture_state("empty"), true, "history/the_empty_state_applies")
	audit.check_eq(screen.row_count(), 0, "history/and_hides_the_rows")
	audit.check_true(screen.find_child(ScreenClass.EMPTY_NODE, true, false) != null, "history/and_shows_the_empty_line")
	audit.check_eq(screen.apply_capture_state("populated"), true, "history/the_populated_state_applies")
	audit.check_eq(screen.row_count(), CAP, "history/and_restores_the_store_s_own_rows")


# ---------------------------------------------------------------------------
# 8. Layout at both declared sizes
# ---------------------------------------------------------------------------

func _layout(audit: AuditBase) -> void:
	var frame: Control = _router.get_parent()
	var screen: Node = _screen()
	var big := _measure(screen)
	audit.report("1280x720: widest=%.1f stats=%.1f list=%.1f" % [big["widest"], big["stats_width"], big["list_width"]])
	audit.check_true(big["widest"] <= FRAME_BIG.x, "history/nothing_is_wider_than_the_frame")
	audit.check_le(big["stats_width"], 720.0, "history/the_boxes_stay_inside_the_reference_s_720px")
	audit.check_le(big["list_width"], 720.0, "history/the_list_stays_inside_it_too")
	frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	var small := _measure(screen)
	audit.report("1024x600: widest=%.1f stats=%.1f list=%.1f" % [small["widest"], small["stats_width"], small["list_width"]])
	audit.check_true(small["widest"] <= FRAME_SMALL.x, "history/nothing_is_wider_than_the_small_frame")
	frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame


func _measure(screen: Node) -> Dictionary:
	var stats: Control = screen.find_child(ScreenClass.STATS_NODE, true, false)
	var list: Control = screen.find_child(ScreenClass.LIST_NODE, true, false)
	var widest := maxf(stats.size.x, list.size.x)
	for child in stats.get_children():
		widest = maxf(widest, (child as Control).size.x)
	return {"widest": widest, "stats_width": stats.size.x, "list_width": list.size.x}


# ---------------------------------------------------------------------------
# 9. The literal scan, and the theme tokens this screen names
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "history/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "history/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "history/HistoryScreen_gd_carries_no_prose_literal")
	var scene_literals: Array = []
	for literal in _literals_in_scene(FileAccess.get_file_as_string(SCENE_PATH)):
		scene_literals.append(String(literal))
	audit.check_eq(scene_literals, [], "history/the_scene_carries_no_literals")
	var screen: Node = _screen()
	var theme: Theme = screen.theme
	var missing: Array = []
	for key in screen.palette_keys():
		if not theme.has_color(String(key), "Palette"):
			missing.append(String(key))
	audit.check_eq(missing, [], "history/the_theme_carries_every_palette_key_the_screen_names")
	audit.check_eq(screen.palette_misses(), [], "history/the_screen_recorded_no_missing_palette_key")


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


func _wipe() -> void:
	var absolute := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for file in dir.get_files():
		DirAccess.remove_absolute("%s/%s" % [absolute, file])
	DirAccess.remove_absolute(absolute)
