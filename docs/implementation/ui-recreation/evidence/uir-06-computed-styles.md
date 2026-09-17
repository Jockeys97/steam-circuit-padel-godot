# UIR-06 evidence: reference computed styles and pixel captures

- Ticket: UIR-06 (`docs/implementation/ui-recreation/tickets/UIR-06-computed-styles.md`)
- Measured (UTC): 2026-09-16T22:04:08Z
- Data file: `docs/implementation/ui-recreation/evidence/uir-06-computed-styles.json` (604890 bytes)
- Captures: `docs/implementation/ui-recreation/evidence/reference-captures/` (16 PNG)
- Status: measured; `screen-result` is NOT statically reachable (recorded below, not invented)

## How it was measured (rerunnable)

```bash
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
python3 -m http.server 8765 --bind 127.0.0.1     # read-only static serve of the frozen build
# browser: chrome-headless-shell (HeadlessChrome/151.0.7922.34) driven over CDP
# viewport forced to exactly 1280x720, deviceScaleFactor 1, mobile false
# script: measure.js, embedded in the appendix; PNGs via Page.captureScreenshot
```

Every screen state was produced by clicking the reference's own declared controls (`[data-action="to-…"]` buttons, `.athlete-card`, `[data-team-confirm]`, `.arena-card`, `#panelBtn`, `[data-action="pause"]`). No code was added to the page; nothing under `js/`, `index.html`, `styles.css`, `assets/` was written.

Fonts came from Google Fonts over the network (`document.fonts.status = "loaded"` after `document.fonts.ready`), so the captures show the real typeface, not a fallback.

### Provenance: hashes of the measured reference (sha256)

| file | sha256 |
|---|---|
| `index.html` | `b4993384b0b203b5f6f0ff339865210e70281d7ed82027b7d37ced6b22c1b9dd` |
| `styles.css` | `9c5ddb56ac9bff42fa1345dbe4e73835d31954b914ec804bb74535981c9b0ae6` |
| `js/ui.js` | `eef9e85296b6e7eda5327610e239cd9371556a6e6c954286e7a762546c00318e` |
| `js/data.js` | `dca8fe0abe4e1b890541b2c9bae278af040ec0c06a2d3a2e4e2e355eff434a53` |
| `js/main.js` | `d1e2d3d20b37395eb1e9fbd3ad8e1dc83c3fc392e75711380fc93b48306a4e0a` |

## 1. The `--pink` chain (measured; the known unknown)

`styles.css:473` sets `--mode-accent: var(--pink)` on `.mode-card__art--career`, and `--pink` is **not defined anywhere** (`:root` at `styles.css:1-13` lists `--ink --muted --panel --line --cyan --gold --coral --green --bg --shadow` only). The single consumer of `--mode-accent` is `styles.css:463`:

```css
.mode-card__art { border-bottom: 3px solid var(--mode-accent, var(--cyan)); }
.mode-card__art--quick { --mode-accent: var(--cyan); ... }
.mode-card__art--tournament { --mode-accent: var(--gold); ... }
.mode-card__art--career { --mode-accent: var(--pink); ... }
```

Raw computed results, quoted verbatim (viewport 1280x720, screen `screen-modes`):

| probe | `.mode-card__art--quick` | `.mode-card__art--tournament` | `.mode-card__art--career` |
|---|---|---|---|
| `getPropertyValue('--mode-accent')` on the element | `#00e5ff` | `#ffcc00` | *(empty string)* |
| `getPropertyValue('--pink')` on the element | *(empty string)* | *(empty string)* | *(empty string)* |
| `border-bottom-color` | `rgb(0, 229, 255)` | `rgb(255, 204, 0)` | `rgb(0, 229, 255)` |
| `border-bottom-style` | `solid` | `solid` | `solid` |
| `border-bottom-width` | `3px` | `3px` | `3px` |
| `border-top-color` | `rgb(246, 247, 251)` | `rgb(246, 247, 251)` | `rgb(246, 247, 251)` |
| `background-color` | `rgb(9, 20, 46)` | `rgb(9, 20, 46)` | `rgb(9, 20, 46)` |
| `background-image` | `url("http://127.0.0.1:8765/assets/ui/modes/quick-match.webp")` | `url("http://127.0.0.1:8765/assets/ui/modes/tournament.webp")` | `url("http://127.0.0.1:8765/assets/ui/modes/career.webp")` |
| `box-shadow` | `rgba(2, 8, 24, 0.88) 0px -30px 34px -28px inset` | `rgba(2, 8, 24, 0.88) 0px -30px 34px -28px inset` | `rgba(2, 8, 24, 0.88) 0px -30px 34px -28px inset` |

