# MERGE-CHECKLIST — integrating `codex/gameplay-and-map` (durable)

Use top to bottom at integration time. Every step assumes **one writer at a time** and **one engine
at a time** (`/tmp/padel-godot.lock.d`; on macOS there is no `flock`; stale guards recovered by the
coordinator only). Nothing here authorizes a commit/push without the user's explicit consent — the
checkpoint for a stopped session is the reviewed diff + snapshots (`manifests/`, `before-set/`).

> **EXECUTED 2026-09-17 (~02:14–02:28 CEST):** steps 0–4 and 6 ran; the merge is `c6837b2` (parents
> `249d55a` + `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590`), reconciled at `c9470e2`; step 6's
> combined sweep (19 runs) is in `../evidence/uir-pull-wave/`. Steps 5, 7 and 8 remain open/partial —
> annotations inline (updated at the 2026-09-17 closeout). The original step text is kept as written; executed steps carry
> `→ Executed:` result lines. Post-pull verification and GATE-A handoff: `../gate-a-review/REPORT.md`.

- [x] **0. Preconditions.** UI lane's wave committed or handed off (its dirty
  `godot/game/match_controller.gd` aborts any pull otherwise). All other writers stopped on the
  paths about to change. `pgrep -f Godot` empty. User go-ahead for the pull obtained.
  → **Executed:** the UI wave landed at `249d55a` (246 files); the pull wave's engine runs were done
  on an isolated copy (`/tmp/padel-uir-pull-20260917/repo`), one engine at a time.
