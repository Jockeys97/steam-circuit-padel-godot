# Astra prompting scan — synthesis (2026-09-17)

Target: `astra-plan-prompt.md`, the plan-creation handoff given to GPT-6 Astra for the
world-arena mission. Scan type: standard comparative, 3 parallel read-only scouts (skill
floor is 2). Parent cross-checked the decisive claims against the primary sources after the
scouts returned.

## Why this ran

Luca flagged v1 of the prompt as not clearly optimized for Astra's documented behavior. The
mission stays as-is; this scan reshapes the prompt to what OpenAI documents and what
practitioners corroborate.

## Method, lanes, identity

| Lane | Scope | Report (sha256, first 16) |
|---|---|---|
| A — official | OpenAI primary sources only (developers.openai.com, openai.com, cdn.openai.com, cookbook, platform); 9 API calls, 130 s | `scan/scout-a-official.md` `4f5fc0a483a5b2d5` |
| B — practitioner | guides/blogs/forums 2026 plus the two locally cached third-party guides; 10 calls, 164 s | `scan/scout-b-practitioner.md` `f4d84ad392a618d0` |
| C — local + verify | profile cache/logs/Desktop docs mining, then live re-verification of the top claims; 11 calls, 344 s | `scan/scout-c-local-verify.md` `a26c1a2a30e776e7` |

Identity: native `delegate_task` batch `deleg_f800c015`, children on the dev-work cheap lane
(reported as `deepseek-flash`), no provider changes, no spend. Deliberately three different
angles (official / practitioner / local verification) rather than three same-angle scouts.

Parent cross-checks (after the scouts): re-fetched the canonical model guide and the
2026-09-11 blog, matched the quotes below verbatim; confirmed the context-cache split on
local disk (`context_length_cache.yaml`: `gpt-6-astra@...codex: 272000`).

## Matrix — what the sources say, by topic

| Topic | Official | Practitioner | Local / cross-check |
|---|---|---|---|
| Autonomy and stalling | Astra "is more likely to ask the user a question when additional input could materially change the result. This can cause it to stop when the user may expect it to make reasonable assumptions and persist." Remedy text: "bias towards action and carry the user's intended task to completion"; "The user should be approving a concrete, reviewable result" (approval last, not first). | An autonomy block appears in every framework found; several 2026 guides recycle one OpenAI-derived framing (weak independence). | The 2026-09-07 prior scan matches; "proceed on implied authorization" is a paraphrase, not official wording. Corrected in v2. |
| Instruction priority | "The user's instructions take precedence over guidelines provided in a skill..."; audit skills and AGENTS.md; Astra is "more sensitive to instructions contained in skills and other files, such as AGENTS.md". | The single most-repeated fix for stalls; add a meta-debug phrasing that names the file which caused a stop. | v1 had no priority clause. v2 adds one. |
| Completion and stop | "Define completion before starting"; stop-for-review language "pulls the model toward an earlier stopping point"; "Do not write tests for reversible, low-impact changes that mirror the implementation." | Two-state stop contracts: success-on-evidence plus blocked-on-conditions (blocker, attempts, evidence, smallest unblocking input). | The Sep 11 blog postdates the local scan; verified live today. |
| Delegation | "The model may delegate less often than desired for your workflow. Specify when and how much it should use subagents for parallel work." | Explicit triggers, task packets, one reconciliation owner; never delegate tightly coupled edits. | DemonPet run: pinned same-identity Astra workers both exited 1; same-family workers cannot serve as independent critics; cross-family routes are xAI and opencode-go. |
| Reasoning effort | low/medium/high/xhigh/max, no `none`; mid-conversation change via `configuration_update` is cache-preserving; `high` fits hard reasoning, debugging, deep planning. | High effort burns subscription allowance faster (single source). | Local: the Codex subscription lane caches 272K context for gpt-6-astra against the documented 1.05M API window. |
| Tools and API | Tool calling requires the Responses API; `temperature`/`top_p` unsupported; async tool calling, mid-turn steering (WebSocket) and background mode exist for long runs. | — | — |
| Prompt shape | Five behaviors to prompt explicitly, plus the (pre-Astra) suggested structure Role / Personality / Goal / Success criteria / Constraints / Tools / Output / Stop rules; implementation-plan checklist: requirements, named files, state transitions or data flow, validation checks, failure behavior, privacy or security, open questions. | Block style GOAL / CONTEXT / PRIORITY / AUTONOMY / DELEGATION / OUTPUT / VERIFICATION / STOP; compact variant = success criteria + discretion + priority + stopping point. | v1 was close in shape; it lacked priority, completion, delegation and blocked-stop sections. |

## Contradictions and stale claims

- 272K vs 1.05M context: Hermes' cached context length for `gpt-6-astra@codex` is 272,000
  (subscription lane); the API documents 1,050,000. Budget plan-session context against 272K.
  Unresolved whether the backend truly caps there.
- "Proceed on implied authorization": a paraphrase from a prior session, not OpenAI text. Do
  not quote it as official.
- Several secondary guides recycle one OpenAI-derived framing; their agreement is weak
  evidence, not independent corroboration.
- X/Twitter search was degraded (no citable posts); forum findings are single-user anecdotes.

## Unverified / gaps

- No Astra-specific long-context prompting guidance and no Astra cookbook recipe found.
- Default reasoning effort for gpt-6-astra: undocumented in the sources found.
- System-card edge claims (CoT monitorability) confirmed only via search excerpts, no clean fetch.
- Vendor-reported numbers (scope-violation percentages) are unverified.

## Ranked recommendations, and where each landed in v2

1. Explicit instruction-priority clause with a conflict protocol. → "Instruction priority"
2. Official-shape autonomy grant (infer scope, bias to action, approval last) and a
   no-stall-questions rule. → "Autonomy"
3. Completion defined inside the prompt; plan plus tickets is the finish line; no early stop
   at "proposed approach". → "Mission and completion"
4. Delegation triggers, because Astra under-delegates by default. → "Delegation"
5. Two-state stop contract; blocked lanes get recorded, not stalled. → "Blocked-stop contract"
6. Kept intact: FIELD LAW, the inspect-first list, evidence-resolved decisions, and the
   regenerable-handle verification rule (already aligned with documented best practice).
7. Minimality and test-calibration lines against over-engineering and over-testing.
   → "Constraints" and "Verification and evidence"
8. Output discipline: lead with the outcome, short chat summary, artifacts carry the detail.
   → "Output and style"

## v1 to v2 changelog

- Added: instruction priority, autonomy, completion contract, delegation, blocked-stop,
  output discipline; minimality and test-calibration lines.
- Reframed the question block as evidence-resolved decisions (still never asked of the user).
- FIELD LAW text unchanged, by Luca's explicit requirement.
- v1 preserved verbatim as `astra-plan-prompt-v1.md`.

## Launch-time checks (for the run itself, not the prompt)

- Launch effort `high` or `xhigh`; keep the session inside 272K context on the subscription lane.
- Any implementation-phase verifier must be cross-family; same-identity Astra workers fail as critics.
- Prior Astra artifacts worth keeping (full paths in `scan/scout-c-local-verify.md` section 4):
  the 2026-09-07 prompt scan and the goal prompt built from it.
