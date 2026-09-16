extends RefCounted
class_name GameAchievements
## The narrow achievement interface: the game's own tracked values in, Steam API
## names out, one backend call each.
##
## The mapping is GATED, not guessed
## ---------------------------------
## `docs/wayfinder/tickets/steamworks-prerequisites.md` (open, owner Luca) owns
## the achievement list with its API names. Until it lands, `SOURCE_TO_API_NAME`
## is **empty on purpose**: `unlock_source()` refuses, because inventing an id
## is a red failure for this slice (see the ticket's failure criteria).
##
## So the class ships the two halves separately:
##   * the SOURCES list — the values the game actually tracks, and nothing else
##     (the prerequisites ticket names exactly these three families: career
##     stars and the progression model, trophies/history, and the 20 unlockable
##     outfit challenges);
##   * `unlock_api(name)` — the wire, exercised by tests and by the future
##     mapping, which calls the backend at most once per achievement.
##
## The one thing it will not do is invent a name. `unlock_source("career.stars")`
## returns false today and records why.

## The achievement sources named by the prerequisites ticket. Each is a value the
## game already tracks; `specials` is deliberately absent (specials are shot
## abilities, not characters — the ticket says so).
const SOURCES: Array = [
	"career.stars", ## js/data.js CAREER_*, career.stars in the save
	"career.season", ## career.bestSeason / career.season
	"career.trophies", ## career.trophies
	"history.wins", ## js/ui.js:1567 renderHistory
	"history.trophies", ## js/ui.js:1569
	"outfits.won", ## js/data.js:515-555, career.outfitsWon keys
]

## The 20 unlockable outfit challenges, the count the prerequisites ticket names.
const OUTFIT_CHALLENGE_COUNT: int = 20

## source -> Steam API name. EMPTY UNTIL THE PREREQUISITES TICKET LANDS.
## Filling this map is the whole of the integration step on this side; nothing
## else in this file changes.
const SOURCE_TO_API_NAME: Dictionary = {}

var _backend: RefCounted
var _unlocked: Dictionary = {}
var _refusals: Array = []
var _backend_calls: int = 0


func _init(p_backend: RefCounted) -> void:
	_backend = p_backend


## False while `SOURCE_TO_API_NAME` is empty. Callers may use it to skip a
## mapping pass instead of collecting refusals.
func mapping_ready() -> bool:
	return not SOURCE_TO_API_NAME.is_empty()


## The API name for a source, or "" when the mapping has not landed.
func api_name_for(source: String) -> String:
	return String(SOURCE_TO_API_NAME.get(source, ""))


## Unlock by source. Refuses while the mapping is empty — no invented id.
func unlock_source(source: String) -> bool:
	var api_name := api_name_for(source)
	if api_name.strip_edges().is_empty():
		_refuse(source, "no API name known for source '%s' (steamworks-prerequisites open): refusing to invent one" % source)
		return false
	return unlock_api(api_name)


## Unlock by API name. The backend is called **at most once** per name: a repeat
## returns the remembered result without a second call, so a game loop that
## re-evaluates a condition cannot spam the Steam API.
func unlock_api(api_name: String) -> bool:
	if api_name.strip_edges().is_empty():
		_refuse(api_name, "empty API name")
		return false
	if _unlocked.has(api_name):
		return bool(_unlocked[api_name])
	_backend_calls += 1
	var ok := bool(_backend.unlock_achievement(api_name))
	if ok:
		_unlocked[api_name] = true
	else:
		_refuse(api_name, "backend refused (no Steam backend enabled, or the call failed)")
	return ok


func unlocked_ids() -> Array:
	return _unlocked.keys()


func refusals() -> Array:
	return _refusals.duplicate(true)


## How many calls actually reached the backend. A test asserts this equals the
## number of distinct accepted achievements, not the number of attempts.
func backend_calls() -> int:
	return _backend_calls


## The sources that a real mapping must cover, for the audit that lands with it.
func uncovered_sources() -> Array:
	if not mapping_ready():
		return SOURCES.duplicate()
	var out: Array = []
	for s in SOURCES:
		if api_name_for(s).is_empty():
			out.append(s)
	return out


func _refuse(source_or_name: String, reason: String) -> void:
	_refusals.append({"source": source_or_name, "reason": reason})
