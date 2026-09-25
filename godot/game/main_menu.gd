## main_menu.gd — the entry screen: quick match, opponent tier, athlete, outfit,
## arena, and the three mode entries.
##
## TWO LISTS OF REAL DATA (`ATHLETES`, `AI_OPPONENTS` from the frozen tables) and
## the arenas from the frozen `ARENAS` table. Everything selected here lands in
## `match_config.gd`, which the match scene reads; nothing about a tier, an athlete
## or an arena is defined in this file.
##
## WHAT THIS BUILD MAY OFFER is not decided here either: the lists come from
## `content_gate.gd`, i.e. the reference's own `demoFilter` / `demoLocked`
## (`js/build.js:58-75`) as ported by the export lane. In a demo build that means
## two athletes, one arena, the fixed difficulty and quick match only — rendered on
## screen, with the excluded modes visible and locked rather than hidden
## ("vedere cosa manca vende più che nasconderlo", `js/ui.js:734`), which is also
## what keeps the focus model from landing on them (`focus_nav.gd::_selectable`
## skips `locked`).
##
## NAVIGATION is `godot/src/input/**` (`game/menu_focus.gd` is the adapter): the
## reference's geometric target search, its no-wrap rule, its wide-target rule, its
## confirm/cancel split and its declared back rules, all audited at `PASS 4/4`,
## 308 checks. This screen no longer carries focus neighbours of its own, and the
## arrow keys and the pad are consumed here so Godot's built-in `ui_*` navigation
## cannot move the same focus a second time.
##
## STRINGS: every control hint and every locked tag resolves through
## `godot/src/input/strings.gd` -> `godot/src/locale/**`. This file owns no literal
## the player reads except the title and the mode labels, which come from the
## locale table by id.
##
## `--capture=menu` renders the screen, writes `res://game/out/<out>.png`
## (`--out=<name>`, default `menu`) and exits 0; that is the screenshot path used by
## `godot/game/run.sh` and by the demo-vs-full comparison in the evidence file.
extends Control

