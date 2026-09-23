## UiData.gd — the read-only adapter between the new screens and the port's seams.
##
## WHY THIS EXISTS. The characters, arena, modes, history, challenges, profile and
## result screens all read the same persisted career/history/unlock data. If each one
## read saves or re-derived the demo rule, the pack would create a dozen owners for one
## rule. The port already has the right seams; this file makes them safe to consume
## without widening them:
##
##   godot/src/modes/modes_save.gd            the public mode-progression API
##                                            (`load_career`, `load_history`,
##                                            `load_drill_records`, `profile`, …)
##   godot/src/save/save_store.gd             atomic writes, quarantine, migration —
##                                            never called from here beyond reads
##   godot/src/modes/career_rules.gd          `is_unlocked`, `career_fixture`,
##                                            `career_rival`, `dictated_rivals`
##   godot/src/modes/career_progress.gd       `ensure_season_objectives`,
##                                            `objective_status`, `season_progress`
##   godot/src/modes/mode_tables.gd           the frozen tables (`outfits`, `objective_defs`)
##   godot/game/content_gate.gd               the demo rule (`is_locked`, `roster`, …)
##   godot/game/match_config.gd               the selection and `save_store()`
##   godot/src/sim/frozen.gd                  the frozen roster and arena tables
##
## ARENAS COME FROM THE ONE CATALOG. `arena_rows` / `world_arena_rows` are
## pass-throughs to `game/arenas/arena_catalog.gd` (bound to this build by
## `content_gate.gd::arena_catalog()`), so the frozen index, the demo wall, the
## career wall and the world set are answered once for both UI paths. Nothing here
## re-derives an arena rule.
##
## RULES THIS FILE KEEPS, so a reviewer can check them mechanically
## (`godot/tests/ui/data_audit.gd` scans this directory for both):
##
##   - **Ids, never prose.** Every dictionary carries ids and locale *keys*
##     (`athlete_maestro_name`, `quickMode`, `obj_winners`), never resolved text. No
##     function here calls the locale seam; the screen resolves what it shows.
##     ONE RECORDED EXCEPTION: a world arena is a port addition with no locale key
##     (`arena_style.gd` carries the deck's own name and description), so its row
##     carries the deck's text for the card to show. It is the catalog's row, not
##     prose written here.
##   - **Read-only.** Nothing here writes through the save contract: no
##     `ModesSave.save_*`, no `write_group`, no adapter that caches mutable state. The
##     write side belongs to the action tickets and goes through the same public API.
##   - **The gate is the truth.** Nothing re-derives the demo rule; every build answer
##     is delegated (`DemoGateAdapter.gd` is the thin wrapper screens actually use).
##
## The optional `store` argument on every read is the seam the audit uses: it points a
## call at a temp `SaveStore` so a real profile is never touched. A screen omits it and
## gets the config's own store (`match_config.gd::save_store()`).
##
## NULLS ARE REAL HERE. The save contract's own defaults are `null` for several fields
## (`save_schema.gd:136-140`: the three `lineup` slots; also `athleteId`, `arenaId`,
## `mode`), and `String(null)` is not a constructor in Godot — so every stored read goes
## through the `_text`/`_int`/`_bool`/`_float` coercers at the bottom of this file. That
## is a real finding from the audit run, not defensive habit.
extends RefCounted

