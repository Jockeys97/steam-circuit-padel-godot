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

## 3. Checkpoint commit (done)

- `249d55a` on `main` — *"feat(ui): checkpoint the UI-recreation wave — screens, HUD,
  router, theme, evidence, captures"*; **246 files, +51067/−4**, explicit pathspecs only
  (`git add -- <paths>`), staged count asserted == 246 before committing; never `git add -A`.
- Left untracked on purpose (preserved; verified absent from the index): `.hermes/`,
  `art/concepts/`, `art/generated/rackets/`, `meshy/**` (including the modified
  `meshy/README.md` and new `fornaio-*` views the live art lane wrote **during** this wave),
  `godot/game/arenas/art/*.webp.import` (arena lane), and `godot/game/out/mode-drill-screen.png`
  + `mode-quick-screen.png` (legacy `mode-*` capture namespace belongs to the mission lane per
  the reviewed partition; they are not in the UI register, so they are not in this commit).
- Freeze artifacts added this wave (no prep snapshot overwritten):
  `integration-prep/manifests/{local-status-final-precommit.txt, active-unstaged-FINAL.patch,
  frozen-hashes-precommit.txt}`.

## 4. Branch re-pin, delta review, merge

### 4a. Re-pin (live, executed)

| Fact | Value |
|---|---|
| `gh pr list --state all` | `[]` — still no PR |
| `refs/heads/codex/gameplay-and-map` | `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590` — matches the parent's live pin; the reviewed `2752d9a2` was **one commit stale** |
| `refs/heads/main` (remote) | `252ff6074039372ebbf8ec682f9adda0e9c80d03` — unchanged; local `main` now `249d55a` (checkpoint on top) |
| `git merge-base --is-ancestor 252ff60 origin/codex/gameplay-and-map` | **true** — branch descends from the split point; with the checkpoint on top, a real (non-ff) merge commit is the correct, non-destructive shape |

### 4b. Delta review — the one new commit

`2752d9a2..a1e10f04` = exactly one commit, *"feat: give the court its real 10 x 20 m, with
the simulation still in pixels"* — 4 files, +98/−29: `godot/game/court.gd`,
`godot/game/arenas/{arena_scenery,court_builder}.gd`, new `godot/tests/court_dimensions_test.gd`.
Everything else on the branch is byte-identical to the reviewed `2752d9a2`.

- Court projected to 10×20 m via a monotone C1 Hermite depth curve; net/service/back-glass
  pinned (visible service at 6.95 m == the sim's 126 px boundary; the new test asserts width,
  length, glass positions, service alignment, no velocity jump, and monotonicity over 1100
  samples). Cameras (`default`/`wide`/`playable`) re-aimed; near glass rail/posts dimmed and
  shadow-casting off; backdrop z −8 → −12.
- **Simulation stays in pixels** — `godot/src/**` untouched; frozen sim/save/locale/modes are
  still untouched by the branch at `a1e10f04` (verified against the diff, not assumed).
- Overlap with our checkpoint (`comm` of both change lists): **exactly
  `godot/game/match_controller.gd`** — same as the 2752d9a2 review; the court commit adds no
  new overlap. 64 branch files, 246 ours, intersection 1.
- Recorded consequence: the court/camera change alters the 3D match view. Neither the branch's
  own 11 tracked captures nor our `ui-hud-*` frames were rendered against it → §5.11 decides
  what, if anything, is re-captured this wave; no other lane's frames are touched.

### 4c. Frozen pre-merge probe (executed)

`git merge-file -p --diff3 local.gd base.gd branch.gd` on frozen versions — base
`252ff60:game/match_controller.gd` (1214 lines), local `249d55a:` (1273), branch `a1e10f04:`
(1959): **exit 0, 0 conflict hunks, 0 diff3 bases, merged 2018 lines** — the same shape as the
reviewed sample (local + 745). `godot/game/hud.gd` was clean at the checkpoint, so the branch's
`hud.gd` change applies without a text merge.

### 4d. The merge itself

