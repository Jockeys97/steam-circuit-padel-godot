#!/usr/bin/env python3
"""Shrink the embedded textures of a Meshy .glb in place, keeping the mesh untouched.

Meshy exports ship 4096px JPEG atlases embedded in the binary chunk. The stands are
read from ~30 m at ~36 px/m, so a 4096 atlas is two decades past what the frame can
resolve — but the resize is capped at 2048 and quality 92 so there is headroom for a
closer camera later, and the mesh, its UVs and every accessor are copied byte for byte.

    python3 shrink_glb_textures.py <file.glb> [--max 2048] [--quality 92] [--backup DIR]

Prints the before/after sizes and verifies the result re-parses and every image decodes.
"""
import argparse, io, json, os, shutil, struct, sys

from PIL import Image


def read_glb(path):
    with open(path, "rb") as f:
        magic, version, total = struct.unpack("<4sII", f.read(12))
        if magic != b"glTF":
            raise SystemExit(f"{path}: not a binary glTF")
        js = bin_ = None
        while f.tell() < total:
            header = f.read(8)
            if len(header) < 8:
                break
            length, kind = struct.unpack("<I4s", header)
            payload = f.read(length)
            if kind == b"JSON":
                js = payload
            elif kind.rstrip(b"\x00") == b"BIN":
                bin_ = payload
    if js is None:
        raise SystemExit(f"{path}: no JSON chunk")
    return json.loads(js), bytearray(bin_ or b"")


def write_glb(path, doc, blob):
    js = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    while len(js) % 4:
        js += b" "
    while len(blob) % 4:
        blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\x00"))
        f.write(bytes(blob))
    return total


def shrink(path, max_side, quality, backup_dir):
    before = os.path.getsize(path)
    if backup_dir:
        os.makedirs(backup_dir, exist_ok=True)
        dest = os.path.join(backup_dir, os.path.basename(path))
        shutil.copy2(path, dest)
        print(f"  backup -> {dest}")

    doc, blob = read_glb(path)
    replacements = {}
    for index, image in enumerate(doc.get("images", [])):
        if "bufferView" not in image:
            continue
        view = doc["bufferViews"][image["bufferView"]]
        offset, length = view.get("byteOffset", 0), view["byteLength"]
        picture = Image.open(io.BytesIO(bytes(blob[offset:offset + length])))
        width, height = picture.size
        if max(width, height) > max_side:
            factor = max_side / max(width, height)
            picture = picture.resize((round(width * factor), round(height * factor)),
                                     Image.Resampling.LANCZOS)
        out = io.BytesIO()
        picture.convert("RGB").save(out, format="JPEG", quality=quality, optimize=True,
                                    subsampling=0)  # 4:4:4: no chroma loss on flat colour fields
        replacements[image["bufferView"]] = out.getvalue()
        print(f"  texture[{index}] {width}x{height} {length / 1048576:.1f} MB"
              f" -> {picture.size[0]}x{picture.size[1]} {len(out.getvalue()) / 1048576:.2f} MB")

    if not replacements:
        print("  no embedded textures; nothing to do")
        return

    # Lay every bufferView out again in its original order, 4-byte aligned.
    rebuilt = bytearray()
    for view_index in sorted(range(len(doc["bufferViews"])),
                             key=lambda k: doc["bufferViews"][k].get("byteOffset", 0)):
        view = doc["bufferViews"][view_index]
        old_offset, old_length = view.get("byteOffset", 0), view["byteLength"]
        data = replacements.get(view_index) or bytes(blob[old_offset:old_offset + old_length])
        while len(rebuilt) % 4:
            rebuilt.append(0)
        view["byteOffset"] = len(rebuilt)
        view["byteLength"] = len(data)
        rebuilt.extend(data)

    doc["buffers"][0]["byteLength"] = len(rebuilt)
    doc["buffers"][0].pop("uri", None)
    after = write_glb(path, doc, rebuilt)
    print(f"  {before / 1048576:.1f} MB -> {after / 1048576:.1f} MB"
          f" ({100 * (before - after) / before:.0f}% smaller)")

    # Verify: it re-parses, every image decodes, the mesh is still there.
    doc2, blob2 = read_glb(path)
    for index, image in enumerate(doc2.get("images", [])):
        view = doc2["bufferViews"][image["bufferView"]]
        probe = Image.open(io.BytesIO(bytes(blob2[view["byteOffset"]:view["byteOffset"] + view["byteLength"]])))
        probe.load()
    triangles = sum(doc2["accessors"][p["indices"]]["count"] // 3
                    for m in doc2.get("meshes", []) for p in m["primitives"] if "indices" in p)
    print(f"  verified: {len(doc2.get('images', []))} textures decode, {triangles:,} triangles intact")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--max", type=int, default=2048)
    ap.add_argument("--quality", type=int, default=92)
    ap.add_argument("--backup", default="")
    args = ap.parse_args()
    for path in args.files:
        print(f"\n=== {os.path.basename(path)}")
        shrink(path, args.max, args.quality, args.backup)


if __name__ == "__main__":
    main()
