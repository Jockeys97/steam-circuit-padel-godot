---
id: UIR-25
title: Final regression and Luca acceptance
slug: final-acceptance
state: blocked
readiness: potential
owner_role: coordinator + Luca (HITL)
blocked_by: [UIR-22, UIR-23, UIR-24, UIR-27]
conditional_blocked_by: [UIR-26]
blocks: []
gates: [plan-approval, gate-a]
closing_gate: luca-final
plan_approved: false
triage: human-gate
evidence:
  - docs/implementation/ui-recreation/evidence/uir-25-final.md
---

# UIR-25: Final regression and Luca acceptance

## Worker brief (copy-paste)

> Run everything, produce the final evidence pack, and put it in front of Luca. This ticket has two phases: (A) execution, where the agent prepares all evidence under gates `plan-approval` and `gate-a` only; (B) closing, where Luca's verdict arrives and the ticket closes on `luca-final`. The closing gate never blocks phase A: the evidence is what Luca judges. This ticket is HITL: the agent produces the artifacts and the runs; Luca produces the verdict. No self-certified visual pass, no "looks right" claims. Deliverables: before/after capture pairs, suites with exit codes and tally lines, the legibility audit at four sizes, the UIR-26 disposition (landed, or the decision quoted verbatim as the scope exception), and the open-items list (any remaining unresolved item and uncovered matrix cell; replay is not an open item, UIR-27 is a blocker). Hand over and stop.

## Why this exists

The mission's rule: feel, framing and UI direction are Luca's; the verdict is not the agent's to give. This is also where the whole recreation is checked as a system against the frozen reference one last time.

## Prerequisites (Definition of Ready)

- UIR-22, UIR-23, UIR-24, UIR-27 landed (`blocked_by`; replay is required, not an open item).
- All screen tickets landed or explicitly excluded and named.
- UIR-26 resolved one way or the other: landed, or the product-scope decision recorded verbatim as the scope exception (microstep 0). "Pending" is not a closing state.

## Read allowlist

- Everything in the pack; `docs/implementation/tickets/hud-and-menu.md` (its evidence list informs the final evidence shape); `docs/wayfinder/tickets/ui-port-approach.md` (the gate this closes the loop on)

## Write allowlist (you own these)

- `docs/implementation/ui-recreation/evidence/uir-25-final.md`
- `docs/implementation/ui-recreation/evidence/uir-25-*.log` (final suite logs; if size is a concern, the log directory can hold summaries plus pointers to the suite logs already written by earlier tickets)
- No code writes. No commits without the coordinator's standard commit rules (only if the mission wants them; do not push).

## Microsteps

0. Disposition of UIR-26, before anything else: if the product-scope decision says keep, confirm UIR-26 has landed and cite its evidence file; if it says postpone or drop, copy the decision's exact wording, date and author into `uir-25-final.md` as the recorded scope exception. Either way the final brief states the touch/OSK scope explicitly; the ticket does not close with the question unanswered.
1. Freeze: `git status --short`; record HEAD.
2. Run the full suite set serially on this Mac (UIR-00's seven + `tests/ui/router_audit.gd` + all `tests/ui/*_audit.gd` + `tests/ui/ui_legibility_audit.gd`). Record exit codes and tallies per suite; count `SCRIPT ERROR` lines separately.
3. Regenerate the final captures: `capture_ui --capture=all` (UIR-24 harness) + the two legacy captures (`--capture=menu`, `--capture=match`) so the before/after pairing is complete. Verify PNGs are real (dimensions, non-blank).
4. Build the comparison artifact: for each of the 13 screens, the reference PNG (UIR-06 `reference-captures/`) next to the port PNG (`godot/game/out/ui-*.png`), plus the menu/HUD before (UIR-00 register) vs after pairs. Put the table in `uir-25-final.md` with paths.
5. Open-items list: every unresolved `--pink`-style item; every "not runnable in the port today" matrix row; every assertion amended in UIR-22 with its note; any screen ticket landed with a blocker note still open. UIR-27 is verified as landed (a blocker), and the UIR-26 disposition is either its landed evidence or the quoted scope exception (step 0), never a silent omission. No item gets dropped for being awkward.
6. Write the final brief for Luca: what to look at (type hierarchy, palette, density, safe areas, 3D-court/HUD composition, the "3D flair" interpretation question), how to launch it himself:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --path <repo>/godot res://game/Main.tscn \
     -- --seed=20260916 --tier=3 --camera=default
   ```
   (verified pattern: real Metal context per `docs/wayfinder/evidence/local-macos-gate-sweep.md`; no feel claims attached).
7. Hand over (phase B; this step closes on the `luca-final` gate). When Luca's verdict arrives, record it verbatim in `uir-25-final.md` and on the board; if acceptance comes with follow-ups, each becomes a named ticket or a named open item. Phase A (steps 0-6) never waited on this gate.

## Acceptance commands (native macOS)

The full serialized suite list of microstep 2, plus:
```bash
"$GODOT" --rendering-driver opengl3 --path godot res://tests/ui/capture_ui.tscn -- --capture=all --seed=20260916 --tier=3
"$GODOT" --path godot res://game/Main.tscn -- --seed=20260916 --tier=3 --camera=default
```

## Evidence to hand back

`uir-25-final.md` (suite table, capture comparison table, open items, the Luca brief and, when it arrives, the verdict) + `uir-25-*.log`.

## Definition of Done

- [ ] Every suite green or every red named with cause; captures real and paired; open items complete and honest; Luca's brief handed over.
- [ ] UIR-26 disposition recorded: landed with cited evidence, or the scope decision quoted verbatim in `uir-25-final.md`; no silent exclusion anywhere in the pack.
- [ ] Luca's verdict recorded verbatim in `uir-25-final.md` and on the board; the plan entrypoint's status line updated to match. (Plan approval was the start gate; this close is `luca-final`.)
- [ ] No claim about feel, framing or visual acceptance authored by the agent.

## Failure and recovery

- A red suite at the final gate: back to the owning ticket with the failing line; the final ticket does not fix code.
- Luca rejects a surface: his reasons become the ticket, not a re-interpretation; record verbatim.

## Traces

`docs/wayfinder/tickets/ui-port-approach.md` ("Resolved when: Luca has seen..."); handoff (verdict gate is Luca's); S4 evidence list; mission human-gate policy.
