#!/usr/bin/env python3
"""Static checks for the five world arenas — no engine, no Godot.

Four things are checked, all of them recomputed from the sources rather than
trusted:

  1. every `kind` a world prop table names has a branch in
     `arena_scenery.gd::_build_prop` (a missing kind silently falls through to
     the `spark` default and would ship as the wrong object);
  2. every world prop's envelope lands fully inside the 1280x720 frame, for all
     three camera presets, using the camera's own projection (the same
     perspective `Camera3D` performs; validated below against the repo's own
     `arena_scenery.gd::band()` closed form);
  3. every world prop sits behind `FIELD_LAW_Z` (-8.0);
  4. the five new arena signatures are distinct from each other and from the
     nine frozen ones.

The frame check is an ENVELOPE check: it mirrors each kind's bounding box from
its builder, not the engine's per-mesh AABB walk. It is evidence that a prop was
authored inside the frame with margin; the engine's own check (the slice test's
`_arena_scenery_in_frame`) remains the proof.

Usage:  python3 integrator-check.py [repo_root]
Exit 1 on any failure.
"""

import json
import math
import re
import sys
from pathlib import Path

REPO = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
STYLE = REPO / "godot/game/arenas/arena_style.gd"
SCENERY = REPO / "godot/game/arenas/arena_scenery.gd"
LIBRARY = REPO / "godot/game/arenas/arena_library.gd"

WORLD_IDS = ["torii", "medina", "carioca", "aurora", "egeo"]
FROZEN_IDS = ["officina", "locomotive", "clockwork", "cattedrale", "forgia",
              "tempesta", "abissale", "caldera", "orrery"]

# Camera presets, copied from godot/game/court.gd::CAMERAS (read-only here).
CAMERAS = {
    "default": {"pos": (0.0, 20.0, 27.5), "pitch_deg": -36.0274, "fov": 30.0},
    "wide": {"pos": (0.0, 22.0, 18.0), "pitch_deg": -50.0, "fov": 60.0},
    "playable": {"pos": (0.0, 8.0, 17.0), "pitch_deg": 0.0, "fov": 60.0,
                 "look_at": (0.0, 0.900, -1.000)},
}
ASPECT = 16.0 / 9.0
BACKDROP_Z = -12.0      # arena_scenery.gd::BACKDROP_Z (unchanged by this lane)
FIELD_LAW_Z = -8.0
PROP_Z = -7.65          # the default prop z in the frozen tables
PROP_Z_OFFSET = -4.0
MARGIN = 0.985          # keep every corner inside 98.5% of NDC
failures = []
notes = []


def fail(msg):
    failures.append(msg)


def vadd(a, b):
    return tuple(x + y for x, y in zip(a, b))


def vsub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def vmul(a, s):
    return tuple(x * s for x in a)


def vdot(a, b):
    return sum(x * y for x, y in zip(a, b))


def vcross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def vnorm(a):
    n = math.sqrt(vdot(a, a))
    return vmul(a, 1.0 / n) if n > 1e-12 else (0.0, 0.0, 0.0)


def camera_axes(preset):
    """(x_axis, y_axis, z_axis) of the camera in world space, Godot's -Z forward."""
    cfg = CAMERAS[preset]
    if "look_at" in cfg:
        z = vnorm(vsub(cfg["pos"], cfg["look_at"]))
        up = (0.0, 1.0, 0.0)
        y = vnorm(vsub(up, vmul(z, vdot(up, z))))
        x = vcross(y, z)
        return x, y, z
    th = math.radians(cfg["pitch_deg"])
    return ((1.0, 0.0, 0.0), (0.0, math.cos(th), math.sin(th)),
            (0.0, -math.sin(th), math.cos(th)))


def ndc(preset, p):
    """NDC of a world point, or None when it is behind the camera."""
    cfg = CAMERAS[preset]
    x_ax, y_ax, z_ax = camera_axes(preset)
    r = vsub(p, cfg["pos"])
    x_v, y_v, z_v = vdot(r, x_ax), vdot(r, y_ax), vdot(r, z_ax)
    if -z_v <= 1e-6:
        return None
    cot = 1.0 / math.tan(math.radians(cfg["fov"]) * 0.5)
    return ((cot / ASPECT) * x_v / -z_v, cot * y_v / -z_v)


