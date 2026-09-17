# Scout lane C — local corpus on prompting GPT-6 Astra (inventory + live verification)

Date: 2026-09-17. Scope: read-only mine of local sources (bounded per lane charter, node_modules/.git/venvs skipped), then live checks of the top claims against official primary sources (developers.openai.com / openai.com). All local reads only; the single write is this report.

Bottom line: the corpus is rich. The direct prior art for the mission prompt is the 2026-09-07 "astra-gpt6-prompt-scan.md" (SOTA scan, 3 lanes) plus the goal prompt built from it (Max-Pain-Baby). A second, *empirical* corpus exists from a real Astra-as-orchestrator run (DemonPet, 2026-09-10/11). Both are worth keeping. All top claims re-verified live today; one material local-vs-live discrepancy found (272K vs 1.05M context on the Codex backend).

---

## 1. Local source inventory (path — description — claims it makes)

### Group A — prior Astra research + applied prompt (2026-09-07 session)

| Path | What it is | Claims |
|---|---|---|
| `/Users/lucafantini/Desktop/Personal/Max-Pain-Baby/run/wayfinder/phase2/research/astra-gpt6-prompt-scan.md` | SOTA scan, 2026-09-07, 3 read-only scout lanes (muse-spark-1.3-contributor); source of nearly all Astra-prompting claims below this line | Context 1,050,000 tok / max out 128,000 / cutoff 2026-04-30; effort low/medium/high/xhigh/max (no `none`); full tool suite + Responses for tools; async tool calling, mid-turn steering (WebSocket), `configuration_update` keeps cache, persisted reasoning, compaction, prompt caching, multi-agent; "official prompting: explicit instructions (GPT-style, not minimal)", role definition, structured tool examples, require testing, TODO tracking + preambles, drop temp/top_p; **autonomy quirk**: over-asks approval / can stall → prompt "proceed on implied authorization", approval only after a concrete reviewable result; **sensitivity quirk**: conflicting/unclear skills + AGENTS.md cause early pauses → audit skills, make instruction priority explicit; CoT monitorability down vs Sol; first model at Critical cyber capability → external handles only, never trust self-report; pricing $10/$50, cached $1.00, >272K = 2x in / 1.5x out; released 2026-09-03/04 |
| `/Users/lucafantini/Desktop/Personal/Max-Pain-Baby/docs/launch/goal-prompt-astra.md` | The /goal-loop charter for Max Pain Baby, built from the scan (direct prior art for our v1 handoff prompt; its last line cites the scan) | Design decisions: CEO/orchestrator role; "proceed on implied authorization… label assumptions"; explicit instruction priority (PLAN.md wins on conflict); every gate = regenerable handle; grader separation (never edit tests/verifier); reward-hacking resistance; context discipline (persist plan to STATE.md, compact early, fresh session per phase); done contracts with concrete "DONE WHEN"; Codex weekly usage <10%; $3 money gate, subscription lanes only |

### Group B — empirical Astra-as-orchestrator run (DemonPet 3D, 2026-09-10/11)

