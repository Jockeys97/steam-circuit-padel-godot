# Arena props (torii, carioca, aurora, egeo) — GEN RESULT

Date: 2026-09-18T22:56:52Z · Captain A (generation) · Repo: `steam-circuit-padel-godot` (primary `main`)
Brief: `docs/mission/arena-kit/arena-props/BRIEF-GEN.md` · Script: `tools/arena-kit/gen_arena_t2.py`

## What generated

Forty textured arena props were generated through the Meshy Image-to-3D API exactly as the
brief specifies: Mesh T2 + Smart Topology (`model_type: "smart-topology"`, `ai_model: "meshy-t2"`),
texture on the create call (`should_texture: true`, `enable_pbr: true`, `texture_resolution: "2k"`),
triangle output at `target_polycount: 4000`, `target_formats: ["glb"]`. Each intake PNG
(`meshy/arenas/<arena>/<slot>.png`, 1024×1024) was sent as a base64 data URI. GLBs were
downloaded immediately on `SUCCEEDED` (signed URLs expire), with the task thumbnail saved as
the slot preview (`previews/<arena>/<slot>.png`). Medina was not regenerated.

| arena | slot | task_id | status | credits | triangles | GLB bytes | sha256 (12) | preview |
|---|---|---|---|---|---|---|---|---|
| torii | hero_landmark | 01a0b6b7-5897-7060-b7dd-8318d87d2669 | SUCCEEDED | 15 | 3996 | 6832960 | 18c130a2baf3 | yes |
| torii | gate_portal | 01a0b6b7-696d-774a-9e42-4ed9d4163ba0 | SUCCEEDED | 15 | 4306 | 4174608 | 6a09b343e0fb | yes |
| torii | light_source | 01a0b6b7-79d1-719e-8332-c680f8a8d635 | SUCCEEDED | 15 | 4166 | 4901516 | 817ccaf55e11 | yes |
| torii | vegetation_cluster | 01a0b6b7-89ba-748b-b46f-dead7146eefe | SUCCEEDED | 15 | 4158 | 4327916 | d429a7f633c5 | yes |
| torii | ground_dressing | 01a0b6b7-99fe-7307-82ed-fad269700c48 | SUCCEEDED | 15 | 4283 | 6241372 | 662c8a02dfb3 | yes |
| torii | ornament_accent | 01a0b6b7-aa84-7315-9387-b599415f437b | SUCCEEDED | 15 | 3613 | 4392756 | 102a3ce0169f | yes |
| torii | column_pillar | 01a0b6b7-bb5c-751c-a5ae-ff2c93dcddc1 | SUCCEEDED | 15 | 4378 | 4225984 | b6ce62f90ceb | yes |
| torii | railing_segment | 01a0b6b7-caf5-7636-9d2f-265bbbab4c0e | SUCCEEDED | 15 | 4152 | 4668312 | 84eb505336d0 | yes |
| torii | furniture | 01a0b6b7-da1f-7225-8556-817417a977c6 | SUCCEEDED | 15 | 4160 | 3874196 | fab9964ae90d | yes |
| torii | signage_banner | 01a0b6b7-ea83-70cd-9c7d-21d4073993f6 | SUCCEEDED | 15 | 4432 | 3944028 | b76f004cad8d | yes |
| carioca | hero_landmark | 01a0b6b8-a46a-7324-91cf-0bfbd766c33f | SUCCEEDED | 15 | 3651 | 5556944 | 00bfc581527f | yes |
| carioca | gate_portal | 01a0b6b8-b533-727a-8d4d-5c20849c80e9 | SUCCEEDED | 15 | 3985 | 3401164 | af7bc64e7807 | yes |
| carioca | light_source | 01a0b6b8-c4cb-711c-b4f7-fa23a88357bc | SUCCEEDED | 15 | 4303 | 5655180 | 640498e30bb0 | yes |
| carioca | vegetation_cluster | 01a0b6b8-d4e5-708d-9778-d52a110d7f75 | SUCCEEDED | 15 | 4234 | 5817384 | b806c2020646 | yes |
| carioca | ground_dressing | 01a0b6b8-e4cf-770f-a33c-7463264daa5b | SUCCEEDED | 15 | 4315 | 4770912 | d9f12ff391df | yes |
| carioca | ornament_accent | 01a0b6b8-f537-761a-ad66-e00dadd6307b | SUCCEEDED | 15 | 4232 | 3862128 | 92bf56cab3cf | yes |
| carioca | column_pillar | 01a0b6b9-060c-7784-a092-8a46481bbcf4 | SUCCEEDED | 15 | 4398 | 4130884 | ece8a8704b17 | yes |
| carioca | railing_segment | 01a0b6b9-14fb-7790-b0d4-90b24af43fd9 | SUCCEEDED | 15 | 4163 | 5735932 | 26f3ae151ac4 | yes |
| carioca | furniture | 01a0b6b9-24fe-7451-a0ee-352931c810f8 | SUCCEEDED | 15 | 4336 | 4612684 | e14228785add | yes |
| carioca | signage_banner | 01a0b6b9-3526-72ad-895b-8f87046fd431 | SUCCEEDED | 15 | 4370 | 5055712 | 6f41c97d0b0b | yes |
| aurora | hero_landmark | 01a0b6b9-f11b-74c4-8fb9-b12c69c47566 | SUCCEEDED | 15 | 4088 | 5494452 | 1a64777cca2b | yes |
| aurora | gate_portal | 01a0b6ba-017b-77e6-987f-d46ef3397ad2 | SUCCEEDED | 15 | 4398 | 4345856 | d56edf89daee | yes |
| aurora | light_source | 01a0b6ba-11e3-740d-bb44-388d2ec3ea44 | SUCCEEDED | 15 | 4236 | 4904228 | 0839f33d54fc | yes |
| aurora | vegetation_cluster | 01a0b6ba-218a-74a5-a558-710d6c8b82b2 | SUCCEEDED | 15 | 4063 | 5181612 | b226d59e300c | yes |
| aurora | ground_dressing | 01a0b6ba-32d4-717d-adc2-9989acbc72fa | SUCCEEDED | 15 | 4318 | 4403160 | 0d8b5e71f250 | yes |
| aurora | ornament_accent | 01a0b6ba-437f-71e4-a290-eb952ec44b65 | SUCCEEDED | 15 | 3483 | 5252448 | 48ff015b8291 | yes |
| aurora | column_pillar | 01a0b6ba-53e1-75dc-900e-7c1e6dc591f8 | SUCCEEDED | 15 | 4238 | 2458876 | e462f07ebddb | yes |
| aurora | railing_segment | 01a0b6ba-62d2-76ae-b102-6518d66aab32 | SUCCEEDED | 15 | 3875 | 4180972 | bebcf9f8e3db | yes |
| aurora | furniture | 01a0b6ba-7288-7433-b0d0-7192b975ffe3 | SUCCEEDED | 15 | 4200 | 4545392 | 235649483f7a | yes |
| aurora | signage_banner | 01a0b6ba-82fd-72b4-9ded-d00e18ed5cae | SUCCEEDED | 15 | 4159 | 2801832 | 72f4d844b76e | yes |
| egeo | hero_landmark | 01a0b6bb-3e08-75a1-b5a4-e1dd7a6c013d | SUCCEEDED | 15 | 3639 | 4818912 | 85a7f8aba69e | yes |
| egeo | gate_portal | 01a0b6bb-4eb2-70b0-9d8d-92c308e8ef6a | SUCCEEDED | 15 | 4332 | 4626448 | cd78ddd5dfd7 | yes |
| egeo | light_source | 01a0b6bb-5f3c-706d-9266-6a24b91726e8 | SUCCEEDED | 15 | 4374 | 4663300 | 5817395e88a0 | yes |
| egeo | vegetation_cluster | 01a0b6bb-6e94-72a9-980a-252919370bd5 | SUCCEEDED | 15 | 4182 | 3985420 | 9f1fee5870a8 | yes |
| egeo | ground_dressing | 01a0b6bb-7e33-7708-b811-ea0e61ecf7ae | SUCCEEDED | 15 | 3378 | 3862924 | d1472282b970 | yes |
| egeo | ornament_accent | 01a0b6bb-8ec8-775b-b528-4e412f69ecae | SUCCEEDED | 15 | 4089 | 5186904 | d2980ad3235f | yes |
| egeo | column_pillar | 01a0b6bb-9f36-7470-a847-f45c8df0ae94 | SUCCEEDED | 15 | 4334 | 5077968 | 5165afa68dc8 | yes |
| egeo | railing_segment | 01a0b6bb-af58-775b-963f-65e9d76792fb | SUCCEEDED | 15 | 4366 | 3325772 | 538c9c14ff38 | yes |
| egeo | furniture | 01a0b6bb-be33-7076-a6e3-65a7a10281d4 | SUCCEEDED | 15 | 3882 | 4439220 | a33163816d9b | yes |
| egeo | signage_banner | 01a0b6bb-cf65-7695-8f76-6cf11a62ffa7 | SUCCEEDED | 15 | 4016 | 5065776 | 83203c1ee50a | yes |

