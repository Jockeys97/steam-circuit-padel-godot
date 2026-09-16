#!/usr/bin/env python3
"""Measure how far apart the rendered outfits actually are, in pixels.

Consumes the frames written by `godot/src/character/roster_render.sh` (one per
reference (athlete, outfit) pair, plus one background-only frame at the same camera
and pose) and produces:

  * <out>/roster_pixel_measurements.json  -- the machine-readable dump the headless
    test `godot/tests/athlete_roster_test.gd` asserts against.
  * <out>/roster_contact_sheet_<res>.png  -- every outfit on the rig, one grid.

METHOD (every mask is derived from the frames, none is hand-drawn)

  body mask      pixels where any outfit frame differs from the background frame by
                 more than BODY_EPS. The pose is identical in every frame, so this is
                 an exact silhouette, not an estimate.

  garment mask   body pixels whose per-channel range ACROSS ALL OUTFIT FRAMES exceeds
                 GARMENT_EPS, i.e. the pixels the recolour actually moves. Fur, skin
                 and the racket are excluded because they never move, which is the
                 saturation guard doing its job.

  garment window the largest 4-connected component of the garment mask (on this rig:
                 the shorts). Reported with its bounding box so the measurement can be
                 reproduced by hand.

  separation     mean absolute per-channel difference between two frames, in /255,
                 measured over three regions:
                   garment_mask   -- THE FLOOR METRIC. Every pixel an outfit can
                                     affect at all. This is the right region for the
                                     question "are these two outfits different?",
                                     because it is exactly the area outfits control.
                   garment_window -- the largest single region, for comparability.
                   body           -- "whole-model", the metric the previous slice
                                     reported, kept so the two runs are comparable.

                 The first pass of this tool stated the floor on the garment WINDOW and
                 that was wrong: maestro base vs signature share a shorts colour
                 (#08bfe8 vs #03c7ed) and differ on the chevron, wristbands and shoe
                 stripes, so a shorts-only window called a clearly different outfit a
                 tint (3.31/255) while 4861 body pixels were moving by more than 8/255.
                 The region was corrected to the full garment mask; both numbers are
                 still reported per pair so the correction is auditable.

Cross-athlete pairs are measured too, and reported, but the floor is stated against
SAME-ATHLETE pairs: those are the ones a player chooses between in one outfit menu.
In the browser build two athletes are told apart by their own sprites and models, a
differentiator this single shared placeholder rig does not have at all.

Interpreter: /root/scrappy/.venv/bin/python3 (the only one here with numpy + PIL).
Zero network, zero paid spend, no asset generation.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_OUT = os.path.join(REPO, "godot", "src", "character", "out")

BODY_EPS = 6          # /255, any channel, frame vs background
GARMENT_EPS = 8       # /255, per-channel range across all outfit frames
TILE = 192            # contact-sheet tile size in px
LABEL_H = 18


def load_rgb(path: str) -> np.ndarray:
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.int16)


def largest_component(mask: np.ndarray) -> np.ndarray:
    """Largest 4-connected component of a bool mask, as a bool mask.

    Two-pass union-find over the rows; no scipy on this host, and a recursive flood
    fill on a 512x512 mask is a stack overflow waiting to happen.
    """
    h, w = mask.shape
    labels = np.zeros((h, w), dtype=np.int32)
    parent = [0]

    def find(x: int) -> int:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    nxt = 1
    for y in range(h):
        row = mask[y]
        prev_row = labels[y - 1] if y > 0 else None
        left = 0
        for x in np.flatnonzero(row):
            up = int(prev_row[x]) if prev_row is not None else 0
            lf = left if (x > 0 and row[x - 1]) else 0
            if up and lf:
                labels[y, x] = min(up, lf)
                union(up, lf)
            elif up or lf:
                labels[y, x] = up or lf
            else:
                parent.append(nxt)
                labels[y, x] = nxt
                nxt += 1
            left = labels[y, x]

    flat = labels.ravel()
    nz = flat > 0
    if not nz.any():
        return mask
    roots = np.array([find(i) for i in range(nxt)], dtype=np.int32)
    flat[nz] = roots[flat[nz]]
    counts = np.bincount(flat[nz])
    best = int(counts.argmax())
    return (labels == best)


def mean_abs_255(a: np.ndarray, b: np.ndarray, sel: np.ndarray) -> float:
    if not sel.any():
        return 0.0
    d = np.abs(a[sel].astype(np.float64) - b[sel].astype(np.float64))
    return float(d.mean())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=DEFAULT_OUT)
    ap.add_argument("--res", default="512x512")
    ap.add_argument("--floor", type=float, default=8.0,
                    help="garment-window mean-abs /255 below which a pair is a tint")
    args = ap.parse_args()

    out_dir = os.path.abspath(args.out_dir)
    manifest_path = os.path.join(out_dir, "roster_manifest_%s.json" % args.res)
    if not os.path.exists(manifest_path):
        print("MISSING %s -- run godot/src/character/roster_render.sh first" % manifest_path)
        return 1
    with open(manifest_path, "r", encoding="utf-8") as fh:
        manifest = json.load(fh)

    frames = [f for f in manifest["frames"] if f["kind"] == "outfit"]
    bg_row = next(f for f in manifest["frames"] if f["kind"] == "background")
    bg = load_rgb(os.path.join(out_dir, bg_row["file"]))

    imgs, keys, meta = [], [], {}
    for f in frames:
        img = load_rgb(os.path.join(out_dir, f["file"]))
        if img.shape != bg.shape:
            print("SHAPE MISMATCH %s" % f["file"])
            return 1
        imgs.append(img)
        keys.append(f["unlock_key"])
        meta[f["unlock_key"]] = f

    stack = np.stack(imgs)                                   # (n, h, w, 3)
    body = (np.abs(stack - bg).max(axis=(0, 3)) > BODY_EPS)
    spread = stack.max(axis=0) - stack.min(axis=0)            # (h, w, 3)
    garment_raw = body & (spread.max(axis=2) > GARMENT_EPS)
    garment = largest_component(garment_raw)
    ys, xs = np.nonzero(garment)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]

    per_outfit = []
    for key, img in zip(keys, imgs):
        sel = garment
        per_outfit.append({
            "unlock_key": key,
            "athlete_id": meta[key]["athlete_id"],
            "outfit_id": meta[key]["outfit_id"],
            "primary_hex": meta[key]["primary_hex"],
            "trim_hex": meta[key]["trim_hex"],
            "art_dependent": meta[key]["art_dependent"],
            "file": meta[key]["file"],
            "garment_mask_mean_rgb": [round(float(v), 3) for v in img[garment_raw].mean(axis=0)],
            "garment_window_mean_rgb": [round(float(v), 3) for v in img[sel].mean(axis=0)],
            "body_mean_rgb": [round(float(v), 3) for v in img[body].mean(axis=0)],
        })

    same, cross = [], []
    for (ka, ia), (kb, ib) in itertools.combinations(list(zip(keys, imgs)), 2):
        row = {
            "a": ka,
            "b": kb,
            "garment_mask_mean_abs_255": round(mean_abs_255(ia, ib, garment_raw), 4),
            "garment_window_mean_abs_255": round(mean_abs_255(ia, ib, garment), 4),
            "whole_model_mean_abs_255": round(mean_abs_255(ia, ib, body), 4),
        }
        (same if ka.split(":")[0] == kb.split(":")[0] else cross).append(row)

    same.sort(key=lambda r: r["garment_mask_mean_abs_255"])
    cross.sort(key=lambda r: r["garment_mask_mean_abs_255"])
    below = [r for r in same if r["garment_mask_mean_abs_255"] < args.floor]

    result = {
        "_tool": "tools/character/measure_roster_outfits.py",
        "_source_manifest": os.path.basename(manifest_path),
        "resolution": args.res,
        "floor": args.floor,
        "floor_metric": "garment_mask_mean_abs_255",
        "outfit_frames": len(frames),
        "body_eps_255": BODY_EPS,
        "garment_eps_255": GARMENT_EPS,
        "body_pixels": int(body.sum()),
        "garment_mask_pixels": int(garment_raw.sum()),
        "garment_window_pixels": int(garment.sum()),
        "garment_window_bbox_xyxy": bbox,
        "garment_window_frac_of_body": round(float(garment.sum()) / max(int(body.sum()), 1), 6),
        "same_athlete_pairs": same,
        "cross_athlete_pairs": cross,
        "per_outfit": per_outfit,
        "same_athlete_min_255": same[0]["garment_mask_mean_abs_255"] if same else -1.0,
        "same_athlete_max_255": same[-1]["garment_mask_mean_abs_255"] if same else -1.0,
        "whole_model_min_255": round(min(r["whole_model_mean_abs_255"] for r in same), 4)
                               if same else -1.0,
        "whole_model_max_255": round(max(r["whole_model_mean_abs_255"] for r in same), 4)
                               if same else -1.0,
        "cross_athlete_min_255": cross[0]["garment_mask_mean_abs_255"] if cross else -1.0,
        "pairs_below_floor": [{"pair": "%s|%s" % (r["a"], r["b"]),
                               "garment_mask_mean_abs_255": r["garment_mask_mean_abs_255"],
                               "garment_window_mean_abs_255": r["garment_window_mean_abs_255"],
                               "whole_model_mean_abs_255": r["whole_model_mean_abs_255"]}
                              for r in below],
    }
    dump = os.path.join(out_dir, "roster_pixel_measurements.json")
    with open(dump, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2)
        fh.write("\n")

    contact = build_contact_sheet(out_dir, args.res, frames, manifest)

    print("MEASURE_OK frames=%d body_px=%d garment_window_px=%d bbox=%s"
          % (len(frames), result["body_pixels"], result["garment_window_pixels"], bbox))
    print("FLOOR %.1f/255 on %s" % (args.floor, result["floor_metric"]))
    print("SAME_ATHLETE min=%.3f max=%.3f  below_floor=%d of %d"
          % (result["same_athlete_min_255"], result["same_athlete_max_255"],
             len(below), len(same)))
    for r in below:
        print("  BELOW %s|%s garment_mask=%.3f window=%.3f whole_model=%.3f"
              % (r["a"], r["b"], r["garment_mask_mean_abs_255"],
                 r["garment_window_mean_abs_255"], r["whole_model_mean_abs_255"]))
    if cross:
        print("CROSS_ATHLETE min=%.3f (%s|%s)"
              % (result["cross_athlete_min_255"], cross[0]["a"], cross[0]["b"]))
    print("WROTE %s" % os.path.relpath(dump, REPO))
    print("WROTE %s" % os.path.relpath(contact, REPO))
    return 0


def build_contact_sheet(out_dir: str, res: str, frames: list, manifest: dict) -> str:
    """One row per athlete, one tile per outfit, labelled. No cropping: the tiles are
    the rendered frames, downscaled, so the sheet cannot flatter the render."""
    by_athlete: dict = {}
    for f in frames:
        by_athlete.setdefault(f["athlete_id"], []).append(f)
    cols = max(len(v) for v in by_athlete.values())
    rows = len(by_athlete)
    gutter = 6
    name_w = 110
    sheet_w = name_w + cols * (TILE + gutter) + gutter
    sheet_h = gutter + rows * (TILE + LABEL_H + gutter)
    sheet = Image.new("RGB", (sheet_w, sheet_h), (24, 26, 31))
    draw = ImageDraw.Draw(sheet)

    for r, (athlete_id, entries) in enumerate(by_athlete.items()):
        top = gutter + r * (TILE + LABEL_H + gutter)
        draw.text((8, top + TILE // 2), athlete_id, fill=(235, 235, 235))
        for c, f in enumerate(entries):
            with Image.open(os.path.join(out_dir, f["file"])) as im:
                tile = im.convert("RGB").resize((TILE, TILE), Image.LANCZOS)
            x = name_w + gutter + c * (TILE + gutter)
            sheet.paste(tile, (x, top))
            label = "%s  %s %s" % (f["outfit_id"], f["primary_hex"], f["trim_hex"])
            draw.text((x + 2, top + TILE + 3), label, fill=(200, 205, 215))
            # Colour chips, so the sheet carries the reference's own values next to
            # what the renderer made of them.
            for i, hexv in enumerate((f["primary_hex"], f["trim_hex"])):
                rgb = tuple(int(hexv.lstrip("#")[j:j + 2], 16) for j in (0, 2, 4))
                draw.rectangle([x + TILE - 26 + i * 13, top + 4,
                                x + TILE - 15 + i * 13, top + 15], fill=rgb)

    path = os.path.join(out_dir, "roster_contact_sheet_%s.png" % res)
    sheet.save(path)
    return path


if __name__ == "__main__":
    sys.exit(main())
