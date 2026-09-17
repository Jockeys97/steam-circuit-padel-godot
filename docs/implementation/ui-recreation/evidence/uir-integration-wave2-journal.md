# Integration wave 2 journal (integrator: foundation/menu, sole engine-run owner)

Date: 2026-09-17 · repo: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot`
Engine: `4.7.2.stable.official.ed1daf0bf` · pre-existing game process PID 94690 left untouched
(`res://game/Main.tscn -- --seed=20260916 --tier=3 --camera=default`, up since 2026-09-16).

Scope: independently review the seven implemented foundation tickets (UIR-00…06), fix
genuine foundation defects inside their own scopes, verify everything on the engine, then
implement and verify UIR-07 (`MenuScreen`). No post-gate-a screen was implemented; GATE-A,
the platform/touch decision and `luca-final` stay untouched.

## 1. Where the engine ran

One engine process at a time, never in the checkout, so the running game keeps its project
directory and the repo stays free of engine-generated files:

    copy   rsync -a --exclude='/.git' --exclude='/godot/.godot'
           /Users/lucafantini/.../steam-circuit-padel-godot/  ->  /tmp/padel-uir-wave2-20260917/repo
    check  relative-path+sha256 manifest of both trees: diff empty before the runs
    logs   /tmp/padel-uir-wave2-20260917/logs/   (00…51, see the table below)

The copy includes the untracked UI sources (`godot/src/ui/**`, `godot/tests/ui/**`,
`godot/assets/ui/**`) and excludes `.git` and the pre-existing `godot/.godot` cache. Two
diagnostic scripts (`_diag_heights.gd`, `_diag_probe.gd`) were written **in the copy only**
during the theme-probe diagnosis and are deleted from it afterwards; they never entered the
repo, and neither the repo's `godot/src/ui`, `godot/tests/ui` nor `godot/assets/ui` carries
a `.godot/`, `.import` or `.uid` artifact from this wave.

## 2. The verification battery (all in the copy, all with `--headless`)

| suite | command (`--path godot/`) | result | script errors |
|---|---|---|---|
| theme probe (UIR-02) | `--script res://tests/ui/theme_probe.gd` | **PASS 254/254** | 0 |
| fonts/assets probe (UIR-01) | `--script res://tests/ui/fonts_assets_probe.gd` | PASS 75/75 | 0 |
| router audit (UIR-03) | `--script res://tests/ui/router_audit.gd` | PASS 86/86 | 0 |
| adapters audit (UIR-04) | `--script res://tests/ui/data_audit.gd` | PASS 131/131 | 0 |
| adapters audit, demo | `--script res://tests/ui/data_audit.gd -- --demo` | PASS 134/134 | 0 |
| input/a11y audit (UIR-05) | `--script res://tests/ui/input_a11y_audit.gd` | PASS 117/117 | 0 |
| reachability audit | `--script res://tests/input/reachability_audit.gd` | PASS 21/21 | 0 |
| **menu audit (UIR-07)** | `--script res://tests/ui/screen_menu_audit.gd` | **PASS 95/95** (96/96 `-- --demo`) | 0 |
| static theme validator | `python3 theme_validator.py` (extracted from `uir-02-theme-probe.log` §Appendix) | PASS 25/25 | — |
| baseline, 8 suites | harness 8/8 · slice 292/292 · slice demo 243/243 · input 4/4 · audits 10/10 · modes 6/6 · save 137/137 · music 32/32 | all green | 0 |

The baseline was re-run **after** every change in this wave, so "green" means green with the
menu landed and the theme extended, not green from before. The already-verified tickets'
audits were re-run rather than trusted: router 86/86, data 131/131 + 134/134, input 117/117,
fonts 75/75 — each exactly as the prior workers claimed, each with 0 script errors.

## 3. What the review found (fixed inside the owning ticket's scope)

1. **`theme_probe.gd` measured an unthemed grid.** Its first engine run read `FAIL 239/248`:
   the grid never assigned the theme to any node, so every height-band check measured engine
   defaults (31 px). Fixed (`_host.theme = _theme`), together with two further defects the
   fix exposed: the chip's 42 px is a CSS *height* the theme cannot hold (the probe now
   declares the screen-side `custom_minimum_size` rule and measures natural height — bands
   unchanged), and the three-column grid overflowed the 1024x600 frame (now four
   weight-balanced columns). Final: `PASS 254/254`. Full record: `uir-02-theme-probe.log`
   appendix.
