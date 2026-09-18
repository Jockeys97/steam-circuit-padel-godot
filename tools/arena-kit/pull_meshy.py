#!/usr/bin/env python3
"""pull_meshy.py — pull a finished Meshy task (or a hand-dropped file) into its arena-kit
slot path, and record what was pulled.

WHY THIS EXISTS. Meshy retains a generated asset for only 3 days and its download URLs are
signed and time-limited (`expires_at`), so a finished task has to be pulled promptly, and
the pull has to be repeatable without guessing whether it already happened. Every pull is
sha256'd into `run/tmp/arena-kit/pull-log.jsonl`; the destination is written atomically
(temp file + rename) so a half-download can never look like a slot asset.

THE TWO MODES
  live          GETs `https://api.meshy.ai/openapi/v2/image-to-3d/<task-id>` with
                `Authorization: Bearer <key>` (key from `$MESHY_API_KEY` or
                `~/.config/meshy/api_key`), takes `model_urls.glb`, downloads it.
  --from-inbox  copies `meshy/inbox/<arena>/<slot>.glb` into place. Zero credentials: this
                is the path that works with no Meshy key at all, and the path the offline
                verification runs.

USAGE
  python3 tools/arena-kit/pull_meshy.py --arena torii --slot hero_landmark --task <id>
  python3 tools/arena-kit/pull_meshy.py --from-inbox --arena torii --slot hero_landmark
  python3 tools/arena-kit/pull_meshy.py --from-inbox --all
  python3 tools/arena-kit/pull_meshy.py --report          # log + integrity of what is in place
  python3 tools/arena-kit/pull_meshy.py --retire --arena torii --slot hero_landmark
  python3 tools/arena-kit/pull_meshy.py --slots           # the frozen slot set, read from arena_kit.gd

EXIT CODES  0 done (including "already in place") · 2 usage · 3 Meshy task not ready ·
            4 no key for the live path · 5 a source/target problem · 6 not a GLB

IDEMPOTENCE. With the destination present and its sha256 already logged for the same
source, the pull is a no-op ("skipped-identical"). A destination that differs from the log
is replaced and logged as "overwritten" (a re-generated model), so running the tool twice
never duplicates work and never silently keeps a stale file. `--force` re-pulls regardless.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import shutil
import sys
import urllib.error
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent                      # <repo>/tools/arena-kit -> <repo>
GODOT_ASSETS = ROOT / "godot" / "assets" / "arenas"
INBOX = ROOT / "meshy" / "inbox"
RUN_DIR = ROOT / "run" / "tmp" / "arena-kit"
LOG_PATH = RUN_DIR / "pull-log.jsonl"
KIT_TABLE = ROOT / "godot" / "game" / "arenas" / "arena_kit.gd"
API_BASE = "https://api.meshy.ai/openapi/v2/image-to-3d"
KEY_FILE = pathlib.Path.home() / ".config" / "meshy" / "api_key"
GLB_MAGIC = b"glTF"
# Only what falls back if `arena_kit.gd` cannot be read; the engine's table is authority.
FALLBACK_SLOTS = [
    "hero_landmark", "gate_portal", "light_source", "vegetation_cluster", "ground_dressing",
    "ornament_accent", "column_pillar", "railing_segment", "furniture", "signage_banner",
]
FALLBACK_ARENAS = ["torii", "medina", "carioca", "aurora", "egeo"]


# --------------------------------------------------------------------------- tables

def read_kit_tables() -> tuple[list[str], list[str]]:
    """The frozen slot set and arena list, read out of `arena_kit.gd` so this tool cannot
    drift from the engine. Falls back to the copy above (and says so) when the file or a
    pattern is missing."""
    text = KIT_TABLE.read_text(encoding="utf-8") if KIT_TABLE.exists() else ""
    slots = _array_after(text, "const SLOTS := [")
    arenas = _array_after(text, "const ARENAS := [")
    if not slots or not arenas:
        print("WARNING: could not read SLOTS/ARENAS from %s — using the built-in copy" % KIT_TABLE,
              file=sys.stderr)
        return list(FALLBACK_SLOTS), list(FALLBACK_ARENAS)
    return slots, arenas


def _array_after(text: str, marker: str) -> list[str]:
    start = text.find(marker)
    if start < 0:
        return []
    end = text.find("]", start)
    if end < 0:
        return []
    return re.findall(r'"([a-z0-9_]+)"', text[start:end])


def slot_glb(arena: str, slot: str) -> pathlib.Path:
    return GODOT_ASSETS / arena / ("%s.glb" % slot)


def inbox_glb(arena: str, slot: str) -> pathlib.Path:
    return INBOX / arena / ("%s.glb" % slot)


# --------------------------------------------------------------------------- log

def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def log(entry: dict) -> None:
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    entry = dict(entry)
    entry["ts"] = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, sort_keys=True) + "\n")


def read_log() -> list[dict]:
    if not LOG_PATH.exists():
        return []
    out = []
    for line in LOG_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out


def logged_for(arena: str, slot: str) -> dict | None:
    """The last entry that actually put a file in place for this slot."""
    hit = None
    for entry in read_log():
        if entry.get("arena") == arena and entry.get("slot") == slot \
                and entry.get("sha256") and entry.get("dst"):
            hit = entry
    return hit


# --------------------------------------------------------------------------- writes

def place(glb_bytes: bytes, dst: pathlib.Path, arena: str, slot: str, source: dict,
          mode: str, force: bool) -> int:
    """Write `glb_bytes` to `dst`, idempotently. Returns the process exit code."""
    if not glb_bytes.startswith(GLB_MAGIC):
        print("FAIL: the source for %s/%s is not a GLB (no 'glTF' magic)" % (arena, slot))
        log({"arena": arena, "slot": slot, "mode": mode, "status": "not-a-glb", **source})
        return 6
    digest = hashlib.sha256(glb_bytes).hexdigest()
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and not force:
        current = sha256_file(dst)
        if current == digest:
            print("ok %s/%s: already in place (sha256 %s…)" % (arena, slot, digest[:16]))
            log({"arena": arena, "slot": slot, "mode": mode, "status": "skipped-identical",
                 "sha256": digest, "bytes": len(glb_bytes), "dst": str(dst.relative_to(ROOT)),
                 **source})
            return 0
        previous = logged_for(arena, slot)
        print("note %s/%s: in place file differs (sha256 %s… -> %s…), replacing%s"
              % (arena, slot, current[:16], digest[:16],
                 "" if previous is None else " (was pulled as %s)" % (previous.get("status") or previous.get("mode"))))
        status = "overwritten"
    else:
        status = "pulled" if mode == "live" else "copied"

    tmp = dst.with_suffix(dst.suffix + ".part")
    tmp.write_bytes(glb_bytes)
    os.replace(tmp, dst)                        # atomic: no half file can be a slot asset
    written = sha256_file(dst)
    if written != digest:
        print("FAIL: %s does not read back with the sha256 it was written with" % dst)
        log({"arena": arena, "slot": slot, "mode": mode, "status": "readback-mismatch",
             "sha256": digest, "readback": written, "dst": str(dst.relative_to(ROOT)), **source})
        return 5
    print("ok %s/%s: %s -> %s (%d bytes, sha256 %s…)"
          % (arena, slot, status, dst.relative_to(ROOT), len(glb_bytes), digest[:16]))
    log({"arena": arena, "slot": slot, "mode": mode, "status": status, "sha256": digest,
         "bytes": len(glb_bytes), "dst": str(dst.relative_to(ROOT)), **source})
    return 0


# --------------------------------------------------------------------------- modes

def meshy_key() -> str:
    key = os.environ.get("MESHY_API_KEY", "").strip()
    if key:
        return key
    if KEY_FILE.exists():
        return KEY_FILE.read_text(encoding="utf-8").strip()
    return ""


def fetch_task(task_id: str, key: str) -> dict:
    request = urllib.request.Request(
        "%s/%s" % (API_BASE, task_id),
        headers={"Authorization": "Bearer %s" % key, "Accept": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def download(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=300) as response:
        return response.read()


def pull_live(arena: str, slot: str, task_id: str, force: bool) -> int:
    key = meshy_key()
    if not key:
        print("FAIL: no Meshy key. Looked at $MESHY_API_KEY and %s." % KEY_FILE)
        print("      Use the credential-free path instead: --from-inbox --arena %s --slot %s"
              % (arena, slot))
        return 4
    try:
        task = fetch_task(task_id, key)
    except urllib.error.HTTPError as exc:
        print("FAIL: Meshy HTTP %s for task %s (%s)" % (exc.code, task_id, exc.reason))
        log({"arena": arena, "slot": slot, "mode": "live", "task_id": task_id,
             "status": "http-error", "http_status": exc.code})
        return 5
    status = str(task.get("status", "")).upper()
    if status != "SUCCEEDED":
        print("FAIL: task %s is %s (progress=%s) — nothing to pull yet"
              % (task_id, status or "UNKNOWN", task.get("progress")))
        log({"arena": arena, "slot": slot, "mode": "live", "task_id": task_id,
             "status": "not-ready", "task_status": status})
        return 3
    urls = task.get("model_urls") or {}
    url = urls.get("glb") or ""
    if not url:
        print("FAIL: task %s has no glb in model_urls (%s)" % (task_id, sorted(urls.keys())))
        log({"arena": arena, "slot": slot, "mode": "live", "task_id": task_id,
             "status": "no-glb-url"})
        return 5
    print("note pulling task %s (%s), url expires %s" % (task_id, status, task.get("expires_at", "?")))
    try:
        blob = download(url)
    except urllib.error.HTTPError as exc:
        print("FAIL: download HTTP %s (%s) — Meshy's signed URL has probably expired; "
              "re-open the task in Meshy and use --from-inbox." % (exc.code, exc.reason))
        log({"arena": arena, "slot": slot, "mode": "live", "task_id": task_id,
             "status": "download-expired", "http_status": exc.code, "url": url})
        return 3
    return place(blob, slot_glb(arena, slot), arena, slot,
                 {"task_id": task_id, "url": url, "task_status": status}, "live", force)


def pull_inbox(arena: str, slot: str, force: bool) -> int:
    src = inbox_glb(arena, slot)
    if not src.exists():
        print("FAIL: no file at %s" % src.relative_to(ROOT))
        log({"arena": arena, "slot": slot, "mode": "inbox", "status": "missing",
             "src": str(src.relative_to(ROOT))})
        return 5
    blob = src.read_bytes()
    return place(blob, slot_glb(arena, slot), arena, slot,
                 {"src": str(src.relative_to(ROOT)), "src_sha256": hashlib.sha256(blob).hexdigest(),
                  "src_bytes": len(blob)}, "inbox", force)


# --------------------------------------------------------------------------- reports

def retire(arena: str, slot: str) -> int:
    """Take a slot's file out of the tree and log it. The way to unstage a bad model
    without hand-deleting files: the log stays the single record of what is in place."""
    dst = slot_glb(arena, slot)
    for leftover in (dst, dst.with_suffix(dst.suffix + ".part")):
        if leftover.exists():
            digest = sha256_file(leftover)
            leftover.unlink()
            print("ok %s/%s: retired %s (sha256 %s…)" % (arena, slot, leftover.relative_to(ROOT), digest[:16]))
            log({"arena": arena, "slot": slot, "mode": "retire", "status": "retired",
                 "sha256": digest, "dst": str(leftover.relative_to(ROOT))})
    if not dst.exists():
        print("ok %s/%s: nothing in place" % (arena, slot))
    return 0


def report() -> int:
    slots, arenas = read_kit_tables()
    entries = read_log()
    by_slot: dict[tuple[str, str], dict] = {}
    for entry in entries:
        if entry.get("sha256") and entry.get("dst"):
            by_slot[(entry["arena"], entry["slot"])] = entry
    print("pull-log: %s (%d entries)" % (LOG_PATH.relative_to(ROOT), len(entries)))
    print("%-9s %-20s %-12s %-10s %s" % ("arena", "slot", "state", "bytes", "sha256"))
    placed = 0
    problems = 0
    for arena in arenas:
        for slot in slots:
            entry = by_slot.get((arena, slot))
            dst = slot_glb(arena, slot)
            if entry is None or entry.get("status") == "retired":
                if dst.exists():
                    print("%-9s %-20s %-12s %-10s %s" % (arena, slot, "on-disk", dst.stat().st_size,
                                                         "NOT in the log"))
                    problems += 1
                continue
            placed += 1
            if not dst.exists():
                print("%-9s %-20s %-12s %-10s %s" % (arena, slot, "MISSING", "-",
                                                     "logged %s but the file is gone" % entry["sha256"][:16]))
                problems += 1
                continue
            actual = sha256_file(dst)
            state = "verified" if actual == entry["sha256"] else "CHANGED"
            if state == "CHANGED":
                problems += 1
            print("%-9s %-20s %-12s %-10d %s" % (arena, slot, state, dst.stat().st_size, actual[:16]))
    print("placed=%d problems=%d (of %d slots)" % (placed, problems, len(arenas) * len(slots)))
    return 1 if problems else 0


def main() -> int:
    slots, arenas = read_kit_tables()
    ap = argparse.ArgumentParser(description="Pull a finished Meshy task (or an inbox drop) into its arena-kit slot path.",
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--arena", choices=arenas)
    ap.add_argument("--slot", choices=slots)
    ap.add_argument("--task", help="Meshy task id (live mode)")
    ap.add_argument("--from-inbox", action="store_true",
                    help="copy meshy/inbox/<arena>/<slot>.glb into the slot path (no credentials)")
    ap.add_argument("--all", action="store_true", help="with --from-inbox: every inbox file that exists")
    ap.add_argument("--force", action="store_true", help="re-pull even when the file is already in place")
    ap.add_argument("--retire", action="store_true",
                    help="remove a slot's file and log it (unstage a bad model)")
    ap.add_argument("--report", action="store_true", help="print the log and verify what is in place")
    ap.add_argument("--slots", action="store_true", help="print the frozen slot set and exit")
    args = ap.parse_args()

    if args.slots:
        print("arenas: %s" % ", ".join(arenas))
        for slot in slots:
            print("  %s -> godot/assets/arenas/<arena>/%s.glb" % (slot, slot))
        return 0
    if args.report:
        return report()
    if args.retire:
        if not (args.arena and args.slot):
            ap.error("--retire needs --arena and --slot")
        return retire(args.arena, args.slot)

    if args.all and not args.from_inbox:
        ap.error("--all is only meaningful with --from-inbox")
    if args.from_inbox:
        targets: list[tuple[str, str]] = []
        if args.all:
            for arena in arenas:
                for slot in slots:
                    if inbox_glb(arena, slot).exists():
                        targets.append((arena, slot))
            if not targets:
                print("FAIL: nothing in %s" % INBOX.relative_to(ROOT))
                return 5
        elif args.arena and args.slot:
            targets = [(args.arena, args.slot)]
        else:
            ap.error("--from-inbox needs --arena and --slot (or --all)")
        worst = 0
        for arena, slot in targets:
            worst = max(worst, pull_inbox(arena, slot, args.force))
        return worst

    if args.arena and args.slot and args.task:
        return pull_live(args.arena, args.slot, args.task, args.force)
    ap.error("choose a mode: --arena/--slot with --task (live), or --from-inbox, or --report")
    return 2


if __name__ == "__main__":
    sys.exit(main())
