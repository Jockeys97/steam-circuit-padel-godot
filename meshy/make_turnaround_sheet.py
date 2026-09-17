#!/usr/bin/env python3
"""Assemble a character view set into one contact sheet.

Pillow only, no numpy. Views are hstacked in the order given, with 24 px white
gutters so neither the sheet nor the crops can bleed into a neighbour.

Usage:
    python3 meshy/make_turnaround_sheet.py <prefix> <view> [view ...]
Examples:
    python3 meshy/make_turnaround_sheet.py burattino front side back 45
    python3 meshy/make_turnaround_sheet.py fornaio front back 45-left 45-right
Reads:
    meshy/views/<prefix>-<view>.png
Writes:
    meshy/<prefix>-turnaround.png (next to this script)
"""
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
args = sys.argv[1:]
if len(args) < 2:
    print("usage: make_turnaround_sheet.py <prefix> <view> [view ...]")
    raise SystemExit(2)

prefix, views = args[0], args[1:]

imgs = [Image.open(HERE / "views" / f"{prefix}-{view}.png").convert("RGB") for view in views]
height = max(im.height for im in imgs)
scaled = []
for im in imgs:
    if im.height != height:
        width = round(im.width * height / im.height)
        im = im.resize((width, height), Image.Resampling.LANCZOS)
    scaled.append(im)

GUTTER = 24
BG = (255, 255, 255)
total_w = sum(im.width for im in scaled) + GUTTER * (len(scaled) + 1)
sheet = Image.new("RGB", (total_w, height + GUTTER * 2), BG)
x = GUTTER
for im in scaled:
    sheet.paste(im, (x, GUTTER))
    x += im.width + GUTTER

out = HERE / f"{prefix}-turnaround.png"
sheet.save(out, optimize=True)
print(f"wrote {out} {sheet.width}x{sheet.height}")
for view, im in zip(views, scaled):
    print(f"  {view}: {im.width}x{im.height}")
