## Hud.gd — UIR-08: the in-match HUD prototype, built from `Hud.tscn`.
##
## WHAT IT IS. The live in-match surface of `index.html:445-535` / `styles.css`:
## scoreboard, game timer, the four `.hud-pause` buttons, serve banner, mini-map,
## the drill/tournament/career mode strip, the match panel (special meter, shot
## meter, the seat for the control legend) and the event log. It paints and it
## emits; it does not simulate, decide, or store game state.
##
## RULES THIS FILE KEEPS
##
##   - **Variations, never colours.** Every node takes its font, size and box from a
##     UIR-02 type variation (`theme_type_variation`) — `HudPanel`, `HudButton`,
##     `HudButtonActive`, `HudPauseCard`, `PanelDark`, `Badge`, `LabelSmall`,
##     `HudLabel`, `HudTitle`, `SegmentedInactive`, `SegmentedActive`. There is no
##     `Color(...)` in this file and no `add_theme_stylebox_override`. The one
##     exception is a *state* colour the reference itself writes at runtime
##     (`js/ui.js:1313-1315` combo ladder, `:1276`… the tactic/intent/advice tones,
##     `js/ui.js:1366` the point banner): those read a **palette entry** through
##     `_palette()` — `theme.get_color(name, "Palette")`, the mechanism
##     `theme/README.md` §4 documents. A palette key that does not exist is recorded
##     in `_palette_misses` instead of being substituted (see `report()`).
##   - **No prose.** Every user-facing string is resolved from the locale seam
##     (`UiStrings`), from `ViewState`, or is the reference's own glyph (`▤`, `🔊`,
##     `⏸`→`Ⅱ`, `🎮`, `☰`, `VS`, `TIMING`, `2/3`). Nothing is written here.
##   - **No fabricated data.** Before the first `refresh()` every field is empty and
##     the meters are hidden: the HUD never shows a plausible-looking default. All
##     values come from the runner's state through `ViewState`.
##   - **It does not own the seam.** The pause button emits `pause_requested`; the
##     mount binds it (`godot/game/match_controller.gd` keeps `_paused`, and no
##     `set_match_paused()` exists yet — UIR-22 introduces it). The match panel's
##     control legend is UIR-13's: this HUD only provides its seat, `control_rows()`.
##   - **Nothing here is mounted.** `Hud.tscn` is instantiable on its own; the router,
##     `Match.tscn` and `godot/game/**` are other owners' files.
##
## INTERIM SEAM. `mode_hud.gd` keeps its own panel until UIR-22 merges the two. The
## mode strip is fed by the mode session's own view dictionary through
## `set_mode_view()` — the same shape `godot/game/mode_session.gd:411-519` returns —
## so the data keeps flowing through the mode owner while the surface moves here.
extends Control

