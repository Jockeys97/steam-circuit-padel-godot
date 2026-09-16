## tournament_rules.gd — the tournament board and its progression, ported from
## `js/data.js` (the fixture resolver) and `js/main.js` (the round advance).
##
## API (a UI lane consumes this without reading its internals):
##
##   TournamentRules.ROUNDS -> int                 3 rounds. `scripts/tournament-audit.mjs:20`
##   TournamentRules.FINAL_ROUND -> int            2 (the third round), `js/main.js:1398`
##   TournamentRules.fixture(round, available_arenas) -> Dictionary
##       `{arena, round}` for that round of the board.
##   TournamentRules.path(available_arenas) -> Array[Dictionary]
##       The three rounds in order, through `fixture`.
##   TournamentRules.prestigio(arena) -> int       `js/data.js:928-930`
##   TournamentRules.ai_for_round(round) -> Dictionary
##       `js/ui.js:1540`: `AI_OPPONENTS[Math.min(round, length - 1)]`.
##   TournamentRules.is_trophy(round, won) -> bool  `js/main.js:1398`
##   TournamentRules.advance(round, won) -> Dictionary
##       `js/main.js:1479-1490`. `{round, continuing, reset}`: winning a round
##       before the final advances it and keeps the result screen up; anything
##       else resets the board to round 0. The reference's `pendingContinue` is
##       the `continuing` flag.
##   TournamentRules.match_config(round, available_arenas) -> Dictionary
##       What the 3D session needs to start a tournament match: `{round, arena,
##       ai, fixture}`. Round 3+ (the value `tournamentRound` reaches after the
##       final, `js/main.js:1480`) resolves rather than crashes — the audit
##       asserts that (`scripts/tournament-audit.mjs:59-64`).
##
## The board is not re-invented: `fixture` is `CareerRules.tournament_fixture`,
## which is `js/data.js:916-925` including its stable prestige sort. This module
## adds only the progression the reference keeps in `main.js`.
extends RefCounted

const CareerRules := preload("res://src/modes/career_rules.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## `const TURNI = 3` (`scripts/tournament-audit.mjs:20`), the same three rounds
## `js/data.js:920` resolves against.
const ROUNDS: int = 3

## The round whose win is the trophy (`js/main.js:1398`: `ui.tournamentRound === 2`).
const FINAL_ROUND: int = 2


## `tournamentFixture(round, availableArenas)` (`js/data.js:916-925`).
static func fixture(round: int, available_arenas: Array = []) -> Dictionary:
	return CareerRules.tournament_fixture(round, available_arenas)


## The whole board: rounds 0, 1, 2 in order.
static func path(available_arenas: Array = []) -> Array:
	var out: Array = []
	for round in range(0, ROUNDS):
		out.append(fixture(round, available_arenas))
	return out


static func prestigio(arena: Dictionary) -> int:
	return CareerRules.prestigio(arena)


## `AI_OPPONENTS[Math.min(round, AI_OPPONENTS.length - 1)]` (`js/ui.js:1540`).
static func ai_for_round(round: int) -> Dictionary:
	var opponents: Array = Frozen.ai_opponents()
	if opponents.size() == 0:
		return {}
	return opponents[mini(round, opponents.size() - 1)]


## `winner === "player" && ui.selectedMode === "tournament" && ui.tournamentRound === 2`
## (`js/main.js:1398`): the third round won is the trophy.
static func is_trophy(round: int, won: bool) -> bool:
	return won and round == FINAL_ROUND


## `js/main.js:1479-1490`. Winning before the final advances the round and stays
## on the result screen; every other path resets the board.
static func advance(round: int, won: bool) -> Dictionary:
	if won and round < FINAL_ROUND:
		return {"round": round + 1, "continuing": true, "reset": false}
	return {"round": 0, "continuing": false, "reset": true}


## Everything a tournament match needs to start: the board's court, the AI tier
## for the round, and the fixture the result screen names.
static func match_config(round: int, available_arenas: Array = []) -> Dictionary:
	var fx: Dictionary = fixture(round, available_arenas)
	return {
		"round": round,
		"arena": fx.get("arena", {}),
		"ai": ai_for_round(round),
		"fixture": fx,
	}
