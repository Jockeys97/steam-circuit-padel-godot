## mode_session.gd — the PLAYABLE mode session: one drill / tournament round /
## career match, wired to the ported mode logic and to the save module.
##
## WHAT WAS MISSING BEFORE THIS FILE. `godot/src/modes/**` had the rules
## (`DrillSession`, `TournamentRules`, `CareerRules`, `CareerProgress`,
## `ModesSave`) and `godot/game/mode_screen.gd` could show their tables, but
## nothing could PLAY one: there was no mode match start, no `ModesSave` caller
## and no way for a result to reach the save. This is the missing middle: one
## object that owns the mode's live state, steps it with the real engine, resolves
## what the mode hands the player, and — on the single end-of-session path —
## awards and persists exactly what the reference awards and persists.
##
## THE RULES ARE NOT HERE. Every number comes from `godot/src/modes/**`:
##   - the arena, the rival pair and the AI profile: `CareerRules`
##     (`getAiForMatch` / `careerFixture` / `tournamentFixture` / `dictatedRivals`);
##   - the drill: `DrillSession`, its own `step`, its own grading;
##   - the bracket: `TournamentRules.advance` / `match_config`;
##   - the awards: `CareerProgress` (`awardObjectives` / `applyCareerMatch` /
##     `awardOutfitChallenges` / `preMatchTrophy`);
##   - persistence: `ModesSave` only, which goes through `godot/src/save/**`.
## The one physics line in this file is `Sim.update_match` (drill: through
## `DrillSession.step`), so a mode is a wrapper around the same engine the quick
## match uses, never a second one.
##
## THE DEMO RULE. `can_start()` asks `content_gate.gd` for the build's granted
## list, the same question the menu's own mode row asks
## (`main_menu.gd` `gate` + `Config.mode_ids()`), so the two cannot disagree. In
## the packaged demo that list is `["quick"]` (`js/build.js:43-53`), which holds
## none of this port's three modes, so all three are REFUSED here, before
## any state is built, so no route — menu, mode screen or a caller that sets
## `Config.pending_mode` by hand — can start one. The reference's own
## `applyDemoLimits` (`js/ui.js:735-756`) locks exactly the `.mode-card` elements
## outside that list and the browser's training entry is a header button rather
## than a mode card, so the browser demo leaves training reachable; the port
## renders all three modes from one row and one gate, so it applies the build's
## granted list uniformly. That is a divergence, it is deliberate, and it is
## recorded in `docs/wayfinder/evidence/modes-playable.md`.
##
## API (a screen or a test consumes this without reading its internals):
##
##   ModeSession.can_start(mode) -> bool          the build's granted modes only
##   ModeSession.start(mode, store, opts := {}) -> ModeSession | null
##       null when the build does not grant the mode: nothing is built and no
##       save byte is written. `refusal(mode)` answers why.
##   session.mode, .arena, .ai, .fixture, .round, .season, .match_index
##   session.state        the real SimState (`state` of the drill's own session
##                        when the mode is drill)
##   session.phase        "ready" | "live" | "done"
##   session.step(dt, input, input2 := {}) -> void      one engine tick
##   session.is_done() -> bool        a finished match (drill: never by itself)
##   session.finish() -> Dictionary   award + persist, ONCE (idempotent)
##   session.hud() -> Dictionary      what the mode HUD draws
##   session.report() -> Dictionary   the whole session as data, for a test
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")
const Locale := preload("res://src/locale/locale.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Gate := preload("res://game/content_gate.gd")
const Lineup := preload("res://game/lineup.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const DrillTarget := preload("res://src/modes/drill_target.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const TournamentRules := preload("res://src/modes/tournament_rules.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")

## The three modes this session can play. `quick` is not one of them: it is the
## menu's own play button and the match scene's default.
const MODES := ["drill", "tournament", "career"]
## `js/drill.js` starts the drill on `DRILL_EXERCISES[0]`; the menu can name
## another one through `opts.exercise`.
const DEFAULT_EXERCISE := "precision"

var mode: String = ""
var store = null
## The build this session runs in — captured at start so a report cannot answer a
## different question than the session did.
var demo: bool = false

var athlete: Dictionary = {}
var arena: Dictionary = {}
var ai: Dictionary = {}
var fixture: Dictionary = {}
var lineup: Dictionary = {}
## Tournament: the round being played (`js/main.js` `ui.tournamentRound`).
var round: int = 0
## Career: the season and the calendar position of the match being played.
var season: int = 1
var match_index: int = 0
## Career: the live payload, mutated by `CareerProgress` and written by `ModesSave`.
var career: Dictionary = {}
## The bonus objective of this match (`matchObjective`, `js/data.js:838-846`).
var objective: Dictionary = {}
## The season objectives as the screen shows them.
var season_objectives: Array = []

## The drill's own session when the mode is drill; the match is a plain state
## stepped by `Sim.update_match` otherwise.
var drill = null
var state = null

var phase: String = "ready"
var finished: bool = false
var counts: bool = false
var awarded: Dictionary = {}
var saved: Dictionary = {}
var winner: String = ""
## Set when `finish()` ran from a mode that has no automatic end (the drill: the
## player leaves, exactly as the browser's exit does).
var closed_by_player: bool = false
## The seed every state of this session is built on, and the arena list its
## fixtures were resolved against: kept so `report()` answers from the same inputs
## the session used rather than from a second read of the world.
var seed_value: int = 0
var arenas: Array = []
## The outfit the player wears in this session (the menu's choice). Kept so the
## report answers with it and the scenes have one place to read it from.
var outfit: StringName = &"base"


# ---------------------------------------------------------------------------
# Starting
# ---------------------------------------------------------------------------

## True when this build grants the mode. The one source of truth is the gate's
## own list (`DEMO_CONTENT.modes`), never a copy of it.
##
## Note that `DEMO_CONTENT.modes` is `["quick"]` and its `allModes`
## (`js/build.js`) lists no training entry at all: that list describes the
## reference's mode CARDS, and the browser's training entry is a header button
## (`index.html`, `data-action="to-drill"`). Neither contains this port's "drill",
## so asking them alone would lock a mode in the FULL build too. The question is
## therefore the build flag (`demo?`) AND the granted list, which is exactly the
## menu's own rule (`main_menu.gd`): outside the demo every mode is granted, and
## inside one only what the build lists is.
static func can_start(mode_id: String) -> bool:
	if not MODES.has(mode_id):
		return false
	return not Gate.is_demo() or Gate.modes().has(mode_id)


## Why a mode cannot start, as a sentence a screen can print. "" when it can.
static func refusal(mode_id: String) -> String:
	if not MODES.has(mode_id):
		return "'%s' is not one of the three modes (%s)" % [mode_id, str(MODES)]
	if not can_start(mode_id):
		return "%s is not in this DEMO build's granted modes %s (demo build)" % [mode_id, str(Gate.modes())]
	return ""


## Builds the mode's live session. Returns null — with nothing built and nothing
## written — when the build does not grant the mode (`refusal()` says why).
static func start(mode_id: String, store_ref, opts: Dictionary = {}) -> RefCounted:
	if not can_start(mode_id):
		return null
	var s := new()
	s.mode = mode_id
	s.store = store_ref
	s.demo = Gate.is_demo()
	s.athlete = opts.get("athlete", {})
	var arenas: Array = opts.get("arenas", [])
	s.seed_value = int(opts.get("seed", 0))
	s.arenas = arenas
	s.outfit = opts.get("outfit", &"base")

	match mode_id:
		"drill":
			s._start_drill(opts)
		"tournament":
			# Which round is played is a fact about the SAVE, not about this call:
			# `opts["round"]` only overrides it when a caller names a round
			# explicitly, and the menu's own options carry -1 for "the save's".
			s.round = int(opts.get("round", -1))
			if s.round < 0:
				s.round = ModesSave.tournament_round(store_ref)
			s.fixture = TournamentRules.fixture(s.round, arenas)
			s.arena = s.fixture.get("arena", {})
			s.ai = TournamentRules.ai_for_round(s.round)
			s._start_match("tournament")
		"career":
			s.career = ModesSave.load_career(store_ref)
			s.season = int(s.career.get("season", 1))
			s.match_index = int(s.career.get("matchIndex", 0))
			s.objective = CareerRules.match_objective(s.season, s.match_index)
			s.season_objectives = CareerProgress.ensure_season_objectives(s.career)
			s.fixture = CareerRules.career_fixture(s.season, s.match_index, arenas)
			s.arena = s.fixture.get("arena", {})
			s.ai = CareerRules.career_ai_profile(s.season, s.match_index)
			s._start_match("career")
	s.phase = "live"
	return s


## The drill: `createDrill(exerciseId, athlete, arena, aiProfile, lineup)`
## (`js/drill.js:86-146`), with the arena the caller selected and the AI tier the
## reference resolves for the free modes (`getAiForMatch("drill", …)`).
func _start_drill(opts: Dictionary) -> void:
	arena = opts.get("arena", {})
	ai = CareerRules.ai_for_match("drill", 0, "", 1, 0)
	lineup = Lineup.resolve(athlete)
	drill = DrillSession.create(
		String(opts.get("exercise", DEFAULT_EXERCISE)), athlete, arena, ai,
		{"seed": seed_value, "lineup": lineup}
	)
	state = drill.state
	state.rng_state = seed_value
	state.running = true
	# The drill has no points target (`pointsToWin` is `Number.MAX_SAFE_INTEGER`),
	# so its `phase` is the only end it has. The session's own phase starts where
	# the reference's does.
	phase = "live"


## A tournament round or a career match: the same `createMatchState` the quick
## match uses, with the mode's own arena, AI profile and rival pair.
##
##   `js/main.js:1105-1140`: the arena comes from the fixture, the AI from
##   `getAiForMatch`, the lineup from `resolveLineup` (which is where
##   `dictatedRivals` lands), and only the career branch overrides the scoring —
##   `scoring = "points"`, `pointsToWin = CAREER_POINTS_TO_WIN`. A tournament
##   round is a full tennis match, exactly as the reference leaves it.
func _start_match(kind: String) -> void:
	# `js/ui.js:548-570`: the reference resolves `playerMate` FIRST, then asks
	# `dictatedRivals` with the player and the mate excluded from the rival pool —
	# so the pool the rival is drawn from depends on who the second player is, and
	# the exclusion list is built here in that order rather than approximated.
	var mate: Variant = Lineup.resolve(athlete).get("playerMate", null)
	var excluded: Array = [String(athlete.get("id", ""))]
	if mate is Dictionary:
		excluded.append(String((mate as Dictionary)["id"]))
	var dictated: Variant = CareerRules.dictated_rivals(kind, season, match_index, round, excluded)
	lineup = Lineup.resolve(athlete, dictated)
	state = Sim.create_match_state(kind, athlete, arena, ai, round, {"lineup": lineup})
	state.rng_state = seed_value
	state.running = true
	if kind == "career":
		state.scoring = "points"
		state.pointsToWin = CareerRules.career_points_to_win()


# ---------------------------------------------------------------------------
# The tick
# ---------------------------------------------------------------------------

## One engine tick. The drill goes through `DrillSession.step`, which itself calls
## `Sim.update_match` (`js/drill.js:361`) and owns the drill's phases and grading;
## every other mode calls the engine directly. Either way there is exactly one
## physics path.
func step(dt: float, input: Dictionary, input2: Dictionary = {}) -> void:
	if state == null:
		return
	if drill != null:
		drill.step(dt, input)
		if String(drill.phase) == "result":
			phase = "live"
		return
	Sim.update_match(state, dt, input, input2)


## A finished match. The drill has no finished state of its own — its own
## `pointsToWin` is `Number.MAX_SAFE_INTEGER` (`js/drill.js:97`), so a point can
## never close it and the player is the one who ends it.
func is_done() -> bool:
	if drill != null:
		return finished
	return state != null and state.result != null


## Who won the match the state carries (`player` / `ai`), or "" while it runs.
func match_winner() -> String:
	if state == null or state.result == null:
		return ""
	return String(state.result.get("winner", ""))


# ---------------------------------------------------------------------------
# Ending: the reference's awards, then the save module
# ---------------------------------------------------------------------------

## The single end-of-session path. Idempotent: a second call returns the first
## call's report and touches neither the career nor the save.
##
##   drill      — `ModesSave.drill_record_after` (`js/main.js:2122-2124`, which is
##                `saveDrillRecord`'s improvement-only rule);
##   tournament — `TournamentRules.advance` (`js/main.js:1479-1490`) and
##                `ModesSave.save_tournament_round`, plus the history entry
##                (`js/ui.js:1557-1561`);
##   career     — `preMatchTrophy`, `awardObjectives`, `awardOutfitChallenges`,
##                `applyCareerMatch` (`js/main.js:1395-1477`) and `save_career`.
func finish() -> Dictionary:
	if counts:
		return awarded
	counts = true
	finished = true
	phase = "done"
	if drill != null:
		awarded = _finish_drill()
		return awarded
	winner = match_winner()
	var won: bool = winner == "player"
	if mode == "tournament":
		awarded = _finish_tournament(won)
	elif mode == "career":
		awarded = _finish_career(won)
	return awarded


func _finish_drill() -> Dictionary:
	awarded = {
		"mode": "drill",
		"exercise": String(drill.exercise.get("id", "")),
		"score": int(drill.score),
		"best": int(drill.best),
		"attempts": int(drill.attempts),
		"hits": int(drill.hits),
		"grade": drill.grade,
		"score_line": drill.score_line(),
		"record": ModesSave.drill_record_after(store, drill),
	}
	awarded["best"] = int(drill.best)
	awarded["persisted_best"] = ModesSave.drill_best(store, String(drill.exercise.get("id", "")))
	return awarded


func _finish_tournament(won: bool) -> Dictionary:
	var trophy: bool = CareerProgress.pre_match_trophy({}, "tournament", won, round)
	var advanced: Dictionary = TournamentRules.advance(round, won)
	saved = ModesSave.save_tournament_round(store, int(advanced["round"]))
	var played_round := round
	round = int(advanced["round"])
	var entry := ModesSave.history_entry(
		"tournament", String(athlete.get("id", "")), String(arena.get("id", "")),
		String(ai.get("id", "")), "solo", winner, _score_text(), 0, trophy, 0,
		int(Time.get_unix_time_from_system())
	)
	var history: Dictionary = ModesSave.record_match(store, entry)
	return {
		"mode": "tournament",
		"round": played_round,
		"won": won,
		"trophy": trophy,
		"advanced": advanced,
		"next_round": int(advanced["round"]),
		"next_fixture": TournamentRules.fixture(int(advanced["round"]), arenas),
		"continuing": bool(advanced["continuing"]),
		"persisted_round": ModesSave.tournament_round(store),
		"round_save": saved,
		"history": history,
		"history_size": ModesSave.load_history(store).size(),
	}


func _finish_career(won: bool) -> Dictionary:
	var played_season := season
	var played_index := match_index
	var before: Dictionary = career.duplicate(true)
	var trophy: bool = CareerProgress.pre_match_trophy(career, "career", won, 0)
	var objectives: Dictionary = CareerProgress.award_objectives(career, state.stats)
	var outfits: Array = CareerProgress.award_outfit_challenges(
		career, String(athlete.get("id", "")), state.stats, won, float(ai.get("skill", 0.0))
	)
	var outcome: Dictionary = CareerProgress.apply_career_match(career, won)
	saved = ModesSave.save_career(store, career)
	season = int(career.get("season", 1))
	match_index = int(career.get("matchIndex", 0))
	season_objectives = career.get("seasonObjectives", [])
	var entry := ModesSave.history_entry(
		"career", String(athlete.get("id", "")), String(arena.get("id", "")),
		String(ai.get("id", "")), "solo", winner, _score_text(), CareerRules.career_points_to_win(),
		trophy, played_season, int(Time.get_unix_time_from_system())
	)
	var history: Dictionary = ModesSave.record_match(store, entry)
	return {
		"mode": "career",
		"season": played_season,
		"match_index": played_index,
		"won": won,
		"trophy": trophy,
		"objective": objective,
		"objectives": objectives,
		"outfits": outfits,
		"outcome": outcome,
		"season_now": season,
		"match_index_now": match_index,
		"stars_before": int(before.get("stars", 0)),
		"stars": int(career.get("stars", 0)),
		"season_stars": int(career.get("seasonStars", 0)),
		"persisted": ModesSave.load_career(store),
		"history": history,
		"history_size": ModesSave.load_history(store).size(),
	}


## `"6-4"`-shaped, the reference's own `state.sets` summary for the history line.
func _score_text() -> String:
	if state == null:
		return ""
	return "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])]


# ---------------------------------------------------------------------------
# What the HUD draws
# ---------------------------------------------------------------------------

## The mode HUD's model. One call, no side effects: the drill case reads the live
## `DrillSession` (phase, target, metrics, score line) and the two match cases read
## the state and the mode's own fixture.
func hud() -> Dictionary:
	match mode:
		"drill":
			return _hud_drill()
		"tournament":
			return _hud_tournament()
		"career":
			return _hud_career()
	return {"mode": mode, "title": mode.to_upper(), "phase": phase, "lines": [], "metrics": []}


func _hud_drill() -> Dictionary:
	var lines: Array = []
	if drill == null:
		return {"mode": "drill", "title": "ALLENAMENTO", "phase": phase, "lines": lines, "metrics": []}
	var target: Dictionary = drill.target
	lines.append("%s  ·  fase %s  ·  round %d" % [
		String(drill.exercise.get("id", "")).to_upper(), String(drill.phase), int(drill.round),
	])
	lines.append("PUNTEGGIO %d  ·  record %d  ·  %s" % [
		int(drill.score), int(drill.best), drill.score_line(),
	])
	lines.append("BERSAGLIO  %s" % _target_line(target))
	lines.append("COLPI %d/%d  ·  serie %d  ·  rally %d" % [
		int(drill.hits), int(drill.attempts), int(drill.streak), int(drill.best_rally),
	])
	if drill.diagnosis != null:
		lines.append("ESITO  %s" % String(drill.diagnosis))
	return {
		"mode": "drill",
		"title": "ALLENAMENTO",
		"phase": String(drill.phase),
		"lines": lines,
		"metrics": drill.metrics(),
		"target": target,
		"score": int(drill.score),
		"best": int(drill.best),
		"attempts": int(drill.attempts),
		"hits": int(drill.hits),
		"grade": drill.grade,
	}


func _target_line(target: Dictionary) -> String:
	if not bool(target.get("active", false)):
		return "—"
	return "%s (%.0f, %.0f) r%.0f" % [
		String(target.get("kind", "?")), float(target.get("x", 0.0)),
		float(target.get("y", 0.0)), float(target.get("r", 0.0)),
	]


func _hud_tournament() -> Dictionary:
	var lines: Array = []
	lines.append("TURNO %d/%d  ·  %s  ·  %s (%s %.2f)" % [
		round + 1, TournamentRules.ROUNDS, String(arena.get("id", "?")),
		String(ai.get("name", "?")), Locale.t("ability"), float(ai.get("skill", 0.0)),
	])
	lines.append(_score_line())
	if counts:
		var next: Dictionary = fixture_of(int(awarded.get("next_round", 0)))
		lines.append("TURNO %d %s  ·  prossimo: %s" % [
			int(awarded.get("round", round)) + 1,
			"VINTO" if bool(awarded.get("won", false)) else "PERSO",
			String((next.get("arena", {}) as Dictionary).get("id", "?")),
		])
	return {
		"mode": "tournament",
		"title": "TORNEO CAMPIONATO",
		"phase": phase,
		"lines": lines,
		"metrics": [],
		"round": round,
		"trophy": TournamentRules.is_trophy(round, winner == "player"),
	}


func fixture_of(round_index: int) -> Dictionary:
	return TournamentRules.fixture(round_index, arenas)


func _hud_career() -> Dictionary:
	var lines: Array = []
	lines.append("STAGIONE %d  ·  PARTITA %d/%d  ·  %s" % [
		season, match_index + 1, CareerRules.career_matches(), String(arena.get("id", "?")),
	])
	lines.append("RIVALE  %s (%s %.2f)" % [
		String(ai.get("name", "?")), Locale.t("ability"), float(ai.get("skill", 0.0)),
	])
	lines.append(_objective_line())
	lines.append(_score_line())
	if counts:
		lines.append("STAGIONE %d  ·  esito %s  ·  stelle %d" % [
			int(awarded.get("season_now", season)),
			String((awarded.get("outcome", {}) as Dictionary).get("outcome", "")),
			int(awarded.get("stars", 0)),
		])
	return {
		"mode": "career",
		"title": "CARRIERA",
		"phase": phase,
		"lines": lines,
		"metrics": [],
		"objective": objective,
		"objective_line": _objective_line(),
		"season": season,
		"match_index": match_index,
	}


## The bonus objective of THIS match, with its live progress
## (`matchObjective` + `matchProgress`, `js/data.js:838-846`, `js/ui.js:91-100`).
## This is the line item 3 asks the career HUD to surface in-match.
func _objective_line() -> String:
	if objective.is_empty():
		return "OBIETTIVO  —"
	var progress: Dictionary = CareerProgress.match_progress(state.stats) if state != null else {}
	var status: Dictionary = CareerProgress.objective_status(objective, progress)
	return "OBIETTIVO  %s %d/%d%s" % [
		String(objective.get("id", "?")), int(status["progress"]), int(status["target"]),
		"  ·  FATTO" if bool(status["done"]) else "",
	]


## The live score line, from the sim's own display fields. A career match scores
## in points (`scoring = "points"`), the tournament in the tennis sequence.
func _score_line() -> String:
	if state == null:
		return "—"
	if String(state.scoring) == "points":
		return "PUNTI %d-%d  ·  a %d" % [
			int(state.points["player"]), int(state.points["ai"]), int(state.pointsToWin),
		]
	return "SET %s-%s  ·  GAME %d-%d" % [
		String(state.playerScore), String(state.aiScore),
		int(state.games["player"]), int(state.games["ai"]),
	]


# ---------------------------------------------------------------------------
# The read-back a test asserts on
# ---------------------------------------------------------------------------

func report() -> Dictionary:
	return {
		"mode": mode,
		"demo": demo,
		"phase": phase,
		"finished": finished,
		"seed": seed_value,
		"outfit": String(outfit),
		"arenas": arenas.size(),
		"arena": String(arena.get("id", "")),
		"ai": String(ai.get("id", "")),
		"round": round,
		"season": season,
		"match_index": match_index,
		"lineup": Lineup.ids(lineup),
		"winner": winner,
		"objective": objective,
		"drill": _drill_report(),
		"awarded": awarded,
		"saved": saved,
	}


func _drill_report() -> Dictionary:
	if drill == null:
		return {}
	return {
		"exercise": String(drill.exercise.get("id", "")),
		"phase": String(drill.phase),
		"round": int(drill.round),
		"attempts": int(drill.attempts),
		"hits": int(drill.hits),
		"score": int(drill.score),
		"best": int(drill.best),
		"streak": int(drill.streak),
		"rally_hits": int(drill.rally_hits),
		"grade": drill.grade,
		"diagnosis": drill.diagnosis,
		"score_line": drill.score_line(),
		"target": drill.target,
		"landing": drill.landing,
		"metrics": drill.metrics(),
	}
