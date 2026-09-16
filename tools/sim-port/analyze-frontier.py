#!/usr/bin/env python3
"""Read-only analyser for the parity digest streams (NEW file, allowlisted tree).

Parses tools/sim-port/out/js-*.txt (JS reference digest lines) and reports:
  * where the ball.z runaway starts (first tick with ball.z < -THRESH)
  * the preceding score transition (points / games / sets change)
  * serveAttempts non-zero occurrences anywhere in the file
  * ball.z extremes and the last "healthy" tick

Never writes to, or executes, anything under js/ or scripts/.
Usage: python3 tools/sim-port/analyze-frontier.py [--thresh=1000] [files...]
"""
import glob
import os
import re
import sys

NUM = r"-?\d+(?:\.\d+)?(?:e-?\d+)?"
LINE = re.compile(
    rf"^tick=(\d+)\s+rngState=(-?\d+)\s+rngCalls=(-?\d+)\s+"
    rf"ball=\(({NUM}),({NUM}),({NUM})\)\s+v=\(({NUM}),({NUM}),({NUM})\)\s+"
    rf"spin=({NUM})\s+bounces=(\d+)/(\d+)\s+shotType=(\S+)\s+smashStage=(\d+)\s+"
    rf"player=\(\S+\)\s+playerMate=\(\S+\)\s+opponent=\(\S+\)\s+opponentMate=\(\S+\)\s+"
    rf"points=(\S+)\s+games=(\S+)\s+sets=(\S+)\s+playerScore=(\S+)\s+aiScore=(\S+)\s+"
    rf"pointsWon=(\S+)\s+rallyHits=(\d+)\s+serveAttempts=(\d+)\s+longestRally=(\d+)"
)


def parse(path):
    rows = []
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            match = LINE.match(raw.strip())
            if not match:
                continue
            g = match.groups()
            rows.append({
                "tick": int(g[0]),
                "rngState": int(g[1]),
                "rngCalls": int(g[2]),
                "bx": float(g[3]), "by": float(g[4]), "bz": float(g[5]),
                "vx": float(g[6]), "vy": float(g[7]), "vz": float(g[8]),
                "spin": float(g[9]),
                "bp": int(g[10]), "ba": int(g[11]),
                "shotType": g[12], "smashStage": int(g[13]),
                "points": g[14], "games": g[15], "sets": g[16],
                "rallyHits": int(g[20]),
                "serveAttempts": int(g[21]),
            })
    return rows


def transitions(rows, key):
    out = []
    prev = None
    for row in rows:
        if prev is not None and row[key] != prev:
            out.append((row["tick"], prev, row[key], row))
        prev = row[key]
    return out


def report(path, thresh):
    rows = parse(path)
    if not rows:
        return {"file": os.path.basename(path), "lines": 0}
    name = os.path.basename(path)
    first_bad = next((r for r in rows if r["bz"] < -thresh), None)
    last_bad = next((r for r in reversed(rows) if r["bz"] < -thresh), None)
    # last tick before the runaway where bz >= 0 (still in the healthy regime)
    last_healthy = None
    if first_bad is not None:
        last_healthy = next((r for r in reversed(rows) if r["tick"] < first_bad["tick"] and r["bz"] >= -1), None)
    touch = [t for t in transitions(rows, "points")]
    sets_tr = transitions(rows, "sets")
    games_tr = transitions(rows, "games")
    return {
        "file": name,
        "lines": len(rows),
        "ticks": (rows[0]["tick"], rows[-1]["tick"]),
        "serveAttempts_values": sorted({r["serveAttempts"] for r in rows}),
        "bz_min": min(r["bz"] for r in rows),
        "bz_max": max(r["bz"] for r in rows),
        "runaway_first_tick": first_bad["tick"] if first_bad else None,
        "runaway_last_tick": last_bad["tick"] if last_bad else None,
        "last_healthy_tick": last_healthy["tick"] if last_healthy else None,
        "last_healthy_points": last_healthy["points"] if last_healthy else None,
        "last_healthy_games": last_healthy["games"] if last_healthy else None,
        "last_healthy_sets": last_healthy["sets"] if last_healthy else None,
        "points_transitions_before_runaway": [
            (t[0], t[1], t[2]) for t in touch if first_bad is None or t[0] <= first_bad["tick"]
        ][-3:],
        "games_transitions": [(t[0], t[1], t[2]) for t in games_tr][:8],
        "sets_transitions": [(t[0], t[1], t[2]) for t in sets_tr][:8],
    }


def main():
    args = sys.argv[1:]
    thresh = 1000.0
    files = []
    for arg in args:
        if arg.startswith("--thresh="):
            thresh = float(arg.split("=", 1)[1])
        else:
            files.append(arg)
    if not files:
        base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
        files = sorted(glob.glob(os.path.join(base, "*.txt")))
        files = [f for f in files if os.path.basename(f).startswith(("js-", "after-js-", "fine-", "before-js-"))]
    import json
    for path in files:
        print(json.dumps(report(path, thresh)))


if __name__ == "__main__":
    main()
