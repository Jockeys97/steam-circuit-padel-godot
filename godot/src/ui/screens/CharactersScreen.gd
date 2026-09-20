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
##
## THE VISUAL REPAIR (landed 2026-09-20, wave 4). Four defects the 3D roster work exposed
## by contrast, each one measured against the reference's own rules rather than a
## preference:
##
##   THE HEADER WAS EMPTY. `index.html:104-110` gives this screen a back control, an `h2`
##   and a `p`, and the port's scene carried all three nodes with no binding on them —
##   a styled back button with no word in it and a title block nothing ever wrote to.
##   They are text bindings now (`_bind_chrome`), so `applyLanguage`'s equivalent
##   (`refresh_strings`) reaches them like every other node.
##
##   THE PORTRAIT WAS A BANNER. `ART_RATIO` carried the MODE card's `3 / 1` from
##   `styles.css:460` where the athlete card is `3 / 4` (`:347`), so `cover` cropped every
##   portrait to a slit at eye level. The ratio is the athlete card's own, and the image
##   is placed by hand to keep the reference's `background-position: center top`
##   (`_fit_art_image`) — cover, anchored at the top, so the head is never the part that
##   gets cut.
##
##   THE BODY DID NOT STACK. The body was a `MarginContainer` with two children, and a
##   `MarginContainer` lays every child it is given into the SAME rect: the description
##   and the two card commands were drawn on top of each other, which is the smeared text
##   in the report. The blocks are stacked now (`<card>BodyStack`), in the reference's own
##   order — name, role, description, ability, stat strip, then `Athlete` / `Outfit`.
##
##   THE ROLE LABEL SAT ON THE FACE, and the confirm was a full-width shelf.
##   `.team-slot-wrap` (`styles.css:2966-2977`) puts the label in its own block above the
##   card; `.athlete-grid__head` (`:2902-2935`) is a bar whose one command is a compact
##   primary at its far end. Both are read here the way the reference reads them.
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
## `.athlete-card__art { aspect-ratio: 3 / 4 }` (`styles.css:347`), the ATHLETE card's
## portrait. The `3 / 1` at `styles.css:460` is the MODE card's strip and this constant
## used to carry it, so the port drew a wide banner where the reference draws a
## portrait: `cover` then cut every head off at the chin. The value is the reference's
## own w / h, the same shape `ModesScreen::ART_RATIO` keeps for its card.
const ART_RATIO := 0.75
const ART_MIN_HEIGHT := 80.0
## `.athlete-grid { padding: 32px 64px; max-width: 1200px; margin: 0 auto }`
## (`styles.css:304-315`): the grid is capped and centred, so a wide window widens the
## margins instead of stretching four portraits into banners. `ModesScreen` reads its
## own setup area the same way (`:813`).
const GRID_MAX_WIDTH := 1200.0
const GRID_SIDE_PADDING := 64.0
## `.athlete-card__body { padding: 18px }`.
const CARD_PADDING := 18.0

## `.team-slot-wrap { display: flex; flex-direction: column; gap: 8px }`
## (`styles.css:2966-2975`): the position label is a block of its own ABOVE the card.
## Inside the card it sat on the portrait, and on the opponent-at-the-net slot — where
## the label wraps to two lines — it covered the face of the athlete being chosen, which
## is the reference's own recorded reason for the wrapper.
const SLOT_WRAP_PREFIX := "TeamSlotWrap_"
const SLOT_WRAP_GAP := 8.0
## `.team-slot__tag { min-height: 38px; padding: 5px 12px; border-radius: 12px }`
## (`styles.css:2979-2995`). The reserved height is what keeps the four cards on one
## line when two of the labels wrap (the career suffix).
const SLOT_TAG_MIN_HEIGHT := 38.0
const SLOT_TAG_PADDING_H := 12.0
const SLOT_TAG_PADDING_V := 5.0
const SLOT_TAG_CORNER := 12.0
const SLOT_TAG_BORDER := 1

