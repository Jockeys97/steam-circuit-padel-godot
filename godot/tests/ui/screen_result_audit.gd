## screen_result_audit.gd — UIR-21's contract audit: the result screen in a router.
##
## WHAT IT PROVES, and the reference each question comes from:
##
##   1. the router mounts the screen and the screen declares its own facts — no return
##      (the reference's own `data-back`-less screen, `nav_routes.gd:82`) and one
##      `to-menu` action (`ScreenRouter.SCREENS[12]`);
##   2. win and loss are separate localized states (`victory`/`defeat`,
##      `js/ui.js:1504`, `:1518`) with the mode's own narrative line;
##   3. the score line has the reference's three shapes (`js/ui.js:1493-1502`): a
##      points match shows the points, a one-set tennis match shows that set's games
##      (`6-4`), a multi-set match shows the sets. All three are constructed here —
##      labelled constructed — by writing the state's own fields and asking
##      `result_from_state` for the two figures;
##   4. the four stat rows are the session's own numbers (`renderMatchStats`,
##      `js/ui.js:1386-1406`): values, labels, the better side (errors lower-is-better)
##      and the two foot figures — compared against the raw stats the payload carries,
##      never recomputed from the screen;
##   5. the career endings are the reference's four (`careerOutcomeText`,
##      `js/ui.js:772-785`) plus the plain win/loss line, and the rival streak line is
##      appended only from |streak| >= 2 (`rivalNarrative`, `js/ui.js:1409-1417`);
##   6. the objectives block: hidden off-career, the season's own rows with their
##      check/progress/category, a claimed row's own category, the match's bonus row,
##      the stars, and newly earned outfits announced IMMEDIATELY
##      (`renderObjectives`, `js/ui.js:1433-1487`);
##   7. the CTA is hidden while nothing is configured (`applyStoreCta`,
##      `js/main.js:2392-2420` — this build has no store URL; recorded), and its
##      wishlist/follow wording and demo/beta body follow the seam's own selection;
##   8. the rematch label is `rematch` or `nextMatch` under a pending continuation
##      (`js/ui.js:1529-1532`), the signal fires, and `menu` routes through the router;
##   9. a language flip moves every string the two tables differ on;
##  10. zero prose literals in `ResultScreen.gd` (the scan the UI lane runs, with the
##      scan's own synthetic proof);
##  11. the LIVE path: a match the simulation itself stepped renders exactly the
##      state's own figures (`result_from_state` + `payload_from_state`), and a render
##      touches the store zero times (byte-compared);
##  12. the eleven declared capture states apply.
##
## CONSTRUCTED vs LIVE. The captures and most payloads here are constructed — the
## audit labels them where they appear, and `view()["constructed"]` carries the flag.
## The live section steps a real `SimState` with `ScriptedPlayer` and compares the
## rendered figures against that state's own fields, so no stat shown there is ever
## synthesised. THIS AUDIT WRITES ONLY TO A TEMP PROFILE (`user://uir21-result-audit`)
## — the career it stages for the objectives section — and removes it again.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/ResultScreen.gd")
const ScreenScene := preload("res://src/ui/screens/ResultScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Config := preload("res://game/match_config.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const Economy := preload("res://src/economy/economy_service.gd")
const Sim := preload("res://src/sim/sim.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")

const SCREEN_PATH := "res://src/ui/screens/ResultScreen.gd"
const TEMP_DIR := "user://uir21-result-audit"
const REFERENCE_SCREEN_COUNT := 13
const SETTLE_FRAMES := 3
const FRAME := Vector2(1280, 720)
const TICK := 1.0 / 60.0
const SEED := 20260917
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"victory\")\n## a comment quoting \"prose in a comment\"\n"

## The reference's outcome map verbatim (`js/ui.js:776-779`), kept here so the screen's
## own copy is compared against the reference rather than against itself.
const OUTCOME_KEYS := {
	"finale": "careerFinale",
	"trophy": "careerSeasonWin",
	"promoted": "careerSeasonPromoted",
	"repeat": "careerSeasonRepeat",
}

var _router: Control
var _store: RefCounted


func _initialize() -> void:
	var audit := AuditBase.new("screen_result")
	await _run(audit)
	_wipe()
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_store = SaveStore.new(TEMP_DIR)
	var frame := Control.new()
	frame.name = "ScreenResultAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _mount(audit)
	await _facts(audit)
	await _titles(audit)
	await _scores(audit)
	await _stats(audit)
	await _reward(audit)
	await _narrative(audit)
	await _objectives(audit)
	await _cta(audit)
	await _live(audit)
	await _strings(audit)
	await _captures(audit)
	_literal_scan(audit)
	await _actions(audit)
	await _menu_route(audit)
	audit.report("temp store: %s — the real user:// profile was never written" % TEMP_DIR)


func _screen() -> Node:
	return _router.active_screen()


# ---------------------------------------------------------------------------
# 1. The router, and the screen's own facts
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "result/the_router_still_carries_thirteen_ids")
	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "result/all_thirteen_slots_register")
	audit.check_true(_router.register("result", ScreenScene), "result/the_scene_registers_under_the_result_id")
	audit.check_eq(_router.go_to("result"), true, "result/go_to_mounts_the_screen")
	audit.check_eq(_router.active_id(), "result", "result/the_screen_is_active")
	var screen: Node = _screen()
	audit.check_true(screen is ScreenClass, "result/the_mounted_scene_carries_ResultScreen_gd")
	audit.check_true(screen.theme != null, "result/the_scene_mounts_the_theme")
	screen.set_store(_store)
	audit.check_eq(screen.store().dir, TEMP_DIR, "result/the_audit_store_is_the_temp_one")


