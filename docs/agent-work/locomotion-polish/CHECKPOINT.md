# Locomotion polish — 2026-09-22

Canonical 11m / codex/integrate-arena-11m. Direct implementation, no Flash,
Meshy calls, commit, profile edits or simulation changes. Existing dirty work
in athletes_view.gd and athlete_rig.gd preserved.

## Scope and decisions

The project already contained procedural shuffle/backpedal/brake clips. Improve
these rather than buy duplicate animations: bent-knee steps with foot roll,
slightly slower backwards cycle, real-displacement cadence in metres/second.
Stopped characters settle even while the simulation activity signal remains high.
Directional hysteresis prevents clip changes around diagonal thresholds.
Add a capped six-degree visual weight shift from velocity and acceleration,
smoothed exponentially; starts, stops and reversals use the same path. No input
delay, root motion, stat/precision/stamina changes or new movement authority.
Stroke poses suppress weight tilt; clip speed never alters stroke timing.
Teleports clear inertia; service suppresses tilt but permits ordinary footwork.

## Evidence

- locomotion_weight_test.gd: 302/302, all six base/Mythic pairs; frame-rate cadence,
  mirrored teams, reversal, stop, contact, teleport, zero delta and finite poses.
- fluidity_animation_test.gd: 163/163, native render inspected at
  /tmp/padel-fluidity.png (static pose comparison, not a full play-session review).
- roster_ready_pose_test.gd: 156/156, recovery avoids open-arm resting poses.
- racket_hand_follow_test.gd: 90 poses, zero failures.
- meshy_strokes_test.gd --athlete=fiamma --outfit=mythic: 533/533.
- git diff --check clean.

Only runtime edits for this task: movement presentation in athletes_view.gd and
procedural footwork/visual tilt in athlete_rig.gd. New focused test above.
These are procedural refinements, not newly purchased mocap clips or foot IK;
perfect foot planting and garment clipping are not solved by this change.

## Follow-up: split step and shot recovery completed

Added in-place split_step (0.28 s, knee compression/takeoff/landing) and
recover_left/recover_right (0.34 s, alternating balance step). Receiving stationary
players cue the split on opponent contact; no hopping while running. A completed
shot triggers recovery once, not every frame. Motion, new shots, charging and
point resets override these cosmetic transients; no changes to input or sim.
No new Meshy calls. Fatigue posture remains outside these five requested points.

Checks: SPLIT_RECOVERY 226/226 across six base/Mythic pairs; FLUIDITY_ANIMATION
163/163; LOCOMOTION_WEIGHT 302/302; Fiamma Mythic MESHY_STROKES 533/533. Native
six-pose capture inspected via fluidity_animation_test --capture --split-recovery.
This is pose/test evidence, not a claim of a full human playtest or foot IK.
