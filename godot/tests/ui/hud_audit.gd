## hud_audit.gd — UIR-08's audit over the in-match HUD prototype.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/ui/hud_audit.gd
##
## Same machine-readable contract as the other audits: `ok <name>` / `FAIL <name>` /
## one `PASS n/n` line, exit 0 on PASS and 1 on FAIL.
##
## WHAT IT ASSERTS, and where the expectation comes from:
##
##   1. the surface exists and is the theme's: `Hud.tscn` loads, mounts the theme,
##      and every chip/button/panel reads a UIR-02 type variation (`HudPanel`,
##      `HudButton`, `HudButtonActive`, `HudPauseCard`, `PanelDark`, `Badge`,
##      `LabelSmall`, `HudLabel`, `HudTitle`, `SegmentedInactive`, `SegmentedActive`);
##   2. it shows nothing before the first `refresh()` — a HUD that invents a 0-0 would
##      be fabricating a state (`no_fabricated_defaults`);
##   3. the live mapping is the reference's, frame by frame, over a **real scripted
##      rally**: the real `Match.tscn` controller, the real sim, the real
##      `ScriptedPlayer`, sampled every 137 ticks, each field compared against the
##      reference's own formula computed here in the audit (`js/ui.js:1276-1373`,
##      `js/game.js:3344-3356`) — not against the view-model that produced it;
##   4. the nine capture states drive, and each one's own affordance follows
##      (drill boxes, tournament/career lines, the point banner's yellow, panel open);
##   5. the interface the mount will use behaves: pause emits and never pauses, mute
##      flips, the log expands, the pad badge follows, an unknown state returns false,
##      and `bind_names` never shadows a live state's own name;
##   6. the geometry holds at the design frame and at the measured minimum: every
##      panel inside the frame, the six panels pairwise disjoint, every descendant
##      inside its own panel, the actions row's own packing (284.52 = timer 134.52 +
##      3 x (8 + 42)), and the two timing markers' *rendered* anchors against the
##      reference's formulas (window pinned at 52 %, needle on the view's position);
##   7. no user-facing literal lives in the HUD's own files, no node carries a colour
##      of its own, and every palette key the HUD can ask for exists in the theme —
##      with the scan proved non-vacuous against a synthetic source first.
##
## WHAT IT DOES NOT ASSERT: the visual verdict (that is GATE-A, a human looking at
## captures), and any behaviour of `godot/game/**` (those files are other owners').
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const HudScene := preload("res://src/ui/Hud.tscn")
const ViewState := preload("res://src/ui/ViewState.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Config := preload("res://game/match_config.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")
const MatchTheme := preload("res://src/ui/theme/padel_theme.tres")
## `UNREADABLE` moved into the shared vocabulary module (`ViewState` reads
## `Vocabulary.UNREADABLE`); the two checks below still asked the view-model for it,
## which does not have it, so this whole file failed to PARSE — and a script that does
## not parse exits 0 and prints nothing but the engine banner, so the audit that guards
## the HUD had been silently not running. Same constant, reached where it now lives.
const Vocabulary := preload("res://game/feedback_vocabulary.gd")

const MATCH_SCENE := "res://game/Match.tscn"
const TICK := 1.0 / 120.0
const DESIGN_FRAME := Vector2(1280.0, 720.0)
const MIN_FRAME := Vector2(1152.0, 648.0)
const SMALL_FRAME := Vector2(1024.0, 600.0)
## `js/ui.js:1353-1356` — the perfect window's own centre, in percent of the timing
## bar: `timingPerfect.style.left = 52 - width / 2`, `width = max(5, min(17, w * 155))`.
## The needle's band (`-8 … 108`) never moves it. The number is copied here so the
## anchor is checked against the reference, not against the HUD's own constant.
const TIMING_CENTER := 0.52
## `js/ui.js:1354` — the reference's own default window when `shotRead` carries none.
const PERFECT_WINDOW_DEFAULT := 0.055
## The seven regions `panels()` reports, in sorted order (the HUD's own names).
const REGION_NAMES := ["ActionsRow", "MatchFeed", "MatchPanel", "MiniMapPanel", "ModeStrip",
	"ScorePanel", "ServeBanner"]
const MINIMAP_BOX := Vector2(86.0, 122.0)
## Nodes added to the root are laid out only after the containers have sorted.
const SETTLE_FRAMES := 3
## The rally: 40 simulated seconds, sampled every 137 ticks (a prime, so the samples do
## not alias the 120 Hz tick).
const RALLY_TICKS := 4800
const SAMPLE_EVERY := 137
const MIN_SAMPLES := 8

const CAPTURE_STATES := [
	"default", "serving", "rally", "point-pause", "set-tennis",
	"drill", "tournament", "career", "panel-open",
]

## The ticket's interface list, as the mount will call it.
const INTERFACE := [
	"refresh", "bind_names", "set_paused", "is_paused", "set_panel_open",
	"is_panel_open", "set_muted", "set_pad_connected", "set_mode_view",
	"apply_safe_area", "panels", "capture_states", "apply_capture_state",
	"report", "control_rows",
]

const HUD_FILES := [
	"res://src/ui/Hud.gd",
	"res://src/ui/ViewState.gd",
	"res://src/ui/Hud.tscn",
]

## A line that builds a message for a developer is not user-facing text — the same rule
## `res://tests/ui/router_audit.gd:59` applies, kept identical on purpose.
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]

## The scan's own proof that it can still see prose: a label with a sentence, a
## developer message, a locale id, and a comment quoting prose.
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"modesTitle\")\n## a comment quoting \"prose in a comment\"\n"

## The reference's own intent table and advice set (`js/ui.js:1328-1337`,
## `js/game.js:892-898`) — the audit's copy, not the module's.
const INTENT_KEYS := {
	"drive": "driveLbl", "slice": "sliceLbl", "lob": "lobLbl",
	"defensive-lob": "defensiveLobLbl", "chiquita": "chiquitaLbl",
	"vibora": "viboraLbl", "smash": "smashLbl", "auto": "shot",
}
const ADVICE_VALUES := ["read", "drive", "lob", "chiquita", "vibora", "smash"]
const TACTIC_VALUES := ["balanced", "attack", "defend", "staggered"]
const LABEL_KEYS := ["controlLbl", "manualLbl", "receiveLbl", "autoSwitchLbl", "receiverLbl", "manual"]

## The mini-map's own numbers (`js/main.js:1400-1403`), copied here so the mapping is
## checked against the reference and not against `ViewState.map_point`.
const MAP_SIZE := Vector2(108.0, 154.0)
const MAP_PADDING := 11.0
const MAP_X0 := 80.0
const MAP_X1 := 880.0
const MAP_Y0 := 56.0
const MAP_Y1 := 564.0

var _observed := {}


func _initialize() -> void:
	var audit := AuditBase.new("hud")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	await _contract(audit)
	await _surface(audit)
	await _honesty(audit)
	await _live_rally(audit)
	await _capture_states(audit)
	await _interaction(audit)
	await _geometry(audit)
	_message_contract(audit)
	_literal_scan(audit)


# ---------------------------------------------------------------------------
# 1. The contract the ticket declares
# ---------------------------------------------------------------------------

