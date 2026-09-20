## coach_text.gd — the coach's own sentences, Italian first.
##
## WHY NOT `UiStrings`. The port's locale layer reads a generated copy of the frozen
## browser reference's string table (`godot/src/locale/locale_data.gd`, verified against
## `js/i18n.js` by `tools/i18n-port/verify-i18n-port.mjs`). The reference has no coach,
## so these ids cannot come from it, and a key written into that generated file by hand
## would be dropped by the next regeneration. They live in `coach_strings.json` — one
## owner, two tables, no second copy — and this module resolves them with the port's own
## chain: the requested locale, then the fallback locale, then the id itself
## (`godot/src/locale/locale.gd:97-138`). An unknown locale is answered by the fallback,
## exactly as `setLang` does there; nothing here invents a translation.
##
## The sentence ids the coach can show are the ones `coach_advice.gd` and
## `godot/src/ui/coach/CoachPanel.gd` name, and the coach test proves every one of them
## resolves in both tables — an id that does not would reach the player as `coachTitle`.
extends RefCounted

const Locale := preload("res://src/locale/locale.gd")

const PATH := "res://src/coach/coach_strings.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		if text.is_empty():
			push_error("coach_text.gd: cannot read %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("coach_text.gd: %s is not a JSON object" % PATH)
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
		# `str()`, not `String()`: GDScript has no String(int) constructor, and these
		# parameters are counts — the same normalization `UiStrings.t()` makes for the
		# port's own tables.
		text = text.replace("{%s}" % str(name), str(params[name]))
	return text


static func resolve(message_id: String, lang: String = "") -> String:
	var target := target_locale(lang)
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


## The placeholders an id still needs, in order: a template that quotes numbers owes
## the caller those parameters, and the coach test reads them off both tables.
static func placeholders(message_id: String, lang: String = "") -> Array[String]:
	var out: Array[String] = []
	for part in resolve(message_id, lang).split("{").slice(1):
		var close := part.find("}")
		if close > 0:
			var name := part.substr(0, close)
			if not out.has(name):
				out.append(name)
	return out


## Every id one table defines — the coach test compares the two tables against each
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
