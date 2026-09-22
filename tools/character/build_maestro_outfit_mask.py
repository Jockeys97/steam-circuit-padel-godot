#!/usr/bin/env python3
"""Build the explicit UV garment mask for Maestro's outfit variants.

WHY THIS EXISTS
---------------
This is the Maestro twin of `tools/character/build_fiamma_outfit_mask.py`. The shader
`outfit_recolour.gdshader` finds the garment by saturation, which works on the Volpe
fox (ivory fur is less saturated than its kit) but not on a human athlete: Maestro's
skin is as saturated as his kit. The masked lane instead takes the region from an
explicit UV mask, so `outfit_region_recolour.gdshader` is the shader that consumes it.

Same pipeline as Fiamma, same mask channels, same report shape:

  R = torso garment, G = hip garment, B = foot garment, A = coverage (evidence only).

Nothing here looks at the texture to decide *where* a garment is. Every triangle is
assigned to the bone that dominates its vertices, the bone picks a garment region
(torso / hip / foot), and the triangle is rasterised into UV space under that region.
Skin, hair and eyes are never painted because no bone that owns them maps to a
region. The texture is consulted only *inside* a region, to tell the two recolourable
families of the baked atlas apart, and - in the leak section - to prove that no texel
the mask covers on bare skin can match either family.

DELIBERATE DIFFERENCES FROM THE FIAMMA TOOL
-------------------------------------------
1. BONES. Maestro's rig has 24 joints against Fiamma's 28, and the names are NOT
   `mixamorig:*`. They are bare, and the spine chain is numbered downward from the
   pelvis (`Spine02` is the lowest spine joint, `Spine` the top one) - the reverse of
   Fiamma's `Spine`/`Spine1`/`Spine2`. Two bones Fiamma maps are simply absent here:
   `LeftToe_End` and `RightToe_End`. They are left out of BONE_REGION rather than
   invented; the toes are still covered by `LeftToeBase`/`RightToeBase`. See
   `BONE_REGION` below and the `bone_diff` block of the report.
2. FAMILY WINDOWS. Fiamma's two families are told apart by hue (lime ~77 deg vs navy
   ~219 deg). Maestro's are not: the light-blue base (#08bfe8 in the reference
   catalogue) and the navy secondary (#102d68) both sit in the blue band, so the
   measurement splits them at 205 deg - measured, not chosen: inside the mask the
   light family's hue mode is 190-200 deg at value 0.6-0.8 and the dark family's is
   210-220 deg at value 0.2-0.4. A 3x3 min-filter keeps 70% of the light family's
   texels (a painted diagonal band) against 34% of the 0.45<=v<0.75 mid band (the
   antialiased seam).
3. The waist split stays at world Y 1.0 and is NOT re-tuned. Maestro's `Hips` joint
   sits at world Y 0.9517 against Fiamma's 0.9549 (3.2 mm apart) and the first spine
   joint at 1.1042 against 1.0755, so the Fiamma cut lands on the same anatomical
   waist landmark (31.7% of the pelvis-to-spine interval here, 37.4% there).
4. The report carries three blocks Fiamma's does not, because a 24-bone rig deserves
   proof rather than assertion: `bone_diff`, `protected_leak` and `texel_classes`.
   Every key of the Fiamma report is still present, unchanged, with Maestro's values.

Outputs (under `--out`, default `godot/assets/athletes/outfits/maestro/`):
  maestro_region_mask.png          2048x2048 RGBA, R=torso G=hip B=foot A=coverage
  maestro_region_mask_preview.png  the same mask tinted, for eyeballing

and a JSON report (under `--report`) with the coverage, the per-region measured family
anchors, the protected-texel count and the leak evidence.

Deterministic: no randomness, no timestamps in the image bytes. `--check`
re-rasterises and exits 1 if the file on disk differs.

    python3 tools/character/build_maestro_outfit_mask.py
    python3 tools/character/build_maestro_outfit_mask.py --check
"""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parents[2]
DEFAULT_GLB = REPO / "godot/assets/athletes/maestro.glb"
DEFAULT_TEXTURE = REPO / "godot/assets/athletes/maestro_texture_0.png"
DEFAULT_OUT = REPO / "godot/assets/athletes/outfits/maestro"
DEFAULT_REPORT = REPO / "docs/agent-work/outfits-3d/evidence/maestro-mask-report.json"