- [x] **1. Re-pin the branch (do not trust this review's SHA blindly).**
  - `gh pr list --repo Jockeys97/steam-circuit-padel-godot --state all` → expect `[]` (still no PR; the
    `/pull/new/` URL is not a PR).
  - `git ls-remote https://github.com/Jockeys97/steam-circuit-padel-godot.git 'refs/heads/*'` → expect
    `main` = `252ff60…` and branch = `2752d9a2…` **or a successor**. The branch already moved once
    mid-review (`61f3ee71` → `2752d9a2`) — if it moved again, `git diff old_sha..new_sha` in a
    read-only clone and re-review the delta **before** merging; record the new pinned SHA here:
    `pinned: a1e10f04f9896de6ebbaff3e29f6d2c0dba77590`.
  - `git merge-base --is-ancestor origin/main origin/codex/gameplay-and-map` (in a scratch clone or
    after fetch) → true ⇒ ff-able.
  → **Executed:** the branch tip had moved once more (`2752d9a2` → **`a1e10f04`**, the court commit
  `a1e10f0`); no PR existed (per the review). Remote re-checked 2026-09-17 ~02:35 (read-only
  `ls-remote`): branch still `a1e10f04`, `main` still `252ff60…`. Integrated as a merge, **not**
  ff-only — the UI checkpoint had diverged by one commit.
- [x] **2. Re-probe the merge — the shared `match_controller.gd` reconciliation.** It is the **only**
  path the branch shares with the dirty tree. On frozen pre-pull versions (not the old samples):
  `git merge-file -p --diff3 local.gd base.gd branch.gd`, record exit code and `<<<<<<<` count.
  The 2026-09-17 sample probe was 0 conflicts / exit 0 (`manifests/merged2-match_controller.gd` is
  that output — a sample, **not** a final merge). Write order for this file stays serialized:
  **UIR-09 mount → S14c branch → UIR-22**; hand over via commit, never via a shared dirty tree.
  → **Executed:** the merge produced a `match_controller.gd` byte-identical to the probe sample —
  `a0f56fec1a99e0b0eb837ae9bd076847381a798215ee1a6d7527b1071e3229ca`, 90,953 B (re-verified at
  `HEAD` by the post-pull pass). Merge message: non-destructive, no force/reset/stash/rebase,
  0 conflicts.
- [x] **3. Protect the screenshots (highest silent-loss risk).** Baseline copies already exist:
  `integration-prep/before-set/` (20 files, byte-identical to the UIR-00 register — 20/20 at prep).
  - Before pull: `shasum -a 256 before-set/*.png` and compare against `PROVENANCE.md`; if any file
    was altered since prep, it is **not** baseline — say so, re-register, never silently substitute.
  - The pull replaces `godot/game/out/{menu,hud,rally,quickmatch-serve,result,arena-*}.png` with the
    branch's regenerated captures **without any conflict** — that is expected; the baseline lives in
    `before-set/` from then on. Add the dated pointer note to `evidence/uir-00-before-set.md`
    (coordinator's file, not the puller's).
  - Never regenerate the other lane's capture namespace: `ui-*`/`ui-prototype-*` = UI lane;
    legacy names + `probe-*`/`timing*`/`hud-off` = mission/S14.
  → **Executed:** `before-set/` intact — register sha256 re-verified at the closeout (all MATCH);
  the two files used by the GATE-A pairs re-verified by the post-pull pass. The merge replaced the
  legacy names as expected (stale renders by the branch's own note); the fresh merged-tip frames
  live in the pull copy and durably in `../gate-a-review/pairs/` (incl. the merged-tip 1280×720
  HUD frames). **Closed 2026-09-17:** the dated note is in `evidence/uir-00-before-set.md`.
- [x] **4. Preserve local state, then pull.**
  - Freeze: `git status --porcelain`, `git diff > active-unstaged-FINAL.patch`,
    `shasum -a 256 godot/game/main_menu.gd godot/game/match_controller.gd`; compare with
    `PROVENANCE.md` §D. Integrator still editing ⇒ stop and wait.
  - `git fetch origin` → `git merge --ff-only <pinned SHA>`. If the tree refuses (dirty touched
    file), that is the guardrail working — commit/hand off first, do not force.
  → **Executed:** freeze snapshots are in `manifests/` (`active-unstaged-FINAL.patch`, t1/t2 status);
  the integration landed as a non-destructive merge to `c6837b2` (the UI checkpoint was committed
  first at `249d55a`, so no dirty-tree refusal), then reconciled at `c9470e2`. The checkout was
  clean vs `c6837b2` at the review's sample.
- [ ] **5. Reconcile the legacy HUD timing cues into the new HUD (agreed durable task).**
  - The branch lands timing presentation in two places: `godot/game/hud.gd` (+~96, S14c) and
    `match_controller.gd` (`_timing_marks`, ring/advice/precision/energy/verdict, `_sync_timing`,
    `_timing_muted`). The recreated HUD (`godot/src/ui/Hud.gd`, mounted additively under `--ui=new`)
    is fed the same state+meta via `_refresh_ui()` but does not yet carry these cues.
  - **Do not retire the ported `_hud`/`_mode_hud` pair until the recreated HUD carries the timing
    presentation** (UIR-22 owns the retire/dedupe). Port/mirror the timing cues first, verify by
    capture + audit, then remove the legacy pair in its own step.
  - Line anchors shift after `hud.gd:91` (`:62`, `:75` stable); re-locate UIR-22's cited anchors and
    `game_slice_test.gd` traces (`:542-571`, `:1796-1811` → post-merge lines) in this same wave.
  → **Partial at 2026-09-17:** the merged tree runs the branch's timing cues (visible in the
  merged-tip frames); under `--ui=new` the legacy pair is hidden and the recreated HUD already
  carries its own TIMING bar/window (closeout). **Still open for UIR-22:** mirror the remaining S14
  cues into the recreated HUD before retiring the legacy pair; re-locate the anchors; the S14
  frame-relative numbers were measured under the old camera — re-measure, do not inherit
  (`../gate-a-review/REPORT.md` §5).
- [x] **6. Rerun the combined tests — serially, in this order** (all counts below were *claims*;
  the gate passes only when re-measured by someone other than the author, matching or explaining
  every delta; engine pinned `/Applications/Godot.app/Contents/MacOS/Godot` 4.7.2 `ed1daf0bf`):
  1. `--import` (sidecars only) · 2. harness main scene (8/8) · 3. `game_slice_test.gd` (record
  actual; `padel.pck` absence may differ) · 4. input runner — expect **5/5** (was 4/4; settle
  392 vs 393 checks) · 5. rules audits (10/10) · 6. modes/save/music (6/6 · 137/137 · 32/32) ·
  7. new S14 parity gates — `shot_logic_parity_test.gd`, `timing_feedback_test.gd`, and
  `--inject-failure` **must FAIL** (a gate that cannot fail is not a gate) · 8. `switch_mode_audit`
  + re-assert `ui_accept`/`ui_cancel` block hashes (`7158cdcc…`, `ec73fe28…`) · 9. UI audits —
  re-run, do not inherit (`ui_legibility_audit` was 73/76 open) · 10. slice under the recorded
  `--ui` default · 11. capture regen last (write-heavy) + before-set hash check · 12.
  `python3 docs/wayfinder/validate.py` (28 audits) + UI static validator.
  → **Executed (isolated copy; non-author):** `../evidence/uir-pull-wave/sweep-results.txt` —
  harness 8/8; slice 339/340 and demo 290/291 (sole red = the branch's deliberate `padel.pck`
  export check; pre-reconcile logs kept too); input 5/5; rules 10/10; modes 6/6; save 137/137;
  music 32/32; `court_dimensions_test` `PASS court dimensions: 1111 checks, 0 failures` (invoked
  explicitly — it is orphaned, no runner includes it); shot-parity 675/675; timing 100/100 with the
  injected-failure control failing by design (88/92); switch 85/85; UI menu 97/97 + 98/98; HUD
  172/172; legibility 76/76; router 86/86; theme 271/271; fonts 75/75; data 131/131 + 134/134;
  input/a11y 117/117; reachability 21/21. `slice-ui-new` red is informational, never a gate. Real
  captures re-ran in the copy (`sweep-commands.txt`, `captures.log`).
- [ ] **7. Fix stale text in the pull wave.** UIR-05 `# must stay 4/4` → actual (5/5);
  UIR-09/UIR-22 anchors (above); UIR-00 register note points at `before-set/`; `docs/mission/LOG.md`
  appended after the pull (union-style conflicts expected otherwise).
  → **Closeout 2026-09-17:** three of four done — UIR-05 `# must stay 4/4` → `5/5` (fixed), the
  `uir-00-before-set.md` pointer note (added), `docs/mission/LOG.md` appended (this closeout);
  UIR-09/UIR-22 anchors **still open** (coordinator; also named in `../gate-a-review/REPORT.md` §8).
- [ ] **8. Owner handover & gates.**
  - Owners: **UIR-22 integration owner** = sole writer of `godot/game/**` post-merge;
    **coordinator** = board/logs/register notes; **repo owner (Luca)** = the pull itself (or delegate);
    **branch owner (brother)** = opens the PR if wanted via the `/pull/new/` URL (repo has zero PRs).
  - Engine sequence ends in GATE-A: UIR-09 evidence refresh + play window for Luca — human verdict,
    not agent-certifiable.
  - Do not merge: the brother's duplicate commits (`8037c6b`≡`8fed1da`, `0458c23`≡`2f7b538`) or his
    local `main`; ask him about local-only `a877d19` instead of fetching it.
  - No `git add -A`, ever. No push of `main` before the gates pass and the user agrees.
  → **Partial:** GATE-A handoff published (`../board-gate-a.md`, `../gate-a-review/`: before/after
  pairs with hashes); the play window and verdict are Luca's and **not started**; nothing pushed.
  The duplicate-commit note is moot as executed (only `a1e10f04` merged).
