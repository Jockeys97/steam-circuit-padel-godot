## UiStrings.gd — the one door a UI script opens to turn a message id into text.
##
## THE CHAIN IS NOT REPEATED HERE, IT IS FORWARDED. `godot/src/locale/locale.gd`
## owns the resolution (`t` at `:97-138`: the requested locale, then the fallback
## locale, then the id itself — ported from `js/i18n.js:1408-1414`), and
## `is_resolvable` (`:148-154`) is the same chain asked as a question.
##
## THIS FILE OWNS NO TABLE, on purpose. A screen that spells a sentence into a
## script is the defect the reference's own i18n gate exists for
## (`scripts/i18n-audit.mjs`; `docs/.../locale` lane), so the port keeps the seam
## narrow enough that a reviewer can read it in one screenful and
## `godot/tests/ui/router_audit.gd` can scan the UI lane for prose with no
## exceptions to remember.
##
## The last step of the chain is a *feature of the reference*, not a safety net:
## `t("does_not_exist_key")` returns `does_not_exist_key`, which is how a missing
## translation becomes visible on screen instead of silent (the port's own history:
## `ai_leggenda_name` was missing and the player read `AI_LEGGENDA_NAME` for a whole
## match — `godot/src/locale/locale.gd:11-17`). `has()` exists so a caller can ask
## first and choose a deliberate fallback rather than guess.
extends RefCounted

const Locale := preload("res://src/locale/locale.gd")


## The text for a message id, or the id itself when nothing resolves it.
##
## Params arrive as whatever the caller has at hand — a count is a count — and the
## reference interpolates a number as text (`js/i18n.js` tables carry `{n}` for counts,
## and JS `replace` stringifies). The frozen locale module splices `String(value)`, and
## GDScript has no `String(int)` constructor, so the door normalizes the values: the
## seam stays narrow and no caller has to remember.
static func t(message_id: String, params: Dictionary = {}) -> String:
	if params.is_empty():
		return Locale.t(message_id)
	var normalized := {}
	for key in params.keys():
		normalized[key] = str(params[key])
	return Locale.t(message_id, normalized)


## True when the id resolves to a sentence in the current locale or the fallback
## one. `UiStrings.has("does_not_exist_key")` is false; `t()` on the same id still
## answers, with the id.
static func has(message_id: String) -> bool:
	return Locale.is_resolvable(message_id)
