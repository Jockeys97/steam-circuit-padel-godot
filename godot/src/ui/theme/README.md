# `padel_theme.tres` — the recreation's single design layer

Owner: **UIR-02** (`docs/implementation/ui-recreation/tickets/UIR-02-theme-resource.md`).
Every value here traces to a line of the frozen reference (`styles.css`, `index.html`) or to a value
measured in a real browser by UIR-06 (`docs/implementation/ui-recreation/evidence/uir-06-computed-styles.md/.json`).
Nothing in this file is a taste decision; where the reference and the engine cannot express the same
thing, the gap is listed in §6 instead of being papered over.

Screens set **type variations** (`theme_type_variation = &"ScreenTitle"`) and never carry literal
colors. The only exception the pack allows is a `custom_minimum_size`, which is geometry, not color.

## 1. Font roles (`res://assets/ui/fonts/*.ttf`, staged by UIR-01)

| theme font resource | file | reference | measured (`UIR-06`) |
|---|---|---|---|
| `FontDisplay` | `LilitaOne-Regular.ttf` | `styles.css:246` `.btn`, `:287` `.screen-header h2`, `:22` body fallback stack | `font-family: "Lilita One", cursive` on every display role |
| `FontBody` | `Nunito-Regular.ttf` | `styles.css:22` `font-family: Nunito, system-ui, sans-serif` | `Nunito, system-ui, sans-serif`, weight 400 |
| `FontBodySemiBold` | `Nunito-SemiBold.ttf` | `index.html:15` weight 600 | loaded on `screen-challenges` |
| `FontBodyBold` | `Nunito-Bold.ttf` | `styles.css:262` `.btn--ghost` `font-weight: 700` | weight 700 |
| `FontBodyExtraBold` | `Nunito-ExtraBold.ttf` | `styles.css:131` `.badge` `font-weight: 800` | weight 800 |
| `FontMono` | system fallback (`SystemFont`) | `styles.css` diagnostics stack `ui-monospace, SFMono-Regular, Menlo, monospace` | — (no download: the ticket says system fallback is fine) |

Godot's `Theme` has no letter-spacing property; `FontVariation.spacing_glyph` is the only mechanism
and it is an **integer pixel** amount, while the reference's tracking is `em`-based (so it scales with
the font size, which an integer cannot follow). Each row below is the reference's own measured
`letter-spacing` converted at its own font size and then rounded to the nearest integer pixel — the
rounding is stated in the last column, not hidden:

| theme font resource | resource id in `.tres` | base | measured `letter-spacing` | `spacing_glyph` | rounding |
|---|---|---|---|---|---|
| `FontDisplay` / `FontBody*` (plain roles) | `FontVariation_Display`, `FontVariation_Body*` | Lilita One / Nunito | `normal` | 0 | exact |
| `FontDisplayButton` | `FontVariation_DisplayButton` | Lilita One | `0.64px` (`.btn` `0.04em` @ 16 px) | 1 | +0.36 px/glyph |
| `FontDisplaySecondary` | `FontVariation_DisplaySecondary` | Lilita One | `0.576px` (`.btn--secondary` @ 14.4 px) | 1 | +0.42 px/glyph |
| `FontBodyBoldButton` | `FontVariation_BodyBoldButton` | Nunito 700 | `0.544px` (`.btn--ghost` @ 13.6 px) | 1 | +0.46 px/glyph |
| `FontBadge` | `FontVariation_Badge` | Nunito 800 | `0.8704px` (`.badge` `0.08em`) | 1 | +0.13 px/glyph |
| `FontLabelSmall` | `FontVariation_LabelSmall` | Nunito 800 | `1.12px` (`.setup-group__label` `0.1em`) | 1 | −0.12 px/glyph |
| `FontSegmented` | `FontVariation_Segmented` | Nunito 800 | `0.3264px` (`.segmented button` `0.03em`) | 0 | −0.33 px/glyph |
| `FontTag` | `FontVariation_Tag` | Nunito 800 | `0.6528px` (`.mode-card__tag` `0.06em`) | 1 | +0.35 px/glyph |
| `FontHudLabel` | `FontVariation_HudLabel` | Nunito 800 | `0.7424px` (`.game-hud__label` `0.08em`) | 1 | +0.26 px/glyph |

