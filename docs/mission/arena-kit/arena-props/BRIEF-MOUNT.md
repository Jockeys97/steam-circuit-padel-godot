# Brief for Captain C — mount the props and kill the clutter

Owner: Captain C (integrator, wave two). Read `docs/mission/arena-kit/arena-props/CHARTER.md` first.

Workdir: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`).

## State you inherit (verified by the parent, not taken on trust)

All fifty GLBs exist: five arenas times ten slots, every one textured, ledger reconciled at
600 credits. The engine seam in `godot/game/arenas/arena_kit.gd` already loads a GLB with
`FileAccess.file_exists` plus runtime `GLTFDocument`, normalizes to bottom origin, scales in
metres, and names the node `Kit/Slot_<slot>`.

## You own exactly

- `godot/game/arenas/arena_kit.gd`
- `godot/tests/arena_kit_test.gd`
- `tools/arena-kit/mount_census.gd` (new, or a Python driver if that reads the tree better)
- `docs/mission/arena-kit/arena-props/PROPS-RESULT.md`, `.../CENSUS.md`

Do NOT change any anchor, `target_h`, `repeats`, `spread`, or `depth` in `SPECS`. The 2D
pre-viz is being built from those exact numbers by another captain and any drift invalidates
it. You are changing `suppress`, and only where justified.

Do NOT touch the GLB folders, `art/arena-kits/**`, `godot/game/arenas/arena_scenery.gd`,
`arena_look.gd`, or the `feat-native-world-arenas` worktree. Do NOT commit or push.

## The job

Luca's directive: the 2D plan is the dense view, the 3D scene must not be cluttered. The
engine's documented default is additive, so a mounted GLB and its procedural counterpart both
build. With fifty real models that doubles the dressing.

1. **Prove the doubling is real before fixing it.** Take a census with GLBs present and
   suppress off: per arena, per slot, how many procedural instances and how many mounted
   instances exist, and which slots carry both. A slot with a procedural `kinds` entry AND a
   GLB is the doubling. Report the before number.
2. **Fix it.** Turn `suppress` on for exactly those slots. Slots with `kinds: []` have no
   procedural counterpart and need no change; say so rather than blanket-flipping.
3. **Re-census.** Prove the doubling is gone with real numbers.

## No-clutter gates, measured not asserted

| Gate | Threshold |
|---|---|
| Doubling | zero slots carrying both a procedural and a mounted instance after the fix |
| Field law | no mounted instance crosses the field-law plane at z = -8.0 |
| Depth budget | each mounted instance's real depth fits `DEPTH_BUDGET` (3.26 m) |
| Frame law | no instance or repeat run extends past `AUTHORED_HALF_X` (14.35) |
| Materials | the shared kit material policy holds: bounded unique materials per arena, not one per model |
| Culling | mounted props are behind the play area and cannot occlude the court from the default camera |

Measure real mounted bounding boxes from the engine, not from the spec's declared depth. A
GLB whose mesh disagrees with its declared footprint is a real finding: report it.

## Engine discipline (this repo's own rule, follow it)

One Godot process at a time. Wrap every run in
`flock -w 900 /tmp/padel-godot.lock` and check `pgrep -x Godot` first. Another captain may
briefly be using the engine for a headless dump; if the lock is held, wait rather than kill
anything, and never `pkill`. On macOS:

    export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
    $GODOT --headless --path godot/ --import
    $GODOT --headless --path godot/ --script res://tests/arena_kit_test.gd

A `PASS` line next to a `SCRIPT ERROR` is a failure; count `SCRIPT ERROR` separately.

## Suites to keep green

`arena_kit_test.gd`, `arena_selector_contract_test.gd`, `screen_arena_audit.gd`,
`world_arenas_*`, `game_slice_test.gd`. Report command, exit code, and tally line for each.
If a suite was red before you started, say so and show the baseline; do not claim you broke
or fixed what you did not.

## Return

Short plain prose: the before and after doubling numbers, the gates table with real measured
values, suite tallies, any GLB whose mesh disagrees with its declared footprint, the
suppress decision per slot, and what you could not verify. No ids in prose.
