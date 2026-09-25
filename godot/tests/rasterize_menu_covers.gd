extends SceneTree

func _init() -> void:
	print("[menu_cover_rasterizer] Rendering 5 covers via ThorVG...")
	var tracks := [
		"ost_menu_velvet_lounge",
		"ost_menu_grand_touring",
		"ost_menu_astral_solitude",
		"ost_menu_dearly_reminiscent",
		"ost_menu_cyber_terminal"
	]
	for tid in tracks:
		var svg_path: String = "res://../scratch/menu_svgs/" + tid + ".svg"
		var fa: FileAccess = FileAccess.open(svg_path, FileAccess.READ)
		if fa == null:
			print("  ERROR reading: ", svg_path)
			quit(1)
			return
		var content: String = fa.get_as_text()
		fa.close()

		var img := Image.new()
		var err := img.load_svg_from_string(content, 1.0)
		if err != OK:
			print("  ERROR parsing SVG: ", tid, " code: ", err)
			quit(1)
			return
		var dest: String = "res://assets/images/jukebox_covers/" + tid + ".png"
		var save_err := img.save_png(dest)
		if save_err == OK:
			print("  [SUCCESS] Rendered ", dest, " (", img.get_width(), "x", img.get_height(), ")")
		else:
			print("  ERROR saving: ", dest, " code: ", save_err)
			quit(1)
			return
	print("[menu_cover_rasterizer] All 5 covers successfully rasterized!")
	quit(0)
