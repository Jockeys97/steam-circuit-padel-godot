## career_audit.gd — the port of `scripts/career-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/career_audit.gd
##
## Same promises as the reference audit:
##
##   `scripts/career-audit.mjs:36-107`  every objective of twelve seasons is
##                                      achievable inside its own ceiling — and a
##                                      `max` objective is not a free star;
##   `:109-116`                         every declared objective appears in twelve
##                                      seasons (one that never does is dead code);
##   `:118-135`                         every metric has an aggregation rule, the
##                                      rule lives in `SEASON_METRIC_AGG` only, and
##                                      every aggregated metric is read by an
##                                      objective;
##   `:183-203`                         repeating a season pays its three season
##                                      stars ONCE while advancing pays more;
##   `:205-235`                         the AI ramp never exceeds its three caps,
##                                      never falls inside a season nor between
##                                      seasons, and its speed cap stays within 60
##                                      of the Legend;
##   `:237-249`                         every AI tier is a rung of the circuit and
##                                      the final season does not come before the
##                                      last rival;
##   `:251-266`                         the season calendar changes court inside a
##                                      season, survives one available arena, and
##                                      falls back to the full list when none is.
##
## Two differences from the reference, both stated rather than hidden:
##
##   1. The reference's `simulateCareer` (`:140-181`) re-implements the star
##      machine locally. This port drives the SHIPPED code instead
##      (`CareerProgress.award_objectives` + `apply_career_match`), so the two
##      numbers the reference asserts — `30 + 3` and "advancing pays more" — are
##      asserted against the module the game actually uses.
##   2. The ceilings in `MATCH_CAP` / `SEASON_METRIC_AGG` are read from the
##      generated table (`mode_tables.gd`), and the season count from
##      `CAREER_MATCHES`, so a retuned reference moves this audit with it.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

## `const SEASONS = 12` (`scripts/career-audit.mjs:36`).
const SEASONS := 12
## `const CYCLES = 10` (`scripts/career-audit.mjs:183`).
const CYCLES := 10


