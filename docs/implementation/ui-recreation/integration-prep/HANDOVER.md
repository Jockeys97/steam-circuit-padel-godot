# HANDOVER — brother-branch integration prep

**Prepared:** 2026-09-17 ~01:33 CEST, by an independent subagent (dev-work profile), while the
UI-recreation mission continued. **Prep only**: no merge/pull/checkout/stash/reset/rebase/fetch,
no commit/push, no engine run, no deletion; budget $0. The checkout was read, never mutated.

## UPDATE 2026-09-17 ~02:45 CEST — post-merge state (supersedes the prep snapshot below)

The prep was **executed and superseded**: the branch moved one commit past the reviewed `2752d9a2`
(`a1e10f0`, the court's real 10×20 m projection), the integration landed as a non-destructive merge
at `c6837b2` (parents `249d55a` + `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590`), and the pull was
reconciled at `c9470e2` (slice assertions restored; no runtime code touched). A docs-only
verification pass re-verified the provenance read-only (merge parents, ancestry, court files
byte-identical `a1e10f04`→`HEAD`, frozen pins re-hashed) — see `../gate-a-review/REPORT.md` §1.

| Prep claim (below) | Current truth (2026-09-17) |
|---|---|
| HEAD / main `252ff60…` | local `main` = **`3238a50`** (the review's `c9470e2` + the shipping-pack evidence commit + the closeout), 10 ahead of remote `origin/main` (`252ff60…`) — **nothing pushed** |
| Branch tip `2752d9a2…` | tip moved once more to **`a1e10f04…`** (the court commit `a1e10f0`); integrated as a merge, not a fast-forward (the UI checkpoint had diverged) |
| Screenshot hazard (branch rewrites the 11 legacy PNGs) | materialized: the merge replaced them (stale renders by the branch's own note); fresh merged-tip captures exist in `/tmp/padel-uir-pull-20260917/repo/…/out/` and durably in `../gate-a-review/pairs/`; the registered baseline `before-set/` is intact and re-verified |
| Court / camera "untouched" (the `branch-review-2752d9a2.md` §2 rows) | **superseded by `a1e10f0`** — court 10 m × 20 m, C1 depth curve, all `CAMERAS` presets re-aimed (`court.gd 844891ea…`, `court_dimensions_test.gd 581adcdc…` at `HEAD`); that review stays historical, valid for `2752d9a2` only |
| Probe sample `manifests/merged2-match_controller.gd` | the merged file at `HEAD` byte-matches it (`a0f56fec…`, 90,953 B) |

Remaining from the prep's next-actions: gates — DONE (`../evidence/uir-pull-wave/`, 19-run sweep;
sole red = the branch's deliberate `padel.pck` export check); UIR-05's "4/4" text and the
`uir-00-before-set.md` pointer note — **closed by the 2026-09-17 closeout**, stale anchors still
OPEN (coordinator); GATE-A handoff — published and final (`../board-gate-a.md`, `../gate-a-review/`,
incl. the merged-tip 1280×720 HUD frames); the verdict is Luca's and not started. The closeout also
ran the merged-tip capture in the real checkout (restored byte-identical) and reconciled the
trackers; nothing pushed.

## Verified state (as recorded by the review, re-anchor at use)

| Fact | Value |
|---|---|
| Local `HEAD` / `main` | `252ff6074039372ebbf8ec682f9adda0e9c80d03` — unchanged; working tree dirty only with UI-lane work |
| Branch under review | `codex/gameplay-and-map` tip **`2752d9a2eda9dafb692c66e91fb423bd0f92f60f`** — 5 commits ahead of `main`, 0 behind, 60 files, +7293/−345; fast-forward-able at ref level |
| PR | **None** (`gh pr list --state all` → `[]` twice). The `/pull/new/codex/gameplay-and-map` link is GitHub's *compare-to-open-a-PR* page, not a PR |
| One shared path with the dirty tree | `godot/game/match_controller.gd` — read-only three-way text probe = **0 conflict hunks** (sample at t2; re-probe on frozen versions) |
| Screenshot hazard | The branch rewrote all 11 legacy `godot/game/out/*.png` (menu/hud/rally/quickmatch-serve/result + 9 arenas) that the UIR-00 register freezes — a pull replaces them **silently** (no conflict) |

**Superseded:** the earlier scout report (`scout-report-61f3ee71-SUPERSEDED.md`, tip `61f3ee71`)
warned of a dead-pad partial bridge. That applies to `61f3ee71` only; tip `2752d9a2` land the S14
lanes including `match_controller.gd`. Do not repeat the partial-pad warning as a current risk —
but do not assume pad-liveness either: re-run the pad gates at merge time
(`switch_mode_audit`, `pad_probe`).

## Done in this prep (all under `docs/implementation/ui-recreation/integration-prep/`)

- The authoritative review + superseded report copied durably (`branch-review-2752d9a2.md`).
- All usable review snapshots preserved under `manifests/` (branch lists, local status, t1/t2
  unstaged patches, branch diffs, merge-probe inputs + corrected 0-conflict output).
- **UIR-00 before-set: all 20 registered PNGs copied to `before-set/`, every copy byte-identical
  to the register** (20/20 match, 0 missing, 0 changed) with source-before/after hashes in
  `PROVENANCE.md`/`.json`. The wave3 `/tmp/uir-wave3-out-before/` backup for 4 of them was
  cross-checked and agrees. These copies are outside `godot/game/out/`, so a pull cannot touch
  them. **No capture re-run, nothing restored, nothing overwritten.**
- `MERGE-CHECKLIST.md` — the durable, ordered checklist for the future integration.

## Live conditions to respect (they were observed changing during prep)

- At least two other writers are active in this checkout: the UI integrator (mutating
  `MenuScreen*`, `Hud*`, `main_menu.gd`, `match_controller.gd`, captures) and an art/meshy lane.
  At prep time `main_menu.gd`/`match_controller.gd` still matched the review's **t2** hashes;
  `godot/game/hud.gd` and the `src/ui` screen files carry their own live hashes (see
  `PROVENANCE.md` §D). Re-hash before trusting any sample.
- **Never claim a newer capture is the baseline.** Baseline = `before-set/` (== register hashes).
  If a working-tree capture differs, it is a new capture with its own provenance.
- One engine at a time across the checkout (`/tmp/padel-godot.lock.d`; no `flock` on macOS).
- Repo house rules that bind the integration: never `git add -A`; no file claimed by two missions
  is written by two hands; a red suite is reported, not worked around.

## Next actions (order)

1. UI lane finishes its wave and commits / hands off (its DoD says "no commits" — that must
   change before a pull, or the pull aborts on the dirty `match_controller.gd`).
2. Follow `MERGE-CHECKLIST.md`: re-pin → re-probe merge → preserve → pull the pinned SHA →
   rerun the combined gates serially → re-register screenshots / fix stale anchors.
3. No commit/push of repo state without the user's explicit consent; the checkpoint for a
   stopped session is the reviewed diff + these snapshots, not a silent commit.

**Open owner actions (outside this prep's write scope):** the coordinator should add a dated note
to `evidence/uir-00-before-set.md` pointing at `integration-prep/before-set/` before the pull,
and the ticket-text drift fixes (UIR-05 "4/4"→actual, UIR-22/UIR-09 anchors) belong to the
pull wave — see `MERGE-CHECKLIST.md` §7.
