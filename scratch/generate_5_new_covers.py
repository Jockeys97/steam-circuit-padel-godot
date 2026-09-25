#!/usr/bin/env python3
"""
generate_5_new_covers.py — Generates vector SVG covers for the 5 new tracks.
"""

import os, math

SCRATCH_DIR = "/Users/alessiofantini/Documents/steam-circuit-padel-11m/scratch"
os.makedirs(SCRATCH_DIR, exist_ok=True)

def header(defs=""):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="8" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="softGlow">
      <feGaussianBlur stdDeviation="4" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    {defs}
  </defs>
"""

def footer(title, subtitle, tag_color="#00f5d4", title_color="#ffffff", scene_text="EPIC CLIMAX SUITE"):
    return f"""
  <!-- Title Badge inside disc radius -->
  <rect x="200" y="675" width="624" height="40" rx="20" fill="#080d1a" fill-opacity="0.92" stroke="{tag_color}" stroke-width="2.5" filter="url(#softGlow)"/>
  <text x="512" y="701" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="15" font-weight="bold" fill="{tag_color}" text-anchor="middle" letter-spacing="3">{subtitle}</text>

  <!-- Title in bold high-contrast typography -->
  <text x="512" y="768" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="34" font-weight="900" fill="#ffffff" text-anchor="middle" letter-spacing="3" filter="url(#glow)">{title}</text>
  <text x="512" y="768" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="34" font-weight="900" fill="{title_color}" text-anchor="middle" letter-spacing="3">{title}</text>

  <!-- Lore tag below -->
  <text x="512" y="805" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif" font-size="14" font-weight="600" fill="#90e0ef" text-anchor="middle" letter-spacing="2">{scene_text}</text>
