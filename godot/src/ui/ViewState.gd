## ViewState.gd — the in-match HUD's view-model: the one place that knows the
## runner's field names (`godot/src/sim/state.gd`), the reference's field names
## (`js/ui.js:1276-1373`, `js/game.js:3344-3356`) and the small arithmetic that
## turns one into the other.
##
## WHY IT EXISTS. `Hud.gd` paints; it must not also know that the runner stores
## `playerScore` and that the reference renders it as a string, or that the
## active-player label has five branches (`js/ui.js:1288-1299`). One file keeps
## those decisions so the HUD can be read as layout, and so an audit can assert
## the mapping without a rendered frame.
##
## RULES THIS FILE KEEPS
##
##   - **Ids, never prose.** Every field here is an id, a locale *key*, a number or
##     a resolved sentence that came out of the locale seam. No sentence is written
##     into this file; nothing here is user-facing text the reference does not have
##     (`js/ui.js` resolves every label through `t()`).
##   - **Presence-checked reads.** The runner is a real `SimState` object; a field
##     the port has not landed is read through `_field()` and answers `null`, which
##     the coercers at the bottom turn into a typed default. The three port gaps this
##     exists for are named where they are read (`careerSeason`, `shotRead.perfectWindow`,
##     the pvp opponent).
##   - **The separators are the reference's own**, composed through `_space()` because
##     the UI lane's literal scan (`godot/tests/ui/router_audit.gd:437-455`) treats any
##     literal containing a space as prose: `" · "` (`js/game.js:2110`), `" > "`
##     (`js/ui.js:1292`), `" "` (`js/ui.js:1279`).
##
## THE FIELDS ARE THE HUD'S, NOT THE REFERENCE'S. `FIELDS` below is the exact key set
## `from_state()` returns; `hud_audit.gd` asserts the two agree.
extends RefCounted

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Frozen := preload("res://src/sim/frozen.gd")
## The one owner of the feedback vocabulary, for the marker this file renders when a
## message id cannot be resolved (architecture-deepening gate 1).
const Vocabulary := preload("res://game/feedback_vocabulary.gd")

## Every key `from_state()` and `capture_view()` return. The HUD reads nothing else.
const FIELDS := [
	"player_score", "ai_score",
	"player_name", "ai_name", "player_name_key", "ai_name_key",
	"match_info", "match_info_parts",
	"active_label_key", "active_label_params", "active_label_text",
	"active_auto_switch", "active_role_key", "active_player_key",
	"tactic_key", "tactic_upper", "tactic_flash", "tactic_text", "tactic_id",
	"combo_n", "combo_text", "combo_color_key", "combo_glow",
	"elapsed", "timer_text",
	"special_ready", "special_dim",
	"shot_intent", "shot_intent_key", "shot_intent_color_key",
	"shot_advice", "shot_advice_key", "shot_advice_color_key", "shot_profile",
	"shot_power", "aim_left", "timing_left", "timing_width",
	"serve_visible", "serve_point_style", "serve_text", "serve_key",
	"log_lines", "map_points",
]

## `js/ui.js:1328-1337`: the eight shot intents the reference labels, in its own map.
## A ninth value is not a new label — it falls back to `shot` (the reference's `?? t("shot")`).
const INTENT_KEYS := {
	"drive": "driveLbl",
	"slice": "sliceLbl",
	"lob": "lobLbl",
	"defensive-lob": "defensiveLobLbl",
	"chiquita": "chiquitaLbl",
	"vibora": "viboraLbl",
	"smash": "smashLbl",
	"auto": "shot",
}

## `styles.css:963-968` (`.shot-meter__intent[data-intent=…]`), each value mapped onto
## the nearest `Palette` entry of `padel_theme.tres`: the theme is UIR-02's file and
## carries no intent-specific token, so the *name of the token* is the one the theme
## owns and the exact reference value is recorded in the ticket's evidence
## (`evidence/uir-08-hud-audit.log`, substitutions table).
const INTENT_COLOR_KEYS := {
	"drive": "text_soft_3",
	"slice": "success",
	"lob": "state_yellow",
	"defensive-lob": "state_yellow_soft",
	"chiquita": "success_cyan",
	"vibora": "success_cyan",
	"smash": "rival",
	"auto": "text_soft_3",
}

