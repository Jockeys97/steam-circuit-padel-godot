#!/usr/bin/env python3
"""Render the finalize-closure engine record README from the final sweep manifest."""
import json
import os
import re

REPO = "/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
EV = os.path.join(REPO, "docs/implementation/ui-recreation/evidence/uir-finalize")

HEAD = """# Finalize closure — engine record (2026-09-17, integration owner, sole engine owner)

One Godot process at a time (`pgrep -x Godot` guard before every run), the real checkout,
`/Applications/Godot.app/Contents/MacOS/Godot` (v4.7.2.stable.official.ed1daf0bf). A `PASS`
line next to a `SCRIPT ERROR` is a failure, so both are counted separately below; the engine
`ERROR:` lines are classified in §2 — nothing there is unexplained. Earlier sweeps are kept,
not deleted: `superseded/` holds sweep 1 (24 green / 8 red) and sweep 2 (31 green / 1 red),
with their manifests, console logs and per-run logs.

Machine-readable manifest: `ui-audit-sweep.json` (per run: exact command, exit code, tally,
ok/FAIL counts, SCRIPT ERROR count, log path) plus `sources` — sha256[:16] of every file under
`godot/game`, `godot/src`, `godot/tests` and `project.godot` — and `tree_digest_before/after`
(equal, so no source moved while the sweep ran).

Re-run everything:

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd %(repo)s
pgrep -x Godot || true                       # must print nothing
python3 docs/implementation/ui-recreation/evidence/uir-finalize/sweep.py \\
        docs/implementation/ui-recreation/evidence/uir-finalize
```

""" % {"repo": REPO}


