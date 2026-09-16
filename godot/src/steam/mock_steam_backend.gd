extends "res://src/steam/steam_backend.gd"
class_name MockSteamBackend
## A TEST DOUBLE for the Steam seam — and it says so about itself.
##
## This is not Steam, it is not a Steam emulator, and it must never be read as
## evidence that Steam works. `is_mock()` returns true, `live_steam_proven()`
## returns false, and every call it accepts is logged with the note that no
## Steam API was involved. Its cloud store is an in-process `Dictionary`, not
## Steam Remote Storage.
##
## Because a mock may make no claim it cannot support, the default mode is
## `UNAVAILABLE`: a freshly built mock reports the honest no-Steam path (init
## status 2, client not running) and every achievement/cloud call is refused.
## A test that wants the seam exercised opts in explicitly.
##
## Modes
##   UNAVAILABLE  — no Steam client. `steamInitEx` status 2, gate closed.
##   INIT_FAILED  — client present but init failed. `steamInitEx` status 1,
##                  gate closed. Both are SOFT failures the game continues past.
##   AVAILABLE    — stands in for a working client so the seam can be driven.
##                  The gate opens; calls are accepted and logged as mock calls.
##
## Honest-failure path: set `honest_failure = true` and the mock refuses every
## achievement write and cloud write while the gate stays open — exactly the
## case a caller must handle without believing a save reached Steam.

enum Mode { UNAVAILABLE, AVAILABLE, INIT_FAILED }

## Which stand-in this instance is. See the mode list above.
var mode: int = Mode.UNAVAILABLE

## When true, accepted-looking calls are refused instead. Exercises the caller's
## "the backend said no" path.
var honest_failure: bool = false

## Gate state, set by `init_backend()`. Never true for a mock unless a test
## chose `Mode.AVAILABLE`.
var _enabled: bool = false

## Every call, in order: {method, arg, ok, note}.
var _calls: Array = []

## Calls refused, with the reason. Read by tests and by the evidence file.
var refusals: Array = []

## Achievements this mock "accepted". Not Steam achievements.
var unlocked: Dictionary = {}

## Files this mock "uploaded". Not Steam Cloud.
var _cloud: Dictionary = {}


func _init(p_mode: int = Mode.UNAVAILABLE) -> void:
	mode = p_mode


# ---------------------------------------------------------------------------
# Identity — the honesty surface
# ---------------------------------------------------------------------------

func backend_id() -> String:
	return "mock"


func is_mock() -> bool:
	return true


## Always false. A mock cannot prove live Steam, and neither can any automated
## run in this repo: that needs a Steam client, the App ID and a manual run.
func live_steam_proven() -> bool:
	return false


## True only in `Mode.AVAILABLE` and only after a zero-status `init_backend()`.
func is_steam_enabled() -> bool:
	return _enabled


# ---------------------------------------------------------------------------
# The seam
# ---------------------------------------------------------------------------

func init_backend() -> Dictionary:
	var status := 1
	var message := ""
	match mode:
		Mode.AVAILABLE:
			status = 0
			_enabled = true
			message = "mock: standing in for a working client (NOT live Steam)"
		Mode.INIT_FAILED:
			status = 1
			_enabled = false
			message = "mock: steamInitEx would return status 1 (other failure) — soft, continue"
		_:
			status = 2
			_enabled = false
			message = "mock: steamInitEx would return status 2 (client not running) — soft, continue"
	_record("init_backend", "", status == 0, message)
	return {"status": status, "message": message, "backend": backend_id()}


func unlock_achievement(api_name: String) -> bool:
	if api_name.strip_edges().is_empty():
		return _refuse("unlock_achievement", api_name, "refused: empty API name — no achievement id may be invented")
	if not _enabled:
		return _refuse("unlock_achievement", api_name, "refused: no Steam backend enabled (local-only path)")
	if honest_failure:
		return _refuse("unlock_achievement", api_name, "refused: honest_failure is set")
	unlocked[api_name] = true
	_record("unlock_achievement", api_name, true, "mock accepted (no Steam API was called)")
	return true


func cloud_write(file_name: String, bytes: PackedByteArray) -> bool:
	if not _enabled:
		return _refuse("cloud_write", file_name, "refused: no Steam backend enabled (local-only path)")
	if honest_failure:
		return _refuse("cloud_write", file_name, "refused: honest_failure is set")
	_cloud[file_name] = bytes
	_record("cloud_write", file_name, true, "mock stored %d bytes in an in-process dict, not Steam Cloud" % bytes.size())
	return true


func cloud_read(file_name: String) -> PackedByteArray:
	if not _enabled:
		_refuse("cloud_read", file_name, "refused: no Steam backend enabled (local-only path)")
		return PackedByteArray()
	var found: Variant = _cloud.get(file_name, null)
	var out: PackedByteArray = found if found is PackedByteArray else PackedByteArray()
	_record("cloud_read", file_name, found != null, "mock read %d bytes" % out.size())
	return out


func cloud_file_exists(file_name: String) -> bool:
	var exists := _enabled and _cloud.has(file_name)
	_record("cloud_file_exists", file_name, exists, "mock")
	return exists


## Always false, and it says why. The route evidence is explicit that the
## overlay cannot be asserted headless — upstream states it needs an export
## launched from Steam.
func show_overlay() -> bool:
	_record("show_overlay", "", false, "refused: the overlay cannot be asserted headless (route evidence)")
	refusals.append({"method": "show_overlay", "arg": "", "reason": "not testable headless"})
	return false


# ---------------------------------------------------------------------------
# Introspection for tests and evidence
# ---------------------------------------------------------------------------

func calls() -> Array:
	return _calls.duplicate(true)


func call_count(method_name: String) -> int:
	var n := 0
	for c in _calls:
		if String(c["method"]) == method_name:
			n += 1
	return n


func calls_for(method_name: String) -> Array:
	var out: Array = []
	for c in _calls:
		if String(c["method"]) == method_name:
			out.append(c)
	return out


func cloud_files() -> Array:
	return _cloud.keys()


func cloud_bytes(file_name: String) -> PackedByteArray:
	var v: Variant = _cloud.get(file_name, null)
	return v if v is PackedByteArray else PackedByteArray()


func _refuse(method_name: String, arg: String, reason: String) -> bool:
	_record(method_name, arg, false, reason)
	refusals.append({"method": method_name, "arg": arg, "reason": reason})
	return false


func _record(method_name: String, arg: String, ok: bool, note: String) -> void:
	_calls.append({"method": method_name, "arg": arg, "ok": ok, "note": note})
