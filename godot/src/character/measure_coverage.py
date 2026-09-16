#!/usr/bin/env python3
"""Coverage-conditional stats: how much of the body actually carries outfit colour."""
import json, os, hashlib
import numpy as np
from PIL import Image
OUT = "/root/projects/steam-circuit-padel-pro/godot/src/character/out"
R4 = lambda v: round(float(v), 4)
def load(n):
    with Image.open(os.path.join(OUT, n)) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8)
BGi = load("background_only_1280x720.png").astype(np.int16)
fn = lambda k: k + "_x0_1280x720.png"
base = load(fn("outfit_base"))
M = (np.abs(base.astype(np.int16) - BGi) > 2).any(axis=2)
NPX = int(M.sum())
res = {"body_mask_px": NPX}

def cond(ka, kb, thr=2.0):
    A = load(fn(ka)).astype(np.float64); B = load(fn(kb)).astype(np.float64)
    d = (A - B)[M]; eu = np.sqrt((d*d).sum(axis=1))
    cov = eu > thr
    n = int(cov.sum())
    return {
        "changed_px_eu_gt_2": n,
        "coverage_frac_of_body": R4(n / NPX),
        "mean_eu_over_whole_body_255": R4(eu.mean()),
        "mean_eu_within_changed_px_255": R4(eu[cov].mean()) if n else 0.0,
        "mean_abs_within_changed_px_255": R4(np.abs(d)[cov].mean()) if n else 0.0,
        "p50_eu_within_changed": R4(np.percentile(eu[cov], 50)) if n else 0.0,
        "p95_eu_within_changed": R4(np.percentile(eu[cov], 95)) if n else 0.0,
        "unchanged_frac": R4(1 - n / NPX),
    }, cov

res["coverage"] = {}
cS, covS = cond("outfit_glacier", "outfit_vermilion")
res["coverage"]["glacier_vs_vermilion_defaultpbr"] = cS
cW, covW = cond("outfit_midnight_violet", "outfit_ember")
res["coverage"]["midnight_violet_vs_ember_defaultpbr"] = cW
cP, covP = cond("pbrglb_outfit_glacier", "pbrglb_outfit_vermilion")
res["coverage"]["glacier_vs_vermilion_pbrglb"] = cP
res["coverage_mask_overlap"] = {
    "strong_and_weak_iou": R4((covS & covW).sum() / max(1, (covS | covW).sum())),
    "strong_and_pbrglb_iou": R4((covS & covP).sum() / max(1, (covS | covP).sum())),
}
# per-window coverage for the strong pair
ys, xs = np.nonzero(M); Y0 = int(ys.min()); SPAN = 598
WINDOWS = [("head",.02,.10),("upper_back",.20,.32),("mid_torso",.32,.45),
           ("waist_hip",.45,.56),("shorts",.56,.68),("thigh",.70,.82),("feet",.94,.99)]
idx = np.nonzero(M)  # row indices aligned with M[M] flattening order
rows = idx[0]
wcov = {}
for w,f0,f1 in WINDOWS:
    lo = int(round(Y0+f0*SPAN)); hi = int(round(Y0+f1*SPAN))
    sel = (rows >= lo) & (rows < hi)
    npx = int(sel.sum())
    wcov[w] = {"y_range":[lo,hi-1], "window_body_px": npx,
               "changed_px_strong": int((covS & sel).sum()),
               "coverage_frac_strong": R4((covS & sel).sum()/npx) if npx else 0.0,
               "changed_px_weak": int((covW & sel).sum()),
               "coverage_frac_weak": R4((covW & sel).sum()/npx) if npx else 0.0}
res["per_window_coverage"] = wcov
p = os.path.join(OUT, "measure-coverage.json")
json.dump(res, open(p,"w"), indent=2)
print(json.dumps(res, indent=2))
print("SHA256", hashlib.sha256(open(p,"rb").read()).hexdigest(), os.path.getsize(p))
