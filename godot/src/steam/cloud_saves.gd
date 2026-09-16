extends RefCounted
class_name CloudSaves
## The cloud layer over the local save — narrow on purpose.
##
## Two rules, both inherited from the resolved route
## (`docs/wayfinder/tickets/steamworks-integration-route.md`, "No-Steam
## fallback") and both enforced here rather than by convention:
##
##   1. **Cloud is layered on the local save, never the only copy.** Every
##      upload starts by reading the local file that was just written, and no
##      method in this class deletes or truncates a local file. A build with no
##      Steam client loses nothing.
##   2. **A closed gate is a skip, not an error.** With no backend the methods
##      return `skipped: true` and the local save stands alone. Nothing about a
##      missing Steam client may fail a run.
##
## The conflict rule is NOT decided here. `resolve_conflict()` states what this
## code does today — local always wins when a local copy exists — and says that
## the real rule belongs to the open save-format decision
## (`docs/wayfinder/tickets/save-and-cloud-format.md`). Corollary: this class
## never implements "cloud wins".

const Schema := preload("res://src/save/save_schema.gd")

var _backend: RefCounted
var _store: RefCounted


func _init(p_backend: RefCounted, p_store: RefCounted) -> void:
	_backend = p_backend
	_store = p_store


## The Steam Cloud file name for a save group.
##
## UNVERIFIED ASSUMPTION: the naming and the per-file size ceiling are part of
## the open save-format/cloud-mapping decision and the cloud quota in
## `steamworks-prerequisites.md`. `padel-<group>.json` is a placeholder, not a
## settled name. The one thing that is settled: the cloud file is derived from
## the local group file, so the two cannot drift in shape.
func cloud_name_for(group: String) -> String:
	return "padel-" + String(Schema.GROUP_FILES.get(group, group + ".json"))


func is_enabled() -> bool:
	return _backend.is_steam_enabled()


## Upload one group's local file after it has been written.
##
## Returns: `ok`, `skipped`, `cloud_name`, `bytes`, `reason`.
func upload_group(group: String) -> Dictionary:
	var path: String = _store.group_path(group)
	if not FileAccess.file_exists(path):
		return {
			"ok": false,
			"skipped": true,
			"cloud_name": cloud_name_for(group),
			"bytes": 0,
			"reason": "no local file at %s: nothing to upload (local is the source of truth)" % path,
		}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "skipped": true, "cloud_name": cloud_name_for(group), "bytes": 0,
			"reason": "local file unreadable: %s" % error_string(FileAccess.get_open_error())}
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return upload_bytes(cloud_name_for(group), bytes)


func upload_bytes(file_name: String, bytes: PackedByteArray) -> Dictionary:
	if not is_enabled():
		return {
			"ok": false,
			"skipped": true,
			"cloud_name": file_name,
			"bytes": bytes.size(),
			"reason": "no Steam backend enabled: local save kept, cloud skipped",
		}
	var ok := bool(_backend.cloud_write(file_name, bytes))
	return {
		"ok": ok,
		"skipped": false,
		"cloud_name": file_name,
		"bytes": bytes.size(),
		"reason": "uploaded" if ok else "backend refused the write",
	}


## Read one group from the cloud at start. Absent or gated is a skip; the local
## file is untouched either way.
##
## Returns: `ok`, `skipped`, `cloud_name`, `bytes` (PackedByteArray), `reason`.
func download_on_start(group: String) -> Dictionary:
	var cloud_name := cloud_name_for(group)
	if not is_enabled():
		return {"ok": false, "skipped": true, "cloud_name": cloud_name, "bytes": PackedByteArray(),
			"reason": "no Steam backend enabled"}
	if not bool(_backend.cloud_file_exists(cloud_name)):
		return {"ok": false, "skipped": true, "cloud_name": cloud_name, "bytes": PackedByteArray(),
			"reason": "no cloud copy"}
	var bytes: PackedByteArray = _backend.cloud_read(cloud_name)
	return {"ok": bytes.size() > 0, "skipped": false, "cloud_name": cloud_name, "bytes": bytes,
		"reason": "downloaded" if bytes.size() > 0 else "cloud copy empty or unreadable"}


## Which side a start-up sees.
##
## Today: a local copy always wins, and cloud is used only when there is no local
## copy at all. That is a placeholder for the open save-format decision, chosen
## because it is the only rule that can never lose a local save. It is stated
## here so nobody mistakes it for a settled cloud policy.
func resolve_conflict(local_exists: bool, cloud_exists: bool) -> String:
	if local_exists:
		return "local"
	if cloud_exists:
		return "cloud"
	return "none"


func status() -> Dictionary:
	return {
		"enabled": is_enabled(),
		"backend": _backend.backend_id(),
		"is_mock": _backend.is_mock(),
		"live_steam_proven": _backend.live_steam_proven(),
	}
