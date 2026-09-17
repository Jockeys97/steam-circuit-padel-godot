---
id: UIR-06
title: Reference computed-style and pixel capture (--pink, type, geometry)
slug: computed-styles
state: done
readiness: potential
owner_role: web-evidence worker
blocked_by: []
blocks: [UIR-02, UIR-07, UIR-08]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-06-computed-styles.md
  - docs/implementation/ui-recreation/evidence/uir-06-computed-styles.json
  - docs/implementation/ui-recreation/evidence/reference-captures/
---

# UIR-06: Reference computed-style and pixel capture (--pink, type, geometry)

## Worker brief (copy-paste)

> Open the frozen web build in a browser at 1280x720 and capture, as data: (1) what the undefined `--pink` actually resolves to on `.mode-card__art--career`, (2) computed font sizes and families for the named type roles, (3) the recurring semantic pixel colors the stylesheet uses, (4) one 1280x720 PNG per screen as the visual reference set. Write the JSON + the Markdown summary under `evidence/`. Read-only against the web build: serve it, measure it, never edit `js/`, `index.html` or `styles.css`.

## Why this exists

The scout pass could not run a browser, so the pack carries two known unknowns: the `--pink` custom property is used at `styles.css:473` but never defined in `:root` (browser fallback behavior must be measured, not guessed), and every pixel measurement so far is estimated from rem values rather than computed. A 1:1 recreation cannot proceed screen by screen on estimates. This ticket produces the measurements once, so every screen ticket works from numbers.

## Prerequisites (Definition of Ready)

- Pack approved (measurement session, no product files touched).
- A browser available on this Mac (Safari, Chrome, Arc) or a Node/browser automation stack. If neither exists, this ticket is BLOCKED-EXTERNAL: record that and hand to Luca; do not invent values.

## Read allowlist

- `index.html`, `styles.css`, `js/**` (the frozen reference; read-only)
- `scripts/i18n-audit.mjs` (language switching for the IT/EN states)

## Write allowlist (you own these)

- `docs/implementation/ui-recreation/evidence/uir-06-computed-styles.md`
- `docs/implementation/ui-recreation/evidence/uir-06-computed-styles.json`
- `docs/implementation/ui-recreation/evidence/reference-captures/*.png` (new directory)

No other writes. No edits to any file under `js/`, `index.html`, `styles.css`, `assets/`.

## The measurements (record each with the exact selector and viewport)

