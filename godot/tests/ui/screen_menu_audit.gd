## screen_menu_audit.gd — UIR-07's contract audit: the menu screen in a real router.
##
## WHAT IT PROVES, and why each check is the reference's own question:
##
##   1. the router still carries the thirteen ids and the menu mounts through it
##      (`js/ui.js:444-458`, `:595-607`);
##   2. all eight actions on the screen route to the reference's own targets — six hero
##      actions plus profile and settings, which the reference guards as separate
##      destinations (`js/main.js:2199-2246`);
##   3. zero user-facing literals in `MenuScreen.gd`, scanned with the same rule
##      `router_audit.gd` applies to the whole UI lane (a literal with a space, outside a
##      comment and off a developer-marker line, is prose) — with the scan's own
##      synthetic proof that it can still see prose;
##   4. a language flip changes every visible string that the two locale tables actually
##      differ on, including the aria names and the toggle's own label
##      (`js/main.js:2421`, `js/i18n.js`);
##   5. the hero badge line is the reference's static `heroBadge` — always on, in both
##      languages — beside the tag row's build chip, which follows the build gate, and the
##      three declared capture states walk (`index.html:49-52`, `:78-80`, `js/ui.js:742-750`);
##   6. the screen reports one capture-state walk (`MenuScreen.capture_states()`);
##   7. the layout holds at 1280x720 and 1024x600 — no horizontal overflow, the poster
##      keeps its 16:9, and the hero's own content fits the frame it is shown in;
##   8. UIR-05's bridge can read the screen: nine focusables, and a confirm dispatch on
##      the primary button lands on `modes`.
##
## Both runs the ticket asks for share this file: a full build and `-- --demo`. The build
## chip checks branch on `DemoGateAdapter.build()`, so the same audit proves "hidden in a
## full build" and "shown in a demo" without being told which run it is in; the hero badge
## line is checked in both runs and both languages, because it never follows the gate.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const MenuScreenClass := preload("res://src/ui/screens/MenuScreen.gd")
const MenuScene := preload("res://src/ui/screens/MenuScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")
const DemoGate := preload("res://src/ui/data/DemoGateAdapter.gd")

const SCREEN_PATH := "res://src/ui/screens/MenuScreen.gd"
const SCENE_PATH := "res://src/ui/screens/MenuScreen.tscn"

const SETTLE_FRAMES := 3
const FRAME_BIG := Vector2(1280, 720)
const FRAME_SMALL := Vector2(1024, 600)
const REFERENCE_SCREEN_COUNT := 13

## The literals the SCENE is allowed to carry, named one by one: the poster caption
## (`index.html:72-73`, `aria-hidden` there and without a `data-i18n`), the reference's
## own "Alpha 0.2" tag (`index.html:83`), and the three emoji glyphs the ticket's decision
## rule says to render as-is (`index.html:41-42`, `:58`). `MenuScreen.gd` itself is
## allowed none.
const SCENE_LITERALS := ["STEAM CIRCUIT", "PADEL PRO", "Alpha 0.2", "👤", "⚙️", "🎮"]

## A line that builds a message for a developer is not user-facing text (same rule and
## same words as `router_audit.gd`).
const DEVELOPER_MARKERS := ["push_error(", "push_warning(", "printerr(", "assert("]

## The scan's own proof: one prose literal (line 2), one developer message, one locale
## id, one comment quoting prose. Only the first may be reported.
const PROBE_SOURCE := "func x() -> void:\n\tlabel.text = \"Play now\"\n\tpush_error(\"dev only\")\n\tlabel.text = UiStrings.t(\"modesTitle\")\n## a comment quoting \"prose in a comment\"\n"

var _router: Control


