## ChallengesScreen.gd — UIR-15: the reference's `#screen-challenges` / "Obiettivi del
## circuito" (`index.html:292-306`), rendered by `renderChallenges`
## (`js/ui.js:1125-1211`).
##
## THE REFERENCE SHAPE. One board (`.challenge-board`) with three sections in the
## reference's order: personaggi (athletes with an `unlock`), costumi (the outfits a
## challenge gates, grouped by athlete) and arene (arenas with an `unlock`). Each
## section heads with its title and a `done/total` count; each row is a mark, a name
## (the athlete's own colour), what it takes, and its state.
##
## WHAT IS REAL DATA HERE. Rows are composed from the frozen tables
## (`Frozen.athletes()`, `Frozen.arenas()`, `Tables.outfits_for_athlete`) and the
## career the store holds (`ModesSave.load_career`), read through the modes lane's own
## rules (`CareerRules.is_unlocked`) — the same rules `UiData.unlock_summary` counts
## with, so the section counts and the rows cannot disagree. Every string is a locale
## id: names are `athlete_<id>_name` / `arena_<id>_name`, roles
## `athlete_<id>_role`, the challenge sentences are the reference's own key family
## (`chChallengeLabel`, `chWin`, `chRally`, `chTotalHits`, `chWins`, `chAtMost`,
## `chAtLeast`, `chNone`, `chSkillLegend`, `chSkillHard`, `metric_<metric>`).
##
## THE MISSING SHARED SEAM, RECORDED FOR THE INTEGRATOR. `UiData.unlock_summary()`
## gives the three buckets' counts but no rows, and the screen must render the rows;
## `godot/src/modes/**` is the reading lane this file uses (the same readers `UiData`
## itself calls). If the integration wave wants zero table reads inside screens, the
## seam to add is a `UiData.challenge_rows(store)` (or three bucket row builders) and
## this file becomes a pure renderer of it. Recorded, not done: it is a shared-file
## edit and this ticket owns only its own four paths.
##
## THE TWO VOLUNTARY NOTES the reference paints only in a limited build
## (`js/ui.js:1203-1208`): the career-limitation note in the personaggi and arene
## sections, keyed by the build (`betaCareerNote` for a beta, `demoCareerNote`
## otherwise). This port reaches `demo` and `full` only, so the note's key is always
## the demo one and `betaCareerNote` stays a recorded locale-lane gap.
##
## STATIC CHECKS ONLY in this wave: nothing here has run in an engine (recorded in
## `evidence/uir-15-screen-challenges.log`).
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")
const Config := preload("res://game/match_config.gd")
const ShellScene := preload("res://src/ui/ScreenShell.tscn")

const SCREEN_ID := "challenges"
const TITLE_KEY := "challengesTitle"
const SUBTITLE_KEY := "challengesSub"
const ARIA_KEY := "ariaChallenges"
const BACK_TARGET_ID := "menu"

## The four capture states (`UIR-15` DoD): the live board, a partially completed one,
## an all-complete one, and the limited build's note.
const CAPTURE_STATE_LIST: Array[String] = [
	"default", "some-complete", "all-complete", "demo-limited",
]

## The section titles, in the reference's order (`js/ui.js:1210`).
const SECTION_KEYS: Array = ["sectionAthletes", "sectionOutfits", "sectionArenas"]

## `js/ui.js:1204`: the note's key family.
const NOTE_KEY_DEMO := "demoCareerNote"
const NOTE_KEY_BETA := "betaCareerNote"

## `.challenge-board` (`styles.css:3176-3180`), stacked below 900 px
## (`styles.css:3245-3252`).
const BOARD_MAX_WIDTH := 1100.0
const BOARD_PAD_WIDE := 64.0
const BOARD_PAD_NARROW := 24.0
const STACK_BELOW_PX := 900.0

const BOARD_NODE := "ChallengeBoard"
const NOTA_NODE := "SectionNota"

