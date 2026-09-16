## career_rules.gd — the pure career/tournament RULES, ported from `js/data.js`
## and `js/ui.js`. No UI, no storage, no scene: every function is a pure function
## of the frozen tables, so it is callable headlessly and testable without a
## session.
##
## API (a UI lane consumes this without reading its internals):
##
##   CareerRules.season_objectives(season, opts := {}) -> Array[Dictionary]
##       `seasonObjectives`, `js/data.js:816-835`. Three `{id, target}` triples,
##       deterministic in `season`. `opts` carries `pointsToWin` / `matches`
##       (the reference's optional second parameter).
##   CareerRules.match_objective(season, match_index) -> Dictionary
##       `matchObjective`, `js/data.js:838-846`.
##   CareerRules.career_rival(season) -> Dictionary
##       `careerRival`, `js/data.js:860-863`: one frozen `AI_OPPONENTS` entry.
##   CareerRules.career_ai_profile(season, match_index) -> Dictionary
##       `careerAiProfile`, `js/data.js:885-895`: the rival plus the season/match
##       growth, clamped by `CAREER_RAMP`'s three caps.
##   CareerRules.career_fixture(season, match_index, available_arenas) -> Dictionary
##       `careerFixture`, `js/data.js:932-936`: `{arena, rival, matchIndex, season}`.
##   CareerRules.tournament_fixture(round, available_arenas) -> Dictionary
##       `tournamentFixture`, `js/data.js:916-925`: `{arena, round}`.
##   CareerRules.empty_season_progress() -> Dictionary
##       `emptySeasonProgress`, `js/data.js:785-787`: the zero state, one key per
##       metric in `SEASON_METRIC_AGG`.
##   CareerRules.is_unlocked(item, career) -> bool
##       `isUnlocked`, `js/data.js:702-710`. `item` is an arena, an athlete, an
##       outfit or any table entry with `challenge` / `unlock`.
##   CareerRules.outfit_challenge_met(challenge, contesto) -> bool
##       `outfitChallengeMet`, `js/data.js:730-741`. `contesto` is
##       `{stats, won, skill, athleteWins}`.
##   CareerRules.metric_value(stats, metric) -> Variant
##       `metricValue`, `js/data.js:744-750`; `null` when the metric is absent.
##   CareerRules.ai_for_match(mode, round, difficulty, season, match_index) -> Dictionary
##       `getAiForMatch`, `js/ui.js:1529-1540`. `quick` maps the difficulty to a
##       tier, `career` reads the ramp, anything else indexes `AI_OPPONENTS` by
##       round (clamped).
##   CareerRules.dictated_rivals(mode, season, match_index, round, excl) -> Variant
##       `dictatedRivals`, `js/ui.js:531-546`: who you face when the calendar
##       decides. `null` for the free modes, which is the reference's own answer.
##   CareerRules.prestigio(arena) -> int
##       `prestigio`, `js/data.js:928-930`; the sort key the tournament board uses.
##
## Two deliberate notes on faithfulness:
##
## 1. `seasonObjectives` is a formula, not a table, and it is transcribed line by
##    line with its anchors above; its INPUTS (`CAREER_MATCHES`,
##    `CAREER_POINTS_TO_WIN`, `CAREER_PROMOTION_WINS`) come from the generated
##    table, never from a literal. `godot/tests/modes/reference_grid_audit.gd`
##    checks the transcription against the reference's OWN output for seasons
##    1-40, which is the mechanical proof that no number was retyped.
## 2. The reference computes the season offset as `(season - 1) % pool.length`,
##    and JavaScript's `%` is signed: a season below 1 yields `pool[-1]`,
##    `undefined`, and a target of `undefined`. That is a JavaScript quirk rather
##    than a rule, and `posmod` here differs from it below season 1. The domain
##    the reference is ever called with starts at 1 (`js/ui.js:63` starts the
##    career at `season: 1`), and the grid covers 1-40. The divergence is named
##    rather than silently inherited.
extends RefCounted

