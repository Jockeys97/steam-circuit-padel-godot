# Training overhaul coordinator checkpoint

## Current status — 2026-09-24

User authorized direct root completion. Implementation and focused acceptance complete;
see ACCEPTANCE.md for results and remaining test-environment limits. Historical blocked
state and findings below are retained as provenance and superseded by this status.
No commit or push. Flash was not restarted.

- User authorized retry and implementation of the training redesign.
- Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`, branch `codex/integrate-arena-11m`, starting HEAD `d29fd4bbc95a01c48950d38f6dfe219eb34fd1b8`.
- Native worker `/root/training_overhaul`, thread `01a0d03a-c3b8-7a41-9185-5cc598635c92`, role `astra_flash_builder` owns implementation + focused validation. No other training writer.
- Worker baseline: `/tmp/training-overhaul-baseline.sKaAPq/`; includes pre-existing 15-line audio edit in match_controller.gd and pre-touch files. Preserve all unrelated dirty work.
- Routing: skill doctor static check passed; its unauthenticated catalog GET returned 401. Router's existing caller-auth helper returned authenticated HTTP 200 with Flash route. Actual router activity confirmed successful subagent responses from `opencode-go/deepseek-v4.1-flash`, and parent `gpt-6-astra`. No configuration changed or extra inference probe run.
- Latest worker milestone (2026-09-23 22:33 UTC): shared hub rendered on both entry routes, bounded runs and three real summary buttons implemented; parse checks clean. Reported drill audit 76/76 and return audit 103/103. Root inspected 1280x720 hub without clipping; final capture must reflect corrected LS aim instructions.
- Independent root return probe: six seeds each for drive/slice/lob now recognize valid returns intercepted by an opponent volley (18/18). Earlier failure was a net-crossing/AI-volley same-step observation bug. Worker added the seed1234 regression permanently.
- Remaining worker bundle: actual seeded positive/negative tests for glass/net/doubles; both hub navigation audits; final summary capture and diff check. Revised handoff target approximately 22:53 UTC, with checkpoint after challenge audit. No new scope.
- Root acceptance pending: inspect full changed patch against baseline; inspect actual seeded success/failure tests, run summary/persistence/retry flow, IT/EN layout/controller evidence for both routes, and rendered screenshot. Do not duplicate worker validation absent a specific concern.
- Execution stopped: native Flash child errored with provider HTTP 400 (`opencode rejected ... deepseek-v4.1-flash`) before final handoff; root called interrupt_agent. Do not automatically restart or switch provider. Preserve partial implementation pending user direction.
- Final inspected logs: drill 76/76, return 103/103, screen 68/68, ported training UI 211/211. Extended challenge/in-match integration is **FAIL 195/201**, not the earlier 182/182 subset. First mounted run fails to reach summary (0 attempts), plus exit-run assertions fail. Actual standalone seeded challenge successes: glass 2/3, net 1/3, doubles 2/3. `git diff --check` clean. No physical-pad validation or final summary capture.
- Concrete root review findings to address in one resumed correction bundle:
  1. `match_controller.gd:1550` consumes `_training_choice` and only dispatches `choose`; `exit` is dropped, and `training_leave()` can no longer inspect the consumed choice. Pass the captured choice explicitly and test real frame/scene dispatch, not only `take_training_choice()`.
  2. Default routed choose returns Main.tscn; verify it mounts the training hub rather than main menu. Current Config helper stores only scene path, no screen target.
  3. Summary pad path hardwires hit->retry regardless of focused button; no summary initial focus/pad navigation integration is visible. Test real input-event activation and all three actions, including mouse, after release grace.
  4. `training_retry()` resets before persisting if called from button before summary tick. Persist before resetting and test saved record after immediate retry.
  5. `drill_session._observe_after` assigns `attempt_contact_fresh_side` from team unconditionally; `_step_return` therefore still credits uncontrolled teammate contact despite comments claiming otherwise. Gate by fresh controlled paddle; add AI-partner negative regression.
  6. Precision/glass/net grade latched `attempt_bounced_ai`, which may predate the human contact; bind landing to the actual controlled-shot sequence, reject stale/AI-only marks. Existing `attempt_landed_ai_after_contact` also identifies side rather than last controlled hitter.
- No gameplay implementation accepted yet. No commits or pushes authorized for this task. Latest UI and core edits remain in the checkout; user should not be told this is complete.
