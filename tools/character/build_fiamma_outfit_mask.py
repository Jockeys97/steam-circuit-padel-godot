#!/usr/bin/env python3
"""Build the explicit UV garment mask for Fiamma's outfit variants.

WHY THIS EXISTS
---------------
`outfit_recolour.gdshader` masks the *Volpe* atlas by colour: the fox's ivory fur
sits below a saturation floor and the garment sits above it. That trick cannot be
reused on a human athlete -- Fiamma's skin is as saturated as her kit -- so the
Meshy bodies need a real mask instead.

This tool writes one. It never looks at the texture to decide *where* a garment
is: the region comes from the skeleton. Every triangle is assigned to the bone
that dominates its vertices, the bone picks a garment region (torso / hip /
foot), and the triangle is rasterised into UV space under that region. Skin,
hair and eyes are never painted because no bone that owns them maps to a region.

The texture is consulted only *inside* a region, and only to tell the two
recolourable families of the baked atlas apart (the lime kit and its navy trim).
A texel outside every region keeps its base colour no matter what it looks like.

Outputs (under `--out`, default `godot/assets/athletes/outfits/fiamma/`):
  fiamma_region_mask.png   2048x2048 RGBA, R=torso G=hip B=foot A=coverage
  fiamma_region_mask_preview.png   the same mask tinted, for eyeballing

and a JSON report (under `--report`) with the coverage, the per-region measured
family anchors and the protected-texel count that the acceptance criteria quote.

Deterministic: no randomness, no timestamps in the image bytes. `--check`
re-rasterises and exits 1 if the file on disk differs.

    python3 tools/character/build_fiamma_outfit_mask.py
    python3 tools/character/build_fiamma_outfit_mask.py --check
"""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parents[2]
DEFAULT_GLB = REPO / "godot/assets/athletes/fiamma.glb"
DEFAULT_TEXTURE = REPO / "godot/assets/athletes/fiamma_texture_0.png"
DEFAULT_OUT = REPO / "godot/assets/athletes/outfits/fiamma"
DEFAULT_REPORT = REPO / "docs/agent-work/outfits-3d/evidence/fiamma-mask-report.json"

MASK_SIZE = 2048
EDGE_SOFTEN_PX = 1.2

## Bone -> garment region. Anything absent is protected: it can never be painted.
## The shins are deliberately *not* here even though Fiamma wears socks: a sock is
## found by the family test inside the foot region, and the shin's own bare skin
## would only add false positives.
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

REGIONS = ("torso", "hip", "foot")

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
# Rasterisation
# --------------------------------------------------------------------------

def rasterise_regions(glb: Glb) -> tuple[dict[str, Image.Image], dict]:
    gltf = glb.json
    prim = gltf["meshes"][0]["primitives"][0]
    pos = glb.accessor(prim["attributes"]["POSITION"])
    uv = glb.accessor(prim["attributes"]["TEXCOORD_0"])
    joints = glb.accessor(prim["attributes"]["JOINTS_0"])
    weights = glb.accessor(prim["attributes"]["WEIGHTS_0"])
    index = [v[0] for v in glb.accessor(prim["indices"])]

    skin = gltf["skins"][0]
    ibm = glb.accessor(skin["inverseBindMatrices"])
    globals_ = node_globals(gltf)
    joint_names = [gltf["nodes"][n].get("name", "") for n in skin["joints"]]

    # Bind-pose world transform of every joint, then of every vertex through its
    # dominant joint. The mesh is a Mixamo export whose bind pose is a T-pose, so
    # the bone that owns a vertex is a far better region signal than its height.
    bind = [mat_mul(globals_[skin["joints"][k]], ibm[k]) for k in range(len(joint_names))]
    dominant = []
    world = []
    for i in range(len(pos)):
        best, best_w = 0, -1.0
        for k in range(4):
            if weights[i][k] > best_w:
                best_w, best = weights[i][k], joints[i][k]
        dominant.append(best)
        world.append(xform(bind[best], pos[i]))

    vertex_region = [BONE_REGION.get(joint_names[d], "") for d in dominant]

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
            region = "torso" if sum(world[v][1] for v in tri) / 3.0 > 1.0 else "hip"
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