const ViewState := preload("res://src/ui/ViewState.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Frozen := preload("res://src/sim/frozen.gd")
## The scene mounts the same theme; this is the fallback for a bare `new()`.
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

## Emitted on press of the pause button. The overlay is UIR-20's; the pause state is
## the match controller's; this signal is the only thing the HUD has to say about it.
signal pause_requested
## Emitted when the panel button flips the command/meter panel.
signal panel_toggled(open: bool)
## Emitted when the mute button flips; audio itself belongs to the audio lane.
signal mute_toggled(muted: bool)
## Emitted when the event log expands or collapses.
signal log_toggled(expanded: bool)

# ---------------------------------------------------------------------------
# Geometry. Every number is a measured box or a measured inset from
# `evidence/uir-06-computed-styles.json` (the `.scoreboard`, `.game-hud__actions`,
# `.game-timer`, `.mini-map`, `.match-panel`, `.match-feed` entries), kept as
# offsets so the frame can be 1280x720 or the minimum 1152x648.
# ---------------------------------------------------------------------------

const DESIGN_FRAME := Vector2(1280.0, 720.0)
const MIN_FRAME := Vector2(1152.0, 648.0)
const EDGE_LEFT := 32.0
const EDGE_RIGHT := 32.0
const EDGE_TOP := 30.0
## `.scoreboard` measured 413.84 x 95 at (32, 30) inside a 1280x720 canvas
## (`screen_boxes["game"]["children"]` — `.canvas-wrap` is exactly 1280x720).
const SCORE_SIZE := Vector2(414.0, 95.0)
const GAP := 14.0
const MODE_HEIGHT := 96.0
const ACTIONS_HEIGHT := 54.0
const ACTION_BUTTON := Vector2(42.0, 42.0)
## `.game-hud__actions` measured 284.52 x 54, right edge at 1280 - 32. The row is
## `timer + 3 x (margin-left 8 + button 42)` (`styles.css:699-705`; the pad indicator adds
## a fourth `8 + 42` when connected), so the timer is 284.52 - 24 - 126 = 134.52.
const TIMER_SIZE := Vector2(134.52, 54.0)
## `.game-timer` is `display:flex; align-items:center; gap:8px; padding:7px 12px 7px 7px`
## (`styles.css:692-697`) over a 38x38 ball (`styles.css:750-757`, `index.html:462-463`,
## `aria-hidden`), then the two-line time column.
const TIMER_BALL := Vector2(38.0, 38.0)
const TIMER_GAP := 8
const ACTIONS_WIDTH := 284.52
const ACTIONS_SEPARATION := 8
const MINIMAP_EDGE := 16.0
const MINIMAP_TOP := 100.0
## `.mini-map` is `top: 100px; right: 16px; padding: 6px` and its canvas renders at
## 86x122 CSS pixels over a 108x154 drawing buffer (`styles.css:786-805`), so the box
## and the buffer are two different numbers.
const MINIMAP_SIZE := Vector2(108.0, 154.0)
const MINIMAP_BOX := Vector2(86.0, 122.0)
const MINIMAP_PAD := 6.0
const MINIMAP_HEADER := 14.0
const BANNER_TOP := -34.0
const BANNER_BOTTOM := 34.0
const BANNER_LEFT := 0.2
const BANNER_RIGHT := 0.8
## `.match-panel` and the panel-state `.match-feed` both sit at a 16 px inset from the
## screen's own edges (`screen_boxes["game-panel"]`: screen 90..1190, children
## 106..1174); 106 in the raw JSON is page-relative, not screen-relative.
const MATCH_INSET := 16.0
## `.match-feed` in the immersive state is `position: fixed; left: 24px; bottom: 20px`
## (`styles.css:2850-2854`), and `.match-feed__toggle` is 28 px tall.
const FEED_EDGE := 24.0
const FEED_BOTTOM := 20.0
const FEED_TOGGLE_HEIGHT := 28.0
const FEED_GAP := 10.0
const FEED_WIDTH := 320.0
const FEED_LOG_HEIGHT := 120.0
const MATCH_PANEL_HEIGHT := 125.0
const MATCH_PANEL_BOTTOM := MATCH_INSET + FEED_TOGGLE_HEIGHT + FEED_GAP
const METER_WIDTH := 170.0
const SPECIAL_WIDTH := 280.0
const METER_HEIGHT := 10.0
const DRILL_CELLS := 5
const LOG_LINES := 5
const MODE_LINES := 3
const REGION_COUNT := 7
const PAD_INSET := 6
const PANEL_INSET := 10

## `js/ui.js:1322` — the cool-down dim the reference applies to the special fill.
const SPECIAL_DIM_ALPHA := 0.45
## `js/ui.js:1334-1335` — the one metric box the reference paints green.
const STREAK_METRIC_KEY := "drillStreak"
## `js/ui.js:1315` — the combo's own glow: `textShadow = "0 0 10px rgba(255,106,92,0.8)"`
## while `state.combo >= 4`, `"none"` below it. The colour is the palette's `combo_glow`;
## the 10 px blur maps onto the label shadow's outline size (theme README §6).
const COMBO_GLOW_OUTLINE := 10
## `js/ui.js:1309` + `styles.css:678-681` — the tactic chip's flashing state is a class
## swap in the reference (`.scoreboard__tactic.is-flashing`: `#8fffd0` on `#071d34`),
## so here it is a variation swap, never a colour written by this file.
const TACTIC_VARIATION := "SegmentedInactive"
const TACTIC_FLASH_VARIATION := "SegmentedFlash"

## The states UIR-24's capture harness drives, in the ticket's own order.
const CAPTURE_STATES := [
	"default", "serving", "rally", "point-pause", "set-tennis",
	"drill", "tournament", "career", "panel-open",
]

var _frame := DESIGN_FRAME
var _frame_ok := true
var _view: Dictionary = {}
var _mode_view: Dictionary = {}
var _palette_misses: Array = []
var _paused := false
var _muted := false
var _panel_open := false
var _log_expanded := false
var _pad_connected := false

# --- scoreboard
var _score_panel: PanelContainer
var _score_title: Button
var _player_bar: ColorRect
var _ai_bar: ColorRect
var _player_name: Label
var _ai_name: Label
var _player_score: Label
var _ai_score: Label
var _match_info: Button
var _control_label: Button
var _tactic_label: Button
var _combo_label: Button
# --- actions
var _actions_row: HBoxContainer
var _timer_label: Label
var _timer_value: Label
var _panel_button: Button
var _mute_button: Button
var _pad_button: Button
var _pause_button: Button
# --- mode strip
var _mode_panel: PanelContainer
var _mode_title: Label
var _mode_boxes: HBoxContainer
var _drill_cells: Array = []
var _mode_lines: Array = []
var _mode_objective: Label
# --- mini-map
var _minimap_panel: PanelContainer
var _minimap_label: Label
var _minimap: MiniMapCourt
# --- serve banner
var _serve_banner: PanelContainer
var _serve_label: Label
# --- bottom stack
var _match_feed: VBoxContainer
var _match_panel: PanelContainer
var _control_rows: VBoxContainer
var _special_bar: Control
var _special_fill: ColorRect
var _intent_label: Label
var _advice_label: Label
var _power_bar: Control
var _power_fill: ColorRect
var _aim_bar: Control
var _aim_needle: ColorRect
var _timing_bar: Control
var _timing_window: ColorRect
var _timing_needle: ColorRect
var _feed_toggle: Button
var _event_log: VBoxContainer
var _log_labels: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	apply_safe_area()


# ---------------------------------------------------------------------------
# The public contract (the ticket's own list)
# ---------------------------------------------------------------------------

## One state, one meta, one frame of HUD. The view-model decides what the values are;
## this method only paints them. `meta` carries what the runner does not know yet
## (`career_season` — see `ViewState.match_info`).
func refresh(state, meta: Dictionary = {}) -> void:
	_apply_view(ViewState.from_state(state, meta))


## Optional name override for the mount's pre-state frame. A live state's derived name
## always wins (`ViewState.names_for`), because that is what the reference shows.
func bind_names(player_name: String, ai_name: String, player_color = null, ai_color = null) -> void:
	if _view.is_empty():
		_player_name.text = player_name
		_ai_name.text = ai_name
	if player_color != null:
		_player_score.add_theme_color_override("font_color", player_color)
	if ai_color != null:
		_ai_score.add_theme_color_override("font_color", ai_color)


## The pause *state*, as the match owns it. The overlay is UIR-20's; this only makes
## the pause button read as engaged, never pauses anything itself.
func set_paused(paused: bool) -> void:
	_paused = paused
	_pause_button.theme_type_variation = &"HudButtonActive" if paused else &"HudButton"


func is_paused() -> bool:
	return _paused


func set_panel_open(open: bool) -> void:
	_panel_open = open
	_match_panel.visible = open
	_panel_button.theme_type_variation = &"HudButtonActive" if open else &"HudButton"
	_panel_button.set_pressed_no_signal(open)
	# The panel state measures the feed as a 28 px row, i.e. collapsed: the log and the
	# panel share the bottom band, so opening the panel collapses the log.
	if open and _log_expanded:
		_set_log_expanded(false)
	_place_bottom_regions()


func is_panel_open() -> bool:
	return _panel_open


func set_muted(muted: bool) -> void:
	_muted = muted
	_mute_button.text = "🔇" if muted else "🔊"
	_mute_button.tooltip_text = UiStrings.t("muteOff") if muted else UiStrings.t("muteOn")
	_mute_button.theme_type_variation = &"HudButtonActive" if muted else &"HudButton"


## The pad badge is the reference's own `<span hidden>` (`index.html:468`): it shows
## while a controller is connected. Styling it green needs the two pad palette tokens
## the substitution table in the evidence requests from UIR-02.
func set_pad_connected(connected: bool) -> void:
	_pad_connected = connected
	_pad_button.visible = connected


## The interim mode seam: a mode session's own view dictionary
## (`godot/game/mode_session.gd:411-519`). Drill shows its four metric boxes;
## tournament and career show their lines and objective through the same surface.
func set_mode_view(view: Dictionary) -> void:
	_mode_view = view
	_apply_mode()


## The seat for UIR-13's control legend. Empty until that ticket fills it.
func control_rows() -> VBoxContainer:
	return _control_rows


## Safe-area pass. The geometry is anchor-based, so this resolves the frame, records
## whether it is at least the measured minimum, and never nudges a panel into another
## panel's box: `panels()` rectangles are asserted disjoint by the audit at both sizes.
func apply_safe_area(frame: Vector2 = Vector2.ZERO) -> void:
	var resolved := frame
	if resolved.x <= 0.0 or resolved.y <= 0.0:
		var viewport := get_viewport()
		if viewport != null:
			resolved = viewport.get_visible_rect().size
	if resolved.x <= 0.0 or resolved.y <= 0.0:
		resolved = DESIGN_FRAME
	_frame = resolved
	_frame_ok = _frame.x >= MIN_FRAME.x and _frame.y >= MIN_FRAME.y


## The rectangles the integration lane reasons about (UIR-05 focus/safe area, UIR-09
## mount, UIR-19/UIR-20 overlays): the HUD's own top-level regions, in tree order.
## Every region's rect tracks its *content*: the feed's band is 28 px tall while the log
## is collapsed and grows by `FEED_LOG_HEIGHT` when it opens, so a visibility-aware
## overlap check (UIR-19) sees real boxes rather than padded bands.
func panels() -> Array[Control]:
	var out: Array[Control] = []
	out.append(_score_panel)
	out.append(_actions_row)
	out.append(_mode_panel)
	out.append(_minimap_panel)
	out.append(_serve_banner)
	out.append(_match_panel)
	out.append(_match_feed)
	return out


func capture_states() -> Array:
	return CAPTURE_STATES.duplicate()


## Drive one capture state. Returns `true` for the nine states the harness asks for,
## `false` for anything else — never a silent no-op.
func apply_capture_state(state_id: String) -> bool:
	if not CAPTURE_STATES.has(state_id):
		return false
	if state_id == "panel-open":
		_apply_view(ViewState.capture_view("rally"))
		set_mode_view({})
		set_panel_open(true)
		return true
	var view := ViewState.capture_view(state_id)
	if view.is_empty():
		return false
	_apply_view(view)
	if state_id == "drill" or state_id == "tournament" or state_id == "career":
		set_mode_view(view.get("mode_view", {}))
	else:
		set_mode_view({})
	# The reference's default frame is immersive: the command/meter panel is revealed by
	# the panel button (`index.html:466`), so every state except `panel-open` keeps it in.
	set_panel_open(false)
	return true


## What this HUD is showing, as data: the view it last applied, every rendered string,
## the palette keys it could not find, and the surface's own flags. This is what the
## audit reads instead of guessing at node paths.
func report() -> Dictionary:
	return {
		"view": _view.duplicate(true),
		"texts": _texts(),
		"palette_misses": _palette_misses.duplicate(),
		"frame": _frame,
		"frame_ok": _frame_ok,
		"panel_open": _panel_open,
		"log_expanded": _log_expanded,
		"muted": _muted,
		"pad_connected": _pad_connected,
		"paused": _paused,
		"combo_glow": _combo_label.get_theme_color("font_shadow_color").a > 0.0,
		"combo_glow_outline": _combo_label.get_theme_constant("shadow_outline_size"),
		"tactic_variation": String(_tactic_label.theme_type_variation),
		"mode_title": _mode_title.text,
		"mode_visible": _mode_panel.visible,
		"serve_visible": _serve_banner.visible,
		"log_visible": _event_log.visible,
		"special_alpha": _special_fill.modulate.a,
		"panels": panels(),
	}


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build() -> void:
	_build_scoreboard()
	_build_actions()
	_build_mode_strip()
	_build_minimap()
	_build_serve_banner()
	_build_bottom_regions()
	_clear()


func _build_scoreboard() -> void:
	_score_panel = _panel("ScorePanel", "HudPanel")
	_anchor(_score_panel, 0.0, 0.0)
	_offsets(_score_panel, EDGE_LEFT, EDGE_TOP, EDGE_LEFT + SCORE_SIZE.x, EDGE_TOP + SCORE_SIZE.y)
	_score_panel.custom_minimum_size = SCORE_SIZE
	# The strip under this card rides its real bottom, not the measured 95 px.
	_score_panel.resized.connect(_stack_mode_strip)
	_score_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_score_panel.grow_vertical = Control.GROW_DIRECTION_END
	var margin := _margin(_score_panel, PANEL_INSET)
	var column := _vbox(margin, 4)
	_score_title = _chip("ScoreTitle", "SegmentedActive")
	_score_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_score_title)
	var teams := _hbox(column, 8)
	var player_block := _vbox(teams, 0)
	player_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_bar = _color_bar(player_block, "cyan", 3.0)
	_player_name = _label(player_block, "HudLabel")
	_player_score = _label(player_block, "HudTitle")
	_player_score.name = "PlayerScore"
	var versus := _label(teams, "HudLabel")
	versus.text = "VS"
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ai_block := _vbox(teams, 0)
	ai_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_bar = _color_bar(ai_block, "coral", 3.0)
	_ai_name = _label(ai_block, "HudLabel")
	_ai_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ai_score = _label(ai_block, "HudTitle")
	_ai_score.name = "AiScore"
	_ai_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# `.scoreboard__teams div:last-child strong { color: var(--coral) }` (`styles.css:625-627`):
	# the right-hand score is coral, not the `.game-hud strong` cyan the variation carries.
	_ai_score.add_theme_color_override("font_color", _palette("coral"))
	var meta := _grid(column, 2, 4)
	_match_info = _chip("MatchInfo", "SegmentedInactive")
	_control_label = _chip("ControlLabel", "SegmentedInactive")
	_tactic_label = _chip("TacticLabel", "SegmentedInactive")
	_combo_label = _chip("ComboLabel", "SegmentedInactive")
	meta.add_child(_match_info)
	meta.add_child(_control_label)
	meta.add_child(_tactic_label)
	meta.add_child(_combo_label)


