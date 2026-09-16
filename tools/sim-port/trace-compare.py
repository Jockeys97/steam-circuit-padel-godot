#!/usr/bin/env python3
"""trace-compare.py — compare the two engines' `# tr` / `# ev` diagnostic traces.

Usage:
  tools/sim-port/trace-compare.py <js-stream> <gd-stream>

Both `tools/sim-port/fault-digest.mjs` and `godot/src/sim/fault_digest_gd.gd` print,
next to the frozen digest lines, one `# tr` comment line per tick where a discrete
field of the simulated state moved, and one `# ev` line per change of the newest
in-game message. Those lines are ignored by `parity-compare.mjs`; this tool is what
reads them, so the fault tick and the second-serve tick can be compared at tick
resolution instead of only on the `--every` grid.

`# tr` lines are compared textually (they carry no engine-specific spelling).
`# ev` lines are NOT compared textually: the JavaScript reference stores localized
display text in `state.events` while the port stores message ids (state.gd:18), so
the wording differs by design. Only their TICK numbers are compared.

Exit 0 = the two traces agree, 1 = they do not, 2 = malformed input.
"""
import hashlib
import re
import sys

TR = re.compile(r"^# tr tick=(\d{6}) (.*)$")
EV = re.compile(r"^# ev tick=(\d{6}) events0=\"(.*)\"$")
DIGEST = re.compile(r"^tick=\d{6}")
# A3 / D2 diagnostics (tools/sim-port/fault-digest.mjs and fault_digest_gd.gd print
# these as comment lines; the text is engine-neutral, so they are compared textually).
FAMILY = re.compile(r"^# (strike|double-fault|set-closed) tick=(\d{6}) (.*)$")


def load(path):
    tr, ev, digest, serve_attempts, sha = {}, {}, [], {}, None
    families = {"strike": [], "double-fault": [], "set-closed": []}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            m = TR.match(line)
            if m:
                tr[int(m.group(1))] = m.group(2)
                continue
            m = EV.match(line)
            if m:
                ev[int(m.group(1))] = m.group(2)
                continue
            m = FAMILY.match(line)
            if m:
                families[m.group(1)].append((int(m.group(2)), m.group(3)))
                continue
            if DIGEST.match(line):
                digest.append(line)
                sa = re.search(r"serveAttempts=(\d+)", line)
                if sa:
                    serve_attempts[int(line.split()[0].split("=")[1])] = int(sa.group(1))
                continue
            if "digestSha256=" in line:
                sha = line.split("digestSha256=")[1].split()[0]
    body = hashlib.sha256(("\n".join(digest) + "\n").encode()).hexdigest()
    return {
        "tr": tr,
        "ev": ev,
        "digest_lines": len(digest),
        "body_sha256": body,
        "declared_sha256": sha,
        "serve_attempts": serve_attempts,
        "families": families,
    }


def transitions(serve_attempts):
    out, previous = [], None
    for tick in sorted(serve_attempts):
        value = serve_attempts[tick]
        if previous is not None and value != previous:
            out.append((tick, previous, value))
        previous = value
    return out


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    js, gd = load(argv[1]), load(argv[2])
    if not js["tr"] or not gd["tr"]:
        print("MALFORMED: one of the streams has no '# tr' lines")
        return 2

    print(f"TRACE-COMPARE js={argv[1]} gd={argv[2]}")
    print(f"# tr lines: js={len(js['tr'])} gd={len(gd['tr'])}")
    print(f"# ev lines: js={len(js['ev'])} gd={len(gd['ev'])}")
    print(f"digest lines: js={js['digest_lines']} gd={gd['digest_lines']}")
    print(f"digest sha256: js={js['body_sha256']} gd={gd['body_sha256']} same={js['body_sha256'] == gd['body_sha256']}")
    print(f"declared sha256: js={js['declared_sha256']} gd={gd['declared_sha256']}")

    ok = True
    for tick in sorted(set(js["tr"]) | set(gd["tr"])):
        a, b = js["tr"].get(tick), gd["tr"].get(tick)
        if a != b:
            ok = False
            print(f"TR-DIVERGENCE tick={tick:06d}\n  js: {a}\n  gd: {b}")
    if ok:
        print(f"TR identical on all {len(js['tr'])} transition ticks")

    ev_ticks_js = sorted(js["ev"])
    ev_ticks_gd = sorted(gd["ev"])
    if ev_ticks_js == ev_ticks_gd:
        print(f"EV tick numbers identical: {ev_ticks_js}")
        for tick in ev_ticks_js:
            print(f"  tick={tick:06d} js=\"{js['ev'][tick]}\" gd=\"{gd['ev'][tick]}\"")
    else:
        ok = False
        print(f"EV-DIVERGENCE ticks js={ev_ticks_js} gd={ev_ticks_gd}")

    for name, side in (("js", js), ("gd", gd)):
        print(f"serveAttempts transitions [{name}]: {transitions(side['serve_attempts'])}")

    # A3 / D2 diagnostics: strike charges, double-fault ticks, set-closure ticks.
    for family in ("strike", "double-fault", "set-closed"):
        a = js["families"][family]
        b = gd["families"][family]
        if a == b:
            print(f"{family.upper()} identical ({len(a)} line(s)): {a}")
        else:
            ok = False
            print(f"{family.upper()}-DIVERGENCE\n  js: {a}\n  gd: {b}")

    print("TRACE-COMPARE RESULT=" + ("IDENTICAL" if ok else "DIVERGED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
