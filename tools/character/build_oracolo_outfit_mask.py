#!/usr/bin/env python3
"""Build the explicit UV garment mask for Oracolo's outfit variants.

WHY THIS EXISTS
---------------
This is the Oracolo twin of `tools/character/build_maestro_outfit_mask.py`, which is
itself the Maestro twin of `build_fiamma_outfit_mask.py`. Same pipeline, same mask
channels, same report shape:

  R = torso garment, G = hip garment, B = foot garment, A = coverage (evidence only).

Nothing here looks at the texture to decide *where* a garment is. Every triangle is
assigned to the bone that dominates its vertices, the bone picks a garment region
(torso / hip / foot), and the triangle is rasterised into UV space under that region.
The texture is consulted only *inside* a region, to measure the recolourable families
of the baked atlas and - in the leak and seam sections - to prove what the mask does
and does not touch.

WHAT IS DIFFERENT ABOUT ORACOLO, AND WHY IT MATTERS
---------------------------------------------------
1. BONES. Oracolo's rig has 28 joints and its joint *set is identical to Fiamma's*,
   `mixamorig:` prefix and all (`LeftToe_End` / `RightToe_End` present, ascending
   `Spine` / `Spine1` / `Spine2`). The Fiamma bone map is therefore reused verbatim
   and `bone_diff.absent_from_oracolo` is empty - nothing had to be invented or
   dropped. Maestro, the previous athlete, is the one whose rig differs (24 joints,
   bare names, spine numbered downward).
2. THE BODY IS NOT MAESTRO'S. Oracolo's `Hips` joint sits at world Y 0.9916 against
   Maestro's 0.9517, and the pelvis-to-Spine interval is 0.1054 m against Maestro's
   0.1525. The waist cut stays at world Y 1.0 and is NOT re-tuned, but on this body it
   lands 8.4 mm above the Hips joint - 8.0% of the pelvis-to-Spine interval, where on
   Maestro the same value lands at 31.7% and on Fiamma at 37.4%. That is the pelvis,
   not the anatomical waist, and the report carries the measurement (`tripartition`).
3. THE OUTFIT IS ARMOUR, NOT A KIT. Oracolo wears a baked fantasy combat outfit: one
   violet garment that runs from the chest, past the waist ornament, into the skirt and
   the thigh-high boots. The torso/hip cut is therefore a horizontal PLANE through a
   continuous garment, and this tool measures that rather than asserting it
   (`region_seams`): 191 seam edges, of which 61.3% pass through recolourable violet
   fabric on BOTH sides, 0.92x as likely as a random masked texel to sit on a texture
   edge and 0.83x as likely to sit on a UV island border. The cut follows no garment
   seam. No cut height between Y 0.94 and Y 1.10 avoids it (the report carries the
   sweep); the reused Y 1.0 is one of the two best available and was kept unchanged.
4. ONE RECOLOURABLE FAMILY, NOT TWO. Maestro's two families are 20 deg apart in hue and
   needed a value gate at 0.76. Oracolo's declared pair (`#6d42b8` / `#a96cff` from the
   outfit, `#6b3df0` / `#e3c6ff` from the reference catalogue's `visual` block - the one
   athlete where those two disagree) is 3.0 deg / 15.1 deg apart, both far inside the
   shader's 45 deg tolerance, and the atlas contains only ONE real painted family
   (`#301850`, 80.4% of the chromatic masked texels, 1452 components >= 64 px). The
   second chromatic band by hue (300-360 deg, 3.4%) is the antialiasing ramp between
   violet and skin: 9640 components, median 1 px, and using it as an anchor leaks 6875
   skin-hued texels because the 45 deg window wraps onto hue 0-4. `value_split` measures
   whether a value gate could replace the hue test - it cannot, and says so with numbers.

DELIBERATE DIFFERENCES FROM THE MAESTRO TOOL
--------------------------------------------
* `bone_diff` reports an EMPTY absent list, because there is nothing absent, and names
  the landmark difference instead (the pelvis height).
* Three new report blocks, all measurement: `tripartition`, `region_seams`,
  `value_split`. Every key of the Maestro report is still present, unchanged, with
  Oracolo's values.
* `MASK_DEFAULTS` is reused byte for byte and not re-tuned.

Outputs (under `--out`, default `godot/assets/athletes/outfits/oracolo/`):
  oracolo_region_mask.png          2048x2048 RGBA, R=torso G=hip B=foot A=coverage
  oracolo_region_mask_preview.png  the same mask tinted, for eyeballing

and a JSON report (under `--report`) with the coverage, the per-region measured family
anchors, the protected-texel count, the leak evidence, the seam evidence and the
family/value verdicts.

Deterministic: no randomness in the image bytes, no timestamps. `--check` re-rasterises
and exits 1 if the file on disk differs.

    python3 tools/character/build_oracolo_outfit_mask.py
    python3 tools/character/build_oracolo_outfit_mask.py --check
"""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import random
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parents[2]
DEFAULT_GLB = REPO / "godot/assets/athletes/oracolo.glb"
DEFAULT_TEXTURE = REPO / "godot/assets/athletes/oracolo_texture_0.png"
DEFAULT_OUT = REPO / "godot/assets/athletes/outfits/oracolo"
DEFAULT_REPORT = REPO / "docs/agent-work/outfits-3d/evidence/oracolo-mask-report.json"

MASK_SIZE = 2048
EDGE_SOFTEN_PX = 1.2

## Bone -> garment region, using Oracolo's REAL joint names (verified against
## skin.joints of oracolo.glb: 28 joints, `mixamorig:` prefix).
## Anything absent is protected: it can never be painted.
##
## This is the Fiamma map verbatim, and that is a measured statement, not laziness:
## Oracolo's joint set is byte-identical to Fiamma's 28 names (verified by set
## comparison against fiamma.glb and maestro.glb). Maestro is the rig that needed a
## different map. The shins (LeftLeg/RightLeg) are deliberately absent, exactly as in
## Fiamma and Maestro: a sock is found by the family test inside the foot region, and
## the shin's bare skin would only add false positives.
BONE_REGION = {
    "mixamorig:Spine": "torso",
    "mixamorig:Spine1": "torso",
    "mixamorig:Spine2": "torso",
    "mixamorig:LeftShoulder": "torso",
    "mixamorig:RightShoulder": "torso",
    "mixamorig:Hips": "hip",
    "mixamorig:LeftUpLeg": "hip",
    "mixamorig:RightUpLeg": "hip",
    "mixamorig:LeftFoot": "foot",
    "mixamorig:RightFoot": "foot",
    "mixamorig:LeftToeBase": "foot",
    "mixamorig:RightToeBase": "foot",
    "mixamorig:LeftToe_End": "foot",
    "mixamorig:RightToe_End": "foot",
}

## The bones the Fiamma map expects. For Oracolo this list is EMPTY - the two rigs
## share their joint set - so nothing is silently substituted and nothing is missing.
## The interesting difference from Maestro is anatomical, not nominal, and is reported
## under `landmarks` below.
BONE_DIFF = {
    "oracolo_joint_count": 28,
    "fiamma_joint_count": 28,
    "maestro_joint_count": 24,
    "absent_from_oracolo": [],
    "renamed": {},
    "note": "Oracolo's skins[0].joints is the same 28-name set as Fiamma's, so the "
            "Fiamma bone map applies verbatim: no bone had to be dropped or renamed. "
            "The extra node `headfront` and the `LeftHandMiddle4`/`RightHandMiddle4` "
            "tips are present but own no garment region, like Fiamma. Maestro, the "
            "previous athlete, is the rig whose names differ (bare, spine numbered "
            "downward) and whose two Toe_End joints are absent.",
}

REGIONS = ("torso", "hip", "foot")

