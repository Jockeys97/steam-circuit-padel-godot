extends SceneTree

const Router := preload("res://src/ui/ScreenRouter.gd")
const ScreenScene := preload("res://src/ui/screens/ProfileScreen.tscn")
const PlaceholderScene := preload("res://src/ui/PlaceholderScreen.tscn")
const SaveStore := preload("res://src/save/save_store.gd")
const Locale := preload("res://src/locale/locale.gd")
const UiStrings := preload("res://src/ui/UiStrings.gd")

var _router: Node

func _initialize() -> void:
	_run()

func _run() -> void:
	var store := SaveStore.new("user://probe-profile")
	_router = Router.new()
	root.add_child(_router)
	for id in Router.ids():
		_router.register(String(id), PlaceholderScene)
	_router.register("profile", ScreenScene)
	_router.go_to("profile", {"store": store})
	await process_frame
	await process_frame
	var screen: Node = _router.active_screen()
	print("screen=", screen)
	print("lang=", Locale.current_lang(), " t=", UiStrings.t("profileSeasons"))
	print("labels before=", screen.stat_labels())
	Locale.set_lang("en")
	print("after set_lang lang=", Locale.current_lang(), " t=", UiStrings.t("profileSeasons"))
	screen.refresh()
	print("labels after=", screen.stat_labels())
	print("Stat1 children=", screen.find_children("Stat1", "", true, false))
	var stat: Node = screen.find_child("Stat1", true, false)
	if stat != null:
		print("Stat1 class=", stat.get_class(), " children=", stat.get_children().map(func(n: Node) -> String: return "%s:%s" % [n.name, n.get_class()]))
	print("probe done")
	quit(0)
