# MERGE-CHECKLIST — integrating `codex/gameplay-and-map` (durable)

Use top to bottom at integration time. Every step assumes **one writer at a time** and **one engine
at a time** (`/tmp/padel-godot.lock.d`; on macOS there is no `flock`; stale guards recovered by the
coordinator only). Nothing here authorizes a commit/push without the user's explicit consent — the
checkpoint for a stopped session is the reviewed diff + snapshots (`manifests/`, `before-set/`).

- [ ] **0. Preconditions.** UI lane's wave committed or handed off (its dirty
  `godot/game/match_controller.gd` aborts any pull otherwise). All other writers stopped on the
  paths about to change. `pgrep -f Godot` empty. User go-ahead for the pull obtained.
- [ ] **1. Re-pin the branch (do not trust this review's SHA blindly).**
  - `gh pr list --repo Jockeys97/steam-circuit-padel-godot --state all` → expect `[]` (still no PR; the
    `/pull/new/` URL is not a PR).
  - `git ls-remote https://github.com/Jockeys97/steam-circuit-padel-godot.git 'refs/heads/*'` → expect
    `main` = `252ff60…` and branch = `2752d9a2…` **or a successor**. The branch already moved once
    mid-review (`61f3ee71` → `2752d9a2`) — if it moved again, `git diff old_sha..new_sha` in a
    read-only clone and re-review the delta **before** merging; record the new pinned SHA here:
    `pinned: ____________________`.
  - `git merge-base --is-ancestor origin/main origin/codex/gameplay-and-map` (in a scratch clone or
    after fetch) → true ⇒ ff-able.
- [ ] **2. Re-probe the merge — the shared `match_controller.gd` reconciliation.** It is the **only**
  path the branch shares with the dirty tree. On frozen pre-pull versions (not the old samples):
  `git merge-file -p --diff3 local.gd base.gd branch.gd`, record exit code and `<<<<<<<` count.
  The 2026-09-17 sample probe was 0 conflicts / exit 0 (`manifests/merged2-match_controller.gd` is
  that output — a sample, **not** a final merge). Write order for this file stays serialized:
  **UIR-09 mount → S14c branch → UIR-22**; hand over via commit, never via a shared dirty tree.
- [ ] **3. Protect the screenshots (highest silent-loss risk).** Baseline copies already exist:
  `integration-prep/before-set/` (20 files, byte-identical to the UIR-00 register — 20/20 at prep).
  - Before pull: `shasum -a 256 before-set/*.png` and compare against `PROVENANCE.md`; if any file
    was altered since prep, it is **not** baseline — say so, re-register, never silently substitute.
  - The pull replaces `godot/game/out/{menu,hud,rally,quickmatch-serve,result,arena-*}.png` with the
    branch's regenerated captures **without any conflict** — that is expected; the baseline lives in
    `before-set/` from then on. Add the dated pointer note to `evidence/uir-00-before-set.md`
    (coordinator's file, not the puller's).
  - Never regenerate the other lane's capture namespace: `ui-*`/`ui-prototype-*` = UI lane;
    legacy names + `probe-*`/`timing*`/`hud-off` = mission/S14.
- [ ] **4. Preserve local state, then pull.**
  - Freeze: `git status --porcelain`, `git diff > active-unstaged-FINAL.patch`,
    `shasum -a 256 godot/game/main_menu.gd godot/game/match_controller.gd`; compare with
    `PROVENANCE.md` §D. Integrator still editing ⇒ stop and wait.
  - `git fetch origin` → `git merge --ff-only <pinned SHA>`. If the tree refuses (dirty touched
    file), that is the guardrail working — commit/hand off first, do not force.
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
- [ ] **6. Rerun the combined tests — serially, in this order** (all counts below were *claims*;
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
- [ ] **7. Fix stale text in the pull wave.** UIR-05 `# must stay 4/4` → actual (5/5);
  UIR-09/UIR-22 anchors (above); UIR-00 register note points at `before-set/`; `docs/mission/LOG.md`
  appended after the pull (union-style conflicts expected otherwise).
- [ ] **8. Owner handover & gates.**
  - Owners: **UIR-22 integration owner** = sole writer of `godot/game/**` post-merge;
    **coordinator** = board/logs/register notes; **repo owner (Luca)** = the pull itself (or delegate);
    **branch owner (brother)** = opens the PR if wanted via the `/pull/new/` URL (repo has zero PRs).
  - Engine sequence ends in GATE-A: UIR-09 evidence refresh + play window for Luca — human verdict,
    not agent-certifiable.
  - Do not merge: the brother's duplicate commits (`8037c6b`≡`8fed1da`, `0458c23`≡`2f7b538`) or his
    local `main`; ask him about local-only `a877d19` instead of fetching it.
  - No `git add -A`, ever. No push of `main` before the gates pass and the user agrees.
