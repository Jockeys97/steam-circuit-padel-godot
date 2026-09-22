#!/usr/bin/env python3
"""Measure the Oracolo's `signature` outfit off the in-field 2D sprites, AND measure how
much of that outfit the 3D model can reach by recolouring alone.

WHY THIS TOOL EXISTS

The 3D rig recolours a baked model inside a UV mask that splits the body into three
regions -- torso, hip (shorts/skirt), foot (shoes) -- and every region carries two colour
families, `a` and `b`. An outfit is therefore six colours:
torso_a, torso_b, hip_a, hip_b, foot_a, foot_b (see
`godot/src/character/outfit_catalogue.gd::OUTFIT_PROFILES`, entry `fiamma`).

The browser reference (`js/data.js::ATHLETE_OUTFITS.oracolo`) declares only TWO colours per
outfit and the Oracolo has only two variants (base, signature). This tool measures what the
in-field 2D sprites actually paint, region by region, so the six slots can be filled from
evidence instead of guesswork -- and it measures the 3D model itself, because the project
audit classifies Oracolo Signature as "T+G locale": texture PLUS a silhouette change
(cropped top, bare shoulders) that the current dress/armour may not have. That claim is
either a number or it is an opinion; this tool makes it a number.

WHAT IT MEASURES

  SPRITES (the palette)
  * frame grid       every sheet is a horizontal strip; frame counts come from the asset
                     contract (`js/data.js` runFrames, `js/render.js` frameCount) and are
                     verified against the alpha gaps between figures.
  * body bbox        per frame, from alpha > ALPHA_MIN.
  * bands            fixed fractions of the body height, declared in BANDS and taken from
                     the measured row map of the base sprite (printed by --row-map), not
                     from eyeballing the artwork. The Oracolo's own map differs from the
                     Maestro's: its skirt ends at 0.56 and its boots start at 0.86.
  * exclusions       skin, hair and the racket. All three are heuristics and are declared
                     in SKIN_*, HAIR_* and racket_mask(); the hair rule is SPLIT in two
                     because on this athlete the declared near-black hair (#0e0c16) and the
                     outfit's dark violet trim are inside the Maestro's own tolerance.
  * families         per (outfit, region), deterministic k-means with k=2 over the
                     surviving pixels. `a` is the larger cluster (dominant garment mass),
                     `b` the smaller one (the trim). Same convention as fiamma/maestro.
  * separation       base vs signature, slot by slot, and the hue distance between the two
                     families the shader's family test has to tell apart.

  MODEL (the geometry, read-only)
  * atlas inventory  the colour families of the BAKED texture the rig actually renders.
  * surface classes  every triangle of the GLB is classified by sampling that texture at
                     its own UVs, weighted by triangle area, so "how much of the surface is
                     bare skin" is an area, not a guess. Shoulders, midriff, thigh, boot and
                     foot zones are reported separately.

HEURISTICS, STATED AS SUCH

  skin      hue in [9, 38] deg with saturation > 0.30 and value > 0.20. The narrow hue
            window the port already uses for protected skin; the Oracolo's declared skin
            (#8a5a3b) sits at hue 22.6 deg / sat 0.57, inside it.
  hair      within HAIR_TOL /255 (max channel distance) of the declared hair colour
            (#0e0c16, `js/data.js` visual.hair). DECLARED DEFECT: the Oracolo's own dark
            violet trim (#1a0f38, visual.secondary) is only 34/255 from that hair colour, so
            the Maestro's rule would delete garment pixels as hair. Two rules are therefore
            measured side by side (strict, and sat-gated) and the report carries both, so
            the sensitivity is visible instead of hidden.
  racket    the Maestro's rule (largest 8-connected gold blob, closed then dilated) is
            MEASURED TO FAIL on this athlete: the Oracolo's racket has a dark string bed,
            so the gold family is only its rim/emblem (129 px, 0.9% of the torso band after
            closing and dilation). The front sheets' torso band is instead excluded from the
            palette pool by sheet, and the reason is a number in `sheet_band_composition`.

  None of these rules is a mask authored by hand, and none of them is exact.

INTERPRETER

numpy + PIL only, no network, no paid API, no asset writes. On this host:
  python3 -m venv <venv> && <venv>/bin/pip install pillow numpy

USAGE

  <venv>/bin/python tools/character/measure_oracolo_palette.py
  <venv>/bin/python tools/character/measure_oracolo_palette.py --row-map
  <venv>/bin/python tools/character/measure_oracolo_palette.py --no-evidence --out-dir <dir>
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import struct
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_OUT = os.path.join(REPO, "docs", "agent-work", "outfits-3d", "evidence", "oracolo-palette")

ALPHA_MIN = 200          # /255, body pixels; below this is antialiased edge or empty
CHANGE_EPS = 16          # /255, per-channel delta above which a pixel counts as changed
HAIR_TOL = 48            # /255, max-channel distance to the declared hair colour
HAIR_SAT_MAX = 0.35      # sat below which a dark pixel counts as hair even inside HAIR_TOL
RACKET_GROW = 11         # px, square dilation of the Maestro's racket blob
RACKET_CLOSE = 9         # px, square closing of the Maestro's racket blob
SKIN_HUE = (9.0, 38.0)   # deg, declared port heuristic
SKIN_SAT_MIN = 0.30
SKIN_VAL_MIN = 0.20
HUE_NEEDS_SAT = 0.15     # below this saturation a hue difference is meaningless (whites)
D_MATCH_DE = 20.0        # dE76 within which a measured mode counts as the declared colour
D_MATCH_HUE = 12.0       # deg, hue window in which a shaded mode counts as the declared colour
TRIM_SAT_MAX = 0.20      # measured saturation below which a slot is the base's own white trim
VIOLET_HUE = (235.0, 305.0)
VIOLET_SAT_MIN = 0.35
VIOLET_VAL_MIN = 0.10

# PORT_OVERRIDES: slots where the port deliberately leaves what BOTH the sprite and the
# reference say. Every entry is labelled `port` in the output and carries its own reason;
# nothing else in the table is invented. See the report's `separation_proposal` for the
# measurement that justifies the single entry below.
PORT_OVERRIDES: dict = {}

# --- bands ------------------------------------------------------------------
# Fractions of the body bbox height (bbox = alpha > ALPHA_MIN, per frame, per sheet).
# Chosen from the base sprite's own row map (`--row-map`, and `mask-check-*.png`): the head
# runs 0.00-0.16, the garment 0.16-0.47, the skirt 0.47-0.56, bare thighs 0.56-0.78, the
# pale boot-top 0.78-0.86 and the boots 0.86-1.00. The three bands below map onto the rig's
# torso / hip / foot bone groups as the mask tool does: hip = hips + upright legs (the
# skirt), foot = feet + toes (the boots).
BANDS = {
    "torso": (0.16, 0.47),
    "hip": (0.47, 0.56),
    "foot": (0.86, 1.00),
}
EXTRA_BANDS = {"boot_top": (0.78, 0.86)}   # evidence only, not a rig region

# Which sheets feed which region. MEASURED REASONS, not taste:
#   torso  the Oracolo holds the racket in front of the chest in the front idle/action
#          sheets, and its racket has a dark string bed, so the Maestro's gold-blob rule
#          finds only the rim/emblem (129 px) and cannot mask it. Measured band
#          composition (`sheet_band_composition`): on the front sheets the torso band is
#          16-30% near-black and only 13-22% violet, while on the back sheets it is
#          42-57% violet and 0% near-black. The back sheets are therefore the torso source
#          and the front numbers stay in the report as evidence.
#   run    the run sheets are a DIFFERENT artwork: their garment hue is 293-306 deg against
#          275 (base) / 262 (signature) on every other sheet, with a cream #ebd4b9 and a
#          bright green #18ff09 that no other sheet carries. They are excluded from the
#          palette pool for every region and reported per sheet as evidence.
BAND_SHEET_EXCLUDE = {
    "torso": ("idle", "action", "run", "back-run"),
    "hip": ("run", "back-run"),
    "foot": ("run", "back-run"),
}

DATA_JS = os.path.join(REPO, "js", "data.js")

# Sheet contract: (sheet name, base sheet path, base frames, outfit path template, frames)
# The outfit paths follow `outfitSpritePaths` in js/data.js, INCLUDING its Oracolo special
# case: idle-v2.webp / back-idle-v2.webp, because the first idle belonged to a different
# luminous concept and read as semi-transparent on screen.
SHEETS = [
    ("idle", "assets/sprites/oracolo-idle-consistent-v2.webp", 4,
     "assets/outfits/oracolo/{outfit}/idle-v2.webp", 4),
    ("action", "assets/sprites/oracolo-action-unique.webp", 4,
     "assets/outfits/oracolo/{outfit}/action.webp", 4),
    ("run", "assets/sprites/oracolo-run-unique.webp", 8,
     "assets/outfits/oracolo/{outfit}/run.webp", 8),
    ("back-idle", "assets/sprites/back/oracolo-idle-consistent-v2.webp", 4,
     "assets/outfits/oracolo/{outfit}/back-idle-v2.webp", 4),
    ("back-action", "assets/sprites/back/oracolo-action-unique.webp", 4,
     "assets/outfits/oracolo/{outfit}/back-action.webp", 4),
    ("back-run", "assets/sprites/back/oracolo-run-unique.webp", 8,
     "assets/outfits/oracolo/{outfit}/back-run.webp", 8),
]
# The superseded first idle pair, measured only to show what v2 replaced.
OLD_IDLE = [("idle", "assets/outfits/oracolo/{outfit}/idle.webp", 4),
            ("back-idle", "assets/outfits/oracolo/{outfit}/back-idle.webp", 4)]

OUTFITS = ["signature"]

ATLAS_PATH = os.path.join(REPO, "godot", "assets", "athletes", "oracolo_texture_0.png")
GLB_PATH = os.path.join(REPO, "godot", "assets", "athletes", "oracolo.glb")
CARD_BASE = os.path.join(REPO, "assets", "athletes", "oracolo.webp")
CARD_PREVIEW = os.path.join(REPO, "assets", "outfits", "oracolo", "{outfit}-preview.webp")
MASK_DIR = os.path.join(REPO, "godot", "assets", "athletes", "outfits", "oracolo")


# ---------------------------------------------------------------------------
# io helpers
# ---------------------------------------------------------------------------
def load_frames(path: str, count: int) -> list:
    """Split a horizontal sprite strip into `count` frames by even division.

    The division is checked against the alpha gaps (`frame_gaps`) before the numbers are
    trusted; a mismatch is reported, not silently averaged over.
    """
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
    fw = rgba.size[0] // count
    return [rgba.crop((i * fw, 0, (i + 1) * fw, rgba.size[1])) for i in range(count)]


def own_span(alpha: np.ndarray) -> tuple:
    """Column span that belongs to THIS frame's figure, plus the dropped pixels.

    The runtime slices sheets by even division (`js/render.js`: `naturalWidth / frameCount`),
    and on the four-frame sheets that boundary cuts a sliver of the NEXT figure into the
    frame. The sliver is left out of the colour measurement (it is not this figure) and
    counted, so the report says how much was dropped instead of hiding it.
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
    return c0, c1, int(cols.sum()) - sum(r[2] for r in kept)


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
    """Read the reference's own colours out of js/data.js.

    Machine-read rather than retyped, so the document cannot drift from the source. The
    Oracolo is the one athlete where `visual.kit/accent` and the `base` outfit's `colors`
    disagree; both are returned so the discrepancy can be measured against the sprite.
    """
    with open(DATA_JS, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"ATHLETE_OUTFITS\s*=\s*\{(.*?)\n\};", text, re.S)
    if not m:
        raise SystemExit("ATHLETE_OUTFITS not found in %s" % DATA_JS)
    block = re.search(r"\n  oracolo:\s*\[(.*?)\n  \],", m.group(1), re.S)
    if not block:
        raise SystemExit("oracolo entry not found in ATHLETE_OUTFITS")
    out: dict = {}
    for line in block.group(1).splitlines():
        oid = re.search(r'id:\s*"([a-z]+)"', line)
        cols = re.search(r'colors:\s*\["#([0-9a-fA-F]{6})",\s*"#([0-9a-fA-F]{6})"\]', line)
        if oid and cols:
            out[oid.group(1)] = ["#" + cols.group(1).lower(), "#" + cols.group(2).lower()]
    vis = re.search(r'id:\s*"oracolo"(.*?)\n  \},', text, re.S)
    out["_visual"] = {}
    if vis:
        for key in ("skin", "hair", "kit", "secondary", "accent", "shoes", "headband"):
            mm = re.search(r'%s:\s*"(#[0-9a-fA-F]{6})"' % key, vis.group(1))
            if mm:
                out["_visual"][key] = mm.group(1).lower()
    sp = re.search(r'const idleName = athleteId === "oracolo" \? "([^"]+)" : "([^"]+)"', text)
    out["_sprite_name_special_case"] = {"oracolo": sp.group(1), "others": sp.group(2)} if sp else None
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


