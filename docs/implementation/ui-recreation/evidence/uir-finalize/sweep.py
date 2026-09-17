#!/usr/bin/env python3
"""UIR finalize captain — serial UI audit sweep runner.

One Godot process at a time (refuses to start while `pgrep -x Godot` is non-empty),
per-run watchdog, and one machine-readable record per run: exact command, exit code,
PASS/x-y tally, ok/FAIL counts and the SCRIPT ERROR / Parse Error / engine ERROR count
(a PASS line next to a SCRIPT ERROR is a failure, so the count is recorded separately).

Usage: sweep.py <out_dir> [--only name1,name2,...]
"""
import json
import os
import re
import subprocess
import sys
import time
import hashlib

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
REPO = "/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
WATCHDOG = 300

# name -> argv (argv is the full engine invocation, minus $GODOT)
YES = True
RUNS = [
    # base suites (UIR-00 register)
    ("harness", ["--headless", "--path", "godot/"]),
    ("game_slice_test", ["--headless", "--path", "godot/", "--script", "res://tests/game_slice_test.gd"]),
    ("game_slice_test_demo", ["--headless", "--path", "godot/", "--script", "res://tests/game_slice_test.gd", "--", "--demo"]),
    ("input_run_all", ["--headless", "--path", "godot/", "--script", "res://tests/input/run_all.gd"]),
    ("audits_run_all", ["--headless", "--path", "godot/", "--script", "res://tests/audits/run_all.gd"]),
    ("modes_run_all", ["--headless", "--path", "godot/", "--script", "res://tests/modes/run_all.gd"]),
    ("save_steam_test", ["--headless", "--path", "godot/", "--script", "res://tests/save_steam_test.gd"]),
    ("music_port_test", ["--headless", "--path", "godot/", "--script", "res://tests/music_port_test.gd"]),
    # UI audits
    ("theme_probe", ["--headless", "--path", "godot/", "--script", "res://tests/ui/theme_probe.gd"]),
    ("router_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/router_audit.gd"]),
    ("data_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/data_audit.gd"]),
    ("fonts_assets_probe", ["--headless", "--path", "godot/", "--script", "res://tests/ui/fonts_assets_probe.gd"]),
    ("hud_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/hud_audit.gd"]),
    ("pause_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/pause_audit.gd"]),
    ("input_a11y_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/input_a11y_audit.gd"]),
    ("osk_touch_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/osk_touch_audit.gd"]),
    ("ui_legibility_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/ui_legibility_audit.gd"]),
    ("uir22_integration_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/uir22_integration_audit.gd"]),
    ("replay_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/replay_audit.gd"]),
    # UIR-23 closure (2026-09-17): the demo matrix in both builds; the recorded 32-run
    # manifest predates these two and is left as its own record.
    ("demo_matrix_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/demo_matrix_audit.gd"]),
    ("demo_matrix_audit_demo", ["--headless", "--path", "godot/", "--script", "res://tests/ui/demo_matrix_audit.gd", "--", "--demo"]),
    ("screen_menu_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_menu_audit.gd"]),
    ("screen_modes_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_modes_audit.gd"]),
    ("screen_characters_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_characters_audit.gd"]),
    ("screen_arena_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_arena_audit.gd"]),
    ("screen_drill_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_drill_audit.gd"]),
    ("screen_result_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_result_audit.gd"]),
    ("screen_settings_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_settings_audit.gd"]),
    ("screen_feedback_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_feedback_audit.gd"]),
    ("screen_help_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_help_audit.gd"]),
    ("screen_history_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_history_audit.gd"]),
    ("screen_challenges_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_challenges_audit.gd"]),
    ("screen_profile_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/screen_profile_audit.gd"]),
    ("uir_route_audit", ["--headless", "--path", "godot/", "--script", "res://tests/ui/uir_route_audit.gd"]),
]

SOURCE_TREES = ["godot/game", "godot/src", "godot/tests", "godot/project.godot",
                "godot/game/Main.tscn", "godot/game/Match.tscn", "godot/game/ModeScreen.tscn"]

TALLY = re.compile(r"^(PASS|FAIL) (\d+)/(\d+)\s*$", re.M)
OKLINE = re.compile(r"^ok ", re.M)
FAILLINE = re.compile(r"^FAIL", re.M)
ENGINE = re.compile(r"SCRIPT ERROR|Parse Error|^ERROR:", re.M)


