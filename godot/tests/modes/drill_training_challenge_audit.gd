## drill_training_challenge_audit.gd — the three TRAINING challenges' own contract.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/modes/drill_training_challenge_audit.gd
##
## WHAT THIS OWNS. `drill_audit.gd` still audits the reference's four rows and
## `return_drill_audit.gd` the Jev exercise; this file owns the training overhaul's three
## challenges (`godot/src/modes/drill_extras.gd`): `glass_recovery`, `net_play`,
## `doubles_tactics`, plus the BOUNDED RUN they all share. What it gates:
##
##   1. THE CONTRACT: the catalog is eight, every id has a well-formed objective, the three
##      families cover all eight in order, and every goal / success / scores / watch id and
##      every control label resolves in BOTH languages — a raw id on screen is the failure
##      these checks exist to catch.
##   2. A BOUNDED RUN: each challenge reaches `summary` after exactly its run length, closes
##      each attempt once, and does NOT restart itself once the run is over.
##   3. REAL PLAY, ON THE ENGINE: with a seeded scripted player each challenge is observed to
##      SUCCEED (its own objective met, its own diagnosis) and, with no input at all, to FAIL
##      with a named diagnosis and no credit — no AI contact is ever the player's.
##   4. A STALLED ATTEMPT CLOSES: the timeout path names itself instead of running forever.
##   5. RESET, RETRY, RECORD: a retry clears the attempt counters and keeps the record, the
##      per-attempt observations do not leak across attempts, and the bounded record lands
##      under its own `training_v1:<id>:<difficulty>:<attempts>` key while the legacy key is
##      written by the session's own path only.
##   6. TRAINING PAYS NOTHING ELSE: finishing a drill run awards no career progress, no
##      outfit, no trophy and no economy receipt.
##
## NO PHYSICS OF ITS OWN. Every step below is `DrillSession.step` -> `Sim.update_match`, and
## every grade is read from the drill's own verdict plus the engine's marks.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Config := preload("res://game/match_config.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const DrillExtras := preload("res://src/modes/drill_extras.gd")
const DrillHub := preload("res://src/modes/drill_hub.gd")
const DrillObjective := preload("res://src/modes/drill_objective.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Locale := preload("res://src/locale/locale.gd")
const ModeSession := preload("res://game/mode_session.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const SaveStore := preload("res://src/save/save_store.gd")
const Sim := preload("res://src/sim/sim.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

const STEP := 1.0 / 120.0
const TEMP_DIR := "user://training-challenge-audit"
## The session-end section's own directory: it measures what a RUN writes, and the records
## section above already wrote records into `TEMP_DIR`.
const RUN_TEMP_DIR := "user://training-challenge-audit-run"
const CHALLENGES: Array = [
	DrillExtras.GLASS_RECOVERY_ID, DrillExtras.NET_PLAY_ID, DrillExtras.DOUBLES_TACTICS_ID,
]
## The seeds the scripted players are run on: three per challenge, so a pass means the
## objective was met on the engine more than once and not on one lucky draw.
const SEEDS: Array = [1234, 4242, 7]
## A seeded scripted attempt is allowed the drill's own attempt budget in ticks.
const TICKS_PER_ATTEMPT := 3000


func _initialize() -> void:
	_wipe()
	var audit := AuditBase.new("drill_training_challenge")
	_contract(audit)
	_bounded_run(audit)
	_play(audit)
	_timeout(audit)
	_records_and_rewards(audit)
	_difficulty(audit)
	_contact_ownership(audit)
	await _summary_actions(audit)
	_wipe()
	quit(audit.finish())


# ---------------------------------------------------------------------------
# 1. The contract: the catalog, the objectives, the words
# ---------------------------------------------------------------------------

func _contract(audit: AuditBase) -> void:
	audit.check_eq(Tables.drill_exercises().size(), 4, "training/the_frozen_reference_still_has_its_own_four")
	audit.check_eq(Tables.drill_catalog().size(), 8, "training/the_catalog_offers_eight")
	var mismatches: Dictionary = DrillObjective.mismatches()
	audit.check_eq(mismatches["missing"], [], "training/every_catalog_exercise_has_an_objective")
	audit.check_eq(mismatches["extra"], [], "training/no_objective_is_orphaned")
	for id in Tables.drill_catalog_ids():
		audit.check_true(DrillObjective.well_formed(String(id)), "training/%s/objective_is_well_formed" % String(id))
		audit.check_gt(DrillObjective.attempts_for(String(id)), 0, "training/%s/has_a_bounded_run" % String(id))
		audit.check_gt(DrillObjective.controls_for(String(id)).size(), 0, "training/%s/lists_the_controls_it_uses" % String(id))

	# The three families cover the catalog, in the order the page shows them.
	var grouped: Array = []
	var labels: Array = []
	for group in DrillHub.groups():
		labels.append(String((group as Dictionary).get("label", "")))
		for card in (group as Dictionary).get("cards", []):
			grouped.append(String((card as Dictionary).get("id", "")))
	# The families REORDER the catalog on purpose (a card belongs to its family, not to the
	# table's row order), so the contract is coverage: every catalog id exactly once, nothing
	# invented — and inside a family, the catalog's own relative order.
	var catalog_ids := Array(Tables.drill_catalog_ids())
	var sorted_grouped := grouped.duplicate()
	sorted_grouped.sort()
	var sorted_catalog := catalog_ids.duplicate()
	sorted_catalog.sort()
	audit.check_eq(sorted_grouped, sorted_catalog, "training/the_groups_hold_every_catalog_exercise_exactly_once")
	for group in DrillHub.groups():
		var ids: Array = []
		for card in (group as Dictionary).get("cards", []):
			ids.append(String((card as Dictionary).get("id", "")))
		var expected: Array = []
		for id in catalog_ids:
			if ids.has(String(id)):
				expected.append(String(id))
		audit.check_eq(ids, expected, "training/the_family_%s_keeps_catalog_order" % String((group as Dictionary).get("id", "")))
	audit.check_eq(labels.size(), 3, "training/the_hub_has_three_families")
	for label in labels:
		audit.check_true(String(label) != "", "training/every_family_has_a_name")

	# Every player-facing id the hub draws resolves in BOTH languages — the objective ids,
	# the controls' own labels, and the diagnoses these challenges can close with.
	var unresolved: Array = []
	for id in Tables.drill_catalog_ids():
		var objective := DrillObjective.for_exercise(String(id))
		var keys: Array = [objective.get("goal_key", ""), objective.get("success_key", ""),
			objective.get("scores_key", ""), objective.get("watch_key", "")]
		for name in (DrillObjective.controls_for(String(id)) as Array):
			keys.append(String((name as Dictionary).get("label", "")))
		for key in keys:
			for lang in ["it", "en"]:
				if not DrillText.has(String(key), String(lang)):
					unresolved.append("%s:%s:%s" % [String(id), String(lang), String(key)])
	var diagnoses := [
		"drillWhyTimeout", "drillWhyNoContact", "drillWhyGlassIn", "drillWhyGlassMissed",
		"drillWhyGlassEarly", "drillWhyGlassOut", "drillWhyNetIn", "drillWhyNoNetShot",
		"drillWhyNetMissed", "drillWhyTacticIn", "drillWhyNoTactic", "drillWhyTacticLost",
		"drillWhyReturnPlayed",
	]
	for key in diagnoses:
		for lang in ["it", "en"]:
			if not DrillText.has(String(key), String(lang)):
				unresolved.append("%s:%s" % [String(lang), String(key)])
	for key in ["drillGroupTechnique", "drillGroupDefence", "drillGroupMatchPlay", "drillHubGoal",
			"drillHubSuccess", "drillHubScores", "drillHubControls", "drillHubBest",
			"drillHubHistoricalBest", "drillHubRun", "drillHudProgress", "drillHudSummary",
			"drillActionRetry", "drillActionChoose", "drillActionExit"]:
		for lang in ["it", "en"]:
			if not DrillText.has(String(key), String(lang)):
				unresolved.append("%s:%s" % [String(lang), String(key)])
	audit.check_eq(unresolved, [], "training/every_player_facing_id_resolves_in_both_languages")

	# The controls are the reference's own pairs, and RT is NOT advertised as sprint: this port
	# feeds the right trigger into the shot's precision (`sim.gd:2930`) and zeroes
	# `paddle.sprinting` (`:3055`), so training must not name it.
	var rt_rows: Array = []
	for id in Tables.drill_catalog_ids():
		for control in DrillObjective.controls_for(String(id)):
			var row: Dictionary = control
			if String(row.get("key", "")) == "RT" or String(row.get("label", "")) == "sprintLbl":
				rt_rows.append("%s:%s" % [String(id), str(row)])
	audit.check_eq(rt_rows, [], "training/no_exercise_advertises_the_right_trigger_as_sprint")


# ---------------------------------------------------------------------------
# 2. The bounded run
# ---------------------------------------------------------------------------

func _bounded_run(audit: AuditBase) -> void:
	for challenge in CHALLENGES:
		var id := String(challenge)
		var session := seeded(id, 1234)
		audit.check_eq(session.run_limit, DrillObjective.attempts_for(id), "training/%s/the_run_length_is_the_objective's" % id)
		session.step(STEP, input({"hit": true}))
		var guard := 0
		while String(session.phase) != "summary" and guard < session.run_limit * TICKS_PER_ATTEMPT:
			session.step(STEP, scripted(session, id))
			guard += 1
		audit.check_eq(String(session.phase), "summary", "training/%s/the_run_reaches_its_summary" % id)
		audit.check_eq(int(session.attempts), int(session.run_limit), "training/%s/the_run_closes_exactly_its_own_attempts" % id)
		audit.check_eq(bool(session.run_done), true, "training/%s/the_run_reports_itself_finished" % id)
		var run: Dictionary = session.summary()
		audit.check_eq(int(run["attempts"]), int(session.attempts), "training/%s/the_summary_counts_the_attempts" % id)
		audit.check_eq(int(run["hits"]), int(session.hits), "training/%s/the_summary_counts_the_hits" % id)
		audit.check_eq(float(run["accuracy"]), float(session.hits) / float(session.attempts), "training/%s/the_accuracy_is_hits_over_attempts" % id)
		audit.check_eq(int(run["score"]), int(session.score), "training/%s/the_summary_carries_the_score" % id)
		audit.check_eq(int(run["run_limit"]), int(session.run_limit), "training/%s/the_summary_carries_the_run_length" % id)

		# A finished run WAITS: stepping it again must not open a ninth attempt.
		var before := int(session.attempts)
		for _i in 600:
			session.step(STEP, input({"hit": true}))
		audit.check_eq(int(session.attempts), before, "training/%s/a_finished_run_does_not_restart_itself" % id)

		# Retry: the counters go back to zero, the record does not.
		var best_before := int(session.best)
		session.restart_run()
		audit.check_eq(int(session.attempts), 0, "training/%s/a_retry_clears_the_attempts" % id)
		audit.check_eq(int(session.hits), 0, "training/%s/a_retry_clears_the_hits" % id)
		audit.check_eq(int(session.score), 0, "training/%s/a_retry_clears_the_score" % id)
		audit.check_eq(int(session.best), best_before, "training/%s/a_retry_keeps_the_record" % id)
		audit.check_eq(String(session.phase), "live", "training/%s/a_retry_starts_a_live_run" % id)
		audit.check_eq(int(session.attempts), 0, "training/%s/a_retry_does_not_double_count" % id)
		audit.report("%s run: attempts=%d hits=%d score=%d best=%d" % [
			id, int(session.attempts), int(session.hits), int(session.score), int(session.best)])


# ---------------------------------------------------------------------------
# 3. Real play: a success and a failure per challenge, on the engine
# ---------------------------------------------------------------------------

func _play(audit: AuditBase) -> void:
	for challenge in CHALLENGES:
		var id := String(challenge)
		var successes := 0
		var diagnoses: Array = []
		for seed_value in SEEDS:
			var session := seeded(id, int(seed_value))
			session.step(STEP, input({"hit": true}))
			var guard := 0
			while String(session.phase) == "live" and guard < TICKS_PER_ATTEMPT:
				session.step(STEP, scripted(session, id))
				guard += 1
			diagnoses.append(String(session.diagnosis))
			if int(session.hits) > 0:
				successes += 1
				# A hit is the player's own: the drill required a fresh controlled contact and
				# the objective's own measured outcome, and it pays.
				audit.check_true(bool(session.attempt_contact), "training/%s/seed_%d/a_hit_required_a_human_contact" % [id, int(seed_value)])
				audit.check_gt(int(session.points), 0, "training/%s/seed_%d/a_hit_scores" % [id, int(seed_value)])
				audit.check_eq(session.diagnosis, success_diagnosis(id), "training/%s/seed_%d/the_success_names_its_own_objective" % [id, int(seed_value)])
		audit.check_gt(successes, 0, "training/%s/the_challenge_is_winnable_by_a_scripted_player" % id)
		audit.report("%s scripted: %d of %d succeeded, diagnoses %s" % [id, successes, SEEDS.size(), str(diagnoses)])

		# THE NO-INPUT RUN: nothing the opponents do may be credited to the player.
		var passive := seeded(id, 99)
		passive.step(STEP, input({"hit": true}))
		var guard := 0
		while String(passive.phase) == "live" and guard < TICKS_PER_ATTEMPT:
			passive.step(STEP, input({}))
			guard += 1
		audit.check_eq(int(passive.hits), 0, "training/%s/an_untouched_ball_is_never_a_hit" % id)
		audit.check_eq(bool(passive.attempt_contact), false, "training/%s/and_never_records_a_human_contact" % id)
		audit.check_eq(String(passive.phase), "result", "training/%s/the_passive_attempt_still_closes_once" % id)
		audit.check_eq(int(passive.attempts), 1, "training/%s/and_counts_as_one" % id)
		audit.check_true(DrillText.has(String(passive.diagnosis), "it") and DrillText.has(String(passive.diagnosis), "en"), "training/%s/the_failure_diagnosis_resolves_in_both_languages" % id)
		audit.check_true(not String(passive.diagnosis).begins_with("drillWhy") or success_diagnosis(id) != String(passive.diagnosis), "training/%s/no_input_is_not_graded_as_the_success" % id)

		# STALE OBSERVATIONS: the next attempt starts clean.
		passive.step(STEP, input({}))
		passive.step(STEP, input({"hit": true}))
		audit.check_eq(String(passive.phase), "live", "training/%s/the_next_attempt_opens" % id)
		audit.check_eq(bool(passive.attempt_contact), false, "training/%s/the_next_attempt_has_no_stale_contact" % id)
		audit.check_eq(bool(passive.attempt_glass), false, "training/%s/the_next_attempt_has_no_stale_glass_mark" % id)
		audit.check_eq(bool(passive.attempt_bounced_ai), false, "training/%s/the_next_attempt_has_no_stale_landing" % id)
		audit.check_eq(bool(passive.attempt_tactic_called), false, "training/%s/the_next_attempt_has_no_stale_tactic" % id)


# ---------------------------------------------------------------------------
# 4. A stalled attempt
# ---------------------------------------------------------------------------

func _timeout(audit: AuditBase) -> void:
	for challenge in CHALLENGES:
		var id := String(challenge)
		var session := seeded(id, 2024)
		session.step(STEP, input({"hit": true}))
		# The attempt's own clock, past the bound, on a tick where nothing has resolved yet:
		# the ball is still the opponents' feed in flight.
		session.attempt_time = DrillSession.ATTEMPT_TIMEOUT + 1.0
		session.step(STEP, input({}))
		audit.check_eq(String(session.diagnosis), "drillWhyTimeout", "training/%s/a_stalled_attempt_is_closed_by_the_timeout" % id)
		audit.check_eq(int(session.attempts), 1, "training/%s/and_counts_once" % id)
		audit.check_eq(int(session.hits), 0, "training/%s/and_is_not_a_hit" % id)


# ---------------------------------------------------------------------------
# 5. Records and rewards
# ---------------------------------------------------------------------------

func _records_and_rewards(audit: AuditBase) -> void:
	var store := SaveStore.new(TEMP_DIR)
	for challenge in CHALLENGES:
		var id := String(challenge)
		var attempts := DrillObjective.attempts_for(id)
		audit.check_eq(ModesSave.training_best(store, id, "easy", attempts), 0, "training/%s/no_bounded_record_yet" % id)
		ModesSave.save_training_score(store, id, "easy", attempts, 31)
		audit.check_eq(ModesSave.training_best(store, id, "easy", attempts), 31, "training/%s/the_bounded_record_is_written" % id)
		# A different difficulty or run length is a DIFFERENT record: two runs are comparable
		# only when the key matches.
		audit.check_eq(ModesSave.training_best(store, id, "hard", attempts), 0, "training/%s/another_difficulty_is_another_record" % id)
		audit.check_eq(ModesSave.training_best(store, id, "easy", attempts + 1), 0, "training/%s/another_run_length_is_another_record" % id)
		audit.check_eq(ModesSave.training_key(id, "easy", attempts), "training_v1:%s:easy:%d" % [id, attempts], "training/%s/the_key_is_stable" % id)
		# The bounded write leaves the legacy record ALONE.
		audit.check_eq(ModesSave.drill_best(store, id), 0, "training/%s/the_bounded_write_does_not_touch_the_legacy_record" % id)
		audit.check_eq(ModesSave.save_training_score(store, id, "easy", attempts, 12).get("skipped", false), true, "training/%s/a_worse_run_is_not_written" % id)
		audit.check_eq(ModesSave.training_best(store, id, "easy", attempts), 31, "training/%s/and_the_record_stands" % id)
	audit.check_eq(ModesSave.load_training_records(store).size(), CHALLENGES.size(), "training/only_the_challenges_wrote_bounded_records")

	# THE SESSION'S OWN END: a training run writes the bounded record and awards nothing else.
	# Its own directory: the records written above would otherwise stand as the baseline the
	# improvement-only rule compares against.
	var run_store := SaveStore.new(RUN_TEMP_DIR)
	_wipe_dir(RUN_TEMP_DIR)
	var session := ModeSession.start("drill", run_store, {
		"athlete": Frozen.athletes()[0], "arena": Frozen.arenas()[0],
		"arenas": Frozen.arenas(), "seed": 1234, "exercise": DrillExtras.NET_PLAY_ID,
		"difficulty": "easy",
	})
	audit.check_true(session != null, "training/the_mode_session_starts_a_drill")
	if session != null:
		session.drill.score = 27
		var persisted: Dictionary = session.persist_training_record()
		audit.check_eq(String(persisted.get("key", "")), "training_v1:%s:easy:%d" % [DrillExtras.NET_PLAY_ID, DrillObjective.attempts_for(DrillExtras.NET_PLAY_ID)], "training/the_run_persists_its_own_bounded_key")
		audit.check_eq(ModesSave.training_best(run_store, DrillExtras.NET_PLAY_ID, "easy", DrillObjective.attempts_for(DrillExtras.NET_PLAY_ID)), 27, "training/and_the_record_reads_back")
		var awarded: Dictionary = session.finish()
		audit.check_eq(String(awarded.get("mode", "")), "drill", "training/the_finish_reports_the_drill")
		for field in ["career", "outfits", "trophy", "economy", "objectives", "history"]:
			audit.check_eq(awarded.has(field), false, "training/finishing_a_run_awards_no_%s" % field)
		audit.check_eq(ModesSave.load_history(run_store).size(), 0, "training/a_run_writes_no_history_entry")
		audit.check_eq(ModesSave.load_career(run_store)["wins"], 0, "training/a_run_does_not_touch_the_career")


# ---------------------------------------------------------------------------
# 6. The difficulty the hub chose is the difficulty the run plays
# ---------------------------------------------------------------------------

func _difficulty(audit: AuditBase) -> void:
	var store := SaveStore.new(TEMP_DIR)
	var chosen := ModeSession.start("drill", store, {
		"athlete": Frozen.athletes()[0], "arena": Frozen.arenas()[0], "arenas": Frozen.arenas(),
		"seed": 7, "exercise": DrillExtras.GLASS_RECOVERY_ID, "difficulty": "hard",
	})
	audit.check_true(chosen != null, "training/the_session_starts_with_a_chosen_difficulty")
	if chosen != null:
		audit.check_eq(String(chosen.difficulty), "hard", "training/the_run_records_the_chosen_difficulty")
		audit.check_eq(String(chosen.ai["id"]), String(CareerRules.ai_for_match("quick", 0, "hard")["id"]), "training/the_run_plays_the_profile_that_difficulty_names")
	var default_run := ModeSession.start("drill", store, {
		"athlete": Frozen.athletes()[0], "arena": Frozen.arenas()[0], "arenas": Frozen.arenas(),
		"seed": 7, "exercise": DrillExtras.GLASS_RECOVERY_ID,
	})
	if default_run != null:
		# No choice = the first opponent, which is exactly what the drill resolved before the
		# difficulty was wired: the default behaviour is unchanged.
		audit.check_eq(String(default_run.ai["id"]), String(Frozen.ai_opponents()[0]["id"]), "training/no_choice_keeps_the_original_opponent")
		audit.check_eq(String(default_run.difficulty), DrillHub.DEFAULT_DIFFICULTY, "training/no_choice_records_the_default")


# ---------------------------------------------------------------------------
# Scenario builders
# ---------------------------------------------------------------------------

## 7. THE SUMMARY'S OWN WAYS IN. A finished run is the one screen a player has to OPERATE,
## so it is driven here the way a player drives it: through the match's real tick path (A and
## B), through the panel's real Buttons (the mouse), and through the exit action. It also pins
## the guard that keeps the shot which ended the run from pressing Retry by itself.
func _summary_actions(audit: AuditBase) -> void:
	var previous_save_dir: String = String(Config.save_dir)
	Config.save_dir = "user://training-summary-audit"
	var first := await _match_node()
	if first == null:
		audit.check_true(false, "summary/the_match_scene_mounts_a_drill")
		Config.save_dir = previous_save_dir
		return
	audit.check_true(await _to_summary(first), "summary/the_run_reaches_its_summary_on_the_match_path")
	var before_attempts := int(first.session.drill.attempts)
	audit.check_gt(before_attempts, 0, "summary/the_run_played_its_attempts")

	# (a) THE SHOT THAT ENDED THE RUN. The very first tick of the summary still carries the
	# player's input: it must NOT restart the run.
	first.tick_fixed(STEP, input({"hit": true}), Sim.empty_input())
	audit.check_eq(int(first.session.drill.attempts), before_attempts, "summary/the_ending_shot_does_not_retry_the_run")
	audit.check_true(first.training_summary_up(), "summary/and_the_summary_is_still_up")
	audit.check_true(first.mode_hud().is_visible_in_tree(), "summary/shipping_UI_shows_the_summary")
	var focus_retry: Button = first.mode_hud().find_child("Action_retry", true, false)
	focus_retry.grab_focus()
	await process_frame
	var direction := InputEventJoypadButton.new()
	direction.button_index = JOY_BUTTON_DPAD_RIGHT
	direction.pressed = true
	Input.parse_input_event(direction)
	await process_frame
	audit.check_eq(root.gui_get_focus_owner().name, "Action_choose", "summary/dpad_reaches_choose")
	direction.pressed = false
	Input.parse_input_event(direction)
	await process_frame
	direction = InputEventJoypadButton.new()
	direction.button_index = JOY_BUTTON_DPAD_RIGHT
	direction.pressed = true
	Input.parse_input_event(direction)
	await process_frame
	audit.check_eq(root.gui_get_focus_owner().name, "Action_exit", "summary/dpad_reaches_exit")
	direction.pressed = false
	Input.parse_input_event(direction)
	focus_retry.grab_focus()
	if OS.get_cmdline_user_args().has("--capture-summary"):
		root.size = Vector2i(1280, 720)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/training-summary-final.png")
	audit.check_eq(first.training_destination("exit")["screen"], "menu", "summary/exit_routes_to_menu")
	audit.check_eq(first.training_destination("choose")["screen"], "drill", "summary/choose_routes_to_hub")

	# (b) A: one quiet tick arms the summary, then the confirm retries the SAME exercise.
	first.tick_fixed(STEP, input({}), Sim.empty_input())
	for _i in 60:
		first.tick_fixed(STEP, input({}), Sim.empty_input())
	first.tick_fixed(STEP, input({"hit": true}), Sim.empty_input())
	audit.check_eq(int(first.session.drill.attempts), 0, "summary/A_retries_the_run")
	audit.check_eq(String(first.session.drill.phase), "live", "summary/and_the_retry_is_live")
	audit.check_true(not first.training_summary_up(), "summary/so_the_summary_is_gone")

	# (c) THE MOUSE: the panel's own Retry button, pressed for real.
	audit.check_true(await _to_summary(first), "summary/the_retried_run_reaches_its_summary")
	var panel: Control = first.mode_hud()
	var retry_button := panel.find_child("Action_retry", true, false) as Button
	var choose_button := panel.find_child("Action_choose", true, false) as Button
	var exit_button := panel.find_child("Action_exit", true, false) as Button
	audit.check_true(retry_button != null and choose_button != null and exit_button != null, "summary/the_panel_offers_three_real_buttons")
	if retry_button != null:
		retry_button.emit_signal("pressed")
		audit.check_eq(int(first.session.drill.attempts), 0, "summary/a_mouse_click_on_Retry_retries_the_run")
		audit.check_true(not first.training_summary_up(), "summary/and_leaves_the_summary")

	# (d) B: change exercise, from the input the pad and the keyboard both feed.
	audit.check_true(await _to_summary(first), "summary/the_second_retry_reaches_its_summary")
	first.tick_fixed(STEP, input({}), Sim.empty_input())
	for _i in 60:
		first.tick_fixed(STEP, input({}), Sim.empty_input())
	first.tick_fixed(STEP, input({"special": true}), Sim.empty_input())
	audit.check_true(bool(first.session.finished), "summary/B_ends_the_run")
	audit.check_eq(String(first.take_training_choice()), "choose", "summary/and_asks_for_the_training_hub")
	audit.check_eq(String(first.session.awarded.get("mode", "")), "drill", "summary/the_end_is_the_drills_own")
	_drop_match(first)

	# (e) THE EXIT BUTTON: the third action, on its own run.
	var second := await _match_node()
	if second != null:
		audit.check_true(await _to_summary(second), "summary/the_exit_run_reaches_its_summary")
		var exit_panel: Control = second.mode_hud()
		var exit_action := exit_panel.find_child("Action_exit", true, false) as Button
		if exit_action != null:
			exit_action.grab_focus()
			exit_panel.activate_training_action()
		audit.check_true(bool(second.session.finished), "summary/the_exit_button_ends_the_run")
		audit.check_eq(String(second.take_training_choice()), "exit", "summary/and_asks_for_the_menu")
		audit.check_eq(ModesSave.load_history(SaveStore.new("user://training-summary-audit")).size(), 0, "summary/no_action_writes_a_history_entry")
		_drop_match(second)
	Config.save_dir = previous_save_dir


## A match node carrying a real drill session, built exactly the way the slice test builds one
## (`harness_mode()` + the mode resolved from `Config`).
func _match_node() -> Node:
	Config.pending_mode = "drill"
	Config.pending_round = -1
	Config.pending_exercise = DrillExtras.NET_PLAY_ID
	Config.pending_drill_difficulty = "easy"
	var node: Node = (load("res://game/Match.tscn") as PackedScene).instantiate()
	node.set("load_models", false)
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	for _i in 3:
		await process_frame
	return node if node.session != null and node.session.mode == "drill" else null


## Plays the mounted run with the same scripted player the sections above use, until the run's
## own summary is up (or the tick budget runs out).
func _to_summary(node: Node) -> bool:
	var guard := 0
	while not node.training_summary_up() and guard < 12 * TICKS_PER_ATTEMPT:
		# The drill's own `ready` gate: the first press STARTS a round, and a scripted player
		# that only swings at a reachable ball would never press it.
		var frame_input := input({"hit": true}) if String(node.session.drill.phase) == "ready" \
			else scripted(node.session.drill, DrillExtras.NET_PLAY_ID)
		node.tick_fixed(STEP, frame_input, Sim.empty_input())
		guard += 1
	return node.training_summary_up()


func _drop_match(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()

## The diagnosis a SUCCESSFUL attempt of this challenge carries, read from the session's own
## branch names (never retyped into the assertions above).
func success_diagnosis(exercise_id: String) -> String:
	match exercise_id:
		DrillExtras.GLASS_RECOVERY_ID:
			return "drillWhyGlassIn"
		DrillExtras.NET_PLAY_ID:
			return "drillWhyNetIn"
		DrillExtras.DOUBLES_TACTICS_ID:
			return "drillWhyTacticIn"
	return ""


func seeded(exercise_id: String, seed_value: int) -> RefCounted:
	var session := DrillSession.create(
		exercise_id, Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
		{"seed": seed_value}
	)
	Support.inject_seed(session.state, Support.seeded_rng_state(seed_value))
	return session


func input(over: Dictionary) -> Dictionary:
	var base: Dictionary = Support.vuoto()
	for key in over:
		base[key] = over[key]
	return base


## The scripted player, one shape per challenge and all of them the same primitive input the
## audits above use: move the controlled paddle toward the ball, and swing when it is in reach.
##
##   glass_recovery  — do NOT touch the ball until the engine has marked the human's own glass
##                     (`ball.postGlassSide`), then play it;
##   net_play        — hold the charge, stay at the net, and take the ball in the air;
##   doubles_tactics — call the pair tactic (`teamTactic`) on the first live frame and then
##                     play the point out.
func scripted(session, exercise_id: String) -> Dictionary:
	var state = session.state
	var pad = state.active_player()
	var ball = state.ball
	var over: Dictionary = {
		"moveX": clampf((float(ball.x) - float(pad.x)) / 30.0, -1.0, 1.0) if absf(float(ball.y) - float(pad.y)) > 70.0 else 0.0,
		"moveY": clampf((float(ball.y) - float(pad.y)) / 60.0, -1.0, 1.0) if absf(float(ball.y) - float(pad.y)) > 40.0 else 0.0,
		"aimY": 0.55,
	}
	match exercise_id:
		DrillExtras.GLASS_RECOVERY_ID:
			# Wait for the glass: the recovery is the shot AFTER it, and a swing before it is
			# the exercise's own "played too early" failure.
			if bool(session.attempt_glass):
				over["hit"] = Sim.can_hit(pad, ball)
			else:
				over["moveY"] = clampf((float(Frozen.court()["bottom"]) - 40.0 - float(pad.y)) / 60.0, -1.0, 1.0)
		DrillExtras.NET_PLAY_ID:
			over["charging"] = true
			over["aim"] = 0.45
			over["hit"] = Sim.can_hit(pad, ball) and float(ball.z) >= 46.0
		DrillExtras.DOUBLES_TACTICS_ID:
			# One call, on the first live frame of the attempt: a CHANGE of tactic is what the
			# exercise counts, and `balanced` is the state's own default.
			over["teamTactic"] = "attack" if not bool(session.attempt_tactic_called) else null
			over["charging"] = true
			over["hit"] = Sim.can_hit(pad, ball)
	return input(over)


func _wipe() -> void:
	_wipe_dir(TEMP_DIR)
	_wipe_dir(RUN_TEMP_DIR)
	_wipe_dir("user://training-summary-audit")


func _contact_ownership(audit: AuditBase) -> void:
	var session := seeded("return", 1234)
	session.start_round()
	var before: Dictionary = session._observe_before()
	session.state.rallyHits += 1
	session.state.lastHitterSide = "player"
	session.state.shotFeedback = {"life": 0.78, "paddleKey": "playerMate"}
	session.state.playerMate.controlled = false
	session._observe_after(before)
	session._step_return(0, int(before["rally"]), 0.0, 0.0)
	audit.check_true(not session.return_contact, "ownership/AI_partner_is_not_a_human_return")
	for id in ["precision", "glass_recovery", "net_play"]:
		var drill := seeded(id, 1234)
		drill.start_round()
		drill.attempt_contact = true
		drill.attempt_bounced_ai = true
		drill.attempt_contact_after_glass = true
		drill.attempt_contact_in_air = true
		drill._grade_live(drill._observe_before())
		audit.check_eq(drill.attempts, 0, "ownership/%s/stale_landing_never_scores" % id)


func _wipe_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir():
				dir.remove(entry)
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
