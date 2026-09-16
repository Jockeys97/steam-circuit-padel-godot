# Gate 2 implementation plan — porting Steam Circuit Padel Pro to Godot 3D

- Status: drafted 2026-09-16 by crew-sierra (Gate 2 lane of the mission `docs/mission/CHARTER.md`)
- Baseline: git commit `2979588`, frozen reference for the web build
- Scope of this plan: the ordered slice list, the exit evidence for each slice, and the
  open human decisions that gate them. It decides nothing that belongs to Luca.
- Authority: `docs/mission/CHARTER.md` (Gate 2), `docs/wayfinder/map.md`,
  `docs/wayfinder/tickets/simulation-port-boundary.md`,
  `docs/wayfinder/tickets/godot-headless-harness.md`, `GAMEPLAY_RULES.md`.
- Constants are authoritative in `js/data.js`. The audit scripts under `scripts/` are the
  executable specification and are not weakened, rewritten or deleted by this plan.

## Outcome: what the player must be able to do

In the finished Godot desktop build, a player starts a quick match from the menu, plays
padel under the same rules as the web build, and gets the same results the web build
produces for the same inputs:

1. Serve from below, from behind the service line, into the diagonally opposite box,
   with first/second serve and double fault.
2. Rally with drive, slice, lob, volée and the special, at the same ball speeds and
   reaction windows the web build uses, so the ball is readable and recoverable
   (`GAMEPLAY_RULES.md:133-140`).
3. Use the glass: the wall is only live after a first valid bounce on the receiving
   side, the second bounce closes the point, a ball that hits the opponent's wall
   without bouncing gives the point to the side that owns that wall.
4. Keep score as tennis score: 0/15/30/40, advantage, game, set, tie-break.
5. See shot feedback (PERFETTO / BUONO / IN ANTICIPO / IN RITARDO with CONTROLLO /
   BILANCIATO / POTENZA), the remaining-energy bar, and the point log.
6. Face the same four AI opponents at their four levels, with the AI held to the same
   physics the player is (`GAMEPLAY_RULES.md:69-100`).
7. Play it with a gamepad, in real 3D, with the same framing on first load as the web
   build (camera start is a *confirmed* decision; the verdict on feel is not).
8. On release: Steam achievements and Steam Cloud saves present in v1.

The mechanical definition of "the same game" is the audit suite, not an opinion: 27
scripts under `scripts/`, run by `scripts/run-audits.mjs` (`npm run audit`), currently
27/27 green on this host. Every slice below must state which of them proves it and add
the Godot-side equivalent under the same test name.

## Scope boundaries

In scope:

- A pure, headless GDScript simulation core reachable without a scene, driven by an
  explicit integer tick of `1/120` s and an explicitly injected seed.
- Quick-match parity in 3D, then feature parity with everything the web build has.
- Godot-side replacements for the audits that cannot port literally (module/import
  contracts, sprite-sheet inspection) — replacement, not deletion.
- Steam interfaces implemented and tested against a development/test app.

Out of scope for the port:

- New athletes, arenas, modes or mechanics the current game does not have. Volpe is a
  pipeline test asset, not a roster character, until Luca says otherwise.
- Re-tuning. `COURT`, the `BALANCE` values, `SERVICE_LINE_OFFSET`, `WIN_SCORE`,
  `MATCH_FORMATS`, athlete stats, AI `skill`/`speed`/`power` and arena `wallBounce` are
  frozen; changing any of them is re-tuning and needs Luca's approval plus a
  `VERSION.balance` bump (`js/data.js:20`).
- Any spend on Meshy, image generation or purchases. Budget for this mission is 0
  credits and $0; inference stays on the existing OpenCode Go lane.
- Publishing, Steam store configuration, deployments and branch/commit churn.
- Authentication, touch/OSK and browser-save migration questions: decided (or dropped
  explicitly) in `product-scope-and-platforms`, never by omission here.

## Ordered slices

Ticket links are the two build tickets this plan delivers plus the wayfinder tickets
that gate the later ones. "Gate" names what must be true before the slice may be
called done.