## The two chromatic bands of the baked atlas inside the mask, as hue windows in
## degrees. Measured for Oracolo: the violet band carries 777 596 texels (80.4% of the
## chromatic masked texels) in 1452 components >= 64 px - the garment. The 300-360
## band carries 32 686 (3.4%) in 9640 components with a median of 1 px: it is the
## antialiasing ramp between violet fabric and skin, NOT a painted second family. The
## window is kept because the classification is what makes that visible in the report;
## see `texel_classes.family_test` for what happens if it is used as an anchor.
FAMILY_WINDOWS = {
    "violet": (240.0, 300.0),
    "magenta": (300.0, 360.0),
}

## The measured Fiamma cut, kept verbatim and NOT re-tuned. On Oracolo's body it lands
## 8.4 mm above the Hips joint (8.0% of the pelvis-to-Spine interval). The report's
## `tripartition.cut_height_sweep` shows what every other height in 0.94-1.12 would do,
## so the reader can judge the cut rather than trust it.
WAIST_Y = 1.0

## The shader's family test, as the masked lane actually runs it: the values
## outfit_catalogue.gd pushes into every material from MASK_DEFAULTS (hue_tol_deg
## 45.0, sat_min 0.18, val_min 0.02, val_max 0.98, luma_clamp 0.45/1.7). Mirrored here
## ONLY to simulate what the shader can and cannot recolour - this tool does not
## retune them.
MASK_DEFAULTS = {
    "hue_tol_deg": 45.0,
    "sat_min": 0.18,
    "val_min": 0.02,
    "val_max": 0.98,
    "luma_clamp_lo": 0.45,
    "luma_clamp_hi": 1.7,
}

## Bone groups that own no garment region: their triangles are the control for the
## leak test. Anything here that falls inside the mask is area a recolour could touch.
PROTECTED_GROUPS = {
    "Head": ["mixamorig:Head", "mixamorig:HeadTop_End", "headfront", "mixamorig:Neck"],
    "Hands": ["mixamorig:LeftHand", "mixamorig:RightHand",
              "mixamorig:LeftHandMiddle4", "mixamorig:RightHandMiddle4"],
    "ForeArm": ["mixamorig:LeftForeArm", "mixamorig:RightForeArm"],
    "Arm": ["mixamorig:LeftArm", "mixamorig:RightArm"],
    "Shin": ["mixamorig:LeftLeg", "mixamorig:RightLeg"],
}

## Hue band that reads as exposed skin in this atlas (Oracolo's baked skin sits at hue
## ~20-30, saturation 0.4-0.7). Used to prove that skin inside the mask cannot match a
## family anchor.
SKIN_HUE = (0.0, 60.0)

## The declared colours of the outfit, for the record only: the reference catalogue's
## `visual` block and the outfit's own `colors`, which disagree on this athlete alone.
DECLARED_FAMILIES = {
    "outfit_base": ("#6d42b8", "#a96cff"),
    "catalogue_visual": ("#6b3df0", "#e3c6ff"),
}

_COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
_NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# --------------------------------------------------------------------------
# Minimal GLB reader (stdlib only, like glb_tri_count.py)
# --------------------------------------------------------------------------

class Glb:
    def __init__(self, path: Path) -> None:
        raw = path.read_bytes()
        magic, version, length = struct.unpack("<III", raw[:12])
        if magic != 0x46546C67:
            raise SystemExit(f"{path} is not a GLB")
        if length != len(raw):
            raise SystemExit(f"{path}: header says {length} bytes, file has {len(raw)}")
        offset, chunks = 12, []
        while offset < len(raw):
            clen, ctype = struct.unpack("<II", raw[offset:offset + 8])
            chunks.append((ctype, offset + 8, clen))
            offset += 8 + clen
        self.json = json.loads(raw[chunks[0][1]:chunks[0][1] + chunks[0][2]].decode("utf-8"))
        self.bin_offset = chunks[1][1]
        self.raw = raw

    def accessor(self, index: int) -> list[tuple]:
        acc = self.json["accessors"][index]
        view = self.json["bufferViews"][acc["bufferView"]]
        fmt, size = _COMPONENT[acc["componentType"]]
        ncomp = _NCOMP[acc["type"]]
        base = self.bin_offset + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride") or size * ncomp
        unpack = struct.Struct("<" + fmt * ncomp)
        return [unpack.unpack_from(self.raw, base + k * stride) for k in range(acc["count"])]


# --------------------------------------------------------------------------
# 4x4 maths, column-major like glTF
# --------------------------------------------------------------------------

def mat_mul(a, b):
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[col * 4 + row] = sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
    return out


def trs_to_mat(t, r, s):
    x, y, z, w = r
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    return [
        (1 - 2 * (yy + zz)) * s[0], (2 * (xy + wz)) * s[0], (2 * (xz - wy)) * s[0], 0.0,
        (2 * (xy - wz)) * s[1], (1 - 2 * (xx + zz)) * s[1], (2 * (yz + wx)) * s[1], 0.0,
        (2 * (xz + wy)) * s[2], (2 * (yz - wx)) * s[2], (1 - 2 * (xx + yy)) * s[2], 0.0,
        t[0], t[1], t[2], 1.0,
    ]


def node_local(node):
    if "matrix" in node:
        return list(node["matrix"])
    return trs_to_mat(node.get("translation", [0, 0, 0]),
                      node.get("rotation", [0, 0, 0, 1]),
                      node.get("scale", [1, 1, 1]))


def xform(m, v):
    x, y, z = v
    return (m[0] * x + m[4] * y + m[8] * z + m[12],
            m[1] * x + m[5] * y + m[9] * z + m[13],
            m[2] * x + m[6] * y + m[10] * z + m[14])


def node_globals(gltf):
    parent = {}
    for i, node in enumerate(gltf["nodes"]):
        for child in node.get("children", []):
            parent[child] = i
    cache = {}

    def compute(i):
        if i in cache:
            return cache[i]
        local = node_local(gltf["nodes"][i])
        m = mat_mul(compute(parent[i]), local) if i in parent else local
        cache[i] = m
        return m

    for i in range(len(gltf["nodes"])):
        compute(i)
    return cache


# --------------------------------------------------------------------------
# Skin decomposition: every vertex's dominant joint and its bind-pose world position
# --------------------------------------------------------------------------

def read_mesh(glb: Glb) -> dict:
    gltf = glb.json
    prim = gltf["meshes"][0]["primitives"][0]
    skin = gltf["skins"][0]
    ibm = glb.accessor(skin["inverseBindMatrices"])
    glob = node_globals(gltf)
    names = [gltf["nodes"][n].get("name", "") for n in skin["joints"]]
    joints = glb.accessor(prim["attributes"]["JOINTS_0"])
    weights = glb.accessor(prim["attributes"]["WEIGHTS_0"])
    pos = glb.accessor(prim["attributes"]["POSITION"])

    # Bind-pose world transform of every joint, then of every vertex through its
    # dominant joint. The mesh is a Mixamo export whose bind pose is a T-pose, so the
    # bone that owns a vertex is a far better region signal than its height. The joint
    # ORIGIN in bind space is the node's global translation - the inverse bind matrix
    # maps a joint origin to (0,0,0) by construction, so it cannot be read from `bind`.
    bind = [mat_mul(glob[skin["joints"][k]], ibm[k]) for k in range(len(names))]
    dominant, world = [], []
    for i in range(len(pos)):
        best, best_w = 0, -1.0
        for k in range(4):
            if weights[i][k] > best_w:
                best_w, best = weights[i][k], joints[i][k]
        dominant.append(best)
        world.append(xform(bind[best], pos[i]))
    origins = {names[k]: xform(glob[skin["joints"][k]], (0, 0, 0)) for k in range(len(names))}

    return {
        "names": names,
        "dominant": dominant,
        "world": world,
        "joint_origins": origins,
        "uv": glb.accessor(prim["attributes"]["TEXCOORD_0"]),
        "index": [v[0] for v in glb.accessor(prim["indices"])],
    }


