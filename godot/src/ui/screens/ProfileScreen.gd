## ProfileScreen.gd — UIR-16: the reference's `#screen-profile` / "Profilo carriera"
## (`index.html:308-327`), rendered by `renderProfile` (`js/ui.js:1608-1666`).
##
## THE REFERENCE SHAPE. Four career boxes (wins, trophies, stars, win rate —
## `js/ui.js:1616-1621`), then the season objectives list (`#profileObjectives`) and
## the unlock summary (`#profileUnlocks`) with its one working route: the Obiettivi
## button (`js/ui.js:1652-1664`).
##
## WHAT IS REAL DATA HERE. Everything: `UiData.profile_summary(store)` (the four
## boxes), `UiData.season_objectives(store)` (the list, with each objective's live
## status), `UiData.unlock_summary(store)` (the counted summary). The screen renders
## what the adapters return and asks the modes lane's own rule functions for nothing
## extra.
##
## THE SCOUT'S ACCEPTANCE, RESTATED SO IT IS NOT LOST: the four numbers the boxes show
## must be the same numbers `ModesSave.profile(store)` computes — the audit asserts
## box-by-box equality against that reader, not against hard-coded expectations.
##
## THE ROUTE IS THE REFERENCE'S OWN. The Obiettivi button carries `data-action=
## "to-challenges"` (`js/ui.js:1662`) and this screen routes it the way `MenuScreen`
## routes its own actions: the first node above with `go_to`. The port's router table
## already declares `menu → to-challenges → challenges` (`ScreenRouter.SCREENS`), so
## nothing here invents an edge.
##
## STATIC CHECKS ONLY in this wave: nothing here has run in an engine (recorded in
## `evidence/uir-16-screen-profile.log`).
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const Config := preload("res://game/match_config.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")
## The box that paints and stacks (`PanelContainer` + `VBoxContainer` in one node): the
## reference's stat boxes are one element each, and `Stat0/Value` is read from the box.
const BoxColumn := preload("res://src/ui/components/BoxColumn.gd")
## The scene mounts the theme; this is the fallback for a bare `new()` (Hud.gd's shape).
const DefaultTheme := preload("res://src/ui/theme/padel_theme.tres")

const SCREEN_ID := "profile"
const TITLE_KEY := "profileTitle"
const SUBTITLE_KEY := "profileSub"
const ARIA_KEY := "ariaProfile"
const BACK_TARGET_ID := "menu"

## The screen's one action, exactly the reference's (`js/ui.js:1662`).
const ACTION_TARGETS := {"to-challenges": "challenges"}

## The three capture states (`UIR-16` DoD): the live page, a season with nothing
## claimed yet (the reference's own empty state) and a mid-season page.
const CAPTURE_STATE_LIST: Array[String] = ["default", "empty-objectives", "mid-season"]

## The four boxes, in order (`js/ui.js:1616-1621`): the reference's own class suffix,
## label key and ink.
const STAT_BOXES: Array = [
	{"key": "wins", "label_key": "histWins", "ink": "win_green", "suffix": "wins"},
	{"key": "seasons", "label_key": "profileSeasons", "ink": "trophy_yellow", "suffix": "trophies"},
	{"key": "stars", "label_key": "profileStars", "ink": "gold", "suffix": "stars"},
	{"key": "win_rate", "label_key": "profileWinRate", "ink": "cyan", "suffix": "rate"},
]

## `.profile-stats { grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)) }`
## (`styles.css:1296-1301`) and the `min(560px, 100%)`-shaped single column the
## reference's own screen falls back to on a narrow frame.
const STATS_MIN_WIDTH := 130.0
const STATS_GAP := 12.0
const CONTENT_MAX_WIDTH := 640.0

const STATS_NODE := "ProfileStats"
const OBJECTIVES_NODE := "ProfileObjectives"
const UNLOCKS_NODE := "ProfileUnlocks"
const UNLOCK_BUTTON_NODE := "ProfileUnlocksButton"
const EMPTY_NODE := "ProfileEmpty"

