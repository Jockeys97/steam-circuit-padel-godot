# Controller release and selection marker — 2026-09-17

The live sampler now follows js/main.js pollGamepadGameplay: X/Y/A priority,
latched charge variant (including RB), aim retained on release, and consumed
second taps for smash/cut volley/globo. Primary one-shots use the selected pad
instead of device-agnostic actions, preventing secondary-pad input leakage.
Keyboard reads only keyboard bindings. Secondary priming reads its own paddle;
as in the 2D core, missing secondary cut-volley/globo flags are false.

The selection halo is horizontal and fixed-size. The pointer is a downward
billboard triangle, and both markers cast no shadows. Controller help is compact
during play, with technical and double-tap combinations shown during pause.

Validation:

- node tools/controller-parity.mjs: 371 frames, all 23 input fields compared
  against the actual extracted browser functions, zero differences (primary pad).
- Godot tests/input/shot_sequences_test.gd: 133 checks passed, including both
  samplers, held/released technical shots, consumed upgrades and keyboard release.
- Godot tests/input/run_all.gd: 392 checks passed.
- Godot tests/game_slice_test.gd: 287/288 passed; remaining failure is the absent
  build/linux-x86_64/padel.pck. All 22 sections completed. The suite also reports
  resource leaks at exit; this is not a clean packaging validation.
- Full-match JS/Godot comparison, seed 12345, frozen input, one set:
  22,210 samples identical at zero tolerance; 254 events matched.
- Rendered and inspected the real Match scene on macOS/OpenGL:
  tests/input/capture_controls.gd saves /tmp/padel-controls-fixed.png.

These are automated input and simulation checks, not a physical controller
playtest of every mode, device or athlete.