func _initialize() -> void:
	var audit := AuditBase.new("career")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var point_cap_match: int = CareerRules.career_points_to_win()
	var point_cap_season: int = point_cap_match * CareerRules.career_matches()
	var match_cap := {
		"pointsWon": point_cap_match,
		"winners": point_cap_match,
		"smashWinners": point_cap_match,
		# Gli errori e i doppi falli del giocatore sono limitati dai punti che
		# l'avversario puo' vincere, non dai propri.
		"errors": point_cap_match,
		"doubleFaults": point_cap_match,
		# Un rally non ha tetto strutturale.
		"longestRally": INF,
	}

	# ── 1. Ogni obiettivo deve essere raggiungibile ─────────────────────────
	var season_detail: Array = []
	for season in range(1, SEASONS + 1):
		var detail: Array = []
		for objective in CareerRules.season_objectives(season):
			var def_id := String(objective["id"])
			var definition: Dictionary = CareerRules.objective_defs()[def_id]
			var cap := _season_cap(match_cap, String(definition["metric"]))
			var target := int(objective["target"])
			if String(definition["unit"]) == "max":
				# Un obiettivo "max" con target al tetto e' soddisfatto sempre.
				audit.check_ge(target, 0, "career/season_%d/%s/target_not_negative" % [season, def_id])
				audit.check_lt(target, cap, "career/season_%d/%s/max_below_the_ceiling" % [season, def_id])
			else:
				audit.check_le(target, cap, "career/season_%d/%s/target_within_the_ceiling" % [season, def_id])
			detail.append("%s=%d/%s" % [def_id, target, "inf" if cap == INF else str(cap)])
		season_detail.append("s%d:%s" % [season, " ".join(detail)])

		for match_index in range(0, CareerRules.career_matches()):
			var match_obj := CareerRules.match_objective(season, match_index)
			var def_id := String(match_obj["id"])
			var definition: Dictionary = CareerRules.objective_defs()[def_id]
			var cap: float = float(match_cap[String(definition["metric"])])
			var target := int(match_obj["target"])
			var ok: bool = (target >= 0 and float(target) < cap) if String(definition["unit"]) == "max" else float(target) <= cap
			audit.check_true(ok, "career/season_%d/match_%d/bonus_%s_ceilings" % [season, match_index + 1, def_id])

	# Ogni obiettivo del pool deve comparire: uno che non esce mai e' codice morto.
	var seen: Dictionary = {}
	for season in range(1, SEASONS + 1):
		for objective in CareerRules.season_objectives(season):
			seen[String(objective["id"])] = true
	for def_id in CareerRules.objective_defs():
		audit.check_true(seen.has(String(def_id)), "career/objective_%s_appears_in_twelve_seasons" % String(def_id))

	# Ogni metrica deve avere una regola di aggregazione, e averla in UN posto solo.
	var agg: Dictionary = CareerRules.season_metric_agg()
	var used_metrics: Dictionary = {}
	for def_id in CareerRules.objective_defs():
		var definition: Dictionary = CareerRules.objective_defs()[def_id]
		audit.check_true(agg.has(String(definition["metric"])), "career/metric_of_%s_has_an_aggregation_rule" % String(def_id))
		# `assert(def.agg === undefined)` (`scripts/career-audit.mjs:124-127`).
		audit.check_true(not definition.has("agg"), "career/%s_does_not_declare_its_own_agg" % String(def_id))
		used_metrics[String(definition["metric"])] = true
	for metric in agg:
		audit.check_true(used_metrics.has(String(metric)), "career/metric_%s_is_read_by_an_objective" % String(metric))

	# ── 2. Le stelle non si possono farmare ────────────────────────────────
	var farmer := simulate_career(1, CYCLES)
	var climber := simulate_career(CareerRules.career_matches(), CYCLES)

	# Ripetendo la stessa stagione le stelle di stagione si prendono una volta
	# sola: resta solo il bonus di match, una stella per partita.
	var solo_bonus: int = CYCLES * CareerRules.career_matches()
	audit.check_eq(
		int(farmer["stars"]), solo_bonus + 3,
		"career/repeating_a_season_pays_%d_bonus_plus_3" % solo_bonus,
	)
	audit.check_gt(int(climber["stars"]), int(farmer["stars"]), "career/advancing_pays_more_than_staying")
	audit.check_eq(int(farmer["season"]), 1, "career/farmer_never_leaves_season_1")
	audit.check_eq(int(climber["season"]), 1 + CYCLES, "career/climber_advances_one_season_per_cycle")
	audit.check_eq(int(farmer["trophies"]), 0, "career/farmer_wins_no_trophy")
	audit.check_eq(int(climber["trophies"]), CYCLES, "career/climber_wins_every_trophy")

	# ── 3. La rampa ha un tetto ────────────────────────────────────────────
	var ramp: Dictionary = CareerRules.career_ramp()
	var previous: Dictionary = {}
	for season in [1, 2, 3, 4, 5, 8, 12, 20, 40, 120]:
		var first := CareerRules.career_ai_profile(season, 0)
		var last := CareerRules.career_ai_profile(season, CareerRules.career_matches() - 1)
		audit.check_le(float(last["skill"]), float(ramp["skillCap"]) + 1e-9, "career/season_%d/skill_within_cap" % season)
		audit.check_le(float(last["speed"]), float(ramp["speedCap"]) + 1e-9, "career/season_%d/speed_within_cap" % season)
		audit.check_le(float(last["power"]), float(ramp["powerCap"]) + 1e-9, "career/season_%d/power_within_cap" % season)
		audit.check_ge(float(last["skill"]), float(first["skill"]), "career/season_%d/skill_does_not_fall_inside" % season)
		if not previous.is_empty():
			audit.check_ge(float(last["skill"]), float(previous["skill"]), "career/season_%d_skill_not_easier_than_%d" % [season, int(previous["season"])])
			audit.check_ge(float(last["speed"]), float(previous["speed"]), "career/season_%d_speed_not_easier_than_%d" % [season, int(previous["season"])])
		previous = last.duplicate()
		previous["season"] = season

	# La velocita' non deve superare di troppo il gradino piu' duro dichiarato.
	var opponents: Array = Frozen.ai_opponents()
	var speed_leggenda: float = float(opponents[opponents.size() - 1]["speed"])
	audit.check_le(
		float(ramp["speedCap"]) - speed_leggenda, 60.0,
		"career/speed_cap_within_60_of_the_legend",
	)

	# ── 4. Il circuito ha un rivale per gradino e una fine ─────────────────
	var rivals: Dictionary = {}
	for season in range(1, SEASONS + 1):
		rivals[String(CareerRules.career_rival(season)["id"])] = true
	audit.check_eq(rivals.size(), opponents.size(), "career/every_ai_tier_is_a_rung_of_the_circuit")
	audit.check_ge(
		CareerRules.career_final_season(), opponents.size(),
		"career/final_season_not_before_the_last_rival",
	)

	# ── 5. Il calendario cambia arena dentro la stagione ───────────────────
	var arenas: Array = Frozen.arenas()
	for season in range(1, SEASONS + 1):
		var courts: Dictionary = {}
		for match_index in range(0, CareerRules.career_matches()):
			courts[String(CareerRules.career_fixture(season, match_index).get("arena", {}).get("id", ""))] = true
		audit.check_eq(
			courts.size(), mini(CareerRules.career_matches(), arenas.size()),
			"career/season_%d_calendar_does_not_repeat_a_court" % season,
		)
	# Con una sola arena sbloccata il calendario deve reggere.
	var one_arena := CareerRules.career_fixture(3, 1, [arenas[0]])
	audit.check_eq(String(Dictionary(one_arena["arena"])["id"]), String(arenas[0]["id"]), "career/one_arena_calendar_uses_it")
	audit.check_eq(
		String(Dictionary(CareerRules.career_fixture(3, 1, [])["arena"])["id"]),
		String(Dictionary(CareerRules.career_fixture(3, 1, arenas)["arena"])["id"]),
		"career/empty_arena_list_falls_back_to_all",
	)

	# ── 6. Il bonus di match e la stella di stagione arrivano dal modulo ───
	# The season objective the reference audit only models, evaluated through
	# `CareerProgress.award_objectives`: a perfect match pays the bonus, the three
	# season stars are paid once per season and never twice.
	var career := CareerProgress.empty_career()
	var first_award := CareerProgress.award_objectives(career, perfect_stats())
	audit.check_eq(int(first_award["stars"]), 4, "career/perfect_match_pays_bonus_plus_three_season_stars")
	audit.check_true(bool(first_award["matchDone"]), "career/perfect_match_pays_the_bonus")
	audit.check_eq((first_award["seasonDone"] as Array).size(), 3, "career/perfect_match_pays_three_season_objectives")
	var second_award := CareerProgress.award_objectives(career, perfect_stats())
	audit.check_eq(int(second_award["stars"]), 1, "career/replayed_match_pays_only_the_bonus")
	audit.check_eq((second_award["seasonDone"] as Array).size(), 0, "career/claimed_objectives_are_not_paid_twice")
	audit.check_eq(int(career["stars"]), 5, "career/stars_are_the_sum_of_the_two_awards")

	# A season lost on the third match repeats, and the objectives already paid
	# stay paid (`js/main.js:1461-1464`).
	var repeat_career := CareerProgress.empty_career()
	var last_outcome: Dictionary = {}
	for i in range(0, 3):
		CareerProgress.award_objectives(repeat_career, perfect_stats())
		last_outcome = CareerProgress.apply_career_match(repeat_career, i == 0)
		if i < 2:
			audit.check_eq(String(last_outcome["outcome"]), "", "career/season_still_running_after_match_%d" % (i + 1))
	audit.check_eq(String(last_outcome["outcome"]), "repeat", "career/lost_season_repeats")
	audit.check_eq(int(repeat_career["season"]), 1, "career/repeat_keeps_the_season")

	# ── 7. I quattro esiti di stagione (`js/main.js:1454-1464`) ────────────
	# `trophy`: three wins, not the final season.
	var trophy_career := CareerProgress.empty_career()
	var trophy_outcome := _play_season(trophy_career, 3)
	audit.check_eq(String(trophy_outcome["outcome"]), "trophy", "career/three_wins_pay_a_trophy")
	audit.check_eq(int(trophy_career["season"]), 2, "career/trophy_advances_the_season")
	audit.check_eq(int(trophy_career["trophies"]), 1, "career/trophy_increments_the_trophy_count")
	audit.check_true(bool(trophy_outcome["seasonWon"]), "career/trophy_flags_the_season_as_won")

	# `promoted`: two wins, no trophy.
	var promoted_career := CareerProgress.empty_career()
	var promoted_outcome := _play_season(promoted_career, 2)
	audit.check_eq(String(promoted_outcome["outcome"]), "promoted", "career/two_wins_promote")
	audit.check_eq(int(promoted_career["season"]), 2, "career/promotion_advances_the_season")
	audit.check_eq(int(promoted_career["trophies"]), 0, "career/promotion_pays_no_trophy")

	# `finale`: the final season won, seen once.
	var finale_career := CareerProgress.empty_career()
	finale_career["season"] = CareerRules.career_final_season()
	var finale_outcome := _play_season(finale_career, 3)
	audit.check_eq(String(finale_outcome["outcome"]), "finale", "career/final_season_won_is_the_finale")
	audit.check_true(bool(finale_career["finaleSeen"]), "career/finale_is_marked_as_seen")
	audit.check_eq(int(finale_career["season"]), CareerRules.career_final_season() + 1, "career/finale_advances_past_the_final_season")
	audit.check_eq(
		int(finale_career["bestSeason"]), CareerRules.career_final_season() + 1,
		"career/best_season_follows_the_finale",
	)
	# Winning the next season again is a trophy, not a second finale.
	var after_finale := _play_season(finale_career, 3)
	audit.check_eq(String(after_finale["outcome"]), "trophy", "career/finale_is_seen_once")

	# The history entry's trophy flag is computed BEFORE the season advances.
	var flag_career := CareerProgress.empty_career()
	flag_career["seasonWins"] = 2
	flag_career["matchIndex"] = 2
	audit.check_true(CareerProgress.pre_match_trophy(flag_career, "career", true, 0), "career/third_win_is_a_career_trophy")
	audit.check_true(not CareerProgress.pre_match_trophy(flag_career, "career", false, 0), "career/lost_third_match_is_no_trophy")
	audit.check_true(CareerProgress.pre_match_trophy(CareerProgress.empty_career(), "tournament", true, 2), "career/tournament_final_is_a_trophy")
	audit.check_true(not CareerProgress.pre_match_trophy(CareerProgress.empty_career(), "tournament", true, 1), "career/tournament_semi_is_no_trophy")
	audit.check_true(not CareerProgress.pre_match_trophy(CareerProgress.empty_career(), "quick", true, 0), "career/quick_match_is_no_trophy")

	# An outfit challenge won through the shipped award path, and only once.
	var outfit_career := CareerProgress.empty_career()
	var won_now := CareerProgress.award_outfit_challenges(outfit_career, "maestro", perfect_stats(), true, 0.95)
	audit.check_ge(won_now.size(), 1, "career/perfect_win_wins_at_least_one_outfit")
	audit.check_true(bool(outfit_career["outfitsWon"].get("maestro:circuit", false)), "career/the_first_rung_outfit_is_unlocked")
	var won_again := CareerProgress.award_outfit_challenges(outfit_career, "maestro", perfect_stats(), true, 0.95)
	audit.check_eq(won_again.size(), 0, "career/an_outfit_is_never_won_twice")
	audit.check_eq(int(outfit_career["athleteWins"]["maestro"]), 2, "career/athlete_wins_are_counted")

	# ── 8. La firma degli obiettivi (`js/ui.js:58-83`) ─────────────────────
	# The signature is what decides whether a stored triple is regenerated: it is
	# compared, so it has to be the reference's own string.
	var sig_career := CareerProgress.empty_career()
	CareerProgress.ensure_season_objectives(sig_career)
	audit.check_eq(
		CareerProgress.objectives_signature(sig_career["seasonObjectives"]),
		"smashWins:4|winners:10|winRally:10",
		"career/objectives_signature_matches_the_reference_triple",
	)
	# A stored triple that no longer matches the season is regenerated, and the
	# season stars restart with it (`js/ui.js:72-80`).
	sig_career["seasonObjectives"] = [{"id": "winners", "target": 99}]
	sig_career["seasonStars"] = 7
	CareerProgress.ensure_season_objectives(sig_career)
	audit.check_eq((sig_career["seasonObjectives"] as Array).size(), 3, "career/a_retuned_triple_is_regenerated")
	audit.check_eq(int(sig_career["seasonStars"]), 0, "career/regeneration_restarts_the_season_stars")
	# …and a matching triple is left alone, which is what keeps `seasonStars`
	# accumulating across the three matches of a season.
	sig_career["seasonStars"] = 5
	CareerProgress.ensure_season_objectives(sig_career)
	audit.check_eq(int(sig_career["seasonStars"]), 5, "career/a_matching_triple_is_not_regenerated")
	# Stars already claimed survive a regeneration, or retuning would pay twice.
	var claimed_career := CareerProgress.empty_career()
	claimed_career["claimedObjectives"] = {"1": ["winners"]}
	CareerProgress.ensure_season_objectives(claimed_career)
	var claimed_flags := 0
	for objective in claimed_career["seasonObjectives"]:
		if bool(Dictionary(objective).get("claimed", false)):
			claimed_flags += 1
	audit.check_eq(claimed_flags, 1, "career/claimed_flags_survive_a_regeneration")

	audit.report("seasons=%d" % SEASONS)
	for line in season_detail:
		audit.report(line)


