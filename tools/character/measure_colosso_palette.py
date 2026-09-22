#!/usr/bin/env python3
"""Measure the Colosso `signature` outfit palette off the in-field 2D sprites.

WHY THIS TOOL EXISTS

The 3D rig recolours a baked model inside a UV mask that splits the body into three
regions -- torso, hip (shorts), foot (shoes) -- and every region carries two colour
families, `a` and `b`. An outfit is therefore six colours:
torso_a, torso_b, hip_a, hip_b, foot_a, foot_b (see
`godot/src/character/outfit_catalogue.gd::OUTFIT_PROFILES`, entries `fiamma` and
`maestro`).

The browser reference (`js/data.js::ATHLEET_OUTFITS.colosso`, variant `signature`)
declares only TWO colours: `#25211e` (dark leather) and `#ff7a12` (orange). This tool
measures what the in-field 2D sprites actually paint, region by region, so the six
slots can be filled from evidence instead of guesswork.

WHAT IT MEASURES

  * frame grid       every Colosso sheet is a horizontal strip; frame counts come from
                     the asset contract (`js/data.js` runFrames) and are checked against
                     the alpha gaps between figures.
  * body bbox        per frame, from alpha > ALPHA_MIN.
  * bands            fractions of the body height, declared in BANDS below. `hip`'s
                     bottom edge is measured, not eyeballed: see HEM DETECTION.
  * exclusions       skin, hair and the racket. All three rules are heuristics and are
                     declared in SKIN_*, HAIR_TOL and racket_columns(). HONEST STATE:
                     the racket rule DID NOT FIRE on any sheet or frame of this athlete
                     (`racket_rule_log.applied_count` is 0), so the racket was not
                     removed and the pool may contain racket pixels. The rule's failure
                     and the cross-check that runs the same measurement with the rule
                     deliberately off (`measured_palette_no_racket_exclusion`) are both
                     in the report.
  * families         per (outfit, region), deterministic k-means with k=2 over the
                     surviving pixels. `a` is the larger cluster (the dominant garment
                     mass), `b` the smaller one (the trim).

WHY THE SKIN RULE NEEDS A VALUE FLOOR ON THIS ATHLETE (measured, not taste)

The port's declared skin heuristic is `hue 9-38 deg AND sat > 0.30`. On the Maestro
that removes a plausible amount of the body. On Colosso it removes **61.6-66.3 % of
every sprite's body pixels**, because his whole outfit is warm brown leather (hue
28-33) and shares the skin's hue band. The rule is therefore extended here with a
VALUE floor, and the floor is measured: pixels within dE76 12 of the declared skin
`#b06a3f` have value p10 = 0.60-0.61 and p50 = 0.65-0.68 on all six sheets, while the
leather mass sits at value 0.03-0.35. `val > 0.50` keeps all of the real skin and
drops the leather. The residual skin that stays in the pool is counted and reported
(`residual_skin_px`), not hidden.

CONSEQUENCE, STATED UP FRONT: the same floor also removes the outfit's glowing orange
details, which are the brightest warm pixels in the sprite (measured glow modes at
value > 0.90: #eb8b5c, #eb8d62, #eb8c32, #ee994a on `idle`, #eb7b13, #eb7c13, #eb7d15,
#eb8c33 on `action`) and sit at hue 19-29 deg -- inside the skin window. Skin and
emissive orange are the same hue band on this athlete; value is the only lever, and it
is the same lever. The report quantifies both sides (`orange_vs_skin`).

WHAT THE MEASUREMENT CANNOT DO ON THIS ATHLETE, AND THE TOOL SAYS SO

  * There is no flat garment fill in these sprites. The most populated 16-level RGB bin
    of a region is 7.4 % of the torso, 10.5 % of the hip and 7.5 % of the foot
    (signature), so "the modal colour" is a weak statistic here -- on the Maestro the
    equivalent number was 56 %. What wins the mode on Colosso is the sprite's NEUTRAL
    SHADING: #474545 (sat 0.029) on the torso and the hip, #fffffe/#ffffff (sat
    0.000-0.004) as the second family. Five of the six measured modes therefore fail the
    shader's own family test (sat_min 0.18) and are not garment colours at all.
  * RULE 5 in `measure()` handles that: a measured mode failing the family test is
    REJECTED (and kept in the record) and the slot falls back to the declared colour of
    its family. The document must not present a rejected mode as the outfit's colour.
  * The atlas's two families are 6.0 deg apart in hue under a 45 deg tolerance, so with
    the value gate OFF both anchors own exactly the same texels (68.3 % of the torso's
    masked texels at the effective constants) and the six slots collapse onto one colour
    per region -- the Maestro failure mode. `atlas_family_split_in_mask()` measures this
    on the real atlas and mask, read-only.

INTERPRETER

numpy + PIL only, no network, no paid API, no asset writes outside
`docs/agent-work/outfits-3d/evidence/colosso-palette/`. On this host:
  python3 -m venv <venv> && <venv>/bin/pip install pillow numpy

USAGE

  <venv>/bin/python tools/character/measure_colosso_palette.py
  <venv>/bin/python tools/character/measure_colosso_palette.py --out-dir <dir> --no-evidence
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
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DEFAULT_OUT = os.path.join(REPO, "docs", "agent-work", "outfits-3d", "evidence", "colosso-palette")

ALPHA_MIN = 200          # /255, body pixels; below this is antialiased edge or empty
CHANGE_EPS = 16          # /255, per-channel delta above which a pixel counts as changed
HAIR_TOL = 48            # /255, max-channel distance to the declared hair colour
SKIN_HUE = (9.0, 38.0)   # deg, declared port heuristic
SKIN_SAT_MIN = 0.30      # declared port heuristic
SKIN_VAL_MIN = 0.50      # MEASURED floor for this athlete, see the module docstring
HUE_NEEDS_SAT = 0.15     # below this saturation a hue difference is meaningless (near-blacks)
D_MATCH_DE = 20.0        # dE76 within which a measured mode counts as the declared colour
D_MATCH_HUE = 12.0       # deg, hue window in which a shaded mode counts as the declared colour
RACKET_GAP = 3           # px, transparent column gap that separates the racket from the body
RACKET_OCC = 0.85        # column occupancy fraction that marks the body's own column block

# The shader's family test. TWO SETS OF NUMBERS, because they disagree and the
# EFFECTIVE one is the catalogue's:
#   * godot/src/character/outfit_region_recolour.gdshader declares sat_min 0.25,
#     val_min 0.06, hue_tol_deg 42.0 -- but those are only its own defaults;
#   * godot/src/character/outfit_catalogue.gd::MASK_DEFAULTS writes sat_min 0.18,
#     val_min 0.02, val_max 0.98, hue_tol_deg 45.0 into every profile material, so
#     the values that actually run are these.
# Both are quoted, and every inertness number below is computed at BOTH settings.
SHADER_SAT_MIN_DEFAULT = 0.25
SHADER_HUE_TOL_DEG = 42.0
SHADER_VAL_MIN = 0.06
CATALOGUE_SAT_MIN = 0.18      # MASK_DEFAULTS, i.e. what the rig actually uses
CATALOGUE_HUE_TOL_DEG = 45.0
CATALOGUE_VAL_MIN = 0.02
SAT_MIN_EFFECTIVE = CATALOGUE_SAT_MIN
# dE76 below which painting a target over its own baked anchor is a change the eye
# will not read as a recolour. Declared, not derived: 5.0 is the usual rough
# large-patch just-noticeable difference for CIE76.
INVISIBLE_DE76 = 5.0
# dE76 at or below which a target is still "the same colour, repainted".
SUBTLY_DE76 = 12.0

# PORT_OVERRIDES: slots where the port deliberately leaves what BOTH the sprite and the
# reference say. Every entry is labelled `port` in the output and carries its own reason.
# Filled in below after the measurement; see `slots` in measure().
PORT_OVERRIDES: dict = {}

# --- bands ------------------------------------------------------------------
# Fractions of the body bbox height (bbox = alpha > ALPHA_MIN, per frame, per sheet).
# `torso` and `foot` keep the fractions the Fiamma/Maestro profiles use, so the three
# athletes stay comparable.
#
# HEM DETECTION, the measured basis for `hip`'s bottom edge: the widest run of opaque
# pixels per row is the garment silhouette; the hem is the first row where it drops below
# 62 % of the previous row's, because below the shorts hem the figure splits into two
# narrow bare legs. Measured (median of the per-frame first drop, printed in the report
# as `hem_detection`):
#   idle 0.59 · run 0.60 · back-idle 0.58 · action 0.66 · back-run 0.66 · back-action 0.48
# The detector is a FIRST-drop detector, so on `back-action` (0.48) it fires on the arm
# crossing the body rather than on the hem, and on `idle`/`back-idle` (0.58-0.59) the
# hip band's top 0.03-0.04 therefore lands on bare thigh. That spill is what the skin
# rule is for -- bare thigh is skin (hue 9-38, sat > 0.30, val > 0.50) and is removed --
# so the band is still measured on every sheet and reported per sheet
# (`measured_palette_per_sheet`).
BANDS = {
    "torso": (0.12, 0.48),
    "hip": (0.48, 0.62),
    "foot": (0.90, 1.00),
}
EXTRA_BANDS = {"socks": (0.80, 0.90)}   # evidence only, not a rig region
HEM_SCAN = (0.44, 0.80)                 # fractions scanned by the hem detector

# Which sheets feed which region's POOLED number. MEASURED REASON: `back-action` is the
# one sheet whose measured hem (0.48) sits at the hip band's own bottom edge, i.e. the
# whole band is on bare leg, and its first drop is the arm and not the hem; it is left
# out of the pooled hip number and still reported per sheet. `idle` and `back-idle`
# (0.58-0.59) are KEPT: their spill is 0.03-0.04 of the body height and is bare thigh,
# which the skin rule removes. The previous revision of this file excluded
# ("action", "back-run") -- the two sheets with the LARGEST measured hem (0.66), i.e. the
# two whose band sits most safely inside the shorts. That was inverted; corrected here.
BAND_SHEET_EXCLUDE = {"hip": ("back-action",)}

DATA_JS = os.path.join(REPO, "js", "data.js")
ATLAS_PATH = os.path.join(REPO, "godot", "assets", "athletes", "colosso_texture_0.png")
METAL_PATH = os.path.join(REPO, "godot", "assets", "athletes",
                          "colosso_texture_0_metallic_roughness.png")
GLB_PATH = os.path.join(REPO, "godot", "assets", "athletes", "colosso.glb")
CARD_BASE = os.path.join(REPO, "assets", "athletes", "colosso.webp")
CARD_PREVIEW = os.path.join(REPO, "assets", "outfits", "colosso", "{outfit}-preview.webp")
CARD_MASTER = os.path.join(REPO, "assets", "_archivio", "originali", "outfits", "colosso",
                           "{outfit}-master.png")
MASK_REPORT = os.path.join(REPO, "docs", "agent-work", "outfits-3d", "evidence",
                           "colosso-mask-report.json")
MASK_PATH = os.path.join(REPO, "godot", "assets", "athletes", "outfits", "colosso",
                         "colosso_region_mask.png")

# Sheet contract: (sheet name, base sheet path, base frames, outfit path template, outfit frames)
SHEETS = [
    ("idle", "assets/sprites/colosso-idle-unique.webp", 4,
     "assets/outfits/colosso/{outfit}/idle.webp", 4),
    ("action", "assets/sprites/colosso-action-unique.webp", 4,
     "assets/outfits/colosso/{outfit}/action.webp", 4),
    ("run", "assets/sprites/colosso-run-unique.webp", 8,
     "assets/outfits/colosso/{outfit}/run.webp", 8),
    ("back-idle", "assets/sprites/back/colosso-idle-unique.webp", 4,
     "assets/outfits/colosso/{outfit}/back-idle.webp", 4),
    ("back-action", "assets/sprites/back/colosso-action-unique.webp", 4,
     "assets/outfits/colosso/{outfit}/back-action.webp", 4),
    ("back-run", "assets/sprites/back/colosso-run-unique.webp", 8,
     "assets/outfits/colosso/{outfit}/back-run.webp", 8),
]

# `signature` is the only Colosso variant in this lane's scope. `mythic` needs new
# geometry (sleeved light jersey, belt, front drape) and is deliberately NOT read here.
OUTFITS = ["signature"]


# ---------------------------------------------------------------------------
# io helpers
# ---------------------------------------------------------------------------
def load_frames(path: str, count: int) -> list:
    """Split a horizontal sprite strip into `count` frames by even division.

    The division is checked against the alpha gaps (see frame_gaps) before the numbers
    are trusted; a mismatch is reported, not silently averaged over.
    """
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
    fw = rgba.size[0] // count
    return [rgba.crop((i * fw, 0, (i + 1) * fw, rgba.size[1])) for i in range(count)]


def own_span(alpha: np.ndarray) -> tuple:
    """Column span that belongs to THIS frame's figure, plus the dropped pixels.

    The runtime slices sheets by even division (`js/render.js`: `naturalWidth /
    frameCount`). Where the even boundary does not fall on an alpha gap, a sliver of the
    neighbouring figure lands inside the frame. The sliver is left out of the colour
    measurement and counted here, so the report says how much was dropped.
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
    """Read the reference's own two colours per outfit, and the athlete's visual block,
    out of js/data.js. Machine-read rather than retyped, so the document cannot drift
    from the source."""
    with open(DATA_JS, "r", encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(r"ATHLETE_OUTFITS\s*=\s*\{(.*?)\n\};", text, re.S)
    if not m:
        raise SystemExit("ATHLETE_OUTFITS not found in %s" % DATA_JS)
    block = re.search(r"\n  colosso:\s*\[(.*?)\n  \],", m.group(1), re.S)
    if not block:
        raise SystemExit("colosso entry not found in ATHLETE_OUTFITS")
    out = {}
    for line in block.group(1).splitlines():
        oid = re.search(r'id:\s*"([a-z]+)"', line)
        cols = re.search(r'colors:\s*\["(#[0-9a-fA-F]{6})",\s*"(#[0-9a-fA-F]{6})"\]', line)
        if oid and cols:
            out[oid.group(1)] = [cols.group(1).lower(), cols.group(2).lower()]
    vis = re.search(r'id:\s*"colosso"(.*?)\n  \},', text, re.S)
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
    # The FP flags raised inside BLAS here are spurious (numpy reports them against the
    # matmul, not against any division in this code). Suppressed rather than hidden: the
    # tool asserts the result is finite on the way out, so a real NaN cannot pass.
    with np.errstate(all="ignore"):
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


def hsv1(hexv):
    h, s, v = hsv_of(np.array(rgb_of(hexv), dtype=float).reshape(1, 3))
    return float(h[0]), float(s[0]), float(v[0])


def dhue_deg(a_deg: float, b_deg: float) -> float:
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
    best_n = 0
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
            if len(px) > best_n:
                best_n = len(px)
                best = np.zeros_like(mask)
                for (y, x) in px:
                    best[y, x] = True
    return best


def racket_columns(rgba: np.ndarray, band: tuple) -> tuple:
    """Column block of the racket inside a band, by a declared geometric rule.

    `rgba` is the full frame; the returned mask has the frame's own shape, so it can be
    ANDed with any band selection.

    MEASURED BASIS. The Maestro's racket rule -- the largest gold blob -- does NOT
    transfer to this athlete: measured by `gold_blob_check()` (bright gold = hue 40-62,
    sat > 0.6, val > 200/255), the family is 0.357-1.195 % of the body on the BASE sheets
    and 0.000 % on the signature sheets, and its largest 8-connected blob is 9-241 px
    (241 px on `action` base), which is a shoe sole, not a racket head: Colosso's racket
    head is black and its frame is DARK brass (val 0.3-0.45), not bright gold. The racket
    is therefore found by shape instead:

      * the widest run of opaque pixels per row is the body silhouette;
      * inside the band, columns whose occupancy is >= RACKET_OCC of the band height form
        the body's own column block;
      * ink to the LEFT of that block, separated by a fully transparent column gap of at
        least RACKET_GAP px, is the racket (and the hand holding it).

    Returns (mask, info). The rule is a heuristic and its cost is measured: the hand that
    grips the handle goes with the racket.
    """
    y0, y1 = band
    h_full = rgba.shape[0]
    body = rgba[:, :, 3] > ALPHA_MIN
    h = y1 - y0
    occ = body[y0:y1].sum(axis=0) / max(1, h)
    solid = occ >= RACKET_OCC
    mask = np.zeros((h_full, rgba.shape[1]), dtype=bool)
    # the body's own column block: the longest run of solid columns
    best_a, best_b, a = 0, 0, None
    for x in range(len(solid) + 1):
        if x < len(solid) and solid[x]:
            if a is None:
                a = x
        elif a is not None:
            if x - a > best_b - best_a:
                best_a, best_b = a, x
            a = None
    if best_b - best_a < 8:
        return mask, {"applied": False, "reason": "no body column block found"}
    cols = body[:, :best_a].any(axis=0)
    # walk left from the body block; a transparent gap of >= RACKET_GAP ends the body
    gap = 0
    cut = 0
    for x in range(best_a - 1, -1, -1):
        if not cols[x]:
            gap += 1
            if gap >= RACKET_GAP:
                cut = x + gap
                break
        else:
            gap = 0
    if cut <= 0:
        return mask, {"applied": False, "reason": "no transparent gap left of the body block",
                      "body_block": [int(best_a), int(best_b)]}
    mask[:, :cut] = body[:, :cut]
    return mask, {"applied": True, "cut_column": int(cut),
                  "body_block": [int(best_a), int(best_b)],
                  "px": int(mask.sum())}


def exclusion_masks(rgba: np.ndarray, hair_hex: str) -> dict:
    """skin / hair masks for one frame. Heuristics, all declared at the top.

    skin = the port's declared hue window AND a value floor measured on this athlete
    (SKIN_VAL_MIN); see the module docstring for the numbers behind the floor.
    """
    rgb = rgba[:, :, :3].astype(np.float64)
    hue, sat, val = hsv_of(rgb)
    skin = ((hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN)
            & (val > SKIN_VAL_MIN))
    hair = np.abs(rgb - np.array(rgb_of(hair_hex), dtype=np.float64)).max(axis=2) <= HAIR_TOL
    return {"skin": skin, "hair": hair}


def body_bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def widest_run(row: np.ndarray) -> int:
    """Widest run of True in a 1-D bool row."""
    best = cur = 0
    for v in row:
        if v:
            cur += 1
            best = max(best, cur)
        else:
            cur = 0
    return best


def hem_fraction(frames_alpha: list) -> dict:
    """Where the shorts end: the row where the silhouette's widest run halves.

    Data-driven, not eyeballed. Returns the fraction per frame plus the median.
    """
    fracs = []
    for al in frames_alpha:
        bb = body_bbox(al)
        if bb is None:
            continue
        _, y0, _, y1 = bb
        h = y1 - y0 + 1
        ws = {}
        for f in np.arange(HEM_SCAN[0], HEM_SCAN[1] + 1e-9, 0.02):
            y = min(int(y0 + f * h), y1)
            ws[round(float(f), 2)] = widest_run(al[y] > ALPHA_MIN)
        ks = sorted(ws)
        hem = None
        for i in range(1, len(ks)):
            if ws[ks[i - 1]] > 0 and ws[ks[i]] < 0.62 * ws[ks[i - 1]]:
                hem = ks[i]
                break
        if hem is not None:
            fracs.append(hem)
    if not fracs:
        return {"hem_fraction": None, "per_frame": []}
    return {"hem_fraction": float(np.median(fracs)), "per_frame": [float(x) for x in fracs]}


# ---------------------------------------------------------------------------
# clustering
# ---------------------------------------------------------------------------
def modal_colours(px: np.ndarray, top: int = 8, levels: int = 16):
    """The region's raw modal palette: the `top` most populated RGB bins.

    Reported next to the two families so nothing is hidden by the k=2 split.
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
        h, s, v = hsv_of(members.mean(axis=0).reshape(1, 3))
        out.append({"hex": hex_of(members.mean(axis=0)),
                    "count": int(cnt[i]),
                    "share_pct": round(float(100.0 * cnt[i] / len(px)), 2),
                    "hue_deg": round(float(h[0]), 1),
                    "sat": round(float(s[0]), 3),
                    "val": round(float(v[0]), 3)})
    return out


def kmeans2(px: np.ndarray, iters: int = 100):
    """Deterministic k=2 k-means in RGB.

    Seeded from the data: the two most populated 16-level bins at least 96/255 apart, so
    the result is reproducible byte for byte and cannot land on two near-identical centres
    (which would split one garment colour in half and report it as two families).

    Each cluster reports BOTH a mean and a mode. The mean is the average of the shaded
    pixels (shadows included, so it reads lighter/greyer than the paint on the fabric);
    the mode is the single most populated bin of the cluster, i.e. the flat colour an
    artist would name. The document uses the mode as the slot value and keeps the mean
    for the audit trail.
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
    for it in range(iters):
        d = np.linalg.norm(px[:, None, :] - c[None, :, :], axis=2)
        new = d.argmin(axis=1)
        if np.array_equal(new, labels) and it > 0:
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


def fam_of(palette: dict, outfit: str, region: str, family: str):
    """The (region, family) cluster of an outfit, or None."""
    e = (palette.get(outfit) or {}).get(region)
    if not e or not e["clusters"]:
        return None
    for c in e["clusters"]:
        if c["family"] == family:
            return c
    return e["clusters"][0]


# ---------------------------------------------------------------------------
# measurement
# ---------------------------------------------------------------------------
def collect(band, excl: dict, alpha: np.ndarray):
    """Return the selection mask of one band: inside the band, opaque, not excluded."""
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


def atlas_inventory() -> dict:
    """Inventory of the BAKED atlas the rig actually renders, read-only.

    NOT the mask and NOT the anchors: the anchors must be measured *inside* the mask by a
    mask tool, which does not exist for Colosso. This inventory is here only so the
    document can say honestly which recolourable colour families the model has at all --
    and it is the reason the six slots cannot be checked against the atlas from here.

    There is deliberately no image write: the tool never writes an asset.
    """
    if not os.path.exists(ATLAS_PATH):
        return {"error": "atlas not found: %s" % os.path.relpath(ATLAS_PATH, REPO)}
    with Image.open(ATLAS_PATH) as im:
        a = np.asarray(im.convert("RGB")).astype(np.float64)
    tot = a.shape[0] * a.shape[1]
    hue, sat, val = hsv_of(a)
    out = {"path": os.path.relpath(ATLAS_PATH, REPO),
           "size": [int(a.shape[1]), int(a.shape[0])], "total_px": int(tot),
           "sha256_prefix": hashlib.sha256(
               open(ATLAS_PATH, "rb").read()).hexdigest()[:16],
           "classes": {}, "notes": []}
    for name, sel in (
            ("dark_val_lt_030", val < 0.30),
            ("mid_val_030_060", (val >= 0.30) & (val < 0.60)),
            ("bright_val_ge_060", val >= 0.60),
            ("sat_gt_025", sat > SHADER_SAT_MIN_DEFAULT),
            ("sat_gt_018", sat > 0.18),
            ("sat_le_025", sat <= SHADER_SAT_MIN_DEFAULT)):
        px = a[sel]
        med = np.median(px, axis=0) if len(px) else np.zeros(3)
        hh, ss, vv = hsv_of(med.reshape(1, 3))
        out["classes"][name] = {"pixels": int(sel.sum()),
                                "share_pct": round(float(100.0 * sel.sum() / tot), 1),
                                "median_hex": hex_of(med),
                                "median_hue_deg": round(float(hh[0]), 1),
                                "median_sat": round(float(ss[0]), 3),
                                "median_val": round(float(vv[0]), 3)}
    # the saturated hue bands: "is there a second recolourable hue?" as a number
    sel = (sat > SHADER_SAT_MIN_DEFAULT) & (val > SHADER_VAL_MIN)
    hist, _ = np.histogram(hue[sel], bins=12, range=(0, 360))
    out["saturated_hue_bands_pct"] = {("%d-%d" % (i * 30, i * 30 + 30)):
                                      round(float(100.0 * h / max(1, hist.sum())), 1)
                                      for i, h in enumerate(hist)}
    out["saturated_share_pct"] = round(float(100.0 * sel.sum() / tot), 1)
    # the dark (leather-like) mass: its modes, and how much of it the shader's family
    # test would accept at sat_min
    dk = val < 0.30
    if dk.sum() >= 32:
        px = a[dk]
        q = (px // 8).astype(np.int32)
        keys = q[:, 0] * 1000000 + q[:, 1] * 1000 + q[:, 2]
        u, cnt = np.unique(keys, return_counts=True)
        order = np.argsort(-cnt)[:6]
        out["dark_modes"] = []
        for i in order:
            m = np.array([(u[i] // 1000000) * 8 + 4, ((u[i] // 1000) % 1000) * 8 + 4,
                          (u[i] % 1000) * 8 + 4], dtype=float)
            hh, ss, vv = hsv_of(m.reshape(1, 3))
            out["dark_modes"].append({"hex": hex_of(m),
                                      "share_pct": round(float(100.0 * cnt[i] / dk.sum()), 2),
                                      "hue_deg": round(float(hh[0]), 1),
                                      "sat": round(float(ss[0]), 3),
                                      "val": round(float(vv[0]), 3)})
    out["dark_texels_passing_family_test"] = {}
    for sm in (0.18, SHADER_SAT_MIN_DEFAULT):
        ok = dk & (sat > sm) & (val > SHADER_VAL_MIN)
        out["dark_texels_passing_family_test"]["sat_min_%.2f" % sm] = {
            "pixels": int(ok.sum()),
            "pct_of_dark": round(float(100.0 * ok.sum() / max(1, dk.sum())), 1),
            "pct_of_atlas": round(float(100.0 * ok.sum() / tot), 1)}
    # value structure of the saturated warm mass: is there a density discontinuity a
    # value gate could sit on?
    warm = (sat > SHADER_SAT_MIN_DEFAULT) & (val > SHADER_VAL_MIN) & (hue < 70)
    if warm.sum() >= 32:
        v = val[warm]
        hist, edges = np.histogram(v, bins=20, range=(0, 1))
        out["warm_value_histogram"] = [
            {"lo": round(float(edges[i]), 2), "hi": round(float(edges[i + 1]), 2),
             "pixels": int(hist[i]), "share_pct": round(float(100.0 * hist[i] / warm.sum()), 2)}
            for i in range(len(hist))]
        jumps = []
        for i in range(1, len(hist)):
            if hist[i - 1] > 0 and hist[i] / hist[i - 1] > 1.3:
                jumps.append({"at_value": round(float(edges[i]), 2),
                              "ratio": round(float(hist[i] / hist[i - 1]), 2)})
        out["warm_value_jumps"] = jumps
    out["notes"].append(
        "the atlas has ONE saturated hue family: the saturated bands are 0-30 deg and "
        "30-60 deg and there is nothing else above 1%%. Skin, the brass trim and the "
        "emissive orange all live in that band, so a hue-based family test cannot "
        "separate two garment families on this athlete the way it does on Fiamma.")
    out["notes"].append(
        "the dark leather mass is largely BELOW the shader's sat_min: only the share "
        "reported in dark_texels_passing_family_test survives the family test, so the "
        "`a` slots of a profile anchored on that leather risk being inert.")
    return out


def metal_map_inventory() -> dict:
    """glTF ORM map inventory (read-only): is the metal trim a usable region signal?

    Colosso's outfit is described as dark leather + metal. The ORM texture's blue channel
    is metallic, green is roughness. If the metal is concentrated on the garment trim, it
    is a potential region signal for a mask lane; this block only states whether it is
    concentrated at all, and on what.
    """
    if not os.path.exists(METAL_PATH):
        return {"error": "not found: %s" % os.path.relpath(METAL_PATH, REPO)}
    with Image.open(METAL_PATH) as im:
        b = np.asarray(im.convert("RGB")).astype(np.float64)
    met = b[:, :, 2] / 255.0
    rough = b[:, :, 1] / 255.0
    tot = met.size
    out = {"path": os.path.relpath(METAL_PATH, REPO),
           "size": [int(b.shape[1]), int(b.shape[0])],
           "channel_means_255": {"R_occlusion": round(float(b[:, :, 0].mean()), 1),
                                 "G_roughness": round(float(b[:, :, 1].mean()), 1),
                                 "B_metallic": round(float(b[:, :, 2].mean()), 1)},
           "metallic": {t: round(float(100.0 * (met > t).mean()), 1) for t in (0.3, 0.5, 0.7)},
           "roughness": {t: round(float(100.0 * (rough > t).mean()), 1) for t in (0.3, 0.5, 0.7)},
           "note": ("read-only inventory; it does not enter any slot value. The map is a "
                    "different resolution from the colour atlas, so it cannot be indexed "
                    "against it here without a resample, which this tool refuses to do "
                    "silently.")}
    return out


def glb_texture_check() -> dict:
    """Is the atlas PNG the texture inside the shipped GLB? Read-only, no extraction."""
    if not os.path.exists(GLB_PATH):
        return {"error": "not found: %s" % os.path.relpath(GLB_PATH, REPO)}
    import struct
    raw = open(GLB_PATH, "rb").read()
    off, js, binchunk = 12, None, None
    while off + 8 <= len(raw):
        ln, typ = struct.unpack_from("<II", raw, off)
        chunk = raw[off + 8:off + 8 + ln]
        if typ == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif typ == 0x004E4942:
            binchunk = chunk
        off += 8 + ln
    if js is None:
        return {"error": "no JSON chunk in %s" % os.path.relpath(GLB_PATH, REPO)}
    out = {"path": os.path.relpath(GLB_PATH, REPO), "size_bytes": len(raw),
           "images": []}
    bvs = js.get("bufferViews", [])
    for i in js.get("images", []):
        rec = {"name": i.get("name"), "mimeType": i.get("mimeType")}
        if "bufferView" in i and binchunk is not None:
            bv = bvs[i["bufferView"]]
            data = binchunk[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
            rec["byteLength"] = len(data)
            rec["sha256_prefix"] = hashlib.sha256(data).hexdigest()[:16]
        out["images"].append(rec)
    if os.path.exists(ATLAS_PATH):
        out["atlas_png_sha256_prefix"] = hashlib.sha256(
            open(ATLAS_PATH, "rb").read()).hexdigest()[:16]
        out["note"] = ("the GLB's embedded images are compared by sha256 prefix with the "
                       "shipped colosso_texture_0.png: a match means the atlas measured "
                       "above is the one the rig renders.")
    return out


def card_check() -> dict:
    """How far each illustrated card is from the base card, read-only.

    The cards are ILLUSTRATIONS, not UV textures, and the port's reference is the in-field
    sprite. This block exists so the divergence is a measured number instead of an
    opinion. `signature-master.png` and `assets/athletes/colosso.webp` are BOTH 1024x1536,
    so that pair is compared at native resolution with NO resampling -- an exact number.
    The 560x747 preview is not the same resolution as anything else, so its comparison is
    marked approximate.
    """
    if not os.path.exists(CARD_BASE):
        return {"error": "base card not found: %s" % os.path.relpath(CARD_BASE, REPO)}
    with Image.open(CARD_BASE) as im:
        base = im.convert("RGB")
    out = {"base_card": os.path.relpath(CARD_BASE, REPO),
           "base_card_size": [int(base.size[0]), int(base.size[1])], "per_outfit": {}}
    for o in OUTFITS:
        entry = {}
        master = CARD_MASTER.format(outfit=o)
        if os.path.exists(master):
            with Image.open(master) as im:
                m = im.convert("RGB")
            entry["master_path"] = os.path.relpath(master, REPO)
            entry["master_size"] = [int(m.size[0]), int(m.size[1])]
            if m.size == base.size:
                a = np.asarray(base).astype(np.int16)
                b = np.asarray(m).astype(np.int16)
                d = np.abs(a - b).max(axis=2)
                entry["vs_base_card_exact"] = {
                    "resampled": False,
                    "pct_pixels_over_16_255": round(float(100.0 * (d > 16).mean()), 1),
                    "pct_pixels_over_48_255": round(float(100.0 * (d > 48).mean()), 1),
                    "mean_abs_255": round(float(d.mean()), 1)}
            else:
                entry["vs_base_card_exact"] = {"resampled": False, "error": "size mismatch"}
        preview = CARD_PREVIEW.format(outfit=o)
        if os.path.exists(preview):
            with Image.open(preview) as im:
                card = im.convert("RGB")
            b = base.resize(card.size, Image.LANCZOS)
            aa = np.asarray(b).astype(np.int16)
            bb_ = np.asarray(card).astype(np.int16)
            d = np.abs(aa - bb_).max(axis=2)
            entry["preview_path"] = os.path.relpath(preview, REPO)
            entry["preview_size"] = [int(card.size[0]), int(card.size[1])]
            entry["vs_base_card_preview_APPROXIMATE"] = {
                "resampled": True,
                "pct_pixels_over_16_255": round(float(100.0 * (d > 16).mean()), 1),
                "mean_abs_255": round(float(d.mean()), 1)}
        out["per_outfit"][o] = entry
    out["note"] = ("a card that differs from the base card over most of its area is a "
                   "different illustration, not a recolour; the in-field sprite is the "
                   "reference for this document. Resampled numbers are labelled as such: "
                   "comparing two different resolutions produces a percentage that is "
                   "mostly a resampling artefact and is not quoted as a result.")
    return out


def mask_lane_cross_check() -> dict:
    """Read-only cross-check against the region-mask lane's own report, if it exists.

    No Colosso mask exists in the tree at the time of writing. Absence is reported, not
    invented: without a mask there are no anchors, no sha256 and no coverage, and the six
    slots cannot be checked against the atlas from here.
    """
    out = {"report": os.path.relpath(MASK_REPORT, REPO),
           "mask": os.path.relpath(MASK_PATH, REPO)}
    out["report_present"] = os.path.exists(MASK_REPORT)
    out["mask_present"] = os.path.exists(MASK_PATH)
    if out["mask_present"]:
        with open(MASK_PATH, "rb") as fh:
            out["mask_sha256_prefix_live"] = hashlib.sha256(fh.read()).hexdigest()[:16]
    if out["report_present"]:
        with open(MASK_REPORT) as fh:
            rep = json.load(fh)
        out["tool"] = rep.get("tool")
        out["family_anchors"] = rep.get("family_anchors")
        out["coverage_fraction"] = rep.get("coverage_fraction")
    else:
        out["note"] = ("no Colosso region-mask report in the tree: the profile's mask "
                       "path, anchors and sha256 prefix cannot be quoted and must stay "
                       "TODO. The atlas inventory in this report is NOT a substitute for "
                       "anchors measured inside the mask.")
    return out


def shader_family_weight(cur: np.ndarray, anchor, hue_tol: float, sat_min: float,
                         val_min: float, band=None, feather: float = 0.05) -> np.ndarray:
    """A faithful re-implementation of `family_weight()` from
    godot/src/character/outfit_region_recolour.gdshader (read-only).

    `cur` is (N, 3) sRGB 0-255; `anchor` is a 3-tuple sRGB 0-255. Returns the weight
    in [0, 1] the shader would compute for each texel. Kept in step with the shader
    by hand, so the constants it is called with are quoted in the report next to the
    result: a drifted constant must be visible, not silent.
    """
    def ss(x):
        x = np.clip(x, 0.0, 1.0)
        return x * x * (3.0 - 2.0 * x)

    def smoothstep(e0, e1, x):
        t = np.clip((x - e0) / max(e1 - e0, 1e-9), 0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)

    hue, sat, val = hsv_of(cur)
    ah, as_, av = hsv_of(np.asarray(anchor, dtype=np.float64).reshape(1, 3))
    dh = np.abs(np.mod(hue - ah[0] + 180.0, 360.0) - 180.0)
    w = 1.0 - smoothstep(hue_tol * 0.55, hue_tol, dh)
    w = w * ss((sat - sat_min) / 0.12)
    w = w * ss((val - val_min) / 0.12)
    if band is not None:
        lo = smoothstep(band[0] - feather, band[0], val)
        hi = 1.0 - smoothstep(band[1], band[1] + feather, val)
        w = w * lo * hi
    return w


def atlas_family_split_in_mask() -> dict:
    """Run the shader's own family test on the BAKED atlas, inside the region mask.

    THIS IS THE DECISIVE INERTNESS MEASUREMENT. The shader does not test the target
    colour: it tests the baked atlas texel against the anchor, inside the mask, and
    only then mixes the target in. So "is this slot inert" is answered by counting,
    per region and per anchor, how many masked atlas texels the family test accepts.

    Read-only: the atlas, the mask and the mask lane's anchors are all read, nothing
    is written. Both the shader's own constants and the catalogue's MASK_DEFAULTS are
    evaluated, because they disagree (0.25/0.06/42 vs 0.18/0.02/45).
    """
    out = {"atlas": os.path.relpath(ATLAS_PATH, REPO),
           "mask": os.path.relpath(MASK_PATH, REPO), "anchors_source": None}
    if not os.path.exists(ATLAS_PATH):
        return {"error": "atlas not found"}
    if not os.path.exists(MASK_PATH):
        return {"error": "mask not found: %s" % os.path.relpath(MASK_PATH, REPO)}
    with Image.open(ATLAS_PATH) as im:
        atlas = np.asarray(im.convert("RGB"))
    with Image.open(MASK_PATH) as im:
        mask = np.asarray(im.convert("RGBA")).astype(np.float64) / 255.0
    if atlas.shape[:2] != mask.shape[:2]:
        return {"error": "atlas %s and mask %s are different sizes; not resampled, "
                         "because resampling one would fabricate the overlap"
                         % (atlas.shape[:2], mask.shape[:2])}
    out["atlas_size"] = [int(atlas.shape[1]), int(atlas.shape[0])]
    if not os.path.exists(MASK_REPORT):
        return {"error": "no mask report, so no anchors to test"}
    with open(MASK_REPORT) as fh:
        rep = json.load(fh)
    out["anchors_source"] = os.path.relpath(MASK_REPORT, REPO)
    fams = rep.get("family_anchors") or {}
    split = rep.get("value_split")
    windows = rep.get("family_windows") or {}
    out["anchors_measured_by_mask_lane"] = fams
    out["value_split"] = split
    out["family_windows"] = windows
    if len(fams) < 2 or split is None:
        return {"error": "mask report has no two anchors / no value_split"}

    names = sorted(fams.keys())              # leather, light
    px = atlas.reshape(-1, 3).astype(np.float64)
    flat_region = {"torso": mask[:, :, 0], "hip": mask[:, :, 1], "foot": mask[:, :, 2]}
    out["coverage_texels_ge128"] = {r: int((v >= 0.5).sum()) for r, v in flat_region.items()}
    out["mask_sha256_prefix_live"] = hashlib.sha256(open(MASK_PATH, "rb").read()).hexdigest()[:16]
    out["mask_sha256_prefix_in_report"] = rep.get("mask_sha256_prefix") or rep.get("mask_sha256")

    settings = {
        "shader_defaults": (SHADER_HUE_TOL_DEG, SHADER_SAT_MIN_DEFAULT, SHADER_VAL_MIN),
        "catalogue_mask_defaults_EFFECTIVE": (CATALOGUE_HUE_TOL_DEG, CATALOGUE_SAT_MIN,
                                              CATALOGUE_VAL_MIN),
    }
    out["per_setting"] = {}
    for sname, (ht, sm, vm) in settings.items():
        res = {"hue_tol_deg": ht, "sat_min": sm, "val_min": vm, "regions": {}}
        for region, rm in flat_region.items():
            inside = (rm >= 0.5).reshape(-1)
            n = int(inside.sum())
            if n == 0:
                res["regions"][region] = {"masked_texels": 0}
                continue
            sub = px[inside]
            # gate OFF: the shipped behaviour, both anchors tested on hue/sat/val only
            w_off = {k: shader_family_weight(sub, rgb_of(fams[k]["hex"]), ht, sm, vm)
                     for k in names}
            accepted_off = {k: w_off[k] > 0.5 for k in names}
            both_off = int((accepted_off[names[0]] & accepted_off[names[1]]).sum())
            entry = {"masked_texels": n, "gate_off": {
                "accepted_per_anchor": {k: int(accepted_off[k].sum()) for k in names},
                "accepted_pct_per_anchor": {k: round(100.0 * accepted_off[k].mean(), 1)
                                            for k in names},
                "accepted_by_BOTH_anchors": both_off,
                "accepted_by_BOTH_pct": round(100.0 * both_off / n, 1),
                "hue_deg_between_anchors": round(dhue_deg(
                    hsv1(fams[names[0]]["hex"])[0], hsv1(fams[names[1]]["hex"])[0]), 1),
            }}
            # gate ON, with the split the mask lane measured
            band_of = {}
            for k in names:
                win = (windows.get(k) or {}).get("value")
                band_of[k] = tuple(win) if win else None
            if all(band_of[k] is not None for k in names):
                w_on = {k: shader_family_weight(sub, rgb_of(fams[k]["hex"]), ht, sm, vm,
                                                band=band_of[k])
                        for k in names}
                acc_on = {k: w_on[k] > 0.5 for k in names}
                both_on = int((acc_on[names[0]] & acc_on[names[1]]).sum())
                orphan = int((~acc_on[names[0]] & ~acc_on[names[1]]).sum())
                entry["gate_on_with_mask_lane_bands"] = {
                    "bands": {k: list(band_of[k]) for k in names},
                    "accepted_per_anchor": {k: int(acc_on[k].sum()) for k in names},
                    "accepted_pct_per_anchor": {k: round(100.0 * acc_on[k].mean(), 1)
                                                for k in names},
                    "accepted_by_BOTH_anchors": both_on,
                    "accepted_by_NEITHER_orphans": orphan,
                }
            res["regions"][region] = entry
        out["per_setting"][sname] = res
    out["note"] = (
        "the family test is run on the BAKED ATLAS TEXEL, not on the target colour, so a "
        "target that is dark or desaturated is NOT inert: the shader still recolours the "
        "texel. What makes a slot inert is the ANCHOR failing the test, and what makes a "
        "recolour invisible is the TARGET sitting on top of its own baked anchor "
        "(see target_vs_baked_anchor).")

    # CROSS-CHECK against the mask lane's own figure. It reports "1048218 of 1421791
    # masked texels answer to both anchors". That is a PURE HUE-WINDOW count (no sat/val
    # ramp), and reproducing it here validates this re-implementation of the shader's
    # family test: the same criterion on the mask revision this tool read gives a number
    # within a fraction of a percent. The shader's actual ramps then cut it much further,
    # which is the number that matters for the render.
    h_all, s_all, v_all = hsv_of(px)
    a0 = hsv1(fams[names[0]]["hex"])[0]
    a1 = hsv1(fams[names[1]]["hex"])[0]
    dh0 = np.abs(np.mod(h_all - a0 + 180.0, 360.0) - 180.0)
    dh1 = np.abs(np.mod(h_all - a1 + 180.0, 360.0) - 180.0)
    # the union of the three regions: `px` above is the WHOLE atlas, and the per-region
    # loop works on `sub`; the cross-check must be over the mask, not over the atlas.
    union = ((flat_region["torso"] >= 0.5) | (flat_region["hip"] >= 0.5)
             | (flat_region["foot"] >= 0.5)).reshape(-1)
    both_window = ((dh0 <= CATALOGUE_HUE_TOL_DEG) & (dh1 <= CATALOGUE_HUE_TOL_DEG)
                   & union)
    both_window_ramped = both_window & (s_all > CATALOGUE_SAT_MIN) \
        & (v_all > CATALOGUE_VAL_MIN) & (v_all < 0.98)
    n_union = int(union.sum())
    out["cross_check_mask_lane_hue_window"] = {
        "masked_texels_here": n_union,
        "hue_window_dh_le_tol_BOTH": int(both_window.sum()),
        "hue_window_dh_le_tol_BOTH_pct": round(100.0 * both_window.sum() / n_union, 1),
        "same_plus_sat_val_ramps_BOTH": int(both_window_ramped.sum()),
        "same_plus_sat_val_ramps_BOTH_pct": round(
            100.0 * both_window_ramped.sum() / n_union, 1),
        "mask_lane_reported_BOTH": 1048218,
        "mask_lane_reported_masked_texels": 1421791,
        "note": ("the mask lane's figure is a pure hue-window count and this reproduction "
                 "agrees with it to within about a percent; the shader's smoothstep ramps "
                 "reject a further ~25 points of that set, and THAT is the count the render "
                 "actually sees. The residual difference is the mask revision: this tool "
                 "reads whatever mask is on disk when it runs."),
    }
    return out


def target_vs_baked_anchor(slots: dict) -> dict:
    """For every proposed slot, the dE76 to the baked anchor of the family it repaints.

    A target within a few dE76 of the anchor it replaces produces a recolour nobody
    can see, even though the shader applied it perfectly. This is the second, and on
    this athlete the real, inertness mode.
    """
    out = {"per_slot": {}, "thresholds": {"invisible_de76": INVISIBLE_DE76,
                                          "subtle_de76": SUBTLY_DE76}}
    if not os.path.exists(MASK_REPORT):
        return {"error": "no mask report, so no anchors"}
    with open(MASK_REPORT) as fh:
        rep = json.load(fh)
    fams = rep.get("family_anchors") or {}
    if len(fams) < 2:
        return {"error": "mask report has no two anchors"}
    names = sorted(fams.keys())
    out["anchors"] = {k: fams[k]["hex"] for k in names}
    for o, recs in slots.items():
        for key, rec in recs.items():
            tgt = rgb_of(rec["hex"])
            per = {}
            for k in names:
                d = de76(tgt, rgb_of(fams[k]["hex"]))
                per[k] = {"de76": round(d, 1),
                          "verdict": ("INVISIBLE" if d <= INVISIBLE_DE76 else
                                      "subtle" if d <= SUBTLY_DE76 else "visible")}
            out["per_slot"]["%s.%s" % (o, key)] = {"hex": rec["hex"], "vs_anchor": per}
    return out


def region_change_delta() -> dict:
    """Per region, which colour CLASSES change between base and the outfit.

    SCALE-INVARIANT: every number is a share of the region's own opaque pixels, so the
    two resolutions never have to be resampled and no percentage here is a false one.
    This is the measurement that answers "which regions actually change", which the
    modal palette alone cannot, because on this athlete the modes are dominated by the
    neutral shading that both outfits share.
    """
    def classes(px):
        h, s, v = hsv_of(px)
        return {
            "skin_de76_le20_from_declared": None,   # filled by caller, needs lab
            "bright_yellow_h35_65_s_gt_40_v_gt_45": ((h >= 35) & (h <= 65) & (s > 0.40)
                                                     & (v > 0.45)),
            "orange_emissive_h5_40_s_gt_60_v_gt_80": ((h >= 5) & (h <= 40) & (s > 0.60)
                                                      & (v > 0.80)),
            "gold_h35_60_s_gt_40_v_30_70": ((h >= 35) & (h <= 60) & (s > 0.40)
                                            & (v > 0.30) & (v <= 0.70)),
            "dark_v_lt_25": v < 0.25,
            "neutral_s_le_15": s <= 0.15,
            "warm_brown_h9_38_s_gt_30_v_le_50": ((h >= 9) & (h <= 38) & (s > 0.30)
                                                 & (v <= 0.50)),
            "white_v_gt_85_s_lt_15": (v > 0.85) & (s < 0.15),
        }

    src = declared_source()
    skin_hex = src.get("_visual", {}).get("skin", "#b06a3f")
    lab_skin = srgb_to_lab(np.array(rgb_of(skin_hex), dtype=np.float64))
    out = {"skin_reference": skin_hex, "per_region": {},
           "note": ("shares of the region's own opaque pixels (alpha > %d); the two "
                    "sheets are different resolutions and are NEVER resampled against "
                    "each other here." % ALPHA_MIN)}
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit=OUTFITS[0]), oframes)):
            for fr in load_frames(os.path.join(REPO, path), count):
                rgba = np.asarray(fr).astype(np.int16)
                c0, c1, _ = own_span(rgba[:, :, 3])
                bands = per_frame_bands(rgba[:, :, 3][:, c0:c1])
                if bands is None:
                    continue
                al = rgba[:, :, 3][:, c0:c1] > ALPHA_MIN
                rows = np.arange(al.shape[0])[:, None]
                for region in BANDS:
                    b0, b1, _ = bands[region]
                    sel = (rows >= int(b0)) & (rows < int(b1)) & al
                    px = rgba[:, c0:c1, :3][sel].astype(np.float64)
                    if len(px) < 30:
                        continue
                    cl = classes(px)
                    dsk = np.sqrt(((srgb_to_lab(px) - lab_skin) ** 2).sum(axis=-1))
                    cl["skin_de76_le20_from_declared"] = dsk <= 20
                    ent = out["per_region"].setdefault(
                        region, {}).setdefault(label, {"px": 0, "classes": {}})
                    ent["px"] += int(len(px))
                    for k, m in cl.items():
                        e = ent["classes"].setdefault(k, {"px": 0})
                        e["px"] += int(m.sum())
    for region, per in out["per_region"].items():
        base_px = (per.get("base") or {}).get("px", 0)
        sig_px = (per.get("outfit") or {}).get("px", 0)
        for label, tot in (("base", base_px), ("outfit", sig_px)):
            if not tot:
                continue
            for k, e in per[label]["classes"].items():
                e["pct"] = round(100.0 * e["px"] / tot, 1)
        delta = {}
        for k in (per.get("base") or {}).get("classes", {}):
            b = per["base"]["classes"][k].get("pct", 0.0)
            s = (per.get("outfit") or {}).get("classes", {}).get(k, {}).get("pct", 0.0)
            delta[k] = round(s - b, 1)
        per["delta_outfit_minus_base_pct"] = delta
    return out


def gold_blob_check() -> dict:
    """Verify, per sheet, the claim the racket rule rests on: that Colosso's bright-gold
    family is tiny and that its largest blob cannot be a racket head.

    Read-only and purely evidential. If this ever comes back with a large blob, the
    geometric racket rule must be revisited.
    """
    out = {"per_sheet": [], "note": (
        "the Maestro's racket rule (largest bright-gold blob) is only usable if the blob "
        "is actually the racket. On Colosso the racket head is black and its frame is dark "
        "brass, so the bright-gold family is expected to be near-empty; this is the "
        "measurement behind that expectation, and it is why racket_columns() is geometric.")}
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit=OUTFITS[0]), oframes)):
            fr = load_frames(os.path.join(REPO, path), count)
            body_px, gold_px, biggest = 0, 0, 0
            for f in fr:
                a = np.asarray(f).astype(np.int16)
                al = a[:, :, 3] > ALPHA_MIN
                rgb = a[:, :, :3].astype(np.float64)
                h, s, v = hsv_of(rgb)
                gold = al & (h >= 40) & (h <= 62) & (s > 0.6) & (v > 200.0 / 255.0)
                body_px += int(al.sum())
                gold_px += int(gold.sum())
                if gold.sum():
                    biggest = max(biggest, int(largest_component(gold).sum()))
            out["per_sheet"].append({
                "sheet": name, "which": label, "body_px": body_px, "gold_px": gold_px,
                "gold_pct_of_body": (round(100.0 * gold_px / body_px, 3) if body_px else None),
                "largest_gold_blob_px": biggest})
    return out


