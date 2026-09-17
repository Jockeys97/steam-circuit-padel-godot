extends SceneTree
## feedback_vocabulary_test.gd — the match-feedback vocabulary seam
## (architecture-deepening gate 1): ONE owner for the grade/mode id encodings, the
## words and the colours the shot feedback resolves to.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##       --script res://tests/feedback_vocabulary_test.gd
##
## What it proves, and where every expected value comes from:
##   1. THE OWNER. The vocabulary lives in `res://game/feedback_vocabulary.gd`,
##      the legacy HUD no longer declares any of it — including the event log's
##      knowledge, `EVENT_LABELS` and its resolver — and the module does not read
##      the legacy HUD (it is not a pass-through). What the legacy HUD keeps is
##      its own painting: the log's lines and the panel maths.
##   2. THE SHIPPING CALLER. `match_controller.gd` takes every vocabulary answer
##      from the module; its only remaining use of the legacy HUD script is the
##      mount (`HudScript.new()`), which gate 4 owns. The hidden legacy HUD is no
##      longer there solely to expose vocabulary.
##   3. THE WORDS (`js/game.js:1062-1069`). `shot:<grade>` -> `shot<Grade>` and
##      `shotMode:<mode>` -> `shotMode<Mode>`, resolved through the locale layer;
##      the bare ids the smash branch stores (`sim.gd:1794-1795`) and the
##      missed-contact id (`sim.gd:2590`); the advice word `js/render.js:1730`
##      draws (`shotAdvice_<advice>`, uppercase), with the reference's own
##      `?? "read"` default.
##   4. THE COLOURS. The field verdict's four and its white fallback
##      (`js/render.js:1044-1052`), the energy bands (`js/render.js:1036`), the
##      precision fill and its strict `tight > 0.02` (`js/render.js:1709-1717`)
##      and the advice tone (`js/render.js:1745`), plus the port's own panel
##      palette as shipped (a parity value: `hud.gd`'s pre-move `GRADE_COLORS`).
##   5. THE EVENT LOG. The module owns the generated `EVENT_LABELS` floor and the
##      resolver that reads it (`describe_event`/`reason_label`: the verified
##      locale layer first, the floor second, `UNREADABLE` — never an id), and the
##      legacy HUD's log asks the module for every line instead of holding a table
##      of its own.
##
## Output contract for CI: one `ok <name>` / `FAIL <name>: …` line per check, then
## `PASS <n>/<n>` or `FAIL <n>/<n>`. Exit 0 = every check green.

const Vocabulary := preload("res://game/feedback_vocabulary.gd")
const Locale := preload("res://src/locale/locale.gd")

const MODULE_PATH := "res://game/feedback_vocabulary.gd"
const HUD_PATH := "res://game/hud.gd"
const CONTROLLER_PATH := "res://game/match_controller.gd"

## Declarations the legacy HUD must not carry any more: the whole vocabulary it
## used to own. Each one existed in `godot/game/hud.gd` before this seam.
const MOVED_DECLARATIONS := [
	"const GRADE_COLORS", "const FIELD_GRADE_COLORS", "const FIELD_ENERGY_TEAL",
	"const PRECISION_CYAN", "const ADVICE_AGGRESSIVE", "const ADVICE_CONTROL",
	"const UNREADABLE", "static func grade_of", "static func mode_of",
	"static func feedback_key", "static func mode_key", "static func feedback_label",
	"static func mode_label", "static func advice_word", "static func advice_color",
	"static func advice_of", "static func grade_color", "static func field_grade_color",
	"static func precision_color", "static func field_energy_color",
	"static func resolve_or",
	"const EVENT_LABELS", "static func describe_event", "static func reason_label",
]
## What stays in the legacy HUD: it paints the log and the panels.
const KEPT_DECLARATIONS := [
	"func _update_log", "static func panel_rect",
]

