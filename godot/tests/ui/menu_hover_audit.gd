## menu_hover_audit.gd — the card hover/focus contract of the menu screens, checked
## against the 2D reference's own two rules.
##
## WHAT IT PROVES. The reference separates the POINTER's presentation from the PAD's and
## the port must too:
##
##   `.athlete-card:hover`  `styles.css:335-340`  `translateY(-3px)` + border
##                                                `rgba(0,229,255,0.35)`, no ring
##   `.menu-focus`          `styles.css:733-738`  `outline: 3px solid var(--cyan)` at
##                                                `outline-offset: 3px`, pulsing to
##                                                `#a5ffe0` (`:742`)
##
##   1. every card of both screens carries the ring node, hidden at rest;
##   2. the ring's own geometry is the reference's: 3 px of border, 3 px of offset, the
##      card's 12 px radius, no fill — and it is drawn by `expand_margin`, which is
##      PROVEN not to enter the card's minimum size (no reflow: the card's rect is
##      byte-identical with the ring hidden and shown);
##   3. every colour it paints is a `Palette` read (`misses_of` empty) and the two it
##      names are the theme's own `cyan` and `focus_pulse` — the keyframe colour added
##      for `styles.css:742`;
##   4. the POINTER lights the reference's hover frame and NOT the ring, the PAD lights
##      the ring, and with both true the card wears both — the composition
##      `js/main.js:2579-2588` produces whenever a pad is connected;
##   5. the theme's existing focus ring for buttons (`Button/styles/focus` = `BoxFocus`,
##      2 px `#16bed7`) is untouched: the card ring is a second, card-sized presentation,
##      not a replacement of it.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot --headless \
##     --script res://tests/ui/menu_hover_audit.gd ; echo "exit=$?"
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Router := preload("res://src/ui/ScreenRouter.gd")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const CharactersScene := preload("res://src/ui/screens/CharactersScreen.tscn")
const ArenaScene := preload("res://src/ui/screens/ArenaScreen.tscn")
const CardFocusRing := preload("res://src/ui/components/CardFocusRing.gd")
const Bridge := preload("res://src/ui/focus/UiFocusBridge.gd")
const MenuFocus := preload("res://game/menu_focus.gd")
const ThemeRes := preload("res://src/ui/theme/padel_theme.tres")

const FRAME := Vector2(1280, 720)
const SETTLE_FRAMES := 3

## The reference's own numbers, each with its line.
const RING_WIDTH := 3        # `styles.css:734` outline-width
const RING_OFFSET := 3.0     # `styles.css:735` outline-offset
const RING_RADIUS := 12      # `styles.css:736` border-radius: inherit (the card's)
const HOVER_ALPHA := 0.35    # `styles.css:339` border-color rgba(0,229,255,0.35)
## The focus ring the port already had for BUTTONS before this lane
## (`padel_theme.tres` `BoxFocus`, commit "paint the focus ring in the game's own cyan").
const BUTTON_RING_WIDTH := 2
const BUTTON_RING_COLOR := Color(0.08627451, 0.74509804, 0.84313725, 1.0)

var _frame: Control
var _router: Control


func _initialize() -> void:
	var audit := AuditBase.new("menu_hover")
	await _run(audit)
	quit(audit.finish())


func _run(audit: AuditBase) -> void:
	_frame = Control.new()
	_frame.name = "MenuHoverAuditFrame"
	_frame.size = FRAME
	root.add_child(_frame)
	_router = Router.new()
	_router.name = "Router"
	_frame.add_child(_router)
	for _i in SETTLE_FRAMES:
		await process_frame
	for id in Router.ids():
		_router.register(String(id), PlaceholderScene)
	_router.register("characters", CharactersScene)
	_router.register("arena", ArenaScene)
	await _characters(audit)
	await _arena(audit)
	_theme_untouched(audit)


# ---------------------------------------------------------------------------
# The characters screen — the team panel and the picker
# ---------------------------------------------------------------------------

