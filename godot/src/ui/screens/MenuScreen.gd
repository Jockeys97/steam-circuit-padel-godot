## MenuScreen.gd — `screen-menu`, the reference's own front page (`index.html:31-87`).
##
## WHAT THIS SCREEN IS. The web build's first section: a top navigation (brand mark,
## profile and settings buttons, the language toggle), the hero copy (badge, two-line
## title, sub, controller hint, six action buttons) and the hero preview (the key-art
## poster with its caption and the tag row). The markup, the eight `to-*` actions and
## the locale keys are the reference's; nothing here is designed.
##
## THE EIGHT ACTIONS ARE THE REFERENCE'S OWN SPELLINGS. `js/main.js:2199-2246` wires one
## handler per action and the router's table carries the same spellings for this screen
## (`ScreenRouter.SCREENS[0].to`). A press asks the tree this screen was mounted in for
## the router — screens live under the router's host, so `go_to` is found above this
## node and the screen never holds a reference that could be wired to a second router.
##
## THE BUILD CHIP IS THE GATE'S, NOT THIS SCREEN'S. `js/ui.js:742-745` writes the limited
## build's own key into the tag row's chip (`index.html:80`, `.hero-tags__build`) and a
## full build never shows it; the hero badge line above the title is the reference's
## static `heroBadge` (`index.html:49-52`, kept by the ticket's own anatomy) and stays
## visible in every build. `DemoGateAdapter` answers the chip's two questions — key and
## visibility — and this screen only renders the answer. The `demo`/`beta` capture
## states pin the key through the same adapter (`badge_text_key_for`): the port's build
## flag is process-level (`tests/build/BuildFlag.gd` reads OS features and the command
## line), so a capture state cannot set it and does not pretend to.
##
## THE THEME GAP THIS FILE CARRIES. The theme (UIR-02) has variations for the buttons,
## panels and type roles used here, but not yet for the menu's own chrome: the top bar,
## its two icon buttons and the language toggle, the badge dot, the hero hint pill, the
## tag chips, the poster frame and the caption's shadow. Those boxes are composed in
## `_style_chrome()` from `Palette` colours — this file carries no literal colour, and
## no literal size where the theme declares one — and `godot/src/ui/theme/README.md` §7
## carries the follow-up that folds them into variations. The one size the theme cannot
## hold is `.hero h1`'s `clamp(2.4rem, 5vw, 4rem)` (`styles.css:145`), a viewport rule;
## `HeroTitle` is the 1280 px value (64) and `_apply_title_clamp()` re-derives the
## clamped size from the frame, exactly as the CSS does.
##
## LITERALS. The only user-facing literals live in the scene: the poster caption
## ("STEAM CIRCUIT" / "PADEL PRO", `index.html:72-73`, `aria-hidden` in the reference and
## without a `data-i18n`) and the "Alpha 0.2" tag (`index.html:83`, which the ticket says
## to reproduce verbatim). Every other string is a locale id resolved by `UiStrings`.
extends "res://src/ui/screens/ScreenContract.gd"

const UiStrings := preload("res://src/ui/UiStrings.gd")
const Locale := preload("res://src/locale/locale.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")

const SCREEN_ID := "menu"

## `js/main.js:2199-2246`: action -> router id, the reference's own eight spellings.
## `router_audit.gd` cross-checks the router's copy of the same table.
const ACTION_TARGETS := {
	"to-modes": "modes",
	"to-drill": "drill",
	"to-help": "help",
	"to-history": "history",
	"to-challenges": "challenges",
	"to-feedback": "feedback",
	"to-profile": "profile",
	"to-settings": "settings",
}

## Which node carries which action (`index.html:41-65`, markup order).
const ACTION_SLOTS := {
	"to-modes": "PlayButton",
	"to-drill": "DrillButton",
	"to-help": "HelpButton",
	"to-history": "HistoryButton",
	"to-challenges": "ChallengesButton",
	"to-feedback": "FeedbackButton",
	"to-profile": "ProfileButton",
	"to-settings": "SettingsButton",
}

