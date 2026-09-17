#!/usr/bin/env python3
"""Coarse ASCII map of the yellow-ish pixels in a capture. Diagnostic, stdlib only.

Built to answer one question the vision pass could not: is the active athlete's
yellow zone actually in the frame? The ball and its landing ring are yellow too, so
a bare count says nothing — their SHAPE does. A ball is a dot; the zone is an
ellipse 1.74 m across and 0.60 m deep, so it prints as a wide flat band around one
athlete and nothing else in the frame comes close.

    python3 godot/game/tools/yellow_map.py godot/game/out/rally.png [yellow|cyan]

`cyan` maps the athletes' own tint rings (`court.gd:273-284`, the player pair's
colour `#00e5ff`), which sit at the same 3 cm height as the active athlete's zone.
If the cyan rings print and the yellow one does not, the height is fine and the zone
is at fault; if neither prints, everything at 3 cm is buried under the play surface.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import inspect_png as ip  # noqa: E402


def is_target(r, g, b, mode):
    if mode == "cyan":
        return g > 140 and b > 150 and r < 130 and b > r + 60
    return r > 140 and g > 130 and b < 120 and r > b + 40


def main(path, mode="yellow", window=None, cell=4):
    """`window` is `x,y,w,h` in pixels, drawn as a fine map of `cell`-pixel cells.

    A coarse whole-frame map says whether a mark is anywhere; a window says what
    SHAPE it is — an outline at the right radius, or a smudge on the athlete.
    """
    _data, width, height, channels, pixels = ip.read_png(path)
    # The image's own stride, kept aside: the window below overwrites `width` and
    # `height`, and reading rows with the window's width as the stride decodes
    # garbage — it printed a striped "yellow floor" where the court is plain blue.
    img_w = width
    x0, y0 = 0, 0
    if window:
        x0, y0, width, height = (int(v) for v in window.split(","))
    # Ceiling, not floor: a window whose size is not a multiple of the cell size has
    # a last partial cell, and flooring it dropped that column and raised IndexError.
    cols = max(1, -(-width // cell))
    rows = max(1, -(-height // cell))
    grid = [[0] * cols for _ in range(rows)]
    total = 0
    for y in range(y0, y0 + height):
        base = y * img_w * channels
        gy = (y - y0) // cell
        for x in range(x0, x0 + width):
            i = base + x * channels
            r, g, b = pixels[i], pixels[i + 1], pixels[i + 2]
            if is_target(r, g, b, mode):
                grid[gy][(x - x0) // cell] += 1
                total += 1
    print("# %s window=%s cell=%d mode=%s pixels=%d" % (path, window or "full", cell, mode, total))
    print("#     %s" % "".join(str(((c * cell + x0) // 100) % 10) for c in range(cols)))
    for gy, row in enumerate(grid):
        # `#` marks a cell with half its pixels or more, `+` any, `.` none.
        print("%4d %s" % (y0 + gy * cell, "".join(
            "#" if c >= cell * cell / 2 else ("+" if c else ".") for c in row)))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "yellow",
         sys.argv[3] if len(sys.argv) > 3 else None,
         int(sys.argv[4]) if len(sys.argv) > 4 else 4)
