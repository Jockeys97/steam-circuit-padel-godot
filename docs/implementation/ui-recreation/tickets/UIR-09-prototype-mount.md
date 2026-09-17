---
id: UIR-09
title: Prototype mount (menu + HUD running for GATE-A)
slug: prototype-mount
state: done
readiness: potential
owner_role: integration owner
blocked_by: [UIR-07, UIR-08]
blocks: [GATE-A, UIR-22, UIR-24]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-09-prototype-mount.md
  - docs/implementation/ui-recreation/evidence/uir-pre-gate-a-captures.log
  - docs/implementation/ui-recreation/evidence/uir-pull-wave/captures.log
  - docs/implementation/ui-recreation/evidence/uir-gate-a-hud-1280x720-capture.log
---

# UIR-09: Prototype mount (menu + HUD running for GATE-A)

## Worker brief (copy-paste)

> You are the integration owner (one writer for `godot/game/**` at a time). Mount the new MenuScreen into `godot/game/Main.tscn` behind a switch, and the new HUD into `godot/game/Match.tscn` as a CanvasLayer overlay, keeping every existing contract: `Main.tscn` is still launched by explicit path, `Config.pending_mode`/`start_match()`/`_open_mode()` semantics unchanged, `match_controller.gd`'s frame accumulator, pause semantics, capture arguments and mode-session persistence untouched, project default scene still `SmokeTest.tscn`. Produce the GATE-A evidence: before/after capture pairs for the menu and the HUD at 1280x720 plus a gate summary. Do not start the remaining screens; this mount is deliberately minimal.

## Why this exists

GATE-A is a human verdict on the approach ("can a Godot Control tree carry this interface without losing readable type, semantic colour, no overflow", `docs/wayfinder/tickets/ui-port-approach.md`). The verdict needs the real thing running, not a mock. This ticket is the smallest change that puts both screens in their real scenes so Luca can look and decide, and it is deliberately reversible: it wires the new screens in behind an explicit flag so both old and new remain verifiable in one engine build.

## Prerequisites (Definition of Ready)

- UIR-07 and UIR-08 landed and their audits green.
- The serial lock held; one engine process at a time.

## Read allowlist

- `godot/game/Main.tscn`, `godot/game/main_menu.gd` (`_ready:83`, `start_match:450-457`, `_open_mode:455-457`), `godot/game/Match.tscn`, `godot/game/match_controller.gd` (`_build_scene`, `apply_frame`, pause block `:1080-1176`, capture args `:144-227`, `_run_capture:930`), `godot/game/hud.gd`, `godot/game/mode_hud.gd`
- `godot/src/ui/**` (what you are mounting)
- `godot/tests/game_slice_test.gd` (the gates you must keep green)
- `docs/wayfinder/tickets/ui-port-approach.md` (the gate this serves)

## Write allowlist (you own these; you are the only writer of `godot/game/**` in this phase)

- `godot/game/Main.tscn`
- `godot/game/Match.tscn`
- `godot/game/main_menu.gd`
- `godot/game/match_controller.gd`
- `godot/game/hud.gd`
- `.uid` sidecars for those files
- `godot/game/out/ui-prototype-menu.png`, `godot/game/out/ui-prototype-hud-serve.png`, `godot/game/out/ui-prototype-hud-rally.png`
- `docs/implementation/ui-recreation/evidence/uir-09-prototype-mount.md`

No other writes. Do not edit `godot/src/sim/**`, `godot/src/locale/**`, `godot/src/modes/**`, `godot/src/save/**`, `godot/tests/**`, `project.godot`, the frozen web reference.

## Microsteps (do in order)

