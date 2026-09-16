#!/usr/bin/env python3
"""Count triangles per GLB by parsing the GLB container and the glTF JSON chunk.

No third-party imports: reads the 12-byte GLB header, the JSON chunk, and then for
every mesh primitive resolves its indices accessor and sums index counts / 3.
Also reports primitive count, material count, image count, joint count and clip count
so the "single baked material / no garment zones" claim is measured, not repeated.

Usage: python3 glb_tri_count.py FILE.glb [FILE.glb ...]
"""
import json
import os
import struct
import sys

COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
MODE_TRIANGLES = 4


def read_glb(path):
    with open(path, "rb") as fh:
        blob = fh.read()
    magic, version, length = struct.unpack_from("<4sII", blob, 0)
    if magic != b"glTF":
        raise ValueError("%s: not a GLB (magic=%r)" % (path, magic))
    if length != len(blob):
        raise ValueError("%s: header length %d != file size %d" % (path, length, len(blob)))
    off = 12
    gltf_json = None
    bin_len = 0
    while off < len(blob):
        clen, ctype = struct.unpack_from("<I4s", blob, off)
        off += 8
        if ctype == b"JSON":
            gltf_json = json.loads(blob[off:off + clen].decode("utf-8"))
        elif ctype == b"BIN\x00":
            bin_len = clen
        off += clen
    return gltf_json, len(blob), bin_len, version


def parse(path):
    g, size, bin_len, version = read_glb(path)
    accessors = g.get("accessors", [])
    tri_total = 0
    vert_total = 0
    per_prim = []
    for mi, mesh in enumerate(g.get("meshes", [])):
        for pi, prim in enumerate(mesh.get("primitives", [])):
            mode = prim.get("mode", MODE_TRIANGLES)
            if mode != MODE_TRIANGLES:
                per_prim.append((mi, pi, "mode=%d (not triangles)" % mode, 0))
                continue
            idx = prim.get("indices")
            if idx is not None:
                count = accessors[idx].get("count", 0)
                tris = count // 3
                verts = accessors[prim["attributes"]["POSITION"]].get("count", 0)
                vert_total += verts
            else:
                verts = accessors[prim["attributes"]["POSITION"]].get("count", 0)
                vert_total += verts
                tris = verts // 3
            tri_total += tris
            per_prim.append((mi, pi, mesh.get("name", "mesh%d" % mi), tris))
    skins = g.get("skins", [])
    joints = sum(len(s.get("joints", [])) for s in skins)
    clips = g.get("animations", [])
    clip_info = []
    for a in clips:
        max_t = 0.0
        for s in a.get("samplers", []):
            acc = accessors[s["input"]]
            if acc.get("max"):
                max_t = max(max_t, float(acc["max"][0]))
        clip_info.append((a.get("name", "?"), round(max_t, 3)))
    mats = g.get("materials", [])
    mat_names = [m.get("name", "?") for m in mats]
    baked = []
    for m in mats:
        pbr = m.get("pbrMetallicRoughness", {})
        tex = pbr.get("baseColorTexture")
        baked.append({
            "name": m.get("name", "?"),
            "baseColorTexture": tex.get("index") if tex else None,
            "baseColorFactor": pbr.get("baseColorFactor"),
            "has_vertex_colors": any("COLOR_0" in p.get("attributes", {})
                                     for me in g.get("meshes", []) for p in me.get("primitives", [])),
        })
    return {
        "file": os.path.basename(path),
        "path": os.path.abspath(path),
        "bytes": size,
        "glb_version": version,
        "bin_chunk_bytes": bin_len,
        "triangles": tri_total,
        "vertices": vert_total,
        "primitives": len(per_prim),
        "per_primitive": per_prim,
        "materials": mat_names,
        "material_detail": baked,
        "images": len(g.get("images", [])),
        "textures": len(g.get("textures", [])),
        "skins": len(skins),
        "joints": joints,
        "animations": clip_info,
        "nodes": len(g.get("nodes", [])),
        "accessors": len(accessors),
    }


def main(argv):
    rows = []
    for p in argv:
        try:
            rows.append(parse(p))
        except Exception as exc:  # noqa: BLE001 - report, do not hide
            rows.append({"file": os.path.basename(p), "error": repr(exc)})
    print(json.dumps(rows, indent=1))
    ok = [r for r in rows if "triangles" in r]
    if len(ok) > 1:
        print("\nSUM triangles across %d files: %d" % (len(ok), sum(r["triangles"] for r in ok)))
        print("MAX triangles in a single file: %d" % max(r["triangles"] for r in ok))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
