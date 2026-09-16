"""pck-list.py — list what is inside a Godot 4 PCK.

Evidence tool for slice S12. What a preset claims to exclude has to be visible on
the artifact, not asserted in the preset file. This reads the pack directory
written by the exporter and prints the inventory.

Layout as found in Godot 4.7.2 `pack_version=4` (verified against these packs):

    header (112 bytes)
      u32 magic 'GDPC' | u32 pack_version | u32 major | u32 minor | u32 patch
      u32 pack_flags | u64 file_base | u64 directory_offset | reserved...
    directory, at the offset the header carries:
      u32 file_count, then per file: u32 path_len, path (padded to 4),
      u64 offset, u64 size, 16-byte md5, u32 flags
    file data, before the directory

    python3 tools/export/pck-list.py <pack> [inventory.txt]
"""

import struct
import sys

MAGIC = 0x43504447  # 'GDPC'


def header(data: bytes) -> dict:
    magic, pack_version, major, minor, patch, flags = struct.unpack_from("<IIIIII", data, 0)
    if magic != MAGIC:
        raise SystemExit(f"not a Godot pack: magic=0x{magic:x}")
    file_base = struct.unpack_from("<Q", data, 24)[0]
    dir_offset = struct.unpack_from("<Q", data, 32)[0]
    return {
        "pack_version": pack_version, "engine": f"{major}.{minor}.{patch}",
        "pack_flags": flags, "file_base": file_base, "directory_offset": dir_offset,
    }


def entries(data: bytes, offset: int) -> list:
    out = []
    count = struct.unpack_from("<I", data, offset)[0]
    off = offset + 4
    for _ in range(count):
        path_len = struct.unpack_from("<I", data, off)[0]
        off += 4
        raw = data[off:off + path_len]
        off += (path_len + 3) // 4 * 4
        path = raw.split(b"\0")[0].decode("utf-8", "replace")
        size, = struct.unpack_from("<Q", data, off + 8)
        off += 8 + 8 + 16 + 4
        out.append((path, size))
    return out


def main() -> None:
    path = sys.argv[1]
    data = open(path, "rb").read()
    info = header(data)
    items = sorted(entries(data, info["directory_offset"]))
    # The pack stores paths without the `res://` prefix; normalise so the inventory
    # reads like the project tree it came from.
    items = [(n if n.startswith("res://") else "res://" + n, s) for n, s in items]
    print(f"pack={path}  bytes={len(data)}")
    print(f"  magic=GDPC pack_version={info['pack_version']} engine={info['engine']} "
          f"file_base={info['file_base']} directory_offset={info['directory_offset']} entries={len(items)}")

    groups: dict = {}
    for name, size in items:
        parts = name.split("/")
        key = "/".join(parts[:3]) if len(parts) > 3 else name
        got = groups.setdefault(key, [0, 0])
        got[0] += 1
        got[1] += size
    for key, (n, total) in sorted(groups.items()):
        print(f"  {n:4d} files  {total:10d} bytes  {key}")

    for prefix in ("res://prototypes", "res://game", "res://tests", "res://src", "res://.godot"):
        hits = [n for n, _ in items if n.startswith(prefix)]
        print(f"  {prefix}: {len(hits)}")
        for h in hits[:4]:
            print(f"      {h}")

    if len(sys.argv) > 2:
        with open(sys.argv[2], "w") as fh:
            for name, size in items:
                fh.write(f"{name}\t{size}\n")
        print(f"  full inventory -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
