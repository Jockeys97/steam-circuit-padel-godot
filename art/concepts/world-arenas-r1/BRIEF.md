# World-arena concept set — round 1

Direction setter for five NEW arenas themed on real world locations, to be recreated in
the Godot port (`godot/game/arenas/`). Not shipping assets; a look deck for Luca's verdict.

- Provider/model: `openai / gpt-image-2.5-flare` (dev-work `image_gen` config), 16:9, one still per arena.
- Cap: 5 generations (+1 refine if the probe fails a gating item). Ledger: `image-spend.json`.
- Raw generations are sacred: refinements are new files (`-r2`), never overwrites.

## Shared DNA — verbatim style block in every prompt

> Stylized low-poly 3D game art render, clean geometric forms with smooth shading, gentle
> ambient occlusion, soft even lighting, saturated harmonious colors, no outlines, no cel
> shading, no photorealism, no texture noise. A padel court arena seen from the game's
> broadcast camera: high above and behind the near baseline, looking down the length of the
> court; the far glass wall sits at the upper third of the frame. The court: flat deep
> navy-blue surface with crisp white lines and a net across the middle, enclosed by a padel
> glass cage whose translucent panels are held by thin pale frame lines, seen through the
> far wall. Behind and above the far glass wall: the location's scenery in the same
> low-poly language — a smooth vertical sky gradient with giant landmark shapes standing on
> the horizon, ground beyond the court in the location's own tone. Empty court: no players,
> no ball, no text, no logos, no HUD. Wide 16:9 composition.

Why these DNA items: the reference court, net and cage are COMMON to all nine arenas
(`js/render.js:704`); arenas differ only in backdrop gradient, artwork, scenery, exterior
ground, glow. The concept stills must vary exactly those four things.

## Freeze checklist (binary, fixed before round 1)

| # | Item | Gating |
|---|------|--------|
| 1 | Reads as the game's court: navy surface, white lines, net, glass cage framing, high down-court camera | G1 |
| 2 | Backdrop = smooth vertical sky gradient + landmark scenery standing at the horizon BEHIND the far glass | G2 |
| 3 | Location instant to identify (torii/pagoda · medina arch/palms · Rio ridges · aurora/basalt · Santorini domes) | G3 |
| 4 | Stylized low-poly 3D, no outlines/photoreal/painted-2D look | – |
| 5 | No players, ball, text, logos, UI | – |
| 6 | Palette matches intended gradient stops + accent glow | – |
| 7 | Scenery shapes rebuildable from simple primitives (cone/box/cylinder/sphere/torus) | – |
| 8 | Composition: far wall ≈ upper third, 16:9, court not cropped | – |
| 9 | Distinct at a glance from the existing nine palettes (no steampunk-orange repeat) | – |

Stop target: all 5 stills pass G1–G3; at most one non-gating miss each.

## The five arenas

### 1. `torii` — Portale Torii (Kyoto, dusk)
- Sky stops: `#0b1026` top → `#3a2350` mid → `#e8734f` horizon glow; apron `#2b2a33` stone.
- Glow accent `#ffb24d` (warm lantern gold).
- Scenery: vermilion torii colonnade (two pillars + double crossbeam, repeating), five-story
  pagoda silhouette, round paper lanterns on the colonnade, drifting pink petals, crescent moon.
- New Godot kinds: `torii` (pillars+beams), `pagoda` (stacked tapering roofs), `lantern` ≈ existing `lamp` warm, `petal` ≈ small `spark` pink.

### 2. `medina` — Cortile Medina (Marrakech, golden hour)
- Sky stops: `#f7c884` top → `#e08a52` mid → `#8f3f30` horizon; apron `#c78a5a` clay.
- Glow accent `#3fd0c9` (zellige turquoise).
- Scenery: ochre clay walls with a horseshoe-arch gate, tall date palms, hanging brass
  lanterns, tiled zellige band (turquoise/white diamonds), slim minaret tower.
- New Godot kinds: `arch` (torus segment on box jambs), `palm` (trunk + fan of cones), `zellige` (striped tile band quad).

### 3. `carioca` — Terrazza Carioca (Rio de Janeiro, noon)
- Sky stops: `#2fb6d9` top → `#9fdcf0` mid → `#eaf7ff` horizon; apron `#e8d5a8` beach sand.
- Glow accent `#ffd84d` (afternoon sun).
- Scenery: granite Sugarloaf + twin-peaks ridges in blue-green haze, rows of palms, white
  wave-foam crescents, thin cable-car line between peaks.
- New Godot kinds: `ridge` (low-poly triangular prism chain), `foam` (flat white crescent), `cable` (thin line quad).

### 4. `aurora` — Banco Aurora (Iceland, night)
- Sky stops: `#04060f` top → `#0a1b33` mid → `#123a3c` horizon; apron `#0d0f12` volcanic black.
- Glow accent `#4dffc3` (aurora green).
- Scenery: basaltic column cliff (hexagonal prisms, varying heights), snow-capped ridge,
  two geyser steam plumes, wavering aurora ribbons green→violet.
- New Godot kinds: `basalt` (hex prism cluster), `aurora` (emissive translucent ribbon), steam ≈ existing `cloud` grey.

### 5. `egeo` — Isola Egeo (Santorini, noon)
- Sky stops: `#1f5fd0` top → `#7fb3f0` mid → `#eef4ff` horizon; apron `#d9d2c4` pale stone.
- Glow accent `#2b5fd9` (cobalt).
- Scenery: whitewashed cubic houses cascading down a cliff, cobalt domes, a windmill,
  magenta bougainvillea patches, dark-blue caldera sea below.
- New Godot kinds: `island` (clustered cubes with blue dome caps), `windmill` (cylinder + cone + blades), `sea` (flat band quad).

## Recreate-in-Godot contract

Each arena maps to one `ArenaStyle.STYLES` entry: `family: "world"`, `sky` stops copied from
the still's gradient, `apron` from the ground-beyond-court tone, `glow` as accent, `props`
list with kinds above at metre positions in the scenery band (`arena_scenery.gd`, BACKDROP_Z
−8.0, upper band + side wedges). The still is the target; the existing court/net/cage
geometry is untouched.

## Framing mandate — gameplay-critical, carries into every plan

The camera that matters is the game's. Every gameplay frame must show the **whole court**:
both baselines, both side walls, and the rear glass the ball bounces off, with the ball
trackable through every bounce. Consequences for any recreation plan:

- A frame that crops the field, hides the rear glass, or puts scenery where it can occlude
  play is a REJECT, however good the backdrop looks. Ball-bounce visibility is a gameplay
  requirement before it is an aesthetic one.
- Scenery and backdrop live only where the reference allows them: the band above the rear
  glass plus the two wedges outside the cage. Never inside the cage, never in front of the
  glass, never over any part of the field.
- The stills below are direction setters for palette, scenery language and ground tone
  ONLY. Their camera poses lower than the game presets — illustrative, not the framing
  target. Do not copy the stills' framing into the build and do not regenerate the stills
  to chase framing; the game camera stays the authority.

Acceptance for any arena work: an in-engine capture per arena from the actual camera preset
showing the full court and the rear glass, plus a play check that rear-glass bounces stay
visible.
