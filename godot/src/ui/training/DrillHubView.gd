## DrillHubView.gd — the TRAINING HUB, body only: the three exercise families, the compact
## cards, the detail panel and the start action, all read from `drill_hub.gd`.
##
## WHY ONE VIEW FOR TWO HOSTS. The training hub is reachable through two routes — the
## recreated `godot/src/ui/screens/DrillScreen.gd` (the default `--ui=new` path, mounted by
## the router) and the ported drill branch of `godot/game/mode_screen.gd` (the `--ui=legacy`
## path and the mode harness). Both must offer the same eight exercises with the same words,
## the same grouping and the same selection; two independent layouts would be two places for
## that to drift. This view is the body they share, and each host keeps its OWN shell,
## header, back control and focus model — it mounts the view and delegates.
##
## THE VIEW DECIDES NOTHING ABOUT THE GAME. It asks `DrillHub` for the catalog, the groups
## and the detail (goal, success rule, what scores, controls, records, run length) and emits
## four signals. Starting, saving, scoring and routeing belong to the host and to the mode
## session, exactly as before.
##
## SIGNALS
##   exercise_selected(id)         the player chose a card (mouse or confirm)
##   start_requested(id)           the player asked to play the selected exercise
##   back_requested()              the host's own declared return was asked for
##   difficulty_changed(diff)      the training difficulty row moved (nothing is persisted)
##
## PUBLIC API (what a host and its audit read)
##   setup(store, difficulty, lang) / refresh()
##   exercise_ids(), selected_exercise(), select_exercise(id) -> bool
##   difficulty(), select_difficulty(id) -> bool
##   detail() -> Dictionary            `DrillHub.detail` for the selection, rendered
##   card_button(id) -> Button         the card, for a test that measures or clicks it
##   focus_rows() -> Array             `{id, control, action}` for the host's focus model
##   report() -> Dictionary            what is on screen, as data
##
## IT IS A CONTAINER ON PURPOSE. The view is mounted inside a host's own layout, and a plain
## `Control` does not lay its children out: the body would keep its minimum rectangle and the
## detail column would be squeezed into whatever the labels happened to need. A
## `MarginContainer` (zero margins) fits its one child to the rectangle the host gives it,
## which is exactly the contract this view needs.
extends MarginContainer

