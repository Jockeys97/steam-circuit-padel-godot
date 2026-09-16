extends SceneTree
## Reports whether the GodotSteam GDExtension is present and what
## `steamInitEx()` returns under the pinned 4.7.2 binary.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://src/steam/probe_steam_addon.gd
##
## This is the closing probe `docs/wayfinder/tickets/steamworks-integration-route.md`
## asks for when the plug-in zip is first fetched. It is a REPORT, not a test:
## it always exits 0, because a non-zero `steamInitEx` status is by design a soft
## failure the game continues past.
##
## With the addon absent (today) it prints, honestly:
##   # Engine.has_singleton("Steam") = false
##   # init status = 2  (singleton absent / client not running — soft)
## and claims nothing else. It uses the real backend class directly, so the
## script below the probe output is the same code path the swap would run.

const RealBackend := preload("res://src/steam/godotsteam_backend.gd")


func _initialize() -> void:
	print("# Steam addon probe (pinned Godot %s)" % Engine.get_version_info().get("string", "?"))
	print("# res://addons/godotsteam/ present = %s" % str(FileAccess.file_exists("res://addons/godotsteam/godotsteam.gdextension") or DirAccess.dir_exists_absolute("res://addons/godotsteam")))
	var has_singleton := Engine.has_singleton("Steam")
	print("# Engine.has_singleton(\"Steam\") = %s" % str(has_singleton))

	var backend: RefCounted = RealBackend.new()
	var init: Dictionary = backend.init_backend()
	print("# init status = %d" % int(init.get("status", -1)))
	print("# init message = %s" % String(init.get("message", "")))
	print("# is_steam_enabled = %s" % str(backend.is_steam_enabled()))
	print("# is_mock = %s (false means this is the real bridge class)" % str(backend.is_mock()))
	print("# live_steam_proven = %s (always false: the live proof is a manual Steam-client run)" % str(backend.live_steam_proven()))
	if not has_singleton:
		print("# RESULT: the addon is not installed in this tree; no Steam behaviour is proven.")
	else:
		print("# RESULT: the singleton exists; a non-zero status above is the documented soft path.")
	quit(0)
