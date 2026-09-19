# Arena props, all five worlds

Date: 2026-09-19
Owner: parent session (CEO)
Tree: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`)
Run as an org simulation.

## Outcome

Every world arena is dressed with real Meshy props: five arenas times ten slots, textured,
mounted in the engine, no procedural doubling, and no clutter in the 3D view. Luca gets a
2D pre-viz plan of each map, fully populated, so he can read the whole dressing at a glance.

Done means:
- 50 GLBs on disk (medina's ten already landed, forty more to generate)
- The engine mounts each slot at its spec anchor, and the procedural prop it replaces is
  suppressed so nothing doubles
- A 2D top-down plan per arena, generated from the engine's own spec table, showing every
  instance including repeats
- The 3D scene stays clean: measured prop counts, real mounted footprints inside the depth
  budget, nothing crossing the field-law plane
- Test suites green with the GLBs present

## Out of scope

- The nine steampunk arenas (KIT-STANDARD §7 leaves those open)
- New intake images; the five sets of ten PNGs already exist
- Sky strategy, backdrops, court, glass, net (all procedural, not kit slots)
- Commits and pushes
- The `feat-native-world-arenas` worktree

## Frugal spend

Luca approved the full set this turn.

- Hard cap: 40 image-to-3D jobs, 15 credits each, 600 credits. Balance at dispatch: 2297.
- Floor: stop launching new jobs if the balance drops below 600.
- One retry per failed slot. No third attempt; a third failure goes to the board report.
- Never regenerate a slot whose GLB already exists and is non-trivial.
- Ground textures never upload.

## What already exists (do not rebuild)

- `godot/game/arenas/arena_kit.gd` (776 lines) already holds the contract: the 5x10 `SPECS`
  table with an anchor in metres, target height, repeat count and spread, declared depth,
  and a `suppress` flag plus the procedural `kinds` each slot stands over. It already loads
  a GLB with `FileAccess.file_exists` and runtime `GLTFDocument`, normalizes to bottom
  origin, scales in metres, and names the node `Kit/Slot_<slot>`.
- `godot/tests/arena_kit_test.gd` already exercises the mount path and the suppress path.
- `tools/arena-kit/gen_medina_t2.py` is the proven generator for one arena.
- Ten textured Medina GLBs are on disk and verified.

The seam is built. This mission fills it and turns it on.

## The clutter rule (Luca's directive)

The 2D plan shows the map fully dressed. The 3D scene must not. Concretely: the engine's
default is additive, so a mounted GLB and its procedural counterpart both build. With real
GLBs in place that doubles the dressing and reads as clutter. Flipping `suppress` per slot
is the fix, and the mission must prove the doubling is gone rather than assert it.

## Gates

1. **Generation.** Forty textured GLBs land, ledgers reconcile against the live balance.
   Handle: `godot/assets/arenas/<arena>/<slot>.glb`, `LEDGER.jsonl`
2. **2D pre-viz.** A per-arena top-down plan, built from the engine's own spec table, every
   instance drawn, five arenas. Handle: `docs/mission/arena-kit/arena-props/previz/`
3. **Mount.** Every arena mounts its ten slots at the spec transform with the procedural
   counterpart suppressed. Handle: `arena_kit` test tally plus a mounted-prop census
4. **No clutter.** Measured: prop count per arena before and after, every mounted footprint
   inside the depth budget, nothing in front of the field-law plane. Handle: census table
5. **Suites.** The frozen audits still pass with GLBs present. Handle: command, exit code,
   tally line

Luca's look verdict is the last gate and is never self-approved.

## Teams

- Captain A, generation: forty GLBs plus ledger and previews. Owns the generator script and
  the four arena asset folders.
- Captain B, pre-viz: the 2D plan builder and its spec dump. Owns the dump probe and the
  previz outputs. Reads `arena_kit.gd`, writes nothing under `godot/` except the probe.
- Captain C, integrator, wave two: turns suppress on, runs the mounted census, runs the
  suites, owns `godot/game/arenas/arena_kit.gd` and the kit tests after A has landed.

Wave one is A and B in parallel, with disjoint file ownership. C runs after A because the
mount proof needs the GLBs.

## Reporting

Append `docs/mission/arena-kit/arena-props/LOG.md` per step. Board report at each gate.
Plain English in the report; raw ids stay in the files.

## Retry

Max two retries per gate per captain. A third failure goes to the board.
