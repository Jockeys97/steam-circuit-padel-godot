#!/usr/bin/env python3
"""Finalize closure — BOARD.md update from the final sweep manifest (single writer pass)."""
import json
import os
import re

REPO = "/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot"
EV = os.path.join(REPO, "docs/implementation/ui-recreation/evidence/uir-finalize")
BOARD = os.path.join(REPO, "docs/implementation/ui-recreation/BOARD.md")

ROWS = {
    "UIR-10": ("screen_modes_audit", "`uir-10-screen-modes.log` + finalize closure `PASS 118/118`"),
    "UIR-11": ("screen_characters_audit", "`uir-11-screen-characters.log` + finalize closure `PASS 148/148`"),
    "UIR-12": ("screen_arena_audit", "`uir-12-screen-arena.log` + finalize closure `PASS 133/133`"),
    "UIR-13": ("screen_help_audit", "`uir-13-screen-help.log` + finalize closure `PASS 91/91`"),
    "UIR-14": ("screen_history_audit", "`uir-14-screen-history.log` + finalize closure `PASS 56/56`"),
    "UIR-15": ("screen_challenges_audit", "`uir-15-screen-challenges.log` + finalize closure `PASS 73/73`"),
    "UIR-16": ("screen_profile_audit", "`uir-16-screen-profile.log` + finalize closure `PASS 74/74`"),
    "UIR-17": ("screen_feedback_audit", "`uir-17-screen-feedback.log` + finalize closure `PASS 119/119`"),
    "UIR-18": ("screen_drill_audit", "`uir-18-screen-drill.log` + finalize closure `PASS 89/89`"),
    "UIR-19": ("screen_settings_audit", "`uir-19-screen-settings.log` + finalize closure `PASS 91/91`"),
    "UIR-20": ("pause_audit", "`uir-20-overlays.log` (hash rows re-computed to the closure state) + finalize closure `PASS 176/176`; the replay entry's flag split (`set_replay_available`) landed with UIR-27"),
    "UIR-21": ("screen_result_audit", "`uir-21-screen-result.log` + finalize closure `PASS 176/176`"),
    "UIR-22": ("uir22_integration_audit", "`uir-22-integration.log` + `uir-22-integration-journal.md` + finalize closure `PASS 71/71` + `uir_route_audit PASS 44/44` + slice `PASS 342/342` (demo `293/293`)"),
    "UIR-24": ("ui_legibility_audit", "`uir-24-capture.log` + `uir-24-legibility.log` + finalize closure `PASS 664/664` (the audit's background resolution corrected against the page base; the real opaque-fill defects fixed in the source)"),
    "UIR-26": ("osk_touch_audit", "`uir-26-osk-touch.md` (§11 closure; `OskPanel.gd`/audit fixes in `evidence/uir-finalize/runs-small-gates/`) + finalize closure `PASS 177/177`"),
    "UIR-27": ("replay_audit", "`uir-27-replay.log` (§12 closure: seam executed, pause flag split picked and wired) + finalize closure `PASS 166/166`"),
}

