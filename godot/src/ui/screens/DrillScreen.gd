## DrillScreen.gd — `screen-drill`, the reference's own training page (`index.html:366-395`),
## rebuilt as the TRAINING HUB.
##
## WHAT THIS SCREEN IS NOW. The eight exercises the build can actually play — the frozen
## reference's four (`js/drill.js:53-71`), the Jev coach's `return` and the training
## overhaul's three challenges — grouped into Technique / Defence / Match play, with a detail
## panel that says what each one asks for: the goal, the measurable success rule, what is
## scored, the controls that matter, both records and how long a run lasts. The BODY is the
## shared `godot/src/ui/training/DrillHubView.gd`, the same view the ported drill branch of
## `godot/game/mode_screen.gd` mounts, so the two routes cannot describe an exercise
## differently.
##
## WHERE THE FACTS COME FROM. `godot/src/modes/drill_hub.gd` (catalog + objectives + records)
## and `drill_text.gd` (the reference's generated strings for its own four, this build's
## `drill_strings.json` for the rest). Nothing here scores, ranks or thresholds anything.
##
## WHAT THIS SCREEN STILL OWNS. The shell (`ScreenShell`: title, subtitle, hint, back), the
## focus registration, and the start route — the reference starts a drill inside the same page
## (`to-drill` -> `startDrill`) because its canvas *is* the court, and the port plays the drill
## in the match scene instead, so this page is the setup step. `start()` writes the seams the
## mode flow reads (`Config.pending_mode`, `pending_exercise`, `pending_drill_difficulty`) plus
## the return route, then changes scene; the payload is returned first so a test can assert it
## in-process (`start(true)`).
##
## DIFFICULTY IS TRANSIENT, AND NOW WIRED. The reference keeps `ui.drillDifficulty` in memory
## (`collectPrefs`, `js/ui.js:422-442`, has no such key), seeded from the stored `aiDifficulty`
## (`js/main.js:2162`): choosing one here writes no preference and never touches the global
## match difficulty. The choice reaches the run through `Config.pending_drill_difficulty`,
## which `game/mode_session.gd` resolves into the run's AI profile (`DrillHub.ai_profile`) —
## so the row is no longer a control that does nothing.
##
## LITERALS. None: ids, keys and numbers only, and the separators a container needs are
## structural, not text.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const DrillScoring := preload("res://src/modes/drill_scoring.gd")
const DrillHub := preload("res://src/modes/drill_hub.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const HubView := preload("res://src/ui/training/DrillHubView.gd")
const Config := preload("res://game/match_config.gd")
const ModeSession := preload("res://game/mode_session.gd")
const Gate := preload("res://game/content_gate.gd")

## `.mode-card--locked { opacity: 0.55 }` — the same presentation the mode cards use, applied
## to the start action when this build does not grant the drill.
const LOCKED_ALPHA := 0.55

const SCREEN_ID := "drill"

## The router's own row for this screen (`ScreenRouter.SCREENS[9]`).
const DECLARED_BACK := "menu"

## The declared capture states: the default view plus the two difficulty pins. Every exercise
## the catalog carries is ALSO a state, accepted at `apply_capture_state` time from the table
## rather than listed here, so a new exercise arrives with its own pin.
const CAPTURE_STATES: Array[String] = ["default", "hard", "legend"]

## The scenario the mode flow loads (`godot/game/ModeScreen.tscn`'s own target).
const SCENE_PATH := "res://game/Match.tscn"

## `js/ui.js:469`: the pref the reference seeds the drill difficulty from (read-only here).
const DIFFICULTY_SEED_KEY := "aiDifficulty"

const MAX_COLUMN := 1180.0

var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted = null
var _built := false
var _hub: Control = null
var _hint: Label = null
var _previews: Dictionary = {}


func _ready() -> void:
	_ensure()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


## The router mounted this page: the hub is refreshed so a record written by the run the
## player just left shows (the records are read from the save on every refresh).
func enter(payload: Dictionary) -> void:
	_ensure()
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", DECLARED_BACK))
	_shell.set_back_target(back_target_id)
	_previews.clear()
	refresh_strings()


func exit() -> void:
	pass


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## Applies a capture state: `default`, an exercise id the catalog carries, or one of the two
## difficulty pins. Anything else answers false — "not declared" — so a harness can tell the
## difference instead of guessing.
func apply_capture_state(state_id: String) -> bool:
	_ensure()
	if state_id == "default":
		select_difficulty(seed_difficulty())
		return select_exercise(first_exercise_id())
	if exercise_ids().has(state_id):
		return select_exercise(state_id)
	if DrillHub.difficulties().has(state_id):
		return select_difficulty(state_id)
	return false


# ---------------------------------------------------------------------------
# The table (read-only: the mode modules own the exercises, the objectives and the records)
# ---------------------------------------------------------------------------

func store() -> RefCounted:
	return _store if _store != null else Config.save_store()


func set_store(store_in: RefCounted) -> void:
	_store = store_in
	_previews.clear()
	if _built:
		_hub.setup(store(), _hub.difficulty())


## Every exercise id the catalog carries, in order. The pins and the hub both read it.
func exercise_ids() -> Array[String]:
	return Tables.drill_catalog_ids()


## The whole catalog: the frozen reference's own four rows, then the Godot-only ones.
func exercise_rows() -> Array:
	return Tables.drill_catalog()


func first_exercise_id() -> String:
	return DrillHub.first_id()


func exercise() -> String:
	return String((_hub as Control).selected_exercise())


func exercise_name_key() -> String:
	return "drill_%s_name" % exercise()


func exercise_desc_key() -> String:
	return "drill_%s_desc" % exercise()


func exercise_hint_key() -> String:
	return "drill_%s_hint" % exercise()


## One exercise's visible name, whichever table owns it (`drill_text.gd`).
func exercise_name(drill_id: String) -> String:
	return DrillText.exercise_name(drill_id)


## Makes one exercise the screen's choice. The hub refuses an id the catalog does not carry;
## the screen then re-reads the strings so the header and the hint follow the selection.
func select_exercise(id: String) -> bool:
	if not _hub.select_exercise(id):
		return false
	refresh_strings()
	return true


func difficulty() -> String:
	return String(_hub.difficulty())


## The four difficulty values the row offers, in the reference's own order.
func difficulty_rows() -> Array:
	var out: Array = []
	for id in DrillHub.difficulties():
		out.append({"id": id, "label_key": DrillHub.difficulty_label(id)})
	return out


## The reference's seed: the stored `aiDifficulty` when it is one of the four, else the first
## value on the list (`js/main.js:2162`). Read-only: nothing here writes a preference.
func seed_difficulty() -> String:
	if not _built:
		return DrillHub.seed_difficulty("")
	var snapshot := UiData.settings_snapshot(store())
	return DrillHub.seed_difficulty(String(snapshot.get("ai_difficulty", "")))


func select_difficulty(id: String) -> bool:
	return _hub.select_difficulty(id)


## The records the panel reads: the legacy `<exercise id>` map (`UiData.drill_records` over
## `ModesSave`, unchanged) — the BOUNDED challenge records are read by the hub itself, keyed
## by difficulty and run length, and the panel shows both.
func records() -> Dictionary:
	return UiData.drill_records(store())


func record_for(id: String) -> int:
	for row in (records().get("rows", []) as Array):
		if String((row as Dictionary).get("id", "")) == id:
			return int((row as Dictionary).get("best", 0))
	return 0


## What the detail panel actually shows for the two records, read back from the painted
## labels — what an audit compares instead of the function it is checking.
func shown_record_rows() -> Dictionary:
	var entry: Dictionary = _hub.detail()
	return {
		"challenge": int(entry.get("best", 0)),
		"historical": int(entry.get("historical_best", 0)),
		"key": String(entry.get("training_key", "")),
		"text": String((_hub.report() as Dictionary).get("record", "")),
	}


## The metric rows of a preview drill for the selection: the same `DrillScoring.metrics()` the
## live drill calls, so the numbers the panel's record rows are labelled with are the drill's
## own and not a second vocabulary.
func metric_rows() -> Array:
	var drill = _drill_for(exercise())
	if drill == null:
		return []
	drill.best = int(shown_record_rows()["challenge"])
	var out: Array = []
	for metric in DrillScoring.metrics(drill):
		var row: Dictionary = metric
		out.append({
			"key": String(row.get("key", "")),
			"label": UiStrings.t(String(row.get("key", ""))),
			"value": String(row.get("value", "")),
		})
	return out


## One preview drill per exercise, created through the frozen module and reused until the
## screen is entered again. Creating one builds a match state; it never steps it, so nothing
## here simulates a match.
func _drill_for(id: String) -> Variant:
	if id == "":
		return null
	if _previews.has(id):
		return _previews[id]
	var drill = DrillSession.create(String(id), Config.athlete(), Config.arena(), Config.tier(), {"seed": 0})
	_previews[id] = drill
	return drill


## The hub's own report, so a test reads the painted hub rather than the table behind it.
func hub_report() -> Dictionary:
	_ensure()
	return _hub.report()


# ---------------------------------------------------------------------------
# Start (the port's own decision: the drill plays in the match scene)
# ---------------------------------------------------------------------------

## The renderer the flow uses and the seams it reads, then the scene change. `dry_run` stops
## before the engine call so an audit can assert the payload in-process.
##
## The demo/scope gate is asked FIRST (`ModeSession.can_start`, the same source of truth
## `game/mode_screen.gd::start_mode` asks): a build that does not grant `drill` refuses it
## here, visibly — no config write and no scene change.
func start(dry_run := false) -> Dictionary:
	var payload := start_payload()
	payload["dry_run"] = dry_run
	payload["started"] = granted()
	if not payload["started"]:
		payload["reason"] = refusal()
		payload["scene"] = ""
		return payload
	Config.pending_mode = "drill"
	Config.pending_exercise = exercise()
	Config.pending_drill_difficulty = difficulty()
	Config.pending_training_return = DrillHub.RETURN_SCENE_ROUTED
	if not dry_run:
		get_tree().change_scene_to_file(SCENE_PATH)
	return payload


## Whether this build grants the drill.
func granted() -> bool:
	return ModeSession.can_start(SCREEN_ID)


## The refusal sentence; "" while the mode is granted (`ModeSession.refusal`).
func refusal() -> String:
	return ModeSession.refusal(SCREEN_ID)


## What `start()` hands the flow, without touching the tree or the config.
func start_payload() -> Dictionary:
	return {
		"mode": "drill",
		"exercise": exercise(),
		"difficulty": difficulty(),
		"scene": SCENE_PATH,
	}


# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------

## The chrome follows the choice exactly as `syncDrillChrome` does (`js/main.js:2146-2185`):
## the subtitle is the exercise's `desc` id, the hint line its `hint` id, both resolved
## through `drill_text.gd` in the current locale. `refresh()` on the hub also rewrites every
## card's own name, so a language flip moves the whole page.
func refresh_strings() -> void:
	_ensure()
	_shell.set_title("drillTitle")
	_shell.set_subtitle_text(DrillText.t(exercise_desc_key()))
	if _hint != null:
		_hint.text = DrillText.t(exercise_hint_key())
	_hub.refresh()
	_apply_gate()


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
	_build()
	refresh_strings()


func _build() -> void:
	var content: MarginContainer = _shell.content()
	var column := VBoxContainer.new()
	column.name = "DrillColumn"
	column.add_theme_constant_override("separation", 14)
	content.add_child(column)
	_hub = HubView.new()
	_hub.name = "DrillHub"
	_hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_hub)
	_hub.setup(store(), seed_difficulty())
	_hub.exercise_selected.connect(_on_hub_exercise)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_register_focus()


func _on_hub_exercise(_exercise_id: String) -> void:
	refresh_strings()


## The gate's own presentation, read off `granted()`: a refused build dims and disables the
## start action. A granted build leaves it alone.
func _apply_gate() -> void:
	var ok := granted()
	var start_button := find_child("HubStart", true, false) as Button
	if start_button != null:
		start_button.disabled = not ok
		start_button.modulate = Color(1, 1, 1, 1) if ok else Color(1, 1, 1, LOCKED_ALPHA)
		start_button.tooltip_text = "" if ok else refusal()


# ---------------------------------------------------------------------------
# Focus: the host's own model (`ScreenShell` -> the router bridge), one row per hub control
# ---------------------------------------------------------------------------

func _register_focus() -> void:
	for row in _hub.focus_rows():
		var entry: Dictionary = row
		_shell.add_focus(String(entry["id"]), entry["control"], String(entry["action"]), {"kind": "button"})


func focus_controls() -> Array:
	_ensure()
	return _shell.focus_controls()


func focus_id(suffix: String) -> String:
	_ensure()
	return _shell.focus_id(suffix)
