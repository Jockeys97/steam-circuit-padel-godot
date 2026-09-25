#!/usr/bin/env python3
import os
import base64
from svg_text_vector import render_title_banner

base_img_path = "scratch/suno_1024.png"
with open(base_img_path, "rb") as f:
    b64_data = base64.b64encode(f.read()).decode("utf-8")

title_banner = render_title_banner(
    "OVERDRIVE LINE", center_x=512, center_y=905,
    scale=0.38, letter_spacing=14, stroke="#ffffff", stroke_width=9, accent_color="#f43f5e"
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

svg_path = "scratch/ost_vocal_overdrive_line.svg"
with open(svg_path, "w", encoding="utf-8") as f:
    f.write(svg_content)

print(f"Saved SVG to {svg_path}")
