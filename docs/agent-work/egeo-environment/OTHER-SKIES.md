# Outdoor sky panel removal

Checkpoint before this change: `eb86bf7` (93 files from concurrent tasks).

Torii, Medina, Carioca and Aurora now hide the legacy Backdrop, artwork, veil
and apron wall. Their existing panorama sky remains visible across camera
changes. Dressing, kit assets, cameras, lighting and gameplay are retained.
Sky fog influence is zero; geometric depth fog remains. Aurora ribbon textures
receive a small build-time horizontal alpha fade to soften rectangular ends.

Validation: native Godot 4.7.2, `res://tests/world_sky_panel_test.gd`, exit 0,
`WORLD_SKY_PANEL failures=0`. Generated 28 captures (four arenas, seven cameras)
under `/tmp/sky-*.png`; inspected courtside for all four and the final Carioca
and Aurora captures after refinements. Shutdown still reports cached GLB/RID
resource leaks, as previous arena capture tests did. This is not a leak fix or
an FPS benchmark.

Scope limit: this removes the sky rectangle, not the remaining sparse scenery
or the finite ground edge. Carioca still has a pale horizon. Full 3D landscape
recomposition, as done for Egeo, remains a separate visual pass.

Another task continued editing athlete_rig.gd after the checkpoint; that later
work was not overwritten or included in this sky change.
