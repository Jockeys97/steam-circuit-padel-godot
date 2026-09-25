## UiArtPaths.gd — where a UI screen's artwork lives, and whether it is there yet.
##
## UIR-01 OWNS THE FILES; THIS FILE ONLY KNOWS THE NAMES. `godot/assets/ui/**` is the
## asset ticket's namespace, and the names below were read off that directory rather
## than invented:
##
##   athletes/<id>.webp                        one per frozen athlete id
##   athletes/<id>.png                         one per GODOT-ONLY special athlete
##                                             (a byte copy of the Meshy front view,
##                                             see `src/character/specials.gd`)
##   arenas/<slug>.webp                        the slug is NOT the arena id
##   modes/quick-match|career|tournament.webp  the reference's three mode cards
##
## A row NEVER points at a file that is not on disk. `path_for()` answers `""` when
## the asset has not landed, or when its name is not in the tables below, so a screen
## renders its own empty state instead of a broken texture — and the audit can assert
## that every non-empty path the adapter hands over really exists. The two arenas whose
## UI art had not landed when this table was written (`cattedrale`, `forgia`) are
## therefore absent from `ARENAS` on purpose: a guess here would be an invented asset
## path, which is worse than a blank card.
extends RefCounted

const ROOT := "res://assets/ui"
const Specials := preload("res://src/character/specials.gd")

## Mode id -> file stem, in the reference's own mode order. `quick-match.webp` is the
## one whose stem differs from its id.
const MODES := {
	"quick": "quick-match",
	"tournament": "tournament",
	"career": "career",
}

## Arena id -> file stem, as UIR-01 named them. An id missing here has no UI art yet;
## `path_for()` reports `""` and the consuming screen shows its own fallback.
const ARENAS := {
	"officina": "officina-vapore-standard",
	"locomotive": "sopraelevata-della-luna",
	"clockwork": "clockwork-factory",
	"tempesta": "bastione-tempesta",
	"abissale": "santuario-abissale",
	"caldera": "caldera-titano",
	"orrery": "orrery-celeste",
}


## The path this table would use for `kind`/`id`, whether or not the file exists.
## The audit compares this convention's shape; screens use `path_for()`.
static func candidate_for(kind: String, id: String) -> String:
	match kind:
		"athletes":
			if id == "":
				return ""
			# A special athlete has no UIR-01 webp: his portrait is the Meshy front
			# view, copied byte for byte into the same namespace with its own
			# extension. The frozen six keep the webp convention untouched.
			if Specials.has(id):
				return "%s/athletes/%s.png" % [ROOT, id]
			return "%s/athletes/%s.webp" % [ROOT, id]
		"arenas":
			if not ARENAS.has(id):
				return ""
			return "%s/arenas/%s.webp" % [ROOT, String(ARENAS[id])]
		"modes":
			if not MODES.has(id):
				return ""
			return "%s/modes/%s.webp" % [ROOT, String(MODES[id])]
	return ""


## The art for `kind`/`id` when the file is on disk, `""` otherwise.
static func path_for(kind: String, id: String) -> String:
	var candidate := candidate_for(kind, id)
	if candidate == "" or not FileAccess.file_exists(candidate):
		return ""
	return candidate


## The ids of `kind` this table knows a name for, whether or not the file exists.
static func outfit_path_for(athlete_id: String, outfit_id: String) -> String:
	if outfit_id != "base" and athlete_id.is_valid_identifier() and outfit_id.is_valid_identifier():
		var candidate := "%s/outfits/%s/%s-preview.webp" % [ROOT, athlete_id, outfit_id]
		if ResourceLoader.exists(candidate):
			return candidate
	return path_for("athletes", athlete_id)


static func named_ids(kind: String) -> Array:
	match kind:
		"arenas":
			var out: Array = ARENAS.keys()
			out.sort()
			return out
		"modes":
			var modes: Array = MODES.keys()
			modes.sort()
			return modes
	return []