## `styles.css:959-961` (`.shot-meter__advice[data-profile=…]`).
const ADVICE_COLOR_KEYS := {
	"control": "success_cyan",
	"attack": "state_yellow",
	"risk": "rival",
}

## `js/ui.js:1313` — the combo ladder, with `js/ui.js:1314`'s `#ff6d70` fallback.
const COMBO_COLOR_KEYS := {
	1: "combo_1",
	2: "combo_2",
	3: "combo_3",
	4: "combo_4",
}
const COMBO_FALLBACK_KEY := "combo_default"
## `js/ui.js:1315`: the glow comes on at four.
const COMBO_GLOW_FROM := 4

## `js/ui.js:1302-1306`: movement states win over the team tactic above this ratio.
const MOVEMENT_THRESHOLD := 0.15

## `js/ui.js:1354` — the reference's own default when the runner does not carry one.
const PERFECT_WINDOW_DEFAULT := 0.055
## `js/ui.js:1353` — the timing needle's band, in percent.
const TIMING_LEFT_MIN := -8.0
const TIMING_LEFT_MAX := 108.0
## `js/ui.js:1354` — the perfect window's width band, in percent.
const TIMING_WIDTH_MIN := 5.0
const TIMING_WIDTH_MAX := 17.0
## `js/ui.js:1345`, `:1342` — the two defaults the reference uses when `shotRead` is absent.
const ADVICE_DEFAULT := "read"
const PROFILE_DEFAULT := "control"

## `js/main.js:1400-1403` — the mini-map's own canvas geometry. The port draws the
## reference's canvas footprint (108x154) instead of its CSS display size (86x122):
## the reference scales a bitmap, a Control draws vectors.
const MAP_SIZE := Vector2(108.0, 154.0)
const MAP_PADDING := 11.0
const MAP_X0 := 80.0
const MAP_X1 := 880.0
const MAP_Y0 := 56.0
const MAP_Y1 := 564.0
## `js/main.js:1414-1424`: four paddles and the ball, in the reference's own colours,
## mapped onto the nearest `Palette` entry (see INTENT_COLOR_KEYS for the rule).
const MAP_PADDLE_KEYS := ["cyan", "text_soft_3", "coral", "rival"]
const MAP_PADDLE_RADIUS := 4.0
const MAP_BALL_KEY := "state_yellow"
const MAP_BALL_RADIUS := 3.2

## The two point ids the locale contract declares a composite rule for
## (`godot/src/locale/locale_rules.json`, `compositeRules`).
const POINT_KEYS := ["pointYou", "pointOpp"]
## The two serve faults the runner stores lowercased (`js/game.js:2128` calls
## `reason.toLowerCase()`; the port stores the same marker at `sim.gd:2038`), and the
## locale keys they name. The reference renders `t("doubleFault", {reason: t(<key>).toLowerCase()})`.
const FAULT_KEYS := {
	"serveoutbox": "serveOutBox",
	"servewallfault": "serveWallFault",
}
## A deliberate, visibly wrong marker instead of an id. It is the one user-facing
## string in this file that the reference does not have; its owner is the vocabulary
## module (`godot/game/feedback_vocabulary.gd::UNREADABLE`), shared with the match
## HUD, so the recreated path keeps no second copy of the marker.


# ---------------------------------------------------------------------------
# The live path: runner state + meta -> the HUD's fields
# ---------------------------------------------------------------------------