def dhue(a_deg: float, b_deg: float) -> float:
    d = abs(a_deg - b_deg) % 360.0
    return min(d, 360.0 - d)


# ---------------------------------------------------------------------------
# masks
# ---------------------------------------------------------------------------
def largest_component(mask: np.ndarray) -> np.ndarray:
    """Largest 8-connected component of a bool mask (BFS; masks here are small)."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    best = np.zeros_like(mask)
    bestn = 0
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
            if len(px) > bestn:
                bestn = len(px)
                best = np.zeros_like(mask)
                for (y, x) in px:
                    best[y, x] = True
    return best


def racket_mask(rgba: np.ndarray) -> tuple:
    """The Maestro's racket rule, kept so its FAILURE on this athlete is a number.

    The rule assumes the racket's head FACE is gold (616 px on each Maestro outfit sprite).
    The Oracolo's racket has a dark string bed and a gold rim, so the gold family is only
    the rim/emblem. The measured blob size is reported and compared against the Maestro's.
    """
    hue, sat, val = hsv_of(rgba[:, :, :3].astype(np.float64))
    gold = (hue > 40) & (hue < 62) & (sat > 0.6) & (val > 200 / 255.0)
    if gold.sum() < 32:
        return np.zeros(gold.shape, dtype=bool), {"gold_px": int(gold.sum()), "blob_px": 0,
                                                 "mask_px": 0}
    blob = largest_component(gold)
    im = Image.fromarray((blob * 255).astype(np.uint8))
    im = im.filter(ImageFilter.MaxFilter(RACKET_CLOSE)).filter(ImageFilter.MinFilter(RACKET_CLOSE))
    im = im.filter(ImageFilter.MaxFilter(RACKET_GROW))
    m = np.asarray(im) > 127
    return m, {"gold_px": int(gold.sum()), "blob_px": int(blob.sum()), "mask_px": int(m.sum())}


def exclusion_masks(rgba: np.ndarray, hair_hex: str, hair_sat_gate: bool) -> dict:
    """skin / hair / racket masks for one frame. Heuristics, all declared at the top."""
    rgb = rgba[:, :, :3].astype(np.float64)
    hue, sat, val = hsv_of(rgb)
    skin = (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN) & (val > SKIN_VAL_MIN)
    hair = np.abs(rgb - np.array(rgb_of(hair_hex), dtype=np.float64)).max(axis=2) <= HAIR_TOL
    if hair_sat_gate:
        hair = hair & (sat <= HAIR_SAT_MAX)
    racket, _ = racket_mask(rgba)
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

    Reported next to the two families so nothing is hidden by the k=2 split: if a region
    carries a third colour (the pale boot-top, the gold trim), it shows up here with its
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
        hh, ss, vv = hsv_of(members.mean(axis=0).reshape(1, 3))
        out.append({"hex": hex_of(members.mean(axis=0)),
                    "count": int(cnt[i]),
                    "share_pct": round(float(100.0 * cnt[i] / len(px)), 2),
                    "hue_deg": round(float(hh[0]), 1),
                    "sat": round(float(ss[0]), 3),
                    "val": round(float(vv[0]), 3)})
    return out


def kmeans2(px: np.ndarray, iters: int = 100):
    """Deterministic k=2 k-means in RGB.

    Seeded from the data: the two most populated 16-level bins at least 96/255 apart, so
    the result is reproducible byte for byte and cannot land on two near-identical centres.

    Each cluster reports BOTH a mean and a mode. The mean is the average of the shaded
    pixels in the cluster (shadows included, so it reads lighter/greyer than the paint on
    the fabric); the mode is the single most populated bin of the cluster, i.e. the flat
    colour an artist would name. The document uses the mode as the slot value and keeps the
    mean for the audit trail.
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
# sprite measurement
# ---------------------------------------------------------------------------
def collect(band, excl: dict, alpha: np.ndarray):
    """Selection mask of one band: inside the band, opaque, not excluded."""
    h = alpha.shape[0]
    rows = np.arange(h)[:, None]
    y0, y1 = band
    sel = (rows >= y0) & (rows < y1) & (alpha > ALPHA_MIN)
    for m in excl.values():
        sel = sel & ~m
    return sel


def per_frame_bands(alpha: np.ndarray):
    bb = body_bbox(alpha)
    if bb is None:
        return None
    _, y0, _, y1 = bb
    h = y1 - y0 + 1
    out = {}
    for name, (f0, f1) in {**BANDS, **EXTRA_BANDS}.items():
        out[name] = (y0 + f0 * h, y0 + f1 * h, bb)
    return out


