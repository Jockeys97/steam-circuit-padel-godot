# UI compatibility & long-term integration checklist — `codex/gameplay-and-map` (brother's branch)

**Prepared:** 2026-09-17 ~01:21–01:40 CEST · **Prepared by:** independent subagent (dev-work profile)
**Authority:** preparation only — no pull/merge/rebase/stash/reset/commit ran anywhere; the active checkout was never mutated; no Godot process was started against it. Budget: $0.
**Method:** read-only git plumbing on the active checkout (`GIT_OPTIONAL_LOCKS=0`, no index writes), read-only GitHub API, and a private partial clone (`--filter=blob:none --no-checkout`) at `/tmp/padel-brother-prep/compatibility/repo`. The other scout's area (`/tmp/padel-brother-prep/remote/`) was not touched.
**Non-claims:** no dynamic verification. Nothing below was produced by running Godot, by executing a real merge, or by trusting either side's tallies — every branch/UI number quoted is *their claim*, marked "re-run at gate".

---

## 0. Headline findings

1. **There is no PR.** `https://github.com/Jockeys97/steam-circuit-padel-godot/pull/new/codex/gameplay-and-map` is GitHub's *"open a PR"* compare link. `gh pr list --repo Jockeys97/steam-circuit-padel-godot --state all` returns `[]` (checked twice, ~01:22 and ~01:33 CEST). The branch exists: `refs/heads/codex/gameplay-and-map`. Treating that URL as a PR would be a category error.
2. **The branch moved mid-review.** First observed tip `61f3ee71` (5a… hand-off only, 21 files). At 01:33 the tip was **`2752d9a2eda9dafb692c66e91fb423bd0f92f60f`** ("feat: prove the shots and the timing, and put the timing on the field") — 5 commits ahead of `main`, 0 behind, **60 files, +7293/-345**. The new commit *lands the S14 lanes* and now touches `godot/game/hud.gd`, `godot/game/match_controller.gd` and `godot/game/out/*.png` — exactly the files the active UI integrator is working — which the earlier 21-file tip did not. Everything below is anchored at `2752d9a2` unless a different SHA is named. **Re-pin at pull time; this branch is a moving target.**
3. **Merge-base = current `main` = local `HEAD` (`252ff60`), 0 commits behind** → the branch is fast-forwardable at ref level.
4. **File-level overlap with the current dirty tree is exactly one path: `godot/game/match_controller.gd`** (computed intersection of the branch's 60 changed paths vs. the local modified+untracked set). A read-only three-way text merge of that file (base `252ff60` + current local + branch tip) produces **0 conflict hunks** (merged 2018 lines = both sides' changes). It must be **re-probed at pull time** — both files were changing during this review (see §3).
5. **Silent-overwrite hazard (not a conflict): the UIR-00 "before" capture register.** The branch rewrites, as tracked binaries, `godot/game/out/menu.png`, `hud.png`, `rally.png`, `quickmatch-serve.png`, `result.png` and all nine `arena-*.png` — the exact 20-file set that `docs/implementation/ui-recreation/evidence/uir-00-before-set.md` freezes by sha256 at `252ff60`. These files are clean locally, so a pull will replace them **without any conflict** and silently invalidate the register. Preserve copies before pulling (§6).
6. **No change to the UI's input contract.** `ui_accept` / `ui_cancel` blocks in `project.godot` are **byte-identical** between `main` and the branch (sha256 of the extracted blocks: `7158cdcc80231d88…` / `ec73fe289676bf3c…`), so `src/ui/focus/UiFocusBridge.gd` (dispatches on those two actions) and `tests/ui/input_a11y_audit.gd` survive the merge unchanged. `run/main_scene="res://tests/SmokeTest.tscn"`, `physics_ticks_per_second=120`, `gl_compatibility` are all preserved (branch `project.godot` lines 14, 150, 154–155).
7. **Nothing in the branch touches map dimensions, spawn logic, cameras, a HUD minimap, `ViewState`, or screen navigation.** Verified against the actual diff, not assumed — see §2. The word "map" in this branch means: the input map (`input_map.gd`), the wayfinder roadmap map (`docs/wayfinder/map.md`), and a PNG colour-mapping tool (`tools/yellow_map.py`). It is **not** the game's court/arena map.