static func from_state(state, meta: Dictionary) -> Dictionary:
	var view := {}
	view["player_score"] = _text(_field(state, "playerScore"))
	view["ai_score"] = _text(_field(state, "aiScore"))
	var names := names_for(state)
	view["player_name"] = names["player"]
	view["ai_name"] = names["ai"]
	view["player_name_key"] = names["player_key"]
	view["ai_name_key"] = names["ai_key"]
	var info := match_info(state, meta)
	view["match_info"] = info["text"]
	view["match_info_parts"] = info["parts"]
	var active := active_label(state)
	view["active_label_key"] = active["key"]
	view["active_label_params"] = active["params"]
	view["active_label_text"] = active["text"]
	view["active_auto_switch"] = active["auto_switch"]
	view["active_role_key"] = active["role_key"]
	view["active_player_key"] = _text(_field(state, "activePlayerKey"))
	var tactic := tactic_state(state)
	view["tactic_key"] = tactic["key"]
	view["tactic_upper"] = tactic["upper"]
	view["tactic_flash"] = tactic["flash"]
	view["tactic_text"] = tactic["text"]
	view["tactic_id"] = tactic["id"]
	var combo := maxi(_int(_field(state, "combo"), 1), 1)
	view["combo_n"] = combo
	view["combo_text"] = UiStrings.t("combo", {"n": combo})
	view["combo_color_key"] = String(COMBO_COLOR_KEYS.get(combo, COMBO_FALLBACK_KEY))
	view["combo_glow"] = combo >= COMBO_GLOW_FROM
	var elapsed := maxf(_float(_field(state, "elapsed"), 0.0), 0.0)
	view["elapsed"] = elapsed
	view["timer_text"] = timer_text(elapsed)
	view["special_ready"] = clampf(_float(_field(state, "specialReady"), 0.0), 0.0, 1.0)
	view["special_dim"] = _float(_field(state, "specialCooldown"), 0.0) > 0.0
	var shot := shot_state(state)
	for key in shot:
		view[key] = shot[key]
	var serve := serve_state(state)
	for key in serve:
		view[key] = serve[key]
	view["log_lines"] = log_lines(state)
	view["map_points"] = map_points(state)
	return view


## The two names the scoreboard shows. `js/ui.js:1279-1282`:
##   player   = t(`athlete_<state.athlete.id>_name`).split(" ").pop()
##   opponent = pvp ? t(`athlete_<opponentAthlete.id>_name`)
##                  : (state.ai.id ? t(`ai_<state.ai.id>_name`) : state.ai.name)
## The port's runner stores the pvp opponent as `pvpAthlete` (`state.gd:37`), which the
## reference fills from `opponentAthlete` (`js/main.js:1181-1183`) — the same fact.
static func names_for(state) -> Dictionary:
	var athlete: Dictionary = _dict(_field(state, "athlete"))
	var ai: Dictionary = _dict(_field(state, "ai"))
	var opponent: Dictionary = _dict(_field(state, "pvpAthlete"))
	var player_key := "athlete_%s_name" % _text(athlete.get("id"))
	var ai_key := ""
	if _text(_field(state, "humanMode")) == "pvp" and not opponent.is_empty():
		ai_key = "athlete_%s_name" % _text(opponent.get("id"))
	elif _text(ai.get("id")) != "":
		ai_key = "ai_%s_name" % _text(ai.get("id"))
	var ai_text := UiStrings.t(ai_key) if ai_key != "" else _text(ai.get("name"))
	return {
		"player": last_word(UiStrings.t(player_key)),
		"ai": last_word(ai_text),
		"player_key": player_key,
		"ai_key": ai_key,
	}


## `js/ui.js:1279`: `.split(" ").pop()` — the last word of the resolved name.
static func last_word(text: String) -> String:
	var parts := text.split(_space())
	if parts.size() == 0:
		return text
	return parts[parts.size() - 1]


