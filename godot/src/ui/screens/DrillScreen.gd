## DrillScreen.gd — `screen-drill`, the reference's own training page (`index.html:366-395`).
##
## WHAT THIS SCREEN IS. The exercise segmented control (four, the drill table's own
## ids), the difficulty control (four, the reference's own values), the four metric
## boxes, the court area and the instruction line. The header's subtitle and the
## instruction line are per-exercise and come from the drill table's own ids
## (`drill_<id>_desc`, `drill_<id>_hint` — `syncDrillChrome`, `js/main.js:1681-1690`).
##
## WHERE THE METRICS COME FROM. `DrillScoring.metrics()` — the same function the live
## drill calls every frame — asked of a drill created for the chosen exercise, with its
## `best` read from the save contract (`UiData.drill_records()` over `ModesSave`, the
## "write only on improvement" record of `save_store.gd::write_drill_record`). Nothing
## here scores, ranks or thresholds anything: a second copy of the drill's rules is the
## defect this ticket exists to avoid.
##
## WHAT THE PORT DECIDES, AND WHY. The reference starts a drill inside the same page
## (`to-drill` → `startDrill`), because its canvas *is* the court. The port plays the
## drill in the match scene, so this page is the setup step: the court area is the
## reference's own frame treatment (`#drillCanvas`: `1px var(--line)`, radius 12,
## `#0a1633` — `styles.css:1401-1407`) with the arena's name and one prominent start
## action. Starting sets the two fields the mode flow already reads
## (`Config.pending_mode`, `Config.pending_exercise`) and changes to `Match.tscn`; the
## payload is returned before the scene change so a test can assert it in-process
## (`start(true)`), and the engine is touched by two lines at the end.
##
## DIFFICULTY IS THIS SCREEN'S OWN STATE, and it stays that way: the reference keeps it
## in `ui.drillDifficulty`, which is not persisted (`collectPrefs`, `js/ui.js:422-442`,
## has no such key), seeded from the stored `aiDifficulty` (`js/main.js:2162`). Choosing
## a drill difficulty therefore writes nothing — and the port's mode flow does not read
## it yet, which the hand-back names as a seam for the integrator, not a change to make
## here.
##
## LITERALS. None: ids, keys and numbers only, and the separators a `GridContainer`
## needs are structural, not text.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const Config := preload("res://game/match_config.gd")
const ModeSession := preload("res://game/mode_session.gd")
const Gate := preload("res://game/content_gate.gd")

## `.mode-card--locked { opacity: 0.55 }` — the same presentation the mode cards use,
## applied to the start action when this build does not grant the drill.
const LOCKED_ALPHA := 0.55

const SCREEN_ID := "drill"

## The router's own row for this screen (`ScreenRouter.SCREENS[9]`).
const DECLARED_BACK := "menu"

const CAPTURE_STATES: Array[String] = ["default", "precision", "smash", "rally", "serve", "hard", "legend"]

## The scenario the mode flow loads (`godot/game/ModeScreen.tscn`'s own target).
const SCENE_PATH := "res://game/Match.tscn"

## `index.html:381-385`: the four difficulty values, in the reference's order.
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard", "legend"]
const DIFFICULTY_LABELS := {
	"easy": "diffEasy",
	"medium": "diffMedium",
	"hard": "diffHard",
	"legend": "diffLegend",
}
## `js/ui.js:469`: the pref the reference seeds the drill difficulty from.
const DIFFICULTY_SEED_KEY := "aiDifficulty"

## `styles.css:1381-1385`: the difficulty row is the same segmented control, quieter.
const DIFFICULTY_ALPHA := 0.86

const MAX_COLUMN := 560.0
const METRICS_COLUMNS := 4
const METRICS_MIN_CELL := 120.0
const METRIC_BOXES := 4

var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted = null
var _built := false
var _exercise := ""
var _difficulty := ""
var _drills: Dictionary = {}
var _exercise_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _metric_boxes: Array = []
var _metrics_grid: GridContainer = null
## Re-entrancy guard for the `resized` handlers: setting a theme-constant override from
## inside the layout pass can re-enter this handler synchronously, and an unguarded
## write loop there is a stack overflow (found by the engine, not the static pass).
var _applying_width := false


