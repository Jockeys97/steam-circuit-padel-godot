extends RefCounted
## Challenge outfits and Godot-only shop kits offered in the Emporio.
## Existing challenge outfits keep their free route.
## Prices are deliberately well above the 150/250 CC OST rungs and never come from UI.

const ModeTables := preload("res://src/modes/mode_tables.gd")
const OutfitCatalogue := preload("res://src/character/outfit_catalogue.gd")

const PRICES := {
	"circuit": 600,
	"legend": 900,
	"signature": 1200,
	"mythic": 1800,
	"solar_sprint": 750,
	"polar_ace": 750,
}


static func shop_rows() -> Array:
	var rows: Array = []
	for athlete_id in ModeTables.outfits():
		for entry in ModeTables.playable_outfits_for_athlete(String(athlete_id)):
			var outfit: Dictionary = entry
			var outfit_id := String(outfit.get("id", ""))
			var key := String(outfit.get("unlockKey", ""))
			var shop_only := bool(outfit.get("shopOnly", false))
			if not PRICES.has(outfit_id) or (not shop_only and not (outfit.get("challenge") is Dictionary)) or key != "%s:%s" % [athlete_id, outfit_id]:
				continue
			rows.append({
				"id": key,
				"athlete_id": String(athlete_id),
				"outfit_id": outfit_id,
				"name_key": String(outfit.get("nameKey", "")),
				"challenge": {} if shop_only else (outfit["challenge"] as Dictionary).duplicate(true),
				"shop_only": shop_only,
				"price": int(PRICES[outfit_id]),
				"supported": OutfitCatalogue.is_renderable(StringName(athlete_id), StringName(outfit_id)),
			})
	return rows


static func row_for(unlock_key: String) -> Dictionary:
	for row in shop_rows():
		if String(row["id"]) == unlock_key:
			return row
	return {}


static func price_of(unlock_key: String) -> int:
	var row := row_for(unlock_key)
	return int(row.get("price", 0)) if bool(row.get("supported", false)) else 0