## The router's own facts, kept the way `MenuScreen` keeps them.
var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted
var _stats: GridContainer
var _objectives: VBoxContainer
var _unlocks: VBoxContainer
var _summary: Dictionary = {}
var _objective_rows: Array[Dictionary] = []
var _unlock_summary: Dictionary = {}
var _pin_empty_objectives: bool = false
var _progress_pin: Dictionary = {}
var _palette_misses: Array = []
## The two section headings (`Title_<key>`), kept so a language flip can re-resolve them.
var _section_titles: Dictionary = {}


func _ready() -> void:
	_build()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return BACK_TARGET_ID


func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", SCREEN_ID))
	back_target_id = String(payload.get("back_target", BACK_TARGET_ID))
	if payload.has("store"):
		_store = payload["store"]
	refresh()


func capture_states() -> Array[String]:
	return CAPTURE_STATE_LIST.duplicate()


## `default` / `empty-objectives` / `mid-season` (`js/ui.js:1624-1640`; the empty state
## is the reference's own branch, the mid-season one a pinned progress so a capture
## shows a season with one foot in both columns).
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"default":
			_pin_empty_objectives = false
			_progress_pin = {}
			refresh()
			return true
		"empty-objectives":
			_pin_empty_objectives = true
			_progress_pin = {}
			refresh()
			return true
		"mid-season":
			_pin_empty_objectives = false
			_progress_pin = _mid_season_progress()
			refresh()
			return true
	return false


func set_store(store: RefCounted) -> void:
	_store = store
	refresh()


func store() -> RefCounted:
	return _store


func refresh() -> void:
	if _shell == null:
		return
	_shell.set_title(TITLE_KEY)
	_shell.set_subtitle(SUBTITLE_KEY)
	_refresh_section_titles()
	if _store == null:
		_store = Config.save_store()
	_summary = UiData.profile_summary(_store)
	_objective_rows = _objectives_for_view()
	_unlock_summary = UiData.unlock_summary(_store)
	_fill_stats()
	_fill_objectives()
	_fill_unlocks()
	_apply_aria()


## The shell's focusables (back + the Obiettivi button); the screen owns no menu focus
## of its own, which is why this is a pass-through and not a policy.
func focus_controls() -> Array:
	return _shell.focus_controls() if _shell != null else []


func objectives() -> Array[Dictionary]:
	return _objective_rows.duplicate(true)


func summary() -> Dictionary:
	return _summary.duplicate()


func unlock_summary() -> Dictionary:
	return _unlock_summary.duplicate()


func stat_values() -> Array:
	var out: Array = []
	for index in STAT_BOXES.size():
		var value := _stats.get_node_or_null("Stat%d/Value" % index) as Label
		out.append("" if value == null else value.text)
	return out


func stat_labels() -> Array:
	var out: Array = []
	for index in STAT_BOXES.size():
		var label := _stats.get_node_or_null("Stat%d/Label" % index) as Label
		out.append("" if label == null else label.text)
	return out


func unlock_button() -> Button:
	# The button lives inside `.profile-unlocks__summary`'s line (`js/ui.js:1652-1664`),
	# not directly under the panel: the accessor's job is to hand back the button the
	# screen draws, wherever in its own summary box it sits.
	if _unlocks == null:
		return null
	return _unlocks.find_child(UNLOCK_BUTTON_NODE, true, false) as Button


## The screen's own title node, through the shell that renders it (`ScreenShell.title_control`).
func title_control() -> Label:
	return _shell.call("title_control") as Label


## The router moves (the reference's `to-challenges`, `js/ui.js:1662`): the first node
## above this screen that owns `go_to`, exactly `MenuScreen.route_action`'s walk.
func route_action(action: String) -> bool:
	var target := String(ACTION_TARGETS.get(action, ""))
	if target == "":
		push_error("ProfileScreen.route_action: '%s' is not one of this screen's actions" % action)
		return false
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to(target))
		node = node.get_parent()
	push_warning("ProfileScreen: no router above this screen; '%s' went nowhere" % action)
	return false


