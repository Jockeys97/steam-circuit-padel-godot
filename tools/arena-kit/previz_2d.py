#!/usr/bin/env python3
"""previz_2d.py — the arena kit's 2D top-down pre-viz plans.

One plan per world arena (torii, medina, carioca, aurora, egeo), a combined sheet of all
five, and one self-contained HTML switcher. The plan is the DENSE view: every slot, every
repeat instance, at true metre scale; the 3D scene is the sparse one (someone else's lane).

EVERY NUMBER IS IMPORTED, NONE IS WRITTEN. The only input is the JSON dumped from the
engine's own spec table by `godot/tests/arena_kit_specs_dump.gd`:

    export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
    $GODOT --headless --path godot/ --script res://tests/arena_kit_specs_dump.gd \
      > docs/mission/arena-kit/arena-props/previz/arena_kit_specs_dump.log 2>&1

The JSON sits between the `SPECS_JSON_BEGIN` / `SPECS_JSON_END` markers in that log. This
script extracts it, re-derives every instance from the raw table as a cross-check against
the probe's own derived block, and refuses to draw when the two disagree (exit 2). It also
refuses to draw when the totals do not match the spec table's computed total.

Run:
    python3 tools/arena-kit/previz_2d.py            # reads the default log path
    python3 tools/arena-kit/previz_2d.py <log|json> # or an explicit dump

Outputs, all under `docs/mission/arena-kit/arena-props/previz/`:
    torii-plan.png … egeo-plan.png   one true-scale panel per arena
    all-five-arenas-plan.png         the combined sheet
    index.html                       self-contained switcher (PNGs embedded, no network)
    plan-data.json                   the per-instance table the plans were drawn from
"""

from __future__ import annotations

import base64
import datetime as _dt
import hashlib
import html
import json
import math
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[2]
PREVIZ = REPO / "docs/mission/arena-kit/arena-props/previz"
DEFAULT_LOG = PREVIZ / "arena_kit_specs_dump.log"
# The fit pass's glass margin (captain D, `docs/mission/arena-kit/arena-props/FIT-RESULT.md`):
# every mounted front face sits at least this far behind the MEASURED rear glass, so a
# declared footprint deeper than `2 * (glass - FIT_MARGIN - its own anchor z)` would put
# mesh through the glass and the plan refuses to draw it. The flat `DEPTH_BUDGET` constant
# (2 * (glass - the DEFAULT prop z)) is what the real Meshy meshes exceed — reported by the
# census and the kit suite, not a drawing defect once the anchors carry the depth.
FIT_MARGIN = 0.05
# The spec table carries 2 dp; the fit measured the true mesh and rounded, so a declared
# depth may legitimately sit half a centimetre above the depth its anchor actually leaves.
ROUND_TOL = 0.005
PROBE_CMD = (
    "/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ "
    "--script res://tests/arena_kit_specs_dump.gd"
)

# ---------------------------------------------------------------------------- palette
BG = (13, 20, 28)
PANEL_BG = (15, 23, 32)
COURT_BED = (22, 36, 58)
COURT_LINE = (230, 237, 245)
COURT_GLASS = (79, 195, 247)
BAND_BG = (19, 27, 36)
INK = (233, 240, 248)
INK_DIM = (150, 163, 178)
INK_FAINT = (104, 116, 130)
FIELD_LAW = (255, 82, 82)
GLASS = (79, 195, 247)
BACKDROP = (124, 136, 153)
PROPZ = (91, 102, 117)
FRAME_LAW = (255, 179, 0)
AUTHORED_LAW = (168, 145, 74)

SLOT_COLOURS = {
    "hero_landmark": (255, 138, 101),
    "gate_portal": (186, 104, 200),
    "light_source": (255, 213, 79),
    "vegetation_cluster": (102, 187, 106),
    "ground_dressing": (161, 136, 127),
    "ornament_accent": (77, 208, 225),
    "column_pillar": (144, 164, 174),
    "railing_segment": (240, 98, 146),
    "furniture": (100, 181, 246),
    "signage_banner": (255, 245, 157),
}

FONT_PATHS = {
    "regular": ["/System/Library/Fonts/Supplemental/Arial.ttf",
                "/System/Library/Fonts/Helvetica.ttc"],
    "bold": ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
             "/System/Library/Fonts/Supplemental/Verdana Bold.ttf"],
    "mono": ["/System/Library/Fonts/Menlo.ttc", "/System/Library/Fonts/Monaco.ttf"],
}


def font(kind: str, size: int):
    for p in FONT_PATHS.get(kind, FONT_PATHS["regular"]):
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default(size=size)


def text_w(draw: ImageDraw.ImageDraw, s: str, f) -> int:
    box = draw.textbbox((0, 0), s, font=f)
    return int(box[2] - box[0])


# ---------------------------------------------------------------------------- dump


def extract_dump(path: Path) -> tuple[dict, str, str]:
    raw = path.read_text(errors="replace")
    if path.suffix == ".json":
        body = raw
    else:
        if "SPECS_JSON_BEGIN" not in raw or "SPECS_JSON_END" not in raw:
            raise SystemExit("FATAL: %s has no SPECS_JSON markers — probe did not complete" % path)
        body = raw.split("SPECS_JSON_BEGIN", 1)[1].split("SPECS_JSON_END", 1)[0].strip()
    digest = hashlib.sha256(body.encode()).hexdigest()
    return json.loads(body), digest, raw


