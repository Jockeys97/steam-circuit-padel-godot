extends RefCounted
class_name SaveSchema
## The port's save schema — the shape of one profile on disk.
##
## Mirrors, field for field, what the frozen browser reference persists in
## `localStorage` (`js/ui.js:7-11`, five keys). Nothing here is invented: every
## constant below cites the reference line it was read from.
##
## Frozen reference: commit 2979588 (`js/` is read-only for this lane).
##
## The five keys, one save group each:
##
##   | group    | reference key    | loader                       |
##   |----------|------------------|------------------------------|
##   | prefs    | `padel.prefs`    | `js/ui.js:405-442`           |
##   | career   | `padel.career`   | `js/ui.js:38-54`             |
##   | history  | `padel.history`  | `js/ui.js:1540-1561`         |
##   | drill    | `padel.drill`    | `js/ui.js:206-230`           |
##   | feedback | `padel.feedback` | `js/ui.js:244-260, 316-333`  |
##
## Envelope (every group file):
##
##   {
##     "format":        "padel-save",     # tag; a foreign file is not a save
##     "schemaVersion": 1,                # int; decides migration
##     "build":         "alpha-0.2",      # js/data.js:20 VERSION.build
##     "balance":       "b7",             # js/data.js:20 VERSION.balance
##     "payload":       <group payload>   # the JSON the browser stored
##   }
##
## One file per group under `user://save/` — see `SaveStore` and `README.md`.
##
## PORT ADDITION (Emporio OST). The reference has five keys and `group_names()`
## still returns exactly those five — `js/ui.js:7-11` is not widened. The port adds
## ONE group of its own, `economy` (wallet + owned OSTs + award receipts, see
## `godot/src/economy/economy_service.gd`), declared in `GROUP_FILES`/`GROUP_TYPES`
## and listed by `port_group_names()` = `group_names()` + `["economy"]`. The whole
## profile read/write and the cloud backup enumerate `port_group_names()`, so the
## economy group is part of a real backup — it is only the *reference key count*
## that stays five.

## Bumped only when the *envelope/payload shape* changes. The browser had no
## schema version at all; v0 below is that unversioned shape, so migration has
## a real from-state rather than a fictional one.
const CURRENT_SCHEMA_VERSION: int = 1

## Tag written into every envelope. A parsed object without it that also has no
## `schemaVersion` is treated as v0 (the browser's bare payload).
const FORMAT_TAG: String = "padel-save"

## The pace ladder owns its own default, so this file stores the id rather than a
## second copy of the choice (`src/sim/pace.gd`). Pure data module: it preloads
## nothing, so the save layer gains no dependency beyond the one constant.
const Pace := preload("res://src/sim/pace.gd")

## Writing build, read from the frozen reference so the save records which build
## wrote it — the same thing the feedback diagnostics already carry.
const BUILD: String = "alpha-0.2" ## js/data.js:20 VERSION.build
const BALANCE: String = "b7" ## js/data.js:20 VERSION.balance

## Directory under `user://`. `user://` is Godot's per-user writable root; the
## browser's equivalent was the origin's `localStorage`.
const SAVE_DIR: String = "user://save"

## group -> file basename. One file per key group, so a corrupt file costs one
## group, not the profile.
const GROUP_FILES: Dictionary = {
	"prefs": "prefs.json",
	"career": "career.json",
	"history": "history.json",
	"drill": "drill.json",
	"feedback": "feedback.json",
	"economy": "economy.json",
}

## Payload JSON type expected per group (Godot type via TYPE_* constants).
const GROUP_TYPES: Dictionary = {
	"prefs": TYPE_DICTIONARY,
	"career": TYPE_DICTIONARY,
	"history": TYPE_ARRAY,
	"drill": TYPE_DICTIONARY,
	"feedback": TYPE_ARRAY,
	"economy": TYPE_DICTIONARY,
}

## History is capped at 20 entries by the reference (`js/ui.js:1551`).
const HISTORY_CAP: int = 20

## Feedback queue is capped by `FEEDBACK.maxQueued` (`js/data.js:73`).
const FEEDBACK_MAX_QUEUED: int = 40

