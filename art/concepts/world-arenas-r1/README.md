# World arena set — round 1 (shipped)

Five concept stills for new arenas themed on real world locations, for recreation in the
Godot port. Direction setters, not shipping assets. Raw generations are unmodified copies.

Review board: `world-arenas-review.html` (self-contained, downscaled jpegs).
Brief + freeze checklist: `BRIEF.md`. Spend: `image-spend.json` (5 calls, cap 5, refine allowance unused).

## Ship table

| # | File | Arena | Location | Reads as | Gate result |
|---|------|-------|----------|----------|-------------|
| 1 | `01-torii.png` | `torii` — Portale Torii | Kyoto, Japan — dusk | vermilion torii colonnade, pagoda, lanterns, petals, crescent moon | G1–G3 pass; camera lower than game preset (far wall mid-frame) |
| 2 | `02-medina.png` | `medina` — Cortile Medina | Marrakech, Morocco — golden hour | horseshoe arch gate, date palms, brass lanterns, zellige band | G1–G3 pass; camera high down-court |
| 3 | `03-carioca.png` | `carioca` — Terrazza Carioca | Rio de Janeiro, Brazil — midday | Sugarloaf ridgeline, palm rows, wave foam | G1–G3 pass; camera lateral/mid-height |
| 4 | `04-aurora.png` | `aurora` — Banco Aurora | Iceland — night | basalt columns, snow ridge, steam plumes, aurora ribbons | G1–G3 pass; court readable in dark palette |
| 5 | `05-egeo.png` | `egeo` — Isola Egeo | Santorini, Greece — midday | white cubes, cobalt domes, windmill, bougainvillea | G1–G3 pass; camera high down-court |

sha256:
```
7270dc64c00e7278f1620679fa73c852e0dfa6d1ccf62e42296e7fd08e6641bd  01-torii.png
de48d63e7419010ab88cfec999252f7f964f3afd5feb0b058706e33050fbbbe  02-medina.png
513ec2ad7e609621d2e1a3a8e4dc525cdc2225fb8f78cb41a474df369fd808b8  03-carioca.png
1d2dcdad5bc77aa7563408da050a38e2eebbd7ed175709c0e90ce2e1398f2e01  04-aurora.png
4097f12b0a3515be2ecb83dd329207fd58799a3123a56d9df6074e8238c76dd8  05-egeo.png
```

## Shared DNA (verbatim in all five prompts)

See `BRIEF.md`. Low-poly stylized 3D, smooth shading; the game's common court/net/cage seen
through the far glass; smooth vertical sky gradient with landmark shapes on the horizon
behind the rear wall; empty court, no players/text/UI. Verified by external vision pass on
the actual files: all five low-poly with smooth shading, no text/logos/people/UI, no
geometry flaws.

## Recreation contract

One `ArenaStyle.STYLES` entry per arena, `family: "world"` (own gradient + glow, like the
fantasy family), sky stops copied from the still, apron from the ground-beyond-court tone,
props at metre positions in the scenery band with the new kinds listed per row in the board.
Existing court, net and cage geometry untouched — the reference says they are common to all
arenas (`js/render.js:704`).

Field law (hard requirement, carried into any plan): every gameplay frame shows the whole
court — both baselines, all four glass walls including the rear glass the ball bounces off —
with the ball trackable through every bounce; arena scenery stays in the band above the rear
glass and the wedges outside the cage, never over the court. The stills' camera is
illustrative, not the framing target: the game's camera presets are the authority, and the
stills are frozen — do not regenerate them to chase framing.

Known deviations to keep honest when recreating: stills 1 and 3 pose the camera lower than
the game's presets, so their backdrop band reads taller than it will in-game; the in-game
framing will show less sky and more court than these stills do.
