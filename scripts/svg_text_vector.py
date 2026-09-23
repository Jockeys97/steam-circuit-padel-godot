import math

GLYPHS = {
    'A': "M 10,110 L 50,15 L 90,110 M 26,75 L 74,75",
    'B': "M 15,15 L 55,15 C 80,15 80,60 55,60 L 15,60 M 15,60 L 60,60 C 85,60 85,110 60,110 L 15,110 M 15,15 L 15,110",
    'C': "M 85,35 C 70,12 30,12 20,62 C 10,105 65,118 85,92",
    'D': "M 15,15 L 50,15 C 85,15 85,110 50,110 L 15,110 Z",
    'E': "M 85,15 L 15,15 L 15,110 L 85,110 M 15,62 L 70,62",
    'F': "M 85,15 L 15,15 L 15,110 M 15,62 L 70,62",
    'G': "M 85,35 C 70,12 30,12 20,62 C 10,105 60,115 85,95 L 85,62 L 55,62",
    'H': "M 15,15 L 15,110 M 85,15 L 85,110 M 15,62 L 85,62",
    'I': "M 20,15 L 80,15 M 50,15 L 50,110 M 20,110 L 80,110",
    'K': "M 15,15 L 15,110 M 80,15 L 18,65 L 82,110",
    'L': "M 15,15 L 15,110 L 85,110",
    'M': "M 15,110 L 15,15 L 50,70 L 85,15 L 85,110",
    'N': "M 15,110 L 15,15 L 85,110 L 85,15",
    'O': "M 50,15 C 15,15 15,110 50,110 C 85,110 85,15 50,15 Z",
    'P': "M 15,110 L 15,15 L 55,15 C 80,15 80,65 55,65 L 15,65",
    'R': "M 15,110 L 15,15 L 55,15 C 80,15 80,62 55,62 L 15,62 M 50,62 L 85,110",
    'S': "M 80,35 C 70,14 30,14 25,40 C 20,60 80,65 80,88 C 80,112 35,115 20,95",
    'T': "M 10,15 L 90,15 M 50,15 L 50,110",
    'U': "M 15,15 L 15,80 C 15,112 85,112 85,80 L 85,15",
    'V': "M 10,15 L 50,110 L 90,15",
    'W': "M 10,15 L 25,110 L 50,55 L 75,110 L 90,15",
    'X': "M 15,15 L 85,110 M 85,15 L 15,110",
    'Y': "M 15,15 L 50,62 L 85,15 M 50,62 L 50,110",
    'Z': "M 15,15 L 85,15 L 15,110 L 85,110",
    ' ': "",
}

def render_title_banner(text, center_x=512, center_y=900, scale=0.38, letter_spacing=14, stroke="#ffffff", stroke_width=9, accent_color="#e0c068"):
    total_w = 0
    widths = []
    for ch in text.upper():
        if ch == ' ':
            w = 50 * scale
        elif ch in ['I']:
            w = 55 * scale
        elif ch in ['M', 'W']:
            w = 105 * scale
        else:
            w = 85 * scale
        widths.append(w)
        total_w += w + letter_spacing

    total_w -= letter_spacing
    start_x = center_x - total_w / 2.0
    text_h = 120 * scale

    # Pill banner dimensions
    banner_w = total_w + 100
    banner_h = text_h + 46
    banner_x = center_x - banner_w / 2.0
    banner_y = center_y - banner_h / 2.0

    svg_parts = []

    # Elegant backdrop plate
    svg_parts.append(f'<g id="title_banner">')
    # Outer glow
    svg_parts.append(f'<rect x="{banner_x-4:.1f}" y="{banner_y-4:.1f}" width="{banner_w+8:.1f}" height="{banner_h+8:.1f}" rx="18" fill="rgba(0,0,0,0.5)" opacity="0.6"/>')
    # Main plaque
    svg_parts.append(f'<rect x="{banner_x:.1f}" y="{banner_y:.1f}" width="{banner_w:.1f}" height="{banner_h:.1f}" rx="14" fill="rgba(14,17,22,0.88)" stroke="{accent_color}" stroke-width="2" stroke-opacity="0.45"/>')
    # Ornamental hairline divider top & bottom
    svg_parts.append(f'<line x1="{banner_x+30:.1f}" y1="{banner_y+8:.1f}" x2="{banner_x+banner_w-30:.1f}" y2="{banner_y+8:.1f}" stroke="{accent_color}" stroke-width="1" stroke-opacity="0.3"/>')
    svg_parts.append(f'<line x1="{banner_x+30:.1f}" y1="{banner_y+banner_h-8:.1f}" x2="{banner_x+banner_w-30:.1f}" y2="{banner_y+banner_h-8:.1f}" stroke="{accent_color}" stroke-width="1" stroke-opacity="0.3"/>')
    # Diamond accents on sides
    svg_parts.append(f'<polygon points="{banner_x+16:.1f},{center_y} {banner_x+22:.1f},{center_y-6} {banner_x+28:.1f},{center_y} {banner_x+22:.1f},{center_y+6}" fill="{accent_color}" opacity="0.7"/>')
    svg_parts.append(f'<polygon points="{banner_x+banner_w-28:.1f},{center_y} {banner_x+banner_w-22:.1f},{center_y-6} {banner_x+banner_w-16:.1f},{center_y} {banner_x+banner_w-22:.1f},{center_y+6}" fill="{accent_color}" opacity="0.7"/>')

    # Drop shadow for text
    cur_x = start_x + 2
    cur_y = center_y - text_h / 2.0 + 2
    for ch, w in zip(text.upper(), widths):
        if ch in GLYPHS and GLYPHS[ch]:
            d = GLYPHS[ch]
            svg_parts.append(
                f'<g transform="translate({cur_x:.1f},{cur_y:.1f}) scale({scale})">'
                f'<path d="{d}" fill="none" stroke="rgba(0,0,0,0.9)" stroke-width="{stroke_width + 4}" stroke-linecap="round" stroke-linejoin="round"/>'
                f'</g>'
            )
        cur_x += w + letter_spacing

    # Main text pass
    cur_x = start_x
    cur_y = center_y - text_h / 2.0
    for ch, w in zip(text.upper(), widths):
        if ch in GLYPHS and GLYPHS[ch]:
            d = GLYPHS[ch]
            svg_parts.append(
                f'<g transform="translate({cur_x:.1f},{cur_y:.1f}) scale({scale})">'
                f'<path d="{d}" fill="none" stroke="{stroke}" stroke-width="{stroke_width}" stroke-linecap="round" stroke-linejoin="round"/>'
                f'</g>'
            )
        cur_x += w + letter_spacing

    svg_parts.append('</g>')
    return "\n".join(svg_parts)
