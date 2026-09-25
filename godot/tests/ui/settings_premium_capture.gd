extends SceneTree
## Visual fixture only: temporary profile, no writes to the player's settings.

const ScreenScene := preload("res://src/ui/screens/SettingsScreen.tscn")
const SaveStore := preload("res://src/save/save_store.gd")
const Locale := preload("res://src/locale/locale.gd")
const Config := preload("res://game/match_config.gd")
const ModesSave := preload("res://src/modes/modes_save.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var lang := "it" if "--it" in args else "en"
	Locale.set_lang(lang)
	var live := "--live" in args
	if live:
		Config.save_dir = "user://settings-premium-live-%d" % Time.get_ticks_usec()
		ModesSave.save_pref(Config.save_store(), "lang", lang)
		var menu: Node = load("res://game/Main.tscn").instantiate()
		root.add_child(menu)
		for _i in 8:
			await process_frame
		menu._router.go_to("settings")
		menu._runtime_ost.toast.hide()
	else:
		var screen := ScreenScene.instantiate()
		root.add_child(screen)
		screen.set_store(SaveStore.new("user://settings-premium-capture"))
		screen.set_language(lang)
		screen.enter({})
	for _i in 5:
		await process_frame
	var viewport_size: Vector2i = root.get_viewport().size
	var path := ProjectSettings.globalize_path("res://out/settings-premium-%s%s-%dx%d.png" % ["live-" if live else "", lang, viewport_size.x, viewport_size.y])
	var error := root.get_viewport().get_texture().get_image().save_png(path)
	print("SETTINGS_PREMIUM_CAPTURE %s %s" % [path, error])
	quit(0 if error == OK else 1)
