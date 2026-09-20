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
## `--capture=mode` is NOT implemented here: the mode screens have no capture path
## in this slice, and pretending otherwise would be a fourth thing to keep green.
extends Control

const Config := preload("res://game/match_config.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Locale := preload("res://src/locale/locale.gd")
const Gate := preload("res://game/content_gate.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const InputSource := preload("res://game/input_map.gd")
const NavRoutes := preload("res://src/input/nav_routes.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const DrillSession := preload("res://src/modes/drill_session.gd")
const TournamentRules := preload("res://src/modes/tournament_rules.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const CareerProgress := preload("res://src/modes/career_progress.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const ModeSession := preload("res://game/mode_session.gd")
const Lineup := preload("res://game/lineup.gd")

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
## Set by `--capture=…`: render this screen and quit, instead of waiting for a
## human. Same shape as the menu's own capture (`game/main_menu.gd`), because this
## host renders software GL (`xvfb-run` + `opengl3`) and every engine start-up is
## paid for once.
var _capture := false


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
	margin.add_child(col)
	_column = col

	_title = _label(_mode_title(), 30, Color(0.0, 0.898, 1.0))
	col.add_child(_title)
	col.add_child(_label(_mode_subtitle(), 16, Color(0.72, 0.78, 0.86)))

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
	col.add_child(_detail)

	var back := Button.new()
	back.name = "BackButton"
	# `<` and not `◂` (U+25C2): the shipped font has no Geometric Shapes block, so
	# that arrow rendered as a missing-glyph box — the same class of defect as the
	# accented letters, and the glyph check in `tests/game_slice_test.gd` now covers
	# the punctuation the screens actually use.
	back.text = "<  Torna al menu"
	back.custom_minimum_size = Vector2(260.0, 40.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(to_menu)
	col.add_child(back)
	_register("back", back, "back")

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
	var key := String(MODE_LABELS.get(_mode, ""))
	var name := Locale.t(key) if key != "" and Locale.is_resolvable(key) else _mode.to_upper()
	return "%s — %s" % [name, Gate.label()]


func _mode_subtitle() -> String:
	return "Schermata del modo '%s' · dati da godot/src/modes/** · back = %s" % [
		_mode, NavRoutes.back_action(SCREEN_ID)]


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
	# A drill row chooses the exercise the session starts on. The menu does not
	# know the exercises (`DRILL_EXERCISES` is the drill's own table), so the
	# choice is made here and carried in `Config.pending_exercise`.
	if id.begins_with("drill:"):
		Config.pending_exercise = id.substr(6)


## The row that actually plays the mode. Everything else on these screens reads
## the mode's tables; this is the one that opens the match, and it is the route
## `start_mode()` refuses in a build that does not grant the mode.
func _start_row(col: VBoxContainer, text: String) -> void:
	var b := Button.new()
	b.name = "StartButton"
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(420.0, 40.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(start_mode)
	col.add_child(b)
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
	col.add_child(_label("ESERCIZI (%d)" % Tables.drill_exercises().size(), 19, Color(1.0, 0.821, 0.4)))
	var exercises: Array = Tables.drill_exercises()
	for exercise in exercises:
		var id := String(exercise["id"])
		var kinds: Array = exercise["kinds"]
		_row("drill:%s" % id, "%s  ·  feed %s · rivals %s · targets %s · kinds %s" % [
			id.to_upper(), String(exercise["feed"]), str(bool(exercise["rivals"])),
			str(bool(exercise["targets"])), str(kinds)],
			"target_r %.1f · bullseye %.1f" % [Tables.drill_target_r(), Tables.drill_bullseye()])
	# The live session: the real `DrillSession`, stepped here, so the screen shows
	# the mode's own numbers rather than a description of them.
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
	var records: Dictionary = ModesSave.load_drill_records(Config.save_store())
	col.add_child(_label("RECORD SALVATI  %s" % JSON.stringify(records), 16, Color(0.80, 0.86, 0.92)))
	_start_row(col, "ALLENATI  >")


func _col_make_tournament(col: VBoxContainer) -> void:
	col.add_child(_label("TABELLONE (%d turni)" % TournamentRules.ROUNDS, 19, Color(1.0, 0.821, 0.4)))
	# Where the bracket IS, from the save (`ModesSave.tournament_round`): the round
	# the next match plays and the fixture it plays on. This is the line a player
	# reads after winning a round, so it is read from the same store the session
	# wrote to rather than from a screen-local guess.
	var state := saved_state()
	var current_round := int(state.get("round", 0))
	var current_arena := String(((state.get("fixture", {}) as Dictionary).get("arena", {}) as Dictionary).get("id", "?"))
	col.add_child(_label("PROSSIMO TURNO %d  ·  %s  ·  partite in albo %d" % [
		current_round + 1, current_arena, int(state.get("history", 0))], 17, Color(0.42, 0.98, 0.55)))
	var path: Array = TournamentRules.path(Config.selectable_arenas())
	for round in path.size():
		var fixture: Dictionary = path[round]
		var arena: Dictionary = fixture.get("arena", {})
		var ai: Dictionary = TournamentRules.ai_for_round(round)
		_row("tournament:round%d" % round, "TURNO %d  ·  %s  ·  %s (%s %.2f)%s%s" % [
			round, String(arena.get("id", "?")), String(ai.get("name", "?")),
			Locale.t("ability"), float(ai.get("skill", 0.0)),
			"  ·  TROFEO" if TournamentRules.is_trophy(round, true) else "",
			"  ·  IN CORSO" if round == current_round else ""],
			"prestigio %d · advance(won) -> %s" % [
				TournamentRules.prestigio(arena), JSON.stringify(TournamentRules.advance(round, true))])
	_start_row(col, "GIOCA TURNO %d  >" % (current_round + 1))


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
	if action == "back":
		to_menu()


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
		labels.append(b.text)
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