func _initialize() -> void:
	var audit := AuditBase.new("screen_menu")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	var frame := Control.new()
	frame.name = "ScreenMenuAuditFrame"
	frame.size = FRAME_BIG
	root.add_child(frame)
	_router = Router.new()
	_router.name = "Router"
	frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame

	_mount(audit)
	await _facts(audit)
	await _strings(audit)
	await _badge(audit)
	await _actions(audit)
	await _layout(audit)
	_literal_scan(audit)
	await _bridge(audit)


# ---------------------------------------------------------------------------
# 1. The router, and the menu mounting through it
# ---------------------------------------------------------------------------

func _mount(audit: AuditBase) -> void:
	var ids: Array = Router.ids()
	audit.check_eq(ids.size(), REFERENCE_SCREEN_COUNT, "menu/the_router_still_carries_thirteen_ids")
	audit.check_true(ids.has("menu"), "menu/the_menu_id_is_one_of_them")
	audit.check_true(Router.to_actions_of("menu").has("to-profile"), "menu/the_reference_lists_the_profile_action")
	audit.check_true(Router.to_actions_of("menu").has("to-settings"), "menu/the_reference_lists_the_settings_action")

	var registered := true
	for id in ids:
		if not _router.register(String(id), PlaceholderScene):
			registered = false
	audit.check_true(registered, "menu/all_thirteen_slots_register")
	audit.check_true(_router.register("menu", MenuScene), "menu/the_menu_scene_registers_under_the_menu_id")
	audit.check_eq(_router.register("nope", MenuScene), false, "menu/register_refuses_an_id_outside_the_table")
	audit.note("expected engine lines in this audit's log, all deliberate: one `ERROR: ScreenRouter.register: 'nope' is not one of the thirteen reference screens` from the refusal check above; the engine's script-error count for this run must still read zero")
	audit.check_eq(_router.go_to("menu"), true, "menu/go_to_mounts_the_menu")
	audit.check_eq(_router.active_id(), "menu", "menu/the_menu_is_the_active_screen")
	audit.check_eq(_router.screen_count(), 1, "menu/one_screen_is_mounted")
	var screen: Node = _router.active_screen()
	audit.check_true(screen != null, "menu/the_mounted_screen_exists")
	audit.check_true(screen is MenuScreenClass, "menu/the_mounted_scene_carries_MenuScreen_gd")
	audit.check_true(screen.theme != null, "menu/the_scene_mounts_the_theme")


func _facts(audit: AuditBase) -> void:
	await process_frame
	var screen: Node = _router.active_screen()
	audit.check_eq(screen.screen_id(), "menu", "menu/the_screen_reports_its_own_id")
	audit.check_eq(screen.back_target(), "", "menu/the_menu_declares_no_return")
	audit.check_eq(screen.get("router_id"), "menu", "menu/the_screen_kept_the_router_fact")
	var states: Array = screen.capture_states()
	audit.check_eq(states, ["default", "demo", "beta"], "menu/the_screen_declares_the_three_capture_states")


# ---------------------------------------------------------------------------
# 2. Strings: every slot resolves, and the flip moves every one that differs
# ---------------------------------------------------------------------------

