#!/usr/bin/env python3
"""Objective comparison of the four rendered Maestro outfit variants.

Reads ONLY the PNG frames written by `res://tests/outfit_maestro_capture.gd`
(and its siblings for other athletes) and measures, on the rendered pixels:

  (a) how far each variant is from `base`;
  (b) how far the variants are from EACH OTHER, with the circuit/signature pair
      broken out by name because that is the known collision risk for this athlete
      (their measured 2D shorts sit at dE76 22 and their `hip_b` is the same white);
  (c) whether SKIN was recoloured - and this one is a HEURISTIC, not a semantic
      proof: skin pixels are selected on the BASE frame by base HSV hue 9-37.8
      degrees, saturation > 0.30 and value > 0.30 (the window the port's own skin
      heuristic uses, and the window the Maestro's declared skin `#c98258` falls
      in), and the same pixel coordinates are then differenced between variant and
      base. It reports mean, p95 and max absolute RGB difference per channel.

WHY A HEURISTIC IS NOT A PROOF. A hue window cannot tell skin from a warm-coloured
garment, a shoe, an antialiased edge, or a hand near the racket's dark handle, and
it can miss a texel whose shading moved it outside the window. It bounds the
problem; a human still has to look at the frames. The tool says so in its output
(`declaration_skin`) and so does docs/agent-work/outfits-3d/MAESTRO-RENDER.md.

NO ENGINE, NO NETWORK: this script never runs Godot and never writes into the
capture directory. Differences are measured on the body mask only, which is derived
per (pose, view, scale) from the frames themselves (border colour = background) and
unioned over the four states, so every compared pair is measured over exactly the
same pixels.

Differences are accumulated as 256-bin per-channel histograms, so percentiles are
exact and memory stays flat regardless of how many frames are compared.

Usage:
    python3 tools/character/compare_maestro_renders.py
    python3 tools/character/compare_maestro_renders.py --json-out /tmp/maestro.json
    python3 tools/character/compare_maestro_renders.py --require-distinct
    python3 tools/character/compare_maestro_renders.py --skin-max-mean 2.0

Requires numpy and Pillow (same as the other tools/character scripts):
    python3 -m venv /tmp/maestro-venv && /tmp/maestro-venv/bin/pip install pillow numpy
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

STATES = ("base", "circuit", "legend", "signature")
POSES = ("idle", "run", "backhand", "smash")
VIEWS = ("front", "back")
SCALES = ("close", "match")

# Defaults are the capture harness's arguments; keep them in step with
# godot/tests/outfit_maestro_capture.gd.
DEFAULT_DIR = "docs/agent-work/outfits-3d/evidence/renders-maestro"
DEFAULT_ATHLETE = "maestro"
SIZE = 640

CHANGE_EPS = 4          # per-channel, /255: below this a pixel is "unchanged"
CHANGE_EPS_BIG = 16     # a visibly moved pixel
BG_EPS = 6              # per-channel, /255: distance from the background = body
BG_SAMPLE_RING = 4      # border width in px used to estimate the background
SKIN_HUE_LO = 9.0
SKIN_HUE_HI = 37.8
SKIN_SAT_MIN = 0.30
SKIN_VAL_MIN = 0.30
SKIN_CHANGED_EPS = 8    # per-channel, /255: a skin pixel that "moved"

DECLARATION_SKIN = (
    "HEURISTIC, NOT A SEMANTIC PROOF. Skin pixels are selected on the BASE frame by "
    "base HSV hue in [9.0, 37.8] degrees, saturation > 0.30 and value > 0.30, and the "
    "same pixel coordinates are then differenced between the variant and base. The "
    "window cannot separate skin from a warm garment, a shoe or an antialiased edge, "
    "and it can miss a texel whose shading pushed it outside the window."
)
DECLARATION_DIFF = (
    "Deltas are measured on the body mask only (pixels further than %d/255 from the "
    "background colour estimated from the frame border), unioned over the four states "
    "per (pose, view, scale) so every pair is measured over identical pixels. The "
    "studio, camera, lights and pose are identical for all four states by "
    "construction in the capture harness, so a delta is the garment and nothing else."
) % BG_EPS


# --------------------------------------------------------------------------- #
# colour helpers (same maths as tools/character/analyse_recolour_delta.py)
# --------------------------------------------------------------------------- #
def rgb_to_hsv01(rgb: np.ndarray):
    """rgb float array in [0,1], shape (...,3) -> (h_deg, s, v)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-9
    rmax = nz & (mx == r)
    gmax = nz & (mx == g) & ~rmax
    bmax = nz & (mx == b) & ~rmax & ~gmax
    with np.errstate(invalid="ignore", divide="ignore"):
        dd = np.where(d == 0, 1, d)
        h[rmax] = (60.0 * ((g - b) / dd))[rmax] % 360.0
        h[gmax] = (60.0 * ((b - r) / dd) + 120.0)[gmax]
        h[bmax] = (60.0 * ((r - g) / dd) + 240.0)[bmax]
    s = np.where(mx > 1e-9, d / np.where(mx == 0, 1, mx), 0.0)
    return h, s, mx


