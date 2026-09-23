## result_coach_audit.gd — the coach block, on the real result screen, in the real router.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/ui/result_coach_audit.gd
##
## WHAT IT GATES, on the screen the player actually sees:
##   1. NOTHING RUNS ON ITS OWN. Mounting a result — and applying a capture state — leaves
##      the coach's request count at zero, with the disclosure and the account of what the
##      numbers are (your side's, both players) on screen before anything is asked.
##   2. THE PRESS IS THE ONLY TRIGGER, AND IT IS ONE REQUEST: the analyze button asks once,
##      shows the loading line, and a second press while the answer is in flight asks
##      nothing more; a finished reading is not thrown away by pressing again.
##   3. AN ADVICE IS EVIDENCE-BACKED AND LINKED: the sentence carries the match's own
##      numbers, the exercise is the frozen table's own name, and the button routes to the
##      EXISTING drill screen with that exercise selected — while writing neither
##      `Config.pending_mode` nor `Config.pending_exercise`.
##   4. A PENDING CONTINUATION IS NOT PUT AT RISK: with the run one press from continuing,
##      the block names the exercise and says where the training opens instead, and the
##      button is not offered at all.
##   5. EVERY WEAK OUTCOME IS TRUTHFUL AND RESTRAINED: uncertain shows the numbers and no
##      exercise, an unreachable bridge names itself (never "Jev analyzed"), an
##      unverifiable answer is refused, and a match without enough measured counters never
##      leaves the machine.
##   6. THE EXIT CANCELS: a reply that arrives after the screen is left paints nothing.
##   7. A LANGUAGE FLIP REACHES THE BLOCK with the rest of the screen.
##
## The match payloads here are CONSTRUCTED — every one of them is labelled so where it is
## built — because this audit is about the block's states and its route, not about the
## simulation: the live counters are `res://tests/coach_test.gd`'s section 7.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const Advice := preload("res://src/coach/coach_advice.gd")
const AuditBase := preload("res://src/audits/audit_base.gd")
const CoachText := preload("res://src/coach/coach_text.gd")
const Config := preload("res://game/match_config.gd")
const DrillScene := preload("res://src/ui/screens/DrillScreen.tscn")
const Locale := preload("res://src/locale/locale.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenClass := preload("res://src/ui/screens/ResultScreen.gd")
const ScreenScene := preload("res://src/ui/screens/ResultScreen.tscn")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const DrillText := preload("res://src/modes/drill_text.gd")

const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 3
## The category the model picks, and the exercise that category links to.
const SERVE_FOCUS := "serve_accuracy"
const DRILL_TARGET := "serve"
## The serve-return ticket's own category and its Godot-only exercise
## (`docs/agent-work/jev-return/PLAN.md`).
const RETURN_FOCUS := "serve_return"
const RETURN_TARGET := "return"
const PENDING_MODE := "career"

## A transport the audit drives itself, through the panel's documented seam.
class FakePoster extends RefCounted:
	var calls: Array = []
	var callbacks: Array = []
	var cancelled := 0

	func post(url: String, body: String, timeout_ms: int, on_done: Callable) -> void:
		calls.append({"url": url, "body": body, "timeout_ms": timeout_ms})
		callbacks.append(on_done)

	func cancel() -> void:
		cancelled += 1

	func deliver(index: int, reply: Dictionary) -> void:
		if index < callbacks.size():
			callbacks[index].call(reply)


var _router: Control


func _initialize() -> void:
	var audit := AuditBase.new("result_coach")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	var frame := Control.new()
	frame.name = "ResultCoachAuditFrame"
	frame.size = FRAME
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	_router.register("result", ScreenScene)
	_router.register("menu", PlaceholderScene)
	_router.register("drill", DrillScene)
	for _i in SETTLE_FRAMES:
		await process_frame
	await _idle(audit)
	await _controller_actions(audit)
	await _advice(audit)
	await _continuation(audit)
	await _states(audit)
	await _reuse_and_retry(audit)
	await _exit(audit)
	await _strings(audit)


## A CONSTRUCTED result: the four stat groups and the three rally counters a match writes,
## with the numbers of an 11-7 win. Nothing here claims a match was played — the payload is
## a fixture, and the block never reads anything else.
func _controller_actions(audit: AuditBase) -> void:
	var mounted := await _mount(_payload())
	var screen: Node = mounted[0]
	var poster: RefCounted = mounted[2]
	var focus = load("res://game/menu_focus.gd").new("result")
	var bridge = load("res://src/ui/focus/UiFocusBridge.gd").new()
	bridge.attach(screen.get_node("Shell"), focus, _router)
	bridge.action_requested.connect(func(action: String): screen.call("activate", action))
	var rematches := [0]
	screen.rematch_requested.connect(func(): rematches[0] += 1)
	for suffix in ["RematchButton", "CoachAnalyzeButton", "MenuButton"]:
		audit.check_true(bridge.set_focus(screen.call("focus_id", suffix)), "pad/focus_" + suffix)
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = JOY_BUTTON_A # Godot south button: Xbox A / PlayStation cross.
		event.pressed = true
		bridge.act(focus.handle_pad_event(event, 0))
		event.pressed = false
		focus.handle_pad_event(event, 0)
		if suffix == "RematchButton":
			audit.check_eq(rematches[0], 1, "pad/rematch_emits_once")
			audit.check_eq(screen.call("activate", "unknown"), false, "pad/unknown_is_inert")
			audit.check_eq(screen.call("activate", "coach-drill"), false, "pad/hidden_drill_is_inert")
		elif suffix == "CoachAnalyzeButton":
			audit.check_eq(poster.calls.size(), 1, "pad/coach_calls_fake_transport_once")
			screen.call("activate", "coach-analyze")
			audit.check_eq(poster.calls.size(), 1, "pad/loading_cannot_duplicate_request")
	audit.check_eq(_router.active_id(), "menu", "pad/menu_routes_home")


func _payload(extra: Dictionary = {}) -> Dictionary:
	var payload := {
		"result": {
			"score": "11-7",
			"won": true,
			"pointsToWin": 11,
			"player": 11,
			"ai": 7,
			"stats": {
				"pointsWon": {"player": 11, "ai": 7},
				"aces": {"player": 2, "ai": 1},
				"winners": {"player": 5, "ai": 3},
				"errors": {"player": 4, "ai": 6},
				"doubleFaults": {"player": 3, "ai": 1},
				"smashWinners": {"player": 1, "ai": 0},
				"rallyCount": 9,
				"totalRallyHits": 32,
				"longestRally": 7,
			},
		},
		"mode": "quick",
		"arena_id": String((Config.arena() as Dictionary).get("id", "")),
		"season": 1,
		"match": 1,
		"outcome": "",
		"tournament": {},
		"continue_pending": false,
	}
	for key in extra.keys():
		payload[key] = extra[key]
	return payload


## Mounts the result screen and installs a transport the audit controls.
func _mount(payload: Dictionary) -> Array:
	_router.go_to("result", payload)
	for _i in SETTLE_FRAMES:
		await process_frame
	var screen: Node = _router.active_screen()
	var panel: Node = screen.call("coach_panel")
	var poster := FakePoster.new()
	panel.call("set_poster", poster)
	return [screen, panel, poster]


func _reply(offered: Array, choice: String, confidence: float) -> Dictionary:
	var rest := (1.0 - 0.8) / float(maxi(offered.size() - 1, 1))
	var probabilities := {}
	for id in offered:
		probabilities[String(id)] = 0.8 if String(id) == choice else rest
	return {
		"status": "ok",
		"body": {"type": "choice", "choice": choice, "confidence": confidence, "probabilities": probabilities},
	}


func _offered(panel: Node) -> Array:
	var snapshot: Dictionary = panel.call("client").call("snapshot")
	return snapshot.get("candidates", [])


# ---------------------------------------------------------------------------
# 1. Mounted, waiting
# ---------------------------------------------------------------------------

func _idle(audit: AuditBase) -> void:
	var mounted := await _mount(_payload())
	var screen: Node = mounted[0]
	var panel: Node = mounted[1]
	var poster: RefCounted = mounted[2]
	audit.check_eq(String(panel.call("state_id")), "idle", "coach/a_mounted_result_waits_for_a_press")
	audit.check_eq(int(panel.call("client").call("request_count")), 0, "coach/and_has_asked_the_bridge_nothing")
	audit.check_eq(poster.calls.size(), 0, "coach/and_has_touched_no_transport")
	audit.check_eq(String(panel.call("shown_title")), CoachText.t("coachTitle"), "coach/the_block_names_itself")
	audit.check_eq(String(panel.call("shown_disclosure")), CoachText.t("coachDisclosure"), "coach/the_disclosure_says_what_would_be_sent")
	audit.check_eq(String(panel.call("shown_analyze_label")), CoachText.t("coachAnalyze"), "coach/the_button_is_the_one_the_plan_names")
	audit.check_eq(bool(panel.call("analyze_visible")), true, "coach/the_button_is_offered")
	audit.check_eq(bool(panel.call("drill_visible")), false, "coach/no_exercise_button_before_an_answer")
	audit.check_eq(String(panel.call("shown_status")), "", "coach/nothing_is_claimed_before_the_press")
	audit.check_eq(String(panel.call("shown_exercise")), "", "coach/and_no_exercise_is_named_yet")
	# Every line and control is really in the tree: a label built but never parented draws
	# nothing while still answering its own text, so a state-only check would pass.
	var missing: Array = []
	for node_name in ["CoachTitle", "CoachDisclosure", "CoachAggregate", "CoachStatus", "CoachEvidence", "CoachExercise", "CoachAnalyzeButton", "CoachDrillButton"]:
		if panel.find_child(node_name, true, false) == null:
			missing.append(node_name)
	audit.check_eq(missing, [], "coach/every_line_and_control_is_in_the_tree")

	# A capture state renders the same block over the zeroed fixture: nothing measured,
	# nothing asked.
	screen.call("apply_capture_state", "default")
	audit.check_eq(int(panel.call("client").call("request_count")), 0, "coach/a_capture_state_asks_nothing")
	audit.check_eq(String(panel.call("state_id")), "insufficient", "coach/a_zeroed_capture_has_nothing_to_advise_on")
	audit.check_eq(String(panel.call("shown_status")), CoachText.t("coachInsufficient"), "coach/and_says_so")
	audit.check_eq(bool(panel.call("analyze_visible")), false, "coach/with_no_button_to_press")


# ---------------------------------------------------------------------------
# 2. The press, the advice, and the route to an exercise that exists
# ---------------------------------------------------------------------------

func _advice(audit: AuditBase) -> void:
	var mounted := await _mount(_payload())
	var panel: Node = mounted[1]
	var poster: RefCounted = mounted[2]
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 1, "coach/the_press_asked_once")
	audit.check_eq(int(panel.call("client").call("request_count")), 1, "coach/and_counted_one_request")
	audit.check_eq(String(panel.call("state_id")), "loading", "coach/and_shows_that_it_is_reading")
	audit.check_eq(String(panel.call("shown_status")), CoachText.t("coachLoading"), "coach/the_reading_line_is_the_localized_one")
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 1, "coach/a_second_press_while_reading_asks_nothing")

	var offered := _offered(panel)
	audit.report("advice fixture: offered %s" % str(offered))
	audit.check_true(offered.has(SERVE_FOCUS), "coach/the_fixture_offers_the_serve_focus")
	poster.deliver(0, _reply(offered, SERVE_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "advice", "coach/a_confident_answer_becomes_advice")
	audit.check_true(String(panel.call("shown_exercise")).contains(CoachText.t("coachAdviceServe", {"doubleFaults": 3, "aces": 2})), "coach/the_sentence_quotes_the_measured_serve_numbers")
	audit.check_true(String(panel.call("shown_exercise")).contains(UiStrings.t("drill_serve_name")), "coach/the_exercise_is_named_the_way_the_drill_screen_names_it")
	var evidence := {"errors": 4, "winners": 5, "aces": 2, "doubleFaults": 3, "rallies": 9, "averageRally": "3.6"}
	audit.check_eq(String(panel.call("shown_evidence")), CoachText.t("coachEvidence", evidence), "coach/the_evidence_line_is_the_matches_own_numbers")
	audit.check_eq((panel.find_child("CoachAggregate", true, false) as Control).visible, false, "coach/and_the_standing_note_steps_aside_so_it_is_not_said_twice")
	audit.check_eq(bool(panel.call("drill_visible")), true, "coach/and_the_exercise_button_is_offered")
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 1, "coach/a_press_after_a_reading_asks_nothing_new")
	audit.check_eq(String(panel.call("state_id")), "advice", "coach/and_keeps_the_reading_it_already_has")

	Config.pending_mode = PENDING_MODE
	Config.pending_exercise = ""
	var routed := String(panel.call("press_drill"))
	await process_frame
	audit.check_eq(routed, DRILL_TARGET, "coach/the_exercise_button_reports_the_recommended_drill")
	audit.check_eq(_router.active_id(), "drill", "coach/and_the_router_opened_the_existing_training_screen")
	var drill: Node = _router.active_screen()
	audit.check_eq(drill.has_method("exercise"), true, "coach/the_mounted_screen_is_a_drill_screen")
	audit.check_eq(String(drill.call("exercise")), DRILL_TARGET, "coach/with_the_recommended_exercise_already_selected")
	audit.check_eq(String(Config.pending_mode), PENDING_MODE, "coach/and_the_pending_run_was_not_overwritten")
	audit.check_eq(String(Config.pending_exercise), "", "coach/nor_the_pending_exercise")
	audit.report("route: %s -> %s, exercise %s, pending_mode %s" % [DRILL_TARGET, _router.active_id(), String(drill.call("exercise")), String(Config.pending_mode)])
	Config.pending_mode = ""

	# The serve-return ticket's own path: an opponent-ace-heavy match, a confident
	# `serve_return` answer, and the route into the FIFTH exercise — while
	# `pending_mode` / `pending_exercise` are still left exactly as they were.
	Config.pending_mode = PENDING_MODE
	Config.pending_exercise = ""
	_router.go_to("menu")
	var return_payload := _payload()
	var return_result: Dictionary = return_payload["result"]
	var return_stats: Dictionary = return_result["stats"]
	var return_aces: Dictionary = return_stats["aces"]
	return_aces["ai"] = 4
	var return_mounted := await _mount(return_payload)
	var return_panel: Node = return_mounted[1]
	var return_poster: RefCounted = return_mounted[2]
	return_panel.call("press_analyze")
	var return_offered := _offered(return_panel)
	audit.check_true(return_offered.has(RETURN_FOCUS), "coach/an_opponent_ace_heavy_match_offers_the_return_focus")
	return_poster.deliver(0, _reply(return_offered, RETURN_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(return_panel.call("state_id")), "advice", "coach/a_confident_return_answer_becomes_advice")
	var return_shown := String(return_panel.call("shown_exercise"))
	audit.check_true(return_shown.contains(CoachText.t("coachAdviceReturn", {"opponentAces": 4})), "coach/the_return_sentence_quotes_the_measured_opponent_aces")
	audit.check_true(return_shown.contains(DrillText.exercise_name(RETURN_TARGET)), "coach/and_names_the_return_exercise")
	var return_routed := String(return_panel.call("press_drill"))
	await process_frame
	audit.check_eq(return_routed, RETURN_TARGET, "coach/the_button_reports_the_return_exercise")
	audit.check_eq(_router.active_id(), "drill", "coach/and_opens_the_training_screen")
	var return_drill: Node = _router.active_screen()
	audit.check_eq(String(return_drill.call("exercise")), RETURN_TARGET, "coach/with_the_return_exercise_selected")
	audit.check_eq(String(Config.pending_mode), PENDING_MODE, "coach/and_the_pending_run_is_still_untouched")
	audit.check_eq(String(Config.pending_exercise), "", "coach/nor_the_pending_exercise")
	audit.report("return route: %s -> %s, exercise %s" % [RETURN_FOCUS, _router.active_id(), String(return_drill.call("exercise"))])
	Config.pending_mode = ""


# ---------------------------------------------------------------------------
# 3. A run that is one press from continuing
# ---------------------------------------------------------------------------

func _continuation(audit: AuditBase) -> void:
	# A career run waiting for its next match: the mode the mount would resume.
	Config.pending_mode = PENDING_MODE
	Config.pending_exercise = ""
	var mounted := await _mount(_payload({"continue_pending": true, "mode": "career"}))
	var panel: Node = mounted[1]
	var poster: RefCounted = mounted[2]
	panel.call("press_analyze")
	poster.deliver(0, _reply(_offered(panel), SERVE_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "advice", "coach/a_pending_run_still_gets_its_advice")
	var shown := String(panel.call("shown_exercise"))
	audit.check_true(shown.contains(UiStrings.t("drill_serve_name")), "coach/the_exercise_is_still_named")
	audit.check_true(shown.contains(CoachText.t("coachDrillBlocked")), "coach/and_the_block_says_where_the_training_opens_instead")
	audit.check_eq(bool(panel.call("drill_visible")), false, "coach/the_exercise_button_is_not_offered")
	var mounted_id := String(_router.active_id())
	var routed := String(panel.call("press_drill"))
	audit.check_eq(routed, "", "coach/a_press_with_nowhere_to_go_reports_no_route")
	audit.check_eq(_router.active_id(), mounted_id, "coach/and_nothing_moved")
	audit.check_eq(String(Config.pending_mode), PENDING_MODE, "coach/the_pending_run_is_left_untouched")
	Config.pending_mode = ""


# ---------------------------------------------------------------------------
# 4. The weak outcomes
# ---------------------------------------------------------------------------

func _states(audit: AuditBase) -> void:
	# An uncertain reading: the numbers, no exercise, and the block says so in its own words.
	var mounted := await _mount(_payload())
	var panel: Node = mounted[1]
	var poster: RefCounted = mounted[2]
	panel.call("press_analyze")
	poster.deliver(0, _reply(_offered(panel), SERVE_FOCUS, 0.3))
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "uncertain", "coach/an_answer_under_the_gate_is_uncertain")
	audit.check_eq(String(panel.call("shown_status")), CoachText.t("coachUncertain"), "coach/and_says_so")
	audit.check_eq(bool(panel.call("retryable")), false, "coach/an_uncertain_reading_is_not_retryable")
	audit.check_eq(String(panel.call("shown_evidence")), CoachText.t("coachEvidence", {"errors": 4, "winners": 5, "aces": 2, "doubleFaults": 3, "rallies": 9, "averageRally": "3.6"}), "coach/with_the_matches_numbers")
	audit.check_eq(bool(panel.call("drill_visible")), false, "coach/and_no_exercise")
	audit.check_eq(String(panel.call("shown_exercise")), "", "coach/and_no_advice_sentence")

	var cases := [
		{"name": "unreachable", "reply": {"status": "unreachable"}, "state": "unavailable", "status_id": "coachUnavailable"},
		{"name": "timeout", "reply": {"status": "timeout"}, "state": "unavailable", "status_id": "coachUnavailable"},
		{"name": "a_refused_answer", "reply": {"status": "invalid"}, "state": "invalid", "status_id": "coachInvalid"},
	]
	for entry in cases:
		var one := await _mount(_payload())
		var one_panel: Node = one[1]
		var one_poster: RefCounted = one[2]
		one_panel.call("press_analyze")
		one_poster.deliver(0, entry["reply"])
		await process_frame
		audit.check_eq(String(one_panel.call("state_id")), String(entry["state"]), "coach/%s_is_%s" % [String(entry["name"]), String(entry["state"])])
		audit.check_eq(String(one_panel.call("shown_status")), CoachText.t(String(entry["status_id"])), "coach/%s_says_so" % String(entry["name"]))
		audit.check_eq(bool(one_panel.call("drill_visible")), false, "coach/%s_offers_no_exercise" % String(entry["name"]))
		audit.check_eq(String(one_panel.call("shown_exercise")), "", "coach/%s_claims_no_analysis" % String(entry["name"]))
		audit.check_eq(bool(one_panel.call("analyze_visible")), true, "coach/%s_can_be_tried_again" % String(entry["name"]))
		audit.check_eq(bool(one_panel.call("retryable")), true, "coach/%s_is_a_retryable_state" % String(entry["name"]))

	# A match with nothing measured: no button, no request, and the disclosure is not the
	# thing on screen — the reason is.
	var empty := _payload()
	(empty["result"] as Dictionary)["stats"] = {}
	var bare := await _mount(empty)
	var bare_panel: Node = bare[1]
	var bare_poster: RefCounted = bare[2]
	audit.check_eq(String(bare_panel.call("state_id")), "insufficient", "coach/an_unmeasured_match_is_insufficient")
	audit.check_eq(String(bare_panel.call("shown_status")), CoachText.t("coachInsufficient"), "coach/and_its_line_is_the_insufficient_one")
	audit.check_eq(bool(bare_panel.call("analyze_visible")), false, "coach/with_no_button")
	audit.check_eq(bool(bare_panel.call("retryable")), false, "coach/a_measured_refusal_is_not_retryable")
	audit.check_eq(bare_poster.calls.size(), 0, "coach/and_nothing_sent")
	audit.check_eq(int(bare_panel.call("client").call("request_count")), 0, "coach/not_even_one_request")


# ---------------------------------------------------------------------------
# 5. Leaving the screen
# ---------------------------------------------------------------------------

## The reading is kept, the failure is retryable, and a late reply to a match the player
## has left cannot paint.
func _reuse_and_retry(audit: AuditBase) -> void:
	var mounted := await _mount(_payload())
	var screen: Node = mounted[0]
	var panel: Node = mounted[1]
	var poster: RefCounted = mounted[2]
	var client: Node = panel.call("client")

	# A failure says nothing about the match: the button offers a retry, and the failed
	# reading is cleared before the new request starts.
	panel.call("press_analyze")
	poster.deliver(0, {"status": "unreachable"})
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "unavailable", "coach/an_unreachable_bridge_is_unavailable")
	audit.check_eq(String(panel.call("shown_analyze_label")), CoachText.t("coachRetry"), "coach/and_offers_a_retry")
	audit.check_eq(bool(panel.call("retryable")), true, "coach/the_block_calls_that_state_retryable")
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 2, "coach/the_retry_really_asks_again")
	audit.check_eq(String(panel.call("state_id")), "loading", "coach/and_the_failed_reading_is_cleared_while_it_asks")
	audit.check_eq(String(panel.call("shown_status")), CoachText.t("coachLoading"), "coach/with_the_reading_line")
	audit.check_eq(String(panel.call("shown_exercise")), "", "coach/and_nothing_of_the_failure_is_left_on_screen")
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 2, "coach/a_double_click_while_reading_asks_nothing_more")
	var offered := _offered(panel)
	poster.deliver(1, _reply(offered, SERVE_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "advice", "coach/the_retry_succeeds")
	audit.check_eq(bool(panel.call("retryable")), false, "coach/a_reading_is_not_retryable")
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 2, "coach/a_reading_is_not_re_asked")

	# Re-rendering the SAME match keeps the reading it already has.
	screen.call("enter", _payload())
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "advice", "coach/a_rerender_of_the_same_match_keeps_the_reading")
	audit.check_eq(poster.calls.size(), 2, "coach/and_asks_nothing_new")
	audit.check_eq(int(client.call("request_count")), 2, "coach/with_one_request_per_ask_for_the_whole_session")

	# Re-rendering the same match while a request is in flight keeps the request.
	var pending := await _mount(_payload())
	var pending_panel: Node = pending[1]
	var pending_poster: RefCounted = pending[2]
	pending_panel.call("press_analyze")
	audit.check_eq(pending_poster.calls.size(), 1, "coach/a_request_is_in_flight")
	(pending[0] as Node).call("enter", _payload())
	await process_frame
	audit.check_eq(pending_poster.calls.size(), 1, "coach/a_rerender_while_reading_does_not_ask_again")
	audit.check_eq(bool(pending_panel.call("client").call("pending")), true, "coach/and_the_request_is_still_in_flight")
	audit.check_eq(String(pending_panel.call("state_id")), "loading", "coach/and_the_block_still_shows_that_it_is_reading")
	pending_poster.deliver(0, _reply(_offered(pending_panel), SERVE_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(pending_panel.call("state_id")), "advice", "coach/and_its_reply_still_lands")

	# A DIFFERENT match drops both: the request is cancelled and its late reply paints nothing.
	var changed := await _mount(_payload())
	var changed_screen: Node = changed[0]
	var changed_panel: Node = changed[1]
	var changed_poster: RefCounted = changed[2]
	changed_panel.call("press_analyze")
	var stale_offered := _offered(changed_panel)
	audit.check_eq(changed_poster.calls.size(), 1, "coach/a_request_is_in_flight_for_the_first_match")
	changed_screen.call("enter", _other_payload())
	await process_frame
	audit.check_eq(changed_poster.cancelled, 1, "coach/a_changed_match_cancels_the_request_it_left")
	audit.check_eq(String(changed_panel.call("state_id")), "idle", "coach/and_the_block_starts_over_for_the_new_match")
	changed_poster.deliver(0, _reply(stale_offered, SERVE_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(changed_panel.call("state_id")), "idle", "coach/a_late_reply_to_the_old_match_paints_nothing")
	audit.check_eq(String(changed_panel.call("shown_exercise")), "", "coach/and_no_advice_appears")
	audit.check_eq(int(changed_panel.call("client").call("request_count")), 1, "coach/and_the_new_match_has_asked_nothing_yet")


## The same fixture with a different score and different counters: a DIFFERENT match, for the
## rule that a changed result must not inherit the old one's reading.
func _other_payload() -> Dictionary:
	var payload := _payload()
	var result: Dictionary = payload["result"]
	result["score"] = "11-3"
	result["ai"] = 3
	result["stats"] = {
		"pointsWon": {"player": 11, "ai": 3},
		"aces": {"player": 1, "ai": 0},
		"winners": {"player": 6, "ai": 1},
		"errors": {"player": 2, "ai": 5},
		"doubleFaults": {"player": 0, "ai": 2},
		"smashWinners": {"player": 2, "ai": 0},
		"rallyCount": 8,
		"totalRallyHits": 24,
		"longestRally": 6,
	}
	return payload

func _exit(audit: AuditBase) -> void:
	var mounted := await _mount(_payload())
	var screen: Node = mounted[0]
	var panel: Node = mounted[1]
	var poster: RefCounted = mounted[2]
	panel.call("press_analyze")
	audit.check_eq(poster.calls.size(), 1, "coach/a_reading_is_in_flight_before_the_exit")
	screen.call("exit")
	audit.check_eq(poster.cancelled, 1, "coach/leaving_the_screen_cancelled_the_transport")
	audit.check_eq(bool(panel.call("client").call("pending")), false, "coach/and_stopped_waiting")
	var offered := _offered(panel)
	poster.deliver(0, _reply(offered, SERVE_FOCUS, 0.8))
	await process_frame
	audit.check_eq(String(panel.call("state_id")), "idle", "coach/a_reply_after_the_exit_paints_nothing")
	audit.check_eq(String(panel.call("shown_exercise")), "", "coach/and_no_advice_appears")
	audit.check_eq(panel.call("record").is_empty(), true, "coach/and_no_record_is_kept")

	# Entering the screen again is a fresh block, asking for nothing by itself.
	var again := await _mount(_payload())
	var again_panel: Node = again[1]
	var again_poster: RefCounted = again[2]
	audit.check_eq(String(again_panel.call("state_id")), "idle", "coach/a_re_entry_starts_from_the_idle_state")
	audit.check_eq(int(again_panel.call("client").call("request_count")), 0, "coach/and_asks_nothing_on_arrival")
	audit.check_eq(again_poster.calls.size(), 0, "coach/and_touches_no_transport")


# ---------------------------------------------------------------------------
# 6. The screen's own language
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var language_at_start := Locale.current_lang()
	var other := "en" if language_at_start != "en" else "it"
	var mounted := await _mount(_payload())
	var panel: Node = mounted[1]
	audit.check_eq(String(panel.call("shown_title")), CoachText.t("coachTitle", {}, language_at_start), "coach/the_block_speaks_the_screens_language")
	Locale.set_lang(other)
	var remounted := await _mount(_payload())
	var other_panel: Node = remounted[1]
	audit.check_eq(String(other_panel.call("shown_title")), CoachText.t("coachTitle", {}, other), "coach/a_flip_moves_the_blocks_title")
	audit.check_eq(String(other_panel.call("shown_disclosure")), CoachText.t("coachDisclosure", {}, other), "coach/and_its_disclosure")
	audit.check_eq(String(other_panel.call("shown_analyze_label")), CoachText.t("coachAnalyze", {}, other), "coach/and_its_button")
	audit.check_ne(CoachText.t("coachTitle", {}, other), CoachText.t("coachTitle", {}, language_at_start), "coach/and_the_two_tables_really_differ")
	Locale.set_lang(language_at_start)
	audit.report("coach strings: %d ids in each table, flipped %s -> %s and back" % [CoachText.ids("it").size(), language_at_start, other])
