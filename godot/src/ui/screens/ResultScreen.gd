## ResultScreen.gd — `screen-result`, the reference's own summary (`index.html:539-566`).
##
## WHAT THIS SCREEN IS. The badge, the title, the narrative line, the two score figures,
## the four compared stat rows with their better-marking, the two rally figures, the
## objectives block (career only — `js/ui.js:1420-1424` returns early otherwise), the
## limited build's call to action (hidden while nothing is configured) and the two
## actions: rematch/next match, and menu.
##
## WHERE THE NUMBERS COME FROM — AND WHERE THEY DO NOT. `result_from_state()` reads a
## live `SimState`'s own fields (`points`, `sets`, `setScores`, `setsToWin`,
## `pointsToWin`, `stats`) and nothing else; `UiData.result_view()` turns the stat
## dictionary into the four rows the reference marks better/worse. This screen adds no
## arithmetic to any of them: it formats, and it reads. A payload a caller builds by
## hand has to carry the same shape, and the audit proves the live path with a match
## state the simulation itself stepped — no stat here is ever synthesised.
##
## THE SCORE LINE HAS THREE SHAPES, the reference's own (`js/ui.js:1493-1502`): a
## points match shows the points; a one-set tennis match shows that set's games (6-4,
## because "1-0" says nothing); a multi-set match shows the sets.
##
## THE NARRATIVE LINE is mode-specific (`js/ui.js:1504-1527`): the career's season
## outcome (four endings plus the plain win/loss line, `js/ui.js:772-785`), the
## tournament's next fixture or its trophy, and the arena line for a quick match. The
## rival's streak line is appended when the streak is long enough to be a story.
##
## WHAT THIS SCREEN DOES NOT DO: write anything. It has no store writes, no marks, no
## queue — the save lane records a match in `mode_session.gd`, before this screen is
## shown, and the audit asserts the store's bytes are untouched by a render.
##
## CAPTURE STATES. Eleven, each one a constructed payload: three score shapes, both
## outcomes, a career promotion, a tournament continuation, and the two limited-build
## calls to action. A capture never claims a live result — the audit labels them.
##
## LITERALS. None: every visible string is a message id, and the separators
## (` · `, a space) are composed, because a literal carrying a space is prose under the
## UI lane's own scan.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
## The locale, for the Emporio reward row's own two-line text: the OST lane carries its
## own IT/EN pair rather than a generated locale key (the Jukebox screen does the same).
const Locale := preload("res://src/locale/locale.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const Config := preload("res://game/match_config.gd")
## The optional coach block (see the file's own header, and `docs/agent-work/jev-coach/`).
## Loaded here, not preloaded by the router: a screen that never shows a result still
## carries no coach.
const CoachPanelScript := preload("res://src/ui/coach/CoachPanel.gd")

const SCREEN_ID := "result"

## The router's own row for this screen: no declared return, one action
## (`ScreenRouter.SCREENS[12]`).
const DECLARED_BACK := ""

const CAPTURE_STATES: Array[String] = [
	"default",
	"win-actions",
	"win-points",
	"loss-points",
	"win-set",
	"loss-set",
	"multi-set",
	"career-promotion",
	"tournament-next",
	"demo-cta",
	"beta-cta",
]

## The four endings `careerOutcomeText` switches on (`js/ui.js:772-785`).
const OUTCOMES: Array[String] = ["finale", "trophy", "promoted", "repeat"]
## …and the message id each one renders (`js/ui.js:776-779`).
const OUTCOME_KEYS := {
	"finale": "careerFinale",
	"trophy": "careerSeasonWin",
	"promoted": "careerSeasonPromoted",
	"repeat": "careerSeasonRepeat",
}

## `rematchBtn.textContent = ui.pendingContinue ? t("nextMatch") : t("rematch")`
## (`js/ui.js:1529-1532`).
const REMATCH_KEY := "rematch"
const NEXT_KEY := "nextMatch"

## The reference's own destinations for the store call to action
## (`applyStoreCta`, `js/main.js:2380-2430`): a wishlist link and a follow link.
const CTA_WISHLIST := "wishlist"
const CTA_FOLLOW := "follow"

## `.result-card` (`styles.css:1099-1108`): 520 px wide, radius 16, the panel fill.
const CARD_WIDTH := 620.0
const ACTION_HEIGHT := 54.0
## The four stat rows and the two score figures the reference lays out.
const STAT_ROWS := 4
const STAT_FIGURES := 2

var router_id: String = ""
var back_target_id: String = ""

signal rematch_requested

var _shell: Control
var _store: RefCounted = null
var _built := false
## Re-entrancy guard for the `resized` handler: writing theme-constant overrides from
## inside the layout pass can re-enter synchronously; unguarded it is a stack overflow
## (proven in-engine on DrillScreen, which shares this exact code shape).
var _applying_width := false
var _payload: Dictionary = {}
var _view: Dictionary = {}
var _outfits: Array = []
var _store_url := ""
var _store_kind := CTA_WISHLIST
var _objective_stars := 0
var _match_objective: Dictionary = {}
var _constructed := false
## Emporio OST: the credits this match paid and the resulting balance (see
## `_render_reward`). Hidden when the payload carries no reward.
var _reward_label: Label = null
## The coach block mounted under the card's own content, or null before `_build()`.
var _coach = null
## The exercise the coach's last advice links to, kept so the route can be asserted
## without reading the panel's own nodes (see `_on_coach_drill_requested`).
var _coach_drill_id: String = ""


func _ready() -> void:
	_ensure()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


## The router mounted this screen with the result payload (see `payload_from_state`).
## A payload carrying a live `state` is accepted too: the two builders above exist so a
## caller can hand either shape over, and the screen never mixes them.
func enter(payload: Dictionary) -> void:
	_ensure()
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", DECLARED_BACK))
	_shell.set_back_target(back_target_id)
	var incoming := payload
	if payload.has("state") and not payload.has("result"):
		incoming = payload_from_state(payload["state"], payload)
	render(incoming)


func exit() -> void:
	# The coach's own rule: a reply that arrives after the player left is dropped, not
	# painted (`godot/src/coach/coach_client.gd::cancel`).
	if _coach != null:
		_coach.cancel()


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## The eleven declared states, each a constructed payload (see `_capture_payload`).
func apply_capture_state(state_id: String) -> bool:
	_ensure()
	if not CAPTURE_STATES.has(state_id):
		return false
	_constructed = true
	render(_capture_payload(state_id))
	if state_id == "win-actions":
		_scroll_actions_capture()
	return true


func _scroll_actions_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := _control("ScreenScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# ---------------------------------------------------------------------------
# The store and the call to action's configuration
# ---------------------------------------------------------------------------

func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


func set_store(store_in: RefCounted) -> void:
	_store = store_in
	if _built:
		_render_objectives()


## The CTA's destination, from the same place the reference reads it
## (`FEEDBACK.steamUrl`/`discordUrl` are null there and the block stays hidden,
## `js/main.js:1961`). Empty by default: this build has no store page configured, and
## the screen says so instead of linking nowhere.
func set_store_config(url: String, kind: String) -> void:
	_store_url = url
	_store_kind = kind if kind != "" else CTA_WISHLIST
	if _built:
		_render_cta()


func cta_url() -> String:
	return _store_url


func cta_visible() -> bool:
	return _store_url != ""


## `applyStoreCta`: the label follows the destination, so the button never promises a
## wishlist when it opens something else.
func cta_label_key() -> String:
	return "demoWishlist" if _store_kind == CTA_WISHLIST else "storeFollow"


## `BUILD !== "demo"` picks the beta body (`js/main.js:2398-2406`). `betaResultBody` has
## no entry in the frozen locale table, so the id renders — the reference's own visible
## fallback — and the hand-back records the gap for the locale lane.
func cta_body_key() -> String:
	return "demoResultBody" if DemoGate.build() == "demo" else "betaResultBody"


# ---------------------------------------------------------------------------
# The payload (what `enter()` takes, and the two builders for it)
# ---------------------------------------------------------------------------

## The four presentation facts of a result, from the state's own fields: the two figures
## the reference shows, the outcome flag, and the live stat dictionary the viewer below
## consumes. The winner is the caller's fact (`mode_session.gd::match_winner()`), never
## derived here.
static func result_from_state(state, meta: Dictionary = {}) -> Dictionary:
	var points: Dictionary = state.points
	var sets: Dictionary = state.sets
	var scores: Array = state.setScores if state.setScores is Array else []
	var sets_to_win := int(state.setsToWin)
	var points_to_win := int(state.pointsToWin)
	var shown: Dictionary = sets
	if points_to_win > 0:
		shown = points
	elif sets_to_win == 1 and scores.size() == 1:
		var first: Variant = scores[0]
		if first is Dictionary:
			shown = first
	var player := int(shown.get("player", 0))
	var ai := int(shown.get("ai", 0))
	return {
		"score": "%d-%d" % [player, ai],
		"won": bool(meta.get("won", false)),
		"pointsToWin": points_to_win,
		"player": player,
		"ai": ai,
		"stats": state.stats,
	}


## The whole payload from a live state plus the facts only the mode knows. `meta`
## carries what the session's own report already holds (`mode_session.gd::report()`:
## `mode`, `winner`, `arena`, `season`, `match_index`, `awarded`) mapped by the caller,
## so this screen never guesses a mode rule.
static func payload_from_state(state, meta: Dictionary = {}) -> Dictionary:
	var out: Dictionary = meta.duplicate(true)
	out["result"] = result_from_state(state, meta)
	return out


## The rendered view of the payload: everything `_render_*` reads, computed once.
func view() -> Dictionary:
	_ensure()
	var result: Dictionary = _payload.get("result", {})
	if result.is_empty():
		result = {"score": "", "won": false, "pointsToWin": 0, "stats": {}}
	var view_data := UiData.result_view(result, store())
	view_data["mode"] = String(_payload.get("mode", ""))
	view_data["arena_id"] = String(_payload.get("arena_id", ""))
	view_data["season"] = int(_payload.get("season", 0))
	view_data["match"] = int(_payload.get("match", 0))
	view_data["outcome"] = String(_payload.get("outcome", ""))
	view_data["rival"] = _payload.get("rival", {})
	view_data["tournament"] = _payload.get("tournament", {})
	view_data["continue_pending"] = bool(_payload.get("continue_pending", false))
	view_data["constructed"] = _constructed
	return view_data


func render(payload: Dictionary) -> void:
	_ensure()
	_payload = payload.duplicate(true)
	_view = view()
	_objective_stars = int(_payload.get("objective_stars", 0))
	_match_objective = _payload.get("match_objective", {}) if _payload.get("match_objective", {}) is Dictionary else {}
	if _payload.has("store_url"):
		_store_url = String(_payload.get("store_url", ""))
		_store_kind = String(_payload.get("store_kind", _store_kind))
	_render_texts()
	_render_scores()
	_render_reward()
	_render_stats()
	_render_objectives()
	_render_cta()
	_render_coach()


# ---------------------------------------------------------------------------
# The score line and the stat rows
# ---------------------------------------------------------------------------

## The two figures, by the reference's three shapes (`js/ui.js:1493-1502`): a live
## result carries them (`result_from_state`), and a constructed payload must carry the
## same two keys — this screen never recomputes a score from parts it does not own.
func score_numbers() -> Array:
	var result: Dictionary = _payload.get("result", {})
	return [int(result.get("player", 0)), int(result.get("ai", 0))]


## `22` — average rally with one decimal, and `0` when no rally was recorded
## (`js/ui.js:1394-1396`: `rallyCount ? (totalHits / rallyCount).toFixed(1) : "0"`).
func average_rally_text() -> String:
	var stats: Dictionary = _payload.get("result", {}).get("stats", {})
	var count := int(stats.get("rallyCount", 0))
	if count == 0:
		return "0"
	return "%.1f" % (float(int(stats.get("totalRallyHits", 0))) / float(count))


func stats_rows() -> Array:
	return _view.get("stats_rows", [])


func longest_rally() -> int:
	return int(_view.get("longest_rally", 0))


# ---------------------------------------------------------------------------
# The narrative line
# ---------------------------------------------------------------------------

## The title key: `victory` or `defeat` (`js/ui.js:1504`, `:1518`).
func title_key() -> String:
	return "victory" if bool(_view.get("won", false)) else "defeat"


## The line under the title, mode by mode, exactly as `showResult` composes it.
func message_text() -> String:
	var won := bool(_view.get("won", false))
	var mode := String(_view.get("mode", ""))
	var text := ""
	if mode == "career":
		text = _career_message(won) + _rival_message(won)
	elif mode == "tournament":
		if won and bool(_tournament().get("continuing", false)):
			text = UiStrings.t("tourneyNext", {
				"n": int(_tournament().get("next_round", 0)),
				"arena": _arena_name(String(_tournament().get("next_arena_id", ""))),
			})
		elif won:
			text = UiStrings.t("tourneyWin")
		else:
			text = UiStrings.t("defeatMsg")
	else:
		text = UiStrings.t("winArena", {"arena": _arena_name(String(_view.get("arena_id", "")))}) if won else UiStrings.t("defeatMsg")
	return text


## `careerOutcomeText` (`js/ui.js:772-785`): the season's ending first, then the plain
## line. The match number is the payload's own — the session's report says which one was
## played, and the screen does not re-derive it from a career it cannot see.
func _career_message(won: bool) -> String:
	var outcome := String(_view.get("outcome", ""))
	var params := {"season": int(_view.get("season", 0)), "match": int(_view.get("match", 0))}
	if OUTCOME_KEYS.has(outcome):
		if outcome == "finale":
			params["rival"] = _rival_name()
		return UiStrings.t(String(OUTCOME_KEYS[outcome]), params)
	return UiStrings.t("careerMatchWin" if won else "careerMatchLoss", params)


## `rivalNarrative` (`js/ui.js:1409-1417`): a streak of two or more becomes a sentence,
## and the rival's own name comes from the roster's key.
func _rival_message(won: bool) -> String:
	var rival: Dictionary = _view.get("rival", {})
	var streak := int(rival.get("streak", 0))
	var suffix := ""
	if won and streak >= 2:
		suffix = UiStrings.t("rivalStreakWin", {"n": streak, "rival": _rival_name()})
	elif not won and streak <= -2:
		suffix = UiStrings.t("rivalStreakLoss", {"n": -streak, "rival": _rival_name()})
	return (_sp() + suffix) if suffix != "" else ""


func _rival_name() -> String:
	var rival: Dictionary = _view.get("rival", {})
	var id := String(rival.get("id", ""))
	return UiStrings.t("ai_%s_name" % id) if id != "" else UiStrings.t("rivalGeneric")


## The rematch label: the next match when the tournament (or the career) is pending.
func rematch_label_key() -> String:
	return NEXT_KEY if bool(_view.get("continue_pending", false)) else REMATCH_KEY


# ---------------------------------------------------------------------------
# The actions
# ---------------------------------------------------------------------------

## MenuFocus confirms through the host's action dispatcher, not Godot ui_accept.
## Reuse the mouse handlers, including their disabled/hidden state guards.
func activate(action: String) -> bool:
	_ensure()
	var button: BaseButton = null
	match action:
		"rematch":
			button = _control("RematchButton") as BaseButton
		"to-menu":
			button = _control("MenuButton") as BaseButton
		"coach-analyze":
			button = _coach.analyze_control() as BaseButton
		"coach-drill":
			button = _coach.drill_control() as BaseButton
	if button == null or button.disabled or not button.is_visible_in_tree():
		return false
	button.pressed.emit()
	return true

## The rematch press. The reference's own handler restarts the same match with
## `pendingContinue` state; the port leaves that to the mount, which is the node that
## knows the mode — this screen only reports the request, and names the label it showed.
func rematch() -> String:
	var action := rematch_label_key()
	rematch_requested.emit()
	return action


## The menu action is a route, so it goes through the router above this screen, the same
## climb `MenuScreen.route_action` uses.
func go_to_menu() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to("menu"))
		node = node.get_parent()
	push_warning("ResultScreen: no router above this screen; to-menu went nowhere")
	return false


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _render_texts() -> void:
	(_control("Badge") as Label).text = UiStrings.t("matchOver")
	var title := _control("ResultTitle") as Label
	title.text = UiStrings.t(title_key())
	if theme != null:
		title.add_theme_color_override("font_color", theme.get_color("win_green", "Palette") \
			if bool(_view.get("won", false)) else theme.get_color("loss_red", "Palette"))
	(_control("Message") as Label).text = message_text()
	(_control("ScoreYouLabel") as Label).text = UiStrings.t("statYou")
	(_control("ScoreOppLabel") as Label).text = UiStrings.t("statOpp")
	(_control("HeadYou") as Label).text = UiStrings.t("statYou")
	(_control("HeadStats") as Label).text = UiStrings.t("statStats")
	(_control("HeadOpp") as Label).text = UiStrings.t("statOpp")
	(_control("RematchButton") as Button).text = UiStrings.t(rematch_label_key())
	(_control("MenuButton") as Button).text = UiStrings.t("menu")


## Emporio OST: the credits this match paid and the resulting balance. The payload
## carries `reward` only for a real played match — a harness run and a constructed
## capture payload have none — so the row is hidden rather than showing a fake zero.
func _render_reward() -> void:
	if _reward_label == null:
		return
	var reward: Variant = _payload.get("reward", null)
	if not (reward is Dictionary):
		_reward_label.visible = false
		_reward_label.text = ""
		return
	var awarded := int((reward as Dictionary).get("awarded", 0))
	var balance := int((reward as Dictionary).get("balance", 0))
	var italian := Locale.current_lang() != "en"
	_reward_label.visible = true
	if awarded > 0:
		_reward_label.text = ("Crediti Circuito +%d — Saldo: %d" % [awarded, balance]) \
			if italian else ("Circuit Credits +%d — Balance: %d" % [awarded, balance])
	else:
		_reward_label.text = ("Crediti Circuito — Saldo: %d" % balance) \
			if italian else ("Circuit Credits — Balance: %d" % balance)


func _render_scores() -> void:
	var numbers := score_numbers()
	var player := _control("ScorePlayer") as Label
	var opponent := _control("ScoreAi") as Label
	player.text = str(numbers[0])
	opponent.text = str(numbers[1])
	if theme != null:
		player.add_theme_color_override("font_color", theme.get_color("cyan", "Palette"))
		opponent.add_theme_color_override("font_color", theme.get_color("rival", "Palette"))


## The four compared rows and the two foot figures (`renderMatchStats`,
## `js/ui.js:1386-1406`), with the reference's own better-marking on the winning side.
func _render_stats() -> void:
	var rows := stats_rows()
	(_control("StatsHead") as Control).visible = not rows.is_empty()
	for index in STAT_ROWS:
		var row := _control("StatRow%d" % index) as Control
		if row == null:
			continue
		row.visible = index < rows.size()
		if index >= rows.size():
			continue
		var spec: Dictionary = rows[index]
		(_control("StatLabel%d" % index) as Label).text = UiStrings.t(String(spec.get("label_key", "")))
		var player := _control("StatPlayer%d" % index) as Label
		var opponent := _control("StatAi%d" % index) as Label
		player.text = str(int(spec.get("player", 0)))
		opponent.text = str(int(spec.get("opponent", 0)))
		_apply_better(player, String(spec.get("better", "tie")) == "player")
		_apply_better(opponent, String(spec.get("better", "tie")) == "opponent")
	(_control("StatLongest") as Label).text = UiStrings.t("statLongest") + _sp() + str(longest_rally())
	(_control("StatAvg") as Label).text = UiStrings.t("statAvgRally") + _sp() + average_rally_text()


func _apply_better(label: Label, better: bool) -> void:
	var theme: Theme = self.theme
	var colour := theme.get_color("ink", "Palette") if theme != null else Color.WHITE
	if better and theme != null:
		colour = theme.get_color("green", "Palette")
	label.add_theme_color_override("font_color", colour)


## The objectives block, career only (`renderObjectives`, `js/ui.js:1419-1488`): the
## season's rows, the match's bonus row, the stars earned, and the outfits this match
## just unlocked — announced here, where the player is already looking.
func _render_objectives() -> void:
	var block := _control("Objectives") as Control
	var mode := String(_view.get("mode", ""))
	var rows: Array = _view.get("objectives", []) if mode == "career" else []
	var outfits: Array = _payload.get("outfits", []) if mode == "career" and _payload.get("outfits", []) is Array else []
	# Detach first, then free: a deferred `queue_free` leaves the old rows attached
	# for a frame, and `add_child` auto-renames a fresh row whose name collides with
	# a still-attached sibling ("ObjRow0" becomes "@HBoxContainer@37") — the accessor
	# reads by name, so the rebuild must not race the old rows.
	for child in block.get_children():
		block.remove_child(child)
		child.queue_free()
	var has_match_objective := not _match_objective.is_empty() and mode == "career"
	if not has_match_objective and rows.is_empty() and _objective_stars == 0 and outfits.is_empty():
		block.visible = false
		return
	block.visible = true
	var head := Label.new()
	head.name = "ObjectivesHead"
	head.text = UiStrings.t("objTitle")
	if _objective_stars > 0:
		head.text += _dot() + UiStrings.t("objStarsEarned", {"n": _objective_stars})
	block.add_child(head)
	var index := 0
	for outfit in outfits:
		block.add_child(_outfit_row(index, outfit as Dictionary))
		index += 1
	if has_match_objective:
		block.add_child(_objective_row(0, _match_objective, "objMatchTitle", true))
	var season_index := 0
	for row in rows:
		block.add_child(_objective_row(season_index, row as Dictionary, _objective_title_key(row as Dictionary), false))
		season_index += 1


func _objective_title_key(row: Dictionary) -> String:
	if bool(row.get("claimed", false)) and bool(row.get("done", false)):
		return "objAlreadyClaimed"
	return "objSeasonTitle"


func _objective_row(index: int, row: Dictionary, title_key: String, match_scope: bool) -> Control:
	var line := HBoxContainer.new()
	line.name = "ObjRow%d" % index
	var check := Label.new()
	check.name = "ObjCheck%d" % index
	var done := bool(row.get("done", false))
	check.text = CHECK_DONE if done else CHECK_TODO
	line.add_child(check)
	var label := Label.new()
	label.name = "ObjLabel%d" % index
	var id := String(row.get("id", ""))
	var target := int(row.get("target", 0))
	var key := ("objMatch_%s" % id) if match_scope else ("obj_%s" % id)
	label.text = UiStrings.t(key, {"n": target})
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var progress := Label.new()
	progress.name = "ObjProgress%d" % index
	progress.text = "%d/%d" % [int(row.get("progress", 0)), target]
	line.add_child(progress)
	var category := Label.new()
	category.name = "ObjCategory%d" % index
	category.text = UiStrings.t(title_key)
	line.add_child(category)
	return line


func _outfit_row(index: int, outfit: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.name = "OutfitRow%d" % index
	var check := Label.new()
	check.name = "OutfitMark%d" % index
	check.text = CHECK_DONE
	line.add_child(check)
	var label := Label.new()
	label.name = "OutfitLabel%d" % index
	label.text = UiStrings.t(String(outfit.get("name_key", ""))) + _dot() + UiStrings.t("athlete_%s_name" % String(outfit.get("athlete_id", "")))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var category := Label.new()
	category.name = "OutfitCategory%d" % index
	category.text = UiStrings.t("outfitWonNow")
	line.add_child(category)
	return line


## The limited build's block, hidden while nothing is configured, with the body and the
## label the reference picks (`applyStoreCta`, `js/main.js:2380-2430`).
func _render_cta() -> void:
	var block := _control("Cta") as Control
	block.visible = cta_visible()
	if not cta_visible():
		return
	(_control("CtaTitle") as Label).text = UiStrings.t("demoResultTitle")
	(_control("CtaBody") as Label).text = UiStrings.t(cta_body_key())
	(_control("CtaButton") as Button).text = UiStrings.t(cta_label_key())


## What a capture pins. Every one of these is constructed — the audit says so, and the
## screen carries the flag in `view()["constructed"]`.
func _capture_payload(state_id: String) -> Dictionary:
	var base := _base_capture()
	match state_id:
		"win-actions":
			base["result"] = _capture_result(11, 7, 11, true)
		"win-points":
			base["result"] = _capture_result(11, 7, 11, true)
		"loss-points":
			base["result"] = _capture_result(8, 11, 11, false)
		"win-set":
			base["result"] = _capture_set_result(6, 4, true)
		"loss-set":
			base["result"] = _capture_set_result(3, 6, false)
		"multi-set":
			base["result"] = _capture_multi_set_result()
		"career-promotion":
			base["mode"] = "career"
			base["outcome"] = "promoted"
			base["season"] = 1
			base["match"] = 5
			base["result"] = _capture_result(11, 5, 11, true)
		"tournament-next":
			base["mode"] = "tournament"
			base["tournament"] = {"continuing": true, "next_round": 1, "next_arena_id": String((Config.arena() as Dictionary).get("id", ""))}
			base["continue_pending"] = true
			base["result"] = _capture_result(11, 9, 11, true)
		"demo-cta":
			base["store_url"] = CTA_URL_PLACEHOLDER
			base["store_kind"] = CTA_WISHLIST
		"beta-cta":
			base["store_url"] = CTA_URL_PLACEHOLDER
			base["store_kind"] = CTA_FOLLOW
	return base


## A capture's own scaffold. Nothing here is a claim about a match that was played —
## the stats are zeroes because a capture shows the layout, and the audit says so.
func _base_capture() -> Dictionary:
	return {
		"result": _capture_result(0, 0, 0, false),
		"mode": "quick",
		"arena_id": String((Config.arena() as Dictionary).get("id", "")),
		"season": 1,
		"match": 1,
		"outcome": "",
		"tournament": {},
		"continue_pending": false,
		"objective_stars": 0,
		"outfits": [],
		# Every capture is a complete state: the CTA is cleared unless the capture
		# itself sets one, so walking them in any order shows what each one pins.
		"store_url": "",
		"store_kind": CTA_WISHLIST,
	}


func _capture_result(player: int, ai: int, points_to_win: int, won: bool) -> Dictionary:
	return {
		"score": "%d-%d" % [player, ai],
		"won": won,
		"pointsToWin": points_to_win,
		"player": player,
		"ai": ai,
		"stats": {
			"pointsWon": {"player": player, "ai": ai},
			"aces": {"player": 2, "ai": 1},
			"winners": {"player": 5, "ai": 3},
			"errors": {"player": 4, "ai": 6},
			"doubleFaults": {"player": 1, "ai": 0},
			"smashWinners": {"player": 2, "ai": 1},
			"rallyCount": 9,
			"totalRallyHits": 32,
			"longestRally": 7,
		},
	}


func _capture_set_result(player: int, ai: int, won: bool) -> Dictionary:
	return _capture_result(player, ai, 0, won)


func _capture_multi_set_result() -> Dictionary:
	return _capture_result(2, 1, 0, true)


## The placeholder destination a capture pins: the CTA's layout, not a link anyone is
## meant to open (nothing in this screen opens it either way).
const CTA_URL_PLACEHOLDER := "https://example.invalid/steam-circuit-padel"

const CHECK_DONE := "✓"
const CHECK_TODO := "○"


# ---------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------

## The separators a literal may not carry: a space, and the reference's ` · `.
static func _sp() -> String:
	return String.chr(32)


static func _dot() -> String:
	return _sp() + String.chr(183) + _sp()


static func _arena_name(arena_id: String) -> String:
	return UiStrings.t("arena_%s_name" % arena_id)


func _tournament() -> Dictionary:
	var data: Variant = _view.get("tournament", {})
	return data if data is Dictionary else {}


func _ensure() -> void:
	if _built:
		return
	_built = true
	_shell = $Shell
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(DECLARED_BACK)
	_build()


func _build() -> void:
	var content: MarginContainer = _shell.content()
	# The reference's screen body scrolls (`.screen { overflow-y: auto }`): the promotion
	# card is taller than the shell at the compact frames, so the column rides a scroll
	# container — the same shape the history and profile bodies use.
	var scroll := ScrollContainer.new()
	scroll.name = "ScreenScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var centering := MarginContainer.new()
	centering.name = "Centering"
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centering.set_meta("max_width", CARD_WIDTH)
	scroll.add_child(centering)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 14)
	centering.add_child(column)
	centering.resized.connect(_apply_column_width.bind(centering, column))
	_apply_column_width(centering, column)
	var panel := PanelContainer.new()
	panel.name = "Card"
	panel.add_theme_stylebox_override("panel", _card_style())
	column.add_child(panel)
	var card := VBoxContainer.new()
	card.name = "CardBody"
	card.add_theme_constant_override("separation", 16)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(card)
	card.add_child(_badge_pill())
	var title := _label(card, "ResultTitle")
	title.add_theme_font_size_override("font_size", 42)
	var message := _label(card, "Message")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 17)
	message.modulate.a = 0.82
	card.add_child(_score_panel())
	# Emporio OST: the reward row sits with the score, above the stats — it is the
	# match's payout, and it is hidden when the payload carries none.
	_reward_label = _label(card, "RewardRow")
	_reward_label.add_theme_font_size_override("font_size", 15)
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.modulate.a = 0.9
	card.add_child(_stats_panel())
	card.add_child(_objectives_block())
	card.add_child(_cta_block())
	card.add_child(_coach_block())
	card.add_child(_actions_row())
	_register_focus()


