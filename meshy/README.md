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

## IL BURATTINO image set (2026-09-17)

Special athlete, beyond the frozen six. The owner runs the Meshy steps in the GUI; this set is
the input. Brief, checklist and upload recipe: `burattino-brief.md`. Spend log:
`image-spend.json`. Lane: `openai` / `gpt-image-2.5-flare`, portrait 1024x1536, each view
chained off the front so identity and scale stay locked.

| File | View | sha256 (first 16) |
|---|---|---|
| `views/burattino-front.png` | front | `d862b29822a6f86f` |
| `views/burattino-side.png` | true 90 side | `2d02a9e9b0f590a9` |
| `views/burattino-back.png` | back | `0feed90638fc8bd8` |
| `views/burattino-45.png` | 45 three-quarter | `b64b12a79f36349c` |

`burattino-turnaround.png` (sha256 `fc32789e60e180ff`) is a local Pillow composite of the four
view files, made by `make_turnaround_sheet.py`. It is not a generation; the four view files are
the upload set.

All four views pass the gating checklist (full body, white background, A-pose with a visible arm
gap, no props or logos, DNA match, key visible in back and side). The first side and 45 renders
came back with arms hanging instead of the A-pose gap and were regenerated; the r1 files stay
alongside as `*-r1.png`.

Moderation note for regenerations: four attempts (three front, one side) were rejected by OpenAI
output moderation ("other") on photoreal doll registers. The register that passes is
"family-friendly video game character, adult grown-up proportions, stylized, wholesome".
Keep it if this character is ever re-generated.

DNA used: jointed wooden athlete mascot with adult proportions; warm pine wood with subtle
grain; rounded articulated joints at shoulders, elbows, wrists, hips, knees, ankles; friendly
cartoon face; cream short-sleeve shirt, emerald vest with gold buttons, navy shorts with emerald
piping, emerald wristbands; brass clockwork wind-up key on the upper back. Colors: pine
`#d9a066`, walnut `#6b4326`, shirt `#f2ece1`, vest `#19b26b`, gold `#d5a62a`, shorts `#22304a`,
brass `#c9a227`. Roster UI color proposal: emerald `#19b26b`. Rig height: 1.66 m.

## The Five Specials — racket front views (2026-09-17)

Meshy intake set for the five special rackets of the tier ladder (design sheet:
`art/generated/rackets/steampunk/DESIGN.md`). One clean **front view per racket**, text-to-image so no
scene colour bleeds into the bake. Lane: `openai` / `gpt-image-2.5-flare`, portrait
1024x1536, one generation each; ledger `art/generated/rackets/steampunk/image-spend.json`
(`round_2_meshy_front`); brief + GUI recipe: `rackets/steampunk/brief.md`.

| Tier | id | Name | File | sha256 (first 16) |
|---|---|---|---|---|
| 1 | sfiato | Lo Sfiato | `rackets/steampunk/views/sfiato-front.png` | `72b281cad2a0297d` |
| 2 | scatto | Lo Scatto | `rackets/steampunk/views/scatto-front.png` | `9b5f2cb50ad216ce` |
| 3 | campanone | Il Campanone | `rackets/steampunk/views/campanone-front.png` | `74b9d819f583e9b4` |
| 4 | novilunio | Il Novilunio | `rackets/steampunk/views/novilunio-front.png` | `c70f4e3afe003dfd` |
| 5 | orsa-maggiore | L'Orsa Maggiore | `rackets/steampunk/views/orsa-maggiore-front.png` | `c13409b41ee7ba57` |

All five: pure flat white background, matte materials (no chrome / glass / emission), full
racket with margin (0 ink pixels in the outer 3 px; fills 94–96 percent of the height),
verified by hash + border/corner measurement plus one external vision pass per file.
Known partial: Novilunio's cyan edge ring reads painted rather than metallic — accepted
for bake, noted in the brief. Upload recipe in `rackets/steampunk/brief.md`. Both racket sets
are indexed, with the folder conventions, in `rackets/README.md`.

## The Five Country Specials — racket front views (2026-09-17)

