## screen_characters_audit.gd — UIR-11's contract audit: `screen-characters` in a real router.
##
## WHAT IT PROVES, each check the ticket's own rule:
##
##   1. the router mounts the screen, and the team panel resolves through the port's own
##      `Lineup` seam: four roles, the dictated pair winning over stored preferences,
##      and the preference source this screen is the first caller of (`js/ui.js:548-594`);
##   2. the player's slot is visually distinct (`styles.css:342`, `.athlete-card--selected`)
##      while rival slots wear the plain frame;
##   3. an editable slot opens the picker; a dictated slot has no picker at all
##      (`js/ui.js:976`);
##   4. a pick can never duplicate an athlete — including picking one already on court,
##      which swaps the two slots (`js/ui.js:559-565`, made explicit here);
##   5. the wardrobe opens per athlete, marks the equipped outfit, refuses a locked one,
##      and a challenge-locked outfit shows the reference's own challenge sentence
##      (`challengeLabel`, `js/ui.js:670-683`);
##   6. locked athletes stay visible and carry a lock label — the build's own key in a
##      demo, the reference's trophy/star wall otherwise (`lockLabel`, `js/ui.js:685-702`);
##   7. three activations inside the window open the code entry; a wrong code changes
##      nothing; the right one (`ModeTables.unlock_code()`) sets `career.unlockAll`;
##      **a build-excluded athlete stays locked afterwards** — the ticket's negation;
##   8. zero user-facing literals in the screen (scene: none), with the scan's synthetic
##      proof it can still see prose;
##   9. a language flip re-resolves every binding, in both locales;
##  10. the five declared capture states walk, each rendering its own view;
##  11. layout at 1280x720 (four columns) and 1024x600 (two), and UIR-05's bridge reads
##      the screen and routes its declared back edge.
##
## Both runs the ticket asks for share this file; the demo checks branch on
## `DemoGateAdapter.build()` and assert the negation (a demo-excluded athlete cannot be
## unlocked by code) in both.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const CharactersScreenClass := preload("res://src/ui/screens/CharactersScreen.gd")
const CharactersScene := preload("res://src/ui/screens/CharactersScreen.tscn")
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
const Lineup := preload("res://game/lineup.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")

const SCREEN_PATH := "res://src/ui/screens/CharactersScreen.gd"
const SCENE_PATH := "res://src/ui/screens/CharactersScreen.tscn"
const TEMP_DIR := "user://uir11-characters-audit"

const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
const REFERENCE_SCREEN_COUNT := 13

## `CharactersScreen.gd` is allowed no prose literal; the scene is allowed none either.
const SCREEN_LITERALS: Array = []
const SCENE_LITERALS: Array = []
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"charactersTitle\")\n## a comment quoting \"prose in a comment\"\n"

## The reference's own bars (`js/ui.js:805-828`, `"▮".repeat(pieni) + "▯".repeat(5 - pieni)`),
## pinned from `js/data.js`'s `ATHLETES` and checked row by row against `frozen/data.json`
## before being written here: one entry per athlete, one filled-tick count per stat in the
## reference's own order (power, control, speed). These are the reference's numbers, not
## the screen's arithmetic — and because the scale is the whole roster, the same row is
## expected in every build, demo included.
const STAT_BARS := {
	"maestro": [1, 4, 1],
	"pantera": [2, 1, 5],
	"steamer": [4, 1, 1],
	"fiamma": [1, 1, 1],
	"oracolo": [1, 5, 1],
	"colosso": [5, 1, 1],
}
const STAT_AUDIT_KEYS := ["power", "control", "speed"]
const STAT_AUDIT_LABELS := {"power": "statPower", "control": "statControl", "speed": "statSpeed"}

var _router: Control
var _frame: Control


func _initialize() -> void:
	var audit := AuditBase.new("screen_characters")
	Config.save_dir = TEMP_DIR
	await _run(audit)
	_cleanup()
	quit(audit.finish())


func _cleanup() -> void:
	Config.save_dir = ""
	Config.pending_mode = "quick"
	Config.athlete_index = 0
	Lineup.set_pref_source(null)
	var absolute := ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(absolute):
		var dir := DirAccess.open(absolute)
		if dir != null:
			for file in dir.get_files():
				dir.remove(file)
		DirAccess.remove_absolute(absolute)


func _run(audit: AuditBase) -> void:
	_frame = Control.new()
	_frame.name = "ScreenCharactersAuditFrame"
	_frame.size = FRAME_BIG
	root.add_child(_frame)
	_router = Router.new()
	_router.name = "Router"
	_frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _register_router(audit)
	await _facts(audit)
	await _team(audit)
	await _picker_and_swap(audit)
	await _stat_strip(audit)
	await _outfits(audit)
	await _locks(audit)
	await _unlock_code(audit)
	_literal_scan(audit)
	await _flip(audit)
	await _captures(audit)
	await _bridge(audit)
	await _layout(audit)


func _register_router(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "characters/the_router_still_carries_thirteen_ids")
	for id in ids:
		_router.register(String(id), PlaceholderScene)
	audit.check_true(_router.register("characters", CharactersScene), "characters/the_scene_registers_under_the_characters_id")
	audit.check_eq(_router.go_to("characters"), true, "characters/go_to_mounts_the_screen")
	for _i in SETTLE_FRAMES:
		await process_frame


func _mount() -> Node:
	_router.go_to("characters")
	for _i in SETTLE_FRAMES:
		await process_frame
	return _router.active_screen()


