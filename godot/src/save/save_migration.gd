extends RefCounted
class_name SaveMigration
## The version step for the port's save format.
##
## Scope, stated before the code: this implements the **mechanical envelope
## migration** and refuses everything else.
##
## The save-format decision (`docs/wayfinder/tickets/save-and-cloud-format.md`)
## is still open and owns the schema, the cloud mapping and any *behavioural*
## migration (e.g. whether a browser `localStorage` profile is imported at all).
## What is decided, and therefore implemented here, is much smaller:
##
##   * v0 = the reference's own on-disk shape: a bare JSON payload with **no**
##     envelope — exactly what `JSON.stringify` of a `localStorage` value is.
##   * v1 = that payload wrapped in `SaveSchema`'s envelope, fields untouched.
##
## v0 -> v1 preserves every field verbatim and adds no game data. It is a
## wrapper, not a re-interpretation, so it cannot invent progression.
##
## Anything else — a version this build does not know, or a payload whose shape
## contradicts the schema — is **refused explicitly** and the file is left
## untouched on disk. `SaveStore` reports the refusal. A save is never silently
## emptied.

## NOTE ON REFERENCES: this file must not use global `class_name` identifiers.
## A headless `--script` run does not rebuild `.godot/global_script_class_cache.cfg`
## (it is empty in this repo), so `SaveSchema.x` would be a parse error and this
## script would silently fail to compile. Cross-script references are `preload`
## consts, which resolve by path in every run mode. Same rule under
## `godot/src/save/**` and `godot/src/steam/**`.
const Schema := preload("res://src/save/save_schema.gd")

## Versions this build can read (after migration). 0 = unversioned/browser shape.
const KNOWN_VERSIONS: Array = [0, 1]

## Set on a migrated envelope so the origin of the data stays visible.
const MIGRATED_FROM_KEY: String = "migratedFrom"

## A v0 envelope cannot know which build wrote it; null says so honestly rather
## than claiming a build (the browser never recorded one).
const UNKNOWN_BUILD: String = ""


## The schema version a parsed file claims.
##   * an explicit int `schemaVersion` wins;
##   * a file with no `schemaVersion` is v0 (the browser's bare payload);
##   * a non-int `schemaVersion` is reported as -1 so the caller can refuse it.
static func detect_version(raw: Variant) -> int:
	if not (raw is Dictionary):
		return 0
	var d: Dictionary = raw
	if not d.has("schemaVersion"):
		return 0
	var v: Variant = d["schemaVersion"]
	if v is int:
		return int(v)
	if v is float and float(v) == floorf(float(v)):
		return int(v)
	return -1


## Migrate a parsed file to the current schema.
##
## Returns a Dictionary:
##   ok:        bool    — true when `envelope` is safe to read
##   from:      int     — the detected version (-1 = unreadable version value)
##   envelope:  Dictionary — the current-version envelope (empty on refusal)
##   actions:   Array[String] — what was done, for the log
##   message:   String  — human-readable outcome; a refusal says why
##
## `group` is the save group the file belongs to; it is used only to stamp the
## envelope's `group` field (it is not required).
static func migrate(raw: Variant, group: String = "") -> Dictionary:
	var from := detect_version(raw)

	if from == -1:
		return _refuse(
			from,
			"schemaVersion is not an integer: refusing to guess how to read this save"
		)

	if not KNOWN_VERSIONS.has(from):
		return _refuse(
			from,
			"schemaVersion %d is not known to this build (known: %s); refusing to migrate"
			% [from, str(KNOWN_VERSIONS)]
		)

	if from == 0:
		# The browser's bare payload. Wrap it; touch no field inside it.
		var payload: Variant = _strip_envelope_markers(raw)
		var envelope: Dictionary = Schema.envelope(group, payload)
		envelope["build"] = UNKNOWN_BUILD
		envelope["balance"] = UNKNOWN_BUILD
		envelope[MIGRATED_FROM_KEY] = 0
		return {
			"ok": true,
			"from": 0,
			"envelope": envelope,
			"actions": ["v0 (unversioned payload) wrapped into the v1 envelope; payload fields untouched"],
			"message": "migrated v0 -> v1 (envelope only)",
		}

	# from == 1: already current. Validate the envelope rather than trusting it.
	if not Schema.is_envelope(raw):
		return _refuse(
			1,
			"schemaVersion is 1 but the format tag is not %s: refusing to read a foreign file"
			% Schema.FORMAT_TAG
		)
	return {
		"ok": true,
		"from": 1,
		"envelope": raw,
		"actions": [],
		"message": "already at schemaVersion 1",
	}


## The payload out of a v0 file: the parsed value minus any envelope markers a
## half-upgraded file might carry.
static func _strip_envelope_markers(raw: Variant) -> Variant:
	if not (raw is Dictionary):
		return raw
	var d: Dictionary = (raw as Dictionary).duplicate(true)
	d.erase("schemaVersion")
	d.erase("format")
	return d


static func _refuse(from: int, message: String) -> Dictionary:
	return {
		"ok": false,
		"from": from,
		"envelope": {},
		"actions": [],
		"message": message,
	}
