extends SceneTree
func _initialize() -> void:
	var theme: Theme = load("res://src/ui/theme/padel_theme.tres")
	print("theme=", theme)
	if theme != null:
		print("colors=", theme.get_color_list("Palette").size())
		for key in ["touch_button_bg", "deck_hit_fill", "replay_banner", "osk_scrim"]:
			print("  has ", key, " = ", theme.has_color(key, "Palette"))
	quit(0)
