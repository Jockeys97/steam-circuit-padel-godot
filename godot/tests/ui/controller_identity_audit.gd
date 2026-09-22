## Runtime controller-layout audit. Synthetic names exercise the deterministic part
## of the same path the match feeds with `Input.get_joy_name(device)`; no physical
## controller is required for Xbox/PlayStation/generic coverage.
extends SceneTree

const LegendScene := preload("res://src/ui/components/ControlLegend.tscn")
const LegendClass := preload("res://src/ui/components/ControlLegend.gd")
const PauseScene := preload("res://src/ui/screens/PauseOverlay.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func run() -> void:
	check(LegendClass.detect_device_layout("Xbox Wireless Controller") == "xbox",
		"Xbox names select the Xbox layout")
	check(LegendClass.detect_device_layout("Microsoft XInput Compatible Gamepad") == "xbox",
		"XInput names select the Xbox layout")
	check(LegendClass.detect_device_layout("DualSense Wireless Controller") == "playstation",
		"DualSense names select the PlayStation layout")
	check(LegendClass.detect_device_layout("Sony PS5 Controller") == "playstation",
		"Sony PS5 names select the PlayStation layout")
	check(LegendClass.detect_device_layout("Nintendo Switch Pro Controller") == "generic",
		"unknown families use the generic layout")
	check(LegendClass.detect_device_layout("") == "generic",
		"a disconnected controller uses the generic layout")

	var legend: Control = LegendScene.instantiate()
	root.add_child(legend)
	legend.setup(LegendClass.reference_rows(), {"visual": false})
	check(legend.set_device_name("DualShock 4 Wireless Controller") == "playstation",
		"the live-name door reports PlayStation")
	check(legend.device_layout() == "playstation", "the live-name door swaps the legend")
	check(legend.row_controls()[2] == "✕" and legend.row_controls()[12] == "OPTIONS",
		"PlayStation face and pause caps are visible")

	var overlay: Control = PauseScene.instantiate()
	root.add_child(overlay)
	await process_frame
	overlay.set_pad_device(7, "Xbox Elite Wireless Controller", true)
	check(overlay.pad_connected(), "the overlay records a connected controller")
	check(overlay.pad_device() == 7, "the overlay records the selected Godot device")
	check(overlay.pad_layout() == "xbox", "the overlay classifies the selected controller")
	check(overlay.legend().device_layout() == "xbox", "the pause legend follows Xbox live")
	overlay.set_pad_device(9, "DualSense Wireless Controller", true)
	check(overlay.pad_device() == 9 and overlay.pad_layout() == "playstation",
		"switching active controller updates identity and family")
	check(overlay.legend().row_controls()[2] == "✕",
		"switching active controller updates every visible cap")
	var art := overlay.legend().visual_node().get_node("ControllerArt") as TextureRect
	check(art.texture != null and art.texture.resource_path.ends_with("playstation-controller-steam.webp"),
		"switching active controller updates the visible artwork")
	overlay.set_pad_device(-1, "", false)
	check(not overlay.pad_connected(), "disconnect clears the connected state")
	check(overlay.pad_device() == -1 and overlay.pad_name() == "",
		"disconnect clears the selected identity")
	check(overlay.legend().device_layout() == "generic",
		"disconnect switches the guide to the generic fallback")
	check(art.texture != null and art.texture.resource_path.ends_with("generic-controller-steam.webp"),
		"disconnect updates the visible artwork")

	legend.queue_free()
	overlay.queue_free()
	await process_frame
	print("CONTROLLER_IDENTITY %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(1 if failures else 0)