func _build_actions() -> void:
	_actions_row = HBoxContainer.new()
	_actions_row.name = "ActionsRow"
	add_child(_actions_row)
	_anchor(_actions_row, 1.0, 0.0)
	_offsets(_actions_row, -EDGE_RIGHT - ACTIONS_WIDTH, EDGE_TOP, -EDGE_RIGHT, EDGE_TOP + ACTIONS_HEIGHT)
	_actions_row.custom_minimum_size = Vector2(0.0, ACTIONS_HEIGHT)
	_actions_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_actions_row.grow_vertical = Control.GROW_DIRECTION_END
	_actions_row.add_theme_constant_override("separation", ACTIONS_SEPARATION)
	_actions_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer := _panel("TimerPanel", "HudPanel", _actions_row)
	timer.custom_minimum_size = TIMER_SIZE
	var timer_margin := _margin(timer, 8)
	# `.game-timer` is a flex row: the ball, then the two-line time column, centred
	# (`index.html:462-463`, `styles.css:692-697`). The ball carries the `TimerBall`
	# variation — its fill, 3 px border and round radius are theme values
	# (`styles.css:750-757`), not ones written here.
	var timer_row := _hbox(timer_margin, TIMER_GAP)
	var timer_ball := _panel("TimerBall", "TimerBall", timer_row)
	timer_ball.custom_minimum_size = TIMER_BALL
	timer_ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var timer_column := _vbox(timer_row, 0)
	timer_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_label = _label(timer_column, "LabelSmall")
	_timer_value = _label(timer_column, "HudTitle")
	_panel_button = _action_button("PanelButton", "▤")
	_panel_button.tooltip_text = UiStrings.t("togglePanel")
	_panel_button.pressed.connect(_on_panel_pressed)
	_mute_button = _action_button("MuteButton", "🔊")
	_mute_button.tooltip_text = UiStrings.t("muteOn")
	_mute_button.pressed.connect(_on_mute_pressed)
	_pad_button = _action_button("PadButton", "🎮")
	_pad_button.tooltip_text = UiStrings.t("gamepadConnected")
	_pad_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad_button.visible = false
	_pause_button = _action_button("PauseButton", "Ⅱ")
	_pause_button.tooltip_text = UiStrings.t("pauseLbl")
	_pause_button.pressed.connect(_on_pause_pressed)


