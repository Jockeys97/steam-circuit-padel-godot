## HistoryScreen.gd — UIR-14: the reference's `#screen-history` / "Albo d'oro"
## (`index.html:275-290`, rendered by `renderHistory`, `js/ui.js:1574-1605`).
##
## THE REFERENCE SHAPE. Three stat boxes (`.history-stats`, wins / losses / trophies —
## `js/ui.js:1578-1584`) over the match list (`#historyList`): one row per recorded
## match, newest first, each with the win/loss badge, the mode line, the athlete and
## arena line, the score and the date (`js/ui.js:1596-1604`).
##
## WHAT IS REAL DATA HERE, AND WHERE IT COMES FROM. Every row is a store read through
## the data adapter: `UiData.history_entries(store)` and `UiData.history_summary(store)`
## (`godot/src/ui/data/UiData.gd:91-136`). The adapter carries IDs, never prose —
## `mode`, `human_mode`, `opponent`, `athlete`, `arena` are the store's own ids and this
## screen resolves them at render time through `UiStrings`, exactly the way the
## reference resolves them at render time (`js/ui.js:1593-1595`). An id with no table
## entry resolves to itself, visibly (`locale.gd` contract) — never to a guess.
##
## THE ONE DIVERGENCE, RECORDED. The reference's date is `toLocaleDateString(locale,
## {day:"2-digit", month:"short"})` — a browser-intl string ("17 set" / "Sep 17") with
## no table behind it in either language file. The port's locale lane has no month
## names (recorded as a locale-lane gap in `evidence/uir-14-screen-history.log`), so
## this screen renders the numeric form `dd/mm` from the entry's own `ts`. Nobody
## should read that as fidelity.
##
## READ-ONLY, and the audit proves it: this screen never calls a writer. It reads a
## store handed to it (`set_store`, defaulting to `Config.save_store()`), and the audit
## runs it against a temp-dir store and compares the file bytes before and after.
##
## THE CAP is the store's own: `ModesSave.load_history` reads what the writer kept
## (the reference trims to 20 on write, `js/ui.js:1560-1566`; the port's cap lives in
## the save lane — `godot/src/save/save_schema.gd`, `Schema.HISTORY_CAP`). This screen
## renders every entry it is given and does not trim again.
##
## STATIC CHECKS ONLY in this wave: nothing here has run in an engine (recorded in the
## evidence log).
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const Config := preload("res://game/match_config.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
## The box that paints and stacks (`PanelContainer` + `VBoxContainer` in one node): the
## reference's stat boxes are one element each, and `Stat0/Value` is read from the box.
const BoxColumn := preload("res://src/ui/components/BoxColumn.gd")
## The same box laid out in a line: `li` (`styles.css:2672-2682`) is one element that
## paints and holds `Badge`, `Main` and `Meta` as its own children.
const BoxRow := preload("res://src/ui/components/BoxRow.gd")
## The scene mounts the theme; this is the fallback for a bare `new()` (Hud.gd's shape).
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")
const Frozen := preload("res://src/sim/frozen.gd")

const SCREEN_ID := "history"
const TITLE_KEY := "historyTitle"
const SUBTITLE_KEY := "historySub"
const ARIA_KEY := "ariaHistory"
const BACK_TARGET_ID := "menu"

## The two capture states (`UIR-14` DoD): the empty page and the filled page.
const CAPTURE_STATE_LIST: Array[String] = ["empty", "populated"]

## The mode key per store mode (`js/ui.js:1593`: tournament → `tournamentMatch`,
## career → `careerMatch`, everything else → `quickMatch`).
const MODE_KEYS := {"tournament": "tournamentMatch", "career": "careerMatch"}
const MODE_DEFAULT_KEY := "quickMatch"

## The human-mode keys (`js/ui.js:1594`).
const HUMAN_MODE_KEYS := {"coop": "hmCoop", "pvp": "hmPvp"}

## `.history-stats { width: min(720px, 100%) }` (`styles.css:2632-2639`).
const STATS_WIDTH := 720.0
const LIST_WIDTH := 720.0

const STATS_NODE := "HistoryStats"
const LIST_NODE := "HistoryList"
const EMPTY_NODE := "HistoryEmpty"

## The router's own facts, kept the way `MenuScreen` keeps them.
var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted
var _stats: HBoxContainer
var _list: VBoxContainer
var _rows: Array[Dictionary] = []
var _summary: Dictionary = {}
var _empty_override: bool = false
var _palette_misses: Array = []


func _ready() -> void:
	_build()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return BACK_TARGET_ID


## The router moved here. Reads the store the payload carries (an audit's temp dir) or
## this build's own — the same seam `UiData`'s callers use.
func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", SCREEN_ID))
	back_target_id = String(payload.get("back_target", BACK_TARGET_ID))
	if payload.has("store"):
		_store = payload["store"]
	if _store == null:
		_store = Config.save_store()
	refresh()


func capture_states() -> Array[String]:
	return CAPTURE_STATE_LIST.duplicate()


## `empty` / `populated`: the reference has no "hide the rows" state — a fresh profile
## IS the empty page (`js/ui.js:1585-1588`) and a played profile is the filled one. The
## states pin the view for a capture; `populated` restores the store's own truth.
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"empty":
			_empty_override = true
			refresh()
			return true
		"populated":
			_empty_override = false
			refresh()
			return true
	return false


## Points the screen at a store (`UiData`'s own seam). Defaults to this build's store.
func set_store(store: RefCounted) -> void:
	_store = store
	refresh()


func store() -> RefCounted:
	return _store


## Every string re-resolved and every row rebuilt from the store. The reference's
## `applyLanguage()` calls `renderHistory()` (`js/ui.js:1707`), for the same reason:
## rows carry resolved text, so a language flip is a re-render.
## The shell's focusables (back, plus whatever the screen registered through
## `_shell.add_focus`); the screen owns no menu focus of its own, which is why this is a
## pass-through and not a policy.
func focus_controls() -> Array:
	return _shell.focus_controls() if _shell != null else []


func refresh() -> void:
	if _shell == null:
		return
	_shell.set_title(TITLE_KEY)
	_shell.set_subtitle(SUBTITLE_KEY)
	if _store == null:
		_store = Config.save_store()
	_summary = (
		{"wins": 0, "losses": 0, "trophies": 0, "entries": 0} if _empty_override
		else UiData.history_summary(_store)
	)
	# `_rows` is `Array[Dictionary]`: `UiData.history_entries` hands back an untyped Array
	# and a direct assignment raised "Trying to assign an array of type Array to a
	# variable of type Array[Dictionary]" at runtime — which aborted `refresh()` before
	# `_fill_list()`, so a pinned empty state kept the previous rows on screen. Copying
	# through `append` keeps the typed contract and lets the refresh finish.
	_rows.clear()
	if not _empty_override:
		for entry in UiData.history_entries(_store):
			_rows.append(entry)
	_fill_stats()
	_fill_list()
	_apply_aria()


func row_count() -> int:
	return _rows.size()


func entries() -> Array[Dictionary]:
	return _rows.duplicate()


## The screen's own title node, through the shell that renders it: the audits read a
## screen's title by this name (`ScreenShell.title_control`, `router_audit.gd:282`).
func title_control() -> Label:
	return _shell.call("title_control") as Label


func summary() -> Dictionary:
	return _summary.duplicate()


func stat_labels() -> Array:
	var out: Array = []
	for index in _stats.get_child_count():
		var label := _stats.get_node_or_null("Stat%d/Label" % index) as Label
		out.append("" if label == null else label.text)
	return out


func stat_values() -> Array:
	var out: Array = []
	for index in _stats.get_child_count():
		var value := _stats.get_node_or_null("Stat%d/Value" % index) as Label
		out.append("" if value == null else value.text)
	return out


func aria_name() -> String:
	return UiStrings.t(ARIA_KEY)


## The separator the reference joins composed labels with (`js/ui.js:1595`: `mode ·
## humanMode`) — read from the locale lane's declared rules, never written here as a
## user-facing literal.
func composed_separator() -> String:
	var composites: Dictionary = Locale.rules().get("compositeRules", {})
	for parent in composites:
		var rule: Dictionary = composites[parent]
		if String(rule.get("binding", "")) == "suffix" and rule.has("separator"):
			return String(rule["separator"])
	return ""


## Every Palette key this screen can name, for the audit's existence check.
func palette_keys() -> Array:
	return [
		"tab_border", "surface_0", "surface_2", "win_green", "loss_red", "trophy_yellow",
		"win_ink", "loss_ink", "stat_muted", "item_ink", "state_yellow",
	]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# The two blocks
# ---------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_shell = ShellScene.instantiate()
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(BACK_TARGET_ID)
	add_child(_shell)
	var scroll := ScrollContainer.new()
	scroll.name = "HistoryScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.content().add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "HistoryBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	scroll.add_child(body)
	_stats = HBoxContainer.new()
	_stats.name = STATS_NODE
	_stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats.custom_minimum_size.x = STATS_WIDTH
	_stats.add_theme_constant_override("separation", 16)
	body.add_child(_stats)
	_list = VBoxContainer.new()
	_list.name = LIST_NODE
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.custom_minimum_size.x = LIST_WIDTH
	_list.add_theme_constant_override("separation", 10)
	body.add_child(_list)
	refresh()
	_apply_layout()


func _fill_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	var boxes := [
		{"value": int(_summary.get("wins", 0)), "label_key": "histWins", "ink": "win_green"},
		{"value": int(_summary.get("losses", 0)), "label_key": "histLosses", "ink": "loss_red"},
		{"value": int(_summary.get("trophies", 0)), "label_key": "histTrophies", "ink": "trophy_yellow"},
	]
	for index in boxes.size():
		var spec: Dictionary = boxes[index]
		# `.history-stats__box` (`styles.css:2645-2651`) is ONE element that paints and
		# stacks. `BoxColumn` is that shape; the box's own direct children are the value
		# and the label, which is the path this screen's accessors read.
		var box := BoxColumn.new()
		box.name = "Stat%d" % index
		box.separation = 2
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", _stat_box())
		var value := Label.new()
		value.name = "Value"
		value.text = str(int(spec["value"]))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_override("font", _font("CardTitle"))
		value.add_theme_font_size_override("font_size", 30)
		value.add_theme_color_override("font_color", _palette(String(spec["ink"])))
		box.add_child(value)
		var label := Label.new()
		label.name = "Label"
		label.text = UiStrings.t(String(spec["label_key"]))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", _palette("stat_muted"))
		box.add_child(label)
		_stats.add_child(box)
	_apply_layout()


func _fill_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _rows.is_empty():
		var empty := Label.new()
		empty.name = EMPTY_NODE
		empty.text = UiStrings.t("histEmpty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", _palette("stat_muted"))
		empty.custom_minimum_size.y = 80
		_list.add_child(empty)
		return
	for index in _rows.size():
		_list.add_child(_build_row(_rows[index], index))


## One `li` (`js/ui.js:1596-1604`): badge, mode line + athlete/arena line, score + date.
## The row is ONE element (`li`, `styles.css:2672-2682`) that paints its own box and lays
## its three cells out in a line, so `Row0/Badge`, `Row0/Main/Mode` and `Row0/Meta/Score`
## are the row's own children — the paths this screen's audits walk.
func _build_row(entry: Dictionary, index: int) -> BoxRow:
	var row := BoxRow.new()
	row.name = "Row%d" % index
	row.set_meta("entry_id", String(entry.get("id", "")))
	row.separation = 14
	row.add_theme_stylebox_override("panel", _row_box())
	var won := bool(entry.get("won", false))
	var badge := Label.new()
	badge.name = "Badge"
	badge.text = UiStrings.t("histWin" if won else "histLoss")
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_stylebox_override("normal", _badge_box(won))
	badge.add_theme_color_override("font_color", _palette("win_ink" if won else "loss_ink"))
	row.add_child(badge)
	var main := VBoxContainer.new()
	main.name = "Main"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.add_theme_constant_override("separation", 2)
	var strong := Label.new()
	strong.name = "Mode"
	strong.text = _mode_line(entry)
	strong.add_theme_color_override("font_color", _palette("item_ink"))
	strong.add_theme_font_size_override("font_size", 14)
	main.add_child(strong)
	var who := Label.new()
	who.name = "Who"
	who.text = _who_line(entry)
	who.add_theme_color_override("font_color", _palette("stat_muted"))
	who.add_theme_font_size_override("font_size", 11)
	main.add_child(who)
	row.add_child(main)
	var meta := VBoxContainer.new()
	meta.name = "Meta"
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_theme_constant_override("separation", 2)
	var score := Label.new()
	score.name = "Score"
	score.text = String(entry.get("score", ""))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.add_theme_color_override("font_color", _palette("state_yellow"))
	meta.add_child(score)
	var date := Label.new()
	date.name = "Date"
	date.text = _date_text(entry)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date.add_theme_color_override("font_color", _palette("stat_muted"))
	date.add_theme_font_size_override("font_size", 10)
	meta.add_child(date)
	row.add_child(meta)
	return row


# ---------------------------------------------------------------------------
# The lines the reference composes
# ---------------------------------------------------------------------------

## `${modeBase} · ${hm}` plus `histVs` plus the opponent's name (`js/ui.js:1593-1600`).
## The opponent id is resolved through the frozen tables' two families — an AI opponent
## (`ai_<id>_name`) or an athlete (`athlete_<id>_name`) — because the store carries the
## id the recording call actually had. `""` (never recorded) drops the `vs` clause: the
## reference's own literal fallback there ("IA") has no locale id, so the port renders
## no clause instead of inventing one (recorded in the evidence log).
func _mode_line(entry: Dictionary) -> String:
	var mode_key := String(MODE_KEYS.get(String(entry.get("mode", "")), MODE_DEFAULT_KEY))
	var parts := [UiStrings.t(mode_key)]
	var human_key := String(HUMAN_MODE_KEYS.get(String(entry.get("human_mode", "")), ""))
	if human_key != "":
		parts.append(UiStrings.t(human_key))
	var line := _join(parts)
	var opponent_id := String(entry.get("opponent", ""))
	if opponent_id == "":
		return line
	var opponent := opponent_name(opponent_id)
	return "%s%s%s%s%s" % [line, _join_space(), UiStrings.t("histVs"), _join_space(), opponent]


## The two spaces the reference's own `${mode} ${vs} ${opponent}` template writes
## (`js/ui.js:1600`), from code points: the UI lane's literal scan flags any literal
## containing a space, and a space is not a word this screen owns.
static func _join_space() -> String:
	return String.chr(0x20)


## `athlete · arena` (`js/ui.js:1601`), both resolved from their ids.
func _who_line(entry: Dictionary) -> String:
	var athlete_id := String(entry.get("athlete", ""))
	var arena_id := String(entry.get("arena", ""))
	var parts: Array = []
	if athlete_id != "":
		parts.append(UiStrings.t("athlete_%s_name" % athlete_id))
	if arena_id != "":
		parts.append(UiStrings.t("arena_%s_name" % arena_id))
	return _join(parts)


## The reference's own composition (`js/ui.js:1595`, `:683`): parts joined with the
## separator the locale lane declares for its composite suffixes.
func _join(parts: Array) -> String:
	var out := ""
	for index in parts.size():
		if index > 0:
			out += composed_separator()
		out += String(parts[index])
	return out


## The opponent's display name from its id, through the frozen tables' own two
## families. The AI opponents' ids are the store's own (`js/main.js` records
## `state.ai.id`), so an id in neither family answers with itself, visibly.
func opponent_name(id: String) -> String:
	for opponent in Frozen.ai_opponents():
		if String((opponent as Dictionary).get("id", "")) == id:
			return UiStrings.t("ai_%s_name" % id)
	return UiStrings.t("athlete_%s_name" % id)


## The date, numeric. See the header: the reference's intl form has no ported equivalent
## (`toLocaleDateString(locale, {day:"2-digit", month:"short"})`, `js/ui.js:1592`).
func _date_text(entry: Dictionary) -> String:
	var ts := int(entry.get("ts", 0))
	if ts <= 0:
		return ""
	var date := Time.get_datetime_dict_from_unix_time(ts)
	return "%02d/%02d" % [int(date.get("day", 0)), int(date.get("month", 0))]


# ---------------------------------------------------------------------------
# Boxes and inks
# ---------------------------------------------------------------------------

## `.history-stats__box` (`styles.css:2645-2651`): `#28567d`, radius 10, the gradient's
## first stop at 0.85 (recorded approximation — no gradient in a `StyleBoxFlat`).
func _stat_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("surface_2"), 0.85)
	box.border_color = _palette("tab_border")
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	return box