| # | Slice | Ticket | Depends on | Gate / exit evidence |
|---|---|---|---|---|
| S1 | Deterministic simulation parity core: `js/game.js` minus its four couplings plus the `clamp` helper, ported to headless GDScript with a bit-exact RNG and the `1/120` tick | `tickets/sim-core-parity.md` | nothing technical; acceptance waits on the parity gate definition | JS and Godot digests agree on `rngState` / `rngCalls` / discrete outcomes at every sampled tick; `node scripts/parity-digest.mjs …` and the Godot equivalent print comparable digests |
| S2 | Quick-match vertical slice in 3D: menu → serve → rally → point → score, with the four AI tiers reachable and the shot feedback visible | `tickets/quick-match-slice.md` | S1; framing verdict from `camera-and-feel-spike`, UI verdict from `ui-port-approach` before the *playable* build is called done | headless slice run green plus a rendered capture; Luca's play verdict on framing and feel |
| S3 | Port the remaining simulation and rules audits one per name (wall rules, court speed, match format, shot quality, shot balance, smash input, difficulty, AI attack, lineup, controller tactics) | `tickets/sim-rules-audits.md` | S1 | each audit exists in Godot under its original name and is green |
| S4 | In-match HUD and main menu in Godot Control nodes | `tickets/hud-and-menu.md` | S2; `ui-port-approach` verdict | two screens rendered; legibility and overflow checked; Luca's verdict |
| S5 | 3D camera and feel integration into the slice | `tickets/camera-feel-integration.md`, gated by `camera-and-feel-spike` | S2; Luca's framing verdict | Luca plays it; camera and feel signed off |
| S6 | Nine arenas in 3D | `tickets/nine-arenas.md` | S5; `arena-art-direction`; the court-aspect decision | one arena built as proof, then the per-arena route |
| S7 | Athlete models, rig and locomotion clips for the roster | `tickets/athlete-models.md` | `athlete-roster-order`; `character-pipeline-economics` | at least two playable athletes and the four AI opponents, in the approved order, inside the credit cap |
| S8 | Drill as a 3D session | `tickets/drill-3d.md` | S2; `product-scope-and-platforms` | drill audit green in the port |
| S9 | Tournament and career presentation | `tickets/tournament-career.md` | S8, S4 | carrier audits green |
| S10 | Audio port (route resolved: baked WAVs replacing the WebAudio synth) | `tickets/audio-port.md`, gated by `audio-port-route` | S2 | 54/54 stub checks and 11/11 browser renders reproduced in Godot |
| S11 | Saves, Steam achievements, Steam Cloud | `tickets/saves-steam-cloud.md`, gated by `save-and-cloud-format`, `steamworks-integration-route` | `steamworks-prerequisites` (App ID) | mock-backed interfaces green; real Steam proof explicitly separate and requires Luca's App ID |
| S12 | Demo and export presets | `tickets/demo-export-presets.md` | `demo-gate-preset`; S11 | demo filter tested, export presets produced |
| S13 | Accessibility, locales, controller navigation, performance target | `tickets/accessibility-locales-performance.md` | `product-scope-and-platforms` | audits green plus a stated frame-rate target measured on agreed hardware |

All thirteen slices now have build tickets under `tickets/`. Each ticket states its own
blocking edges, its file allowlist and the human decisions that gate its acceptance; none
of them treats an open decision as made, and none of them may be declared complete while
its gate is open.

Ticket files, one per slice:

| Slice | Ticket |
|---|---|
| S1 | `tickets/sim-core-parity.md` (existing) |
| S2 | `tickets/quick-match-slice.md` (existing) |
| S3 | `tickets/sim-rules-audits.md` |
| S4 | `tickets/hud-and-menu.md` |
| S5 | `tickets/camera-feel-integration.md` |
| S6 | `tickets/nine-arenas.md` |
| S7 | `tickets/athlete-models.md` |
| S8 | `tickets/drill-3d.md` |
| S9 | `tickets/tournament-career.md` |
| S10 | `tickets/audio-port.md` |
| S11 | `tickets/saves-steam-cloud.md` |
| S12 | `tickets/demo-export-presets.md` |
| S13 | `tickets/accessibility-locales-performance.md` |

## Open human decisions, and what each blocks

Everything in this table is **open and waiting on Luca**. The "recommended default" is a
proposal an agent may build against as a *provisional* target where explicitly noted; it
is never treated as a confirmation, and no slice may be declared complete on it.