func _build_mode_strip() -> void:
	_mode_panel = _panel("ModeStrip", "HudPanel")
	_anchor(_mode_panel, 0.0, 0.0)
	var top := EDGE_TOP + SCORE_SIZE.y + GAP
	_offsets(_mode_panel, EDGE_LEFT, top, EDGE_LEFT + SCORE_SIZE.x, top + MODE_HEIGHT)
	_mode_panel.custom_minimum_size = Vector2(SCORE_SIZE.x, MODE_HEIGHT)
	_stack_mode_strip()
	_mode_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_mode_panel.grow_vertical = Control.GROW_DIRECTION_END
	_mode_panel.visible = false
	var margin := _margin(_mode_panel, PANEL_INSET)
	var column := _vbox(margin, 6)
	_mode_title = _label(column, "HudLabel")
	_mode_boxes = _hbox(column, 6)
	for index in DRILL_CELLS:
		var cell := _panel("DrillCell%d" % index, "PanelDark", _mode_boxes)
		cell.custom_minimum_size = Vector2(76.0, 0.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell_margin := _margin(cell, 6)
		var cell_column := _vbox(cell_margin, 0)
		_drill_cells.append({
			"panel": cell,
			"label": _label(cell_column, "HudLabel"),
			"value": _label(cell_column, "HudTitle"),
		})
	for index in MODE_LINES:
		_mode_lines.append(_label(column, "LabelSmall"))
	_mode_objective = _label(column, "LabelSmall")


## The training/tournament strip hangs under the scoreboard, and the scoreboard is
## content-sized: its meta rows grow with the theme's type (95 px was the measured
## box, not the rendered one). Its top is therefore the card's real bottom, and
## `resized` re-runs this whenever the card's content moves it — the legibility
## audit measured the two boxes 19 px into each other while this was a constant.
func _stack_mode_strip() -> void:
	if _mode_panel == null or _score_panel == null:
		return
	var top := _score_panel.position.y + maxf(_score_panel.size.y, SCORE_SIZE.y) + GAP
	_offsets(_mode_panel, EDGE_LEFT, top, EDGE_LEFT + SCORE_SIZE.x, top + MODE_HEIGHT)


func _build_minimap() -> void:
	_minimap_panel = _panel("MiniMapPanel", "HudPanel")
	_anchor(_minimap_panel, 1.0, 0.0)
	var width := MINIMAP_BOX.x + MINIMAP_PAD * 2.0
	var height := MINIMAP_BOX.y + MINIMAP_PAD * 2.0 + MINIMAP_HEADER
	_offsets(_minimap_panel, -MINIMAP_EDGE - width, MINIMAP_TOP, -MINIMAP_EDGE, MINIMAP_TOP + height)
	_minimap_panel.custom_minimum_size = Vector2(width, height)
	_minimap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_minimap_panel.grow_vertical = Control.GROW_DIRECTION_END
	var margin := _margin(_minimap_panel, MINIMAP_PAD)
	var column := _vbox(margin, 4)
	_minimap_label = _label(column, "HudLabel")
	_minimap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap = MiniMapCourt.new()
	_minimap.name = "MiniMapCourt"
	_minimap.custom_minimum_size = MINIMAP_BOX
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_minimap)
	_minimap.configure(MINIMAP_SIZE, MINIMAP_BOX, _map_rect(), _palette("surface_5"), _palette("ink"))
	_minimap.set_net_y(_map_net_y())


func _build_serve_banner() -> void:
	_serve_banner = _panel("ServeBanner", "HudPauseCard")
	_anchor(_serve_banner, BANNER_LEFT, 0.5)
	_serve_banner.anchor_right = BANNER_RIGHT
	_serve_banner.anchor_bottom = 0.5
	_offsets(_serve_banner, 0.0, BANNER_TOP, 0.0, BANNER_BOTTOM)
	_serve_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_serve_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_serve_banner.visible = false
	var margin := _margin(_serve_banner, PANEL_INSET)
	var column := _vbox(margin, 0)
	_serve_label = _label(column, "HudTitle")
	_serve_label.name = "ServeLabel"
	_serve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_serve_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_serve_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_bottom_regions() -> void:
	_build_match_panel()
	_build_match_feed()
	_place_bottom_regions()


