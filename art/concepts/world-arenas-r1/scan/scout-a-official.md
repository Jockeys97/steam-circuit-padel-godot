# Scout Lane A — How OpenAI OFFICIALLY says to prompt GPT-6 Astra (`gpt-6-astra`)

**Research date:** 2026-09-17 (CEST)
**Method:** read-only web research via `web_search` / `web_extract`, primary sources only: `developers.openai.com` (+`/cookbook`), `openai.com`, `deploymentsafety.openai.com` (official OpenAI deployment-safety subdomain hosting the system card), `cdn.openai.com` referenced inside those pages. ~24 page-fetch attempts; ~20 distinct official pages successfully retrieved; 2 fetch attempts failed/substituted (recorded below).
**Rules honored:** every claim below carries an exact URL, a page date (or "living page, retrieved 2026-09-17" when the page shows no date), and a short verbatim quote. Nothing is quoted that was not returned by an actual fetch/search against the live pages. Items I could not verify are listed in §9.

**Mission context for this scout:** a "plan-creation" handoff prompt for GPT-6 Astra acting as lead orchestrator over a 3D game repo with cheap subagent workers (implementation plan + dependency-linked tickets for five new arenas). Section §8 maps findings to that use case.

---

## 1. The canonical Astra prompting page (start here)

The single most important official page is OpenAI's model guidance for Astra ("Using GPT-6 Astra", tab of the "Model guidance" page). It contains the five documented behavior patterns and OpenAI's own copy-ready prompts for each.

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 1.1 | The five documented Astra prompt-behavior priorities are: initiative & follow-through, instruction following, personality & writing style, subagent delegation, testing & verification | https://developers.openai.com/api/docs/guides/latest-model | Living page; retrieved 2026-09-17 (no date shown) | "* Initiative and follow-through … * Instruction following … * Personality and writing style … * Subagent delegation … * Testing and verification" |
| 1.2 | Astra is OpenAI's "most intelligent model yet", built for multistep workflows across code, browsers, professional software; "most aligned model yet" | same | same | "GPT-6 Astra is our most intelligent model yet, with state-of-the-art performance in computer use, browsing, software engineering, science, and professional work." / "GPT-6 Astra is also our most aligned model yet." |
| 1.3 | Astra fills routine gaps from context and asks focused questions only "when the answer could change the outcome" | same | same | "When instructions leave room for interpretation, it uses the context it has to fill in routine gaps and asks focused questions when the answer could change the outcome." |
| 1.4 | Model ID usage: set `model` to `gpt-6-astra` in a Responses API request | same | same | "To build with Astra, set `model` to `gpt-6-astra` in a Responses API request." |
| 1.5 | Three new controls for long-running work: async tool calling, mid-turn steering, change reasoning effort mid-conversation (cache-preserving) | same | same | "**Async tool calling:** GPT-6 Astra can continue reasoning, call other tools, or answer independent parts of a request while your application runs a tool." / "**Mid-turn steering:** Send additional user instructions while GPT-6 Astra is working" / "**Change reasoning mid-conversation while preserving cache**" |
| 1.6 | Astra limitation: no `none` reasoning effort | same | same | "GPT-6 Astra does not support the `none` reasoning effort." |
| 1.7 | Misalignment monitoring runs asynchronously on supported Responses requests and can stop a conversation for review | same | same | "our systems asynchronously monitor for misalignment and trigger alerts when necessary." (cf. changelog §6.4) |

---

## 2. Item (1) — Documented prompt-behavior priorities, with OpenAI's own prompt text

