## Temporary probe (deleted before the sweep): why the challenges arena rows and the done
## border fail their audits.
extends SceneTree

const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenScene := preload("res://src/ui/screens/ChallengesScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const SaveStore := preload("res://src/save/save_store.gd")
const SaveSchema := preload("res://src/save/save_schema.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const BoardClass := preload("res://src/ui/screens/ChallengesScreen.gd")

var _router: Node


func _initialize() -> void:
	_run()


func _dump(node: Node, depth: int, want: Color) -> void:
	if depth > 4:
		return
	var pad := ""
	for _i in depth:
		pad += "  "
	var info := ""
	var control := node as Control
	if control != null:
		info = " rect=" + str(control.size)
		var box := control.get_theme_stylebox("panel") as StyleBoxFlat
		if box != null:
			info += " border=" + str(box.border_color) + " done=" + str(box.border_color.is_equal_approx(want))
	print(pad, node.name, " [", node.get_class(), "]", info)
	for child in node.get_children():
		_dump(child, depth + 1, want)


func _run() -> void:
	var store := SaveStore.new("user://probe-challenges")
	_router = Router.new()
	root.add_child(_router)
	for id in Router.ids():
		_router.register(String(id), PlaceholderScene)
	_router.register("challenges", ScreenScene)
	_router.go_to("challenges", {"store": store})
	await process_frame
	await process_frame
	var screen: Node = _router.active_screen()
	print("screen=", screen, " theme=", screen.theme)
	var sections: Array = screen.sections()
	print("sections=", sections.size())
	for index in sections.size():
		var rows: Array = screen.section_rows(index)
		print("section ", index, " title=", (sections[index] as Dictionary).get("title_key", "?"),
			" rows=", rows.size())
		if index == 2:
			var keys: Array = []
			for row_in in rows:
				keys.append(String((row_in as Dictionary).get("name_key", "")))
			print("  arena name_keys=", keys)
	# What the board looks like at the state the audit checks the done border in.
	print("some-complete=", screen.apply_capture_state("some-complete"))
	await process_frame
	print("section_done(1)=", screen.section_done(1))
	var board2: Control = screen.find_child(BoardClass.BOARD_NODE, true, false)
	var theme2: Theme = screen.theme
	var want2: Color = theme2.get_color("challenge_done_border", "Palette")
	_dump(board2, 0, want2)
	print("probe done")
	quit(0)


