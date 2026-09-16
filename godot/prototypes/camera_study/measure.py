#!/usr/bin/env python3
"""measure.py — OFFLINE pixel measurement of the camera study frames.

Runs no engine. Reads only `out/index__<W>x<H>.json` and the PNGs beside it, and
writes `out/measure__<W>x<H>.{json,md}`, the two contact sheets and
`out/inventory.md` (bytes + sha256 + dimensions of everything the study wrote).

WHERE THE NUMBERS COME FROM
  * Body / ball / court pixel counts come from the ID pass (`*__mask.png`), where
    every subject carries one exact unshaded RGB. A pixel is that subject's when
    each channel is on the right side of a wide threshold, so a stray +-1 from the
    colour pipeline cannot change a count.
  * "Hidden behind the HUD" is those same pixels intersected with the HUD panel
    rectangles the ENGINE reported for that exact frame (`hud_panels` in the JSON).
    The panels' 8 px rounded corners are ignored, which slightly OVER-states how
    much a panel hides - the honest direction for this question.
  * "Court surface in frame" is a 41x27 grid of points on the court floor, counted
    by whether they project inside the frame. "Court quad in frame" is the
    projected corner quad clipped to the frame (Sutherland-Hodgman). The quad is
    the intuitive one and it breaks on a low camera, where the near corners project
    thousands of pixels away and inflate the denominator; the grid does not. Both
    are reported.
  * The mask pass hides the glass cage, so a body behind a translucent pane counts
    as fully visible. In the beauty frame it is dimmed, not hidden - that is a
    readability question the pixels here do not answer.

Nothing in here decides anything. It measures.
"""
import hashlib
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")

SUBJECTS = ["player", "playerMate", "opponent", "opponentMate", "ball", "court"]
NEAR = ["player", "playerMate"]
LABELS = {
    "player": "near player",
    "playerMate": "near partner",
    "opponent": "far player",
    "opponentMate": "far partner",
}

HI = 160   # a channel the ID colour says is 255 must be at least this
LO = 95    # a channel the ID colour says is 0 must be at most this


# ---------------------------------------------------------------------------
# pixels
# ---------------------------------------------------------------------------

def binary(img, rgb):
    """1-bit-ish L image: 255 where the pixel is this ID colour."""
    r, g, b = img.split()
    out = None
    for chan, want in zip((r, g, b), rgb):
        if want >= 128:
            m = chan.point(lambda v: 255 if v >= HI else 0)
        else:
            m = chan.point(lambda v: 255 if v <= LO else 0)
        out = m if out is None else Image.composite(m, Image.new("L", img.size, 0), out)
    return out


def count(mask):
    return mask.histogram()[255]


def hud_union(size, panels):
    u = Image.new("L", size, 0)
    d = ImageDraw.Draw(u)
    for p in panels:
        x0, y0 = int(round(p["x"])), int(round(p["y"]))
        x1, y1 = int(round(p["x"] + p["w"])), int(round(p["y"] + p["h"]))
        d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=255)
    return u


def under(mask, region):
    """How many of this subject's pixels fall inside `region`."""
    keep = Image.composite(mask, Image.new("L", mask.size, 0), region)
    return count(keep)


# ---------------------------------------------------------------------------
# geometry
# ---------------------------------------------------------------------------

def clip_poly(poly, w, h):
    """Sutherland-Hodgman clip of a polygon to the frame rectangle."""
    def inside(p, edge):
        x, y = p
        return {"l": x >= 0, "r": x <= w, "t": y >= 0, "b": y <= h}[edge]

    def cut(a, b, edge):
        (x1, y1), (x2, y2) = a, b
        if edge in ("l", "r"):
            xe = 0.0 if edge == "l" else float(w)
            t = (xe - x1) / (x2 - x1) if x2 != x1 else 0.0
            return (xe, y1 + t * (y2 - y1))
        ye = 0.0 if edge == "t" else float(h)
        t = (ye - y1) / (y2 - y1) if y2 != y1 else 0.0
        return (x1 + t * (x2 - x1), ye)

    out = list(poly)
    for edge in ("l", "r", "t", "b"):
        if not out:
            return []
        src, out = out, []
        for i, cur in enumerate(src):
            prv = src[i - 1]
            if inside(cur, edge):
                if not inside(prv, edge):
                    out.append(cut(prv, cur, edge))
                out.append(cur)
            elif inside(prv, edge):
                out.append(cut(prv, cur, edge))
    return out


def area(poly):
    if len(poly) < 3:
        return 0.0
    s = 0.0
    for i, (x1, y1) in enumerate(poly):
        x2, y2 = poly[(i + 1) % len(poly)]
        s += x1 * y2 - x2 * y1
    return abs(s) * 0.5


