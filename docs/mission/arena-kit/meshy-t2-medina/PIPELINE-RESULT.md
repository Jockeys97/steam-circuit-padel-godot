# Medina Mesh T2 pack — PIPELINE RESULT

Date: 2026-09-18T22:17:02Z · Pipeline captain · Repo: `steam-circuit-padel-godot` (primary `main`)
Brief: `docs/mission/arena-kit/meshy-t2-medina/PIPELINE-BRIEF.md` · Script: `tools/arena-kit/gen_medina_t2.py`

## What generated

Ten textured Medina arena props were generated through the Meshy Image-to-3D API exactly as the
brief specifies: Mesh T2 + Smart Topology (`model_type: "smart-topology"`, `ai_model: "meshy-t2"`),
texture on the create call (`should_texture: true`, `enable_pbr: true`, `texture_resolution: "2k"`),
triangle output at `target_polycount: 4000`, `target_formats: ["glb"]`. Each intake PNG
(`meshy/arenas/medina/<slot>.png`, 1024×1024) was sent as a base64 data URI. GLBs were downloaded
immediately on `SUCCEEDED` (signed URLs expire), with the task thumbnail saved as the slot preview.

| slot | task_id | status | credits | triangles | GLB bytes | sha256 (12) | preview |
|---|---|---|---|---|---|---|---|
| hero_landmark | 01a0b696-cbf4-7753-9c52-0185afe65486 | SUCCEEDED | 15 | 4045 | 5482512 | 0cfde94733f4 | yes |
| gate_portal | 01a0b696-da14-75f9-a2ff-be9ba4f20cc1 | SUCCEEDED | 15 | 4120 | 5030012 | 5889c21a55ae | yes |
| light_source | 01a0b696-e9a2-76fe-849d-5422f55ea4f7 | SUCCEEDED | 15 | 3981 | 5283896 | 09961843d49e | yes |
| vegetation_cluster | 01a0b696-f7de-7499-a451-9284c9269ce4 | SUCCEEDED | 15 | 4226 | 4209792 | 8502b906a899 | yes |
| ground_dressing | 01a0b697-0724-7043-871f-006cfd9f6fd0 | SUCCEEDED | 15 | 4432 | 4844692 | 22b5d959a56a | yes |
| ornament_accent | 01a0b697-15e2-7039-9244-9e0bad3f79ec | SUCCEEDED | 15 | 4301 | 5489412 | 1888f75dede1 | yes |
| column_pillar | 01a0b697-25ae-761a-9933-9213d08c6ed3 | SUCCEEDED | 15 | 4280 | 5767176 | ad498f6ad1aa | yes |
| railing_segment | 01a0b697-3373-7077-b6d3-7ff7611d9f3e | SUCCEEDED | 15 | 4171 | 2795884 | 525abb4d02b1 | yes |
| furniture | 01a0b697-4217-7077-872f-1eaac4696fe4 | SUCCEEDED | 15 | 4227 | 5415508 | 66f7168ac618 | yes |
| signage_banner | 01a0b697-5130-716a-8a03-6a3b4f1b0762 | SUCCEEDED | 15 | 4182 | 5090896 | 155815fbe564 | yes |

- Slots succeeded: 10 of 10
- Credits consumed (ledger sum of `consumed_credits`): 150
- Balance before: 2447 · after: 2297 · remaining: 2297

## Failures and retries

No failed slots — all ten landed.

## Gates (as specified in the brief)

| Gate | Threshold | Result |
|---|---|---|
| GLBs on disk | ten files at `godot/assets/arenas/medina/<slot>.glb`, each over 50 KB | PASS |
| Texture present | each GLB has a material with a base-colour image, and `enable_pbr` was accepted | PASS |
| Triangles | per-slot count recorded in the ledger | PASS |
| Ledger | ten lines with task_id and consumed_credits, no missing slot | PASS |
| Balance | remaining balance recorded in PIPELINE-RESULT.md | PASS |
| Tree scope | `git status --short` shows only Medina GLBs, the new script, and the mission docs | see raw output below |

Raw tree scope (`git status --short`):

```
?? docs/mission/arena-kit/meshy-t2-medina/
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
?? tools/arena-kit/gen_medina_t2.py
```

## Disk checks (live, at report time)

hero_landmark: 5482512 bytes, 4045 tris, base-colour texture: yes, 1 material(s), 3 image(s)
gate_portal: 5030012 bytes, 4120 tris, base-colour texture: yes, 1 material(s), 3 image(s)
light_source: 5283896 bytes, 3981 tris, base-colour texture: yes, 1 material(s), 3 image(s)
vegetation_cluster: 4209792 bytes, 4226 tris, base-colour texture: yes, 1 material(s), 3 image(s)
ground_dressing: 4844692 bytes, 4432 tris, base-colour texture: yes, 1 material(s), 3 image(s)
ornament_accent: 5489412 bytes, 4301 tris, base-colour texture: yes, 1 material(s), 3 image(s)
column_pillar: 5767176 bytes, 4280 tris, base-colour texture: yes, 1 material(s), 3 image(s)
railing_segment: 2795884 bytes, 4171 tris, base-colour texture: yes, 1 material(s), 3 image(s)
furniture: 5415508 bytes, 4227 tris, base-colour texture: yes, 1 material(s), 3 image(s)
signage_banner: 5090896 bytes, 4182 tris, base-colour texture: yes, 1 material(s), 3 image(s)

## Method notes

- Triangle counts: measured with `tools/character/glb_tri_count.py` when it ran; otherwise an
  in-script GLB JSON parse. Method used per slot is in `run/tmp/arena-kit/medina-t2-state.json`
  (`tri_method`) and in the journal.
- `enable_pbr` acceptance, straight from each task's `texture_urls`:
- hero_landmark: texture_urls keys = base_color, metallic, normal, roughness
- gate_portal: texture_urls keys = base_color, metallic, normal, roughness
- light_source: texture_urls keys = base_color, metallic, normal, roughness
- vegetation_cluster: texture_urls keys = base_color, metallic, normal, roughness
- ground_dressing: texture_urls keys = base_color, metallic, normal, roughness
- ornament_accent: texture_urls keys = base_color, metallic, normal, roughness
- column_pillar: texture_urls keys = base_color, metallic, normal, roughness
- railing_segment: texture_urls keys = base_color, metallic, normal, roughness
- furniture: texture_urls keys = base_color, metallic, normal, roughness
- signage_banner: texture_urls keys = base_color, metallic, normal, roughness
- Balance readings (12) are in `run/tmp/arena-kit/medina-t2-state.json`
  and the journal; cost per task is the task's own `consumed_credits` (authoritative per RECON).
- Journal: `run/tmp/arena-kit/medina-t2-journal.txt`. Ledger: `docs/mission/arena-kit/meshy-t2-medina/LEDGER.jsonl`.
  Previews: `docs/mission/arena-kit/meshy-t2-medina/previews/<slot>.png`.
- `ground_texture` was NOT sent to Meshy (material swatch only), per the kit standard.