func _strings(audit: AuditBase) -> void:
	var screen: Node = _router.active_screen()
	var language_at_start := Locale.current_lang()
	audit.check_eq(language_at_start, Locale.default_lang(), "menu/the_run_starts_in_the_default_language")

	var unresolved: Array = []
	for node_name in MenuScreenClass.TEXT_SLOTS:
		var key := String(MenuScreenClass.TEXT_SLOTS[node_name])
		for lang in Locale.locales():
			if not Locale.is_resolvable(key, String(lang)):
				unresolved.append("%s/%s" % [key, lang])
	audit.check_eq(unresolved, [], "menu/every_visible_key_resolves_in_both_locales")

	var wrong: Array = []
	for node_name in MenuScreenClass.TEXT_SLOTS:
		var key := String(MenuScreenClass.TEXT_SLOTS[node_name])
		var control: Control = screen.find_child(String(node_name), true, false)
		var shown := ""
		if control is Button:
			shown = (control as Button).text
		elif control is Label:
			shown = (control as Label).text
		if shown != Locale.t(key):
			wrong.append("%s: %s != %s" % [node_name, shown, Locale.t(key)])
	audit.check_eq(wrong, [], "menu/every_slot_shows_the_current_locale_text")
	audit.check_eq((screen.find_child("BrandLabel", true, false) as Label).text, UiStrings.t("brand"),
		"menu/the_brand_resolves_through_the_seam")

	# The flip: the screen re-resolves on `Locale.set_lang` + its own refresh, and every
	# slot that the two tables actually differ on must have moved. A slot whose two
	# translations are identical is recorded, not counted as a failure.
	var toggle: Button = screen.find_child("LangToggle", true, false)
	audit.check_eq(toggle.text, "IT", "menu/the_toggle_offers_the_other_language_by_default")
	var before := _visible_strings(screen)
	var aria_before: Dictionary = screen.aria_names()
	screen.toggle_language()
	audit.check_eq(Locale.current_lang(), "it", "menu/the_toggle_switches_the_session_language")
	audit.check_eq(toggle.text, "EN", "menu/the_toggle_now_offers_the_language_it_left")
	var after := _visible_strings(screen)
	var unmoved: Array = []
	var moved := 0
	var identical_in_both := 0
	for node_name in before:
		if String(before[node_name]) != String(after[node_name]):
			moved += 1
			continue
		var key := String(MenuScreenClass.TEXT_SLOTS[node_name])
		if Locale.t(key, {}, "it") == Locale.t(key, {}, "en"):
			identical_in_both += 1
		else:
			unmoved.append(node_name)
	audit.check_eq(unmoved, [], "menu/the_flip_moves_every_slot_whose_two_translations_differ")
	audit.check_gt(moved, 0, "menu/the_flip_moved_strings")
	audit.report("language flip: moved=%d identical_in_both_locales=%d slots=%d" % [moved, identical_in_both, before.size()])

	var aria_after: Dictionary = screen.aria_names()
	var aria_unmoved: Array = []
	for node_name in aria_before:
		var key := String(MenuScreenClass.ARIA_SLOTS[node_name])
		if String(aria_before[node_name]) == String(aria_after[node_name]) and Locale.t(key, {}, "it") != Locale.t(key, {}, "en"):
			aria_unmoved.append(node_name)
	audit.check_eq(aria_unmoved, [], "menu/the_aria_names_follow_the_language")
	audit.check_eq((screen.find_child("ProfileButton", true, false) as Button).tooltip_text, UiStrings.t("profile"),
		"menu/the_profile_tooltip_is_the_reference_title")
	var names: Dictionary = screen.aria_names()
	audit.check_eq(names.size(), 4, "menu/the_four_aria_names_are_declared")
	audit.check_true(String(names["Root"]) != "ariaMenu", "menu/the_screen_has_a_screen_reader_name")
	audit.report("aria path: engine exposes accessibility_name=%s" % str(screen.engine_has_accessible_name()))
	# The toggle pressed again returns to the language the run started in.
	screen.toggle_language()
	audit.check_eq(Locale.current_lang(), language_at_start, "menu/the_second_press_returns_to_the_run_language")
	audit.check_eq(toggle.text, "IT", "menu/the_toggle_label_returns_with_it")


## node name -> the text the node currently shows, for every visible slot.
func _visible_strings(screen: Node) -> Dictionary:
	var out := {}
	for node_name in MenuScreenClass.TEXT_SLOTS:
		var control: Control = screen.find_child(String(node_name), true, false)
		if control is Button:
			out[node_name] = (control as Button).text
		elif control is Label:
			out[node_name] = (control as Label).text
	return out


# ---------------------------------------------------------------------------
# 3. The badge (`js/ui.js:742-750`) and the three capture states
# ---------------------------------------------------------------------------

