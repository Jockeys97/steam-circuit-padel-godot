---
id: UIR-02
title: Theme resource from styles.css tokens
slug: theme-resource
state: done
readiness: potential
owner_role: visual-foundation worker
blocked_by: [UIR-01, UIR-06]
blocks: [UIR-07, UIR-08, UIR-10, UIR-11, UIR-12, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-20, UIR-21]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-02-theme-probe.log
---

# UIR-02: Theme resource from styles.css tokens

## Worker brief (copy-paste)

> Build `godot/src/ui/theme/padel_theme.tres` from the frozen palette at `styles.css:1-13` plus the semantic colors the stylesheet actually uses, wire the four font roles to the TTFs imported by UIR-01, and prove it with a small theme probe scene rendered at 1280x720, 1152x648, 1920x1080 and 1024x600. The theme is the only place colors and sizes are declared: screen scripts must not carry literal colors. Do not implement any screen content.

## Why this exists

Every color and size on screen is currently a per-node override in `godot/game/main_menu.gd:83-264` and `godot/game/hud.gd:100-345`, and the hand-copied values drifted (menu gold `Color(1.0, 0.821, 0.4)` = `#FFD166` vs the reference `--gold: #FFCC00`; background `Color(0.043, 0.063, 0.11)` = `#0B101C` vs `--bg: #07072A`). The recreation needs one design layer. This ticket creates it.

## Prerequisites (Definition of Ready)

- UIR-01 landed: fonts present under `godot/assets/ui/fonts/` and import ran clean.
- UIR-06 landed: the measured values exist at `evidence/uir-06-computed-styles.md/.json` (the theme uses measured values for everything UIR-06 measured).
- Read the "Palette and type" section of the pack README.

## Read allowlist

