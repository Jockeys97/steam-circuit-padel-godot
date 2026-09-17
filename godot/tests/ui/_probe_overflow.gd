## Temporary probe (deleted before the sweep): which node's minimum size overflows the frame.
extends SceneTree

const HostScene := preload("res://game/Main.tscn")

var _frame: Control
var _host: Control
var _router: Control

func _initialize() -> void:
	_run()

func _run() -> void:
	for spec in [["characters", Vector2(1152, 648)]]:
		var id := String(spec[0])
		var size := spec[1] as Vector2
		_frame = Control.new()
		_frame.size = size
		root.add_child(_frame)
		_host = HostScene.instantiate()
		_host.set("ui_prototype", true)
		_frame.add_child(_host)
		for _i in 4:
			await process_frame
		_router = _host.call("ui_router")
		print("###### ", id, " frame=", size, " go_to=", _router.call("go_to", id))
		for _i in 4:
			await process_frame
		var screen: Node = _router.call("active_screen")
		var culprits: Array = []
		if id == "characters":
			var grid: Node = screen.find_child("GridArea", true, false)
			_culprits_narrow(grid, culprits)
		else:
			_culprits(screen, size, culprits)
		print("  screen min=", (screen as Control).get_combined_minimum_size())
		for line in culprits.slice(0, 14):
			print("   ", line)
		_frame.queue_free()
		await process_frame
	print("probe done")
	quit(0)

func _culprits_narrow(node: Node, out: Array) -> void:
	var c := node as Control
	if c != null:
		var want := c.get_combined_minimum_size()
		if want.x > 200.0:
			out.append("%s [%s] min=(%.0f,%.0f) size=(%.0f,%.0f) text=%s" % [c.name, c.get_class(), want.x, want.y, c.size.x, c.size.y, (c as Label).text if c is Label else ""])
	for child in node.get_children():
		_culprits_narrow(child, out)


func _culprits(node: Node, size: Vector2, out: Array) -> void:
	var c := node as Control
	if c != null:
		var want := c.get_combined_minimum_size()
		if want.x > size.x + 0.5 or want.y > size.y + 0.5:
			out.append("%s [%s] min=(%.0f,%.0f) size=(%.0f,%.0f)" % [c.name, c.get_class(), want.x, want.y, c.size.x, c.size.y])
	for child in node.get_children():
		_culprits(child, size, out)
