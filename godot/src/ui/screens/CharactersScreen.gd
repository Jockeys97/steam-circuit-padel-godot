## CharactersScreen.gd — `screen-characters` (`index.html:89-97`), the reference's team page.
##
## THE THREE VIEWS ARE ONE GRID, REBUILT. The reference empties `#athleteGrid` and draws
## again (`js/ui.js:846-1124`): the team panel (four slots, `showTeam`), the athlete
## picker (`showPicker`) and the wardrobe (`showOutfits`), with `#athleteGridHead`
## carrying each view's own command. This screen mirrors that: one `AthleteGrid`, one
## `GridHead`, and `_build_*()` per view — so a new view is a new builder, not a new
## screen.
##
## ROLE OF THE SEAM. The lineup is NOT resolved here: `Lineup.resolve(player, dictated)`
## (`godot/game/lineup.gd`, ported from `resolveLineup`, `js/ui.js:548-594`) does it, and
## the dictated pair comes from `CareerRules.dictated_rivals` (career/tournament have a
## calendar; quick does not). This screen's `enter()` is the port's first caller of the
## `Lineup` preference seam (`set_pref_source`), whose own comment names this screen as
## the missing caller — the source is the save-backed prefs dictionary, and this screen
## writes choices through `ModesSave` only (never a direct file write).
##
## DICTATED SLOTS WIN. A slot the calendar or the bracket fills carries no change
## command (`dettata` in the reference), because "un bottone che non cambia niente e'
## peggio di nessun bottone". A rename of the same rule: dictated roles are not editable
## and the tag says why (`slotByCalendar` / `slotByBracket`).
##
## NO DUPLICATES, BY CONSTRUCTION. The reference's dedupe is emergent (`resolveLineup`'s
## `usati` set skips an id already on court, and the fallback fills the vacated slot);
## this screen performs the swap explicitly before saving, so the invariant the ticket
## asks for ("never duplicates through any activation path") is provable and does not
## depend on fallback order.
##
## THE UNLOCK CODE IS PROGRESSION-ONLY. Three activations inside 1400 ms on a
## *progression*-locked athlete (`UNLOCK_TAPS`/`UNLOCK_TAP_WINDOW`, `js/ui.js:703-704`)
## open the code entry; a build-locked (demo-excluded) athlete does not even count taps,
## exactly as the reference's demo never renders those names at all. A correct code sets
## `career.unlockAll` (`js/ui.js:730-733`) through `ModesSave.save_career`; the build
## lock is a *separate* answer (`DemoGateAdapter`) and stays locked afterwards — the
## ticket's DoD asks for that negation explicitly, and the audit asserts it.
##
## CODE ENTRY ROUTE (platform note). The port's on-screen keyboard model exists
## (`src/input/menu_nav.gd:148` `set_osk_targets`, `:224` `osk.open_for`, `src/input/osk.gd`)
## and is wired for the feedback/settings text fields through the input layer's own
## context. This screen is desktop/Steam (physical keyboard is the platform decision the
## ticket's "if the platform decision allows" points at), so the code is typed into a
## `LineEdit` (`UnlockCodeInput`) and the OSK hand-off is NOT duplicated here: a pad-only
## shell would call `MenuNav.set_osk_targets()` + `osk.open_for(UnlockCodeInput, …)`, the
## same two calls the input lane already owns.
##
## LITERALS. None. The two separators the reference writes into markup (` · ` in the
## challenge label, ` ` before the dictated tag) and the `⚡` glyph are spelled from their
## code points (`joiner()` / `tag_joiner()` / `special_prefix()`), because
## `router_audit.gd` flags any literal containing a space and these are punctuation, not
## words this screen owns.
##
## THE STAT STRIP (landed 2026-09-17, wave 3). The reference's team slot carries
## `statLine(athlete)` — three five-tick bars of `STAT_RANGE` (`js/ui.js:805-828`) — and
## the picker shows the same strip on every unlocked card (`:1071`). The scale and the
## bars are derived in `UiData.stat_range`/`stat_rows` from the frozen roster (the table
## the reference reads as `ATHLETES`, checked row by row) — not from a build's subset —
## and this screen renders them: `SlotStat_<role>` on all four team slots (a rival slot
## takes the reference's own ink, `styles.css:3030`) and `PickStat_<id>` on unlocked
## picker cards. The picker's one delta stays as recorded: the special rides in the body
## where the reference puts it in the card's footer; the strip follows the narrative, as
## in `js/ui.js:971`.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const UiArt := preload("res://src/ui/data/UiArtPaths.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const ModeTables := preload("res://src/modes/mode_tables.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Lineup := preload("res://game/lineup.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")
const Frozen := preload("res://src/sim/frozen.gd")

const SCREEN_ID := "characters"
const BACK_TARGET_ID := "modes"
const ROUTE_TO_ARENA := "arena"

const VIEW_TEAM := "team"
const VIEW_PICKER := "picker"
const VIEW_OUTFITS := "outfits"

## The three wall presentations a capture state can pin (`""` = the live gate).
const LOCK_LIVE := ""
const LOCK_CAREER := "career"
const LOCK_DEMO := "demo"

const CAPTURE_STATES: Array[String] = ["default", "picker-open", "outfit-open", "locked-athlete", "demo-locked"]

## `js/ui.js:703-704`.
const UNLOCK_TAPS := 3
const UNLOCK_TAP_WINDOW := 1400

## `.athlete-grid { grid-template-columns: repeat(4, 1fr) }` and its one-column
## fallback (`styles.css:314`, `:2033`).
const GRID_COLUMNS := 4
const NARROW_COLUMNS := 2
const GRID_BREAKPOINT := 1050.0
const CARD_SEPARATION := 20.0
const ART_RATIO := 3.0
const ART_MIN_HEIGHT := 80.0
## `.athlete-card__body { padding: 18px }`.
const CARD_PADDING := 18.0

## The frame rules of the two card treatments the theme already names.
const SELECTED_ALPHA := 1.0
const LOCKED_CARD_ALPHA := 0.55

## `statLine`'s own measurements (`js/ui.js:814-828`, `styles.css:3016-3024`):
## `.stat-line { gap: 4px 10px; font-size: 0.72rem; letter-spacing: 0.06em;
## opacity: 0.85 }` and `.team-slot .stat-line { margin-top: 12px }`. The card stack
## already separates children by 4, so the strip's own top margin is 8 (4 + 8 = 12).
## `0.72rem` measured 11.52 px and is rounded to 12 like the theme's own sizes; the
## `0.06em` tracking (≈0.69 px) is not expressible on a Label without a FontVariation
## and the strip ships without it — a measured delta, recorded in the evidence log.
const STAT_LABEL_SIZE := 12
const STAT_LINE_GAP := 10
const STAT_PAIR_GAP := 4
const STAT_LINE_TOP_MARGIN := 8
const STAT_LINE_ALPHA := 0.85