### 2.1 Initiative and follow-through (the "over-eager to ask / stalls" behavior)

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 2.1.1 | Officially documented failure mode: Astra may stop where the user expects persistence | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "The model is designed to be a more effective collaborator and is thus more likely to ask the user a question when additional input could materially change the result. This can cause it to stop when the user may expect it to make reasonable assumptions and persist." |
| 2.1.2 | Official autonomy prompt #1 (bias to action) | same | same | "You should infer the user's intent and task scope from the instructions and prior conversation context. Your job is to bias towards action and carry the user's intended task to completion." (+ "…) unless they are clearly destructive or irreversible.") |
| 2.1.3 | Official autonomy prompt #2 (treat polite requests as commands) | same | same | "When the user's prompt indicates a request for action, such as \"can you...\", \"I want to...\", \"help me...\" and similar expressions, treat these as instructions to do the work and take action. Do not stop at acknowledging capability (e.g. \"Yes…\"), proposing a plan, or offering to continue." |
| 2.1.4 | Official autonomy prompt #3 (no capability-acknowledgement stalling; no "helpful enough" partials) | same | same | "Do not settle for a partial or \"helpful enough\" solution that does not fully satisfy the user's task to save time, effort or tokens. If a task requires sustained work, complete all the necessary work until the intended outcome is fulfilled." |
| 2.1.5 | Approval should be asked only after a concrete, reviewable result exists | same | same | "Before asking the user clarifying questions, you should complete the work that is already authorized from context and necessary to make the proposed action concrete and reviewable. The user should be approving a concrete, reviewable result." |
| 2.1.6 | Suppress unsolicited approval/warning machinery | same | same | "Do not introduce unsolicited warnings, disclaimers, approval flows, or safety/compliance checklists due to hypothetical risk." |
| 2.1.7 | Adjust autonomy to application needs; model asks non-blocking questions by default | same | same | "The model also likes to ask non-blocking questions as it's working by default, so adjust these prompts to match the level of autonomy your application needs." |
| 2.1.8 | Migration checklist names "unnecessary approval pauses" explicitly | same | same | "**Unnecessary approval pauses:** If you run into issues where the model keeps asking for approval before proceeding, use the initiative and follow-through guidance to prompt for more autonomous execution." |

### 2.2 Instruction following and instruction priority

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 2.2.1 | Astra is stronger at general instruction following, but MORE sensitive to skills/AGENTS.md files; audit them | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "It can be more sensitive to instructions contained in skills and other files, such as `AGENTS.md`. We **strongly recommend** auditing skills and other files accessible to your model for instructions that could influence its behavior." |
| 2.2.2 | Conflicting skill guidance can pause/block work; make priority explicit | same | same | "For example, unclear or conflicting guidance in a skill file may cause the model to pause and block work early. Make the priority of user instructions and skills explicit." |
| 2.2.3 | Official instruction-priority prompt | same | same | "The user's instructions take precedence over guidelines provided in a skill. If explicit user instructions conflict with a skill's instructions, prioritize the user's instructions." |
| 2.2.4 | Official transparency/debug prompt (names the blocking skill) | same | same | "If a skill causes you to ask for permission or confirmation, pause, leave requested work unfinished, or diverge from the user's intent, name and link to the exact SKILL.md file you read, quote the relevant instruction, and briefly explain how it applies. Distinguish explicit skill requirements from your interpretation of guidelines." |
| 2.2.5 | Decision boundaries previously written to restrain older models can now over-restrain Astra | https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra | Sep 11, 2026 | "If you stated boundaries previously because you wanted to prevent other models from going too far and you're now switching to GPT-6 Astra, consider updating that language: Astra could take it too seriously and may stop work where you'd actually be happy for it to continue." |
| 2.2.6 | Treat Astra as trustworthy for safe actions ("most aligned model") | same | same | "GPT-6 Astra, as our most aligned model, has much better judgment and will not perform tasks unless it knows it is safe – so you should treat it as such." |

### 2.3 Personality, writing style, verbosity

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 2.3.1 | Documented default: detailed, formatted, recurring phrases | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "The model tends toward detailed, formatted responses and may use recurring phrases across sessions. Specify the writing style and structure your application needs." |
| 2.3.2 | Official prose-style prompt | same | same | "Default to using clear, concise paragraphs, each developing one main idea. Use lists only when the information is genuinely parallel, sequential, or easier to compare, and avoid nested lists unless the hierarchy cannot be expressed clearly in prose." |
| 2.3.3 | Official technical-communication prompt | same | same | "Use plain language over jargon, and reference technical details only to the degree that it helps illustrate an idea or your work to the user." |
| 2.3.4 | Official "slop words" blocklist prompt (verbatim list) | same | same | "Avoid using slop words or phrases like \"Bottom Line:\" in conclusions, \"delve,\" \"foster,\" \"leverage,\" \"it's worth noting,\" \"importantly,\" \"Question? Answer.\" or \"This isn't about X. It's about Y.\", \"genuinely\" or hyphenated compound descriptions and adjectives." |
| 2.3.5 | Anti-contrastive framing rule | same | same | "Do not use contrastive framing such as \"X, not Y\" or \"X—not Y\" that introduces an unprompted alternative that the user didn't ask about." |

