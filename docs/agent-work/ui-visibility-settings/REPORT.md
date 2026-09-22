# UI visibility settings — acceptance report

Status: accepted after Astra review in the canonical checkout `steam-circuit-padel-11m` / `codex/integrate-arena-11m`.

## Delivered

- Fourth pause tab, `UI` / `INTERFACCIA`.
- Presets: `all`, `essential`, `score_only`, `clean`.
- Independent components: `score`, `time`, `map`, `guidance`, `indicators`, `events`.
- Clean gesture restores the exact previous non-clean profile.
- Bottom-centre localized restore hint shown only during clean live play.
- Per-match state; rematch resets to `all`.
- Existing Escape pause flow, replay, touch controls, simulation and InputMap remain unchanged.

## Independent acceptance checks

- `ui_visibility_audit.gd`: `PASS 146/146`, strict gate clean, exit 0.
- `clean_mode_audit.gd`: `PASS 64/64`, strict gate clean, exit 0; one allowed static-resource shutdown line.
- `pause_audit.gd`: `PASS 228/228`, strict gate clean, exit 0.
- `git diff --check` on all bundle source/test paths: clean.

Worker evidence also records:

- `hud_audit.gd`: `PASS 172/172`.
- `court_timing_marks_test.gd`: `PASS 87/87`.
- `uir22_integration_audit.gd`: `PASS 75/75`.

## Visual evidence

Real OpenGL capture harness: `PASS 3/3`.

- `evidence/captures/ui-visibility-tab-1280x720.png`
- `evidence/captures/ui-visibility-tab-1152x648.png`
- `evidence/captures/ui-visibility-hint-1280x720.png`

The fourth tab fits at both supported frames without clipping. The clean-view hint is readable, input-transparent and remains the only informational UI on the clean frame.

## Limits

- Controller buttons are covered with injected Godot joypad events; no physical DualSense or Xbox controller was attached for this run.
- The visibility profile deliberately does not persist to the save file and resets on rematch, as specified.
- No files were staged, committed or pushed.