# --------------------------------------------------------------------------- #
# exact percentiles from 256-bin per-channel histograms
# --------------------------------------------------------------------------- #
class DiffAccumulator:
    """Mean / p95 / max absolute RGB difference, accumulated over frames."""

    def __init__(self, eps: int, eps_big: int):
        self.eps = eps
        self.eps_big = eps_big
        self.hist = np.zeros((3, 256), dtype=np.int64)
        self.abs_sum = np.zeros(3, dtype=np.float64)
        self.signed_sum = np.zeros(3, dtype=np.float64)
        self.max = np.zeros(3, dtype=np.int64)
        self.n = 0
        self.n_changed = 0
        self.n_changed_big = 0
        self.euc_sum = 0.0
        self.frames = 0

    def add(self, a_u8: np.ndarray, b_u8: np.ndarray, mask: np.ndarray) -> None:
        self.frames += 1
        if mask.sum() == 0:
            return
        a = a_u8[mask].astype(np.int16)
        b = b_u8[mask].astype(np.int16)
        d = np.abs(a - b)
        s = a - b
        self.abs_sum += d.sum(axis=0)
        self.signed_sum += s.sum(axis=0)
        self.max = np.maximum(self.max, d.max(axis=0))
        for c in range(3):
            self.hist[c] += np.bincount(d[:, c].astype(np.int64), minlength=256)
        mx = d.max(axis=1)
        self.n_changed += int((mx > self.eps).sum())
        self.n_changed_big += int((mx > self.eps_big).sum())
        self.euc_sum += float(np.sqrt((s.astype(np.float64) ** 2).sum(axis=1)).sum())
        self.n += int(d.shape[0])

    def _pct(self, channel: int, q: float) -> int:
        if self.n == 0:
            return 0
        cum = np.cumsum(self.hist[channel])
        return int(min(int(np.searchsorted(cum, q * self.n)), 255))

    def report(self) -> dict:
        n = max(self.n, 1)
        return {
            "frames": self.frames,
            "body_pixels": self.n,
            "mean_abs_per_channel_255": [round(float(x) / n, 4) for x in self.abs_sum],
            "mean_abs_overall_255": round(float(self.abs_sum.sum()) / (3.0 * n), 4),
            "p95_per_channel_255": [self._pct(c, 0.95) for c in range(3)],
            "max_per_channel_255": [int(x) for x in self.max],
            "max_channel_overall_255": int(self.max.max()) if self.n else 0,
            "mean_euclidean_255": round(self.euc_sum / n, 4),
            "signed_mean_per_channel_255": [round(float(x) / n, 4) for x in self.signed_sum],
            "frac_changed_gt_%d" % self.eps: round(self.n_changed / n, 6),
            "frac_changed_gt_%d" % self.eps_big: round(self.n_changed_big / n, 6),
            "abs_mean_over_changed_255": (
                round(float(self.abs_sum.sum()) / (3.0 * self.n_changed), 4)
                if self.n_changed else 0.0),
            "identical": self.n > 0 and int(self.max.max()) == 0,
        }