func aria_name() -> String:
	return UiStrings.t(ARIA_KEY)


## Every Palette key this screen can name, for the audit's existence check.
func palette_keys() -> Array:
	return [
		"tab_border", "surface_2", "win_green", "trophy_yellow", "gold", "cyan",
		"stat_muted", "muted", "ink", "line", "white", "green", "summary_fill",
	]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# The objective rows (adapter first; the pin composes through the same lane)
# ---------------------------------------------------------------------------

## The adapter's own rows, or — for the `mid-season` capture pin only — the same
## composition with a pinned progress dictionary. The pin exists because the adapter
## reads the store and a capture must not write one; everything below the pin is the
## modes lane's own rule functions, the same the adapter calls.
func _objectives_for_view() -> Array[Dictionary]:
	if _pin_empty_objectives:
		return []
	if _progress_pin.is_empty():
		return UiData.season_objectives(_store)
	var career := ModesSave.load_career(_store)
	var out: Array[Dictionary] = []
	for objective_in in CareerProgress.ensure_season_objectives(career):
		var objective: Dictionary = objective_in
		var id := String(objective.get("id", ""))
		var status: Dictionary = CareerProgress.objective_status(objective, _progress_pin)
		out.append({
			"id": id,
			"label_key": "obj_%s" % id,
			"target": int(status.get("target", 0)),
			"progress": int(status.get("progress", 0)),
			"done": bool(status.get("done", false)),
			"claimed": bool(objective.get("claimed", false)),
		})
	return out


## The `mid-season` pin: the live season's own progress with the first pending
## objective's metric brought to its target, so the page shows one done row and the
## rest pending.
func _mid_season_progress() -> Dictionary:
	var career := ModesSave.load_career(_store)
	var progress := CareerProgress.season_progress(career)
	for objective_in in CareerProgress.ensure_season_objectives(career):
		var objective: Dictionary = objective_in
		if bool(CareerProgress.objective_status(objective, progress).get("done", false)):
			continue
		var metric := _metric_of(String(objective.get("id", "")))
		if metric != "":
			progress[metric] = int(objective.get("target", 0))
		break
	return progress


## The metric an objective definition reads (`career_rules.gd::objective_defs()`),
## the same lookup `objective_status` does internally.
func _metric_of(def_id: String) -> String:
	var definitions: Dictionary = CareerRules.objective_defs()
	return String((definitions.get(def_id, {}) as Dictionary).get("metric", ""))


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_section_titles = {}
	_shell = ShellScene.instantiate()
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(BACK_TARGET_ID)
	add_child(_shell)
	var scroll := ScrollContainer.new()
	scroll.name = "ProfileScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.content().add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "ProfileBody"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_stats = GridContainer.new()
	_stats.name = STATS_NODE
	_stats.columns = 4
	_stats.add_theme_constant_override("h_separation", int(STATS_GAP))
	body.add_child(_stats)
	body.add_child(_section_title("objSeasonTitle"))
	_objectives = VBoxContainer.new()
	_objectives.name = OBJECTIVES_NODE
	_objectives.add_theme_constant_override("separation", 0)
	_objectives.add_theme_stylebox_override("panel", _panel_box())
	body.add_child(_panel_wrap(_objectives))
	body.add_child(_section_title("profileUnlocksTitle"))
	_unlocks = VBoxContainer.new()
	_unlocks.name = UNLOCKS_NODE
	_unlocks.add_theme_constant_override("separation", 0)
	_unlocks.add_theme_stylebox_override("panel", _panel_box())
	body.add_child(_panel_wrap(_unlocks))
	resized.connect(_apply_layout)
	refresh()
	_apply_layout()