- Slots succeeded: 40 of 40
- Credits consumed (ledger sum of `consumed_credits`): 600
- Balance before: 2297 · after: 1697 · remaining: 1697
- Triangle range across generated GLBs: 3378 – 4432

## Failures and retries

No failed slots — all forty landed.

## Gates (as specified in the brief)

| Gate | Threshold | Result |
|---|---|---|
| GLBs | 40 files, each over 50 KB, named to slot | PASS |
| Texture | every GLB carries a base-colour image in its material | PASS |
| Ledger | 40 lines with task_id and consumed_credits, no missing slot | PASS |
| Balance | remaining balance recorded, reconciled against the ledger sum | PASS |
| Scope | `git status --short` shows only your owned paths | see raw output below |

Raw tree scope (`git status --short`):

```
?? docs/mission/arena-kit/arena-props/
?? docs/mission/arena-kit/meshy-t2-medina/
?? godot/assets/arenas/aurora/column_pillar.glb
?? godot/assets/arenas/aurora/furniture.glb
?? godot/assets/arenas/aurora/gate_portal.glb
?? godot/assets/arenas/aurora/ground_dressing.glb
?? godot/assets/arenas/aurora/hero_landmark.glb
?? godot/assets/arenas/aurora/light_source.glb
?? godot/assets/arenas/aurora/ornament_accent.glb
?? godot/assets/arenas/aurora/railing_segment.glb
?? godot/assets/arenas/aurora/signage_banner.glb
?? godot/assets/arenas/aurora/vegetation_cluster.glb
?? godot/assets/arenas/carioca/column_pillar.glb
?? godot/assets/arenas/carioca/furniture.glb
?? godot/assets/arenas/carioca/gate_portal.glb
?? godot/assets/arenas/carioca/ground_dressing.glb
?? godot/assets/arenas/carioca/hero_landmark.glb
?? godot/assets/arenas/carioca/light_source.glb
?? godot/assets/arenas/carioca/ornament_accent.glb
?? godot/assets/arenas/carioca/railing_segment.glb
?? godot/assets/arenas/carioca/signage_banner.glb
?? godot/assets/arenas/carioca/vegetation_cluster.glb
?? godot/assets/arenas/egeo/column_pillar.glb
?? godot/assets/arenas/egeo/furniture.glb
?? godot/assets/arenas/egeo/gate_portal.glb
?? godot/assets/arenas/egeo/ground_dressing.glb
?? godot/assets/arenas/egeo/hero_landmark.glb
?? godot/assets/arenas/egeo/light_source.glb
?? godot/assets/arenas/egeo/ornament_accent.glb
?? godot/assets/arenas/egeo/railing_segment.glb
?? godot/assets/arenas/egeo/signage_banner.glb
?? godot/assets/arenas/egeo/vegetation_cluster.glb
?? godot/assets/arenas/medina/column_pillar.glb
?? godot/assets/arenas/medina/furniture.glb
?? godot/assets/arenas/medina/gate_portal.glb
?? godot/assets/arenas/medina/ground_dressing.glb
?? godot/assets/arenas/medina/hero_landmark.glb
?? godot/assets/arenas/medina/light_source.glb
?? godot/assets/arenas/medina/ornament_accent.glb
?? godot/assets/arenas/medina/railing_segment.glb
?? godot/assets/arenas/medina/signage_banner.glb
?? godot/assets/arenas/medina/vegetation_cluster.glb
?? godot/assets/arenas/torii/column_pillar.glb
?? godot/assets/arenas/torii/furniture.glb
?? godot/assets/arenas/torii/gate_portal.glb
?? godot/assets/arenas/torii/ground_dressing.glb
?? godot/assets/arenas/torii/hero_landmark.glb
?? godot/assets/arenas/torii/light_source.glb
?? godot/assets/arenas/torii/ornament_accent.glb
?? godot/assets/arenas/torii/railing_segment.glb
?? godot/assets/arenas/torii/signage_banner.glb
?? godot/assets/arenas/torii/vegetation_cluster.glb
?? godot/tests/arena_kit_specs_dump.gd
?? tools/arena-kit/gen_arena_t2.py
?? tools/arena-kit/gen_medina_t2.py
?? tools/arena-kit/previz_2d.py
```

