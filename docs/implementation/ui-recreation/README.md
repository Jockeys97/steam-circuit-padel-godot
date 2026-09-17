---
pack: ui-recreation
repo: steam-circuit-padel-godot
status: awaiting-plan-approval
approved: false
approved_by: null
created: 2026-09-16
created_by: hermes (dev-work profile), from handoff + two scout passes
repo_head_at_authoring: 74195c4
engine: 4.7.2.stable.official.ed1daf0bf
gates: [plan-approval, gate-a, product-scope-and-platforms]
closing_gate: luca-final
tickets: 28
screens: 13
---

# UI recreation plan: the web build's interface, 1:1 in Godot

## What this is

The plan and ticket pack for recreating the frozen web build's interface, all 13 screens, inside the Godot port, keeping the port's live 3D court as the in-match view. The definition of done for the whole effort is Luca's: he looks at the running build and says whether it is the same interface. Nothing in this pack claims that verdict.

This document is the entry point. Everything else lives here:

| File | What it holds |
|---|---|
| `README.md` | this plan: scope, verified facts, decisions, gates, DAG, coordination rules, command reference |
| `BOARD.md` | live status board, claim protocol, coordinator duties |
| `FEATURE-MATRIX.md` | every screen, state and cross-cutting feature traced to its ticket, acceptance command and evidence path |
| `VALIDATION.md` | structural validation of this pack: DAG, ownership, links (script embedded; rerunnable) |
| `tickets/UIR-00..UIR-27` | one self-contained ticket per unit of work, machine-readable frontmatter included |
| `evidence/` | evidence files written by tickets (created on first hand-back) |

The plan entrypoint lives in the workspace plans directory, outside the repo: `/Users/lucafantini/.hermes/plans/2026-09-16_225600-ui-recreation-plan.md`; it points here. No files were added to the repo outside `docs/implementation/ui-recreation/`.

## The goal, in Luca's terms

"Recreate the 2D UI 1:1 in Godot, with some 3D flair." Working interpretation, recorded at handoff and kept here:

- The web build's screen inventory (13 screens), chrome, type, palette, panel language, demo-lock treatment and behavior are reproduced from the frozen reference (`index.html`, `styles.css`, `js/**`), which is read-only.
- The in-match HUD sits over the port's live 3D court instead of over the 2D canvas. The 3D court is the port's own verified asset; the HUD is recreated.
- What "3D flair" means beyond that (depth, transitions, tilt) is NOT decided here. It is a question for GATE-A, alongside the visual verdict. No agent decides it silently; no invented animation ships under its name.

## Frozen reference and frozen files

Read-only during the entire effort, permanently:

- `index.html`, `styles.css`, `js/**` (the parity reference)
- `godot/src/sim/**` (the verified simulation core)
- `godot/src/locale/**`, `godot/src/save/**`, `godot/src/modes/**` (seams other lanes own; this pack wraps them, never edits them)
- `godot/src/input/nav_routes.gd` (a generated inventory; a byte edit fails its own `--verify`)
- `godot/project.godot` `run/main_scene` stays `res://tests/SmokeTest.tscn`; only UIR-22 adds a `[display]` block, nothing else
- `docs/implementation/PLAN.md` and the existing S4 ticket `docs/implementation/tickets/hud-and-menu.md` are not edited; the pack supersedes S4's scope by building all 13 screens, and treats S4 as one of its contracts

## Verified ground truth (checked against the repository on 2026-09-16, not copied from the handoff)

