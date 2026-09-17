# The Five Specials — Meshy front-view set (racket ladder, round 2)

Purpose: input images for Meshy **Image-to-3D** (single-image mode) for the five special
padel rackets of the tier ladder designed 2026-09-17. The owner runs the Meshy GUI steps;
this set is the input.

Lane: Hermes `image_gen`, provider `openai`, model `gpt-image-2.5-flare`, portrait
1024x1536, **text-to-image** (no reference images on purpose: the r1 direction stills carry
scenes whose background and furnace light would bleed into the texture bake). One
generation per racket, 5 total, no retries. Spend + source caches:
`art/generated/rackets/steampunk/image-spend.json` (`round_2_meshy_front`). Design authority:
`art/generated/rackets/steampunk/DESIGN.md`; r1 direction stills in `art/generated/rackets/steampunk/<id>/`.

## Delivery — five front views

| Tier | id | Name | File | sha256 |
|---|---|---|---|---|
| 1 | sfiato | Lo Sfiato | `views/sfiato-front.png` | `72b281cad2a0297d577eb1010ed115b25bbb85f8fc4384a01eb5f4d6e4766755` |
| 2 | scatto | Lo Scatto | `views/scatto-front.png` | `9b5f2cb50ad216ce7a408480b1d573e2c3d1504d9ee7102e338feab00670ed1c` |
| 3 | campanone | Il Campanone | `views/campanone-front.png` | `74b9d819f583e9b424c3d7fc38d4ed0e468477668208979bbb8311b1c56afccb` |
| 4 | novilunio | Il Novilunio | `views/novilunio-front.png` | `c70f4e3afe003dfd3e2dfbfa9e79569c6881a6d668bda3eefc04a7e80a7133d0` |
| 5 | orsa-maggiore | L'Orsa Maggiore | `views/orsa-maggiore-front.png` | `c13409b41ee7ba57ee4b53013804f54be94f2fa283a39d65454af298e733dd5b` |

## Checklist (frozen before round 2) — results

Gating, any fail blocks the hand-off:

- **G1** single racket, straight-on flat front view, head up / handle down, full racket
  visible with margin, nothing touching the edges — PASS ×5 (measured: 0 ink pixels in the
  outer 3 px border on any file; smallest margin 28 px).
- **G2** pure flat white background, no vignette / gradient / cast shadow — PASS ×5
  (corner means 254.0–254.2 of 255; border minimum 253).
- **G3** matte materials only — no chrome, mirror, glass, transparency or emission
  (Meshy bake rule) — PASS ×5.
- **G4** design matches the ladder DNA (per-racket, below) — PASS ×5, one partial:
  Il Novilunio's cyan edge ring reads as painted colour rather than a metal part; accepted
  (it bakes as colour — see recipe step 5).
- **G5** no text, watermark, hands, people, logo, second object — PASS ×5.

Binary, recorded: fill about 90% of frame height — actual **93.9–96.0% height**,
67.3–84.5% width; even diffused light. PASS.

Verification: one external vision pass per file (delivered with the renders) plus parent
hash / border / corner measurements (above). Ad-hoc evidence — the owner's eye stays the gate.

## DNA used (condensed per racket)

1. **Lo Sfiato** — hammered scrap-steel over a beech core, matte worn grey with rust-brown
   edge staining, mismatched soft rivets, chunky matte brass pressure valve on the throat
   bridge just below the head, dull taped black rubber grip.
2. **Lo Scatto** — matte polished dark steel frame, neat brass fasteners, exposed
   ratchet-gear stack at the throat driving a small matte cyan-tinted metal wheel,
   machined bevels, clean dark leather grip.
3. **Il Campanone** — one flowing cast of matte warm golden bronze, hand-scraped,
   engraved concentric arcs, bell-mouth swell at the throat, aged brown leather-and-wire
   grip. Head is a clear teardrop (r1's round read fixed).
4. **Il Novilunio** — deep matte black face, thin cyan-tinted edge ring, matte dark-grey
   alloy frame with small old-gold accents, engraved black-moon motif at the throat
   (no clocks — r1's stray detail removed), black leather grip with gold ferrule.
5. **L'Orsa Maggiore** — matte brass-and-gold frame, celestial engraving, exactly seven
   small gold star ornaments on short brass arms around the head, midnight-blue
   star-dusted face, armillary-ring collar, dark brown leather grip.

## Meshy GUI recipe

1. **Image to 3D** (single image mode) — upload `<id>-front.png` as the primary image.
   Multi-view is not needed for the first pass; if the mesh wants it, side/back views can
   chain off these fronts later.
2. Pose control: not applicable (rigid prop, no rig step).
3. Target polycount: start about 30k; decimate to roughly 8–12k after retopology
   (engine band for hero props; athletes sit 8–20k).
4. No rigging/animation steps.
5. Texture note: white-background shots bake clean albedo; the Novilunio cyan ring bakes
   as colour — raise metalness in the material if you want the ring to catch light.
6. Real-world size about 45 cm long; the engine rescales at the hand anchor. In-engine the
   racket is currently procedural (`Court.make_racket_view`) attached at
   `mixamorig:RightHand` with the offsets in `AthletesView.RACKET_HAND_LOCAL` /
   `RACKET_HAND_ROTATION`; swapping in a GLB is an engine-lane change that reuses the
   same anchor.
7. Working ids: `sfiato`, `scatto`, `campanone`, `novilunio`, `orsa-maggiore`
   (no racket registry analogue of `roster-3d.json` yet).

## Appendix — the shared prompt block (verbatim, round 2)

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
> anatomy: teardrop head with a perforated dark face, solid throat bridge, wrapped grip
> with wrist cord. No text, no watermark, no hands, no people, no logo, no second object.

Each call appended its racket's subject paragraph under this block. Source renders cached
under `~/.hermes/profiles/dev-work/cache/images/` (paths in the ledger).
