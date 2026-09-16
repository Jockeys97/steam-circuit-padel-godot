# Steam Circuit Padel Pro: Godot 3D port — Wayfinder map

Local-markdown Wayfinder map. **This map is an index, and it is charted, not
approved.** The decisions that are settled by Luca were confirmed on 2026-09-16
and live in exactly one place,
[Confirmed direction](tickets/confirmed-direction.md). Everything else is a
proposal, a question, or fog — unless a ticket below says `resolved`, in which
case the decision is recorded in that ticket with its evidence. Unresolved human
choices stay open; no ticket substitutes a guess for Luca's answer.

One ticket per file under `tickets/`. Refer to tickets by name, never by slug
alone. Detail lives in the ticket; this map only gists it and links.

## Destination

A Godot desktop 3D build of Steam Circuit Padel Pro that plays the same game as
the current web build, in real 3D, with no current feature dropped without Luca's
explicit approval, and with Steam achievements and Cloud saves in the first
release. This map is done when every ticket is resolved and the planning gates
below are met — not before.

## Notes

- Design authority is `GAMEPLAY_RULES.md`. Constants are authoritative in
  `js/data.js`. Audit scripts under `scripts/` are the executable specification.
- Source facts read from those files on 2026-09-16, verified by script (see
  [Validation](validation.md)): **6 athletes** (maestro, pantera, steamer,
  fiamma, oracolo, colosso), **9 arenas**, **26 outfit entries = 6 base + 20
  unlockable** (maestro 5, pantera 5, steamer 5, fiamma 5, oracolo 3, colosso 3),
  **4 AI opponents** (rivale, ingegnere, campione, leggenda), **13 screens**,
  **28 audit scripts**. Twenty unlockable outfits is the correct unlock set;
  26 is the total.
- **Correction, 2026-09-17 — the audit count is 28, not 27.** `scripts/` holds 28
  `*-audit.mjs` files in both trees, and the runner GLOBS them
  (`scripts/run-audits.mjs:21-23`: `readdir` + `filter`, no list to edit), so every
  one of the 28 is wired and none is orphaned. The earlier "27" and the validator's
  matching expectation were stale together, not a drift: the newest audit file is
  dated 2026-09-10, days before this mission started. Corrected in `validate.py`
  (the expected value, never the check) and here. Two consequences recorded rather
  than smoothed over: the bullet above quotes the Linux host's `27/27`, which cannot
  be the total of a tree with 28 files unless that run skipped one — this session
  cannot resolve it from this Mac; and on the owner's Mac the suite cannot run at all
  yet, because `node_modules/` is absent and `sharp` does not resolve (`npm run
  audit` → module-not-found, 28 reds, not 28 passes).
- Reference commit `2979588` is the frozen baseline. **The audit suite is now
  green on this host: 27/27, exit 0**, after installing the devDependencies the
  repo already declared. Both former reds had one cause — `node_modules/` was
  absent, so `sharp` could not be resolved — and neither was a product defect;
  the failing "assertion line" in the old log was a runner artefact.
  Diagnosis and raw log: [baseline audit diagnosis](evidence/baseline-audit-diagnosis.md),
  [baseline audit](evidence/baseline-audit.log). No test was weakened, and no
  generated asset changed.
- **Godot is installed and the headless harness is proven.** Version
  `4.7.2.stable.official.ed1daf0bf` at `/root/tools/godot/`, confirmed from the
  binary itself and from the canonical release notes. `godot/` now exists and
  runs in CI: `env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/`
  prints `PASS 8/8`, exit 0. Proof: [headless smoke](evidence/godot-harness-smoke.log).
  See [Godot headless harness](tickets/godot-headless-harness.md) for the rule
  that keeps a hung run from reading green.
- The simulation runs a **fixed 120 Hz step in the frame loop**, not in
  `game.js`: `FIXED_STEP = 1 / 120` at `js/main.js:1164`, accumulator loop at
  `js/main.js:1186-1207`, drill loop at `js/main.js:2113`. The RNG is `nextRandom`
  (`js/game.js:22`), seeded once per match from `Math.random` (`js/game.js:218`),
  deterministic from there on. The boundary between portable simulation and
  Godot-owned presentation is specified in
  [Simulation port boundary](tickets/simulation-port-boundary.md).
- **Volpe is a newly generated Meshy trial**, not a retrieval of Luca's latest
  existing asset and not a roster athlete. The rig is a single base pose — **no
  idle clip anywhere**; walking and running are companion GLBs; 24 joints; one
  baked texture with no proven tint zones. Provenance and limits:
  [Confirmed direction](tickets/confirmed-direction.md).
