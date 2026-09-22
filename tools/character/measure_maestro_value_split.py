#!/usr/bin/env python3
"""Measure a VALUE split for Maestro's two baked garment families.

WHY THIS EXISTS
---------------
`outfit_region_recolour.gdshader` tells the two recolourable families of a baked
atlas apart by HUE around two measured anchors. That works on Fiamma (lime 77 deg
vs navy 219 deg) and does NOT work on Maestro: the mask lane measured the two
anchors 20.0 deg apart (#102040 navy at hue 217.1, #68a8c8 sky at hue 196.5) under
a hue tolerance of 42-45 deg, so 1,114,473 masked texels answer to *both* anchors
and the six slots collapse onto one colour per region.

Maestro's two families are far apart in VALUE instead. This tool measures that
separation on the real assets - inside the real mask - and reports:

  * the value histogram of the recolourable (blue-hued, saturated) texels,
  * the atlas's only density discontinuity, which is where the split goes,
  * the adjacency evidence that the in-between band is the light family's
    antialiased edge and NOT the dark family's shading,
  * what the shader does with and without the value gate, using the shader's own
    formulas (mirrored exactly) and the SHADER'S EFFECTIVE constants,
  * per slot (region x family), how many masked texels each target can still move.

Read-only: nothing is written except the JSON report.

    python3 tools/character/measure_maestro_value_split.py
"""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parents[2]
TEXTURE = REPO / "godot/assets/athletes/maestro_texture_0.png"
MASK = REPO / "godot/assets/athletes/outfits/maestro/maestro_region_mask.png"
REPORT = REPO / "docs/agent-work/outfits-3d/evidence/maestro-value-split/maestro-value-split-report.json"

REGIONS = ("torso", "hip", "foot")

## The profile's anchors (measured by the mask lane, quoted from its report).
ANCHOR_A = "102040"   # navy, hue 217.1 deg, value 0.2510  -> the DARK family
ANCHOR_B = "68a8c8"   # sky,  hue 196.5 deg, value 0.7843  -> the LIGHT family

## The mask lane's own family windows (tools/character/build_maestro_outfit_mask.py).
FAMILY_WINDOWS = {"sky": (150.0, 205.0), "navy": (205.0, 270.0)}
BLUE_HUE = (150.0, 270.0)

## The shader's DECLARED defaults on the masked path, and the constants the mask
## lane assumed it runs with. They are NOT the same, and the difference is measured
## rather than papered over: `outfit_catalogue.gd::_apply_profile` never pushes
## MASK_DEFAULTS into the material, so a profile material runs on the shader's own
## default literals.
SHADER_DEFAULTS = {"hue_tol_deg": 42.0, "sat_min": 0.25, "val_min": 0.06, "val_max": 0.99}
MASK_DEFAULTS = {"hue_tol_deg": 45.0, "sat_min": 0.18, "val_min": 0.02, "val_max": 0.98}

COVERAGE_MIN = 128     # mask alpha, the geometric union of the three regions
REGION_MIN = 128       # a region channel counts as "this region" at/above this

## The value gate this tool proposes, in the shader's own terms:
##   band_a = [0.0, 0.74]  the DARK family (navy garment + its baked shading)
##   band_b = [0.76, 1.0]  the LIGHT family (the sky-blue accent cluster)
##   feather = 0.01        the two ramps meet across the accent's antialiased edge
BAND_A = (0.0, 0.74)
BAND_B = (0.76, 1.0)
FEATHER = 0.01
BINS = 100             # 0.01 value bins


# ---------------------------------------------------------------- shader mirror

def hex_rgb(h: str) -> tuple[int, int, int]:
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def _srgb_to_lab(rgb01):
    lin = np.where(rgb01 > 0.04045, ((rgb01 + 0.055) / 1.055) ** 2.4, rgb01 / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ m.T
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[..., 1] - 16.0,
                     500.0 * (f[..., 0] - f[..., 1]),
                     200.0 * (f[..., 1] - f[..., 2])], axis=-1)


