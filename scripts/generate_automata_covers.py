import os
import math
import random
from svg_text_vector import render_title_banner

TEMP_SVG_DIR = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/automata_svgs"
os.makedirs(TEMP_SVG_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. RAYS OF RUST
# -------------------------------------------------------------
def make_rays_of_rust_svg():
    title_svg = render_title_banner(
        "RAYS OF RUST", center_x=512, center_y=900,
        scale=0.42, letter_spacing=15, stroke="#fff8e7", stroke_width=9, accent_color="#d6b268"
    )

    beams = []
    for angle, opacity in [(15, 0.12), (25, 0.18), (35, 0.15), (45, 0.22), (55, 0.14), (65, 0.09)]:
        rad = math.radians(angle)
        dx = 1400 * math.cos(rad)
        dy = 1400 * math.sin(rad)
        beams.append(f'<polygon points="0,0 {dx},{dy} {dx+120},{dy+60} 0,0" fill="url(#sunray_grad)" opacity="{opacity}"/>')
    beams_str = "\n".join(beams)

    motes = []
    rng = random.Random(42)
    for _ in range(60):
        mx = rng.randint(60, 960)
        my = rng.randint(100, 850)
        mr = rng.uniform(1.5, 4.5)
        mo = rng.uniform(0.3, 0.85)
        motes.append(f'<circle cx="{mx}" cy="{my}" r="{mr:.1f}" fill="#ffeaa7" opacity="{mo:.2f}"/>')
    motes_str = "\n".join(motes)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="sky_grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#2a332d"/>
      <stop offset="40%" stop-color="#3d493e"/>
      <stop offset="70%" stop-color="#7a7f64"/>
      <stop offset="100%" stop-color="#9a8c6e"/>
    </linearGradient>
    <linearGradient id="sunray_grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fff6cc" stop-opacity="0.9"/>
      <stop offset="60%" stop-color="#ffdc82" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#e8bf56" stop-opacity="0.0"/>
    </linearGradient>
    <linearGradient id="metal_rust" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#22201d"/>
      <stop offset="40%" stop-color="#4a3b32"/>
      <stop offset="70%" stop-color="#6e4d36"/>
      <stop offset="100%" stop-color="#2b201a"/>
    </linearGradient>
    <linearGradient id="moss_stone" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#323b30"/>
      <stop offset="100%" stop-color="#1e241d"/>
    </linearGradient>
    <radialGradient id="sun_glow" cx="10%" cy="10%" r="50%">
      <stop offset="0%" stop-color="#fff8d4" stop-opacity="0.85"/>
      <stop offset="40%" stop-color="#ffd875" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#c49b45" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette" cx="50%" cy="50%" r="70%">
      <stop offset="60%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#0c0e0c" stop-opacity="0.75"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#sky_grad)"/>
  <circle cx="80" cy="80" r="420" fill="url(#sun_glow)"/>

  <polygon points="120,450 160,280 220,280 250,450" fill="#2b332b" opacity="0.4"/>
  <polygon points="720,520 760,210 820,210 850,520" fill="#242b24" opacity="0.5"/>
  <polygon points="840,480 870,310 910,310 930,480" fill="#1d221d" opacity="0.4"/>

  <path d="M 0,220 L 350,140 L 380,180 L 0,280 Z" fill="url(#metal_rust)"/>
  <path d="M 280,150 L 310,650 L 260,650 L 240,165 Z" fill="#2e2520"/>

  <rect x="420" y="240" width="220" height="520" fill="url(#moss_stone)"/>
  <circle cx="530" cy="380" r="85" fill="#1b1d19" stroke="#7a6245" stroke-width="8"/>
  <circle cx="530" cy="380" r="76" fill="none" stroke="#9e8460" stroke-width="2" stroke-dasharray="6,8"/>
  <line x1="530" y1="380" x2="575" y2="340" stroke="#cbb28d" stroke-width="6" stroke-linecap="round"/>
  <line x1="530" y1="380" x2="510" y2="430" stroke="#8c775a" stroke-width="5" stroke-linecap="round"/>
  <path d="M 440,240 Q 460,350 430,480 Q 450,560 425,680" stroke="#52614a" stroke-width="12" fill="none"/>
  <path d="M 590,320 Q 620,440 600,560 Q 635,620 630,720" stroke="#46543f" stroke-width="14" fill="none"/>
  <path d="M 470,520 C 470,490 510,490 510,520 L 510,610 L 470,610 Z" fill="#121512"/>
  <path d="M 550,520 C 550,490 590,490 590,520 L 590,610 L 550,610 Z" fill="#121512"/>

  {beams_str}

  <g transform="translate(180, 780)">
    <circle cx="0" cy="0" r="140" fill="url(#metal_rust)"/>
    <circle cx="0" cy="0" r="70" fill="#181a17"/>
    <circle cx="0" cy="0" r="40" fill="#2d2822"/>
    <rect x="-18" y="-160" width="36" height="32" fill="#523927"/>
    <rect x="-18" y="128" width="36" height="32" fill="#523927"/>
    <rect x="-160" y="-18" width="32" height="36" fill="#523927"/>
    <rect x="128" y="-18" width="32" height="36" fill="#523927"/>
    <rect x="-115" y="-115" width="32" height="32" transform="rotate(45)" fill="#523927"/>
    <rect x="85" y="85" width="32" height="32" transform="rotate(45)" fill="#523927"/>
    <rect x="-115" y="85" width="32" height="32" transform="rotate(-45)" fill="#523927"/>
    <rect x="85" y="-115" width="32" height="32" transform="rotate(-45)" fill="#523927"/>
    <path d="M -80,-100 Q -40,-20 -90,60 Q -60,110 -10,130" stroke="#5a694d" stroke-width="8" fill="none"/>
  </g>

  <polygon points="0,740 1024,700 1024,1024 0,1024" fill="#191c18"/>
  <polygon points="0,780 480,750 620,830 0,910" fill="#222720"/>
  <polygon points="520,770 1024,740 1024,880 460,860" fill="#20241e"/>

  <g transform="translate(680, 770)">
    <path d="M 0,60 Q 15,20 10,-30" stroke="#485c3b" stroke-width="4" fill="none"/>
    <ellipse cx="0" cy="-35" rx="14" ry="32" fill="#ffffff" transform="rotate(-30 0 -35)"/>
    <ellipse cx="18" cy="-35" rx="14" ry="32" fill="#ffffff" transform="rotate(30 18 -35)"/>
    <ellipse cx="9" cy="-45" rx="13" ry="35" fill="#f5f7f0"/>
    <circle cx="9" cy="-32" r="5" fill="#ffeaa7"/>
    <circle cx="9" cy="-32" r="16" fill="#fff9d4" opacity="0.35"/>
  </g>
  <g transform="translate(740, 805) scale(0.8)">
    <path d="M 0,60 Q -10,20 -5,-30" stroke="#485c3b" stroke-width="4" fill="none"/>
    <ellipse cx="-10" cy="-35" rx="14" ry="30" fill="#ffffff" transform="rotate(-25 -10 -35)"/>
    <ellipse cx="8" cy="-35" rx="14" ry="30" fill="#ffffff" transform="rotate(25 8 -35)"/>
    <ellipse cx="0" cy="-45" rx="13" ry="32" fill="#f5f7f0"/>
    <circle cx="0" cy="-32" r="5" fill="#ffeaa7"/>
    <circle cx="0" cy="-32" r="14" fill="#fff9d4" opacity="0.35"/>
  </g>
  <g transform="translate(630, 820) scale(0.9)">
    <path d="M 0,60 Q 20,25 15,-25" stroke="#485c3b" stroke-width="4" fill="none"/>
    <ellipse cx="5" cy="-30" rx="14" ry="30" fill="#ffffff" transform="rotate(-20 5 -30)"/>
    <ellipse cx="22" cy="-30" rx="14" ry="30" fill="#ffffff" transform="rotate(30 22 -30)"/>
    <ellipse cx="14" cy="-40" rx="13" ry="32" fill="#f5f7f0"/>
    <circle cx="14" cy="-28" r="5" fill="#ffeaa7"/>
  </g>

  {motes_str}

  {title_svg}

  <rect width="1024" height="1024" fill="url(#vignette)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 2. WEIGHT OF THE RALLY
# -------------------------------------------------------------
def make_weight_of_the_rally_svg():
    title_svg = render_title_banner(
        "WEIGHT OF THE RALLY", center_x=512, center_y=900,
        scale=0.32, letter_spacing=10, stroke="#f4efe2", stroke_width=9, accent_color="#caa568"
    )

    motes = []
    rng = random.Random(101)
    for _ in range(70):
        mx = rng.randint(120, 900)
        my = rng.randint(80, 800)
        mr = rng.uniform(1.2, 4.0)
        mo = rng.uniform(0.25, 0.9)
        motes.append(f'<circle cx="{mx}" cy="{my}" r="{mr:.1f}" fill="#fce4a6" opacity="{mo:.2f}"/>')
    motes_str = "\n".join(motes)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="hall_bg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0f141d"/>
      <stop offset="45%" stop-color="#192230"/>
      <stop offset="75%" stop-color="#2c3a50"/>
      <stop offset="100%" stop-color="#141a24"/>
    </linearGradient>
    <linearGradient id="celestial_beam" x1="50%" y1="0%" x2="50%" y2="100%">
      <stop offset="0%" stop-color="#fff8db" stop-opacity="0.75"/>
      <stop offset="50%" stop-color="#e8cf90" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#9a8656" stop-opacity="0.0"/>
    </linearGradient>
    <linearGradient id="marble_step" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#242b38"/>
      <stop offset="50%" stop-color="#3d495d"/>
      <stop offset="100%" stop-color="#242b38"/>
    </linearGradient>
    <radialGradient id="rose_glow" cx="50%" cy="32%" r="40%">
      <stop offset="0%" stop-color="#fff4cd" stop-opacity="0.9"/>
      <stop offset="35%" stop-color="#e2bf75" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#2c3a50" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_rally" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#080b10" stop-opacity="0.8"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#hall_bg)"/>
  <circle cx="512" cy="300" r="280" fill="url(#rose_glow)"/>

  <circle cx="512" cy="300" r="140" fill="#111620" stroke="#a68e61" stroke-width="12"/>
  <circle cx="512" cy="300" r="120" fill="none" stroke="#caa568" stroke-width="4"/>
  <circle cx="512" cy="300" r="70" fill="#18202d" stroke="#8b7348" stroke-width="6"/>
  <g stroke="#caa568" stroke-width="4">
    <line x1="512" y1="160" x2="512" y2="440"/>
    <line x1="372" y1="300" x2="652" y2="300"/>
    <line x1="413" y1="201" x2="611" y2="399"/>
    <line x1="413" y1="399" x2="611" y2="201"/>
  </g>
  <polygon points="512,180 540,230 512,250" fill="#4fa1d8" opacity="0.6"/>
  <polygon points="460,250 490,290 440,280" fill="#e8b948" opacity="0.65"/>
  <polygon points="530,320 570,300 560,350" fill="#4fc1b0" opacity="0.5"/>
  <polygon points="470,330 510,360 480,380" fill="#d95d5d" opacity="0.55"/>

  <polygon points="440,300 584,300 760,820 264,820" fill="url(#celestial_beam)"/>

  <path d="M 0,0 L 0,840 L 160,840 L 160,540 C 160,360 260,240 380,180 L 320,100 C 180,180 80,320 0,500 Z" fill="#1c2330"/>
  <rect x="130" y="440" width="30" height="400" fill="#161c27"/>
  <rect x="230" y="480" width="24" height="360" fill="#1f2735"/>
  <path d="M 230,480 C 230,380 300,320 380,280 L 380,250 C 280,290 190,370 190,480 Z" fill="#1a222e"/>

  <path d="M 1024,0 L 1024,840 L 864,840 L 864,540 C 864,360 764,240 644,180 L 704,100 C 844,180 944,320 1024,500 Z" fill="#1c2330"/>
  <rect x="864" y="440" width="30" height="400" fill="#161c27"/>
  <rect x="770" y="480" width="24" height="360" fill="#1f2735"/>
  <path d="M 794,480 C 794,380 724,320 644,280 L 644,250 C 744,290 834,370 834,480 Z" fill="#1a222e"/>

  <polygon points="260,780 764,780 820,830 204,830" fill="url(#marble_step)"/>
  <polygon points="204,830 820,830 880,900 144,900" fill="#181e28"/>
  <polygon points="144,900 880,900 950,1024 74,1024" fill="#10141b"/>

  <polygon points="440,700 584,700 610,780 414,780" fill="#4d596d"/>
  <polygon points="455,640 569,640 584,700 440,700" fill="#69778e"/>
  <rect x="470" y="600" width="84" height="40" fill="#8898b0"/>
  <polygon points="490,530 534,510 545,600 480,600" fill="#e8d8b5" stroke="#2a303c" stroke-width="2"/>
  <circle cx="512" cy="560" r="45" fill="#ffeaa7" opacity="0.3"/>

  <path d="M 160,540 Q 180,640 170,720" stroke="#374839" stroke-width="8" fill="none"/>
  <path d="M 864,540 Q 840,630 850,710" stroke="#374839" stroke-width="8" fill="none"/>
  <path d="M 320,100 Q 340,240 330,340" stroke="#2d3d30" stroke-width="10" fill="none"/>
  <path d="M 704,100 Q 680,220 690,320" stroke="#2d3d30" stroke-width="10" fill="none"/>

  {motes_str}

  {title_svg}

  <rect width="1024" height="1024" fill="url(#vignette_rally)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 3. BEAUTIFUL DUEL
# -------------------------------------------------------------
def make_beautiful_duel_svg():
    title_svg = render_title_banner(
        "BEAUTIFUL DUEL", center_x=512, center_y=900,
        scale=0.39, letter_spacing=14, stroke="#fcedce", stroke_width=9, accent_color="#d4af37"
    )

    crystals = []
    rng = random.Random(202)
    for _ in range(55):
        cx = rng.randint(340, 684)
        cy = rng.randint(220, 480)
        cr = rng.uniform(2.5, 6.0)
        co = rng.uniform(0.4, 0.95)
        crystals.append(f'<polygon points="{cx},{cy-cr*2} {cx+cr},{cy} {cx},{cy+cr*2} {cx-cr},{cy}" fill="#d4f3ff" opacity="{co:.2f}"/>')
        crystals.append(f'<circle cx="{cx}" cy="{cy}" r="{cr*2.5:.1f}" fill="#fff2c2" opacity="0.25"/>')
    crystals_str = "\n".join(crystals)

    petals = []
    for _ in range(35):
        px = rng.randint(150, 874)
        py = rng.randint(300, 880)
        rot = rng.randint(0, 360)
        petals.append(f'<ellipse cx="{px}" cy="{py}" rx="9" ry="16" transform="rotate({rot} {px} {py})" fill="#b51b32" opacity="0.75"/>')
    petals_str = "\n".join(petals)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="opera_bg" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#14060a"/>
      <stop offset="50%" stop-color="#2b0a13"/>
      <stop offset="85%" stop-color="#18070c"/>
      <stop offset="100%" stop-color="#0a0305"/>
    </linearGradient>
    <linearGradient id="curtain_left" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#4d0e19"/>
      <stop offset="35%" stop-color="#94192d"/>
      <stop offset="70%" stop-color="#5a111e"/>
      <stop offset="100%" stop-color="#24070c"/>
    </linearGradient>
    <linearGradient id="curtain_right" x1="100%" y1="0%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#4d0e19"/>
      <stop offset="35%" stop-color="#94192d"/>
      <stop offset="70%" stop-color="#5a111e"/>
      <stop offset="100%" stop-color="#24070c"/>
    </linearGradient>
    <linearGradient id="spotlight_cone" x1="50%" y1="0%" x2="50%" y2="100%">
      <stop offset="0%" stop-color="#fff8db" stop-opacity="0.85"/>
      <stop offset="60%" stop-color="#ffdc8a" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#e8bf56" stop-opacity="0.0"/>
    </linearGradient>
    <linearGradient id="stage_wood" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#3b171c"/>
      <stop offset="40%" stop-color="#5c262e"/>
      <stop offset="100%" stop-color="#1d0a0e"/>
    </linearGradient>
    <radialGradient id="chandelier_glow" cx="50%" cy="30%" r="45%">
      <stop offset="0%" stop-color="#fff6cc" stop-opacity="0.95"/>
      <stop offset="35%" stop-color="#ffd470" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#801224" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_duel" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#050102" stop-opacity="0.85"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#opera_bg)"/>

  <g fill="#1a070c" stroke="#3d141c" stroke-width="3">
    <rect x="180" y="240" width="664" height="30"/>
    <path d="M 220,240 C 220,180 270,180 270,240"/>
    <path d="M 320,240 C 320,180 370,180 370,240"/>
    <path d="M 420,240 C 420,180 470,180 470,240"/>
    <path d="M 554,240 C 554,180 604,180 604,240"/>
    <path d="M 654,240 C 654,180 704,180 704,240"/>
    <path d="M 754,240 C 754,180 804,180 804,240"/>
  </g>

  <polygon points="512,140 680,820 344,820" fill="url(#spotlight_cone)"/>

  <line x1="512" y1="0" x2="512" y2="210" stroke="#c49b45" stroke-width="4"/>
  <line x1="420" y1="0" x2="490" y2="220" stroke="#8c6e30" stroke-width="2"/>
  <line x1="604" y1="0" x2="534" y2="220" stroke="#8c6e30" stroke-width="2"/>

  <circle cx="512" cy="280" r="160" fill="url(#chandelier_glow)"/>
  <ellipse cx="512" cy="240" rx="140" ry="24" fill="#38240a" stroke="#d4af37" stroke-width="6"/>
  <ellipse cx="512" cy="300" rx="190" ry="32" fill="#2d1d07" stroke="#e6c35c" stroke-width="8"/>
  <ellipse cx="512" cy="360" rx="120" ry="20" fill="#221505" stroke="#caa54e" stroke-width="5"/>
  <polygon points="512,360 480,440 544,440" fill="#caa54e"/>

  {crystals_str}

  <path d="M 0,0 C 140,80 200,280 180,480 C 160,680 220,780 140,940 L 0,940 Z" fill="url(#curtain_left)"/>
  <path d="M 60,0 C 160,180 120,400 130,680" stroke="#24070c" stroke-width="16" fill="none"/>
  <path d="M 120,0 C 220,240 180,500 190,820" stroke="#b0233c" stroke-width="8" fill="none"/>
  <path d="M 0,420 Q 140,460 170,520" stroke="#d4af37" stroke-width="6" fill="none"/>
  <polygon points="165,520 185,570 155,570" fill="#d4af37"/>

  <path d="M 1024,0 C 884,80 824,280 844,480 C 864,680 804,780 884,940 L 1024,940 Z" fill="url(#curtain_right)"/>
  <path d="M 964,0 C 864,180 904,400 894,680" stroke="#24070c" stroke-width="16" fill="none"/>
  <path d="M 904,0 C 804,240 844,500 834,820" stroke="#b0233c" stroke-width="8" fill="none"/>
  <path d="M 1024,420 Q 884,460 854,520" stroke="#d4af37" stroke-width="6" fill="none"/>
  <polygon points="859,520 839,570 869,570" fill="#d4af37"/>

  <polygon points="120,760 904,760 1024,960 0,960" fill="url(#stage_wood)"/>
  <line x1="512" y1="760" x2="512" y2="960" stroke="#240a0e" stroke-width="3"/>
  <line x1="380" y1="760" x2="260" y2="960" stroke="#240a0e" stroke-width="3"/>
  <line x1="644" y1="760" x2="764" y2="960" stroke="#240a0e" stroke-width="3"/>
  <ellipse cx="512" cy="790" rx="140" ry="18" fill="#ffeaa7" opacity="0.3"/>

  {petals_str}

  {title_svg}

  <rect width="1024" height="1024" fill="url(#vignette_duel)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 4. MEMORIES OF SAND
# -------------------------------------------------------------
def make_memories_of_sand_svg():
    title_svg = render_title_banner(
        "MEMORIES OF SAND", center_x=512, center_y=900,
        scale=0.35, letter_spacing=12, stroke="#fff4db", stroke_width=9, accent_color="#fae19c"
    )

    particles = []
    rng = random.Random(303)
    for _ in range(60):
        sx = rng.randint(40, 984)
        sy = rng.randint(20, 420)
        sr = rng.uniform(1.0, 2.5)
        particles.append(f'<circle cx="{sx}" cy="{sy}" r="{sr:.1f}" fill="#fae19c" opacity="{rng.uniform(0.3, 0.8):.2f}"/>')
    for _ in range(80):
        dx = rng.randint(80, 960)
        dy = rng.randint(480, 850)
        dr = rng.uniform(1.2, 3.5)
        particles.append(f'<circle cx="{dx}" cy="{dy}" r="{dr:.1f}" fill="#ffe4a0" opacity="{rng.uniform(0.35, 0.75):.2f}"/>')
    particles_str = "\n".join(particles)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="twilight_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#150f24"/>
      <stop offset="40%" stop-color="#2d1c3e"/>
      <stop offset="70%" stop-color="#5e2b4d"/>
      <stop offset="90%" stop-color="#a64d4b"/>
      <stop offset="100%" stop-color="#e0864e"/>
    </linearGradient>
    <linearGradient id="dune_back" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#d97c36"/>
      <stop offset="50%" stop-color="#b85c27"/>
      <stop offset="100%" stop-color="#733218"/>
    </linearGradient>
    <linearGradient id="dune_mid" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#f0a54d"/>
      <stop offset="40%" stop-color="#d67b2c"/>
      <stop offset="100%" stop-color="#803816"/>
    </linearGradient>
    <linearGradient id="dune_front" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#fac370"/>
      <stop offset="50%" stop-color="#e6963c"/>
      <stop offset="100%" stop-color="#994d1a"/>
    </linearGradient>
    <radialGradient id="celestial_sun" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#fff8e7"/>
      <stop offset="45%" stop-color="#ffd685"/>
      <stop offset="80%" stop-color="#f59c47"/>
      <stop offset="100%" stop-color="#d65e38" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_sand" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#0a0710" stop-opacity="0.8"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#twilight_sky)"/>
  <circle cx="512" cy="380" r="190" fill="url(#celestial_sun)"/>
  <circle cx="512" cy="380" r="160" fill="#fffbe8"/>

  {particles_str}

  <path d="M 0,460 Q 240,420 520,470 Q 780,510 1024,440 L 1024,600 L 0,600 Z" fill="#99452b" opacity="0.75"/>

  <g transform="translate(680, 500) rotate(-18)">
    <circle cx="0" cy="0" r="120" fill="#4d3b32" stroke="#241b16" stroke-width="8"/>
    <circle cx="-35" cy="-20" r="22" fill="#150f0c"/>
    <circle cx="35" cy="-20" r="22" fill="#150f0c"/>
    <circle cx="-35" cy="-20" r="12" fill="#ffe17d"/>
    <circle cx="-35" cy="-20" r="28" fill="#ffeaa7" opacity="0.35"/>
    <circle cx="0" cy="-90" r="6" fill="#806859"/>
    <circle cx="-70" cy="-60" r="6" fill="#806859"/>
    <circle cx="70" cy="-60" r="6" fill="#806859"/>
  </g>

  <path d="M 0,550 Q 320,490 640,570 Q 860,620 1024,530 L 1024,760 L 0,760 Z" fill="url(#dune_mid)"/>

  <g transform="translate(260, 680) rotate(32)">
    <circle cx="0" cy="0" r="160" fill="#593b22" stroke="#2b1a0d" stroke-width="10"/>
    <circle cx="0" cy="0" r="110" fill="#8c5d35"/>
    <circle cx="0" cy="0" r="60" fill="#3b2413"/>
    <rect x="-24" y="-190" width="48" height="40" fill="#8c5d35"/>
    <rect x="-190" y="-24" width="40" height="48" fill="#8c5d35"/>
    <rect x="150" y="-24" width="40" height="48" fill="#8c5d35"/>
    <rect x="-135" y="-135" width="42" height="42" transform="rotate(45)" fill="#8c5d35"/>
    <rect x="95" y="-135" width="42" height="42" transform="rotate(-45)" fill="#8c5d35"/>
  </g>

  <path d="M 0,690 Q 380,630 680,740 Q 880,810 1024,710 L 1024,1024 L 0,1024 Z" fill="url(#dune_front)"/>
  <path d="M 0,690 Q 380,630 680,740 Q 880,810 1024,710" stroke="#fff0b8" stroke-width="5" fill="none"/>

  <path d="M 80,780 Q 280,740 480,800" stroke="#f5c77a" stroke-width="4" fill="none" opacity="0.6"/>
  <path d="M 420,830 Q 640,790 840,860" stroke="#d68d38" stroke-width="4" fill="none" opacity="0.5"/>

  {title_svg}

  <rect width="1024" height="1024" fill="url(#vignette_sand)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 5. REBIRTH OF HOPE
# -------------------------------------------------------------
def make_rebirth_of_hope_svg():
    title_svg = render_title_banner(
        "REBIRTH OF HOPE", center_x=512, center_y=900,
        scale=0.36, letter_spacing=12, stroke="#ffffff", stroke_width=9, accent_color="#e0e8f0"
    )

    sparkles = []
    rng = random.Random(404)
    for _ in range(65):
        sx = rng.randint(80, 944)
        sy = rng.randint(60, 820)
        sr = rng.uniform(1.2, 4.0)
        sparkles.append(f'<circle cx="{sx}" cy="{sy}" r="{sr:.1f}" fill="#ffffff" opacity="{rng.uniform(0.4, 0.95):.2f}"/>')
        if sr > 2.8:
            sparkles.append(f'<line x1="{sx-sr*3}" y1="{sy}" x2="{sx+sr*3}" y2="{sy}" stroke="#fffbee" stroke-width="1.5" opacity="0.6"/>')
            sparkles.append(f'<line x1="{sx}" y1="{sy-sr*3}" x2="{sx}" y2="{sy+sr*3}" stroke="#fffbee" stroke-width="1.5" opacity="0.6"/>')
    for _ in range(25):
        fx = rng.randint(180, 844)
        fy = rng.randint(200, 750)
        frot = rng.randint(-40, 40)
        sparkles.append(f'<path d="M {fx},{fy} Q {fx+12},{fy-20} {fx},{fy-40} Q {fx-12},{fy-20} {fx},{fy}" fill="#ffffff" opacity="0.75" transform="rotate({frot} {fx} {fy})"/>')
    sparkles_str = "\n".join(sparkles)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="dawn_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#142636"/>
      <stop offset="30%" stop-color="#244b61"/>
      <stop offset="60%" stop-color="#6b8694"/>
      <stop offset="85%" stop-color="#e89e78"/>
      <stop offset="100%" stop-color="#ffdfa4"/>
    </linearGradient>
    <linearGradient id="cloud_layer1" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="50%" stop-color="#ffd5b5" stop-opacity="0.8"/>
      <stop offset="100%" stop-color="#9ea4b0" stop-opacity="0.4"/>
    </linearGradient>
    <linearGradient id="cloud_layer2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffebd4"/>
      <stop offset="50%" stop-color="#e0a382"/>
      <stop offset="100%" stop-color="#465466"/>
    </linearGradient>
    <radialGradient id="dawn_sunburst" cx="50%" cy="40%" r="55%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="25%" stop-color="#fff4c4" stop-opacity="0.9"/>
      <stop offset="55%" stop-color="#ffa86b" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#244b61" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_hope" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#08141e" stop-opacity="0.75"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#dawn_sky)"/>
  <circle cx="512" cy="380" r="420" fill="url(#dawn_sunburst)"/>
  <circle cx="512" cy="380" r="100" fill="#ffffff"/>

  <g stroke="#ffffff" stroke-width="3" opacity="0.35">
    <line x1="512" y1="380" x2="100" y2="120"/>
    <line x1="512" y1="380" x2="924" y2="120"/>
    <line x1="512" y1="380" x2="250" y2="60"/>
    <line x1="512" y1="380" x2="774" y2="60"/>
    <line x1="512" y1="380" x2="512" y2="20"/>
    <line x1="512" y1="380" x2="0" y2="300"/>
    <line x1="512" y1="380" x2="1024" y2="300"/>
  </g>

  <polygon points="180,560 260,390 340,560" fill="#2b4354"/>
  <polygon points="680,580 760,420 840,580" fill="#243846"/>
  <polygon points="790,560 840,460 890,560" fill="#1b2a36"/>

  <g transform="translate(512, 480)">
    <path d="M 0,0 C -80,-60 -220,-120 -380,-80 C -340,-20 -220,10 -140,20 Z" fill="#d4af37" stroke="#ffffff" stroke-width="3"/>
    <path d="M -220,-120 C -320,-180 -440,-160 -460,-120 C -420,-90 -320,-80 -220,-100 Z" fill="#fffbe8"/>
    <path d="M -180,-100 C -280,-150 -390,-120 -420,-80 C -370,-50 -260,-50 -170,-70 Z" fill="#ffffff"/>
    <path d="M -140,-70 C -240,-110 -340,-70 -370,-30 C -320,-10 -210,-20 -130,-40 Z" fill="#fff5d9"/>
    <path d="M -100,-40 C -180,-60 -270,-20 -290,20 C -250,30 -160,20 -90,0 Z" fill="#ffffff"/>

    <path d="M 0,0 C 80,-60 220,-120 380,-80 C 340,-20 220,10 140,20 Z" fill="#d4af37" stroke="#ffffff" stroke-width="3"/>
    <path d="M 220,-120 C 320,-180 440,-160 460,-120 C 420,-90 320,-80 220,-100 Z" fill="#fffbe8"/>
    <path d="M 180,-100 C 280,-150 390,-120 420,-80 C 370,-50 260,-50 170,-70 Z" fill="#ffffff"/>
    <path d="M 140,-70 C 240,-110 340,-70 370,-30 C 320,-10 210,-20 130,-40 Z" fill="#fff5d9"/>
    <path d="M 100,-40 C 180,-60 270,-20 290,20 C 250,30 160,20 90,0 Z" fill="#ffffff"/>

    <circle cx="0" cy="0" r="28" fill="#ffffff" stroke="#e6c35c" stroke-width="6"/>
    <circle cx="0" cy="0" r="60" fill="#fff5d4" opacity="0.45"/>
  </g>

  <path d="M -40,580 Q 80,510 240,550 Q 380,480 540,530 Q 720,490 880,540 Q 980,510 1064,570 L 1064,780 L -40,780 Z" fill="url(#cloud_layer2)"/>
  <path d="M -40,680 Q 120,600 320,660 Q 480,580 680,640 Q 840,590 1064,670 L 1064,1024 L -40,1024 Z" fill="url(#cloud_layer1)"/>

  {sparkles_str}

  {title_svg}

  <rect width="1024" height="1024" fill="url(#vignette_hope)" pointer-events="none"/>
</svg>"""

TRACKS = [
    ("ost_rays_of_rust", make_rays_of_rust_svg),
    ("ost_weight_of_the_rally", make_weight_of_the_rally_svg),
    ("ost_beautiful_duel", make_beautiful_duel_svg),
    ("ost_memories_of_sand", make_memories_of_sand_svg),
    ("ost_rebirth_of_hope", make_rebirth_of_hope_svg),
]

print("=== Generating Automata Suite Scenic Cover SVGs (Refined Typography) ===")
for track_id, generator_func in TRACKS:
    svg_content = generator_func()
    svg_path = os.path.join(TEMP_SVG_DIR, f"{track_id}.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg_content)
    print(f"  [OK] Generated {track_id}.svg ({len(svg_content)} bytes)")

# Write GDScript batch rasterizer
gd_batch_script = """extends SceneTree

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
"""

rasterizer_path = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/godot/tests/rasterize_automata_covers.gd"
with open(rasterizer_path, "w", encoding="utf-8") as f:
    f.write(gd_batch_script)

print("Batch rasterizer updated.")
