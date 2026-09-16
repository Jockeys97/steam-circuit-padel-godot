#!/usr/bin/env python3
"""Blank-frame guard for the slice captures. Pure standard library.

Reports, per PNG: bytes, sha256, pixel dimensions, distinct RGB values, per-channel
standard deviation, and the fraction of pixels that differ from the frame's most
common colour. A blank capture — what a `--headless` Godot run writes, because the
dummy rendering driver never draws — scores 1 distinct colour, std 0.0 and 0.0
differing pixels. Exit code is 1 if any frame is blank.

    python3 godot/game/tools/inspect_png.py godot/game/out/*.png

No numpy/PIL on this host, so the PNG is decoded here: 8-bit, non-interlaced,
colour type 2 (RGB) or 6 (RGBA), which is what `Image.save_png()` writes.
"""
import hashlib
import struct
import sys
import zlib


def read_png(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s is not a PNG" % path)
    pos = 8
    width = height = depth = colour = None
    idat = b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, depth, colour, comp, filt, interlace = struct.unpack(">IIBBBBB", payload)
            if depth != 8 or interlace != 0 or colour not in (2, 6):
                raise ValueError("unsupported PNG: depth=%d colour=%d interlace=%d" % (depth, colour, interlace))
        elif ctype == b"IDAT":
            idat += payload
        elif ctype == b"IEND":
            break
    channels = 3 if colour == 2 else 4
    raw = zlib.decompress(idat)
    stride = width * channels
    out = bytearray(height * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if ftype == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up = prev[i]
                upleft = prev[i - channels] if i >= channels else 0
                p = left + up - upleft
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - upleft)
                pred = left if (pa <= pb and pa <= pc) else (up if pb <= pc else upleft)
                line[i] = (line[i] + pred) & 0xFF
        elif ftype != 0:
            raise ValueError("bad filter %d at row %d" % (ftype, y))
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return data, width, height, channels, bytes(out)


def stats(width, height, channels, pixels):
    counts = {}
    sums = [0, 0, 0]
    sumsq = [0, 0, 0]
    n = width * height
    for i in range(0, len(pixels), channels):
        r, g, b = pixels[i], pixels[i + 1], pixels[i + 2]
        key = (r, g, b)
        counts[key] = counts.get(key, 0) + 1
        sums[0] += r
        sums[1] += g
        sums[2] += b
        sumsq[0] += r * r
        sumsq[1] += g * g
        sumsq[2] += b * b
    var = 0.0
    for c in range(3):
        mean = sums[c] / n
        var += max(0.0, sumsq[c] / n - mean * mean)
    std = (var / 3.0) ** 0.5
    modal = max(counts.values())
    return len(counts), std, 1.0 - modal / float(n)


def region_stats(width, height, channels, pixels, x, y, w, h):
    """Mean/min/max RGB of a rectangle. Used to measure a named screen region —
    the rear-wall band, say — before and after a visual fix."""
    sums = [0, 0, 0]
    lo = [255, 255, 255]
    hi = [0, 0, 0]
    n = 0
    for row in range(y, min(y + h, height)):
        base = row * width * channels
        for col in range(x, min(x + w, width)):
            i = base + col * channels
            for c in range(3):
                v = pixels[i + c]
                sums[c] += v
                lo[c] = min(lo[c], v)
                hi[c] = max(hi[c], v)
            n += 1
    if n == 0:
        return None
    return [sums[c] / float(n) for c in range(3)], lo, hi, n


def row_profile(width, height, channels, pixels, x0, x1, y0, y1):
    """Per-row mean RGB of a column range: the vertical layering of a band.

    A single rectangle mean hides structure — it cannot tell a lit glass wall with a
    rail from a dark void that happens to average the same. One line per screen row
    shows the layers instead, which is what makes a "does this read as a back wall"
    claim checkable.
    """
    out = []
    for y in range(max(0, y0), min(height, y1)):
        got = region_stats(width, height, channels, pixels, x0, y, max(1, x1 - x0), 1)
        if got is not None:
            out.append((y, got[0], got[1], got[2]))
    return out


def parse_region(text):
    parts = text.split(",")
    if len(parts) != 4:
        raise ValueError("--region needs x,y,w,h (got %r)" % text)
    return tuple(int(p) for p in parts)


def main(paths, regions, profiles):
    rc = 0
    for path in paths:
        try:
            data, width, height, channels, pixels = read_png(path)
            distinct, std, different = stats(width, height, channels, pixels)
        except Exception as exc:  # noqa: BLE001 - report and fail
            print("%s ERROR %s" % (path, exc))
            rc |= 1
            continue
        blank = distinct <= 1 or std == 0.0
        rc |= 1 if blank else 0
        print(
            "%s bytes=%d sha256=%s size=%dx%d channels=%d distinct_rgb=%d std=%.2f "
            "pixels_different_from_modal=%.4f blank=%s"
            % (path, len(data), hashlib.sha256(data).hexdigest(), width, height, channels,
               distinct, std, different, "YES" if blank else "no")
        )
        for name, rect, x0, x1 in profiles:
            print("  profile %s columns %d..%d" % (name, x0, x1))
            for y, mean, lo, hi in row_profile(width, height, channels, pixels, x0, x1, rect[1], rect[1] + rect[3]):
                print("    row %3d mean=(%3.0f,%3.0f,%3.0f) min=(%3d,%3d,%3d) max=(%3d,%3d,%3d)"
                      % (y, mean[0], mean[1], mean[2], lo[0], lo[1], lo[2], hi[0], hi[1], hi[2]))
        for name, rect in regions:
            got = region_stats(width, height, channels, pixels, *rect)
            if got is None:
                print("  region %s %s EMPTY" % (name, rect))
                rc |= 1
                continue
            mean, lo, hi, n = got
            print(
                "  region %s rect=%s pixels=%d mean_rgb=(%.1f, %.1f, %.1f) min=(%d, %d, %d) max=(%d, %d, %d)"
                % (name, rect, n, mean[0], mean[1], mean[2], lo[0], lo[1], lo[2], hi[0], hi[1], hi[2])
            )
    return rc


if __name__ == "__main__":
    args = sys.argv[1:]
    region_args = []
    profile_args = []
    files = []
    for a in args:
        if a.startswith("--region="):
            region_args.append(a[len("--region="):])
        elif a.startswith("--rows="):
            profile_args.append(a[len("--rows="):])
        else:
            files.append(a)
    parsed = []
    for spec in region_args:
        label, _, rect_text = spec.partition("@")
        parsed.append((label or rect_text, parse_region(rect_text or label)))
    rows = []
    for spec in profile_args:
        # --rows=name@x0,x1,y0,h : one line per screen row, mean RGB across that column
        # range — the vertical layering of a band, which a single rectangle mean hides.
        label, _, rect_text = spec.partition("@")
        x0, x1, y0, h = parse_region(rect_text)
        rows.append((label or rect_text, (0, y0, 1, h), x0, x1))
    if not files:
        print(__doc__)
        print("Optional: --region=name@x,y,w,h (repeatable) reports the mean/min/max RGB of that rect.")
        print("Optional: --rows=name@x0,x1,y0,h (repeatable) prints per-row mean RGB for that column range.")
        sys.exit(2)
    sys.exit(main(files, parsed, rows))
