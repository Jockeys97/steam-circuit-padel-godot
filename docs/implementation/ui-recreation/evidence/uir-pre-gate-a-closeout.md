# UIR pre-gate-a closeout — menu caption, HUD findings reconciled, suites, captures

Wave ......... pre-GATE-A defect closeout (single writer), 2026-09-17
Author ....... Hermes subagent on model `deepseek-flash` (provider `opencode-go`)
Scope ........ `MenuScreen(.gd/.tscn)`, `Hud.gd`, `ViewState.gd`, `theme/**`, `tests/ui/**`,
               captures and this evidence set + `LOG.md` + `BOARD.md`
Constraints .. $0 budget, no paid calls; no commits, pushes or merges (the next single-owner
               integration wave checkpoints); nothing deleted; one engine at a time
               (`pgrep -x Godot` guard — a pre-existing process is never killed); no taste
               verdict anywhere (GATE-A belongs to Luca); reference/sim/save/locale/modes
               untouched; `--ui=new` opt-in only, `run/main_scene` unchanged.
Evidence ..... `uir-pre-gate-a-suite.log` (19 runs), `uir-pre-gate-a-menu-audit.log`,
               `uir-pre-gate-a-hud-audit.log`, `uir-pre-gate-a-legibility.log`,
               `uir-pre-gate-a-captures.log` (this document ties them together).

## 1. File register (this wave)

| File | Change | Why |
|---|---|---|
| `godot/src/ui/screens/MenuScreen.gd` | `_apply_caption_fit()` + `CAPTION_WIDTH`/`CAPTION_RIGHT`; hooked to poster `resized` and `enter()` | the caption box was a fixed 378 px and left the poster at 1024x600 |
| `godot/src/ui/screens/MenuScreen.tscn` | `Caption` VBoxContainer: `alignment = 2` | the two caption lines must hug the box's bottom edge, as the reference's content-sized `bottom: 18px` box does |
| `godot/src/ui/Hud.gd` | `TIMER_GAP`/`TIMER_BALL` + the `TimerBall` panel; `COMBO_GLOW_OUTLINE` + `_set_combo_glow()`; `TACTIC_VARIATION`/`TACTIC_FLASH_VARIATION` swap; `report()` gains `combo_glow`, `combo_glow_outline`, `tactic_variation`; score labels named `PlayerScore`/`AiScore` | review findings 2 and 5; the three fields make the states assertable |
| `godot/src/ui/ViewState.gd` | the `rally` capture state now carries `tactic_flash` | so a declared capture state exercises the flash rendering (`set-tennis` already exercises the glow) |
| `godot/src/ui/theme/padel_theme.tres` | palette `combo_glow`; `BoxSegmentedFlash` + `SegmentedFlash` (Button); `BoxTimerBall` + `TimerBall` (Panel); `load_steps` 40 -> 42 | finding 2 needs a theme-owned variation (no screen-side colour literals) and finding 5 a themed ball |
| `godot/src/ui/theme/README.md` | §3 row (`combo_glow`), §4 rows (`SegmentedFlash`, `TimerBall`), §5 rows (both boxes), §6 item 10 (text-shadow -> `font_shadow_color` + `shadow_outline_size`) | the theme's own rule: every value carries its reference line |
| `godot/tests/ui/hud_audit.gd` | +21 checks (151 -> 172): timer ball, both score colours, glow on/at-four and off below, flash swap and return, rendered timing-window anchors in live rally *and* both capture states, actions-row packing at both target sizes | findings 1, 2, 3, 4, 5 and the audit's own two blind spots |
| `godot/tests/ui/screen_menu_audit.gd` | +2 checks (95 -> 97; 96 -> 98 `--demo`): caption containment + both declared insets + poster-vs-column width + text-bottom-hug, at 1280x720 and 1024x600 | closes the recorded defect and the review's "poster width unasserted" nit |
| `godot/tests/ui/router_audit.gd` | `ui_strings_owns_no_table` now scans top-level declarations only | the flat substring matched a *function-local* dict (`UiStrings.gd:36`) and read `FAIL 85/86`; the rule is "owns no table", and a local temporary is not a table |
| `godot/tests/ui/theme_probe.gd` | +17 checks (254 -> 271): `combo_glow` palette value, `SegmentedFlash` fill/text/radius, `TimerBall` fill/border/radius | the theme rows this wave added are asserted from the reference's own lines |
| `godot/tests/ui/ui_legibility_audit.gd` | closing report line counts what it walks (`screens=4 hud_states=18`, was hardcoded `0/0`) | the line read "nothing ran" next to a 76-check PASS |
| `docs/implementation/ui-recreation/evidence/uir-pre-gate-a-*` | this evidence set | — |
| `docs/implementation/ui-recreation/LOG.md`, `BOARD.md` | wave record | — |

