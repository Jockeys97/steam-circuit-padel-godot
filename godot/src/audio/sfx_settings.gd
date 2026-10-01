extends RefCounted
## One interpretation of the saved game-effects level for menu, match and settings.
## This only scales SFX; master and soundtrack preferences remain independent.

const Schema := preload("res://src/save/save_schema.gd")
const Mixer := preload("res://src/audio/mixer_contract.gd")


static func effective_volume(prefs: Dictionary) -> float:
	var raw := float(prefs.get("sfxVolume", Schema.PREFS_DEFAULTS.get("sfxVolume", 1.0)))
	return clampf(raw if not is_nan(raw) else 0.0, 0.0, 1.0)


static func apply(prefs: Dictionary) -> float:
	return Mixer.new().apply_sfx_volume(effective_volume(prefs))
