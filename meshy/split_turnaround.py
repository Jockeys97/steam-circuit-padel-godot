#!/usr/bin/env python3
"""Split a 4-view turnaround sheet into one PNG per view.

Usage: python3 split_turnaround.py <sheet.png> [output_dir]

Finds each figure by column ink profile, splits merged clusters at the internal ink
minimum, trims each figure to its own bounding box, then adds a uniform white border
so a neighbouring figure can never bleed into the crop.

Pillow only, no numpy.
"""
import sys, os
from PIL import Image

VIEWS = ["front", "side", "back", "45"]
MARGIN = 24
INK_THRESHOLD = 240   # a pixel is "ink" if any RGB channel is below this
COL_ACTIVE = 3        # per-column ink ratio (0-255) above which a column counts as active
MIN_RUN = 25          # smallest believable figure width in px


def col_profile(mask):
    return list(mask.resize((mask.width, 1), Image.BOX).get_flattened_data())


def row_profile(mask):
    return list(mask.resize((1, mask.height), Image.BOX).get_flattened_data())


def to_mask(im):
    return im.convert("L").point(lambda v: 255 if v < INK_THRESHOLD else 0)


def segments(mask, target=4):
    colp = col_profile(mask)
    active = [v > COL_ACTIVE for v in colp]
    runs, start = [], None
    for i, v in enumerate(active):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if i - start > MIN_RUN:
                runs.append((start, i))
            start = None
    if start is not None and mask.width - start > MIN_RUN:
        runs.append((start, mask.width))

    # if figures touch, the runs merge: keep splitting the widest cluster at its
    # internal ink minimum until we have the expected count
    while len(runs) < target:
        idx = max(range(len(runs)), key=lambda i: runs[i][1] - runs[i][0])
        x0, x1 = runs[idx]
        lo, hi = x0 + int(0.30 * (x1 - x0)), x0 + int(0.70 * (x1 - x0))
        if hi - lo < 10:
            break
        colp = col_profile(mask)
        cut = min(range(lo, hi), key=lambda x: colp[x])
        runs[idx:idx + 1] = [(x0, cut), (cut, x1)]
    return runs


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sheet = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(sheet), "views")
    os.makedirs(outdir, exist_ok=True)

    stem = os.path.basename(sheet).replace(".png", "").replace("-turnaround", "")
    im = Image.open(sheet).convert("RGB")
    mask = to_mask(im)
    runs = segments(mask)
    if len(runs) != 4:
        sys.exit(f"expected 4 figures, found {len(runs)}: {runs}")

    for name, (x0, x1) in zip(VIEWS, runs):
        slab = mask.crop((x0, 0, x1, im.height))
        cols = [i for i, v in enumerate(col_profile(slab)) if v > COL_ACTIVE]
        rows = [i for i, v in enumerate(row_profile(slab)) if v > COL_ACTIVE]
        if not cols or not rows:
            sys.exit(f"empty figure for view {name}")
        fig = im.crop((x0 + cols[0], rows[0], x0 + cols[-1] + 1, rows[-1] + 1))
        canvas = Image.new("RGB", (fig.width + 2 * MARGIN, fig.height + 2 * MARGIN), (255, 255, 255))
        canvas.paste(fig, (MARGIN, MARGIN))
        out = os.path.join(outdir, f"{stem}-{name}.png")
        canvas.save(out)
        print(f"{out}  {canvas.size}")


if __name__ == "__main__":
    main()
