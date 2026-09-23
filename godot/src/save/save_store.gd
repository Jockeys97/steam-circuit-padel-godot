extends RefCounted
class_name SaveStore
## Read and write the port's profile under `user://`, one file per save group.
##
## Format, defaults and the merge rule live in `SaveSchema`; the version step
## lives in `SaveMigration`; the field-by-field map and the on-disk example are
## in `godot/src/save/README.md`.
##
## Guarantees, each one proven by `godot/tests/save_steam_test.gd`:
##
##   1. **Atomic write.** Text is written to `<path>.tmp`, flushed and closed,
##      then renamed over the target. The rename is the commit point, so a
##      crash between the two leaves the previous file fully intact — never a
##      half-written save. On POSIX the rename is atomic.
##   2. **Merge against defaults on read.** A stored payload that is missing
##      fields loads with the reference's defaults filled in
##      (`js/ui.js:41`, `js/ui.js:405-442`): an older save never becomes an
##      empty profile.
##   3. **Corrupt-file recovery.** A file that does not parse is *quarantined*
##      (renamed to `<path>.corrupt.<unix>`, contents preserved) and the group
##      falls back to its defaults, reported in `read_all()`'s `recovered` list.
##      The browser's `try/catch` returned an empty value and lost the bytes;
##      this keeps them and says so.
##   4. **Explicit refusal, never a silent empty.** A save whose `schemaVersion`
##      this build does not know is refused by `SaveMigration`; the file is left
##      untouched and the refusal is reported in `refused`.
##
## Nothing here knows about the Steam API. Cloud is a layer over these files
## (`godot/src/steam/cloud_saves.gd`), never a replacement for them.

const Schema := preload("res://src/save/save_schema.gd")
const Migration := preload("res://src/save/save_migration.gd")

const TMP_SUFFIX: String = ".tmp"
const QUARANTINE_SUFFIX: String = ".corrupt."

## Root directory. Defaults to the schema's `user://save`; tests point it at
## their own directory so a real profile is never touched.
var dir: String = Schema.SAVE_DIR

## TEST HOOK — when true, `_atomic_write_text` removes the temp file and returns
## a failure instead of renaming. It exists only so a test can prove that a
## failure between "write" and "commit" leaves no partial file. No production
## path sets it.
var fail_before_rename: bool = false

var last_write_path: String = ""
var last_write_bytes: int = 0
var last_write_ok: bool = false
var last_write_message: String = ""


func _init(p_dir: String = "") -> void:
	if p_dir != "":
		dir = p_dir


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

func group_path(group: String) -> String:
	return dir.path_join(String(Schema.GROUP_FILES.get(group, group + ".json")))


## Create the save directory if it is missing.
##
## Both the default root and the test root live under `user://`, so the tail is
## created from that root explicitly instead of slicing the configured path —
## nothing here guesses at `get_base_dir()` semantics.
func ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(dir):
		return true
	var root := "user://"
	if not dir.begins_with(root):
		return false
	var base := DirAccess.open(root)
	if base == null:
		return false
	return base.make_dir_recursive(dir.trim_prefix(root)) == OK


# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------

## Write one group's payload as a current-version envelope.
##
## Returns: `ok`, `path`, `bytes`, `message` (and `simulated` on the test hook).
func write_group(group: String, payload: Variant) -> Dictionary:
	if not Schema.payload_type_ok(group, payload):
		return {
			"ok": false,
			"path": group_path(group),
			"bytes": 0,
			"message": "payload type %d does not match group '%s'" % [typeof(payload), group],
		}
	var text := JSON.stringify(Schema.envelope(group, payload), "\t", true)
	return _atomic_write_text(group_path(group), text)


## Write every group of a profile dictionary.
##
## Returns: `ok`, `written` (group -> bytes), `errors` (group -> message),
## `bytes_total`.
func write_all(profile: Dictionary) -> Dictionary:
	var written: Dictionary = {}
	var errors: Dictionary = {}
	var total := 0
	# Every group this PORT persists, the economy group included: a whole-profile
	# write is a real backup, not the reference's five keys alone.
	for group in Schema.port_group_names():
		if not profile.has(group):
			continue
		var r := write_group(group, profile[group])
		if bool(r["ok"]):
			written[group] = int(r["bytes"])
			total += int(r["bytes"])
		else:
			errors[group] = String(r["message"])
	return {
		"ok": errors.is_empty(),
		"written": written,
		"errors": errors,
		"bytes_total": total,
	}


## History, capped at 20 exactly as `js/ui.js:1551` caps it.
func write_history(list: Array) -> Dictionary:
	return write_group("history", list.slice(0, int(Schema.HISTORY_CAP)))


## Feedback queue, capped at `FEEDBACK.maxQueued` exactly as `js/ui.js:256`.
func write_feedback(list: Array) -> Dictionary:
	return write_group("feedback", list.slice(0, int(Schema.FEEDBACK_MAX_QUEUED)))


## Drill records keep the reference's save-only-on-improvement policy
## (`js/ui.js:219-230`): a lower or equal score is not written at all, and the
## returned dictionary says `skipped`.
func write_drill_record(exercise_id: String, score: int) -> Dictionary:
	var group := "drill"
	var current := read_group(group)
	var records: Dictionary = {}
	if current["payload"] is Dictionary:
		records = (current["payload"] as Dictionary).duplicate(true)
	if not Schema.drill_record_improves(records.get(exercise_id, 0), score):
		return {
			"ok": true,
			"skipped": true,
			"path": group_path(group),
			"bytes": 0,
			"message": "no improvement over %d: record kept (js/ui.js:219-230)" % int(records.get(exercise_id, 0)),
		}
	records[exercise_id] = score
	return write_group(group, records)