Captures regenerated (untracked files under `godot/game/out/`): 18 files, inventory and hashes
in `uir-pre-gate-a-captures.log`. The match lane rewrote the four tracked plan-lane names to
produce them; those files are UIR-00's frozen before-set and were restored byte-identical
afterwards and re-verified against the register's full sha256 (all MATCH). The pre-wave set was
copied to `/tmp/uir-pregate/prior/` before anything was overwritten.

## 2. The menu caption — two defects, both closed

### 2.1 The recorded overflow (the wave-3 open finding)

Before, at 1024x600, all three menu states (verbatim from `uir-24-legibility.log`):

```
FAIL legibility/1024x600/menu/default/containment: expected [], got ["Caption [P: (552.0, 307.0),
   S: (378.0, 92.0)] outside PosterFrame [P: (561.0, 197.0), S: (391.0, 220.0)]"]
```

The fixed 378 px box (offsets `-400 … -22`) reached 9 px past the poster's left edge once the
hero column narrowed to 391 px. `_apply_caption_fit()` now re-derives the box from the poster
itself — `width = min(text minimum, poster width − 22)` — on every poster resize and on
`enter()`, so the design width is a ceiling, not a constant. After, at the same size:

```
# report 1024x600 caption [P: (713.0, 298.0), S: (217.0, 92.0)] in poster [P: (561.0, 188.0), S: (391.0, 220.0)]
ok legibility/1024x600/menu/{default,demo,beta}/containment
PASS 76/76   (was FAIL 73/76; the other 73 checks are byte-identical in both logs)
```

### 2.2 Vertical placement (found while measuring the fix; also closed)

