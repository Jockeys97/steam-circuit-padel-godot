# Critic Council Loop — charter (frozen)

loop_id: padel-port-ccl-01
round 1 opened: 2026-09-16, local macOS session
maker (this round): Hermes parent + native sub-agents + repairs landed by the mission's lanes
refiner (must be a different model/context from every critic): to be pinned per round
cost ceiling: zero paid APIs — no Meshy calls, no metered inference beyond the local/subscription lanes
max rounds: 2 (hard cap 3)

## Artifact under judgement

The Godot 3D padel port's player-facing surfaces and asset set, inside
`steam-circuit-padel-godot`, judged against the FROZEN browser reference in the
same repository (`js/`, `index.html`, `styles.css`, `assets/`).

- artifact_id: padel-port-r1
- commit at freeze: 9cca592f075f69cd88ee1e34bfe346601f32c1e6 (branch main)
- git tree hash of the Godot project (git rev-parse HEAD:godot): 81b90334c8fec66692a20ab75370487898f36f8e
- git tree hash of the frozen reference (git rev-parse HEAD:js): cf1edec26aadfcf3d4c0a3a08f3e3ec910ddc93f
- surfaces in scope: every screen the reference renders, every asset the reference loads,
  the in-match HUD and audio, the demo build's locked content, the pause/rematch flow.

## Boolean checklist (5-9 items, one claim each, gating unless marked)

1. GATING — UI surface parity: every screen the browser reference renders has a
   reachable counterpart in the port; the inventory names each one with the path that
   implements it and the grep that proves it is reachable from a scene or script.
2. GATING — Asset parity: every asset the reference actually loads (arena backdrops,
   athlete rigs and art, outfit textures, sprite sheets, audio, music data, UI art) is
   carried into the Godot project AND reachable at runtime — present on disk but
   unreferenced counts as missing.
3. GATING — Visual language parity: rendered port frames, compared side by side against
   the reference's own screens, keep the reference's typography, accent colours and
   layout; no clipped labels, no ASCII fallback for accented Italian, no mixed-language
   stat labels in any rendered screen.
4. GATING — Music is wired into the live match: the ported music module plays during a
   real match, not only in its own unit test.
5. GATING — Oracle green on a fresh clone on this Mac, demo build included: harness,
   playable slice (full and demo), saves, input, rules audits, music — each with its
   command, exit code and tally, no PASS sitting next to a SCRIPT ERROR.
6. GATING — Cross-engine match parity unregressed: the same seed and scripted input still
   produce identical tick-by-tick results between the browser reference and the Godot core.
7. GATING — Known defect list closed: every finding the second independent review raised
   is either repaired with a test that can fail, or shown false with evidence; none is
   carried silently.
8. GATING — Pause and rematch are stable: pausing then rematching does not freeze the
   simulation or leave a stale HUD.
9. SOFT — Pack integrity: an exported build carries the athlete rigs and the UI assets
   (no excluded tree inside the pack). Soft only because exporting may not be possible on
   this host; if it cannot be built, the item is reported as not-established, never passed.

Target: every GATING item passes (derived score 10.0 with 9 items; Luca's floor of 8.5
means at most one soft fail). One soft fail allowed overall.

## External oracle (decides done — never a critic's opinion)

1. The repository's own suites, run serialised through /tmp/padel-lock.sh on this Mac,
   each reported as command + exit code + tally line.
2. Rendered captures of the port's own surfaces, indexed with dimensions and distinct
   colour counts so a blank frame cannot pass as evidence.
3. Cross-engine parity driver output (same seed, scripted input, tick digests).
4. A machine-checkable asset reachability diff: every reference asset path mapped to a
   path inside godot/ and a grep proving some scene or script references it.

## Stop rules (first match wins, logged as stop_reason)

1. retired-under-5 — a surviving artifact scores below half the checklist: redesign, do not refine.
2. target-met — all gating items pass: ship the best artifact.
3. flattening — round-over-round gain under one point equivalent, or no item flips.
4. rounds-exhausted — round 2 ends with the target unmet: ship the best and name the biggest gap.
5. abort — artifact path or hash missing, maker detected as judge, cost ceiling breached,
   identical verdict lines across critics, or a human taste gate (feel and camera framing)
   reached — escalate immediately.

## Ledger

Append-only JSONL at `docs/wayfinder/evidence/ccl-ledger.jsonl`, one row per artifact per
round, with the required keys: loop_id, round, round_kind, artifact_id, artifact_path,
artifact_hash, critics with id/lens/model/passes, pass_count, cost_usd.