func _ready() -> void:
	_ensure()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


## The router mounted this page: the reference syncs the chrome and starts nothing
## (`js/main.js:2214-2217` is the feedback case; `to-drill` starts a drill there, and
## the port's decision moves that to the start action — see this file's header).
func enter(payload: Dictionary) -> void:
	_ensure()
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", DECLARED_BACK))
	_shell.set_back_target(back_target_id)
	# A record written by the session the player just left has to show: the preview
	# drills are rebuilt and the values re-read on every entry.
	_drills.clear()
	refresh_metrics()
	refresh_strings()


func exit() -> void:
	pass


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## The four exercises and the two difficulty pins a capture may ask for; anything else
## is not declared and answers false.
func apply_capture_state(state_id: String) -> bool:
	_ensure()
	if state_id == "default":
		select_difficulty(seed_difficulty())
		select_exercise(first_exercise_id())
		return true
	match state_id:
		"precision":
			return select_exercise("precision")
		"smash":
			return select_exercise("smash")
		"rally":
			return select_exercise("rally")
		"serve":
			return select_exercise("serve")
		"hard":
			return select_difficulty("hard")
		"legend":
			return select_difficulty("legend")
	return false


# ---------------------------------------------------------------------------
# The table (read-only: the frozen drill table owns the exercises)
# ---------------------------------------------------------------------------

func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


func set_store(store_in: RefCounted) -> void:
	_store = store_in
	_drills.clear()
	if _built:
		refresh_metrics()


func exercise_rows() -> Array:
	return Tables.drill_exercises()


func first_exercise_id() -> String:
	var rows := exercise_rows()
	return String((rows[0] as Dictionary).get("id", "")) if not rows.is_empty() else ""


func exercise() -> String:
	return _exercise


func exercise_name_key() -> String:
	return "drill_%s_name" % _exercise


func exercise_desc_key() -> String:
	return "drill_%s_desc" % _exercise


func exercise_hint_key() -> String:
	return "drill_%s_hint" % _exercise


func select_exercise(id: String) -> bool:
	var known := false
	for row in exercise_rows():
		if String((row as Dictionary).get("id", "")) == id:
			known = true
	if not known:
		return false
	_exercise = id
	_refresh_segments()
	refresh_metrics()
	refresh_strings()
	return true


func difficulty() -> String:
	return _difficulty


func difficulty_rows() -> Array:
	var out: Array = []
	for id in DIFFICULTIES:
		out.append({"id": id, "label_key": String(DIFFICULTY_LABELS[id])})
	return out


## The reference's seed: the stored `aiDifficulty` when it is one of the four, else the
## first value on the list (`js/main.js:2162`).
func seed_difficulty() -> String:
	if not _built:
		return DIFFICULTIES[0]
	var snap := UiData.settings_snapshot(store())
	var stored := String(snap.get("ai_difficulty", ""))
	return stored if DIFFICULTIES.has(stored) else DIFFICULTIES[0]


## Changing the drill difficulty writes nothing (`ui.drillDifficulty` is not persisted):
## the pref the screen was seeded from is left exactly as it was.
func select_difficulty(id: String) -> bool:
	if not DIFFICULTIES.has(id):
		return false
	_difficulty = id
	_refresh_segments()
	return true


# ---------------------------------------------------------------------------
# The metric boxes (`drillMetrics(drill)`, `js/drill.js:440-470`)
# ---------------------------------------------------------------------------

## The records the boxes read their `best` from — the same reader the drill session
## writes through (`ModesSave.save_drill_score` → `write_drill_record`).
func records() -> Dictionary:
	return UiData.drill_records(store())


func record_for(id: String) -> int:
	for row in (records().get("rows", []) as Array):
		if String((row as Dictionary).get("id", "")) == id:
			return int((row as Dictionary).get("best", 0))
	return 0


## The live metric rows for the chosen exercise: `{key, label, value}` per box, in the
## order the scoring module produces them. The values are a fresh drill's own — the
## reference shows `0` before a drill starts — with `best` seeded from the stored record.
func metric_rows() -> Array:
	var drill = _drill_for(_exercise)
	if drill == null:
		return []
	drill.best = record_for(_exercise)
	var out: Array = []
	for metric in DrillScoring.metrics(drill):
		var row: Dictionary = metric
		out.append({
			"key": String(row.get("key", "")),
			"label": UiStrings.t(String(row.get("key", ""))),
			"value": String(row.get("value", "")),
		})
	return out


