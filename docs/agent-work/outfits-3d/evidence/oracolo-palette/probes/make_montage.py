#!/usr/bin/env python3
"""PROBE (scratch): build one side-by-side montage so the card, the base sprite, the
signature sprite and the baked 3D model can be compared by eye at the same display height.

Not an artifact. Writes to scratch only.
"""
import os, sys
from PIL import Image

REPO = "/Users/alessiofantini/Documents/steam-circuit-padel-11m"
OUT = "/Users/alessiofantini/.hermes/profiles/dev-work/cache/scratch/oracolo/montage.png"
EV = os.path.join(REPO, "docs/agent-work/outfits-3d/evidence/oracolo-palette")
H = 620


def frame0(path, frames, pad=6):
    im = Image.open(os.path.join(REPO, path)).convert("RGBA")
    w = im.size[0] // frames
    f = im.crop((0, 0, w, im.size[1]))
    bb = f.getbbox()
    if bb:
        f = f.crop(bb)
    s = H / f.size[1]
    return f.resize((max(1, int(f.size[0] * s)), H), Image.LANCZOS)


def fit(path, bg=(24, 24, 30)):
    im = Image.open(path).convert("RGBA")
    bb = im.getbbox()
    if bb:
        im = im.crop(bb)
    s = H / im.size[1]
    im = im.resize((max(1, int(im.size[0] * s)), H), Image.LANCZOS)
    canvas = Image.new("RGBA", im.size, bg + (255,))
    canvas.alpha_composite(im)
    return canvas


panels = [
    ("CARD signature-preview", fit(os.path.join(REPO, "assets/outfits/oracolo/signature-preview.webp"))),
    ("SPRITE base idle f0", frame0("assets/sprites/oracolo-idle-consistent-v2.webp", 4)),
    ("SPRITE sig idle f0", frame0("assets/outfits/oracolo/signature/idle-v2.webp", 4)),
    ("SPRITE base idle f2", frame0("assets/sprites/oracolo-idle-consistent-v2.webp", 4)),
    ("MODEL baked front", fit(os.path.join(EV, "model-front.png"))),
    ("MODEL classes front", fit(os.path.join(EV, "model-front-classes.png"))),
]

gap = 14
W = sum(p.size[0] for _, p in panels) + gap * (len(panels) + 1)
canvas = Image.new("RGB", (W, H + 26), (12, 12, 16))
x = gap
for i, (name, p) in enumerate(panels):
    canvas.paste(p.convert("RGB"), (x, 20))
    x += p.size[0] + gap
canvas.save(OUT)
print("WROTE", OUT, canvas.size)
for name, p in panels:
    print("  %-24s %dx%d" % (name, p.size[0], p.size[1]))