NOTE = """
## Finalize closure (2026-09-17, integration owner; local only, **nothing pushed**)

Every repair landed and the whole pack was re-run serially on the final tree, one Godot process at
a time (`pgrep -x Godot` guard before every run). Machine-readable record:
`evidence/uir-finalize/ui-audit-sweep.json` (per run: exact command, exit, tally, ok/FAIL counts,
`SCRIPT ERROR` count) + `evidence/uir-finalize/README.md` (the human table and the classified
engine lines) + `evidence/uir-finalize/playable-route.md`. All sources under `godot/game`,
`godot/src`, `godot/tests` and `project.godot` were hashed before and after: tree digest
`1256f5f1d7200437`, **stable**. Earlier sweeps are kept, not deleted:
`evidence/uir-finalize/superseded/` (sweep 1: 24 green / 8 red; sweep 2: 31 green / 1 red).

- Sweep: **32 runs**; **32 green** (exit 0, no `FAIL` line, 0 `SCRIPT ERROR`); **4,318 checks
  passed**; **0 `SCRIPT ERROR`** lines. The 11 engine `ERROR:` lines are classified in the README:
  4 named allowances (`godot/game/check_log.sh`: the arena unknown-id probe ×2, the engine shutdown
  report ×2), 4 deliberate refusal probes flanked by their `ok` checks (router `register` ×2, menu
  `register` ×1, profile `route_action` ×1) and 3 headless-clipboard lines (no display clipboard;
  the feedback screen's copy path). Nothing is unexplained.
- Repairs that closed the wave: the replay seam landed in `match_controller.gd` with the pause flag
  split (`set_replay_available`), so the card's RIGUARDA PUNTO is reachable and ESC's step 0 is
  never stale; the audits' own defects corrected with citations (node paths, counts, one impossible
  ball-triple inequality replaced with the array-identity proof); the small-gates fixes (`OskPanel`
  targets / field-id capture / eager build, help, challenges, history, profile, feedback) landed
  with their logs in `evidence/uir-finalize/runs-small-gates/`.
- The playable route is verified in-engine end to end — `menu → modes → characters → arena →
  drill → match → pause → result → rematch → settings` — by `godot/tests/ui/uir_route_audit.gd`
  (**PASS 44/44**) plus `uir22_integration_audit.gd` (**PASS 71/71**), both drawing on the real
  screens, the real bridge and a real played-out match; the slice is **PASS 342/342**, demo 293/293.
- Ticket truth, from frontmatter recomputed against this sweep: **26 `done`** — UIR-00..UIR-22,
  UIR-24, UIR-26, UIR-27; **1 `ready`** — UIR-23 (all its blockers landed; flipped from `blocked`);
  **1 `blocked`** — UIR-25 (closes on `luca-final`). No ticket is done off a partial green.
- Hash registers re-fingerprinted to the closure state: `evidence/uir-20-overlays.log`
  (`PauseOverlay.gd` 1546/57091/`b2d7d4dcfb1ea0d5`), `uir-26-osk-touch.md` §11, `uir-27-replay.log`
  §12 (closure fingerprints + the executed runs), `uir-22-integration-journal.md` (naming drift
  closed — the ticket's evidence now points at the real files).
- Stale opt-in text corrected: `board-gate-a.md`'s "default stays legacy" statements now read as
  superseded by UIR-22's approved default-NEW flip (`--ui=legacy` is the opt-out).
- Nothing committed, nothing pushed; the push stays the owner's decision.
"""

STANDINGS = """## Standings

- Tickets done: **26 of 28** (UIR-00–UIR-22, UIR-24, UIR-26, UIR-27) — recomputed programmatically
  from the ticket frontmatter against the finalize closure's engine record
  (`evidence/uir-finalize/ui-audit-sweep.json`) on 2026-09-17; a ticket is `done` only when the
  audit that is its arbiter exited 0 with no `FAIL` line and 0 `SCRIPT ERROR`.
- Ready: **1** — UIR-23 (demo/beta content matrix; all blockers landed, flipped from `blocked`).
- Blocked: **1** — UIR-25 (final regression + Luca acceptance; closes on `luca-final`).
- Gates: plan-approval — implementation approved by Luca's request (`CHARTER.md`; `LOG.md:4`); the
  pack README's flag is `approved: true`. **GATE-A passed-by-owner** 2026-09-17 (the owner's
  "All approved let's go finalize this, so I can play-test the game with the current devs", recorded
  in the finalize handoff) — the look/feel verdict itself is the owner's play-test and no agent
  certifies it. `product-scope-and-platforms`: the touch/OSK direction was approved in the same
  request; UIR-26 is `done` on its green audit, with the device pass recorded as owed
  (`not_ported`, §5/§11 of `uir-26-osk-touch.md`). `luca-final` OPEN.
- Nothing here self-certifies.
"""