## `js/drill.js:468` — "Le quattro classi sono quelle del motore": perfect, good,
## early, late.
const GRADE_IDS := ["perfect", "good", "early", "late"]
## `js/game.js:889-901` — the six advice ids `t("shotAdvice_" + advice)` looks up.
const ADVICE_IDS := ["read", "lob", "chiquita", "smash", "vibora", "drive"]
## Every `text` the ported simulation can store (`sim.gd:1245`, `:1794`, `:2590`):
## the `shot:<grade>` form, the four bare smash labels and the missed-contact id.
const TEXT_IDS := [
	"shot:perfect", "shot:good", "shot:early", "shot:late",
	"shotSmashX2", "shotSmashX3", "shotSmashFlat", "shotBandejaFallback",
	"smashMissedContact",
]
## Every `mode` the ported simulation can store (`sim.gd:1246`, `:1795`, `:2590`):
## `shotMode:<mode>`, the two bare smash hints, and — after a successful smash —
## the grade already uppercased (`String(assessment["grade"]).to_upper()`).
const MODE_IDS := [
	"shotMode:control", "shotMode:balanced", "shotMode:power",
	"smashNotReady", "smashMissedHint", "PERFECT",
]

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	await _run()
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	print("feedback vocabulary seam test — one owner, one vocabulary")
	print("  module     %s" % MODULE_PATH)
	print("  legacy HUD %s" % HUD_PATH)
	print("  caller     %s" % CONTROLLER_PATH)
	print("")
	# The words below are the Italian table's: the same language the reference
	# ships and the slice test pins (`Locale.set_lang("it")`).
	Locale.set_lang("it")
	_ownership()
	_encodings()
	_words()
	_colours()
	_events()
	_report_tally()


# ---------------------------------------------------------------------------
# 1. The one owner
# ---------------------------------------------------------------------------

func _ownership() -> void:
	var hud := _text(HUD_PATH)
	var controller := _text(CONTROLLER_PATH)
	var module := _text(MODULE_PATH)

	_check("the one vocabulary module exists at %s" % MODULE_PATH, module != "", MODULE_PATH)
	_check("the module owns the knowledge: it preloads no caller (no pass-through)",
		not module.contains("preload(\"res://game/hud.gd\")")
		and not module.contains("preload(\"res://game/match_controller.gd\")"),
		"preload(res://game/hud.gd)")

	var still_declared: Array[String] = []
	for declaration in MOVED_DECLARATIONS:
		if hud.contains(String(declaration)):
			still_declared.append(String(declaration))
	_check("the legacy HUD no longer declares the moved vocabulary",
		still_declared.is_empty(), str(still_declared))

	var missing: Array[String] = []
	for declaration in KEPT_DECLARATIONS:
		if not hud.contains(String(declaration)):
			missing.append(String(declaration))
	_check("the legacy HUD keeps its own painting: the log's lines and the panel maths",
		missing.is_empty(), str(missing))

	# The shipping caller: vocabulary from the module, the legacy HUD script only
	# for the mount — and since gate 4 that mount is built only when a run asks for
	# it (`ui_legacy` / `--ui=legacy`), so the shipping consumer is the court timing
	# module (gate 3 moved the controller's last vocabulary call into it).
	var court_timing := _text("res://game/court_timing_marks.gd")
	_check("the court timing module preloads the vocabulary module",
		court_timing.contains("preload(\"%s\")" % MODULE_PATH), MODULE_PATH)
	var hud_script_uses := controller.count("HudScript.") - controller.count("ModeHudScript.")
	_check("the controller's only use of the legacy HUD script is the legacy mount",
		hud_script_uses == 1 and controller.contains("HudScript.new()"),
		"HudScript. x%d" % hud_script_uses)
	_check("no controller vocabulary call goes through the legacy HUD script",
		not controller.contains("HudScript.feedback_label")
		and not controller.contains("HudScript.mode_label")
		and not controller.contains("HudScript.advice_word")
		and not controller.contains("HudScript.advice_of")
		and not controller.contains("HudScript.advice_color")
		and not controller.contains("HudScript.field_grade_color")
		and not controller.contains("HudScript.field_energy_color")
		and not controller.contains("HudScript.precision_color")
		and not controller.contains("HudScript.PRECISION_CYAN")
		and not controller.contains("HudScript.FIELD_ENERGY_TEAL"),
		"HudScript.<vocabulary>")


