# IL BURATTINO: Meshy image set (special athlete, r1)

Purpose: character reference images to upload into Meshy **Image to 3D, Multi-view** for the new
special, IL BURATTINO. The owner runs the Meshy steps in the GUI. This set is the input.

Lane: Hermes `image_gen`, provider `openai`, model `gpt-image-2.5-flare`, portrait, 2026-09-17.
Spend: cap 6 generated images (4 views plus up to 2 refines). Ledger: `image-spend.json`.

## Character DNA (reused in every prompt)

- Wooden marionette athlete. Warm pine wood with subtle grain; walnut-brown ball joints at
  shoulders, elbows, wrists, hips, knees, ankles; carved wooden hands and feet; thin seams at
  elbows and knees.
- Painted face: large friendly dark painted eyes with tiny highlights, painted eyebrows, rosy
  painted cheeks, cheerful painted smile, small carved nose.
- Chunky brass wind-up key on the upper back, between the shoulder blades.
- Outfit: cream short-sleeve shirt, emerald vest with gold buttons and gold trim, navy shorts with
  emerald piping, emerald wristbands.
- Colors: pine `#d9a066`, walnut `#6b4326`, cheeks `#e88a8a`, shirt `#f2ece1`, vest `#19b26b`,
  gold `#d5a62a`, shorts `#22304a`, brass `#c9a227`. Roster UI color proposal: emerald `#19b26b`.

## Delivery: four view files

| File | View | Meshy upload order |
|---|---|---|
| `views/burattino-front.png` | front | 1 (primary) |
| `views/burattino-side.png` | true 90 side | 2 |
| `views/burattino-back.png` | back | 3 |
| `views/burattino-45.png` | 45 three-quarter | 4 |

Each view is its own generation; the front is generated first and the other three chain off it so
identity, outfit and scale stay locked.

## Checklist (frozen before round 1)

Gating, any fail on any view blocks the hand-off:

- G1 Full body, head to toe, nothing touching the image edges.
- G2 Pure seamless white background; at most a soft contact shadow under the feet.
- G3 A-pose, arms about 45 degrees down and away, hands empty. No racket, no props, no strings,
  no wires.
- G4 No logos, brand marks, emblems, text or watermarks anywhere.
- G5 Identity matches the DNA: wooden puppet with ball joints, painted face, emerald vest with
  gold buttons; wind-up key visible in the back view.

Binary, recorded but not gating:

- B1 Even diffused lighting, no harsh baked shadows.
- B2 Figure fills about 90 percent of the frame height.
- B3 The view is the true stated angle (front / 90 side / back / 45).

Stop target: all gating items pass on all four views. Refines are new files, never overwrites.

## Meshy GUI recipe

1. Image to 3D, switch to Multi-view. Upload `burattino-front.png` first (primary view), then
   side, back, 45.
2. Pose Control: A-pose. Target polycount about 30k.
3. After retopology decimate to 8-15k (engine band 8-20k, remesh target 12k).
4. Rigging: height 1.66 m. Set it before the rigging call; the height fixes the model scale and
   cannot be corrected without re-rigging.
5. The racket is not in the images on purpose; it attaches to `mixamorig:RightHand` in engine.
6. Working id `burattino`. No `roster-3d.json` entry yet; that lands with the first GLB as the
   owner-decided special beyond the frozen six.

## Results

All four views delivered 2026-09-17, each passing G1-G5 on a vision check. Generation and
checklist details in `README.md` (section IL BURATTINO image set).

| File | View | sha256 | Note |
|---|---|---|---|
| `views/burattino-front.png` | front | `d862b29822a6f86f33b84dc8518b47eb24898e850e5632048c761811b045aaea` | probe view |
| `views/burattino-side.png` | true 90 side | `2d02a9e9b0f590a97c7af1a944e30c0473b0c58761bfcc75a606ce17ec4b5f33` | r2, A-pose fix |
| `views/burattino-back.png` | back | `0feed90638fc8bd8e706b1ac8daecf4e581af044a5ff64605397a287aed5d7e3` | key clearly visible |
| `views/burattino-45.png` | 45 three-quarter | `b64b12a79f36349cfb3aa36152e1992660393d2e45276118a9bc8139b75ceefc` | r2, A-pose fix |
| `burattino-turnaround.png` | composite | `fc32789e60e180ff754d6407396ba3e4112f1d176213e73b95c19181c241a5d8` | local Pillow composite, not a generation |

The r1 side and 45 files are kept as `views/burattino-*-r1.png`. If a regeneration is ever
needed, reuse the passing prompt register from `README.md`; photoreal doll phrasing was
rejected by output moderation four times.
