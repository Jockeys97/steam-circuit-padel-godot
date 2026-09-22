#!/usr/bin/env python3
"""Measure the Maestro's three outfit palettes off the in-field 2D sprites.

WHY THIS TOOL EXISTS

The 3D rig recolours a baked model inside a UV mask that splits the body into three
regions -- torso, hip (shorts), foot (shoes) -- and every region carries two colour
families, `a` and `b`. An outfit is therefore six colours:
torso_a, torso_b, hip_a, hip_b, foot_a, foot_b (see
`godot/src/character/outfit_catalogue.gd::OUTFIT_PROFILES`, entry `fiamma`).

The browser reference (`js/data.js::ATHLETE_OUTFITS.maestro`) declares only TWO
colours per outfit. This tool measures what the in-field 2D sprites actually paint,
region by region, so the six slots can be filled from evidence instead of guesswork.

WHAT IT MEASURES

  * frame grid       every Maestro sheet is a horizontal strip; frame counts are read
                     from the asset contract (`js/data.js` runFrames) and verified
                     against the alpha gaps between figures.
  * body bbox        per frame, from alpha > ALPHA_MIN.
  * bands            fixed fractions of the body height, declared in BANDS below and
                     chosen from the measured row map of the base sprite, not from
                     eyeballing the artwork.
  * exclusions       skin, hair and the racket are removed before any colour is
                     reported. All three rules are heuristics and are declared in
                     SKIN_*, HAIR_TOL and racket_mask().
  * families         per (outfit, region), k-means with k=2 over the surviving
                     pixels. `a` is the larger cluster (the dominant garment mass),
                     `b` the smaller one (the trim). Same convention as the Fiamma
                     profile: kit on `a`, trim on `b`.

HEURISTICS, STATED AS SUCH

  skin      hue in [9, 38] deg with saturation > 0.30. This is the narrow hue window
            the port already uses for protected skin on these athletes; the Maestro's
            declared skin (#c98258) sits at hue 25 deg / sat 0.56, inside it.
  hair      within HAIR_TOL /255 (max channel distance) of the declared hair colour
            (#241b19, `js/data.js` visual.hair). The Maestro's hair is near-black;
            this also removes the racket's black frame and handle, which is wanted.
  racket    the largest 8-connected blob of the gold family (hue 40-62, sat > 0.6,
            value > 200), closed and dilated by RACKET_GROW px. The gold family is
            exclusively the racket's head face on all four Maestro variants: the
            measured gold blob is 616 px on each of the three outfit sprites and
            1720 px on the base sprite at its 1.665x resolution (616 * 1.665^2 =
            1706), i.e. the same unchanged object.

  None of these rules is a mask authored by hand, and none of them is exact: the
  racket rule removes a few px of the hand and of the shoulder behind the racket.

INTERPRETER

numpy + PIL only, no network, no paid API, no asset writes outside
`docs/agent-work/outfits-3d/evidence/maestro-palette/`. On this host:
  python3 -m venv <venv> && <venv>/bin/pip install pillow numpy

USAGE

  <venv>/bin/python tools/character/measure_maestro_palette.py
  <venv>/bin/python tools/character/measure_maestro_palette.py --out-dir <dir> --no-evidence
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_OUT = os.path.join(REPO, "docs", "agent-work", "outfits-3d", "evidence", "maestro-palette")

ALPHA_MIN = 200          # /255, body pixels; below this is antialiased edge or empty
CHANGE_EPS = 16          # /255, per-channel delta above which a pixel counts as changed
HAIR_TOL = 48            # /255, max-channel distance to the declared hair colour
RACKET_GROW = 11         # px, square dilation of the racket blob (closing is RACKET_CLOSE)
RACKET_CLOSE = 9         # px, square closing that fills the string holes
SKIN_HUE = (9.0, 38.0)   # deg, declared port heuristic
SKIN_SAT_MIN = 0.30
HUE_NEEDS_SAT = 0.15     # below this saturation a hue difference is meaningless (whites)
D_MATCH_DE = 20.0        # dE76 within which a measured mode counts as the declared colour
D_MATCH_HUE = 12.0       # deg, hue window in which a shaded mode counts as the declared colour
TRIM_SAT_MAX = 0.20      # measured saturation below which a slot is the base's own white/ivory trim

# PORT_OVERRIDES: slots where the port deliberately leaves what BOTH the sprite and the
# reference say. Every entry is labelled `port` in the output and carries its own reason;
# nothing else in the table is invented. This is the separation proposal for circuit vs
# signature, and it is exactly one slot: see the report's `separation_proposal`.
#
# MEASURED REASON. Circuit and signature put a dark navy/teal mass on the same body part
# (hip_a #1c325a vs #154959, dE76 22.2, dHue 24.6 deg, dVal 0.004) while their torso
# carries their identity (dE 62.4). The hip is the second largest garment mass and the
# only region where the two outfits read the same at match distance, so it is the region
# the port moves. The value used is the outfit's OWN declared primary, not a new colour:
# the shorts become the blue the outfit already declares for its kit. Revert to the
# measured `#1c325a` for strict sprite fidelity at the cost of the separation.
PORT_OVERRIDES = {
    ("circuit", "hip_a"): {
        "hex": "#315cff",
        "why": ("PORT: the measured shorts #1c325a sit dE76 22.2 from signature's #154959 "
                "(same value, 24.6 deg of hue), which is the closest the two outfits get in "
                "any region. Substituted with circuit's own declared primary #315cff: the "
                "hip separation rises to dE76 90.6 and the outfit reads blue from the waist "
                "down. Deviation from the sprite is real and deliberate -- the sprite paints "
                "these shorts navy. Revert to #1c325a for strict sprite fidelity."),
    },
}

# --- bands ------------------------------------------------------------------
# Fractions of the body bbox height (bbox = alpha > ALPHA_MIN, per frame, per sheet).
# Chosen from the base sprite's own row map, printed by --row-map: the shirt runs
# 0.15-0.48, the shorts 0.48-0.62, bare legs 0.62-0.82, socks 0.82-0.90 and the shoes
# 0.90-1.00. The three bands below map onto the rig's torso / hip / foot bone groups
# as the mask tool does: hip = hips + upright legs (the shorts), foot = feet + toes
# (the shoes). The sock band sits between two rig regions and is reported separately
# as evidence (see "socks" in the JSON) but is NOT one of the six slots.
BANDS = {
    "torso": (0.12, 0.48),
    "hip": (0.48, 0.66),
    "foot": (0.90, 1.00),
}
EXTRA_BANDS = {"socks": (0.82, 0.90)}   # evidence only, not a rig region

# Which sheets feed which region. MEASURED REASON, not taste: on the run sheets the
# running stride drops the hips, so the fixed hip band lands on bare thighs instead of
# the shorts (verified frame by frame on `mask-check-run.png`; the same check on
# `mask-check-idle.png` and `mask-check-action.png` shows the band correctly on the
# shorts). The run sheets are therefore used for torso and foot only, and their hip
# numbers are still reported per sheet as evidence.
BAND_SHEET_EXCLUDE = {"hip": ("run", "back-run")}

DATA_JS = os.path.join(REPO, "js", "data.js")

# Sheet contract: (sheet name, base sheet path, base frames, outfit path template, outfit frames)
SHEETS = [
    ("idle", "assets/sprites/maestro.webp", 4,
     "assets/outfits/maestro/{outfit}/idle.webp", 4),
    ("action", "assets/sprites/maestro-action.webp", 4,
     "assets/outfits/maestro/{outfit}/action.webp", 4),
    ("run", "assets/sprites/maestro-run-v3.webp", 8,
     "assets/outfits/maestro/{outfit}/run.webp", 8),
    ("back-idle", "assets/sprites/back/maestro.webp", 4,
     "assets/outfits/maestro/{outfit}/back-idle.webp", 4),
    ("back-action", "assets/sprites/back/maestro-action.webp", 4,
     "assets/outfits/maestro/{outfit}/back-action.webp", 4),
    ("back-run", "assets/sprites/back/maestro-run-v3.webp", 8,
     "assets/outfits/maestro/{outfit}/back-run.webp", 8),
]

OUTFITS = ["circuit", "legend", "signature"]


# ---------------------------------------------------------------------------
# io helpers
# ---------------------------------------------------------------------------
def load_frames(path: str, count: int) -> list:
    """Split a horizontal sprite strip into `count` frames by even division.

    The division is checked against the alpha gaps (see frame_gaps) before the
    numbers are trusted; a mismatch is reported, not silently averaged over.
    """
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
    fw = rgba.size[0] // count
    return [rgba.crop((i * fw, 0, (i + 1) * fw, rgba.size[1])) for i in range(count)]


def own_span(alpha: np.ndarray) -> tuple:
    """Column span that belongs to THIS frame's figure, plus the dropped pixels.

    The runtime slices sheets by even division (`js/render.js`: `naturalWidth /
    frameCount`), and on the four-frame sheets that boundary cuts a 2 px sliver of the
    NEXT figure into the frame. Measured: on `idle` the gaps run (250, 295), (571, 616),
    (852, 877) while the even boundaries fall at 298, 596, 894, so columns 296-297,
    594-595 and 892-893 of a neighbouring drawing land inside the frame. The sliver is
    left out of the colour measurement (it is not this figure) and counted here, so the
    report says how much was dropped instead of hiding it.
    """
    cols = (alpha > 16).sum(axis=0)
    runs, start = [], None
    for i, ink in enumerate(cols):
        if ink > 0 and start is None:
            start = i
        elif ink == 0 and start is not None:
            runs.append((start, i - 1))
            start = None
    if start is not None:
        runs.append((start, len(cols) - 1))
    if not runs:
        return 0, alpha.shape[1], 0
    ink_of = [(a, b, int(cols[a:b + 1].sum())) for a, b in runs]
    peak = max(r[2] for r in ink_of)
    kept = [r for r in ink_of if r[2] >= 0.20 * peak]
    c0 = min(r[0] for r in kept)
    c1 = max(r[1] for r in kept) + 1
    total = int(cols.sum())
    return c0, c1, total - sum(r[2] for r in kept)


def frame_gaps(path: str) -> list:
    """Column runs of fully transparent pixels, to check the even-division grid."""
    with Image.open(path) as im:
        a = np.asarray(im.convert("RGBA"))[:, :, 3]
    ink = (a > 16).sum(axis=0) == 0
    runs, start = [], None
    for i, z in enumerate(ink):
        if z and start is None:
            start = i
        elif not z and start is not None:
            runs.append((start, i - 1))
            start = None
    if start is not None:
        runs.append((start, len(ink) - 1))
    return runs


def declared_source() -> dict:
    """Read the reference's own two colours per outfit out of js/data.js.

    Machine-read rather than retyped, so the document cannot drift from the source.
    """
    with open(DATA_JS, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"ATHLETE_OUTFITS\s*=\s*\{(.*?)\n\};", text, re.S)
    if not m:
        raise SystemExit("ATHLETE_OUTFITS not found in %s" % DATA_JS)
    block = re.search(r"\n  maestro:\s*\[(.*?)\n  \],", m.group(1), re.S)
    if not block:
        raise SystemExit("maestro entry not found in ATHLETE_OUTFITS")
    out = {}
    for line in block.group(1).splitlines():
        oid = re.search(r'id:\s*"([a-z]+)"', line)
        cols = re.search(r'colors:\s*\["#([0-9a-fA-F]{6})",\s*"#([0-9a-fA-F]{6})"\]', line)
        if oid and cols:
            out[oid.group(1)] = ["#" + cols.group(1).lower(), "#" + cols.group(2).lower()]
    vis = re.search(r'id:\s*"maestro"(.*?)\n  \},', text, re.S)
    out["_visual"] = {}
    if vis:
        for key in ("skin", "hair", "kit", "secondary", "accent", "shoes", "headband"):
            mm = re.search(r'%s:\s*"(#[0-9a-fA-F]{6})"' % key, vis.group(1))
            if mm:
                out["_visual"][key] = mm.group(1).lower()
    return out


# ---------------------------------------------------------------------------
# colour helpers
# ---------------------------------------------------------------------------
def hex_of(rgb) -> str:
    r, g, b = (int(max(0, min(255, round(float(v))))) for v in rgb)
    return "#%02x%02x%02x" % (r, g, b)


def rgb_of(hexv: str):
    h = hexv.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def fam_by_name(palette: dict, outfit: str, region: str, family: str):
    """The (region, family) cluster of an outfit, or None."""
    e = (palette.get(outfit) or {}).get(region)
    if not e or not e["clusters"]:
        return None
    for c in e["clusters"]:
        if c["family"] == family:
            return c
    return e["clusters"][0]


def hsv_of(rgb: np.ndarray):
    """rgb: (..., 3) float 0-255 -> hue deg, sat 0-1, value 0-1."""
    a = rgb.astype(np.float64) / 255.0
    mx = a.max(axis=-1)
    mn = a.min(axis=-1)
    d = mx - mn
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    hue = np.zeros_like(mx)
    nz = d > 1e-9
    ri = (mx == r) & nz
    gi = (mx == g) & nz & ~ri
    bi = (mx == b) & nz & ~ri & ~gi
    with np.errstate(invalid="ignore", divide="ignore"):
        hue[ri] = (((g - b) / d) % 6)[ri]
        hue[gi] = ((b - r) / d + 2)[gi]
        hue[bi] = ((r - g) / d + 4)[bi]
    hue *= 60.0
    sat = np.where(mx > 1e-9, d / np.maximum(mx, 1e-9), 0.0)
    return hue, sat, mx


def srgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    """CIE L*a*b* (D65) from sRGB 0-255. CIE76 dE is used for all colour distances."""
    a = np.asarray(rgb, dtype=np.float64) / 255.0
    lin = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375],
                  [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T
    wp = np.array([0.95047, 1.0, 1.08883])
    t = xyz / wp
    d = 6.0 / 29.0
    f = np.where(t > d ** 3, np.cbrt(t), t / (3 * d ** 2) + 4.0 / 29.0)
    return np.stack([116 * f[..., 1] - 16,
                     500 * (f[..., 0] - f[..., 1]),
                     200 * (f[..., 1] - f[..., 2])], axis=-1)


def de76(a_rgb, b_rgb) -> float:
    la = srgb_to_lab(np.array(a_rgb, dtype=np.float64))
    lb = srgb_to_lab(np.array(b_rgb, dtype=np.float64))
    return float(np.sqrt(((la - lb) ** 2).sum()))


# ---------------------------------------------------------------------------
# masks
# ---------------------------------------------------------------------------
def largest_component(mask: np.ndarray) -> np.ndarray:
    """Largest 8-connected component of a bool mask (BFS; masks here are small)."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    best = np.zeros_like(mask)
    for sy in range(h):
        for sx in range(w):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            q = deque([(sy, sx)])
            seen[sy, sx] = True
            px = []
            while q:
                cy, cx = q.popleft()
                px.append((cy, cx))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
            if len(px) > int(best.sum()):
                best = np.zeros_like(mask)
                for (y, x) in px:
                    best[y, x] = True
    return best


