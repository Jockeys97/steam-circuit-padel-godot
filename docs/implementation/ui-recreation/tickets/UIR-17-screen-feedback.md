---
id: UIR-17
title: FeedbackScreen 1:1 (screen-feedback, queue + failure ladder)
slug: screen-feedback
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-22]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-17-screen-feedback.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [default, counted, diagnostics-open, manual-fallback, sent]
---

# UIR-17: FeedbackScreen 1:1 (screen-feedback, queue + failure ladder)

## Worker brief (copy-paste)

> Recreate `screen-feedback` (`index.html:310-364`) as `godot/src/ui/screens/FeedbackScreen.gd/.tscn`, registered as `feedback`, back target `menu`. Six topics (bug, balance, controls, performance, idea, other), the message text area with a live `0 / 1200` counter and `1200` cap, optional bounded contact field, the diagnostics disclosure showing the exact payload that would be attached, the attach toggle, and the action row: send, copy, plus the Steam/Discord button that stays hidden while both URLs are null. Submission ALWAYS queues locally before any delivery attempt; endpoint success marks sent; offline/rejected/no-endpoint states offer the mail/copy/manual fallback WITHOUT claiming delivery; the manual fallback shows selectable text. Text entry uses the physical keyboard; gamepad text entry goes through the existing OSK model (visual grid is UIR-26, blocked on the product decision). Do not invent a network path.

## Why this exists

The reference's feedback screen is a queue-first design with an escalation ladder (`js/ui.js:244-404`: `loadFeedbackQueue`, `feedbackDiagnostics:270`, `queueFeedback:316`, `markFeedbackSent:336`, `feedbackMailto:387`, `feedbackAsText:395`) audited by `scripts/feedback-audit.mjs`. The port has no feedback screen yet; the save contract can store the queue (`SaveStore.write_feedback:133`, `read_group`). Delivery is deliberately NOT invented: the port's own lane must expose whatever endpoint configuration exists, and the screen must mirror the reference's "never claim delivery you cannot prove" ladder.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-04 landed; UIR-05 landed (OSK model path).

## Read allowlist

- `index.html:310-364` (topics, fields, details, actions, manual fallback block)
- `styles.css`: `.feedback`, `.feedback-topics` (+ the 560px two-column rule `:3436` or nearby), `.feedback__text`, `.feedback__count`, `.feedback__input`, `.feedback__attach`, `.feedback__details`, `.feedback__diag`, `.feedback__manual`, `.feedback__note`, `.feedback__status`
- `js/ui.js:244-404` (queue + diagnostics + mailto + text), `js/main.js` feedback form wiring (submit, copy, steam button, manual reveal), `scripts/feedback-audit.mjs` (the executable spec; port its claims under its name where the port can express them)
- i18n keys: `feedbackTitle`, `feedbackSub`, `feedbackTopic`, `fbTopicBug`, `fbTopicBalance`, `fbTopicControls`, `fbTopicPerformance`, `fbTopicIdea`, `fbTopicOther`, `feedbackMessage`, `feedbackPlaceholder`, `feedbackContact`, `feedbackContactHint`, `feedbackAttach`, `feedbackWhatIsAttached`, `feedbackSend`, `feedbackCopy`, `feedbackSteam`, `feedbackManualTitle`, and the status/note keys for queued/sent/fallback states (locate each; do not invent)
- `godot/src/save/save_store.gd` (`write_feedback`, `read_group`), `godot/game/match_config.gd:81-85` (`save_store()`), `godot/src/input/osk.gd` + `godot/src/input/menu_nav.gd:148-231` (OSK wiring)

## Write allowlist (you own these)

- `godot/src/ui/screens/FeedbackScreen.gd`, `godot/src/ui/screens/FeedbackScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_feedback_audit.gd`, `godot/tests/ui/screen_feedback_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-17-screen-feedback.log`

No other writes.

## Behavior rules (each becomes an audit assertion)

- Six topics; the segmented control renders three per row normally, two per row at the small size (560px rule; approximate at 1024x600 if needed and record the deviation).
- Empty submission rejected and focus moves to the message field.
- Counter tracks `0 / 1200` to `1200 / 1200`; input stops at 1200 (the reference `maxlength` semantics: cap, not error).
- Contact optional, bounded (120 chars in the markup).
- Diagnostics disclosure shows the exact payload before attachment; the attach toggle controls inclusion.
- Submit: queue locally FIRST (assert the queue file/group written before any delivery attempt), then attempt delivery IF a deliverable endpoint exists in this build; mark sent only on success.
- Delivery backend status in this port: NONE configured today (no network endpoint exists; `run.sh` documents no network assumptions). The audit proves the queue-first ordering and the failure ladder against the seam's failure path. A `sent` state is reachable only through the seam's own success path supplied by the test double, and the evidence file labels that run as a simulated seam response. No audit makes a network call, and no evidence file implies one happened.
- No endpoint / failure: offer mail/copy/manual fallback; the status text must not claim delivery; the manual fallback reveals selectable text (a read-only text area).
- Steam/Discord button hidden while both URLs are null (configurable later through the same seam; default null here and recorded).
- Gamepad: confirming a text field with a pad opens the OSK model for that field; typed characters land in the field; back closes the OSK and refocuses the field. Assert via the model API, not a visual grid (UIR-26 blocked-external).
- Feedback diagnostics payload: reuse the port's existing diagnostics data if a lane already publishes it (search `feedbackDiagnostics` ports; if none, build the payload from data that exists: build label, version, seed if a match context is present, platform; record every field in the log).

## Microsteps

1. Key/field table first, including the failure-ladder state list.
2. Static tree per markup.
3. Queue-first submit path over `SaveStore`; sent marking via the same public API style as `markFeedbackSent` semantics.
4. Fallback ladder UI (mailto/text/manual) with honest status strings (existing ids).
5. OSK model wiring via `menu_nav.set_osk_targets`.
6. `screen_feedback_audit.gd`: topics render; empty reject; counter bounds; diagnostics payload exact-shape check; queue-before-send ordering; sent marking; failure ladder states (simulated by making the endpoint seam report failure); manual reveal; Steam button hidden; OSK open/type/close; language flip; capture states.
7. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_feedback_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-17-screen-feedback.log`; hand-back names: the endpoint seam status (exists / none configured), the diagnostics field list, the OSK entry proof line, and the explicit note that the OSK visual grid is UIR-26's, gated by `docs/wayfinder/tickets/product-scope-and-platforms.md`.

## Definition of Done

- [ ] All behavior rules asserted; queue-first proven by ordering in the audit; failure ladder honest; zero literals; audit green.
- [ ] No network endpoint invented; delivery path documented as "none configured" when absent; any `sent`-state run labeled as reaching the seam through the test double, never as a real delivery.
- [ ] OSK model wired; visual grid explicitly out of scope with its blocker ticket named.
- [ ] Hand-back names command and tally.

## Failure and recovery

- No queue storage path in the save contract for feedback: `SaveStore.write_feedback` exists; use it. If the schema disagrees with the reference's fields, record the mapping; do not add a second store.
- Clipboard: Godot's OS clipboard works on macOS (`DisplayServer.clipboard_set`); use it for the copy action; if it fails in headless audits, the audit simulates the fallback ladder instead and says so.

## Traces

`index.html:310-364`, `js/ui.js:244-404`, `scripts/feedback-audit.mjs`, `godot/game/run.sh` header (no network assumptions); scout T07 acceptance list.

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_feedback_audit.gd` — **PASS 119/119**, exit 0, 0 `SCRIPT ERROR` line(s) (0.4s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_feedback_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