def sheet_band_composition(name: str, path: str, frames: int, hair_hex: str) -> list:
    """Per sheet/frame: how each band is composed, before any exclusion.

    This is the evidence behind BAND_SHEET_EXCLUDE: it is what shows the front torso band
    is mostly racket and hair while the back torso band is mostly garment.
    """
    rows = []
    imgs = load_frames(os.path.join(REPO, path), frames)
    for fi, frame in enumerate(imgs):
        rgba = np.asarray(frame).astype(np.int16)
        alpha = rgba[:, :, 3]
        c0, c1, _drop = own_span(alpha)
        rgb = rgba[:, c0:c1, :3].astype(np.float64)
        body = alpha[:, c0:c1] > ALPHA_MIN
        hue, sat, val = hsv_of(rgb)
        skin = (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN)
        violet = (hue >= VIOLET_HUE[0]) & (hue <= VIOLET_HUE[1]) & (sat > VIOLET_SAT_MIN) & (val > VIOLET_VAL_MIN)
        black = val <= 0.12
        gold = (hue > 35) & (hue < 75) & (sat > 0.45) & (val > 0.45)
        grey = (sat < 0.15) & (val > 0.12) & (val <= 0.35)
        bands = per_frame_bands(alpha[:, c0:c1])
        if bands is None:
            continue
        for region, (b0, b1, _bb) in bands.items():
            hh = alpha[:, c0:c1].shape[0]
            r = np.arange(hh)[:, None]
            m = body & (r >= b0) & (r < b1)
            nb = max(1, int(m.sum()))
            rows.append({"sheet": name, "frame": fi, "region": region, "px": int(m.sum()),
                         "skin_pct": round(100.0 * (skin & m).sum() / nb, 1),
                         "violet_pct": round(100.0 * (violet & m).sum() / nb, 1),
                         "near_black_pct": round(100.0 * (black & m).sum() / nb, 1),
                         "grey_pct": round(100.0 * (grey & m).sum() / nb, 1),
                         "gold_pct": round(100.0 * (gold & m).sum() / nb, 1)})
    return rows


def row_map() -> list:
    """Printed by --row-map: the base sprite's own row-by-row colour map.

    This is where BANDS comes from. Nothing in the band choice is eyeballed.
    """
    out = []
    for name, path, frames in (("idle", "assets/sprites/oracolo-idle-consistent-v2.webp", 4),
                               ("back-idle", "assets/sprites/back/oracolo-idle-consistent-v2.webp", 4),
                               ("run", "assets/sprites/oracolo-run-unique.webp", 8)):
        imgs = load_frames(os.path.join(REPO, path), frames)
        for fi in (0, 1 if frames == 4 else 4):
            rgba = np.asarray(imgs[fi]).astype(np.int16)
            alpha = rgba[:, :, 3]
            c0, c1, _drop = own_span(alpha)
            rgb = rgba[:, c0:c1, :3].astype(np.float64)
            body = alpha[:, c0:c1] > ALPHA_MIN
            bb = body_bbox(alpha[:, c0:c1])
            y0, y1 = bb[1], bb[3]
            h = y1 - y0 + 1
            for k in range(20):
                r0 = y0 + int(k * 0.05 * h)
                r1 = max(r0 + 1, y0 + int((k + 1) * 0.05 * h))
                r = np.arange(body.shape[0])[:, None]
                m = body & (r >= r0) & (r < r1)
                px = rgb[m]
                if len(px) < 20:
                    continue
                out.append({"sheet": name, "frame": fi, "frac": round(k * 0.05, 2),
                            "rows": [int(r0), int(r1)], "px": int(len(px)),
                            "modes": modal_colours(px, top=3)})
    return out


# ---------------------------------------------------------------------------
# atlas + model measurement
# ---------------------------------------------------------------------------
def hsv_atlas_classes(a: np.ndarray) -> np.ndarray:
    """Class map of an RGB image, same thresholds used for the model and the atlas."""
    hue, sat, val = hsv_of(a)
    cls = np.zeros(a.shape[:2], dtype=np.uint8)
    cls[(hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN)] = 1        # skin
    cls[(hue >= VIOLET_HUE[0]) & (hue <= VIOLET_HUE[1]) & (sat > VIOLET_SAT_MIN) & (val > VIOLET_VAL_MIN)] = 2
    cls[((hue >= 305) | (hue <= 8)) & (sat > VIOLET_SAT_MIN) & (val > VIOLET_VAL_MIN)] = 3   # magenta
    cls[(sat < 0.15) & (val > 0.10)] = 4                                               # grey/white
    cls[val <= 0.10] = 5                                                              # near-black
    return cls


CLASS_NAMES = {0: "other", 1: "skin", 2: "violet", 3: "magenta", 4: "grey_white", 5: "near_black"}


