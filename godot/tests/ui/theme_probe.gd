## theme_probe.gd — UIR-02's gate for `res://src/ui/theme/padel_theme.tres`.
##
##   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
##   "$GODOT" --headless --path godot/ --script res://tests/ui/theme_probe.gd ; echo "exit=$?"
##
## What it proves, in order:
##   1. the theme loads; every documented type variation exists with its documented base type;
##   2. every variation carries the font size, colour and stylebox the token map promises, and every
##      palette entry equals the reference's own value (the tables below are the map from
##      `godot/src/ui/theme/README.md`, transcribed once so the README can be checked against the file);
##   3. one instance of every variation lays out inside a real frame at 1280x720, 1152x648, 1920x1080
##      and 1024x600 without overflowing its container;
##   4. the reference's own foreground/background pairs keep their contrast ratios.
##
## Contract copied from `godot/tests/smoke_test.gd:7-14`: one `ok <name>` line per check, a single
## `PASS n/n` (or `FAIL n/n`) line, exit 0 on pass and 1 on fail. Informational lines start with `#`.
##
## Owner: UIR-02. `theme_probe.tscn` mounts the same grid for a human; it carries no script, so this
## headless run is the acceptance path.
extends SceneTree

const THEME_PATH := "res://src/ui/theme/padel_theme.tres"

## Reference values, transcribed from `styles.css:1-13` (root tokens) and the measured semantic
## colours (UIR-06). `Palette` colours are compared against these.
var PALETTE := {
	"ink": Color("f6f7fb"),
	"muted": Color(1, 1, 1, 0.48),
	"panel": Color("111540"),
	"line": Color(1, 1, 1, 0.12),
	"cyan": Color("00e5ff"),
	"gold": Color("ffcc00"),
	"coral": Color("ff4b6e"),
	"green": Color("1aff8a"),
	"bg": Color("07072a"),
	"shadow": Color(0, 0, 0, 0.45),
	"surface_0": Color("061426"),
	"surface_1": Color("091d39"),
	"surface_2": Color("0b2444"),
	"surface_3": Color("0b3152"),
	"surface_4": Color("10365f"),
	"surface_5": Color("173b61"),
	"text_soft": Color("bdeeff"),
	"text_soft_2": Color("9ef8ff"),
	"text_soft_3": Color("7ef3ff"),
	"state_yellow": Color("fff36a"),
	"state_yellow_soft": Color("ffd98a"),
	"rival_soft": Color("ffc09a"),
	"rival": Color("ff9a5c"),
	"success": Color("b9ffe0"),
	"success_cyan": Color("8fffd0"),
	"combo_1": Color("7ef3ff"),
	"combo_2": Color("8fffd0"),
	"combo_3": Color("ffe066"),
	"combo_4": Color("ff9a5c"),
	"combo_default": Color("ff6d70"),
	"tab_border": Color("28567d"),
	"tab_text_idle": Color("809bb6"),
	"secondary_button": Color("1c6eb0"),
	"button_gradient_start": Color("00d4f0"),
	"segmented_gradient_start": Color("22d5ee"),
	"hud_panel_bg": Color(6 / 255.0, 24 / 255.0, 46 / 255.0, 0.82),
	"hud_panel_border": Color("1c507e"),
	"hud_label": Color("dcefff"),
	"hint_bg": Color(9 / 255.0, 29 / 255.0, 57 / 255.0, 0.7),
	"tag_idle": Color(1, 1, 1, 0.35),
	"fixture": Color(1, 1, 1, 0.42),
	"ghost_text": Color(1, 1, 1, 0.65),
	"tab_text_hover": Color("cfe9f7"),
	"hud_button_hover": Color("1a4a79"),
	"hud_button_active_text": Color("04203a"),
	"card_hover_border": Color(0, 229 / 255.0, 1, 0.35),
	# Added 2026-09-17 by the integration wave when UIR-07 needed the menu chrome the theme
	# did not yet carry; each transcribed from the reference line cited in the theme README §3.
	"nav_bg": Color(5 / 255.0, 5 / 255.0, 22 / 255.0, 0.97),
	"caption_shadow": Color(7 / 255.0, 21 / 255.0, 43 / 255.0, 1),
	"poster_fade": Color(3 / 255.0, 7 / 255.0, 25 / 255.0, 0.82),
	# Added 2026-09-17 by the pre-gate wave: the combo glow `js/ui.js:1315` writes at
	# combo >= 4 — `rgba(255,106,92,0.8)` — was computed by the view-model and painted
	# nowhere until then. README §3.
	"combo_glow": Color(1, 106 / 255.0, 92 / 255.0, 0.8),
	# Added 2026-09-17 (wave 3) from UIR-13's recorded seam: the 15 palette rows the
	# help/history/challenges/profile screens read but the theme did not carry, each
	# transcribed from the reference line cited in the theme README §3, plus the two
	# UIR-11 stat-strip inks (`styles.css:3026`/`:3030`) added with the strip itself.
	"win_green": Color("3fd36f"),
	"win_ink": Color("04210f"),
	"loss_red": Color("ff5d7a"),
	"loss_ink": Color("21040a"),
	"trophy_yellow": Color("ffd23a"),
	"stat_muted": Color("6f91ad"),
	"item_ink": Color("e6f8ff"),
	"help_muted": Color("8aa5bc"),
	"kbd_border": Color("29c9dc"),
	"white": Color(1, 1, 1),
	"challenge_cyan": Color("78c8ff"),
	"challenge_row_fill": Color(8 / 255.0, 16 / 255.0, 44 / 255.0, 0.5),
	"challenge_done_border": Color(1, 210 / 255.0, 120 / 255.0, 0.4),
	"challenge_done_fill": Color(60 / 255.0, 42 / 255.0, 8 / 255.0, 0.28),
	"summary_fill": Color(8 / 255.0, 22 / 255.0, 48 / 255.0, 0.6),
	"stat_bar": Color("7ee0ff"),
	"stat_bar_rival": Color("ffb08c"),
}

