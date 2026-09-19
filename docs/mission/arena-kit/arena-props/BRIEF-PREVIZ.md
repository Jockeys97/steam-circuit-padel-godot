# Brief for Captain B — 2D pre-viz plan, all five arenas

Owner: Captain B (pre-viz). Read `docs/mission/arena-kit/arena-props/CHARTER.md` first.

Workdir: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`).

## You own exactly

- `godot/tests/arena_kit_specs_dump.gd` (new; a headless probe that prints the spec table)
- `tools/arena-kit/previz_2d.py` (new; builds the plans)
- `docs/mission/arena-kit/arena-props/previz/**` (new; all outputs)
- `docs/mission/arena-kit/arena-props/PREVIZ-RESULT.md`

Do NOT edit `godot/game/arenas/arena_kit.gd`, any GLB, any asset folder, or anything under
`art/arena-kits/`. Do NOT touch the `feat-native-world-arenas` worktree. Do NOT commit.

## What Luca asked for

Populate the map in a 2D pre-viz so the map reads as filled. So the 2D plan is the dense
view: every slot, every repeat instance, at true metre scale. The 3D view is the sparse one
and is someone else's problem.

## The data must come from the engine, not from your notes

`godot/game/arenas/arena_kit.gd` already holds the real placement contract as a `const SPECS`
dictionary, 5 arenas times 10 slots. Each entry carries:

- `anchor`: a Vector3 in metres, the authored ground-contact point
- `target_h`: the height the mounted piece normalizes to, in metres
- `repeats`: how many instances the slot places
- `spread`: metres between repeat instances
- `depth`: the declared footprint depth of one instance, in metres
- `footprint`: a human-readable note
- `suppress`, `kinds`: the procedural counterpart, used by the other captain

Also in that file, and load-bearing for the plan: `GLASS_PLANE_Z` (-10.02), `PROP_Z`
(-11.65), `DEPTH_BUDGET` (3.26), `AUTHORED_HALF_X` (14.35).

Hand-copying those numbers into Python guarantees drift. Instead: write a small headless
GDScript probe that dumps the whole `SPECS` table plus those four constants to JSON, run it
with the engine, and have the Python builder consume that JSON. Record the exact probe
command in your result.

Engine facts for this repo (do not rediscover them):

    export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
    $GODOT --headless --path godot/ --import      # first, if imports are stale
    $GODOT --headless --path godot/ --script res://tests/arena_kit_specs_dump.gd

One engine process at a time: guard with `pgrep -x Godot` before running, and do not run
the engine while another lane is using it. Print JSON to stdout and save it beside your
outputs so the plan is reproducible.

## What the plan must show, per arena

A true-scale top-down view (looking down -Y), one arena per panel, all five:

- the court outline, read from the engine's own court geometry or the spec/court constants,
  whichever is authoritative in this repo; say which you used
- the field-law plane at z = -8.0, drawn as a hard line, since nothing may cross it
- the glass plane at z = -10.02, drawn distinctly
- the authored frame law at x = plus or minus 14.35, drawn as the outer limit
- every instance of every slot as a marker at its true anchor, with repeat instances spaced
  by `spread` along x, drawn as its declared footprint rectangle (x-extent by `depth`)
- the slot name on or beside each marker, and the repeat count visible
- a legend and a per-arena instance total

Two outputs:

1. `docs/mission/arena-kit/arena-props/previz/<arena>-plan.png` per arena, plus a combined
   sheet of all five
2. `docs/mission/arena-kit/arena-props/previz/index.html` — one self-contained file, a
   switcher over the five arenas, so Luca can click between maps. Reuse the PNGs as
   embedded or linked images; no build step, no network dependency.

## Honesty gates

| Gate | Threshold |
|---|---|
| Instance count | the plan's instance total equals the spec table's computed total, for all five arenas |
| Every arena | five panels present, no placeholder |
| Consistency | zero instances drawn in front of z = -8.0; flag any that are, in the result |
| No invention | every number in the plan traces to the dumped JSON; the probe command is recorded |
| Renders | the HTML opens and switches arenas; PNGs are non-blank at the expected size |

If the spec table itself puts an instance in front of the field-law plane, that is a real
finding: report it, do not silently move it.

## Return

Short plain prose: probe command, per-arena instance totals as a table, any instances that
break the field law, output paths, and the one thing you are least confident about.
