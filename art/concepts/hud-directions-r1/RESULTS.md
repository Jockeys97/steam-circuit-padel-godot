# hud-directions-r1 — results (2026-09-17)

5 single-screen in-match HUD direction stills, each an image-edit of the real merged-tip capture
(base kept byte-identical, sha256 `93799b94…`). Direction setters — for picking a look to build
toward; not ship assets, not a GATE-A verdict.

| # | file | direction | what it sells | sha256 (first 12) |
|---|---|---|---|---|
| 1 | `01-editoriale.png` | light editorial | sports-magazine calm: off-white paper cards, serif scoreline, persimmon accent, hairline rules | `5cee2633eb44` |
| 2 | `02-vetro.png` | frosted glass | glossy light 2026: translucent glass pills with blur, lime/cyan accent chips | `7aba0e89f368` |
| 3 | `03-broadcast.png` | TV score bug | televised-padel look: slim white segmented strip bottom-left + small live timer | `b53296ef791c` |
| 4 | `04-arcade.png` | arcade pop | playful chunky: cream/orange slabs, fat numerals, round timer badge | `4080420f69da` |
| 5 | `05-zen.png` | zen minimal | near-zero HUD: one quiet score chip + one small prompt pill; the scene dominates | `88f844d78209` |

All five render 1536×1024 (the provider returns 3:2 landscape; exact 16:9 is not available from
gpt-image-2.5-flare). Raw generations stay in `~/.hermes/profiles/dev-work/cache/images/`; the
files here are byte-identical copies (hashes above re-measured).

## Verification record (parent, 2026-09-17)

- `shasum -a 256` on all five files re-matched the workers' reported hashes 1:1.
- Dimensions re-measured (`sips`); the base capture re-hashed unchanged after the run.
- Parent vision spot-checks (01 + 04): single screen ✓, 3D scene preserved ✓, old dark HUD fully
  gone ✓, style match ✓, lettering legible ✓.
- Worker vision passes (all five, same checklist): all pass; cosmetic notes only — thin CRONACA
  strip on 01, unified strip vs fully segmented boxes on 03, minor scene flourishes on 01/04
  (a lamppost / cloud decals, a kit number).
- Caveats: lettering is model-rendered and approximate by nature, even where it reads cleanly;
  no code changed; GATE-A untouched; nothing merged or pushed.

## Status

Delivered for comparison. Next: Luca picks (or rejects) direction(s) — only then does any of this
become a build target. Nothing gets re-rolled or refined without that call.