const Hub := preload("res://src/modes/drill_hub.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const Locale := preload("res://src/locale/locale.gd")

signal exercise_selected(exercise_id: String)
signal start_requested(exercise_id: String)
signal back_requested()
signal difficulty_changed(difficulty: String)

## Compact cards: tall enough for a 15 px name, and no taller. The detail column carries the
## prose, so a card only has to be scannable.
const CARD_HEIGHT := 46.0
const CARD_FONT := 15
const LIST_WIDTH := 340.0
## The theme variations the shipping theme already carries (`padel_theme.tres`): the page
## adds no style of its own, so the hub looks like the rest of the recreated UI in both
## hosts.
const CARD_ACTIVE := "SegmentedActive"
const CARD_IDLE := "SegmentedInactive"
const PANEL_VARIATION := "PanelDark"
const TITLE_VARIATION := "CardTitle"
const SMALL_VARIATION := "LabelSmall"
const START_VARIATION := "ButtonPrimary"

var _store: RefCounted = null
var _difficulty := ""
var _selected := ""
var _cards: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _group_labels: Dictionary = {}
var _group: ButtonGroup = null
var _built := false

# The detail panel's own labels, kept so `refresh()` writes in place.
var _name_label: Label
var _goal_label: Label
var _success_label: Label
var _scores_label: Label
var _controls_label: Label
var _record_label: Label
var _run_label: Label
var _start_button: Button


## Builds the body. `store` is the save the records are read from (the host's own store);
## `difficulty` seeds the difficulty row; `lang` is empty for "the current locale".
func setup(store, difficulty: String = "", lang: String = "") -> void:
	_store = store
	_difficulty = Hub.seed_difficulty(difficulty)
	if not _built:
		_build(lang)
	refresh()


func refresh() -> void:
	if not _built:
		return
	# THE WORDS MOVE WITH THE LANGUAGE. Every card's name, the difficulty row's labels, the
	# family headings and the start action are re-resolved on every refresh, so a locale flip
	# through the screen's own `refresh_strings()` moves the page without a remount.
	for id in _cards:
		var card := Hub.card(String(id))
		(_cards[id] as Button).text = String(card.get("name", String(id)))
		(_cards[id] as Button).tooltip_text = String(card.get("goal", ""))
	for id in _difficulty_buttons:
		(_difficulty_buttons[id] as Button).text = Hub.difficulty_label(String(id))
	for group in Hub.groups():
		var group_id := String((group as Dictionary).get("id", ""))
		if _group_labels.has(group_id):
			(_group_labels[group_id] as Label).text = String((group as Dictionary).get("label", ""))
	if _start_button != null:
		_start_button.text = DrillText.t("playNow")
	var ids := exercise_ids()
	if _selected == "" or not ids.has(_selected):
		_selected = Hub.first_id()
	_style_cards()
	var entry := detail()
	if _name_label != null:
		_name_label.text = String(entry.get("name", ""))
	if _goal_label != null:
		_goal_label.text = "%s  %s" % [DrillText.t("drillHubGoal"), String(entry.get("goal", ""))]
	if _success_label != null:
		_success_label.text = "%s  %s" % [DrillText.t("drillHubSuccess"), String(entry.get("success", ""))]
	if _scores_label != null:
		_scores_label.text = "%s  %s" % [DrillText.t("drillHubScores"), String(entry.get("scores", ""))]
	if _controls_label != null:
		var parts: Array = []
		for control in entry.get("controls", []):
			parts.append(String((control as Dictionary).get("text", "")))
		_controls_label.text = "%s  %s" % [DrillText.t("drillHubControls"), "     ".join(parts)]
	if _record_label != null:
		_record_label.text = "%s %d     %s %d" % [
			DrillText.t("drillHubBest"), int(entry.get("best", 0)),
			DrillText.t("drillHubHistoricalBest"), int(entry.get("historical_best", 0)),
		]
	if _run_label != null:
		_run_label.text = "%s: %s" % [
			DrillText.t("drillHubAttempts"),
			DrillText.t("drillHubRun", {"attempts": int(entry.get("attempts", 0))}),
		]
	if _start_button != null:
		_start_button.disabled = _selected == ""
	for id in _difficulty_buttons:
		_style_difficulty(_difficulty_buttons[id] as Button, String(id) == _difficulty)


# ---------------------------------------------------------------------------
# The table the view offers
# ---------------------------------------------------------------------------

func exercise_ids() -> Array[String]:
	return Hub.exercise_ids()


func selected_exercise() -> String:
	return _selected


## Makes one exercise the selection. False for an id the catalog does not carry: a choice
## this view cannot play is refused rather than silently falling back.
func select_exercise(exercise_id: String) -> bool:
	if not Hub.has(exercise_id):
		return false
	_selected = exercise_id
	refresh()
	exercise_selected.emit(exercise_id)
	return true


func difficulty() -> String:
	return _difficulty


## Moves the difficulty row. Nothing is written: the reference keeps `ui.drillDifficulty` in
## memory (`js/ui.js:422-442` has no such key), and the host carries it to the match through
## `Config.pending_drill_difficulty`.
func select_difficulty(difficulty_id: String) -> bool:
	if not Hub.difficulties().has(difficulty_id):
		return false
	_difficulty = difficulty_id
	refresh()
	difficulty_changed.emit(difficulty_id)
	return true


## The detail panel's model, rendered: `DrillHub.detail` for the selection plus the resolved
## difficulty label. The audit compares the panel's own labels against this.
func detail() -> Dictionary:
	var out := Hub.detail(_selected, _store, _difficulty)
	out["difficulty_label"] = Hub.difficulty_label(_difficulty)
	return out


## The card for one exercise, for a test's measurement and clicks. Null when the catalog
## does not carry it.
func card_button(exercise_id: String) -> Button:
	return _cards.get(exercise_id, null) as Button


## What the host's focus model registers: one row per card, one per difficulty, one for the
## start action. `action` is the id the host's dispatcher understands
## (`exercise:<id>`, `difficulty:<id>`, `start`).
func focus_rows() -> Array:
	var out: Array = []
	for id in _cards:
		out.append({"id": "exercise:%s" % String(id), "control": _cards[id], "action": "exercise:%s" % String(id)})
	for id in _difficulty_buttons:
		out.append({"id": "difficulty:%s" % String(id), "control": _difficulty_buttons[id], "action": "difficulty:%s" % String(id)})
	if _start_button != null:
		out.append({"id": "start", "control": _start_button, "action": "start"})
	return out


## What the host hands the mode flow when the player starts.
func start_payload() -> Dictionary:
	return {"mode": "drill", "exercise": _selected, "difficulty": _difficulty}


## The body as data: the groups with their cards' ids and names, the selection, the detail
## strings actually painted, and the difficulty. A test reads THIS rather than the table it
## is checking.
func report() -> Dictionary:
	var groups: Array = []
	for group in Hub.groups():
		var ids: Array = []
		for card in (group as Dictionary).get("cards", []):
			ids.append(String((card as Dictionary).get("id", "")))
		groups.append({
			"id": String((group as Dictionary).get("id", "")),
			"label": String((group as Dictionary).get("label", "")),
			"ids": ids,
		})
	return {
		"selected": _selected,
		"difficulty": _difficulty,
		"difficulty_label": Hub.difficulty_label(_difficulty),
		"groups": groups,
		"name": _name_label.text if _name_label != null else "",
		"goal": _goal_label.text if _goal_label != null else "",
		"success": _success_label.text if _success_label != null else "",
		"scores": _scores_label.text if _scores_label != null else "",
		"controls": _controls_label.text if _controls_label != null else "",
		"record": _record_label.text if _record_label != null else "",
		"run": _run_label.text if _run_label != null else "",
		"start_text": _start_button.text if _start_button != null else "",
		"detail": detail(),
	}


# ---------------------------------------------------------------------------
# The body
# ---------------------------------------------------------------------------

func _build(lang: String) -> void:
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_group = ButtonGroup.new()
	var body := HBoxContainer.new()
	body.name = "HubBody"
	body.add_theme_constant_override("separation", 24)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_build_list(body, lang)
	_build_detail(body)


## Left: the three families, each a heading and its compact cards, in `DrillHub.groups()`
## order.
func _build_list(parent: Container, lang: String) -> void:
	var left := VBoxContainer.new()
	left.name = "HubListColumn"
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(left)
	for group in Hub.groups(lang):
		var group_id := String((group as Dictionary).get("id", ""))
		var heading := _label(String((group as Dictionary).get("label", "")), 13, Color(1.0, 0.831, 0.4))
		heading.name = "HubGroup_%s" % group_id
		heading.theme_type_variation = SMALL_VARIATION
		left.add_child(heading)
		_group_labels[group_id] = heading
		var box := PanelContainer.new()
		box.name = "HubGroupBox_%s" % group_id
		box.theme_type_variation = "SegmentedContainer"
		left.add_child(box)
		var list := VBoxContainer.new()
		list.name = "HubGroupList_%s" % group_id
		list.add_theme_constant_override("separation", 3)
		box.add_child(list)
		for card in (group as Dictionary).get("cards", []):
			_make_card(list, String((card as Dictionary).get("id", "")))


## One compact card: the exercise's own name, with its goal as the tooltip — the detail panel
## carries the prose.
func _make_card(list: VBoxContainer, exercise_id: String) -> void:
	var entry := Hub.card(exercise_id)
	var button := Button.new()
	button.name = "HubCard_%s" % exercise_id
	button.text = String(entry.get("name", exercise_id))
	button.tooltip_text = String(entry.get("goal", ""))
	button.toggle_mode = true
	button.button_group = _group
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", CARD_FONT)
	button.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_card_pressed.bind(exercise_id))
	list.add_child(button)
	_cards[exercise_id] = button


