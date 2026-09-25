# Richiesta immagini 2D — sette arene (2026-09-25)

Per: Alessio, da generare in ChatGPT. Dopo, Claude porta le immagini in gioco:
copertine nel menu, oggetti in 3D con Meshy (image-to-3D) montati nei "posti" del
kit arene (`docs/mission/arena-kit/KIT-STANDARD.md`).

## Come consegnarle

1. Crea sulla Scrivania la cartella **`asset-arene`**.
2. Salva ogni immagine con **esattamente** il nome indicato (es. `tempesta_cover.png`,
   `tempesta_hero_landmark.png`).
3. Copertine: **16:9, orizzontali**. Oggetti: **quadrati 1:1, sfondo bianco**.
4. Se un'immagine esce con testo, scritte, loghi, ombre a terra o più oggetti: rigenerala,
   Meshy la rovina.

## Budget Meshy (da decidere)

Saldo attuale: **269 crediti**. Un oggetto costa **~15 crediti** (smart topology, texture).
Qui sotto ogni arena ha **5 oggetti** in ordine di priorità (★ = i primi tre).
- Solo i ★ (3 per arena × 6 arene = 18 oggetti) ≈ **270 crediti**: tutto il saldo.
- Tutti e 5 (30 oggetti) ≈ **450 crediti**: servono crediti in più.
Le copertine non costano crediti Meshy.

---

## A. Copertine (una per arena)

Blocco di stile comune: incollalo **in fondo** a ogni prompt di copertina.

```
Epic painterly steampunk-fantasy illustration, cinematic, highly detailed, rich dramatic
lighting with warm brass highlights and glowing lamps, deep saturated colours. A single blue
padel court with glass walls and a black mesh fence at the exact centre of the picture, seen
from behind one baseline from a slightly elevated position, perfectly symmetrical
composition, the court's far end leading the eye to the main landmark on the horizon.
Ornate brass-and-iron steampunk structures frame the court on both sides. Landscape 16:9,
no text, no letters, no logo, no people, no players, no watermark, no border, no UI.
```

| File | Arena | Scena (prompt, prima del blocco di stile) |
|---|---|---|
| `locomotive_cover.png` | Sopraelevata della Luna | `A padel court at night encircled by an elevated four-lane skyway with glowing street lamps and cars with headlights and red taillights, a dense city skyline of towers with warm lit windows behind it, dark mountains, and a huge full moon low in a starry indigo sky.` |
| `cattedrale_cover.png` | Cattedrale di Vapore | `A padel court inside a colossal gothic steampunk cathedral nave: tall pointed arches, giant rose window of amber and violet stained glass, brass organ pipes venting soft steam, hanging chandeliers of iron and candles, gilded clockwork reliefs on the columns.` |
| `forgia_cover.png` | Forgia Abyssal | `A padel court on an iron platform deep in an underwater volcanic forge: black basalt, rivers of glowing orange magma behind thick riveted portholes, huge brass anvils and hammers driven by pistons, bubbles and dark teal water pressing on a riveted glass dome.` |
| `tempesta_cover.png` | Bastione della Tempesta | `A padel court on the deck of a fortified flying airship bastion inside a violent thunderstorm: blue lightning, swirling storm clouds, brass propellers and lightning-rod towers, iron chains and lanterns along the deck rails.` |
| `abissale_cover.png` | Santuario Abissale | `A padel court inside a great glass-and-brass dome on the ocean floor: a whale swimming past, sunken temple ruins and glowing jellyfish, kelp, teal light rays from the surface, brass porthole ribs and pipes around the dome.` |
| `caldera_cover.png` | Caldera del Titano | `A padel court on a dark iron arena suspended over a volcanic caldera: two colossal steampunk titan statues with glowing furnace eyes flank the court, lava falls, forge chimneys spitting sparks, chains and gears in the red smoke.` |
| `orrery_cover.png` | Orrery Celeste | `A padel court on a brass observatory platform floating in space: a gigantic golden orrery with orbiting planets on arms, telescopes, astrolabe rings, a purple and blue nebula full of stars behind a domed glass frame.` |