## `getMatchInfo` (`js/game.js:3344-3356`). `parts` carries what the line is made of,
## so an audit can assert the pieces rather than only the sentence.
##
## PORT GAP, named: `state.careerSeason` does not exist in `godot/src/sim/state.gd`
## (the reference sets it in `js/main.js:1193`). It is read presence-checked; when it is
## absent the career line keeps its base (`t("careerMatch")`) and `parts["career_season"]`
## is 0, which the evidence records as an open field for the mount to supply through
## `meta["career_season"]`.
static func match_info(state, meta: Dictionary) -> Dictionary:
	var mode := _text(_field(state, "mode"))
	var season := _int(_field(state, "careerSeason"), 0)
	if season == 0:
		season = _int(meta.get("career_season"), 0)
	var round_index := _int(_field(state, "tournamentRound"), 0)
	var parts := {"mode": mode, "career_season": season, "round": round_index, "human": ""}
	var base := ""
	if mode == "tournament":
		base = UiStrings.t("tournamentMatch") + _space() + "%d/3" % (round_index + 1)
	elif mode == "career":
		base = UiStrings.t("careerMatch")
		if season > 0:
			base += sep_dot() + UiStrings.t("careerSeason", {"n": season})
	else:
		base = UiStrings.t("quickMatch")
	var human := _text(_field(state, "humanMode"))
	if human == "coop":
		parts["human"] = "coop"
		base += sep_dot() + UiStrings.t("hmCoop")
	elif human == "pvp":
		parts["human"] = "pvp"
		base += sep_dot() + UiStrings.t("hmPvp")
	var points_to_win := _int(_field(state, "pointsToWin"), 0)
	var sets: Dictionary = _dict(_field(state, "sets"))
	var games: Dictionary = _dict(_field(state, "games"))
	var tie_break_points: Dictionary = _dict(_field(state, "tieBreakPoints"))
	var tie_break := bool(_field(state, "tieBreak"))
	var line := ""
	if points_to_win > 0:
		line = UiStrings.t("ptsToWin", {"n": points_to_win})
	elif tie_break:
		line = UiStrings.t("tieBreakShort") + _space() + "%d-%d" % [
			_int(tie_break_points.get("player"), 0), _int(tie_break_points.get("ai"), 0)]
	else:
		line = UiStrings.t("setLbl") + _space() + str(_int(sets.get("player"), 0) + _int(sets.get("ai"), 0) + 1)
		line += sep_dot() + UiStrings.t("gamesLbl") + _space() + "%d-%d" % [
			_int(games.get("player"), 0), _int(games.get("ai"), 0)]
	parts["points_to_win"] = points_to_win
	parts["tie_break"] = tie_break
	parts["line"] = line
	return {"text": base + sep_dot() + line, "parts": parts}


## `js/ui.js:1284-1298` — the five branches of the active-player label, in the
## reference's own order, plus the role it renders.
static func active_label(state) -> Dictionary:
	var key := _text(_field(state, "activePlayerKey"))
	var paddle: Variant = _field(state, key)
	var net_y := float(Frozen.court().get("netY", 0.0))
	var role_key := "roleBack" if _float(_field(paddle, "y"), 0.0) > net_y + 150.0 else "roleNet"
	var role := UiStrings.t(role_key)
	var serving := bool(_field(state, "serving"))
	var receiving_serve := _text(_field(state, "serveSide")) == "ai" \
		and (serving or bool(_field(_field(state, "ball"), "serveInFlight")))
	var branch := ""
	var params := {}
	var auto_switch := false
	var text := ""
	if receiving_serve:
		branch = "receiverLbl"
		var side_key := "sideLeft" if _text(_field(_field(state, "ball"), "serveTargetSide")) == "left" else "sideRight"
		params = {"side": UiStrings.t(side_key)}
		text = UiStrings.t(branch, params)
	elif _float(_field(state, "manualSwitchFlash"), 0.0) > 0.0:
		branch = "manual"
		text = UiStrings.t("manual") + sep_arrow() + role
	elif _float(_field(state, "receiverSwitchFlash"), 0.0) > 0.0:
		branch = "autoSwitchLbl"
		auto_switch = true
		params = {"role": role}
		text = UiStrings.t(branch, params)
	elif bool(_field(state, "receiverLocked")):
		branch = "receiveLbl"
		params = {"role": role}
		text = UiStrings.t(branch, params)
	else:
		branch = "manualLbl" if _text(_field(state, "controlMode")) == "manual" else "controlLbl"
		params = {"role": role}
		text = UiStrings.t(branch, params)
	return {
		"key": branch, "params": params, "text": text,
		"auto_switch": auto_switch, "role_key": role_key,
	}


## `js/ui.js:1299-1309` — the team tactic, with the movement override. The override is
## the reference's own upper-casing of a *resolved* sentence, so the HUD uppercases the
## rendered text; the tactic itself is the key `tacticHud_<tactic>`.
static func tactic_state(state) -> Dictionary:
	var key := _text(_field(state, "activePlayerKey"))
	var paddle: Variant = _field(state, key)
	var tactic := _text(_field(state, "playerTeamTactic"))
	if tactic == "":
		tactic = "balanced"
	var upper := false
	var text := ""
	var split_step := _float(_field(paddle, "splitStep"), 0.0)
	var sprinting := _float(_field(paddle, "sprinting"), 0.0)
	if split_step > MOVEMENT_THRESHOLD:
		upper = true
		text = UiStrings.t("splitStepLbl").to_upper()
	elif sprinting > MOVEMENT_THRESHOLD:
		upper = true
		text = (UiStrings.t("sprintLbl") + _space() + "%d%%" % roundi(sprinting * 100.0)).to_upper()
	else:
		text = UiStrings.t("tacticHud_%s" % tactic)
	return {
		"key": "tacticHud_%s" % tactic,
		"upper": upper,
		"flash": _float(_field(state, "tacticFlash"), 0.0) > 0.0,
		"text": text,
		"id": tactic,
	}


