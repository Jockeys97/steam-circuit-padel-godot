## screen_profile_audit.gd — UIR-16's contract audit: the career profile against a
## constructed career in a temp store.
##
## WHAT IT PROVES, and why each check is the reference's own question:
##
##   1. the router still carries the thirteen ids and the profile mounts through it;
##   2. THE SCOUT'S ACCEPTANCE, box by box: the four numbers the screen shows are the
##      numbers the save lane computes — compared against `ModesSave.profile(store)`'s
##      own career group and against the adapter's `UiData.profile_summary`, never
##      against a hand-copied expectation (`js/ui.js:1616-1621`);
##   3. the season objectives are the adapter's own rows (`UiData.season_objectives`),
##      each rendered as check + label + progress/target + category, with the
##      reference's `✓`/`○` and its two category words (`js/ui.js:1629-1638`);
##   4. the empty state is the reference's own (`profileNoObjectives`);
##   5. the one route works: the Obiettivi button carries `to-challenges`
##      (`js/ui.js:1662`) and lands on the challenges screen through the router;
##   6. a language flip re-resolves;
##   7. zero user-facing literals in the screen and its scene;
##   8. the layout holds at 1280x720 and 1024x600;
##   9. all three declared capture states walk.
##
## CONSTRUCTED STATE, labeled: the career is written into
## `user://uir16-profile-audit` through `ModesSave.save_career`; the directory is
## removed at the end. The real `user://save` profile is never written.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/ProfileScreen.gd")
const ScreenScene := preload("res://src/ui/screens/ProfileScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")

const SCREEN_PATH := "res://src/ui/screens/ProfileScreen.gd"
const SCENE_PATH := "res://src/ui/screens/ProfileScreen.tscn"
const TEMP_DIR := "user://uir16-profile-audit"

const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)

## The constructed career: 7 wins, 3 losses, 2 trophies, 5 stars — a 70 % win rate,
## all four numbers deterministic and inside the reference's own shape.
const WINS := 7
const LOSSES := 3
const TROPHIES := 2
const STARS := 5

const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"profileTitle\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("screen_profile")
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
	var career := ModesSave.load_career(_store)
	career["wins"] = WINS
	career["losses"] = LOSSES
	career["trophies"] = TROPHIES
	career["stars"] = STARS
	ModesSave.save_career(_store, career)
	var frame := Control.new()
	frame.name = "ScreenProfileAuditFrame"
	frame.size = FRAME_BIG
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame

	await _mount(audit)
	await _stats(audit)
	await _objectives(audit)
	await _unlocks(audit)
	await _route(audit)
	await _strings(audit)
	await _captures(audit)
	await _layout(audit)
	_literal_scan(audit)
	audit.report("temp store: %s — the real user:// profile was never written" % TEMP_DIR)