## The visible text slots: node name -> locale id, the `data-i18n` attributes of
## `index.html:31-87`. The hero badge line is one of them; the tag row's build chip is
## not — that text is the gate's answer (`_refresh_badge`).
const TEXT_SLOTS := {
	"BrandLabel": "brand",
	"BadgeLabel": "heroBadge",
	"Title1": "heroTitle1",
	"Title2": "heroTitle2",
	"HeroSub": "heroSub",
	"HintLabel": "heroPadNote",
	"PlayButton": "playNow",
	"DrillButton": "training",
	"HelpButton": "howTo",
	"HistoryButton": "history",
	"ChallengesButton": "challenges",
	"FeedbackButton": "feedback",
	"TagPc": "tagPc",
	"TagArcade": "tagArcade",
}

## The screen-reader names (`data-i18n-aria`): node name -> locale id. The two icon
## buttons also carry the reference's `title` (keys `profile`, `settings`) — applied as
## tooltips, which is what a mouse user meets.
const ARIA_SLOTS := {
	"Root": "ariaMenu",
	"ProfileButton": "ariaProfile",
	"SettingsButton": "ariaSettings",
	"PosterFrame": "ariaHeroImg",
}

const TITLE_SLOTS := {
	"ProfileButton": "profile",
	"SettingsButton": "settings",
}

## The capture states a harness may ask for: the live build, and the reference's two
## limited builds pinned to their badge.
const CAPTURE_STATES: Array[String] = ["default", "demo", "beta"]

## The language toggle is not one of the reference's `to-*` actions — it changes the
## screen, not the screen — so it carries its own action name (UIR-09's mount wires it
## to `toggle_language`).
const LANG_ACTION := "lang-toggle"

## The pair the reference's toggle flips between (`js/main.js:2421`).
const LANGS: Array[String] = ["it", "en"]

## The title lines the clamp applies to, and `.hero h1`'s rule (`styles.css:145`):
## `clamp(2.4rem, 5vw, 4rem)` at the reference's 16 px root.
const TITLE_NODES: Array[String] = ["Title1", "Title2"]
const TITLE_MIN_PX := 38.4
const TITLE_MAX_PX := 64.0
const TITLE_VW := 0.05

## Godot's accessible-name property, where the engine holds it (the probe in
## `_set_accessible_name` records its absence instead of inventing a fourth path).
const ACCESSIBILITY_NAME_PROPERTY := "accessibility_name"

## The chrome nodes addressed by name — kept as constants so the audit's scan and this
## file agree on the spellings.
const BADGE_NODE := "Badge"
const BADGE_LABEL_NODE := "BadgeLabel"
## The tag row's build chip (`index.html:80`, `.hero-tags__build`): the node the limited
## build's own name is written into, and the one a full build keeps hidden.
const BUILD_BADGE_NODE := "BuildBadge"
const TOP_NAV_NODE := "TopNav"
const LANG_NODE := "LangToggle"
const HINT_PILL_NODE := "HintPill"
const POSTER_NODE := "PosterFrame"
const CAPTION_NODE := "Caption"
## `.hero-poster__title`'s design box: `right: 22px` (`styles.css:207`) over the
## scene's own 400 px left offset (`MenuScreen.tscn`) — 378 px wide at the design
## frame. It is a ceiling, not a constant: `_apply_caption_fit()` re-derives the
## width off the poster on every resize.
const CAPTION_WIDTH := 400.0
const CAPTION_RIGHT := 22.0
## `find_child` cannot find the root by name, so the aria slot for the screen itself
## (`index.html:31`, `data-i18n-aria="ariaMenu"` on the section) is addressed as this.
const ROOT_ALIAS := "Root"

## The router told this screen's `enter()` (the router's own facts).
var router_id: String = ""
var back_target_id: String = ""

## The badge key a capture run pinned (`""` = the live gate's own answer).
var badge_key_override: String = ""

## The build chip and the label it carries (the same node: `BuildBadge` is a Label).
var _badge: Control
var _badge_label: Label
var _focus_specs: Dictionary = {}


