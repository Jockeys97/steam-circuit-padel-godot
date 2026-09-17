# Branch-pull integration journal — checkpoint the UI wave, integrate `codex/gameplay-and-map`

Date: 2026-09-17 (CEST) · repo: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot`
Author: integration subagent (dev-work profile), sole writer in this wave.
Engine: `/Applications/Godot.app/Contents/MacOS/Godot` 4.7.2 `ed1daf0bf`.
Budget $0, no paid calls, no nested workers. One engine at a time; a pre-existing owner
Godot process is never killed.

## 0. Scope and constraints (as dispatched)

- Checkpoint the reviewed UI-mission files with explicit pathspecs (user authorized commits;
  **no push** — the parent certifies first). Preserve every unrelated/preexisting file
  (`.hermes/`, `art/concepts/`, `art/generated/`, `meshy/**`, arena `.webp.import` sidecars).
- Integrate the brother branch via a normal non-destructive merge (no force/reset/stash/
  rebase/history rewrite), re-pinned live (do not trust the stale `2752…`).
- Reconcile the shared `match_controller.gd`; prove semantics, not just the 0-conflict text probe.
- Re-run the combined gates serially with per-run error detection.

## 1. Preconditions recorded before any mutation

| Fact | Value |
|---|---|
| Branch / HEAD at start | `main` = `252ff6074039372ebbf8ec682f9adda0e9c80d03` (= origin/main at prep) |
| Frozen working state | `main_menu.gd` sha256 `9ded3edc4f34ede1f4287ba8d372d0abe38d46fbc41159e25ddd6a1647564e64`; `match_controller.gd` sha256 `18542ea2d3642e3fe6af96e130c672636dd446320573db8fd25797de8150538a` — **identical to prep's t2 and PROVENANCE §D; zero drift**. |
| `before-set/` backup | `docs/implementation/ui-recreation/integration-prep/` — `shasum -a 256 -c SHA256SUMS.txt` → **47 OK, 0 failures** (includes all 20 before-set PNGs) before any action. |
| No stash / nothing staged | confirmed (`git status` clean of index entries at start). |
| Running engine | `pgrep -x Godot` → none at start. |
| Secret scan (candidate set only) | 0 hits across 8 patterns (key/token/password/private-key/AWS/GCP) over `godot/src/ui`, `godot/tests/ui`, `godot/assets/ui`, `docs/implementation/ui-recreation`; no `.env/.pem/.key/.p12` anywhere in the set. Scanned by file-count only; nothing printed. |

Freeze artifacts for this wave (added, never overwriting prep snapshots):
`integration-prep/manifests/local-status-final-precommit.txt`,
`integration-prep/manifests/active-unstaged-FINAL.patch`,
`integration-prep/manifests/frozen-hashes-precommit.txt`.

## 2. The parent's `screen_menu_audit` double-ERROR question — investigated

`/tmp/uir-parent-pregate/screen_menu_audit.log`: `grep -c "ERROR"` = 2, and the two hits are
(a) the log's own note line at :10 that *quotes* the expected ERROR text, and (b) one real
engine line `ERROR: ScreenRouter.register: 'nope' is not one of the thirteen reference
screens` with a GDScript backtrace through `register (ScreenRouter.gd:143)` ← `_mount
(screen_menu_audit.gd:111)` ← `_run (:84)`. That is the audit's **deliberate refusal check**
(`register_refuses_an_id_outside_the_table`) printing the refusal it asserts; the run's own
note says the engine script-error count must still read zero. Classification: expected, not
a defect — to be re-verified by re-running the audit in this wave (same single deliberate
`ERROR:`, `PASS 97/97`, 0 `SCRIPT ERROR` lines) rather than suppressed.

## 3. Checkpoint commit — on hold until inventory freeze (next)

## 4. Branch re-pin, merge, reconciliation — to be appended

## 5. Combined gates — to be appended

## 6. Evidence / board updates — to be appended