func _characters(audit: AuditBase) -> void:
	var screen: Node = await _mount("characters")
	audit.check_true(screen != null, "hover/characters_mounts")
	if screen == null:
		return
	# The picker holds the cards the pad can actually land on: a team slot that carries
	# its own commands is a container, not a target (`game/menu_focus.gd`,
	# `js/main.js:571-577`).
	screen.apply_capture_state("picker-open")
	for _i in SETTLE_FRAMES:
		await process_frame
	var cards := _cards_of(screen)
	audit.check_gt(cards.size(), 0, "hover/characters_the_picker_builds_cards")

	var missing: Array = []
	for card in cards:
		if CardFocusRing.ring_of(card) == null:
			missing.append(String(card.name))
	audit.check_eq(missing, [], "hover/every_character_card_carries_the_focus_ring")

	var lit_at_rest: Array = []
	for card in cards:
		if CardFocusRing.is_focused(card):
			lit_at_rest.append(String(card.name))
	audit.check_eq(lit_at_rest, [], "hover/no_character_card_wears_the_ring_at_rest")

	var sample: Control = cards[0]
	audit.check_eq(CardFocusRing.misses_of(sample), [],
		"hover/the_ring_names_no_palette_key_the_theme_lacks")

	# 2. the ring's geometry is the reference's, and it is drawn outside the card's rect.
	var ring := CardFocusRing.ring_of(sample)
	var box := CardFocusRing.ring_style_of(sample)
	audit.check_true(box != null, "hover/the_ring_has_a_stylebox")
	if box != null:
		audit.check_eq(box.border_width_left, RING_WIDTH, "hover/the_ring_is_three_px_wide_left")
		audit.check_eq(box.border_width_top, RING_WIDTH, "hover/the_ring_is_three_px_wide_top")
		audit.check_eq(box.border_width_right, RING_WIDTH, "hover/the_ring_is_three_px_wide_right")
		audit.check_eq(box.border_width_bottom, RING_WIDTH, "hover/the_ring_is_three_px_wide_bottom")
		audit.check_eq(box.expand_margin_left, RING_OFFSET + RING_WIDTH,
			"hover/the_ring_box_is_grown_by_offset_plus_width")
		# The reference's `outline-offset` is the GAP, and `expand_margin` grows the box
		# the border is then drawn inside: the gap is the difference, and a bare offset
		# would have put the ring flush against the card (the first capture's own bug).
		audit.check_eq(CardFocusRing.offset_of(box), RING_OFFSET,
			"hover/the_gap_between_the_card_and_the_ring_is_the_reference_offset")
		audit.check_eq(box.corner_radius_top_left, RING_RADIUS, "hover/the_ring_keeps_the_card_radius")
		audit.check_true(not box.draw_center, "hover/the_ring_paints_no_fill")
		audit.check_eq(box.border_color, ThemeRes.get_color("cyan", "Palette"),
			"hover/the_ring_is_the_palette_cyan")
		# The offset is drawn, not laid out: a stylebox's own minimum size is its content
		# margins, so an expand margin cannot reflow the grid.
		audit.check_eq(box.get_minimum_size(), Vector2.ZERO,
			"hover/the_ring_contributes_no_minimum_size")
	audit.check_eq(ThemeRes.get_color("focus_pulse", "Palette"),
		Color(0.64705882, 1, 0.87843137, 1),
		"hover/the_pulse_keyframe_is_the_reference_a5ffe0")

	# 4a. the POINTER: the reference's hover frame, and no ring. The card must be one the
	# screen has NOT already chosen: `.athlete-card--selected` (`styles.css:342-345`)
	# outranks the hover border in the reference's own cascade only for `border-color`,
	# and the picker's first card IS the equipped athlete.
	var hovered: Control = _unselected_card(cards)
	audit.check_true(hovered != null, "hover/the_picker_offers_a_card_that_is_not_the_chosen_one")
	if hovered == null:
		return
	var rest_size := hovered.size
	var rest_pos := hovered.position
	hovered.mouse_entered.emit()
	for _i in SETTLE_FRAMES:
		await process_frame
	var hover_box := hovered.get_theme_stylebox("panel") as StyleBoxFlat
	audit.check_true(hover_box != null, "hover/the_hovered_card_has_a_frame")
	if hover_box != null:
		var expected := Color(ThemeRes.get_color("cyan", "Palette"), HOVER_ALPHA)
		audit.check_true(hover_box.border_color.is_equal_approx(expected),
			"hover/the_pointer_lights_the_reference_rgba_0_229_255_0_35_border")
		audit.check_true(hover_box.shadow_size == 0,
			"hover/the_pointer_does_not_add_the_selected_halo")
	audit.check_true(not CardFocusRing.is_focused(hovered),
		"hover/the_pointer_alone_never_lights_the_pad_ring")
	audit.check_true(hovered.position.y < rest_pos.y,
		"hover/the_pointer_lifts_the_card_by_the_reference_transform")
	audit.check_eq(hovered.size, rest_size, "hover/the_hover_does_not_resize_the_card")

	# 5 (part): the ring is drawn outside the card, so it must not change the card's rect.
	CardFocusRing.set_focused(hovered, true)
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_eq(hovered.size, rest_size, "hover/the_ring_does_not_resize_the_card")
	audit.check_true(CardFocusRing.is_focused(hovered),
		"hover/both_holders_compose_on_the_same_card")
	CardFocusRing.set_focused(hovered, false)
	hovered.mouse_exited.emit()
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_true(not CardFocusRing.is_focused(hovered),
		"hover/the_ring_clears_with_the_pad")

	# 4b. the PAD, through the real bridge: the focus lands on a card and that card — and
	# only that card — wears the ring. `UiFocusBridge.set_focus` moves the MODEL; the
	# mount is what paints it (`MenuFocus.apply_focus`, `game/main_menu.gd:1147`), so the
	# audit paints it the same way rather than reaching into the screen.
	var target_name := _first_focusable_card_name(screen)
	audit.check_ne(target_name, "", "hover/the_picker_offers_a_focusable_card")
	if target_name != "":
		var focus: RefCounted = MenuFocus.new()
		var bridge: RefCounted = Bridge.new()
		bridge.attach(screen, focus, _router)
		var focus_id := "characters/%s" % target_name
		audit.check_true(bridge.set_focus(focus_id), "hover/the_bridge_can_focus_a_card")
		focus.apply_focus()
		for _i in SETTLE_FRAMES:
			await process_frame
		var target: Control = screen.find_child(target_name, true, false)
		audit.check_true(target != null, "hover/the_focused_card_exists")
		if target != null:
			audit.check_true(CardFocusRing.is_focused(target),
				"hover/the_pad_lights_the_ring_on_the_card_it_holds")
			# The ring is the pad's; no other card may wear it.
			var others: Array = []
			for card in _cards_of(screen):
				if card != target and CardFocusRing.is_focused(card):
					others.append(String(card.name))
			audit.check_eq(others, [], "hover/the_pad_lights_exactly_one_card")
			# And the pad's frame is still the reference's hover frame, not a second,
			# stronger border: the ring is what distinguishes it. Asserted on a card the
			# screen has not already chosen, so the selected frame cannot answer instead.
			var unselected: Control = _unselected_card(_cards_of(screen))
			if unselected != null:
				unselected.focus_mode = Control.FOCUS_ALL
				unselected.grab_focus()
				for _i in SETTLE_FRAMES:
					await process_frame
				var pad_box := unselected.get_theme_stylebox("panel") as StyleBoxFlat
				if pad_box != null:
					audit.check_true(pad_box.border_color.a < 1.0,
						"hover/the_pads_frame_is_the_soft_border_and_the_ring_is_the_difference")
					audit.check_true(CardFocusRing.is_focused(unselected),
						"hover/the_same_split_holds_on_a_card_the_screen_has_not_chosen")
		# Leaving the screen with the focus still held must not leave a ring behind.
		bridge.set_focus("characters/BackButton")
		focus.apply_focus()
		for _i in SETTLE_FRAMES:
			await process_frame
		var still_lit: Array = []
		for card in _cards_of(screen):
			if CardFocusRing.is_focused(card):
				still_lit.append(String(card.name))
		audit.check_eq(still_lit, [], "hover/the_ring_clears_when_the_pad_moves_away")


