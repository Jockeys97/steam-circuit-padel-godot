@tool
extends SceneTree

func _init() -> void:
	print("[rasterize_neon_velocity] Starting rasterization...")
	var f := FileAccess.open("/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/ost_vocal_neon_velocity.svg", FileAccess.READ)
	if not f:
		printerr("Cannot open SVG: /Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/ost_vocal_neon_velocity.svg")
		quit(1)
		return
	var svg_content := f.get_as_text()
	f.close()
	var img := Image.new()
	var err := img.load_svg_from_string(svg_content, 1.0)
	if err != OK:
		printerr("Failed to load SVG code: ", err)
		quit(1)
		return
	var dest := "res://assets/images/jukebox_covers/ost_vocal_neon_velocity.png"
	var save_err := img.save_png(dest)
	if save_err != OK:
		printerr("Failed to save PNG: ", save_err)
		quit(1)
		return
	print("Saved ", dest, " size: ", img.get_width(), "x", img.get_height())
	quit(0)