## The commit point. Temp file first, then rename over the target.
func _atomic_write_text(path: String, text: String) -> Dictionary:
	if not ensure_dir():
		return {"ok": false, "path": path, "bytes": 0, "message": "cannot create %s" % dir}
	var tmp := path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {
			"ok": false,
			"path": path,
			"bytes": 0,
			"message": "cannot open temp file: %s" % error_string(FileAccess.get_open_error()),
		}
	f.store_string(text)
	f.flush()
	f.close()
	var bytes := text.to_utf8_buffer().size()

	if fail_before_rename:
		# Nothing half-written may survive a failure here: drop the temp file and
		# leave the target exactly as it was.
		DirAccess.remove_absolute(tmp)
		last_write_ok = false
		last_write_message = "simulated failure before rename (temp removed, target untouched)"
		return {
			"ok": false,
			"simulated": true,
			"path": path,
			"bytes": 0,
			"message": last_write_message,
		}

	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		last_write_ok = false
		last_write_message = "rename failed: %s" % error_string(err)
		return {"ok": false, "path": path, "bytes": 0, "message": last_write_message}

	last_write_path = path
	last_write_bytes = bytes
	last_write_ok = true
	last_write_message = "atomic write (temp + rename)"
	return {"ok": true, "path": path, "bytes": bytes, "message": last_write_message}


# ---------------------------------------------------------------------------
# Read
# ---------------------------------------------------------------------------

## Read one group.
##
## Returns: `group`, `path`, `ok`, `existed`, `payload` (the stored payload,
## before any default merge, or null), `recovered`, `refused`, `migrated`,
## `quarantine_path`, `message`.
##
## `ok` is false only when the file exists and could not be read as a save of
## this schema (corrupt or refused). A missing file is `ok: true, existed: false`
## — a first launch is not an error.
func read_group(group: String) -> Dictionary:
	var path := group_path(group)
	var out := {
		"group": group,
		"path": path,
		"ok": false,
		"existed": false,
		"payload": null,
		"recovered": false,
		"refused": false,
		"migrated": false,
		"quarantine_path": "",
		"message": "",
	}
	if not FileAccess.file_exists(path):
		out["ok"] = true
		out["message"] = "absent"
		return out
	out["existed"] = true

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out["message"] = "cannot open: %s" % error_string(FileAccess.get_open_error())
		return out
	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		return _quarantine_and_recover(
			group,
			path,
			"JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		)

	var result := Migration.migrate(json.data, group)
	if not bool(result["ok"]):
		# Refused, not repaired: the file stays exactly where it is.
		out["refused"] = true
		out["message"] = String(result["message"])
		return out

	var envelope: Dictionary = result["envelope"]
	var payload: Variant = envelope.get("payload", null)
	if not Schema.payload_type_ok(group, payload):
		return _quarantine_and_recover(
			group,
			path,
			"payload is type %d, group '%s' expects %d"
			% [typeof(payload), group, int(Schema.GROUP_TYPES.get(group, -1))]
		)

	out["ok"] = true
	out["payload"] = Schema.normalize_numbers(payload)
	out["migrated"] = int(result["from"]) != int(Schema.CURRENT_SCHEMA_VERSION)
	out["message"] = String(result["message"])
	return out


func _quarantine_and_recover(group: String, path: String, reason: String) -> Dictionary:
	var qpath := path + QUARANTINE_SUFFIX + str(int(Time.get_unix_time_from_system()))
	var err := DirAccess.rename_absolute(path, qpath)
	var kept := qpath if err == OK else ""
	return {
		"group": group,
		"path": path,
		"ok": false,
		"existed": true,
		"payload": null,
		"recovered": true,
		"refused": false,
		"migrated": false,
		"quarantine_path": kept,
		"message": "corrupt file recovered to defaults: %s; original kept at %s" % [reason, kept],
	}


## Read the whole profile.
##
## Returns: `ok`, `profile` (each group's payload with defaults applied), `groups`
## (per-group details), `recovered`, `refused`, `errors`.
func read_all() -> Dictionary:
	var profile: Dictionary = {}
	var groups: Dictionary = {}
	var recovered: Array = []
	var refused: Array = []
	var errors: Dictionary = {}
	# Every group this PORT persists, the economy group included — see
	# `SaveSchema.port_group_names()` and `write_all` above.
	for group in Schema.port_group_names():
		var r := read_group(group)
		groups[group] = r
		if bool(r["recovered"]):
			recovered.append(group)
		if bool(r["refused"]):
			refused.append(group)
		if not bool(r["ok"]) and not bool(r["recovered"]) and not bool(r["refused"]):
			errors[group] = String(r["message"])
		var payload: Variant = r["payload"]
		if payload == null:
			payload = Schema.empty_payload_for(group)
		profile[group] = Schema.apply_defaults(group, payload)
	return {
		"ok": errors.is_empty() and refused.is_empty(),
		"profile": profile,
		"groups": groups,
		"recovered": recovered,
		"refused": refused,
		"errors": errors,
	}
