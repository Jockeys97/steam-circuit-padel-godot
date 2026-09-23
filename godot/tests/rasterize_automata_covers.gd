extends SceneTree

const TRACK_MAP: Dictionary = {
	"ost_rays_of_rust": "res://../scratch/automata_svgs/ost_rays_of_rust.svg",
	"ost_weight_of_the_rally": "res://../scratch/automata_svgs/ost_weight_of_the_rally.svg",
	"ost_beautiful_duel": "res://../scratch/automata_svgs/ost_beautiful_duel.svg",
	"ost_memories_of_sand": "res://../scratch/automata_svgs/ost_memories_of_sand.svg",
	"ost_rebirth_of_hope": "res://../scratch/automata_svgs/ost_rebirth_of_hope.svg",
}

func _init() -> void:
	print("[batch_cover_rasterizer] Starting ThorVG render of 5 refined covers...")
	for tid in TRACK_MAP.keys():
		var tid_str: String = String(tid)
		var path: String = TRACK_MAP[tid]
		var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
		if fa == null:
			print("  ERROR: could not read SVG at: ", path)
			continue
		var svg_content: String = fa.get_as_text()
		fa.close()

		var img := Image.new()
		var err := img.load_svg_from_string(svg_content, 1.0)
		if err != OK:
			print("  ERROR: failed to parse SVG for ", tid_str, " code: ", err)
			continue
		var dest_path: String = "res://assets/images/jukebox_covers/" + tid_str + ".png"
		var save_err := img.save_png(dest_path)
		if save_err == OK:
			print("  [SUCCESS] Rendered ", dest_path, " (", img.get_width(), "x", img.get_height(), ")")
		else:
			print("  ERROR saving PNG for ", tid_str, " code: ", save_err)
	print("[batch_cover_rasterizer] All done!")
	quit()