# ---------------------------------------------------------------------------
# 2. The id encodings the simulation stores
# ---------------------------------------------------------------------------

func _encodings() -> void:
	_check_eq("`shot:<grade>` derives the reference key `shot<Grade>`",
		Vocabulary.feedback_key("shot:perfect"), "shotPerfect")
	_check_eq("a bare feedback id is already a key",
		Vocabulary.feedback_key("shotSmashX2"), "shotSmashX2")
	_check_eq("`shotMode:<mode>` derives the reference key `shotMode<Mode>`",
		Vocabulary.mode_key("shotMode:balanced"), "shotModeBalanced")
	_check_eq("a bare mode id is already a key",
		Vocabulary.mode_key("smashNotReady"), "smashNotReady")
	_check_eq("`shot:<grade>` resolves to its grade",
		Vocabulary.grade_of("shot:perfect"), "perfect")
	_check_eq("a bare id keeps its own last segment (the colour key)",
		Vocabulary.grade_of("smashMissedContact"), "smashMissedContact")
	_check_eq("`shotMode:<mode>` resolves to the uppercased mode",
		Vocabulary.mode_of("shotMode:balanced"), "BALANCED")
	_check_eq("the port's own marker equals the shipped one",
		Vocabulary.UNREADABLE, "??")


# ---------------------------------------------------------------------------
# 3. The words
# ---------------------------------------------------------------------------

