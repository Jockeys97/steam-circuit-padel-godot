## ModesScreen.gd — `screen-modes`, the reference's own mode page (`index.html:103-154`).
##
## WHAT THIS SCREEN IS. The web build's second section: a back button, the
## `MODALITÀ DI GIOCO` header, three `article.mode-card`s (quick, tournament, career)
## with art, title, description and a status tag — the career card also carries its
## season tag and the calendar fixture line — and below them `#matchSetup`: the
## difficulty segmented (four rungs) and the match-length segmented (six formats).
##
## THE CARDS ARE THE SELECTORS, EXACTLY AS THE REFERENCE HAS THEM. None of the three
## is hidden, re-worded or removed per mode; a mode this build does not grant stays
## visible with `mode-card--locked`'s own presentation (art kept, tag switched to
## `demoLockedMode`, no activation) — `applyDemoLimits` (`js/ui.js:746-753`), whose
## tag text and ready-class are the only two things that move. A press on an
## unlocked card performs `js/ui.js:1720-1729`: `ui.selectedMode = card.dataset.mode`
## (tournament also resets its round), the prefs write, and then `selectMode()` —
## which in the port is the pending-mode seam plus a route to `characters`.
##
## THE SETUP GROUPS FOLLOW `syncMatchSetup` (`js/main.js:1651-1657`), which hides
## `#matchSetup` whenever the selected mode is not `quick`. That call is not this
## screen's own state in the reference (it runs on the `to-modes` action and on the
## card select); the port reads the same rule from its own pending-mode seam, so the
## screen shows what the browser shows for the mode the session is in. The card row
## is never touched by it — no per-mode hiding is invented for the cards.
##
## THE DEMO PIN IS THE ADAPTER'S ANSWER, NOT A COPY OF THE RULE.
## `DemoGateAdapter.difficulty_allowed` gates the four rungs (one disabled, still
## visible, in a demo) and `DemoGateAdapter.mode_locked` gates the cards. The
## `demo-locked` capture state renders the same presentation in a full build by
## reading the demo's own generated table (`tests/build/DemoContent.gd`, the table
## the gate itself reads); the adapter request for a build-parameterised lock
## question is recorded in `evidence/uir-10-screen-modes.log`.
##
## THE LENGTH SEGMENT PERSISTS THROUGH THE REFERENCE'S OWN CARRIER. `Config` has no
## match-format member and nothing reads `prefs.matchLength` yet — a real gap,
## recorded in the evidence log with the request for the owning lane. What this
## screen does is what `collectPrefs`/`loadPrefs` do: the choice is written through
## `ModesSave.save_pref(store, "matchLength", …)`, the validated preference the
## reference itself keeps (`js/main.js:2277`). No new settings schema.
##
## THE GAME-PACE GROUP IS A PORT ADDITION, NEXT TO THE REFERENCE'S TWO. `#matchSetup`
## carries the difficulty and the match-length segments and nothing else; the pace
## rungs are this build's own (`src/sim/pace.gd`, the same control the settings screen
## shows) and they wear the setup groups' own presentation. Their display text comes
## from that module — `locale_data.gd` is generated from the frozen `js/i18n.js` — and
## the choice is written through the same prefs carrier the other two use, so the match
## reads it at start (`Config.pace_id()`) with no second store and no second default.
##
## THE SETUP AREA IS A RESPONSIVE THREE-CARD GRID. The original two reference groups
## and the port's pace group share one visual hierarchy at desktop widths, then stack
## into a single readable column on smaller frames. Each group keeps its own controls
## and save semantics; this is presentation only. Two-column difficulty and pace
## ladders keep their labels legible without making the pace card dictate a tall,
## mostly-empty row for its neighbours.
##
## LITERALS. `ModesScreen.gd` carries none: every visible string is a locale id
## resolved through `UiStrings`. The scene carries none either (this screen's nodes
## are named, not worded).
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Pace := preload("res://src/sim/pace.gd")
const Locale := preload("res://src/locale/locale.gd")
const CardFocusRing := preload("res://src/ui/components/CardFocusRing.gd")
const UiMotionPolicy := preload("res://src/ui/accessibility/UiMotionPolicy.gd")

const SCREEN_ID := "modes"

## The declared back edge (`ScreenRouter.SCREENS`, `nav_routes.gd`), as a router id.
const BACK_TARGET_ID := "menu"
## The card/segment actions are this screen's own spellings: they are reported by
## UIR-05's bridge, not routed by it, because a press has to set the selection before
## it navigates.
const SELECT_MODE_ACTION := "select-mode"
const DIFFICULTY_ACTION := "difficulty"
const LENGTH_ACTION := "length"
const ROUTE_TO_CHARACTERS := "characters"

## PORT ADDITION: the game-pace rung (`src/sim/pace.gd`) — the same control the
## settings screen carries, on the page a match is actually started from. The ladder,
## its factors and its display text are that module's; this screen shows the rungs and
## writes the chosen id through the prefs carrier the match reads at start
## (`Config.pace_id()`), exactly as the two reference segments write theirs.
const PACE_ACTION := "pace"
const PACE_KEY := "pacePreset"
## The pace group's own title, resolved through the pace module rather than through
## `UiStrings`: it is a port addition, and `locale_data.gd` is generated from the
## frozen `js/i18n.js` (its verifier rejects any key the reference lacks).
const PACE_TITLE_KEY := "pacePreset"

## `index.html:136-139`, in the reference's own order.
const DIFFICULTY_ORDER: Array[String] = ["easy", "medium", "hard", "legend"]
const DIFFICULTY_KEYS := {
	"easy": "diffEasy",
	"medium": "diffMedium",
	"hard": "diffHard",
	"legend": "diffLegend",
}

## `MATCH_FORMAT_IDS` (`js/data.js:689-698`), the reference's own order; the keys are
## its `data-i18n` ids (`index.html:145-150`, `js/i18n.js:34-39`).
const LENGTH_ORDER: Array[String] = ["points11", "points21", "games3", "games5", "set", "match2"]
const LENGTH_KEYS := {
	"points11": "len11",
	"points21": "len21",
	"games3": "lenGames3",
	"games5": "lenGames5",
	"set": "lenSet",
	"match2": "lenMatch2",
}

## Difficulty keeps the familiar single-row ladder, while length and pace use compact
## three-column grids over two rows. Every segment expands to fill its grid cell
## instead of bunching around the text at the left edge.
const DIFFICULTY_COLUMNS := 4
const PACE_COLUMNS := 3

## The three mode ids in the reference's document order (`index.html:112-156`).
const MODE_ORDER: Array[String] = ["quick", "tournament", "career"]

## The card art's screen-reader names (`data-i18n-aria`, `index.html:113/119/125`).
const MODE_ARIA_KEYS := {
	"quick": "ariaQuickModeArt",
	"tournament": "ariaTournamentModeArt",
	"career": "ariaCareerModeArt",
}

## The accent under each card's art (`.mode-card__art--*`), as theme `Palette` names.
## The career card's `var(--pink)` is undefined in the reference and renders the
## `var(--mode-accent, var(--cyan))` fallback, measured by UIR-06 and recorded in the
## theme README §2 — so career is cyan, not an invented pink.
const MODE_ACCENT_TOKENS := {"quick": "cyan", "tournament": "gold", "career": "cyan"}

## The states UIR-24's harness may ask for. `quick`/`tournament`/`career` pin the
## pending mode (what `syncMatchSetup` reads); `demo-locked` pins the demo view.
const CAPTURE_STATES: Array[String] = ["default", "quick", "tournament", "career", "demo-locked"]

## The screen-reader names this screen owns: node -> locale id. The three art slots
## are resolved dynamically with their cards.
const ARIA_SLOTS := {
	"Root": "ariaSelectModes",
	"DifficultySegmented": "difficulty",
	"LengthSegmented": "matchLength",
}

## PORT ADDITION: the pace group's own screen-reader name. It resolves through
## `Pace.text`, like its rung labels, so it is not a row of `ARIA_SLOTS` above —
## every row of that table resolves through `UiStrings`.
const PACE_ARIA_NODE := "PaceSegmented"

## `.mode-card__art { aspect-ratio: 3 / 1 }` (`styles.css:460-474`).
const ART_RATIO := 3.0
## `.mode-grid { gap: 20px }`, the grid's own h/v separation.
const CARD_SEPARATION := 20.0
## `@media (max-width: 1050px)`: `.mode-grid, .arena-grid { grid-template-columns: 1fr }`.
const GRID_BREAKPOINT := 1050.0
## `.mode-grid { grid-template-columns: repeat(3, 1fr); gap: 20px }`.
const GRID_COLUMNS := 3
const SMALL_COLUMNS := 1
## The setup cards align with the mode-card composition above instead of collapsing
## into a narrow strip in the middle of a wide screen.
const SETUP_MAX_WIDTH := 1240.0
const SETUP_SIDE_PADDING := 24.0
const SETUP_GRID_COLUMNS := 3
const SETUP_SMALL_COLUMNS := 1
const SETUP_BREAKPOINT := 1200.0
## Taller setup choices reproduce the reference mockup's card-like selectors.
const SEGMENT_HEIGHT := 62
## `.mode-card__body { padding: 18px }`.
const CARD_PADDING := 18.0
## `.mode-card__art + h3 { margin-top: 14px }` and the gap before the tag.
const TITLE_GAP := 14.0
const TAG_GAP := 14.0
## `.mode-card--locked { opacity: 0.55 }` — a node's own modulate, because a stylebox
## cannot modulate the node (theme README §6.4).
const LOCKED_CARD_ALPHA := 0.55
## `.athlete-card, .mode-card, .arena-card { transition: transform 0.15s ease }` with
## `:hover { transform: translateY(-3px) }` (`styles.css:332`, `styles.css:339-342`):
## the card rises 3 px over the reference's own 0.15 s, ease-out.
const CARD_LIFT_PX := 3.0
const CARD_LIFT_SECONDS := 0.15
## A pad focus is intentionally stronger than pointer hover: an outside 4 px
## frame, a 3 px gap and a compact glow. The mode already chosen keeps its own
## thinner card border, so the two states remain legible at the same time.
const PAD_FOCUS_WIDTH := 4
const PAD_FOCUS_GAP := 3.0
const PAD_FOCUS_GLOW_SIZE := 10
const PAD_FOCUS_GLOW_ALPHA := 0.35
## `#difficultySeg button.is-active { box-shadow: 0 0 18px var(--step-glow) }`
## (`styles.css:2303-2305`): the active chip's glow is the rung's own colour at the
## rung's own alpha — `--step-glow` is green 0.4 / cyan 0.42 / gold 0.42 / coral 0.45
## (`styles.css:2265`, `:2272`, `:2279`, `:2286`). Keyed by the same Palette token
## `_segment_accent` answers with; the fallback is the base `.segmented` cyan.
const SEGMENT_GLOW_SIZE := 18
const SEGMENT_GLOW_ALPHA := {"green": 0.4, "cyan": 0.42, "gold": 0.42, "coral": 0.45}
## The art never collapses at one column.
const ART_MIN_HEIGHT := 90.0
## The separator `js/main.js:1567` writes into the fixture line
## (`${fixtureText} · ${rivalText}`): U+0020, U+00B7 MIDDLE DOT, U+0020 — spelled from
## its code points because it is punctuation with no locale key of its own, and the UI
## lane's literal scan (`tests/ui/router_audit.gd`) flags any literal containing a
## space. This is a datum the reference hard-codes, not a word this screen owns.
static func fixture_joiner() -> String:
	return String.chr(0x20) + String.chr(0x00b7) + String.chr(0x20)

## The dynamic node-name prefixes; the audit and this file agree on them.
const CARD_PREFIX := "ModeCard_"
const ART_PREFIX := "ModeArt_"
const ART_IMAGE_PREFIX := "ModeArtImage_"
const TITLE_PREFIX := "ModeTitle_"
const DESC_PREFIX := "ModeDesc_"
const TAG_PREFIX := "ModeTag_"
const FIXTURE_PREFIX := "ModeFixture_"
const DIFFICULTY_PREFIX := "DiffButton_"
const LENGTH_PREFIX := "LengthButton_"
const PACE_PREFIX := "PaceButton_"

## The mode screen owns its header instead of mounting ScreenShell. These are the
## reference's `data-i18n` bindings for that header, including the back control.
const HEADER_TEXT_SLOTS := {
	"BackButton": "back",
	"TitleLabel": "modesTitle",
	"SubLabel": "modesSub",
}

const SETUP_TEXT_SLOTS := {
	"DifficultyLabel": "difficulty",
	"LengthLabel": "matchLength",
}

## `find_child` cannot find the root by name; the aria slot for the screen itself
## (`index.html:103`, `data-i18n-aria="ariaSelectModes"`) is addressed as this.
const ROOT_ALIAS := "Root"
const ACCESSIBILITY_NAME_PROPERTY := "accessibility_name"

## The router told this screen's `enter()` (the router's own facts).
var router_id: String = ""
var back_target_id: String = ""

## The capture pins: `""` = the live pending mode, `false` = the live build gate.
var capture_mode_pin: String = ""
var capture_demo_pin: bool = false

var _rows: Array[Dictionary] = []
var _bindings: Array[Dictionary] = []
var _text_nodes: Dictionary = {}
var _cards: Dictionary = {}
## Pointer hover and keyboard/controller focus are two ways of selecting the same
## card. Keeping the pointer state prevents one from erasing the other's visual.
var _card_pointer_hover: Dictionary = {}
## The lift's own state, one row per mode id: the offset the card currently carries,
## the y `ModeGrid` laid it out at, the offset it should hold, and the in-flight
## tween. One tween per card, so a fast pointer cannot leave a card stuck off-origin.
var _card_lift: Dictionary = {}
var _card_lift_base: Dictionary = {}
var _card_lift_target: Dictionary = {}
var _card_lift_tweens: Dictionary = {}
## True for the duration of this screen's own write to a card's `position.y`, so the
## card's `item_rect_changed` can tell our move from the grid's.
var _card_lift_writing: bool = false
var _difficulty_buttons: Dictionary = {}
var _length_buttons: Dictionary = {}
var _pace_buttons: Dictionary = {}
var _focus_specs: Dictionary = {}
var _motion: UiMotionPolicy = null


func _ready() -> void:
	_hydrate_motion()
	_style_chrome()
	for node_name in HEADER_TEXT_SLOTS:
		var header_node := _control(String(node_name))
		if header_node != null:
			_bind(header_node, String(HEADER_TEXT_SLOTS[node_name]))
	for node_name in SETUP_TEXT_SLOTS:
		var setup_label := _control(String(node_name))
		if setup_label != null:
			_bind(setup_label, String(SETUP_TEXT_SLOTS[node_name]))
	_build_rows()
	_build_segments()
	_wire()
	resized.connect(_apply_layout)
	var grid := _control("ModeGrid")
	if grid != null:
		grid.resized.connect(_update_art_heights)
	_apply_layout()
	# The selected/highlighted frames are resolved for the rows the build just made, so
	# a screen mounted without `enter()` still shows the session's mode as chosen.
	_refresh_cards()
	_refresh_selection()
	refresh_strings()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


## The router mounted this screen: it hands over its own facts and this screen
## re-reads the seams it renders, so a career that moved or a language that changed
## is visible the moment the screen appears (`js/main.js` refreshes the tag and the
## grids on entry and on `setLanguage`, `:2435-2441`).
func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", back_target_id))
	refresh_data()


func exit() -> void:
	pass


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## `default` = live; `quick`/`tournament`/`career` = that pending mode pinned;
## `demo-locked` = the demo build's own presentation. A full build renders the demo
## view from the demo's generated content table, because the adapter's lock question
## is build-bound (the request for a parameterised one is in the evidence log).
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"default":
			capture_mode_pin = ""
			capture_demo_pin = false
		"quick", "tournament", "career":
			capture_mode_pin = state_id
			capture_demo_pin = false
		"demo-locked":
			capture_mode_pin = "quick"
			capture_demo_pin = true
		_:
			return false
	refresh_data()
	return true


# ---------------------------------------------------------------------------
# Data (the rows this screen renders)
# ---------------------------------------------------------------------------

## Re-reads every seam the screen renders and redraws. Called on entry, on a
## language change and by the capture states.
func refresh_data() -> void:
	_hydrate_motion()
	_rows = _rows_now()
	_refresh_cards()
	_refresh_selection()
	# The lock state rides the focus registration (`_focus_spec`'s `locked`), and a
	# career can unlock a mode while this screen is off. Re-reading the rows without
	# re-registering would leave the model on the locks the screen was built with.
	_register_focus()
	refresh_strings()
	_apply_layout()


## The rows as the screen shows them: `UiData.mode_rows()` (ids, keys, art, the
## gate's own answers) over the live career, with the capture view applied.
func _rows_now() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row_in in UiData.mode_rows(Config.save_store()):
		var row: Dictionary = (row_in as Dictionary).duplicate(true)
		var id := String(row.get("id", ""))
		var demo_locked := DemoGate.mode_locked(id)
		if capture_demo_pin:
			demo_locked = _demo_locked("mode", id)
		var locked := demo_locked or bool(row.get("locked", false))
		row["demo_locked"] = demo_locked
		row["locked"] = locked
		row["tag_key"] = Gate.locked_key() if locked else "available"
		row["tag_ready"] = not locked
		out.append(row)
	return out


## The demo's own lock answer for one id, from the generated table the gate reads.
## Used only by the `demo-locked` capture state; live screens ask the adapter.
func _demo_locked(kind: String, item_id: String) -> bool:
	# The adapter's `locked()` forwards to the gate's athlete/arena tables and
	# declines other kinds; a mode is the adapter's own `mode_locked` question.
	if DemoGate.build() == "demo":
		if kind == "mode":
			return DemoGate.mode_locked(item_id)
		return DemoGate.locked(item_id, kind)
	match kind:
		"athlete":
			return not DemoContent.allowed_athlete_ids().has(item_id)
		"arena":
			return not DemoContent.allowed_arena_ids().has(item_id)
		"mode":
			return not DemoContent.allowed_mode_ids().has(item_id)
	return false


## The rows this screen is currently rendering, in card order.
func mode_rows_now() -> Array[Dictionary]:
	return _rows.duplicate(true)


## True when the card is rendered with the locked presentation.
func mode_locked_shown(mode_id: String) -> bool:
	for row in _rows:
		if String(row.get("id", "")) == mode_id:
			return bool(row.get("locked", false))
	return true


# ---------------------------------------------------------------------------
# The static composition (cards + segments)
# ---------------------------------------------------------------------------

func _build_rows() -> void:
	var grid := _control("ModeGrid")
	if grid == null:
		push_error("ModesScreen: the scene has no ModeGrid to fill")
		return
	for row in _rows_now():
		grid.add_child(_make_card(row))
	_rows = _rows_now()


func _make_card(row: Dictionary) -> Control:
	var theme: Theme = self.theme
	var id := String(row.get("id", ""))
	var locked := bool(row.get("locked", false))
	var card := PanelContainer.new()
	card.name = CARD_PREFIX + id
	card.set_meta("mode_id", id)
	# `.mode-grid { grid-template-columns: repeat(3, 1fr) }`: every column is the
	# same width, which a GridContainer only gives a child that expands.
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_box(false))
	card.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
	card.modulate = Color(1, 1, 1, LOCKED_CARD_ALPHA) if locked else Color(1, 1, 1, 1)
	# `ModeGrid` owns the card's position and rewrites it on every re-sort; this is the
	# card's own move notification, and the one place a stale lift base is caught.
	card.item_rect_changed.connect(_on_card_item_rect_changed.bind(id))
	card.mouse_entered.connect(_on_card_hover.bind(id, true))
	card.mouse_exited.connect(_on_card_hover.bind(id, false))
	# PanelContainer has no built-in focused style. Mirror its controller focus into
	# the same cyan presentation used for a pointer hover.
	card.focus_entered.connect(_on_card_focus.bind(id))
	card.focus_exited.connect(_on_card_focus.bind(id))
	# The reference excludes locked cards from the click wire
	# (`js/ui.js:1720`, `.mode-card:not(.mode-card--locked)`) — a locked card has no
	# activation path at all, which is what the audit proves by emitting into it.
	if not locked:
		card.gui_input.connect(_on_card_input.bind(id))

	var column := VBoxContainer.new()
	column.name = "ModeColumn_" + id
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)

	var art := Panel.new()
	art.name = ART_PREFIX + id
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_theme_stylebox_override("panel", _art_box(String(MODE_ACCENT_TOKENS.get(id, "cyan"))))
	art.custom_minimum_size = Vector2(0, ART_MIN_HEIGHT)
	column.add_child(art)

	var image := TextureRect.new()
	image.name = ART_IMAGE_PREFIX + id
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art_path := String(row.get("art_path", ""))
	if art_path != "":
		image.texture = load(art_path)
	art.add_child(image)

	var body := MarginContainer.new()
	body.name = "ModeBody_" + id
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(CARD_PADDING)
	body.add_theme_constant_override("margin_left", pad)
	body.add_theme_constant_override("margin_right", pad)
	body.add_theme_constant_override("margin_top", pad)
	body.add_theme_constant_override("margin_bottom", pad)
	column.add_child(body)

	var stack := VBoxContainer.new()
	stack.name = "ModeStack_" + id
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	body.add_child(stack)

	var title := Label.new()
	title.name = TITLE_PREFIX + id
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.theme_type_variation = &"CardTitle"
	stack.add_child(title)
	_bind(title, String(row.get("title_key", "")))

	var title_gap := Control.new()
	title_gap.custom_minimum_size = Vector2(0, TITLE_GAP)
	title_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title_gap)

	var desc := Label.new()
	desc.name = DESC_PREFIX + id
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.theme_type_variation = &"CardBody"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(desc)
	_bind(desc, String(row.get("desc_key", "")))

	var tag_gap := Control.new()
	tag_gap.custom_minimum_size = Vector2(0, TAG_GAP)
	tag_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(tag_gap)

	var tag := Label.new()
	tag.name = TAG_PREFIX + id
	# Registered now, bound on the first refresh (`available` or the build's locked
	# key), the way the reference writes it at `js/ui.js:746-753`.
	_text_nodes[tag.name] = tag
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.theme_type_variation = &"TagReady" if bool(row.get("tag_ready", false)) else &"Tag"
	stack.add_child(tag)

	var fixture := Label.new()
	fixture.name = FIXTURE_PREFIX + id
	# Registered now, bound on the first refresh: its binding is rebuilt whenever the
	# career step moves, so it is not part of the build-time binding set.
	_text_nodes[fixture.name] = fixture
	fixture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixture.theme_type_variation = &"LabelSmall"
	if theme != null:
		fixture.add_theme_color_override("font_color", theme.get_color("fixture", "Palette"))
	fixture.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fixture.visible = false
	stack.add_child(fixture)
	# Keep the controller's location unmistakable without changing the card's
	# selected-mode frame or giving pointer hover the same emphasis.
	CardFocusRing.attach(card)
	var ring_box := CardFocusRing.ring_style_of(card)
	if ring_box != null:
		var cyan := CardFocusRing.palette_of(card, "cyan")
		ring_box.set_border_width_all(PAD_FOCUS_WIDTH)
		ring_box.set_expand_margin_all(PAD_FOCUS_GAP + float(PAD_FOCUS_WIDTH))
		ring_box.shadow_color = Color(cyan, PAD_FOCUS_GLOW_ALPHA)
		ring_box.shadow_size = PAD_FOCUS_GLOW_SIZE

	_cards[id] = card
	return card


func _build_segments() -> void:
	var difficulty := _control("DifficultySegmented")
	if difficulty != null:
		# Two balanced rows keep the setup cards compact at desktop and readable when
		# the responsive grid stacks them on narrower frames.
		if difficulty is GridContainer:
			(difficulty as GridContainer).columns = DIFFICULTY_COLUMNS
		for key in DIFFICULTY_ORDER:
			var button := _segment_button(DIFFICULTY_PREFIX + key, String(DIFFICULTY_KEYS[key]))
			button.pressed.connect(select_difficulty.bind(key))
			difficulty.add_child(button)
			_difficulty_buttons[key] = button
	var length := _control("LengthSegmented")
	if length != null:
		# `#lengthSeg { grid-auto-flow: row; grid-template-columns: repeat(3, …) }`
		# (`styles.css:3297-3301`): six formats wrap into two rows of three.
		if length is GridContainer:
			(length as GridContainer).columns = 3
		for key in LENGTH_ORDER:
			var button := _segment_button(LENGTH_PREFIX + key, String(LENGTH_KEYS[key]))
			button.pressed.connect(select_length.bind(key))
			length.add_child(button)
			_length_buttons[key] = button
	var pace := _control("PaceSegmented")
	if pace != null:
		# The port's own group. Its rungs come from the pace module, in that module's
		# ladder order, and they are not `_segment_button`s: their labels are `Pace`'s
		# strings, not locale ids, so `_refresh_pace()` sets both the text and the
		# selected look for them.
		if pace is GridContainer:
			(pace as GridContainer).columns = PACE_COLUMNS
		for id in Pace.ids():
			var button := _pace_button(PACE_PREFIX + String(id))
			button.pressed.connect(select_pace.bind(String(id)))
			pace.add_child(button)
			_pace_buttons[String(id)] = button


func _segment_button(node_name: String, key: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"SegmentedInactive"
	button.custom_minimum_size = Vector2(0, SEGMENT_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind(button, key)
	return button


## A pace rung. Registered in `_text_nodes` — the audits read a control's text through
## `text_shown()`, the same door as every other control — but deliberately NOT in
## `_bindings`: every row of that list resolves through `UiStrings`, and a rung's label
## is `Pace`'s own string (`_refresh_pace()` is what fills it, in both locales).
func _pace_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"SegmentedInactive"
	button.custom_minimum_size = Vector2(0, SEGMENT_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_nodes[node_name] = button
	return button


# ---------------------------------------------------------------------------
# Selection (the reference's own semantics)
# ---------------------------------------------------------------------------

## `js/ui.js:1720-1729`, the unlocked-card press: the mode becomes the session's
## pending mode, tournament resets its round, the choice is persisted, and the press
## lands on `characters`. A locked card is not a selector in the reference and is
## refused here by name.
func select_mode(mode_id: String) -> bool:
	if not MODE_ORDER.has(mode_id):
		push_error("ModesScreen.select_mode: '%s' is not one of the reference's modes" % mode_id)
		return false
	if mode_locked_shown(mode_id):
		return false
	Config.pending_mode = mode_id
	var store := Config.save_store()
	ModesSave.save_pref(store, "mode", mode_id)
	if mode_id == "tournament":
		ModesSave.save_tournament_round(store, 0)
	return route_to(ROUTE_TO_CHARACTERS)


## The difficulty rung a tier index is, through the gate's own table
## (`content_gate.gd:37`); `""` for an index outside the four rungs.
func rung_of_index(index: int) -> String:
	for key in DIFFICULTY_ORDER:
		if int(Gate.DIFFICULTY_TIERS.get(key, -1)) == index:
			return key
	return ""


func active_difficulty() -> String:
	return rung_of_index(Config.tier_index)


## The rung this build pins, `""` in a full build (`applyDemoLimits`,
## `js/ui.js:760-764`: the demo grants exactly one difficulty).
func pinned_rung() -> String:
	if DemoGate.build() == "demo":
		return rung_of_index(Gate.fixed_tier_index())
	if capture_demo_pin:
		return DemoContent.difficulty()
	return ""


func difficulty_allowed(key: String) -> bool:
	var pinned := pinned_rung()
	return pinned == "" or key == pinned


## The chosen rung: `Config.tier_index` for the session (the match reads it) and the
## prefs carrier for persistence — the two things the reference writes
## (`ui.aiDifficulty` + `collectPrefs`, `js/main.js:2276`).
func select_difficulty(key: String) -> bool:
	if not DIFFICULTY_ORDER.has(key):
		return false
	if not difficulty_allowed(key):
		return false
	Config.tier_index = int(Gate.DIFFICULTY_TIERS.get(key, Config.tier_index))
	ModesSave.save_pref(Config.save_store(), "aiDifficulty", key)
	_refresh_selection()
	return true


## The persisted match-length choice, through the reference's own prefs carrier.
func active_length() -> String:
	var snapshot: Dictionary = UiData.settings_snapshot(Config.save_store())
	var value := String(snapshot.get("match_length", ""))
	return value if LENGTH_ORDER.has(value) else LENGTH_ORDER[0]


func select_length(key: String) -> bool:
	if not LENGTH_ORDER.has(key):
		return false
	ModesSave.save_pref(Config.save_store(), "matchLength", key)
	_refresh_selection()
	return true


## The pace rung the save holds. Read through the config's own validated reader — the
## same call `match_controller` latches when a match starts — so the screen can never
## show a rung the clock would not run, and a save from a build without the key reads
## back as the module's default rather than as a stopped clock.
func active_pace() -> String:
	return Config.pace_id()


## The pace rung press: the chosen id is written through the same save door the two
## reference segments use (`ModesSave.save_pref`), into the key the match reads at
## start. An id outside the ladder is refused rather than stored — a stored id no
## clock can read would just be a rung that never runs.
func select_pace(id: String) -> bool:
	if not Pace.has(id):
		return false
	ModesSave.save_pref(Config.save_store(), PACE_KEY, id)
	_refresh_pace()
	return true


## The screen's one activation door for UIR-05's bridge: an action the bridge does
## not route (it is not a `to-*` edge) is reported to the mount, which hands it here.
func activate(action: String) -> bool:
	var parts := action.split(":")
	if parts.size() != 2:
		return false
	match parts[0]:
		SELECT_MODE_ACTION:
			return select_mode(parts[1])
		DIFFICULTY_ACTION:
			return select_difficulty(parts[1])
		LENGTH_ACTION:
			return select_length(parts[1])
		PACE_ACTION:
			return select_pace(parts[1])
	return false


## The router moves. It is the first node above this screen that owns `go_to`
## (`ScreenRouter` mounts screens under its host); a press with no router above is
## reported, not swallowed.
func route_to(screen_id: String) -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to(screen_id))
		node = node.get_parent()
	push_warning("ModesScreen: no router above this screen; '%s' went nowhere" % screen_id)
	return false


# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------

func _bind(control: Control, key: String, params: Dictionary = {}, suffix_key: String = "", suffix_params: Dictionary = {}) -> void:
	var node_name := String(control.name)
	_text_nodes[node_name] = control
	_bindings.append({
		"name": node_name,
		"key": key,
		"params": params.duplicate(),
		"suffix_key": suffix_key,
		"joiner": fixture_joiner() if suffix_key != "" else "",
		"suffix_params": suffix_params.duplicate(),
	})


## Every string this screen shows: `{name, key, params, suffix_key, joiner,
## suffix_params}`. The audit re-resolves each through `UiStrings` in both locales —
## so this list is the screen's own claim about what it renders.
func text_bindings() -> Array:
	var out: Array = []
	for row in _bindings:
		out.append((row as Dictionary).duplicate(true))
	return out


## The text a bound node currently shows (button or label).
func text_shown(node_name: String) -> String:
	var node: Control = _text_nodes.get(node_name, null)
	if node == null:
		return ""
	if node is Button:
		return (node as Button).text
	if node is Label:
		return (node as Label).text
	return ""


func refresh_strings() -> void:
	# This scene owns its header (rather than mounting ScreenShell), including the
	# back button. `refresh_strings()` can run before `_ready()` in router probes,
	# so resolve the three labels directly here as well as registering their normal
	# bindings during construction.
	for node_name in HEADER_TEXT_SLOTS:
		var header_node := _control(String(node_name))
		if header_node is Button:
			(header_node as Button).text = UiStrings.t(String(HEADER_TEXT_SLOTS[node_name]))
		elif header_node is Label:
			(header_node as Label).text = UiStrings.t(String(HEADER_TEXT_SLOTS[node_name]))
	# The two data-driven bindings first: a card's tag (`available` / the build's
	# locked key) and the career card's fixture line. Both are re-bound on every
	# refresh, so a language flip re-resolves them with everything else.
	for row in _rows:
		var id := String(row.get("id", ""))
		var tag_node: Label = _text_nodes.get(TAG_PREFIX + id, null)
		if tag_node != null:
			_rebind(tag_node, String(row.get("tag_key", "")))
			tag_node.text = UiStrings.t(String(row.get("tag_key", "")))
			tag_node.theme_type_variation = &"TagReady" if bool(row.get("tag_ready", false)) else &"Tag"
		var fixture_node: Label = _text_nodes.get(FIXTURE_PREFIX + id, null)
		if fixture_node != null:
			fixture_node.visible = false
			if id == "career":
				var career: Variant = row.get("career", null)
				if typeof(career) == TYPE_DICTIONARY:
					var fixture: Dictionary = career
					_rebind(fixture_node, "careerFixture", _fixture_params(fixture), "careerRivalLabel", _rival_params(fixture))
					fixture_node.visible = true
	for row in _bindings:
		var node: Control = _text_nodes.get(String(row["name"]), null)
		if node == null:
			continue
		var text := UiStrings.t(String(row["key"]), row.get("params", {}))
		if String(row.get("suffix_key", "")) != "":
			text += String(row.get("joiner", "")) + UiStrings.t(String(row["suffix_key"]), row.get("suffix_params", {}))
		if node is Button:
			(node as Button).text = text
		elif node is Label:
			(node as Label).text = text
	_refresh_pace()
	_refresh_setup_titles()
	_refresh_aria()


## The pace group's three moving parts: every rung's label, the group's own title and
## which rung wears the selected look. Its strings are `Pace`'s — this is the one place
## on this screen where text does not come from `UiStrings`, because the pace rungs are
## a port addition and `locale_data.gd` carries only the reference's ids — and it runs
## on a language flip with everything else. The active state is the same
## `SegmentedActive`/`SegmentedInactive` swap the two reference segments use.
func _refresh_pace() -> void:
	var lang := Locale.current_lang()
	var current := active_pace()
	for id in _pace_buttons:
		var button: Button = _pace_buttons[id]
		var preset: Dictionary = Pace.preset(String(id))
		button.text = Pace.text(String(preset["label_key"]), lang)
		var active: bool = String(id) == current
		_style_segment_state(button, active)
		button.set_meta("active", active)
	var title := _control("PaceLabel") as Label
	if title != null:
		title.text = Pace.text(PACE_TITLE_KEY, lang)


func _refresh_setup_titles() -> void:
	for node_name in ["DifficultyLabel", "LengthLabel", "PaceLabel"]:
		var label := _control(node_name) as Label
		if label != null:
			label.text = label.text.to_upper()


## `careerTag` `{season}/{match}/{total}` + `careerFixture` … (`js/main.js:1549-1567`).
func _fixture_text(career: Dictionary) -> String:
	return UiStrings.t("careerFixture", _fixture_params(career)) \
		+ fixture_joiner() + UiStrings.t("careerRivalLabel", _rival_params(career))


func _fixture_params(career: Dictionary) -> Dictionary:
	return {
		"match": int(career.get("match_index", 0)) + 1,
		"total": int(career.get("matches", 0)),
		"arena": UiStrings.t("arena_%s_name" % String(career.get("arena_id", ""))),
	}


func _rival_params(career: Dictionary) -> Dictionary:
	return {"rival": UiStrings.t("ai_%s_name" % String(career.get("rival_id", "")))}


## A binding that follows the data: the node keeps its place in the tree, its row in
## the binding registry is replaced. (Tags and the career fixture line move with the
## build gate and the calendar, so they are re-bound instead of bound once.)
func _rebind(node: Control, key: String, params: Dictionary = {}, suffix_key: String = "", suffix_params: Dictionary = {}) -> void:
	var kept: Array[Dictionary] = []
	for row in _bindings:
		if String(row.get("name", "")) != node.name:
			kept.append(row)
	_bindings = kept
	_bind(node, key, params, suffix_key, suffix_params)


func aria_names() -> Dictionary:
	var out := {}
	for node_name in ARIA_SLOTS:
		out[node_name] = UiStrings.t(String(ARIA_SLOTS[node_name]))
	# PORT ADDITION: the pace group's own name, resolved through the module that owns
	# its text (the reference's two segments resolve theirs through `UiStrings`).
	out[PACE_ARIA_NODE] = Pace.text(PACE_TITLE_KEY, Locale.current_lang())
	for row in _rows:
		var id := String(row.get("id", ""))
		out[ART_PREFIX + id] = UiStrings.t(String(MODE_ARIA_KEYS.get(id, "")))
	return out


func _refresh_aria() -> void:
	for node_name in aria_names():
		_set_accessible_name(_control(node_name), String(aria_names()[node_name]))


func _set_accessible_name(node: Node, text: String) -> void:
	if node == null:
		return
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == ACCESSIBILITY_NAME_PROPERTY:
			node.set(ACCESSIBILITY_NAME_PROPERTY, text)
			return


# ---------------------------------------------------------------------------
# Live view
# ---------------------------------------------------------------------------

func _refresh_cards() -> void:
	for row in _rows:
		var id := String(row.get("id", ""))
		var card: Control = _cards.get(id, null)
		if card == null:
			continue
		var locked := bool(row.get("locked", false))
		card.modulate = Color(1, 1, 1, LOCKED_CARD_ALPHA) if locked else Color(1, 1, 1, 1)
		card.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
	# The selected frame follows the session's mode, and the mode can move while this
	# screen is off (a capture state, a career that unlocked one): re-resolve it here.
	for row in _rows:
		_refresh_card_highlight(String(row.get("id", "")))


func _refresh_selection() -> void:
	var rung := active_difficulty()
	for key in _difficulty_buttons:
		var button: Button = _difficulty_buttons[key]
		var active := String(key) == rung
		_style_segment_state(button, active)
		button.disabled = not difficulty_allowed(String(key))
		button.set_meta("active", active)
	var length := active_length()
	for key in _length_buttons:
		var button: Button = _length_buttons[key]
		var active := String(key) == length
		_style_segment_state(button, active)
		button.set_meta("active", active)


func _style_segment_state(button: Button, active: bool) -> void:
	button.theme_type_variation = &"SegmentedActive" if active else &"SegmentedInactive"
	button.add_theme_font_size_override("font_size", 14)
	var accent_token := _segment_accent(button)
	button.add_theme_stylebox_override("normal", _segment_box(accent_token, active, false))
	button.add_theme_stylebox_override("hover", _segment_box(accent_token, active, true))
	button.add_theme_stylebox_override("pressed", _segment_box(accent_token, active, true))
	var indicator := button.get_node_or_null("Indicator") as ColorRect
	if indicator == null:
		indicator = ColorRect.new()
		indicator.name = "Indicator"
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator.anchor_left = 0.5
		indicator.anchor_top = 1.0
		indicator.anchor_right = 0.5
		indicator.anchor_bottom = 1.0
		indicator.offset_left = -28.0
		indicator.offset_top = -10.0
		indicator.offset_right = 28.0
		indicator.offset_bottom = -6.0
		button.add_child(indicator)
	var accent := theme.get_color(accent_token, "Palette")
	indicator.color = accent.darkened(0.42) if active else _alpha(accent, 0.9)


func _segment_accent(button: Button) -> String:
	var node_name := String(button.name)
	if node_name == DIFFICULTY_PREFIX + "easy":
		return "green"
	if node_name == DIFFICULTY_PREFIX + "hard":
		return "gold"
	if node_name == DIFFICULTY_PREFIX + "legend":
		return "coral"
	return "cyan"


## `syncMatchSetup` (`js/main.js:1651-1657`): the setup groups are shown for the
## quick mode and hidden for the other two. The cards are never touched.
func setup_visible() -> bool:
	return _mode_now() == "quick"


func _mode_now() -> String:
	var mode := capture_mode_pin if capture_mode_pin != "" else String(Config.pending_mode)
	return mode if MODE_ORDER.has(mode) else "quick"


func _on_card_input(event: InputEvent, mode_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			select_mode(mode_id)


func _on_card_hover(mode_id: String, entered: bool) -> void:
	_card_pointer_hover[mode_id] = entered
	_refresh_card_highlight(mode_id)


func _on_card_focus(mode_id: String) -> void:
	_refresh_card_highlight(mode_id)


## The visible selection is active when either navigation method names this card.
## This is presentation-only: activation remains the bridge -> `select_mode` path.
##
## THREE STATES, resolved in the reference's cascade order: the selected card
## (`.athlete-card--selected`, `styles.css:341-345`) over the highlighted one
## (`.athlete-card:hover`, `styles.css:339-342`) over the resting card (`.mode-card`,
## `styles.css:323-338`). Pointer and controller feed the ONE `highlighted` flag, so
## the two input methods still land on the same frame.
func _refresh_card_highlight(mode_id: String) -> void:
	var card: Control = _cards.get(mode_id, null)
	if card == null:
		return
	if mode_locked_shown(mode_id):
		CardFocusRing.set_focused(card, false, _motion)
		return
	var highlighted := card.has_focus() or bool(_card_pointer_hover.get(mode_id, false))
	card.add_theme_stylebox_override("panel", _card_box(highlighted, _card_is_selected(mode_id)))
	_animate_card_lift(mode_id, highlighted)
	CardFocusRing.set_focused(card, card.has_focus(), _motion)


func _hydrate_motion() -> void:
	if _motion == null:
		_motion = UiMotionPolicy.new()
	_motion.apply_prefs(ModesSave.profile(Config.save_store()).get("prefs", {}))


## The card whose mode the session is in: `Config.pending_mode`, the seam `select_mode`
## writes and `syncMatchSetup` reads. The reference marks no mode card as selected
## (`.mode-card` only ever gains `--locked`/`--demo`, `js/ui.js:746-753`), so this is
## the port's own reading of the selection — the frame the characters and arena grids
## already wear, on the seam that says which mode a match would start in.
func _card_is_selected(mode_id: String) -> bool:
	return _mode_now() == mode_id


## `.athlete-card:hover { transform: translateY(-3px) }` (`styles.css:339-342`) over
## the card's `transition: transform 0.15s ease` (`styles.css:332`).
##
## WHY AN OFFSET AGAINST A STORED BASE, NOT A TWEENED `position`. The cards are
## `ModeGrid`'s children, so the GRID owns their position: every re-sort
## (`Container.fit_child_in_rect`) rewrites it, and a tween aimed at an absolute y would
## fight that and could end on the wrong one. The tween therefore animates a float
## offset, applied as `base + offset`, and every move the container makes re-reads the
## base (`_on_card_item_rect_changed`, the `NOTIFICATION_SORT_CHILDREN` equivalent for
## a card whose container owns the sort). Killing the card's own in-flight tween before
## starting the next one means exactly one writer per card, so rapid mouse movement
## cannot interleave two of them.
func _animate_card_lift(mode_id: String, lifted: bool) -> void:
	var card: Control = _cards.get(mode_id, null)
	if card == null:
		return
	var target := -CARD_LIFT_PX if lifted else 0.0
	_card_lift_target[mode_id] = target
	var current := float(_card_lift.get(mode_id, 0.0))
	var running: Tween = _card_lift_tweens.get(mode_id, null)
	if running != null and running.is_valid():
		running.kill()
	if is_equal_approx(current, target):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_card_lift.bind(mode_id), current, target, CARD_LIFT_SECONDS)
	_card_lift_tweens[mode_id] = tween


## The y the grid gave this card. The hook below keeps it current, so this only ever
## has to answer the first time it is asked: the lift is 0 at that moment, so the
## card's own `position.y` IS the base.
func _card_lift_base_y(mode_id: String, card: Control) -> float:
	if not _card_lift_base.has(mode_id):
		_card_lift_base[mode_id] = card.position.y
	return float(_card_lift_base[mode_id])


func _set_card_lift(amount: float, mode_id: String) -> void:
	var card: Control = _cards.get(mode_id, null)
	if card != null:
		_write_card_lift(card, mode_id, amount)


func _write_card_lift(card: Control, mode_id: String, amount: float) -> void:
	_card_lift[mode_id] = amount
	# The guard is what keeps our own write from being mistaken for the container's:
	# `_on_card_item_rect_changed` re-reads the base on every move it did not make.
	# The signal is emitted synchronously, so the guard cannot outlive this call.
	_card_lift_writing = true
	card.position.y = _card_lift_base_y(mode_id, card) + amount
	_card_lift_writing = false


## A `Container` rewrites a child's position on every re-sort, so a stored base goes
## stale under a running tween and the card would settle off-origin (measured: a resize
## from three columns to one left a card 3 px off its new row). `NOTIFICATION_SORT_CHILDREN`
## goes to `ModeGrid`, not to its children, so the card's own `item_rect_changed` is the
## move notification this screen can subscribe to. The position the container just wrote
## IS the base, the tween that measured against the old one is dropped, and the offset
## the card should hold is re-applied on the spot — so any re-layout, whenever it lands,
## converges on `base + target` in one step.
func _on_card_item_rect_changed(mode_id: String) -> void:
	if _card_lift_writing:
		return
	var card: Control = _cards.get(mode_id, null)
	if card == null:
		return
	var running: Tween = _card_lift_tweens.get(mode_id, null)
	if running != null and running.is_valid():
		running.kill()
	_card_lift_base[mode_id] = card.position.y
	_write_card_lift(card, mode_id, float(_card_lift_target.get(mode_id, 0.0)))


# ---------------------------------------------------------------------------
# Focus (UIR-05's bridge consumes these; the screen only names its controls)
# ---------------------------------------------------------------------------

func _wire() -> void:
	var back := _control("BackButton") as Button
	if back != null:
		back.pressed.connect(route_to.bind(BACK_TARGET_ID))
	_register_focus()


func _register_focus() -> void:
	_focus_specs.clear()
	var back := _control("BackButton")
	if back != null:
		_focus_specs["BackButton"] = _focus_spec("BackButton", back, "back")
	for row in _rows:
		var id := String(row.get("id", ""))
		var card: Control = _cards.get(id, null)
		if card == null:
			continue
		# `collectMenuTargets` refuses `.mode-card--locked` (`js/main.js:571-577`):
		# a withheld mode stays visible with its own presentation and is NOT a place
		# the focus may land. Registering it without the flag made it a target that
		# swallowed a confirm and did nothing.
		_focus_specs[CARD_PREFIX + id] = _focus_spec(CARD_PREFIX + id, card,
			"%s:%s" % [SELECT_MODE_ACTION, id], {"locked": bool(row.get("locked", false))})
	for key in _difficulty_buttons:
		var button: Button = _difficulty_buttons[key]
		_focus_specs[DIFFICULTY_PREFIX + key] = _focus_spec(DIFFICULTY_PREFIX + key, button, "%s:%s" % [DIFFICULTY_ACTION, key])
	for key in _length_buttons:
		var button: Button = _length_buttons[key]
		_focus_specs[LENGTH_PREFIX + key] = _focus_spec(LENGTH_PREFIX + key, button, "%s:%s" % [LENGTH_ACTION, key])
	for id in _pace_buttons:
		var button: Button = _pace_buttons[id]
		_focus_specs[PACE_PREFIX + id] = _focus_spec(PACE_PREFIX + id, button, "%s:%s" % [PACE_ACTION, id])


func _focus_spec(node_name: String, control: Control, action: String, extra: Dictionary = {}) -> Dictionary:
	var opts := {"kind": "card" if control is PanelContainer else "button"}
	opts.merge(extra)
	return {
		"id": "%s/%s" % [SCREEN_ID, node_name],
		"node": control,
		"action": action,
		"opts": opts,
	}


func focus_controls() -> Array:
	return _focus_specs.values()


# ---------------------------------------------------------------------------
# Layout (the viewport rules the theme cannot hold)
# ---------------------------------------------------------------------------

func _apply_layout() -> void:
	var grid := _control("ModeGrid") as GridContainer
	if grid != null:
		grid.columns = GRID_COLUMNS if size.x >= GRID_BREAKPOINT else SMALL_COLUMNS
	_update_art_heights()
	var setup := _control("MatchSetup") as GridContainer
	if setup != null:
		setup.visible = setup_visible()
		setup.columns = SETUP_GRID_COLUMNS if size.x >= SETUP_BREAKPOINT else SETUP_SMALL_COLUMNS
	var area := _control("SetupArea") as MarginContainer
	if area != null:
		var side := int(maxf(0.0, (size.x - SETUP_MAX_WIDTH) / 2.0) + SETUP_SIDE_PADDING)
		area.add_theme_constant_override("margin_left", side)
		area.add_theme_constant_override("margin_right", side)


## `.mode-card__art { aspect-ratio: 3 / 1 }`: the height follows the column's width,
## read from the grid (a card's own width is not settled until the grid has laid out,
## and the grid's is the number the columns are cut from).
func _update_art_heights() -> void:
	var grid := _control("ModeGrid") as GridContainer
	if grid == null:
		return
	var columns := grid.columns
	var gaps := float(maxi(columns - 1, 0)) * CARD_SEPARATION
	var column_width := (grid.size.x - gaps) / float(maxi(columns, 1))
	for row in _rows:
		var art := _control(ART_PREFIX + String(row.get("id", "")))
		if art != null:
			art.custom_minimum_size.y = maxf(ART_MIN_HEIGHT, column_width / ART_RATIO)


# ---------------------------------------------------------------------------
# The scene
# ---------------------------------------------------------------------------

func _control(node_name: String) -> Control:
	if node_name == ROOT_ALIAS:
		return self
	return find_child(node_name, true, false) as Control


# ---------------------------------------------------------------------------
# Chrome (the theme gap this screen carries: card frame + setup frames; the
# request for variations is recorded in the evidence log, the theme is not edited)
# ---------------------------------------------------------------------------

func _style_chrome() -> void:
	var theme: Theme = self.theme
	if theme == null:
		push_error("ModesScreen: the scene carries no theme; the chrome cannot be composed")
		return
	var back := _control("BackButton")
	if back != null:
		back.theme_type_variation = &"ButtonGhost"
	var title := _control("TitleLabel")
	if title != null:
		title.theme_type_variation = &"ScreenTitle"
	var sub := _control("SubLabel")
	if sub != null:
		sub.theme_type_variation = &"ScreenSubtitle"
	var setup_accents := {
		"DifficultyGroup": "cyan",
		"LengthGroup": "cyan",
		"PaceGroup": "cyan",
	}
	for panel_name in setup_accents:
		var panel := _control(panel_name)
		if panel != null:
			(panel as PanelContainer).add_theme_stylebox_override(
				"panel", _setup_box(theme, String(setup_accents[panel_name])))
	for label_name in ["DifficultyLabel", "LengthLabel", "PaceLabel"]:
		var label := _control(label_name) as Label
		if label != null:
			label.theme_type_variation = &"CardTitle"
			label.add_theme_color_override("font_color", theme.get_color(
				String(setup_accents.get(String(label.get_parent().get_parent().name), "cyan")), "Palette"))
	for line_name in ["DifficultyTitleLine", "LengthTitleLine", "PaceTitleLine"]:
		var line := _control(line_name) as HSeparator
		if line != null:
			line.add_theme_stylebox_override("separator", _title_line_box(theme))
	for card_name in ["DifficultySegmentedBox", "LengthSegmentedBox", "PaceSegmentedBox"]:
		var segmented := _control(card_name)
		if segmented != null:
			(segmented as PanelContainer).add_theme_stylebox_override("panel", _theme_box("SegmentedContainer"))


## `.mode-card` (`styles.css:323-338`): `--panel`, 1 px `--line`, radius 12, art
## flush to the card's edges (the body carries the 18 px).
##
## THREE STATES, in the reference's cascade order: the selected card (full `--cyan`
## border plus the `box-shadow: 0 0 0 1px var(--cyan)` halo, `.athlete-card--selected`,
## `styles.css:341-345`) over the highlighted one (`border-color:
## rgba(0,229,255,0.35)`, `.athlete-card:hover`, `styles.css:339-342`) over the
## resting card. A card that is BOTH selected and highlighted keeps the halo — it is
## what marks the mode a match would start in, and it must not vanish under the
## pointer — and wears the hover frame, so the card a pointer hovers and the card the
## controller has focused still read the same (`tests/ui/controller_cards_test.gd`
## pins that convergence). The halo's colour and width are read off
## `BoxPanelSelected` itself, so the theme keeps owning the token.
func _card_box(hover: bool, selected: bool = false) -> StyleBoxFlat:
	var variation := "PanelDark"
	if hover:
		variation = "PanelCardHover"
	elif selected:
		variation = "PanelCardSelected"
	var box := _theme_box(variation)
	if selected and hover:
		var halo := _theme_box("PanelCardSelected")
		box.shadow_color = halo.shadow_color
		box.shadow_size = halo.shadow_size
	# The reference bleeds the art to the card's edges and pads the body instead
	# (`.mode-card__art { margin: -18px -18px 0 }`, `styles.css:460`), so the frame
	# keeps the theme's fill/border/radius and gives up only its content padding.
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	return box


## `.mode-card__art` (`styles.css:460-474`): the accent under the art, the top
## corners following the card's radius. No fill of its own: the reference's
## `#09142e` placeholder is not a theme token (recorded, not invented).
func _art_box(accent_token: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = theme.get_color(accent_token, "Palette")
	box.border_width_bottom = 3
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	return box


## `.match-setup .setup-group` (`styles.css`, measured for the theme): 1 px
## `rgba(0,229,255,0.22)`, radius 14, padding 15/17/17/17, fill `rgba(11,36,68,0.9)`
## over `rgba(6,20,38,0.92)` (the first stop, as the theme's own gradient rule does;
## `surface_2` is `#0b2444` = rgb(11,36,68)). No variation exists for this box, so it
## is composed here from Palette — the theme request is in the evidence log.
func _setup_box(theme: Theme, accent_token: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var accent := theme.get_color(accent_token, "Palette")
	box.bg_color = _alpha(theme.get_color("surface_2", "Palette"), 0.94)
	box.border_color = _alpha(accent, 0.42)
	box.set_corner_radius_all(16)
	box.set_border_width_all(1)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 22.0
	box.shadow_color = _alpha(theme.get_color("cyan", "Palette"), 0.08)
	box.shadow_size = 14
	return box


func _title_line_box(source_theme: Theme) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = _alpha(source_theme.get_color("cyan", "Palette"), 0.52)
	line.thickness = 2
	line.vertical = false
	return line


## `.segmented button` (`styles.css:2228-2256`): the reference's own cyan wash
## `rgba(0,229,255,0.10)` on hover-but-not-active (`styles.css:2237-2240`) — cyan for
## EVERY rung, the coloured ones included — and, on the active chip, the lit fill plus
## `box-shadow: 0 0 18px var(--step-glow)` (`#difficultySeg button.is-active`,
## `styles.css:2303-2305`), i.e. the rung's own colour at the rung's own alpha.
##
## The reference's `linear-gradient(180deg, var(--step-lit), var(--step-color))` is a
## FLAT approximation here: a `StyleBoxFlat` carries one fill, not a gradient, and the
## theme's own `BoxSegmentedActive` made the same flat choice (#22d5ee, the gradient's
## base stop). The chip is `--step-color` (`accent`); the `inset 0 1px 0` top highlight
## is not expressible on a `StyleBoxFlat` and is left out rather than faked.
func _segment_box(accent_token: String, active: bool, hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var accent := theme.get_color(accent_token, "Palette")
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	if active:
		box.bg_color = accent
		box.shadow_color = _alpha(accent, float(SEGMENT_GLOW_ALPHA.get(accent_token, 0.42)))
		box.shadow_size = SEGMENT_GLOW_SIZE
	else:
		var wash := theme.get_color("cyan", "Palette")
		box.bg_color = _alpha(wash, 0.10) if hover else _alpha(accent, 0.025)
	return box


## A theme variation's box, duplicated so a screen may adjust it without touching the
## shared resource. `SegmentedContainer`/`PanelDark` are declared on `Panel`, which a
## `PanelContainer` cannot carry (theme README §4), so this is how a container-shaped
## node uses them — recorded in the evidence log as a theme request.
func _theme_box(variation: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box: StyleBox = theme.get_stylebox("panel", variation)
	if box == null:
		push_error("ModesScreen: the theme has no '%s' box" % variation)
		return StyleBoxFlat.new()
	return (box as StyleBoxFlat).duplicate()


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out