## `.athlete-grid__head` (`styles.css:2902-2919`): a full-width bar with its own 64 px
## side padding and a hairline under it, whose one command (`[data-team-confirm]`) is
## pushed to the far end (`margin-left: auto`) as a compact primary.
const HEAD_SIDE_PADDING := 64.0
const HEAD_BAR_PADDING_V := 11.0
const HEAD_ACTION_MIN_HEIGHT := 46.0
const HEAD_HINT_SIZE := 14
const HEAD_GLASS_ALPHA := 0.72
const HEAD_RULE_ALPHA := 0.14
## The card's own portrait node, `<card>ArtImage`: a `TextureRect` the card factory
## places by hand, because the reference's `background-position: center top` has no
## Control equivalent (`styles.css:351-353`).
const ART_IMAGE_SUFFIX := "ArtImage"

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
## The special-athlete strip (port additions): its OWN prefixes, so no frozen
## picker node is touched and the audits that count `PickCard_<id>` cards over
## `athlete_rows_now()` (the six) stay exactly what they were.
const SPECIAL_HEAD := "SpecialStripHead"
const SPECIAL_CARD_PREFIX := "SpecialPickCard_"
const SPECIAL_NAME_PREFIX := "SpecialPickName_"
const SPECIAL_STAT_PREFIX := "SpecialPickStat_"
const OUTFIT_CARD_PREFIX := "OutfitCard_"
const OUTFIT_NAME_PREFIX := "OutfitName_"
const OUTFIT_ART_PREFIX := "OutfitArt_"
const OUTFIT_LINE_PREFIX := "OutfitLine_"
const OUTFIT_TAG_PREFIX := "OutfitTag_"
const OUTFIT_FOOTER_PREFIX := "OutfitFooter_"
## The actions this screen reports to UIR-05's bridge. None of them is a `to-*` edge:
## each one is a choice the screen has to make before it navigates (the mode screen's
## own reasoning), so the bridge reports it and the mount hands it back to
## `activate()` below. The verbs are the reference's own `data-azione` values
## (`atleta` / `completo`, `js/ui.js:936-939`) and the two header commands.
const HEAD_ACTION := "head-action"
const CODE_ACTION := "code-submit"
const SLOT_ATHLETE_ACTION := "slot-athlete"
const SLOT_OUTFIT_ACTION := "slot-outfit"
const PICK_ACTION := "pick"
const OUTFIT_ACTION := "outfit"
## The header commands by node name, so one loop registers all three controls and the
## back control keeps its declared `back` action.
const HEAD_ACTIONS := {
	"BackButton": "back",
	"HeadAction": HEAD_ACTION,
	"CodeSubmit": CODE_ACTION,
}
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
	# A Godot-only special athlete (`src/character/specials.gd`): the frozen table
	# does not hold him and never will, but the stat strip and the career door must
	# see the record a card for him is drawn from.
	return AthleteSpawn.record(StringName(athlete_id))


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
	_clear(_control("SpecialGrid"))
	_control("SpecialSection").hide()
	_bindings.clear()
	_text_nodes.clear()
	_cards.clear()
	_bind(_control("BackButton"), "back")
	_bind(_control("TitleLabel"), "charactersTitle")
	_bind(_control("SubLabel"), "charactersSub")
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
		# `.team-slot-wrap` (`styles.css:2966-2977`): the position label is a block of its
		# own ABOVE the card. Inside the card it sat on the portrait, and on the
		# opponent-at-the-net slot — where it wraps to two lines — it covered the face of
		# the athlete being chosen, which is the reference's own recorded reason for the
		# wrapper.
		var wrap := VBoxContainer.new()
		wrap.name = SLOT_WRAP_PREFIX + role
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_theme_constant_override("separation", int(SLOT_WRAP_GAP))
		grid.add_child(wrap)
		var tag := _slot_tag(role)
		wrap.add_child(tag)
		var card := _make_card(TEAM_SLOT_PREFIX + role, _art_for(id), "cyan",
			_select_box() if role == "player" else _plain_box(role in RIVAL_ROLES),
			false, wrap)
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

	# --- special-athlete strip (port additions) --------------------------------
	# The Godot-only specials (`Config.selectable_special_athletes()`: one in a full
	# build, none in a demo) are offered in their OWN strip after the frozen picker
	# — never as frozen pick cards: `athlete_rows_now()` stays the six the audits
	# count, and the strip's cards carry their own `SpecialPickCard_` names. A pick
	# goes through the same `select_athlete` door, and the frozen grid's own rule
	# holds here too: the athlete already in the "player" slot is not offered to a
	# rival slot, so no pick can duplicate him.
	var specials: Array = Config.selectable_special_athletes()
	if not specials.is_empty():
		(_control(SPECIAL_HEAD) as Label).text = "SPECIAL"
		var special_grid := _control("SpecialGrid")
		for row_in in specials:
			var row: Dictionary = row_in
			var id := String(row.get("id", ""))
			if _picker_role != "player" and id == player_id:
				continue
			var active := id == slot_athlete_id(_picker_role)
			_control("SpecialSection").show()
			var card := _make_card(SPECIAL_CARD_PREFIX + id, _art_for(id), "gold",
				_select_box() if active else _plain_box(false), false, special_grid)
			var stack := card["stack"] as VBoxContainer
			var name_label := Label.new()
			name_label.name = SPECIAL_NAME_PREFIX + id
			name_label.theme_type_variation = &"CardTitle"
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stack.add_child(name_label)
			_bind(name_label, "athlete_%s_name" % id)
			_add_stat_line(card, SPECIAL_STAT_PREFIX, id, id, false)
			_wire_picker_card(card["panel"], id, false)


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
func _make_card(
		node_name: String, art_path: String, accent_token: String, box: StyleBoxFlat,
		locked: bool = false, parent: Control = null) -> Dictionary:
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
	# `overflow: hidden` on the card (`styles.css:327`) plus the hand-placed image below:
	# without the clip the covered portrait would bleed over the card's own body.
	art.clip_contents = true
	art.custom_minimum_size = Vector2(0, ART_MIN_HEIGHT)
	column.add_child(art)
	if art_path != "":
		var image := TextureRect.new()
		image.name = node_name + ART_IMAGE_SUFFIX
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Anchored top-left and sized by `_fit_art_image`, not stretched to the panel: the
		# reference pins the cover to the TOP of the box (`background-position: center
		# top`, `styles.css:352`), so a portrait taller than the box loses its feet, never
		# its face.
		image.set_anchors_preset(Control.PRESET_TOP_LEFT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture = load(art_path)
		image.set_meta("portrait_texture", image.texture)
		art.add_child(image)
		art.resized.connect(_fit_art_image.bind(art, image))
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
	# The margin box carries the padding; the box inside it carries the ORDER. A
	# `MarginContainer` lays every child it is given into the SAME content rect, so the
	# narrative stack and the command row used to be painted on top of one another — the
	# smeared description in the report. The reference's body is one flow
	# (`athleteCardMarkup`, `js/ui.js:834-845`: heading, role, description, footer), so the
	# two blocks are stacked here and the commands land below the stat strip.
	var inner := VBoxContainer.new()
	inner.name = node_name + "BodyStack"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 14)
	body.add_child(inner)
	var stack := VBoxContainer.new()
	stack.name = node_name + "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	inner.add_child(stack)
	var actions := HBoxContainer.new()
	actions.name = node_name + "Actions"
	actions.add_theme_constant_override("separation", 8)
	inner.add_child(actions)
	# `.team-slot-wrap` (`styles.css:2966-2977`): a team slot hands the card the column it
	# shares with its position label; the picker and the wardrobe keep adding to the grid.
	var host: Control = parent if parent != null else _control("AthleteGrid")
	host.add_child(panel)
	_cards[node_name] = panel
	return {"panel": panel, "stack": stack, "actions": actions, "art": art}