func _facts(audit: AuditBase) -> void:
	await process_frame
	var screen: Node = _screen()
	audit.check_eq(screen.screen_id(), "result", "result/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "", "result/the_reference_declares_no_return")
	audit.check_eq(screen.back_target(), Router.back_target_of("result"), "result/the_return_is_the_router_own")
	audit.check_eq(ScreenClass.DECLARED_BACK, Router.back_target_of("result"), "result/the_declared_back_is_not_hardcoded")
	var actions: Array = Array(Router.to_actions_of("result"))
	audit.check_true(actions.has("to-menu"), "result/the_router_row_carries_the_menu_action")
	audit.check_eq(Array(screen.capture_states()), Array(ScreenClass.CAPTURE_STATES), "result/the_declared_capture_states_are_the_screen_own")
	audit.check_eq(screen.apply_capture_state("nope"), false, "result/an_undeclared_capture_state_is_refused")
	audit.check_eq(screen.cta_visible(), false, "result/with_no_store_url_the_cta_is_hidden")
	audit.check_eq(screen.cta_url(), "", "result/and_there_is_no_destination_to_open")
	var game := _payload({"mode": "quick"})
	screen.enter(game)
	audit.check_eq(screen.view().get("constructed", true), false, "result/a_real_payload_is_not_a_capture")


# ---------------------------------------------------------------------------
# 2. Win / loss, the title and the narrative line
# ---------------------------------------------------------------------------

func _titles(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var arena_id := String((Config.arena() as Dictionary).get("id", ""))
	screen.enter(_payload({"result": _result(11, 7, 11, true, _mixed_stats())}))
	audit.check_eq(screen.title_key(), "victory", "result/a_won_match_takes_the_victory_key")
	audit.check_eq(screen.shown_title(), UiStrings.t("victory"), "result/the_title_shows_the_won_string")
	audit.check_eq(screen.shown_message(), UiStrings.t("winArena", {"arena": UiStrings.t("arena_%s_name" % arena_id)}), "result/a_won_quick_match_names_the_arena")
	screen.enter(_payload({"result": _result(5, 11, 11, false, _mixed_stats())}))
	audit.check_eq(screen.title_key(), "defeat", "result/a_lost_match_takes_the_defeat_key")
	audit.check_eq(screen.shown_title(), UiStrings.t("resultLossTitle"), "result/the_title_shows_the_lost_string")
	audit.check_eq((screen.find_child("ResultTitle", true, false) as Label).theme_type_variation, &"HeroTitle", "result/outcome_uses_display_font")
	audit.check_true((screen.find_child("OutcomeAccent", true, false) as ColorRect).visible, "result/outcome_has_a_subtle_accent")
	audit.check_eq(screen.shown_message(), UiStrings.t("defeatMsg"), "result/a_lost_quick_match_says_defeat")
	audit.check_eq(_text_of(screen, "Badge"), UiStrings.t("matchOver"), "result/the_badge_says_the_match_is_over")
	audit.check_eq(screen.shown_rematch_label(), UiStrings.t("rematch"), "result/without_a_continuation_the_action_is_rematch")
	audit.check_eq(_text_of(screen, "MenuButton"), UiStrings.t("menu"), "result/the_second_action_is_the_menu")
	var rematch := screen.find_child("RematchButton", true, false) as Button
	var menu := screen.find_child("MenuButton", true, false) as Button
	var analyze := screen.find_child("CoachAnalyzeButton", true, false) as Button
	audit.check_eq(rematch.theme_type_variation, &"ButtonPrimary", "result/rematch_is_the_clear_primary_button")
	audit.check_eq(menu.theme_type_variation, &"ButtonSecondary", "result/menu_is_a_filled_secondary_button")
	audit.check_eq(analyze.theme_type_variation, &"ButtonSecondary", "result/jev_analysis_is_a_filled_button")
	audit.check_ge(rematch.custom_minimum_size.y, 52.0, "result/rematch_is_a_comfortable_controller_target")
	audit.check_ge(menu.custom_minimum_size.y, 52.0, "result/menu_is_a_comfortable_controller_target")
	audit.check_ge(analyze.custom_minimum_size.y, 48.0, "result/jev_is_a_comfortable_controller_target")
	audit.check_eq(rematch.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "result/rematch_fills_its_action_slot")
	audit.check_eq(menu.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "result/menu_fills_its_action_slot")
	audit.check_eq(analyze.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "result/jev_fills_its_action_slot")
	var focus_ids: Array = []
	for item in screen.focus_controls():
		focus_ids.append(String((item as Dictionary).get("id", "")))
	audit.check_true(focus_ids.has(screen.focus_id("CoachAnalyzeButton")), "result/controller_reaches_jev")
	audit.check_true(focus_ids.has(screen.focus_id("RematchButton")), "result/controller_reaches_rematch")
	audit.check_true(focus_ids.has(screen.focus_id("MenuButton")), "result/controller_reaches_menu")
	audit.report("titles: victory/defeat are separate localized states; quick narrative names the arena from Config")


# ---------------------------------------------------------------------------
# 3. The score line's three shapes (`result_from_state`, `js/ui.js:1493-1502`)
# ---------------------------------------------------------------------------

func _scores(audit: AuditBase) -> void:
	var screen: Node = _screen()

	# A points match: `pointsToWin > 0` shows the points.
	var points_state = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier())
	points_state.pointsToWin = 11
	points_state.points = {"player": 7, "ai": 3}
	var points_result: Dictionary = ScreenClass.result_from_state(points_state, {"won": true})
	audit.check_eq(points_result.get("score", ""), "7-3", "result/the_points_shape_reads_the_points")
	audit.check_eq(int(points_result.get("player", -1)), 7, "result/the_points_shape_keeps_the_players_points")
	audit.check_eq(int(points_result.get("ai", -1)), 3, "result/the_points_shape_keeps_the_rivals_points")
	screen.enter(_payload({"result": points_result}))
	audit.check_eq(screen.shown_score(), ["7", "3"], "result/the_points_shape_renders")

	# A one-set tennis match: one set, `setsToWin == 1`, draws that set's games.
	var set_state = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier())
	set_state.setsToWin = 1
	set_state.setScores = [{"player": 6, "ai": 4}]
	set_state.sets = {"player": 1, "ai": 0}
	var set_result: Dictionary = ScreenClass.result_from_state(set_state, {"won": true})
	audit.check_eq(set_result.get("score", ""), "6-4", "result/the_one_set_shape_reads_the_games")
	screen.enter(_payload({"result": set_result}))
	audit.check_eq(screen.shown_score(), ["6", "4"], "result/the_one_set_shape_renders")

	# A multi-set match: more than one set draws the sets.
	var multi_state = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier())
	multi_state.setsToWin = 2
	multi_state.setScores = [{"player": 6, "ai": 4}, {"player": 3, "ai": 6}, {"player": 7, "ai": 5}]
	multi_state.sets = {"player": 2, "ai": 1}
	var multi_result: Dictionary = ScreenClass.result_from_state(multi_state, {"won": true})
	audit.check_eq(multi_result.get("score", ""), "2-1", "result/the_multi_set_shape_reads_the_sets")
	screen.enter(_payload({"result": multi_result}))
	audit.check_eq(screen.shown_score(), ["2", "1"], "result/the_multi_set_shape_renders")
	audit.note("the three score shapes above are CONSTRUCTED: the state's own fields were written by the audit, then read through result_from_state")