# --------------------------------------------------------------------------- #
# frame discovery and masks
# --------------------------------------------------------------------------- #
def frame_name(athlete: str, state: str, pose: str, view: str, scale: str) -> str:
    return "%s_%s_%s_%s_%s.png" % (athlete, state, pose, view, scale)


def read_rgb(path: str) -> np.ndarray:
    with Image.open(path) as im:
        return np.asarray(im.convert("RGB"), dtype=np.uint8).copy()


def background_colour(img: np.ndarray) -> tuple:
    """Modal 8-bit colour of the frame border: the studio background."""
    k = BG_SAMPLE_RING
    ring = np.concatenate([
        img[:k].reshape(-1, 3), img[-k:].reshape(-1, 3),
        img[:, :k].reshape(-1, 3), img[:, -k:].reshape(-1, 3),
    ])
    packed = (ring[:, 0].astype(np.int64) << 16) | (ring[:, 1].astype(np.int64) << 8) | ring[:, 2]
    values, counts = np.unique(packed, return_counts=True)
    best = int(values[int(np.argmax(counts))])
    return ((best >> 16) & 0xFF, (best >> 8) & 0xFF, best & 0xFF)


def body_mask(img: np.ndarray, bg: tuple, eps: int = BG_EPS) -> np.ndarray:
    diff = np.abs(img.astype(np.int16) - np.array(bg, dtype=np.int16)).max(axis=2)
    return diff > eps


def skin_mask(base: np.ndarray, body: np.ndarray) -> np.ndarray:
    """The declared heuristic. See DECLARATION_SKIN."""
    f = base.astype(np.float64) / 255.0
    h, s, v = rgb_to_hsv01(f)
    inside = (h >= SKIN_HUE_LO) & (h <= SKIN_HUE_HI) & (s > SKIN_SAT_MIN) & (v > SKIN_VAL_MIN)
    return inside & body