## variation -> [base type, font_size (0 = not asserted), font_color ("" = not asserted), stylebox name ("" = none)]
var VARIATIONS := {
	"ScreenTitle": [&"Label", 38, "ink", ""],
	"ScreenSubtitle": [&"Label", 16, "muted", ""],
	"HeroTitle": [&"Label", 64, "ink", ""],
	"CardTitle": [&"Label", 18, "ink", ""],
	"CardTitleActive": [&"Label", 18, "cyan", ""],
	"CardBody": [&"Label", 13, "muted", ""],
	"LabelSmall": [&"Label", 11, "text_soft", ""],
	"Badge": [&"Label", 11, "ink", "normal"],
	"Tag": [&"Label", 11, "tag_idle", ""],
	"TagReady": [&"Label", 11, "green", ""],
	"HudLabel": [&"Label", 9, "hud_label", ""],
	"HudTitle": [&"Label", 24, "cyan", ""],
	"Mono": [&"Label", 14, "text_soft", ""],
	"ButtonPrimary": [&"Button", 16, "black", "normal"],
	"ButtonSecondary": [&"Button", 14, "white", "normal"],
	"ButtonGhost": [&"Button", 14, "ghost_text", "normal"],
	"SegmentedInactive": [&"Button", 11, "tab_text_idle", "normal"],
	"SegmentedActive": [&"Button", 11, "surface_0", "normal"],
	"HudButton": [&"Button", 19, "state_yellow", "normal"],
	"HudButtonActive": [&"Button", 19, "hud_button_active_text", "normal"],
	"PanelDark": [&"Panel", 0, "", "panel"],
	"PanelCardHover": [&"Panel", 0, "", "panel"],
	"PanelCardSelected": [&"Panel", 0, "", "panel"],
	"HudPanel": [&"Panel", 0, "", "panel"],
	"HudPauseCard": [&"Panel", 0, "", "panel"],
	"SegmentedContainer": [&"Panel", 0, "", "panel"],
	# Added 2026-09-17 by the pre-gate wave (`Hud`'s flashing tactic chip and the
	# `.game-timer__ball`; README §4). The flash's `#071d34` is asserted in
	# `check_colors_are_reference_values` — it is a one-line rule colour, not a token.
	"SegmentedFlash": [&"Button", 11, "", "normal"],
	"TimerBall": [&"Panel", 0, "", "panel"],
}

## The four sizes the ticket names, in order.
var SIZES := [Vector2(1280, 720), Vector2(1152, 648), Vector2(1920, 1080), Vector2(1024, 600)]

var _theme: Theme
var _host: Control
var _cells: Array[Control] = []
var _checks := 0
var _failures := 0
var _size_index := 0
var _frames := 0