SUMMARY = ("(**finalize closure** — every repair landed and the pack was re-run serially on the final tree, one engine "
           "process at a time: **32 runs, 32 green**, 4,318 checks, 0 `SCRIPT ERROR`, 11 classified engine lines; tree "
           "digest `1256f5f1d7200437`, stable; the playable route `menu→modes→characters→arena→drill→match→pause→result→"
           "rematch→settings` verified in-engine; tickets 26 done / 1 ready / 1 blocked; the replay seam + pause flag split "
           "closed; hash registers re-fingerprinted; `board-gate-a.md`'s stale opt-in text corrected to UIR-22's approved "
           "default-NEW; **nothing committed or pushed** — see the \"Finalize closure\" note below). Previous: ")

FRONTIER_OLD = ("Nothing is `ready` yet: every remaining ticket sits behind `gate-a` (`plan-approval` is recorded passed; "
                "see Standings). Once GATE-A has Luca's verdict, the post-gate waves become claimable; claims go through "
                "the coordinator. The waves follow the DAG exactly:")
FRONTIER_NEW = ("**Closure note (2026-09-17):** every wave below has landed and GATE-A passed (`passed-by-owner`); the one "
                "`ready` ticket is UIR-23 (all blockers landed, flipped from `blocked` in the finalize closure), and UIR-25 "
                "waits on it plus `luca-final`. Claims go through the coordinator. The waves followed the DAG exactly:")


def main() -> int:
    man = json.load(open(os.path.join(EV, "ui-audit-sweep.json")))
    runs = {r["name"]: r for r in man["runs"]}
    text = open(BOARD).read()

    # 1. header line
    lines = text.split("\n")
    assert lines[4].startswith("Last updated: 2026-09-17 ("), lines[4][:60]
    assert ": " in lines[4]
    old_body = lines[4][len("Last updated: "):]
    lines[4] = "Last updated: 2026-09-17 " + SUMMARY + old_body
    text = "\n".join(lines)

    # 2. frontier intro
    assert FRONTIER_OLD in text
    text = text.replace(FRONTIER_OLD, FRONTIER_NEW, 1)

    # 3. ticket rows
    green_ids, red_ids = [], []
    for tid, (suite, ev) in ROWS.items():
        r = runs[suite]
        ok = r["exit"] == 0 and r["fail_lines"] == 0 and r["script_errors"] == 0 and r["tally"].startswith("PASS")
        state = "done" if ok else "in-progress"
        (green_ids if ok else red_ids).append(tid)
        pat = re.compile(r"^\| %s \|.*$" % re.escape(tid), re.M)
        m = pat.search(text)
        assert m, tid
        cells = [c.strip() for c in m.group(0).strip("|").split("|")]
        cells[2] = state
        cells[7] = ev
        text = text[:m.start()] + "| " + " | ".join(cells) + " |" + text[m.end():]

    # 4. UIR-23 flip (all blockers landed)
    pat = re.compile(r"^\| UIR-23 \|.*$", re.M)
    m = pat.search(text)
    cells = [c.strip() for c in m.group(0).strip("|").split("|")]
    assert cells[2] == "blocked", cells[2]
    cells[2] = "ready"
    text = text[:m.start()] + "| " + " | ".join(cells) + " |" + text[m.end():]

    # 5. strip the old finalize-wave note, insert the closure note
    text = re.sub(r"\n## Finalize wave \(2026-09-17, integration captain.*?(?=\n## Claim protocol)",
                  "", text, flags=re.S)
    assert "\n## Claim protocol" in text
    text = text.replace("\n## Claim protocol", NOTE + "\n## Claim protocol", 1)

    # 6. standings replaced wholesale
    text = re.sub(r"\n## Standings\n.*$", "\n" + STANDINGS, text, flags=re.S)

    open(BOARD, "w").write(text)
    print("green:", green_ids)
    print("red:", red_ids)
    print("board bytes:", len(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