Second themed racket line (design sheet: `art/generated/rackets/country/DESIGN.md`):
La Capezza → Il Bottone → Il Marchio → L'Alambicco → Il Bisonte Bianco — an arc from the ranch
to a plains legend. Same intake lane and spec as the steampunk set — one clean **front view per
racket**, text-to-image, portrait 1024x1536, one generation each; ledger
`art/generated/rackets/country/image-spend.json`; brief + GUI recipe: `rackets/country/brief.md`.

| Tier | id | Name | File | sha256 (first 16) |
|---|---|---|---|---|
| 1 | capezza | La Capezza | `rackets/country/views/capezza-front.png` | `dd6d2cdb66a1c14c` |
| 2 | bottone | Il Bottone | `rackets/country/views/bottone-front.png` | `ce568483e6623737` |
| 3 | marchio | Il Marchio | `rackets/country/views/marchio-front.png` | `f3b12305210e9522` |
| 4 | alambicco | L'Alambicco | `rackets/country/views/alambicco-front.png` | `be328f41d3644bc2` |
| 5 | bisonte | Il Bisonte Bianco | `rackets/country/views/bisonte-front.png` | `46707dcc87e899ba` |

All five: pure flat white background, matte materials (no chrome / glass / emission), full
racket with margin (0 ink pixels in the outer 3 px; fills 95–97 percent of the height),
verified by hash + border/corner measurement plus one external vision pass per file. Noted
deviations (accepted for bake): Bottone's pearl snaps land in a grid rather than the designed
arc and catch small highlights; Marchio's throat reads Y-shaped rather than the face glyph;
Alambicco's copper is semi-gloss. Upload recipe in `rackets/country/brief.md`.

## IL FORNAIO image set (2026-09-17)

Special athlete, beyond the frozen six, plus his prop racket. Brief, checklist and GUI recipe:
`fornaio-brief.md`. Spend log: `image-spend-fornaio.json`. Lane: `openai` /
`gpt-image-2.5-flare`, portrait 1024x1536; the character views chain off the front, the racket
is text-to-image in the five-specials intake style. Athlete sheets keep hands empty on purpose:
the racket mounts at the hand anchor in engine, never inside the mesh.

| File | View | sha256 (first 16) |
|---|---|---|
| `views/fornaio-front.png` | front | `78c9f22a9c73f7e8` |
| `views/fornaio-back.png` | back | `2276754bf27dbd2f` |
| `views/fornaio-45-left.png` | 45 left | `f6f8b8ae9c864089` |
| `views/fornaio-45-right.png` | 45 right | `619ab4660c61ea31` |
| `views/cornetto-front.png` | croissant racket front | `a7ea2ade51e78c96` |

`fornaio-turnaround.png` (sha256 `76aa3b47de3042e0`) is a local Pillow composite of the four
character views, made with `python3 make_turnaround_sheet.py fornaio front back 45-left
45-right`; not a generation.

All four character views pass the gating checklist (full body, white background, A-pose with a
wide arm gap, empty hands, DNA match). Three renders were regenerated once each and their r1
files stay alongside: front (arms ~30 degrees), back (arms narrow), 45 left (came back frontal,
a duplicate of the front angle). The racket passes its checklist except a mild gloss note: the
brass ferrule and crust bake slightly shiny (accepted for bake, engine material can set matte,
same precedent as Novilunio's painted ring).

Character DNA: sturdy broad-shouldered baker, big dark curled mustache, white snug baker's cap,
white short-sleeve double-breasted jacket with amber buttons and rolled sleeves, flour dusting
on shoulders and forearms, navy shorts with amber piping, amber wristbands, white sneakers with
navy accents. Colors: jacket `#f7f4ee`, amber `#d98e2b`, navy `#22304a`, skin `#c08552`.
Roster UI color proposal: amber `#d98e2b`. Rig height: 1.82 m. Racket working id `cornetto`
(Il Cornetto): croissant head with flaky ridges, beech handle, twine grip, no strings. Placement
note: `art/generated/rackets/steampunk/DESIGN.md` parks comedy kitchen rackets (La Caffettiera) as
celebration/seasonal material, so Cornetto reads as a character signature rather than a sixth
ladder rung.

Zero moderation blocks this run: the family-friendly register from the Burattino section was
reused from the first attempt.
