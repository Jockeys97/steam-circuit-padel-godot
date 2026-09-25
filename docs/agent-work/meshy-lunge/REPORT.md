# Forehand lunge (Meshy), 2026-09-24

## Cost
Owner approved up to 18 credits. Spent 18: rig 5 + Prime motion 10 + retarget 3.
Balance 300 -> 282. One free rejection (prompt over 400 characters).
The 2026-09-20 Fiamma rig belongs to another Meshy account ("Rigging task not
found" with this key), so Fiamma was re-rigged here from
`meshy-fiamma-trial/fiamma-trial-rig.glb` at its measured 1.74 m. The new rig has
the same 24 joints and names as the old one. Task ids: `tasks.json`. The generator
is `tools/meshy/lunge-strokes.cjs`, which reads MESHY_API_KEY from the environment,
enforces a hard ceiling and never retries a POST.

## Bake
`tests/bake_meshy_fiamma.gd -- lunge_forehand auto <athlete> <outfit>`: length 0.80 s,
contact phase 0.30, source contact 1.1 s. It is the first stroke to import the hips'
POSITION: the full vertical drop (about 26 cm in the source) plus 60% of the sideways
step towards the ball, with no forward travel. The last 0.15 s blends back to rest.
It is baked for all 13 athlete/outfit ids and was inspected on Fiamma, Colosso,
Maestro and Pantera: feet on the floor, deep lunge, recovery to standing.

## Runtime
`athletes_view.gd::_sync_stroke`: a `meshy_drive` whose ball lies >= 0.5 of the
stretch band (about 1.0 m to the side) and below head height plays
`meshy_lunge_forehand`, with no extra crouch or slide and an 0.08 s blend
(`play_stroke_at(..., blend)`) so the pelvis travels instead of snapping. The
backhand side has no lunge yet.