## The two bottom regions, placed the way the two measured states place them
## (`screen_boxes["game"]` and `screen_boxes["game-panel"]`):
##
##  - immersive (panel closed, the default): the feed is fixed at left 24 / bottom 20
##    (`styles.css:2850-2854`) and the panel is `display: none` (measured 0x0);
##  - panel open: the panel and the feed share the screen's 16 px insets, the panel
##    above the feed, and the feed is a 28 px row — the measured panel-state feed is
##    1068x28, i.e. the log is collapsed. Opening the panel therefore collapses the log:
##    both regions live in the bottom band and this is the one arbitration the reference
##    never had to make (its panel sits below the canvas, off the 720 px frame).
func _place_bottom_regions() -> void:
	_match_panel.anchor_right = 1.0
	_match_panel.anchor_top = 1.0
	_match_panel.anchor_bottom = 1.0
	_offsets(_match_panel, MATCH_INSET, -MATCH_PANEL_BOTTOM - MATCH_PANEL_HEIGHT,
		-MATCH_INSET, -MATCH_PANEL_BOTTOM)
	_match_feed.anchor_top = 1.0
	_match_feed.anchor_bottom = 1.0
	var band := FEED_TOGGLE_HEIGHT
	if _log_expanded:
		band += FEED_GAP + FEED_LOG_HEIGHT
	_match_feed.offset_top = -FEED_BOTTOM - band
	_match_feed.offset_bottom = -FEED_BOTTOM
	if _panel_open:
		_match_feed.anchor_left = 0.0
		_match_feed.anchor_right = 1.0
		_offsets(_match_feed, MATCH_INSET, _match_feed.offset_top, -MATCH_INSET, _match_feed.offset_bottom)
	else:
		_match_feed.anchor_left = 0.0
		_match_feed.anchor_right = 0.0
		_offsets(_match_feed, FEED_EDGE, _match_feed.offset_top,
			FEED_EDGE + FEED_WIDTH, _match_feed.offset_bottom)


func _build_match_panel() -> void:
	_match_panel = _panel("MatchPanel", "HudPanel")
	_match_panel.custom_minimum_size = Vector2(0.0, MATCH_PANEL_HEIGHT)
	_match_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_match_panel.visible = false
	var margin := _margin(_match_panel, PANEL_INSET)
	var column := _vbox(margin, 6)
	_control_rows = VBoxContainer.new()
	_control_rows.name = "ControlRows"
	_control_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_control_rows)
	var special := _hbox(column, 8)
	var special_label := _label(special, "HudLabel")
	special_label.text = UiStrings.t("ability")
	_special_bar = _bar(special, SPECIAL_WIDTH)
	_special_fill = _fill(_special_bar, "button_gradient_start")
	var shot := _vbox(column, 4)
	var intent_row := _hbox(shot, 10)
	_intent_label = _label(intent_row, "HudLabel")
	_advice_label = _label(intent_row, "HudLabel")
	var power_row := _hbox(shot, 8)
	var power_label := _label(power_row, "HudLabel")
	power_label.text = UiStrings.t("power")
	_power_bar = _bar(power_row, METER_WIDTH)
	_power_fill = _fill(_power_bar, "cyan")
	var aim_row := _hbox(shot, 8)
	var aim_label := _label(aim_row, "HudLabel")
	aim_label.text = UiStrings.t("aim")
	_aim_bar = _bar(aim_row, METER_WIDTH)
	var tick := ColorRect.new()
	tick.name = "AimTick"
	tick.color = _palette("ink")
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tick.anchor_left = 0.5
	tick.anchor_right = 0.5
	tick.offset_left = -1.0
	tick.offset_right = 1.0
	_aim_bar.add_child(tick)
	_aim_needle = _needle(_aim_bar, "ink", 4.0, 16.0, "AimNeedle")
	_aim_needle.color = _palette("state_yellow")
	var timing_row := _hbox(shot, 8)
	var timing_label := _label(timing_row, "HudLabel")
	timing_label.text = "TIMING"
	_timing_bar = _bar(timing_row, METER_WIDTH)
	_timing_window = _needle(_timing_bar, "success_cyan", 0.0, 6.0, "TimingWindow")
	_timing_needle = _needle(_timing_bar, "ink", 4.0, 16.0, "TimingNeedle")


func _build_match_feed() -> void:
	_match_feed = VBoxContainer.new()
	_match_feed.name = "MatchFeed"
	_match_feed.add_theme_constant_override("separation", 4)
	_match_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_match_feed.alignment = BoxContainer.ALIGNMENT_END
	_match_feed.grow_horizontal = Control.GROW_DIRECTION_END
	_match_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_match_feed)
	_event_log = VBoxContainer.new()
	_event_log.name = "EventLog"
	_event_log.add_theme_constant_override("separation", 3)
	_event_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_log.visible = false
	_match_feed.add_child(_event_log)
	for index in LOG_LINES:
		var line := _label(_event_log, "LabelSmall")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.visible = false
		_log_labels.append(line)
	_feed_toggle = _chip("FeedToggle", "SegmentedInactive")
	_feed_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_feed_toggle.focus_mode = Control.FOCUS_NONE
	_feed_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_feed_toggle.custom_minimum_size = Vector2(0.0, FEED_TOGGLE_HEIGHT)
	_match_feed.add_child(_feed_toggle)
	_feed_toggle.pressed.connect(_on_feed_pressed)


# ---------------------------------------------------------------------------
# Painting one view
# ---------------------------------------------------------------------------

