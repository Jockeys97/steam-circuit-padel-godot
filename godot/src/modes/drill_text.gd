## drill_text.gd — the Godot-only drill strings, Italian first.
##
## WHY NOT `UiStrings`. The port's locale layer reads a generated copy of the frozen
## browser reference's string table (`godot/src/locale/locale_data.gd`, verified against
## `js/i18n.js` by `tools/i18n-port/verify-i18n-port.mjs`). The reference has four
## exercises, so a fifth one's name, subtitle, hint and diagnoses cannot come from there,
## and a key written into the generated file by hand would be dropped by the next
## regeneration. They live in `drill_strings.json` — one owner, two tables, no second copy
## — and this module resolves them.
##
## THE REFERENCE'S TABLE WINS. `resolve()` asks `Locale` first: the four reference
## exercises (and any key the reference later gains) are never shadowed by this file, so
## the frozen table stays the single source for everything it already owns. Only an id the
## reference cannot answer falls through to this file's own two tables, with the port's own
## chain: the requested locale, then the fallback locale, then the id itself
## (`godot/src/locale/locale.gd:97-138`). An unknown locale is answered by the fallback,
## exactly as `setLang` does there; nothing here invents a translation.
##
## The ids this module answers are the ones `drill_extras.gd` declares exercises for and
## the ones `drill_session.gd` closes a return attempt with; `tests/modes/drill_audit.gd`
## and `tests/modes/return_drill_audit.gd` prove every one of them resolves in both
## tables — an id that does not would reach the player as the id.
extends RefCounted

const Locale := preload("res://src/locale/locale.gd")

const PATH := "res://src/modes/drill_strings.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		if text.is_empty():
			push_error("drill_text.gd: cannot read %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("drill_text.gd: %s is not a JSON object" % PATH)
			return {}
		_data = parsed
	return _data


static func locales() -> Array[String]:
	var raw: Variant = data().get("locales", [])
	var out: Array[String] = []
	if raw is Array:
		for entry in raw:
			out.append(String(entry))
	return out


static func fallback() -> String:
	var declared := String(data().get("fallback", "it"))
	return declared if locales().has(declared) else "it"


## The text for one id, or the id itself when nothing resolves it — the same visible
## failure mode the port's locale layer has on purpose.
static func t(message_id: String, params: Dictionary = {}, lang: String = "") -> String:
	var text := resolve(message_id, lang)
	for name in params.keys():
		# `str()`, not `String()`: GDScript has no String(int) constructor.
		text = text.replace("{%s}" % str(name), str(params[name]))
	return text


## The port's own chain, with the reference's generated table asked first: an id the frozen
## locale layer can answer is never answered here.
static func resolve(message_id: String, lang: String = "") -> String:
	var target := target_locale(lang)
	if Locale.is_resolvable(message_id, target):
		return Locale.t(message_id, {}, target)
	var primary := strings(target)
	if primary.has(message_id):
		return String(primary[message_id])
	var secondary := strings(fallback())
	if secondary.has(message_id):
		return String(secondary[message_id])
	return message_id


## True when an id produces a sentence rather than itself.
static func has(message_id: String, lang: String = "") -> bool:
	return resolve(message_id, lang) != message_id


## The visible name of one drill exercise, whichever table owns it — the one accessor the
## drill screen and the coach's exercise line share, so the two cannot name the same
## exercise differently.
static func exercise_name(drill_id: String, lang: String = "") -> String:
	return t("drill_%s_name" % drill_id, {}, lang)


static func exercise_desc_key(drill_id: String) -> String:
	return "drill_%s_desc" % drill_id


static func exercise_hint_key(drill_id: String) -> String:
	return "drill_%s_hint" % drill_id


## Every id this file's own two tables define — the audit compares the two against each
## other and against the ids the code can show.
static func ids(lang: String = "") -> Array[String]:
	var out: Array[String] = []
	for key in strings(target_locale(lang)).keys():
		out.append(String(key))
	return out


static func target_locale(lang: String = "") -> String:
	var requested := lang if lang != "" else Locale.current_lang()
	return requested if locales().has(requested) else fallback()


static func strings(lang: String) -> Dictionary:
	var tables: Variant = data().get("strings", {})
	if not (tables is Dictionary):
		return {}
	var table: Variant = (tables as Dictionary).get(lang, {})
	return table if table is Dictionary else {}