- On `document.documentElement`: `getPropertyValue('--pink')` = `""` and `getPropertyValue('--mode-accent')` = `""` (both empty: neither is declared on `:root`); the declared tokens read back normally, e.g. `--cyan` = `#00e5ff`, `--gold` = `#ffcc00`.

**Conclusion (what a browser actually renders, to be reproduced 1:1):** `--pink` is undefined, so the declaration `--mode-accent: var(--pink)` is **invalid at computed-value time** and the custom property computes to the empty string on the career element (measured: `""`). `var(--mode-accent, var(--cyan))` then uses its declared fallback, so the career card's bottom border renders **`rgb(0, 229, 255)` — the same `#00e5ff` cyan as the quick-match card**. The tournament card is the only one that differs (`rgb(255, 204, 0)`, `#ffcc00`). Nothing else on the career card changes: it renders exactly like the quick-match card apart from its artwork. There is no "missing color" to repair and no distinct career accent to infer — a faithful port paints the career art's bottom border cyan.

Every consumer of `--mode-accent` in `styles.css` (exhaustive; `grep -n -- "--mode-accent" styles.css`):

| line | text | computed result |
|---|---|---|
| `styles.css:463` | `border-bottom: 3px solid var(--mode-accent, var(--cyan));` | quick `#00e5ff`, tournament `#ffcc00`, career `#00e5ff` (fallback) |
| `styles.css:471` | `--mode-accent: var(--cyan);` (`.mode-card__art--quick`) | `#00e5ff` |
| `styles.css:472` | `--mode-accent: var(--gold);` (`.mode-card__art--tournament`) | `#ffcc00` |
| `styles.css:473` | `--mode-accent: var(--pink);` (`.mode-card__art--career`) | empty string (dropped) |

`#comboDisplay` colors are not in the stylesheet: `js/ui.js:1333-1335` defines `{1:'#7ef3ff',2:'#8fffd0',3:'#ffe066',4:'#ff9a5c'}`, default `#ff6d70`. Measured on the running match at combo x1: computed `color` = `rgb(126, 243, 255)`, i.e. `#7ef3ff`, the map's tier-1 value (`#ff6d70` is the default for any combo count outside the map).

## 2. Type roles (computed, viewport 1280x720, root font-size 16px)

| selector | screen measured | font-family | font-size | weight | letter-spacing | line-height | text-transform | color |
|---|---|---|---|---|---|---|---|---|
| `.screen-header h2` | `screen-characters` | "Lilita One", cursive | 38.4px | 700 | normal | normal | none | rgb(246, 247, 251) |
| `.screen-header p` | `screen-characters` | Nunito, system-ui, sans-serif | 16px | 400 | normal | normal | none | rgba(255, 255, 255, 0.48) |
| `.hero h1` | `screen-menu` | "Lilita One", cursive | 64px | 700 | normal | 69.12px | none | rgb(246, 247, 251) |
| `.hero p` | `screen-menu` | Nunito, system-ui, sans-serif | 16px | 400 | normal | 26.4px | none | rgba(255, 255, 255, 0.55) |
| `.btn` | `screen-menu` | "Lilita One", cursive | 16px | 400 | 0.64px | normal | none | rgb(0, 0, 0) |
| `.btn--primary` | `screen-menu` | "Lilita One", cursive | 16px | 400 | 0.64px | normal | none | rgb(0, 0, 0) |
| `.btn--secondary` | `screen-menu` | "Lilita One", cursive | 14.4px | 400 | 0.576px | normal | none | rgb(255, 255, 255) |
| `.btn--ghost` | `screen-characters` | Nunito, sans-serif | 13.6px | 700 | 0.544px | normal | none | rgba(255, 255, 255, 0.65) |
| `.segmented button` | `screen-modes` | Nunito, sans-serif | 10.88px | 900 | 0.3264px | normal | none | rgb(6, 20, 38) |
| `.segmented button.is-active` | `screen-modes` | Nunito, sans-serif | 10.88px | 900 | 0.3264px | normal | none | rgb(6, 20, 38) |
| `.athlete-card__body h3` | `screen-characters` | "Lilita One", cursive | 17.6px | 700 | normal | normal | none | rgb(0, 229, 255) |
| `.mode-card h3` | `screen-modes` | "Lilita One", cursive | 17.6px | 700 | normal | normal | none | rgb(246, 247, 251) |
| `.scoreboard__teams strong` | `screen-game` | "Lilita One", cursive | 24px | 700 | normal | 24px | none | rgb(0, 229, 255) |
| `.scoreboard__title` | `screen-game` | "Lilita One", cursive | 11.52px | 400 | 1.8432px | normal | none | rgb(6, 20, 38) |
| `.scoreboard__meta span` | `screen-game` | "Lilita One", cursive | 8.96px | 400 | normal | normal | none | rgb(255, 243, 106) |
| `.hud-pause` | `screen-game` | "Lilita One", cursive | 19.2px | 400 | normal | 19.2px | none | rgb(255, 243, 106) |
| `.result-card h2` *(hidden subtree)* | `screen-menu` | "Lilita One", cursive | 48px | 700 | normal | normal | none | rgb(0, 229, 255) |
| `.drill-hud__box b` | `screen-drill` | "Lilita One", cursive | 24px | 700 | normal | normal | none | rgb(246, 247, 251) |
| `.top-nav .brand span` | `screen-menu` | "Lilita One", cursive | 16px | 400 | 0.64px | normal | none | rgb(0, 229, 255) |