func _apply_view(view: Dictionary) -> void:
	_view = view
	_score_title.text = UiStrings.t("score")
	_player_name.text = String(view.get("player_name", ""))
	_ai_name.text = String(view.get("ai_name", ""))
	_player_score.text = String(view.get("player_score", ""))
	_ai_score.text = String(view.get("ai_score", ""))
	_match_info.text = String(view.get("match_info", ""))
	_control_label.text = String(view.get("active_label_text", ""))
	_tactic_label.text = String(view.get("tactic_text", ""))
	_combo_label.text = String(view.get("combo_text", ""))
	var auto_switch := bool(view.get("active_auto_switch", false))
	_control_label.theme_type_variation = &"SegmentedActive" if auto_switch else &"SegmentedInactive"
	_control_label.add_theme_color_override("font_color",
		_palette("surface_0") if auto_switch else _palette("state_yellow"))
	_combo_label.add_theme_color_override("font_color",
		_palette(String(view.get("combo_color_key", "combo_default"))))
	_set_combo_glow(bool(view.get("combo_glow", false)))
	# `js/ui.js:1309`: `tacticLabel.classList.toggle("is-flashing", state.tacticFlash > 0)`
	# — a class swap on the same chip, i.e. a variation swap here (`styles.css:678-681`).
	_tactic_label.theme_type_variation = StringName(TACTIC_FLASH_VARIATION
		if bool(view.get("tactic_flash", false)) else TACTIC_VARIATION)
	_timer_label.text = UiStrings.t("gameTime")
	_timer_value.text = String(view.get("timer_text", ""))
	_timer_value.add_theme_color_override("font_color", _palette("ink"))
	_feed_toggle.text = "☰" + ViewState.sep_space() + UiStrings.t("chronicle")
	_minimap_label.text = UiStrings.t("map")
	_special_fill.anchor_right = clampf(float(view.get("special_ready", 0.0)), 0.0, 1.0)
	_special_fill.modulate.a = SPECIAL_DIM_ALPHA if bool(view.get("special_dim", false)) else 1.0
	_aim_needle.visible = true
	_timing_needle.visible = true
	_timing_window.visible = true
	_intent_label.text = UiStrings.t(String(view.get("shot_intent_key", "shot"))).to_upper()
	_intent_label.add_theme_color_override("font_color",
		_palette(String(view.get("shot_intent_color_key", "text_soft_3"))))
	_advice_label.text = UiStrings.t(String(view.get("shot_advice_key", "shotAdvice_read"))).to_upper()
	_advice_label.add_theme_color_override("font_color",
		_palette(String(view.get("shot_advice_color_key", "success_cyan"))))
	_power_fill.anchor_right = clampf(float(view.get("shot_power", 0.0)), 0.0, 1.0)
	_place_needle(_aim_needle, float(view.get("aim_left", 50.0)))
	_place_timing(float(view.get("timing_left", -8.0)), float(view.get("timing_width", 5.0)))
	_serve_banner.visible = bool(view.get("serve_visible", false))
	_serve_label.text = String(view.get("serve_text", ""))
	_serve_label.add_theme_color_override("font_color",
		_palette("state_yellow") if bool(view.get("serve_point_style", false)) else _palette("cyan"))
	_set_log(view.get("log_lines", []))
	_minimap.set_points(view.get("map_points", []), _map_colors())


## The intent/advice tones are palette keys the view-model mapped (`ViewState`), and the
## two scoreboard bars are the reference's own side colours (`--cyan` / `--coral`).
##
## The timing needle's band is wider than the bar on purpose (`js/ui.js:1353` clamps to
## `-8 … 108`), so the clamp is a parameter rather than 0..100.
func _place_needle(needle: ColorRect, percent: float, low: float = 0.0, high: float = 100.0) -> void:
	var ratio := clampf(percent, low, high) / 100.0
	needle.anchor_left = ratio
	needle.anchor_right = ratio


## `js/ui.js:1352-1356`: the needle's position is clamped to a band wider than the bar
## (`-8 … 108`); the perfect window is NOT centred on the needle — the reference pins it
## at 52 % of the bar (`timingPerfect.style.left = 52 - width / 2`, `js/ui.js:1356`) and
## only its width follows `perfectWindow`, so the window marks where perfect timing lives.
const TIMING_CENTER := 0.52


func _place_timing(left: float, width: float) -> void:
	_place_needle(_timing_needle, left, ViewState.TIMING_LEFT_MIN, ViewState.TIMING_LEFT_MAX)
	var half := clampf(width, ViewState.TIMING_WIDTH_MIN, ViewState.TIMING_WIDTH_MAX) / 200.0
	_timing_window.anchor_left = TIMING_CENTER - half
	_timing_window.anchor_right = TIMING_CENTER + half


## `js/ui.js:1315`: `comboEl.style.textShadow = state.combo >= 4
##   ? "0 0 10px rgba(255,106,92,0.8)" : "none"`.
## A Godot Label has no text-shadow stack; its `font_shadow_color` at alpha 0 is the
## reference's "none", and the 10 px blur maps onto the shadow's outline size (the same
## blur->size mechanism theme README §6.3 records). The glow colour is the palette's
## `combo_glow` entry; nothing here writes a colour.
func _set_combo_glow(on: bool) -> void:
	var glow := _palette("combo_glow")
	if not on:
		glow.a = 0.0
	_combo_label.add_theme_color_override("font_shadow_color", glow)
	_combo_label.add_theme_constant_override("shadow_offset_x", 0)
	_combo_label.add_theme_constant_override("shadow_offset_y", 0)
	_combo_label.add_theme_constant_override("shadow_outline_size", COMBO_GLOW_OUTLINE if on else 0)


func _set_log(lines: Variant) -> void:
	var rows: Array = lines if typeof(lines) == TYPE_ARRAY else []
	for index in _log_labels.size():
		var label: Label = _log_labels[index]
		var has_line := index < rows.size() and String(rows[index]) != ""
		label.visible = has_line
		label.text = String(rows[index]) if has_line else ""


func _apply_mode() -> void:
	var has_view := not _mode_view.is_empty()
	_mode_panel.visible = has_view
	if not has_view:
		return
	_mode_title.text = String(_mode_view.get("title", ""))
	var metrics: Array = _mode_view.get("metrics", [])
	for index in _drill_cells.size():
		var cell: Dictionary = _drill_cells[index]
		var panel: PanelContainer = cell["panel"]
		var label: Label = cell["label"]
		var value: Label = cell["value"]
		var present := index < metrics.size()
		panel.visible = present
		if not present:
			continue
		var metric: Dictionary = metrics[index]
		var key := String(metric.get("key", ""))
		label.text = UiStrings.t(key)
		value.text = String(metric.get("value", ""))
		value.add_theme_color_override("font_color",
			_palette("green") if key == STREAK_METRIC_KEY else _palette("ink"))
	var lines: Array = _mode_view.get("lines", [])
	for index in _mode_lines.size():
		var line: Label = _mode_lines[index]
		var present_line := index < lines.size()
		line.visible = present_line
		line.text = String(lines[index]) if present_line else ""
	var objective := String(_mode_view.get("objective_line", ""))
	_mode_objective.visible = objective != ""
	_mode_objective.text = objective


