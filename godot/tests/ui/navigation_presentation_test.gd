extends SceneTree

const Config := preload("res://game/match_config.gd")
var host: Control
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func settle() -> void:
	for i in 6:
		host._playable_process(0.0)
		await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	host._input(event)

func down() -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = 0.0
	host._input(event)
	event.axis_value = 1.0
	host._input(event)
	event.axis_value = 0.0
	host._input(event)

func run() -> void:
	Config.save_dir = "user://navigation-presentation-%d" % Time.get_ticks_usec()
	root.size = Vector2i(1280, 720)
	host = load("res://game/Main.tscn").instantiate()
	root.add_child(host)
	host.set_process(false)
	await settle()
	var first: String = host._focus.focus_id()
	key(KEY_DOWN)
	var second: String = host._focus.focus_id()
	check(first != second, "keyboard down retains its new model selection")
	check(root.gui_get_focus_owner() == host._focus.focus_node(), "keyboard paints the selected control")
	key(KEY_UP)
	check(host._focus.focus_id() == first, "opposite key returns from the previous selection")
	check(root.gui_get_focus_owner() == host._focus.focus_node(), "second key keeps visible and model focus aligned")
	host._bridge.set_focus("menu/PlayButton")
	host._apply_focus()
	key(KEY_ENTER)
	await settle()
	check(host._router.active_id() == "modes", "keyboard confirm opens modes")
	key(KEY_ESCAPE)
	await settle()
	check(host._router.active_id() == "menu", "keyboard back returns to menu")
	host._router.go_to("arena")
	await settle()
	var arena: Control = host._router.active_screen()
	var scroll := arena.find_child("Scroll", true, false) as ScrollContainer
	var moved_below_fold := false
	var visited: Array = []
	for i in 16:
		var before: String = host._focus.focus_id()
		down()
		await process_frame
		var selected: Control = host._focus.focus_node()
		if host._focus.focus_id() == before:
			break
		visited.append(host._focus.focus_id())
		if scroll.is_ancestor_of(selected):
			check(scroll.get_global_rect().intersects(selected.get_global_rect()), "pad selection remains visible: " + selected.name)
			check(root.gui_get_focus_owner() == selected, "pad paints " + selected.name)
			moved_below_fold = moved_below_fold or scroll.scroll_vertical > 0
	check(visited.size() >= 3, "pad walks multiple arena rows")
	check(moved_below_fold, "arena navigation scrolls beyond the first viewport")
	# Start at the lowest target, then manually scroll away. A boundary arrow
	# must scroll the live container even though there is no next focus target.
	var bottom_id := ""
	var bottom_y := -INF
	for id in host._focus.focusable_ids():
		var node: Control = host._focus.node_of(id)
		var y := node.get_global_rect().get_center().y
		if y > bottom_y:
			bottom_id = id
			bottom_y = y
	host._bridge.set_focus(bottom_id)
	host._apply_focus()
	scroll.scroll_vertical = 0
	await process_frame
	key(KEY_DOWN)
	check(scroll.scroll_vertical == 90, "boundary key scrolls the real arena by one step")
	check(host._focus.focus_id() == bottom_id, "boundary scroll preserves selection")
	var verdict: Dictionary = host._focus.step_pad({"stick_y": 1.0, "right_stick_y": 1.0, "buttons": {}, "now_ms": 9999.0})
	check(float(verdict.get("direction_scrolled", 0.0)) == 15.0, "pad boundary exposes only its directional scroll")
	check(float(verdict.get("scrolled", 0.0)) > float(verdict.get("direction_scrolled", 0.0)), "right-stick contribution stays separate to avoid double scrolling")
	var before_scroll := scroll.scroll_vertical
	host._apply_navigation_scroll(float(verdict.get("direction_scrolled", 0.0)))
	check(scroll.scroll_vertical == before_scroll + 15, "pad boundary scroll reaches the real container")
	host.queue_free()
	await process_frame
	print("NAVIGATION_PRESENTATION ", "PASS" if failures == 0 else "FAIL %d" % failures)
	quit(0 if failures == 0 else 1)
