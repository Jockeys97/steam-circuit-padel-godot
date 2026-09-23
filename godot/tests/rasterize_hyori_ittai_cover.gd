extends SceneTree

func _init() -> void:
	print("[hyori_ittai_rasterizer] Starting ThorVG render of Hyori Ittai cover...")
	var path: String = "res://../scratch/automata_svgs/ost_hyori_ittai_vocal.svg"
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		print("  ERROR: could not read SVG at: ", path)
		quit(1)
		return
	var svg_content: String = fa.get_as_text()
	fa.close()

	var img := Image.new()
	var err := img.load_svg_from_string(svg_content, 1.0)
	if err != OK:
		print("  ERROR: failed to parse SVG code: ", err)
		quit(1)
		return
	var dest_path: String = "res://assets/images/jukebox_covers/ost_hyori_ittai_vocal.png"
	var save_err := img.save_png(dest_path)
	if save_err == OK:
		print("  [SUCCESS] Rendered ", dest_path, " (", img.get_width(), "x", img.get_height(), ")")
	else:
		print("  ERROR saving PNG: ", save_err)
		quit(1)
		return
	print("[hyori_ittai_rasterizer] All done!")
	quit(0)