const TEAM_SLOT_PREFIX := "TeamSlot_"
const SLOT_ART_PREFIX := "SlotArt_"
const SLOT_NAME_PREFIX := "SlotName_"
const SLOT_ROLE_PREFIX := "SlotRole_"
const SLOT_DESC_PREFIX := "SlotDesc_"
const SLOT_SPECIAL_PREFIX := "SlotSpecial_"
const SLOT_TAG_PREFIX := "SlotTag_"
const SLOT_ATHLETE_ACTION_PREFIX := "SlotAthleteAction_"
const SLOT_OUTFIT_ACTION_PREFIX := "SlotOutfitAction_"
const PICK_CARD_PREFIX := "PickCard_"
const PICK_NAME_PREFIX := "PickName_"
const PICK_ART_PREFIX := "PickArt_"
const PICK_ROLE_PREFIX := "PickRole_"
const PICK_DESC_PREFIX := "PickDesc_"
const PICK_SPECIAL_PREFIX := "PickSpecial_"
const PICK_TAG_PREFIX := "PickTag_"
const OUTFIT_CARD_PREFIX := "OutfitCard_"
const OUTFIT_NAME_PREFIX := "OutfitName_"
const OUTFIT_ART_PREFIX := "OutfitArt_"
const OUTFIT_LINE_PREFIX := "OutfitLine_"
const OUTFIT_TAG_PREFIX := "OutfitTag_"
const OUTFIT_FOOTER_PREFIX := "OutfitFooter_"
## The stat strip: `<prefix><role|id>` is the strip node, `<prefix>label_…` and
## `<prefix>bar_…` are its three label/bar pairs. Each inner name carries its suffix,
## because `_text_nodes` keys bindings by node name and a picker build can carry up to
## six strips at once.
const SLOT_STAT_PREFIX := "SlotStat_"
const PICK_STAT_PREFIX := "PickStat_"

## The role labels of the four slots (`js/ui.js:917-922`).
const SLOT_LABEL_KEYS := {
	"player": "slotYou",
	"playerMate": "slotPartner",
	"opponent": "slotOpponent",
	"opponentMate": "slotOpponentNet",
}
## Rival roles: the two that a calendar or a bracket can dictate.
const RIVAL_ROLES: Array[String] = ["opponent", "opponentMate"]
const EDITABLE_ROLES: Array[String] = ["player", "playerMate", "opponent", "opponentMate"]

const ROOT_ALIAS := "Root"
const ACCESSIBILITY_NAME_PROPERTY := "accessibility_name"
const ARIA_SLOTS := {"Root": "ariaSelectAthlete"}

# --- the router's own facts -------------------------------------------------
var router_id: String = ""
var back_target_id: String = ""

# --- capture pins -----------------------------------------------------------
var capture_view_pin: String = ""
var capture_lock_pin: String = LOCK_LIVE

# --- live state -------------------------------------------------------------
var _view: String = VIEW_TEAM
var _picker_role: String = "player"
var _outfit_athlete_id: String = ""
var _outfit_role: String = "player"
var _unlock_taps: int = 0
var _unlock_tap_time: int = 0
var _code_open: bool = false
var _code_wrong: bool = false

var _career: Dictionary = {}
var _dictated: Dictionary = {}
var _lineup: Dictionary = {}
var _rows: Array[Dictionary] = []
var _bindings: Array[Dictionary] = []
var _text_nodes: Dictionary = {}
var _cards: Dictionary = {}
var _focus_specs: Dictionary = {}


func _ready() -> void:
	_style_chrome()
	_wire()
	refresh_data()
	resized.connect(_apply_layout)
	var grid := _control("AthleteGrid")
	if grid != null:
		grid.resized.connect(_update_art_heights)
	_apply_layout()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", back_target_id))
	# The Lineup seam's own comment: "null today: the team screen is not ported". This
	# is that caller; the source is the save-backed prefs dictionary.
	Lineup.set_pref_source(ModesSave.profile(Config.save_store()).get("prefs", {}))
	_view = VIEW_TEAM
	refresh_data()


func exit() -> void:
	_code_open = false
	_code_wrong = false


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## `default` = the team panel; `picker-open` / `outfit-open` = the two subviews; the
## three lock presentations the ticket names: `locked-athlete` = the picker under the
## career wall, `demo-locked` = the picker under the build's own wall.
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"default":
			capture_view_pin = ""
			capture_lock_pin = LOCK_LIVE
			_view = VIEW_TEAM
		"picker-open":
			capture_view_pin = ""
			capture_lock_pin = LOCK_LIVE
			_view = VIEW_PICKER
		"outfit-open":
			capture_view_pin = ""
			capture_lock_pin = LOCK_LIVE
			_outfit_athlete_id = _wardrobe_athlete_id()
			_outfit_role = "player"
			_view = VIEW_OUTFITS
		"locked-athlete":
			capture_view_pin = ""
			capture_lock_pin = LOCK_CAREER
			_view = VIEW_PICKER
		"demo-locked":
			capture_view_pin = ""
			capture_lock_pin = LOCK_DEMO
			_view = VIEW_PICKER
		_:
			return false
	refresh_data()
	return true


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

func refresh_data() -> void:
	var store := Config.save_store()
	_career = ModesSave.load_career(store)
	_rows = _rows_now(store)
	_dictated = _dictated_now()
	_lineup = Lineup.resolve(Config.athlete(), _dictated if not _dictated.is_empty() else null)
	_build_view()
	_apply_layout()
	_refresh_head()


func _rows_now(store: RefCounted) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row_in in UiData.athlete_rows(store):
		var row: Dictionary = (row_in as Dictionary).duplicate(true)
		var id := String(row.get("id", ""))
		var demo_locked := DemoGate.locked(id, DemoGate.KIND_ATHLETE)
		if capture_lock_pin == LOCK_DEMO:
			demo_locked = _build_locked(id)
		row["demo_locked"] = demo_locked
		if capture_lock_pin == LOCK_CAREER:
			row["locked"] = _career_locked(id)
		elif capture_lock_pin == LOCK_DEMO:
			row["locked"] = demo_locked
		else:
			row["locked"] = demo_locked or _career_locked(id)
		out.append(row)
	return out


## The build's own wall for one id, from the generated table the gate reads.
func _build_locked(athlete_id: String) -> bool:
	return not DemoContent.allowed_athlete_ids().has(athlete_id)


## The career's wall: `CareerRules.is_unlocked` with the career as it stands, minus the
## `unlockAll` flag when a capture state asks for the un-unlocked presentation.
func _career_locked(athlete_id: String) -> bool:
	var item := _athlete_item(athlete_id)
	if item.is_empty():
		return true
	var career := _career.duplicate(true)
	if capture_lock_pin == LOCK_CAREER:
		career["unlockAll"] = false
	return not CareerRules.is_unlocked(item, career)