- No rendered or playable Godot evidence exists yet. `meshy/rigged/RESULT.md`
  is a pipeline test (parsing-verified GLBs), not in-engine proof.
- **Confirmed** = Luca said it on 2026-09-16. Everything else is a proposal.
  Tickets mark which is which, and the confirmations are recorded once, in
  [Confirmed direction](tickets/confirmed-direction.md).
- Skills for sessions working this map: `wayfinder`, `tdd`. Luca signs off feel,
  camera and UI — those never resolve on tests alone.
- **The parity proof now covers a full point sequence.** A runner
  (`tools/sim-port/fault-digest.mjs` with `godot/src/sim/fault_digest_gd.gd`) strikes
  serves at full charge — the frozen harness's charge cap 0.3254 against a measured
  fault threshold of ≈ 0.90 is why faults never fired — and both engines produce
  **byte-identical** streams on the strict comparator: the first-serve fault at tick 251,
  the second serve at 254 (601 ticks × 21 fields), then a **double fault** at tick 377
  (4,001 samples, digest `23f5fb15…`) and, with `setsToWin = 3`, a **completed set** at
  tick 12,691 and a second at 25,537 (481 samples, digest `568a5290…`). Evidence:
  [fault and second serve parity](evidence/fault-second-serve-parity.md),
  [double fault and completed set parity](evidence/fault-double-fault-set-parity.md).
  Still open and named: the double fault needs the second athlete (the frozen harness's
  own athlete structurally cannot fault on serve); the post-result tail is outside the
  runners' scope; and the parity **gate verdict** itself is Luca's, so slice S1 is
  proven, not closed.
- **The audio port has a verified event contract, not an implementation.** Ten events map
  to the ten baked WAVs, every anchor resolves to a real call site in the reference, and
  a test fails on drift (7 injected cases caught, one red control run). No Godot audio
  module, bus or playback exists yet, and the reference defines no loudness/ducking
  targets — recorded as unknown. Evidence:
  [audio event contract](evidence/audio-event-contract.md).
- **The recolour visible-difference limit is measured, and it is authoring, not the
  render path.** Only 14.25 % of the packed atlas is recolourable, capping the
  rendered whole-model difference at 8.95/255 with today's mask; the prescribed
  stronger targets in `tools/character/outfits-strong.json` predict 3.74/255 against
  today's measured 1.2/255. Evidence:
  [recolour delta ceiling](evidence/character-recolour-delta-ceiling.md).
- Ticket header convention: Status (open/resolved), Type
  (research/prototype/grilling/task), Mode (AFK/HITL), Owner, Blocked by. The
  frontier is every open ticket whose blockers are all resolved.

## Decisions so far

- [Confirmed direction](tickets/confirmed-direction.md) — RESOLVED 2026-09-16: the
  five confirmed decisions (animation split, camera start, delivery order, outfit
  route, Steam in v1) and the Volpe trial provenance, in one place. The recolour
  path is explicitly still open.
- [Simulation port boundary](tickets/simulation-port-boundary.md) — RESOLVED
  2026-09-16: the simulation core is `js/game.js` minus four named couplings
  (audio calls, visual effects, the reduced-motion branch, and translation) plus
  one render helper; the tick, RNG-word and data contracts a Godot port must
  reproduce are pinned with file-and-line anchors, together with the balance
  constants frozen pending Luca.
- [Godot headless harness](tickets/godot-headless-harness.md) — RESOLVED
  2026-09-16: engine pinned to Godot 4.7.2 stable, proven from the binary and the
  upstream release notes; headless CI contract established, including the rule
  that a hung run must be killed by `timeout` because the convenient
  `--quit-after` bound exits green.

## Tickets and dependencies

`Status` shows where each ticket stands; the dependency column mirrors each
ticket's own `Blocked by` line, so the map cannot drift from the tickets.