## `background-size: cover` + `background-position: center top` (`styles.css:347-353`) for
## a `TextureRect`: the scale covers the box, the horizontal centre is kept, and the image
## is pinned to the top edge instead of being centred — the whole difference between a
## portrait and a crop of somebody's collar. It reads the box the layout actually gave the
## art panel, and the panel's own `resized` is what calls it again.
func _fit_art_image(art: Control, image: TextureRect) -> void:
	var texture := image.get_meta("portrait_texture") as Texture2D
	if texture == null:
		return
	var box := art.size
	var source := texture.get_size()
	if box.x <= 0.0 or box.y <= 0.0 or source.x <= 0.0 or source.y <= 0.0:
		return
	# Crop the source, not the Control, so the cover stays inside its parent bounds.
	var crop_width := minf(source.x, source.y * box.x / box.y)
	var crop_height := crop_width * box.y / box.x
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2((source.x - crop_width) * 0.5, 0.0, crop_width, crop_height)
	image.texture = cropped
	image.position = Vector2.ZERO
	image.size = box


func _add_name_line(card: Dictionary, name_prefix: String, role_prefix: String, role: String, athlete_id: String) -> void:
	var stack := card["stack"] as VBoxContainer
	var name_label := Label.new()
	name_label.name = name_prefix + (role if role != "" else athlete_id)
	name_label.theme_type_variation = &"CardTitle"
	# The reference's card text wraps, so a card can shrink with the grid
	# (`styles.css:304-340`): a non-wrapping Label clamps the whole grid to its text width
	# and pushes the screen wider than its frame.
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# `<h3 style="color:${color}">` (`js/ui.js:838`): the name wears the athlete's own
	# accent, the hex the frozen roster carries (`src/sim/frozen/data.json`), not a theme
	# token — the roster's six are not all palette names.
	name_label.add_theme_color_override("font_color", _accent_of(athlete_id))
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
	# `.slot-special { font-weight: 700; color: var(--cyan) }` (`styles.css:3099-3104`) and
	# `.team-slot--rival .slot-special { color: #ffc09a }` (`:3101-3103`), the palette's
	# own `rival_soft`.
	special.add_theme_color_override("font_color",
		_palette("rival_soft") if role in RIVAL_ROLES else _palette("cyan"))
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
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", STAT_LINE_GAP)
	wrap.add_child(line)
	for row_in in UiData.stat_rows(_athlete_item(athlete_id)):
		var row: Dictionary = row_in
		var key := String(row.get("key", ""))
		var pair := HBoxContainer.new()
		pair.custom_minimum_size.x = 84
		pair.add_theme_constant_override("separation", STAT_PAIR_GAP)
		line.add_child(pair)
		var label := Label.new()
		label.name = "%slabel_%s_%s" % [prefix, suffix, key]
		label.add_theme_font_size_override("font_size", STAT_LABEL_SIZE)
		label.add_theme_color_override("font_color", _palette("ink"))
		# `.athlete-card__stats` clips inside the card (`styles.css:280-300`): the strip is
		# one line by construction, so its labels give width back instead of clamping the
		# grid — the five-tick bars stay whole.
		label.clip_text = false
		label.custom_minimum_size.x = 26
		pair.add_child(label)
		_bind(label, String(row.get("label_key", "")))
		var bar := Label.new()
		bar.name = "%sbar_%s_%s" % [prefix, suffix, key]
		bar.add_theme_font_size_override("font_size", STAT_LABEL_SIZE)
		bar.clip_text = true
		bar.custom_minimum_size.x = 50
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
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 13)
	var rival := node_name.contains("opponent")
	var ink := _palette("rival_soft") if rival else _palette("cyan")
	if key == "slotChangeOutfit":
		ink = Color("ffd166")
	var box := _slot_tag_box("opponent" if rival else "playerMate")
	box.border_color = Color(ink, 0.5)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	_bind(button, key)
	return button