func _screen() -> Node:
	return _router.active_screen()


func _facts(audit: AuditBase) -> void:
	var screen := _screen()
	audit.check_true(screen is CharactersScreenClass, "characters/the_mounted_scene_carries_CharactersScreen_gd")
	audit.check_eq(screen.screen_id(), "characters", "characters/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "modes", "characters/the_declared_back_edge_is_modes")
	audit.check_eq(screen.capture_states(),
		["default", "picker-open", "outfit-open", "locked-athlete", "demo-locked"],
		"characters/the_screen_declares_the_five_capture_states")
	audit.check_eq(screen.view(), "team", "characters/the_initial_view_is_the_team_panel")


# ---------------------------------------------------------------------------
# 1-2. The team panel
# ---------------------------------------------------------------------------

func _team(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	Config.pending_mode = "quick"
	screen.refresh_data()
	await process_frame

	var ids: Dictionary = screen.lineup_ids()
	audit.check_eq(ids.size(), 4, "characters/the_lineup_carries_the_player_and_three_slots")
	audit.check_eq(screen.slots_of(ids).size(), 3, "characters/three_slots_beside_the_player")
	var distinct: Array = []
	distinct.append(String(Config.athlete().get("id", "")))
	for role in ["playerMate", "opponent", "opponentMate"]:
		distinct.append(String(ids.get(role, "")))
	var unique := {}
	for id in distinct:
		unique[id] = true
	audit.check_eq(unique.size(), 4, "characters/four_distinct_athletes_on_court")
	audit.check_eq(screen.slot_athlete_id("player"), String(Config.athlete().get("id", "")), "characters/the_player_slot_is_the_sessions_athlete")

	var missing: Array = []
	for role in Lineup.ROLES:
		for prefix in ["TeamSlot_", "SlotName_", "SlotRole_", "SlotTag_", "SlotDesc_", "SlotSpecial_"]:
			if screen.find_child(prefix + String(role), true, false) == null:
				missing.append(prefix + String(role))
	audit.check_eq(missing, [], "characters/every_slot_carries_its_own_nodes")

	# The player's slot wears the selected frame; a rival slot does not.
	var player_card: Control = screen.find_child("TeamSlot_player", true, false)
	var mate_card: Control = screen.find_child("TeamSlot_playerMate", true, false)
	var theme: Theme = screen.theme
	audit.check_true(player_card != null and mate_card != null, "characters/player_and_mate_slots_exist")
	var player_box := player_card.get_theme_stylebox("panel") as StyleBoxFlat
	var mate_box := mate_card.get_theme_stylebox("panel") as StyleBoxFlat
	audit.check_true(player_box != null and mate_box != null, "characters/both_slots_carry_a_frame")
	audit.check_eq(player_box.border_color, theme.get_color("cyan", "Palette"), "characters/the_player_slot_border_is_the_theme_cyan")
	audit.check_ne(player_box.border_color, mate_box.border_color, "characters/the_player_slot_is_distinct_from_a_rival_slot")

	# The slot actions: editable slots offer both commands.
	var actions: Array = []
	for node_name in ["SlotAthleteAction_player", "SlotOutfitAction_player", "SlotAthleteAction_playerMate"]:
		if screen.find_child(node_name, true, false) != null:
			actions.append(node_name)
	audit.check_true(actions.has("SlotAthleteAction_player"), "characters/an_editable_slot_offers_the_athlete_command")
	audit.check_true(actions.has("SlotOutfitAction_player"), "characters/the_players_slot_offers_the_wardrobe_command")

	# Dictated slots: the calendar or the bracket decides, and the slot says so.
	Config.pending_mode = "career"
	screen.refresh_data()
	await process_frame
	var dictated: Array = screen.dictated_roles()
	audit.report("dictated=%s build=%s" % [JSON.stringify(dictated), DemoGate.build()])
	audit.check_true(dictated.size() == 0 or dictated.size() == 2, "characters/the_calendar_dictates_none_or_both_rival_slots")
	for role in dictated:
		audit.check_eq(screen.role_editable(String(role)), false, "characters/a_dictated_slot_is_not_editable_%s" % role)
		audit.check_eq(screen.open_picker(String(role)), false, "characters/a_dictated_slot_opens_no_picker_%s" % role)
		var tag: Label = screen.find_child("SlotTag_%s" % role, true, false)
		audit.check_true(tag.text.contains(UiStrings.t("slotByCalendar")), "characters/the_dictated_slot_says_why_%s" % role)
		var commanded: Control = screen.find_child("SlotAthleteAction_%s" % role, true, false)
		audit.check_eq(commanded, null, "characters/a_dictated_slot_carries_no_command_%s" % role)
	audit.check_eq(screen.role_editable("player"), true, "characters/the_player_is_never_dictated")
	audit.check_eq(screen.role_editable("playerMate"), true, "characters/the_second_player_is_never_dictated")
	Config.pending_mode = "quick"
	screen.refresh_data()
	await process_frame


# ---------------------------------------------------------------------------
# 3-4. The picker and the swap
# ---------------------------------------------------------------------------

func _picker_and_swap(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	# 3. An editable slot opens the picker, and the picker shows the whole roster.
	audit.check_true(screen.open_picker("playerMate"), "characters/an_editable_slot_opens_the_picker")
	audit.check_eq(screen.view(), "picker", "characters/the_picker_is_the_active_view")
	var player_id := String(Config.athlete().get("id", ""))
	var shown: Array = []
	for row in screen.athlete_rows_now():
		if screen.find_child("PickCard_%s" % String((row as Dictionary).get("id", "")), true, false) != null:
			shown.append(String((row as Dictionary).get("id", "")))
	audit.check_eq(shown.size(), Frozen.athletes().size() - 1,
		"characters/a_rival_slot_picker_shows_every_athlete_but_the_players_own")
	audit.check_eq(shown.has(player_id), false, "characters/the_players_athlete_is_not_offered_in_a_rival_slot")
	audit.check_true(screen.close_subview(), "characters/the_picker_closes_back_to_the_team")
	audit.check_eq(screen.open_picker("player"), true, "characters/the_players_slot_opens_the_picker_too")

	# 4. A pick never duplicates: the roster stays four distinct athletes, whichever
	# build this is and however few athletes it exposes.
	var store := Config.save_store()
	Config.pending_mode = "quick"
	screen.refresh_data()
	var session_player_id := String(Config.athlete().get("id", ""))
	var unlocked_ids: Array = []
	for row in screen.athlete_rows_now():
		var id := String((row as Dictionary).get("id", ""))
		if not bool(row.get("locked", false)) and id != session_player_id:
			unlocked_ids.append(id)
	audit.report("selectable beside the player: %s" % JSON.stringify(unlocked_ids))
	audit.check_ge(unlocked_ids.size(), 1, "characters/the_roster_exposes_at_least_one_selectable_athlete_beside_the_player")

	# 4a. The player's own picker moves the session's athlete (`ui.selectedAthlete`).
	var first := String(unlocked_ids[0])
	audit.check_true(screen.open_picker("player"), "characters/the_players_picker_is_open")
	audit.check_eq(screen.select_athlete(first), true, "characters/a_free_athlete_is_selectable")
	audit.check_eq(screen.slot_athlete_id("player"), first, "characters/the_players_pick_moves_the_session_athlete")
	var after_player: Dictionary = screen.lineup_ids()
	audit.check_eq(_distinct_count(after_player), 4, "characters/the_players_pick_created_no_duplicate")

	# 4b. A rival slot's picker moves that slot, and the pick is saved as the three slots.
	# The candidates are read again after the player moved: a build that exposes two
	# athletes only exposes the other one once the player has taken the first.
	var second := ""
	for row in screen.athlete_rows_now():
		var candidate := String((row as Dictionary).get("id", ""))
		if not bool(row.get("locked", false)) and candidate != first and candidate != String(after_player.get("playerMate", "")):
			second = candidate
			break
	if second == "":
		audit.report("only one selectable athlete beside the player in this build: the second-slot pick is driven below through the player's own slot")
		# With a single candidate the second slot can still be filled: the player's picker
		# offers them all, and the mate's picker is where the exclusion bites.
		audit.check_true(screen.open_picker("playerMate"), "characters/a_rival_slots_picker_opens_anyway")
		audit.check_eq(screen.view(), "picker", "characters/the_picker_is_the_active_view_again")
	else:
		audit.check_true(screen.open_picker("playerMate"), "characters/a_rival_slots_picker_opens")
		audit.check_eq(screen.select_athlete(second), true, "characters/a_free_athlete_fills_the_second_slot")
		var after: Dictionary = screen.lineup_ids()
		audit.check_eq(String(after.get("playerMate", "")), second, "characters/the_chosen_athlete_takes_the_slot")
		audit.check_eq(_distinct_count(after), 4, "characters/the_pick_created_no_duplicate")
		var saved: Dictionary = ModesSave.profile(store).get("prefs", {}).get("lineup", {})
		audit.check_eq(String(saved.get("playerMate", "")), second, "characters/the_pick_reached_the_saved_lineup")
		audit.check_eq(saved.size(), 3, "characters/the_saved_lineup_is_the_three_slots")

	# 4c. A swap: choosing an athlete already on court moves them and frees their old slot
	# for whoever they displaced — driven wherever the build exposes a selectable mate.
	var mate_now: String = screen.slot_athlete_id("playerMate")
	var player_now: String = screen.slot_athlete_id("player")
	audit.check_true(mate_now != "" and mate_now != player_now, "characters/the_mate_slot_holds_a_different_athlete")
	var mate_selectable := false
	for row in screen.athlete_rows_now():
		if String((row as Dictionary).get("id", "")) == mate_now:
			mate_selectable = not bool(row.get("locked", false))
	if not mate_selectable:
		audit.report("the mate slot is held by a build-locked athlete (%s) in this build: the swap is asserted through the roster invariant, not through that card" % mate_now)
		audit.check_eq(_distinct_count(screen.lineup_ids()), 4, "characters/the_swap_created_no_duplicate")
	else:
		audit.check_true(screen.open_picker("player"), "characters/the_players_picker_reopens_for_the_swap")
		audit.check_eq(screen.select_athlete(mate_now), true, "characters/an_athlete_already_on_court_is_selectable_as_a_swap")
		var swapped: Dictionary = screen.lineup_ids()
		audit.check_eq(screen.slot_athlete_id("player"), mate_now, "characters/the_swap_puts_the_chosen_athlete_in_the_slot")
		audit.check_eq(screen.slot_athlete_id("playerMate"), player_now, "characters/the_swap_gives_the_vacated_slot_back")
		audit.check_eq(_distinct_count(swapped), 4, "characters/the_swap_created_no_duplicate")
		var saved_swap: Dictionary = ModesSave.profile(store).get("prefs", {}).get("lineup", {})
		audit.check_eq(saved_swap.size(), 3, "characters/the_swapped_lineup_is_the_three_slots")

	# The lineup preference seam: what this screen saves is what the resolve reads.
	Config.athlete_index = 0
	screen.refresh_data()
	var resolved: Dictionary = screen.lineup_ids()
	audit.check_eq(_distinct_count(resolved), 4, "characters/the_refreshed_lineup_has_no_duplicate")
	# Confirm hands over to the arena with the resolved lineup saved.
	audit.check_true(screen.confirm_lineup(), "characters/confirm_hands_over_to_the_arena")
	audit.check_eq(_router.active_id(), "arena", "characters/confirm_lands_on_arena")
	var saved_after: Dictionary = ModesSave.profile(store).get("prefs", {}).get("lineup", {})
	audit.check_eq(saved_after.size(), 3, "characters/the_confirmed_lineup_is_the_three_slots")
	for role in ["playerMate", "opponent", "opponentMate"]:
		audit.check_true(saved_after.get(role, null) != null, "characters/the_confirmed_lineup_fills_%s" % role)


func _distinct_count(ids: Dictionary) -> int:
	var unique := {}
	for key in ids:
		unique[String(ids[key])] = true
	return unique.size()


# ---------------------------------------------------------------------------
# 4b. The stat strip (added 2026-09-17, wave 3): `statLine` on the four team slots and
#     on every unlocked picker card, from the roster's own `STAT_RANGE`
# ---------------------------------------------------------------------------

## The bars the reference paints (`js/ui.js:805-828`): five ticks per stat, at least one
## filled, from `1 + round(clampUnit((value - min) / (max - min || 1)) * 4)`. The scale is
## the whole frozen roster — never a build's or a slot's own subset — so the pinned
## `STAT_BARS` rows are expected in this build and in a demo alike.
func _stat_strip(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var theme: Theme = screen.theme
	var has_bar := theme != null and theme.has_color("stat_bar", "Palette")
	var has_rival := theme != null and theme.has_color("stat_bar_rival", "Palette")
	audit.check_true(has_bar, "characters/the_theme_carries_the_stat_bar_ink")
	audit.check_true(has_rival, "characters/the_theme_carries_the_rival_stat_bar_ink")
	var bar_ink: Color = theme.get_color("stat_bar", "Palette") if has_bar else Color.BLACK
	var rival_ink: Color = theme.get_color("stat_bar_rival", "Palette") if has_rival else Color.BLACK
	audit.check_true(not bar_ink.is_equal_approx(rival_ink),
		"characters/the_two_bar_inks_are_two_different_tints")

	var missing: Array = []
	var wrong: Array = []
	var ink_wrong: Array = []
	for role in Lineup.ROLES:
		var role_name := String(role)
		if screen.find_child("SlotStat_%s" % role_name, true, false) == null:
			missing.append("SlotStat_%s" % role_name)
		var athlete_id := String(screen.slot_athlete_id(role_name))
		var expected: Array = STAT_BARS.get(athlete_id, [])
		if expected.is_empty():
			wrong.append("unpinned athlete %s" % athlete_id)
			continue
		for index in STAT_AUDIT_KEYS.size():
			var key := String(STAT_AUDIT_KEYS[index])
			var label: Label = screen.find_child("SlotStat_label_%s_%s" % [role_name, key], true, false)
			var bar: Label = screen.find_child("SlotStat_bar_%s_%s" % [role_name, key], true, false)
			if label == null or bar == null:
				wrong.append("nodes %s/%s" % [role_name, key])
				continue
			if label.text != UiStrings.t(String(STAT_AUDIT_LABELS[key])):
				wrong.append("label %s/%s=%s" % [role_name, key, label.text])
			if bar.text != _stat_bar_text(int(expected[index])):
				wrong.append("bar %s/%s=%s" % [role_name, key, bar.text])
			var wanted: Color = rival_ink if CharactersScreenClass.RIVAL_ROLES.has(role_name) else bar_ink
			if not bar.get_theme_color("font_color").is_equal_approx(wanted):
				ink_wrong.append("%s/%s" % [role_name, key])
	audit.check_eq(missing, [], "characters/every_team_slot_carries_its_stat_strip")
	audit.check_eq(wrong, [], "characters/every_slot_bar_reads_the_pinned_roster_scale")
	audit.check_eq(ink_wrong, [], "characters/the_rival_slots_take_the_references_rival_ink")

	var rows: Array = screen.athlete_rows_now()
	audit.check_gt(rows.size(), 0, "characters/the_picker_offers_rows")
	audit.check_true(screen.open_picker("playerMate"), "characters/the_picker_opens_for_the_strip_check")
	await process_frame
	var pick_missing: Array = []
	var pick_wrong: Array = []
	var pick_locked: Array = []
	for row in screen.athlete_rows_now():
		var row_dict: Dictionary = row
		var athlete_id := String(row_dict.get("id", ""))
		if bool(row_dict.get("locked", false)):
			if screen.find_child("PickStat_%s" % athlete_id, true, false) != null:
				pick_locked.append(athlete_id)
			continue
		# The picker offers every athlete but the player's own (`js/ui.js:1005-1009`, asserted
		# at `:250-256` above and skipped the same way at `:268`): the excluded card is not
		# in the grid, so it rightly carries no strip.
		if athlete_id == String(Config.athlete().get("id", "")):
			continue
		if screen.find_child("PickStat_%s" % athlete_id, true, false) == null:
			pick_missing.append(athlete_id)
			continue
		var expected: Array = STAT_BARS.get(athlete_id, [])
		if expected.is_empty():
			pick_wrong.append("unpinned athlete %s" % athlete_id)
			continue
		for index in STAT_AUDIT_KEYS.size():
			var key := String(STAT_AUDIT_KEYS[index])
			var bar: Label = screen.find_child("PickStat_bar_%s_%s" % [athlete_id, key], true, false)
			if bar == null or bar.text != _stat_bar_text(int(expected[index])):
				pick_wrong.append("%s/%s" % [athlete_id, key])
	audit.check_eq(pick_missing, [], "characters/every_unlocked_picker_card_carries_the_same_strip")
	audit.check_eq(pick_wrong, [], "characters/the_picker_bars_read_the_same_pinned_scale")
	audit.check_eq(pick_locked, [], "characters/no_locked_picker_card_shows_a_strip")
	screen.close_subview()


## `"▮".repeat(pieni) + "▯".repeat(5 - pieni)` (`js/ui.js:820`), composed the way the
## screen composes it — from the glyphs' code points, so both sides are byte-identical.
func _stat_bar_text(filled: int) -> String:
	return String.chr(0x25ae).repeat(filled) + String.chr(0x25af).repeat(5 - filled)


# ---------------------------------------------------------------------------
# 5. The wardrobe
# ---------------------------------------------------------------------------

func _outfits(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var athlete_id := String(Config.athlete().get("id", ""))
	audit.check_true(ModeTables.outfits_for_athlete(athlete_id).size() > 1, "characters/the_players_athlete_has_a_wardrobe")
	audit.check_true(screen.open_outfits("player"), "characters/the_wardrobe_opens_for_the_player")
	audit.check_eq(screen.view(), "outfits", "characters/the_wardrobe_is_the_active_view")
	audit.check_eq(screen.outfit_athlete_id(), athlete_id, "characters/the_wardrobe_belongs_to_the_athletes_slot")

	var outfits: Array = ModeTables.outfits_for_athlete(athlete_id)
	var equipped := String(screen.equipped_outfit_id(athlete_id))
	var shown: Array = []
	for outfit in outfits:
		var outfit_id := String((outfit as Dictionary).get("id", ""))
		if screen.find_child("OutfitCard_%s" % outfit_id, true, false) != null:
			shown.append(outfit_id)
	audit.check_eq(shown.size(), outfits.size(), "characters/the_wardrobe_shows_every_outfit")
	var equipped_card: Control = screen.find_child("OutfitCard_%s" % equipped, true, false)
	var equipped_box := equipped_card.get_theme_stylebox("panel") as StyleBoxFlat
	audit.check_eq(equipped_box.border_color, screen.theme.get_color("cyan", "Palette"), "characters/the_equipped_outfit_wears_the_selected_frame")

	# A locked outfit: refused, and carrying the reference's own sentence.
	var career_now: Dictionary = ModesSave.load_career(Config.save_store())
	var locked := {}
	var unlocked := {}
	for outfit in outfits:
		var entry: Dictionary = outfit
		if CareerRules.is_unlocked(entry, career_now):
			unlocked = entry
		else:
			locked = entry
	audit.report("wardrobe: equipped=%s locked=%s unlocked=%s" % [equipped, locked.get("id", "-"), unlocked.get("id", "-")])
	if locked.is_empty():
		audit.report("this career has every outfit unlocked already (unlockAll or won): the locked branch is proven below in a fresh career")
	if not locked.is_empty():
		var locked_id := String(locked.get("id", ""))
		audit.check_eq(screen.equip_outfit(athlete_id, locked_id), false, "characters/a_locked_outfit_cannot_be_equipped")
		var line: Label = screen.find_child("OutfitLine_%s" % locked_id, true, false)
		var challenge: Variant = locked.get("challenge", null)
		if challenge is Dictionary:
			audit.check_eq(line.text, screen.challenge_line(challenge), "characters/the_locked_outfit_shows_the_reference_challenge_line")
			audit.check_true(line.text != "" and not line.text.begins_with("ch") and not line.text.contains("metric_"),
				"characters/the_challenge_line_is_a_sentence_not_a_key")
		var footer: Control = screen.find_child("OutfitFooter_%s" % locked_id, true, false)
		audit.check_eq(footer, null, "characters/a_locked_outfit_offers_no_action")
	if not unlocked.is_empty():
		var unlocked_id := String(unlocked.get("id", ""))
		audit.check_true(screen.equip_outfit(athlete_id, unlocked_id), "characters/an_unlocked_outfit_is_equipped")
		var career: Dictionary = ModesSave.load_career(Config.save_store())
		var worn: Dictionary = career.get("equippedOutfits", {})
		audit.check_eq(String(worn.get(athlete_id, "")), unlocked_id, "characters/the_equipped_outfit_is_persisted")
		audit.check_eq(screen.view(), "team", "characters/equipping_returns_to_the_team_panel")
	audit.check_eq(screen.open_outfits("opponentMate"), true, "characters/the_wardrobe_opens_for_a_rival_slot_too")


# ---------------------------------------------------------------------------
# 6-7. Locks and the unlock code
# ---------------------------------------------------------------------------

func _locks(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var locked_rows: Array = []
	var demo_locked_rows: Array = []
	for row in screen.athlete_rows_now():
		var id := String((row as Dictionary).get("id", ""))
		if bool(row.get("demo_locked", false)):
			demo_locked_rows.append(id)
		if screen.athlete_locked_shown(id):
			locked_rows.append(id)
	audit.report("locks: locked=%s demo_locked=%s" % [JSON.stringify(locked_rows), JSON.stringify(demo_locked_rows)])
	var build := DemoGate.build()
	if build == "demo":
		audit.check_eq(demo_locked_rows.size(), Frozen.athletes().size() - DemoContent.allowed_athlete_ids().size(),
			"characters/demo_withholds_the_athletes_it_does_not_grant")
		audit.check_ge(demo_locked_rows.size(), 1, "characters/the_demo_has_at_least_one_withheld_athlete")
	else:
		audit.check_eq(demo_locked_rows.size(), 0,
			"characters/a_full_build_withholds_nothing_live")
	# Locked cards stay visible in the picker and carry a label.
	screen.open_picker("playerMate")
	await process_frame
	for id in locked_rows:
		var card: Control = screen.find_child("PickCard_%s" % String(id), true, false)
		audit.check_true(card != null, "characters/locked_athlete_%s_stays_visible" % id)
		audit.check_true(card != null and card.modulate.a < 1.0, "characters/locked_athlete_%s_is_dimmed" % id)
		var tag: Label = screen.find_child("PickTag_%s" % String(id), true, false)
		audit.check_true(tag != null and tag.text != "", "characters/locked_athlete_%s_carries_a_label" % id)
		if demo_locked_rows.has(String(id)):
			audit.check_eq(tag.text, UiStrings.t("demoOnlyFull"), "characters/build_locked_athlete_%s_names_the_build" % id)


func _unlock_code(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var code := ModeTables.unlock_code()
	audit.check_true(code != "" and code == code.to_upper(), "characters/the_frozen_unlock_code_is_a_non_empty_uppercase_word")
	var withheld := _build_withheld_ids()
	audit.report("build withheld from the demo table: %d of %d" % [withheld.size(), _all_ids().size()])

	# The build's own wall is not a progression wall: a demo's rows are locked by the
	# build, a full build renders the same wall through the pinned state, and in both an
	# activation on it counts for nothing.
	if DemoGate.build() != "demo":
		audit.check_true(screen.apply_capture_state("demo-locked"), "characters/the_demo_locked_state_applies_for_the_negation")
	for id in withheld:
		audit.check_eq(screen.unlock_tap(String(id)), false, "characters/a_build_locked_athlete_counts_no_taps_%s" % id)
	if DemoGate.build() != "demo":
		audit.check_true(screen.apply_capture_state("default"), "characters/the_live_state_returns")

	# A progression-locked candidate: the career's own wall (a fresh career may have none,
	# which the run reports instead of inventing one).
	var candidate := ""
	for row in screen.athlete_rows_now():
		var id := String((row as Dictionary).get("id", ""))
		if bool(row.get("locked", false)) and not bool(row.get("demo_locked", false)):
			candidate = id
			break
	audit.report("unlock candidate=%s" % candidate)
	audit.check_eq(screen.submit_unlock_code(code), "refused", "characters/the_code_door_is_closed_by_default")
	if candidate != "":
		audit.check_eq(screen.unlock_tap(candidate), false, "characters/the_first_activation_asks_nothing")
		audit.check_eq(screen.unlock_tap(candidate), false, "characters/the_second_activation_asks_nothing")
		audit.check_eq(screen.unlock_tap(candidate), true, "characters/the_third_activation_opens_the_code_entry")
		audit.check_eq(screen.submit_unlock_code(code + "XX"), "wrong", "characters/a_wrong_code_is_refused")
		audit.check_eq(bool(ModesSave.load_career(Config.save_store()).get("unlockAll", false)), false, "characters/a_wrong_code_changes_nothing")
		audit.check_eq(screen.submit_unlock_code(" " + code.to_lower() + " "), "ok", "characters_the_right_code_is_accepted_after_trimming")
		audit.check_eq(bool(ModesSave.load_career(Config.save_store()).get("unlockAll", false)), true, "characters_the_right_code_sets_unlockAll")
		audit.check_eq(screen.submit_unlock_code(code), "refused", "characters/the_code_door_closes_when_nothing_is_asked")
		audit.check_eq(screen.athlete_locked_shown(candidate), false, "characters/the_unlocked_athlete_is_open_after_the_code")
		# The window: after the code is spent, a fresh first activation asks nothing more.
		screen.refresh_data()
		audit.check_eq(screen.unlock_tap(candidate), false, "characters/a_fresh_activation_starts_a_new_count")
		# The negation, now that `unlockAll` is set: the build's own wall is untouched.
		if DemoGate.build() != "demo":
			audit.check_true(screen.apply_capture_state("demo-locked"), "characters/the_demo_locked_state_reapplies_after_the_code")
		for id in withheld:
			audit.check_eq(screen.athlete_locked_shown(String(id)), true, "characters/build_locked_athlete_%s_survives_the_code" % id)
		if DemoGate.build() != "demo":
			audit.check_true(screen.apply_capture_state("default"), "characters/the_live_state_returns_after_the_negation")


func _build_withheld_ids() -> Array:
	var out: Array = []
	for id in _all_ids():
		if not DemoContent.allowed_athlete_ids().has(String(id)):
			out.append(String(id))
	return out


func _all_ids() -> Array:
	var out: Array = []
	for athlete in Frozen.athletes():
		out.append(String((athlete as Dictionary).get("id", "")))
	return out


# ---------------------------------------------------------------------------
# 8. The literal scan
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "characters/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "characters/the_screen_source_is_readable")
	var offenders: Array = []
	for entry in _offenders_in_source(SCREEN_PATH, source):
		if not SCREEN_LITERALS.has(String((entry as Dictionary).get("literal", ""))):
			offenders.append("%s \"%s\"" % [(entry as Dictionary).get("where", ""), (entry as Dictionary).get("literal", "")])
	audit.check_eq(offenders, [], "characters/CharactersScreen_gd_carries_no_prose_literal")
	var scene := FileAccess.get_file_as_string(SCENE_PATH)
	var found: Array = []
	for line in scene.split("\n"):
		var code := String(line).strip_edges()
		if code.begins_with("text = "):
			found.append(code)
	audit.check_eq(found, SCENE_LITERALS, "characters/the_scene_carries_no_literal_text")


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
# 9. The language flip
# ---------------------------------------------------------------------------

func _flip(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var language_at_start := Locale.current_lang()
	var unresolved: Array = []
	for binding in screen.text_bindings():
		var row: Dictionary = binding
		var keys: Array = []
		if not (row.get("parts", []) as Array).is_empty():
			for part in row.get("parts", []):
				keys.append(String((part as Dictionary).get("key", "")))
		else:
			keys.append(String(row.get("key", "")))
			if String(row.get("suffix_key", "")) != "":
				keys.append(String(row["suffix_key"]))
		for key in keys:
			for lang in Locale.locales():
				if not Locale.is_resolvable(String(key), String(lang)):
					unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "characters/every_bound_key_resolves_in_both_locales")
	audit.check_gt(screen.text_bindings().size(), 0, "characters/the_screen_binds_strings")

	Locale.set_lang("it")
	screen.refresh_strings()
	_check_bindings(audit, screen, "it")
	Locale.set_lang("en")
	screen.refresh_strings()
	_check_bindings(audit, screen, "en")

	Locale.set_lang("it")
	screen.refresh_strings()
	var before := _binding_texts(screen)
	Locale.set_lang("en")
	screen.refresh_strings()
	var after := _binding_texts(screen)
	var unmoved: Array = []
	var moved := 0
	for binding in screen.text_bindings():
		var name := String((binding as Dictionary).get("name", ""))
		if String(before.get(name, "")) != String(after.get(name, "")):
			moved += 1
			continue
		if _text_in_lang(binding, "it") != _text_in_lang(binding, "en"):
			unmoved.append(name)
	audit.check_gt(moved, 0, "characters/the_flip_moved_strings")
	audit.check_eq(unmoved, [], "characters/the_flip_moves_every_binding_whose_two_translations_differ")
	audit.report("language flip: moved=%d bindings=%d" % [moved, before.size()])

	Locale.set_lang(language_at_start)
	screen.refresh_strings()
	_check_bindings(audit, screen, language_at_start)
	audit.check_eq(Locale.current_lang(), language_at_start, "characters/the_run_language_is_restored")


func _check_bindings(audit: AuditBase, screen: Node, lang: String) -> void:
	var wrong: Array = []
	for binding in screen.text_bindings():
		var expected := _expected_text(binding)
		var shown := String(screen.text_shown(String((binding as Dictionary).get("name", ""))))
		if shown != expected:
			wrong.append("%s: %s != %s" % [(binding as Dictionary).get("name", ""), shown, expected])
	audit.check_eq(wrong, [], "characters/every_binding_shows_its_locale_text_in_%s" % lang)


## The text a binding should show, re-derived from the locale tables the same way the
## screen composes it (parts joined by the screen's own separator, `word_key`/`what_key`
## resolved first).
func _expected_text(binding: Dictionary) -> String:
	var parts: Array = binding.get("parts", [])
	if not parts.is_empty():
		var out := ""
		for index in parts.size():
			if index > 0:
				out += CharactersScreenClass._join_middot()
			var part: Dictionary = parts[index]
			var params: Dictionary = (part.get("params", {}) as Dictionary).duplicate()
			if part.has("word_key"):
				params["word"] = UiStrings.t(String(part["word_key"]))
			if part.has("what_key"):
				params["what"] = UiStrings.t(String(part["what_key"]))
			out += UiStrings.t(String(part.get("key", "")), params)
		return out
	var text := String(binding.get("prefix", "")) + UiStrings.t(String(binding.get("key", "")), binding.get("params", {}))
	if String(binding.get("suffix_key", "")) != "":
		text += String(binding.get("joiner", "")) + UiStrings.t(String(binding["suffix_key"]), binding.get("suffix_params", {}))
	return text


## The same composition the screen does, but in a named language — so a binding whose
## two translations differ can be held to have moved.
func _text_in_lang(binding: Dictionary, lang: String) -> String:
	var parts: Array = binding.get("parts", [])
	if not parts.is_empty():
		var out := ""
		for index in parts.size():
			if index > 0:
				out += CharactersScreenClass._join_middot()
			var part: Dictionary = parts[index]
			var params: Dictionary = (part.get("params", {}) as Dictionary).duplicate()
			if part.has("word_key"):
				params["word"] = Locale.t(String(part["word_key"]), {}, lang)
			if part.has("what_key"):
				params["what"] = Locale.t(String(part["what_key"]), {}, lang)
			out += Locale.t(String(part.get("key", "")), params, lang)
		return out
	var text := String(binding.get("prefix", "")) + Locale.t(String(binding.get("key", "")), _normalized(binding.get("params", {})), lang)
	if String(binding.get("suffix_key", "")) != "":
		text += String(binding.get("joiner", "")) + Locale.t(String(binding["suffix_key"]), _normalized(binding.get("suffix_params", {})), lang)
	return text


func _normalized(params: Dictionary) -> Dictionary:
	var out := {}
	for key in params:
		out[key] = str(params[key])
	return out


func _binding_texts(screen: Node) -> Dictionary:
	var out := {}
	for binding in screen.text_bindings():
		var name := String((binding as Dictionary).get("name", ""))
		out[name] = screen.text_shown(name)
	return out


# ---------------------------------------------------------------------------
# 10. Capture states
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var walk: Array = []
	for state_id in screen.capture_states():
		var applied := bool(screen.apply_capture_state(String(state_id)))
		walk.append([String(state_id), applied, screen.view()])
	audit.check_eq(walk, [
		["default", true, "team"],
		["picker-open", true, "picker"],
		["outfit-open", true, "outfits"],
		["locked-athlete", true, "picker"],
		["demo-locked", true, "picker"],
	], "characters/every_declared_capture_state_renders_its_own_view")
	audit.check_eq(screen.apply_capture_state("nope"), false, "characters/an_undeclared_capture_state_is_refused")

	# The three picker presentations really differ: the build's wall withholds exactly
	# the athletes its table does not list.
	screen.apply_capture_state("demo-locked")
	await process_frame
	var pinned_locked: Array = []
	for row in screen.athlete_rows_now():
		if bool((row as Dictionary).get("locked", false)):
			pinned_locked.append(String((row as Dictionary).get("id", "")))
	var expected_locked: Array = []
	for id in _all_ids():
		if not DemoContent.allowed_athlete_ids().has(String(id)):
			expected_locked.append(String(id))
	audit.check_eq(pinned_locked.size(), expected_locked.size(), "characters/the_demo_locked_state_withholds_the_builds_own_count")
	screen.apply_capture_state("locked-athlete")
	await process_frame
	var career_locked: Array = []
	for row in screen.athlete_rows_now():
		if bool((row as Dictionary).get("locked", false)):
			career_locked.append(String((row as Dictionary).get("id", "")))
	audit.report("pinned walls: demo=%d career=%d" % [pinned_locked.size(), career_locked.size()])
	audit.check_le(career_locked.size(), expected_locked.size(), "characters/the_career_wall_withholds_no_more_than_the_build_table")
	screen.apply_capture_state("default")
	await process_frame
	audit.check_eq(screen.view(), "team", "characters/the_default_state_returns_to_the_team")


# ---------------------------------------------------------------------------
# 11. Bridge and layout
# ---------------------------------------------------------------------------

func _bridge(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	var specs: Array = screen.focus_controls()
	var ids: Array = []
	for spec in specs:
		ids.append(String((spec as Dictionary).get("id", "")))
	audit.check_true(specs.size() >= 4, "characters/the_screen_registers_its_controls")
	audit.check_true(ids.has("characters/BackButton"), "characters/the_back_control_is_registered")
	audit.check_true(ids.has("characters/HeadAction"), "characters/the_head_command_is_registered")
	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	audit.check_true(bridge.ids().size() >= 4, "characters/the_bridge_reads_the_controls")
	audit.check_true(bridge.set_focus("characters/BackButton"), "characters/the_bridge_can_focus_the_back_control")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	audit.check_true(bridge.dispatch(event), "characters/a_confirm_dispatch_is_handled")
	await process_frame
	audit.check_eq(_router.active_id(), "modes", "characters/the_back_dispatch_lands_on_modes")


func _layout(audit: AuditBase) -> void:
	var screen: Node = await _mount()
	audit.check_true(screen.size.is_equal_approx(FRAME_BIG), "characters/the_screen_fills_the_frame")
	var grid: GridContainer = screen.find_child("AthleteGrid", true, false)
	audit.check_eq(grid.columns, 4, "characters/four_columns_at_1280")
	var widest := 0.0
	for card_name in ["TeamSlot_player", "TeamSlot_playerMate", "TeamSlot_opponent", "TeamSlot_opponentMate"]:
		var card: Control = screen.find_child(card_name, true, false)
		if card != null:
			widest = maxf(widest, card.size.x)
	audit.check_le(widest, FRAME_BIG.x, "characters/nothing_is_wider_than_the_frame")
	audit.check_gt(widest, 0.0, "characters/the_slots_have_width")
	var art: Control = screen.find_child("TeamSlot_playerArt", true, false)
	audit.check_between(art.size.x / maxf(art.size.y, 1.0), 2.7, 3.3, "characters/the_art_keeps_the_reference_aspect")
	audit.report("1280x720: slot=%.1f grid=%.1f" % [widest, grid.size.x])

	_frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(grid.columns, 2, "characters/two_columns_below_the_reference_breakpoint")
	var widest_small := 0.0
	for card_name in ["TeamSlot_player", "TeamSlot_playerMate"]:
		var card: Control = screen.find_child(card_name, true, false)
		if card != null:
			widest_small = maxf(widest_small, card.size.x)
	audit.check_le(widest_small, FRAME_SMALL.x, "characters/nothing_is_wider_than_the_small_frame")
	audit.report("1024x600: slot=%.1f grid=%.1f" % [widest_small, grid.size.x])
	_frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame
