## ArenaScreen.gd — `screen-arena` (`index.html:157-178`), the last screen before the field.
##
## WHAT THIS SCREEN IS. The reference's ninth section: the header, the arena grid the
## renderer fills (`renderArenas`, `js/ui.js:1220-1275`), and the player-mode panel
## (`index.html:168-177`). Three states overlap on this grid and each one is the
## reference's own:
##
##   * the build's wall (`demoLocked(arena, DEMO_CONTENT.arenas)`), which is a lock like
##     any other on the card but a different sentence — `demoOnlyFull`;
##   * the career's wall (`isUnlocked(arena, ui.career)`), which in the frozen table no
##     arena carries (none has an `unlock`) and which is still read, not assumed;
##   * the calendar's own choice: in career the arena is the fixture's and the others stay
##     visible but switched off, with the sentence that says why — `arenaOtherMatchday`,
##     or `arenaOtherRound` in a tournament. The fixture card carries the badge that names
##     where the choice came from (`arenaByCalendar` / `arenaByBracket`).
##
## The reference's own comment (`js/ui.js:1227-1230`) gives the reason: the match uses the
## fixture's arena and throws `ui.selectedArena` away, so letting the grid choose was "a
## choice the game discarded". This port keeps that note in behaviour, not in a comment:
## a non-fixture card is disabled in career/tournament exactly as `fuoriGiornata` is.
##
## THE WORLD FIVE (port additions, `arena_catalog.gd::world_rows()`). The recreated
## path offers the same five the ported menu column does, from the same one catalog
## (`UiData.world_arena_rows()`, i.e. `content_gate.gd::arena_catalog()`), and under
## the same rules: in a FULL build they are a further choice, in a DEMO build the set
## does not exist at all (no row, no card), and in career/tournament the calendar's
## fixture is the only arena a start can use, so every world card is switched off
## exactly like a non-fixture frozen card. Their grid (`WorldArenaGrid`, built here
## because the scene carries the frozen grid alone) leaves the frozen nine's own grid
## untouched: `arena_rows_now()` is still the nine-row catalog the arena audits pin.
##
## WHAT IT NEVER DOES. No mode logic, no simulation: the start path is the contract that
## already exists (`game/main_menu.gd:497` quick → `res://game/Match.tscn`, `:502` modes →
## `res://game/ModeScreen.tscn`), reached through `Config.pending_mode` and
## `Config.arena_index` — the seams `game/match_config.gd:22-27` documents.
## A world arena has no roster index, so its seat is the id itself
## (`Config.set_arena_id`, the same call the ported column's world row makes).
##
## THE CARD STATES MOVE (the reference's hover states, ported as motion). The web cards
## are CSS transitions, not two frames: `.arena-card:hover` rides 3 px up over 0.15 s
## with its border lightening (`styles.css:332`, `:335-340`), the chosen card wears a
## halo instead of a second border (`:342-345`), and the chips under the player-mode
## panel have three states, not two (`:2220-2252`). The port drew the states and never
## moved one — a `StyleBoxFlat` swap cannot translate anything — so the lift is a
## `Tween` on the card's own `position.y` (`_lift_to`) and the halo is the box's
## `shadow_size`/`shadow_color`. A card is lit while the POINTER or the PAD holds it:
## the reference has one `:hover`, the focus model paints the same cards
## (`game/menu_focus.gd:73`), and one lift serves both.
##
## SPLIT FROM THE SCENES. Like the other screens in this lane: named nodes only, every
## string resolved from `UiStrings`, chrome read off `padel_theme.tres`.

extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const CardFocusRing := preload("res://src/ui/components/CardFocusRing.gd")
const UiMotionPolicy := preload("res://src/ui/accessibility/UiMotionPolicy.gd")
const Locale := preload("res://src/locale/locale.gd")

const SCREEN_ID := "arena"
const BACK_TARGET_ID := "characters"
## The two scenes `game/main_menu.gd` already changes to, verbatim (`:497`, `:502`).
const MATCH_SCENE := "res://game/Match.tscn"
const MODE_SCENE := "res://game/ModeScreen.tscn"

const GRID_COLUMNS := 3
const SMALL_COLUMNS := 1
const GRID_BREAKPOINT := 1050.0
const PREVIEW_RATIO := 16.0 / 9.0
const PREVIEW_MIN_HEIGHT := 120.0
## `.arena-card__body { padding: 18px }` (`styles.css:323-345`).
const CARD_PADDING := 18.0

## `.arena-card:hover { transform: translateY(-3px) }` (`styles.css:335-340`) over the
## card's own `transition: transform 0.15s ease` (`:332`): the lift is as animated as the
## reference's own, so it is a tween and not a second frame.
const CARD_LIFT := 3.0
const LIFT_SECONDS := 0.15
## How far off the captured rest Y a card may sit before this screen reads the position
## as the grid's own rather than one of its tweens (`_rest_y_of`): a `GridContainer`
## writes whole pixels, the tween writes fractions, and the smallest lift is 3 px.
const LIFT_EPSILON := 0.5
## The halo `.athlete-card--selected` (`styles.css:342-345`) and `.arena-card--in-programma`
## (`:3126-3128`) wear. One `StyleBoxFlat` carries ONE shadow, so the `0 0 0 1px
## var(--cyan)` ring is the box's own cyan border and the shadow is the `0 12px 40px
## rgba(0, 229, 255, 0.18)` glow — at 16 px of blur, because `shadow_size` is a radius
## drawn on both sides of the box and the grid leaves 20 px between two cards, where the
## reference's 40 px blur would paint over its neighbours.
const HALO_SIZE := 16
const HALO_ALPHA := 0.18
## `.segmented button.is-active { box-shadow: 0 0 16px rgba(22, 190, 215, 0.42), inset 0
## 1px 0 rgba(255, 255, 255, 0.38) }` (`styles.css:2248-2252`): the chosen chip keeps its
## own light source, at the size and ink the theme already carries for it
## (`padel_theme.tres:187-188`).
const SEGMENT_GLOW_SIZE := 16
const SEGMENT_GLOW_COLOR := Color(0.08627451, 0.74509805, 0.84313726, 0.42)
## `.segmented button:hover:not(.is-active) { background: rgba(0, 229, 255, 0.1); color:
## #cfe9f7 }` (`styles.css:2238-2241`) — through the theme's own cyan, 229/255 is the
## palette token's own blue and only the alpha is the reference's.
const SEGMENT_HOVER_ALPHA := 0.1
const SEGMENT_HOVER_INK := "cfe9f7"
## The meta a lifted card carries: its rest Y, the offset in flight and the tween
## carrying it (`_lift_state`).
const LIFT_META := "arena_card_lift"

const CARD_PREFIX := "ArenaCard_"
const ART_PREFIX := "ArenaArt_"
const NAME_PREFIX := "ArenaName_"
const LINE_PREFIX := "ArenaLine_"
const BADGE_PREFIX := "ArenaBadge_"
const LOCK_PREFIX := "ArenaLock_"
const MODE_PREFIX := "PlayerModeButton_"
## The world five's own nodes: a second grid, so the frozen nine's nodes (which the
## arena audits read by name) are never renamed or reshuffled.
const WORLD_AREA := "WorldGridArea"
const WORLD_GRID := "WorldArenaGrid"
const WORLD_CARD_PREFIX := "WorldArenaCard_"
const WORLD_ART_PREFIX := "WorldArenaArt_"
const WORLD_NAME_PREFIX := "WorldArenaName_"
const WORLD_LINE_PREFIX := "WorldArenaLine_"
## The world five's CARD art, copied from the direction deck
## (`art/concepts/world-arenas-r1/`) and named by arena id so the path is the id.
## Card preview only: the 3D backdrop stays procedural (`world_info().artwork` is
## empty on purpose), so these stills never reach a match.
const WORLD_ART_DIR := "res://game/arenas/art/world/"
const BODY_NODE := "Body"
const GRID_AREA_NODE := "GridArea"

const WORDING_QUICK := "quick"
const WORDING_CAREER := "career"
const WORDING_TOURNAMENT := "tournament"
const PLAYER_MODES := ["solo", "coop", "pvp"]
const CAPTURE_STATES := ["default", "career-calendar", "tournament-bracket", "demo-locked", "player-mode-coop"]

const MODE_KEYS := {
	"solo": "pmSolo",
	"coop": "pmCoop",
	"pvp": "pmPvp",
}

var _rows: Array = []
## The world five this build offers, in the catalog's order (empty in a demo).
var _world_rows: Array = []
var _wording: String = WORDING_QUICK
var _selected_id: String = ""
var _locked_ids: Array = []
var _out_of_matchday: Array = []
var _in_program: String = ""
var _capture_lock_pin: String = ""
var _capture_entry_mode: String = ""
var _bindings: Array[Dictionary] = []
var _text_nodes: Dictionary = {}
var _focus_specs: Array[Dictionary] = []
## The selected arena and the controller's current card are distinct states: a
## stick move must show where A will act without changing the player's saved
## arena until they confirm it.
var _focused_card_id: String = ""
## The arena the POINTER is over. A separate holder from `_focused_card_id` (the pad
## moves the focus, the mouse does not), and the two are ONE visual state: the reference
## has a single `:hover` (`styles.css:335-340`) and the focus model hands a card the same
## focus a controller moves (`game/menu_focus.gd:73`).
var _hovered_card_id: String = ""
## One re-capture of the captured rest Y at a time (`_refresh_lifts`): a resize arrives as
## several `resized` signals through the frame's containers.
var _lift_refresh_queued: bool = false
## The port's one door for "may this animation run" (`UiMotionPolicy`), hydrated from the
## saved prefs (`SettingsScreen._stored_prefs`, `ModesSave.profile`): the reference's
## `body.reduce-motion` switches `.menu-focus`'s keyframes off (`styles.css:2748-2758`).
var _motion: UiMotionPolicy = null


func screen_id() -> String:
	return SCREEN_ID


## The contract's own name for the declared back edge (`ScreenContract.back_target`).
func back_target() -> String:
	return BACK_TARGET_ID


func capture_states() -> Array:
	return CAPTURE_STATES.duplicate()


# ---------------------------------------------------------------------------
# Lifecycle


func _ready() -> void:
	_style_chrome()
	_apply_layout()
	_apply_accessibility()
	resized.connect(_apply_layout)
	var grid := _control("ArenaGrid")
	if grid != null:
		grid.resized.connect(_update_preview_heights)
		# The grid is the truth about where a card rests: a relayout re-reads the
		# captured Y (`_refresh_lifts`), so a card that is lifted while the window
		# changes size comes back to the row it is actually drawn in.
		grid.resized.connect(_refresh_lifts)
	_wire()
	refresh_data()


func enter(payload: Dictionary = {}) -> void:
	if payload.has("entry_mode"):
		_capture_entry_mode = String(payload["entry_mode"])
	if _capture_entry_mode == "":
		_capture_entry_mode = String(Config.pending_mode)
	refresh_data()


func exit() -> void:
	pass


func _wire() -> void:
	var back := _control("BackButton") as Button
	if back != null:
		back.pressed.connect(_on_back)
	(back as Button).focus_mode = Control.FOCUS_ALL
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key) as Button
		if button != null:
			button.pressed.connect(select_player_mode.bind(key))
			button.focus_mode = Control.FOCUS_ALL


func _on_back() -> void:
	route_to(BACK_TARGET_ID)


## The router moves. It is the first node above this screen that owns `go_to`
## (`ScreenRouter` mounts screens under its host); a press with no router above is
## reported, not swallowed.
func route_to(screen_id: String) -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to(screen_id))
		node = node.get_parent()
	push_warning("ArenaScreen: no router above this screen; '%s' went nowhere" % screen_id)
	return false


# ---------------------------------------------------------------------------
# Data


## The nine rows of `renderArenas` (`js/ui.js:1240-1268`), the build's answer included.
func refresh_data() -> void:
	_hydrate_motion()
	_wording = _wording_now()
	_rows = _rows_now()
	_world_rows = _world_rows_now()
	_locked_ids = []
	for row in _rows:
		if bool((row as Dictionary).get("locked", false)):
			_locked_ids.append(String((row as Dictionary).get("id", "")))
	_in_program = _fixture_arena_id()
	# The calendar's own choice cannot be a locked card: `selectableArenas()` excludes
	# them before the fixture is drawn (`js/ui.js:490-503`).
	if _in_program != "" and _locked_ids.has(_in_program):
		_in_program = ""
	_out_of_matchday = []
	if _in_program != "":
		# In career and tournament EVERY other arena is switched off, the world five
		# included: the start uses the fixture whatever was pressed.
		for card in _card_ids():
			if card != _in_program and not _locked_ids.has(card):
				_out_of_matchday.append(card)
	if _selected_id == "" or not _is_a_card(_selected_id) \
			or arena_card_state(_selected_id) == "locked":
		_selected_id = _first_selectable_id()
	_build_grid()
	# The header is bound AFTER the grid: `_clear(ArenaGrid)` resets the binding list
	# the whole screen shares (`_bindings`, `_text_nodes`), so a header bound before it
	# would show its key on the next refresh — the 2026-09-18 screenshot read
	# "arenaTitle" / "arenaSub" / "back" for exactly that reason.
	_bind_header()
	_build_world_grid()
	_build_player_mode()
	_apply_layout()
	refresh_strings()


## Every arena this screen draws a card for: the frozen grid first, then the world
## five (the order `arena_catalog.gd::rows()` keeps).
func _card_ids() -> Array:
	var out: Array = []
	for row in _rows:
		out.append(String((row as Dictionary).get("id", "")))
	for row in _world_rows:
		out.append(String((row as Dictionary).get("id", "")))
	return out


func _is_a_card(arena_id: String) -> bool:
	return not _row_of(arena_id).is_empty() or not _world_row_of(arena_id).is_empty()


## The world half of the catalog this build offers (`UiData.world_arena_rows()` —
## `arena_catalog.gd::world_rows()`): the five in a full build, none in a demo, so a
## demo builds no world grid at all. The rows are the deck's own records — the same
## ones `Config.selectable_world_arenas()` hands the ported column — and the card
## shows them as data: a port addition has no locale key for its name or description.
func _world_rows_now() -> Array:
	var out: Array = []
	for row in UiData.world_arena_rows():
		var entry: Dictionary = (row as Dictionary).duplicate(true)
		entry["world"] = true
		var raw: Variant = entry.get("palette")
		var palette: Dictionary = raw if raw is Dictionary else {}
		entry["accent"] = String(palette.get("accent", ""))
		out.append(entry)
	return out


func _wording_now() -> String:
	var mode := String(Config.pending_mode)
	if mode == WORDING_CAREER or mode == WORDING_TOURNAMENT:
		return mode
	return WORDING_QUICK


## `selectableArenas()` (`js/ui.js:490-492`): the build's filter *and* the career's wall —
## `demoFilter(ARENAS, DEMO_CONTENT.arenas).filter((a) => isUnlocked(a, ui.career))`. The
## fixture must come from this pool, or the calendar would name an arena the career has
## not opened: `Config.selectable_arenas()` alone is only the build's half
## (`match_config.gd:64-66`).
func _career_selectable_arenas() -> Array:
	var out: Array = []
	for row in _rows:
		var entry: Dictionary = row
		if bool(entry.get("locked", false)) or _locked_ids.has(String(entry.get("id", ""))):
			continue
		for arena in Frozen.arenas():
			if String((arena as Dictionary).get("id", "")) == String(entry.get("id", "")):
				out.append(arena)
				break
	return out


## `const dettata = ui.selectedMode === "career" ? currentFixture().arena : …`
## (`js/ui.js:1231-1235`), read through the port's own rules.
func _fixture_arena_id() -> String:
	var available: Array = _career_selectable_arenas()
	if _wording == WORDING_CAREER:
		var career: Dictionary = ModesSave.load_career(Config.save_store())
		var fixture: Dictionary = CareerRules.career_fixture(
			int(career.get("season", 1)), int(career.get("matchIndex", 0)), available)
		var arena: Dictionary = fixture.get("arena", {}) if fixture.get("arena") is Dictionary else {}
		return String(arena.get("id", ""))
	if _wording == WORDING_TOURNAMENT:
		var round := ModesSave.tournament_round(Config.save_store())
		var fixture: Dictionary = CareerRules.tournament_fixture(round, available)
		var arena: Dictionary = fixture.get("arena", {}) if fixture.get("arena") is Dictionary else {}
		return String(arena.get("id", ""))
	return ""


## `renderArenas`'s three booleans per card (`js/ui.js:1238-1241`), with the build's wall
## the only thing a capture state may pin.
func _rows_now() -> Array:
	var out: Array = []
	for row in UiData.arena_rows(Config.save_store()):
		var entry: Dictionary = (row as Dictionary).duplicate(true)
		var id := String(entry.get("id", ""))
		var demo_locked := bool(entry.get("demo_locked", false))
		entry["demo_locked"] = demo_locked
		if _capture_lock_pin == "demo":
			demo_locked = not DemoContent.allowed_arena_ids().has(id)
			entry["demo_locked"] = demo_locked
		entry["locked"] = demo_locked or bool(entry.get("locked", false))
		entry["accent"] = _accent_of(id)
		out.append(entry)
	return out


## The arena a press would start on when the player has not chosen: the first one the
## build exposes (`Config.selectable_arenas()` order, `match_config.gd:64-66`).
func _first_selectable_id() -> String:
	for row in _rows:
		var entry: Dictionary = row
		if not bool(entry.get("locked", false)) and not _out_of_matchday.has(String(entry.get("id", ""))):
			return String(entry.get("id", ""))
	return ""


func arena_rows_now() -> Array:
	return _rows.duplicate(true)


## The world five this build draws cards for — the frozen grid's twin accessor. A
## demo answers `[]`: the set does not exist there.
func world_arena_rows_now() -> Array:
	return _world_rows.duplicate(true)


func wording_mode() -> String:
	return _wording


func fixture_arena_id() -> String:
	return _in_program


func in_program_id() -> String:
	return _in_program


func out_of_matchday_ids() -> Array:
	return _out_of_matchday.duplicate()


func locked_ids() -> Array:
	return _locked_ids.duplicate()


func selected_arena_id() -> String:
	return _selected_id


## Which of `renderArenas`'s four sentences the card's body carries.
func arena_card_state(arena_id: String) -> String:
	if _locked_ids.has(arena_id):
		return "locked"
	if _out_of_matchday.has(arena_id):
		return "out_of_matchday"
	if arena_id == _in_program:
		return "in_program"
	return "selectable"


func arena_locked_shown(arena_id: String) -> bool:
	var lock := _control(LOCK_PREFIX + arena_id) as Control
	return lock != null and lock.visible


func arena_badge_shown(arena_id: String) -> bool:
	var badge := _control(BADGE_PREFIX + arena_id) as Control
	return badge != null and badge.visible


func arena_line_key(arena_id: String) -> String:
	var row := _row_of(arena_id)
	var demo_locked := bool(row.get("demo_locked", false))
	var unlock: Dictionary = _arena_unlock_of(arena_id)
	if demo_locked:
		return "demoOnlyFull"
	if _locked_ids.has(arena_id):
		if int(unlock.get("trophies", 0)) > 0:
			return "unlockTrophies"
		if int(unlock.get("stars", 0)) > 0:
			return "unlockStars"
		return Gate.locked_key()
	if _out_of_matchday.has(arena_id):
		return "arenaOtherRound" if _wording == WORDING_TOURNAMENT else "arenaOtherMatchday"
	return String(row.get("desc_key", ""))


## `lockLabel(unlock)`'s own params (`js/ui.js:685-702`): the count, and the noun chosen
## by the reference's rule — `{n: 2, word: t("trophyMany")}` resolves to "🏆 2 trofei",
## never the raw "{n} {word}" template the locked cards showed (the 2026-09-18
## screenshot). The noun is resolved here, at binding time, the way the reference
## resolves it in the same expression; a key with no wall to count carries no params.
func _line_params_of(arena_id: String, line_key: String) -> Dictionary:
	var unlock := _arena_unlock_of(arena_id)
	var count := 0
	var word_key := ""
	if line_key == "unlockTrophies":
		count = int(unlock.get("trophies", 0))
		word_key = "trophyOne" if count == 1 else "trophyMany"
	elif line_key == "unlockStars":
		count = int(unlock.get("stars", 0))
		word_key = "starOne" if count == 1 else "starMany"
	if word_key == "":
		return {}
	return {"n": count, "word": UiStrings.t(word_key)}


# ---------------------------------------------------------------------------
# Selection and the preserved start contract


## `ui.selectedArena = arena; onSelect?.(arena)` (`js/ui.js:1264-1265`) — the choice is the
## session's, and the port's seat for it is `Config.arena_index` (`match_config.gd:22-27`).
## Select-only, by design: the audits and the career fixtures read the choice on its own,
## and the press's own path is `activate_arena` below.
func select_arena(arena_id: String) -> bool:
	if not _is_a_card(arena_id):
		return false
	var state := arena_card_state(arena_id)
	if state == "locked" or state == "out_of_matchday":
		return false
	_selected_id = arena_id
	_apply_selection_styles()
	return true


## The press's own path, UIR-12's rule: "Selecting an eligible arena starts the match".
## A walled card refuses (locked, or switched off by the calendar), an eligible one
## moves the session's choice and then runs `start_match` — which is what a click and,
## once the bridge can reach the screen, a keyboard confirm both mean. `apply_scene` is
## `start_match`'s own: false is how an audit starts without touching the tree.
func activate_arena(arena_id: String, apply_scene: bool = true) -> bool:
	if not _is_a_card(arena_id):
		return false
	var state := arena_card_state(arena_id)
	if state == "locked" or state == "out_of_matchday":
		return false
	if not select_arena(arena_id):
		return false
	return start_match(apply_scene)


## Which arena the start will use: the chosen one, or — in career and tournament — the
## calendar's, because `startMatch` uses the fixture and discards the choice
## (`js/ui.js:1227-1230`, `js/main.js`'s guards around `:1545-1583`).
func start_arena_id() -> String:
	if _wording == WORDING_CAREER or _wording == WORDING_TOURNAMENT:
		return _in_program
	return _selected_id


func can_start() -> bool:
	var id := start_arena_id()
	if id == "":
		return false
	var seat := _seat_of(id)
	if int(seat["index"]) >= 0:
		return true
	return bool(seat["world"]) and bool(seat["offered"])


## The payload the router (UIR-22) reads. Keys named and returned, never written into a
## mode rule: `mode` is `Config.pending_mode`'s own value, `arena_index` is
## `Config.arena_index`'s own seat, `scene` is the scene today's call sites change to.
## `index` is -1 and `world` is true for a world arena: its seat is the id itself, the
## same answer `Config.set_arena_id` lands on.
func start_payload() -> Dictionary:
	var id := start_arena_id()
	var mode := _wording
	var seat := _seat_of(id)
	return {
		"mode": mode,
		"arena_id": id,
		"arena_index": int(seat["index"]),
		"world": bool(seat["world"]),
		"player_mode": player_mode(),
		"scene": MODE_SCENE if mode != WORDING_QUICK else MATCH_SCENE,
	}


func start_match(apply_scene: bool = true) -> bool:
	if not can_start():
		return false
	var payload := start_payload()
	# One seat call for both kinds (`match_config.gd::set_arena_id`): a frozen arena
	# lands on its roster index and clears the world seat, a world arena takes the
	# world seat and leaves the frozen index where it was.
	if not Config.set_arena_id(String(payload["arena_id"])):
		return false
	Config.pending_mode = String(payload["mode"])
	# The reference's own rule (`js/main.js:1156`): the human mode rides only on a
	# quick match; tournament, career and drill are forced back to `"solo"`.
	Config.pending_player_mode = String(payload["player_mode"]) if String(payload["mode"]) == WORDING_QUICK else "solo"
	if apply_scene:
		get_tree().change_scene_to_file(String(payload["scene"]))
	return true


func player_mode() -> String:
	var prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	var mode := String(prefs.get("playerMode", PLAYER_MODES[0]))
	if not PLAYER_MODES.has(mode):
		return PLAYER_MODES[0]
	return mode


func player_mode_visible() -> bool:
	var panel := _control("PlayerModePanel") as Control
	return panel != null and panel.visible


func hint_key() -> String:
	return "pmHint"


func select_player_mode(mode: String) -> bool:
	if not PLAYER_MODES.has(mode):
		return false
	ModesSave.save_pref(Config.save_store(), "playerMode", mode)
	refresh_strings()
	refresh_selection()
	return true


## `.segmented button`'s three states, one box each (`styles.css:2220-2252`): the chip
## asleep is transparent with the reference's muted ink, the chip under the POINTER takes
## `background: rgba(0, 229, 255, 0.1); color: #cfe9f7` (`:2238-2241`), and the chosen one
## keeps the accent and its glow (`:2248-2252`). Handing `hover` the same box as `normal`
## — what this function used to do — made the lightest of the three invisible under the
## pointer, which is the defect this replaces.
func refresh_selection() -> void:
	var current := player_mode()
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key) as Button
		if button == null:
			continue
		var active := String(key) == current
		button.add_theme_stylebox_override("normal", _active_segment_box() if active else _inactive_segment_box())
		button.add_theme_stylebox_override("hover", _active_segment_box() if active else _segment_hover_box())
		button.add_theme_stylebox_override("pressed", _active_segment_box() if active else _segment_hover_box())
		if active:
			# `.segmented button.is-active` fixes the ink in every state (`:2248-2252`):
			# the reference's `:hover:not(.is-active)` rule cannot reach the chosen chip,
			# so no override of this button's own colour is left behind.
			button.remove_theme_color_override("font_hover_color")
			button.remove_theme_color_override("font_pressed_color")
		else:
			# `.segmented button { color: #809bb6 }` is the theme's own; only the ink
			# under the pointer moves (`:2231`, `:2240`).
			button.add_theme_color_override("font_hover_color", Color(SEGMENT_HOVER_INK))
			button.add_theme_color_override("font_pressed_color", Color(SEGMENT_HOVER_INK))


func player_mode_shown(mode: String) -> String:
	return UiStrings.t(MODE_KEYS.get(mode, ""))


# ---------------------------------------------------------------------------
# Capture states


func apply_capture_state(state: String) -> bool:
	if not CAPTURE_STATES.has(state):
		return false
	match state:
		"default":
			_capture_lock_pin = ""
			Config.pending_mode = _capture_entry_mode if _capture_entry_mode != "" else WORDING_QUICK
		"career-calendar":
			_capture_lock_pin = ""
			Config.pending_mode = WORDING_CAREER
		"tournament-bracket":
			_capture_lock_pin = ""
			Config.pending_mode = WORDING_TOURNAMENT
		"demo-locked":
			_capture_lock_pin = "demo"
		"player-mode-coop":
			_capture_lock_pin = ""
			Config.pending_mode = _capture_entry_mode if _capture_entry_mode != "" else WORDING_QUICK
	refresh_data()
	if state == "player-mode-coop":
		select_player_mode("coop")
	return true


# ---------------------------------------------------------------------------
# The grid


func _build_grid() -> void:
	var grid := _control("ArenaGrid") as GridContainer
	if grid == null:
		return
	# Every card node is replaced here, so a card the POINTER held is gone: the holder is
	# dropped with it rather than surviving into the new node under the same name.
	_hovered_card_id = ""
	_clear(grid)
	for row in _rows:
		var entry: Dictionary = row
		var id := String(entry.get("id", ""))
		var state := arena_card_state(id)
		var card := PanelContainer.new()
		card.name = CARD_PREFIX + id
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.theme_type_variation = &""
		# The reference paints exactly three card states — locked, out of the matchday, in
		# program (`js/ui.js:1238-1243`) — and no "chosen" one: the choice is the session's,
		# not the card's. The port draws the session's own choice on top of them
		# (`_card_box_of`), so the card the player picked is the one the selection frame
		# marks; without it a press read as a no-op (the 2026-09-18 screenshot).
		card.add_theme_stylebox_override("panel", _card_box_of(id))
		card.focus_entered.connect(_on_card_focus.bind(id, true))
		card.focus_exited.connect(_on_card_focus.bind(id, false))
		# The pad's ring (`styles.css:733-738`) rides the card as an overlay; see
		# `CardFocusRing.gd` for why it is not a theme variation.
		CardFocusRing.attach(card)
		# `.arena-card:hover` (`styles.css:335-340`): the pointer lightens the border and
		# rides the card 3 px up. Unlike `.mode-card:not(.mode-card--locked):hover`
		# (`:336`) the reference excludes nothing here, so a card out of the matchday
		# answers the pointer as well — it is the calendar's own sentence that says why
		# the card cannot be taken, not a dead frame.
		card.mouse_entered.connect(_on_card_pointer.bind(id, true))
		card.mouse_exited.connect(_on_card_pointer.bind(id, false))
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.name = card.name + "Column"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		card.add_child(column)

		# `.arena-card__preview` (`styles.css:508-522`): the art with the accent it carries.
		var preview := PanelContainer.new()
		preview.name = ART_PREFIX + id
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_theme_stylebox_override("panel", _preview_box(String(entry.get("accent", ""))))
		column.add_child(preview)
		var art := TextureRect.new()
		art.name = preview.name + "Texture"
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art_path := String(entry.get("art_path", ""))
		var texture: Texture2D = load(art_path) if art_path != "" else null
		if texture != null:
			art.texture = texture
		preview.add_child(art)
		_place_overlay(art, LOCK_PREFIX + id, LockBadge.new(), state == "locked")
		var badge := Label.new()
		_place_overlay(art, BADGE_PREFIX + id, badge, state == "in_program")
		_bind(badge, "arenaByBracket" if _wording == WORDING_TOURNAMENT else "arenaByCalendar")

		var body := MarginContainer.new()
		body.name = card.name + "Body"
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pad := int(CARD_PADDING)
		body.add_theme_constant_override("margin_left", pad)
		body.add_theme_constant_override("margin_right", pad)
		body.add_theme_constant_override("margin_top", pad)
		body.add_theme_constant_override("margin_bottom", pad)
		column.add_child(body)
		var stack := VBoxContainer.new()
		stack.name = card.name + "Stack"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 4)
		body.add_child(stack)

		var name_label := Label.new()
		name_label.name = NAME_PREFIX + id
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.theme_type_variation = &"CardTitle"
		stack.add_child(name_label)
		_bind(name_label, String(entry.get("name_key", "")))

		var line := Label.new()
		line.name = LINE_PREFIX + id
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.theme_type_variation = &"CardBody"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(line)
		var line_key := arena_line_key(id)
		_bind(line, line_key, _line_params_of(id, line_key))

		# A switched-off card is a card the reference hands to `card.disabled`
		# (`js/ui.js:1263-1271`), never a card that quietly does nothing.
		card.modulate = Color(1, 1, 1, 0.55) if state == "out_of_matchday" else Color(1, 1, 1, 1)
		if state != "out_of_matchday":
			card.gui_input.connect(_on_card_input.bind(id))


## The world five's own grid, in the frozen grid's own idiom: one card per arena the
## catalog offers, in table order, each card named and described by the row both UI
## paths read. A build that offers none builds no grid (a demo), and a build that
## lost them (a capture state, a failed read) hides the area instead of leaving an
## empty container in the scroll. The frozen grid's own children are never touched
## here, and the global binding lists are cleared once per refresh by `_build_grid`.
func _build_world_grid() -> void:
	var area := _control(WORLD_AREA)
	var grid := _control(WORLD_GRID) as GridContainer
	if _world_rows.is_empty():
		if grid != null:
			_clear_children(grid)
		if area != null:
			area.visible = false
		return
	if grid == null:
		grid = _make_world_grid()
	if grid == null:
		return
	if area != null:
		area.visible = true
	_clear_children(grid)
	for row in _world_rows:
		_build_world_card(grid, row)


## Builds the world area and its grid into the screen's own body, ABOVE the frozen
## grid: the scene carries the frozen grid alone, so the world half is inserted where
## the layout already put its sibling, with the same margins and separation. Above,
## not below — the five are the reason the screen exists for a player who wants one,
## and below nine 16:9 frozen cards they sat past the fold (the 2026-09-18 screenshot).
func _make_world_grid() -> GridContainer:
	var body := _control(BODY_NODE)
	if body == null:
		return null
	var area := MarginContainer.new()
	area.name = WORLD_AREA
	area.add_theme_constant_override("margin_left", 64)
	area.add_theme_constant_override("margin_right", 64)
	area.add_theme_constant_override("margin_top", 20)
	area.add_theme_constant_override("margin_bottom", 0)
	body.add_child(area)
	var grid := GridContainer.new()
	grid.name = WORLD_GRID
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.columns = _column_count()
	# The world grid's own relayouts matter to the lift exactly as the frozen grid's do
	# (`_refresh_lifts`).
	grid.resized.connect(_refresh_lifts)
	area.add_child(grid)
	var frozen_area := _control(GRID_AREA_NODE)
	if frozen_area != null:
		body.move_child(area, frozen_area.get_index())
	return grid


func _build_world_card(grid: GridContainer, row: Dictionary) -> void:
	var id := String(row.get("id", ""))
	var state := arena_card_state(id)
	var card := PanelContainer.new()
	card.name = WORLD_CARD_PREFIX + id
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.theme_type_variation = &""
	card.add_theme_stylebox_override("panel", _card_box_of(id))
	card.focus_entered.connect(_on_card_focus.bind(id, true))
	card.focus_exited.connect(_on_card_focus.bind(id, false))
	# The world cards wear the same pad ring as the frozen nine.
	CardFocusRing.attach(card)
	# The world cards answer the pointer exactly as the frozen nine do: one card, one
	# hover rule (`styles.css:335-340`).
	card.mouse_entered.connect(_on_card_pointer.bind(id, true))
	card.mouse_exited.connect(_on_card_pointer.bind(id, false))
	grid.add_child(card)
	var column := VBoxContainer.new()
	column.name = card.name + "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)

	# The frozen grid's own preview, in the frozen grid's own idiom: the accented panel
	# carries the deck still for this arena. The panel stays the fallback — a build that
	# has not imported the stills shows the accent, never a broken texture.
	var preview := PanelContainer.new()
	preview.name = WORLD_ART_PREFIX + id
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_stylebox_override("panel", _preview_box(String(row.get("accent", ""))))
	column.add_child(preview)
	var art := TextureRect.new()
	art.name = preview.name + "Texture"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_path := WORLD_ART_DIR + id + ".png"
	var texture: Texture2D = load(art_path) if ResourceLoader.exists(art_path) else null
	if texture != null:
		art.texture = texture
	preview.add_child(art)

	var body := MarginContainer.new()
	body.name = card.name + "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(CARD_PADDING)
	body.add_theme_constant_override("margin_left", pad)
	body.add_theme_constant_override("margin_right", pad)
	body.add_theme_constant_override("margin_top", pad)
	body.add_theme_constant_override("margin_bottom", pad)
	column.add_child(body)
	var stack := VBoxContainer.new()
	stack.name = card.name + "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	body.add_child(stack)

	var name_label := Label.new()
	name_label.name = WORLD_NAME_PREFIX + id
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.theme_type_variation = &"CardTitle"
	name_label.text = String(row.get("name", ""))
	_register_text_node(name_label)
	stack.add_child(name_label)

	var line := Label.new()
	line.name = WORLD_LINE_PREFIX + id
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.theme_type_variation = &"CardBody"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_register_text_node(line)
	stack.add_child(line)
	if state == "out_of_matchday":
		_bind(line, "arenaOtherRound" if _wording == WORDING_TOURNAMENT else "arenaOtherMatchday")
	else:
		# The deck's own description, the string `main_menu.gd`'s world tooltip
		# carries too: a port addition has no locale key to resolve.
		line.text = String(row.get("desc", ""))

	card.modulate = Color(1, 1, 1, 0.55) if state == "out_of_matchday" else Color(1, 1, 1, 1)
	if state != "out_of_matchday":
		card.gui_input.connect(_on_card_input.bind(id))


## Removes a container's children WITHOUT the global binding reset `_clear` does: the
## frozen grid's bindings are registered for the whole screen (`text_bindings`), and
## the world grid must not wipe them.
func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_card_input(event: InputEvent, arena_id: String) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		# A press on an eligible card STARTS (`activate_arena`); a walled card's
		# press refuses inside the same call, so the handler needs no second rule.
		activate_arena(arena_id)


## `PanelContainer` cards do not paint a native focus state. Keep the focused
## card separate from `_selected_id`: moving with a controller previews the
## cyan selection frame, while only a confirm persists and starts that arena.
func _on_card_focus(arena_id: String, entered: bool) -> void:
	if entered:
		_focused_card_id = arena_id
	elif _focused_card_id == arena_id:
		_focused_card_id = ""
	_apply_selection_styles()


# ---------------------------------------------------------------------------
# The card's own motion (`styles.css:332`, `:335-340`)
#
# A card is a child of a `GridContainer`, and a container owns its children's positions:
# the reference's `transform: translateY(-3px)` has no equivalent that survives a
# relayout on its own. So the Y the layout gives a card at rest is CAPTURED and re-read
# whenever the grid re-lays the card out (`_refresh_lifts`, wired to the screen's and the
# grid's own `resized`), and every move starts from that rest Y — offsets are never
# accumulated on top of each other.
# ---------------------------------------------------------------------------


## The pointer is the second holder of the lit state (see `_hovered_card_id`): both it
## and the pad go through `_apply_selection_styles`, so the frame and the lift resolve in
## one place and the two can never disagree.
func _on_card_pointer(arena_id: String, entered: bool) -> void:
	if entered:
		_hovered_card_id = arena_id
	elif _hovered_card_id == arena_id:
		_hovered_card_id = ""
	_apply_selection_styles()


func _card_lifted(arena_id: String) -> bool:
	return arena_id == _hovered_card_id or arena_id == _focused_card_id


## The card's own record: the Y the layout gives it at rest, how far it currently sits
## from that Y, and the tween carrying it. Kept on the node itself, so a card the grid
## rebuilds takes its stale record with it.
func _lift_state(card: Control) -> Dictionary:
	if not card.has_meta(LIFT_META):
		card.set_meta(LIFT_META, {"base_y": INF, "applied": 0.0, "tween": null})
	return card.get_meta(LIFT_META)


## The Y the grid gives this card at rest. A `GridContainer` writes its children's
## positions when it sorts, so a position that is not where this screen last put the card
## IS the container's own answer: the base follows it there and the offset in flight is
## dropped rather than added to it. Otherwise the base is recovered from the offset, which
## holds even for a card caught half way through its own tween.
func _rest_y_of(card: Control) -> float:
	var state := _lift_state(card)
	var base := float(state["base_y"])
	var applied := float(state["applied"])
	if not is_finite(base) or absf(card.position.y - (base + applied)) > LIFT_EPSILON:
		base = card.position.y
		state["applied"] = 0.0
	state["base_y"] = base
	return base


## Moves a card `offset` px off its rest Y over the reference's own 0.15 s, replacing any
## tween still in flight: a pointer crossing four cards quickly used to leave each one
## wherever its own tween happened to be. Driven by `tween_method` rather than
## `tween_property` so the record above is written by the same hand that moves the card.
func _lift_to(card: Control, offset: float) -> void:
	var state := _lift_state(card)
	var base := _rest_y_of(card)
	var target := base + offset
	_kill_lift(state)
	if is_zero_approx(card.position.y - target):
		_lift_step(target, card)
		return
	var tween: Tween = card.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_lift_step.bind(card), card.position.y, target, LIFT_SECONDS)
	state["tween"] = tween


func _lift_step(y: float, card: Control) -> void:
	var state := _lift_state(card)
	card.position.y = y
	state["applied"] = y - float(state["base_y"])


func _kill_lift(state: Dictionary) -> void:
	var tween: Tween = state.get("tween", null)
	state["tween"] = null
	if tween != null and tween.is_valid():
		tween.kill()


## Schedules the re-capture a relayout needs. A container sorts its children DEFERRED and
## queues that sort from the very notification that resized it, so a capture taken in this
## frame would read the row the cards are LEAVING: the re-capture waits one frame, by
## which time every sort this resize queued has run. One capture is queued at a time — a
## resize arrives as several `resized` signals through the frame's containers.
func _refresh_lifts() -> void:
	if _lift_refresh_queued:
		return
	_lift_refresh_queued = true
	_after_sort.call_deferred()


func _after_sort() -> void:
	if not is_inside_tree():
		_lift_refresh_queued = false
		return
	await get_tree().process_frame
	_lift_refresh_queued = false
	if not is_inside_tree():
		return
	_recapture_lifts()


## Re-reads every card's rest Y and re-applies the offset it owes, without animation:
## after a relayout the grid's own positions are the truth, and a tween started under the
## old layout would land on a Y nothing stands on any more.
func _recapture_lifts() -> void:
	if not is_inside_tree():
		return
	for row in _rows:
		_recapture_card_lift(String((row as Dictionary).get("id", "")), CARD_PREFIX)
	for row in _world_rows:
		_recapture_card_lift(String((row as Dictionary).get("id", "")), WORLD_CARD_PREFIX)


func _recapture_card_lift(arena_id: String, prefix: String) -> void:
	var card := _control(prefix + arena_id)
	if card == null:
		return
	var state := _lift_state(card)
	var base := _rest_y_of(card)
	_kill_lift(state)
	state["base_y"] = base
	state["applied"] = -CARD_LIFT if _card_lifted(arena_id) else 0.0
	card.position.y = base + float(state["applied"])


func _place_overlay(host: Control, overlay_name: String, overlay: Control, visible_now: bool) -> void:
	overlay.name = overlay_name
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = visible_now
	if overlay is Label:
		(overlay as Label).theme_type_variation = &"Tag"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)


## `.arena-card__preview`'s height: the art keeps its own ratio, floored so a narrow
## column cannot collapse it.
func _update_preview_heights() -> void:
	var grid := _control("ArenaGrid") as GridContainer
	if grid == null:
		return
	var columns := _column_count()
	var width := grid.size.x
	if width <= 0.0:
		return
	# The column the viewport rules give this card, floored so a narrow column cannot
	# collapse the preview.
	var column_width := (width - float(columns - 1) * float(_grid_separation())) / float(columns)
	for row in _rows:
		_fit_preview(ART_PREFIX, CARD_PREFIX, String((row as Dictionary).get("id", "")), column_width)
	# The world cards' previews keep the same ratio: same card, same art frame, same
	# deck still behind it.
	for row in _world_rows:
		_fit_preview(WORLD_ART_PREFIX, WORLD_CARD_PREFIX,
			String((row as Dictionary).get("id", "")), column_width)


func _fit_preview(art_prefix: String, card_prefix: String, id: String, column_width: float) -> void:
	var preview := _control(art_prefix + id) as Control
	if preview == null:
		return
	var card := _control(card_prefix + id) as Control
	var basis := card.size.x if card != null and card.size.x > 1.0 else column_width
	preview.custom_minimum_size.y = maxf(PREVIEW_MIN_HEIGHT, basis / PREVIEW_RATIO)


# ---------------------------------------------------------------------------
# The player-mode panel


func _build_player_mode() -> void:
	var panel := _control("PlayerModePanel") as Control
	if panel == null:
		return
	# `js/main.js:1656`: `playerModeSetup.hidden = ui.selectedMode !== "quick"` — the panel
	# is the quick match's, and it is the same rule the modes screen's setup obeys.
	panel.visible = _wording == WORDING_QUICK
	var label := _control("PlayerModeLabel") as Label
	if label != null:
		_bind(label, "playerMode")
	var hint := _control("PlayerModeHint") as Label
	if hint != null:
		_bind(hint, hint_key())
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key) as Button
		if button != null:
			_bind(button, String(MODE_KEYS[key]))
	refresh_selection()


# ---------------------------------------------------------------------------
# Chrome (theme tokens only)


func _style_chrome() -> void:
	var panel := _control("PlayerModePanel") as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", _setup_box())


func _theme_box(variation: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	if theme == null:
		return StyleBoxFlat.new()
	var box: StyleBox = theme.get_stylebox("panel", variation)
	if box == null:
		push_error("ArenaScreen: the theme has no '%s' box" % variation)
		return StyleBoxFlat.new()
	var out := (box as StyleBoxFlat).duplicate()
	# The preview bleeds to the card's edges (`styles.css:508-522`): the frame gives up
	# its padding and the body below carries it.
	out.content_margin_left = 0.0
	out.content_margin_top = 0.0
	out.content_margin_right = 0.0
	out.content_margin_bottom = 0.0
	return out


func _card_box() -> StyleBoxFlat:
	return _theme_box("PanelDark")


## The frame the card wears, in the reference's own order: the calendar's fixture and the
## session's pick wear the halo (`styles.css:3126-3128`), the card the pointer or the pad
## holds wears the cyan frame alone — `styles.css:335-340` is the reference's whole hover
## state, and the port's focus rule (`game/menu_focus.gd:73`) paints the same card, so one
## held state serves both. Without a frame at all a press left the grid looking untouched
## (the 2026-09-18 screenshot).
func _card_box_of(arena_id: String) -> StyleBoxFlat:
	if arena_id == _in_program or arena_id == _selected_id:
		return _selected_box()
	if _card_lifted(arena_id):
		return _focus_box()
	return _card_box()


## `.arena-card--in-programma` (`styles.css:3126-3128`) / `.athlete-card--selected`
## (`:342-345`): the cyan border AND the halo.
func _selected_box() -> StyleBoxFlat:
	var box := _theme_box("PanelCardSelected")
	_add_halo(box)
	return box


## The same frame without the glow: the card under the pointer or the pad, one state
## below the session's own choice. The reference lightens the hovered border
## (`styles.css:335-340`) where the port's own focus rule has always painted the cyan
## frame, and `controller_cards_test` pins that frame's border and fill on the focused
## card — so the two held states share one box and only the halo is reserved for the
## chosen card.
func _focus_box() -> StyleBoxFlat:
	var box := _theme_box("PanelCardSelected")
	box.shadow_size = 0
	return box


## The halo the chosen card wears: `0 0 0 1px var(--cyan)` (the box's own cyan border)
## plus `0 12px 40px rgba(0, 229, 255, 0.18)` (the shadow, `styles.css:342-345`,
## `:3126-3128`).
func _add_halo(box: StyleBoxFlat) -> void:
	var theme_now: Theme = self.theme
	if theme_now == null or not theme_now.has_color("cyan", "Palette"):
		return
	box.shadow_color = Color(theme_now.get_color("cyan", "Palette"), HALO_ALPHA)
	box.shadow_size = int(HALO_SIZE)
	box.shadow_offset = Vector2(0.0, 4.0)


func _apply_selection_styles() -> void:
	for arena_id in _card_ids():
		var id := String(arena_id)
		var card := _control(CARD_PREFIX + id)
		if card == null:
			card = _control(WORLD_CARD_PREFIX + id)
		if card == null:
			continue
		card.add_theme_stylebox_override("panel", _card_box_of(id))
		# The frame and the lift are one state: a card the pointer or the pad holds
		# moves as well as lights up (`styles.css:332`, `:335-340`), whichever frame it
		# happens to be wearing.
		_lift_to(card, -CARD_LIFT if _card_lifted(id) else 0.0)
		# The PAD's own presentation, on top of the frame above: `.menu-focus`'s 3 px cyan
		# ring 3 px outside the card (`styles.css:733-738`). The reference keeps it a
		# separate rule from `:hover` and hands it to the pointer only when a pad is
		# connected (`js/main.js:2579-2588`); the port draws it for the pad alone, so the
		# card the controller holds never reads as a card the mouse happens to be over.
		CardFocusRing.set_focused(card, id == _focused_card_id, _motion)


## The motion policy the ring asks before it pulses: `UiMotionPolicy` over the saved
## prefs, the same store `SettingsScreen._stored_prefs` reads. Hydrated on
## `refresh_data()` (the screen's own re-entry point), so a toggle in the settings screen
## is live the next time this screen is entered.
func _hydrate_motion() -> void:
	if _motion == null:
		_motion = UiMotionPolicy.new()
	_motion.apply_prefs(ModesSave.profile(Config.save_store()).get("prefs", {}))


## Bound after `_build_grid` because `_clear(ArenaGrid)` wipes `_bindings`.
func _bind_header() -> void:
	var title := _control("TitleLabel")
	if title != null:
		_bind(title, "arenaTitle")
	var sub := _control("SubLabel")
	if sub != null:
		_bind(sub, "arenaSub")
	var back := _control("BackButton")
	if back != null:
		_bind(back, "back")


func _setup_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	if theme == null:
		return StyleBoxFlat.new()
	var box := _theme_box("PanelDark")
	if theme.has_color("line", "Palette"):
		box.border_color = theme.get_color("line", "Palette")
	return box


func _preview_box(accent_hex: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	if theme != null and theme.has_color("panel", "Palette"):
		box.bg_color = theme.get_color("panel", "Palette")
	box.set_corner_radius_all(12)
	if accent_hex != "":
		var accent := Color.from_string(accent_hex, Color.WHITE)
		box.border_color = Color(accent.r, accent.g, accent.b, 0.55)
		box.border_width_bottom = 2
	return box


func _active_segment_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	# A `StyleBoxFlat` starts at `bg_color = Color(0.6, 0.6, 0.6)` with `draw_center` on,
	# so a segment that only wants a bottom border must clear the fill or it paints an
	# opaque grey slab (`styles.css` .segmented button: background none).
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	if theme != null and theme.has_color("cyan", "Palette"):
		box.border_color = theme.get_color("cyan", "Palette")
	box.set_corner_radius_all(8)
	box.border_width_bottom = 2
	# `.segmented button.is-active { box-shadow: 0 0 16px rgba(22, 190, 215, 0.42) ... }`
	# (`styles.css:2248-2252`): the chosen chip is the only lit one, and the tween-less
	# `StyleBoxFlat` is where a shadow belongs. The box draws no fill, so the shadow
	# reads as the glow the reference draws around it.
	box.shadow_color = SEGMENT_GLOW_COLOR
	box.shadow_size = int(SEGMENT_GLOW_SIZE)
	return box


func _inactive_segment_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	if theme != null and theme.has_color("line", "Palette"):
		box.border_color = theme.get_color("line", "Palette")
	box.set_corner_radius_all(8)
	box.border_width_bottom = 1
	return box


## `.segmented button:hover:not(.is-active) { background: rgba(0, 229, 255, 0.1) }`
## (`styles.css:2238-2241`) over the reference's `.segmented button { transition:
## background 0.18s ease, color 0.18s ease, transform 0.18s ease }` (`:2235`): the chip
## under the pointer is a FILL over the idle border, not the idle box again — the pair the
## theme already carries as `BoxSegmentedIdleHover` (`padel_theme.tres:166-175`). The ink
## that goes with it is `#cfe9f7` and is set by `refresh_selection`, next to the state it
## belongs to.
func _segment_hover_box() -> StyleBoxFlat:
	var theme: Theme = self.theme
	var box := _inactive_segment_box()
	if theme != null and theme.has_color("cyan", "Palette"):
		box.bg_color = Color(theme.get_color("cyan", "Palette"), SEGMENT_HOVER_ALPHA)
	return box


## `lockLabel(arena.unlock)`'s own field (`js/ui.js:414-417`): the frozen table carries no
## `unlock` on any arena today, so this reads it rather than assuming its absence.
func _arena_unlock_of(arena_id: String) -> Dictionary:
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		if String(entry.get("id", "")) == arena_id and entry.get("unlock") is Dictionary:
			return entry["unlock"]
	return {}


func _accent_of(arena_id: String) -> String:
	for arena in Frozen.arenas():
		var entry: Dictionary = arena
		if String(entry.get("id", "")) == arena_id:
			var palette: Dictionary = entry.get("palette", {}) if entry.get("palette") is Dictionary else {}
			return String(palette.get("accent", ""))
	return ""


# ---------------------------------------------------------------------------
# Layout


func _column_count() -> int:
	return GRID_COLUMNS if size.x >= GRID_BREAKPOINT else SMALL_COLUMNS


func _grid_separation() -> int:
	var grid := _control("ArenaGrid") as GridContainer
	return grid.get_theme_constant("h_separation") if grid != null else 20


func _apply_layout() -> void:
	var grid := _control("ArenaGrid") as GridContainer
	if grid != null:
		grid.columns = _column_count()
	var world := _control(WORLD_GRID) as GridContainer
	if world != null:
		world.columns = _column_count()
	# A relayout moves every card: the rest Y captured for the lift (`_lift_to`) is
	# re-read once the containers have sorted (`_refresh_lifts`).
	_refresh_lifts()
	_update_preview_heights()


# ---------------------------------------------------------------------------
# Strings


func refresh_strings() -> void:
	for row in _bindings:
		var entry: Dictionary = row
		var node: Control = _text_nodes.get(String(entry.get("name", "")), null)
		if node == null:
			continue
		_set_node_text(node, _resolve_entry(entry))
	_apply_accessibility()


func _resolve_entry(entry: Dictionary) -> String:
	var text := String(entry.get("prefix", "")) + UiStrings.t(String(entry.get("key", "")), entry.get("params", {}))
	if String(entry.get("suffix_key", "")) != "":
		text += String(entry.get("joiner", "")) + UiStrings.t(String(entry["suffix_key"]), entry.get("suffix_params", {}))
	return text


func _set_node_text(node: Control, text: String) -> void:
	if node is Label:
		(node as Label).text = text
	elif node is Button:
		(node as Button).text = text


func _bind(control: Control, key: String, params: Dictionary = {}, joiner: String = "",
		suffix_key: String = "", suffix_params: Dictionary = {}, prefix: String = "") -> void:
	_register_text_node(control)
	_bindings.append({
		"name": control.name,
		"key": key,
		"params": params,
		"prefix": prefix,
		"joiner": joiner,
		"suffix_key": suffix_key,
		"suffix_params": suffix_params,
	})
	_set_node_text(control, _resolve_entry(_bindings[_bindings.size() - 1]))


func _register_text_node(control: Control) -> void:
	_text_nodes[control.name] = control


func text_bindings() -> Array:
	return _bindings.duplicate(true)


func text_shown(node_name: String) -> String:
	var node: Control = _text_nodes.get(node_name, null)
	if node == null:
		return ""
	if node is Label:
		return (node as Label).text
	if node is Button:
		return (node as Button).text
	return ""


# ---------------------------------------------------------------------------
# Focus and accessibility


func focus_controls() -> Array:
	return _focus_specs.duplicate(true)


func _apply_accessibility() -> void:
	_focus_specs = []
	var back := _control("BackButton")
	if back != null:
		_focus_specs.append(_focus_spec("BackButton", back, "back"))
	for row in _rows:
		var arena_id := String((row as Dictionary).get("id", ""))
		var card := _control(CARD_PREFIX + arena_id)
		if card != null:
			_focus_specs.append(_focus_spec(CARD_PREFIX + String((row as Dictionary).get("id", "")), card,
				"activate:" + CARD_PREFIX + arena_id, _arena_focus_opts(arena_id)))
	# The world cards are reachable the same way: the ported column registers its
	# world row in the focus model too (`main_menu.gd`), so a keyboard or pad can
	# select a world arena on either path.
	for row in _world_rows:
		var world_id := String((row as Dictionary).get("id", ""))
		var world_card := _control(WORLD_CARD_PREFIX + world_id)
		if world_card != null:
			_focus_specs.append(_focus_spec(WORLD_CARD_PREFIX + world_id, world_card,
				"activate:" + WORLD_CARD_PREFIX + world_id, _arena_focus_opts(world_id)))
	for key in MODE_KEYS:
		var button := _control(MODE_PREFIX + key)
		if button != null:
			_focus_specs.append(_focus_spec(MODE_PREFIX + key, button, "player-mode:" + key))


## UIR-05's bridge reads these shapes: the id it can focus, the node it moves the focus to,
## the reference's own action name, and the model's options (`game/menu_focus.gd:60-77`).
func _focus_spec(node_name: String, control: Control, action: String, extra_opts: Dictionary = {}) -> Dictionary:
	var opts := {"kind": "card" if control is PanelContainer else "button"}
	opts.merge(extra_opts)
	return {
		"id": "%s/%s" % [SCREEN_ID, node_name],
		"node": control,
		"action": action,
		"opts": opts,
	}


## The reference leaves unavailable arena cards on screen but they cannot be
## activated. Treat them as disabled focus targets too, so the stick never lands
## on a card where A would knowingly do nothing.
func _arena_focus_opts(arena_id: String) -> Dictionary:
	var state := arena_card_state(arena_id)
	return {"disabled": state == "locked" or state == "out_of_matchday"}


## This screen's activation door for UIR-05's bridge — the same contract
## `ModesScreen.activate()` documents: an action the bridge does not route (it is not a
## `to-*` edge) is reported to the mount, which hands it back here. Both branches run
## the handler the mouse path runs (`_on_card_input` calls `activate_arena`, `_wire`
## calls `select_player_mode`), so a pad confirm and a click mean the same thing.
func activate(action: String) -> bool:
	var parts := action.split(":")
	if parts.size() != 2:
		return false
	match String(parts[0]):
		"activate":
			var arena_id := String(parts[1]).trim_prefix(CARD_PREFIX).trim_prefix(WORLD_CARD_PREFIX)
			return activate_arena(arena_id)
		"player-mode":
			return select_player_mode(String(parts[1]))
	return false


func aria_names() -> Dictionary:
	var out := {}
	var back := _control("BackButton") as Button
	if back != null:
		out["BackButton"] = back.text
	return out


# ---------------------------------------------------------------------------
# Small helpers


func _control(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control


func _row_of(arena_id: String) -> Dictionary:
	for row in _rows:
		if String((row as Dictionary).get("id", "")) == arena_id:
			return row
	return {}


func _world_row_of(arena_id: String) -> Dictionary:
	for row in _world_rows:
		if String((row as Dictionary).get("id", "")) == arena_id:
			return row
	return {}


## The seat an arena id takes, from the one catalog both paths read
## (`content_gate.gd::arena_catalog()`, `match_config.gd`'s own seat rule):
## `{index, world, offered}`.
func _seat_of(arena_id: String) -> Dictionary:
	var catalog: Variant = Gate.arena_catalog()
	return catalog.seat(arena_id)


func _clear(container: Node) -> void:
	_bindings.clear()
	_text_nodes.clear()
	_focus_specs.clear()
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## The lock badge is the reference's own `🔒` (`js/ui.js:1249`), from its code point.
class LockBadge:
	extends Label

	func _init() -> void:
		text = String.chr(0x1f512)
		horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vertical_alignment = VERTICAL_ALIGNMENT_TOP
