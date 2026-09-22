## menu_hover_capture.gd — the visual proof of the card hover and the pad's focus ring.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --rendering-driver opengl3 \
##     --path godot --resolution 1280x720 res://tests/ui/menu_hover_capture.tscn ; echo "exit=$?"
##
## RENDERING: a real window is required — plain `--headless` renders blank PNGs (the dummy
## driver), which is why this is a `.tscn` and not a `--script` run (`capture_ui.gd`'s own
## note). Every frame is read back from `get_viewport().get_texture().get_image()` and
## checked non-vacuous (a single-colour frame is a blank frame) before it is trusted.
##
## WHAT EACH FRAME IS. The reference's two card presentations, plus the composition it
## produces with a pad connected (`js/main.js:2579-2588`):
##
##   characters-hover.png             `.athlete-card:hover` — the soft
##                                    `rgba(0,229,255,0.35)` border and the 3 px lift
##   characters-pad-focus.png         `.menu-focus` — the 3 px `#00e5ff` ring, 3 px
##                                    outside the card, on a DIFFERENT card
##   characters-hover-and-focus.png   both, on the same card
##   team-hover.png                   the team panel (the screenshot's own screen)
##
## HOW THE STATES ARE DRIVEN. The pointer is a REAL `InputEventMouseMotion` pushed through
## `Viewport.push_input`, so the hover arrives by the engine's own GUI input path and not
## by a private call; the frame is captured only after the screen's own frame box is read
## back and found to be the hover box. The pad's focus is a real `grab_focus()` on the card
## — the same `focus_entered` edge `MenuFocus.apply_focus()` produces
## (`game/menu_focus.gd:377-382`) — and is verified the same way before capture.
extends Control

const HostScene := preload("res://game/Main.tscn")
const CardFocusRing := preload("res://src/ui/components/CardFocusRing.gd")
const OutDir := "res://../docs/agent-work/menu-hover"
const SETTLE_FRAMES := 6
## The hover lift is the reference's own `transition: transform 0.15s ease`
## (`styles.css:332`): the tween needs longer than a couple of frames to arrive, so the
## assertions wait for it while the captures only wait for the frame to be drawn.
const LIFT_FRAMES := 24
const HOVER_ALPHA := 0.35
const SAMPLES := 16

var _saved: Array = []
var _failures: Array = []
var _notes: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	print("MENU_HOVER_CAPTURE_START frame=%s" % str(get_viewport_rect().size))
	await _run()
	_finish()


func _run() -> void:
	await get_tree().process_frame
	var host: Control = HostScene.instantiate()
	host.set("ui_prototype", true)
	add_child(host)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var router: Control = host.call("ui_router") if host.has_method("ui_router") else null
	if router == null:
		_fail("harness/the_host_mounted_a_router", "the host built no router")
		return
	router.call("go_to", "characters")
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var screen: Node = router.call("active_screen")
	if screen == null:
		_fail("harness/the_characters_screen_mounted", "no active screen")
		return

	# --- the picker: the grid of athlete cards the pad can land on -------------------
	screen.call("apply_capture_state", "picker-open")
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var cards := _cards_of(screen)
	if cards.size() < 2:
		_fail("harness/the_picker_built_cards", "only %d card(s)" % cards.size())
		return
	var hover_card: Control = cards[0]
	var focus_card: Control = cards[1]
	# A card the screen has already chosen wears `PanelCardSelected` whatever else is
	# true of it, so the hover frame would be invisible on it.
	for card in cards:
		if not bool(card.get_meta("card_selected", false)):
			hover_card = card
			break
	for card in cards:
		if card != hover_card and not bool(card.get_meta("card_selected", false)):
			focus_card = card
			break

	# --- the pointer's own frame -----------------------------------------------------
	var hovered_by_event := await _point_at(hover_card)
	var hover_box := hover_card.get_theme_stylebox("panel") as StyleBoxFlat
	var hover_ok := hover_box != null and hover_box.border_color.a < 1.0 and not CardFocusRing.is_focused(hover_card)
	_notes.append("hover driven by a pushed mouse motion=%s, border_alpha=%.2f, ring=%s"
		% [str(hovered_by_event), hover_box.border_color.a if hover_box != null else -1.0,
		str(CardFocusRing.is_focused(hover_card))])
	if not hover_ok:
		_fail("capture/the_hover_state_was_reached", _notes[-1])
	else:
		_ok("capture/the_hover_state_was_reached")
	# The rects, so a reader can correlate the PNG with the state that produced it.
	print("# rect hover_card=%s rect=%s" % [hover_card.name, str(hover_card.get_global_rect())])
	print("# rect focus_card=%s rect=%s" % [focus_card.name, str(focus_card.get_global_rect())])
	await _capture("characters-hover")

	# --- the pad's own ring, on the other card ---------------------------------------
	await _clear_pointer()
	if _is_hovered(hover_card):
		_fail("capture/the_pointer_was_moved_away", "the first card is still hovered")
	else:
		_ok("capture/the_pointer_was_moved_away")
	focus_card.focus_mode = Control.FOCUS_ALL
	focus_card.grab_focus()
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	if not CardFocusRing.is_focused(focus_card):
		_fail("capture/the_pad_ring_was_reached", "the focused card wears no ring")
	else:
		_ok("capture/the_pad_ring_was_reached")
		_notes.append("focus ring on %s, hover ring on %s" % [focus_card.name, hover_card.name])
	await _capture("characters-pad-focus")

	# --- both at once: what the reference shows with a pad connected ------------------
	await _point_at(focus_card)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	if not (CardFocusRing.is_focused(focus_card) and _is_hovered(focus_card)):
		_fail("capture/the_composed_state_was_reached", "the two holders did not compose")
	else:
		_ok("capture/the_composed_state_was_reached")
	await _capture("characters-hover-and-focus")

	# --- the team panel: the screen the report's screenshot came from -----------------
	screen.call("apply_capture_state", "default")
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var slots := _cards_of(screen)
	if slots.is_empty():
		_fail("capture/the_team_panel_built_cards", "no team slot")
		return
	var rest_y: float = (slots[0] as Control).position.y
	await _point_at(slots[0])
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	# `.team-slot:hover` (`styles.css:3040-3042`) is a `transform` and nothing else: the
	# slot lifts 2 px and paints NO border, so the lift is what the capture must show.
	if not _is_lifted(slots[0], rest_y):
		_fail("capture/the_team_slot_lifted",
			"the slot did not answer the pointer (y=%.1f, rest=%.1f)" % [slots[0].position.y, rest_y])
	else:
		_ok("capture/the_team_slot_lifted")
		_notes.append("team slot %s lifted %.1f px, border alpha %.2f (the reference paints none)"
			% [slots[0].name, rest_y - slots[0].position.y,
			(slots[0].get_theme_stylebox("panel") as StyleBoxFlat).border_color.a])
	await _capture("team-hover")


