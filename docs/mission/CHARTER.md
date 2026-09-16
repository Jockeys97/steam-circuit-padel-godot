# Godot port mission

## Authority and outcome

Luca authorised execution on 2026-09-16: run org-simulation using DeepSeek V4.1 Flash, minimise the Astra parent context, keep progressing until complete. This supersedes the planning-only execution restriction in the Wayfinder introduction; it does not approve unanswered visual/product choices or spending.

Deliver the existing Steam Circuit Padel Pro game in real Godot 3D, preserving its features, plus Steam achievements and cloud saves for release. Quick-match parity comes first. The map is `docs/wayfinder/map.md`; confirmed choices are `docs/wayfinder/tickets/confirmed-direction.md`. This charter authorises research, local prototypes, detailed implementation planning and tickets, and implementation of unblocked technical work. Keep unresolved human decisions explicitly open. Do not call the game complete while those gates remain open.

## Operating model

Scheduled captain uses provider `opencode-go`, model `deepseek-v4.1-flash`; native workers must resolve to that same explicitly requested identity. No alternative inference providers or expensive models. The parent Astra only certifies evidence and responds to product decisions. Configured native delegation was checked before launch and matches this identity. Recheck selected provider/model only, never print credentials. If routing drifts, stop dispatch and report.

Load org-simulation. Native leaf workers cannot redelegate in this environment: the scheduled captain assigns bounded crew tasks directly, not imaginary nested captains. Dispatch at least two independent crew lanes when work splits. One named integration owner handles cross-module changes. Each task has a narrow file allowlist and concrete verification command. Do not let concurrent writers overlap. Every child return needs independent verification, not self-report acceptance.

Read this charter, `STATE.md`, `LOG.md`, the map and live git status at each run. One scheduled driver only. Check the current job run/worker state before dispatch; no overlapping runs or duplicate live crew. Claims with start time and evidence belong in STATE; recover only after proving a prior owner stopped. A timeout is not proof its processes stopped.

## Ordered gates

1. Resolve AFK planning questions with evidence. Diagnose the baseline's two failing audits; do not remove/weaken tests. Verify Godot version through canonical releases and actual executable output, not previous chat claims. Correct map dependencies that block documentation research on a live Steam App ID unnecessarily.
2. Produce a detailed implementation plan and named dependency-linked implementation tickets in `docs/implementation/`. Keep conditional work blocked by the actual human decisions; never substitute guesses as confirmed answers. Tickets specify objective, existing source anchors, file ownership, inputs/outputs, tests, execution commands, expected evidence, and failure/recovery criteria.
3. Produce the smallest Godot import and camera/UI prototypes using existing downloaded rig files. Prove skeleton, skins, clip retargeting, dimensions, coordinate mapping and material limitations in-engine. Export screenshots and a runnable artifact for Luca. Taste, camera and feel approval belong to Luca.
4. Implement unblocked vertical slices, beginning with deterministic simulation parity and quick match. Preserve original web game as comparison. Install existing npm dependencies and official Godot binaries as needed; toolchain acquisition is allowed, paid services are not. Prefer separate `godot/` sources and do not silently retune balance.
5. Complete feature parity, exports, offline saves, controller navigation, accessibility/OSK, locales, audio and feedback. Implement Steam interfaces and tests without publishing or pretending mocks prove production Steam success. Actual Steam configuration and multi-device cloud verification remain explicit release gates.
6. Independent review and parent-verifiable evidence for every claimed completed slice. All tests, exports, visual/play approval and real Steam release gates must pass before final completion.

## Budget and boundaries

Additional Meshy/image-generation/purchases: 0 credits and $0 authorised. Existing test already spent 40 Meshy credits. Reuse assets; pitch any further spend with purpose, exact batch, price and duration. Inference uses only the user-requested existing OpenCode Go lane; do not buy quota or switch to metered providers. Record available telemetry, mark unavailable cost telemetry unknown.

Two attempts per failing gate before recording a blocker; continue unrelated unblocked work. No endless identical retries. No destructive cleanup, secret exposure, commits, pushes, deployments or Steam publication. Do not modify Hermes profiles, provider settings or other projects. Local game edits and proof tooling only. Human choices need a short decision queue with a recommended option and a tangible artifact, not fabricated consent. Volpe is a newly generated test asset, not a seventh approved roster character. Recolouring a baked texture still needs proof.

## Continuity and completion

Keep `docs/mission/STATE.md` current after every bounded work unit, with phase, task owners, completed evidence, blockers, next action and job handle. Append `LOG.md`; write `BOARD.md` at milestones with shipped/verified/blocked/cost/next action. The scheduled run is resumable, not an immortal agent: save early and finish each bounded tick cleanly. No extra scheduler, detached agent or concurrent driver.

Continue each scheduled tick from disk until all gates are proven. If all remaining work needs Luca, credentials, new spend or unavailable capacity, record WAITING with exact unblock requirements and pause this mission job rather than consuming tokens doing nothing. Paused is not complete. If user replies, parent can update decisions and resume. On true completion write COMPLETE with evidence and pause this mission job. Other jobs are untouched. Report milestones concisely; never claim the full game is finished on a partial test suite.