## `seasonCap(metric)` (`scripts/career-audit.mjs:60-64`): a `max` metric is
## capped by one match, a summing one by the whole season.
static func _season_cap(match_cap: Dictionary, metric: String) -> float:
	var cap: float = float(match_cap[metric])
	if cap == INF:
		return INF
	return cap if String(CareerRules.season_metric_agg()[metric]) == "max" else cap * float(CareerRules.career_matches())


## A match whose stats meet every objective the reference's pool declares, so the
## star arithmetic is exercised through the shipped awards rather than modelled.
##
## `winners` 10 and `smashWinners` 4 are one point-cap of winners per match, and
## the season totals (`3 x`) clear the largest targets the pool reaches
## (`winners` 16, `smashWinners` 10, `winRally` 16, `winPoints` 30). `errors` and
## `doubleFaults` are 0, which satisfies the two `max` objectives for every season
## (`noDoubleFault` 0 and `fewErrors` >= 3).
static func perfect_stats() -> Dictionary:
	return {
		"pointsWon": {"player": CareerRules.career_points_to_win(), "ai": 0},
		"winners": {"player": 10, "ai": 0},
		"smashWinners": {"player": 4, "ai": 0},
		"errors": {"player": 0, "ai": 0},
		"doubleFaults": {"player": 0, "ai": 0},
		"longestRally": 40,
		"totalRallyHits": 300,
	}


## The reference's `simulateCareer` (`scripts/career-audit.mjs:140-181`), driving
## the shipped progression: every objective is met (the stats are perfect) and
## only `winsPerSeason` of the three matches are won.
static func simulate_career(wins_per_season: int, cycles: int) -> Dictionary:
	var career := CareerProgress.empty_career()
	for cycle in range(0, cycles):
		for match_index in range(0, CareerRules.career_matches()):
			CareerProgress.award_objectives(career, perfect_stats())
			CareerProgress.apply_career_match(career, match_index < wins_per_season)
	return career


## One season of three matches with `wins` of them won, returning the outcome the
## third match produced (`js/main.js:1454-1464`).
static func _play_season(career: Dictionary, wins: int) -> Dictionary:
	var outcome: Dictionary = {}
	for match_index in range(0, CareerRules.career_matches()):
		CareerProgress.award_objectives(career, perfect_stats())
		outcome = CareerProgress.apply_career_match(career, match_index < wins)
	return outcome
