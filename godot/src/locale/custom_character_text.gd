extends RefCounted
## custom_character_text.gd — the port's own strings for the create-a-character slice,
## Italian first.
##
## WHY NOT `locale_data.gd`. That file is a generated copy of the frozen browser
## reference's string table (`tools/i18n-port/verify-i18n-port.mjs` checks it against
## `js/i18n.js`), so a key written into it by hand would be dropped by the next
## regeneration — the same reason `src/modes/drill_text.gd` and
## `src/coach/coach_text.gd` keep the port's own strings beside it. The reference has no
## create-a-character screen, so its labels cannot come from there.
##
## It also keeps `src/ui/**` free of prose literals: the router's own literal scan
## (`tests/ui/router_audit.gd`) reads every UI script and flags any string containing a
## space, so a screen asks this module for its words instead of typing them.
##
## Resolution order: the frozen `Locale` table first (an id the reference owns is never
## shadowed), then this file's own two tables, then the id itself — the port's chain.

const Locale := preload("res://src/locale/locale.gd")

const FALLBACK := "it"

const STRINGS := {
	"it": {
		"customHint": "Crea il tuo stile. Le scelte estetiche non cambiano le abilità.",
		"customBalanced": "Atleta personalizzato · Bilanciato",
		"customCreateEntry": "CREA ATLETA",
		"customEditorTitle": "CREA ATLETA",
		"customFieldName": "NOME",
		"customFieldBody": "CORPO",
		"customFieldSkin": "PELLE",
		"customFieldHair": "CAPELLI",
		"customFieldHairColor": "COLORE CAPELLI",
		"customFieldOutfit": "COMPLETO",
		"customFieldOutfitColor": "COLORE COMPLETO",
		"customActionSave": "SALVA",
		"customActionCancel": "ANNULLA",
		"customActionBack": "INDIETRO",
		"customRotateLeft": "RUOTA A SINISTRA",
		"customRotateRight": "RUOTA A DESTRA",
		"customCloseUp": "PRIMO PIANO",
		"customFullBody": "CORPO INTERO",
		"customChoiceHint": "Sinistra/destra: cambia scelta · Su/giù: cambia riga",
		"customErrorRig": "impossibile costruire l'atleta",
		"customErrorPreview": "impossibile aggiornare l'anteprima",
		"customErrorSave": "salvataggio non riuscito",
	},
	"en": {
		"customHint": "Create your style. Appearance does not change your abilities.",
		"customBalanced": "Custom athlete · Balanced",
		"customCreateEntry": "CREATE ATHLETE",
		"customEditorTitle": "CREATE ATHLETE",
		"customFieldName": "NAME",
		"customFieldBody": "BODY",
		"customFieldSkin": "SKIN",
		"customFieldHair": "HAIR",
		"customFieldHairColor": "HAIR COLOR",
		"customFieldOutfit": "OUTFIT",
		"customFieldOutfitColor": "OUTFIT COLOR",
		"customActionSave": "SAVE",
		"customActionCancel": "CANCEL",
		"customActionBack": "BACK",
		"customRotateLeft": "ROTATE LEFT",
		"customRotateRight": "ROTATE RIGHT",
		"customCloseUp": "CLOSE UP",
		"customFullBody": "FULL BODY",
		"customChoiceHint": "Left/right: change choice · Up/down: change row",
		"customErrorRig": "the athlete could not be built",
		"customErrorPreview": "the preview could not be updated",
		"customErrorSave": "save failed",
	},
}


static func locales() -> Array:
	return STRINGS.keys()


static func option(id: String) -> String:
	var names := {
		"buzz": ["Rasati", "Buzz cut"], "crop": ["Corti", "Short crop"],
		"curly": ["Ricci", "Curly"], "bun": ["Chignon", "Bun"],
		"donna_media": ["Donna", "Woman"], "donna_atletica": ["Donna atletica", "Athletic woman"],
		"uomo_medio": ["Uomo", "Man"], "uomo_robusto": ["Uomo robusto", "Strong man"],
		"uomo_b": ["Uomo stilizzato B", "Stylized man B"],
		"ponytail": ["Coda", "Ponytail"], "circuit": ["Circuito", "Circuit"],
		"training": ["Allenamento", "Training"], "varsity": ["Club", "Club"],
		"porcelain": ["Porcellana", "Porcelain"], "light": ["Chiara", "Light"],
		"tan": ["Dorata", "Tan"], "olive": ["Olivastra", "Olive"],
		"brown": ["Castano", "Brown"], "deep": ["Scura", "Deep"],
		"black": ["Nero", "Black"], "blonde": ["Biondo", "Blonde"],
		"auburn": ["Ramato", "Auburn"], "grey": ["Grigio", "Grey"],
		"violet": ["Viola", "Violet"], "coral": ["Corallo", "Coral"],
		"azure": ["Azzurro", "Azure"], "lime": ["Lime", "Lime"],
		"graphite": ["Grafite", "Graphite"], "sand": ["Sabbia", "Sand"],
	}
	return String(names.get(id, [id, id])[0 if Locale.current_lang() == "it" else 1])


static func t(message_id: String, lang: String = "") -> String:
	var target := lang if lang != "" else Locale.current_lang()
	if target == "":
		target = FALLBACK
	if Locale.has_key(message_id, target):
		return Locale.t(message_id, {}, target)
	var primary: Dictionary = STRINGS.get(target, {})
	if primary.has(message_id):
		return String(primary[message_id])
	var secondary: Dictionary = STRINGS.get(FALLBACK, {})
	if secondary.has(message_id):
		return String(secondary[message_id])
	return message_id