def verify(d: dict) -> list[str]:
    """Cross-check the probe's derived block against a fresh derivation from the raw table.

    The probe computes the repeat instances with `mount_slot()`'s formula; this function
    recomputes them from the raw anchor/spread/repeats/x_scale. Two independent passes over
    the same numbers, so a transcription slip in either one is caught before anything is
    drawn. Returns a list of complaints (empty == good).
    """
    bad: list[str] = []
    xs = float(d["frame"]["x_scale"])
    half = float(d["constants"]["AUTHORED_HALF_X"])
    gl = float(d["constants"]["GLASS_PLANE_Z"])
    fl = float(d["constants"]["FIELD_LAW_Z"])
    budget = float(d["constants"]["DEPTH_BUDGET"])
    for arena in d["arenas"]:
        aid = arena["id"]
        count = 0
        for slot in arena["slots"]:
            n, sp = int(slot["repeats"]), float(slot["spread"])
            ax0, az = float(slot["anchor"]["x"]), float(slot["anchor"]["z"])
            w = float(slot["footprint_parsed"]["w"])
            depth, th = float(slot["depth"]), float(slot["target_h"])
            if int(slot["footprint_parsed"]["h"] * 100) != int(th * 100):
                bad.append("%s/%s footprint height %s != target_h %s" % (aid, slot["slot"], slot["footprint_parsed"]["h"], th))
            if int(slot["footprint_parsed"]["d"] * 100) != int(depth * 100):
                bad.append("%s/%s footprint depth %s != depth %s" % (aid, slot["slot"], slot["footprint_parsed"]["d"], depth))
            if len(slot["instances"]) != n:
                bad.append("%s/%s instances %d != repeats %d" % (aid, slot["slot"], len(slot["instances"]), n))
            for k, inst in enumerate(slot["instances"]):
                count += 1
                want_ax = ax0 + (k - (n - 1) / 2.0) * sp
                want_cx = want_ax * xs
                want_front = az + depth / 2.0
                if abs(inst["ax"] - want_ax) > 1e-6 or abs(inst["cx"] - want_cx) > 1e-6:
                    bad.append("%s/%s instance %d x mismatch (probe %s/%s, recomputed %s/%s)"
                               % (aid, slot["slot"], k + 1, inst["ax"], inst["cx"], want_ax, want_cx))
                if abs(inst["cz"] - az) > 1e-9 or abs(inst["front_z"] - want_front) > 1e-9:
                    bad.append("%s/%s instance %d z mismatch" % (aid, slot["slot"], k + 1))
                if abs(inst["back_z"] - (az - depth / 2.0)) > 1e-9:
                    bad.append("%s/%s instance %d back_z mismatch" % (aid, slot["slot"], k + 1))
                if abs(inst["x_min"] - (want_cx - w / 2.0)) > 1e-6:
                    bad.append("%s/%s instance %d x_min mismatch" % (aid, slot["slot"], k + 1))
            # verdicts, recomputed here
            if not (az + depth / 2.0 <= fl):
                bad.append("%s/%s FIELD LAW: front z %.3f > %.3f" % (aid, slot["slot"], az + depth / 2.0, fl))
            if not (az + depth / 2.0 <= gl):
                bad.append("%s/%s glass: front z %.3f > %.3f" % (aid, slot["slot"], az + depth / 2.0, gl))
            # DEPTH, at the slot's OWN anchor. `budget` (3.26 m) is 2*(glass - the DEFAULT
            # prop z) — what a footprint could take while its front stayed behind the glass
            # at that one z. The fit pass moved real anchors so every MEASURED mesh clears
            # the glass by FIT_MARGIN; the depth a footprint may now use is therefore
            # per-slot, and seven pieces in four slots are legitimately deeper than the flat
            # constant (named in FIT-RESULT.md). The law the plan draws to is the glass.
            # ROUND_TOL: the table carries 2 dp (the fit measured the true mesh, then rounded),
            # so the declared depth may sit half a centimetre above the true one.
            avail = 2.0 * (gl - FIT_MARGIN - az) + ROUND_TOL
            if not (0.0 < depth <= avail):
                bad.append("%s/%s depth %.3f outside the %.3f m available at its anchor %.2f "
                           "(glass %.2f - margin %.2f + 2 dp %.3f; flat budget %.2f)"
                           % (aid, slot["slot"], depth, avail, az, gl, FIT_MARGIN, ROUND_TOL, budget))
            if abs(ax0) + (n - 1) * 0.5 * sp > half + 1e-9:
                bad.append("%s/%s authored frame law: run %.3f > %.3f" % (aid, slot["slot"], abs(ax0) + (n - 1) * 0.5 * sp, half))
        if count != int(arena["instances_total"]):
            bad.append("%s instance total %d != counted %d" % (aid, arena["instances_total"], count))
        if count != int(d["instance_totals"][aid]):
            bad.append("%s totals block %d != counted %d" % (aid, d["instance_totals"][aid], count))
    return bad


# ---------------------------------------------------------------------------- layout


class Plan:
    """One arena's panel geometry: world metres -> pixels, and the drawing helpers."""

    def __init__(self, arena: dict, d: dict, ppm: int, x_range: tuple[float, float],
                 z_range: tuple[float, float], origin: tuple[int, int]):
        self.arena = arena
        self.d = d
        self.ppm = ppm
        self.x0, self.x1 = x_range
        self.z0, self.z1 = z_range
        self.ox, self.oy = origin
        self.w = int(round((self.x1 - self.x0) * ppm))
        self.h = int(round((self.z1 - self.z0) * ppm))

    def px(self, x: float) -> float:
        return self.ox + (x - self.x0) * self.ppm

    def py(self, z: float) -> float:
        return self.oy + (z - self.z0) * self.ppm

    # --- primitives -------------------------------------------------------
    def hline(self, draw, z, colour, width=1, dash=None, x_from=None, x_to=None):
        y = self.py(z)
        x_from = self.x0 if x_from is None else x_from
        x_to = self.x1 if x_to is None else x_to
        _line(draw, (self.px(x_from), y), (self.px(x_to), y), colour, width, dash)

    def vline(self, draw, x, colour, width=1, dash=None, z_from=None, z_to=None):
        xp = self.px(x)
        z_from = self.z0 if z_from is None else z_from
        z_to = self.z1 if z_to is None else z_to
        _line(draw, (xp, self.py(z_from)), (xp, self.py(z_to)), colour, width, dash)

    def rect(self, draw, x_min, x_max, z_front, z_back, fill=None, outline=None, width=1):
        box = [self.px(x_min), self.py(z_back), self.px(x_max), self.py(z_front)]
        draw.rectangle(box, fill=fill, outline=outline, width=width)