## Every field blank, every measurement hidden: the frame before the first `refresh()`.
## The audit asserts this — a HUD that shows a plausible 0-0 would be inventing a state.
func _clear() -> void:
	_view = {}
	_score_title.text = UiStrings.t("score")
	_player_name.text = ""
	_ai_name.text = ""
	_player_score.text = ""
	_ai_score.text = ""
	_match_info.text = ""
	_control_label.text = ""
	_tactic_label.text = ""
	_tactic_label.theme_type_variation = StringName(TACTIC_VARIATION)
	_combo_label.text = ""
	_set_combo_glow(false)
	_timer_label.text = ""
	_timer_value.text = ""
	_serve_banner.visible = false
	_serve_label.text = ""
	_intent_label.text = ""
	_advice_label.text = ""
	_special_fill.anchor_right = 0.0
	_power_fill.anchor_right = 0.0
	# The markers are hidden rather than parked at a plausible position: a needle sitting
	# at the middle of an empty meter is a measurement the HUD has not been given.
	_aim_needle.visible = false
	_timing_needle.visible = false
	_timing_window.visible = false
	_set_log([])
	_minimap.set_points([], _map_colors())
	_panel_open = false
	_match_panel.visible = false
	_mode_view = {}
	_mode_panel.visible = false
	_set_log_expanded(false)
	_feed_toggle.text = "☰" + ViewState.sep_space() + UiStrings.t("chronicle")


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _on_panel_pressed() -> void:
	set_panel_open(not _panel_open)
	panel_toggled.emit(_panel_open)


func _on_mute_pressed() -> void:
	set_muted(not _muted)
	mute_toggled.emit(_muted)


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_feed_pressed() -> void:
	_set_log_expanded(not _log_expanded)
	log_toggled.emit(_log_expanded)


## Expanding the log grows the feed's band upward — the reference renders the log as a
## block above the toggle (`styles.css:1059-1066`) — and the region placement has to
## follow, because UIR-19's overlap pass reads these rects.
func _set_log_expanded(expanded: bool) -> void:
	_log_expanded = expanded
	_event_log.visible = expanded
	_feed_toggle.theme_type_variation = &"SegmentedActive" if expanded else &"SegmentedInactive"
	_feed_toggle.set_pressed_no_signal(expanded)
	_place_bottom_regions()


# ---------------------------------------------------------------------------
# Node factories. Every one of them takes a type variation name; none takes a colour.
# ---------------------------------------------------------------------------