| Path | What it is | Claims |
|---|---|---|
| `/Users/lucafantini/Desktop/Personal/DemonPet/docs/3d-production/ASTRA-FINISH-BRIEF.md` | Astra lead-implementer brief for the DemonPet finish mission | Role + "you implement"; 8 gating checks; TDD at seams; journal to ASTRA-WORKLOG with commands/exit codes/sha256; pause only for destructive conflict / blocking human verdict / infra failure; hard limits (no game/ edits, no pushes); ≤400-word final with honest gaps |
| `/Users/lucafantini/Desktop/Personal/DemonPet/docs/3d-production/ASTRA-RESUME-05AM-BRIEF.md` | Resume brief (quota-reset run) | Quota probe first, back off if 429; "no self-score, never average away fails"; independent critics must be different model families; freeze artifacts before scoring; dirty tree intentional |
| `/Users/lucafantini/Desktop/Personal/DemonPet/docs/3d-production/critic-routing.md` | Cross-family critic routing (CCL) | Same-family workers cannot be critics; proven routes: xAI Grok (`xai-oauth`, logged in) and DeepSeek/MiniMax (`opencode-go`); openai-codex excluded (parent family); effort is policy-only for `hermes chat` |
| `/Users/lucafantini/Desktop/Personal/DemonPet/three-d/ASTRA-WORKLOG.md` | Append-only empirical run log | journey-browser went red→green after control fix; two pinned `openai-codex/gpt-6-astra` workers **both exit 1**; art captures with sha256 before/after; resume quota probe OK; native delegation excluded because its OpenRouter lane was metered/forbidden |
| `/Users/lucafantini/Desktop/Personal/DemonPet/three-d/ASTRA-PARENT-REVIEW.md` | Parent pre-integration review | Concrete defect list (input leakage, save-failure handling, fps measurement); "no council score inferred from implementation workers — same model identity as parent cannot satisfy the cross-family critic council"; visual verdict stays human |
| `/Users/lucafantini/Desktop/Personal/DemonPet/three-d/astra-art-brief.txt`, `astra-gameplay-brief.txt` | Worker prompt templates (pinned identity, disjoint ownership) | "Same authorized openai-codex/gpt-6-astra identity as parent"; exclusive file ownership; NO nested agents; ~25-minute caps; append-only worklog to avoid concurrent overwrite; evidence dirs per worker; no self-certified scores |
| `/Users/lucafantini/Desktop/Personal/DemonPet/three-d/evidence-astra-finish/` (+ `resume-05am/`) | Evidence tree backing the worklog | Baseline hashes, worker stdout/stderr logs, quota probe, route JSONs |
| `/Users/lucafantini/Desktop/Personal/DemonPet/temp/handoff-20260911-092400-demonpet-finish-3d.md` | Session handoff | Copy-goal-verbatim rule; acceptance law + council contract; "do not self-score"; desktop ≠ iPhone proof |

### Group C — current mission documents (Padel / world-arenas-r1)

| Path | What it is | Claims |
|---|---|---|
| `.../Padel-3D/steam-circuit-padel-godot/art/concepts/world-arenas-r1/astra-plan-prompt.md` | **The v1 prompt being improved** (object of the mission) | Astra = lead orchestrator certifying evidence; FIELD LAW; zero spend; frozen stills; deliverable = plan + named linked tickets; "Verify every claim with a regenerable handle… Never report self-certified green" (inherits the Max-Pain-Baby pattern) |
| `.../world-arenas-r1/scan/launch.md` | Scan launch note (2026-09-17) | Lanes A (official docs), B (practitioner), C (local corpus + verification — this lane); reads-only, one report file each |
| `.../docs/mission/CHARTER.md` | Mission charter | "Minimise the Astra parent context"; captain = `opencode-go/deepseek-v4.1-flash`; org-simulation; native leaves cannot redelegate; child returns need independent verification (not self-report) |

### Group D — web cache corpus (`~/.hermes/profiles/dev-work/cache/web/`) — the claim pool behind the 09-07 scan

Official (OpenAI):
- `developers.openai.com-5c4b950aae.md` — "Using GPT-6 Astra" model guidance, **full page text** (best local copy). Claims: prompting best practices — initiative & follow-through, instruction following, writing style, subagent delegation, testing & verification; "unnecessary approval pauses" remedy; migration items (drop temp/top_p/logprobs; `none`→`low`; Responses for tools; `prompt_cache_options.ttl="30m"`).
- `developers.openai.com-f1a02cdda8a9d870.cache.md` — "Rethinking skills and prompts for GPT-6 Astra" blog (Sep 11, 2026). Claims: prune skill descriptions (specific triggers), progressive disclosure, over-specific recipes hinder; AGENTS.md → read-what's-needed map, not read-everything; Astra self-tests (unnecessary-testing risk); **more tentative about stopping → define completion; push until done**; widen decision boundaries (strong ask-first language makes it stop early).
- `developers.openai.com-424f1bd875c5ca21.cache.md` — model page (context/effort/pricing/snapshots). `developers.openai.com-49e8d0577a.md` + `ec54a9766f44f928.cache.md` — changelog (no `none` effort; no temp/top_p/logprobs).
- `openai.com-ea74e2fffb.md`, `developers.openai.com-26c8bcaa0d.md`, `developers.openai.com-8dc7c4c9263708ee.cache.md` — launch post "A new generation of intelligence" (dupes). `openai.com-ad620be9197d98ea.cache.md`, `openai.com-e7ce2f6b9daf1a3f.cache.md`, `deploymentsafety.openai.com-d170283db7.md` — safety overview / system-card pages (Critical cyber; CoT monitorability drop; misalignment monitoring; sandbagging). `openai.com-711821fe83fa9736.cache.md`, `openai.com-d8e6fd2ea6.md` — safeguards note (internal hardening; Astra-class tool-enabled inference).

