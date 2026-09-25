#!/usr/bin/env python3
"""
generate_menu_covers.py — Generates high-resolution 1024x1024 vector SVG covers
for all menu soundtracks and rasterizes them to PNG via Godot ThorVG.
"""

import os
import math
import random
from svg_text_vector import render_title_banner

OUT_SVG_DIR = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/menu_svgs"
os.makedirs(OUT_SVG_DIR, exist_ok=True)


def make_breeze_plaza_svg():
    title_svg = render_title_banner(
        "BREEZE PLAZA", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#ffffff", stroke_width=9, accent_color="#38bdf8"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="breeze_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="60%" stop-color="#bae6fd"/>
      <stop offset="100%" stop-color="#f0f9ff"/>
    </linearGradient>
    <linearGradient id="plaza_tiles" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#fef08a"/>
      <stop offset="50%" stop-color="#fde047"/>
      <stop offset="100%" stop-color="#eab308"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#breeze_sky)"/>
  <!-- Sun -->
  <circle cx="850" cy="180" r="80" fill="#fef08a" opacity="0.9"/>
  <circle cx="850" cy="180" r="110" fill="#fde047" opacity="0.25"/>
  <!-- Fluffy Clouds -->
  <ellipse cx="280" cy="240" rx="140" ry="50" fill="#ffffff" opacity="0.85"/>
  <ellipse cx="220" cy="220" rx="90" ry="60" fill="#ffffff" opacity="0.9"/>
  <ellipse cx="640" cy="310" rx="160" ry="55" fill="#ffffff" opacity="0.8"/>
  <!-- Plaza Ground -->
  <polygon points="0,580 1024,580 1024,1024 0,1024" fill="url(#plaza_tiles)"/>
  <line x1="0" y1="580" x2="1024" y2="580" stroke="#ca8a04" stroke-width="4"/>
  <!-- Grid Lines -->
  <line x1="512" y1="580" x2="512" y2="1024" stroke="#ca8a04" stroke-width="2" opacity="0.5"/>
  <line x1="256" y1="580" x2="128" y2="1024" stroke="#ca8a04" stroke-width="2" opacity="0.5"/>
  <line x1="768" y1="580" x2="896" y2="1024" stroke="#ca8a04" stroke-width="2" opacity="0.5"/>
  <!-- Palm Trees -->
  <path d="M 220,580 Q 200,480 180,400" stroke="#78350f" stroke-width="12" fill="none" stroke-linecap="round"/>
  <circle cx="180" cy="400" r="70" fill="#22c55e" opacity="0.85"/>
  <path d="M 800,580 Q 820,490 840,420" stroke="#78350f" stroke-width="12" fill="none" stroke-linecap="round"/>
  <circle cx="840" cy="420" r="65" fill="#16a34a" opacity="0.85"/>
  {title_svg}
</svg>"""


def make_sacred_spring_svg():
    title_svg = render_title_banner(
        "SACRED SPRING", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#f0fdf4", stroke_width=9, accent_color="#22c55e"
    )
    rng = random.Random(77)
    fairies = []
    for _ in range(35):
        fx = rng.randint(150, 870)
        fy = rng.randint(150, 700)
        fr = rng.uniform(3.0, 7.0)
        color = rng.choice(["#f472b6", "#38bdf8", "#fde047", "#a7f3d0"])
        fairies.append(f'<circle cx="{fx}" cy="{fy}" r="{fr:.1f}" fill="{color}" opacity="0.9"/>')
        fairies.append(f'<circle cx="{fx}" cy="{fy}" r="{fr*2.4:.1f}" fill="{color}" opacity="0.25"/>')
    fairies_str = "\n".join(fairies)
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="cavern_bg" cx="50%" cy="50%" r="60%">
      <stop offset="0%" stop-color="#064e3b"/>
      <stop offset="60%" stop-color="#022c22"/>
      <stop offset="100%" stop-color="#021510"/>
    </radialGradient>
    <linearGradient id="pool_water" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#34d399"/>
      <stop offset="50%" stop-color="#059669"/>
      <stop offset="100%" stop-color="#047857"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#cavern_bg)"/>
  <!-- Ancient Stone Arch -->
  <path d="M 260,700 C 260,300 764,300 764,700" stroke="#065f46" stroke-width="40" fill="none" opacity="0.7"/>
  <path d="M 300,700 C 300,340 724,340 724,700" stroke="#047857" stroke-width="15" fill="none" opacity="0.5"/>
  <!-- Magical Pool -->
  <ellipse cx="512" cy="680" rx="360" ry="120" fill="url(#pool_water)" stroke="#6ee7b7" stroke-width="4"/>
  <ellipse cx="512" cy="680" rx="280" ry="80" fill="#6ee7b7" opacity="0.25"/>
  <!-- Fairies -->
  {fairies_str}
  {title_svg}
</svg>"""


def make_ancient_sanctum_svg():
    title_svg = render_title_banner(
        "ANCIENT SANCTUM", center_x=512, center_y=900,
        scale=0.36, letter_spacing=13, stroke="#f8fafc", stroke_width=9, accent_color="#38bdf8"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="deep_space" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#030712"/>
      <stop offset="50%" stop-color="#0b1329"/>
      <stop offset="100%" stop-color="#020617"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#deep_space)"/>
  <!-- Giant Ring-World Curve (Halo Style) -->
  <path d="M 512,-300 C 650,200 650,700 512,1200" stroke="#38bdf8" stroke-width="26" fill="none" opacity="0.55"/>
  <path d="M 512,-300 C 650,200 650,700 512,1200" stroke="#ffffff" stroke-width="8" fill="none" opacity="0.85"/>
  <!-- Monolithic Pillars -->
  <polygon points="260,350 340,300 340,820 260,820" fill="#1e293b" stroke="#38bdf8" stroke-width="2"/>
  <polygon points="764,350 684,300 684,820 764,820" fill="#1e293b" stroke="#38bdf8" stroke-width="2"/>
  <!-- Holographic Beam in Center -->
  <polygon points="492,0 532,0 550,820 474,820" fill="#0284c7" opacity="0.25"/>
  <line x1="512" y1="0" x2="512" y2="820" stroke="#bae6fd" stroke-width="3" opacity="0.8"/>
  {title_svg}
</svg>"""


def make_rainy_atrium_svg():
    title_svg = render_title_banner(
        "RAINY ATRIUM", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#fef3c7", stroke_width=9, accent_color="#f59e0b"
    )
    rng = random.Random(88)
    drops = []
    for _ in range(80):
        dx = rng.randint(40, 980)
        dy = rng.randint(40, 750)
        dl = rng.randint(15, 35)
        drops.append(f'<line x1="{dx}" y1="{dy}" x2="{dx-4}" y2="{dy+dl}" stroke="#93c5fd" stroke-width="1.8" opacity="0.45"/>')
    drops_str = "\n".join(drops)
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="rain_bg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1e293b"/>
      <stop offset="60%" stop-color="#334155"/>
      <stop offset="100%" stop-color="#1e1b4b"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#rain_bg)"/>
  <!-- Window Panes -->
  <rect x="120" y="80" width="784" height="660" rx="16" fill="#0f172a" opacity="0.6" stroke="#475569" stroke-width="8"/>
  <line x1="512" y1="80" x2="512" y2="740" stroke="#475569" stroke-width="8"/>
  <line x1="120" y1="410" x2="904" y2="410" stroke="#475569" stroke-width="8"/>
  {drops_str}
  <!-- Steaming Coffee Cup on Sill -->
  <rect x="460" y="660" width="104" height="70" rx="8" fill="#f59e0b" stroke="#78350f" stroke-width="3"/>
  <path d="M 500,645 Q 512,625 500,610" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.6"/>
  <path d="M 524,645 Q 536,625 524,610" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.6"/>
  {title_svg}
</svg>"""


def make_chronicle_winds_svg():
    title_svg = render_title_banner(
        "TIMELESS WINDS", center_x=512, center_y=900,
        scale=0.36, letter_spacing=13, stroke="#fef9c3", stroke_width=9, accent_color="#eab308"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="twilight_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1e1b4b"/>
      <stop offset="40%" stop-color="#431407"/>
      <stop offset="75%" stop-color="#b45309"/>
      <stop offset="100%" stop-color="#fef08a"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#twilight_sky)"/>
  <!-- Giant Compass Gear Silhouette in Sky -->
  <circle cx="512" cy="380" r="220" stroke="#fef08a" stroke-width="6" fill="none" opacity="0.35"/>
  <circle cx="512" cy="380" r="160" stroke="#fde047" stroke-width="3" stroke-dasharray="12 8" fill="none" opacity="0.45"/>
  <!-- Clock Pendulum Line -->
  <line x1="512" y1="160" x2="512" y2="520" stroke="#fef08a" stroke-width="4" opacity="0.5"/>
  <circle cx="512" cy="520" r="28" fill="#fde047" opacity="0.6"/>
  <!-- Grassy Cliff Horizon -->
  <path d="M 0,680 Q 340,600 700,660 T 1024,640 L 1024,1024 L 0,1024 Z" fill="#14532d"/>
  {title_svg}
</svg>"""


def make_subaquatic_drift_svg():
    title_svg = render_title_banner(
        "CORAL DRIFT", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#ecfeff", stroke_width=9, accent_color="#06b6d4"
    )
    rng = random.Random(99)
    bubbles = []
    for _ in range(40):
        bx = rng.randint(80, 940)
        by = rng.randint(100, 780)
        br = rng.uniform(4.0, 14.0)
        bubbles.append(f'<circle cx="{bx}" cy="{by}" r="{br:.1f}" stroke="#a5f3fc" stroke-width="1.5" fill="#a5f3fc" fill-opacity="0.15"/>')
    bubbles_str = "\n".join(bubbles)
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="aqua_bg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#083344"/>
      <stop offset="50%" stop-color="#0e7490"/>
      <stop offset="100%" stop-color="#042f2e"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#aqua_bg)"/>
  <!-- Sun Rays Piercing Water -->
  <polygon points="200,0 280,0 480,800 360,800" fill="#67e8f9" opacity="0.12"/>
  <polygon points="500,0 580,0 720,800 620,800" fill="#67e8f9" opacity="0.15"/>
  <polygon points="750,0 830,0 950,800 860,800" fill="#67e8f9" opacity="0.10"/>
  {bubbles_str}
  <!-- Coral Silhouettes at Bottom -->
  <path d="M 80,820 Q 120,680 180,680 Q 240,680 280,820 Z" fill="#f43f5e" opacity="0.75"/>
  <path d="M 720,820 Q 780,640 840,640 Q 900,640 940,820 Z" fill="#fb923c" opacity="0.75"/>
  {title_svg}
</svg>"""


def make_northern_aurora_svg():
    title_svg = render_title_banner(
        "NORTHERN FROST", center_x=512, center_y=900,
        scale=0.36, letter_spacing=13, stroke="#f0fdfa", stroke_width=9, accent_color="#2dd4bf"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="aurora_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#022c22"/>
      <stop offset="50%" stop-color="#064e3b"/>
      <stop offset="100%" stop-color="#020617"/>
    </linearGradient>
    <linearGradient id="aurora_ribbon" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#2dd4bf" stop-opacity="0"/>
      <stop offset="30%" stop-color="#2dd4bf" stop-opacity="0.8"/>
      <stop offset="70%" stop-color="#a855f7" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="#a855f7" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#aurora_sky)"/>
  <!-- Aurora Borealis Curving Ribbons -->
  <path d="M 0,220 Q 300,100 600,280 T 1024,200 L 1024,450 Q 600,380 300,500 L 0,450 Z" fill="url(#aurora_ribbon)" opacity="0.65"/>
  <!-- Mountain Peaks -->
  <polygon points="120,680 340,380 560,680" fill="#0f172a" stroke="#e2e8f0" stroke-width="2"/>
  <polygon points="480,680 720,320 960,680" fill="#1e293b" stroke="#e2e8f0" stroke-width="2"/>
  <polygon points="340,380 390,450 340,430 290,450" fill="#ffffff"/>
  <polygon points="720,320 780,410 720,380 660,410" fill="#ffffff"/>
  {title_svg}
</svg>"""


def make_champions_pavilion_svg():
    title_svg = render_title_banner(
        "CHAMPIONS HALL", center_x=512, center_y=900,
        scale=0.36, letter_spacing=13, stroke="#fef08a", stroke_width=9, accent_color="#eab308"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="arena_bg" cx="50%" cy="40%" r="60%">
      <stop offset="0%" stop-color="#450a0a"/>
      <stop offset="60%" stop-color="#1c0404"/>
      <stop offset="100%" stop-color="#0a0202"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#arena_bg)"/>
  <!-- Crossed Spotlight Beams -->
  <polygon points="0,0 120,0 800,820 680,820" fill="#fef08a" opacity="0.18"/>
  <polygon points="1024,0 904,0 224,820 344,820" fill="#fef08a" opacity="0.18"/>
  <!-- Trophy Pedestal -->
  <polygon points="432,600 592,600 620,780 404,780" fill="#78350f" stroke="#ca8a04" stroke-width="4"/>
  <!-- Golden Trophy Cup -->
  <path d="M 462,480 L 562,480 L 542,560 L 482,560 Z" fill="#eab308" stroke="#fef08a" stroke-width="4"/>
  <circle cx="512" cy="450" r="30" fill="#facc15" stroke="#fef08a" stroke-width="3"/>
  <path d="M 442,490 C 420,510 420,540 462,540" stroke="#facc15" stroke-width="6" fill="none"/>
  <path d="M 582,490 C 604,510 604,540 562,540" stroke="#facc15" stroke-width="6" fill="none"/>
  {title_svg}
</svg>"""


def make_orbital_vanguard_svg():
    title_svg = render_title_banner(
        "ORBITAL VISTA", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#ecfeff", stroke_width=9, accent_color="#06b6d4"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="space_dark" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#020617"/>
      <stop offset="60%" stop-color="#041f38"/>
      <stop offset="100%" stop-color="#020d1a"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#space_dark)"/>
  <!-- Glowing Blue Planet Horizon -->
  <circle cx="512" cy="1150" r="680" fill="#0284c7" stroke="#38bdf8" stroke-width="6"/>
  <circle cx="512" cy="1150" r="700" fill="none" stroke="#7dd3fc" stroke-width="3" opacity="0.6"/>
  <!-- Space Station Window Frame -->
  <polygon points="0,0 200,0 120,820 0,820" fill="#0f172a" stroke="#334155" stroke-width="4"/>
  <polygon points="1024,0 824,0 904,820 1024,820" fill="#0f172a" stroke="#334155" stroke-width="4"/>
  <line x1="200" y1="280" x2="824" y2="280" stroke="#38bdf8" stroke-width="3" opacity="0.5"/>
  {title_svg}
</svg>"""


def make_third_strike_svg():
    title_svg = render_title_banner(
        "STREET SELECT", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#fff1f2", stroke_width=9, accent_color="#f43f5e"
    )
    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="street_bg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0f0f17"/>
      <stop offset="50%" stop-color="#241026"/>
      <stop offset="100%" stop-color="#0a0a0f"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#street_bg)"/>
  <!-- 90s Spray Graffiti Shapes -->
  <polygon points="180,240 420,180 380,480 140,420" fill="#f43f5e" opacity="0.6" stroke="#fb7185" stroke-width="4"/>
  <polygon points="620,260 880,200 840,520 580,440" fill="#38bdf8" opacity="0.6" stroke="#7dd3fc" stroke-width="4"/>
  <circle cx="512" cy="420" r="140" fill="#facc15" opacity="0.75" stroke="#fde047" stroke-width="6"/>
  <!-- Cassette / Boombox Grid -->
  <rect x="362" y="360" width="300" height="160" rx="16" fill="#18181b" stroke="#f43f5e" stroke-width="6"/>
  <circle cx="442" cy="440" r="36" fill="#27272a" stroke="#ffffff" stroke-width="4"/>
  <circle cx="582" cy="440" r="36" fill="#27272a" stroke="#ffffff" stroke-width="4"/>
  <rect x="478" y="425" width="68" height="30" fill="#f43f5e" rx="4"/>
  {title_svg}
</svg>"""


def main():
    generators = [
        ("ost_menu_breeze_plaza", make_breeze_plaza_svg),
        ("ost_menu_sacred_spring", make_sacred_spring_svg),
        ("ost_menu_ancient_sanctum", make_ancient_sanctum_svg),
        ("ost_menu_rainy_atrium", make_rainy_atrium_svg),
        ("ost_menu_chronicle_winds", make_chronicle_winds_svg),
        ("ost_menu_subaquatic_drift", make_subaquatic_drift_svg),
        ("ost_menu_northern_aurora", make_northern_aurora_svg),
        ("ost_menu_champions_pavilion", make_champions_pavilion_svg),
        ("ost_menu_orbital_vanguard", make_orbital_vanguard_svg),
        ("ost_menu_third_strike", make_third_strike_svg),
    ]

    print("Generating 10 SVG vector covers...")
    for tid, gen_fn in generators:
        svg_content = gen_fn()
        svg_path = os.path.join(OUT_SVG_DIR, f"{tid}.svg")
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write(svg_content)
        print(f"  [OK] Saved {tid}.svg ({len(svg_content)} bytes)")

    # GDScript rasterizer
    gd_script = """extends SceneTree

func _init() -> void:
	print("[menu_cover_rasterizer_part2] Rendering 10 new covers via ThorVG...")
	var tracks := [
		"ost_menu_breeze_plaza",
		"ost_menu_sacred_spring",
		"ost_menu_ancient_sanctum",
		"ost_menu_rainy_atrium",
		"ost_menu_chronicle_winds",
		"ost_menu_subaquatic_drift",
		"ost_menu_northern_aurora",
		"ost_menu_champions_pavilion",
		"ost_menu_orbital_vanguard",
		"ost_menu_third_strike"
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
	print("[menu_cover_rasterizer_part2] All 10 covers successfully rasterized!")
	quit(0)
"""
    rasterizer_path = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/godot/tests/rasterize_menu_covers_part2.gd"
    with open(rasterizer_path, "w", encoding="utf-8") as f:
        f.write(gd_script)
    print("Rasterizer script ready at godot/tests/rasterize_menu_covers_part2.gd")


if __name__ == "__main__":
    main()
