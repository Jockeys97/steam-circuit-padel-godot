#!/usr/bin/env python3
"""Derive the athlete/outfit catalogue from the frozen browser reference.

`js/data.js` is the single source of truth for who the six athletes are and which
outfits each of them owns. Nothing in this repository's Godot port is allowed to
retype those numbers by hand, so this script parses the reference and emits a
machine-readable catalogue that the engine loads at runtime:

    godot/assets/athletes/reference_catalogue.json

Two reference structures are read:

  ATHLETES[]        -> id, name, role, color, visual{skin,hair,headband,kit,
                       secondary,accent,kitStyle,shoes,frame,hairStyle,beard}
  ATHLETE_OUTFITS{} -> per athlete, an ordered list of {id, nameKey, colors[2],
                       challenge?, preview?, sprites?}

The parse is deliberately literal (regex over the reference's own one-field-per-line
formatting) rather than a JS evaluator: the failure mode of a regex miss is a loud
KeyError here, not a silently wrong colour in the game.

Usage:  python3 tools/character/extract_reference_catalogue.py [--check]
        --check re-derives and diffs against the committed JSON (exit 1 on drift).

Zero network, zero paid spend, no asset generation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REFERENCE = os.path.join(REPO, "js", "data.js")
OUT_JSON = os.path.join(REPO, "godot", "assets", "athletes", "reference_catalogue.json")

# The two texel families the single baked atlas actually exposes to a recolour.
# Measured by tools/character/recolour_outfits.py + outfits-strong.json, not chosen here:
# the Meshy rig ships ONE material and ONE baked baseColorTexture, and the only
# garment-shaped colour clusters in it are the navy body panels and the gold trim.
ANCHOR_PRIMARY = "#22304a"   # shorts / top / sneaker panels  <- outfit colors[0]
ANCHOR_TRIM = "#ffc94a"      # trim, wristbands, collar       <- outfit colors[1]

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


def read_reference() -> str:
    with open(REFERENCE, "r", encoding="utf-8") as fh:
        return fh.read()


def slice_block(text: str, start_marker: str, end_marker: str) -> str:
    i = text.index(start_marker)
    j = text.index(end_marker, i)
    return text[i:j]


def parse_visual(line: str) -> dict:
    """`visual: { frame: "athletic", skin: "#c98258", ..., beard: true }` -> dict."""
    body = line[line.index("{") + 1:line.rindex("}")]
    out = {}
    for key, value in re.findall(r'(\w+)\s*:\s*("(?:[^"]*)"|null|true|false)', body):
        if value == "null":
            out[key] = None
        elif value == "true":
            out[key] = True
        elif value == "false":
            out[key] = False
        else:
            out[key] = value.strip('"')
    return out


def parse_athletes(text: str) -> list:
    block = slice_block(text, "export const ATHLETES = [", "\nexport ")
    athletes = []
    current = None
    for raw in block.splitlines():
        line = raw.strip()
        m = re.match(r'^id:\s*"([^"]+)",$', line)
        if m:
            current = {"id": m.group(1)}
            athletes.append(current)
            continue
        if current is None:
            continue
        for field in ("name", "role", "color"):
            m = re.match(r'^%s:\s*"([^"]+)",$' % field, line)
            # First occurrence wins: `special: { name: "Colpo di Precisione" }` is a
            # nested block whose `name:` line looks identical once stripped, and taking
            # the last match silently renames every athlete after its special move.
            if m and field not in current:
                current[field] = m.group(1)
        if line.startswith("visual: {"):
            current["visual"] = parse_visual(line)
    return athletes


def parse_outfits(text: str) -> dict:
    block = slice_block(text, "export const ATHLETE_OUTFITS = {", "\nexport function outfitsForAthlete")
    out = {}
    athlete = None
    for raw in block.splitlines():
        line = raw.strip()
        m = re.match(r"^(\w+):\s*\[$", line)
        if m:
            athlete = m.group(1)
            out[athlete] = []
            continue
        if athlete is None or not line.startswith("{ id:"):
            continue
        oid = re.search(r'id:\s*"([^"]+)"', line).group(1)
        name_key = re.search(r'nameKey:\s*"([^"]+)"', line)
        colors = re.search(r'colors:\s*\[([^\]]*)\]', line)
        entry = {
            "id": oid,
            "unlock_key": "%s:%s" % (athlete, oid),
            "name_key": name_key.group(1) if name_key else "",
            "colors": [c.strip().strip('"') for c in colors.group(1).split(",")] if colors else [],
            "has_challenge": "challenge:" in line,
            "has_sprites": "sprites:" in line,
            "preview": (re.search(r'preview:\s*"([^"]+)"', line).group(1)
                        if "preview:" in line else ""),
        }
        out[athlete].append(entry)
    return out


def build() -> dict:
    text = read_reference()
    athletes = parse_athletes(text)
    outfits = parse_outfits(text)

    if len(athletes) != 6:
        raise SystemExit("expected 6 athletes in the reference, parsed %d" % len(athletes))
    for a in athletes:
        for field in ("id", "name", "role", "color", "visual"):
            if field not in a:
                raise SystemExit("athlete %r is missing %r" % (a.get("id"), field))
        if a["id"] not in outfits:
            raise SystemExit("athlete %r has no ATHLETE_OUTFITS entry" % a["id"])
    for athlete_id, entries in outfits.items():
        if not entries:
            raise SystemExit("athlete %r parsed with zero outfits" % athlete_id)
        for e in entries:
            if len(e["colors"]) != 2 or not all(HEX.match(c) for c in e["colors"]):
                raise SystemExit("outfit %s has unusable colors %r" % (e["unlock_key"], e["colors"]))

    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return {
        "_source": "js/data.js",
        "_source_sha256": digest,
        "_tool": "tools/character/extract_reference_catalogue.py",
        "_note": ("Derived, not hand-written. Re-run with --check to prove it still matches "
                  "the reference. Anchors map the reference's two-colour outfit definition "
                  "onto the two recolourable texel families of the single baked atlas."),
        "anchors": {"primary": ANCHOR_PRIMARY, "trim": ANCHOR_TRIM},
        "athletes": athletes,
        "outfits": outfits,
        "counts": {
            "athletes": len(athletes),
            "outfit_entries": sum(len(v) for v in outfits.values()),
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="re-derive and diff against the committed JSON instead of writing")
    args = ap.parse_args()

    data = build()
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

    if args.check:
        if not os.path.exists(OUT_JSON):
            print("DRIFT missing %s" % OUT_JSON)
            return 1
        with open(OUT_JSON, "r", encoding="utf-8") as fh:
            have = fh.read()
        if have != text:
            print("DRIFT %s differs from a fresh derivation of js/data.js" % OUT_JSON)
            return 1
        print("CATALOGUE_CHECK_OK athletes=%d outfit_entries=%d source_sha256=%s"
              % (data["counts"]["athletes"], data["counts"]["outfit_entries"],
                 data["_source_sha256"][:16]))
        return 0

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        fh.write(text)
    print("CATALOGUE_WRITTEN %s athletes=%d outfit_entries=%d"
          % (os.path.relpath(OUT_JSON, REPO), data["counts"]["athletes"],
             data["counts"]["outfit_entries"]))
    for athlete_id, entries in data["outfits"].items():
        print("  %-8s %d outfits: %s" % (athlete_id, len(entries),
                                         ", ".join(e["id"] for e in entries)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