Executed next (recorded in the appended section once done): `git merge
a1e10f04f9896de6ebbaff3e29f6d2c0dba77590` from `main` on top of the checkpoint — normal,
non-destructive, no force/reset/stash/rebase, merge commit message records the pin. Nothing is
pushed.

## 5. The merge and its semantic verification (done)

- `git merge a1e10f04f9896de6ebbaff3e29f6d2c0dba77590` → merge commit **`c6837b2`** on
  `main`: auto-merge, **0 conflicts**, 64 branch files landed (no Godot process was running;
  single-writer kept).
- `godot/game/match_controller.gd` after the merge is **byte-identical to the frozen probe
  output** (sha256 `a0f56fec…`) — the probe's shape was not re-derived, it was checked.
  Both sides' symbols present; the four lines a junction diff flagged as "removed" are
  branch-side edits (MATCH_START print, input latch, capture plan), not our mount.
- Mount seam intact: `src/ui`, `UI_HUD`, `ui_hud`, `_refresh_ui`, `_on_ui*` all present;
  `ui_accept`/`ui_cancel` blocks byte-identical across merged/main/branch
  (`check_input_blocks.py`).
- `godot/src/**` untouched by the branch; frozen sim/save/locale/modes unchanged by either
  side; the court commit is presentation-only (re-read, not assumed).

## 6. Combined verification sweep (done — evidence/uir-pull-wave/)

Isolated rsync copy of the merged tree (`/tmp/padel-uir-pull-20260917/repo`, 833 files
verified identical), one engine at a time (`pgrep -x Godot` guard; the owner's engine was
never touched). 19 runs + import; full table in `sweep-results.txt`, exact commands in
`sweep-commands.txt`.

- **17 green runs**, 0 `SCRIPT ERROR` anywhere except the two slice constructions noted
  below: `base-harness` 8/8, `base-input` 5/5, `base-rules` 10/10, `base-modes` 6/6,
  `base-save` 137/137, `base-music` 32/32, `s14-court` 1111 checks, `s14-shot-parity`
  675/675, `s14-timing` 100/100, `s14-switch` 85/85, `ui-menu-audit` 97/97 (98/98 demo),
  `ui-hud-audit` 172/172, `ui-legibility` 76/76, `ui-router` 86/86, `ui-theme` 271/271,
  `ui-fonts` 75/75, `ui-data` 131/131 (134/134 demo), `ui-input-a11y` 117/117,
  `ui-reachability` 21/21. The brother's gates on the merged tree: court, shot parity,
  timing, switch all green.
- `s14-timing-inject` = **FAIL 88/92, exit 1 by design**: the negative control injects the
  four timing defects and the suite must catch them — it does.
- **The parent's menu double-ERROR question — closed.** `screen_menu_audit` reads
  `PASS 97/97, script_errors=0, error_lines=1, warnings=0`; the two `ERROR` *grep hits* are
  (a) the log's own note quoting the expected text and (b) the audit's deliberate
  `ScreenRouter.register` refusal probe. Identical shape in the parent's pre-gate log. No
  defect, nothing suppressed.
- **Finding 1 — the branch's slice rewrite silently dropped main-line coverage.** In
  `base-slice` the first sweep read `FAIL 322/325` (3 red) and `base-slice-demo`
  `FAIL 267/274` (7 red): the artwork set had been re-asserted as four (contradicting the
  frozen reference and this tree), and the demo guards + the music seam block were gone
  (§7 reconciles).
- **Finding 2 — `slice-ui-new` (informational, not a gate).** exit 1: the slice drives the
  ported menu's API, which the prototype menu does not expose (61 reds before §7, 57 after),
  the `_menu_reaches_match` section throws, and the object ceiling reads 472 while the
  prototype scenes are mounted — the mount is exactly what `--ui=new` adds, so that figure
  is expected there. Recorded for UIR-22; no fix attempted in the pull wave.

## 7. Reconciliation — restoring what the branch's rewrite dropped (done)

