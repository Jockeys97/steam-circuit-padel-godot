extends RefCounted
## Arenas offered in the Emporio (2026-09-26): the six career-gated arenas rebuilt from the
## owner's covers and Meshy props, sold as an expensive alternative to the career route.
## The career route (trophies/stars) stays exactly as it is and free; a purchase is an
## independent unlock, the same pattern as the challenge outfits.
##
## Only arenas with a career wall are for sale: `locomotive` (the rebuilt "Sopraelevata
## della Luna") is open from the start and has nothing to sell. Prices climb with the
## career wall they skip and never come from the UI.

const Frozen := preload("res://src/sim/frozen.gd")
const Art := preload("res://src/ui/data/UiArtPaths.gd")

const PRICES := {
	"cattedrale": 1500, # 2 trophies
	"forgia": 1800,     # 10 stars
	"tempesta": 2100,   # 3 trophies
	"abissale": 2400,   # 14 stars
	"caldera": 2700,    # 4 trophies
	"orrery": 3200,     # 5 trophies + 18 stars
}


## The shelf, in the frozen roster's own order: id, locale keys, cover, career wall, price.
static func shop_rows() -> Array:
	var rows: Array = []
	for entry in Frozen.arenas():
		var arena: Dictionary = entry
		var id := String(arena.get("id", ""))
		if not PRICES.has(id) or arena.get("unlock") == null:
			continue
		rows.append({
			"id": id,
			"name_key": "arena_%s_name" % id,
			"desc_key": "arena_%s_desc" % id,
			"art_path": Art.path_for("arenas", id),
			"unlock": (arena["unlock"] as Dictionary).duplicate(true),
			"price": int(PRICES[id]),
		})
	return rows


static func row_for(arena_id: String) -> Dictionary:
	for row in shop_rows():
		if String(row["id"]) == arena_id:
			return row
	return {}


static func is_known(arena_id: String) -> bool:
	return not row_for(arena_id).is_empty()


static func price_of(arena_id: String) -> int:
	return int(row_for(arena_id).get("price", 0))


## The frozen row itself, for the career rule (`CareerRules.is_unlocked`).
static func frozen_row(arena_id: String) -> Dictionary:
	for entry in Frozen.arenas():
		if String((entry as Dictionary).get("id", "")) == arena_id:
			return entry
	return {}
