# Roster animation retarget

Canonical checkout: steam-circuit-padel-11m, codex/integrate-arena-11m.
User approved local reuse of the five downloaded Meshy motions. No API calls,
credits, new rigs or models were required. No commit/push performed.

## Runtime changes

- Dedicated drive, smash, bandeja, backhand, slice resources for Colosso,
  Oracolo, Maestro, Fornaio, Pantera and Steamer; Fiamma's five preserved.
- 35 animation resources total, approximately 3.65 MB on disk. Source GLBs
  and duplicate mesh/texture data are not loaded by runtime matches.
- Selection uses each rig's registered clips, with procedural fallback if an
  imported clip is absent. Other shot intents and all simulation code unchanged.
- Target translations and scales remain frozen from their own idle animation;
  no imported root motion or changes to collision/hitboxes.
- Contact phase, clip duration and playback speed retain existing recipes;
  backhand uses ball side and near/far facing, not human aiming direction.

## Retarget families and visual corrections

The existing baker accepts `stroke auto athlete` after `--`.
Mixamo 28-joint models use named spine remapping and global rest-space deltas
(23 mapped joints). The legacy 24-joint family uses shared source-axis global
orientations (24 mapped joints): applying another bind-pose tilt incorrectly
bent their arms, caught in rendered Maestro/Volpe reviews and corrected.
Bandeja posture constraints use source neutral axes on legacy rigs; using the
target idle axes inverted Volpe's pelvis. The corrected versions were rebaked.
Added above-head smash contact and upright-body checks to catch these classes
of regression beyond finite-quaternion and dispatch assertions.

Meshes remain unchanged: Pantera/Steamer use Volpe fallback; Fornaio uses the
Maestro stand-in with Cornetto racket. The work does not create their final art.

## Checks

Per-character test: `meshy_strokes_test.gd -- --athlete=<id>`; add `--capture`
to render equipped preparation/contact/recovery sheets here. Tests include all
five clips, finite rotations, unchanged translation, immediate contact phase,
upright body, smash hand height, recovery, repeated dispatch, near/far hand
selection, excluded intents, racket attachment, and missing-clip fallback.
Final results: Colosso/Oracolo/Fiamma 611/611 each; Maestro/Fornaio/Pantera/
Steamer 531/531 each, totaling 3957 successful assertions across seven rigs.

Regression checks: fluidity_animation_test 163/163, racket_hand_follow_test
30 poses with zero failures, meshy_fiamma_integration_test zero failures,
athlete_stroke_bridge_test 75/75. A real rendered match ran 960 simulation ticks
successfully; existing ReplayOverlay anchor warnings remain unrelated.

Limitations: no ball-contact IK or footplant IK is introduced. Static rendered
pose review and deterministic tests do not guarantee perfect contact at every
ball height or eliminate foot sliding. Running and new volley motion remain
outside this phase. All previous procedural clips remain available as fallback.
