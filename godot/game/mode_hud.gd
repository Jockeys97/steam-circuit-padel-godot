## mode_hud.gd — the mode HUD: the panel that tells a drill, a tournament round
## and a career match apart while they are being played.
##
## WHY IT IS A SEPARATE PANEL. `hud.gd` owns the match's own scoreboard — the
## tennis score, the energy bar, the shot feedback, the event log — and every one
## of its panels is asserted to stay inside the frame and to touch no other panel
## (`tests/game_slice_test.gd::_hud_safe_area`). A mode's own facts (the drill's
## phase, target and live score; the tournament round and its bracket; the career
## season, its objective and its live progress) are not that HUD's business, so
## they live in their own panel in the free band of the frame and are asserted the
## same way by the mode section of the same test.
##
## IT DRAWS NOTHING IT INVENTS. Every line comes from `ModeSession.hud()`, which
## reads the ported mode modules (`DrillSession`, `TournamentRules`,
## `CareerProgress`) — the panel is a projection, and a test compares the two.
##
## The panel is anchored to the frame's bottom-right corner and bounded to a
## SAFE_MARGIN inset, in the one band no other HUD panel occupies at either
## 1280x720 or 1152x648.
##
## TRAINING'S THREE ACTIONS. A finished training run is the one thing this panel does not
## only REPORT: the model carries three actions (retry / change exercise / exit), and they are
## real Buttons in the panel — mouse-clickable, and reachable by the pad and the keyboard
## through the controller's own input (A retries, B changes exercise, ESC exits). The panel
## emits one signal per action and the match controller owns what each one does.
extends Control

const Locale := preload("res://src/locale/locale.gd")
const DrillText := preload("res://src/modes/drill_text.gd")

## What the player asked for from a finished training run's summary.
signal training_retry_requested
signal training_choose_requested
signal training_exit_requested

const SAFE_MARGIN := 8.0
## The panel's width and the offset from the frame's bottom-right corner. Drawn
## from the free band: the log panel ends at x = 432 and the feedback panel spans
## x 442..774 at 1152 px, while this panel starts at 1152 - 388 = 764... which is
## why the width is what it is and the test measures both frames instead of
## trusting this sentence.
const PANEL_WIDTH := 356.0
const PANEL_OFFSET := Vector2(-364.0, -268.0)

