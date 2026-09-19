## pace_screen_test.gd — the game-pace rung on the play-flow screen, end to end.
##
## WHAT IT PROVES, in the order the feature's own claim reads:
##
##   1. the control IS on the play-flow screen: `ModesScreen.tscn`'s `#matchSetup`
##      row carries a third group beside the reference's difficulty and
##      match-length segments, with one rung per `Pace.ids()` entry, named
##      `PaceButton_<id>`, and every rung labelled from the pace module;
##   2. a PRESS on a rung — the button's own `pressed` signal, the door a player's
##      click uses — writes the stored preference through the same prefs carrier
##      the other two segments use, and a rung outside the ladder is refused
##      without touching what is stored;
##   3. the SIMULATION CLOCK follows the rung the screen wrote: for a fixed span of
##      real frames the controller runs `round(120 * factor)` whole `FIXED_STEP`
##      ticks, measured on the real `advance_frame` (`_probe_pace_clock.gd`'s
##      method, here driven off the rung the screen stored rather than off a
##      hand-written pref), and the default rung reproduces the tick count the
##      build ran before the feature existed;
##   4. the LAYOUT holds with the third group in, at both frames the missions
##      measure: the setup row's own minimum width fits the frame and every rung
##      stays inside its segmented box (`tests/ui/ui_legibility_audit.gd` walks the
##      same screen separately, over every capture state);
##   5. a save from a build without the key, and a stored id outside the ladder,
##      both read back as the module's default — never as a rung that runs the
##      clock at zero.
##
## WRITES: only `user://pace-screen-test`, removed again at the end, and the locale
## is restored; `Config.save_dir` is put back. The real `user://save` is never
## touched.
##
## Command: "$GODOT" --headless --path godot/ --script res://tests/pace_screen_test.gd
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const ModesScene := preload("res://src/ui/screens/ModesScreen.tscn")
const ModesScreenClass := preload("res://src/ui/screens/ModesScreen.gd")
const MatchScene := preload("res://game/Match.tscn")
const Pace := preload("res://src/sim/pace.gd")
const Config := preload("res://game/match_config.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Schema := preload("res://src/save/save_schema.gd")
const Locale := preload("res://src/locale/locale.gd")

const TEMP_DIR := "user://pace-screen-test"
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
const SETTLE_FRAMES := 3
## The legibility audit's own containment tolerance: the layout's rounding is not a
## bug, and this test measures the same rects it does.
const CONTAINMENT_TOLERANCE := 1.0
## `.match-setup { width: min(760px, 100%); padding: 0 24px }` (`styles.css:2129-2139`):
## the content box `SetupArea` centres, and the number the setup row's own minimum has
## to fit — the margins that centre it are part of its minimum size, so a row wider
## than this box overflows the screen at every frame width.
const SETUP_CONTENT_BOX := 760.0 - 2.0 * 24.0
## 60 frames at 1/60 equals exactly 120 ticks at factor 1.0, so the expectations
## below are exact integers rather than a tolerance around a measurement.
const FRAMES := 60
const DELTA := 1.0 / 60.0
const TICKS_AT_ONE := 120

var _frame: Control
var _screen: Node
var _language_at_start := ""


func _initialize() -> void:
	var audit := AuditBase.new("pace_screen")
	Config.save_dir = TEMP_DIR
	Config.pending_mode = "quick"
	Config.pending_round = -1
	_language_at_start = Locale.current_lang()
	await _run(audit)
	_wipe()
	Config.save_dir = ""
	Locale.set_lang(_language_at_start)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_frame = Control.new()
	_frame.name = "PaceScreenTestFrame"
	_frame.size = FRAME_BIG
	root.add_child(_frame)
	# The tree must be iterating before the screen is created (a node added from
	# `_initialize()` gets its `_ready` deferred to the first frame).
	for _i in SETTLE_FRAMES:
		await process_frame
	_screen = ModesScene.instantiate()
	_frame.add_child(_screen)
	for _i in SETTLE_FRAMES:
		await process_frame
	_control(audit)
	_strings(audit)
	_press(audit)
	await _clock(audit)
	await _layout(audit)
	_defaults(audit)


# ---------------------------------------------------------------------------
# 1. The control, on the setup row
# ---------------------------------------------------------------------------

func _control(audit: AuditBase) -> void:
	var setup: Control = _screen.find_child("MatchSetup", true, false)
	audit.check_true(setup != null, "pace/the_reference_setup_row_exists")
	var group: Control = _screen.find_child("PaceGroup", true, false)
	audit.check_true(group != null, "pace/the_pace_group_is_on_the_play_flow_screen")
	audit.check_true(group != null and group.get_parent() == setup,
		"pace/the_pace_group_sits_on_the_setup_row_beside_the_two_reference_segments")
	for node_name in ["PaceStack", "PaceLabel", "PaceSegmentedBox", "PaceSegmented"]:
		audit.check_true(_screen.find_child(node_name, true, false) != null, "pace/%s_exists" % node_name)

	var ids: Array = []
	for id in Pace.ids():
		var node_name := ModesScreenClass.PACE_PREFIX + String(id)
		var button: Button = _screen.find_child(node_name, true, false)
		audit.check_true(button != null, "pace/%s_is_a_button" % node_name)
		if button != null:
			audit.check_true(button.text != "" and button.text != String(id),
				"pace/%s_carries_a_sentence_not_its_id" % node_name)
			ids.append(String(id))
	audit.check_eq(ids, Array(Pace.ids()), "pace/the_rungs_are_the_ladder_in_the_modules_own_order")
	audit.check_eq(_active_rungs().size(), 1, "pace/exactly_one_rung_is_selected_on_arrival")
	audit.check_eq(_active_rungs(), [Config.pace_id()], "pace/the_selected_rung_is_the_stored_one")
	# The screen's own claim about the rung it shows, through the same door the modes
	# audit reads.
	audit.check_eq(_screen.active_pace(), Config.pace_id(), "pace/the_screen_reads_the_stored_rung")


## The rungs wearing the selected look, read the way the modes audit reads the
## difficulty rungs (the button's own `active` meta).
func _active_rungs() -> Array:
	var out: Array = []
	for id in Pace.ids():
		var button: Button = _screen.find_child(ModesScreenClass.PACE_PREFIX + String(id), true, false)
		if button != null and bool(button.get_meta("active", false)):
			out.append(String(id))
	return out


# ---------------------------------------------------------------------------
# 2. The strings: the pace module's own text, in both locales
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var title: Label = _screen.find_child("PaceLabel", true, false)
	audit.check_true(title != null, "pace/the_group_carries_a_title_label")
	for lang_in in Locale.locales():
		var lang := String(lang_in)
		Locale.set_lang(lang)
		_screen.refresh_strings()
		var wrong: Array = []
		for id in Pace.ids():
			var preset: Dictionary = Pace.preset(String(id))
			var expected := Pace.text(String(preset["label_key"]), lang)
			var shown := String(_screen.text_shown(ModesScreenClass.PACE_PREFIX + String(id)))
			if shown != expected:
				wrong.append("%s: %s != %s" % [id, shown, expected])
		audit.check_eq(wrong, [], "pace/every_rung_shows_the_pace_modules_own_text_in_%s" % lang)
		var title_text := "" if title == null else title.text
		audit.check_eq(title_text, Pace.text(ModesScreenClass.PACE_TITLE_KEY, lang),
			"pace/the_group_title_is_the_pace_modules_own_in_%s" % lang)
		audit.check_true(title_text != ModesScreenClass.PACE_TITLE_KEY,
			"pace/the_title_is_a_sentence_not_a_raw_key_in_%s" % lang)
	# The flip really reaches this group: the labels are not one language's twice.
	Locale.set_lang("it")
	_screen.refresh_strings()
	var italian := String(_screen.text_shown(ModesScreenClass.PACE_PREFIX + String(Pace.ids()[0])))
	Locale.set_lang("en")
	_screen.refresh_strings()
	var english := String(_screen.text_shown(ModesScreenClass.PACE_PREFIX + String(Pace.ids()[0])))
	audit.check_ne(italian, english, "pace/the_rung_labels_follow_the_language")
	Locale.set_lang(_language_at_start)
	_screen.refresh_strings()


# ---------------------------------------------------------------------------
# 3. The press: the stored preference moves
# ---------------------------------------------------------------------------

func _press(audit: AuditBase) -> void:
	for id in Pace.ids():
		var key := String(id)
		var button: Button = _screen.find_child(ModesScreenClass.PACE_PREFIX + key, true, false)
		audit.check_true(button != null, "pace/%s_has_a_press_wire" % key)
		if button == null:
			continue
		button.pressed.emit()
		audit.check_eq(_stored_id(), key, "pace/a_press_on_%s_stores_the_rung" % key)
		audit.check_eq(_stored_on_disk(), key, "pace/a_press_on_%s_reaches_the_file" % key)
		audit.check_eq(Config.pace_id(), key, "pace/the_matchs_own_reader_sees_%s" % key)
		audit.check_eq(_screen.active_pace(), key, "pace/the_screen_reads_%s_back" % key)
		audit.check_eq(_active_rungs(), [key], "pace/%s_is_the_one_selected_rung" % key)

	# The screen's own activation door — what the focus bridge hands it.
	audit.check_true(_screen.activate("pace:relaxed"), "pace/the_activation_door_accepts_a_rung")
	audit.check_eq(_stored_id(), "relaxed", "pace/the_activation_door_stores_the_rung")
	audit.check_eq(_screen.activate("pace:no_such_pace"), false, "pace/the_door_refuses_an_unknown_rung")
	audit.check_eq(_stored_id(), "relaxed", "pace/a_refused_rung_leaves_the_stored_one_alone")
	audit.check_eq(_screen.select_pace("no_such_pace"), false, "pace/select_pace_refuses_an_unknown_rung")
	audit.check_eq(_stored_id(), "relaxed", "pace/the_refused_press_stores_nothing")
	audit.check_true(_stored_prefs().has("pacePreset"),
		"pace/the_rung_lands_in_the_reference_carrier_not_a_second_field")


# ---------------------------------------------------------------------------
# 4. The clock: the rung the screen wrote is what the simulation runs at
# ---------------------------------------------------------------------------

func _clock(audit: AuditBase) -> void:
	var measured := {}
	for id in Pace.ids():
		var key := String(id)
		# The write under test is the screen's own press, not a hand-written pref.
		var button: Button = _screen.find_child(ModesScreenClass.PACE_PREFIX + key, true, false)
		if button == null:
			continue
		button.pressed.emit()
		measured[key] = await _ticks_for(audit, key)
	for id in Pace.ids():
		var key := String(id)
		var expected := int(round(float(TICKS_AT_ONE) * Pace.factor_for(key)))
		audit.check_between(int(measured.get(key, -1)), expected - 2, expected + 2,
			"pace/%s_advances_%d_ticks_over_%d_frames" % [key, expected, FRAMES])
	audit.check_eq(int(measured.get(Pace.default_id(), -1)), TICKS_AT_ONE,
		"pace/the_default_rung_reproduces_the_pre_change_clock")
	audit.check_eq(measured, {
		"realistic": 180,
		"brisk": 120,
		"standard": 90,
		"relaxed": 72,
		"learning": 60,
	}, "pace/the_whole_tick_table_is_the_ladder")
	audit.report("ticks over %d frames: %s" % [FRAMES, JSON.stringify(measured)])


## Boots one match on the stored rung and counts the whole ticks one span of real
## frames buys. A fresh node per rung, so no accumulator carries over.
func _ticks_for(audit: AuditBase, id: String) -> int:
	var node: Node = MatchScene.instantiate()
	root.add_child(node)
	node.harness_mode()
	node.start_match()
	audit.check_eq(node.get("pace_factor"), Pace.factor_for(id),
		"pace/the_%s_match_latched_the_rungs_factor" % id)
	var ticks := 0
	for _i in FRAMES:
		var step: Dictionary = node.advance_frame(DELTA)
		ticks += int(step.get("steps", 0))
	if node.get_parent() != null:
		root.remove_child(node)
	node.free()
	return ticks


# ---------------------------------------------------------------------------
# 5. The layout: the third group fits the frames the missions measure
# ---------------------------------------------------------------------------

func _layout(audit: AuditBase) -> void:
	for size_in in [FRAME_BIG, FRAME_SMALL]:
		var frame_size: Vector2 = size_in
		_frame.size = frame_size
		for _i in SETTLE_FRAMES:
			await process_frame
		var tag := "%dx%d" % [int(frame_size.x), int(frame_size.y)]
		audit.check_true(_screen.size.is_equal_approx(frame_size), "pace/the_screen_fills_%s" % tag)
		var setup: Control = _screen.find_child("MatchSetup", true, false)
		var area: Control = _screen.find_child("SetupArea", true, false)
		var group: Control = _screen.find_child("PaceGroup", true, false)
		audit.check_eq(_outside(setup, area), [],
			"pace/the_setup_row_stays_inside_its_area_at_%s" % tag)
		audit.check_true(setup.get_combined_minimum_size().x <= area.size.x + CONTAINMENT_TOLERANCE,
			"pace/the_three_groups_own_minimum_width_fits_at_%s" % tag)
		audit.check_eq(_outside(group, setup), [],
			"pace/the_pace_group_stays_inside_the_setup_row_at_%s" % tag)
		var box: Control = _screen.find_child("PaceSegmentedBox", true, false)
		var strays: Array = []
		for id in Pace.ids():
			var button: Control = _screen.find_child(ModesScreenClass.PACE_PREFIX + String(id), true, false)
			strays.append_array(_outside(button, box))
		audit.check_eq(strays, [], "pace/every_rung_stays_inside_its_segmented_box_at_%s" % tag)
		# The row's minimum is what the frame has to hold, and `SetupArea` gives it the
		# reference's own content box (`min(760, w) - 2 * 24`; the centring margins are
		# part of its minimum, so a row whose minimum exceeds the box overflows the
		# screen at EVERY width rather than shrinking). The demo view is the state that
		# tests it: the three un-granted difficulty rungs are disabled there and the
		# theme's disabled segmented box is wider than its normal one (80-95 px against
		# 36-51 at this frame), which is why the row wraps instead of pushing `Frame`
		# past the right edge.
		_screen.apply_capture_state("demo-locked")
		for _i in SETTLE_FRAMES:
			await process_frame
		var demo_min: float = setup.get_combined_minimum_size().x
		audit.check_true(demo_min <= SETUP_CONTENT_BOX + CONTAINMENT_TOLERANCE,
			"pace/the_rows_minimum_fits_the_reference_content_box_in_the_demo_view_at_%s" % tag)
		audit.check_true(demo_min <= area.size.x + CONTAINMENT_TOLERANCE,
			"pace/the_demo_view_row_fits_its_area_at_%s" % tag)
		audit.check_eq(_outside(group, setup), [],
			"pace/the_pace_group_stays_inside_the_row_in_the_demo_view_at_%s" % tag)
		_screen.apply_capture_state("default")
		for _i in SETTLE_FRAMES:
			await process_frame
		audit.report("%s setup=%.1f min=%.1f demo_min=%.1f group=%.1f" % [
			tag, setup.size.x, setup.get_combined_minimum_size().x, demo_min, group.size.x])


## The legibility audit's own containment question, aimed at one pair of rects.
func _outside(child: Control, parent: Control) -> Array:
	if child == null or parent == null:
		return ["missing node"]
	var outer: Rect2 = parent.get_global_rect().grow(CONTAINMENT_TOLERANCE)
	if outer.encloses(child.get_global_rect()):
		return []
	return ["%s %s outside %s %s" % [
		String(child.name), str(child.get_global_rect()),
		String(parent.name), str(parent.get_global_rect())]]


# ---------------------------------------------------------------------------
# 6. The defaults: a key nothing stored, and an id outside the ladder
# ---------------------------------------------------------------------------

func _defaults(audit: AuditBase) -> void:
	var store := Config.save_store()
	audit.check_eq(String(Schema.PREFS_DEFAULTS.get("pacePreset", "")), Pace.default_id(),
		"pace/the_save_schemas_default_is_the_modules_own")

	# A profile from a build that never had the key.
	store.write_group("prefs", {})
	audit.check_eq(Config.pace_id(), Pace.default_id(),
		"pace/a_save_without_the_key_reads_back_as_the_default")
	_screen.refresh_strings()
	audit.check_eq(_active_rungs(), [Pace.default_id()],
		"pace/the_screen_shows_the_default_rung_when_nothing_is_stored")
	audit.check_eq(_stored_on_disk(), "", "pace/writing_the_empty_profile_stored_no_rung")

	# A stored id this build does not know: the default, and the unscaled clock.
	ModesSave.save_pref(store, "pacePreset", "no_such_pace")
	audit.check_eq(Config.pace_id(), Pace.default_id(),
		"pace/an_unknown_stored_id_reads_back_as_the_default")
	audit.check_eq(Config.pace_factor(), 1.0, "pace/an_unknown_stored_id_keeps_the_unscaled_clock")
	_screen.refresh_strings()
	audit.check_eq(_active_rungs(), [Pace.default_id()],
		"pace/the_screen_shows_the_default_rung_for_an_unknown_id")


# ---------------------------------------------------------------------------
# The save doors this test reads
# ---------------------------------------------------------------------------

## The stored prefs group, raw (`read_group` payload: the save applies no defaults
## here, so this is what the file holds rather than what a schema would fill in).
func _stored_prefs() -> Dictionary:
	var read: Dictionary = Config.save_store().read_group("prefs")
	var payload: Variant = read.get("payload", null)
	return payload if payload is Dictionary else {}


func _stored_id() -> String:
	return String(_stored_prefs().get("pacePreset", ""))


## The same value, read from the group's file on disk: the press has to reach the
## save, not only the screen's own copy of it.
func _stored_on_disk() -> String:
	var path: String = Config.save_store().group_path("prefs")
	if not FileAccess.file_exists(path):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return ""
	var payload: Variant = (parsed as Dictionary).get("payload", null)
	if not (payload is Dictionary):
		return ""
	return String((payload as Dictionary).get("pacePreset", ""))


func _wipe() -> void:
	var absolute := ProjectSettings.globalize_path(TEMP_DIR)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file))
	for dir in DirAccess.get_directories_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(dir))
	DirAccess.remove_absolute(absolute)
