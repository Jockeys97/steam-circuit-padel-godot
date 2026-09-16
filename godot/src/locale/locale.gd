## locale.gd — the port's locale layer: message ids in, sentences out.
##
## The ported simulation stores message ids, not text
## (`docs/wayfinder/tickets/simulation-port-boundary.md` §2; the port's own note is
## `godot/src/sim/state.gd`: `events` and `pointMessage` hold ids). This is where an
## id becomes something a player can read, and it is the only place that may call
## into the string table.
##
## The behaviour is not designed here, it is copied from the reference:
##
##   - `t(key, params)` = `DICT[lang][key] ?? DICT.it[key] ?? key` — the requested
##     locale, then the fallback locale, then **the id itself** (js/i18n.js:1408-1414).
##     That last step is not a safety net, it is the failure the port must be able to
##     see: `ai_leggenda_name` was missing and the player read "AI_LEGGENDA_NAME" for
##     a whole match (git 1652240). `is_resolvable()` exists so a caller can assert
##     instead of guessing, and `tools/i18n-port/verify-i18n-port.mjs` fails when an
##     id the simulation can emit resolves to nothing.
##   - `setLang(lang)` silently falls back for a locale the table does not have
##     (js/i18n.js:1400-1402). There is no German table in the reference, so a German
##     request answers in Italian — see `tools/i18n-port/resolve-rules.json`
##     `absentLocales`. Nothing here invents a translation.
##   - `{name}` placeholders are replaced one by one (js/i18n.js:1411-1413). A
##     placeholder with no parameter is left in the output, braces and all: that is
##     what the reference does, and it is visible on screen, which is the point.
##
## The data lives in the generated `locale_data.gd` (never edited by hand) and the
## resolution rules in `locale_rules.json` (declarative, so the engine-free drift
## test can apply the same rules without a Godot binary).
extends RefCounted

const Data := preload("res://src/locale/locale_data.gd")

const RULES_PATH := "res://src/locale/locale_rules.json"

static var _lang: String = ""
static var _rules: Dictionary = {}


## The declared rules, loaded once. A missing or malformed file is loud: a silent
## default would resolve composite ids as if they were plain keys.
static func rules() -> Dictionary:
	if _rules.is_empty():
		var text := FileAccess.get_file_as_string(RULES_PATH)
		if text.is_empty():
			push_error("locale.gd: cannot read %s" % RULES_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("locale.gd: %s is not a JSON object" % RULES_PATH)
			return {}
		_rules = parsed
	return _rules


static func default_lang() -> String:
	return String(rules().get("defaultLocale", Data.DEFAULT_LANG))


static func fallback_lang() -> String:
	return String(rules().get("fallbackLang", Data.FALLBACK_LANG))


## The locales the reference actually has. There is no other: see the contract.
static func locales() -> Array:
	return Data.LOCALES.duplicate()


static func has_locale(lang: String) -> bool:
	return Data.TABLES.has(lang)


## `setLang` (js/i18n.js:1400-1402). Unknown locale: fall back, silently, exactly
## like the reference — the caller that wants to complain checks `has_locale()`
## first.
static func set_lang(lang: String) -> void:
	_lang = lang if has_locale(lang) else fallback_lang()


static func current_lang() -> String:
	if _lang == "":
		_lang = default_lang()
	return _lang


static func table(lang: String) -> Dictionary:
	var tables := Data.TABLES
	if not tables.has(lang):
		return {}
	return tables[lang]


static func has_key(key: String, lang: String = "") -> bool:
	var target := lang if lang != "" else current_lang()
	return table(target).has(key) or table(fallback_lang()).has(key)


## `t(key, params)` (js/i18n.js:1408-1414).
static func t(message_id: String, params: Dictionary = {}, lang: String = "") -> String:
	var target := lang if lang != "" else current_lang()
	return substitute(resolve(message_id, target), params)


## Resolves one message id for one locale, without substituting placeholders.
## Composite ids (`controlMsg:roleBackPos`, `pointOpp:msgOut`) are split on the
## declared separator and bound by the declared rule; a composite with no rule is
## looked up as a plain key, which is how it ends up visible as an id.
static func resolve(message_id: String, lang: String) -> String:
	var sep := String(rules().get("compositeSeparator", ":"))
	var cut := message_id.find(sep)
	if cut > 0:
		var parent := message_id.substr(0, cut)
		var arg := message_id.substr(cut + sep.length())
		var composite: Dictionary = rules().get("compositeRules", {})
		var rule: Variant = composite.get(parent)
		if rule is Dictionary:
			var binding := String((rule as Dictionary).get("binding", ""))
			if binding == "placeholder":
				var bound := {}
				bound[String((rule as Dictionary).get("placeholder", ""))] = resolve(arg, lang)
				return substitute(lookup(parent, lang), bound)
			if binding == "suffix":
				if arg == "":
					return lookup(parent, lang)
				return lookup(parent, lang) + String((rule as Dictionary).get("separator", " · ")) + resolve(arg, lang)
			push_error("locale.gd: composite rule '%s' has unknown binding '%s'" % [parent, binding])
	return lookup(message_id, lang)


## The fallback chain of `t()`: requested locale, then the fallback locale, then
## the id itself. The last branch is the bug class, not a feature.
static func lookup(key: String, lang: String) -> String:
	var primary := table(lang)
	if primary.has(key):
		return String(primary[key])
	var secondary := table(fallback_lang())
	if secondary.has(key):
		return String(secondary[key])
	return key


static func substitute(text: String, params: Dictionary) -> String:
	var out := text
	for name in params.keys():
		out = out.replace("{%s}" % String(name), String(params[name]))
	return out


## True when an id produces a sentence rather than itself. A caller that has to
## show something can use this to fall back to a deliberate placeholder instead of
## printing an id; the drift test uses it to prove nothing on the emit path is
## unresolved.
static func is_resolvable(message_id: String, lang: String = "") -> bool:
	var target := lang if lang != "" else current_lang()
	return resolve(message_id, target) != message_id


## The placeholders a message id still needs, in the order they appear. An empty
## array means the id is self-contained; a non-empty one means the caller owes
## `t()` a params dictionary (the simulation's `serveHint` owes two — see the
## debt ledger in tools/i18n-port/unresolved-baseline.json).
static func required_params(message_id: String, lang: String = "") -> Array:
	var text := resolve(message_id, lang if lang != "" else current_lang())
	var found: Array = []
	for part in text.split("{").slice(1):
		var close := part.find("}")
		if close > 0:
			var name := part.substr(0, close)
			if not found.has(name):
				found.append(name)
	return found
