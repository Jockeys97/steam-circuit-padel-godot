# Rest-pose correction — 2026-09-22

Direct implementation in canonical 11m after reproduced diagnosis.
No API calls, model changes, progression changes, staging or commit performed.

Volpe fallback (Pantera/Steamer) used a single-key bind hold as idle; Colosso and
Oracolo used their exported restpose. Ready/prepare/footwork inherited those poses.
The existing ready-idle authoring now includes these rigs and relaxes shoulders
and hands from each rig's own walking animation, not just upper/forearms.
Maestro base/Fornaio, Fiamma and Maestro Mythic behavior is preserved.

Rebaked all five imported strokes for the four affected athletes (20 animation
resources) because their baked recovery keys otherwise returned to the old pose
briefly before the animation-finished callback. Meshes and simulation unchanged.

Validation:
- roster_ready_pose_test: 156/156, run-to-idle/ready/prepare/brake/shuffle/backpedal,
  baked end-of-stroke recovery and finished-stroke transitions for all four rigs.
- meshy_strokes_test: Pantera 531/531, Steamer 531/531, Colosso 611/611,
  Oracolo 611/611, including above-head smash and stationary stroke translations.
- racket_hand_follow_test: 35 poses, zero failures.
- Rendered Volpe before/after and measured all five states. Idle hand drop below
  upper-arm origin: Volpe 0.35 -> 0.46–0.48m, Colosso 0.07 -> 0.45–0.46m,
  Oracolo 0.03 -> 0.41m. Running remains unchanged.

Diagnostic files: /tmp/padel-pose-check.Dq5Bd4 (temporary, not release assets).
The transition test advances in frame-sized increments: one large advance call
does not by itself sample the completed animation blend.
