#!/usr/bin/env python3
"""timing-compare.py — the timing-field comparison, field by field.

Usage:
  tools/sim-port/timing-compare.py <js-stream> <gd-stream>

Both `tools/sim-port/timing-trace.mjs` (JavaScript engine) and
`godot/tests/timing_feedback_test.gd -- --trace=<file>` (ported engine) print, next
to the frozen digest lines, a comment family this tool is the only reader of:

  `# tm tick=NNNNNN charge=.. active=.. eta=.. perfectWindow=.. advice=.. profile=..
   overlap=.. fbGrade=.. fbQuality=.. fbProfile=.. fbMode=.. shotType=.. queuedCharge=..
   queuedPower=.. x3ai=.. x3player=..`
        one line per tick: the timing model's numbers, which the frozen digest does
        not carry (it samples ball, paddles and score);
  `# con name=<constant> value=..`
        the timing constants read from each engine's OWN balance table, so a
        constant that drifted apart shows up in the same diff;
  `# cov ...`
        the scenario's own coverage counters, compared textually: two streams that
        agree on every field but exercised different branches would be a hollow pass.

The digest lines themselves are read with `tools/sim-port/trace-compare.py`'s own
loader (imported, not re-implemented), so this tool reports the same body sha256 for
the digest shape the frozen harness uses.

The `# tm` and `# con` lines are compared field by field, not textually, so a single
divergence is reported with its tick and its two values instead of one giant line
diff. `# tm` floats are compared as printed: six decimals, the reference's own
precision (`Digest.fixed` / `toFixed(6)`).

Exit 0 = every timing field, every constant, every coverage line and the digest body
agree; 1 = something does not; 2 = malformed input.

Nothing here widens a tolerance: the comparison is exact string equality per field,
which is what "the same numbers at the reference's printed precision" means.
"""
import hashlib
import importlib.util
import os
import re
import sys

TM = re.compile(r"^# tm tick=(\d{6}) (.*)$")
CON = re.compile(r"^# con name=(\S+) value=(\S+)$")
COV = re.compile(r"^# cov (.*)$")
DECLARED_TIMING = re.compile(r"^# timingSha256=([0-9a-f]{64})$")
SUMMARY = re.compile(r"^TIMING-TRACE (JS|GD) (PASS|FAIL) (.*)$")
FIELD = re.compile(r"([A-Za-z0-9_]+)=(\S*)")

# The fields the two streams must agree on, in the order the line prints them.
FIELDS = [
    "charge", "active", "eta", "perfectWindow", "advice", "profile", "overlap", "serving",
    "fbGrade", "fbQuality", "fbProfile", "fbMode", "shotType",
    "queuedCharge", "queuedPower", "x3ai", "x3player",
]

HERE = os.path.dirname(os.path.abspath(__file__))


