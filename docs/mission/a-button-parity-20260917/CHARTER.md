# Il tasto A dal controller al colpo

Owner: Astra. Approved by Luca: "ok procedi boss".

## Outcome
Determine whether the live Godot port differs from the 2D reference when the same physical A-button timeline reaches the same match state. Produce a replayable differential test, first-divergence evidence, and a scoped verdict. A matching mapping or sim-only parity is not sufficient.

## Scope and gates
- Provenance: identify both reference trees, hashes, current dirty Godot source. Preserve existing uncommitted work.
- Input replay: exercise actual production input functions, not rewritten equivalents. Cover tap, charge/release, repeat A with smashPrimed, RB+A, movement/aim, no input, and press/release around zero/one/multiple fixed simulation ticks.
- Combined proof: compare translated intent, queue age/power/aim and final shot/contact where executable. Pin seed and frame schedules. Report missing seams rather than claiming end-to-end proof.
- Red control: deliberately corrupt a COPY of one trace and prove comparison exits nonzero. Never mutate production to demonstrate a test.
- Review: different worker independently challenges tests and limits; Astra re-runs a bounded command and checks artifacts.
- Human gate: Luca alone judges feel. No causal claim about his exact symptom without reproducing it.

## Limits
Diagnosis and test artifacts only. No gameplay fix, balance change, input redesign, commit, push, installs, paid APIs, deletion or process termination. Product trees and frozen JS read-only. Existing dirty match_controller.gd and untracked controller/parity tests belong to prior work; inspect/reuse without overwriting.
Authorized new artifacts only below this mission folder; dedicated scratch below /tmp/padel-a-button-20260917-<team> permitted. Source copies must retain hashes and modification provenance.
Godot PID 43135 was running at preflight. Leave it and keyboard focus alone. Run headless tests ONLY in an isolated minimal project/copy with no shared .godot cache; one diagnostic engine at a time, exclusively owned by Port. If isolation fails, return blocker, do not close user's game.
Budget: maximum 6 native worker launches total, maximum 2 retries per gate within that ceiling; 0 EUR new paid API spend, 0 asset credits. Subscription token cost unknown, never reported as measured zero. Initial lane target <=30 tool calls each. No new dispatch beyond launch cap. No routing fallback without user approval.
Native identity verified before dispatch: opencode-go / deepseek-v4-pro. CEO: openai-codex / gpt-6-astra. Runtime children cannot spawn children (max_spawn_depth=1); flat teams are deliberate, all crew launches remain with CEO. No CLI-agent workaround.

## Teams and ownership
- Reference: original browser input and reproducible oracle. Owns reference/ only.
- Port: Godot replay and sole integrator. Owns port/ and, after separate dispatch, integration/. Only team allowed to run Godot.
- Review: independent runtime-path audit and subsequent cross-review. Owns review/ only; no Godot while Port runs.
DeepSeek V4 Pro native workers fit bounded source/harness tasks. Independent review is a different worker, same worker model; final cross-model verification is Astra, not falsely advertised as heterogeneous worker review.
CEO owns CHARTER, MAP, LOG, tickets, ledger and board. Workers provide findings, never certify own gates.

## Evidence contract
Each team writes REPORT.md incrementally, then returns a short summary with absolute report path, runnable commands, output handles, source hashes, explicit coverage gaps, tool-call count if known, paid spend, and remaining launch allowance. Include exit codes and SCRIPT ERROR counts for every Godot run. Distinguish full live-path replay from adapter-only and sim-only tests.
Reference owns a machine-readable sequence corpus plus a documented schema. Port may design its runner independently, but integration waits for Reference completion and uses the exact reference corpus. No duplicated oracle logic. Reuse existing harnesses where they exercise the right seam.

## Reporting
Board report at each gate/milestone. Append log on dispatch and acceptance. Keep user-facing reports in Italian. Charter frozen after dispatch; changes logged by CEO.
