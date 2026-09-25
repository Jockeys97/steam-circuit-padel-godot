## mode_screen.gd — the first real screens for the three modes: drill, tournament
## and career.
##
## WHAT THESE SCREENS ARE. They are the application layer `godot/src/modes/**` was
## waiting for: every row on them comes from that directory's own public API
## (`ModeTables`, `DrillSession`, `TournamentRules`, `CareerRules`,
## `CareerProgress`), the drill screen runs a live `DrillSession` — the real one,
## stepping the real simulation — and the numbers on screen are the mode's numbers.
##
## AND THEY NOW START THE MODE. `start_mode()` opens `res://game/Match.tscn` with
## `pending_mode` set, and the match controller resolves the mode through
## `game/mode_session.gd`: a real match against the fixture's court and the mode's
## own AI, persisted through `ModesSave` when it ends. The screens read back what
## the save holds — the bracket round, the career season — so a screen shows the
## state the player just changed rather than a fresh default.
##
## ONE SCREEN, THREE READS. The reference has one screen per mode
## (`screen-drill`, the tournament board, the career board); the port opens one
## screen whose body is the mode's own data. The reason is honesty about size: three
## near-identical scene files would be three places to keep in step, and the rows
## that matter are the mode's tables either way.
##
## NAVIGATION is the verified model, exactly as on the menu
## (`game/menu_focus.gd` -> `godot/src/input/**`), and this screen declares the
## reference's own return: `NavRoutes` gives `screen-modes` the declared back
## `to-menu` (`js/ui.js`, `scripts/gamepad-nav-audit.mjs:73-80`), so ESC and the
## pad's B go through `MenuFocus.back()` -> `{"kind": "back", "action": "to-menu"}`
## and land on the menu. The screen does not invent a destination for back, and it
## does not use Godot's built-in `ui_*` navigation for the rows.
##
## A DEMO BUILD DOES NOT OPEN A LOCKED MODE: `content_gate.gd` answers
## `modes()` -> `["quick"]`, and a mode outside it renders the reference's own
## locked line ("Nella versione completa", `js/i18n.js:147,839`) instead of a
## screen full of rows the build does not grant — the same rule the menu applies
## to its locked mode entries.
##
## THE TRAINING SCREEN IS THE ONE THAT READS AS A MENU. When `pending_mode` is
## `drill` this file mounts the SHARED hub body (`godot/src/ui/training/DrillHubView.gd`),
## the same view the recreated `godot/src/ui/screens/DrillScreen.gd` mounts: the eight
## `Tables.drill_catalog()` exercises grouped into Technique / Defence / Match play, one
## selected (`Config.pending_exercise` on confirm), with the chosen exercise's own goal,
## success rule, scored facts, controls, both records and run length beside them, one primary
## start action, and the locale's own Back. Every string resolves through `DrillText`/
## `Locale`, so the page is translated and carries no repository path, JSON or raw session
## numbers — the live `DrillSession` still runs and `screen_report()` still reports it as
## data, it is simply not painted. Tournament and career keep the presentation and logic they
## shipped with.
##
## `--capture=mode` renders this screen and quits
## (`godot/game/out/mode-<mode>-screen.png`), the same shape as the menu's capture.
extends Control

