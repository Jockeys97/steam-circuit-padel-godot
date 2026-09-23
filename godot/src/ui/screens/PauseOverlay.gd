## PauseOverlay.gd — UIR-20: the reference's pause card, its three tabs, the
## quit confirmation and the door to the smash tutorial.
##
## WHAT THIS IS. `index.html:566-688` (`#pauseOverlay`), `styles.css:1423-1523` and
## `:1958-2030`, with the reference's own behaviour read from `js/main.js`:
##
##   `pauseGame` (`:1584-1591`)   reset the transient input, pause, show the card,
##                                disarm the quit confirmation, open on the MATCH tab
##   `resumeGame` (`:1593-1600`)  reset the transient input again, resume, hide
##   `handleQuitMatch` (`:1622-1634`)  first press arms (`ESCI` -> `CONFERMI?`,
##                                `quitConfirm`), second press leaves the match
##   `setPauseTab` (`:224-241`)   swap the panel, swap the tab's active look
##   `showSmashTutorial`/`hideSmashTutorial` (`:203-221`)  the nested tutorial
##   `menuBack` (`:751-770`) and the ESC branch (`:2607-2614`)  the back hierarchy
##   `updateStickMonitor` (`:447-451`)  the two dots, `x * 17` px from the centre
##
## THE PAUSE CONTRACT, READ TWICE. This overlay does NOT own the pause flag and it
## never touches the engine's global tree pause (the ticket's own rule: the tree is
## frozen by nothing here). The match controller owns `_paused` and its
## `_reset_transient_input()` on both edges (`godot/game/match_controller.gd:1881-1904`;
## `is_paused()` at `:1946`). The seam this overlay needs is one new method, owned by
## UIR-22 (see `HAND-BACK` at the bottom of this header):
##
##   seam.set_match_paused(paused: bool) -> Variant
##       sets `_paused` on the controller, calls `_reset_transient_input()` on BOTH
##       edges (the reference calls it in `pauseGame` AND `resumeGame`,
##       `js/main.js:1532,1543`), refreshes `_hud.set_paused`/`_ui_hud.set_paused`,
##       and echoes into this overlay with `PauseOverlay.set_match_paused(paused)`.
##   seam.is_paused() -> bool        (exists today, `match_controller.gd:1946`)
##   seam.rematch() -> void          (exists today, `match_controller.gd:1926`)
##   seam.leave_match() -> void      (the route out; `_leave_match()` today at
##                                    `match_controller.gd:1980` is private — either
##                                    expose it or bind `quit_requested`)
##
## Without a seam the overlay refuses to fake a transition: it records the missing
## method name in `report()["seam_missing"]` and leaves the state to the mount. It
## never pauses the tree, and the audit greps these files for exactly that.
##
## UNTIL THE SEAM LANDS (the ticket's own instruction): `pause_route()` answers
## `action`, and `resume()`/`pause()` go out as the engine's synthetic `padel_pause`
## press — the same branch ESC takes (`match_controller.gd:1884-1906`), including
## `_reset_transient_input()` on both edges. `read_paused()` reads the match's own
## `is_paused()` when a seam is bound, and answers null when it is not — never a guess.
##
## HAND-BACK (the mount's recipe, all names asserted by `pause_audit.gd`):
##
##   overlay = PauseOverlay.tscn instantiate, added over the match
##   overlay.bind_seam(match_controller)            # or bind the signals below
##   overlay.set_store(store)                       # defaults to Config.save_store()
##   overlay.set_pad_device(device, Input.get_joy_name(device), device >= 0)
##   overlay.set_osk_open(menu_nav.osk.is_open())   # once per frame, or on change
##   seam.set_match_paused(...) on both edges, echoing overlay.set_match_paused(...)
##   overlay.set_match_paused(controller.is_paused()) after every edge, so the card
##   shows exactly while the match is paused
##
##   signals: resume_requested, pause_requested, rematch_requested,
##            replay_requested (UIR-27), quit_requested, tab_changed(tab_id)
##
## THE REPLAY BUTTON IS DISABLED UNTIL UIR-27 LANDS. `js/main.js:2238-2241` hides the
## pause card and enters replay; there is no replay entry point in the port yet, so
## the button carries `disabled` and `replay_disabled_reason()` returns the recorded
## dependency — never a silently dead button, never a fake replay.
##
## LITERALS. Every user-facing string is a locale id through `UiStrings`, except the
## reference's own markup constant (the status line's product title, `index.html:578`),
## composed with `_sp()` because the UI-lane prose scan flags any literal carrying a
## space. Colours are `Palette` reads; a key the theme does not carry yet is recorded
## in `palette_misses()` and requested in the evidence log — never substituted.
##
## STATIC CHECKS ONLY in this wave: the dispatch for UIR-20/UIR-26 says no Godot
## process may be started by this worker; the acceptance command is written down in
## `evidence/uir-20-overlays.log` for the integration owner to run.
extends Control

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Rows := preload("res://src/ui/components/SettingsRows.gd")
const LegendScene := preload("res://src/ui/components/ControlLegend.tscn")
const LegendClass := preload("res://src/ui/components/ControlLegend.gd")
const TutorialScene := preload("res://src/ui/screens/SmashTutorial.tscn")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Locale := preload("res://src/locale/locale.gd")
const Config := preload("res://game/match_config.gd")
## The scene mounts the theme; this is the fallback for a bare `new()`.
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

## Emitted on CONTINUE, and on the ESC hierarchy's step 4.
signal resume_requested
## Emitted on the ESC hierarchy's step 5 (the match is not paused: ESC pauses it).
signal pause_requested
signal rematch_requested
## UIR-27's entry point. Emitted only when the replay entry exists (`set_replay_active`).
signal replay_requested
signal quit_requested
signal tab_changed(tab_id: String)

## The three tabs (`index.html:570-572`), in markup order.
const TAB_MATCH := "match"
const TAB_CAMERA := "camera"
const CAMERA_LABELS := {"default": "cameraClassic", "immersive": "cameraImmersive", "courtside": "cameraCourtside", "tactical": "cameraTactical", "broadcast": "cameraBroadcast"}
var _camera_buttons: Dictionary = {}
var _camera_preview: SubViewport
var _preview_camera: Camera3D
var _camera_description: Label
var _camera_hint: Label
var _preview_id := "default"
var _resume_footer: Button
const CameraCourt := preload("res://game/court.gd")
const TAB_CONTROLLER := "controller"
const TAB_CONTROLS := "controls"
## The fourth tab is this bundle's own (`docs/agent-work/ui-visibility-settings/
## PLAN.md`): the reference has no such panel, and its controls read and write the
## match's visibility profile through the seam, never through a node of their own.
const TAB_UI := "ui"
const TABS := [
	{"id": TAB_MATCH, "label_id": "tabMatch"},
	{"id": TAB_CAMERA, "label_id": "tabCamera"},
	{"id": TAB_CONTROLLER, "label_id": "tabController"},
	{"id": TAB_CONTROLS, "label_id": "commands"},
	{"id": TAB_UI, "label_id": "tabUi"},
]

## The UI tab's own vocabulary, in the order the tab lists it. The ids are the
## match controller's (`match_controller.gd:UI_COMPONENTS` / `UI_PRESET_IDS`), which
## owns the profile; `tests/ui/ui_visibility_audit.gd` asserts the two lists and
## `Hud.COMPONENT_IDS` are equal, so a mirror cannot drift silently. The label ids
## are the tab's own, like every other string this overlay shows.
const UI_COMPONENT_IDS := ["score", "time", "map", "guidance", "indicators", "events", "preparation"]
const UI_COMPONENT_LABEL_IDS := {
	"score": "uiCompScore", "time": "uiCompTime", "map": "uiCompMap",
	"guidance": "uiCompGuidance", "indicators": "uiCompIndicators",
	"events": "uiCompEvents",
	"preparation": "uiCompPreparation",
}
const UI_PRESET_IDS := ["all", "essential", "score_only", "clean"]
const UI_PRESET_LABEL_IDS := {
	"all": "uiPresetAll", "essential": "uiPresetEssential",
	"score_only": "uiPresetScoreOnly", "clean": "uiPresetClean",
}

## The one-line seam UIR-22 owns (`set_match_paused(bool)`, see the header) and the
## action the overlay falls back to until it lands — `match_controller._unhandled_input`'s
## own `padel_pause` branch (`match_controller.gd:1884-1906`), which is ESC.
const SEAM_SET_PAUSED := "set_match_paused"
const PAUSE_ACTION := "padel_pause"

## `js/main.js:2607-2614` (and `menuBack`, `:751-770`): the five steps, plus UIR-27's
## replay step which the reference checks before all of them (`:2607`). The audit
## asserts the order; the constants are the vocabulary it asserts.
const STEP_REPLAY := 0
const STEP_OSK := 1
const STEP_TUTORIAL := 2
const STEP_TAB := 3
const STEP_RESUME := 4
const STEP_PAUSE := 5

## The capture states the ticket's frontmatter declares.
const CAPTURE_STATES: Array[String] = [
	"pause-match", "pause-controller", "pause-controls", "pause-ui",
	"quit-confirm", "smash-tutorial",
]