## `.profile-section-title` (`styles.css:1311-1317`): small, uppercased, muted.
func _section_title(key: String) -> Label:
	var title := Label.new()
	title.name = "Title_%s" % key
	title.text = UiStrings.t(key)
	title.add_theme_color_override("font_color", _palette("muted"))
	title.add_theme_font_size_override("font_size", 13)
	_section_titles[key] = title
	return title


## The section headings are the screen's only text resolved at build time and not by a
## fill, so a language flip with the page already mounted left them in the old language
## while the shell, the stat labels and the rows moved. Re-resolving them here puts them
## back on the same path as everything else (`refresh()` is what `enter()` and
## `set_store()` call).
func _refresh_section_titles() -> void:
	for key in _section_titles:
		var label := _section_titles[key] as Label
		if label != null:
			label.text = UiStrings.t(String(key))


## `.profile-objectives` / `.profile-unlocks` (`styles.css:1319-1325`): a `--line` box
## over a faint white fill.
func _panel_wrap(inner: VBoxContainer) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_box())
	panel.add_child(inner)
	return panel


func _fill_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	for index in STAT_BOXES.size():
		var spec: Dictionary = STAT_BOXES[index]
		var value := int(_summary.get(String(spec["key"]), 0))
		# `.profile-stats__box` is one element that paints and stacks (`BoxColumn`), so
		# `Stat%d/Value` and `Stat%d/Label` are the box's direct children — the paths
		# this screen's accessors and the audit read.
		var box := BoxColumn.new()
		box.name = "Stat%d" % index
		box.separation = 2
		box.custom_minimum_size.x = STATS_MIN_WIDTH
		box.set_meta("class_suffix", String(spec["suffix"]))
		box.add_theme_stylebox_override("panel", _stat_box())
		var value_label := Label.new()
		value_label.name = "Value"
		value_label.text = ("%d%%" % value) if String(spec["key"]) == "win_rate" else str(value)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_override("font", _font("CardTitle"))
		value_label.add_theme_font_size_override("font_size", 26)
		value_label.add_theme_color_override("font_color", _palette(String(spec["ink"])))
		box.add_child(value_label)
		var label := Label.new()
		label.name = "Label"
		label.text = UiStrings.t(String(spec["label_key"]))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", _palette("stat_muted"))
		box.add_child(label)
		_stats.add_child(box)


## `js/ui.js:1624-1640`: one row per objective (check, label, progress/target, the
## done-or-claimed category) or the reference's own empty line.
func _fill_objectives() -> void:
	for child in _objectives.get_children():
		_objectives.remove_child(child)
		child.queue_free()
	if _objective_rows.is_empty():
		var empty := Label.new()
		empty.name = EMPTY_NODE
		empty.text = UiStrings.t("profileNoObjectives")
		empty.add_theme_color_override("font_color", _palette("muted"))
		empty.add_theme_font_size_override("font_size", 13)
		_objectives.add_child(empty)
		return
	for index in _objective_rows.size():
		var row: Dictionary = _objective_rows[index]
		var done := bool(row.get("done", false))
		var line := HBoxContainer.new()
		line.name = "Objective%d" % index
		line.add_theme_constant_override("separation", 8)
		var check := Label.new()
		check.name = "Check"
		check.text = "✓" if done else "○"
		check.custom_minimum_size.x = 18.0
		check.add_theme_color_override("font_color", _palette("green") if done else _palette("muted"))
		line.add_child(check)
		var label := Label.new()
		label.name = "Label"
		label.text = UiStrings.t(String(row["label_key"]), {"n": int(row.get("target", 0))})
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if done:
			label.add_theme_color_override("font_color", _palette("ink"))
		else:
			label.add_theme_color_override("font_color", _alpha(_palette("white"), 0.72))
		line.add_child(label)
		var progress := Label.new()
		progress.name = "Progress"
		progress.text = "%d/%d" % [int(row.get("progress", 0)), int(row.get("target", 0))]
		if done:
			progress.add_theme_color_override("font_color", _palette("green"))
		else:
			progress.add_theme_color_override("font_color", _alpha(_palette("white"), 0.55))
		progress.add_theme_font_size_override("font_size", 12)
		line.add_child(progress)
		var cat := Label.new()
		cat.name = "Cat"
		cat.text = ""
		if done:
			cat.text = UiStrings.t("objDone")
		elif bool(row.get("claimed", false)):
			cat.text = UiStrings.t("objAlreadyClaimed")
		cat.add_theme_color_override("font_color", _palette("muted"))
		cat.add_theme_font_size_override("font_size", 10)
		line.add_child(cat)
		_objectives.add_child(_ruled(line, index))


