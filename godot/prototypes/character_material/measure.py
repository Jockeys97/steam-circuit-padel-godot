#!/usr/bin/env python3
"""Measure the character_material renders. Pure numpy/PIL, no network, no writes
outside stdout + JSON in this directory.

Reads the numbers the engine printed (framing) from render log and re-derives
the two aligned screen rectangles from them - the measurement is anchored to the
engine's own unprojection, not to hand-picked pixel coordinates.

Regions:
  A_FULL  the full body box of copy A (foot..head, x span +-0.45 m)
  B_FULL  A_FULL shifted by +dx px (dx = engine-reported screen shift)
  A_TORSO / B_TORSO  the upper-body band of the same boxes (fraction of the
          measured body span), where a tee/torso garment lives
"""
import hashlib
import json
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))

LOG = os.path.join(HERE, "render_1280x720.log")
PNG_AB = os.path.join(HERE, "outfit_ab_side_by_side_1280x720.png")
PNG_A = os.path.join(HERE, "outfit_a_only_1280x720.png")
PNG_B = os.path.join(HERE, "outfit_b_only_1280x720.png")

log = open(LOG, encoding="utf-8", errors="replace").read()


def grab(pattern, cast=float):
    m = re.search(pattern, log)
    if not m:
        sys.exit("MISSING in log: %s" % pattern)
    return [cast(g) for g in m.groups()]


# Engine-reported framing for copy A and copy B.
a_foot = grab(r"FRAMING_a foot_px=\(([-\d.]+),([-\d.]+)\) head_px=\(([-\d.]+),([-\d.]+)\) x_span_px=([-\d.]+)\.\.([-\d.]+)")
b_xspan = grab(r"FRAMING_b foot_px=\(([-\d.]+),([-\d.]+)\) head_px=\(([-\d.]+),([-\d.]+)\) x_span_px=([-\d.]+)\.\.([-\d.]+)")
dx, dy = grab(r"FRAMING_SHIFT_PX dx=([-\d.]+) dy=([-\d.]+)")

ax0, ax1 = a_foot[4], a_foot[5]
ay0, ay1 = a_foot[3], a_foot[1]          # head y .. foot y
INSET = 2                                # stay strictly inside the unprojected span

BOX_A = (int(round(ax0)) + INSET, int(round(ay0)) + INSET,
         int(round(ax1)) - INSET, int(round(ay1)) - INSET)
BOX_B = (int(round(ax0 + dx)) + INSET, int(round(ay0 + dy)) + INSET,
         int(round(ax1 + dx)) - INSET, int(round(ay1 + dy)) - INSET)

# Bands, as fractions of the measured body height (head at 0.0, foot at 1.0).
T0, T1 = 0.14, 0.60      # upper body: shoulders/chest/torso -> where a tee sits
L0, L1 = 0.55, 0.98      # lower body: shorts/legs
h = BOX_A[3] - BOX_A[1]
BAND = (int(round(h * T0)), int(round(h * T1)))
LBAND = (int(round(h * L0)), int(round(h * L1)))


def band_box(box, band):
    return (box[0], box[1] + band[0], box[2], box[1] + band[1])


def crop(arr, box):
    return arr[box[1]:box[3], box[0]:box[2], :3].astype(np.int16)


def stats(d):
    a = np.abs(d)
    euc = np.sqrt((d.astype(np.float64) ** 2).sum(axis=2))
    changed10 = int((euc > 10).sum())
    total = euc.size
    return {
        "pixels": int(total),
        "mean_abs_overall_255": round(float(a.mean()), 4),
        "mean_abs_per_channel_255": [round(float(v), 4) for v in a.reshape(-1, 3).mean(axis=0)],
        "rms_overall_255": round(float(np.sqrt((d.astype(np.float64) ** 2).mean())), 4),
        "mean_euclidean_255": round(float(euc.mean()), 4),
        "max_euclidean_255": round(float(euc.max()), 4),
        "pixels_euclidean_gt10": changed10,
        "frac_euclidean_gt10": round(changed10 / total, 6),
        "pixels_euclidean_gt25": int((euc > 25).sum()),
        "frac_euclidean_gt25": round(float((euc > 25).sum()) / total, 6),
        "mean_abs_over_changed_gt10_255": round(float(np.abs(d)[euc > 10].mean()), 4) if changed10 else 0.0,
    }


def img_info(path, arr):
    raw = open(path, "rb").read()
    im = Image.open(path)
    rgb = arr[:, :, :3].astype(np.uint32)
    key = (rgb[:, :, 0] << 16) | (rgb[:, :, 1] << 8) | rgb[:, :, 2]
    uniq = int(np.unique(key).size)
    return {
        "path": os.path.basename(path),
        "bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "size": list(im.size),
        "mode": im.mode,
        "distinct_rgb_colours": uniq,
        "mean_rgb_255": [round(float(v), 3) for v in arr[:, :, :3].reshape(-1, 3).mean(axis=0)],
        "std_rgb_255": round(float(arr[:, :, :3].reshape(-1, 3).std()), 4),
        "max_channel_255": int(arr[:, :, :3].max()),
        "min_channel_255": int(arr[:, :, :3].min()),
    }


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"))


ab = load(PNG_AB)
a_only = load(PNG_A)
b_only = load(PNG_B)

out = {
    "region_geometry": {
        "engine_reported_dx_px": dx,
        "engine_reported_dy_px": dy,
        "box_a_xyxy": list(BOX_A),
        "box_b_xyxy": list(BOX_B),
        "box_wh": [BOX_A[2] - BOX_A[0], BOX_A[3] - BOX_A[1]],
        "torso_band_frac_of_body_height": [T0, T1],
        "torso_band_y_offsets_in_box": list(BAND),
    },
    "images": {
        "ab": img_info(PNG_AB, ab),
        "a_only": img_info(PNG_A, a_only),
        "b_only": img_info(PNG_B, b_only),
    },
}

