## accessibility_settings.gd — the accessibility knobs the reference actually has,
## as a model plus the two effects they drive.
##
## The reference has exactly **two** accessibility toggles. `index.html:412-421`
## puts them in one group:
##
##   <span data-i18n="accessibility">Accessibilità</span>
##   <input id="optReduceMotion" type="checkbox" checked />  reduceMotion
##   <input id="optColorblind"  type="checkbox" />           colorblind
##
## `applyAccessibility()` (`js/main.js:2300-2305`) is what they do: it toggles
## `body.reduce-motion` and `body.mode-colorblind` and forwards the motion flag to
## the effects layer (`setReduceMotion`, `js/fx.js:4-6`). The effects are concrete
## and are ported here so a test can observe them rather than read a flag:
##
##   reduced motion  →  particle counts to at most 35 % with a floor of 2
##                      (`js/fx.js:26`), and shake capped at 0.5 (`js/fx.js:63`)
##   colourblind     →  a colour filter on the 3D view and the hero preview
##                      (`styles.css:2726-2728`)
##
## Everything else the ticket's title might suggest is **named as absent, not
## invented** — see `ABSENT`, printed by the audit as a note. There is no large
## text / font-scale setting, no high-contrast mode and no screen-reader API in the
## reference, and the port adds none: a knob that exists only in the port would be a
## claim about accessibility the reference cannot back.
##
## Two rules the rest of the port depends on, stated here so they can be asserted:
##
##   - **The audio layer never reads the motion setting.** `js/audio.js` has no
##     match for it, and this slice keeps that: reduced motion is presentation, not
##     sound. `godot/src/audio/**` is read by the audit to prove it still holds.
##   - **The keyboard is the fallback path.** `keyboard_policy()` reports the pad-only
##     actions by name, because "every pad action has a keyboard equivalent" is not
##     true of the reference and a port that claimed it would be lying.
extends RefCounted

const Locale := preload("res://src/locale/locale.gd")
const Scheme := preload("res://src/input/scheme.gd")
const InputStrings := preload("res://src/input/strings.gd")

const REDUCE_MOTION := "reduce_motion"
const COLORBLIND := "colorblind"

## The reference's two toggles, with what each one does and where it is wired.
const SETTINGS := [
	{
		"id": REDUCE_MOTION,
		"locale_key": "reduceMotion",
		"default": false,
		"reference": "index.html:414,415 · js/ui.js:471 · js/main.js:2214,2300-2305 · js/fx.js:2-10",
		"effect": "particle counts to at most 35% with a floor of 2 (js/fx.js:26); shake capped at 0.5 (js/fx.js:63); CSS animation and transition off, focus ring widened (styles.css:2715-2722)",
	},
	{
		"id": COLORBLIND,
		"locale_key": "colorblind",
		"default": false,
		"reference": "index.html:418,419 · js/ui.js:474 · js/main.js:2215,2302",
		"effect": "a colour filter on the 3D view and the hero preview (styles.css:2726-2728)",
	},
]

## Settings the ticket's name invites and the reference does not have. Listed so
## the gap is visible in the evidence instead of looking like an oversight.
const ABSENT := [
	{
		"id": "large_text / font_scale",
		"why": "index.html's settings screen has language, accessibility (two toggles), audio/controller and feedback sections only; no font-size, zoom or text-scale control exists anywhere in index.html, styles.css or js/",
	},
	{
		"id": "high_contrast",
		"why": "colourblind mode is a colour filter (styles.css:2726-2728); there is no contrast or theme setting",
	},
	{
		"id": "screen_reader_api",
		"why": "the reference's accessible names are DOM attributes (58 data-i18n-aria hooks, 81 aria-* attributes in index.html); Godot exposes no DOM, so the port keeps named controls and a keyboard path, and claims no screen-reader parity",
	},
	{
		"id": "caption / subtitle_size",
		"why": "there are no captions in the reference to size",
	},
	{
		"id": "hold_vs_toggle",
		"why": "no input-assist options (hold-to-charge, auto-aim, one-button) exist in the reference",
	},
]

## The reference's markup default for reduced motion is `checked` while the state
## default is `false`; the state wins as soon as the settings screen syncs
## (`js/main.js:2376`). Recorded because it is a real disagreement inside the
## reference, not something to copy silently.
const MARKUP_DEFAULT_DIVERGENCE := "index.html:414 marks optReduceMotion `checked` while js/ui.js:471 defaults ui.reduceMotion to false and js/main.js:2376 assigns the state onto the checkbox when the settings screen syncs"

