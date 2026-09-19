# Brief for Captain D — fit the props to the band, then show the 3D

Owner: Captain D (integrator, wave three). Read `docs/mission/arena-kit/arena-props/CHARTER.md`,
`CENSUS.md`, and `PROPS-RESULT.md` first. Those two carry the measured numbers you need.

Workdir: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`).

## What the previous pass established (parent-verified, do not redo)

- Doubling is fixed: 16 slots suppressed, 34 left alone, 296 stray procedural meshes gone to 0.
- Heights, frame law, material policy and culling all pass.
- Fifty GLBs are intact, sha256-identical to the pre-run fingerprint. Do not regenerate anything.
- Four gates fail, all one defect: the real Meshy meshes are deeper than the spec table assumed,
  so seventeen mounted pieces push forward through the rear glass and overlap the court volume.
  Parent reproduced the suite result independently: `world_arenas_field_law_test.gd` FAIL 79/88,
  zero script errors.

## The geometry you are working with

The rear glass sits at z = -10.02 and the backdrop wall at z = -12.0. The usable band is under
two metres deep, and the pieces that offend measure 2.4 to 3.9 metres deep. So a piece cannot
both sit behind the glass and stay fully in front of the wall. Decide per piece, do not pretend
the band is bigger than it is.

## You own exactly

- `godot/game/arenas/arena_kit.gd` (anchors and declared depths only)
- `godot/tests/arena_kit_test.gd` if a gate assertion must move to match
- `docs/mission/arena-kit/arena-props/FIT-RESULT.md`, `.../captures/**`
- a small helper under `tools/arena-kit/` if you need one

Do NOT change `target_h` for any slot. Heights are correct and the owner approved the look.
Do NOT change any GLB, `arena_scenery.gd`, `arena_look.gd`, `art/arena-kits/**`, or the
`feat-native-world-arenas` worktree. Do NOT commit or push.

## Job 1 — the objective fix

Every mounted piece's front face must sit behind the rear glass at z = -10.02, with a small
margin, so nothing clips through the glass and nothing overlaps the court footprint. Do it by
moving the affected anchors back, because that is the change that does not alter how a prop
looks. Where moving an anchor back would bury a piece so far behind the backdrop wall that it
reads as cut off, report that piece instead of shrinking it: the scale call is the owner's.

Prefer measured numbers over declared ones. `docs/mission/arena-kit/arena-props/CENSUS.md` and
the census tool carry each piece's real z-range; use those, and re-measure after the change
rather than trusting the arithmetic.

Then make the spec table honest: set each slot's declared `depth` to its measured depth, and
update the footprint note's width and height and depth to the measured values, so the 2D plan
and the spec stop disagreeing with the art.

## Job 2 — prove it

Re-run and report command, exit code and tally for:

- `world_arenas_field_law_test.gd` — must return to 88/88
- `arena_kit_test.gd`
- `world_arenas_frame_test.gd`, `world_arenas_selection_test.gd`,
  `arena_selector_contract_test.gd`, `screen_arena_audit.gd`
- `mount_census.gd` — the court-overlap and glass gates must go green

Known and not yours: `game_slice_test.gd` has a pre-existing locale failure, 688 against 689
keys, from another lane. Report the baseline you measured rather than claiming you caused or
fixed it.

## Job 3 — show the 3D, which nobody has seen yet

Every pass so far was headless geometry. Luca asked for the 3D not to be cluttered, and that is
a look verdict he has to make with his eyes, not from a table. Render the five arenas:

    /Applications/Godot.app/Contents/MacOS/Godot --path godot/ --rendering-driver opengl3 \
      --resolution 1280x720 res://tests/world_arenas_capture.tscn -- --out=docs/mission/arena-kit/arena-props/captures

Use a fresh output name, never overwrite a frozen capture register. Check `pgrep -x Godot`
first and wrap every run in `flock -w 900 /tmp/padel-godot.lock`. Never `pkill`. Write the exact
command you used into FIT-RESULT.md.

## Job 4 — regenerate the 2D plan

Anchors changed, so the plan on disk is now stale. Rebuild it with
`python3 tools/arena-kit/previz_2d.py` after the spec table is final, so the plan and the engine
agree. Do not hand-edit the plan's outputs.

## Gates

| Gate | Threshold |
|---|---|
| Glass | zero mounted pieces with a front face in front of z = -10.02, re-measured |
| Court | zero mounted pieces overlapping the court footprint |
| Field law | `world_arenas_field_law_test.gd` back to 88/88 |
| No other regression | the other suites at or above the baseline you measured first |
| Spec honest | declared depth equals measured depth for all fifty slots |
| Plan fresh | regenerated after the final table, instance totals recomputed |
| Captures | five 1280x720 images on disk, non-blank, named per arena |

Fail honest. If a gate cannot pass without a scale change, say so and name the pieces rather
than forcing it.

## Return

Short plain prose: how many anchors moved and by how much, which pieces still poke behind the
backdrop wall, the gates table with re-measured values, suite tallies, capture paths, and what
you could not verify. No ids in prose.