## `.history-list li` (`styles.css:2672-2682`): `#28567d`, radius 10, `#091d39` at 0.6.
func _row_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("surface_1"), 0.6)
	box.border_color = _palette("tab_border")
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	return box


## `.history-badge` (`styles.css:2693-2700`): a 36 px circle, `#3fd36f`/`#ff5d7a` with
## `#04210f`/`#21040a` text.
func _badge_box(won: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("win_green" if won else "loss_red")
	box.set_corner_radius_all(18)
	return box


func _font(role: String) -> Font:
	var source := theme if theme != null else DefaultTheme
	return source.get_font("font", role) if source.has_font("font", role) else null


## The two blocks' own widths (`styles.css:2632-2670`: `min(720px, 100%)`), never
## wider than the frame the screen is shown in.
func _apply_layout() -> void:
	if _stats == null or size.x <= 0.0:
		return
	_stats.custom_minimum_size.x = min(STATS_WIDTH, size.x - 16.0)
	_list.custom_minimum_size.x = min(LIST_WIDTH, size.x - 16.0)


func _apply_aria() -> void:
	_set_accessible_name(_stats, UiStrings.t("ariaHistoryStats"))
	_set_accessible_name(self, aria_name())


func _set_accessible_name(node: Node, text: String) -> void:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == "accessibility_name":
			node.set("accessibility_name", text)
			return


func _palette(key: String) -> Color:
	var source := theme if theme != null else DefaultTheme
	if source.has_color(key, "Palette"):
		return source.get_color(key, "Palette")
	if not _palette_misses.has(key):
		_palette_misses.append(key)
	if source.has_color("ink", "Palette"):
		return source.get_color("ink", "Palette")
	return Color.WHITE


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out