func _contract(audit: AuditBase) -> void:
	var hud: Control = HudScene.instantiate()
	audit.check_true(hud != null, "hud/hud_scene_instantiates")
	if hud == null:
		return
	for method in INTERFACE:
		audit.check_true(hud.has_method(method), "hud/the_interface_declares_%s" % method)
	audit.check_true(hud.has_signal("pause_requested"), "hud/the_pause_button_has_a_signal_to_emit")
	audit.check_eq(hud.capture_states(), CAPTURE_STATES, "hud/the_nine_capture_states_are_the_tickets_own_list")
	hud.free()

	# The theme carries every variation the HUD names. If UIR-02 renames one, this fails
	# here instead of turning into a silently unstyled node on screen. The probe matches
	# what the theme can carry for that variation: the panel-ish ones declare a stylebox,
	# the text ones a font (`padel_theme.tres`: `LabelSmall :441`, `HudLabel :462`,
	# `HudTitle :467`, `Mono :566` carry `fonts/font` and never a stylebox).
	for variation in ["HudPanel", "HudPauseCard", "PanelDark", "SegmentedContainer",
			"Badge", "LabelSmall", "HudLabel", "HudTitle", "Mono",
			"SegmentedInactive", "SegmentedActive", "SegmentedFlash", "TimerBall",
			"HudButton", "HudButtonActive",
			"ButtonPrimary", "ButtonSecondary", "ButtonGhost"]:
		audit.check_true(MatchTheme.has_stylebox("panel", variation) or MatchTheme.has_stylebox("normal", variation)
			or MatchTheme.has_font("font", variation),
			"hud/theme_carries_the_variation_%s" % variation)

	# Every palette key the HUD can ask for exists: the mapping tables, the mini-map's
	# dots and the two scoreboard sides. The dynamic misses are asserted empty after
	# every state below; this is the static half of the same rule.
	var palette_keys: Array = ["cyan", "coral", "ink", "state_yellow", "button_gradient_start",
		"surface_5", "surface_0", "green", "combo_glow"]
	for key in ViewState.MAP_PADDLE_KEYS:
		palette_keys.append(String(key))
	palette_keys.append(ViewState.MAP_BALL_KEY)
	for key in ViewState.INTENT_COLOR_KEYS.values():
		palette_keys.append(String(key))
	for key in ViewState.ADVICE_COLOR_KEYS.values():
		palette_keys.append(String(key))
	for key in ViewState.COMBO_COLOR_KEYS.values():
		palette_keys.append(String(key))
	palette_keys.append(ViewState.COMBO_FALLBACK_KEY)
	var missing_palette: Array = []
	for key in palette_keys:
		if not MatchTheme.has_color(String(key), "Palette"):
			missing_palette.append(String(key))
	audit.check_eq(missing_palette, [], "hud/every_palette_key_the_hud_can_name_exists_in_the_theme")

	# Every locale key the mapping can build exists — the same rule for text.
	var missing_keys: Array = []
	for intent in INTENT_KEYS:
		if not UiStrings.has(String(INTENT_KEYS[intent])):
			missing_keys.append(String(INTENT_KEYS[intent]))
	for advice in ADVICE_VALUES:
		if not UiStrings.has("shotAdvice_%s" % advice):
			missing_keys.append("shotAdvice_%s" % advice)
	for tactic in TACTIC_VALUES:
		if not UiStrings.has("tacticHud_%s" % tactic):
			missing_keys.append("tacticHud_%s" % tactic)
	for key in LABEL_KEYS + ["roleBack", "roleNet", "sideLeft", "sideRight", "serveFirst",
			"serveSecond", "serveOpp", "score", "gameTime", "chronicle", "map", "ability",
			"power", "aim", "combo", "quickMatch", "ptsToWin", "training", "drillScore",
			"drillBest", "drillHits", "drillStreak", "muteOn", "muteOff", "pauseLbl",
			"togglePanel", "gamepadConnected"]:
		if not UiStrings.has(String(key)):
			missing_keys.append(String(key))
	audit.check_eq(missing_keys, [], "hud/every_locale_key_the_mapping_can_build_resolves")


# ---------------------------------------------------------------------------
# 2. The surface
# ---------------------------------------------------------------------------

func _mount(frame_size: Vector2) -> Control:
	var frame := Control.new()
	frame.name = "HudAuditFrame"
	frame.size = frame_size
	root.add_child(frame)
	return frame


## A button press the way the reference delivers one: the node's own `pressed` signal.
func _press(hud: Control, node_name: String) -> void:
	var button := hud.find_child(node_name, true, false) as Button
	button.pressed.emit()


func _regions_outside(panels: Array, frame_size: Vector2) -> Array:
	var out: Array = []
	for panel in panels:
		var rect: Rect2 = (panel as Control).get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 \
				or rect.end.x > frame_size.x + 0.5 or rect.end.y > frame_size.y + 0.5:
			out.append("%s=%s" % [String((panel as Control).name), str(rect)])
	return out


## Nothing that is ON the frame paints outside the region that carries it. Hidden boxes
## are excluded for the same reason `_visible_overlaps` excludes hidden regions: a closed
## panel's children are not laid out (the engine skips sorting an invisible container), so
## their rectangles are staging artifacts, not pixels — the hidden set is asserted by name
## in each of the two measured states instead of being waved through.
func _spilling(panels: Array) -> Array:
	var out: Array = []
	for panel in panels:
		var region: Control = panel
		if not region.is_visible_in_tree():
			continue
		var rect: Rect2 = region.get_global_rect()
		for child in region.find_children("*", "Control", true, false):
			var inner: Control = child
			if not inner.is_visible_in_tree():
				continue
			if not rect.grow(0.5).encloses(inner.get_global_rect()):
				out.append("%s/%s" % [String(region.name), String(inner.name)])
	return out


## Hidden regions are outside the overlap check — the reference measures the closed panel
## at 0x0 — so the check runs over what is on the frame, and the hidden set is asserted
## by name in each of the two measured states instead of being waved through.
func _visible_overlaps(panels: Array) -> Array:
	var out: Array = []
	for index in panels.size():
		for other in range(index + 1, panels.size()):
			var a: Control = panels[index]
			var b: Control = panels[other]
			if not a.is_visible_in_tree() or not b.is_visible_in_tree():
				continue
			if a.get_global_rect().intersects(b.get_global_rect()):
				out.append("%s x %s" % [String(a.name), String(b.name)])
	return out


func _hidden_regions(panels: Array) -> Array:
	var out: Array = []
	for panel in panels:
		if not (panel as Control).is_visible_in_tree():
			out.append(String((panel as Control).name))
	out.sort()
	return out


func _region_names(panels: Array) -> Array:
	var out: Array = []
	for panel in panels:
		out.append(String((panel as Control).name))
	out.sort()
	return out