---

## B. Oggetti per Meshy (quadrati, sfondo bianco)

Modello di prompt: sostituisci **{OGGETTO}** con la riga della tabella e **{STILE ARENA}**
con il blocco dell'arena. Il resto va incollato identico ogni volta: le variazioni di
formulazione diventano variazioni di stile.

```
A single isolated {OGGETTO}, read as one connected solid form. Stylized low-poly 3D game
asset, clean geometric shapes with smooth shading, gently rounded edges, flat matte
materials, subtle ambient occlusion only, no texture noise, no surface grunge, no outlines,
no cel shading, no photorealism.

{STILE ARENA}
All surfaces matte — no gloss, no chrome, no glass, no wet reflection, no metallic
highlight.

Three-quarter view rotated about 20 degrees off-axis, orthographic-looking with minimal
perspective distortion, long lens, the whole object visible with a clear margin on every
side and nothing crossing the frame edge, centred and filling 70 to 90 percent of the
square frame.

Lighting: even, diffused, shadowless studio lighting from the front, uniform ambient fill,
no cast shadow on the ground.

Background: pure white seamless background, #FFFFFF, no gradient, no floor plane, no
shadow under the object.

Square 1:1 image, sharp focus edge to edge, clean readable silhouette.

No text, no letters, no numbers, no signage, no logo, no watermark, no border, no people,
no animals, no second object, no ground, no scenery.
```

### Sopraelevata della Luna (`locomotive`)