def measure(out_dir: str, write_evidence: bool) -> dict:
    src = declared_source()
    hair_hex = src.get("_visual", {}).get("hair", "#1c130d")
    skin_hex = src.get("_visual", {}).get("skin", "#b06a3f")

    # --- grid check ---------------------------------------------------------
    grid = []
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit=OUTFITS[0]), oframes)):
            full = os.path.join(REPO, path)
            with Image.open(full) as im:
                size = im.size
            fw = size[0] / count
            gaps = frame_gaps(full)
            devs = []
            if gaps:
                for i in range(count - 1):
                    b = (i + 1) * fw
                    d = min(min(abs(b - a), abs(b - bb)) if not (a <= b <= bb) else 0.0
                            for a, bb in gaps)
                    devs.append(round(d, 1))
            grid.append({"sheet": name, "which": label, "path": path, "size": list(size),
                         "frames": count, "frame_w": round(fw, 2),
                         "gaps": [list(g) for g in gaps],
                         "boundary_deviation_px": devs,
                         "boundary_on_gap": bool(devs) and max(devs) == 0.0})

    # --- hem detection ------------------------------------------------------
    hem = {}
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit=OUTFITS[0]), oframes)):
            fr = load_frames(os.path.join(REPO, path), count)
            alphas = []
            for f in fr:
                a = np.asarray(f)[:, :, 3]
                c0, c1, _ = own_span(a)
                alphas.append(a[:, c0:c1])
            hem.setdefault(name, {})[label] = hem_fraction(alphas)

    # --- base palette and per-outfit pixels ---------------------------------
    pools = {}        # (outfit, region) -> list of arrays, pooled over the usable sheets
    per_sheet = {}    # (sheet, outfit, region) -> array, kept as evidence
    no_racket = {}    # (outfit, region) -> list of arrays, racket NOT removed
    bleed = []        # what own_span() dropped, per sheet/frame
    racket_log = []
    skin_log = []
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
                    rk, rk_info = racket_columns(rgba[:, c0:c1], (int(b0), int(b1)))
                    if rk_info.get("applied"):
                        racket_log.append({"sheet": name, "outfit": o, "frame": fi,
                                           "region": region, **rk_info})
                    sel = collect((b0, b1), excl, alpha)[:, c0:c1]
                    sel_nr = sel.copy()
                    if rk_info.get("applied"):
                        sel = sel & ~rk
                    px = rgba[:, c0:c1, :3][sel].astype(np.float64)
                    px_nr = rgba[:, c0:c1, :3][sel_nr].astype(np.float64)
                    if len(px) == 0:
                        continue
                    per_sheet.setdefault((name, o, region), []).append(px)
                    no_racket.setdefault((o, region), []).append(px_nr)
                    if name not in BAND_SHEET_EXCLUDE.get(region, ()):
                        pools.setdefault((o, region), []).append(px)
                    # residual skin left in the pool: pixels within dE76 12 of the
                    # declared skin colour that survived the exclusion
                    if len(px):
                        dsk = np.sqrt(((srgb_to_lab(px) - srgb_to_lab(
                            np.array(rgb_of(skin_hex), dtype=np.float64))) ** 2).sum(axis=-1))
                        skin_log.append({"sheet": name, "outfit": o, "region": region,
                                         "frame": fi, "pool_px": int(len(px)),
                                         "residual_skin_px": int((dsk <= 12).sum()),
                                         "residual_skin_pct": round(
                                             float(100.0 * (dsk <= 12).mean()), 2)})

    # --- per (outfit, region) clusters -------------------------------------
    palette = {}
    for (o, region), chunks in sorted(pools.items()):
        px = np.concatenate(chunks, axis=0)
        clusters = kmeans2(px)
        entry = {"pixels": int(len(px)), "modes": modal_colours(px), "clusters": []}
        for k, cl in enumerate(clusters):
            rgb = cl["rgb"]
            m_rgb = cl.get("mode_rgb", rgb)
            hue, sat, val = hsv_of(np.asarray(m_rgb, dtype=float).reshape(1, 3))
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

    # --- the same measurement WITHOUT the racket exclusion, as a cross-check -
    palette_no_racket = {}
    for (o, region), chunks in sorted(no_racket.items()):
        px = np.concatenate(chunks, axis=0)
        clusters = kmeans2(px)
        palette_no_racket.setdefault(o, {})[region] = {
            "pixels": int(len(px)),
            "clusters": [{"family": "ab"[k] if len(clusters) == 2 else "a",
                          "mode_hex": hex_of(c.get("mode_rgb", c["rgb"])),
                          "share_pct": round(float(100.0 * c["count"] / len(px)), 1)}
                         for k, c in enumerate(clusters)],
        }

    # --- the same measurement per sheet, as cross-check evidence ------------
    per_sheet_palette = {}
    for (sheet, o, region), chunks in sorted(per_sheet.items()):
        px = np.concatenate(chunks, axis=0)
        clusters = kmeans2(px)
        per_sheet_palette.setdefault(sheet, {}).setdefault(o, {})[region] = {
            "pixels": int(len(px)),
            "modes": modal_colours(px, top=3),
            "clusters": [{"family": "ab"[k] if len(clusters) == 2 else "a",
                          "mode_hex": hex_of(c.get("mode_rgb", c["rgb"])),
                          "share_pct": round(float(100.0 * c["count"] / len(px)), 1)}
                         for k, c in enumerate(clusters)],
        }

    # --- changed-pixel comparison against the base -------------------------
    # The base sheets and the outfit sheets are DIFFERENT resolutions (298 px per frame
    # against 179 on the four-frame sheets, 238 against 143 on `run`), so any pixel
    # comparison has to resample one of them and the result is APPROXIMATE. It is
    # reported with that flag and is never quoted as an exact change figure.
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
                row = {"sheet": name, "outfit": o, "frame": fi, "APPROXIMATE": True,
                       "reason": "base frame %s resampled to outfit frame %s"
                                 % (base_frames[fi].size, on.size),
                       "body_px": int(alpha.sum()), "changed_px": int(ch.sum()),
                       "changed_pct_of_body": round(100.0 * ch.sum() / max(1, alpha.sum()), 2),
                       "changed_pct_of_frame": round(100.0 * ch.sum() / (w * h), 2)}
                bands = per_frame_bands(np.asarray(on)[:, :, 3])
                if bands:
                    for region, (b0, b1, _bb) in bands.items():
                        rows = np.arange(h)[:, None]
                        bs = alpha & (rows >= b0) & (rows < b1)
                        row["changed_pct_" + region] = round(
                            100.0 * (ch & bs).sum() / max(1, bs.sum()), 2)
                changes.append(row)

    # --- base vs signature, SCALE-INVARIANT cross-check --------------------
    # The two sprites are different resolutions, so instead of pixels this compares the
    # things that do not depend on scale: the modal palette of each region and the share
    # of each family. A recolour moves those; a resample does not.
    base_vs_signature = {"per_region": {}, "note": (
        "modal palettes and family shares are scale-invariant, so this comparison is "
        "valid across the two resolutions; the pixel-change table above is not.")}
    for region in list(BANDS):
        b = palette.get("base", {}).get(region)
        s = palette.get(OUTFITS[0], {}).get(region)
        if not b or not s:
            continue
        bm = {m["hex"]: m["share_pct"] for m in b["modes"]}
        sm = {m["hex"]: m["share_pct"] for m in s["modes"]}
        shared = sorted(set(bm) & set(sm))
        base_modes = [m["hex"] for m in b["modes"][:5]]
        sig_modes = [m["hex"] for m in s["modes"][:5]]
        # how far each outfit's own family modes are from the other's, in dE76
        per_fam = {}
        for f in ("a", "b"):
            cb = fam_of(palette, "base", region, f)
            cs = fam_of(palette, OUTFITS[0], region, f)
            if not cb or not cs:
                continue
            per_fam["%s_%s" % (region, f)] = {
                "base_mode": cb["mode_hex"], "signature_mode": cs["mode_hex"],
                "de76": round(de76(rgb_of(cb["mode_hex"]), rgb_of(cs["mode_hex"])), 1),
                "base_share_pct": cb["share_pct"], "signature_share_pct": cs["share_pct"],
                "base_sat": cb["sat"], "signature_sat": cs["sat"],
                "base_val": cb["val"], "signature_val": cs["val"]}
        base_vs_signature["per_region"][region] = {
            "base_pixels": b["pixels"], "signature_pixels": s["pixels"],
            "base_top_modes": base_modes, "signature_top_modes": sig_modes,
            "shared_modes": shared,
            "shared_mode_shares": {h: [bm[h], sm[h]] for h in shared},
            "families": per_fam}

    # --- the two named risks, measured -------------------------------------
    # RISK 1: is the declared dark leather below the shader's sat_min?
    risk1 = {"declared": [], "atlas": None, "shader": {
        "sat_min_default": SHADER_SAT_MIN_DEFAULT,
        "hue_tol_deg": SHADER_HUE_TOL_DEG,
        "val_min": SHADER_VAL_MIN}}
    for o in OUTFITS:
        for c in src.get(o, []):
            h, s, v = hsv1(c)
            risk1["declared"].append({
                "outfit": o, "hex": c, "hue_deg": round(h, 1), "sat": round(s, 3),
                "val": round(v, 3),
                "passes_family_test_at_025": bool(s > SHADER_SAT_MIN_DEFAULT and v > SHADER_VAL_MIN),
                "passes_family_test_at_018": bool(s > 0.18 and v > SHADER_VAL_MIN)})
    risk1["atlas"] = atlas_inventory()
    risk1["note"] = ("the family test runs on the ATLAS texel, not on the target colour, so "
                     "the decisive number is the atlas share that survives sat_min -- see "
                     "atlas.dark_texels_passing_family_test. The declared colours are listed "
                     "because the task's inertness hypothesis is stated on them.")

    # RISK 2: do the orange details fall in the skin's hue window?
    orange = {"declared_signature_colours": [], "sprite_measurement": []}
    for o in OUTFITS:
        for c in src.get(o, []):
            h, s, v = hsv1(c)
            orange["declared_signature_colours"].append({
                "hex": c, "hue_deg": round(h, 1), "sat": round(s, 3), "val": round(v, 3),
                "inside_skin_hue_window": bool(SKIN_HUE[0] <= h <= SKIN_HUE[1]),
                "inside_skin_rule_full": bool(SKIN_HUE[0] <= h <= SKIN_HUE[1]
                                              and s > SKIN_SAT_MIN and v > SKIN_VAL_MIN)})
    hs, ss_, vs = hsv1(skin_hex)
    orange["declared_skin"] = {"hex": skin_hex, "hue_deg": round(hs, 1),
                               "sat": round(ss_, 3), "val": round(vs, 3)}
    for name, bpath, bframes, opath, oframes in SHEETS:
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit=OUTFITS[0]), oframes)):
            fr = load_frames(os.path.join(REPO, path), count)
            warm_px, glow_px, skinwin_px, skin_px, body_px = 0, 0, 0, 0, 0
            glow_modes = []
            for f in fr:
                a = np.asarray(f)
                rgb = a[:, :, :3].astype(np.float64)
                al = a[:, :, 3]
                c0, c1, _ = own_span(al)
                rgb = rgb[:, c0:c1]
                al = al[:, c0:c1]
                body = al > ALPHA_MIN
                hue, sat, val = hsv_of(rgb)
                body_px += int(body.sum())
                skinwin_px += int((body & (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1])
                                   & (sat > SKIN_SAT_MIN)).sum())
                skin_px += int((body & (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1])
                                & (sat > SKIN_SAT_MIN) & (val > SKIN_VAL_MIN)).sum())
                warm = body & (val > 0.55) & (sat > 0.5) & (hue >= 5) & (hue <= 45)
                warm_px += int(warm.sum())
                glow = body & (val > 0.90) & (sat > 0.55) & (hue >= 5) & (hue <= 45)
                glow_px += int(glow.sum())
                if glow.sum():
                    px = rgb[glow]
                    q = (px // 8).astype(np.int32)
                    k = q[:, 0] * 65536 + q[:, 1] * 256 + q[:, 2]
                    u, cnt = np.unique(k, return_counts=True)
                    for i in np.argsort(-cnt)[:2]:
                        glow_modes.append(hex_of(px[k == u[i]].mean(axis=0)))
            if body_px == 0:
                continue
            orange["sprite_measurement"].append({
                "sheet": name, "which": label, "body_px": body_px,
                "skin_rule_hue_sat_pct": round(100.0 * skinwin_px / body_px, 1),
                "skin_rule_with_val_floor_pct": round(100.0 * skin_px / body_px, 1),
                "bright_warm_val_gt_055_pct": round(100.0 * warm_px / body_px, 1),
                "glow_val_gt_090_pct": round(100.0 * glow_px / body_px, 1),
                "glow_modes_sample": sorted(set(glow_modes))[:4]})
    orange["note"] = ("the glow and the skin are the same hue band on this athlete. The "
                      "value floor that removes the leather from the skin rule also removes "
                      "the glow, because the glow is the brightest warm thing in the sprite. "
                      "Value is the only lever available and it is the same lever.")

    # --- the six slots, with provenance attached to every one of them -------
    #
    # POLICY (stated once, applied mechanically; thresholds are the declared constants
    # D_MATCH_DE / D_MATCH_HUE / HUE_NEEDS_SAT at the top of this file):
    #
    #   1. torso_a is THE IDENTITY SLOT: the torso is the region the reference's two
    #      colours were authored for. If the measured mode sits in the same hue family as
    #      a declared colour (dHue <= D_MATCH_HUE, both saturated) or within D_MATCH_DE,
    #      the DECLARED hex takes the slot and is labelled `source`. The sprite's mode is
    #      that colour with the 2D artwork's own shading baked in, and the 3D shader
    #      applies its own shading on top, so authoring the shaded value would double it.
    #   2. a `b` family whose measured mode sits in the same hue family as the outfit's
    #      DECLARED second colour (dHue <= D_MATCH_HUE, both saturated) takes the declared
    #      hex, labelled `source`: the sprite paints that trim with its own shading and
    #      the declared colour is the authored datum for it.
    #   3. EVERY OTHER SLOT takes the measured mode of its own region and is labelled
    #      `sprite`. The reference declares only TWO colours while the sprite paints a
    #      different colour in each region.
    #   4. explicit PORT_OVERRIDES win over all of the above and are labelled `port`.
    slots = {}
    for o in OUTFITS:
        decl = src.get(o, [])
        for region in list(BANDS):
            for f in ("a", "b"):
                c = fam_of(palette, o, region, f)
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
                    dh = dhue_deg(hm, hbest)
                    if region == "torso" and f == "a":
                        if min(sm, sbest) > HUE_NEEDS_SAT and dh <= D_MATCH_HUE:
                            origin, hexv = "source", best
                            reason = ("torso_a carries the outfit's identity; the measured "
                                      "%s is the declared %s in the same hue family (dHue "
                                      "%.1f deg <= %.0f deg), only the 2D shading differs "
                                      "(val %.3f vs %.3f), so the authored value takes the "
                                      "slot" % (measured, best, dh, D_MATCH_HUE, vm, vbest))
                        elif de_best <= D_MATCH_DE:
                            origin, hexv = "source", best
                            reason = ("torso_a carries the outfit's identity; measured %s "
                                      "is the declared %s (dE76 %.1f <= %.0f)"
                                      % (measured, best, de_best, D_MATCH_DE))
                    elif f == "b" and len(decl) > 1:
                        if min(sm, sbest) > HUE_NEEDS_SAT and dh <= D_MATCH_HUE:
                            origin, hexv = "source", best
                            reason = ("the sprite paints this trim as %s (%.1f%% of the "
                                      "region), which is the declared %s in the same hue "
                                      "family (dHue %.1f deg <= %.0f deg, val %.3f vs "
                                      "%.3f); the authored value takes the slot"
                                      % (measured, mk, best, dh, D_MATCH_HUE, vm, vbest))
                        else:
                            reason = ("measured modal colour of the region (%s, %.1f%% of "
                                      "the region's garment pixels); the declared second "
                                      "colour %s is %.1f deg of hue and dE76 %.1f away, "
                                      "outside the match windows, so the sprite value stays"
                                      % (measured, mk, best, dh, de_best))
                    else:
                        reason = ("measured modal colour of the region (%s, %.1f%% of the "
                                  "region's garment pixels); the reference declares no "
                                  "region/family" % (measured, mk))
                # RULE 5 (declared): a measured mode that FAILS THE SHADER'S OWN FAMILY
                # TEST is not a garment colour. On this athlete five of the six measured
                # modes are the sprite's neutral shading/outline (sat 0.000-0.030) and the
                # white highlight (sat 0.000-0.004); the shader's `ss((sat - sat_min)/0.12)`
                # gives them weight ~0, so as targets they would paint nothing, and as
                # evidence they are not what the garment is made of. Those slots fall back
                # to the declared colour of the family they belong to -- family `a` is the
                # dominant mass and takes `colors[0]` (primary), family `b` is the trim and
                # takes `colors[1]` (trim), which is the catalogue's own convention
                # ("colors[0] -> primary, colors[1] -> trim"). The rejected measured mode is
                # kept in the record, never dropped.
                if origin == "sprite" and decl and (c["sat"] <= CATALOGUE_SAT_MIN
                                                    or c["val"] <= CATALOGUE_VAL_MIN):
                    fb = decl[0] if f == "a" else (decl[1] if len(decl) > 1 else decl[0])
                    origin, hexv = "source", fb
                    reason = ("measured modal colour %s (%.1f%% of the region) REJECTED: "
                              "sat %.3f / val %.3f fails the shader's own family test at "
                              "sat_min %.2f (the sprite has no flat garment fill on this "
                              "athlete -- the mode is its neutral shading, not paint), so "
                              "the declared %s takes the %s family"
                              % (measured, mk, c["sat"], c["val"], CATALOGUE_SAT_MIN, fb,
                                 "primary (a, the dominant mass)" if f == "a"
                                 else "trim (b, the accent)"))
                key = "%s_%s" % (region, f)
                rec = {"hex": hexv, "origin": origin, "measured_mode": measured,
                       "measured_share_pct": mk, "measured_sat": c["sat"],
                       "measured_val": c["val"], "reason": reason}
                ov = PORT_OVERRIDES.get((o, key))
                if ov:
                    rec = {"hex": ov["hex"], "origin": "port", "measured_mode": measured,
                           "measured_share_pct": mk, "measured_sat": c["sat"],
                           "measured_val": c["val"], "reason": ov["why"],
                           "would_have_been": hexv}
                slots.setdefault(o, {})[key] = rec

    # --- inertness of each proposed slot, as a number ----------------------
    # TWO distinct questions, and they are NOT the same question:
    #   (i)  does the SHADER accept the slot's family? It tests the BAKED ATLAS TEXEL
    #        against the ANCHOR, so the answer comes from atlas_family_split_in_mask();
    #   (ii) is the recolour VISIBLE? That depends on the TARGET vs the anchor it
    #        replaces, and it is answered by target_vs_baked_anchor().
    # The per-slot block below keeps the task's framing (the target colour's own
    # sat/val against sat_min) so the hypothesis can be checked directly, and reports
    # it at BOTH the shader's default and the catalogue's effective setting.
    atlas_split = atlas_family_split_in_mask()
    tgt_vs_anchor = target_vs_baked_anchor(slots)
    region_delta = region_change_delta()
    inert = {}
    for o in OUTFITS:
        for key, rec in slots[o].items():
            h, s, v = hsv1(rec["hex"])
            ms, mv = rec["measured_sat"], rec["measured_val"]
            inert[key] = {
                "hex": rec["hex"], "origin": rec["origin"],
                "sat": round(s, 3), "val": round(v, 3),
                "passes_family_test_at_shader_default_025": bool(
                    s > SHADER_SAT_MIN_DEFAULT and v > SHADER_VAL_MIN),
                "passes_family_test_at_effective_018": bool(
                    s > CATALOGUE_SAT_MIN and v > CATALOGUE_VAL_MIN),
                "measured_mode_sat": ms,
                "measured_mode_val": mv,
                "measured_mode_passes_at_shader_default_025": bool(
                    ms > SHADER_SAT_MIN_DEFAULT and mv > SHADER_VAL_MIN),
                "measured_mode_passes_at_effective_018": bool(
                    ms > CATALOGUE_SAT_MIN and mv > CATALOGUE_VAL_MIN),
                "target_vs_baked_anchor": (tgt_vs_anchor.get("per_slot", {})
                                           .get("%s.%s" % (o, key), {})),
                "note": ("the shader tests the BAKED ATLAS TEXEL, not this target, so "
                         "these booleans check the task's hypothesis on the target and "
                         "are NOT what decides whether the slot recolours. See "
                         "atlas_family_split_in_mask and target_vs_baked_anchor."),
            }
    inert["_summary"] = {
        "shader_sat_min_default": SHADER_SAT_MIN_DEFAULT,
        "catalogue_sat_min_effective": CATALOGUE_SAT_MIN,
        "slots_with_measured_mode_below_effective_sat_min": sorted(
            k for k, v in inert.items()
            if isinstance(v, dict) and not v["measured_mode_passes_at_effective_018"]),
        "slots_with_target_below_effective_sat_min": sorted(
            k for k, v in inert.items()
            if isinstance(v, dict) and not v["passes_family_test_at_effective_018"]),
        "slots_whose_target_is_INVISIBLE_on_its_own_baked_anchor": sorted(
            k for k, v in inert.items() if isinstance(v, dict)
            and any(a.get("verdict") == "INVISIBLE"
                    for a in (v["target_vs_baked_anchor"].get("vs_anchor") or {}).values())),
        "slots_above": sorted(k for k, v in inert.items()
                              if isinstance(v, dict) and v["passes_family_test_at_effective_018"]),
    }

    # --- provenance tally, so the document cannot overstate how much was measured ---
    prov = {}
    for o in OUTFITS:
        for key, rec in slots[o].items():
            prov[rec["origin"]] = prov.get(rec["origin"], 0) + 1
    slot_provenance = {
        "counts": prov,
        "legend": {"source": "js/data.js ATHLETE_OUTFITS value",
                   "sprite": "modal colour measured off the in-field 2D sprite",
                   "port": "deliberate deviation from both, listed in port_only"},
        "port_only": {o: sorted(k for k, r in recs.items() if r["origin"] == "port")
                      for o, recs in slots.items()},
    }

    report = {
        "_tool": "tools/character/measure_colosso_palette.py",
        "scope": {
            "athlete": "colosso",
            "outfits_measured": OUTFITS,
            "out_of_scope": ("mythic: needs new geometry (sleeved light jersey, belt, front "
                             "drape) and is built elsewhere with the Meshy API. Not read, "
                             "not measured, not in any table of this report."),
        },
        "method": {
            "alpha_min": ALPHA_MIN,
            "bands_of_body_bbox_height": BANDS,
            "extra_bands_not_rig_regions": EXTRA_BANDS,
            "change_eps_255": CHANGE_EPS,
            "family_convention": "a = larger cluster (dominant garment mass), b = trim",
            "heuristics": {
                "skin": ("hue %d-%d deg and sat > %.2f (declared port heuristic) AND val > "
                         "%.2f (MEASURED floor for this athlete: the declared skin %s has "
                         "val p10 0.60-0.61 over the six sheets, the leather mass 0.03-0.35, "
                         "and the bare hue+sat rule alone would remove 61.6-66.3%% of the body)"
                         % (SKIN_HUE[0], SKIN_HUE[1], SKIN_SAT_MIN, SKIN_VAL_MIN, skin_hex)),
                "hair": "max-channel distance <= %d/255 from declared hair %s" % (HAIR_TOL, hair_hex),
                "racket": ("geometric: inside each band, the body's own column block is the "
                           "run of columns whose occupancy is >= %.2f of the band height; ink "
                           "left of it, separated by a fully transparent column gap of >= %d "
                           "px, is the racket. The Maestro's gold-blob rule does NOT apply "
                           "here: the bright-gold family is 0.00-0.89%% of the body and its "
                           "largest blob is 8-46 px, because this racket's head is black and "
                           "its frame is dark brass." % (RACKET_OCC, RACKET_GAP)),
            },
        },
        "source_colours_declared": src,
        "hem_detection": {"per_sheet": hem, "note": (
            "the shorts hem is the row where the silhouette's widest run drops below 62%% "
            "of the previous row's: below the hem the figure splits into two narrow legs. "
            "This is what sets the hip band's bottom edge.")},
        "baked_atlas_inventory": risk1["atlas"],
        "atlas_family_split_in_mask": atlas_split,
        "target_vs_baked_anchor": tgt_vs_anchor,
        "region_change_delta": region_delta,
        "metal_map_inventory": metal_map_inventory(),
        "glb_texture_check": glb_texture_check(),
        "mask_lane_cross_check": mask_lane_cross_check(),
        "card_check": card_check(),
        "frame_grid_check": grid,
        "sheet_bleed": {"per_frame": bleed,
                        "total_dropped_px": int(sum(b["dropped_px"] for b in bleed)),
                        "note": "columns belonging to a neighbouring figure's ink; excluded "
                                "from the colour measurement"},
        "bands_sheet_policy": {k: list(v) for k, v in BAND_SHEET_EXCLUDE.items()},
        "racket_rule_log": {"applied_count": len(racket_log), "entries": racket_log[:40]},
        "racket_rule_gold_blob_check": gold_blob_check(),
        "residual_skin_log": skin_log,
        "measured_palette": palette,
        "measured_palette_no_racket_exclusion": palette_no_racket,
        "measured_palette_per_sheet": per_sheet_palette,
        "slot_proposal": slots,
        "slot_provenance_summary": slot_provenance,
        "inertness": inert,
        "risk_dark_leather_below_sat_min": risk1,
        "risk_orange_vs_skin_hue": orange,
        "base_vs_signature": base_vs_signature,
        "pixel_changes_vs_base_APPROXIMATE": changes,
    }

    os.makedirs(out_dir, exist_ok=True)
    # A non-finite number anywhere would serialise as bare NaN/Infinity, i.e. invalid
    # JSON that only Python reads back. Fail loudly instead.
    bad = []

    def _scan(node, path=""):
        if isinstance(node, dict):
            for k, v in node.items():
                _scan(v, "%s.%s" % (path, k))
        elif isinstance(node, list):
            for i, v in enumerate(node):
                _scan(v, "%s[%d]" % (path, i))
        elif isinstance(node, float) and not np.isfinite(node):
            bad.append(path)

    _scan(report)
    if bad:
        raise SystemExit("non-finite numbers in the report at: %s" % ", ".join(bad[:10]))
    dump = os.path.join(out_dir, "colosso-palette-report.json")
    with open(dump, "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, allow_nan=False)
        fh.write("\n")

    if write_evidence:
        write_evidence_images(out_dir, report)

    print("WROTE %s" % os.path.relpath(dump, REPO))
    for o in ["base"] + OUTFITS:
        bits = []
        for region in list(BANDS):
            for f in ("a", "b"):
                c = fam_of(palette, o, region, f)
                if c:
                    bits.append("%s_%s=%s(mode)/%s(mean) %s%% sat=%.3f val=%.3f"
                                % (region, f, c["mode_hex"], c["mean_hex"], c["share_pct"],
                                   c["sat"], c["val"]))
        print("%-10s %s" % (o, "  ".join(bits)))
    print("slots proposed (origin/source per slot):")
    for o in OUTFITS:
        for key in ("torso_a", "torso_b", "hip_a", "hip_b", "foot_a", "foot_b"):
            rec = report["slot_proposal"][o][key]
            print("  %-10s %-8s %s  [%s]  measured=%s sat=%.3f  %s"
                  % (o, key, rec["hex"], rec["origin"], rec["measured_mode"],
                     rec["measured_sat"], rec["reason"]))
    _pv = report["slot_provenance_summary"]
    print("provenance over the six slots: %s   port_only=%s"
          % (_pv["counts"], _pv["port_only"]))
    print("inertness (effective sat_min %.2f from the catalogue's MASK_DEFAULTS; the shader's own "
          "default is %.2f):" % (CATALOGUE_SAT_MIN, SHADER_SAT_MIN_DEFAULT))
    for key, v in sorted(report["inertness"].items()):
        if key.startswith("_"):
            continue
        print("  %-8s %s target_sat=%.3f val=%.3f passes@0.18=%s | measured_sat=%.3f val=%.3f passes@0.18=%s"
              % (key, v["hex"], v["sat"], v["val"], v["passes_family_test_at_effective_018"],
                 v["measured_mode_sat"], v["measured_mode_val"],
                 v["measured_mode_passes_at_effective_018"]))
        for an, av in (v["target_vs_baked_anchor"].get("vs_anchor") or {}).items():
            print("      vs baked anchor %-8s %s  dE76=%5.1f  %s"
                  % (an, report["target_vs_baked_anchor"]["anchors"][an], av["de76"],
                     av["verdict"]))
    _sm = report["inertness"]["_summary"]
    print("  targets below effective sat_min: %s" % (", ".join(_sm["slots_with_target_below_effective_sat_min"]) or "none"))
    print("  targets INVISIBLE on their own baked anchor: %s"
          % (", ".join(_sm["slots_whose_target_is_INVISIBLE_on_its_own_baked_anchor"]) or "none"))
    asp = report["atlas_family_split_in_mask"]
    print("ATLAS FAMILY SPLIT IN MASK (%s)" % asp.get("mask", "?"))
    if "error" in asp:
        print("      %s" % asp["error"])
    else:
        print("      anchors from %s: %s" % (asp["anchors_source"], asp["anchors_measured_by_mask_lane"]))
        print("      coverage texels (>=128): %s" % asp["coverage_texels_ge128"])
        for sname, s in asp["per_setting"].items():
            print("      [%s] hue_tol=%.0f sat_min=%.2f val_min=%.2f"
                  % (sname, s["hue_tol_deg"], s["sat_min"], s["val_min"]))
            for region, e in s["regions"].items():
                if not e.get("masked_texels"):
                    print("        %-5s no masked texels" % region)
                    continue
                g = e["gate_off"]
                acc = {k: round(float(v), 1) for k, v in g["accepted_pct_per_anchor"].items()}
                print("        %-5s masked=%7d  gateOFF accepted: %s  BOTH=%d (%.1f%%)  dHue between anchors=%.1f"
                      % (region, e["masked_texels"], acc,
                         g["accepted_by_BOTH_anchors"], g["accepted_by_BOTH_pct"],
                         g["hue_deg_between_anchors"]))
                on = e.get("gate_on_with_mask_lane_bands")
                if on:
                    acco = {k: round(float(v), 1)
                            for k, v in on["accepted_pct_per_anchor"].items()}
                    print("              gateON  accepted: %s  BOTH=%d  orphans=%d"
                          % (acco, on["accepted_by_BOTH_anchors"],
                             on["accepted_by_NEITHER_orphans"]))
        xc = asp.get("cross_check_mask_lane_hue_window") or {}
        if xc:
            print("      CROSS-CHECK vs the mask lane's own figure: masked_texels_here=%d "
                  "(mask lane %d)" % (xc["masked_texels_here"],
                                      xc["mask_lane_reported_masked_texels"]))
            print("        pure hue window (dh<=tol for BOTH): %d (%.1f%%)  | mask lane reports %d (%.1f%%)"
                  % (xc["hue_window_dh_le_tol_BOTH"], xc["hue_window_dh_le_tol_BOTH_pct"],
                     xc["mask_lane_reported_BOTH"],
                     round(100.0 * xc["mask_lane_reported_BOTH"]
                           / xc["mask_lane_reported_masked_texels"], 1)))
            print("        the same set after the shader's sat/val ramps: %d (%.1f%%) -- that is "
                  "the count the render sees"
                  % (xc["same_plus_sat_val_ramps_BOTH"],
                     xc["same_plus_sat_val_ramps_BOTH_pct"]))
    print("REGION CHANGE DELTA (scale-invariant shares, outfit minus base, points):")
    for region, per in report["region_change_delta"]["per_region"].items():
        d = per["delta_outfit_minus_base_pct"]
        big = sorted(d.items(), key=lambda kv: -abs(kv[1]))[:3]
        print("  %-5s base_px=%d sig_px=%d  biggest deltas: %s"
              % (region, per["base"]["px"], per["outfit"]["px"],
                 ", ".join("%s %+.1f" % (k, v) for k, v in big)))
    at = report["baked_atlas_inventory"]
    if "error" not in at:
        print("ATLAS %s %s sha=%s saturated=%.1f%% bands=%s"
              % (at["path"], at["size"], at["sha256_prefix"], at["saturated_share_pct"],
                 at["saturated_hue_bands_pct"]))
        print("      dark texels passing family test: %s" % at["dark_texels_passing_family_test"])
    print("BASE vs SIGNATURE (scale-invariant):")
    for region, v in report["base_vs_signature"]["per_region"].items():
        print("  %-6s base %s / sig %s  shared modes %s"
              % (region, v["base_top_modes"][:3], v["signature_top_modes"][:3],
                 v["shared_modes"]))
        for k, fv in v["families"].items():
            print("      %-8s base %s (%.1f%%) vs sig %s (%.1f%%)  dE76=%.1f"
                  % (k, fv["base_mode"], fv["base_share_pct"], fv["signature_mode"],
                     fv["signature_share_pct"], fv["de76"]))
    print("ORANGE vs SKIN:")
    for c in report["risk_orange_vs_skin_hue"]["declared_signature_colours"]:
        print("  declared %s hue=%.1f sat=%.3f val=%.3f inside_skin_hue_window=%s"
              % (c["hex"], c["hue_deg"], c["sat"], c["val"], c["inside_skin_hue_window"]))
    for s in report["risk_orange_vs_skin_hue"]["sprite_measurement"]:
        print("  %-10s %-5s skin_rule(hue+sat)=%.1f%% -> with val floor=%.1f%%  "
              "bright_warm=%.1f%%  glow(val>.90)=%.1f%%  glow_modes=%s"
              % (s["sheet"], s["which"], s["skin_rule_hue_sat_pct"],
                 s["skin_rule_with_val_floor_pct"], s["bright_warm_val_gt_055_pct"],
                 s["glow_val_gt_090_pct"], s["glow_modes_sample"]))
    cc = report["card_check"]
    for o, v in cc["per_outfit"].items():
        ex = v.get("vs_base_card_exact") or {}
        ap = v.get("vs_base_card_preview_APPROXIMATE") or {}
        print("CARD %s master(exact, %s): %.1f%% over 16/255 mean %.1f | preview(APPROX): %.1f%%"
              % (o, v.get("master_size"), ex.get("pct_pixels_over_16_255", -1),
                 ex.get("mean_abs_255", -1), ap.get("pct_pixels_over_16_255", -1)))
    rr = report["racket_rule_log"]
    print("RACKET RULE applied_count=%d (0 means the geometric rule never fired, so the "
          "racket was NOT excluded and the pool may contain racket pixels)" % rr["applied_count"])
    gb = report["racket_rule_gold_blob_check"]
    print("      bright-gold family, largest blob per sheet (why the Maestro's gold-blob "
          "rule cannot be used here):")
    for e in gb["per_sheet"]:
        print("        %-11s %-5s gold=%.3f%% of body  largest_blob=%d px"
              % (e["sheet"], e["which"], e["gold_pct_of_body"] or 0.0,
                 e["largest_gold_blob_px"]))
    mc = report["mask_lane_cross_check"]
    print("MASKLANE report_present=%s mask_present=%s %s"
          % (mc["report_present"], mc["mask_present"], mc.get("note", "")))
    return report


# ---------------------------------------------------------------------------
# evidence images
# ---------------------------------------------------------------------------
def write_evidence_images(out_dir: str, report: dict) -> None:
    """Band boundaries, the skin rule and the racket rule over the base sprite.

    The images are the check on the heuristics: if the skin rule ate the leather, or the
    racket rule ate the hand, it is visible here.
    """
    hair_hex = report["source_colours_declared"].get("_visual", {}).get("hair", "#1c130d")
    for name, bpath, bframes, opath, oframes in SHEETS:
        panels = []
        for label, path, count in (("base", bpath, bframes),
                                   ("outfit", opath.format(outfit=OUTFITS[0]), oframes)):
            frames = load_frames(os.path.join(REPO, path), count)
            for fi, frame in enumerate(frames):
                rgba = np.asarray(frame).astype(np.int16)
                alpha = rgba[:, :, 3]
                c0, c1, _ = own_span(alpha)
                # the crop is by COLUMN only, so the row indices of `bands` stay valid on
                # the full-height frame; every mask drawn here must be the cropped one.
                excl = exclusion_masks(rgba[:, c0:c1], hair_hex)
                bands = per_frame_bands(alpha[:, c0:c1])
                vis = rgba[:, c0:c1, :3].astype(np.uint8).copy()
                # skin rule, split into the two halves so the value floor is visible
                rgb = rgba[:, c0:c1, :3].astype(np.float64)
                hue, sat, val = hsv_of(rgb)
                win = (hue >= SKIN_HUE[0]) & (hue <= SKIN_HUE[1]) & (sat > SKIN_SAT_MIN)
                dark_win = win & (val <= SKIN_VAL_MIN)
                vis[dark_win] = (vis[dark_win] * 0.45 + np.array([90, 90, 90]) * 0.55
                                 ).astype(np.uint8)
                vis[excl["skin"]] = (vis[excl["skin"]] * 0.35 + np.array([255, 0, 0]) * 0.65
                                     ).astype(np.uint8)
                vis[excl["hair"]] = (vis[excl["hair"]] * 0.35 + np.array([255, 160, 0]) * 0.65
                                     ).astype(np.uint8)
                if bands:
                    for region in BANDS:
                        b0, b1, _ = bands[region]
                        rk, info = racket_columns(rgba[:, c0:c1], (int(b0), int(b1)))
                        if info.get("applied"):
                            vis[rk] = (vis[rk] * 0.35 + np.array([255, 0, 255]) * 0.65
                                       ).astype(np.uint8)
                img = Image.fromarray(vis)
                d = ImageDraw.Draw(img)
                if bands:
                    for region in BANDS:
                        b0, b1, _ = bands[region]
                        for y in (b0, b1):
                            d.line([(0, y), (img.size[0], y)], fill=(80, 255, 80), width=1)
                        d.text((2, min(img.size[1] - 10, b0 + 2)), region, fill=(120, 255, 120))
                sc = 3
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

    # swatch strips: MEASURED modal colour per region family, and the PROPOSED slot value
    # with its provenance letter (S source / M measured sprite / P port).
    cols = [("torso_a", "torso", "a"), ("torso_b", "torso", "b"),
            ("hip_a", "hip", "a"), ("hip_b", "hip", "b"),
            ("foot_a", "foot", "a"), ("foot_b", "foot", "b")]
    rowh, cw = 52, 150
    rows = ["base"] + OUTFITS
    for which in ("measured", "proposed"):
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
                rgb, note = None, ""
                if which == "measured":
                    e = (report["measured_palette"].get(o) or {}).get(region) or {}
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
                         "against the base (default %d). The base and outfit sheets are "
                         "different resolutions, so this comparison is APPROXIMATE at any "
                         "setting." % CHANGE_EPS)
    args = ap.parse_args()
    CHANGE_EPS = args.change_eps
    measure(os.path.abspath(args.out_dir), not args.no_evidence)
    return 0


if __name__ == "__main__":
    sys.exit(main())
