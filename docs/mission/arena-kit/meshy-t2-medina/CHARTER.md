# Medina Mesh T2 pack

Date: 2026-09-18
Owner: parent session (CEO)
Tree: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`)
Not the `feat-native-world-arenas` worktree.

## Outcome

Luca can drop ten textured Medina props into the arena without running Meshy by hand.

Done means: ten GLBs at `godot/assets/arenas/medina/<slot>.glb`, each with PBR texture, generated through Meshy API with Mesh T2 plus Smart Topology. Task ids and `consumed_credits` live in a ledger. Ground texture is never uploaded.

## Out of scope

- Carioca, aurora, egeo (no new 3D)
- Torii new generation (texture-salvage only if a live task id exists)
- Engine look/feel edits, `arena_look.gd`, commits, push
- Image regen of the intake PNGs

## Frugal spend

Luca approved this use case this turn: Medina pack via Meshy API, Mesh T2, Smart Topology, textured.

Hard cap: **10 image-to-3D jobs** (the ten kit slots) plus at most **2 salvage texture jobs** if existing untextured models have live API task ids. One retry per failed slot. Abort the rest if a single job reports more than 30 credits or the key is missing.

Do not generate until recon proves: official Mesh T2 param name, Smart Topology param, texture-on-create vs texture-later, and a key present (name only, never print the secret).

If existing GUI models cannot be reached by API (expected: Workspace models are not enumerable), skip salvage and generate Medina fresh. Do not spend credits probing dead ids.

## Gates

1. **Recon.** Official docs pin Mesh T2 + Smart Topology + texture request shape. Key exists. Slot list is the kit ten. Handle: `docs/mission/arena-kit/meshy-t2-medina/RECON.md`
2. **Generate.** Ten textured GLBs on disk plus ledger with task ids and `consumed_credits`. Handle: `godot/assets/arenas/medina/*.glb` and `docs/mission/arena-kit/meshy-t2-medina/LEDGER.jsonl`
3. **Drop.** Files named to kit slots, README updated, no foreign diffs. Luca judges look. Handle: file list + sha256

## Teams

- Scout captain: Meshy API docs, pricing, Mesh T2 / Smart Topology / texture. Read-only. Evidence: RECON.md
- Inventory captain: local slots, `pull_meshy.py`, key location without printing it, any saved task ids. Read-only. Evidence: INVENTORY.md
- Pipeline captain (integrator, after recon): create, poll, download. Named later.

## Reporting

Append `LOG.md` per step. Board report after recon and after generate. Raw ids only in files.

## Retry

Max 2 retries per gate per captain. Third failure goes to the board, not a fourth attempt.