Nessun oggetto Meshy necessario: la mappa è già costruita. Manca solo la copertina, più
il **SUV bianco** (scaricalo da Meshy come l'utilitaria: Download → GLB).

### Cattedrale di Vapore (`cattedrale`)

STILE ARENA: `Palette: deep violet #3a2350, stained-glass amber #f2a83b, antique brass #b98a3e, dark iron #2a2630. Materials: matte painted stone, matte painted brass, opaque coloured glass panels.`

| | File | OGGETTO |
|---|---|---|
| ★ | `cattedrale_hero_landmark.png` | `gothic steampunk cathedral facade with a large round rose window, two pointed bell towers topped by brass spires, small clock faces and pipes` |
| ★ | `cattedrale_column_pillar.png` | `tall gothic stone column with a brass capital, riveted iron bands and a thin steam pipe spiralling up its shaft` |
| ★ | `cattedrale_light_source.png` | `standing iron candelabrum lamp with a brass cage and one large warm glowing bulb on top` |
| | `cattedrale_ornament_accent.png` | `small church organ console with a fan of brass pipes of different heights` |
| | `cattedrale_furniture.png` | `wooden church pew bench with carved gothic ends and brass rivets` |

### Forgia Abyssal (`forgia`)

STILE ARENA: `Palette: black basalt #1b1a1f, magma orange #ff6a1f, deep sea teal #0f4a55, oxidised brass #8c6a3a. Materials: matte basalt stone, matte painted iron and brass, opaque glowing magma.`

| | File | OGGETTO |
|---|---|---|
| ★ | `forgia_hero_landmark.png` | `giant steampunk forge furnace shaped like a squat tower, riveted iron body, a round open mouth glowing with magma, two tall chimneys and thick pipes` |
| ★ | `forgia_ornament_accent.png` | `huge blacksmith anvil on a basalt block with a giant mechanical hammer on a piston arm above it` |
| ★ | `forgia_light_source.png` | `iron brazier bowl on three riveted legs filled with glowing magma rocks` |
| | `forgia_column_pillar.png` | `thick hexagonal basalt pillar wrapped by an iron pipe with a pressure gauge` |
| | `forgia_ground_dressing.png` | `cluster of three dark basalt boulders with glowing orange cracks` |

### Bastione della Tempesta (`tempesta`)

STILE ARENA: `Palette: storm navy #10214a, lightning blue #5ec8ff, polished brass #c29a4a, dark iron #262a33. Materials: matte painted iron and brass, matte painted wood planks, opaque canvas.`

| | File | OGGETTO |
|---|---|---|
| ★ | `tempesta_hero_landmark.png` | `steampunk airship with a large cigar-shaped canvas balloon, brass gondola, two side propellers and a tail fin` |
| ★ | `tempesta_column_pillar.png` | `iron lightning-rod tower with a copper coil on top and a small crackling blue sphere` |
| ★ | `tempesta_light_source.png` | `brass ship lantern on a short iron post with a warm glowing core` |
| | `tempesta_ornament_accent.png` | `large brass ship propeller with four blades mounted on a riveted hub` |
| | `tempesta_railing_segment.png` | `short section of iron deck railing with chains between two posts` |

### Santuario Abissale (`abissale`)

STILE ARENA: `Palette: abyss blue #062334, bioluminescent teal #3fe0d0, aged brass #9c7a3c, coral pink #e0707a. Materials: matte painted brass and stone, opaque glowing shells, matte coral.`

| | File | OGGETTO |
|---|---|---|
| ★ | `abissale_hero_landmark.png` | `sunken temple tower with a domed roof, broken columns, brass porthole windows and coral growing on it` |
| ★ | `abissale_ornament_accent.png` | `stylized whale sculpture made of brass plates and rivets, as a monument` |
| ★ | `abissale_light_source.png` | `glowing jellyfish lamp: a translucent-looking dome lamp with trailing tendrils, on a brass stand` |
| | `abissale_vegetation_cluster.png` | `cluster of tall kelp and branching coral on a small rock` |
| | `abissale_column_pillar.png` | `brass pressure pipe column with a big round valve wheel and portholes` |

### Caldera del Titano (`caldera`)

STILE ARENA: `Palette: soot black #16100f, lava red #d8331c, furnace orange #ff8a2a, dark bronze #6d4a2a. Materials: matte painted iron and bronze, matte volcanic rock, opaque glowing lava.`

| | File | OGGETTO |
|---|---|---|
| ★ | `caldera_hero_landmark.png` | `colossal steampunk titan statue kneeling, bronze armour plates, glowing furnace eyes and a chest furnace grille` |
| ★ | `caldera_column_pillar.png` | `forge chimney stack of riveted iron with a glowing ember top` |
| ★ | `caldera_light_source.png` | `hanging iron cage lantern on a chain with a glowing lava core` |
| | `caldera_ornament_accent.png` | `giant bronze gear wheel half buried in volcanic rock` |
| | `caldera_ground_dressing.png` | `cluster of dark volcanic rocks with glowing lava cracks` |

### Orrery Celeste (`orrery`)

STILE ARENA: `Palette: space indigo #120f3a, nebula violet #7a4fd6, gold brass #d4a64c, star white #f4efe0. Materials: matte painted brass and gold, opaque painted planet spheres.`

| | File | OGGETTO |
|---|---|---|
| ★ | `orrery_hero_landmark.png` | `giant golden orrery: a central sun sphere with several planets on curved brass arms and rings` |
| ★ | `orrery_ornament_accent.png` | `large brass telescope on a tripod pointing up` |
| ★ | `orrery_light_source.png` | `brass armillary sphere lamp with a glowing star in its centre on a short pedestal` |
| | `orrery_column_pillar.png` | `slender brass column topped by a small ringed planet` |
| | `orrery_railing_segment.png` | `short brass railing section decorated with small stars and crescent moons` |

---

## C. Cosa faccio io dopo

- Copertine → `godot/assets/ui/arenas/*.webp`, collegate nel menu.
- Oggetti → Meshy (image-to-3D, smart topology, ~8–12k triangoli), poi
  `godot/assets/arenas/<arena>/<slot>.glb`, montati nei posti del kit.
- Cielo, luci, strutture grandi (navate, ponte della nave, cupola, piattaforma) le
  costruisco nel codice come per la Sopraelevata, e ti mando fotogrammi a ogni passo.