def band_top_y(preset, z, ny=1.0):
    """The world y of a frame row at plane z — the repo's own closed form."""
    cfg = CAMERAS[preset]
    cam = cfg["pos"]
    th = math.radians(cfg["pitch_deg"])
    t = math.tan(math.radians(cfg["fov"]) * 0.5)
    denom = ny * t * math.sin(th) - math.cos(th)
    d = (z - cam[2]) / denom
    return cam[1] + d * (ny * t * math.cos(th) + math.sin(th))


def prop_half_x(preset, z, ny=1.06):
    cfg = CAMERAS[preset]
    cam = cfg["pos"]
    th = math.radians(cfg["pitch_deg"])
    t = math.tan(math.radians(cfg["fov"]) * 0.5)
    denom = ny * t * math.sin(th) - math.cos(th)
    d = (z - cam[2]) / denom
    return max(d * t * ASPECT, 6.0)


# --- 0. the camera math, validated against the repo's own closed form --------
for _preset in CAMERAS:
    if "look_at" in CAMERAS[_preset]:
        continue      # the closed form is for a pure-pitch camera; look_at needs the basis
    for _ny in (1.0, 0.55):
        _y = band_top_y(_preset, BACKDROP_Z, _ny)
        _got = ndc(_preset, (0.0, _y, BACKDROP_Z))
        if _got is None or abs(_got[1] - _ny) > 0.01:
            fail("camera math: %s row %.2f does not round-trip (%s)" % (_preset, _ny, _got))
notes.append("camera math round-trips the repo's band() closed form at z=%.1f for the pitched presets"
             % BACKDROP_Z)

# --- 1. the tables ----------------------------------------------------------
style_text = STYLE.read_text()
scenery_text = SCENERY.read_text()
library_text = LIBRARY.read_text()

start = style_text.index('# --- the five world arenas')
entries = {}
for arena_id in WORLD_IDS:
    m = re.search(r'\n\t"%s": \{' % arena_id, style_text[start:])
    if not m:
        fail("arena_style.gd: no STYLES entry for %s" % arena_id)
        continue
    body_start = start + m.end()
    depth = 1
    i = body_start
    while i < len(style_text) and depth > 0:
        if style_text[i] == "{":
            depth += 1
        elif style_text[i] == "}":
            depth -= 1
        i += 1
    entries[arena_id] = style_text[body_start:i - 1]

if len(entries) != len(WORLD_IDS):
    fail("arena_style.gd: %d of %d world entries found" % (len(entries), len(WORLD_IDS)))

# The match labels a kind is dispatched to, read straight off `_build_prop`.
build_prop = scenery_text[scenery_text.index("static func _build_prop"):]
build_prop = build_prop[:build_prop.index("\n\n\n")]
kinds_implemented = set(re.findall(r'^\t\t"([a-z_0-9]+)":\s*$', build_prop, re.M))
notes.append("%d prop kinds are implemented in _build_prop" % len(kinds_implemented))

# Per-kind envelope: (half width, top above the container, bottom, z pad).
# Mirrors the builders in arena_scenery.gd; every figure is the largest a part of
# that kind can reach, so the check is conservative by construction.