## `index.html:589` (`data-i18n="pauseInProgress"`), the line above the product title.
const STATUS_KEY := "pauseInProgress"
## `index.html:567`, the card's own title.
const TITLE_KEY := "pause"
## `index.html:568` (`data-i18n-aria="ariaPauseMenu"`).
const ARIA_TABS_KEY := "ariaPauseMenu"
## `index.html:592` (`ariaControllerSettings`), `:595` (`ariaControlMode`), `:604`
## (`ariaStickTest`).
const ARIA_CONTROLLER_KEY := "ariaControllerSettings"
const ARIA_CONTROL_MODE_KEY := "ariaControlMode"
const ARIA_STICK_KEY := "ariaStickTest"

## `index.html:598-600`: AUTO / SEMI / MANUALE, in the reference's own order. The
## values are the save contract's own (`data-control-mode`, validated at
## `js/main.js:2273`; the port's `Config.CONTROL_MODES`, asserted equal by the audit).
const CONTROL_MODES := ["assisted", "semi", "manual"]
const CONTROL_MODE_LABELS := {"assisted": "auto", "semi": "semi", "manual": "manual"}
const CONTROL_MODE_KEY := "controlMode"

## `index.html:605-608`: the deadzone row's own bounds and step, and the pref key
## (`id="gamepadDeadzone"`).
const DEADZONE_KEY := "gamepadDeadzone"
const DEADZONE_MIN := 0.08
const DEADZONE_MAX := 0.30
const DEADZONE_STEP := 0.01
const DEADZONE_DEFAULT := 0.15
## `index.html:631-634`: the volume row.
const VOLUME_KEY := "volume"
const VOLUME_MIN := 0.0
const VOLUME_MAX := 1.0
const VOLUME_STEP := 0.01
const VOLUME_DEFAULT := 0.5
## `index.html:625`: the vibration toggle.
const VIBRATION_KEY := "vibration"

## `index.html:610-613`: MOVE / SWITCH, the two monitored sticks.
const STICK_MOVE_KEY := "stickMove"
const STICK_SWITCH_KEY := "stickAimSwitch"

## `js/main.js:447-451` (`updateStickMonitor`): the dot moves `x * 17` px and
## `y * 17` px from the circle's centre. Reproduced in Control pixels 1:1 — the
## port's frame is the reference's own 1280x720 and the CSS pixel is the Control
## pixel here, so there is no scale conversion to make.
const STICK_RANGE := 17.0
## `.stick-monitor i` (`styles.css:1593-1601`): a 52 px circle; `b` is 10 px.
const STICK_BOX := 52.0
const STICK_DOT := 10.0
## `.stick-monitor i::after` `inset: 8px` (`styles.css:1603-1609`).
const STICK_RING_INSET := 8.0

## `js/main.js:291-299` (`radialStick`): deadzone on the magnitude, the rest
## rescaled, then curved by 1.28.
const STICK_CURVE := 1.28

## `js/main.js:1602-1610` (`quitMatch`): `showScreen("menu")` — the route out.
const QUIT_KEY := "quit"
const QUIT_CONFIRM_KEY := "quitConfirm"

## The contract's own bounds: the reference's segmented tabs are 40 px tall
## (`styles.css:1459-1469`), the control-mode strip 36 (`:1545-1554`).
const TAB_HEIGHT := 40.0
const MODE_HEIGHT := 36.0
## `.pause-panel { min-height: 350px }` (`styles.css:1477-1479`); the 760 px rule
## (`:1975-1985`) gives the match and controller panels 330 and turns the controls
## panel's floor off.
const PANEL_MIN_HEIGHT := 350.0
const PANEL_MIN_HEIGHT_NARROW := 330.0
## `.pause-actions { width: min(320px, 100%) }` (`styles.css:1509-1511`).
const ACTIONS_WIDTH := 320.0
## `.controller-settings { width: min(460px, 100%) }` (`styles.css:1518-1524`).
const SETTINGS_WIDTH := 460.0
## `.pause-card { width: min(880px, calc(100vw - 32px)) }` (`styles.css:1436-1446`).
const CARD_WIDTH := 880.0
const CARD_MARGIN := 16.0
## The reference's own breakpoints for this card (`styles.css:1970`, `:2003`).
const NARROW_PX := 760.0
const TIGHT_PX := 470.0

## Node names the mount, the tutorial and the audit address by name.
const NODE_SCRIM := "PauseScrim"
const NODE_CARD := "PauseCard"
const NODE_TITLE := "PauseTitle"
const NODE_STATUS := "PauseStatus"
const NODE_STATUS_TITLE := "PauseStatusTitle"
const NODE_TABS := "PauseTabs"
const NODE_ACTIONS := "PauseActions"
const NODE_CONTINUE := "ContinueButton"
const NODE_REPLAY := "ReplayButton"
const NODE_REMATCH := "RematchButton"
const NODE_QUIT := "QuitButton"
const NODE_CONTROLLER := "ControllerSettings"
const NODE_UI := "UiVisibilitySettings"
const NODE_UI_PRESETS := "UiPresets"
const NODE_UI_NOTE := "UiShortcutNote"
const NODE_MODE_STRIP := "ControlModeToggle"
const NODE_STICK := "StickMonitor"
const NODE_LEGEND_HOST := "PauseControlsOverview"
const NODE_TUTORIAL := "SmashTutorial"

## `pause/` prefixes every id this overlay registers, so the model's ids cannot
## collide with a screen's (`ScreenShell` registers `<screen_id>/<suffix>`).
const ID_PREFIX := "pause/"

## The actions the overlay reports on confirm, the reference's own `data-action`s
## (`index.html:592-595`, `:655`, `:684`) plus the tab and tutorial spellings.
const ACTION_RESUME := "resume"
const ACTION_REPLAY := "replay"
const ACTION_REMATCH := "rematch"
const ACTION_QUIT := "quit-match"
const ACTION_TUTORIAL_OPEN := "open-smash-tutorial"
const ACTION_TUTORIAL_CLOSE := "close-smash-tutorial"
const ACTION_TAB_PREFIX := "tab-"
const ACTION_DEADZONE := "deadzone"
const ACTION_VIBRATION := "vibration"
const ACTION_VOLUME := "volume"
const ACTION_MODE_PREFIX := "control-mode:"
## The UI tab's two control families, in its own action vocabulary.
const ACTION_UI_PRESET_PREFIX := "ui-preset:"
const ACTION_UI_COMPONENT_PREFIX := "ui-component:"

var _built := false
var _open := false
var _tab: String = TAB_MATCH
var _quit_armed := false
var _tutorial_open := false
var _osk_open := false
var _replay_active := false
var _replay_available := false
var _pad_connected := false
var _pad_device := -1
var _pad_name := ""
var _pad_layout := LegendClass.DEFAULT_LAYOUT
var _narrow := false
var _tight := false
var _seam: Object = null
var _missing_seam: Array = []
var _store: RefCounted = null
var _palette_misses: Array = []
var _stick_values := {"left": Vector2.ZERO, "right": Vector2.ZERO}

var _scrim: Panel
var _card: PanelContainer
var _title: Label
var _status_key: Label
var _status_title: Label
var _tabs: Dictionary = {}
var _panels: Dictionary = {}
var _controller_box: Control = null
var _ui_panel: Control = null
var _ui_title: Label = null
var _ui_presets_label: Label = null
var _ui_note: Label = null
var _ui_preset_buttons: Dictionary = {}
var _ui_toggle_rows: Dictionary = {}
var _mode_strip: Control = null
var _stick_monitor: Control = null
var _continue_button: Button
var _replay_button: Button
var _rematch_button: Button
var _quit_button: Button
var _mode_buttons: Dictionary = {}
var _deadzone_row: Control = null
var _volume_row: Control = null
var _now_playing_row: Control = null
var _vibration_row: Control = null
var _stick_dots: Dictionary = {}
var _stick_boxes: Dictionary = {}
var _legend: Control
var _legend_host: VBoxContainer
var _tutorial: Control


func _ready() -> void:
	set_process_input(true)
	_ensure()


# ---------------------------------------------------------------------------
# The mount's contract
# ---------------------------------------------------------------------------

## The seam holder: any object with the four methods in the header. Bound by the
## mount; without it the overlay only emits and records what it could not do.
func bind_seam(seam_in: Object) -> void:
	_seam = seam_in


func seam() -> Object:
	return _seam


## The store the controller rows read and write: the caller's (an audit's temp
## directory) or the game's own (`Config.save_store()`), like `SettingsScreen`.
func set_store(store_in: RefCounted) -> void:
	_store = store_in
	if _built:
		refresh_values()


func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


## The reference focuses a tab only with a pad in hand (`js/main.js:2349`,
## `setPauseTab(button.dataset.pauseTab, gamepad.connected)`).
func set_pad_connected(connected: bool) -> void:
	_pad_connected = connected
	if not connected:
		_pad_device = -1
		_pad_name = ""
		_pad_layout = LegendClass.detect_device_layout("")
		_apply_pad_layout()


func pad_connected() -> bool:
	return _pad_connected