## Every factory takes the parent it will live under. A node added twice — once by the
## factory and once by the caller — is how a panel ends up at the frame's origin instead
## of inside its box, so the parent is never implicit for a node that leaves the HUD root.
## A region is a card that holds its content. `PanelContainer` lays the content out and
## grows to it; a bare `Panel` keeps the offsets' rectangle and the content (whose own
## minimum is wider than the box, or taller) paints past the card's background. The
## measured box stays the floor (`custom_minimum_size`, set by each builder); where the
## port's type needs more room than the reference's CSS did, the card grows and the
## deviation is what the evidence log records (`uir-08-hud-audit.log`).
func _panel(node_name: String, variation: String, parent: Node = null) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = node_name
	node.theme_type_variation = StringName(variation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(node)
	return node


func _label(parent: Node, variation: String) -> Label:
	var node := Label.new()
	node.theme_type_variation = StringName(variation)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


## The reference's small chips (`index.html:448-459`, `:531`) are interactive elements
## with a state (`aria-pressed`/`aria-expanded`). They carry the segmented variations so
## the *state* is a theme variation, and they are inert here: the HUD sits over the live
## match, so it never takes focus (`focus_mode = NONE`) and never eats a movement key.
func _chip(node_name: String, variation: String, parent: Node = null) -> Button:
	var node := Button.new()
	node.name = node_name
	node.theme_type_variation = StringName(variation)
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(node)
	return node


func _action_button(node_name: String, glyph: String) -> Button:
	var node := Button.new()
	node.name = node_name
	node.theme_type_variation = &"HudButton"
	node.text = glyph
	node.custom_minimum_size = ACTION_BUTTON
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	_actions_row.add_child(node)
	return node


## The card's content fills the card, so its blocks are laid out against the measured
## rect. Unanchored, the margin sizes itself to its own minimum — and an autowrapping
## label's minimum height is its text wrapped at width 1 — which is how a box used to
## end up taller than the card that carries it.
func _margin(parent: Node, inset: int) -> MarginContainer:
	var node := MarginContainer.new()
	node.name = "Margin"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_theme_constant_override("margin_left", inset)
	node.add_theme_constant_override("margin_top", inset)
	node.add_theme_constant_override("margin_right", inset)
	node.add_theme_constant_override("margin_bottom", inset)
	parent.add_child(node)
	return node


func _vbox(parent: Node, separation: int) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.name = "Column"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node


func _hbox(parent: Node, separation: int) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.name = "Row"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node


func _grid(parent: Node, columns: int, separation: int) -> GridContainer:
	var node := GridContainer.new()
	node.name = "Meta"
	node.columns = columns
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("h_separation", separation)
	node.add_theme_constant_override("v_separation", separation)
	parent.add_child(node)
	return node


func _color_bar(parent: Node, palette_key: String, height: float) -> ColorRect:
	var node := ColorRect.new()
	node.name = "Bar"
	node.color = _palette(palette_key)
	node.custom_minimum_size = Vector2(0.0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


## A meter: the track is a `HudPanel` box (the closest measured box to the reference's
## `.shot-meter__*` track), the value is a `ColorRect` whose width is an anchor, so it
## tracks any resize without a resize handler.
func _bar(parent: Node, width: float) -> Control:
	var node := Control.new()
	node.name = "Bar"
	node.custom_minimum_size = Vector2(width, METER_HEIGHT)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	var track := Panel.new()
	track.name = "Track"
	track.theme_type_variation = &"HudPanel"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.add_child(track)
	return node


func _fill(parent: Control, palette_key: String) -> ColorRect:
	var node := ColorRect.new()
	node.name = "Fill"
	node.color = _palette(palette_key)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_left = 0.0
	node.anchor_right = 0.0
	node.anchor_top = 0.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_right = 0.0
	node.offset_top = 0.0
	node.offset_bottom = 0.0
	parent.add_child(node)
	return node


## A vertical marker: 4 px wide by default, stacked on the track. Its position is an
## anchor fraction, taken from the view-model's own formula.
## The marker's `marker_name` is part of the contract: three markers ride the two timing
## meters (the reference's aim tick, its timing window and its timing needle) and two of
## them are siblings, so a shared name would be silently renamed by the engine and the
## audit could not tell which of the three existed.
func _needle(parent: Control, palette_key: String, width: float, height: float, marker_name := "Needle") -> ColorRect:
	var node := ColorRect.new()
	node.name = marker_name
	node.color = _palette(palette_key)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_top = 0.5
	node.anchor_bottom = 0.5
	node.offset_top = -height / 2.0
	node.offset_bottom = height / 2.0
	node.offset_left = -width / 2.0
	node.offset_right = width / 2.0
	parent.add_child(node)
	return node


# ---------------------------------------------------------------------------
# Anchors and theme reads
# ---------------------------------------------------------------------------

func _anchor(node: Control, left: float, top: float) -> void:
	node.anchor_left = left
	node.anchor_top = top


func _offsets(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom


func _theme() -> Theme:
	return theme if theme != null else DefaultTheme


## A palette entry, or a recorded miss. Never a literal, never a silent guess: a key the
## theme does not carry is reported through `report()["palette_misses"]` and asserted
## empty by the audit, which is how a missing token becomes a visible seam request
## instead of a wrong colour.
func _palette(key: String) -> Color:
	var source := _theme()
	if source.has_color(key, "Palette"):
		return source.get_color(key, "Palette")
	if not _palette_misses.has(key):
		_palette_misses.append(key)
	var fallback := "ink"
	if not source.has_color(fallback, "Palette"):
		fallback = "cyan"
	return source.get_color(fallback, "Palette")


## The mini-map's own canvas geometry, taken from the view-model's constants (which are
## the reference's own numbers, `js/main.js:1400-1403`).
func _map_rect() -> Rect2:
	return Rect2(
		Vector2(ViewState.MAP_PADDING, ViewState.MAP_PADDING),
		ViewState.MAP_SIZE - Vector2(ViewState.MAP_PADDING, ViewState.MAP_PADDING) * 2.0)


func _map_net_y() -> float:
	var court: Dictionary = Frozen.court()
	var top := float(court.get("top", ViewState.MAP_Y0))
	var bottom := float(court.get("bottom", ViewState.MAP_Y1))
	var net := float(court.get("netY", (top + bottom) / 2.0))
	return ViewState.map_point(0.0, net).y


## The mini-map dots' colours, resolved once per refresh from the palette keys
## `ViewState` puts on each point (`js/main.js:1414-1424`).
func _map_colors() -> Dictionary:
	var colors := {}
	for key in ViewState.MAP_PADDLE_KEYS:
		colors[String(key)] = _palette(String(key))
	colors[ViewState.MAP_BALL_KEY] = _palette(ViewState.MAP_BALL_KEY)
	colors["ink"] = _palette("ink")
	colors["surface_5"] = _palette("surface_5")
	return colors


func _texts() -> Dictionary:
	var out := {
		"score_title": _score_title.text,
		"player_name": _player_name.text,
		"player_score": _player_score.text,
		"ai_name": _ai_name.text,
		"ai_score": _ai_score.text,
		"match_info": _match_info.text,
		"control_label": _control_label.text,
		"control_variation": String(_control_label.theme_type_variation),
		"tactic_label": _tactic_label.text,
		"combo_label": _combo_label.text,
		"timer_label": _timer_label.text,
		"timer_value": _timer_value.text,
		"intent": _intent_label.text,
		"advice": _advice_label.text,
		"serve": _serve_label.text,
		"feed_toggle": _feed_toggle.text,
		"minimap_label": _minimap_label.text,
		"mode_title": _mode_title.text,
		"mode_cells": [],
		"mode_lines": [],
		"log": [],
	}
	for cell in _drill_cells:
		var data: Dictionary = cell
		if (data["panel"] as PanelContainer).visible:
			out["mode_cells"].append((data["label"] as Label).text
				+ ViewState.sep_space() + (data["value"] as Label).text)
	for line in _mode_lines:
		var label: Label = line
		if label.visible:
			out["mode_lines"].append(label.text)
	for line in _log_labels:
		var label: Label = line
		if label.visible:
			out["log"].append(label.text)
	return out


# ---------------------------------------------------------------------------
# MiniMapCourt — the reference's own drawing (`js/main.js:1397-1428`), in court
# coordinates. It takes the court rectangle and the ink it draws with from the HUD,
# so the palette stays in one place.
# ---------------------------------------------------------------------------

class MiniMapCourt extends Control:
	var _points: Array = []
	var _colors: Dictionary = {}
	var _court_rect := Rect2()
	var _net_y := 0.0
	var _scale := Vector2.ONE

	## The drawing buffer the reference's canvas uses (108x154), the CSS box it is
	## displayed in (86x122, `styles.css:801-805`), the court rectangle inside the
	## buffer, and the two inks — all passed in, so this class owns no palette.
	func configure(buffer: Vector2, box: Vector2, court_rect: Rect2, fill: Color, line: Color) -> void:
		_colors["fill"] = fill
		_colors["line"] = line
		_court_rect = court_rect
		_scale = Vector2(box.x / buffer.x, box.y / buffer.y)
		custom_minimum_size = box
		queue_redraw()

	## `js/main.js:1409` — the net line, in canvas pixels.
	func set_net_y(net_y: float) -> void:
		_net_y = net_y
		queue_redraw()

	func set_points(points: Variant, colors: Dictionary) -> void:
		_points = points if typeof(points) == TYPE_ARRAY else []
		_colors.merge(colors, true)
		queue_redraw()

	func point_count() -> int:
		return _points.size()

	## `js/main.js:1405-1426`: court fill, court outline, net, then the five dots — drawn
	## in the buffer's own coordinates and scaled to the box, which is what the browser
	## does when it displays the 108x154 canvas at 86x122.
	func _draw() -> void:
		if not _colors.has("fill") or not _colors.has("line"):
			return
		draw_set_transform(Vector2.ZERO, 0.0, _scale)
		draw_rect(_court_rect, _colors["fill"], true)
		draw_rect(_court_rect, _colors["line"], false, 2.0)
		draw_line(Vector2(_court_rect.position.x, _net_y),
			Vector2(_court_rect.end.x, _net_y), _colors["line"], 2.0)
		for point in _points:
			var data: Dictionary = point
			var color: Color = _colors.get(String(data.get("color_key", "")), _colors["line"])
			draw_circle(data.get("position", Vector2.ZERO), float(data.get("radius", 3.0)), color)