### 2.4 Subagent delegation

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 2.4.1 | Documented failure mode: under-delegation | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "The model may delegate less often than desired for your workflow. Specify when and how much it should use subagents for parallel work." |
| 2.4.2 | Astra is trained to divide and delegate work to parallel subagents | same | same | "GPT-6 Astra is trained to be able to divide and delegate work to subagents that work in parallel." |
| 2.4.3 | Official delegation prompt | same | same | "If at any point you can parallelize work by delegating tasks to another agent (no matter if you are the root or subagent), you should do so using collaboration tools if it could save time or improve quality." |
| 2.4.4 | Inter-agent message legibility prompt | same | same | "Messages that you send to other agents and your final answer may be read by a human, so ensure they are legible. Always put proper spaces between words and/or numbers." |
| 2.4.5 | API-level multi-agent (subagents coordinated in parallel) exists and is beta in the Responses API; tune delegation via prompting | https://developers.openai.com/api/docs/guides/prompt-guidance (GPT-5.6 tab content) | Living; retrieved 2026-09-17 | "Multi-agent [beta]: Multi-agent lets a GPT-5.6 instance coordinate multiple subagents in parallel and synthesize their results. … available as a beta feature in the Responses API" (note: this page/tab is the GPT-5.6 guidance, not Astra-specific — see §9) |

### 2.5 Testing and verification

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 2.5.1 | Documented failure mode: over-thorough testing on small tasks | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "For coding tasks, the model tends to be thorough in testing before considering a task complete. For smaller tasks, this can result in broader tests than the task requires." |
| 2.5.2 | Official testing-calibration prompt | same | same | "Do not write tests for reversible, low-impact changes that mirror the implementation." / "Run tests appropriate to the change and complete required checks. Once those pass, broaden or repeat testing only when new changes, failures, or unresolved concerns justify it; otherwise, continue toward completing the task." |
| 2.5.3 | Old "encourage testing" scaffolding is now unnecessary | https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra | Sep 11, 2026 | "Previous models needed encouragement to run tests and check their work. GPT-6 Astra does that on its own, so the same instructions can lead to unnecessary testing." |
| 2.5.4 | Example safe-workflow autonomy grant for tests (AGENTS.md pattern) | same | same | "The local tests use disposable fixtures and have no production access. Run them, fix failures caused by the requested change, and rerun affected tests without asking for approval at each step." |

---

## 3. Item (2) — Reasoning-effort levels and when to use each

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 3.1 | Astra `reasoning.effort` supports low/medium/high/xhigh/max (no `none`) | https://developers.openai.com/api/docs/models/gpt-6-astra | Living; retrieved 2026-09-17 | "`reasoning.effort` supports `low`, `medium`, `high`, `xhigh`, and `max`." |
| 3.2 | Changelog: no `none` level for Astra | https://developers.openai.com/api/docs/changelog | September 2026 section (Astra release entry; model released 2026-09-03 per launch post/system card) | "GPT-6 Astra does not support the `none` reasoning effort level." |
| 3.3 | Official migration guidance for choosing a starting effort | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "**Reasoning effort:** If you currently use `none` or `minimal`, start with `low` and compare results. Otherwise, preserve your current effective reasoning effort. Use `reasoning.effort` in Responses" |
| 3.4 | Generic official effort-level table ("Best for" per level) | https://developers.openai.com/api/docs/guides/reasoning | Living; retrieved 2026-09-17 | low: "Efficient reasoning with a modest latency increase. Ideal for use cases requiring tool-use, planning, search, or multi-step decision making, while optimizing for speed and cost." / medium: "When quality and reliability matter, and the task involves planning, complex reasoning, and judgement. Default configuration for most workloads" / high: "Hard reasoning, complex debugging, deep planning, and high-value tasks where quality and intelligence matters more than latency." / xhigh: "Deep research, asynchronous workflows and agentic tasks that require long runs. Only use when your evals show a clear benefit…" / max: "Maximum reasoning for your most complex tasks." |
| 3.5 | Effort values are model-dependent; check the model page | same | same | "Supported values are model-dependent and can include `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, and `max`. … Some models support only a subset of these values, so check the relevant model page before choosing a setting." |
| 3.6 | Change effort mid-conversation without rewriting the cached prefix | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "Add a `configuration_update` input item to increase reasoning effort for difficult work or reduce it for routine follow-ups without rewriting the original prompt prefix." |
| 3.7 | Cache-preservation rule for mid-conversation effort changes | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "If your application changes effort between responses, use `configuration_update` items in standard, single-agent requests. Keep request-level `reasoning.effort` unchanged to preserve the prompt prefix for caching." |