MASK_SIZE = 2048
EDGE_SOFTEN_PX = 1.2

## Bone -> garment region, using Maestro's REAL joint names (verified against
## skin.joints of maestro.glb: 24 joints, no `mixamorig:` prefix).
## Anything absent is protected: it can never be painted.
##
## Not the Fiamma map, and not a guess. Against the Fiamma map this one drops
## `LeftToe_End` / `RightToe_End` (no such joints exist on this rig) and renames the
## spine chain: Maestro's Spine02/Spine01/Spine are the ascending pelvis->shoulders
## chain that Fiamma spells Spine/Spine1/Spine2. Legs, feet and shoulders match by
## name. The shins (LeftLeg/RightLeg) are deliberately absent, exactly as in Fiamma:
## a sock is found by the family test inside the foot region, and the shin's bare skin
## would only add false positives.
BONE_REGION = {
    "Spine": "torso",
    "Spine01": "torso",
    "Spine02": "torso",
    "LeftShoulder": "torso",
    "RightShoulder": "torso",
    "Hips": "hip",
    "LeftUpLeg": "hip",
    "RightUpLeg": "hip",
    "LeftFoot": "foot",
    "RightFoot": "foot",
    "LeftToeBase": "foot",
    "RightToeBase": "foot",
}

## Bones the Fiamma map expects that Maestro's rig does not have. Reported, never
## silently substituted.
BONE_DIFF = {
    "maestro_joint_count": 24,
    "fiamma_joint_count": 28,
    "absent_from_maestro": ["mixamorig:LeftToe_End", "mixamorig:RightToe_End"],
    "renamed": {"mixamorig:Spine1": "Spine01", "mixamorig:Spine2": "Spine02"},
    "note": "Maestro names its spine chain downward from the pelvis (Spine02 lowest, "
            "then Spine01, then Spine) while Fiamma's Spine/Spine1/Spine2 run upward. "
            "All three map to torso, so the flip moves no triangle. The two missing "
            "bones are Toe_End joints only; the toes stay covered by LeftToeBase and "
            "RightToeBase.",
}

REGIONS = ("torso", "hip", "foot")

## The two recolourable families of the baked atlas, as hue windows in degrees inside
## the mask. Measured for Maestro (see the module docstring): the light family's hue
## mode is 190-200, the dark family's is 210-220, and 205 is the boundary between
## them. Fiamma's windows (40-130 lime, 180-265 navy) cannot be reused here because
## Maestro's two families both fall inside 180-265.
FAMILY_WINDOWS = {
    "sky": (150.0, 205.0),
    "navy": (205.0, 270.0),
}

## The measured Fiamma cut, kept verbatim: Maestro's pelvis sits within 3.2 mm of
## Fiamma's, so the same value lands on the same anatomical waist.
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
    "Head": ["Head", "head_end", "headfront", "neck"],
    "Hands": ["LeftHand", "RightHand"],
    "ForeArm": ["LeftForeArm", "RightForeArm"],
    "Arm": ["LeftArm", "RightArm"],
    "Shin": ["LeftLeg", "RightLeg"],
}

## Hue band that reads as exposed skin in this atlas (Maestro's baked skin sits at
## hue ~20, saturation 0.4-0.7). Used to prove that skin inside the mask cannot match
## a family anchor.
SKIN_HUE = (0.0, 60.0)

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
    # dominant joint. The mesh is a Mixamo export whose bind pose is a T-pose, so
    # the bone that owns a vertex is a far better region signal than its height.
    bind = [mat_mul(glob[skin["joints"][k]], ibm[k]) for k in range(len(names))]
    dominant, world = [], []
    for i in range(len(pos)):
        best, best_w = 0, -1.0
        for k in range(4):
            if weights[i][k] > best_w:
                best_w, best = weights[i][k], joints[i][k]
        dominant.append(best)
        world.append(xform(bind[best], pos[i]))

    return {
        "names": names,
        "dominant": dominant,
        "world": world,
        "uv": glb.accessor(prim["attributes"]["TEXCOORD_0"]),
        "index": [v[0] for v in glb.accessor(prim["indices"])],
    }


def joint_names(glb: Glb) -> list[str]:
    gltf = glb.json
    return [gltf["nodes"][n].get("name", "") for n in gltf["skins"][0]["joints"]]