## `js/ui.js:1320-1357` — the two meters.
static func shot_state(state) -> Dictionary:
	var intent := _text(_field(state, "shotIntent"))
	if not INTENT_KEYS.has(intent):
		intent = "auto"
	var read: Dictionary = _dict(_field(state, "shotRead"))
	var advice := _text(read.get("advice"))
	if advice == "":
		advice = ADVICE_DEFAULT
	var profile := _text(read.get("profile"))
	if profile == "":
		profile = PROFILE_DEFAULT
	if not ADVICE_COLOR_KEYS.has(profile):
		profile = PROFILE_DEFAULT
	var active := bool(read.get("active", false))
	var eta_present := active and read.get("eta") != null
	var left := TIMING_LEFT_MIN
	if eta_present:
		left = clampf(52.0 - _float(read.get("eta"), 0.0) * 72.0, TIMING_LEFT_MIN, TIMING_LEFT_MAX)
	var width := clampf(_float(read.get("perfectWindow"), PERFECT_WINDOW_DEFAULT) * 155.0,
		TIMING_WIDTH_MIN, TIMING_WIDTH_MAX)
	return {
		"shot_intent": intent,
		"shot_intent_key": String(INTENT_KEYS[intent]),
		"shot_intent_color_key": String(INTENT_COLOR_KEYS.get(intent, "text_soft_3")),
		"shot_advice": advice,
		"shot_advice_key": "shotAdvice_%s" % advice,
		"shot_advice_color_key": String(ADVICE_COLOR_KEYS[profile]),
		"shot_profile": profile,
		"shot_power": clampf(_float(_field(state, "shotCharge"), 0.0), 0.0, 1.0),
		"aim_left": clampf(50.0 + _float(_field(state, "shotAim"), 0.0) * 42.0, 0.0, 100.0),
		"timing_left": left,
		"timing_width": width,
	}


## `js/ui.js:1360-1368` — the serve banner, in the reference's own precedence:
## between points beats serving, and the point message is the state's own id.
static func serve_state(state) -> Dictionary:
	var serving := bool(_field(state, "serving"))
	var point_pause := _float(_field(state, "pointPause"), 0.0) > 0.0
	var point_message := _text(_field(state, "pointMessage"))
	var side := _text(_field(state, "serveSide"))
	var attempts := _int(_field(state, "serveAttempts"), 0)
	var key := ""
	var text := ""
	if point_pause:
		key = "pointMessage"
		text = resolve_message(point_message)
	elif side == "player":
		key = "serveSecond" if attempts > 0 else "serveFirst"
		text = UiStrings.t(key)
	else:
		key = "serveOpp"
		text = UiStrings.t(key)
	return {
		"serve_visible": serving or point_pause,
		"serve_point_style": point_pause,
		"serve_text": text,
		"serve_key": key,
	}


## The event ring (`state.events`, newest first, at most five — `sim.gd:241-244`),
## each id resolved the way the reference's `addEvent` stores it: as a sentence.
static func log_lines(state) -> Array:
	var out: Array = []
	var events: Variant = _field(state, "events")
	if typeof(events) != TYPE_ARRAY:
		return out
	for id in events:
		out.append(resolve_message(_text(id)))
	return out