*(No official Astra-specific "use X for Y" effort table was found — the "Best for" table is the generic reasoning guide. See §9.)*

---

## 4. Item (3) — Long-context prompting guidance

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 4.1 | Astra context/output specs | https://developers.openai.com/api/docs/models/gpt-6-astra | Living; retrieved 2026-09-17 | "1,050,000 context window" / "128,000 max output tokens" / "Apr 30, 2026 knowledge cutoff" |
| 4.2 | Long-request pricing threshold (context economics) | same | same | "Prompts with more than 272K input tokens are priced at 2x input and cache rates and 1.5x output for the full request." |
| 4.3 | Official mechanism for long-running context: server-side compaction via `context_management` + `compact_threshold` | https://developers.openai.com/api/docs/guides/compaction | Living; retrieved 2026-09-17 | "You can enable server-side compaction in a Responses create request … by setting `context_management` with `compact_threshold`." |
| 4.4 | Compaction best-practice for continuity | same | same | "The returned compaction item carries forward key prior state and reasoning into the next run using fewer tokens. It is opaque and not intended to be human-interpretable." |
| 4.5 | Standalone compaction endpoint for explicit control | same | same | "use the standalone compact endpoint for stateless compaction in long-running workflows. … do not prune `/responses/compact` output. The returned window is the canonical next context window" |
| 4.6 | Cookbook long-context prompt pattern (re-grounding; reduces "lost in the scroll") — **archived GPT-5.2 recipe, not Astra-specific** | https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide | Dec 11, 2025 (page flags: "This recipe is archived and may reference outdated models or APIs.") | "For inputs longer than ~10k tokens … First, produce a short internal outline of the key sections relevant to the user's request. Re-state the user's constraints explicitly … anchor claims to sections ("In the 'Data Retention' section…") rather than speaking generically." |
| 4.7 | Cookbook compaction cadence | same | same | "Compact after major milestones (e.g., tool-heavy phases), not every turn" |
| 4.8 | Cookbook instruction placement for long context — **GPT-4.1 era, dated guidance** | https://developers.openai.com/cookbook/examples/gpt4-1_prompting_guide | Date not shown in extract (GPT-4.1 era, 2025) | "If you have long context in your prompt, ideally place your instructions at both the beginning and end of the provided context, as we found this to perform better than only above or below." |
| 4.9 | Astra-specific launch-era context feature (Codex harness, not API prompting): notes across context windows; earlier windows stay searchable | https://openai.com/index/gpt-6-astra/ | Living; retrieved 2026-09-17 (launch post, rollout dated 2026-09-03) | "In Codex, Astra can keep notes across context windows, preserving accumulated details without repeatedly compressing them into a single summary. Earlier context windows remain searchable" |

---