func _ready() -> void:
	_style_chrome()
	_wire_actions()
	resized.connect(_apply_title_clamp)
	var preview := _control("HeroPreview")
	if preview != null:
		preview.resized.connect(_apply_poster_aspect)
	var poster := _control(POSTER_NODE)
	if poster != null:
		poster.resized.connect(_apply_caption_fit)
	_apply_title_clamp()
	_apply_poster_aspect()
	refresh_strings()


func screen_id() -> String:
	return SCREEN_ID


func back_target() -> String:
	return back_target_id


## The router mounted this screen: it hands over its own facts (`router_id`,
## `back_target`) and this screen re-resolves every string it shows, so a screen entered
## under a different language is correct the moment it appears.
func enter(payload: Dictionary) -> void:
	router_id = String(payload.get("router_id", router_id))
	back_target_id = String(payload.get("back_target", back_target_id))
	_apply_title_clamp()
	_apply_poster_aspect()
	refresh_strings()
	_apply_caption_fit()


func exit() -> void:
	pass


func capture_states() -> Array[String]:
	return CAPTURE_STATES.duplicate()


## `default` = the live build; `demo`/`beta` = the badge pinned to that build's own key
## through the adapter. The flag itself is process-level and is not faked: what a
## capture gets is the badge row the reference shows for that build.
func apply_capture_state(state_id: String) -> bool:
	match state_id:
		"default":
			badge_key_override = ""
		"demo":
			badge_key_override = DemoGate.badge_text_key_for("demo")
		"beta":
			badge_key_override = DemoGate.badge_text_key_for("beta")
		_:
			return false
	refresh_strings()
	return true


# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------

## Re-resolves every string this screen shows: the `data-i18n` slots, the badge (the
## gate's answer or a capture's), the toggle's own label, the two title colours and the
## aria names. The reference does the same on `setLanguage` (`js/main.js:2421`).
func refresh_strings() -> void:
	for node_name in TEXT_SLOTS:
		var control := _control(node_name)
		var text := UiStrings.t(String(TEXT_SLOTS[node_name]))
		if control is Button:
			(control as Button).text = text
		elif control is Label:
			(control as Label).text = text
	var toggle := _control(LANG_NODE) as Button
	if toggle != null:
		toggle.text = next_lang_label()
	_refresh_badge()
	_refresh_aria()


## The label the toggle shows: the language a press switches TO — the reference's own
## rule (`langToggle.textContent = getLang() === "it" ? "EN" : "IT"`).
func next_lang_label() -> String:
	return next_lang().to_upper()


func next_lang() -> String:
	return LANGS[0] if Locale.current_lang() == LANGS[1] else LANGS[1]


func toggle_language() -> void:
	Locale.set_lang(next_lang())
	refresh_strings()


# ---------------------------------------------------------------------------
# The build chip (`js/ui.js:742-750`)
# ---------------------------------------------------------------------------

## The tag row's chip takes the limited build's own key and is unhidden only where the
## gate says a limited build is running. The hero badge line above the title is not this
## one: it is the reference's static `heroBadge`, resolved through `TEXT_SLOTS`.
func _refresh_badge() -> void:
	var key := badge_key_shown()
	var visible := key != "" and (badge_key_override != "" or DemoGate.badge_visible())
	_badge.visible = visible
	_badge_label.text = UiStrings.t(key) if visible else ""


## The badge key this screen is currently rendering (the gate's own answer, or the
## capture state's) — what the audit compares against, so the check never re-derives
## the rule it is checking.
func badge_key_shown() -> String:
	return badge_key_override if badge_key_override != "" else DemoGate.badge_text_key()


func badge_visible_shown() -> bool:
	return _badge.visible


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _wire_actions() -> void:
	for action in ACTION_SLOTS:
		var button := _control(String(ACTION_SLOTS[action])) as Button
		if button == null:
			continue
		button.pressed.connect(route_action.bind(String(action)))
	var toggle := _control(LANG_NODE) as Button
	if toggle != null:
		toggle.pressed.connect(toggle_language)
	_register_focus()