- `styles.css:1-13` (`:root` tokens), the rules that consume them (`.btn` family, `.segmented:2207-2252`, `.screen-header:280-296`, cards `:323-342`, `.scoreboard:553-678`, `.result-card:1099-1200`, `.drill-seg:1344-1386`, media queries `:1970, :2003, :2033, :2058, :2064, :2070, :2775, :2785, :2936, :3245, :3299, :3436, :3577`)
- `index.html:11-16` (font families and weights)
- `docs/implementation/ui-recreation/evidence/uir-06-computed-styles.md` and `.json` (blocking input: computed pixels outrank this ticket's estimates; where UIR-06 has no measurement for a value, the reference numbers below are the fallback and the evidence file says which is which)

## Write allowlist (you own these)

- `godot/src/ui/theme/padel_theme.tres`
- `godot/src/ui/theme/padel_theme_base.tres` (optional second resource if you split Button/Segmented variations)
- `godot/src/ui/theme/*.tres` (any further theme variations you need)
- `godot/src/ui/theme/README.md` (token map: styles.css source -> theme value)
- `godot/tests/ui/theme_probe.gd` and `godot/tests/ui/theme_probe.tscn`
- `.uid` sidecar for the new probe script
- `docs/implementation/ui-recreation/evidence/uir-02-theme-probe.log`

No other writes. No commits.

## Do not touch

`godot/game/**`, `godot/src/sim/**`, `godot/src/locale/**`, `godot/src/save/**`, `godot/src/modes/**`, `godot/project.godot`, `godot/assets/**` (UIR-01 owns it), `js/**`, `index.html`, `styles.css`.

## Required palette (verbatim from `styles.css:1-13`)

```
--ink:   #f6f7fb      --cyan:  #00e5ff     --bg:    #07072a
--muted: rgba(255,255,255,0.48)            --gold:  #ffcc00
--panel: #111540      --coral: #ff4b6e     --shadow: 0 24px 80px rgba(0,0,0,0.45)
--line:  rgba(255,255,255,0.12)            --green: #1aff8a
```

Recurring semantic colors used by the screen rules (from the scout pass; UIR-06 confirms computed values): dark blue surfaces `#061426 #091d39 #0b2444 #0b3152 #10365f #173b61`; light cyan text `#7ef3ff #9ef8ff #bdeeff`; yellow state `#fff36a #ffd98a`; rival accent `#ffc09a #ff9a5c`; success `#b9ffe0 #56e8d8`. Type roles: display/buttons `"Lilita One", cursive`; body `Nunito, system-ui, sans-serif`; diagnostics monospace `ui-monospace, SFMono-Regular, Menlo, monospace`. Reference sizes: screen title `2.4rem`; hero title `clamp(2.4rem, 5vw, 4rem)`; result title `3rem`; card headings `1.1rem`; small labels uppercase with letter spacing.

## Interface (all new; nothing here exists today)

- Theme type variations (PROPOSED names, this ticket fixes them): `ScreenTitle`, `ScreenSubtitle`, `CardTitle`, `CardBody`, `Label(Small)`, `Button/primary`, `Button/secondary`, `Button/ghost`, `Segmented/Inactive`, `Segmented/Active`, `Panel/Dark`, `Badge`.
- Font roles as `FontFile` resources: `Display` (Lilita One 400), `Body` (Nunito 400), `BodyStrong` (Nunito 700/800), `Mono` (system fallback is fine; no font download).
- One constant dictionary for semantic colors is not enough: expose named `StyleBoxFlat`/`StyleBoxTexture` resources inside the theme so screens set type variations and never colors.

## Microsteps (do in order)

1. Write `godot/src/ui/theme/README.md` first: a table with one row per `:root` token and each semantic color, the consuming styles.css rule, and the theme value you will assign. This table is the traceability artifact.
2. Create `padel_theme.tres` (a `Theme` resource). Add default font = Body, default font size = 17 px (the port's existing menu uses 17-19 px at 1280x720; the reference's rem sizes assume a 16 px root. If UIR-06 measured values exist, use them and note the delta).
3. Add the four font files; create `FontVariation` resources for weights if the Nunito statics differ only by weight.
4. Add type variations and styleboxes for buttons (primary = cyan gradient on dark text with cyan glow, secondary = dark blue solid, ghost = transparent muted), segmented (recessed container, active gets the cyan gradient), panels (dark translucent border 1 px, rounded corners), and the `#screen-game` HUD surfaces.
5. Build the probe: `theme_probe.tscn` mounts one instance of every type variation in a grid, labelled, plus a 1280-wide row that mirrors the stylesheet's key measurements. `theme_probe.gd` prints one `ok <name>` line per assertion and a `PASS n/n` summary, matching the port's contract (`godot/tests/smoke_test.gd:8-14`).
6. Probe assertions (minimum): every named variation resolves; no control overflows its container at 1280x720, 1152x648, 1920x1080, 1024x600 (drive via `root.size` like `godot/tests/game_slice_test.gd:299-300` does); every foreground/background pair of the probe grid meets the reference's contrast levels (grey text on `--bg` and on `--panel`; dark text on the cyan button).
7. Run the probe on this Mac (serial lock), save the log.
8. Render one capture of the probe at 1280x720 through the capture path if UIR-24 exists; otherwise skip captures (the probe log is the evidence) and note it.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/theme_probe.gd ; echo "exit=$?"
```

## Acceptance commands (Linux CI form, existing, host agents only)

```bash
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  <linux-godot> --headless --path godot/ --script res://tests/ui/theme_probe.gd
```

## Evidence to hand back

- `evidence/uir-02-theme-probe.log` (exit 0, `PASS n/n`).
- `godot/src/ui/theme/README.md` token map.
- Hand-back message: variation list, font files used, probe tally, whichever numbers were taken from UIR-06 vs estimated.

## Definition of Done

- [ ] `padel_theme.tres` loads with zero script errors; probe green at four sizes.
- [ ] Every color in the theme traces to a styles.css line in the README map; no per-node color left in the probe.
- [ ] Fonts assigned by role; no font path outside the theme.
- [ ] Probe and its `.uid` files are the only code added.
- [ ] Hand-back names the exact command and tally line.

## Failure and recovery

- Font loads but renders wrong: check import settings (antialiasing, hinting) and record measured differences instead of swapping fonts.
- Theme type variation names clash with engine built-ins: rename, do not patch around with per-node overrides.
- A reference color cannot be resolved (for example the `--pink` chain): use the value UIR-06 measured. If the measurement shows the declaration is dropped (invalid at computed-value time, nothing rendered), reproduce that exact result and quote the raw computed strings; do not invent a color.

## Traces

`styles.css:1-13`, `styles.css:2207-2252` (segmented), `styles.css:280-296` (header), `styles.css:323-342` (cards), `styles.css:2748-2757` (`body.reduce-motion`, for the later motion policy), handoff diagnosis items 1-2; old S4 ticket `docs/implementation/tickets/hud-and-menu.md:51` (theme path this ticket finally creates).