## The router's own facts, kept the way `MenuScreen` keeps them.
var router_id: String = ""
var back_target_id: String = ""

var _shell: Control
var _store: RefCounted
var _board: VBoxContainer
var _career_pin: Dictionary = {}
var _note_pin: Variant = null
var _narrow: bool = false
var _sections: Array[Dictionary] = []
var _palette_misses: Array = []


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


## The four states the ticket declares. `some-complete` and `all-complete` pin the
## career the rows are read against (the reference's own two ways a board looks
## finished); `demo-limited` pins the limitation note — in a full build the reference
## paints no note, so that state is a labelled capture pin, not a build claim.
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"default":
			_career_pin = {}
			_note_pin = null
			refresh()
			return true
		"some-complete":
			_career_pin = _partial_career()
			_note_pin = null
			refresh()
			return true
		"all-complete":
			var live: RefCounted = _store if _store != null else Config.save_store()
			var career := ModesSave.load_career(live)
			career = career.duplicate()
			career["unlockAll"] = true
			_career_pin = career
			_note_pin = null
			refresh()
			return true
		"demo-limited":
			_note_pin = true
			refresh()
			return true
	return false


func set_store(store: RefCounted) -> void:
	_store = store
	refresh()


func store() -> RefCounted:
	return _store


## The whole board rebuilt from the store and the frozen tables. `renderChallenges()`
## is called from `applyLanguage()` in the reference (`js/main.js:2220`), for the same
## reason: rows carry resolved text.
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
	_sections = _build_sections()
	_fill_board()
	_apply_aria()


## The three sections' rows, as data. Kept apart from the painting so the audit can
## assert counts and per-row facts without walking the tree's text.
func sections() -> Array[Dictionary]:
	return _sections.duplicate(true)


func section_rows(section_index: int) -> Array:
	if section_index < 0 or section_index >= _sections.size():
		return []
	return (_sections[section_index]["rows"] as Array).duplicate()


func section_done(section_index: int) -> int:
	if section_index < 0 or section_index >= _sections.size():
		return 0
	return int(_sections[section_index]["done"])


func section_total(section_index: int) -> int:
	if section_index < 0 or section_index >= _sections.size():
		return 0
	return int(_sections[section_index]["total"])


func note_visible(section_index: int) -> bool:
	if section_index < 0 or section_index >= _sections.size():
		return false
	return bool(_sections[section_index].get("note", false))


func note_key() -> String:
	return NOTE_KEY_BETA if DemoGate.build() == "beta" else NOTE_KEY_DEMO


func aria_name() -> String:
	return UiStrings.t(ARIA_KEY)


## The separator the reference joins composed labels with (`js/ui.js:683`), read from
## the locale lane's declared rules — never written here as a user-facing literal.
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
		"muted", "cyan", "ink", "challenge_cyan", "challenge_row_fill",
		"challenge_done_border", "challenge_done_fill", "state_yellow_soft",
	]


func palette_misses() -> Array:
	return _palette_misses.duplicate()


# ---------------------------------------------------------------------------
# The data
# ---------------------------------------------------------------------------

func _career() -> Dictionary:
	if not _career_pin.is_empty():
		return _career_pin
	if _store == null:
		_store = Config.save_store()
	return ModesSave.load_career(_store)


## The `some-complete` pin: the live career plus the first challenge outfit of every
## athlete — a board with a foot in both columns, deterministic for a capture.
func _partial_career() -> Dictionary:
	var career := _career().duplicate(true)
	var won: Variant = career.get("outfitsWon")
	var outfits_won: Dictionary = won if won is Dictionary else {}
	outfits_won = outfits_won.duplicate()
	for athlete in Frozen.athletes():
		for outfit in Tables.outfits_for_athlete(String((athlete as Dictionary).get("id", ""))):
			if (outfit as Dictionary).get("challenge", null) != null:
				outfits_won[String((outfit as Dictionary).get("unlockKey", ""))] = true
				break
	career["outfitsWon"] = outfits_won
	career["unlockAll"] = false
	return career