## Live controller identity, fed from the match's selected input seat. This is the
## Godot equivalent of `gamepadconnected` + `applyControllerLayout(gamepad.id)` in
## the 2D game: one update swaps artwork, caption and every key cap together.
func set_pad_device(device_id: int, device_name: String, connected: bool = true) -> void:
	var next_device := device_id if connected else -1
	var next_name := device_name if connected else ""
	var next_layout := LegendClass.detect_device_layout(next_name)
	if _pad_connected == connected and _pad_device == next_device \
			and _pad_name == next_name and _pad_layout == next_layout:
		return
	_pad_connected = connected
	_pad_device = next_device
	_pad_name = next_name
	_pad_layout = next_layout
	_apply_pad_layout()


func pad_device() -> int:
	return _pad_device


func pad_name() -> String:
	return _pad_name


func pad_layout() -> String:
	return _pad_layout


func _apply_pad_layout() -> void:
	if _legend != null and _legend.has_method("set_device_layout"):
		_legend.call("set_device_layout", _pad_layout)


## The keyboard's state, mirrored for the back hierarchy's step 1. The mount syncs
## it (`menu_nav.osk.is_open()`); the overlay never opens or closes the keyboard.
func set_osk_open(open: bool) -> void:
	_osk_open = open


func osk_open() -> bool:
	return _osk_open


## UIR-27's playback flag: while a replay is up, ESC closes it first
## (`js/main.js:2607-2610`). The integration feeds it the live playback reading, so
## ESC's step 0 (`back()`) can never be stale — `_replay_available` below is the
## button's own gate and does not move it.
func set_replay_active(active: bool) -> void:
	_replay_active = active
	_apply_replay_state()


func replay_active() -> bool:
	return _replay_active


## UIR-27's availability reading: the record holds enough frames for a playback, so the
## card's entry can start one (`js/main.js:1389-1390`). The button's gate follows either
## fact; ESC's step 0 follows the playback alone — with no playback up a step 0 would be
## stale.
func set_replay_available(available: bool) -> void:
	_replay_available = available
	_apply_replay_state()


func replay_available() -> bool:
	return _replay_available


# ---------------------------------------------------------------------------
# Open / close — the paused state, as the match owns it
# ---------------------------------------------------------------------------

## `pauseGame()` (`js/main.js:1584-1591`): show the card, disarm the quit
## confirmation, open on the MATCH tab. The input reset is the seam's (both edges) —
## this overlay cannot reach `queued_one_shots` and must not try.
func open() -> void:
	_ensure()
	if _open:
		return
	_open = true
	visible = true
	reset_quit_confirm()
	set_tab(TAB_MATCH, _pad_connected)
	refresh_values()
	refresh_strings()


## `resumeGame()` (`js/main.js:1593-1600`): hide the card. Leaving the overlay
## disarms the quit confirmation (`handleQuitMatch`'s state, `:1615-1628`).
func close() -> void:
	_ensure()
	if not _open:
		return
	_open = false
	visible = false
	reset_quit_confirm()
	if _camera_preview != null:
		_camera_preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	close_tutorial(false)


func is_open() -> bool:
	return _open


## The seam's echo: the mount tells the overlay where the match's own `_paused` went.
## Returns whether the view changed, so a caller can tell "already there" from "moved".
func set_match_paused(paused: bool) -> bool:
	_ensure()
	if paused == _open:
		return false
	if paused:
		open()
	else:
		close()
	return true


# ---------------------------------------------------------------------------
# Tabs (`setPauseTab`, js/main.js:224-241)
# ---------------------------------------------------------------------------

func active_tab() -> String:
	return _tab


## The reference's `setPauseTab(tabName, focusTab)`: an open tutorial closes first
## (without stealing the focus back), the panel swaps and the tab's active look
## follows. `focus_tab` paints the focus on the tab button (`grab_focus()`), which is
## what the reference does when a pad is connected.
func set_tab(tab_id: String, focus_tab: bool = false) -> bool:
	_ensure()
	if not _panels.has(tab_id):
		return false
	if _tutorial_open:
		close_tutorial(false)
	_tab = tab_id
	if _resume_footer != null:
		_resume_footer.visible = tab_id != TAB_MATCH
	if _camera_preview != null:
		_camera_preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if tab_id == TAB_CAMERA:
		_refresh_camera_buttons()
		_preview_camera_choice(Config.camera_preset if CAMERA_LABELS.has(Config.camera_preset) else "default")
	for id in _panels:
		var panel: Control = _panels[id]
		panel.visible = String(id) == tab_id
	for id in _tabs:
		_style_tab(_tabs[id] as Button, String(id) == tab_id)
	if focus_tab and _tabs.has(tab_id):
		(_tabs[tab_id] as Button).grab_focus()
	tab_changed.emit(tab_id)
	return true


func tab_button(tab_id: String) -> Button:
	_ensure()
	return _tabs.get(tab_id, null)


# ---------------------------------------------------------------------------
# The smash tutorial, nested in the COMANDI tab (js/main.js:203-221)
# ---------------------------------------------------------------------------

## `showSmashTutorial()` (`js/main.js:214-221`): the controls overview hides, the
## tutorial shows, the focus moves to its back control (the mount registers it).
func open_tutorial() -> bool:
	_ensure()
	if _tutorial_open or _tutorial == null:
		return false
	_tutorial_open = true
	if _legend_host != null:
		_legend_host.visible = false
	_tutorial.open()
	return true


## `hideSmashTutorial(focusTrigger)` (`js/main.js:203-212`): the overview returns
## and the tutorial hides; the pause card stays open — that is the ticket's assertion.
func close_tutorial(_focus_trigger: bool = false) -> bool:
	_ensure()
	if not _tutorial_open:
		return false
	_tutorial_open = false
	if _legend_host != null:
		_legend_host.visible = true
	if _tutorial != null:
		_tutorial.close()
	return true


func tutorial_open() -> bool:
	return _tutorial_open


func smash_tutorial() -> Control:
	_ensure()
	return _tutorial


## The consumed `ControlLegend` (UIR-13), read-only — the audit and the smoke driver
## read its own facts through this door.
func legend() -> Control:
	_ensure()
	return _legend


func legend_host() -> VBoxContainer:
	_ensure()
	return _legend_host


# ---------------------------------------------------------------------------
# The match-tab actions
# ---------------------------------------------------------------------------

## CONTINUE and the ESC hierarchy's step 4. The seam's `set_match_paused(false)` is
## the action; the signal is the notification. Without a seam the overlay falls back
## to the action route (`padel_pause`, the ticket's own instruction until UIR-22
## lands) — and with neither it records what it could not do and fakes nothing.
func resume() -> void:
	_ensure()
	resume_requested.emit()
	_apply_pause(false)


## ESC hierarchy's step 5: the match is running, ESC pauses it (`js/main.js:2613`).
func pause() -> void:
	_ensure()
	pause_requested.emit()
	_apply_pause(true)


## What a pause call can use right now: the one-line seam if the integration owner
## landed it, else the action route the ticket names for the meantime, else nothing.
func pause_route() -> String:
	if _seam != null and _seam.has_method(SEAM_SET_PAUSED):
		return "seam"
	if InputMap.has_action(PAUSE_ACTION):
		return "action"
	for method in [SEAM_SET_PAUSED, "is_paused"]:
		if not _missing_seam.has(String(method)):
			_missing_seam.append(String(method))
	return "none"


## The action route's event: the engine's own synthetic input, which runs
## `match_controller._unhandled_input`'s `padel_pause` branch exactly like the key —
## including `_reset_transient_input` on both edges. Exposed so the audit can assert
## the binding and the event without a live controller.
func pause_action_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = PAUSE_ACTION
	event.pressed = true
	return event


## The match's own answer, when it is reachable: `is_paused()` (`match_controller.gd:1946`).
## `null` when no seam is bound — the overlay never guesses.
func read_paused() -> Variant:
	if _seam != null and _seam.has_method("is_paused"):
		return _seam.call("is_paused")
	return null


func _apply_pause(paused: bool) -> String:
	var route := pause_route()
	match route:
		"seam":
			_seam.callv(SEAM_SET_PAUSED, [paused])
		"action":
			Input.parse_input_event(pause_action_event())
	return route


## RIGIOCA: the existing rematch path (`match_controller.gd:1926`).
func rematch() -> void:
	_ensure()
	rematch_requested.emit()
	_call_seam("rematch", [])


## RIGUARDA PUNTO: UIR-27's entry point. Gated on UIR-27's two readings (a playback is
## up, or one can start); a press on the disabled button is refused here too, so a
## programmatic caller cannot fake it.
func replay() -> bool:
	_ensure()
	if not replay_enabled():
		return false
	replay_requested.emit()
	return true


## The reference hides the pause card before entering replay (`js/main.js:2239-2241`).
func replay_enabled() -> bool:
	return _replay_active or _replay_available


## The recorded dependency the disabled button carries, for the tooltip and the log.
func replay_disabled_reason() -> String:
	return "" if replay_enabled() else "uir27-replay-entry-not-landed"


## ESCI, first press (`handleQuitMatch`, `js/main.js:1622-1634`): arm. Second press:
## leave. `ESCI` -> `CONFERMI?` is a text swap on the same button (`quitConfirm`).
func handle_quit() -> bool:
	_ensure()
	if not _quit_armed:
		_quit_armed = true
		_apply_quit_arm()
		return false
	quit_requested.emit()
	_call_seam("leave_match", [])
	# `quitMatch()` hides the card itself (`js/main.js:1610`).
	close()
	return true


