extends SceneTree

func _initialize() -> void:
	var script: GDScript = load("res://tests/ui/_probe_input.gd")
	var probe: Node = script.new()
	root.add_child(probe)
