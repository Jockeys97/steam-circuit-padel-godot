## coach_test.gd — the coach's own contract test: contract, snapshot, advice, text.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##       --script res://tests/coach_test.gd
##
## WHAT IT GATES, and where each answer comes from:
##   1. THE CONTRACT IS THE ONE THE BRIDGE READS: six declared categories with
##      `insufficient_data` among them, five of them drillable, the gate and the
##      sufficiency floors declared, and the wire version and path stated once.
##   2. THE SNAPSHOT IS THE MATCH'S OWN NUMBERS. A match the simulation itself stepped
##      (`Sim.update_match` with a `ScriptedPlayer`) is turned into a result payload by the
##      result screen's own builder, and every counter the coach would send is compared to
##      that state's own `stats` — nothing recomputed, nothing inferred, and the average
##      rally is the result screen's own formula.
##   3. THE SNAPSHOT REFUSES WHAT IT CANNOT MEASURE: a payload with a negative, fractional,
##      textual or oversized counter is named in `problems` and never becomes askable; an
##      unknown key is ignored and recorded; a match with fewer points or rallies than the
##      floors is `insufficient_data` with no request — and never a candidate list of one.
##   4. EVERY DRILLABLE CATEGORY HAS A SENTENCE, A DRILL THAT EXISTS AND THE NUMBERS THE
##      SENTENCE QUOTES: the advice id resolves in both tables, the drill id is one of the
##      frozen drill table's four, and the placeholders of the sentence are exactly the
##      parameters the adapter supplies from the snapshot.
##   5. AN ANSWER IS ONLY SHOWN IF IT PASSES ITS OWN CONTRACT, and the provisional gate
##      decides how much is claimed: a low-confidence choice, an unoffered category, a
##      wrong type, a confidence outside [0, 1] and a distribution that is not one all end
##      up as a state that shows the match's numbers and offers no exercise.
##   6. THE FALLBACK CHAIN: an unknown locale is answered by the fallback, an unknown id
##      comes back as the id, and the two tables define the same ids.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally.
extends SceneTree