# ---------------------------------------------------------------------------
# Driving the two states, and reading them back
# ---------------------------------------------------------------------------

## Pushes a real mouse motion at the card's centre through the viewport's own GUI input
## path. Answers whether the screen's hover frame is on the card afterwards.
func _point_at(card: Control) -> bool:
	var centre := card.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = centre
	motion.global_position = centre
	get_viewport().push_input(motion, true)
	for _i in LIFT_FRAMES:
		await get_tree().process_frame
	return _is_hovered(card)


## Parks the pointer on empty space at the top-left of the frame. The card's own
## `mouse_exited` is what clears the hover.
func _clear_pointer() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(2, 2)
	motion.global_position = Vector2(2, 2)
	get_viewport().push_input(motion, true)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame


## Whether the card is wearing the reference's hover frame: the border at
## `rgba(0,229,255,0.35)` (`styles.css:339`). NOT "alpha < 1": the plain frame's
## `rgba(255,255,255,0.12)` (`styles.css:327`) is below 1 too, and a predicate that
## matched it would report a hover that is not there.
func _is_hovered(card: Control) -> bool:
	var box := card.get_theme_stylebox("panel") as StyleBoxFlat
	if box == null:
		return false
	var expected := Color(CardFocusRing.palette_of(card, "cyan"), HOVER_ALPHA)
	return box.border_color.is_equal_approx(expected)


## Whether the card has been lifted off its rest Y. `.team-slot:hover`
## (`styles.css:3040-3042`) is a `transform` and NOTHING else — a hovered team slot
## paints no border — so the lift is the only thing to read on that family.
func _is_lifted(card: Control, rest_y: float) -> bool:
	return card.position.y < rest_y - 0.5


func _cards_of(screen: Node) -> Array:
	var out: Array = []
	for spec in screen.call("focus_controls"):
		var entry: Dictionary = spec
		var node: Control = entry.get("node", null)
		if node != null and node is PanelContainer and CardFocusRing.ring_of(node) != null:
			out.append(node)
	return out


# ---------------------------------------------------------------------------
# Capture and the harness contract
# ---------------------------------------------------------------------------

func _capture(file: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		_fail("capture/%s" % file, "the viewport produced no image")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OutDir))
	var path := "%s/%s.png" % [OutDir, file]
	var err := img.save_png(path)
	var colours := {}
	var step_x := maxi(img.get_width() / SAMPLES, 1)
	var step_y := maxi(img.get_height() / SAMPLES, 1)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			colours[img.get_pixel(x, y).to_rgba32()] = true
			y += step_y
		x += step_x
	if colours.size() <= 1:
		_fail("capture/%s" % file, "the frame carries one colour (blank)")
		return
	if err != OK:
		_fail("capture/%s" % file, "save_png err=%d" % err)
		return
	_saved.append(path)
	_ok("capture/%s" % file)
	print("ok %s path=%s size=%dx%d colours=%d" % [file, path, img.get_width(), img.get_height(), colours.size()])


var _ok_count: int = 0


func _ok(name: String) -> void:
	print("ok %s" % name)
	_ok_count += 1


func _fail(name: String, why: String) -> void:
	print("FAIL %s: %s" % [name, why])
	_failures.append(name)


func _finish() -> void:
	for note in _notes:
		print("# note %s" % note)
	print("# saved=%s" % JSON.stringify(_saved))
	var total := _ok_count + _failures.size()
	if _failures.is_empty():
		print("PASS %d/%d" % [_ok_count, total])
		get_tree().quit(0)
	else:
		print("FAIL %d/%d first=%s" % [_ok_count, total, String(_failures[0])])
		get_tree().quit(1)