- Exactly 13 screens. Registry: `js/ui.js:444-458`. Markup anchors: `screen-menu:31`, `screen-characters:90`, `screen-modes:103`, `screen-arena:157`, `screen-help:181`, `screen-history:268`, `screen-challenges:281`, `screen-profile:293`, `screen-feedback:310`, `screen-drill:366`, `screen-settings:399`, `screen-game:445`, `screen-result:539`. Overlays (pause, smash tutorial, OSK, asset loading, action deck, event log, replay) are not screens and do not inflate the count.
- Route graph and declared back targets: `godot/src/input/nav_routes.gd` generated block; menu/game/result declare no back; result carries `to-menu`.
- No design layer exists in the port: zero font files in the repo, no theme resource (only `.tres` is `godot/assets/audio/padel_audio_bus.tres`), no `godot/src/ui/` at all. Colors are per-node overrides in `godot/game/main_menu.gd:83-264` and `godot/game/hud.gd:100-345`.
- The handoff's line anchors for `js/ui.js` are stale and are corrected in this pack: `showResult` is at `:1488` (not 1477), `renderAthletes` at `:846` (not 837), `renderArenas` at `:1220` (not 1209), `updateHud` at `:1276` (not 1265), `renderChallenges` at `:1125`, `renderMatchStats` at `:1386`, `renderObjectives` at `:1433`, `renderHistory` at `:1574`, `renderProfile` at `:1608`. The S4 ticket's own anchors are four to eleven lines stale; tickets here cite the verified numbers.
- `--pink` is used at `styles.css:473` (`--mode-accent: var(--pink)` on the career card) and is NOT defined in `:root`. Browsers resolve this as invalid-at-computed-value-time; the exact rendered result is unknown and is measured by UIR-06 before anything copies it.
- macOS reality check on the scout commands: `flock`, `xvfb-run`, `timeout` and `gtimeout` are all ABSENT on this Mac (`command -v` returns nothing; no Homebrew stash either). The handoff's claim that "flock works on macOS" is wrong for this machine. All ticket commands therefore come in two labeled forms: native macOS (serialized by the coordinator's lock protocol) and Linux CI (the existing `run.sh` shape). Scouting-and-arrow commands are marked PROPOSED where this session did not run them.
- Window capture of a running Godot window does not work on this Mac (`screencapture -l` refuses, `cua-driver` times out; recorded in `docs/wayfinder/evidence/local-macos-gate-sweep.md`). The in-engine `--capture=` path is the only frame evidence here. The captures on disk carry a 2026-09-16 19:14-19:21 regeneration (handoff line 64; mtimes agree), but the exact host and command of that run are not recorded, so the native capture command in this pack (run.sh's shape minus `xvfb`/`flock`/`timeout`, keeping `--rendering-driver opengl3`) is PROPOSED and is validated on first use in UIR-24.
- The OSK is NOT absent in the port: `godot/src/input/osk.gd` is a complete model (rows, shift, insert/delete/done, focus hand-off) wired into `menu_nav.gd` and audited by `godot/tests/input/gamepad_nav_audit.gd` (`nav/osk_*`). What does not exist is the VISUAL grid; the product decision (`product-scope-and-platforms`) gates it. Scout phrasing "OSK unsupported" is refined, not repeated.
- The demo gate is real and wired: `godot/game/content_gate.gd` over `godot/tests/build/**` (`BuildFlag`, `DemoContent`, `ContentFilter`), ported from `js/build.js`. Screens consume it through UIR-04's adapter; no screen re-derives demo rules.
- Pause is not `SceneTree.paused`: `match_controller.gd` owns `_paused`, `is_paused()`, and `_reset_transient_input()` on both edges (`:1080-1113`). There is NO `set_match_paused(bool)` today; UIR-22 introduces it as a NEW seam and UIR-20 consumes it.

## Baseline numbers (historical, NOT re-run in the planning session)

Recorded for comparison only. UIR-00 re-measures them on this machine; differences get recorded, not repaired.

| Suite | Last recorded | Source | Notes |
|---|---|---|---|
| harness | PASS 8/8, exit 0 | LOG tick 19 / macOS sweep | reproduces on this Mac |
| slice, full | 280 checks (post-fix handoff) | LOG tick 19; handoff | fresh clone without the gitignored pack reads 278 (two pack checks skip) |
| slice, demo | 229 checks (post-fix handoff) | LOG tick 19; handoff | pre-`42aafa5` this was structurally red (four demo-guard failures; see macOS sweep evidence) |
| input | PASS 4/4, 308 checks, 7 not-ported | macOS sweep | reproduces exactly |
| rules audits | PASS 10/10, 221 checks | macOS sweep | reproduces exactly |
| saves + Steam seam | PASS 137/137 | macOS sweep | reproduces exactly |
| music port | 32/32 claimed; measured FAIL 30/32 on the sweep commit | handoff vs sweep | provenance hash mismatch was fixed by `42aafa5` per its message; confirm in UIR-00 |
| UI captures | `godot/game/out/*.png` (20 files) | `ls -lT` 2026-09-16 | menu/hud/rally/quickmatch-serve/result at 19:14, arena-* at 19:21, the rest 18:08 |

## Gates (all open; nothing in this pack bypasses one)

| Gate | Owner | What it blocks | Where |
|---|---|---|---|
| plan-approval | Luca | mass implementation; every ticket carries `gates: [plan-approval]` and `plan_approved: false` | this file, frontmatter |
| GATE-A: menu + HUD approach verdict | Luca (HITL) | all remaining screens (UIR-10 through UIR-21), described below; UIR-09 prepares the verdict, the verdict never blocks that preparation | `docs/wayfinder/tickets/ui-port-approach.md`, same question |
| product-scope-and-platforms | Luca | UIR-26 (OSK visual + touch) and UIR-25's closing disposition for it (landed, or the decision quoted as a scope exception); everything else proceeds with desktop keyboard/pad | `docs/wayfinder/tickets/product-scope-and-platforms.md` |
| luca-final | Luca | UIR-25's closing only (its `closing_gate`); UIR-25's execution and evidence preparation (phase A) runs under plan-approval + gate-a and never waits on this gate | UIR-25 |

GATE-A in one paragraph: UIR-07 (menu) and UIR-08 (HUD) are built as representative prototypes and mounted by UIR-09; Luca gets before/after capture pairs at 1280x720 plus a running window with the documented seed/tier; he answers the approach question (readable type, semantic color, no overflow) and, if he wants, the "3D flair" interpretation. Only after that do the mass screens start. If he rejects the approach, the pack is re-scoped, not pushed through: the wayfinder ticket says exactly that. The verdict gates what follows the prototype, never the preparation of the prototype evidence: UIR-09 mounts and captures before the verdict exists, by design.

## DAG (blockers first; numbers are dependency-ordered)

```
UIR-00 baseline   UIR-01 assets   UIR-03 router   UIR-06 computed styles   (parallel starts)
  UIR-02 theme (needs 01, 06)     UIR-04 adapters (needs 03)     UIR-05 input/a11y (needs 03)
    UIR-07 menu (needs 02-06)     UIR-08 HUD (needs 02-06)
      UIR-09 prototype mount (needs 07, 08)  ->  GATE-A (prototype verdict)
        UIR-10, UIR-11, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-21
          (need 02-05 + 07; UIR-21 also needs 08, which landed with the prototype)
          UIR-12 arena (also needs UIR-11)
          UIR-20 overlays (also needs UIR-13, UIR-19, UIR-08)
        UIR-22 integration (needs 03, 07-21, 09; after GATE-A)
          UIR-27 replay (needs 20 + 22)
          UIR-23 demo matrix (needs 04, 10, 11, 12, 21)
          UIR-24 capture harness (needs 03, 09; starts early, grows as screens land)
            UIR-25 final + Luca acceptance (needs 22, 23, 24, 27;
              phase A under plan-approval + gate-a; closes on luca-final)
UIR-26 OSK/touch (external: product-scope decision; UIR-25's conditional blocker:
  landed, or the decision recorded verbatim as the scope exception)
```

Frontmatter is the machine-readable truth: `blocked_by` lists direct ticket blockers (the graph is acyclic; every `blocks` list is the exact reverse of `blocked_by`, checked in `VALIDATION.md`); `gates` lists the human gates that must pass before the ticket starts; `closing_gate` (UIR-25 only) is the human gate that applies to the ticket's closure and never to the preparation of its evidence; `conditional_blocked_by` (UIR-25 only) names the ticket that must be resolved, as built or as a recorded decision, before UIR-25 closes; `readiness` distinguishes `potential` (ready once blockers and approvals land) from `external` (waits on a decision outside the pack).

The DAG above is the authority, and not every "parallel" ticket is independent: within UIR-10 through UIR-21, UIR-12 waits on UIR-11 and UIR-20 waits on UIR-13 and UIR-19; UIR-25 waits on UIR-27's replay as well as UIR-22/23/24. The board's waves follow this order.

## The 13 screens and their tickets

| # | Screen | Markup anchor | Ticket(s) |
|---|---|---|---|
| 1 | menu | `index.html:31` | UIR-07 (GATE-A prototype) |
| 2 | characters | `index.html:90` | UIR-11 |
| 3 | modes | `index.html:103` | UIR-10 |
| 4 | arena | `index.html:157` | UIR-12 |
| 5 | help | `index.html:181` | UIR-13 |
| 6 | history | `index.html:268` | UIR-14 |
| 7 | challenges | `index.html:281` | UIR-15 |
| 8 | profile | `index.html:293` | UIR-16 |
| 9 | feedback | `index.html:310` | UIR-17 |
| 10 | drill | `index.html:366` | UIR-18 |
| 11 | settings | `index.html:399` | UIR-19 |
| 12 | game | `index.html:445` | UIR-08 (HUD, GATE-A prototype) + UIR-20 (pause/tutorial) + UIR-27 (replay) + UIR-26 (touch layer, external) |
| 13 | result | `index.html:539` | UIR-21 |

Cross-cutting tickets: UIR-00 baseline, UIR-01 assets, UIR-02 theme, UIR-03 router, UIR-04 adapters, UIR-05 input/a11y, UIR-06 computed styles, UIR-09 prototype mount, UIR-22 integration, UIR-23 demo matrix, UIR-24 captures, UIR-25 final.

## Async work without collisions

The pack is written so N workers run in parallel with no shared-file fights. The rules:

1. One writer per file, always. Every ticket's write allowlist is exclusive; the allowlists live in the tickets, and every path two tickets share has an explicit order: `godot/game/**` is UIR-09, then UIR-22, then UIR-27's buffer half; `godot/src/ui/ScreenRouter.gd` is UIR-03, then (only) UIR-22 under the freeze note; `godot/tests/game_slice_test.gd` is UIR-22, plus UIR-27's `r`-key assertion if the slice encodes the retired behavior. If a worker needs a change outside its allowlist, it hands back a blocker naming the exact file and method, and the owner does it.
2. The router (`godot/src/ui/ScreenRouter.gd`) freezes when UIR-03 lands. Screens register themselves; nobody edits the router. The only later writer is the integration owner (UIR-22) or a coordinator-approved change.
3. Shared components have named owners: `ControlLegend.gd` is UIR-13's, `SettingsRows.gd` is UIR-19's, `Hud.gd`/`ViewState.gd` are UIR-08's. Consumers import, never edit.
4. Tests are per-ticket: each screen and overlay ticket owns its audit file (`screen_<id>_audit.gd/.tscn`, `hud_audit.gd`, `pause_audit.gd`, `replay_audit.gd`) and nothing else touches it. The shared `game_slice_test.gd` is touched only by UIR-22 under its reconciliation rule, and by UIR-27 for the `r`-key assertion if the slice encodes the retired behavior (cited in its log). `.uid` sidecars belong to the ticket that creates the script; `.import` sidecars under `godot/assets/ui/**` belong to UIR-01.
5. Captures: `godot/game/out/ui-*.png` is UIR-24's namespace; `ui-prototype-*.png` is UIR-09's; the pre-existing PNGs are read-only "before" evidence. A screen's captures are producible as soon as that screen ticket lands: a screen ticket never waits on UIR-24, and UIR-24 never waits on a screen.
6. `godot/game/**` and `godot/project.godot` have exactly one writer: the integration owner ticket in flight, in order UIR-09, then UIR-22, then UIR-27. Each lands fully before the next starts (that order is in the DAG too: UIR-22 is blocked by UIR-09, UIR-27 is blocked by UIR-22).
7. Engine processes are serial across the whole checkout. On this Mac there is no `flock`; the coordinator runs the engine queue (all tests and all captures, one process at a time) and a worker that runs its own engine command holds the guard below. Worker hand-backs state which commands they need run if they cannot hold the guard themselves.

Engine guard and stale-lock recovery (PROPOSED; no lock binary exists on this Mac):

```bash
LOCK=/tmp/padel-godot.lock.d
# acquire (coordinator queue first; this guard is the belt-and-braces check)
until mkdir "$LOCK" 2>/dev/null; do
  pid=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    echo "stale engine guard (pid $pid is dead); coordinator must recover $LOCK" >&2
    exit 2
  fi
  sleep 5
done
echo $$ > "$LOCK/pid"
trap 'rm -f "$LOCK/pid"; rmdir "$LOCK"' EXIT
# ... run engine commands, one process at a time ...
```

The guard directory is not a lock primitive this Mac provides, so a killed process can leave it behind. Recovery is coordinator-only and manual: remove `$LOCK` (after `rm -f "$LOCK/pid"`) only when `pgrep -f Godot` shows no engine running, and note the recovery on the board. Never `rm -rf` a guard a live process may hold, and never auto-remove a stale guard from a waiting worker (a racer can delete a fresh guard).

The Linux host keeps using the existing `flock -w 900 /tmp/padel-godot.lock` shape from `godot/game/run.sh`; do not port that command to the Mac unchanged (it cannot run).

## Command reference

Native macOS (works here; serialized):

```bash
export REPO=/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd "$REPO"

# gates
"$GODOT" --headless --path godot/                                                  # harness
"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd          # slice full
"$GODOT" --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo
"$GODOT" --headless --path godot/ --script res://tests/input/run_all.gd
"$GODOT" --headless --path godot/ --script res://tests/audits/run_all.gd
"$GODOT" --headless --path godot/ --script res://tests/modes/run_all.gd
"$GODOT" --headless --path godot/ --script res://tests/save_steam_test.gd

# play (real Metal context, per the macOS sweep evidence)
"$GODOT" --path godot res://game/Main.tscn -- --seed=20260916 --tier=3 --camera=default

# captures (PROPOSED-MAC: run.sh's xvfb/flock wrapper does not exist here; keeps run.sh's --rendering-driver opengl3 because the dummy driver captures blank frames; validate on first use and record the exact command that worked)
"$GODOT" --rendering-driver opengl3 --path godot res://game/Main.tscn  -- --capture=menu
"$GODOT" --rendering-driver opengl3 --path godot res://game/Match.tscn -- --capture=match --tier=3 --seed=20260916
```

Linux CI form (existing, host agents only): the same commands under `flock -w 900 /tmp/padel-godot.lock timeout N env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 <linux-godot>`, and the capture route with `xvfb-run -a -s "-screen 0 1280x720x24" --rendering-driver opengl3`. Never `--headless` for captures anywhere (dummy driver renders blank).

## Definitions

Definition of Ready (per ticket, all true before starting):

- All `blocked_by` tickets are done and recorded on the board; the ticket's `gates` are passed; the claim is acknowledged by the coordinator (BOARD claim protocol; the coordinator is the only writer of the board); the pack README and the ticket were read in full; write allowlist understood; the worker has the engine commands for its acceptance.

Definition of Done (per ticket, all true before hand-back):

- Acceptance commands run with recorded exit codes and tally lines; evidence files written to the exact paths in the allowlist; any constructed state (scripted rally, temp-dir save store, injected pad event, simulated seam failure) labeled as constructed in the evidence, with production seams exercised wherever they exist; `git status --short` reviewed and only allowlisted paths changed; no user-facing literal added anywhere; no frozen file touched; hand-back message names the commands, the tallies and every open item with its owning ticket.

## Evidence model

- Every claim comes with a rerunnable command plus a file. Logs capture command, exit code, tally and `SCRIPT ERROR` count.
- Constructed states are scaffolding, never evidence substitutes: if a run used a scripted rally, a temp-dir store, injected input or a simulated seam failure, the evidence says so where it appears; production seams are exercised wherever they exist.
- Captures are frame evidence only from the in-engine path; window grabs are impossible on this Mac and are not promised. A screen's captures are requested from UIR-24 through the coordinator's engine queue once the screen lands; until then the screen ticket records them as pending instead of blocking.
- Capture namespace: new UI captures live in `godot/game/out/ui-<screen>[-<state>].png` (UIR-24 owns the prefix, UIR-09 owns `ui-prototype-*`); the pre-existing PNGs are read-only before-evidence. S4 named `godot/shots/ui-*.png` and `docs/implementation/evidence/s4-capture.log`; this pack keeps captures where the real ones actually live and keeps its own evidence under this pack's `evidence/` directory, superseding S4 in conversation only.
- The no-self-certification rule stands for every visual claim: workers produce captures; Luca produces verdicts.

## Known unknowns carried explicitly

- `--pink` behavior (UIR-06 measures; UIR-02 and UIR-11 consume).
- "3D flair" interpretation (GATE-A question, Luca).
- Touch/OSK fate (product-scope ticket; UIR-26 blocked-external; UIR-25's close requires the disposition: UIR-26 landed, or the decision quoted verbatim as the scope exception).
- Replay buffer cost (UIR-27 measures; absent today by the match controller's own comment).
- The port's score-format storage for match length (UIR-10 records whether `Config` exposes it; if not, a blocker is filed rather than a new schema invented).
- Store URL for the result CTA (absent today; UIR-21 records "none configured" and the CTA stays hidden, which is the reference's own behavior when URLs are null).

## Capability gaps carried openly

The port does not have these today; each ticket's rules say how it proceeds without faking them:

| Missing today | Ticket | Rule |
|---|---|---|
| Browser measurement session (computed styles, reference PNGs) | UIR-06 | measured, or explicitly blocked-external; the manual browser + console snippet is the fallback; no estimate is presented as a measurement, and the visual chain holds behind it |
| Network endpoint for feedback delivery | UIR-17 | queue locally first; failure ladder honest; `sent` only through the seam's success path (test double), labeled as such; "none configured" recorded when absent |
| Store URL for the result CTA | UIR-21 | CTA stays hidden; the wishlist/follow wording logic is ready for a configured URL; "none configured" recorded |
| Replay buffer | UIR-27 | new bounded ring with the reference's semantics; the port's current `r`-restarts behavior is retired explicitly |
| Touch/OSK visual layer | UIR-26 | blocked on the product-scope decision; excluded only by a recorded decision, never silently |
| `[display]` stretch configuration | UIR-22 | added as a proposed block, verified against the running window, with the four-size legibility re-run |
| Window capture, `flock`, `xvfb-run`, `timeout` on this Mac | UIR-09, UIR-24, all | in-engine `--capture=` only; the native engine guard in this README; the Linux CI shape stays host-only |
| Pad-layout artwork seam, date localization helper, feedback diagnostics publisher, beta build flag | UIR-13, UIR-14, UIR-17, UIR-23 | where a seam is missing, the ticket records the gap as a blocker naming it; nothing is invented in its place |

## What this pack does not do

- It does not edit `docs/implementation/PLAN.md`, the S4 ticket, or any existing mission doc. S4's scope is superseded in conversation only; the file stays as written.
- It does not change simulation, locale, save or mode implementations, `project.godot`'s default scene, or the frozen web reference.
- It does not re-tune anything, add content, or invent design. Where the reference is silent, the pack records the gap instead of filling it.
- It does not claim any suite is green. The baseline numbers above are historical records from the mission logs, not measurements taken by this pack.
- It does not approve itself: `approved: false` until Luca says otherwise.

## How a worker starts

1. Read `BOARD.md` for the current frontier, the claim protocol and the engine guard.
2. Read this file and your ticket, in full.
3. Request the claim from the coordinator (ticket id, your handle, today's date). The coordinator is the only writer of the board: wait for the acknowledgement row (`in-progress`) before touching anything; if the row shows another holder, pick a different ticket.
4. Do the microsteps in order; run acceptance through the coordinator's engine queue (hold the guard if you run it yourself).
5. Hand back with the evidence paths and the tallies, then stop; the coordinator records `done` and updates dependents.

## How the coordinator works

- Owns `BOARD.md`, this README, and `FEATURE-MATRIX.md`; the only writer of those three files.
- Records every claim request, acknowledgement, hand-back and state change on the board; workers never edit rows (the board is the record; the acknowledgement is what serializes claims).
- Runs the engine queue (tests + captures) serially; other workers do not start engine processes without the guard, and stale-guard recovery is this role's (see the engine guard section).
- Updates ticket frontmatter `state`/`readiness` as the frontier moves; keeps the matrix's evidence column truthful.
- Records GATE-A, the product-scope decision and Luca's final verdict verbatim; never paraphrases a verdict.
