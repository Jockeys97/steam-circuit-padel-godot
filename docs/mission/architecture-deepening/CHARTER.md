# Architecture deepening mission charter

## Outcome

Implement all five approved deepening candidates from the 17 September architecture review without changing game behavior or the frozen parity contract.

A player should see the same game. Maintainers should get one owner for match feedback vocabulary, arena availability, court timing marks, UI mount policy, and mixer contract reading.

## Approved test seams

These seams are fixed for this mission and satisfy the TDD gate:

- Match feedback vocabulary through its public static interface.
- Arena availability through one catalog seam used by legacy and recreated UI adapters.
- Court timing presentation through a public report and update seam, never private node names.
- Match UI mounting through the real Match scene and shipping recreated UI path.
- Mixer contract values through one reader used by both audio adapters.

Each implementation team must add or move a failing behavior test before its production change, then make that test green. Existing private-state tests may remain only when a frozen harness still requires them.

## Gates

1. Feedback vocabulary leaves the legacy HUD. Shipping callers and tests use the new module. The hidden legacy HUD no longer exists solely to expose vocabulary.
2. One arena catalog answers selection, lock, demo, and world-arena availability for both legacy and recreated UI paths.
3. Court timing marks move out of `match_controller.gd`. Their geometry, placement, verdict, and report behavior are tested through their interface.
4. Clock ownership and UI mount policy become independent. A real-match test crosses the same recreated UI seam as users.
5. Audio modules share one mixer-contract reader. Playback behavior remains in the existing adapters.
6. Integrated proof passes the scoped suites, main harness, full slice, demo slice, audio suites, UI integration suites, world-arena proof, JS audit, static GDScript checks, and a source-digest check showing frozen paths unchanged.
7. Independent review passes both the mission spec and repository standards. The integrator fixes all P0 and P1 findings and either fixes or records lower-severity findings.
8. The final commit contains only mission changes. Pre-existing untracked UID and debris files remain byte-for-byte untouched and unstaged.

## Hard limits

- Do not edit `js/**`, `scripts/**`, `godot/src/sim/**`, or `godot/project.godot`.
- Keep `run/main_scene` on `SmokeTest.tscn`.
- Do not extend parity behavior beyond the documented world arenas.
- Do not delete or clean pre-existing untracked files.
- One Godot process at a time. Use `/Applications/Godot.app/Contents/MacOS/Godot` and serial runs.
- No paid API calls. Spend cap: $0.
- Native worker launch budget: 8 implementation, integration, and review launches total.
- Retry cap: 2 retries per gate per captain. A third failure stops the gate.
- Do not commit until the independent review has passed and the final integrated proof is green.

## Organization

- Arena team owns gate 2.
- Audio team owns gate 5.
- Feedback team owns gate 1.
- Court-feedback team owns gate 3.
- Mount-policy team owns gate 4.
- Final Integration captain owns all cross-team seams, domain glossary updates, mission records, the combined proof, and the single final commit.
- Independent Review captain certifies the diff after implementation and before commit.

## Evidence contract

Every captain returns changed paths, exact test commands, exit codes, pass tallies, remaining launch budget, and any known gap. A summary without paths and tallies is not evidence. The CEO verifies the real checkout independently.

## Reporting rhythm

Write one board report after implementation and independent review. Append every dispatch, gate result, retry, integration decision, and commit handle to `LOG.md`.
