# HUD direction set — r1 (`hud-directions-r1`)

**Purpose:** 5 single-screen in-match HUD *direction stills* (light editorial / frosted glass /
broadcast strip / arcade pop / zen minimal) to steer the recreated HUD beyond GATE-A.
Direction setters only — never ship-ready, never a taste verdict; GATE-A belongs to Luca.

**Base frame (kept byte-identical, used as the image-edit input):**
`docs/implementation/ui-recreation/gate-a-review/pairs/hud-after-prototype-serve-1280x720.png`
sha256 `93799b94ced8ca32801c51681720a7afa9a32bfeca1679b5948422ec88dfb9e1` (1280×720, real
merged-tip capture).

**Model / provider:** `gpt-image-2.5-flare` / `openai` (dev-work profile `image_gen` config),
aspect `landscape`. 1 generation per variant; up to 2 budgeted re-rolls, allowed ONLY for
gating-item failures. Ledger: `image-spend.json` (this dir).

## Shared DNA (verbatim in every generation prompt)

> Edit this real game screenshot, keeping the 3D scene EXACTLY as-is: same light-blue padel court
> with white lines and glass walls, same net, same four simple 3D players, same ball, same arena
> background, same camera angle. Do not redraw, move, restyle, or zoom the scene. Remove ALL
> existing HUD/UI overlays completely — every current panel and pill (the dark score card
> top-left, the dark GAME TIME card and buttons top-right, the minimap panel, the center prompt
> pill, the bottom-left commentary pill) — no leftovers of the old dark UI may remain. Replace
> them with the new HUD described below: a single clean 16:9 game screenshot, flat modern 2026
> casual-game UI, generous rounded corners, soft shadows, high contrast, very readable, generous
> spacing, uncluttered. HUD text in Italian, short labels, approximate legible lettering is fine.
> No collage, no multiple panels, no frames, no watermark, no debug text.

## Variants (per-variant HUD paragraph appended to the DNA)

1. **01-editoriale** — light editorial sports-newspaper: off-white paper cards, near-black ink
   text, one warm persimmon-orange accent, hairline divider rules, small uppercase kickers.
   Top-left score card (`PARTITA RAPIDA · SET 1`, scoreline `MAESTRO 0 — 0 CIRCUITO`, chip row
   `GIOCHI 0-0 · COMBO x1`); small white `GAME TIME 00:01` card top-right; slim white `CRONACA`
   bar bottom-left. No dark boxes anywhere.
2. **02-vetro** — light frosted glassmorphism: translucent white glass pills, soft blur, lime +
   cyan accent chips. Score glass pill top-left, round glass timer top-right, slim lime energy
   bar bottom-center, small glass `CRONACA` chip bottom-left. No dark opaque panels.
3. **03-broadcast** — televised score bug: compact strip of slim white segmented boxes with
   crisp dark tabular numerals and a magenta+blue accent edge, bottom-left; small live timer box
   top-right; thin `CRONACA` ticker under the strip. Sports-TV precise, hairline rules.
4. **04-arcade** — arcade pop: chunky rounded slabs, thick soft outlines, cream/tangerine/yellow,
   big bold near-black numerals, sticker shapes slightly tilted. Big score slab top-left, round
   yellow timer badge top-right, thick orange energy bar with lightning bolt bottom-center.
5. **05-zen** — zen minimal: almost no HUD. One small quiet white chip top-left
   (`MAESTRO 0—0 CIRCUITO · SET 1`), one thin gray `CRONACA` line bottom-left, one small soft
   pill above the nearest player (`LEGGI LA PALLA`). Scene dominates; screen breathes.

## Freeze checklist (binary, decided before round 1)

- **C1** 3D scene preserved (court, walls, players, ball, camera recognizable vs base) — **GATING**
- **C2** single 16:9 screen; no collage / multi-panel / borders / watermark — **GATING**
- **C3** old dark HUD fully gone (no leftover score card / minimap / old pills) — **GATING**
- **C4** HUD matches the assigned direction style
- **C5** HUD text approximate but legible (score + names + set/game present)
- **C6** clean & simple (≤ ~6 HUD clusters, generous spacing, readable contrast)
- **C7** no debug text (SEED / TIER / RNG)
- **C8** no new clutter in the 3D scene

**Stop target:** `target-met` = C1–C3 pass on all five stills. Re-roll (≤2 total) only for a
failed gating item; refinements are new files, raws never overwritten.

## Non-claims

Generated lettering will be approximate; stills are direction setters for comparison only; they
change nothing in the shipped recreation; the visual/fun verdict stays Luca's.