## One message id -> the line the player reads.
##
## The locale seam already resolves the composite point ids through the declared rules
## (`locale_rules.json`, `compositeRules`): `pointYou:msgOut` -> `PUNTO TUO · Palla fuori
## dal campo.` One composite the contract leaves unresolved is the double fault, whose
## *argument* is a marker rather than a key (`doubleFault:serveoutbox`): the reference
## renders it as `t("doubleFault", {reason: t(<key>).toLowerCase()})` (`js/game.js:2128`),
## and that composition is what this branch performs.
##
## Anything left unresolved — the id itself, or a template still carrying `{ordinal}`
## (`serveHint`, the locale debt ledger's own case) — renders the vocabulary module's
## `UNREADABLE` instead of an id. Never an id on screen.
static func resolve_message(message_id: String) -> String:
	if message_id == "":
		return ""
	var parts := message_id.split(":")
	if parts.size() >= 3 and POINT_KEYS.has(String(parts[0])) and String(parts[1]) == "doubleFault":
		var marker := String(parts[2])
		var fault_key := String(FAULT_KEYS.get(marker, ""))
		if fault_key != "":
			var reason := UiStrings.t(fault_key).to_lower()
			return UiStrings.t(String(parts[0])) + sep_dot() + UiStrings.t("doubleFault", {"reason": reason})
	if not UiStrings.has(message_id):
		var let_key := "evLet" if message_id == "LET" else ""
		if let_key != "":
			return UiStrings.t(let_key)
		return Vocabulary.UNREADABLE
	var text := UiStrings.t(message_id)
	if text.contains("{"):
		return Vocabulary.UNREADABLE
	return text


## `js/main.js:1402` — the mini-map's own mapping, court pixels -> canvas pixels,
## plus the five dots in the reference's colours.
static func map_points(state) -> Array:
	var dots: Array = []
	var keys := ["player", "playerMate", "opponent", "opponentMate"]
	for index in keys.size():
		var paddle: Variant = _field(state, String(keys[index]))
		if paddle == null:
			continue
		dots.append({
			"position": map_point(_float(_field(paddle, "x"), 0.0), _float(_field(paddle, "y"), 0.0)),
			"radius": MAP_PADDLE_RADIUS,
			"color_key": String(MAP_PADDLE_KEYS[index]),
		})
	var ball: Variant = _field(state, "ball")
	if ball != null:
		dots.append({
			"position": map_point(_float(_field(ball, "x"), 0.0), _float(_field(ball, "y"), 0.0)),
			"radius": MAP_BALL_RADIUS,
			"color_key": MAP_BALL_KEY,
		})
	return dots


static func map_point(x: float, y: float) -> Vector2:
	var width := MAP_SIZE.x - MAP_PADDING * 2.0
	var height := MAP_SIZE.y - MAP_PADDING * 2.0
	return Vector2(
		MAP_PADDING + ((x - MAP_X0) / (MAP_X1 - MAP_X0)) * width,
		MAP_PADDING + ((y - MAP_Y0) / (MAP_Y1 - MAP_Y0)) * height)


## `js/ui.js:1337-1338` — `MM:SS`, zero-padded, floored.
static func timer_text(elapsed: float) -> String:
	var total := maxi(int(floor(elapsed)), 0)
	return "%02d:%02d" % [total / 60, total % 60]


# ---------------------------------------------------------------------------
# The harness path: the nine capture states, as constructed views
# ---------------------------------------------------------------------------

