## reference_grid_audit.gd — the formulas against the REFERENCE'S OWN output.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/reference_grid_audit.gd
##
## The career rules are formulas, not tables: `seasonObjectives`, `matchObjective`,
## `careerRival`, `careerAiProfile`, `careerFixture` and `tournamentFixture` are
## functions in `js/data.js`, and a port of a function can only be checked against
## the function itself. Hand-checking a transcription against a second reading of
## the source is how a number gets retyped without anyone noticing.
##
## `tools/modes-port/extract-modes.mjs` therefore EVALUATES the reference
## functions over a grid and writes the answers to
## `godot/tests/modes/data/reference-grid.json`. This audit calls the ported
## GDScript over the same inputs and compares, value by value:
##
##   seasonObjectives    seasons 1-40, three objectives each
##   matchObjective      seasons 1-40 x 3 matches
##   careerRival         seasons 1-40
##   careerAiProfile     seasons 1-121 x 3 matches (id, skill, speed, power)
##   careerFixture       seasons 1-40 x 3 matches x pools of 0/1/2/3/4/9
##   tournamentFixture   rounds 0-4 x the same pools
##
## The grid is deliberately wider than any single audit's sweep, so a
## transcription that happens to be right only on the audited points still fails
## here. The grid's own row counts are asserted first: a truncated or regenerated
## file cannot pass by having fewer rows to check.
##
## Float comparisons are `abs(port - reference) <= 1e-12`; the maximum observed
## difference is printed, so "close enough" is a number rather than a claim.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

const GRID_PATH := "res://tests/modes/data/reference-grid.json"
const TOLERANCE := 1e-12

## The generator's own sweep (`tools/modes-port/extract-modes.mjs`): `0` is the
## empty list, `n` is the first `n` arenas.
const ARENA_COUNTS := [0, 1, 2, 3, 4, 9]
const ROUNDS := [0, 1, 2, 3, 4]
const SEASONS := 40
const PROFILE_SEASONS := 121

## Maximum |port - reference| seen over every float compared. Static because
## `run` is the entry point `run_all.gd` calls on the script.
static var _max_float_diff: float = 0.0


