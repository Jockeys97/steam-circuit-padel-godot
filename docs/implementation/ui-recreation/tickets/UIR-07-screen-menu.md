---
id: UIR-07
title: MenuScreen 1:1 (screen-menu)
slug: screen-menu
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-06]
blocks: [UIR-09, UIR-10, UIR-11, UIR-12, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-20, UIR-21, UIR-22]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-07-screen-menu.log
capture_states: [default, demo, beta]
---

# UIR-07: MenuScreen 1:1 (screen-menu)

## Worker brief (copy-paste)

> Recreate `screen-menu` (`index.html:31-87`) as `godot/src/ui/screens/MenuScreen.gd/.tscn`, styled by `padel_theme.tres`, registered with the router as `menu`, with every action routed through the router. Content: top navigation (brand logo, profile button, settings button, language toggle), hero (badge, two-line title, sub, pad hint, six action buttons), hero preview (key art with the STEAM CIRCUIT / PADEL PRO caption, tag row with the build badge). Build the demo/beta badge through `DemoGateAdapter` only. The screen must not contain a single literal user-facing string: everything resolves through `UiStrings`. This screen plus UIR-08 is what GATE-A shows Luca; build it to look finished.

## Why this exists

The menu is the port's first screen and currently a developer surface: subtitle reads "Port Godot 4.7.2 … Regole, fisica e taratura sono il core S1 già verificato" (`godot/game/main_menu.gd:110`), an arena line prints raw `wallBounce`/`grip` decimals (`:405`), and a seed line explains determinism (`:412`). Those strings leave the player-facing surface. The reference menu has none of that.

## Prerequisites (Definition of Ready)

- UIR-02 (theme), UIR-03 (router + shell + UiStrings), UIR-04 (adapters), UIR-05 (focus bridge), UIR-06 (measurements; if UIR-06 is blocked-external, state what remains estimated).
- The frozen markup and styles read in full (they are short).

## Read allowlist

- `index.html:31-87` (markup), `index.html:11-16` (fonts)
- `styles.css`: `.top-nav:81-130`, `.hero` and `.hero-*` rules, `.btn` family, `.badge`, `.hero-tags`, `.hero-tags__build:3626-3634`
- `js/ui.js:737-770` (`applyDemoLimits`), `js/main.js:2199+` (action handlers: `to-modes`, `to-drill`, `to-help`, `to-history`, `to-challenges`, `to-feedback`, `to-profile`, `to-settings`), `js/main.js:2421` (`setLanguage`), `js/i18n.js` keys: `brand`, `heroBadge`, `heroTitle1`, `heroTitle2`, `heroSub`, `heroPadNote`, `playNow`, `training`, `howTo`, `history`, `challenges`, `feedback`, `profile`, `settings`, `demoBadge`, `betaBadge`, `ariaMenu`, `ariaProfile`, `ariaSettings`, `ariaHeroImg`, `tagPc`, `tagArcade`
- `godot/src/ui/**` (UIR-02/03/04/05 deliverables), `godot/src/locale/locale.gd`
- `godot/game/main_menu.gd` and `godot/game/Main.tscn` (current menu being replaced later by UIR-22; read-only here)

## Write allowlist (you own these)

- `godot/src/ui/screens/MenuScreen.gd`, `godot/src/ui/screens/MenuScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_menu_audit.gd`, `godot/tests/ui/screen_menu_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-07-screen-menu.log`

No other writes. Do not edit the router, theme, adapters or shell; if one of them lacks what you need, hand back a blocker naming the exact method you miss.

## Reference anatomy (verified from the frozen markup; reproduce in this order)

- `nav.top-nav`: brand (circle logo SVG + "STEAM CIRCUIT PADEL PRO"), actions: profile icon button (`data-action="to-profile"`), settings icon button (`data-action="to-settings"`), language toggle labeled IT (toggles it/en).
- `div.hero` > `div.hero-copy`:
  - `span.badge` (dot + `heroBadge` text);
  - `h1` two spans: `heroTitle1` / `heroTitle2`;
  - `p` (`heroSub`); `p.hero-hint` (pad icon + `heroPadNote`);
  - `div.hero-actions` six buttons, all `btn`: primary `to-modes` (`playNow`), then secondary `to-drill` (`training`), `to-help` (`howTo`), `to-history` (`history`), `to-challenges` (`challenges`), `to-feedback` (`feedback`).