## The router moves. It is the first node above this screen that owns `go_to`
## (`ScreenRouter` mounts screens under its host); a press with no router above is
## reported, not swallowed.
func route_action(action: String) -> bool:
	var target := String(ACTION_TARGETS.get(action, ""))
	if target == "":
		push_error("MenuScreen.route_action: '%s' is not one of this screen's actions" % action)
		return false
	var node: Node = get_parent()
	while node != null:
		if node.has_method("go_to"):
			return bool(node.go_to(target))
		node = node.get_parent()
	push_warning("MenuScreen: no router above this screen; '%s' went nowhere" % action)
	return false


# ---------------------------------------------------------------------------
# Focus (UIR-05's bridge consumes these; the screen only names its controls)
# ---------------------------------------------------------------------------

func _register_focus() -> void:
	for action in ACTION_SLOTS:
		var node_name := String(ACTION_SLOTS[action])
		var control := _control(node_name)
		if control == null:
			continue
		_focus_specs[node_name] = _focus_spec(node_name, control, action)
	var toggle := _control(LANG_NODE)
	if toggle != null:
		_focus_specs[LANG_NODE] = _focus_spec(LANG_NODE, toggle, LANG_ACTION)


func _focus_spec(node_name: String, control: Control, action: String) -> Dictionary:
	return {
		"id": "%s/%s" % [SCREEN_ID, node_name],
		"node": control,
		"action": action,
		"opts": {"kind": "button"},
	}


func focus_controls() -> Array:
	return _focus_specs.values()


# ---------------------------------------------------------------------------
# The aria equivalents (`data-i18n-aria`)
# ---------------------------------------------------------------------------

func _refresh_aria() -> void:
	for node_name in ARIA_SLOTS:
		_set_accessible_name(_control(node_name), UiStrings.t(String(ARIA_SLOTS[node_name])))
	for node_name in TITLE_SLOTS:
		var control := _control(node_name)
		if control is Control:
			(control as Control).tooltip_text = UiStrings.t(String(TITLE_SLOTS[node_name]))


## The resolved aria names, node name -> text: what the audit compares across a language
## flip without depending on an engine property that may not exist.
func aria_names() -> Dictionary:
	var out := {}
	for node_name in ARIA_SLOTS:
		out[node_name] = UiStrings.t(String(ARIA_SLOTS[node_name]))
	return out


## Set the accessible name where the engine holds the property; where it does not, the
## tooltips and `aria_names()` still carry the reference's names, and the hand-back says
## which of the two paths this engine took.
func _set_accessible_name(node: Node, text: String) -> void:
	if node == null:
		return
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == ACCESSIBILITY_NAME_PROPERTY:
			node.set(ACCESSIBILITY_NAME_PROPERTY, text)
			return


## True when this engine's Controls carry `accessibility_name` — recorded by the audit.
func engine_has_accessible_name() -> bool:
	var probe := Control.new()
	var found := false
	for entry in probe.get_property_list():
		if String(entry.get("name", "")) == ACCESSIBILITY_NAME_PROPERTY:
			found = true
			break
	probe.free()
	return found


# ---------------------------------------------------------------------------
# `.hero h1`'s clamp (styles.css:145) — the one size the theme cannot hold
# ---------------------------------------------------------------------------

func _apply_title_clamp() -> void:
	var rounded := int(round(clampf(size.x * TITLE_VW, TITLE_MIN_PX, TITLE_MAX_PX)))
	for node_name in TITLE_NODES:
		var label := _control(node_name) as Label
		if label != null:
			label.add_theme_font_size_override("font_size", rounded)


## `.hero-poster`'s `aspect-ratio: 16 / 9` (styles.css:183) is width-driven, and a Godot
## container derives no height from its own width — so the poster's height is computed
## from its column here, the same way the clamped title is. Called on the column's
## `resized`, and again on `enter()` for a screen mounted at a size it has not seen.
func _apply_poster_aspect() -> void:
	var preview := _control("HeroPreview")
	var poster := _control(POSTER_NODE)
	if preview == null or poster == null:
		return
	poster.custom_minimum_size.y = preview.size.x * POSTER_HEIGHT_PER_WIDTH


## `9 / 16`, from `.hero-poster`'s `aspect-ratio: 16 / 9`.
const POSTER_HEIGHT_PER_WIDTH := 0.5625


