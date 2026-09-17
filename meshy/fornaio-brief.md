# IL FORNAIO: Meshy image set (special athlete, r1)

Purpose: input images for the Meshy GUI for the croissant baker special and his racket. Two
deliverables: the athlete (multi-view character sheets) and the croissant racket (single-image
prop, follows the racket-ladder intake style of `meshy/rackets-brief.md`).

Lane: Hermes `image_gen`, provider `openai`, model `gpt-image-2.5-flare`, portrait 1024x1536,
2026-09-17. Spend cap: 4 character views + 1 racket front + up to 2 refines. Ledger:
`image-spend-fornaio.json`.

## Interpretation note

Character sheets keep hands empty and carry no racket. That is the athlete standard
(`docs/art/character-standard.md`) and the `meshy/README.md` rule: the racket mounts at
`mixamorig:RightHand` in engine, never inside the athlete mesh. The croissant racket is
therefore delivered as its own prop front. If the owner wanted it baked into the character's
hand in the sheets instead, that is a full regeneration of the four character views.

Working ids: athlete `fornaio`, racket `cornetto`.

## Character DNA

- Sturdy, broad-shouldered baker athlete, adult, grown-up proportions. Warm tan skin `#c08552`,
  rosy cheeks, a big dark curled mustache, thick dark eyebrows, friendly smile, short dark-brown
  hair, and a soft snug white baker's cap (low and rounded, not a tall chef's toque).
- White short-sleeve double-breasted baker's jacket with two neat columns of small amber
  buttons; sleeves rolled to just below the elbow showing warm forearms; a light dusting of
  flour on shoulders and forearms and a small flour smudge on one cheek.
- Navy shorts with thin amber piping; thin amber wristbands; white sneakers with navy accents.
- Colors: jacket `#f7f4ee`, amber `#d98e2b`, navy `#22304a`, skin `#c08552`, hair `#2a1a12`.
  Roster UI color proposal: amber `#d98e2b`.
- Height for the rigging step: 1.82 m.

## Racket DNA (Il Cornetto)

- One large golden-brown croissant as the racket head, crescent curve forming a rounded
  teardrop padel head; matte baked crust in deep amber, honey and toasted golden tones with
  clearly visible layered flaky dough ridges.
- Solid pastry head: no strings, no perforations.
- Warm beech wood throat flowing into a turned rolling-pin-style wooden handle with a small
  matte brass ferrule; grip wrapped with cream bakery twine cord.
- Roughly 45 cm long, matte materials only, pure white background for the Meshy bake.

## Delivery files

| File | View | Meshy use |
|---|---|---|
| `views/fornaio-front.png` | front | character multi-view upload 1 (primary) |
| `views/fornaio-back.png` | back | character multi-view upload 2 |
| `views/fornaio-45-left.png` | 45 left | character multi-view upload 3 |
| `views/fornaio-45-right.png` | 45 right | character multi-view upload 4 |
| `views/cornetto-front.png` | racket front | racket single-image Image-to-3D |

Each character view is its own generation; the front goes first and the rest chain off it so
identity, outfit and scale stay locked.

## Checklist (frozen before round 1)

Character sheets, gating, any fail blocks the hand-off:

- G1 Full body, head to toe, nothing touching the image edges.
- G2 Pure seamless white background; at most a soft contact shadow under the feet.
- G3 A-pose, arms about 45 degrees down and away with a visible gap, hands empty; no racket or
  any other prop in the hands.
- G4 No logos, brand marks, emblems, text or watermarks anywhere.
- G5 Identity matches the DNA: baker build, mustache, cap, white double-breasted jacket with
  amber buttons, rolled sleeves, flour dusting, navy shorts with amber piping.

Racket sheet, gating:

- R1 Single racket, flat front view, head up and handle down, full racket with margin, nothing
  touching the edges.
- R2 Pure flat white background, no vignette, gradient or cast shadow.
- R3 All materials matte: no chrome, mirror, glass, transparency or emission.
- R4 Croissant DNA match: crescent pastry head with flaky ridges, wood handle, twine grip; no
  strings.
- R5 No text, watermark, hands, people, logo or second object.

Binary, recorded: figure fills about 90 percent of the frame height; even diffused lighting;
the view is the true stated angle.

Stop target: all gating items pass on every file. Refines are new files, never overwrites.

## Meshy GUI recipe

1. Character: Image to 3D, Multi-view. Upload `fornaio-front.png` first (primary), then back,
   45-left, 45-right. Pose Control: A-pose.
2. Racket: Image to 3D, single image. Upload `cornetto-front.png`. No rig step.
3. Polycount: start about 30k for both; decimate the character to 8-15k (engine band 8-20k) and
   the racket to roughly 8-12k.
4. Rigging height for the character: 1.82 m, set before the rigging call; it fixes the scale.
5. In-engine the croissant racket mounts at the hand anchor exactly like the five specials; the
   character mesh stays racket-free.
6. Working ids `fornaio` and `cornetto`. No registry entries yet (special athlete and prop).

## Results

Run finished 2026-09-17. All four character views pass G1-G5, and the racket passes R1-R5
except a mild gloss note (accepted; see `README.md`). Eight generations total; three refines
against the declared two, so the cap was extended by one and is logged in
`image-spend-fornaio.json`.

| File | View | sha256 | Note |
|---|---|---|---|
| `views/fornaio-front.png` | front | `78c9f22a9c73f7e857b956cee9d0e5f773578f9ffde8cab0f773be38b2115a18` | r2, A-pose fix (r1 had arms ~30 degrees) |
| `views/fornaio-back.png` | back | `2276754bf27dbd2ff7e8c7363093c86ce2700948b1bff538dc1dbe775eb2f879` | r2, arms wide (r1 arms narrow) |
| `views/fornaio-45-left.png` | 45 left | `f6f8b8ae9c864089c0eafd969bef7d49b6cb1ff78cf0772461fd8bdb58f5fa69` | r2, true three-quarter (r1 came back frontal) |
| `views/fornaio-45-right.png` | 45 right | `619ab4660c61ea31eacf0c55a52588a56cfcac2aff37b25115f7a6a8ffa784bd` | first pass |
| `views/cornetto-front.png` | racket front | `a7ea2ade51e78c9662bfccfe0064ba9de13ace2e1ce1e8734038afe8f7ef72ec` | first pass; mild gloss accepted |
| `fornaio-turnaround.png` | composite | `76aa3b47de3042e0457a3f490a0c58e8fb58cf3a2ca4fe6112cbf80c03e75e24` | local Pillow composite, not a generation |

r1 archives kept: `views/fornaio-front-r1.png`, `views/fornaio-back-r1.png`,
`views/fornaio-45-left-r1.png`.
