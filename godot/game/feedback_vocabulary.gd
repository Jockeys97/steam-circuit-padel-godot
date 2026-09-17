## feedback_vocabulary.gd — THE one owner of the match's feedback vocabulary.
##
## WHY THIS FILE EXISTS
##   The ported HUD (`godot/game/hud.gd`) grew the entire language the shot
##   feedback speaks: the id encodings the ported simulation stores, the words the
##   reference resolves them to, and every colour they are drawn with. Two other
##   files then read that language THROUGH the HUD: the shipping match shell
##   (`godot/game/match_controller.gd`) called `HudScript.feedback_label`, …,
##   `HudScript.precision_color` for its own court marks, and the slice test pinned
##   the same statics. The hidden legacy HUD (invisible behind the recreated UI)
##   therefore had to exist for the vocabulary alone. This module is that one
##   owner — including the EVENT LOG's knowledge, the table and the resolver the
##   HUD used to keep beside the vocabulary it painted; `hud.gd` keeps what is its
##   own (the panels and the log's painting) and consumes this module for
##   everything below.
##
## WHAT IT OWNS
##   - the id encodings the port stores in `state.shotFeedback`:
##       `shot:<grade>`            -> `feedback_key()`  = `shot<Grade>`
##                                   -> `grade_of()`     = `<grade>`
##       `shotMode:<mode>`         -> `mode_key()`      = `shotMode<Mode>`
##                                   -> `mode_of()`      = `<MODE>`
##       a bare id (`shotSmashX2`, `smashMissedContact`, `smashNotReady`,
##       `smashMissedHint`) is already a key and keeps its own last segment.
##     (`js/game.js:1062-1069`, `sim.gd:1244-1246`, `:1787-1795`, `:2590`)
##   - the EVENT LOG's knowledge: `EVENT_LABELS` — the message-id -> readable-line
##     floor, GENERATED into this file by `godot/game/tools/gen_hud_labels.py` and
##     read statically from this file by `tools/i18n-port/hud-coverage.mjs` — and
##     the resolver that reads it: `describe_event`/`reason_label` ask the verified
##     locale layer first, the floor second, and render `UNREADABLE` — never an id.
##   - the WORDS: `feedback_label()` / `mode_label()` resolve the derived key
##     through the verified locale layer, exactly as the reference renders it
##     (`js/game.js:1062-1069`); `advice_word()` is the tactical word the reference
##     draws over the active athlete, `t("shotAdvice_" + advice).toUpperCase()`
##     (`js/render.js:1730`), with the reference's own `?? "read"` default
##     (`advice_of()`);
##   - the COLOURS: the verdict's four over the athlete who hit and its white
##     fallback (`js/render.js:1041-1069`), the panel palette the port ships for the
##     HUD's corner line (a parity value — see `GRADE_COLORS`), the energy bar's
##     three bands (`js/render.js:1031-1037`), the precision fill and its strict
##     `tight > 0.02` arming (`js/render.js:1697-1717`), and the advice tone
##     (`js/render.js:1745`);
##   - the resolver rule: the locale layer first, a readable floor second, and
##     `UNREADABLE` — never an id on screen.
##
## WHAT IS DELIBERATELY NOT HERE
##   - no painting: the HUD's panels (`hud.gd`) and the court marks
##     (`match_controller.gd`) keep every node, layout and material they had; they
##     ask this module for the word, the colour and the log line only;
##   - no simulation state and no rules: the sim stores the ids, this module only
##     says what they mean.
##
## Behaviour is a move, not a change: every value and every branch below is the one
## `godot/game/hud.gd` shipped — including the event-log table and its resolver,
## moved here byte-for-byte — and `godot/tests/feedback_vocabulary_test.gd` pins the
## words, the encodings, the colours and the log lines against the reference's own
## values.
extends RefCounted

const Locale := preload("res://src/locale/locale.gd")

## Rendered when an id is neither resolvable nor given a readable fallback.
## Deliberately not the id: a visible "??" is a defect report, an id on screen is a
## silent one. The one user-facing string the port adds (the reference has no
## marker), shared by the HUD's log lines and the recreated UI's view-model.
const UNREADABLE := "??"

