extends RefCounted
class_name SteamBackend
## The narrow Steam seam of the port.
##
## This file is the *interface only*. It makes no Steam call and must not: the
## one class that talks to GodotSteam is `godotsteam_backend.gd`, and it is
## swapped in at exactly one place (`steam_backend_factory.gd`).
##
## Scope, and what it deliberately is not
## --------------------------------------
## The release features in scope here are the two the route ticket names for v1:
## **achievements** and **cloud saves** (Steam Remote Storage). The overlay is
## present as a single guarded call because the route includes it, but the route
## evidence states it can never be asserted headless — nothing in this repo
## claims it works.
##
## The route is resolved in
## `docs/wayfinder/tickets/steamworks-integration-route.md`: GodotSteam
## GDExtension 4.22.1 Stable (Steamworks SDK 1.65), a drop-in under
## `addons/godotsteam/`, guarded by `Engine.has_singleton("Steam")`, with every
## call behind one `is_steam_enabled()` gate so a headless run, a Steam-less
## machine and a non-Steam build take the same local-only path.
##
## Honesty rule that shapes every method below
## -------------------------------------------
## A backend may **not** report success for a live Steam call it cannot make.
## `MockSteamBackend` therefore reports `is_mock() == true` and
## `live_steam_proven() == false` unconditionally, and refuses (returns false)
## whenever it is not in a mode that stands in for a working client. The real
## backend reports `live_steam_proven() == false` too, because no automation in
## this repo can prove live Steam: that needs a Steam client, a real App ID and
## a manual run, all of which are open human gates.

## Stable identifier of this backend, for logs and evidence.
func backend_id() -> String:
	return "abstract"


## True for any test double. A mock must say so.
func is_mock() -> bool:
	return false


## True only when a live Steam client has actually been exercised. No backend in
## this repo may return true; the live proof is a manual run, not a test.
func live_steam_proven() -> bool:
	return false


## The single gate. Every achievement, cloud and overlay call in the game goes
## through this. False means "local-only path", which must always be safe.
func is_steam_enabled() -> bool:
	return false


## Initialise the backend. Returns `status` (0 = usable, non-zero = soft failure
## the caller continues through) and `message`.
func init_backend() -> Dictionary:
	return {"status": 1, "message": "abstract backend: nothing initialised", "backend": backend_id()}


## Unlock one achievement by its Steam API name. Returns true only if the
## backend actually accepted the call. An unknown/empty name must return false,
## never a silent success.
func unlock_achievement(_api_name: String) -> bool:
	return false


## Write a file into Steam Cloud (Remote Storage). Returns true only on success.
func cloud_write(_file_name: String, _bytes: PackedByteArray) -> bool:
	return false


## Read a file from Steam Cloud. Empty means "absent or failed"; callers must
## treat an empty result as no cloud copy, never as an empty save.
func cloud_read(_file_name: String) -> PackedByteArray:
	return PackedByteArray()


## Whether Steam Cloud holds a file at all.
func cloud_file_exists(_file_name: String) -> bool:
	return false


## Show the Steam overlay. Cannot be verified headless (see the route evidence).
func show_overlay() -> bool:
	return false


## Call log for tests and evidence. Every backend records what it was asked and
## what it answered.
func calls() -> Array:
	return []