---

## 1. PR / branch verification (exact handles)

| Fact | Value | Source |
|---|---|---|
| Remote | `https://github.com/Jockeys97/steam-circuit-padel-godot.git` (both fetch/push in active checkout) | `git remote -v` |
| PR count for head branch | **0** (`[]`) | `gh pr list --repo Jockeys97/steam-circuit-padel-godot --state all --head codex/gameplay-and-map` |
| PR count, all states | **0** (`[]`) | `gh pr list --state all --limit 20` |
| Branch ref | `refs/heads/codex/gameplay-and-map` = `61f3ee71…` at 01:22, `2752d9a2eda9dafb692c66e91fb423bd0f92f60f` at 01:33 | `git ls-remote` (twice) |
| `refs/heads/main` | `252ff6074039372ebbf8ec682f9adda0e9c80d03` (unchanged across both ls-remote runs; = local HEAD) | `git ls-remote`, `git rev-parse HEAD` |
| Merge-base(main, branch) | `252ff60` (branch strictly ahead) | `git merge-base` in private clone |
| Compare API (main…branch, new tip) | `status=ahead, ahead_by=5, behind_by=0, total_commits=5, files=60`; `merge_base=base=252ff60`; `head: null` (API quirk) | `gh api .../compare/main...codex/gameplay-and-map` |
| Branch commits (main..branch) | `d5bb0f8` pad/input fix · `a52bbb2` S14 charting + 27→28 audit correction · `cc88a14` pad_probe + yellow_map instruments · `61f3ee7` hand-off note · `2752d9a2` S14 landed (shot/timing proof + on-field timing presentation) | `git log --oneline origin/main..origin/codex/gameplay-and-map` |
| Local `main` | `252ff60` = origin/main; **no stash**, nothing staged; working tree dirty only by the UI integrator (§3) | `git status`, `git stash list` |

---

## 2. What the branch actually changes (file-level, at `2752d9a2`)

Full name-status list saved at `snapshot/branch-changed-files.txt`. 60 files: 15 docs, 24 code/test/tool files, 21 PNGs.

**Code, gameplay-side**
- `godot/game/input_map.gd` (+368/-110): per-frame pad selection (`selectPrimaryGamepad`), Godot button numbering, left-stick aim while charging, right-stick directional switch latch (0.72/0.30), take-over-holds-first-press.
- `godot/project.godot` (+121/-…): `[input]` re-written — `padel_switch` LB 4→9, `padel_pause` Start 9→6, `padel_technical` RB 5→10, `padel_split_step` button 6→axis 4, `padel_sprint` drops button 7, tactics 12–15→11–14 (D-pad). `ui_accept`/`ui_cancel` moved but byte-identical (§0.6). Header/comments replaced; `[physics]`/`[rendering]` sections moved, values kept.
- `godot/game/match_config.gd` (+21): new `control_mode()` (validated `assisted|semi|manual` from save).
- `godot/game/match_controller.gd` (**+753**): active-player marker (`_active_ring`, `_active_pin`) and the timing presentation (ring/advice/precision/energy/verdict, `_timing_marks` built in `_build_scene`, placed in `_sync_timing`; `_timing_muted` A/B frame flag; `queued_one_shots2` latch fix; new `CAPTURE_MARKER` print in `_save_frame`).
- `godot/game/hud.gd` (+96/-…): timing-related HUD work. `HUD_LANG` stays at line 62, `SAFE_MARGIN := 8.0` stays at line 75 (the two constants the UI pack cites); everything past line 91 shifts (e.g. `_build_debug` 328→331, SEED line 402→406, `_build_feedback` 267→270, `_update_energy` 443→447).
- `godot/tests/game_slice_test.gd` (+447/-151): marker section added (`_active_player_marker`), SECTIONS list changed (line 83/94–95), menu-fit check 571→573, `_hud_safe_area` 1785→**1956**, HUD frame checks 1810–1811→**1981–1982**. Same assertions, moved lines.
- `godot/tests/input/run_all.gd` (+1): adds `["switch_mode", …]` → **input runner becomes 5 audits** (was 4).
- `godot/tests/input/input_remap_a11y_audit.gd` (+7/-7): free-button list corrected to Godot numbering (`["16","17","18"]`).
- New: `godot/tests/input/switch_mode_audit.gd` (320) + `.uid`; `godot/tests/shot_logic_parity_test.gd` (912) + `.uid`; `godot/tests/timing_feedback_test.gd` (916); `godot/game/tools/pad_probe.gd` (+uid), `yellow_map.py`; `tools/sim-port/{shot-intent-compare.mjs, shot-intent-probe.mjs, timing-compare.py, timing-trace.mjs}`.