## Feedback topics (`js/data.js:78`), carried because the queue entry's `topic`
## is validated against them when the queue is built.
const FEEDBACK_TOPICS: Array = ["bug", "balance", "controls", "performance", "idea", "other"]

## Default career, verbatim from `js/ui.js:12-36`. The reference merges a stored
## career over exactly this object (`js/ui.js:41`), so an older or partial save
## gains defaults instead of becoming an empty profile.
const CAREER_DEFAULTS: Dictionary = {
	"season": 1,
	"matchIndex": 0,
	"wins": 0,
	"losses": 0,
	"trophies": 0,
	"stars": 0,
	"seasonObjectives": [],
	"seasonStars": 0,
	"rivalStreak": 0,
	"seasonWins": 0,
	"seasonProgress": {
		"pointsWon": 0,
		"winners": 0,
		"smashWinners": 0,
		"errors": 0,
		"doubleFaults": 0,
		"longestRally": 0,
	},
	"claimedObjectives": {},
	"bestSeason": 1,
	"finaleSeen": false,
	"unlockAll": false,
	"equippedOutfits": {},
}

## Defaults the reference's runtime `ui` object starts with, for every field
## `collectPrefs()` writes (`js/ui.js:422-442` against `js/ui.js:460-481`), plus
## the audio defaults `collectPrefs` reads (`js/audio.js:3-6`).
##
## The browser's `loadPrefs()` returns `{}` and lets the `ui` object supply the
## fallbacks, so these ARE the "defaults" the merge is against — the recovery
## note in the ticket names exactly this object.
##
## Merge semantics match the reference: a *shallow* merge. A stored `lineup`
## therefore replaces the default `lineup` whole, exactly as JS spread does.
const PREFS_DEFAULTS: Dictionary = {
	"cameraPreset": "default",
	"athleteId": null, ## js/ui.js:424, null until an athlete is chosen
	"arenaId": null, ## js/ui.js:425
	"mode": null, ## js/ui.js:426
	"tournamentRound": 0, ## js/ui.js:427, 464
	"muted": false, ## js/audio.js:4
	"volume": 0.5, ## js/audio.js:5
	"musicVolume": 1.0, ## Port addition: multiplier for the Music bus only.
	"controlMode": "semi", ## js/ui.js:466
	"gamepadDeadzone": 0.15, ## js/ui.js:467
	"vibration": true, ## js/ui.js:468
	"aiDifficulty": "easy", ## js/ui.js:469
	"matchLength": "points11", ## js/ui.js:470
	"reduceMotion": false, ## js/ui.js:471
	"matchPanel": false, ## js/ui.js:472
	"colorblind": false, ## js/ui.js:473
	"lang": "en", ## js/ui.js:475
	"playerMode": "solo", ## js/ui.js:476
	## PORT ADDITION, no reference line: the game-pace preset
	## (`src/sim/pace.gd`). Its default is the rung whose factor is 1.0, so a save
	## written before this key existed reads back as the tuning it was written at.
	"pacePreset": Pace.DEFAULT_ID,
	"lineup": { ## js/ui.js:480
		"playerMate": null,
		"opponent": null,
		"opponentMate": null,
	},
}

## The port's own `economy` group (Emporio OST): a wallet, the OST ids the profile
## owns, the migration marker and the award receipts. No reference line — this group
## has no browser counterpart, so it carries no reference default and is merged over
## exactly this object. `migrationVersion` starts at 0 ("not yet initialized"); the
## economy service writes 1 on its first successful initialization and never lowers
## it, so a later missing/refused economy file can never re-decide a grant.
const ECONOMY_DEFAULTS: Dictionary = {
	"credits": 0,
	"owned": [],
	"migrationVersion": 0,
	"receipts": {},
}

## Which group's payload gets merged over which defaults on read. Groups absent
## here are round-tripped as-is (the reference does not merge them either:
## `loadHistory`/`loadDrillRecords`/`loadFeedbackQueue` all return the stored
## value or an empty container).
const DEFAULTS_BY_GROUP: Dictionary = {
	"prefs": PREFS_DEFAULTS,
	"career": CAREER_DEFAULTS,
	"economy": ECONOMY_DEFAULTS,
}


## The group names, in a stable order (deterministic tests and evidence).
static func group_names() -> Array:
	return ["prefs", "career", "history", "drill", "feedback"]


