## match_format_audit.gd — the port of `scripts/match-format-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/audits/match_format_audit.gd
##
## This audit does not check the table, it checks the ENGINE: every point is
## awarded by sending the ball out of the back of one half, so it goes through
## `scorePoint`, `finishGame` and `finishSet` exactly as a real point does.
##
## The three promises (`scripts/match-format-audit.mjs:69-122`):
##   1. winning every point wins the match in every one of the six formats, at the
##      exact point count the format implies (11 / 21 / 8 / 12 / 24 / 48);
##   2. a set closes at the configured game count — including 2-1 in the
##      win-by-one formats, which the margin governs;
##   3. the full set demands the two-game margin and 6-6 starts the tie-break.
##
## Extra check the JavaScript cannot make (ticket `sim-rules-audits.md` §Tests):
## all six `MATCH_FORMATS` keys are exercised, and the count is asserted — a
## format silently dropped from the table fails here rather than passing quietly.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")

## `scripts/match-format-audit.mjs:46`.
const DT := 1.0 / 240.0
const POINT_FRAMES := 4000


func _initialize() -> void:
	var audit := AuditBase.new("match_format")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var formats: Dictionary = Frozen.all()["matchFormats"]
	# The order the reference iterates: `Object.entries(MATCH_FORMATS)` — the
	# frozen table's insertion order, which `frozen/data.json` preserves.
	var order: Array = ["points11", "points21", "games3", "games5", "set", "match2"]

	audit.check_eq(formats.size(), 6, "match_format/frozen_match_formats_has_six_entries")
	var exercised := 0
	for id in order:
		if not formats.has(id):
			audit.check_true(false, "match_format/frozen_format_%s_present" % id)
			continue
		exercised += 1
		var format: Dictionary = formats[id]
		var outcome := dominant_match(audit, format, id)
		if outcome.is_empty():
			continue
		audit.check_eq(String(outcome["vincitore"]), "player", "match_format/%s/dominant_player_wins" % id)
		if String(format.get("scoring", "tennis")) == "points":
			audit.check_eq(int(outcome["punti"]), int(format["pointsToWin"]), "match_format/%s/points_to_close" % id)
		else:
			var expected: int = 4 * int(format["gamesToWin"]) * int(format["setsToWin"])
			audit.check_eq(int(outcome["punti"]), expected, "match_format/%s/points_to_close" % id)
			audit.check_eq(
				int(Dictionary(outcome["sets"])["player"]), int(format["setsToWin"]),
				"match_format/%s/closes_at_configured_sets" % id,
			)
	audit.check_eq(exercised, 6, "match_format/every_format_exercised")

	# The case the margin governs: in the short formats one game must be enough.
	for id in ["games3", "games5"]:
		var format: Dictionary = formats[id]
		var state := new_match(format)
		for game in range(0, int(format["gamesToWin"]) - 1):
			for point in range(0, 4):
				award_point(audit, state, "ai")
		var result: Variant = null
		var budget: int = 4 * int(format["gamesToWin"])
		for point in range(0, budget):
			if result != null:
				break
			result = award_point(audit, state, "player")
		audit.check_true(result != null, "match_format/%s/won_by_one_game_closes" % id)
		if result != null:
			audit.check_eq(
				String(Dictionary(result)["winner"]), "player",
				"match_format/%s/last_game_wins_the_match" % id,
			)

	# The full set must demand the two-game margin and reach the tie-break at 6-6.
	var full := new_match(formats["set"])
	for game in range(0, 5):
		for point in range(0, 4):
			award_point(audit, full, "ai")
	for point in range(0, 20):
		award_point(audit, full, "player")
	audit.check_eq(int(full.games["player"]), 5, "match_format/set/five_games_each_player")
	audit.check_eq(int(full.games["ai"]), 5, "match_format/set/five_games_each_ai")
	for point in range(0, 4):
		award_point(audit, full, "player")
	audit.check_eq(int(full.sets["player"]), 0, "match_format/set/six_five_does_not_close_the_set")
	for point in range(0, 4):
		award_point(audit, full, "ai")
	audit.check_eq(bool(full.tieBreak), true, "match_format/set/six_six_starts_the_tie_break")


# ---------------------------------------------------------------------------
# `nuovaPartita` (`scripts/match-format-audit.mjs:25-29`).
# ---------------------------------------------------------------------------

static func new_match(format: Dictionary) -> State:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	# `Object.assign(state, formato, {running: true})`. The reference leaves the
	# seed to `Math.random` (`js/game.js:218`); the port's constructor starts from
	# `rng_state = 0`, which is the same injection point the reference uses when it
	# replaces `Math.random` (no draw has been taken before the first tick).
	if format.has("scoring"):
		state.scoring = String(format["scoring"])
	if format.has("pointsToWin"):
		state.pointsToWin = int(format["pointsToWin"])
	if format.has("gamesToWin"):
		state.gamesToWin = int(format["gamesToWin"])
	if format.has("gameMargin"):
		state.gameMargin = int(format["gameMargin"])
	if format.has("setsToWin"):
		state.setsToWin = int(format["setsToWin"])
	if format.has("tieBreakAt"):
		state.tieBreakAt = format["tieBreakAt"]
	state.running = true
	return state


# ---------------------------------------------------------------------------
# `assegnaPunto` (`scripts/match-format-audit.mjs:31-54`): award a point to a side
# by sending the other side's ball out of the back of its own half.
# ---------------------------------------------------------------------------

static func award_point(audit: AuditBase, state: State, to: String) -> Variant:
	var court: Dictionary = Frozen.court()
	var loser: String = "ai" if to == "player" else "player"
	state.serving = false
	state.pointPause = 0.0
	state.ball.x = 480.0
	state.ball.y = float(court["top"]) - 80.0 if loser == "player" else float(court["bottom"]) + 80.0
	state.ball.z = 2.0
	state.ball.vx = 0.0
	state.ball.vy = -300.0 if loser == "player" else 300.0
	state.ball.vz = -50.0
	state.ball.crossedNet = true
	state.ball.serveInFlight = false
	state.lastHitterSide = loser
	var before := score_total(state)
	for frame in range(0, POINT_FRAMES):
		var outcome: Variant = Sim.update_match(state, DT, Support.vuoto())
		if outcome != null:
			return outcome
		if score_total(state) != before:
			return null
	audit.check_true(false, "match_format/point_awarded_for_%s" % to)
	return null


static func score_total(state: State) -> int:
	return (
		int(state.points["player"]) + int(state.points["ai"])
		+ int(state.games["player"]) + int(state.games["ai"])
		+ int(state.sets["player"]) + int(state.sets["ai"])
		+ int(state.tieBreakPoints["player"]) + int(state.tieBreakPoints["ai"])
	)


# ---------------------------------------------------------------------------
# `partitaADominio` (`scripts/match-format-audit.mjs:56-67`).
# ---------------------------------------------------------------------------

static func dominant_match(audit: AuditBase, format: Dictionary, id: String) -> Dictionary:
	var state := new_match(format)
	for point in range(0, 400):
		var outcome: Variant = award_point(audit, state, "player")
		if outcome != null:
			return {
				"punti": point + 1,
				"vincitore": String(Dictionary(outcome)["winner"]),
				"games": state.games,
				"sets": state.sets,
			}
	audit.check_true(false, "match_format/%s/match_ends_within_400_points" % id)
	return {}