## Shot grades the simulation stores as `shot:<grade>` (sim.gd:1245), plus the bare
## id it stores instead of a grade (`smashMissedContact`, sim.gd:2590). The colour
## of the HUD's corner line is keyed by the grade, not by the resolved sentence.
## A parity palette: these are the values the port ships (`js/render.js:1044-1052`
## keeps the brighter set below, drawn over the athlete who hit).
const GRADE_COLORS := {
	"perfect": Color(0.42, 0.98, 0.55),
	"good": Color(0.62, 0.88, 1.0),
	"early": Color(1.0, 0.821, 0.4),
	"late": Color(1.0, 0.294, 0.431),
	"smashMissedContact": Color(1.0, 0.294, 0.431),
}
## The panel line's own default, for a grade the table does not know.
const GRADE_COLOR_FALLBACK := Color(0.93, 0.95, 0.98)

## The four colours of the verdict drawn ON THE COURT (`js/render.js:1048-1053`).
## The reference keeps two palettes: these bright ones for the word over the athlete
## who hit, and the panel's (`GRADE_COLORS` above) for the corner line. An unknown
## grade is white, which is the reference's own `?? "#ffffff"`.
const FIELD_GRADE_COLORS := {
	"perfect": Color(0.455, 1.0, 0.729),   # #74ffba
	"good": Color(0.467, 0.906, 1.0),      # #77e7ff
	"early": Color(1.0, 0.831, 0.361),     # #ffd45c
	"late": Color(1.0, 0.545, 0.439),      # #ff8b70
}
const FIELD_GRADE_FALLBACK := Color(1.0, 1.0, 1.0)

## The three bands and the three colours of the energy bar the REFERENCE draws: it
## has no energy bar in its HUD at all. `js/main.js:1916` hands
## `state.rallyEnergy.player` to `drawActiveIndicator`, which draws the bar on the
## court, under the active athlete (`js/render.js:1031-1037`), and the ported match
## controller draws that one from these values.
const FIELD_ENERGY_TEAL := Color(0.337, 0.910, 0.847)   # #56e8d8, energy > 0.55
const FIELD_ENERGY_AMBER := Color(1.0, 0.831, 0.361)    # #ffd45c, energy > 0.3
const FIELD_ENERGY_RED := Color(1.0, 0.420, 0.392)      # #ff6b64, below

## The precision bar's fill (`js/render.js:1709-1717`): cyan while the angle is not
## armed, amber — reddening with `tight` — and pulsing once it is. `armed` is
## `tight > 0.02`, the reference's own threshold; `pulse` is the caller's clock
## (the reference blinks it at `time * 16`, `js/render.js:1711`).
const PRECISION_CYAN := Color(0.494, 0.953, 1.0, 0.75)  # rgba(126,243,255,0.75)

## The tactical advice word's colour, by shot profile: `#ffd46a` aggressive,
## `#8fffd0` otherwise (`js/render.js:1745`) — the reference's exact two-value rule,
## aggressive checked first, everything else (including "control") on the second.
const ADVICE_AGGRESSIVE := Color(1.0, 0.831, 0.416)  # #ffd46a
const ADVICE_CONTROL := Color(0.561, 1.0, 0.816)     # #8fffd0

## The event log's message-id -> readable-line floor, GENERATED into this file by
## `godot/game/tools/gen_hud_labels.py` — a projection of the verified locale layer
## plus one readable fallback per debt-ledger id. Never hand-edited: `--check`
## verifies this block byte-for-byte.