## `.hero-poster__title` is `position:absolute; right:22px; bottom:18px` over a
## content-sized grid (`styles.css:205-217`): its box follows the two caption lines
## and is pinned to the poster's corner, never past it. The scene carries the design
## box (offsets -400/-22); as a fixed 378 px box it left `PosterFrame` by 9 px once
## the poster column shrank to 391 px at 1024x600 (UIR-24's legibility audit,
## `evidence/uir-24-legibility.log`). Re-derived whenever either side moves, capped
## at the design width and at the poster's own width, so the right-anchored text
## keeps its position and the box can never overhang.
func _apply_caption_fit() -> void:
	var poster := _control(POSTER_NODE)
	var caption := _control(CAPTION_NODE)
	if poster == null or caption == null:
		return
	var cap := maxf(0.0, minf(CAPTION_WIDTH, poster.size.x) - CAPTION_RIGHT)
	var width := minf(caption.get_combined_minimum_size().x, cap)
	# The scene's own anchors keep the bottom-right pin (`bottom: 18px`); only the
	# left edge moves, and the two lines are right-aligned inside whatever box this
	# leaves, so the text itself never moves.
	caption.offset_left = -(width + CAPTION_RIGHT)
	caption.offset_right = -CAPTION_RIGHT


# ---------------------------------------------------------------------------
# The scene
# ---------------------------------------------------------------------------

func _control(node_name: String) -> Control:
	if node_name == ROOT_ALIAS:
		return self
	return find_child(node_name, true, false) as Control


# ---------------------------------------------------------------------------
# Menu chrome (the theme gap: see this file's header and theme README §7)
# ---------------------------------------------------------------------------

func _style_chrome() -> void:
	var theme: Theme = self.theme
	if theme == null:
		push_error("MenuScreen: the scene carries no theme; the chrome cannot be composed")
		return
	_box(BADGE_NODE, "panel", theme.get_stylebox("normal", "Badge"))
	_box("BadgeDot", "panel", _dot_box(theme))
	_box(HINT_PILL_NODE, "panel", _hint_box(theme))
	_box(POSTER_NODE, "panel", _poster_box(theme))
	_box(TOP_NAV_NODE, "panel", _top_nav_box(theme))
	_box("BrandRing", "panel", _brand_ring_box(theme))
	_box("BrandDot", "panel", _brand_dot_box(theme))
	for node_name in ["TagPc", "TagArcade", "AlphaTag"]:
		_box(node_name, "normal", _tag_box(theme))
	_box("BuildBadge", "normal", _build_badge_box(theme))
	for node_name in ["ProfileButton", "SettingsButton"]:
		for slot in ["normal", "hover", "pressed"]:
			_box(node_name, slot, _nav_button_box(theme, slot != "normal"))
	for slot in ["normal", "hover", "pressed"]:
		_box(LANG_NODE, slot, _lang_toggle_box(theme, slot != "normal"))
	_badge = _control(BUILD_BADGE_NODE)
	_badge_label = _badge as Label
	_chrome_fonts(theme)
	_tags_typography(theme)
	_caption(theme)
	_key_art()


func _box(node_name: String, slot: String, box: StyleBox) -> void:
	var control := _control(node_name)
	if control == null:
		push_error("MenuScreen: the scene has no '%s' to style" % node_name)
		return
	control.add_theme_stylebox_override(slot, box)


## `.top-nav` (styles.css:81-92): the bar, its 32 px side padding carried as content
## margins so the row reaches the frame's edges.
func _top_nav_box(theme: Theme) -> StyleBoxFlat:
	var box := _flat(theme.get_color("nav_bg", "Palette"))
	box.border_color = _alpha(theme.get_color("cyan", "Palette"), 0.1)
	box.border_width_bottom = 1
	box.content_margin_left = 32.0
	box.content_margin_right = 32.0
	box.content_margin_top = 0.0
	box.content_margin_bottom = 0.0
	return box