# ---------------------------------------------------------------------------
# The arena screen
# ---------------------------------------------------------------------------

func _arena(audit: AuditBase) -> void:
	var screen: Node = await _mount("arena")
	audit.check_true(screen != null, "hover/arena_mounts")
	if screen == null:
		return
	var ids: Array = []
	for row in screen.arena_rows_now():
		ids.append(String((row as Dictionary).get("id", "")))
	for row in screen.world_arena_rows_now():
		ids.append(String((row as Dictionary).get("id", "")))
	audit.check_gt(ids.size(), 0, "hover/the_arena_screen_builds_cards")
	var cards: Array = []
	for id in ids:
		for prefix in ["ArenaCard_", "WorldArenaCard_"]:
			var card: Control = screen.find_child(prefix + String(id), true, false)
			if card != null:
				cards.append(card)
	audit.check_gt(cards.size(), 0, "hover/the_arena_cards_exist")
	var missing: Array = []
	for card in cards:
		if CardFocusRing.ring_of(card) == null:
			missing.append(String(card.name))
	audit.check_eq(missing, [], "hover/every_arena_card_carries_the_focus_ring")
	audit.check_eq(CardFocusRing.misses_of(cards[0]), [],
		"hover/the_arena_ring_names_no_palette_key_the_theme_lacks")

	# The pointer lights the frame; the pad lights the ring. Same split as the characters
	# screen, on the other card family of the same rule (`styles.css:335-340`).
	var card: Control = cards[0]
	var rest_size := card.size
	card.mouse_entered.emit()
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_true(not CardFocusRing.is_focused(card),
		"hover/the_arena_pointer_alone_never_lights_the_ring")
	audit.check_eq(card.size, rest_size, "hover/the_arena_hover_does_not_resize_the_card")
	var focus: RefCounted = MenuFocus.new()
	var bridge: RefCounted = Bridge.new()
	bridge.attach(screen, focus, _router)
	var card_id := String(card.name).trim_prefix("ArenaCard_").trim_prefix("WorldArenaCard_")
	audit.check_true(bridge.set_focus("arena/ArenaCard_%s" % card_id),
		"hover/the_bridge_can_focus_an_arena_card")
	focus.apply_focus()
	for _i in SETTLE_FRAMES:
		await process_frame
	audit.check_true(CardFocusRing.is_focused(card),
		"hover/the_arena_pad_lights_the_ring")
	audit.check_eq(card.size, rest_size, "hover/the_arena_ring_does_not_resize_the_card")