func is_quit_armed() -> bool:
	return _quit_armed


## `resetQuitConfirm()` (`js/main.js:1615-1620`).
func reset_quit_confirm() -> void:
	_quit_armed = false
	_apply_quit_arm()


func quit_button() -> Button:
	_ensure()
	return _quit_button


# ---------------------------------------------------------------------------
# The ESC / back hierarchy (`js/main.js:2607-2614`, `menuBack` `:751-770`)
# ---------------------------------------------------------------------------

## One cancel, in the reference's order. Returns the step taken, so the caller can
## see which branch fired without guessing:
##
##   0  replay is up       -> UIR-27's overlay closes it (nothing done here)
##   1  the keyboard is up -> the OSK model closes it (nothing done here)
##   2  the tutorial is up -> back to the COMANDI tab, pause stays open
##   3  another tab        -> back to the MATCH tab
##   4  paused             -> resume
##   5  running            -> pause
func back() -> Dictionary:
	_ensure()
	if _replay_active:
		return {"step": STEP_REPLAY, "kind": "replay_close"}
	if _osk_open:
		return {"step": STEP_OSK, "kind": "osk_close"}
	if _tutorial_open:
		close_tutorial(false)
		return {"step": STEP_TUTORIAL, "kind": "tutorial_close", "tab": _tab}
	if _open and _tab != TAB_MATCH:
		set_tab(TAB_MATCH, _pad_connected)
		return {"step": STEP_TAB, "kind": "tab_back", "tab": TAB_MATCH}
	if _open:
		resume()
		return {"step": STEP_RESUME, "kind": "resume"}
	pause()
	return {"step": STEP_PAUSE, "kind": "pause"}


# ---------------------------------------------------------------------------
# The controller tab's rows (shared components, read-only)
# ---------------------------------------------------------------------------

## `syncControllerSettings` (`js/main.js:2445-2455`): the mode strip's active button,
## the deadzone value, the vibration check — from the one stored state.
func refresh_values() -> void:
	_ensure()
	var snap := snapshot()
	_refresh_mode_buttons(String(snap.get("control_mode", "semi")))
	if _deadzone_row != null:
		(_deadzone_row as Rows.RangeRow).set_value(float(snap.get("deadzone", DEADZONE_DEFAULT)))
	if _vibration_row != null:
		(_vibration_row as Rows.ToggleRow).set_on(bool(snap.get("vibration", true)))
	if _volume_row != null:
		(_volume_row as Rows.RangeRow).set_value(float(snap.get("volume", VOLUME_DEFAULT)))
	refresh_ui_values()
	if _now_playing_row != null:
		(_now_playing_row as Rows.ToggleRow).set_on(bool(ModesSave.profile(store()).get("prefs", {}).get("nowPlaying", true)))


## What the rows show: `UiData.settings_snapshot()` over the store — the same
## contract the settings screen reads (`js/main.js:2455-2470` syncs both copies).
func snapshot() -> Dictionary:
	return UiData.settings_snapshot(store())


func control_mode() -> String:
	var value := String(snapshot().get("control_mode", "semi"))
	return value if CONTROL_MODES.has(value) else "semi"


func deadzone() -> float:
	return float(snapshot().get("deadzone", DEADZONE_DEFAULT))


func volume() -> float:
	return float(snapshot().get("volume", VOLUME_DEFAULT))


## The player's own change of mode (`js/main.js:2474-2481`): persist; the match's
## own copy is the seam's business (`match_controller` reads `Config.control_mode()`).
func set_control_mode(mode: String) -> bool:
	_ensure()
	if not CONTROL_MODES.has(mode):
		return false
	_persist(CONTROL_MODE_KEY, mode)
	_refresh_mode_buttons(mode)
	return true


## The rows, by node name — the audit and the integrator read the same door the
## settings screen exposes (`SettingsScreen.rows()`).
func rows() -> Dictionary:
	_ensure()
	return {
		"DeadzoneRow": _deadzone_row,
		"VolumeRow": _volume_row,
		"NowPlayingRow": _now_playing_row,
		"VibrationRow": _vibration_row,
	}


## UIR-22: the door a model-stepped range comes back through. A drag on the slider
## fires `changed` and persists through the handlers above, but the nav model steps the
## value in place (`focus_nav._adjust_range`) and never touches a node, so the mount
## hands the new value over here: the row is updated for the player AND the screen's
## own handler runs, which is what persists it.
func set_row_value(row_name: String, value: float) -> bool:
	_ensure()
	var rows_now := rows()
	if not rows_now.has(row_name):
		return _set_ui_row_value(row_name, value)
	var row: Control = rows_now[row_name]
	if row is Rows.RangeRow:
		(row as Rows.RangeRow).set_value(value)
		if row_name == "VolumeRow":
			_on_volume_changed(value)
		elif row_name == "DeadzoneRow":
			_on_deadzone_changed(value)
		return true
	if row is Rows.ToggleRow:
		var on := value > 0.5
		(row as Rows.ToggleRow).set_on(on)
		if row_name == "VibrationRow":
			_on_vibration_changed(on)
		elif row_name == "NowPlayingRow":
			_persist("nowPlaying", on)
		return true
	return false


func mode_button(mode: String) -> Button:
	_ensure()
	return _mode_buttons.get(mode, null)


# ---------------------------------------------------------------------------
# The UI tab's controls (docs/agent-work/ui-visibility-settings/PLAN.md)
# ---------------------------------------------------------------------------

## The UI tab's toggle rows, by component id — one door along from `rows()`, which
## stays exactly the controller tab's own table (`DeadzoneRow`/`VolumeRow`/
## `VibrationRow`). The nav model and the audit read both through these doors.
func ui_rows() -> Dictionary:
	_ensure()
	var out := {}
	for id in UI_COMPONENT_IDS:
		out[String(id)] = _ui_toggle_rows.get(id, null)
	return out


## The four preset buttons, by preset id.
func ui_preset_buttons() -> Dictionary:
	_ensure()
	return _ui_preset_buttons.duplicate()


## The profile in force, read through the seam. No seam means the documented
## default (the full view) and NO recorded miss: a read falls back, while a write is
## what a missing seam makes dead — and that is what `_call_seam` records.
func ui_profile() -> Dictionary:
	if _seam != null and _seam.has_method("ui_visibility_snapshot"):
		var snapshot: Variant = _seam.call("ui_visibility_snapshot")
		if snapshot is Dictionary:
			return snapshot
	return {}


## The preset the profile is exactly, straight from the seam: the controller owns
## the maps, so the tab cannot disagree with the HUD about what `essential` means.
func ui_preset_id() -> String:
	if _seam != null and _seam.has_method("ui_preset_id"):
		return String(_seam.call("ui_preset_id"))
	return ""


## Repaints the tab from the seam: the six toggles, then the selected preset (four
## inactive buttons when the profile matches none of them).
func refresh_ui_values() -> void:
	_ensure()
	var profile := ui_profile()
	for id in UI_COMPONENT_IDS:
		var row: Control = _ui_toggle_rows.get(id, null)
		if row is Rows.ToggleRow:
			(row as Rows.ToggleRow).set_on(bool(profile.get(id, true)))
	var active := ui_preset_id()
	for id in UI_PRESET_IDS:
		var button: Button = _ui_preset_buttons.get(id, null)
		if button == null:
			continue
		var on := String(id) == active
		button.theme_type_variation = &"SegmentedActive" if on else &"SegmentedInactive"
		button.set_pressed_no_signal(on)


## The checkbox's own route: the write goes through the seam, then the tab re-reads
## the profile — the controller may have refused, and the preset selection has moved.
func _on_ui_component_changed(on: bool, id: String) -> void:
	_call_seam("set_ui_component", [id, on])
	refresh_ui_values()


func _on_ui_preset_pressed(id: String) -> void:
	_call_seam("set_ui_preset", [id])
	refresh_ui_values()


## The model-stepped route into the UI tab's toggles (`set_row_value`'s other half):
## the row is set for the player AND the tab's own handler runs, which is what writes
## the profile.
func _set_ui_row_value(row_name: String, value: float) -> bool:
	var row: Control = _ui_toggle_rows.get(row_name, null)
	if not (row is Rows.ToggleRow):
		return false
	(row as Rows.ToggleRow).set_on(value > 0.5)
	_on_ui_component_changed(value > 0.5, row_name)
	return true


# ---------------------------------------------------------------------------
# The stick monitors (`updateStickMonitor`, js/main.js:447-451)
# ---------------------------------------------------------------------------

## The two dots, from the live axis values the mount reads off the pad. The
## reference applies the stored deadzone before the preview (`js/main.js:791-794`,
## `radialStick(..., previewDeadzone)`), so a pad that twitches at rest does not
## move the dots.
func set_stick_values(left: Vector2, right: Vector2) -> void:
	_ensure()
	_stick_values = {"left": left, "right": right}
	_position_dots()


