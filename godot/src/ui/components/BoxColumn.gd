## BoxColumn — the reference's boxes that BOTH paint a surface and stack their children in
## a column: `article.help-card`, `.history-stats__box`, `.profile-stats__box`
## (`styles.css:2425-2436`, `:2645-2651`, `:1289-1300`). One DOM element does both jobs.
##
## Godot splits them: `PanelContainer` paints its `panel` stylebox but fits every child to
## the same rect, `VBoxContainer` stacks children but paints nothing. The screens' own
## accessors and the screen audits address those boxes' children by name as DIRECT children
## of the box (`Stat0/Value`, `Stat0/Label`, `HelpCard0/Title`, `HelpCard0/Body`), so
## neither stock container can carry the reference's shape. This is the missing primitive:
## it draws its `panel` stylebox and lays its children out in a column inside it.
##
## The stylebox is read through the same theme item the legibility audit walks
## (`get_theme_stylebox("panel")`), so what the screen paints and what the audit measures
## stay one value — a painted box cannot be invisible to the contrast walk (and vice versa).
##
## Usage: add a `theme_override_styles/panel`, set `separation`, then add the children in
## the reference's own order. No layout flags are honoured beyond each child's minimum
## height: the reference's boxes are columns, which is what this is.
extends Container

## The gap between two children, in pixels (BoxContainer's own theme constant name).
var separation: int = 0:
	set(value):
		separation = value
		queue_sort()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_sort_children()
			queue_redraw()
		NOTIFICATION_DRAW:
			_draw_panel()
		NOTIFICATION_THEME_CHANGED, NOTIFICATION_RESIZED:
			queue_sort()
			queue_redraw()


## The column, laid inside the stylebox's content margins — the reference's padding.
func _sort_children() -> void:
	var box := _box()
	var left := box.get_margin(SIDE_LEFT)
	var top := box.get_margin(SIDE_TOP)
	var width := maxf(0.0, size.x - left - box.get_margin(SIDE_RIGHT))
	var y := top
	var shown: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control != null and control.visible:
			shown.append(control)
	for index in shown.size():
		var control: Control = shown[index]
		var child_height := maxf(control.get_combined_minimum_size().y, 0.0)
		control.position = Vector2(left, y)
		control.size = Vector2(width, child_height)
		y += child_height
		if index < shown.size() - 1:
			y += float(separation)


func _get_minimum_size() -> Vector2:
	var box := _box()
	var out := Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
		box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))
	var widest := 0.0
	var tall := 0.0
	var count := 0
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var child_min := control.get_combined_minimum_size()
		widest = maxf(widest, child_min.x)
		tall += child_min.y
		count += 1
	if count > 1:
		tall += float(separation) * float(count - 1)
	return out + Vector2(widest, tall)


func _draw_panel() -> void:
	_box().draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


func _box() -> StyleBox:
	var box := get_theme_stylebox("panel")
	return box if box != null else StyleBoxEmpty.new()
