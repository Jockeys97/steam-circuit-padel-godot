#!/usr/bin/env python3
"""Assess the 28 UIR ticket statuses programmatically from ticket frontmatter and the board.

Read-only: parses tickets/*.md frontmatter + BOARD.md's ticket table, prints counts and
divergences. Output saved as evidence next to this script.
"""
import re
from collections import Counter
from pathlib import Path

UIR = Path("/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot/docs/implementation/ui-recreation")

front = {}
for f in sorted((UIR / "tickets").glob("UIR-*.md")):
    text = f.read_text()
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    meta = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^([a-z_]+):\s*(.*)$", line)
        if mm:
            meta[mm.group(1)] = mm.group(2).strip()
    front[meta.get("id", f.stem)] = {"state": meta.get("state"), "readiness": meta.get("readiness"),
                                     "gates": meta.get("gates"), "plan_approved": meta.get("plan_approved"),
                                     "file": f.name}

rows = {}
board = (UIR / "BOARD.md").read_text()
for line in board.splitlines():
    mm = re.match(r"^\| (UIR-\d\d) \|.*?\| (blocked-external|blocked|ready|in-progress|done) \|", line)
    if mm:
        rows[mm.group(1)] = mm.group(2)

print(f"tickets parsed from frontmatter: {len(front)}")
print(f"rows parsed from BOARD.md:      {len(rows)}")
print()
print(f"{'id':7} {'frontmatter':14} {'board':14} note")
diverge = []
for tid in sorted(front):
    fs, bs = front[tid]["state"], rows.get(tid, "?")
    note = ""
    if fs != bs:
        note = "DIVERGES (frontmatter not updated by the docs-correction pass)"
        diverge.append((tid, fs, bs))
    print(f"{tid:7} {fs:14} {bs:14} {note}")

print()
print("frontmatter counts:", dict(Counter(v["state"] for v in front.values())))
print("board-row counts:  ", dict(Counter(rows.values())))
print()
print("gates referenced:", dict(Counter(g.strip("[] ") for v in front.values() for g in v["gates"].split(","))))
pa = Counter(v["plan_approved"] for v in front.values())
print("plan_approved flags:", dict(pa))
print()
if diverge:
    print("divergences:")
    for tid, fs, bs in diverge:
        print(f"  {tid}: frontmatter={fs} board={bs}")
else:
    print("no divergences")
