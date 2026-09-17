# The Five Country Specials — racket ladder design sheet

Status: **concept round 1, 2026-09-17.** The second themed special line, alongside the
steampunk set (`../steampunk/DESIGN.md`). No code, no GLB, no balance numbers yet.

Deliverable this round: the **Meshy intake front views** are the artifacts —
`meshy/rackets/country/views/<id>-front.png` (no scene stills; the views carry the design).
Spend ledger: `image-spend.json` (this folder). Intake brief + GUI recipe:
`meshy/rackets/country/brief.md`.

## The arc — work to legend

One rule binds the five: **each rung moves up one world, one finish, one verb** — and the glow
climbs from nothing to something almost quiet again.

| rung | glow | finish | verb | comes from |
|---|---|---|---|---|
| 1 | none — frayed rope and patches | improvisation | hold (charge holds while you run) | the ranch |
| 2 | one soft pearl sheen | tailored, immaculate | snap (release at the final beat) | Sunday best |
| 3 | cherry iron when charged | forge-welded | sear (brand the court) | the forge |
| 4 | copper runs hot | hammered and soldered | pour (a wobbling spirit shot) | the still |
| 5 | pale, calm, sacred | one of one | stampede (an unreturnable rally) | the plains |

The line walks from what the ranch had lying around, through the cowboy's best clothes, the
blacksmith, and the still, to the plains' own legend. Nothing glows until the forge; everything
after does.

## The five

### 1 · La Capezza — "the Halter"
- **Origin:** built on the ranch from what the mule already wears and the fence already lost.
- **Material read:** a bent grey fence-wire hoop stretched with pale feed-sack canvas,
  awl-punched with a scatter of holes and sagging a little; worn ash-wood frame rails; thick
  three-strand halter rope binding the throat and grip; a plain leather noseband as the butt
  cap. Matte, frayed, work-worn.
- **Signature:** the halter never tugs — your charge holds its line and decays half as fast
  while you are moving.
- **Unlock idea:** the line's starter — early career, trophies.

### 2 · Il Bottone — "the Snap"
- **Origin:** a Sunday-best work shirt, retired to the court.
- **Material read:** doubled indigo denim face, fine woven texture; an arc of fourteen round
  mother-of-pearl snaps in small metal rings forms the perforation; the folded placket is the
  throat; a tightly wound starched sleeve is the grip. Immaculate, plain, exactly one sheen.
- **Signature:** the snaps pop at the last instant — release your charge in its final beat and
  the shot fires with no wind-up.
- **Unlock idea:** mid-career trophies.

### 3 · Il Marchio — "the Brand"
- **Origin:** the ranch's old branding iron, forge-welded into a racket.
- **Material read:** wrought-iron face pierced clean through in a ring of punch holes forming
  the ranch's own glyph; hammered black iron; the throat a rod bent into the same crooked
  glyph; scorched latigo grip with charred edges.
- **Signature:** charge it and the glyph glows cherry — the smash comes down searing and leaves
  a smoldering brand on the court that nobody crosses twice.
- **Unlock idea:** stars-tier. (The single most convergent idea of the run: three of the five
  generator frames proposed a branding iron unprompted.)

### 4 · L'Alambicco — "the Still"
- **Origin:** a hammered copper pot still, rolled out of the back room and turned sideways.
- **Material read:** the pot flattened into the face — hammer dimples, soldered seams, rows of
  mash-plate holes; the swan-neck bent down into the throat; dark leather grip wound with thin
  copper wire.
- **Signature:** long rallies run the copper hot — fire the special while it glows and the ball
  comes off the neck wobbling like poured spirit, straight through the return swing.
- **Unlock idea:** late career.

### 5 · Il Bisonte Bianco — "the White Bison"
- **Origin:** the plains' sacred legend, made racket. One was ever made; nobody agrees where
  it is.
- **Material read:** a bone-white head with the faint pale grain of old bone, perforated by a
  scatter of small hoofprint-shaped holes; the throat curves up like a bison horn, pale with a
  darkened tip; short pale-brown mane tufts shingle the upper frame edge; pale leather grip
  with a single dark band. Quiet, dignified, no ornament beyond that.
- **Signature:** once a match, when you are down match point, the herd charges — for one rally,
  every shot you strike is unreturnable.
- **Unlock idea:** the line's endgame — final season or full completion.
- **Register note:** keep the awe framing — a sacred symbol of the plains, never a trophy or
  hunt item. If that register ever feels too heavy for the game's tone, *La Vena Madre* below
  is the drop-in swap.

## Bench — alternates kept for future drops

La Vena Madre (T5: gold-laced quartz; every point won pans another fleck into the face — the
strongest alternate apex), La Batea (T2 gold pan: charged shots sieve into drifting gold dust),
Il Banjo (T3: rallies strum chords; a full chord charges the special), La Botte (T3 barrel:
rallies age — a long one pours cask-strength, a miss drinks your meter), Il Guanto (T4
bull-rider's glove: charges hold through any hit; the nod opens the gate), L'Ultimo Giro (T5:
one silver buckle; wakes at match point), plus the T1 cluster (La Tela, Il Fieno, La Balla di
Fieno, La Trapunta, La Pannocchia), Lo Scacciapensieri, Il Tamburello, Lo Spaventapasseri,
Il Rotolone, La Ruota Panoramica, Il Sonaglio, Il Tornado, La Fisarmonica, Lo Sprone,
Il Fustagno, La Pece.

## Traps — flagged, do not build as-is

| idea | why it is a trap |
|---|---|
| La Trapunta (quilt) | "every point you lose sews a patch" rewards losing; anti-sporting read |
| Lo Spaventapasseri (scarecrow) | meter only fills standing still — inverts the movement game; reads broken |
| Il Rotolone (tumbleweed) | random line-switch "you included" — no player control, only salt |
| Il Sonaglio / Il Tornado | hooks ride on ball-physics chaos and audio tells the current sim does not carry; spectacle without a lever |
| Il Guanto (glove) | "charges hold through any hit" is straight power creep with no cost; needs a price before it could ship |

## Integration notes

- Same as the steampunk line: the rackets are props. In-engine the racket mounts to
  `mixamorig:RightHand` with the offsets in `AthletesView.RACKET_HAND_LOCAL` /
  `RACKET_HAND_ROTATION`; swapping in a GLB reuses the same anchor.
- All five signatures ride existing primitives (charge, slice, special); tier 5 stacks on the
  special. Tune in the balance pass — the hooks are written as feels, not formulas.

## Appendix — provenance

ADHD run 2026-09-17, second line: 5 isolated generator frames × 6 candidates = 30 raw ideas
(frames: western film prop master, rodeo circuit veteran, gold-rush prospector, Nashville
session musician, county-fair kid). Convergence signals: the branding iron (3 of 5 frames), the
mother lode as apex material (2 of 5 frames), the canvas/hay/quilt T1 cluster. Picks and tier
placements match each source frame's own guess. Full 30-candidate pool in the session record;
bench items above are the keepers. Intake views: `meshy/rackets/country/views/`; checklist and
hashes in `meshy/rackets/country/brief.md`.
