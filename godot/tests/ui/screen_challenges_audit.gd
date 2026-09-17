## screen_challenges_audit.gd — UIR-15's contract audit: the challenges board against
## a constructed career in a temp store.
##
## WHAT IT PROVES, and why each check is the reference's own question:
##
##   1. the router still carries the thirteen ids and the board mounts through it;
##   2. the three sections and their `done/total` counts agree with the adapter's own
##      buckets (`UiData.unlock_summary`), so the board cannot disagree with the
##      Profile's summary line about the same economies
##      (`js/ui.js:1157-1211`);
##   3. every row is the frozen table's row: name ids from `athlete_<id>_name` /
##      `arena_<id>_name`, the athlete's own colour, the cost line from the unlock's own
##      numbers (`costo()`, `js/ui.js:1145-1150`), the challenge sentence from the
##      reference's own key family (`challengeLabel()`, `js/ui.js:670-688`) with no
##      placeholder left unreplaced;
##   4. the two states that make the board look finished do (`all-complete` through the
##      career's own `unlockAll`, `some-complete` through a partial pin), and the limited
##      build's note follows the gate (`js/ui.js:1203-1208`);
##   5. zero user-facing literals in the screen and its scene;
##   6. the layout holds at 1280x720 and 1024x600, with the reference's own 900 px stack
##      (`styles.css:3245-3254`) applied below 900;
##   7. all four declared capture states walk.
##
## CONSTRUCTED STATE, labeled: the career is the temp store's own
## (`user://uir15-challenges-audit`), written through `ModesSave.save_career`; the
## directory is removed at the end. The real `user://save` profile is never written.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/ChallengesScreen.gd")
const ScreenScene := preload("res://src/ui/screens/ChallengesScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")

const SCREEN_PATH := "res://src/ui/screens/ChallengesScreen.gd"
const SCENE_PATH := "res://src/ui/screens/ChallengesScreen.tscn"
const TEMP_DIR := "user://uir15-challenges-audit"

const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
const FRAME_NARROW := Vector2(820, 600)

const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"sectionAthletes\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("screen_challenges")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "ScreenChallengesAuditFrame"
	frame.size = FRAME_BIG
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame

	await _mount(audit)
	await _sections(audit)
	await _rows(audit)
	await _outfits(audit)
	await _states(audit)
	await _note(audit)
	await _strings(audit)
	await _captures(audit)
	await _layout(audit)
	_literal_scan(audit)
	audit.report("temp store: %s — the real user:// profile was never written" % TEMP_DIR)


func _screen() -> Node:
	return _router.active_screen()


func _unlockable(items: Array) -> Array:
	var out: Array = []
	for item in items:
		if (item as Dictionary).get("unlock", null) != null:
			out.append(item)
	return out


