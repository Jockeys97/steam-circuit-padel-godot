# Interstitial budget — where a match spends its time

Measured on a real match (`game/tools/interstitial_probe.gd`,
`interstitial_beat_probe.gd`; headless, quick match, tier 3, scripted human vs
sim AI, 4 rigs). Not a proposal: the numbers below are what the build does today.

```
INTERSTITIAL ticks=7921 rig_ticks=31684 points=7 strokes=44
INTERSTITIAL PHASES  pause=14.9%  serve=5.9%  rally=79.2%
INTERSTITIAL PAUSE_RUNS n=7 median=1.41s max=1.41s
INTERSTITIAL ready_during_pause=7.4% of rig ticks
```

Per-clip share of the athletes' time:

| clip | share | | clip | share |
|------|-------|-|------|-------|
| `ready` | 20.84% | | `brake` | 3.39% |
| `prepare` | 19.41% | | `split_step` | 2.30% |
| `shuffle_left` | 18.54% | | `serve` | 1.19% |
| `shuffle_right` | 18.33% | | `meshy_drive` | 0.97% |
| `backpedal` | 6.28% | | `meshy_backhand` | 0.62% |
| `run` | 6.22% | | `walk` | 0.48% |

The strokes are ~2% of the athletes' time. The **interstitial** phases — the 1.4 s
after every point and the serve walk-up — are 20.8% of the match.

## What those two phases actually look like

**After a point.** The paddles teleport (the view zeroes its visual velocity on
`teleported`), and then, for the whole 1.41 s, every rig is frozen:

```
BEAT PAUSE t=0.01  player=shuffle_right(0.000m) ... opponent=brake(0.000m)
BEAT PAUSE t=0.02  player=prepare(0.000m)  playerMate=prepare(0.000m)
                   opponent=ready(0.000m)  opponentMate=ready(0.000m)
BEAT PAUSE t=0.70  player=prepare(0.000m)  playerMate=prepare(0.000m)
                   opponent=ready(0.000m)  opponentMate=ready(0.000m)
```

0.000 m of movement per tick for 1.4 s, in two static poses: the pair that lost
the point holds `prepare` (the crouched charge stance), the pair that won holds
`ready`. Nobody reacts to winning or losing, and nobody walks back to position —
the snap is instant.

**During the serve.** 467 samples of the serve phase: the server plays `ready`
for 465 of them (2 `backpedal`). The serve motion itself is 1.19% of the match.
There is no ritual: no stance, no ball prep, nothing before the swing.

## What is not in the budget yet

`recover_left` / `recover_right` are authored (0.34 s, `LOOP_NONE`) and the view
arms them for 0.34 s when a stroke ends (`_recovery_remaining`), but their share
of rig time is under the 0.4% reporting floor: the point freeze usually arrives
first. Worth a look before adding anything new in that slot.