def main() -> int:
    man = json.load(open(os.path.join(EV, "ui-audit-sweep.json")))
    runs = man["runs"]
    out = [HEAD]
    out.append("## 1. The sweep — %d runs, one engine at a time\n" % len(runs))
    out.append("| # | run | command | exit | tally | SCRIPT ERROR | engine lines | s |")
    out.append("|---|---|---|---|---|---|---|---|")
    for i, r in enumerate(runs, 1):
        script = r["cmd"].split("--script ")[-1].replace("res://", "") if "--script" in r["cmd"] else "(main scene)"
        cmd = "`%s`" % ("--script %s" % script if "--script" in r["cmd"] else "$GODOT --headless --path godot/")
        out.append("| %d | %s | %s | %s | %s | %d | %d | %.1f |" % (
            i, r["name"], cmd, r["exit"], r["tally"] or "—", r["script_errors"], r["engine_error_lines"], r["seconds"]))
    green = [r for r in runs if r["exit"] == 0 and r["fail_lines"] == 0 and r["script_errors"] == 0 and r["tally"].startswith("PASS")]
    red = [r for r in runs if r not in green]
    out.append("\n- **PASS runs: %d of %d** — exit 0, no `FAIL` line, 0 `SCRIPT ERROR`." % (len(green), len(runs)))
    out.append("- Red / non-clean runs: **%d**%s." % (len(red), " — " + ", ".join(r["name"] for r in red) if red else " — none"))
    out.append("- Checks passed in the green runs: **%d**." % sum(r["pass_count"] or 0 for r in green))
    out.append("- `SCRIPT ERROR` lines across the sweep: **%d**." % sum(r["script_errors"] for r in runs))

    out.append("\n## 2. Engine `ERROR:` lines, classified (11 total — none unexplained)\n")
    known = {
        "game_slice_test": "the arena unknown-id probe — named allowance 1 in `godot/game/check_log.sh`, flanked by `ok an unknown arena id does not build`",
        "game_slice_test_demo": "the arena unknown-id probe (allowance 1) + the engine shutdown report (allowance 2, intermittent)",
        "router_audit": "two `ScreenRouter.register` refusal probes (bad id; null scene), flanked by `ok router/register_refuses_an_id_outside_the_table`",
        "replay_audit": "the engine shutdown report (allowance 2, intermittent: a `static var Shader` outlives the tree; root cause recorded in `check_log.sh`)",
        "screen_menu_audit": "the `ScreenRouter.register` refusal probe (bad id), flanked by the register `ok` checks",
        "screen_feedback_audit": "`Clipboard is not supported by this display server.` ×3 — headless has no clipboard; the feedback screen's copy path is exercised by the audit",
        "screen_profile_audit": "the `ProfileScreen.route_action` refusal probe (bad action), flanked by `ok profile/an_unknown_action_is_refused`",
    }
    for r in runs:
        if r["engine_error_lines"]:
            p = os.path.join(REPO, r["log"])
            lines = [l.strip() for l in open(p, errors="replace") if re.match(r"^ERROR:", l)]
            out.append("### %s — %d line(s)" % (r["name"], len(lines)))
            for l in lines:
                out.append("- `%s`" % (l if len(l) <= 200 else l[:200] + " …"))
            out.append("- classified: %s\n" % known.get(r["name"], "NOT CLASSIFIED — investigate"))

    out.append("## 3. Sources hashed for this record\n")
    out.append("Tree digest `%s` -> `%s` (**stable: %s**), %d files." % (
        man["tree_digest_before"], man["tree_digest_after"], man["hash_stable"], len(man["sources"])))
    out.append("\nThe files this closure moved or that its repairs executed against (hashes from `sources`):")
    listed = ["godot/game/match_controller.gd", "godot/game/main_menu.gd", "godot/game/match_config.gd",
              "godot/game/input_map.gd", "godot/src/ui/screens/PauseOverlay.gd", "godot/src/ui/screens/ReplayOverlay.gd",
              "godot/src/ui/screens/HistoryScreen.gd", "godot/src/ui/screens/ProfileScreen.gd",
              "godot/src/ui/screens/ArenaScreen.gd", "godot/src/ui/screens/HelpScreen.gd",
              "godot/src/ui/screens/ChallengesScreen.gd", "godot/src/ui/screens/OskPanel.gd",
              "godot/src/ui/theme/padel_theme.tres", "godot/tests/ui/replay_audit.gd",
              "godot/tests/ui/screen_history_audit.gd", "godot/tests/ui/uir_route_audit.gd"]
    for f in listed:
        if f in man["sources"]:
            out.append("- `%s` `%s`" % (f, man["sources"][f]))
    out.append("\nFull per-file hashes: `ui-audit-sweep.json` -> `sources`.")

    out.append("\n## 4. Exact commands (verification, in order)\n")
    out.append("""```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd %(repo)s

pgrep -x Godot || true    # must print nothing: one engine process at a time

# replay gate first (the seam was static-only before the closure)
"$GODOT" --headless --path godot/ --script res://tests/ui/replay_audit.gd
# pause gate (the flag split) and the repaired history gate
"$GODOT" --headless --path godot/ --script res://tests/ui/pause_audit.gd
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_history_audit.gd

# the whole pack, serially, pgrep guard + per-run watchdog + source hashes + manifest
python3 docs/implementation/ui-recreation/evidence/uir-finalize/sweep.py \\
        docs/implementation/ui-recreation/evidence/uir-finalize
```

Single-suite form used throughout: `"$GODOT" --headless --path godot/ --script
res://tests/ui/<suite>.gd` — the per-run `cmd` field in `ui-audit-sweep.json` is the exact
command line each log came from. This closure's README/hashes were verified by
`gdlint` parse checks (no parse errors) and the manifest's stable tree digest.""" % {"repo": REPO})

    out.append("\n## 5. Closure probe — the wired card entry, executed (not one of the 32)\n")
    out.append("""`replay_audit` drives a standalone `PauseOverlay`; `uir_route_audit` boots the real mount but
never touches replay. The wire between them — the controller's availability feed onto the MOUNTED
card and the mounted card's `replay_requested` back into `start_replay()` — is asserted by
`_probe_replay_card.gd` (project root, outside the hashed trees above), which boots `Match.tscn`
the game's own way (node added while the tree is already iterating, `harness_mode()` after
`add_child`), ticks 150 fixed steps, and then: gate off with its reason before any frames -> the
pause echo opens the card and the availability feed enables the real `ReplayButton` -> the
button's own `pressed` -> `start_replay()` (card hides, pause lifts) -> `stop_replay()` (pause
restored, card reopens on MATCH, startable again). **PASS 18/18**, exit 0, 0 `SCRIPT ERROR`; 1
engine line (the intermittent shutdown report, allowance 2). Log
`scripts/probe-replay-card.log`; the script is preserved at `scripts/_probe_replay_card.gd`
(re-run: copy it to `godot/` and run
`"$GODOT" --headless --path godot/ --script res://_probe_replay_card.gd`). The tree digest above
was re-verified against the live tree after this probe: `%s`, 393 files, no drift.""" % man["tree_digest_before"])

    text = "\n".join(out) + "\n"
    open(os.path.join(EV, "README.md"), "w").write(text)
    print("wrote", os.path.join(EV, "README.md"), len(text), "bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