| Decision (owner: Luca) | Blocks | Recommended default (proposal only, not confirmed) |
|---|---|---|
| Parity gate definition | S1 acceptance, S3, S6 exit | Gate on discrete state: identical `rngState`, `rngCalls`, counters, score fields and ordered point outcomes at every sampled tick; positions compared with an absolute 1e-3 px tolerance, applied to the first divergence only, with any first-divergence mismatch a hard failure. This tolerance is a proposal from `simulation-port-boundary.md` and is **not measured**. |
| Web build strangler policy | which commit parity is measured against (S1, S3) | Freeze the web build at `2979588` for the duration of the port; any later fix re-freezes the baseline and re-measures parity. |
| Court aspect: `COURT` is 800 x 508 px = 1.575, not 20:10 | S1's 3D court mesh, S6 | Keep the web build's proportions: one uniform scale of 0.025 m/px makes the court 20.000 x 12.700 m, matching the pixels. The "20 x 10 metri" figure in `GAMEPLAY_RULES.md:11` would require a different or non-uniform scale and is Luca's call. Determinism is unaffected either way. |
| Camera and feel | S5, S6, and the *done* verdict on S2 | Keep the `godot/prototypes/arena_spike/` playable preset framing as the provisional composition until Luca's verdict. |
| UI port approach | S4, and the *done* verdict on S2 | Godot Control tree for two screens only (main menu, in-match HUD), then stop for a verdict. |
| Arena art direction | S6 | Reuse the existing painted artwork as textures/skybox first; no Meshy spend in the port. |
| Athlete roster order (+ Volpe fate, + credit cap) | S7 | Build in `ATHLETES` order (`js/data.js:324`): maestro and pantera first, the four AI opponents reusing those bodies. Volpe stays a pipeline test asset unless Luca promotes it. |
| Product scope and platforms | S8, S11 context, S13; the *playable* form of S2 (input scope) | Windows + Linux desktop, gamepad and keyboard both supported, touch and the on-screen keyboard postponed to a stated later slice rather than dropped, `user://` saves plus Steam Cloud at release. |
| Demo gate rule | S12 | Reuse the `demo-audit` content rule (two athletes, one arena, quick match only) behind an export preset, tested as the web build tests it. |
| Steam App ID (live) | S11's real-Steam proof only | Develop and test against a Steam development/test app; the live release proof waits on Luca. |
| Character pipeline economics / recolour path | S7 | Unresolved: the Volpe rig has one baked texture with no proven garment zones. Do not assume recolouring is cheap and do not spend credits to find out. |

Two decisions are *not* on this list because they were confirmed on 2026-09-16 and must
not be re-opened: the animation split (Meshy rig plus Meshy locomotion clips, padel
strokes authored in Godot), the delivery order (quick match first), the outfit route
(recolour the same rigged model), Steam in v1, and the camera *start* (first build
reproduces the current web composition).

## Evidence and verification model

- The web build stays in the repository as the comparison reference for the whole port.
- Every claim is backed by a rerunnable command and a file on disk. Prefer a log plus an
  exit code over prose.
- Headless contract (from the resolved harness ticket): `timeout` is part of the
  contract, not decoration, because an aborted `_ready()` hangs instead of going red;
  `--quit-after` must not be used as the CI bound because it exits 0 on an aborted run.
- The Godot harness is a second job beside the Node suite, never a replacement for it.
- Rendering evidence on this host is software GL (`llvmpipe`, no GPU). It is valid for
  correctness screenshots and invalid for any frame-rate or target-hardware claim.
- One writer per file at a time; each ticket below states its file allowlist.

## Budget

Zero spend. 0 Meshy credits and $0 for the port; inference stays on the existing
OpenCode Go lane (provider `opencode-go`, model `deepseek-v4.1-flash`). No provider,
model or credential setting is changed by this plan.

## What this plan deliberately does not do

- It does not answer any decision in the table above.
- It does not authorise implementation of the slices beyond S1 and S2, and it does not
  claim S2 can be called complete while the framing, UI and parity gates stay open.
- It does not weaken, delete or rewrite any script under `scripts/`, and it does not
  modify `js/`, `godot/` or `tools/`; the tickets below are instructions for future
  implementers, not changes made here.
