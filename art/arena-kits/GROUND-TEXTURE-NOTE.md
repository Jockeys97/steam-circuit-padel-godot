# `ground_texture` — scale note (LOOK lane)

The image-only slot of KIT-STANDARD §1 (`art/arena-kits/<arena>/ground_texture.png`) is not a
Meshy model: it is the ground material's albedo. The engine reads it, at runtime, from the
kit folder of the same arena:

```
art/arena-kits/<arena>/ground_texture.png      -> source swatch (this folder, unchanged)
godot/assets/arenas/<arena>/ground_texture.png -> the file the engine loads
```

Enable it for an arena by copying (or on Windows, pasting) the swatch:

```sh
cp art/arena-kits/torii/ground_texture.png godot/assets/arenas/torii/ground_texture.png
```

With no file in place — the state of the repo today — the ground keeps the arena's palette
colour (`palette.floor`, darkened) exactly as before: an absent slot is not an error and
nothing about the built tree or the frame changes (`arena_look.gd::apply_ground_texture`,
`godot/tests/arena_look_test.gd`).

## What one tile covers

`arena_look.gd::GROUND_TILE_M = 2.5` metres. The swatch is authored full-bleed and square, so
one textel-tile reads at roughly player scale on the apron and on the ground beyond the cage
without turning the far ground into visual noise. It is applied to two surfaces:

| surface | node | UV span it is tiled over |
|---|---|---|
| ground beyond the cage | `Arena/Surround` (80 × 80 m plane) | 32 × 32 tiles |
| apron strip at the backdrop | `Scenery/BackdropApron` (47 × 0.42 m) | 18.8 × 1 tile |

If the swatch ever reads too large or too small, `GROUND_TILE_M` is the single number to
change; it is asserted against the wiring in `godot/tests/arena_look_test.gd`
(`ground/present_uvs_tile_at_the_ground_tile_metres`).