func _initialize() -> void:
	var audit := AuditBase.new("reference_grid")
	run(audit)
	audit.report("max_float_diff=%s" % ("%.18f" % _max_float_diff))
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var grid := _grid()
	if grid.is_empty():
		audit.check_true(false, "reference_grid/grid_file_readable")
		return

	# --- the grid's own shape: fewer rows must not read as a pass --------------
	var season_objectives: Array = grid.get("seasonObjectives", [])
	var match_objectives: Array = grid.get("matchObjective", [])
	var rivals: Array = grid.get("careerRival", [])
	var profiles: Array = grid.get("careerAiProfile", [])
	var fixtures: Array = grid.get("careerFixture", [])
	var tournament: Array = grid.get("tournamentFixture", [])
	var matches: int = CareerRules.career_matches()
	audit.check_eq(season_objectives.size(), SEASONS, "reference_grid/grid_has_%d_seasons" % SEASONS)
	audit.check_eq(match_objectives.size(), SEASONS * matches, "reference_grid/grid_has_%d_match_objectives" % (SEASONS * matches))
	audit.check_eq(rivals.size(), SEASONS, "reference_grid/grid_has_%d_rivals" % SEASONS)
	audit.check_eq(profiles.size(), PROFILE_SEASONS * matches, "reference_grid/grid_has_%d_ai_profiles" % (PROFILE_SEASONS * matches))
	audit.check_eq(fixtures.size(), SEASONS * matches * ARENA_COUNTS.size(), "reference_grid/grid_has_%d_career_fixtures" % (SEASONS * matches * ARENA_COUNTS.size()))
	audit.check_eq(tournament.size(), ROUNDS.size() * ARENA_COUNTS.size(), "reference_grid/grid_has_%d_tournament_fixtures" % (ROUNDS.size() * ARENA_COUNTS.size()))

	# --- seasonObjectives -----------------------------------------------------
	for row in season_objectives:
		var season := int(row["season"])
		var expected: Array = row["objectives"]
		var actual := CareerRules.season_objectives(season)
		var same: bool = actual.size() == expected.size()
		if same:
			for i in expected.size():
				same = same \
					and String(actual[i]["id"]) == String(expected[i]["id"]) \
					and int(actual[i]["target"]) == int(expected[i]["target"])
		audit.check_true(same, "reference_grid/season_objectives_%d" % season)

	# --- matchObjective -------------------------------------------------------
	for row in match_objectives:
		var season := int(row["season"])
		var match_index := int(row["matchIndex"])
		var expected: Dictionary = row["objective"]
		var actual := CareerRules.match_objective(season, match_index)
		audit.check_true(
			String(actual["id"]) == String(expected["id"]) and int(actual["target"]) == int(expected["target"]),
			"reference_grid/match_objective_%d_%d" % [season, match_index],
		)

	# --- careerRival ----------------------------------------------------------
	for row in rivals:
		var season := int(row["season"])
		audit.check_eq(
			String(CareerRules.career_rival(season)["id"]), String(row["rival"]),
			"reference_grid/career_rival_%d" % season,
		)

	# --- careerAiProfile ------------------------------------------------------
	for row in profiles:
		var season := int(row["season"])
		var match_index := int(row["matchIndex"])
		var profile := CareerRules.career_ai_profile(season, match_index)
		var label := "reference_grid/career_ai_profile_%d_%d" % [season, match_index]
		audit.check_eq(String(profile["id"]), String(row["id"]), "%s/id" % label)
		_close(audit, float(profile["skill"]), float(row["skill"]), "%s/skill" % label)
		_close(audit, float(profile["speed"]), float(row["speed"]), "%s/speed" % label)
		_close(audit, float(profile["power"]), float(row["power"]), "%s/power" % label)

	# --- careerFixture --------------------------------------------------------
	for row in fixtures:
		var season := int(row["season"])
		var match_index := int(row["matchIndex"])
		var count := int(row["arenaCount"])
		var fx := CareerRules.career_fixture(season, match_index, _pool(count))
		var label := "reference_grid/career_fixture_%d_%d_pool%d" % [season, match_index, count]
		audit.check_eq(String(Dictionary(fx["arena"]).get("id", "")), String(row["arena"]), "%s/arena" % label)
		audit.check_eq(String(Dictionary(fx["rival"]).get("id", "")), String(row["rival"]), "%s/rival" % label)

	# --- tournamentFixture ----------------------------------------------------
	for row in tournament:
		var round := int(row["round"])
		var count := int(row["arenaCount"])
		var arena: Dictionary = CareerRules.tournament_fixture(round, _pool(count)).get("arena", {})
		audit.check_eq(
			String(arena.get("id", "")), String(row["arena"]),
			"reference_grid/tournament_fixture_round%d_pool%d" % [round, count],
		)

	# --- the two tables the grid is generated beside --------------------------
	audit.check_eq(String(Tables.source_sha256().get("js/data.js", "")), String(grid.get("sourceSha256", {}).get("js/data.js", "")), "reference_grid/table_and_grid_come_from_the_same_data_js")
	audit.check_eq(int(grid.get("emptySeasonProgress", {}).size()), Tables.season_metric_agg().size(), "reference_grid/empty_progress_has_a_key_per_metric")


## The pool the generator passed at that count (`ARENAS.slice(0, n)`, `[]` for 0).
static func _pool(count: int) -> Array:
	if count == 0:
		return []
	return Frozen.arenas().slice(0, count)


static func _close(audit: AuditBase, actual: float, expected: float, label: String) -> void:
	var diff := absf(actual - expected)
	_max_float_diff = maxf(_max_float_diff, diff)
	audit.check_le(diff, TOLERANCE, label)


static func _grid() -> Dictionary:
	var text := FileAccess.get_file_as_string(GRID_PATH)
	if text.is_empty():
		push_error("reference_grid_audit.gd: cannot read %s — run `node tools/modes-port/extract-modes.mjs`" % GRID_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