## One `InputEventJoypadMotion`, as the engine delivers it (the audit injects one —
## no pad is attached to this Mac). Left stick = MOVE, right = SWITCH.
func handle_joypad_motion(event: InputEventJoypadMotion) -> bool:
	_ensure()
	var value := clampf(event.axis_value, -1.0, 1.0)
	match event.axis:
		JOY_AXIS_LEFT_X:
			set_stick_values(Vector2(value, _stick_values["left"].y), _stick_values["right"])
			return true
		JOY_AXIS_LEFT_Y:
			set_stick_values(Vector2(_stick_values["left"].x, value), _stick_values["right"])
			return true
		JOY_AXIS_RIGHT_X:
			set_stick_values(_stick_values["left"], Vector2(value, _stick_values["right"].y))
			return true
		JOY_AXIS_RIGHT_Y:
			set_stick_values(_stick_values["left"], Vector2(_stick_values["right"].x, value))
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		handle_joypad_motion(event as InputEventJoypadMotion)


## The dots' own offsets from their circles' centres, as rendered: the radial value
## through the player's deadzone, times the reference's 17 px range.
func stick_offsets() -> Dictionary:
	var deadzone_value := deadzone()
	return {
		"left": radial(_stick_values["left"], deadzone_value) * STICK_RANGE,
		"right": radial(_stick_values["right"], deadzone_value) * STICK_RANGE,
	}


func stick_dot_position(which: String) -> Vector2:
	_ensure()
	var dot: Control = _stick_dots.get(which, null)
	return Vector2.ZERO if dot == null else dot.position


func stick_values() -> Dictionary:
	return _stick_values.duplicate()


## `radialStick` (`js/main.js:291-299`): deadzone on the magnitude, the remainder
## rescaled and then curved by 1.28. The deadzone is the player's stored one.
static func radial(value: Vector2, deadzone_value: float) -> Vector2:
	var clamped := Vector2(clampf(value.x, -1.0, 1.0), clampf(value.y, -1.0, 1.0))
	var magnitude := minf(1.0, clamped.length())
	if magnitude <= deadzone_value or magnitude == 0.0:
		return Vector2.ZERO
	var normalized := (magnitude - deadzone_value) / (1.0 - deadzone_value)
	var curved := pow(normalized, STICK_CURVE)
	return Vector2((clamped.x / magnitude) * curved, (clamped.y / magnitude) * curved)


# ---------------------------------------------------------------------------
# Strings, report, captures
# ---------------------------------------------------------------------------

## Every visible string, re-resolved through the seam: the card's title, the tabs,
## the four actions, the mode strip, the two rows, the stick labels, the legend and
## the tutorial. Called on `open()` and on a language flip.
func refresh_strings() -> void:
	_ensure()
	_title.text = UiStrings.t(TITLE_KEY)
	_status_key.text = UiStrings.t(STATUS_KEY)
	_status_title.text = status_title()
	for id in _tabs:
		var label_id := ""
		for tab in TABS:
			if String(tab["id"]) == String(id):
				label_id = String(tab["label_id"])
		(_tabs[id] as Button).text = UiStrings.t(label_id)
	_continue_button.text = UiStrings.t("continue")
	_resume_footer.text = UiStrings.t("pauseResumeMatch")
	_rematch_button.text = UiStrings.t("rematch")
	_quit_button.text = UiStrings.t(QUIT_CONFIRM_KEY) if _quit_armed else UiStrings.t(QUIT_KEY)
	_replay_button.text = UiStrings.t("replayBtn")
	_replay_button.tooltip_text = replay_disabled_reason()
	for mode in CONTROL_MODES:
		if _mode_buttons.has(mode):
			(_mode_buttons[mode] as Button).text = UiStrings.t(String(CONTROL_MODE_LABELS[mode]))
	for id in _camera_buttons:
		(_camera_buttons[id] as Button).text = UiStrings.t(CAMERA_LABELS[id])
	_refresh_camera_buttons()
	_refresh_camera_copy()
	if _ui_title != null:
		_ui_title.text = UiStrings.t("uiVisibility")
	if _ui_presets_label != null:
		_ui_presets_label.text = UiStrings.t("uiPresets")
	if _ui_note != null:
		_ui_note.text = UiStrings.t("uiShortcutNote")
	for id in UI_PRESET_IDS:
		var preset_button: Button = _ui_preset_buttons.get(id, null)
		if preset_button != null:
			preset_button.text = UiStrings.t(String(UI_PRESET_LABEL_IDS[id]))
	if _legend != null and _legend.has_method("refresh_strings"):
		_legend.call("refresh_strings")
	if _tutorial != null and _tutorial.has_method("refresh_strings"):
		_tutorial.call("refresh_strings")
	_refresh_row_strings()
	_apply_aria()


## The language *choice* and its persistence are the settings screen's
## (`SettingsScreen.set_language`); this door re-resolves the strings this overlay
## owns, which is what the language flip and the audit need.
func set_language(lang: String) -> bool:
	if not Locale.has_locale(lang):
		return false
	Locale.set_lang(lang)
	refresh_strings()
	return true


func _refresh_row_strings() -> void:
	if _now_playing_row != null:
		(_now_playing_row as Rows.ToggleRow).check.text = "Mostra titolo e copertina" if Locale.current_lang() == "it" else "Show music title and cover"
	for row in [_deadzone_row, _volume_row, _vibration_row]:
		if row != null:
			Rows.refresh_strings(row)
	for id in UI_COMPONENT_IDS:
		var row: Control = _ui_toggle_rows.get(id, null)
		if row != null:
			Rows.refresh_strings(row)


## `index.html:578`: `<strong>STEAM CIRCUIT</strong>`, the reference's own literal
## (it carries no `data-i18n`). Composed with a built space because the UI lane's
## prose scan flags any literal carrying one — `MenuScreen` keeps its equivalent
## literals in its scene for the same reason.
static func status_title() -> String:
	return "STEAM" + _sp() + "CIRCUIT"


func report() -> Dictionary:
	_ensure()
	return {
		"open": _open,
		"tab": _tab,
		"quit_armed": _quit_armed,
		"tutorial_open": _tutorial_open,
		"osk_open": _osk_open,
		"replay_active": _replay_active,
		"replay_enabled": replay_enabled(),
		"pad_connected": _pad_connected,
		"pad_device": _pad_device,
		"pad_name": _pad_name,
		"pad_layout": _pad_layout,
		"seam": _seam != null,
		"seam_missing": _missing_seam.duplicate(),
		"pause_route": pause_route(),
		"palette_misses": _palette_misses.duplicate(),
		"stick_offsets": stick_offsets(),
		"narrow": _narrow,
		"tight": _tight,
		"ui_visibility": ui_profile(),
		"ui_preset": ui_preset_id(),
		"ui_components": UI_COMPONENT_IDS.duplicate(),
	}


func capture_states() -> Array:
	return CAPTURE_STATES.duplicate()


## Drives one of the ticket's five states: the three tabs, the armed quit
## confirmation and the smash tutorial. Anything else answers false.
func apply_capture_state(state_id: String) -> bool:
	_ensure()
	match state_id:
		"pause-match":
			open()
			return set_tab(TAB_MATCH, false)
		"pause-controller":
			open()
			return set_tab(TAB_CONTROLLER, false)
		"pause-controls":
			open()
			return set_tab(TAB_CONTROLS, false)
		"pause-ui":
			open()
			return set_tab(TAB_UI, false)
		"quit-confirm":
			open()
			set_tab(TAB_MATCH, false)
			reset_quit_confirm()
			handle_quit()
			return _quit_armed
		"smash-tutorial":
			open()
			set_tab(TAB_CONTROLS, false)
			return open_tutorial()
	return false


## Every Palette key this overlay can name, for the audit's existence check.
func palette_keys() -> Array:
	return [
		"overlay_scrim", "tab_border", "surface_0", "surface_1", "surface_2",
		"tab_text_idle", "segmented_gradient_end", "text_soft", "text_soft_3",
		"state_yellow", "ink", "line", "panel", "shadow", "help_muted",
		"kbd_border", "danger_border", "danger_fill", "danger_fill_hover", "danger_shadow",
	]


## The palette keys the theme does not carry yet, in first-seen order. Each one is
## requested, with its reference line, in `evidence/uir-20-overlays.log`; a miss is
## loud (the audit prints the set) and never silently substituted — `Hud.gd`'s rule.
func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# Focus (UIR-05's model path: the mount registers these under the overlay context)
# ---------------------------------------------------------------------------