**Docs**: `docs/handoff/gameplay-and-map-2026-09-17.md` (new), `docs/mission/BOARD.md` (new, 70 lines), `docs/mission/LOG.md` (+76), `docs/mission/STATE.md` (+27, **declares the S14 lane allowlists — see §5**), `docs/wayfinder/evidence/{active-player-marker,player-switch-parity,shot-logic-parity,timing-logic-parity,timing-presentation-3d}.md` (new), `docs/wayfinder/tickets/{shot-logic-parity,timing-logic-parity,timing-presentation-3d}.md` (new), `docs/wayfinder/{map.md,validation.md,validate.py}` (27→28 audit-count correction).

**Captures (`godot/game/out/`, all tracked binaries)**: 11 changed — `menu.png` (120852→139765 B), `hud.png` (219028→201516), `rally.png` (217086→199597), `quickmatch-serve.png` (195475→175453), `result.png` (216317→189559), `arena-{abissale,caldera,cattedrale,clockwork,forgia,locomotive,officina,orrery,tempesta}.png`; 11 **new** — `hud-off.png`, `probe-{charge,charge-off,precision,precision-off,timing,timing-off,verdict,verdict-off}.png`, `timing.png`, `timing-off.png`.

### Checked against, and NOT changed by, the branch

| Area | Verdict | Evidence |
|---|---|---|
| Map dimensions / court / arenas | untouched | no `court.gd`, `arenas/**`, `arena_library.gd` in `git diff --name-only` |
| Spawn (athletes, rigs) | untouched | no `src/character/**` in diff; no spawn edits inside match_controller hunks |
| Camera | untouched | no `camera*` file in diff; `--camera=` capture arg unchanged |
| HUD minimap | **does not exist in this tree on either side** | `git ls-tree -r origin/codex/gameplay-and-map \| grep -i minimap` → empty |
| `ViewState` | untouched (UI-lane file) | no `godot/src/ui/**` path in diff |
| Navigation (router / `nav_routes` / NavigationMesh) | untouched | no router/nav files in diff; `gamepad_nav_audit.gd` unchanged (only `run_all.gd` + `input_remap_a11y_audit.gd`) |
| Scenes (`Main.tscn`, `Match.tscn`, `ModeScreen.tscn`) | untouched | no `.tscn` in the 60-file list |
| `godot/src/**` (sim, locale, modes, save) | untouched ("frozen", their BOARD §"What shipped" item 2) | no `godot/src/` path in the diff |
| `js/**`, `index.html`, `styles.css` (frozen reference) | untouched | not in diff |

---

## 3. Local checkout snapshot (concurrent files are a snapshot, not immutable)

**Anchor:** `HEAD = 252ff60`, branch `main`, no stash, nothing staged.

