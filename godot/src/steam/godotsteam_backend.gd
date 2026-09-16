extends "res://src/steam/steam_backend.gd"
class_name GodotSteamBackend
## THE SWAP POINT — the only class in this port that talks to GodotSteam.
##
## STATUS: **written, not executed inside the game project, and its API surface is
## now VERIFIED against the loaded plug-in** — see
## `docs/wayfinder/evidence/steam-addon-verification.md` (crew-steam, 2026-09-16).
## The surface was read two ways, both real:
##
##   * the plug-in was loaded in the pinned engine
##     `4.7.2.stable.official.ed1daf0bf` in an isolated probe project and every
##     method below was dumped from `ClassDB.class_get_method_list("Steam")` —
##     the binding that is actually registered, arity and default arguments
##     included. The 4.4-ABI plug-in DOES register on 4.7.2:
##     `Engine.has_singleton("Steam") == true`, 798 methods, and
##     `get_godotsteam_version()` returns `4.22.1`;
##   * upstream source at the exact release commit
##     `5853a7741d174cfa37edee1ca44a11581a989d0b` (tag `v4.22.1-gde`) — the
##     implementation of every method below was read to check return shapes and
##     default-argument behaviour.
##
## The addon is deliberately NOT installed in this project: registering it needs
## the generated `godot/.godot/extension_list.cfg`, which is outside this lane's
## boundary, and a plain copy of the addon alone does NOT register (measured — the
## negative control in the probe). Nothing in the repo instantiates this class by
## default: `steam_backend_factory.gd` returns `MockSteamBackend` and changing that
## one line is still the swap.
##
## Route this implements (`docs/wayfinder/tickets/steamworks-integration-route.md`):
## GodotSteam GDExtension 4.22.1 Stable, Steamworks SDK 1.65, a drop-in under
## `addons/godotsteam/`, stock Godot export templates, guarded by
## `Engine.has_singleton("Steam")`, with `steamInitEx()`'s non-zero status
## treated as a SOFT failure the game continues past.
##
## CORRECTIONS applied after verification (wrong in the first draft)
## --------------------------------------------------------------
##   1. `fileRead(name)` was **wrong**. The real signature is
##      `fileRead(file: String, data_to_read: int) -> Dictionary` with NO default
##      for the second argument, so the one-argument call raised
##      `Invalid call to function 'fileRead' in base 'Steam'. Expected 2 argument(s).`
##      and returned null. `cloud_read()` now asks `getFileSize(name)` first and
##      passes the size.
##   2. The read result has keys `ret` (int, **bytes read**, not a bool) and `buf`
##      (`PackedByteArray`) — there is no `size` key. `cloud_read()` now reads `ret`
##      as the success signal and `buf` as the payload.
##
## Verified surface actually used below (registered arity -> return type)
## -------------------------------------------------------------------
##   * singleton is named `"Steam"`; upstream registers it with
##     `Engine::register_singleton("Steam", ...)` in `register_types.cpp`
##     (`entry_symbol = "godotsteam_init"`, `compatibility_minimum = "4.4"`).
##   * `steamInitEx(app_id: int = 0, embed_callbacks: bool = false) -> Dictionary`
##     with keys `status` (int) and `verbal` (String). Codes: 0 ok, 1 other
##     failure, 2 client not running, 3 client out of date. **Measured on this
##     host, with no Steam client installed at all, the real return is
##     `status = 1` and `verbal = "Failed to load module
##     '/root/.steam/sdk64/steamclient.so'"` — not 2.** The gate only needs
##     `status != 0`; nothing here may assert the specific code.
##   * `setAchievement(achievement_name: String) -> bool`, `storeStats() -> bool`.
##     Upstream documents `storeStats` as rate limited ("call frequency should be
##     on the order of minutes"); `achievements.gd` already calls the backend at
##     most once per distinct id, which is what keeps that honest.
##   * `getAchievement(achievement_name: String) -> Dictionary` with keys
##     `ret` (bool) and `achieved` (bool). Used by nothing shipped.
##   * `fileWrite(file: String, data: PackedByteArray, size: int = 0) -> bool`.
##     The implementation is `data_size = data.size(); if (size > 0) data_size = size;`,
##     so the two-argument call writes all the bytes — verified, not assumed.
##   * `fileExists(file: String) -> bool`, `getFileSize(file: String) -> int`
##     (returns `-1` when Remote Storage is not available).
##   * `activateGameOverlay(type: String = "") -> void` — returns nothing.
##
## STILL UNVERIFIED, and why
## -------------------------
##   * Live behaviour of every call: no Steam client and no App ID exist here. The
##     init fails, the gate stays closed and `live_steam_proven()` is false.
##   * The overlay dialog string. This class passes `"Friends"`, Valve's historical
##     spelling, while upstream documents lowercase dialog names
##     (`activateGameOverlay("friends")`). Neither shipped library contains the
##     dialog name table (checked with `strings`), so the string is matched inside
##     the Steam client and its case behaviour cannot be settled without one.
##     Left as it was, and flagged rather than silently changed.
##   * Achievement API names (`SOURCE_TO_API_NAME` is still empty on purpose;
##     `docs/wayfinder/tickets/steamworks-prerequisites.md` owns that) and the
##     cloud quota.