# >>> EVENT_LABELS (generated by godot/game/tools/gen_hud_labels.py) >>>
const EVENT_LABELS := {
	"evReceiverLock": "Ricevitore bloccato sul diagonale fino alla risposta.",
	"serveHint": "Servizio dal basso: cerca il diagonale.",
	"evOppServe": "Servizio avversario: attendi il rimbalzo o gioca la volée.",
	"evCounter": "Avversari presi in contropiede: campo aperto!",
	"evAiForced": "L'IA forza il colpo: profondità fuori controllo!",
	"evOppOutOfPos": "Avversario fuori posizione: palla da attaccare!",
	"evOppLob": "Lob avversario: recupera il fondo!",
	"evCoverCenter": "Volée avversaria: copri il centro!",
	"evOppVibora": "Víbora avversaria: preparati al taglio sul vetro!",
	"evOppSmashX2": "SMASH x2 avversario: difendi dopo il vetro!",
	"evOppSmashX3": "SMASH x3 avversario: chiudi l'uscita laterale!",
	"evChiquita": "Chiquita bassa sui piedi degli avversari!",
	"evLobOver": "Lob sovraccarico: grande profondità, ma il vetro è vicino!",
	"evLobShort": "Lob corto: la coppia avversaria può attaccarlo.",
	"evDefensiveLob": "Lob difensivo: tempo per recuperare la posizione.",
	"evLobHigh": "Lob: traiettoria alta verso il vetro di fondo.",
	"evSmashX3": "SMASH x3: cerca fondo e uscita laterale!",
	"evSmashX3Downgrade": "X3 non perfetto: trasformato in uno smash X2.",
	"evSmashX2Deep": "SMASH x2: palla profonda per farla tornare!",
	"evSmashCenter": "Smash piatto: potenza al centro del campo!",
	"evSmashFlatFallback": "Smash non pulito: colpo piatto ancora aggressivo.",
	"evBandejaConverted": "Palla non ideale: smash convertito in bandeja.",
	"evBandeja": "Bandeja: controllo e posizione a rete.",
	"evAngleWall": "Angolo cercato: il vetro laterale entra in gioco!",
	"evGlobo": "Globo altissimo: la coppia avversaria deve indietreggiare!",
	"evGloboShort": "Globo corto: palla alta e attaccabile.",
	"evCutVolley": "Volée tagliata: taglio pesante verso il fondo.",
	"evVibora": "Víbora: taglio laterale aggressivo!",
	"evSlice": "Slice: traiettoria bassa e rimbalzo tagliato.",
	"evSmashIntercepted": "Smash letto in anticipo: l'avversario lo taglia al volo!",
	"evPrecision": "Colpo di Precisione: angolo chirurgico!",
	"evLightningDash": "Scatto Fulmineo: volée letale!",
	"evSteamSmash": "Smash a Vapore: palla alta e profonda!",
	"evSteamShield": "Scudo di Vapore: difesa e controattacco!",
	"evPerfectVision": "Visione Perfetta: angolo impossibile, lettura in ritardo!",
	"evSteamHammer": "Martello a Vapore: l'officina trema sotto l'impatto!",
	"evSteamShieldAbsorb": "Scudo di Vapore: pressione assorbita!",
	"setToYou": "Set a te!",
	"setToCircuit": "Set a Circuito!",
	"tieBreak": "Tie-break a 7: due punti di scarto.",
	"pointYou": "PUNTO TUO",
	"pointOpp": "PUNTO AVVERSARIO",
	"LET": "Let: nastro e rimbalzo nel riquadro corretto. Servizio da ripetere.",
	"evLet": "Let: nastro e rimbalzo nel riquadro corretto. Servizio da ripetere.",
	"evServeValid": "Servizio valido: rimbalzo nel riquadro opposto.",
	"evSmashValid": "Smash valido: primo rimbalzo, ora lavora il vetro!",
	"evOwnWallOut": "Uscita dal proprio vetro: palla ancora in gioco.",
	"evX3Recovered": "Uscita X3 letta: difesa sul vetro!",
	"evSideWallCenter": "Vetro laterale: traiettoria riaperta al centro!",
	"evCutVolleyKill": "La palla muore sul vetro: nessun rimbalzo utile!",
	"evCutVolleyRead": "Effetto letto: la palla si rialza dal vetro.",
	"evSmashX3Grid": "SMASH x3: il rimbalzo sale verso la griglia laterale!",
	"evSmashX2Read": "Uscita letta: la palla e' stata rincorsa sul vetro!",
	"evSmashX2": "SMASH x2: la palla torna verso la tua metà!",
	"evWallValid": "Vetro valido dopo il rimbalzo!",
	"evTape": "Nastro: la palla rallenta e ricade oltre la rete.",
	"evNetRebound": "Rete piena: la palla viene respinta e perde velocità.",
	"evSmashTapConfirmed": "Secondo tap riconosciuto: smash attivato!",
	"evSmashPrimed": "Smash preparato: premi di nuovo A al momento dell'impatto.",
	"evSmashTapExpired": "Secondo tap mancato: resta un colpo normale.",
	"evCutVolleyPrimed": "Volée tagliata pronta: premi di nuovo X all'impatto.",
	"evGloboPrimed": "Globo pronto: premi di nuovo Y all'impatto.",
	"evGloboConfirmed": "Globo confermato!",
	"evCutVolleyConfirmed": "Volée tagliata confermata!",
	"controlMsg:roleBackPos": "Controlli il giocatore di fondo.",
	"controlMsg:roleNetPos": "Controlli il giocatore a rete.",
	"evShotLong": "Contatto in ritardo: il colpo si allunga oltre il fondo.",
	"evShotWide": "Angolo strappato: la palla se ne va sul vetro laterale.",
	"evShotNet": "Colpo affossato: contatto sporco, la palla non passa.",
	"eventLine0": "Rimbalzo sul vetro: angolo perfetto!",
	"eventLine1": "Combo attiva: pressione sul fondo!",
	"eventLine2": "Lettura steampunk: palla letta al millimetro.",
	"eventLine3": "Volée fulminea sul circuito!",
	"eventLine4": "Smash a vapore: difesa sfondata!",
	"eventLine5": "Wall shot: il vetro lavora per te.",
	"msgNetFault": "Rete: la palla è ricaduta nel campo di chi ha colpito.",
	"msgOut": "Palla fuori dal campo.",
	"msgNetShort": "Palla corta: non ha superato la rete.",
	"msgDoubleBounce": "Secondo rimbalzo: punto perso.",
	"msgWallNoBounce": "Parete avversaria colpita senza rimbalzo.",
	"msgSmashX3Wall": "SMASH x3: palla fuori dalla parete laterale!",
	"msgSmashReturned": "SMASH x2: la palla è tornata oltre la rete!",
	"doubleFault:serveoutbox": "Doppio fallo: servizio fuori dal riquadro.",
	"doubleFault:servewallfault": "Doppio fallo: la palla ha colpito il vetro prima del rimbalzo",
	"serveOutBox secondServe": "Servizio fuori dal riquadro. Seconda di servizio.",
	"serveWallFault secondServe": "La palla ha colpito il vetro prima del rimbalzo Seconda di servizio.",
	"tactic_attack": "Tattica di coppia: conquista la rete.",
	"tactic_defend": "Tattica di coppia: difesa sul vetro.",
	"tactic_staggered": "Tattica di coppia: disposizione sfalsata.",
	"tactic_balanced": "Tattica di coppia: equilibrio.",
	"pointYou:doubleFault:serveoutbox": "PUNTO TUO · Doppio fallo: servizio fuori dal riquadro.",
	"pointYou:doubleFault:servewallfault": "PUNTO TUO · Doppio fallo: la palla ha colpito il vetro prima del rimbalzo",
	"pointOpp:doubleFault:serveoutbox": "PUNTO AVVERSARIO · Doppio fallo: servizio fuori dal riquadro.",
	"pointOpp:doubleFault:servewallfault": "PUNTO AVVERSARIO · Doppio fallo: la palla ha colpito il vetro prima del rimbalzo",
}
# <<< EVENT_LABELS (generated by godot/game/tools/gen_hud_labels.py) <<<


