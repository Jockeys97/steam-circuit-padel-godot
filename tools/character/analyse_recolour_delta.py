#!/usr/bin/env python3
"""Offline, sampled ceiling analysis for the one-rig-two-outfits recolour path.

READ-ONLY with respect to every existing artefact: this script never writes the
recolour outputs, never calls `tools/character/recolour_outfits.py`, and never
opens a GLB or an engine. It loads at most two images at a time, strided
(`--stride`, default 4 -> 512x512 samples from a 2048x2048 atlas), and only
prints JSON to stdout so the caller can append it to an evidence file.

The colour operators below are a line-faithful re-implementation of
`tools/character/recolour_outfits.py` v1.0.1 (same helpers: smoothstep mask on
saturation, per-anchor hue/sat/val smoothstep weight multiplied by that mask,
target colour scaled by the source luminance ratio clamped to `luma_clamp`).
Re-implementing them on a strided sample is how the analytic model is validated
against the real `outfit-a.png` / `outfit-b.png` PNGs without running the tool.

Usage:
    python3 tools/character/analyse_recolour_delta.py --stage mask
    python3 tools/character/analyse_recolour_delta.py --stage predict
    python3 tools/character/analyse_recolour_delta.py --stage strong --spec tools/character/outfits-strong.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CHANGE_EPS = 2.0 / 255.0
DISTINCT_EPS = 10.0 / 255.0

# Empirical render-transfer factor, taken from the measured in-engine render:
# whole-model mean rendered abs delta 1.2/255 for an atlas mean abs delta of
# 4.873/255 (docs/wayfinder/evidence/character-material-render.md s3.3/s3.4).
RENDER_TRANSFER = 1.2 / 4.873


# --------------------------------------------------------------------------- #
# colour helpers - behaviour identical to recolour_outfits.py v1.0.1
# --------------------------------------------------------------------------- #
def hex_to_rgb(h: str) -> np.ndarray:
    h = h.strip().lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * (c ** (1 / 2.4)) - 0.055)


def rgb_to_hsv(a: np.ndarray):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1)
    mn = a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-9
    rmax = nz & (mx == r)
    gmax = nz & (mx == g) & ~rmax
    bmax = nz & (mx == b) & ~rmax & ~gmax
    with np.errstate(invalid="ignore", divide="ignore"):
        h[rmax] = (60.0 * ((g - b) / np.where(d == 0, 1, d)))[rmax] % 360.0
        h[gmax] = (60.0 * ((b - r) / np.where(d == 0, 1, d)) + 120.0)[gmax]
        h[bmax] = (60.0 * ((r - g) / np.where(d == 0, 1, d)) + 240.0)[bmax]
    s = np.where(mx > 1e-9, d / np.where(mx == 0, 1, mx), 0.0)
    return h, s, mx


def hsv_to_rgb(h_deg: np.ndarray, s: np.ndarray, v: np.ndarray) -> np.ndarray:
    h = (h_deg % 360.0) / 60.0
    i = np.floor(h)
    f = h - i
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    i = i.astype(np.int64) % 6
    out = np.empty(h.shape + (3,), dtype=np.float64)
    for idx, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t),
                                        (p, q, v), (t, p, v), (v, p, q)]):
        m = i == idx
        out[..., 0][m] = rr[m]
        out[..., 1][m] = gg[m]
        out[..., 2][m] = bb[m]
    return out


def luma_lin(rgb_lin: np.ndarray) -> np.ndarray:
    return 0.2126 * rgb_lin[..., 0] + 0.7152 * rgb_lin[..., 1] + 0.0722 * rgb_lin[..., 2]


def smoothstep(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def chroma_mask(rgb: np.ndarray, protect_sat: float) -> np.ndarray:
    _, s, _ = rgb_to_hsv(rgb)
    return smoothstep((s - protect_sat) / 0.10)


def apply_chroma(rgb, mask, hue_shift_deg, sat_scale, val_scale):
    h, s, v = rgb_to_hsv(rgb)
    shifted = hsv_to_rgb(h + hue_shift_deg, np.clip(s * sat_scale, 0.0, 1.0),
                         np.clip(v * val_scale, 0.0, 1.0))
    m = mask[..., None]
    return rgb * (1 - m) + shifted * m


def apply_anchor(rgb, mask, src_hex, dst_hex, d):
    src = hex_to_rgb(src_hex)
    dst = hex_to_rgb(dst_hex)
    h, s, v = rgb_to_hsv(rgb)
    hs, ss, vs = rgb_to_hsv(src.reshape(1, 1, 3))
    hs, ss, vs = float(hs[0, 0]), float(ss[0, 0]), float(vs[0, 0])
    dh = np.abs(((h - hs + 180.0) % 360.0) - 180.0)
    w = smoothstep((d["hue_tol_deg"] - dh) / max(d["hue_tol_deg"], 1e-6))
    w = w * smoothstep((s - d["sat_min"]) / 0.12)
    w = w * smoothstep((v - d["val_min"]) / 0.12)
    w = w * smoothstep((d["val_max"] - v) / 0.12)
    w = w * mask
    w = w * float(d.get("strength", 1.0))
    src_lin = srgb_to_linear(dst)
    pix_luma = luma_lin(srgb_to_linear(rgb))
    ratio = np.clip(pix_luma / max(float(luma_lin(srgb_to_linear(src.reshape(1, 1, 3)))[0, 0]), 1e-4),
                    d["luma_clamp"][0], d["luma_clamp"][1])
    shaded = linear_to_srgb(src_lin * ratio[..., None])
    return rgb * (1 - w[..., None]) + shaded * w[..., None], w


def build_outfit(rgb: np.ndarray, outfit: dict, d: dict):
    mask = chroma_mask(rgb, d["protect_sat"])
    out = rgb
    c = outfit.get("chroma") or {}
    if c:
        out = apply_chroma(out, mask, c.get("hue_shift_deg", 0.0),
                           c.get("sat_scale", 1.0), c.get("val_scale", 1.0))
    weights = []
    for a in outfit.get("anchors", []):
        merge = dict(d)
        merge.update({k: v for k, v in a.items() if k in
                      ("hue_tol_deg", "sat_min", "val_min", "val_max", "strength", "luma_clamp")})
        out, w = apply_anchor(out, mask, a["from"], a["to"], merge)
        weights.append(w)
    return out, mask, weights


# --------------------------------------------------------------------------- #
def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_sampled(path: str, stride: int) -> np.ndarray:
    """Load one image, keep only the strided grid, release the full buffer."""
    im = Image.open(path)
    size = im.size
    mode = im.mode
    arr = np.asarray(im.convert("RGB"))[::stride, ::stride].copy()
    im.close()
    return arr, size, mode


def stats(a: np.ndarray, b: np.ndarray) -> dict:
    d = np.abs(a - b)
    euc = np.sqrt((d ** 2).sum(-1))
    return {
        "mean_abs_overall_255": round(float(d.mean()) * 255.0, 4),
        "mean_abs_per_channel_255": [round(float(x) * 255.0, 4) for x in d.reshape(-1, 3).mean(0)],
        "mean_euclidean_255": round(float(euc.mean()) * 255.0, 4),
        "rms_overall_255": round(float(np.sqrt((d ** 2).mean())) * 255.0, 4),
        "max_euclidean_255": round(float(euc.max()) * 255.0, 4),
        "samples_total": int(d.shape[0] * d.shape[1]),
        "frac_changed_any_gt2": round(float((d.max(-1) > CHANGE_EPS).mean()), 6),
        "frac_changed_euc_gt10": round(float((euc > DISTINCT_EPS).mean()), 6),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", required=True, choices=["inputs", "mask", "predict", "strong"])
    ap.add_argument("--spec", default=None)
    ap.add_argument("--source", default="meshy/rigged/volpe/volpe-texture.png")
    ap.add_argument("--stride", type=int, default=4)
    args = ap.parse_args(argv)

    src_path = os.path.join(REPO_ROOT, args.source)
    a_path = os.path.join(REPO_ROOT, "tools/character/out/outfit-a.png")
    b_path = os.path.join(REPO_ROOT, "tools/character/out/outfit-b.png")

    print(json.dumps({"stage": args.stage, "stride": args.stride,
                      "source_texture": args.source,
                      "source_sha256": sha256(src_path),
                      "outfit_a_sha256": sha256(a_path),
                      "outfit_b_sha256": sha256(b_path)}))
    if args.stage == "inputs":
        return 0

    src_u8, src_size, src_mode = load_sampled(src_path, args.stride)
    src = src_u8.astype(np.float64) / 255.0
    print(json.dumps({"source_size": list(src_size), "source_mode": src_mode,
                      "sample_shape": list(src_u8.shape)}))
    del src_u8

    default_spec = json.loads(open(os.path.join(REPO_ROOT, "tools/character/outfits.json"),
                                   encoding="utf-8").read())
    d = dict(default_spec["defaults"])

    if args.stage == "mask":
        m = chroma_mask(src, d["protect_sat"])
        _, s, v = rgb_to_hsv(src)
        h, _, _ = rgb_to_hsv(src)
        out = {
            "protect_sat": d["protect_sat"],
            "mask_mean": round(float(m.mean()), 6),
            "mask_ge_0p99_frac": round(float((m >= 0.99).mean()), 6),
            "mask_gt_0p01_frac": round(float((m > 0.01).mean()), 6),
            "mask_ge_0p5_frac": round(float((m >= 0.5).mean()), 6),
            "sat_percentiles_255": {str(p): round(float(np.percentile(s, p)) * 255.0, 2)
                                    for p in (10, 25, 50, 75, 90, 95, 99)},
            "mean_sat_all": round(float(s.mean()), 4),
        }
        sel = m >= 0.5
        hh = h[sel]
        bins = np.histogram(hh, bins=np.arange(0, 361, 30))[0]
        tot = max(int(sel.sum()), 1)
        out["hue_bins_30deg_of_masked"] = [
            {"lo": int(i * 30), "hi": int((i + 1) * 30),
             "frac_of_masked": round(float(bins[i]) / tot, 4)} for i in range(12)]
        out["masked_frac_of_atlas"] = round(float(sel.mean()), 6)
        print(json.dumps(out))
        return 0

    if args.stage == "predict":
        pred = {}
        weights = {}
        masks = {}
        for outf in default_spec["outfits"]:
            o, mk, ws = build_outfit(src, outf, d)
            pred[outf["name"]] = o
            weights[outf["name"]] = ws
            masks[outf["name"]] = mk
        pa = pred["outfit-a"]
        pb = pred["outfit-b"]
        del pred, weights

        # measured, sampled from the real PNGs - one image at a time
        au8, a_size, _ = load_sampled(a_path, args.stride)
        a_meas = au8.astype(np.float64) / 255.0
        del au8
        bu8, b_size, _ = load_sampled(b_path, args.stride)
        b_meas = bu8.astype(np.float64) / 255.0
        del bu8

        rep = {
            "source_sha256": sha256(src_path),
            "predicted_a_vs_b": stats(pa, pb),
            "measured_a_vs_b_sampled": stats(a_meas, b_meas),
            "predicted_a_vs_source": stats(src, pa),
            "measured_a_vs_source_sampled": stats(src, a_meas),
            "predicted_b_vs_source": stats(src, pb),
            "measured_b_vs_source_sampled": stats(src, b_meas),
        }
        resid = np.abs((pa - pb) - (a_meas - b_meas))
        rep["residual_abs_per_channel_255"] = [round(float(x) * 255.0, 4)
                                               for x in resid.reshape(-1, 3).mean(0)]
        rep["residual_abs_overall_255"] = round(float(resid.mean()) * 255.0, 4)
        # correlation between predicted and measured per-sample euclidean A-B delta
        pe = np.sqrt(((pa - pb) ** 2).sum(-1)).ravel()
        me = np.sqrt(((a_meas - b_meas) ** 2).sum(-1)).ravel()
        if pe.std() > 0 and me.std() > 0:
            rep["pearson_r_euclid_delta"] = round(float(np.corrcoef(pe, me)[0, 1]), 5)
        # signed mean colour A-B
        rep["signed_AB_predicted_255"] = [round(float(x) * 255.0, 4)
                                          for x in (pa - pb).reshape(-1, 3).mean(0)]
        rep["signed_AB_measured_255"] = [round(float(x) * 255.0, 4)
                                         for x in (a_meas - b_meas).reshape(-1, 3).mean(0)]
        # where it moved: separation over the changed set
        dm = np.abs(a_meas - b_meas)
        sel = dm.max(-1) > CHANGE_EPS
        rep["meas_changed_frac"] = round(float(sel.mean()), 6)
        if sel.sum():
            rep["meas_abs_over_changed_255"] = round(float(dm[sel].mean()) * 255.0, 4)
            rep["meas_signed_over_changed_255"] = [round(float(x) * 255.0, 4)
                                                   for x in (a_meas - b_meas)[sel].mean(0)]
        dp = np.abs(pa - pb)
        selp = dp.max(-1) > CHANGE_EPS
        rep["pred_changed_frac"] = round(float(selp.mean()), 6)
        if selp.sum():
            rep["pred_abs_over_changed_255"] = round(float(dp[selp].mean()) * 255.0, 4)
        # fur-protection check: predicted movement where the mask is closed
        mk = masks["outfit-a"]
        prot = mk < 0.01
        rep["protected_frac"] = round(float(prot.mean()), 6)
        if prot.sum():
            rep["pred_abs_a_vs_source_over_protected_255"] = round(
                float(np.abs(pa - src)[prot].mean()) * 255.0, 5)
        print(json.dumps(rep))
        return 0

    if args.stage == "strong":
        spec = json.loads(open(os.path.join(REPO_ROOT, args.spec), encoding="utf-8").read())
        d2 = dict(spec["defaults"])
        outs = {}
        for outf in spec["outfits"]:
            o, mk, ws = build_outfit(src, outf, d2)
            outs[outf["name"]] = (o, mk, ws)
        names = list(outs)
        rep = {"spec": args.spec, "protect_sat": d2["protect_sat"], "per_outfit": {}}
        for n, (o, mk, ws) in outs.items():
            s_st = stats(src, o)
            rep["per_outfit"][n] = {
                "label": next(x.get("label") for x in spec["outfits"] if x["name"] == n),
                "vs_source": s_st,
                "anchor_hit_frac_ge_0p99": [round(float((w >= 0.99).mean()), 6) for w in ws],
                "anchor_hit_frac_gt_0p5": [round(float((w > 0.5).mean()), 6) for w in ws],
                "predicted_rendered_model_mean_abs_255": round(
                    s_st["mean_abs_overall_255"] * RENDER_TRANSFER, 4),
            }
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                s_st = stats(outs[names[i]][0], outs[names[j]][0])
                dm = np.abs(outs[names[i]][0] - outs[names[j]][0])
                sel = dm.max(-1) > CHANGE_EPS
                s_st["abs_over_changed_255"] = round(float(dm[sel].mean()) * 255.0, 4) if sel.sum() else 0.0
                rep["pair_%s__vs__%s" % (names[i], names[j])] = {
                    "atlas": s_st,
                    "predicted_rendered_model_mean_abs_255": round(
                        s_st["mean_abs_overall_255"] * RENDER_TRANSFER, 4),
                    "predicted_rendered_garment_window_255": round(
                        s_st["abs_over_changed_255"] * RENDER_TRANSFER, 4),
                }
        # ceiling: what the mask allows at maximum separation
        mk = outs[names[0]][1]
        rep["mask_mean"] = round(float(mk.mean()), 6)
        rep["mask_full_frac"] = round(float((mk >= 0.99).mean()), 6)
        rep["ceiling_note"] = ("atlas mean abs = mask_mean x per-texel separation; "
                               "per-texel separation is bounded by 255/255")
        rep["legal_max_atlas_mean_abs_255"] = round(float(mk.mean()) * 255.0, 4)
        rep["legal_max_rendered_model_mean_abs_255"] = round(
            float(mk.mean()) * 255.0 * RENDER_TRANSFER, 4)
        print(json.dumps(rep))
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