Third-party (2026 practitioner corpus):
- `promptessor.com-dde85283e5.md` (+ `fa645c6e2e346e52.cache.md`) — "How to Prompt GPT-6 Astra": five official behaviors; do-not-micromanage; context/instruction-priority/autonomy/tools blocks; "complete all reversible and already-authorized work before asking for approval"; effort ladder; 1.05M context → context engineering.
- `acecloud.ai-ca1f271f66.md` (+ cache) — "22 hacks": outcome briefs, autonomy rules, define "done", pre-authorise safe workflows, anti-overengineering instruction, scoped testing, "find out why Astra stopped" diagnostic, skill/AGENTS.md audit, delegation rules, confirmation gates for destructive actions.
- `dev.to-e2f6b98fbf23d278.cache.md` — guide + pricing: 1.05M/128K, xhigh/max added, 272K billing cliff (2x/1.5x for the whole request), "don't start at max", DeepSWE 74.1 vs Sol 70.8.
- `blog.kilo.ai-58268dfb0098ae13.cache.md` — Kilo production preview: best coding model they tested; **over-engineering bias + does too much research**; OpenAI's own FrontierCode dev message against sprawl; ~2,000-step overnight run; Critical cyber classification.
- `api.treerouter.ai-52c265e1b0702cdc.cache.md` — feature guide: mid-turn steering over WebSocket; async tool calling via `call_id`; `configuration_update` preserves cache; Responses required for tools; `prompt_cache_retention` → `prompt_cache_options.ttl="30m"`.
- `go.tabbit.ai-94dcbda00ccadafc.cache.md` — subscription field report: Astra High = sweet spot for implementation/planning (single user); XHigh no obvious gain; Fast/Fast+High consumed allowances fast; unfinished major refactor.
- `agiflow.io-eb649c61980b7b9f.cache.md` — "five controls beyond model intelligence": authority/evidence/approval/recovery records; capability ≠ authority; "OpenAI says Astra can keep working while it waits for a person".
- `news.ycombinator.com-40857189a5e3fc5a.cache.md` (+ `93253d7962.md`) — HN thread "Astra for Coding: Why Are We Doing This Again?" (practitioner criticism of coding feel).

### Group E — logs / runtime state

- `~/.hermes/profiles/dev-work/logs/agent.log`, `.1`, `.3` — real `gpt-6-astra` sessions via provider `openai-codex`: 2026-09-07 model switch with `reasoning effort 'high'`, and the Max-Pain-Baby goal prompt launched into a fresh Astra session (16:08). `.3` contains: `Cached context length gpt-6-astra@https://chatgpt.com/backend-api/codex -> 272,000 tokens`.
- `~/.hermes/profiles/dev-work/logs/errors.log` — contains the **failed earlier definitions of today's scout lanes** (an async delegation batch that errored with empty object; lane C's text matches this task). `.1`/`.2` — provider connection errors for the Astra lane (operational, not prompting-related).
- `~/.hermes/profiles/dev-work/context_length_cache.yaml` — `gpt-6-astra@…codex: 272000` (same value cached for `gpt-5.6-luna`/`terra`).

### False-positive grep noise (do not re-mine)

`astral-sh/uv` installers (pypi/github/hermes docs), `Mastra` (openrouter/github lists), `AstraZeneca` (oldschoolvalue), "metastrategies" (chicagobooth), `Olgastrasse` (LTEK corpora), `Astral Duelist` (Padel locale file). "gpt-6-astra" string search found no other reporting docs beyond Groups A–C.

---

## 2. Verification table — top 5 claims vs live primary sources (checked 2026-09-17)