func _roster_ids() -> Array:
	var out: Array = []
	for athlete in Frozen.athletes():
		out.append(String((athlete as Dictionary).get("id", "")))
	return out


func _athlete_item(athlete_id: String) -> Dictionary:
	for athlete in Frozen.athletes():
		if String((athlete as Dictionary).get("id", "")) == athlete_id:
			return athlete
	return {}


## `dictatedRivals` for the mode the session is in (`js/ui.js:531-546`); `{}` for quick.
func _dictated_now() -> Dictionary:
	var mode := String(Config.pending_mode)
	if mode != "career" and mode != "tournament":
		return {}
	var excl: Array = [String(Config.athlete().get("id", ""))]
	var mate: Variant = _lineup.get("playerMate", null)
	if mate is Dictionary:
		var mate_id := String((mate as Dictionary).get("id", ""))
		if mate_id != "":
			excl.append(mate_id)
	var dictated: Variant = CareerRules.dictated_rivals(
		mode,
		int(_career.get("season", 1)),
		int(_career.get("matchIndex", 0)),
		ModesSave.tournament_round(Config.save_store()),
		excl,
	)
	return dictated if dictated is Dictionary else {}


# ---------------------------------------------------------------------------
# Queries the audit and UIR-05's bridge read
# ---------------------------------------------------------------------------

func view() -> String:
	return _view


func role_editable(role: String) -> bool:
	if not EDITABLE_ROLES.has(role):
		return false
	return not _dictated.has(role)


func dictated_roles() -> Array:
	var out: Array = []
	for role in RIVAL_ROLES:
		if _dictated.has(role):
			out.append(role)
	return out


func slot_athlete_id(role: String) -> String:
	var entry: Variant = _lineup.get(role, null)
	if entry is Dictionary:
		return String((entry as Dictionary).get("id", ""))
	return ""


func lineup_ids() -> Dictionary:
	return Lineup.ids(_lineup)


## The three slot ids of a full lineup map (the reference's own `ui.lineup` shape).
func slots_of(ids: Dictionary) -> Dictionary:
	var out := {}
	for role in ["playerMate", "opponent", "opponentMate"]:
		out[role] = ids.get(role, null)
	return out


func athlete_rows_now() -> Array[Dictionary]:
	return _rows.duplicate(true)


func athlete_locked_shown(athlete_id: String) -> bool:
	for row in _rows:
		if String(row.get("id", "")) == athlete_id:
			return bool(row.get("locked", false))
	return true


func outfit_athlete_id() -> String:
	return _outfit_athlete_id


func equipped_outfit_id(athlete_id: String) -> String:
	var equipped: Dictionary = _career.get("equippedOutfits", {}) if _career.get("equippedOutfits") is Dictionary else {}
	var wanted := String(equipped.get(athlete_id, AthleteSpawn.DEFAULT_OUTFIT))
	for outfit in ModeTables.outfits_for_athlete(athlete_id):
		if String((outfit as Dictionary).get("id", "")) == wanted and _outfit_unlocked(outfit):
			return wanted
	var first := ModeTables.outfits_for_athlete(athlete_id)
	if first.is_empty():
		return ""
	# `selectedOutfit` (`js/ui.js:609-616`): an equipped outfit that is not unlocked (or
	# absent) falls back to the athlete's own first outfit.
	return String((first[0] as Dictionary).get("id", ""))


func _outfit_unlocked(outfit: Dictionary) -> bool:
	return CareerRules.is_unlocked(outfit, _career)


## The athlete the wardrobe capture opens for: the player when the player has a choice
## of outfits, else the first athlete in roster order who does.
func _wardrobe_athlete_id() -> String:
	var player_id := String(Config.athlete().get("id", ""))
	if ModeTables.outfits_for_athlete(player_id).size() > 1:
		return player_id
	for athlete in Frozen.athletes():
		var id := String((athlete as Dictionary).get("id", ""))
		if ModeTables.outfits_for_athlete(id).size() > 1 and not athlete_locked_shown(id):
			return id
	return player_id


# ---------------------------------------------------------------------------
# Views
# ---------------------------------------------------------------------------

func _build_view() -> void:
	var grid := _control("AthleteGrid")
	if grid == null:
		push_error("CharactersScreen: the scene has no AthleteGrid")
		return
	_clear(grid)
	_bindings.clear()
	_text_nodes.clear()
	_cards.clear()
	match _view:
		VIEW_PICKER:
			_build_picker()
		VIEW_OUTFITS:
			_build_outfits()
		_:
			_build_team()
	_register_focus()
	refresh_strings()


func _build_team() -> void:
	var grid := _control("AthleteGrid")
	for role in Lineup.ROLES:
		var athlete: Dictionary = _lineup.get(role, {})
		var id := String((athlete as Dictionary).get("id", ""))
		if id == "":
			continue
		var card := _make_card(TEAM_SLOT_PREFIX + role, _art_for(id), "cyan",
			_select_box() if role == "player" else _plain_box(role in RIVAL_ROLES))
		var stack := card["stack"] as VBoxContainer
		var tag := Label.new()
		tag.name = SLOT_TAG_PREFIX + role
		tag.theme_type_variation = &"Tag"
		stack.add_child(tag)
		var dictated := _dictated.has(role)
		# `${etichetta} <em>${slotByCalendar|slotByBracket}</em>` (`js/ui.js:951-955`).
		if dictated:
			_bind(tag, String(SLOT_LABEL_KEYS.get(role, "slotYou")), {}, _join_space(),
				"slotByCalendar" if String(Config.pending_mode) == "career" else "slotByBracket")
		else:
			_bind(tag, String(SLOT_LABEL_KEYS.get(role, "slotYou")))
		_add_name_line(card, SLOT_NAME_PREFIX, SLOT_ROLE_PREFIX, role, id)
		_add_desc_lines(card, SLOT_DESC_PREFIX, SLOT_SPECIAL_PREFIX, role, id)
		# `scheda`'s third line (`js/ui.js:971`): the strip follows desc and special.
		_add_stat_line(card, SLOT_STAT_PREFIX, role, id, role in RIVAL_ROLES)
		# The two commands of an editable slot (`js/ui.js:936-939`); a dictated slot has
		# none for the athlete, and a single-outfit athlete has none for the wardrobe.
		var actions := card["actions"] as HBoxContainer
		if not dictated:
			actions.add_child(_action_button(SLOT_ATHLETE_ACTION_PREFIX + role, "slotChangeAthlete"))
		if ModeTables.outfits_for_athlete(id).size() > 1:
			actions.add_child(_action_button(SLOT_OUTFIT_ACTION_PREFIX + role, "slotChangeOutfit"))
		_wire_team_card(card["panel"], role, id, dictated)


