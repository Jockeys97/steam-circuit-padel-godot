#!/usr/bin/env python3
"""PROBE (scratch): the Oracolo ATLAS's own family structure, for the shader family-test
question.

The artifact already reports the atlas's two largest SATURATED families. This probe adds the
missing half: how the atlas's violet family is distributed in VALUE and HUE, i.e. whether a
value gate (the Maestro's fix) is even available here, and whether a SECOND garment family
exists at all for the `_b` slots to land on.

Reported as atlas structure only. It is NOT a mask coverage measurement -- the Oracolo mask
does not exist in the tree, so no anchor can be quoted from here.
"""
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, "/Users/alessiofantini/Documents/steam-circuit-padel-11m/tools/character")
import measure_oracolo_palette as M

REPO = M.REPO
ATLAS = "godot/assets/athletes/oracolo_texture_0.png"
OUT = "/Users/alessiofantini/.hermes/profiles/dev-work/cache/scratch/oracolo/atlas_families.json"

a = np.asarray(Image.open(os.path.join(REPO, ATLAS)).convert("RGB")).astype(np.float64)
flat = a.reshape(-1, 3)
hue, sat, val = M.hsv_of(flat)
sat = sat.ravel(); val = val.ravel(); hue = hue.ravel()

violet = (hue >= 240.0) & (hue <= 300.0) & (sat >= 0.35)
near_black = (val <= 0.12) & (sat < 0.35)
grey_white = (sat < 0.15) & (val > 0.35)
cyan = (hue >= 170.0) & (hue <= 215.0) & (sat >= 0.35)
total = flat.shape[0]

print("atlas %s  %d texels" % (ATLAS, total))
res = {"atlas": ATLAS, "texels": int(total), "classes": {}, "violet_value_hist": {},
       "violet_hue_hist": {}, "value_gate_candidates": {}}

for name, m in (("violet_240_300_sat35", violet), ("near_black_val_le_0.12", near_black),
                ("grey_white_sat_lt_0.15_val_gt_0.35", grey_white), ("cyan_170_215_sat35", cyan)):
    n = int(m.sum())
    res["classes"][name] = {"texels": n, "pct_of_atlas": round(100.0 * n / total, 3)}
    print("  %-34s %9d  %6.3f%% of atlas" % (name, n, 100.0 * n / total))

# value histogram of the violet family: is there a density discontinuity (a gate)?
v = val[violet]
edges = np.linspace(0.0, 1.0, 41)
hist, _ = np.histogram(v, bins=edges)
res["violet_value_hist"] = {("%.2f-%.2f" % (edges[i], edges[i + 1])): int(hist[i])
                            for i in range(len(hist))}
print("\n  violet VALUE histogram (40 bins of 0.025), texels per bin:")
mx = max(1, hist.max())
for i in range(len(hist)):
    if hist[i] == 0:
        continue
    print("    %.3f-%.3f %8d %s" % (edges[i], edges[i + 1], hist[i], "#" * int(48 * hist[i] / mx)))

# hue histogram of the violet family: one band or several?
hh = hue[violet]
e2 = np.arange(240.0, 301.0, 5.0)
h2, _ = np.histogram(hh, bins=e2)
res["violet_hue_hist"] = {("%.0f-%.0f" % (e2[i], e2[i + 1])): int(h2[i]) for i in range(len(h2))}
print("\n  violet HUE histogram (5 deg bins), texels per bin:")
mx2 = max(1, h2.max())
for i in range(len(h2)):
    print("    %.0f-%.0f %8d %s" % (e2[i], e2[i + 1], h2[i], "#" * int(48 * h2[i] / mx2)))

# widest empty value gap inside the violet family's populated range -> a gate candidate
pop = np.nonzero(hist)[0]
gaps = []
for i in range(len(pop) - 1):
    if pop[i + 1] > pop[i] + 1:
        gaps.append((int(hist[pop[i] + 1:pop[i + 1]].sum()), edges[pop[i] + 1], edges[pop[i] + 1]))
res["widest_empty_value_gaps_in_violet"] = [
    {"empty_bins": int(pop[i + 1] - pop[i] - 1), "lo": round(float(edges[pop[i] + 1]), 3),
     "hi": round(float(edges[pop[i + 1]]), 3)} for i in range(len(pop) - 1) if pop[i + 1] > pop[i] + 1]
print("\n  empty value gaps inside the violet family's populated range:")
for g in res["widest_empty_value_gaps_in_violet"]:
    print("    %d empty bins between %.3f and %.3f" % (g["empty_bins"], g["lo"], g["hi"]))
if not res["widest_empty_value_gaps_in_violet"]:
    print("    NONE - the violet family is value-continuous; no density gap to gate on")

# the largest 5-deg hue gap inside the violet family
hpop = np.nonzero(h2)[0]
print("\n  empty hue gaps inside the violet family's populated range:")
found = False
for i in range(len(hpop) - 1):
    if hpop[i + 1] > hpop[i] + 1:
        print("    %.0f-%.0f empty" % (e2[hpop[i] + 1], e2[hpop[i + 1]]))
        found = True
if not found:
    print("    NONE - the violet family is hue-continuous across its whole 240-300 window")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(res, open(OUT, "w"), indent=1)
print("\nWROTE", OUT)