def span_fraction(head_y, feet_y, lo, hi):
    """Fraction of the vertical segment [head_y, feet_y] that lies in [lo, hi]."""
    a, b = min(head_y, feet_y), max(head_y, feet_y)
    if b - a <= 1e-6:
        return 1.0 if lo <= a <= hi else 0.0
    return max(0.0, min(b, hi) - max(a, lo)) / (b - a)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def measure_option(rec):
    frame = (rec["frame"]["w"], rec["frame"]["h"])
    mask_path = os.path.join(OUT, rec["mask_png"])
    img = Image.open(mask_path).convert("RGB")
    assert img.size == frame, "%s is %s, JSON says %s" % (mask_path, img.size, frame)

    panels = rec["hud_panels"]
    union = hud_union(frame, panels)
    band_top = min([p["y"] for p in panels if p["y"] > frame[1] * 0.5] or [frame[1]])

    ids = {k: [int(v) for v in rec.get("_mask_colors", {}).get(k, [])] for k in SUBJECTS}
    out = {
        "id": rec["id"],
        "frame": {"w": frame[0], "h": frame[1]},
        "camera": rec["camera"],
        "hud_mode": rec["hud_mode"],
        "bottom_band_top_px": band_top,
        "bottom_band_h_px": frame[1] - band_top,
        "bottom_band_pct_of_frame": 100.0 * (frame[1] - band_top) / frame[1],
        "hud_panels": panels,
        "athletes": {},
        "unclassified_px": None,
    }

    classified = 0
    for key in SUBJECTS:
        rgb = ids[key]
        m = binary(img, rgb)
        n = count(m)
        classified += n
        hidden = under(m, union) if n else 0
        bbox = m.getbbox()
        if key in LABELS:
            g = rec["geometry"]["athletes"][key]
            head_y, feet_y = g["head_px"]["y"], g["feet_px"]["y"]
            out["athletes"][key] = {
                "label": LABELS[key],
                "near": g["near"],
                "body_px": n,
                "px_under_hud": hidden,
                "px_readable": n - hidden,
                "readable_pct_of_drawn": (100.0 * (n - hidden) / n) if n else 0.0,
                "mask_bbox": bbox,
                "feet_px_y": feet_y,
                "head_px_y": head_y,
                "height_px": abs(feet_y - head_y),
                "body_in_frame_pct": 100.0 * span_fraction(head_y, feet_y, 0.0, frame[1]),
                "body_above_band_pct": 100.0 * span_fraction(head_y, feet_y, 0.0, band_top),
                "feet_below_band_top": feet_y > band_top,
            }
        elif key == "ball":
            b = rec["geometry"]["ball"]
            out["ball"] = {
                "px": n,
                "diameter_px_from_area": 2.0 * math.sqrt(n / math.pi) if n else 0.0,
                "diameter_px_projected": 2.0 * b["radius_px"],
                "bbox": bbox,
                "bbox_w": (bbox[2] - bbox[0]) if bbox else 0,
                "bbox_h": (bbox[3] - bbox[1]) if bbox else 0,
                "px_under_hud": hidden,
                "world": b["world"],
                "radius_m": b["radius_m"],
            }
        else:
            c = rec["geometry"]["court_corners_px"]
            quad = [(c[k]["x"], c[k]["y"]) for k in ("near_left", "near_right", "far_right", "far_left")]
            behind = any(c[k]["behind"] for k in c)
            full = area(quad)
            vis = area(clip_poly(quad, frame[0], frame[1]))
            g = rec["geometry"]["court_grid"]
            out["court"] = {
                "grid_in_frame_pct": g["in_frame_pct"],
                "grid_near_half_in_frame_pct": g["near_half_in_frame_pct"],
                "grid_samples": g["samples"],
                "bed_px_drawn": n,
                "bed_px_under_hud": hidden,
                "bed_pct_of_frame": 100.0 * n / (frame[0] * frame[1]),
                "quad_px_total": None if behind else full,
                "quad_px_in_frame": None if behind else vis,
                "quad_in_frame_pct": None if behind or full <= 0 else 100.0 * vis / full,
                "any_corner_behind_camera": behind,
                "court_m": rec["geometry"]["court_m"],
            }

    r, g_, b = img.split()
    black = None
    for chan in (r, g_, b):
        m = chan.point(lambda v: 255 if v <= LO else 0)
        black = m if black is None else Image.composite(m, Image.new("L", img.size, 0), black)
    bg = count(black)
    total = frame[0] * frame[1]
    out["background_px"] = bg
    out["unclassified_px"] = total - classified - bg
    out["unclassified_pct"] = 100.0 * out["unclassified_px"] / total

    # per-panel overlap with the court bed: does this option put more HUD on top of
    # the playing area than the current composition does?
    bed = binary(img, ids["court"])
    per_panel = []
    for p in panels:
        one = hud_union(frame, [p])
        per_panel.append({
            "name": p["name"],
            "rect": [p["x"], p["y"], p["w"], p["h"]],
            "area_px": p["w"] * p["h"],
            "court_bed_px_covered": under(bed, one),
        })
    out["panels_over_court"] = per_panel
    out["court_bed_px_under_hud_total"] = out["court"]["bed_px_under_hud"]
    return out


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def contact_sheet(records, key, title, path, cell_w=440, extra=None):
    tiles = []
    if extra and os.path.exists(extra[1]):
        tiles.append((extra[0], extra[1]))
    for r in records:
        tiles.append((r["id"], os.path.join(OUT, r[key])))
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    with Image.open(tiles[0][1]) as probe:
        ar = probe.size[1] / probe.size[0]
    cell_h = int(round(cell_w * ar))
    lab_h = 26
    pad = 8
    top = 38
    W = cols * cell_w + (cols + 1) * pad
    H = top + rows * (cell_h + lab_h + pad) + pad
    sheet = Image.new("RGB", (W, H), (14, 16, 22))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
        big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 19)
    except OSError:
        font = big = ImageFont.load_default()
    d.text((pad, 10), title, fill=(235, 240, 250), font=big)
    for i, (name, p) in enumerate(tiles):
        cx = pad + (i % cols) * (cell_w + pad)
        cy = top + (i // cols) * (cell_h + lab_h + pad)
        with Image.open(p) as im:
            sheet.paste(im.convert("RGB").resize((cell_w, cell_h), Image.LANCZOS), (cx, cy))
        d.rectangle([cx, cy, cx + cell_w - 1, cy + cell_h - 1], outline=(60, 70, 90))
        d.text((cx + 4, cy + cell_h + 5), name, fill=(200, 212, 228), font=font)
    sheet.save(path)
    return path


def main(res):
    index_path = os.path.join(OUT, "index__%s.json" % res)
    with open(index_path) as f:
        index = json.load(f)
    colors = index["mask_colors"]

    results = []
    for rec in index["options"]:
        rec["_mask_colors"] = colors
        results.append(measure_option(rec))

    base = results[0]
    for r in results:
        r["delta_vs_current"] = {
            "near_body_readable_px": sum(r["athletes"][k]["px_readable"] for k in NEAR)
            - sum(base["athletes"][k]["px_readable"] for k in NEAR),
            "ball_diameter_px": r["ball"]["diameter_px_from_area"] - base["ball"]["diameter_px_from_area"],
            "court_quad_in_frame_pct": (
                None if r["court"]["quad_in_frame_pct"] is None or base["court"]["quad_in_frame_pct"] is None
                else r["court"]["quad_in_frame_pct"] - base["court"]["quad_in_frame_pct"]),
            "court_bed_px_under_hud": r["court"]["bed_px_under_hud"] - base["court"]["bed_px_under_hud"],
            "court_grid_in_frame_pp": r["court"]["grid_in_frame_pct"] - base["court"]["grid_in_frame_pct"],
            "hud_area_px": sum(p["area_px"] for p in r["panels_over_court"])
            - sum(p["area_px"] for p in base["panels_over_court"]),
        }

    payload = {"frame": index["frame"], "bodies": index["bodies"], "frozen": index["frozen"],
               "mask_colors": colors, "options": results}
    mj = os.path.join(OUT, "measure__%s.json" % res)
    with open(mj, "w") as f:
        json.dump(payload, f, indent=2)

    lines = []
    lines.append("## Measurements at %s (bodies=%s, frozen tick %s)\n" % (
        res, index["bodies"], index["frozen"]["tick"]))
    lines.append("### Near pair: body pixels drawn / hidden by HUD / readable, and how much of the body is above the bottom band\n")
    lines.append("| option | subject | body px | px under HUD | readable px | readable % | body in frame % | body above band % | feet below band top |")
    lines.append("|---|---|---:|---:|---:|---:|---:|---:|---|")
    for r in results:
        for k in SUBJECTS[:4]:
            a = r["athletes"][k]
            lines.append("| %s | %s | %d | %d | %d | %.1f | %.1f | %.1f | %s |" % (
                r["id"], a["label"], a["body_px"], a["px_under_hud"], a["px_readable"],
                a["readable_pct_of_drawn"], a["body_in_frame_pct"], a["body_above_band_pct"],
                "YES" if a["feet_below_band_top"] else "no"))
    lines.append("")
    lines.append("### Court, ball and the bottom band\n")
    lines.append("| option | court surface in frame % | near half in frame % | court quad in frame % | court bed px | court bed px under HUD | ball diameter px (area) | ball diameter px (projected) | bottom band height px | bottom band % of frame | HUD total area px |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for r in results:
        q = r["court"]["quad_in_frame_pct"]
        lines.append("| %s | %.1f | %.1f | %s | %d | %d | %.1f | %.1f | %.0f | %.1f | %d |" % (
            r["id"], r["court"]["grid_in_frame_pct"], r["court"]["grid_near_half_in_frame_pct"],
            "n/a" if q is None else "%.1f" % q, r["court"]["bed_px_drawn"],
            r["court"]["bed_px_under_hud"], r["ball"]["diameter_px_from_area"],
            r["ball"]["diameter_px_projected"], r["bottom_band_h_px"],
            r["bottom_band_pct_of_frame"], sum(p["area_px"] for p in r["panels_over_court"])))
    lines.append("")
    lines.append("`court surface in frame %` is a 41x27 grid of points on the court floor: "
                 "the share of the playing surface the camera can see. `court quad in frame %` is "
                 "the projected corner quad clipped to the frame - correct for the top-down options "
                 "and meaningless for a low camera, where the near corners project thousands of "
                 "pixels off-screen and blow the denominator up. Both are printed so the failure is "
                 "visible instead of silent.\n")
    lines.append("### Cameras\n")
    lines.append("| option | mode | solve | dolly back m | position | pitch deg | fov |")
    lines.append("|---|---|---|---:|---|---:|---:|")
    for r in results:
        c = r["camera"]
        lines.append("| %s | %s | %s | %.3f | (%.2f, %.2f, %.2f) | %.2f | %.2f |" % (
            r["id"], c["mode"], c.get("solve") or "-", c.get("dolly_back_m", 0.0),
            c["position"]["x"], c["position"]["y"], c["position"]["z"],
            c["rotation_degrees"]["x"], c["fov"]))
    lines.append("")
    lines.append("### Deltas against `current-composition` (positive = more of it)\n")
    lines.append("| option | near-pair readable px | ball diameter px | court surface in frame pp | court bed px under HUD | HUD area px |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for r in results:
        d = r["delta_vs_current"]
        lines.append("| %s | %+d | %+.1f | %+.1f | %+d | %+d |" % (
            r["id"], d["near_body_readable_px"], d["ball_diameter_px"],
            d["court_grid_in_frame_pp"], d["court_bed_px_under_hud"], d["hud_area_px"]))
    lines.append("")
    lines.append("### HUD panels, per option (engine rectangles, x y w h)\n")
    lines.append("| option | panel | rect | court bed px it covers |")
    lines.append("|---|---|---|---:|")
    for r in results:
        for p in r["panels_over_court"]:
            lines.append("| %s | %s | %.0f %.0f %.0f %.0f | %d |" % (
                r["id"], p["name"], p["rect"][0], p["rect"][1], p["rect"][2], p["rect"][3],
                p["court_bed_px_covered"]))
    lines.append("")
    lines.append("Unclassified mask pixels (neither a subject nor the black background, i.e. the "
                 "classifier's own error bar): " + ", ".join(
        "%s %.4f%% (%d px)" % (r["id"], r["unclassified_pct"], r["unclassified_px"]) for r in results))
    md = os.path.join(OUT, "measure__%s.md" % res)
    with open(md, "w") as f:
        f.write("\n".join(lines) + "\n")

    ref = os.path.join(OUT, "reference-in-game-rally__1280x720.png")
    cs1 = contact_sheet(index["options"], "beauty_png",
                        "Camera study %s - frames as played (HUD on). Reference tile = the game's own rally.png." % res,
                        os.path.join(OUT, "contact-sheet__%s.png" % res),
                        extra=("in-game rally.png (reference)", ref))
    cs2 = contact_sheet(index["options"], "mask_png",
                        "Camera study %s - ID pass the measurements count (glass/net/scenery hidden)." % res,
                        os.path.join(OUT, "contact-sheet-mask__%s.png" % res))

    inv = []
    for name in sorted(os.listdir(OUT)):
        p = os.path.join(OUT, name)
        if not os.path.isfile(p) or name == "inventory.md":
            continue
        dim = ""
        if name.endswith(".png"):
            with Image.open(p) as im:
                dim = "%dx%d" % im.size
        inv.append("| `%s` | %d | %s | `%s` |" % (name, os.path.getsize(p), dim, sha(p)))
    with open(os.path.join(OUT, "inventory.md"), "w") as f:
        f.write("| file | bytes | dimensions | sha256 |\n|---|---:|---|---|\n" + "\n".join(inv) + "\n")

    print("MEASURE_PASS res=%s options=%d json=%s md=%s sheets=%s,%s" % (
        res, len(results), mj, md, cs1, cs2))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "1280x720")