## `.top-nav-btn` (styles.css:2113-2126): `#0b2444` on `#28567d`, radius 6, padding 7/10,
## hover `#123a68`.
func _nav_button_box(theme: Theme, hover: bool) -> StyleBoxFlat:
	var box := _chrome_button_base(theme, 10.0)
	if hover:
		box.bg_color = theme.get_color("hud_button_hover", "Palette")
	return box


## `.lang-toggle` (styles.css:2092-2104): the same box, padding 7/14.
func _lang_toggle_box(theme: Theme, hover: bool) -> StyleBoxFlat:
	var box := _chrome_button_base(theme, 14.0)
	if hover:
		box.bg_color = theme.get_color("hud_button_hover", "Palette")
	return box


func _chrome_button_base(theme: Theme, side: float) -> StyleBoxFlat:
	var box := _flat(theme.get_color("surface_2", "Palette"))
	box.border_color = theme.get_color("tab_border", "Palette")
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	_edge_margins(box, side, 7.0)
	return box


## `.badge-dot` (styles.css:133-140): 6 px green with a 6 px glow.
func _dot_box(theme: Theme) -> StyleBoxFlat:
	var green := theme.get_color("green", "Palette")
	var box := _flat(green)
	box.set_corner_radius_all(3)
	box.shadow_color = green
	box.shadow_size = 6
	return box


## `.hero-hint` (styles.css:160-173): a pill over `#16bed7` at 8 %, border `#7ef3ff` at
## 28 %, padding 7/14/7/9.
func _hint_box(theme: Theme) -> StyleBoxFlat:
	var box := _flat(_alpha(theme.get_color("segmented_gradient_start", "Palette"), 0.08))
	box.border_color = _alpha(theme.get_color("text_soft_3", "Palette"), 0.28)
	box.set_corner_radius_all(20)
	box.set_border_width_all(1)
	box.content_margin_left = 9.0
	box.content_margin_right = 14.0
	box.content_margin_top = 7.0
	box.content_margin_bottom = 7.0
	return box


## `.hero-poster` (styles.css:179-189): `#061426`, 2 px `rgba(0,229,255,0.32)`, radius 8,
## `var(--shadow)` — the theme's own blur/offset mapping (theme README §6.3).
func _poster_box(theme: Theme) -> StyleBoxFlat:
	var box := _flat(theme.get_color("surface_0", "Palette"))
	box.border_color = _alpha(theme.get_color("cyan", "Palette"), 0.32)
	box.set_corner_radius_all(8)
	box.set_border_width_all(2)
	box.shadow_color = theme.get_color("shadow", "Palette")
	box.shadow_size = 80
	box.shadow_offset = Vector2(0.0, 24.0)
	return box


## `.brand-logo` (`index.html:34-37`): a cyan ring with a gold dot in a 42 px box.
func _brand_ring_box(theme: Theme) -> StyleBoxFlat:
	var cyan := theme.get_color("cyan", "Palette")
	var box := _flat(cyan)
	box.draw_center = false
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.shadow_color = _alpha(cyan, 0.45)
	box.shadow_size = 8
	return box


func _brand_dot_box(theme: Theme) -> StyleBoxFlat:
	var box := _flat(theme.get_color("gold", "Palette"))
	box.set_corner_radius_all(5)
	return box


## `.hero-tags span` (styles.css:235-243): radius 6 — not `BoxBadge`'s 20 — over
## `rgba(255,255,255,0.06)`, border `--line`, padding 7/14.
func _tag_box(theme: Theme) -> StyleBoxFlat:
	var box := _flat(_alpha(theme.get_color("ink", "Palette"), 0.06))
	box.border_color = theme.get_color("line", "Palette")
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	_edge_margins(box, 14.0, 7.0)
	return box


## `.hero-tags__build` (styles.css:3626-3634): the gold chip a limited build shows.
func _build_badge_box(theme: Theme) -> StyleBoxFlat:
	var gold := theme.get_color("gold", "Palette")
	var box := _flat(_alpha(gold, 0.12))
	box.border_color = _alpha(gold, 0.55)
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	_edge_margins(box, 14.0, 7.0)
	return box