def _line(draw, p0, p1, colour, width=1, dash=None):
    if not dash:
        draw.line([p0, p1], fill=colour, width=width)
        return
    (x0, y0), (x1, y1) = p0, p1
    length = math.hypot(x1 - x0, y1 - y0)
    if length <= 0:
        return
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    pos = 0.0
    on = 0.0
    while pos < length:
        seg = dash[0] if on % 2 == 0 else dash[1]
        end = min(pos + seg, length)
        if on % 2 == 0:
            draw.line([(x0 + ux * pos, y0 + uy * pos), (x0 + ux * end, y0 + uy * end)],
                      fill=colour, width=width)
        pos = end
        on += 1


def halo_text(draw, xy, s, f, fill, anchor="la", halo=(10, 15, 21), pad=1):
    x, y = xy
    for dx in (-pad, 0, pad):
        for dy in (-pad, 0, pad):
            if dx or dy:
                draw.text((x + dx, y + dy), s, font=f, fill=halo, anchor=anchor)
    draw.text((x, y), s, font=f, fill=fill, anchor=anchor)


# ---------------------------------------------------------------------------- panels


def draw_map(draw, plan: Plan, d: dict, *, label_font, tick_font, dot_font, compact=False):
    """The top-down map itself: court, planes, footprints, markers, labels."""
    c = d["constants"]
    court = d["court"]
    frame = d["frame"]
    ppm = plan.ppm
    x_half = float(court["half_len_x"])
    z_half = float(court["half_depth_z"])

    # the dressing band between the backdrop wall and the rear glass
    plan.rect(draw, plan.x0, plan.x1, float(c["GLASS_PLANE_Z"]), float(frame["backdrop_z"]),
              fill=BAND_BG)
    # the court bed
    plan.rect(draw, -x_half, x_half, z_half, -z_half, fill=COURT_BED, outline=COURT_LINE,
              width=max(1, ppm // 21))

    # net (z = 0) and its posts
    plan.hline(draw, 0.0, COURT_LINE, width=max(2, ppm // 14), x_from=-x_half, x_to=x_half)
    for sx in (-1, 1):
        draw.rectangle([plan.px(sx * x_half) - 3, plan.py(0) - 3, plan.px(sx * x_half) + 3, plan.py(0) + 3],
                       fill=COURT_LINE)
    # service lines + centre line
    for sz in (-1, 1):
        plan.hline(draw, sz * float(court["service_z"]), (200, 212, 226), width=1, dash=(6, 6),
                   x_from=-x_half, x_to=x_half)
    plan.vline(draw, 0.0, (200, 212, 226), width=1, dash=(6, 6),
               z_from=-float(court["center_line_len_z"]) / 2, z_to=float(court["center_line_len_z"]) / 2)
    # the cage: side glass and the near wall (the rear is the measured glass plane below)
    for sx in (-1, 1):
        plan.vline(draw, sx * x_half, COURT_GLASS, width=2, dash=(3, 5), z_from=-z_half, z_to=z_half)
    plan.hline(draw, z_half, COURT_GLASS, width=2, dash=(3, 5), x_from=-x_half, x_to=x_half)

    # the four bounding planes
    plan.hline(draw, float(c["FIELD_LAW_Z"]), FIELD_LAW, width=max(3, ppm // 13))
    plan.hline(draw, float(c["GLASS_PLANE_Z"]), GLASS, width=max(2, ppm // 19))
    plan.hline(draw, float(frame["backdrop_z"]), BACKDROP, width=2, dash=(9, 6))
    plan.hline(draw, float(c["PROP_Z"]), PROPZ, width=1, dash=(2, 5))
    # the frame law: the authored half-span as the engine mounts it (x * x_scale)
    world_half = float(c["AUTHORED_HALF_X"]) * float(frame["x_scale"])
    for sx in (-1, 1):
        plan.vline(draw, sx * world_half, FRAME_LAW, width=max(2, ppm // 19))
        plan.vline(draw, sx * float(c["AUTHORED_HALF_X"]), AUTHORED_LAW, width=1, dash=(4, 6))

    # footprints: one rectangle per repeat instance, at true scale, slot-coloured
    for slot in plan.arena["slots"]:
        colour = SLOT_COLOURS.get(slot["slot"], INK)
        w = float(slot["footprint_parsed"]["w"])
        depth = float(slot["depth"])
        for inst in slot["instances"]:
            x_min, x_max = float(inst["x_min"]), float(inst["x_max"])
            fill = tuple(int(round(v * 0.55 + PANEL_BG[i] * 0.45)) for i, v in enumerate(colour))
            plan.rect(draw, x_min, x_max, float(inst["front_z"]), float(inst["back_z"]),
                      fill=fill, outline=colour, width=max(1, ppm // 30))
            rw = plan.px(x_max) - plan.px(x_min)
            rh = plan.py(float(inst["front_z"])) - plan.py(float(inst["back_z"]))
            if rw >= 20 and rh >= 13:
                halo_text(draw, (plan.px((x_min + x_max) / 2), plan.py(float(inst["cz"])),),
                          str(inst["i"]), dot_font, INK, anchor="mm")
            # the true anchor: a dot at the anchor's own x/z
            ax, az = plan.px(float(inst["cx"])), plan.py(float(inst["cz"]))
            draw.ellipse([ax - 2, az - 2, ax + 2, az + 2], fill=colour)

    # slot labels, fanned into the free gap between the field-law plane and the band
    rows = [-8.35, -8.95, -9.55, -10.05]
    gap = 6 if not compact else 5
    stats = {"labels": 0, "fallback": 0, "rows_used": set(), "clipped": 0}
    occupied: dict[int, list[tuple[float, float]]] = {i: [] for i in range(len(rows))}
    slots_sorted = sorted(plan.arena["slots"], key=lambda s: float(
        sum(float(i["cx"]) for i in s["instances"]) / len(s["instances"])))
    for slot in slots_sorted:
        colour = SLOT_COLOURS.get(slot["slot"], INK)
        cent_x = sum(float(i["cx"]) for i in slot["instances"]) / len(slot["instances"])
        text = "%s \u00d7%d" % (slot["slot"], int(slot["repeats"]))
        tw = text_w(draw, text, label_font)
        placed = False
        for ri, rz in enumerate(rows):
            span = occupied[ri]
            for cand in _candidates(plan.px(cent_x) - tw / 2, tw, plan.ox + 4, plan.ox + plan.w - 4):
                if all(cand + tw + gap <= a or cand >= b + gap for a, b in span):
                    span.append((cand, cand + tw))
                    y = plan.py(rz)
                    draw.line([(cand + tw / 2, y + 10), (plan.px(cent_x), plan.py(float(slot["anchor"]["z"])))],
                              fill=colour, width=1)
                    halo_text(draw, (cand, y), text, label_font, colour)
                    placed = True
                    stats["labels"] += 1
                    stats["rows_used"].add(ri)
                    if cand < plan.ox + 4 or cand + tw > plan.ox + plan.w - 4:
                        stats["clipped"] += 1
                    break
            if placed:
                break
        if not placed:  # never silent: the label lands on the last row anyway
            y = plan.py(rows[-1])
            halo_text(draw, (plan.px(cent_x) - tw / 2, y), text, label_font, colour)
            draw.line([(plan.px(cent_x), y + 10), (plan.px(cent_x), plan.py(float(slot["anchor"]["z"])))],
                      fill=colour, width=1)
            stats["labels"] += 1
            stats["fallback"] += 1

    # plane captions
    cap = label_font
    cap_y = {"field": float(c["FIELD_LAW_Z"]), "glass": float(c["GLASS_PLANE_Z"]),
             "back": float(frame["backdrop_z"]), "propz": float(c["PROP_Z"])}
    halo_text(draw, (plan.ox + 6, plan.py(cap_y["field"]) - 20), "FIELD LAW  z = %+.2f — nothing crosses"
              % float(c["FIELD_LAW_Z"]), cap, FIELD_LAW)
    halo_text(draw, (plan.ox + 6, plan.py(cap_y["glass"]) - 20), "rear glass (measured)  z = %+.2f"
              % float(c["GLASS_PLANE_Z"]), cap, GLASS)
    halo_text(draw, (plan.ox + 6, plan.py(cap_y["back"]) - 20), "backdrop wall  z = %+.2f"
              % float(frame["backdrop_z"]), cap, BACKDROP)
    halo_text(draw, (plan.ox + plan.w - 6, plan.py(cap_y["propz"]) - 20),
              "default prop z = %+.2f" % float(c["PROP_Z"]), cap, PROPZ, anchor="ra")
    halo_text(draw, (plan.px(world_half) - 8, plan.py(float(frame["backdrop_z"])) + 6),
              "frame law  x = \u00b1%.3f m world" % world_half, cap, FRAME_LAW, anchor="ra")
    halo_text(draw, (plan.px(-world_half) + 8, plan.py(float(c["GLASS_PLANE_Z"])) + 6),
              "= authored \u00b1%.2f \u00d7 x_scale %.5f" % (float(c["AUTHORED_HALF_X"]), float(frame["x_scale"])),
              cap, AUTHORED_LAW)

    # scale bar + axes
    bar_m = 5.0
    bx, by = plan.ox + 10, plan.oy + plan.h - 26
    draw.line([(bx, by), (bx + bar_m * ppm, by)], fill=INK, width=3)
    for ex in (bx, bx + bar_m * ppm):
        draw.line([(ex, by - 5), (ex, by + 5)], fill=INK, width=2)
    halo_text(draw, (bx + bar_m * ppm / 2, by - 19), "%.0f m" % bar_m, tick_font, INK, anchor="ma")
    if not compact:
        step = 5.0
        xv = math.ceil(plan.x0 / step) * step
        while xv <= plan.x1:
            halo_text(draw, (plan.px(xv), plan.oy + plan.h - 8), "%+g" % xv, tick_font, INK_FAINT, anchor="ma")
            xv += step
        zv = math.ceil(plan.z0 / 2.0) * 2.0
        while zv <= plan.z1:
            if abs(zv) > 0.1:
                halo_text(draw, (plan.ox + 4, plan.py(zv)), "%+g" % zv, tick_font, INK_FAINT)
            zv += 2.0
    draw.text((plan.ox + 6, plan.oy + 4), "+x \u2192   \u2191 \u2212z (rear of court)", font=tick_font, fill=INK_DIM)
    return stats


def _candidates(start: float, width: float, lo: float, hi: float):
    """Label x positions to try in a row: the ideal spot, then small right/left steps."""
    out = []
    for delta in (0, 12, -12, 26, -26, 42, -42, 60, -60, 84, -84, 110, -110):
        cand = start + delta
        cand = max(lo, min(cand, hi - width))
        if cand not in out:
            out.append(cand)
    return out


def draw_legend_column(img, draw, plan: Plan, d: dict, origin, box, *, title_font,
                       label_font, small_font, mono_font):
    """The right-hand column: title, instance total, per-slot table, plane key, provenance."""
    x, y = origin
    w = box
    c = d["constants"]
    frame = d["frame"]
    arena = plan.arena
    world_half = float(c["AUTHORED_HALF_X"]) * float(frame["x_scale"])

    halo_text(draw, (x, y), arena["id"].upper(), title_font, INK)
    y += 34
    halo_text(draw, (x, y), "world deck \u2014 10 kit slots, %d instances on the map" % arena["instances_total"],
              label_font, INK_DIM)
    y += 22
    halo_text(draw, (x, y), "top-down, true metre scale (world m), camera preset \u201c%s\u201d" % frame["preset"],
              small_font, INK_FAINT)
    y += 28

    # provenance block
    for line in [
        "probe  $GODOT --headless --path godot/",
        "       --script res://tests/arena_kit_specs_dump.gd",
        "spec   res://game/arenas/arena_kit.gd  (SPECS 5\u00d710)",
        "court  %s  %g \u00d7 %g m" % (d["court"]["source"], d["court"]["court_len_x"], d["court"]["court_depth_z"]),
        "dump   sha256 %s" % d["_digest"][:16],
    ]:
        halo_text(draw, (x, y), line, mono_font, INK_FAINT)
        y += 15
    y += 10

    # the per-slot table
    cols = [("slot", 0), ("\u00d7n", 150), ("auth. x", 186), ("z", 246), ("w\u00d7d", 292),
            ("h", 342), ("front z", 372)]
    halo_text(draw, (x, y), "SLOT TABLE \u2014 every drawn instance traces to these numbers", small_font, INK_DIM)
    y += 18
    for name, dx in cols:
        halo_text(draw, (x + dx, y), name, small_font, INK_FAINT)
    y += 16
    draw.line([(x, y), (x + w, y)], fill=INK_FAINT, width=1)
    y += 4
    for slot in arena["slots"]:
        colour = SLOT_COLOURS.get(slot["slot"], INK)
        flag = "" if (slot["field_law_ok"] and slot["glass_ok"] and slot["frame_run_ok"]
                      and slot["frame_rect_authored_ok"] and slot["footprint_matches_spec"]) else "  !! see result"
        draw.rectangle([x, y + 4, x + 9, y + 13], fill=colour)
        halo_text(draw, (x + 15, y), slot["slot"], small_font, INK)
        for name, dx in cols[1:]:
            val = {
                "\u00d7n": "%d" % slot["repeats"],
                "auth. x": "%+.2f" % slot["anchor"]["x"],
                "z": "%+.2f" % slot["anchor"]["z"],
                "w\u00d7d": "%.2f\u00d7%.2f" % (slot["footprint_parsed"]["w"], slot["depth"]),
                "h": "%.2f" % slot["target_h"],
                "front z": "%+.2f" % slot["front_z"],
            }[name]
            halo_text(draw, (x + dx, y), val, small_font, INK_DIM)
        if flag:
            halo_text(draw, (x + w - 4, y), flag, small_font, FIELD_LAW, anchor="ra")
        y += 17
    y += 8

    # plane key
    halo_text(draw, (x, y), "PLANES AND LIMITS", small_font, INK_DIM)
    y += 18
    keys = [
        (FIELD_LAW, "field law plane, z = %+.2f (hard: nothing crosses it)" % float(c["FIELD_LAW_Z"])),
        (GLASS, "rear glass plane, z = %+.2f (measured; the stricter gate)" % float(c["GLASS_PLANE_Z"])),
        (BACKDROP, "backdrop wall, z = %+.2f" % float(frame["backdrop_z"])),
        (PROPZ, "default prop z = %+.2f (the spec table's own band)" % float(c["PROP_Z"])),
        (COURT_LINE, "court bed, lines, net (z = 0) and cage \u2014 %g \u00d7 %g m"
         % (d["court"]["court_len_x"], d["court"]["court_depth_z"])),
        (FRAME_LAW, "authored frame law x = \u00b1%.2f m \u00d7 x_scale %.5f = \u00b1%.3f m world"
         % (float(c["AUTHORED_HALF_X"]), float(frame["x_scale"]), world_half)),
        (AUTHORED_LAW, "authored \u00b1%.2f m unscaled (where the table's own x would land)"
         % float(c["AUTHORED_HALF_X"])),
        (INK, "slot markers: filled box = one instance's declared footprint (x-extent \u00d7 depth),"),
        (INK, "dot = its true anchor, \u00b7n\u00b7 = instance index (repeats run along x by \u2018spread\u2019)"),
    ]
    for colour, line in keys:
        draw.rectangle([x, y + 3, x + 22, y + 8], fill=colour)
        halo_text(draw, (x + 30, y), line, small_font, INK_FAINT)
        y += 17
    y += 8
    halo_text(draw, (x, y), "DEPTH BUDGET  %.2f m per slot at prop z  \u2014  front face = anchor.z + depth/2"
              % float(c["DEPTH_BUDGET"]), small_font, INK_DIM)
    y += 17
    halo_text(draw, (x, y), "field-law violations on this map: %d   \u00b7   instances: %d"
              % (d["_law_violations"].get(arena["id"], 0), arena["instances_total"]), small_font,
              FIELD_LAW if d["_law_violations"].get(arena["id"]) else INK_FAINT)


# ---------------------------------------------------------------------------- sheets


def render_panel(arena_id: str, d: dict, ppm: int, *, standalone: bool) -> tuple[Image.Image, dict]:
    arena = next(a for a in d["arenas"] if a["id"] == arena_id)
    c = d["constants"]
    frame = d["frame"]
    world_half = float(c["AUTHORED_HALF_X"]) * float(frame["x_scale"])
    x_range = (-(world_half + 1.6), world_half + 1.6)
    z_range = (-13.4, float(d["court"]["half_depth_z"]) + 0.9)

    title_font = font("bold", 30 if standalone else 20)
    label_font = font("bold", 15 if standalone else 12)
    small_font = font("regular", 14 if standalone else 11)
    tick_font = font("regular", 13 if standalone else 10)
    dot_font = font("bold", 12 if standalone else 9)
    mono_font = font("mono", 12 if standalone else 10)

    margin = 26
    head = 92 if standalone else 40
    legend_w = 470 if standalone else 0
    map_w = int(round((x_range[1] - x_range[0]) * ppm))
    map_h = int(round((z_range[1] - z_range[0]) * ppm))
    W = margin + map_w + (24 + legend_w if standalone else 0) + margin
    H = head + map_h + (34 if standalone else 22)

    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle([margin, head, margin + map_w, head + map_h], fill=PANEL_BG)

    plan = Plan(arena, d, ppm, x_range, z_range, (margin, head))
    stats = draw_map(draw, plan, d, label_font=label_font, tick_font=tick_font, dot_font=dot_font,
                     compact=not standalone)
    stats["slots"] = len(arena["slots"])
    stats["instances"] = int(arena["instances_total"])

    if standalone:
        halo_text(draw, (margin, 16), "%s \u2014 ARENA KIT PRE-VIZ PLAN" % arena["id"].upper(),
                  title_font, INK)
        halo_text(draw, (margin, 52),
                  "every slot, every repeat instance, at the engine's own metres \u2014 %d instances "
                  "across 10 slots" % arena["instances_total"], small_font, INK_DIM)
        draw_legend_column(img, draw, plan, d,
                           (margin + map_w + 24, head + 6), legend_w - 24,
                           title_font=title_font, label_font=label_font, small_font=small_font,
                           mono_font=mono_font)
        halo_text(draw, (margin + map_w + 24, H - 26),
                  "generated by tools/arena-kit/previz_2d.py from the engine dump \u2014 %s"
                  % d["_generated"], font("regular", 11), INK_FAINT)
    else:
        halo_text(draw, (margin, 10), "%s \u2014 %d instances" % (arena["id"].upper(), arena["instances_total"]),
                  title_font, INK)
    return img, stats


def render_sheet(d: dict) -> Image.Image:
    ppm = 28
    margin = 24
    rendered = [render_panel(a["id"], d, ppm, standalone=False) for a in d["arenas"]]
    panels = [r[0] for r in rendered]
    for arena, r in zip(d["arenas"], rendered):
        print("  sheet cell %-8s labels %d/%d, row fallback %d, clipped %d"
              % (arena["id"], r[1]["labels"], r[1]["slots"], r[1]["fallback"], r[1]["clipped"]))
    cols, rows = 2, 3
    col_w = max(p.width for p in panels)
    row_h = max(p.height for p in panels)
    W = margin * (cols + 1) + col_w * cols
    H = 104 + margin * (rows + 1) + row_h * rows
    sheet = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(sheet)
    halo_text(draw, (margin, 22), "ARENA KIT \u2014 ALL FIVE WORLD ARENAS, DENSE 2D PRE-VIZ",
              font("bold", 34), INK)
    halo_text(draw, (margin, 64), "torii \u00b7 medina \u00b7 carioca \u00b7 aurora \u00b7 egeo \u2014 "
              "%d instances in total, true metre scale, generated from the engine's own spec table"
              % sum(d["instance_totals"].values()), font("regular", 16), INK_DIM)
    cells = [(margin + (i % cols) * (col_w + margin), 104 + margin + (i // cols) * (row_h + margin))
             for i in range(cols * rows)]
    for panel, (cx, cy) in zip(panels, cells):
        sheet.paste(panel, (cx, cy))
    # the sixth cell: totals, key, provenance
    x, y = cells[5]
    small = font("regular", 13)
    mono = font("mono", 11)
    title = font("bold", 22)
    halo_text(draw, (x, y + 6), "WHAT IS DRAWN", title, INK)
    y += 40
    for arena in d["arenas"]:
        halo_text(draw, (x, y), "%-9s %2d slots  %2d instances" % (arena["id"], len(arena["slots"]),
                                                                  arena["instances_total"]), small, INK_DIM)
        y += 19
    y += 6
    for colour, line in [
        (FIELD_LAW, "field law plane z = %+.2f \u2014 nothing crosses (0 violations on all five maps)" % float(d["constants"]["FIELD_LAW_Z"])),
        (GLASS, "rear glass plane z = %+.2f (measured, the stricter gate)" % float(d["constants"]["GLASS_PLANE_Z"])),
        (BACKDROP, "backdrop wall z = %+.2f  \u00b7  prop z = %+.2f" % (float(d["frame"]["backdrop_z"]), float(d["constants"]["PROP_Z"]))),
        (FRAME_LAW, "authored frame law x = \u00b1%.2f m \u00d7 x_scale %.5f = \u00b1%.3f m world"
         % (float(d["constants"]["AUTHORED_HALF_X"]), float(d["frame"]["x_scale"]),
            float(d["constants"]["AUTHORED_HALF_X"]) * float(d["frame"]["x_scale"]))),
        (COURT_LINE, "court bed %g \u00d7 %g m, net at z = 0, service lines at z = \u00b1%g m"
         % (d["court"]["court_len_x"], d["court"]["court_depth_z"], d["court"]["service_z"])),
    ]:
        draw.rectangle([x, y + 3, x + 22, y + 8], fill=colour)
        halo_text(draw, (x + 30, y), line, small, INK_FAINT)
        y += 19
    y += 6
    halo_text(draw, (x, y), "each box = one instance's declared footprint (x-extent \u00d7 depth),", small, INK_FAINT)
    y += 18
    halo_text(draw, (x, y), "dot = true anchor, \u00b7n\u00b7 = instance index, label = slot \u00d7 repeats", small, INK_FAINT)
    y += 22
    for line in [
        "probe  $GODOT --headless --path godot/ --script res://tests/arena_kit_specs_dump.gd",
        "spec   res://game/arenas/arena_kit.gd SPECS 5\u00d710   \u00b7   court res://game/court.gd",
        "dump   sha256 %s   \u00b7   %s" % (d["_digest"][:16], d["_generated"]),
        "made   tools/arena-kit/previz_2d.py",
    ]:
        halo_text(draw, (x, y), line, mono, INK_FAINT)
        y += 16
    return sheet


# ---------------------------------------------------------------------------- html


def build_html(d: dict, images: dict[str, bytes], digest: str) -> str:
    def b64(png: bytes) -> str:
        return base64.b64encode(png).decode("ascii")

    ids = [a["id"] for a in d["arenas"]]
    buttons = "".join(
        '<button class="tab" data-id="%s">%s<span class="n">%d</span></button>' % (i, i, d["instance_totals"][i])
        for i in ids)
    buttons += '<button class="tab" data-id="all">all five<span class="n">%d</span></button>' % sum(
        d["instance_totals"].values())
    panes = "".join(
        '<figure class="pane%s" data-id="%s"><img alt="%s arena kit plan" src="data:image/png;base64,%s">'
        '<figcaption>%s \u2014 %d instances across 10 slots</figcaption></figure>'
        % (" active" if i == ids[0] else "", i, i, b64(images[i]), i, d["instance_totals"][i])
        for i in ids)
    panes += ('<figure class="pane" data-id="all"><img alt="all five arena plans" '
              'src="data:image/png;base64,%s"><figcaption>all five arenas \u2014 %d instances</figcaption></figure>'
              % (b64(images["all"]), sum(d["instance_totals"].values())))
    rows = "".join(
        "<tr><td>%s</td><td>%d</td><td>%d</td><td>%s</td><td>%s</td></tr>"
        % (html.escape(a["id"]), len(a["slots"]), a["instances_total"],
           ", ".join("%s\u00d7%d" % (s["slot"], s["repeats"]) for s in a["slots"][:4]) + ", \u2026",
           "0")
        for a in d["arenas"])
    return """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Arena kit \u2014 2D pre-viz plans, all five world arenas</title>
<style>
 :root { --bg:#0d141c; --panel:#131c26; --ink:#e9f0f8; --dim:#96a3b2; --faint:#687482;
         --law:#ff5252; --glass:#4fc3f7; --frame:#ffb300; }
 * { box-sizing:border-box; }
 body { margin:0; background:var(--bg); color:var(--ink);
        font:15px/1.5 -apple-system,Segoe UI,Helvetica,Arial,sans-serif; }
 header { padding:26px 30px 14px; }
 h1 { margin:0 0 6px; font-size:24px; letter-spacing:.2px; }
 .sub { color:var(--dim); max-width:110ch; }
 .tabs { display:flex; flex-wrap:wrap; gap:8px; padding:14px 30px 6px; }
 .tab { background:var(--panel); color:var(--ink); border:1px solid #23303d; border-radius:999px;
        padding:9px 16px; font-size:15px; cursor:pointer; text-transform:none; }
 .tab:hover { border-color:#3b4c5e; }
 .tab.active { background:#1d3a54; border-color:var(--glass); color:#fff; }
 .tab .n { display:inline-block; margin-left:8px; font-size:12px; color:var(--dim); }
 .stage { padding:8px 30px 4px; }
 .pane { display:none; margin:0; }
 .pane.active { display:block; }
 .pane img { width:100%%; height:auto; border:1px solid #23303d; border-radius:8px;
             background:#0f1720; }
 figcaption { color:var(--faint); font-size:13px; padding:6px 2px 0; }
 section { padding:14px 30px 30px; display:grid; gap:18px;
           grid-template-columns:minmax(320px,1fr) minmax(320px,1fr); align-items:start; }
 @media (max-width:900px){ section{ grid-template-columns:1fr; } }
 .card { background:var(--panel); border:1px solid #23303d; border-radius:10px; padding:16px 18px; }
 h2 { font-size:15px; margin:0 0 10px; color:var(--dim); text-transform:uppercase; letter-spacing:.8px; }
 table { border-collapse:collapse; width:100%%; font-size:14px; }
 td,th { text-align:left; padding:5px 8px; border-bottom:1px solid #1d2833; }
 th { color:var(--faint); font-weight:600; }
 code, pre { font:12px/1.5 ui-monospace,Menlo,monospace; color:var(--dim); }
 pre { margin:0; white-space:pre-wrap; word-break:break-word; }
 .pill { display:inline-block; padding:2px 8px; border-radius:999px; font-size:12px;
         border:1px solid #23303d; color:var(--dim); }
 .ok { color:#7bd88f; }
 .law { color:var(--law); }
 ul { margin:6px 0 0; padding-left:18px; color:var(--dim); }
</style></head>
<body>
<header>
  <h1>Arena kit \u2014 the dense 2D pre-viz plans</h1>
  <div class="sub">Every slot and every repeat instance of the five world arenas, drawn at
  the engine's own metres from <code>res://game/arenas/arena_kit.gd</code>. The plan is the
  dense view; the 3D scene stays uncluttered. Click an arena, or press <b>1</b>\u2013<b>5</b>.
  Images are embedded in this file \u2014 no build step, no network.</div>
</header>
<nav class="tabs">%s</nav>
<main class="stage">%s</main>
<section>
  <div class="card">
    <h2>Instance totals</h2>
    <table><thead><tr><th>arena</th><th>slots</th><th>instances</th><th>first slots</th><th>field-law breaks</th></tr></thead>
    <tbody>%s</tbody></table>
    <p><span class="pill">total %d instances</span> <span class="pill ok">0 field-law breaks</span>
    <span class="pill">0 outside the frame law</span> <span class="pill">0 over the depth budget</span></p>
  </div>
  <div class="card">
    <h2>Provenance</h2>
    <pre>probe   %s

spec    res://game/arenas/arena_kit.gd   SPECS 5 x 10
court   %s   %g x %g m, net z = 0, service z = \u00b1%g m
dump    sha256 %s
godot   %s
made    tools/arena-kit/previz_2d.py   \u00b7   %s</pre>
    <h2 style="margin-top:14px">How to read a plan</h2>
    <ul>
      <li>one box = one instance's declared footprint: x-extent (from the footprint note) by <code>depth</code>, at true scale</li>
      <li>dot = its true anchor; <code>n</code> inside the box = instance index; repeats run along x by <code>spread</code></li>
      <li>label = slot \u00d7 repeats; the right-hand table carries every drawn number</li>
      <li><span class="law">field law</span> z = %+.2f is hard, the <span style="color:var(--glass)">rear glass</span> z = %+.2f is measured and stricter</li>
      <li>the frame law is drawn where the engine mounts it: authored \u00b1%.2f m \u00d7 x_scale %.5f = \u00b1%.3f m world</li>
    </ul>
  </div>
</section>
<script>
 const tabs = [...document.querySelectorAll('.tab')];
 const panes = [...document.querySelectorAll('.pane')];
 function show(id){
   tabs.forEach(t => t.classList.toggle('active', t.dataset.id === id));
   panes.forEach(p => p.classList.toggle('active', p.dataset.id === id));
 }
 tabs.forEach(t => t.addEventListener('click', () => show(t.dataset.id)));
 addEventListener('keydown', e => {
   const n = parseInt(e.key, 10);
   if (n >= 1 && n <= tabs.length) show(tabs[n-1].dataset.id);
 });
 show(tabs[0].dataset.id);
</script>
</body></html>
""" % (buttons, panes, rows, sum(d["instance_totals"].values()), html.escape(PROBE_CMD),
       html.escape(d["court"]["source"]), d["court"]["court_len_x"], d["court"]["court_depth_z"],
       d["court"]["service_z"], digest, html.escape(d["godot"]), d["_generated"],
       float(d["constants"]["FIELD_LAW_Z"]), float(d["constants"]["GLASS_PLANE_Z"]),
       float(d["constants"]["AUTHORED_HALF_X"]), float(d["frame"]["x_scale"]),
       float(d["constants"]["AUTHORED_HALF_X"]) * float(d["frame"]["x_scale"]))


# ---------------------------------------------------------------------------- main


def main(argv: list[str]) -> int:
    src = Path(argv[1]) if len(argv) > 1 else DEFAULT_LOG
    if not src.exists():
        raise SystemExit("FATAL: no dump at %s — run the probe first (see module docstring)" % src)
    d, digest, _raw = extract_dump(src)
    problems = verify(d)
    if problems:
        for p in problems:
            print("VERIFY FAIL: %s" % p)
        return 2
    d["_digest"] = digest
    d["_generated"] = _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    d["_source"] = str(src)
    d["_law_violations"] = {
        a["id"]: sum(1 for s in a["slots"] if not (s["field_law_ok"] and
                                                   float(s["front_z"]) <= float(d["constants"]["FIELD_LAW_Z"])))
        for a in d["arenas"]}
    PREVIZ.mkdir(parents=True, exist_ok=True)

    pngs: dict[str, bytes] = {}
    for arena in d["arenas"]:
        img, stats = render_panel(arena["id"], d, 42, standalone=True)
        out = PREVIZ / ("%s-plan.png" % arena["id"])
        img.save(out)
        pngs[arena["id"]] = out.read_bytes()
        print("wrote %s  %dx%d  labels %d/%d slots  fallback %d  clipped %d"
              % (out.relative_to(REPO), img.width, img.height, stats["labels"], stats["slots"],
                 stats["fallback"], stats["clipped"]))
    sheet = render_sheet(d)
    sheet_path = PREVIZ / "all-five-arenas-plan.png"
    sheet.save(sheet_path)
    pngs["all"] = sheet_path.read_bytes()
    print("wrote %s  %dx%d" % (sheet_path.relative_to(REPO), sheet.width, sheet.height))

    (PREVIZ / "index.html").write_text(build_html(d, pngs, digest))
    table = {
        "probe_command": PROBE_CMD,
        "dump": {"source": str(src), "sha256": digest, "godot": d["godot"]},
        "constants": d["constants"],
        "court": d["court"],
        "frame": d["frame"],
        "instance_totals": d["instance_totals"],
        "instances": [
            {"arena": a["id"], "slot": s["slot"], "i": inst["i"],
             "authored_x": inst["ax"], "world_x": inst["cx"], "z": inst["cz"],
             "footprint_w": s["footprint_parsed"]["w"], "depth": s["depth"],
             "target_h": s["target_h"], "spread": s["spread"],
             "front_z": inst["front_z"], "back_z": inst["back_z"],
             "x_min": inst["x_min"], "x_max": inst["x_max"],
             "field_law_ok": s["field_law_ok"], "glass_ok": s["glass_ok"],
             "frame_run_ok": s["frame_run_ok"], "frame_rect_authored_ok": s["frame_rect_authored_ok"],
             "frame_rect_world_ok": s["frame_rect_world_ok"], "depth_ok": s["depth_ok"]}
            for a in d["arenas"] for s in a["slots"] for inst in s["instances"]
        ],
    }
    (PREVIZ / "plan-data.json").write_text(json.dumps(table, indent=2, sort_keys=True) + "\n")
    print("wrote %s  (%d instances)" % ((PREVIZ / "plan-data.json").relative_to(REPO),
                                        len(table["instances"])))
    print("instances per arena: %s  total %d" % (d["instance_totals"], sum(d["instance_totals"].values())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
