# Outdoor arena landmarks

The three reference images were created with the built-in image generation tool,
then used as the sole image inputs to Meshy image-to-3D. They depict isolated,
three-quarter-view subjects on neutral backgrounds (no court or players):

| Arena | Reference brief | Runtime model |
| --- | --- | --- |
| Torii | Steampunk Kyoto five-tier shrine/pagoda, dark wood, vermilion, brass and lanterns | `godot/assets/arenas/torii/distant_landmark.glb` |
| Medina | Ochre Moroccan monumental gate with horseshoe arch, zellige and brass pipes | `godot/assets/arenas/medina/distant_landmark.glb` |
| Aurora | Icelandic basalt columns and icy spires around a geothermal vent | `godot/assets/arenas/aurora/distant_landmark.glb` |

Each task used Meshy 7.1 image-to-3D, textured 2K, PBR, triangular remesh targeting
10,000 polygons, GLB output: 30 Meshy credits per arena, 90 credits total.
`scripts/meshy-outdoor-landmarks.mjs` persists each task ID before polling, so a
retry cannot silently submit another paid request. Source GLBs are retained here;
`scripts/optimize-outdoor-landmark.mjs` reduces embedded texture dimensions to
1024 pixels for the runtime GLBs. All binary assets are covered by Git LFS.

`godot/game/arenas/outdoor_landscape.gd` places the models beyond the back glass,
without collision or dynamic shadows. Existing arena-kit assets remain intact.
