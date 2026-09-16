# Athlete roster order

- Status: open
- Type: grilling
- Mode: HITL
- Owner: unassigned
- Blocked by: [Character pipeline economics](character-pipeline-economics.md)

## Question

Which athletes become 3D models, in what order, and under what spend cap. Quick
match needs at least two playable athletes and the four AI opponents; the roster
is exactly six: maestro, pantera, steamer, fiamma, oracolo, colosso.

**The Volpe question, reframed.** Volpe is **not in the game roster** and zero
mentions of it exist in `js/data.js`. The old line calling it "the special unlock"
has no source basis: specials in `js/game.js` are shot abilities
(`specialCooldown`/`specialReady`), not unlockable characters. Volpe exists only
as a newly generated Meshy trial under `meshy/rigged/volpe/`. The real decision
is whether that trial becomes a **7th athlete (new scope, contradicting "no new
athletes")** or is discarded once the pipeline is proven.

## Why it matters

The spend cap is a number only Luca can set, and the Volpe fate changes whether
the port stays at parity or grows the roster.

## Resolved when

An ordered list with a credit cap for the Meshy spend and a stated answer on
Volpe: 7th athlete or discarded test asset.
