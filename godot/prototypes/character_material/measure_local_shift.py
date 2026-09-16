#!/usr/bin/env python3
"""The measurement that survives the perspective disparity.

Copy A sits at world x=-0.75, copy B at x=+0.75, both 2.6 m from the camera.
A rigid world translation is NOT a screen translation under perspective: a
surface point 0.25 m nearer the camera than the model origin shifts by
1.5*f/(2.35) instead of 1.5*f/(2.6), i.e. ~11% more. Any comparison that uses
one constant screen shift therefore reports large differences wherever the body
is not at the origin plane - differences that vanish if you align locally.

So: for every window (and for the whole body box) this script searches the
LOCAL shift that minimises the mean absolute difference between the two
rendered regions, and reports the residual at that best shift. That residual is
the honest in-engine colour/surface difference; the size of the local shift
that was needed is itself reported, because it is the disparity the geometry
predicts.

Validation of the method on the same data: the identical search run on copy A's
region against ITSELF must return shift 0 and residual 0.
"""
import json
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "render_1280x720.log")
log = open(LOG, encoding="utf-8", errors="replace").read()

X0 = float(re.search(r"x_span_px=([-\d.]+)\.\.", log).group(1))
foot_y = float(re.search(r"FRAMING_a foot_px=\([-\d.]+,([-\d.]+)\)", log).group(1))
head_y = float(re.search(r"head_px=\([-\d.]+,[-\d.]+\)", log).group(0).split(",")[1].rstrip(")"))
head_y = float(head_y)
dx = float(re.search(r"FRAMING_SHIFT_PX dx=([-\d.]+)", log).group(1))

img = np.asarray(Image.open(os.path.join(HERE, "outfit_ab_side_by_side_1280x720.png")).convert("RGB")).astype(np.float64)
H = int(round(foot_y - head_y))
X0i, Y0i = int(round(X0)), int(round(head_y))
BW = 301


def sample(x0, y0, w, h, sx, sy):
    xs = np.clip(x0 + np.arange(w) + sx, 0, img.shape[1] - 1.001)
    ys = np.clip(y0 + np.arange(h) + sy, 0, img.shape[0] - 1.001)
    xi = np.floor(xs).astype(int); yi = np.floor(ys).astype(int)
    fx = (xs - xi)[None, :, None]; fy = (ys - yi)[:, None, None]
    return (img[np.ix_(yi, xi)] * (1 - fx) * (1 - fy) + img[np.ix_(yi, xi + 1)] * fx * (1 - fy)
            + img[np.ix_(yi + 1, xi)] * (1 - fx) * fy + img[np.ix_(yi + 1, xi + 1)] * fx * fy)


SEARCH = np.arange(-6.0, 6.01, 0.25)


def best_shift(x0, y0, w, h, base_dx, base_dy=0.0):
    A = sample(x0, y0, w, h, 0.0, base_dy)
    best = None
    for sx in SEARCH:
        for sy in np.arange(-2.0, 2.01, 0.5):
            B = sample(x0, y0, w, h, base_dx + sx, base_dy + sy)
            v = float(np.abs(A - B).mean())
            if best is None or v < best[0]:
                best = (v, float(sx), float(sy), B)
    v, sx, sy, B = best
    d = (A - B).reshape(-1, 3)
    e = np.sqrt((d ** 2).sum(axis=1))
    return {
        "mean_abs_at_best_shift_255": round(v, 4),
        "local_shift_px": [round(sx, 2), round(sy, 2)],
        "total_shift_px": [round(base_dx + sx, 3), round(base_dy + sy, 3)],
        "frac_pixels_euclid_gt10": round(float((e > 10).mean()), 5),
        "frac_pixels_euclid_gt5": round(float((e > 5).mean()), 5),
        "mean_signed_diff_255": [round(float(x), 3) for x in d.mean(axis=0)],
        "A_mean_rgb_255": [round(float(x), 2) for x in A.reshape(-1, 3).mean(axis=0)],
        "B_mean_rgb_255": [round(float(x), 2) for x in B.reshape(-1, 3).mean(axis=0)],
    }


WIN = [
    ("whole_body", 0.0, 1.0, 0.0, 1.0),
    ("head", 0.30, 0.70, 0.02, 0.10),
    ("upper_back", 0.25, 0.75, 0.20, 0.32),
    ("mid_torso", 0.30, 0.70, 0.32, 0.45),
    ("waist_hip", 0.25, 0.75, 0.45, 0.56),
    ("shorts", 0.22, 0.78, 0.56, 0.68),
    ("thigh", 0.25, 0.75, 0.70, 0.82),
    ("feet", 0.20, 0.80, 0.94, 0.99),
]

out = {}
for name, fx0, fx1, fy0, fy1 in WIN:
    x0, x1 = X0i + int(BW * fx0), X0i + int(BW * fx1)
    y0, y1 = Y0i + int(H * fy0), Y0i + int(H * fy1)
    out[name] = best_shift(x0, y0, x1 - x0, y1 - y0, dx)

# Method validation: the same search, copy A against itself (base shift 0).
out["VALIDATION_A_vs_A_self_search"] = best_shift(X0i + 40, Y0i + 100, 220, 300, 0.0)

print(json.dumps(out, indent=1))
with open(os.path.join(HERE, "measure-local-shift.json"), "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=1)
