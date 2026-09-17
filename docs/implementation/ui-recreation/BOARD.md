# Board: UI recreation pack

Live status board for the 28 tickets. The coordinator is the only writer of this file; workers never edit it. Claims happen through the coordinator (claim protocol below): the acknowledgement row is the lock. Status changes happen only with the evidence named in the ticket.

Last updated: 2026-09-17 (**finalize closure** — every repair landed and the pack was re-run serially on the final tree, one engine process at a time: **32 runs, 32 green**, 4,318 checks, 0 `SCRIPT ERROR`, 11 classified engine lines; tree digest `1256f5f1d7200437`, stable; the playable route `menu→modes→characters→arena→drill→match→pause→result→rematch→settings` verified in-engine; tickets 26 done / 1 ready / 1 blocked; the replay seam + pause flag split closed; hash registers re-fingerprinted; `board-gate-a.md`'s stale opt-in text corrected to UIR-22's approved default-NEW; **nothing committed or pushed** — see the "Finalize closure" note below). Previous: 2026-09-17 (**finalize wave** — UIR-22 integration landed and the whole pack re-run serially on the merged tree, one engine process at a time; 32 runs, 24 green, 8 red with the failing check names recorded; the playable route `menu→modes→characters→arena→drill→match→pause→result→rematch→settings` verified in-engine; tickets reconciled to 18 done / 8 in-progress / 2 blocked; the stale `SmashTutorial.gd` hash row corrected; **nothing committed or pushed** — see the "Finalize wave" note below). Previous: 2026-09-17 (post-pull closeout — merged-tip 1280×720 HUD recapture, ticket frontmatter and the README `approved` flag reconciled with this board, nothing pushed; **plus the post-pull correction pass** — merge provenance re-verified read-only, UIR-08/UIR-09 rows flipped to `done` on their landed evidence, UIR-24 recorded `in-progress`/partial, the GATE-A handoff pack published at `board-gate-a.md` + `gate-a-review/`; **plus the pre-GATE-A closeout** — UIR-07's recorded caption finding and a second caption defect closed, the wave-3 HUD review reconciled with `hud_audit` 172/172 and `ui_legibility_audit` 76/76, captures regenerated for real, the full 19-run sweep green; `gate-a`, the platform/touch decision and `luca-final` stay untouched and unclaimed — see the "Post-pull correction" and "Post-pull closeout" notes below)

## State legend

| Field | Values | Meaning |
|---|---|---|
| state | `blocked` | not started; waiting on `blocked_by` tickets and/or a gate |
|  | `ready` | all blockers done, gates passed, no other holder; a worker may request the claim |
|  | `in-progress` | claimed and acknowledged; the worker's name and date are in the row |
|  | `done` | acceptance ran, evidence exists, hand-back recorded |
|  | `blocked-external` | waits on a human decision outside the pack (UIR-26 only) |
| readiness | `potential` | becomes `ready` automatically when blockers/gates land |
|  | `external` | needs a decision document updated first |
|  | `plan-approval` | Luca approves this pack (recorded passed 2026-09-17 — implementation only; see Standings) |
|  | `gate-a` | Luca's verdict on the menu+HUD prototype approach |
|  | `product-scope-and-platforms` | Luca's touch/OSK decision |
|  | `luca-final` | Luca's verdict on the finished recreation |
| closing_gate | `luca-final` | UIR-25 only: applies when UIR-25 closes, after its evidence is prepared, never before |

## Frontier

**Closure note (2026-09-17):** every wave below has landed and GATE-A passed (`passed-by-owner`); UIR-23 closed on its own executed acceptance (full `PASS 133/133`, demo `PASS 178/178` — see its closure note below), and UIR-25 waits on `luca-final` alone. Claims go through the coordinator. The waves followed the DAG exactly:

- Wave 0 (parallel; `plan-approval` only): UIR-00 baseline, UIR-01 assets, UIR-03 router, UIR-06 computed styles.
- Wave 1: UIR-02 theme (needs UIR-01 + UIR-06), UIR-04 adapters, UIR-05 input/a11y.
- Wave 2: UIR-07 menu + UIR-08 HUD (parallel prototypes).
- Wave 3: UIR-09 prototype mount, then GATE-A (Luca's prototype verdict).
- Wave 4 (after GATE-A): UIR-10, UIR-11, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-21 in parallel (UIR-21 needs only UIR-08, already done); UIR-12 opens when UIR-11 lands; UIR-20 opens when UIR-13 and UIR-19 land; UIR-23 opens when UIR-10, 11, 12, 21 land. UIR-24 starts as soon as GATE-A passes (it needs only UIR-03 + UIR-09) and its coverage grows as screens register.
- Wave 5: UIR-22 integration, then UIR-27 replay (UIR-27 is blocked by UIR-22: one writer for `godot/game/**` at a time).
- Wave 6: UIR-23 and UIR-24 final runs, then UIR-25 final evidence (needs UIR-22, 23, 24, 27). UIR-25's execution (phase A) runs under plan-approval + gate-a; it closes on `luca-final` after Luca's verdict.
- Outside the waves: UIR-26 (external decision; UIR-25's conditional blocker: landed, or the decision recorded verbatim as the scope exception).

Foundation wave result (2026-09-17): UIR-00, UIR-03, UIR-04 and UIR-05 are `done` with
evidence in `evidence/uir-00-baseline-gates.log`, `uir-00-before-set.md`,
`uir-03-router-audit.log`, `uir-04-adapters-audit.log` and `uir-05-input-a11y-audit.log`.
That makes UIR-07 and UIR-08 (menu + HUD prototypes, blocked by UIR-03) the next
claimable tickets once plan approval covers them; UIR-09 follows them, and GATE-A is
still Luca's, unstarted.

Menu wave result (2026-09-17): UIR-01, UIR-02 and UIR-06 are `done` — their verification
was the pending item and it ran on the engine in an isolated copy of the working tree
(`/tmp/padel-uir-wave2-20260917/repo`, the running game process untouched):
`fonts_assets_probe` 75/75, `theme_probe` 254/254 after three defects in the probe itself
were fixed (unthemed grid, chip height rule, 1024x600 overflow — `evidence/uir-02-theme-probe.log`),
static validator 25/25. UIR-06's measured values are asserted through the theme by that same
probe; a fresh browser capture was not re-run (frozen reference, outside this wave's engine
scope). The three colours UIR-06 had measured nowhere — `nav_bg`, `caption_shadow`,
`poster_fade` — were added to the theme palette for the menu, each from its own reference
line. UIR-07 (`MenuScreen`) is `done` with both acceptance runs green
(`screen_menu_audit` 95/95, 96/96 `--demo`; zero script errors; the literal scan reads the
screen: 12 files, 0 offenders) — evidence in `evidence/uir-07-screen-menu.log` and the
integration journal. `ui-menu.png` is pending UIR-24's harness, and the wave's deviations
(theme palette rows, `DemoGateAdapter.badge_text_key_for`, the two viewport rules in the
screen) are recorded in the screen's evidence log. UIR-09 (mount) is now the next ticket on
this path; GATE-A remains unstarted. The foundation audits were re-run, not trusted: router
86/86, adapters 131/131 + 134/134, input/a11y 117/117, reachability 21/21, and the full
baseline (8 suites) green *after* the menu landed.

Pre-gate-a closeout (2026-09-17, before GATE-A; single writer, no merge while changes were in
flight): UIR-07's recorded caption defect is closed — the caption box is re-derived from the
poster (`MenuScreen._apply_caption_fit()`, design 378 px kept as a ceiling) and a second
caption defect found while measuring it (text top-aligned in a 92 px box: glyphs 52 px above
the poster's bottom edge where the reference measures 24 px) is fixed with the scene's
`alignment = 2` — `screen_menu_audit` 97/97 (98/98 `--demo`) now asserts containment, the
declared insets, the poster-vs-column width and the text-bottom-hug at 1280x720 and 1024x600.
UIR-08's implementation has its acceptance run: the wave-3 independent review's six findings
are reconciled in source and in tests (window pinned at 52 %, combo glow and tactic flash
rendered through theme-owned values, AI coral, the row's 134.52/8 geometry, the timer ball)
and `hud_audit` is `PASS 172/172`, 0 SCRIPT ERRORs. UIR-24's harness and audits run
`PASS 76/76` (was `FAIL 73/76`) at four sizes and the captures were regenerated for real
(menu 1152x648/1024x600/1280x720, HUD 1152x648/1024x600/1280x720; the before-set is preserved
outside the tree). The full sweep — 19 runs, one engine at a time — is exit 0 with 0 SCRIPT
ERROR lines in every run. Evidence: `evidence/uir-pre-gate-a-closeout.md`, `-suite.log`,
`-menu-audit.log`, `-hud-audit.log`, `-legibility.log`, `-captures.log`. Row flips for
UIR-08/09/24 wait for the coordinator's next dispatch (that wave also reconciles the brother
branch's `match_controller`/HUD timing cues and runs the combined gates); GATE-A has not run —
no look/feel verdict exists anywhere in this wave.

Pull wave (2026-09-17; integration lane, single writer, **nothing pushed**): the UI-recreation
wave is checkpointed at `249d55a` (246 files, explicit pathspecs) and the brother branch
(`codex/gameplay-and-map` tip `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590`) is merged at
`c6837b2` — normal merge, 0 conflicts, `match_controller.gd` byte-identical to the frozen
probe. Combined sweep on an isolated copy: 17 runs green (brother's court 1111 / shot-parity
675/675 / timing 100/100 / switch 85/85; UI audits menu 97/97 + 98/98, HUD 172/172,
legibility 76/76, router, theme, fonts, data, input-a11y, reachability all green; the timing
negative control fails by design). The branch's slice rewrite had silently dropped main-line
assertions — the nine-arena artwork set, the demo guards and the whole music seam — and is
reconciled in the pull wave's final commit (see `evidence/uir-branch-pull-journal.md` §7);
one deliberate red remains, the branch's own `padel.pck` pack check, which needs an exported
pack on the gate host. Real-GPU captures (Metal) of the merged tree re-ran in the isolated
copy including the branch's new `timing`/`timing-off` shots. Evidence:
`evidence/uir-pull-wave/`. Rows are the coordinator's to flip; GATE-A remains Luca's and
unstarted.

Post-pull correction and GATE-A preparation (2026-09-17, docs-only; read-only git, no engine, $0;
delegated verification subagent): the merge's provenance was re-verified independently of the merge
report — `c6837b2`'s parents are `249d55a` + `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590`, `a1e10f04`
is an ancestor of `HEAD c9470e2`, the court files at `HEAD` are byte-identical to `a1e10f04` (only
three engine-generated `.import` sidecars differ), and every frozen pin re-hashes to its recorded
value (`court.gd 844891ea…`, `hud.gd 883b8ff5…`, `match_controller.gd a0f56fec…` — the probe
sample, `project.godot 3aef17de…`). Remote unchanged, nothing pushed. With the closeout's acceptance
runs and the pull wave's combined sweep behind them, **UIR-08 and UIR-09 move to `done`**;
**UIR-24 is recorded `in-progress` (partial)** — its harness and legibility audit have landed and
re-run green (`PASS 76/76` at four sizes, harness `PASS 5/5`), but its coverage grows as screens
register, so it is not `done` until the screen set lands (UIR-10–UIR-21). GATE-A itself stays
unstarted and unclaimed: the handoff pack (before/after image pairs with hashes, the judgement list,
the open items) is published at `board-gate-a.md` and `gate-a-review/` — the verdict is Luca's
alone. The 2752-era review's "court/camera untouched" rows are historical (`2752d9a2` only) and are
superseded by `a1e10f0`. Ticket frontmatter for the flipped rows is the coordinator's to update —
this pass edited the board only. (Done in the closeout note below.)

Post-pull closeout (2026-09-17, single engine owner; local only, **nothing pushed**): the open
engine-lane item — a post-merge 1280×720 prototype-HUD capture — landed. The documented command
(`Match.tscn -- --ui=new --capture=match --tier=3 --seed=20260916 --resolution 1280x720`) ran on the
merged tip `3238a50` in the real checkout: exit 0, 0 SCRIPT ERRORs, one named shutdown allowance,
seven frames at 1280×720; `godot/game/out/` was snapshotted first and restored byte-identical
(104/104 files, git status unchanged — the merge's stale plan-lane renders were restored, not
repaired). Durable copies: `gate-a-review/pairs/hud-after-prototype-{serve,hud,rally}-1280x720.png`
and the composed sheet `gate-a-review/sheets/hud-before-after-1280x720.png`; transcript
`evidence/uir-gate-a-hud-1280x720-capture.log`. With it, **the ticket frontmatter for UIR-08/UIR-09
(`done`) and UIR-24 (`in-progress`, partial) is reconciled with this board, and the pack README's
`approved` flag reads `true`** — implementation approval from Luca's request, as this board already
records; GATE-A, the product-scope decision and `luca-final` stay open and unclaimed. The
assessment re-run on the reconciled tree parses 28/28 tickets with zero board divergences
(`gate-a-review/ticket-status-assessment.txt`). Still open for the coordinator: the UIR-09/UIR-22
slice line anchors. The push decision remains Luca's; nothing is pushed.

## Tickets

| Ticket | Title | State | Readiness | Blocked by | Gates | Owner role | Evidence |
|---|---|---|---|---|---|---|---|
| UIR-00 | Baseline freeze and evidence register | done | potential | (plan-approval only) | plan-approval | coordinator | `uir-00-baseline-gates.log` + `uir-00-before-set.md` |
| UIR-01 | UI asset acquisition and import | done | potential | (plan-approval only) | plan-approval | asset worker | `uir-01-assets.md` |
| UIR-02 | Theme resource from styles.css tokens | done | potential | UIR-01 | plan-approval | visual-foundation worker | `uir-02-theme-probe.log` |
| UIR-03 | Screen router and shared UI contracts | done | potential | (plan-approval only) | plan-approval | shared-ui worker | `uir-03-router-audit.log` |
| UIR-04 | UI data adapters | done | potential | UIR-03 | plan-approval | contract/adapters worker | `uir-04-adapters-audit.log` |
| UIR-05 | Input, focus and accessibility contract | done | potential | UIR-03 | plan-approval | input/a11y worker | `uir-05-input-a11y-audit.log` |
| UIR-06 | Reference computed-style capture | done | potential | (plan-approval only) | plan-approval | web-evidence worker | `uir-06-computed-styles.md/.json` |
| UIR-07 | MenuScreen 1:1 (GATE-A prototype) | done | potential | UIR-02, 03, 04, 05, 06 | plan-approval | screen worker | `uir-07-screen-menu.log` |
| UIR-08 | In-match HUD 1:1 (GATE-A prototype) | done | potential | UIR-02, 03, 04, 05, 06 | plan-approval | screen worker | `uir-08-hud-audit.log` (implementation register) + `uir-pre-gate-a-hud-audit.log` (**PASS 172/172**, 0 SCRIPT ERRORs) + merged-tree re-run `ui-hud-audit PASS 172/172` in `uir-pull-wave/sweep-results.txt` |
| UIR-09 | Prototype mount | done | potential | UIR-07, UIR-08 | plan-approval | integration owner | `uir-09-prototype-mount.md` + `uir-pre-gate-a-captures.log` (11 real capture runs) + `uir-pull-wave/captures.log` (merged-tip re-capture); GATE-A brief completed by `board-gate-a.md` |
| GATE-A | Luca verdict on prototype approach | passed-by-owner | external | UIR-09 | luca | Luca | owner approved the approach and the remaining screens 2026-09-17 ("All approved let's go finalize this, so I can play-test the game with the current devs", recorded in `handoff-20260917-121721-ui-recreation-finalize.md`); no agent certifies the look/feel — that verdict is the owner's play-test |
| UIR-10 | ModesScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-10-screen-modes.log` + finalize closure `PASS 118/118` |
| UIR-11 | CharactersScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-11-screen-characters.log` + finalize closure `PASS 148/148` |
| UIR-12 | ArenaScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-12-screen-arena.log` + finalize closure `PASS 133/133` |
| UIR-13 | HelpScreen 1:1 + ControlLegend | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-13-screen-help.log` + finalize closure `PASS 91/91` |
| UIR-14 | HistoryScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-14-screen-history.log` + finalize closure `PASS 56/56` |
| UIR-15 | ChallengesScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-15-screen-challenges.log` + finalize closure `PASS 73/73` |
| UIR-16 | ProfileScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-16-screen-profile.log` + finalize closure `PASS 74/74` |
| UIR-17 | FeedbackScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-17-screen-feedback.log` + finalize closure `PASS 119/119` |
| UIR-18 | DrillScreen 1:1 | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-18-screen-drill.log` + finalize closure `PASS 89/89` |
| UIR-19 | SettingsScreen 1:1 + SettingsRows | done | potential | UIR-02..06, UIR-09 | + gate-a | screen worker | `uir-19-screen-settings.log` + finalize closure `PASS 91/91` |
| UIR-20 | Pause overlay, replay entry, smash tutorial | done | potential | UIR-02..08, 13, 19 | + gate-a | screen worker | `uir-20-overlays.log` (hash rows re-computed to the closure state) + finalize closure `PASS 176/176`; the replay entry's flag split (`set_replay_available`) landed with UIR-27 |
| UIR-21 | ResultScreen 1:1 | done | potential | UIR-02..05, 07, 08 | + gate-a | screen worker | `uir-21-screen-result.log` + finalize closure `PASS 176/176` |
| UIR-22 | Full integration | done | potential | UIR-03, UIR-07, UIR-08, UIR-09, UIR-10-21 | + gate-a | integration owner | `uir-22-integration.log` + `uir-22-integration-journal.md` + finalize closure `PASS 71/71` + `uir_route_audit PASS 44/44` + slice `PASS 342/342` (demo `293/293`) |
| UIR-23 | Demo and beta content matrix | done | potential | UIR-04, 10, 11, 12, 21 | + gate-a | verification worker | `uir-23-demo-matrix.md` + `.log` — full `PASS 133/133`, demo `PASS 178/178`, exit 0, 0 `SCRIPT ERROR` (release captain, 2026-09-17; beta column `not_ported`, recorded) |
| UIR-24 | Capture harness + legibility audit | done | potential | UIR-03, UIR-09 | + gate-a | verification worker | `uir-24-capture.log` + `uir-24-legibility.log` + finalize closure `PASS 664/664` (the audit's background resolution corrected against the page base; the real opaque-fill defects fixed in the source) |
| UIR-25 | Final regression and Luca acceptance | blocked | potential | UIR-22, 23, 24, 27 (+ UIR-26 conditional) | + gate-a; closes on luca-final | coordinator + Luca | `uir-25-final.md` |
| UIR-26 | OSK visual grid and touch layer | done | external | product-scope decision | product-scope-and-platforms | screen worker (after decision) | `uir-26-osk-touch.md` (§11 closure; `OskPanel.gd`/audit fixes in `evidence/uir-finalize/runs-small-gates/`) + finalize closure `PASS 177/177` |
| UIR-27 | Replay point (buffer + overlay) | done | potential | UIR-20, 22 | + gate-a | integration + screen pair | `uir-27-replay.log` (§12 closure: seam executed, pause flag split picked and wired) + finalize closure `PASS 166/166` |


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
- The wired card entry, executed (not one of the 32): `_probe_replay_card.gd` on the real MOUNTED
  card — gate off with its reason before any frames, the pause echo + availability feed, the real
  `ReplayButton`'s press → `start_replay()` (card hides, pause lifts), `stop_replay()` → pause
  restored, card back on MATCH — **PASS 18/18**, 0 `SCRIPT ERROR`; log
  `evidence/uir-finalize/scripts/probe-replay-card.log`, script preserved beside it (project root
  copy stays re-runnable; the manifest digest was re-checked after the probe: stable).
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

## UIR-23 closure (2026-09-17, release captain; acceptance executed, local only)

`demo_matrix_audit.gd` written (UIR-23's own file, mounts the playable host read-only through the
router) and the ticket's two acceptance commands run serially, `pgrep -x Godot` empty before each:
full `PASS 133/133`, demo (`-- --demo`) `PASS 178/178`, both exit 0 with 0 `SCRIPT ERROR` and no
engine `ERROR:` lines. Matrix table with per-cell evidence: `evidence/uir-23-demo-matrix.md`;
both transcripts: `evidence/uir-23-demo-matrix.log`; beta column `not_ported` (no beta build in
the port today — `BuildFlag.gd` is one boolean), never emulated. Findings handed back, not
patched: the `storeFollow` locale gap (already recorded by UIR-21) and `ArenaScreen.gd:10-11`'s
stale "no arena carries an `unlock`" prose (UIR-12's file). The finalize manifest (32 runs) is
unchanged; `evidence/uir-finalize/sweep.py`'s `RUNS` list now carries the two UIR-23 runs for the
next full sweep.

## Claim protocol

1. Pick a row with `state: ready`. If it is `blocked` or `in-progress`, do not start it.
2. Request the claim from the coordinator (message: ticket id, your handle, today's date). Do not edit this file; the coordinator is its only writer.
3. Wait for the acknowledgement: the row reads `in-progress` with your handle and date. The acknowledgement is what holds the ticket against another worker; a request is not a claim.
4. Read the ticket in full, including its write allowlist. If you need a file outside the allowlist, stop and hand back a blocker naming the file and the owner instead of editing it.
5. Run acceptance through the coordinator's engine queue (or hold the guard yourself: `/tmp/padel-godot.lock.d`, one engine process at a time across the whole checkout; there is no `flock` on this Mac; stale guards are recovered by the coordinator only).
6. Hand back: evidence paths, exact commands, exit codes, tallies, open items. The coordinator flips the row to `done` and updates dependents to `ready`.
7. A red suite or a failed assertion is reported, never worked around.

## Coordinator duties

- Sole writer of this board, `README.md` and `FEATURE-MATRIX.md`; records every claim request, acknowledgement, hand-back and status change here (workers never edit rows; the acknowledgement row is what holds a ticket against another worker).
- Runs or schedules the engine queue (all tests and all captures) serially; keeps the one-engine-at-a-time rule and owns stale-guard recovery.
- Flips tickets to `ready` as blockers land; records GATE-A, the product-scope decision and Luca's final verdict verbatim (no paraphrase).
- Reconciles cross-ticket findings (for example a screen disagreeing with the demo matrix) by assigning the fix to the owning ticket.
- Updates `README.md`'s baseline table only with real re-measurements, labeled as such; keeps UIR-25's phase A (evidence preparation) separate from its `luca-final` closing gate.

## Standings

- Tickets done: **27 of 28** (UIR-00–UIR-24, UIR-26, UIR-27) — UIR-00..UIR-22, UIR-24, UIR-26,
  UIR-27 recomputed from the ticket frontmatter against the finalize closure's engine record
  (`evidence/uir-finalize/ui-audit-sweep.json`) on 2026-09-17, plus UIR-23 on its own executed
  acceptance (full `PASS 133/133`, demo `PASS 178/178`, 2026-09-17 release captain); a ticket is
  `done` only when the audit that is its arbiter exited 0 with no `FAIL` line and 0 `SCRIPT ERROR`.
- Ready: **0** — UIR-23 closed on its executed acceptance (2026-09-17).
- Blocked: **1** — UIR-25 (final regression + Luca acceptance; closes on `luca-final`).
- Gates: plan-approval — implementation approved by Luca's request (`CHARTER.md`; `LOG.md:4`); the
  pack README's flag is `approved: true`. **GATE-A passed-by-owner** 2026-09-17 (the owner's
  "All approved let's go finalize this, so I can play-test the game with the current devs", recorded
  in the finalize handoff) — the look/feel verdict itself is the owner's play-test and no agent
  certifies it. `product-scope-and-platforms`: the touch/OSK direction was approved in the same
  request; UIR-26 is `done` on its green audit, with the device pass recorded as owed
  (`not_ported`, §5/§11 of `uir-26-osk-touch.md`). `luca-final` OPEN.
- Nothing here self-certifies.