## Every group this PORT persists, in a stable order: the reference's five plus the
## port's own `economy`. This is what the whole-profile read/write and the cloud
## backup enumerate — the reference count stays five in `group_names()`, but a real
## backup is six files.
static func port_group_names() -> Array:
	return group_names() + ["economy"]


## Absolute `user://` path of a group's file.
static func group_path(group: String) -> String:
	return SAVE_DIR.path_join(String(GROUP_FILES.get(group, group + ".json")))


## The empty container the reference's loader returns when nothing is stored:
## `{}` for the dictionary groups, `[]` for the list groups.
static func empty_payload_for(group: String) -> Variant:
	return [] if int(GROUP_TYPES.get(group, TYPE_DICTIONARY)) == TYPE_ARRAY else {}


## True when the parsed payload is the JSON type this group expects.
static func payload_type_ok(group: String, payload: Variant) -> bool:
	if not GROUP_TYPES.has(group):
		return true
	var expected: int = int(GROUP_TYPES[group])
	if expected == TYPE_DICTIONARY:
		return payload is Dictionary
	if expected == TYPE_ARRAY:
		return payload is Array
	return typeof(payload) == expected


## True when `group` merges a stored payload over defaults.
static func has_defaults(group: String) -> bool:
	return DEFAULTS_BY_GROUP.has(group)


## Shallow merge over defaults, exactly the reference's
## `{ ...DEFAULT_X, ...JSON.parse(raw) }` (`js/ui.js:41`): every missing key is
## supplied by the defaults, every stored key (including unknown ones) is kept.
## A stored explicit `null` is kept — the reference does not treat null as
## "missing" either.
static func merge_against_defaults(payload: Variant, defaults: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	if payload is Dictionary:
		for key in (payload as Dictionary):
			out[key] = (payload as Dictionary)[key]
	return out


## The stored payload merged over the group's defaults, or the payload as-is
## when the group has no defaults. `null` payload (absent or recovered file)
## yields the defaults — never an empty profile.
static func apply_defaults(group: String, payload: Variant) -> Variant:
	if not has_defaults(group):
		return payload
	return merge_against_defaults(payload, DEFAULTS_BY_GROUP[group])


## Build one group's envelope. `payload` is the exact browser payload.
static func envelope(group: String, payload: Variant) -> Dictionary:
	return {
		"format": FORMAT_TAG,
		"schemaVersion": CURRENT_SCHEMA_VERSION,
		"build": BUILD,
		"balance": BALANCE,
		"group": group,
		"payload": payload,
	}


## True when a value is an envelope this schema understands.
static func is_envelope(value: Variant) -> bool:
	return value is Dictionary and String((value as Dictionary).get("format", "")) == FORMAT_TAG


## A complete empty profile, i.e. what a first launch reads.
static func empty_profile() -> Dictionary:
	return {
		"prefs": PREFS_DEFAULTS.duplicate(true),
		"career": CAREER_DEFAULTS.duplicate(true),
		"history": [],
		"drill": {},
		"feedback": [],
		"economy": ECONOMY_DEFAULTS.duplicate(true),
	}


## The reference's drill policy: a record is written **only on improvement**
## (`js/ui.js:219-230`). Returns true when `score` should replace `existing`.
static func drill_record_improves(existing: Variant, score: int) -> bool:
	return score > int(existing)


## Godot's JSON parser returns **every** number as a float (`4` reloads as
## `4.0`), where the browser's `JSON.parse` produced one JS number type. The
## store normalises whole-valued numbers back to ints on read, so `career.season`
## reads back as `4` and a round-trip is byte-exact in JSON terms rather than
## "close enough". Values with a fractional part (`gamepadDeadzone` 0.15,
## `volume` 0.35) are left alone.
##
## Lossless: only numbers that are already integral are converted, and the
## int64 range covers everything a JSON document can hold here.
static func normalize_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if is_finite(f) and f == floor(f) and absf(f) <= 9007199254740992.0:
				return int(f)
			return f
		TYPE_ARRAY:
			var list: Array = []
			for item in (value as Array):
				list.append(normalize_numbers(item))
			return list
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in (value as Dictionary):
				out[key] = normalize_numbers((value as Dictionary)[key])
			return out
	return value
