#!/usr/bin/env python3
import os
import base64
import subprocess
from svg_text_vector import render_title_banner

def make_svg(base_img_path, title_text, accent_color, scale=0.35, letter_spacing=12):
    with open(base_img_path, "rb") as f:
        b64_data = base64.b64encode(f.read()).decode("utf-8")

    title_banner = render_title_banner(
        title_text, center_x=512, center_y=905,
        scale=scale, letter_spacing=letter_spacing, stroke="#ffffff", stroke_width=9, accent_color=accent_color
    )

    svg_content = f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <!-- Suno Cover Artwork -->
  <image href="data:image/png;base64,{b64_data}" width="1024" height="1024" />
  
  <!-- Subtle dark vignette at bottom for banner readability -->
  <defs>
    <linearGradient id="vignette" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="60%" stop-color="#000000" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0.85"/>
    </linearGradient>
  </defs>
  <rect y="650" width="1024" height="374" fill="url(#vignette)"/>

  <!-- Title Banner -->
  {title_banner}
</svg>"""
    return svg_content

def main():
    root = "/Users/alessiofantini/Documents/steam-circuit-padel-11m"
    covers = [
        {
            "id": "ost_vocal_break_point_riot",
            "img": os.path.join(root, "scratch/suno_break_point_1024.png"),
            "svg": os.path.join(root, "scratch/ost_vocal_break_point_riot.svg"),
            "dest": "res://assets/images/jukebox_covers/ost_vocal_break_point_riot.png",
            "title": "BREAK POINT RIOT",
            "accent": "#f43f5e",
            "scale": 0.35,
            "spacing": 12
        },
        {
            "id": "ost_vocal_reach_for_the_sun",
            "img": os.path.join(root, "scratch/suno_reach_sun_1024.png"),
            "svg": os.path.join(root, "scratch/ost_vocal_reach_for_the_sun.svg"),
            "dest": "res://assets/images/jukebox_covers/ost_vocal_reach_for_the_sun.png",
            "title": "REACH FOR THE SUN",
            "accent": "#f59e0b",
            "scale": 0.33,
            "spacing": 11
        }
    ]

    for item in covers:
        svg = make_svg(item["img"], item["title"], item["accent"], item["scale"], item["spacing"])
        with open(item["svg"], "w", encoding="utf-8") as f:
            f.write(svg)
        print(f"Generated {item['svg']}")

    # Create GDScript to rasterize both
    gdscript_content = """@tool
extends SceneTree

func _init() -> void:
\tprint("[rasterize_vocal_covers] Starting rasterization...")
"""
    for item in covers:
        svg_abs = item["svg"].replace("\\", "/")
        dest_res = item["dest"]
        gdscript_content += f"""\t_rasterize("{svg_abs}", "{dest_res}")\n"""

    gdscript_content += """\tprint("[rasterize_vocal_covers] Finished all covers successfully.")
\tquit(0)

func _rasterize(svg_abs_path: String, dest_res_path: String) -> void:
\tvar f := FileAccess.open(svg_abs_path, FileAccess.READ)
\tif not f:
\t\tprinterr("Cannot open SVG: ", svg_abs_path)
\t\tquit(1)
\t\treturn
\tvar svg_content := f.get_as_text()
\tf.close()
\tvar img := Image.new()
\tvar err := img.load_svg_from_string(svg_content, 1.0)
\tif err != OK:
\t\tprinterr("Failed to load SVG from string: ", svg_abs_path, " code: ", err)
\t\tquit(1)
\t\treturn
\tvar save_err := img.save_png(dest_res_path)
\tif save_err != OK:
\t\tprinterr("Failed to save PNG to: ", dest_res_path, " code: ", save_err)
\t\tquit(1)
\t\treturn
\tprint("Saved ", dest_res_path, " size: ", img.get_width(), "x", img.get_height())
"""

    gdscript_path = os.path.join(root, "godot/tests/rasterize_vocal_covers.gd")
    with open(gdscript_path, "w", encoding="utf-8") as f:
        f.write(gdscript_content)
    print(f"Created {gdscript_path}")

if __name__ == "__main__":
    main()