func _on_card_pressed(exercise_id: String) -> void:
	# The mouse route and the host's confirm both land in `select_exercise`, so the two
	# cannot disagree about what is selected.
	if _selected == exercise_id:
		_style_cards()
		return
	select_exercise(exercise_id)


## Right: the chosen exercise's own panel — goal, success rule, what scores, controls, both
## records and the run length — with the difficulty row and the one start action under it.
func _build_detail(parent: Container) -> void:
	var right := VBoxContainer.new()
	right.name = "HubDetailColumn"
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(right)
	var panel := PanelContainer.new()
	panel.name = "HubDetailPanel"
	panel.theme_type_variation = PANEL_VARIATION
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(panel)
	var info := VBoxContainer.new()
	info.name = "HubDetail"
	info.add_theme_constant_override("separation", 8)
	panel.add_child(info)
	_name_label = _label("", 22, Color(0.0, 0.898, 1.0))
	_name_label.name = "HubName"
	_name_label.theme_type_variation = TITLE_VARIATION
	info.add_child(_name_label)
	_goal_label = _section(info, "HubGoal", 15, Color(0.80, 0.86, 0.92))
	_success_label = _section(info, "HubSuccess", 14, Color(0.55, 0.95, 0.72))
	_scores_label = _section(info, "HubScores", 14, Color(0.72, 0.78, 0.86))
	_controls_label = _section(info, "HubControls", 14, Color(0.68, 0.90, 0.98))
	_record_label = _section(info, "HubRecord", 15, Color(1.0, 0.8, 0.0))
	_run_label = _section(info, "HubRun", 13, Color(0.72, 0.78, 0.86))
	_record_label.theme_type_variation = SMALL_VARIATION
	_run_label.theme_type_variation = SMALL_VARIATION
	var spacer := Control.new()
	spacer.name = "HubSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	right.add_child(_difficulty_row())
	_start_button = Button.new()
	_start_button.name = "HubStart"
	_start_button.text = DrillText.t("playNow")
	_start_button.theme_type_variation = START_VARIATION
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.custom_minimum_size = Vector2(0.0, 50.0)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(func() -> void: start_requested.emit(_selected))
	right.add_child(_start_button)


