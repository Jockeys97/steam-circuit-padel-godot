# Full game slice audit fixes — 2026-09-24

Direct completion, as authorized by the user. Branch: codex/integrate-arena-11m.
Existing unrelated timing-presentation edits in game_slice_test.gd were preserved.

- Training reachability counts the eight exercises plus difficulty/start controls; the HUD check verifies the actual translated miss diagnosis rather than the obsolete LIVE label.
- Wardrobe checks compare all court roles with saved/unlocked equipped outfits.
- Tournament checks inspect visible child labels in the active language, not the now-empty Button.text.
- Locale checks require matching nonempty key sets, not an obsolete fixed count.
- Audio checks branch on the active OST/legacy engine and verify result-context playback.
- Arena material audit validates the workshop shader/tint separately from standard material colours. The original null cast no longer aborts cleanup or skips later assertions.
- Missing Linux export is an explicit SKIP in a source checkout. Run with `-- --require-export` for the mandatory release-pack gate; no pack was generated or validated here.
- Soundtrack manager teardown kills pending fades, stops both players and releases streams. Tests allow 100ms for asynchronous audio-thread disposal before measuring/quitting; the memory ceiling remains unchanged.

Validation: Godot headless verbose `res://tests/game_slice_test.gd` exited 0, PASS 338/338, all 23 sections complete, no leaked-instance/resource errors in the final log (`/tmp/game-slice-final.log`). Assertions increased because the arena audit now reaches its end. The export-content check is skipped, not counted as passed. Existing import/anchor warnings remain unrelated to these assertions.

`res://tests/soundtrack_manager_test.gd`: 78 checks, zero failures; no leaked-instance warnings after audio-thread drain (`/tmp/soundtrack-drain.log`). `git diff --check` clean. No commit/push performed.
