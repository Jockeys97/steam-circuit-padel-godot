extends RefCounted
class_name CustomCharacterStore
## CustomCharacterStore — the custom athlete's own file, deliberately outside the
## profile save group.
##
## ===========================================================================
## WHY A SEPARATE FILE
## ===========================================================================
## The profile store (`src/save/save_store.gd`) owns career, economy and unlock
## state: it migrates between schema versions and a bad write there costs a player
## their progression. A character appearance has no such relationship. It is one
## small record, it never unlocks anything, and it must be readable even when the
## profile group is mid-migration or absent. So it lives at
## `user://custom_character.json`, written with the same discipline the profile
## store uses and nothing else: temp file, flush, close, rename. The rename is the
## commit point, so an interrupted save leaves the previous appearance intact.
##
## ===========================================================================
## FAILURE BEHAVIOUR
## ===========================================================================
## Missing file, unreadable file, malformed JSON, wrong schema: `load()` answers the
## documented default record and reports why in its second return value. It never
## throws, never returns null, and never leaves the caller to guess whether it got
## real data. `save()` refuses to write anything `CustomCharacter.normalize()` would
## rewrite, so a stored file is always a canonical record.

const CustomCharacter := preload("res://src/character/custom_character.gd")

const PATH := "user://custom_character.json"
const TMP_SUFFIX := ".tmp"
## Shared injection for isolated integration tests; empty in normal play.
static var default_path_override: String = ""

## TEST HOOK — when true, the temp file is removed and the write fails before the
## rename, so a test can prove the target file is untouched by a failed save.
var fail_before_rename: bool = false

## TEST HOOK — points the store at another file so a test never touches a player's
## real appearance. Empty means the shipped path.
var path_override: String = ""


static func path() -> String:
	return PATH


func target_path() -> String:
	return path_override if path_override != "" else (default_path_override if default_path_override != "" else PATH)


func exists() -> bool:
	return FileAccess.file_exists(target_path())


## Reads the stored appearance. Always returns a canonical record; the second value
## is a short machine-readable reason ("ok", "missing", "unreadable", "malformed",
## "not_an_object") for the evidence dump and for the editor's error line.
func load_record() -> Array:
	var default := CustomCharacter.defaults()
	if not exists():
		return [default, "missing"]
	var f := FileAccess.open(target_path(), FileAccess.READ)
	if f == null:
		return [default, "unreadable"]
	var text := f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return [default, "malformed"]
	var parsed: Variant = parser.data
	if not (parsed is Dictionary):
		return [default, "not_an_object"]
	var normalized := CustomCharacter.normalize(parsed as Dictionary)
	if normalized != (parsed as Dictionary):
		return [normalized, "normalized"]
	return [normalized, "ok"]


## Convenience: the record alone, for callers that do not care why.
func read() -> Dictionary:
	return (load_record() as Array)[0]


## Writes the appearance. The record is normalized first, so an unknown id can never
## reach the disk. Returns `{ok, message}` — `ok` is the only thing a caller needs.
func write(record: Dictionary) -> Dictionary:
	var canonical := CustomCharacter.normalize(record)
	var text := JSON.stringify(canonical, "\t")
	return _atomic_write_text(text)


## Simulates the save being refused: the record is checked, then nothing is written.
func write_without_commit(record: Dictionary) -> Dictionary:
	var canonical := CustomCharacter.normalize(record)
	# Same validation path as `write()`; the file is deliberately left alone.
	if canonical.is_empty():
		return {"ok": false, "message": "refused: empty record"}
	return {"ok": true, "message": "validated, not written"}


func erase() -> bool:
	if not exists():
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(target_path())) == OK


## The commit point. Temp file first, then rename over the target.
func _atomic_write_text(text: String) -> Dictionary:
	var target := target_path()
	var tmp := target + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "message": "cannot open temp file: %s" % error_string(FileAccess.get_open_error())}
	f.store_string(text)
	f.flush()
	f.close()
	if fail_before_rename:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return {"ok": false, "message": "simulated failure before rename (temp removed, target untouched)"}
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(target))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return {"ok": false, "message": "rename failed: %s" % error_string(err)}
	return {"ok": true, "message": "atomic write (temp + rename)"}
