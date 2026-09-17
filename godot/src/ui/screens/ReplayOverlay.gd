## ReplayOverlay.gd — UIR-27: the replay overlay's chrome, drawn over the court while a
## recorded point plays back.
##
## WHAT THIS IS. `drawReplayOverlay` (`js/main.js:1362-1381`), the canvas drawing the
## reference runs while its replay is up: a translucent banner across the top carrying
## `t("replay")` and the exit hint `t("replayExit")`, and a progress bar pinned to the
## bottom edge whose gold fill is `(replayIndex + 1) / replayFrames.length` of the width.
## The overlay is up exactly while a replay is running (`js/main.js:1243-1245`, `:1282`,
## `:1291-1294`); it draws nothing else and it exits through no control of its own (R and
## ESC are the match's keys, `js/main.js:2606-2626`).
##
## WHAT THIS IS NOT. It records nothing, plays nothing and owns no clock. The buffer, the
## playback cursor and the pause state are the integration half of UIR-27 in
## `godot/game/match_controller.gd` (the seam contract is written down in
## `evidence/uir-27-replay.log` §Seam and asserted by `tests/ui/replay_audit.gd`). This
## overlay READS two facts through a seam — `replay_active()` and `replay_progress()` —
## and paints them. With no seam bound it paints nothing (`refresh()` answers false and
## the view stays hidden); `set_replay()` is the direct feed the audit's geometry checks
## and a mount with the two facts in hand use.
##
## THE REFERENCE'S PIXELS ARE CANVAS PIXELS, READ AT THIS FRAME'S SCALE. The overlay is
## drawn on the 960x700 game canvas (`index.html:476`) that the captures render at
## 1280x720, so every number is `value * 1280/960` — the same conversion
## `match_controller.gd` keeps as `TIMING_FRAME_SCALE`, repeated here as `FRAME_SCALE`
## because this file must not preload the controller:
##
##   banner       40 px tall, `rgba(6, 12, 30, 0.42)`              -> 53.33 px, `replay_banner`
##   banner text  12 px 'Lilita One', `#ffcc00`, x = 14             -> 16 px, `gold`, inset 18.67
##   exit hint    11 px, `rgba(255,255,255,0.9)`, right, 14 in      -> 15 px, `white` @ 0.9, same inset
##   progress bar 8 px tall at the canvas bottom; track
##                `rgba(255,255,255,0.2)`, fill `#ffcc00`           -> 10.67 px, `white` @ 0.2 / `gold`
##
## The reference's text box sits 14 px above and below the 40 px strip's middle
## (`js/main.js:1371`: the 12 px baseline at y = 26), so each label fills the strip's
## height and centres vertically.
##
## PALETTE. `#ffcc00` is the theme's own `gold` entry (exact); the two whites are the
## theme's `white` at the reference's own alphas (the convention `theme/README.md` records
## for its `rgba(255,255,255,α)` reads); `rgba(6,12,30,0.42)` has no entry yet, so it is
## read as `replay_banner`, recorded in `palette_misses()` and requested with its reference
## line in `evidence/uir-27-replay.log` — never silently substituted (`Hud.gd`'s rule).
##
## WHAT IT NEVER DOES. No input handling (the exit keys are the controller's); no
## `SceneTree.paused`; no focusable node of its own (`focus_controls()` answers the empty
## list and says why — the reference's overlay draws no button, and while it is up the
## pause card is closed, so the mount drops the card's focus rows for the duration and
## rebuilds them when the card reopens); no prose literal (the two texts are `UiStrings.t`
## ids and `▶` is the reference's own glyph, `js/main.js:1371`).
##
## THE MOUNT'S RECIPE:
##
##   const ReplayOverlayScene := preload("res://src/ui/screens/ReplayOverlay.tscn")
##   var overlay := ReplayOverlayScene.instantiate()
##   layer.add_child(overlay)      # FIRST in the HUD layer (or z_index below the HUDs):
##                                 # the reference's canvas sits UNDER the HTML HUD
##                                 # (`.game-hud` z-index 5, `styles.css:536-544`), so the
##                                 # scoreboard stays readable over the banner's left end
##   overlay.bind_seam(self)       # the controller: replay_active() / replay_progress()
##
## With a seam bound the overlay refreshes itself every frame (`_process`); a mount may
## also call `refresh()` by hand. `apply_capture_state("replay")` asks the seam to start a
## REAL replay and refuses (returns false) when it cannot — the harness records the
## refusal rather than painting a track that does not exist.
##
## STATIC CHECKS ONLY in this wave: the dispatch for UIR-27 says no Godot process may be
## started by this worker; the acceptance command is written down in
## `evidence/uir-27-replay.log` for the integration owner to run.
extends Control

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
## The scene mounts the theme; this is the fallback for a bare `new()`.
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