# --- the measurement: copy A's region vs copy B's region, same frame ---------
d_ab_full = crop(ab, BOX_A) - crop(ab, BOX_B)
out["diff_ab_side_by_side_FULLBODY"] = stats(d_ab_full)
d_ab_torso = crop(ab, band_box(BOX_A, BAND)) - crop(ab, band_box(BOX_B, BAND))
out["diff_ab_side_by_side_TORSO"] = stats(d_ab_torso)

# Contract-style diff: only pixels that are actually model in copy A's frame
# (background and floor are flat and identical in both crops; masking them out
# keeps the body-number free of dilution).
bg_c = ab[5, 5, :3].astype(np.int16)
floor_c = ab[700, 60, :3].astype(np.int16)
ca = crop(ab, BOX_A)
cb = crop(ab, BOX_B)
m_body = ((np.abs(ca - bg_c).sum(axis=2) > 12) & (np.abs(ca - floor_c).sum(axis=2) > 12))
out["bg_colour_rgb"] = [int(v) for v in bg_c]
out["floor_colour_rgb"] = [int(v) for v in floor_c]
out["masked_body_pixels"] = int(m_body.sum())
out["masked_body_frac_of_box"] = round(float(m_body.mean()), 6)
d_m = d_ab_full[m_body]
e_m = np.sqrt((d_m.astype(np.float64) ** 2).sum(axis=1))
out["diff_ab_MASKED_BODY"] = {
    "pixels": int(e_m.size),
    "mean_abs_overall_255": round(float(np.abs(d_m).mean()), 4),
    "mean_abs_per_channel_255": [round(float(v), 4) for v in np.abs(d_m).mean(axis=0)],
    "rms_overall_255": round(float(np.sqrt((d_m.astype(np.float64) ** 2).mean())), 4),
    "mean_euclidean_255": round(float(e_m.mean()), 4),
    "max_euclidean_255": round(float(e_m.max()), 4),
    "pixels_euclidean_gt10": int((e_m > 10).sum()),
    "frac_euclidean_gt10": round(float((e_m > 10).mean()), 6),
    "pixels_euclidean_gt25": int((e_m > 25).sum()),
    "frac_euclidean_gt25": round(float((e_m > 25).mean()), 6),
    "mean_abs_over_changed_gt10_255": round(float(np.abs(d_m)[e_m > 10].mean()), 4) if (e_m > 10).any() else 0.0,
}
out["diff_ab_side_by_side_LEGS"] = stats(crop(ab, band_box(BOX_A, LBAND)) - crop(ab, band_box(BOX_B, LBAND)))

# Internal control: the head/upper-shoulder band (0.00-0.12 of body height) is
# skin/fur, i.e. texels the recolour tool's chromatic mask is supposed to leave
# alone. A difference there would mean the swap is a global tint; a near-zero
# number there is the evidence that the measured difference is localised.
HBAND = (0, int(round(h * 0.12)))
out["diff_ab_side_by_side_HEADBAND_control"] = stats(crop(ab, band_box(BOX_A, HBAND)) - crop(ab, band_box(BOX_B, HBAND)))

def region_colours(frame, box):
    c = crop(frame, box)
    k = (c[:, :, 0].astype(np.uint32) << 16) | (c[:, :, 1].astype(np.uint32) << 8) | c[:, :, 2].astype(np.uint32)
    return int(np.unique(k).size)

out["region_distinct_colours"] = {
    "ab_frame_A_region": region_colours(ab, BOX_A),
    "ab_frame_B_region": region_colours(ab, BOX_B),
    "a_only_A_region": region_colours(a_only, BOX_A),
    "b_only_B_region": region_colours(b_only, BOX_B),
}

# --- null controls: same pixels with the other copy hidden ------------------
# If the renderer is deterministic and hiding one copy cannot touch the other,
# these must be all-zero; any non-zero value is the measurement floor.
d_null_a = crop(ab, BOX_A) - crop(a_only, BOX_A)
out["null_control_A_abframe_vs_aonly"] = stats(d_null_a)
d_null_b = crop(ab, BOX_B) - crop(b_only, BOX_B)
out["null_control_B_abframe_vs_bonly"] = stats(d_null_b)

# --- cross-check: the single-outfit frames against each other ---------------
d_ab_singles = crop(a_only, BOX_A) - crop(b_only, BOX_B)
out["diff_aonly_vs_bonly_FULLBODY"] = stats(d_ab_singles)
out["diff_aonly_vs_bonly_TORSO"] = stats(crop(a_only, band_box(BOX_A, BAND)) - crop(b_only, band_box(BOX_B, BAND)))

# --- is there anything in the frame at all? ---------------------------------
nonbg = int((np.abs(ab[:, :, :3].astype(np.int16) - ab[5, 5, :3].astype(np.int16)).sum(axis=2) > 12).sum())
out["frame_check"] = {
    "ab_pixels_differing_from_top_left_bg": nonbg,
    "ab_frac_differing_from_bg": round(nonbg / (ab.shape[0] * ab.shape[1]), 6),
    "bg_pixel_rgba": [int(v) for v in ab[5, 5]],
}

print(json.dumps(out, indent=1))
with open(os.path.join(HERE, "measure-report.json"), "w", encoding="utf-8") as fh:
    json.dump(out, fh, indent=1)