Label-set diff of `godot/tests/game_slice_test.gd` between `249d55a` (main line) and
`a1e10f04`: **20 checks lost** (3 artwork, 1 court-scale — legitimately superseded by the
branch's new 10×20 m court check — 2 demo guards, 14 music seam), 52 gained (the branch's
timing/court/marker/HUD work — kept).

- **Artwork (3).** The rewrite asserted "the four arenas … are the four that load it" — a
  factual error in this tree: the frozen `js/data.js` gives **every** arena an `image`
  (two reuse files) and `arena_style.gd` has carried nine mappings since `74195c4` (in both
  lineages; the branch never reverted it). Restored the three main-line checks verbatim
  (nine mappings, the two reuses, decode-at-runtime for all nine).
- **Demo guards (2 + probing).** `_tiers_playable` and `_arena_library` lost their
  `Gate.is_demo()` handling, which is why the demo run was red; restored (pinned tier 1 /
  granted arena in env **and** sim, three arena ids probed under demo).
- **Music seam (14).** `_full_playthrough` lost the whole score seam: the block, the
  per-tick `reference_music_intensity` drive, the awaited scheduler proof and the
  end-of-match stop checks; the helper function and the `AWAITED_SECTIONS` entry were gone
  too. Restored verbatim from `249d55a`, same runtime (no game code touched).
- **Kept from the branch:** their stricter `padel.pck` pack check (see below), the new
  court/timing/marker checks, the reorganized sections.
- **Result:** `base-slice` → **FAIL 339/340** (was 322/325), `base-slice-demo` → **FAIL
  290/291** (was 267/274). The single remaining red in both is the branch's own pack check,
  `"the shipping pack exists (export it before running this test)"` — deliberate upstream
  policy that no source checkout can satisfy (pre-merge it was "not scored"; the rewrite
  flipped it). Kept and reported, **not worked around**; it needs an exported pack on
  whatever host runs the final gate.
- The reconciliation commit touches only `godot/tests/game_slice_test.gd` (+127/−13, net
  +114 lines) plus docs/evidence — the runtime and the frozen files are untouched, so the
  sweep's other 17 green runs still hold for this tree. Verified after the restore:
  `script_errors=0`, the one expected `ERROR:` engine probe line, every restored check `ok`
  (`MUSIC_WIRING start … intensity=0.12 … bus_gain=0.55` / `end … stops=1
  voices_started=4`).
- Also committed here: the three engine-generated `.import` sidecars for the arena art
  added by `74195c4` (they match the tracked pattern of the four sibling files; the brief
  says preserve the arena imports).

## 8. Real-GPU captures of the merged tree (done)

In the isolated copy, windowed on Metal (`OpenGL API 4.1 Metal … Apple M4`), after the
reconciliation:

- `Match.tscn --ui=new --capture=match --tier=3 --seed=20260916` (1152x648): exit 0,
  shots=5 (`quickmatch-serve`, `rally`, **`timing`**, **`timing-off`** — the branch's new
  timing presentation included — `hud`, `hud-off`, `result`), every `CAPTURE_SAVE err=0`.
- `Main.tscn --ui=new --capture=menu` (1280x720): exit 0, `ui-prototype-menu.png` saved.
- Transcript + md5s: `evidence/uir-pull-wave/captures.log`. PNGs live in the isolated copy
  (`/tmp/padel-uir-pull-20260917/repo/godot/game/out/`), not committed (no binary churn);
  regenerate with the documented commands.

## 9. State at hand-back

- Local commits (nothing pushed, parent certifies first): `249d55a` (checkpoint, 246
  files) → `c6837b2` (merge of `a1e10f04`) → the reconciliation commit that adds this
  section.
- Working tree: only preserved foreign-lane leftovers (`.hermes/`, `art/concepts/`,
  `art/generated/rackets/`, `meshy/**`, `mode-drill-screen.png`/`mode-quick-screen.png`
  from the mission lane's capture namespace). Never `git add -A`.
- **GATE-A remains Luca's and unstarted**; no visual verdict is implied by this wave. The
  interface/mission rows on the board are untouched — this wave only lands the integration
  and its evidence.