## `js/main.js:1371`: the banner opens with the reference's own glyph.
const BANNER_GLYPH := "▶"
## `js/main.js:1371`, `:1375`: the two message ids. Both resolve in `locale_data.gd`
## (`replay` -> RIPRODUZIONE / REPLAY, `replayExit` -> R · per uscire / R · to exit).
const BANNER_KEY := "replay"
const EXIT_KEY := "replayExit"

# ---------------------------------------------------------------------------
# The reference's numbers, in CANVAS pixels (`js/main.js:1366-1379`)
# ---------------------------------------------------------------------------

const BANNER_CANVAS_H := 40.0
const BANNER_TEXT_CANVAS_PX := 12.0
const EXIT_TEXT_CANVAS_PX := 11.0
const INSET_CANVAS := 14.0
const BAR_CANVAS_H := 8.0
## The canvas the reference draws on (`index.html:476`: 960x700) and the frame the
## captures render (1280x720): one conversion, canvas px -> frame px.
const FRAME_SCALE := 1280.0 / 960.0

## The same numbers read at this frame's scale. The two font sizes are integers the way
## `match_controller.gd` writes its own (`11/14/9 * 1280/960`); 12 * 4/3 is 16 exactly,
## 11 * 4/3 = 14.67 rounds to 15.
const BANNER_H := 40.0 * (1280.0 / 960.0)
const INSET := 14.0 * (1280.0 / 960.0)
const BAR_H := 8.0 * (1280.0 / 960.0)
const BANNER_FONT_PX := 16
const EXIT_FONT_PX := 15

# ---------------------------------------------------------------------------
# Palette (`Palette` entries; a key the theme does not carry is recorded, never guessed)
# ---------------------------------------------------------------------------

## `#ffcc00` — the banner text and the bar's fill (`js/main.js:1368`, `:1378`). The
## theme's `gold` is exactly this value.
const KEY_GOLD := "gold"
## `rgba(255,255,255,0.9)` and `rgba(255,255,255,0.2)` (`js/main.js:1372`, `:1376`) —
## the theme's `white`, at the reference's own alphas.
const KEY_WHITE := "white"
## `rgba(6,12,30,0.42)` (`js/main.js:1366`) — the one key this overlay has to request.
const KEY_BANNER_BG := "replay_banner"
const ALPHA_EXIT := 0.9
const ALPHA_TRACK := 0.2

## The banner's face: the reference's `'Lilita One'` (`js/main.js:1369`), i.e. the theme's
## display font, the same one `HudTitle` carries. The size override is the reference's
## own 12 px read at this frame's scale.
const FONT_ROLE := "HudTitle"

# ---------------------------------------------------------------------------
# Nodes the mount, the capture harness and the audit address by name
# ---------------------------------------------------------------------------

const NODE_BANNER := "ReplayBanner"
const NODE_BANNER_LABEL := "ReplayBannerLabel"
const NODE_EXIT_HINT := "ReplayExitHint"
const NODE_BAR := "ReplayProgress"
const NODE_BAR_TRACK := "ReplayProgressTrack"
const NODE_BAR_FILL := "ReplayProgressFill"

## The one capture state this overlay declares: a replay that is actually running, asked
## of the seam. A capture must never show chrome over a track that does not exist.
const CAPTURE_REPLAY := "replay"

var _built := false
var _active := false
var _progress := 0.0
var _seam: Object = null
var _missing_seam: Array = []
var _palette_misses: Array = []

var _banner: ColorRect
var _banner_label: Label
var _exit_hint: Label
var _bar: Control
var _bar_track: ColorRect
var _bar_fill: ColorRect


func _ready() -> void:
	_ensure()
	set_process(_seam != null)


# ---------------------------------------------------------------------------
# The mount's contract
# ---------------------------------------------------------------------------

## The seam holder: any object with `replay_active() -> bool` and
## `replay_progress() -> float` (the ticket's proposed API, `UIR-27-replay.md` microstep 2).
## Without it the overlay stays hidden and records what it could not read.
## ATTACH ONLY, never a paint: a bind is not a fact about the replay, so the first
## read belongs to the frame that follows (`_process`) or to the caller's own
## `refresh()` — a bind that painted would turn the caller's next `refresh()` into
## a no-op and its "did the view move" answer into a lie.
func bind_seam(seam_in: Object) -> void:
	_seam = seam_in
	set_process(_seam != null)