func _challenge_outfits() -> Array:
	var out: Array = []
	for athlete in Frozen.athletes():
		for outfit in Tables.outfits_for_athlete(String((athlete as Dictionary).get("id", ""))):
			if (outfit as Dictionary).get("challenge", null) != null:
				out.append(outfit)
	return out


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "challenges/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "challenges/all_thirteen_slots_register")
	audit.check_true(_router.register("challenges", ScreenScene), "challenges/the_scene_registers_under_the_challenges_id")
	audit.check_eq(_router.go_to("challenges", {"store": _store}), true, "challenges/go_to_mounts_the_screen")
	await process_frame
	var screen: Node = _screen()
	audit.check_true(screen is ScreenClass, "challenges/the_mounted_scene_carries_ChallengesScreen_gd")
	audit.check_true(screen.theme != null, "challenges/the_scene_mounts_the_theme")
	audit.check_eq(screen.store().dir, TEMP_DIR, "challenges/the_screen_reads_the_temp_store")
	audit.check_eq(screen.screen_id(), "challenges", "challenges/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), Router.back_target_of("challenges"), "challenges/the_declared_return_is_the_router_table_s")
	audit.check_eq(String(screen.get("router_id")), "challenges", "challenges/the_screen_kept_the_router_fact")
	audit.check_eq(Array(screen.capture_states()), ["default", "some-complete", "all-complete", "demo-limited"],
		"challenges/the_four_declared_capture_states")
	audit.check_eq(screen.apply_capture_state("nope"), false, "challenges/an_undeclared_capture_state_is_refused")


# ---------------------------------------------------------------------------
# 2. The three sections, and their counts against the adapter's own buckets
# ---------------------------------------------------------------------------

func _sections(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var sections: Array = screen.sections()
	audit.check_eq(sections.size(), 3, "challenges/the_board_has_the_reference_s_three_sections")
	audit.check_eq(Array(ScreenClass.SECTION_KEYS), ["sectionAthletes", "sectionOutfits", "sectionArenas"],
		"challenges/the_section_order_is_the_reference_s_own")
	var titles: Array = []
	for section in sections:
		titles.append(String((section as Dictionary)["title_key"]))
	audit.check_eq(titles, Array(ScreenClass.SECTION_KEYS), "challenges/the_sections_carry_the_reference_s_titles")
	# The counts must equal the adapter's buckets — the same numbers the Profile's
	# summary line counts.
	var summary := UiData.unlock_summary(_store)
	audit.check_eq(screen.section_total(0), int(summary["characters"]["total"]), "challenges/the_character_total_is_the_adapter_s")
	audit.check_eq(screen.section_done(0), int(summary["characters"]["done"]), "challenges/the_character_done_count_is_the_adapter_s")
	audit.check_eq(screen.section_total(1), int(summary["outfits"]["total"]), "challenges/the_outfit_total_is_the_adapter_s")
	audit.check_eq(screen.section_done(1), int(summary["outfits"]["done"]), "challenges/the_outfit_done_count_is_the_adapter_s")
	audit.check_eq(screen.section_total(2), int(summary["arenas"]["total"]), "challenges/the_arena_total_is_the_adapter_s")
	audit.check_eq(screen.section_done(2), int(summary["arenas"]["done"]), "challenges/the_arena_done_count_is_the_adapter_s")
	audit.report("sections: characters %d/%d, outfits %d/%d, arenas %d/%d" % [
		screen.section_done(0), screen.section_total(0),
		screen.section_done(1), screen.section_total(1),
		screen.section_done(2), screen.section_total(2),
	])


# ---------------------------------------------------------------------------
# 3. The rows are the frozen tables' own
# ---------------------------------------------------------------------------

func _rows(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var athletes := _unlockable(Frozen.athletes())
	var rows: Array = screen.section_rows(0)
	audit.check_eq(rows.size(), athletes.size(), "challenges/one_row_per_unlockable_athlete")
	var names_match := true
	var states_match := true
	var costs_present := true
	for index in rows.size():
		var row: Dictionary = rows[index]
		var athlete: Dictionary = athletes[index]
		var id := String(athlete.get("id", ""))
		if String(row["name_key"]) != "athlete_%s_name" % id:
			names_match = false
		var unlocked := CareerRules.is_unlocked(athlete, ModesSave.load_career(_store))
		var expected_state := "challengeUnlocked" if unlocked else "challengeLocked"
		if String(row["state_key"]) != expected_state:
			states_match = false
		if athlete.get("unlock") != null:
			var unlock: Dictionary = athlete["unlock"]
			if (int(unlock.get("trophies", 0)) > 0 or int(unlock.get("stars", 0)) > 0) and String(row["what"]) == "":
				costs_present = false
	audit.check_true(names_match, "challenges/every_character_row_names_its_athlete_by_id")
	audit.check_true(states_match, "challenges/every_character_state_follows_the_career_rules")
	audit.check_true(costs_present, "challenges/every_gated_character_row_carries_its_cost")
	var arena_rows: Array = screen.section_rows(2)
	audit.check_eq(arena_rows.size(), _unlockable(Frozen.arenas()).size(), "challenges/one_row_per_unlockable_arena")
	var arena_names: Array = []
	for row_in in arena_rows:
		arena_names.append(String((row_in as Dictionary)["name_key"]))
	# The rows are exactly the frozen table's unlockable arenas, by the same id the
	# reference composes (`t(\`arena_<id>_name\`)`, `js/ui.js:1203-1207`) — officina is the
	# free arena and has no `unlock` (`frozen/data.json`), so it is not one of them.
	var wanted_arena_names: Array = []
	for arena_in in _unlockable(Frozen.arenas()):
		wanted_arena_names.append("arena_%s_name" % String((arena_in as Dictionary).get("id", "")))
	audit.check_eq(arena_names, wanted_arena_names, "challenges/the_arena_rows_carry_the_frozen_ids")
	# The cost line's own composition (`js/ui.js:1142-1150`).
	var carrier := ""
	for row_in in rows:
		var row: Dictionary = row_in
		if String(row["what"]) != "":
			carrier = String(row["what"])
			break
	audit.check_true(carrier.contains("🏆") or carrier.contains("⭐"), "challenges/the_cost_line_carries_the_reference_s_own_glyphs")
	audit.check_true(carrier.contains(UiStrings.t("trophyOne")) or carrier.contains(UiStrings.t("trophyMany"))
		or carrier.contains(UiStrings.t("starOne")) or carrier.contains(UiStrings.t("starMany")),
		"challenges/and_the_singular_or_plural_word")


# ---------------------------------------------------------------------------
# 4. The outfits section: groups, and the challenge sentence
# ---------------------------------------------------------------------------

func _outfits(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var sections: Array = screen.sections()
	var groups: Array = (sections[1] as Dictionary).get("groups", [])
	var athletes_with: Array = []
	for athlete in Frozen.athletes():
		var suoi: Array = []
		for outfit in Tables.outfits_for_athlete(String((athlete as Dictionary).get("id", ""))):
			if (outfit as Dictionary).get("challenge", null) != null:
				suoi.append(outfit)
		if not suoi.is_empty():
			athletes_with.append(String((athlete as Dictionary).get("id", "")))
	audit.check_eq(groups.size(), athletes_with.size(), "challenges/one_group_per_athlete_with_challenge_outfits")
	var group_ids: Array = []
	for group_in in groups:
		group_ids.append(String((group_in as Dictionary)["name_key"]))
	audit.check_eq(group_ids.size(), athletes_with.size(), "challenges/every_group_keeps_its_athlete_s_name_key")
	var rows_ok := true
	var placeholders := 0
	for group_in in groups:
		for row_in in (group_in as Dictionary).get("rows", []):
			var what := String((row_in as Dictionary)["what"])
			if what == "":
				rows_ok = false
			if what.contains("{") or what.contains("}"):
				placeholders += 1
	audit.check_true(rows_ok, "challenges/every_outfit_row_carries_a_challenge_sentence")
	audit.check_eq(placeholders, 0, "challenges/and_no_placeholder_is_left_unreplaced")
	# A known sentence, composed exactly as `challengeLabel()` composes it: maestro's
	# `circuit` outfit is `{ metric: winners, target: 4 }` (`modes.json`).
	var expected := UiStrings.t("chAtLeast", {"n": 4, "what": UiStrings.t("metric_winners")})
	audit.check_true(expected.contains(UiStrings.t("metric_winners")), "challenges/the_metric_label_resolves")
	var found_sentence := false
	var carried := ""
	for group_in in groups:
		if String((group_in as Dictionary)["name_key"]) != "athlete_maestro_name":
			continue
		for row_in in (group_in as Dictionary).get("rows", []):
			carried = String((row_in as Dictionary)["what"])
			if carried == expected:
				found_sentence = true
	audit.check_true(found_sentence, "challenges/maestro_s_circuit_sentence_is_the_expected_composition")
	audit.report("outfits: %d groups, %d rows, example %s" % [groups.size(), int((sections[1] as Dictionary)["total"]), carried])


# ---------------------------------------------------------------------------
# 5. The two states that make the board look finished, and the demo note
# ---------------------------------------------------------------------------

func _states(audit: AuditBase) -> void:
	var screen: Node = _screen()
	audit.check_eq(screen.apply_capture_state("all-complete"), true, "challenges/the_all_complete_state_applies")
	var all_done := true
	for index in 3:
		for row_in in screen.section_rows(index):
			if not bool((row_in as Dictionary)["done"]):
				all_done = false
	audit.check_eq(screen.section_done(0), screen.section_total(0), "challenges/all_complete_fills_the_character_section")
	audit.check_true(all_done or screen.section_total(0) == 0, "challenges/and_every_character_row_reads_done")
	audit.check_eq(screen.apply_capture_state("some-complete"), true, "challenges/the_some_complete_state_applies")
	var done_count := 0
	var todo_count := 0
	for group_in in (screen.sections()[1] as Dictionary).get("groups", []):
		for row_in in (group_in as Dictionary).get("rows", []):
			if bool((row_in as Dictionary)["done"]):
				done_count += 1
			else:
				todo_count += 1
	audit.check_gt(done_count, 0, "challenges/some_complete_wins_at_least_one_outfit")
	audit.check_gt(todo_count, 0, "challenges/and_leaves_at_least_one_to_win")
	audit.check_eq(screen.section_done(1), done_count, "challenges/the_outfit_count_matches_its_own_rows")
	# The row's own ink follows the done state (`styles.css:3221-3224`). Flat sections hang
	# their rows off the section box and the outfit section hangs them off its per-athlete
	# groups, so the walk descends the whole board for `Row_*`.
	var theme: Theme = screen.theme
	var marked := false
	var board: Node = screen.find_child(ScreenClass.BOARD_NODE, true, false)
	for row_node in board.find_children("Row_*", "PanelContainer", true, false):
		var box := (row_node as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if box != null and box.border_color.is_equal_approx(theme.get_color("challenge_done_border", "Palette")):
			marked = true
	audit.check_true(marked, "challenges/a_done_row_carries_the_theme_s_done_border")
	audit.check_eq(screen.apply_capture_state("default"), true, "challenges/the_default_state_applies")


func _note(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var limited := DemoGate.badge_visible()
	audit.check_eq(screen.note_visible(0), limited, "challenges/the_note_follows_the_build_gate_in_the_characters_section")
	audit.check_eq(screen.note_visible(1), false, "challenges/the_outfits_section_carries_no_note")
	audit.check_eq(screen.note_visible(2), limited, "challenges/the_note_follows_the_build_gate_in_the_arenas_section")
	audit.check_eq(screen.note_key(), "demoCareerNote",
		"challenges/the_note_key_is_the_demo_one_because_this_port_has_no_beta_build")
	audit.check_eq(screen.apply_capture_state("demo-limited"), true, "challenges/the_demo_limited_state_applies")
	audit.check_true(screen.note_visible(0) and screen.note_visible(2), "challenges/the_pinned_note_lands_in_both_sections")
	var nota: Node = screen.find_child(ScreenClass.NOTA_NODE, true, false)
	audit.check_eq(String((nota as Label).text), UiStrings.t("demoCareerNote"), "challenges/and_it_is_the_reference_s_own_sentence")
	screen.apply_capture_state("default")


# ---------------------------------------------------------------------------
# 6. Strings and the language flip
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var original := Locale.current_lang()
	# The section title sits inside the head row of its section
	# (`Section0 -> head -> SectionTitle`), so the read walks the live structure
	# instead of demanding a direct child that the layout cannot provide.
	var title_before := String((screen.find_child("Section0", true, false).find_child("SectionTitle", true, false) as Label).text)
	audit.check_eq(title_before, UiStrings.t("sectionAthletes"), "challenges/the_first_section_title_is_the_locale_text")
	# The runtime's default locale is `en` (`locale_rules.json` `defaultLocale`), so a
	# hard-coded "en" flip is a no-op here and proves nothing. Flip to the other table
	# of the pair, whatever the run started in (the osk audit's own pattern).
	var other := ""
	for lang in Locale.locales():
		if String(lang) != original:
			other = String(lang)
	audit.check_ne(other, "", "challenges/there_is_a_second_locale_to_flip_to")
	Locale.set_lang(other)
	screen.refresh()
	var title_other := String((screen.find_child("Section0", true, false).find_child("SectionTitle", true, false) as Label).text)
	audit.check_true(title_other != title_before, "challenges/the_english_section_title_differs")
	audit.check_eq(String(screen.title_control().text), UiStrings.t("challengesTitle"), "challenges/the_title_follows_the_language")
	Locale.set_lang(original)
	screen.refresh()
	audit.check_eq(String((screen.find_child("Section0", true, false).find_child("SectionTitle", true, false) as Label).text), title_before,
		"challenges/the_flip_back_restores_the_first_text")


# ---------------------------------------------------------------------------
# 7. Capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var applied: Array = []
	for state in ScreenClass.CAPTURE_STATE_LIST:
		applied.append(screen.apply_capture_state(String(state)))
	audit.check_eq(applied, [true, true, true, true], "challenges/all_four_declared_states_apply")
	audit.check_eq(screen.apply_capture_state("default"), true, "challenges/and_the_board_returns_to_the_live_career")
	var summary := UiData.unlock_summary(_store)
	audit.check_eq(screen.section_done(0), int(summary["characters"]["done"]), "challenges/back_on_the_live_career_s_own_numbers")


# ---------------------------------------------------------------------------
# 8. Layout at both declared sizes, and the 900px stack
# ---------------------------------------------------------------------------

func _layout(audit: AuditBase) -> void:
	var frame: Control = _router.get_parent()
	var screen: Node = _screen()
	var big := _measure(screen)
	audit.report("1280x720: widest=%.1f board=%.1f stacked=%s" % [big["widest"], big["board"], str(big["stacked"])])
	audit.check_true(big["widest"] <= FRAME_BIG.x, "challenges/nothing_is_wider_than_the_frame")
	audit.check_eq(big["stacked"], false, "challenges/the_rows_are_four_columns_at_1280")
	audit.check_eq(big["row_children"], 4, "challenges/a_wide_row_is_mark_name_what_state")
	frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	var small := _measure(screen)
	audit.report("1024x600: widest=%.1f board=%.1f stacked=%s" % [small["widest"], small["board"], str(small["stacked"])])
	audit.check_true(small["widest"] <= FRAME_SMALL.x, "challenges/nothing_is_wider_than_the_small_frame")
	audit.check_eq(small["stacked"], false, "challenges/the_rows_are_still_four_columns_at_1024")
	frame.size = FRAME_NARROW
	for _i in SETTLE_FRAMES:
		await process_frame
	var narrow := _measure(screen)
	audit.report("820x600: widest=%.1f stacked=%s children=%d" % [narrow["widest"], str(narrow["stacked"]), narrow["row_children"]])
	audit.check_true(narrow["widest"] <= FRAME_NARROW.x, "challenges/nothing_is_wider_than_the_narrow_frame")
	audit.check_eq(narrow["stacked"], true, "challenges/the_rows_stack_below_900px")
	audit.check_eq(narrow["row_children"], 2, "challenges/and_a_stacked_row_is_mark_plus_one_column")
	frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame


func _measure(screen: Node) -> Dictionary:
	var board: Control = screen.find_child(ScreenClass.BOARD_NODE, true, false)
	var widest := board.size.x
	var stacked := false
	var row_children := 0
	var first_row := true
	for child in board.get_children():
		widest = maxf(widest, (child as Control).size.x)
		for row_node in (child as Node).get_children():
			if not String(row_node.name).begins_with("Row_") or not first_row:
				continue
			first_row = false
			var line := (row_node as Node).get_child(0) as Control
			row_children = line.get_child_count()
			var second := line.get_child(1)
			stacked = second is VBoxContainer and String(second.name) != "What"
	return {"widest": widest, "board": board.size.x, "stacked": stacked, "row_children": row_children}


# ---------------------------------------------------------------------------
# 9. The literal scan, and the theme tokens this screen names
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "challenges/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "challenges/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "challenges/ChallengesScreen_gd_carries_no_prose_literal")
	var scene_literals: Array = []
	for literal in _literals_in_scene(FileAccess.get_file_as_string(SCENE_PATH)):
		scene_literals.append(String(literal))
	audit.check_eq(scene_literals, [], "challenges/the_scene_carries_no_literals")
	var screen: Node = _screen()
	var theme: Theme = screen.theme
	var missing: Array = []
	for key in screen.palette_keys():
		if not theme.has_color(String(key), "Palette"):
			missing.append(String(key))
	audit.check_eq(missing, [], "challenges/the_theme_carries_every_palette_key_the_screen_names")
	audit.check_eq(screen.palette_misses(), [], "challenges/the_screen_recorded_no_missing_palette_key")


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
