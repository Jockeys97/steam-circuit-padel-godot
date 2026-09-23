import os
import math
import random
from svg_text_vector import render_title_banner

TEMP_SVG_DIR = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch/automata_svgs"
os.makedirs(TEMP_SVG_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. BROKEN MONOLITH
# -------------------------------------------------------------
def make_broken_monolith_svg():
    title_svg = render_title_banner(
        "BROKEN MONOLITH", center_x=512, center_y=900,
        scale=0.36, letter_spacing=14, stroke="#fff8e7", stroke_width=9, accent_color="#d4af37"
    )

    beams = []
    for angle, opacity in [(30, 0.14), (40, 0.20), (50, 0.16), (60, 0.22), (70, 0.12)]:
        rad = math.radians(angle)
        dx = 1400 * math.cos(rad)
        dy = 1400 * math.sin(rad)
        beams.append(f'<polygon points="900,0 {900-dx},{dy} {900-dx-100},{dy+60} 900,0" fill="url(#godray_grad)" opacity="{opacity}"/>')
    beams_str = "\n".join(beams)

    motes = []
    rng = random.Random(101)
    for _ in range(50):
        mx = rng.randint(100, 920)
        my = rng.randint(120, 800)
        mr = rng.uniform(1.5, 4.0)
        mo = rng.uniform(0.3, 0.8)
        motes.append(f'<circle cx="{mx}" cy="{my}" r="{mr:.1f}" fill="#ffd875" opacity="{mo:.2f}"/>')
    motes_str = "\n".join(motes)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="sanctuary_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#141c19"/>
      <stop offset="45%" stop-color="#24302b"/>
      <stop offset="75%" stop-color="#3b4d45"/>
      <stop offset="100%" stop-color="#182420"/>
    </linearGradient>
    <linearGradient id="godray_grad" x1="100%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#fff9d6" stop-opacity="0.8"/>
      <stop offset="60%" stop-color="#f6d365" stop-opacity="0.25"/>
      <stop offset="100%" stop-color="#cca03d" stop-opacity="0.0"/>
    </linearGradient>
    <linearGradient id="monolith_stone" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3d4944"/>
      <stop offset="50%" stop-color="#222b27"/>
      <stop offset="100%" stop-color="#151b18"/>
    </linearGradient>
    <linearGradient id="bronze_seam" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffd56b"/>
      <stop offset="50%" stop-color="#c99738"/>
      <stop offset="100%" stop-color="#694d1b"/>
    </linearGradient>
    <linearGradient id="water_grad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1d2d2a"/>
      <stop offset="60%" stop-color="#101917"/>
      <stop offset="100%" stop-color="#090d0c"/>
    </linearGradient>
    <radialGradient id="vignette" cx="50%" cy="50%" r="70%">
      <stop offset="60%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#070a08" stop-opacity="0.8"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#sanctuary_sky)"/>

  <!-- Distant Ruined Vaults -->
  <path d="M 60,480 Q 200,280 340,480 L 340,700 L 60,700 Z" fill="#1c2522" opacity="0.6"/>
  <path d="M 680,480 Q 820,260 960,480 L 960,700 L 680,700 Z" fill="#18211e" opacity="0.65"/>
  <rect x="180" y="320" width="40" height="380" fill="#141c19" opacity="0.7"/>
  <rect x="800" y="300" width="40" height="400" fill="#141c19" opacity="0.7"/>

  <!-- Flooded Courtyard Water Base -->
  <rect x="0" y="660" width="1024" height="364" fill="url(#water_grad)"/>
  <line x1="0" y1="660" x2="1024" y2="660" stroke="#4a6358" stroke-width="2" opacity="0.5"/>

  <!-- Colossal Broken Monolith Center -->
  <!-- Base / lower section -->
  <polygon points="420,680 440,380 584,395 604,680" fill="url(#monolith_stone)" stroke="#1a2320" stroke-width="3"/>
  <!-- Top fractured piece tilted slightly -->
  <polygon points="446,365 470,140 550,150 580,380" fill="url(#monolith_stone)" stroke="#1a2320" stroke-width="3" transform="rotate(-3, 512, 260)"/>

  <!-- Jagged fracture crack glowing bronze/gold -->
  <path d="M 440,380 L 480,368 L 510,388 L 545,372 L 584,395" stroke="url(#bronze_seam)" stroke-width="6" fill="none" stroke-linecap="round"/>
  <path d="M 490,260 L 505,320 L 480,368" stroke="url(#bronze_seam)" stroke-width="3" fill="none" opacity="0.85"/>
  <path d="M 530,220 L 525,290 L 545,372" stroke="url(#bronze_seam)" stroke-width="3" fill="none" opacity="0.85"/>

  <!-- Ancient geometric relief engravings -->
  <rect x="475" y="440" width="74" height="74" fill="none" stroke="#758f82" stroke-width="2" stroke-dasharray="4,6" opacity="0.6"/>
  <polygon points="512,450 540,490 484,490" fill="none" stroke="#9bb3a7" stroke-width="2" opacity="0.7"/>
  <circle cx="512" cy="477" r="14" fill="none" stroke="#d4af37" stroke-width="2" opacity="0.8"/>
  <line x1="512" y1="530" x2="512" y2="620" stroke="#758f82" stroke-width="3" opacity="0.5"/>
  <circle cx="512" cy="620" r="8" fill="#d4af37" opacity="0.7"/>

  <!-- Overgrown ivy vines -->
  <path d="M 425,410 Q 400,500 435,560 Q 410,620 425,680" stroke="#48633b" stroke-width="10" fill="none" stroke-linecap="round"/>
  <path d="M 595,430 Q 625,520 590,590 Q 615,640 600,680" stroke="#3b5230" stroke-width="12" fill="none" stroke-linecap="round"/>
  <circle cx="410" cy="510" r="14" fill="#5c7d4b"/>
  <circle cx="438" cy="580" r="12" fill="#698f56"/>
  <circle cx="612" cy="530" r="16" fill="#5c7d4b"/>

  <!-- Water Reflections -->
  <polygon points="420,680 436,860 588,860 604,680" fill="#18231f" opacity="0.45"/>
  <ellipse cx="512" cy="685" rx="140" ry="12" fill="#32493f" opacity="0.35"/>
  <line x1="380" y1="710" x2="644" y2="710" stroke="#688a7c" stroke-width="2" opacity="0.3"/>
  <line x1="430" y1="740" x2="594" y2="740" stroke="#688a7c" stroke-width="1.5" opacity="0.25"/>

  <!-- God Rays & Dust Motes -->
  {beams_str}
  {motes_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette overlay -->
  <rect width="1024" height="1024" fill="url(#vignette)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 2. CITY OF PEARLS
# -------------------------------------------------------------
def make_city_of_pearls_svg():
    title_svg = render_title_banner(
        "CITY OF PEARLS", center_x=512, center_y=900,
        scale=0.38, letter_spacing=14, stroke="#ffffff", stroke_width=9, accent_color="#7ba4d1"
    )

    rng = random.Random(202)
    crystals = []
    for _ in range(35):
        cx = rng.randint(80, 944)
        cy = rng.randint(100, 720)
        cr = rng.uniform(4.0, 14.0)
        co = rng.uniform(0.35, 0.8)
        crystals.append(f'<polygon points="{cx},{cy-cr:.1f} {cx+cr*0.7:.1f},{cy} {cx},{cy+cr:.1f} {cx-cr*0.7:.1f},{cy}" fill="#ffffff" stroke="#c0dcf7" stroke-width="1" opacity="{co:.2f}"/>')
    crystals_str = "\n".join(crystals)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="pearl_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#d4e6f9"/>
      <stop offset="40%" stop-color="#edf4fb"/>
      <stop offset="80%" stop-color="#ffffff"/>
      <stop offset="100%" stop-color="#e2ecf5"/>
    </linearGradient>
    <linearGradient id="tower_light" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="50%" stop-color="#e9f1f8"/>
      <stop offset="100%" stop-color="#ccdbe8"/>
    </linearGradient>
    <linearGradient id="tower_shade" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#b4c7d9"/>
      <stop offset="100%" stop-color="#93a8bd"/>
    </linearGradient>
    <linearGradient id="spire_glow" x1="0%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#a6c8ea" stop-opacity="0.7"/>
    </linearGradient>
    <radialGradient id="sun_pearl" cx="50%" cy="25%" r="45%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="50%" stop-color="#e8f3ff" stop-opacity="0.5"/>
      <stop offset="100%" stop-color="#dbe8f6" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_pearl" cx="50%" cy="50%" r="70%">
      <stop offset="65%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#142436" stop-opacity="0.6"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#pearl_sky)"/>
  <circle cx="512" cy="250" r="380" fill="url(#sun_pearl)"/>

  <!-- Distant Background Towers -->
  <polygon points="180,680 230,220 280,220 330,680" fill="#ccdbe8" opacity="0.6"/>
  <polygon points="720,680 770,200 820,200 870,680" fill="#ccdbe8" opacity="0.6"/>
  <polygon points="340,680 380,180 430,180 470,680" fill="#bdcfdf" opacity="0.7"/>
  <polygon points="580,680 620,160 670,160 710,680" fill="#bdcfdf" opacity="0.7"/>

  <!-- Midground Monumental Geometric Blocks -->
  <polygon points="80,740 160,340 260,340 180,740" fill="url(#tower_light)"/>
  <polygon points="260,340 320,380 240,740 180,740" fill="url(#tower_shade)"/>

  <polygon points="780,740 840,320 940,320 880,740" fill="url(#tower_light)"/>
  <polygon points="780,740 840,320 780,360 720,740" fill="url(#tower_shade)"/>

  <!-- Foreground Central Spire (Copied City needle) -->
  <polygon points="460,780 500,80 524,80 564,780" fill="url(#tower_light)"/>
  <polygon points="524,80 540,110 580,780 564,780" fill="url(#tower_shade)"/>
  <line x1="512" y1="80" x2="512" y2="20" stroke="#7ba4d1" stroke-width="4" stroke-linecap="round"/>
  <circle cx="512" cy="20" r="6" fill="#ffffff" stroke="#7ba4d1" stroke-width="2"/>

  <!-- Floating pristine architectural cubes -->
  <g transform="translate(320, 280) rotate(15)">
    <polygon points="0,0 50,-15 100,0 50,15" fill="#ffffff"/>
    <polygon points="0,0 50,15 50,75 0,60" fill="#d2e0ee"/>
    <polygon points="50,15 100,0 100,60 50,75" fill="#a4bcd2"/>
  </g>
  <g transform="translate(640, 240) rotate(-20)">
    <polygon points="0,0 40,-12 80,0 40,12" fill="#ffffff"/>
    <polygon points="0,0 40,12 40,60 0,48" fill="#d2e0ee"/>
    <polygon points="40,12 80,0 80,48 40,60" fill="#a4bcd2"/>
  </g>
  <g transform="translate(220, 460) rotate(25)">
    <polygon points="0,0 35,-10 70,0 35,10" fill="#ffffff"/>
    <polygon points="0,0 35,10 35,50 0,40" fill="#d2e0ee"/>
    <polygon points="35,10 70,0 70,40 35,50" fill="#a4bcd2"/>
  </g>

  <!-- Ground marble terrace grid -->
  <polygon points="0,740 1024,740 1024,1024 0,1024" fill="#d9e6f2"/>
  <polygon points="0,740 512,740 512,1024 0,1024" fill="#edf4fa" opacity="0.6"/>
  <line x1="0" y1="740" x2="1024" y2="740" stroke="#a3bdd6" stroke-width="3"/>
  <line x1="512" y1="740" x2="100" y2="1024" stroke="#a3bdd6" stroke-width="2" opacity="0.6"/>
  <line x1="512" y1="740" x2="924" y2="1024" stroke="#a3bdd6" stroke-width="2" opacity="0.6"/>
  <line x1="512" y1="740" x2="512" y2="1024" stroke="#a3bdd6" stroke-width="2" opacity="0.7"/>

  <!-- Shimmering Crystalline Motifs -->
  {crystals_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_pearl)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 3. TEARS OF PORCELAIN
# -------------------------------------------------------------
def make_tears_of_porcelain_svg():
    title_svg = render_title_banner(
        "TEARS OF PORCELAIN", center_x=512, center_y=900,
        scale=0.34, letter_spacing=13, stroke="#fff8e7", stroke_width=9, accent_color="#f6e05e"
    )

    rng = random.Random(303)
    petals = []
    for _ in range(40):
        px = rng.randint(80, 944)
        py = rng.randint(120, 820)
        pr = rng.randint(0, 360)
        ps = rng.uniform(0.7, 1.4)
        po = rng.uniform(0.4, 0.85)
        petals.append(f'<path d="M 0,0 C 10,-12 25,-12 30,0 C 25,18 10,18 0,0 Z" fill="#fda4af" stroke="#f43f5e" stroke-width="1" opacity="{po:.2f}" transform="translate({px},{py}) rotate({pr}) scale({ps:.2f})"/>')
    petals_str = "\n".join(petals)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="night_glass" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#0a101f"/>
      <stop offset="45%" stop-color="#141e34"/>
      <stop offset="75%" stop-color="#212d4a"/>
      <stop offset="100%" stop-color="#0f1626"/>
    </linearGradient>
    <linearGradient id="moon_grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="60%" stop-color="#e0e7ff"/>
      <stop offset="100%" stop-color="#93c5fd"/>
    </linearGradient>
    <linearGradient id="porcelain_skin" x1="20%" y1="0%" x2="80%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="50%" stop-color="#f5f4f0"/>
      <stop offset="85%" stop-color="#ded8cf"/>
      <stop offset="100%" stop-color="#b8b0a5"/>
    </linearGradient>
    <linearGradient id="kintsugi_gold" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffd56b"/>
      <stop offset="50%" stop-color="#e6b840"/>
      <stop offset="100%" stop-color="#a67c1e"/>
    </linearGradient>
    <radialGradient id="tear_gem" cx="35%" cy="35%" r="65%">
      <stop offset="0%" stop-color="#e0f2fe"/>
      <stop offset="40%" stop-color="#38bdf8"/>
      <stop offset="100%" stop-color="#0284c7"/>
    </radialGradient>
    <radialGradient id="vignette_night" cx="50%" cy="50%" r="70%">
      <stop offset="60%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#050810" stop-opacity="0.85"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#night_glass)"/>

  <!-- Ornate Iron Conservatory Window Arches in background -->
  <path d="M 120,700 L 120,340 Q 512,40 904,340 L 904,700 Z" fill="none" stroke="#25324d" stroke-width="12"/>
  <path d="M 280,700 L 280,420 Q 512,180 744,420 L 744,700 Z" fill="none" stroke="#2a3959" stroke-width="8"/>
  <line x1="512" y1="120" x2="512" y2="700" stroke="#2a3959" stroke-width="8"/>
  <line x1="120" y1="460" x2="904" y2="460" stroke="#2a3959" stroke-width="6"/>

  <!-- Silver Crescent Moon outside the glass -->
  <g transform="translate(680, 220)">
    <circle cx="0" cy="0" r="90" fill="url(#moon_grad)"/>
    <circle cx="-35" cy="-20" r="85" fill="#141e34"/>
  </g>

  <!-- Heavy stone windowsill -->
  <polygon points="60,720 964,720 1024,800 0,800" fill="#1e2538"/>
  <rect x="0" y="800" width="1024" height="224" fill="#131724"/>
  <line x1="0" y1="720" x2="1024" y2="720" stroke="#485980" stroke-width="3"/>

  <!-- Central Porcelain Marionette Mask -->
  <g id="porcelain_mask" transform="translate(512, 540)">
    <!-- Head oval -->
    <path d="M 0,-180 C 130,-180 150,-40 130,90 C 110,180 50,210 0,210 C -50,210 -110,180 -130,90 C -150,-40 -130,-180 0,-180 Z" fill="url(#porcelain_skin)" stroke="#2b313d" stroke-width="4"/>

    <!-- Closed serene eyes (carved porcelain slit) -->
    <path d="M -85,-20 Q -50,5 -15,-20" stroke="#4a5260" stroke-width="5" fill="none" stroke-linecap="round"/>
    <path d="M 85,-20 Q 50,5 15,-20" stroke="#4a5260" stroke-width="5" fill="none" stroke-linecap="round"/>

    <!-- Slender nose bridge -->
    <path d="M 0,-30 L 0,45 L 14,58" stroke="#a39b8f" stroke-width="3.5" fill="none" stroke-linecap="round"/>

    <!-- Dark rose porcelain lips -->
    <path d="M -30,120 Q 0,105 30,120 Q 0,140 -30,120 Z" fill="#9e4359"/>
    <line x1="-30" y1="120" x2="30" y2="120" stroke="#5c2432" stroke-width="2"/>

    <!-- Delicate Kintsugi gold seams & cracks -->
    <path d="M -45,-150 Q -10,-80 -35,-20 Q -40,30 -25,90" stroke="url(#kintsugi_gold)" stroke-width="4.5" fill="none" stroke-linecap="round"/>
    <path d="M -35,-20 L -75,20" stroke="url(#kintsugi_gold)" stroke-width="3" fill="none"/>
    <path d="M 50,-120 Q 75,-40 60,30 Q 75,80 55,140" stroke="url(#kintsugi_gold)" stroke-width="4" fill="none" stroke-linecap="round"/>

    <!-- The Crystalline Tear Gem running down the cheek -->
    <path d="M -50,0 C -60,25 -65,50 -50,75 C -35,50 -40,25 -50,0 Z" fill="url(#tear_gem)" stroke="#ffffff" stroke-width="1.5"/>
    <circle cx="-50" cy="55" r="4" fill="#ffffff" opacity="0.8"/>
  </g>

  <!-- Scattered Rose Petals -->
  {petals_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_night)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 4. HYMN OF THE ANCIENTS
# -------------------------------------------------------------
def make_hymn_of_the_ancients_svg():
    title_svg = render_title_banner(
        "HYMN OF THE ANCIENTS", center_x=512, center_y=900,
        scale=0.33, letter_spacing=13, stroke="#fff8e7", stroke_width=9, accent_color="#00f2fe"
    )

    rng = random.Random(404)
    spirits = []
    for _ in range(55):
        sx = rng.randint(180, 844)
        sy = rng.randint(120, 780)
        sr = rng.uniform(2.0, 5.5)
        so = rng.uniform(0.35, 0.9)
        spirits.append(f'<circle cx="{sx}" cy="{sy}" r="{sr:.1f}" fill="#70f8ff" opacity="{so:.2f}"/>')
        spirits.append(f'<circle cx="{sx}" cy="{sy}" r="{sr*2.2:.1f}" fill="#00c8e0" opacity="{so*0.35:.2f}"/>')
    spirits_str = "\n".join(spirits)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="cavern_deep" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#080c14"/>
      <stop offset="45%" stop-color="#0e1726"/>
      <stop offset="80%" stop-color="#182338"/>
      <stop offset="100%" stop-color="#0b101c"/>
    </linearGradient>
    <linearGradient id="spirit_shaft" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#a6ffff" stop-opacity="0.85"/>
      <stop offset="50%" stop-color="#00f2fe" stop-opacity="0.35"/>
      <stop offset="100%" stop-color="#4facfe" stop-opacity="0.0"/>
    </linearGradient>
    <linearGradient id="basalt_statue" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#1a2233"/>
      <stop offset="50%" stop-color="#2d3a54"/>
      <stop offset="100%" stop-color="#141a29"/>
    </linearGradient>
    <linearGradient id="altar_grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#2d3a54"/>
      <stop offset="100%" stop-color="#111622"/>
    </linearGradient>
    <radialGradient id="altar_glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#00f2fe" stop-opacity="0.9"/>
      <stop offset="40%" stop-color="#00b4d8" stop-opacity="0.4"/>
      <stop offset="100%" stop-color="#0f172a" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_cave" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#04060a" stop-opacity="0.88"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#cavern_deep)"/>

  <!-- Shaft of Celestial Azure Light from cavern ceiling -->
  <polygon points="512,0 360,780 664,780" fill="url(#spirit_shaft)"/>

  <!-- Colossal Ancient Guardian Statues flanking the hall -->
  <!-- Left Guardian -->
  <polygon points="40,820 90,260 210,260 260,820" fill="url(#basalt_statue)"/>
  <!-- Guardian head silhouette -->
  <circle cx="150" cy="220" r="55" fill="#253147"/>
  <rect x="120" y="270" width="60" height="40" fill="#1b2333"/>
  <line x1="130" y1="215" x2="145" y2="215" stroke="#00f2fe" stroke-width="4" stroke-linecap="round"/>
  <line x1="155" y1="215" x2="170" y2="215" stroke="#00f2fe" stroke-width="4" stroke-linecap="round"/>

  <!-- Right Guardian -->
  <polygon points="984,820 934,260 814,260 764,820" fill="url(#basalt_statue)"/>
  <!-- Guardian head silhouette -->
  <circle cx="874" cy="220" r="55" fill="#253147"/>
  <rect x="844" y="270" width="60" height="40" fill="#1b2333"/>
  <line x1="854" y1="215" x2="869" y2="215" stroke="#00f2fe" stroke-width="4" stroke-linecap="round"/>
  <line x1="879" y1="215" x2="894" y2="215" stroke="#00f2fe" stroke-width="4" stroke-linecap="round"/>

  <!-- Central Sacrificial Altar Disk -->
  <ellipse cx="512" cy="740" rx="200" ry="46" fill="url(#altar_grad)" stroke="#4a5f85" stroke-width="4"/>
  <ellipse cx="512" cy="735" rx="160" ry="34" fill="#111622" stroke="#00f2fe" stroke-width="3"/>
  <circle cx="512" cy="735" r="70" fill="url(#altar_glow)"/>

  <!-- Sacred Geometric Inscriptions around altar -->
  <ellipse cx="512" cy="735" rx="120" ry="24" fill="none" stroke="#70f8ff" stroke-width="2" stroke-dasharray="6,8" opacity="0.8"/>
  <polygon points="512,715 540,745 484,745" fill="none" stroke="#ffffff" stroke-width="2"/>

  <!-- Floating Spirit Light Motes -->
  {spirits_str}

  <!-- Cavern Floor -->
  <polygon points="0,820 1024,820 1024,1024 0,1024" fill="#0c111a"/>
  <line x1="0" y1="820" x2="1024" y2="820" stroke="#253147" stroke-width="3"/>

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_cave)" pointer-events="none"/>
</svg>"""

# -------------------------------------------------------------
# 5. ASHES OF DESTINY
# -------------------------------------------------------------
def make_ashes_of_destiny_svg():
    title_svg = render_title_banner(
        "ASHES OF DESTINY", center_x=512, center_y=900,
        scale=0.36, letter_spacing=14, stroke="#fff8e7", stroke_width=9, accent_color="#ff7675"
    )

    rng = random.Random(505)
    embers = []
    for _ in range(65):
        ex = rng.randint(80, 944)
        ey = rng.randint(140, 800)
        er = rng.uniform(1.5, 4.2)
        eo = rng.uniform(0.4, 0.9)
        color = rng.choice(["#ff7675", "#ffa07a", "#ffd166", "#ff4757"])
        embers.append(f'<circle cx="{ex}" cy="{ey}" r="{er:.1f}" fill="{color}" opacity="{eo:.2f}"/>')
    embers_str = "\n".join(embers)

    return f"""<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="twilight_sky" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#120c18"/>
      <stop offset="35%" stop-color="#281122"/>
      <stop offset="65%" stop-color="#4d1627"/>
      <stop offset="85%" stop-color="#702638"/>
      <stop offset="100%" stop-color="#240e16"/>
    </linearGradient>
    <linearGradient id="blade_steel" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="48%" stop-color="#cbd5e1"/>
      <stop offset="52%" stop-color="#64748b"/>
      <stop offset="100%" stop-color="#334155"/>
    </linearGradient>
    <linearGradient id="ash_dune1" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#251a24"/>
      <stop offset="100%" stop-color="#140e14"/>
    </linearGradient>
    <linearGradient id="ash_dune2" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1c131c"/>
      <stop offset="100%" stop-color="#0c080d"/>
    </linearGradient>
    <radialGradient id="sword_glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#ff7675" stop-opacity="0.8"/>
      <stop offset="50%" stop-color="#ff4757" stop-opacity="0.3"/>
      <stop offset="100%" stop-color="#240e16" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="vignette_ash" cx="50%" cy="50%" r="70%">
      <stop offset="55%" stop-color="#000000" stop-opacity="0.0"/>
      <stop offset="100%" stop-color="#0a0508" stop-opacity="0.88"/>
    </radialGradient>
  </defs>

  <rect width="1024" height="1024" fill="url(#twilight_sky)"/>

  <!-- Distant Volcanic Crag Silhouettes -->
  <polygon points="0,580 180,440 320,580" fill="#180e16" opacity="0.8"/>
  <polygon points="680,600 840,410 1024,600" fill="#180e16" opacity="0.8"/>
  <polygon points="260,620 480,480 660,620" fill="#20121d" opacity="0.7"/>

  <!-- Silver Crescent Moon -->
  <g transform="translate(760, 180)">
    <circle cx="0" cy="0" r="60" fill="#f8fafc"/>
    <circle cx="-25" cy="-14" r="56" fill="#1b0e1b"/>
  </g>

  <!-- Rolling Volcanic Ash Dunes -->
  <path d="M 0,660 Q 240,610 512,650 Q 780,690 1024,640 L 1024,800 L 0,800 Z" fill="url(#ash_dune1)"/>
  <path d="M 0,720 Q 320,680 640,730 Q 860,700 1024,750 L 1024,1024 L 0,1024 Z" fill="url(#ash_dune2)"/>

  <!-- Ancient Broadsword Planted in Soil -->
  <g id="planted_sword" transform="translate(512, 540)">
    <!-- Red aura around blade entry point -->
    <ellipse cx="0" cy="180" rx="80" ry="24" fill="url(#sword_glow)"/>

    <!-- Sword Blade -->
    <polygon points="-12,-220 12,-220 16,180 -16,180" fill="url(#blade_steel)"/>
    <line x1="0" y1="-220" x2="0" y2="180" stroke="#0f172a" stroke-width="2"/>

    <!-- Crossguard -->
    <rect x="-70" y="-232" width="140" height="16" rx="4" fill="#475569" stroke="#94a3b8" stroke-width="2"/>
    <circle cx="0" cy="-224" r="8" fill="#ffd166"/>

    <!-- Grip and Pommel -->
    <rect x="-8" y="-310" width="16" height="78" rx="3" fill="#1e293b"/>
    <line x1="-8" y1="-290" x2="8" y2="-290" stroke="#94a3b8" stroke-width="2"/>
    <line x1="-8" y1="-270" x2="8" y2="-270" stroke="#94a3b8" stroke-width="2"/>
    <line x1="-8" y1="-250" x2="8" y2="-250" stroke="#94a3b8" stroke-width="2"/>
    <circle cx="0" cy="-322" r="14" fill="#475569" stroke="#cbd5e1" stroke-width="3"/>
  </g>

  <!-- Glowing Embers rising into wind -->
  {embers_str}

  <!-- Title Banner -->
  {title_svg}

  <!-- Vignette -->
  <rect width="1024" height="1024" fill="url(#vignette_ash)" pointer-events="none"/>
</svg>"""

TRACKS = [
    ("ost_broken_monolith", make_broken_monolith_svg),
    ("ost_city_of_pearls", make_city_of_pearls_svg),
    ("ost_tears_of_porcelain", make_tears_of_porcelain_svg),
    ("ost_hymn_of_the_ancients", make_hymn_of_the_ancients_svg),
    ("ost_ashes_of_destiny", make_ashes_of_destiny_svg),
]

def main():
    print("=== Generating Automata Suite Part 2 Scenic Cover SVGs ===")
    for track_id, generator_func in TRACKS:
        svg_content = generator_func()
        svg_path = os.path.join(TEMP_SVG_DIR, f"{track_id}.svg")
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write(svg_content)
        print(f"  [OK] Generated {track_id}.svg ({len(svg_content)} bytes)")

    # GDScript batch rasterizer
    gd_batch_script = """extends SceneTree

const TRACK_MAP: Dictionary = {
	"ost_broken_monolith": "res://../scratch/automata_svgs/ost_broken_monolith.svg",
	"ost_city_of_pearls": "res://../scratch/automata_svgs/ost_city_of_pearls.svg",
	"ost_tears_of_porcelain": "res://../scratch/automata_svgs/ost_tears_of_porcelain.svg",
	"ost_hymn_of_the_ancients": "res://../scratch/automata_svgs/ost_hymn_of_the_ancients.svg",
	"ost_ashes_of_destiny": "res://../scratch/automata_svgs/ost_ashes_of_destiny.svg",
}

func _init() -> void:
	print("[batch_cover_rasterizer_part2] Starting ThorVG render of 5 new covers...")
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
	print("[batch_cover_rasterizer_part2] All done!")
	quit()
"""

    rasterizer_path = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/godot/tests/rasterize_automata_covers_part2.gd"
    with open(rasterizer_path, "w", encoding="utf-8") as f:
        f.write(gd_batch_script)

    print("Batch rasterizer updated.")

if __name__ == "__main__":
    main()