## 5. Item (4) — Agentic / long-horizon / planning-and-execution guidance

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 5.1 | Design intent: carry tasks from initial request to finished result | https://developers.openai.com/api/docs/changelog | September 2026 (Astra release entry) | "It combines these capabilities to carry complex tasks from an initial request to a finished result, using the context and tools you provide." |
| 5.2 | Async tool calling: model continues while your app runs tools; app still owns execution | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "Set `async: true` on a function or custom tool and return its result when ready using the original `call_id`. Your application still executes the tool and manages pending work." |
| 5.3 | Mid-turn steering: corrections/handoffs while a response is in progress (WebSocket) | https://developers.openai.com/api/docs/guides/steering | Living; retrieved 2026-09-17 | "Mid-turn steering is available with GPT-6 Astra (`gpt-6-astra`) over a WebSocket connection to the Responses API. GPT-5.6 and earlier models do not support steering." |
| 5.4 | Long-running-work patterns: visible preamble before first tool call, sparse outcome updates, preserve `phase` values, compact after milestones — **GPT-5.6 Sol guidance, not Astra-specific** | https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6 | Living; retrieved 2026-09-17 | "Before tool calls for a multi-step task, send a one- or two-sentence user-visible update that states the first step. During the task, update only when a major phase begins or a finding changes the plan." / "Preserve assistant phase values when replaying history so the model can distinguish commentary from the final answer." |
| 5.5 | What an implementation plan must contain (official checklist, GPT-5.6 framing) — directly relevant to plan-creation handoffs | https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6 | Living; retrieved 2026-09-17 | "For implementation plans, include requirements, named resources or files, state transitions or data flow, validation checks, failure behavior, privacy or security considerations, and open questions that materially affect implementation." |
| 5.6 | Reasoning-model prompting for planning: outcome-first, don't prescribe every step | https://developers.openai.com/api/docs/guides/reasoning | Living; retrieved 2026-09-17 | "Reasoning-capable GPT-5 models usually work best when you give them a clear goal, strong constraints, and an explicit output contract without prescribing every intermediate step." / "For agentic or research-heavy workflows, define what counts as done and how the model should verify its work." |
| 5.7 | Agents API (managed Codex harness) reached public beta Sep 10, 2026; example uses Astra with an explicit "report the actual output" instruction | https://developers.openai.com/api/docs/guides/agents-api/quickstart + https://developers.openai.com/api/docs/changelog | Sep 10, 2026 (changelog) | "Released the Agents API in public beta. Build agents with a managed Codex harness while OpenAI handles session orchestration, context compaction, and recovery." (quickstart example instruction: "Write clean code, run it, and report the actual output.") |
| 5.8 | Frontend/eval footnote: Codex-style developer message actually used for Astra's FrontierCode eval run (concrete production wording) | https://openai.com/index/gpt-6-astra/ | Living; retrieved 2026-09-17 | "Avoid creating excessive test files. Create a new test file only when required by repository conventions or when no existing file is a suitable home. … Read relevant repository instructions and inspect nearby code, tests, documentation, and CI. Follow established conventions. The goal is clean, mergeable code." |

---

## 6. Item (5) — Official prompt framework / recommended prompt structure

Two official structures exist:

**6a. General prompt-engineering structure (`developer`/`instructions` message):**

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 6a.1 | Recommended developer-message sections, in order | https://developers.openai.com/api/docs/guides/prompt-engineering | Living; retrieved 2026-09-17 | "In general, a developer message will contain the following sections, usually in this order …: Identity … Instructions … Examples … Context" |
| 6a.2 | `instructions` parameter > `input`; developer role > user role; role priority defined by the model spec | same | same | "Any instructions provided this way will take priority over a prompt in the `input` parameter." / "`developer` messages are instructions provided by the application developer, prioritized ahead of `user` messages." |
| 6a.3 | Markdown + XML delimiting for sections/context | same | same | "Markdown headers and lists can be helpful to mark distinct sections of a prompt … XML tags can help delineate where one piece of content (like a supporting document used for reference) begins and ends." |
| 6a.4 | Reasoning-model prompting: high-level guidance preferred over step-by-step | same | same | "Generally speaking, reasoning models will provide better results on tasks with only high-level guidance." (o-series framing, model-dependent) |

