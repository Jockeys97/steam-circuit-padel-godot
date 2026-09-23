extends SceneTree
## Checks that every visible router Back button activates its declared return by click.

const Router := preload("res://src/ui/ScreenRouter.gd")
const BACK_SCREENS := [
	"arena", "characters", "modes", "help", "history", "challenges", "profile",
	"feedback", "drill", "settings",
]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS %s" % label)
	else:
		_failed += 1
		printerr("FAIL %s" % label)


func _find_back(node: Node) -> Button:
	if node is Button and node.name == "BackButton":
		return node as Button
	for child in node.get_children():
		var found := _find_back(child)
		if found != null:
			return found
	return null


func _run() -> void:
	var frame := Control.new()
	frame.size = Vector2(1280, 720)
	root.add_child(frame)
	var router: Control = Router.new()
	frame.add_child(router)
	var scenes: Dictionary = load("res://game/main_menu.gd").SCREEN_SCENES
	for id in scenes:
		router.register(String(id), load(String(scenes[id])) as PackedScene)
	await process_frame

	for id in BACK_SCREENS:
		_check(router.go_to(id), "%s mounts" % id)
		var screen: Node = router.active_screen()
		var back := _find_back(screen)
		var target := Router.back_target_of(id)
		_check(back != null and back.visible, "%s exposes its Back button" % id)
		if back == null:
			continue
		back.pressed.emit()
		_check(router.active_id() == target, "%s click routes to %s" % [id, target])

	_check(router.go_to("menu"), "menu mounts")
	var menu_back := _find_back(router.active_screen())
	_check(menu_back == null or not menu_back.visible, "root menu has no visible Back action")
	_check(router.go_to("result"), "result mounts")
	var result_back := _find_back(router.active_screen())
	_check(result_back == null or not result_back.visible, "result has no visible Back action")

	print("BACK_CLICK_AUDIT %s %d/%d" % ["PASS" if _failed == 0 else "FAIL", _passed, _passed + _failed])
	quit(1 if _failed > 0 else 0)