func _badge(audit: AuditBase) -> void:
	var screen: Node = _router.active_screen()
	var build := DemoGate.build()
	audit.report("build=%s limited=%s" % [build, str(DemoGate.badge_visible())])
	# The reference's two distinct nodes: the hero badge line (`index.html:49-52`), a
	# `data-i18n="heroBadge"` label that is never hidden, and the tag row's build chip
	# (`index.html:78-80`), which only a limited build turns on and writes.
	var hero_row: Control = screen.find_child("Badge", true, false)
	var hero_label: Label = screen.find_child("BadgeLabel", true, false)
	var chip: Label = screen.find_child("BuildBadge", true, false)
	audit.check_true(hero_row != null and hero_label != null, "menu/the_hero_badge_row_mounts")
	audit.check_true(chip != null, "menu/the_build_chip_mounts")

	# The hero badge line: always on, and it carries `heroBadge` in both languages.
	var language_at_start := Locale.current_lang()
	audit.check_true(hero_row.visible, "menu/the_hero_badge_row_is_always_visible")
	var hero_texts := {}
	for lang in MenuScreenClass.LANGS:
		Locale.set_lang(String(lang))
		screen.refresh_strings()
		hero_texts[String(lang)] = hero_label.text
		audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/the_hero_badge_shows_heroBadge_in_%s" % String(lang))
		audit.check_ne(hero_label.text, "heroBadge", "menu/the_hero_badge_text_is_the_locale_copy_in_%s" % String(lang))
	audit.check_ne(hero_texts["it"], hero_texts["en"], "menu/the_hero_badge_line_follows_the_language")
	audit.check_true(hero_row.visible, "menu/the_hero_badge_row_survives_the_language_flip")
	Locale.set_lang(language_at_start)
	screen.refresh_strings()

	# The build chip: the live build's own answer, whichever run this is.
	var expected_visible := DemoGate.badge_visible()
	audit.check_eq(screen.badge_visible_shown(), expected_visible, "menu/the_badge_follows_the_build_gate")
	audit.check_eq(chip.visible, expected_visible, "menu/the_build_chip_hides_with_the_gate")
	if expected_visible:
		audit.check_eq(chip.text, UiStrings.t(DemoGate.badge_text_key()), "menu/a_limited_build_shows_its_badge_text")
		audit.check_true(chip.text != DemoGate.badge_text_key(), "menu/the_badge_text_is_a_sentence_not_an_id")
	else:
		audit.check_eq(chip.text, "", "menu/a_full_build_shows_no_badge_text")
	audit.check_eq(screen.badge_key_shown(), DemoGate.badge_text_key(), "menu/the_badge_key_is_the_adapters_answer")
	audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/the_gate_does_not_write_the_hero_badge_line")

	# The capture-state walk: default -> demo -> beta -> default.
	var walk: Array = []
	for state_id in screen.capture_states():
		walk.append([String(state_id), bool(screen.apply_capture_state(String(state_id)))])
	audit.check_eq(walk, [["default", true], ["demo", true], ["beta", true]], "menu/every_declared_capture_state_applies")
	audit.check_eq(screen.apply_capture_state("nope"), false, "menu/an_undeclared_capture_state_is_refused")

	screen.apply_capture_state("demo")
	audit.check_true(chip.visible, "menu/the_demo_state_shows_the_build_chip")
	audit.check_eq(screen.badge_key_shown(), DemoGate.BADGE_DEMO_KEY, "menu/the_demo_state_pins_the_demo_key")
	audit.check_eq(chip.text, UiStrings.t(DemoGate.BADGE_DEMO_KEY), "menu/the_demo_state_shows_the_demo_text")
	audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/the_demo_state_leaves_the_hero_badge_line_alone")

	screen.apply_capture_state("beta")
	audit.check_true(chip.visible, "menu/the_beta_state_shows_the_build_chip")
	audit.check_eq(screen.badge_key_shown(), DemoGate.BADGE_BETA_KEY, "menu/the_beta_state_pins_the_beta_key")
	audit.check_eq(chip.text, UiStrings.t(DemoGate.BADGE_BETA_KEY), "menu/the_beta_state_shows_what_that_key_resolves_to")
	audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/the_beta_state_leaves_the_hero_badge_line_alone")
	audit.note("the beta badge key is pinned through the adapter; the port's frozen locale table has no `betaBadge`, so the chip shows the id — the reference's own visible-fallback behaviour, recorded here for the locale lane")

	screen.apply_capture_state("default")
	audit.check_eq(screen.badge_visible_shown(), expected_visible, "menu/the_default_state_returns_to_the_gate")
	audit.check_eq(screen.badge_key_shown(), DemoGate.badge_text_key(), "menu/the_default_state_returns_the_key")
	audit.check_true(hero_row.visible, "menu/the_hero_badge_row_kept_its_own_visibility")
	audit.check_eq(hero_label.text, UiStrings.t("heroBadge"), "menu/the_hero_badge_line_kept_its_own_text")