func _screen() -> Node:
	return _router.active_screen()


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "profile/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "profile/all_thirteen_slots_register")
	audit.check_true(_router.register("profile", ScreenScene), "profile/the_scene_registers_under_the_profile_id")
	audit.check_eq(_router.go_to("profile", {"store": _store}), true, "profile/go_to_mounts_the_screen")
	await process_frame
	var screen: Node = _screen()
	audit.check_true(screen is ScreenClass, "profile/the_mounted_scene_carries_ProfileScreen_gd")
	audit.check_true(screen.theme != null, "profile/the_scene_mounts_the_theme")
	audit.check_eq(screen.store().dir, TEMP_DIR, "profile/the_screen_reads_the_temp_store")
	audit.check_eq(screen.screen_id(), "profile", "profile/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), Router.back_target_of("profile"), "profile/the_declared_return_is_the_router_table_s")
	audit.check_eq(String(screen.get("router_id")), "profile", "profile/the_screen_kept_the_router_fact")
	audit.check_eq(Array(screen.capture_states()), ["default", "empty-objectives", "mid-season"],
		"profile/the_three_declared_capture_states")
	audit.check_eq(screen.apply_capture_state("nope"), false, "profile/an_undeclared_capture_state_is_refused")


# ---------------------------------------------------------------------------
# 2. The four boxes, against the save lane's own numbers
# ---------------------------------------------------------------------------

func _stats(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var profile := ModesSave.profile(_store)
	var career: Dictionary = profile.get("career", {})
	audit.check_eq(int(career.get("wins", -1)), WINS, "profile/the_constructed_career_is_the_one_in_the_store")
	var adapter := UiData.profile_summary(_store)
	var values: Array = screen.stat_values()
	audit.check_eq(values.size(), 4, "profile/the_reference_shows_four_boxes")
	audit.check_eq(String(values[0]), str(int(career["wins"])), "profile/the_wins_box_is_the_career_s_own")
	audit.check_eq(String(values[0]), str(int(adapter["wins"])), "profile/the_wins_box_is_the_adapter_s_own")
	audit.check_eq(String(values[1]), str(int(career["trophies"])), "profile/the_trophies_box_is_the_career_s_own")
	audit.check_eq(String(values[1]), str(int(adapter["seasons"])), "profile/the_trophies_box_matches_the_adapter")
	audit.check_eq(String(values[2]), str(int(career["stars"])), "profile/the_stars_box_is_the_career_s_own")
	audit.check_eq(String(values[2]), str(int(adapter["stars"])), "profile/the_stars_box_matches_the_adapter")
	audit.check_eq(String(values[3]), "70%", "profile/the_win_rate_is_seventy_per_cent_for_seven_of_ten")
	audit.check_eq(String(values[3]).trim_suffix("%"), str(int(adapter["win_rate"])),
		"profile/and_it_is_the_adapter_s_own_rounding")
	var labels: Array = screen.stat_labels()
	audit.check_eq(String(labels[0]), UiStrings.t("histWins"), "profile/the_first_box_label_is_the_reference_s")
	audit.check_eq(String(labels[1]), UiStrings.t("profileSeasons"), "profile/the_second_box_label_is_the_reference_s")
	audit.check_eq(String(labels[2]), UiStrings.t("profileStars"), "profile/the_third_box_label_is_the_reference_s")
	audit.check_eq(String(labels[3]), UiStrings.t("profileWinRate"), "profile/the_fourth_box_label_is_the_reference_s")


# ---------------------------------------------------------------------------
# 3. The season objectives
# ---------------------------------------------------------------------------

func _objectives(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var rows: Array = screen.objectives()
	var adapter := UiData.season_objectives(_store)
	audit.check_eq(rows.size(), adapter.size(), "profile/the_list_is_the_adapter_s_own_row_count")
	audit.check_gt(rows.size(), 0, "profile/a_fresh_season_has_objectives")
	var first: Dictionary = rows[0]
	var expected_first: Dictionary = adapter[0]
	audit.check_eq(int(first["target"]), int(expected_first["target"]), "profile/the_first_target_is_the_adapter_s")
	audit.check_eq(int(first["progress"]), int(expected_first["progress"]), "profile/the_first_progress_is_the_adapter_s")
	var row0: Node = screen.find_child(ScreenClass.OBJECTIVES_NODE, true, false).get_node_or_null("Objective0")
	audit.check_true(row0 != null, "profile/the_first_objective_row_exists")
	var ruled := row0 as Node
	var line := ruled.get_child(0) as Control
	var check_label := String((line.get_node("Check") as Label).text)
	audit.check_true(check_label == "✓" or check_label == "○", "profile/the_check_column_is_the_reference_s_own_glyph")
	audit.check_eq(String((line.get_node("Progress") as Label).text), "%d/%d" % [int(first["progress"]), int(first["target"])],
		"profile/the_progress_column_is_progress_slash_target")
	audit.check_eq(String((line.get_node("Label") as Label).text), UiStrings.t(String(first["label_key"]), {"n": int(first["target"])}),
		"profile/the_label_is_the_objective_s_own_key_with_its_target")
	var cat := String((line.get_node("Cat") as Label).text)
	var expected_cat := ""
	if bool(first["done"]):
		expected_cat = UiStrings.t("objDone")
	elif bool(first["claimed"]):
		expected_cat = UiStrings.t("objAlreadyClaimed")
	audit.check_eq(cat, expected_cat, "profile/the_category_column_follows_the_adapter_s_status")


# ---------------------------------------------------------------------------
# 4. The unlock summary and the reference's empty state
# ---------------------------------------------------------------------------

func _unlocks(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var summary := UiData.unlock_summary(_store)
	var text: Node = screen.find_child("UnlockCount", true, false)
	audit.check_true(text != null, "profile/the_unlock_summary_line_exists")
	audit.check_eq(String((text as Label).text), UiStrings.t("profileUnlocksCount", {
		"done": int(summary["done"]), "total": int(summary["total"]),
	}), "profile/the_summary_line_is_the_adapter_s_own_count")
	var button: Button = screen.unlock_button()
	audit.check_true(button != null, "profile/the_unlock_button_exists")
	audit.check_eq(String(button.text), UiStrings.t("challenges"), "profile/and_it_carries_the_reference_s_own_word")
	audit.check_eq(String(button.theme_type_variation), "ButtonSecondary", "profile/the_button_uses_the_secondary_variation")
	# The reference's own empty branch (`js/ui.js:1639`).
	audit.check_eq(screen.apply_capture_state("empty-objectives"), true, "profile/the_empty_objectives_state_applies")
	var empty: Node = screen.find_child(ScreenClass.EMPTY_NODE, true, false)
	audit.check_true(empty != null, "profile/and_the_list_shows_the_empty_line")
	audit.check_eq(String((empty as Label).text), UiStrings.t("profileNoObjectives"), "profile/which_is_the_reference_s_own_sentence")
	audit.check_eq(screen.objectives().size(), 0, "profile/and_no_objective_row_is_left")
	audit.check_eq(screen.apply_capture_state("default"), true, "profile/the_default_state_applies")
	audit.check_eq(screen.objectives().size(), UiData.season_objectives(_store).size(), "profile/and_the_live_rows_come_back")


# ---------------------------------------------------------------------------
# 5. The one route
# ---------------------------------------------------------------------------

func _route(audit: AuditBase) -> void:
	var screen: Node = _screen()
	audit.check_eq(screen.route_action("nope"), false, "profile/an_unknown_action_is_refused")
	audit.check_eq(screen.route_action("to-challenges"), true, "profile/the_unlock_button_s_route_lands")
	await process_frame
	audit.check_eq(_router.active_id(), "challenges", "profile/and_the_router_moved_to_challenges")
	audit.check_eq(_router.go_to("profile", {"store": _store}), true, "profile/the_audit_returns_to_the_profile")
	await process_frame
	# The button is also the screen's own focusable (UIR-05's bridge reads it).
	var screen2: Node = _screen()
	var specs: Array = screen2.focus_controls()
	var ids: Array = []
	for spec in specs:
		ids.append(String((spec as Dictionary).get("id", "")))
	audit.check_true(ids.has("profile/unlocks-challenges"), "profile/the_unlock_button_is_a_registered_focusable")
	audit.check_true(ids.has("profile/back"), "profile/the_back_control_is_registered")
	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen2, focus, _router)
	audit.check_eq(bridge.ids().size(), specs.size(), "profile/the_bridge_reads_every_registered_control")


# ---------------------------------------------------------------------------
# 6. Strings and the language flip
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var original := Locale.current_lang()
	var label_before := String(screen.stat_labels()[1])
	audit.check_eq(label_before, UiStrings.t("profileSeasons"), "profile/the_seasons_label_is_the_locale_text")
	Locale.set_lang("en")
	screen.refresh()
	audit.check_true(String(screen.stat_labels()[1]) != label_before, "profile/the_english_seasons_label_differs")
	audit.check_eq(String(screen.title_control().text), UiStrings.t("profileTitle"), "profile/the_title_follows_the_language")
	Locale.set_lang(original)
	screen.refresh()
	audit.check_eq(String(screen.stat_labels()[1]), label_before, "profile/the_flip_back_restores_the_first_text")


# ---------------------------------------------------------------------------
# 7. Capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var applied: Array = []
	for state in ScreenClass.CAPTURE_STATE_LIST:
		applied.append(screen.apply_capture_state(String(state)))
	audit.check_eq(applied, [true, true, true], "profile/all_three_declared_states_apply")
	# `mid-season` pins the live season's progress with one objective met: the page must
	# show one foot in each column (`js/ui.js:124-128`).
	audit.check_eq(screen.apply_capture_state("mid-season"), true, "profile/the_mid_season_state_applies")
	var done := 0
	var pending := 0
	for row_in in screen.objectives():
		if bool((row_in as Dictionary)["done"]):
			done += 1
		else:
			pending += 1
	audit.check_gt(done, 0, "profile/mid_season_has_at_least_one_met_objective")
	audit.check_gt(pending, 0, "profile/and_at_least_one_still_open")
	audit.report("mid-season: %d done, %d open" % [done, pending])
	audit.check_eq(screen.apply_capture_state("default"), true, "profile/the_default_state_applies_again")


# ---------------------------------------------------------------------------
# 8. Layout at both declared sizes
# ---------------------------------------------------------------------------

func _layout(audit: AuditBase) -> void:
	var frame: Control = _router.get_parent()
	var screen: Node = _screen()
	var big := _measure(screen)
	audit.report("1280x720: widest=%.1f columns=%d" % [big["widest"], big["columns"]])
	audit.check_true(big["widest"] <= FRAME_BIG.x, "profile/nothing_is_wider_than_the_frame")
	audit.check_eq(big["columns"], 4, "profile/the_four_boxes_sit_in_one_row_at_1280")
	var objectives: Control = screen.find_child(ScreenClass.OBJECTIVES_NODE, true, false)
	var unlocks: Control = screen.find_child(ScreenClass.UNLOCKS_NODE, true, false)
	audit.check_le(objectives.size.x, FRAME_BIG.x, "profile/the_objectives_box_stays_inside_the_frame")
	audit.check_le(unlocks.size.x, FRAME_BIG.x, "profile/the_unlocks_box_stays_inside_the_frame")
	frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	var small := _measure(screen)
	audit.report("1024x600: widest=%.1f columns=%d" % [small["widest"], small["columns"]])
	audit.check_true(small["widest"] <= FRAME_SMALL.x, "profile/nothing_is_wider_than_the_small_frame")
	audit.check_ge(small["columns"], 1, "profile/the_boxes_refold_inside_the_small_frame")
	frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame


func _measure(screen: Node) -> Dictionary:
	var stats: GridContainer = screen.find_child(ScreenClass.STATS_NODE, true, false)
	var widest := stats.size.x
	for child in stats.get_children():
		widest = maxf(widest, (child as Control).size.x)
	return {"widest": widest, "columns": stats.columns}


# ---------------------------------------------------------------------------
# 9. The literal scan, and the theme tokens this screen names
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "profile/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "profile/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "profile/ProfileScreen_gd_carries_no_prose_literal")
	var scene_literals: Array = []
	for literal in _literals_in_scene(FileAccess.get_file_as_string(SCENE_PATH)):
		scene_literals.append(String(literal))
	audit.check_eq(scene_literals, [], "profile/the_scene_carries_no_literals")
	var screen: Node = _screen()
	var theme: Theme = screen.theme
	var missing: Array = []
	for key in screen.palette_keys():
		if not theme.has_color(String(key), "Palette"):
			missing.append(String(key))
	audit.check_eq(missing, [], "profile/the_theme_carries_every_palette_key_the_screen_names")
	audit.check_eq(screen.palette_misses(), [], "profile/the_screen_recorded_no_missing_palette_key")


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
