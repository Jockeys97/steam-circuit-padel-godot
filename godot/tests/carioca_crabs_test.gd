extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var wildlife := preload("res://game/arenas/carioca_crabs.gd").new()
	root.add_child(wildlife)
	wildlife.set_process(false)
	assert(wildlife.crabs.size() == 4)
	var seen := false
	var hidden := false
	var submerged := false
	for i in 600:
		wildlife.step(0.1)
		for crab in wildlife.crabs:
			assert(absf(crab.position.x) >= 8.5)
		seen = seen or wildlife.crabs[0].visible
		hidden = hidden or not wildlife.crabs[0].visible
		submerged = submerged or wildlife.crabs[0].position.y < -0.3
	assert(seen and hidden and submerged)
	assert(wildlife.find_children("*", "CollisionObject3D", true, false).is_empty())
	wildlife.free()
	print("PASS Carioca crabs: walking, burrowing, hiding, outside court, no collisions")
	quit()