def measure_anchors(texture: Image.Image, layers: dict[str, Image.Image]) -> dict:
    """The two recolourable families of the baked atlas, measured *inside* the
    garment regions only. Skin and hair cannot vote here: they are outside."""
    px = texture.load()
    masks = {r: layer.load() for r, layer in layers.items()}
    buckets: dict[str, list[tuple[float, tuple[int, int, int]]]] = {}
    for name, layer in masks.items():
        for y in range(0, MASK_SIZE, 4):
            for x in range(0, MASK_SIZE, 4):
                if layer[x, y] < 200:
                    continue
                rgb = px[x, y]
                h, s, v = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
                if s < 0.25 or v < 0.08:
                    continue
                hue = h * 360.0
                family = "lime" if 40 <= hue <= 130 else ("navy" if 180 <= hue <= 265 else None)
                if family is None:
                    continue
                buckets.setdefault(family, []).append((hue, rgb))
    out = {}
    for family, samples in sorted(buckets.items()):
        # The anchor is the *modal* colour, not the mean: shading variants would
        # drag a mean toward the dark side and make the luma-preserving ratio wrong.
        from collections import Counter
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


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--glb", type=Path, default=DEFAULT_GLB)
    ap.add_argument("--texture", type=Path, default=DEFAULT_TEXTURE)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    ap.add_argument("--check", action="store_true", help="fail if the on-disk mask is not reproducible")
    args = ap.parse_args()

    glb = Glb(args.glb)
    layers, stats = rasterise_regions(glb)
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
    covered = sum(1 for v in coverage.getdata() if v > 128)
    report = {
        "tool": "tools/character/build_fiamma_outfit_mask.py",
        "glb": str(args.glb.relative_to(REPO)),
        "texture": str(args.texture.relative_to(REPO)),
        "mask": str((args.out / "fiamma_region_mask.png").relative_to(REPO)),
        "mask_size": MASK_SIZE,
        "edge_soften_px": EDGE_SOFTEN_PX,
        "bone_region": BONE_REGION,
        "regions": list(REGIONS),
        "coverage_texels": covered,
        "coverage_fraction": round(covered / (MASK_SIZE * MASK_SIZE), 4),
        "protected_texels": MASK_SIZE * MASK_SIZE - covered,
        "family_anchors": anchors,
        **stats,
    }

    args.out.mkdir(parents=True, exist_ok=True)
    mask_path = args.out / "fiamma_region_mask.png"
    preview_path = args.out / "fiamma_region_mask_preview.png"
    if args.check:
        if not mask_path.exists():
            print(f"FAIL missing {mask_path}")
            return 1
        on_disk = Image.open(mask_path)
        if list(on_disk.getdata()) != list(mask.getdata()):
            print(f"FAIL {mask_path} is not what this tool produces")
            return 1
        print(f"FIAMMA_MASK_CHECK_PASS {mask_path} sha256={hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]}")
        return 0

    mask.save(mask_path)
    preview.save(preview_path)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=1) + "\n")

    digest = hashlib.sha256(mask_path.read_bytes()).hexdigest()[:16]
    print(f"FIAMMA_MASK_PASS wrote {mask_path.name} sha256={digest} "
          f"coverage={report['coverage_fraction']:.4f} anchors="
          + ",".join(f"{k}:{v['hex']}" for k, v in sorted(anchors.items())))
    print(f"FIAMMA_MASK_REGIONS " + " ".join(
        f"{r}={stats['region_triangles'][r]}tris y[{stats['region_y_min'][r]},{stats['region_y_max'][r]}]"
        for r in REGIONS))
    print(f"FIAMMA_MASK_REPORT {args.report.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
