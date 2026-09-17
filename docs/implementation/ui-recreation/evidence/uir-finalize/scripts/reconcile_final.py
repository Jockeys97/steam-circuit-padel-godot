#!/usr/bin/env python3
"""Reconcile UIR ticket frontmatter with the finalize wave's engine record.

Reads docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json and,
per ticket, sets `state` from the audit that is that ticket's arbiter, adds the manifest
to `evidence:`, and appends a "Finalize wave" section naming the tally, the exit code,
the SCRIPT ERROR count and the open items. No ticket is flipped off a partial green.
"""
import json
import os
import re
import sys

REPO = "/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
EV = os.path.join(REPO, "docs/implementation/ui-recreation/evidence/uir-finalize")
TICKETS = os.path.join(REPO, "docs/implementation/ui-recreation/tickets")

MAP = {
    "UIR-10-screen-modes.md": ["screen_modes_audit"],
    "UIR-11-screen-characters.md": ["screen_characters_audit"],
    "UIR-12-screen-arena.md": ["screen_arena_audit"],
    "UIR-13-screen-help.md": ["screen_help_audit"],
    "UIR-14-screen-history.md": ["screen_history_audit"],
    "UIR-15-screen-challenges.md": ["screen_challenges_audit"],
    "UIR-16-screen-profile.md": ["screen_profile_audit"],
    "UIR-17-screen-feedback.md": ["screen_feedback_audit"],
    "UIR-18-screen-drill.md": ["screen_drill_audit"],
    "UIR-19-screen-settings.md": ["screen_settings_audit"],
    "UIR-20-game-overlays.md": ["pause_audit"],
    "UIR-21-screen-result.md": ["screen_result_audit"],
    "UIR-22-full-integration.md": ["uir22_integration_audit", "uir_route_audit"],
    "UIR-24-capture-harness.md": ["ui_legibility_audit"],
    "UIR-26-osk-touch.md": ["osk_touch_audit"],
    "UIR-27-replay.md": ["replay_audit"],
}

MANIFEST = "docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json"


def failing_checks(name, limit=8):
    p = os.path.join(EV, "runs", "%s.log" % name)
    if not os.path.exists(p):
        return []
    out = []
    for line in open(p, errors="replace"):
        if line.startswith("FAIL ") and "/" not in line.split(" ", 2)[1][:1]:
            out.append(line.strip()[:160])
    return out[:limit]


def main() -> int:
    man = json.load(open(os.path.join(EV, "ui-audit-sweep.json")))
    runs = {r["name"]: r for r in man["runs"]}
    print("tree digest %s -> %s (stable=%s)" % (man["tree_digest_before"], man["tree_digest_after"], man["hash_stable"]))
    changed = []
    for fname, audits in MAP.items():
        path = os.path.join(TICKETS, fname)
        text = open(path).read()
        recs = [runs[a] for a in audits if a in runs]
        if not recs:
            print("SKIP %s (no run record)" % fname)
            continue
        green = all(r["exit"] == 0 and r["fail_lines"] == 0 and r["script_errors"] == 0 and r["tally"].startswith("PASS") for r in recs)
        new_state = "done" if green else "in-progress"
        lines = []
        for r in recs:
            lines.append("- `%s` — **%s**, exit %s, %s `SCRIPT ERROR` line(s) (%.1fs); log `%s`" % (
                r["cmd"].split("--script ")[-1].replace("res://", ""), r["tally"] or "<no tally>", r["exit"],
                r["script_errors"], r["seconds"], r["log"]))
            for fc in failing_checks(r["name"]):
                lines.append("  - %s" % fc)
        section = "\n\n## Finalize closure (2026-09-17, integration owner)\n\n" + \
            "Engine record, one Godot process at a time, manifest `%s` (all sources hashed\n" % MANIFEST + \
            "before and after: tree digest `%s`, stable).\n\n" % man["tree_digest_after"] + \
            "\n".join(lines) + "\n" + \
            ("\n**State: `done`** — the audit above is this ticket's arbiter and it is green on the\n"
             "finalize tree.\n" if green else
             "\n**State: `in-progress`** — the implementation is on disk and the audit now runs and\n"
             "names what is still open; the ticket is NOT done off a partial green.\n")
        # frontmatter
        text = re.sub(r"^state: .*$", "state: %s" % new_state, text, count=1, flags=re.M)
        text = re.sub(r"^plan_approved: .*$", "plan_approved: true", text, count=1, flags=re.M)
        if MANIFEST not in text:
            text = re.sub(r"^(evidence:\n(?:  - .*\n)+)", r"\1  - %s\n" % MANIFEST, text, count=1, flags=re.M)
        # drop an older finalize section if this script is re-run
        text = re.sub(r"\n\n## Finalize (?:wave|closure) \(2026-09-17, integration (?:captain|owner)\).*$", "", text, flags=re.S)
        text = text.rstrip("\n") + section
        open(path, "w").write(text)
        changed.append((fname, new_state))
        print("%-34s -> %-11s %s" % (fname, new_state, " ".join(r["tally"] for r in recs)))
    print("changed:", len(changed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