# --------------------------------------------------------------------------- #
def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=DEFAULT_DIR,
                    help="directory of capture PNGs (repo-relative or absolute)")
    ap.add_argument("--athlete", default=DEFAULT_ATHLETE)
    ap.add_argument("--json-out", default=None, help="also write the report here")
    ap.add_argument("--change-eps", type=int, default=CHANGE_EPS)
    ap.add_argument("--change-eps-big", type=int, default=CHANGE_EPS_BIG)
    ap.add_argument("--bg-eps", type=int, default=BG_EPS)
    ap.add_argument("--skin-eps", type=int, default=SKIN_CHANGED_EPS)
    ap.add_argument("--require-distinct", action="store_true",
                    help="exit 1 when a variant is pixel-identical to base")
    ap.add_argument("--require-separable", action="store_true",
                    help="exit 1 when circuit/signature are not separable on screen")
    ap.add_argument("--separable-min", type=float, default=0.01,
                    help="minimum fraction of body pixels that must move between "
                         "circuit and signature for --require-separable")
    ap.add_argument("--skin-max-mean", type=float, default=None,
                    help="exit 1 when the skin mean abs difference per channel "
                         "exceeds this many 255ths")
    args = ap.parse_args(argv)

    out_dir = args.dir if os.path.isabs(args.dir) else os.path.join(REPO_ROOT, args.dir)
    report = {
        "tool": "tools/character/compare_maestro_renders.py",
        "athlete": args.athlete,
        "dir": out_dir,
        "expected_resolution": [SIZE, SIZE],
        "declaration_delta": DECLARATION_DIFF,
        "declaration_skin": DECLARATION_SKIN,
        "thresholds": {
            "change_eps_255": args.change_eps,
            "change_eps_big_255": args.change_eps_big,
            "bg_eps_255": args.bg_eps,
            "skin_eps_255": args.skin_eps,
            "skin_hue_deg": [SKIN_HUE_LO, SKIN_HUE_HI],
            "skin_sat_min": SKIN_SAT_MIN,
            "skin_val_min": SKIN_VAL_MIN,
        },
    }
    if not os.path.isdir(out_dir):
        print(json.dumps(dict(report, error="no such directory: %s" % out_dir,
                              frames_found=0, missing=[frame_name(
                                  args.athlete, s, p, v, sc)
                                  for s in STATES for p in POSES for v in VIEWS
                                  for sc in SCALES])), file=sys.stdout)
        print("compare_maestro_renders: missing directory %s" % out_dir, file=sys.stderr)
        return 1

    # ---- load every expected frame --------------------------------------
    frames = {}
    missing = []
    wrong_size = []
    for state in STATES:
        for pose in POSES:
            for view in VIEWS:
                for scale in SCALES:
                    name = frame_name(args.athlete, state, pose, view, scale)
                    path = os.path.join(out_dir, name)
                    if not os.path.exists(path):
                        missing.append(name)
                        continue
                    img = read_rgb(path)
                    if list(img.shape[:2]) != [SIZE, SIZE]:
                        wrong_size.append({"file": name, "shape": list(img.shape[:2])})
                    frames[(state, pose, view, scale)] = img
    report["frames_expected"] = len(STATES) * len(POSES) * len(VIEWS) * len(SCALES)
    report["frames_found"] = len(frames)
    report["missing"] = missing
    report["unexpected_resolution"] = wrong_size

    if missing:
        print(json.dumps(report, indent=2))
        print("compare_maestro_renders: %d of %d frames missing in %s"
              % (len(missing), report["frames_expected"], out_dir), file=sys.stderr)
        return 1

    # ---- body mask, derived once per (pose, view, scale) ----------------
    bg_by_state = {}
    for state in STATES:
        key = (state, POSES[0], VIEWS[0], SCALES[0])
        bg_by_state[state] = background_colour(frames[key])
    bg_values = {tuple(v) for v in bg_by_state.values()}
    if len(bg_values) != 1:
        print("compare_maestro_renders: WARNING background estimate differs per state: %s"
              % bg_by_state, file=sys.stderr)
    bg = bg_by_state[STATES[0]]

    masks = {}
    mask_stats = {}
    for pose in POSES:
        for view in VIEWS:
            for scale in SCALES:
                union = np.zeros((SIZE, SIZE), dtype=bool)
                per_state = {}
                for state in STATES:
                    img = frames[(state, pose, view, scale)]
                    m = body_mask(img, background_colour(img), args.bg_eps)
                    per_state[state] = m
                    union |= m
                masks[(pose, view, scale)] = union
                # identical geometry => identical masks. Report the worst
                # disagreement instead of assuming it.
                disagree = 0.0
                total = max(int(union.sum()), 1)
                for state in STATES:
                    disagree = max(disagree, float((per_state[state] ^ union).sum()) / total)
                mask_stats["%s_%s_%s" % (pose, view, scale)] = {
                    "body_pixels": int(union.sum()),
                    "fraction_of_frame": round(float(union.mean()), 4),
                    "max_mask_disagreement_frac": round(disagree, 6),
                }
    report["background_rgb8"] = list(bg)
    report["background_estimate_per_state"] = {k: list(v) for k, v in bg_by_state.items()}
    report["body_mask"] = mask_stats

    # ---- (a) each variant against base, (b) variants against each other --
    def accumulate(pair, scale_filter=None, mask_fn=None):
        acc = DiffAccumulator(args.change_eps, args.change_eps_big)
        for pose in POSES:
            for view in VIEWS:
                for scale in SCALES:
                    if scale_filter and scale != scale_filter:
                        continue
                    body = masks[(pose, view, scale)]
                    m = body if mask_fn is None else (body & mask_fn(pose, view, scale))
                    acc.add(frames[(pair[0], pose, view, scale)],
                            frames[(pair[1], pose, view, scale)], m)
        return acc.report()

    def pair_report(a: str, b: str) -> dict:
        rep = accumulate((a, b))
        rep["by_scale"] = {scale: accumulate((a, b), scale_filter=scale)
                           for scale in SCALES}
        return rep

    comparisons = {}
    for state in STATES[1:]:
        comparisons["%s__vs__base" % state] = pair_report(state, "base")
    for i, a in enumerate(STATES[1:]):
        for b in STATES[i + 2:]:
            comparisons["%s__vs__%s" % (a, b)] = pair_report(a, b)
    report["comparisons"] = comparisons

    # ---- (c) the skin heuristic -----------------------------------------
    skin_masks = {}
    for pose in POSES:
        for view in VIEWS:
            for scale in SCALES:
                body = masks[(pose, view, scale)]
                skin_masks[(pose, view, scale)] = skin_mask(
                    frames[("base", pose, view, scale)], body)

    skin_pixels = {
        "match_8_frames": int(sum(v.sum() for k, v in skin_masks.items() if k[2] == "match")),
        "close_8_frames": int(sum(v.sum() for k, v in skin_masks.items() if k[2] == "close")),
        "all_32_frames": int(sum(v.sum() for k, v in skin_masks.items())),
    }

    def skin_report(state: str, scales) -> dict:
        acc = DiffAccumulator(args.skin_eps, args.change_eps_big)
        for pose in POSES:
            for view in VIEWS:
                for scale in scales:
                    acc.add(frames[(state, pose, view, scale)],
                            frames[("base", pose, view, scale)],
                            skin_masks[(pose, view, scale)])
        rep = acc.report()
        rep["skin_samples"] = acc.n
        return rep

    skin = {
        "declaration": DECLARATION_SKIN,
        "skin_pixels_selected_on_base": skin_pixels,
        "note": ("The selection is made on the BASE frame and the SAME coordinates are "
                 "differenced in each variant, so a variant that repaints a skin-hued "
                 "texel shows up here, and a variant that repaints a texel the window "
                 "never selected does not."),
        "per_variant": {},
    }
    for state in STATES[1:]:
        skin["per_variant"][state] = {
            "match_8_frames": skin_report(state, ["match"]),
            "close_8_frames": skin_report(state, ["close"]),
            "all_32_frames": skin_report(state, ["close", "match"]),
        }

    # A variant-independent residual means the skin pixels moved for a reason that
    # has nothing to do with WHICH outfit is on: the masked ShaderMaterial and the
    # rig's own StandardMaterial3D are two different shading paths, and the base
    # state is the only one that uses the second. Differencing two variants against
    # each other over the same skin pixels isolates that: if the outfits do not
    # touch skin, this is ~0 even when each variant-vs-base is not.
    def skin_report_pair(a: str, b: str) -> dict:
        acc = DiffAccumulator(args.skin_eps, args.change_eps_big)
        for pose in POSES:
            for view in VIEWS:
                for scale in SCALES:
                    acc.add(frames[(a, pose, view, scale)],
                            frames[(b, pose, view, scale)],
                            skin_masks[(pose, view, scale)])
        rep = acc.report()
        rep["skin_samples"] = acc.n
        return rep

    skin["pairwise_between_variants"] = {
        "%s__vs__%s" % (STATES[1 + i], STATES[2 + i]): skin_report_pair(STATES[1 + i], STATES[2 + i])
        for i in range(len(STATES) - 2)
    }
    skin["pairwise_between_variants"]["circuit__vs__signature"] = skin_report_pair("circuit", "signature")
    report["skin_check"] = skin

    # ---- verdicts --------------------------------------------------------
    def entry(key: str) -> dict:
        return comparisons[key]

    identical = [s for s in STATES[1:] if entry("%s__vs__base" % s)["identical"]]
    cs = entry("circuit__vs__signature")
    verdict = {
        "variants_identical_to_base": identical,
        "variants_that_move_pixels": [s for s in STATES[1:]
                                      if s not in identical],
        "circuit_vs_signature": {
            "identical": cs["identical"],
            "mean_abs_overall_255": cs["mean_abs_overall_255"],
            "frac_changed_gt_%d" % args.change_eps: cs["frac_changed_gt_%d" % args.change_eps],
            "abs_mean_over_changed_255": cs["abs_mean_over_changed_255"],
            "by_scale_frac_changed": {
                scale: cs["by_scale"][scale]["frac_changed_gt_%d" % args.change_eps]
                for scale in SCALES},
        },
        "skin": {
            s: {
                "mean_abs_per_channel_255": skin["per_variant"][s]["match_8_frames"]["mean_abs_per_channel_255"],
                "max_per_channel_255": skin["per_variant"][s]["match_8_frames"]["max_per_channel_255"],
                "frac_changed_gt_%d" % args.skin_eps: skin["per_variant"][s]["match_8_frames"]["frac_changed_gt_%d" % args.skin_eps],
            } for s in STATES[1:]
        },
    }
    report["verdict"] = verdict

    # ---- gates -----------------------------------------------------------
    gate_failures = []
    if args.require_distinct and identical:
        gate_failures.append("--require-distinct: identical to base: %s" % ", ".join(identical))
    if args.require_separable:
        frac = cs["frac_changed_gt_%d" % args.change_eps]
        if cs["identical"] or frac < args.separable_min:
            gate_failures.append(
                "--require-separable: circuit/signature move only %.4f of body pixels "
                "(minimum %.4f)" % (frac, args.separable_min))
    if args.skin_max_mean is not None:
        for s in STATES[1:]:
            mean_vec = skin["per_variant"][s]["match_8_frames"]["mean_abs_per_channel_255"]
            if max(mean_vec) > args.skin_max_mean:
                gate_failures.append(
                    "--skin-max-mean: %s moves skin by up to %.4f/255 (limit %.4f)"
                    % (s, max(mean_vec), args.skin_max_mean))
    report["gates"] = {"requested": {
        "require_distinct": args.require_distinct,
        "require_separable": args.require_separable,
        "separable_min": args.separable_min,
        "skin_max_mean": args.skin_max_mean,
    }, "failures": gate_failures}
    report["ok"] = not gate_failures

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(report, fh, indent=2, sort_keys=False)
            fh.write("\n")
        print("compare_maestro_renders: report written to %s" % args.json_out, file=sys.stderr)

    print(json.dumps(report, indent=2))

    # Human-readable digest on stderr; stdout stays pure JSON.
    print("--- Maestro render comparison (%s) ---" % out_dir, file=sys.stderr)
    print("background rgb8 %s | body mask %s px at %s"
          % (bg, mask_stats["idle_front_match"]["body_pixels"], "idle_front_match"),
          file=sys.stderr)
    for key, rep in comparisons.items():
        print("%-28s mean %7.4f  p95 %s  max %s  changed>%d %6.4f"
              % (key, rep["mean_abs_overall_255"], rep["p95_per_channel_255"],
                 rep["max_per_channel_255"], args.change_eps,
                 rep["frac_changed_gt_%d" % args.change_eps]), file=sys.stderr)
    for s in STATES[1:]:
        r = skin["per_variant"][s]["match_8_frames"]
        print("skin %-10s samples %7d  mean %s  p95 %s  max %s  changed>%d %6.4f"
              % (s, r["skin_samples"], r["mean_abs_per_channel_255"],
                 r["p95_per_channel_255"], r["max_per_channel_255"],
                 args.skin_eps, r["frac_changed_gt_%d" % args.skin_eps]), file=sys.stderr)
    for key, r in skin["pairwise_between_variants"].items():
        print("skin %-24s mean %s  max %s  (variant vs variant: isolates the "
              "shading-path residual from any outfit colour)"
              % (key, r["mean_abs_per_channel_255"], r["max_per_channel_255"]), file=sys.stderr)
    for failure in gate_failures:
        print("GATE FAIL %s" % failure, file=sys.stderr)
    print("COMPARE_MAESTRO_RENDERS_%s" % ("PASS" if not gate_failures else "FAIL"),
          file=sys.stderr)
    return 0 if not gate_failures else 1


if __name__ == "__main__":
    sys.exit(main())