</svg>"""

# 1. APEX VICTORY
def svg_apex_victory():
    defs = """
    <radialGradient id="apexBg" cx="50%" cy="40%" r="65%">
      <stop offset="0%" stop-color="#1f0933"/>
      <stop offset="50%" stop-color="#0d0417"/>
      <stop offset="100%" stop-color="#020005"/>
    </radialGradient>
    <linearGradient id="neonGrid" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ff007f" stop-opacity="0"/>
      <stop offset="60%" stop-color="#00f0ff" stop-opacity="0.6"/>
      <stop offset="100%" stop-color="#ff007f" stop-opacity="0.9"/>
    </linearGradient>
    """
    body = """
  <rect width="1024" height="1024" fill="url(#apexBg)"/>
  <!-- Perspective Cyber Grid -->
  <g stroke="url(#neonGrid)" stroke-width="2" opacity="0.6">
    <line x1="512" y1="280" x2="100" y2="650"/>
    <line x1="512" y1="280" x2="250" y2="650"/>
    <line x1="512" y1="280" x2="400" y2="650"/>
    <line x1="512" y1="280" x2="512" y2="650"/>
    <line x1="512" y1="280" x2="624" y2="650"/>
    <line x1="512" y1="280" x2="774" y2="650"/>
    <line x1="512" y1="280" x2="924" y2="650"/>
    <line x1="160" y1="520" x2="864" y2="520"/>
    <line x1="130" y1="570" x2="894" y2="570"/>
    <line x1="100" y1="630" x2="924" y2="630"/>
  </g>

  <!-- Glowing Neon Apex Diamond / Polygon -->
  <polygon points="512,180 660,340 512,500 364,340" fill="#0b0214" stroke="#ff007f" stroke-width="4" filter="url(#glow)"/>
  <polygon points="512,210 630,340 512,470 394,340" fill="none" stroke="#00f0ff" stroke-width="2.5"/>
  <circle cx="512" cy="340" r="50" fill="#ff007f" fill-opacity="0.3" filter="url(#glow)"/>
  <circle cx="512" cy="340" r="20" fill="#00f0ff" filter="url(#softGlow)"/>

  <!-- Speed laser trails -->
  <line x1="200" y1="340" x2="360" y2="340" stroke="#00f0ff" stroke-width="3" stroke-dasharray="12,8" filter="url(#softGlow)"/>
  <line x1="664" y1="340" x2="824" y2="340" stroke="#ff007f" stroke-width="3" stroke-dasharray="12,8" filter="url(#softGlow)"/>
    """
    return header(defs) + body + footer("APEX VICTORY", "CYBERPUNK DARKSYNTH CLIMAX", "#00f0ff", "#ff70a6", "BOSS FIGHT • CYBER CIRCUIT NEMESIS")

# 2. CLASH OF CHAMPIONS
def svg_clash_of_champions():
    defs = """
    <radialGradient id="clashBg" cx="50%" cy="40%" r="65%">
      <stop offset="0%" stop-color="#3d1400"/>
      <stop offset="50%" stop-color="#1f0700"/>
      <stop offset="100%" stop-color="#050100"/>
    </radialGradient>
    <linearGradient id="fireGold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffe600"/>
      <stop offset="50%" stop-color="#ff5400"/>
      <stop offset="100%" stop-color="#990000"/>
    </linearGradient>
    """
    body = """
  <rect width="1024" height="1024" fill="url(#clashBg)"/>

  <!-- Colosseum Arches Silhouette -->
  <path d="M 180,640 L 180,420 Q 512,260 844,420 L 844,640 Z" fill="none" stroke="#ff5400" stroke-width="3" stroke-opacity="0.35"/>
  <path d="M 240,640 L 240,450 Q 512,310 784,450 L 784,640 Z" fill="none" stroke="#ffe600" stroke-width="2" stroke-opacity="0.3"/>

  <!-- Twin Clashing Golden Rackets -->
  <g transform="translate(512, 380)">
    <!-- Shockwave Impact Burst -->
    <circle cx="0" cy="0" r="140" fill="none" stroke="#ff5400" stroke-width="3" stroke-dasharray="15,10" opacity="0.6" filter="url(#glow)"/>
    <circle cx="0" cy="0" r="80" fill="#ffe600" fill-opacity="0.25" filter="url(#glow)"/>
    <circle cx="0" cy="0" r="25" fill="#ffffff" filter="url(#glow)"/>

    <!-- Left Racket leaning right -->
    <g transform="rotate(-35) translate(-70, 0)">
      <ellipse cx="0" cy="0" rx="60" ry="85" fill="#120400" stroke="url(#fireGold)" stroke-width="4" filter="url(#softGlow)"/>
      <line x1="-30" y1="0" x2="30" y2="0" stroke="#ffe600" stroke-width="1.5" opacity="0.7"/>
      <line x1="0" y1="-50" x2="0" y2="50" stroke="#ffe600" stroke-width="1.5" opacity="0.7"/>
      <rect x="-6" y="85" width="12" height="65" rx="3" fill="#ffe600"/>
    </g>

    <!-- Right Racket leaning left -->
    <g transform="rotate(35) translate(70, 0)">
      <ellipse cx="0" cy="0" rx="60" ry="85" fill="#120400" stroke="url(#fireGold)" stroke-width="4" filter="url(#softGlow)"/>
      <line x1="-30" y1="0" x2="30" y2="0" stroke="#ffe600" stroke-width="1.5" opacity="0.7"/>
      <line x1="0" y1="-50" x2="0" y2="50" stroke="#ffe600" stroke-width="1.5" opacity="0.7"/>
      <rect x="-6" y="85" width="12" height="65" rx="3" fill="#ffe600"/>
    </g>
  </g>
    """
    return header(defs) + body + footer("CLASH OF CHAMPIONS", "SYMPHONIC BATTLE SUITE", "#ffbe0b", "#ffd166", "MATCH POINT CLIMAX • ARENA CALDERA")

# 3. REFLEX STRIKE
def svg_reflex_strike():
    defs = """
    <radialGradient id="reflexBg" cx="50%" cy="40%" r="65%">
      <stop offset="0%" stop-color="#002b36"/>
      <stop offset="50%" stop-color="#00141a"/>
      <stop offset="100%" stop-color="#00070a"/>
    </radialGradient>
    <linearGradient id="lightning" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00f5d4"/>
      <stop offset="60%" stop-color="#70e000"/>
      <stop offset="100%" stop-color="#ffff3f"/>
    </linearGradient>
    """
    body = """
  <rect width="1024" height="1024" fill="url(#reflexBg)"/>

  <!-- High-frequency Sonic Waves -->
  <circle cx="512" cy="380" r="220" fill="none" stroke="#00f5d4" stroke-width="2" stroke-dasharray="20,10" opacity="0.3"/>
  <circle cx="512" cy="380" r="170" fill="none" stroke="#70e000" stroke-width="2.5" stroke-dasharray="14,8" opacity="0.45"/>
  <circle cx="512" cy="380" r="120" fill="none" stroke="#ffff3f" stroke-width="3" stroke-dasharray="8,6" opacity="0.6"/>

  <!-- Dynamic Lightning Bolt Reflex Path -->
  <polygon points="512,160 550,290 470,330 570,440 450,470 540,600 480,480 540,430 460,340 520,290"
           fill="url(#lightning)" filter="url(#glow)"/>

  <!-- High-Speed Padel Ball with Motion Blur -->
  <circle cx="512" cy="380" r="38" fill="#ffff3f" filter="url(#glow)"/>
  <circle cx="512" cy="380" r="22" fill="#ffffff"/>
  <ellipse cx="440" cy="380" rx="30" ry="15" fill="#70e000" fill-opacity="0.5" filter="url(#softGlow)"/>
  <ellipse cx="370" cy="380" rx="20" ry="8" fill="#00f5d4" fill-opacity="0.3"/>
    """
    return header(defs) + body + footer("REFLEX STRIKE", "HIGH-SPEED ACTION BREAKBEAT", "#00f5d4", "#ccff33", "FAST COMBAT • REFLEX VOLLEY DUEL")

# 4. IRON JUGGERNAUT
def svg_iron_juggernaut():
    defs = """
    <radialGradient id="ironBg" cx="50%" cy="40%" r="65%">
      <stop offset="0%" stop-color="#2b1509"/>
      <stop offset="50%" stop-color="#140a04"/>
      <stop offset="100%" stop-color="#050201"/>
    </radialGradient>
    <linearGradient id="bronzeGear" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#e0a96d"/>
      <stop offset="50%" stop-color="#99582a"/>
      <stop offset="100%" stop-color="#432818"/>
    </linearGradient>
    """
    # Giant gear
    cog_lines = ""
    for i in range(12):
        angle = i * (2 * math.pi / 12)
        cx = 512 + 130 * math.cos(angle)
        cy = 380 + 130 * math.sin(angle)
        cog_lines += f'<rect x="{cx-15:.1f}" y="{cy-15:.1f}" width="30" height="30" rx="4" fill="#e0a96d" transform="rotate({math.degrees(angle):.1f} {cx:.1f} {cy:.1f})"/>'

    body = f"""
  <rect width="1024" height="1024" fill="url(#ironBg)"/>

  <!-- Piston Steam Release Jets -->
  <polygon points="512,380 300,120 360,100" fill="#ffffff" fill-opacity="0.2" filter="url(#glow)"/>
  <polygon points="512,380 724,120 664,100" fill="#ffffff" fill-opacity="0.2" filter="url(#glow)"/>

  <!-- Colossal Steampunk Cogwheel -->
  <g filter="url(#softGlow)">
    <circle cx="512" cy="380" r="140" fill="url(#bronzeGear)" stroke="#e0a96d" stroke-width="4"/>
    {cog_lines}
    <circle cx="512" cy="380" r="75" fill="#140a04" stroke="#ff5400" stroke-width="3"/>
  </g>

  <!-- Pressure Gauge in red zone -->
  <g transform="translate(512, 380)">
    <circle cx="0" cy="0" r="50" fill="#080402" stroke="#e0a96d" stroke-width="3"/>
    <!-- Red warning arc -->
    <path d="M 0,-40 A 40 40 0 0 1 35,-15" fill="none" stroke="#ff0000" stroke-width="6" stroke-linecap="round" filter="url(#glow)"/>
    <!-- Needle pointing at MAX -->
    <line x1="0" y1="0" x2="30" y2="-25" stroke="#ffcc00" stroke-width="3.5" stroke-linecap="round"/>
    <circle cx="0" cy="0" r="8" fill="#e0a96d"/>
  </g>
    """
    return header(defs) + body + footer("IRON JUGGERNAUT", "INDUSTRIAL STEAMPUNK METAL", "#e0a96d", "#ffaa00", "MECHA BOSS • FOUNDRY POWER CLIMAX")

# 5. THUNDER STRIKE
def svg_thunder_strike():
    defs = """
    <radialGradient id="thunderBg" cx="50%" cy="40%" r="65%">
      <stop offset="0%" stop-color="#141a29"/>
      <stop offset="50%" stop-color="#080b12"/>
      <stop offset="100%" stop-color="#020305"/>
    </radialGradient>
    <linearGradient id="goldLightning" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffffff"/>
      <stop offset="40%" stop-color="#ffd60a"/>
      <stop offset="100%" stop-color="#ff9100"/>
    </linearGradient>
    """
    body = """
  <rect width="1024" height="1024" fill="url(#thunderBg)"/>

  <!-- Japanese Torii Gate Silhouette in Background -->
  <g fill="#0b0e14" stroke="#ffd60a" stroke-width="2" stroke-opacity="0.4">
    <!-- Top curved beam -->
    <path d="M 280,240 Q 512,210 744,240 L 730,265 Q 512,235 294,265 Z"/>
    <!-- Second beam -->
    <rect x="330" y="290" width="364" height="20"/>
    <!-- Columns -->
    <rect x="370" y="265" width="28" height="375"/>
    <rect x="626" y="265" width="28" height="375"/>
  </g>

  <!-- Golden Thunder Dragons / Lightning Bolts Striking Center -->
  <path d="M 512,120 L 530,260 L 480,290 L 550,400 L 460,430 L 512,560"
        fill="none" stroke="url(#goldLightning)" stroke-width="6" stroke-linecap="round" filter="url(#glow)"/>
  <path d="M 400,200 L 440,290 L 420,310 L 480,400"
        fill="none" stroke="#ffd60a" stroke-width="3" stroke-linecap="round" filter="url(#softGlow)"/>
  <path d="M 624,200 L 584,290 L 604,310 L 544,400"
        fill="none" stroke="#ffd60a" stroke-width="3" stroke-linecap="round" filter="url(#softGlow)"/>

  <!-- Sacred Padel Core Orb -->
  <circle cx="512" cy="400" r="55" fill="#0b0e14" stroke="#ffd60a" stroke-width="4" filter="url(#glow)"/>
  <circle cx="512" cy="400" r="28" fill="#ffd60a" filter="url(#glow)"/>
  <circle cx="512" cy="400" r="12" fill="#ffffff"/>
    """
    return header(defs) + body + footer("THUNDER STRIKE", "ANIME BATTLE ROCK & SHAMISEN", "#ffd60a", "#ffea00", "BATTLE ROCK • ARENA TORII SHOWDOWN")

tracks = {
    "ost_apex_victory.svg": svg_apex_victory(),
    "ost_clash_of_champions.svg": svg_clash_of_champions(),
    "ost_reflex_strike.svg": svg_reflex_strike(),
    "ost_iron_juggernaut.svg": svg_iron_juggernaut(),
    "ost_thunder_strike.svg": svg_thunder_strike()
}

for fname, content in tracks.items():
    p = os.path.join(SCRATCH_DIR, fname)
    with open(p, "w") as f:
        f.write(content)
    print(f"Generated {p}")