- `div.hero-preview`: `figure.hero-poster` with `assets/ui/steam-circuit-key-art.webp` (alt `ariaHeroImg`) and the caption "STEAM CIRCUIT" / "PADEL PRO"; `div.hero-tags` with the build badge (hidden unless demo/beta; text set by the demo gate) plus `tagPc`, `tagArcade`, and the literal "Alpha 0.2".
- The "Alpha 0.2" tag has no `data-i18n` in the markup; it is a literal in the reference. Reproduce it verbatim (it is reference content, not a port literal); note it in the evidence file.
- Icon glyphs in the top nav are emoji in the reference (👤, ⚙️). Decision rule for the port: render the same glyphs (no icon library), and record any glyph that does not render on macOS in the hand-back.

## Interface (all new)

- `MenuScreen.gd` extends `ScreenContract` (UIR-03). `screen_id() -> "menu"`, `back_target() -> ""`, `capture_states() -> ["default", "demo", "beta"]`, `apply_capture_state(state_id)`:
  - `"default"`: current build's normal rendering;
  - `"demo"` / `"beta"`: forces `DemoGateAdapter` into that mode for capture purposes ONLY, via the gate's own build flag seam (`godot/tests/build/BuildFlag.gd`), never by faking strings. If the flag cannot be forced without a process-level setting, implement the states by swapping the badge text/badge row through the adapter's own data and record the limitation.
- Actions: every button emits through the router (`go_to("modes")` etc.); profile/settings go to `profile`/`settings`; language toggle calls `Locale.set_lang()` and already-visible dynamic text re-resolves (the reference refreshes generated content on `setLanguage`, `js/main.js:2421`).

## Microsteps (do in order)

1. Read the markup + styles; list every string key on a scratch line inside your evidence log.
2. Build `MenuScreen.tscn` as a static Control tree (top nav, hero, preview), with `MenuScreen.gd` doing only wiring and dynamic bits (badge, language toggle label).
3. Route all strings through `UiStrings.t("...")`; include `data-i18n-aria` equivalents as accessibility names on the buttons (`ariaProfile`, `ariaSettings`, `ariaMenu`).
4. Wire actions to router calls; profile and settings are separate destinations (the reference explicitly guards that the menu's profile/settings buttons are not a back action; the router's declared-back model makes this structural).
5. Wire the language toggle: label shows the other language (`IT` shows when current is en, per the reference toggle behavior); on activate, `Locale.set_lang()` then re-resolve every visible string.
6. Badge: text from `DemoGateAdapter.badge_text_key()` (`demoBadge`/`betaBadge`), visible only when `badge_visible()`.
7. Write `screen_menu_audit.gd`: mounts the router + MenuScreen headless; asserts (a) all six hero actions and the two top-nav actions resolve to the right router targets and the router still carries 13 ids; (b) zero literal strings: scan `MenuScreen.gd` for string literals not passed through `UiStrings` (allow the screen id and node names); (c) language flip changes visible text on all data-i18n slots (compare resolved texts before/after `set_lang("it")`); (d) badge visibility follows the gate; (e) the screen reports one capture state walk.
8. Run the audit; save log. Capture `ui-menu.png` at 1280x720 through UIR-24's harness if it exists; otherwise note pending.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_menu_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_menu_audit.gd -- --demo ; echo "exit=$?"
```

## Acceptance commands (Linux CI form, existing, host agents only)

Same commands under `flock`/`timeout` with the Linux binary.

## Evidence to hand back

- `evidence/uir-07-screen-menu.log`: both runs, exit 0, tallies.
- Hand-back message: key list used, the badge path, language flip proof, anything visual that needs UIR-02 to expose more of the theme (name the exact variation you miss).

## Definition of Done

- [ ] Screen renders in the router; all 8 actions route correctly (six hero + profile + settings).
- [ ] Zero user-facing literals, proven by the audit scan.
- [ ] Language toggle changes every visible string including titles and alt/aria equivalents and the toggle's own label.
- [ ] Badge visibility correct per build (default false in full build).
- [ ] No edit outside the allowlist; hand-back names commands and tallies.

## Failure and recovery

- The theme lacks a variation (for example the hero title's clamping size): reproduce with a documented per-instance size override ONLY if the theme's public surface cannot express it; record the override and open a follow-up note for UIR-02's owner. Do not fork the theme file.
- Key art image renders at the wrong aspect: measure from UIR-06's geometry; do not crop creatively.

## Traces

`index.html:31-87`, `js/ui.js:737-770`, `js/main.js:2199-2246` handlers; handoff items 3-5 (dev text, language split, scaling); scout T01 acceptance list; GATE-A readiness.