**6b. The explicit "Suggested prompt structure" (GPT-5.6 Sol guidance page):**

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 6b.1 | Official 8-part prompt skeleton | https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6 | Living; retrieved 2026-09-17 | "Role: [the model's function and context] / Personality: [tone and collaboration style] / Goal: [user-visible outcome] / Success criteria: [what must be true before the final answer] / Constraints: [policy, safety, business, evidence, and side-effect limits] / Tools: [which tools to use, when, and what not to use] / Output: [sections, length, format, and tone] / Stop rules: [when to retry, fallback, abstain, ask, or stop]" |
| 6b.2 | Autonomy/approval policy pattern (compact, stated once) — directly reusable for orchestrator prompts | same | same | "For requests to answer, explain, review, diagnose, or plan, inspect the relevant materials and report the result. Do not implement changes unless the request also asks for them. / For requests to change, build, or fix, make the requested in-scope local changes and run relevant non-destructive validation without asking first. / Require confirmation for external writes, destructive actions, purchases, or a material expansion of scope." |
| 6b.3 | Warning against repeated "ask first" language | same | same | "Repeating instructions such as "ask first," "do not mutate," or "wait for approval" can cause unnecessary approval requests for safe, expected actions." |
| 6b.4 | Stopping-conditions phrasing pattern | same | same | "Resolve the request in the fewest useful tool loops, but do not let loop minimization outrank correctness, required evidence, calculations, or required citations. / After each result, ask whether the core request can now be answered with useful evidence. If yes, answer." |
| 6b.5 | Avoid absolute rules except for true invariants | same | same | "Avoid unnecessary absolute rules. Use ALWAYS, NEVER, must, and only for true invariants such as safety rules, required fields, or actions that should never happen. For judgment calls, such as when to search, ask, use a tool, or keep iterating, prefer decision rules." |
| 6b.6 | Validation loop wording for coding work | same | same | "After making changes, run the most relevant validation available: targeted tests for changed behavior; type checks or lint checks when applicable; build checks for affected packages; a minimal smoke test when full validation is too expensive" |

*(6b is officially labeled "Prompting guidance for GPT-5.6 Sol" — I found no Astra-specific equivalent structure page. See §9.)*

---

## 7. Item (6) — Tool calling and Responses API requirements

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 7.1 | Tool calling requires the Responses API | https://developers.openai.com/api/docs/changelog | September 2026 (Astra release entry) | "Tool calling requires the Responses API. If you use tools with Chat Completions, follow the Responses migration guide." |
| 7.2 | Same requirement in migration guidance | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "**Tool calling:** Use the Responses API. GPT-6 Astra supports Chat Completions, but tool calling requires Responses." |
| 7.3 | Unsupported sampling parameters | same | same | "**Unsupported parameters:** Remove `temperature`, `top_p`, and `top_logprobs`. For Chat Completions, also remove `logprobs`. For Responses, remove `message.output_text.logprobs` from `include`." |
| 7.4 | Tools available to Astra on the Responses API | https://developers.openai.com/api/docs/models/gpt-6-astra | Living; retrieved 2026-09-17 | "Tools supported by this model when using the Responses API. Web search Supported / File search Supported / Image generation Supported / Code interpreter Supported / Hosted shell Supported / Apply patch Supported / Skills Supported / Computer use Supported / MCP Supported / Tool search Supported" |
| 7.5 | Model decides when to use configured tools; `tool_choice` to guide | https://developers.openai.com/api/docs/guides/tools | Living; retrieved 2026-09-17 | "Based on the provided prompt, the model automatically decides whether to use a configured tool. … You can explicitly control or guide this behavior by setting the `tool_choice` parameter in the API request." |
| 7.6 | Astra also supports Structured Outputs, streaming, PTC, multi-agent orchestration (from GPT-5.6), prompt caching, persisted reasoning, compaction, pro mode | https://developers.openai.com/api/docs/guides/latest-model | Living; retrieved 2026-09-17 | "GPT-6 Astra also supports the existing API capabilities available with GPT-5.6, including computer use, Structured Outputs, streaming, Programmatic Tool Calling, multi-agent orchestration, prompt caching, persisted reasoning, compaction, and pro mode." |
| 7.7 | Endpoint availability includes Responses, Chat Completions, Batch etc.; fine-tuning not supported | https://developers.openai.com/api/docs/models/gpt-6-astra | Living; retrieved 2026-09-17 | "Fine-tuning Not supported" (Endpoints list includes "Responses v1/responses", "Chat Completions v1/chat/completions", "Batch v1/batch") |