const Advice := preload("res://src/coach/coach_advice.gd")
const AuditBase := preload("res://src/audits/audit_base.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CoachText := preload("res://src/coach/coach_text.gd")
const Config := preload("res://game/match_config.gd")
const Contract := preload("res://src/coach/coach_contract.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const Locale := preload("res://src/locale/locale.gd")
const ScreenClass := preload("res://src/ui/screens/ResultScreen.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const Sim := preload("res://src/sim/sim.gd")
const Stats := preload("res://src/coach/coach_stats.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

const TICK := 1.0 / 60.0
const SEED := 20260920
## A points match the bot plays to its end: the ceiling is generous, and the loop stops the
## moment the state has a result (the sampled match needed ~9 000 ticks for 17 points, so
## the ceiling is what an unusually long match could take, not what this one costs).
const LIVE_TICKS := 30000
const TEMP_DIR := "user://jev-coach-test"

var _previous_dir := ""


func _initialize() -> void:
	_previous_dir = Config.save_dir
	Config.save_dir = TEMP_DIR
	var audit := AuditBase.new("coach")
	await _run(audit)
	_wipe()
	Config.save_dir = _previous_dir
	quit(audit.finish())


func _wipe() -> void:
	DirAccess.remove_absolute(TEMP_DIR)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR))


func _run(audit: AuditBase) -> void:
	_contract(audit)
	_text(audit)
	_refusals(audit)
	_support(audit)
	_mapping(audit)
	_answers(audit)
	await _live(audit)


# ---------------------------------------------------------------------------
# 1. The contract
# ---------------------------------------------------------------------------

func _contract(audit: AuditBase) -> void:
	audit.check_true(Contract.available(), "coach/the_contract_loads")
	var ids := Contract.category_ids()
	audit.check_eq(ids.size(), 6, "coach/six_categories_are_declared")
	audit.check_true(ids.has(Contract.INSUFFICIENT), "coach/insufficient_data_is_one_of_them")
	audit.check_true(ids.has("serve_return"), "coach/serve_return_is_one_of_them")
	audit.check_eq(Contract.drill_categories().size(), 5, "coach/five_of_them_can_link_an_exercise")
	audit.check_eq(String(Contract.wire().get("path", "")), "/coach/jev", "coach/the_wire_path_is_the_bridge_path")
	audit.check_eq(int(Contract.wire().get("version", 0)), Contract.WIRE_VERSION, "coach/the_wire_version_is_the_declared_one")
	audit.check_gt(Contract.confidence_gate(), 0.0, "coach/a_confidence_gate_is_declared")
	audit.check_le(Contract.confidence_gate(), 1.0, "coach/the_gate_is_a_probability")
	var floors := Contract.sufficiency()
	audit.check_ge(int(floors.get("minCandidates", 0)), 2, "coach/a_choice_needs_at_least_two_drillable_options")
	audit.check_gt(int(floors.get("minPointsPlayed", 0)), 0, "coach/a_points_floor_is_declared")
	audit.check_gt(int(floors.get("minRallies", 0)), 0, "coach/a_rally_floor_is_declared")
	audit.check_eq(String(Contract.upstream().get("endpoint", "")), "https://api.typesafe.ai/v1/systemone", "coach/the_upstream_is_the_fixed_typesafe_endpoint")
	audit.check_eq(String(Contract.upstream().get("model", "")), "jev-latest", "coach/the_model_is_jev_latest")
	audit.report("contract: %s" % str(ids))


# ---------------------------------------------------------------------------
# 2. The sentences
# ---------------------------------------------------------------------------

## Every id the coach can put on a screen. A new sentence in the code that is not in this
## list is a sentence no one resolves; a new one in the tables with no code behind it is
## dead weight — the second is caught by the "both tables define the same ids" check, and
## this list is what makes the first impossible.
func _showable_ids() -> Array:
	return [
		"coachTitle", "coachDisclosure", "coachAggregate", "coachAnalyze", "coachLoading",
		"coachInsufficient", "coachUnavailable", "coachInvalid", "coachRetry",
		"coachUncertain", "coachEvidence", "coachExercise", "coachOpenDrill",
		"coachDrillBlocked",
		Advice.advice_id("serve_accuracy"), Advice.advice_id("shot_accuracy"),
		Advice.advice_id("rally_consistency"), Advice.advice_id("net_finishing"),
		Advice.advice_id("serve_return"),
	]


func _text(audit: AuditBase) -> void:
	var locales := CoachText.locales()
	audit.check_true(locales.has("it"), "coach/italian_is_a_declared_locale")
	audit.check_true(locales.has("en"), "coach/english_is_a_declared_locale")
	var italian := CoachText.ids("it")
	var english := CoachText.ids("en")
	audit.check_gt(italian.size(), 10, "coach/the_tables_are_populated")
	var only_one_side: Array = []
	for id in italian:
		if not english.has(String(id)):
			only_one_side.append(String(id))
	for id in english:
		if not italian.has(String(id)):
			only_one_side.append(String(id))
	audit.check_eq(only_one_side, [], "coach/both_tables_define_the_same_ids")
	var unresolved: Array = []
	for id in _showable_ids():
		for lang in locales:
			if not CoachText.has(String(id), String(lang)):
				unresolved.append("%s:%s" % [String(id), String(lang)])
	audit.check_eq(unresolved, [], "coach/every_id_the_coach_can_show_resolves_in_both_tables")
	audit.check_eq(CoachText.t("does_not_exist_key"), "does_not_exist_key", "coach/an_unknown_id_comes_back_as_the_id")
	audit.check_eq(CoachText.t("coachTitle", {}, "de"), CoachText.t("coachTitle", {}, "it"), "coach/an_unknown_locale_is_answered_by_the_fallback")
	audit.check_true(CoachText.t("coachEvidence", {"errors": 4}).contains("4"), "coach/placeholders_are_substituted")

	# The other half of the UI lane's own scan: the sentences live in the JSON and are not
	# duplicated into any script, so a language flip cannot be defeated by a stale copy.
	var duplicated: Array = []
	for path in _coach_scripts():
		var source := _code_only(FileAccess.get_file_as_string(String(path)))
		for lang in locales:
			for id in CoachText.ids(String(lang)):
				var sentence := CoachText.resolve(String(id), String(lang))
				if sentence != String(id) and source.contains(sentence):
					duplicated.append("%s: %s" % [String(path), String(id)])
	audit.check_eq(duplicated, [], "coach/no_sentence_is_duplicated_into_a_script")

	# Nothing the coach says may name a cause this build does not measure: "unforced", a
	# missed chance, a position on court or a serve "costing" points are all claims the
	# counters cannot support. The criteria are checked too — they are what the model reads.
	var forbidden := ["unforced", "missed", "chance", "occasions", "cost", "out of position", "net position", "sbagli", "occasione", "costa", "posizione"]
	var overclaiming: Array = []
	var spoken: Array = ["coachEvidence"]
	for id in Contract.drill_categories():
		spoken.append(String(Advice.advice_id(String(id))))
	for lang in locales:
		for id in spoken:
			var text := CoachText.resolve(String(id), String(lang)).to_lower()
			for word in forbidden:
				if text.contains(String(word)):
					overclaiming.append("%s:%s says '%s'" % [String(id), String(lang), String(word)])
	for id in Contract.category_ids():
		var rubric := String(Contract.criteria().get(String(id), "")).to_lower()
		for word in forbidden:
			if rubric.contains(String(word)):
				overclaiming.append("criteria:%s says '%s'" % [String(id), String(word)])
	audit.check_eq(overclaiming, [], "coach/nothing_names_a_cause_this_build_does_not_measure")


## The source with its comments removed, the way the UI lane's own literal scan reads a
## script (`godot/tests/ui/router_audit.gd::_offenders_in_source`): a sentence quoted in a
## comment is documentation, not a second copy of the table.
func _code_only(source: String) -> String:
	var kept: Array[String] = []
	for line in source.split("\n"):
		kept.append(String(line).split("#")[0])
	return "\n".join(kept)


func _coach_scripts() -> Array:
	return [
		"res://src/coach/coach_advice.gd",
		"res://src/coach/coach_client.gd",
		"res://src/coach/coach_contract.gd",
		"res://src/coach/coach_stats.gd",
		"res://src/coach/coach_text.gd",
		"res://src/ui/coach/CoachPanel.gd",
	]


# ---------------------------------------------------------------------------
# 3. The snapshot
# ---------------------------------------------------------------------------

## A measured match's own shape, as the simulation writes it (`godot/src/sim/sim.gd`).
## Overrides replace whole entries, so a test can zero one group without touching the rest.
func _stats(overrides: Dictionary = {}) -> Dictionary:
	var out := {
		"pointsWon": {"player": 11, "ai": 7},
		# The opponent's aces are the return focus's only evidence, so the default fixture
		# carries a high count the way a match dominated by unreturned serves would.
		"aces": {"player": 2, "ai": 4},
		"winners": {"player": 5, "ai": 3},
		"errors": {"player": 4, "ai": 6},
		"doubleFaults": {"player": 3, "ai": 1},
		"smashWinners": {"player": 1, "ai": 0},
		"rallyCount": 9,
		"totalRallyHits": 32,
		"longestRally": 7,
	}
	for key in overrides.keys():
		out[key] = overrides[key]
	return out


func _snapshot(overrides: Dictionary = {}) -> Dictionary:
	return Stats.snapshot({"stats": _stats(overrides)})


func _refusals(audit: AuditBase) -> void:
	var empty := Stats.snapshot({"stats": {}})
	audit.check_eq(bool(empty.get("sufficient", true)), false, "coach/an_empty_match_is_not_enough")
	audit.check_eq(empty.get("candidates", []), [Contract.INSUFFICIENT], "coach/an_empty_match_offers_only_insufficient_data")
	audit.check_eq(empty.get("counters", {}).get("rallyCount", -1), 0, "coach/an_absent_counter_reads_as_zero")
	audit.check_true(_names("malformed:pointsWon", empty.get("blockers", [])), "coach/an_absent_group_is_a_blocker")
	audit.check_true(_names("missing:rallyCount", empty.get("blockers", [])), "coach/an_absent_rally_count_is_a_blocker")

	# A group that is present but not an object is not a side that measured zero either.
	var shaped := _stats({})
	shaped["errors"] = 4
	var wrong_shape := Stats.snapshot({"stats": shaped})
	audit.check_true(_names("malformed:errors", wrong_shape.get("blockers", [])), "coach/a_wrong_shaped_group_is_a_blocker")
	audit.check_eq(bool(wrong_shape.get("sufficient", true)), false, "coach/a_wrong_shaped_group_is_never_askable")

	# And a group whose side is missing is missing, not zero.
	var half := _stats({})
	(half["aces"] as Dictionary).erase("ai")
	var missing_side := Stats.snapshot({"stats": half})
	audit.check_true(_names("missing:aces.ai", missing_side.get("blockers", [])), "coach/a_missing_side_is_a_blocker")
	audit.check_eq(bool(missing_side.get("sufficient", true)), false, "coach/a_missing_side_is_never_askable")

	var textual := Stats.snapshot({"stats": _stats({"errors": {"player": "four", "ai": 6}})})
	audit.check_true(_names("malformed:errors.player", textual.get("problems", [])), "coach/a_textual_counter_is_named")
	audit.check_eq(bool(textual.get("sufficient", true)), false, "coach/a_textual_counter_is_never_askable")
	audit.check_eq(int(textual.get("counters", {}).get("errors", {}).get("player", -1)), 0, "coach/a_textual_counter_reads_as_zero")

	var negative := Stats.snapshot({"stats": _stats({"errors": {"player": -2, "ai": 6}})})
	audit.check_true(_names("negative:errors.player", negative.get("problems", [])), "coach/a_negative_counter_is_named")
	audit.check_eq(bool(negative.get("sufficient", true)), false, "coach/a_negative_counter_is_never_askable")

	var fractional := Stats.snapshot({"stats": _stats({"winners": {"player": 2.5, "ai": 3}})})
	audit.check_true(_names("fractional:winners.player", fractional.get("problems", [])), "coach/a_fractional_counter_is_named")
	audit.check_eq(bool(fractional.get("sufficient", true)), false, "coach/a_fractional_counter_is_never_askable")

	var infinite := Stats.snapshot({"stats": _stats({"rallyCount": INF})})
	audit.check_true(_names("malformed:rallyCount", infinite.get("problems", [])), "coach/an_infinite_counter_is_named")
	audit.check_eq(bool(infinite.get("sufficient", true)), false, "coach/an_infinite_counter_is_never_askable")

	var oversized := Stats.snapshot({"stats": _stats({"rallyCount": Contract.max_value() + 1})})
	audit.check_true(_names("clamped:rallyCount", oversized.get("problems", [])), "coach/a_counter_over_the_declared_bound_is_named")
	audit.check_eq(bool(oversized.get("sufficient", true)), false, "coach/a_counter_over_the_bound_is_never_askable")

	var extra := _stats({})
	extra["goals"] = 3
	var unknown := Stats.snapshot({"stats": extra})
	audit.check_true(_names("ignored:goals", unknown.get("problems", [])), "coach/an_unknown_counter_is_recorded")
	audit.check_eq(unknown.get("blockers", []), [], "coach/an_unknown_counter_does_not_block_the_measured_ones")
	audit.check_eq(bool(unknown.get("sufficient", false)), true, "coach/a_future_counter_does_not_silence_the_coach")

	var short_match := Stats.snapshot({"stats": _stats({"pointsWon": {"player": 3, "ai": 2}})})
	audit.check_eq(bool(short_match.get("sufficient", true)), false, "coach/a_match_under_the_points_floor_is_not_enough")
	audit.check_eq(short_match.get("candidates", []), [Contract.INSUFFICIENT], "coach/and_offers_only_insufficient_data")

	var derived := _snapshot()
	audit.check_eq(int(derived.get("pointsPlayed", -1)), 18, "coach/points_played_is_the_two_sides_added")
	audit.check_eq(float(derived.get("averageRally", 0.0)), 32.0 / 9.0, "coach/the_average_rally_is_the_result_screens_own_formula")
	var none := Stats.snapshot({"stats": _stats({"rallyCount": 0, "totalRallyHits": 0, "pointsWon": {"player": 0, "ai": 0}})})
	audit.check_eq(float(none.get("averageRally", -1.0)), 0.0, "coach/no_rally_means_no_average")


func _names(problem: String, problems: Array) -> bool:
	for entry in problems:
		if String(entry) == problem:
			return true
	return false


# ---------------------------------------------------------------------------
# 4. What each category needs before it can be offered
# ---------------------------------------------------------------------------

func _support(audit: AuditBase) -> void:
	var full := _snapshot()
	var offered: Array = full.get("candidates", [])
	var missing: Array = []
	for id in Contract.drill_categories():
		if not offered.has(String(id)):
			missing.append(String(id))
	audit.check_eq(missing, [], "coach/a_full_match_offers_every_category_that_has_evidence")
	audit.check_eq(String(offered[offered.size() - 1]), Contract.INSUFFICIENT, "coach/insufficient_data_is_always_the_last_option")

	var no_serve := _snapshot({"aces": {"player": 0, "ai": 0}, "doubleFaults": {"player": 0, "ai": 0}})
	audit.check_eq(Stats.supported("serve_accuracy", no_serve), false, "coach/a_match_with_no_serve_outcome_cannot_be_about_the_serve")
	audit.check_eq(Stats.supported("serve_accuracy", _snapshot({"aces": {"player": 2, "ai": 0}, "doubleFaults": {"player": 0, "ai": 0}})), true, "coach/two_aces_are_enough_serve_evidence")

	# The return focus reads the OPPONENT's aces and nothing else — the measured count of
	# serves the human side did not return. Zero and "too few to be a pattern" both leave it
	# unoffered; the floor is the declared, conservative one.
	var floor := int(Stats.MIN_OPPONENT_ACES)
	audit.check_eq(Stats.supported("serve_return", _snapshot({"aces": {"player": 6, "ai": 0}})), false, "coach/no_opponent_ace_cannot_be_about_the_return")
	audit.check_eq(Stats.supported("serve_return", _snapshot({"aces": {"player": 0, "ai": floor - 1}})), false, "coach/too_few_opponent_aces_cannot_be_about_the_return")
	audit.check_eq(Stats.supported("serve_return", _snapshot({"aces": {"player": 0, "ai": floor}})), true, "coach/the_declared_opponent_ace_floor_is_enough_return_evidence")
	# The human side's own aces and double faults are the SERVE focus's counters, and they
	# are not evidence about returning: own aces alone leave the return focus unoffered.
	audit.check_eq(
		Stats.supported("serve_return", _snapshot({"aces": {"player": 9, "ai": 0}, "doubleFaults": {"player": 9, "ai": 0}})),
		false,
		"coach/your_own_serve_numbers_are_not_return_evidence"
	)

	audit.check_eq(Stats.supported("rally_consistency", _snapshot({"rallyCount": 3})), false, "coach/a_short_rally_count_cannot_be_about_rallies")
	audit.check_eq(Stats.supported("rally_consistency", _snapshot({"rallyCount": 9})), true, "coach/nine_rallies_are_enough_rally_evidence")
	audit.check_eq(Stats.supported("shot_accuracy", _snapshot({"errors": {"player": 0, "ai": 0}, "winners": {"player": 0, "ai": 0}})), false, "coach/a_match_with_no_ending_event_cannot_be_about_accuracy")
	audit.check_eq(Stats.supported("net_finishing", _snapshot({"winners": {"player": 0, "ai": 0}, "errors": {"player": 0, "ai": 3}})), false, "coach/a_match_with_no_ending_event_cannot_be_about_finishing")
	# Smash winners are neither added to winners nor treated as winners: a match with smashes
	# alone has no winners-to-points ratio to read.
	audit.check_eq(
		Stats.supported("net_finishing", _snapshot({"winners": {"player": 0, "ai": 0}, "errors": {"player": 0, "ai": 0}, "smashWinners": {"player": 4, "ai": 0}})),
		false,
		"coach/smash_winners_are_not_counted_as_winners"
	)
	audit.check_eq(
		Stats.supported("net_finishing", _snapshot({"pointsWon": {"player": 2, "ai": 0}, "winners": {"player": 2, "ai": 0}, "errors": {"player": 2, "ai": 0}})),
		false,
		"coach/too_few_points_won_is_not_a_ratio_to_read"
	)
	audit.check_eq(
		Stats.supported("net_finishing", _snapshot({"winners": {"player": 2, "ai": 0}, "errors": {"player": 1, "ai": 0}})),
		true,
		"coach/three_measured_endings_are_enough_finishing_evidence"
	)

	# The coin-toss guard, at its exact boundary: floors met, exactly one drillable category
	# supported is refused, and exactly two are asked.
	var one_real := _snapshot({"aces": {"player": 0, "ai": 0}, "doubleFaults": {"player": 0, "ai": 0}, "winners": {"player": 0, "ai": 0}, "smashWinners": {"player": 0, "ai": 0}, "errors": {"player": 0, "ai": 0}})
	audit.check_eq(Stats.supported("rally_consistency", one_real), true, "coach/one_real_category_is_still_supported")
	audit.check_eq(bool(one_real.get("sufficient", true)), false, "coach/one_real_category_beside_insufficient_data_is_not_askable")
	audit.check_eq(one_real.get("candidates", []), [Contract.INSUFFICIENT], "coach/and_the_call_is_not_made_at_all")
	audit.check_eq(one_real.get("drillCandidates", []), [], "coach/and_no_drillable_candidate_is_offered")

	# Shot accuracy and rallies have their evidence; the serve has none, and finishing has no
	# winners-to-points-won ratio to read (two points won).
	var two_real := _snapshot({"aces": {"player": 0, "ai": 0}, "doubleFaults": {"player": 0, "ai": 0}, "pointsWon": {"player": 2, "ai": 7}})
	audit.check_eq(Stats.supported("shot_accuracy", two_real), true, "coach/two_real_categories_include_shot_accuracy")
	audit.check_eq(Stats.supported("net_finishing", two_real), false, "coach/and_finishing_has_no_ratio_to_read")
	audit.check_eq(two_real.get("drillCandidates", []).size(), 2, "coach/exactly_two_drillable_candidates_were_offered")
	audit.check_eq(bool(two_real.get("sufficient", false)), true, "coach/and_exactly_two_are_askable")
	audit.check_eq(two_real.get("candidates", []).size(), 3, "coach/with_insufficient_data_as_the_third_option")


# ---------------------------------------------------------------------------
# 5. Advice, drills and the numbers a sentence quotes
# ---------------------------------------------------------------------------

func _drill_ids() -> Array:
	var out: Array = []
	for row in Tables.drill_exercises():
		out.append(String((row as Dictionary).get("id", "")))
	return out


## Every exercise this build can actually play: the reference's four plus the Godot-only
## ones (`Tables.drill_catalog()`). The coach's advice links a DRILL, so the catalog is
## what its ids are checked against.
func _catalog_ids() -> Array:
	var out: Array = []
	for row in Tables.drill_catalog():
		out.append(String((row as Dictionary).get("id", "")))
	return out


func _unique(values: Array) -> Array:
	var out: Array = []
	for value in values:
		if not out.has(value):
			out.append(value)
	return out


func _mapping(audit: AuditBase) -> void:
	var drills := _drill_ids()
	audit.check_eq(drills.size(), 4, "coach/the_frozen_drill_table_has_four_exercises")
	var catalog := _catalog_ids()
	audit.check_eq(catalog.size(), 5, "coach/the_catalog_offers_five_exercises")
	audit.check_true(catalog.has("return"), "coach/the_catalog_carries_the_return_exercise")
	audit.check_eq(Advice.categories().size(), Contract.drill_categories().size(), "coach/there_is_one_advice_per_drillable_category")
	var unmapped: Array = []
	var unknown: Array = []
	var mapped: Array = []
	for id in Contract.drill_categories():
		var drill := String(Advice.drill_id(String(id)))
		if drill == "":
			unmapped.append(String(id))
		elif not catalog.has(drill):
			unknown.append("%s -> %s" % [String(id), drill])
		else:
			mapped.append(drill)
	audit.check_eq(unmapped, [], "coach/no_drillable_category_is_left_without_an_exercise")
	audit.check_eq(unknown, [], "coach/every_advice_links_an_exercise_the_build_can_play")
	audit.check_eq(_unique(mapped).size(), mapped.size(), "coach/two_categories_do_not_share_one_exercise")
	var without_sentence: Array = []
	for id in Contract.drill_categories():
		if not CoachText.has(String(Advice.advice_id(String(id))), "it"):
			without_sentence.append(String(id))
	audit.check_eq(without_sentence, [], "coach/every_category_has_a_sentence")
	var undescribed: Array = []
	for id in mapped:
		# The exercise's own name: the generated locale table for the reference's four, this
		# build's own `drill_strings.json` for the Godot-only ones — the same resolver the
		# drill screen and the coach's exercise line use (`drill_text.gd`).
		if not DrillText.has("drill_%s_name" % String(id), "it") or not DrillText.has("drill_%s_name" % String(id), "en"):
			undescribed.append(String(id))
	audit.check_eq(undescribed, [], "coach/every_linked_exercise_is_named_in_both_tables")

	var snapshot := _snapshot()
	var missing_numbers: Array = []
	var evidence_params := Advice.evidence_params(snapshot)
	for name in CoachText.placeholders(Advice.EVIDENCE_ID, "it"):
		if not evidence_params.has(String(name)):
			missing_numbers.append("evidence needs %s" % String(name))
	for id in Contract.drill_categories():
		var params: Dictionary = Advice.advice_params(String(id), snapshot)
		for name in CoachText.placeholders(String(Advice.advice_id(String(id))), "it"):
			if not params.has(String(name)):
				missing_numbers.append("%s needs %s" % [String(id), String(name)])
	audit.check_eq(missing_numbers, [], "coach/every_sentence_gets_the_numbers_it_quotes")

	var serve_params: Dictionary = Advice.advice_params("serve_accuracy", snapshot)
	audit.check_eq(int(serve_params.get("doubleFaults", -1)), 3, "coach/the_serve_sentence_quotes_the_measured_double_faults")
	audit.check_eq(int(serve_params.get("aces", -1)), 2, "coach/the_serve_sentence_quotes_the_measured_aces")
	var return_params: Dictionary = Advice.advice_params("serve_return", snapshot)
	audit.check_eq(int(return_params.get("opponentAces", -1)), 4, "coach/the_return_sentence_quotes_the_measured_opponent_aces")
	audit.check_eq(return_params.size(), 1, "coach/the_return_sentence_quotes_only_the_opponent_aces")
	audit.check_eq(return_params.has("aces"), false, "coach/the_return_sentence_never_quotes_your_own_aces")
	audit.check_eq(int((Advice.advice_params("net_finishing", snapshot) as Dictionary).get("pointsWon", -1)), 11, "coach/the_finishing_sentence_quotes_the_points_won")
	audit.check_eq((Advice.advice_params("net_finishing", snapshot) as Dictionary).has("smashWinners"), false, "coach/the_finishing_sentence_never_adds_smash_winners_to_winners")
	audit.check_eq((Advice.advice_params("shot_accuracy", snapshot) as Dictionary).has("smashWinners"), false, "coach/the_accuracy_sentence_never_adds_smash_winners_to_winners")
	audit.check_eq(String((Advice.advice_params("rally_consistency", snapshot) as Dictionary).get("averageRally", "")), "3.6", "coach/the_rally_sentence_quotes_the_average_as_the_screen_does")
	audit.check_eq(int(evidence_params.get("errors", -1)), 4, "coach/the_evidence_line_quotes_the_measured_errors")


# ---------------------------------------------------------------------------
# 6. What an answer may become
# ---------------------------------------------------------------------------

## A transport report carrying one well-formed Choice. `peak` is the probability the
## chosen option holds, so the rest of the distribution is spread over the others.
func _reply(choice: String, offered: Array, confidence: float, peak := 0.8) -> Dictionary:
	var rest := (1.0 - peak) / float(maxi(offered.size() - 1, 1))
	var probabilities := {}
	for id in offered:
		probabilities[String(id)] = peak if String(id) == choice else rest
	return {
		"status": "ok",
		"body": {"type": "choice", "choice": choice, "confidence": confidence, "probabilities": probabilities},
	}


func _answers(audit: AuditBase) -> void:
	var snapshot := _snapshot()
	var offered: Array = snapshot.get("candidates", [])
	var strong := Advice.evaluate(snapshot, _reply("serve_accuracy", offered, 0.8))
	audit.check_eq(String(strong.get("state", "")), Advice.STATE_ADVICE, "coach/a_confident_choice_becomes_advice")
	audit.check_eq(String(strong.get("advice_id", "")), "coachAdviceServe", "coach/the_advice_sentence_is_the_serves_own")
	audit.check_eq(String(strong.get("drill_id", "")), "serve", "coach/the_advice_links_the_serve_exercise")
	var probabilities: Dictionary = strong.get("probabilities", {})
	audit.check_eq(probabilities.size(), offered.size(), "coach/the_validated_distribution_is_kept")

	# The return focus end to end: a confident, valid answer becomes measured advice that
	# quotes the opponent's aces and links the fifth exercise, and an answer under the gate
	# says nothing about the return.
	var return_strong := Advice.evaluate(snapshot, _reply("serve_return", offered, 0.8))
	audit.check_eq(String(return_strong.get("state", "")), Advice.STATE_ADVICE, "coach/a_confident_return_choice_becomes_advice")
	audit.check_eq(String(return_strong.get("advice_id", "")), "coachAdviceReturn", "coach/the_return_sentence_is_the_returns_own")
	audit.check_eq(String(return_strong.get("drill_id", "")), "return", "coach/the_return_advice_links_the_return_exercise")
	var return_params: Dictionary = return_strong.get("advice_params", {})
	audit.check_eq(int(return_params.get("opponentAces", -1)), 4, "coach/and_quotes_the_measured_opponent_aces")

	var return_weak := Advice.evaluate(snapshot, _reply("serve_return", offered, 0.3))
	audit.check_eq(String(return_weak.get("state", "")), Advice.STATE_UNCERTAIN, "coach/an_under_gate_return_choice_is_uncertain")
	audit.check_eq(String(return_weak.get("drill_id", "")), "", "coach/an_uncertain_return_reading_offers_no_exercise")
	audit.check_eq(String(return_weak.get("advice_id", "")), "", "coach/an_uncertain_return_reading_shows_no_advice")

	# A fixture of an opponent-ace-heavy match whose ONLY measured evidence is the return
	# focus: rallies alone are kept off the call so this is the coin-toss guard's other side
	# — exactly two drillable candidates (the return focus among them) and the call is made.
	var offerable := _snapshot({
		"aces": {"player": 0, "ai": 5},
		"doubleFaults": {"player": 0, "ai": 0},
		"winners": {"player": 0, "ai": 0},
		"smashWinners": {"player": 0, "ai": 0},
		"errors": {"player": 0, "ai": 0},
	})
	var narrowed: Array = offerable.get("candidates", [])
	audit.check_true(narrowed.has("serve_return"), "coach/an_opponent_ace_heavy_fixture_offers_the_return_focus")
	audit.check_eq(bool(offerable.get("sufficient", false)), true, "coach/and_the_call_is_still_askable")

	var weak := Advice.evaluate(snapshot, _reply("serve_accuracy", offered, 0.3))
	audit.check_eq(String(weak.get("state", "")), Advice.STATE_UNCERTAIN, "coach/a_choice_under_the_gate_is_uncertain")
	audit.check_eq(String(weak.get("advice_id", "")), "", "coach/an_uncertain_reading_shows_no_advice")
	audit.check_eq(String(weak.get("drill_id", "")), "", "coach/an_uncertain_reading_offers_no_exercise")
	audit.check_eq(int((weak.get("evidence_params", {}) as Dictionary).get("errors", -1)), 4, "coach/an_uncertain_reading_still_shows_the_numbers")

	var refuses := Advice.evaluate(snapshot, _reply(Contract.INSUFFICIENT, offered, 0.9))
	audit.check_eq(String(refuses.get("state", "")), Advice.STATE_INSUFFICIENT, "coach/the_models_own_insufficient_data_is_insufficient")
	audit.check_eq(String(refuses.get("drill_id", "")), "", "coach/and_offers_no_exercise")

	# A tie at the peak is still a peak: the answer is accepted (here as an uncertain reading,
	# because its confidence is under the gate), not refused as inconsistent.
	var tied := {
		"status": "ok",
		"body": {
			"type": "choice",
			"choice": "serve_accuracy",
			"confidence": 0.3,
			"probabilities": {
				"serve_accuracy": 0.4,
				"shot_accuracy": 0.4,
				"rally_consistency": 0.1,
				"net_finishing": 0.025,
				"serve_return": 0.025,
				"insufficient_data": 0.05,
			},
		},
	}
	audit.check_eq(String(Advice.evaluate(snapshot, tied).get("state", "")), Advice.STATE_UNCERTAIN, "coach/a_tie_for_the_peak_is_accepted")

	var thin := Stats.snapshot({"stats": _stats({"pointsWon": {"player": 1, "ai": 1}})})
	var thin_record := Advice.evaluate(thin, _reply("serve_accuracy", [Contract.INSUFFICIENT], 0.9))
	audit.check_eq(String(thin_record.get("state", "")), Advice.STATE_INSUFFICIENT, "coach/a_match_without_evidence_is_insufficient")
	audit.check_eq(String(thin_record.get("detail", "")), "the match did not measure enough to ask about", "coach/and_says_so_without_asking")

	var trusted := _reply("serve_accuracy", offered, 0.8)
	var refused: Dictionary = {}
	var no_type := trusted.duplicate(true)
	(no_type["body"] as Dictionary)["type"] = "noul"
	refused["a_noul_in_place_of_a_choice"] = no_type
	var unoffered := trusted.duplicate(true)
	(unoffered["body"] as Dictionary)["choice"] = "win_more"
	refused["an_unoffered_category"] = unoffered
	var over := trusted.duplicate(true)
	(over["body"] as Dictionary)["confidence"] = 1.4
	refused["a_confidence_over_one"] = over
	var no_distribution := trusted.duplicate(true)
	(no_distribution["body"] as Dictionary).erase("probabilities")
	refused["no_distribution"] = no_distribution
	var short_distribution := trusted.duplicate(true)
	((short_distribution["body"] as Dictionary)["probabilities"] as Dictionary).erase("serve_accuracy")
	refused["a_distribution_missing_a_category"] = short_distribution
	var unnormalized := trusted.duplicate(true)
	((unnormalized["body"] as Dictionary)["probabilities"] as Dictionary)["serve_accuracy"] = 0.1
	refused["a_distribution_that_is_not_one"] = unnormalized
	var extra_category := trusted.duplicate(true)
	((extra_category["body"] as Dictionary)["probabilities"] as Dictionary)["win_more"] = 0.0
	refused["a_category_that_was_never_offered"] = extra_category
	var not_the_peak := trusted.duplicate(true)
	((not_the_peak["body"] as Dictionary)["probabilities"] as Dictionary)["serve_accuracy"] = 0.1
	((not_the_peak["body"] as Dictionary)["probabilities"] as Dictionary)["shot_accuracy"] = 0.6
	refused["a_choice_that_is_not_the_most_probable"] = not_the_peak
	for name in refused.keys():
		var record := Advice.evaluate(snapshot, refused[name])
		audit.check_eq(String(record.get("state", "")), Advice.STATE_INVALID, "coach/%s_is_refused" % String(name))
		audit.check_eq(String(record.get("drill_id", "")), "", "coach/%s_offers_no_exercise" % String(name))
		audit.check_eq(int((record.get("evidence_params", {}) as Dictionary).get("winners", -1)), 5, "coach/%s_still_shows_the_matches_numbers" % String(name))

	for status in ["timeout", "unreachable", "error", "too_large"]:
		var record := Advice.evaluate(snapshot, {"status": String(status)})
		audit.check_eq(String(record.get("state", "")), Advice.STATE_UNAVAILABLE, "coach/a_%s_transport_is_unavailable" % String(status))
		audit.check_eq(String(record.get("advice_id", "")), "", "coach/a_%s_transport_claims_nothing" % String(status))
	audit.check_eq(String(Advice.evaluate(snapshot, {"status": "invalid"}).get("state", "")), Advice.STATE_INVALID, "coach/an_invalid_bridge_answer_is_refused")


# ---------------------------------------------------------------------------
# 7. The live path: a match the simulation itself stepped
# ---------------------------------------------------------------------------

func _live(audit: AuditBase) -> void:
	# The career's points format: the same live path, and a match that reaches a result
	# (`godot/tests/ui/screen_result_audit.gd::_live` uses the same three lines).
	var state = Sim.create_match_state("career", Config.athlete(), Config.arena(), Config.tier())
	state.scoring = "points"
	state.pointsToWin = CareerRules.career_points_to_win()
	state.rng_state = SEED
	state.running = true
	var bot := ScriptedPlayer.new()
	var spent := 0
	while spent < LIVE_TICKS and state.result == null:
		Sim.update_match(state, TICK, bot.decide(state), Sim.empty_input())
		spent += 1
	audit.check_gt(float(state.elapsed), 10.0, "coach/the_sampled_match_ran_for_real_simulated_seconds")
	audit.check_true(state.result != null, "coach/the_sampled_match_reached_its_own_result")
	var won := state.result != null and String((state.result as Dictionary).get("winner", "")) == "player"

	var payload: Dictionary = ScreenClass.payload_from_state(state, {"won": won, "mode": "career"})
	var snapshot := Stats.snapshot(payload.get("result", {}))
	var counters: Dictionary = snapshot.get("counters", {})
	var measured: Array = []
	for group in Contract.group_names():
		for side in Contract.group_sides(String(group)):
			var expected := int((state.stats.get(String(group), {}) as Dictionary).get(String(side), 0))
			var shown := int((counters.get(String(group), {}) as Dictionary).get(String(side), -1))
			if expected != shown:
				measured.append("%s.%s: state %d, coach %d" % [String(group), String(side), expected, shown])
	for name in Contract.counter_names():
		var expected := int(state.stats.get(String(name), 0))
		var shown := int(counters.get(String(name), -1))
		if expected != shown:
			measured.append("%s: state %d, coach %d" % [String(name), expected, shown])
	audit.check_eq(measured, [], "coach/every_counter_the_coach_would_send_is_the_states_own")
	audit.check_eq(snapshot.get("blockers", []), [], "coach/a_stepped_match_carries_no_blocking_counter")
	audit.report("live counters: %s points=%d rallies=%d average=%.1f candidates=%s" % [
		str(counters),
		int(snapshot.get("pointsPlayed", 0)),
		int(counters.get("rallyCount", 0)),
		float(snapshot.get("averageRally", 0.0)),
		str(snapshot.get("candidates", [])),
	])
	audit.check_eq(int(snapshot.get("pointsPlayed", -1)), int(state.stats.get("pointsWon", {}).get("player", 0)) + int(state.stats.get("pointsWon", {}).get("ai", 0)), "coach/the_live_points_played_are_the_states_own")
	audit.check_eq(float(snapshot.get("averageRally", -1.0)), float(state.stats.get("totalRallyHits", 0)) / float(state.stats.get("rallyCount", 1)), "coach/the_live_average_is_the_states_own")

	var offered: Array = snapshot.get("candidates", [])
	var outside: Array = []
	for id in offered:
		if not Contract.category_ids().has(String(id)):
			outside.append(String(id))
	audit.check_eq(outside, [], "coach/no_candidate_outside_the_contract_was_offered")
	var confused: Array = []
	for id in Contract.drill_categories():
		if offered.has(String(id)) and not Stats.supported(String(id), snapshot):
			confused.append(String(id))
	audit.check_eq(confused, [], "coach/no_candidate_was_offered_without_its_own_evidence")

	# The verdict and the offer agree, in whichever direction this match measured: a match
	# the side ended rarely really is one the coach refuses to advise on, and the refusal is
	# the offer's own shape rather than a second rule.
	var askable := bool(snapshot.get("sufficient", false))
	audit.check_eq(askable, offered.size() > 1, "coach/the_live_offer_matches_the_live_verdict")
	var choice := String(offered[0])
	var record := Advice.evaluate(snapshot, _reply(choice, offered, 0.8))
	if askable:
		audit.check_ge(offered.size(), int(Contract.sufficiency().get("minCandidates", 3)), "coach/a_live_call_offers_at_least_the_declared_minimum")
		audit.check_eq(String(record.get("state", "")), Advice.STATE_ADVICE, "coach/a_confident_choice_over_the_live_candidates_is_advice")
		audit.check_eq(_drill_ids().has(String(record.get("drill_id", ""))), true, "coach/the_live_advice_links_an_exercise_that_exists")
		audit.check_true(CoachText.has(String(record.get("advice_id", "")), "it"), "coach/the_live_advice_has_a_sentence")
		var params: Dictionary = record.get("advice_params", {})
		var quoted: Array = []
		for name in CoachText.placeholders(String(record.get("advice_id", "")), "it"):
			if not params.has(String(name)):
				quoted.append(String(name))
		audit.check_eq(quoted, [], "coach/the_live_sentence_has_every_number_it_quotes")
	else:
		audit.check_eq(String(record.get("state", "")), Advice.STATE_INSUFFICIENT, "coach/a_live_match_without_enough_evidence_is_answered_without_a_call")
		audit.check_eq(offered, [Contract.INSUFFICIENT], "coach/and_offers_only_insufficient_data")
	audit.report("live points match: %d ticks, candidates %s, verdict %s, first route %s -> %s" % [
		spent, str(offered), "ask" if askable else "insufficient", choice, String(record.get("drill_id", "")),
	])
