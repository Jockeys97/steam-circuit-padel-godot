extends RefCounted
## One interpretation of the saved music controls for menu, match and settings.
## Disabling music silences only the Music bus and preserves musicVolume for later.

const Schema := preload("res://src/save/save_schema.gd")
const Mixer := preload("res://src/audio/mixer_contract.gd")


static func effective_volume(prefs: Dictionary) -> float:
	if bool(prefs.get("musicMuted", Schema.PREFS_DEFAULTS.get("musicMuted", false))):
		return 0.0
	var raw := float(prefs.get("musicVolume", Schema.PREFS_DEFAULTS.get("musicVolume", 1.0)))
	return clampf(raw if not is_nan(raw) else 0.0, 0.0, 1.0)


static func apply(prefs: Dictionary) -> float:
	return Mixer.new().apply_music_volume(effective_volume(prefs))