---

## 8. Item (7)+(8) — Stop conditions, completion criteria, autonomy grants (incl. answering-question behavior)

| # | Claim | Exact URL | Page date | Short verbatim quote |
|---|-------|-----------|-----------|----------------------|
| 8.1 | Official guidance: define completion before starting; push until fully done | https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra | Sep 11, 2026 | "This is where it helps to define completion before starting. You might need to push Astra to continue until it's fully done. If the task includes getting the implementation running, inspecting the result, and fixing what fails, make that part of the request." |
| 8.2 | Stop-for-review requirements pull the model toward earlier stopping | same | same | "A requirement to stop for review after the first implementation will pull the model toward an earlier stopping point, so check whether that's a decision you actually need to make." |
| 8.3 | Name the exploration boundaries explicitly | same | same | "If you want it to keep exploring beyond a first pass, say what you want explored and where it should stop." |
| 8.4 | Documented tentative-stopping behavior | same | same | "If you're used to GPT-5.6 Sol taking a request and continuing for long stretches, GPT-6 Astra can feel more tentative about when to stop. It may reach a first implementation and come back for your review while there's still work to do." |
| 8.5 | Measured scope-discipline result (context for autonomy grants) | https://openai.com/index/gpt-6-astra/ | Living; retrieved 2026-09-17 | "Compared to GPT‑5.6 Sol, which without production safeguards went beyond the authorized target 48% of the time, GPT‑6 Astra did this in 0% of cases." |
| 8.6 | Question-asking policy in production products (Codex): ask async, proceed on sensible assumptions if unanswered, wait on consequential decisions | same | same | "In Codex, it can ask asynchronously while continuing work that doesn't depend on your reply. If you don't respond, it proceeds with sensible assumptions where appropriate, but waits for your input on consequential decisions." |
| 8.7 | Steering resilience: new requirements don't drop the original task | same | same | "Astra incorporates new requirements, changes course when asked, and answers side questions without dropping the broader task." |
| 8.8 | System-card alignment claim underpinning "authorized scope" wording | https://deploymentsafety.openai.com/gpt-6-astra | System card dated 2026-09-03 (with Sep 9, 2026 revisions noted) | "we find that GPT-6 Astra is stronger at respecting safety and security boundaries and staying within its authorized scope." |
| 8.9 | No `none` effort + misalignment monitoring can stop a conversation (operational stop context) | https://developers.openai.com/api/docs/changelog | September 2026 | "Misalignment monitoring asynchronously checks for potential issues during agent work in supported Responses API requests. Checks can trigger safety alerts or stop a conversation for review." |

---

## 9. Could NOT verify in official sources

