## hud.gd — the in-match HUD: tennis score, remaining rally energy, shot feedback,
## the point/event log and the match result.
##
## Godot Control nodes only, built once in `_ready()` and updated in place. No
## fullscreen table swap, no per-frame node churn: the project treats a
## rejected-UI screenshot as a P0 regression, so every panel is a fixed-size
## anchored panel with a readable theme font size, and every long string
## autowraps inside a bounded width instead of pushing the layout wider.
##
## TEXT — WHERE IT COMES FROM
##   Every player-visible line built from a simulation message id goes through the
##   verified locale layer (`res://src/locale/locale.gd`, the port of the frozen
##   `js/i18n.js`; contract: `docs/wayfinder/evidence/i18n-port-contract.md`):
##
##       t(key) = <requested locale> ?? it ?? <the id itself>   (js/i18n.js:1408)
##
##   That last step is the bug class this file must not reproduce: an id on screen
##   is what "AI_LEGGENDA_NAME" looked like for a whole match (git 1652240). So:
##
##     - `describe_event()` calls `Locale.t()` first and returns the sentence;
##     - an id the locale layer cannot resolve, or one whose template still needs
##       parameters the simulation does not carry (`serveHint`), falls back to the
##       readable line in `EVENT_LABELS` — never to the id;
##     - an id in neither place renders `UNREADABLE`, which is visibly wrong on
##       purpose rather than silently an id. `tools/i18n-port/verify-i18n-port.mjs`
##       fails before that can happen: a new emit site nobody wrote down is a red
##       drift test, not a surprise on screen.
##
##   `EVENT_LABELS` is GENERATED below from `godot/src/locale/locale_data.gd` by
##   `godot/game/tools/gen_hud_labels.py` — it is a projection of the locale layer,
##   not a second string table — plus one hand-written readable fallback per
##   debt-ledger id (`tools/i18n-port/unresolved-baseline.json`, ten entries, three
##   documented root causes). It is generated because `tools/i18n-port/hud-coverage.mjs`
##   reads this table statically to decide whether an id can reach the screen, so the
##   table has to be complete for every id the ported simulation can emit. The slice
##   test asserts each generated entry is byte-equal to `Locale.t(id)`, so the table
##   cannot drift from the resolver.
##
##   Labels that are NOT message ids stay in this file and are marked as such: the
##   score words, the energy bar's caption, the control legend. Where the reference
##   has a key for one of them it is used (`chronicle`, `pause`).
##
## TEXT SOURCES (nothing invented):
##   - score: `state.playerScore` / `state.aiScore` / `games` / `sets` /
##     `tieBreak` / `tieBreakPoints`, exactly the fields the sim's own
##     `sync_point_display` maintains;
##   - feedback: `state.shotFeedback.text` = `shot:<grade>` and
##     `state.shotFeedback.mode` = `shotMode:<mode>` (sim.gd:1245-1246), rendered
##     the way the reference renders them: `t("shot" + Grade)` /
##     `t("shotMode" + Mode)` (`js/game.js:1062-1069`);
##   - energy: `state.rallyEnergy["player"]` (`GAMEPLAY_RULES.md:150`);
##   - log: `state.events`, the newest-first message-id ring `add_event` fills.
extends Control

const Locale := preload("res://src/locale/locale.gd")

## UIR-22: this HUD no longer picks a language. It used to force Italian here
## (`const HUD_LANG := "it"` + `Locale.set_lang(HUD_LANG)` in `_ready()`), which
## silently overrode the language the player chose in the settings screen the moment
## a match built its HUD — two languages in one build, and the menu's own choice lost.
## The match HUD now follows the same `Locale` current language the menus resolve
## through (`Locale.current_lang()`, set once at boot from the stored `lang` pref and
## by the settings screen on a change). The ported HUD's own literal labels stay
## literal: they are its diagnostic surface's, not a second locale layer.

## Rendered when an id is neither resolvable nor in `EVENT_LABELS`. Deliberately not
## the id: a visible "??" is a defect report, an id on screen is a silent one.
const UNREADABLE := "??"

## The safe area: no HUD element may come closer than this to the frame's edge.
## The defect this answers: a yellow arc read as a clipped gauge at the left edge
## of the frame (that one turned out to be arena scenery, not a Control — see
## `docs/wayfinder/evidence/quick-match-playable.md`), and a HUD that trusted its
## own hard-coded offsets at any window size. Every panel is bounded to this
## margin both when it is built and again on every viewport resize, and the slice
## test asserts the same property at 1280x720 and 1152x648.
const SAFE_MARGIN := 8.0