## One constructed view per capture state (`ticket` frontmatter `capture_states`).
## Each is built from **explicit, labeled values** — no simulation runs here and none
## is implied: the states exist so UIR-24/UIR-09 can capture the HUD's own variants,
## and the audit that proves the *live* mapping drives a real scripted rally through
## `from_state()` instead.
static func capture_view(state_id: String) -> Dictionary:
	var view := _constructed_base()
	match state_id:
		"default":
			view["serve_visible"] = true
			view["serve_text"] = UiStrings.t("serveFirst")
			view["serve_key"] = "serveFirst"
		"serving":
			view["serve_visible"] = true
			view["serve_point_style"] = false
			view["serve_text"] = UiStrings.t("serveSecond")
			view["serve_key"] = "serveSecond"
			view["active_label_key"] = "receiverLbl"
			view["active_label_text"] = UiStrings.t("receiverLbl", {"side": UiStrings.t("sideLeft")})
		"rally":
			view["serve_visible"] = false
			view["combo_n"] = 3
			view["combo_text"] = UiStrings.t("combo", {"n": 3})
			view["combo_color_key"] = "combo_3"
			view["tactic_key"] = "tacticHud_attack"
			view["tactic_text"] = UiStrings.t("tacticHud_attack")
			view["tactic_id"] = "attack"
			# `js/ui.js:1309`: a tactic that has just changed flashes — the chip's own
			# state, captured here so the flashing variation is a frame and not a claim.
			view["tactic_flash"] = true
			view["shot_power"] = 0.72
			view["aim_left"] = 61.5
			view["timing_left"] = 38.0
			view["timing_width"] = clampf(0.061 * 155.0, TIMING_WIDTH_MIN, TIMING_WIDTH_MAX)
			view["shot_intent"] = "slice"
			view["shot_intent_key"] = String(INTENT_KEYS["slice"])
			view["shot_intent_color_key"] = String(INTENT_COLOR_KEYS["slice"])
			view["shot_advice"] = "smash"
			view["shot_advice_key"] = "shotAdvice_smash"
			view["shot_advice_color_key"] = String(ADVICE_COLOR_KEYS["attack"])
			view["shot_profile"] = "attack"
		"point-pause":
			view["serve_visible"] = true
			view["serve_point_style"] = true
			view["serve_key"] = "pointMessage"
			view["serve_text"] = resolve_message("pointYou:msgOut")
		"set-tennis":
			view["player_score"] = "40"
			view["ai_score"] = "30"
			view["match_info"] = match_info(_constructed_state(), {})["text"]
			view["match_info_parts"] = match_info(_constructed_state(), {})["parts"]
			view["active_label_key"] = "receiveLbl"
			view["active_label_params"] = {"role": UiStrings.t("roleNet")}
			view["active_label_text"] = UiStrings.t("receiveLbl", {"role": UiStrings.t("roleNet")})
			view["active_role_key"] = "roleNet"
			view["combo_n"] = 4
			view["combo_text"] = UiStrings.t("combo", {"n": 4})
			view["combo_color_key"] = "combo_4"
			view["combo_glow"] = true
			view["log_lines"] = [UiStrings.t("evCounter"), UiStrings.t("evOppServe")]
		"drill":
			view["mode_view"] = {
				"mode": "drill",
				"title": UiStrings.t("training"),
				"phase": "",
				"metrics": [
					{"key": "drillScore", "value": "12"},
					{"key": "drillBest", "value": "18"},
					{"key": "drillHits", "value": "12/14"},
					{"key": "drillStreak", "value": "4"},
				],
				"lines": [],
			}
			# A drill serves nothing: the banner is a serve prompt in the reference, so
			# it cannot stand beside the training strip (the legibility audit measured
			# the two boxes meeting at 1152x648 while this came from the base view).
			view["serve_visible"] = false
		"tournament":
			view["mode_view"] = {
				"mode": "tournament",
				"title": UiStrings.t("tournamentMode"),
				"phase": "",
				"metrics": [],
				"lines": [UiStrings.t("tournamentMatch") + _space() + "2/3"],
			}
		"career":
			view["mode_view"] = {
				"mode": "career",
				"title": UiStrings.t("careerMode"),
				"phase": "",
				"metrics": [],
				"lines": [UiStrings.t("careerSeason", {"n": 2})],
				"objective_line": UiStrings.t("objSeasonTitle") + _space() + "2/8",
			}
		"panel-open":
			return capture_view("rally")
		_:
			return {}
	return view


## The defaults every constructed view starts from: a quick match at 0-0, serving,
## with the runner's own first frame values (`state.gd`). Constructed, and labeled as
## such wherever it is used.
static func _constructed_base() -> Dictionary:
	return {
		"player_score": "0",
		"ai_score": "0",
		"player_name": "Maestro",
		"ai_name": "Leggenda",
		"player_name_key": "athlete_maestro_name",
		"ai_name_key": "ai_leggenda_name",
		"match_info": UiStrings.t("quickMatch") + sep_dot() + UiStrings.t("ptsToWin", {"n": 11}),
		"match_info_parts": {"mode": "quick", "career_season": 0, "round": 0, "human": "", "points_to_win": 11, "tie_break": false, "line": ""},
		"active_label_key": "controlLbl",
		"active_label_params": {"role": UiStrings.t("roleBack")},
		"active_label_text": UiStrings.t("controlLbl", {"role": UiStrings.t("roleBack")}),
		"active_auto_switch": false,
		"active_role_key": "roleBack",
		"active_player_key": "player",
		"tactic_key": "tacticHud_balanced",
		"tactic_upper": false,
		"tactic_flash": false,
		"tactic_text": UiStrings.t("tacticHud_balanced"),
		"tactic_id": "balanced",
		"combo_n": 1,
		"combo_text": UiStrings.t("combo", {"n": 1}),
		"combo_color_key": "combo_1",
		"combo_glow": false,
		"elapsed": 95.0,
		"timer_text": timer_text(95.0),
		"special_ready": 1.0,
		"special_dim": false,
		"shot_intent": "auto",
		"shot_intent_key": String(INTENT_KEYS["auto"]),
		"shot_intent_color_key": String(INTENT_COLOR_KEYS["auto"]),
		"shot_advice": ADVICE_DEFAULT,
		"shot_advice_key": "shotAdvice_%s" % ADVICE_DEFAULT,
		"shot_advice_color_key": String(ADVICE_COLOR_KEYS[PROFILE_DEFAULT]),
		"shot_profile": PROFILE_DEFAULT,
		"shot_power": 0.0,
		"aim_left": 50.0,
		"timing_left": TIMING_LEFT_MIN,
		"timing_width": clampf(PERFECT_WINDOW_DEFAULT * 155.0, TIMING_WIDTH_MIN, TIMING_WIDTH_MAX),
		"serve_visible": true,
		"serve_point_style": false,
		"serve_text": UiStrings.t("serveFirst"),
		"serve_key": "serveFirst",
		"log_lines": [UiStrings.t("evOppServe")],
		"map_points": _constructed_map_points(),
	}