# --------------------------------------------------------------------------
# Rasterisation
# --------------------------------------------------------------------------

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
        # Hip weights extend into the abdomen. Use bind-space height to avoid
        # painting arbitrary triangles of the tank top with skirt trim colours.
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


# --------------------------------------------------------------------------
# Family measurement (the anchors the shader and the profile quote)
# --------------------------------------------------------------------------

def classify(hue_deg: float, sat: float, val: float) -> str:
    """Which of the two families a texel belongs to, by the measured windows."""
    for family, (lo, hi) in FAMILY_WINDOWS.items():
        if lo <= hue_deg < hi:
            return family
    return ""


def measure_anchors(texture: Image.Image, layers: dict[str, Image.Image]) -> dict:
    """The two recolourable families of the baked atlas, measured *inside* the
    garment regions only. Skin and hair cannot vote here: they are outside.

    Same gates as the Fiamma tool (saturation >= 0.25, value >= 0.08, modal quantised
    colour at 8/255 steps); the hue windows differ, see FAMILY_WINDOWS."""
    px = texture.load()
    masks = {r: layer.load() for r, layer in layers.items()}
    buckets: dict[str, list[tuple[float, tuple[int, int, int]]]] = {}
    for layer in masks.values():
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
    out = {}
    for family, samples in sorted(buckets.items()):
        # The anchor is the *modal* colour, not the mean: shading variants would
        # drag a mean toward the dark side and make the luma-preserving ratio wrong.
        quantised = Counter((r // 8 * 8, g // 8 * 8, b // 8 * 8) for _, (r, g, b) in samples)
        (r, g, b), hits = quantised.most_common(1)[0]
        out[family] = {
            "hex": "#%02x%02x%02x" % (r, g, b),
            "srgb": [round(r / 255.0, 4), round(g / 255.0, 4), round(b / 255.0, 4)],
            "hue_deg": round(sum(h for h, _ in samples) / len(samples), 1),
            "samples": len(samples),
            "modal_hits": hits,
        }
    return out


def measure_texel_classes(texture: Image.Image, layers: dict[str, Image.Image],
                          anchors: dict, coverage: Image.Image) -> dict:
    """What the mask actually covers, and whether any of it can be recoloured.

    Every texel the mask covers is classified once (sky / navy / skin / neutral /
    other), then put through the shader's own family test with the MASK_DEFAULTS
    windows. `skin_hued_family_hits` is the number that matters: a texel sitting on
    bare skin that the shader would recolour. It must be zero, and this is the
    measurement that proves it rather than asserting it."""
    px = texture.load()
    cp = coverage.point(lambda v: 1 if v >= 128 else 0).load()
    anchor_hue = {f: _rgb_hue_deg(a["srgb"]) for f, a in anchors.items()}
    tol = MASK_DEFAULTS["hue_tol_deg"]
    counts = Counter()
    fam_hits = Counter()
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
            # question for a pair of anchors 20 deg apart under a 45 deg tolerance.
            matched = 0
            for family, ah in anchor_hue.items():
                dh = abs((hue - ah + 180.0) % 360.0 - 180.0)
                if dh < tol:
                    fam_hits[family] += 1
                    matched += 1
            if matched > 1:
                both_anchors += 1
            if matched and cls == "skin":
                skin_family_hits += 1
    total = sum(counts.values())
    separation = None
    if len(anchor_hue) == 2:
        a, b = sorted(anchor_hue.values())
        separation = round(b - a, 1)
    return {
        "masked_texels": total,
        "classes": {k: counts[k] for k in ("sky", "navy", "skin", "neutral", "other") if counts[k]},
        "classes_by_region": {r: dict(per_region[r]) for r in REGIONS},
        "family_test": {
            "effective": {k: MASK_DEFAULTS[k] for k in ("hue_tol_deg", "sat_min", "val_min", "val_max")},
            "anchor_hue_deg": {f: round(v, 1) for f, v in anchor_hue.items()},
            "hue_separation_deg": separation,
            "hits": dict(fam_hits),
            "texels_matching_both_anchors": both_anchors,
            "skin_hued_family_hits": skin_family_hits,
            "hue_test_separates_the_two_families": bool(
                separation is not None and separation > 2 * MASK_DEFAULTS["hue_tol_deg"]),
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
    first version of this measurement from 0.0002 to 0.28."""
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
    print(f"MAESTRO_BONE_DIFF joints={len(names)} mapped={len(BONE_REGION)} "
          f"absent_expected={','.join(BONE_DIFF['absent_from_maestro'])} "
          f"unmapped_protected={','.join(unmapped)}")

    mesh = read_mesh(glb)
    layers, stats = rasterise_regions(mesh)
    texture = Image.open(args.texture).convert("RGB")
    if texture.size != (MASK_SIZE, MASK_SIZE):
        raise SystemExit(f"{args.texture} is {texture.size}, expected {MASK_SIZE}x{MASK_SIZE}")

    mask = Image.merge("RGBA", (layers["torso"], layers["hip"], layers["foot"],
                                Image.new("L", (MASK_SIZE, MASK_SIZE), 0)))
    coverage = Image.new("L", (MASK_SIZE, MASK_SIZE), 0)
    for r in REGIONS:
        coverage = Image.composite(Image.new("L", (MASK_SIZE, MASK_SIZE), 255), coverage, layers[r])
    mask.putalpha(coverage)

    tint = {"torso": (255, 64, 64), "hip": (64, 255, 64), "foot": (64, 128, 255)}
    preview = texture.copy()
    for r in REGIONS:
        preview = Image.composite(Image.new("RGB", (MASK_SIZE, MASK_SIZE), tint[r]),
                                  preview, layers[r].point(lambda v: int(v * 0.75)))

    anchors = measure_anchors(texture, layers)
    classes = measure_texel_classes(texture, layers, anchors, coverage)
    leak = measure_protected_leak(mesh, coverage)
    covered = sum(1 for v in coverage.getdata() if v > 128)
    report = {
        "tool": "tools/character/build_maestro_outfit_mask.py",
        "glb": str(args.glb.relative_to(REPO)),
        "texture": str(args.texture.relative_to(REPO)),
        "mask": str((args.out / "maestro_region_mask.png").relative_to(REPO)),
        "mask_size": MASK_SIZE,
        "edge_soften_px": EDGE_SOFTEN_PX,
        "bone_region": BONE_REGION,
        "regions": list(REGIONS),
        "coverage_texels": covered,
        "coverage_fraction": round(covered / (MASK_SIZE * MASK_SIZE), 4),
        "protected_texels": MASK_SIZE * MASK_SIZE - covered,
        "family_anchors": anchors,
        **stats,
        "bone_diff": BONE_DIFF,
        "protected_leak": leak,
        "texel_classes": classes,
    }

    args.out.mkdir(parents=True, exist_ok=True)
    mask_path = args.out / "maestro_region_mask.png"
    preview_path = args.out / "maestro_region_mask_preview.png"
    if args.check:
        if not mask_path.exists():
            print(f"FAIL missing {mask_path}")
            return 1
        on_disk = Image.open(mask_path)
        if list(on_disk.getdata()) != list(mask.getdata()):
            print(f"FAIL {mask_path} is not what this tool produces")
            return 1
        print(f"MAESTRO_MASK_CHECK_PASS {mask_path} sha256={hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]}")
        return 0

    mask.save(mask_path)
    preview.save(preview_path)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=1) + "\n")

    digest = hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]
    print(f"MAESTRO_MASK_PASS wrote {mask_path.name} sha256={digest} "
          f"coverage={report['coverage_fraction']:.4f} anchors="
          + ",".join(f"{k}:{v['hex']}" for k, v in sorted(anchors.items())))
    print("MAESTRO_MASK_REGIONS " + " ".join(
        f"{r}={stats['region_triangles'][r]}tris y[{stats['region_y_min'][r]},{stats['region_y_max'][r]}]"
        for r in REGIONS))
    print("MAESTRO_MASK_LEAK " + " ".join(
        f"{g}=ge200:s{leak[g]['strict']['leak_ge200']}/m{leak[g]['majority']['leak_ge200']}"
        f" ge128:s{leak[g]['strict']['leak_ge128']}/m{leak[g]['majority']['leak_ge128']}"
        for g in PROTECTED_GROUPS))
    print(f"MAESTRO_MASK_SAFETY skin_hued_family_hits={classes['family_test']['skin_hued_family_hits']} "
          f"hue_separation={classes['family_test']['hue_separation_deg']} "
          f"hue_test_separates={classes['family_test']['hue_test_separates_the_two_families']}")
    print(f"MAESTRO_MASK_REPORT {args.report.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
