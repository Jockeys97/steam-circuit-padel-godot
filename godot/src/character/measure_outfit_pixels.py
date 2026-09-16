#!/usr/bin/env python3
"""OFFLINE pixel measurement of rendered athlete outfit frames.
Reads only; writes measure-*.json and derived_*.png into out/.
"""
import json, os, hashlib
import numpy as np
from PIL import Image

OUT = "/root/projects/steam-circuit-padel-pro/godot/src/character/out"
R4 = lambda v: round(float(v), 4)

def load(name):
    with Image.open(os.path.join(OUT, name)) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)

BG = load("background_only_1280x720.png")
BGi = BG.astype(np.int16)

def body_mask(img):
    return (np.abs(img.astype(np.int16) - BGi) > 2).any(axis=2)

DEFAULT_PBR = ["outfit_base", "outfit_glacier", "outfit_vermilion",
               "outfit_midnight_violet", "outfit_ember"]
PBRGLB = ["pbrglb_outfit_base", "pbrglb_outfit_glacier", "pbrglb_outfit_vermilion"]
ALL8 = DEFAULT_PBR + PBRGLB
fn = lambda k: k + "_x0_1280x720.png"

res = {}

# ---------- 1. body mask ----------
imgs = {k: load(fn(k)) for k in ALL8}
masks = {k: body_mask(imgs[k]) for k in ALL8}
ref = masks[ALL8[0]]
ys, xs = np.nonzero(ref)
BB = dict(x0=int(xs.min()), x1=int(xs.max()), y0=int(ys.min()), y1=int(ys.max()))
res["body_mask"] = {
    "rule": "any-channel abs(frame-background) > 2",
    "per_frame_pixel_count": {k: int(masks[k].sum()) for k in ALL8},
    "bit_identical_to_first": {k: bool(np.array_equal(masks[k], ref)) for k in ALL8},
    "all_bit_identical": bool(all(np.array_equal(masks[k], ref) for k in ALL8)),
    "reference_frame": ALL8[0],
    "bbox": BB,
    "bbox_str": f"x={BB['x0']}..{BB['x1']}, y={BB['y0']}..{BB['y1']}",
    "y_span": BB["y1"] - BB["y0"] + 1,
}
M = ref
NPX = int(M.sum())

# ---------- 2. null control ----------
a = imgs["outfit_base"].astype(np.float64)
reread = load(fn("outfit_base")).astype(np.float64)
res["null_control"] = {
    "outfit_base_vs_itself_mean_abs_255": R4(np.abs(a - a)[M].mean()),
    "outfit_base_vs_reread_mean_abs_255": R4(np.abs(a - reread)[M].mean()),
    "outfit_base_vs_reread_max_abs_255": R4(np.abs(a - reread)[M].max()),
    "outfit_glacier_vs_itself_mean_abs_255": R4(
        np.abs(imgs["outfit_glacier"].astype(np.float64)
               - load(fn("outfit_glacier")).astype(np.float64))[M].mean()),
    "body_mask_pixels": NPX,
}
del reread, a

# ---------- 3. whole-model mean rendered RGB ----------
means = {}
for k in ALL8:
    v = imgs[k][M].astype(np.float64)
    means[k] = [R4(v[:, 0].mean()), R4(v[:, 1].mean()), R4(v[:, 2].mean())]
res["whole_model_mean_rgb"] = means

# ---------- 4. pairwise deltas ----------
def pair(ka, kb):
    A = imgs[ka][M].astype(np.float64)
    B = imgs[kb][M].astype(np.float64)
    d = A - B
    ad = np.abs(d)
    eu = np.sqrt((d * d).sum(axis=1))
    return {
        "signed_delta_rgb": [R4(d[:, 0].mean()), R4(d[:, 1].mean()), R4(d[:, 2].mean())],
        "mean_abs_delta_per_channel_255": [R4(ad[:, 0].mean()), R4(ad[:, 1].mean()), R4(ad[:, 2].mean())],
        "mean_abs_delta_overall_255": R4(ad.mean()),
        "mean_euclidean_255": R4(eu.mean()),
        "max_pixel_euclidean_255": R4(eu.max()),
        "frac_pixels_eu_gt_10": R4((eu > 10).mean()),
        "frac_pixels_eu_gt_25": R4((eu > 25).mean()),
        "n_pixels_eu_gt_10": int((eu > 10).sum()),
        "n_pixels_eu_gt_25": int((eu > 25).sum()),
    }

PAIRS = [
    ("glacier_vs_vermilion_defaultpbr", "outfit_glacier", "outfit_vermilion"),
    ("midnight_violet_vs_ember_defaultpbr", "outfit_midnight_violet", "outfit_ember"),
    ("glacier_vs_vermilion_pbrglb", "pbrglb_outfit_glacier", "pbrglb_outfit_vermilion"),
    ("glacier_metallic0_vs_metallic1", "outfit_glacier", "pbrglb_outfit_glacier"),
    ("base_vs_glacier_defaultpbr", "outfit_base", "outfit_glacier"),
    ("base_vs_vermilion_defaultpbr", "outfit_base", "outfit_vermilion"),
    ("base_vs_midnight_violet_defaultpbr", "outfit_base", "outfit_midnight_violet"),
    ("base_vs_ember_defaultpbr", "outfit_base", "outfit_ember"),
    ("base_metallic0_vs_metallic1", "outfit_base", "pbrglb_outfit_base"),
    ("vermilion_metallic0_vs_metallic1", "outfit_vermilion", "pbrglb_outfit_vermilion"),
]
res["pairwise"] = {name: pair(a_, b_) for name, a_, b_ in PAIRS}