## Disk checks (live, at report time)

torii/hero_landmark: 6832960 bytes, 3996 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/gate_portal: 4174608 bytes, 4306 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/light_source: 4901516 bytes, 4166 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/vegetation_cluster: 4327916 bytes, 4158 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/ground_dressing: 6241372 bytes, 4283 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/ornament_accent: 4392756 bytes, 3613 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/column_pillar: 4225984 bytes, 4378 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/railing_segment: 4668312 bytes, 4152 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/furniture: 3874196 bytes, 4160 tris, base-colour texture: yes, 1 material(s), 3 image(s)
torii/signage_banner: 3944028 bytes, 4432 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/hero_landmark: 5556944 bytes, 3651 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/gate_portal: 3401164 bytes, 3985 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/light_source: 5655180 bytes, 4303 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/vegetation_cluster: 5817384 bytes, 4234 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/ground_dressing: 4770912 bytes, 4315 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/ornament_accent: 3862128 bytes, 4232 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/column_pillar: 4130884 bytes, 4398 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/railing_segment: 5735932 bytes, 4163 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/furniture: 4612684 bytes, 4336 tris, base-colour texture: yes, 1 material(s), 3 image(s)
carioca/signage_banner: 5055712 bytes, 4370 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/hero_landmark: 5494452 bytes, 4088 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/gate_portal: 4345856 bytes, 4398 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/light_source: 4904228 bytes, 4236 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/vegetation_cluster: 5181612 bytes, 4063 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/ground_dressing: 4403160 bytes, 4318 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/ornament_accent: 5252448 bytes, 3483 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/column_pillar: 2458876 bytes, 4238 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/railing_segment: 4180972 bytes, 3875 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/furniture: 4545392 bytes, 4200 tris, base-colour texture: yes, 1 material(s), 3 image(s)
aurora/signage_banner: 2801832 bytes, 4159 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/hero_landmark: 4818912 bytes, 3639 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/gate_portal: 4626448 bytes, 4332 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/light_source: 4663300 bytes, 4374 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/vegetation_cluster: 3985420 bytes, 4182 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/ground_dressing: 3862924 bytes, 3378 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/ornament_accent: 5186904 bytes, 4089 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/column_pillar: 5077968 bytes, 4334 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/railing_segment: 3325772 bytes, 4366 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/furniture: 4439220 bytes, 3882 tris, base-colour texture: yes, 1 material(s), 3 image(s)
egeo/signage_banner: 5065776 bytes, 4016 tris, base-colour texture: yes, 1 material(s), 3 image(s)