1. Design the switch: a single explicit entry, for example `-- --ui=new` on the command line, defaulting to... decide and record. Recommended: default NEW for `Main.tscn` (the menu is a leaf; old code path stays available via `--ui=legacy`), keeping `hud.gd` in place for the match until UIR-22. Record the choice and why in the evidence file.
2. `Main.tscn`: keep root Control + `main_menu.gd` script as the host, or add the router as a child that instantiates `MenuScreen`; keep `start_match()`/`_open_mode()` reachable from the new screen's actions. The new menu's `to-modes` must reach the current `ModeScreen.tscn` flow (the mode screens are not recreated yet).
3. `Match.tscn`/`match_controller.gd`: add the new `Hud.tscn` as a CanvasLayer child; feed it the same state+meta the old HUD gets (one call site; delete or bypass only after UIR-22). Keep `set_paused` wiring so ESC still flips `_paused` and the HUD reflects it. Do not change `_paused` semantics, `_reset_transient_input`, or the capture args.
4. Run the full local gate set serially (UIR-00's command list). The slice test's menu assertions (`MENU_ON_SCREEN`, the 1280x720/1152x648 fit check `game_slice_test.gd:542-571`) and HUD assertions (`:1796-1811`) still target the old construction; if the new default breaks them, either (a) keep legacy as the default for `Main.tscn` and pass `--ui=new` in the gate evidence commands, or (b) update the assertions to target whichever construction is active. Choose ONE, record the decision, and keep both constructions runnable. Never delete an assertion to go green; amend it only to point at the active construction.
5. Captures for the gate, on this Mac (in-engine capture path; PROPOSED-MAC: `run.sh` wraps these in xvfb, which does not exist here):
   ```bash
   export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
   cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
   "$GODOT" --rendering-driver opengl3 --path godot res://game/Main.tscn -- --capture=menu
   "$GODOT" --rendering-driver opengl3 --path godot res://game/Match.tscn -- --capture=match --tier=3 --seed=20260916
   ```
   Rename/place outputs as `ui-prototype-menu.png`, `ui-prototype-hud-serve.png`, `ui-prototype-hud-rally.png` from the produced PNGs (`godot/game/out/menu.png`, `quickmatch-serve.png`, `rally.png`) by copying them, so the "before" files stay intact.
6. Write `evidence/uir-09-prototype-mount.md`: the switch design, the assertion decision from microstep 4, the before/after capture pairs (before = the UIR-00 register), gate suite results, and the exact commands.
7. Launch the playable window once for the human gate:
   ```bash
   "$GODOT" --path godot res://game/Main.tscn -- --seed=20260916 --tier=3 --camera=default
   ```
   Confirm from process output it uses the real GPU context (`OpenGL API 4.1 Metal`). Hand the window to Luca; quit after his look. Note: window capture of a running Godot window does not work on this Mac (screencapture refuses, cua-driver times out); the in-engine captures above are the frame evidence, and feel stays Luca's verdict.

## Acceptance commands (native macOS)

The seven-suite list from UIR-00, plus the two capture commands and the one play launch above; all serialized.

## Evidence to hand back

- `evidence/uir-09-prototype-mount.md` (switch design, suite results table, capture paths).
- Three PNGs under `godot/game/out/ui-prototype-*.png`.
- Hand-back message: what Luca will see, what is deliberately still old (mode screens, language handling), suite tallies.

## Definition of Done

- [ ] New menu and new HUD run in their real scenes; all suites green under the chosen default; decision recorded.
- [ ] `project.godot` untouched (`run/main_scene="res://tests/SmokeTest.tscn"` still).
- [ ] Captures regenerated and placed; "before" files untouched.
- [ ] GATE-A brief written (in the evidence file: what to look at, what to judge: type readability, semantic color, density, safe areas, 3D-court/HUD composition, and Luca's interpretation of "3D flair").
- [ ] One engine at a time respected; no commits.

## Failure and recovery

- Slice test red on menu fit / HUD panels: measure with `godot/game/tools/hud_probe.gd` (prints anchors/offsets at both sizes) and fix the layout; assertion edits only per microstep 4's rule.
- ESC/pause misbehaves (stale input on resume): this is exactly the defect class `match_controller.gd:1080-1176` documents; preserve `_reset_transient_input` on both edges.
- Capture blank: you are on the wrong rendering path; do not use `--headless` for captures (dummy driver renders blank).

## Traces

`docs/wayfinder/tickets/ui-port-approach.md`; `js/ui.js:595`; `godot/game/match_controller.gd:1080-1176, :930-970`; `godot/tests/game_slice_test.gd:542-571, :1796-1811`; `godot/game/tools/hud_probe.gd` header; handoff "Capture" notes.