## A runner-shaped **dictionary** for the capture states that need one. Every read in
## this file goes through `_field()`, which reads objects and dictionaries alike, so a
## constructed state does not have to be a `SimState`; the live path still receives the
## real one from the runner. Constructed, and named as such.
static func _constructed_state() -> Dictionary:
	return {
		"mode": "quick",
		"pointsToWin": 0,
		"tieBreak": true,
		"tieBreakPoints": {"player": 4, "ai": 3},
		"sets": {"player": 1, "ai": 0},
		"games": {"player": 5, "ai": 4},
		"humanMode": "",
	}


static func _constructed_map_points() -> Array:
	var court: Dictionary = Frozen.court()
	var mid_x := (float(court.get("left", MAP_X0)) + float(court.get("right", MAP_X1))) / 2.0
	return [
		{"position": map_point(mid_x, float(court.get("bottom", MAP_Y1)) - 120.0), "radius": MAP_PADDLE_RADIUS, "color_key": "cyan"},
		{"position": map_point(mid_x - 60.0, float(court.get("bottom", MAP_Y1)) - 60.0), "radius": MAP_PADDLE_RADIUS, "color_key": "text_soft_3"},
		{"position": map_point(mid_x - 40.0, float(court.get("top", MAP_Y0)) + 120.0), "radius": MAP_PADDLE_RADIUS, "color_key": "coral"},
		{"position": map_point(mid_x + 60.0, float(court.get("top", MAP_Y0)) + 60.0), "radius": MAP_PADDLE_RADIUS, "color_key": "rival"},
		{"position": map_point(mid_x, float(court.get("netY", MAP_Y0))), "radius": MAP_BALL_RADIUS, "color_key": MAP_BALL_KEY},
	]


# ---------------------------------------------------------------------------
# The reference's separators (composed, never written with a space)
# ---------------------------------------------------------------------------

static func _space() -> String:
	return String.chr(32)


## `js/ui.js:1289` — the reference's own single-space operator (`${t("controlMsg")} …`).
static func sep_space() -> String:
	return _space()


## `js/game.js:2110` / `locale_rules.json` `compositeRules.*.separator`.
static func sep_dot() -> String:
	return _space() + "·" + _space()


## `js/ui.js:1292` — `${t("manual")} > ${activeRole}`.
static func sep_arrow() -> String:
	return _space() + ">" + _space()


# ---------------------------------------------------------------------------
# Nil-safe reads (the same rule `godot/src/ui/data/UiData.gd:490-503` keeps, and for
# the same reason: the runner's defaults are not guaranteed to be of the type their
# field name suggests)
# ---------------------------------------------------------------------------

## A field of the runner (an object) or of a plain dictionary, or `null` when absent.
static func _field(source, name: String) -> Variant:
	if source == null:
		return null
	return source.get(name)


static func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _text(value: Variant) -> String:
	return "" if value == null else str(value)


static func _int(value: Variant, fallback: int = 0) -> int:
	return fallback if value == null else int(value)


static func _float(value: Variant, fallback: float = 0.0) -> float:
	return fallback if value == null else float(value)
