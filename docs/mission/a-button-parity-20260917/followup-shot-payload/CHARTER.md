# Preserve deferred shot requests

Owner: Astra. User approved proceeding with contact proof and scoped fix after the diagnostic report.

## Outcome and approved test seams
Prove the effect through real input sampler -> frame/fixed-step handoff -> actual ball contact with matched athlete, arena, seed and state. Preserve requested shot family and aim across zero-substep frames without restoring browser lost-input behavior. No balance, camera, UI or sim physics changes. Human feel remains Luca's verdict.

## Gates
1. Contact reproduction: matched setup, real production path, normal hold/release. Compare immediate and deferred equivalent requests plus browser contact at a consuming frame; browser dropped release is a known defect, not desired behavior. Record whether auto and drive actually differ. Test technical A and slice if needed to expose family loss, not claim every A drive changes.
2. Red then green: failing behavioral test BEFORE minimum payload preservation fix. Retain full relevant request only when a shot edge occurs. Prove no replay/double fire, no overwritten payload by later neutral samples, correct clearing on consumption/reset, and existing input/clock tests.
3. Comparator integrity: jointly missing nested fields, expected frame/value matching for known-difference scenarios, and real verdict-based negative controls fail correctly. Historical old-source evidence remains historical.
4. Independent review of patch and proof; parent bounded re-run.
5. Named integrator promotes exact reviewed patch to live checkout only if current file hash matches original baseline, preserving concurrent work; rerun relevant checks in isolated fresh exact copies. No commit/push/restart. Live game does not automatically load code edits.

## Teams and limits
Port captain is sole implementation and promotion integrator. Work in /tmp/padel-shot-payload-fix/godot and followup/port only until promotion dispatch. Copy current production sources with hashes, not stale earlier scratch. Only approved eventual production files: godot/game/match_controller.gd and a new godot/tests/input/deferred_shot_payload_test.gd; expansion needs CEO decision.
Comparator team owns earlier integration/comparator.py and test_comparator.py only plus followup/comparator docs. No Godot. Review owns followup/review only and runs after implementer returns. Flat native delegation, children cannot spawn.
Followup budget: 6 native launches maximum, including 2 Pro runs stopped on user routing correction, 0 paid API spend, no automatic routing fallback, max2 retries per gate within cap. User-corrected routing opencode-go/deepseek-v4-flash ONLY; parent openai-codex/gpt-6-astra. Token cost unknown. Two stopped launches are preserved as partial work; two Flash continuations, then Flash review and promotion if gates pass.
No installs, deletions, git mutation, credential access, reference JS edits, unrelated cleanup, live game focus or process changes. One diagnostic engine at a time, separate cache. All evidence records commands, exits, script errors, hashes. Preserve user's active game.

## Reporting
CEO owns this charter, MAP, LOG and board. Bounded child returns with exact paths and remaining launch budget; reports in Italian. Log every gate, no broad parity or hardware/feel certification.