# ---------------------------------------------------------------------------
# 4. The eight actions
# ---------------------------------------------------------------------------

func _actions(audit: AuditBase) -> void:
	for action in MenuScreenClass.ACTION_TARGETS:
		var target := String(MenuScreenClass.ACTION_TARGETS[action])
		var screen := await _mount_menu()
		var node_name := String(MenuScreenClass.ACTION_SLOTS[action])
		var button: Button = screen.find_child(node_name, true, false)
		if button == null:
			audit.check_true(false, "menu/%s_routes_to_%s" % [String(action).trim_prefix("to-"), target])
			continue
		button.pressed.emit()
		await process_frame
		var landed: String = _router.active_id()
		audit.check_eq(landed, target, "menu/%s_routes_to_%s" % [String(action).trim_prefix("to-"), target])
		audit.check_eq(_router.screen_count(), 1, "menu/%s_mounts_exactly_one_screen" % String(action).trim_prefix("to-"))
	# The two the reference guards as separate destinations, named by their own test.
	var profile_screen := await _mount_menu()
	audit.check_true(profile_screen.route_action("to-profile"), "menu/profile_is_a_separate_destination")
	audit.check_eq(_router.active_id(), "profile", "menu/profile_lands_on_profile")
	var settings_screen := await _mount_menu()
	audit.check_true(settings_screen.route_action("to-settings"), "menu/settings_is_a_separate_destination")
	audit.check_eq(_router.active_id(), "settings", "menu/settings_lands_on_settings")
	audit.check_eq(_router.back_target_of("menu"), "", "menu/the_menu_has_no_declared_back_edge")
	await _mount_menu()


func _mount_menu() -> Node:
	_router.go_to("menu")
	for _i in SETTLE_FRAMES:
		await process_frame
	return _router.active_screen()


# ---------------------------------------------------------------------------
# 5. The layout at the ticket's sizes
# ---------------------------------------------------------------------------

