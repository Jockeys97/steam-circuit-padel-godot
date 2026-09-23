## ost_catalog.gd — the one catalog the Emporio prices, gates and sells.
##
## WHAT THIS IS. The OST catalog already exists and is not re-declared here:
## `godot/src/audio/soundtrack_manager.gd::TRACK_METADATA` carries every track id with
## an explicit `category`, and `all_track_ids()` enumerates it. This file is the
## *economy view* over that catalog — which tracks are free starters, which are shop
## items, and what each costs — derived from the existing category field only.
##
## PRICES COME FROM THE CATEGORY, NOT FROM THE UI. `price_of()` maps an explicit
## catalog category to a price; nothing in the shop screen decides a number. A track
## whose category this file does not know is NOT a shop item (`price_of` returns 0), so
## an unknown addition cannot silently land in the shop at a guessed price.
##
## ACHIEVEMENT-LINKED EXCLUSIONS: NONE EXIST (reported, not invented). The contract
## asks for OSTs that an objective unlocks to be excluded from the shop. `rg
## 'ost_[a-z0-9_]+' godot/src/modes/ godot/src/steam/` returns nothing: the objective
## tables never name a track id, and the soundtrack catalog carries no unlock field.
## `EXCLUDED_IDS` is therefore empty, and `exclusion_report()` says so explicitly so the
## emptiness is evidence rather than a silent omission.
##
## STARTERS. `menu`, `roster`, `training` and `victory` are the free tracks a new
## profile owns from the first launch (the contract's list). They are never sold.
##
## CROSS-SCRIPT REFERENCES are `preload` consts (see `godot/src/save/README.md`): a
## headless `--script` run does not rebuild the global class cache, so a global
## `class_name` reference would be a parse error.
extends RefCounted

const Soundtrack := preload("res://src/audio/soundtrack_manager.gd")

## The free tracks a new profile starts with (the contract's own four).
const STARTER_IDS: Array = ["ost_menu", "ost_roster", "ost_training", "ost_victory"]

## Price rungs. Two, because the catalog has two weight classes: an arena/context track
## and a special (epic/anime suite) track.
const PRICE_STANDARD: int = 150
const PRICE_SPECIAL: int = 250

## Category -> price. Read left to right; the FIRST matching rung wins. The categories
## are the exact strings `soundtrack_manager.gd::TRACK_METADATA` carries.
const STANDARD_CATEGORIES: Array = [
	"Menu & Sistema",
	"Fasi Partita",
	"Arena Frozen",
	"Arena Mondiale",
	"Arena Speciale",
]
const SPECIAL_CATEGORIES: Array = [
	"Epico / Anime Special",
	"Sawano / Titan Special",
	"Dragon Ball GT / 90s Anime",
]

## Achievement-linked tracks that must NOT be sold. Empty on purpose: see the header.
## A future objective->OST mapping is added HERE (one id per line), and the shop drops
## it automatically.
const EXCLUDED_IDS: Array = []


## Every track id in the catalog, in the catalog's own order.
static func all_ids() -> PackedStringArray:
	return Soundtrack.all_track_ids()


## The catalog's own category for a track, or `""` for an id it does not know.
static func category_of(track_id: String) -> String:
	return String(Soundtrack.track_info(track_id).get("category", ""))


## The catalog's own title for a track, or the id when the catalog has none.
static func title_of(track_id: String) -> String:
	var info: Dictionary = Soundtrack.track_info(track_id)
	var title := String(info.get("title", ""))
	return title if title != "" else track_id


## True for an id the catalog knows at all.
static func is_known(track_id: String) -> bool:
	return Soundtrack.has_track(track_id)


## True for a free starter track.
static func is_starter(track_id: String) -> bool:
	return STARTER_IDS.has(track_id)


## True for an achievement-linked exclusion (currently none).
static func is_excluded(track_id: String) -> bool:
	return EXCLUDED_IDS.has(track_id)


## The catalog price of a track: `PRICE_STANDARD` / `PRICE_SPECIAL`, or `0` when the
## track is not a shop item at all (starter, excluded, unknown, or an unrecognised
## category). `0` is the single "not for sale" answer, so a caller never has to ask
## three questions in a particular order.
static func price_of(track_id: String) -> int:
	if not is_known(track_id) or is_starter(track_id) or is_excluded(track_id):
		return 0
	var category := category_of(track_id)
	if STANDARD_CATEGORIES.has(category):
		return PRICE_STANDARD
	if SPECIAL_CATEGORIES.has(category):
		return PRICE_SPECIAL
	return 0


## True when the track belongs on the shop shelf.
static func is_shop_item(track_id: String) -> bool:
	return price_of(track_id) > 0


## The shop shelf, in catalog order: only the tracks a player can buy.
static func shop_ids() -> Array:
	var out: Array = []
	for id in all_ids():
		if is_shop_item(id):
			out.append(String(id))
	return out


## The starter tracks, in catalog order.
static func starter_ids() -> Array:
	var out: Array = []
	for id in all_ids():
		if is_starter(String(id)):
			out.append(String(id))
	return out


## One shop row: id, title, category, price. `owned` is NOT decided here — ownership is
## the economy service's, and this catalog only prices the shelf.
static func shop_rows() -> Array:
	var out: Array = []
	for id in shop_ids():
		out.append({
			"id": id,
			"title": title_of(id),
			"category": category_of(id),
			"price": price_of(id),
		})
	return out


## The exclusion evidence, for a report or a test: how many objective-linked OSTs were
## found and which. An empty `ids` with a stated reason is the honest answer here.
static func exclusion_report() -> Dictionary:
	return {
		"ids": EXCLUDED_IDS.duplicate(),
		"count": EXCLUDED_IDS.size(),
		"reason": (
			"no objective->OST mapping exists in godot/src/modes/** or godot/src/steam/**"
			if EXCLUDED_IDS.is_empty() else "objective-linked tracks excluded from the shop"
		),
	}


## A summary of the shelf for a report or a test.
static func catalog_report() -> Dictionary:
	var by_category: Dictionary = {}
	for id in all_ids():
		var category := category_of(String(id))
		by_category[category] = int(by_category.get(category, 0)) + 1
	var standard := 0
	var special := 0
	for id in shop_ids():
		if price_of(String(id)) == PRICE_STANDARD:
			standard += 1
		else:
			special += 1
	return {
		"tracks": all_ids().size(),
		"starters": starter_ids().size(),
		"shop_items": shop_ids().size(),
		"standard": standard,
		"special": special,
		"excluded": EXCLUDED_IDS.size(),
		"by_category": by_category,
	}
