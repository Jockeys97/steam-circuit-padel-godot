# GATE-A — board report (menu + HUD approach verdict)

**Gate owner:** Luca (human). **State: OPEN — no verdict exists anywhere; this report prepares it.**
Prepared 2026-09-17 by the docs-only verification pass (`gate-a-review/`); read-only git, no engine,
$0. Updated the same day by the post-pull closeout pass: the queued post-merge 1280×720 HUD
re-capture landed (open item 1 below is closed; HEAD is now `3238a50`, the shipping-pack evidence
commit — no runtime code changed since `c9470e2`). The gate question lives in
`docs/wayfinder/tickets/ui-port-approach.md`: *can a Godot Control
tree carry this interface without losing readable type, semantic colour, no overflow* — and, if Luca
wants, what "3D flair" means beyond the live 3D court.

## What Luca will see

1. **The running build** (recorded launch command from `evidence/uir-09-prototype-mount.md`; mission
   seed/tier per `README.md` — **not run by this pass**):
   ```
   /Applications/Godot.app/Contents/MacOS/Godot --rendering-driver opengl3 --path godot \
     --resolution 1280x720 res://game/Main.tscn -- --ui=new --seed=20260916 --tier=3
   ```
   `--ui=new` mounts the recreated menu and (from a match) the recreated HUD beside the ported ones;
   both old and new constructions remain runnable. **Corrected 2026-09-17 (UIR-22 landed): the
   recreated UI is the DEFAULT and `--ui=legacy` is the opt-out** — the "`--ui=legacy` default"
   reading this report was written under is superseded (owner-approved; BOARD row GATE-A,
   `main_menu.gd:111`, `match_controller.gd:413`).
2. **The before/after pairs** (real captures only; every file hash-recorded):
   - `gate-a-review/sheets/menu-before-after-1280x720.png` — REFERENCE (web) | BEFORE (ported, UIR-00
     register) | AFTER (recreated MenuScreen, merged tip `c9470e2`, 1280×720).
   - `gate-a-review/sheets/hud-before-after-1280x720.png` — REFERENCE (web) | BEFORE (ported legacy
     HUD, register) | AFTER (recreated HUD over the merged 10×20 m court, **1280×720**, merged tip
     `3238a50`; the re-capture this pack's open item queued).
   - `gate-a-review/sheets/hud-before-after.png` — the same trio at 1152×648, retained as composed
     with its own hash record.
   - Raw panels in `gate-a-review/pairs/` (full hashes `pairs/SHA256SUMS.txt`; provenance
     `gate-a-review/PROVENANCE.md`; context `gate-a-review/REPORT.md`).

## Verified state behind the gate (what is settled)

- **Merge provenance (re-verified this pass):** `c6837b2` = `249d55a` (UI checkpoint) + `a1e10f04`
  (pinned branch tip); `a1e10f04` is an ancestor of `HEAD c9470e2`; court files at `HEAD` are
  byte-identical to `a1e10f04`; frozen pins re-hash to their recorded values
  (`REPORT.md` §1). Local only — **nothing pushed**.
- **Acceptance evidence (quoted, not re-run here):** pre-gate-a closeout 19-run sweep green,
  0 SCRIPT ERRORs; combined pull-wave sweep on the merged tree (`evidence/uir-pull-wave/`), the only
  red being the branch's own `padel.pck` export check (needs an exported pack on the gate host).
  `court_dimensions_test.gd` was run explicitly: `PASS court dimensions: 1111 checks, 0 failures`.
- **Prototype mounts were opt-in at GATE-A; corrected 2026-09-17 (UIR-22 landed):** the approved
  UIR-22 flip made the recreated UI the default — `--ui=legacy` keeps the legacy construction
  reachable (`match_controller.gd:413` `_ui_new = _arg(args, "--ui=", "new") != "legacy"`,
  `main_menu.gd:111`), and `project.godot` `run/main_scene` is unchanged (`3aef17de…`, still
  frozen; UIR-22's mount goes through `main_menu.gd`, not the main scene).

## What to judge (the brief)

- **Type readability, semantic colour, density, safe areas** across the menu and the in-match HUD at
  1280×720 and the narrow sizes (1024×600 proofs are in `evidence/uir-pre-gate-a-captures.log`).
- **3D court / HUD composition** over the now-correct **10×20 m court**: does the re-aimed camera and
  the HUD sit well together; does the port's answer to "3D flair" read the way Luca wants (per the
  wall the ticket itself sets).
- **Two riding owner decisions** the merge did not close: the **camera feel** (the commit says
  "measured, not judged") and the **court-aspect** question (mission STATE listed it as an open owner
  decision; resolved in code at the owner's request). Surface both while looking.

## Open items that affect the review (not blockers to looking)

1. ~~**No post-merge 1280×720 prototype-HUD capture exists.**~~ **Closed 2026-09-17** by the
   closeout pass: `pairs/hud-after-prototype-{serve,hud,rally}-1280x720.png` + sheet
   `sheets/hud-before-after-1280x720.png`, captured at the merged tip `3238a50` (transcript
   `evidence/uir-gate-a-hud-1280x720-capture.log`). The pre-merge 1280×720 prototype frame remains
   at `pairs/hud-prototype-premerge-1280x720.png` for the pre/post-merge shape.
2. **S14 frame-relative tuning was measured under the old camera** (`TIMING_FOOT_FORWARD` etc.) and
   must be re-measured before its frame numbers are trusted; the cues are visible and functional in
   the merged-tip frames, but their numbers are not inherited.
3. The working tree's legacy-name PNGs are the merge's stale renders; the fresh frames are the ones
   in this pack. (No silent substitution anywhere: see `PROVENANCE.md` cross-check 4.)

## Blockers behind this gate

Mass screens (UIR-10–UIR-21) and everything downstream stay blocked until the verdict; the
platform/touch decision (UIR-26) and `luca-final` are separate human gates, also open. If the verdict
rejects the approach, the pack re-scopes — it is not pushed through (wayfinder ticket).

## Budget and method

$0. No paid API calls, no engine process, no nested delegation, no commits/pushes; git read-only.

## Non-claims

No look/feel verdict is made or implied anywhere in this pack; the frame notes are identifications
and measurements, not taste. Ticket rows flipped by this pass are documented in `BOARD.md`
("Post-pull correction") and evidence-mapped in `gate-a-review/REPORT.md` §3; ticket frontmatter
updates remain the coordinator's.