**Weight 900 delta (recorded, not hidden):** the reference asks Nunito for weight 900 in `.segmented
button`, `.setup-group__label`, `.game-hud__label` and `.lang-toggle`. UIR-01 staged 400/600/700/800
(the ticket's list) and the link in `index.html:13-16` also only requests 400/600/700/800, so the
browser substitutes the closest available face — measured `font-weight: 900` is the *requested* value,
the *rendered* face is Nunito ExtraBold (800). `FontBodyExtraBold` therefore reproduces what the
reference actually renders; the rule is not silently simplified.

`fallbacks`: every role font is a `FontVariation` whose `fallbacks` array holds one `SystemFont`
(no explicit names → the engine's default UI font), mirroring `Nunito, system-ui, sans-serif`
(`styles.css:22`). This is what draws the symbols/emoji the latin font subsets do not carry
(UIR-01 §1 finding 2).

## 2. Palette — `:root` tokens (`styles.css:1-13`), verbatim

The palette lives in the theme as plain colour entries under the type name `Palette` (a data
namespace, not a node-attachable variation: screens read it with `theme.get_color("cyan", "Palette")`).
It is deliberately **not** declared as a type variation, so nothing can attach it to a Control and
shadow the layout types.

| theme color (`Palette` type) | value | source |
|---|---|---|
| `ink` | `#f6f7fb` | `styles.css:3` |
| `muted` | `rgba(255,255,255,0.48)` | `styles.css:4` |
| `panel` | `#111540` | `styles.css:5` |
| `line` | `rgba(255,255,255,0.12)` | `styles.css:6` |
| `cyan` | `#00e5ff` | `styles.css:7` |
| `gold` | `#ffcc00` | `styles.css:8` |
| `coral` | `#ff4b6e` | `styles.css:9` |
| `green` | `#1aff8a` | `styles.css:10` |
| `bg` | `#07072a` | `styles.css:11` |
| `shadow` | `rgba(0,0,0,0.45)` (text form `0 24px 80px rgba(0,0,0,0.45)`) | `styles.css:12` |

`--pink` is **not** defined (`styles.css:1-13`) and `styles.css:473` references it: measured in UIR-06,
the declaration is dropped and `var(--mode-accent, var(--cyan))` at `styles.css:463` renders the
**cyan** fallback. The career card therefore uses `cyan`, exactly like quick-match. Do not add a
`pink` token to this theme; that would be inventing a color the reference does not render.

## 3. Semantic colors the screen rules use (each one measured by UIR-06, or read from the line cited)

| theme color (`Palette` type) | value | source / measured on |
|---|---|---|
| `surface_0` | `#061426` | `styles.css:2249` (`#difficultySeg … color: #061426`), measured as `rgb(6,20,38)` |
| `surface_1` | `#091d39` | `styles.css:2216` `.segmented` background, measured `rgb(9,29,57)` |
| `surface_2` | `#0b2444` | `styles.css` (`0b2444`, 2 occurrences) |
| `surface_3` | `#0b3152` | `styles.css` (`0b3152`, 4 occurrences) |
| `surface_4` | `#10365f` | `styles.css` `.hud-pause` background, measured `rgb(16,54,95)` |
| `surface_5` | `#173b61` | `styles.css` `.hud-pause` border, measured `rgb(23,59,97)` |
| `text_soft` | `#bdeeff` | `styles.css` `.setup-group__label` color, measured `rgb(189,238,255)` |
| `text_soft_2` | `#9ef8ff` | `styles.css` (4 occurrences) |
| `text_soft_3` | `#7ef3ff` | measured on `.lang-toggle` `rgb(126,243,255)`, `#comboDisplay` tier 1 (`js/ui.js:1333`) |
| `state_yellow` | `#fff36a` | measured on `.scoreboard__control` `rgb(255,243,106)`, `.hud-pause` color |
| `state_yellow_soft` | `#ffd98a` | `styles.css` (3 occurrences) |
| `rival_soft` | `#ffc09a` | `styles.css` (3 occurrences) |
| `rival` | `#ff9a5c` | `styles.css` (2 occurrences), combo tier 4 (`js/ui.js:1333`) |
| `success` | `#b9ffe0` | `styles.css` (1 occurrence) |
| `success_cyan` | `#8fffd0` | measured on `.scoreboard__tactic` `rgb(143,255,208)`, combo tier 2 |
| `combo_1` | `#7ef3ff` | `js/ui.js:1333` |
| `combo_2` | `#8fffd0` | `js/ui.js:1333` |
| `combo_3` | `#ffe066` | `js/ui.js:1333-1335` |
| `combo_4` | `#ff9a5c` | `js/ui.js:1333` |
| `combo_default` | `#ff6d70` | `js/ui.js:1335` |
| `tab_border` | `#28567d` | `styles.css:2215` `.segmented` border, measured `rgb(40,86,125)` |
| `tab_text_idle` | `#809bb6` | `styles.css:2233` `.segmented button` color |
| `secondary_button` | `#1c6eb0` | `styles.css:270` `.btn--secondary` background |
| `button_gradient_start` | `#00d4f0` | `styles.css:252` `linear-gradient(135deg, #00d4f0, #00b4cc)` first stop (fill used, see §6) |
| `segmented_gradient_start` | `#22d5ee` | `styles.css:2249` `linear-gradient(180deg, #22d5ee, #16bed7)` first stop (fill used, see §6) |
| `hud_panel_bg` | `rgba(6,24,46,0.82)` | `styles.css:557` `.scoreboard, .game-timer, .mini-map` |
| `hud_panel_border` | `#1c507e` | `styles.css:556` |
| `hud_label` | `#dcefff` | `styles.css:606` `.game-hud__label`, measured `rgb(220,239,255)` |
| `hint_bg` | `rgba(9,29,57,0.7)` | measured on `.setup-group__hint` `rgba(9, 29, 57, 0.7)` |
| `tag_idle` | `rgba(255,255,255,0.35)` | `styles.css` `.mode-card__tag` color |
| `fixture` | `rgba(255,255,255,0.42)` | `styles.css` `.mode-card__fixture` color, measured `rgba(255,255,255,0.42)` |
| `ghost_text` | `rgba(255,255,255,0.65)` | `styles.css:261` `.btn--ghost` color, measured `rgba(255,255,255,0.65)` |
| `nav_bg` | `#050516` (97%) | `styles.css:90` `.top-nav` `background: rgba(5, 5, 22, 0.97)` — added 2026-09-17 (integration wave) for the UIR-07 menu chrome; the theme owner's follow-up is to give it a variation, see §7 |
| `caption_shadow` | `#07152b` | `styles.css:215` `.hero-poster__title` `text-shadow: 0 3px 0 #07152b` — same addition; the caption's second (cyan glow) shadow is not expressible, see §6 |
| `poster_fade` | `#030719` (82%) | `styles.css:194` `.hero-poster::after` `linear-gradient(180deg, transparent, rgba(3, 7, 25, 0.82))` — same addition; the gradient itself is rendered screen-side from this token (first stop) |
| `combo_glow` | `#ff6a5c` (80%) | `js/ui.js:1315` — the combo's `textShadow: 0 0 10px rgba(255, 106, 92, 0.8)` at `combo >= 4`; added 2026-09-17 (pre-gate wave) because the flag was computed and never painted. Read by `Hud` through `_palette("combo_glow")` |
| `win_green` | `#3fd36f` | `styles.css:2662,2697` (history stat box wins `b`, history item result) — added 2026-09-17 (wave 3) from UIR-13's recorded seam; read by history/profile |
| `win_ink` | `#04210f` | `styles.css:2697` (history item result chip ink) — same addition |
| `loss_red` | `#ff5d7a` | `styles.css:2663,2698` — same addition |
| `loss_ink` | `#21040a` | `styles.css:2698` — same addition |
| `trophy_yellow` | `#ffd23a` | `styles.css:2664` (history stat box trophies `b`) — same addition |
| `stat_muted` | `#6f91ad` | `styles.css:2655,2704,2717,2722` (history stat box labels, profile boxes) — same addition |
| `item_ink` | `#e6f8ff` | `styles.css:2702` (history item text) — same addition |
| `help_muted` | `#8aa5bc` | `styles.css:2437,2623` (help card body, keyboard-guide rows) — same addition |
| `kbd_border` | `#29c9dc` | `styles.css:1727` (help keyboard guide `kbd` border) — same addition |
| `white` | `#ffffff` (base for the reference's `rgba(255,255,255,α)` hairlines/labels: α .03 `:1321`, .05 `:1234`, .55 `:1237`, .72 `:1263`) | profile's `white@α` reads; added with the same wave |
| `challenge_cyan` | `#78c8ff` | `styles.css:3216,3267` (`rgba(120,200,255,α)` rules; hex base) — same addition |
| `challenge_row_fill` | `rgba(8,16,44,0.5)` | `styles.css:3217` (challenge row background) — same addition |
| `challenge_done_border` | `rgba(255,210,120,0.4)` | `styles.css:3222` (completed challenge row border) — same addition |
| `challenge_done_fill` | `rgba(60,42,8,0.28)` | `styles.css:3223` (completed challenge row background) — same addition |
| `summary_fill` | `rgba(8,22,48,0.6)` | `styles.css:3592` (profile career summary panel) — same addition |
| `stat_bar` | `#7ee0ff` | `styles.css:3026` `.stat-bar` (UIR-11's stat strip) — added 2026-09-17 (wave 3) with the strip itself |
| `stat_bar_rival` | `#ffb08c` | `styles.css:3030` `.team-slot--rival .stat-bar` — same addition |
| `focus_pulse` | `#a5ffe0` | `styles.css:742` — `@keyframes menu-focus-pulse` 50 % frame, the colour the pad's `.menu-focus` outline (`:733-738`) travels to. Read by `godot/src/ui/components/CardFocusRing.gd`; the ring itself is composed at run time from `cyan` + this token, not added as a variation, because it is drawn OUTSIDE the card's own box (see §6.11) |

## 4. Type variations (names fixed here; screens use these strings)

| variation | base type | font | size | color | reference |
|---|---|---|---|---|---|
| `ScreenTitle` | `Label` | `FontDisplay` | 38 *(measured 38.4, −0.4)* | `ink` | `.screen-header h2` `2.4rem` (measured `38.4px`, weight 700 requested → display face) |
| `ScreenSubtitle` | `Label` | `FontBody` | 16 | `muted` | `.screen-header p` color `var(--muted)` (measured) |
| `HeroTitle` | `Label` | `FontDisplay` | 64 *(measured 64.0, exact)* | `ink` | `.hero h1` (measured `64px` = `clamp(2.4rem,5vw,4rem)` at 1280 px) |
| `CardTitle` | `Label` | `FontDisplay` | 18 *(measured 17.6, +0.4)* | `ink` | `.mode-card h3` (measured `17.6px`) |
| `CardTitleActive` | `Label` | `FontDisplay` | 18 *(measured 17.6, +0.4)* | `cyan` | `.athlete-card__body h3` (measured `rgb(0,229,255)`) |
| `CardBody` | `Label` | `FontBody` | 13 *(measured 13.12, −0.12)* | `muted` | `.athlete-card__desc, .mode-card p, .arena-card__body p` `0.82rem` (measured `13.12px`) |
| `LabelSmall` | `Label` | `FontLabelSmall` | 11 *(measured 11.2, −0.2)* | `text_soft` | `.setup-group__label` (measured `11.2px`, uppercase, `ls 1.12px`) |
| `Badge` | `Label` | `FontBadge` | 11 *(measured 10.88, +0.12)* | `ink` | `.badge` (measured `10.88px`, weight 800, `ls 0.8704px`) |
| `Tag` | `Label` | `FontTag` | 11 *(measured 10.88, +0.12)* | `tag_idle` | `.mode-card__tag` (measured uppercase, `ls 0.6528px`); `TagReady` = `green` (`.mode-card__tag--ready`) |
| `HudLabel` | `Label` | `FontHudLabel` | 9 *(measured 9.28, −0.28)* | `hud_label` | `.game-hud__label` (measured, uppercase) |
| `HudTitle` | `Label` | `FontDisplay` | 24 | `cyan` | `.game-hud strong`, `.scoreboard__teams strong` (measured `24px`) |
| `ButtonPrimary` | `Button` | `FontDisplayButton` | 16 *(measured 16.0, exact)* | `#000` | `.btn--primary` (measured `16px`, color `rgb(0,0,0)`) |
| `ButtonSecondary` | `Button` | `FontDisplaySecondary` | 14 *(measured 14.4, −0.4)* | `#fff` | `.btn--secondary` (measured `14.4px`) |
| `ButtonGhost` | `Button` | `FontBodyBoldButton` | 14 *(measured 13.6, +0.4)* | `ghost_text` | `.btn--ghost` (measured `13.6px`, weight 700) |
| `SegmentedInactive` | `Button` | `FontSegmented` | 11 *(measured 10.88, +0.12)* | `tab_text_idle` | `.segmented button` (measured `10.88px`, weight 900 → ExtraBold) |
| `SegmentedActive` | `Button` | `FontSegmented` | 11 *(measured 10.88, +0.12)* | `surface_0` | `.segmented button.is-active` (measured color `rgb(6,20,38)`) |
| `HudButton` | `Button` | `FontDisplay` | 19 *(measured 19.2, −0.2)* | `state_yellow` | `.hud-pause` (measured `19.2px`, `rgb(255,243,106)`) |
| `HudButtonActive` | `Button` | `FontDisplay` | 19 | `hud_button_active_text` | measured `#panelBtn` (`.hud-pause--panel`) background `rgb(0,229,255)`, text `#04203a` |
| `Mono` | `Label` | `FontMono` | 14 | `text_soft` | diagnostics only: the stylesheet's monospace stack (no reference size to measure; the pack's own diagnostics use it) |
| `PanelDark` | `Panel` | — | — | — | `--panel` + `--line` + radius 12 (cards, `BoxPanelDark`) |
| `PanelCardHover` | `Panel` | — | — | — | `.mode-card:hover` border `rgba(0,229,255,0.35)` (`BoxPanelHover`) |
| `PanelCardSelected` | `Panel` | — | — | — | `.athlete-card--selected` cyan border + 1 px cyan ring (`BoxPanelSelected`) |
| `HudPanel` | `Panel` | — | — | — | `.scoreboard` (measured radius 8, border `#1c507e`, bg `rgba(6,24,46,0.82)`, `BoxHudPanel`) |
| `HudPauseCard` | `Panel` | — | — | — | `.pause-card` (measured radius 8, padding `26/30/30/30`, bg `#111540`, `BoxPauseCard`) |
| `SegmentedContainer` | `Panel` | — | — | — | `.segmented` container fill/border/radius/padding (`BoxSegmentedContainer`) |
| `SegmentedFlash` | `Button` | `FontSegmented` | 11 | `#071d34` | `.scoreboard__tactic.is-flashing` (`styles.css:678-681`: fill `#8fffd0`, color `#071d34`) — the tactic chip's flashing state, a class swap in `js/ui.js:1309`, a variation swap in `Hud` |
| `TimerBall` | `Panel` | — | — | — | `.game-timer__ball` (`styles.css:750-757`: 38x38 including the 3 px `#d9f8ff` border, fill `#d8ff5f`, radius 19; `box-sizing: border-box` at `styles.css:15-17`), `index.html:462-463` |
| `TagReady` | `Label` | `FontTag` | 11 *(measured 10.88, +0.12)* | `green` | `.mode-card__tag--ready` (measured `rgb(26,255,138)`) |

Theme defaults: `default_font = FontBody`, `default_font_size = 16`, `Panel/styles/panel = PanelDark`,
`Label/colors/font_color = ink`, `Button/fonts/font = FontDisplay`, `Button/font_sizes/font_size = 16`.
**Delta vs the old port:** `godot/game/main_menu.gd` used 17–19 px for menu text; the reference's own
root/body size is **16 px** (measured), and all rem-derived sizes above are computed from that 16 px
root. The measured value wins, per the ticket's rule.

## 5. Styleboxes

| variation / state | stylebox | value | reference |
|---|---|---|---|
| `ButtonPrimary` normal | `BoxButtonPrimary` | fill `#00d4f0`, radius 10, padding 16/28, shadow `rgba(0,229,255,0.5)` offset `(0,6)` size 28 | `.btn--primary` (measured), `styles.css:251-256` |
| `ButtonPrimary` hover / pressed | `BoxButtonPrimary` | *same box* | the stylesheet declares **no** `.btn:hover` / `.btn:active` rule (checked line by line); reproducing the reference means hover must not change the button |
| `ButtonSecondary` normal | `BoxButtonSecondary` | fill `#1c6eb0`, radius 10, padding 12/18, no shadow | `.btn--secondary` (measured), `styles.css:268-273` |
| `ButtonGhost` normal | `BoxButtonGhost` | transparent (`draw_center=false`), no border, padding 10/16 | `.btn--ghost` (measured) |
| `Button*` disabled | `BoxButtonDisabled` | fill with alpha 0.4, no shadow | `.btn:disabled` `opacity: 0.4` (`styles.css:275-278`) — closest expressible form, see §6 |
| `SegmentedInactive` normal | `BoxSegmentedIdle` | transparent, radius 7, padding 0/6 | `.segmented button` (measured) |
| `SegmentedActive` normal | `BoxSegmentedActive` | fill `#22d5ee`, radius 7, shadow `rgba(22,190,215,0.42)` size 16, inset top highlight not expressible | `.segmented button.is-active` (measured), `styles.css:2248-2252` |
| segmented container | `BoxSegmentedContainer` | fill `#091d39`, border 1 px `#28567d`, radius 10, padding 5 | `.segmented` (measured) |
| `PanelDark` / cards | `BoxPanelDark` | fill `#111540`, border 1 px `rgba(255,255,255,0.12)`, radius 12, padding 18 | `.athlete-card, .mode-card, .arena-card` (measured) |
| card hover | `BoxPanelHover` | same, border `rgba(0,229,255,0.35)` | `.mode-card:hover` (`styles.css:330-334`) |
| card selected | `BoxPanelSelected` | same, border `cyan` + 1 px cyan ring | `.athlete-card--selected` (`styles.css:337-340`) |
| `Tag`-like chip | `BoxBadge` | fill `rgba(255,255,255,0.06)`, border 1 px `line`, radius 20, padding 5/16 | `.badge` (measured) |
| `HudPanel` | `BoxHudPanel` | fill `rgba(6,24,46,0.82)`, border 1 px `#1c507e`, radius 8, shadow `rgba(0,0,0,0.35)` offset `(0,4)` size 14 | `.scoreboard` (measured), `styles.css:553-560` |
| `HudButton` | `BoxHudButton` | fill `#10365f`, border 3 px `#173b61`, radius 8, shadow `rgba(4,22,43,0.48)` offset `(0,5)` size 5 | `.hud-pause` (measured) |
| `HudButtonPanelActive` | `BoxHudButtonActive` | fill `cyan`, text `#04203a` | measured `#panelBtn` (`hud-pause--panel`) background `rgb(0,229,255)` |
| `HudPauseCard` | `BoxPauseCard` | fill `#111540`, border 1 px `line`, radius 8, padding 26/30/30/30, shadow `rgba(0,0,0,0.5)` offset `(0,24)` size 70 | `.pause-card` (measured), `styles.css:1100-1110` |
| `SegmentedFlash` normal | `BoxSegmentedFlash` | fill `#8fffd0`, radius 7, padding 0/6 (the idle chip's own box) | `.scoreboard__tactic.is-flashing` (`styles.css:678-681`) |
| `TimerBall` | `BoxTimerBall` | fill `#d8ff5f`, border 3 px `#d9f8ff`, radius 19 (a 38 px circle), no shadow | `.game-timer__ball` (`styles.css:750-757`); the inset crescent shadow is not expressible, see §6.2 |

## 6. Gaps between the reference and Godot 4.7 — recorded, not filled

1. **Gradients.** `.btn--primary` and `.segmented button.is-active` fill with `linear-gradient(...)`;
   `StyleBoxFlat` has no gradient and the gradient-bearing `StyleBoxTexture` has no corner radius or
   shadow, and a Godot `Button` can only carry one stylebox per state. The theme therefore fills with
   the gradient's **first stop** (`#00d4f0`, `#22d5ee`) and keeps the measured radius, padding and
   glow. Both stops are measured; neither is a new color. If the diagonal shade matters at GATE-A, the
   alternative is a `StyleBoxTexture` (gradient, square corners, no glow) — a trade the verdict owner
   makes, not this file.
2. **Two shadows / inset shadows.** `.pause-card` has an outer shadow *and* a cyan glow; `.segmented`
   has an inset shadow; `.scoreboard__title` and the primary button combine a gradient with a glow.
   `StyleBoxFlat` supports exactly one shadow and no inset. The primary shadow is implemented, the
   second/inset one is not. `backdrop-filter: blur(3px)` (`.scoreboard`) has no theme equivalent.
3. **Blur → `shadow_size` mapping.** CSS `blur` px is mapped 1:1 to `StyleBoxFlat.shadow_size`, offset
   1:1 to `shadow_offset`. The mapping is a mechanism, not a measured equivalence (the two renderers
   differ); it is flagged here and is one of the things the probe's captures exist to let a human
   judge.
4. **`opacity: 0.4` on disabled buttons** is emulated with a 40 %-alpha fill plus a 40 %-alpha text
   color, because a stylebox cannot modulate the node.
5. **`#hud-pause` is 42×42 px and `.logo`/`.lang-toggle` sizes come from fixed `width`/`height` rules.**
   Those are layout rules, not theme items: screens set `custom_minimum_size` (allowed: it is geometry).
6. **`letter-spacing` values are baked into role fonts** (§1). Changing a variation's font changes its
   tracking; the README is the map.
7. **`--pink`** — see §2: it renders as cyan through the `var()` fallback; the theme carries no pink.
8. **Integer font sizes.** `Theme` font sizes are integers, so four measured sizes cannot be stored
   verbatim: 38.4 → 38, 17.6 → 18, 13.12 → 13, 11.2 → 11, 10.88 → 11, 9.28 → 9, 14.4 → 14, 13.6 → 14,
   19.2 → 19. §4 shows each delta next to its value; the deltas are ≤ 0.4 px. `spacing_glyph` is integer
   too (§1).
9. **Scaling.** The reference's sizes are `rem`-based, so the whole interface scales with the root font
   size; a Godot `Theme` holds absolute px sizes. The port therefore does not follow a hypothetical root
   change. This matters only if a later ticket decides to scale the UI — nothing in this pack does.
10. **`text-shadow` stacks.** The reference writes them at run time (`js/ui.js:1315` combo glow,
    `styles.css:215` caption shadow). A Godot `Label` has one `font_shadow_color` plus offsets and
    `shadow_outline_size`: the combo glow is rendered as the shadow colour with the CSS blur mapped to
    the outline size 1:1 (the §6.3 mechanism), and a two-shadow stack (`0 3px 0 #07152b, 0 0 16px rgba(...)`)
    keeps only its offset component. Recorded for the GATE-A read, not treated as equivalent.
11. **`outline` / `outline-offset` is not a theme variation.** `.menu-focus` (`styles.css:733-738`)
    paints a 3 px `cyan` ring 3 px OUTSIDE the element. `StyleBoxFlat.expand_margin_*` is the one
    Godot mechanism that paints outside a control's rect without changing the space it occupies
    (measured: `get_minimum_size()` returns the content margins alone), so the ring CAN be drawn —
    but it cannot live on the card's own `Panel` variation, because that variation is the card's
    frame and a stylebox carries one border and one shadow. `godot/src/ui/components/CardFocusRing.gd`
    therefore composes it at run time from `cyan` + `focus_pulse` as a child overlay. The keyframe
    colour is the only value this needed and it is the §3 row above.

## 7. How this is proven

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/theme_probe.gd ; echo "exit=$?"
```

`godot/tests/ui/theme_probe.gd` mounts one instance of every variation in a labelled grid, asserts each
one resolves with the values above, drives the layout at 1280×720, 1152×648, 1920×1080 and 1024×600,
prints the computed contrast ratios, and ends with a single `PASS n/n` line (exit 0) or `FAIL n/n`
(exit 1), the port's standard contract (`godot/tests/smoke_test.gd:7-14`).
`godot/tests/ui/theme_probe.tscn` is the mountable version of the same grid (no script attached, so it
cannot run headlessly): it exists for UIR-09/UIR-24 to capture once captures exist.

**Open follow-up for the theme owner (opened 2026-09-17 by the integration wave).** UIR-07's screen
needed chrome this theme has no variation for — `.top-nav` (bar + its buttons + the language toggle),
`.badge`'s dot, `.hero p` / `.hero-hint`, the `.hero-tags` chips (radius 6, not `BoxBadge`'s 20),
`.hero-poster` (with its fade overlay) and the `.hero-poster__title` caption. The screen composes
those styleboxes at run time from `Palette` colours (`godot/src/ui/screens/MenuScreen.gd`, section
"menu chrome") and carries no literal colour of its own; the three palette rows added to §3 are the
only new theme values. The theme's next owner should fold that composition into variations
(`TopNav`, `NavButton`, `LangToggle`, `HeroHint`, `HeroTag`, `HeroPoster`, `HeroCaption`, …) so the
menu can set type variations like every other screen.