def atlas_inventory() -> dict:
    """Inventory of the BAKED atlas the rig actually renders, read-only.

    NOT the mask and NOT the anchors: the anchors must be measured *inside* the mask by the
    mask tool (`tools/character/build_maestro_outfit_mask.py` is the pattern). There is no
    such mask for the Oracolo yet, and the report says so. This inventory is here so the
    document can say honestly which recolourable colour families the model has at all, and
    how far apart their hues are -- which is what the shader's family test has to separate.
    There is deliberately no asset write.
    """
    if not os.path.exists(ATLAS_PATH):
        return {"error": "atlas not found: %s" % os.path.relpath(ATLAS_PATH, REPO)}
    with Image.open(ATLAS_PATH) as im:
        a = np.asarray(im.convert("RGB")).astype(np.float64)
    tot = a.shape[0] * a.shape[1]
    hue, sat, val = hsv_of(a)
    sat_m = (sat > 0.25) & (val > 0.10)
    out = {"path": os.path.relpath(ATLAS_PATH, REPO), "size": [int(a.shape[1]), int(a.shape[0])],
           "total_px": int(tot), "saturated_share_pct": round(float(100.0 * sat_m.sum() / tot), 1)}
    hist, edges = np.histogram(hue[sat_m], bins=36, range=(0, 360))
    share = 100.0 * hist / max(1, hist.sum())
    out["saturated_hue_bands_10deg_pct"] = {("%d-%d" % (edges[i], edges[i + 1])): round(float(share[i]), 2)
                                            for i in range(36) if share[i] > 0.40}
    out["cyan_170_215_pct_of_saturated"] = round(float(share[17:21].sum()), 2)
    out["gold_35_70_pct_of_saturated"] = round(float(share[3:7].sum()), 2)
    out["warm_skin_0_40_pct_of_saturated"] = round(float(share[0:4].sum()), 2)
    out["violet_240_300_pct_of_saturated"] = round(float(share[24:30].sum()), 2)
    # modes of the saturated texels, 8-level bins
    q = (a[sat_m] // 8).astype(np.int32)
    keys = q[:, 0] * 1000000 + q[:, 1] * 1000 + q[:, 2]
    u, cnt = np.unique(keys, return_counts=True)
    order = np.argsort(-cnt)[:8]
    out["saturated_modes"] = []
    for i in order:
        m = np.array([(u[i] // 1000000) * 8 + 4, ((u[i] // 1000) % 1000) * 8 + 4, (u[i] % 1000) * 8 + 4],
                     dtype=float)
        hh, ss, vv = hsv_of(m.reshape(1, 3))
        out["saturated_modes"].append({"hex": hex_of(m), "share_pct_of_saturated": round(float(100.0 * cnt[i] / cnt.sum()), 2),
                                       "hue_deg": round(float(hh[0]), 1), "sat": round(float(ss[0]), 3),
                                       "val": round(float(vv[0]), 3)})
    # THE FAMILY TEST QUESTION: how far apart are the two biggest saturated hue clusters?
    fams = family_clusters(a[sat_m], k=2)
    out["two_largest_saturated_families"] = fams
    if len(fams) == 2 and fams[0]["sat"] > HUE_NEEDS_SAT and fams[1]["sat"] > HUE_NEEDS_SAT:
        out["family_hue_separation_deg"] = round(dhue(fams[0]["hue_deg"], fams[1]["hue_deg"]), 1)
    else:
        out["family_hue_separation_deg"] = None
    out["shader_hue_tol_deg"] = 45.0
    out["note"] = ("the anchors and the coverage must come from the mask tool; there is no "
                   "Oracolo mask in the tree yet, so this inventory is the atlas's own "
                   "structure, not a coverage measurement")
    return out


def family_clusters(px: np.ndarray, k: int = 2) -> list:
    """k-means (k=2) over saturated texels, reported as hue/sat/val + share.

    Deterministic: seeded from the two most populated 16-level bins at least 96/255 apart,
    the same seeding rule kmeans2 uses, so the answer cannot depend on a random start.
    """
    if len(px) < 64:
        return []
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
        return []
    c = np.stack(seeds)
    labels = np.zeros(len(px), dtype=np.int32)
    for _ in range(100):
        d = np.linalg.norm(px[:, None, :] - c[None, :, :], axis=2)
        new = d.argmin(axis=1)
        if np.array_equal(new, labels) and _ > 0:
            labels = new
            break
        labels = new
        for j in range(2):
            if (labels == j).any():
                c[j] = px[labels == j].mean(axis=0)
    out = []
    for j in range(2):
        sel = labels == j
        if not sel.any():
            continue
        sub = px[sel]
        mq = (sub // 8).astype(np.int32)
        mk = mq[:, 0] * 1000000 + mq[:, 1] * 1000 + mq[:, 2]
        mu, mc = np.unique(mk, return_counts=True)
        best = mu[int(np.argmax(mc))]
        mode = np.array([(best // 1000000) * 8 + 4, ((best // 1000) % 1000) * 8 + 4, (best % 1000) * 8 + 4],
                        dtype=float)
        hh, ss, vv = hsv_of(mode.reshape(1, 3))
        out.append({"mode_hex": hex_of(mode), "mean_hex": hex_of(c[j]),
                    "share_pct": round(float(100.0 * sel.sum() / len(px)), 1),
                    "hue_deg": round(float(hh[0]), 1), "sat": round(float(ss[0]), 3),
                    "val": round(float(vv[0]), 3), "count": int(sel.sum())})
    out.sort(key=lambda r: -r["count"])
    return out


# --- GLB ---------------------------------------------------------------------
_CT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def glb_read(path: str) -> dict:
    """Parse a .glb: JSON chunk, BIN chunk, accessor reader. Read-only, no writer."""
    with open(path, "rb") as fh:
        d = fh.read()
    magic, ver, length = struct.unpack("<III", d[:12])
    if magic != 0x46546C67:
        raise SystemExit("not a glb: %s" % path)
    off = 12
    chunks = []
    while off < length:
        clen, ctype = struct.unpack("<II", d[off:off + 8])
        chunks.append((ctype, off + 8, clen))
        off += 8 + clen
    gj = json.loads(d[chunks[0][1]:chunks[0][1] + chunks[0][2]].decode("utf-8"))
    bin0 = chunks[1][1]

    def acc(i):
        a = gj["accessors"][i]
        bv = gj["bufferViews"][a["bufferView"]]
        fmt, size = _CT[a["componentType"]]
        n = _NC[a["type"]]
        st = bin0 + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride") or (size * n)
        if stride == size * n:
            return np.frombuffer(d, dtype=np.dtype(fmt), count=a["count"] * n,
                                 offset=st).reshape(a["count"], n).astype(np.float64)
        o = np.empty((a["count"], n), dtype=np.float64)
        for k in range(a["count"]):
            o[k] = np.frombuffer(d, dtype=np.dtype(fmt), count=n, offset=st + k * stride)
        return o

    return {"json": gj, "acc": acc, "raw": d, "bin0": bin0}


def model_measure() -> dict:
    """Classify the GLB's own triangles by sampling the baked texture at their UVs.

    This is the geometry half of the audit's "T+G locale" claim, made numeric. Every
    triangle contributes its 3D AREA to the class of the majority of its three texture
    samples, so "how much of the surface is bare skin" is a surface area and a share of the
    model, not a pixel count on an illustration.

    Read-only: no texture, mesh or asset is written.
    """
    if not os.path.exists(GLB_PATH):
        return {"error": "glb not found: %s" % os.path.relpath(GLB_PATH, REPO)}
    g = glb_read(GLB_PATH)
    gj = g["json"]
    acc = g["acc"]
    prim = gj["meshes"][0]["primitives"][0]
    POS = acc(prim["attributes"]["POSITION"])
    UV = acc(prim["attributes"]["TEXCOORD_0"])
    IDX = acc(prim["indices"]).astype(np.int64).ravel().reshape(-1, 3)
    joints = [gj["nodes"][n].get("name") for n in gj["skins"][0]["joints"]]
    tex_i = gj["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = gj["images"][gj["textures"][tex_i]["source"]]
    bv = gj["bufferViews"][img["bufferView"]]
    blob = g["raw"][g["bin0"] + bv.get("byteOffset", 0): g["bin0"] + bv.get("byteOffset", 0) + bv["byteLength"]]
    tex = Image.open(io.BytesIO(blob)).convert("RGB")
    T = np.asarray(tex).astype(np.float64)
    H, W = T.shape[:2]
    cls_map = hsv_atlas_classes(T)

    tri_cls = np.zeros((len(IDX), 3), dtype=np.uint8)
    for c in range(3):
        u = np.clip((UV[IDX[:, c], 0] % 1.0) * (W - 1), 0, W - 1).astype(int)
        v = np.clip((UV[IDX[:, c], 1] % 1.0) * (H - 1), 0, H - 1).astype(int)
        tri_cls[:, c] = cls_map[v, u]
    maj = np.array([np.bincount(tri_cls[k], minlength=6).argmax() for k in range(len(IDX))], dtype=np.uint8)

    P = POS[IDX]
    e1 = P[:, 1] - P[:, 0]
    e2 = P[:, 2] - P[:, 0]
    area = 0.5 * np.linalg.norm(np.cross(e1, e2), axis=1)
    cen = P.mean(axis=1)
    tot = float(area.sum())
    y = cen[:, 1]
    x = cen[:, 0]
    z = cen[:, 2]

    out = {"path": os.path.relpath(GLB_PATH, REPO), "verts": int(len(POS)), "triangles": int(len(IDX)),
           "surface_area_m2": round(tot, 4),
           "texture_size": [int(W), int(H)],
           "joints": joints,
           "class_area_share_pct": {}, "class_area_m2": {}}
    for k, nm in CLASS_NAMES.items():
        m = maj == k
        out["class_area_share_pct"][nm] = round(float(100.0 * area[m].sum() / tot), 1)
        out["class_area_m2"][nm] = round(float(area[m].sum()), 4)

    zones = {
        # the audit's two claims, as zones
        "shoulder_top_y1.38_1.47_x0.10_0.30": (np.abs(x) > 0.10) & (np.abs(x) < 0.30) & (y >= 1.38) & (y < 1.47),
        "shoulder_top_no_hair": None,
        "upper_arm_y1.20_1.38_x0.20_0.45": (np.abs(x) > 0.20) & (np.abs(x) < 0.45) & (y >= 1.20) & (y < 1.38),
        "chest_front_y1.20_1.45_x0.16_zpos": (np.abs(x) < 0.16) & (y >= 1.20) & (y < 1.45) & (z > 0),
        "midriff_front_y1.00_1.20_x0.16_zpos": (np.abs(x) < 0.16) & (y >= 1.00) & (y < 1.20) & (z > 0),
        "skirt_y0.80_1.00_x0.22_zpos": (np.abs(x) < 0.22) & (y >= 0.80) & (y < 1.00) & (z > 0),
        "thigh_y0.55_0.80_x0.25_zpos": (np.abs(x) < 0.25) & (y >= 0.55) & (y < 0.80) & (z > 0),
        "boot_y0.15_0.55_x0.25_zpos": (np.abs(x) < 0.25) & (y >= 0.15) & (y < 0.55) & (z > 0),
        "foot_y0.00_0.15_zpos": (y >= 0.00) & (y < 0.15) & (z > 0),
    }
    zones["shoulder_top_no_hair"] = zones["shoulder_top_y1.38_1.47_x0.10_0.30"] & (maj != 5)
    out["zones"] = {}
    for name, m in zones.items():
        A = area[m]
        if A.sum() < 1e-6:
            out["zones"][name] = {"area_m2": 0.0}
            continue
        rec = {"area_m2": round(float(A.sum()), 4),
               "share_pct": {CLASS_NAMES[c]: round(float(100.0 * A[maj[m] == c].sum() / A.sum()), 1)
                             for c in sorted(set(maj[m].tolist()))}}
        # the number the audit's claim is about: of the VISIBLE surface (hair excluded),
        # how much is bare skin
        vis = (maj[m] == 1) | (maj[m] == 2) | (maj[m] == 0) | (maj[m] == 4)
        if A[vis].sum() > 1e-9:
            rec["skin_share_of_non_hair_pct"] = round(float(100.0 * A[maj[m] == 1].sum() / A[vis].sum()), 1)
        out["zones"][name] = rec

    # vertical extent of the garment on the FRONT trunk: where does violet stop?
    prof = []
    for k in range(34):
        lo, hi = k * 0.05, k * 0.05 + 0.05
        m = (np.abs(x) < 0.14) & (z > 0) & (y >= lo) & (y < hi)
        A = area[m]
        if A.sum() < 1e-6:
            continue
        prof.append({"y_m": [round(lo, 2), round(hi, 2)], "area_m2": round(float(A.sum()), 5),
                     "skin_pct": round(float(100.0 * A[maj[m] == 1].sum() / A.sum()), 1),
                     "violet_pct": round(float(100.0 * A[maj[m] == 2].sum() / A.sum()), 1),
                     "near_black_pct": round(float(100.0 * A[maj[m] == 5].sum() / A.sum()), 1),
                     "grey_white_pct": round(float(100.0 * A[maj[m] == 4].sum() / A.sum()), 1)})
    out["front_trunk_profile"] = prof
    out["note"] = ("class is decided by sampling the BAKED texture at each triangle's own "
                   "UVs and taking the majority of its three corners, weighted by 3D area. "
                   "UV-seam triangles can straddle two classes; the effect is bounded by the "
                   "seam texels, and the zone numbers are shares, not absolutes.")
    return out


def mask_lane_cross_check() -> dict:
    """Read-only: does an Oracolo region mask exist yet?

    The anchors, the shipped mask's sha256 prefix and the family-test verdict can only be
    quoted if that lane has produced them. Absence is reported, not invented.
    """
    out = {"mask_dir": os.path.relpath(MASK_DIR, REPO), "present": os.path.isdir(MASK_DIR)}
    if not out["present"]:
        out["note"] = ("no Oracolo mask directory in the tree; the profile's mask path, "
                       "anchors and sha256 prefix must stay TODO and the six slots cannot be "
                       "checked against a mask from here")
        return out
    out["files"] = sorted(os.listdir(MASK_DIR))
    for f in out["files"]:
        p = os.path.join(MASK_DIR, f)
        if os.path.isfile(p):
            with open(p, "rb") as fh:
                out.setdefault("sha256_prefix", {})[f] = hashlib.sha256(fh.read()).hexdigest()[:16]
    return out


def card_check() -> dict:
    """How far each illustrated preview card is from the base card, read-only.

    The cards are ILLUSTRATIONS, not UV textures, and the port's reference is the in-field
    sprite. This block exists so the divergence is a measured number instead of an opinion.
    Both cards are opaque (no alpha), so the figure CANNOT be isolated from the painted
    background by a colour rule; that is why no per-band skin share is claimed for the card
    here and why the card/sprite comparison stays at whole-image level.
    """
    if not os.path.exists(CARD_BASE):
        return {"error": "base card not found: %s" % os.path.relpath(CARD_BASE, REPO)}
    with Image.open(CARD_BASE) as im:
        base = im.convert("RGB")
    out = {"base_card": os.path.relpath(CARD_BASE, REPO),
           "base_card_size": [int(base.size[0]), int(base.size[1])],
           "cards_are_opaque": True, "per_outfit": {}}
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
            "mean_abs_255": round(float(d.mean()), 1)}
    out["note"] = ("a preview card that differs from the base card over most of its area is a "
                   "different illustration, not a recolour; the in-field sprite is the "
                   "reference for this document.")
    return out


# ---------------------------------------------------------------------------
# the measurement
# ---------------------------------------------------------------------------
def measure(out_dir: str, write_evidence: bool, do_row_map: bool) -> dict:
    src = declared_source()
    hair_hex = src.get("_visual", {}).get("hair", "#0e0c16")
    skin_hex = src.get("_visual", {}).get("skin", "#8a5a3b")

    # --- grid check ---------------------------------------------------------
    grid = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit="signature"), oframes)):
            full = os.path.join(REPO, path)
            with Image.open(full) as im:
                size = im.size
            fw = size[0] / count
            gaps = frame_gaps(full)
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

    # --- racket rule: measured failure on this athlete ----------------------
    racket_probe = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        frames = load_frames(os.path.join(REPO, bpath), bframes)
        for fi, frame in enumerate(frames):
            rgba = np.asarray(frame).astype(np.int16)
            alpha = rgba[:, :, 3]
            c0, c1, _drop = own_span(alpha)
            m, info = racket_mask(rgba[:, c0:c1])
            bands = per_frame_bands(alpha[:, c0:c1])
            rec = dict(info)
            rec.update({"sheet": name, "frame": fi, "which": "base"})
            if bands:
                for region, (b0, b1, _bb) in bands.items():
                    r = np.arange(alpha[:, c0:c1].shape[0])[:, None]
                    band = (alpha[:, c0:c1] > ALPHA_MIN) & (r >= b0) & (r < b1)
                    rec["racket_pct_of_" + region] = round(100.0 * (band & m).sum() / max(1, int(band.sum())), 1)
            racket_probe.append(rec)

    # --- sheet band composition (the evidence for the sheet policy) ---------
    composition = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        composition += sheet_band_composition(name, bpath, bframes, hair_hex)

    # --- base palette and per-outfit pixels, under the two hair rules -------
    def gather(hair_sat_gate: bool):
        pools, per_sheet, bleed = {}, {}, []
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
                    if hair_sat_gate:
                        bleed.append({"sheet": name, "outfit": o, "frame": fi,
                                      "own_span": [int(c0), int(c1)], "dropped_px": int(dropped)})
                    excl = exclusion_masks(rgba, hair_hex, hair_sat_gate)
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
        return pools, per_sheet, bleed

    pools, per_sheet, bleed = gather(True)
    pools_strict, _, _ = gather(False)

    def clusterise(pools_):
        pal = {}
        for (o, region), chunks in sorted(pools_.items()):
            px = np.concatenate(chunks, axis=0)
            clusters = kmeans2(px)
            entry = {"pixels": int(len(px)), "modes": modal_colours(px), "clusters": []}
            for k, cl in enumerate(clusters):
                rgb = cl["rgb"]
                m_rgb = cl.get("mode_rgb", rgb)
                hue, sat, val = hsv_of(m_rgb.reshape(1, 3))
                entry["clusters"].append({
                    "family": "ab"[k] if len(clusters) == 2 else "a",
                    "mode_hex": hex_of(m_rgb), "mode_srgb": [int(round(v)) for v in m_rgb],
                    "mode_count": int(cl.get("mode_count", cl["count"])),
                    "mean_hex": hex_of(rgb), "srgb": [int(round(v)) for v in rgb],
                    "count": cl["count"],
                    "share_pct": round(float(100.0 * cl["count"] / len(px)), 1),
                    "hue_deg": round(float(hue[0]), 1), "sat": round(float(sat[0]), 3),
                    "val": round(float(val[0]), 3),
                    "spread_255": round(cl.get("spread_255", 0.0), 1)})
            pal.setdefault(o, {})[region] = entry
        return pal

    palette = clusterise(pools)
    palette_hair_strict = clusterise(pools_strict)

    per_sheet_palette = {}
    for (sheet, o, region), chunks in sorted(per_sheet.items()):
        px = np.concatenate(chunks, axis=0)
        per_sheet_palette.setdefault(sheet, {}).setdefault(o, {})[region] = {
            "pixels": int(len(px)), "modes": modal_colours(px, top=3)}

    def fam(o, region, family="a"):
        e = palette.get(o, {}).get(region)
        if not e or not e["clusters"]:
            return None
        for c in e["clusters"]:
            if c["family"] == family:
                return c
        return e["clusters"][0]

    # --- changed-pixel comparison against the base -------------------------
    # RESOLUTION WARNING, inherited from the Maestro lane: base frames are 298 px wide and
    # outfit frames 179, so this comparison REQUIRES resampling the base and its percentages
    # are an interval, not an exact value. Only the outfit-vs-outfit pairs are exact.
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
                       "base_frame_w": int(base_frames[fi].size[0]), "outfit_frame_w": int(w),
                       "resampled": True,
                       "body_px": int(alpha.sum()), "changed_px": int(ch.sum()),
                       "changed_pct_of_body": round(100.0 * ch.sum() / max(1, alpha.sum()), 2),
                       "changed_pct_of_frame": round(100.0 * ch.sum() / (w * h), 2)}
                bands = per_frame_bands(np.asarray(on)[:, :, 3])
                if bands:
                    rows = np.arange(h)[:, None]
                    for region, (b0, b1, _bb) in bands.items():
                        bs = alpha & (rows >= b0) & (rows < b1)
                        row["changed_pct_" + region] = round(
                            100.0 * (ch & bs).sum() / max(1, bs.sum()), 2)
                changes.append(row)

    # --- SILHOUETTE CHECK: resolution independent, so it IS exact ----------
    # The Maestro lane had to retract percentages produced by comparing resized images. The
    # way around it is to compare things that do not depend on the pixel grid: the share of
    # skin per normalised height band, and the figure width per normalised height. If the
    # signature artwork changed the silhouette or the bare-skin layout, these move.
    def profile(path: str, count: int, fi: int, hair_hex_: str) -> dict:
        frames = load_frames(os.path.join(REPO, path), count)
        rgba = np.asarray(frames[fi]).astype(np.int16)
        alpha = rgba[:, :, 3]
        c0, c1, _drop = own_span(alpha)
        alpha = alpha[:, c0:c1]
        rgb = rgba[:, c0:c1, :3].astype(np.float64)
        body = alpha > ALPHA_MIN
        bb = body_bbox(alpha)
        if bb is None:
            return {}
        y0, y1 = bb[1], bb[3]
        h = y1 - y0 + 1
        hue, sat, val = hsv_of(rgb)
        skin = (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN) & (val > SKIN_VAL_MIN)
        hair = np.abs(rgb - np.array(rgb_of(hair_hex_), dtype=np.float64)).max(axis=2) <= HAIR_TOL
        rows = np.arange(alpha.shape[0])[:, None]
        out = {}
        for k in range(20):
            r0 = y0 + int(k * 0.05 * h)
            r1 = max(r0 + 1, y0 + int((k + 1) * 0.05 * h))
            m = body & (rows >= r0) & (rows < r1)
            n = int(m.sum())
            if n == 0:
                out["%.2f" % (k * 0.05)] = None
                continue
            xs = np.nonzero(m)[1]
            out["%.2f" % (k * 0.05)] = {"px": n,
                                        "skin_pct": round(100.0 * (skin & m).sum() / n, 1),
                                        "hair_pct": round(100.0 * (hair & m).sum() / n, 1),
                                        "width_px": int(xs.max() - xs.min() + 1),
                                        "width_of_height": round((xs.max() - xs.min() + 1) / h, 4)}
        return {"path": path, "frame": fi, "bbox_h": int(h), "bands": out}

    silhouette = {}
    for name, bpath, bframes, opath, oframes in SHEETS:
        key = name
        silhouette.setdefault(key, {})["base"] = profile(bpath, bframes, 0, hair_hex)
        silhouette[key]["signature"] = profile(opath.format(outfit="signature"), oframes, 0, hair_hex)

    # --- the two hair rules side by side, so the sensitivity is visible -----
    hair_rule_sensitivity = {}
    for region in list(BANDS):
        a = fam("base", region, "a")
        b = (palette_hair_strict.get("base", {}).get(region) or {}).get("clusters") or []
        a2 = (b[0] if b else None)
        if a and a2:
            hair_rule_sensitivity[region] = {
                "sat_gated_rule": {"mode_hex": a["mode_hex"], "share_pct": a["share_pct"], "pixels": palette["base"][region]["pixels"]},
                "strict_maestro_rule": {"mode_hex": a2["mode_hex"], "share_pct": a2["share_pct"],
                                        "pixels": palette_hair_strict["base"][region]["pixels"]},
                "de76_between_rules": round(de76(rgb_of(a["mode_hex"]), rgb_of(a2["mode_hex"])), 1)}
    hair_rule_sensitivity["_why"] = (
        "the declared hair %s is only 34/255 from the Oracolo's declared secondary %s, so the "
        "Maestro's hair rule (max-channel <= %d/255) also deletes dark violet garment pixels. "
        "The sat-gated rule (<= %.2f saturation) keeps them. Both are reported."
        % (hair_hex, src.get("_visual", {}).get("secondary"), HAIR_TOL, HAIR_SAT_MAX))

    # --- palette distances ------------------------------------------------
    def hsv1(hexv):
        h, s, v = hsv_of(np.array(rgb_of(hexv), dtype=float).reshape(1, 3))
        return float(h[0]), float(s[0]), float(v[0])

    distances = {}
    for region in list(BANDS):
        for f in ("a", "b"):
            cb, co = fam("base", region, f), fam("signature", region, f)
            if not cb or not co:
                continue
            hbx, sb, vb = hsv1(cb["mode_hex"])
            hox, so, vo = hsv1(co["mode_hex"])
            distances["%s_%s" % (region, f)] = {
                "base_mode": cb["mode_hex"], "signature_mode": co["mode_hex"],
                "de76": round(de76(rgb_of(cb["mode_hex"]), rgb_of(co["mode_hex"])), 1),
                "dhue_deg": None if min(sb, so) < HUE_NEEDS_SAT else round(dhue(hbx, hox), 1),
                "sats": [round(sb, 3), round(so, 3)], "dval": round(abs(vb - vo), 3)}

    # --- the family-test question -----------------------------------------
    # The shader tells the two families of a region apart by HUE with a 45 deg tolerance.
    # So the question is the hue distance between the two families the sprite paints in a
    # region, and between the two families the atlas actually has.
    fam_sep = {}
    for region in list(BANDS):
        ca, cb = fam("signature", region, "a"), fam("signature", region, "b")
        if not ca or not cb:
            continue
        sep = None
        if min(ca["sat"], cb["sat"]) >= HUE_NEEDS_SAT:
            sep = round(dhue(ca["hue_deg"], cb["hue_deg"]), 1)
        fam_sep[region] = {"a_mode": ca["mode_hex"], "a_hue": ca["hue_deg"], "a_sat": ca["sat"],
                           "b_mode": cb["mode_hex"], "b_hue": cb["hue_deg"], "b_sat": cb["sat"],
                           "hue_separation_deg": sep,
                           "b_is_the_shared_white": bool(cb["sat"] < TRIM_SAT_MAX)}
    fam_sep["_shader_hue_tol_deg"] = 45.0
    fam_sep["_note"] = ("the two families the SPRITE paints in a region are the garment violet "
                        "and the base's shared near-white trim; the white has sat < 0.15, so "
                        "the hue test cannot see it at all (sat_min rejects it). The atlas "
                        "side of the same question is in `atlas_inventory."
                        "two_largest_saturated_families`.")

    # --- the six slots, with provenance attached to every one of them ------
    slots = {}
    decl = src.get("signature", [])
    for region in list(BANDS):
        for f in ("a", "b"):
            c = fam("signature", region, f)
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
                dh = dhue(hm, hbest)
                if region == "torso" and f == "a":
                    if min(sm, sbest) > HUE_NEEDS_SAT and dh <= D_MATCH_HUE:
                        origin, hexv = "source", best
                        reason = ("torso_a carries the outfit's identity; the measured %s is "
                                  "the declared %s in the same hue family (dHue %.1f deg <= "
                                  "%.0f deg), only the 2D shading differs (val %.2f vs %.2f), "
                                  "so the authored value takes the slot"
                                  % (measured, best, dh, D_MATCH_HUE, vm, vbest))
                    elif de_best <= D_MATCH_DE:
                        origin, hexv = "source", best
                        reason = ("torso_a carries the outfit's identity; measured %s is the "
                                  "declared %s (dE76 %.1f <= %.0f)" % (measured, best, de_best, D_MATCH_DE))
                elif (sm < TRIM_SAT_MAX and f == "b" and len(decl) > 1
                      and hsv1(decl[1])[1] > TRIM_SAT_MAX):
                    origin, hexv = "source", decl[1]
                    reason = ("sprite paints this trim as the base's white (%s, sat %.3f); that "
                              "white is identical in base and signature, so it carries no "
                              "outfit information, and the declared second colour %s is itself "
                              "a colour (sat %.3f), so it takes the slot"
                              % (measured, sm, decl[1], hsv1(decl[1])[1]))
                else:
                    reason = ("measured modal colour of the region (%s, %.1f%% of the region's "
                              "garment pixels); the reference declares no colour for this "
                              "region/family" % (measured, mk))
            key = "%s_%s" % (region, f)
            rec = {"hex": hexv, "origin": origin, "measured_mode": measured,
                   "measured_share_pct": mk, "reason": reason}
            ov = PORT_OVERRIDES.get(("signature", key))
            if ov:
                rec = {"hex": ov["hex"], "origin": "port", "measured_mode": measured,
                       "measured_share_pct": mk, "reason": ov["why"], "would_have_been": hexv}
            slots.setdefault("signature", {})[key] = rec

    # --- separation lever: base vs signature, slot by slot -----------------
    separation = {}
    for key in ("torso_a", "torso_b", "hip_a", "hip_b", "foot_a", "foot_b"):
        region, f = key.split("_")
        cb, co = fam("base", region, f), fam("signature", region, f)
        s1 = slots.get("signature", {}).get(key)
        if not cb or not co or not s1:
            continue
        separation[key] = {
            "base_measured": cb["mode_hex"], "signature_measured": co["mode_hex"],
            "signature_proposed": s1["hex"],
            "de76_base_vs_measured_signature": round(de76(rgb_of(cb["mode_hex"]), rgb_of(co["mode_hex"])), 1),
            "de76_base_vs_proposed_signature": round(de76(rgb_of(cb["mode_hex"]), rgb_of(s1["hex"])), 1)}
    # is the proposed signature value already the model's own baked colour?
    atlas = atlas_inventory()
    atlas_mode = None
    if atlas.get("saturated_modes"):
        atlas_mode = atlas["saturated_modes"][0]["hex"]
    if atlas_mode:
        for key, rec in separation.items():
            rec["atlas_mode_hex"] = atlas_mode
            rec["de76_atlas_mode_vs_proposed_signature"] = round(
                de76(rgb_of(atlas_mode), rgb_of(rec["signature_proposed"])), 1)

    # mass-weighted separation: a proxy for what a player sees at match distance.
    weights, tot_px = {}, 0.0
    for region in list(BANDS):
        n1 = palette["base"][region]["pixels"] if region in palette.get("base", {}) else 0
        n2 = palette["signature"][region]["pixels"] if region in palette.get("signature", {}) else 0
        for f in ("a", "b"):
            r1 = fam("base", region, f)
            r2 = fam("signature", region, f)
            if not r1 or not r2:
                continue
            w = 0.5 * (n1 * r1["share_pct"] / 100.0 + n2 * r2["share_pct"] / 100.0)
            weights["%s_%s" % (region, f)] = w
            tot_px += w
    weighted = {}
    for k, w in weights.items():
        if not separation.get(k):
            continue
        weighted[k] = {"weight_pct": round(100.0 * w / max(tot_px, 1e-9), 1),
                       "de76_measured": separation[k]["de76_base_vs_measured_signature"],
                       "de76_proposed": separation[k]["de76_base_vs_proposed_signature"]}
    sep_summary = {
        "per_slot": separation, "mass_weighted": weighted,
        "mass_weighted_de76_measured": round(sum(v["weight_pct"] * v["de76_measured"] / 100.0 for v in weighted.values()), 1),
        "mass_weighted_de76_proposed": round(sum(v["weight_pct"] * v["de76_proposed"] / 100.0 for v in weighted.values()), 1),
        "weight_note": "weights are measured pixel shares of each region x family, averaged "
                       "over base and signature; a proxy for match-distance legibility, not a "
                       "perceptual model",
    }

    # --- old idle vs v2, the special case in outfitSpritePaths -------------
    old_idle = {}
    for label, tmpl, count in OLD_IDLE:
        p_old = os.path.join(REPO, tmpl.format(outfit="signature"))
        p_new = os.path.join(REPO, tmpl.replace("idle.webp", "idle-v2.webp").format(outfit="signature"))
        if not os.path.exists(p_old):
            continue
        with Image.open(p_old) as i1, Image.open(p_new) as i2:
            a1 = np.asarray(i1.convert("RGBA")).astype(np.int16)
            a2 = np.asarray(i2.convert("RGBA")).astype(np.int16)
        same = a1.shape == a2.shape
        rec = {"old": os.path.relpath(p_old, REPO), "v2": os.path.relpath(p_new, REPO),
               "same_size": bool(same), "old_size": [int(a1.shape[1]), int(a1.shape[0])],
               "v2_size": [int(a2.shape[1]), int(a2.shape[0])]}
        if same:
            body = (a1[:, :, 3] > ALPHA_MIN) & (a2[:, :, 3] > ALPHA_MIN)
            d = np.abs(a1[:, :, :3] - a2[:, :, :3]).max(axis=2)
            rec["changed_pct_of_body"] = round(100.0 * (body & (d > CHANGE_EPS)).sum() / max(1, int(body.sum())), 1)
            rec["mean_alpha_old"] = round(float(a1[:, :, 3][a1[:, :, 3] > 0].mean()), 1)
            rec["mean_alpha_v2"] = round(float(a2[:, :, 3][a2[:, :, 3] > 0].mean()), 1)
            # the declared reason for the special case: the old idle read as semi-transparent
            rec["old_px_below_alpha_200"] = int(((a1[:, :, 3] > 0) & (a1[:, :, 3] < 200)).sum())
            rec["v2_px_below_alpha_200"] = int(((a2[:, :, 3] > 0) & (a2[:, :, 3] < 200)).sum())
        old_idle[label] = rec

    report = {
        "_tool": "tools/character/measure_oracolo_palette.py",
        "method": {
            "alpha_min": ALPHA_MIN,
            "bands_of_body_bbox_height": BANDS,
            "extra_bands_not_rig_regions": EXTRA_BANDS,
            "change_eps_255": CHANGE_EPS,
            "family_convention": "a = larger cluster (dominant garment mass), b = trim",
            "heuristics": {
                "skin": "hue 9-38 deg, sat > 0.30, val > 0.20 (declared port heuristic); declared "
                        "Oracolo skin %s" % skin_hex,
                "hair_sat_gated": "max-channel distance <= %d/255 from declared hair %s AND sat "
                                  "<= %.2f" % (HAIR_TOL, hair_hex, HAIR_SAT_MAX),
                "hair_strict_maestro": "max-channel distance <= %d/255 from declared hair %s "
                                       "(the Maestro's rule; measured to eat the Oracolo's dark "
                                       "violet trim, reported side by side)" % (HAIR_TOL, hair_hex),
                "racket": "the Maestro's largest-8-connected-gold-blob rule, closed %d px then "
                          "dilated %d px -- kept so its measured FAILURE on this athlete is a "
                          "number" % (RACKET_CLOSE, RACKET_GROW),
            },
            "sprite_name_special_case": src.get("_sprite_name_special_case"),
        },
        "source_colours_declared": src,
        "sheet_band_composition": composition,
        "bands_sheet_policy": {k: list(v) for k, v in BAND_SHEET_EXCLUDE.items()},
        "frame_grid_check": grid,
        "racket_rule_probe": racket_probe,
        "sheet_bleed": {"per_frame": bleed, "total_dropped_px": int(sum(b["dropped_px"] for b in bleed)),
                        "note": "columns belonging to a neighbouring figure's ink on the "
                                "four-frame sheets; excluded from the colour measurement"},
        "measured_palette": palette,
        "measured_palette_strict_hair_rule": palette_hair_strict,
        "hair_rule_sensitivity": hair_rule_sensitivity,
        "measured_palette_per_sheet": per_sheet_palette,
        "slot_proposal": slots,
        "separation_proposal": sep_summary,
        "family_test_question": fam_sep,
        "distance_from_base": distances,
        "silhouette_check": silhouette,
        "pixel_changes_vs_base": changes,
        "atlas_inventory": atlas,
        "model_measure": model_measure(),
        "mask_lane_cross_check": mask_lane_cross_check(),
        "card_check": card_check(),
        "old_idle_vs_v2": old_idle,
    }
    if do_row_map:
        report["row_map"] = row_map()

    os.makedirs(out_dir, exist_ok=True)
    dump = os.path.join(out_dir, "oracolo-palette-report.json")
    with open(dump, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2)
        fh.write("\n")
    print("WROTE %s" % os.path.relpath(dump, REPO))

    if write_evidence:
        write_evidence_images(out_dir, report)

    # --- console summary ---------------------------------------------------
    for o in ["base"] + OUTFITS:
        bits = []
        for region in list(BANDS):
            for f in ("a", "b"):
                c = fam(o, region, f)
                if c:
                    bits.append("%s_%s=%s(mode)/%s(mean) %s%%" % (region, f, c["mode_hex"], c["mean_hex"], c["share_pct"]))
        print("%-10s %s" % (o, "  ".join(bits)))
    print("slots proposed (origin/source per slot):")
    for key in ("torso_a", "torso_b", "hip_a", "hip_b", "foot_a", "foot_b"):
        rec = report["slot_proposal"]["signature"][key]
        print("  %-8s %s  [%s]  measured=%s  %s" % (key, rec["hex"], rec["origin"], rec["measured_mode"], rec["reason"]))
    print("base vs signature (dE76 measured -> proposed):")
    for k, v in sep_summary["per_slot"].items():
        print("  %-8s %s -> %s : %.1f -> %.1f" % (k, v["base_measured"], v["signature_proposed"],
                                                  v["de76_base_vs_measured_signature"], v["de76_base_vs_proposed_signature"]))
    print("  mass-weighted: measured=%.1f proposed=%.1f" % (sep_summary["mass_weighted_de76_measured"],
                                                             sep_summary["mass_weighted_de76_proposed"]))
    print("family-test question (sprite, per region):")
    for region in list(BANDS):
        r = fam_sep.get(region)
        if r:
            print("  %-6s a=%s h%.1f  b=%s h%.1f sat%.3f  hue_sep=%s  b_is_white=%s"
                  % (region, r["a_mode"], r["a_hue"], r["b_mode"], r["b_hue"], r["b_sat"],
                     r["hue_separation_deg"], r["b_is_the_shared_white"]))
    at = report["atlas_inventory"]
    if "error" not in at:
        print("ATLAS %s %s saturated=%.1f%%  violet240_300=%.1f%%  skin0_40=%.1f%%  cyan170_215=%.2f%%  gold=%.2f%%"
              % (at["path"], at["size"], at["saturated_share_pct"], at["violet_240_300_pct_of_saturated"],
                 at["warm_skin_0_40_pct_of_saturated"], at["cyan_170_215_pct_of_saturated"],
                 at["gold_35_70_pct_of_saturated"]))
        if at.get("two_largest_saturated_families"):
            f2 = at["two_largest_saturated_families"]
            print("  atlas two largest saturated families: %s (%.1f%%, h%.1f) vs %s (%.1f%%, h%.1f) -> hue sep %s deg under tol %.0f"
                  % (f2[0]["mode_hex"], f2[0]["share_pct"], f2[0]["hue_deg"],
                     f2[1]["mode_hex"], f2[1]["share_pct"], f2[1]["hue_deg"],
                     at.get("family_hue_separation_deg"), at["shader_hue_tol_deg"]))
    mm = report["model_measure"]
    if "error" not in mm:
        print("MODEL %s verts=%d tris=%d area=%.3f m2  classes: %s"
              % (mm["path"], mm["verts"], mm["triangles"], mm["surface_area_m2"],
                 "  ".join("%s=%.1f%%" % (k, v) for k, v in mm["class_area_share_pct"].items())))
        for zn in ("shoulder_top_y1.38_1.47_x0.10_0.30", "shoulder_top_no_hair", "chest_front_y1.20_1.45_x0.16_zpos",
                   "midriff_front_y1.00_1.20_x0.16_zpos", "thigh_y0.55_0.80_x0.25_zpos"):
            z = mm["zones"].get(zn)
            if z:
                print("  %-42s area %.4f  skin_of_non_hair=%s%%  %s" % (zn, z["area_m2"],
                      z.get("skin_share_of_non_hair_pct"), z.get("share_pct")))
    mc = report["mask_lane_cross_check"]
    print("MASKLANE %s present=%s %s" % (mc["mask_dir"], mc["present"], mc.get("note", "")))
    cc = report["card_check"]
    if "error" not in cc:
        print("CARD base=%s %s: %s" % (cc["base_card"], cc["base_card_size"], "  ".join(
            "%s=%.1f%% over 16/255 (mean %.1f/255)" % (o, v["pct_pixels_over_16_255"], v["mean_abs_255"])
            for o, v in cc["per_outfit"].items())))
    return report


# ---------------------------------------------------------------------------
# evidence images
# ---------------------------------------------------------------------------
def write_evidence_images(out_dir: str, report: dict) -> None:
    """Band boundaries + exclusion masks on the base sprite, slot swatches, and the model.

    The mask-check images are the check on the heuristics: if the skin/hair/racket masks
    leaked into the garment, it is visible here as a hole in the fabric.
    """
    hair_hex = report["source_colours_declared"].get("_visual", {}).get("hair", "#0e0c16")
    for name, bpath, bframes, _o, _of in SHEETS:
        frames = load_frames(os.path.join(REPO, bpath), bframes)
        panels = []
        for fi, frame in enumerate(frames):
            rgba = np.asarray(frame).astype(np.int16)
            alpha = rgba[:, :, 3]
            excl = exclusion_masks(rgba, hair_hex, True)
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

    # swatch strips: measured modes, and proposed slots with provenance letter
    cols = [("torso_a", "torso", "a"), ("torso_b", "torso", "b"),
            ("hip_a", "hip", "a"), ("hip_b", "hip", "b"),
            ("foot_a", "foot", "a"), ("foot_b", "foot", "b")]
    rowh, cw = 52, 140
    pal = report["measured_palette"]
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
                    e = (pal.get(o) or {}).get(region) or {}
                    rgb, note = None, ""
                    for c in e.get("clusters", []):
                        if c["family"] == f:
                            rgb, note = rgb_of(c["mode_hex"]), "M %s%%" % c["share_pct"]
                    if rgb is None and e.get("clusters"):
                        rgb, note = rgb_of(e["clusters"][0]["mode_hex"]), "only family"
                else:
                    rec = (report["slot_proposal"].get(o) or {}).get(label)
                    rgb = rgb_of(rec["hex"]) if rec else None
                    note = ((rec["hex"] + "  " + {"source": "S", "sprite": "M", "port": "P"}.get(rec["origin"], "?")) if rec else "")
                if rgb:
                    d.rectangle([x, y + 10, x + cw - 12, y + 44], fill=rgb)
                    d.text((x + 4, y + 44), note, fill=(200, 200, 200))
        path = os.path.join(out_dir, "%s-slots.png" % which)
        img.save(path)
        print("WROTE %s" % os.path.relpath(path, REPO))

    # the model: baked front/back, and the class map the numbers come from
    write_model_images(out_dir)


def write_model_images(out_dir: str) -> None:
    """Rasterise the GLB's own triangles (painter's algorithm + z-buffer) from the texture.

    This is the geometry evidence: the baked model, the class map behind the area numbers,
    and a front view that can be put beside the 2D card. Read-only.
    """
    if not os.path.exists(GLB_PATH):
        return
    g = glb_read(GLB_PATH)
    gj = g["json"]
    acc = g["acc"]
    prim = gj["meshes"][0]["primitives"][0]
    POS = acc(prim["attributes"]["POSITION"])
    UV = acc(prim["attributes"]["TEXCOORD_0"])
    IDX = acc(prim["indices"]).astype(np.int64).ravel().reshape(-1, 3)
    tex_i = gj["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img = gj["images"][gj["textures"][tex_i]["source"]]
    bv = gj["bufferViews"][img["bufferView"]]
    blob = g["raw"][g["bin0"] + bv.get("byteOffset", 0): g["bin0"] + bv.get("byteOffset", 0) + bv["byteLength"]]
    T = np.asarray(Image.open(io.BytesIO(blob)).convert("RGB")).astype(np.float64)
    H, W = T.shape[:2]
    cls_map = hsv_atlas_classes(T)
    PAL = np.array([[0, 0, 0], [255, 80, 40], [110, 60, 235], [235, 60, 200], [235, 235, 235], [40, 40, 48]], np.uint8)
    CT_ = PAL[cls_map]

    def raster(axis: int, source: str, size: int = 560):
        Wd = size
        xlo, xhi = -0.85, 0.85
        ylo, yhi = -0.05, 1.75
        Hd = int(Wd * (yhi - ylo) / (xhi - xlo))
        out = np.zeros((Hd, Wd, 3))
        zbuf = np.full((Hd, Wd), -1e9)
        sx = (POS[:, 0] - xlo) / (xhi - xlo) * (Wd - 1)
        sy = (Hd - 1) - (POS[:, 1] - ylo) / (yhi - ylo) * (Hd - 1)
        sz = POS[:, 2] * (1 if axis == 0 else -1)
        for tri in IDX:
            X = sx[tri]; Y = sy[tri]; Z = sz[tri]
            x0 = max(0, int(np.floor(X.min()))); x1 = min(Wd - 1, int(np.ceil(X.max())))
            y0 = max(0, int(np.floor(Y.min()))); y1 = min(Hd - 1, int(np.ceil(Y.max())))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            d00 = (X[1] - X[0]) * (Y[2] - Y[0]) - (X[2] - X[0]) * (Y[1] - Y[0])
            if abs(d00) < 1e-12:
                continue
            w0 = ((X[1] - gx) * (Y[2] - gy) - (X[2] - gx) * (Y[1] - gy)) / d00
            w1 = ((X[2] - gx) * (Y[0] - gy) - (X[0] - gx) * (Y[2] - gy)) / d00
            w2 = 1.0 - w0 - w1
            m = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not m.any():
                continue
            zz = w0 * Z[0] + w1 * Z[1] + w2 * Z[2]
            sub = zbuf[y0:y1 + 1, x0:x1 + 1]
            upd = m & (zz > sub)
            if not upd.any():
                continue
            uu = w0 * UV[tri[0], 0] + w1 * UV[tri[1], 0] + w2 * UV[tri[2], 0]
            vv = w0 * UV[tri[0], 1] + w1 * UV[tri[1], 1] + w2 * UV[tri[2], 1]
            xq = np.clip((uu[upd] % 1.0) * (W - 1), 0, W - 1).astype(int)
            yq = np.clip((vv[upd] % 1.0) * (H - 1), 0, H - 1).astype(int)
            col = T[yq, xq] if source == "baked" else CT_[yq, xq]
            sub[upd] = zz[upd]
            out[y0:y1 + 1, x0:x1 + 1][upd] = col
        return out.astype(np.uint8)

    for axis, name in ((0, "front"), (1, "back")):
        rgb = raster(axis, "baked")
        bg = np.zeros_like(rgb); bg[:] = (18, 18, 22)
        mask = rgb.sum(2) > 0
        bg[mask] = rgb[mask]
        p = os.path.join(out_dir, "model-%s.png" % name)
        Image.fromarray(bg).save(p)
        print("WROTE %s" % os.path.relpath(p, REPO))
        cm = raster(axis, "class")
        p = os.path.join(out_dir, "model-%s-classes.png" % name)
        Image.fromarray(cm).save(p)
        print("WROTE %s" % os.path.relpath(p, REPO))


def main() -> int:
    global CHANGE_EPS
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=DEFAULT_OUT)
    ap.add_argument("--no-evidence", action="store_true")
    ap.add_argument("--row-map", action="store_true",
                    help="also dump the base sprite's row-by-row colour map, which is where "
                         "BANDS comes from")
    ap.add_argument("--change-eps", type=int, default=CHANGE_EPS,
                    help="per-channel /255 delta above which a pixel counts as changed "
                         "(default %d)" % CHANGE_EPS)
    args = ap.parse_args()
    CHANGE_EPS = args.change_eps
    measure(os.path.abspath(args.out_dir), not args.no_evidence, args.row_map)
    return 0


if __name__ == "__main__":
    sys.exit(main())