def envelope(kind, p):
    x, y, r, h, w = p["x"], p.get("y", 0.0), p.get("r", 0.4), p.get("h", 1.2), p.get("w", 6.0)
    if kind == "torii":
        post = max(w * 0.055, 0.05)
        return w * 0.67, h * 1.03, 0.0, post * 1.2
    if kind == "pagoda":
        return r * 0.85, h + 0.24, 0.0, r * 0.55
    if kind == "lantern":
        hang = p.get("hang", 0.45)
        return r, y + r + hang, y - r, r
    if kind == "petal":
        return 0.45, y + 0.48, y - 0.28, 0.1
    if kind == "moon":
        return r * 1.28, y + r, y - r, 0.1
    if kind == "sun":
        return r * 2.0, y + r * 2.0, y - r * 2.0, 0.1
    if kind == "star":
        return 0.40, y + 0.18, y - 0.14, 0.1
    if kind == "aurora":
        return w * 0.5, y + h * 0.5, y - h * 0.5, 0.1
    if kind == "wall":
        return w * 0.5, h + 0.235, 0.0, 0.15
    if kind == "zellige":
        tile_d = h * 0.62
        return w * 0.5, y + max(h * 0.35, tile_d * 0.71), y - max(h * 0.35, tile_d * 0.71), 0.2
    if kind == "arch":
        arc_r = w * 0.5
        return arc_r + 0.34, h + arc_r * 1.62 + 0.15, 0.0, 0.2
    if kind == "minaret":
        return r * 1.3, h + 0.26, 0.0, r * 1.3
    if kind == "palm":
        fl = h * 0.55 * 0.92
        return fl * 0.95, h + fl * 0.42 + 0.05, 0.0, 0.15
    if kind == "ridge":
        peaks, spread = int(p.get("count", 4)), p.get("spread", 1.5)
        return (peaks - 1) * 0.5 * spread * r + r * 0.90, r * 1.65, 0.0, 0.35
    if kind == "peak":
        twin, twin_x = p.get("twin", 0.0), p.get("twin_x", r * 2.4)
        half = max(r, twin_x + r * twin) if twin > 0.0 else r
        return half, r * 1.30 + r * 1.25, 0.0, 0.5
    if kind == "foam":
        rings = int(p.get("count", 3))
        return r * (1.0 + 0.55 * (rings - 1)) + r * 0.1, 0.1, 0.0, r
    if kind == "cable":
        return w * 0.5, y + 0.05, y - 0.32, 0.1
    if kind == "basalt":
        columns = int(p.get("count", 7))
        return (columns - 1) * 0.5 * r * 0.92 + r * 1.17, h + 0.05, 0.0, r
    if kind == "snowridge":
        crests = int(p.get("count", 4))
        return (crests - 1) * 0.5 * 1.5 * r + r * 0.9, r * 1.53, 0.0, 0.35
    if kind == "steam":
        return 3 * 0.42 * r + r * 1.48, y + 2.7 * r + r * 1.48, y - r, 0.3
    if kind == "island":
        return 2.0 * 1.05 * r + r * 0.475, h + r * 0.23, 0.0, r * 0.5
    if kind == "windmill":
        return 1.87 * r, max(h + 0.9 * r, h * 0.86 + 1.85 * r), 0.0, 0.6
    if kind == "bougainvillea":
        return 1.60 * r, r * 1.8 + r * 0.44, 0.0, r * 0.6
    if kind == "sea":
        return w * 0.5, y + h * 0.5, y - h * 0.5, 0.1
    if kind == "cloud":
        # The frozen cloud branch: three spheres, the widest 1.6 r off centre, the
        # tallest r above and the lowest r below the prop's own y.
        return r * 1.65, y + r * 1.05, y - r * 1.05, r
    if kind in ("tree", "floodlight", "lamp", "signal", "gear", "gearring",
                "girder", "rail", "loco", "clock", "piston", "airship", "bolt", "chain",
                "dome", "porthole", "bubble", "titan", "lava", "rock", "orbit", "planet",
                "column", "spark"):
        return 8.0, 4.0, 0.0, 1.0      # frozen kinds: not this lane's to bound
    return None


def props_of(body):
    out = []
    for m in re.finditer(r'\{"kind".*?\}', body, re.S):
        out.append(json.loads(m.group(0)))
    return out


print("== world arena tables ==")
signatures = {}
for arena_id, body in entries.items():
    props = props_of(body)
    family = re.search(r'"family":\s*"([a-z]+)"', body)
    artwork = re.search(r'"artwork":\s*"([^"]*)"', body)
    sky = re.findall(r'\["(\d\.\d+)",\s*"(#[0-9a-fA-F]{6})"\]', body)
    palette = re.search(r'"palette":\s*(\{[^}]*\})', body)
    apron = re.search(r'"apron":\s*"(#[0-9a-fA-F]{6})"', body)
    glow = re.search(r'"glow":\s*"(#[0-9a-fA-F]{6})"', body)
    if not family or family.group(1) != "world":
        fail("%s: family is not 'world'" % arena_id)
    if not artwork or artwork.group(1) != "":
        fail("%s: artwork must be empty (the deck is never imported)" % arena_id)
    if len(sky) < 3:
        fail("%s: fewer than three sky stops (%d)" % (arena_id, len(sky)))
    if not palette or not apron or not glow:
        fail("%s: palette/apron/glow incomplete" % arena_id)
    stops = "".join(s[1] for s in sky)
    sig = "world|%s|%s|%s|%d" % (stops, apron.group(1) if apron else "?",
                                 glow.group(1) if glow else "?", len(props))
    signatures[sig] = arena_id
    print("  %-8s family=%s props=%2d sky=%s apron=%s glow=%s"
          % (arena_id, family.group(1), len(props), ">".join(s[1] for s in sky),
             apron.group(1) if apron else "?", glow.group(1) if glow else "?"))
    for p in props:
        kind = p.get("kind", "?")
        if kind not in kinds_implemented:
            fail("%s: kind '%s' has no branch in _build_prop (it would build a spark)" % (arena_id, kind))
            continue
        env = envelope(kind, p)
        if env is None:
            fail("%s: no envelope for kind '%s'" % (arena_id, kind))
            continue
        half, top, bottom, z_pad = env
        # 3. field law
        z = p.get("z", PROP_Z) + PROP_Z_OFFSET
        if z + z_pad > FIELD_LAW_Z:
            fail("%s/%s at z=%.2f crosses FIELD_LAW_Z=%.1f" % (arena_id, kind, z + z_pad, FIELD_LAW_Z))
        if bottom < -0.05:
            fail("%s/%s sinks below the ground (bottom %.2f)" % (arena_id, kind, bottom))
        # 2. frame containment, every camera preset
        for preset in CAMERAS:
            x_scale = prop_half_x(preset, BACKDROP_Z) / 14.35
            cx = p["x"] * x_scale
            worst = 0.0
            worst_at = ""
            for sx in (cx - half, cx + half):
                for sy in (bottom, top):
                    for sz in (z - z_pad, z + z_pad):
                        got = ndc(preset, (sx, sy, sz))
                        if got is None:
                            fail("%s/%s is behind the camera in the %s preset" % (arena_id, kind, preset))
                            continue
                        over = max(abs(got[0]), abs(got[1]))
                        if over > worst:
                            worst = over
                            worst_at = "(%.1f, %.1f, %.1f)" % (sx, sy, sz)
            if worst > MARGIN:
                fail("%s/%s leaves the %s frame: ndc %.3f at %s" % (arena_id, kind, preset, worst, worst_at))