def delta_e76(a_hex: str, b_hex: str) -> float:
    """CIE76 (dE76) between two sRGB hex colours, D65. Same metric the palette lane
    reports with, so the numbers can be read side by side."""
    a = _srgb_to_lab(np.array(hex_rgb(a_hex.lstrip("#")), dtype=np.float64) / 255.0)
    b = _srgb_to_lab(np.array(hex_rgb(b_hex.lstrip("#")), dtype=np.float64) / 255.0)
    return float(np.sqrt(((a - b) ** 2).sum()))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def hsv(rgb: np.ndarray):
    """The shader's rgb_to_hsv_deg, vectorised: (hue deg, sat, value=max channel)."""
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    safe = d > 1e-9
    rm = safe & (mx == r)
    gm = safe & (mx == g) & ~rm
    bm = safe & ~rm & ~gm
    h[rm] = np.mod(60.0 * (g[rm] - b[rm]) / d[rm], 360.0)
    h[gm] = 60.0 * (b[gm] - r[gm]) / d[gm] + 120.0
    h[bm] = 60.0 * (r[bm] - g[bm]) / d[bm] + 240.0
    s = np.where(mx > 1e-9, d / np.where(mx > 1e-9, mx, 1.0), 0.0)
    return h, s, mx


def family_weight(rgb: np.ndarray, anchor_hex: str, consts: dict, band=None) -> np.ndarray:
    """`family_weight()` of outfit_region_recolour.gdshader plus the optional value
    gate. `band = None` is the shader as it shipped before the gate existed."""
    ar, ag, ab = [c / 255.0 for c in hex_rgb(anchor_hex)]
    ah = colorsys.rgb_to_hsv(ar, ag, ab)[0] * 360.0
    h, s, v = hsv(rgb)
    dh = np.abs(np.mod(h - ah + 180.0, 360.0) - 180.0)
    tol = consts["hue_tol_deg"]
    w = 1.0 - smoothstep(tol * 0.55, tol, dh)
    w = w * smoothstep(0.0, 1.0, (s - consts["sat_min"]) / 0.12)
    w = w * smoothstep(0.0, 1.0, (v - consts["val_min"]) / 0.12)
    if band is not None:
        lo, hi = band
        w = w * smoothstep(lo - FEATHER, lo, v) * (1.0 - smoothstep(hi, hi + FEATHER, v))
    return w


def dilated(mask: np.ndarray, k: int) -> np.ndarray:
    im = Image.fromarray((mask * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.MaxFilter(k))) > 0