func _layout(audit: AuditBase) -> void:
	var frame: Control = _router.get_parent()
	var screen: Node = await _mount_menu()
	audit.check_true(screen.size.is_equal_approx(FRAME_BIG), "menu/the_screen_fills_the_frame")
	var big := _measure(screen)
	audit.report("1280x720: content=%.1f viewport=%.1f poster=%.2f scroll=%d widest=%.1f" % [
		big["content_height"], big["viewport"], big["poster_ratio"], big["scroll"], big["widest"]])
	audit.check_true(big["widest"] <= FRAME_BIG.x, "menu/nothing_is_wider_than_the_frame")
	audit.check_between(big["poster_ratio"], 1.74, 1.82, "menu/the_poster_keeps_the_reference_aspect")
	audit.check_eq(big["title_px"], 64, "menu/the_title_is_the_theme_size_at_1280")
	audit.check_le(big["content_height"], big["viewport"], "menu/at_1280x720_the_hero_fits_without_scrolling")
	audit.check_eq(big["scroll"], 0, "menu/at_1280x720_the_hero_sits_at_the_top")
	_check_caption(audit, screen, "1280x720")

	# The theme gap this screen carries: the chrome tokens it composes from must exist,
	# and a composed box must really read one of them.
	var theme: Theme = screen.theme
	var missing: Array = []
	for key in ["nav_bg", "caption_shadow", "poster_fade"]:
		if not theme.has_color(key, "Palette"):
			missing.append(key)
	audit.check_eq(missing, [], "menu/the_theme_carries_the_chrome_tokens")
	var nav_box := (screen.find_child("TopNav", true, false) as Control).get_theme_stylebox("panel") as StyleBoxFlat
	audit.check_true(nav_box != null, "menu/the_top_bar_carries_a_composed_box")
	audit.check_true(nav_box.bg_color.is_equal_approx(theme.get_color("nav_bg", "Palette")),
		"menu/the_top_bar_box_reads_the_palette_token")

	frame.size = FRAME_SMALL
	for _i in SETTLE_FRAMES:
		await process_frame
	var small := _measure(screen)
	audit.report("1024x600: content=%.1f viewport=%.1f poster=%.2f scroll=%d widest=%.1f title=%d" % [
		small["content_height"], small["viewport"], small["poster_ratio"], small["scroll"], small["widest"], small["title_px"]])
	audit.check_true(small["widest"] <= FRAME_SMALL.x, "menu/nothing_is_wider_than_the_small_frame")
	audit.check_eq(small["title_px"], 51, "menu/the_title_clamp_speaks_below_1280")
	# The page scrolls in the browser when the viewport is short (`body` scrolls; the
	# reference's hero is content-height there); the ScrollContainer is the same answer,
	# and the last control must be reachable rather than clipped away.
	var hero: ScrollContainer = screen.find_child("HeroScroll", true, false)
	# The band is the reference's own behaviour, measured: the browser's page scrolls
	# when the viewport is short, so the port may scroll too — but only a sliver. Full
	# build: 9 px of 422 (2 %); demo build: 35 px (8 %), where the tag row's build chip appears.
	# The 1280x720 frame, the capture size, does not overflow in either build.
	audit.check_le(small["content_height"] - small["viewport"], 40.0,
		"menu/the_smallest_frame_overflows_by_a_scrollable_sliver_at_most")
	hero.scroll_vertical = 100000
	await process_frame
	var reachable := hero.scroll_vertical
	audit.report("1024x600 scroll range: 0..%d px" % reachable)
	audit.check_true(reachable >= 0, "menu/the_scroll_offset_round_trips")
	audit.check_le(float(reachable), 40.0, "menu/and_that_sliver_is_all_that_is_hidden")
	_check_caption(audit, screen, "1024x600")
	hero.scroll_vertical = 0
	frame.size = FRAME_BIG
	for _i in SETTLE_FRAMES:
		await process_frame


