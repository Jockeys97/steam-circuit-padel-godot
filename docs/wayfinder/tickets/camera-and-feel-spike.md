# Camera and feel spike

- Status: open
- Type: prototype
- Mode: HITL
- Owner: unassigned
- Blocked by: [Godot headless harness](godot-headless-harness.md)

## Question

The first thing worth looking at: a Godot scene with the court, net, glass, a
ball carrying real x/y/z motion from `BALANCE`, a diagonal serve from below, and
one rigged athlete. The camera must reproduce today's composition on first load,
then be tunable in the editor. Luca plays it and says whether the framing and the
feel hold in 3D.

Two constraints the spike must respect:

- **No idle clip exists.** The Meshy rig (`volpe-rigged.glb`) is a single base
  pose (one key at t=0.30 s, duration 0.0). Walking and running are separate
  companion GLBs. The spike either stands the athlete in the base pose or
  authors a minimal idle in Godot; it must not claim an idle clip that does not
  exist.
- **Court dimensions are unverified.** The "20x10" figure has not been checked
  against `COURT` in `js/data.js`. Read the constant before drawing the court.

This is the cheapest artifact that can produce Luca's verdict, and it does **not**
require the full port core — a scene and one asset are enough.

## Resolved when

Luca has played the spike and given a verdict on framing and feel. Until then it
is unresolved, and no camera or art direction is locked in.

## Spike artifacts — static framing pass (added by the arena_spike build)

Prototype: `godot/prototypes/arena_spike/` (project.godot, Main.tscn,
arena_spike.gd, render.sh, assets/volpe-rigged.glb — a byte-identical copy of
`meshy/rigged/volpe/volpe-rigged.glb`). Renders + raw logs live in that folder;
the full write-up is `docs/wayfinder/evidence/camera-spike-render.md`.

Three real 1280x720 PNGs were rendered headless (Xvfb + Mesa llvmpipe, exit 0,
`ARENA_PASS` in each log): `arena_default_1280x720.png`,
`arena_wide_1280x720.png`, `arena_playable_1280x720.png`.

What the spike answers, and what it does not:

- **Court dimensions are now read, not assumed.** `COURT` is
  `left 80 / right 880 / top 56 / bottom 564 / netY 310 / netHeight 38`, giving
  800 x 508 px = aspect **1.575**, which is **not** 20:10 = 2.0. Under one
  uniform scale (0.025 m/px, chosen so 800 px = the 20.00 m FIP length) the
  court is 20.00 x **12.70** m and the net 0.95 m. The "20x10" figure in this
  ticket is therefore only half-confirmed: the length is right at that scale, the
  width is not. This needs a decision — the web layout either compresses depth or
  is not a scale plan — before the port locks a court mesh.
- **The web's default match camera is a near-top-down whole-court view.** Its
  composition is the pseudo-3D trapezoid in `js/render.js` (`point()`): far
  baseline at y=100 spanning x 210..750, near baseline at y=687 spanning
  x 48..912, net warped to y≈358. A pinhole camera at 16:9 cannot reproduce that
  trapezoid exactly (`sin(pitch)` would have to exceed 1); the best fit that
  holds the player's baseline exactly sits 14.46 m up at 65.2 degrees of pitch.
  Consequence for this ticket: **framing parity with today's build and a playable
  3D camera are different compositions.** Luca's verdict should be taken on both
  (the `default` render and the `playable` render are exactly that pair).
- **No idle clip is claimed.** The rig was loaded and held at t=0.300 s of its
  single `Armature|clip0|baselayer` key (7 tracks, length 0.300); the athlete is
  a static base pose standing on the court. Measured height 1.678 m from the
  bone extent in that pose.
- **Not in this artifact:** ball motion from `BALANCE`, the diagonal serve, any
  camera tuning UI, rackets, opponents, HUD, performance measurement. This pass
  is the static framing question only.

Status stays **open** — it still needs Luca's verdict.