## Method notes

- Triangle counts: measured with `tools/character/glb_tri_count.py` when it ran; otherwise an
  in-script GLB JSON parse. Method used per slot is in `run/tmp/arena-kit/gen-arena-state.json`
  (`tri_method`) and in the journal.
- `enable_pbr` acceptance, straight from each task's `texture_urls`:
- torii/hero_landmark: texture_urls keys = base_color, metallic, normal, roughness
- torii/gate_portal: texture_urls keys = base_color, metallic, normal, roughness
- torii/light_source: texture_urls keys = base_color, metallic, normal, roughness
- torii/vegetation_cluster: texture_urls keys = base_color, metallic, normal, roughness
- torii/ground_dressing: texture_urls keys = base_color, metallic, normal, roughness
- torii/ornament_accent: texture_urls keys = base_color, metallic, normal, roughness
- torii/column_pillar: texture_urls keys = base_color, metallic, normal, roughness
- torii/railing_segment: texture_urls keys = base_color, metallic, normal, roughness
- torii/furniture: texture_urls keys = base_color, metallic, normal, roughness
- torii/signage_banner: texture_urls keys = base_color, metallic, normal, roughness
- carioca/hero_landmark: texture_urls keys = base_color, metallic, normal, roughness
- carioca/gate_portal: texture_urls keys = base_color, metallic, normal, roughness
- carioca/light_source: texture_urls keys = base_color, metallic, normal, roughness
- carioca/vegetation_cluster: texture_urls keys = base_color, metallic, normal, roughness
- carioca/ground_dressing: texture_urls keys = base_color, metallic, normal, roughness
- carioca/ornament_accent: texture_urls keys = base_color, metallic, normal, roughness
- carioca/column_pillar: texture_urls keys = base_color, metallic, normal, roughness
- carioca/railing_segment: texture_urls keys = base_color, metallic, normal, roughness
- carioca/furniture: texture_urls keys = base_color, metallic, normal, roughness
- carioca/signage_banner: texture_urls keys = base_color, metallic, normal, roughness
- aurora/hero_landmark: texture_urls keys = base_color, metallic, normal, roughness
- aurora/gate_portal: texture_urls keys = base_color, metallic, normal, roughness
- aurora/light_source: texture_urls keys = base_color, metallic, normal, roughness
- aurora/vegetation_cluster: texture_urls keys = base_color, metallic, normal, roughness
- aurora/ground_dressing: texture_urls keys = base_color, metallic, normal, roughness
- aurora/ornament_accent: texture_urls keys = base_color, metallic, normal, roughness
- aurora/column_pillar: texture_urls keys = base_color, metallic, normal, roughness
- aurora/railing_segment: texture_urls keys = base_color, metallic, normal, roughness
- aurora/furniture: texture_urls keys = base_color, metallic, normal, roughness
- aurora/signage_banner: texture_urls keys = base_color, metallic, normal, roughness
- egeo/hero_landmark: texture_urls keys = base_color, metallic, normal, roughness
- egeo/gate_portal: texture_urls keys = base_color, metallic, normal, roughness
- egeo/light_source: texture_urls keys = base_color, metallic, normal, roughness
- egeo/vegetation_cluster: texture_urls keys = base_color, metallic, normal, roughness
- egeo/ground_dressing: texture_urls keys = base_color, metallic, normal, roughness
- egeo/ornament_accent: texture_urls keys = base_color, metallic, normal, roughness
- egeo/column_pillar: texture_urls keys = base_color, metallic, normal, roughness
- egeo/railing_segment: texture_urls keys = base_color, metallic, normal, roughness
- egeo/furniture: texture_urls keys = base_color, metallic, normal, roughness
- egeo/signage_banner: texture_urls keys = base_color, metallic, normal, roughness
- Balance readings (42) are in `run/tmp/arena-kit/gen-arena-state.json`
  and the journal; cost per task is the task's own `consumed_credits` (authoritative).
- Journal: `run/tmp/arena-kit/gen-arena-journal.txt`. Ledger: `docs/mission/arena-kit/arena-props/LEDGER.jsonl`.
  Previews: `docs/mission/arena-kit/arena-props/previews/<arena>/<slot>.png`.
- Ground textures were NOT sent to Meshy (material swatches only), per the kit standard.
- Launches were capped at 10 concurrent tasks (the concurrency proven by the Medina
  run), POSTs at 42 (40 slots + at most 2 retries), and launches halt below a 600-credit
  balance or above the 630-credit cumulative spend cap.