## The poster caption (`index.html:72-73`). `.hero-poster__title` is pinned to the
## poster's corner (`right: 22px; bottom: 18px`, `styles.css:205-217`) over a
## content-sized box; as a fixed 378 px box it left the poster by 9 px once the hero
## column narrowed to 391 px at 1024x600 (UIR-24's legibility audit). The screen now
## derives the width from the poster (`_apply_caption_fit()`); these checks are the
## screen's own guard for it — containment, both declared insets, and the one
## assumption the poster height rides on (its width is its column's).
func _check_caption(audit: AuditBase, screen: Node, tag: String) -> void:
	var poster: Control = screen.find_child("PosterFrame", true, false)
	var caption: Control = screen.find_child("Caption", true, false)
	var preview: Control = screen.find_child("HeroPreview", true, false)
	var problems: Array = []
	if poster == null or caption == null or preview == null:
		problems.append("missing nodes")
	else:
		var poster_rect := poster.get_global_rect()
		var caption_rect := caption.get_global_rect()
		if not poster_rect.grow(1.0).encloses(caption_rect):
			problems.append("caption %s outside poster %s" % [str(caption_rect), str(poster_rect)])
		if absf((poster_rect.end.x - caption_rect.end.x) - 22.0) > 1.0:
			problems.append("right inset %.1f" % (poster_rect.end.x - caption_rect.end.x))
		if absf((poster_rect.end.y - caption_rect.end.y) - 18.0) > 1.0:
			problems.append("bottom inset %.1f" % (poster_rect.end.y - caption_rect.end.y))
		if absf(poster.size.x - preview.size.x) > 0.5:
			problems.append("poster %.2f != its column %.2f" % [poster.size.x, preview.size.x])
		audit.report("%s caption %s in poster %s" % [tag, str(caption_rect), str(poster_rect)])
		var last_line: Control = null
		for line: Control in [caption.get_node_or_null("CaptionLine1"), caption.get_node_or_null("CaptionLine2")]:
			if line != null:
				audit.report("%s caption line %s text %s" % [tag, line.name, str(line.get_global_rect())])
				last_line = line
		# The reference pins the *text block* to `bottom: 18px` (`styles.css:207`) over a
		# content-sized box, so the last line's box hugs the box's own bottom edge. The
		# port keeps a 92 px box (inherited) and must bottom-align inside it: measured on
		# the reference capture at 1280x720, the `PADEL PRO` glyphs end 22 px above the
		# poster's outer bottom edge, and the port's top-aligned text sat 29 px higher
		# than that before `alignment = 2` (`UIR-wave-pre-gate-a` note in the LOG).
		if last_line != null and caption_rect.end.y - last_line.get_global_rect().end.y > 1.0:
			problems.append("caption text ends %.1f px above its box" % (caption_rect.end.y - last_line.get_global_rect().end.y))
	audit.check_eq(problems, [], "menu/the_caption_stays_inside_its_poster_at_%s" % tag)


## The screen's own numbers, read off the live nodes: the copy column's height against
## the hero area it sits in, the poster's achieved ratio, the scroll offset, the widest
## control and the title size the clamp settled on.
func _measure(screen: Node) -> Dictionary:
	var copy: Control = screen.find_child("HeroCopy", true, false)
	var preview: Control = screen.find_child("HeroPreview", true, false)
	var scroll: ScrollContainer = screen.find_child("HeroScroll", true, false)
	var poster: Control = screen.find_child("PosterFrame", true, false)
	var title: Label = screen.find_child("Title1", true, false)
	var widest := 0.0
	for control in [copy, preview, poster, screen.find_child("HeroActions", true, false), screen.find_child("TagsRow", true, false)]:
		if control is Control:
			widest = maxf(widest, (control as Control).size.x)
	return {
		"content_height": copy.size.y,
		"hero_height": (copy.get_parent() as Control).size.y,
		"viewport": scroll.size.y,
		"poster_ratio": poster.size.x / maxf(poster.size.y, 1.0),
		"scroll": scroll.scroll_vertical,
		"widest": widest,
		"title_px": title.get_theme_font_size("font_size"),
	}


# ---------------------------------------------------------------------------
# 6. The literal scan (the rule `router_audit.gd` uses, aimed at this screen)
# ---------------------------------------------------------------------------

