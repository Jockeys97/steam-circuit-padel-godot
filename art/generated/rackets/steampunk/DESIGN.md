# The Five Specials — racket ladder design sheet

Status: **concept round 1, 2026-09-17.** No code, no GLB, no balance numbers yet — this is
the design + art-direction layer. Economics figures are proposals for the balance pass.

Art: `art/generated/rackets/steampunk/<id>/` (raw, unmodified) · spend ledger: `image-spend.json` ·
prompt DNA: `PROMPT-DNA.md`. Meshy intake views: `meshy/rackets/steampunk/views/<id>-front.png` (brief and
GUI recipe: `meshy/rackets/steampunk/brief.md`). Provenance §Appendix.

## The arc — why the set reads as increasingly higher-tier

One rule binds the five: **each rung brings one new material family, one new level of glow,
one new mechanic verb — and each comes from a different arena.** Sensory arc:
steam (air) → clockwork (time) → bell (sound) → the dark side of light → light reborn as stars.

| rung | glow | ornament | verb | comes from |
|---|---|---|---|---|
| 1 | none — a wisp of steam | visible repairs | vent (feint) | Caldera Titano |
| 2 | one cold glint | clean bevels | tick (bank discipline) | Clockwork Factory |
| 3 | warm shimmer | engraved arcs | toll (bank tone) | Officina Vapore |
| 4 | razor-thin corona | restrained gold | vanish (stealth) | Santuario Abissale |
| 5 | radiating starlight | full celestial | ascend (apotheosis) | Orrery Celeste |

## The five

### 1 · Lo Sfiato — "the Vent"
- **Origin:** torn off the overflow pipework of Caldera Titano. A grand place's cast-off.
- **Material read:** hammered scrap steel over a beech core, matte, rust-browned edges,
  soft mismatched rivets; a chunky hissing brass valve bolted where the sweet spot sits;
  taped vulcanized-rubber grip, dull and dirty.
- **Signature:** vent the valve mid-charge — a burst of steam masks your shot direction
  for half a beat.
- **Unlock idea:** the first special; early career, trophies.

### 2 · Lo Scatto — "the Tick"
- **Origin:** built on the winding benches of the Clockwork Factory.
- **Material read:** polished dark steel, neat brass fasteners, an exposed ratchet-gear
  stack in the throat driving a small cold-cyan escapement; immaculate but understated.
- **Signature:** three clean hits ratchet the stack — a free micro-charge.
- **Unlock idea:** mid-career trophies.
- **Naming note:** shares the word *scatto* with La Pantera's move *Scatto Fulmineo*
  (different sense: the tick of the escapement). One-string rename if it ever bothers.

### 3 · Il Campanone — "the Big Bell"
- **Origin:** cast from re-melted foundry bells in the Officina Vapore's own furnace.
- **Material read:** bell-bronze (78 copper / 22 tin) in one flowing cast, hand-scraped,
  fine engraved concentric arcs, a bell-mouth swell at the throat, leather-and-wire grip.
- **Signature:** dead-center hits ring a true note and bank a harmonic; the special spends
  the whole stacked ring as one tolling shockwave.
- **Unlock idea:** stars-tier. (*Campanone* is the great-bell word — Florence's cathedral
  has one.)

### 4 · Il Novilunio — "the New Moon"
- **Origin:** quenched in the lightless pits of the Santuario Abissale.
- **Material read:** the face is a disc of blackened mirror-glass that swallows light,
  ringed by a razor-thin cold-cyan corona; dark alloy frame, restrained old gold; a
  black-moon motif engraved at the throat.
- **Signature:** while charged, the ball's neon trail runs dark — opponents learn where
  the shot went when it lands.
- **Unlock idea:** late career / winning the Santuario Abissale.
- **Naming note:** renamed from *L'Eclissi* — L'Oracolo already owns *Eclissi Quantica*
  as an outfit signature; one rare word twice muddies both.

### 5 · L'Orsa Maggiore — "Ursa Major"
- **Origin:** assembled from the Orrery Celeste's master instrument — a portable piece
  of the observatory.
- **Material read:** ornate burnished brass-and-gold frame; seven pin-bright star
  ornaments orbiting the head on hair-thin clockwork arms; the face glows faintly like
  a night sky; an armillary-ring accent at the grip.
- **Signature:** every hit lights one star; seven stars in a single rally call down a
  Star Fall smash that crashes through any special and burns a constellation into the court.
- **Unlock idea:** endgame — final season, or full-trophy completion.

## Bench — alternates worth keeping for future drops

La Lanterna (T3: meter fills 2× fast but is public — a real trade-off), Il Volano
(T2 flywheel: rally length feeds smash power), L'Astrolabio (T3: perfect slice drags a
false orbit-arc), Lo Specchio (T4: spin inverts on contact), La Pallasite (T5: olivine
windows reveal the ball's spin axis), Il Sigillo (T5: full-meter charge cannot be
sliced, stalled or deflected — "it simply arrives"), Il Silenzio (T5: no sound at all;
once per match the arena mutes for everyone but you), L'Ultimo Fischio (T5: on your
first match point, the whistle takes over).

## Traps — flagged, do not build as-is

| idea | why it is a trap |
|---|---|
| La Cometa (flying yo-yo head) | breaks the hand-bone mount model; head-decoupling is new rig/physics scope, and "never move your feet" deletes the movement skill |
| La Lamiera (self-deforming sweet spot) | punishes play; reads as a bug, not as character |
| L'Invar (heat-proof meter) | value exists only inside one arena; dead everywhere else |
| Il Registro (opponent-modeling dials) | deep opponent-profiling systems cost; reads as cheating |
| La Caffettiera (moka-pot racket) | genuinely delightful, but comedy shifts the cinematic tone — better as a celebration/seasonal skin |

## Integration notes (for the gameplay lane)

- Today the match racket is a procedural mesh (`Court.make_racket_view`, mounted at
  `mixamorig:RightHand` via `AthletesView.RACKET_HAND_LOCAL/ROTATION`); nothing here
  requires the racket to leave that anchor.
- Each signature maps onto existing primitives: charge shot, slice, and the special
  (Alt/Meta). No new input verbs are needed for tiers 1–4; tier 5 stacks on the special.
- A future item pass needs: racket selection UI + per-racket material/mesh, and one sim
  hook per signature. Hooks are written as *feels*, not formulas — tune in the balance pass.

## Appendix — provenance

ADHD run 2026-09-17: 5 isolated generator frames × 6 candidates = 30 raw ideas
(frames: game-design, 10-year-old, master-smith, inversion, maximalist), scored on
novelty/viability/fit, clustered by angle, picks converge on the ladder above.
Top-scoring raw picks: L'Orsa Maggiore [N10 V8 F9] · Il Silenzio [N10 V7 F8] ·
L'Eclissi→Novilunio [N9 V8 F9] · Il Campanone [N8 V8 F9] · Lo Sfiato [N7 V9 F9].
Full 30-candidate pool lives in the session record; bench items above are the keepers.
