#!/usr/bin/env python3
import os
import base64
from svg_text_vector import render_title_banner

root = "/Users/alessiofantini/Documents/steam-circuit-padel-11m"
base_img_path = os.path.join(root, "scratch/suno_neon_1024.png")

with open(base_img_path, "rb") as f:
    b64_data = base64.b64encode(f.read()).decode("utf-8")

title_banner = render_title_banner(
    "NEON VELOCITY", center_x=512, center_y=905,
    scale=0.36, letter_spacing=13, stroke="#ffffff", stroke_width=9, accent_color="#00e5ff"
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

svg_path = os.path.join(root, "scratch/ost_vocal_neon_velocity.svg")
with open(svg_path, "w", encoding="utf-8") as f:
    f.write(svg_content)
print(f"Saved SVG to {svg_path}")

# Write GDScript rasterizer
gdscript_content = f"""@tool
extends SceneTree

func _init() -> void:
\tprint("[rasterize_neon_velocity] Starting rasterization...")
\tvar f := FileAccess.open("{svg_path}", FileAccess.READ)
\tif not f:
\t\tprinterr("Cannot open SVG: {svg_path}")
\t\tquit(1)
\t\treturn
\tvar svg_content := f.get_as_text()
\tf.close()
\tvar img := Image.new()
\tvar err := img.load_svg_from_string(svg_content, 1.0)
\tif err != OK:
\t\tprinterr("Failed to load SVG code: ", err)
\t\tquit(1)
\t\treturn
\tvar dest := "res://assets/images/jukebox_covers/ost_vocal_neon_velocity.png"
\tvar save_err := img.save_png(dest)
\tif save_err != OK:
\t\tprinterr("Failed to save PNG: ", save_err)
\t\tquit(1)
\t\treturn
\tprint("Saved ", dest, " size: ", img.get_width(), "x", img.get_height())
\tquit(0)
"""

rasterizer_path = os.path.join(root, "godot/tests/rasterize_neon_velocity.gd")
with open(rasterizer_path, "w", encoding="utf-8") as f:
    f.write(gdscript_content)
print(f"Created {rasterizer_path}")