def racket_mask(rgba: np.ndarray) -> np.ndarray:
    """Racket exclusion: the gold head face, closed to swallow the strings, grown.

    MEASURED BASIS: the gold family is the racket head on every Maestro variant. The
    blob is 616 px on each of the three outfit idle sprites and 1720 px on the base
    sprite, whose frame is 1.665x larger in each axis (616 * 1.665^2 = 1706). Same
    unchanged object, four sprites.
    """
    hue, sat, val = hsv_of(rgba[:, :, :3].astype(np.float64))
    gold = (hue > 40) & (hue < 62) & (sat > 0.6) & (val > 200 / 255.0)
    if gold.sum() < 32:
        return np.zeros(gold.shape, dtype=bool)
    blob = largest_component(gold)
    im = Image.fromarray((blob * 255).astype(np.uint8))
    im = im.filter(ImageFilter.MaxFilter(RACKET_CLOSE)).filter(ImageFilter.MinFilter(RACKET_CLOSE))
    im = im.filter(ImageFilter.MaxFilter(RACKET_GROW))
    return np.asarray(im) > 127


def exclusion_masks(rgba: np.ndarray, hair_hex: str) -> dict:
    """skin / hair / racket masks for one frame. Heuristics, all declared at the top."""
    rgb = rgba[:, :, :3].astype(np.float64)
    hue, sat, val = hsv_of(rgb)
    skin = (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN)
    hair = np.abs(rgb - np.array(rgb_of(hair_hex), dtype=np.float64)).max(axis=2) <= HAIR_TOL
    racket = racket_mask(rgba)
    return {"skin": skin, "hair": hair, "racket": racket}