## The chrome's type, read from the theme's own variations where one matches the
## reference's role (`Button` = Lilita 16, `Badge`, `LabelSmall`, `ButtonGhost`), so a
## theme change moves these with everything else. The colours the theme does not carry
## as roles are `Palette` reads, exactly like the boxes above.
func _chrome_fonts(theme: Theme) -> void:
	var brand := _control("BrandLabel") as Label
	brand.add_theme_font_override("font", theme.get_font("font", "Button"))
	brand.add_theme_font_size_override("font_size", 16)
	brand.add_theme_color_override("font_color", theme.get_color("cyan", "Palette"))
	var title2 := _control("Title2") as Label
	title2.add_theme_color_override("font_color", theme.get_color("cyan", "Palette"))
	var sub := _control("HeroSub") as Label
	sub.add_theme_color_override("font_color", _alpha(theme.get_color("ink", "Palette"), 0.55))
	var hint := _control("HintLabel") as Label
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", _alpha(theme.get_color("ink", "Palette"), 0.68))
	var hint_icon := _control("HintIcon") as Label
	hint_icon.add_theme_font_size_override("font_size", 15)
	for node_name in ["ProfileButton", "SettingsButton"]:
		var button := _control(node_name) as Button
		button.add_theme_font_size_override("font_size", 15)
	var badge_label := _control(BADGE_LABEL_NODE) as Label
	badge_label.add_theme_font_override("font", theme.get_font("font", "Badge"))
	badge_label.add_theme_font_size_override("font_size", theme.get_font_size("font_size", "Badge"))
	badge_label.add_theme_color_override("font_color", theme.get_color("ink", "Palette"))


## `.hero-tags span` (styles.css:235-243): Nunito 700 at 0.68 rem — the theme's
## `FontBodyBoldButton` role — and the build badge at 800 with 0.1 em tracking
## (`FontLabelSmall`), in gold.
func _tags_typography(theme: Theme) -> void:
	for node_name in ["TagPc", "TagArcade", "AlphaTag"]:
		var label := _control(node_name) as Label
		label.add_theme_font_override("font", theme.get_font("font", "ButtonGhost"))
		label.add_theme_font_size_override("font_size", 11)
	var build := _control("BuildBadge") as Label
	build.add_theme_font_override("font", theme.get_font("font", "LabelSmall"))
	build.add_theme_font_size_override("font_size", 11)
	build.add_theme_color_override("font_color", theme.get_color("gold", "Palette"))


## `.hero-poster__title` (styles.css:210-227): Lilita One, two clamped sizes at 1280
## (31 and 23), the dark offset shadow. The cyan glow half of `text-shadow` is not
## expressible (theme README §6.2).
func _caption(theme: Theme) -> void:
	var shadow := theme.get_color("caption_shadow", "Palette")
	for node_name in ["CaptionLine1", "CaptionLine2"]:
		var label := _control(node_name) as Label
		label.add_theme_font_override("font", theme.get_font("font", "HeroTitle"))
		label.add_theme_color_override("font_shadow_color", shadow)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.add_theme_constant_override("shadow_outline_size", 0)
	var line1 := _control("CaptionLine1") as Label
	line1.add_theme_font_size_override("font_size", 31)
	line1.add_theme_color_override("font_color", theme.get_color("ink", "Palette"))
	var line2 := _control("CaptionLine2") as Label
	line2.add_theme_font_size_override("font_size", 23)
	line2.add_theme_color_override("font_color", theme.get_color("cyan", "Palette"))


## `.hero-poster img` (styles.css:197-202): cover the frame; and `::after`
## (styles.css:191-196) — the fade over the poster's lower 52 %, from `poster_fade`.
func _key_art() -> void:
	var art := _control("KeyArt") as TextureRect
	if art != null:
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var fade := _control("PosterFade") as TextureRect
	if fade == null:
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, _theme_palette_color("poster_fade"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	fade.texture = texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE


func _theme_palette_color(key: String) -> Color:
	return self.theme.get_color(key, "Palette")


func _flat(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	return box


func _alpha(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out


func _edge_margins(box: StyleBoxFlat, side: float, vertical: float) -> void:
	box.content_margin_left = side
	box.content_margin_right = side
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