## VERIFIED: registered singleton name (`register_types.cpp`, and
## `Engine.has_singleton("Steam") == true` in the probe).
const SINGLETON_NAME: String = "Steam"

## 0 = "let the addon use the configured app id". The live App ID is an open
## human gate; a development/test id is what a first real run would use. VERIFIED:
## `app_id = 0` makes upstream fall back to the
## `steam/initialization/app_data/app_id` project setting, and if that is 0 too it
## sets no environment variable and `SteamAPI_InitEx` fails — which is the honest
## status on this machine.
const DEFAULT_APP_ID: int = 0

var _steam: Variant = null
var _enabled: bool = false
var _status: int = 1
var _message: String = "not initialised"
var _calls: Array = []


func backend_id() -> String:
	return "godotsteam"


func is_mock() -> bool:
	return false


## False, unconditionally. No automated run in this repo can prove live Steam:
## that is a manual Steam-client run with the real App ID.
func live_steam_proven() -> bool:
	return false


func is_steam_enabled() -> bool:
	return _enabled


func init_backend() -> Dictionary:
	# VERIFIED presence test: Engine.has_singleton("Steam") — the addon registers
	# the singleton under exactly that name.
	if not Engine.has_singleton(SINGLETON_NAME):
		_enabled = false
		_steam = null
		_status = 2
		_message = "GodotSteam singleton absent (addon not installed, or stripped from the build)"
		_record("init_backend", false, _message)
		return {"status": _status, "message": _message, "backend": backend_id()}

	_steam = Engine.get_singleton(SINGLETON_NAME)
	# VERIFIED: steamInitEx(app_id = 0, embed_callbacks = false) -> {status, verbal}.
	var reply: Variant = _steam.steamInitEx(DEFAULT_APP_ID)
	var status := 1
	var verbal := ""
	if reply is Dictionary:
		status = int((reply as Dictionary).get("status", 1))
		verbal = String((reply as Dictionary).get("verbal", ""))
	# status != 0 is a SOFT failure: the game continues on the local-only path.
	# MEASURED on this host, with no Steam client installed at all: status is 1
	# ("other failure", verbal names the missing steamclient.so) — NOT the 2 the
	# route evidence predicted for "client not running". Only `!= 0` may be
	# asserted; no caller may test for a specific non-zero code.
	_enabled = status == 0
	_status = status
	_message = "steamInitEx status %d%s" % [status, (": " + verbal) if verbal != "" else ""]
	_record("init_backend", _enabled, _message)
	return {"status": _status, "message": _message, "backend": backend_id()}


func unlock_achievement(api_name: String) -> bool:
	if not _enabled or _steam == null:
		return _refuse("unlock_achievement", api_name, "no Steam backend enabled")
	if api_name.strip_edges().is_empty():
		return _refuse("unlock_achievement", api_name, "empty API name — no achievement id may be invented")
	# VERIFIED: setAchievement(name) -> bool; storeStats() -> bool. storeStats is
	# documented as rate limited (minutes, not seconds); the once-per-distinct-id
	# de-duplication in achievements.gd is what keeps this call pattern acceptable.
	var set_ok: Variant = _steam.setAchievement(api_name)
	var stored: Variant = _steam.storeStats()
	var ok := bool(set_ok) and bool(stored)
	_record("unlock_achievement", ok, "%s setAchievement=%s storeStats=%s" % [api_name, str(set_ok), str(stored)])
	return ok