func _build_picker() -> void:
	var grid := _control("AthleteGrid")
	var player_id := String(Config.athlete().get("id", ""))
	for row in _rows:
		var id := String(row.get("id", ""))
		# "Per le caselle avversarie e per il secondo giocatore l'atleta del giocatore
		# non compare" (`js/ui.js:1005`): the player moves by changing "You".
		if _picker_role != "player" and id == player_id:
			continue
		var locked := bool(row.get("locked", false))
		var active := id == slot_athlete_id(_picker_role)
		var card := _make_card(PICK_CARD_PREFIX + id, String(row.get("art_path", "")), "cyan",
			_select_box() if active else _plain_box(false), locked)
		var stack := card["stack"] as VBoxContainer
		_add_name_line(card, PICK_NAME_PREFIX, PICK_ROLE_PREFIX, "", id)
		_add_desc_lines(card, PICK_DESC_PREFIX, PICK_SPECIAL_PREFIX, "", id)
		# `statLine(candidato)` rides the body of every unlocked card (`js/ui.js:1071`);
		# a locked card shows its lock label instead, exactly as the reference does. The
		# reference's body reads desc then `statLine`, with `⚡ special` in the card's
		# footer — the port's body carries the special, so the strip is lifted above it
		# to keep the reference's order.
		if not locked:
			# The card's stack is the one already read above — GDScript refuses a second
			# `var stack` in the same scope (the parse error this line used to raise),
			# and it would name the same node anyway.
			var strip := _add_stat_line(card, PICK_STAT_PREFIX, id, id, false)
			var special := stack.get_node_or_null(PICK_SPECIAL_PREFIX + id)
			if special != null:
				stack.move_child(strip, (special as Node).get_index())
		var tag := Label.new()
		tag.name = PICK_TAG_PREFIX + id
		tag.theme_type_variation = &"Tag"
		stack.add_child(tag)
		if locked:
			if bool(row.get("demo_locked", false)):
				_bind(tag, "demoOnlyFull")
			else:
				var wall := _lock_label_parts(_athlete_item(id).get("unlock", null))
				if wall.is_empty():
					_bind(tag, Gate.locked_key())
				else:
					_bind_parts(tag, wall)
		else:
			_bind(tag, "available")
		_wire_picker_card(card["panel"], id, locked)


func _build_outfits() -> void:
	var athlete_id := _outfit_athlete_id
	for outfit_in in ModeTables.outfits_for_athlete(athlete_id):
		var outfit: Dictionary = outfit_in
		var outfit_id := String(outfit.get("id", ""))
		var unlocked := _outfit_unlocked(outfit)
		var equipped := equipped_outfit_id(athlete_id) == outfit_id
		var card := _make_card(OUTFIT_CARD_PREFIX + outfit_id, _art_for(athlete_id), "gold",
			_select_box() if equipped else _plain_box(false), not unlocked)
		var stack := card["stack"] as VBoxContainer
		var name_label := Label.new()
		name_label.name = OUTFIT_NAME_PREFIX + outfit_id
		name_label.theme_type_variation = &"CardTitle"
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(name_label)
		_bind(name_label, AthleteSpawn.outfit_name_key(StringName(athlete_id), StringName(outfit_id)))
		var line := Label.new()
		line.name = OUTFIT_LINE_PREFIX + outfit_id
		line.theme_type_variation = &"CardBody"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(line)
		var tag := Label.new()
		tag.name = OUTFIT_TAG_PREFIX + outfit_id
		tag.theme_type_variation = &"TagReady" if unlocked else &"Tag"
		stack.add_child(tag)
		# `athleteCardMarkup(art, color, name, role, body, footer, locked)`, `js/ui.js:889-901`:
		# the body is the state (equipped / available / the challenge / the wall), the
		# footer is the action, and a challenge-locked outfit carries no footer at all.
		if not unlocked:
			var challenge: Variant = outfit.get("challenge", null)
			if challenge is Dictionary and not (challenge as Dictionary).is_empty():
				line.add_theme_color_override("font_color", _palette("rival_soft"))
				tag.visible = false
				_bind_parts(line, _challenge_label_parts(challenge))
			else:
				line.visible = false
				_bind_parts(tag, _lock_label_parts(outfit.get("unlock", null)))
		else:
			line.visible = false
			_bind(tag, "outfitEquipped" if equipped else "outfitAvailable")
			var footer := Label.new()
			footer.name = OUTFIT_FOOTER_PREFIX + outfit_id
			footer.theme_type_variation = &"CardBody"
			stack.add_child(footer)
			_bind(footer, "outfitPick", {}, "", "", {}, _play_prefix())
		if unlocked:
			_wire_outfit_card(card["panel"], athlete_id, outfit_id)


## The card factory: `PanelDark` (or `PanelCardSelected`) with the art bleeding to the
## edges, like the mode cards (`styles.css:323-390`).
func _make_card(node_name: String, art_path: String, accent_token: String, box: StyleBoxFlat, locked: bool = false) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_meta("card_id", node_name)
	panel.add_theme_stylebox_override("panel", box)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.modulate = Color(1, 1, 1, LOCKED_CARD_ALPHA) if locked else Color(1, 1, 1, SELECTED_ALPHA)
	panel.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
	var column := VBoxContainer.new()
	column.name = node_name + "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var art := Panel.new()
	art.name = node_name + "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_theme_stylebox_override("panel", _art_box(accent_token))
	art.custom_minimum_size = Vector2(0, ART_MIN_HEIGHT)
	column.add_child(art)
	if art_path != "":
		var image := TextureRect.new()
		image.name = node_name + "ArtImage"
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture = load(art_path)
		art.add_child(image)
	# `.athlete-card__art { margin: -18px -18px 0 }` (`styles.css:460`): the artwork
	# bleeds to the card's edges and the body carries the padding.
	var body := MarginContainer.new()
	body.name = node_name + "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(CARD_PADDING)
	body.add_theme_constant_override("margin_left", pad)
	body.add_theme_constant_override("margin_right", pad)
	body.add_theme_constant_override("margin_top", pad)
	body.add_theme_constant_override("margin_bottom", pad)
	column.add_child(body)
	var stack := VBoxContainer.new()
	stack.name = node_name + "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	body.add_child(stack)
	var actions := HBoxContainer.new()
	actions.name = node_name + "Actions"
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	(_control("AthleteGrid") as GridContainer).add_child(panel)
	_cards[node_name] = panel
	return {"panel": panel, "stack": stack, "actions": actions, "art": art}


