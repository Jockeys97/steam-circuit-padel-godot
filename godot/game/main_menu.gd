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
const ModesSave := preload("res://src/modes/modes_save.gd")
const InputSource := preload("res://game/input_map.gd")
## The verified audio module, for the one job the host has in it: applying the stored
## master volume at boot (`js/main.js:2278`). The bus derivation stays in the module.
const AudioPortScript := preload("res://src/audio/audio_port.gd")

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
var _mode_buttons: Array[Button] = []
var _info: Label
var _seed_label: Label
var _outfit_button: Button
var _play: Button
var _focus: MenuFocus
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
## UIR-05's bridge over the same `_focus` model the ported column uses: the screens
## declare their controls, the model decides, and the bridge turns a verdict into a
## `ScreenRouter.go_to` or one of its two signals.
var _bridge: RefCounted = null
## There is no on-screen keyboard in this mount any more (user decision, 2026-09-17:
## it came up over the main menu, where the reference has no text field at all). The
## lane's OSK model is untouched (`src/input/osk.gd`, bound into `menu_nav`) and the
## panel's own contract is still asserted by `tests/ui/osk_touch_audit.gd`, which
## mounts it on its own; what is gone is the mount of `OskPanel.tscn` here and the
## branch that fed it the focus. `_sync_osk()` is what remains: it closes the model
## the moment the lane opens it and finishes the confirm the lane meant to allow.
## The audio module instance the host applies the stored master volume through. Built
## once, lazily, by `_apply_stored_audio_prefs()`.
var _audio_port: Node = null
## Frames to wait before re-measuring the model after a screen swap: a container
## sorts at the end of the frame that mounted it, so the first rectangles are wrong
## by construction.
var _refresh_pending := 0
var _out_name := "menu"
var _pad_seen := false
## The column the focus model measures, and the laid-out size it was last refreshed
## at. A container sorts at the end of the frame that built it, so the rectangles
## `_ready()` refreshes with are the pre-layout ones.
var _column: Control
var _layout_seen := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	bg.color = Color(0.043, 0.063, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
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
	_bridge = (load("res://src/ui/focus/UiFocusBridge.gd") as GDScript).new()
	_bridge.range_changed.connect(_on_range_changed)
	_router.screen_changed.connect(_on_screen_changed)
	# NO keyboard is mounted over the router (user decision, 2026-09-17). UIR-26's
	# recipe — `OskPanel.tscn` instantiated here, bound to `_focus.menu.osk`, its
	# `closed` signal wired to the field hand-off — used to stand on this line. It
	# is where the panel the player saw over the MENU came from; `_sync_osk()` below
	# names why the lane opened it there and what replaces the hand-off.
	# One locale drives the menu and the match HUD (UIR-22): the player's stored
	# choice is applied once, here, and nothing below switches language behind it.
	_apply_stored_language()
	# The stored mixer/input prefs go on at the same moment (`js/main.js:2276-2278`),
	# so a value the settings screen wrote is already in force before any screen reads
	# it — including the language above, which the reference applies in the same block.
	_apply_stored_audio_prefs()
	# A finished match left its payload behind; everything else starts at the menu.
	if Config.pending_result.is_empty():
		if not _router.go_to("menu"):
			push_error("main_menu: the router refused to mount the menu screen")
	else:
		var payload := Config.take_pending_result()
		if not _router.go_to("result", payload):
			push_error("main_menu: the router refused to mount the result screen")
	_on_screen_changed("", String(_router.active_id()))
	_refresh_pending = 2


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
	var screen: Node = _router.active_screen()
	if screen == null:
		return
	if screen.has_method("set_store"):
		screen.set_store(Config.save_store())
	_bridge.attach(screen as Control, _focus, _router)
	# The result screen's rematch is the host's decision: the screen reports the
	# request and names its label, and the mount owns the mode.
	if screen.has_signal("rematch_requested") and not screen.is_connected("rematch_requested", _on_rematch_requested):
		screen.connect("rematch_requested", _on_rematch_requested)
	_sync_osk()
	# A freshly mounted screen's containers sort at the end of this frame; the model
	# is re-measured two frames later, not on the rectangles `_ready()` saw.
	_refresh_pending = 2


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


## WHY THE KEYBOARD CAME UP OVER THE MENU, and what finishes that confirm now.
##
## The lane opens its model on any confirm whose target passes
## `FocusNav.is_text_field` (`src/input/menu_nav.gd:223`) — and every target passes
## it. `src/input/focus_nav.gd:251-258` accepts a target whose `input_type` key is
## absent, because the accepted set contains the empty string (`js/main.js:545-549`:
## "an `<input>` with no type is a text input"). That rule is about a DOM `<input>`
## element; a ported target dictionary is not one, and `game/menu_focus.gd::_target()`
## (:93-105) never emits `input_type` — no screen registers it either — so the menu's
## buttons were read as text fields too. Confirming an ordinary row with a pad
## therefore opened the OSK instead of running the row: that is the panel that came
## up over the menu, and the reason it is gone from this mount rather than restyled.
##
## Nothing here renders a keyboard, so the mount closes the model at once and
## finishes the confirm the way the lane would have with a correct `is_text_field`:
## the screen's own targets come back first (so the player can navigate away), the
## field takes the focus, and the target's action is replayed through the bridge — a
## row routes exactly like a plain confirm, while a genuine text field
## (`FeedbackScreen` registers the one action `text-field`, `:1053`) has no route to
## take and simply keeps the focus. The typed-value hand-off
## (`FeedbackScreen.apply_osk_value`) goes with the keyboard: a model that opens with
## an empty value must never be written back onto the field.
func _sync_osk() -> void:
	if _focus == null:
		return
	var osk = _focus.menu.osk
	if osk == null or not osk.is_open():
		return
	var target_id := String(osk.target_id())
	osk.close()
	_focus.menu.set_osk_targets([])
	if target_id == "":
		return
	_bridge.set_focus(target_id)
	_bridge.act({
		"kind": "activate",
		"target": target_id,
		"action": _focus.action_of(target_id),
	})


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
	for i in _arena_buttons.size():
		var full_index := Gate.index_in(Frozen.arenas(), Config.selectable_arenas()[i])
		_arena_buttons[i].button_pressed = full_index == Config.arena_index
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
	Config.athlete_index = full_index
	Config.outfit_index = 0
	_refresh_info()
	_refresh_outfit_button()


func _on_arena(full_index: int) -> void:
	if full_index < 0:
		return
	Config.arena_index = full_index
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


## Keys the model owns are consumed before the GUI sees them, so Godot's built-in
## `ui_*` focus navigation cannot move the same focus a second time. The playable path
## dispatches through UIR-05's bridge instead of the model directly: the verdict there
## becomes a `ScreenRouter.go_to`, an OSK open/close against the same model, or one of
## the bridge's report signals.
func _input(event: InputEvent) -> void:
	if _capture or _focus == null:
		return
	if _playable:
		if event is InputEventKey:
			if _bridge.dispatch(event):
				get_viewport().set_input_as_handled()
				_sync_osk()
		elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
			# Confirm/cancel are the bridge's; every other pad event is swallowed
			# anyway, because the model is polled once per frame below (the
			# reference polls its gamepad in the render loop, `js/main.js:1001-1004`)
			# and a second, built-in navigation on the same stick would move the
			# focus the model does not know about.
			if _bridge.dispatch(event):
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


func _process(_delta: float) -> void:
	if _capture or _focus == null:
		return
	if _playable:
		_playable_process()
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
	if not connected:
		return
	var result: Dictionary = _focus.poll_pad()
	if String(result.get("dir", "")) != "" and bool(result.get("focus_moved", false)):
		_apply_focus()
	if String(result.get("kind", "")) != "":
		_dispatch(result)


## The playable path's frame: the same polling contract as the ported column, over
## whichever screen the router has up. A swap asks for a re-measure (containers sort
## at the end of the frame that built them), a confirm or a back the poll resolved is
## applied through the bridge, and the presentation is refreshed when the model moved.
func _playable_process() -> void:
	if _refresh_pending > 0:
		_refresh_pending -= 1
		if _refresh_pending == 0:
			_focus.refresh()
			_apply_focus()
	var connected := _pad_connected()
	if connected != _pad_seen:
		_pad_seen = connected
		_focus.pad_connected(connected)
	if not connected:
		return
	var result: Dictionary = _focus.poll_pad()
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
		_on_arena(_full_arena_index(action.substr(6)))
	elif action.begins_with("mode:"):
		_open_mode(action.substr(5))


func _full_arena_index(arena_id: String) -> int:
	for i in Frozen.arenas().size():
		if String((Frozen.arenas()[i] as Dictionary)["id"]) == arena_id:
			return i
	return -1


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