## The difficulty row: the reference's own four values, as a quiet segmented control. The
## label names what the choice changes (the run's AI), because the reference's own comment
## left it unlabelled and unwired.
func _difficulty_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "HubDifficultyRow"
	row.add_theme_constant_override("separation", 6)
	var label := _label(DrillText.t("drillHubDifficulty"), 13, Color(0.72, 0.78, 0.86))
	label.name = "HubDifficultyLabel"
	label.theme_type_variation = SMALL_VARIATION
	# The captions that must keep their own width turn wrapping OFF: a wrapping label reports a
	# one-character minimum, and an HBox with expanding buttons beside it squeezed "Difficulty"
	# into a vertical stack of letters.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	for id in Hub.difficulties():
		var button := Button.new()
		button.name = "HubDifficulty_%s" % id
		button.text = Hub.difficulty_label(id)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 13)
		button.custom_minimum_size = Vector2(0.0, 30.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_difficulty_pressed.bind(id))
		row.add_child(button)
		_difficulty_buttons[id] = button
	return row


func _on_difficulty_pressed(difficulty_id: String) -> void:
	if _difficulty == difficulty_id:
		_style_difficulty(_difficulty_buttons[difficulty_id] as Button, true)
		return
	select_difficulty(difficulty_id)


func _style_cards() -> void:
	for id in _cards:
		var button := _cards[id] as Button
		var active: bool = String(id) == _selected
		button.set_pressed_no_signal(active)
		_apply_segment(button, active)


func _style_difficulty(button: Button, active: bool) -> void:
	if button == null:
		return
	button.set_pressed_no_signal(active)
	_apply_segment(button, active)


## One segmented control's state, using the theme's OWN two variations for their colours and
## radii, with the active variation's drop shadow removed. `BoxSegmentedActive` carries
## `shadow_size = 16` (`padel_theme.tres:188`), and a stylebox's shadow is part of its
## minimum size: selected cards and the selected difficulty were therefore TALLER than their
## neighbours and the whole column re-measured itself whenever the choice moved. Zeroing the
## shadow on a per-control copy keeps the theme's look and a stable, uniform height.
func _apply_segment(button: Button, active: bool) -> void:
	var variation := CARD_ACTIVE if active else CARD_IDLE
	button.theme_type_variation = variation
	for slot in ["normal", "hover", "pressed", "focus"]:
		var box := button.get_theme_stylebox(slot, variation)
		if box is StyleBoxFlat:
			var flat := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.shadow_size = 0
			button.add_theme_stylebox_override(slot, flat)


## One labelled line of the detail panel. The caption is part of the label's own text, so the
## rows the player reads are the rows the audit reads back.
func _section(parent: Container, node_name: String, size: int, color: Color) -> Label:
	var label := _label("", size, color)
	label.name = node_name
	parent.add_child(label)
	return label


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
