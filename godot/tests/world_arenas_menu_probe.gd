## world_arenas_menu_probe.gd — the integrator's diagnostic for the MENU FIT RED
## (not a gate). The slice's fit check reads `MenuColumn`'s children the same way
## (`game_slice_test.gd`: per-child `_fit_height` + separations + chrome against
## 1280x720 and 1152x648); the world-arena row made the column need 677 px for a
## 648 px frame. This probe prints the raw material for the fix: every column
## child's minimum size and, for the rows, every child's minimum width — so the
## width a new world-arena control can occupy is read, not guessed.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##     --script res://tests/world_arenas_menu_probe.gd
##
## Output: `# MENU...` lines only. Read-only: builds the menu, writes nothing.
extends SceneTree

const MENU_SCENE := "res://game/Main.tscn"

var _state := 0


func _process(_delta: float) -> bool:
	if _state == 0:
		_state = 1
		_run()
	return _state == 2


func _run() -> void:
	var packed: PackedScene = load(MENU_SCENE)
	if packed == null:
		print("# MENU probe: no menu scene")
		quit(1)
		return
	var menu: Node = packed.instantiate()
	menu.set("ui_legacy", true)
	var host := Control.new()
	host.size = Vector2(1280.0, 720.0)
	root.add_child(host)
	host.add_child(menu)
	for i in 4:
		await process_frame
	var column := _find(menu, "MenuColumn")
	var margin := _find(menu, "MenuMargin")
	if column == null or margin == null:
		print("# MENU probe: MenuColumn/MenuMargin missing")
		quit(1)
		return
	print("# MENU margins l/r/t/b=%d/%d/%d/%d separation=%d" % [
		margin.get_theme_constant("margin_left"), margin.get_theme_constant("margin_right"),
		margin.get_theme_constant("margin_top"), margin.get_theme_constant("margin_bottom"),
		column.get_theme_constant("separation")])
	var rows := column.get_children()
	var widest := 0.0
	var widest_row := ""
	var total_y := 0.0
	for row_node in rows:
		var row := row_node as Control
		if row == null:
			continue
		var ms := row.get_combined_minimum_size()
		print("# MENU row %-16s class=%-16s min=%6.0fx%4.0f size=%6.0fx%4.0f" % [
			row.name, row.get_class(), ms.x, ms.y, row.size.x, row.size.y])
		if ms.x > widest:
			widest = ms.x
			widest_row = String(row.name)
		if row is Container:
			var parts: Array[String] = []
			for kid in row.get_children():
				var k := kid as Control
				if k == null:
					continue
				parts.append("%s %s %sx%s" % [k.name, k.get_class(),
					"%.0f" % k.get_combined_minimum_size().x, "%.0f" % k.get_combined_minimum_size().y])
			print("# MENU   %s: %s" % [row.name, ", ".join(parts)])
	print("# MENU widest row=%s at %.0f px (frame avail %.0f at 1152)" % [widest_row, widest, 1152.0 - 74.0])
	quit(0)


func _find(from: Node, node_name: String) -> Node:
	if from.name == node_name:
		return from
	for child in from.find_children("*", "", true, false):
		if child.name == node_name:
			return child
	return null