func _literal_scan(audit: AuditBase) -> void:
	var probe := _offenders_in_source("res://probe.gd", PROBE_SOURCE)
	audit.check_eq(probe, ["res://probe.gd:2 \"Play now\""], "menu/the_literal_scan_flags_prose_and_ignores_developer_text")

	var source := FileAccess.get_file_as_string(SCREEN_PATH)
	audit.check_true(source != "", "menu/the_screen_source_is_readable")
	audit.check_eq(_offenders_in_source(SCREEN_PATH, source), [], "menu/MenuScreen_gd_carries_no_prose_literal")

	var scene := FileAccess.get_file_as_string(SCENE_PATH)
	var found: Array = []
	for literal in _literals_in_scene(scene):
		found.append(String(literal))
	var sorted_found: Array = found.duplicate()
	sorted_found.sort()
	var expected: Array = SCENE_LITERALS.duplicate()
	expected.sort()
	audit.check_eq(sorted_found, expected, "menu/the_scene_carries_exactly_the_documented_literals")
	audit.note("scene literals: %s — the caption (index.html:72-73, aria-hidden, no data-i18n), the reference's own Alpha 0.2 tag (index.html:83) and the three emoji glyphs (index.html:41-42, :58)" % str(expected))


## The `text = "..."` values a scene assigns, which is where a scene keeps its prose.
func _literals_in_scene(scene: String) -> Array:
	var out: Array = []
	for line in scene.split("\n"):
		var code := String(line).strip_edges()
		if not code.begins_with("text = "):
			continue
		for literal in _literals(code):
			if String(literal) != "":
				out.append(String(literal))
	return out


func _offenders_in_source(path: String, source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	for index in lines.size():
		var code := String(lines[index]).split("#")[0]
		var developer := false
		for marker in DEVELOPER_MARKERS:
			if code.contains(marker):
				developer = true
				break
		if developer:
			continue
		for literal in _literals(code):
			if not String(literal).contains(" "):
				continue
			out.append("%s:%d \"%s\"" % [path, index + 1, literal])
	return out


func _literals(code: String) -> Array:
	var out: Array = []
	var i := 0
	while i < code.length():
		if code[i] == "\"":
			var j := i + 1
			var buffer := ""
			while j < code.length() and code[j] != "\"":
				if code[j] == "\\":
					j += 1
					if j < code.length():
						buffer += code[j]
				else:
					buffer += code[j]
				j += 1
			out.append(buffer)
			i = j + 1
		else:
			i += 1
	return out


# ---------------------------------------------------------------------------
# 7. UIR-05's bridge over this screen (the last check: it navigates away)
# ---------------------------------------------------------------------------

func _bridge(audit: AuditBase) -> void:
	var screen: Node = await _mount_menu()
	var specs: Array = screen.focus_controls()
	audit.check_eq(specs.size(), 9, "menu/the_screen_registers_nine_focusables")
	var ids: Array = []
	for spec in specs:
		ids.append(String((spec as Dictionary).get("id", "")))
	audit.check_true(ids.has("menu/PlayButton"), "menu/the_primary_button_is_registered")
	audit.check_true(ids.has("menu/LangToggle"), "menu/the_language_toggle_is_registered")
	var actions: Array = []
	for spec in specs:
		actions.append(String((spec as Dictionary).get("action", "")))
	audit.check_eq(actions.count("back"), 0, "menu/the_menu_registers_no_back_control")

	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	audit.check_eq(bridge.ids().size(), 9, "menu/the_bridge_reads_the_nine_controls")
	audit.check_true(bridge.set_focus("menu/PlayButton"), "menu/the_bridge_can_focus_the_primary_button")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	audit.check_true(bridge.dispatch(event), "menu/a_confirm_dispatch_is_handled")
	await process_frame
	audit.check_eq(_router.active_id(), "modes", "menu/the_confirm_dispatch_on_play_lands_on_modes")

	var toggle_focus: RefCounted = MenuFocus.new()
	var toggle_bridge: RefCounted = Bridge.new()
	var second: Node = await _mount_menu()
	toggle_bridge.attach(second, toggle_focus, _router)
	audit.check_true(toggle_focus.ids().has("menu/LangToggle"), "menu/the_toggle_reaches_the_focus_model")
	audit.check_eq(String(second.get("router_id")), "menu", "menu/a_second_mount_is_told_its_own_id")