The reference pins the *text block* to `bottom: 18px` over a content-sized box
(`styles.css:205-217`). Measured on `evidence/reference-captures/menu.png` (1280x720) by
colour mask: poster border rows 236/237 and 544/545, border cols 665 and 1214 (poster
550x310); the cyan `PADEL PRO` glyphs end at y=522, i.e. **24 px above the poster's outer
bottom edge**. The port's box was 92 px tall with the text top-aligned, so the glyphs ended
52 px above it (28 px too high) — nobody had measured the inner placement before. Fix:
`alignment = 2` on the caption `VBoxContainer`. Measured after, on the regenerated
`ui-menu.png` (1280x720), same mask: glyphs end at y=441, poster outer bottom 466 ->
**25 px** (1 px from the reference). The audit guard asserts the rect-level rule at both
sizes (last line's box bottom == box bottom; box bottom == poster bottom − 18).
At 1024x600 the same reports hold: `CaptionLine2` bottom = 390 = box bottom, poster bottom
408 (inset 18), caption box fully inside the poster.

## 3. The wave-3 independent review, reconciled finding by finding

Source: `/tmp/uir-wave3-review.md` (read-only review, no engine). "Source now" is this
checkout after the wave; every claim was re-read, then converted into an executable
assertion where the review identified the suite was blind.

| # | Review finding | Source now | Guard (executable) | Status |
|---|---|---|---|---|
| 1 | Perfect window anchored on the needle instead of pinned at 52 % (`js/ui.js:1353-1356`) | `Hud.gd:750-757` — `TIMING_CENTER = 0.52`, window `anchor_left/right = 0.52 ∓ width/200`; the old "centred on it" comment replaced | `hud/the_perfect_window_is_pinned_at_52_percent_not_centred_on_the_needle`, `…/and_the_needle_still_sits_at_the_views_own_38_percent` (live rally frame), `…/with_no_shot_reading_the_window_stays_at_52_percent`, `…/while_the_needle_parks_on_the_references_minus_8_percent` | **closed** — the fix was already in source (integrator wave); this wave added the assertions the review said were missing, reading the rendered anchors per frame |
| 2 | `combo_glow` / `tactic_flash` computed, never rendered | `Hud.gd:129-136, 760-775` + `_apply_view` swap; theme `SegmentedFlash`; palette `combo_glow` | `hud/set_tennis_lights_the_combo_glow_at_four`, `hud/the_glow_is_the_references_10px_blur`, `hud/the_glow_colour_is_the_palettes_own_rgba_255_106_92`, `hud/a_combo_of_three_carries_no_glow`, `hud/the_glow_outline_is_zero_when_off`, `hud/a_flashing_tactic_swaps_the_chip_to_the_flash_variation`, `hud/a_settled_tactic_returns_the_chip_to_the_idle_variation`, `hud/the_tactic_chip_starts_on_the_idle_variation`; theme probe: flash fill/text/radius | **fixed here** (rendered through theme-owned values — the review's first option, not the "declare the flags dead" fallback) |
| 3 | AI score renders cyan, not `--coral` (`styles.css:625-627`) | `Hud.gd:427-429` coral override; both labels now named for the audit | `hud/the_ai_score_is_the_references_coral_not_the_title_cyan`, `hud/the_player_score_is_the_cyan_the_title_variation_carries`, `hud/the_two_score_labels_are_named_so_the_colours_can_be_read` | **closed** (source fix already present; assertions added here) |
| 4 | Actions row cannot reproduce the measured 284.52 (timer 134.52 + 3x(8+42)) | `Hud.gd:75-86` — `TIMER_SIZE (134.52, 54)`, `ACTIONS_SEPARATION 8`, `ACTIONS_WIDTH 284.52` | `hud/the_actions_row_packs_the_measured_284_52_with_the_134_52_timer_at_1280x720` (and `…_at_1152x648`): row rect, right edge at the 32 px inset, timer width, and children packing == row width | **closed** (source fix already present; the packing assertion is new — the old audit read only the outer rect) |
| 5 | Timer ball missing (`index.html:462-463`, `styles.css:750-757`) | `Hud.gd:456-460` — `TimerBall` Panel 38x38 inside the timer row, `TIMER_GAP 8`; theme `TimerBall` (fill `#d8ff5f`, border 3 px `#d9f8ff`, radius 19) | `hud/the_timer_carries_the_references_38px_ball_inside_its_own_box`; theme probe: ball fill/border/radius | **fixed here** |
| 6 | The HUD audit had never been executed; every HUD claim a static prediction | — | the suite: `uir-pre-gate-a-hud-audit.log` | **closed** — `PASS 172/172`, 0 SCRIPT ERRORs; the two blind spots the review named (window anchors unread, flags unasserted) are exactly what the new checks read |
| n1 | Menu nit: poster height derives from `HeroPreview.size.x`, unasserted | `MenuScreen.gd` (unchanged derivation) | `menu/the_caption_stays_inside_its_poster_at_*` also asserts poster width == its column | **closed as a nit** (the assumption is now asserted, the derivation kept) |
| n2 | Menu nit: `next_lang()` differs from `js/main.js:2421` for any third locale (identical for it/en) | unchanged | — | **accepted, recorded** — the locale module is frozen and the port ships it/en; changing it is outside this wave and outside the frozen scope |
| — | Review header: duplicate `MINIMAP_HEADER` and the missing font import "already with the integrator" | `Hud.gd:95` single `const MINIMAP_HEADER := 14.0` (duplicate gone); fonts probe 75/75 | `ui-fonts-probe` in the suite log | **confirmed clean** |

All six findings are therefore either fixed or verified-and-guarded; none is outstanding, and
each "already fixed" line above was confirmed in source rather than taken from a summary.

## 4. Router audit false positive (fixed, not worked around)

`UiStrings.gd` gained `var normalized := {}` (a function-local temporary, line 36) after the
wave-3 router run; the audit's flat substring `":= {"` matched it and read `FAIL 85/86` on an
untouched rule ("THIS FILE OWNS NO TABLE", `UiStrings.gd:1-13`). The check now scans
top-level declarations only — a top-level table still fails it, a local temporary does not.
`PASS 86/86`. This is a precision fix to a heuristic, not a relaxation of the rule.

## 5. Suites — the frozen tree, one certified pass

Full table, commands and the before-this-wave values: `uir-pre-gate-a-suite.log`.
19 runs, every exit code 0, **0 SCRIPT ERROR lines in every run** (read per run, never the
tally alone):

- UI lane: menu 97/97 (98/98 `--demo`), HUD 172/172, legibility 76/76, router 86/86,
  theme 271/271, fonts 75/75, data 131/131 (134/134 `--demo`), input/a11y 117/117,
  reachability 21/21.
- Baseline (UIR-00's own eight commands, unchanged): harness 8/8, slice 292/292,
  slice `--demo` 243/243, input 4/4, rules 10/10, modes 6/6, save+Steam 137/137, music 32/32
  — identical to the recorded baselines.

Deltas vs the wave-3 records are all upward and all from the new checks
(hud 151 -> 172, menu 95 -> 97, theme 254 -> 271, legibility FAIL 73/76 -> PASS 76/76,
router restored to 86/86); no pre-existing check was removed or renamed. One new check was
born failing and fixed during the wave: `hud_audit`'s first run reported `PASS 158/158` next
to one `SCRIPT ERROR` (a `Label`-typed read of the `ComboLabel` *Button*, which silently
dropped 14 checks); typed correctly, the tally is 172/172 with 0 errors — recorded because
"PASS next to a SCRIPT ERROR" is exactly how a suite lies.

## 6. Captures — regenerated, genuine, measured

11 capture runs (all exit 0, 0 SCRIPT ERRORs): menu harness at 1152x648, 1024x600 and
1280x720; the UIR-09 prototype-menu lane at 1280x720; the match/HUD lane at 1152x648,
1024x600 and 1280x720. Every menu PNG is re-checked non-vacuous by the harness on read-back
(sampled colour count 56-73). Hash: `ui-menu.png` before `1f0e32d3…` -> after `b99f1cc7…`
(the byte-identical prototype-lane frame follows, as before); full table in
`uir-pre-gate-a-captures.log`, pre-wave set preserved in `/tmp/uir-pregate/prior/`.

The 1024x600 overflow proof is three-legged: the before-log (3 FAIL lines, quoted in §2.1),
the after-log (same 76 checks, all ok, `PASS 76/76`), and the regenerated real frame
`godot/game/out/ui-menu-1024x600.png` (plus `-demo`/`-beta`). The caption fix is also proven
at the pixel level on 1280x720 (§2.2: glyph inset 52 px -> 25 px vs the reference's 24 px).

## 7. Open items, on purpose

1. **GATE-A is untouched.** No look/feel verdict is claimed anywhere; the frame notes here
   are measurements, not taste. The gate belongs to Luca.
2. **No commit/push/merge from this wave** (per the coordinator's dispatch). `godot/src/ui/**`,
   `godot/tests/ui/**` and `docs/implementation/ui-recreation/**` are untracked (`??`) in the
   working tree. The match lane rewrote the four tracked plan-lane PNGs to derive the `ui-*`
   frames; they are UIR-00's frozen before-set and were restored byte-identical (register
   sha256 re-verified, git reports them unmodified). The next single-owner integration wave
   checkpoints.
3. **The brother branch's `match_controller`/HUD timing cues are not merged here** (no merge
   while changes are in flight). `Hud.gd`/`ViewState.gd` in this tree are the local truth;
   the integration wave reconciles.
4. **The caption's 2 px box nuance** is accepted: the reference measures its 18 px from the
   padding box, the port from the panel rect (border 2 px). Invisible against the art; not
   worth a second geometry rule.
5. Navigation/menu nit n2 (§3) stays recorded, not changed.
6. `modes` keeps its own capture lane (recorded in wave 3); the harness reports it pending,
   the legibility audit `not_ported`. Unchanged, and correct until UIR-10 lands.