Notes: `.segment button.is-active` (the ticket's spelling) matches **no element** — the real selector is `.segmented button.is-active` (`styles.css:2248`), measured above. Values marked *(hidden subtree)* were computed on a `display:none` screen (`screen-result` is unreachable, see section 6): font-family/size/weight/letter-spacing/colour still resolve from the cascade, but no layout-derived value for those is claimed.

## 3. Semantic pixels

| selector | screen measured | color | background-color | border-top-color | background-image |
|---|---|---|---|---|---|
| `.scoreboard__control` | `screen-game` | rgb(255, 243, 106) | rgb(23, 59, 97) | rgb(255, 243, 106) | `none` |
| `.scoreboard__tactic` | `screen-game` | rgb(143, 255, 208) | rgb(16, 47, 80) | rgb(143, 255, 208) | `none` |
| `.mode-card__tag--ready` | `screen-modes` | rgb(26, 255, 138) | rgba(0, 0, 0, 0) | rgb(26, 255, 138) | `none` |
| `.athlete-card__role` | `screen-characters` | rgba(255, 255, 255, 0.48) | rgba(0, 0, 0, 0) | rgba(255, 255, 255, 0.48) | `none` |
| `.athlete-card__special` | `screen-characters` | rgb(0, 229, 255) | rgba(0, 0, 0, 0) | rgb(0, 229, 255) | `none` |
| `.result-objectives__check` | `screen-profile` | rgba(255, 255, 255, 0.48) | rgba(0, 0, 0, 0) | rgba(255, 255, 255, 0.48) | `none` |
| `.setup-group__hint` | `screen-arena` | rgb(179, 223, 240) | rgba(9, 29, 57, 0.7) | rgb(179, 223, 240) | `none` |
| `.badge` | `screen-menu` | rgb(246, 247, 251) | rgba(255, 255, 255, 0.06) | rgba(255, 255, 255, 0.12) | `none` |
| `.lang-toggle` | `screen-menu` | rgb(126, 243, 255) | rgb(11, 36, 68) | rgb(40, 86, 125) | `none` |
| `.hero-tags span` | `screen-menu` | rgb(255, 204, 0) | rgba(255, 255, 255, 0.06) | rgba(255, 204, 0, 0.55) | `none` |
| `.demo-cta h3` *(hidden)* | `screen-menu` | rgb(0, 229, 255) | rgba(0, 0, 0, 0) | rgb(0, 229, 255) | `none` |
| `#comboDisplay` | `screen-game` | rgb(126, 243, 255) | rgba(0, 0, 0, 0) | rgb(126, 243, 255) | `none` |
| `.mode-card__art--career` | `screen-modes` | rgb(246, 247, 251) | rgb(9, 20, 46) | rgb(246, 247, 251) | `career.webp` |
| `.mode-card__art--quick` | `screen-modes` | rgb(246, 247, 251) | rgb(9, 20, 46) | rgb(246, 247, 251) | `quick-match.webp` |
| `.mode-card__art--tournament` | `screen-modes` | rgb(246, 247, 251) | rgb(9, 20, 46) | rgb(246, 247, 251) | `tournament.webp` |

## 4. Stylebox-relevant computed values (input for UIR-02's theme)

| control | screen | background-image | background-color | box-shadow | radius | padding | color | font |
|---|---|---|---|---|---|---|---|---|
| `.btn--primary` | `menu` | `linear-gradient(135deg, rgb(0, 212, 240), rgb(0, 180, 204))` | rgba(0, 0, 0, 0) | `rgba(0, 229, 255, 0.5) 0px 6px 28px 0px` | 10px | 16px/28px | rgb(0, 0, 0) | 16px 400 |
| `.btn--secondary` | `menu` | `none` | rgb(28, 110, 176) | `none` | 10px | 12px/18px | rgb(255, 255, 255) | 14.4px 400 |
| `.badge` | `menu` | `none` | rgba(255, 255, 255, 0.06) | `none` | 20px | 5px/16px | rgb(246, 247, 251) | 10.88px 800 |
| `.lang-toggle` | `menu` | `none` | rgb(11, 36, 68) | `none` | 6px | 7px/14px | rgb(126, 243, 255) | 12.48px 900 |
| `.segmented` | `modes` | `none` | rgb(9, 29, 57) | `rgba(0, 0, 0, 0.32) 0px 2px 8px 0px inset` | 10px | 5px/5px | rgb(246, 247, 251) | 16px 400 |
| `.segmented button.is-active` | `modes` | `linear-gradient(rgb(134, 255, 196), rgb(26, 255, 138))` | rgba(0, 0, 0, 0) | `rgba(26, 255, 138, 0.4) 0px 0px 18px 0px, rgba(255, 255, 255, 0.45) 0px 1px 0px ` | 7px | 0px/6px | rgb(6, 20, 38) | 10.88px 900 |
| `.mode-card` | `modes` | `none` | rgb(17, 21, 64) | `none` | 12px | 18px/18px | rgb(246, 247, 251) | 16px 400 |
| `.btn--ghost` | `characters` | `none` | rgba(0, 0, 0, 0) | `none` | 10px | 10px/16px | rgba(255, 255, 255, 0.65) | 13.6px 700 |
| `.athlete-card` | `characters` | `none` | rgb(17, 21, 64) | `none` | 12px | 0px/0px | rgb(246, 247, 251) | 16px 400 |
| `.screen-header` | `characters` | `none` | rgba(0, 0, 0, 0) | `none` | 0px | 32px/64px | rgb(246, 247, 251) | 16px 400 |
| `.arena-card` | `arena` | `none` | rgb(17, 21, 64) | `none` | 12px | 1px/6px | rgb(246, 247, 251) | 16px 400 |
| `.hud-pause` | `game` | `none` | rgb(0, 229, 255) | `rgba(4, 22, 43, 0.48) 0px 5px 0px 0px` | 8px | 1px/6px | rgb(4, 32, 58) | 19.2px 400 |
| `.scoreboard` | `game` | `none` | rgba(6, 24, 46, 0.82) | `rgba(0, 0, 0, 0.35) 0px 4px 14px 0px` | 8px | 0px/0px | rgb(246, 247, 251) | 16px 400 |
| `.match-panel` | `game` | `none` | rgba(0, 0, 0, 0) | `none` | 0px | 0px/0px | rgb(246, 247, 251) | 16px 400 |
| `.hud-pause` | `game-panel` | `none` | rgb(16, 54, 95) | `rgba(4, 22, 43, 0.48) 0px 5px 0px 0px` | 8px | 1px/6px | rgb(255, 243, 106) | 19.2px 400 |
| `.pause-card` | `game-pause` | `none` | rgb(17, 21, 64) | `rgba(0, 0, 0, 0.5) 0px 24px 70px 0px, rgba(18, 223, 240, 0.08) 0px 0px 34px 0px` | 8px | 26px/30px | rgb(246, 247, 251) | 16px 400 |
| `.drill-hud` | `drill` | `none` | rgba(0, 0, 0, 0) | `none` | 0px | 0px/0px | rgb(246, 247, 251) | 16px 400 |

Segmented instances (`#difficultySeg`, `#lengthSeg`, `#playerModeSeg`, `#settingsLangSeg`) are in the JSON under `segmented_instances`. Base active chip = cyan `linear-gradient(180deg, #22d5ee, #16bed7)` with `#061426` text; the difficulty chip is tinted per level by `--step-color` (`styles.css:2263-2285`: easy `#1aff8a`, medium `#00e5ff`, hard `#ffcc00`, legend `#ff4b6e`).

## 5. Geometry at 1280x720 (`getBoundingClientRect`)

| selector | screen | visible | rect w×h | x,y | padding | border-radius | max-width |
|---|---|---|---|---|---|---|---|
| `.screen-header` | `screen-characters` | True | 1280×105 | 0,0 | 32px/64px/0px/64px | 0px | none |
| `.btn--primary` | `screen-menu` | True | 136.64×51 | 64,609.5 | 16px/28px/16px/28px | 10px | none |
| `.segmented` | `screen-modes` | True | 311×54 | 302,497.34 | 5px/5px/5px/5px | 10px | none |
| `.athlete-card` | `screen-characters` | True | 253×586.38 | 104,258 | 0px/0px/0px/0px | 12px | none |
| `.mode-card` | `screen-modes` | True | 344×259.34 | 104,137 | 18px/18px/18px/18px | 12px | none |
| `.arena-card` | `screen-arena` | True | 344×271.97 | 104,137 | 1px/6px/1px/6px | 12px | none |
| `.scoreboard` | `screen-game` | True | 413.84×95 | 32,30 | 0px/0px/0px/0px | 8px | none |
| `.game-hud__actions` | `screen-game` | True | 284.52×54 | 963.48,30 | 0px/0px/0px/0px | 0px | none |
| `.match-panel` | `screen-game` | True | 1068×217 | 106,796.91 | 0px/0px/0px/0px | 0px | none |
| `.event-log` | `screen-menu` | False | 0×0 | 0,0 | 0px/0px/0px/0px | 0px | none |
| `.result-card` | `screen-menu` | False | 0×0 | 0,0 | 40px/40px/40px/40px | 16px | none |
| `.pause-card` | `screen-game` | True | 880×531 | 200,94.5 | 26px/30px/30px/30px | 8px | none |
| `.drill-hud` | `screen-drill` | True | 640×64 | 320,239 | 0px/0px/0px/0px | 0px | 640px |

Screen padding and content width: `.screen` itself computes to `padding: 0px` at 1280x720 and its children carry the layout gutters — measured `.screen-header` = 1280×105 with `padding: 32px 64px 0px 64px`, so the horizontal gutter is **64px** and the effective content width is `1280 − 2×64 = 1152px` (no `max-width` is set on the menu children; per-screen child rects are in the JSON under `screen_boxes`).

Not measured (no reachable state): `.event-log` stays `display:none` in every state the reference's own controls reach, and `.result-card` never becomes visible (see section 6). Both are reported as `visible: false` with a 0×0 rect rather than estimated.

## 6. Captures and reachability

| file | bytes | active screen | reached |
|---|---|---|---|
| `reference-captures/arena.png` | 809470 | — | yes |
| `reference-captures/challenges.png` | 263989 | — | yes |
| `reference-captures/characters.png` | 664283 | — | yes |
| `reference-captures/drill.png` | 383541 | — | yes |
| `reference-captures/feedback.png` | 378969 | — | yes |
| `reference-captures/game-panel.png` | 444828 | — | yes |
| `reference-captures/game-pause.png` | 94638 | — | yes |
| `reference-captures/game.png` | 339377 | — | yes |
| `reference-captures/help.png` | 480347 | — | yes |
| `reference-captures/history.png` | 403831 | — | yes |
| `reference-captures/menu-demo.png` | 703650 | — | yes |
| `reference-captures/menu.png` | 701589 | — | yes |
| `reference-captures/modes.png` | 577665 | — | yes |
| `reference-captures/profile.png` | 396414 | — | yes |
| `reference-captures/result-NOT-STATICALLY-REACHABLE.png` | 327390 | — | NO — result screen not reachable |
| `reference-captures/settings.png` | 399218 | — | yes |

Navigation recipes used (clicking the reference's own declared controls; full trails in the JSON):

- the 9 screens reachable straight from the top nav: `[data-action="to-<screen>"]` — characters, modes, help, history, challenges, profile, feedback, drill, settings; plus `menu`, which is the entry state of a fresh load (9 + menu + arena + game = the 12 screens that rendered; `result` is the 13th and is unreachable, below)
- `screen-arena`: `[data-action="to-characters"]` → `.athlete-card` → `.athlete-card--selected` → `[data-team-confirm]`
- `screen-game`: the arena trail → `#arenaGrid .arena-card:not(.arena-card--locked)`
- `game-pause.png` and `game-panel.png`: `[data-action="pause"]` and `#panelBtn` on the running match
- `menu-demo.png`: `index.html?build=demo` (the `demo` build switch, `js/build.js:25-28`), a fresh page load

**`screen-result` is not statically reachable.** Measured probe: after starting a match through the declared controls the app sits on `screen-game` with the match clock at `00:03`; `getComputedStyle('#screen-result').display == "none"` and the element is not `screen--active`. A result only appears when a match finishes (`js/main.js:1528/1536/1546` `showResult(...)`), which needs minutes of live play. Per the ticket this is recorded, not forced: the frame shipped as `result-NOT-STATICALLY-REACHABLE.png` is the game screen where the attempt stopped, and is explicitly **not** a result-screen reference.

## 7. Font loading facts

The reference requests `https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@400;600;700;800&display=swap` (`index.html:13-16`). After `document.fonts.ready`:

| screen measured | families reported `loaded` |
|---|---|
| `menu` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `menu-demo` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `characters` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `modes` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `arena` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `help` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `history` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `challenges` | Lilita One 400, Nunito 400, Nunito 600, Nunito 700, Nunito 800 |
| `profile` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `feedback` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `drill` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `settings` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `game` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `game-pause` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |
| `game-panel` | Lilita One 400, Nunito 400, Nunito 700, Nunito 800 |

The font files the browser actually fetched (latin subsets, from the resource timing log):

- `https://fonts.gstatic.com/s/lilitaone/v17/i7dPIFZ9Zz-WBtRtedDbYEF8RXi4EwQ.woff2`
- `https://fonts.gstatic.com/s/nunito/v32/XRXV3I6Li01BKofINeaBTMnFcQ.woff2`

Note for UIR-01/UIR-02: the reference loads **Nunito as a variable font** (one woff2 serves weights 400–800); the port ships static per-weight TTFs, which render the same weights. Glyph coverage of the shipped statics was checked against the reference's own text corpus (see `uir-01-assets.md`).

## 8. What could not be measured

- `screen-result` reference frame and `.result-card` layout (not statically reachable, above).
- `.event-log` visible geometry (its state is not reachable through the declared controls; the `#panelBtn` panel state exposes `.match-panel` = 1068×217 but leaves `.event-log` at `display:none`).
- Cross-browser comparison: only one browser family was available for this measurement (chrome-headless-shell 151). The measured behaviour above is that browser's; the `--pink` result is spec-defined (invalid-at-computed-value-time + `var()` fallback) and not expected to differ.

## Appendix: the measurement snippet (paste-able in a browser console)

Served page, then paste in DevTools:

```js
(() => {
  const TYPE_SELECTORS = [
    ".screen-header h2", ".screen-header p", ".hero h1", ".hero p",
    ".btn", ".btn--primary", ".btn--secondary", ".btn--ghost", ".btn--confirm",
    ".segmented button", ".segmented button.is-active", ".segment button.is-active",
    ".athlete-card__body h3", ".mode-card h3",
    ".scoreboard__teams strong", ".scoreboard__title", ".scoreboard__meta span",
    ".hud-pause", ".result-card h2", ".result-stats__row",
    ".drill-hud__box b", ".top-nav .brand span"
  ];
  const COLOR_SELECTORS = [
    ".scoreboard__control", ".scoreboard__tactic", ".mode-card__tag--ready",
    ".athlete-card__role", ".athlete-card__special", ".result-objectives__check",
    ".profile-kind", ".hint", ".setup-group__hint", ".badge", ".lang-toggle",
    ".hero-tags span", ".demo-cta h3", "#comboDisplay",
    ".mode-card__art--career", ".mode-card__art--quick", ".mode-card__art--tournament"
  ];
  const GEOMETRY_SELECTORS = [
    ".screen-header", ".btn--primary", ".segmented", ".athlete-card", ".mode-card",
    ".arena-card", ".scoreboard", ".game-hud__actions", ".match-panel", ".event-log",
    ".result-card", ".pause-card", ".drill-hud"
  ];
  const TYPE_PROPS = ["font-family","font-size","font-weight","font-style","letter-spacing","line-height","text-transform","color"];
  const COLOR_PROPS = ["color","background-color","background-image","border-top-color","border-right-color","border-bottom-color","border-left-color","box-shadow","text-shadow","opacity","filter"];
  const RECT_PROPS = ["display","box-sizing","padding-top","padding-right","padding-bottom","padding-left","margin-top","margin-bottom","border-top-width","border-radius","max-width","width","min-height","gap","grid-template-columns"];

  const activeScreen = document.querySelector(".screen--active")?.id ?? null;
  const round = (n) => Math.round(n * 100) / 100;
  const propsOf = (el, props) => {
    if (!el) return null;
    const cs = getComputedStyle(el);
    const o = {};
    for (const p of props) { const v = cs.getPropertyValue(p); o[p] = v === undefined ? null : v; }
    return o;
  };
  const visible = (el) => {
    if (!el) return false;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && el.offsetParent !== null;
  };
  const rectOf = (el) => {
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: round(r.x), y: round(r.y), width: round(r.width), height: round(r.height),
             top: round(r.top), right: round(r.right), bottom: round(r.bottom), left: round(r.left) };
  };
  const collect = (selectors, fn) => {
    const out = {};
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      out[sel] = el ? fn(el) : { exists: false };
    }
    return out;
  };

  // --pink chain: element + documentElement, raw strings
  const career = document.querySelector(".mode-card__art--career");
  const csCareer = career ? getComputedStyle(career) : null;
  const csRoot = getComputedStyle(document.documentElement);
  const pink = {
    selector: ".mode-card__art--career",
    found: !!career,
    element: csCareer ? {
      backgroundImage: csCareer.getPropertyValue("background-image"),
      backgroundColor: csCareer.getPropertyValue("background-color"),
      boxShadow: csCareer.getPropertyValue("box-shadow"),
      borderColor: csCareer.getPropertyValue("border-top-color"),
      borderImageSource: csCareer.getPropertyValue("border-image-source"),
      "--mode-accent": csCareer.getPropertyValue("--mode-accent"),
      "--pink": csCareer.getPropertyValue("--pink")
    } : null,
    documentElement: {
      "--mode-accent": csRoot.getPropertyValue("--mode-accent"),
      "--pink": csRoot.getPropertyValue("--pink"),
      "--cyan": csRoot.getPropertyValue("--cyan"),
      "--gold": csRoot.getPropertyValue("--gold")
    }
  };

  const fontsFacts = {
    status: document.fonts.status,
    size: document.fonts.size,
    loaded: [...document.fonts].map((f) => ({ family: f.family, weight: f.weight, style: f.style, status: f.status })),
    resourceUrls: performance.getEntriesByType("resource")
      .filter((e) => /fonts\.(gstatic|googleapis)\.com/.test(e.name))
      .map((e) => ({ name: e.name, initiatorType: e.initiatorType, transferSize: e.transferSize }))
  };

  return {
    env: {
      href: location.href,
      title: document.title,
      viewport: [window.innerWidth, window.innerHeight],
      devicePixelRatio: window.devicePixelRatio,
      rootFontSize: getComputedStyle(document.documentElement).fontSize,
      bodyFontSize: getComputedStyle(document.body).fontSize,
      activeScreen,
      readyState: document.readyState,
      scrollbarGuard: document.documentElement.scrollHeight
    },
    pink,
    type: collect(TYPE_SELECTORS, (el) => Object.assign({ exists: true, visible: visible(el) }, propsOf(el, TYPE_PROPS))),
    colors: collect(COLOR_SELECTORS, (el) => Object.assign({ exists: true, visible: visible(el) }, propsOf(el, COLOR_PROPS))),
    geometry: collect(GEOMETRY_SELECTORS, (el) => Object.assign({ exists: true, visible: visible(el), rect: rectOf(el), screen: activeScreen }, propsOf(el, RECT_PROPS))),
    screenBox: (() => {
      const s = document.querySelector(".screen--active");
      if (!s) return null;
      const cs = getComputedStyle(s);
      const kids = [...s.children].map((k) => ({ tag: k.tagName, cls: k.className, rect: rectOf(k), maxWidth: getComputedStyle(k).maxWidth, width: getComputedStyle(k).width, marginLeft: getComputedStyle(k).marginLeft, marginRight: getComputedStyle(k).marginRight }));
      return { id: s.id, rect: rectOf(s), padding: [cs.paddingTop, cs.paddingRight, cs.paddingBottom, cs.paddingLeft], children: kids };
    })(),
    fontsFacts
  };
})()
```