func cloud_write(file_name: String, bytes: PackedByteArray) -> bool:
	if not _enabled or _steam == null:
		return _refuse("cloud_write", file_name, "no Steam backend enabled")
	if bytes.is_empty():
		# VERIFIED from upstream's own notes: an empty buffer is a documented
		# failure case for fileWrite ("data is empty"). Refused here instead of
		# asking a call that can only answer false.
		return _refuse("cloud_write", file_name, "empty buffer: Steam fileWrite refuses zero-byte writes")
	# VERIFIED: fileWrite(file, data, size = 0) -> bool, and the implementation
	# treats size 0 as "write data.size() bytes", so this two-argument call writes
	# all the bytes.
	var ok := bool(_steam.fileWrite(file_name, bytes))
	_record("cloud_write", ok, "%s (%d bytes)" % [file_name, bytes.size()])
	return ok


func cloud_read(file_name: String) -> PackedByteArray:
	if not _enabled or _steam == null:
		_refuse("cloud_read", file_name, "no Steam backend enabled")
		return PackedByteArray()
	# CORRECTED (was `fileRead(name)`, which cannot work): the real signature is
	# fileRead(file, data_to_read) with the byte count REQUIRED and no default. Ask
	# the size first — VERIFIED getFileSize(file) -> int, -1 when Remote Storage is
	# unavailable.
	var size := int(_steam.getFileSize(file_name))
	if size <= 0:
		_record("cloud_read", false, "%s: getFileSize = %d (absent, or Remote Storage unavailable)" % [file_name, size])
		return PackedByteArray()
	# VERIFIED: fileRead(file, data_to_read) -> {ret: int bytes read, buf: PackedByteArray}.
	# There is no `size` key, and `ret` counts BYTES — it is not a bool.
	var reply: Variant = _steam.fileRead(file_name, size)
	if not (reply is Dictionary):
		_record("cloud_read", false, "%s: fileRead returned no dictionary" % file_name)
		return PackedByteArray()
	var d: Dictionary = reply
	var read_bytes := int(d.get("ret", 0))
	if read_bytes <= 0:
		_record("cloud_read", false, "%s: fileRead ret = %d (nothing read)" % [file_name, read_bytes])
		return PackedByteArray()
	var buf: Variant = d.get("buf", PackedByteArray())
	var out: PackedByteArray = buf if buf is PackedByteArray else PackedByteArray()
	# The buffer is sized to the request; keep exactly the bytes Steam reported.
	if out.size() > read_bytes:
		out = out.slice(0, read_bytes)
	_record("cloud_read", out.size() > 0, "%s (%d of %d bytes)" % [file_name, out.size(), size])
	return out


func cloud_file_exists(file_name: String) -> bool:
	if not _enabled or _steam == null:
		return false
	# VERIFIED: fileExists(file) -> bool.
	var ok := bool(_steam.fileExists(file_name))
	_record("cloud_file_exists", ok, file_name)
	return ok


## VERIFIED signature: `activateGameOverlay(type: String = "") -> void`. It returns
## nothing, so this method must not read a result from it — calling it with a
## return-value expectation is a GDScript runtime error (observed). It still
## returns false in every automated run, because upstream states the overlay needs
## an export launched from Steam, which no run here can provide.
##
## The ARGUMENT is the one part left unverified: upstream documents lowercase
## dialog names ("friends", "achievements", …) while this passes Valve's historical
## "Friends" spelling. The dialog name table is not in either shipped library
## (`strings` finds no "officialgamegroup"/"friends" in libgodotsteam.*.so or
## libsteam_api.so), so the match happens inside the Steam client and its case
## behaviour cannot be settled without a client and an App ID. Recorded, not
## silently changed.
func show_overlay() -> bool:
	if not _enabled or _steam == null:
		return _refuse("show_overlay", "", "no Steam backend enabled")
	_steam.activateGameOverlay("Friends")
	_record("show_overlay", false, "called, and unverifiable headless by upstream's own statement")
	return false


func calls() -> Array:
	return _calls.duplicate(true)


func _refuse(method_name: String, arg: String, reason: String) -> bool:
	_record(method_name + "(" + arg + ")", false, "refused: " + reason)
	return false


func _record(method_name: String, ok: bool, note: String) -> void:
	_calls.append({"method": method_name, "ok": ok, "note": note})