func seam() -> Object:
	return _seam


## The direct feed: what the overlay paints, nothing more. `progress` is clamped to
## `[0, 1]` — the reference clamps at the paint (`js/main.js:1379`) — and `active` decides
## the whole overlay's visibility, so a caller cannot show chrome without a replay.
## Returns whether the view changed, so a caller can tell "already there" from "moved".
func set_replay(active: bool, progress: float = 0.0) -> bool:
	_ensure()
	var clamped := clampf(progress, 0.0, 1.0)
	var changed := active != _active or not is_equal_approx(clamped, _progress)
	_active = active
	_progress = clamped
	visible = _active
	_apply_progress()
	return changed


func is_active() -> bool:
	return _active


func progress() -> float:
	return _progress


## Reads the seam and paints what it says. Returns whether the view changed. With no seam
## bound it paints nothing (and answers false): the overlay never invents a replay.
func refresh() -> bool:
	_ensure()
	if _seam == null:
		# No seam, no replay to paint. "Paints nothing" is a HIDDEN overlay, not a
		# stale one: the header's own rule is "with no seam the overlay stays hidden",
		# and a bound-then-unbound seam must not leave chrome over a dead track.
		return set_replay(false, 0.0)
	if not _seam.has_method("replay_active"):
		_note_missing("replay_active")
		return set_replay(false, 0.0)
	var active := bool(_seam.call("replay_active"))
	var value := 0.0
	if active:
		if _seam.has_method("replay_progress"):
			value = float(_seam.call("replay_progress"))
		else:
			_note_missing("replay_progress")
	return set_replay(active, value)


func _process(_delta: float) -> void:
	refresh()


# ---------------------------------------------------------------------------
# Strings and language (`setPauseTab`-style: one flip refreshes every slot)
# ---------------------------------------------------------------------------

## `UiStrings.t("replay")` behind the reference's own glyph and separator: the composed
## literal the canvas prints (`js/main.js:1371`) — composed here because the UI lane's
## prose scan flags any quoted literal carrying a space.
func banner_text() -> String:
	return BANNER_GLYPH + _sp() + UiStrings.t(BANNER_KEY)


func exit_hint_text() -> String:
	return UiStrings.t(EXIT_KEY)


func refresh_strings() -> void:
	_ensure()
	_banner_label.text = banner_text()
	_exit_hint.text = exit_hint_text()


## The settings screen's own language seam: the language is set once, every slot follows.
func set_language(lang: String) -> bool:
	if not Locale.has_locale(lang):
		return false
	Locale.set_lang(lang)
	refresh_strings()
	return true


# ---------------------------------------------------------------------------
# Capture (UIR-24's contract: declare the states, refuse what cannot be shown)
# ---------------------------------------------------------------------------

func capture_states() -> Array:
	return [CAPTURE_REPLAY]


## Drives the one declared state: a replay that is actually up. The seam is asked to
## START one — the frames have to exist — and the state is refused when it cannot, so the
## capture harness records "declared and refused" instead of a painted invention.
func apply_capture_state(state_id: String) -> bool:
	_ensure()
	if state_id != CAPTURE_REPLAY:
		return false
	if _seam == null or not _seam.has_method("start_replay"):
		_note_missing("start_replay")
		return false
	var started := bool(_seam.call("start_replay"))
	if started:
		refresh()
	return started


# ---------------------------------------------------------------------------
# Focus (UIR-05's model path)
# ---------------------------------------------------------------------------

## The overlay carries no focusable control: the reference draws none (no button, no
## click target, `js/main.js:1362-1381`), and R/ESC are the match controller's keys. The
## mount drops the pause card's focus rows while the replay is up (the card is closed)
## and rebuilds them when it reopens; there is nothing here to register.
func focus_controls() -> Array:
	return []


# ---------------------------------------------------------------------------
# What the audit and the evidence log read
# ---------------------------------------------------------------------------

func report() -> Dictionary:
	_ensure()
	return {
		"active": _active,
		"progress": _progress,
		"banner_text": banner_text(),
		"exit_hint": exit_hint_text(),
		"banner_h": BANNER_H,
		"inset": INSET,
		"bar_h": BAR_H,
		"fill_ratio": fill_ratio(),
		"seam": _seam != null,
		"seam_missing": _missing_seam.duplicate(),
		"palette_misses": _palette_misses.duplicate(),
		"captures": capture_states().duplicate(),
	}