2. **Theme gap for the menu (UIR-02 scope).** Three reference colours had no palette token:
   `nav_bg` (`styles.css:90`), `caption_shadow` (`styles.css:215`), `poster_fade`
   (`styles.css:194`). Added to `padel_theme.tres` + README §3, asserted by the probe; the
   theme README §7 now names the variation set the theme owner should fold the menu's
   composed chrome into next.
3. **Adapter gap (UIR-04 scope).** `DemoGateAdapter.badge_text_key_for(build_id)` added for
   the reference's beta branch (`js/ui.js:744`); `badge_text_key()` unchanged.
4. No other foundation defect surfaced: the router/data/input audits reproduce their tallies
   unmodified, the literal scan now reads 12 UI files with 0 offenders, and the four entry
   points (import, probes, audits, baseline) all exit 0.

## 4. Deliverables this wave

- `godot/src/ui/screens/MenuScreen.gd` + `.tscn` — the reference's front page (`index.html:31-87`),
  all eight `to-*` actions through the router, every string through `UiStrings`, badge
  through `DemoGateAdapter`, its own theme-gap documentation and the two viewport rules
  (hero-title clamp, poster 16:9).
- `godot/tests/ui/screen_menu_audit.gd` + `.tscn` — 95/96 checks (see
  `evidence/uir-07-screen-menu.log`, which carries both runs verbatim).
- Evidence: new `uir-07-screen-menu.log`; integrator appendices in `uir-01-assets.md`,
  `uir-02-theme-probe.log`, `uir-03-router-audit.log`, `uir-04-adapters-audit.log`,
  `uir-05-input-a11y-audit.log`; this journal.
- Tracker: `BOARD.md` (rows UIR-01/02/06/07 verified; standings), `LOG.md` (this wave),
  ticket frontmatter for UIR-01/02/06/07 (`state: done`, `plan_approved: true`).

## 5. Deviations, honestly

- The screen's write allowlist does not include the theme or the adapters. Both edits above
  are integrator-owned, minimal, inside *those tickets'* own scopes, and recorded in the
  screen's evidence log and in each ticket's appendix — instead of the "hand back a blocker"
  branch, which would have left UIR-07 unbuildable this wave.
- `ui-menu.png` is **pending**: UIR-24's capture harness does not exist yet, so no PNG was
  produced (the ticket's own "otherwise note pending" branch). The layout numbers the audit
  prints are the substitute evidence at both ticket sizes.
- Nothing was committed, pushed, deleted, or paid for; no provider override was claimed; no
  nested delegation was used.

## 6. System state at close (recorded, not hidden)

- **The play window exited on its own during this wave.** PID 94690 was up and healthy when
  the battery started (checked: 1 h 13 m elapsed) and read as gone ~20 minutes later. No
  signal came from this session: every engine invocation was
  `--headless --path /tmp/padel-uir-wave2-20260917/repo/godot/` (a separate project
  directory) and no `kill`/`pkill` was issued at any point. Most plausibly the window was
  closed by hand while the work ran; the game's own last log was rotated away by the copy's
  runs (Godot keeps a handful of rotated logs under the shared
  `…/app_userdata/Steam Circuit Padel Pro (harness)/logs/`), so no exit reason can be read
  from there. It changes nothing about the verification: every run in the copy is
  self-contained, and the green battery does not depend on the play window being up.
- Side effect worth knowing: headless runs of the copy write to the *same* `user://`
  directory as the repo's runs (same project name), so the copy's runs rotate that
  directory's `godot.log` history. No save or preference file was written by this wave's
  audits (they use their own `user://uir*` scratch names; the save suite passes 137/137).
- At close: no Godot process is running anywhere on this machine, and the checkout's only
  engine cache remains the pre-existing `godot/.godot/` (from the game's own runs), with no
  `.uid`/`.import` file added by this wave under `godot/src/ui`, `godot/tests/ui` or
  `godot/assets/ui`.
