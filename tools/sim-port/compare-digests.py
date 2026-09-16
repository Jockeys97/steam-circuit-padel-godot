#!/usr/bin/env python3
"""compare-digests.py — line-by-line comparison of two parity digest streams.

Usage:
  tools/sim-port/compare-digests.py <js.txt> <gd.txt>

Prints one summary line and, when the streams differ, the first differing tick
with the full JS and Godot field maps for that tick. Exit 0 = identical over the
common ticks, 1 = diverged, 2 = malformed input (no tick lines).

Deliberately a separate tool from `parity-digest-gd.sh`'s own comparison: that
one checks a stored JSON reference, this one compares two live streams.
"""
import sys


def load(path):
    ticks = {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line.startswith("tick="):
                continue
            parts = line.split()
            tick = int(parts[0].split("=")[1])
            fields = {}
            for kv in parts[1:]:
                if "=" in kv:
                    k, v = kv.split("=", 1)
                    fields[k] = v
            ticks[tick] = fields
    return ticks


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    js = load(argv[1])
    gd = load(argv[2])
    if not js or not gd:
        print("MALFORMED: one of the streams has no tick lines")
        return 2
    common = sorted(set(js) & set(gd))
    if not common:
        print(f"NOCOMMON js_ticks={len(js)} gd_ticks={len(gd)}")
        return 2
    first = None
    differing = 0
    for tick in common:
        a, b = js[tick], gd[tick]
        keys = set(a) | set(b)
        diff = [k for k in sorted(keys) if a.get(k) != b.get(k)]
        if diff:
            differing += 1
            if first is None:
                first = (tick, diff)
    if first is None:
        print(
            f"IDENTICAL common_ticks={len(common)} js_ticks={len(js)} gd_ticks={len(gd)}"
        )
        return 0
    tick, diff = first
    print(
        f"DIVERGED firstTick={tick:06d} fields={','.join(diff)} "
        f"differing_ticks={differing}/{len(common)}"
    )
    print(f"  JS {tick:06d} " + " ".join(f"{k}={js[tick].get(k)}" for k in sorted(js[tick])))
    print(f"  GD {tick:06d} " + " ".join(f"{k}={gd[tick].get(k)}" for k in sorted(gd[tick])))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
