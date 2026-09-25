# rally_car.glb

Source: owner's Meshy web-app generation "Azure Rally Racer" (2026-09-25), downloaded as
`Meshy_AI_Azure_Rally_Racer_0925133700_texture.glb` (508,428 triangles, 21.8 MB).
Reference image: the blue rally hatchback render (ChatGPT, Downloads).

Background prop, so reduced locally with gltf-transform (no credits):
`weld` -> `simplify --ratio 0.02 --error 0.002` -> `resize 1024` -> `jpeg`.
Result: 11,574 triangles, 0.97 MB; inspected side by side with the source.
Meshy-normalised size 1.90 x 0.86 x 1.08 (long x tall x wide), centred (min_y -0.43):
scale and lift it to the ground on placement.