1. `--pink` chain. Read `getComputedStyle(document.querySelector('.mode-card__art--career'))` and capture: `backgroundImage`, `backgroundColor`, `boxShadow`, `borderColor`, plus `getPropertyValue('--mode-accent')` and `getPropertyValue('--pink')` on both the element and `document.documentElement`. Then find every consumer of `--mode-accent` (grep styles.css for `--mode-accent`) and capture its computed result on the career card. Conclusion to state explicitly in the evidence file: what a browser renders where `--pink` is referenced undefined (invalid-at-computed-value-time behavior vs a resolved color), so UIR-02 and UIR-11 can reproduce the same rendered result. Do not recommend a "nicer" color; reproduce the source.
2. Type roles at root font-size 16px, viewport 1280x720: computed `font-family`, `font-size`, `font-weight`, `letter-spacing`, `line-height`, `text-transform` for: `.screen-header h2`, `.screen-header p`, `.hero h1`, `.hero p`, `.btn` (each variant), `.segmented button`, `.segment button.is-active`, `.athlete-card__body h3`, `.mode-card h3`, `.scoreboard__teams strong`, `.scoreboard__title`, `.scoreboard__meta span`, `.hud-pause`, `.result-card h2`, `.result-stats__row`, `.drill-hud__box b`, `.top-nav .brand span`.
3. Semantic pixels: computed colors for one representative per recurring value: `.scoreboard__control`, `.scoreboard__tactic`, `.mode-card__tag--ready`, `.athlete-card__role`, `.athlete-card__special`, `.result-objectives__check`, `.profile-kind`, `.hint`/`.setup-group__hint`, `.badge`, `.lang-toggle`, `.hero-tags span`, `.demo-cta h3`. Also record `#comboDisplay` only through its code-defined colors (`js/ui.js:1333-1335`: `{1:'#7ef3ff',2:'#8fffd0',3:'#ffe066',4:'#ff9a5c'}`, default `#ff6d70`).
4. Geometry at 1280x720: `getBoundingClientRect()` for `.screen-header`, `.btn--primary`, one `.segmented`, one `.athlete-card`, one `.mode-card`, one `.arena-card`, `.scoreboard`, `.game-hud__actions`, `.match-panel`, `.event-log`, `.result-card`, `.pause-card`, `.drill-hud`. Also the `.screen` horizontal padding and max content width.
5. Font loading facts: from `document.fonts`, record which families/weights actually loaded and the resolved font URLs from the Google Fonts stylesheet (so UIR-01 can prefer the exact files). Note the two families and weights once more: Lilita One 400, Nunito 400/600/700/800 (`index.html:13-16`).
6. Reference captures: one PNG per screen at 1280x720, using the frozen build served locally. Serve read-only:
   ```bash
   cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
   python3 -m http.server 8765 --bind 127.0.0.1
   ```
   Then drive the browser: navigate to `http://127.0.0.1:8765/index.html`, and for each of the 13 screens call the page's own router (`window` modules: the module scope is not exposed; instead click the declared actions, or evaluate `document.querySelector('[data-action="to-..."]').click()` sequences), wait a frame, and screenshot to `reference-captures/<screen-id>.png`. Give capture states where cheap: `screen-menu` in full, `screen-menu?build=demo` per `js/build.js:26` query, `screen-game` twice (serve and rally frames are not reachable statically; capture the default entry state only), `screen-result` only if reachable via the debug path; otherwise record as not statically reachable and move on. Do not add code to the page to reach states.
   If browser automation is unavailable but a manual browser is: capture the PNGs manually, and run the computed-style script from the browser console with a paste-able snippet stored in the evidence file.

## Microsteps (do in order)

1. Start the static server; confirm `index.html` loads with fonts (network on for Google Fonts; if offline, record the fallback rendering AND note the delta).
2. Run the measurement script (console or automation) producing `uir-06-computed-styles.json`.
3. Capture the 13 screen PNGs.
4. Write `uir-06-computed-styles.md`: one section per measurement group, each value next to its selector; the `--pink` finding as its own section with the raw computed strings quoted.
5. Kill the server. Hand back.

## Acceptance commands (native macOS)

```bash
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
python3 -m http.server 8765 --bind 127.0.0.1    # foreground; second terminal drives the browser
# measurement + captures per the microsteps; log every raw value verbatim
```

Browser automation availability was not verified in the planning session; treat the automation path as PROPOSED and the manual path (browser + console snippet) as the guaranteed fallback.

## Evidence to hand back

- `uir-06-computed-styles.json` + `.md` + `reference-captures/` (13 PNGs or a documented subset with reasons).
- Hand-back message: the `--pink` resolution result, any measurement that could not be taken, the PNG count.

## Definition of Done

- [ ] `--pink` resolution measured and quoted; every consumer of `--mode-accent` listed.
- [ ] Type, color and geometry tables complete for the listed selectors; every value is computed, none estimated.
- [ ] PNG set present (or the unreachable states named).
- [ ] Zero writes outside the evidence directory.

## Failure and recovery

- If no browser exists at all (no automation and no manual browser), record BLOCKED-EXTERNAL, hand to Luca with exactly what cannot be measured, and stop: the visual chain behind this ticket (UIR-02, UIR-07, UIR-08, UIR-10 through UIR-21) holds until it lands, and the coordinator records the stall on the board. Never substitute estimates for measurements.
- Google Fonts unreachable: measurements still valid except glyph rendering; record the fallback font in use and flag that the reference capture shows fallback.
- Automation fails mid-set: keep the partial set, name what is missing, hand back; partial measured data beats complete estimates.
- The `--pink` chain behaves differently across browsers: record per-browser results; the target is the behavior in the browser family Luca uses, noted explicitly.

## Traces

`styles.css:1-13`, `styles.css:473` (`--mode-accent: var(--pink)`), `index.html:11-16`; scout section 6 ("Potential source issue to preserve or resolve explicitly"); handoff step 3 (fonts); pack README "Known unknowns".