func _surface(audit: AuditBase) -> void:
	var frame := _mount(DESIGN_FRAME)
	var hud: Control = HudScene.instantiate()
	frame.add_child(hud)
	for _i in SETTLE_FRAMES:
		await process_frame

	audit.check_true(hud.theme != null, "hud/the_scene_mounts_a_theme")
	audit.check_eq(String(hud.theme.resource_path), "res://src/ui/theme/padel_theme.tres",
		"hud/the_mounted_theme_is_uir_02s_file")

	var expectations := [
		["ScorePanel", "HudPanel"], ["ModeStrip", "HudPanel"], ["MiniMapPanel", "HudPanel"],
		["MatchPanel", "HudPanel"], ["ServeBanner", "ServeChip"],
	]
	var wrong: Array = []
	for pair in expectations:
		var node: Node = hud.find_child(String(pair[0]), true, false)
		if node == null:
			wrong.append("%s missing" % String(pair[0]))
		elif String((node as Control).theme_type_variation) != String(pair[1]):
			wrong.append("%s=%s" % [String(pair[0]), String((node as Control).theme_type_variation)])
	audit.check_eq(wrong, [], "hud/every_panel_carries_the_measured_theme_variation")

	var chips := [
		["ScoreTitle", "SegmentedActive"], ["MatchInfo", "SegmentedInactive"],
		["ControlLabel", "SegmentedInactive"], ["TacticLabel", "SegmentedInactive"],
		["ComboLabel", "SegmentedInactive"], ["FeedToggle", "SegmentedInactive"],
	]
	var wrong_chips: Array = []
	for pair in chips:
		var node: Node = hud.find_child(String(pair[0]), true, false)
		if node == null:
			wrong_chips.append("%s missing" % String(pair[0]))
		elif String((node as Control).theme_type_variation) != String(pair[1]):
			wrong_chips.append("%s=%s" % [String(pair[0]), String((node as Control).theme_type_variation)])
	audit.check_eq(wrong_chips, [], "hud/every_chip_carries_a_segmented_variation")

	var buttons: Array = []
	for name in ["PanelButton", "MuteButton", "PadButton", "PauseButton"]:
		var node: Node = hud.find_child(String(name), true, false)
		if node == null:
			buttons.append("%s missing" % String(name))
			continue
		var button := node as Button
		if String(button.theme_type_variation) != "HudButton":
			buttons.append("%s=%s" % [String(name), String(button.theme_type_variation)])
		if button.focus_mode != Control.FOCUS_NONE:
			buttons.append("%s takes focus" % String(name))
		if button.custom_minimum_size != Vector2(42.0, 42.0):
			buttons.append("%s=%s" % [String(name), str(button.custom_minimum_size)])
	audit.check_eq(buttons, [], "hud/the_four_hud_pause_buttons_are_42px_hud_buttons_that_never_take_focus")

	var tracks := hud.find_children("Track", "Panel", true, false)
	var fills := hud.find_children("Fill", "ColorRect", true, false)
	# The three markers are named one by one. Two of them ride the same timing bar, so a
	# shared name would be silently renamed by the engine and a count of one name could
	# not say which of the reference's three markers existed (`Hud.gd:_needle`).
	var marker_names := ["AimTick", "TimingWindow", "TimingNeedle"]
	var markers: Array = []
	for marker_name in marker_names:
		if hud.find_child(marker_name, true, false) is ColorRect:
			markers.append(marker_name)
	audit.check_eq(markers, marker_names, "hud/the_aim_tick_and_the_two_timing_markers_exist")
	audit.check_eq(tracks.size(), 4, "hud/the_four_meter_tracks_are_theme_panels")
	audit.check_eq(fills.size(), 2, "hud/the_special_and_power_fills_are_two_rects")

	# The timer's own box: `.game-timer` is the ball plus the two-line column
	# (`index.html:462-463`, `styles.css:692-697`), and the ball is a visible 38x38
	# circle whose fill, 3 px border and radius the theme owns (`TimerBall`).
	var timer_panel: Control = hud.find_child("TimerPanel", true, false)
	var ball: Control = hud.find_child("TimerBall", true, false)
	var timer_ok: Array = []
	if timer_panel == null:
		timer_ok.append("TimerPanel missing")
	if ball == null:
		timer_ok.append("TimerBall missing")
	else:
		if String(ball.theme_type_variation) != "TimerBall":
			timer_ok.append("ball variation=%s" % String(ball.theme_type_variation))
		if ball.custom_minimum_size != Vector2(38.0, 38.0):
			timer_ok.append("ball=%s" % str(ball.custom_minimum_size))
		if ball.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			timer_ok.append("ball takes the mouse")
		if timer_panel != null and not timer_panel.is_ancestor_of(ball):
			timer_ok.append("ball is not inside the timer box")
	audit.check_eq(timer_ok, [], "hud/the_timer_carries_the_references_38px_ball_inside_its_own_box")

	# The two scoreboard scores, as the reference colours them: the right-hand one is
	# `var(--coral)` (`styles.css:625-627`), the left one the cyan the title carries.
	var player_score: Label = hud.find_child("PlayerScore", true, false)
	var ai_score: Label = hud.find_child("AiScore", true, false)
	audit.check_true(player_score != null and ai_score != null,
		"hud/the_two_score_labels_are_named_so_the_colours_can_be_read")
	if player_score != null:
		audit.check_true(player_score.get_theme_color("font_color").is_equal_approx(
			MatchTheme.get_color("cyan", "Palette")),
			"hud/the_player_score_is_the_cyan_the_title_variation_carries")
	if ai_score != null:
		audit.check_true(ai_score.get_theme_color("font_color").is_equal_approx(
			MatchTheme.get_color("coral", "Palette")),
			"hud/the_ai_score_is_the_references_coral_not_the_title_cyan")

	# The tactic chip before any state: the idle variation (the flash is a state).
	var tactic: Button = hud.find_child("TacticLabel", true, false)
	audit.check_eq(String(tactic.theme_type_variation), "SegmentedInactive",
		"hud/the_tactic_chip_starts_on_the_idle_variation")
	var minimap: Node = hud.find_child("MiniMapCourt", true, false)
	audit.check_true(minimap != null, "hud/the_mini_map_is_the_references_own_canvas")
	if minimap != null:
		audit.check_eq((minimap as Control).custom_minimum_size, MINIMAP_BOX,
			"hud/the_mini_map_is_displayed_at_the_measured_86x122_css_box")
		audit.check_eq(minimap.get("_scale"), MINIMAP_BOX / MAP_SIZE,
			"hud/the_mini_map_scales_its_108x154_buffer_to_that_box")
		audit.check_true(minimap.has_method("point_count"),
			"hud/the_mini_map_exposes_its_point_count")
	audit.check_true(hud.find_child("ControlRows", true, false) != null,
		"hud/the_control_legend_seat_uir_13_fills_exists_and_is_empty")
	audit.check_eq(hud.control_rows().get_child_count(), 0, "hud/the_legend_seat_starts_empty")

	# The mounted surface is inert over the match: no node in the HUD's own tree stops
	# the mouse except the three real buttons and the log toggle.
	var stopping: Array = []
	var ignore_count := 0
	for node in hud.find_children("*", "Control", true, false):
		var control := node as Control
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			stopping.append(String(control.name))
		elif control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			ignore_count += 1
	stopping.sort()
	audit.check_eq(stopping, ["FeedToggle", "MuteButton", "PanelButton", "PauseButton"],
		"hud/only_the_three_buttons_and_the_log_toggle_take_the_mouse")
	audit.check_gt(ignore_count, 20, "hud/the_rest_of_the_surface_lets_the_mouse_through")

	# The action deck and the coarse-pointer touch layer are NOT ported here, and the
	# reason is recorded rather than implied: the reference gates them behind
	# `@media (pointer: fine)` / `(pointer: coarse)` (`styles.css:807-845`, `:1081-1100`),
	# and a Godot Control has no pointer-class media query — the touch layer is UIR-26's.
	audit.not_ported("hud/action_deck_and_touch_controls",
		"hidden by `@media (pointer: fine)`/`(pointer: coarse)` in the browser; the coarse-pointer layer is UIR-26's ticket and the deck is a keyboard legend UIR-13 owns")
	audit.check_eq(hud.find_children("ActionDeck", "Control", true, false).size(), 0,
		"hud/no_action_deck_hides_in_the_desktop_hud")
	return


# ---------------------------------------------------------------------------
# 3. Nothing is invented before the first frame of data
# ---------------------------------------------------------------------------

func _honesty(audit: AuditBase) -> void:
	var frame := _mount(DESIGN_FRAME)
	var hud: Control = HudScene.instantiate()
	frame.add_child(hud)
	for _i in SETTLE_FRAMES:
		await process_frame
	var report: Dictionary = hud.report()
	var texts: Dictionary = report["texts"]
	audit.check_eq(texts["player_score"], "", "hud/before_the_first_refresh_the_score_is_empty")
	audit.check_eq(texts["timer_value"], "", "hud/before_the_first_refresh_the_timer_is_empty")
	audit.check_eq(texts["match_info"], "", "hud/before_the_first_refresh_the_match_info_is_empty")
	audit.check_eq(texts["log"], [], "hud/before_the_first_refresh_the_log_is_empty")
	audit.check_eq(report["serve_visible"], false, "hud/before_the_first_refresh_no_banner_is_shown")
	audit.check_eq(report["palette_misses"], [], "hud/before_the_first_refresh_no_palette_key_was_missed")
	audit.check_eq(hud.capture_states().size(), CAPTURE_STATES.size(), "hud/the_state_list_survives_a_mount")
	audit.check_eq(String(texts["score_title"]), UiStrings.t("score"), "hud/the_static_title_is_a_resolved_locale_string")
	hud.get_parent().queue_free()


# ---------------------------------------------------------------------------
# 4. The live mapping, over a real scripted rally
# ---------------------------------------------------------------------------

