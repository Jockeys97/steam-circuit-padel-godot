extends RefCounted
class_name CustomCharacter
## CustomCharacter — the one persistent, player-made athlete's appearance record.
##
## The record is small and versioned, never a generated model and never a raw path:
##
##     {
##       "schema_version": 1,
##       "display_name": "ALBA",
##       "skin_id": "tan",
##       "hair_id": "ponytail",
##       "hair_color_id": "brown",
##       "outfit_id": "circuit",
##       "outfit_color_id": "coral",
##     }
##
## Every choice is a bounded id from a table below, so a save from another build
## can only ever land on an id this build knows or on the documented default — a
## corrupt or stale file is normalized, never trusted and never fatal.
##
## The athlete itself has a stable synthetic id (`ID`) that is the same at the
## roster, selection and match boundary. Its gameplay stats are the frozen
## `roster_average` preset (`src/sim/frozen.gd::roster_average`), so every cosmetic
## choice is exactly that: cosmetic. Customization cannot move a stat.

const ID := &"custom_one"

const SCHEMA_VERSION := 1

## The Meshy bodies (2026-09-27, `custom_body_look.gd`), in editor order. Each maps to a
## rig id `cc_<body>` in `athlete_rig.gd::ATHLETE_GLB`.
const BODIES := [&"donna_media", &"donna_atletica", &"uomo_medio", &"uomo_robusto", &"uomo_b"]
const DEFAULT_BODY := &"donna_media"
const DEFAULT_SKIN := &"tan"
const DEFAULT_HAIR := &"ponytail"
const DEFAULT_HAIR_COLOR := &"brown"
const DEFAULT_OUTFIT := &"circuit"
const DEFAULT_OUTFIT_COLOR := &"coral"
const DEFAULT_NAME := "ALBA"
const NAME_MAX_LENGTH := 14

## Skin tones, in editor order.
const SKINS := {
	&"porcelain": Color("f4d6c2"),
	&"light": Color("e8bd97"),
	&"tan": Color("c98f63"),
	&"olive": Color("a9714a"),
	&"brown": Color("7d4f34"),
	&"deep": Color("523424"),
}

## Hair colours, in editor order.
const HAIR_COLORS := {
	&"black": Color("1b1a1c"),
	&"brown": Color("5a3a24"),
	&"blonde": Color("d8b56a"),
	&"auburn": Color("8c3f21"),
	&"grey": Color("b9bcc2"),
	&"violet": Color("6b3fa0"),
}

## Outfit colours, in editor order. This is the garment's main colour; the kit also
## paints a fixed accent so a two-tone kit reads as designed, not as one tint.
const OUTFIT_COLORS := {
	&"coral": Color("d94e42"),
	&"azure": Color("2f6fb8"),
	&"violet": Color("7a4fd0"),
	&"lime": Color("8fbf3f"),
	&"graphite": Color("3a3f46"),
	&"sand": Color("d9b98a"),
}

## Hair geometry variants (>= 2), in editor order. Each is a different part set in
## `custom_character_kit.gd`, not a recolour of one shape.
const HAIRS := [&"buzz", &"crop", &"ponytail", &"curly", &"bun"]

## Outfit geometry variants (>= 2), in editor order. Different garment geometry:
## a sleeved tee-and-shorts kit versus a tank-and-skirt kit versus a one-piece.
const OUTFITS := [&"circuit", &"training", &"varsity"]

const DEFAULT_RECORD := {
	"schema_version": SCHEMA_VERSION,
	"display_name": DEFAULT_NAME,
	"body_id": "donna_media",
	"skin_id": "tan",
	"hair_id": "ponytail",
	"hair_color_id": "brown",
	"outfit_id": "circuit",
	"outfit_color_id": "coral",
}

## Fixed secondary garment colour per outfit variant, so the two-tone kit is a
## design decision and not a second free slider.
const OUTFIT_ACCENTS := {
	&"circuit": Color("1f2833"),
	&"training": Color("f2e6d0"),
	&"varsity": Color("f4f1ea"),
}

const SHOE_COLOR := Color("23262b")


# =========================================================================
# Ids
# =========================================================================

static func option_ids(field: String) -> Array:
	match field:
		"body_id":
			return BODIES.duplicate()
		"skin_id":
			return SKINS.keys()
		"hair_id":
			return HAIRS.duplicate()
		"hair_color_id":
			return HAIR_COLORS.keys()
		"outfit_id":
			return OUTFITS.duplicate()
		"outfit_color_id":
			return OUTFIT_COLORS.keys()
	return []


## True when `value` is a legal id for this field. Used by the editor to refuse a
## step onto an unknown id and by `normalize()` to fall back.
static func has_option(field: String, value: StringName) -> bool:
	return option_ids(field).has(value)