def connected(mask: np.ndarray, min_size: int = 1) -> list[dict]:
    """4-connected components of a boolean mask, largest first."""
    from collections import deque
    h, w = mask.shape
    seen = np.zeros((h, w), dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        pts = []
        while q:
            y, x = q.popleft()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(pts) >= min_size:
            a = np.array(pts)
            bw = int(a[:, 1].max() - a[:, 1].min() + 1)
            bh = int(a[:, 0].max() - a[:, 0].min() + 1)
            out.append({"size": len(pts), "bbox_xywh": [int(a[:, 1].min()), int(a[:, 0].min()), bw, bh],
                        "bbox_fill": round(len(pts) / float(bw * bh), 4)})
    out.sort(key=lambda c: -c["size"])
    return out


# ---------------------------------------------------------------- measurement

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", type=Path, default=REPORT)
    args = ap.parse_args()

    tex = np.asarray(Image.open(TEXTURE).convert("RGB"), dtype=np.float32) / 255.0
    mask = np.asarray(Image.open(MASK).convert("RGBA"), dtype=np.uint8)
    inside = mask[..., 3] >= COVERAGE_MIN
    region = {r: mask[..., i] >= REGION_MIN for i, r in enumerate(REGIONS)}
    h, s, v = hsv(tex)
    n_inside = int(inside.sum())

    # The recolourable set: blue-hued AND saturated enough to pass the shader's own
    # sat_min. Without the saturation filter the "population" would be dominated by
    # the white/grey shoes, which no anchor can ever match.
    blueh = (s >= SHADER_DEFAULTS["sat_min"]) & (h >= BLUE_HUE[0]) & (h < BLUE_HUE[1])
    recolourable = inside & blueh
    n_rec = int(recolourable.sum())

    hist_all = np.histogram(v[recolourable], bins=BINS, range=(0.0, 1.0))[0]

    # The atlas's density discontinuity: the largest relative jump between adjacent
    # 0.01 bins above 0.40 (below that the histogram is one smooth garment mode).
    jumps = []
    for i in range(40, BINS - 1):
        prev, cur = int(hist_all[i]), int(hist_all[i + 1])
        if cur >= 500 and prev >= 0:
            jumps.append((cur / max(prev, 1), (i + 1) / 100.0, prev, cur))
    jumps.sort(reverse=True)
    split_value = jumps[0][1] if jumps else None
    if split_value is None:
        raise SystemExit("no density discontinuity above 0.40 with >=500 texels in a 0.01 bin")

    ## The light family: everything at/above the discontinuity.
    light = recolourable & (v >= split_value)
    ## The in-between band, which the adjacency test below shows is the light
    ## family's antialiased edge, not the dark family's shading.
    edge_band = recolourable & (v >= split_value - 0.02) & (v < split_value)
    dark = recolourable & (v < split_value - 0.02)
    near_light = dilated(light, 5)
    mid_045 = recolourable & (v >= 0.45) & (v < split_value - 0.02)

    # --- populations by the mask lane's own hue windows (context, sat-filtered)
    pops = {}
    for fam, (lo, hi) in FAMILY_WINDOWS.items():
        sel = inside & blueh & (h >= lo) & (h < hi)
        vals = v[sel]
        pops[fam] = {
            "hue_window": [lo, hi],
            "texels": int(sel.sum()),
            "value_p50": round(float(np.percentile(vals, 50)), 4) if vals.size else None,
            "value_p99": round(float(np.percentile(vals, 99)), 4) if vals.size else None,
        }

    # --- what the shader does, before and after the gate
    def classify(consts, band_a, band_b) -> dict:
        wa = family_weight(tex, ANCHOR_A, consts, band_a)
        wb = family_weight(tex, ANCHOR_B, consts, band_b)
        ia = (wa > 0.5) & inside
        ib = (wb > 0.5) & inside
        both = (wa > 0.0) & (wb > 0.0) & inside
        return {
            "texels_family_a_gt_0.5": int(ia.sum()),
            "texels_family_b_gt_0.5": int(ib.sum()),
            "texels_both_gt_0.5": int((ia & ib).sum()),
            "share_both_gt_0.5": round(float((ia & ib).sum()) / n_inside, 4),
            "texels_both_gt_0.0": int(both.sum()),
            "texels_neither_gt_0.5": int((~ia & ~ib & inside).sum()),
            "share_neither_gt_0.5": round(float((~ia & ~ib & inside).sum()) / n_inside, 4),
            "per_region_gt_0.5": {
                r: {"a": int((ia & region[r]).sum()), "b": int((ib & region[r]).sum()),
                    "both": int((ia & ib & region[r]).sum()),
                    "neither": int((~ia & ~ib & region[r]).sum()),
                    "masked": int(region[r].sum())}
                for r in REGIONS
            },
        }

    today = classify(SHADER_DEFAULTS, None, None)
    gated = classify(SHADER_DEFAULTS, BAND_A, BAND_B)
    lane = classify(MASK_DEFAULTS, None, None)

    # --- texels the gate leaves to their baked colour. "Visible" = the hue test
    #     matches at least one anchor and sat/val pass, i.e. texels the shader can
    #     recolour at all today. An orphan is a visible texel the gate then zeroes on
    #     BOTH families: it would keep its baked colour in the middle of a recoloured
    #     area. The chosen bands must orphan none; a lower dark-band cut is measured
    #     below because it orphans isolated single texels (speckle).
    hue_visible = ((family_weight(tex, ANCHOR_A, SHADER_DEFAULTS, None) > 0.0)
                   | (family_weight(tex, ANCHOR_B, SHADER_DEFAULTS, None) > 0.0)) & inside
    wa_g = family_weight(tex, ANCHOR_A, SHADER_DEFAULTS, BAND_A)
    wb_g = family_weight(tex, ANCHOR_B, SHADER_DEFAULTS, BAND_B)
    preserved_in_dead_zone = int((hue_visible & (wa_g <= 0.0) & (wb_g <= 0.0)).sum())
    neither_gt0_today = int((~hue_visible & inside).sum())
    neither_gt0_gated = int((((wa_g <= 0.0) & (wb_g <= 0.0)) & inside).sum())

    alternatives = []
    for lo in (0.60, 0.65, 0.70, 0.72, 0.74):
        wa = family_weight(tex, ANCHOR_A, SHADER_DEFAULTS, (0.0, lo))
        wb = family_weight(tex, ANCHOR_B, SHADER_DEFAULTS, BAND_B)
        orphan = hue_visible & (wa <= 0.0) & (wb <= 0.0)
        cs = connected(orphan, 1)
        alternatives.append({
            "band_a_upper": lo,
            "orphan_texels": int(orphan.sum()),
            "orphan_components": len(cs),
            "largest_orphan_component": cs[0]["size"] if cs else 0,
            "median_orphan_component": int(np.median([c["size"] for c in cs])) if cs else 0,
            "orphan_speckles_le_4px": sum(1 for c in cs if c["size"] <= 4),
        })

    # --- which of the 18 slots can still move a texel, and by how much the colour
    #     actually changes (a slot whose target equals what is already painted there
    #     moves texels without changing anything). The movable count is a property of
    #     (region, family); the colour delta is per outfit.
    outfits = {
        "circuit": {"torso_a": "#315cff", "torso_b": "#1c335a", "hip_a": "#315cff",
                    "hip_b": "#9ef8ff", "foot_a": "#183567", "foot_b": "#9ef8ff"},
        "legend": {"torso_a": "#fff0a3", "torso_b": "#5a471b", "hip_a": "#59471c",
                   "hip_b": "#fff0a3", "foot_a": "#fef4d5", "foot_b": "#5a4617"},
        "signature": {"torso_a": "#03c7ed", "torso_b": "#195466", "hip_a": "#154959",
                      "hip_b": "#162f61", "foot_a": "#165568", "foot_b": "#17c8fe"},
    }
    slots = {}
    for r in REGIONS:
        for fam in ("a", "b"):
            anchor = ANCHOR_A if fam == "a" else ANCHOR_B
            band = BAND_A if fam == "a" else BAND_B
            w = family_weight(tex, anchor, SHADER_DEFAULTS, band)
            hit = (w > 0.0) & region[r]
            modal = None
            if hit.any():
                px = np.rint(tex[hit] * 255.0).astype(np.uint8)
                q = (px // 8 * 8).astype(np.int32)
                keys = q[:, 0] * 65536 + q[:, 1] * 256 + q[:, 2]
                vals, counts = np.unique(keys, return_counts=True)
                top = int(vals[int(np.argmax(counts))])
                modal = "#%02x%02x%02x" % (top >> 16, (top >> 8) & 0xFF, top & 0xFF)
            slots[f"{r}_{fam}"] = {
                "region": r, "family": fam,
                "texels_movable": int(hit.sum()),
                "movable_gt_0.5": int(((w > 0.5) & region[r]).sum()),
                "share_of_region": round(float(hit.sum()) / max(int(region[r].sum()), 1), 4),
                "baked_modal_hex": modal,
                "per_outfit": {
                    o: {"target_hex": outfits[o][f"{r}_{fam}"],
                        "delta_e76_target_vs_baked": (round(delta_e76(modal, outfits[o][f"{r}_{fam}"]), 1)
                                                      if modal else None)}
                    for o in outfits
                },
            }

    # --- texels that never recolour, gate or no gate
    neutral_in = (s < SHADER_DEFAULTS["sat_min"]) | (v < SHADER_DEFAULTS["val_min"]) | (v > SHADER_DEFAULTS["val_max"])
    neutral = np.zeros_like(inside)
    neutral[inside] = neutral_in[inside]
    neutral_by_region = {r: int((neutral & region[r]).sum()) for r in REGIONS}

    report = {
        "tool": "tools/character/measure_maestro_value_split.py",
        "texture": str(TEXTURE.relative_to(REPO)),
        "texture_sha256_prefix": hashlib.sha256(TEXTURE.read_bytes()).hexdigest()[:16],
        "mask": str(MASK.relative_to(REPO)),
        "mask_sha256_prefix": hashlib.sha256(MASK.read_bytes()).hexdigest()[:16],
        "anchors": {"a_dark": "#" + ANCHOR_A, "b_light": "#" + ANCHOR_B},
        "effective_constants": {
            "shader_defaults_on_the_masked_path": SHADER_DEFAULTS,
            "mask_defaults_assumed_by_the_mask_lane": MASK_DEFAULTS,
            "note": "outfit_catalogue.gd::_apply_profile does not push MASK_DEFAULTS, so a "
                    "profile material runs on the shader's declared defaults. Both are "
                    "measured so the difference cannot silently change the verdict.",
        },
        "masked_texels": n_inside,
        "recolourable_texels": n_rec,
        "recolourable_rule": "inside the mask AND sat >= sat_min(0.25) AND hue in [150,270)",
        "value_histogram_0.01": [int(c) for c in hist_all],
        "split": {
            "measured_discontinuity": split_value,
            "density_jump_top3": [{"at": j[1], "ratio": round(j[0], 3), "below": j[2], "above": j[3]}
                                  for j in jumps[:3]],
            "dark_family_texels": int(dark.sum()),
            "light_family_texels": int(light.sum()),
            "edge_band_texels": int(edge_band.sum()),
            "edge_band_adjacent_to_light_within_5px": int((edge_band & near_light).sum()),
            "edge_band_adjacency_share": round(float((edge_band & near_light).sum()) / max(int(edge_band.sum()), 1), 4),
            "mid_0.45_to_split_texels": int(mid_045.sum()),
            "mid_0.45_to_split_adjacent_share": round(float((mid_045 & near_light).sum()) / max(int(mid_045.sum()), 1), 4),
            "light_components_ge_64px": connected(light, 64)[:8],
            "light_components_total": len(connected(light, 1)),
        },
        "gate": {
            "band_a": list(BAND_A),
            "band_b": list(BAND_B),
            "feather": FEATHER,
            "ramps_meet_at": BAND_A[1] + FEATHER,
            "dead_zone": [BAND_A[1] + FEATHER, BAND_B[0] - FEATHER],
            "recolourable_texels_left_orphan_by_the_gate": preserved_in_dead_zone,
            "share_of_mask_left_orphan": round(preserved_in_dead_zone / n_inside, 6),
            "texels_matching_neither_anchor_gt0_today": neither_gt0_today,
            "texels_matching_neither_anchor_gt0_gated": neither_gt0_gated,
            "dark_band_upper_alternatives": alternatives,
            "alternatives_note": "cutting the dark band lower orphans isolated texels of the "
                                 "garment's own baked shading, which would read as speckles "
                                 "(a preserved navy texel inside a recoloured jersey).",
        },
        "shader_behaviour": {
            "today_hue_only_shader_defaults": today,
            "with_value_gate_shader_defaults": gated,
            "today_hue_only_mask_lane_constants": lane,
        },
        "slots_after_gate": slots,
        "neutral_texels_never_recolourable": {
            "texels": int(neutral.sum()),
            "share_of_mask": round(float(neutral.sum()) / n_inside, 4),
            "by_region": neutral_by_region,
            "rule": "sat < sat_min(0.25) or value outside [val_min 0.06, val_max 0.99]",
        },
    }

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=1) + "\n")

    print(f"MAESTRO_VALUE_SPLIT masked={n_inside} recolourable={n_rec} "
          f"({n_rec / n_inside:.4f})")
    print(f"MAESTRO_VALUE_SPLIT measured_discontinuity={split_value} "
          f"top_jump={jumps[0][0]:.2f}x at {jumps[0][1]} ({jumps[0][2]}->{jumps[0][3]})")
    print(f"MAESTRO_VALUE_SPLIT dark={int(dark.sum())} light={int(light.sum())} "
          f"edge_band={int(edge_band.sum())} (adjacent_to_light "
          f"{(edge_band & near_light).sum()}/{int(edge_band.sum())} = "
          f"{report['split']['edge_band_adjacency_share']:.3f})")
    print(f"MAESTRO_VALUE_SPLIT light_components>=64px={len(connected(light, 64))} "
          f"largest={connected(light, 64)[0]['size'] if light.any() else 0} "
          f"bbox={connected(light, 64)[0]['bbox_xywh'] if light.any() else None}")
    print(f"MAESTRO_VALUE_SPLIT today both>0.5={today['texels_both_gt_0.5']} "
          f"({today['share_both_gt_0.5']:.4f}) | gated both>0.5={gated['texels_both_gt_0.5']} "
          f"({gated['share_both_gt_0.5']:.4f}) neither={gated['texels_neither_gt_0.5']} "
          f"({gated['share_neither_gt_0.5']:.4f})")
    print(f"MAESTRO_VALUE_SPLIT lane_constants both>0.5={lane['texels_both_gt_0.5']}")
    print(f"MAESTRO_VALUE_SPLIT dead_zone={report['gate']['dead_zone']} "
          f"orphan_texels={preserved_in_dead_zone} neither_today={neither_gt0_today} "
          f"neither_gated={neither_gt0_gated}")
    for row in alternatives:
        print(f"MAESTRO_ALT band_a_upper={row['band_a_upper']} orphan={row['orphan_texels']} "
              f"components={row['orphan_components']} largest={row['largest_orphan_component']} "
              f"median={row['median_orphan_component']} speckles_le4px={row['orphan_speckles_le_4px']}")
    for name, row in slots.items():
        per = " ".join(f"{o}={row['per_outfit'][o]['target_hex']}/dE{row['per_outfit'][o]['delta_e76_target_vs_baked']}"
                       for o in row["per_outfit"])
        print(f"MAESTRO_SLOT {name} movable={row['texels_movable']} "
              f"(>0.5: {row['movable_gt_0.5']}) share_of_region={row['share_of_region']} "
              f"baked_modal={row['baked_modal_hex']} {per}")
    print(f"MAESTRO_VALUE_SPLIT neutral={int(neutral.sum())} "
          f"({report['neutral_texels_never_recolourable']['share_of_mask']:.4f}) "
          f"by_region={neutral_by_region}")
    print(f"MAESTRO_VALUE_SPLIT_REPORT {args.report.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