const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Schema := preload("res://src/save/save_schema.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Art := preload("res://src/ui/data/UiArtPaths.gd")

## The reference's own mode order (`index.html:112-156`: quick, tournament, career) with
## the locale keys its cards carry.
const MODE_KEYS := [
	{"id": "quick", "title_key": "quickMode", "desc_key": "quickModeDesc"},
	{"id": "tournament", "title_key": "tournamentMode", "desc_key": "tournamentModeDesc"},
	{"id": "career", "title_key": "careerMode", "desc_key": "careerModeDesc"},
]

## The reference's six feedback topics (`index.html:322-327`, `data-value` attributes).
const FEEDBACK_TOPICS := [
	{"id": "bug", "label_key": "fbTopicBug"},
	{"id": "balance", "label_key": "fbTopicBalance"},
	{"id": "controls", "label_key": "fbTopicControls"},
	{"id": "performance", "label_key": "fbTopicPerformance"},
	{"id": "idea", "label_key": "fbTopicIdea"},
	{"id": "other", "label_key": "fbTopicOther"},
]

## The three stats the reference's stat strip shows, in its own order
## (`js/ui.js:824-826`), with the label each bar wears (`:824-826`).
const STAT_KEYS := ["power", "control", "speed"]
## The five ticks one bar carries; at least one of them is always filled
## (`js/ui.js:820`: `"▮".repeat(pieni) + "▯".repeat(5 - pieni)`).
const STAT_TICKS := 5
const STAT_FILLED_STEPS := 4
const STAT_LABEL_KEYS := {
	"power": "statPower",
	"control": "statControl",
	"speed": "statSpeed",
}

## `renderMatchStats` (`js/ui.js:1386-1406`): four compared rows plus two foot figures.
## `lower_is_better` is the reference's own fourth argument for the errors row.
const RESULT_STAT_ROWS := [
	{"key": "pointsWon", "label_key": "statPoints", "lower_is_better": false},
	{"key": "aces", "label_key": "statAces", "lower_is_better": false},
	{"key": "winners", "label_key": "statWinners", "lower_is_better": false},
	{"key": "errors", "label_key": "statErrors", "lower_is_better": true},
]


# ---------------------------------------------------------------------------
# History (`renderHistory`, js/ui.js:1574-1606)
# ---------------------------------------------------------------------------

## The stored history rows, newest first, each with the reference's own win/loss reading
## (`js/ui.js:1578-1580`: a row is a win when `winner === "player"`) and its trophy rule
## (`:1580`: the stored trophy flag, or a won tournament match). Ids only.
static func history_entries(store: RefCounted = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in ModesSave.load_history(_store(store)):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		out.append(_history_row(raw))
	return out


## The three counters the history screen's own stat boxes show (`js/ui.js:1578-1581`).
static func history_summary(store: RefCounted = null) -> Dictionary:
	var rows := history_entries(store)
	var wins := 0
	var losses := 0
	var trophies := 0
	for row in rows:
		if bool(row["won"]):
			wins += 1
		else:
			losses += 1
		if bool(row["counts_as_trophy"]):
			trophies += 1
	return {"wins": wins, "losses": losses, "trophies": trophies, "entries": rows.size()}


static func _history_row(raw: Dictionary) -> Dictionary:
	var mode := _text(raw.get("mode"))
	var won := _text(raw.get("winner")) == "player"
	var trophy := _bool(raw.get("trophy"), false)
	var opponent := _text(raw.get("opponent"))
	return {
		"id": "%d-%s-%s" % [_int(raw.get("ts"), 0), mode, opponent],
		"ts": _int(raw.get("ts"), 0),
		"result": "win" if won else "loss",
		"won": won,
		"mode": mode,
		"human_mode": _text(raw.get("humanMode")),
		"opponent": opponent,
		"athlete": _text(raw.get("athlete")),
		"arena": _text(raw.get("arena")),
		"score": _text(raw.get("score")),
		"points_to_win": _int(raw.get("pointsToWin"), 0),
		"trophy": trophy,
		"counts_as_trophy": trophy or (mode == "tournament" and won),
		"season": _int(raw.get("season"), 0),
	}


# ---------------------------------------------------------------------------
# Career (`renderProfile`, js/ui.js:1608-1640)
# ---------------------------------------------------------------------------

## The career's four stat boxes (`js/ui.js:1612-1619`). `seasons` is the reference's own
## label for `career.trophies` — the number is carried, the naming is the screen's.
static func profile_summary(store: RefCounted = null) -> Dictionary:
	var career := ModesSave.load_career(_store(store))
	var wins := _int(career.get("wins"), 0)
	var losses := _int(career.get("losses"), 0)
	var total := wins + losses
	return {
		"wins": wins,
		"losses": losses,
		"total": total,
		"seasons": _int(career.get("trophies"), 0),
		"stars": _int(career.get("stars"), 0),
		"win_rate": 0 if total == 0 else int(round(float(wins) / float(total) * 100.0)),
		"season": _int(career.get("season"), 1),
		"match_index": _int(career.get("matchIndex"), 0),
	}


## The season's objectives with their live status: the reference renders exactly these
## facts per row (`js/ui.js:1622-1638`) — the label key `obj_<id>` with the target as its
## `n` placeholder, the progress figure, and whether it is done or already claimed.
static func season_objectives(store: RefCounted = null) -> Array[Dictionary]:
	var career := ModesSave.load_career(_store(store))
	var progress := CareerProgress.season_progress(career)
	var out: Array[Dictionary] = []
	for objective in CareerProgress.ensure_season_objectives(career):
		if typeof(objective) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = objective
		var id := _text(row.get("id"))
		var status: Dictionary = CareerProgress.objective_status(row, progress)
		out.append({
			"id": id,
			"label_key": "obj_%s" % id,
			"target": _int(status.get("target"), 0),
			"progress": _int(status.get("progress"), 0),
			"done": _bool(status.get("done"), false),
			"claimed": _bool(row.get("claimed"), false),
		})
	return out


## The three unlock economies the reference's Profile counts in one line
## (`js/ui.js:1653-1668`): athletes with an `unlock`, arenas with an `unlock`, and the
## outfits whose `challenge` gates them. `label_key` is the reference's own summary key
## (`profileUnlocksCount`, taking `done` and `total`).
static func unlock_summary(store: RefCounted = null) -> Dictionary:
	var career := ModesSave.load_career(_store(store))
	var characters := _unlock_bucket(_with_unlock(Frozen.athletes()), career)
	var arenas := _unlock_bucket(_with_unlock(Frozen.arenas()), career)
	var outfits: Array = []
	for athlete in Frozen.athletes():
		for outfit in Tables.outfits_for_athlete(_text((athlete as Dictionary).get("id"))):
			if (outfit as Dictionary).get("challenge", null) != null:
				outfits.append(outfit)
	var outfits_bucket := _unlock_bucket(outfits, career)
	return {
		"characters": characters,
		"outfits": outfits_bucket,
		"arenas": arenas,
		"done": int(characters["done"]) + int(outfits_bucket["done"]) + int(arenas["done"]),
		"total": int(characters["total"]) + int(outfits_bucket["total"]) + int(arenas["total"]),
		"label_key": "profileUnlocksCount",
	}


static func _with_unlock(items: Array) -> Array:
	var out: Array = []
	for item in items:
		if (item as Dictionary).get("unlock", null) != null:
			out.append(item)
	return out


static func _unlock_bucket(items: Array, career: Dictionary) -> Dictionary:
	var done := 0
	for item in items:
		if CareerRules.is_unlocked(item as Dictionary, career):
			done += 1
	return {"done": done, "total": items.size()}


# ---------------------------------------------------------------------------
# Drill (`loadDrillRecords`, js/ui.js:206-230)
# ---------------------------------------------------------------------------

## Every drill exercise the frozen tables hold, with its persisted best (0 when never
## played). `ModesSave.load_drill_records` is the reader; nothing here writes a record.
## `Tables.drill_catalog()` is the list: the reference's own four rows plus this build's
## Godot-only ones, so the record reader and the training screen cannot disagree about
## which exercises exist.
static func drill_records(store: RefCounted = null) -> Dictionary:
	var persisted := ModesSave.load_drill_records(_store(store))
	var rows: Array[Dictionary] = []
	var best_total := 0
	for exercise in Tables.drill_catalog():
		var id := _text((exercise as Dictionary).get("id"))
		var best := _int(persisted.get(id), 0)
		best_total += best
		rows.append({
			"id": id,
			"name_key": "drill_%s_name" % id,
			"best": best,
			"played": persisted.has(id),
		})
	return {"rows": rows, "best_total": best_total, "count": rows.size()}


# ---------------------------------------------------------------------------
# Roster, arenas, modes
# ---------------------------------------------------------------------------

## One row per frozen athlete, in roster order: ids and locale keys only. `locked` is
## the reference's own two-part rule (`js/ui.js:485-487`: the build's `demoFilter` and
## the career's `isUnlocked`), `demo_locked` separates the build half so a screen can
## word the two cases differently, which the reference does (`demoOnlyFull`).
static func athlete_rows(store: RefCounted = null) -> Array[Dictionary]:
	var career := ModesSave.load_career(_store(store))
	var selectable := Gate.roster()
	var out: Array[Dictionary] = []
	for athlete in Frozen.athletes():
		var row: Dictionary = athlete
		var id := _text(row.get("id"))
		var demo_locked := Gate.is_locked(row, "athlete")
		out.append({
			"id": id,
			"name_key": "athlete_%s_name" % id,
			"desc_key": "athlete_%s_desc" % id,
			"art_path": Art.path_for("athletes", id),
			"demo_locked": demo_locked,
			"locked": demo_locked or not CareerRules.is_unlocked(row, career),
			"selectable": _id_in(selectable, id),
		})
	return out


static func arena_rows(store: RefCounted = null) -> Array[Dictionary]:
	var career := ModesSave.load_career(_store(store))
	var catalog: Variant = Gate.arena_catalog()
	var out: Array[Dictionary] = []
	for row in catalog.frozen_rows(career):
		out.append(row as Dictionary)
	return out


## The WORLD arenas this build offers as a further choice: the five port additions
## in a full build, none in a demo — `arena_catalog.gd::world_rows()`, the same list
## `Config.selectable_world_arenas()` (the ported column's seam) hands the menu. A
## world row is a deck record, not a frozen row: its `name`/`desc` are the deck's own
## text and its physics are the library's PROVISIONAL neutrals (`world: true`,
## `provisional: true`) — see `arena_library.gd`'s `WORLD_WALL_BOUNCE` block.
static func world_arena_rows() -> Array[Dictionary]:
	var catalog: Variant = Gate.arena_catalog()
	var out: Array[Dictionary] = []
	for row in catalog.world_rows():
		out.append((row as Dictionary).duplicate(true))
	return out


## The reference's three mode cards (`index.html:112-156`), each with the build's answer
## about it. The career card additionally carries the calendar step it is on: in career
## mode the arena is the calendar's, not the menu's (`currentFixture`, `js/ui.js:500-503`,
## which the arena screen's own comment repeats at `js/ui.js:1227-1230`).
static func mode_rows(store: RefCounted = null) -> Array[Dictionary]:
	var career := ModesSave.load_career(_store(store))
	var exposed := Gate.modes()
	var out: Array[Dictionary] = []
	for spec in MODE_KEYS:
		var id := _text(spec["id"])
		var locked := not exposed.has(id)
		var row := {
			"id": id,
			"title_key": _text(spec["title_key"]),
			"desc_key": _text(spec["desc_key"]),
			"art_path": Art.path_for("modes", id),
			"locked": locked,
			"locked_key": Gate.locked_key(),
			"tag_key": "available" if not locked else Gate.locked_key(),
		}
		if id == "career":
			row["career"] = _career_fixture(career)
		out.append(row)
	return out


static func _career_fixture(career: Dictionary) -> Dictionary:
	var season := _int(career.get("season"), 1)
	var match_index := _int(career.get("matchIndex"), 0)
	var fixture: Dictionary = CareerRules.career_fixture(season, match_index, Gate.arenas())
	var rival: Dictionary = CareerRules.career_rival(season)
	return {
		"season": season,
		"match_index": match_index,
		"matches": CareerRules.career_matches(),
		"arena_id": _text((fixture.get("arena", {}) as Dictionary).get("id")),
		"rival_id": _text(rival.get("id")),
	}


## `resolveLineup` (`js/ui.js:548-593`), as ids: a saved slot is honoured only while it
## names an athlete this build can field and is not already on court, and the fallback
## for the two opponent slots draws on the whole roster — the reference's own comment:
## a demo fields two athletes and faces the others (`js/ui.js:552-556`).
static func lineup_defaults(store: RefCounted = null) -> Dictionary:
	var profile := ModesSave.profile(_store(store))
	var prefs: Dictionary = profile.get("prefs", {})
	var saved: Dictionary = prefs.get("lineup", {})
	var player := _text(Config.athlete().get("id"))
	var selectable := _ids_of(Gate.roster())
	var roster := _ids_of(Frozen.athletes())
	var used: Array = [player]
	var mate := _pick_saved(_text(saved.get("playerMate")), selectable, used)
	if mate != "":
		used.append(mate)
	var opponent := _pick_saved(_text(saved.get("opponent")), roster, used)
	if opponent != "":
		used.append(opponent)
	var opponent_mate := _pick_saved(_text(saved.get("opponentMate")), roster, used)
	return {
		"playerMate": mate,
		"opponent": opponent,
		"opponentMate": opponent_mate,
		"player": player,
	}


static func _pick_saved(saved_id: String, pool: Array, used: Array) -> String:
	if saved_id != "" and pool.has(saved_id) and not used.has(saved_id):
		return saved_id
	for id in pool:
		if not used.has(id):
			return _text(id)
	return ""


# ---------------------------------------------------------------------------
# Athlete stat strip (`STAT_RANGE`/`statLine`, js/ui.js:805-828)
# ---------------------------------------------------------------------------


## `STAT_RANGE` (`js/ui.js:805-812`): each stat's min and max over the WHOLE frozen
## roster — `ATHLETES.map((a) => a.stats[chiave])` there (`:808`), `Frozen.athletes()`
## here, the same six rows (checked against `js/data.js` on 2026-09-17). The reference's
## own words: "Le barrette servono a confrontare gli atleti fra loro, quindi la scala e'
## quella reale del roster e non un intervallo scelto a mano" (`:799-801`). The scale is
## the roster's, never a build's: a demo fields a subset and must still read the same
## bars, which is why this reads `Frozen` and not `Gate.roster()`.
static func stat_range() -> Dictionary:
	var out := {}
	for key in STAT_KEYS:
		out[key] = {"min": INF, "max": -INF}
	for athlete in Frozen.athletes():
		var stats: Dictionary = (athlete as Dictionary).get("stats", {})
		for key in STAT_KEYS:
			if not stats.has(key):
				continue
			var value := float(stats[key])
			var bounds: Dictionary = out[key]
			bounds["min"] = minf(float(bounds["min"]), value)
			bounds["max"] = maxf(float(bounds["max"]), value)
	return out


## One row per stat for one frozen athlete: `{key, label_key, value, filled, ticks}`.
## `filled` is the reference's own formula (`js/ui.js:819`):
## `1 + round(clampUnit((value - min) / (max - min || 1)) * 4)` — the weakest athlete of
## the roster keeps one tick, because "una barretta vuota sembra un dato mancante, non una
## statistica bassa" (`:817-818`). No number is written beside a bar; the bars compare
## athletes with each other, so `value` is carried for a caller that wants it, not shown.
static func stat_rows(athlete: Dictionary) -> Array[Dictionary]:
	var ranges := stat_range()
	var stats: Dictionary = athlete.get("stats", {})
	var out: Array[Dictionary] = []
	for key in STAT_KEYS:
		var bounds: Dictionary = ranges.get(key, {})
		var value := float(stats.get(key, 0.0))
		var min_value := float(bounds.get("min", 0.0))
		var span := float(bounds.get("max", 0.0)) - min_value
		var unit := 0.0 if span == 0.0 else clampf((value - min_value) / span, 0.0, 1.0)
		out.append({
			"key": key,
			"label_key": _text(STAT_LABEL_KEYS.get(key)),
			"value": value,
			"filled": 1 + int(round(unit * float(STAT_FILLED_STEPS))),
			"ticks": STAT_TICKS,
		})
	return out


# ---------------------------------------------------------------------------
# Settings (`collectPrefs`/`savePrefs`, js/ui.js:405-442)
# ---------------------------------------------------------------------------

## What the settings screen shows, read from the save contract's own defaults and the
## stored `prefs` group. Values only — no option lists, which are the screen's.
static func settings_snapshot(store: RefCounted = null) -> Dictionary:
	var profile := ModesSave.profile(_store(store))
	var prefs: Dictionary = profile.get("prefs", {})
	var defaults: Dictionary = Schema.PREFS_DEFAULTS
	return {
		"language": _text(prefs.get("lang", defaults.get("lang", "en"))),
		"reduce_motion": _bool(prefs.get("reduceMotion", defaults.get("reduceMotion", false)), false),
		"colorblind": _bool(prefs.get("colorblind", defaults.get("colorblind", false)), false),
		"volume": _float(prefs.get("volume", defaults.get("volume", 0.5)), 0.5),
		"music_volume": _float(prefs.get("musicVolume", defaults.get("musicVolume", 1.0)), 1.0),
		"muted": _bool(prefs.get("muted", defaults.get("muted", false)), false),
		"deadzone": _float(prefs.get("gamepadDeadzone", defaults.get("gamepadDeadzone", 0.15)), 0.15),
		"vibration": _bool(prefs.get("vibration", defaults.get("vibration", true)), true),
		"control_mode": _text(prefs.get("controlMode", defaults.get("controlMode", "semi"))),
		"match_length": _text(prefs.get("matchLength", defaults.get("matchLength", "points11"))),
		"player_mode": _text(prefs.get("playerMode", defaults.get("playerMode", "solo"))),
		"ai_difficulty": _text(prefs.get("aiDifficulty", defaults.get("aiDifficulty", "easy"))),
		"pace_preset": _text(prefs.get("pacePreset", defaults.get("pacePreset", ""))),
		"tournament_round": _int(prefs.get("tournamentRound", defaults.get("tournamentRound", 0)), 0),
	}


# ---------------------------------------------------------------------------
# Result screen (`renderMatchStats`/`renderObjectives`, js/ui.js:1386-1488)
# ---------------------------------------------------------------------------

## The result screen's data, presentation-free: the score line, the four compared stat
## rows with the reference's `better` marking (`js/ui.js:1398-1402`), the two rally
## figures (`:1404-1406`), the season objectives with their status, and the outfits this
## career has won (`career.outfitsWon`, `js/ui.js:629-630`).
##
## `result` is the match's own summary: `{score, won, pointsToWin, stats}` where `stats`
## carries `{pointsWon, aces, winners, errors}` as `{player, ai}` pairs — the shapes the
## reference reads at `js/ui.js:1394-1402`.
static func result_view(result: Dictionary, store: RefCounted = null) -> Dictionary:
	var stats: Dictionary = result.get("stats", {})
	var rows: Array[Dictionary] = []
	for spec in RESULT_STAT_ROWS:
		var pair: Dictionary = stats.get(_text(spec["key"]), {})
		var player := _int(pair.get("player"), 0)
		var opponent := _int(pair.get("ai"), 0)
		var better := "tie"
		if player != opponent:
			var higher_wins := player > opponent
			var player_better := higher_wins if not bool(spec["lower_is_better"]) else not higher_wins
			better = "player" if player_better else "opponent"
		rows.append({
			"key": _text(spec["key"]),
			"label_key": _text(spec["label_key"]),
			"player": player,
			"opponent": opponent,
			"lower_is_better": bool(spec["lower_is_better"]),
			"better": better,
		})
	var rally_count := _int(stats.get("rallyCount"), 0)
	var total_hits := _int(stats.get("totalRallyHits"), 0)
	return {
		"score": _text(result.get("score")),
		"won": _bool(result.get("won"), false),
		"points_to_win": _int(result.get("pointsToWin"), 0),
		"stats_rows": rows,
		"longest_rally": _int(stats.get("longestRally"), 0),
		"average_rally": 0.0 if rally_count == 0 else float(total_hits) / float(rally_count),
		"objectives": season_objectives(store),
		"outfit_rows": outfit_unlock_rows(store),
	}


## The outfits this career has won, as rows: `{athlete_id, outfit_id, unlock_key,
## name_key}`. Read from `career.outfitsWon` (keyed by `unlockKey`, `js/ui.js:629-630`)
## through the frozen outfit table's own lookup (`mode_tables.gd::outfit_by_unlock_key`).
static func outfit_unlock_rows(store: RefCounted = null) -> Array[Dictionary]:
	var career := ModesSave.load_career(_store(store))
	var won: Dictionary = career.get("outfitsWon", {})
	var out: Array[Dictionary] = []
	for key in won.keys():
		if not _bool(won[key], false):
			continue
		var outfit := Tables.outfit_by_unlock_key(_text(key))
		if outfit.is_empty():
			out.append({"athlete_id": "", "outfit_id": "", "unlock_key": _text(key), "name_key": ""})
			continue
		out.append({
			"athlete_id": _text(outfit.get("athleteId")),
			"outfit_id": _text(outfit.get("id")),
			"unlock_key": _text(key),
			"name_key": _text(outfit.get("nameKey")),
		})
	return out


## The reference's six feedback topics (`index.html:322-327`): ids and label keys.
static func feedback_topics() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for topic in FEEDBACK_TOPICS:
		out.append({"id": _text(topic["id"]), "label_key": _text(topic["label_key"])})
	return out


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## The store a read goes through: the caller's (the audit's temp directory) or the
## config's own. Never a cached store — a test may point `Config.save_dir` elsewhere.
static func _store(store: RefCounted) -> RefCounted:
	return store if store != null else Config.save_store()


## Stored values are not trusted to be of the type their field name suggests: the save
## contract's own defaults are `null` for `lineup`'s three slots and for the selection
## fields (`save_schema.gd:136-140`), and `String(null)` is not a constructor in Godot —
## the first audit run died on exactly that line. Every stored read goes through these.
static func _text(value: Variant) -> String:
	return "" if value == null else str(value)


static func _int(value: Variant, fallback: int = 0) -> int:
	return fallback if value == null else int(value)


static func _bool(value: Variant, fallback: bool = false) -> bool:
	return fallback if value == null else bool(value)


static func _float(value: Variant, fallback: float = 0.0) -> float:
	return fallback if value == null else float(value)


static func _id_in(items: Array, id: String) -> bool:
	for item in items:
		if _text((item as Dictionary).get("id")) == id:
			return true
	return false


static func _ids_of(items: Array) -> Array:
	var out: Array = []
	for item in items:
		var id := _text((item as Dictionary).get("id"))
		if id != "":
			out.append(id)
	return out