# ---------- 5. per-window signed deltas ----------
Y0, SPAN = BB["y0"], 598
WINDOWS = [("head", .02, .10), ("upper_back", .20, .32), ("mid_torso", .32, .45),
           ("waist_hip", .45, .56), ("shorts", .56, .68), ("thigh", .70, .82),
           ("feet", .94, .99)]
def window_mask(f0, f1):
    y_lo = int(round(Y0 + f0 * SPAN)); y_hi = int(round(Y0 + f1 * SPAN))
    wm = np.zeros_like(M); wm[y_lo:y_hi, :] = True
    return (wm & M), y_lo, y_hi

win_res = {}
for wname, f0, f1 in WINDOWS:
    wm, y_lo, y_hi = window_mask(f0, f1)
    entry = {"y_range": [y_lo, y_hi - 1], "frac_range": [f0, f1], "pixels": int(wm.sum())}
    if wm.sum() == 0:
        win_res[wname] = entry; continue
    for k in DEFAULT_PBR:
        v = imgs[k][wm].astype(np.float64)
        entry["mean_rgb_" + k] = [R4(v[:, 0].mean()), R4(v[:, 1].mean()), R4(v[:, 2].mean())]
    for label, ka, kb in [("glacier_vs_vermilion", "outfit_glacier", "outfit_vermilion"),
                          ("midnight_violet_vs_ember", "outfit_midnight_violet", "outfit_ember")]:
        d = imgs[ka][wm].astype(np.float64) - imgs[kb][wm].astype(np.float64)
        entry[label] = {
            "signed_delta_rgb": [R4(d[:, 0].mean()), R4(d[:, 1].mean()), R4(d[:, 2].mean())],
            "mean_abs_delta_255": R4(np.abs(d).mean()),
            "mean_euclidean_255": R4(np.sqrt((d * d).sum(axis=1)).mean()),
        }
    win_res[wname] = entry
res["windows"] = win_res
for label in ("glacier_vs_vermilion", "midnight_violet_vs_ember"):
    scored = [(w, win_res[w][label]["mean_abs_delta_255"]) for w, _, _ in WINDOWS if label in win_res[w]]
    scored.sort(key=lambda t: -t[1])
    res.setdefault("largest_window", {})[label] = {"ranked": scored, "largest": scored[0][0]}

# ---------- 6. transfer ratio ----------
ATLAS_STRONG, ATLAS_WEAK, PRIOR_T = 15.177, 4.873, 0.2463
s = res["pairwise"]["glacier_vs_vermilion_defaultpbr"]["mean_abs_delta_overall_255"]
w = res["pairwise"]["midnight_violet_vs_ember_defaultpbr"]["mean_abs_delta_overall_255"]
sg = res["pairwise"]["glacier_vs_vermilion_pbrglb"]["mean_abs_delta_overall_255"]
Ts, Tw, Tsg = s / ATLAS_STRONG, w / ATLAS_WEAK, sg / ATLAS_STRONG
res["transfer_ratio"] = {
    "strong_pair": {"atlas_mean_abs_255": ATLAS_STRONG, "rendered_mean_abs_255": R4(s), "T": R4(Ts)},
    "weak_pair": {"atlas_mean_abs_255": ATLAS_WEAK, "rendered_mean_abs_255": R4(w), "T": R4(Tw)},
    "strong_pair_pbrglb": {"atlas_mean_abs_255": ATLAS_STRONG, "rendered_mean_abs_255": R4(sg), "T": R4(Tsg)},
    "T_strong_minus_T_weak": R4(Ts - Tw),
    "T_ratio_strong_over_weak": R4(Ts / Tw) if Tw else None,
    "prior_recorded_T": PRIOR_T,
    "strong_vs_prior_abs_diff": R4(abs(Ts - PRIOR_T)),
    "weak_vs_prior_abs_diff": R4(abs(Tw - PRIOR_T)),
    "agree_within_0.02": bool(abs(Ts - Tw) < 0.02),
    "linear_if_T_constant": bool(abs(Ts - Tw) < 0.02),
}
del imgs, masks