def body_bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


# ---------------------------------------------------------------------------
# clustering
# ---------------------------------------------------------------------------
def modal_colours(px: np.ndarray, top: int = 8, levels: int = 16):
    """The region's raw modal palette: the `top` most populated RGB bins.

    Reported next to the two families so nothing is hidden by the k=2 split: if the
    shirt carries a third colour (a white stripe, say), it shows up here with its
    pixel count even though the rig only has two slots for that region.
    """
    if len(px) == 0:
        return []
    q = (px // levels).astype(np.int32)
    keys = q[:, 0] * 65536 + q[:, 1] * 256 + q[:, 2]
    uniq, cnt = np.unique(keys, return_counts=True)
    order = np.argsort(-cnt)[:top]
    out = []
    for i in order:
        members = px[keys == uniq[i]]
        out.append({"hex": hex_of(members.mean(axis=0)),
                    "count": int(cnt[i]),
                    "share_pct": round(float(100.0 * cnt[i] / len(px)), 2)})
    return out


def kmeans2(px: np.ndarray, iters: int = 100):
    """Deterministic k=2 k-means in RGB.

    Seeded from the data: the two most populated 16-level bins at least 96/255 apart,
    so the result is reproducible byte for byte and cannot land on two near-identical
    centres (which would split one garment colour in half and report it as two
    families).

    Each cluster reports BOTH a mean and a mode. The mean is the average of the shaded
    pixels in the cluster (shadows included, so it reads lighter/greyer than the paint
    on the fabric); the mode is the single most populated bin of the cluster, i.e. the
    flat colour an artist would name. The document uses the mode as the slot value and
    keeps the mean for the audit trail.
    """
    if len(px) == 0:
        return []
    if len(px) < 8:
        return [{"rgb": px.mean(axis=0), "count": len(px), "mode_rgb": px.mean(axis=0)}]
    q = (px // 16).astype(np.int32)
    keys = q[:, 0] * 65536 + q[:, 1] * 256 + q[:, 2]
    uniq, cnt = np.unique(keys, return_counts=True)
    order = np.argsort(-cnt)
    seeds = [px[keys == uniq[order[0]]].mean(axis=0)]
    for idx in order[1:]:
        cand = px[keys == uniq[idx]].mean(axis=0)
        if min(np.abs(cand - s).max() for s in seeds) >= 96:
            seeds.append(cand)
            break
    if len(seeds) < 2:
        return [{"rgb": px.mean(axis=0), "count": len(px), "mode_rgb": px.mean(axis=0)}]
    c = np.stack(seeds)
    labels = np.zeros(len(px), dtype=np.int32)
    for _ in range(iters):
        d = np.linalg.norm(px[:, None, :] - c[None, :, :], axis=2)
        new = d.argmin(axis=1)
        if np.array_equal(new, labels) and _ > 0:
            labels = new
            break
        labels = new
        for k in range(2):
            if (labels == k).any():
                c[k] = px[labels == k].mean(axis=0)
    out = []
    for k in range(2):
        sel = labels == k
        if not sel.any():
            continue
        sub = px[sel]
        mq = (sub // 16).astype(np.int32)
        mkeys = mq[:, 0] * 65536 + mq[:, 1] * 256 + mq[:, 2]
        mu, mc = np.unique(mkeys, return_counts=True)
        best = mu[int(np.argmax(mc))]
        mode_members = sub[mkeys == best]
        out.append({"rgb": c[k], "count": int(sel.sum()),
                    "mode_rgb": mode_members.mean(axis=0),
                    "mode_count": int(mode_members.shape[0]),
                    "spread_255": float(np.abs(sub - c[k]).mean())})
    out.sort(key=lambda r: -r["count"])
    return out


# ---------------------------------------------------------------------------
# measurement
# ---------------------------------------------------------------------------
def collect(band, excl: dict, alpha: np.ndarray):
    """Return the selection mask of one band: inside the band, opaque, not excluded.

    `band` is a (y0, y1) pair in pixels, already resolved from the body bbox.
    """
    h = alpha.shape[0]
    rows = np.arange(h)[:, None]
    y0, y1 = band
    sel = (rows >= y0) & (rows < y1) & (alpha > ALPHA_MIN)
    for m in excl.values():
        sel = sel & ~m
    return sel


def per_frame_bands(alpha: np.ndarray) -> dict:
    bb = body_bbox(alpha)
    if bb is None:
        return None
    _, y0, _, y1 = bb
    h = y1 - y0 + 1
    out = {}
    for name, (f0, f1) in {**BANDS, **EXTRA_BANDS}.items():
        out[name] = (y0 + f0 * h, y0 + f1 * h, bb)
    return out


ATLAS_PATH = os.path.join(REPO, "godot", "assets", "athletes", "maestro_texture_0.png")


def atlas_families() -> dict:
    """Inventory of the BAKED atlas the rig actually renders, read-only.

    NOT the mask and NOT the anchors: the anchors must be measured *inside* the mask by
    the mask tool (`tools/character/build_fiamma_outfit_mask.py` is the pattern), which
    does not exist for the Maestro yet. This inventory is here only so the document can
    say honestly which recolourable colour families the model has at all -- and it is
    the reason the six slots cannot be checked against the atlas from here.

    There is deliberately no webp/png write: the tool never writes an asset.
    """
    if not os.path.exists(ATLAS_PATH):
        return {"error": "atlas not found: %s" % os.path.relpath(ATLAS_PATH, REPO)}
    with Image.open(ATLAS_PATH) as im:
        a = np.asarray(im.convert("RGB")).astype(np.float64)
    tot = a.shape[0] * a.shape[1]
    hue, sat, val = hsv_of(a)
    navy = (sat > 0.2) & (val > 20 / 255.0) & (hue >= 195) & (hue <= 265)
    warm = (sat > 0.2) & (val > 20 / 255.0) & ((hue < 45) | (hue > 265))
    grey = (sat < 0.10) & (val > 40 / 255.0)
    dark = val <= 40 / 255.0
    out = {"path": os.path.relpath(ATLAS_PATH, REPO), "size": [int(a.shape[1]), int(a.shape[0])],
           "total_px": int(tot), "classes": {}}
    for name, sel in (("navy_hue195_265", navy), ("warm_hue_lt45_or_gt265", warm),
                      ("desaturated_grey", grey), ("near_black", dark)):
        px = a[sel]
        med = np.median(px, axis=0) if len(px) else np.zeros(3)
        out["classes"][name] = {"pixels": int(sel.sum()),
                                "share_pct": round(float(100.0 * sel.sum() / tot), 1),
                                "median_hex": hex_of(med)}
    # the navy family's own modes, at 8-level bins: this is what a mask-side anchor
    # measurement would start from, and it is the evidence that the atlas has ONE
    # saturated family rather than two favourably separated ones.
    if navy.sum() >= 32:
        q = (a[navy] // 8).astype(np.int32)
        keys = q[:, 0] * 1000000 + q[:, 1] * 1000 + q[:, 2]
        u, cnt = np.unique(keys, return_counts=True)
        order = np.argsort(-cnt)[:5]
        out["navy_modes"] = [{"hex": hex_of(np.array([(u[i] // 1000000) * 8 + 4,
                                                       ((u[i] // 1000) % 1000) * 8 + 4,
                                                       (u[i] % 1000) * 8 + 4], dtype=float)),
                              "share_pct": round(float(100.0 * cnt[i] / navy.sum()), 1)}
                             for i in order]
    # the saturated hue bands, so "no second recolourable hue" is a number, not a claim
    sel = (sat > 0.2) & (val > 20 / 255.0)
    hist, _ = np.histogram(hue[sel], bins=12, range=(0, 360))
    out["saturated_hue_bands_pct"] = {("%d-%d" % (i * 30, i * 30 + 30)): round(float(100.0 * h / max(1, hist.sum())), 1)
                                      for i, h in enumerate(hist)}
    out["note"] = ("the two saturated clusters are navy and skin/hair; there is no cyan "
                   "hue and no second saturated garment hue, and a desaturated grey cannot "
                   "be a family because the shader's family test needs sat > sat_min. "
                   "Anchors and coverage must come from the mask tool, not from here.")
    return out


CARD_BASE = os.path.join(REPO, "assets", "athletes", "maestro.webp")
CARD_PREVIEW = os.path.join(REPO, "assets", "outfits", "maestro", "{outfit}-preview.webp")


def card_check() -> dict:
    """How far each illustrated preview card is from the base card, read-only.

    The cards are ILLUSTRATIONS, not UV textures, and the port's reference is the
    in-field sprite. This block exists so the divergence is a measured number instead of
    an opinion: the cards are compared at the preview's own resolution, so no cropping or
    framing assumption is made beyond resizing the base card.
    """
    if not os.path.exists(CARD_BASE):
        return {"error": "base card not found: %s" % os.path.relpath(CARD_BASE, REPO)}
    with Image.open(CARD_BASE) as im:
        base = im.convert("RGB")
    out = {"base_card": os.path.relpath(CARD_BASE, REPO),
           "base_card_size": [int(base.size[0]), int(base.size[1])], "per_outfit": {}}
    for o in OUTFITS:
        path = CARD_PREVIEW.format(outfit=o)
        if not os.path.exists(path):
            out["per_outfit"][o] = {"error": "missing"}
            continue
        with Image.open(path) as im:
            card = im.convert("RGB")
        b = base.resize(card.size, Image.LANCZOS)
        aa = np.asarray(b).astype(np.int16)
        bb_ = np.asarray(card).astype(np.int16)
        d = np.abs(aa - bb_).max(axis=2)
        out["per_outfit"][o] = {
            "path": os.path.relpath(path, REPO), "size": [int(card.size[0]), int(card.size[1])],
            "pct_pixels_over_16_255": round(float(100.0 * (d > 16).mean()), 1),
            "mean_abs_255": round(float(d.mean()), 1),
        }
    out["note"] = ("a preview card that differs from the base card over most of its area "
                   "is a different illustration, not a recolour; the in-field sprite is "
                   "the reference for this document.")
    return out


MASK_REPORT = os.path.join(REPO, "docs", "agent-work", "outfits-3d", "evidence",
                           "maestro-mask-report.json")


def mask_report_cross_check() -> dict:
    """Read-only cross-check against the region-mask lane's own report.

    The Maestro region mask was authored in a parallel lane
    (tools/character/build_maestro_outfit_mask.py). This tool never writes there: it reads
    that lane's report and re-hashes the shipped mask, so the anchors, the shipped mask's
    sha256 prefix and the family-test verdict quoted in MAESTRO-PALETTE.md are checkable
    from one place instead of being copied by hand. Absence is reported, not invented.
    """
    out = {"report": os.path.relpath(MASK_REPORT, REPO)}
    if not os.path.exists(MASK_REPORT):
        out["present"] = False
        out["note"] = ("the mask lane's report is not in the tree; the profile's mask path, "
                       "anchors and sha256 prefix cannot be quoted and must stay TODO")
        return out
    out["present"] = True
    with open(MASK_REPORT) as fh:
        rep = json.load(fh)
    out["tool"] = rep.get("tool")
    out["mask"] = rep.get("mask")
    out["coverage_fraction"] = rep.get("coverage_fraction")
    out["family_anchors"] = {k: {"hex": v.get("hex"), "hue_deg": v.get("hue_deg"),
                                 "samples": v.get("samples"), "modal_hits": v.get("modal_hits")}
                             for k, v in (rep.get("family_anchors") or {}).items()}
    ft = ((rep.get("texel_classes") or {}).get("family_test") or {})
    out["family_test"] = {
        "anchor_hue_deg": ft.get("anchor_hue_deg"),
        "hue_separation_deg": ft.get("hue_separation_deg"),
        "hue_tol_deg_effective": (ft.get("effective") or {}).get("hue_tol_deg"),
        "sat_min_effective": (ft.get("effective") or {}).get("sat_min"),
        "hits": ft.get("hits"),
        "texels_matching_both_anchors": ft.get("texels_matching_both_anchors"),
        "hue_test_separates_the_two_families": ft.get("hue_test_separates_the_two_families"),
    }
    out["classes_by_region"] = ((rep.get("texel_classes") or {}).get("classes_by_region"))
    if out.get("mask"):
        path = os.path.join(REPO, out["mask"])
        if os.path.exists(path):
            with open(path, "rb") as fh:
                out["mask_sha256_prefix_live"] = hashlib.sha256(fh.read()).hexdigest()[:16]
        else:
            out["mask_sha256_prefix_live"] = None
    out["note"] = ("read-only. The mask lane owns this file; a regenerated mask changes the "
                   "sha256 prefix, which is why it is re-hashed here instead of trusted.")
    return out


def measure(out_dir: str, write_evidence: bool) -> dict:
    src = declared_source()
    hair_hex = src.get("_visual", {}).get("hair", "#241b19")
    skin_hex = src.get("_visual", {}).get("skin", "#c98258")

    # --- grid check ---------------------------------------------------------
    grid = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes), ("outfit", opath.format(outfit="circuit"), oframes)):
            full = os.path.join(REPO, path)
            with Image.open(full) as im:
                size = im.size
            fw = size[0] / count
            gaps = frame_gaps(full)
            # distance from each even-division boundary to the nearest alpha gap
            devs = []
            for i in range(count - 1):
                b = (i + 1) * fw
                d = min(min(abs(b - a), abs(b - bb)) if not (a <= b <= bb) else 0.0
                        for a, bb in gaps)
                devs.append(round(d, 1))
            grid.append({"sheet": name, "which": label, "path": path, "size": list(size),
                         "frames": count, "frame_w": round(fw, 2),
                         "boundary_deviation_px": devs,
                         "boundary_on_gap": bool(max(devs) == 0.0)})

    # --- base palette and per-outfit pixels ---------------------------------
    pools = {}        # (outfit, region) -> list of arrays, pooled over the usable sheets
    per_sheet = {}    # (sheet, outfit, region) -> array, kept as evidence
    bleed = []        # what own_span() dropped, per sheet/frame
    for name, bpath, bframes, opath, oframes in SHEETS:
        base_frames = load_frames(os.path.join(REPO, bpath), bframes)
        variants = {"base": base_frames}
        for o in OUTFITS:
            variants[o] = load_frames(os.path.join(REPO, opath.format(outfit=o)), oframes)

        for o in ["base"] + OUTFITS:
            for fi, frame in enumerate(variants[o]):
                rgba = np.asarray(frame).astype(np.int16)
                alpha = rgba[:, :, 3]
                c0, c1, dropped = own_span(alpha)
                bleed.append({"sheet": name, "outfit": o, "frame": fi,
                              "own_span": [int(c0), int(c1)], "dropped_px": int(dropped)})
                excl = exclusion_masks(rgba, hair_hex)
                bands = per_frame_bands(alpha[:, c0:c1])
                if bands is None:
                    continue
                for region, (b0, b1, _bb) in bands.items():
                    sel = collect((b0, b1), excl, alpha)[:, c0:c1]
                    px = rgba[:, c0:c1, :3][sel].astype(np.float64)
                    if len(px) == 0:
                        continue
                    per_sheet.setdefault((name, o, region), []).append(px)
                    if name not in BAND_SHEET_EXCLUDE.get(region, ()):
                        pools.setdefault((o, region), []).append(px)

    # --- per (outfit, region) clusters -------------------------------------
    palette = {}
    for (o, region), chunks in sorted(pools.items()):
        px = np.concatenate(chunks, axis=0)
        clusters = kmeans2(px)
        entry = {"pixels": int(len(px)), "modes": modal_colours(px), "clusters": []}
        for k, cl in enumerate(clusters):
            rgb = cl["rgb"]
            m_rgb = cl.get("mode_rgb", rgb)
            hue, sat, val = hsv_of(m_rgb.reshape(1, 3))
            entry["clusters"].append({
                "family": "ab"[k] if len(clusters) == 2 else "a",
                "mode_hex": hex_of(m_rgb),
                "mode_srgb": [int(round(v)) for v in m_rgb],
                "mode_count": int(cl.get("mode_count", cl["count"])),
                "mean_hex": hex_of(rgb),
                "srgb": [int(round(v)) for v in rgb],
                "count": cl["count"],
                "share_pct": round(float(100.0 * cl["count"] / len(px)), 1),
                "hue_deg": round(float(hue[0]), 1),
                "sat": round(float(sat[0]), 3),
                "val": round(float(val[0]), 3),
                "spread_255": round(cl.get("spread_255", 0.0), 1),
            })
        palette.setdefault(o, {})[region] = entry

    # --- the same measurement per sheet, as cross-check evidence ------------
    per_sheet_palette = {}
    for (sheet, o, region), chunks in sorted(per_sheet.items()):
        px = np.concatenate(chunks, axis=0)
        per_sheet_palette.setdefault(sheet, {}).setdefault(o, {})[region] = {
            "pixels": int(len(px)),
            "modes": modal_colours(px, top=3),
        }

    # --- changed-pixel comparison against the base -------------------------
    changes = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        base_frames = load_frames(os.path.join(REPO, bpath), bframes)
        for o in OUTFITS:
            oframes_ = load_frames(os.path.join(REPO, opath.format(outfit=o)), oframes)
            for fi in range(min(len(base_frames), len(oframes_))):
                on = oframes_[fi]
                w, h = on.size
                bn = base_frames[fi].resize((w, h), Image.LANCZOS)
                aa = np.asarray(bn).astype(np.int16)
                bb_ = np.asarray(on).astype(np.int16)
                alpha = (aa[:, :, 3] > ALPHA_MIN) & (bb_[:, :, 3] > ALPHA_MIN)
                d = np.abs(aa[:, :, :3] - bb_[:, :, :3]).max(axis=2)
                ch = alpha & (d > CHANGE_EPS)
                row = {"sheet": name, "outfit": o, "frame": fi,
                       "body_px": int(alpha.sum()), "changed_px": int(ch.sum()),
                       "changed_pct_of_body": round(100.0 * ch.sum() / max(1, alpha.sum()), 2),
                       "changed_pct_of_frame": round(100.0 * ch.sum() / (w * h), 2)}
                # per-region change, so the doc can say which region actually moves
                bands = per_frame_bands(np.asarray(on)[:, :, 3])
                if bands:
                    for region, (b0, b1, _bb) in bands.items():
                        rows = np.arange(h)[:, None]
                        bs = alpha & (rows >= b0) & (rows < b1)
                        row["changed_pct_" + region] = round(
                            100.0 * (ch & bs).sum() / max(1, bs.sum()), 2)
                # same-resolution pairs: no resampling, so this one is exact
                changes.append(row)

    # circuit vs signature, exact (same resolution, no resampling)
    close = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        ci = load_frames(os.path.join(REPO, opath.format(outfit="circuit")), oframes)
        si = load_frames(os.path.join(REPO, opath.format(outfit="signature")), oframes)
        for fi in range(min(len(ci), len(si))):
            aa = np.asarray(ci[fi]).astype(np.int16)
            bb_ = np.asarray(si[fi]).astype(np.int16)
            w, h = ci[fi].size
            alpha = (aa[:, :, 3] > ALPHA_MIN) & (bb_[:, :, 3] > ALPHA_MIN)
            d = np.abs(aa[:, :, :3] - bb_[:, :, :3]).max(axis=2)
            ch = alpha & (d > CHANGE_EPS)
            row = {"sheet": name, "frame": fi,
                   "body_px": int(alpha.sum()), "changed_px": int(ch.sum()),
                   "changed_pct_of_body": round(100.0 * ch.sum() / max(1, alpha.sum()), 2),
                   "changed_pct_of_frame": round(100.0 * ch.sum() / (w * h), 2)}
            bands = per_frame_bands(aa[:, :, 3])
            if bands:
                for region, (b0, b1, _bb) in bands.items():
                    rows = np.arange(h)[:, None]
                    bs = alpha & (rows >= b0) & (rows < b1)
                    row["changed_pct_" + region] = round(
                        100.0 * (ch & bs).sum() / max(1, bs.sum()), 2)
            close.append(row)

    # --- palette distances -------------------------------------------------
    def fam(o, region, fam="a"):
        e = palette.get(o, {}).get(region)
        if not e or not e["clusters"]:
            return None
        for c in e["clusters"]:
            if c["family"] == fam:
                return c
        return e["clusters"][0]

    def hsv1(hexv):
        h, s, v = hsv_of(np.array(rgb_of(hexv), dtype=float).reshape(1, 3))
        return float(h[0]), float(s[0]), float(v[0])

    distances = {}
    for o in OUTFITS:
        for region in list(BANDS):
            for f in ("a", "b"):
                cb, co = fam("base", region, f), fam(o, region, f)
                if not cb or not co:
                    continue
                hbx, sb, vb = hsv1(cb["mode_hex"])
                hox, so, vo = hsv1(co["mode_hex"])
                distances.setdefault(o, {})["%s_%s" % (region, f)] = {
                    "base_mode": cb["mode_hex"], "outfit_mode": co["mode_hex"],
                    "de76": round(de76(rgb_of(cb["mode_hex"]), rgb_of(co["mode_hex"])), 1),
                    "dhue_deg": None if min(sb, so) < HUE_NEEDS_SAT else round(abs(hbx - hox), 1),
                    "sats": [round(sb, 3), round(so, 3)],
                    "dval": round(abs(vb - vo), 3),
                }

    cs = {}
    for region in list(BANDS):
        for f in ("a", "b"):
            cc, ss = fam("circuit", region, f), fam("signature", region, f)
            if not cc or not ss:
                continue
            hcx, sc, vc = hsv1(cc["mode_hex"])
            hsx, ssat, vs = hsv1(ss["mode_hex"])
            cs["%s_%s" % (region, f)] = {
                "circuit_mode": cc["mode_hex"], "signature_mode": ss["mode_hex"],
                "circuit_share_pct": cc["share_pct"], "signature_share_pct": ss["share_pct"],
                "de76": round(de76(rgb_of(cc["mode_hex"]), rgb_of(ss["mode_hex"])), 1),
                "dhue_deg": None if min(sc, ssat) < HUE_NEEDS_SAT else round(abs(hcx - hsx), 1),
                "sats": [round(sc, 3), round(ssat, 3)],
                "dval": round(abs(vc - vs), 3),
            }

    # --- the six slots, with provenance attached to every one of them -------
    #
    # POLICY (stated once, applied mechanically; thresholds are the declared constants
    # D_MATCH_DE / D_MATCH_HUE / TRIM_SAT_MAX at the top of this file):
    #
    #   1. torso_a is THE IDENTITY SLOT: the torso is the region the reference's two
    #      colours were authored for. If the measured mode sits in the same hue family as
    #      a declared colour (dHue <= D_MATCH_HUE, both saturated) or within D_MATCH_DE,
    #      the DECLARED hex takes the slot and is labelled `source`. The sprite's mode is
    #      that colour with the 2D artwork's own shading baked in, and the 3D shader
    #      applies its own shading on top, so authoring the shaded value would double it.
    #   2. a `b` family the sprite paints as a near-white (sat < TRIM_SAT_MAX) takes the
    #      outfit's declared second colour, labelled `source`: that white is the base
    #      garment's own white, identical in base, circuit and signature, so it carries no
    #      outfit information -- the reference's second colour is the outfit's trim datum.
    #   3. EVERY OTHER SLOT takes the measured mode of its own region and is labelled
    #      `sprite`. This is deliberate: the reference declares only TWO colours per
    #      outfit, while the sprite paints a different colour in each region, and the six
    #      slots exist precisely to express that per-region difference. Folding the whole
    #      outfit onto the two declared colours would make circuit and signature a uniform
    #      blue and a uniform cyan, which is the conflict this document is about.
    #   4. explicit PORT_OVERRIDES win over all of the above and are labelled `port`.
    slots = {}
    for o in OUTFITS:
        decl = src.get(o, [])
        for region in list(BANDS):
            for f in ("a", "b"):
                c = fam(o, region, f)
                if not c:
                    continue
                measured = c["mode_hex"]
                mk = c["share_pct"]
                origin, hexv, reason = "sprite", measured, "measured modal colour of the region"
                if decl:
                    hm, sm, vm = hsv1(measured)
                    best = min(decl, key=lambda d: de76(rgb_of(d), rgb_of(measured)))
                    de_best = de76(rgb_of(best), rgb_of(measured))
                    hbest, sbest, vbest = hsv1(best)
                    dhue = min(abs(hm - hbest), 360 - abs(hm - hbest))
                    if region == "torso" and f == "a":
                        # THE IDENTITY SLOT. The torso's dominant family is where an outfit
                        # declares itself, and it is the region the reference's colours were
                        # authored for. If the sprite's mode sits in the same hue family as a
                        # declared colour, the DECLARED value takes the slot: the sprite's
                        # mode is that colour with the 2D artwork's own shading baked in
                        # (same hue, value only), and the 3D shader applies its own shading.
                        if min(sm, sbest) > HUE_NEEDS_SAT and dhue <= D_MATCH_HUE:
                            origin, hexv = "source", best
                            reason = ("torso_a carries the outfit's identity; the measured %s "
                                      "is the declared %s in the same hue family (dHue %.1f deg "
                                      "<= %.0f deg), only the 2D shading differs (val %.2f vs "
                                      "%.2f), so the authored value takes the slot"
                                      % (measured, best, dhue, D_MATCH_HUE, vm, vbest))
                        elif de_best <= D_MATCH_DE:
                            origin, hexv = "source", best
                            reason = ("torso_a carries the outfit's identity; measured %s is "
                                      "the declared %s (dE76 %.1f <= %.0f)"
                                      % (measured, best, de_best, D_MATCH_DE))
                    elif (sm < TRIM_SAT_MAX and f == "b" and len(decl) > 1
                          and hsv1(decl[1])[1] > TRIM_SAT_MAX):
                        # Only when the declared second colour is ITSELF a colour: swapping the
                        # base's white for a declared near-white (circuit's #9ef8ff has sat
                        # 0.06) would move the slot for no gain and, measured, would pull
                        # circuit's shoe trim from white to pale cyan -- closer to
                        # signature's cyan accent (foot_b dE76 50.3 -> 31.3). So a white
                        # declared trim leaves the sprite's white in place.
                        origin, hexv = "source", decl[1]
                        reason = ("sprite paints this trim as the base's white (%s, sat %.3f); "
                                  "that white is identical in base/circuit/signature, so it "
                                  "carries no outfit information, and the declared second colour "
                                  "%s is itself a colour (sat %.3f), so it takes the slot"
                                  % (measured, sm, decl[1], hsv1(decl[1])[1]))
                    else:
                        reason = ("measured modal colour of the region (%s, %.1f%% of the "
                                  "region's garment pixels); the reference declares no colour "
                                  "for this region/family" % (measured, mk))
                key = "%s_%s" % (region, f)
                rec = {"hex": hexv, "origin": origin, "measured_mode": measured,
                       "measured_share_pct": mk, "reason": reason}
                ov = PORT_OVERRIDES.get((o, key))
                if ov:
                    rec = {"hex": ov["hex"], "origin": "port", "measured_mode": measured,
                           "measured_share_pct": mk,
                           "reason": ov["why"], "would_have_been": hexv}
                slots.setdefault(o, {})[key] = rec

    # --- separation lever: dE76 between circuit and signature slot by slot ---
    separation = {}
    for key in ("torso_a", "torso_b", "hip_a", "hip_b", "foot_a", "foot_b"):
        c1 = slots.get("circuit", {}).get(key)
        c2 = slots.get("signature", {}).get(key)
        if not c1 or not c2:
            continue
        separation[key] = {
            "circuit": c1["hex"], "signature": c2["hex"],
            "de76_measured_modes": round(de76(rgb_of(c1["measured_mode"]),
                                               rgb_of(c2["measured_mode"])), 1),
            "de76_proposed_slots": round(de76(rgb_of(c1["hex"]), rgb_of(c2["hex"])), 1),
        }

    # mass-weighted separation: a proxy for what a player sees at match distance. Each
    # (region, family) pair is weighted by the share of the outfit's measured garment
    # pixels it covers, averaged over the two outfits. It is a PROXY: it counts pixels,
    # not visual importance, and the torso band is dominant by pixel count.
    weights = {}
    tot_px = 0.0
    for region in list(BANDS):
        n1 = palette["circuit"][region]["pixels"]
        n2 = palette["signature"][region]["pixels"]
        for f in ("a", "b"):
            r1 = fam_by_name(palette, "circuit", region, f)
            r2 = fam_by_name(palette, "signature", region, f)
            if not r1 or not r2:
                continue
            w = 0.5 * (n1 * r1["share_pct"] / 100.0 + n2 * r2["share_pct"] / 100.0)
            weights["%s_%s" % (region, f)] = w
            tot_px += w
    weighted = {}
    for k, w in weights.items():
        if not k or not separation.get(k):
            continue
        weighted[k] = {"weight_pct": round(100.0 * w / max(tot_px, 1e-9), 1),
                       "de76_measured": separation[k]["de76_measured_modes"],
                       "de76_proposed": separation[k]["de76_proposed_slots"]}
    sep_summary = {
        "per_slot": separation,
        "mass_weighted": weighted,
        "mass_weighted_de76_measured": round(sum(v["weight_pct"] * v["de76_measured"] / 100.0
                                                 for v in weighted.values()), 1),
        "mass_weighted_de76_proposed": round(sum(v["weight_pct"] * v["de76_proposed"] / 100.0
                                                 for v in weighted.values()), 1),
        "weight_note": "weights are measured pixel shares of each region x family, averaged "
                       "over circuit and signature; a proxy for match-distance legibility, "
                       "not a perceptual model",
    }

    report = {
        "_tool": "tools/character/measure_maestro_palette.py",
        "method": {
            "alpha_min": ALPHA_MIN,
            "bands_of_body_bbox_height": BANDS,
            "extra_bands_not_rig_regions": EXTRA_BANDS,
            "change_eps_255": CHANGE_EPS,
            "family_convention": "a = larger cluster (dominant garment mass), b = trim",
            "heuristics": {
                "skin": "hue 9-38 deg and sat > 0.30 (declared port heuristic); declared "
                        "Maestro skin %s" % skin_hex,
                "hair": "max-channel distance <= %d/255 from declared hair %s" % (HAIR_TOL, hair_hex),
                "racket": "largest 8-connected gold blob (hue 40-62, sat>0.6, val>200/255), "
                          "closed %dpx then dilated %dpx" % (RACKET_CLOSE, RACKET_GROW),
            },
        },
        "source_colours_declared": src,
        "baked_atlas_inventory": atlas_families(),
        "mask_lane_cross_check": mask_report_cross_check(),
        "card_check": card_check(),
        "frame_grid_check": grid,
        "sheet_bleed": {"per_frame": bleed,
                        "total_dropped_px": int(sum(b["dropped_px"] for b in bleed)),
                        "note": "columns belonging to a neighbouring figure's ink on the "
                                "four-frame sheets; excluded from the colour measurement"},
        "bands_sheet_policy": {k: list(v) for k, v in BAND_SHEET_EXCLUDE.items()},
        "measured_palette": palette,
        "measured_palette_per_sheet": per_sheet_palette,
        "slot_proposal": slots,
        "separation_proposal": sep_summary,
        "distance_from_base": distances,
        "circuit_vs_signature": {"colour_distance": cs, "pixel_changes": close},
        "pixel_changes_vs_base": changes,
    }

    os.makedirs(out_dir, exist_ok=True)
    dump = os.path.join(out_dir, "maestro-palette-report.json")
    with open(dump, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")

    if write_evidence:
        write_evidence_images(out_dir, report)

    print("WROTE %s" % os.path.relpath(dump, REPO))
    cc = report["card_check"]
    if "error" not in cc:
        print("CARD base=%s %s: %s" % (cc["base_card"], cc["base_card_size"], "  ".join(
            "%s=%.1f%% over 16/255 (mean %.1f/255)" % (o, v["pct_pixels_over_16_255"], v["mean_abs_255"])
            for o, v in cc["per_outfit"].items())))
    mc = report["mask_lane_cross_check"]
    if mc.get("present"):
        print("MASKLANE %s sha256_prefix=%s anchors=%s family_test_separates=%s "
              "(hue_sep=%.1f deg under tol %.1f deg, both_anchor_texels=%s)"
              % (mc["report"], mc.get("mask_sha256_prefix_live"),
                 ",".join("%s:%s" % (k, v["hex"]) for k, v in sorted(mc["family_anchors"].items())),
                 mc["family_test"]["hue_test_separates_the_two_families"],
                 mc["family_test"]["hue_separation_deg"], mc["family_test"]["hue_tol_deg_effective"],
                 mc["family_test"]["texels_matching_both_anchors"]))
    else:
        print("MASKLANE %s" % mc["note"])
    at = report["baked_atlas_inventory"]
    if "error" not in at:
        print("ATLAS %s: %s" % (at["path"], "  ".join(
            "%s=%.1f%%(%s)" % (k, v["share_pct"], v["median_hex"])
            for k, v in at["classes"].items())))
    for o in ["base"] + OUTFITS:
        bits = []
        for region in list(BANDS):
            for f in ("a", "b"):
                c = fam(o, region, f)
                if c:
                    bits.append("%s_%s=%s(mode)/%s(mean) %s%%" % (region, f, c["mode_hex"],
                                                                 c["mean_hex"], c["share_pct"]))
        print("%-10s %s" % (o, "  ".join(bits)))
    print("slots proposed (origin/source per slot):")
    for o in OUTFITS:
        for key in ("torso_a", "torso_b", "hip_a", "hip_b", "foot_a", "foot_b"):
            rec = report["slot_proposal"][o][key]
            print("  %-10s %-8s %s  [%s]  measured=%s  %s"
                  % (o, key, rec["hex"], rec["origin"], rec["measured_mode"], rec["reason"]))
    sp = report["separation_proposal"]
    print("separation circuit vs signature (dE76, measured modes -> proposed slots):")
    for k, v in sp["per_slot"].items():
        print("  %-8s %s vs %s   measured=%.1f -> proposed=%.1f"
              % (k, v["circuit"], v["signature"], v["de76_measured_modes"], v["de76_proposed_slots"]))
    print("  mass-weighted (pixel-share proxy): measured=%.1f -> proposed=%.1f"
          % (sp["mass_weighted_de76_measured"], sp["mass_weighted_de76_proposed"]))
    for k, v in sp["mass_weighted"].items():
        print("    %-8s weight=%4.1f%%  %.1f -> %.1f"
              % (k, v["weight_pct"], v["de76_measured"], v["de76_proposed"]))
    print("circuit vs signature, mode dE76 per slot:")
    for slot, v in sorted(report["circuit_vs_signature"]["colour_distance"].items()):
        dh = "n/a (low sat)" if v["dhue_deg"] is None else "%.1f deg" % v["dhue_deg"]
        print("  %-10s %s vs %s  dE=%.1f  dHue=%s  dVal=%.3f"
              % (slot, v["circuit_mode"], v["signature_mode"], v["de76"], dh, v["dval"]))
    return report


# ---------------------------------------------------------------------------
# evidence images
# ---------------------------------------------------------------------------
def write_evidence_images(out_dir: str, report: dict) -> None:
    """Band boundaries + exclusion masks, one sheet type at a time, on the base sprite.

    The images are the check on the heuristics: if the skin/hair/racket masks leaked
    into the shirt, it is visible here as a hole in the fabric.
    """
    hair_hex = report["source_colours_declared"].get("_visual", {}).get("hair", "#241b19")
    for name, bpath, bframes, _o, _of in SHEETS:
        frames = load_frames(os.path.join(REPO, bpath), bframes)
        panels = []
        for fi, frame in enumerate(frames):
            rgba = np.asarray(frame).astype(np.int16)
            alpha = rgba[:, :, 3]
            excl = exclusion_masks(rgba, hair_hex)
            bands = per_frame_bands(alpha)
            vis = rgba[:, :, :3].astype(np.uint8).copy()
            for key, m in excl.items():
                tint = {"skin": (255, 0, 0), "hair": (255, 160, 0), "racket": (255, 0, 255)}[key]
                vis[m] = (vis[m] * 0.35 + np.array(tint) * 0.65).astype(np.uint8)
            img = Image.fromarray(vis)
            d = ImageDraw.Draw(img)
            if bands:
                for region in BANDS:
                    b0, b1, _ = bands[region]
                    for y in (b0, b1):
                        d.line([(0, y), (img.size[0], y)], fill=(80, 255, 80), width=1)
                    d.text((2, min(img.size[1] - 10, b0 + 2)), region, fill=(120, 255, 120))
            sc = 2
            panels.append(img.resize((img.size[0] * sc, img.size[1] * sc), Image.NEAREST))
        if not panels:
            continue
        h = max(p.size[1] for p in panels)
        w = sum(p.size[0] + 8 for p in panels)
        sheet = Image.new("RGB", (w, h), (16, 17, 20))
        x = 0
        for p in panels:
            sheet.paste(p, (x, 0))
            x += p.size[0] + 8
        path = os.path.join(out_dir, "mask-check-%s.png" % name)
        sheet.save(path)
        print("WROTE %s" % os.path.relpath(path, REPO))

    # Two swatch strips: the MEASURED modal colour per region family, and the PROPOSED
    # slot value with its provenance letter (S source / M measured sprite / P port).
    cols = [("torso_a", "torso", "a"), ("torso_b", "torso", "b"),
            ("hip_a", "hip", "a"), ("hip_b", "hip", "b"),
            ("foot_a", "foot", "a"), ("foot_b", "foot", "b")]
    rowh, cw = 52, 140
    for which in ("measured", "proposed"):
        rows = ["base"] + OUTFITS
        img = Image.new("RGB", (130 + cw * len(cols), rowh * (len(rows) + 1)), (16, 17, 20))
        d = ImageDraw.Draw(img)
        d.text((6, 6), which.upper() + " slots", fill=(235, 235, 235))
        for j, (label, _r, _f) in enumerate(cols):
            d.text((130 + j * cw + 4, 6), label, fill=(220, 220, 220))
        for i, o in enumerate(rows):
            y = rowh * (i + 1)
            d.text((6, y + 20), o, fill=(220, 220, 220))
            for j, (label, region, f) in enumerate(cols):
                x = 130 + j * cw
                if which == "measured":
                    e = (report["measured_palette"].get(o) or {}).get(region) or {}
                    rgb, note = None, ""
                    for c in e.get("clusters", []):
                        if c["family"] == f:
                            rgb, note = rgb_of(c["mode_hex"]), "M %s%%" % c["share_pct"]
                    if rgb is None and e.get("clusters"):
                        rgb, note = rgb_of(e["clusters"][0]["mode_hex"]), "only family"
                else:
                    rec = (report["slot_proposal"].get(o) or {}).get(label)
                    rgb = rgb_of(rec["hex"]) if rec else None
                    note = ((rec["hex"] + "  " + {"source": "S", "sprite": "M", "port": "P"}
                             .get(rec["origin"], "?")) if rec else "")
                if rgb:
                    d.rectangle([x, y + 10, x + cw - 12, y + 44], fill=rgb)
                    d.text((x + 4, y + 44), note, fill=(200, 200, 200))
        path = os.path.join(out_dir, "%s-slots.png" % which)
        img.save(path)
        print("WROTE %s" % os.path.relpath(path, REPO))


def main() -> int:
    global CHANGE_EPS
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=DEFAULT_OUT)
    ap.add_argument("--no-evidence", action="store_true")
    ap.add_argument("--change-eps", type=int, default=CHANGE_EPS,
                    help="per-channel /255 delta above which a pixel counts as changed "
                         "against the base (default %d). The document quotes a sweep over "
                         "this value, because the pre-measured percentages it was asked to "
                         "verify do not reproduce at any single setting." % CHANGE_EPS)
    args = ap.parse_args()
    CHANGE_EPS = args.change_eps
    measure(os.path.abspath(args.out_dir), not args.no_evidence)
    return 0


if __name__ == "__main__":
    sys.exit(main())
