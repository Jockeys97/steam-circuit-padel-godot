@tool
extends SceneTree

func _init() -> void:
	print("[rasterize_vocal_covers] Starting rasterization...")
	_rasterize("/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/ost_vocal_break_point_riot.svg", "res://assets/images/jukebox_covers/ost_vocal_break_point_riot.png")
	_rasterize("/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/ost_vocal_reach_for_the_sun.svg", "res://assets/images/jukebox_covers/ost_vocal_reach_for_the_sun.png")
	print("[rasterize_vocal_covers] Finished all covers successfully.")
	quit(0)

func _rasterize(svg_abs_path: String, dest_res_path: String) -> void:
	var f := FileAccess.open(svg_abs_path, FileAccess.READ)
	if not f:
		printerr("Cannot open SVG: ", svg_abs_path)
		quit(1)
		return
	var svg_content := f.get_as_text()
	f.close()
	var img := Image.new()
	var err := img.load_svg_from_string(svg_content, 1.0)
	if err != OK:
		printerr("Failed to load SVG from string: ", svg_abs_path, " code: ", err)
		quit(1)
		return
	var save_err := img.save_png(dest_res_path)
	if save_err != OK:
		printerr("Failed to save PNG to: ", dest_res_path, " code: ", save_err)
		quit(1)
		return
	print("Saved ", dest_res_path, " size: ", img.get_width(), "x", img.get_height())