**Dirty (modified, unstaged)** — the UI integrator's UIR-09 mount work:
- `godot/game/main_menu.gd` — prototype router mount, `ui_prototype` property, `--ui=new`, `_run_capture` prototype branch. sha256 **t1** `d2fb3429…` (~01:21) → **t2** `9ded3edc4f34ede1f4287ba8d372d0abe38d46fbc41159e25ddd6a1647564e64` (~01:28).
- `godot/game/match_controller.gd` — `UiHudScene` mount into `_build_scene`, `_refresh_ui` feeding, `_on_ui_pause`, capture-path `UI_PROTOTYPE_ON_SCREEN` print. sha256 **t1** `b0895ebb…` → **t2** `18542ea2d3642e3fe6af96e130c672636dd446320573db8fd25797de8150538a`.

Both files were **edited during this review** (t1→t2 drift in ~7 minutes). Full t2 patches saved: `snapshot/active-unstaged.patch` (t1) and `snapshot/active-unstaged-t2.patch` (t2). **Re-snapshot immediately before any pull; use the t2+ state.**

**Untracked (23 entries)** — from `snapshot/local-status.txt`:
- `docs/implementation/ui-recreation/**` (pack: 6 top docs, 28 tickets, evidence incl. `reference-captures/`), `godot/src/ui/**` (14 scripts + 2 themes + `theme/README.md`), `godot/tests/ui/**` (13 audit/capture scripts + scenes), `godot/assets/ui/**` (fonts, portraits, arena webp, controllers, key art + `.import` sidecars)
- `godot/game/out/ui-*.png` + `ui-prototype-*.png` + `mode-quick-screen.png` (UIR-24/UIR-09 captures)
- `godot/game/arenas/art/{clockwork-factory,deposito-locomotive,officina-vapore-standard}.webp.import` (import sidecars from another lane — "leave alone")
- `.hermes/plans/…`, `art/concepts/world-arenas-r1/**` (art lane), and — **appearing mid-review** — `meshy/burattino-brief.md`, `meshy/image-spend.json`, `meshy/views/burattino-front.png`
- The tree gained 3 new untracked paths between 01:21 and 01:28. **At least two other writers are live in this checkout** (UI integrator + an art/meshy lane). This is the "snapshot not immutable" caveat made concrete.

**Also live on this machine:** the branch author's own session (its `docs/mission/BOARD.md` tick-21 report) and a running Godot play-test window; the UI pack's one-engine-at-a-time guard is `/tmp/padel-godot.lock.d` (no `flock` on macOS).

---

## 4. Overlap analysis (branch `2752d9a2` vs current dirty/untracked state)

**Computed intersection** (`comm -12`, files `snapshot/dirty-paths.txt` × `snapshot/branch-sorted.txt`): exactly one path — **`godot/game/match_controller.gd`**.

### 4a. Direct dirty overlap

| Path | Branch | Local | Consequence |
|---|---|---|---|
| `godot/game/match_controller.gd` | +753 (S14c marker + timing) | modified (UIR-09 mount) | **The one shared file.** Text merge probe §5: 0 conflicts at t2. Re-probe after each side settles. |

### 4b. Silent overwrites (clean locally → pull replaces them with no conflict)

| Path(s) | What changes under you |
|---|---|
| `godot/game/out/{menu,hud,rally,quickmatch-serve,result}.png`, `arena-*.png` (11 files) | Branch's regenerated captures replace the UIR-00 **before-set** (register `uir-00-before-set.md` pinned by sha256 at `252ff60`). Pull = register silently falsified. Also, UIR-09's evidence references these as before-halves; UIR-24's ticket says "never touch" them (true for *players of the pack* — false for a git pull). |
| `godot/game/hud.gd` | Carries S14c work. Line anchors cited across UI docs shift past line 91 (`hud.gd:315/334/402` in UIR-22 → ~+3..+9 lines; re-locate). Constants at `:62`, `:75` survive. |
| `godot/tests/game_slice_test.gd` | +447/-151; menu-fit 571→573, `_hud_safe_area` 1785→1956, HUD checks 1810–1811→1981–1982. UIR-09's trace citations (`:542-571`, `:1796-1811`) go stale; assertions themselves survive. |
| `godot/project.godot` | `[input]` rewritten (button numbering) but `ui_accept`/`ui_cancel` byte-identical; `run/main_scene` kept. UIR-22 must add `[display]` **on top of the branch's file**, never the current one. |
| `godot/tests/input/{run_all,input_remap_a11y_audit}.gd` + new `switch_mode_audit.gd` | Input runner tally 4/4 → **5/5** (their claim: 392 checks + 7 not-ported; the 61f3ee71 hand-off said 393 — **re-run to settle**). UIR-05's DoD text says `# must stay 4/4` — stale post-merge. |
| `docs/mission/LOG.md` | Both hands append; branch adds a 76-line block at EOF. UIR-22's write allowlist includes this file → append-after-pull, or expect union-style conflicts. |
| `docs/mission/{STATE.md,BOARD.md}`, `docs/wayfinder/**` | Mission-owned; UI pack references only `docs/wayfinder/tickets/ui-port-approach.md` (GATE-A) — **untouched by the branch**. `validate.py` now expects 28 audit scripts. |
| `godot/game/input_map.gd`, `godot/game/match_config.gd` | Clean locally; pure pull. UI lane does not preload either today (grep: no `input_map`/`InputSource` references under `godot/src/ui`, `godot/tests/ui`; `match_controller.gd` keeps `preload("res://game/input_map.gd")`). |

