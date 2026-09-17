# GATE-A review pack — visual handoff, merge provenance, ticket assessment

**Prepared:** 2026-09-17 ~02:35–02:50 CEST, by a delegated verification subagent (dev-work profile), as the
documentation-correction + GATE-A preparation pass for the post-pull state.
**Constraints honored:** git read-only (log/show/rev-list/merge-base/diff/status/ls-remote only — no fetch,
merge, commit, stash, checkout); **no engine run** (another lane owns the engine/export work); **no
paid calls** ($0); **no deletion**; no push; only doc/artifact files under
`docs/implementation/ui-recreation/` were created or edited.
**Non-claims:** nothing here is a look/feel verdict (GATE-A is Luca's); no suite was re-run by this pass
(suite numbers below are quoted from the recorded runs and labeled as such); no frame was altered —
the only composed files are the two labeled contact sheets, whose panels are byte-identical copies of
the real captures (hashes below). This pack certifies nothing; it hands the parent real artifacts to
inspect and requests Luca's verdict through the parent.

**Update (2026-09-17, post-pull closeout):** the open engine-lane item (§7.3, first bullet) is
closed — a merged-tip 1280×720 re-capture of the prototype HUD exists
(`pairs/hud-after-prototype-{serve,hud,rally}-1280x720.png`; sheet
`sheets/hud-before-after-1280x720.png`; transcript
`../evidence/uir-gate-a-hud-1280x720-capture.log`), and the §7.2 coordinator items were reconciled
(ticket frontmatter UIR-08/09/24, README `approved`, UIR-05 text, before-set pointer, LOG entry).
See §8 for the deltas; the sections around it are preserved as written at ~02:50 CEST.

---

## 1. Merge provenance — independently re-verified (read-only)

The claim under test: `HEAD c9470e2` contains the brother branch (`codex/gameplay-and-map`) merged at
`c6837b2` at the pinned tip `a1e10f04`, with the UI checkpoint preserved, plus a reconciliation commit.

| Assertion | Result | How |
|---|---|---|
| Merge commit `c6837b2f093266705985671afdc455002805cec5` has exactly two parents: `249d55a24da8f1a3ba23fc531cf5ca4e2eb4a1c7` (UI checkpoint) + `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590` (pinned branch tip) | **TRUE** | `git rev-list --parents -n 1 c6837b2` |
| `a1e10f04…` is an ancestor of `HEAD` | **TRUE** | `git merge-base --is-ancestor a1e10f04 HEAD` → exit 0 |
| Court-changing source at `HEAD` is byte-identical to `a1e10f04` (court.gd, arenas/, court_builder.gd) | **TRUE** — the only diffs `a1e10f04..HEAD` on those paths are 3 engine-generated `.import` sidecars (+120 lines) | `git diff --stat a1e10f04 HEAD -- godot/game/court.gd godot/game/arenas/ godot/game/court_builder.gd` |
| Frozen pins re-hash at the worktree of `HEAD` | **TRUE, all six match the review's appendix** | `shasum -a 256` (values below) |
| The reconciliation commit `c9470e2` touched no runtime code | **TRUE** — stat vs `c6837b2`: `godot/tests/game_slice_test.gd` (+140/−17), `docs/**`, `evidence/uir-pull-wave/**`, 3 `.import` sidecars. Commit message: "No runtime code touched. Nothing pushed." | `git show --stat c9470e2`; `git diff --stat c6837b2 c9470e2` |
| Remote state (read-only `git ls-remote`, 2026-09-17 ~02:35 CEST) | `refs/heads/codex/gameplay-and-map` = `a1e10f04…` (unmoved since the pin); `refs/heads/main` = `252ff6074039372ebbf8ec682f9adda0e9c80d03` — **local `main` is 9 commits ahead; nothing pushed** | `git ls-remote`; `git branch -vv` |

**Hash pins at `HEAD` (`c9470e2306465aa2b34ffc9a17f9b2bcc2db0f97`), all re-measured by this pass:**

```
844891ea8c30e944608f30c9ad08f9bae8df7c033a2cdd4e0a97be12de0872f3  godot/game/court.gd
883b8ff56be6948f68c0bc8cc17f95c8004a14275d99072df27499d26afc07d1  godot/game/hud.gd
a0f56fec1a99e0b0eb837ae9bd076847381a798215ee1a6d7527b1071e3229ca  godot/game/match_controller.gd  (90,953 B == integration-prep/manifests/merged2-match_controller.gd)
581adcdcb5a64cf579c58067dfb466300c0a93f7817789ba58ed5680e824317b  godot/tests/court_dimensions_test.gd
9ded3edc4f34ede1f4287ba8d372d0abe38d46fbc41159e25ddd6a1647564e64  godot/game/main_menu.gd
3aef17de3f1ff1aa680e23746d3f1f60212b5e9053c4ca05c9e3943cf5635190  godot/project.godot
```

Conclusion: the merge is real, pinned, and intact in the local checkout; the reconciliation commit
restored the main-line slice assertions the branch rewrite had dropped (`game_slice_test.gd` now
carries the court 10×20 check at line 226 and the restored music/demo/arena sections — spot-checked).
Nothing is pushed; the parent still owns that decision.

## 2. What the court merge changed — and what it invalidates

The one commit beyond the previously reviewed `2752d9a2` is `a1e10f0` (Alessio Fantini, 2026-09-17
01:37:13 +0200, "give the court its real 10 x 20 m, with the simulation still in pixels"). From the
independent review plus source reads (no engine):

- `court.gd`: `court_len()` 20→**10**, `court_depth()` 12.7→**20**, `service_z()` 3.15→**6.95**;
  world X becomes a uniform 10 m / 800 px projection; Z uses a monotone C1 Hermite `depth_m()`;
  `PX_TO_M = 0.025` is retained only for heights/legacy effects; all three `CAMERAS` presets
  (`default`/`wide`/`playable`) were re-aimed.
- New gate file: `godot/tests/court_dimensions_test.gd` — **orphaned**: no runner references it at
  `HEAD` (re-checked this pass: `grep` over `godot/tests/**` runners finds nothing). It must be
  invoked explicitly (the pull wave did: `PASS court dimensions: 1111 checks, 0 failures`).
- **Supersession:** the prep docs' statements that the court/camera were untouched
  (`integration-prep/branch-review-2752d9a2.md` §"Map dimensions / court / arenas | untouched" and
  "Camera | untouched") describe `2752d9a2` **only** and are false at `a1e10f04`+. The historical
  file is preserved as written; the supersession is recorded in `HANDOVER.md`, `MERGE-CHECKLIST.md`
  and `board-gate-a.md`.
- **Stale captures:** the merge brought the branch's committed legacy `godot/game/out/*.png` renders
  (stale by the branch's own commit message). The working tree's legacy-name PNGs are those stale
  renders; the fresh merged-tip captures live in the isolated pull copy
  `/tmp/padel-uir-pull-20260917/repo/godot/game/out/` (the sanctioned source for this pack). No
  committed frame is valid "after" evidence.
- **Two human decisions ride along** (from the review, still open for the owner): the camera *feel*
  ("measured, not judged" per the commit) and the court-aspect question (mission STATE lists it as
  an owner decision; resolved in code at the owner's request).

## 3. Ticket status assessment — all 28, programmatic

Raw output: `ticket-status-assessment.txt` (script: `assess_ticket_status.py`; run 2026-09-17 against
the tree as found, **before** this pass's board edits). Result: **28/28 parsed from ticket
frontmatter and 28/28 board rows; zero divergences at assessment time**; counts —
`done 8` (UIR-00–UIR-07), `blocked 19`, `blocked-external 1` (UIR-26); `plan_approved: true` on the
8 done tickets, `false` on the other 20; gates tally: plan-approval ×28, gate-a ×17,
product-scope ×1.

**Corrections applied by this pass (board rows only — see §6):**

| Ticket | Was | Now | Justification (evidence path) |
|---|---|---|---|
| UIR-08 | blocked | **done** | Acceptance ran twice: `evidence/uir-pre-gate-a-hud-audit.log` `PASS 172/172`, 0 SCRIPT ERRORs (closeout, non-author execution) and again on the merged tree in `evidence/uir-pull-wave/sweep-results.txt` (`ui-hud-audit exit=0 PASS 172/172`). DoD items map to the closeout record (`uir-pre-gate-a-closeout.md` §3 findings table incl. the review's six findings, all fixed or guarded). |
| UIR-09 | blocked | **done** | `evidence/uir-09-prototype-mount.md` (switch design, suite table, capture table); `evidence/uir-pre-gate-a-captures.log` (11 real capture runs, exit 0); suites green pre- and post-merge (`uir-pull-wave/sweep-results.txt`); `project.godot` hash unchanged (`3aef17de…`); the GATE-A brief is completed by this pack (`board-gate-a.md`). |
| UIR-24 | blocked | **in-progress (partial)** | Harness + legibility audit landed and re-run green at four sizes (`PASS 76/76`, `uir-pre-gate-a-legibility.log`; capture harness `PASS 5/5`, `uir-24-capture.log`). **Not done**: coverage is menu + HUD only — the ticket's "coverage grows as screens land" rule keeps it partial until UIR-10–UIR-21 exist. |

The whole project is **not** complete, and this pack does not label it so: GATE-A, the
product-scope/platform decision and `luca-final` stay open; UIR-10–UIR-23, UIR-25, UIR-27 remain
blocked; UIR-26 stays blocked-external. The one deviation left deliberately red (the branch's own
`padel.pck` export check) is reported, not worked around.

**Divergences this pass did NOT (and must not) fix — for the coordinator:**
1. The ticket frontmatter for UIR-08/09/24 still reads `state: blocked` / `plan_approved: false`
   (this pass's scope was the board, not ticket files; the coordinator's convention is to set
   `plan_approved: true` + `state: done` when flipping — see `LOG.md` lines 36/88). *(Reconciled by the
   closeout pass — §8.)*
2. README frontmatter still says `approved: false` while `CHARTER.md` and `LOG.md:4` record that
   Luca's request to implement the tickets approves implementation (visual approach, platform scope
   and final acceptance explicitly *not* approved by it — the same three gates this pack keeps open).
   *(Reconciled — §8.)*
3. UIR-05 ticket text `# must stay 4/4` is stale — the sweep measures `PASS 5/5`. *(Fixed — §8.)*
4. UIR-09/UIR-22 line anchors into `game_slice_test.gd` (`:542-571`, `:1796-1811`) were not
   re-located after the reconciliation rewrite. *(Still open — §8.)*
5. `evidence/uir-00-before-set.md` still has no dated pointer note to `integration-prep/before-set/`.
   *(Added — §8.)*

## 4. The visual pairs — paths, hashes, viewports

All paths below are durable (inside the repo) unless marked `/tmp/` (the sanctioned capture source).
Every copy is byte-identical to its source (sha256 equality asserted at copy time).

| Role | File | Viewport | sha256 |
|---|---|---|---|
| MENU — reference (frozen web build) | `gate-a-review/pairs/menu-reference-web-1280x720.png` | 1280×720 | `6ad40de750b86db5ab1e4f8759b8aed207c9669da5f46fd52ff6e3c28d0b6ae9` |
| MENU — before (UIR-00 register baseline, ported UI) | `gate-a-review/pairs/menu-before-ported-1280x720.png` | 1280×720 | `bb2d929c09f8d7030ab6da25f63b47e959fc6f103e6b9b377eec390d6d777202` |
| MENU — after (recreated prototype, merged tip) | `gate-a-review/pairs/menu-after-prototype-1280x720.png` | 1280×720 | `badf1ec05243dd437c3951c4c8b38b75ddcb8f36b8ef3ecf3c8221949ff1177d` |
| HUD — reference (frozen web build) | `gate-a-review/pairs/hud-reference-web-1280x720.png` | 1280×720 | `1d1d5d5f4a085a0a2c268300f259b51bab809ef7e589085a9bbf8acfeb068cdf` |
| HUD — before (UIR-00 register baseline, ported legacy HUD) | `gate-a-review/pairs/hud-before-ported-1280x720.png` | 1280×720 | `0a2696dd784382151dcd9f6a84bebdfd541aa77d85e33dc58f7b39b4b62e2f20` |
| HUD — after, serve (recreated HUD, `--ui=new`, merged tip) | `gate-a-review/pairs/hud-after-prototype-1152x648.png` | **1152×648** | `e13b4d845af59fc2ea9cb2b09761a64fb2626365c9cd7beaeb29650323737cf4` |
| HUD — after, later state | `gate-a-review/pairs/hud-after-prototype-hud-1152x648.png` | 1152×648 | `c603430c313e078397b4c952da1ee65a33fac98d807a8d3df29031986745d621` |
| HUD — after, rally | `gate-a-review/pairs/hud-after-prototype-rally-1152x648.png` | 1152×648 | `36be85042f3263a0131789dc911f86c6abc74051ab93d4d74847819ea76e0f0b` |
| HUD — prototype, **pre-merge** (kept for the 1280×720 shape) | `gate-a-review/pairs/hud-prototype-premerge-1280x720.png` | 1280×720 | `1bd985050a1011e35d6685280886c46a5e9b7e70855a6f7d039c504ec17b6856` |
| HUD — after, serve (**post-merge 1280×720**, closeout) | `gate-a-review/pairs/hud-after-prototype-serve-1280x720.png` | 1280×720 | `93799b94ced8ca32…` |
| HUD — after, later state (**post-merge 1280×720**, closeout) | `gate-a-review/pairs/hud-after-prototype-hud-1280x720.png` | 1280×720 | `91e0a6d31b716e23…` |
| HUD — after, rally (**post-merge 1280×720**, closeout) | `gate-a-review/pairs/hud-after-prototype-rally-1280x720.png` | 1280×720 | `14a75224f6d9bfe4…` |

**Composed contact sheets** (panels unmodified; captions and bands burned in — composition only):

- `gate-a-review/sheets/menu-before-after-1280x720.png` — REFERENCE | BEFORE | AFTER, 3936×1068.
- `gate-a-review/sheets/hud-before-after.png` — REFERENCE | BEFORE | AFTER, 3808×1098.
- `gate-a-review/sheets/hud-before-after-1280x720.png` — REFERENCE | BEFORE | AFTER (serve,
  post-merge), 3936×1098, `61ab1a56…`; composed by the closeout pass (§8). The 1152×648 sheet above
  is retained unchanged.

Sources: references from `evidence/reference-captures/`; befores from
`integration-prep/before-set/` (register-verified: both befores' sha256 match `SHA256SUMS.txt` of the
prep); afters from `/tmp/padel-uir-pull-20260917/repo/godot/game/out/` — the pull wave's real-GPU
captures (Metal, Apple M4), recorded in `evidence/uir-pull-wave/captures.log` (menu capture line:
`CAPTURE_SAVE err=0 path=res://game/out/ui-prototype-menu.png size=1280x720`; timestamps 02:26).
The AFTER menu frame is byte-identical (md5 `b99f1cc7…`) to the pre-merge `ui-menu.png` — the court
merge provably did not change the menu frame. Full records: `PROVENANCE.md` + `pairs/SHA256SUMS.txt`.

## 5. Frame-grounded observations (descriptions only — no taste verdict)

Vision was used to **identify and describe** the frames (labels, HUD family, scenario), not to judge
them. What the pairs show:

- **Menu:** reference = web landing page (top bar with three buttons + `IT`, hero title, description,
  pad-note, six-button column, poster card, tag chips). Before = the ported dev menu (flat text UI,
  `Port Godot 4.7.2 — demo`, opponent/athlete/arena sections). After = the recreated `MenuScreen`
  carrying the reference's structure over a flat backdrop, no dev text visible.
- **HUD:** reference = web HUD (`SCORE` card top-left with MAESTRO vs RIVAL, `GAME TIME`, MAP,
  `FIRST SERVE · SPACE` banner, log affordance; EN locale in that capture). Before = ported legacy
  HUD (`SEED · TIER · TICK · RNG` dev strip, central score bar, `CRONACA` box, `ENERGIA — TU`) over
  the old court. After = recreated HUD family (no dev strip; `SCORE` card, `MAPPA`, `GAME TIME`,
  `COPPIA`/`CONTROLLO` chips, `CRONACA` toggle label; IT strings) over the **merged 10×20 court**,
  with the merged branch's S14 timing cues visible (`LEGGI LA PALLA` prompt, `PERFETTO`/`BILANCIATO`
  verdict, timing ring) — those cues are the branch's own presentation seen over the prototype HUD
  (`--ui=new`; legacy `_hud` hidden at `match_controller.gd:718/735`).
- **Open frame-level items already recorded elsewhere and still applicable:** the recorded
  pairing note (the reference `game.png` shows `RIVAL`, the port shows tier-derived names); the
  minimap-header tightness watch item; and — because the court/camera changed — **the S14
  frame-relative tuning (`TIMING_FOOT_FORWARD` etc.) was measured under the old camera and must be
  re-measured, not inherited**.

## 6. Documentation corrections made by this pass

- `BOARD.md` — "Last updated" note + a new "Post-pull correction and GATE-A preparation" paragraph;
  rows UIR-08 → `done`, UIR-09 → `done`, UIR-24 → `in-progress (partial)`; standings recomputed to
  10 done / 1 partial / 16 blocked / 1 blocked-external; gate states restated (GATE-A,
  product-scope, luca-final open; plan-approval per CHARTER).
- `integration-prep/HANDOVER.md` — a dated UPDATE section that supersedes the prep snapshot
  (each prep claim → current truth; incl. the court/camera supersession and the captures situation).
- `integration-prep/MERGE-CHECKLIST.md` — steps 0–4 and 6 annotated as executed with results and the
  pinned SHA filled in; steps 5, 7, 8 annotated as open/partial with owners.
- **New:** `board-gate-a.md` (the GATE-A board report the charter asks for) and this `gate-a-review/`
  directory (report, provenance, pairs, sheets, scripts, assessment output).
- **Preserved as historical, unmodified:** `branch-review-2752d9a2.md`,
  `scout-report-61f3ee71-SUPERSEDED.md`, all `evidence/*` logs, all tickets.

## 7. Remaining blocked scope (nothing here is self-certifying)

1. **Luca (through the parent):** GATE-A verdict on the menu+HUD approach; the platform/touch
   decision; final acceptance. Mass screens (UIR-10–UIR-21) wait for GATE-A.
2. **Coordinator:** reconcile ticket frontmatter (08/09/24) and README `approved` flag with the
   board; stale UIR-05 text and UIR-09/UIR-22 anchors; `uir-00-before-set.md` pointer note;
   mission LOG append; the push decision (nothing pushed).
3. **Engine/export lane:** re-capture the prototype HUD at 1280×720 at the merged tip (only
   1152×648 post-merge frames exist); re-measure the S14 frame-relative numbers under the new
   camera; give `court_dimensions_test.gd` a recurring invocation; decide whether the main
   checkout's stale legacy PNGs get regenerated there (the sweep ran in an isolated copy).
4. **Parent:** inspect `gate-a-review/sheets/*.png` and the raw pairs, then request Luca's verdict
   before any remaining screens are produced.

## 8. Closeout update (2026-09-17): merged-tip 1280×720 re-capture + reconciliation

One engine run, on the real checkout at `HEAD 3238a50` (the shipping-pack evidence commit; no
runtime code changed since `c9470e2`) — sole engine owner held (`pgrep -x Godot` empty before and
after; the checkout's own plan-lane PNGs were snapshotted first):

```
"$GODOT" --rendering-driver opengl3 --path godot --resolution 1280x720 res://game/Match.tscn -- \
    --ui=new --capture=match --tier=3 --seed=20260916
```

→ exit 0, 0 SCRIPT ERRORs, one named engine allowance (the `check_log.sh` shutdown report), real GPU
(`OpenGL API 4.1 Metal`, Apple M4), `CAPTURE_DONE shots=5 ticks=25962`, all seven frames
`size=1280x720`. Full transcript: `../evidence/uir-gate-a-hud-1280x720-capture.log`.

- `godot/game/out/` was snapshotted first (104 files) and **restored byte-identical** after the
  run: name-level delta empty, byte-delta exactly the seven capture outputs, post-restore hashes
  equal the snapshot, `git status` for the directory unchanged, the five plan-lane tracked PNGs
  equal to `HEAD` (the merge's stale renders were restored, not repaired — the UIR-00 register
  values live at `integration-prep/before-set/`, re-hashed and matching).
- Durable frames: the three new pairs and the composed `sheets/hud-before-after-1280x720.png`
  (hashes in §4). The earlier 1152×648 sheet is retained unchanged; `compose_sheets.py` is
  deterministic (a dry-run rerun reproduced both earlier sheets byte-identically before the script
  was extended — `PROVENANCE.md` cross-check 7).
- Reconciliation (the §7.2 coordinator items): ticket frontmatter UIR-08/09 → `done`, UIR-24 →
  `in-progress`, all three `plan_approved: true`; README frontmatter `approved: true`,
  `approved_by: Luca` (implementation approval from the implement request — GATE-A, product-scope
  and `luca-final` stay open, per `BOARD.md`); UIR-05's stale `# must stay 4/4` → `5/5`;
  `evidence/uir-00-before-set.md` gained the dated pointer to `integration-prep/before-set/`;
  `LOG.md` carries the closeout entry. Assessment rerun on the reconciled tree: 28/28 tickets
  parsed, zero board divergences (counts 10 done / 1 in-progress / 16 blocked / 1 blocked-external).
- Still open from §7: the UIR-09/UIR-22 slice line anchors (coordinator); S14 frame-relative
  re-measurement and a recurring `court_dimensions_test.gd` invocation (engine lane); the push
  decision (parent). Nothing pushed.