func _initialize() -> void:
	print("# theme_probe · Godot %s" % Engine.get_version_info().get("string", "?"))
	_theme = load(THEME_PATH)
	check_true(_theme != null, "theme loads from %s" % THEME_PATH)
	if _theme == null:
		_finish()
		return

	check_eq(_theme.default_font_size, 16, "default font size is the measured 16 px root")
	check_true(_theme.default_font != null, "default font is assigned")

	for key in PALETTE:
		var want: Color = PALETTE[key]
		check_true(_theme.has_color(key, "Palette"), "palette carries %s" % key)
		if _theme.has_color(key, "Palette"):
			var got: Color = _theme.get_color(key, "Palette")
			check_true(got.is_equal_approx(want),
				"palette %s = %s (reference %s)" % [key, got.to_html(true), want.to_html(true)])

	for name in VARIATIONS:
		var spec: Array = VARIATIONS[name]
		var base: StringName = spec[0]
		check_true(_theme.is_type_variation(name, base), "%s is a %s variation" % [name, base])
		if int(spec[1]) > 0:
			check_eq(_theme.get_font_size("font_size", name), spec[1],
				"%s font size is %d" % [name, spec[1]])
		if String(spec[2]) != "":
			var want_color: Color = _color_for(String(spec[2]))
			check_true(_theme.has_color("font_color", name), "%s assigns font_color" % name)
			if _theme.has_color("font_color", name):
				var got_color: Color = _theme.get_color("font_color", name)
				check_true(got_color.is_equal_approx(want_color),
					"%s font_color = %s" % [name, got_color.to_html(true)])
		if String(spec[3]) != "":
			check_true(_theme.has_stylebox(String(spec[3]), name),
				"%s carries stylebox '%s'" % [name, spec[3]])
		if base == &"Label" or base == &"Button":
			check_true(_theme.has_font("font", name), "%s assigns a font role" % name)

	check_colors_are_reference_values()
	_build_grid()


func _color_for(key: String) -> Color:
	match key:
		"black":
			return Color(0, 0, 0, 1)
		"white":
			return Color(1, 1, 1, 1)
		_:
			return PALETTE.get(key, Color.MAGENTA)


## The values the token map promises for the styleboxes, read back from the loaded resource.
func check_colors_are_reference_values() -> void:
	var primary := _theme.get_stylebox("normal", "ButtonPrimary")
	check_true(primary is StyleBoxFlat, "ButtonPrimary normal box is a StyleBoxFlat")
	if primary is StyleBoxFlat:
		var p := primary as StyleBoxFlat
		check_true(p.bg_color.is_equal_approx(PALETTE["button_gradient_start"]),
			"primary fill = measured gradient start %s" % p.bg_color.to_html(true))
		check_eq(p.corner_radius_top_left, 10, "primary corner radius = 10 px (measured)")
		check_eq(int(p.content_margin_left), 28, "primary left padding = 28 px (measured)")
		check_eq(int(p.content_margin_top), 16, "primary top padding = 16 px (measured)")
		check_true(p.shadow_color.is_equal_approx(PALETTE["cyan"] * Color(1, 1, 1, 0.5)),
			"primary glow = cyan at 50%% alpha (measured %s)" % p.shadow_color.to_html(true))
		check_eq(p.shadow_size, 28, "primary glow blur = 28 px (measured)")

	var panel := _theme.get_stylebox("panel", "PanelDark")
	if panel is StyleBoxFlat:
		var b := panel as StyleBoxFlat
		check_true(b.bg_color.is_equal_approx(PALETTE["panel"]), "panel fill = --panel")
		check_true(b.border_color.is_equal_approx(PALETTE["line"]), "panel border = --line")
		check_eq(b.corner_radius_top_left, 12, "panel radius = 12 px (measured)")

	var active := _theme.get_stylebox("normal", "SegmentedActive")
	if active is StyleBoxFlat:
		var a := active as StyleBoxFlat
		check_true(a.bg_color.is_equal_approx(PALETTE["segmented_gradient_start"]),
			"active chip fill = measured gradient start %s" % a.bg_color.to_html(true))
		check_eq(a.corner_radius_top_left, 7, "active chip radius = 7 px (measured)")

	var hud := _theme.get_stylebox("panel", "HudPanel")
	if hud is StyleBoxFlat:
		check_true((hud as StyleBoxFlat).bg_color.is_equal_approx(PALETTE["hud_panel_bg"]),
			"hud panel fill = rgba(6,24,46,0.82) (measured)")

	# The pre-gate wave's two additions (README §5): the flashing tactic chip and the
	# timer ball. Values are the reference's own lines, transcribed here.
	var flash := _theme.get_stylebox("normal", "SegmentedFlash")
	check_true(flash is StyleBoxFlat, "SegmentedFlash normal box is a StyleBoxFlat")
	if flash is StyleBoxFlat:
		var f := flash as StyleBoxFlat
		check_true(f.bg_color.is_equal_approx(PALETTE["success_cyan"]),
			"flash chip fill = #8fffd0 (styles.css:680, %s)" % f.bg_color.to_html(true))
		check_eq(f.corner_radius_top_left, 7, "flash chip radius = 7 px (the idle chip's own box)")
	var flash_text := _theme.get_color("font_color", "SegmentedFlash")
	check_true(flash_text.is_equal_approx(Color(7 / 255.0, 29 / 255.0, 52 / 255.0)),
		"flash chip text = #071d34 (styles.css:679, %s)" % flash_text.to_html(true))

	var ball := _theme.get_stylebox("panel", "TimerBall")
	check_true(ball is StyleBoxFlat, "TimerBall panel box is a StyleBoxFlat")
	if ball is StyleBoxFlat:
		var b := ball as StyleBoxFlat
		check_true(b.bg_color.is_equal_approx(Color(216 / 255.0, 255 / 255.0, 95 / 255.0)),
			"timer ball fill = #d8ff5f (styles.css:754, %s)" % b.bg_color.to_html(true))
		check_eq(b.border_width_top, 3, "timer ball border = 3 px (styles.css:752)")
		check_true(b.border_color.is_equal_approx(Color(217 / 255.0, 248 / 255.0, 1.0)),
			"timer ball border = #d9f8ff (styles.css:752, %s)" % b.border_color.to_html(true))
		check_eq(b.corner_radius_top_left, 19, "timer ball radius = 19 px (a 38 px circle)")