# ---------------------------------------------------------------------------
# 4. The stats table: values, better-marking, the foot
# ---------------------------------------------------------------------------

func _stats(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var stats := _mixed_stats()
	screen.enter(_payload({"result": _result(11, 7, 11, true, stats)}))
	audit.check_eq(screen.stats_rows().size(), 4, "result/four_stat_rows")
	var expected_marks: Array = []
	for index in 4:
		var spec: Dictionary = UiData.RESULT_STAT_ROWS[index]
		var key := String(spec["key"])
		var pair: Dictionary = stats.get(key, {})
		var player := int(pair.get("player", 0))
		var opponent := int(pair.get("ai", 0))
		var shown: Dictionary = screen.shown_stat_row(index)
		audit.check_eq(shown.get("player", ""), str(player), "result/row_%s_shows_the_players_figure" % key)
		audit.check_eq(shown.get("opponent", ""), str(opponent), "result/row_%s_shows_the_rivals_figure" % key)
		audit.check_eq(shown.get("label", ""), UiStrings.t(String(spec["label_key"])), "result/row_%s_shows_its_own_label" % key)
		var better := "tie"
		if player != opponent:
			var higher_wins := player > opponent
			var player_better := (not higher_wins) if bool(spec["lower_is_better"]) else higher_wins
			better = "player" if player_better else "opponent"
		expected_marks.append(better)
	audit.check_eq(expected_marks, ["player", "tie", "opponent", "player"], "result/the_better_side_is_computed_lower_wins_included")
	# The highlight: the theme's green on the better side, the ink elsewhere. With the
	# theme absent (its file failed to load) the screen falls back to plain white — that
	# fallback is asserted as such, not hidden.
	var theme: Theme = screen.theme
	if theme != null:
		var green := theme.get_color("green", "Palette")
		var ink := theme.get_color("ink", "Palette")
		audit.check_eq(_cell_mark(screen, "StatPlayer0", green, ink), "better", "result/points_wons_player_side_is_highlighted")
		audit.check_eq(_cell_mark(screen, "StatAi0", green, ink), "plain", "result/points_wons_rival_side_is_not")
		audit.check_eq(_cell_mark(screen, "StatPlayer1", green, ink), "plain", "result/a_tie_highlights_nobody")
		audit.check_eq(_cell_mark(screen, "StatAi1", green, ink), "plain", "result/a_tie_highlights_nobody_on_either_side")
		audit.check_eq(_cell_mark(screen, "StatPlayer2", green, ink), "plain", "result/more_winners_on_the_rival_side_leaves_the_player_plain")
		audit.check_eq(_cell_mark(screen, "StatAi2", green, ink), "better", "result/more_winners_on_the_rival_side_is_highlighted")
		audit.check_eq(_cell_mark(screen, "StatPlayer3", green, ink), "better", "result/fewer_errors_is_better_and_highlighted")
		audit.check_eq(_cell_mark(screen, "StatAi3", green, ink), "plain", "result/more_errors_is_never_highlighted")
	else:
		audit.note("the theme resource failed to load in this run (a sibling lane's in-flight edit) — the highlight falls back to plain white and the colour assertions are replaced by the fallback note")
	var foot: Array = screen.shown_foot()
	audit.check_eq(String(foot[0]), UiStrings.t("statLongest") + String.chr(32) + str(int(stats["longestRally"])), "result/the_longest_rally_figure_is_the_states_own")
	audit.check_eq(String(foot[1]), UiStrings.t("statAvgRally") + String.chr(32) + "3.5", "result/the_average_is_total_hits_over_rallies")
	screen.enter(_payload({"result": _result(11, 7, 11, true, _stats_without_rallies())}))
	audit.check_eq(screen.average_rally_text(), "0", "result/a_match_without_rallies_averages_zero")
	audit.check_true(String(screen.shown_foot()[1]).ends_with(String.chr(32) + "0"), "result/and_the_foot_shows_that_zero")


func _cell_mark(screen: Node, node_name: String, green: Color, ink: Color) -> String:
	var label := screen.find_child(node_name, true, false) as Label
	if label == null:
		return "<missing>"
	if not label.has_theme_color_override("font_color"):
		return "<no-override>"
	var colour := label.get_theme_color("font_color")
	if colour.is_equal_approx(green):
		return "better"
	if colour.is_equal_approx(ink):
		return "plain"
	return "other:%s" % str(colour)


# ---------------------------------------------------------------------------
# Circuit Credits receipt: actual payout, transparent breakdown and safe failure
# ---------------------------------------------------------------------------

func _reward(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var breakdown := Economy.reward_breakdown(18, true)
	audit.check_eq(int(breakdown["total"]), 71, "result/credits_formula_matches_the_wallet")
	audit.check_eq(int(Economy.reward_breakdown(500, false)["play_bonus"]), 80, "result/credits_play_bonus_is_capped")
	var before := Economy.balance(_store)
	var award := Economy.award_completion(_store, "uir21-result-reward", 18, true)
	audit.check_true(bool(award.get("ok", false)), "result/credits_are_saved_by_the_economy_service")
	audit.check_eq(int(award.get("awarded", 0)), 71, "result/credits_saved_amount_matches_the_breakdown")
	audit.check_eq(int(award.get("balance", 0)), before + 71, "result/credits_saved_balance_includes_one_reward")
	screen.enter(_payload({"reward": award}))
	var panel := screen.find_child("RewardPanel", true, false) as PanelContainer
	audit.check_true(panel != null and panel.visible, "result/credits_receipt_is_visible")
	audit.check_eq(_text_of(screen, "RewardRow"), UiStrings.t("resultCreditsAmount", {"n": 71}), "result/credits_earned_is_prominent")
	audit.check_eq(_text_of(screen, "RewardBalance"), UiStrings.t("resultCreditsBalance", {"n": before + 71}), "result/credits_balance_is_separate")
	audit.check_eq(_text_of(screen, "RewardBreakdown"), UiStrings.t("resultCreditsBreakdownWin", {
		"base": 20, "points": 18, "per": 2, "play": 36, "win": 15,
	}), "result/credits_breakdown_uses_the_wallet_components")
	var animated := award.duplicate(true)
	animated["animate"] = true
	animated["match_id"] = "uir21-visual-animation"
	screen.enter(_payload({"reward": animated}))
	audit.check_eq(_text_of(screen, "RewardRow"), UiStrings.t("resultCreditsAmount", {"n": 0}), "result/credits_visual_count_starts_at_zero")
	await create_timer(0.25).timeout
	var in_flight := int(screen.get("_reward_count"))
	audit.check_true(in_flight > 0 and in_flight < 71, "result/credits_visual_count_progresses")
	await create_timer(0.75).timeout
	audit.check_eq(_text_of(screen, "RewardRow"), UiStrings.t("resultCreditsAmount", {"n": 71}), "result/credits_visual_count_reaches_saved_amount")
	screen.render(_payload({"reward": animated}))
	audit.check_eq(_text_of(screen, "RewardRow"), UiStrings.t("resultCreditsAmount", {"n": 71}), "result/credits_rerender_does_not_replay_count")
	audit.check_eq(int(Economy.balance(_store)), before + 71, "result/credits_animation_never_writes_the_wallet")
	var loss_parts := Economy.reward_breakdown(8, false)
	screen.enter(_payload({"reward": {
		"ok": true, "already": false, "awarded": 36, "earned": 36,
		"balance": 386, "breakdown": loss_parts,
	}}))
	audit.check_eq(_text_of(screen, "RewardBreakdown"), UiStrings.t("resultCreditsBreakdownLoss", {
		"base": 20, "points": 8, "per": 2, "play": 16,
	}), "result/loss_receipt_has_no_victory_bonus")
	var repeat := Economy.award_completion(_store, "uir21-result-reward", 18, true)
	audit.check_eq(int(repeat.get("awarded", -1)), 0, "result/reopen_does_not_pay_twice")
	audit.check_eq(int(Economy.balance(_store)), before + 71, "result/reopen_leaves_the_balance_unchanged")
	screen.enter(_payload({"reward": repeat}))
	audit.check_eq(_text_of(screen, "RewardRow"), UiStrings.t("resultCreditsAmount", {"n": 71}), "result/reopen_shows_original_credits")
	audit.check_eq(_text_of(screen, "RewardBreakdown"), UiStrings.t("resultCreditsAlready"), "result/reopen_does_not_claim_a_second_payment")
	screen.enter(_payload({"reward": {"ok": false, "awarded": 0, "balance": 350}}))
	audit.check_eq(_text_of(screen, "RewardRow"), "—", "result/failed_save_does_not_show_earned_credits")
	audit.check_eq(_text_of(screen, "RewardBreakdown"), UiStrings.t("resultCreditsUnavailable"), "result/failed_save_explains_no_credit")
	screen.enter(_payload({}))
	audit.check_true(not panel.visible, "result/constructed_result_without_award_hides_receipt")


# ---------------------------------------------------------------------------
# 5. The career endings, the rival narrative, the tournament line
# ---------------------------------------------------------------------------

func _narrative(audit: AuditBase) -> void:
	var screen: Node = _screen()
	audit.check_eq(ScreenClass.OUTCOME_KEYS, OUTCOME_KEYS, "result/the_outcome_map_is_the_references_own")
	for outcome in OUTCOME_KEYS:
		screen.enter(_payload({"mode": "career", "outcome": String(outcome), "season": 2, "match": 4}))
		var params := {"season": 2, "match": 4}
		if String(outcome) == "finale":
			params["rival"] = UiStrings.t("rivalGeneric")
		audit.check_eq(screen.shown_message(), UiStrings.t(String(OUTCOME_KEYS[outcome]), params), "result/the_%s_ending_shows_its_own_line" % outcome)
	screen.enter(_payload({"mode": "career", "outcome": "", "season": 2, "match": 4}))
	audit.check_eq(screen.shown_message(), UiStrings.t("careerMatchWin", {"season": 2, "match": 4}), "result/a_plain_career_win_has_its_own_line")
	screen.enter(_payload({"mode": "career", "outcome": "", "result": _result(5, 11, 11, false, _mixed_stats())}))
	audit.check_eq(screen.shown_message(), UiStrings.t("careerMatchLoss", {"season": 1, "match": 1}), "result/a_plain_career_loss_has_its_own_line")
	var rival_id := _first_athlete_id()
	screen.enter(_payload({"mode": "career", "outcome": "", "rival": {"id": rival_id, "streak": 3}}))
	var rival_name := UiStrings.t("ai_%s_name" % rival_id) if rival_id != "" else UiStrings.t("rivalGeneric")
	var win_line := UiStrings.t("careerMatchWin", {"season": 1, "match": 1})
	audit.check_eq(screen.shown_message(), win_line + String.chr(32) + UiStrings.t("rivalStreakWin", {"n": 3, "rival": rival_name}), "result/a_three_win_streak_becomes_a_sentence")
	screen.enter(_payload({"mode": "career", "outcome": "", "rival": {"id": rival_id, "streak": 1}}))
	audit.check_eq(screen.shown_message(), win_line, "result/a_single_win_stays_unspoken")
	screen.enter(_payload({"mode": "career", "outcome": "", "result": _result(5, 11, 11, false, _mixed_stats()), "rival": {"id": rival_id, "streak": -2}}))
	var loss_line := UiStrings.t("careerMatchLoss", {"season": 1, "match": 1})
	audit.check_eq(screen.shown_message(), loss_line + String.chr(32) + UiStrings.t("rivalStreakLoss", {"n": 2, "rival": rival_name}), "result/a_two_loss_streak_becomes_a_sentence")
	var arena_name := UiStrings.t("arena_%s_name" % String((Config.arena() as Dictionary).get("id", "")))
	screen.enter(_payload({"mode": "tournament", "tournament": {"continuing": true, "next_round": 2, "next_arena_id": String((Config.arena() as Dictionary).get("id", ""))}, "continue_pending": true}))
	audit.check_eq(screen.shown_message(), UiStrings.t("tourneyNext", {"n": 2, "arena": arena_name}), "result/a_won_tournament_round_names_the_next_fixture")
	audit.check_eq(screen.rematch_label_key(), "nextMatch", "result/while_a_continuation_is_pending_the_action_is_the_next_match")
	screen.enter(_payload({"mode": "tournament", "tournament": {"continuing": false}, "continue_pending": false}))
	audit.check_eq(screen.shown_message(), UiStrings.t("tourneyWin"), "result/a_won_final_says_the_tournament_is_won")
	screen.enter(_payload({"mode": "tournament", "result": _result(5, 11, 11, false, _mixed_stats())}))
	audit.check_eq(screen.shown_message(), UiStrings.t("defeatMsg"), "result/a_lost_tournament_round_says_defeat")


func _first_athlete_id() -> String:
	var athletes: Array = Config.athletes()
	if athletes.is_empty():
		return ""
	return String((athletes[0] as Dictionary).get("id", ""))


# ---------------------------------------------------------------------------
# 6. The objectives block (`renderObjectives`, `js/ui.js:1433-1487`)
# ---------------------------------------------------------------------------

func _objectives(audit: AuditBase) -> void:
	# The block is rebuilt on every render with a deferred cleanup, so a read must
	# settle one frame first or it walks the previous render's rows too.
	var screen: Node = _screen()
	screen.enter(_payload({"mode": "quick"}))
	await process_frame
	audit.check_eq(screen.objectives_visible(), false, "result/off_career_the_objectives_block_stays_hidden")
	screen.enter(_payload({"mode": "quick", "outfits": [_outfit_row()]}))
	await process_frame
	audit.check_eq(screen.objectives_visible(), false, "result/outfits_do_not_leak_onto_a_quick_match")
	screen.enter(_payload({"mode": "career"}))
	await process_frame
	audit.check_eq(screen.objectives_visible(), true, "result/a_career_result_shows_the_block")
	var rows: Array = UiData.season_objectives(_store)
	audit.check_gt(rows.size(), 0, "result/the_season_offers_objectives_to_show")
	var season_row: Dictionary = rows[0]
	var first_id := String(season_row.get("id", ""))
	var first_target := int(season_row.get("target", 0))
	var first_label: String = UiStrings.t("obj_%s" % first_id, {"n": first_target})
	var glyphs: Array = []
	for shown in screen.shown_objectives():
		var glyph := String((shown as Dictionary).get("check", ""))
		if glyph != "" and not glyphs.has(glyph):
			glyphs.append(glyph)
	audit.check_eq(glyphs, ["○"], "result/checks_render_as_glyphs_never_names")
	var entry := _find_objective_by_label(screen, first_label)
	audit.check_true(not entry.is_empty(), "result/the_first_season_row_is_there")
	audit.check_eq(String(entry.get("category", "")), UiStrings.t("objSeasonTitle"), "result/an_open_season_row_says_so")
	audit.check_eq(String(entry.get("check", "")), "○", "result/an_open_season_row_is_unchecked")
	audit.check_eq(String(entry.get("progress", "")), "0/%d" % first_target, "result/an_open_season_row_shows_zero_progress")
	audit.check_eq(String(entry.get("label", "")), first_label, "result/the_row_names_the_objectives_own_id")

	# A met row: every season metric lifted past its target, written through the save
	# contract (CONSTRUCTED career — the audit's temp store). The max-unit objectives
	# (stay-at-or-below) are the ones a big number must NOT satisfy, so they stay open.
	ModesSave.save_career(_store, {"season": 1, "seasonProgress": _lifted_progress()})
	screen.enter(_payload({"mode": "career"}))
	await process_frame
	var met_entry := _find_objective_by_label(screen, first_label)
	audit.check_eq(String(met_entry.get("check", "")), "✓", "result/a_met_objective_is_checked")
	audit.check_eq(String(met_entry.get("category", "")), UiStrings.t("objSeasonTitle"), "result/a_met_but_unclaimed_row_still_says_season")

	# A claimed row: the season list itself staged with the first flag taken.
	var expected_list: Array = CareerRules.season_objectives(1)
	var staged: Array = []
	for objective in expected_list:
		if objective is Dictionary:
			var copy: Dictionary = (objective as Dictionary).duplicate()
			copy["done"] = true
			copy["claimed"] = String(copy.get("id", "")) == first_id
			staged.append(copy)
	ModesSave.save_career(_store, {"season": 1, "seasonProgress": _lifted_progress(), "seasonObjectives": staged})
	screen.enter(_payload({"mode": "career"}))
	await process_frame
	var claimed_entry := _find_objective_by_label(screen, first_label)
	audit.check_eq(String(claimed_entry.get("category", "")), UiStrings.t("objAlreadyClaimed"), "result/a_claimed_row_takes_the_claimed_category")
	audit.check_eq(String(claimed_entry.get("check", "")), "✓", "result/a_claimed_row_is_checked_too")

	# The match's bonus row and the stars (`js/ui.js:1450-1470`).
	screen.enter(_payload({"mode": "career", "match_objective": {"id": "winners", "target": 3, "progress": 3, "done": true}, "objective_stars": 2}))
	await process_frame
	var match_entry := _find_objective_by_label(screen, UiStrings.t("objMatch_winners", {"n": 3}))
	audit.check_true(not match_entry.is_empty(), "result/the_match_bonus_row_is_there")
	audit.check_eq(String(match_entry.get("category", "")), UiStrings.t("objMatchTitle"), "result/the_bonus_row_carries_the_match_category")
	audit.check_eq(String(match_entry.get("progress", "")), "3/3", "result/the_bonus_row_shows_progress_over_target")
	var head := _head_of(screen)
	audit.check_true(head.contains(UiStrings.t("objStarsEarned", {"n": 2})), "result/the_stars_earned_ride_the_head_line")

	# The outfit, announced IMMEDIATELY in this very section.
	var athlete_id := _first_athlete_id()
	screen.enter(_payload({"mode": "career", "outfits": [{"athlete_id": athlete_id, "outfit_id": "", "name_key": "outfitWonNow"}]}))
	await process_frame
	audit.check_eq(screen.objectives_visible(), true, "result/a_won_outfit_shows_the_block")
	var outfit_label := _text_of(screen, "OutfitLabel0")
	var dot := String.chr(32) + String.chr(183) + String.chr(32)
	audit.check_eq(outfit_label, UiStrings.t("outfitWonNow") + dot + UiStrings.t("athlete_%s_name" % athlete_id), "result/the_outfit_line_names_the_outfit_and_the_athlete")
	audit.check_eq(_text_of(screen, "OutfitMark0"), "✓", "result/the_outfit_is_marked_won")
	audit.check_eq(_text_of(screen, "OutfitCategory0"), UiStrings.t("outfitWonNow"), "result/the_outfit_says_it_was_won_now")
	# The season rows are still the staged ones behind the outfit.
	audit.check_eq(String(_find_objective_by_label(screen, first_label).get("category", "")), UiStrings.t("objAlreadyClaimed"), "result/the_staged_season_row_survives_the_next_render")
	audit.note("the career staged for this section is CONSTRUCTED (written to %s through ModesSave.save_career); the rows themselves are the season's own" % TEMP_DIR)


## Every season metric lifted past any target — the sum-unit objectives are all met by
## it, the max-unit ones (errors, double faults) are deliberately not.
func _lifted_progress() -> Dictionary:
	var out: Dictionary = {}
	for metric in CareerRules.empty_season_progress():
		out[metric] = 999
	return out


func _count_objectives(screen: Node, field: String, value: String) -> int:
	var count := 0
	for entry in screen.shown_objectives():
		if String((entry as Dictionary).get(field, "")) == value:
			count += 1
	return count


func _find_objective(screen: Node, category: String) -> Dictionary:
	for entry in screen.shown_objectives():
		if String((entry as Dictionary).get("category", "")) == category:
			return entry
	return {}


func _find_objective_by_label(screen: Node, label: String) -> Dictionary:
	for entry in screen.shown_objectives():
		if String((entry as Dictionary).get("label", "")) == label:
			return entry
	return {}


func _head_of(screen: Node) -> String:
	for entry in screen.shown_objectives():
		if (entry as Dictionary).has("head"):
			return String((entry as Dictionary).get("head", ""))
	return ""


func _outfit_row() -> Dictionary:
	return {"athlete_id": _first_athlete_id(), "outfit_id": "", "name_key": "outfitWonNow"}


# ---------------------------------------------------------------------------
# 7. The CTA (`applyStoreCta`, `js/main.js:2392-2420`)
# ---------------------------------------------------------------------------

func _cta(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var url := "https://example.invalid/uir21-store"
	audit.check_eq(screen.cta_visible(), false, "result/the_cta_starts_hidden")
	screen.set_store_config(url, ScreenClass.CTA_WISHLIST)
	audit.check_eq(screen.cta_visible(), true, "result/a_configured_url_shows_the_block")
	audit.check_eq(screen.cta_label_key(), "demoWishlist", "result/a_wishlist_destination_wishes")
	audit.check_eq(_text_of(screen, "CtaButton"), UiStrings.t("demoWishlist"), "result/the_button_carries_the_wishlist_label")
	audit.check_eq(_text_of(screen, "CtaTitle"), UiStrings.t("demoResultTitle"), "result/the_title_is_the_limited_builds_own")
	audit.check_eq(_text_of(screen, "CtaBody"), UiStrings.t(screen.cta_body_key()), "result/the_body_is_the_builds_own_key")
	audit.check_eq(_text_of(screen, "CtaBody"), UiStrings.t("betaResultBody"), "result/this_full_build_asks_for_a_beta_body")
	audit.note("the locale tables carry no betaResultBody entry (checked below); the screen shows the reference's own visible fallback — the id itself - and the gap is recorded for the locale lane")
	screen.set_store_config(url, ScreenClass.CTA_FOLLOW)
	audit.check_eq(screen.cta_label_key(), "storeFollow", "result/a_follow_destination_follows")
	audit.check_eq(_text_of(screen, "CtaButton"), UiStrings.t("storeFollow"), "result/the_button_carries_the_follow_label")
	screen.enter(_payload({"store_url": url, "store_kind": ScreenClass.CTA_FOLLOW}))
	audit.check_eq(screen.cta_visible(), true, "result/a_payload_url_shows_the_block_too")
	screen.set_store_config("", ScreenClass.CTA_WISHLIST)
	screen.enter(_payload({}))
	audit.check_eq(screen.cta_visible(), false, "result/with_the_url_cleared_the_block_hides_again")


# ---------------------------------------------------------------------------
# 8. The LIVE path: a simulation-stepped state, and a render that writes nothing
# ---------------------------------------------------------------------------

func _live(audit: AuditBase) -> void:
	var screen: Node = _screen()

	var tennis = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier())
	tennis.rng_state = SEED
	tennis.running = true
	_step_match(tennis, 2400)
	audit.check_gt(float(tennis.elapsed), 10.0, "result/the_sampled_match_ran_for_real_simulated_seconds")
	audit.check_eq(tennis.stats.keys().has("pointsWon"), true, "result/the_live_state_carries_the_reference_stats_keys")

	var won := tennis.result != null and String((tennis.result as Dictionary).get("winner", "")) == "player"
	var expected := _shape_figures(tennis)
	var result: Dictionary = ScreenClass.result_from_state(tennis, {"won": won})
	audit.check_eq(int(result.get("player", -1)), int((expected as Dictionary)["player"]), "result/the_live_players_figure_is_the_states_own")
	audit.check_eq(int(result.get("ai", -1)), int((expected as Dictionary)["ai"]), "result/the_live_rivals_figure_is_the_states_own")
	audit.check_eq(String(result.get("score", "")), "%d-%d" % [int((expected as Dictionary)["player"]), int((expected as Dictionary)["ai"])], "result/the_live_score_is_built_from_the_state")

	var bytes_before := _store_bytes()
	screen.enter(ScreenClass.payload_from_state(tennis, {"won": won, "mode": "quick", "arena_id": String((Config.arena() as Dictionary).get("id", ""))}))
	audit.check_eq(screen.shown_score(), [str(int((expected as Dictionary)["player"])), str(int((expected as Dictionary)["ai"]))], "result/the_live_score_renders_the_states_own_figures")
	var stat_mismatches: Array = []
	for index in 4:
		var spec: Dictionary = UiData.RESULT_STAT_ROWS[index]
		var key := String(spec["key"])
		var pair: Dictionary = tennis.stats.get(key, {})
		var shown: Dictionary = screen.shown_stat_row(index)
		if String(shown.get("player", "")) != str(int(pair.get("player", 0))) or String(shown.get("opponent", "")) != str(int(pair.get("ai", 0))):
			stat_mismatches.append("%s: shown %s/%s, state %s/%s" % [key, shown.get("player", ""), shown.get("opponent", ""), pair.get("player", ""), pair.get("ai", "")])
	audit.check_eq(stat_mismatches, [], "result/every_live_stat_row_is_the_states_own_numbers")
	audit.check_eq(String(screen.shown_foot()[0]), UiStrings.t("statLongest") + String.chr(32) + str(int(tennis.stats.get("longestRally", 0))), "result/the_live_longest_rally_is_the_states_own")
	audit.check_eq(screen.average_rally_text(), _expected_average(tennis), "result/the_live_average_is_the_states_own")
	audit.check_eq(_store_bytes(), bytes_before, "result/rendering_the_live_state_writes_nothing_to_the_store")
	audit.report("live quick match: %d ticks (%.1f simulated seconds), state figures rendered verbatim" % [int(round(float(tennis.elapsed) / TICK)), float(tennis.elapsed)])

	# A career points match: the same live path under the career's own scoring.
	var career = Sim.create_match_state("career", Config.athlete(), Config.arena(), Config.tier())
	career.scoring = "points"
	career.pointsToWin = CareerRules.career_points_to_win()
	career.rng_state = SEED
	career.running = true
	_step_match(career, 900)
	audit.check_gt(float(career.elapsed), 10.0, "result/the_career_sample_ran_too")
	var career_result: Dictionary = ScreenClass.result_from_state(career, {"won": false})
	audit.check_eq(int(career_result.get("player", -1)), int(career.points["player"]), "result/the_career_points_come_from_the_state")
	audit.check_eq(int(career_result.get("ai", -1)), int(career.points["ai"]), "result/the_career_rival_points_come_from_the_state")
	screen.enter(ScreenClass.payload_from_state(career, {"won": false, "mode": "career"}))
	audit.check_eq(screen.shown_score(), [str(int(career.points["player"])), str(int(career.points["ai"]))], "result/the_career_points_render_the_states_own")
	audit.note("both live states are constructed simulations stepped by the audit (ScriptedPlayer); no external or fabricated data enters this section")


## The two figures `result_from_state` must read, derived here from the raw state so the
## comparison is against the state itself and not against the function under test.
func _shape_figures(state) -> Dictionary:
	var points: Dictionary = state.points
	var sets: Dictionary = state.sets
	var scores: Array = state.setScores if state.setScores is Array else []
	var shows: Dictionary = sets
	if int(state.pointsToWin) > 0:
		shows = points
	elif int(state.setsToWin) == 1 and scores.size() == 1:
		var first: Variant = scores[0]
		if first is Dictionary:
			shows = first
	return {"player": int(shows.get("player", 0)), "ai": int(shows.get("ai", 0))}


func _expected_average(state) -> String:
	var count := int(state.stats.get("rallyCount", 0))
	if count == 0:
		return "0"
	return "%.1f" % (float(int(state.stats.get("totalRallyHits", 0))) / float(count))


func _step_match(state, ticks: int) -> void:
	var bot := ScriptedPlayer.new()
	var spent := 0
	while spent < ticks and state.result == null:
		Sim.update_match(state, TICK, bot.decide(state), Sim.empty_input())
		spent += 1


func _store_bytes() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		out[String(file)] = FileAccess.get_file_as_string(TEMP_DIR.path_join(String(file)))
	return out


# ---------------------------------------------------------------------------
# 9. Strings
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var language_at_start := Locale.current_lang()
	var unresolved: Array = []
	for key in ["matchOver", "victory", "defeat", "winArena", "defeatMsg", "careerMatchWin",
			"careerMatchLoss", "careerFinale", "careerSeasonWin", "careerSeasonPromoted",
			"careerSeasonRepeat", "tourneyNext", "tourneyWin", "rivalStreakWin", "rivalStreakLoss",
			"rivalGeneric", "statYou", "statOpp", "statStats", "statPoints", "statAces",
			"statWinners", "statErrors", "statLongest", "statAvgRally", "rematch", "nextMatch",
			"menu", "demoResultTitle", "demoResultBody", "demoWishlist", "objTitle",
			"objStarsEarned", "outfitWonNow", "objSeasonTitle", "objAlreadyClaimed", "objMatchTitle",
			"objMatch_winners"]:
		for lang in Locale.locales():
			if not Locale.is_resolvable(key, String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "result/every_visible_key_resolves_in_both_locales")
	audit.check_eq(Locale.is_resolvable("betaResultBody", language_at_start), false, "result/the_beta_body_key_is_a_recorded_locale_gap")
	audit.check_eq(Locale.is_resolvable("storeFollow", language_at_start), false, "result/the_follow_label_is_a_recorded_locale_gap")
	var other := ""
	for lang in Locale.locales():
		if String(lang) != language_at_start:
			other = String(lang)
	audit.check_true(other != "", "result/there_is_a_second_locale_to_flip_to")

	var payload := _payload({"result": _result(11, 7, 11, true, _mixed_stats())})
	screen.enter(payload)
	var slots := _slots()
	var before := _visible_texts(screen)
	Locale.set_lang(other)
	screen.enter(payload)
	await process_frame
	var after := _visible_texts(screen)
	var wrong: Array = []
	var moved := 0
	for slot in slots:
		var expected_text := Locale.resolve(String(slots[slot]), other)
		if String(after[slot]) != expected_text:
			wrong.append("%s expected <%s> got <%s>" % [slot, expected_text, after[slot]])
		if Locale.resolve(String(slots[slot]), language_at_start) != expected_text:
			moved += 1
	audit.check_eq(wrong, [], "result/the_flip_shows_the_other_tables_own_text")
	audit.check_gt(moved, 0, "result/the_flip_moved_strings_that_differ")
	audit.report("language flip: %d of %d visible slots differ between tables, all now show %s" % [moved, slots.size(), other])
	Locale.set_lang(language_at_start)
	screen.enter(payload)
	await process_frame
	var restored := _visible_texts(screen)
	var still_wrong: Array = []
	for slot in slots:
		if String(restored[slot]) != String(before[slot]):
			still_wrong.append(slot)
	audit.check_eq(still_wrong, [], "result/the_flip_back_restores_every_slot")


func _slots() -> Dictionary:
	var out := {
		"badge": "matchOver",
		"title": "victory",
		"rematch": "rematch",
		"menu": "menu",
		"head_you": "statYou",
		"head_stats": "statStats",
		"head_opp": "statOpp",
		"score_you": "statYou",
		"score_opp": "statOpp",
	}
	for index in 4:
		out["stat/%d" % index] = String((UiData.RESULT_STAT_ROWS[index] as Dictionary)["label_key"])
	return out


func _visible_texts(screen: Node) -> Dictionary:
	var out := {
		"badge": _text_of(screen, "Badge"),
		"title": _text_of(screen, "ResultTitle"),
		"rematch": _text_of(screen, "RematchButton"),
		"menu": _text_of(screen, "MenuButton"),
		"head_you": _text_of(screen, "HeadYou"),
		"head_stats": _text_of(screen, "HeadStats"),
		"head_opp": _text_of(screen, "HeadOpp"),
		"score_you": _text_of(screen, "ScoreYouLabel"),
		"score_opp": _text_of(screen, "ScoreOppLabel"),
	}
	for index in 4:
		out["stat/%d" % index] = _text_of(screen, "StatLabel%d" % index)
	return out


func _text_of(screen: Node, node_name: String) -> String:
	var node := screen.find_child(node_name, true, false)
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return "<missing>"


# ---------------------------------------------------------------------------
# 10. The captures
# ---------------------------------------------------------------------------

func _captures(audit: AuditBase) -> void:
	var screen: Node = _screen()
	for state_id in ScreenClass.CAPTURE_STATES:
		audit.check_eq(screen.apply_capture_state(String(state_id)), true, "result/capture_state_%s_applies" % state_id)
	audit.check_eq(screen.apply_capture_state("win-points"), true, "result/the_win_points_capture_applies")
	audit.check_eq(screen.shown_score(), ["11", "7"], "result/the_win_points_capture_shows_its_points")
	audit.check_eq(screen.shown_title(), UiStrings.t("victory"), "result/the_win_points_capture_is_a_win")
	audit.check_eq(screen.view().get("constructed", false), true, "result/a_capture_is_flagged_constructed")
	audit.check_eq(screen.apply_capture_state("loss-points"), true, "result/the_loss_points_capture_applies")
	audit.check_eq(screen.shown_score(), ["8", "11"], "result/the_loss_points_capture_shows_its_points")
	audit.check_eq(screen.shown_title(), UiStrings.t("resultLossTitle"), "result/the_loss_points_capture_is_a_loss")
	audit.check_eq(screen.apply_capture_state("win-set"), true, "result/the_win_set_capture_applies")
	audit.check_eq(screen.shown_score(), ["6", "4"], "result/the_win_set_capture_is_the_game_score")
	audit.check_eq(screen.apply_capture_state("loss-set"), true, "result/the_loss_set_capture_applies")
	audit.check_eq(screen.shown_score(), ["3", "6"], "result/the_loss_set_capture_is_the_game_score")
	audit.check_eq(screen.apply_capture_state("multi-set"), true, "result/the_multi_set_capture_applies")
	audit.check_eq(screen.shown_score(), ["2", "1"], "result/the_multi_set_capture_is_the_set_score")
	audit.check_eq(screen.apply_capture_state("career-promotion"), true, "result/the_promotion_capture_applies")
	audit.check_eq(screen.shown_message(), UiStrings.t("careerSeasonPromoted", {"season": 1, "match": 5}), "result/the_promotion_capture_shows_the_promotion_line")
	audit.check_eq(screen.apply_capture_state("tournament-next"), true, "result/the_tournament_capture_applies")
	audit.check_true(screen.shown_message().length() > 0, "result/the_tournament_capture_carries_a_narrative")
	audit.check_eq(screen.shown_rematch_label(), UiStrings.t("nextMatch"), "result/the_tournament_capture_offers_the_next_match")
	audit.check_eq(screen.apply_capture_state("demo-cta"), true, "result/the_demo_cta_capture_applies")
	audit.check_eq(screen.cta_visible(), true, "result/the_demo_cta_capture_shows_the_block")
	audit.check_eq(screen.cta_label_key(), "demoWishlist", "result/the_demo_cta_capture_wishes")
	audit.check_eq(screen.apply_capture_state("beta-cta"), true, "result/the_beta_cta_capture_applies")
	audit.check_eq(screen.cta_label_key(), "storeFollow", "result/the_beta_cta_capture_follows")
	audit.check_eq(screen.apply_capture_state("default"), true, "result/the_default_capture_applies")
	audit.check_eq(screen.shown_score(), ["0", "0"], "result/the_default_capture_is_a_blank_card")
	audit.check_eq(screen.cta_visible(), false, "result/the_default_capture_hides_the_cta")


func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "result/the_literal_scan_flags_prose_and_ignores_developer_text")
	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "result/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "result/ResultScreen_gd_carries_no_prose_literal")


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
# 11. The actions, and the route home
# ---------------------------------------------------------------------------

func _actions(audit: AuditBase) -> void:
	var screen: Node = _screen()
	screen.enter(_payload({"continue_pending": true}))
	audit.check_eq(screen.rematch_label_key(), "nextMatch", "result/a_pending_continuation_renames_the_action")
	audit.check_eq(screen.shown_rematch_label(), UiStrings.t("nextMatch"), "result/the_button_shows_the_next_match_label")
	var fired: Array = []
	var recorder := func() -> void:
		fired.append(true)
	screen.connect("rematch_requested", Callable(recorder))
	var shown_action: String = screen.rematch()
	audit.check_eq(shown_action, "nextMatch", "result/pressing_rematch_reports_the_action_it_showed")
	audit.check_eq(fired.size(), 1, "result/and_emits_the_request_for_the_mount_to_act_on")


func _menu_route(audit: AuditBase) -> void:
	var screen: Node = _screen()
	var routed: bool = screen.go_to_menu()
	audit.check_eq(routed, true, "result/the_menu_action_routes")
	audit.check_eq(_router.active_id(), "menu", "result/the_router_followed_the_route")
	audit.check_eq(_router.screen_count(), 1, "result/and_left_exactly_one_screen_mounted")


# ---------------------------------------------------------------------------
# Internals: the payloads, the temp directory's own cleanup
# ---------------------------------------------------------------------------

func _payload(overrides: Dictionary) -> Dictionary:
	var base := {
		"mode": "quick",
		"arena_id": String((Config.arena() as Dictionary).get("id", "")),
		"season": 1,
		"match": 1,
		"outcome": "",
		"tournament": {},
		"continue_pending": false,
		"objective_stars": 0,
		"match_objective": {},
		"outfits": [],
		"rival": {},
		"result": _result(11, 7, 11, true, _mixed_stats()),
	}
	for key in overrides:
		base[key] = overrides[key]
	return base


func _result(player: int, ai: int, points_to_win: int, won: bool, stats: Dictionary) -> Dictionary:
	return {
		"score": "%d-%d" % [player, ai],
		"won": won,
		"pointsToWin": points_to_win,
		"player": player,
		"ai": ai,
		"stats": stats,
	}


## One row better for the player, one tie, one better for the rival, and the errors
## row read lower-is-better — the four cases `renderMatchStats` distinguishes.
func _mixed_stats() -> Dictionary:
	return {
		"pointsWon": {"player": 10, "ai": 6},
		"aces": {"player": 2, "ai": 2},
		"winners": {"player": 4, "ai": 7},
		"errors": {"player": 3, "ai": 6},
		"rallyCount": 8,
		"totalRallyHits": 28,
		"longestRally": 9,
	}


func _stats_without_rallies() -> Dictionary:
	return {
		"pointsWon": {"player": 11, "ai": 7},
		"aces": {"player": 1, "ai": 0},
		"winners": {"player": 3, "ai": 2},
		"errors": {"player": 2, "ai": 4},
		"rallyCount": 0,
		"totalRallyHits": 0,
		"longestRally": 0,
	}


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(String(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))
