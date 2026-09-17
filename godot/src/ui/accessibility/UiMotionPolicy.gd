## UiMotionPolicy.gd — the one door a UI animation asks before it runs.
##
## THE KNOBS ARE NOT OURS. `godot/src/accessibility/accessibility_settings.gd` already
## owns the two settings and their effects arithmetic — `particle_count:161` is the
## reference's `Math.max(2, round(count * 0.35))` and `shake:168` its 0.5 cap
## (`js/fx.js:26,63`), including the recorded markup divergence
## (`MARKUP_DEFAULT_DIVERGENCE`: `index.html:414` marks the toggle checked while
## `js/ui.js:471` defaults it false). This policy adds the UI layer's own question —
## "may this animation run at all, and for how long" — and forwards everything else, so
## a shell has one thing to call and no way to read a raw pref.
##
## The game-side effects (particles, camera shake) keep using `AccessibilitySettings`
## directly, as they already do; nothing here replaces that, and nothing here is a second
## copy of the settings.
extends RefCounted

const AccessibilitySettings := preload("res://src/accessibility/accessibility_settings.gd")

var _settings: AccessibilitySettings


## `settings` may be the game's own object (`AccessibilitySettings` is wired by
## `godot/game/**`); a policy created without one owns a fresh object for its own shell.
func _init(settings: AccessibilitySettings = null) -> void:
	_settings = settings if settings != null else AccessibilitySettings.new()


## The settings object this policy reads — the same one, not a copy.
func settings() -> AccessibilitySettings:
	return _settings


func reduced_motion() -> bool:
	return _settings.is_reduced_motion()


func colorblind() -> bool:
	return _settings.is_colorblind()


## A UI animation's duration under the player's setting: the length asked for, or none.
## A shell that animates must ask this rather than test the pref itself.
func duration(seconds: float) -> float:
	return 0.0 if reduced_motion() else seconds


## The same question for a shell that only wants a yes or a no.
func motion_allowed() -> bool:
	return not reduced_motion()


## `AccessibilitySettings.particle_count` (`js/fx.js:26`), for a UI effect that has
## particles of its own.
func particle_count(base_count: int) -> int:
	return _settings.particle_count(base_count)


## `AccessibilitySettings.shake` (`js/fx.js:63`) — capped, not zeroed, under reduced
## motion; the reference keeps a little feedback for a hit and drops the sweep.
func shake(amount: float) -> float:
	return _settings.shake(amount)


## Applies the settings screen's saved prefs through the object this policy already
## reads, so the one key mapping (`accessibility_settings.gd:145`) is used once.
func apply_prefs(prefs: Dictionary) -> void:
	_settings.apply_prefs(prefs)