### 4c. No collision (verified disjoint)

`godot/game/main_menu.gd` (branch does not touch it); everything untracked: `godot/src/ui/**`, `godot/tests/ui/**`, `godot/assets/ui/**`, `docs/implementation/**`, `godot/game/out/ui-*.png`, `ui-prototype-*.png`, meshy/art/hermes files; new branch files (`pad_probe.gd`, `yellow_map.py`, `switch_mode_audit.gd`, parity tests, sim-port tools, `docs/handoff/*`, `docs/mission/BOARD.md`) — none of these names exist as untracked locally.

### 4d. Semantic ownership overlaps (no shared path, shared files-by-claim)

From the branch's own `docs/mission/STATE.md` (Slice S14 lane table): **`crew-timinghud` is allowlisted to write `godot/game/hud.gd`, `godot/game/match_controller.gd`, one `_timing_presentation` section in `godot/tests/game_slice_test.gd`, and `godot/game/out/*.png`.** Those are the same files the UI pack claims: UIR-09's write allowlist (`main_menu.gd`, `match_controller.gd`, `hud.gd`, `Main/Match.tscn`, `ui-prototype-*.png`), UIR-22 ("the single writer of `godot/game/**`" and `project.godot [display]`), UIR-24 ("`godot/game/out/ui-*.png` is yours"). The S14 code has now **landed on the branch** (commit `2752d9a2`), so going forward the collision risk is no longer "two dirty trees" but "two integration orders". The durable fix is serialization, not partitioning (§7).

---

## 5. Merge mechanics — read-only probe (and its limits)

- **Ref level:** branch strictly ahead of `main`; `git merge --ff-only` would be the fast path.
- **Dirty-tree level:** `git` refuses any merge/pull that would update a locally-modified file (standard behavior; **not exercised here** — no merge was run). With `match_controller.gd` dirty and the branch changing it, a plain `git pull` would abort with "Your local changes … would be overwritten by merge". No data loss — but no integration either. **The integrator must commit (or otherwise preserve) before the pull.**
- **Text level (executed, read-only):** `git merge-file -p --diff3 local-match_controller.gd base-match_controller.gd branch-match_controller.gd` (argument order corrected after a first bad run):
  - exit **0**, `<<<<<<<` markers **0**; merged 2018 lines = local 1273 + branch's +745 exactly.
  - Inputs: `snapshot/{base,local,branch}-match_controller.gd`; output `snapshot/merged2-match_controller.gd`.
  - **Limits:** this is a text merge of *captured* t2 content; both sides changed after capture (local t1→t2; branch tip moved once). It proves the two change-sets *as sampled* interleave cleanly; it does not prove the final files will. Re-run the same probe on frozen pre-pull versions and record the exit code.
- `main_menu.gd`: branch byte-identical to `main` → merge is a no-op by construction.
- Binary captures (`*.png`): no textual merge possible; either side's regeneration wins wholesale. Namespaces are currently disjoint (§7) — keep it that way or expect conflicts.

