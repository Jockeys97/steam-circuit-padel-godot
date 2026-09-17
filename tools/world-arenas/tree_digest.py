#!/usr/bin/env python3
"""tree_digest.py — a deterministic digest of the tracked engine sources.

Hashes the CONTENTS of every tracked file under godot/game, godot/src,
godot/tests and godot/project.godot (via `git ls-files`, so the untracked run
output under tools/world-arenas/out/ is invisible to it), the same four paths the
UIR sweep fingerprints. Emits JSON on stdout:

    {"head": "<sha>", "files": N, "digest": "<sha256[:16]>", "dirty": [paths]}

`run_proof.sh` calls this before and after its steps: the manifest is only honest
if the digest is identical in both. A concurrent production writer (arena
integrator) will change it, and that must be visible, never smoothed over.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

PATHS = ["godot/game", "godot/src", "godot/tests", "godot/project.godot"]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    out = subprocess.run(
        ["git", "ls-files", "--", *PATHS],
        cwd=root, capture_output=True, text=True, check=True,
    )
    files = [p for p in out.stdout.splitlines() if p.strip()]
    digest = hashlib.sha256()
    for rel in sorted(files):
        digest.update(rel.encode())
        try:
            digest.update((root / rel).read_bytes())
        except OSError:
            digest.update(b"<missing>")
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True, check=True,
    ).stdout.strip()
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=root, capture_output=True, text=True, check=True,
    ).stdout
    dirty = [ln for ln in status.splitlines() if ln.strip()]
    json.dump(
        {"head": head, "files": len(files), "digest": digest.hexdigest()[:16], "dirty": dirty},
        sys.stdout, indent=2,
    )
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
