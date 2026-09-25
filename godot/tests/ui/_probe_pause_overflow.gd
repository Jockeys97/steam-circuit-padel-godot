## _probe_pause_overflow.gd — does the pause card actually need a scroll container?
##
##   /opt/homebrew/bin/godot --headless --path godot/ \
##       --script res://tests/ui/_probe_pause_overflow.gd
##
## The right-stick ticket lists "pause panels where overflowing". Before adding a
## `ScrollContainer` to a modal that has none, this asks the question the layout can
## answer: at the two shipped frames, is the pause card's own content taller than the
## area it is drawn in? It mounts the real overlay, opens it, and reports the card's
## combined minimum size, its laid-out size and every `ScrollContainer` it holds.
##
## It writes nothing and asserts nothing: it is a measurement, and the report under
## `docs/agent-work/right-stick-scroll/` carries its output.
extends SceneTree

const OverlayScene := preload("res://src/ui/screens/PauseOverlay.tscn")
const FRAMES := [Vector2(1280, 720), Vector2(1152, 648)]

var _frame: Control


func _initialize() -> void:
	_run()


func _run() -> void:
	for size in FRAMES:
		_frame = Control.new()
		_frame.size = size
		root.add_child(_frame)
		var overlay: Control = OverlayScene.instantiate()
		_frame.add_child(overlay)
		for _i in 4:
			await process_frame
		overlay.call("open")
		for _i in 4:
			await process_frame
		var card: Control = overlay.find_child("PauseCard", true, false)
		if card == null:
			card = _first_panel(overlay)
		var scrolls := []
		_collect_scrolls(overlay, scrolls)
		print("PAUSE_PROBE frame=%s open=%s card=%s" % [size, overlay.call("is_open"), card != null])
		if card != null:
			print("  card min=%s size=%s viewport=%s" % [
				card.get_combined_minimum_size(), card.size, size])
			print("  card overflows=%s" % (card.get_combined_minimum_size().y > card.size.y + 0.5))
		print("  scroll_containers=%d %s" % [scrolls.size(), scrolls])
		print("  overlay min=%s size=%s" % [
			(overlay as Control).get_combined_minimum_size(), (overlay as Control).size])
		_frame.queue_free()
		await process_frame
	print("PAUSE_PROBE_DONE")
	quit(0)


func _first_panel(node: Node) -> Control:
	for child in node.get_children():
		if child is PanelContainer:
			return child as Control
		var found := _first_panel(child)
		if found != null:
			return found
	return null


func _collect_scrolls(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is ScrollContainer:
			var sc := child as ScrollContainer
			out.append("%s(max=%.0f page=%.0f)" % [sc.name, sc.get_v_scroll_bar().max_value, sc.get_v_scroll_bar().page])
		_collect_scrolls(child, out)
