# Meshy-ready turnaround sheets

Generated with `openai/gpt-image-2.5-flare-high` (Hermes image_gen), 1536x1024 PNG, 2026-09-16.
Purpose: reference images to upload into Meshy Image-to-3D for the two demo playable athletes,
plus the special unlock.

| File | Character | sha256 |
|---|---|---|
| `maestro-turnaround.png` | IL MAESTRO (control) | `7af8352b3da072262350477216cb0aff46ce8066ba7166da0e519bb70efa7887` |
| `steamer-turnaround.png` | LO STEAMER (power) | `16ddb09a002bbc42d168f08e98b4eb09484e15dc8e1293003c0c5078b7dd5e01` |
| `spitz-turnaround.png` | VOLPE (special, half Spitz) | `750ab277b9b6a0470083167da5640190c8bf2295b74808eeb96efd328a57c435` |

Each sheet is one wide image with 4 full-body views left to right: front, true 90 degree side,
back, 45 degree three-quarter. Same character, same outfit, same scale, plain white background,
A-pose, hands empty, no racket.

## What Meshy actually requires (from the 3-scout scan of official docs, 2026-09-16)

Sources: docs.meshy.ai/en/webapp/image-to-3d, help.meshy.ai articles 15723519 / 9996860 /
16102152, docs.meshy.ai/en/api/multi-image-to-3d.

- Plain white or transparent background, backgrounds removed on **every** view. Reflective or
  gradient backgrounds bleed into the texture.
- Recommended angle set: front + true 90 degree side + back + 3/4. Distinct angles at least
  45-90 degrees apart. Near-duplicate angles add noise and can force false symmetry.
- Neutral, T-pose or A-pose. A-pose is arms roughly 45 degrees down and away from the torso. This
  is what makes the mesh riggable with Meshy Animate.
- Even diffused lighting, no harsh shadows. Shadows bake into the texture as fake surface detail.
- Subject fills 70-90 percent of the frame, fully visible, nothing touching the image edge.
- 1024px or more (512px floor), sharp PNG. Same character, scale and lighting across all views.
- Avoid: multiple subjects per frame (except an intentional sheet), cropped limbs, extreme
  top-down or bottom-up angles, transparent or chrome materials, mismatched scale between views.

## Upload recipe

1. Open Meshy, Image to 3D, switch to Multi-view.
2. You can upload the sheet as a single primary image, or crop the four panels into separate files
   for higher fidelity. Separate files are the documented path and give the cleanest result.
3. Front panel is the primary view. Set Pose Control to A-pose if you want the rig-ready output.
4. Target polycount for a game character: start at 30k, decimate to 8-15k after retopology.
5. Racket is not in the sheets on purpose. The in-game racket is drawn procedurally
   (`js/render.js`, ellipse head plus string grid), so model it separately or attach it in engine.

## Known blemish

`maestro-turnaround.png` and `spitz-turnaround.png` have soft contact shadows under the shoes.
`steamer-turnaround.png` has none. Meshy tolerates mild contact shadows, but if the first mesh
comes back with a grey smudge at the feet, strip the shadow (a band-limited near-white threshold
on the lower region) before re-uploading.

## Volpe final set, one generation per side

`volpe-views/` holds the current Volpe set. Each view is its own generation, not a crop: the front
was generated first and the other three used it as a reference image so the character, outfit and
scale stay identical.

| File | View | sha256 (first 16) | Branding |
|---|---|---|---|
| `volpe-views/volpe-front.png` | front | `7205d99d2c8f83ff` | Adidas-style marks on chest, shorts, sneakers |
| `volpe-views/volpe-side.png` | true 90 side | `10ab9b88f47a580e` | swoosh on sneakers |
| `volpe-views/volpe-back.png` | back | `7f82ad26760ea7c4` | clean, none |
| `volpe-views/volpe-45.png` | 45 three-quarter | `552becbf1c094f88` | swoosh on sneakers |

All 1024x1536, one figure per file, pure white background, figure fills 57 to 75 percent of the
width and 94 to 96 percent of the height, and no file has any ink in the outer 3px border.

The generator invents sportswear brand marks when it is asked for a padel kit. The back view came
out clean because the prompt named the back of the sneakers; the front, side and 45 inherited a
swoosh from the front reference. To remove them, regenerate the front with an explicit no-logo
prompt and re-propagate the other views from the new front.

## Image generation lane

The OpenAI API image endpoint returned HTTP 500 for every request (including a 7 word control
prompt) partway through this run, while status.openai.com reported no incident. Generation moved
to the ChatGPT/Codex subscription lane, which is what produced the `volpe-views/` set. That
setting lives in `image_gen.provider` / `image_gen.model` in the profile config, with a
timestamped `config.yaml.bak-*` next to it.

## Per-view files (for Meshy multi-view upload)

`views/` holds one cropped PNG per view. Upload in order front, side, back, 45, since Meshy
treats the first image as the primary view.

| Character | Files |
|---|---|
| Il Maestro | `views/maestro-{front,side,back,45}.png` |
| Lo Steamer | `views/steamer-{front,side,back,45}.png` |
| Volpe | `views/spitz-r2-{front,side,back,45}.png` |

Crops come from `split_turnaround.py` (Pillow only, no numpy):

```bash
python3 split_turnaround.py spitz-turnaround-r2.png views
```

It finds figures by column ink profile, splits touching figures at their internal ink minimum,
trims each figure to its own bounding box, then adds a 24px white border so a neighbour cannot
bleed in. Every file in `views/` passes the edge check (no ink in the outer 3px on any side).

## Volpe revision

`spitz-turnaround.png` (r1) read round and puppy-like. `spitz-turnaround-r2.png` is the same
character pushed cool: lean V-taper torso with a narrow waist, fur lying close to the body with
sculpted volume only at the ruff, chest and tail, wolfish head with narrow almond eyes, dark
liner, angular brow and a closed-mouth smirk, tall sharply pointed notched ears, tail carried
high as a plume. Outfit, goggles and view layout are unchanged.

## Character DNA used

**IL MAESTRO** - athletic male, medium frame. Tan skin `#c98258`, wavy brown hair `#241b19`,
light stubble, white headband and wristbands. Navy tee `#102d68` with a white diagonal chest
stripe `#f4fbff`, cyan sleeve and side trim `#00e5ff`, navy shorts with cyan piping, navy-white
sneakers `#123f78`.

**LO STEAMER** - big muscular male, broad frame. Tan skin `#cf7b4e`, short spiked brown hair
`#43251b`, beard, orange headband and wristbands. Orange raglan tee `#f47713` with navy sleeves
`#172c57`, navy shorts with orange side stripe, ember trim `#ff9a35`, orange-navy sneakers with
white soles `#e66b18`.

**VOLPE** (special) - half Spitz. Ivory fur `#f7f4ee` with cream shading `#e8dcc8`, upright
triangular ears with pink inner ear `#f0b8b8`, black nose and toe beans `#1a1a1a`, amber-brown
eyes `#8a5524`, fluffy curled tail, brass goggle strap pushed up on the forehead `#c9a227`.
Ivory tee `#f2ece1` with gold trim `#ffc94a`, navy shorts `#22304a`, brass-gold wristbands.