---

## 6. Preservation strategy (do these BEFORE any pull)

1. **Freeze the local state**: re-run `git status --porcelain`, `git diff > snapshot/active-unstaged-FINAL.patch`, `shasum -a 256 godot/game/main_menu.gd godot/game/match_controller.gd`; compare to `snapshot/active-unstaged-t2.patch` (sha256 `a7624de61e4c…`). If the integrator is still editing, stop and wait for it to settle or commit.
2. **Preserve the UIR-00 before-set**: copy the 20 registered PNGs out of the blast radius, e.g. `cp godot/game/out/{menu,hud,rally,quickmatch-serve,result,arena-*,mode-*,menu-full,menu-demo}.png` into `docs/implementation/ui-recreation/evidence/before-set/` (or any durable path outside `godot/game/out/`), then after the pull re-verify the register's sha256s against the copies and add a dated note to `uir-00-before-set.md` ("working tree now carries the post-branch captures; register refers to copies at this path"). Owner of that call: UIR-00/UIR-09 ticket owner (coordinator), not the puller.
3. **Sequence the integrator's work**: UIR-09's DoD says "no commits", which is incompatible with pulling over a dirty tree. Proposed: integrator finishes the wave, then commits the UIR-09 changes on a UI branch (`ui-recreation` or similar) with explicit paths (never `git add -A` — repo house rule, echoed in the branch hand-off), including the untracked `src/ui/**`, `tests/ui/**`, `assets/ui/**`, `docs/implementation/ui-recreation/**` (mind `.import`/`.uid` sidecars; exclude `.hermes/`, `art/concepts/`, `meshy/`, arena `.import` sidecars from other lanes).
4. **Fetch and pin**: `git fetch origin` then merge/ff **the reviewed SHA** (`2752d9a2` or its successor after re-review). If the tip moved, diff `old_sha..new_sha` first; the branch already moved once during this review.
5. **Never regenerate the other namespace's captures**: `ui-*`/`ui-prototype-*` = UI lane; legacy names + `probe-*`/`timing*`/`hud-off` = mission lanes.
6. **One engine at a time** (both sessions share this checkout): take `/tmp/padel-godot.lock.d`; `pgrep -f Godot` check before each run; journal each suite to a file.

---

## 7. Proposed ownership boundaries (durable)