func _live_rally(audit: AuditBase) -> void:
	Config.pending_round = -1
	Config.tier_index = 0
	var packed: PackedScene = load(MATCH_SCENE)
	audit.check_true(packed != null, "hud/the_real_match_scene_loads")
	if packed == null:
		return
	var match_node: Node = packed.instantiate()
	match_node.harness_mode()
	root.add_child(match_node)
	match_node.start_match()
	audit.check_true(match_node.state != null, "hud/the_controller_owns_a_real_sim_state")
	if match_node.state == null:
		match_node.queue_free()
		return

	var frame := _mount(DESIGN_FRAME)
	var hud: Control = HudScene.instantiate()
	frame.add_child(hud)
	for _i in SETTLE_FRAMES:
		await process_frame

	var timing_window: ColorRect = hud.find_child("TimingWindow", true, false)
	var timing_needle: ColorRect = hud.find_child("TimingNeedle", true, false)

	var bot := ScriptedPlayer.new()
	var state = match_node.state
	var ticks := 0
	var samples := 0
	var mismatch_fields: Array = []
	var paint_failures: Array = []
	var id_leaks: Array = []
	var map_failures: Array = []
	var palette_misses: Array = []
	var serve_seen := false
	var log_seen := false
	var power_max := 0.0
	var combo_max := 1
	var elapsed_max := 0.0
	var local_misses: Array = []

	while ticks < RALLY_TICKS and state.result == null:
		match_node.tick_fixed(TICK, bot.decide(state), Sim.empty_input())
		ticks += 1
		if ticks % SAMPLE_EVERY != 0:
			continue
		samples += 1
		hud.refresh(state, match_node.meta)
		var report: Dictionary = hud.report()
		var view: Dictionary = report["view"]
		var texts: Dictionary = report["texts"]
		for miss in report["palette_misses"]:
			if not local_misses.has(String(miss)):
				local_misses.append(String(miss))
		# --- the field-by-field comparison, each against the reference's own rule ---
		_compare_scalars(view, state, mismatch_fields)
		_compare_serve(view, state, mismatch_fields)
		_compare_shot(view, state, mismatch_fields, timing_window, timing_needle)
		_compare_texts(view, texts, paint_failures)
		_compare_ids(view, state, id_leaks)
		_compare_map(view, state, map_failures)
		serve_seen = serve_seen or bool(view["serve_visible"])
		log_seen = log_seen or (view["log_lines"] as Array).size() > 0
		power_max = maxf(power_max, float(view["shot_power"]))
		combo_max = maxi(combo_max, int(view["combo_n"]))
		elapsed_max = maxf(elapsed_max, float(state.elapsed))

	palette_misses = local_misses
	audit.check_ge(samples, MIN_SAMPLES, "hud/the_rally_produced_enough_samples_to_mean_something")
	audit.check_gt(elapsed_max, 20.0, "hud/the_sampled_rally_ran_for_real_simulated_seconds")
	audit.check_eq(mismatch_fields, [], "hud/every_sampled_field_matches_the_references_own_formula")
	audit.check_eq(paint_failures, [], "hud/the_hud_paints_exactly_the_view_it_was_given")
	audit.check_eq(id_leaks, [], "hud/no_message_id_reaches_the_screen")
	audit.check_eq(map_failures, [], "hud/the_mini_map_dots_follow_the_references_mapping")
	audit.check_eq(palette_misses, [], "hud/the_live_rally_missed_no_palette_key")
	audit.check_true(serve_seen, "hud/the_serve_banner_was_seen_during_the_rally")
	audit.check_true(log_seen, "hud/the_event_log_carried_lines_during_the_rally")
	audit.check_true(power_max > 0.0, "hud/the_power_meter_moved_during_the_rally")
	audit.check_ge(combo_max, 1, "hud/the_combo_was_read_from_the_state")
	_observed = {
		"samples": samples, "ticks": ticks, "elapsed": elapsed_max,
		"power_max": power_max, "combo_max": combo_max, "serve_seen": serve_seen,
		"log_seen": log_seen, "result": state.result,
	}
	audit.report("rally samples=%d ticks=%d elapsed=%.1f power_max=%.2f combo_max=%d serve=%s log=%s result=%s"
		% [samples, ticks, elapsed_max, power_max, combo_max, str(serve_seen), str(log_seen), str(state.result)])

	# `bind_names` may fill a name before there is data, but it must never shadow a live
	# state's own name — the reference derives it from the athlete id every frame.
	var live_name := String(hud.report()["texts"]["player_name"])
	hud.bind_names("ZZZ", "WWW")
	audit.check_eq(String(hud.report()["texts"]["player_name"]), live_name,
		"hud/bind_names_never_shadows_a_live_states_own_name")

	match_node.queue_free()
	frame.queue_free()
	await process_frame


func _compare_scalars(view: Dictionary, state, problems: Array) -> void:
	if String(view["player_score"]) != String(state.playerScore):
		problems.append("player_score %s != %s" % [String(view["player_score"]), String(state.playerScore)])
	if String(view["ai_score"]) != String(state.aiScore):
		problems.append("ai_score %s != %s" % [String(view["ai_score"]), String(state.aiScore)])
	var expected_timer := "%02d:%02d" % [int(floor(maxf(state.elapsed, 0.0))) / 60, int(floor(maxf(state.elapsed, 0.0))) % 60]
	if String(view["timer_text"]) != expected_timer:
		problems.append("timer %s != %s" % [String(view["timer_text"]), expected_timer])
	var athlete: Dictionary = state.athlete
	var player_key := "athlete_%s_name" % String(athlete.get("id", ""))
	var player_parts := UiStrings.t(player_key).split(" ")
	var expected_name := String(player_parts[player_parts.size() - 1])
	if String(view["player_name"]) != expected_name:
		problems.append("player_name %s != %s" % [String(view["player_name"]), expected_name])
	var ai: Dictionary = state.ai
	var expected_ai := ""
	if String(ai.get("id", "")) != "":
		var ai_parts := UiStrings.t("ai_%s_name" % String(ai.get("id", ""))).split(" ")
		expected_ai = String(ai_parts[ai_parts.size() - 1])
	else:
		expected_ai = String(ai.get("name", ""))
	if String(view["ai_name"]) != expected_ai:
		problems.append("ai_name %s != %s" % [String(view["ai_name"]), expected_ai])
	var expected_info := UiStrings.t("quickMatch")
	if int(state.pointsToWin) > 0:
		expected_info += " · " + UiStrings.t("ptsToWin", {"n": int(state.pointsToWin)})
	elif bool(state.tieBreak):
		expected_info += " · " + UiStrings.t("tieBreakShort") + " %d-%d" % [
			int(state.tieBreakPoints["player"]), int(state.tieBreakPoints["ai"])]
	else:
		expected_info += " · " + UiStrings.t("setLbl") + " %d" % (int(state.sets["player"]) + int(state.sets["ai"]) + 1)
		expected_info += " · " + UiStrings.t("gamesLbl") + " %d-%d" % [int(state.games["player"]), int(state.games["ai"])]
	if String(view["match_info"]) != expected_info:
		problems.append("match_info %s != %s" % [String(view["match_info"]), expected_info])
	var expected_combo := UiStrings.t("combo", {"n": int(state.combo)})
	if String(view["combo_text"]) != expected_combo:
		problems.append("combo %s != %s" % [String(view["combo_text"]), expected_combo])
	if int(view["combo_n"]) != int(state.combo):
		problems.append("combo_n %s != %s" % [str(view["combo_n"]), str(state.combo)])
	var ready := clampf(float(state.specialReady), 0.0, 1.0)
	if absf(float(view["special_ready"]) - ready) > 0.0001:
		problems.append("special_ready %f != %f" % [float(view["special_ready"]), ready])
	if bool(view["special_dim"]) != (float(state.specialCooldown) > 0.0):
		problems.append("special_dim %s" % str(view["special_dim"]))
	# The active-player label's five branches, in the reference's own order.
	var paddle = state.get(String(state.activePlayerKey))
	var net_y := float(Frozen.court().get("netY", 0.0))
	var role_key := "roleBack" if float(paddle.y) > net_y + 150.0 else "roleNet"
	var receiving: bool = String(state.serveSide) == "ai" and (bool(state.serving) or bool(state.ball.serveInFlight))
	var expected_branch := "controlLbl"
	var expected_label := ""
	if receiving:
		expected_branch = "receiverLbl"
		var side := "sideLeft" if String(state.ball.serveTargetSide) == "left" else "sideRight"
		expected_label = UiStrings.t("receiverLbl", {"side": UiStrings.t(side)})
	elif float(state.manualSwitchFlash) > 0.0:
		expected_branch = "manual"
		expected_label = UiStrings.t("manual") + " > " + UiStrings.t(role_key)
	elif float(state.receiverSwitchFlash) > 0.0:
		expected_branch = "autoSwitchLbl"
		expected_label = UiStrings.t("autoSwitchLbl", {"role": UiStrings.t(role_key)})
	elif bool(state.receiverLocked):
		expected_branch = "receiveLbl"
		expected_label = UiStrings.t("receiveLbl", {"role": UiStrings.t(role_key)})
	else:
		expected_branch = "manualLbl" if String(state.controlMode) == "manual" else "controlLbl"
		expected_label = UiStrings.t(expected_branch, {"role": UiStrings.t(role_key)})
	if String(view["active_label_key"]) != expected_branch:
		problems.append("active_label_key %s != %s" % [String(view["active_label_key"]), expected_branch])
	if String(view["active_label_text"]) != expected_label:
		problems.append("active_label_text %s != %s" % [String(view["active_label_text"]), expected_label])
	if bool(view["active_role_key"] == "roleBack") != bool(role_key == "roleBack"):
		problems.append("active_role_key %s != %s" % [String(view["active_role_key"]), role_key])
	# The tactic: the movement states win over the team tactic above 0.15.
	var tactic_upper := float(paddle.splitStep) > 0.15 or float(paddle.sprinting) > 0.15
	if bool(view["tactic_upper"]) != tactic_upper:
		problems.append("tactic_upper %s" % str(view["tactic_upper"]))
	if not tactic_upper:
		var expected_tactic := UiStrings.t("tacticHud_%s" % String(state.playerTeamTactic))
		if String(view["tactic_text"]) != expected_tactic:
			problems.append("tactic %s != %s" % [String(view["tactic_text"]), expected_tactic])