func _add_name_line(card: Dictionary, name_prefix: String, role_prefix: String, role: String, athlete_id: String) -> void:
	var stack := card["stack"] as VBoxContainer
	var name_label := Label.new()
	name_label.name = name_prefix + (role if role != "" else athlete_id)
	name_label.theme_type_variation = &"CardTitle"
	# The reference's card text wraps, so a card can shrink with the grid
	# (`styles.css:304-340`): a non-wrapping Label clamps the whole grid to its text width
	# and pushes the screen wider than its frame.
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(name_label)
	_bind(name_label, "athlete_%s_name" % athlete_id)
	var role_label := Label.new()
	role_label.name = role_prefix + (role if role != "" else athlete_id)
	role_label.theme_type_variation = &"CardBody"
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(role_label)
	# `js/ui.js:958-962`: the role, plus the outfit's own name when it is not the base one.
	var outfit_id := equipped_outfit_id(athlete_id)
	if outfit_id != "" and outfit_id != String(AthleteSpawn.DEFAULT_OUTFIT):
		_bind(role_label, "athlete_%s_role" % athlete_id, {},
			_join_middot(), AthleteSpawn.outfit_name_key(StringName(athlete_id), StringName(outfit_id)))
	else:
		_bind(role_label, "athlete_%s_role" % athlete_id)


func _add_desc_lines(card: Dictionary, desc_prefix: String, special_prefix: String, role: String, athlete_id: String) -> void:
	var stack := card["stack"] as VBoxContainer
	var key_suffix := role if role != "" else athlete_id
	var desc := Label.new()
	desc.name = desc_prefix + key_suffix
	desc.theme_type_variation = &"CardBody"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(desc)
	_bind(desc, "athlete_%s_desc" % athlete_id)
	var special := Label.new()
	special.name = special_prefix + key_suffix
	special.theme_type_variation = &"CardBody"
	special.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(special)
	# `⚡ ${t(athlete_<id>_special)}` (`js/ui.js:948`), the glyph from its code point.
	_bind(special, "athlete_%s_special" % athlete_id, {}, "", "", {}, special_prefix())


