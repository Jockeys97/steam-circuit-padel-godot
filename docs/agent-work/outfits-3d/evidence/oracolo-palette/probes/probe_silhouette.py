#!/usr/bin/env python3
"""PROBE (scratch): resolution-INDEPENDENT silhouette / skin-exposure comparison of the
Oracolo's base vs signature 2D sprites.

Why: `pixel_changes_vs_base` in the artifact resamples (base frames are 298 px wide, outfit
frames 179 px -- a 1.665x factor), so its percentages are approximate. The per-band
`skin_pct` and `width_of_height` in `silhouette_check` are normalised (share of a band that
is skin; band width divided by body bbox height), so they survive a resolution change
without any resampling. This probe turns them into base-vs-signature deltas, per sheet.

A cropped top or bare shoulders raise the SKIN share of the upper torso bands. A silhouette
change moves `width_of_height`. Neither number is affected by the sheets' different scales.
"""
import os, sys, json
import numpy as np

sys.path.insert(0, "/Users/alessiofantini/Documents/steam-circuit-padel-11m/tools/character")
import measure_oracolo_palette as M

REPO = M.REPO
OUT = "/Users/alessiofantini/.hermes/profiles/dev-work/cache/scratch/oracolo/silhouette_compare.json"


def bands_of(path, frames):
    """Per band: (skin_pct, hair_pct, width_of_height), using the tool's own bands + masks."""
    hair_hex = M.declared_source()["_visual"]["hair"]
    acc = {}
    imgs = M.load_frames(os.path.join(REPO, path), frames)
    for frame in imgs:
        rgba = np.asarray(frame).astype(np.int16)
        alpha = rgba[:, :, 3]
        c0, c1, _d = M.own_span(alpha)
        a2 = alpha[:, c0:c1]
        rgb = rgba[:, c0:c1, :3].astype(np.float64)
        hue, sat, val = M.hsv_of(rgb)
        skin = (hue >= M.SKIN_HUE[0]) & (hue <= M.SKIN_HUE[1]) & (sat > M.SKIN_SAT_MIN)
        hair = np.abs(rgb - np.array(M.rgb_of(hair_hex), dtype=np.float64)).max(axis=2) <= M.HAIR_TOL
        body = a2 > M.ALPHA_MIN
        bb = M.body_bbox(a2)
        if bb is None:
            continue
        _, y0, _, y1 = bb
        h = y1 - y0 + 1
        for i in range(20):
            f0, f1 = i * 0.05, (i + 1) * 0.05
            r0, r1 = int(y0 + f0 * h), int(y0 + f1 * h)
            m = body & (np.arange(a2.shape[0])[:, None] >= r0) & (np.arange(a2.shape[0])[:, None] < r1)
            n = int(m.sum())
            if n == 0:
                continue
            cols = np.nonzero(m.any(axis=0))[0]
            wid = (cols.max() - cols.min() + 1) if len(cols) else 0
            d = acc.setdefault(f0, {"n": 0, "skin": 0, "hair": 0, "w": []})
            d["n"] += n
            d["skin"] += int((skin & m).sum())
            d["hair"] += int((hair & m).sum())
            d["w"].append(wid / float(h))
    return {f: {"skin_pct": round(100.0 * d["skin"] / d["n"], 1),
                "hair_pct": round(100.0 * d["hair"] / d["n"], 1),
                "width_of_height": round(float(np.mean(d["w"])), 4),
                "px": d["n"]} for f, d in sorted(acc.items())}


out = {"sheets": {}}
for name, bpath, bframes, opath, oframes in M.SHEETS:
    b = bands_of(bpath, bframes)
    s = bands_of(opath.format(outfit="signature"), oframes)
    rows = []
    for f in sorted(set(b) & set(s)):
        rows.append({"band": f,
                     "base_skin_pct": b[f]["skin_pct"], "sig_skin_pct": s[f]["skin_pct"],
                     "d_skin_pct": round(s[f]["skin_pct"] - b[f]["skin_pct"], 1),
                     "base_woh": b[f]["width_of_height"], "sig_woh": s[f]["width_of_height"],
                     "d_woh_pct": round(100.0 * (s[f]["width_of_height"] - b[f]["width_of_height"]) /
                                        max(1e-9, b[f]["width_of_height"]), 1)})
    out["sheets"][name] = {"base_path": bpath, "sig_path": opath.format(outfit="signature"),
                           "rows": rows}
    ds = [r["d_skin_pct"] for r in rows]
    dw = [r["d_woh_pct"] for r in rows]
    print("== %-12s base=%s sig=%s" % (name, bpath, opath.format(outfit="signature")))
    print("   d_skin_pct: mean %+.1f  min %+.1f  max %+.1f  |d|>10 in %d/20 bands"
          % (float(np.mean(ds)), min(ds), max(ds), sum(1 for x in ds if abs(x) > 10)))
    print("   d_width_of_height: mean %+.1f%%  min %+.1f%%  max %+.1f%%  |d|>10%% in %d/20 bands"
          % (float(np.mean(dw)), min(dw), max(dw), sum(1 for x in dw if abs(x) > 10)))
    for r in rows:
        if abs(r["d_skin_pct"]) > 10 or abs(r["d_woh_pct"]) > 10:
            print("     band %.2f  d_skin %+5.1f  (base %5.1f -> sig %5.1f)   d_woh %+6.1f%%  (%.4f -> %.4f)"
                  % (float(r["band"]), r["d_skin_pct"], r["base_skin_pct"], r["sig_skin_pct"],
                     r["d_woh_pct"], r["base_woh"], r["sig_woh"]))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(out, open(OUT, "w"), indent=1)
print("\nWROTE", OUT)