const Config := preload("res://game/match_config.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Locale := preload("res://src/locale/locale.gd")
const Gate := preload("res://game/content_gate.gd")
const InputStrings := preload("res://src/input/strings.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
## The shared right-stick scroll: one instance per UI scene, one `update()` per frame.
## The stick that scrolls a long screen, over whichever container is up.
const ControllerScroll := preload("res://src/ui/focus/controller_scroll.gd")
## The world-arena set (port additions). Only `is_world` is used here: the list
## itself always comes from `Config.selectable_world_arenas()`.
const Arena := preload("res://game/arenas/arena_library.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
## The Emporio OST's economy service: the host initializes it at boot (before any
## other group is written) and mounts its shop overlay.
const Economy := preload("res://src/economy/economy_service.gd")
const InputSource := preload("res://game/input_map.gd")
## The verified audio module, for the one job the host has in it: applying the stored
## master volume at boot (`js/main.js:2278`). The bus derivation stays in the module.
const AudioPortScript := preload("res://src/audio/audio_port.gd")
const MusicSettings := preload("res://src/audio/music_settings.gd")

const TIER_NAMES := ["Rivale del Circuito", "Ingegnere del Vapore", "Campione Steampunk", "Leggenda del Circuito"]
## The three mode entries: the keyboard/pad action id, the locale id of the label,
## and the mode id `ModeScreen` opens. "quick" is the play button, not a mode entry:
## the reference's menu has three mode cards and the quick one is where PLAY leads.
const MODE_ENTRIES := [
	{"mode": "drill", "label_id": "training"},
	{"mode": "tournament", "label_id": "tournamentMode"},
	{"mode": "career", "label_id": "careerMode"},
]

var _tier_buttons: Array[Button] = []
var _athlete_buttons: Array[Button] = []
var _arena_buttons: Array[Button] = []
## The world-arena row (port additions, full build only). Plain buttons, NOT
## toggle buttons: the frozen row's contract is one toggle per exposed arena
## (`game_slice_test.gd` counts them against `selectable_arenas()`), and the
## world set is additive content selected by id.
var _world_arena_buttons: Array[Button] = []
## The special-athlete strip (port additions, full build only). The same contract
## shape as the world row: plain buttons selected by id, never toggles, so the
## slice's own counts over the frozen rows are untouched. They live in the same
## column as the world arenas — this strip's own labelled block, not a row of the
## frozen ATLETA column whose count the slice pins.
var _special_athlete_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _info: Label
var _seed_label: Label
var _outfit_button: Button
var _play: Button
var _focus: MenuFocus
## The right stick's own helper (`src/ui/focus/controller_scroll.gd`): built once per
## UI scene, fed one surface per frame. It reads `JOY_AXIS_RIGHT_Y` and writes
## `ScrollContainer.scroll_vertical`, and it decides nothing the focus model owns.
var _controller_scroll: RefCounted = null
var _scroll_window_active := true
var _capture := false
## UIR-22's switch, and the playable host. `--ui=new` (the default) mounts the
## recreated screens — all twelve Control screens the router's table has a scene for —
## and drives them through the port's verified input model (`game/menu_focus.gd` +
## `src/ui/focus/UiFocusBridge.gd`). `--ui=legacy` keeps the ported menu column below,
## byte for byte, as the diagnostic fallback the suite and the demo-vs-full captures
## read. UIR-24's harnesses set this property before `_ready()` instead of passing the
## flag, so they mount the same host the game does.
var ui_prototype := false
## The explicit opt-out. `tests/game_slice_test.gd` asserts the PORTED column's own
## contract (its rows, its play button, its `screen_report`), so it sets this before
## `_ready()` — the same way the UIR-24 harnesses set `ui_prototype` — and gets the
## legacy construction, whatever the command line says. Nothing in the game sets it.
var ui_legacy := false
var _router: Control = null
## True once the playable host is mounted (the recreated path). Every branch below
## that has two shapes asks this flag once.
var _playable := false
## The feedback transport (`src/feedback/feedback_delivery.gd`), or null in a run that
## must not post. It is owned by this host — not by the feedback screen — so a message
## whose send is still in flight when the player leaves the form is still delivered and
## its confirmation still written. `_arm_feedback_delivery()` is the only place it is
## built, and it refuses to build one for a headless or capture run.
var _feedback_delivery: Node = null
## UIR-05's bridge over the same `_focus` model the ported column uses: the screens
## declare their controls, the model decides, and the bridge turns a verdict into a
## `ScreenRouter.go_to` or one of its two signals.
var _bridge: RefCounted = null
var _restore_menu_focus: String = ""
## UIR-26's on-screen keyboard, mounted over everything (the recipe in
## `src/ui/screens/OskPanel.gd`): the panel renders the input lane's own OSK model.
var _osk_panel: Control = null
var _jukebox_overlay: Control = null
var _runtime_ost: Node = null
var _jukebox_button: Button = null
## The Emporio OST shop, mounted the same way the Jukebox is (an overlay over the menu,
## driven by its own Back/Escape and the host's right-stick surface).
var _emporio_overlay: Control = null
var _emporio_button: Button = null
## The audio module instance the host applies the stored master volume through. Built
## once, lazily, by `_apply_stored_audio_prefs()`.
var _audio_port: Node = null
## Frames to wait before re-measuring the model after a screen swap: a container
## sorts at the end of the frame that mounted it, so the first rectangles are wrong
## by construction.
var _refresh_pending := 0
var _out_name := "menu"
var _pad_seen := false
## The seat the menus read, remembered across frames so `selectPrimaryGamepad`'s rule
## ("the pad somebody touches takes over, the current one is kept while nobody does")
## has a current to fall back to. `NO_DEVICE` until a pad shows up.
var _pad_device := InputSource.NO_DEVICE
## The column the focus model measures, and the laid-out size it was last refreshed
## at. A container sorts at the end of the frame that built it, so the rectangles
## `_ready()` refreshes with are the pre-layout ones.
var _column: Control
var _layout_seen := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Emporio OST: initialize the economy group FIRST, before anything below can write
	# prefs or career. The legacy-vs-new decision reads the reference groups' FILES, so a
	# brand-new profile must be initialized while the profile is still empty — a later
	# init would see its own prefs/career and falsely grandfather all 47 OSTs.
	_init_economy()
	_runtime_ost = preload("res://src/audio/runtime_soundtrack.gd").new()
	add_child(_runtime_ost)
	_runtime_ost.music_enabled_changed.connect(_on_music_enabled_changed)
	_runtime_ost.set_screen("menu")
	_capture = "--capture=menu" in OS.get_cmdline_user_args()
	_out_name = _arg("--out=", "menu")
	ui_prototype = (not ui_legacy) and (ui_prototype or _arg("--ui=", "new") != "legacy")
	if ui_prototype:
		# The playable path builds the recreated screens instead of the ported column:
		# one at a time, owned by the router, and the ported construction is not built
		# at all (so nothing of it can show through).
		_mount_ui_prototype()
		if _capture:
			_run_capture()
		return
	# `applyDemoLimits` (`js/ui.js:736-756`) before anything is built: the demo pins
	# the difficulty, the athlete and the arena, so the screen never has to render a
	# selection the build does not grant.
	var limits := Config.apply_build_limits()
	if not limits.is_empty():
		print("MENU_BUILD_LIMITS %s" % JSON.stringify(limits))

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.063, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.name = "MenuMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.name = "MenuColumn"
	# Separation 4 rather than 6, plus the mode row: the column still has to fit a
	# 1152x648 window as well as the 1280x720 the captures use — measured, not
	# guessed, by the fit assertion in `tests/game_slice_test.gd`.
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)

	_focus = MenuFocus.new()
	set_process_input(true)
	_setup_controller_scroll()

	var title := _label("STEAM CIRCUIT PADEL PRO", 34, Color(0.0, 0.898, 1.0))
	col.add_child(title)
	var sub := _label("Port Godot 4.7.2 — %s. Regole, fisica e taratura sono il core S1 già verificato." % Gate.label(), 17, Color(0.72, 0.78, 0.86))
	col.add_child(sub)

	var lists := HBoxContainer.new()
	lists.add_theme_constant_override("separation", 40)
	col.add_child(lists)

	# --- opponent tier column -------------------------------------------------
	var tier_col := VBoxContainer.new()
	tier_col.add_theme_constant_override("separation", 8)
	lists.add_child(tier_col)
	var tier_group := ButtonGroup.new()
	var tiers: Array = Frozen.ai_opponents()
	var locked_tier := Gate.is_demo()
	var fixed_tier := Gate.fixed_tier_index()
	tier_col.add_child(_label("AVVERSARIO (%d livelli%s)" % [
		tiers.size(), " · difficoltà fissa" if locked_tier else ""], 19, Color(1.0, 0.821, 0.4)))
	for i in tiers.size():
		var tier: Dictionary = tiers[i]
		# The stat labels are the REFERENCE'S OWN ids (`statSpeed`, `statPower`,
		# `ability`), not English words typed here: this row used to read
		# "skill … speed … power" beside the athlete row's "vel … pot … ctrl",
		# so one screen spoke two languages. `statSpeed`/`statPower` are the two
		# roster stats the tier table actually carries; an AI tier's accuracy has
		# no stat id of its own in the reference (`js/ui.js:636` feeds it as
		# `state.ai.skill`), so it prints the reference's `ability` label.
		var b := _choice_button(
			"%s  ·  %s %.2f · %s %d · %s %.2f" % [
				TIER_NAMES[i] if i < TIER_NAMES.size() else String(tier["name"]),
				Locale.t("ability"), float(tier["skill"]),
				Locale.t("statSpeed"), int(tier["speed"]),
				Locale.t("statPower"), float(tier["power"]),
			],
			tier_group, i == Config.tier_index,
			# The demo runs one difficulty (`js/ui.js:751`); the others are shown
			# disabled, exactly like the reference's difficulty segmented buttons.
			locked_tier and i != fixed_tier
		)
		b.pressed.connect(_on_tier.bind(i))
		tier_col.add_child(b)
		_tier_buttons.append(b)
		_register("tier:%d" % i, b, "tier:%d" % i, locked_tier and i != fixed_tier)

	# --- athlete column -------------------------------------------------------
	var athlete_col := VBoxContainer.new()
	athlete_col.add_theme_constant_override("separation", 8)
	lists.add_child(athlete_col)
	var roster: Array = Config.selectable_athletes()
	athlete_col.add_child(_label("ATLETA (%d)" % roster.size(), 19, Color(1.0, 0.821, 0.4)))
	var athlete_group := ButtonGroup.new()
	var full_roster: Array = Frozen.athletes()
	for i in roster.size():
		var athlete: Dictionary = roster[i]
		var stats: Dictionary = athlete["stats"]
		var full_index := Gate.index_in(full_roster, athlete)
		# Same three ids the reference prints for a roster entry (`statSpeed`,
		# `statPower`, `statControl`), so both columns of the menu say "VEL / POT /
		# CTR" in Italian and "SPD / PWR / CTL" in English — one language per screen.
		var b := _choice_button(
			"%s  ·  %s %.2f · %s %.2f · %s %.2f" % [
				String(athlete["name"]),
				Locale.t("statSpeed"), float(stats["speed"]),
				Locale.t("statPower"), float(stats["power"]),
				Locale.t("statControl"), float(stats["control"]),
			],
			athlete_group, full_index == Config.athlete_index
		)
		b.pressed.connect(_on_athlete.bind(full_index))
		athlete_col.add_child(b)
		_athlete_buttons.append(b)
		_register("athlete:%d" % full_index, b, "athlete:%d" % full_index)

	# --- world arena column (port additions) ----------------------------------
	# The five world arenas (`arena_style.gd`, `family: "world"`) have no frozen
	# row and no seat in the frozen arena row below: a FULL build offers them as
	# this setup column, a demo offers none of them
	# (`Config.selectable_world_arenas()` is empty there, so the column is not
	# built at all). It lives HERE, beside AVVERSARIO and ATLETA, and not as a
	# row of its own: this column's slot already has the vertical space (the
	# athlete column sets the row's height at 261 px, this one needs 184), while
	# a new row measured 677 px against the 1152x648 frame the fit assertion in
	# `game_slice_test.gd` measures — the screen's vertical budget is spent to
	# the pixel (separation 4, the mode title moved out of its row), and the fit
	# check is not the thing to change. Width is the other half of that budget:
	# the column is 90 px wide, so the setup row grows from 914 to 1044 against
	# the 1056 the frame allows, and the arena row below stays the widest row.
	# Plain buttons, never toggle buttons: the frozen arena row's own contract —
	# one toggle per exposed arena, counted by `game_slice_test.gd` — stays
	# exactly what it was. The selection lands in `match_config.gd`'s world seat
	# (`_on_world_arena`), the tooltip carries the same facts as the frozen
	# row's, and the active one is marked on the button itself
	# (`_apply_selection_state`).
	var world_list: Array = Config.selectable_world_arenas()
	# The special-athlete strip (port additions) rides the SAME column, as its own
	# labelled block: a column of its own did not fit the setup row's width budget
	# (see the block comment above — 1044 of the 1056 px a 1152x648 frame allows),
	# and the column has the vertical slack. One column, two labelled blocks; the
	# node names and the selection handler of each stay its own.
	var special_list: Array = Config.selectable_special_athletes()
	var world_col: VBoxContainer = null
	if not world_list.is_empty() or not special_list.is_empty():
		world_col = VBoxContainer.new()
		world_col.add_theme_constant_override("separation", 8)
		lists.add_child(world_col)
	if not world_list.is_empty():
		var world_head := _label("MONDI (%d)" % world_list.size(), 16, Color(0.0, 0.898, 1.0))
		world_col.add_child(world_head)
		for i in world_list.size():
			var arena: Dictionary = world_list[i]
			var arena_id := String(arena["id"])
			var b := Button.new()
			b.name = "WorldArena_%s" % arena_id
			b.text = _arena_label(arena)
			b.focus_mode = Control.FOCUS_ALL
			b.add_theme_font_size_override("font_size", 12)
			b.custom_minimum_size = Vector2(90.0, 26.0)
			b.clip_text = true
			b.tooltip_text = "%s (%s) — %s · wallBounce %.2f (provisional) · floorGrip %.2f" % [
				String(arena["name"]), arena_id, String(arena["desc"]),
				float(arena["wallBounce"]), float(arena["floorGrip"]),
			]
			b.pressed.connect(_on_world_arena.bind(arena_id))
			world_col.add_child(b)
			_world_arena_buttons.append(b)
			_register("arena:%s" % arena_id, b, "arena:%s" % arena_id)

	# --- special-athlete strip (port additions) -------------------------------
	# The Godot-only specials (`src/character/specials.gd`, `Config.selectable_special_athletes()`;
	# one in a full build, none in a demo) get their OWN labelled block — never a
	# row of ATLETA, whose label's count and whose toggle buttons the slice pins to
	# the frozen roster, and never a merge into `Config.selectable_athletes()`. The
	# button is selected by id through `Config.set_special_athlete_id` and marked on
	# the button itself (`_apply_selection_state`), exactly like a world arena. The
	# name is the overlay's own (`IL FORNAIO`); the tooltip says out loud that the
	# on-court body is a stand-in until the owner drops a Meshy export.
	if not special_list.is_empty():
		world_col.add_child(_label("SPECIAL (%d)" % special_list.size(), 16, Color("d98e2b")))
		for i in special_list.size():
			var athlete: Dictionary = special_list[i]
			var athlete_id := String(athlete["id"])
			var b := Button.new()
			b.name = "SpecialAthlete_%s" % athlete_id
			b.text = String(athlete["name"])
			b.focus_mode = Control.FOCUS_ALL
			b.add_theme_font_size_override("font_size", 12)
			b.custom_minimum_size = Vector2(90.0, 26.0)
			b.clip_text = true
			b.tooltip_text = "%s (%s) — %s · %s" % [
				String(athlete["name"]), athlete_id, String(athlete.get("role", "")),
				String(athlete.get("stand_in_note", "")),
			]
			b.pressed.connect(_on_special_athlete.bind(athlete_id))
			world_col.add_child(b)
			_special_athlete_buttons.append(b)
			_register("athlete:%s" % athlete_id, b, "athlete:%s" % athlete_id)

	_info = _label("", 16, Color(0.80, 0.86, 0.92))
	col.add_child(_info)

	# --- mode row -------------------------------------------------------------
	# The reference's three mode cards (`index.html:108-125`). Quick match is the
	# play button below; the other three open their own screens. In a demo build the
	# excluded modes stay visible and locked, as `applyDemoLimits` renders them, and
	# the focus model skips a locked target.
	# The section title is on its OWN line rather than in the row: inside the row it
	# reserved 118 px of the width the three mode buttons have to share, which is
	# what made a locked row 24 px too narrow for `TORNEO CAMPIONATO — Nella
	# versione completa` at 1280x720 and 66 px too narrow at 1152x648 (measured by
	# the fit check in `tests/game_slice_test.gd`, and the reason the demo printed
	# `Nella versione completa` as `Nella versione complet`). The title does not
	# need to be in the row to label it.
	#
	# The title itself is the REFERENCE'S OWN string (`modesTitle`, `js/i18n.js`:
	# "MODALITÀ DI GIOCO" in Italian, "GAME MODES" in English) and not a literal.
	# The screen used to print "MODALITA'" — an ASCII apostrophe standing in for
	# `À` — which is a defect in the SOURCE STRING, not a font gap: the shipped
	# font carries `À` (the glyph check in `tests/game_slice_test.gd` measures it).
	# Reading the title from the table means it cannot drift from the reference and
	# cannot lose an accent again.
	col.add_child(_label(Locale.t("modesTitle"), 18, Color(1.0, 0.821, 0.4)))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	col.add_child(mode_row)
	for entry in MODE_ENTRIES:
		var mode_id := String(entry["mode"])
		var locked: bool = Gate.is_demo() and not Config.mode_ids().has(mode_id)
		var label := Locale.t(String(entry["label_id"]))
		var b := Button.new()
		b.name = "Mode_%s" % mode_id
		b.text = label if not locked else "%s — %s" % [label, Locale.t(Gate.locked_key())]
		b.toggle_mode = false
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = locked
		# 13 px and no `clip_text`: the row must FIT its longest label with room to
		# spare, not trim it. (14 px left the widest demo row exactly 0 px of slack
		# at 1152x648 — measured, not guessed.)
		# Clipping is what hid this defect — `In the full game`/`Nella versione
		# completa` was cut to `… complet` and the screen looked fine. With the
		# label unclipped an overflow is visible on screen, and the fit assertion in
		# `tests/game_slice_test.gd` fails before it can become visible.
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(180.0, 28.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not locked:
			b.pressed.connect(_open_mode.bind(mode_id))
		mode_row.add_child(b)
		_mode_buttons.append(b)
		_register("mode:%s" % mode_id, b, "mode:%s" % mode_id, locked)

	# --- arena row ------------------------------------------------------------
	# One button per arena this build exposes, in the frozen table's own order,
	# labelled with the reference's own name key (`arena_<id>_name`, the key
	# `js/render.js:906` draws on the canvas) resolved through the locale layer.
	# `clip_text` makes "a long label cannot push the row wider than the frame"
	# structural.
	var arena_row := HBoxContainer.new()
	arena_row.add_theme_constant_override("separation", 6)
	col.add_child(arena_row)
	var arena_list: Array = Config.selectable_arenas()
	var arena_title := _label("ARENA (%d)" % arena_list.size(), 19, Color(1.0, 0.821, 0.4))
	arena_title.custom_minimum_size = Vector2(118.0, 0.0)
	arena_row.add_child(arena_title)
	var arena_group := ButtonGroup.new()
	var full_arenas: Array = Frozen.arenas()
	for i in arena_list.size():
		var arena: Dictionary = arena_list[i]
		var full_index := Gate.index_in(full_arenas, arena)
		var b := _choice_button(_arena_label(arena), arena_group, full_index == Config.arena_index)
		b.name = "Arena_%s" % String(arena["id"])
		b.add_theme_font_size_override("font_size", 13)
		# 90 px minimum and an equal share of the row's surplus: without a real
		# minimum the buttons collapse to their clip width (8 px) and the row renders
		# as unlabelled stubs.
		b.custom_minimum_size = Vector2(90.0, 30.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var name_key := "arena_%s_name" % String(arena["id"])
		var shown := Locale.t(name_key) if Locale.is_resolvable(name_key) else String(arena["name"])
		b.tooltip_text = "%s (%s) — %s · wallBounce %.2f · floorGrip %.2f" % [
			shown, String(arena["id"]), String(arena["desc"]),
			float(arena["wallBounce"]), float(arena["floorGrip"]),
		]
		b.pressed.connect(_on_arena.bind(full_index))
		arena_row.add_child(b)
		_arena_buttons.append(b)
		_register("arena:%s" % String(arena["id"]), b, "arena:%s" % String(arena["id"]))

	# --- actions --------------------------------------------------------------
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	col.add_child(actions)
	var play := Button.new()
	_play = play
	play.name = "PlayButton"
	play.text = "GIOCA PARTITA RAPIDA"
	play.add_theme_font_size_override("font_size", 24)
	play.custom_minimum_size = Vector2(330.0, 46.0)
	play.pressed.connect(start_match)
	actions.add_child(play)
	_register("play", play, "play")
	# The outfit of the athlete being played. One button cycling that athlete's own
	# outfits (`AthleteSpawn.outfit_ids`), named by the reference's own locale ids
	# (`outfitBase`, `outfitLegend`, ...). The match applies it in place through
	# `AthleteSpawn.set_outfit` -- no respawn, no new scene.
	_outfit_button = Button.new()
	_outfit_button.name = "OutfitButton"
	_outfit_button.add_theme_font_size_override("font_size", 16)
	_outfit_button.custom_minimum_size = Vector2(300.0, 46.0)
	_outfit_button.clip_text = true
	_outfit_button.pressed.connect(_on_outfit)
	actions.add_child(_outfit_button)
	_register("outfit", _outfit_button, "outfit")
	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = "ESCI"
	quit.add_theme_font_size_override("font_size", 20)
	quit.custom_minimum_size = Vector2(140.0, 46.0)
	quit.pressed.connect(_quit)
	actions.add_child(quit)
	_register("quit", quit, "quit")

	_seed_label = _label("", 15, Color(0.60, 0.66, 0.74))
	col.add_child(_seed_label)
	# The control hints, through the input lane's locale seam: `padHints1` is the
	# pad's gameplay legend and `padMenuHint` the menu navigation line, both the
	# reference's own ids (`js/i18n.js:206,329`). This screen owns no literal here.
	col.add_child(_label("%s\n%s" % [
		InputStrings.text("padHints1"), InputStrings.text(InputStrings.MENU_HINT),
	], 15, Color(0.66, 0.72, 0.80)))

	_refresh_info()
	_apply_selection_state()
	# The focus model needs the laid-out rectangles, so it is registered after the
	# tree is built and refreshed once the containers have placed their children.
	# `_ready()` is still too early for the real ones: a container sorts through the
	# `MessageQueue` at the END of the frame that built it, so every row is at the
	# origin here. `_process` re-refreshes the moment the column's laid-out size
	# changes — the first frame that happens, and again after a window resize.
	_column = col
	_focus.refresh()
	_focus.ensure_focus()
	_focus.pad_connected(_pad_connected())
	_apply_focus()

	if _capture:
		_run_capture()


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


## UIR-22's playable host: the router owns which screen is up and every recreated
## Control screen is registered under the router's own id. The ported column below is
## not built at all in this path (so nothing of it can show through), and the same
## `game/menu_focus.gd` model drives the screens through UIR-05's bridge — the one
## construction every screen audit already proved.
##
## `game` — the thirteenth id — has no scene here on purpose: the match is
## `Match.tscn`, a 3D scene the router cannot own as a Control. It is reached the way
## the screens' own start routes reach it (`ArenaScreen.start_match`,
## `DrillScreen.start`, `ModesScreen` -> `characters` -> `arena`), through
## `Config.pending_mode`, and the result comes back through `Config.pending_result`.
const SCREEN_SCENES := {
	"menu": "res://src/ui/screens/MenuScreen.tscn",
	"characters": "res://src/ui/screens/CharactersScreen.tscn",
	"modes": "res://src/ui/screens/ModesScreen.tscn",
	"arena": "res://src/ui/screens/ArenaScreen.tscn",
	"help": "res://src/ui/screens/HelpScreen.tscn",
	"history": "res://src/ui/screens/HistoryScreen.tscn",
	"challenges": "res://src/ui/screens/ChallengesScreen.tscn",
	"profile": "res://src/ui/screens/ProfileScreen.tscn",
	"feedback": "res://src/ui/screens/FeedbackScreen.tscn",
	"drill": "res://src/ui/screens/DrillScreen.tscn",
	"settings": "res://src/ui/screens/SettingsScreen.tscn",
	"result": "res://src/ui/screens/ResultScreen.tscn",
}


## UIR-22's playable host: the router owns which screen is up and every recreated
## Control screen is registered under the router's own id. The ported column below is
## not built at all in this path (so nothing of it can show through), and the same
## `game/menu_focus.gd` model drives the screens through UIR-05's bridge — the one
## construction every screen audit already proved.
##
## `game` — the thirteenth id — has no scene here on purpose: the match is
## `Match.tscn`, a 3D scene the router cannot own as a Control. It is reached the way
## the screens' own start routes reach it (`ArenaScreen.start_match`,
## `DrillScreen.start`, `ModesScreen` -> `characters` -> `arena`), through
## `Config.pending_mode`, and the result comes back through `Config.pending_result`.
## Loaded in `_mount_ui_prototype`, not preloaded: a `--ui=legacy` run must not pull
## twelve screens and their theme in behind its back.
func _mount_ui_prototype() -> void:
	_playable = true
	var bg := ColorRect.new()
	bg.name = "PrototypeBackground"
	var ui_theme := load("res://src/ui/theme/padel_theme.tres") as Theme
	bg.color = ui_theme.get_color("bg", "Palette") if ui_theme != null else Color(0.027, 0.027, 0.165)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_add_menu_glow(ui_theme)
	# Loaded, not preloaded: the slice gate counts every object the engine holds at
	# the end of a run, and a `--ui=legacy` run must not pull twelve screens + theme
	# in behind its back.
	_router = (load("res://src/ui/ScreenRouter.gd") as GDScript).new()
	_router.name = "UiRouter"
	add_child(_router)
	for id in SCREEN_SCENES:
		if not _router.register(String(id), load(String(SCREEN_SCENES[id])) as PackedScene):
			push_error("main_menu: the router refused the '%s' scene" % id)
	# The ported mode scene is NOT registered: it is not a UIR-03 screen and mounting
	# it would fire its own `--capture` lane under the harness's feet (the measured
	# 01:24 run `tests/ui/capture_ui.gd` documents). `modes` above is the recreation.
	_focus = MenuFocus.new()
	set_process_input(true)
	_setup_controller_scroll()
	_bridge = (load("res://src/ui/focus/UiFocusBridge.gd") as GDScript).new()
	_bridge.range_changed.connect(_on_range_changed)
	# The bridge reports what it did not route; without these two connections a
	# reported action went nowhere. That is what made the mode cards, the rungs, the
	# team slots' Atleta/Completo commands and the arena cards dead to a pad confirm
	# while the same press with a mouse worked — the screens' own handlers were never
	# called (`ModesScreen.activate()` documents the door the mount has to use).
	_bridge.action_requested.connect(_on_action_requested)
	_bridge.back_requested.connect(_on_back_requested)
	_router.screen_changed.connect(_on_screen_changed)
	# UIR-26's keyboard, over everything (z 60 in the reference), bound to the input
	# lane's own model — the one `menu_nav.confirm()` opens.
	var panel_scene := load("res://src/ui/screens/OskPanel.tscn") as PackedScene
	_osk_panel = panel_scene.instantiate()
	_osk_panel.name = "OskPanel"
	add_child(_osk_panel)
	_osk_panel.bind_model(_focus.menu.osk)
	_osk_panel.closed.connect(_on_osk_closed)
	_create_jukebox_button()
	_create_emporio_button()
	# One locale drives the menu and the match HUD (UIR-22): the player's stored
	# choice is applied once, here, and nothing below switches language behind it.
	_apply_stored_language()
	# The stored mixer/input prefs go on at the same moment (`js/main.js:2276-2278`),
	# so a value the settings screen wrote is already in force before any screen reads
	# it — including the language above, which the reference applies in the same block.
	_apply_stored_audio_prefs()
	# The feedback transport exists BEFORE the first route is mounted: a launch that goes
	# straight back to the feedback form (`Config.pending_menu_screen`) has to be handed a
	# transport by its own mount, and the launch queue retry belongs to the same moment.
	# A headless or capture run still arms nothing (`_arm_feedback_delivery`).
	_arm_feedback_delivery()
	# A finished match left its payload behind; everything else starts at the menu.
	if Config.pending_result.is_empty():
		var destination := Config.pending_menu_screen if Config.pending_menu_screen != "" else "menu"
		Config.pending_menu_screen = ""
		if not _router.go_to(destination):
			push_error("main_menu: the router refused to mount the menu screen")
	else:
		var payload := Config.take_pending_result()
		if not _router.go_to("result", payload):
			push_error("main_menu: the router refused to mount the result screen")
	_on_screen_changed("", String(_router.active_id()))
	_refresh_pending = 2


## The feedback transport, built once per playable run and owned here.
##
## A HEADLESS OR CAPTURE RUN NEVER ARMS IT, and that is the whole guard: the endpoint is
## a real address, so an automated pass over the menu — an audit, a screenshot lane, the
## slice gate — must not be able to post a message or write a confirmation. With no
## transport the form keeps the honest save-and-copy ladder it ships with.
##
## Called once, before the first route is mounted, so the launch retry below is not racing
## the feedback screen's own mount: a relaunch that asks to reopen the feedback form gets
## a screen whose transport is already there. `PLAN.md`'s "Al riavvio ritentare le voci
## pendenti una volta, senza loop aggressivi" is that one retry — the transport itself
## refuses a second pass (`boot_retry`), so this is not a poll — and because the screen is
## bound to the transport's own signal, this run's verdict still reaches it if it was the
## screen the launch opened.
func _arm_feedback_delivery() -> void:
	if DisplayServer.get_name() == "headless" or _capture:
		return
	var script := load("res://src/feedback/feedback_delivery.gd") as GDScript
	if script == null:
		push_error("main_menu: the feedback transport did not load")
		return
	var delivery: Node = script.new()
	delivery.name = "FeedbackDelivery"
	add_child(delivery)
	# Read from the script's own constant map instead of repeating the address: one
	# source for the endpoint, and a rename cannot leave this copy behind.
	var endpoint := String(script.get_script_constant_map().get("ENDPOINT", ""))
	if endpoint == "":
		push_error("main_menu: the feedback transport declares no endpoint")
		delivery.queue_free()
		return
	delivery.call("configure", endpoint)
	_feedback_delivery = delivery
	delivery.call("boot_retry")


## `styles.css:24-26` body background: two radial washes over `--bg`. Loaded, not
## preloaded: `--ui=legacy` never reaches this mount.
func _add_menu_glow(ui_theme: Theme) -> void:
	if ui_theme == null:
		return
	_add_radial_wash("MenuGlowCyan", ui_theme.get_color("cyan", "Palette"), 0.18, Vector2(0.12, 0.42), Vector2(720, 520))
	_add_radial_wash("MenuGlowGold", ui_theme.get_color("gold", "Palette"), 0.12, Vector2(0.88, 0.52), Vector2(560, 560))


func _add_radial_wash(node_name: String, color: Color, alpha: float, anchor: Vector2, size: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(size.x)
	tex.height = int(size.y)
	var wash := TextureRect.new()
	wash.name = node_name
	wash.texture = tex
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.anchor_left = clampf(anchor.x - 0.28, 0.0, 1.0)
	wash.anchor_top = clampf(anchor.y - 0.32, 0.0, 1.0)
	wash.anchor_right = clampf(anchor.x + 0.28, 0.0, 1.0)
	wash.anchor_bottom = clampf(anchor.y + 0.32, 0.0, 1.0)
	wash.offset_left = 0.0
	wash.offset_top = 0.0
	wash.offset_right = 0.0
	wash.offset_bottom = 0.0
	add_child(wash)


func _create_jukebox_button() -> void:
	if _jukebox_button != null:
		return
	_jukebox_button = Button.new()
	_jukebox_button.name = "JukeboxLaunchButton"
	_jukebox_button.text = "🎵 Jukebox [J]"
	var theme_res = load("res://src/ui/theme/padel_theme.tres")
	if theme_res is Theme:
		_jukebox_button.theme = theme_res
	_jukebox_button.theme_type_variation = &"SegmentedInactive"
	_jukebox_button.custom_minimum_size = Vector2(130, 36)
	_jukebox_button.anchor_left = 1.0
	_jukebox_button.anchor_top = 0.0
	_jukebox_button.anchor_right = 1.0
	_jukebox_button.anchor_bottom = 0.0
	# Separated to the left of the 3 top nav buttons (Profile, Settings, Lang)
	_jukebox_button.offset_left = -370
	_jukebox_button.offset_top = 15
	_jukebox_button.offset_right = -230
	_jukebox_button.offset_bottom = 51
	_jukebox_button.z_index = 50
	_jukebox_button.pressed.connect(toggle_jukebox)
	add_child(_jukebox_button)


func toggle_jukebox() -> void:
	if _jukebox_overlay != null and is_instance_valid(_jukebox_overlay):
		_jukebox_overlay.queue_free()
		_jukebox_overlay = null
		return
	var scene := load("res://src/ui/jukebox/JukeboxScreen.tscn") as PackedScene
	if scene != null:
		_jukebox_overlay = scene.instantiate()
		_jukebox_overlay.z_index = 100
		# Emporio OST: the Jukebox gates playback on ownership, so it reads the same store
		# and can ask the host for the shop when a locked track is chosen.
		if _jukebox_overlay.has_method("set_store"):
			_jukebox_overlay.call("set_store", Config.save_store())
		if _jukebox_overlay.has_signal("shop_requested"):
			_jukebox_overlay.connect("shop_requested", _on_jukebox_shop_requested)
		_jukebox_overlay.closed.connect(func():
			if _jukebox_overlay != null and is_instance_valid(_jukebox_overlay):
				_jukebox_overlay.queue_free()
				_jukebox_overlay = null
		)
		add_child(_jukebox_overlay)


## Emporio OST boot step: initialize the economy save group once, before any other
## group is written. Idempotent, and never fatal — a refused or unwritable economy file
## leaves the shop empty rather than failing the menu (the service reports the reason).
func _init_economy() -> void:
	var result: Dictionary = Economy.ensure_initialized(Config.save_store())
	if not bool(result.get("ok", false)):
		push_warning("main_menu: economy init: %s" % String(result.get("reason", "")))
		return
	if bool(result.get("granted", false)):
		print("EMPORIO economy initialized: %s" % String(result.get("reason", "")))


## The Emporio OST shop button, beside the Jukebox one. Same construction, same corner.
func _create_emporio_button() -> void:
	if _emporio_button != null:
		return
	_emporio_button = Button.new()
	_emporio_button.name = "EmporioLaunchButton"
	_emporio_button.text = "🛒 Emporio [E]"
	var theme_res = load("res://src/ui/theme/padel_theme.tres")
	if theme_res is Theme:
		_emporio_button.theme = theme_res
	_emporio_button.theme_type_variation = &"SegmentedInactive"
	_emporio_button.custom_minimum_size = Vector2(130, 36)
	_emporio_button.anchor_left = 1.0
	_emporio_button.anchor_top = 0.0
	_emporio_button.anchor_right = 1.0
	_emporio_button.anchor_bottom = 0.0
	# To the left of the Jukebox button (which sits at -370..-230).
	_emporio_button.offset_left = -510
	_emporio_button.offset_top = 15
	_emporio_button.offset_right = -370
	_emporio_button.offset_bottom = 51
	_emporio_button.z_index = 50
	_emporio_button.pressed.connect(toggle_emporio)
	add_child(_emporio_button)
	# The pad must be able to REACH the shop from the initial menu, so the button joins
	# the focus list. In the playable path the bridge owns that list and rebuilds it from
	# the mounted screen on every swap (`UiFocusBridge._sync` clears the model), so the
	# registration is re-applied in `_on_screen_changed`; the ported column uses the
	# model directly.
	_ensure_emporio_focus()


## (Re-)register the Emporio launch button with whichever focus owner is live. The
## action is handled in `_on_action_requested`.
func _ensure_emporio_focus() -> void:
	if _emporio_button == null:
		return
	if _playable and _bridge != null:
		_bridge.register("emporio", _emporio_button, "emporio")
	elif _focus != null:
		_register("emporio", _emporio_button, "emporio")


func toggle_emporio() -> void:
	if _emporio_overlay != null and is_instance_valid(_emporio_overlay):
		_emporio_overlay.call("_stop_preview")
		_emporio_overlay.queue_free()
		_emporio_overlay = null
		if is_instance_valid(_runtime_ost):
			_runtime_ost.set_held(is_instance_valid(_jukebox_overlay))
		return
	var scene := load("res://src/ui/screens/EmporioScreen.tscn") as PackedScene
	if scene == null:
		return
	_emporio_overlay = scene.instantiate()
	_emporio_overlay.z_index = 100
	if _emporio_overlay.has_method("set_store"):
		_emporio_overlay.call("set_store", Config.save_store())
	_emporio_overlay.closed.connect(func():
		if _emporio_overlay != null and is_instance_valid(_emporio_overlay):
			_emporio_overlay.queue_free()
			_emporio_overlay = null
		if is_instance_valid(_runtime_ost):
			_runtime_ost.set_held(is_instance_valid(_jukebox_overlay))
	)
	add_child(_emporio_overlay)
	if is_instance_valid(_runtime_ost):
		_runtime_ost.set_held(true)


## The live Emporio overlay, or null. The acceptance audit reads it the way it reads
## `_jukebox_overlay`.
func emporio_overlay() -> Control:
	return _emporio_overlay


## The Jukebox asked for the shop — a locked track was chosen. Close the Jukebox and open
## the Emporio: the Jukebox itself never opens a screen.
func _on_jukebox_shop_requested(_track_id: String) -> void:
	if _jukebox_overlay != null and is_instance_valid(_jukebox_overlay):
		_jukebox_overlay.queue_free()
		_jukebox_overlay = null
	if _emporio_overlay == null or not is_instance_valid(_emporio_overlay):
		toggle_emporio()


## The stored language, applied at boot: `lang` from the same prefs group the
## settings screen writes, over `Locale`'s own default. Nothing here invents a
## language — `Locale.set_lang` refuses anything but the reference's two tables.
func _apply_stored_language() -> void:
	var prefs: Dictionary = ModesSave.profile(Config.save_store()).get("prefs", {})
	var lang := String(prefs.get("lang", ""))
	if lang != "":
		Locale.set_lang(lang)


## The stored mixer/input prefs, applied at boot the way the reference applies them at
## load (`js/main.js:2276-2278`): `volume` to the audio module's own master gain (the
## bus derivation stays in the module, never a second copy here) and
## `gamepadDeadzone` to the pad reader, clamped inside the reference's band by
## `set_deadzone`. This is the reader the review's F6 named missing.
func _apply_stored_audio_prefs() -> void:
	var prefs: Dictionary = Config.stored_prefs()
	if _audio_port == null:
		_audio_port = AudioPortScript.new()
		_audio_port.name = "UiAudioPort"
		add_child(_audio_port)
	_audio_port.set_master_gain(float(prefs.get("volume", 0.5)))
	# AudioPort builds the buses; apply the independent saved music state after it.
	MusicSettings.apply(prefs)
	InputSource.set_deadzone(float(prefs.get("gamepadDeadzone", 0.15)))


## The live value follows the stored one: the settings screen persists through its own
## `set_volume`/`set_deadzone` door, and the host applies the same value to the audio
## module and the pad reader (review F6).
func _apply_range_side_effects(row_name: String, value: float) -> void:
	if row_name == "VolumeRow" and _audio_port != null:
		_audio_port.set_master_gain(value)
	elif row_name == "DeadzoneRow":
		InputSource.set_deadzone(value)


## The router swapped screens: bind the bridge to what is up now, hand the screen the
## game's own store where it takes one, and ask for a re-measure once the new tree has
## been sorted. `menu_nav.open_screen` is inside `attach()`, so the context and the
## declared-back rule follow the swap in one step.
func _on_screen_changed(_from_id: String, _to_id: String) -> void:
	# A swap is a new surface: the stick starts from the new screen's own offset, never
	# from a fraction accumulated over the screen that just left.
	if _controller_scroll != null:
		_controller_scroll.reset()
	var screen: Node = _router.active_screen()
	if screen == null:
		return
	if screen.has_method("set_store"):
		screen.set_store(Config.save_store())
	# The feedback screen posts through the host's own transport, so a send already in
	# flight is not cut short by this swap. Screens without the door are untouched.
	if screen.has_method("set_async_delivery"):
		screen.call("set_async_delivery", _feedback_delivery)
	_restore_menu_focus = String(screen.call("preferred_focus_id")) if screen.has_method("preferred_focus_id") else ""
	_bridge.attach(screen as Control, _focus, _router)
	# `attach()` rebuilds the bridge's registry from the mounted screen, which drops the
	# host's own Emporio button: put it back so a pad can still open the shop from the
	# menu.
	_ensure_emporio_focus()
	# The result screen's rematch is the host's decision: the screen reports the
	# request and names its label, and the mount owns the mode.
	if screen.has_signal("rematch_requested") and not screen.is_connected("rematch_requested", _on_rematch_requested):
		screen.connect("rematch_requested", _on_rematch_requested)
	_sync_osk()
	if _jukebox_button != null:
		_jukebox_button.visible = (_to_id == "menu")
	if _emporio_button != null:
		_emporio_button.visible = (_to_id == "menu")
	# A freshly mounted screen's containers sort at the end of this frame; the model
	# is re-measured two frames later, not on the rectangles `_ready()` saw.
	_refresh_pending = 2


func _on_music_enabled_changed(_enabled: bool) -> void:
	if _router != null and _router.active_id() == "settings":
		var screen: Node = _router.active_screen()
		if screen != null and screen.has_method("refresh_values"):
			screen.refresh_values()


## A control the bridge activated but did not route: the action belongs to the screen
## that reported it (`ModesScreen.activate()` is the door it documents, and the other
## recreated screens carry the same one). The mount hands it over instead of deciding
## what a mode card or an Atleta command means. `""` is a target the reference leaves
## inert — a dictated rival slot with a single outfit is a card with no command and no
## click handler either — so it is not a gap and is not reported as one.
func _on_action_requested(action: String) -> void:
	# The Emporio launch button is the menu's own control, not a screen's: the bridge
	# reports its action here rather than routing it to a screen.
	if action == "emporio":
		toggle_emporio()
		return
	if action == "":
		return
	var screen: Node = _router.active_screen()
	if screen == null:
		return
	if screen.has_method("activate"):
		screen.call("activate", action)
		return
	print("MENU_NAV no activation door for the action '%s' on '%s'" % [action, _router.active_id()])


## Back the bridge could not resolve: the root, which the reference's own audit says
## leads nowhere (`scripts/gamepad-nav-audit.mjs:67-82`), or a screen that declares no
## return. Reported, never invented — the same rule the ported column states.
func _on_back_requested(_screen_id: String) -> void:
	print("MENU_BACK root: nowhere to go (js/main.js:731 is the defect the model refuses)")


## A range the model stepped in place (`UiFocusBridge.range_changed`): the screen owns
## the write and the persist, so the host hands the value over through the screen's own
## public door — `set_volume`/`set_deadzone` where the screen has them (they persist),
## `set_row_value` otherwise. The id is `<screen>/<RowNode>`, the model's own spelling.
func _on_range_changed(id: String, value: float) -> void:
	var screen: Node = _router.active_screen()
	if screen == null:
		return
	var row_name := id.get_slice("/", 1)
	if row_name == "":
		return
	if row_name == "VolumeRow" and screen.has_method("set_volume"):
		screen.call("set_volume", value)
		_apply_range_side_effects(row_name, value)
		return
	if row_name == "DeadzoneRow" and screen.has_method("set_deadzone"):
		screen.call("set_deadzone", value)
		_apply_range_side_effects(row_name, value)
		return
	if screen.has_method("set_row_value"):
		screen.call("set_row_value", row_name, value)


## The OSK panel follows the input lane's own model: opened/closed/typed state comes
## from `menu_nav.osk` (never from a second copy), and a screen that owns the field's
## write takes the value back (`FeedbackScreen.apply_osk_value`).
func _sync_osk() -> void:
	if _focus == null:
		return
	var osk = _focus.menu.osk
	if _osk_panel != null:
		_osk_panel.refresh()
	if osk == null:
		return
	if osk.is_open():
		_focus.menu.set_osk_targets(_osk_panel.osk_key_targets() if _osk_panel != null else [])
		var screen: Node = _router.active_screen()
		if screen != null and screen.has_method("apply_osk_value"):
			screen.apply_osk_value(String(osk.target_id()), String(osk.value()))
	else:
		_focus.menu.set_osk_targets([])


## The panel's own `done` hand-off (`js/main.js:533-542`): the model closed, the key
## targets go back to the screen's controls, and the field takes the focus back.
func _on_osk_closed(target_id: String) -> void:
	if _focus == null:
		return
	_focus.menu.set_osk_targets([])
	if _osk_panel != null:
		_osk_panel.refresh()
	if target_id != "" and _bridge != null:
		_bridge.set_focus(target_id)


## The result screen's rematch, and the mode flow's continue: the same fixture when
## the run is over, the next one when the session advanced its own bracket or season
## (`Config.pending_mode` still names the run, and the mode session resolves its own
## round). `dry_run` stops before the engine call so an audit can assert the route.
func _on_rematch_requested() -> void:
	rematch_route()


func rematch_route(dry_run := false) -> Dictionary:
	var route := {
		"action": "rematch",
		"mode": Config.pending_mode,
		"scene": "res://game/Match.tscn",
	}
	if not dry_run:
		get_tree().change_scene_to_file(String(route["scene"]))
	return route


## The router UIR-24's capture harness walks. Null in a legacy run.
func ui_router() -> Control:
	return _router


## The right-stick helper this scene drives, so a screen and a test can ask it what it
## is scrolling and what the last frame did. Never null after `_ready()`.
func controller_scroll() -> RefCounted:
	return _controller_scroll


## Built once per UI scene, in both paths. It owns no node and paints nothing on its
## own: `_update_controller_scroll()` names the surface each frame, and the helper
## reads `JOY_AXIS_RIGHT_Y` and writes the container.
func _setup_controller_scroll() -> void:
	if _controller_scroll != null:
		return
	_controller_scroll = ControllerScroll.new()
	# The focused control, when there is one, is what lets a nested panel pick its own
	# scroll container. The helper handles a null answer (no focus, a freed node).
	_controller_scroll.set_focus_source(func() -> Control: return _focus.focus_node() if _focus != null else null)
	# A pad that goes away mid-scroll stops the scroll: the helper must not keep a
	# fraction alive for a seat that no longer exists.
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Losing the window is losing the player's hand: a stick left deflected while the
	# window is in the background must not resume the moment it comes back.
	var tree := get_tree()
	if tree != null and tree.root != null and not tree.root.focus_exited.is_connected(_on_window_focus_lost):
		tree.root.focus_exited.connect(_on_window_focus_lost)
		tree.root.focus_entered.connect(_on_scroll_window_focus_returned)


## One frame of the right stick, over the surface that owns it. The order is the
## reference's own modal rule: the keyboard, then an overlay, then the active screen.
func _update_controller_scroll(delta: float) -> void:
	if _controller_scroll == null:
		return
	if not _scroll_window_active:
		return
	_controller_scroll.set_device(_read_pad_device())
	_controller_scroll.set_surface(_scroll_surface())
	_controller_scroll.update(delta)


## True while an OST overlay (the Jukebox or the Emporio) is up and therefore owns the
## input. The menu's own focus dispatch is skipped so a pad confirm/cancel cannot drive
## the screen behind the modal.
##
## The on-screen keyboard is deliberately NOT in this set: the OSK lane is driven BY the
## menu's own bridge dispatch (`_sync_osk`, `MenuNav.osk`), so suppressing that dispatch
## while the keyboard is up would break code entry. The OSK keeps its existing handling.
func _overlay_owns_input() -> bool:
	if _jukebox_overlay != null and is_instance_valid(_jukebox_overlay) and _jukebox_overlay.is_visible_in_tree():
		return true
	if _emporio_overlay != null and is_instance_valid(_emporio_overlay) and _emporio_overlay.is_visible_in_tree():
		return true
	return false


## The UI that owns the stick this frame, or null when there is none (the ported
## column, which builds no scroll container, and the gameplay frame). A hidden
## overlay is not a surface: `is_visible_in_tree()` is the test, so the screen under a
## modal is inert without a second flag.
func _scroll_surface() -> Control:
	if not _playable:
		return null
	if _osk_panel != null and is_instance_valid(_osk_panel) and _osk_panel.is_visible_in_tree():
		return _osk_panel
	if _jukebox_overlay != null and is_instance_valid(_jukebox_overlay) and _jukebox_overlay.is_visible_in_tree():
		return _jukebox_overlay
	if _emporio_overlay != null and is_instance_valid(_emporio_overlay) and _emporio_overlay.is_visible_in_tree():
		return _emporio_overlay
	if _router != null:
		return _router.active_screen() as Control
	return null


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and _controller_scroll != null:
		# Suspend, not reset: a pad that comes back with the stick still held must wait
		# for neutral before it scrolls again.
		_controller_scroll.suspend()


func _on_window_focus_lost() -> void:
	_scroll_window_active = false
	if _controller_scroll != null:
		# Suspend, not reset: dropping the fraction alone would let the very next frame
		# read the still-deflected stick and carry on scrolling.
		_controller_scroll.suspend()


func _on_scroll_window_focus_returned() -> void:
	_scroll_window_active = true


func _register(id: String, node: Control, action: String, locked := false) -> void:
	_focus.add(id, node, action, {"locked": locked})


# ---------------------------------------------------------------------------
# Widgets
# ---------------------------------------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _choice_button(text: String, group: ButtonGroup, selected: bool, locked := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = selected
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = locked
	b.add_theme_font_size_override("font_size", 16)
	b.custom_minimum_size = Vector2(430.0, 28.0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## An arena button's label: the frozen arena's own id, in caps. The reference's
## display names are not distinct at their first word, and a truncated name is worse
## than the id; the name key, the description and the two frozen numbers ride in the
## tooltip and the info line.
func _arena_label(arena: Dictionary) -> String:
	return String(arena["id"]).to_upper()


func _apply_selection_state() -> void:
	for i in _tier_buttons.size():
		_tier_buttons[i].button_pressed = i == Config.tier_index and not _tier_buttons[i].disabled
	for i in _athlete_buttons.size():
		var full_index := Gate.index_in(Frozen.athletes(), Config.selectable_athletes()[i])
		_athlete_buttons[i].button_pressed = full_index == Config.athlete_index
	# A world arena being selected clears the frozen row's pressed state: the
	# frozen indices are still what they were, but the arena the match would start
	# on is the world one.
	var world_active := Config.is_world_selected()
	for i in _arena_buttons.size():
		var full_index := Gate.index_in(Frozen.arenas(), Config.selectable_arenas()[i])
		_arena_buttons[i].button_pressed = full_index == Config.arena_index and not world_active
	# The world row marks its own selection: `Button` without toggle mode has no
	# pressed state, so the active id carries the accent colour instead.
	var world_list: Array = Config.selectable_world_arenas()
	for i in _world_arena_buttons.size():
		if i >= world_list.size():
			break
		var id := String((world_list[i] as Dictionary).get("id", ""))
		if world_active and Config.arena_id() == id:
			_world_arena_buttons[i].add_theme_color_override("font_color", Color(0.0, 0.898, 1.0))
		else:
			_world_arena_buttons[i].remove_theme_color_override("font_color")
	# The special strip marks its own selection the same way (amber is the roster
	# UI colour the overlay carries for `fornaio`).
	var special_list: Array = Config.selectable_special_athletes()
	for i in _special_athlete_buttons.size():
		if i >= special_list.size():
			break
		var special_id := String((special_list[i] as Dictionary).get("id", ""))
		if Config.is_special_selected() and Config.athlete_id() == special_id:
			_special_athlete_buttons[i].add_theme_color_override("font_color", Color("d98e2b"))
		else:
			_special_athlete_buttons[i].remove_theme_color_override("font_color")
	_refresh_outfit_button()


func _refresh_outfit_button() -> void:
	if _outfit_button == null:
		return
	var key := Config.outfit_name_key()
	var name := Locale.t(key) if Locale.is_resolvable(key) else String(Config.outfit_id())
	_outfit_button.text = "COMPLETO: %s  (%d/%d)  »" % [
		name, Config.outfit_index + 1, Config.outfit_ids().size()]


func _refresh_info() -> void:
	var arena := Config.arena()
	var name_key := "arena_%s_name" % String(arena["id"])
	var shown_name := Locale.t(name_key) if Locale.is_resolvable(name_key) else String(arena["name"])
	_info.text = "Arena: %s (%s) · wallBounce %.2f · grip %.2f · %s" % [
		shown_name,
		String(arena["id"]),
		float(arena["wallBounce"]),
		float(arena["floorGrip"]),
		String(arena["desc"]),
	]
	_seed_label.text = "Seed %d (fissa; due partite con la stessa seed danno gli stessi punti). Q per uscire." % Config.seed_value


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func _on_tier(index: int) -> void:
	Config.tier_index = index
	_refresh_info()


func _on_athlete(full_index: int) -> void:
	if full_index < 0:
		return
	# A frozen pick takes the selection back from the special seat (the two are
	# mutually exclusive, exactly like the frozen and world arena seats).
	Config.clear_special_athlete()
	Config.athlete_index = full_index
	Config.outfit_index = 0
	_apply_selection_state()
	_refresh_info()
	_refresh_outfit_button()


## A special athlete's own handler. A special has no frozen roster index, so the
## selection goes through `Config.set_special_athlete_id` — the seat is the id
## itself. A refusal means this build does not offer the set (a demo builds no
## strip at all), so it is reported rather than swallowed.
func _on_special_athlete(athlete_id: String) -> void:
	if not Config.set_special_athlete_id(athlete_id):
		push_error("main_menu: this build does not offer the special athlete '%s'" % athlete_id)
		return
	Config.outfit_index = 0
	_apply_selection_state()
	_refresh_info()
	_refresh_outfit_button()


func _on_arena(full_index: int) -> void:
	if full_index < 0:
		return
	Config.arena_index = full_index
	# The two seats are mutually exclusive: choosing a frozen arena clears the
	# world one (`Config.arena_id()` reads the frozen index again) and the world
	# row's own marking is refreshed below.
	Config.world_arena_id = ""
	_apply_selection_state()
	_refresh_info()


## A world arena's own handler. The frozen row routes through `_on_arena(index)`;
## a world arena has no frozen index, so the selection goes through
## `Config.set_arena_id` — the seat is the id itself. A refusal here means the
## build does not offer the set (a demo builds no world row at all), so it is
## reported rather than swallowed.
func _on_world_arena(arena_id: String) -> void:
	if not Config.set_arena_id(arena_id):
		push_error("main_menu: this build does not offer the world arena '%s'" % arena_id)
		return
	_apply_selection_state()
	_refresh_info()


func _on_outfit() -> void:
	Config.cycle_outfit(1)
	_refresh_outfit_button()
	# The menu's choice is what the MATCH scene will spawn; if a match is already
	# up, the live rig is recoloured in place (`AthleteSpawn.set_outfit`).
	var match_node := get_tree().get_first_node_in_group("padel_match")
	if match_node != null and match_node.has_method("apply_outfit"):
		match_node.apply_outfit(Config.outfit_index)


func start_match() -> void:
	Config.pending_mode = "quick"
	get_tree().change_scene_to_file("res://game/Match.tscn")


func _open_mode(mode_id: String) -> void:
	Config.pending_mode = mode_id
	get_tree().change_scene_to_file("res://game/ModeScreen.tscn")


func _quit() -> void:
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# Navigation: the verified model, not a private copy
# ---------------------------------------------------------------------------

func _pad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


## The pad this screen's model reads (`selectPrimaryGamepad`, `js/main.js:265-272`,
## through the same rule the match's seats use): the pad somebody touches takes over,
## the current one is kept while nobody does, and a fresh list falls back to its first
## entry. NOT blindly the first entry of the host's list, which on a two-pad host is
## not necessarily the one in the player's hands. `NO_DEVICE` stays `NO_DEVICE`: the
## model reads every axis and button as neutral then.
func _read_pad_device() -> int:
	_pad_device = InputSource.select_device(_pad_device)
	return _pad_device


## Keys the model owns are consumed before the GUI sees them, so Godot's built-in
## `ui_*` focus navigation cannot move the same focus a second time. The playable path
## dispatches through UIR-05's bridge instead of the model directly: the verdict there
## becomes a `ScreenRouter.go_to`, an OSK open/close against the same model, or one of
## the bridge's report signals.
func _input(event: InputEvent) -> void:
	if _capture or _focus == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		toggle_jukebox()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and _emporio_shortcut_available():
		toggle_emporio()
		get_viewport().set_input_as_handled()
		return
	# An overlay owns the input while it is up. Without this guard the menu behind a
	# Jukebox/Emporio overlay would still receive pad navigation and confirm through
	# the focus bridge — the overlay would look modal and behave transparently. The
	# event is left unhandled so the GUI delivers `ui_accept` to the overlay's own
	# focused control.
	if _overlay_owns_input():
		return
	if _runtime_ost != null and _runtime_ost.handle_skip(event):
		get_viewport().set_input_as_handled()
		return
	if _playable:
		if event is InputEventKey:
			if _bridge.dispatch(event):
				get_viewport().set_input_as_handled()
				var result: Dictionary = _bridge.last_result()
				if bool(result.get("moved", false)):
					_apply_focus()
				_apply_navigation_scroll(float(result.get("scrolled", 0.0)))
				if String(result.get("kind", "")) != "":
					_sync_osk()
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			# The event can precede `Input`'s per-device state by a rendered frame on
			# macOS. Feed it into the SAME poll model immediately; the later poll then
			# sees the held state and its edge/repeat bookkeeping prevents a second move.
			var pad_device := (event as InputEventJoypadButton).device if event is InputEventJoypadButton else (event as InputEventJoypadMotion).device
			_pad_device = pad_device
			var result: Dictionary = _focus.handle_pad_event(event, _pad_device)
			if bool(result.get("focus_moved", false)):
				_apply_focus()
			if String(result.get("kind", "")) != "" and _bridge != null:
				_bridge.act(result)
				# Only a confirm/back can change the OSK context. Re-applying its empty
				# target list after a direction clears the navigation model and puts focus
				# back on the first control, so a card can never stay selected.
				_sync_osk()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var result: Dictionary = _focus.handle_key(event as InputEventKey)
		if bool(result.get("handled", false)):
			get_viewport().set_input_as_handled()
			_dispatch(result)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# The pad is polled once per frame (the reference polls in its render loop,
		# `js/main.js:1001-1004`); the events themselves are swallowed so `ui_accept`
		# cannot press the focused button a second time.
		get_viewport().set_input_as_handled()


func _emporio_shortcut_available() -> bool:
	if not _playable or _router == null or _router.active_id() != "menu" or _overlay_owns_input():
		return false
	if _osk_panel != null and _osk_panel.is_visible_in_tree():
		return false
	var owner := get_viewport().gui_get_focus_owner()
	return not (owner is LineEdit or owner is TextEdit)


func _process(delta: float) -> void:
	if _runtime_ost != null:
		_runtime_ost.set_screen(_router.active_id() if _playable and _router != null else "menu")
		_runtime_ost.set_held(is_instance_valid(_jukebox_overlay) or is_instance_valid(_emporio_overlay))
	if _capture or _focus == null:
		return
	if _playable:
		_playable_process(delta)
		return
	# The layout settles one frame after the tree is built (and changes again on a
	# window resize): re-measure the model's rectangles when it does, so navigation
	# reasons about where the rows actually are rather than where `_ready()` found
	# them — all of them at the origin.
	if _column != null and _column.size != _layout_seen:
		_layout_seen = _column.size
		_focus.refresh()
		_apply_focus()
	var connected := _pad_connected()
	if connected != _pad_seen:
		_pad_seen = connected
		_focus.pad_connected(connected)
	# The right stick is applied BEFORE the "nobody is connected" return, and it is the
	# helper — not this branch — that reads the seat: a disconnected pad and a null
	# surface both leave it inert, so the early return below is about the FOCUS poll,
	# not about scrolling.
	_update_controller_scroll(delta)
	if not connected:
		return
	var result: Dictionary = _focus.poll_pad(_read_pad_device())
	_apply_navigation_scroll(float(result.get("direction_scrolled", 0.0)) * delta * 60.0)
	if String(result.get("dir", "")) != "" and bool(result.get("focus_moved", false)):
		_apply_focus()
	if String(result.get("kind", "")) != "":
		_dispatch(result)


## The playable path's frame: the same polling contract as the ported column, over
## whichever screen the router has up. A swap asks for a re-measure (containers sort
## at the end of the frame that built them), a confirm or a back the poll resolved is
## applied through the bridge, and the presentation is refreshed when the model moved.
func _playable_process(delta: float) -> void:
	# A screen that rebuilt its own view (the athlete picker, the wardrobe) freed the
	# controls the bridge registered; re-read them before anything paints, so the frame
	# never touches a freed node. The new tree sorts at the end of this frame, so the
	# rectangles are re-measured two frames later, like a screen swap.
	if _bridge != null and _bridge.refresh_if_rebuilt():
		_refresh_pending = 2
	if _refresh_pending > 0:
		_refresh_pending -= 1
		if _refresh_pending == 0:
			_focus.refresh()
			if _restore_menu_focus != "":
				_bridge.set_focus(_restore_menu_focus)
				_restore_menu_focus = ""
			_apply_focus()
	var connected := _pad_connected()
	if connected != _pad_seen:
		_pad_seen = connected
		_focus.pad_connected(connected)
	# Same order as the ported column: the scroll is applied whatever the focus poll
	# decides, and the helper itself is what refuses a disconnected seat or a surface
	# that is not up.
	_update_controller_scroll(delta)
	# An OST overlay owns confirm/cancel while it is up. `poll_pad` reads the HELD pad
	# state every frame (not just pushed events), so without this stop a real gamepad
	# held down would keep activating the screen behind the shop. The scroll above still
	# runs, and the GUI still delivers accept to the overlay's own focused control.
	if _overlay_owns_input():
		return
	if not connected:
		return
	var result: Dictionary = _focus.poll_pad(_read_pad_device())
	_apply_navigation_scroll(float(result.get("direction_scrolled", 0.0)) * delta * 60.0)
	if bool(result.get("focus_moved", false)):
		_apply_focus()
	if String(result.get("kind", "")) != "":
		if _bridge != null:
			_bridge.act(result)
		_sync_osk()


## What the model decided. `activate` runs the target's action; `none` on the root
## is the reference's own rule — back from the root leads nowhere
## (`scripts/gamepad-nav-audit.mjs:67-82`) — so this screen does not invent a
## destination for it.
func _dispatch(result: Dictionary) -> void:
	var kind := String(result.get("kind", ""))
	match kind:
		"activate":
			_run_action(String(result.get("action", "")))
		"back":
			_run_action(String(result.get("action", "")))
		"none":
			if bool(result.get("root", false)):
				print("MENU_BACK root: nowhere to go (js/main.js:731 is the defect the model refuses)")
		"osk_open", "osk_close", "overlay":
			# This screen has no text field and no overlay: the model's other
			# outcomes are unreachable from here, and saying so is cheaper than a
			# dead branch that pretends otherwise.
			print("MENU_NAV unreachable outcome from the menu: %s" % kind)
	if bool(result.get("focus_moved", false)) or kind == "":
		_apply_focus()


func _run_action(action: String) -> void:
	if action == "":
		return
	if action == "play":
		start_match()
	elif action == "quit":
		_quit()
	elif action == "outfit":
		_on_outfit()
	elif action.begins_with("tier:"):
		_on_tier(int(action.substr(5)))
	elif action.begins_with("athlete:"):
		_on_athlete(int(action.substr(8)))
	elif action.begins_with("arena:"):
		var arena_id := action.substr(6)
		if Arena.is_world(arena_id):
			_on_world_arena(arena_id)
		else:
			_on_arena(_full_arena_index(arena_id))
	elif action.begins_with("mode:"):
		_open_mode(action.substr(5))


func _full_arena_index(arena_id: String) -> int:
	for i in Frozen.arenas().size():
		if String((Frozen.arenas()[i] as Dictionary)["id"]) == arena_id:
			return i
	return -1


func _apply_navigation_scroll(amount: float) -> void:
	if _controller_scroll == null or not _scroll_window_active or is_zero_approx(amount):
		return
	_controller_scroll.set_surface(_scroll_surface())
	_controller_scroll.scroll_by(amount)
	_focus.refresh_geometry()


func _apply_focus() -> void:
	_focus.apply_focus()


## The focus model itself, so a screen and a test can ask it what it registered and
## what it can reach. Never null after `_ready()`.
func focus_model() -> MenuFocus:
	return _focus


# ---------------------------------------------------------------------------
# Capture (the screenshot path `run.sh` uses)
# ---------------------------------------------------------------------------

func _run_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# The model needs the final rectangles, and the capture has to show the same
	# focus the model holds. In the playable path the model is the bridge's, over
	# whichever screen the router mounted.
	if _focus != null:
		_refresh_pending = 0
		_focus.refresh()
		_focus.apply_focus()
		_sync_osk()
	await RenderingServer.frame_post_draw
	var dir := "res://game/out"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var tex := get_viewport().get_texture()
	if tex == null:
		push_error("menu capture: viewport texture null")
		get_tree().quit(3)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_error("menu capture: viewport image null")
		get_tree().quit(4)
		return
	if _playable:
		print("UI_PROTOTYPE_ON_SCREEN %s" % JSON.stringify({
			"screen": String(_router.active_id()) if _router != null else "",
			"router": "menu",
			"playable": true,
		}))
	elif _focus != null:
		print("MENU_ON_SCREEN %s" % JSON.stringify(screen_report()))
	var err := img.save_png("%s/%s.png" % [dir, _out_name])
	print("CAPTURE_SAVE err=%d path=%s/%s.png size=%dx%d" % [err, dir, _out_name, img.get_width(), img.get_height()])
	get_tree().quit(0 if err == OK else 5)


## What this screen actually shows, as data — the demo-vs-full comparison is made
## on this line plus the pixels, never on a claim about the pixels.
func screen_report() -> Dictionary:
	var athlete_labels: Array = []
	for b in _athlete_buttons:
		athlete_labels.append(b.text.split(" ")[0])
	var arena_labels: Array = []
	for b in _arena_buttons:
		arena_labels.append(b.text)
	var enabled_tiers: Array = []
	for i in _tier_buttons.size():
		if not _tier_buttons[i].disabled:
			enabled_tiers.append(i)
	var mode_labels: Array = []
	for b in _mode_buttons:
		mode_labels.append({"text": b.text, "disabled": b.disabled})
	return {
		"build": Gate.label(),
		"athletes": athlete_labels,
		"arenas": arena_labels,
		"tiers_shown": _tier_buttons.size(),
		"tiers_enabled": enabled_tiers,
		"modes": mode_labels,
		"outfit": _outfit_button.text if _outfit_button != null else "",
		"focus": _focus.focus_id() if _focus != null else "",
		"focusable": _focus.focusable_ids() if _focus != null else [],
	}
