import os
import math
import random
from svg_text_vector import render_title_banner

TEMP_SVG_DIR = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/automata_svgs"
os.makedirs(TEMP_SVG_DIR, exist_ok=True)

def make_hyori_ittai_svg():
    title_svg = render_title_banner(
        "HYORI ITTAI", center_x=512, center_y=900,
        scale=0.38, letter_spacing=15, stroke="#fff8e7", stroke_width=9, accent_color="#f1c40f"
    )

    # Stars on the dark side (x: 512 to 1024)
    rng = random.Random(777)
    stars = []
    for _ in range(60):
        sx = rng.randint(520, 1000)
        sy = rng.randint(40, 750)
        sr = rng.uniform(1.2, 3.5)
        so = rng.uniform(0.4, 0.95)
        color = rng.choice(["#ffffff", "#74b9ff", "#a29bfe"])
        stars.append(f'<circle cx="{sx}" cy="{sy}" r="{sr:.1f}" fill="{color}" opacity="{so:.2f}"/>')
    stars_str = "\n".join(stars)

    # Golden light particles on the solar side (x: 0 to 512)
    motes = []
    for _ in range(60):
        mx = rng.randint(40, 500)
        my = rng.randint(40, 750)
        mr = rng.uniform(1.5, 4.0)
        mo = rng.uniform(0.35, 0.9)
        color = rng.choice(["#ffd166", "#fff9d2", "#f39c12"])
        motes.append(f'<circle cx="{mx}" cy="{my}" r="{mr:.1f}" fill="{color}" opacity="{mo:.2f}"/>')
    motes_str = "\n".join(motes)

    # Solar flare rays on left
    sunbeams = []
    for deg in range(120, 240, 15):
        rad = math.radians(deg)
        x2 = 512 + 600 * math.cos(rad)
        y2 = 440 + 600 * math.sin(rad)
        sunbeams.append(f'<polygon points="512,440 {x2:.1f},{y2-40:.1f} {x2:.1f},{y2+40:.1f}" fill="#ffd166" opacity="0.12"/>')
    sunbeams_str = "\n".join(sunbeams)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Light & Dark Split Backgrounds -->
    <linearGradient id="light_sky" x1="100%" y1="50%" x2="0%" y2="50%">
      <stop offset="0%" stop-color="#e67e22"/>
      <stop offset="40%" stop-color="#f39c12"/>
      <stop offset="70%" stop-color="#f1c40f"/>
      <stop offset="100%" stop-color="#fffae6"/>
    </linearGradient>
    <linearGradient id="dark_sky" x1="0%" y1="50%" x2="100%" y2="50%">
      <stop offset="0%" stop-color="#1e0c2b"/>
      <stop offset="40%" stop-color="#120824"/>
      <stop offset="80%" stop-color="#090414"/>
      <stop offset="100%" stop-color="#04020a"/>
    </linearGradient>

    <!-- Solar Eclipse Corona -->
    <radialGradient id="solar_corona" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="40%" stop-color="#ffd166" stop-opacity="0.9"/>
      <stop offset="70%" stop-color="#f39c12" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#e74c3c" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="lunar_corona" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#74b9ff" stop-opacity="0.8"/>
      <stop offset="50%" stop-color="#0984e3" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#0c2461" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_split" cx="50%" cy="50%" r="70%">
      <stop offset="60%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#06020c" stop-opacity="0.85"/>
    </radialGradient>
  </defs>

  <!-- Left Side: Radiant Golden Light -->
  <rect x="0" y="0" width="512" height="1024" fill="url(#light_sky)"/>
  <!-- Right Side: Deep Cosmic Void -->
  <rect x="512" y="0" width="512" height="1024" fill="url(#dark_sky)"/>

  <!-- Stars on Right Side -->
  {stars_str}

  <!-- Sunbeams on Left Side -->
  {sunbeams_str}
  {motes_str}

  <!-- Center Eclipse / Dual Celestial Sphere (512, 440) -->
  <!-- Corona Glow -->
  <circle cx="512" cy="440" r="300" fill="url(#solar_corona)" opacity="0.6"/>
  <circle cx="512" cy="440" r="240" fill="url(#lunar_corona)" opacity="0.7"/>

  <!-- Left Sun half (Golden Fire) -->
  <path d="M 512,250 A 190,190 0 0,0 512,630 Z" fill="#ffd166" stroke="#ffffff" stroke-width="4"/>
  <!-- Right Moon half (Pitch Black with Azure Glow) -->
  <path d="M 512,250 A 190,190 0 0,1 512,630 Z" fill="#0c0717" stroke="#74b9ff" stroke-width="4"/>
  <!-- Blinding White Center Boundary Line -->
  <line x1="512" y1="240" x2="512" y2="640" stroke="#ffffff" stroke-width="6"/>

  <!-- Double Helix Energy Ribbons (Gold & Cyan) Intertwining -->
  <!-- Golden Ribbon from Light to Center -->
  <path d="M 180,780 Q 320,680 440,560 Q 512,480 512,440" stroke="#f1c40f" stroke-width="6" fill="none" opacity="0.85" stroke-linecap="round"/>
  <!-- Cyan Ribbon from Darkness to Center -->
  <path d="M 844,780 Q 704,680 584,560 Q 512,480 512,440" stroke="#00cec9" stroke-width="6" fill="none" opacity="0.85" stroke-linecap="round"/>

  <!-- Jagged Cliff Ledge at Bottom -->
  <polygon points="0,740 380,720 512,710 644,720 1024,740 1024,1024 0,1024" fill="#0f0c18"/>
  <line x1="0" y1="740" x2="512" y2="710" stroke="#f39c12" stroke-width="3"/>
  <line x1="512" y1="710" x2="1024" y2="740" stroke="#74b9ff" stroke-width="3"/>

  <!-- Dual Silhouette Figures Standing Back-to-Back at Center (512, 708) -->
  <!-- Left Figure: Solar Hero (Looking Left) -->
  <g transform="translate(476, 645) scale(0.65)">
    <!-- Head & spiky hair silhouette -->
    <circle cx="0" cy="-60" r="16" fill="#ffd166"/>
    <polygon points="-8,-75 0,-92 10,-72" fill="#ffd166"/>
    <polygon points="-16,-65 -28,-75 -10,-55" fill="#ffd166"/>
    <!-- Cloak & Body -->
    <path d="M -8,-44 L 8,-44 L 14,30 L -25,50 Z" fill="#ffd166"/>
    <rect x="-18" y="45" width="10" height="45" rx="3" fill="#ffd166"/>
    <rect x="-2" y="45" width="10" height="45" rx="3" fill="#ffd166"/>
  </g>

  <!-- Right Figure: Shadow Guardian (Looking Right) -->
  <g transform="translate(548, 645) scale(0.65)">
    <!-- Head & wild fluffy hair silhouette -->
    <circle cx="0" cy="-60" r="16" fill="#74b9ff"/>
    <polygon points="8,-75 0,-92 -10,-72" fill="#74b9ff"/>
    <polygon points="16,-65 28,-75 10,-55" fill="#74b9ff"/>
    <!-- Cloak & Body -->
    <path d="M -8,-44 L 8,-44 L 25,50 L -14,30 Z" fill="#74b9ff"/>
    <rect x="-8" y="45" width="10" height="45" rx="3" fill="#74b9ff"/>
    <rect x="8" y="45" width="10" height="45" rx="3" fill="#74b9ff"/>
  </g>

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_split)" pointer-events="none"/>
</svg>"""

def main():
    print("=== Generating Hyori Ittai Scenic Cover SVG ===")
    svg_content = make_hyori_ittai_svg()
    svg_path = os.path.join(TEMP_SVG_DIR, "ost_hyori_ittai_vocal.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg_content)
    print(f"  [OK] Generated ost_hyori_ittai_vocal.svg ({len(svg_content)} bytes)")

    # GDScript batch rasterizer for Hyori Ittai
    gd_script = """extends SceneTree

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
"""

    rasterizer_path = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/godot/tests/rasterize_hyori_ittai_cover.gd"
    with open(rasterizer_path, "w", encoding="utf-8") as f:
        f.write(gd_script)
    print("Rasterizer script ready.")

if __name__ == "__main__":
    main()