## `styles.css:2715-2722` — what reduced motion means for the effects layer.
const PARTICLE_FLOOR := 2
const PARTICLE_FACTOR := 0.35
const SHAKE_CAP := 0.5

## Named controls: control id → the locale key that names it. The port's stand-in
## for the reference's `aria-label`/`data-i18n-aria` discipline (`index.html`).
const CONTROL_LABELS := {
	"osk": "ariaOsk",
	"osk_grid": "ariaOsk",
	"input_tabs": "ariaInputTabs",
	"controls_legend": "ariaControlsLegend",
	"stick_monitor": "ariaStickTest",
	"controller_settings": "ariaControllerSettings",
	"control_mode": "ariaControlMode",
	"help_screen": "ariaHelp",
	"settings_screen": "ariaSettings",
	"menu_screen": "ariaMenu",
}

var _values := {}


func _init() -> void:
	for setting in SETTINGS:
		_values[String(setting["id"])] = bool(setting["default"])


func set_enabled(setting_id: String, enabled: bool) -> bool:
	if not _values.has(setting_id):
		return false
	_values[setting_id] = enabled
	return true


func is_enabled(setting_id: String) -> bool:
	return bool(_values.get(setting_id, false))


func is_reduced_motion() -> bool:
	return is_enabled(REDUCE_MOTION)


func is_colorblind() -> bool:
	return is_enabled(COLORBLIND)


## What to persist (`collectPrefs`, `js/ui.js:422-442`), as the same booleans.
func prefs() -> Dictionary:
	return _values.duplicate()


func apply_prefs(prefs: Dictionary) -> void:
	for setting in SETTINGS:
		var key := String(setting["id"])
		var camel := String(setting["locale_key"])
		if prefs.has(key) and typeof(prefs[key]) == TYPE_BOOL:
			_values[key] = bool(prefs[key])
		# The reference's saved keys are camelCase (`reduceMotion`, `colorblind`).
		elif prefs.has(camel) and typeof(prefs[camel]) == TYPE_BOOL:
			_values[key] = bool(prefs[camel])


# ---------------------------------------------------------------------------
# The effects layer
# ---------------------------------------------------------------------------

## `js/fx.js:26`: `if (reducedMotion) count = Math.max(2, Math.round(count * 0.35))`.
func particle_count(base_count: int) -> int:
	if not is_reduced_motion():
		return base_count
	return maxi(PARTICLE_FLOOR, int(round(float(base_count) * PARTICLE_FACTOR)))


## `js/fx.js:63`: `if (reducedMotion) fx.shake = Math.min(fx.shake ?? 0, 0.5)`.
func shake(amount: float) -> float:
	if not is_reduced_motion():
		return amount
	return minf(amount, SHAKE_CAP)


## The label of a toggle, resolved through the locale seam — never a private
## string (`scripts/i18n-audit.mjs` is the reference's gate for exactly this).
func label(setting_id: String, lang: String = "") -> String:
	for setting in SETTINGS:
		if String(setting["id"]) == setting_id:
			return InputStrings.text(String(setting["locale_key"]), lang)
	return ""


## A named control's accessible name, or `""` when the control has none.
func control_label(control_id: String, lang: String = "") -> String:
	if not CONTROL_LABELS.has(control_id):
		return ""
	return Locale.t(String(CONTROL_LABELS[control_id]), {}, lang)


## Controls that would have no name: the audit asserts this list is empty.
func unnamed_controls() -> Array:
	var out: Array = []
	for control_id in CONTROL_LABELS:
		if not Locale.is_resolvable(String(CONTROL_LABELS[control_id])):
			out.append(control_id)
	return out


## The keyboard policy, with the pad-only actions named rather than glossed.
func keyboard_policy() -> Dictionary:
	var pad_only: Array = []
	for action in Scheme.ids():
		if Scheme.devices(action) == ["pad"]:
			pad_only.append(action)
	return {
		"navigation_always_available": true,
		"text_entry": "on-screen keyboard when a pad is connected (js/main.js:701-704); the platform decision on touch and the OSK is postponed, not dropped",
		"pad_only_actions": pad_only,
		"pad_only_count": pad_only.size(),
		"note": "the browser wires these on the pad only (GAMEPLAY_RULES.md:159-175); the port does not invent keyboard keys for them",
	}