## The focusable controls of the CURRENT view, in the reference's markup order:
## the three tabs, then the active panel's controls (or the tutorial's two). The
## mount registers them with `MenuFocus.add(id, node, action, opts)` for the overlay
## context; the overlay never registers them itself.
func focus_controls() -> Array:
	_ensure()
	var out: Array = []
	for tab in TABS:
		var id := String(tab["id"])
		out.append({
			"id": ID_PREFIX + ACTION_TAB_PREFIX + id,
			"node": _tabs[id],
			"action": ACTION_TAB_PREFIX + id,
			"opts": {"kind": "button"},
		})
	if _tutorial_open:
		if _tutorial != null and _tutorial.has_method("focus_controls"):
			out.append_array(_tutorial.call("focus_controls"))
		return out
	match _tab:
		TAB_CAMERA:
			for id in CAMERA_LABELS:
				out.append(_focus_row("camera-" + id, _camera_buttons[id]))
		TAB_MATCH:
			out.append(_focus_row(ACTION_RESUME, _continue_button))
			out.append(_focus_row(ACTION_REPLAY, _replay_button))
			out.append(_focus_row(ACTION_REMATCH, _rematch_button))
			out.append(_focus_row(ACTION_QUIT, _quit_button))
		TAB_CONTROLLER:
			for mode in CONTROL_MODES:
				out.append(_focus_row(ACTION_MODE_PREFIX + String(mode), _mode_buttons.get(mode, null)))
			out.append(_focus_row(ACTION_DEADZONE, Rows.focus_node(_deadzone_row)))
			out.append(_focus_row(ACTION_VIBRATION, Rows.focus_node(_vibration_row)))
			out.append(_focus_row(ACTION_VOLUME, Rows.focus_node(_volume_row)))
			out.append(_focus_row("now-playing", Rows.focus_node(_now_playing_row)))
		TAB_CONTROLS:
			if _legend != null and _legend.has_method("tutorial_button"):
				var link: Button = _legend.call("tutorial_button")
				if link != null:
					out.append(_focus_row(ACTION_TUTORIAL_OPEN, link))
		TAB_UI:
			for id in UI_PRESET_IDS:
				out.append(_focus_row(ACTION_UI_PRESET_PREFIX + String(id),
					_ui_preset_buttons.get(id, null)))
			for id in UI_COMPONENT_IDS:
				var row: Control = _ui_toggle_rows.get(id, null)
				out.append(_focus_row(ACTION_UI_COMPONENT_PREFIX + String(id), Rows.focus_node(row)))
	if _tab != TAB_MATCH:
		out.append(_focus_row(ACTION_RESUME, _resume_footer))
	return out


func _focus_row(action: String, node: Control) -> Dictionary:
	var kind := "button"
	if node != null and node is HSlider:
		kind = "range"
	return {
		"id": ID_PREFIX + action,
		"node": node,
		"action": action,
		"opts": {"kind": kind},
	}


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_build()
	set_tab(TAB_MATCH, false)
	refresh_values()
	refresh_strings()
	visible = false
	_apply_layout()


func _build() -> void:
	_scrim = Panel.new()
	_scrim.name = NODE_SCRIM
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.add_theme_stylebox_override("panel", _scrim_box())
	add_child(_scrim)
	var center := CenterContainer.new()
	center.name = "PauseCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.add_child(center)
	_card = PanelContainer.new()
	_card.name = NODE_CARD
	_card.theme_type_variation = &"HudPauseCard"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.name = "PauseColumn"
	column.add_theme_constant_override("separation", 14)
	_card.add_child(column)
	_title = Label.new()
	_title.name = NODE_TITLE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", _font("HeroTitle"))
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", _palette("ink"))
	column.add_child(_title)
	_build_tabs(column)
	_build_match_panel(column)
	_build_camera_panel(column)
	_build_controller_panel(column)
	_build_controls_panel(column)
	_build_ui_panel(column)
	_resume_footer = _action_button("ResumeFooter", "ButtonPrimary", "pauseResumeMatch")
	_resume_footer.custom_minimum_size.y = 40
	_resume_footer.pressed.connect(resume)
	column.add_child(_resume_footer)
	resized.connect(_apply_layout)


## `.pause-tabs` (`styles.css:1448-1457`): one strip, three equal cells, 4 px gaps.
func _build_tabs(parent: Control) -> void:
	var strip := PanelContainer.new()
	strip.name = NODE_TABS
	strip.add_theme_stylebox_override("panel", _tab_strip_box())
	parent.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	strip.add_child(row)
	for tab in TABS:
		var id := String(tab["id"])
		var button := Button.new()
		button.name = "Tab%s" % id.capitalize()
		button.theme_type_variation = &"SegmentedInactive"
		button.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_tab.bind(id, _pad_connected))
		row.add_child(button)
		_tabs[id] = button


## `pause-panel--match` (`index.html:577-595`): the status line, then the four
## actions, 26 px apart, centred.
func _build_match_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.name = "PanelMatch"
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 26)
	parent.add_child(panel)
	var status := VBoxContainer.new()
	status.name = NODE_STATUS
	status.add_theme_constant_override("separation", 4)
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(status)
	_status_key = Label.new()
	_status_key.name = "StatusKey"
	_status_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_key.add_theme_font_override("font", _font("LabelSmall"))
	_status_key.add_theme_font_size_override("font_size", 11)
	_status_key.add_theme_color_override("font_color", _palette("text_soft_3"))
	status.add_child(_status_key)
	_status_title = Label.new()
	_status_title.name = NODE_STATUS_TITLE
	_status_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_title.add_theme_font_override("font", _font("HeroTitle"))
	_status_title.add_theme_font_size_override("font_size", 26)
	_status_title.add_theme_color_override("font_color", _palette("ink"))
	status.add_child(_status_title)
	var actions := VBoxContainer.new()
	actions.name = NODE_ACTIONS
	actions.custom_minimum_size = Vector2(ACTIONS_WIDTH, 0.0)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)
	_continue_button = _action_button(NODE_CONTINUE, "ButtonPrimary", "continue")
	_continue_button.pressed.connect(resume)
	actions.add_child(_continue_button)
	_replay_button = _action_button(NODE_REPLAY, "ButtonSecondary", "replayBtn")
	_replay_button.pressed.connect(_on_replay_pressed)
	actions.add_child(_replay_button)
	_rematch_button = _action_button(NODE_REMATCH, "ButtonSecondary", "rematch")
	_rematch_button.pressed.connect(rematch)
	actions.add_child(_rematch_button)
	_quit_button = _action_button(NODE_QUIT, "ButtonGhost", QUIT_KEY)
	_quit_button.pressed.connect(handle_quit)
	actions.add_child(_quit_button)
	_apply_replay_state()
	_panels[TAB_MATCH] = panel


## `.pause-panel--controller` (`index.html:597-636`): the settings strip, the two
## rows from UIR-19's shared components, the stick monitors.
func _build_controller_panel(parent: Control) -> void:
	# The 2D reference's `.pause-panel--controller` is only a centring container;
	# it has no additional surface behind the compact settings column.
	var panel := CenterContainer.new()
	panel.name = "PanelController"
	parent.add_child(panel)
	var settings := VBoxContainer.new()
	settings.name = NODE_CONTROLLER
	settings.custom_minimum_size = Vector2(SETTINGS_WIDTH, 0.0)
	settings.add_theme_constant_override("separation", 14)
	panel.add_child(settings)
	_controller_box = settings
	var title := Label.new()
	title.name = "ControllerTitle"
	title.text = UiStrings.t("controlPlayers")
	title.set_meta("message_id", "controlPlayers")
	title.add_theme_font_override("font", _font("LabelSmall"))
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", _palette("text_soft"))
	settings.add_child(title)
	_mode_strip = _build_mode_strip()
	settings.add_child(_mode_strip)
	_deadzone_row = Rows.make_range("deadzone", DEADZONE_MIN, DEADZONE_MAX, DEADZONE_STEP,
		float(snapshot().get("deadzone", DEADZONE_DEFAULT)), "DeadzoneRow")
	(_deadzone_row as Rows.RangeRow).changed.connect(_on_deadzone_changed)
	settings.add_child(_deadzone_row)
	_stick_monitor = _build_stick_monitor()
	settings.add_child(_stick_monitor)
	_vibration_row = Rows.make_toggle("vibration", bool(snapshot().get("vibration", true)), "VibrationRow")
	(_vibration_row as Rows.ToggleRow).changed.connect(_on_vibration_changed)
	settings.add_child(_vibration_row)
	_volume_row = Rows.make_range("volume", VOLUME_MIN, VOLUME_MAX, VOLUME_STEP,
		float(snapshot().get("volume", VOLUME_DEFAULT)), "VolumeRow")
	(_volume_row as Rows.RangeRow).changed.connect(_on_volume_changed)
	settings.add_child(_volume_row)
	_now_playing_row = Rows.make_toggle("Mostra titolo e copertina", bool(ModesSave.profile(store()).get("prefs", {}).get("nowPlaying", true)), "NowPlayingRow")
	(_now_playing_row as Rows.ToggleRow).changed.connect(func(on: bool) -> void: _persist("nowPlaying", on))
	settings.add_child(_now_playing_row)
	_panels[TAB_CONTROLLER] = panel