const Tables := preload("res://src/modes/mode_tables.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## `JS_SORT_STABLE` — `Array.prototype.sort` is stable (ECMA-262, since ES2019),
## so two arenas with the same prestige keep their table order. Godot's
## `Array.sort_custom` is not stable, so `tournament_fixture` decorates with the
## original index and breaks ties on it. Without this the three prestige-0 arenas
## could be permuted relative to the reference and the round-0 court would differ.
const _PRESTIGE_TIE_BREAK := true


# ---------------------------------------------------------------------------
# Career tables (all read, nothing re-typed)
# ---------------------------------------------------------------------------

static func career_matches() -> int:
	return Tables.career_matches()


static func career_points_to_win() -> int:
	return Tables.career_points_to_win()


static func career_promotion_wins() -> int:
	return Tables.career_promotion_wins()


static func career_final_season() -> int:
	return Tables.career_final_season()


static func career_ramp() -> Dictionary:
	return Tables.career_ramp()


static func season_metric_agg() -> Dictionary:
	return Tables.season_metric_agg()


static func objective_defs() -> Dictionary:
	return Tables.objective_defs()


## `emptySeasonProgress()` (`js/data.js:785-787`): one key per metric of
## `SEASON_METRIC_AGG`, all zero.
static func empty_season_progress() -> Dictionary:
	var out: Dictionary = {}
	for metric in season_metric_agg():
		out[metric] = 0
	return out


# ---------------------------------------------------------------------------
# Objectives
# ---------------------------------------------------------------------------

## `seasonObjectives(season, { pointsToWin, matches })` (`js/data.js:816-835`).
static func season_objectives(season: int, opts: Dictionary = {}) -> Array:
	var points_to_win: int = int(opts.get("pointsToWin", career_points_to_win()))
	var matches: int = int(opts.get("matches", career_matches()))
	var cap: int = points_to_win * matches
	var promotion_points: int = points_to_win * career_promotion_wins()
	# La richiesta cresce con le stagioni ma satura: oltre, tornerebbe impossibile.
	var step: int = mini(maxi(season - 1, 0), 6)
	var pool: Array = [
		{"id": "smashWins", "target": 4 + step},
		{"id": "winners", "target": mini(cap - 6, 10 + step)},
		{"id": "winRally", "target": 10 + step},
		{"id": "noDoubleFault", "target": maxi(0, 2 - int(floor(float(step) / 3.0)))},
		{"id": "winPoints", "target": mini(cap - 3, promotion_points + step)},
		{"id": "fewErrors", "target": maxi(3, 8 - step)},
	]
	var offset: int = posmod(season - 1, pool.size())
	var out: Array = []
	for i in range(0, 3):
		out.append(pool[posmod(offset + i, pool.size())].duplicate())
	return out


## `matchObjective(season, matchIndex)` (`js/data.js:838-846`).
static func match_objective(season: int, match_index: int) -> Dictionary:
	var pool: Array = [
		{"id": "smashWins", "target": 1},
		{"id": "winners", "target": 2},
		{"id": "winRally", "target": 6},
		{"id": "noDoubleFault", "target": 0},
	]
	return pool[posmod(season * 7 + match_index * 3, pool.size())].duplicate()


# ---------------------------------------------------------------------------
# The circuit: rival, ramp, fixtures
# ---------------------------------------------------------------------------

## `careerRival(season)` (`js/data.js:860-863`).
static func career_rival(season: int) -> Dictionary:
	var opponents: Array = Frozen.ai_opponents()
	var index: int = clampi(season - 1, 0, opponents.size() - 1)
	return opponents[index] if opponents.size() > 0 else {}


## `careerAiProfile(season, matchIndex)` (`js/data.js:885-895`).
static func career_ai_profile(season: int, match_index: int) -> Dictionary:
	var base: Dictionary = career_rival(season)
	var ramp: Dictionary = career_ramp()
	var opponents: Array = Frozen.ai_opponents()
	var growth: float = maxf(0.0, float(season - opponents.size())) * float(ramp["seasonGain"]) \
		+ float(match_index) * float(ramp["matchGain"])
	var profile: Dictionary = base.duplicate()
	profile["skill"] = minf(float(ramp["skillCap"]), float(base["skill"]) + growth)
	profile["speed"] = minf(float(ramp["speedCap"]), float(base["speed"]) + growth * 140.0)
	profile["power"] = minf(float(ramp["powerCap"]), float(base["power"]) + growth)
	return profile


## `prestigio(arena)` (`js/data.js:928-930`): what unlocking the arena costs.
static func prestigio(arena: Dictionary) -> int:
	var unlock: Dictionary = arena.get("unlock", {}) if arena.get("unlock") is Dictionary else {}
	return int(unlock.get("trophies", 0)) * 10 + int(unlock.get("stars", 0))


## `tournamentFixture(round, availableArenas = ARENAS)` (`js/data.js:916-925`).
static func tournament_fixture(round: int, available_arenas: Array = []) -> Dictionary:
	var pool: Array = _sorted_by_prestige(available_arenas)
	var turni := 3
	var index: int = 0 if pool.size() == 1 else _js_round(
		(float(mini(round, turni - 1)) / float(turni - 1)) * float(pool.size() - 1)
	)
	return {"arena": pool[index] if pool.size() > 0 else {}, "round": round}


## `careerFixture(season, matchIndex, availableArenas = ARENAS)` (`js/data.js:932-936`).
static func career_fixture(season: int, match_index: int, available_arenas: Array = []) -> Dictionary:
	var pool: Array = available_arenas if available_arenas.size() > 0 else Frozen.arenas()
	var arena: Dictionary = {}
	if pool.size() > 0:
		arena = pool[posmod(season * 3 + match_index, pool.size())]
	return {
		"arena": arena,
		"rival": career_rival(season),
		"matchIndex": match_index,
		"season": season,
	}


## The pool `tournamentFixture` sorts: the available arenas when there is at
## least one, the whole `ARENAS` table otherwise (`js/data.js:917-918`).
static func _sorted_by_prestige(available_arenas: Array) -> Array:
	var pool: Array = available_arenas if available_arenas.size() > 0 else Frozen.arenas()
	var decorated: Array = []
	for index in pool.size():
		decorated.append({"arena": pool[index], "p": prestigio(pool[index]), "i": index})
	# Stable by construction: equal prestige keeps the input order (JS sort is
	# stable), which is what `_PRESTIGE_TIE_BREAK` records.
	decorated.sort_custom(func(a, b):
		if int(a["p"]) == int(b["p"]):
			return int(a["i"]) < int(b["i"]) if _PRESTIGE_TIE_BREAK else false
		return int(a["p"]) < int(b["p"]))
	var out: Array = []
	for entry in decorated:
		out.append(entry["arena"])
	return out


## `Math.round`: half away from zero. Godot's `roundf` agrees; spelled here so a
## reader does not have to wonder which rounding the reference uses.
static func _js_round(value: float) -> int:
	return int(roundf(value))


# ---------------------------------------------------------------------------
# Unlocks and outfit challenges
# ---------------------------------------------------------------------------

## `isUnlocked(item, career)` (`js/data.js:702-710`).
static func is_unlocked(item: Dictionary, career: Dictionary) -> bool:
	if bool(career.get("unlockAll", false)):
		return true
	# I completi non si comprano: si vincono.
	if item.get("challenge") != null:
		var won: Dictionary = career.get("outfitsWon", {}) if career.get("outfitsWon") is Dictionary else {}
		return bool(won.get(String(item.get("unlockKey", "")), false))
	if item.get("unlock") == null:
		return true
	var unlock: Dictionary = item["unlock"]
	var trophies: int = int(unlock.get("trophies", 0))
	var stars: int = int(unlock.get("stars", 0))
	return int(career.get("trophies", 0)) >= trophies and int(career.get("stars", 0)) >= stars


## `outfitChallengeMet(challenge, contesto)` (`js/data.js:730-741`).
static func outfit_challenge_met(challenge: Variant, contesto: Dictionary) -> bool:
	if challenge == null or not (challenge is Dictionary):
		return false
	var ch: Dictionary = challenge
	var stats: Variant = contesto.get("stats", null)
	var won: bool = bool(contesto.get("won", false))
	var skill: float = float(contesto.get("skill", 0.0))
	var athlete_wins: int = int(contesto.get("athleteWins", 0))
	if bool(ch.get("win", false)) and not won:
		return false
	if ch.get("minSkill") != null and skill < float(ch["minSkill"]):
		return false
	var prova_ok := func(prova: Dictionary) -> bool:
		var value: Variant = athlete_wins if String(prova.get("metric", "")) == "wins" else metric_value(stats, String(prova["metric"]))
		if value == null:
			return false
		if bool(prova.get("atMost", false)):
			return float(value) <= float(prova["target"])
		return float(value) >= float(prova["target"])
	if not prova_ok.call(ch):
		return false
	if ch.get("also") != null and ch["also"] is Dictionary:
		return bool(prova_ok.call(ch["also"]))
	return true


## `metricValue(stats, metric)` (`js/data.js:744-750`) from the player's side.
static func metric_value(stats: Variant, metric: String) -> Variant:
	if stats == null or not (stats is Dictionary):
		return null
	var table: Dictionary = stats
	# `longestRally` e `totalRallyHits` sono della partita, non di un lato.
	if metric == "longestRally" or metric == "totalRallyHits":
		return table.get(metric, null)
	var voce: Variant = table.get(metric, null)
	if voce != null and voce is Dictionary:
		return voce.get("player", null)
	return null


# ---------------------------------------------------------------------------
# Which AI you face, and who the calendar hands you
# ---------------------------------------------------------------------------

## `getAiForMatch(mode, round, difficulty)` (`js/ui.js:1529-1540`). The career
## season/match index is passed in place of the reference's `ui.career` read.
static func ai_for_match(mode: String, round: int, difficulty: String = "easy", season: int = 1, match_index: int = 0) -> Dictionary:
	var opponents: Array = Frozen.ai_opponents()
	if opponents.size() == 0:
		return {}
	if mode == "quick":
		var tiers := {"easy": 0, "medium": 1, "hard": 2, "legend": 3}
		return opponents[int(tiers.get(difficulty, 0))]
	if mode == "career":
		return career_ai_profile(season, match_index)
	return opponents[mini(round, opponents.size() - 1)]


## `dictatedRivals(esclusi)` (`js/ui.js:531-546`), with the mode and the circuit
## position passed in place of the reference's `ui` reads. Returns
## `{opponent, opponentMate}` for career/tournament and `null` for the free
## modes, where the player picks everything.
static func dictated_rivals(mode: String, season: int, match_index: int, round: int, excl: Array = []) -> Variant:
	var seme: Variant = null
	if mode == "career":
		seme = season * career_matches() + match_index
	elif mode == "tournament":
		seme = round + 1
	if seme == null:
		return null
	var pool: Array = []
	for athlete in Frozen.athletes():
		if not excl.has(athlete["id"]):
			pool.append(athlete)
	if pool.size() < 2:
		return null
	var primo: Dictionary = pool[int(seme) % pool.size()]
	var resto: Array = []
	for athlete in pool:
		if athlete["id"] != primo["id"]:
			resto.append(athlete)
	return {
		"opponent": primo,
		"opponentMate": resto[posmod(int(seme) * 3 + 1, resto.size())],
	}