var _player_name: Label
var _ai_name: Label
var _player_score: Label
var _ai_score: Label
var _sets_line: Label
var _games_line: Label
var _state_line: Label
var _feedback: Label
var _feedback_mode: Label
var _energy_fill: ColorRect
var _energy_label: Label
var _log_lines: Array[Label] = []
var _debug: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_detail: Label
var _hint: Label
var _hint_paused := false
## Every panel this HUD built. The safe-area pass walks exactly these.
var _panels: Array[PanelContainer] = []

## HUD chrome, not message ids: colours of the two sides, and the two positions the
## sim's `activePlayerKey` can take (the reference labels the controlled athlete by
## roster name; the energy bar names the *position*, which has no reference key).
var _player_color := Color(0.0, 0.898, 1.0)
var _ai_color := Color(1.0, 0.294, 0.431)
const POSITION_LABELS := {
	"player": "TU",
	"playerMate": "COMPAGNO",
}
const HINT_PLAY := "WASD/frecce muoviti · SPAZIO carica e rilascia (drive) · META slice · ALT speciale · TAB/Z cambia · ESC pausa"
const HINT_PAD := "A drive · X slice · Y lob\nB speciale · RB tecnico\nLS muovi / mira · RS/LB cambia\nLT split-step · RT sprint\nD-pad tattica · START pausa"
const HINT_PAD_DETAILS := "RB+A chiquita · RB+X vibora · RB+Y lob difensivo\nDoppio A/X/Y: smash / volée / globo quando pronti"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_scoreboard()
	_build_feedback()
	_build_log()
	_build_debug()
	_build_result()
	apply_safe_area()
	# A window can be resized (or start at another size): re-bound the layout, do
	# not trust the offsets as built. `get_viewport()` is null only before the HUD
	# enters the tree, which is where `_ready` runs.
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(apply_safe_area)


## One panel's rectangle, from its anchors, its offsets and its own minimum size —
## the same arithmetic the layout uses, so a panel whose height is "auto"
## (`offset_bottom == offset_top`) is measured at its real height rather than zero.
static func panel_rect(panel: Control, frame: Vector2) -> Rect2:
	var minimum := panel.get_combined_minimum_size()
	var left := panel.anchor_left * frame.x + panel.offset_left
	var top := panel.anchor_top * frame.y + panel.offset_top
	var right := panel.anchor_right * frame.x + panel.offset_right
	var bottom := panel.anchor_bottom * frame.y + panel.offset_bottom
	return Rect2(left, top, maxf(right - left, minimum.x), maxf(bottom - top, minimum.y))


## Moves every panel back inside the safe area of the current frame.
func apply_safe_area() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	for panel in _panels:
		# A frame smaller than the panel cannot hold it: moving the panel would only
		# place it somewhere wrong (in the headless harness the viewport is 64x64, and
		# clamping into it pushed the layout off the real frame). Skip, do not guess.
		var minimum := panel.get_combined_minimum_size()
		if minimum.x > vp.x - 2.0 * SAFE_MARGIN or minimum.y > vp.y - 2.0 * SAFE_MARGIN:
			continue
		bound_panel(panel, vp)


## Bounds one panel: shifted, never resized. Offsets are what the layout reads, so
## shifting them is the one change that cannot fight the containers inside.
func bound_panel(panel: Control, frame: Vector2) -> void:
	var rect := panel_rect(panel, frame)
	var dx := 0.0
	var dy := 0.0
	if rect.position.x < SAFE_MARGIN:
		dx = SAFE_MARGIN - rect.position.x
	elif rect.end.x > frame.x - SAFE_MARGIN:
		dx = (frame.x - SAFE_MARGIN) - rect.end.x
	if rect.position.y < SAFE_MARGIN:
		dy = SAFE_MARGIN - rect.position.y
	elif rect.end.y > frame.y - SAFE_MARGIN:
		dy = (frame.y - SAFE_MARGIN) - rect.end.y
	if dx != 0.0:
		panel.offset_left += dx
		panel.offset_right += dx
	if dy != 0.0:
		panel.offset_top += dy
		panel.offset_bottom += dy


## The panels the safe-area pass owns, for the tests and the tools.
func panels() -> Array[PanelContainer]:
	return _panels