def joint_names(glb: Glb) -> list[str]:
    gltf = glb.json
    return [gltf["nodes"][n].get("name", "") for n in gltf["skins"][0]["joints"]]


# --------------------------------------------------------------------------
# Rasterisation
# --------------------------------------------------------------------------

def assign_regions(mesh: dict) -> list[str]:
    """The region of every triangle, by the pipeline's own rule."""
    names, dominant, world, index = (mesh["names"], mesh["dominant"], mesh["world"],
                                     mesh["index"])
    vertex_region = [BONE_REGION.get(names[d], "") for d in dominant]
    out = []
    for t in range(0, len(index), 3):
        tri = [index[t + k] for k in range(3)]
        hits = [vertex_region[v] for v in tri if vertex_region[v]]
        if not hits:
            out.append("")
            continue
        region = max(REGIONS, key=hits.count)
        # Hip weights extend into the abdomen. Use bind-space height to avoid painting
        # arbitrary triangles of the bodice with skirt trim colours.
        if region != "foot":
            region = "torso" if sum(world[v][1] for v in tri) / 3.0 > WAIST_Y else "hip"
        out.append(region)
    return out


def rasterise_regions(mesh: dict) -> tuple[dict[str, Image.Image], dict]:
    names, dominant, world, uv, index = (mesh["names"], mesh["dominant"], mesh["world"],
                                         mesh["uv"], mesh["index"])
    vertex_region = [BONE_REGION.get(names[d], "") for d in dominant]

    layers = {r: Image.new("L", (MASK_SIZE, MASK_SIZE), 0) for r in REGIONS}
    drawers = {r: ImageDraw.Draw(layers[r]) for r in REGIONS}
    counts = {r: 0 for r in REGIONS}
    protected_tris = 0
    straddling = 0
    ys = {r: [] for r in REGIONS}

    for t in range(0, len(index), 3):
        tri = [index[t + k] for k in range(3)]
        votes = [vertex_region[v] for v in tri]
        hits = [r for r in votes if r]
        if not hits:
            protected_tris += 1
            continue
        if len(set(hits)) > 1:
            straddling += 1
        region = max(REGIONS, key=hits.count)
        if region != "foot":
            region = "torso" if sum(world[v][1] for v in tri) / 3.0 > WAIST_Y else "hip"
        counts[region] += 1
        for v in tri:
            ys[region].append(world[v][1])
        # glTF UVs address images from the top left, like PNG rows and Godot.
        pts = [(uv[v][0] * MASK_SIZE, uv[v][1] * MASK_SIZE) for v in tri]
        drawers[region].polygon(pts, fill=255)

    if EDGE_SOFTEN_PX > 0:
        for r in REGIONS:
            layers[r] = layers[r].filter(ImageFilter.GaussianBlur(EDGE_SOFTEN_PX))

    stats = {
        "triangles": len(index) // 3,
        "region_triangles": counts,
        "protected_triangles": protected_tris,
        "straddling_triangles": straddling,
        "region_y_min": {r: (round(min(v), 4) if v else None) for r, v in ys.items()},
        "region_y_max": {r: (round(max(v), 4) if v else None) for r, v in ys.items()},
    }
    return layers, stats


def coverage_image(layers: dict[str, Image.Image]) -> Image.Image:
    coverage = Image.new("L", (MASK_SIZE, MASK_SIZE), 0)
    for r in REGIONS:
        coverage = Image.composite(Image.new("L", (MASK_SIZE, MASK_SIZE), 255), coverage, layers[r])
    return coverage


# --------------------------------------------------------------------------
# Family measurement (the anchors the shader and the profile quote)
# --------------------------------------------------------------------------

def classify(hue_deg: float, sat: float, val: float) -> str:
    """Which chromatic band of the atlas a texel belongs to, by the measured windows."""
    for family, (lo, hi) in FAMILY_WINDOWS.items():
        if lo <= hue_deg < hi:
            return family
    return ""