func _words() -> void:
	_check_eq("shot grade resolves to the reference's own word",
		Vocabulary.feedback_label("shot:perfect"), "PERFETTO")
	_check_eq("a good grade resolves to the reference's own word",
		Vocabulary.feedback_label("shot:good"), "BUONO")
	# `js/i18n.js` carries `shotEarly`/`shotLate` twice inside the `it` object
	# (`:175` "IN ANTICIPO" and `:557` "ANTICIPATO"); the later key wins in JS,
	# which is the value the port's locale table carries and the one asserted.
	_check_eq("an early grade resolves to the reference's own word",
		Vocabulary.feedback_label("shot:early"), "ANTICIPATO")
	_check_eq("a late grade resolves to the reference's own word",
		Vocabulary.feedback_label("shot:late"), "RITARDATO")
	_check_eq("shot mode resolves to the reference's own word",
		Vocabulary.mode_label("shotMode:balanced"), "BILANCIATO")
	_check_eq("a control mode resolves to the reference's own word",
		Vocabulary.mode_label("shotMode:control"), "CONTROLLO")
	_check_eq("a power mode resolves to the reference's own word",
		Vocabulary.mode_label("shotMode:power"), "POTENZA")
	_check_eq("a bare feedback id is resolved as itself",
		Vocabulary.feedback_label("smashMissedContact"), "IMPATTO MANCATO")
	# The smash branch overwrites text/mode (`sim.gd:1794-1795`).
	_check_eq("the x2 smash label is the reference's own word",
		Vocabulary.feedback_label("shotSmashX2"), "SMASH X2")
	_check_eq("the flat smash label is the reference's own word",
		Vocabulary.feedback_label("shotSmashFlat"), "SMASH")
	_check_eq("the bandeja fallback is the reference's own word",
		Vocabulary.feedback_label("shotBandejaFallback"), "BANDEJA")
	_check_eq("the not-ready smash hint is the reference's own word",
		Vocabulary.mode_label("smashNotReady"), "SMASH NON PRONTO")
	# RECORDED, NOT ENDORSED — a pre-existing divergence this slice preserves (it
	# moves behaviour, it does not change it): for a successful smash the sim stores
	# the grade ALREADY UPPERCASED (`sim.gd:1795`, mirroring `js/game.js:1832`) and
	# the reference draws that stored string verbatim (`js/render.js:1068-1069`),
	# while the port's resolver refuses to echo a stored value back as its own label
	# — so this one mode renders the port's marker instead of `PERFECT`. Recorded as
	# a gap in `docs/mission/architecture-deepening/tickets/feedback-vocabulary.md`.
	_check_eq("the smash branch's stored uppercase grade renders the port's marker today",
		Vocabulary.mode_label("PERFECT"), Vocabulary.UNREADABLE)

	# Never an id, never the marker: for every other id the simulation can store.
	var leaking: Array[String] = []
	for id in TEXT_IDS:
		var line := Vocabulary.feedback_label(String(id))
		if line == "" or line == Vocabulary.UNREADABLE or line == String(id) \
				or line.contains(String(id)):
			leaking.append("%s -> %s" % [String(id), line])
	for id in MODE_IDS:
		if String(id) == "PERFECT":
			continue
		var line := Vocabulary.mode_label(String(id))
		if line == "" or line == Vocabulary.UNREADABLE or line == String(id) \
				or line.contains(String(id)):
			leaking.append("%s -> %s" % [String(id), line])
	_check("no feedback id and no marker reaches the screen", leaking.is_empty(), str(leaking))

	# A projection of the locale layer, not a second string table.
	var drifting: Array[String] = []
	for id in TEXT_IDS:
		var key := Vocabulary.feedback_key(String(id))
		if Locale.is_resolvable(key) and Locale.required_params(key).is_empty():
			if Vocabulary.feedback_label(String(id)) != Locale.t(key):
				drifting.append("%s -> %s != %s" % [key, Vocabulary.feedback_label(String(id)), Locale.t(key)])
	for id in MODE_IDS:
		var key := Vocabulary.mode_key(String(id))
		if Locale.is_resolvable(key) and Locale.required_params(key).is_empty():
			if Vocabulary.mode_label(String(id)) != Locale.t(key):
				drifting.append("%s -> %s != %s" % [key, Vocabulary.mode_label(String(id)), Locale.t(key)])
	_check("every resolved word is what the locale layer produces (projection, not a copy)",
		drifting.is_empty(), str(drifting))

	_check_eq("an unknown grade still renders a readable word, never the stored id",
		Vocabulary.feedback_label("shot:bogus"), "BOGUS")

	# The advice word (`js/render.js:1730`), and its reference default.
	_check_eq("the reference's own default advice is `read`",
		Vocabulary.advice_of({}), "read")
	_check_eq("an advice in the read model is kept as it is",
		Vocabulary.advice_of({"advice": "lob"}), "lob")
	_check_eq("the advice word is the locale's own, uppercased",
		Vocabulary.advice_word("lob"), "LOB DI RECUPERO")
	var advice_off: Array[String] = []
	for advice in ADVICE_IDS:
		var word := Vocabulary.advice_word(String(advice))
		if word != Locale.t("shotAdvice_%s" % String(advice)).to_upper() \
				or word.begins_with("shotAdvice"):
			advice_off.append("%s -> %s" % [String(advice), word])
	_check("all six advice ids are the reference's, resolved and uppercased",
		advice_off.is_empty(), str(advice_off))


# ---------------------------------------------------------------------------
# 4. The colours
# ---------------------------------------------------------------------------