# ---------------------------------------------------------------------------
# The ring the port already had must be untouched
# ---------------------------------------------------------------------------

func _theme_untouched(audit: AuditBase) -> void:
	var button_ring := ThemeRes.get_stylebox("focus", "Button") as StyleBoxFlat
	audit.check_true(button_ring != null, "hover/the_button_focus_box_still_exists")
	if button_ring == null:
		return
	audit.check_eq(button_ring.border_width_left, BUTTON_RING_WIDTH,
		"hover/the_button_focus_ring_is_still_two_px")
	audit.check_true(button_ring.border_color.is_equal_approx(BUTTON_RING_COLOR),
		"hover/the_button_focus_ring_is_still_the_games_own_cyan")
	audit.check_eq(button_ring.expand_margin_left, 0.0,
		"hover/the_button_focus_ring_was_not_turned_into_a_card_ring")
	# A `Panel` has no focus stylebox in the theme: the card ring is composed by the
	# component, so the two presentations cannot collide.
	audit.check_true(not ThemeRes.has_stylebox("focus", "Panel"),
		"hover/the_theme_carries_no_competing_panel_focus_box")


# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

func _mount(screen_id: String) -> Node:
	_router.go_to(screen_id)
	for _i in SETTLE_FRAMES:
		await process_frame
	return _router.active_screen()


## Every card the screen registered, in build order — the same list `_register_focus`
## walks, so the audit and the focus model cannot disagree about what a card is.
func _cards_of(screen: Node) -> Array:
	var out: Array = []
	for spec in screen.focus_controls():
		var entry: Dictionary = spec
		var node: Control = entry.get("node", null)
		if node != null and node is PanelContainer and CardFocusRing.ring_of(node) != null:
			out.append(node)
	return out


## The first card the screen has NOT already chosen. `_card_box_for` gives a chosen card
## `PanelCardSelected` whatever else is true of it, so a hover assertion on the picker's
## first card (the equipped athlete) would read the chosen frame instead of the hover one.
func _unselected_card(cards: Array) -> Control:
	for card in cards:
		if not bool((card as Control).get_meta("card_selected", false)):
			return card
	return null


## The first card name the screen declares that is a card AND is not a container of its
## own commands (the reference refuses those as focus targets).
func _first_focusable_card_name(screen: Node) -> String:
	for spec in screen.focus_controls():
		var entry: Dictionary = spec
		var opts: Dictionary = entry.get("opts", {})
		if bool(opts.get("contains_buttons", false)):
			continue
		var node: Control = entry.get("node", null)
		if node == null or CardFocusRing.ring_of(node) == null:
			continue
		var id := String(entry.get("id", ""))
		return id.substr(id.find("/") + 1)
	return ""