## `.team-slot__tag` (`styles.css:2979-3000`): the position label as its own block — the
## theme's `Tag` role for the type, plus the pill the reference draws around it. It wraps
## like every other label on this screen, because a non-wrapping one would clamp the grid
## to the width of "OPPONENT AT THE NET" and push the four cards past their frame.
func _slot_tag(role: String) -> Label:
	var tag := Label.new()
	tag.name = SLOT_TAG_PREFIX + role
	tag.theme_type_variation = &"Tag"
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(0, SLOT_TAG_MIN_HEIGHT)
	tag.add_theme_stylebox_override("normal", _slot_tag_box(role))
	tag.add_theme_color_override("font_color", _slot_tag_ink(role))
	return tag


## The pill's own fill and border, side by side with the reference's two variants
## (`styles.css:2996-3012`). The player's own slot is the green one — it is the one the
## reader is choosing for themselves — and both rival slots are the warm one.
func _slot_tag_box(role: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.content_margin_left = SLOT_TAG_PADDING_H
	box.content_margin_right = SLOT_TAG_PADDING_H
	box.content_margin_top = SLOT_TAG_PADDING_V
	box.content_margin_bottom = SLOT_TAG_PADDING_V
	box.border_width_left = SLOT_TAG_BORDER
	box.border_width_top = SLOT_TAG_BORDER
	box.border_width_right = SLOT_TAG_BORDER
	box.border_width_bottom = SLOT_TAG_BORDER
	box.corner_radius_top_left = SLOT_TAG_CORNER
	box.corner_radius_top_right = SLOT_TAG_CORNER
	box.corner_radius_bottom_right = SLOT_TAG_CORNER
	box.corner_radius_bottom_left = SLOT_TAG_CORNER
	if role == "player":
		box.bg_color = Color(20.0 / 255.0, 60.0 / 255.0, 40.0 / 255.0, 0.86)
		box.border_color = Color(120.0 / 255.0, 1.0, 190.0 / 255.0, 0.5)
	elif role in RIVAL_ROLES:
		box.bg_color = Color(4.0 / 255.0, 10.0 / 255.0, 35.0 / 255.0, 0.82)
		box.border_color = Color(1.0, 150.0 / 255.0, 110.0 / 255.0, 0.5)
	else:
		box.bg_color = Color(4.0 / 255.0, 10.0 / 255.0, 35.0 / 255.0, 0.82)
		box.border_color = Color(120.0 / 255.0, 200.0 / 255.0, 1.0, 0.45)
	return box


## `.team-slot__tag { color: #9ef8ff }`, `.team-slot-wrap--rival … { color: #ffc09a }`,
## `.team-slot-wrap--you … { color: #9dffcf }` (`styles.css:2996-3012`).
func _slot_tag_ink(role: String) -> Color:
	if role == "player":
		return Color(157.0 / 255.0, 1.0, 207.0 / 255.0)
	if role in RIVAL_ROLES:
		return _palette("rival_soft")
	return Color(158.0 / 255.0, 248.0 / 255.0, 1.0)


## The accent the frozen roster carries for an athlete (`"color"`, the hex the reference
## paints the card's heading with, `js/ui.js:838`). A Godot-only special has no row there,
## and a missing accent falls back to the lane's cyan rather than inventing a colour.
func _accent_of(athlete_id: String) -> Color:
	var hex := String(_athlete_item(athlete_id).get("color", ""))
	if hex.is_valid_html_color():
		return Color(hex)
	return _palette("cyan")


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
	if not role_editable(_picker_role):
		return false
	# A Godot-only special is not a frozen row and has no frozen index: it takes
	# the special seat (`_select_special`). A demo offers none, so the door refuses
	# there exactly as it refuses a withheld frozen athlete.
	if _is_special_athlete(athlete_id):
		return _select_special(athlete_id)
	var row := _row_of(athlete_id)
	if row.is_empty() or bool(row.get("locked", false)):
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


## Is this id one of the Godot-only specials THIS build offers? A demo offers
## none (`Config.selectable_special_athletes()` is empty there), which is what
## makes the picker door refuse a special in a demo.
func _is_special_athlete(athlete_id: String) -> bool:
	for row in Config.selectable_special_athletes():
		if String((row as Dictionary).get("id", "")) == athlete_id:
			return true
	return false


## The pick of a special: `resolveLineup`'s rule (`js/ui.js:1030-1046`), on the
## special seat. The player slot moves `Config`'s own athlete selection onto the
## special (`Config.set_special_athlete_id` — the seat is the id itself, since a
## special has no frozen roster index); a rival slot writes the lineup preference
## exactly as the frozen path does. The swap is explicit, so no path can
## duplicate an athlete.
func _select_special(athlete_id: String) -> bool:
	var store := Config.save_store()
	var prefs: Dictionary = ModesSave.profile(store).get("prefs", {})
	var stored: Variant = prefs.get("lineup")
	var lineup: Dictionary = (stored as Dictionary).duplicate(true) if stored is Dictionary else {}
	var previous_player := slot_athlete_id("player")
	var displaced := slot_athlete_id(_picker_role)
	var holder := ""
	for role in EDITABLE_ROLES:
		if role != _picker_role and slot_athlete_id(role) == athlete_id:
			holder = role
			break
	if _picker_role == "player":
		if not Config.set_special_athlete_id(athlete_id):
			return false
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
	_refresh_head()


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
			_focus_specs[node_name] = _focus_spec(node_name, control, String(HEAD_ACTIONS.get(node_name, "back")))
	for card_name in _cards:
		var card: Control = _cards[card_name]
		# `collectMenuTargets` (`js/main.js:571-577`): a card that holds its own
		# buttons is a container, not a target. The four team slots carry Atleta and
		# Completo, so the card is skipped and those two commands are the targets —
		# registering the card instead left both commands unreachable with a pad,
		# which is the report. The picker and the wardrobe keep the card as the
		# target, exactly as the reference does.
		var commands := _command_names(String(card_name))
		_focus_specs[String(card_name)] = _focus_spec(String(card_name), card,
			_card_action(String(card_name)), {"contains_buttons": not commands.is_empty()})
		for command in commands:
			var button := _control(command) as Button
			if button == null:
				continue
			_focus_specs[command] = _focus_spec(command, button, _command_action(command))


## The command buttons a card holds, in the reference's own order: Atleta then
## Completo (`js/ui.js:936-939`). Only the team slots have any; the picker's and the
## wardrobe's cards are the buttons themselves.
func _command_names(card_name: String) -> Array:
	var out: Array = []
	if not card_name.begins_with(TEAM_SLOT_PREFIX):
		return out
	var role := card_name.substr(TEAM_SLOT_PREFIX.length())
	for prefix in [SLOT_ATHLETE_ACTION_PREFIX, SLOT_OUTFIT_ACTION_PREFIX]:
		if _control(prefix + role) != null:
			out.append(prefix + role)
	return out


## The action a card reports when it *is* the target: the picker's choice, the
## wardrobe's pick, and nothing for a team slot the reference leaves inert (a dictated
## rival slot with a single outfit has no command and no click handler either —
## `_wire_team_card`).
func _card_action(card_name: String) -> String:
	if card_name.begins_with(PICK_CARD_PREFIX):
		return "%s:%s" % [PICK_ACTION, card_name.substr(PICK_CARD_PREFIX.length())]
	if card_name.begins_with(SPECIAL_CARD_PREFIX):
		return "%s:%s" % [PICK_ACTION, card_name.substr(SPECIAL_CARD_PREFIX.length())]
	if card_name.begins_with(OUTFIT_CARD_PREFIX):
		return "%s:%s:%s" % [OUTFIT_ACTION, _outfit_athlete_id, card_name.substr(OUTFIT_CARD_PREFIX.length())]
	return ""


## The action a team slot's command button reports, as `<verb>:<role>`.
func _command_action(command: String) -> String:
	if command.begins_with(SLOT_ATHLETE_ACTION_PREFIX):
		return "%s:%s" % [SLOT_ATHLETE_ACTION, command.substr(SLOT_ATHLETE_ACTION_PREFIX.length())]
	if command.begins_with(SLOT_OUTFIT_ACTION_PREFIX):
		return "%s:%s" % [SLOT_OUTFIT_ACTION, command.substr(SLOT_OUTFIT_ACTION_PREFIX.length())]
	return ""


## This screen's activation door for UIR-05's bridge — the same contract
## `ModesScreen.activate()` documents: an action the bridge does not route (it is not a
## `to-*` edge) is reported to the mount, which hands it here. Every branch runs the
## handler the mouse path runs, so the save rules and the locked-content refusals stay
## in one place.
func activate(action: String) -> bool:
	var parts := action.split(":")
	match String(parts[0]):
		HEAD_ACTION:
			_on_head_action()
			return true
		CODE_ACTION:
			_on_code_submit()
			return true
		SLOT_ATHLETE_ACTION:
			return parts.size() == 2 and open_picker(String(parts[1]))
		SLOT_OUTFIT_ACTION:
			return parts.size() == 2 and open_outfits(String(parts[1]))
		PICK_ACTION:
			return parts.size() == 2 and select_athlete(String(parts[1]))
		OUTFIT_ACTION:
			return parts.size() == 3 and equip_outfit(String(parts[1]), String(parts[2]))
	return false


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
# Layout and chrome
# ---------------------------------------------------------------------------

func _apply_layout() -> void:
	var area := _control("GridArea") as MarginContainer
	var padding := maxi(24, int((size.x - GRID_MAX_WIDTH) / 2.0))
	if size.x < GRID_MAX_WIDTH + GRID_SIDE_PADDING * 2.0:
		padding = 32 if size.x < GRID_BREAKPOINT else 64
	area.add_theme_constant_override("margin_left", padding)
	area.add_theme_constant_override("margin_right", padding)
	var grid := _control("AthleteGrid") as GridContainer
	if grid != null:
		grid.columns = GRID_COLUMNS if size.x >= GRID_BREAKPOINT else NARROW_COLUMNS
		(_control("SpecialGrid") as GridContainer).columns = grid.columns
	_update_art_heights()


func _update_art_heights() -> void:
	var grid := _control("AthleteGrid") as GridContainer
	if grid == null:
		return
	var gaps := float(maxi(grid.columns - 1, 0)) * CARD_SEPARATION
	var column_width := (grid.size.x - gaps) / float(maxi(grid.columns, 1))
	# A single special must retain the same width as a regular roster card.
	for special_card in _control("SpecialGrid").get_children():
		(special_card as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		(special_card as Control).custom_minimum_size.x = maxf(0.0, column_width)
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
	_control("TitleBlock").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var action := _control("HeadAction")
	action.theme_type_variation = &"ButtonPrimary"
	action.custom_minimum_size.y = HEAD_ACTION_MIN_HEIGHT
	_control("HeadBack").hide()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := _control("HeadRow")
	row.add_child(spacer)
	row.move_child(spacer, 0)
	row.move_child(action, row.get_child_count() - 1)
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
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.03, 0.12, HEAD_GLASS_ALPHA)
	box.border_width_bottom = 1
	box.border_color = Color(0.0, 0.8, 1.0, HEAD_RULE_ALPHA)
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
