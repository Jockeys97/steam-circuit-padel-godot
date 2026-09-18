#!/usr/bin/env python3
"""make_tiny_prop.py — build `fixtures/tiny_prop.glb`, the tiny STATIC GLB the arena-kit
tests and the puller's offline check use.

Why a hand-built GLB and not a copy of a repo asset: every GLB in this repo is a
*skinned* athlete export of 8.9 MB or more, and the kit's placement math needs one
fixture whose size is known exactly — this box is 0.50 m tall, 0.50 m wide, 0.50 m deep,
with its bottom at y = 0, so "scale to the spec height" is checkable to the millimetre
(scale = target_h / 0.50). It also carries a deliberately WRONG material on purpose:
`metallicFactor 0.9`, `roughnessFactor 0.2`, `emissiveFactor (1,1,1)` — i.e. exactly what
a Meshy export arrives with — so the kit's shared material policy has something real to
correct (`metallic 0.0`, `roughness 0.85`, emission off, albedo kept).

    python3 tools/arena-kit/fixtures/make_tiny_prop.py           # writes next to itself
    python3 tools/arena-kit/fixtures/make_tiny_prop.py --check   # rebuild and compare

Stdlib only; no engine, no network. The GLB is a glTF 2.0 binary container: a JSON chunk
and a BIN chunk, per the glTF 2.0 specification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import struct
import sys

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / "tiny_prop.glb"

# A 0.5 m cube standing on the origin: x/z in ±0.25, y in 0.0 .. 0.5.
HALF = 0.25
HEIGHT = 0.5
POSITIONS = [
    (-HALF, 0.0, -HALF), (HALF, 0.0, -HALF), (HALF, 0.0, HALF), (-HALF, 0.0, HALF),
    (-HALF, HEIGHT, -HALF), (HALF, HEIGHT, -HALF), (HALF, HEIGHT, HALF), (-HALF, HEIGHT, HALF),
]
# 12 triangles, outward winding (front/back/left/right/top/bottom).
INDICES = [
    3, 2, 6, 3, 6, 7,
    1, 0, 4, 1, 4, 5,
    0, 3, 7, 0, 7, 4,
    2, 1, 5, 2, 5, 6,
    7, 6, 5, 7, 5, 4,
    0, 1, 2, 0, 2, 3,
]


def build_glb() -> bytes:
    bin_chunk = struct.pack("<%df" % (len(POSITIONS) * 3), *[c for p in POSITIONS for c in p])
    bin_chunk += struct.pack("<36H", *INDICES)
    while len(bin_chunk) % 4:
        bin_chunk += b"\x00"

    gltf = {
        "asset": {"version": "2.0", "generator": "tools/arena-kit/fixtures/make_tiny_prop.py"},
        "scene": 0,
        "scenes": [{"name": "TinyProp", "nodes": [0]}],
        "nodes": [{"name": "TinyProp", "mesh": 0}],
        "meshes": [{
            "name": "TinyBox",
            "primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "material": 0, "mode": 4}],
        }],
        # The "Meshy defaults" the kit's material policy has to correct — deliberately
        # NOT a clean material.
        "materials": [{
            "name": "MeshyDefaults",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.9, 0.3, 0.2, 1.0],
                "metallicFactor": 0.9,
                "roughnessFactor": 0.2,
            },
            "emissiveFactor": [1.0, 1.0, 1.0],
            "doubleSided": False,
        }],
        "accessors": [
            {
                "bufferView": 0, "componentType": 5126, "count": len(POSITIONS), "type": "VEC3",
                "min": [-HALF, 0.0, -HALF], "max": [HALF, HEIGHT, HALF],
            },
            {"bufferView": 1, "componentType": 5123, "count": len(INDICES), "type": "SCALAR"},
        ],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(POSITIONS) * 12, "target": 34962},
            {"buffer": 0, "byteOffset": len(POSITIONS) * 12, "byteLength": len(INDICES) * 2, "target": 34963},
        ],
        "buffers": [{"byteLength": len(bin_chunk)}],
    }

    json_chunk = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    while len(json_chunk) % 4:
        json_chunk += b" "

    total = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    out = struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(json_chunk), 0x4E4F534A) + json_chunk
    out += struct.pack("<II", len(bin_chunk), 0x004E4942) + bin_chunk
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Build fixtures/tiny_prop.glb (the tiny static GLB fixture).")
    ap.add_argument("--check", action="store_true", help="rebuild and compare with the file on disk")
    args = ap.parse_args()

    data = build_glb()
    if args.check:
        if not OUT.exists():
            print("FAIL: %s does not exist" % OUT)
            return 1
        current = OUT.read_bytes()
        if current != data:
            print("FAIL: %s differs from what this script builds (re-run without --check)" % OUT)
            return 1
        print("OK: %s matches (%d bytes, sha256=%s)" % (OUT, len(data), hashlib.sha256(data).hexdigest()))
        return 0

    OUT.write_bytes(data)
    print("wrote %s (%d bytes, sha256=%s)" % (OUT, len(data), hashlib.sha256(data).hexdigest()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
