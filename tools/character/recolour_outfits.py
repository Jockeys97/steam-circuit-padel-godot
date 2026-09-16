#!/usr/bin/env python3
"""One rigged model -> two outfits, by recolouring the single baked baseColorTexture.

The Meshy trial rig ships exactly one material (`Material_1`) and one baked
baseColorTexture, with no garment zones, no vertex colours and no separate
materials (measured, see tools/character/glb_tri_count.py). A Godot
`StandardMaterial3D` reads that one texture as `albedo_texture`, so the only
engine-side lever is "swap the texture". This script authors those swapped
textures offline, from the original, deterministically.

Two operators, both mask-driven:

1. `chroma` - a selective chroma shift applied only to texels above
   `protect_sat`. The ivory fur of the spitz is near-neutral (measured mean
   saturation 0.20, with the dominant fur bucket at sat ~0.13), so a saturation
   floor is a usable fur/skin protection mask: the fur survives, the garment
   moves. This is the "region mask" the packed atlas does not give us - it is
   inferred from colour, not from UV layout.

2. `anchors` - named source->target palette swaps. A texel matches an anchor
   when its hue is within `hue_tol_deg` (circular) and its saturation and value
   fall in range. The replacement keeps the source texel's shading by scaling
   the target colour with the source luminance ratio (clamped), so folds and
   baked-in shadow detail are not flattened.

Every output is the same size and channel layout as the input, so it drops into
the same Godot material slot unchanged.

Usage:
    python3 tools/character/recolour_outfits.py \
        --spec tools/character/outfits.json \
        --out-dir tools/character/out

Writes: outfit-<name>.png per outfit, mask-chromatic.png (the protection mask,
as evidence), diff-report.json and PROVENANCE.md.
No third-party imports beyond Pillow + numpy.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone

import numpy as np
from PIL import Image

TOOL_NAME = "tools/character/recolour_outfits.py"
TOOL_VERSION = "1.0.1"
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CHANGE_EPS = 2.0 / 255.0  # any-channel delta counted as a changed texel
DISTINCT_EPS = 10.0 / 255.0  # euclidean delta counted as a visibly changed texel


# --------------------------------------------------------------------------- #
# colour helpers
# --------------------------------------------------------------------------- #
def hex_to_rgb(h: str) -> np.ndarray:
    h = h.strip().lstrip("#")
    if len(h) != 6:
        raise ValueError("expected #rrggbb, got %r" % h)
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def srgb_to_linear(c: np.ndarray) -> np.ndarray:
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c: np.ndarray) -> np.ndarray:
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * (c ** (1 / 2.4)) - 0.055)


def rgb_to_hsv(a: np.ndarray):
    """Vectorised HSV. a: (...,3) in [0,1]. Returns h in degrees, s, v."""
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
    return (0.2126 * rgb_lin[..., 0] + 0.7152 * rgb_lin[..., 1] + 0.0722 * rgb_lin[..., 2])


def smoothstep(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


# --------------------------------------------------------------------------- #
# operators
# --------------------------------------------------------------------------- #
def chroma_mask(rgb: np.ndarray, protect_sat: float) -> np.ndarray:
    """Soft mask of texels allowed to move: 0 = protected (near-neutral fur/skin)."""
    _, s, _ = rgb_to_hsv(rgb)
    return smoothstep((s - protect_sat) / 0.10)


def apply_chroma(rgb: np.ndarray, mask: np.ndarray, hue_shift_deg: float,
                 sat_scale: float, val_scale: float) -> np.ndarray:
    h, s, v = rgb_to_hsv(rgb)
    h2 = h + hue_shift_deg
    s2 = np.clip(s * sat_scale, 0.0, 1.0)
    v2 = np.clip(v * val_scale, 0.0, 1.0)
    shifted = hsv_to_rgb(h2, s2, v2)
    m = mask[..., None]
    return rgb * (1 - m) + shifted * m


def apply_anchor(rgb: np.ndarray, mask: np.ndarray, src_hex: str, dst_hex: str,
                 d: dict) -> tuple[np.ndarray, np.ndarray]:
    """Blend matched texels toward the target colour, keeping source shading."""
    src = hex_to_rgb(src_hex)
    dst = hex_to_rgb(dst_hex)
    h, s, v = rgb_to_hsv(rgb)
    hs, ss, vs = rgb_to_hsv(src.reshape(1, 1, 3))
    hs, ss, vs = float(hs[0, 0]), float(ss[0, 0]), float(vs[0, 0])

    dh = np.abs(((h - hs + 180.0) % 360.0) - 180.0)
    w = smoothstep((d["hue_tol_deg"] - dh) / max(d["hue_tol_deg"], 1e-6))
    w *= smoothstep((s - d["sat_min"]) / 0.12)
    w *= smoothstep((v - d["val_min"]) / 0.12)
    w *= smoothstep((d["val_max"] - v) / 0.12)
    w *= mask
    w *= float(d.get("strength", 1.0))

    src_lin = srgb_to_linear(dst)
    target_luma = float(luma_lin(src_lin.reshape(1, 1, 3))[0, 0])
    pix_luma = luma_lin(srgb_to_linear(rgb))
    ratio = np.clip(pix_luma / max(float(luma_lin(srgb_to_linear(src.reshape(1, 1, 3)))[0, 0]), 1e-4),
                    d["luma_clamp"][0], d["luma_clamp"][1])
    shaded = linear_to_srgb(src_lin * ratio[..., None])
    out = rgb * (1 - w[..., None]) + shaded * w[..., None]
    return out, w


def build_outfit(rgb: np.ndarray, outfit: dict, d: dict):
    mask = chroma_mask(rgb, d["protect_sat"])
    out = rgb
    c = outfit.get("chroma") or {}
    if c:
        out = apply_chroma(out, mask, c.get("hue_shift_deg", 0.0),
                           c.get("sat_scale", 1.0), c.get("val_scale", 1.0))
    anchor_weights = []
    for a in outfit.get("anchors", []):
        merge = dict(d)
        merge.update({k: v for k, v in a.items() if k in
                      ("hue_tol_deg", "sat_min", "val_min", "val_max", "strength", "luma_clamp")})
        out, w = apply_anchor(out, mask, a["from"], a["to"], merge)
        anchor_weights.append(w)
    return out


# --------------------------------------------------------------------------- #
# measurement
# --------------------------------------------------------------------------- #
def measure(a: np.ndarray, b: np.ndarray) -> dict:
    d = np.abs(a - b)
    euc = np.sqrt((d ** 2).sum(-1))
    changed_any = (d.max(-1) > CHANGE_EPS)
    changed_vis = (euc > DISTINCT_EPS)
    return {
        "mean_abs_per_channel_255": [round(float(x) * 255.0, 3) for x in d.reshape(-1, 3).mean(0)],
        "mean_abs_overall_255": round(float(d.mean()) * 255.0, 3),
        "rms_overall_255": round(float(np.sqrt((d ** 2).mean())) * 255.0, 3),
        "mean_euclidean_255": round(float(euc.mean()) * 255.0, 3),
        "max_euclidean_255": round(float(euc.max()) * 255.0, 3),
        "pixels_total": int(d.shape[0] * d.shape[1]),
        "pixels_changed_any_channel_gt2": int(changed_any.sum()),
        "frac_changed_any_channel": round(float(changed_any.mean()), 6),
        "pixels_changed_euclidean_gt10": int(changed_vis.sum()),
        "frac_changed_euclidean_gt10": round(float(changed_vis.mean()), 6),
    }


def read_producer(repo_root: str) -> dict:
    """Read the Meshy rig task provenance from the repository, not from a literal.

    The producer row used to hardcode the rig task id. A hardcoded id is a claim
    that cannot be checked and silently goes stale if the asset is regenerated,
    so the id, task type and finish date are read from the Meshy response the
    asset was downloaded from (`meshy/rigged/volpe/rig_final.json`). If that file
    is missing or unreadable the fields say `unknown` rather than invent an id.
    Signed download URLs in that file are never read or printed.
    """
    rel = os.path.join("meshy", "rigged", "volpe", "rig_final.json")
    p = os.path.join(repo_root, rel)
    out = {"task_id": "unknown", "task_type": "unknown",
           "finished_utc": "unknown", "source": rel.replace(os.sep, "/")}
    try:
        with open(p, "r", encoding="utf-8") as fh:
            d = json.load(fh)
    except (OSError, ValueError) as exc:
        out["error"] = repr(exc)
        return out
    out["task_id"] = str(d.get("id") or "unknown")
    out["task_type"] = str(d.get("type") or "unknown")
    fin = d.get("finished_at")
    if isinstance(fin, (int, float)):
        out["finished_utc"] = datetime.fromtimestamp(
            fin / 1000.0, timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    return out


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# --------------------------------------------------------------------------- #
def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--spec", default="tools/character/outfits.json")
    ap.add_argument("--source", default=None, help="override the spec's source texture")
    ap.add_argument("--out-dir", default="tools/character/out")
    ap.add_argument("--mask-dump", action="store_true", default=True,
                    help="also write mask-chromatic.png as evidence")
    args = ap.parse_args(argv)

    spec_path = os.path.abspath(args.spec)
    spec = json.loads(open(spec_path, "r", encoding="utf-8").read())
    src_path = os.path.abspath(args.source or spec["source_texture"])
    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)

    defaults = dict(spec.get("defaults", {}))
    im = Image.open(src_path)
    src_mode = im.mode
    rgb = np.asarray(im.convert("RGB")).astype(np.float64) / 255.0
    print("source  %s  %dx%d  mode=%s  sha256=%s"
          % (os.path.relpath(src_path), im.size[0], im.size[1], src_mode, sha256(src_path)[:16]))

    mask = chroma_mask(rgb, defaults["protect_sat"])
    if args.mask_dump:
        mp = os.path.join(out_dir, "mask-chromatic.png")
        Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), "L").save(mp)
        print("mask    %s  movable frac=%.4f" % (os.path.relpath(mp), float(mask.mean())))

    report = {
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "tool": TOOL_NAME,
        "tool_version": TOOL_VERSION,
        "spec": os.path.relpath(spec_path),
        "source_texture": os.path.relpath(src_path),
        "source_sha256": sha256(src_path),
        "source_size": list(im.size),
        "source_mode": src_mode,
        "protect_sat": defaults["protect_sat"],
        "movable_fraction": round(float(mask.mean()), 6),
        "producer": read_producer(REPO_ROOT),
        "outputs": {},
        "outfit_vs_source": {},
        "outfit_vs_outfit": {},
    }

    rendered = {}
    for outfit in spec["outfits"]:
        name = outfit["name"]
        out = build_outfit(rgb, outfit, defaults)
        out_u8 = (np.clip(out, 0, 1) * 255.0 + 0.5).astype(np.uint8)
        dst = os.path.join(out_dir, name + ".png")
        Image.fromarray(out_u8, "RGB").save(dst, optimize=True)
        rendered[name] = out
        report["outputs"][name] = {
            "label": outfit.get("label"),
            "path": os.path.relpath(dst),
            "bytes": os.path.getsize(dst),
            "sha256": sha256(dst),
        }
        m = measure(rgb, out)
        report["outfit_vs_source"][name] = m
        print("\n%s (%s) -> %s" % (name, outfit.get("label"), os.path.relpath(dst)))
        print("  vs source: mean|dRGB| %.3f/255 over %d px | changed(any>2) %.4f | changed(euc>10) %.4f | mean euc %.3f | rms %.3f"
              % (m["mean_abs_overall_255"], m["pixels_total"], m["frac_changed_any_channel"],
                 m["frac_changed_euclidean_gt10"], m["mean_euclidean_255"], m["rms_overall_255"]))

    names = list(rendered)
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            key = "%s__vs__%s" % (names[i], names[j])
            m = measure(rendered[names[i]], rendered[names[j]])
            report["outfit_vs_outfit"][key] = m
            print("\n%s" % key)
            print("  mean|dRGB| %.3f/255 | per-channel %s | changed(any>2) %.4f | changed(euc>10) %.4f | mean euc %.3f | rms %.3f"
                  % (m["mean_abs_overall_255"], m["mean_abs_per_channel_255"],
                     m["frac_changed_any_channel"], m["frac_changed_euclidean_gt10"],
                     m["mean_euclidean_255"], m["rms_overall_255"]))

    rp = os.path.join(out_dir, "diff-report.json")
    with open(rp, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1)
    print("\nreport  %s" % os.path.relpath(rp))

    write_provenance(report, os.path.join(out_dir, "PROVENANCE.md"), spec)
    print("proof   %s" % os.path.relpath(os.path.join(out_dir, "PROVENANCE.md")))
    return 0


def write_provenance(report: dict, path: str, spec: dict) -> None:
    lines = []
    A = lines.append
    A("# Provenance: one model, two outfits (texture step)")
    A("")
    A("Generated %s by `%s` v%s. No Meshy call, no paid API, no network access: this"
      % (report["generated_utc"], report["tool"], report["tool_version"]))
    A("artifact is authored offline from the texture Meshy already produced. Zero credits spent.")
    A("")
    A("## Input")
    A("")
    A("| Field | Value |")
    A("|---|---|")
    A("| Source texture | `%s` |" % report["source_texture"])
    A("| sha256 | `%s` |" % report["source_sha256"])
    A("| Size / mode | %s / %s |" % (report["source_size"], report["source_mode"]))
    pr = report.get("producer", {})
    A("| Producer | Meshy `%s` task `%s`, finished %s (read from `%s`) |"
      % (pr.get("task_type", "unknown"), pr.get("task_id", "unknown"),
         pr.get("finished_utc", "unknown"), pr.get("source", "unknown")))
    A("| Material | `Material_1`, single `baseColorTexture`, no vertex colours (measured) |")
    A("| Spec | `%s` |" % report["spec"])
    A("")
    A("## Outputs")
    A("")
    A("| Outfit | Label | File | Bytes | sha256 (first 16) |")
    A("|---|---|---|---|---|")
    for name, o in report["outputs"].items():
        A("| `%s` | %s | `%s` | %d | `%s` |" % (name, o["label"], o["path"], o["bytes"], o["sha256"][:16]))
    A("")
    A("## Measured difference")
    A("")
    A("Every output is the same 2048x2048 RGB layout as the source, so each one drops into the")
    A("same Godot `StandardMaterial3D.albedo_texture` slot with no UV change and no re-import pass.")
    A("")
    A("Per outfit, against the source texture:")
    A("")
    A("| Outfit | mean abs diff (0-255) | mean per channel R,G,B | changed texels, any channel > 2 | changed texels, euclidean > 10 | mean euclidean | RMS |")
    A("|---|---|---|---|---|---|---|")
    for name, m in report["outfit_vs_source"].items():
        A("| `%s` | %.3f | %s | %.4f | %.4f | %.3f | %.3f |" % (
            name, m["mean_abs_overall_255"], m["mean_abs_per_channel_255"],
            m["frac_changed_any_channel"], m["frac_changed_euclidean_gt10"],
            m["mean_euclidean_255"], m["rms_overall_255"]))
    A("")
    A("Outfit against outfit (the number that answers 'two distinct outfits from one model'):")
    A("")
    A("| Pair | mean abs diff (0-255) | mean per channel R,G,B | changed texels, any channel > 2 | changed texels, euclidean > 10 | mean euclidean | RMS |")
    A("|---|---|---|---|---|---|---|")
    for key, m in report["outfit_vs_outfit"].items():
        A("| `%s` | %.3f | %s | %.4f | %.4f | %.3f | %.3f |" % (
            key, m["mean_abs_overall_255"], m["mean_abs_per_channel_255"],
            m["frac_changed_any_channel"], m["frac_changed_euclidean_gt10"],
            m["mean_euclidean_255"], m["rms_overall_255"]))
    A("")
    A("## What this proves, and what it does not")
    A("")
    A("Proves: the single baked baseColorTexture is a sufficient source to author two")
    A("measurably different outfit textures, offline, deterministically, at zero credit cost.")
    A("")
    A("Does not prove: which texels are garment and which are fur. The mask is inferred from")
    A("colour, so it cannot separate an ivory tee from ivory fur. It also says nothing about how")
    A("the swap looks in engine - that is proved separately by")
    A("`godot/prototypes/character_material/` renders and")
    A("`docs/wayfinder/evidence/character-pipeline-economics.md`.")
    A("")
    A("## Reproduce")
    A("")
    A("```bash")
    A("cd %s" % os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
    A("python3 tools/character/recolour_outfits.py --spec tools/character/outfits.json --out-dir tools/character/out")
    A("```")
    A("")
    A("Deterministic: same spec + same source texture hash -> same output hashes.")
    A("")
    A("## Region-mask caveat")
    A("")
    A("The chromatic mask (`out/mask-chromatic.png`, movable fraction %.4f of texels) is inferred"
      % report["movable_fraction"])
    A("from colour, not from UV layout, because the rig has no garment zones. It separates garment")
    A("from near-neutral fur reliably, but it cannot separate an ivory tee from ivory fur - those")
    A("are the same colour class in the atlas. A shipping pipeline wants Meshy's UV Unwrap or a")
    A("manual polygon selection to author true garment zones before the first outfit is authored.")
    A("")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