# ---------------------------------------------------------------------------
# Node construction
# ---------------------------------------------------------------------------

func _panel(anchor: Vector2, offset: Vector2, size: Vector2, panel_name := "") -> PanelContainer:
	var p := PanelContainer.new()
	if panel_name != "":
		p.name = panel_name
	p.anchor_left = anchor.x
	p.anchor_right = anchor.x
	p.anchor_top = anchor.y
	p.anchor_bottom = anchor.y
	p.offset_left = offset.x
	p.offset_top = offset.y
	p.offset_right = offset.x + size.x
	p.offset_bottom = offset.y + size.y
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.78)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	_panels.append(p)
	return p


func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_scoreboard() -> void:
	# Anchored centre: the panel spans x 280..1000 and the top-left debug panel
	# spans x 12..276, so the two can never touch (the defect this replaced: the
	# debug line ran under the athlete name).
	var panel := _panel(Vector2(0.5, 0.0), Vector2(-360.0, 10.0), Vector2(720.0, 0.0), "ScorePanel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230.0, 0.0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	_player_name = _label("—", 22, _player_color, HORIZONTAL_ALIGNMENT_LEFT, false)
	left.add_child(_player_name)
	_player_score = _label("0", 54, _player_color, HORIZONTAL_ALIGNMENT_LEFT, false)
	left.add_child(_player_score)

	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(200.0, 0.0)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	# Score line: the numbers are the sim's, the two words are HUD chrome.
	_sets_line = _label("SET 0-0", 20, Color(0.93, 0.95, 0.98), HORIZONTAL_ALIGNMENT_CENTER, false)
	mid.add_child(_sets_line)
	_games_line = _label("GAME 0-0", 20, Color(0.93, 0.95, 0.98), HORIZONTAL_ALIGNMENT_CENTER, false)
	mid.add_child(_games_line)
	_state_line = _label("", 18, Color(1.0, 0.821, 0.4), HORIZONTAL_ALIGNMENT_CENTER, false)
	mid.add_child(_state_line)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(230.0, 0.0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	_ai_name = _label("—", 22, _ai_color, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_ai_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_ai_name)
	_ai_score = _label("0", 54, _ai_color, HORIZONTAL_ALIGNMENT_RIGHT, false)
	right.add_child(_ai_score)


func _build_feedback() -> void:
	# 268 wide, not 600: the frame's bottom band also holds the log panel on the
	# left, and the two overlapped at 1152 px (the assertion in
	# `tests/game_slice_test.gd` is what caught it). The energy label now sits above
	# its bar instead of beside it, which is where the width went.
	var panel := _panel(Vector2(1.0, 1.0), Vector2(-280.0, -190.0), Vector2(268.0, 0.0), "FeedbackPanel")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	_feedback = _label("", 40, Color(0.93, 0.95, 0.98), HORIZONTAL_ALIGNMENT_CENTER, false)
	col.add_child(_feedback)
	_feedback_mode = _label("", 22, Color(0.72, 0.78, 0.86), HORIZONTAL_ALIGNMENT_CENTER, false)
	col.add_child(_feedback_mode)

	var energy_row := VBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 6)
	col.add_child(energy_row)
	# No reference key exists for the energy bar ("energy" is not in js/i18n.js);
	# HUD chrome, like the control legend.
	_energy_label = _label("ENERGIA", 18, Color(0.72, 0.78, 0.86), HORIZONTAL_ALIGNMENT_LEFT, false)
	_energy_label.custom_minimum_size = Vector2(0.0, 0.0)
	energy_row.add_child(_energy_label)

	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(240.0, 18.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.20, 0.26, 0.95)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	bar_bg.add_theme_stylebox_override("panel", sb)
	energy_row.add_child(bar_bg)

	var bar_clip := Control.new()
	bar_clip.clip_contents = true
	bar_clip.custom_minimum_size = Vector2(240.0, 18.0)
	bar_bg.add_child(bar_clip)
	_energy_fill = ColorRect.new()
	_energy_fill.color = Color(0.0, 0.898, 1.0)
	_energy_fill.anchor_top = 0.0
	_energy_fill.anchor_bottom = 1.0
	_energy_fill.anchor_left = 0.0
	_energy_fill.anchor_right = 1.0
	_energy_fill.offset_right = 0.0
	bar_clip.add_child(_energy_fill)


func _build_log() -> void:
	var panel := _panel(Vector2(0.0, 1.0), Vector2(12.0, -182.0), Vector2(250.0, 170.0), "LogPanel")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var title := _label(Locale.t("chronicle"), 18, Color(1.0, 0.821, 0.4), HORIZONTAL_ALIGNMENT_LEFT, false)
	col.add_child(title)
	for i in 5:
		var l := _label("", 14, Color(0.86, 0.90, 0.95))
		l.custom_minimum_size = Vector2(226.0, 0.0)
		col.add_child(l)
		_log_lines.append(l)


func _build_debug() -> void:
	# Bounded so it can never reach the scoreboard: the debug panel ends at x = 208
	# and the scoreboard starts at `W/2 - 360` = 216 even at Godot's default 1152 px
	# window (the captures are 1280). The line wraps instead of growing — the frame
	# is the constraint, not the text. The defect this replaced: the panel was 330 px
	# wide and ran under the athlete name in the scoreboard.
	var panel := _panel(Vector2(0.0, 0.0), Vector2(12.0, 10.0), Vector2(196.0, 0.0), "DebugPanel")
	_debug = _label("", 16, Color(0.66, 0.72, 0.80))
	_debug.custom_minimum_size = Vector2(172.0, 0.0)
	panel.add_child(_debug)

	# The control legend sits in the free strip to the right of the centre (below the
	# scoreboard, right of the result panel), not in the bottom band: three panels in
	# one band overlap at 1152 px, which is the overlap the safe-area assertion in
	# `tests/game_slice_test.gd` catches.
	var hint_panel := _panel(Vector2(1.0, 0.0), Vector2(-272.0, 148.0), Vector2(260.0, 88.0), "HintPanel")
	_hint = _label(HINT_PLAY, 15, Color(0.70, 0.76, 0.84))
	_hint.custom_minimum_size = Vector2(236.0, 0.0)
	hint_panel.add_child(_hint)


func _build_result() -> void:
	_result_panel = _panel(Vector2(0.5, 0.5), Vector2(-280.0, -110.0), Vector2(560.0, 220.0), "ResultPanel")
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_result_panel.add_child(col)
	_result_title = _label("", 46, Color(1.0, 0.898, 0.16), HORIZONTAL_ALIGNMENT_CENTER, false)
	col.add_child(_result_title)
	_result_detail = _label("", 22, Color(0.90, 0.93, 0.97), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_result_detail)
	var keys := _label("R nuova partita · ESC menu", 20, Color(0.72, 0.78, 0.86), HORIZONTAL_ALIGNMENT_CENTER, false)
	col.add_child(keys)
	_result_panel.visible = false


# ---------------------------------------------------------------------------
# Updates (called in place; never rebuilds the tree)
# ---------------------------------------------------------------------------

func bind_names(player_name: String, ai_name: String, player_color: Color, ai_color: Color) -> void:
	_player_color = player_color
	_ai_color = ai_color
	_player_name.text = player_name
	_player_name.add_theme_color_override("font_color", player_color)
	_player_score.add_theme_color_override("font_color", player_color)
	_ai_name.text = ai_name
	_ai_name.add_theme_color_override("font_color", ai_color)
	_ai_score.add_theme_color_override("font_color", ai_color)


func refresh(state, meta: Dictionary) -> void:
	set_paused(_hint_paused)
	_player_score.text = String(state.playerScore)
	_ai_score.text = String(state.aiScore)
	var set_scores: Array = state.setScores
	var set_line := "SET 0-0"
	if set_scores.size() > 0:
		var last: Dictionary = set_scores[set_scores.size() - 1]
		set_line = "SET %d-%d" % [int(last["player"]), int(last["ai"])]
	_sets_line.text = "%s  ·  VINTI %d-%d" % [set_line, int(state.sets["player"]), int(state.sets["ai"])]
	_games_line.text = "GAME %d-%d" % [int(state.games["player"]), int(state.games["ai"])]
	if state.tieBreak:
		_state_line.text = "TIE-BREAK %d-%d" % [int(state.tieBreakPoints["player"]), int(state.tieBreakPoints["ai"])]
	elif state.serving:
		_state_line.text = "SERVIZIO: %s" % ("TU" if state.serveSide == "player" else "CIRCUITO")
	elif state.serveAttempts > 0:
		_state_line.text = "SECONDA DI SERVIZIO"
	else:
		_state_line.text = "RALLY %d colpi" % int(state.rallyHits)

	_update_feedback(state)
	_update_energy(state)
	_update_log(state)

	_debug.text = "SEED %d · TIER %s · TICK %d · RNG %d · %s" % [
		int(meta.get("seed", 0)),
		String(meta.get("tier", "?")),
		int(meta.get("tick", 0)),
		int(state.rng_calls),
		String(meta.get("camera", "default")),
	]

	if state.result != null:
		show_result(state)


func _update_feedback(state) -> void:
	var fb: Variant = state.shotFeedback
	if fb == null:
		_feedback.text = ""
		_feedback_mode.text = ""
		return
	var text_id := String(fb.get("text", ""))
	var mode_id := String(fb.get("mode", ""))
	var grade := grade_of(text_id)
	var mode := mode_of(mode_id)
	_feedback.text = feedback_label(text_id)
	_feedback_mode.text = mode_label(mode_id)
	var color: Color = GRADE_COLORS.get(grade, Color(0.93, 0.95, 0.98))
	_feedback.add_theme_color_override("font_color", color)


func _update_energy(state) -> void:
	var key := String(state.activePlayerKey)
	var energy := float(state.rallyEnergy.get("player", 1.0))
	var whose: String = POSITION_LABELS.get(key, key)
	_energy_label.text = "ENERGIA — %s" % whose
	var width := 300.0 * clampf(energy, 0.0, 1.0)
	_energy_fill.offset_left = 0.0
	_energy_fill.offset_right = width - 300.0
	var c := Color(0.0, 0.898, 1.0)
	if energy < 0.3:
		c = Color(1.0, 0.294, 0.431)
	elif energy < 0.6:
		c = Color(1.0, 0.821, 0.4)
	_energy_fill.color = c


## The three bands and the three colours of the energy bar the REFERENCE draws: it
## has no energy bar in its HUD at all. `js/main.js:1916` hands
## `state.rallyEnergy.player` to `drawActiveIndicator`, which draws the bar on the
## court, under the active athlete (`js/render.js:1031-1037`), and the ported match
## controller draws that one from these values. The panel bar above keeps its own
## (opaque) bands: it is the port's addition, and changing its colours would change
## a screenshot the review has already read.
const FIELD_ENERGY_TEAL := Color(0.337, 0.910, 0.847)   # #56e8d8, energy > 0.55
const FIELD_ENERGY_AMBER := Color(1.0, 0.831, 0.361)    # #ffd45c, energy > 0.3
const FIELD_ENERGY_RED := Color(1.0, 0.420, 0.392)      # #ff6b64, below


## `energy > 0.55 ? "#56e8d8" : energy > 0.3 ? "#ffd45c" : "#ff6b64"`
## (`js/render.js:1036`).
static func field_energy_color(energy: float) -> Color:
	if energy > 0.55:
		return FIELD_ENERGY_TEAL
	if energy > 0.3:
		return FIELD_ENERGY_AMBER
	return FIELD_ENERGY_RED


## The precision bar's fill (`js/render.js:1709-1717`): cyan while the angle is not
## armed, amber — reddening with `tight` — and pulsing once it is. `armed` is
## `tight > 0.02`, the reference's own threshold; `pulse` is the caller's clock
## (the reference blinks it at `time * 16`, `js/render.js:1711`).
const PRECISION_CYAN := Color(0.494, 0.953, 1.0, 0.75)  # rgba(126,243,255,0.75)


static func precision_color(tight: float, pulse: float) -> Color:
	if tight > 0.02:
		var level := clampf(tight, 0.0, 1.0)
		return Color(1.0, (190.0 - level * 120.0) / 255.0, 70.0 / 255.0, clampf(pulse, 0.0, 1.0))
	return PRECISION_CYAN


## The five most recent events, newest first, resolved to sentences.
##
## One rendering rule: an event whose line is identical to the line above it is
## not shown a second time. The simulation emits `controlMsg:roleBackPos` on every
## switch back to that role (sim.gd:557-566), so the ring can hold the same id
## twice in a row; once resolved, that is two identical sentences telling the
## player nothing, and the defect report for this slice named it. `state.events`
## is not touched — this is display only.
func _update_log(state) -> void:
	var events: Array = state.events
	var shown := 0
	var previous := ""
	for i in events.size():
		if shown >= _log_lines.size():
			break
		var line := describe_event(String(events[i]))
		if line == previous:
			continue
		_log_lines[shown].text = "· " + line
		previous = line
		shown += 1
	while shown < _log_lines.size():
		_log_lines[shown].text = ""
		shown += 1


func show_result(state) -> void:
	if _result_panel.visible:
		return
	var winner := String(state.result["winner"])
	_result_title.text = "VITTORIA" if winner == "player" else "SCONFITTA"
	_result_title.add_theme_color_override(
		"font_color",
		Color(1.0, 0.898, 0.16) if winner == "player" else Color(1.0, 0.294, 0.431)
	)
	var sets_player := int(state.sets["player"])
	var sets_ai := int(state.sets["ai"])
	var longest := int(state.stats.get("longestRally", 0))
	_result_detail.text = "Set %d-%d · punti vinti %d-%d · rally più lungo %d colpi" % [
		sets_player,
		sets_ai,
		int(state.stats["pointsWon"]["player"]),
		int(state.stats["pointsWon"]["ai"]),
		longest,
	]
	_result_panel.visible = true


func set_paused(paused: bool) -> void:
	_hint_paused = paused
	var has_pad := not Input.get_connected_joypads().is_empty()
	_hint.text = (HINT_PAD if has_pad else HINT_PLAY)
	if paused:
		_hint.text = "%s — ESC / START\n%s\n%s" % [Locale.t("pause"), _hint.text, HINT_PAD_DETAILS if has_pad else ""]


# ---------------------------------------------------------------------------
# Message ids -> readable lines
# ---------------------------------------------------------------------------

## Shot grades the simulation stores as `shot:<grade>` (sim.gd:1245), plus the two
## bare ids it stores instead of a grade (`smashMissedContact`, sim.gd:2590). The
## colour of the feedback line is keyed by the grade, not by the resolved sentence.
const GRADE_COLORS := {
	"perfect": Color(0.42, 0.98, 0.55),
	"good": Color(0.62, 0.88, 1.0),
	"early": Color(1.0, 0.821, 0.4),
	"late": Color(1.0, 0.294, 0.431),
	"smashMissedContact": Color(1.0, 0.294, 0.431),
}


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
static func feedback_label(text_id: String) -> String:
	var key := text_id
	if text_id.begins_with("shot:"):
		key = "shot" + text_id.substr(5).capitalize()
	return resolve_or(key, grade_of(text_id).to_upper())


## `js/game.js:1069` — `t("shotMode" + CapitalizedMode)`.
static func mode_label(mode_id: String) -> String:
	var key := mode_id
	if mode_id.begins_with("shotMode:"):
		key = "shotMode" + mode_id.substr(9).capitalize()
	return resolve_or(key, mode_of(mode_id))


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


static func field_grade_color(grade: String) -> Color:
	return FIELD_GRADE_COLORS.get(grade, Color(1.0, 1.0, 1.0))


## The tactical advice word the reference draws over the active athlete,
## `t("shotAdvice_" + state.shotRead.advice).toUpperCase()` (`js/render.js:1730`).
## Resolved here, where the locale layer is, and never as the id: an id on screen is
## the defect class this file exists to prevent. The upper case is the reference's
## own (`js/render.js:1730`).
static func advice_word(advice: String) -> String:
	return resolve_or("shotAdvice_%s" % advice, advice.to_upper()).to_upper()


## The word's colour, by shot profile: `#ffd46a` aggressive, `#8fffd0` otherwise
## (`js/render.js:1745`) — the reference's exact two-value rule, aggressive checked
## first, everything else (including "control") on the second.
const ADVICE_AGGRESSIVE := Color(1.0, 0.831, 0.416)  # #ffd46a
const ADVICE_CONTROL := Color(0.561, 1.0, 0.816)     # #8fffd0


static func advice_color(profile: String) -> Color:
	return ADVICE_AGGRESSIVE if profile == "aggressive" else ADVICE_CONTROL


## The word drawn when the simulation carries no advice at all: the reference's
## `state.shotRead?.advice ?? "read"` (`js/render.js:1730`).
static func advice_of(read: Dictionary) -> String:
	return String(read.get("advice", "read"))


## The resolver first; the readable fallback only when the resolver would hand back
## the id itself. Never the id.
static func resolve_or(message_id: String, fallback: String) -> String:
	if Locale.is_resolvable(message_id):
		return Locale.t(message_id)
	if fallback != "" and fallback != message_id:
		return fallback
	return UNREADABLE


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


static func reason_label(reason: String) -> String:
	return describe_event(reason)


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
