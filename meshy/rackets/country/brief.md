# The Five Country Specials — Meshy front-view set (country line, round 1)

Purpose: input images for Meshy **Image-to-3D** (single-image mode) for the five special
padel rackets of the country line designed 2026-09-17 — the second themed set, alongside the
steampunk five (`../steampunk/brief.md`). The owner runs the Meshy GUI steps; this set is the
input.

Lane: Hermes `image_gen`, provider `openai`, model `gpt-image-2.5-flare`, portrait 1024x1536,
**text-to-image** (no reference images — the designs are prop-clean by construction and
reference scenes would bleed background and light into the texture bake). One generation per
racket, 5 total, no retries. Spend + source caches: `art/generated/rackets/country/image-spend.json`.
Design authority: `art/generated/rackets/country/DESIGN.md`.

## Delivery — five front views

| Tier | id | Name | File | sha256 |
|---|---|---|---|---|
| 1 | capezza | La Capezza | `views/capezza-front.png` | `dd6d2cdb66a1c14cbebee9eb1fca72c3629faa42f183410657e4ffd078cace29` |
| 2 | bottone | Il Bottone | `views/bottone-front.png` | `ce568483e6623737eab3c32cbd0b0da3166bcdf1081d7597fbed04c7d0807002` |
| 3 | marchio | Il Marchio | `views/marchio-front.png` | `f3b12305210e9522be5b1dede6c25abc7def62580f1863ee65fb657e930dafc5` |
| 4 | alambicco | L'Alambicco | `views/alambicco-front.png` | `be328f41d3644bc228b48d0107f473179198eb7ba331d608caab2e147903324d` |
| 5 | bisonte | Il Bisonte Bianco | `views/bisonte-front.png` | `46707dcc87e899bab1df09567fbd66c44635140e72bed3a5c719f088b106040f` |

## Checklist (frozen before the round) — results

- **G1** single racket, straight-on flat front view, head up / handle down, full racket with
  margin, nothing touching the edges — PASS ×5 (0 ink pixels under 240 in the outer 3 px
  border of every file; side margins 136–193 px, top/bottom 20–42 px).
- **G2** pure flat white background, no vignette / gradient / cast shadow — PASS ×5 (corner
  means 254.0–254.2 of 255). A faint soft shading was visually flagged on Bottone and
  Alambicco; the mechanical audit found no shadow band — the strip below each subject holds
  at most 13 near-white samples (under 252) and zero under 245. Nothing to strip for bake.
- **G3** matte materials only — PASS with two value notes: Bottone's pearl snaps and placket
  button show small specular highlights (reads as pearl, bakes as colour); Alambicco's copper
  reads semi-gloss (no chrome, no glow). Engine material can be set matte after import —
  same precedent as Novilunio's painted ring and Cornetto's shiny crust.
- **G4** design matches the line DNA (per racket, below) — PASS ×5 with three deviations,
  all accepted for bake and left for the owner's eye: Bottone's snaps land in a grid rather
  than the designed arc; Marchio's throat reads as a Y rather than a rod bent into the face
  glyph; Bisonte carries a small dark strap at the grip end (reads as the single dark band).
- **G5** no text, watermark, hands, people, logo, second object — PASS ×5.

Binary, recorded: fill about 90% of frame height — actual **95.1–97.3% height**, 62.4–72.0%
width; even diffused light. PASS.

Verification: one external vision pass per file plus parent hash / border / corner /
shadow-strip measurements (above). Ad-hoc evidence — the owner's eye stays the gate.

## DNA used (condensed per racket)

1. **La Capezza** — bent grey fence-wire hoop stretched with pale feed-sack canvas,
   awl-punched with a scatter of holes, sagging slightly; worn ash-wood frame rails; thick
   three-strand rope binding throat and grip; plain leather noseband butt cap.
2. **Il Bottone** — doubled indigo denim face with fine woven texture; an arc of round
   mother-of-pearl snaps in small metal rings as the perforation; folded placket throat;
   tightly wound starched sleeve grip.
3. **Il Marchio** — wrought-iron face pierced clean through in a ring of punch holes forming
   a ranch brand glyph; hammered black iron; rod throat bent like the glyph; scorched latigo
   grip with charred edges.
4. **L'Alambicco** — hammered copper pot-still face with dimples, soldered seams, rows of
   mash-plate holes; swan-neck bent down into the throat; dark leather grip with thin copper
   wire.
5. **Il Bisonte Bianco** — bone-white head with faint old-bone grain, hoofprint-shaped holes;
   horn-curved throat pale with a darkened tip; short pale-brown mane tufts shingled along
   the upper frame edge; pale leather grip with a single dark band.

## Meshy GUI recipe

Same steps as the steampunk set (`../steampunk/brief.md`), with these notes:

1. **Image to 3D** (single image mode) — upload `<id>-front.png` as the primary image.
2. No rig step (rigid prop). Target polycount: start about 30k; decimate to roughly 8–12k
   after retopology.
3. White-background shots bake clean albedo. Bottone's snaps and Alambicco's copper may want
   matte set on import if the bake looks hot (precedent: Novilunio ring, Cornetto crust).
4. Real-world size about 45 cm long; the engine rescales at the hand anchor
   (`mixamorig:RightHand` via `AthletesView.RACKET_HAND_LOCAL` / `RACKET_HAND_ROTATION`).
5. Working ids: `capezza`, `bottone`, `marchio`, `alambicco`, `bisonte`.

## Appendix — the shared prompt block (verbatim, round 1)

> Clean studio product photograph of a single padel racket shown straight-on in a flat
> front view: the perforated head facing the camera, handle pointing straight down,
> perfectly centered and vertical, minimal perspective distortion, realistic padel-racket
> proportions (slim modern paddle, roughly 45 cm long and a 26 cm wide head). Pure
> seamless flat white background of uniform #ffffff, no vignette, no gradient, no cast
> shadow, no floor, no environment — the racket floats isolated in frame with a small even
> margin on all sides, nothing touching the image edge, the full racket filling about 90
> percent of the frame height. Even diffused studio lighting, soft matte shading that
> reads the forms clearly. All materials matte: no chrome, no mirror reflections, no
> glass, no transparency, no glow or light emission, no steam, no particles. Padel racket
> anatomy: teardrop head with a perforated face, solid throat bridge, wrapped grip
> with wrist cord. No text, no watermark, no hands, no people, no logo, no second object.

Each call appended its racket's subject paragraph under this block. Source renders cached
under `~/.hermes/profiles/dev-work/cache/images/` (paths in the ledger).
