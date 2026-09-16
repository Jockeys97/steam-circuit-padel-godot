#!/usr/bin/env python3
"""Sub-pixel-aligned A/B comparison of the character_material renders.

Why this exists: the two copies stand dx = 501.4136 px apart on screen, so
copy B's region cannot be compared with copy A's region at integer offsets -
rounding to 501 shifts everything by 0.41 px and turns every anti-aliased
silhouette edge into a large fake difference. This script resamples copy B's
region onto copy A's exact pixel grid with bilinear interpolation, and reports
an alignment FLOOR (copy A's own region resampled by the same fractional shift
and compared with itself) so the reader can see how much of any number is
resampling artefact.

Writes: measure-aligned.json, and two derived (non-render) preview PNGs.
"""
import hashlib
import json
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(HERE, "render_1280x720.log")
PNG_AB = os.path.join(HERE, "outfit_ab_side_by_side_1280x720.png")
PNG_A = os.path.join(HERE, "outfit_a_only_1280x720.png")
PNG_B = os.path.join(HERE, "outfit_b_only_1280x720.png")

log = open(LOG, encoding="utf-8", errors="replace").read()
m = re.search(r"FRAMING_a foot_px=\([-\d.]+,[-\d.]+\) head_px=\([-\d.]+,[-\d.]+\) x_span_px=([-\d.]+)\.\.([-\d.]+)", log)
xt0, xt1 = float(m.group(1)), float(m.group(2))
m = re.search(r"FRAMING_a foot_px=\([-\d.]+,[-\d.]+\) head_px=\(([-\d.]+),([-\d.]+)\)", log)
m2 = re.search(r"FRAMING_a foot_px=\([-\d.]+,([-\d.]+)\)", log)
head_y = float(m.group(2))
foot_y = float(m2.group(1))
m = re.search(r"FRAMING_SHIFT_PX dx=([-\d.]+) dy=([-\d.]+)", log)
dx, dy = float(m.group(1)), float(m.group(2))

X0, X1 = xt0, xt1          # exact float body box of copy A
Y0, Y1 = head_y, foot_y
W = int(round(X1 - X0))
H = int(round(Y1 - Y0))


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64)


def sample(img, x0, y0, w, h, sx, sy):
    """Bilinear sample of img at (x0+i+sx, y0+j+sy) -> (h,w,3). Clamped edges."""
    xs = np.clip(x0 + np.arange(w) + sx, 0, img.shape[1] - 1.001)
    ys = np.clip(y0 + np.arange(h) + sy, 0, img.shape[0] - 1.001)
    xi = np.floor(xs).astype(int)
    yi = np.floor(ys).astype(int)
    fx = (xs - xi)[None, :, None]
    fy = (ys - yi)[:, None, None]
    a = img[np.ix_(yi, xi)]
    b = img[np.ix_(yi, xi + 1)]
    c = img[np.ix_(yi + 1, xi)]
    d = img[np.ix_(yi + 1, xi + 1)]
    return (a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy)


ab = load(PNG_AB)
a_only = load(PNG_A)
b_only = load(PNG_B)

X0i, Y0i = int(round(X0)), int(round(Y0))
A = sample(ab, X0i, Y0i, W, H, 0.0, 0.0)                 # copy A, native grid
B = sample(ab, X0i, Y0i, W, H, dx, dy)                   # copy B, warped onto A's grid
A_sh = sample(ab, X0i, Y0i, W, H, dx - round(dx), dy)     # A resampled by the same fraction

m_bg = ab[5, 5]
m_fl = ab[700, 60]
body = (np.abs(A - m_bg).sum(axis=2) > 12) & (np.abs(A - m_fl).sum(axis=2) > 12)


def stats(d):
    e = np.sqrt((d ** 2).sum(axis=1))
    n = e.size
    return {
        "pixels": int(n),
        "mean_abs_overall_255": round(float(np.abs(d).mean()), 4),
        "mean_abs_per_channel_255": [round(float(v), 4) for v in np.abs(d).mean(axis=0)],
        "rms_overall_255": round(float(np.sqrt((d ** 2).mean())), 4),
        "mean_euclidean_255": round(float(e.mean()), 4),
        "p95_euclidean_255": round(float(np.percentile(e, 95)), 4),
        "max_euclidean_255": round(float(e.max()), 4),
        "pixels_euclidean_gt5": int((e > 5).sum()),
        "frac_euclidean_gt5": round(float((e > 5).mean()), 6),
        "pixels_euclidean_gt10": int((e > 10).sum()),
        "frac_euclidean_gt10": round(float((e > 10).mean()), 6),
        "pixels_euclidean_gt25": int((e > 25).sum()),
        "frac_euclidean_gt25": round(float((e > 25).mean()), 6),
        "mean_abs_over_pixels_gt10_255": round(float(np.abs(d)[e > 10].mean()), 4) if (e > 10).any() else 0.0,
    }


d_all = A - B
d_body = A - B
out = {
    "alignment": {
        "engine_dx_px": dx,
        "engine_dy_px": dy,
        "integer_offset_used": round(dx),
        "fractional_residual_px": round(dx - round(dx), 6),
        "region_wh": [W, H],
        "body_pixels": int(body.sum()),
        "body_frac": round(float(body.mean()), 6),
    },
    "A_vs_B_aligned_ALL_PIXELS": stats(d_all.reshape(-1, 3)),
    "A_vs_B_aligned_BODY_ONLY": stats(d_all.reshape(-1, 3)[body.reshape(-1)]),
    "alignment_floor_A_resampled_vs_A": stats((A - A_sh).reshape(-1, 3)),
    "alignment_floor_body_only": stats((A - A_sh).reshape(-1, 3)[body.reshape(-1)]),
}

# Ratio: how many times larger is the real A/B difference than the pure
# resampling artefact of the identical image.
r = out["A_vs_B_aligned_BODY_ONLY"]["mean_abs_overall_255"] / max(out["alignment_floor_body_only"]["mean_abs_overall_255"], 1e-9)
out["signal_to_alignment_ratio_body"] = round(r, 3)

# --- derived (non-render) previews -----------------------------------------
amp = np.clip(np.abs(d_all) * 6.0, 0, 255).astype(np.uint8)
Image.fromarray(amp).resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, "derived_diff_amplified_6x_ab_regions.png"))

pair = np.concatenate([A, np.full((H, 6, 3), 255.0), B], axis=1)
Image.fromarray(np.clip(pair, 0, 255).astype(np.uint8)).resize(((W * 2 + 6) * 2, H * 2), Image.NEAREST).save(
    os.path.join(HERE, "derived_side_by_side_A_left_B_right_2x.png"))

b1 = (Y0i + int(H * 0.14), Y0i + int(H * 0.60))
bandA = sample(ab, X0i, Y0i, W, H, 0.0, 0.0)[b1[0] - Y0i:b1[1] - Y0i]
bandB = sample(ab, X0i, Y0i, W, H, dx, dy)[b1[0] - Y0i:b1[1] - Y0i]
Image.fromarray(np.clip(np.concatenate([bandA, np.full((bandA.shape[0], 6, 3), 255.0), bandB], axis=1), 0, 255).astype(np.uint8)).resize(
    ((W * 2 + 6) * 3, (b1[1] - b1[0]) * 3), Image.NEAREST).save(os.path.join(HERE, "derived_torso_band_A_left_B_right_3x.png"))

print(json.dumps(out, indent=1))
with open(os.path.join(HERE, "measure-aligned.json"), "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=1)
