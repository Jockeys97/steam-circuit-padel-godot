#!/usr/bin/env python3
"""PROBE (scratch, not an artifact): which of the two declared colour pairs describes the
Oracolo's real in-field sprites -- the catalogue's `visual.kit/accent` (#6b3df0/#e3c6ff) or
the `base` outfit's `colors` (#6d42b8/#a96cff)?

Reuses tools/character/measure_oracolo_palette.py's own constants and helpers, so the
segmentation is byte-identical to the artifact's.

Test: a shaded garment pixel is a VALUE-SCALED copy of the paint colour (same hue, same
saturation, lower value). So for each candidate C build the shade line {C*k, k in [0.05,1]}
and measure the mean dE76 from the garment pixels to that line. The candidate whose shade
line the pixels actually lie on is the one the sprite is painted with. Hue and saturation
are also compared directly, since they are shading-invariant in HSV.
"""
import os, sys, json
import numpy as np

sys.path.insert(0, "/Users/alessiofantini/Documents/steam-circuit-padel-11m/tools/character")
import measure_oracolo_palette as M

REPO = M.REPO
OUT = "/Users/alessiofantini/.hermes/profiles/dev-work/cache/scratch/oracolo/discrepancy.json"

CANDIDATES = {
    "visual.kit        #6b3df0": "#6b3df0",
    "visual.accent     #e3c6ff": "#e3c6ff",
    "visual.secondary  #1a0f38": "#1a0f38",
    "visual.shoes      #3c1f8a": "#3c1f8a",
    "base.colors[0]    #6d42b8": "#6d42b8",
    "base.colors[1]    #a96cff": "#a96cff",
    "sig  colors[0]    #38216f": "#38216f",
    "sig  colors[1]    #29dfff": "#29dfff",
    "atlas family A    #341c54": "#341c54",
}

REGIONS = ("torso", "hip", "foot", "boot_top")


def shade_line(hexv, ks=200):
    """RGB array of the candidate's own shades, k from 0.05 to 1.0."""
    rgb = np.array(M.rgb_of(hexv), dtype=np.float64)
    k = np.linspace(0.05, 1.0, ks)[:, None]
    return rgb[None, :] * k


def pool_for(outfit):
    """Garment pixels of one outfit, per region, using the tool's bands + exclusions."""
    pools = {r: [] for r in REGIONS}
    hair_hex = M.declared_source()["_visual"]["hair"]
    for name, bpath, bframes, opath, oframes in M.SHEETS:
        if outfit == "base":
            path, frames = bpath, bframes
        else:
            path, frames = opath.format(outfit=outfit), oframes
        p = os.path.join(REPO, path)
        if not os.path.exists(p):
            print("MISSING", p); continue
        imgs = M.load_frames(p, frames)
        for frame in imgs:
            rgba = np.asarray(frame).astype(np.int16)
            alpha = rgba[:, :, 3]
            c0, c1, _d = M.own_span(alpha)
            sub = rgba[:, c0:c1, :]
            a2 = alpha[:, c0:c1]
            excl = M.exclusion_masks(sub, hair_hex, True)
            bands = M.per_frame_bands(a2)
            if bands is None:
                continue
            for region in REGIONS:
                if name in M.BAND_SHEET_EXCLUDE.get(region, ()):
                    continue
                b0, b1, _bb = bands[region]
                sel = M.collect((b0, b1), excl, a2)
                if sel.any():
                    pools[region].append(sub[:, :, :3][sel].astype(np.float64))
    return {r: (np.concatenate(v) if v else np.zeros((0, 3))) for r, v in pools.items()}


def analyse(px, label):
    if len(px) == 0:
        return None
    hue, sat, val = M.hsv_of(px)
    # only violet-family garment pixels (the declared dark trim / near-black excluded)
    v = (hue >= M.VIOLET_HUE[0]) & (hue <= M.VIOLET_HUE[1]) & (sat > M.VIOLET_SAT_MIN)
    pxv = px[v]
    hv, sv, vv = hue[v], sat[v], val[v]
    res = {"n_garment_px": int(len(pxv)),
           "measured_hue_mean_deg": round(float(hv.mean()), 1),
           "measured_hue_median_deg": round(float(np.median(hv)), 1),
           "measured_sat_mean": round(float(sv.mean()), 3),
           "measured_val_mean": round(float(vv.mean()), 3),
           "measured_val_p05": round(float(np.percentile(vv, 5)), 3),
           "measured_val_p95": round(float(np.percentile(vv, 95)), 3),
           "candidates": {}}
    for name, hx in CANDIDATES.items():
        line = shade_line(hx)
        lab_line = M.srgb_to_lab(line)
        # chunked to bound memory
        d = np.empty(len(pxv))
        step = 20000
        for i in range(0, len(pxv), step):
            chunk = pxv[i:i + step]
            dch = np.linalg.norm(M.srgb_to_lab(chunk)[:, None, :] - lab_line[None, :, :], axis=2)
            d[i:i + step] = dch.min(axis=1)
        ch, cs, cv = M.hsv_of(np.array(M.rgb_of(hx), dtype=np.float64).reshape(1, 3))
        ch, cs = float(ch[0]), float(cs[0])
        in_hue = (np.abs(((hv - ch + 180.0) % 360.0) - 180.0) <= M.D_MATCH_HUE)
        res["candidates"][name] = {
            "hex": hx,
            "cand_hue_deg": round(ch, 1), "cand_sat": round(cs, 3),
            "mean_dE76_to_shade_line": round(float(d.mean()), 2),
            "median_dE76_to_shade_line": round(float(np.median(d)), 2),
            "pct_px_within_dE20": round(float(100.0 * (d <= 20.0).mean()), 1),
            "dHue_to_measured_mean_deg": round(M.dhue(ch, float(hv.mean())), 1),
            "pct_px_within_dHue12": round(float(100.0 * in_hue.mean()), 1),
            "dSat_to_measured_mean": round(abs(cs - float(sv.mean())), 3),
        }
    return res


out = {"tool": "scratch probe over measure_oracolo_palette.py", "regions": {}}
for outfit in ("base", "signature"):
    pools = pool_for(outfit)
    out[outfit] = {}
    for region, px in pools.items():
        r = analyse(px, region)
        if r:
            out[outfit][region] = r
            print("== %s / %s  n=%d  hue_mean=%.1f sat=%.3f val=%.3f" %
                  (outfit, region, r["n_garment_px"], r["measured_hue_mean_deg"],
                   r["measured_sat_mean"], r["measured_val_mean"]))
            for name, c in sorted(r["candidates"].items(), key=lambda kv: kv[1]["mean_dE76_to_shade_line"]):
                print("     %-28s hue=%6.1f dHue=%5.1f  meanDE=%5.2f  withinDE20=%5.1f%%  withinDHue12=%5.1f%%  dSat=%.3f"
                      % (name, c["cand_hue_deg"], c["dHue_to_measured_mean_deg"],
                         c["mean_dE76_to_shade_line"], c["pct_px_within_dE20"],
                         c["pct_px_within_dHue12"], c["dSat_to_measured_mean"]))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(out, open(OUT, "w"), indent=1)
print("\nWROTE", OUT)