## What the four boxes actually show, label and value, read back from the scene — what
## the audit compares instead of the function it is checking.
func shown_metric_rows() -> Array:
	var out: Array = []
	for index in _metric_boxes.size():
		var box := _metric_boxes[index] as Control
		var label := box.find_child("MetricLabel%d" % index, true, false) as Label
		var value := box.find_child("MetricValue%d" % index, true, false) as Label
		out.append({
			"label": label.text if label != null else "",
			"value": value.text if value != null else "",
		})
	return out


func refresh_metrics() -> void:
	_ensure()
	var rows := metric_rows()
	for index in _metric_boxes.size():
		var box := _metric_boxes[index] as Control
		var label := box.find_child("MetricLabel%d" % index, true, false) as Label
		var value := box.find_child("MetricValue%d" % index, true, false) as Label
		if label == null or value == null:
			continue
		if index < rows.size():
			label.text = String((rows[index] as Dictionary)["label"])
			value.text = String((rows[index] as Dictionary)["value"])
		else:
			label.text = ""
			value.text = ""


## One preview drill per exercise, created through the frozen module and reused until
## the screen is entered again. Creating one builds a match state; it never steps it,
## so nothing here simulates a match.
func _drill_for(id: String) -> Variant:
	if id == "":
		return null
	if _drills.has(id):
		return _drills[id]
	var drill = DrillSession.create(String(id), Config.athlete(), Config.arena(), Config.tier(), {"seed": 0})
	_drills[id] = drill
	return drill


# ---------------------------------------------------------------------------
# Start (the port's own decision: the drill plays in the match scene)
# ---------------------------------------------------------------------------

## The renderer the flow uses and the two fields it reads, then the scene change.
## `dry_run` stops before the engine call so an audit can assert the payload in-process.
##
## The demo/scope gate is asked FIRST (`ModeSession.can_start`, the same source of
## truth `game/mode_screen.gd::start_mode` asks): a build that does not grant `drill`
## refuses it here, visibly — no config write and no scene change — instead of letting
## the mode flow substitute another mode after the fact (review F8: the controller used
## to answer `MODE_REFUSED` and silently open a quick match).
func start(dry_run := false) -> Dictionary:
	var payload := start_payload()
	payload["dry_run"] = dry_run
	payload["started"] = granted()
	if not payload["started"]:
		payload["reason"] = refusal()
		payload["scene"] = ""
		return payload
	Config.pending_mode = "drill"
	Config.pending_exercise = _exercise
	if not dry_run:
		get_tree().change_scene_to_file(SCENE_PATH)
	return payload


## Whether this build grants the drill. The reference locks only `.mode-card`s and
## keeps the drill entry as a header button, but the port plays the drill in the match
## scene, so the gate must be asked here too.
func granted() -> bool:
	return ModeSession.can_start(SCREEN_ID)


## The refusal sentence; "" while the mode is granted (`ModeSession.refusal`).
func refusal() -> String:
	return ModeSession.refusal(SCREEN_ID)


## What `start()` hands the flow, without touching the tree or the config: the mode,
## the exercise, the difficulty and the scene. The two `Config` writes moved into
## `start()`, after the gate, so a refused press leaves no seam behind.
func start_payload() -> Dictionary:
	return {
		"mode": "drill",
		"exercise": _exercise,
		"difficulty": _difficulty,
		"scene": SCENE_PATH,
	}


# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------

func refresh_strings() -> void:
	_ensure()
	_shell.set_title("drillTitle")
	_shell.set_subtitle(exercise_desc_key())
	(_control("Hint") as Label).text = UiStrings.t(exercise_hint_key())
	(_control("StartButton") as Button).text = UiStrings.t("training")
	(_control("CourtCaption") as Label).text = UiStrings.t(arena_name_key())
	_apply_gate()
	for id in _exercise_buttons:
		(_exercise_buttons[id] as Button).text = UiStrings.t("drill_%s_name" % id)
	for id in _difficulty_buttons:
		(_difficulty_buttons[id] as Button).text = UiStrings.t(String(DIFFICULTY_LABELS[id]))
	(_metrics_grid as Control).tooltip_text = UiStrings.t("drillExercise")
	_refresh_segments()