| # | Claim (as found locally) | Local source | Live check URL | Verdict | Note |
|---|---|---|---|---|---|
| 1 | Astra over-asks approval / can stall; official remedy = complete authorized work, don't add unsolicited approval flows; user approves a concrete reviewable result; "unnecessary approval pauses" → use initiative & follow-through guidance | `astra-gpt6-prompt-scan.md` L1; `goal-prompt-astra.md` autonomy line | `https://developers.openai.com/api/docs/guides/latest-model` | **Verified** | Live wording: "complete the work that is already authorized from context… You don't need user permission for reversible tasks, read-only actions, reviews or fixes"; "Do not introduce unsolicited warnings, disclaimers, approval flows… due to hypothetical risk"; migration bullet "Unnecessary approval pauses". The scan's "proceed on implied authorization" is a faithful paraphrase, not verbatim |
| 2 | Astra is more tentative about stopping; define completion before starting; a mandatory review-stop pulls the stopping point earlier; push until fully done | `astra-gpt6-prompt-scan.md` L2 (done contract); `goal-prompt-astra.md`; v1 prompt checkpoint rules | `https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra` (Persistence section) | **Verified** | Official blog (Sep 11, 2026): "It may reach a first implementation and come back for your review while there's still work to do… define completion before starting" |
| 3 | Context 1,050,000 tok; max output 128,000; cutoff Apr 30, 2026; `reasoning.effort` low/medium/high/xhigh/max, no `none`; tools need Responses; temp/top_p/logprobs unsupported | scan L1; `promptessor.com` cache; changelog caches | `https://developers.openai.com/api/docs/models/gpt-6-astra` + guide migration section | **Verified** | Model page states all four numbers; effort list "low, medium, high, xhigh, max"; guide: "tool calling requires Responses"; remove `temperature`, `top_p`, `top_logprobs` |
| 4 | Pricing: $10 in / $50 out, cached input $1.00; >272K-token requests billed 2x input / 1.5x output for the full request | scan L1; `dev.to` cache | `https://developers.openai.com/api/docs/models/gpt-6-astra` + `https://developers.openai.com/api/docs/pricing` | **Verified** (scan numbers exact) | Extra current detail the scan missed: cache writes $12.50; long-context tier is $20/$2/$75; Fast mode 2x; Batch/Flex 50%. EU data residency: Fast unsupported for Astra |
| 5 | Astra is sensitive to conflicting/over-long skills & AGENTS.md (wrong skill loads, early pauses); make instruction priority explicit; audit/prune legacy rules | scan L1 "sensitivity quirk"; `promptessor.com` cache | `https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra` | **Verified** | Live adds: skill descriptions get truncated when too many; progressive disclosure preferred; **don't mandate read-everything before edits**; Astra self-tests, so old test-encouragement instructions cause unnecessary testing |

Secondary claims also confirmed live (no table row needed):
- Mid-turn steering (WebSocket), async tool calling (`async:true`, results via `call_id`), `configuration_update` preserving prompt cache — guide "What's new" section; treerouter cache matches.
- Critical cyber designation, CoT monitorability decrease, misalignment monitoring in production — system card at `https://deploymentsafety.openai.com/gpt-6-astra` + `https://openai.com/index/path-to-astra/` (confirmed via live search excerpts; a direct page extraction of the hub URL returned an archived GPT-5.2 guide page, so full-page fetch of that exact URL is unreliable — use the PDF `…/gpt-6-astra/gpt-6-astra.pdf` if needed).
- Release date Sep 3, 2026 + gpt-6-astra id — launch post + model page.

---

## 3. Contradictions

