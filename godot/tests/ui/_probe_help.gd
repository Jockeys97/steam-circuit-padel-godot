## Temporary probe (deleted before the sweep): which help node is wider than the 820 frame.
extends SceneTree

const HostScene := preload("res://game/Main.tscn")

func _initialize() -> void:
	_run()

func _run() -> void:
	var frame := Control.new()
	frame.size = Vector2(1280, 720)
	root.add_child(frame)
	var host: Control = HostScene.instantiate()
	host.set("ui_prototype", true)
	frame.add_child(host)
	for _i in 4:
		await process_frame
	var router: Node = host.call("ui_router")
	print("go_to=", router.call("go_to", "help"))
	for _i in 4:
		await process_frame
	frame.size = Vector2(820, 600)
	for _i in 5:
		await process_frame
	var screen: Node = router.call("active_screen")
	for node_name in ["HelpScroll", "HelpBody", "HelpRow", "HelpSections", "HelpControls", "HelpInputTabs"]:
		var control: Control = screen.find_child(node_name, true, false)
		if control == null:
			print(node_name, " MISSING")
			continue
		print("%s size=(%.0f,%.0f) min=(%.0f,%.0f) parent=%s" % [node_name, control.size.x, control.size.y, control.get_combined_minimum_size().x, control.get_combined_minimum_size().y, control.get_parent().name])
	var row: Control = screen.find_child("HelpRow", true, false)
	for child in row.get_children():
		print("  row child %s [%s] size=%.0f min=%.0f visible=%s" % [child.name, child.get_class(), (child as Control).size.x, (child as Control).get_combined_minimum_size().x, (child as Control).visible])
	var sections: Control = screen.find_child("HelpSections", true, false)
	for child in sections.get_children():
		print("  card %s size=%.0f min=%.0f" % [child.name, (child as Control).size.x, (child as Control).get_combined_minimum_size().x])
	print("probe done")
	quit(0)