func _colours() -> void:
	# `js/render.js:1044-1052` — the verdict over the athlete who hit.
	_check_eq("the perfect verdict is the reference's #74ffba",
		Vocabulary.field_grade_color("perfect").to_html(false), "74ffba")
	_check_eq("the good verdict is the reference's #77e7ff",
		Vocabulary.field_grade_color("good").to_html(false), "77e7ff")
	_check_eq("the early verdict is the reference's #ffd45c",
		Vocabulary.field_grade_color("early").to_html(false), "ffd45c")
	_check_eq("the late verdict is the reference's #ff8b70",
		Vocabulary.field_grade_color("late").to_html(false), "ff8b70")
	_check_eq("an unknown grade is the reference's own white",
		Vocabulary.field_grade_color("bogus").to_html(false), "ffffff")

	# The panel line's palette as the port ships it (`hud.gd`'s pre-move
	# `GRADE_COLORS`): a parity value, plus the missed-contact red.
	_check_eq("the panel's perfect line keeps its shipped colour",
		Vocabulary.grade_color("perfect").to_html(false), "6bfa8c")
	_check_eq("the panel's good line keeps its shipped colour",
		Vocabulary.grade_color("good").to_html(false), "9ee0ff")
	_check_eq("the panel's early line keeps its shipped colour",
		Vocabulary.grade_color("early").to_html(false), "ffd166")
	_check_eq("the panel's late line keeps its shipped colour",
		Vocabulary.grade_color("late").to_html(false), "ff4b6e")
	_check_eq("the missed contact keeps the late red on the panel",
		Vocabulary.grade_color("smashMissedContact").to_html(false), "ff4b6e")
	_check_eq("an unknown grade keeps the panel's shipped fallback",
		Vocabulary.grade_color("bogus").to_html(false), "edf2fa")

	# `js/render.js:1036` — `> 0.55` teal, `> 0.3` amber, else red (strict).
	_check_eq("full energy is the reference's #56e8d8",
		Vocabulary.field_energy_color(1.0).to_html(false), "56e8d8")
	_check_eq("mid energy is the reference's #ffd45c",
		Vocabulary.field_energy_color(0.4).to_html(false), "ffd45c")
	_check_eq("low energy is the reference's #ff6b64",
		Vocabulary.field_energy_color(0.2).to_html(false), "ff6b64")
	_check_eq("the band at 0.55 is amber, not teal (the reference's strict >)",
		Vocabulary.field_energy_color(0.55).to_html(false), "ffd45c")
	_check_eq("the band at 0.3 is red (the reference's strict >)",
		Vocabulary.field_energy_color(0.3).to_html(false), "ff6b64")

	# `js/render.js:1709-1717` — cyan while the angle is not armed. The alpha is part
	# of the value, so these three compare the full RGBA.
	_check_eq("the unarmed precision fill is `rgba(126,243,255,0.75)`",
		Vocabulary.precision_color(0.0, 1.0).to_html(true), "7ef3ffbf")
	_check_eq("the armed threshold is strict: tight at 0.02 is still cyan",
		Vocabulary.precision_color(0.02, 1.0).to_html(true), Vocabulary.PRECISION_CYAN.to_html(true))
	_check_eq("an armed angle is `rgb(255, 70, 70)` at full pulse",
		Vocabulary.precision_color(1.0, 1.0).to_html(true), "ff4646ff")
	_check_eq("the armed fill's alpha is the caller's pulse",
		Vocabulary.precision_color(1.0, 0.0).to_html(true), "ff464600")

	# `js/render.js:1745` — aggressive first, everything else on the second.
	_check_eq("an aggressive profile is the reference's #ffd46a",
		Vocabulary.advice_color("aggressive").to_html(false), "ffd46a")
	_check_eq("a control profile is the reference's #8fffd0",
		Vocabulary.advice_color("control").to_html(false), "8fffd0")
	_check_eq("every other profile is the reference's #8fffd0",
		Vocabulary.advice_color("attack").to_html(false), "8fffd0")


# ---------------------------------------------------------------------------
# 5. The event log's knowledge
# ---------------------------------------------------------------------------