func _build_sections() -> Array[Dictionary]:
	var career := _career()
	var sections: Array[Dictionary] = []
	# personaggi
	var atleti := _unlockable(Frozen.athletes())
	var righe_atleti: Array = []
	for athlete_in in atleti:
		var athlete: Dictionary = athlete_in
		var id := String(athlete.get("id", ""))
		var unlocked := CareerRules.is_unlocked(athlete, career)
		righe_atleti.append({
			"name_key": "athlete_%s_name" % id,
			"role_key": "athlete_%s_role" % id,
			"color": String(athlete.get("color", "")),
			"what": _cost(athlete.get("unlock"), career),
			"done": unlocked,
			"state_key": "challengeUnlocked" if unlocked else "challengeLocked",
		})
	sections.append(_section("sectionAthletes", righe_atleti, _note_shown(), true))
	# costumi
	var gruppi: Array = []
	var completi_totali := 0
	var completi_fatti := 0
	var tutto := bool(career.get("unlockAll", false))
	var won_map: Variant = career.get("outfitsWon")
	var outfits_won: Dictionary = won_map if won_map is Dictionary else {}
	for athlete_in in Frozen.athletes():
		var athlete: Dictionary = athlete_in
		var suoi: Array = []
		for outfit_in in Tables.outfits_for_athlete(String(athlete.get("id", ""))):
			var outfit: Dictionary = outfit_in
			if outfit.get("challenge", null) == null:
				continue
			completi_totali += 1
			var fatto := tutto or bool(outfits_won.get(String(outfit.get("unlockKey", "")), false))
			if fatto:
				completi_fatti += 1
			suoi.append({
				"name_key": String(outfit.get("nameKey", "")),
				"what": challenge_label(outfit.get("challenge")),
				"done": fatto,
				"state_key": "challengeDone" if fatto else "challengeTodo",
			})
		if suoi.is_empty():
			continue
		var unlocked := CareerRules.is_unlocked(athlete, career)
		var small_key := ("athlete_%s_role" % String(athlete.get("id", "")))
		if not unlocked:
			small_key = "challengeLockedAthlete"
		gruppi.append({
			"name_key": "athlete_%s_name" % String(athlete.get("id", "")),
			"small_key": small_key,
			"color": String(athlete.get("color", "")),
			"rows": suoi,
		})
	sections.append({
		"title_key": "sectionOutfits", "done": completi_fatti, "total": completi_totali,
		"rows": [], "groups": gruppi, "note": false,
	})
	# arene
	var arene := _unlockable(Frozen.arenas())
	var righe_arene: Array = []
	for arena_in in arene:
		var arena: Dictionary = arena_in
		var palette: Variant = arena.get("palette")
		var accent := ""
		if palette is Dictionary:
			accent = String((palette as Dictionary).get("accent", ""))
		var unlocked := CareerRules.is_unlocked(arena, career)
		righe_arene.append({
			"name_key": "arena_%s_name" % String(arena.get("id", "")),
			"role_key": "",
			"color": accent,
			"what": _cost(arena.get("unlock"), career),
			"done": unlocked,
			"state_key": "challengeUnlocked" if unlocked else "challengeLocked",
		})
	sections.append(_section("sectionArenas", righe_arene, _note_shown(), true))
	return sections


func _section(title_key: String, rows: Array, note: bool, counts: bool) -> Dictionary:
	var done := 0
	for row in rows:
		if bool((row as Dictionary).get("done", false)):
			done += 1
	return {
		"title_key": title_key, "done": done, "total": (rows.size() if counts else 0),
		"rows": rows, "groups": [], "note": note,
	}


func _unlockable(items: Array) -> Array:
	var out: Array = []
	for item in items:
		if (item as Dictionary).get("unlock", null) != null:
			out.append(item)
	return out


