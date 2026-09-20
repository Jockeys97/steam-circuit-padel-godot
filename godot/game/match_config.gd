## match_config.gd — the menu's selection, carried to the match scene, plus the
## small lookups both screens need.
##
## Static vars, so nothing needs an autoload (the harness project deliberately has
## none) and a scene change does not lose the choice. Everything the data layer
## can answer is answered from the frozen tables in `src/sim/frozen/`, which are a
## mechanical serialisation of `js/data.js` — no athlete, arena or tier is defined
## here.
extends RefCounted

const Frozen := preload("res://src/sim/frozen.gd")
const Gate := preload("res://game/content_gate.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const Store := preload("res://src/save/save_store.gd")
const Arena := preload("res://game/arenas/arena_library.gd")

## Roster-order defaults, per `PLAN.md` "Athlete roster order": the first athlete
## and the first arena are the slice's defaults.
##
## BOTH INDICES ARE FROZEN-ROSTER INDICES, not positions in the list a screen
## shows. In a demo build the two lists differ (the demo exposes two of six
## athletes and one of nine arenas), so a screen enumerates
## `selectable_athletes()` / `selectable_arenas()` and maps back with
## `athlete_index` / `arena_index`; `apply_build_limits()` is what guarantees the
## selection is inside the exposed set after a demo build starts.
static var athlete_index: int = 0
static var arena_index: int = 0
## The SPECIAL athlete seat (port additions, `src/character/specials.gd`). Empty
## means "the frozen `athlete_index` is the selection"; a non-empty id means the
## selected athlete is that Godot-only special and `athlete_index` is left where it
## was, so pressing a frozen athlete button (or restoring the frozen selection)
## simply clears the seat. The world-arena seat below works the same way. Only a
## FULL build can hold one (`set_special_athlete_id` refuses an id this build does
## not offer, and `apply_build_limits()` clears the seat in a demo): the demo's
## content rule is the reference's own table and knows nothing of the special set.
static var special_athlete_id: String = ""
## The WORLD arena seat (port additions, `arena_library.gd::world_ids()`). Empty
## means "the frozen `arena_index` is the selection"; a non-empty id means the
## selected arena is that world arena and `arena_index` is left where it was, so
## pressing a frozen arena button (or restoring the frozen selection) simply
## clears the seat. Only a FULL build can hold one (`set_arena_id` refuses a
## world id in a demo, and `apply_build_limits()` clears the seat) — the demo's
## content rule is the reference's own table and knows nothing of the world set.
static var world_arena_id: String = ""
static var tier_index: int = 0
static var seed_value: int = 20260916
static var camera_preset: String = "default"
## The mode the next scene should open: "quick" (the play button) or one of
## `Gate.modes()` (a mode entry). Read once by the screen that is being opened, so
## the menu stays the only thing that decides where a press leads.
static var pending_mode: String = "quick"
## Which drill exercise a drill session starts on (`js/drill.js` `DRILL_EXERCISES`,
## the id the drill screen's rows carry). Unused by the other two modes.
static var pending_exercise: String = "precision"
## The human mode a QUICK match opens with (`ui.playerMode`, `js/main.js:1156`):
## `"solo"`, `"coop"` or `"pvp"` — two humans on the same keyboard/pad when it is not
## `solo`. Written by the arena screen's start, read once by `match_controller`'s
## `start_match()`. Every other mode runs `"solo"`: the reference forces it
## (`humanMode = ui.selectedMode === "quick" ? (ui.playerMode ?? "solo") : "solo"`),
## and so does the arena screen's own write.
static var pending_player_mode: String = "solo"
## Which tournament round a mode match plays. -1 means "whatever the save holds"
## (`ModesSave.tournament_round`), which is the normal path: the bracket is
## persisted, so the round is a fact about the save rather than about this call.
static var pending_round: int = -1
## UIR-22's result hand-off. `match_controller.gd` fills this with the payload
## `ResultScreen.enter()` takes (`ResultScreen.payload_from_state`: the live state's
## own score/stat fields plus the mode's facts) at the moment a match ends, and then
## routes to `res://game/Main.tscn`; the router host there mounts `result` with this
## payload and takes it (`take_pending_result()`), so a result is shown once and never
## twice. Empty means "no result waiting" — the host then opens the menu.
static var pending_result: Dictionary = {}


## The recorded result, consumed exactly once (the store-then-take pair above).
static func take_pending_result() -> Dictionary:
	var held := pending_result
	pending_result = {}
	return held


## The stored `prefs` group, the one the settings screen writes. Read through the
## save's own group door (same shape as `control_mode()` above), never from a second
## copy of the schema; `{}` when nothing is stored or the payload is malformed. This
## is the reader the review's F6 named missing: the volume, deadzone and vibration
## rows used to persist values that nothing read back.
static func stored_prefs() -> Dictionary:
	var read: Dictionary = save_store().read_group("prefs")
	var payload: Variant = read.get("payload", null)
	if typeof(payload) != TYPE_DICTIONARY:
		return {}
	return payload

## The save root the screens and the mode session read and write. `""` means the
## save module's own `user://save`; a test points it at its own directory so it
## never touches a real profile.
static var save_dir: String = ""
## Which of the selected athlete's outfits is worn. Frozen-roster indices again: an
## index into `AthleteSpawn.outfit_ids()` for the *selected* athlete.
static var outfit_index: int = 0


static func athletes() -> Array:
	return Frozen.athletes()


static func arenas() -> Array:
	return Frozen.arenas()


## The athletes this build offers as a choice (`content_gate.gd` -> the reference's
## `demoFilter`). The full roster in a full build; two in the packaged demo.
static func selectable_athletes() -> Array:
	return Gate.roster()


## The arenas this build offers as a choice. One in the packaged demo.
static func selectable_arenas() -> Array:
	return Gate.arenas()


## The WORLD arenas this build offers as a further choice: the five port
## additions in a full build, nothing in a demo (`Gate.world_arenas()`). A
## separate list, never merged into `selectable_arenas()`: the frozen list's size
## and order are the reference's own (the slice pins them), and the world set is
## additive content the selection asks for by name.
static func selectable_world_arenas() -> Array:
	return Gate.world_arenas()


## The SPECIAL athletes this build offers as a further choice: the Godot-only
## additions (fornaio) in a full build, nothing in a demo
## (`Gate.special_athletes()`). A separate list, never merged into
## `selectable_athletes()` — that list is the reference's own roster and the slice
## pins its size; a special is additive content the selection asks for BY NAME.
static func selectable_special_athletes() -> Array:
	return Gate.special_athletes()


## THE ONE ARENA CATALOG for this build (`content_gate.gd::arena_catalog()`,
## `game/arenas/arena_catalog.gd`): the frozen index, the world set and the seat rule
## all come from it, so this file no longer decides frozen-vs-world by itself — the
## ported column and the recreated arena screen ask the same catalog. Typed Variant
## because the module is a `RefCounted` class and only its public interface is called.
static func arena_catalog() -> Variant:
	return Gate.arena_catalog()


## Is the current selection a world arena (the world seat is occupied)?
static func is_world_selected() -> bool:
	return world_arena_id != ""


## Is the current selection a special athlete (the special seat is occupied)?
static func is_special_selected() -> bool:
	return special_athlete_id != ""


## Selects a special athlete by id. False for an id this build does not offer — a
## demo build refuses every special, exactly as it refuses a world arena. The
## caller decides what to do about the refusal rather than the config silently
## picking something else. `athlete_index` is left where it was, so a frozen pick
## (or the demo's limits) simply puts the frozen selection back in charge.
static func set_special_athlete_id(id: String) -> bool:
	for row in selectable_special_athletes():
		if String((row as Dictionary).get("id", "")) == id:
			special_athlete_id = id
			return true
	return false


## Gives the frozen roster back the selection: the special seat is cleared.
static func clear_special_athlete() -> void:
	special_athlete_id = ""


## The mode ids this build offers (`["quick"]` in the demo).
static func mode_ids() -> Array:
	return Gate.modes()


static func is_demo() -> bool:
	return Gate.is_demo()


## The save store every mode call goes through. Built per call (the store is a
## thin, stateless reader/writer over one directory) so nothing caches a path
## that a test may have moved.
static func save_store() -> RefCounted:
	return Store.new(save_dir)


## The three player-switching modes the reference accepts, by its own names.
const CONTROL_MODES := ["assisted", "semi", "manual"]
const DEFAULT_MATCH_FORMAT := "points11"


## The switching mode the save holds, validated. An absent or unknown value is
## `semi`, which is the simulation's own default too.
##
## The reference validates exactly these three when it loads its preferences
## (`js/main.js:2273`) and copies the saved value onto the match before its loop
## starts (`js/main.js:1184`: `matchState.controlMode = ui.controlMode`). Until
## this function existed the preference was written into the save, defaulted and
## shown — and never reached `SimState.controlMode`, so every match ran `semi`.
static func control_mode() -> String:
	var read: Dictionary = save_store().read_group("prefs")
	var payload: Variant = read.get("payload", null)
	if typeof(payload) != TYPE_DICTIONARY:
		return "semi"
	var value := String((payload as Dictionary).get("controlMode", "semi"))
	return value if CONTROL_MODES.has(value) else "semi"


## The quick-match format follows `prefs.matchLength`, written by ModesScreen,
## and validates against the frozen reference table. A missing or stale value uses
## the browser's own default rather than a guessed fallback.
static func match_length() -> String:
	var formats := Frozen.match_formats()
	var value := String(stored_prefs().get("matchLength", DEFAULT_MATCH_FORMAT))
	return value if formats.has(value) else DEFAULT_MATCH_FORMAT


## Mirrors `Object.assign(matchState, MATCH_FORMATS[ui.matchLength])` exactly:
## only the selected row's fields are assigned. This is only for quick matches;
## tournament and career rules remain owned by their session code.
static func apply_quick_match_format(state: Variant) -> void:
	if state == null:
		return
	var formats := Frozen.match_formats()
	var format: Dictionary = formats.get(match_length(), formats.get(DEFAULT_MATCH_FORMAT, {}))
	if format.has("scoring"):
		state.scoring = String(format["scoring"])
	if format.has("pointsToWin"):
		state.pointsToWin = int(format["pointsToWin"])
	if format.has("gamesToWin"):
		state.gamesToWin = int(format["gamesToWin"])
	if format.has("gameMargin"):
		state.gameMargin = int(format["gameMargin"])
	if format.has("tieBreakAt"):
		state.tieBreakAt = format["tieBreakAt"]
	if format.has("setsToWin"):
		state.setsToWin = int(format["setsToWin"])


## The options a mode session needs, from the state this config already carries.
## One place, so a screen and a test hand `ModeSession.start` the same dictionary.
static func mode_options() -> Dictionary:
	return {
		"exercise": pending_exercise,
		"round": pending_round,
		"seed": seed_value,
		"athlete": athlete(),
		"arena": arena(),
		"arenas": selectable_arenas(),
		"outfit": outfit_id(),
		"lineup": {},
	}


## The outfits the selected athlete owns, in reference order (`AthleteSpawn`).
static func outfit_ids() -> Array:
	return AthleteSpawn.outfit_ids(StringName(String(athlete()["id"])))


static func outfit_id() -> StringName:
	var list := outfit_ids()
	if list.is_empty():
		return &"base"
	return StringName(String(list[clampi(outfit_index, 0, list.size() - 1)]))


static func outfit_name_key() -> String:
	return AthleteSpawn.outfit_name_key(StringName(String(athlete()["id"])), outfit_id())


## Moves to the next outfit of the selected athlete, wrapping. Returns the new id.
static func cycle_outfit(step: int = 1) -> StringName:
	var list := outfit_ids()
	if list.size() == 0:
		return &"base"
	outfit_index = posmod(outfit_index + step, list.size())
	return outfit_id()


## `applyDemoLimits` (`js/ui.js:736-756`), for the selection this port carries: the
## demo pins the difficulty (`ui.aiDifficulty = DEMO_CONTENT.difficulty`), starts on
## its own first mode (`ui.selectedMode = DEMO_CONTENT.modes[0]`, which here is the
## only mode) and can only offer the athletes and arenas it exposes
## (`selectableAthletes` / `selectableArenas`, `js/ui.js:485-492`). The tier mapping
## is the reference's own (`js/ui.js:1531`), not a new one.
##
## Returns what it changed, so a caller (and the slice test) can see the limits were
## applied rather than assume it. A full build gets an empty Dictionary: nothing is
## touched, which is the point of `demoFilter` being a no-op outside the demo.
static func apply_build_limits() -> Dictionary:
	var changed := {}
	if not Gate.is_demo():
		return changed
	# The world set is full-build content: a demo can never hold a world seat.
	if world_arena_id != "":
		changed["world_arena_id"] = world_arena_id
		world_arena_id = ""
	# The special set is full-build content too: a demo can never hold the seat.
	if special_athlete_id != "":
		changed["special_athlete_id"] = special_athlete_id
		special_athlete_id = ""
		outfit_index = 0
	var tier := Gate.fixed_tier_index()
	if tier >= 0 and tier_index != tier:
		changed["tier_index"] = tier
		tier_index = tier
	var first_athlete := Gate.first_exposed_athlete_index()
	if first_athlete >= 0 and athlete_index != first_athlete:
		changed["athlete_index"] = first_athlete
		athlete_index = first_athlete
		outfit_index = 0
	var first_arena := Gate.first_exposed_arena_index()
	if first_arena >= 0 and arena_index != first_arena:
		changed["arena_index"] = first_arena
		arena_index = first_arena
	return changed


## Does this build grant the frozen-table athlete/arena/tier at this index?
##
## A full build grants everything in range — the same answer `js/build.js`
## `demoFilter` gives when `IS_DEMO` is false (a no-op). A demo grants only what
## its own table declares: the athlete at that roster index must be one of
## `Gate.roster()`, the arena one of `Gate.arenas()`, and the tier must be the one
## difficulty the demo pins (`Gate.fixed_tier_index()`, `js/ui.js:1531`).
static func grants_athlete(index: int) -> bool:
	var list := athletes()
	if index < 0 or index >= list.size():
		return false
	if not Gate.is_demo():
		return true
	return Gate.index_in(Gate.roster(), list[index]) >= 0


static func grants_arena(index: int) -> bool:
	var list := arenas()
	if index < 0 or index >= list.size():
		return false
	if not Gate.is_demo():
		return true
	return Gate.index_in(Gate.arenas(), list[index]) >= 0


static func grants_tier(index: int) -> bool:
	var list := tiers()
	if index < 0 or index >= list.size():
		return false
	if not Gate.is_demo():
		return true
	return index == Gate.fixed_tier_index()


## The build gate for a selection that did NOT come from the menu: the command
## line (`--athlete=… --arena=… --tier=…`), a scene opened directly by path, or
## anything else that writes these indices before `apply_build_limits()` has run.
##
## review-2 F-2: `apply_build_limits()` had exactly one caller (`main_menu.gd:78`),
## so `godot/… Match.tscn -- --demo --athlete=5 --arena=orrery --tier=3` started a
## match on `leggenda`/`colosso`/`orrery` — three things the demo does not grant —
## and the menu's gate was simply overwritten by the match scene's own arg parsing.
##
## The menu's order is kept and a second one added, because the two answer
## different questions:
##
##   1. `apply_build_limits()` first — pin the selection into what this build
##      grants, exactly as the menu does, so a demo that is handed locked content
##      still starts on granted content;
##   2. then accept a requested item ONLY if `grants_*` says this build grants it.
##      A locked request is refused and reported by name instead of silently
##      honoured, and it does not move the selection.
##
## Returns `{"pinned": …, "refused": …, "effective": …}`: `pinned` is what
## `apply_build_limits()` changed ({} in a full build), `refused` names every
## requested item this build does not grant, `effective` is the selection the
## match will actually start with. A caller prints it; a test asserts on it.
static func apply_cli_selection(athlete_arg: String, arena_arg: String, tier_arg: String) -> Dictionary:
	var pinned := apply_build_limits()
	var refused := {}
	if athlete_arg != "":
		var requested := int(athlete_arg)
		if grants_athlete(requested):
			athlete_index = requested
			outfit_index = 0
		else:
			refused["athlete"] = requested
	if arena_arg != "":
		# The catalog's own seat answer, the same one `set_arena_id` lands on: a
		# frozen id this build grants keeps its roster index, a world id this build
		# offers takes the world seat, and a demo refuses both by name.
		var seat: Dictionary = arena_catalog().seat(arena_arg)
		var frozen_index := int(seat["index"])
		if frozen_index >= 0 and grants_arena(frozen_index):
			arena_index = frozen_index
			world_arena_id = ""
		elif bool(seat["world"]) and bool(seat["offered"]):
			# A world arena this build offers: the seat is the id itself. A demo
			# refuses it below, with everything else it does not grant.
			world_arena_id = arena_arg
		else:
			refused["arena"] = arena_arg
	if tier_arg != "":
		var requested_tier := int(tier_arg)
		if grants_tier(requested_tier):
			tier_index = requested_tier
		else:
			refused["tier"] = requested_tier
	return {
		"pinned": pinned,
		"refused": refused,
		"effective": {
			"tier_index": tier_index,
			"athlete_index": athlete_index,
			"arena_index": arena_index,
			"tier": String(tier()["id"]),
			"athlete": String(athlete()["id"]),
			"arena": String(arena()["id"]),
		},
	}


static func arena_ids() -> PackedStringArray:
	return arena_catalog().ids()


## Roster index of an arena id, or -1. The frozen table's order is the menu's order.
static func arena_index_of(id: String) -> int:
	return arena_catalog().index_of(id)


## The selected arena's id. `arena_index` stays the single piece of FROZEN state
## (nothing downstream needs to know an id was ever involved), and the world seat
## — when occupied — is the id itself.
static func arena_id() -> String:
	if world_arena_id != "":
		return world_arena_id
	return String(arena()["id"])


## Selects an arena by id. Returns false for an unknown id — and for a WORLD id
## in a demo build, which does not offer the world set at all: the caller decides
## what to do about it rather than the config silently picking something else.
## Which seat the id lands in is the catalog's answer (`seat()`), not a second rule
## here: a frozen id keeps its roster index and clears the world seat, a world id
## this build offers takes the world seat.
static func set_arena_id(id: String) -> bool:
	var seat: Dictionary = arena_catalog().seat(id)
	if int(seat["index"]) >= 0:
		arena_index = int(seat["index"])
		world_arena_id = ""
		return true
	if bool(seat["world"]) and bool(seat["offered"]):
		world_arena_id = id
		return true
	return false


static func tiers() -> Array:
	return Frozen.ai_opponents()


## The selected athlete record the match and the screens describe: the special's
## own record when the special seat is occupied (`AthleteSpawn.record`, which the
## catalogue answers for a Godot-only id), else the frozen row at `athlete_index`.
static func athlete() -> Dictionary:
	if special_athlete_id != "":
		var special: Dictionary = AthleteSpawn.record(StringName(special_athlete_id))
		if not special.is_empty():
			return special
	var list := athletes()
	return list[clampi(athlete_index, 0, list.size() - 1)]


## The selected athlete's id. `athlete_index` stays the single piece of FROZEN
## state (nothing downstream needs to know an id was ever involved), and the
## special seat — when occupied — is the id itself. Mirrors `arena_id()`.
static func athlete_id() -> String:
	if special_athlete_id != "":
		return special_athlete_id
	return String(athlete()["id"])


## The arena record the match runs on: the frozen row at `arena_index`, or — when
## the world seat is occupied — the world arena's own record
## (`Arena.world_info()`, which carries the provisional physics the sim reads).
static func arena() -> Dictionary:
	if world_arena_id != "":
		return Arena.world_info(world_arena_id)
	var list := arenas()
	return list[clampi(arena_index, 0, list.size() - 1)]


static func tier() -> Dictionary:
	var list := tiers()
	return list[clampi(tier_index, 0, list.size() - 1)]


## One colour per tier, for the scoreboard and the opponent's floor ring. The
## tiers carry no colour in `js/data.js`; this is presentation and is recorded as
## such in the evidence file.
const TIER_COLORS := [
	Color(0.54, 0.83, 1.0),
	Color(1.0, 0.821, 0.4),
	Color(1.0, 0.549, 0.0),
	Color(1.0, 0.294, 0.431),
]


static func tier_color(index: int) -> Color:
	return TIER_COLORS[clampi(index, 0, TIER_COLORS.size() - 1)]
