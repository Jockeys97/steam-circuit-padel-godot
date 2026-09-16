#!/usr/bin/env python3
"""Memory-lean row-band driver for tools/character/recolour_outfits.py.

WHY THIS EXISTS (measured, not assumed): the original tool materialises the whole
2048x2048 atlas as float64 and every operator intermediate at full size. Peak RSS
measured on this host: 765,836 kB. The host has 3,910 MB RAM, 0 swap and other
tenants, so the run was killed by the global OOM killer (signal 9, exit 137) with
283 MB available. This driver produces the SAME BYTES in ~10x less memory.

It is a driver, not a fork: every colour operator is imported unchanged from
`recolour_outfits.py`, which is not modified. That is sound because each operator
(`chroma_mask`, `apply_chroma`, `apply_anchor`, and therefore `build_outfit`) is a
strictly per-texel elementwise function -- no convolution, no global normalisation,
no spatial term -- so evaluating it on a horizontal band of rows gives bit-identical
results to evaluating it on the whole image. That claim is CHECKED, not asserted:
`--verify-against DIR` re-runs the original spec and requires the output PNG sha256s
to equal the ones the original tool already wrote.

All difference statistics are accumulated in streaming form (sums, counts, running
max) so no pair of full float images is ever resident.

Usage:
    /root/scrappy/.venv/bin/python3 tools/character/recolour_outfits_tiled.py \
        --spec tools/character/outfits-strong.json \
        --out-dir tools/character/out-strong \
        --band 128

    # byte-identity gate against the artefacts the original tool produced:
    ... --spec tools/character/outfits.json --out-dir /tmp/tiled-check \
        --verify-against tools/character/out

Writes <name>.png per outfit, mask-chromatic.png, diff-report.json, PROVENANCE.md.
No Meshy call, no paid API, no network.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import recolour_outfits as ro  # noqa: E402  (the unmodified original)

TOOL_NAME = "tools/character/recolour_outfits_tiled.py"
TOOL_VERSION = "1.0.0"
CHANGE_EPS = ro.CHANGE_EPS
DISTINCT_EPS = ro.DISTINCT_EPS


class DiffAccumulator:
    """Streaming equivalent of recolour_outfits.measure(), band by band."""

    def __init__(self) -> None:
        self.n = 0                       # texels
        self.sum_abs = np.zeros(3)       # per channel
        self.sum_sq = 0.0
        self.sum_euc = 0.0
        self.max_euc = 0.0
        self.changed_any = 0
        self.changed_euc = 0

    def add(self, a: np.ndarray, b: np.ndarray) -> None:
        d = np.abs(a - b)
        euc = np.sqrt((d ** 2).sum(-1))
        self.n += d.shape[0] * d.shape[1]
        self.sum_abs += d.reshape(-1, 3).sum(0)
        self.sum_sq += float((d ** 2).sum())
        self.sum_euc += float(euc.sum())
        self.max_euc = max(self.max_euc, float(euc.max()))
        self.changed_any += int((d.max(-1) > CHANGE_EPS).sum())
        self.changed_euc += int((euc > DISTINCT_EPS).sum())

    def result(self) -> dict:
        n = max(self.n, 1)
        return {
            "mean_abs_per_channel_255": [round(float(x) / n * 255.0, 3) for x in self.sum_abs],
            "mean_abs_overall_255": round(float(self.sum_abs.sum()) / (n * 3) * 255.0, 3),
            "rms_overall_255": round(float(np.sqrt(self.sum_sq / (n * 3))) * 255.0, 3),
            "mean_euclidean_255": round(self.sum_euc / n * 255.0, 3),
            "max_euclidean_255": round(self.max_euc * 255.0, 3),
            "pixels_total": int(self.n),
            "frac_changed_any_channel": round(self.changed_any / n, 6),
            "frac_changed_euclidean_gt10": round(self.changed_euc / n, 6),
        }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--spec", default="tools/character/outfits.json")
    ap.add_argument("--source", default=None)
    ap.add_argument("--out-dir", default="tools/character/out-tiled")
    ap.add_argument("--band", type=int, default=128, help="rows per band (memory lever)")
    ap.add_argument("--verify-against", default=None,
                    help="directory of <name>.png written by the original tool; "
                         "exit 2 unless every sha256 matches")
    args = ap.parse_args(argv)

    spec_path = os.path.abspath(args.spec)
    spec = json.loads(open(spec_path, "r", encoding="utf-8").read())
    src_path = os.path.abspath(args.source or os.path.join(REPO_ROOT, spec["source_texture"]))
    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)
    defaults = dict(spec.get("defaults", {}))

    im = Image.open(src_path).convert("RGB")
    W, H = im.size
    src_u8 = np.asarray(im, dtype=np.uint8)
    im.close()
    print("source  %s  %dx%d  sha256=%s  band=%d"
          % (os.path.relpath(src_path, REPO_ROOT), W, H, ro.sha256(src_path)[:16], args.band))

    names = [o["name"] for o in spec["outfits"]]
    outs = {n: np.empty((H, W, 3), dtype=np.uint8) for n in names}
    mask_u8 = np.empty((H, W), dtype=np.uint8)

    mask_sum = 0.0
    acc_src = {n: DiffAccumulator() for n in names}
    acc_pair = {}
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            acc_pair["%s__vs__%s" % (names[i], names[j])] = DiffAccumulator()

    for y0 in range(0, H, args.band):
        y1 = min(y0 + args.band, H)
        rgb = src_u8[y0:y1].astype(np.float64) / 255.0

        mask = ro.chroma_mask(rgb, defaults["protect_sat"])
        mask_sum += float(mask.sum())
        mask_u8[y0:y1] = (np.clip(mask, 0, 1) * 255).astype(np.uint8)
        del mask

        band_f = {}
        for outfit in spec["outfits"]:
            out = ro.build_outfit(rgb, outfit, defaults)
            band_f[outfit["name"]] = out
            outs[outfit["name"]][y0:y1] = (np.clip(out, 0, 1) * 255.0 + 0.5).astype(np.uint8)
            acc_src[outfit["name"]].add(rgb, out)
        for key, acc in acc_pair.items():
            a, b = key.split("__vs__")
            acc.add(band_f[a], band_f[b])
        del band_f, rgb

    mp = os.path.join(out_dir, "mask-chromatic.png")
    Image.fromarray(mask_u8, "L").save(mp)
    movable = mask_sum / float(W * H)
    print("mask    %s  movable frac=%.4f" % (os.path.relpath(mp, REPO_ROOT), movable))
    del mask_u8

    report = {
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "tool": TOOL_NAME,
        "tool_version": TOOL_VERSION,
        "driver_of": ro.TOOL_NAME,
        "driver_of_version": ro.TOOL_VERSION,
        "band_rows": args.band,
        "spec": os.path.relpath(spec_path, REPO_ROOT),
        "source_texture": os.path.relpath(src_path, REPO_ROOT),
        "source_sha256": ro.sha256(src_path),
        "source_size": [W, H],
        "source_mode": "RGB",
        "protect_sat": defaults["protect_sat"],
        "movable_fraction": round(movable, 6),
        "producer": ro.read_producer(REPO_ROOT),
        "outputs": {},
        "outfit_vs_source": {},
        "outfit_vs_outfit": {},
    }

    for outfit in spec["outfits"]:
        n = outfit["name"]
        dst = os.path.join(out_dir, n + ".png")
        Image.fromarray(outs[n], "RGB").save(dst, optimize=True)
        outs[n] = None
        report["outputs"][n] = {
            "label": outfit.get("label"),
            "path": os.path.relpath(dst, REPO_ROOT),
            "bytes": os.path.getsize(dst),
            "sha256": ro.sha256(dst),
        }
        m = acc_src[n].result()
        report["outfit_vs_source"][n] = m
        print("\n%s (%s) -> %s" % (n, outfit.get("label"), os.path.relpath(dst, REPO_ROOT)))
        print("  vs source: mean|dRGB| %.3f/255 | changed(any>2) %.4f | mean euc %.3f | rms %.3f"
              % (m["mean_abs_overall_255"], m["frac_changed_any_channel"],
                 m["mean_euclidean_255"], m["rms_overall_255"]))

    for key, acc in acc_pair.items():
        m = acc.result()
        report["outfit_vs_outfit"][key] = m
        print("\n%s" % key)
        print("  mean|dRGB| %.3f/255 | per-channel %s | changed(any>2) %.4f | mean euc %.3f | rms %.3f"
              % (m["mean_abs_overall_255"], m["mean_abs_per_channel_255"],
                 m["frac_changed_any_channel"], m["mean_euclidean_255"], m["rms_overall_255"]))

    rp = os.path.join(out_dir, "diff-report.json")
    with open(rp, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1)
    print("\nreport  %s" % os.path.relpath(rp, REPO_ROOT))

    ro.write_provenance(report, os.path.join(out_dir, "PROVENANCE.md"), spec)
    print("proof   %s" % os.path.relpath(os.path.join(out_dir, "PROVENANCE.md"), REPO_ROOT))

    if args.verify_against:
        ref_dir = os.path.abspath(args.verify_against)
        bad = 0
        print("\n--- byte-identity gate against %s ---" % os.path.relpath(ref_dir, REPO_ROOT))
        for n in names:
            ref = os.path.join(ref_dir, n + ".png")
            got = os.path.join(out_dir, n + ".png")
            if not os.path.exists(ref):
                print("MISSING reference %s" % ref)
                bad += 1
                continue
            rh, gh = ro.sha256(ref), ro.sha256(got)
            same = rh == gh
            print("%s %s: reference %s / tiled %s" % ("ok" if same else "MISMATCH", n, rh, gh))
            if not same:
                bad += 1
        if bad:
            print("VERIFY_FAIL %d/%d" % (bad, len(names)))
            return 2
        print("VERIFY_PASS %d/%d byte-identical" % (len(names), len(names)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
