# Training overhaul — direct completion

2026-09-24. User explicitly authorized root to finish directly after Flash failed.
Checkout: steam-circuit-padel-11m, branch codex/integrate-arena-11m. No commit/push.

## Delivered

- Shared eight-exercise hub on both entry routes; goals, scoring, controls, difficulty and separate bounded-run records.
- Glass recovery, net play and doubles tactics use the actual simulation; eight-attempt sessions, feedback and retry/choose/exit.
- Fixed summary route consumption, default-UI hub return, save-before-retry, focused confirmation and explicit directional neighbours.
- Shipping UI now actually shows training progress and the central summary; pause hides it. Training no longer advertises the internal huge points target as a quick match.
- Fresh controlled-contact ownership rejects AI partner credit and stale pre-contact landings. Smash completion requires an actual smash; rally completion requires human contact.

## Verification

Direct Godot scripts under `godot`, using `/Applications/Godot.app/Contents/MacOS/Godot`:

| Script | Result |
| --- | --- |
| tests/modes/drill_training_challenge_audit.gd | PASS 216/216 |
| tests/modes/return_drill_audit.gd | PASS 103/103 |
| tests/modes/drill_audit.gd | PASS 76/76 |
| tests/ui/screen_drill_audit.gd | PASS 68/68 |
| tests/ui/mode_training_screen_audit.gd | PASS 211/211 |

Challenge audit runs real seeded simulation with success/failure, bounded completion, records, no career rewards, mounted Match summary, simulated D-pad events and focused action activation. All three new challenges have successful seeded attempts; success is not guaranteed for every scripted seed.

Rendered and inspected actual hub at 1280x720 and scaled 1920x1080, plus mounted in-match summary at 1280x720 (`/tmp/training-summary-final.png`). Capture harness PASS 5/5. `git diff --check` clean.

Limits: no physical controller playtest. Some harness runs report teardown resource/ObjectDB warnings (ReplayOverlay anchor warnings also observed); functional checks pass, but this is not a claim of a clean whole-project suite or leak-free shutdown. Other chats' audio/simulation/asset changes remain untouched by root.