1. **272,000 vs 1,050,000 context — local runtime vs live docs (material).** `context_length_cache.yaml` and `agent.log.3` cache `gpt-6-astra@…codex = 272,000` tokens, but the live API page says 1,050,000. The same 272,000 is cached for `gpt-5.6-luna`/`terra`, so it looks like the Codex **subscription backend's operational window**, not the model's API window. Which limit governs Astra used via a Codex/ChatGPT session is unresolved. Coincidence worth noting: 272K is also the long-context pricing cliff. Budget plan-creation context against the smaller figure when running on the subscription lane.
2. **"Explicit instructions, GPT-style, not minimal" (scan, Sep 7) vs "Fewer rules, not more" (official blog, Sep 11).** Apparent tension. Reconciliation: prune *accumulated* context (skills, AGENTS.md, legacy prohibitions); keep the *task prompt* explicit about goal, boundaries and done. The v1 prompt's "Pause only for destructive actions…" pattern matches the newer widening-boundaries guidance.
3. **"Proceed on implied authorization" is not verbatim OpenAI.** The scan presents it in quotes; the live guide's actual text is "complete the work that is already authorized from context… The user should be approving a concrete, reviewable result". Same intent, but future prompts shouldn't cite the scan phrasing as official wording.
4. **Over-engineering/over-research (Kilo) vs "don't over-instruct to read/test" (official).** Kilo reports Astra defaults to sprawling changes and does too much research (OpenAI's own FrontierCode dev message asked it to avoid sprawl); the official blog says drop blanket read-before-edit and test-encouragement mandates. Both can be true: prune mandates, but keep one explicit minimality/scope line and a testing-calibration line. The v1 prompt has scope constraints but no explicit minimality instruction; worth adding.
5. **Guide publication date conflicts (cosmetic).** Third-party recap (pasqualepillitteri.it) says the Rethinking guide was published Sep 5, 2026 (quoting a Sep 5 tweet); the official page header says Sep 11, 2026. Treat the official date as canonical (page may have been updated).
6. **Subscription-allowance vs per-task-cost lenses (context, not direct conflict).** Tabbit: High burns 20x allowances fast (allowance ≈ 60% in 24h; High+Fast reset in ~12h). Dev.to: Astra uses fewer output tokens → lower cost per task. Different denominators (subscription allowance vs API per-task). Practical rule already in prior art: stay on subscription lanes, keep weekly Codex usage <10%, never plan against a clean reset.

---

## 4. Local paths worth keeping as references

1. `/Users/lucafantini/Desktop/Personal/Max-Pain-Baby/run/wayfinder/phase2/research/astra-gpt6-prompt-scan.md` — the prior research; every top claim traceable here.
2. `/Users/lucafantini/Desktop/Personal/Max-Pain-Baby/docs/launch/goal-prompt-astra.md` — closest working precedent to our v1 handoff prompt.
3. `/Users/lucafantini/Desktop/Personal/DemonPet/docs/3d-production/ASTRA-FINISH-BRIEF.md` + `ASTRA-RESUME-05AM-BRIEF.md` — empirical orchestrator briefs (contracts, pause rules, council prohibition).
4. `/Users/lucafantini/Desktop/Personal/DemonPet/three-d/ASTRA-WORKLOG.md` + `ASTRA-PARENT-REVIEW.md` + `docs/3d-production/critic-routing.md` — what actually happened with pinned same-identity workers, and the cross-family critic routes.
5. `/Users/lucafantini/Desktop/Personal/DemonPet/three-d/astra-art-brief.txt` / `astra-gameplay-brief.txt` — battle-tested worker prompt templates (disjoint ownership, caps, append-only log).
6. `~/.hermes/profiles/dev-work/cache/web/developers.openai.com-5c4b950aae.md` — full local copy of "Using GPT-6 Astra" (prompting best practices).
7. `~/.hermes/profiles/dev-work/cache/web/developers.openai.com-f1a02cdda8a9d870.cache.md` — the Sep 11 "Rethinking skills and prompts" blog.
8. `~/.hermes/profiles/dev-work/cache/web/promptessor.com-dde85283e5.md` (+ `.cache.md`) and `dev.to-e2f6b98fbf23d278.cache.md` — best third-party prompting/pricing captures.
9. `~/.hermes/profiles/dev-work/logs/agent.log.3` (Sep 7 Astra switch, effort=high, Max-Pain-Baby launch, 272K cache line) + `context_length_cache.yaml`.
10. Current-mission anchors: `…/world-arenas-r1/astra-plan-prompt.md`, `…/world-arenas-r1/scan/launch.md`, `…/docs/mission/CHARTER.md`.

---

*Verification method: local greps/reads (read-only) + `web_search`/`web_extract` of the URLs cited above on 2026-09-17. Nothing was executed against the OpenAI API; no credentials used. Third-party items (Kilo, Tabbit, HN, acecloud, agiflow, pasqualepillitteri) are unverified opinions unless a row above says otherwise.*
