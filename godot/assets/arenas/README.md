# Arena kits — the drop-in slot folder

One GLB per slot, one folder per arena:

    godot/assets/arenas/<arena>/<slot>.glb      (arena = torii | medina | carioca | aurora | egeo)

The engine remembers nothing between files: `godot/game/arenas/arena_kit.gd` reads
`godot/assets/arenas/<arena>/<slot>.glb` at build time through `GLTFDocument` (the athlete-rig
precedent — no `.import`, no editor pass), normalizes the model to the slot's spec height in
metres, drops it at the slot's anchor under `Scenery/Kit/Slot_<slot>`, and leaves the
procedural blockout exactly as it was. **An empty folder changes nothing**: with no `.glb`
anywhere the built arena is byte-identical to the pre-kit tree (proved by
`godot/tests/arena_kit_test.gd` against a recorded baseline).

Two ways a file gets here:

* pull a finished Meshy task — `python3 tools/arena-kit/pull_meshy.py --arena torii --slot hero_landmark --task <id>`
* drop it by hand — put it at `meshy/inbox/<arena>/<slot>.glb` and run
  `python3 tools/arena-kit/pull_meshy.py --from-inbox --all` (no credentials needed)

Slots, anchors, target heights, repeat counts and footprints live in the spec table at the top
of `godot/game/arenas/arena_kit.gd`; the short recipe for adding or changing an arena is
`docs/mission/arena-kit/PIPELINE.md`, and the frozen contract behind both is
`docs/mission/arena-kit/KIT-STANDARD.md`.

Rules a slot asset must keep (checked by the engine, not trusted): bottom origin, +Z facing the
camera, one connected solid mass, no lights, no cameras, no collision, and a footprint that
stays behind the rear glass.