## The optional coach, mounted the way every other block is: one block under the card's
## own content, with its sentences resolved by the coach's own table and its two controls
## registered with the shell's focus model so a pad reaches them like any other button.
func _coach_block() -> Control:
	var wrapper := PanelContainer.new()
	wrapper.name = "CoachCard"
	wrapper.add_theme_stylebox_override("panel", _section_style(true))
	var panel = CoachPanelScript.new()
	_coach = panel
	panel.drill_requested.connect(_on_coach_drill_requested)
	wrapper.add_child(panel)
	_shell.add_focus("CoachAnalyzeButton", _coach.analyze_control(), "coach-analyze", {"kind": "button"})
	_shell.add_focus("CoachDrillButton", _coach.drill_control(), "coach-drill", {"kind": "button"})
	return wrapper


## Hand the block this match's own numbers, and whether the run behind it is one press
## from continuing.
func _render_coach() -> void:
	if _coach == null:
		return
	_coach.show_result(_payload.get("result", {}), bool(_view.get("continue_pending", false)))


## The coach's one route. It opens the EXISTING training screen with the recommended
## exercise preselected, and it writes nothing: no `Config.pending_mode`, no
## `Config.pending_exercise`, so a pending career or tournament continuation keeps the
## run it was waiting for. Starting a drill from there is the drill screen's own,
## pre-existing entry, exactly as reaching it from the menu is.
func _on_coach_drill_requested(drill_id: String) -> bool:
	_coach_drill_id = drill_id
	var router := _router()
	if router == null:
		return false
	if not bool(router.call("go_to", "drill", {})):
		return false
	var screen: Node = router.call("active_screen")
	if screen == null or not screen.has_method("select_exercise"):
		return true
	# The exercise is chosen by the mounted screen's own recognizer: `return` is one of
	# the exercises the screen lists (`Tables.drill_catalog()`), so a coach advice for a
	# category that links it lands on the fifth selector like any other. A refusal is
	# reported instead of assumed away — the route opened a screen but did not reach the
	# exercise, and that is the failure mode this reports rather than hides.
	if not bool(screen.call("select_exercise", drill_id)):
		push_warning("ResultScreen: the training screen refused the coach's exercise '%s'" % drill_id)
		return false
	return true


