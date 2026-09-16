#!/usr/bin/env python3
"""Hard per-region numbers for the aligned A/B render comparison.

Prints, for a grid of fixed windows inside the body box (coordinates given as
fractions of the box, so they are anchored to the measured body, not eyeballed),
the mean RGB of outfit-A's pixels and of outfit-B's pixels at the SAME body
location, and the aligned body-band breakdown. These are the numbers the
evidence file quotes for "where does the outfit change show".
"""
import json
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "render_1280x720.log")
PNG_AB = os.path.join(HERE, "outfit_ab_side_by_side_1280x720.png")
log = open(LOG, encoding="utf-8", errors="replace").read()

xt = re.search(r"x_span_px=([-\d.]+)\.\.([-\d.]+)", log)
X0 = float(xt.group(1))
m2 = re.search(r"FRAMING_a foot_px=\([-\d.]+,([-\d.]+)\)", log)
foot_y = float(m2.group(1))
m3 = re.search(r"head_px=\(([-\d.]+),([-\d.]+)\)", log)
head_y = float(m3.group(2))
dx = float(re.search(r"FRAMING_SHIFT_PX dx=([-\d.]+)", log).group(1))

img = np.asarray(Image.open(PNG_AB).convert("RGB")).astype(np.float64)
H = int(round(foot_y - head_y))
X0i, Y0i = int(round(X0)), int(round(head_y))


def sample(x0, y0, w, h, sx, sy):
    xs = np.clip(x0 + np.arange(w) + sx, 0, img.shape[1] - 1.001)
    ys = np.clip(y0 + np.arange(h) + sy, 0, img.shape[0] - 1.001)
    xi = np.floor(xs).astype(int); yi = np.floor(ys).astype(int)
    fx = (xs - xi)[None, :, None]; fy = (ys - yi)[:, None, None]
    return (img[np.ix_(yi, xi)] * (1 - fx) * (1 - fy) + img[np.ix_(yi, xi + 1)] * fx * (1 - fy)
            + img[np.ix_(yi + 1, xi)] * (1 - fx) * fy + img[np.ix_(yi + 1, xi + 1)] * fx * fy)


A = sample(X0i, Y0i, 301, H, 0.0, 0.0)
B = sample(X0i, Y0i, 301, H, dx, 0.0)

# Windows as (x_frac0, x_frac1, y_frac0, y_frac1) of the body box. x_frac 0 is
# the left edge of the unprojected shoulder span, y_frac 0 is the head.
WIN = [
    ("head",      0.30, 0.70, 0.02, 0.10),
    ("neck_chest", 0.30, 0.70, 0.12, 0.20),
    ("upper_back", 0.25, 0.75, 0.20, 0.32),
    ("mid_torso",  0.30, 0.70, 0.32, 0.45),
    ("waist_hip",  0.25, 0.75, 0.45, 0.56),
    ("shorts",     0.22, 0.78, 0.56, 0.68),
    ("thigh",      0.25, 0.75, 0.70, 0.82),
    ("shin",       0.25, 0.75, 0.82, 0.94),
    ("feet",       0.20, 0.80, 0.94, 0.99),
]
res = {}
for name, fx0, fx1, fy0, fy1 in WIN:
    x0, x1 = int(301 * fx0), int(301 * fx1)
    y0, y1 = int(H * fy0), int(H * fy1)
    a = A[y0:y1, x0:x1].reshape(-1, 3)
    b = B[y0:y1, x0:x1].reshape(-1, 3)
    d = a - b
    e = np.sqrt((d ** 2).sum(axis=1))
    res[name] = {
        "A_mean_rgb_255": [round(float(v), 1) for v in a.mean(axis=0)],
        "B_mean_rgb_255": [round(float(v), 1) for v in b.mean(axis=0)],
        "mean_abs_diff_255": round(float(np.abs(d).mean()), 3),
        "frac_pixels_euclid_gt10": round(float((e > 10).mean()), 4),
        "max_euclid_255": round(float(e.max()), 2),
    }

bands = {}
for name, f0, f1 in [("head_0-12pct", 0.0, 0.12), ("upper_14-60pct", 0.14, 0.60),
                     ("lower_55-98pct", 0.55, 0.98), ("feet_94-100pct", 0.94, 1.0)]:
    y0, y1 = int(H * f0), int(H * f1)
    d = (A[y0:y1] - B[y0:y1]).reshape(-1, 3)
    bands[name] = {"mean_abs_255": round(float(np.abs(d).mean()), 3),
                   "frac_gt10": round(float((np.sqrt((d ** 2).sum(axis=1)) > 10).mean()), 4)}

out = {"windows": res, "bands": bands, "body_box_height_px": H}
print(json.dumps(out, indent=1))
with open(os.path.join(HERE, "measure-regions.json"), "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=1)