## The two properties the slice test pinned while the table lived in the HUD —
## never an id on screen, and every entry a projection of the locale layer — plus
## the wiring: the legacy HUD's log asks the module for its line.
func _events() -> void:
	var hud := _text(HUD_PATH)
	# THE PRODUCTION WIRING. Delete the `Vocabulary.describe_event(` call from
	# `hud.gd::_update_log` and the log paints a line no one owns — this check goes
	# red, because the module is the only place the resolver may live.
	_check("the legacy HUD asks the module for every log line",
		hud.contains("Vocabulary.describe_event("), "Vocabulary.describe_event(")
	_check("the legacy HUD keeps no copy of the event table",
		not hud.contains("EVENT_LABELS"), "EVENT_LABELS")

	# The resolver rule, in order: the verified locale layer first ...
	_check_eq("a composite the locale layer resolves is the layer's own sentence",
		Vocabulary.describe_event("pointYou:msgOut"), "PUNTO TUO · Palla fuori dal campo.")
	_check_eq("a control message the locale layer resolves is the layer's own sentence",
		Vocabulary.describe_event("controlMsg:roleBackPos"), "Controlli il giocatore di fondo.")
	# ... the generated floor second, for an id the layer cannot resolve at all ...
	_check_eq("an id the locale layer cannot resolve falls to the generated floor",
		Vocabulary.describe_event("LET"),
		"Let: nastro e rimbalzo nel riquadro corretto. Servizio da ripetere.")
	# ... and never an id: an unknown id renders the marker.
	_check_eq("an unknown id renders the marker, never the id",
		Vocabulary.describe_event("totallyUnknownId"), Vocabulary.UNREADABLE)
	_check_eq("the ledger's own word resolves exactly like describe_event",
		Vocabulary.reason_label("msgOut"), Vocabulary.describe_event("msgOut"))

	# The moved table, entry for entry.
	var labels: Dictionary = Vocabulary.EVENT_LABELS
	_check("the moved table is intact: the pre-move count of entries",
		labels.size() == 94, "entries=%d" % labels.size())
	var leaking: Array[String] = []
	var drifting: Array[String] = []
	for id in labels:
		var key := String(id)
		var line := Vocabulary.describe_event(key)
		if line == "" or line == Vocabulary.UNREADABLE or line == key or line.contains(key):
			leaking.append("%s -> %s" % [key, line])
		if Locale.is_resolvable(key) and Locale.required_params(key).is_empty() and line != Locale.t(key):
			drifting.append("%s -> %s != %s" % [key, line, Locale.t(key)])
	_check("no entry of the event table ever renders its own id (or the marker)",
		leaking.is_empty(), str(leaking))
	_check("every resolved entry equals what the locale layer produces (projection, not a copy)",
		drifting.is_empty(), str(drifting))

	# The debt ledger (`tools/i18n-port/unresolved-baseline.json`) — readable, not
	# faked: never the id itself and never the marker.
	var ledger := [
		"LET", "serveHint", "serveOutBox secondServe", "serveWallFault secondServe",
		"doubleFault:serveoutbox", "doubleFault:servewallfault",
		"pointYou:doubleFault:serveoutbox", "pointYou:doubleFault:servewallfault",
		"pointOpp:doubleFault:serveoutbox", "pointOpp:doubleFault:servewallfault",
	]
	var unreadable: Array[String] = []
	for id in ledger:
		var line := Vocabulary.describe_event(String(id))
		if line == String(id) or line == Vocabulary.UNREADABLE:
			unreadable.append(String(id))
	_check("the ten debt-ledger ids get a readable fallback (never the id, never `??`)",
		unreadable.is_empty(), str(unreadable))
	_check_eq("the ledger is not shrunk: the offer-back fallback is still recorded as unresolvable",
		Locale.is_resolvable("LET"), false)


# ---------------------------------------------------------------------------

## The text of a resource, or `""` when it is not on disk.
func _text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("ok %s" % name)
	else:
		_failures += 1
		print("FAIL %s: %s" % [name, detail])


func _check_eq(name: String, got: Variant, expected: Variant) -> void:
	_check(name, got == expected, "expected %s, got %s" % [str(expected), str(got)])


func _report_tally() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
