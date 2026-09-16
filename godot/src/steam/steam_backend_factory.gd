extends RefCounted
class_name SteamBackendFactory
## The single swap point of the Steam seam.
##
## `create()` is the only function in this port that decides which backend the
## game uses. It returns `MockSteamBackend`, so today every build — headless CI,
## a developer machine, an exported build — takes the local-only path and
## nothing is claimed about Steam.
##
## To go live with the real GodotSteam GDExtension
## -----------------------------------------------
## 1. Fetch `godotsteam-4.22.1-gdextension-plugin-4.4.zip` and drop it in as
##    `godot/addons/godotsteam/` (a toolchain acquisition, not authored here).
##    **A bare copy does NOT register the plug-in.** Measured: with the addon
##    present but absent from `godot/.godot/extension_list.cfg`,
##    `Engine.has_singleton("Steam")` is still false, and the addon needs Valve's
##    `libsteam_api.so` next to it (shipped in the zip under `linux64/`). The
##    generated `extension_list.cfg` is produced by opening the project in the
##    editor, or must list `res://addons/godotsteam/godotsteam.gdextension`
##    explicitly.
## 2. Replace the body of `create()` below with the two commented lines:
##
##        var b: SteamBackend = GodotSteamBackendScript.new()
##        b.init_backend()   # non-zero status leaves the gate closed: the soft path
##        return b
##
##    That is the whole change. Nothing else moves: achievements and cloud go
##    through `achievements.gd` / `cloud_saves.gd`, which only know the
##    `SteamBackend` interface, and a non-zero `steamInitEx` status keeps
##    `is_steam_enabled()` false so a Steam-less machine still runs on local
##    saves alone.
## 3. Run `res://src/steam/probe_steam_addon.gd` to record what the pinned binary
##    reports on this machine. Do it BEFORE trusting a live run, and read
##    `docs/wayfinder/evidence/steam-addon-verification.md` first: the state it
##    records is **status 1, not 0**, because there is no Steam client here.
##
## Verified against the real plug-in (2026-09-16, crew-steam)
## ---------------------------------------------------------
## The addon's 4.7.2 compatibility is no longer a guess: the 4.4-ABI GDExtension
## loads in `4.7.2.stable.official.ed1daf0bf`, `Engine.has_singleton("Steam")` is
## true and 798 methods are registered. Every Steam API name in
## `godotsteam_backend.gd` was checked against that registered surface and against
## upstream source at release commit `5853a7741d174cfa37edee1ca44a11581a989d0b`;
## the two names that were wrong were corrected (`fileRead` arity and its return
## keys). What is still unproven is live behaviour — that needs a Steam client, an
## App ID and a manual run — so `live_steam_proven()` stays false.

const MockBackend := preload("res://src/steam/mock_steam_backend.gd")
const GodotSteamBackendScript := preload("res://src/steam/godotsteam_backend.gd")

## Sentinel: use the mock's own default mode (UNAVAILABLE — the honest no-Steam
## path). A real mode constant cannot be a default argument of a static function
## without depending on the class cache, so the sentinel keeps this robust.
const DEFAULT_MODE: int = -1


## THE SWAP POINT.
static func create(mock_mode: int = DEFAULT_MODE) -> RefCounted:
	# ----- live swap: replace the next line only (see the header) -----
	return MockBackend.new(MockBackend.Mode.UNAVAILABLE if mock_mode == DEFAULT_MODE else mock_mode)
	# ------------------------------------------------------------------


## Create and initialise in one step. The returned dictionary carries the init
## status, so a caller can log it without a second call.
static func create_initialised(mock_mode: int = DEFAULT_MODE) -> Dictionary:
	var backend: RefCounted = create(mock_mode)
	var init: Dictionary = backend.init_backend()
	return {
		"backend": backend,
		"status": int(init.get("status", 1)),
		"message": String(init.get("message", "")),
		"enabled": backend.is_steam_enabled(),
		"is_mock": backend.is_mock(),
		"live_steam_proven": backend.live_steam_proven(),
	}
