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
## Which tournament round a mode match plays. -1 means "whatever the save holds"
## (`ModesSave.tournament_round`), which is the normal path: the bracket is
## persisted, so the round is a fact about the save rather than about this call.
static var pending_round: int = -1
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
		var index := arena_index_of(arena_arg)
		if index >= 0 and grants_arena(index):
			arena_index = index
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
	var out := PackedStringArray()
	for row in arenas():
		out.append(String(row["id"]))
	return out


## Roster index of an arena id, or -1. The frozen table's order is the menu's order.
static func arena_index_of(id: String) -> int:
	var list := arenas()
	for i in list.size():
		if String((list[i] as Dictionary)["id"]) == id:
			return i
	return -1


## The selected arena's id. `arena_index` stays the single piece of state, so
## nothing downstream needs to know an id was ever involved.
static func arena_id() -> String:
	return String(arena()["id"])


## Selects an arena by id. Returns false for an unknown id: the caller decides
## what to do about it rather than the config silently picking something else.
static func set_arena_id(id: String) -> bool:
	var index := arena_index_of(id)
	if index < 0:
		return false
	arena_index = index
	return true


static func tiers() -> Array:
	return Frozen.ai_opponents()


static func athlete() -> Dictionary:
	var list := athletes()
	return list[clampi(athlete_index, 0, list.size() - 1)]


static func arena() -> Dictionary:
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
