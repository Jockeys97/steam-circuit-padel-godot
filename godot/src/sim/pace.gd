## pace.gd — the game-pace presets, as a TIME RATE and nothing else.
##
## WHAT A PRESET IS. One float, `factor`. Every clock that feeds the simulation
## multiplies its `dt` by it before the sim sees it. Running the sim clock `k`
## times faster is arithmetically the same as multiplying every speed in the game
## by `k`, because a speed is a distance over a time: the ball still travels the
## same trajectory through the same bounce points at the same angles, only the
## tempo of the whole match moves.
##
## WHY IT IS DONE THIS WAY. `src/sim/frozen/data.json` and `src/sim/frozen.gd` are
## the browser reference's own tables, asserted byte for byte, and BALANCE is the
## set of relationships the port promises to keep (`tests/audits/court_speed_audit.gd`
## asserts three of them). A pace preset touches none of those numbers: nothing
## inside the simulation moves, so every ratio between two of its values survives
## by construction. That is the whole reason a time-rate scale was chosen over a
## second tuning table.
##
## THE LADDER. `realistic` is the anchor: a verified radar study of padel smashes
## puts a real full-court crossing at 541 to 689 ms, and the build's own measured
## crossing is 876 ms (`tools/audit-port/logs/court_speed_audit.log`), so k = 1.5
## lands at 584 ms, inside the real band. Every other rung is stated as its ratio
## to real pace, `1.5 / factor`: 1.5:1, 2:1, 2.5:1, 3:1.
##
## THE DEFAULT IS `brisk`, whose factor is exactly 1.0, so an existing player's
## match runs at the tuning it has always run at until they choose otherwise.
##
## THE STRINGS LIVE HERE, not in `src/locale/locale_data.gd`: that file is
## generated from the frozen `js/i18n.js` and its verifier fails on any key the
## reference does not have. Port-added content carries its own display text in its
## own data module (the world arenas do the same in `game/arenas/arena_style.gd`),
## and the UI lane's literal scan stays clean because no sentence is written into a
## screen.
##
## PURE: no I/O, no save layer, no UI. A caller reads the id from wherever it keeps
## preferences and asks this file for the number.
extends RefCounted

## The id a player gets when nothing is stored, or when what is stored is not a
## preset any more. One constant, so moving the default is one line.
const DEFAULT_ID := "brisk"

## The ratio the `realistic` rung represents, and the numerator of every label's
## `real : game` figure (`real_pace_ratio = REAL_PACE_FACTOR / factor`).
const REAL_PACE_FACTOR := 1.5

## The ladder, slowest last. `factor` multiplies the dt that feeds the simulation.
const PRESETS: Array = [
	{"id": "realistic", "factor": 1.5, "label_key": "paceRealistic", "blurb_key": "paceRealisticBlurb"},
	{"id": "brisk", "factor": 1.0, "label_key": "paceBrisk", "blurb_key": "paceBriskBlurb"},
	{"id": "standard", "factor": 0.75, "label_key": "paceStandard", "blurb_key": "paceStandardBlurb"},
	{"id": "relaxed", "factor": 0.6, "label_key": "paceRelaxed", "blurb_key": "paceRelaxedBlurb"},
	{"id": "learning", "factor": 0.5, "label_key": "paceLearning", "blurb_key": "paceLearningBlurb"},
]

## The display text of the keys above, per locale, in the two languages the port
## carries (`src/locale/locale_data.gd::LOCALES`). The blurb states the concrete
## crossing time so a player picks by feel rather than by arithmetic.
const STRINGS: Dictionary = {
	"en": {
		"pacePreset": "GAME PACE",
		"paceRealistic": "Realistic (1:1)",
		"paceRealisticBlurb": "Full real-padel pace. The ball crosses the court in about 0.6 s.",
		"paceBrisk": "Brisk (1.5:1)",
		"paceBriskBlurb": "The pace this build has always run at. About 0.9 s to cross.",
		"paceStandard": "Standard (2:1)",
		"paceStandardBlurb": "Half real pace. The ball crosses the court in about 1.2 s.",
		"paceRelaxed": "Relaxed (2.5:1)",
		"paceRelaxedBlurb": "More time on every ball. About 1.5 s to cross.",
		"paceLearning": "Learning (3:1)",
		"paceLearningBlurb": "A third of real pace. The ball crosses the court in about 1.8 s.",
	},
	"it": {
		"pacePreset": "RITMO DI GIOCO",
		"paceRealistic": "Realistico (1:1)",
		"paceRealisticBlurb": "Ritmo reale del padel. La palla attraversa il campo in circa 0,6 s.",
		"paceBrisk": "Svelto (1.5:1)",
		"paceBriskBlurb": "Il ritmo con cui questa build ha sempre giocato. Circa 0,9 s per attraversare.",
		"paceStandard": "Standard (2:1)",
		"paceStandardBlurb": "Metà del ritmo reale. La palla attraversa il campo in circa 1,2 s.",
		"paceRelaxed": "Rilassato (2.5:1)",
		"paceRelaxedBlurb": "Più tempo su ogni palla. Circa 1,5 s per attraversare.",
		"paceLearning": "Didattico (3:1)",
		"paceLearningBlurb": "Un terzo del ritmo reale. La palla attraversa il campo in circa 1,8 s.",
	},
}


## The preset ids, in ladder order.
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for preset in PRESETS:
		out.append(String((preset as Dictionary)["id"]))
	return out


## True when `id` names a preset.
static func has(id: String) -> bool:
	return ids().has(id)


## The whole record for `id`, or the default's record for anything else. Never
## empty, so a caller cannot end up holding a factor of zero.
static func preset(id: String) -> Dictionary:
	for entry in PRESETS:
		if String((entry as Dictionary)["id"]) == id:
			return entry as Dictionary
	for entry in PRESETS:
		if String((entry as Dictionary)["id"]) == DEFAULT_ID:
			return entry as Dictionary
	return PRESETS[0] as Dictionary


## The dt multiplier for `id`. An unknown id gets the default's factor, which is
## the one answer that can never stop a match's clock.
static func factor_for(id: String) -> float:
	return float(preset(id)["factor"])


static func default_id() -> String:
	return DEFAULT_ID


## The simulated time one real `dt` is worth at this preset. The single arithmetic
## the whole feature is.
static func scaled_dt(dt: float, id: String) -> float:
	return dt * factor_for(id)


## How many times slower than real padel a preset plays, as the number its label
## carries: 1.0 for `realistic`, 3.0 for `learning`.
static func real_pace_ratio(id: String) -> float:
	return REAL_PACE_FACTOR / factor_for(id)


## The display text of a `label_key` / `blurb_key` in `lang`, falling back to the
## port's default locale and then to the key itself, the same chain
## `src/locale/locale.gd` resolves a reference id through.
static func text(key: String, lang: String) -> String:
	var table: Dictionary = STRINGS.get(lang, {})
	if table.has(key):
		return String(table[key])
	var fallback: Dictionary = STRINGS.get("en", {})
	return String(fallback.get(key, key))