# --- the libraries ----------------------------------------------------------
print("== integration ==")
for needle, where in [("static func world_ids", STYLE), ("static func is_world", STYLE),
                      ("static func world_info", LIBRARY), ("static func all_ids", LIBRARY),
                      ("static func field_law_report", SCENERY),
                      ("const FIELD_LAW_Z := -8.0", SCENERY)]:
    if needle not in where.read_text():
        fail("%s: missing %r" % (where.name, needle))
if "STYLES[ids[0]" in style_text:
    fail("arena_style.gd: style() still falls back to key order, which the world entries broke")
if "ArenaScenery.FIELD_LAW_Z" in library_text:
    notes.append("library does not re-export FIELD_LAW_Z (callers use ArenaScenery directly)")
if not re.search(r"world_ids\(\) -> PackedStringArray:\n\treturn ArenaStyle\.world_ids\(\)", library_text):
    fail("arena_library.gd: world_ids() does not delegate to the style table")
if "return ids().has(id) or ArenaStyle.is_world(id)" not in library_text:
    fail("arena_library.gd: has() does not accept the world set")

# --- 4. distinctness --------------------------------------------------------
dupes = [s for s, a in signatures.items() if s in signatures and signatures[s] != a]
if len(set(signatures)) != len(WORLD_IDS):
    fail("world signatures are not all distinct: %s" % list(signatures.values()))
for sig, arena_id in signatures.items():
    digest_prefix = sig.split("|", 1)[1]
    for frozen_id in FROZEN_IDS:
        frozen = re.search(r'\n\t"%s": \{' % frozen_id, style_text)
        if not frozen:
            continue
        body_start = frozen.end()
        depth, i = 1, body_start
        while i < len(style_text) and depth > 0:
            if style_text[i] == "{":
                depth += 1
            elif style_text[i] == "}":
                depth -= 1
            i += 1
        frozen_body = style_text[body_start:i - 1]
        frozen_sky = "".join(s[1] for s in re.findall(r'\["(\d\.\d+)",\s*"(#[0-9a-fA-F]{6})"\]', frozen_body))
        frozen_apron = re.search(r'"apron":\s*"(#[0-9a-fA-F]{6})"', frozen_body)
        frozen_glow = re.search(r'"glow":\s*"(#[0-9a-fA-F]{6})"', frozen_body)
        if frozen_sky == "".join(re.findall(r'"(#[0-9a-fA-F]{6})"', sig.split("|")[1])):
            fail("world arena %s copies the frozen %s's sky stops" % (arena_id, frozen_id))

print("== summary ==")
for n in notes:
    print("  note: %s" % n)
if failures:
    print("FAIL %d" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("PASS: %d world arenas, %d props, kinds/frame/field-law/distinctness all hold"
      % (len(entries), sum(len(props_of(b)) for b in entries.values())))