def godot_running() -> bool:
    return subprocess.run(["pgrep", "-x", "Godot"], capture_output=True).returncode == 0


def source_hashes() -> dict:
    """sha256[:16] of every source file the sweep exercises, keyed by repo path."""
    out = {}
    for tree in SOURCE_TREES:
        path = os.path.join(REPO, tree)
        if os.path.isfile(path):
            files = [path]
        else:
            files = []
            for base, _dirs, names in os.walk(path):
                if "/.godot" in base:
                    continue
                for n in names:
                    if n.endswith(".uid") or n.endswith(".import"):
                        continue
                    files.append(os.path.join(base, n))
        for f in sorted(files):
            with open(f, "rb") as fh:
                out[os.path.relpath(f, REPO)] = hashlib.sha256(fh.read()).hexdigest()[:16]
    return out


def tree_digest(hashes: dict) -> str:
    h = hashlib.sha256()
    for k in sorted(hashes):
        h.update(("%s %s\n" % (k, hashes[k])).encode())
    return h.hexdigest()[:16]


def run_one(name: str, argv: list, out_dir: str) -> dict:
    log_path = os.path.join(out_dir, "runs", "%s.log" % name)
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    cmd = [GODOT] + argv
    started = time.time()
    with open(log_path, "w") as fh:
        proc = subprocess.Popen(cmd, cwd=REPO, stdout=fh, stderr=subprocess.STDOUT)
        try:
            code = proc.wait(timeout=WATCHDOG)
        except subprocess.TimeoutExpired:
            proc.terminate()
            try:
                code = proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
                code = "timeout-killed"
    text = open(log_path, errors="replace").read()
    tal = TALLY.findall(text)
    verdict = tal[-1] if tal else ("PASS" if name == "harness" and code == 0 else "")
    tally = "%s %s/%s" % verdict if verdict else ""
    engine_lines = [m.group(0) for m in ENGINE.finditer(text)]
    rec = {
        "name": name,
        "cmd": " ".join(cmd),
        "exit": code,
        "tally": tally,
        "pass_count": int(verdict[1]) if verdict else None,
        "total_count": int(verdict[2]) if verdict else None,
        "ok_lines": len(OKLINE.findall(text)),
        "fail_lines": len(FAILLINE.findall(text)),
        "script_errors": len(re.findall(r"SCRIPT ERROR", text)),
        "engine_error_lines": len(engine_lines),
        "seconds": round(time.time() - started, 1),
        "log": os.path.relpath(log_path, REPO),
    }
    if engine_lines:
        rec["engine_error_sample"] = engine_lines[:5]
    return rec


def main() -> int:
    out_dir = sys.argv[1]
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    os.makedirs(os.path.join(out_dir, "runs"), exist_ok=True)
    hashes_before = source_hashes()
    results = []
    for name, argv in RUNS:
        if only and name not in only:
            continue
        if godot_running():
            print("ABORT: another Godot is running (pgrep -x Godot)")
            return 2
        rec = run_one(name, argv, out_dir)
        results.append(rec)
        print("%-26s exit=%-4s %-12s script_errors=%s engine_lines=%s %ss"
              % (name, rec["exit"], rec["tally"], rec["script_errors"],
                 rec["engine_error_lines"], rec["seconds"]), flush=True)
    hashes_after = source_hashes()
    payload = {
        "lane": "uir-finalize-captain",
        "date": time.strftime("%Y-%m-%d %H:%M:%S"),
        "godot": GODOT,
        "repo": REPO,
        "only": sorted(only) if only else None,
        "engine_processes": "one at a time (pgrep -x Godot guard before every run)",
        "tree_digest_before": tree_digest(hashes_before),
        "tree_digest_after": tree_digest(hashes_after),
        "hash_stable": hashes_before == hashes_after,
        "sources": hashes_after,
        "runs": results,
    }
    path = os.path.join(out_dir, "ui-audit-sweep.json" if not only else "ui-audit-subset.json")
    with open(path, "w") as fh:
        json.dump(payload, fh, indent=2)
    print("wrote", path, "hash_stable=%s" % payload["hash_stable"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