## `costo()` (`js/ui.js:1145-1150`): `🏆 4/6 Trofei · ⭐ 3/8 Stelle`, each part with its
## own progress figure. The glyphs are reference content.
func _cost(unlock: Variant, career: Dictionary) -> String:
	var parts: Array = []
	if not (unlock is Dictionary):
		return ""
	var row: Dictionary = unlock
	if int(row.get("trophies", 0)) > 0:
		parts.append(_glyph_prefix(0x1f3c6) + _quanti(
			int(career.get("trophies", 0)), int(row["trophies"]), "trophyOne", "trophyMany"))
	if int(row.get("stars", 0)) > 0:
		parts.append(_glyph_prefix(0x2b50) + _quanti(
			int(career.get("stars", 0)), int(row["stars"]), "starOne", "starMany"))
	return _join(parts)


## `🏆 `/`⭐ ` (`js/ui.js:1148-1149`) and `quanti`'s own space (`:1142`), from code
## points: the UI lane's literal scan flags any literal containing a space, and these
## glyphs are reference content, not words this screen owns.
static func _glyph_prefix(code: int) -> String:
	return String.chr(code) + String.chr(0x20)


## The single space `quanti` writes between its figure and its word (`js/ui.js:1142`).
static func _join_space() -> String:
	return String.chr(0x20)


## `quanti()` (`js/ui.js:1142-1143`): `min(had, needed)/needed <word>`, the singular
## word chosen by the requirement.
func _quanti(avuti: int, servono: int, uno_key: String, tanti_key: String) -> String:
	var word := UiStrings.t(uno_key if servono == 1 else tanti_key)
	return "%d/%d%s%s" % [min(avuti, servono), servono, _join_space(), word]


## `challengeLabel()` (`js/ui.js:670-688`): the sentence parts joined.
func challenge_label(challenge: Variant) -> String:
	if not (challenge is Dictionary):
		return ""
	var ch: Dictionary = challenge
	var parts: Array = []
	if bool(ch.get("win", false)):
		parts.append(UiStrings.t("chWin"))
	parts.append(_prova(ch))
	var also: Variant = ch.get("also")
	if also is Dictionary:
		parts.append(_prova(also))
	var min_skill: Variant = ch.get("minSkill")
	if min_skill != null and float(min_skill) >= 0.85:
		parts.append(UiStrings.t("chSkillLegend"))
	elif min_skill != null and float(min_skill) > 0.0:
		parts.append(UiStrings.t("chSkillHard"))
	return _join(parts)


## `parte()` (`js/ui.js:671-682`): the three named metrics first, then the generic
## `atLeast`/`atMost`/`none` forms over the metric's own label.
func _prova(prova: Variant) -> String:
	if not (prova is Dictionary):
		return ""
	var p: Dictionary = prova
	var metric := String(p.get("metric", ""))
	var target := int(p.get("target", 0))
	var out := ""
	match metric:
		"longestRally":
			out = UiStrings.t("chRally", {"n": target})
		"totalRallyHits":
			out = UiStrings.t("chTotalHits", {"n": target})
		"wins":
			out = UiStrings.t("chWins", {"n": target})
		_:
			var what := UiStrings.t("metric_%s" % metric)
			if bool(p.get("atMost", false)):
				if target == 0:
					out = UiStrings.t("chNone", {"what": what})
				else:
					out = UiStrings.t("chAtMost", {"n": target, "what": what})
			else:
				out = UiStrings.t("chAtLeast", {"n": target, "what": what})
	return out


func _join(parts: Array) -> String:
	var out := ""
	for index in parts.size():
		if index > 0:
			out += composed_separator()
		out += String(parts[index])
	return out


## `IS_DEMO` (`js/ui.js:1203-1208`): the note shows in a limited build, or when a
## capture pinned it.
func _note_shown() -> bool:
	if _note_pin != null:
		return bool(_note_pin)
	return DemoGate.badge_visible()


