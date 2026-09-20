# Jev post-match coach

## Objective and scope
Add an optional Italian-first coach to the Godot result screen, using actual match
statistics to select a bounded training recommendation. Work only in this checkout,
branch `codex/integrate-arena-11m`. Preserve all pre-existing edits. No gameplay,
physics, score, AI opponent, menu redesign, commits, deployment, or asset changes.

## Architecture and contracts
- Existing `ResultScreen.payload_from_state` is the source of match statistics.
  Inspect what is actually measured; never infer missing shot/position/error-cause
  telemetry or represent team aggregates as individual-player measurements.
- A small pure coach adapter normalizes an allowlisted stats snapshot and constructs
  a narrow Choice question with supported coaching categories and `insufficient_data`.
  Code owns localized advice, evidence numbers, and an existing valid drill mapping.
- A separate Node standard-library loopback service owns `TYPESAFE_API_KEY` from its
  environment. Do not embed credentials or read secret files from Godot. Bind only
  127.0.0.1; accept only bounded validated POST JSON on a fixed coach path; reject
  browser Origin requests and non-loopback Host headers; no CORS. Fixed upstream
  https://api.typesafe.ai/v1/systemone, jev-latest, bounded timeout/response size,
  no redirects or automatic retries. Reject invalid/nonfinite stats and unexpected
  fields. Never log secrets, raw upstream errors, or sensitive payloads.
- Godot accesses only this loopback bridge asynchronously. Explicit user action
  `Analizza con Jev` discloses aggregate stats sent to TypeSafe. No automatic calls
  on render/captures. Loading/offline/insufficient-data/invalid-response states,
  no blocked navigation, cancel/ignore stale replies on exit/re-entry, and reuse
  completed analysis within the same result screen session.
- Validate Choice ID, type, confidence and distribution before presentation; a
  documented conservative provisional confidence gate yields an uncertain result.
  Advice must not overclaim evidence. Only send sufficient evidence for candidates
  that can be supported by available measured stats.
- Add a recommendation button that navigates through the existing drill flow without
  overwriting a pending career/tournament continuation. If direct drill entry is unsafe,
  show a named existing exercise and use a safe existing training-screen route.
- Preserve result save/read-only behavior, rematch/menu actions, focus/navigation and
  existing locale conventions. Offline must be a truthful unavailable state, never
  falsely labeled Jev analysis. Public distribution needs a future authenticated backend;
  this local bridge is explicitly a development integration, not a deployed service.

## One implementation phase
Flash owns discovery, baseline capture of touched dirty files, implementation,
targeted tests and routine UI validation. Allowed scope: new coach modules under
godot/src/, ResultScreen.gd/tscn, relevant locale entries, minimal result/drill routing
glue if needed, scripts/coach/, focused godot/tests/ tests, and feature docs. Avoid
dirty ScreenShell, assets and unrelated changes. Capture baselines outside repository
before edits and provide incremental diff/report paths. Main agent owns this plan.

## Acceptance
1. Actual completed-match payload reaches coach without invented metrics.
2. Known valid Jev response selects localized advice with actual supporting numbers
   and an existing exercise; low confidence/no evidence yields restrained UI.
3. Network errors, malformed input/output, double clicks and late replies are safe.
4. Bridge security/input/timeout tests pass with a fake upstream; no paid smoke tests.
5. Godot targeted coach and result/navigation regression tests pass; provide visible
   layout evidence when feasible. State clearly what was and was not live-tested.
6. Document exact local startup/test commands and production boundary. No automatic
   paid API calls, no deployment. User can opt in via the analysis button after setup.

## Routing and status
Root model is GPT-6 per active session instruction; static user config default differs
and is not the current UI override. Doctor reports static-ready for native
astra_flash_builder / opencode-go/deepseek-v4.1-flash, inference not yet verified.
Status: implementation accepted after one consolidated correction cycle. Reviewed
the incremental ResultScreen diff against the saved pre-edit file, coach modules,
bridge validation/lifecycle, integration probe and refreshed layout evidence.
Targeted tests passed: bridge 123, real Godot-to-bridge integration 27, adapter 146,
client 79, result coach 111; result/drill/router/demo regressions passed.
No live TypeSafe inference was performed. Model quality and production hosting are
not validated by fixture tests. The bridge must be started locally with its key in
the environment. Provider inference routing metadata was unavailable: the native
Flash role was used, but upstream routing remains independently unverified.
