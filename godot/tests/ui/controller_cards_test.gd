## controller_cards_test.gd — the live Modes/Characters controller walk.
##
## THE QUESTION. The user reports that on the Modes cards and on the Characters four
## slot cards (with their Atleta/Outfit buttons) the controller cannot navigate. The
## component audits are green and the single-dispatch test passes, so the defect — if
## there is one — lives in the live scene integration, not in the model. This file
## mounts the game's own `res://game/Main.tscn`, walks it with the engine's real input
## events, and asserts what a player would see: the focus moves where it should, it is
## painted on a node the viewport actually owns, and a confirm/back reaches the same
## handlers a click does.
##
## WHAT IT IS NOT. Synthetic pad events are not a physical pad: this file proves the
## engine path, never a hand on hardware. `Input.parse_input_event` + the mount's own
## per-frame `poll_pad` is the same route a real device takes (`_playable_process`),
## and the raw-event assertions keep the single-dispatch rule honest.
##
## ISOLATED SAVE. `Config.save_dir` is redirected before the host boots, so the walk
## never reads or writes the player's own profile.
extends SceneTree

const Config := preload("res://game/match_config.gd")

var failures := 0
var _menu: Control = null


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func run() -> void:
	Config.save_dir = "user://controller-cards-test-%d" % Time.get_ticks_usec()
	print("PHYSICAL_DEVICES ", Input.get_connected_joypads())
	_menu = load("res://game/Main.tscn").instantiate()
	root.add_child(_menu)
	await _frames(6)
	check(_menu._playable, "default playable menu mounted")
	await _walk_menu()
	await _walk_modes()
	await _walk_characters()
	await _walk_arena()
	_menu.queue_free()
	await process_frame
	print("CONTROLLER_CARDS %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(1 if failures else 0)


func _focus() -> RefCounted:
	return _menu._focus


func _bridge() -> RefCounted:
	return _menu._bridge


func _screen() -> Node:
	return _menu._router.active_screen()


func _focus_id() -> String:
	return _focus().focus_id()


func _focusable() -> Array:
	return _focus().focusable_ids()


## The menu itself: the first focusable takes the focus without anybody placing it
## there, and the confirm reaches the screen's own route.
func _walk_menu() -> void:
	check(_menu._router.active_id() == "menu", "the game opens on the menu")
	check(_focus_id() == "menu/PlayButton", "the menu's first control takes the focus unprompted")
	check(_painted() == "PlayButton", "the menu paints the control the model names")
	# The reachability walk MOVES the model's focus while it asks its question; it must
	# put the player back where they were.
	_focus().reachable_ids()
	check(_focus_id() == "menu/PlayButton", "the reachability walk leaves the focus where it found it")
	check(_painted() == "PlayButton", "the reachability walk leaves the painted focus alone")
	# The raw event reaches the same focus model immediately. The following poll sees the
	# held state and must not activate a second time.
	var raw := InputEventJoypadButton.new()
	raw.device = 0
	raw.button_index = JOY_BUTTON_A
	raw.pressed = true
	_menu._input(raw)
	check(_menu._router.active_id() == "modes", "a raw pad confirm opens the modes screen")
	await _frames(3)
	check(_menu._router.active_id() == "modes", "the held confirm does not activate twice")
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_A
	release.pressed = false
	_menu._input(release)
	await _frames(4)


## The modes screen: the three cards are targets, the focus ring lands on the card
## itself, a direction walks the row, and a confirm runs the card's own selection.
func _walk_modes() -> void:
	var screen := _screen()
	check(screen != null and screen.screen_id() == "modes", "the modes screen is mounted")
	check(_focus_id() == "modes/BackButton", "modes opens on the declared back control")
	check(_painted() == "BackButton", "modes paints the back control")
	var cards: Array = []
	for row in screen.mode_rows_now():
		cards.append("modes/ModeCard_%s" % String((row as Dictionary).get("id", "")))
	for card in cards:
		check(_focusable().has(card), "modes registers %s as a target" % card)

	await _dir("down")
	check(_focus_id().begins_with("modes/ModeCard_"), "a pad down reaches the mode cards")
	check(_painted() == _focus_id().get_slice("/", 1), "modes paints the focused card, not the control it left")
	check(_card_uses_controller_highlight(screen, _focus_id()), "controller focus gives the mode card its cyan highlight")
	var first_card := _focus_id()
	await _dir("right")
	check(_focus_id() != first_card, "a pad right walks to the next mode card")
	check(_painted() == _focus_id().get_slice("/", 1), "modes paints the second card")
	check(_card_uses_controller_highlight(screen, _focus_id()), "the next mode card keeps the cyan controller highlight")
	await _dir("left")
	check(_focus_id() == first_card, "a pad left walks back to the first mode card")

	# The two segmented groups under the cards are their own targets: a pad press on a
	# format has to write the same preference a click writes (`length:<key>` is the
	# screen's own action, not a route the bridge owns), and the chosen segment has to
	# take the active style so the player sees what will be played.
	check(await _walk_to("modes/LengthButton_games3"), "the pad reaches the 3 games segment")
	check(_painted() == "LengthButton_games3", "modes paints the focused format segment")
	await _confirm()
	check(Config.match_length() == "games3", "a pad confirm on 3 games persists it as the quick-match format")
	var chosen := _focus().node_of("modes/LengthButton_games3") as Button
	check(chosen != null and String(chosen.theme_type_variation) == "SegmentedActive",
		"the chosen format segment takes the active style")
	var unchosen := _focus().node_of("modes/LengthButton_points11") as Button
	check(unchosen != null and String(unchosen.theme_type_variation) == "SegmentedInactive",
		"the format segment the pad left takes the inactive style")

	check(await _walk_to("modes/DiffButton_medium"), "the pad reaches the difficulty segment")
	await _confirm()
	check(String(Config.stored_prefs().get("aiDifficulty", "")) == "medium",
		"a pad confirm on a difficulty rung persists the rung")
	var medium := _focus().node_of("modes/DiffButton_medium") as Button
	check(medium != null and String(medium.theme_type_variation) == "SegmentedActive",
		"the chosen difficulty segment takes the active style")

	# The confirm is the card's own `select_mode`, not a route the bridge guessed: the
	# mode is written to the session and the screen moves to the character panel.
	check(await _walk_to(first_card), "the pad returns to the quick-match card after editing setup")
	await _confirm()
	check(_menu._router.active_id() == "characters", "a pad confirm on an unlocked mode card opens the characters screen")


func _card_uses_controller_highlight(screen: Node, focus_id: String) -> bool:
	var card: Control = _focus().node_of(focus_id) as Control
	if card == null:
		return false
	var actual := card.get_theme_stylebox("panel") as StyleBoxFlat
	var expected := screen._card_box(true) as StyleBoxFlat
	return actual != null and expected != null \
		and actual.border_color == expected.border_color \
		and actual.bg_color == expected.bg_color


## The characters screen: the four slots' Atleta/Outfit commands are the targets (the
## cards that hold them are containers), the picker and the wardrobe open and close
## with the pad, and the focus stays inside the visible frame.
func _walk_characters() -> void:
	await _frames(4)
	var screen := _screen()
	check(screen != null and screen.screen_id() == "characters", "the characters screen is mounted")
	check(_focus_id() == "characters/BackButton", "characters opens on the declared back control")
	check(_painted() == "BackButton", "characters paints the back control")

	var slots: Array = []
	for role in ["player", "playerMate", "opponent", "opponentMate"]:
		slots.append(role)
	for role in slots:
		var commands := _commands_of(screen, role)
		for command in commands:
			check(_focusable().has(command), "characters registers %s as a target" % command)
		if not commands.is_empty():
			check(not _focusable().has("characters/TeamSlot_%s" % role),
				"a slot card that holds its own commands is not a target (%s)" % role)

	await _dir("down")
	check(_focus_id().begins_with("characters/SlotAthleteAction_") or _focus_id().begins_with("characters/SlotOutfitAction_"),
		"a pad down reaches a slot command")
	check(_painted() == _focus_id().get_slice("/", 1), "characters paints the focused command")
	var reached := _focus_id()
	await _dir("right")
	check(_focus_id() != reached, "a pad right walks to the next slot command")
	check(_painted() == _focus_id().get_slice("/", 1), "characters paints the second command")

	# The Atleta command opens the picker, and the picker's own targets replace the
	# team's: the reference re-collects on every view change.
	check(await _walk_to("characters/SlotAthleteAction_player"), "the pad reaches the player slot's Atleta command")
	await _confirm()
	check(screen.view() == "picker", "a pad confirm on Atleta opens the picker")
	await _frames(4)
	check(_focus_id() == "characters/BackButton", "the picker opens on the back control")
	await _dir("down")
	check(_focus_id().begins_with("characters/PickCard_"), "a pad down reaches the picker cards")
	check(_painted() == _focus_id().get_slice("/", 1), "the picker paints the focused card")
	var target_pick := _focus_id()
	await _confirm()
	check(screen.view() == "team", "a pad confirm on a pick card chooses the athlete and returns to the team")
	check(screen.slot_athlete_id("player") == target_pick.trim_prefix("characters/PickCard_"),
		"the pad's pick is the athlete the slot now holds")

	# The wardrobe, opened by the player slot's Completo command and closed by the
	# screen's own return (`HeadAction`, the reference's `teamPickBack`).
	await _frames(4)
	# A slot only offers Completo when its athlete has more than one outfit
	# (`js/ui.js:936-939`), and the pick above may have changed who the player is, so the
	# command is found the way a player finds it: by what the screen registered.
	var outfit_command := _first_focusable("characters/SlotOutfitAction_")
	check(outfit_command != "", "a slot offers the Completo command")
	check(await _walk_to(outfit_command), "the pad reaches the slot's Completo command")
	await _confirm()
	check(screen.view() == "outfits", "a pad confirm on Completo opens the wardrobe")
	await _frames(4)
	await _dir("down")
	check(_focus_id().begins_with("characters/OutfitCard_"), "a pad down reaches the wardrobe cards")
	check(_painted() == _focus_id().get_slice("/", 1), "the wardrobe paints the focused card")
	# The focused card is the fifth of a tall grid: the frame is smaller than the page,
	# so the container had to scroll it into view.
	check(_focus_visible(screen), "the wardrobe keeps the focused card inside the visible frame")
	check(await _walk_to("characters/HeadAction"), "the pad reaches the screen's own return")
	await _confirm()
	check(screen.view() == "team", "the screen's own return closes the wardrobe")

	# Back on the team view the declared return still works: B leaves for the screen the
	# reference declares (`to-modes`), and the mount follows it through the router.
	await _frames(4)
	await _back()
	check(_menu._router.active_id() == "modes", "the declared back leaves the characters screen for modes")


## The arena grid uses cards as the command itself. The stick must be able to
## reach an offered card and make its cyan focus frame visible before A starts a
## match; unavailable cards are intentionally skipped by the same model.
func _walk_arena() -> void:
	_menu._router.go_to("arena")
	await _frames(4)
	var screen := _screen()
	check(screen != null and screen.screen_id() == "arena", "the arena screen is mounted")
	check(_focus_id() == "arena/BackButton", "arena opens on the declared back control")
	await _dir("down")
	check(_focus_id().begins_with("arena/ArenaCard_") or _focus_id().begins_with("arena/WorldArenaCard_"),
		"a pad down reaches an offered arena card")
	check(_painted() == _focus_id().get_slice("/", 1), "arena paints the focused card")
	check(_card_uses_arena_focus_highlight(screen, _focus_id()), "controller focus gives the arena card its cyan highlight")
	var focused_id := _focus_id().trim_prefix("arena/ArenaCard_").trim_prefix("arena/WorldArenaCard_")
	check(screen.arena_card_state(focused_id) == "selectable" or screen.arena_card_state(focused_id) == "in_program",
		"the controller does not land on an unavailable arena card")


func _card_uses_arena_focus_highlight(screen: Node, focus_id: String) -> bool:
	var card: Control = _focus().node_of(focus_id) as Control
	if card == null:
		return false
	var actual := card.get_theme_stylebox("panel") as StyleBoxFlat
	var expected := screen._selected_box() as StyleBoxFlat
	return actual != null and expected != null \
		and actual.border_color == expected.border_color \
		and actual.bg_color == expected.bg_color


## The Atleta/Completo commands a slot offers, in the reference's own order.
func _commands_of(screen: Node, role: String) -> Array:
	var out: Array = []
	for prefix in ["SlotAthleteAction_", "SlotOutfitAction_"]:
		if screen.find_child(prefix + role, true, false) != null:
			out.append("characters/%s%s" % [prefix, role])
	return out


## The first registered target whose id starts with `prefix`, or `""` when the screen
## registers none. Used where the roster decides which slots carry a command.
func _first_focusable(prefix: String) -> String:
	for id in _focusable():
		if String(id).begins_with(prefix):
			return String(id)
	return ""


## Walks the focus to an id with pad directions only — never by placing it there, which
## would prove nothing about whether a player can reach it. Each step asks the model
## which control its own geometry puts in each direction and presses the one that lands
## nearest the target: a player reading the screen does the same thing, and the model
## still decides where every press goes. Returns whether it arrived.
func _walk_to(id: String, max_steps: int = 12) -> bool:
	for _i in max_steps:
		if _focus_id() == id:
			return true
		var goal := _rect_of(id)
		var best := ""
		var best_distance := INF
		for dir in ["up", "down", "left", "right"]:
			var next: Dictionary = _focus().menu.nav.find_target(dir)
			if next.is_empty():
				continue
			if String(next["id"]) == id:
				best = dir
				break
			var distance := _rect_distance(next["rect"], goal)
			if distance < best_distance:
				best_distance = distance
				best = dir
		if best == "":
			return false
		await _dir(best)
	return _focus_id() == id


func _rect_of(id: String) -> Rect2:
	var node: Control = _focus().node_of(id)
	return node.get_global_rect() if node != null else Rect2()


static func _rect_distance(a: Rect2, b: Rect2) -> float:
	return (a.position + a.size * 0.5).distance_to(b.position + b.size * 0.5)


## Is the control the viewport painted the focus on inside the scroll frame that owns
## it? `follow_focus` scrolls the container, so the answer is the visible-focus claim.
func _focus_visible(screen: Node) -> bool:
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner == null:
		return false
	var scroll := screen.find_child("ScreenScroll", true, false) as Control
	if scroll == null:
		return false
	var frame := scroll.get_global_rect()
	var box: Rect2 = (owner as Control).get_global_rect()
	return frame.intersects(box) and box.size.y > 0.0 and box.position.y >= frame.position.y - 1.0


## The Control the viewport actually owns the focus on — the node the player sees the
## focus ring on. `null` means the model moved but nothing is painted.
func _painted() -> String:
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner == null:
		return "<none>"
	return String(owner.name)


## One pad direction: the engine's own event queue carries the stick and the mount's
## own per-frame poll (`_playable_process`, the same call a real pad goes through)
## moves the focus and repaints it. The stick is centred again before returning, so the
## next push is a fresh direction instead of a repeat.
func _dir(dir: String) -> void:
	await _stick(dir, 1.0)
	await _stick(dir, 0.0)


func _stick(dir: String, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	match dir:
		"up", "down":
			motion.axis = JOY_AXIS_LEFT_Y
			motion.axis_value = -value if dir == "up" else value
		_:
			motion.axis = JOY_AXIS_LEFT_X
			motion.axis_value = -value if dir == "left" else value
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await _frames(3)


func _confirm() -> void:
	await _button(JOY_BUTTON_A)


func _back() -> void:
	await _button(JOY_BUTTON_B)


## One pad button: the engine's queue carries the press, the mount's own poll resolves
## it, and the button is let go again so the next press is a fresh edge. Nothing here
## calls the bridge directly — a synthetic event that only works because a test called
## `act()` would prove nothing about the path a pad takes.
func _button(button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await _frames(3)
	await _release(button)


## Lets a button back up, so the next press is a fresh edge rather than a held button.
func _release(button: JoyButton) -> void:
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = button
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _frames(3)
