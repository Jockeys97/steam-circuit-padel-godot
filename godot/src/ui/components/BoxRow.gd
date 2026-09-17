## BoxRow — `BoxColumn` laid out in a line: the reference's rows are ONE element that
## both paints (`li` in `.history-list`, `styles.css:2672-2682`) and lays its cells out
## horizontally. The screens' accessors and the audits read those cells as the row's own
## children (`Row0/Badge`, `Row0/Main/Mode`, `Row0/Meta/Score`), which is why the row
## cannot be a `PanelContainer` wrapping an unnamed `HBoxContainer`.
extends "res://src/ui/components/BoxColumn.gd"


## The cells, left to right, centred on the row's own height.
func _sort_children() -> void:
	var box := _box()
	var left := box.get_margin(SIDE_LEFT)
	var top := box.get_margin(SIDE_TOP)
	var height := maxf(0.0, size.y - top - box.get_margin(SIDE_BOTTOM))
	var right := maxf(0.0, size.x - left - box.get_margin(SIDE_RIGHT))
	var shown: Array[Control] = []
	for child in get_children():
		var control := child as Control
		if control != null and control.visible:
			shown.append(control)
	var fixed := 0.0
	var expanders := 0
	for control in shown:
		fixed += control.get_combined_minimum_size().x
		if control.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			expanders += 1
	var slack := maxf(0.0, right - fixed - float(separation) * float(maxi(shown.size() - 1, 0)))
	var x := left
	for index in shown.size():
		var control: Control = shown[index]
		var width := control.get_combined_minimum_size().x
		if expanders > 0 and control.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
			width += slack / float(expanders)
		var height_used := height
		if control.size_flags_vertical == Control.SIZE_SHRINK_CENTER:
			height_used = minf(height, control.get_combined_minimum_size().y)
		control.position = Vector2(x, top + floorf((height - height_used) * 0.5))
		control.size = Vector2(width, height_used)
		x += width
		if index < shown.size() - 1:
			x += float(separation)


func _get_minimum_size() -> Vector2:
	var box := _box()
	var out := Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
		box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))
	var widest := 0.0
	var tallest := 0.0
	var count := 0
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var child_min := control.get_combined_minimum_size()
		widest += child_min.x
		tallest = maxf(tallest, child_min.y)
		count += 1
	if count > 1:
		widest += float(separation) * float(count - 1)
	return out + Vector2(widest, tallest)