const Config := preload("res://game/match_config.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Locale := preload("res://src/locale/locale.gd")
const Gate := preload("res://game/content_gate.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const InputSource := preload("res://game/input_map.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const UiData := preload("res://src/ui/data/UiData.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const DrillText := preload("res://src/modes/drill_text.gd")
const DrillHub := preload("res://src/modes/drill_hub.gd")
const HubView := preload("res://src/ui/training/DrillHubView.gd")
const TournamentRules := preload("res://src/modes/tournament_rules.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const ModeSession := preload("res://game/mode_session.gd")
const Lineup := preload("res://game/lineup.gd")
## The one theme the recreated UI and `DrillScreen.tscn` mount
## (`godot/src/ui/theme/padel_theme.tres`). `ModeScreen.tscn` carries none, so
## without this a `theme_type_variation` is inert; it is applied to the TRAINING
## screen's own body and back control only, which leaves the tournament and career
## screens on the default skin they have always had.
const PadelTheme := preload("res://src/ui/theme/padel_theme.tres")

## The reference's three mode cards (`index.html:108-125`), with the locale id of
## each label: the same ids the menu's mode row uses.
const MODE_LABELS := {
	"drill": "training",
	"tournament": "tournamentMode",
	"career": "careerMode",
}
## The screen the model's declared back leads to (`NavRoutes.back_action`).
const SCREEN_ID := "screen-modes"

var _mode := "quick"
var _focus: MenuFocus
## The seat the rows read, remembered across frames (`selectPrimaryGamepad`'s rule,
## `js/main.js:265-272`): the pad somebody touches takes over, the current one is kept
## while nobody does. `NO_DEVICE` until a pad shows up.
var _pad_device := InputSource.NO_DEVICE
var _rows: Array[Button] = []
var _detail: Label
var _title: Label
var _column: Control
var _layout_seen := Vector2.ZERO
## The drill session this screen runs, when the mode is drill. Public so a test can
## read the live numbers the screen is showing.
var session
## The training screen's own controls: the selected exercise and the shared hub body
## (`godot/src/ui/training/DrillHubView.gd`), which owns the cards, the detail panel and the
## start action. `_hub` is only built on the drill branch.
var _selected_exercise := ""
## The shared hub body when the mode is drill (`godot/src/ui/training/DrillHubView.gd`).
var _hub: Control = null
## Set by `--capture=…`: render this screen and quit, instead of waiting for a
## human. Same shape as the menu's own capture (`game/main_menu.gd`), because this
## host renders software GL (`xvfb-run` + `opengl3`) and every engine start-up is
## paid for once.
var _capture := false
var _tournament_details: Dictionary = {}
var _tournament_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Capture-only arguments: which mode to open, and which save root to read it
	# from. Both exist so a render can show the screen a PLAYER sees (a season with
	# a match played, a bracket mid-round) instead of a fresh profile — the numbers
	# on screen are read from the save, so the save has to be the one that was
	# played. `--mode` also carries `Config.pending_mode`, which is what the match
	# scene reads.
	var args := OS.get_cmdline_user_args()
	var mode_arg := _arg(args, "--mode=", "")
	if mode_arg != "":
		Config.pending_mode = mode_arg
	var save_dir_arg := _arg(args, "--save-dir=", "")
	if save_dir_arg != "":
		Config.save_dir = save_dir_arg
	_capture = _arg(args, "--capture=", "") != ""
	_mode = Config.pending_mode
	if _mode == "tournament":
		theme = PadelTheme
	_focus = MenuFocus.new(SCREEN_ID)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.063, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "ModeMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.name = "ModeColumn"
	col.add_theme_constant_override("separation", 6)
	if _mode == "tournament":
		col.add_theme_constant_override("separation", 18)
	if _mode == "tournament":
		_tournament_scroll = ScrollContainer.new()
		_tournament_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tournament_scroll.follow_focus = true
		margin.add_child(_tournament_scroll)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tournament_scroll.add_child(col)
	else:
		margin.add_child(col)
	_column = col

	_title = _label(_mode_title(), 30, Color(0.0, 0.898, 1.0))
	if _mode == "tournament":
		_title.theme_type_variation = "HudTitle"
		_title.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(_title)
	var subtitle := _label(_mode_subtitle(), 16, Color(0.72, 0.78, 0.86))
	col.add_child(subtitle)
	if _mode == "drill":
		# The two header lines wear the shipped theme's own type on the TRAINING
		# screen, so the header matches the recreated UI instead of the engine's
		# default font. Tournament and career keep their current look.
		_title.theme = PadelTheme
		_title.theme_type_variation = "HudTitle"
		subtitle.theme = PadelTheme
		subtitle.theme_type_variation = "ScreenSubtitle"

	if is_locked():
		_col_make_locked(col)
	else:
		match _mode:
			"drill":
				_col_make_drill(col)
			"tournament":
				_col_make_tournament(col)
			"career":
				_col_make_career(col)

	_detail = _label("", 16, Color(0.80, 0.86, 0.92))
	if _mode == "drill":
		# The training screen's bottom line is the selected exercise's own hint
		# (`drill_<id>_hint`); the raw session line the other screens keep printing
		# stays out of the player's view.
		_detail.theme = PadelTheme
		_detail.name = "DrillHint"
	col.add_child(_detail)
	if _mode == "drill":
		_refresh_drill_detail()

	var back := Button.new()
	back.name = "BackButton"
	# `<` and not `◂` (U+25C2): the shipped font has no Geometric Shapes block, so
	# that arrow rendered as a missing-glyph box — the same class of defect as the
	# accented letters, and the glyph check in `tests/game_slice_test.gd` now covers
	# the punctuation the screens actually use.
	back.text = _back_label()
	if _mode == "tournament":
		back.theme_type_variation = "ButtonSecondary"
	back.custom_minimum_size = Vector2(240.0, 46.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if _mode == "drill":
		back.theme = PadelTheme
		back.theme_type_variation = "ButtonSecondary"
	back.pressed.connect(to_menu)
	col.add_child(back)
	_register("back", back, "back")
	if _mode == "tournament":
		col.add_child(_label("D-PAD / LS · %s     A · %s     B · %s" % ["Naviga" if Locale.current_lang() == "it" else "Navigate", "Conferma" if Locale.current_lang() == "it" else "Confirm", "Indietro" if Locale.current_lang() == "it" else "Back"], 12, Color("8192ab")))

	_refresh_detail()
	set_process_input(true)
	_focus.refresh()
	_focus.ensure_focus()
	_focus.apply_focus()
	if _rows.size() > 0:
		_rows[0].grab_focus()
	if _capture:
		_run_capture()


## Renders this screen and quits. Prints the screen's own report first, so the
## pixels and the data are the same claim.
func _run_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := "res://game/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/mode-%s-screen.png" % [dir, _mode]
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("mode screen capture: viewport texture null")
		get_tree().quit(3)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("mode screen capture: viewport image null")
		get_tree().quit(4)
		return
	print("MODE_SCREEN_ON_SCREEN %s" % JSON.stringify(screen_report()))
	var err := img.save_png(path)
	print("CAPTURE_SAVE err=%d path=%s size=%dx%d" % [err, path, img.get_width(), img.get_height()])
	get_tree().quit(0 if err == OK else 5)


func _arg(args: PackedStringArray, prefix: String, fallback: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


## Is this build allowed to open the screen? The gate's own list decides
## (`DEMO_CONTENT.modes = ["quick"]`, `js/build.js:43-53`), and it decides for ALL
## THREE modes — the demo build grants quick match only, so all three screens are
## locked there and none of them can start a session.
##
## WHY THE DRILL IS GATED HERE TOO, AND WHY IT IS A DELIBERATE DIVERGENCE. The
## browser's `applyDemoLimits` (`js/ui.js:735-748`) locks the `.mode-card` elements
## outside that list, and the browser's training entry (`data-action="to-drill"`,
## `index.html:61`) is a header button rather than a mode card, so the browser demo
## leaves training reachable. The port renders all three modes from ONE row and one
## gate (`portal`, `godot/game/main_menu.gd`), so it applies the build's granted
## list uniformly: in the packaged demo, no mode can be started by any route. The
## divergence is named in `docs/wayfinder/evidence/modes-playable.md` rather than
## hidden behind a special case.
func is_locked() -> bool:
	# The same question the menu's own mode row asks, through the same gate, so a
	# screen can never offer what the session would refuse (`ModeSession.can_start`)
	# and the locked tag a player reads is the reason the start button gives.
	return not ModeSession.can_start(_mode)


func _mode_title() -> String:
	# The TRAINING screen's own heading (`drillTitle`: "ALLENAMENTO" / "TRAINING"),
	# the same id `DrillScreen.gd` uses. The other two screens keep the reference's
	# mode label plus the build's own tag, exactly as they shipped.
	if _mode == "drill":
		return _text("drillTitle", _mode.to_upper())
	var key := String(MODE_LABELS.get(_mode, ""))
	var name := Locale.t(key) if key != "" and Locale.is_resolvable(key) else _mode.to_upper()
	if _mode == "tournament":
		return name
	return "%s — %s" % [name, Gate.label()]


func _mode_subtitle() -> String:
	if _mode == "tournament":
		return "Tre sfide. Un solo trofeo. Vinci ogni turno per arrivare in finale." if Locale.current_lang() == "it" else "Three matches. One trophy. Win each round to reach the final."
	# `drillSub` is the reference's own training subtitle. It replaces the
	# "dati da godot/src/modes/**" line on this screen: a player must never read a
	# repository path or a declared back action, and the mode's data is no longer
	# what the page is about.
	if _mode == "drill":
		return _text("drillSub", "")
	return "Schermata del modo '%s' · dati da godot/src/modes/** · back = %s" % [
		_mode, NavRoutes.back_action(SCREEN_ID)]


## One player-facing string from the port's own locale layer, with a deliberate
## fallback for an id the table cannot answer (`Locale.t` would print the id).
func _text(key: String, fallback: String) -> String:
	return Locale.t(key) if Locale.is_resolvable(key) else fallback


## The back control's word, from the reference's own `back` id (`← Indietro` /
## `← Back`). The shipped fonts carry no Arrows block — measured: U+2190 is absent
## from both Lilita One and Nunito, the same gap that turned `◂` (U+25C2) into a
## missing-glyph box — so the reference's arrow is swapped for the Latin-1 `<`
## while the WORD stays the locale's, and the button is still translated.
func _back_label() -> String:
	var text := _text("back", "Back")
	return text.replace("←", "<").replace("◂", "<").strip_edges()


# ---------------------------------------------------------------------------
# Rows, one per fact the mode's own modules answer
# ---------------------------------------------------------------------------

func _row(id: String, text: String, detail: String) -> void:
	var b := Button.new()
	b.name = "Row_%s" % id
	b.text = text
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(760.0, 30.0)
	b.add_theme_font_size_override("font_size", 16)
	b.tooltip_text = detail
	b.pressed.connect(_on_row.bind(id, detail))
	_column.add_child(b)
	_rows.append(b)
	_register(id, b, id)


func _on_row(id: String, detail: String) -> void:
	_detail.text = "%s — %s" % [id, detail]


# ---------------------------------------------------------------------------
# The training screen: the shared hub body, one chosen exercise, one action
# ---------------------------------------------------------------------------

## The exercise the screen opens on: the one already pending, when the catalogue still carries
## it, otherwise the catalogue's own first row — the same default `ModeSession.start` falls
## back to. Nothing is written to `Config` here: the seam is only touched when the player
## actually chooses.
func _initial_exercise(exercises: Array) -> String:
	var ids: Array[String] = []
	for exercise in exercises:
		ids.append(String((exercise as Dictionary).get("id", "")))
	var pending := String(Config.pending_exercise)
	if ids.has(pending):
		return pending
	return ids[0] if not ids.is_empty() else ""


## A row was activated — by the mouse (`pressed`) or by the navigation model
## (`_run_action`), which suppress the other. The hub owns the choice; this keeps the
## screen's own seam (`Config.pending_exercise`) in step with it.
func _on_exercise(exercise_id: String) -> void:
	if not _hub_has(exercise_id):
		return
	_select_exercise(exercise_id)


## Makes one exercise the screen's choice. This is the ONE place the choice is written, and it
## writes exactly what the shipped gate/`screen_report()` expect: `Config.pending_exercise`,
## which `start_mode()` and the match scene read.
func _select_exercise(exercise_id: String) -> void:
	if _hub == null or not _hub.select_exercise(exercise_id):
		return
	_selected_exercise = exercise_id
	Config.pending_exercise = exercise_id
	_refresh_drill_detail()


func _hub_has(exercise_id: String) -> bool:
	for row in Tables.drill_catalog():
		if String((row as Dictionary).get("id", "")) == exercise_id:
			return true
	return false


## The hint line under the hub. The panel's own prose (goal, success rule, scored facts,
## controls, records, run length) is written by the shared view; this screen adds the
## reference's per-exercise hint, which the old page also carried.
func _refresh_drill_detail() -> void:
	if _detail != null:
		_detail.text = DrillText.t(DrillText.exercise_hint_key(_selected_exercise))


## The row that actually plays the mode. Everything else on these screens reads
## the mode's tables; this is the one that opens the match, and it is the route
## `start_mode()` refuses in a build that does not grant the mode.
##
## `primary` is the training screen's wide, filled action (`ButtonPrimary`); the
## tournament board keeps the plain action it shipped with.
func _start_row(parent: Container, text: String, primary := false) -> void:
	var b := Button.new()
	b.name = "StartButton"
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.theme_type_variation = "ButtonPrimary"
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(0.0, 56.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(420.0, 40.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(start_mode)
	parent.add_child(b)
	_register("start", b, "start")


## Starts the mode this screen is showing: `pending_mode` is what the match scene
## reads, and the screen does not touch the save itself — the session does, on the
## single end-of-match path (`game/mode_session.gd::finish`).
##
## Returns what it did, so a test can ask without changing scenes: `dry_run` skips
## the scene change and reports what WOULD have happened.
func start_mode(dry_run := false) -> Dictionary:
	var mode := _mode
	var granted: bool = ModeSession.can_start(mode)
	var reason: String = ModeSession.refusal(mode)
	if granted:
		Config.pending_mode = mode
		if mode == "drill" and Config.pending_exercise == "":
			Config.pending_exercise = String(ModeSession.DEFAULT_EXERCISE)
		Config.pending_round = -1
	if not dry_run and granted:
		get_tree().change_scene_to_file("res://game/Match.tscn")
	return {
		"mode": mode,
		"started": granted,
		"reason": reason,
		"scene": "res://game/Match.tscn" if granted else "",
		"pending_mode": String(Config.pending_mode),
		"exercise": String(Config.pending_exercise),
	}


## The save's own state for this mode, read through `ModesSave` — the same numbers
## the session writes when the match ends.
func saved_state() -> Dictionary:
	var store = Config.save_store()
	match _mode:
		"tournament":
			var round := ModesSave.tournament_round(store)
			return {
				"round": round,
				"fixture": TournamentRules.fixture(round, Config.selectable_arenas()),
				"history": ModesSave.load_history(store).size(),
			}
		"career":
			var career := ModesSave.load_career(store)
			var season := int(career.get("season", 1))
			var index := int(career.get("matchIndex", 0))
			return {
				"season": season,
				"matchIndex": index,
				"fixture": CareerRules.career_fixture(season, index, Config.selectable_arenas()),
				"wins": int(career.get("wins", 0)),
				"losses": int(career.get("losses", 0)),
				"stars": int(career.get("stars", 0)),
				"seasonStars": int(career.get("seasonStars", 0)),
				"trophies": int(career.get("trophies", 0)),
				"seasonObjectives": career.get("seasonObjectives", []),
				"objectives": _objective_rows(career),
				"history": ModesSave.load_history(store).size(),
			}
		"drill":
			return {"records": ModesSave.load_drill_records(store), "history": ModesSave.load_history(store).size()}
	return {}


## The season's three objectives with their stored state, as the career screen
## prints them (`career.seasonObjectives`, written by `ensureSeasonObjectives`).
func _objective_rows(career: Dictionary) -> Array:
	var out: Array = []
	var stored: Variant = career.get("seasonObjectives", null)
	var list: Array = stored if stored is Array else []
	# `career` here is the copy `load_career` returned, so generating the season's
	# objectives into it writes a screen-local value and never the save.
	if list.is_empty():
		list = CareerProgress.ensure_season_objectives(career)
	for objective in list:
		if not (objective is Dictionary):
			continue
		out.append({
			"id": String((objective as Dictionary).get("id", "")),
			"target": int((objective as Dictionary).get("target", 0)),
			"done": bool((objective as Dictionary).get("done", false)),
			"claimed": bool((objective as Dictionary).get("claimed", false)),
		})
	return out


func _col_make_drill(col: VBoxContainer) -> void:
	var exercises: Array = Tables.drill_catalog()

	# The live session: the REAL `DrillSession`, stepped here, so `screen_report()`
	# still carries the mode's own phase and target and the existing coverage keeps
	# meaning. It is NOT painted: the drill's live numbers belong to the match HUD,
	# and raw session/target text on a setup page is exactly the debug prose this
	# screen had to lose.
	var first: Dictionary = exercises[0] if exercises.size() > 0 else {}
	if not first.is_empty():
		var ai: Dictionary = CareerRules.ai_for_match("drill", 0, "", 1, 0)
		session = DrillSession.create(String(first["id"]), Config.athlete(), Config.arena(), ai, {
			"seed": Config.seed_value,
			"lineup": Lineup.resolve(Config.athlete()),
		})
		for _i in 120:
			# The first frame carries the player's press (leaving `ready`), the rest
			# carry nothing — a real `DrillSession` stepped with a real input dict, not
			# with `null`, which its own signature refuses.
			session.step(1.0 / 120.0, {"hit": true} if _i == 0 else {})

	_selected_exercise = _initial_exercise(exercises)

	# The SHARED hub body (`godot/src/ui/training/DrillHubView.gd`): the same view the
	# recreated `DrillScreen` mounts, so the two routes cannot describe an exercise
	# differently. The shipped theme is scoped to this screen's own subtree (see `PadelTheme`),
	# so the view's variations resolve here exactly as they do there.
	var body := MarginContainer.new()
	body.name = "DrillBody"
	body.theme = PadelTheme
	col.add_child(body)
	_hub = HubView.new()
	_hub.name = "DrillHub"
	_hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_hub)
	_hub.setup(Config.save_store(), _initial_difficulty(), Locale.current_lang())
	_hub.select_exercise(_selected_exercise)
	_hub.exercise_selected.connect(_on_hub_exercise)
	_hub.start_requested.connect(_on_hub_start)
	_hub.difficulty_changed.connect(_on_hub_difficulty)

	# The rows the model navigates and `screen_report()` lists: the hub's own cards, in the
	# order the page shows them, under the ids the ports already use (`drill:<id>`), plus the
	# difficulty row and the one start action.
	for row in _hub.focus_rows():
		var entry: Dictionary = row
		var action := String(entry["action"])
		var focus_id := "drill:%s" % action.substr(action.find(":") + 1) if action.begins_with("exercise:") else action
		if action.begins_with("difficulty:"):
			focus_id = action
		_rows.append(entry["control"] as Button)
		_register(focus_id, entry["control"], focus_id)
	_refresh_drill_detail()


## The shared hub body's own report, so a test (and `screen_report()`) can read the page as
## data without reaching into the view's internals. `{}` in the two other modes.
func hub_report() -> Dictionary:
	if _hub == null:
		return {}
	return _hub.report()


## The difficulty the hub opens on: the stored `aiDifficulty` when it is one of the four
## (`js/main.js:2162`), otherwise the first. Read-only — choosing one here writes no
## preference (`DrillHub.seed_difficulty`).
func _initial_difficulty() -> String:
	var snapshot: Dictionary = UiData.settings_snapshot(Config.save_store())
	return DrillHub.seed_difficulty(String(snapshot.get("ai_difficulty", "")))


func _on_hub_exercise(exercise_id: String) -> void:
	_selected_exercise = exercise_id
	Config.pending_exercise = exercise_id
	_refresh_drill_detail()


func _on_hub_start(_exercise_id: String) -> void:
	start_mode()


## A difficulty row row: the choice is transient (no preference is written) and travels to the
## run through `Config.pending_drill_difficulty`, which `game/mode_session.gd` resolves into
## the drill's AI profile.
func _on_hub_difficulty(difficulty_id: String) -> void:
	Config.pending_drill_difficulty = difficulty_id


func _col_make_tournament(col: VBoxContainer) -> void:
	_build_tournament_cards(col)
	return

func _build_tournament_cards(col: VBoxContainer) -> void:
	var italian := Locale.current_lang() == "it"
	var current := int(saved_state().get("round", 0))
	var gold := Color("ffdb70")
	col.add_child(_label(("VERSO IL TROFEO   /   TURNO %d DI 3" if italian else "ROAD TO THE TROPHY   /   ROUND %d OF 3") % (current + 1), 15, gold))
	var grid := HBoxContainer.new()
	grid.name = "TournamentCards"
	grid.add_theme_constant_override("separation", 18)
	col.add_child(grid)
	var fixtures: Array = TournamentRules.path(Config.selectable_arenas())
	for index in fixtures.size():
		var arena: Dictionary = fixtures[index].get("arena", {})
		var ai := TournamentRules.ai_for_round(index)
		var id := "tournament:round%d" % index
		var stages := ["QUALIFICAZIONE", "SEMIFINALE", "FINALE"] if italian else ["QUALIFIER", "SEMI-FINAL", "FINAL"]
		var stage: String = stages[index]
		var arena_name := String(arena.get("name", arena.get("id", "")))
		var status := ("COMPLETATO" if italian else "COMPLETED") if index < current else (("PROSSIMA SFIDA" if italian else "UP NEXT") if index == current else ("DA RAGGIUNGERE" if italian else "COMING UP"))
		var button := Button.new()
		button.name = "Round%d" % index
		button.custom_minimum_size = Vector2(0, 292)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := StyleBoxFlat.new()
		box.bg_color = Color("111c37")
		box.border_color = Color("18c6db") if index == current else Color("294365")
		box.set_border_width_all(2)
		box.set_corner_radius_all(14)
		button.add_theme_stylebox_override("normal", box)
		var focused := box.duplicate() as StyleBoxFlat
		focused.border_color = gold
		focused.set_border_width_all(4)
		focused.shadow_color = Color(0, 0.8, 1, 0.25)
		focused.shadow_size = 8
		for slot in ["focus", "hover", "pressed"]:
			button.add_theme_stylebox_override(slot, focused)
		grid.add_child(button)
		var body := VBoxContainer.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.offset_left = 14
		body.offset_right = -14
		body.offset_top = 14
		body.offset_bottom = -14
		body.add_theme_constant_override("separation", 8)
		button.add_child(body)
		var art := TextureRect.new()
		art.custom_minimum_size.y = 122
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var image_path := preload("res://src/ui/data/UiArtPaths.gd").path_for("arenas", String(arena.get("id", "")))
		if image_path != "":
			art.texture = load(image_path)
		body.add_child(art)
		body.add_child(_label("0%d   %s" % [index + 1, stage], 19, gold if index == 2 else Color("68e4ed")))
		body.add_child(_label(arena_name, 18, Color.WHITE))
		body.add_child(_label(String(ai.get("name", "")), 14, Color("9cafc8")))
		body.add_child(_label(status, 12, Color("69e8ba") if index <= current else Color("8192ab")))
		_tournament_details[id] = "%s · %s · %s" % [stage, arena_name, status]
		button.pressed.connect(_show_tournament_round.bind(id))
		button.focus_entered.connect(_show_tournament_round.bind(id))
		_rows.append(button)
		_register(id, button, id)
	_start_row(col, ("GIOCA TURNO %d  >" if italian else "PLAY ROUND %d  >") % (current + 1), true)

func _show_tournament_round(id: String) -> void:
	if _detail != null:
		_detail.text = String(_tournament_details.get(id, ""))

func _col_make_career(col: VBoxContainer) -> void:
	var objectives: Array = CareerRules.season_objectives(1)
	var saved := saved_state()
	col.add_child(_label("STAGIONE %d  ·  partita %d/%d  ·  %s  ·  %d partite  ·  %d punti per vincere  ·  %d vittorie per la promozione" % [
		int(saved.get("season", 1)), int(saved.get("matchIndex", 0)) + 1, CareerRules.career_matches(),
		String(((saved.get("fixture", {}) as Dictionary).get("arena", {}) as Dictionary).get("id", "")),
		CareerRules.career_matches(), CareerRules.career_points_to_win(), CareerRules.career_promotion_wins()],
		19, Color(1.0, 0.821, 0.4)))
	# The season as the SAVE holds it: stars, record, and each objective's own
	# progress. The first three rows below the header are the season's objectives
	# written by the last match (`seasonObjectives`), not the fresh season-1 pool.
	col.add_child(_label("BILANCIO  %d vinte · %d perse · %d stelle (stagione %d) · %d trofei  ·  albo %d" % [
		int(saved.get("wins", 0)), int(saved.get("losses", 0)), int(saved.get("stars", 0)),
		int(saved.get("seasonStars", 0)), int(saved.get("trophies", 0)), int(saved.get("history", 0))],
		17, Color(0.42, 0.98, 0.55)))
	var saved_objectives: Array = saved.get("objectives", [])
	if saved_objectives.is_empty():
		var progress: Dictionary = CareerRules.empty_season_progress()
		for objective in objectives:
			var id := String(objective.get("id", objective.get("def", "?")))
			_row("career:objective:%s" % id, "OBIETTIVO  ·  %s  ·  %s" % [id, JSON.stringify(objective)],
				"progress %s" % JSON.stringify(progress))
	else:
		for objective in saved_objectives:
			var entry: Dictionary = objective
			_row("career:objective:%s" % String(entry.get("id", "?")),
				"OBIETTIVO  ·  %s  ·  target %d%s%s" % [
					String(entry.get("id", "?")), int(entry.get("target", 0)),
					"  ·  FATTO" if bool(entry.get("done", false)) else "",
					"  ·  stella presa" if bool(entry.get("claimed", false)) else ""],
				"stored in career.seasonObjectives (js/ui.js:62-83)")
	var live_fixture: Dictionary = CareerRules.career_fixture(
		int(saved.get("season", 1)), int(saved.get("matchIndex", 0)), Config.selectable_arenas())
	var live_arena: Dictionary = live_fixture.get("arena", {})
	var live_ai: Dictionary = CareerRules.career_ai_profile(
		int(saved.get("season", 1)), int(saved.get("matchIndex", 0)))
	var live_objective: Dictionary = CareerRules.match_objective(
		int(saved.get("season", 1)), int(saved.get("matchIndex", 0)))
	_row("career:fixture", "PARTITA %d  ·  %s  ·  %s (%s %.2f)" % [
		int(saved.get("matchIndex", 0)) + 1, String(live_arena.get("id", "?")),
		String(live_ai.get("name", "?")), Locale.t("ability"), float(live_ai.get("skill", 0.0))],
		"rival %s · obiettivo %s · ramp %s" % [
			String(CareerRules.career_rival(int(saved.get("season", 1))).get("name", "?")),
			JSON.stringify(live_objective),
			JSON.stringify(CareerRules.career_ramp())])
	_row("career:season", "STAGIONE FINALE %d  ·  esito %s" % [
		CareerRules.career_final_season(), JSON.stringify(CareerProgress.apply_career_match(
			CareerProgress.empty_career(), true))],
		"empty_career %s" % JSON.stringify(CareerProgress.empty_career()))


func _col_make_locked(col: VBoxContainer) -> void:
	var key := Gate.locked_key()
	var line := Locale.t(key) if Locale.is_resolvable(key) else "In the full game"
	col.add_child(_label("%s — %s" % [_mode.to_upper(), line], 20, Color(1.0, 0.549, 0.0)))
	col.add_child(_label("Questo build offre i modi: %s." % str(Gate.modes()), 16, Color(0.80, 0.86, 0.92)))


func _refresh_detail() -> void:
	if _mode == "tournament":
		_detail.text = "D-PAD / LS  ·  Naviga       A  ·  Conferma       B  ·  Indietro" if Locale.current_lang() == "it" else "D-PAD / LS  ·  Navigate       A  ·  Confirm       B  ·  Back"
		return
	# The training screen's bottom line is the chosen exercise's own hint, written by
	# `_refresh_drill_detail()`. The raw session readout below is the debug prose this
	# screen had to lose; `screen_report()` still answers `drill_phase` and
	# `drill_target` as data.
	if _mode == "drill":
		return
	if session == null:
		_detail.text = "Scegli una riga: il dettaglio appare qui." if _rows.size() > 0 else _detail.text
		return
	_detail.text = "SESSIONE  fase %s · round %d · tentativi %d · punti %d · target %s · metriche %s" % [
		String(session.phase), int(session.round), int(session.attempts), int(session.points),
		JSON.stringify(session.target), str(session.metrics())]


# ---------------------------------------------------------------------------
# Navigation: the model, and the reference's declared return
# ---------------------------------------------------------------------------

func _register(id: String, node: Control, action: String) -> void:
	_focus.add(id, node, action)


## The pad the rows read (`selectPrimaryGamepad`, `js/main.js:265-272`): the pad
## somebody touches takes over, the current one is kept while nobody does — never
## blindly the host's first entry, which is not necessarily the pad in the player's
## hands. `NO_DEVICE` stays `NO_DEVICE`, and the model reads it as neutral.
func _read_pad_device() -> int:
	_pad_device = InputSource.select_device(_pad_device)
	return _pad_device


func _input(event: InputEvent) -> void:
	if _focus == null:
		return
	if event is InputEventKey:
		var result: Dictionary = _focus.handle_key(event as InputEventKey)
		if bool(result.get("handled", false)):
			get_viewport().set_input_as_handled()
			_dispatch(result)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _focus == null:
		return
	# The layout settles one frame after the tree is built (see `main_menu.gd`): the
	# model's rectangles are re-measured when it does.
	if _column != null and _column.size != _layout_seen:
		_layout_seen = _column.size
		_focus.refresh()
		_focus.apply_focus()
	if Input.get_connected_joypads().is_empty():
		return
	var result: Dictionary = _focus.poll_pad(_read_pad_device())
	if bool(result.get("focus_moved", false)) or String(result.get("kind", "")) != "":
		_dispatch(result)


## What the model decided. `back` here is the reference's own declared return
## (`screen-modes` -> `to-menu`), never a positional guess.
func _dispatch(result: Dictionary) -> void:
	var kind := String(result.get("kind", ""))
	if kind == "activate" or kind == "back":
		_run_action(String(result.get("action", "")))
	if bool(result.get("focus_moved", false)) or kind == "":
		_focus.apply_focus()


func _run_action(action: String) -> void:
	if action == "back" or action == "to-menu":
		to_menu()
	elif action.begins_with("drill:"):
		# The model's confirm on an exercise row. The mouse reaches the same choice
		# through the Button's own `pressed` signal; both land in `_select_exercise`,
		# so a pad and a click cannot disagree about `Config.pending_exercise`.
		_on_exercise(action.substr(6))
	elif action == "start":
		start_mode()
	elif action.begins_with("tournament:"):
		_show_tournament_round(action)


func to_menu() -> void:
	Config.pending_mode = "quick"
	get_tree().change_scene_to_file("res://game/Main.tscn")


# ---------------------------------------------------------------------------
# Widgets and the test's read-back
# ---------------------------------------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## The focus model, so a test can ask this screen the same questions it asks the
## menu: what is registered, what can be reached, where the focus is.
func focus_model() -> MenuFocus:
	return _focus


## What this screen shows, as data — the read-back a test asserts on.
func screen_report() -> Dictionary:
	var labels: Array = []
	for b in _rows:
		labels.append(b.text if _mode != "tournament" else String(_tournament_details.get("tournament:round%d" % _rows.find(b), "")))
	return {
		"mode": _mode,
		"screen": SCREEN_ID,
		"declared_back": NavRoutes.back_action(SCREEN_ID),
		"locked": is_locked(),
		"startable": ModeSession.can_start(_mode),
		"rows": labels,
		"detail": _detail.text if _detail != null else "",
		"drill_phase": String(session.phase) if session != null else "",
		"drill_target": session.target if session != null else {},
		"focus": _focus.focus_id() if _focus != null else "",
		"saved": saved_state(),
	}
