extends SceneTree

const Config = preload("res://game/match_config.gd")
const Locale = preload("res://src/locale/locale.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1

func settle() -> void:
	for i in range(5):
		await process_frame

func run() -> void:
	Config.save_dir = "user://menu-context-%s" % Time.get_ticks_usec()
	var main = load("res://game/Main.tscn").instantiate()
	root.add_child(main)
	await settle()
	check(main._bridge.focus_id() == "menu/PlayButton", "first entry selects play")
	var screen = main._router.active_screen()
	main._bridge.set_focus("menu/DrillButton")
	main._focus.apply_focus()
	check(screen._selected_control == "DrillButton", "controller focus updates description")
	screen.route_action("to-drill")
	await settle()
	main._router.go_to("menu")
	await settle()
	check(main._bridge.focus_id() == "menu/DrillButton", "actual router return restores training focus")
	screen = main._router.active_screen()
	var texts: Array = []
	for lang in ["it", "en"]:
		Locale.set_lang(lang)
		screen.refresh_strings()
		texts.append(screen._description.text)
		check(not screen._description.text.begins_with("menuDesc"), "description translated " + lang)
		for device_hint in ["menuKeysHint", "menuPadHint", "menuPadPsHint", "menuPadXboxHint"]:
			screen._device_hint = device_hint
			screen._refresh_context()
			check(screen._control("HintLabel").text != device_hint, "device hint translated " + lang + device_hint)
		screen._device_hint = "menuKeysHint"
		screen._refresh_context()
		if "--capture-menu" in OS.get_cmdline_user_args():
			root.size = Vector2i(1024, 600)
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/padel-menu-context-" + lang + ".png")
	check(texts[0] != texts[1], "description changes with language")
	check(screen.focus_controls().size() == 9, "original nine controls preserved")
	main.queue_free()
	await process_frame
	print("MENU_CONTEXT failures=", failures)
	quit(0 if failures == 0 else 1)