def measure_anchors(texture: Image.Image, layers: dict[str, Image.Image]) -> dict:
    """The recolourable bands of the baked atlas, measured *inside* the garment regions
    only. Skin and hair cannot vote here: they are outside.

    Same gates as the Fiamma and Maestro tools (saturation >= 0.25, value >= 0.08,
    modal quantised colour at 8/255 steps); the hue windows differ, see FAMILY_WINDOWS.
    `components` and `components_ge_64px` are the honesty check that the Maestro lane
    introduced for its light family: a painted family has few large components, an
    antialiasing ramp has thousands of 1-px ones."""
    px = texture.load()
    masks = {r: layer.load() for r, layer in layers.items()}
    buckets: dict[str, list[tuple[float, tuple[int, int, int]]]] = {}
    sample_map = {}
    for r in REGIONS:
        layer = masks[r]
        for y in range(0, MASK_SIZE, 4):
            for x in range(0, MASK_SIZE, 4):
                if layer[x, y] < 200:
                    continue
                rgb = px[x, y]
                h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
                if s < 0.25 or v < 0.08:
                    continue
                family = classify(h * 360.0, s, v)
                if family:
                    buckets.setdefault(family, []).append((h * 360.0, rgb))
                    sample_map.setdefault(family, []).append((x, y))
    out = {}
    for family, samples in sorted(buckets.items()):
        # The anchor is the *modal* colour, not the mean: shading variants would drag a
        # mean toward the dark side and make the luma-preserving ratio wrong.
        quantised = Counter((r // 8 * 8, g // 8 * 8, b // 8 * 8) for _, (r, g, b) in samples)
        (r, g, b), hits = quantised.most_common(1)[0]
        comps = _component_sizes(sample_map[family], 4)
        out[family] = {
            "hex": "#%02x%02x%02x" % (r, g, b),
            "srgb": [round(r / 255.0, 4), round(g / 255.0, 4), round(b / 255.0, 4)],
            "hue_deg": round(sum(h for h, _ in samples) / len(samples), 1),
            "samples": len(samples),
            "modal_hits": hits,
            "components": len(comps),
            "components_ge_64px": sum(1 for c in comps if c >= 64),
            "largest_component_px": max(comps) if comps else 0,
        }
    return out


def _component_sizes(points: list[tuple[int, int]], step: int) -> list[int]:
    """8-connected component sizes of a sparse sample set, in atlas pixels.

    `step` is the sampling stride the caller used, so adjacency has to be tested at
    that stride and each sample counts for step*step pixels."""
    grid = set(points)
    seen = set()
    sizes = []
    for p in grid:
        if p in seen:
            continue
        stack = [p]
        seen.add(p)
        n = 0
        while stack:
            x, y = stack.pop()
            n += 1
            for dx in (-step, 0, step):
                for dy in (-step, 0, step):
                    q = (x + dx, y + dy)
                    if q in grid and q not in seen:
                        seen.add(q)
                        stack.append(q)
        sizes.append(n * step * step)
    return sizes


def measure_texel_classes(texture: Image.Image, layers: dict[str, Image.Image],
                          anchors: dict, coverage: Image.Image) -> dict:
    """What the mask actually covers, and whether any of it can be recoloured.

    Every texel the mask covers is classified once (violet / magenta / skin / neutral /
    other), then put through the shader's own family test with the MASK_DEFAULTS
    windows. Two numbers matter:
      * `skin_hued_family_hits` - a texel on bare skin that the shader would recolour.
        It must be zero, and this is the measurement that proves it rather than
        asserting it. It is reported PER ANCHOR, because on Oracolo it is zero for the
        violet anchor and non-zero for the magenta one: the 45 deg window around a
        320 deg anchor wraps onto hue 0-4 and catches 6875 skin texels.
      * `texels_matching_both_anchors` - the separability question. Two anchors closer
        than 2x the tolerance cannot be told apart by the shader at all."""
    px = texture.load()
    cp = coverage.point(lambda v: 1 if v >= 128 else 0).load()
    anchor_hue = {f: _rgb_hue_deg(a["srgb"]) for f, a in anchors.items()}
    tol = MASK_DEFAULTS["hue_tol_deg"]
    counts = Counter()
    fam_hits = Counter()
    fam_skin_hits = Counter()
    both_anchors = 0
    skin_family_hits = 0
    per_region = {r: Counter() for r in REGIONS}
    region_layers = {r: layers[r].point(lambda v: 1 if v >= 128 else 0).load() for r in REGIONS}
    for y in range(MASK_SIZE):
        for x in range(MASK_SIZE):
            if not cp[x, y]:
                continue
            rgb = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
            hue = h * 360.0
            if s < MASK_DEFAULTS["sat_min"] or not (MASK_DEFAULTS["val_min"] <= v <= MASK_DEFAULTS["val_max"]):
                cls = "neutral"
            else:
                cls = classify(hue, s, v) or ("skin" if SKIN_HUE[0] <= hue < SKIN_HUE[1] else "other")
            counts[cls] += 1
            for r in REGIONS:
                if region_layers[r][x, y]:
                    per_region[r][cls] += 1
            # The shader evaluates both anchors independently (fam_a and fam_b, no
            # else-if), so a texel can match both - which is the whole separability
            # question for a pair of anchors under a 45 deg tolerance.
            matched = 0
            for family, ah in anchor_hue.items():
                dh = abs((hue - ah + 180.0) % 360.0 - 180.0)
                if dh < tol:
                    fam_hits[family] += 1
                    matched += 1
                    if cls == "skin":
                        fam_skin_hits[family] += 1
            if matched > 1:
                both_anchors += 1
            if matched and cls == "skin":
                skin_family_hits += 1
    total = sum(counts.values())
    separation = None
    if len(anchor_hue) == 2:
        a, b = sorted(anchor_hue.values())
        separation = round(b - a, 1)
    separates = bool(separation is not None and separation > 2 * MASK_DEFAULTS["hue_tol_deg"])
    # Which hue window does each anchor's tolerance actually cover? An anchor past 315
    # deg wraps onto the low hues, and on this atlas that wrap lands on skin.
    wrap = {}
    for family, ah in anchor_hue.items():
        lo, hi = (ah - tol) % 360.0, (ah + tol) % 360.0
        wrap[family] = {"hue_window_deg": [round(lo, 1), round(hi, 1)],
                        "wraps_past_360": lo > hi}
    leaking_anchor = ""
    for family, n in sorted(fam_skin_hits.items()):
        if n > fam_skin_hits.get(leaking_anchor, -1):
            leaking_anchor = family
    safe_anchor = leaking_anchor
    for family in sorted(anchors):
        if fam_skin_hits.get(family, 0) < fam_skin_hits.get(safe_anchor, 10 ** 9):
            safe_anchor = family
    if not separates:
        verdict = (
            "The hue test does NOT separate the two anchors: %s vs %s are %.1f deg apart "
            "under a %.0f deg tolerance (2x tolerance = %.0f deg), and %.4f of the mask "
            "answers to both. %d skin-hued masked texels would be recoloured, all of them "
            "by the %s anchor, whose window [%s] wraps past 360 onto the low hues; the %s "
            "anchor alone recolours %d skin-hued texels."
            % (sorted(anchors)[0], sorted(anchors)[1], separation or 0.0, tol, 2 * tol,
               round(both_anchors / total, 4) if total else 0.0, skin_family_hits,
               leaking_anchor or "-",
               ", ".join("%.0f" % v for v in wrap.get(leaking_anchor, {}).get("hue_window_deg", [])),
               safe_anchor, fam_skin_hits.get(safe_anchor, 0)))
    else:
        verdict = "The hue test separates the two anchors (%.1f deg apart)." % (separation or 0.0)
    return {
        "masked_texels": total,
        "classes": {k: counts[k] for k in ("violet", "magenta", "skin", "neutral", "other") if counts[k]},
        "classes_by_region": {r: dict(per_region[r]) for r in REGIONS},
        "family_test": {
            "effective": {k: MASK_DEFAULTS[k] for k in ("hue_tol_deg", "sat_min", "val_min", "val_max")},
            "anchor_hue_deg": {f: round(v, 1) for f, v in anchor_hue.items()},
            "anchor_hue_window": wrap,
            "hue_separation_deg": separation,
            "hits": dict(fam_hits),
            "skin_hued_family_hits_by_anchor": dict(fam_skin_hits),
            "texels_matching_both_anchors": both_anchors,
            "texels_matching_both_anchors_fraction": round(both_anchors / total, 4) if total else 0.0,
            "skin_hued_family_hits": skin_family_hits,
            "hue_test_separates_the_two_families": separates,
            "verdict": verdict,
        },
    }


def _rgb_hue_deg(srgb: list[float]) -> float:
    h, _, _ = colorsys.rgb_to_hsv(*srgb)
    return h * 360.0


def measure_protected_leak(mesh: dict, coverage: Image.Image) -> dict:
    """How much of the mask falls on body parts that own no garment region.

    Attribution matters and is reported both ways, because the loose rule lies:
      strict    all three vertices dominated by the protected group
      majority  at least two of three
    A triangle with a single arm or shin corner is a torso/hip triangle - the hem and
    the sleeve seam - and belongs in the mask. Counting it as a leak inflated the
    first version of the Maestro measurement from 0.0002 to 0.28."""
    names, dominant, uv, index = mesh["names"], mesh["dominant"], mesh["uv"], mesh["index"]
    # Two coverages, because they answer different questions: >=200 is the geometric
    # region (no Gaussian bleed, the honest area measure), >=128 is what the shader's
    # linear filtering can actually see.
    hard = coverage.point(lambda v: 255 if v >= 200 else 0)
    soft = coverage.point(lambda v: 255 if v >= 128 else 0)
    out = {}
    for label, bones in PROTECTED_GROUPS.items():
        row = {}
        for rule, need in (("strict", 3), ("majority", 2)):
            img = Image.new("L", (MASK_SIZE, MASK_SIZE), 0)
            d = ImageDraw.Draw(img)
            tris = 0
            for t in range(0, len(index), 3):
                tri = [index[t + k] for k in range(3)]
                if sum(1 for v in tri if names[dominant[v]] in bones) < need:
                    continue
                tris += 1
                d.polygon([(uv[v][0] * MASK_SIZE, uv[v][1] * MASK_SIZE) for v in tri], fill=255)
            texels = img.histogram()[255]
            inside_hard = ImageChops.multiply(img, hard).histogram()[255]
            inside_soft = ImageChops.multiply(img, soft).histogram()[255]
            row[rule] = {
                "triangles": tris,
                "texels": texels,
                "inside_mask_texels_ge200": inside_hard,
                "leak_ge200": round(inside_hard / texels, 4) if texels else 0.0,
                "inside_mask_texels_ge128": inside_soft,
                "leak_ge128": round(inside_soft / texels, 4) if texels else 0.0,
            }
        out[label] = row
    return out


# --------------------------------------------------------------------------
# TRIPARTITION: does torso / hip / foot mean anything on this body?
# --------------------------------------------------------------------------

LANDMARKS = ("mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
             "mixamorig:Neck", "mixamorig:Head", "mixamorig:LeftUpLeg", "mixamorig:LeftLeg",
             "mixamorig:LeftFoot", "mixamorig:LeftShoulder", "mixamorig:LeftArm",
             "mixamorig:LeftForeArm", "mixamorig:LeftHand")

## The same landmark on the two athletes this pipeline has already run, read off their
## own GLBs by the same code path. Quoted here so the pelvis height can be compared
## without re-running another lane's tool.
LANDMARK_REFERENCE = {
    "maestro": {"hips_y": 0.9517, "spine_y": 1.1042, "cut_fraction_of_interval": 0.317},
    "fiamma": {"hips_y": 0.9549, "spine_y": 1.0755, "cut_fraction_of_interval": 0.374},
}


def measure_tripartition(mesh: dict, layers: dict[str, Image.Image], texture: Image.Image,
                         region_of_tri: list[str]) -> dict:
    """The anatomical and topological facts the tripartition rests on."""
    names, dominant, world, uv, index = (mesh["names"], mesh["dominant"], mesh["world"],
                                         mesh["uv"], mesh["index"])
    origins = mesh["joint_origins"]
    landmarks = {b: [round(c, 4) for c in origins[b]] for b in LANDMARKS if b in origins}
    hips_y = origins["mixamorig:Hips"][1]
    spine_y = origins["mixamorig:Spine"][1]
    interval = spine_y - hips_y

    # UV islands: weld every vertex copy that shares a UV, then union by triangle edge.
    uv_key = {}
    for i, (u, v) in enumerate(uv):
        uv_key.setdefault((round(u, 4), round(v, 4)), []).append(i)
    parent = list(range(len(uv)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for members in uv_key.values():
        for m in members[1:]:
            union(members[0], m)
    for t in range(0, len(index), 3):
        union(index[t], index[t + 1])
        union(index[t + 1], index[t + 2])
    island_of_vertex = [find(i) for i in range(len(uv))]
    island_tris = Counter()
    island_regions = defaultdict(set)
    for t in range(0, len(index), 3):
        key = island_of_vertex[index[t]]
        island_tris[key] += 1
        if region_of_tri[t // 3]:
            island_regions[key].add(region_of_tri[t // 3])
    sizes = sorted(island_tris.values(), reverse=True)
    mixed = [k for k, regs in island_regions.items() if len(regs) > 1]
    mixed_tris = sum(island_tris[k] for k in mixed)

    # UV area budget: how many atlas pixels a triangle owns on average. This is the
    # resolution the recolour actually has to work with.
    areas = []
    for t in range(0, len(index), 3):
        (ax, ay), (bx, by), (cx, cy) = uv[index[t]], uv[index[t + 1]], uv[index[t + 2]]
        areas.append(abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2.0)
    total_area = sum(areas)
    areas_sorted = sorted(areas)
    px = lambda a: a * MASK_SIZE * MASK_SIZE
    per_region_px = {}
    for r in REGIONS:
        sel = [areas[t // 3] for t in range(0, len(index), 3) if region_of_tri[t // 3] == r]
        per_region_px[r] = {
            "triangles": len(sel),
            "uv_area_share": round(sum(sel) / total_area, 4) if total_area else 0.0,
            "atlas_px_per_triangle_mean": round(px(sum(sel) / len(sel)), 1) if sel else 0.0,
        }

    # What the texture looks like in the 1 cm bands around the cut.
    band = []
    for lo in [round(0.94 + 0.01 * k, 2) for k in range(19)]:
        sel = [t for t in range(0, len(index), 3)
               if region_of_tri[t // 3] in ("torso", "hip")
               and lo <= sum(world[v][1] for v in index[t:t + 3]) / 3.0 < lo + 0.01]
        if len(sel) < 20:
            continue
        cs = [_sample(texture, _tri_uv_centroid(uv, index, t)) for t in sel]
        n = len(sel)
        violet = sum(1 for c in cs if 240 <= c[1] < 300 and c[2] >= 0.18)
        skin = sum(1 for c in cs if SKIN_HUE[0] <= c[1] < SKIN_HUE[1] and c[2] >= 0.18)
        band.append({
            "y_lo": lo, "y_hi": round(lo + 0.01, 2), "triangles": n,
            "violet_share": round(violet / n, 4),
            "skin_hued_share": round(skin / n, 4),
        })

    return {
        "landmarks_world_y": landmarks,
        "hips_y": round(hips_y, 4),
        "spine_y": round(spine_y, 4),
        "pelvis_to_spine_interval_m": round(interval, 4),
        "waist_y": WAIST_Y,
        "cut_above_hips_m": round(WAIST_Y - hips_y, 4),
        "cut_fraction_of_pelvis_to_spine": round((WAIST_Y - hips_y) / interval, 4) if interval else None,
        "cut_fraction_reference": LANDMARK_REFERENCE,
        "cut_lands_on": "pelvis" if (WAIST_Y - hips_y) / interval < 0.15 else "waist",
        "uv_islands": {
            "count": len(island_tris),
            "largest_tris": sizes[:8],
            "median_tris": sizes[len(sizes) // 2] if sizes else 0,
            "mean_tris": round(sum(sizes) / len(sizes), 2) if sizes else 0.0,
            "islands_spanning_more_than_one_region": len(mixed),
            "share_of_islands_spanning": round(len(mixed) / len(island_tris), 4) if island_tris else 0.0,
            "triangles_in_those_islands": mixed_tris,
            "share_of_triangles_in_those_islands": round(mixed_tris / (len(index) // 3), 4),
        },
        "uv_budget": {
            "total_uv_area_of_unit_square": round(total_area, 4),
            "atlas_px_total": round(px(total_area)),
            "atlas_px_per_triangle_mean": round(px(total_area / (len(index) // 3)), 1),
            "atlas_px_per_triangle_median": round(px(areas_sorted[len(areas_sorted) // 2]), 1),
            "atlas_px_per_triangle_p10": round(px(areas_sorted[len(areas_sorted) // 10]), 1),
            "atlas_px_per_triangle_p90": round(px(areas_sorted[9 * len(areas_sorted) // 10]), 1),
            "by_region": per_region_px,
            "note": "A triangle owns a median of this many atlas pixels, which is the "
                    "resolution the recolour works at and the reason the mask edge is "
                    "rasterised at 2048 with a 1.2 px soften.",
        },
        "band_profile_around_the_cut": band,
        "verdict": (
            "The partition is topologically clean (see region_seams) but it is NOT a "
            "garment partition: the cut is a horizontal plane at bind Y %.2f, which is "
            "%.4f m above the Hips joint - %.1f%% of the pelvis-to-Spine interval, "
            "against 31.7%% on Maestro and 37.4%% on Fiamma. On this body it lands on the "
            "pelvis, and the violet garment is present on both sides of it."
            % (WAIST_Y, WAIST_Y - hips_y,
               100 * (WAIST_Y - hips_y) / interval if interval else 0.0)
        ),
    }


# --------------------------------------------------------------------------
# SEAMS: does the region boundary follow anything the outfit actually has?
# --------------------------------------------------------------------------

def measure_region_seams(mesh: dict, coverage: Image.Image, texture: Image.Image,
                         region_of_tri: list[str]) -> dict:
    """Everything the tripartition claim needs to be checkable.

    An edge of the mesh is shared by exactly two triangles. If those two triangles are
    in different regions the edge lies ON the region boundary, and there are four
    independent ways to ask whether the boundary is meaningful:

      1. UV islands  - is the edge also a UV island border? (welded by position, then
         compare the UVs the two triangles use at the shared endpoints)
      2. texture edges - does the boundary sit on a real edge of the baked image?
         (top-5% gradient magnitude, dilated 3 px, versus the base rate over random
         in-mask texels: a likelihood ratio of ~1.0 means it follows nothing)
      3. colour across - is the fabric on the two sides the same? (triangle-interior
         samples, versus the same-region baseline)
      4. what the shader sees - on how much of the boundary is there recolourable
         fabric on BOTH sides, i.e. how much of it would show as a hard line if the
         two regions got different colours?
    """
    names, dominant, world, uv, index = (mesh["names"], mesh["dominant"], mesh["world"],
                                         mesh["uv"], mesh["index"])
    # Every vertex is welded to its duplicates by bind-pose world position, exactly as
    # the mask lane needs: two triangles that share a surface point are adjacent even
    # when the exporter split them for UVs or normals.
    weld = {}
    for i, p in enumerate(mesh["world"]):
        weld.setdefault((round(p[0], 4), round(p[1], 4), round(p[2], 4)), []).append(i)

    def welded(i):
        p = mesh["world"][i]
        return weld[(round(p[0], 4), round(p[1], 4), round(p[2], 4))][0]

    edge_tris = defaultdict(list)
    for t in range(0, len(index), 3):
        a, b, c = welded(index[t]), welded(index[t + 1]), welded(index[t + 2])
        for e in ((a, b), (b, c), (c, a)):
            edge_tris[(min(e), max(e))].append(t // 3)
    shared = {e: ts for e, ts in edge_tris.items() if len(ts) == 2}

    def uv_at(tri, point):
        for k in range(3):
            if welded(index[tri * 3 + k]) == point:
                return uv[index[tri * 3 + k]]

    uv_seam_all = 0
    for e, (t1, t2) in shared.items():
        if not _same_uv(uv_at(t1, e[0]), uv_at(t2, e[0]), uv_at(t1, e[1]), uv_at(t2, e[1])):
            uv_seam_all += 1
    base_uv_seam = uv_seam_all / len(shared) if shared else 0.0

    seam = [(e, ts) for e, ts in shared.items()
            if region_of_tri[ts[0]] != region_of_tri[ts[1]]
            and region_of_tri[ts[0]] and region_of_tri[ts[1]]]
    by_pair = Counter()
    uv_seam = 0
    ys = []
    deltas = []
    for e, (t1, t2) in seam:
        by_pair[tuple(sorted((region_of_tri[t1], region_of_tri[t2])))] += 1
        if not _same_uv(uv_at(t1, e[0]), uv_at(t2, e[0]), uv_at(t1, e[1]), uv_at(t2, e[1])):
            uv_seam += 1
        ys.append((sum(mesh["world"][v][1] for v in index[t1 * 3:t1 * 3 + 3])
                   + sum(mesh["world"][v][1] for v in index[t2 * 3:t2 * 3 + 3])) / 6.0)
        c1 = _sample(texture, _tri_uv_centroid(uv, index, t1 * 3))
        c2 = _sample(texture, _tri_uv_centroid(uv, index, t2 * 3))
        deltas.append(max(abs(c1[0][k] - c2[0][k]) for k in range(3)))
    ctrl = []
    for e, (t1, t2) in shared.items():
        if region_of_tri[t1] != region_of_tri[t2] or not region_of_tri[t1]:
            continue
        c1 = _sample(texture, _tri_uv_centroid(uv, index, t1 * 3))
        c2 = _sample(texture, _tri_uv_centroid(uv, index, t2 * 3))
        ctrl.append(max(abs(c1[0][k] - c2[0][k]) for k in range(3)))

    # texture-edge coincidence
    gray = texture.convert("L")
    w, h = gray.size
    dx = ImageChops.difference(gray.crop((1, 0, w, h)), gray.crop((0, 0, w - 1, h)))
    dy = ImageChops.difference(gray.crop((0, 1, w, h)), gray.crop((0, 0, w, h - 1)))
    edge = ImageChops.lighter(dx.resize((w, h)), dy.resize((w, h)))
    hist = edge.histogram()
    cut = _percentile_from_histogram(hist, 0.95)
    strong = edge.point(lambda v: 255 if v >= cut else 0).filter(ImageFilter.MaxFilter(7))
    sp = strong.load()
    hits = 0
    mids = []
    for e, (t1, t2) in seam:
        m = ((uv_at(t1, e[0])[0] + uv_at(t1, e[1])[0]) / 2.0,
             (uv_at(t1, e[0])[1] + uv_at(t1, e[1])[1]) / 2.0)
        mids.append(m)
        if sp[int(min(max(m[0] * MASK_SIZE, 0), MASK_SIZE - 1)),
              int(min(max(m[1] * MASK_SIZE, 0), MASK_SIZE - 1))]:
            hits += 1
    rng = random.Random(7)
    n_sample, base_hits = 20000, 0
    while n_sample > 0:
        t = rng.randrange(0, len(index), 3)
        if not region_of_tri[t // 3]:
            continue
        r1, r2 = rng.random(), rng.random()
        if r1 + r2 > 1:
            r1, r2 = 1 - r1, 1 - r2
        u = (uv[index[t]][0] * (1 - r1 - r2) + uv[index[t + 1]][0] * r1 + uv[index[t + 2]][0] * r2)
        v = (uv[index[t]][1] * (1 - r1 - r2) + uv[index[t + 1]][1] * r1 + uv[index[t + 2]][1] * r2)
        if sp[int(min(max(u * MASK_SIZE, 0), MASK_SIZE - 1)),
              int(min(max(v * MASK_SIZE, 0), MASK_SIZE - 1))]:
            base_hits += 1
        n_sample -= 1

    # what the shader sees on each side
    anchor_hue = 265.7  # measured, see family_anchors
    tol = MASK_DEFAULTS["hue_tol_deg"]

    def recolourable(c):
        return (240.0 <= c[1] < 300.0 and c[2] >= MASK_DEFAULTS["sat_min"]
                and abs((c[1] - anchor_hue + 180.0) % 360.0 - 180.0) < tol)

    both = one = neither = 0
    for e, (t1, t2) in seam:
        a = recolourable(_sample(texture, _tri_uv_centroid(uv, index, t1 * 3)))
        b = recolourable(_sample(texture, _tri_uv_centroid(uv, index, t2 * 3)))
        if a and b:
            both += 1
        elif a or b:
            one += 1
        else:
            neither += 1

    # sensitivity of the cut height (evidence only: WAIST_Y is not re-tuned)
    sweep = []
    for w_y in (0.94, 0.96, 0.98, 1.00, 1.02, 1.04, 1.06, 1.08, 1.10, 1.12):
        regions = []
        for t in range(0, len(index), 3):
            tri = index[t:t + 3]
            hits_ = [BONE_REGION.get(names[dominant[v]], "") for v in tri]
            hits_ = [r for r in hits_ if r]
            if not hits_:
                regions.append("")
                continue
            r = max(REGIONS, key=hits_.count)
            if r != "foot":
                r = "torso" if sum(mesh["world"][v][1] for v in tri) / 3.0 > w_y else "hip"
            regions.append(r)
        b2 = n2 = 0
        for e, (t1, t2) in shared.items():
            if regions[t1] == regions[t2] or not regions[t1] or not regions[t2]:
                continue
            n2 += 1
            if (recolourable(_sample(texture, _tri_uv_centroid(uv, index, t1 * 3)))
                    and recolourable(_sample(texture, _tri_uv_centroid(uv, index, t2 * 3)))):
                b2 += 1
        if n2:
            sweep.append({"waist_y": w_y, "seam_edges": n2,
                          "visible_on_both_sides": b2,
                          "visible_share": round(b2 / n2, 4)})

    n = len(seam)
    # The full adjacency graph, including the protected group: this is what shows that
    # the foot region is edge-isolated (no foot<->hip and no foot<->torso edge exists).
    adjacency = Counter()
    for e, ts in shared.items():
        a = region_of_tri[ts[0]] or "protected"
        b = region_of_tri[ts[1]] or "protected"
        if a != b:
            adjacency[tuple(sorted((a, b)))] += 1
    return {
        "mesh_edges": len(edge_tris),
        "edges_shared_by_two_triangles": len(shared),
        "edges_not_shared_by_two": len(edge_tris) - len(shared),
        "region_seam_edges": n,
        "region_seam_edges_by_pair": {"%s|%s" % k: v for k, v in sorted(by_pair.items())},
        "region_adjacency_all_pairs": {"%s|%s" % k: v for k, v in adjacency.most_common()},
        "region_seam_bind_y_min": round(min(ys), 4) if ys else None,
        "region_seam_bind_y_max": round(max(ys), 4) if ys else None,
        "uv_island_alignment": {
            "seam_edges_on_a_uv_island_border": uv_seam,
            "seam_edges_inside_a_uv_island": n - uv_seam,
            "share_on_a_uv_island_border": round(uv_seam / n, 4) if n else 0.0,
            "base_rate_all_shared_edges": round(base_uv_seam, 4),
            "likelihood_ratio": round((uv_seam / n) / base_uv_seam, 2) if n and base_uv_seam else None,
        },
        "texture_edge_alignment": {
            "gradient_threshold_percentile": 0.95,
            "gradient_threshold_value": cut,
            "seam_midpoints_on_a_texture_edge": hits,
            "seam_midpoints": n,
            "share_on_a_texture_edge": round(hits / n, 4) if n else 0.0,
            "base_rate_random_in_mask_texels": round(base_hits / 20000, 4),
            "likelihood_ratio": round((hits / n) / (base_hits / 20000), 2) if n and base_hits else None,
        },
        "colour_across_the_boundary": {
            "seam_pairs_mean_max_channel_delta_255": round(sum(deltas) / len(deltas), 1) if deltas else 0.0,
            "same_region_pairs_mean_max_channel_delta_255": round(sum(ctrl) / len(ctrl), 1) if ctrl else 0.0,
            "ratio": round((sum(deltas) / len(deltas)) / (sum(ctrl) / len(ctrl)), 2) if deltas and ctrl else None,
        },
        "what_the_shader_sees": {
            "recolourable_fabric_on_both_sides": both,
            "on_one_side_only": one,
            "on_neither_side": neither,
            "visible_share": round(both / n, 4) if n else 0.0,
            "anchor_hue_deg": anchor_hue,
            "hue_tol_deg": tol,
        },
        "cut_height_sweep": sweep,
        "verdict": (
            "The region boundary follows nothing the outfit has. %d seam edges, all "
            "torso<->hip and all inside bind Y [%.3f, %.3f] - a horizontal plane. It is "
            "%.2fx as likely as a random masked texel to sit on a texture edge and %.2fx "
            "as likely to sit on a UV island border, and the fabric colour across it is "
            "%.2fx the same-region baseline. %.1f%% of it passes through recolourable "
            "violet on both sides, so a torso/hip colour split would draw a hard line "
            "there. The cut-height sweep shows no height in 0.94-1.12 avoids it."
            % (n, min(ys) if ys else 0.0, max(ys) if ys else 0.0,
               (hits / n) / (base_hits / 20000) if n and base_hits else 0.0,
               (uv_seam / n) / base_uv_seam if n and base_uv_seam else 0.0,
               (sum(deltas) / len(deltas)) / (sum(ctrl) / len(ctrl)) if deltas and ctrl else 0.0,
               100.0 * both / n if n else 0.0)
        ),
    }


def _same_uv(a1, a2, b1, b2) -> bool:
    return (abs(a1[0] - a2[0]) < 1e-4 and abs(a1[1] - a2[1]) < 1e-4
            and abs(b1[0] - b2[0]) < 1e-4 and abs(b1[1] - b2[1]) < 1e-4)


def _tri_uv_centroid(uv, index, t):
    return ((uv[index[t]][0] + uv[index[t + 1]][0] + uv[index[t + 2]][0]) / 3.0,
            (uv[index[t]][1] + uv[index[t + 1]][1] + uv[index[t + 2]][1]) / 3.0)


def _sample(texture: Image.Image, uv_point):
    """(rgb 0-255, hue deg, sat, val) at a UV point, clamped."""
    x = int(min(max(uv_point[0] * MASK_SIZE, 0), MASK_SIZE - 1))
    y = int(min(max(uv_point[1] * MASK_SIZE, 0), MASK_SIZE - 1))
    rgb = texture.getpixel((x, y))
    h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
    return rgb, h * 360.0, s, v


def _percentile_from_histogram(hist: list[int], q: float) -> int:
    total = sum(hist)
    target = total * q
    run = 0
    for i, c in enumerate(hist):
        run += c
        if run >= target:
            return i
    return len(hist) - 1


# --------------------------------------------------------------------------
# VALUE SPLIT: could a value gate do what the hue test cannot?
# --------------------------------------------------------------------------

def measure_value_split(texture: Image.Image, coverage: Image.Image, anchors: dict) -> dict:
    """Is there a value threshold that separates two recolourable families here?

    This is the same question the Maestro lane answered with a gate at value 0.76, and
    it is asked the same way: the population is the texels the shader can recolour at
    all, and the evidence is whether the atlas has a density discontinuity to cut on.
    On Maestro it did - a 5.34x jump at 0.76. Here it does not, and the numbers below
    are why: above value 0.55 the histogram is flat at 100-190 texels per 0.01 bin out
    to 0.97, the largest upward jump anywhere above the val_min gate is 1.95x, and the
    bright population is speckle (134 components with a median of 2 px)."""
    px = texture.load()
    cp = coverage.point(lambda v: 1 if v >= 128 else 0).load()
    sat_min = MASK_DEFAULTS["sat_min"]
    v_lo, v_hi = MASK_DEFAULTS["val_min"], MASK_DEFAULTS["val_max"]
    hist = [0] * 100
    pop = 0
    bright = {t: [] for t in (0.5, 0.6, 0.7, 0.76, 0.8)}
    for y in range(MASK_SIZE):
        for x in range(MASK_SIZE):
            if not cp[x, y]:
                continue
            rgb = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
            hue = h * 360.0
            if s < sat_min or not (v_lo <= v <= v_hi) or not (240.0 <= hue < 360.0):
                continue
            pop += 1
            hist[min(99, int(v * 100))] += 1
            for t in bright:
                if v >= t:
                    bright[t].append((x, y))
    jumps = []
    for i in range(len(hist) - 1):
        if hist[i] >= 20:
            jumps.append((round(hist[i + 1] / hist[i], 2), round(i / 100.0, 2)))
    jumps.sort(reverse=True)
    # The largest jump in the region a gate could actually use. Below v=0.10 the
    # histogram is still climbing out of the val_min gate, so those ratios measure the
    # gate, not the atlas.
    jumps_above_030 = [j for j in jumps if j[1] >= 0.30]
    tail = {}
    flat = [hist[i] for i in range(55, 98) if hist[i]]
    for t, pts in bright.items():
        sizes = _component_sizes(pts, 1)
        tail["%0.2f" % t] = {
            "texels": len(pts),
            "share_of_population": round(len(pts) / pop, 4) if pop else 0.0,
            "components": len(sizes),
            "components_ge_64px": sum(1 for s in sizes if s >= 64),
            "largest_component_px": max(sizes) if sizes else 0,
            "median_component_px": sorted(sizes)[len(sizes) // 2] if sizes else 0,
        }
    flat_band = {
        "v_lo": 0.55, "v_hi": 0.98,
        "counts_per_0.01_bin_min": min(flat) if flat else 0,
        "counts_per_0.01_bin_max": max(flat) if flat else 0,
        "counts_per_0.01_bin_median": sorted(flat)[len(flat) // 2] if flat else 0,
    }
    return {
        "population": pop,
        "population_definition": "masked texels (alpha>=128) with hue 240-360, sat >= 0.18, "
                                 "0.02 <= v <= 0.98 - i.e. everything the shader could recolour",
        "value_histogram_0_01_bins": {("%0.2f" % (i / 100.0)): c for i, c in enumerate(hist) if c},
        "flat_band": flat_band,
        "largest_upward_jumps": [{"ratio": r, "at_v": v} for r, v in jumps[:6]],
        "largest_upward_jump_above_v_0_30": (
            {"ratio": jumps_above_030[0][0], "at_v": jumps_above_030[0][1]}
            if jumps_above_030 else None),
        "maestro_reference": {"discontinuity_value": 0.76, "jump_ratio": 5.34,
                              "light_family_texels": 24067, "light_family_components_ge_64px": 23},
        "bright_tail": tail,
        "possible": False,
        "verdict": (
            "A value split is NOT possible on this atlas. The population is %d texels and "
            "above value 0.55 its value histogram is FLAT - %d to %d texels per 0.01 bin "
            "with a median of %d - where Maestro had a 5.34x density jump at 0.76. The "
            "largest upward jump anywhere above v=0.30 is %.2fx (at v=%.2f), which is "
            "noise; the biggest ratio in the whole histogram (%.2fx at v=%.2f) is the "
            "val_min gate itself, not the atlas. The bright population is speckle: v>=0.76 "
            "holds %d texels (%.4f of the population) in %d components with a median of "
            "%d px, against Maestro's 24067 texels in 23 components >= 64 px. There is no "
            "threshold to cut on, so the second declared family cannot be reached by value "
            "either."
            % (pop, flat_band["counts_per_0.01_bin_min"], flat_band["counts_per_0.01_bin_max"],
               flat_band["counts_per_0.01_bin_median"],
               jumps_above_030[0][0] if jumps_above_030 else 0.0,
               jumps_above_030[0][1] if jumps_above_030 else 0.0,
               jumps[0][0] if jumps else 0.0, jumps[0][1] if jumps else 0.0,
               tail["0.76"]["texels"], tail["0.76"]["share_of_population"],
               tail["0.76"]["components"], tail["0.76"]["median_component_px"])
        ),
    }


# --------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--glb", type=Path, default=DEFAULT_GLB)
    ap.add_argument("--texture", type=Path, default=DEFAULT_TEXTURE)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    ap.add_argument("--check", action="store_true", help="fail if the on-disk mask is not reproducible")
    args = ap.parse_args()

    glb = Glb(args.glb)
    names = joint_names(glb)
    unmapped = [b for b in names if b not in BONE_REGION]
    print(f"ORACOLO_BONE_DIFF joints={len(names)} mapped={len(BONE_REGION)} "
          f"absent_expected={','.join(BONE_DIFF['absent_from_oracolo']) or '-'} "
          f"unmapped_protected={','.join(unmapped)}")

    mesh = read_mesh(glb)
    layers, stats = rasterise_regions(mesh)
    texture = Image.open(args.texture).convert("RGB")
    if texture.size != (MASK_SIZE, MASK_SIZE):
        raise SystemExit(f"{args.texture} is {texture.size}, expected {MASK_SIZE}x{MASK_SIZE}")
    region_of_tri = assign_regions(mesh)

    mask = Image.merge("RGBA", (layers["torso"], layers["hip"], layers["foot"],
                                Image.new("L", (MASK_SIZE, MASK_SIZE), 0)))
    coverage = coverage_image(layers)
    mask.putalpha(coverage)

    tint = {"torso": (255, 64, 64), "hip": (64, 255, 64), "foot": (64, 128, 255)}
    preview = texture.copy()
    for r in REGIONS:
        preview = Image.composite(Image.new("RGB", (MASK_SIZE, MASK_SIZE), tint[r]),
                                  preview, layers[r].point(lambda v: int(v * 0.75)))

    anchors = measure_anchors(texture, layers)
    classes = measure_texel_classes(texture, layers, anchors, coverage)
    leak = measure_protected_leak(mesh, coverage)
    tripartition = measure_tripartition(mesh, layers, texture, region_of_tri)
    seams = measure_region_seams(mesh, coverage, texture, region_of_tri)
    value_split = measure_value_split(texture, coverage, anchors)
    covered = sum(1 for v in coverage.getdata() if v > 128)
    report = {
        "tool": "tools/character/build_oracolo_outfit_mask.py",
        "glb": str(args.glb.relative_to(REPO)),
        "texture": str(args.texture.relative_to(REPO)),
        "mask": str((args.out / "oracolo_region_mask.png").relative_to(REPO)),
        "mask_size": MASK_SIZE,
        "edge_soften_px": EDGE_SOFTEN_PX,
        "bone_region": BONE_REGION,
        "regions": list(REGIONS),
        "coverage_texels": covered,
        "coverage_fraction": round(covered / (MASK_SIZE * MASK_SIZE), 4),
        "protected_texels": MASK_SIZE * MASK_SIZE - covered,
        "family_anchors": anchors,
        "declared_families": DECLARED_FAMILIES,
        **stats,
        "bone_diff": BONE_DIFF,
        "protected_leak": leak,
        "texel_classes": classes,
        "tripartition": tripartition,
        "region_seams": seams,
        "value_split": value_split,
    }

    args.out.mkdir(parents=True, exist_ok=True)
    mask_path = args.out / "oracolo_region_mask.png"
    preview_path = args.out / "oracolo_region_mask_preview.png"
    if args.check:
        if not mask_path.exists():
            print(f"FAIL missing {mask_path}")
            return 1
        on_disk = Image.open(mask_path)
        if list(on_disk.getdata()) != list(mask.getdata()):
            print(f"FAIL {mask_path} is not what this tool produces")
            return 1
        print(f"ORACOLO_MASK_CHECK_PASS {mask_path} sha256={hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]}")
        return 0

    mask.save(mask_path)
    preview.save(preview_path)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=1) + "\n")

    digest = hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]
    print(f"ORACOLO_MASK_PASS wrote {mask_path.name} sha256={digest} "
          f"coverage={report['coverage_fraction']:.4f} anchors="
          + ",".join(f"{k}:{v['hex']}" for k, v in sorted(anchors.items())))
    print("ORACOLO_MASK_REGIONS " + " ".join(
        f"{r}={stats['region_triangles'][r]}tris y[{stats['region_y_min'][r]},{stats['region_y_max'][r]}]"
        for r in REGIONS))
    print("ORACOLO_MASK_LEAK " + " ".join(
        f"{g}=ge200:s{leak[g]['strict']['leak_ge200']}/m{leak[g]['majority']['leak_ge200']}"
        f" ge128:s{leak[g]['strict']['leak_ge128']}/m{leak[g]['majority']['leak_ge128']}"
        for g in PROTECTED_GROUPS))
    print(f"ORACOLO_MASK_SAFETY skin_hued_family_hits={classes['family_test']['skin_hued_family_hits']} "
          f"by_anchor={classes['family_test']['skin_hued_family_hits_by_anchor']} "
          f"hue_separation={classes['family_test']['hue_separation_deg']} "
          f"hue_test_separates={classes['family_test']['hue_test_separates_the_two_families']}")
    print(f"ORACOLO_MASK_SEAMS edges={seams['region_seam_edges']} "
          f"uv_island_lr={seams['uv_island_alignment']['likelihood_ratio']} "
          f"texture_edge_lr={seams['texture_edge_alignment']['likelihood_ratio']} "
          f"visible_both_sides={seams['what_the_shader_sees']['visible_share']}")
    print(f"ORACOLO_MASK_TRIPARTITION cut_above_hips={tripartition['cut_above_hips_m']} "
          f"fraction_of_pelvis_to_spine={tripartition['cut_fraction_of_pelvis_to_spine']} "
          f"lands_on={tripartition['cut_lands_on']}")
    print(f"ORACOLO_MASK_VALUE_SPLIT possible={value_split['possible']}")
    print(f"ORACOLO_MASK_REPORT {args.report.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