func _compare_serve(view: Dictionary, state, problems: Array) -> void:
	var visible: bool = bool(state.serving) or float(state.pointPause) > 0.0
	if bool(view["serve_visible"]) != visible:
		problems.append("serve_visible %s != %s" % [str(view["serve_visible"]), str(visible)])
	if bool(view["serve_point_style"]) != (float(state.pointPause) > 0.0):
		problems.append("serve_point_style %s" % str(view["serve_point_style"]))
	if float(state.pointPause) > 0.0:
		var expected := _expected_message(String(state.pointMessage))
		if String(view["serve_text"]) != expected:
			problems.append("point banner %s != %s" % [String(view["serve_text"]), expected])
	elif String(state.serveSide) == "player":
		var expected_key := "serveSecond" if int(state.serveAttempts) > 0 else "serveFirst"
		if String(view["serve_key"]) != expected_key:
			problems.append("serve_key %s != %s" % [String(view["serve_key"]), expected_key])
		if String(view["serve_text"]) != UiStrings.t(expected_key):
			problems.append("serve_text %s" % String(view["serve_text"]))
	elif String(view["serve_key"]) != "serveOpp":
		problems.append("serve_key %s != serveOpp" % String(view["serve_key"]))


## The message-id rule, written out a second time on purpose: the seam resolves the
## composite point ids through `locale_rules.json`, the double fault's argument is a
## marker the contract leaves unresolved (`js/game.js:2128`), the let event has no key
## of its own (`evLet`), and anything else must not reach the screen as an id.
func _expected_message(message_id: String) -> String:
	var parts := message_id.split(":")
	if parts.size() >= 3 and (String(parts[0]) == "pointYou" or String(parts[0]) == "pointOpp") \
			and String(parts[1]) == "doubleFault":
		var fault_keys := {"serveoutbox": "serveOutBox", "servewallfault": "serveWallFault"}
		var fault_key := String(fault_keys.get(String(parts[2]), ""))
		if fault_key != "":
			return UiStrings.t(String(parts[0])) + " · " \
				+ UiStrings.t("doubleFault", {"reason": UiStrings.t(fault_key).to_lower()})
	if message_id == "LET":
		return UiStrings.t("evLet")
	if not UiStrings.has(message_id):
		return "??"
	var text := UiStrings.t(message_id)
	return "??" if text.contains("{") else text


func _compare_shot(view: Dictionary, state, problems: Array, timing_window: ColorRect = null,
		timing_needle: ColorRect = null) -> void:
	var power := clampf(float(state.shotCharge), 0.0, 1.0)
	if absf(float(view["shot_power"]) - power) > 0.0001:
		problems.append("shot_power %f != %f" % [float(view["shot_power"]), power])
	var aim := clampf(50.0 + float(state.shotAim) * 42.0, 0.0, 100.0)
	if absf(float(view["aim_left"]) - aim) > 0.0001:
		problems.append("aim_left %f != %f" % [float(view["aim_left"]), aim])
	var read: Dictionary = state.shotRead
	var eta_present: bool = bool(read.get("active", false)) and read.get("eta") != null
	var expected_left := -8.0
	if eta_present:
		expected_left = maxf(-8.0, minf(108.0, 52.0 - float(read["eta"]) * 72.0))
	if absf(float(view["timing_left"]) - expected_left) > 0.0001:
		problems.append("timing_left %f != %f" % [float(view["timing_left"]), expected_left])
	var expected_width := maxf(5.0, minf(17.0, float(read.get("perfectWindow", PERFECT_WINDOW_DEFAULT)) * 155.0))
	if absf(float(view["timing_width"]) - expected_width) > 0.0001:
		problems.append("timing_width %f != %f" % [float(view["timing_width"]), expected_width])
	# The *rendered* anchors, not the view fields: the needle rides the view's own
	# position (`-8 … 108` % of the bar) while the window is pinned at 52 % ± width/2
	# of it — the wave-3 review's finding 1 measured this being done wrong and the
	# audit could not see it because it only read the view dictionary.
	if timing_needle != null:
		var needle_anchor := clampf(expected_left, -8.0, 108.0) / 100.0
		if absf(timing_needle.anchor_left - needle_anchor) > 0.0001 or absf(timing_needle.anchor_right - needle_anchor) > 0.0001:
			problems.append("needle anchor %f != %f" % [timing_needle.anchor_left, needle_anchor])
	if timing_window != null:
		var half := expected_width / 200.0
		if absf(timing_window.anchor_left - (TIMING_CENTER - half)) > 0.0001 \
				or absf(timing_window.anchor_right - (TIMING_CENTER + half)) > 0.0001:
			problems.append("window anchors %f..%f != %f..%f" % [
				timing_window.anchor_left, timing_window.anchor_right,
				TIMING_CENTER - half, TIMING_CENTER + half])
	var intent := String(state.shotIntent)
	if INTENT_KEYS.has(intent) and String(view["shot_intent_key"]) != String(INTENT_KEYS[intent]):
		problems.append("intent %s -> %s" % [intent, String(view["shot_intent_key"])])
	var advice := String(read.get("advice", ""))
	if advice != "" and String(view["shot_advice_key"]) != "shotAdvice_%s" % advice:
		problems.append("advice %s -> %s" % [advice, String(view["shot_advice_key"])])