## The router this screen was mounted by, found the same way `go_to_menu` finds it.
func _router() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return node
		node = node.get_parent()
	return null


func _apply_column_width(centering: MarginContainer, column: VBoxContainer) -> void:
	if _applying_width:
		return
	_applying_width = true
	var max_width := float(centering.get_meta("max_width", 0.0))
	# The column centres itself (`SIZE_SHRINK_CENTER`) instead of the centering carrying
	# side margins: margins are part of a container's own minimum size, so a width the
	# screen once had could never be given back and the shell stayed wider than its frame.
	var available := centering.get_parent_area_size().x
	var want_min := minf(max_width, available)
	if not is_equal_approx(column.custom_minimum_size.x, want_min):
		column.custom_minimum_size.x = want_min
	_applying_width = false


## `.result-card` (`styles.css:1099-1108`): the panel fill, a line border, radius 16.
func _card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var theme: Theme = self.theme
	if theme == null:
		return box
	box.bg_color = theme.get_color("panel", "Palette")
	var cyan := theme.get_color("cyan", "Palette")
	box.border_color = Color(cyan.r, cyan.g, cyan.b, 0.24)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.content_margin_left = 32.0
	box.content_margin_right = 32.0
	box.content_margin_top = 28.0
	box.content_margin_bottom = 28.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	box.shadow_size = 24
	box.shadow_offset = Vector2(0, 10)
	return box


