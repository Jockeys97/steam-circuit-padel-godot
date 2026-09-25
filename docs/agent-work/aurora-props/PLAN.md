# Banco Aurora: environmental props

## Objective

Make the Icelandic court feel inhabited and grounded from default, wide, and playable cameras: a few snow-capped basalt groups beside the stands, two geothermal pools with restrained slow steam, and a low side/background walkway with marker lights.

## Contract

- Build only for `aurora`, in the existing `OutdoorLandscape` presentation layer.
- Keep every prop outside the playable enclosure and spectator clearance. Preserve court, cameras, ball visibility, scoring, and other arena builds.
- No collisions, real lights, shadow casters, large GLB duplication, paid generation, or per-frame gameplay script. Bounded steam only.
- Keep the existing landscape node budget (<180 children) and preserve the uncommitted Aurora grounding changes already in this checkout.

## One implementation bundle

The Flash writer owns arena-only construction and focused tests in `outdoor_landscape.gd`, optionally `aurora_details.gd`, and the landscape test files. Astra reviews the actual diff and real 1280x720 default/wide/playable captures. The capture harness already fails its glass-visibility check on the baseline; that failure is recorded separately from the new props.

## Acceptance

Focused headless test passes, all three images show recognizable details without obscuring the court, added geometry is deterministic and shadow/collision/light-free, and unrelated arena logic remains unchanged. No commit or push in this task.
