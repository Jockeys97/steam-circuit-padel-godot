## return_drill_audit.gd — the Godot-only `return` exercise's own contract.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/modes/return_drill_audit.gd
##
## WHAT THIS EXERCISE IS. `return` is the FIFTH drill (`godot/src/modes/drill_extras.gd`),
## added by the Jev serve-return ticket (`docs/agent-work/jev-return/PLAN.md`) and NOT
## present in the frozen browser reference: the OPPONENTS serve and the attempt is the
## human side's return. `tests/modes/drill_audit.gd` still audits the reference's own four
## rows against `Tables.drill_exercises()`; this audit owns the extension.
##
## WHAT IT GATES, in the order the acceptance criteria ask for it:
##   1. THE EXERCISE IS REAL AND REACHABLE: it is in the catalog, `drill_exercise("return")`
##      resolves it, an unknown id still falls back to the reference's first, and the frozen
##      document was not touched (its four rows and its source sha256 are unchanged).
##   2. THE OPPONENTS SERVE. Starting a round puts the ENGINE in the opponent's own serve
##      (`serveSide == "ai"`, `state.serving`, the reception formation on the human side) and
##      the serve arrives as a real engine shot — the exercise integrates no ball of its own.
##   3. A LEGAL RETURN SUCCEEDS, read off the ENGINE: the human side contacts the serve, the
##      return clears the net, and the ball bounces inside the opponents' court. The audit
##      compares the closed attempt's own verdict to the engine's ball marks, so a pass is
##      the engine's measurement and not the drill's opinion.
##   4. A NON-RETURN FAILS: the same scripted player, with no swing at all, closes the
##      attempt as a failure with a measured diagnosis. Across seeds the audit runs both
##      directions, so the exercise has been observed to succeed and to fail.
##   4b. THE OTHER LEGAL ENDING (root integration probe, 2026-09-24): a return the OPPONENT
##      plays back — a volley before it bounces — is a good return, not a net fault. The
##      seeded trajectory below (seed 1234, a drive) contacts the serve and is then volleyed
##      by the opponents, and this audit requires it to close as a SUCCESS with the distinct
##      diagnosis `drillWhyReturnPlayed` and with NO depth bonus: the deep tier is only ever
##      read off a measured landing.
##   5. THE METRICS ARE USEFUL AND THE DIAGNOSES RESOLVE in both languages — including the
##      ones this extension added (`drillWhyReturnIn`, `drillWhyAceAgainst`, …), which live
##      in `godot/src/modes/drill_strings.json` and are resolved by `drill_text.gd`.
##   6. THE RECORD IS INDEPENDENT: the exercise's own persisted best is written through
##      `ModesSave` and does not touch another exercise's record.
##   7. DETERMINISTIC RESET: the same seed and the same scripted inputs produce the same
##      outcome twice, and `reset()` clears the attempt's own marks.
##
## The scripted player is the drill audits' own shape (`_player_input`, the reference's
## `vicina` rule) with the paddle kept under the flying ball and the swing aimed deep: the
## exercise must be winnable by a human who does the right thing, and this is what doing the
## right thing looks like as input.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const DrillExtras := preload("res://src/modes/drill_extras.gd")
const Sim := preload("res://src/sim/sim.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const DrillTarget := preload("res://src/modes/drill_target.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Locale := preload("res://src/locale/locale.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

const STEP := 1.0 / 120.0
const ATTEMPT_FRAMES := 2400
const TEMP_DIR := "user://jev-return-drill-audit"
## The same seed the Jev ticket's own live sample uses, plus two more: the audit is about
## the exercise's rules, and three draws show both endings without pretending to sweep.
const SEEDS := [1234, 4242, 7]


func _initialize() -> void:
	_wipe()
	var audit := AuditBase.new("return_drill")
	_catalog(audit)
	_opponent_serve(audit)
	_grading(audit)
	_metrics(audit)
	_records(audit)
	_determinism(audit)
	_wipe()
	quit(audit.finish())


# ---------------------------------------------------------------------------
# 1. The exercise, and the frozen document it is not in
# ---------------------------------------------------------------------------

func _catalog(audit: AuditBase) -> void:
	var frozen_rows: Array = Tables.drill_exercises()
	audit.check_eq(frozen_rows.size(), 4, "return/the_frozen_reference_table_still_has_its_own_four")
	var frozen_ids: Array = []
	for row in frozen_rows:
		frozen_ids.append(String((row as Dictionary).get("id", "")))
	audit.check_eq(frozen_ids.has("return"), false, "return/the_frozen_table_does_not_carry_it")
	# `the_generated_document_is_untouched`: the document records the sha256 of the two
	# reference files it was generated from, and the honest check is against the SOURCE,
	# not against a constant this file happens to remember. A hardcoded digest went stale
	# when `js/drill.js` moved on (the recorded one is correct, the constant was not), which
	# is exactly the failure mode a relationship check cannot have.
	for source in ["js/drill.js", "js/data.js"]:
		var recorded := String(Tables.source_sha256().get(String(source), ""))
		var actual := _source_sha256(String(source))
		audit.check_eq(recorded, actual, "return/the_document_records_the_real_sha256_of_%s" % String(source).replace("/", "_"))
		audit.check_true(recorded != "", "return/the_document_records_a_digest_for_%s" % String(source).replace("/", "_"))

	var catalog: Array = Tables.drill_catalog()
	# The training overhaul's three challenges are catalog rows of this same Godot-only
	# family (`drill_extras.gd`), so the catalog this build OFFERS is the frozen four plus
	# four extension rows — `Tables.drill_exercises()` above is still the reference's four.
	audit.check_eq(catalog.size(), 8, "return/the_catalog_offers_eight_exercises")
	var catalog_ids := Tables.drill_catalog_ids()
	audit.check_true(catalog_ids.has(DrillExtras.RETURN_ID), "return/the_extension_is_one_of_them")
	for challenge in [DrillExtras.GLASS_RECOVERY_ID, DrillExtras.NET_PLAY_ID, DrillExtras.DOUBLES_TACTICS_ID]:
		audit.check_true(catalog_ids.has(String(challenge)), "return/%s_is_offered" % String(challenge))
		audit.check_eq(bool(DrillExtras.is_extra(String(challenge))), true, "return/%s_is_a_godot_only_row" % String(challenge))
	audit.check_eq(String(Tables.drill_exercise("return").get("id", "")), "return", "return/the_id_resolves_to_the_exercise")
	audit.check_eq(String(Tables.drill_exercise("inesistente").get("id", "")), String(frozen_ids[0]), "return/an_unknown_id_still_falls_back_to_the_reference_first")
	audit.check_eq(bool(DrillExtras.is_extra("return")), true, "return/it_is_marked_as_the_godot_only_one")
	audit.check_eq(bool(DrillExtras.is_extra("precision")), false, "return/the_reference_rows_are_not")
	audit.report("catalog=%s (frozen rows %s), source sha256 intact" % [str(catalog_ids), str(frozen_ids)])


# ---------------------------------------------------------------------------
# 2. The opponents serve
# ---------------------------------------------------------------------------

func _opponent_serve(audit: AuditBase) -> void:
	var session := seeded("return", 1234)
	audit.check_eq(String(session.exercise.get("feed", "")), "serve", "return/the_exercise_feeds_a_serve")
	audit.check_eq(bool(session.exercise.get("opponentServe", false)), true, "return/and_declares_the_opponent_as_the_server")
	session.step(STEP, input({"hit": true}))
	audit.check_eq(session.phase, "live", "return/the_first_command_starts_the_attempt")
	audit.check_eq(String(session.state.serveSide), "ai", "return/the_engine_is_in_the_opponents_serve")
	audit.check_true(bool(session.state.serving), "return/the_serve_is_prepared_not_invented")
	# The reception formation is the engine's own `/prepareServe` for an opponent serve:
	# both human paddles at the back, the service receiver locked. The drill places no ball.
	audit.check_gt(float(session.state.player.y), float(Frozen.court()["netY"]), "return/the_human_side_is_on_its_own_half")
	var frames := 0
	var served := false
	while frames < 400 and not served:
		session.step(STEP, input({}))
		served = not bool(session.state.serving) and bool(session.state.ball.served)
		frames += 1
	audit.check_true(served, "return/the_opponent_put_the_ball_in_play_with_the_engines_own_serve")
	audit.check_true(bool(session.state.ball.serveInFlight) or float(session.state.ball.vy) != 0.0, "return/the_serve_is_a_real_engine_shot")
	audit.report("opponent serve: side=%s served_after=%d frames" % [String(session.state.serveSide), frames])


# ---------------------------------------------------------------------------
# 3. A legal return succeeds; 4. a non-return fails
# ---------------------------------------------------------------------------

func _grading(audit: AuditBase) -> void:
	var successes := 0
	var failures := 0
	for seed_value in SEEDS:
		var returning := _play(int(seed_value), true)
		var engine_verdict := String(returning["session"].return_ball_diagnosis())
		audit.check_true(engine_verdict != "none", "return/seed_%d/the_human_side_reached_the_serve" % seed_value)
		audit.check_true(bool(returning["session"].return_cleared), "return/seed_%d/the_return_cleared_the_net" % seed_value)
		var diagnosis := String(returning["session"].diagnosis)
		var landed := diagnosis == "drillWhyReturnIn" or diagnosis == "drillWhyReturnDeep"
		var played_back := diagnosis == "drillWhyReturnPlayed"
		if landed:
			successes += 1
			audit.check_eq(int(returning["session"].hits), 1, "return/seed_%d/a_return_that_landed_in_the_opponent_court_is_a_hit" % seed_value)
			audit.check_gt(int(returning["session"].points), 0, "return/seed_%d/and_scores" % seed_value)
			# The landing the verdict was read from is inside the opponents' COURT: not
			# merely past the net (the back wall is a miss, the engine says so).
			audit.check_eq(DrillTarget.in_return_zone(float(returning["landing"]["y"])), true, "return/seed_%d/and_the_graded_landing_is_inside_the_opponent_court" % seed_value)
			audit.check_ge(float(returning["session"].squash), 0.0, "return/seed_%d/the_execution_scale_is_measured" % seed_value)
			audit.check_le(float(returning["session"].squash), 1.0, "return/seed_%d/and_stays_in_scale" % seed_value)
		elif played_back:
			# The opponents played the return before it bounced: a legal, playable return.
			# It scores, its verdict is its own, and — the point of the split — it carries
			# NO depth bonus, because no landing was measured to read one from.
			successes += 1
			var grade: Variant = returning["session"].grade if returning["session"].grade != null else "good"
			audit.check_eq(int(returning["session"].hits), 1, "return/seed_%d/a_return_the_opponent_played_is_a_hit" % seed_value)
			audit.check_eq(int(returning["session"].points), DrillScoring.attempt_points(DrillSession.RETURN_PLAYED_TIER, grade), "return/seed_%d/and_pays_the_flat_played_back_tier_with_no_depth_bonus" % seed_value)
			audit.check_eq(returning["session"].landing, null, "return/seed_%d/and_measured_no_landing_to_bonus" % seed_value)
			audit.check_true(DrillText.has("drillWhyReturnPlayed", "it") and DrillText.has("drillWhyReturnPlayed", "en"), "return/seed_%d/the_opponent_volley_diagnosis_is_its_own_and_localized" % seed_value)
		else:
			audit.check_eq(int(returning["session"].hits), 0, "return/seed_%d/a_return_that_did_not_land_is_not_a_hit" % seed_value)

		var passive := _play(int(seed_value), false)
		failures += 1
		audit.check_eq(String(passive["session"].diagnosis) == "drillWhyReturnIn", false, "return/seed_%d/no_swing_never_grades_a_return_in" % seed_value)
		audit.check_eq(int(passive["session"].hits), 0, "return/seed_%d/no_swing_is_never_a_hit" % seed_value)
		audit.check_eq(int(passive["session"].attempts), 1, "return/seed_%d/a_non_return_still_closes_exactly_one_attempt" % seed_value)
		audit.check_eq(String(passive["session"].return_ball_diagnosis()), "none", "return/seed_%d/and_the_human_side_never_touched_the_serve" % seed_value)
		audit.check_true(DrillText.has(String(passive["session"].diagnosis), "it"), "return/seed_%d/the_failure_diagnosis_resolves_in_italian" % seed_value)
		audit.check_true(DrillText.has(String(passive["session"].diagnosis), "en"), "return/seed_%d/and_in_english" % seed_value)
	audit.check_gt(successes, 0, "return/at_least_one_seed_graded_a_real_return_as_success")
	audit.check_gt(failures, 0, "return/and_at_least_one_attempt_graded_a_non_return_as_failure")

	# THE DRIVE REGRESSION (root probe, `/tmp/training-return-review.5C0Y3C/probe.gd`, drive
	# variant, seed 1234): the human's controlled drive contacts the serve and the opponents
	# volley it AT y < netY on the very next contact — in the same tick the ball crossed the
	# net, so the engine's own `crossedNet` flag was cleared by that volley before the drill
	# could read it. Requiring a previously latched `crossedNet` made this legal return a
	# "net" miss; the objective now accepts the legal opponent contact in the opponents' half
	# and raises `return_cleared` itself. This is the trajectory that regression exists for.
	var drive := _play_drive(1234)
	audit.check_eq(String(drive["session"].diagnosis), "drillWhyReturnPlayed", "return/drive_seed_1234/the_opponent_volley_of_a_legal_drive_is_a_success")
	audit.check_eq(bool(drive["session"].return_cleared), true, "return/drive_seed_1234/the_accepted_volley_marks_the_return_as_cleared")
	audit.check_eq(int(drive["session"].hits), 1, "return/drive_seed_1234/and_it_is_a_hit")
	audit.check_gt(int(drive["session"].points), 0, "return/drive_seed_1234/and_it_scores")
	audit.check_eq(drive["session"].landing, null, "return/drive_seed_1234/and_no_landing_was_measured_to_bonus")
	audit.check_true(drive["contacted_frame"] > 0 and drive["opponent_frame"] > drive["contacted_frame"], "return/drive_seed_1234/the_engine_saw_the_human_contact_then_the_opponent_contact")
	audit.report("drive regression: contact frame %d, opponent contact frame %d, verdict %s" % [
		int(drive["contacted_frame"]), int(drive["opponent_frame"]), String(drive["session"].diagnosis)])

	# Boundary outcomes are driven through the drill's grading seam with engine-owned
	# marks. A contacted ball that closes before crossing is a net failure; a contacted
	# ball that crossed but bounced beyond the back wall is an out failure. These fixtures
	# isolate the verdict after the live scenarios above have already proved the real serve
	# and a playable return end to end.
	var net := seeded("return", 99)
	net.start_round()
	net.return_contact = true
	net.state.lastHitterSide = "player"
	net.state.ball.crossedNet = false
	net.state.ball.bounces = {"player": 0, "ai": 0}
	net.state.result = {"winner": "ai"}
	net.call("_step_return", int(net.state.stats["aces"]["ai"]), int(net.state.rallyHits), float(net.state.ball.z), float(net.state.ball.vz))
	audit.check_eq(int(net.hits), 0, "return/a_net_return_is_not_a_hit")
	audit.check_eq(String(net.diagnosis), "drillWhyReturnNet", "return/a_net_return_is_named_from_its_measured_outcome")

	var out := seeded("return", 100)
	out.start_round()
	out.return_contact = true
	out.state.lastHitterSide = "player"
	out.state.ball.crossedNet = true
	out.state.ball.bounces = {"player": 0, "ai": 1}
	out.state.ball.y = float(Frozen.court()["top"]) - 1.0
	out.state.ball.z = 0.0
	out.call("_step_return", int(out.state.stats["aces"]["ai"]), int(out.state.rallyHits), 1.0, float(out.state.ball.vz))
	audit.check_eq(int(out.hits), 0, "return/an_out_return_is_not_a_hit")
	audit.check_eq(String(out.diagnosis), "msgOut", "return/an_out_return_uses_the_engines_existing_out_message")
	audit.report("grading: %d of %d scripted attempts returned in; %d passive attempts failed" % [successes, SEEDS.size(), failures])


# ---------------------------------------------------------------------------
# 5. The metrics, and every diagnosis this exercise can emit
# ---------------------------------------------------------------------------

func _metrics(audit: AuditBase) -> void:
	var session := seeded("return", 1234)
	session.step(STEP, input({"hit": true}))
	var metrics: Array = DrillScoring.metrics(session)
	audit.check_eq(metrics.size(), 4, "return/the_hud_wants_four_metrics")
	var keys: Array = []
	for metric in metrics:
		keys.append(String((metric as Dictionary).get("key", "")))
		audit.check_true((metric as Dictionary).get("value") != null, "return/return/%s_is_populated" % String((metric as Dictionary).get("key", "")))
	audit.check_eq(keys, ["drillScore", "drillBest", "drillIn", "drillStreak"], "return/the_metric_keys_are_the_references_own")
	var unresolved: Array = []
	for key in keys:
		for lang in ["it", "en"]:
			if not Locale.is_resolvable(String(key), String(lang)):
				unresolved.append("%s:%s" % [String(key), String(lang)])
	audit.check_eq(unresolved, [], "return/every_metric_label_resolves_in_both_languages")

	# Every diagnosis the branch can close an attempt with, resolved from the extension's
	# own table in both languages. A missing one would reach the HUD as the id itself.
	var diagnoses := [
		"drillWhyReturnIn", "drillWhyReturnDeep", "drillWhyAceAgainst", "drillWhyNoReturn",
		"drillWhyReturnNet", "drillWhyReturnOut", "drillWhyReturnLost",
	]
	var broken: Array = []
	for id in diagnoses:
		for lang in ["it", "en"]:
			if not DrillText.has(String(id), String(lang)):
				broken.append("%s:%s" % [String(id), String(lang)])
	audit.check_eq(broken, [], "return/every_return_diagnosis_resolves_in_both_languages")
	# And the extension never shadows the reference's own table: the frozen ids still come
	# from the generated locale data, and an id neither table knows still answers itself.
	audit.check_eq(DrillText.resolve("drill_precision_name", "it"), Locale.t("drill_precision_name", {}, "it"), "return/the_reference_names_are_still_the_generated_ones")
	audit.check_eq(DrillText.resolve("drill_nonexistent_name", "it"), "drill_nonexistent_name", "return/an_id_no_table_knows_comes_back_as_the_id")
	audit.check_eq(DrillText.resolve("drill_return_name", "de"), DrillText.resolve("drill_return_name", "it"), "return/an_unknown_locale_is_answered_by_the_fallback")
	audit.report("metrics=%s" % str(metrics))


# ---------------------------------------------------------------------------
# 6. The record is the exercise's own
# ---------------------------------------------------------------------------

func _records(audit: AuditBase) -> void:
	var store := SaveStore.new(TEMP_DIR)
	audit.check_eq(ModesSave.drill_best(store, "return"), 0, "return/no_record_before_the_first_run")
	ModesSave.save_drill_score(store, "return", 9)
	audit.check_eq(ModesSave.drill_best(store, "return"), 9, "return/the_return_record_is_written")
	audit.check_eq(ModesSave.drill_best(store, "serve"), 0, "return/and_the_serve_record_is_untouched")
	audit.check_eq(ModesSave.load_drill_records(store).size(), 1, "return/exactly_one_exercise_has_a_record")
	# `saveDrillRecord` is improvement-only (`js/ui.js:219-230`): a lower score keeps the
	# record, a higher one replaces it.
	var lower: Dictionary = ModesSave.save_drill_score(store, "return", 4)
	audit.check_eq(int(lower.get("skipped", 0)), 1, "return/a_lower_score_is_not_written")
	audit.check_eq(ModesSave.drill_best(store, "return"), 9, "return/and_the_record_stands")
	var higher: Dictionary = ModesSave.save_drill_score(store, "return", 12)
	audit.check_eq(bool(higher.get("written", false)), true, "return/an_improvement_is_written")
	audit.check_eq(ModesSave.drill_best(store, "return"), 12, "return/and_reads_back")
	var records: Dictionary = ModesSave.load_drill_records(store)
	audit.check_eq(int(records.get("return", 0)), 12, "return/the_store_carries_only_the_returns_own_record")
	audit.check_eq(records.has("serve"), false, "return/and_nothing_was_written_for_the_reference_exercises")


# ---------------------------------------------------------------------------
# 7. Determinism and the reset
# ---------------------------------------------------------------------------

func _determinism(audit: AuditBase) -> void:
	var first := _play(4242, true)
	var second := _play(4242, true)
	audit.check_eq(String(first["session"].diagnosis), String(second["session"].diagnosis), "return/same_seed_same_diagnosis")
	audit.check_eq(int(first["session"].points), int(second["session"].points), "return/same_seed_same_points")
	audit.check_eq(int(first["session"].hits), int(second["session"].hits), "return/same_seed_same_hits")
	audit.check_eq(int(first["frames"]), int(second["frames"]), "return/same_seed_same_attempt_length")

	# `reset()` (`js/drill.js:234-242`) clears the attempt's own marks and re-places the
	# teams; the extension's two marks go with it.
	var session: RefCounted = first["session"]
	session.return_contact = true
	session.return_cleared = true
	session.landing = {"x": 1.0, "y": 2.0}
	session.reset()
	audit.check_eq(session.return_contact, false, "return/reset_clears_the_contact_mark")
	audit.check_eq(session.return_cleared, false, "return/reset_clears_the_cleared_net_mark")
	audit.check_eq(session.landing, null, "return/reset_clears_the_landing")
	audit.check_eq(session.phase, "ready", "return/reset_returns_to_the_ready_phase")


# ---------------------------------------------------------------------------
# Scenario builders
# ---------------------------------------------------------------------------

## One scripted attempt. `swing` false is the honest non-return: the same seed, the same
## serve, and no swing at all.
func _play(seed_value: int, swing: bool) -> Dictionary:
	var session := seeded("return", seed_value)
	session.step(STEP, input({"hit": true}))
	var frames := 0
	while frames < ATTEMPT_FRAMES and session.phase != "result":
		session.step(STEP, _player_input(session) if swing else input({}))
		frames += 1
	return {"session": session, "frames": frames, "landing": session.landing if session.landing is Dictionary else {}}


## The root probe's own drive trajectory, frame by frame: the paddle is kept under the ball,
## `aimY` is 0.6, the variant is a drive, nothing is charged, and the human swings ONCE (the
## probe's `not session.return_contact` gate). It reports the frame of the human's contact and
## the frame of the opponents' contact, so the regression can assert the ORDER the engine saw
## rather than only the verdict.
func _play_drive(seed_value: int) -> Dictionary:
	var session := seeded("return", seed_value)
	session.step(STEP, input({"hit": true}))
	var contact_frame := -1
	var opponent_frame := -1
	var frames := 0
	while frames < ATTEMPT_FRAMES and session.phase not in ["result", "summary"]:
		var s = session.state
		var pad = s.active_player()
		var ball = s.ball
		var over := {
			"moveX": clampf((float(ball.x) - float(pad.x)) / 30.0, -1.0, 1.0) if absf(float(ball.y) - float(pad.y)) > 80.0 else 0.0,
			"moveY": clampf((float(ball.y) - float(pad.y)) / 60.0, -1.0, 1.0) if absf(float(ball.y) - float(pad.y)) > 45.0 else 0.0,
			"aimY": 0.6,
			"shotVariant": "drive",
			"charging": false,
			"hit": Sim.can_hit(pad, ball) and absf(float(ball.y) - float(pad.y)) < 45.0 and not session.return_contact,
		}
		var before := int(s.rallyHits)
		session.step(STEP, input(over))
		if int(s.rallyHits) != before:
			if String(s.lastHitterSide) == "player" and contact_frame < 0:
				contact_frame = frames
			elif String(s.lastHitterSide) == "ai" and opponent_frame < 0:
				opponent_frame = frames
		frames += 1
	return {"session": session, "frames": frames, "contacted_frame": contact_frame, "opponent_frame": opponent_frame}


func seeded(exercise_id: String, seed_value: int) -> RefCounted:
	var athlete: Dictionary = Frozen.athletes()[0]
	var arena: Dictionary = Frozen.arenas()[0]
	var opponents: Array = Frozen.ai_opponents()
	var session := DrillSession.create(String(exercise_id), athlete, arena, opponents[1], {"seed": seed_value})
	Support.inject_seed(session.state, Support.seeded_rng_state(seed_value))
	return session


## `input(over)` (`scripts/drill-audit.mjs:41-46`): the reference's own literal over the
## port's `empty_input`.
func input(over: Dictionary) -> Dictionary:
	var base: Dictionary = Support.vuoto()
	for key in over:
		base[key] = over[key]
	return base


## The drill audits' own scripted swing (`_player_input`, the reference's `vicina` rule),
## with the paddle held under the flying ball and the swing aimed DEEP: a return that clears
## the net and lands in the opponents' court is exactly the legal return this exercise
## grades, so the scripted player has to actually try one.
func _player_input(session) -> Dictionary:
	var ball = session.state.ball
	var vicina: bool = absf(float(ball.y) - float(session.state.player.y)) < 90.0 and float(ball.z) <= 108.0
	if not vicina:
		var delta_y: float = clampf((float(ball.y) - float(session.state.player.y)) / 60.0, -1.0, 1.0)
		return input({"moveY": delta_y})
	return input({"hit": true, "charging": true, "aimY": 0.9})


func _wipe() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir():
				dir.remove(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))


## The sha256 of one reference source file, read from the checkout: `res://` is `godot/`,
## so the reference tree is one level up. `""` when the file cannot be read — a missing
## source is a failed check, not a pass.
static func _source_sha256(relative_path: String) -> String:
	var root := ProjectSettings.globalize_path("res://")
	var path := root.path_join("../%s" % relative_path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()
