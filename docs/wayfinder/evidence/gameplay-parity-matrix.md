# Gameplay parity matrix — 2D reference → Godot 3D

Updated 2026-09-16 after the first gameplay-focused port pass.

The browser implementation in `/Users/alessiofantini/Documents/Padel/js/game.js`
remains the behavioural reference. Godot's `src/sim/sim.gd` is the only gameplay
simulation in the 3D project; `game/match_controller.gd` only advances it at the
same fixed `1/120` tick and maps state to views.

## Current matrix

| Contract | 2D reference | Godot 3D status | Evidence / remaining risk |
|---|---|---|---|
| Match lifecycle and tennis scoring | `createMatchState`, `scorePoint`, game/set/tie-break formats | Implemented in `src/sim` | Ported rules audits pass; all formats still need broader whole-match coverage |
| Serve, first/second fault and diagonal box | `performServe`, `handleGroundBounce` | Implemented in `src/sim` | Covered by match playthrough and parity streams |
| Movement, charge slowdown, split-step and tactics | `moveHumanPaddle`, `updateShotControl` | Implemented in `src/sim` and `game/input_map.gd` | Input mapping is covered structurally; physical controller feel still needs a live play-test |
| Receiver forecast and lock | `bestResponder`, `lockReceiverForIncomingShot` | Implemented in `src/sim` | Whole-match parity covers the state path; co-op/PvP combinations remain to be exercised |
| Timing/position/height/control/energy quality | `evaluateShotQuality`, `showShotFeedback` | Implemented in `src/sim` | `shot_quality` audit passes with matching reference report values |
| Drive, slice, lob, volley and technical variants | `hitBall` variant branches | Implemented in `src/sim` | Discrete audit coverage exists; visual differentiation is still in progress |
| Smash x2/x3/flat/bandeja and double tap | smash branch in `hitBall`, input queue | Implemented in `src/sim` | `smash_input` audit passes; no claim yet for every seed/athlete in a whole match |
| Gravity, bounce, spin, net and glass | `handleGroundBounce`, `handleWalls`, `handleNetCollision` | Implemented in `src/sim` | `wall_rules` audit and wall/glass parity scenarios pass |
| AI difficulty, attack choice and controlled error | `chooseComputerShot`, `applyComputerShot` | Implemented in `src/sim` | Four tiers and attack audits pass; statistical parity is band-based, not bit-identical |
| Doubles shape and partner behaviour | `updateDoublesAI`, tactical mate movement | Implemented in `src/sim` | Lineup and whole-playthrough checks pass; human co-op still needs a hands-on gate |
| Stamina and athlete specials | `rallyEnergy`, `applySpecial` | Implemented in `src/sim` | State/audio routes exist; visual special treatment is not complete |
| Controller one-shot semantics | `pollGamepadGameplay`, fixed-step latch | Implemented in `game/input_map.gd` + controller | Structural input audit passes; device-specific validation remains open |
| Athlete position and gait | canvas paddle position/motion | Implemented in `athletes_view.gd` | Rig follows sim position and locomotion |
| Shot animation/contact timing | sprite action frame at contact | First seam implemented | `play_stroke_at()` seeks the authored clip to a shot-specific contact phase; clips are still authored approximations |
| Shot-specific body mechanics | distinct 2D action sprites | Open | Current rig vocabulary is drive/slice/lob/serve; smash/vibora/volley are semantic recipes over these clips |
| Racket/hand/ball physical contact | 2D paddle contact box | Open by design | Sim decides contact; rigs are not physics bodies and need visual polish |
| Camera, court proportion and readability | fixed canvas framing | Open | 3D camera/court scale is an owner decision and requires play-test sign-off |

## Acceptance rule for the next pass

Gameplay is ready to be called *translated* only when the discrete simulation
rules stay green **and** the 3D presentation makes the same decision readable to
a player. A matching digest alone does not certify animation timing, camera feel,
or controller ergonomics.

The next test expansion is a deterministic scenario grid: every shot variant,
serve fault, wall/net branch, smash branch, AI tier, athlete special, match
format, and human input mode. Each scenario should compare the state transition
first, then capture the animation recipe/contact phase used by the view.

## First implementation seam

`AthletesView.stroke_recipe()` now translates the simulation's `actionIntent` into
a registered rig clip plus a contact phase and speed. `AthleteRig.play_stroke_at()`
starts the authored motion at that phase and keeps locomotion speed from slowing a
stroke. This is deliberately presentation-only: changing the recipe cannot alter
ball physics, scoring, AI or RNG.
