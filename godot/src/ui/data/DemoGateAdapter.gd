## DemoGateAdapter.gd — the thin wrapper a screen asks about the build's content rule.
##
## WHY A WRAPPER AND NOT THE GATE ITSELF. `godot/game/content_gate.gd` is already the
## one place in `godot/game/**` that knows where the export lane's build tables live
## (`godot/tests/build/**`), and it already delegates every answer to them. What it does
## not give a screen is the two shapes a UI needs and a data layer should not: a build
## *label* for the badge, and lookups by id for a row a screen already has. Those two
## additions are the whole of this file; nothing here re-derives a rule.
##
##   `js/ui.js:734` — "vedere cosa manca vende piu' che nasconderlo": a listed item this
##   build does not grant stays visible and is rendered locked. `locked()` is that
##   question, asked by id.
##
## The reference's own badge logic (`js/ui.js:742-750`) calls the badge by the build's
## name (`demoBadge` for a demo, `betaBadge` for a beta) and hides it entirely in a full
## build; the port has one flag (`godot/tests/build/BuildFlag.gd`, ported from
## `js/build.js:19-35`), so `build()` answers `demo` or `full` and the unreachable third
## value is recorded rather than invented — see the audit's note.
extends RefCounted

const Gate := preload("res://game/content_gate.gd")
const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const Frozen := preload("res://src/sim/frozen.gd")

const KIND_ATHLETE := "athlete"
const KIND_ARENA := "arena"


## `BUILD` (`js/build.js:19-35`): this port has two reachable values, not three.
static func build() -> String:
	return "demo" if BuildFlag.is_demo() else "full"


## The badge a build shows. A full build shows none (`js/ui.js:744-749` hides it).
static func badge_text_key() -> String:
	return "demoBadge"


## The two keys the reference's badge logic selects between (`js/ui.js:742-750`).
const BADGE_DEMO_KEY := "demoBadge"
const BADGE_BETA_KEY := "betaBadge"


## `js/ui.js:744`: `BUILD === "beta" ? "betaBadge" : "demoBadge"`, asked for a build's own
## name. The port reaches `demo` and `full` (`BuildFlag.is_demo()`); `beta` exists in the
## reference and is unreachable here, so a caller that wants the beta key gets it and the
## caller decides what an unresolvable key means (UIR-07's capture states pin it; the
## locale table has no `betaBadge`, which the evidence records as a visible fallback).
static func badge_text_key_for(build_id: String) -> String:
	match build_id:
		"demo":
			return BADGE_DEMO_KEY
		"beta":
			return BADGE_BETA_KEY
	return ""


static func badge_visible() -> bool:
	return BuildFlag.is_demo()


## `demoLocked(item, allowed)` (`js/build.js:73-75`), asked by id: the row's own id is
## looked up in the frozen table it belongs to, and the answer is the gate's. An id the
## frozen tables do not hold is still asked about — the reference asks about the id it
## was handed, and a demo locks what it does not list — while a **kind** the gate has no
## branch for is not a question this adapter forwards: the gate folds every unknown kind
## into its arena branch (`content_gate.gd::is_locked`), which would tell a screen that
## the unknown kind is locked. Declining is honest; propagating that would be a rule
## invented here.
static func locked(item_id: String, kind: String) -> bool:
	if item_id == "" or not _known_kind(kind):
		return false
	var item := _item_of(item_id, kind)
	if item.is_empty():
		item = {"id": item_id}
	return Gate.is_locked(item, kind)


static func _known_kind(kind: String) -> bool:
	return kind == KIND_ATHLETE or kind == KIND_ARENA


## `js/ui.js:759-766`: a mode this build does not grant is shown locked, not removed.
static func mode_locked(mode_id: String) -> bool:
	return not Gate.modes().has(mode_id)


## `applyDemoLimits` (`js/ui.js:763-769`): a demo pins one difficulty; a full build
## leaves every rung available (`fixed_tier_index()` is -1 there).
static func difficulty_allowed(tier_key: String) -> bool:
	var fixed := Gate.fixed_tier_index()
	if fixed < 0:
		return true
	var wanted: Variant = Gate.DIFFICULTY_TIERS.get(tier_key)
	return wanted != null and int(wanted) == fixed


## The ids this build exposes for a kind: the athletes/arenas it lists, the modes it
## offers. Ids only; the order is the frozen tables' own.
static func exposed_ids(kind: String) -> Array:
	match kind:
		KIND_ATHLETE:
			return _ids_of(Gate.roster())
		KIND_ARENA:
			return _ids_of(Gate.arenas())
		"mode":
			return Gate.modes()
	return []


## The full roster/arena list the frozen tables hold, so a screen can render what the
## build withholds (the reference's own "show what is missing" rule).
static func all_ids(kind: String) -> Array:
	match kind:
		KIND_ATHLETE:
			return _ids_of(Frozen.athletes())
		KIND_ARENA:
			return _ids_of(Frozen.arenas())
	return []


static func _item_of(item_id: String, kind: String) -> Dictionary:
	var items: Array = []
	match kind:
		KIND_ATHLETE:
			items = Frozen.athletes()
		KIND_ARENA:
			items = Frozen.arenas()
		_:
			return {}
	for item in items:
		if String((item as Dictionary).get("id", "")) == item_id:
			return item
	return {}


static func _ids_of(items: Array) -> Array:
	var out: Array = []
	for item in items:
		out.append(String((item as Dictionary).get("id", "")))
	return out