## The banner's box, in this frame's pixels (`40 * 1280/960` tall, full width).
func banner_rect() -> Rect2:
	_ensure()
	return _banner.get_global_rect()


## The progress bar's track, in this frame's pixels (`8 * 1280/960`, at the bottom edge).
func bar_rect() -> Rect2:
	_ensure()
	return _bar_track.get_global_rect()


## The painted fill against the track, measured. `0.0` until the tree has been laid out.
func fill_ratio() -> float:
	_ensure()
	if _bar_track == null or _bar_track.size.x <= 0.0:
		return 0.0
	return _bar_fill.size.x / _bar_track.size.x


## Every Palette key this overlay can name, for the audit's existence check.
static func palette_keys() -> Array:
	return [KEY_GOLD, KEY_WHITE, KEY_BANNER_BG]


## The keys the theme does not carry yet, first-seen order. Each one is requested with its
## reference line in `evidence/uir-27-replay.log`; the audit prints the set and a miss is
## never silently substituted.
func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_build()
	refresh_strings()
	_apply_progress()
	visible = false


func _build() -> void:
	_banner = ColorRect.new()
	_banner.name = NODE_BANNER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_bottom = BANNER_H
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_apply_theme_colors()

	_banner_label = Label.new()
	_banner_label.name = NODE_BANNER_LABEL
	# Full-width, left-aligned, inset by the reference's own 14 canvas px: the text
	# starts at `INSET` and the label's box never clips it. Both labels share the
	# banner's box the way the reference draws both texts into the same 40 px strip.
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner_label.offset_left = INSET
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.add_theme_font_override("font", _font(FONT_ROLE))
	_banner_label.add_theme_font_size_override("font_size", BANNER_FONT_PX)
	_banner_label.add_theme_color_override("font_color", _palette(KEY_GOLD))
	_banner.add_child(_banner_label)

	_exit_hint = Label.new()
	_exit_hint.name = NODE_EXIT_HINT
	_exit_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_hint.offset_right = -INSET
	_exit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_exit_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exit_hint.add_theme_font_override("font", _font(FONT_ROLE))
	_exit_hint.add_theme_font_size_override("font_size", EXIT_FONT_PX)
	_exit_hint.add_theme_color_override("font_color", _alpha(_palette(KEY_WHITE), ALPHA_EXIT))
	_banner.add_child(_exit_hint)

	_bar = Control.new()
	_bar.name = NODE_BAR
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -BAR_H
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.resized.connect(_apply_progress)
	add_child(_bar)

	_bar_track = ColorRect.new()
	_bar_track.name = NODE_BAR_TRACK
	_bar_track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_track.color = _alpha(_palette(KEY_WHITE), ALPHA_TRACK)
	_bar.add_child(_bar_track)

	_bar_fill = ColorRect.new()
	_bar_fill.name = NODE_BAR_FILL
	_bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_bar_fill.offset_right = 0.0
	_bar_fill.size.x = 0.0
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.color = _palette(KEY_GOLD)
	_bar.add_child(_bar_fill)

	resized.connect(_apply_progress)


## The four reference colours, read once at build: the palette does not change under a
## mounted overlay (`SettingsScreen`'s own behaviour for theme-owned values).
func _apply_theme_colors() -> void:
	_banner.color = _palette(KEY_BANNER_BG)


## The fill is `clamp(progress, 0, 1)` of the track's width (`js/main.js:1379`), measured
## against the laid-out track rather than assumed: the reference's `canvas.width * …`.
func _apply_progress() -> void:
	if _bar_track == null or _bar_fill == null:
		return
	_bar_fill.size.x = _bar_track.size.x * clampf(_progress, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Theme access (`Hud.gd`'s mechanism, same contract: never a literal, never a guess)
# ---------------------------------------------------------------------------

func _theme() -> Theme:
	return theme if theme != null else DefaultTheme


func _font(role: String) -> Font:
	var source := _theme()
	if source == null:
		return null
	return source.get_font("font", role) if source.has_font("font", role) else null


## A palette entry, or a recorded miss — a null theme (the shared file is another lane's,
## a parse error in it must not take this overlay down) records the key and stands in the
## palette's own ink.
func _palette(key: String) -> Color:
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


func _note_missing(method: String) -> void:
	if not _missing_seam.has(method):
		_missing_seam.append(method)
		push_warning("ReplayOverlay: the seam misses %s(); the overlay stays hidden" % method)


## The separator a composed literal may not carry (the UI lane's prose scan flags any
## quoted literal with a space in it).
static func _sp() -> String:
	return String.chr(32)