func _compare_texts(view: Dictionary, texts: Dictionary, problems: Array) -> void:
	var pairs := [
		["player_score", "player_score"], ["ai_score", "ai_score"],
		["player_name", "player_name"], ["ai_name", "ai_name"],
		["match_info", "match_info"], ["active_label_text", "control_label"],
		["tactic_text", "tactic_label"], ["combo_text", "combo_label"],
		["timer_text", "timer_value"], ["serve_text", "serve"],
	]
	for pair in pairs:
		if String(view[pair[0]]) != String(texts[pair[1]]):
			problems.append("%s painted %s != %s" % [pair[1], String(texts[pair[1]]), String(view[pair[0]])])
	if String(texts["intent"]) != UiStrings.t(String(view["shot_intent_key"])).to_upper():
		problems.append("intent painted %s" % String(texts["intent"]))
	if String(texts["advice"]) != UiStrings.t(String(view["shot_advice_key"])).to_upper():
		problems.append("advice painted %s" % String(texts["advice"]))
	var log: Array = view["log_lines"]
	var painted: Array = texts["log"]
	if painted.size() != mini(log.size(), 5):
		problems.append("log painted %d of %d" % [painted.size(), log.size()])
	for index in mini(painted.size(), log.size()):
		if String(painted[index]) != String(log[index]):
			problems.append("log[%d] painted %s" % [index, String(painted[index])])


func _compare_ids(view: Dictionary, state, leaks: Array) -> void:
	var events: Array = state.events
	var lines: Array = view["log_lines"]
	for index in mini(events.size(), lines.size()):
		if String(lines[index]) == String(events[index]):
			leaks.append(String(lines[index]))
	for line in lines:
		if String(line).contains("{") or String(line).contains("_id"):
			leaks.append(String(line))
	for key in ["serve_text", "match_info", "tactic_text", "combo_text", "active_label_text"]:
		if String(view[key]).contains("{"):
			leaks.append("%s=%s" % [key, String(view[key])])


func _compare_map(view: Dictionary, state, problems: Array) -> void:
	var points: Array = view["map_points"]
	if points.size() != 5:
		problems.append("map_points=%d" % points.size())
		return
	var paddles := [
		[state.player, "cyan"], [state.playerMate, "text_soft_3"],
		[state.opponent, "coral"], [state.opponentMate, "rival"],
	]
	for index in paddles.size():
		var paddle = paddles[index][0]
		var point: Dictionary = points[index]
		var expected := Vector2(
			MAP_PADDING + ((float(paddle.x) - MAP_X0) / (MAP_X1 - MAP_X0)) * (MAP_SIZE.x - MAP_PADDING * 2.0),
			MAP_PADDING + ((float(paddle.y) - MAP_Y0) / (MAP_Y1 - MAP_Y0)) * (MAP_SIZE.y - MAP_PADDING * 2.0))
		if (point["position"] as Vector2).distance_to(expected) > 0.01:
			problems.append("map[%d] %s != %s" % [index, str(point["position"]), str(expected)])
		if String(point["color_key"]) != String(paddles[index][1]):
			problems.append("map[%d] colour %s" % [index, String(point["color_key"])])
	var ball: Dictionary = points[4]
	var expected_ball := Vector2(
		MAP_PADDING + ((float(state.ball.x) - MAP_X0) / (MAP_X1 - MAP_X0)) * (MAP_SIZE.x - MAP_PADDING * 2.0),
		MAP_PADDING + ((float(state.ball.y) - MAP_Y0) / (MAP_Y1 - MAP_Y0)) * (MAP_SIZE.y - MAP_PADDING * 2.0))
	if (ball["position"] as Vector2).distance_to(expected_ball) > 0.01:
		problems.append("map ball %s != %s" % [str(ball["position"]), str(expected_ball)])


# ---------------------------------------------------------------------------
# 5. The nine capture states
# ---------------------------------------------------------------------------

func _capture_states(audit: AuditBase) -> void:
	var frame := _mount(DESIGN_FRAME)
	var hud: Control = HudScene.instantiate()
	frame.add_child(hud)
	for _i in SETTLE_FRAMES:
		await process_frame

	var wrong: Array = []
	for state_id in CAPTURE_STATES:
		if not hud.apply_capture_state(state_id):
			wrong.append("refused %s" % state_id)
	audit.check_eq(wrong, [], "hud/the_nine_capture_states_all_drive")
	audit.check_eq(hud.apply_capture_state("nope"), false, "hud/an_unknown_state_is_refused_and_not_a_silent_no_op")

	hud.apply_capture_state("drill")
	await process_frame
	var report: Dictionary = hud.report()
	audit.check_eq(report["mode_visible"], true, "hud/drill_shows_the_mode_strip")
	audit.check_eq(String(report["mode_title"]), UiStrings.t("training"), "hud/drill_titles_the_strip_through_the_library")
	audit.check_eq((report["texts"]["mode_cells"] as Array).size(), 4, "hud/drill_shows_four_metric_boxes")
	audit.check_true(String((report["texts"]["mode_cells"] as Array)[0]).begins_with(UiStrings.t("drillScore")),
		"hud/the_first_drill_box_is_the_score_and_not_an_id")
	audit.check_eq(report["panel_open"], false, "hud/drill_leaves_the_meter_panel_in")

	hud.apply_capture_state("career")
	await process_frame
	report = hud.report()
	audit.check_eq(String(report["mode_title"]), UiStrings.t("careerMode"), "hud/career_titles_the_strip_through_the_library")
	audit.check_gt((report["texts"]["mode_lines"] as Array).size(), 0, "hud/career_shows_its_objective_line")

	hud.apply_capture_state("point-pause")
	await process_frame
	report = hud.report()
	audit.check_eq(report["serve_visible"], true, "hud/the_point_banner_is_shown_between_points")
	var banner: Node = hud.find_child("ServeBanner", true, false)
	# The label is the HUD's own `ServeLabel`: the banner's box can carry a column, and a
	# lookup by the bare class name would pass on a node the banner never shows.
	var serve_label := (banner as Control).find_child("ServeLabel", true, false) if banner != null else null
	audit.check_true(serve_label != null, "hud/the_banner_has_a_label")
	if serve_label != null:
		audit.check_eq((serve_label as Label).get_theme_color("font_color"), MatchTheme.get_color("state_yellow", "Palette"),
			"hud/the_point_banner_is_the_state_yellows_the_reference_uses_for_a_point")

	hud.apply_capture_state("panel-open")
	await process_frame
	report = hud.report()
	audit.check_eq(report["panel_open"], true, "hud/panel_open_shows_the_command_panel")
	audit.check_eq((hud.find_child("MatchPanel", true, false) as PanelContainer).visible, true,
		"hud/panel_open_reveals_the_meter_panel_node")

	# The three state-driven visuals wave-3's review found unrendered or anchored
	# wrong: the combo glow at four (`js/ui.js:1315`), the flashing tactic chip
	# (`js/ui.js:1309`) and the perfect window pinned at 52 % (`js/ui.js:1356`).
	var combo: Button = hud.find_child("ComboLabel", true, false)
	var window: ColorRect = hud.find_child("TimingWindow", true, false)
	var needle: ColorRect = hud.find_child("TimingNeedle", true, false)

	hud.apply_capture_state("set-tennis")
	await process_frame
	report = hud.report()
	audit.check_eq(report["combo_glow"], true, "hud/set_tennis_lights_the_combo_glow_at_four")
	audit.check_eq(int(report["combo_glow_outline"]), 10, "hud/the_glow_is_the_references_10px_blur")
	audit.check_true(combo.get_theme_color("font_shadow_color").is_equal_approx(
		MatchTheme.get_color("combo_glow", "Palette")),
		"hud/the_glow_colour_is_the_palettes_own_rgba_255_106_92")

	hud.apply_capture_state("rally")
	await process_frame
	report = hud.report()
	audit.check_eq(report["combo_glow"], false, "hud/a_combo_of_three_carries_no_glow")
	audit.check_eq(int(report["combo_glow_outline"]), 0, "hud/the_glow_outline_is_zero_when_off")
	audit.check_eq(String(report["tactic_variation"]), "SegmentedFlash",
		"hud/a_flashing_tactic_swaps_the_chip_to_the_flash_variation")
	var rally_half := clampf(0.061 * 155.0, 5.0, 17.0) / 200.0
	audit.check_true(absf(window.anchor_left - (TIMING_CENTER - rally_half)) < 0.0001
		and absf(window.anchor_right - (TIMING_CENTER + rally_half)) < 0.0001,
		"hud/the_perfect_window_is_pinned_at_52_percent_not_centred_on_the_needle")
	audit.check_true(absf(needle.anchor_left - 0.38) < 0.0001,
		"hud/and_the_needle_still_sits_at_the_views_own_38_percent")

	hud.apply_capture_state("default")
	await process_frame
	report = hud.report()
	var default_half := clampf(PERFECT_WINDOW_DEFAULT * 155.0, 5.0, 17.0) / 200.0
	audit.check_eq(String(report["tactic_variation"]), "SegmentedInactive",
		"hud/a_settled_tactic_returns_the_chip_to_the_idle_variation")
	audit.check_eq(report["combo_glow"], false, "hud/the_default_state_carries_no_glow")
	audit.check_true(absf(window.anchor_left - (TIMING_CENTER - default_half)) < 0.0001
		and absf(window.anchor_right - (TIMING_CENTER + default_half)) < 0.0001,
		"hud/with_no_shot_reading_the_window_stays_at_52_percent")
	audit.check_true(absf(needle.anchor_left - -0.08) < 0.0001,
		"hud/while_the_needle_parks_on_the_references_minus_8_percent")

	audit.check_eq(report["palette_misses"], [], "hud/no_capture_state_missed_a_palette_key")
	var leaked: Array = []
	for text in (report["texts"] as Dictionary).values():
		if typeof(text) == TYPE_STRING and String(text).contains("{"):
			leaked.append(String(text))
	audit.check_eq(leaked, [], "hud/no_capture_state_put_an_unbound_placeholder_on_screen")
	frame.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 6. The interface the mount will use