## `js/ui.js:1652-1664`: the counted summary and the one button that leads to the
## board the count describes.
func _fill_unlocks() -> void:
	for child in _unlocks.get_children():
		_unlocks.remove_child(child)
		child.queue_free()
	var summary := PanelContainer.new()
	summary.name = "UnlockSummary"
	summary.add_theme_stylebox_override("panel", _summary_box())
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	var text := Label.new()
	text.name = "UnlockCount"
	text.text = UiStrings.t(String(_unlock_summary.get("label_key", "profileUnlocksCount")), {
		"done": int(_unlock_summary.get("done", 0)),
		"total": int(_unlock_summary.get("total", 0)),
	})
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("font_color", _palette("cyan"))
	line.add_child(text)
	var button := Button.new()
	button.name = UNLOCK_BUTTON_NODE
	button.theme_type_variation = &"ButtonSecondary"
	button.text = UiStrings.t("challenges")
	button.pressed.connect(func() -> void: route_action("to-challenges"))
	line.add_child(button)
	summary.add_child(line)
	_unlocks.add_child(summary)
	_shell.add_focus("unlocks-challenges", button, "to-challenges", {"kind": "button"})


# ---------------------------------------------------------------------------
# Boxes and inks
# ---------------------------------------------------------------------------

## `.history-stats__box` again (`styles.css:2645-2651`), the box the profile reuses.
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


## `.profile-objectives, .profile-unlocks` (`styles.css:1319-1325`).
func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("white"), 0.03)
	box.border_color = _palette("line")
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 14.0
	return box


## `.result-objectives__row` (`styles.css:1228-1235`): a `rgba(255,255,255,0.05)` rule
## above each row and 4 px of padding. The row carries the name the accessors walk to
## (`Objective%d`, whose `get_child(0)` is this line), and the box paints the rule ONLY: a
## `StyleBoxFlat` starts with `bg_color = Color(0.6, 0.6, 0.6)` and `draw_center = true`,
## so a rule that never assigned its fill painted an opaque grey slab behind every
## objective — the legibility audit's `bg=999999` on these labels was exactly that.
func _ruled(line: HBoxContainer, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Objective%d" % index
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = _alpha(_palette("white"), 0.05)
	box.border_width_top = 1
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(line)
	return panel


## `.profile-unlocks__summary` (`styles.css:3586-3596`): a cyan-tinted box.
func _summary_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _palette("summary_fill")
	box.border_color = _alpha(_palette("cyan"), 0.22)
	box.set_corner_radius_all(12)
	box.set_border_width_all(1)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	return box


func _font(role: String) -> Font:
	var source := theme if theme != null else DefaultTheme
	return source.get_font("font", role) if source.has_font("font", role) else null


## `repeat(auto-fit, minmax(130px, 1fr))` as a column count, never more than the four
## boxes and never wider than the frame.
func _apply_layout() -> void:
	if _stats == null or size.x <= 0.0:
		return
	var columns := int(max(1.0, floor((size.x - 32.0) / (STATS_MIN_WIDTH + STATS_GAP))))
	_stats.columns = min(columns, STAT_BOXES.size())


func _apply_aria() -> void:
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