| Path / namespace | Sole writer at any time | Rules |
|---|---|---|
| `godot/game/match_controller.gd` | **Serialized: UIR-09 integrator → then S14c (already committed on branch) merges → then UIR-22** | The only true shared file. Whoever holds it must not have it dirty when someone else needs to merge/pull. Handover via commit, never via shared dirty tree. |
| `godot/game/hud.gd` | S14c (landed on branch) → UIR-22 (retire/dedupe) | UIR-09 leaves it untouched (its current tree indeed has it clean). Any UI edit re-locates line anchors first (`:62`, `:75` stable; `:91+` shifted). |
| `godot/game/main_menu.gd`, `Main.tscn`, `Match.tscn` | UIR-09 → UIR-22 | Branch never touches them; keep it that way (S14 shouldn't need them). |
| `godot/project.godot` | Branch `[input]` is authoritative post-merge; **UIR-22 owns `[display]` only** | Pin `ui_accept`/`ui_cancel` blocks by hash in any post-merge check (`7158cdcc…`, `ec73fe28…`). No other writer. |
| `godot/tests/game_slice_test.gd` | One writer per wave; S14's rewrite is committed → next holder is UIR-09/UIR-22 for the menu/HUD assertion reconciliation | Re-locate anchors after every merge; never delete an assertion to go green (both house rules say this). |
| `godot/tests/input/**` | Mission/S14 | UI reads only (UIR-05's read allowlist). Expect 5/5 post-merge; update UIR-05's "must stay 4/4" text to "5/5 (or record the actual)". |
| `godot/tests/ui/**`, `godot/src/ui/**`, `godot/assets/ui/**`, `docs/implementation/ui-recreation/**` | UI pack (per ticket allowlists, coordinator-serialized) | The branch adds nothing here; verified disjoint. |
| `godot/game/out/` | Namespace partition: `ui-*`/`ui-prototype-*` = UIR-24/UIR-09 · legacy names (`menu`, `hud`, `rally`, `quickmatch-serve`, `result`, `arena-*`, `mode-*`, `menu-full`, `menu-demo`) = mission regenerations · `probe-*`/`timing*`/`hud-off` = S14 | Also an acknowledged open item on their side: `godot/game/out/*.png` "is not gitignored while four captures are tracked" (their BOARD); no ticket may regenerate another namespace's files; hash-diff before committing captures. |
| `docs/mission/{LOG,STATE,BOARD}.md`, `docs/wayfinder/**` | Mission (CEO) | UI pack writes `LOG.md` only as appends, after the pull. `ui-port-approach.md` (GATE-A) untouched by branch. |
| `tools/sim-port/**` | Mission/S14 | New dirs on branch; UI owns none of it. |

**Ordering doctrine (the durable rule):** *any file claimed by two missions = a single committed writer at a time; before merging, the other side must be clean for that path; conflicts are resolved by ordering commits, never by editing someone's dirty tree.*

---

## 8. Regression gates & test order (post-merge, serialized)

All test counts below are the two sides' **claims** (`# re-run at gate`); the gate passes only when re-measured by someone other than the author, matching or explaining every delta. Engine runs strictly one at a time (lock dir), from the repo root, with the pinned Godot (`/Applications/Godot.app/Contents/MacOS/Godot`, hash `ed1daf0bf`, 4.7.2).

**Preconditions:** pull merged cleanly; re-snapshot archived; before-set copies verified; `git status` shows only intended changes; `pgrep -f Godot` empty.

| # | Gate | Command | Expected (claim → re-run) |
|---|---|---|---|
| 1 | Import pass | `$GODOT --headless --path godot/ --import` | sidecars only; keep `.uid`/`.import` out of commits |
| 2 | Harness (main scene) | `$GODOT --headless --path godot/` | `PASS 8/8` (both sides) |
| 3 | Full slice | `… --script res://tests/game_slice_test.gd` | branch: `324/325`, only red `padel.pck` (clone artifact); source checkout may print `292/292`. Record actual. |
| 4 | Input runner | `… --script res://tests/input/run_all.gd` | branch: `PASS 5/5`, 392 checks (hand-off said 393 — settle it), 7 not-ported |
| 5 | Rules audits | `… --script res://tests/audits/run_all.gd` | `PASS 10/10`, 221 checks |
| 6 | Modes + saves + music | `tests/modes/run_all.gd`, `tests/save_steam_test.gd`, `tests/music_port_test.gd` | `6/6` (3603 checks) · `137/137` · `32/32` |
| 7 | S14 parity gates (new) | `… --script res://tests/shot_logic_parity_test.gd`; `… --script res://tests/timing_feedback_test.gd`; and `-- --inject-failure` | `675/675` exit 0; `100/100` exit 0; injected-failure **must FAIL** (96/100, exit 1) — a gate that can't fail isn't a gate |
| 8 | Pad wiring pin | `… --script res://tests/input/switch_mode_audit.gd` (also in runner) | pins `padel_switch`=LB(9), `padel_pause`=Start(6), `padel_technical`=RB(10) against `project.godot`; also re-assert `ui_accept`/`ui_cancel` block hashes |
| 9 | UI audits | `tests/ui/{router_audit,data_audit,input_a11y_audit,hud_audit,screen_menu_audit,theme_probe,fonts_assets_probe}.gd` | board claims: router 86/86 · adapters 131/131 + 134/134 · input/a11y 117/117 · screen_menu 95/95 and 96/96 (`--demo`) · theme 254/254 · fonts 75/75; **open**: `ui_legibility_audit` was `FAIL 73/76` in UIR-09's own evidence — re-run, do not inherit |
| 10 | Slice under the new default | `game_slice_test.gd` with whatever `--ui` default UIR-09 records | both constructions runnable (legacy default + `--ui=new`) — UIR-09 microstep 4's recorded decision |
| 11 | Capture regen + register check | UIR-24 harness (`tests/ui/capture_ui.tscn -- --capture=all …`), `--ui=new --capture=menu --out=ui-prototype-menu`, HUD capture `res://game/Match.tscn -- --ui=new --capture=match …` | outputs land in `game/out/ui-*` only; **hash-check before-set** — expected CHANGED (branch regenerated them); if so, execute §6.2 before GATE-A |
| 12 | Docs gate | `python3 docs/wayfinder/validate.py` | `PASS, 0 errors, 0 warnings`, 28 audit scripts; and UI static validator 25/25 |
| 13 | GATE-A | UIR-09 evidence refresh + play window for Luca | human verdict; not agent-certifiable |

**Order rationale:** branch gates (7) before UI gates (9) so the frozen look the UI measures against is stable; captures (11) last because they are the only write-heavy step that touches shared namespaces. Update ticket texts (UIR-05 `4/4`→ actual; UIR-22 hud.gd/slice line anchors) in the same wave as the pull, so future readers stop chasing stale anchors.

---

## 9. Open items / risks (ranked)

1. **Branch is still moving** — tip changed once mid-review; its BOARD says "next lever: the second push" and the S14 lanes may draw corrections. **Pin the SHA; re-review any delta.**
2. **Integrator is still editing** (`main_menu.gd`, `match_controller.gd` hashes drifted t1→t2 in minutes; new `meshy/**` files appeared). The clean merge probe is valid only for the sampled t2 state.
3. **UIR-00 before-set register will silently falsify** on pull (branch rewrote all 11 legacy captures + added 11 more). Preserve or re-register — decide before, not after.
4. **`godot/game/out` tracking hygiene** — acknowledged open on the branch side ("not gitignored while four captures are tracked"); the UI pack also commits captures. Agree once: which captures are committed, which are ignored.
5. **Ticket text drift after merge**: UIR-05 "input 4/4", UIR-09 traces (`game_slice_test.gd:542-571, :1796-1811`), UIR-22 anchors (`hud.gd:315/334/402`), UIR-00 baseline table (slice counts, input 4/4) — all stale once the branch lands. Fix in the pull wave.
6. **Test-count discrepancies to settle by measurement**: input checks 392 vs 393; slice 292/292 vs 324/325 (depends on `padel.pck` scoring); no other deltas found.
7. **Concurrent engine usage** on a shared checkout and the pack's own rule ("one engine process at a time"); `flock`/`timeout` don't exist on macOS → lock-dir guard, stale recovery by coordinator only.

## 10. Evidence index (all under `/tmp/padel-brother-prep/compatibility/`)

- `snapshot/active-unstaged.patch` (t1, sha256 `674226b23e19…`) · `active-unstaged-t2.patch` (t2, `a7624de61e4c…`)
- `snapshot/local-status.txt` · `local-tracked-game-out.txt` · `local-tools-input.txt` · `local-tracked-docs-impl.txt`
- `snapshot/base-match_controller.gd` · `local-match_controller.gd` · `branch-match_controller.gd` · `merged2-match_controller.gd` (0-conflict probe output)
- `snapshot/branch-changed-files.txt` · `branch-{match_controller,hud,game_slice_test}.diff` · `branch-project.godot.diff` · `branch-sorted.txt` · `dirty-paths.txt`
- `repo/` — private partial clone (`--filter=blob:none --no-checkout`), review reference
- Read-only sources cited: `docs/implementation/ui-recreation/{BOARD.md, tickets/UIR-09-prototype-mount.md, tickets/UIR-24-capture-harness.md, evidence/uir-00-before-set.md, evidence/uir-09-prototype-mount.md}`, `docs/mission/STATE.md` (branch), `docs/handoff/gameplay-and-map-2026-09-17.md` (branch), `docs/wayfinder/evidence/active-player-marker.md` (branch)