# ---------------------------------------------------------------------------

func _interaction(audit: AuditBase) -> void:
	var frame := _mount(DESIGN_FRAME)
	var hud: Control = HudScene.instantiate()
	frame.add_child(hud)
	for _i in SETTLE_FRAMES:
		await process_frame

	var seen := {"pause": 0, "mute": true, "log": true, "panel": true}
	hud.pause_requested.connect(func() -> void: seen["pause"] = int(seen["pause"]) + 1)
	hud.mute_toggled.connect(func(muted: bool) -> void: seen["mute"] = muted)
	hud.log_toggled.connect(func(expanded: bool) -> void: seen["log"] = expanded)
	hud.panel_toggled.connect(func(open: bool) -> void: seen["panel"] = open)

	var pause_button: Button = hud.find_child("PauseButton", true, false)
	var mute_button: Button = hud.find_child("MuteButton", true, false)
	var panel_button: Button = hud.find_child("PanelButton", true, false)
	var feed_toggle: Button = hud.find_child("FeedToggle", true, false)
	var pad_button: Button = hud.find_child("PadButton", true, false)

	pause_button.pressed.emit()
	audit.check_eq(int(seen["pause"]), 1, "hud/the_pause_button_emits_its_seam_signal")
	audit.check_eq(hud.is_paused(), false, "hud/the_pause_button_never_pauses_by_itself")
	hud.set_paused(true)
	audit.check_eq(hud.is_paused(), true, "hud/set_paused_is_the_match_s_state_not_the_hud_s")
	audit.check_eq(String(pause_button.theme_type_variation), "HudButtonActive",
		"hud/a_paused_match_marks_the_pause_button_active")
	hud.set_paused(false)
	audit.check_eq(String(pause_button.theme_type_variation), "HudButton", "hud/unpausing_restores_the_button")

	mute_button.pressed.emit()
	audit.check_eq(bool(seen["mute"]), true, "hud/the_mute_button_emits_its_state")
	audit.check_eq(mute_button.text, "🔇", "hud/muted_shows_the_muted_glyph")
	hud.set_muted(false)
	audit.check_eq(mute_button.text, "🔊", "hud/unmuted_shows_the_speaker_glyph")

	panel_button.pressed.emit()
	audit.check_eq(bool(seen["panel"]), true, "hud/the_panel_button_emits_its_state")
	audit.check_eq(hud.is_panel_open(), true, "hud/the_panel_button_opens_the_panel")
	panel_button.pressed.emit()
	audit.check_eq(hud.is_panel_open(), false, "hud/the_panel_button_closes_it_again")

	feed_toggle.pressed.emit()
	audit.check_eq(bool(seen["log"]), true, "hud/the_log_toggle_emits_its_state")
	audit.check_eq(String(feed_toggle.theme_type_variation), "SegmentedActive", "hud/an_open_log_reads_as_active")
	feed_toggle.pressed.emit()
	audit.check_eq(bool(seen["log"]), false, "hud/the_log_toggle_closes_again")

	hud.set_pad_connected(true)
	audit.check_eq(pad_button.visible, true, "hud/the_pad_badge_follows_the_pad")
	hud.set_pad_connected(false)
	audit.check_eq(pad_button.visible, false, "hud/the_pad_badge_hides_again")

	# The mode strip accepts a mode session's own view dictionary, the shape
	# `godot/game/mode_session.gd:411-519` returns — the interim seam UIR-22 removes.
	hud.set_mode_view({
		"mode": "drill", "title": UiStrings.t("training"), "phase": "aim",
		"lines": [], "metrics": [
			{"key": "drillScore", "value": "7"},
			{"key": "drillBest", "value": "9"},
			{"key": "drillHits", "value": "7/9"},
			{"key": "drillStreak", "value": "2"},
		],
	})
	await process_frame
	var report: Dictionary = hud.report()
	audit.check_eq(report["mode_visible"], true, "hud/a_mode_session_view_drives_the_strip")
	audit.check_eq((report["texts"]["mode_cells"] as Array).size(), 4, "hud/the_sessions_four_metrics_become_four_boxes")
	hud.set_mode_view({})
	audit.check_eq(hud.report()["mode_visible"], false, "hud/an_empty_mode_view_hides_the_strip")
	frame.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 7. Geometry: the frame, the panels, and nothing spilling out
# ---------------------------------------------------------------------------