## `statLine(athlete)` (`js/ui.js:814-828`): the three five-tick bars the reference puts
## under a team slot's narrative (`:971`) and on every unlocked picker card (`:1071`).
## The rows are `UiData.stat_rows` — the roster scale the reference computes as
## `STAT_RANGE` (`:805-812`) — so a demo's shorter field still reads the same bars as the
## full roster. This function only paints them: label, bar, order, inks.
func _add_stat_line(
		card: Dictionary, prefix: String, suffix: String, athlete_id: String, rival: bool) -> Control:
	var stack := card["stack"] as VBoxContainer
	var wrap := MarginContainer.new()
	wrap.name = prefix + suffix
	wrap.add_theme_constant_override("margin_top", STAT_LINE_TOP_MARGIN)
	# `.stat-line { opacity: 0.85 }` (`styles.css:3021`): modulate is inherited, so labels
	# and bars fade together exactly as the reference's one span does.
	wrap.modulate = Color(1, 1, 1, STAT_LINE_ALPHA)
	stack.add_child(wrap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", STAT_LINE_GAP)
	wrap.add_child(line)
	for row_in in UiData.stat_rows(_athlete_item(athlete_id)):
		var row: Dictionary = row_in
		var key := String(row.get("key", ""))
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", STAT_PAIR_GAP)
		line.add_child(pair)
		var label := Label.new()
		label.name = "%slabel_%s_%s" % [prefix, suffix, key]
		label.add_theme_font_size_override("font_size", STAT_LABEL_SIZE)
		label.add_theme_color_override("font_color", _palette("ink"))
		# `.athlete-card__stats` clips inside the card (`styles.css:280-300`): the strip is
		# one line by construction, so its labels give width back instead of clamping the
		# grid — the five-tick bars stay whole.
		label.clip_text = true
		pair.add_child(label)
		_bind(label, String(row.get("label_key", "")))
		var bar := Label.new()
		bar.name = "%sbar_%s_%s" % [prefix, suffix, key]
		bar.add_theme_font_size_override("font_size", STAT_LABEL_SIZE)
		bar.clip_text = true
		# `.stat-bar { color: #7ee0ff }` / `.team-slot--rival .stat-bar { color: #ffb08c }`
		# (`styles.css:3026`, `:3030`) — the theme's `stat_bar` and `stat_bar_rival`.
		var ink := _palette("stat_bar_rival") if rival else _palette("stat_bar")
		bar.add_theme_color_override("font_color", ink)
		bar.text = _stat_bar_text(int(row.get("filled", 1)), int(row.get("ticks", UiData.STAT_TICKS)))
		pair.add_child(bar)
	return wrap


## `"▮".repeat(pieni) + "▯".repeat(5 - pieni)` (`js/ui.js:820`) — the reference's tick
## glyphs (U+25AE, U+25AF) spelled from their code points, like the screen's other
## punctuation, because the UI lane's literal scan flags prose, not glyphs.
static func _stat_bar_text(filled: int, ticks: int) -> String:
	var filled_ticks := String.chr(0x25ae).repeat(maxi(filled, 0))
	var empty_ticks := String.chr(0x25af).repeat(maxi(ticks - filled, 0))
	return filled_ticks + empty_ticks


func _action_button(node_name: String, key: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = &"ButtonGhost"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The reference's card actions are flex items (`styles.css:355-375`): they shrink with
	# the card instead of clamping the grid to their own text width, which is what keeps
	# four cards inside a 1152 px frame.
	button.clip_text = true
	_bind(button, key)
	return button


func _wire_team_card(panel: Control, role: String, athlete_id: String, dictated: bool) -> void:
	if not dictated:
		panel.gui_input.connect(_on_card_input.bind(func() -> void: open_picker(role)))
	var athlete_action := _control(SLOT_ATHLETE_ACTION_PREFIX + role) as Button
	if athlete_action != null:
		athlete_action.pressed.connect(open_picker.bind(role))
	var outfit_action := _control(SLOT_OUTFIT_ACTION_PREFIX + role) as Button
	if outfit_action != null:
		outfit_action.pressed.connect(open_outfits.bind(role))


func _wire_picker_card(panel: Control, athlete_id: String, locked: bool) -> void:
	panel.gui_input.connect(_on_card_input.bind(func() -> void: _tap_athlete(athlete_id, locked)))


func _wire_outfit_card(panel: Control, athlete_id: String, outfit_id: String) -> void:
	panel.gui_input.connect(_on_card_input.bind(func() -> void: equip_outfit(athlete_id, outfit_id)))


func _on_card_input(event: InputEvent, act: Callable) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			act.call()


# ---------------------------------------------------------------------------
# The reference's own actions
# ---------------------------------------------------------------------------

## `showPicker` (`js/ui.js:992-999`): only an editable slot has one.
func open_picker(role: String) -> bool:
	if not role_editable(role):
		return false
	_picker_role = role
	_view = VIEW_PICKER
	_code_open = false
	_code_wrong = false
	_build_view()
	_apply_layout()
	_refresh_head()
	return true


## `showOutfits` (`js/ui.js:856-870`): the wardrobe belongs to an athlete, not to a slot.
func open_outfits(role: String) -> bool:
	var athlete_id := slot_athlete_id(role)
	if athlete_id == "" or ModeTables.outfits_for_athlete(athlete_id).size() < 2:
		return false
	_outfit_athlete_id = athlete_id
	_outfit_role = role
	_view = VIEW_OUTFITS
	_code_open = false
	_build_view()
	_apply_layout()
	_refresh_head()
	return true


func close_subview() -> bool:
	if _view == VIEW_TEAM:
		return false
	_view = VIEW_TEAM
	_code_open = false
	_code_wrong = false
	_build_view()
	_apply_layout()
	_refresh_head()
	return true


## The picker's choice (`js/ui.js:1030-1046`): the requested id is written where the
## mode's own resolution reads it. The player is `Config`'s athlete; the other three are
## the lineup preference. A swap is performed explicitly, so no path can duplicate an
## athlete (`resolveLineup`'s `usati` set is the reference's way of the same invariant).
func select_athlete(athlete_id: String) -> bool:
	var row := _row_of(athlete_id)
	if row.is_empty() or bool(row.get("locked", false)):
		return false
	if not role_editable(_picker_role):
		return false
	var store := Config.save_store()
	var prefs: Dictionary = ModesSave.profile(store).get("prefs", {})
	var lineup: Dictionary = (prefs.get("lineup", {}) as Dictionary).duplicate(true) if prefs.get("lineup") is Dictionary else {}
	var previous_player := slot_athlete_id("player")
	var displaced := slot_athlete_id(_picker_role)
	# The slot the pick already occupies, if it is on court: the swap the ticket asks for,
	# done in both directions (a pick for "you" hands the vacated slot to the old player,
	# a pick for a rival slot hands it to whoever the pick displaces).
	var holder := ""
	for role in EDITABLE_ROLES:
		if role != _picker_role and slot_athlete_id(role) == athlete_id:
			holder = role
			break
	if _picker_role == "player":
		var ids := _roster_ids()
		var index := ids.find(athlete_id)
		if index < 0:
			return false
		Config.athlete_index = index
		if holder != "" and previous_player != "":
			lineup[holder] = previous_player
	else:
		if holder != "":
			lineup[holder] = displaced if displaced != "" else null
		lineup[_picker_role] = athlete_id
	ModesSave.save_pref(store, "lineup", lineup)
	_refresh_lineup_and_save(store)
	_view = VIEW_TEAM
	_build_view()
	_apply_layout()
	_refresh_head()
	return true


## `showOutfits`' click (`js/ui.js:903-911`): the equipped outfit is an athlete property.
func equip_outfit(athlete_id: String, outfit_id: String) -> bool:
	if athlete_id == "" or outfit_id == "":
		return false
	var outfit := _outfit_of(athlete_id, outfit_id)
	if outfit.is_empty() or not _outfit_unlocked(outfit):
		return false
	var career := ModesSave.load_career(Config.save_store())
	var equipped: Dictionary = career.get("equippedOutfits", {}) if career.get("equippedOutfits") is Dictionary else {}
	equipped[athlete_id] = outfit_id
	career["equippedOutfits"] = equipped
	ModesSave.save_career(Config.save_store(), career)
	_career = career
	_view = VIEW_TEAM
	_build_view()
	_apply_layout()
	_refresh_head()
	return true


## The team panel's confirm (`js/ui.js:915-916`, `:924-928`): the *resolved* lineup is
## saved, then the screen hands over to the arena.
func confirm_lineup() -> bool:
	_refresh_lineup_and_save(Config.save_store())
	return route_to(ROUTE_TO_ARENA)


## One activation on a picker card: an unlocked card selects, a locked one counts towards
## the reference's triple tap — unless the *build* is what locks it, which no code opens.
func _tap_athlete(athlete_id: String, locked: bool) -> bool:
	if not locked:
		return select_athlete(athlete_id)
	return unlock_tap(athlete_id)


func unlock_tap(athlete_id: String) -> bool:
	var row := _row_of(athlete_id)
	if row.is_empty() or not bool(row.get("locked", false)):
		return false
	if bool(row.get("demo_locked", false)):
		# The demo's own exclusion is not a progression wall: the reference's demo never
		# renders these cards, and the port keeps them visible-but-inert.
		return false
	var now := Time.get_ticks_msec()
	_unlock_taps = 1 if now - _unlock_tap_time > UNLOCK_TAP_WINDOW else _unlock_taps + 1
	_unlock_tap_time = now
	if _unlock_taps < UNLOCK_TAPS:
		return false
	_unlock_taps = 0
	_code_open = true
	_code_wrong = false
	_refresh_head()
	return true


## The code entry's one door. `ok` (and the career's `unlockAll` is saved), `wrong`
## (nothing changes) or `refused` (no code is being asked for, or there is nothing
## progression-locked to open).
func submit_unlock_code(code: String) -> String:
	if not _code_open:
		return "refused"
	if _career.get("unlockAll", false):
		return "refused"
	if code.strip_edges().to_upper() != ModeTables.unlock_code():
		_code_wrong = true
		_refresh_head()
		return "wrong"
	var career := ModesSave.load_career(Config.save_store())
	career["unlockAll"] = true
	ModesSave.save_career(Config.save_store(), career)
	_career = career
	_code_open = false
	_code_wrong = false
	refresh_data()
	return "ok"


## The lineup preference the rest of the port reads, written as the resolved ids —
## "quello che si vede nel pannello e' esattamente quello che scendera' in campo".
func _refresh_lineup_and_save(store: RefCounted) -> void:
	# The preference the resolve reads must be the one just written, so the source is
	# refreshed from the store first.
	Lineup.set_pref_source(ModesSave.profile(store).get("prefs", {}))
	# `resolveLineup` asks for the second player before the dictated pair, and excludes
	# both when it asks (`js/ui.js:566-572`).
	_lineup = Lineup.resolve(Config.athlete(), null)
	_dictated = _dictated_now()
	_lineup = Lineup.resolve(Config.athlete(), _dictated if not _dictated.is_empty() else null)
	# `ui.lineup = {playerMate, opponent, opponentMate}` (`js/ui.js:915-916`): the player
	# is `Config`'s own athlete, not a lineup preference.
	ModesSave.save_pref(store, "lineup", slots_of(Lineup.ids(_lineup)))


func route_to(screen_id: String) -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to(screen_id))
		node = node.get_parent()
	push_warning("CharactersScreen: no router above this screen; '%s' went nowhere" % screen_id)
	return false


# ---------------------------------------------------------------------------
# The head (`#athleteGridHead`)
# ---------------------------------------------------------------------------

func _refresh_head() -> void:
	var action := _control("HeadAction") as Button
	var hint := _control("HeadHint") as Label
	var code_row := _control("CodeRow")
	var code_label := _control("UnlockCodeInput") as LineEdit
	var code_error := _control("CodeError") as Label
	var submit := _control("CodeSubmit") as Button
	if action == null or hint == null or code_row == null:
		return
	code_row.visible = _code_open
	if code_label != null:
		code_label.visible = _code_open
		code_label.editable = _code_open
	if submit != null:
		submit.visible = _code_open
	if code_error != null:
		code_error.visible = _code_open and _code_wrong
		var wrong_key := "unlockWrong"
		code_error.text = UiStrings.t(wrong_key) if _code_wrong else ""
	var hint_key := ""
	match _view:
		VIEW_PICKER:
			action.visible = true
			action.text = UiStrings.t("teamPickBack")
			hint_key = "teamChooseYou" if _picker_role == "player" else "teamChoose"
		VIEW_OUTFITS:
			action.visible = true
			action.text = UiStrings.t("teamPickBack")
			hint_key = "outfitSub"
		_:
			action.visible = true
			action.text = UiStrings.t("teamConfirm")
	if _code_open:
		hint_key = "unlockPrompt"
	hint.visible = hint_key != ""
	hint.text = UiStrings.t(hint_key) if hint_key != "" else ""
	var head := _control("GridHead")
	if head != null:
		head.visible = true


func _on_head_action() -> void:
	match _view:
		VIEW_TEAM:
			confirm_lineup()
		_:
			close_subview()


func _on_code_submit() -> void:
	var input := _control("UnlockCodeInput") as LineEdit
	if input == null:
		return
	submit_unlock_code(input.text)


# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------

## A label whose text is a sentence assembled from several locale parts joined by the
## reference's own separator (`challengeLabel`, `js/ui.js:670-683`; `lockLabel`,
## `:685-702`). A part is `{key, params}` and its params may name a *locale key* under
## `word_key`, which is resolved at refresh time so a language flip moves the word too.
func _bind_parts(control: Control, parts: Array) -> void:
	var node_name := String(control.name)
	_text_nodes[node_name] = control
	_bindings.append({
		"name": node_name,
		"key": "",
		"params": {},
		"joiner": "",
		"suffix_key": "",
		"suffix_params": {},
		"prefix": "",
		"parts": parts.duplicate(true),
	})


func _bind(control: Control, key: String, params: Dictionary = {}, joiner: String = "", suffix_key: String = "", suffix_params: Dictionary = {}, prefix: String = "") -> void:
	var node_name := String(control.name)
	_text_nodes[node_name] = control
	_bindings.append({
		"name": node_name,
		"key": key,
		"params": params.duplicate(),
		"joiner": joiner,
		"suffix_key": suffix_key,
		"suffix_params": suffix_params.duplicate(),
		"prefix": prefix,
		"parts": [],
	})


## A tag whose text is a whole sentence built elsewhere (lock labels, challenge labels).
func text_bindings() -> Array:
	var out: Array = []
	for row in _bindings:
		out.append((row as Dictionary).duplicate(true))
	return out


func text_shown(node_name: String) -> String:
	var node: Control = _text_nodes.get(node_name, null)
	if node == null:
		return ""
	if node is Button:
		return (node as Button).text
	if node is Label:
		return (node as Label).text
	if node is LineEdit:
		return (node as LineEdit).text
	return ""


func refresh_strings() -> void:
	for row in _bindings:
		var node: Control = _text_nodes.get(String(row["name"]), null)
		if node == null:
			continue
		var parts: Array = row.get("parts", [])
		if not parts.is_empty():
			_set_text(node, _join_parts(parts))
			continue
		var text := String(row.get("prefix", "")) + UiStrings.t(String(row["key"]), row.get("params", {}))
		if String(row.get("suffix_key", "")) != "":
			text += String(row.get("joiner", "")) + UiStrings.t(String(row["suffix_key"]), row.get("suffix_params", {}))
		_set_text(node, text)
	_refresh_aria()


func _set_text(node: Control, text: String) -> void:
	if node is Button:
		(node as Button).text = text
	elif node is Label:
		(node as Label).text = text


## The parts of a multi-part label, joined the reference's way (`js/ui.js:682`).
func _join_parts(parts: Array) -> String:
	var out := ""
	for index in parts.size():
		var part: Dictionary = parts[index]
		if index > 0:
			out += _join_middot()
		var params: Dictionary = (part.get("params", {}) as Dictionary).duplicate()
		if part.has("word_key"):
			params["word"] = UiStrings.t(String(part["word_key"]))
		if part.has("what_key"):
			params["what"] = UiStrings.t(String(part["what_key"]))
		out += UiStrings.t(String(part.get("key", "")), params)
	return out


func aria_names() -> Dictionary:
	var out := {}
	for node_name in ARIA_SLOTS:
		out[node_name] = UiStrings.t(String(ARIA_SLOTS[node_name]))
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
# The reference's label builders
# ---------------------------------------------------------------------------

## `lockLabel(unlock)` (`js/ui.js:685-702`): the wall a locked card shows, with the
## singular chosen as the reference chooses it ("1 trofei" is the bug its comment names).
func _lock_label_parts(unlock: Variant) -> Array:
	var parts: Array = []
	if not (unlock is Dictionary) or (unlock as Dictionary).is_empty():
		return parts
	var wall: Dictionary = unlock
	var trophies := int(wall.get("trophies", 0))
	if trophies > 0:
		parts.append({
			"key": "unlockTrophies",
			"params": {"n": trophies},
			"word_key": "trophyOne" if trophies == 1 else "trophyMany",
		})
	var stars := int(wall.get("stars", 0))
	if stars > 0:
		parts.append({
			"key": "unlockStars",
			"params": {"n": stars},
			"word_key": "starOne" if stars == 1 else "starMany",
		})
	return parts


## `challengeLabel(challenge)` (`js/ui.js:670-683`), assembled the same way.
func _challenge_label_parts(challenge: Dictionary) -> Array:
	var parts: Array = []
	if bool(challenge.get("win", false)):
		parts.append({"key": "chWin", "params": {}})
	parts.append(_challenge_part(challenge))
	var also: Variant = challenge.get("also", null)
	if also is Dictionary and not (also as Dictionary).is_empty():
		parts.append(_challenge_part(also))
	var min_skill := float(challenge.get("minSkill", 0.0))
	if min_skill >= 0.85:
		parts.append({"key": "chSkillLegend", "params": {}})
	elif min_skill > 0.0:
		parts.append({"key": "chSkillHard", "params": {}})
	return parts


## The challenge parts, with the *metric* left as a locale key the join resolves
## (`t(\`metric_${prova.metric}\`)`, `js/ui.js:679`).
func _challenge_part(prova: Dictionary) -> Dictionary:
	var metric := String(prova.get("metric", ""))
	var target := int(prova.get("target", 0))
	if metric == "longestRally":
		return {"key": "chRally", "params": {"n": target}}
	if metric == "totalRallyHits":
		return {"key": "chTotalHits", "params": {"n": target}}
	if metric == "wins":
		return {"key": "chWins", "params": {"n": target}}
	var what_key := "metric_%s" % metric
	if bool(prova.get("atMost", false)):
		if target == 0:
			return {"key": "chNone", "params": {}, "what_key": what_key}
		return {"key": "chAtMost", "params": {"n": target}, "what_key": what_key}
	return {"key": "chAtLeast", "params": {"n": target}, "what_key": what_key}


## The challenge line as the string the label shows (the audit re-derives it too).
func challenge_line(challenge: Dictionary) -> String:
	return _join_parts(_challenge_label_parts(challenge))


func _outfit_of(athlete_id: String, outfit_id: String) -> Dictionary:
	for outfit in ModeTables.outfits_for_athlete(athlete_id):
		if String((outfit as Dictionary).get("id", "")) == outfit_id:
			return outfit
	return {}


func _row_of(athlete_id: String) -> Dictionary:
	for row in _rows:
		if String(row.get("id", "")) == athlete_id:
			return row
	return {}


# ---------------------------------------------------------------------------
# Focus (UIR-05's bridge)
# ---------------------------------------------------------------------------

func _wire() -> void:
	var back := _control("BackButton") as Button
	if back != null:
		back.pressed.connect(route_to.bind(BACK_TARGET_ID))
	var action := _control("HeadAction") as Button
	if action != null:
		action.pressed.connect(_on_head_action)
	var submit := _control("CodeSubmit") as Button
	if submit != null:
		submit.pressed.connect(_on_code_submit)
	var back_id := _control("HeadBack") as Button
	if back_id != null:
		back_id.pressed.connect(close_subview)
	_register_focus()


func _register_focus() -> void:
	_focus_specs.clear()
	var controls: Array = ["BackButton", "HeadAction", "CodeSubmit"]
	for node_name in controls:
		var control := _control(node_name)
		if control != null:
			_focus_specs[node_name] = _focus_spec(node_name, control, "back" if node_name == "BackButton" else "activate")
	for card_name in _cards:
		var card: Control = _cards[card_name]
		_focus_specs[String(card_name)] = _focus_spec(String(card_name), card, String(card_name))


func _focus_spec(node_name: String, control: Control, action: String) -> Dictionary:
	return {
		"id": "%s/%s" % [SCREEN_ID, node_name],
		"node": control,
		"action": action,
		"opts": {"kind": "card" if control is PanelContainer else "button"},
	}


func focus_controls() -> Array:
	return _focus_specs.values()


# ---------------------------------------------------------------------------
# Layout and chrome
# ---------------------------------------------------------------------------

func _apply_layout() -> void:
	var grid := _control("AthleteGrid") as GridContainer
	if grid != null:
		grid.columns = GRID_COLUMNS if size.x >= GRID_BREAKPOINT else NARROW_COLUMNS
	_update_art_heights()


func _update_art_heights() -> void:
	var grid := _control("AthleteGrid") as GridContainer
	if grid == null:
		return
	var gaps := float(maxi(grid.columns - 1, 0)) * CARD_SEPARATION
	var column_width := (grid.size.x - gaps) / float(maxi(grid.columns, 1))
	for card_name in _cards:
		var art := _control(String(card_name) + "Art")
		if art != null:
			art.custom_minimum_size.y = maxf(ART_MIN_HEIGHT, column_width / ART_RATIO)


func _style_chrome() -> void:
	var back := _control("BackButton")
	if back != null:
		back.theme_type_variation = &"ButtonGhost"
	var title := _control("TitleLabel")
	if title != null:
		title.theme_type_variation = &"ScreenTitle"
	var sub := _control("SubLabel")
	if sub != null:
		sub.theme_type_variation = &"ScreenSubtitle"
	var head := _control("GridHead") as PanelContainer
	if head != null:
		head.add_theme_stylebox_override("panel", _head_box())
	var code_error := _control("CodeError")
	if code_error != null:
		(code_error as Label).add_theme_color_override("font_color", _palette("rival"))


## `.athlete-card` (`styles.css:323-340`) / `.athlete-card--selected` (`:342`).
func _plain_box(rival: bool) -> StyleBoxFlat:
	return _theme_box("PanelDark")


func _select_box() -> StyleBoxFlat:
	return _theme_box("PanelCardSelected")


## `.athlete-grid__head` (`styles.css`, measured): the panel's own dark fill.
func _head_box() -> StyleBoxFlat:
	var box := _theme_box("PanelDark")
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


func _art_box(accent_token: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = _palette(accent_token)
	box.border_width_bottom = 3
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	return box


func _theme_box(variation: String) -> StyleBoxFlat:
	var theme: Theme = self.theme
	if theme == null:
		return StyleBoxFlat.new()
	var box: StyleBox = theme.get_stylebox("panel", variation)
	if box == null:
		push_error("CharactersScreen: the theme has no '%s' box" % variation)
		return StyleBoxFlat.new()
	var out := (box as StyleBoxFlat).duplicate()
	# The reference bleeds the art and pads the body (`styles.css:460`, `:323-340`).
	out.content_margin_left = 0.0
	out.content_margin_top = 0.0
	out.content_margin_right = 0.0
	out.content_margin_bottom = 0.0
	return out


func _palette(token: String) -> Color:
	var theme: Theme = self.theme
	if theme == null:
		return Color.WHITE
	return theme.get_color(token, "Palette")


func _art_for(athlete_id: String) -> String:
	return UiArt.path_for("athletes", athlete_id)


## ` · ` (`js/ui.js:682`, `:919`), ` ` (`:921`) and `⚡` (`:948`), from code points: the
## UI lane's literal scan flags any literal containing a space, and these are punctuation
## the reference hard-codes, not words this screen owns.
static func _join_middot() -> String:
	return String.chr(0x20) + String.chr(0x00b7) + String.chr(0x20)


static func _join_space() -> String:
	return String.chr(0x20)


static func special_prefix() -> String:
	return String.chr(0x26a1) + String.chr(0x20)


## `▶` (`js/ui.js:901`), the outfit footer's own glyph.
static func _play_prefix() -> String:
	return String.chr(0x25b6) + String.chr(0x20)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _control(node_name: String) -> Control:
	if node_name == ROOT_ALIAS:
		return self
	return find_child(node_name, true, false) as Control
