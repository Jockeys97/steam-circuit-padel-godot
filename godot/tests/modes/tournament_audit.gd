## tournament_audit.gd — the port of `scripts/tournament-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/tournament_audit.gd
##
## Same promises, same cases, same constants as the reference audit:
##
##   `scripts/tournament-audit.mjs:26-27`  three distinct courts with the whole
##                                         `ARENAS` table available;
##   `:29-32`                              prestige non-decreasing round by round;
##   `:34-37`                              the final is the most prestigious court;
##   `:41-51`                              the degradation sweep: 1, 2 and 3
##                                         available arenas, every round inside
##                                         the pool, `min(quante, 3)` distinct;
##   `:55-57`                              an empty availability list falls back to
##                                         the whole table (`selectableArenas` can
##                                         filter everything out in the demo);
##   `:61-64`                              out-of-range rounds (3, 4, 10) still
##                                         resolve to a real court;
##   `:70-75`                              a tournament AI tier per round, rising.
##
## Port-only additions, printed after the ported ones: the round advance
## (`js/main.js:1479-1490`) and the trophy round (`js/main.js:1398`) — the
## progression the reference audit does not touch because it lives in `main.js`,
## not in the fixture resolver.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const TournamentRules := preload("res://src/modes/tournament_rules.gd")

## `const TURNI = 3` (`scripts/tournament-audit.mjs:20`).
const ROUNDS := 3


func _initialize() -> void:
	var audit := AuditBase.new("tournament")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var arenas: Array = Frozen.arenas()

	# --- il tabellone viaggia e sale ------------------------------------------
	var path: Array = []
	for round in range(0, ROUNDS):
		path.append(TournamentRules.fixture(round, arenas)["arena"])

	var ids: Array = []
	for arena in path:
		ids.append(String(arena["id"]))
	audit.check_eq(_distinct(ids).size(), ROUNDS, "tournament/three_rounds_in_distinct_courts")

	for turno in range(1, ROUNDS):
		audit.check_ge(
			TournamentRules.prestigio(path[turno]), TournamentRules.prestigio(path[turno - 1]),
			"tournament/round_%d_at_least_as_prestigious" % (turno + 1),
		)

	var final: Dictionary = path[ROUNDS - 1]
	var maximum := -1
	for arena in arenas:
		maximum = maxi(maximum, TournamentRules.prestigio(arena))
	audit.check_eq(TournamentRules.prestigio(final), maximum, "tournament/final_in_the_most_prestigious_court")

	# --- i casi limite: poche arene, o una sola --------------------------------
	for quante in [1, 2, 3]:
		var pool: Array = arenas.slice(0, quante)
		var used: Array = []
		for round in range(0, ROUNDS):
			var arena: Dictionary = TournamentRules.fixture(round, pool)["arena"]
			audit.check_true(not arena.is_empty(), "tournament/%d_arenas/round_%d_has_a_court" % [quante, round + 1])
			audit.check_true(pool.has(arena), "tournament/%d_arenas/round_%d_court_is_available" % [quante, round + 1])
			used.append(String(arena["id"]))
		audit.check_eq(
			_distinct(used).size(), mini(quante, ROUNDS),
			"tournament/%d_arenas/uses_%d_distinct_courts" % [quante, mini(quante, ROUNDS)],
		)

	# Elenco vuoto: non deve rompersi, deve ricadere sul roster completo.
	var with_empty: Dictionary = TournamentRules.fixture(0, [])["arena"]
	audit.check_true(not with_empty.is_empty() and arenas.has(with_empty), "tournament/empty_pool_falls_back_to_all_arenas")

	# Un turno oltre la finale non deve uscire dall'elenco.
	for round in [3, 4, 10]:
		var arena: Dictionary = TournamentRules.fixture(round, arenas)["arena"]
		audit.check_true(not arena.is_empty() and arenas.has(arena), "tournament/round_%d_out_of_range_resolves" % round)

	# --- l'avversario cresce col turno ----------------------------------------
	var opponents: Array = Frozen.ai_opponents()
	audit.check_ge(opponents.size(), ROUNDS, "tournament/at_least_three_ai_tiers")
	for turno in range(1, ROUNDS):
		audit.check_gt(
			float(opponents[turno]["skill"]), float(opponents[turno - 1]["skill"]),
			"tournament/round_%d_harder_than_round_%d" % [turno + 1, turno],
		)
		audit.check_gt(
			float(TournamentRules.ai_for_round(turno)["skill"]), float(TournamentRules.ai_for_round(turno - 1)["skill"]),
			"tournament/ai_for_round_%d_rises" % (turno + 1),
		)
	audit.check_eq(String(TournamentRules.ai_for_round(0)["id"]), String(opponents[0]["id"]), "tournament/round_1_uses_the_first_tier")
	audit.check_eq(
		String(TournamentRules.ai_for_round(9)["id"]), String(opponents[opponents.size() - 1]["id"]),
		"tournament/ai_for_round_clamps_past_the_last_tier",
	)

	# --- il turno avanza, e la vittoria della finale e' il trofeo --------------
	# `js/main.js:1479-1490`.
	var advance := TournamentRules.advance(0, true)
	audit.check_eq(int(advance["round"]), 1, "tournament/won_round_1_advances")
	audit.check_true(bool(advance["continuing"]), "tournament/won_round_1_keeps_the_result_screen")
	audit.check_eq(int(TournamentRules.advance(1, true)["round"]), 2, "tournament/won_round_2_advances")
	var after_final := TournamentRules.advance(2, true)
	audit.check_eq(int(after_final["round"]), 0, "tournament/won_final_resets_the_board")
	audit.check_true(bool(after_final["reset"]), "tournament/reset_flag_on_final_win")
	audit.check_eq(int(TournamentRules.advance(1, false)["round"]), 0, "tournament/lost_round_resets_the_board")

	# `js/main.js:1398`.
	audit.check_true(TournamentRules.is_trophy(2, true), "tournament/final_won_is_the_trophy")
	audit.check_true(not TournamentRules.is_trophy(2, false), "tournament/final_lost_is_not_the_trophy")
	audit.check_true(not TournamentRules.is_trophy(1, true), "tournament/semi_final_won_is_not_the_trophy")

	# One match configuration, end to end, for the UI lane.
	var config := TournamentRules.match_config(1, arenas)
	audit.check_true(not Dictionary(config["arena"]).is_empty(), "tournament/match_config_has_a_court")
	audit.check_eq(String(Dictionary(config["ai"])["id"]), String(opponents[1]["id"]), "tournament/match_config_ai_is_the_round_tier")
	audit.check_eq(int(Dictionary(config["fixture"])["round"]), 1, "tournament/match_config_carries_the_round")

	audit.report("rounds=%s" % JSON.stringify(ids))
	audit.report("finale=%s arene=%d" % [String(final["id"]), arenas.size()])


static func _distinct(values: Array) -> Dictionary:
	var out: Dictionary = {}
	for value in values:
		out[value] = true
	return out