static func default_option(field: String) -> StringName:
	match field:
		"body_id":
			return DEFAULT_BODY
		"skin_id":
			return DEFAULT_SKIN
		"hair_id":
			return DEFAULT_HAIR
		"hair_color_id":
			return DEFAULT_HAIR_COLOR
		"outfit_id":
			return DEFAULT_OUTFIT
		"outfit_color_id":
			return DEFAULT_OUTFIT_COLOR
	return &""


# =========================================================================
# Record
# =========================================================================

static func defaults() -> Dictionary:
	return DEFAULT_RECORD.duplicate(true)


## Coerces anything (a corrupt file, an older schema, a hand-built dictionary) into
## a record this build can render. Unknown ids, wrong types and missing keys all
## resolve to the documented default for their field. Never returns null.
static func normalize(source: Variant) -> Dictionary:
	var out := defaults()
	if not (source is Dictionary):
		return out
	var raw: Dictionary = source
	var version_value: Variant = raw.get("schema_version", 0)
	var version := int(version_value) if version_value is int or version_value is float else 0
	# The reader is forward-compatible by design: an older or unknown version is
	# normalized field by field, which is exactly what a future schema wants too.
	if version > SCHEMA_VERSION:
		out["_source_schema_version"] = version
	out["schema_version"] = SCHEMA_VERSION
	var display_name: Variant = raw.get("display_name", DEFAULT_NAME)
	out["display_name"] = sanitize_name(display_name if display_name is String else DEFAULT_NAME)
	for field in ["body_id", "skin_id", "hair_id", "hair_color_id", "outfit_id", "outfit_color_id"]:
		var candidate: Variant = raw.get(field, "")
		var value := StringName(candidate) if candidate is String or candidate is StringName else &""
		out[field] = String(value) if has_option(field, value) else String(default_option(field))
	return out


## A display name is shown on the roster card and on the match HUD, so it is held to
## one line of plain text: trimmed, collapsed whitespace, upper case, length-bounded.
## An empty result is the default name, never an empty label.
static func sanitize_name(text: String) -> String:
	var stripped := text.strip_edges()
	var collapsed := ""
	var space_pending := false
	for i in stripped.length():
		var ch := stripped[i]
		if ch == " " or ch == "\t" or ch == "\n":
			space_pending = collapsed.length() > 0
			continue
		if space_pending:
			collapsed += " "
			space_pending = false
		collapsed += ch
	if collapsed.length() > NAME_MAX_LENGTH:
		collapsed = collapsed.substr(0, NAME_MAX_LENGTH)
	collapsed = collapsed.strip_edges().to_upper()
	return collapsed if collapsed != "" else DEFAULT_NAME


## True when the record is already exactly what `normalize()` would return: no id
## out of table, no name that would be rewritten. The editor uses this to decide
## whether Save has anything to write.
static func is_canonical(record: Dictionary) -> bool:
	return record == normalize(record)


static func colors(record: Dictionary) -> Dictionary:
	var r := normalize(record)
	return {
		"skin": SKINS[StringName(r["skin_id"])],
		"hair": HAIR_COLORS[StringName(r["hair_color_id"])],
		"outfit": OUTFIT_COLORS[StringName(r["outfit_color_id"])],
		"accent": OUTFIT_ACCENTS.get(StringName(r["outfit_id"]), Color("1f2833")),
		"shoe": SHOE_COLOR,
	}


## One-line signature of the appearance, used by tests and by the evidence dump to
## prove two records really differ without comparing floats.
static func signature(record: Dictionary) -> String:
	var r := normalize(record)
	return "%s|%s|%s|%s|%s|%s" % [
		r["body_id"], r["skin_id"], r["hair_id"], r["hair_color_id"],
		r["outfit_id"], r["outfit_color_id"],
	]


# =========================================================================
# Gameplay-facing facts
# =========================================================================

## The frozen, documented balanced preset this athlete plays with. Read from
## `rosterAverage`, not invented here: the numbers move only if `data.json` moves.
static func stats() -> Dictionary:
	const Frozen := preload("res://src/sim/frozen.gd")
	var average := Frozen.roster_average()
	return average.duplicate(true) if not average.is_empty() else {}


## The description row the roster screens consume. The custom athlete is not one of
## the six, so it is described here rather than by touching the frozen catalogue.
static func roster_row(record: Dictionary) -> Dictionary:
	var r := normalize(record)
	return {
		"id": String(ID),
		"name": r["display_name"],
		"custom": true,
		"stats": stats(),
		"appearance": r,
	}



## The rig id of the record's Meshy body (`athlete_rig.gd::ATHLETE_GLB`).
static func body_rig_id(record: Dictionary) -> StringName:
	return StringName("cc_" + String(normalize(record)["body_id"]))