# ---------------------------------------------------------------------------
# The id encodings the simulation stores
# ---------------------------------------------------------------------------

## `shot:perfect` -> `perfect`, anything else keeps its last segment. Used for the
## colour and for nothing else.
static func grade_of(text_id: String) -> String:
	var parts := text_id.split(":")
	return String(parts[parts.size() - 1]) if parts.size() > 1 else text_id


static func mode_of(mode_id: String) -> String:
	var parts := mode_id.split(":")
	var value := String(parts[parts.size() - 1]) if parts.size() > 1 else mode_id
	return value.to_upper()


## `js/game.js:1062-1069`: the reference renders the grade as `t("shot" + Grade)`,
## with `Grade` the capitalized assessment grade, and stores the *rendered* string.
## The port stores `shot:<grade>`, so the same key is derived here — the reference's
## derivation, not a new one. A bare id (`smashMissedContact`, `shotSmashX2`) is
## already a key and is resolved as it is.
static func feedback_key(text_id: String) -> String:
	if text_id.begins_with("shot:"):
		return "shot" + text_id.substr(5).capitalize()
	return text_id


static func feedback_label(text_id: String) -> String:
	return _resolve_or(feedback_key(text_id), grade_of(text_id).to_upper())


## `js/game.js:1069` — `t("shotMode" + CapitalizedMode)`. The port's smash branch
## stores the grade already uppercased instead (`sim.gd:1795`), and a bare id
## (`smashNotReady`, `smashMissedHint`) is a key of its own.
static func mode_key(mode_id: String) -> String:
	if mode_id.begins_with("shotMode:"):
		return "shotMode" + mode_id.substr(9).capitalize()
	return mode_id