| Ticket | Status | Type / Mode | Owner | Blocked by |
|---|---|---|---|---|
| [Simulation port boundary](tickets/simulation-port-boundary.md) | resolved | research / AFK | crew-charlie | none |
| [Character pipeline economics](tickets/character-pipeline-economics.md) | open | research / AFK | crew-alfa | none |
| [Audio port route](tickets/audio-port-route.md) | resolved | research / AFK | crew-lima | none |
| [Godot headless harness](tickets/godot-headless-harness.md) | resolved | research / AFK | crew-bravo | none |
| [Web build strangler policy](tickets/web-build-strangler-policy.md) | open | grilling / HITL | unassigned | none |
| [Steamworks prerequisites](tickets/steamworks-prerequisites.md) | open | task / HITL | unassigned | none |
| [Product scope and platforms](tickets/product-scope-and-platforms.md) | open | grilling / HITL | unassigned | none |
| [Demo gate rule](tickets/demo-gate-preset.md) | open | grilling / HITL | unassigned | none |
| [Steamworks integration route](tickets/steamworks-integration-route.md) | resolved | research / AFK | crew-mike | none |
| [Save and cloud format](tickets/save-and-cloud-format.md) | open | grilling / HITL | unassigned | Steamworks integration route |
| [Parity gate definition](tickets/parity-gate-definition.md) | open | grilling / HITL | unassigned | Godot headless harness, Web build strangler policy |
| [Camera and feel spike](tickets/camera-and-feel-spike.md) | open | prototype / HITL | unassigned | Godot headless harness |
| [UI port approach](tickets/ui-port-approach.md) | open | prototype / HITL | unassigned | Godot headless harness |
| [Arena art direction](tickets/arena-art-direction.md) | open | grilling / HITL | unassigned | Camera and feel spike |
| [Athlete roster order](tickets/athlete-roster-order.md) | open | grilling / HITL | unassigned | Character pipeline economics |
| [Shot logic parity](tickets/shot-logic-parity.md) | open | task / AFK | crew-shotlogic | none |
| [Timing logic parity](tickets/timing-logic-parity.md) | open | task / AFK | crew-timinglogic | none |
| [Timing presentation in 3D](tickets/timing-presentation-3d.md) | open | task / AFK | crew-timinghud | none |

**Dependency correction, 2026-09-16:** [Steamworks integration
route](tickets/steamworks-integration-route.md) is no longer blocked by
[Steamworks prerequisites](tickets/steamworks-prerequisites.md). Choosing and
compatibility-checking a Steam bridge needs a development/test app, not the live
App ID, and the engine version it must be checked against is now pinned. Only
the live release proof waits on Luca's App ID, and that lives in the
prerequisites ticket.

Frontier (open, no open blockers): Character pipeline economics, Web build
strangler policy, Steamworks prerequisites, Product scope and platforms, Demo
gate rule.

**Status reconciliation, 2026-09-16 (tick 9):** [Audio port
route](tickets/audio-port-route.md) and [Steamworks integration
route](tickets/steamworks-integration-route.md) were marked `open` in the table
above long after their own ticket files said `resolved` and after the CEO had
independently re-run or re-fetched their evidence (tick 5: 54/54 stub checks and
11/11 browser renders re-run; the cited GodotSteam release page fetched live with
its quoted text and artifact names matched). The table now mirrors the tickets.
Neither resolution substitutes for a human verdict: the live Steam release proof
still waits on Luca's App ID in [Steamworks
prerequisites](tickets/steamworks-prerequisites.md).

## Planning exit gates

1. Every ticket above is resolved, with evidence linked from the ticket.
2. Luca has given verdicts on camera/feel, UI approach, parity gate, roster
   order, arena direction, strangler policy and product scope.
3. The next phase (the detailed implementation plan and build tickets) exists
   only after gates 1–2. No implementation ticket may masquerade as a decision
   ticket.

## Next questions for Luca (not yet asked)

The OS, input, save-migration and OSK questions below are ticket-shaped now and
live in [Product scope and platforms](tickets/product-scope-and-platforms.md);
this list is a gist only.

- Touch controls / on-screen keyboard: keep, drop, or postpone in the port?
- Legacy browser saves: must the Godot build import them?
- OS targets for the desktop build (Windows / Linux / macOS)?
- Arena style in 3D: reuse painted art vs full geometry
  ([Arena art direction](tickets/arena-art-direction.md))?
- Which current features, if any, are allowed to be cut? Nothing is dropped
  silently.

## Not yet specified

- Tournament and career presentation in 3D (after UI verdict + quick-match parity).
- Coop and versus camera handling with more than one player in frame.
- Drill mode as a 3D session reusing the match engine.
- Steam store page assets, capsule art, demo build (after the demo gate rule).
- Whether the Volpe trial becomes a playable 7th athlete or stays a pipeline test
  ([Athlete roster order](tickets/athlete-roster-order.md)).

## Out of scope

- New athletes, arenas, modes or mechanics the current game does not have. The
  port reaches parity; it does not extend. (Exception to be re-scoped by decision:
  the Volpe trial as a 7th athlete is currently a question, not an in-scope build.)
