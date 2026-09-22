#!/usr/bin/env python3
"""Build the explicit UV garment mask for Colosso's outfit variants.

WHY THIS EXISTS
---------------
This is the Colosso twin of `tools/character/build_maestro_outfit_mask.py` (itself the
Maestro twin of `tools/character/build_fiamma_outfit_mask.py`). The shader
`outfit_recolour.gdshader` finds the garment by saturation, which works on the Volpe
fox but not on a human athlete whose skin is as saturated as the kit. The masked lane
instead takes the region from an explicit UV mask, so
`outfit_region_recolour.gdshader` is the shader that consumes it.

Same pipeline as Fiamma and Maestro, same mask channels, same report shape:

  R = torso garment, G = hip garment, B = foot garment, A = coverage (evidence only).

Nothing here looks at the texture to decide *where* a garment is. Every triangle is
assigned to the bone that dominates its vertices, the bone picks a garment region
(torso / hip / foot), and the triangle is rasterised into UV space under that region.
Skin, hair and eyes are never *painted* because no bone that owns them maps to a
region. The texture is consulted only *inside* a region, to tell the recolourable
families of the baked atlas apart, and - in the skin section - to measure whether the
shader could tell the character's skin from his garment if it had to.

DELIBERATE DIFFERENCES FROM THE MAESTRO TOOL
--------------------------------------------
1. BONES. Colosso's rig has 28 joints with the `mixamorig:` prefix - the Fiamma
   naming, not Maestro's bare names - and its spine chain ascends
   (`Spine`/`Spine1`/`Spine2`), unlike Maestro's descending chain. All 14 bones of
   the Fiamma map exist here, including `LeftToe_End`/`RightToe_End`, so nothing is
   substituted and nothing is missing. See `BONE_REGION` and the `bone_diff` block.
2. FAMILY WINDOWS ARE VALUE WINDOWS, AND THAT IS THE FINDING. Fiamma's two families
   are two hues (lime 77 deg / navy 219 deg); Maestro's are one hue 20 deg apart split
   by value. Colosso's atlas is tighter still: every chromatic texel inside the mask
   sits between hue 21 and 45 - the dark leather at 33-39 deg, the character's own skin
   at 21-27 deg, the dark browns at 27-33 deg. The whole chromatic content spans 24
   deg, less than one `hue_tol_deg` (45), so no anchor placed anywhere in that band can
   fail to match most of the recolourable mask. The two families this tool reports are
   therefore split by the measured value step, and the report says plainly that the hue
   test does not separate them. See FAMILY_WINDOWS and `texel_classes.family_test`.
3. The report carries a `skin_protection` block Maestro's does not. Maestro's skin sits
   at hue 20 deg against anchors at 200 and 220, so `skin_hued_family_hits` was zero
   and the mask was sufficient on its own. Colosso's skin sits *inside* the garment's
   own hue band, so "can the shader reject the skin?" has to be answered with numbers
   rather than assumed. It is answered here, and the answer is no. See the block and
   the `verdict` field.
4. The waist split stays at world Y 1.0 and is NOT re-tuned. The measurement that
   justifies it for this rig is in the `waist_cut` block of the report.

Outputs (under `--out`, default `godot/assets/athletes/outfits/colosso/`):
  colosso_region_mask.png          2048x2048 RGBA, R=torso G=hip B=foot A=coverage
  colosso_region_mask_preview.png  the same mask tinted, for eyeballing

and a JSON report (under `--report`) with the coverage, the per-region measured family
anchors, the protected-texel count, the leak evidence and the skin separation result.

Deterministic: no randomness, no timestamps in the image bytes. `--check`
re-rasterises and exits 1 if the file on disk differs.

    python3 tools/character/build_colosso_outfit_mask.py
    python3 tools/character/build_colosso_outfit_mask.py --check
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
DEFAULT_GLB = REPO / "godot/assets/athletes/colosso.glb"
DEFAULT_TEXTURE = REPO / "godot/assets/athletes/colosso_texture_0.png"
DEFAULT_OUT = REPO / "godot/assets/athletes/outfits/colosso"
DEFAULT_REPORT = REPO / "docs/agent-work/outfits-3d/evidence/colosso-mask-report.json"

MASK_SIZE = 2048
EDGE_SOFTEN_PX = 1.2

## Bone -> garment region, using Colosso's REAL joint names (verified against
## skin.joints of colosso.glb: 28 joints, `mixamorig:` prefix, spine ascending).
## Anything absent is protected: it can never be painted.
##
## This is the Fiamma map verbatim, and it is not a guess: all 14 names were read back
## out of the GLB (the run log prints `missing_from_rig=[]`). The shins
## (LeftLeg/RightLeg) are deliberately absent, exactly as in Fiamma and Maestro: a sock
## is found by the family test inside the foot region, and the shin's bare skin would
## only add false positives.
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

## How this rig differs from the two rigs already done. Reported, never silently
## substituted.
BONE_DIFF = {
    "colosso_joint_count": 28,
    "fiamma_joint_count": 28,
    "maestro_joint_count": 24,
    "prefix": "mixamorig: (as Fiamma, unlike Maestro's bare names)",
    "absent_from_colosso": [],
    "renamed": {},
    "missing_from_rig": [],
    "note": "Colosso's rig is the Fiamma rig shape: 28 joints, `mixamorig:` prefix, "
            "spine chain ascending (Spine -> Spine1 -> Spine2), and both Toe_End joints "
            "present. Every one of the 14 bones in BONE_REGION was found in "
            "skins[0].joints by name; nothing is missing and nothing is invented. "
            "Against Maestro the differences are the prefix, the spine numbering "
            "direction and the two Toe_End joints - all three of which change no "
            "triangle, because Maestro's map covers the same anatomy.",
}

REGIONS = ("torso", "hip", "foot")

## The two recolourable families of the baked atlas. MEASURED, not chosen - and for
## this athlete the discriminator is VALUE, not hue.
##
## Inside the mask, of 45,723 recolourable texels sampled at step 4 (hue x value table
## reproduced in COLOSSO-MASK.md):
##   hue 21-27 (the character's skin, modal #906040): 82% of them sit at value 0.50-0.70;
##   hue 33-39 (the dark ochre leather, modal #786038 / #907040): spread over 0.15-0.70,
##      mass at 0.25-0.60;
##   hue 27-33 (dark brown, transitional): mass at 0.15-0.35.
## Hue cannot separate them: the modal hues are 12 deg apart under a 45 deg tolerance,
## and the entire chromatic content of this atlas lives in 21-45 deg. Value does
## separate the DARK garment from the light one, and the split below is the boundary of
## the largest step of the 0.05-binned in-mask value histogram (0.45-0.50 -> 0.50-0.55,
## x1.635; the x1.588 step at 0.50-0.55 -> 0.55-0.60 is the second largest). The report
## is explicit that the light family this produces IS the character's skin tone, which
## is the whole problem for this athlete.

## The measured value cut used to define the two families: the boundary of the largest
## step of the 0.05-binned in-mask value histogram, 0.45-0.50 -> 0.50-0.55 at x1.635. It
## is NOT a density discontinuity - Maestro's was x5.34 - and the report says so.
## Reported, and used only to describe the atlas - not pushed to the shader.
VALUE_SPLIT = 0.50

## Derived from VALUE_SPLIT, so the two families and the split statistic cannot drift
## apart: whatever the split is, it is the shared edge of the two value windows.
FAMILY_WINDOWS = {
    "leather": {"hue": (15.0, 45.0), "value": (0.02, VALUE_SPLIT)},
    "light": {"hue": (15.0, 45.0), "value": (VALUE_SPLIT, 0.98)},
}

## The measured Fiamma cut, kept verbatim; the justification for this rig is in the
## `waist_cut` block of the report (Hips joint and first spine joint heights).
WAIST_Y = 1.0

## The shader's family test, as the masked lane actually runs it: the values
## outfit_catalogue.gd pushes into every material from MASK_DEFAULTS (protect_sat 0.22,
## hue_tol_deg 45.0, sat_min 0.18, val_min 0.02, val_max 0.98, luma_clamp 0.45/1.7).
## Mirrored here ONLY to simulate what the shader can and cannot recolour - this tool
## does not retune them.
MASK_DEFAULTS = {
    "protect_sat": 0.22,
    "hue_tol_deg": 45.0,
    "sat_min": 0.18,
    "val_min": 0.02,
    "val_max": 0.98,
    "luma_clamp_lo": 0.45,
    "luma_clamp_hi": 1.7,
}

## Bone groups that own no garment region: their triangles are the control for the leak
## test AND the honest population from which the character's skin colour is measured
## (face, arms, forearms, hands, shins - no garment bone can claim them).
PROTECTED_GROUPS = {
    "Head": ["mixamorig:Head", "mixamorig:HeadTop_End", "headfront", "mixamorig:Neck"],
    "Hands": ["mixamorig:LeftHand", "mixamorig:RightHand",
              "mixamorig:LeftHandMiddle4", "mixamorig:RightHandMiddle4"],
    "ForeArm": ["mixamorig:LeftForeArm", "mixamorig:RightForeArm"],
    "Arm": ["mixamorig:LeftArm", "mixamorig:RightArm"],
    "Shin": ["mixamorig:LeftLeg", "mixamorig:RightLeg"],
}

## Hue band that reads as exposed skin in this atlas (Colosso's baked skin is at hue 24,
## saturation 0.53-0.59, value 0.53-0.63). Reported, and used to prove whether skin
## inside the mask can be recoloured.
SKIN_HUE = (0.0, 60.0)

## The port's own skin heuristic, quoted from
## tools/character/compare_maestro_renders.py (SKIN_HUE_LO/HI, SKIN_SAT_MIN,
## SKIN_VAL_MIN). It is a heuristic, not a proof - a hue window cannot tell skin from a
## warm garment - but it is the window the render lane uses, so the skin numbers here
## are given both as a tight window around the measured skin anchor and as this one.
PROJECT_SKIN_WINDOW = {"hue_deg": (9.0, 37.8), "sat_min": 0.30, "val_min": 0.30}

## Tight window around the measured skin anchor, used for the "texels inside the mask
## that carry the character's own skin tone" count: +-6 deg of hue, +-0.10 of saturation
## and value - tight enough that no leather texel fits (the nearest leather modal is
## 12 deg of hue and 0.09 of value away).
SKIN_MATCH_TOL = {"hue_deg": 6.0, "sat": 0.10, "val": 0.10}

_QUALIFY_SAT = 0.45          # gate for the skin-anchor measurement on the protected bones
_QUALIFY_VAL = (0.45, 0.70)  # ditto; keeps hair, shadow and the black leather out

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

    joint_y = {names[k]: xform(glob[skin["joints"][k]], (0, 0, 0))[1] for k in range(len(names))}
    return {
        "names": names,
        "dominant": dominant,
        "world": world,
        "uv": glb.accessor(prim["attributes"]["TEXCOORD_0"]),
        "index": [v[0] for v in glb.accessor(prim["indices"])],
        "joint_y": joint_y,
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
        # painting arbitrary triangles of the chest piece with hip colours.
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


def rasterise_bone_groups(mesh: dict, rule: int) -> dict[str, Image.Image]:
    """One layer per protected group; `rule` = how many of the three vertices must be
    dominated by the group (3 = strict, 2 = majority)."""
    names, dominant, uv, index = mesh["names"], mesh["dominant"], mesh["uv"], mesh["index"]
    out = {}
    for label, bones in PROTECTED_GROUPS.items():
        img = Image.new("L", (MASK_SIZE, MASK_SIZE), 0)
        d = ImageDraw.Draw(img)
        for t in range(0, len(index), 3):
            tri = [index[t + k] for k in range(3)]
            if sum(1 for v in tri if names[dominant[v]] in bones) < rule:
                continue
            d.polygon([(uv[v][0] * MASK_SIZE, uv[v][1] * MASK_SIZE) for v in tri], fill=255)
        out[label] = img
    return out


def rasterise_bone_layers(mesh: dict, bone_list) -> dict[str, Image.Image]:
    """One layer per bone, strict (all three vertices dominated by that bone)."""
    names, dominant, uv, index = mesh["names"], mesh["dominant"], mesh["uv"], mesh["index"]
    out = {b: Image.new("L", (MASK_SIZE, MASK_SIZE), 0) for b in bone_list}
    drawers = {b: ImageDraw.Draw(img) for b, img in out.items()}
    for t in range(0, len(index), 3):
        tri = [index[t + k] for k in range(3)]
        bs = {names[dominant[v]] for v in tri}
        if len(bs) == 1:
            b = bs.pop()
            if b in out:
                drawers[b].polygon([(uv[v][0] * MASK_SIZE, uv[v][1] * MASK_SIZE) for v in tri], fill=255)
    return out


def rasterise_bone_owners(mesh: dict) -> tuple[dict[str, Image.Image], dict]:
    """One layer per BONE_REGION bone, one owner per triangle: the region bone that
    dominates the most of the triangle's three vertices (plurality; ties broken by bone
    name so the result is deterministic).

    This is a PARTITION of the masked area, which `rasterise_bone_layers` is not: that
    one draws a triangle only when all three of its vertices are dominated by the same
    bone, so every mixed-dominance triangle belongs to no bone at all. Attribution that
    has to add up - "which garment bone owns these skin-toned texels" - needs a
    partition; the strict layers are reported next to it as the secondary number.
    """
    names, dominant, uv, index = mesh["names"], mesh["dominant"], mesh["uv"], mesh["index"]
    out: dict[str, Image.Image] = {}
    by_owner = Counter()
    for t in range(0, len(index), 3):
        tri = [index[t + k] for k in range(3)]
        votes = Counter(names[dominant[v]] for v in tri if names[dominant[v]] in BONE_REGION)
        if not votes:
            continue
        top = max(votes.values())
        bone = sorted(b for b, n in votes.items() if n == top)[0]
        by_owner[bone] += 1
        if bone not in out:
            out[bone] = Image.new("L", (MASK_SIZE, MASK_SIZE), 0)
        ImageDraw.Draw(out[bone]).polygon(
            [(uv[v][0] * MASK_SIZE, uv[v][1] * MASK_SIZE) for v in tri], fill=255)
    return out, {"triangles_owned": sum(by_owner.values()),
                 "triangles_by_owner": dict(sorted(by_owner.items()))}


def rasterise_bone_groups_any(mesh: dict, rule: int) -> Image.Image:
    """Union of every protected group's layer, so the skin population is measured once
    per texel instead of once per group."""
    layers = rasterise_bone_groups(mesh, rule)
    union = Image.new("L", (MASK_SIZE, MASK_SIZE), 0)
    for label in PROTECTED_GROUPS:
        union = Image.composite(Image.new("L", (MASK_SIZE, MASK_SIZE), 255), union,
                                layers[label].point(lambda v: 255 if v >= 128 else 0))
    return union


# --------------------------------------------------------------------------
# Family measurement (the anchors the shader and the profile quote)
# --------------------------------------------------------------------------

def classify(hue_deg: float, sat: float, val: float) -> str:
    """Which of the two families a texel belongs to, by the measured windows."""
    for family, w in FAMILY_WINDOWS.items():
        lo, hi = w["hue"]
        vlo, vhi = w["value"]
        if lo <= hue_deg < hi and vlo <= val < vhi:
            return family
    return ""


def measure_anchors(texture: Image.Image, layers: dict[str, Image.Image]) -> dict:
    """The recolourable families of the baked atlas, measured *inside* the garment
    regions only. Skin outside the mask cannot vote here.

    Same gates as the Fiamma/Maestro tools (saturation >= 0.25, value >= 0.08, modal
    quantised colour at 8/255 steps); the windows differ, see FAMILY_WINDOWS."""
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
            "modal_hue_deg": round(_rgb_hue_deg([r / 255.0, g / 255.0, b / 255.0]), 1),
            "samples": len(samples),
            "modal_hits": hits,
        }
    return out


def _rgb_hue_deg(srgb) -> float:
    h, _, _ = colorsys.rgb_to_hsv(*srgb)
    return h * 360.0


# --------------------------------------------------------------------------
# The question this athlete forces: can the shader tell his skin from his kit?
# --------------------------------------------------------------------------

def measure_skin(texture: Image.Image, skin_layer: Image.Image, anchors: dict,
                 coverage: Image.Image, region_masks: dict[str, Image.Image],
                 owner_bone_masks: dict[str, Image.Image],
                 strict_bone_masks: dict[str, Image.Image], value_hist: Counter,
                 value_total: int) -> dict:
    """Skin is measured on the STRICT protected-group triangles (face, arms, forearms,
    hands, shins) - no garment bone owns them, so whatever colour is there is the
    character's skin, and it is outside the mask. Then the shader's own family test is
    run on that population, and the mask is scanned for texels carrying that exact tone.

    Everything is reported as measured. Where a number says the skin would be
    recoloured, it is reported as such."""
    px = texture.load()
    skin_pt = skin_layer.point(lambda v: 255 if v >= 128 else 0).load()
    cpd = coverage.point(lambda v: 255 if v >= 128 else 0).load()
    region_pt = {r: m.point(lambda v: 255 if v >= 128 else 0).load() for r, m in region_masks.items()}
    owner_pt = {b: m.point(lambda v: 255 if v >= 128 else 0).load() for b, m in owner_bone_masks.items()}
    strict_pt = {b: m.point(lambda v: 255 if v >= 128 else 0).load() for b, m in strict_bone_masks.items()}

    # (a) the skin anchor: modal colour on the strict skin triangles, gated to the
    # saturated mid-value band so hair and shadow cannot vote.
    buckets = Counter()
    skin_samples = 0
    for y in range(0, MASK_SIZE, 2):
        for x in range(0, MASK_SIZE, 2):
            if skin_pt[x, y] < 128:
                continue
            r, g, b = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s >= _QUALIFY_SAT and 15.0 <= h * 360 <= 30.0 and _QUALIFY_VAL[0] <= v <= _QUALIFY_VAL[1]:
                buckets[(r // 8 * 8, g // 8 * 8, b // 8 * 8)] += 1
                skin_samples += 1
    (sr, sg, sb), skin_hits = buckets.most_common(1)[0]
    skin_srgb = (sr / 255.0, sg / 255.0, sb / 255.0)
    sh, ss, sv = colorsys.rgb_to_hsv(*skin_srgb)
    skin_anchor_hue = sh * 360.0

    anchor_hue = {f: _rgb_hue_deg(a["srgb"]) for f, a in anchors.items()}
    tol = MASK_DEFAULTS["hue_tol_deg"]
    skin_lo, skin_hi = SKIN_HUE

    def tight(rgb) -> bool:
        h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
        dh = abs((h * 360.0 - skin_anchor_hue + 180.0) % 360.0 - 180.0)
        return (dh <= SKIN_MATCH_TOL["hue_deg"]
                and abs(s - ss) <= SKIN_MATCH_TOL["sat"]
                and abs(v - sv) <= SKIN_MATCH_TOL["val"])

    skin_texels = 0
    skin_matching = Counter()
    skin_in_project_window = 0
    inmask_skin_toned = 0
    inmask_total = 0
    inmask_by_region = Counter()
    inmask_skin_by_region = Counter()
    inmask_skin_by_bone = Counter()
    inmask_skin_strict_by_bone = Counter()
    inmask_skin_unattributed = 0
    inmask_skin_ambiguous = 0
    inmask_skin_in_no_region = 0
    inmask_skin_in_several_regions = 0
    inmask_skin_val = Counter()
    skin_val = Counter()
    garment_val = Counter()
    for y in range(0, MASK_SIZE, 2):
        for x in range(0, MASK_SIZE, 2):
            rgb = px[x, y]
            on_skin = skin_pt[x, y] >= 128
            in_mask = cpd[x, y] >= 128
            if not on_skin and not in_mask:
                continue
            h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
            hue = h * 360.0
            if on_skin:
                skin_texels += 1
                if s >= MASK_DEFAULTS["sat_min"]:
                    skin_val[int(v * 100)] += 1
                if skin_lo <= hue < skin_hi and s > PROJECT_SKIN_WINDOW["sat_min"] \
                        and v > PROJECT_SKIN_WINDOW["val_min"]:
                    skin_in_project_window += 1
                for family, ah in anchor_hue.items():
                    dh = abs((hue - ah + 180.0) % 360.0 - 180.0)
                    if dh < tol and s >= MASK_DEFAULTS["sat_min"] \
                            and MASK_DEFAULTS["val_min"] <= v <= MASK_DEFAULTS["val_max"]:
                        skin_matching[family] += 1
            if in_mask:
                inmask_total += 1
                regions_here = [r for r in REGIONS if region_pt[r][x, y] >= 128]
                for r in regions_here:
                    inmask_by_region[r] += 1
                if s >= MASK_DEFAULTS["sat_min"] \
                        and MASK_DEFAULTS["val_min"] <= v <= MASK_DEFAULTS["val_max"] \
                        and not tight(rgb):
                    # the chromatic garment population, the counterweight to the skin in
                    # the value separation measured below
                    garment_val[int(v * 100)] += 1
                if tight(rgb):
                    inmask_skin_toned += 1
                    inmask_skin_val[int(v * 100)] += 1
                    # Attribution is a PARTITION: each texel lands in exactly one bucket,
                    # and the leftovers (no owner, or two owners on a shared edge) are
                    # counted too. The previous rule incremented a counter for every bone
                    # layer covering the texel, so its rows added up to 24490 of the 45059
                    # texels they claimed to explain and the missing 20569 were invisible.
                    if len(regions_here) == 1:
                        inmask_skin_by_region[regions_here[0]] += 1
                    elif regions_here:
                        inmask_skin_in_several_regions += 1
                    else:
                        inmask_skin_in_no_region += 1
                    owners_here = [b for b, pt in owner_pt.items() if pt[x, y] >= 128]
                    if len(owners_here) == 1:
                        inmask_skin_by_bone[owners_here[0]] += 1
                    elif owners_here:
                        inmask_skin_ambiguous += 1
                    else:
                        inmask_skin_unattributed += 1
                    for b, pt in strict_pt.items():
                        if pt[x, y] >= 128:
                            inmask_skin_strict_by_bone[b] += 1

    # (c) does the value gate separate the two families, and where would it cut?
    # value_hist keys are int(value * 100), i.e. percent.
    bins = sorted(value_hist)
    split_idx = int(round(VALUE_SPLIT * 100))
    total = sum(value_hist.values())
    floor = max(200, int(0.002 * total))  # ignore the near-empty low tail bins
    steps = []
    for a, b in zip(bins, bins[1:]):
        if b - a != 1 or a < 15 or b > 95:
            continue
        lo, hi = value_hist[a], value_hist[b]
        if lo >= floor and hi >= floor:
            steps.append((round(hi / lo, 3), a, b, lo, hi))
    steps.sort(reverse=True)
    best = steps[0] if steps else None
    # the transition region, where the dark mass ends and the light peak begins
    mid = [s for s in steps if 30 <= s[1] <= 60]
    mid_best = mid[0] if mid else None
    split_step = (round(value_hist[split_idx] / value_hist[split_idx - 1], 3)
                  if value_hist.get(split_idx - 1) and value_hist.get(split_idx) else None)
    below = sum(value_hist[k] for k in bins if k < split_idx)
    above = sum(value_hist[k] for k in bins if k >= split_idx)
    band = sum(value_hist[k] for k in bins if 44 <= k < 52)
    skin_light = sum(v for k, v in inmask_skin_val.items() if k >= split_idx)

    # The 0.05-binned histogram, computed rather than asserted. The split constant is
    # defined as the boundary of THIS histogram's largest step, and a 1%-bin ratio is
    # noise next to it (x0.718 one bin left of the split, x1.599 one bin right), so the
    # two must not be quoted as if they were the same number.
    agg05 = Counter()
    for k, n in value_hist.items():
        agg05[int(k // 5) * 5] += n
    agg_bins = sorted(agg05)
    steps05 = [(round(agg05[b] / agg05[a], 3), a, b, agg05[a], agg05[b])
               for a, b in zip(agg_bins, agg_bins[1:])
               if agg05[a] >= floor and agg05[b] >= floor and 15 <= a <= 85]
    steps05.sort(reverse=True)
    best05 = steps05[0] if steps05 else None
    second05 = steps05[1] if len(steps05) > 1 else None
    at_split05 = next((s for s in steps05 if s[2] == split_idx), None)

    # How far the value test gets if it is pushed as far as it goes: the single cut that
    # best puts the skin above and the chromatic garment below. This is the ceiling of
    # the idea, so it is measured instead of argued - twice, because the two populations
    # answer different questions: inside the mask (what the shader actually has to decide
    # on) and against the whole measured skin population (outside it, on the protected
    # bones, where no garment bone can claim the texels).
    skin_gated = sum(skin_val.values())
    garment_gated = sum(garment_val.values())

    def best_cut(skin_hist: Counter, other_hist: Counter):
        n = sum(skin_hist.values()) + sum(other_hist.values())
        best = None
        for thr in range(30, 80):
            sk_above = sum(v for k, v in skin_hist.items() if k >= thr)
            ga_below = sum(v for k, v in other_hist.items() if k < thr)
            acc = (sk_above + ga_below) / n if n else 0.0
            if best is None or acc > best[0]:
                best = (acc, thr, sk_above, ga_below)
        return best

    cut = best_cut(inmask_skin_val, garment_val)   # inside the mask, the deciding pair
    cut_out = best_cut(skin_val, garment_val)      # measured skin vs the same garment mass

    def cut_block(best, skin_hist, note: str):
        if not best:
            return None
        skin_n = sum(skin_hist.values())
        other_n = sum(garment_val.values())
        return {
            "threshold": round(best[1] / 100, 2),
            "balanced_accuracy": round(best[0], 4),
            "bar_for_separating": 0.95,
            "skin_above_the_cut": best[2], "skin_below_the_cut": skin_n - best[2],
            "garment_below_the_cut": best[3],
            "garment_above_the_cut_landing_on_the_skin_side": other_n - best[3],
            "skin_population_texels": skin_n,
            "garment_population_texels": other_n,
            "note": note,
            "sampling": "every second texel (step 2), the sample this whole block uses",
        }

    # (d) The shader's own family weight, mirrored. outfit_region_recolour.gdshader
    # ::family_weight is graded, not a hard window:
    #   w = (1 - smoothstep(tol*0.55, tol, dh)) * ss((s - sat_min)/0.12) * ss((v - val_min)/0.12)
    # with the value gate off. A window test says "matches"; this says how strongly, and
    # for this athlete's skin it says 1.0 for BOTH anchors - the skin is not merely inside
    # the tolerance, it is at the centre of the ramp.
    def _ss(x: float) -> float:
        x = min(1.0, max(0.0, x))
        return x * x * (3.0 - 2.0 * x)

    def _smoothstep(a: float, b: float, x: float) -> float:
        if b == a:
            return 0.0
        t = min(1.0, max(0.0, (x - a) / (b - a)))
        return t * t * (3.0 - 2.0 * t)

    def family_weight(rgb, anchor_deg: float) -> float:
        h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
        dh = abs((h * 360.0 - anchor_deg + 180.0) % 360.0 - 180.0)
        tol = MASK_DEFAULTS["hue_tol_deg"]
        return ((1.0 - _smoothstep(tol * 0.55, tol, dh))
                * _ss((s - MASK_DEFAULTS["sat_min"]) / 0.12)
                * _ss((v - MASK_DEFAULTS["val_min"]) / 0.12))

    full_weight_inmask = Counter()
    full_weight_skin = Counter()
    min_weight_inmask = {}
    for y in range(0, MASK_SIZE, 2):
        for x in range(0, MASK_SIZE, 2):
            on_skin = skin_pt[x, y] >= 128
            in_mask = cpd[x, y] >= 128
            if not on_skin and not in_mask:
                continue
            rgb = px[x, y]
            for family, ah in anchor_hue.items():
                w = family_weight(rgb, ah)
                if in_mask and tight(rgb):
                    min_weight_inmask[family] = min(min_weight_inmask.get(family, 1.0), w)
                    if w >= 0.99:
                        full_weight_inmask[family] += 1
                if on_skin and w >= 0.99:
                    full_weight_skin[family] += 1

    skin_match_frac = {f: round(skin_matching[f] / skin_texels, 4) for f in anchor_hue}
    skin_toned_frac = round(inmask_skin_toned / inmask_total, 4) if inmask_total else 0.0
    owners_txt = ", ".join(f"{b} {n}" for b, n in
                           sorted(inmask_skin_by_bone.items(), key=lambda kv: -kv[1])[:4]) or "none"
    cut_txt = (f"Pushed as far as it goes, the best single value cut inside the mask "
               f"({cut[1] / 100:.2f}) still puts {garment_gated - cut[3]} chromatic garment "
               f"texels on the skin's side and {sum(inmask_skin_val.values()) - cut[2]} skin-toned "
               f"texels on the garment's side, balanced accuracy {cut[0]:.3f} - below the 0.95 a "
               "separation would need."
               if cut else "No value cut could be measured.")
    return {
        "skin_anchor": {
            "hex": "#%02x%02x%02x" % (sr, sg, sb),
            "srgb": [round(c, 4) for c in skin_srgb],
            "hue_deg": round(skin_anchor_hue, 1),
            "sat": round(ss, 3),
            "val": round(sv, 3),
            "samples": skin_samples,
            "modal_hits": skin_hits,
            "measured_on": "strict protected-group triangles (head, arms, forearms, hands, shins)",
        },
        "skin_population_texels": skin_texels,
        "skin_texels_in_project_skin_window": skin_in_project_window,
        "skin_texels_matching_anchor": dict(skin_matching),
        "skin_match_fraction": skin_match_frac,
        "skin_window_used": dict(PROJECT_SKIN_WINDOW),
        "inmask_texels": inmask_total,
        "inmask_texels_carrying_skin_tone": inmask_skin_toned,
        "inmask_skin_tone_fraction": skin_toned_frac,
        "inmask_skin_tone_by_region": {**{r: inmask_skin_by_region[r] for r in REGIONS},
                                       "in_several_regions": inmask_skin_in_several_regions,
                                       "in_no_region": inmask_skin_in_no_region},
        "inmask_skin_tone_by_garment_bone": {k: v for k, v in sorted(inmask_skin_by_bone.items()) if v},
        "inmask_skin_tone_attribution": {
            "rule": "one owner per triangle - the BONE_REGION bone dominating the most of "
                    "that triangle's three vertices, ties broken by bone name - so the "
                    "per-bone rows are a partition and sum to the texel count they explain",
            "attributed": sum(inmask_skin_by_bone.values()),
            "unattributed_texels": inmask_skin_unattributed,
            "ambiguous_texels": inmask_skin_ambiguous,
            "total": inmask_skin_toned,
            "unattributed_note": "texels inside the mask that no garment-bone triangle owns: "
                                 "protected geometry caught by the 1.2 px edge soften, or "
                                 "coverage overlap between islands",
            "strict_all_three_vertices_secondary": {
                "counts": {k: v for k, v in sorted(inmask_skin_strict_by_bone.items()) if v},
                "covers_texels": sum(inmask_skin_strict_by_bone.values()),
                "note": "the strict rule draws a triangle only when all three vertices are "
                        "dominated by the same bone, so a texel on a mixed-dominance "
                        "triangle belongs to no bone and is missing here; this is why the "
                        "strict rows never summed to the total and must not be read as a "
                        "partition",
            },
        },
        "skin_match_tolerance": dict(SKIN_MATCH_TOL),
        "shader_family_weight_mirror": {
            "formula": "w = (1 - smoothstep(hue_tol_deg*0.55, hue_tol_deg, dh)) * "
                       "ss((s - sat_min)/0.12) * ss((v - val_min)/0.12), value gate off - "
                       "outfit_region_recolour.gdshader::family_weight, run with the "
                       "MASK_DEFAULTS windows and the anchors' modal hues",
            "weight_on_the_skin_anchor_colour": {f: round(family_weight((sr, sg, sb), ah), 4)
                                                 for f, ah in anchor_hue.items()},
            "inmask_skin_toned_texels": inmask_skin_toned,
            "inmask_skin_toned_at_full_weight_ge_0.99": {f: full_weight_inmask[f] for f in anchor_hue},
            "inmask_skin_toned_min_weight": {f: round(min_weight_inmask.get(f, 0.0), 4)
                                             for f in anchor_hue},
            "skin_population_outside_the_mask_texels": skin_texels,
            "skin_population_outside_the_mask_at_full_weight_ge_0.99": {
                f: full_weight_skin[f] for f in anchor_hue},
            "note": "the skin of this athlete sits at the centre of both anchors' ramps, so the "
                    "shader recolours it at full weight for both families; outside the mask the "
                    "mask is what keeps it out, and inside the mask nothing does",
        },
        "value_gate": {
            "split_tried": VALUE_SPLIT,
            "split_defined_as": "the boundary of the largest step of the 0.05-binned in-mask "
                                "value histogram, near-empty low bins floored out",
            "texels_below": below,
            "texels_above": above,
            "ambiguous_band_0.44_0.52": band,
            "value_histogram_0.01": {str(round(k / 100, 2)): value_hist[k] for k in bins},
            "value_histogram_0.05": {str(round(k / 100, 2)): agg05[k] for k in agg_bins},
            "bin_0.05_floor": floor,
            "largest_step_0.05_bins": ({
                "ratio": best05[0], "from_bin": round(best05[1] / 100, 2),
                "to_bin": round(best05[2] / 100, 2), "boundary": round(best05[2] / 100, 2),
                "from_n": best05[3], "to_n": best05[4]} if best05 else None),
            "second_largest_step_0.05_bins": ({
                "ratio": second05[0], "from_bin": round(second05[1] / 100, 2),
                "to_bin": round(second05[2] / 100, 2), "boundary": round(second05[2] / 100, 2),
                "from_n": second05[3], "to_n": second05[4]} if second05 else None),
            "step_0.05_bins_at_the_chosen_split": ({
                "ratio": at_split05[0], "from_bin": round(at_split05[1] / 100, 2),
                "to_bin": round(at_split05[2] / 100, 2), "from_n": at_split05[3],
                "to_n": at_split05[4]} if at_split05 else None),
            "step_0.01_bins_at_the_chosen_split": split_step,
            "largest_step_anywhere_0.01_bins": ({"ratio": best[0], "from_bin": round(best[1] / 100, 2),
                                                 "to_bin": round(best[2] / 100, 2), "from_n": best[3],
                                                 "to_n": best[4]} if best else None),
            "largest_step_in_transition_0.30_0.60_0.01_bins": (
                {"ratio": mid_best[0], "from_bin": round(mid_best[1] / 100, 2),
                 "to_bin": round(mid_best[2] / 100, 2), "from_n": mid_best[3],
                 "to_n": mid_best[4]} if mid_best else None),
            "step_ratio_vs_maestro_5.34": (round(best05[0] / 5.34, 2) if best05 else None),
            "value_test_separates_the_two_families": bool(
                at_split05 is not None and at_split05[0] >= 1.4),
            "value_test_separates_skin_from_garment": bool(cut is not None and cut[0] >= 0.95),
            "best_value_cut_for_skin_vs_garment_inside_the_mask": cut_block(
                cut, inmask_skin_val,
                "skin side = the in-mask texels carrying the measured skin tone; garment side = "
                "the in-mask chromatic texels that are not skin-toned. This is the pair the "
                "shader has to decide on, and it does not separate."),
            "best_value_cut_for_skin_vs_garment_measured_skin": cut_block(
                cut_out, skin_val,
                "same scan against the whole measured skin population on the protected bones "
                "(outside the mask), against the same garment mass inside it."),
            "note": (
                f"The split at {VALUE_SPLIT:.2f} is the boundary of the largest step of the "
                f"0.05-binned in-mask value histogram"
                + (f" ({best05[1] / 100:.2f}-{best05[2] / 100:.2f} -> {best05[2] / 100:.2f}-"
                   f"{(best05[2] + 5) / 100:.2f}, x{best05[0]:.3f}); the second largest is "
                   f"x{second05[0]:.3f} one bin higher." if best05 and second05 else ".")
                + " It is NOT the density discontinuity Maestro's split sits on (x5.34): at "
                + (f"0.01 resolution the histogram is still rising through the split "
                   f"(x{split_step:.3f}), and the largest 1%-bin step in the transition is "
                   f"x{mid_best[0]:.3f} at {mid_best[1] / 100:.2f}->{mid_best[2] / 100:.2f}, "
                   f"inside the light family's own peak" if mid_best and split_step else
                   "0.01 resolution the histogram has no clean edge here")
                + ". What no value cut fixes is what it separates: the light side is the "
                  "character's own skin."),
            "but_the_light_side_is_the_skin": True,
            "skin_toned_texels_in_the_light_side": skin_light,
            "skin_population_texels_below_the_split": sum(
                v for k, v in skin_val.items() if k < split_idx),
            "skin_population_texels_below_the_split_note":
                "population = on-skin texels with s >= sat_min (the same gate as "
                "skin_toned_texels_in_the_light_side); the report used to carry the ungated "
                "count of every on-skin texel below the split, which is a different "
                "population and 3.7x larger",
            "skin_population_texels_with_the_sat_gate": skin_gated,
        },
        "skin_recolourable_verdict": (
            "NO. The skin population measured on the protected bones sits at hue "
            f"{round(skin_anchor_hue, 1)} deg - inside the garment's own hue band (21-45 deg) - so "
            "the shader's 45 deg family test cannot reject it: "
            f"{skin_match_frac.get('leather', 0) * 100:.1f}% of the skin texels answer to the "
            f"leather anchor and {skin_match_frac.get('light', 0) * 100:.1f}% to the light anchor. "
            f"Inside the mask, {inmask_skin_toned} sampled texels "
            f"({skin_toned_frac * 100:.2f}% of it) carry that exact skin tone, on bare skin the "
            f"garment bones own: {owners_txt}. A value gate separates the dark leather from the "
            "light family, but the light family IS the skin: "
            f"{skin_light} of those {inmask_skin_toned} texels "
            f"({100.0 * skin_light / inmask_skin_toned:.1f}%) sit above the split. {cut_txt}"
        ),
    }


def measure_texel_classes(texture: Image.Image, layers: dict[str, Image.Image], anchors: dict,
                          coverage: Image.Image, skin: dict) -> dict:
    """What the mask actually covers, and whether any of it can be recoloured.

    Every texel the mask covers is classified once (leather / light / skin / neutral /
    other), then put through the shader's own family test with the MASK_DEFAULTS
    windows. `skin_hued_family_hits` is the number that matters: a texel sitting on bare
    skin that the shader would recolour."""
    px = texture.load()
    cp = coverage.point(lambda v: 1 if v >= 128 else 0).load()
    anchor_hue = {f: _rgb_hue_deg(a["srgb"]) for f, a in anchors.items()}
    tol = MASK_DEFAULTS["hue_tol_deg"]
    skin_anchor = skin["skin_anchor"]
    skin_rgb = skin_anchor["srgb"]
    skin_hue_deg = skin_anchor["hue_deg"]
    skin_sat = skin_anchor["sat"]
    skin_val = skin_anchor["val"]
    counts = Counter()
    fam_hits = Counter()
    both_anchors = 0
    skin_family_hits = 0
    neutral_reasons = Counter()
    per_region = {r: Counter() for r in REGIONS}
    region_layers = {r: layers[r].point(lambda v: 1 if v >= 128 else 0).load() for r in REGIONS}
    for y in range(MASK_SIZE):
        for x in range(MASK_SIZE):
            if not cp[x, y]:
                continue
            rgb = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
            hue = h * 360.0
            if s < MASK_DEFAULTS["sat_min"]:
                cls = "neutral"
                neutral_reasons["achromatic_s_below_sat_min"] += 1
            elif v < MASK_DEFAULTS["val_min"]:
                cls = "neutral"
                neutral_reasons["too_dark_v_below_val_min"] += 1
            elif v > MASK_DEFAULTS["val_max"]:
                cls = "neutral"
                neutral_reasons["too_bright_v_above_val_max"] += 1
            else:
                dh = abs((hue - skin_hue_deg + 180.0) % 360.0 - 180.0)
                is_skin_toned = (dh <= SKIN_MATCH_TOL["hue_deg"]
                                 and abs(s - skin_sat) <= SKIN_MATCH_TOL["sat"]
                                 and abs(v - skin_val) <= SKIN_MATCH_TOL["val"])
                if is_skin_toned:
                    cls = "skin"
                else:
                    cls = classify(hue, s, v) or ("skin" if SKIN_HUE[0] <= hue < SKIN_HUE[1] else "other")
            counts[cls] += 1
            for r in REGIONS:
                if region_layers[r][x, y]:
                    per_region[r][cls] += 1
            # The shader evaluates both anchors independently (fam_a and fam_b, no
            # else-if), so a texel can match both - which is the whole separability
            # question for a pair of anchors 12 deg apart under a 45 deg tolerance.
            matched = 0
            for family, ah in anchor_hue.items():
                dha = abs((hue - ah + 180.0) % 360.0 - 180.0)
                if dha < tol:
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
        "classes": {k: counts[k] for k in ("leather", "light", "skin", "neutral", "other") if counts[k]},
        "neutral_breakdown": {
            **{k: neutral_reasons[k] for k in
               ("achromatic_s_below_sat_min", "too_dark_v_below_val_min", "too_bright_v_above_val_max")},
            "recolourable_chromatic_texels": total - sum(neutral_reasons.values()),
            "recolourable_fraction_of_the_mask": round(
                (total - sum(neutral_reasons.values())) / total, 4) if total else None,
            "thresholds": {"sat_min": MASK_DEFAULTS["sat_min"], "val_min": MASK_DEFAULTS["val_min"],
                           "val_max": MASK_DEFAULTS["val_max"]},
            "note": "the mask is a permission map: these are the texels it covers that the "
                    "shader cannot recolour at all, because sat_min rejects the greys and the "
                    "value window rejects the near-black and the blown-out",
        },
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


def measure_protected_leak(mesh: dict, coverage: Image.Image) -> dict:
    """How much of the mask falls on body parts that own no garment region.

    Attribution matters and is reported both ways, because the loose rule lies:
      strict    all three vertices dominated by the protected group
      majority  at least two of three
    A triangle with a single arm or shin corner is a torso/hip triangle - the hem and
    the sleeve seam - and belongs in the mask. Counting it as a leak inflated the first
    Maestro measurement from 0.0002 to 0.28."""
    # Two coverages, because they answer different questions: >=200 is the geometric
    # region (no Gaussian bleed, the honest area measure), >=128 is what the shader's
    # linear filtering can actually see.
    hard = coverage.point(lambda v: 255 if v >= 200 else 0)
    soft = coverage.point(lambda v: 255 if v >= 128 else 0)
    out = {}
    for rule, need in (("strict", 3), ("majority", 2)):
        layers = rasterise_bone_groups(mesh, need)
        for label, img in layers.items():
            texels = img.histogram()[255]
            inside_hard = ImageChops.multiply(img, hard).histogram()[255]
            inside_soft = ImageChops.multiply(img, soft).histogram()[255]
            row = {
                "texels": texels,
                "inside_mask_texels_ge200": inside_hard,
                "leak_ge200": round(inside_hard / texels, 4) if texels else 0.0,
                "inside_mask_texels_ge128": inside_soft,
                "leak_ge128": round(inside_soft / texels, 4) if texels else 0.0,
            }
            out.setdefault(label, {})[rule] = row
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
    missing = [b for b in BONE_REGION if b not in names]
    BONE_DIFF["missing_from_rig"] = missing
    if missing:
        raise SystemExit(f"BONE_REGION names absent from the rig: {missing}")
    unmapped = [b for b in names if b not in BONE_REGION]
    print(f"COLOSSO_BONE_DIFF joints={len(names)} mapped={len(BONE_REGION)} "
          f"missing_from_rig=[] unmapped_protected={','.join(unmapped)}")

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

    # value histogram of the recolourable in-mask texels, for the value-split evidence
    value_hist = Counter()
    value_total = 0
    px = texture.load()
    cp_pt = coverage.point(lambda v: 255 if v >= 128 else 0).load()
    for y in range(0, MASK_SIZE, 2):
        for x in range(0, MASK_SIZE, 2):
            if cp_pt[x, y] < 128:
                continue
            r, g, b = px[x, y]
            _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s >= MASK_DEFAULTS["sat_min"] and MASK_DEFAULTS["val_min"] <= v <= MASK_DEFAULTS["val_max"]:
                value_hist[int(v * 100)] += 1
                value_total += 1

    skin_layer = rasterise_bone_groups_any(mesh, 3)
    owner_bone_masks, owner_stats = rasterise_bone_owners(mesh)
    strict_bone_masks = rasterise_bone_layers(mesh, sorted(BONE_REGION))

    skin = measure_skin(texture, skin_layer, anchors, coverage, layers, owner_bone_masks,
                        strict_bone_masks, value_hist, value_total)
    classes = measure_texel_classes(texture, layers, anchors, coverage, skin)
    leak = measure_protected_leak(mesh, coverage)
    covered = sum(1 for v in coverage.getdata() if v > 128)

    hips_y = mesh["joint_y"].get("mixamorig:Hips")
    spine_y = mesh["joint_y"].get("mixamorig:Spine")
    waist = {
        "waist_y": WAIST_Y,
        "hips_joint_y": round(hips_y, 4) if hips_y is not None else None,
        "first_spine_joint_y": round(spine_y, 4) if spine_y is not None else None,
        "fraction_of_pelvis_to_spine": (round((WAIST_Y - hips_y) / (spine_y - hips_y), 4)
                                        if hips_y is not None and spine_y not in (None, hips_y) else None),
        "note": "Not re-tuned. Reported so the cut can be checked against the rig it is "
                "applied to, exactly as for Maestro.",
    }

    family_test = classes["family_test"]
    vg = skin["value_gate"]
    skin_ok = (family_test["skin_hued_family_hits"] == 0
               and skin["inmask_texels_carrying_skin_tone"] == 0)
    verdict = (
        "MASK USABLE AS A PERMISSION MAP, NOT USABLE AS A TWO-FAMILY RECOLOUR MAP. "
        f"The mask itself is sound: {stats['region_triangles']['torso']} torso / "
        f"{stats['region_triangles']['hip']} hip / {stats['region_triangles']['foot']} foot "
        f"triangles, {covered} covered texels ({round(covered / (MASK_SIZE ** 2), 4)} of the atlas), "
        f"strict leak on the head, hands, forearms, arms and shins at or below "
        f"{max(leak[g]['strict']['leak_ge200'] for g in PROTECTED_GROUPS):.4f} of each group's own UV area. "
        "It is NOT sufficient to keep Colosso's skin out of a recolour: the atlas's whole "
        "chromatic content lives in hue 21-45 deg, the anchors are "
        f"{family_test['hue_separation_deg']} deg apart under a {MASK_DEFAULTS['hue_tol_deg']} deg "
        "tolerance, so the hue test separates nothing "
        f"({family_test['texels_matching_both_anchors']} of {classes['masked_texels']} masked texels "
        "answer to both anchors, including every skin-toned texel inside the mask). The value "
        f"test splits the dark mass from the light one at {vg['split_tried']:.2f} "
        f"(x{vg['largest_step_0.05_bins']['ratio'] if vg['largest_step_0.05_bins'] else 0} in "
        f"0.05 bins against Maestro's x5.34, i.e. a ramp, not a discontinuity), but what it "
        "cannot separate is what the split puts on the light side: "
        f"{vg['skin_toned_texels_in_the_light_side']} of the "
        f"{skin['inmask_texels_carrying_skin_tone']} skin-toned sampled texels inside the mask "
        f"({100.0 * vg['skin_toned_texels_in_the_light_side'] / max(1, skin['inmask_texels_carrying_skin_tone']):.1f}%) "
        "are above it, and the best single value cut for skin-vs-garment inside the mask still "
        f"lands {vg['best_value_cut_for_skin_vs_garment_inside_the_mask']['garment_above_the_cut_landing_on_the_skin_side']} "
        "chromatic garment texels on the skin's side. "
        f"{skin['inmask_texels_carrying_skin_tone']} sampled masked texels "
        f"({skin['inmask_skin_tone_fraction'] * 100:.2f}% of the mask) carry the character's own "
        f"skin tone, and {classes['neutral_breakdown']['recolourable_fraction_of_the_mask'] * 100:.2f}% "
        "of the mask is chromatic and inside the shader's value window at all."
    )

    report = {
        "tool": "tools/character/build_colosso_outfit_mask.py",
        "glb": str(args.glb.relative_to(REPO)),
        "texture": str(args.texture.relative_to(REPO)),
        "mask": str((args.out / "colosso_region_mask.png").relative_to(REPO)),
        "mask_size": MASK_SIZE,
        "edge_soften_px": EDGE_SOFTEN_PX,
        "bone_region": BONE_REGION,
        "regions": list(REGIONS),
        "coverage_texels": covered,
        "coverage_fraction": round(covered / (MASK_SIZE * MASK_SIZE), 4),
        "protected_texels": MASK_SIZE * MASK_SIZE - covered,
        "family_anchors": anchors,
        "family_windows": FAMILY_WINDOWS,
        "value_split": VALUE_SPLIT,
        **stats,
        "waist_cut": waist,
        "bone_diff": BONE_DIFF,
        "bone_owners": owner_stats,
        "protected_leak": leak,
        "texel_classes": classes,
        "skin_protection": skin,
        "ok": bool(skin_ok),
        "verdict": verdict,
    }

    args.out.mkdir(parents=True, exist_ok=True)
    mask_path = args.out / "colosso_region_mask.png"
    preview_path = args.out / "colosso_region_mask_preview.png"
    if args.check:
        if not mask_path.exists():
            print(f"FAIL missing {mask_path}")
            return 1
        on_disk = Image.open(mask_path)
        if list(on_disk.getdata()) != list(mask.getdata()):
            print(f"FAIL {mask_path} is not what this tool produces")
            return 1
        print(f"COLOSSO_MASK_CHECK_PASS {mask_path} sha256={hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]}")
        return 0

    mask.save(mask_path)
    preview.save(preview_path)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=1) + "\n")

    digest = hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]
    print(f"COLOSSO_MASK_PASS wrote {mask_path.name} sha256={digest} "
          f"coverage={report['coverage_fraction']:.4f} anchors="
          + ",".join(f"{k}:{v['hex']}" for k, v in sorted(anchors.items())))
    print("COLOSSO_MASK_REGIONS " + " ".join(
        f"{r}={stats['region_triangles'][r]}tris y[{stats['region_y_min'][r]},{stats['region_y_max'][r]}]"
        for r in REGIONS))
    print("COLOSSO_MASK_LEAK " + " ".join(
        f"{g}=ge200:s{leak[g]['strict']['leak_ge200']}/m{leak[g]['majority']['leak_ge200']}"
        f" ge128:s{leak[g]['strict']['leak_ge128']}/m{leak[g]['majority']['leak_ge128']}"
        for g in PROTECTED_GROUPS))
    print(f"COLOSSO_MASK_SAFETY skin_hued_family_hits={family_test['skin_hued_family_hits']} "
          f"hue_separation={family_test['hue_separation_deg']} "
          f"hue_test_separates={family_test['hue_test_separates_the_two_families']} "
          f"skin_anchor={skin['skin_anchor']['hex']}@h{skin['skin_anchor']['hue_deg']} "
          f"inmask_skin_toned={skin['inmask_texels_carrying_skin_tone']}"
          f"({skin['inmask_skin_tone_fraction'] * 100:.2f}%) "
          f"skin_match={skin['skin_match_fraction']}")
    print(f"COLOSSO_MASK_VALUE_GATE split={vg['split_tried']} "
          f"largest_step_0.05={vg['largest_step_0.05_bins']['ratio']}"
          f"@{vg['largest_step_0.05_bins']['boundary']} "
          f"second_0.05={vg['second_largest_step_0.05_bins']['ratio']} "
          f"vs_maestro_5.34={vg['step_ratio_vs_maestro_5.34']} "
          f"separates_two_families={vg['value_test_separates_the_two_families']} "
          f"separates_skin_from_garment={vg['value_test_separates_skin_from_garment']} "
          f"skin_vs_garment_best_cut="
          f"{vg['best_value_cut_for_skin_vs_garment_inside_the_mask']['threshold']}"
          f"@{vg['best_value_cut_for_skin_vs_garment_inside_the_mask']['balanced_accuracy']}")
    sw = skin["shader_family_weight_mirror"]
    print(f"COLOSSO_MASK_SHADER_WEIGHT weight_on_skin_anchor="
          f"{sw['weight_on_the_skin_anchor_colour']} "
          f"inmask_skin_toned_full_weight={sw['inmask_skin_toned_at_full_weight_ge_0.99']}"
          f" of {sw['inmask_skin_toned_texels']} "
          f"min_weight={sw['inmask_skin_toned_min_weight']} "
          f"skin_outside_mask_full_weight="
          f"{sw['skin_population_outside_the_mask_at_full_weight_ge_0.99']}"
          f" of {sw['skin_population_outside_the_mask_texels']}")
    print(f"COLOSSO_MASK_REPORT {args.report.relative_to(REPO)}")
    att = skin["inmask_skin_tone_attribution"]
    nb = classes["neutral_breakdown"]
    print(f"COLOSSO_MASK_ATTRIBUTION inmask_skin_toned={skin['inmask_texels_carrying_skin_tone']} "
          f"attributed={att['attributed']} unattributed={att['unattributed_texels']} "
          f"ambiguous={att['ambiguous_texels']} "
          f"strict_rule_covers={att['strict_all_three_vertices_secondary']['covers_texels']}")
    print(f"COLOSSO_MASK_NEUTRAL achromatic={nb['achromatic_s_below_sat_min']} "
          f"too_dark={nb['too_dark_v_below_val_min']} too_bright={nb['too_bright_v_above_val_max']} "
          f"recolourable={nb['recolourable_chromatic_texels']}"
          f"({nb['recolourable_fraction_of_the_mask']})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
