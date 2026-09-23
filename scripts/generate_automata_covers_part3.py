import os
import math
import random
from svg_text_vector import render_title_banner

TEMP_SVG_DIR = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/automata_svgs"
os.makedirs(TEMP_SVG_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. CARNIVAL OF ILLUSIONS
# -------------------------------------------------------------
def make_carnival_of_illusions_svg():
    title_svg = render_title_banner(
        "CARNIVAL OF ILLUSIONS", center_x=512, center_y=900,
        scale=0.33, letter_spacing=13, stroke="#fff8e7", stroke_width=9, accent_color="#ffb86c"
    )

    # Carnival lights / bulbs along the Ferris wheel
    wheel_cx, wheel_cy, wheel_r = 512, 420, 240
    spokes = []
    bulbs = []
    for deg in range(0, 360, 30):
        rad = math.radians(deg)
        x2 = wheel_cx + wheel_r * math.cos(rad)
        y2 = wheel_cy + wheel_r * math.sin(rad)
        spokes.append(f'<line x1="{wheel_cx}" y1="{wheel_cy}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="#3b2d4a" stroke-width="3"/>')
        # Gondola carriage
        gx, gy = x2, y2
        spokes.append(f'<rect x="{gx-12:.1f}" y="{gy-8:.1f}" width="24" height="20" rx="4" fill="#2d1c3a" stroke="#d68438" stroke-width="2"/>')
        color = "#ffd166" if deg % 60 == 0 else "#06d6a0"
        bulbs.append(f'<circle cx="{x2:.1f}" cy="{y2:.1f}" r="5" fill="{color}" opacity="0.9"/>')
        bulbs.append(f'<circle cx="{x2:.1f}" cy="{y2:.1f}" r="12" fill="{color}" opacity="0.3"/>')
    wheel_str = "\n".join(spokes + bulbs)

    # Drifting confetti & fireflies
    rng = random.Random(601)
    fireflies = []
    for _ in range(50):
        fx = rng.randint(80, 944)
        fy = rng.randint(120, 800)
        fr = rng.uniform(1.8, 4.0)
        fo = rng.uniform(0.35, 0.85)
        c = rng.choice(["#ffb86c", "#ffd166", "#06d6a0", "#ff7675"])
        fireflies.append(f'<circle cx="{fx}" cy="{fy}" r="{fr:.1f}" fill="{c}" opacity="{fo:.2f}"/>')
    fireflies_str = "\n".join(fireflies)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="twilight_carnival" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#110d24"/>
      <stop offset="40%" stop-color="#24153b"/>
      <stop offset="75%" stop-color="#4a2254"/>
      <stop offset="100%" stop-color="#180e22"/>
    </linearGradient>
    <radialGradient id="carnival_glow" cx="50%" cy="42%" r="45%">
      <stop offset="0%" stop-color="#ffb86c" stop-opacity="0.5"/>
      <stop offset="60%" stop-color="#4a2254" stop-opacity="0.2"/>
      <stop offset="100%" stop-color="#110d24" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_carnival" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#080510" stop-opacity="0.88"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#twilight_carnival)"/>
  <circle cx="512" cy="420" r="380" fill="url(#carnival_glow)"/>

  <!-- Distant Ruined Rollercoaster Track Silhouettes -->
  <path d="M -40,420 Q 180,260 400,380 Q 650,510 900,280 Q 980,210 1064,260" fill="none" stroke="#251636" stroke-width="10"/>
  <path d="M 0,440 L 1024,440" fill="none" stroke="#1c112b" stroke-width="3" stroke-dasharray="8,12"/>

  <!-- Colossal Ruined Ferris Wheel -->
  <circle cx="{wheel_cx}" cy="{wheel_cy}" r="{wheel_r}" fill="none" stroke="#4a355e" stroke-width="8"/>
  <circle cx="{wheel_cx}" cy="{wheel_cy}" r="{wheel_r-20}" fill="none" stroke="#372647" stroke-width="4"/>
  <circle cx="{wheel_cx}" cy="{wheel_cy}" r="32" fill="#2d1c3a" stroke="#ffd166" stroke-width="4"/>
  <!-- Support A-frame legs -->
  <polygon points="512,420 320,760 360,760 512,440" fill="#2d1c3a"/>
  <polygon points="512,420 704,760 664,760 512,440" fill="#241530"/>
  {wheel_str}

  <!-- Carnival Pennant String Bunting -->
  <path d="M 60,620 Q 280,680 500,640 Q 720,680 964,610" fill="none" stroke="#5a3d73" stroke-width="2"/>
  <polygon points="120,632 150,670 180,638" fill="#ff7675" opacity="0.85"/>
  <polygon points="220,644 250,682 280,650" fill="#ffd166" opacity="0.85"/>
  <polygon points="320,652 350,688 380,654" fill="#06d6a0" opacity="0.85"/>
  <polygon points="420,652 450,686 480,650" fill="#74b9ff" opacity="0.85"/>
  <polygon points="540,648 570,684 600,652" fill="#ff7675" opacity="0.85"/>
  <polygon points="660,654 690,688 720,656" fill="#ffd166" opacity="0.85"/>
  <polygon points="780,644 810,678 840,640" fill="#06d6a0" opacity="0.85"/>

  <!-- Ruined Carousel Platform & Shattered Wooden Horse Silhouette -->
  <polygon points="0,740 1024,740 1024,1024 0,1024" fill="#180e22"/>
  <line x1="0" y1="740" x2="1024" y2="740" stroke="#4a2e66" stroke-width="4"/>

  <!-- Carousel Horse on Foreground Left -->
  <g transform="translate(240, 710) scale(0.65)">
    <!-- Brass pole -->
    <line x1="0" y1="-180" x2="0" y2="120" stroke="#ffd166" stroke-width="8"/>
    <!-- Horse body -->
    <path d="M -60,0 C -40,-30 20,-30 50,0 C 60,30 30,50 -10,40 C -50,40 -70,20 -60,0 Z" fill="#eed9c4" stroke="#4a2e66" stroke-width="4"/>
    <!-- Horse neck & head -->
    <path d="M 40,-10 C 60,-50 70,-80 50,-100 C 40,-110 20,-100 20,-80 C 10,-50 20,-20 40,-10 Z" fill="#eed9c4" stroke="#4a2e66" stroke-width="4"/>
    <!-- Saddle -->
    <path d="M -15,5 Q 5,20 25,5 Q 15,-10 -15,5 Z" fill="#e84393" stroke="#ffd166" stroke-width="3"/>
    <!-- Overgrown ivy around leg -->
    <path d="M -30,40 Q -10,80 -20,120" stroke="#2ed573" stroke-width="6" fill="none"/>
  </g>

  <!-- Glowing fireflies & drifting confetti -->
  {fireflies_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_carnival)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 2. VERDANT WHISPERS
# -------------------------------------------------------------
def make_verdant_whispers_svg():
    title_svg = render_title_banner(
        "VERDANT WHISPERS", center_x=512, center_y=900,
        scale=0.35, letter_spacing=14, stroke="#fff8e7", stroke_width=9, accent_color="#55efc4"
    )

    beams = []
    for angle, opacity in [(35, 0.16), (45, 0.22), (55, 0.18), (65, 0.24), (75, 0.12)]:
        rad = math.radians(angle)
        dx = 1400 * math.cos(rad)
        dy = 1400 * math.sin(rad)
        beams.append(f'<polygon points="120,0 {120+dx},{dy} {120+dx+110},{dy+60} 120,0" fill="url(#forest_beam)" opacity="{opacity}"/>')
    beams_str = "\n".join(beams)

    rng = random.Random(602)
    spores = []
    for _ in range(55):
        sx = rng.randint(80, 944)
        sy = rng.randint(100, 800)
        sr = rng.uniform(1.8, 4.5)
        so = rng.uniform(0.35, 0.85)
        spores.append(f'<circle cx="{sx}" cy="{sy}" r="{sr:.1f}" fill="#a8ffb2" opacity="{so:.2f}"/>')
    spores_str = "\n".join(spores)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="canopy_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0a1c12"/>
      <stop offset="45%" stop-color="#163824"/>
      <stop offset="80%" stop-color="#2c5e3d"/>
      <stop offset="100%" stop-color="#142e1d"/>
    </linearGradient>
    <linearGradient id="forest_beam" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fffbcf" stop-opacity="0.85"/>
      <stop offset="50%" stop-color="#d4ed9a" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#55efc4" stop-opacity="0.0"/>
    </linearGradient>
    <linearGradient id="stone_moss" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2b3b2f"/>
      <stop offset="60%" stop-color="#1a261d"/>
      <stop offset="100%" stop-color="#0e1710"/>
    </linearGradient>
    <radialGradient id="vignette_forest" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#051009" stop-opacity="0.88"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#canopy_sky)"/>

  <!-- Colossal Ancient Redwood Tree Trunks flanking sides -->
  <polygon points="-40,0 160,0 200,820 -40,820" fill="#18241b"/>
  <polygon points="1064,0 864,0 824,820 1064,820" fill="#141f17"/>
  <!-- Roots wrapping across -->
  <path d="M 160,540 Q 280,680 440,720" stroke="#1f2d22" stroke-width="28" fill="none"/>
  <path d="M 860,520 Q 740,660 580,720" stroke="#18231a" stroke-width="26" fill="none"/>

  <!-- Ancient Moss-Covered Castle Archway Center -->
  <path d="M 320,740 L 320,380 Q 512,180 704,380 L 704,740 Z" fill="url(#stone_moss)" stroke="#1a261d" stroke-width="6"/>
  <!-- Hollow Inner Arch opening to mystical green light -->
  <path d="M 380,740 L 380,440 Q 512,280 644,440 L 644,740 Z" fill="#14301f"/>
  <circle cx="512" cy="460" r="160" fill="#2d6a45" opacity="0.4"/>

  <!-- Overgrown Ivy Curtains -->
  <path d="M 340,320 Q 320,440 350,560 Q 330,640 345,740" stroke="#387a4c" stroke-width="14" fill="none" stroke-linecap="round"/>
  <path d="M 684,330 Q 710,460 670,580 Q 695,650 680,740" stroke="#2d633e" stroke-width="16" fill="none" stroke-linecap="round"/>
  <circle cx="330" cy="460" r="16" fill="#4ea868"/>
  <circle cx="360" cy="540" r="14" fill="#55efc4"/>
  <circle cx="690" cy="480" r="18" fill="#4ea868"/>
  <circle cx="665" cy="570" r="14" fill="#55efc4"/>

  <!-- White Stag / Spirit Deer Silhouette in Archway -->
  <g transform="translate(512, 630) scale(0.65)">
    <!-- Deer torso & legs -->
    <path d="M -30,0 C -15,-20 25,-20 40,0 L 35,60 L 25,60 L 25,10 L -15,10 L -20,60 L -30,60 Z" fill="#e8fff4" opacity="0.9"/>
    <!-- Slender neck & head -->
    <path d="M 30,-10 C 35,-35 45,-55 35,-65 C 28,-68 22,-60 25,-45 L 20,-10 Z" fill="#e8fff4" opacity="0.9"/>
    <!-- Majestic glowing antlers -->
    <path d="M 35,-65 Q 45,-90 60,-100 M 42,-80 Q 30,-95 20,-105 M 35,-65 Q 25,-90 10,-100 M 28,-80 Q 40,-95 50,-105" stroke="#a8ffb2" stroke-width="3" fill="none" stroke-linecap="round"/>
  </g>

  <!-- Forest Ground & Ferns -->
  <polygon points="0,740 1024,740 1024,1024 0,1024" fill="#0c1810"/>
  <line x1="0" y1="740" x2="1024" y2="740" stroke="#3b6949" stroke-width="3"/>

  <!-- Sunbeams & Glowing Spores -->
  {beams_str}
  {spores_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_forest)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 3. ABYSSAL SILENCE
# -------------------------------------------------------------
def make_abyssal_silence_svg():
    title_svg = render_title_banner(
        "ABYSSAL SILENCE", center_x=512, center_y=900,
        scale=0.36, letter_spacing=14, stroke="#fff8e7", stroke_width=9, accent_color="#00d2d3"
    )

    rng = random.Random(603)
    ripples = []
    for r in [40, 90, 150, 220, 300, 390]:
        ripples.append(f'<ellipse cx="512" cy="740" rx="{r*1.8:.1f}" ry="{r*0.45:.1f}" fill="none" stroke="#00d2d3" stroke-width="2" opacity="{0.7 - r*0.0014:.2f}"/>')
    ripples_str = "\n".join(ripples)

    motes = []
    for _ in range(45):
        mx = rng.randint(120, 904)
        my = rng.randint(200, 780)
        mr = rng.uniform(1.5, 4.0)
        mo = rng.uniform(0.3, 0.8)
        motes.append(f'<circle cx="{mx}" cy="{my}" r="{mr:.1f}" fill="#54a0ff" opacity="{mo:.2f}"/>')
    motes_str = "\n".join(motes)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="abyss_dark" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#05070a"/>
      <stop offset="45%" stop-color="#0a1019"/>
      <stop offset="80%" stop-color="#101c2b"/>
      <stop offset="100%" stop-color="#070b12"/>
    </linearGradient>
    <linearGradient id="alien_monolith" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#101924"/>
      <stop offset="50%" stop-color="#23354a"/>
      <stop offset="100%" stop-color="#0c131c"/>
    </linearGradient>
    <radialGradient id="lake_glow" cx="50%" cy="74%" r="45%">
      <stop offset="0%" stop-color="#00d2d3" stop-opacity="0.45"/>
      <stop offset="50%" stop-color="#101c2b" stop-opacity="0.15"/>
      <stop offset="100%" stop-color="#05070a" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_abyss" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#020305" stop-opacity="0.92"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#abyss_dark)"/>

  <!-- Jagged Cavern Stalactites from ceiling -->
  <polygon points="60,0 120,0 90,260" fill="#0d1420"/>
  <polygon points="180,0 260,0 220,380" fill="#131e2e"/>
  <polygon points="760,0 840,0 800,340" fill="#131e2e"/>
  <polygon points="880,0 960,0 920,240" fill="#0d1420"/>
  <polygon points="440,0 520,0 480,180" fill="#0e1624"/>

  <!-- Colossal Submerged Alien Monolith Center -->
  <polygon points="460,740 480,240 544,240 564,740" fill="url(#alien_monolith)" stroke="#1f2f42" stroke-width="3"/>
  <polygon points="480,240 512,160 544,240" fill="#2d425c"/>

  <!-- Glowing Bioluminescent Circuitry / Runes on Monolith -->
  <line x1="512" y1="200" x2="512" y2="700" stroke="#00d2d3" stroke-width="4" stroke-linecap="round"/>
  <circle cx="512" cy="200" r="8" fill="#ffffff" stroke="#00d2d3" stroke-width="2"/>
  <line x1="486" y1="360" x2="538" y2="360" stroke="#00d2d3" stroke-width="2"/>
  <line x1="480" y1="480" x2="544" y2="480" stroke="#00d2d3" stroke-width="2"/>
  <line x1="474" y1="600" x2="550" y2="600" stroke="#00d2d3" stroke-width="2"/>
  <polygon points="512,460 530,480 512,500 494,480" fill="none" stroke="#54a0ff" stroke-width="2"/>

  <!-- Pitch-black subterranean lake glow & concentric water ripples -->
  <rect x="0" y="680" width="1024" height="344" fill="url(#lake_glow)"/>
  {ripples_str}

  <!-- Bioluminescent floating motes -->
  {motes_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_abyss)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 4. DANCE OF THE BLADE
# -------------------------------------------------------------
def make_dance_of_the_blade_svg():
    title_svg = render_title_banner(
        "DANCE OF THE BLADE", center_x=512, center_y=900,
        scale=0.34, letter_spacing=13, stroke="#fff8e7", stroke_width=9, accent_color="#ff7675"
    )

    rng = random.Random(604)
    leaves = []
    for _ in range(50):
        lx = rng.randint(80, 944)
        ly = rng.randint(120, 800)
        lr = rng.randint(0, 360)
        ls = rng.uniform(0.6, 1.3)
        lo = rng.uniform(0.4, 0.9)
        color = rng.choice(["#ff4757", "#ff6b6b", "#ffa502", "#ee5253"])
        leaves.append(f'<path d="M 0,0 C 12,-18 30,-10 32,5 C 25,25 0,22 0,0 Z" fill="{color}" opacity="{lo:.2f}" transform="translate({lx},{ly}) rotate({lr}) scale({ls:.2f})"/>')
    leaves_str = "\n".join(leaves)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="sunset_fire" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1a0812"/>
      <stop offset="35%" stop-color="#420f1e"/>
      <stop offset="65%" stop-color="#7a1c2e"/>
      <stop offset="85%" stop-color="#c0392b"/>
      <stop offset="100%" stop-color="#e67e22"/>
    </linearGradient>
    <linearGradient id="blade_glint" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="50%" stop-color="#cbd5e1"/>
      <stop offset="100%" stop-color="#475569"/>
    </linearGradient>
    <radialGradient id="duel_glow" cx="50%" cy="56%" r="40%">
      <stop offset="0%" stop-color="#ffd166" stop-opacity="0.8"/>
      <stop offset="50%" stop-color="#e74c3c" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#1a0812" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_duel" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#0d0408" stop-opacity="0.88"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#sunset_fire)"/>

  <!-- Distant Floating Mountain / Spire Silhouettes -->
  <polygon points="0,580 160,420 300,580" fill="#2d0b17" opacity="0.8"/>
  <polygon points="720,580 860,390 1024,580" fill="#2d0b17" opacity="0.8"/>
  <circle cx="512" cy="560" r="320" fill="url(#duel_glow)"/>

  <!-- Swirling Wind Trails -->
  <path d="M 80,480 Q 320,380 512,440 Q 720,500 960,420" fill="none" stroke="#ffbe76" stroke-width="2" opacity="0.6"/>
  <path d="M 120,560 Q 380,480 600,540 Q 820,600 920,530" fill="none" stroke="#ff7979" stroke-width="2" opacity="0.5"/>

  <!-- Suspended Stone Dueling Platform -->
  <ellipse cx="512" cy="740" rx="360" ry="70" fill="#2c2738" stroke="#483f5c" stroke-width="4"/>
  <ellipse cx="512" cy="735" rx="310" ry="55" fill="#1e1a26" stroke="#c0392b" stroke-width="3"/>
  <line x1="202" y1="740" x2="822" y2="740" stroke="#786c8f" stroke-width="2"/>

  <!-- Two Crossed Ancient Katanas / Blades in Center -->
  <!-- Left Blade (angled right) -->
  <g transform="translate(512, 570) rotate(24)">
    <polygon points="-8,-210 8,-210 10,130 -10,130" fill="url(#blade_glint)"/>
    <line x1="0" y1="-210" x2="0" y2="130" stroke="#0f172a" stroke-width="2"/>
    <rect x="-40" y="-220" width="80" height="10" rx="3" fill="#ffd166"/>
    <rect x="-6" y="-280" width="12" height="60" rx="2" fill="#1e293b"/>
  </g>
  <!-- Right Blade (angled left) -->
  <g transform="translate(512, 570) rotate(-24)">
    <polygon points="-8,-210 8,-210 10,130 -10,130" fill="url(#blade_glint)"/>
    <line x1="0" y1="-210" x2="0" y2="130" stroke="#0f172a" stroke-width="2"/>
    <rect x="-40" y="-220" width="80" height="10" rx="3" fill="#ffd166"/>
    <rect x="-6" y="-280" width="12" height="60" rx="2" fill="#1e293b"/>
  </g>

  <!-- Golden Clash Spark at Intersection -->
  <circle cx="512" cy="570" r="16" fill="#ffffff"/>
  <circle cx="512" cy="570" r="32" fill="#ffd166" opacity="0.6"/>

  <!-- Swirling Crimson Autumn Leaves -->
  {leaves_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_duel)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 5. CRADLE OF WAVES
# -------------------------------------------------------------
def make_cradle_of_waves_svg():
    title_svg = render_title_banner(
        "CRADLE OF WAVES", center_x=512, center_y=900,
        scale=0.36, letter_spacing=14, stroke="#fff8e7", stroke_width=9, accent_color="#74b9ff"
    )

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="pastel_sunset" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1f1a38"/>
      <stop offset="35%" stop-color="#3c2f5e"/>
      <stop offset="65%" stop-color="#705282"/>
      <stop offset="85%" stop-color="#b8839d"/>
      <stop offset="100%" stop-color="#f8c291"/>
    </linearGradient>
    <linearGradient id="ocean_water" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#38ada9"/>
      <stop offset="40%" stop-color="#1e7e78"/>
      <stop offset="80%" stop-color="#0a3d45"/>
      <stop offset="100%" stop-color="#041f24"/>
    </linearGradient>
    <radialGradient id="sun_gold" cx="50%" cy="52%" r="40%">
      <stop offset="0%" stop-color="#fff8d4" stop-opacity="0.95"/>
      <stop offset="40%" stop-color="#f8c291" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#705282" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_waves" cx="50%" cy="50%" r="70%">
      <stop offset="60%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#0a0814" stop-opacity="0.85"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#pastel_sunset)"/>
  <circle cx="512" cy="520" r="320" fill="url(#sun_gold)"/>

  <!-- Distant Submerged City Skyline / Bridge Towers -->
  <polygon points="120,530 160,380 200,380 240,530" fill="#503f66" opacity="0.6"/>
  <polygon points="760,530 800,340 840,340 880,530" fill="#503f66" opacity="0.6"/>
  <line x1="0" y1="460" x2="1024" y2="460" stroke="#604b78" stroke-width="4" opacity="0.4"/>

  <!-- Flock of Distant Seagulls -->
  <g stroke="#ffffff" stroke-width="2" fill="none" opacity="0.75">
    <path d="M 320,340 Q 330,332 340,340 Q 350,332 360,340"/>
    <path d="M 380,310 Q 388,304 396,310 Q 404,304 412,310"/>
    <path d="M 640,320 Q 650,312 660,320 Q 670,312 680,320"/>
  </g>

  <!-- Tranquil Turquoise Ocean Base -->
  <rect x="0" y="530" width="1024" height="494" fill="url(#ocean_water)"/>
  <line x1="0" y1="530" x2="1024" y2="530" stroke="#f8c291" stroke-width="3" opacity="0.7"/>

  <!-- Submerged Ruined Highway Pillars in Midground -->
  <!-- Left Pillar -->
  <polygon points="260,510 290,700 370,700 400,510" fill="#2d424b" stroke="#16252c" stroke-width="3"/>
  <path d="M 240,510 L 420,510 L 390,470 L 270,470 Z" fill="#3d5661"/>
  <!-- Overgrown barnacles and moss -->
  <path d="M 280,620 Q 330,640 380,620" stroke="#38ada9" stroke-width="8" fill="none" opacity="0.8"/>

  <!-- Right Submerged Tower Pillar -->
  <polygon points="620,490 650,720 730,720 760,490" fill="#263840" stroke="#16252c" stroke-width="3"/>
  <path d="M 600,490 L 780,490 L 750,450 L 630,450 Z" fill="#344c57"/>

  <!-- Gentle Lapping Wave Foam Lines -->
  <path d="M 0,560 Q 250,545 512,560 Q 770,575 1024,560" stroke="#b8e994" stroke-width="3" fill="none" opacity="0.6"/>
  <path d="M 0,620 Q 300,600 600,625 Q 850,640 1024,615" stroke="#ffffff" stroke-width="2.5" fill="none" opacity="0.45"/>
  <path d="M 0,690 Q 220,710 512,680 Q 780,660 1024,690" stroke="#82ccdd" stroke-width="3" fill="none" opacity="0.5"/>
  <path d="M 0,760 Q 320,740 640,770 Q 880,750 1024,765" stroke="#ffffff" stroke-width="2" fill="none" opacity="0.35"/>

  <!-- Sun Reflection Column on Ocean -->
  <ellipse cx="512" cy="545" rx="80" ry="6" fill="#fff8d4" opacity="0.8"/>
  <ellipse cx="512" cy="580" rx="120" ry="8" fill="#ffd384" opacity="0.6"/>
  <ellipse cx="512" cy="630" rx="160" ry="10" fill="#ffb86c" opacity="0.4"/>
  <ellipse cx="512" cy="700" rx="200" ry="12" fill="#f8c291" opacity="0.25"/>

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_waves)" pointer-events="none"/>
</svg>"""

TRACKS = [
    ("ost_carnival_of_illusions", make_carnival_of_illusions_svg),
    ("ost_verdant_whispers", make_verdant_whispers_svg),
    ("ost_abyssal_silence", make_abyssal_silence_svg),
    ("ost_dance_of_the_blade", make_dance_of_the_blade_svg),
    ("ost_cradle_of_waves", make_cradle_of_waves_svg),
]

def main():
    print("=== Generating Automata Suite Part 3 Scenic Cover SVGs ===")
    for track_id, generator_func in TRACKS:
        svg_content = generator_func()
        svg_path = os.path.join(TEMP_SVG_DIR, f"{track_id}.svg")
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write(svg_content)
        print(f"  [OK] Generated {track_id}.svg ({len(svg_content)} bytes)")

    # GDScript batch rasterizer
    gd_batch_script = """extends SceneTree

const TRACK_MAP: Dictionary = {
	"ost_carnival_of_illusions": "res://../scratch/automata_svgs/ost_carnival_of_illusions.svg",
	"ost_verdant_whispers": "res://../scratch/automata_svgs/ost_verdant_whispers.svg",
	"ost_abyssal_silence": "res://../scratch/automata_svgs/ost_abyssal_silence.svg",
	"ost_dance_of_the_blade": "res://../scratch/automata_svgs/ost_dance_of_the_blade.svg",
	"ost_cradle_of_waves": "res://../scratch/automata_svgs/ost_cradle_of_waves.svg",
}

func _init() -> void:
	print("[batch_cover_rasterizer_part3] Starting ThorVG render of 5 Part 3 covers...")
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
	print("[batch_cover_rasterizer_part3] All done!")
	quit()
"""

    rasterizer_path = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/godot/tests/rasterize_automata_covers_part3.gd"
    with open(rasterizer_path, "w", encoding="utf-8") as f:
        f.write(gd_batch_script)

    print("Batch rasterizer Part 3 updated.")

if __name__ == "__main__":
    main()
