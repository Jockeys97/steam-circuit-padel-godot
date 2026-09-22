## menu_hover_probe.gd — the two engine measurements the card hover rests on.
##
## The hover lift (`translateY(-3px)`, `styles.css:338`) and the focus ring
## (`outline-offset: 3px`, `styles.css:735`) both have to happen WITHOUT moving the card
## in the layout. Godot offers two candidate mechanisms and this probe measures which one
## survives, so the choice is a measurement and not a preference:
##
##   1. `position` / `scale` on a card inside a `Container`. If a re-sort resets them, the
##      lift cannot be a bare `position.y` write, and the ring cannot be a `scale`.
##   2. `StyleBoxFlat.expand_margin_*`. If it stays out of `get_minimum_size()`, a ring
##      can be drawn OUTSIDE a card without changing the card's size — the one Godot
##      property that matches what a CSS `outline` does to layout.
##
## Measured on Godot 4.7.2.stable (2026-09-21), recorded in
## `docs/agent-work/menu-hover/REPORT.md`:
##   1a. home position: (0, 0)               1b. after a manual lift: pos=(0, -3) scale=(1, 1.03)
##   1c. after `queue_sort`: pos=(0, 0) scale=(1, 1)      <-- BOTH reset
##   2.  a `sort_children` handler runs BEFORE the container repositions its children
##   3a. `get_minimum_size()` with `expand_margin 3` = (18, 18)   <-- content margins only
##   3c. the card keeps its own size with an expand-margin panel
##
##   Godot --path godot --headless --script res://tests/ui/menu_hover_probe.gd
extends SceneTree

const CARD_SIZE := Vector2(200, 100)
const LIFT := 3.0
const CONTENT := 18.0
const EXPAND := 3.0

var _grid: GridContainer
var _card: PanelContainer
var _failures: int = 0


func _initialize() -> void:
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size = Vector2(600, 400)
	root.add_child(_grid)
	_card = _panel("Card0")
	_grid.add_child(_card)
	_grid.add_child(_panel("Card1"))
	await process_frame
	await process_frame

	# 1. does a re-sort undo a `position` / `scale` write on a child?
	var home := _card.position
	_card.position.y -= LIFT
	_card.scale = Vector2(1.0, 1.03)
	var lifted := _card.position
	var scaled := _card.scale
	_grid.queue_sort()
	await process_frame
	await process_frame
	var after_pos := _card.position
	var after_scale := _card.scale
	print("1a. home=%s  lifted=%s  scaled=%s" % [home, lifted, scaled])
	print("1b. after queue_sort: pos=%s scale=%s" % [after_pos, after_scale])
	_check(after_pos == home, "a_container_resets_a_child_position_on_resort",
		"position stayed %s" % after_pos)
	_check(after_scale == Vector2.ONE, "a_container_resets_a_child_scale_on_resort",
		"scale stayed %s" % after_scale)
	_check(lifted.y < home.y, "the_manual_lift_landed_before_the_sort",
		"lift was %s" % lifted)

	# 2. does `expand_margin` leak into the minimum size?
	var box := StyleBoxFlat.new()
	box.content_margin_left = CONTENT
	box.content_margin_top = CONTENT
	box.set_expand_margin_all(EXPAND)
	var minimum := box.get_minimum_size()
	print("2a. minimum_size with content %s and expand %s: %s" % [CONTENT, EXPAND, minimum])
	_check(minimum == Vector2(CONTENT, CONTENT), "expand_margin_is_absent_from_minimum_size",
		"minimum was %s" % minimum)
	var before := _card.size
	_card.add_theme_stylebox_override("panel", box)
	await process_frame
	await process_frame
	print("2b. card size: before=%s after=%s (minimum %s)" % [before, _card.size, CARD_SIZE])
	_check(_card.size == before, "an_expand_margin_ring_does_not_resize_the_card",
		"card went from %s to %s" % [before, _card.size])

	print("%s %d/%d" % ["FAIL" if _failures > 0 else "PASS", 5 - _failures, 5])
	quit(1 if _failures > 0 else 0)


func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	return panel


func _check(ok: bool, label: String, detail: String) -> void:
	if ok:
		print("ok ", label)
	else:
		_failures += 1
		print("FAIL ", label, ": ", detail)
