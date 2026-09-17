# What the arena's scenery costs, measured

Date: 2026-09-17. Tree: `codex/reconcile-20260917`, worktree `/private/tmp/padel-reconcile`.
Machine: Apple M4, macOS 26.2, GL Compatibility (`OpenGL API 4.1 Metal`).
Probe: `godot/game/tools/bleachers_probe.gd`, 1280x720, vsync off, 60 warmup frames,
four 2-second windows per configuration, median taken across windows.

## The layers, one at a time

Each row adds to the row above it. The delta is what that layer alone costs.

| layer | fps | delta | what it draws |
|---|---|---|---|
| bare court | 64.9 | — | court, cage, players, HUD |
| + stands | 51.6 | **−13.3** | 919,856 tri (2 copies) |
| + furniture | 35.8 | **−15.9** | 1,152,904 tri (4 shelters, 3 boards) |
| + crowd | 34.0 | **−1.8** | 120 tri (60 billboard quads) |

Two things in this table are worth saying out loud.

**The furniture costs more than the stands.** Seven copies at 1.15 M triangles beat
two copies at 0.92 M, and the shelters are the bulk of it (259,882 tri each, four of
them). If a frame budget is ever needed, `arena_props.gd::shelters_per_side` is the
first dial to turn — it is a `static var` precisely so it can be turned without a
rebuild.

**The crowd is effectively free.** 60 spectators cost 1.8 fps, and roughly none of
that is the 120 triangles — it is the per-frame bob loop over 60 nodes. This is what
the sprite-billboard choice bought: a modelled crowd at even 2,000 tri per person
would have been 120,000 triangles and a third pass of draw calls.

## Shadows: what got switched on, and what did not

The scene has had a shadow-casting sun since `court_builder.gd:199`, but every prop
opted out of the shadow pass. That is why a prop whose measured `min_y` is exactly
0.0000 still read as hovering: geometry says it stands on the floor, and with no
contact shadow the eye does not believe it.

| configuration | fps | delta from 34.0 |
|---|---|---|
| no prop shadows (before) | 34.0 | — |
| stands cast | 32.6 | **−1.4** |
| stands + furniture cast | 29.2 | **−4.8** |

**Shipped: the stands cast, the furniture does not.** The stands' shadow is what
grounds the whole side line, and it costs 1.4. The furniture's own shadow costs
another 3.4 and grounds much less, because a shelter tucked against the stands
already falls inside the stands' shadow. Buying 3.4 fps of shadow that lands on
shadow is not a trade worth making.

Both remain switchable — `--shadow=` and `--prop-shadow=` on the probe — so the
decision can be re-measured rather than re-argued.

## Where the scene stands now

**32.3 fps** at 1280x720 with everything on: stands, furniture, crowd, stand shadows.

That number is honest but it is not a verdict on the shipped game. This probe runs an
uncapped, vsync-off window with the simulation driven at full tilt, which is the right
setup for comparing two configurations and the wrong one for predicting play. What it
proves is the SHAPE of the cost: geometry dominates, the crowd is noise, and the
shadow decision is worth 1.4 rather than 4.8.

## Suites after the change

slice full `340/340` · slice demo `291/291` · court `1111 checks` · audits `10/10` ·
music `31/31` · save `137/137` · crowd probe `6/6`. Zero `SCRIPT ERROR`.

## Not measured here

Frame cost on the Linux target, the exported pack, and anything about how it looks or
feels — the shadows were switched on because a measurement said 1.4 fps, not because
anyone has confirmed they read better. That verdict is the owner's.
