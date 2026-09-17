# The arena's furniture: sideline shelters and sponsor boards

Date: 2026-09-17. Tree: `codex/reconcile-20260917`, worktree `/private/tmp/padel-reconcile`.
Module: `godot/game/arenas/arena_props.gd`. Probe: `godot/game/tools/arena_props_probe.gd`.

## What was added

Two Meshy units the owner supplied, placed from the court's own geometry rather than
from numbers typed into the module:

| prop | file | copies | scale | unit as authored |
|---|---|---|---|---|
| Players' sideline shelter | `assets/arena/sideline-shelter.glb` | 4 (2 per side) | 2.4 | 1.90 × 1.00 × 0.79 m, 259,882 tri |
| Sponsor board | `assets/arena/sponsor-board.glb` | 3 (rear line) | 2.0 | 1.90 × 0.41 × 0.15 m, 37,792 tri |

## Where they ended up, measured

`godot --headless --path godot/ --script res://game/tools/arena_props_probe.gd`

```
CAGE glass_x=5.500 glass_z=10.000 glass_h=3.000 court_w=11.00
UNIT ShelterR1     x=[  6.700,  8.595] y=[0.000, 2.402] z=[  3.453,  8.013]
UNIT ShelterR2     x=[  6.700,  8.595] y=[0.000, 2.402] z=[ -8.013, -3.453]
UNIT ShelterL1     x=[ -8.595, -6.700] y=[0.000, 2.402] z=[  3.453,  8.013]
UNIT ShelterL2     x=[ -8.595, -6.700] y=[0.000, 2.402] z=[ -8.013, -3.453]
UNIT SponsorBoard1 x=[ -5.697, -1.899] y=[0.000, 0.811] z=[-10.907,-10.600]
UNIT SponsorBoard2 x=[ -1.899,  1.899] y=[0.000, 0.811] z=[-10.907,-10.600]
UNIT SponsorBoard3 x=[  1.899,  5.696] y=[0.000, 0.811] z=[-10.907,-10.600]
CAGE_WORST unit=SponsorBoard1 clearance=0.600 OK
OVERLAPS count=0 OK
GROUND worst min_y=0.0000 OK
SHELTER_HEIGHT tallest=ShelterR1 h=2.402 glass_h=3.000 OK
```

Four claims, each a signed number rather than an impression:

- **Nothing crosses the cage.** The shelters stand 1.20 m clear of the side glass —
  the same `Bleachers.CORRIDOR_M` the stands use, so the two read as one row of
  furniture. The boards stand 0.60 m clear of the rear glass.
- **Nothing interpenetrates.** Zero overlapping pairs across all nine units
  (stands included), tested as AABB intersection with a 1 mm tolerance.
- **Everything stands on the floor.** Worst `min_y` is 0.0000.
- **The shelters stay under the glass.** 2.40 m against the cage's 3.00 m, so the
  cage remains the tallest thing on the side line.

The boards span 11.39 m against the court's 11.00 m: the run reads as continuous
signage with no gap at the corners.

## A screenshot review said the opposite, and was wrong

A vision pass over `game/out/arena-props.png` reported canopies clipping the cage,
props interpenetrating, and units floating. The probe contradicts all three. At ~30 m
and ~36 px/m a 5 cm gap and a 5 cm overlap are the same handful of pixels, and
translucent glass in front of a prop reads as an intersection. **A placement claim is
worth making only when a number backs it** — that is why this probe exists and why it
prints clearances rather than a verdict alone.

What the review got right and the probe cannot see: no contact shadows under the side
props (`cast_shadow` is false for the same reason it is false on the stands — they sit
~30 m out on dark ground), and the canopies sharing the court's blue. Both are taste
calls for the owner, not correctness bugs.

## Texture weight

All three Meshy units were shrunk in place with
`godot/game/tools/shrink_glb_textures.py` (2048 px cap, JPEG q92, 4:4:4 subsampling,
mesh and UVs copied byte for byte):

| asset | before | after | triangles |
|---|---|---|---|
| stands | 31.1 MB | 16.3 MB | 459,928 intact |
| shelter | 14.0 MB | 10.1 MB | 259,882 intact |
| board | 7.2 MB | 3.6 MB | 37,792 intact |

Three loose `texture_*.jpg` files beside the stands' GLB were deleted: the same three
images are already embedded in the binary chunk, nothing references the loose copies,
and they cost 17.5 MB of permanent history.

### The sharpness question, settled by measurement

A first pass at 1024 px / q85 was visibly softer. Measured as mean absolute luma
gradient over the stands' own pixel box:

| | left stand | right stand |
|---|---|---|
| original 31 MB | 9.86 | 8.29 |
| shipped 16 MB | 9.85 | 8.29 |

−0.1% and −0.0%: the shipped asset is the original's equal at this framing. The cap
is 2048 rather than 1024 precisely so a closer camera has headroom later.

`generate_lods` is off for the stands' import: Godot was swapping in a decimated mesh
at this distance. A project-wide anisotropy and mipmap-bias change was tried and
reverted — it moved nothing measurable, and a rendering default that buys nothing is
worse than no change at all.

## The suites, after the furniture landed

Re-run on the tree with the props built into every arena:

| suite | result |
|---|---|
| game slice, full | `PASS 340/340` |
| game slice, demo (`-- --demo`) | `PASS 291/291` |
| court dimensions | `PASS 1111 checks, 0 failures` |
| audits | `10/10`, 221 checks, harness `20/20` |
| music port | `PASS 31/31` |

Zero `SCRIPT ERROR` across all five.

## Not measured here

Frame cost of the new props (the stands' own A/B window measured ~20 fps for
919,856 triangles in two copies; the furniture adds 1,152,904 across seven copies and
deserves its own window), the exported pack, and how any of it feels. The look is the
owner's call.