func arena_name_key() -> String:
	return "arena_%s_name" % String((Config.arena() as Dictionary).get("id", ""))


# ---------------------------------------------------------------------------
# The page
# ---------------------------------------------------------------------------

func _ensure() -> void:
	if _built:
		return
	_built = true
	_shell = $Shell
	_shell.setup(SCREEN_ID)
	_shell.set_back_target(DECLARED_BACK)
	_exercise = first_exercise_id()
	_build()
	_difficulty = seed_difficulty()
	refresh_metrics()
	refresh_strings()


func _build() -> void:
	var column := _centered_column()
	column.add_child(_segment("ExerciseSeg", "drillExercise", exercise_rows(), "Exercise_%s", "drill_%s_name", _exercise_buttons, select_exercise))
	var difficulty_seg := _segment("DifficultySeg", "difficulty", difficulty_rows(), "Difficulty_%s", "", _difficulty_buttons, select_difficulty)
	difficulty_seg.modulate.a = DIFFICULTY_ALPHA
	column.add_child(difficulty_seg)
	column.add_child(_metrics())
	column.add_child(_court_frame())
	_label(column, "Hint")
	_register_focus()
	resized.connect(_apply_metrics_columns)


func _centered_column() -> VBoxContainer:
	var content: MarginContainer = _shell.content()
	var centering := MarginContainer.new()
	centering.name = "Centering"
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centering.set_meta("max_width", MAX_COLUMN)
	content.add_child(centering)
	var column := VBoxContainer.new()
	column.name = "DrillColumn"
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 16)
	centering.add_child(column)
	centering.resized.connect(_apply_column_width.bind(centering, column))
	_apply_column_width(centering, column)
	return column


func _apply_column_width(centering: MarginContainer, column: VBoxContainer) -> void:
	if _applying_width:
		return
	_applying_width = true
	var max_width := float(centering.get_meta("max_width", 0.0))
	# The column centres itself (`SIZE_SHRINK_CENTER`) instead of the centering carrying
	# side margins: margins are part of a container's own minimum size, so a width the
	# screen once had could never be given back and the shell stayed wider than its frame.
	var available := centering.get_parent_area_size().x
	var want_min := minf(max_width, available)
	if not is_equal_approx(column.custom_minimum_size.x, want_min):
		column.custom_minimum_size.x = want_min
	_applying_width = false


## One segmented control. `label_pattern` is `""` for rows whose labels come from the
## difficulty table instead of `drill_<id>_name`.
func _segment(node_name: String, aria_key: String, rows: Array, name_pattern: String, label_pattern: String, registry: Dictionary, handler: Callable) -> HBoxContainer:
	var seg := HBoxContainer.new()
	seg.name = node_name
	seg.add_theme_constant_override("separation", 0)
	seg.tooltip_text = UiStrings.t(aria_key)
	seg.alignment = BoxContainer.ALIGNMENT_CENTER
	for row in rows:
		var id := String((row as Dictionary).get("id", ""))
		var button := Button.new()
		button.name = name_pattern % id
		button.toggle_mode = true
		button.pressed.connect(handler.bind(id))
		seg.add_child(button)
		registry[id] = button
	return seg


## The four boxes (`styles.css:1370-1383`): border `--line`, radius 10, over
## `rgba(255,255,255,0.03)`, a muted caption and a bright figure.
func _metrics() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Metrics"
	grid.columns = METRICS_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_metrics_grid = grid
	var theme: Theme = self.theme
	for index in METRIC_BOXES:
		var box := VBoxContainer.new()
		box.name = "MetricBox%d" % index
		var label := Label.new()
		label.name = "MetricLabel%d" % index
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		var value := Label.new()
		value.name = "MetricValue%d" % index
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(value)
		if theme != null:
			value.add_theme_font_override("font", theme.get_font("font", "HeroTitle"))
			value.add_theme_font_size_override("font_size", 22)
			value.add_theme_color_override("font_color", theme.get_color("cyan", "Palette"))
			label.modulate.a = 0.62
		var panel := PanelContainer.new()
		panel.name = "MetricPanel%d" % index
		panel.add_theme_stylebox_override("panel", _metric_box_style())
		panel.add_child(box)
		grid.add_child(panel)
		_metric_boxes.append(box)
	return grid


