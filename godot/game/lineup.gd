## lineup.gd — who is on court: the four athletes of a quick match.
##
## Port of `resolveLineup` (`js/ui.js:548-590`), the function the reference calls
## before it builds a match (`js/main.js:1118`). The rule, in the reference's own
## words and order:
##
##   - the three non-player slots are picked from `selectableAthletes()`, i.e. the
##     athletes THIS BUILD grants and the career has unlocked (`js/ui.js:485-487`);
##   - `playerMate`, `opponent` and `opponentMate` may be dictated by the calendar
##     or the board when the mode has one (`dictatedRivals`, `js/ui.js:531-546`);
##   - in quick match nothing dictates them, so the position is filled by the first
##     FREE reserve;
##   - the fallback pool is the FULL roster, not the exposed one: "il ripiego pesca
##     dal roster intero: nella demo si gioca con due atleti e si affrontano gli
##     altri" (`js/ui.js:551-554`). So a demo of two athletes still meets the other
##     four, which is what the browser does;
##   - nobody appears twice: each pick is checked against the athletes already on
##     court (`usati`, `js/ui.js:559-575`);
##   - a match between four different athletes is the normal case even with no
##     selection made, which is what the `libero()` fallback (`:579-583`) is for.
##
## The dictated path IS wired (`CareerRules.dictated_rivals`, the same rule the
## reference calls at `js/ui.js:559`): a career or tournament caller passes the
## pair the calendar or the board decided, and it takes the two opponent slots
## AHEAD of any stored preference — a rival you can re-pick is not a dictated
## one. A caller with no dictated pair (`null`, every quick match) gets exactly
## the old behaviour, so the quick-match lineup is untouched.
##
## Outfits: the reference stores the equipped outfit per athlete id
## (`equippedOutfits`) and applies it at this one point (`athleteWithOutfit`,
## `js/ui.js:587-589`). Live matches pass the saved career to resolve all four
## selections with the same unlock rules as the wardrobe.
extends RefCounted

