#!/usr/bin/env python3
"""Tiled local-shift alignment of the two rendered copies.

Perspective disparity between the two world positions is up to ~+-60 px (a
surface point 0.3 m nearer the camera than the model origin shifts by
1.5*f/2.3 instead of 1.5*f/2.6). So this tiles copy A's region with small
blocks and, per block, searches a WIDE range of integer shifts for the one that
minimises the mean absolute difference. Output per block:

  best_shift_x  - the local disparity that perspective predicts varies smoothly
                  with the body's depth; a smooth map means the two copies are
                  the same geometry in the same pose
  residual      - mean abs diff (0-255) that REMAINS after local alignment,
                  i.e. the honest rendered difference caused by the outfit
                  texture, with spatial misalignment removed
  residual_null - the same block matched against a neighbouring block of the
                  SAME copy (a 48 px self-offset). That is the level a perfect
                  match cannot go below for textured fur, and it bounds how much
                  of the residual could still be spurious.
"""
import json
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
log = open(os.path.join(HERE, "render_1280x720.log"), encoding="utf-8", errors="replace").read()
X0 = float(re.search(r"x_span_px=([-\d.]+)\.\.", log).group(1))
foot_y = float(re.search(r"FRAMING_a foot_px=\([-\d.]+,([-\d.]+)\)", log).group(1))
head_y = float(re.search(r"head_px=\([-\d.]+,[-\d.]+\)", log).group(0).split(",")[1].rstrip(")"))
dx = float(re.search(r"FRAMING_SHIFT_PX dx=([-\d.]+)", log).group(1))

img = np.asarray(Image.open(os.path.join(HERE, "outfit_ab_side_by_side_1280x720.png")).convert("RGB")).astype(np.float32)
H = int(round(foot_y - head_y))
X0i, Y0i = int(round(X0)), int(round(head_y))
BW = 301

BG = img[5, 5]
FL = img[700, 60]

BLK = 48
SX = np.arange(-80, 81, 1.0)


def patch(x, y, w, h):
    return img[y:y + h, x:x + w]


rows = []
for by in range(0, H - BLK + 1, BLK):
    for bx in range(0, BW - BLK + 1, BLK):
        A = patch(X0i + bx, Y0i + by, BLK, BLK)
        # skip blocks that are entirely background/floor (nothing to align)
        if (np.abs(A - BG).sum(axis=2) < 12).all() or (np.abs(A - FL).sum(axis=2) < 12).all():
            continue
        body = (np.abs(A - BG).sum(axis=2) > 12) & (np.abs(A - FL).sum(axis=2) > 12)
        if body.mean() < 0.05:
            continue
        best = None
        for sx in SX:
            for sy in (-2.0, -1.0, 0.0, 1.0, 2.0):
                B = patch(X0i + bx + int(round(dx)) + int(sx), Y0i + by + int(sy), BLK, BLK)
                if B.shape != A.shape:
                    continue
                v = float(np.abs(A[body] - B[body]).mean())
                if best is None or v < best[0]:
                    best = (v, float(sx), float(sy))
        if best is None:
            continue
        # null: same block of copy A against a 48 px-offset block of copy A
        A2 = patch(X0i + bx + BLK, Y0i + by, BLK, BLK)
        null = float(np.abs(A[body] - A2[body]).mean()) if A2.shape == A.shape else None
        rows.append({
            "block_xy_in_body": [bx, by],
            "body_frac": round(float(body.mean()), 3),
            "residual_after_local_align": round(best[0], 3),
            "local_shift_x": best[1],
            "local_shift_y": best[2],
            "null_adjacent_block_same_copy": round(null, 3) if null is not None else None,
        })

res = [r["residual_after_local_align"] for r in rows]
nul = [r["null_adjacent_block_same_copy"] for r in rows if r["null_adjacent_block_same_copy"] is not None]
sh = [r["local_shift_x"] for r in rows]

out = {
    "blocks_measured": len(rows),
    "block_size_px": BLK,
    "residual_after_local_align": {
        "mean": round(float(np.mean(res)), 3), "median": round(float(np.median(res)), 3),
        "p10": round(float(np.percentile(res, 10)), 3), "p90": round(float(np.percentile(res, 90)), 3),
        "min": round(float(np.min(res)), 3), "max": round(float(np.max(res)), 3),
    },
    "null_adjacent_block_same_copy": {
        "mean": round(float(np.mean(nul)), 3), "median": round(float(np.median(nul)), 3),
        "min": round(float(np.min(nul)), 3), "max": round(float(np.max(nul)), 3),
    },
    "local_shift_x_px": {"min": round(min(sh), 1), "max": round(max(sh), 1),
                         "mean": round(float(np.mean(sh)), 1)},
    "blocks": rows,
}
print(json.dumps({k: v for k, v in out.items() if k != "blocks"}, indent=1))
print("SAMPLE BLOCKS:")
for r in rows[:14]:
    print(" ", r)
with open(os.path.join(HERE, "measure-blocks.json"), "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=1)
