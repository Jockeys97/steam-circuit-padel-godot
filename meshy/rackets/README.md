# Racket sets — design + Meshy intake

Themed special-racket lines for the game. Each set: one generation per racket, same intake
spec — text-to-image, portrait 1024x1536, pure-white matte studio **front view** (shared
prompt block verbatim in each set's brief). Every file verified by sha256 + border/corner
measurement plus one external vision pass; results and deviations in the set's brief.

## Layout convention (same for every set)

- Intake views (the upload files): `<theme>/views/<id>-front.png`
- Set brief — checklist, results, DNA, Meshy GUI recipe: `<theme>/brief.md`
- Design sheet + spend ledger (round history): `art/generated/rackets/<theme>/` —
  `DESIGN.md`, `image-spend.json`
- Working id = file stem. Tier = rung within its set's ladder.

Athlete turnarounds are a different world: they live in `meshy/views/` + `meshy/<name>-brief.md`
(see the main README). Racket sets live here.

## steampunk (2026-09-17) — from a vent to the stars

Five rungs: steam → clockwork → sound → darkness → starlight. Round history: r1 direction
stills (scene shots, kept as design reference in the design folder) + r2 intake views.
Design sheet: `art/generated/rackets/steampunk/DESIGN.md`. Brief: `steampunk/brief.md`.

| Tier | id | Name | File | sha256 (first 16) |
|---|---|---|---|---|
| 1 | sfiato | Lo Sfiato | `steampunk/views/sfiato-front.png` | `72b281cad2a0297d` |
| 2 | scatto | Lo Scatto | `steampunk/views/scatto-front.png` | `9b5f2cb50ad216ce` |
| 3 | campanone | Il Campanone | `steampunk/views/campanone-front.png` | `74b9d819f583e9b4` |
| 4 | novilunio | Il Novilunio | `steampunk/views/novilunio-front.png` | `c70f4e3afe003dfd` |
| 5 | orsa-maggiore | L'Orsa Maggiore | `steampunk/views/orsa-maggiore-front.png` | `c13409b41ee7ba57` |

Known partial: Novilunio's cyan edge ring reads painted rather than metallic (accepted for
bake).

## country (2026-09-17) — from the ranch to the plains

Five rungs: work → cloth → fire → spirit → legend (ranch rope and canvas → Sunday-best denim
→ the forge → the still → the plains' legend). The intake views are the round-1 artifacts —
no scene stills by design. Design sheet: `art/generated/rackets/country/DESIGN.md`.
Brief: `country/brief.md`.

| Tier | id | Name | File | sha256 (first 16) |
|---|---|---|---|---|
| 1 | capezza | La Capezza | `country/views/capezza-front.png` | `dd6d2cdb66a1c14c` |
| 2 | bottone | Il Bottone | `country/views/bottone-front.png` | `ce568483e6623737` |
| 3 | marchio | Il Marchio | `country/views/marchio-front.png` | `f3b12305210e9522` |
| 4 | alambicco | L'Alambicco | `country/views/alambicco-front.png` | `be328f41d3644bc2` |
| 5 | bisonte | Il Bisonte Bianco | `country/views/bisonte-front.png` | `46707dcc87e899ba` |

Noted deviations (accepted for bake): Bottone's pearl snaps land in a grid rather than the
designed arc and catch small highlights; Marchio's throat reads Y-shaped rather than the
face glyph; Alambicco's copper is semi-gloss.

## Adding the next set

Make a `<theme>/` folder next to these, drop the intake views in `<theme>/views/`, write
`<theme>/brief.md` beside them, and put the design sheet + ledger under
`art/generated/rackets/<theme>/`. Same intake spec; reuse the shared prompt block from an
existing brief.
