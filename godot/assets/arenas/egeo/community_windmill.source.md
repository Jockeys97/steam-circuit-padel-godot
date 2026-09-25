# Egeo community windmill

Source: [Weathered Windmill by chaos411vm on Meshy Community](https://www.meshy.ai/it/3d-models/019dae33-b596-7044-84e9-00c9e5101023). The public model page labels the 3D output **CC0**; Meshy's [Community License](https://www.meshy.ai/terms-of-use) applies CC0 to published 3D models, but separately applies CC BY-NC to uploaded reference images. The game includes only the textured 3D model, not its reference image. Model-page title, creator, and license checked on 2026-09-25.

User-supplied Meshy textured GLB: `Meshy_AI_Weathered_Windmill_0925123633_texture.glb`, downloaded 2026-09-25. Source SHA-256: `f0b40b16ce53bb799f15737e63388a5e522efe9bfe1d233df500aee0d1908a07`. The original remains in Downloads, outside the repository.

The original is 145.2 MiB with 3,612,179 triangles and four 2048² textures. The in-game file is 2.8 MiB with 100,322 triangles and four 1024² textures (output SHA-256: `bbe7d7cf3dc658645db53dcd68afc6e012f20d140bc8abe9163e111ef1716f46`). No Draco or meshopt runtime extension is required. The model is distant scenery in Egeo only, outside the court, without collision or dynamic shadows. The procedural windmill remains as a fallback if the GLB cannot load.

Reproduction: first run `gltf-transform optimize SOURCE.glb stage1.glb --compress false --texture-compress auto --texture-size 1024 --simplify-ratio 0.03 --simplify-error 1 --palette false` with `@gltf-transform/cli` 4.5.0. Then install `@gltf-transform/core` 4.5.0 and `meshoptimizer` 1.2.0 in a temporary npm prefix and run `NODE_PATH=/path/to/temp/node_modules node tools/meshy/optimize_community_windmill.cjs stage1.glb output.glb 0.15 0.05`. The second stage compacts all vertex attributes after simplification. Validate with `gltf-transform validate output.glb` and import with Godot before using it.

Visual check: captured in the Egeo match and courtside views on 2026-09-25. A 7,884-triangle variant was rejected because the sails became too broken at gameplay distance. The selected 100,322-triangle version keeps their outline readable.