func _section_style(accented: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var theme_now: Theme = self.theme
	if theme_now == null:
		return box
	var surface := theme_now.get_color("surface_0", "Palette")
	box.bg_color = Color(surface.r, surface.g, surface.b, 0.68)
	var border := theme_now.get_color("cyan", "Palette") if accented else theme_now.get_color("line", "Palette")
	box.border_color = Color(border.r, border.g, border.b, 0.30 if accented else border.a)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box


func _badge_pill() -> Control:
	var pill := PanelContainer.new()
	pill.name = "BadgePill"
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	if theme != null:
		var cyan := theme.get_color("cyan", "Palette")
		style.bg_color = Color(cyan.r, cyan.g, cyan.b, 0.12)
		style.border_color = Color(cyan.r, cyan.g, cyan.b, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(999)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", style)
	var badge := _label(pill, "Badge")
	badge.add_theme_font_size_override("font_size", 13)
	if theme != null:
		badge.add_theme_color_override("font_color", theme.get_color("text_soft_2", "Palette"))
	return pill


func _label(parent: Node, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


## `.result-scores` (`styles.css:1117-1141`): two columns, a caption and a big figure.
func _scores_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Scores"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for spec in [{"label": "ScoreYouLabel", "value": "ScorePlayer"}, {"label": "ScoreOppLabel", "value": "ScoreAi"}]:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 0)
		var caption := Label.new()
		caption.name = String(spec["label"])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(caption)
		var value := Label.new()
		value.name = String(spec["value"])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(value)
		var theme: Theme = self.theme
		if theme != null:
			value.add_theme_font_override("font", theme.get_font("font", "HeroTitle"))
			value.add_theme_font_size_override("font_size", 34)
			caption.modulate.a = 0.62
		row.add_child(block)
	return row


func _score_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ScorePanel"
	panel.add_theme_stylebox_override("panel", _section_style())
	panel.add_child(_scores_row())
	return panel


## `.result-stats` (`styles.css:1143-1188`): the two-sided head, four rows, the foot.
func _stats_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "Stats"
	block.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.name = "StatsHead"
	for node_name in ["HeadYou", "HeadStats", "HeadOpp"]:
		var label := Label.new()
		label.name = node_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(label)
	block.add_child(head)
	for index in STAT_ROWS:
		block.add_child(_stat_row(index))
	var foot := HBoxContainer.new()
	foot.name = "StatsFoot"
	for node_name in ["StatLongest", "StatAvg"]:
		var label := Label.new()
		label.name = node_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(label)
	block.add_child(foot)
	return block


func _stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	panel.add_theme_stylebox_override("panel", _section_style())
	panel.add_child(_stats_block())
	return panel


func _stat_row(index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "StatRow%d" % index
	for node_name in ["StatPlayer%d" % index, "StatLabel%d" % index, "StatAi%d" % index]:
		var label := Label.new()
		label.name = node_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)
	return row


func _objectives_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "Objectives"
	block.visible = false
	block.add_theme_constant_override("separation", 4)
	return block


func _cta_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "Cta"
	block.visible = false
	block.add_theme_constant_override("separation", 6)
	_label(block, "CtaTitle")
	var body := _label(block, "CtaBody")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var button := Button.new()
	button.name = "CtaButton"
	button.theme_type_variation = &"ButtonSecondary"
	button.custom_minimum_size.y = 48.0
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_cta_pressed)
	block.add_child(button)
	return block


## A press with a configured destination opens it (the reference's `<a target=_blank>`
## behaviour); with none there is nothing to open, and the block is not even shown.
func _on_cta_pressed() -> void:
	if _store_url != "":
		OS.shell_open(_store_url)


func _actions_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Actions"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	var rematch_button := Button.new()
	rematch_button.name = "RematchButton"
	rematch_button.theme_type_variation = &"ButtonPrimary"
	rematch_button.custom_minimum_size.y = ACTION_HEIGHT
	rematch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rematch_button.pressed.connect(rematch)
	row.add_child(rematch_button)
	var menu := Button.new()
	menu.name = "MenuButton"
	menu.theme_type_variation = &"ButtonSecondary"
	menu.custom_minimum_size.y = ACTION_HEIGHT
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(go_to_menu)
	row.add_child(menu)
	return row


func _register_focus() -> void:
	_shell.add_focus("RematchButton", _control("RematchButton"), "rematch", {"kind": "button"})
	_shell.add_focus("MenuButton", _control("MenuButton"), "to-menu", {"kind": "button"})


func focus_controls() -> Array:
	_ensure()
	return _shell.focus_controls()


func focus_id(suffix: String) -> String:
	_ensure()
	return _shell.focus_id(suffix)


func _control(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control


func _control_from(parent: Node, node_name: String) -> Control:
	return parent.find_child(node_name, true, false) as Control


# ---------------------------------------------------------------------------
# What the audit reads back (the screen, not the function it is checking)
# ---------------------------------------------------------------------------

func shown_score() -> Array:
	return [(_control("ScorePlayer") as Label).text, (_control("ScoreAi") as Label).text]


func shown_stat_row(index: int) -> Dictionary:
	return {
		"player": (_control("StatPlayer%d" % index) as Label).text,
		"label": (_control("StatLabel%d" % index) as Label).text,
		"opponent": (_control("StatAi%d" % index) as Label).text,
	}


func shown_foot() -> Array:
	return [(_control("StatLongest") as Label).text, (_control("StatAvg") as Label).text]


func shown_objectives() -> Array:
	var block := _control("Objectives") as Control
	var out: Array = []
	for child in block.get_children():
		var line := child as Control
		if line.name == "ObjectivesHead":
			out.append({"head": (line as Label).text})
			continue
		var prefix := "Obj" if String(line.name).begins_with("ObjRow") else "Outfit"
		out.append({
			"row": line.name,
			"check": _text_of(line, "%sCheck0" % prefix) if prefix == "Obj" else _text_of(line, "OutfitMark0"),
			"label": _text_of(line, "%sLabel0" % prefix),
			"progress": _text_of(line, "ObjProgress0") if prefix == "Obj" else "",
			"category": _text_of(line, "%sCategory0" % prefix),
		})
	return out


func _text_of(parent: Node, node_name: String) -> String:
	var label := parent.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


func objectives_visible() -> bool:
	return (_control("Objectives") as Control).visible


func shown_title() -> String:
	return (_control("ResultTitle") as Label).text


func shown_message() -> String:
	return (_control("Message") as Label).text


func shown_rematch_label() -> String:
	return (_control("RematchButton") as Button).text


## The coach block, for a caller that has to drive its transport or read its state
## (`godot/tests/ui/result_coach_audit.gd`).
func coach_panel() -> Node:
	_ensure()
	return _coach


## The exercise the coach's last press routed to, or "".
func coach_route() -> String:
	return _coach_drill_id
