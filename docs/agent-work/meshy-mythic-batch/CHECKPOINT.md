# Generation and runtime integration — completed

All ten tasks SUCCEEDED and downloaded. Actual total 175 credits, balance 615→440.
Five geometry candidates and five 24-joint rigs with basic walk/run companions.
30 native Godot captures completed, no script errors; see REPORT.md and PREVIEW.md.
No new POST is authorized or needed. Local runtime integration is completed:
five geometry mappings, 25 padel clips, saved wardrobe-to-match verification and
racket tests. See INTEGRATION.md for results and remaining garment limitations.

## Original resumability procedure (historical)

User approved 175-credit ceiling. Starting balance 615. Five image-to-3D jobs
submitted successfully for 150 credits; 25 remain authorized for five rigs.
Do not resubmit these jobs or delete their task records. No runtime promotion.

Resume read-only with `node scripts/meshy-mythic-batch.mjs status <athlete> model`.
Athletes: fiamma, pantera, steamer, oracolo, colosso. Their JSON records hold IDs.
After downloaded success, inspect GLB and preview before submitting that athlete's
one rig (`submit <athlete> rig`, 5 credits). Then `status <athlete> rig` downloads
model and basic running/walking companions. No other paid endpoints authorized.

Preview/audit tools already available:
- `python3 tools/character/glb_tri_count.py <GLB>`
- `godot --path godot --script res://tests/meshy_outfit_trial_capture.gd -- <absolute GLB> <absolute output prefix> [animation phase]`

Use original full 2D references; PNGs here are format conversions only. Inspect
fused rackets, hands, tails/capes and full legs. Artifacts are candidates, not
runtime-ready skins. Existing base athletes and Maestro Mythic remain unchanged.