const Frozen := preload("res://src/sim/frozen.gd")
const Gate := preload("res://game/content_gate.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const ModeTables := preload("res://src/modes/mode_tables.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")

## The four slots, in the reference's own order.
const ROLES := ["player", "playerMate", "opponent", "opponentMate"]
## The three the reference's `resolveLineup` fills (the player is the choice).
const FILLED := ["playerMate", "opponent", "opponentMate"]


## `{role: athlete_dict}`. `player` is the athlete the menu selected; the other
## three come from the rule above. `dictated` is `{opponent, opponentMate}` or
## empty/null.
static func resolve(player: Dictionary, dictated: Variant = null, career: Dictionary = {}) -> Dictionary:
	var relocked := bool(career.get("lockAll", false))
	if relocked and not CareerRules.is_unlocked(player, career):
		for candidate in Gate.roster():
			if CareerRules.is_unlocked(candidate, career):
				player = candidate
				break
	var out := {"player": player}
	var roster: Array = Frozen.athletes()
	var used := {String(player["id"]): true}
	# A slot the screen chose explicitly wins if it is exposed, is not the player
	# and is not already on court (`scelto(ui.lineup[ruolo])`, js/ui.js:569).
	var dettati: Dictionary = dictated if dictated is Dictionary else {}
	for role in FILLED:
		# `js/ui.js:559-565`: the dictated pair is asked for first, the stored
		# preference only for a slot nobody dictated (the second player).
		var chosen: Variant = dettati.get(role, null)
		if chosen == null:
			chosen = _pref(role)
		if chosen == null:
			continue
		if relocked and not CareerRules.is_unlocked(chosen, career):
			continue
		if used.has(String((chosen as Dictionary)["id"])):
			continue
		out[role] = chosen
		used[String((chosen as Dictionary)["id"])] = true
	# The reserve pool is the FULL roster minus the player (`js/ui.js:578`).
	var reserves: Array = []
	for athlete in roster:
		if relocked and not CareerRules.is_unlocked(athlete, career):
			continue
		if String(athlete["id"]) != String(player["id"]):
			reserves.append(athlete)
	for role in FILLED:
		if out.has(role):
			continue
		out[role] = _free(reserves, used, player)
		used[String((out[role] as Dictionary)["id"])] = true
	return out


## Saved per-athlete choices for live matches; explicit player override and base
## reserves for older diagnostic callers that omit the career.
static func outfits(lineup: Dictionary, player_outfit: StringName, career: Variant = null) -> Dictionary:
	var out := {}
	for role in ROLES:
		if not lineup.has(role):
			continue
		if career is Dictionary:
			out[role] = equipped_outfit(String(lineup[role]["id"]), career)
			# Quick-match's explicit outfit cycle may override the wardrobe choice,
			# but never bypass an achievement lock. Base means no explicit override.
			if role == "player" and player_outfit != &"base":
				for outfit in ModeTables.playable_outfits_for_athlete(String(lineup[role]["id"])):
					if StringName(outfit.get("id", "")) == player_outfit and CareerRules.is_unlocked(outfit, career):
						out[role] = player_outfit
						break
		elif role == "player":
			out[role] = player_outfit
		else:
			out[role] = &"base"
	return out


## Same persisted selection and unlock check as the wardrobe, for every court role.
## The optional career argument above preserves explicit legacy/capture callers.
static func equipped_outfit(athlete_id: String, career: Dictionary) -> StringName:
	var equipped: Variant = career.get("equippedOutfits", {})
	var wanted := String(equipped.get(athlete_id, "base")) if equipped is Dictionary else "base"
	for outfit in ModeTables.playable_outfits_for_athlete(athlete_id):
		if String(outfit.get("id", "")) == wanted and CareerRules.is_unlocked(outfit, career):
			return StringName(wanted)
	return &"base"


## The id of each slot, for logs and for the slice test.
static func ids(lineup: Dictionary) -> Dictionary:
	var out := {}
	for role in lineup:
		out[role] = String((lineup[role] as Dictionary)["id"])
	return out


## `libero()` (`js/ui.js:579-583`): the first reserve not already occupied, else
## the first reserve, else the player.
static func _free(reserves: Array, used: Dictionary, player: Dictionary) -> Dictionary:
	for athlete in reserves:
		if not used.has(String(athlete["id"])):
			return athlete
	if reserves.size() > 0:
		return reserves[0]
	return player


## `ui.lineup[role]` (`js/main.js:2218-2226`): an athlete the player picked in the
## team screen, and only if it still exists in the roster. The port has no team
## screen yet, so this reads the prefs the save module already carries.
##
## The pool is the exposed roster PLUS the specials THIS build offers
## (`Gate.special_athletes()`, empty in a demo): the team screen's special strip
## can assign one to any slot, and a preference the resolver dropped would make
## that pick silently revert. The two lists stay separate — a special is never
## added to `Gate.roster()`, whose size the slice pins.
static func _pref(role: String) -> Variant:
	var prefs: Variant = _PREF_SOURCE
	if prefs == null:
		return null
	var lineup: Variant = prefs.get("lineup")
	if lineup == null or typeof(lineup) != TYPE_DICTIONARY:
		return null
	var id: Variant = lineup.get(role)
	if typeof(id) != TYPE_STRING:
		return null
	for athlete in Gate.roster() + Gate.special_athletes():
		if String(athlete["id"]) == String(id):
			return athlete
	return null


## Where the lineup preference comes from, when one exists. `null` today: the team
## screen is not ported. Kept as one named seam instead of a dead branch scattered
## through the rule, and asserted by the slice test to be either null or the
## save-backed prefs dictionary.
static var _PREF_SOURCE: Variant = null


static func set_pref_source(source: Variant) -> void:
	_PREF_SOURCE = source