1. **No Astra-specific cookbook recipe / prompting guide.** Searches of `developers.openai.com/cookbook` for "gpt-6"/"astra" returned only Astra DB (DataStax) vector-DB archive recipes and GPT-4.1/5.x-era guides. The Astra prompting guidance lives in the API docs ("Using GPT-6 Astra") and the developers blog post — not in the cookbook, as far as I could reach.
2. **No Astra-specific long-context prompting guidance.** Nothing found on any official page that says "for Astra long-context, do X". All long-context prompt patterns found are generic/archived (GPT-5.2 cookbook recipe is explicitly archived; GPT-4.1 cookbook is dated). Astra-specific context material is limited to mechanics (1.05M window, 128K output, 272K pricing breakpoint, compaction, Codex note-taking).
3. **No Astra-specific prompt-structure page.** The "Suggested prompt structure" (Role/Personality/Goal/Success criteria/Constraints/Tools/Output/Stop rules) is on the GPT-5.6 Sol guidance page. Whether OpenAI intends it for Astra verbatim is not stated.
4. **Multi-agent guide unreachable.** Two fetch attempts for `developers.openai.com/api/docs/guides/multi-agent(.md)` returned substituted/unrelated content (the compaction page, then the launch post). The multi-agent *guide* contents for Astra (how to configure delegation in the Responses API) could not be verified. Only the GPT-5.6-tab mention of an "Multi-agent [beta]" Responses feature was verified.
5. **No official "use effort X for task Y" table specific to Astra.** The best-for table is on the generic Reasoning models page (values "model-dependent"; the page's examples use GPT-5.5/5.6).
6. **Astra's default reasoning effort is not stated** on the model page or guidance page (GPT-5.6 defaults to `medium`; no equivalent statement found for `gpt-6-astra`).
7. **No official phrasing of "stop conditions" specifically for plan-creation/orchestrator handoffs.** Closest official artifacts: the GPT-5.6 stop-rules structure, the blog's "define completion before starting", and the testing-calibration prompt in §2.5.2.
8. **`/api/docs/guides/long-context.md` does not exist** (fetch returned no result). No dedicated long-context page was found at that predictable slug; the docs index (`llms.txt`) was not fetched (fetch budget).
9. **help.openai.com** was not queried directly in this lane (no Astra prompting articles surfaced via search targeting it).

## 10. Open questions

1. Does an Astra-tuned variant of the GPT-5.6 "prompting guidance" page exist under another slug (e.g. `prompt-guidance-gpt-6-astra`)? Checking `developers.openai.com/llms.txt` would resolve the doc index — worth one fetch in a follow-up lane.
2. How exactly does the "Multi-agent [beta]" Responses feature configure delegation for Astra (roles, depth limits, tool handoff), and does it change the prompting advice in §2.4?
3. Is `phase: "commentary"/"final_answer"` applicable to Astra workflows the same way as GPT-5.5/5.6 (it is not named in the Astra guide; only mid-turn steering, async tools and `configuration_update` are)?
4. For plan-creation specifically: which effort level (high vs xhigh vs max) does OpenAI implicitly recommend for "deep planning" when the output is a plan rather than code? Generic table says high = "deep planning", xhigh = "DESTINED for long runs; only when evals show clear benefit", max = "most complex tasks".
5. Does the `configuration_update` cache-preservation rule apply inside tool loops / multi-agent requests (the guidance limits it to "standard, single-agent requests")?

---

### Appendix A — Pages retrieved (successful)

1. https://developers.openai.com/api/docs/guides/latest-model — "Model guidance / Using GPT-6 Astra" (primary)
2. https://developers.openai.com/api/docs/models/gpt-6-astra
3. https://developers.openai.com/api/docs/changelog
4. https://developers.openai.com/api/docs/guides/prompt-engineering
5. https://developers.openai.com/api/docs/guides/reasoning
6. https://developers.openai.com/api/docs/guides/reasoning-best-practices
7. https://developers.openai.com/api/docs/guides/compaction
8. https://developers.openai.com/api/docs/guides/prompt-guidance (GPT-5.6 tab)
9. https://developers.openai.com/api/docs/guides/prompt-guidance-gpt-5p6
10. https://developers.openai.com/api/docs/guides/steering
11. https://developers.openai.com/api/docs/guides/tools (via search extract)
12. https://developers.openai.com/api/docs/guides/prompt-caching (via search extract)
13. https://developers.openai.com/api/docs/guides/agents-api/quickstart (via search extract)
14. https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra (Sep 11, 2026)
15. https://openai.com/index/gpt-6-astra/ (launch post)
16. https://deploymentsafety.openai.com/gpt-6-astra (system card, 2026-09-03)
17. https://developers.openai.com/cookbook/examples/gpt-5/gpt-5-2_prompting_guide (archived)
18. https://developers.openai.com/cookbook/examples/gpt-4.1_prompting_guide (via search extract)

### Appendix B — Failed / substituted fetches

- https://developers.openai.com/api/docs/guides/multi-agent(.md) — attempt 1 returned the Compaction page; attempt 2 returned the openai.com launch post. Not verified.
- https://developers.openai.com/api/docs/guides/long-context.md — "Extract backend returned no result" (page does not exist at that slug).
- https://developers.openai.com/api/docs/changelog.md — extractor substituted the Reasoning best-practices page; the plain changelog URL worked.
- https://cookbook.openai.com search for Astra recipes — no GPT-6 Astra cookbook recipe found.
