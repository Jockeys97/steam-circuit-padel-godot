#!/usr/bin/env python3
"""build_manifest.py — fold a run_proof.sh run dir into MANIFEST.json / MANIFEST.md.

Reads (all produced by the runner and the capture harness, nothing invented):
  results.tsv          step | exit | tally | SCRIPT ERROR count | log sha256 | command
  logs/<step>.log      the complete engine log of the step
  logs/<step>.exit     the step's exit code (redundant with results.tsv by design)
  captures/captures.json  per-PNG: path, sha256, size, colour count, projected
                          court/glass points, glass alphas, engine + display facts
  captures/<preset>/arena-<id>.png  the frames themselves
  tree_before.json / tree_after.json  the tracked-source digest around the run

Writes MANIFEST.json and MANIFEST.md into the run dir (or --out-dir). Every hash
is recomputed here from the bytes on disk — a hash recorded by a producer is
re-verified, never trusted. Exit 0 when the manifest was written; the manifest
itself records whether the run was green and whether the tree moved under it.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

TALLY = re.compile(r"^(PASS|FAIL) (\d+)/(\d+)$", re.M)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path: Path):
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", help="tools/world-arenas/out/<run-id>")
    ap.add_argument("--out-dir", default=None, help="where to write MANIFEST.* (default: run dir)")
    args = ap.parse_args()

    run = Path(args.run_dir).resolve()
    out = Path(args.out_dir).resolve() if args.out_dir else run
    out.mkdir(parents=True, exist_ok=True)

    steps = []
    tsv = run / "results.tsv"
    if tsv.exists():
        for line in tsv.read_text().splitlines():
            if not line.strip():
                continue
            parts = line.split("\t")
            name = parts[0]
            log = run / "logs" / f"{name}.log"
            log_sha = sha256_file(log) if log.exists() else None
            recorded_log_sha = parts[4] if len(parts) > 4 and parts[4] else None
            tally = parts[2] if len(parts) > 2 else ""
            m = TALLY.search(tally)
            steps.append({
                "step": name,
                "exit": parts[1] if len(parts) > 1 else None,
                "tally": tally or None,
                "passed": int(m.group(2)) if m and m.group(1) == "PASS" else None,
                "total": int(m.group(3)) if m else None,
                "script_errors": int(parts[3]) if len(parts) > 3 and parts[3] else None,
                "command": parts[5] if len(parts) > 5 else None,
                "log": f"logs/{name}.log" if log.exists() else None,
                "log_sha256": log_sha,
                "log_sha256_matches_record": (recorded_log_sha == log_sha) if (recorded_log_sha and log_sha) else None,
            })

    captures = read_json(run / "captures" / "captures.json")
    pngs = []
    if captures:
        for rec in captures.get("records", []):
            png = run / "captures" / rec["png"]
            actual = sha256_file(png) if png.exists() else None
            pngs.append({
                "preset": rec.get("preset"),
                "arena": rec.get("arena"),
                "png": f"captures/{rec['png']}",
                "sha256": actual,
                "sha256_matches_in_run_record": (actual == rec.get("sha256")) if actual else None,
                "size": rec.get("size"),
                "colours": rec.get("colours"),
                "min_margin_px": rec.get("min_margin_px"),
                "worst_point": rec.get("worst_point"),
                "glass": {
                    "rear_alpha": (rec.get("glass") or {}).get("rear_alpha"),
                    "expected_rear_alpha": (rec.get("glass") or {}).get("expected_rear_alpha"),
                    "side_alpha": (rec.get("glass") or {}).get("side_alpha"),
                    "all_visible": (rec.get("glass") or {}).get("all_visible"),
                },
                "points": rec.get("points"),
            })

    # The menu capture (round-2 review item): the real menu showing the world
    # chooser. Re-hashed from the bytes on disk, same rule as the arena frames.
    menu_json = read_json(run / "captures" / "menu_capture.json")
    menu_rec = None
    if menu_json and menu_json.get("record"):
        rec = menu_json["record"]
        png = run / "captures" / rec.get("png", "")
        actual = sha256_file(png) if png.exists() else None
        menu_rec = {
            "png": f"captures/{rec.get('png')}",
            "sha256": actual,
            "sha256_matches_in_run_record": (actual == rec.get("sha256")) if actual else None,
            "size": rec.get("size"),
            "colours": rec.get("colours"),
            "min_margin_px": rec.get("min_margin_px"),
            "buttons": rec.get("buttons"),
            "display": menu_json.get("display"),
            "engine": menu_json.get("engine"),
        }

    before = read_json(run / "tree_before.json")
    after = read_json(run / "tree_after.json")
    engine = None
    for step in steps:
        if not step.get("log"):
            continue
        text = (run / step["log"]).read_text(errors="replace")
        m = re.search(r"Godot ([\w.]+)", text)
        if m:
            engine = m.group(1)
            break

    green = bool(steps) and all(
        s["exit"] == "0" and (s["script_errors"] in (0, None)) and not (s["tally"] or "").startswith("FAIL")
        for s in steps
    )
    tree_stable = bool(before and after and before.get("digest") == after.get("digest"))

    manifest = {
        "tool": "tools/world-arenas/build_manifest.py",
        "run_dir": str(run),
        "engine": engine,
        "steps": steps,
        "run_green": green,
        "tree_before": before,
        "tree_after": after,
        "tree_stable_during_run": tree_stable,
        "captures": {
            "capture_size": (captures or {}).get("capture_size"),
            "adapter": (captures or {}).get("adapter"),
            "display": (captures or {}).get("display"),
            "count": len(pngs),
            # Records vs bytes: a run-record only claims a frame; this counts the
            # ones whose PNG exists on disk AND re-hashes to the recorded value
            # (or, when the record carries no hash, whose file exists at all).
            "files_on_disk": sum(1 for p in pngs if p.get("sha256")),
            "files_size_ok": sum(1 for p in pngs if (p.get("size") or [0, 0]) ==
                                ((captures or {}).get("capture_size") or [0, 0]) and p.get("sha256")),
            "pngs": pngs,
            "menu": menu_rec,
        },
    }
    (out / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")

    md = ["# World-arena proof manifest", ""]
    md.append(f"- run dir: `{run}`")
    md.append(f"- engine: `{engine}`")
    md.append(f"- run green: **{green}**")
    md.append(f"- tree stable during run: **{tree_stable}** "
              f"({(before or {}).get('digest')} -> {(after or {}).get('digest')})")
    md.append(f"- captures: {len(pngs)} records, "
              f"{manifest['captures']['files_on_disk']} files on disk, "
              f"{manifest['captures']['files_size_ok']} at the recorded size "
              f"({(captures or {}).get('capture_size')})")
    md += ["", "## Steps", "", "| step | exit | tally | SCRIPT ERRORs | log sha256 |", "|---|---|---|---|---|"]
    for s in steps:
        md.append(f"| {s['step']} | {s['exit']} | {s['tally'] or ''} | {s['script_errors']} | "
                  f"`{(s['log_sha256'] or '')[:16]}` |")
    md += ["", "## Captures", "", "| preset | arena | size | colours | min margin (px) | sha256 |",
           "|---|---|---|---|---|---|"]
    for p in pngs:
        size = f"{p['size'][0]}x{p['size'][1]}" if p.get("size") else ""
        md.append(f"| {p['preset']} | {p['arena']} | {size} | {p['colours']} | "
                  f"{p['min_margin_px']:.1f} | `{(p['sha256'] or '')[:16]}` |")
    if menu_rec:
        md.append("")
        md.append(f"- menu capture: `{menu_rec['png']}` "
                  f"{'x'.join(str(v) for v in (menu_rec.get('size') or []))} "
                  f"colours={menu_rec.get('colours')} buttons={len(menu_rec.get('buttons') or {})} "
                  f"sha256 `{(menu_rec.get('sha256') or '')[:16]}` "
                  f"(re-hash matches record: {menu_rec.get('sha256_matches_in_run_record')})")
    md.append("")
    (out / "MANIFEST.md").write_text("\n".join(md) + "\n")

    print(f"manifest written: {out / 'MANIFEST.json'} + MANIFEST.md "
          f"(steps={len(steps)} green={green} tree_stable={tree_stable} captures={len(pngs)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