## One labelled row per variation, plus the row that mirrors the stylesheet's key measurements.
func _build_grid() -> void:
	_host = Control.new()
	_host.name = "ThemeProbeFrame"
	_host.size = SIZES[0]
	root.add_child(_host)
	# The grid must render UNDER the theme it checks. Without this assignment every cell
	# below is styled by the engine defaults and the layout assertions measure the wrong
	# interface — found by the first engine run of this probe (integrator, 2026-09-17):
	# the primary button measured 31 px (unthemed default) instead of its themed 52 px.
	_host.theme = _theme

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_host.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Rows"
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := Label.new()
	header.name = "ScreenTitleRow"
	header.theme_type_variation = &"ScreenTitle"
	header.text = "CAMPI STEAMPUNK"
	column.add_child(header)
	_cells.append(header)

	var subtitle := Label.new()
	subtitle.name = "ScreenSubtitleRow"
	subtitle.theme_type_variation = &"ScreenSubtitle"
	subtitle.text = "Scegli l'arena del circuito"
	column.add_child(subtitle)
	_cells.append(subtitle)

	var row := HBoxContainer.new()
	row.name = "ReferenceMeasurements"
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var primary := Button.new()
	primary.name = "PrimaryNatural"
	primary.theme_type_variation = &"ButtonPrimary"
	primary.text = "PARTITA RAPIDA"
	row.add_child(primary)
	_cells.append(primary)
	var secondary := Button.new()
	secondary.name = "SecondaryNatural"
	secondary.theme_type_variation = &"ButtonSecondary"
	secondary.text = "TORNEO"
	row.add_child(secondary)
	_cells.append(secondary)
	var ghost := Button.new()
	ghost.name = "GhostNatural"
	ghost.theme_type_variation = &"ButtonGhost"
	ghost.text = "Indietro"
	row.add_child(ghost)
	_cells.append(ghost)
	var hud_button := Button.new()
	hud_button.name = "HudButtonNatural"
	hud_button.theme_type_variation = &"HudButton"
	hud_button.text = "▤"
	hud_button.custom_minimum_size = Vector2(42, 42)
	row.add_child(hud_button)
	_cells.append(hud_button)
	# The reference row measures natural heights too (same rule as the grid cells above).
	for child in row.get_children():
		(child as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Four columns so that ~30 rows fit every one of the four frames: with three the grid
	# overflowed the smallest frame (1024x600) by ~90 px on the first engine run
	# (integrator, 2026-09-17: `Probe_HudPauseCard y=615..638`).
	var grid := HBoxContainer.new()
	grid.name = "Grid"
	grid.add_theme_constant_override("separation", 12)
	column.add_child(grid)
	var columns: Array[VBoxContainer] = []
	for i in 4:
		var col := VBoxContainer.new()
		col.name = "Col%d" % i
		col.add_theme_constant_override("separation", 4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(col)
		columns.append(col)
	# Rows are distributed tallest-first across the columns instead of in table order: the
	# panels are the tall cells (content margins up to 26/30 px) and packing them in
	# insertion order still overflowed the two smallest frames (integrator, 2026-09-17).
	# The weight only balances; the layout check below stays the verdict.
	var order: Array = VARIATIONS.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _row_weight(String(a), VARIATIONS[a]) > _row_weight(String(b), VARIATIONS[b]))
	var index := 0
	for name in order:
		var spec: Array = VARIATIONS[name]
		var line := VBoxContainer.new()
		line.name = "Row_" + name
		line.add_theme_constant_override("separation", 2)
		columns[index % columns.size()].add_child(line)
		index += 1
		var tag := Label.new()
		tag.text = name
		# The annotation is small on purpose: at the theme's own 16 px the tags helped push the
		# tallest column past the 1024x600 frame (integrator, 2026-09-17).
		tag.add_theme_font_size_override("font_size", 9)
		line.add_child(tag)
		var control: Control
		match String(spec[0]):
			"Button":
				var button := Button.new()
				button.text = name
				control = button
			"Panel":
				# The panel cell is the box itself, at a fixed readable height: a PanelContainer
				# grew by its own content margins (HudPauseCard laid out 87 px tall) and helped
				# overflow the two small frames. The tag above names it; the box shows fill,
				# border, radius and shadow — which is what this variation is.
				var panel := Panel.new()
				panel.custom_minimum_size = Vector2(0.0, 40.0)
				control = panel
			_:
				var label := Label.new()
				label.text = name
				control = label
		control.name = "Probe_" + name
		control.theme_type_variation = name
		# The reference fixes some heights in CSS itself (`styles.css:2226`
		# `.segmented button { height: 42px }`); a Godot theme carries no height (README
		# §6.5), so the screen side declares it as `custom_minimum_size` — the probe mirrors
		# that rule here, which is what makes the band check below measure the reference's
		# own geometry instead of a bare label (integrator, 2026-09-17).
		if name == "SegmentedInactive" or name == "SegmentedActive":
			control.custom_minimum_size = Vector2(0.0, 42.0)
		# Natural size, not stretched: the cells are measured against their own minimum, so a
		# taller sibling row can never inflate (or a compressed frame deflate) the reading.
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(control)
		_cells.append(control)


## A row's likely height, used only to balance the four columns: panels carry the theme's
## largest content margins, buttons carry their padding, labels carry their font size. A
## wrong guess costs slack, never correctness — the layout check is the verdict.
func _row_weight(name: String, spec: Array) -> float:
	match String(spec[0]):
		"Panel":
			return 78.0 if name == "HudPauseCard" else 66.0
		"Button":
			return 58.0
	return 30.0 + float(spec[1])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_check_layout()
	_size_index += 1
	if _size_index >= SIZES.size():
		_finish()
		return true
	_host.size = SIZES[_size_index]
	root.size = Vector2i(SIZES[_size_index])
	_frames = 0
	return false


## No control may overflow the frame it was given, at any of the four sizes.
func _check_layout() -> void:
	var size: Vector2 = SIZES[_size_index]
	var overflows: Array[String] = []
	var widest := 0.0
	var tallest := 0.0
	for cell in _cells:
		if cell == null or not is_instance_valid(cell):
			continue
		var rect := cell.get_global_rect()
		widest = maxf(widest, rect.size.x)
		tallest = maxf(tallest, rect.size.y)
		if rect.position.x < -0.5 or rect.end.x > size.x + 0.5:
			overflows.append("%s x=%.1f..%.1f" % [cell.name, rect.position.x, rect.end.x])
		if rect.position.y < -0.5 or rect.end.y > size.y + 0.5:
			overflows.append("%s y=%.1f..%.1f" % [cell.name, rect.position.y, rect.end.y])
		var minimum := cell.get_combined_minimum_size()
		if minimum.x > size.x + 0.5:
			overflows.append("%s min width %.1f > %.1f" % [cell.name, minimum.x, size.x])
	var detail := "widest %.1f, tallest %.1f" % [widest, tallest]
	if not overflows.is_empty():
		detail = " | ".join(overflows)
	check_true(overflows.is_empty(),
		"nothing overflows a %dx%d frame (%s)" % [int(size.x), int(size.y), detail])
	print("# frame %dx%d: widest control %.1f px, tallest %.1f px" % [int(size.x), int(size.y), widest, tallest])

	# The reference's own key measurements, for the record (menu frame: title 38.4 px,
	# primary button 51 px tall with 16 px font, segmented chip 42 px tall). Measured as the
	# control's NATURAL height (`get_combined_minimum_size`): the themed minimum is what the
	# theme expresses, and a container's stretch must not move a band reading.
	var primary_cell: Control = _find("Probe_ButtonPrimary")
	if primary_cell != null:
		var height := primary_cell.get_combined_minimum_size().y
		print("# reference primary button: measured 51 px tall at 16 px/28 px padding; this theme's natural height is %.1f px" % height)
		check_true(height >= 40.0 and height <= 62.0,
			"primary button height %.1f px stays in the reference's band (40-62)" % height)
	var chip_cell: Control = _find("Probe_SegmentedActive")
	if chip_cell != null:
		var chip := chip_cell.get_combined_minimum_size().y
		print("# reference segmented chip: measured 42 px tall (its CSS height, declared here as custom_minimum_size); this theme with that rule is %.1f px" % chip)
		check_true(chip >= 34.0 and chip <= 52.0,
			"segmented chip height %.1f px stays in the reference's band (34-52)" % chip)


func _find(node_name: String) -> Control:
	var found := _host.find_child(node_name, true, false)
	return found as Control


## WCAG relative-luminance contrast, computed here so the numbers on the log are reproducible.
func _relative_luminance(color: Color, backdrop: Color) -> float:
	var c := color
	if c.a < 1.0:
		c = Color(
			backdrop.r * (1.0 - color.a) + color.r * color.a,
			backdrop.g * (1.0 - color.a) + color.g * color.a,
			backdrop.b * (1.0 - color.a) + color.b * color.a,
			1.0)
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


func _channel(value: float) -> float:
	if value <= 0.03928:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


func _contrast(fg: Color, backdrop: Color) -> float:
	var a := _relative_luminance(fg, backdrop)
	var b := _relative_luminance(backdrop, backdrop)
	var hi := maxf(a, b)
	var lo := minf(a, b)
	return (hi + 0.05) / (lo + 0.05)


func _check_contrast(label: String, fg: Color, backdrop: Color, floor: float) -> void:
	var ratio := _contrast(fg, backdrop)
	var text := "%s contrast %.2f:1 (floor %.1f:1)" % [label, ratio, floor]
	check_true(ratio >= floor, text)


func _finish() -> void:
	_check_contrast("ink on --bg", PALETTE["ink"], PALETTE["bg"], 10.0)
	_check_contrast("muted on --bg", PALETTE["muted"], PALETTE["bg"], 3.5)
	_check_contrast("muted on --panel", PALETTE["muted"], PALETTE["panel"], 3.5)
	_check_contrast("black on primary button", Color(0, 0, 0, 1), PALETTE["button_gradient_start"], 10.0)
	_check_contrast("idle chip text on segmented surface", PALETTE["tab_text_idle"], PALETTE["surface_1"], 4.0)
	_check_contrast("active chip text on active chip", PALETTE["surface_0"], PALETTE["segmented_gradient_start"], 8.0)
	_check_contrast("hud label on hud panel", PALETTE["hud_label"], PALETTE["hud_panel_bg"], 4.5)
	_check_contrast("hint text on hint surface", PALETTE["text_soft"], PALETTE["surface_1"], 4.5)
	_finish_report()


func check_eq(got: Variant, expected: Variant, name: String) -> void:
	_checks += 1
	if got == expected:
		print("ok %s" % name)
		return
	_failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(got)]
	print(line)
	printerr(line)


func check_true(got: bool, name: String) -> void:
	check_eq(got, true, name)


func _finish_report() -> void:
	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
	quit(0 if _failures == 0 else 1)