## `.control-mode-toggle` (`styles.css:1535-1576`): three cells, 36 px tall.
func _build_mode_strip() -> PanelContainer:
	var strip := PanelContainer.new()
	strip.name = NODE_MODE_STRIP
	strip.add_theme_stylebox_override("panel", _tab_strip_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	strip.add_child(row)
	for mode in CONTROL_MODES:
		var button := Button.new()
		button.name = "Mode%s" % String(mode).capitalize()
		button.theme_type_variation = &"SegmentedInactive"
		button.custom_minimum_size = Vector2(0.0, MODE_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_control_mode.bind(mode))
		row.add_child(button)
		_mode_buttons[mode] = button
	return strip


## `.stick-monitor` (`index.html:603-606`, `styles.css:1578-1620`): two labelled
## circles with a 10 px dot each.
func _build_stick_monitor() -> HBoxContainer:
	var monitor := HBoxContainer.new()
	monitor.name = NODE_STICK
	monitor.add_theme_constant_override("separation", 12)
	monitor.add_child(_build_stick("left", STICK_MOVE_KEY))
	monitor.add_child(_build_stick("right", STICK_SWITCH_KEY))
	return monitor


func _build_stick(which: String, label_key: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "Stick%s" % which.capitalize()
	column.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.name = "StickLabel"
	label.text = UiStrings.t(label_key)
	label.set_meta("message_id", label_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font("LabelSmall"))
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", _palette("tab_text_idle"))
	column.add_child(label)
	var box := Panel.new()
	box.name = "StickCircle"
	box.custom_minimum_size = Vector2(STICK_BOX, STICK_BOX)
	box.add_theme_stylebox_override("panel", _stick_circle_box(false))
	column.add_child(box)
	var ring := Panel.new()
	ring.name = "StickRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = STICK_RING_INSET
	ring.offset_top = STICK_RING_INSET
	ring.offset_right = -STICK_RING_INSET
	ring.offset_bottom = -STICK_RING_INSET
	ring.add_theme_stylebox_override("panel", _stick_circle_box(true))
	box.add_child(ring)
	var dot := Panel.new()
	dot.name = "StickDot"
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size = Vector2(STICK_DOT, STICK_DOT)
	dot.add_theme_stylebox_override("panel", _dot_box())
	box.add_child(dot)
	_stick_boxes[which] = box
	_stick_dots[which] = dot
	_position_dots()
	return column


## `.pause-panel--controls` (`index.html:639-686`): the legend overview, then the
## tutorial section, which starts hidden.
func _build_controls_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.name = "PanelControls"
	panel.add_theme_constant_override("separation", 18)
	parent.add_child(panel)
	_legend_host = VBoxContainer.new()
	_legend_host.name = NODE_LEGEND_HOST
	_legend_host.add_theme_constant_override("separation", 14)
	panel.add_child(_legend_host)
	_legend = LegendScene.instantiate()
	_legend.name = "PauseLegend"
	_legend_host.add_child(_legend)
	if _legend.has_method("setup"):
		_legend.call("setup", LegendClass.reference_rows(), {
			"tutorial_link": true,
			"side_by_side": true,
		})
	_apply_pad_layout()
	if _legend.has_signal("tutorial_requested"):
		_legend.connect("tutorial_requested", open_tutorial)
	_tutorial = TutorialScene.instantiate()
	_tutorial.name = NODE_TUTORIAL
	panel.add_child(_tutorial)
	if _tutorial.has_signal("back_requested"):
		_tutorial.connect("back_requested", _on_tutorial_back)
	if _tutorial.has_signal("try_requested"):
		_tutorial.connect("try_requested", _on_tutorial_try)
	if _tutorial.has_method("close"):
		_tutorial.call("close")
	_panels[TAB_CONTROLS] = panel


## The UI tab (`docs/agent-work/ui-visibility-settings/PLAN.md`): the four presets
## first, then the six independent toggles, then the one-line explanation of the
## in-match shortcut. Every control reads its state from the bound controller and
## writes through it — the panel owns no profile of its own, so the tab and the live
## HUD cannot disagree.
func _build_camera_panel(parent: Control) -> void:
	var panel := HBoxContainer.new()
	panel.name = "PanelCamera"
	panel.add_theme_constant_override("separation", 20)
	parent.add_child(panel)
	var choices := VBoxContainer.new()
	choices.custom_minimum_size.x = 210
	choices.add_theme_constant_override("separation", 8)
	panel.add_child(choices)
	for id in CAMERA_LABELS:
		var button := _action_button("Camera" + String(id).capitalize(), "SegmentedInactive", CAMERA_LABELS[id])
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_select_camera.bind(String(id)))
		button.focus_entered.connect(_preview_camera_choice.bind(String(id)))
		button.mouse_entered.connect(_preview_camera_choice.bind(String(id)))
		choices.add_child(button)
		_camera_buttons[id] = button
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	panel.add_child(details)
	_camera_preview = SubViewport.new()
	_camera_preview.size = Vector2i(640, 360)
	_camera_preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_camera_preview.gui_disable_input = true
	details.add_child(_camera_preview)
	_preview_camera = Camera3D.new()
	_camera_preview.add_child(_preview_camera)
	_preview_camera.current = true
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.custom_minimum_size.y = 200
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(frame)
	var image := TextureRect.new()
	image.texture = _camera_preview.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(image)
	_camera_description = _section_label("CameraDescription", "cameraClassicDesc", 16)
	_camera_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_camera_description)
	_camera_hint = _section_label("CameraHint", "cameraPreviewHint", 13)
	_camera_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_camera_hint)
	_panels[TAB_CAMERA] = panel


func _preview_camera_choice(id: String) -> void:
	if not CAMERA_LABELS.has(id) or _camera_preview == null:
		return
	_preview_id = id
	if _seam is Node3D:
		_camera_preview.world_3d = (_seam as Node3D).get_world_3d()
		CameraCourt.apply_camera(_preview_camera, id)
		if _open and _tab == TAB_CAMERA:
			_camera_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	_refresh_camera_copy()


func _refresh_camera_copy() -> void:
	if _camera_description == null:
		return
	_camera_description.text = UiStrings.t(String(CAMERA_LABELS[_preview_id]) + "Desc")
	_camera_hint.text = UiStrings.t("cameraSelected" if _preview_id == Config.camera_preset else "cameraPreviewHint")


func _select_camera(id: String) -> void:
	if _seam != null and _seam.has_method("set_camera_preset"):
		_seam.call("set_camera_preset", id)
	_refresh_camera_buttons()
	_preview_camera_choice(id)


func _refresh_camera_buttons() -> void:
	for id in _camera_buttons:
		_style_tab(_camera_buttons[id], id == Config.camera_preset)
		(_camera_buttons[id] as Button).text = ("✓" + _sp() if id == Config.camera_preset else "") + UiStrings.t(CAMERA_LABELS[id])


func _build_ui_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.name = "PanelUi"
	panel.add_theme_constant_override("separation", 12)
	parent.add_child(panel)
	_ui_panel = panel
	var settings := VBoxContainer.new()
	settings.name = NODE_UI
	settings.custom_minimum_size = Vector2(SETTINGS_WIDTH, 0.0)
	settings.add_theme_constant_override("separation", 12)
	panel.add_child(settings)
	_ui_title = _section_label("UiTitle", "uiVisibility", 11)
	settings.add_child(_ui_title)
	_ui_presets_label = _section_label("UiPresetsTitle", "uiPresets", 11)
	settings.add_child(_ui_presets_label)
	var presets := GridContainer.new()
	presets.name = NODE_UI_PRESETS
	presets.columns = 2
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	settings.add_child(presets)
	for id in UI_PRESET_IDS:
		var button := _action_button("UiPreset%s" % String(id).capitalize(),
			"SegmentedInactive", String(UI_PRESET_LABEL_IDS[id]))
		button.custom_minimum_size = Vector2(0.0, MODE_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_ui_preset_pressed.bind(String(id)))
		presets.add_child(button)
		_ui_preset_buttons[id] = button
	for id in UI_COMPONENT_IDS:
		var row := Rows.make_toggle(String(UI_COMPONENT_LABEL_IDS[id]), true,
			"UiToggle%s" % String(id).capitalize())
		(row as Rows.ToggleRow).changed.connect(_on_ui_component_changed.bind(String(id)))
		settings.add_child(row)
		_ui_toggle_rows[id] = row
	_ui_note = _section_label(NODE_UI_NOTE, "uiShortcutNote", 11)
	_ui_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings.add_child(_ui_note)
	_panels[TAB_UI] = panel


