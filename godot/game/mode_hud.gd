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
extends Control

const Locale := preload("res://src/locale/locale.gd")

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
	_panel.visible = false


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
	_panel.visible = true
	_title.text = "%s  ·  %s" % [String(_last.get("title", "")), _build_label()]
	_phase.text = "FASE %s%s" % [
		String(_last.get("phase", "")).to_upper(),
		"  ·  FINITA" if bool(_session.finished) else "",
	]
	var lines: Array = _last.get("lines", [])
	for i in _lines.size():
		_lines[i].text = String(lines[i]) if i < lines.size() else ""
	var metrics: Array = _last.get("metrics", [])
	var parts: Array = []
	for metric in metrics:
		parts.append("%s %s" % [metric_name(String((metric as Dictionary).get("key", ""))),
			String((metric as Dictionary).get("value", ""))])
	_metrics.text = "  ·  ".join(parts) if parts.size() > 0 else ""


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