# ---------- 7. motion proof ----------
def clip(prefix):
    frames = [load(f"{prefix}_f{i}_1280x720.png") for i in range(8)]
    ms = [body_mask(f) for f in frames]
    union = np.zeros_like(ms[0])
    for m in ms: union |= m
    uy, ux = np.nonzero(union)
    ubb = dict(x0=int(ux.min()), x1=int(ux.max()), y0=int(uy.min()), y1=int(uy.max()))
    f0 = frames[0].astype(np.float64)
    per = []
    for i, f in enumerate(frames):
        y, x = np.nonzero(ms[i])
        d = np.abs(f.astype(np.float64) - f0)[union]
        per.append({
            "frame": i,
            "mean_abs_vs_f0_255": R4(d.mean()),
            "max_abs_vs_f0_255": R4(d.max()),
            "silhouette_px": int(ms[i].sum()),
            "bbox": dict(x0=int(x.min()), x1=int(x.max()), y0=int(y.min()), y1=int(y.max())),
        })
    return {"union_bbox": ubb, "union_px": int(union.sum()), "frames": per}, frames, ubb

run_stats, run_frames, run_bb = clip("anim_run")
drive_stats, drive_frames, drive_bb = clip("anim_drive")
res["motion"] = {"anim_run": run_stats, "anim_drive": drive_stats}

# ---------- 8. derived contact sheets ----------
arts = {}
def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p)
    b = os.path.getsize(p)
    h = hashlib.sha256(open(p, "rb").read()).hexdigest()
    arts[name] = {"path": p, "width": img.size[0], "height": img.size[1], "bytes": b, "sha256": h}

def strip(frames, bb, name, maxw=4000):
    w = bb["x1"] - bb["x0"] + 1; h = bb["y1"] - bb["y0"] + 1
    tiles = [Image.fromarray(f[bb["y0"]:bb["y1"]+1, bb["x0"]:bb["x1"]+1]) for f in frames]
    sheet = Image.new("RGB", (w * len(tiles), h))
    for i, t in enumerate(tiles): sheet.paste(t, (i * w, 0))
    if sheet.size[0] > maxw:
        sc = maxw / sheet.size[0]
        sheet = sheet.resize((maxw, max(1, int(round(sheet.size[1] * sc)))), Image.LANCZOS)
    save(sheet, name)
    return {"tile_w": w, "tile_h": h, "n_tiles": len(tiles)}

res["sheets"] = {}
res["sheets"]["derived_anim_run_strip.png"] = strip(run_frames, run_bb, "derived_anim_run_strip.png")
del run_frames
res["sheets"]["derived_anim_drive_strip.png"] = strip(drive_frames, drive_bb, "derived_anim_drive_strip.png")
del drive_frames

# outfit grid: 5 default-PBR frames, cropped to body bbox
w = BB["x1"] - BB["x0"] + 1; h = BB["y1"] - BB["y0"] + 1
tiles = [load(fn(k))[BB["y0"]:BB["y1"]+1, BB["x0"]:BB["x1"]+1] for k in DEFAULT_PBR]
grid = Image.new("RGB", (w * len(tiles), h))
for i, t in enumerate(tiles): grid.paste(Image.fromarray(t), (i * w, 0))
if grid.size[0] > 4000:
    sc = 4000 / grid.size[0]
    grid = grid.resize((4000, max(1, int(round(grid.size[1] * sc)))), Image.LANCZOS)
save(grid, "derived_outfit_grid.png")
res["sheets"]["derived_outfit_grid.png"] = {"tile_w": w, "tile_h": h, "order": DEFAULT_PBR}
sidecar = os.path.join(OUT, "derived_outfit_grid.json")
json.dump({"image": "derived_outfit_grid.png", "tile_order_left_to_right": DEFAULT_PBR,
           "source_bbox": BB, "tile_w_source_px": w, "tile_h_source_px": h,
           "sheet_w_px": grid.size[0], "sheet_h_px": grid.size[1]},
          open(sidecar, "w"), indent=2)
arts["derived_outfit_grid.json"] = {"path": sidecar, "bytes": os.path.getsize(sidecar),
    "sha256": hashlib.sha256(open(sidecar, "rb").read()).hexdigest()}
del tiles, grid

# amplified strong-pair difference
AMP = 6
ga = load(fn("outfit_glacier"))[BB["y0"]:BB["y1"]+1, BB["x0"]:BB["x1"]+1].astype(np.int16)
vb = load(fn("outfit_vermilion"))[BB["y0"]:BB["y1"]+1, BB["x0"]:BB["x1"]+1].astype(np.int16)
diff = np.abs(ga - vb)
ampd = np.clip(diff * AMP, 0, 255).astype(np.uint8)
save(Image.fromarray(ampd), "derived_glacier_vs_vermilion_amplified.png")
res["sheets"]["derived_glacier_vs_vermilion_amplified.png"] = {
    "amplification": AMP, "crop_bbox": BB,
    "raw_diff_max_per_channel": [int(diff[:, :, i].max()) for i in range(3)],
    "saturated_px_after_amp": int((diff * AMP > 255).any(axis=2).sum()),
}
del ga, vb, diff, ampd

res["artifacts"] = arts
p = os.path.join(OUT, "measure-outfit-pixels.json")
json.dump(res, open(p, "w"), indent=2)
print("WROTE", p)
print(json.dumps({k: res[k] for k in ("body_mask", "null_control", "whole_model_mean_rgb",
                                      "transfer_ratio")}, indent=2))
