# The active athlete's marker (zone + pin)

## The gap this closes

The owner, testing with a pad: *"non vedo nemmeno il puntatore sopra il giocatore
selezionato in quel momento"*. Nothing was wrong with the switch itself — the
simulation has moved the control correctly since the port, and the input bridge was
fixed in the same session (`player-switch-parity.md`). Nothing on the field said
*where the control went*, so a working switch and a broken one looked identical.

The reference draws three things around `state[state.activePlayerKey]`:

| reference | where | ported |
|---|---|---|
| hit zone: dashed ellipse, radii `paddle.w * 0.62` × `paddle.reach * 0.52`, `#fff36a`, alpha 0.25 | `js/render.js:913-924`, called at `js/main.js:1850` | yes — `ActiveRing` |
| team geometry: dashed link to the partner, dot at the midpoint, red on overlap | `js/render.js:926-947` | **no** |
| timing ring while charging + the energy bar under the active athlete | `js/render.js:1646+` | bar only, in the HUD (`hud.gd::_update_energy`) |

The HUD does name the controlled athlete — `ENERGIA — TU` / `ENERGIA — COMPAGNO`
(`hud.gd:430-434`) — but that is a label in a corner, not a mark on the field.

## What was added

`_active_ring` (the reference's hit zone, on the floor) and `_active_pin` (a cone
pointing down at the athlete, 2.45 m up). The pin has no reference counterpart: it
exists because the zone alone does not read. Both are built in
`match_controller.gd::_build_scene` and placed in `_sync_views`, per frame, from
`state.active_player()`.

## What the measurements cost, and why they are written down

Three attempts were needed, each one measured rather than eyeballed. Screenshots of
the running game are unavailable on this host, so every claim below comes from a
rendered frame written by `--capture=match` and read back with
`game/tools/inspect_png.py` and `game/tools/yellow_map.py`.

1. **Faithful line weight drew nothing.** A 2 px stroke at alpha 0.25 is a crisp mark
   on a canvas; on a 20 m court it is 5 cm, and in the frame it was invisible. The
   first capture showed no ring and the vision pass agreed.
2. **A 12% band at alpha 0.85 drew a 4 px mark.** The ellipse's two radii are scaled
   apart (×1.80 across the court, ×0.67 deep), so a *relative* band is 21 cm one way
   and 8 cm the other. 28% at alpha 0.95 gives ~50 cm and ~19 cm.
3. **The lift was in the wrong unit.** `Court.world_pos(px_x, px_y, px_z)` takes its
   third argument in sim pixels: `0.04` put the ring **1 mm** above the floor, inside
   the depth buffer's resolution. 3 cm (`ACTIVE_RING_LIFT`) is what the athletes' own
   tint rings use (`court.gd:279`).
4. **The pin is sized from pixels, not taste.** A 20 cm cone measured 18 × 30 px at
   1280×720 and read as a speck; 28 cm × 55 cm measures ~24 × 40 px.

## Evidence

Frame from `--capture=match --camera=default --tier=3 --seed=20260916`
(`game/out/rally.png`), with the node positions printed by `_save_frame` as
`CAPTURE_MARKER` and the pixels counted by `yellow_map.py`:

```
CAPTURE_MARKER zone=(403,571) pin=(360,545) zone_visible=true pin_visible=true
```

```
# rally.png window=300,500,180,110 cell=6 mode=yellow pixels=915
 530 .........+###+................   <- the pin (the cone over the athlete)
 554 ......................++++++..   <- the zone (the floor ellipse)
 560 ......................########
```

The attribution is an A/B, not an eyeball: the same frame rendered with the two
nodes switched off drops that window from **1269 to 96** yellow pixels, and the 96
that survive sit on the ball (a small yellow blob that is in both frames).

## Tests

`game_slice_test.gd::_active_player_marker` (section 3d, 9 checks): the zone and the
pin exist, both are drawn while the match runs and hidden when it ends, they sit on
`state.active_player()`, the zone carries the reference's two radii read from the
live paddle, and **both follow a switch** to the partner — the check that would have
caught the original complaint.

## Known gaps

- The team-geometry link and the timing ring are still not ported.
- The pin does not distinguish the two seats in PvP/co-op: it marks whichever paddle
  `activePlayerKey` names, which is the human pair's — the reference's own choice.
- Nothing here is in the simulation: `godot/src/sim/**` is untouched and the parity
  digests are unchanged.