func _geometry(audit: AuditBase) -> void:
	for frame_size in [DESIGN_FRAME, MIN_FRAME]:
		var frame := _mount(frame_size)
		var hud: Control = HudScene.instantiate()
		frame.add_child(hud)
		for _i in SETTLE_FRAMES:
			await process_frame
		hud.apply_safe_area(frame_size)
		var report: Dictionary = hud.report()
		audit.check_eq(report["frame_ok"], true, "hud/the_frame_%dx%d_is_supported" % [int(frame_size.x), int(frame_size.y)])
		var panels: Array = hud.panels()
		audit.check_eq(_region_names(panels), REGION_NAMES,
			"hud/the_seven_regions_are_the_reference's_own_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		audit.check_eq(_regions_outside(panels, frame_size), [], "hud/every_region_is_inside_the_frame_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		audit.check_eq(_spilling(panels), [], "hud/nothing_spills_out_of_its_region_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])

		# The row's own arithmetic (the wave-3 review's finding 4). The measured
		# `.game-hud__actions` is 284.52 wide = timer 134.52 + 3 x (8 + 42), right edge
		# at the 32 px inset (`styles.css:699-705`; the three buttons carry 8 px
		# `margin-left` each). The anchors set the row's outer rect, so checking only
		# that rect could never see a wrong timer width or a wrong gap — these do.
		var row: Control = hud.find_child("ActionsRow", true, false)
		var timer: Control = hud.find_child("TimerPanel", true, false)
		var row_ok: Array = []
		if absf(row.size.x - 284.52) > 0.51:
			row_ok.append("row width %.2f" % row.size.x)
		if absf(row.get_global_rect().end.x - (frame_size.x - 32.0)) > 0.51:
			row_ok.append("row right edge %.2f" % row.get_global_rect().end.x)
		if absf(timer.size.x - 134.52) > 0.51:
			row_ok.append("timer width %.2f" % timer.size.x)
		var packing := 0.0
		var visible_children := 0
		for child in row.get_children():
			if (child as Control).is_visible_in_tree():
				packing += (child as Control).size.x
				visible_children += 1
		packing += float(row.get_theme_constant("separation")) * maxi(0, visible_children - 1)
		if absf(packing - row.size.x) > 0.51:
			row_ok.append("children pack to %.2f in a %.2f row" % [packing, row.size.x])
		audit.check_eq(row_ok, [], "hud/the_actions_row_packs_the_measured_284_52_with_the_134_52_timer_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])

		# The immersive default (measured: the panel is 0x0) with the event log expanded —
		# the state that puts the most visible boxes on the frame at once.
		_press(hud, "FeedToggle")
		await process_frame
		audit.check_eq(hud.report()["log_expanded"], true,
			"hud/the_feed_toggle_expands_the_log_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		audit.check_eq(_visible_overlaps(panels), [],
			"hud/visible_regions_are_pairwise_disjoint_immersive_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		# This section runs before the first refresh (`_honesty` fixes that premise: no
		# banner is shown yet), so the closed panel, the drill strip and the serve banner
		# are the hidden set — the same two the panel-open check below asserts.
		audit.check_eq(_hidden_regions(panels), ["MatchPanel", "ModeStrip", "ServeBanner"],
			"hud/immersive_hides_exactly_the_command_panel_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])

		# The panel state (measured: `.match-panel` above a 28 px `.match-feed`, both at
		# the screen's 16 px insets) — opening the panel collapses the log.
		hud.apply_capture_state("panel-open")
		await process_frame
		audit.check_eq(hud.report()["panel_open"], true,
			"hud/the_panel_state_opens_the_command_panel_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		audit.check_eq(hud.report()["log_expanded"], false,
			"hud/opening_the_panel_collapses_the_log_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		audit.check_eq(_visible_overlaps(panels), [],
			"hud/visible_regions_are_pairwise_disjoint_panel_state_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		audit.check_eq(_hidden_regions(panels), ["ModeStrip", "ServeBanner"],
			"hud/the_panel_state_shows_the_regions_the_view_supports_at_%dx%d" % [int(frame_size.x), int(frame_size.y)])
		frame.queue_free()
		await process_frame

	# A frame below the measured minimum must say so instead of pretending.
	var small := _mount(SMALL_FRAME)
	var small_hud: Control = HudScene.instantiate()
	small.add_child(small_hud)
	for _i in SETTLE_FRAMES:
		await process_frame
	small_hud.apply_safe_area(SMALL_FRAME)
	audit.check_eq(small_hud.report()["frame_ok"], false, "hud/a_frame_below_the_measured_minimum_is_reported_not_ignored")
	small.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# 8-9. The message contract and the literal scan
# ---------------------------------------------------------------------------

## The message-id resolver, checked against the reference's own compositions
## (`js/game.js:2110` for the point suffix, `:2128` for the double fault, and the
## locale contract's `compositeRules`).
func _message_contract(audit: AuditBase) -> void:
	var separator := " · "
	audit.check_eq(ViewState.resolve_message("pointYou:msgOut"),
		UiStrings.t("pointYou") + separator + UiStrings.t("msgOut"),
		"hud/a_composite_point_message_resolves_through_the_declared_rule")
	var fault_reason := UiStrings.t("serveOutBox").to_lower()
	audit.check_eq(ViewState.resolve_message("pointOpp:doubleFault:serveoutbox"),
		UiStrings.t("pointOpp") + separator + UiStrings.t("doubleFault", {"reason": fault_reason}),
		"hud/the_double_fault_reads_as_the_reference_writes_it")
	audit.check_eq(ViewState.resolve_message("LET"), UiStrings.t("evLet"),
		"hud/the_let_event_uses_the_ports_own_key")
	audit.check_eq(ViewState.resolve_message("serveHint"), Vocabulary.UNREADABLE,
		"hud/a_template_with_unbound_placeholders_is_marked_not_printed")
	audit.check_eq(ViewState.resolve_message("no_such_key"), Vocabulary.UNREADABLE,
		"hud/an_unresolvable_id_is_marked_not_printed")
	audit.check_eq(ViewState.timer_text(0.0), "00:00", "hud/the_timer_starts_at_zero")
	audit.check_eq(ViewState.timer_text(65.9), "01:05", "hud/the_timer_floors_the_seconds")
	audit.check_eq(ViewState.timer_text(3600.0), "60:00", "hud/the_timer_counts_minutes_past_the_hour")
	audit.check_eq(ViewState.last_word("Ludovico Maestro"), "Maestro", "hud/the_scoreboard_shows_the_last_word_of_a_name")

	# The view-model declares its fields; the audit holds it to that list.
	var state = Sim.create_match_state("quick", Config.athlete(), Config.arena(), Config.tier(), 0, {})
	var view := ViewState.from_state(state, {})
	var produced: Array = view.keys()
	produced.sort()
	var declared: Array = ViewState.FIELDS.duplicate()
	declared.sort()
	audit.check_eq(produced, declared, "hud/the_view_model_returns_exactly_the_fields_it_declares")
	var missing: Array = []
	for field in ViewState.FIELDS:
		if not view.has(field):
			missing.append(String(field))
	audit.check_eq(missing, [], "hud/no_declared_field_is_missing_from_a_fresh_state")


func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe.size(), 1, "hud/the_literal_scan_flags_prose_in_a_synthetic_source")
	audit.check_true(String(probe[0]).contains("Play now"), "hud/the_literal_scan_flags_the_right_line")
	var offenders: Array = []
	for path in HUD_FILES:
		offenders.append_array(_offenders_in_source(String(path), FileAccess.get_file_as_string(String(path))))
	audit.check_eq(offenders, [], "hud/no_user_facing_literal_lives_in_the_huds_own_files")

	# The build-time half of the same rule: no colour of its own, no stylebox override,
	# no font-size override — every look comes from a variation.
	var violations: Array = []
	for path in HUD_FILES:
		var source := FileAccess.get_file_as_string(String(path))
		var lines := source.split("\n")
		for index in lines.size():
			var code := String(lines[index]).split("#")[0]
			for token in ["Color(", "add_theme_stylebox_override", "add_theme_font_size_override"]:
				if code.contains(token):
					violations.append("%s:%d %s" % [String(path), index + 1, token])
	audit.check_eq(violations, [], "hud/no_node_carries_a_colour_or_a_stylebox_of_its_own")

	# The scene is a mount, not a second copy of the tree: it carries the script and the
	# theme and no literal of its own.
	var scene_text := FileAccess.get_file_as_string("res://src/ui/Hud.tscn")
	audit.check_true(scene_text.contains("res://src/ui/theme/padel_theme.tres"),
		"hud/the_scene_mounts_uir_02s_theme")
	audit.check_true(scene_text.contains("res://src/ui/Hud.gd"), "hud/the_scene_mounts_the_hud_script")
	audit.check_eq(_offenders_in_source("res://src/ui/Hud.tscn", scene_text), [],
		"hud/the_scene_declares_no_prose_of_its_own")
	audit.report("literal scan files=%d offenders=%d palette_keys=%d" % [HUD_FILES.size(), offenders.size(), 0])


## `res://tests/ui/router_audit.gd:437-455`, same rule, same exemptions.
func _offenders_in_source(path: String, source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		var developer := false
		for marker in DEVELOPER_MARKERS:
			if code.contains(marker):
				developer = true
				break
		if developer:
			continue
		for literal in _literals(code):
			if literal.contains(" ") and not String(literal).contains("res://"):
				out.append("%s:%d \"%s\"" % [path, index + 1, literal])
	return out


func _literals(code: String) -> Array:
	var out: Array = []
	var index := 0
	while index < code.length():
		var char := code[index]
		if char == "\"":
			var value := ""
			index += 1
			while index < code.length() and code[index] != "\"":
				if code[index] == "\\":
					index += 1
				if index < code.length():
					value += code[index]
				index += 1
			out.append(value)
		index += 1
	return out
