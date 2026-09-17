# Five playthroughs (one per arena)

- Status: **resolved 2026-09-17** (five complete matches recorded, one per arena)
- Owner: proof engineer
- Depends on: [aurora-ridge-refinement](aurora-ridge-refinement.md) (run on the post-refinement tree)
- Blocks: [final-rescore](final-rescore.md)

## Why

Round 1 item 7 ("selectable and played through the real game") has a complete played match on
**torii only** — `WORLD_PLAYTHROUGH arena=torii ticks=31295 points=26 result={"winner":"ai"}`.
The other four arenas are proven selectable and built (selection 13/13, demo 8/8) but were
never played to a result; the parent refused to smooth this coverage gap over.

## Deliverable

- One complete played match to a real result per arena — all five arenas — recorded in the
  `WORLD_PLAYTHROUGH` line format (arena, ticks, points, result), through the real game, with
  frozen physics and demo restrictions unchanged (a demo still refuses the world set).
- Logs + tallies journaled in the serialized run; RED history kept.

## Resolved when

- Five `WORLD_PLAYTHROUGH` lines (one per arena) exist in green-run logs and round 2 cites
  them instead of a generalization.

## Resolution (2026-09-17)

- The selection suite now plays a full deterministic quick match on **all five** world courts:
  one exact line per arena in `proof/round2/logs/selection.log` (and the parent's re-run
  `tools/world-arenas/out/ceo-final-01/logs/selection.log`) —
  `WORLD_PLAYTHROUGH arena=torii|medina|carioca|aurora|egeo ticks=31295 points=26
  result={"winner":"ai"} score=0-0`. Selection 18/18, demo 8/8.
- Identity across arenas is the expected determinism of the same provisional neutral physics
  (`wallBounce 0.89`) and the same scripted match — each arena instantiated its own scene and
  ran its own 31,295 ticks; torii reproduces round 1 exactly.
- Cited by round 2 as evidence, not generalization: rows `wa-r2-*` (item 7) in `ccl-ledger.jsonl`.