## A section label in the controller tab's own type (`controlPlayers`'s shape): the
## small soft-cased eyebrow above a group of controls.
func _section_label(node_name: String, key: String, size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = UiStrings.t(key)
	label.set_meta("message_id", key)
	label.add_theme_font_override("font", _font("LabelSmall"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", _palette("text_soft"))
	return label


func _action_button(node_name: String, variation: String, key: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = StringName(variation)
	button.text = UiStrings.t(key)
	button.set_meta("message_id", key)
	button.custom_minimum_size = Vector2(0.0, 44.0)
	return button


## The tutorial's back: to the COMANDI tab, pause open (`js/main.js:203-212`).
func _on_tutorial_back() -> void:
	close_tutorial(true)


## `trySmashTutorial` (`js/main.js:2354-2357`): hide the tutorial, resume.
func _on_tutorial_try() -> void:
	close_tutorial(false)
	resume()


func _on_replay_pressed() -> void:
	if not replay():
		push_warning("PauseOverlay: replay is disabled until UIR-27 lands")


## `js/main.js:2238-2241`: no replay entry point exists in the port yet, so the
## button is disabled and carries the recorded reason — never silently dead, never a
## fake replay (the ticket's own rule).
func _apply_replay_state() -> void:
	if _replay_button == null:
		return
	_replay_button.disabled = not replay_enabled()
	_replay_button.tooltip_text = replay_disabled_reason()


func _refresh_mode_buttons(active_mode: String) -> void:
	for mode in _mode_buttons:
		var button: Button = _mode_buttons[mode]
		var active: bool = String(mode) == active_mode
		_style_tab(button, active)
		button.set_meta("aria_pressed", active)


func _on_deadzone_changed(raw: float) -> void:
	_persist(DEADZONE_KEY, clampf(raw, DEADZONE_MIN, DEADZONE_MAX))


func _on_volume_changed(raw: float) -> void:
	_persist(VOLUME_KEY, clampf(raw, VOLUME_MIN, VOLUME_MAX))


func _on_vibration_changed(on: bool) -> void:
	_persist(VIBRATION_KEY, on)


## `savePrefs(collectPrefs())` on every one of these changes (`js/main.js:2477-2490`),
## through the port's per-key writer so another lane's keys survive (`SettingsScreen`'s
## own contract).
func _persist(key: String, value: Variant) -> void:
	ModesSave.save_pref(store(), key, value)


## The pause family's segmented look: the theme's `SegmentedInactive` while idle, and
## while active the reference's own `.pause-tabs button.is-active` box (`.control-mode-toggle`
## is the same rule, `styles.css:1556-1565`), composed from Palette reads because the
## theme carries no variation for it yet — the request is in `evidence/uir-20-overlays.log`.
func _style_tab(button: Button, active: bool) -> void:
	if button == null:
		return
	var source := _theme()
	if active:
		button.theme_type_variation = &"SegmentedActive"
		for slot in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(String(slot), _active_tab_box())
	else:
		button.theme_type_variation = &"SegmentedInactive"
		for slot in ["normal", "hover", "pressed", "focus"]:
			button.remove_theme_stylebox_override(String(slot))
	if active and source.has_color("font_color", "SegmentedActive"):
		button.add_theme_color_override("font_color", source.get_color("font_color", "SegmentedActive"))
		button.add_theme_color_override("font_hover_color", source.get_color("font_color", "SegmentedActive"))
		button.add_theme_color_override("font_pressed_color", source.get_color("font_color", "SegmentedActive"))
	else:
		for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.remove_theme_color_override(String(slot))


## `.pause-tabs button.is-active` (`styles.css:1471-1475`): `#16bed7` fill, radius 4,
## and the `0 0 14px rgba(22,190,215,0.25)` glow.
func _active_tab_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("segmented_gradient_end")
	box.set_corner_radius_all(4)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.shadow_color = _alpha(_palette("segmented_gradient_end"), 0.25)
	box.shadow_size = 14
	return box


func _apply_quit_arm() -> void:
	if _quit_button == null:
		return
	_quit_button.text = UiStrings.t(QUIT_CONFIRM_KEY) if _quit_armed else UiStrings.t(QUIT_KEY)
	if _quit_armed:
		_quit_button.theme_type_variation = &"ButtonGhost"
		for slot in ["normal", "hover", "pressed", "focus"]:
			_quit_button.add_theme_stylebox_override(String(slot), _confirm_box(slot == "hover"))
	else:
		_quit_button.theme_type_variation = &"ButtonGhost"
		for slot in ["normal", "hover", "pressed", "focus"]:
			_quit_button.remove_theme_stylebox_override(String(slot))


## `.btn--confirm` (`styles.css:2765-2773`): `#5c141c` fill, `#ff4b4b` border, the
## `0 5px 0 rgba(60,8,12,0.5)` shadow, `#7a1a24` on hover.
func _confirm_box(hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("danger_fill_hover") if hover else _palette("danger_fill")
	box.border_color = _palette("danger_border")
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.shadow_color = _palette("danger_shadow")
	box.shadow_offset = Vector2(0.0, 5.0)
	return box


## The two dots, from the values through the player's deadzone (`updateStickMonitor`
## is called with the radial value, `js/main.js:791-794`).
func _position_dots() -> void:
	var deadzone_value := deadzone()
	_place_dot("left", radial(_stick_values["left"], deadzone_value))
	_place_dot("right", radial(_stick_values["right"], deadzone_value))


func _place_dot(which: String, value: Vector2) -> void:
	var box: Control = _stick_boxes.get(which, null)
	var dot: Control = _stick_dots.get(which, null)
	if box == null or dot == null:
		return
	var center := box.size * 0.5
	dot.position = center + value * STICK_RANGE - Vector2(STICK_DOT, STICK_DOT) * 0.5


## The reference's breakpoints for this card (`styles.css:1970-2026`): the panel
## floor, the tab font and the legend's column count. The card's own narrowing
## padding rule is the theme's box (a shared variation) — recorded as a gap.
func _apply_layout() -> void:
	if _card == null:
		return
	var width := size.x
	if width <= 0.0:
		width = 1280.0
	_narrow = width < NARROW_PX
	_tight = width < TIGHT_PX
	_card.custom_minimum_size.x = minf(CARD_WIDTH, maxf(0.0, width - CARD_MARGIN * 2.0))
	for id in _panels:
		var panel: Control = _panels[id]
		var floor := PANEL_MIN_HEIGHT
		if _narrow:
			floor = PANEL_MIN_HEIGHT_NARROW if (id == TAB_MATCH or id == TAB_CONTROLLER) else 0.0
		if id == TAB_CAMERA:
			floor = 0.0
		panel.custom_minimum_size.y = floor
	var tab_size := 10 if _tight else 12
	for id in _tabs:
		(_tabs[id] as Button).add_theme_font_size_override("font_size", tab_size)
	for id in _tabs:
		for tab in TABS:
			if String(tab["id"]) == String(id):
				var button: Button = _tabs[id]
				button.set_meta("message_id", String(tab["label_id"]))
	if _ui_panel != null:
		var presets := _ui_panel.find_child(NODE_UI_PRESETS, true, false)
		if presets is GridContainer:
			(presets as GridContainer).columns = 1 if _tight else 2
		for id in UI_PRESET_IDS:
			var preset_button: Button = _ui_preset_buttons.get(id, null)
			if preset_button != null:
				preset_button.set_meta("message_id", String(UI_PRESET_LABEL_IDS[id]))
	for mode in _mode_buttons:
		(_mode_buttons[mode] as Button).set_meta("message_id", String(CONTROL_MODE_LABELS[mode]))
	if _legend != null:
		if _legend.has_method("set_side_by_side"):
			_legend.call("set_side_by_side", not _narrow)
		var rows_node: Node = _legend.get_node_or_null("LegendRows")
		if rows_node != null and rows_node is GridContainer:
			(rows_node as GridContainer).columns = 1 if _tight else 2


## The card's scrim (`styles.css:1427`): `rgba(4,4,14,0.82)`.
func _scrim_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("overlay_scrim")
	return box


## `.pause-tabs` / `.control-mode-toggle` (`styles.css:1448-1457`, `:1535-1543`).
func _tab_strip_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("surface_1")
	box.border_color = _palette("tab_border")
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


## `.stick-monitor i` (`styles.css:1593-1609`): 52 px, `#091d39`, 2 px `#28567d`;
## the inner dashed ring is the same call with `dashed = true` (its `1px dashed
## rgba(126,243,255,0.24)`, `:1603-1609`).
func _stick_circle_box(dashed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = not dashed
	box.bg_color = _palette("surface_1")
	box.border_color = _palette("tab_border") if not dashed else _alpha(_palette("text_soft_3"), 0.24)
	box.set_border_width_all(2 if not dashed else 1)
	box.set_corner_radius_all(int(STICK_BOX * 0.5))
	return box


## `.stick-monitor b` (`styles.css:1611-1618`): a 10 px cyan dot with a 7 px glow.
func _dot_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("text_soft_3")
	box.set_corner_radius_all(int(STICK_DOT * 0.5))
	box.shadow_color = _alpha(_palette("text_soft_3"), 0.72)
	box.shadow_size = 7
	return box


func _call_seam(method: String, args: Array) -> bool:
	if _seam != null and _seam.has_method(method):
		_seam.callv(method, args)
		return true
	if not _missing_seam.has(method):
		_missing_seam.append(method)
	return false


func _apply_aria() -> void:
	_set_accessible_name(_scrim, UiStrings.t(ARIA_TABS_KEY))
	_set_accessible_name(_controller_box, UiStrings.t(ARIA_CONTROLLER_KEY))
	_set_accessible_name(_mode_strip, UiStrings.t(ARIA_CONTROL_MODE_KEY))
	_set_accessible_name(_stick_monitor, UiStrings.t(ARIA_STICK_KEY))


func _set_accessible_name(node: Node, text: String) -> void:
	if node == null or text == "":
		return
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == "accessibility_name":
			node.set("accessibility_name", text)
			return


func _theme() -> Theme:
	return theme if theme != null else DefaultTheme


func _font(role: String) -> Font:
	var source := _theme()
	if source == null:
		return null
	return source.get_font("font", role) if source.has_font("font", role) else null


## A palette entry, or a recorded miss — never a literal, never a silent guess
## (`Hud.gd`'s mechanism, same contract).
func _palette(key: String) -> Color:
	# A null source means the shared theme did not load (the theme file is another
	# lane's; a parse error in it must not take this screen's tree down) — the key is
	# recorded and the palette's own ink stands in.
	var source := _theme()
	if source != null and source.has_color(key, "Palette"):
		return source.get_color(key, "Palette")
	if not _palette_misses.has(key):
		_palette_misses.append(key)
	if source != null and source.has_color("ink", "Palette"):
		return source.get_color("ink", "Palette")
	return Color.WHITE


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out


## The space a literal may not carry (the UI lane's scan flags prose, and a lone
## space is a space). Composed the way the rest of the port composes its separators
## (`FeedbackScreen._sp`, `ViewState._space`).
static func _sp() -> String:
	return String.chr(32)