def load_trace_compare():
    """`trace-compare.py` is hyphenated, so it is loaded by path."""
    path = os.path.join(HERE, "trace-compare.py")
    spec = importlib.util.spec_from_file_location("trace_compare", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load(path):
    ticks, constants, coverage, declared, summary = {}, {}, [], None, None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            match = TM.match(line)
            if match:
                fields = dict(FIELD.findall(match.group(2)))
                ticks[int(match.group(1))] = fields
                continue
            match = CON.match(line)
            if match:
                constants[match.group(1)] = match.group(2)
                continue
            match = COV.match(line)
            if match:
                coverage.append(match.group(1))
                continue
            match = DECLARED_TIMING.match(line)
            if match:
                declared = match.group(1)
                continue
            match = SUMMARY.match(line)
            if match:
                summary = {"side": match.group(1), "verdict": match.group(2), "body": match.group(3)}
    body = hashlib.sha256(("\n".join(
        "# tm tick=%06d %s" % (tick, " ".join("%s=%s" % (key, ticks[tick][key]) for key in FIELDS if key in ticks[tick]))
        for tick in sorted(ticks)
    ) + "\n").encode()).hexdigest()
    return {
        "ticks": ticks,
        "constants": constants,
        "coverage": coverage,
        "declared_timing_sha256": declared,
        "recomputed_timing_sha256": body,
        "summary": summary,
    }


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    js, gd = load(argv[1]), load(argv[2])
    if not js["ticks"] or not gd["ticks"]:
        print("MALFORMED: one of the streams has no '# tm' lines")
        return 2

    print(f"TIMING-COMPARE js={argv[1]} gd={argv[2]}")
    print(f"# tm lines: js={len(js['ticks'])} gd={len(gd['ticks'])}")
    print(f"# con lines: js={len(js['constants'])} gd={len(gd['constants'])}")
    print(f"# cov lines: js={len(js['coverage'])} gd={len(gd['coverage'])}")
    for name, side in (("js", js), ("gd", gd)):
        summary = side["summary"]
        print(f"engine summary [{name}]: {'none' if summary is None else summary['side'] + ' ' + summary['verdict']}")

    ok = True

    # ------------------------------------------------------------------ constants
    names = sorted(set(js["constants"]) | set(gd["constants"]))
    differing = [name for name in names if js["constants"].get(name) != gd["constants"].get(name)]
    print(f"\n-- constants ({len(names)} compared) --")
    for name in names:
        mark = "ok " if name not in differing else "DIFF"
        print(f"  {mark} {name}: js={js['constants'].get(name)} gd={gd['constants'].get(name)}")
    if differing:
        ok = False
        print(f"CONSTANT-DIVERGENCE: {len(differing)} of {len(names)}: {', '.join(differing)}")
    else:
        print(f"constants identical: {len(names)}/{len(names)}")

    # --------------------------------------------------------------------- fields
    ticks = sorted(set(js["ticks"]) | set(gd["ticks"]))
    missing = [tick for tick in ticks if tick not in js["ticks"] or tick not in gd["ticks"]]
    if missing:
        ok = False
        print(f"\nTICK-DIVERGENCE: {len(missing)} tick(s) present in only one stream: {missing[:20]}")

    compared = [tick for tick in ticks if tick in js["ticks"] and tick in gd["ticks"]]
    per_field = {field: {"agree": 0, "differ": 0, "none_js": 0, "none_gd": 0} for field in FIELDS}
    first_divergences = []
    for tick in compared:
        a, b = js["ticks"][tick], gd["ticks"][tick]
        for field in FIELDS:
            left, right = a.get(field), b.get(field)
            if left == "none":
                per_field[field]["none_js"] += 1
            if right == "none":
                per_field[field]["none_gd"] += 1
            if left == right:
                per_field[field]["agree"] += 1
            else:
                per_field[field]["differ"] += 1
                if len(first_divergences) < 10:
                    first_divergences.append((tick, field, left, right))

    print(f"\n-- fields over {len(compared)} shared ticks --")
    total_differ = 0
    for field in FIELDS:
        stat = per_field[field]
        total_differ += stat["differ"]
        flag = "ok " if stat["differ"] == 0 else "DIFF"
        if field in ("fbGrade", "fbQuality", "fbProfile", "fbMode", "shotType"):
            note = f" (set on {stat['agree'] + stat['differ'] - stat['none_js']} ticks js / {stat['agree'] + stat['differ'] - stat['none_gd']} ticks gd)"
        else:
            note = ""
        print(f"  {flag} {field}: agree={stat['agree']} differ={stat['differ']}{note}")
    if total_differ:
        ok = False
        print(f"FIELD-DIVERGENCE: {total_differ} field mismatch(es) over {len(FIELDS)} fields")
        for tick, field, left, right in first_divergences:
            print(f"  tick={tick:06d} {field}: js={left} gd={right}")
    else:
        print(f"all {len(FIELDS)} fields identical on all {len(compared)} ticks")

    # ------------------------------------------------------------ coverage lines
    print("\n-- coverage --")
    if js["coverage"] == gd["coverage"]:
        for line in js["coverage"]:
            print(f"  ok # cov {line}")
        if not js["coverage"]:
            print("  (no counter line in either stream)")
    else:
        ok = False
        for line in js["coverage"]:
            if line not in gd["coverage"]:
                print(f"  js only: # cov {line}")
        for line in gd["coverage"]:
            if line not in js["coverage"]:
                print(f"  gd only: # cov {line}")
        print("COVERAGE-DIVERGENCE")

    # ------------------------------------------------------------------- digests
    print("\n-- digests (via tools/sim-port/trace-compare.py's loader) --")
    trace_compare = load_trace_compare()
    digest_js, digest_gd = trace_compare.load(argv[1]), trace_compare.load(argv[2])
    print(f"  digest lines: js={digest_js['digest_lines']} gd={digest_gd['digest_lines']}")
    print(f"  digest body sha256: js={digest_js['body_sha256']} gd={digest_gd['body_sha256']} same={digest_js['body_sha256'] == digest_gd['body_sha256']}")
    print(f"  declared digest sha256: js={digest_js['declared_sha256']} gd={digest_gd['declared_sha256']}")
    if digest_js["body_sha256"] != digest_gd["body_sha256"]:
        ok = False
        print("DIGEST-DIVERGENCE")
    print(f"  # tr lines: js={len(digest_js['tr'])} gd={len(digest_gd['tr'])}")
    tr_ticks = sorted(set(digest_js["tr"]) | set(digest_gd["tr"]))
    tr_differ = [tick for tick in tr_ticks if digest_js["tr"].get(tick) != digest_gd["tr"].get(tick)]
    if tr_differ:
        ok = False
        print(f"TR-DIVERGENCE on {len(tr_differ)} of {len(tr_ticks)} ticks: {tr_differ[:10]}")
    else:
        print(f"  # tr identical on all {len(tr_ticks)} transition ticks")

    # --------------------------------------------------- declared timing hashes
    print("\n-- declared timing hashes --")
    for name, side in (("js", js), ("gd", gd)):
        print(f"  {name}: declared={side['declared_timing_sha256']} recomputed={side['recomputed_timing_sha256']} "
              f"match={side['declared_timing_sha256'] == side['recomputed_timing_sha256']}")
        if side["declared_timing_sha256"] != side["recomputed_timing_sha256"]:
            ok = False
    if js["recomputed_timing_sha256"] != gd["recomputed_timing_sha256"]:
        # The two streams build the field order themselves; the digest above already
        # covers the values, so this is only a spelling check. It still has to pass.
        ok = False
        print("TIMING-HASH-DIVERGENCE (the two streams do not spell the same field order)")

    print("\nTIMING-COMPARE RESULT=" + ("IDENTICAL" if ok else "DIVERGED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