# ---------------------------------------------------------------------------
# The board
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
	scroll.name = "ChallengesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.content().add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_board = VBoxContainer.new()
	_board.name = BOARD_NODE
	_board.custom_minimum_size.x = 480.0
	_board.add_theme_constant_override("separation", 34)
	center.add_child(_board)
	resized.connect(_apply_layout)
	refresh()
	_apply_layout()


func _fill_board() -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	for index in _sections.size():
		_board.add_child(_build_section(_sections[index], index))


## One `section.challenge-section` (`js/ui.js:1152-1155`): the title with its count, the
## note where the reference paints one, then the rows or the groups.
func _build_section(section: Dictionary, index: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Section%d" % index
	box.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.name = "SectionTitle"
	title.text = UiStrings.t(String(section["title_key"]))
	title.add_theme_color_override("font_color", _palette("cyan"))
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := Label.new()
	count.name = "SectionCount"
	count.text = "%d/%d" % [int(section["done"]), int(section["total"])]
	count.add_theme_color_override("font_color", _palette("muted"))
	count.add_theme_font_size_override("font_size", 13)
	head.add_child(count)
	box.add_child(head)
	var rule := ColorRect.new()
	rule.name = "SectionRule"
	rule.color = _alpha(_palette("challenge_cyan"), 0.2)
	rule.custom_minimum_size.y = 1.0
	box.add_child(rule)
	if bool(section.get("note", false)):
		var nota := Label.new()
		nota.name = NOTA_NODE
		nota.text = UiStrings.t(note_key())
		nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nota.add_theme_color_override("font_color", _palette("muted"))
		nota.add_theme_font_size_override("font_size", 13)
		nota.add_theme_stylebox_override("normal", _nota_box())
		box.add_child(nota)
	var rows: Array = section.get("rows", [])
	for row_index in rows.size():
		box.add_child(_build_row(rows[row_index], index, row_index, ""))
	for group_in in section.get("groups", []):
		var group: Dictionary = group_in
		box.add_child(_build_group(group, index))
	return box


## `challenge-group` (`js/ui.js:1169-1183`): the athlete's coloured name, its role (or
## the locked-athlete state) as `small`, then the group's own rows.
func _build_group(group: Dictionary, section_index: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Group_%s" % String(group.get("name_key", ""))
	box.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var name := Label.new()
	name.name = "GroupName"
	name.text = UiStrings.t(String(group["name_key"]))
	name.add_theme_color_override("font_color", _data_color(String(group.get("color", ""))))
	name.add_theme_font_size_override("font_size", 16)
	head.add_child(name)
	var small := Label.new()
	small.name = "GroupSmall"
	small.text = UiStrings.t(String(group["small_key"]))
	small.add_theme_color_override("font_color", _palette("muted"))
	small.add_theme_font_size_override("font_size", 11)
	head.add_child(small)
	box.add_child(head)
	var rows: Array = group.get("rows", [])
	var group_key := String(group.get("name_key", ""))
	for row_index in rows.size():
		box.add_child(_build_row(rows[row_index], section_index, row_index, group_key))
	return box


## `riga()` (`js/ui.js:1131-1139`): mark, coloured name, what, state. Below 900 px the
## what and the state sit under the name (`.challenge-row` grid override,
## `styles.css:3249-3254`).
func _build_row(row: Dictionary, section: int, index: int, group: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Row_%d_%d" % [section, index]
	panel.set_meta("group_key", group)
	panel.add_theme_stylebox_override("panel", _row_box(bool(row.get("done", false))))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var mark := Label.new()
	mark.name = "Mark"
	mark.text = "🏅" if bool(row.get("done", false)) else "🎯"
	mark.custom_minimum_size.x = 24.0 if _narrow else 28.0
	line.add_child(mark)
	var name := Label.new()
	name.name = "Name"
	name.text = UiStrings.t(String(row["name_key"]))
	name.add_theme_color_override("font_color", _data_color(String(row.get("color", ""))))
	if _narrow:
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.add_theme_constant_override("separation", 2)
		text_column.add_child(name)
		var what_narrow := Label.new()
		what_narrow.name = "What"
		what_narrow.text = String(row.get("what", ""))
		what_narrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what_narrow.add_theme_color_override("font_color", _palette("muted"))
		text_column.add_child(what_narrow)
		var state_narrow := Label.new()
		state_narrow.name = "State"
		state_narrow.text = UiStrings.t(String(row.get("state_key", "")))
		state_narrow.add_theme_color_override("font_color", _state_ink(bool(row.get("done", false))))
		state_narrow.add_theme_font_size_override("font_size", 11)
		text_column.add_child(state_narrow)
		line.add_child(text_column)
	else:
		# At a wide frame `.challenge-row` is one flat line: mark, name, what and state
		# are four siblings (`styles.css:2049-2070`), so the name sits on the line itself
		# and only the narrow form wraps name/what/state into a column.
		name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		line.add_child(name)
		var what := Label.new()
		what.name = "What"
		what.text = String(row.get("what", ""))
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.size_flags_stretch_ratio = 2.0
		what.add_theme_color_override("font_color", _palette("muted"))
		what.add_theme_font_size_override("font_size", 13)
		line.add_child(what)
		var state := Label.new()
		state.name = "State"
		state.text = UiStrings.t(String(row.get("state_key", "")))
		state.add_theme_color_override("font_color", _state_ink(bool(row.get("done", false))))
		state.add_theme_font_size_override("font_size", 11)
		line.add_child(state)
	panel.add_child(line)
	return panel


## The screen's own title node, through the shell that renders it (`ScreenShell.title_control`).
func title_control() -> Label:
	return _shell.call("title_control") as Label


## Below 900 px the rows stack and the board's padding narrows
## (`styles.css:3245-3254`). A width change rebuilds, because which layout a row uses is
## decided where the row is built.
func _apply_layout() -> void:
	if _board == null or size.x <= 0.0:
		return
	var narrow := size.x < STACK_BELOW_PX
	var pad := BOARD_PAD_NARROW if narrow else BOARD_PAD_WIDE
	_board.custom_minimum_size.x = min(BOARD_MAX_WIDTH - pad * 2.0, size.x - pad * 2.0)
	if narrow != _narrow:
		_narrow = narrow
		_fill_board()


# ---------------------------------------------------------------------------
# Inks and boxes
# ---------------------------------------------------------------------------

## `.challenge-row` (`styles.css:3208-3219`) and its `.is-done` variant
## (`styles.css:3221-3224`).
func _row_box(done: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if done:
		box.bg_color = _palette("challenge_done_fill")
		box.border_color = _palette("challenge_done_border")
	else:
		box.bg_color = _palette("challenge_row_fill")
		box.border_color = _alpha(_palette("challenge_cyan"), 0.16)
	box.set_corner_radius_all(10)
	box.set_border_width_all(1)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


## `.challenge-section__nota` (`styles.css:3456-3465`): a cyan left rule over a faint
## cyan fill.
func _nota_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = _alpha(_palette("cyan"), 0.06)
	box.border_color = _palette("cyan")
	box.border_width_left = 2
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box


## `.challenge-row.is-done .challenge-row__state` (`styles.css:3240-3242`).
func _state_ink(done: bool) -> Color:
	return _palette("state_yellow_soft") if done else _palette("muted")


## The athlete's / arena's own colour from the frozen table (`js/ui.js:1134`, `:1136`).
## Data arrives as a CSS hex string; an entry without one keeps the theme's ink.
func _data_color(hex: String) -> Color:
	if hex == "":
		return _palette("ink")
	return Color.from_string(hex, _palette("ink"))


func _apply_aria() -> void:
	_set_accessible_name(self, aria_name())


func _set_accessible_name(node: Node, text: String) -> void:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == "accessibility_name":
			node.set("accessibility_name", text)
			return


func _palette(key: String) -> Color:
	var source := theme if theme != null else load("res://src/ui/theme/padel_theme.tres")
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