## `#drillCanvas` (`styles.css:1401-1407`): the frame treatment the port keeps while the
## court itself lives in the match scene.
func _metric_box_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var theme: Theme = self.theme
	if theme == null:
		return box
	box.bg_color = _alpha(theme.get_color("ink", "Palette"), 0.03)
	box.border_color = theme.get_color("line", "Palette")
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


func _court_frame() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CourtFrame"
	panel.custom_minimum_size = Vector2(0.0, 240.0)
	panel.add_theme_stylebox_override("panel", _court_style())
	var inner := VBoxContainer.new()
	inner.name = "CourtInner"
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 12)
	panel.add_child(inner)
	_label(inner, "CourtCaption")
	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(start)
	inner.add_child(start_button)
	return panel


## The gate's own presentation, read off `granted()`: a refused build dims and
## disables the start action and swaps the caption for the lock tag key the mode cards
## use (`Gate.locked_key`). A granted build leaves both alone.
func _apply_gate() -> void:
	var ok := granted()
	var start_button := _control("StartButton") as Button
	if start_button != null:
		start_button.disabled = not ok
		start_button.modulate = Color(1, 1, 1, 1) if ok else Color(1, 1, 1, LOCKED_ALPHA)
		start_button.tooltip_text = "" if ok else refusal()
	var caption := _control("CourtCaption") as Label
	if caption != null and not ok:
		caption.text = UiStrings.t(Gate.locked_key())


func _court_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var theme: Theme = self.theme
	if theme == null:
		return box
	box.bg_color = theme.get_color("panel", "Palette")
	box.border_color = theme.get_color("line", "Palette")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	return box


func _label(parent: Node, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _refresh_segments() -> void:
	for id in _exercise_buttons:
		_style_segment(_exercise_buttons[id] as Button, String(id) == _exercise)
	for id in _difficulty_buttons:
		_style_segment(_difficulty_buttons[id] as Button, String(id) == _difficulty)


func _style_segment(button: Button, active: bool) -> void:
	if button == null:
		return
	button.set_pressed_no_signal(active)
	var theme: Theme = self.theme
	if theme == null:
		return
	var variation := "SegmentedActive" if active else "SegmentedInactive"
	button.add_theme_stylebox_override("normal", theme.get_stylebox("normal", variation))
	button.add_theme_stylebox_override("hover", theme.get_stylebox("hover", variation))
	button.add_theme_stylebox_override("pressed", theme.get_stylebox("pressed", variation))
	button.add_theme_stylebox_override("focus", theme.get_stylebox("normal", variation))
	button.add_theme_font_override("font", theme.get_font("font", variation))
	button.add_theme_font_size_override("font_size", theme.get_font_size("font_size", variation))
	for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(String(slot), theme.get_color(String(slot), variation))


## `repeat(auto-fit, minmax(120px, 1fr))`: four boxes at the design frame, two when the
## frame is narrower than three cells.
func _apply_metrics_columns() -> void:
	if _metrics_grid == null:
		return
	var width := size.x
	if width <= 0.0:
		width = 1280.0
	_metrics_grid.columns = maxi(2, mini(METRICS_COLUMNS, int(width / (METRICS_MIN_CELL * 3.0))))


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out


# ---------------------------------------------------------------------------
# Focus
# ---------------------------------------------------------------------------

func _register_focus() -> void:
	for id in _exercise_buttons:
		_shell.add_focus("Exercise_%s" % id, _exercise_buttons[id], "exercise:%s" % id, {"kind": "button"})
	for id in _difficulty_buttons:
		_shell.add_focus("Difficulty_%s" % id, _difficulty_buttons[id], "difficulty:%s" % id, {"kind": "button"})
	_shell.add_focus("StartButton", _control("StartButton"), "start", {"kind": "button"})


func focus_controls() -> Array:
	_ensure()
	return _shell.focus_controls()


func focus_id(suffix: String) -> String:
	_ensure()
	return _shell.focus_id(suffix)


func _control(node_name: String) -> Control:
	return find_child(node_name, true, false) as Control
