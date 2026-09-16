## strings.gd — the locale seam of the input surface: every string the controller
## navigation and the on-screen keyboard put in front of a player, resolved
## through `godot/src/locale/**` and never through a table of its own.
##
## The reference keeps these in the one dictionary (`js/i18n.js`) that
## `scripts/i18n-audit.mjs` walks, and the port keeps its single seam: this file
## owns *ids*, not text, so the id set can be enumerated and asserted resolvable
## per locale. The contract is deliberately thin — `Locale.t()` with its
## `requested → fallback → the id itself` chain (`godot/src/locale/locale.gd:97-138`)
## is the whole resolution, and `unresolvable()` is how a caller proves an id does
## not end up printed as itself.
##
## Ids come from the reference's own input surfaces, with the anchor that uses
## them:
##
##   padHints1-3, padMenuHint  the pad help line (`js/main.js`, `js/i18n.js:163-165,286`)
##   oskShift/Space/Backspace/Done/Hint, ariaOsk
##                             the on-screen keyboard's action keys and its label
##                             (`js/main.js:493-509`, `:517-524`)
##   *_Lbl / pad*Desc          the controller legend of `index.html:243-257`
##   ariaInputTabs, ariaControlsLegend, helpKeyboard, helpGamepad
##                             the help screen's device tabs (`index.html:221-243`)
##   back, controlLbl, gamepadConnected, gamepadDisconnected, controllerDetected
##                             the navigation and controller-status labels
##   reduceMotion, colorblind  the two accessibility toggles (`index.html:414-420`),
##                             owned by `godot/src/accessibility/**`
##
## Nothing here composes a sentence, substitutes a placeholder or falls back on its
## own: a missing id must be visible, which is the point of
## `tools/i18n-port/hud-coverage.mjs --fail-on-leak`.
extends RefCounted

const Locale := preload("res://src/locale/locale.gd")

## The pad help lines, in the reference's order.
const PAD_HINTS := ["padHints1", "padHints2", "padHints3"]
## The menu-only pad help line (`js/i18n.js:286`).
const MENU_HINT := "padMenuHint"

## The on-screen keyboard: its action keys and its announced name.
const OSK_LABELS := {
	"shift": "oskShift",
	"space": "oskSpace",
	"backspace": "oskBackspace",
	"done": "oskDone",
}
const OSK_HINT := "oskHint"
const OSK_ARIA := "ariaOsk"

## The controller legend of `index.html:243-257`, key for key.
const LEGEND := [
	{"control": "LS", "label_id": "moveLbl", "desc_id": "padMoveDesc"},
	{"control": "RS", "label_id": "aimLbl", "desc_id": "padAimDesc"},
	{"control": "A", "label_id": "driveLbl", "desc_id": "padDriveDesc"},
	{"control": "X", "label_id": "sliceLbl", "desc_id": "padSliceDesc"},
	{"control": "Y", "label_id": "lobLbl", "desc_id": "padLobDesc"},
	{"control": "B", "label_id": "specialLbl", "desc_id": "padSpecialDesc"},
	{"control": "LB", "label_id": "switchLbl", "desc_id": "padSwitchDesc"},
	{"control": "LT", "label_id": "splitStepLbl", "desc_id": "padSplitStepDesc"},
	{"control": "RT", "label_id": "sprintLbl", "desc_id": "padSprintDesc"},
	{"control": "RB", "label_id": "technicalLbl", "desc_id": "padTechnicalDesc"},
	{"control": "D-PAD", "label_id": "tacticsLbl", "desc_id": "padTacticsDesc"},
	{"control": "A+A", "label_id": "smashLbl", "desc_id": "padSmashDesc"},
	{"control": "☰", "label_id": "pauseLbl", "desc_id": "padPauseDesc"},
]

## The keyboard legend of `index.html:227-235`, by the key printed in the markup.
const KEYBOARD_LEGEND := [
	{"keys": "WASD", "label_id": "moveNet"},
	{"keys": "Space", "label_id": "chargeShot"},
	{"keys": "⌘", "label_id": "chargeSlice"},
	{"keys": "A/D/←/→", "label_id": "aimWhile"},
	{"keys": "Option", "label_id": "specialBtn"},
	{"keys": "Z", "label_id": "switchBtn"},
	{"keys": "Esc", "label_id": "pauseBtn"},
]

## The remaining single ids on the navigation and status paths.
const NAV_LABELS := [
	"back",
	"controlLbl",
	"controllerDetected",
	"gamepadConnected",
	"gamepadDisconnected",
	"heroPadNote",
	"ariaInputTabs",
	"ariaControlsLegend",
	"ariaStickTest",
	"ariaControllerSettings",
	"ariaControlMode",
	"helpKeyboard",
	"helpGamepad",
	"tabController",
	"genericControllerLayout",
]

## The accessibility labels, owned by `godot/src/accessibility/**`, named here so
## one inventory covers every string the input and settings surfaces resolve.
const ACCESSIBILITY_LABELS := ["reduceMotion", "colorblind", "accessibility", "deadzone", "vibration"]

## Every id this module resolves, deduplicated, in declaration order.
static func owned_ids() -> Array:
	var out: Array = []
	for group in [PAD_HINTS, [MENU_HINT], [OSK_HINT, OSK_ARIA], OSK_LABELS.values(), LEGEND.map(_legend_ids), KEYBOARD_LEGEND.map(_keyboard_ids), NAV_LABELS, ACCESSIBILITY_LABELS]:
		for entry in group:
			if entry is Array:
				for id in entry:
					if not out.has(String(id)):
						out.append(String(id))
			elif not out.has(String(entry)):
				out.append(String(entry))
	return out


static func _legend_ids(row: Dictionary) -> Array:
	return [row["label_id"], row["desc_id"]]


static func _keyboard_ids(row: Dictionary) -> Array:
	return [row["label_id"]]


## The one resolution path: the locale seam, never a private table.
static func text(message_id: String, lang: String = "") -> String:
	return Locale.t(message_id, {}, lang)


## Every id that would print as itself in that locale — the failure
## `AI_LEGGENDA_NAME` was, and the one this module must not introduce.
static func unresolvable(lang: String = "") -> Array:
	var out: Array = []
	for message_id in owned_ids():
		if not Locale.is_resolvable(message_id, lang):
			out.append(message_id)
	return out


## The pad help lines, resolved, in the reference's order.
static func pad_hints(lang: String = "") -> Array:
	var out: Array = []
	for message_id in PAD_HINTS:
		out.append(text(message_id, lang))
	return out


static func menu_hint(lang: String = "") -> String:
	return text(MENU_HINT, lang)


## `openOsk`'s label composition (`js/main.js:517-524`): the field's own label,
## then the hint — so the player knows what they are typing into.
static func osk_label(field_label: String, lang: String = "") -> String:
	var hint := text(OSK_HINT, lang)
	if field_label.strip_edges() == "":
		return hint
	return "%s · %s" % [field_label, hint]


## The action keys of the on-screen keyboard, in the reference's order, resolved.
static func osk_labels(lang: String = "") -> Array:
	var out: Array = []
	for name in OSK_LABELS:
		out.append({"id": name, "label_id": OSK_LABELS[name], "text": text(OSK_LABELS[name], lang)})
	return out