static func mode_label(mode_id: String) -> String:
	return _resolve_or(mode_key(mode_id), mode_of(mode_id))


## The tactical advice word the reference draws over the active athlete,
## `t("shotAdvice_" + state.shotRead.advice).toUpperCase()` (`js/render.js:1730`).
## Resolved here, where the locale layer is, and never as the id: an id on screen is
## the defect class this module exists to prevent. The upper case is the reference's
## own (`js/render.js:1730`).
static func advice_word(advice: String) -> String:
	return _resolve_or("shotAdvice_%s" % advice, advice.to_upper()).to_upper()


## The word drawn when the simulation carries no advice at all: the reference's
## `state.shotRead?.advice ?? "read"` (`js/render.js:1730`).
static func advice_of(read: Dictionary) -> String:
	return String(read.get("advice", "read"))


# ---------------------------------------------------------------------------
# The colours
# ---------------------------------------------------------------------------

## The HUD's corner line, by grade, with the port's own fallback.
static func grade_color(grade: String) -> Color:
	return GRADE_COLORS.get(grade, GRADE_COLOR_FALLBACK)


static func field_grade_color(grade: String) -> Color:
	return FIELD_GRADE_COLORS.get(grade, FIELD_GRADE_FALLBACK)


## `energy > 0.55 ? "#56e8d8" : energy > 0.3 ? "#ffd45c" : "#ff6b64"`
## (`js/render.js:1036`) — both comparisons strict.
static func field_energy_color(energy: float) -> Color:
	if energy > 0.55:
		return FIELD_ENERGY_TEAL
	if energy > 0.3:
		return FIELD_ENERGY_AMBER
	return FIELD_ENERGY_RED


static func precision_color(tight: float, pulse: float) -> Color:
	if tight > 0.02:
		var level := clampf(tight, 0.0, 1.0)
		return Color(1.0, (190.0 - level * 120.0) / 255.0, 70.0 / 255.0, clampf(pulse, 0.0, 1.0))
	return PRECISION_CYAN


static func advice_color(profile: String) -> Color:
	return ADVICE_AGGRESSIVE if profile == "aggressive" else ADVICE_CONTROL


# ---------------------------------------------------------------------------
# The resolver rule
# ---------------------------------------------------------------------------

## The resolver first; the readable fallback only when the resolver would hand back
## the id itself. Never the id.
static func _resolve_or(message_id: String, fallback: String) -> String:
	if Locale.is_resolvable(message_id):
		return Locale.t(message_id)
	if fallback != "" and fallback != message_id:
		return fallback
	return UNREADABLE


# ---------------------------------------------------------------------------
# The event log's resolver
# ---------------------------------------------------------------------------

## A message id -> the line the player reads.
##
## Order matters and is the reverse of the old hand table: the verified locale layer
## is asked first, and `EVENT_LABELS` is the readable floor. An id whose locale
## template still carries unbound placeholders (`serveHint`) also goes to the floor:
## the reference fills those two parameters at the call site (`js/game.js:2629-2632`)
## and the ported simulation does not carry them, so resolving it would put
## `{ordinal}` on screen.
static func describe_event(id: String) -> String:
	if Locale.is_resolvable(id) and Locale.required_params(id).is_empty():
		return Locale.t(id)
	return EVENT_LABELS.get(id, UNREADABLE)


## The same resolution, under the name the HUD's log carried (`reason_label`): the
## debt-ledger's own word for an id it could not resolve. Never an id, never a
## silent `??`.
static func reason_label(reason: String) -> String:
	return describe_event(reason)