var _panel: PanelContainer
var _title: Label
var _phase: Label
var _lines: Array[Label] = []
var _metrics: Label
## The summary's three actions, shown only while a finished training run is on.
var _actions: HBoxContainer
var _action_buttons: Dictionary = {}
var _session = null
var _last: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Behind the match HUD's own panels: this is an information panel, and the
	# scoreboard must stay the first thing a player reads.
	z_index = -1
	_panel = PanelContainer.new()
	_panel.name = "ModePanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = PANEL_OFFSET.x
	_panel.offset_right = PANEL_OFFSET.x + PANEL_WIDTH
	_panel.offset_top = PANEL_OFFSET.y
	_panel.offset_bottom = PANEL_OFFSET.y + 0.0
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
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.name = "ModeColumn"
	col.add_theme_constant_override("separation", 3)
	_panel.add_child(col)
	_title = _label("", 20, Color(1.0, 0.898, 0.16), false)
	col.add_child(_title)
	_phase = _label("", 16, Color(1.0, 0.821, 0.4), false)
	col.add_child(_phase)
	for i in 5:
		var l := _label("", 15, Color(0.88, 0.92, 0.96))
		l.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 0.0)
		col.add_child(l)
		_lines.append(l)
	_metrics = _label("", 15, Color(0.72, 0.78, 0.86))
	_metrics.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 0.0)
	col.add_child(_metrics)
	_actions = HBoxContainer.new()
	_actions.name = "ModeActions"
	_actions.add_theme_constant_override("separation", 6)
	col.add_child(_actions)
	for row in [["retry", "training_retry_requested"], ["choose", "training_choose_requested"], ["exit", "training_exit_requested"]]:
		var button := Button.new()
		button.name = "Action_%s" % String(row[0])
		button.text = DrillText.t("drillAction%s" % String(row[0]).capitalize())
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for style_name in ["normal", "hover", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("10374d") if style_name == "normal" else Color("11667b")
			style.border_color = Color("13d2e9")
			style.set_border_width_all(2 if style_name == "focus" else 1)
			style.set_corner_radius_all(8)
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			button.add_theme_stylebox_override(style_name, style)
		button.pressed.connect(_emit_action.bind(String(row[0])))
		_actions.add_child(button)
		_action_buttons[String(row[0])] = button
	var ordered := _action_buttons.values()
	for i in ordered.size():
		var button: Button = ordered[i]
		button.focus_neighbor_left = button.get_path_to(ordered[(i + 2) % 3])
		button.focus_neighbor_right = button.get_path_to(ordered[(i + 1) % 3])
		button.focus_neighbor_top = button.focus_neighbor_left
		button.focus_neighbor_bottom = button.focus_neighbor_right
	_actions.visible = false
	_panel.visible = false


func _emit_action(action: String) -> void:
	match action:
		"retry":
			training_retry_requested.emit()
		"choose":
			training_choose_requested.emit()
		"exit":
			training_exit_requested.emit()


func _label(text: String, size: int, color: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Binds the session this HUD reports. Null hides the panel: a quick match has no
## mode HUD at all, which is what keeps this a mode-only overlay.
func bind_session(session) -> void:
	_session = session
	refresh()


## Reads the session's own model and writes it in place — never a rebuild, so the
## panel's rectangle is stable across the whole match.
func refresh() -> void:
	if _panel == null:
		return
	if _session == null:
		_panel.visible = false
		return
	_last = _session.hud()
	var summary_up := String(_last.get("phase", "")) == "summary"
	if _session.mode == "drill":
		var panel_style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
		panel_style.bg_color = Color(0.035, 0.055, 0.14, 0.98)
		panel_style.border_color = Color("17677d")
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(16)
		_title.add_theme_color_override("font_color", Color("14d4e8"))
		z_index = 10 if summary_up else 1
		_panel.anchor_left = 0.5 if summary_up else 1.0
		_panel.anchor_right = _panel.anchor_left
		_panel.anchor_top = 0.5 if summary_up else 1.0
		_panel.anchor_bottom = _panel.anchor_top
		_panel.offset_left = -310.0 if summary_up else -408.0
		_panel.offset_right = 310.0 if summary_up else -8.0
		_panel.offset_top = -120.0 if summary_up else -355.0
		_panel.offset_bottom = 120.0 if summary_up else -78.0
	_panel.visible = true
	_title.text = "%s  ·  %s" % [String(_last.get("title", "")), _build_label()]
	_phase.text = "FASE %s%s" % [
		String(_last.get("phase", "")).to_upper(),
		"  ·  FINITA" if bool(_session.finished) else "",
	]
	if _session.mode == "drill":
		_title.text = DrillText.exercise_name(String(_last.get("exercise", "")))
		_phase.text = DrillText.t("drillHudSummary", {"hits": _session.drill.hits, "attempts": _session.drill.attempts, "accuracy": int(round(_session.drill.summary()["accuracy"] * 100)), "score": _session.drill.score, "best": _session.training_best}) if summary_up else String(_last.get("progress", ""))
	var lines: Array = _last.get("lines", [])
	if summary_up and _session.mode == "drill":
		lines = [lines[0], lines[2]] if lines.size() >= 3 else lines
	for i in _lines.size():
		_lines[i].text = String(lines[i]) if i < lines.size() else ""
		_lines[i].visible = i < lines.size()
	# The drill's finished run carries its own three actions (`shell` in the model). They
	# take the metric row while the run is over — the chips' four numbers are the summary's
	# own line already — so nothing is added to the panel and nothing grows its rectangle.
	var actions := String(_last.get("actions", ""))
	var metrics: Array = _last.get("metrics", [])
	var parts: Array = []
	for metric in metrics:
		parts.append("%s %s" % [metric_name(String((metric as Dictionary).get("key", ""))),
			String((metric as Dictionary).get("value", ""))])
	if actions != "":
		_metrics.text = actions
	elif parts.size() > 0:
		_metrics.text = "  ·  ".join(parts)
	else:
		_metrics.text = ""
	# The finished run's THREE ACTIONS are the only interactive controls this panel owns, and
	# they exist only while that run's summary does. Mouse reaches them directly; the pad and
	# the keyboard reach them through the controller's own input.
	if _actions != null:
		var was_visible := _actions.visible
		_actions.visible = String(_last.get("phase", "")) == "summary"
		if _actions.visible and not was_visible:
			_action_buttons["retry"].grab_focus()


func activate_training_action() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	for button in _action_buttons.values():
		if focused == button:
			button.emit_signal("pressed")
			return
	training_retry_requested.emit()


func _build_label() -> String:
	return "DEMO" if _session != null and bool(_session.demo) else "FULL"


## The reference's own labels for the four drill metrics (`js/i18n.js`: `drillScore`,
## `drillBest`, `drillHits`, `drillIn`, `drillStreak`, `drillBestRally`,
## `drillEnergy`, `drillDoubleFaults`) resolved through the locale layer, so the
## drill HUD is in the same language as the rest of the interface. The fallback is
## the key's tail, never an English word this file made up.
static func metric_name(key: String) -> String:
	if key == "":
		return ""
	if Locale.is_resolvable(key):
		return Locale.t(key)
	return key


## The panel, for a test that measures it against the match HUD's own panels.
func panel() -> PanelContainer:
	return _panel


## What this HUD is showing, as data.
func report() -> Dictionary:
	return {
		"title": _title.text if _title != null else "",
		"phase": _phase.text if _phase != null else "",
		"lines": _lines.map(func(l): return (l as Label).text),
		"metrics": _metrics.text if _metrics != null else "",
		"visible": _panel.visible if _panel != null else false,
		"model": _last,
	}
